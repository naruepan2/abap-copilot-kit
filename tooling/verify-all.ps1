# verify-all.ps1 - full consistency audit after the agent/memory/skill redesign.
# Read-only. Reports facts; changes nothing.
#
#   -Detail terse | full   (default terse)   See docs/reference/detail-levels.md
#     terse  one line per check (this is the default now)
#     full   every file and every probe, as this script used to print
#   -Summary   legacy alias; terse and -Summary are the same thing
param(
    [ValidateSet('terse', 'full')]
    [string]$Detail = 'terse',
    # Legacy alias, honoured rather than merely accepted. Before this the switch was declared and then
    # overwritten by the $Detail default, so `-Detail full -Summary` printed the full output the caller
    # had just asked to suppress - a flag that did nothing is worse than an absent one.
    [switch]$Summary
)
if ($Summary) { $Detail = 'terse' }
$Summary = ($Detail -eq 'terse')

$ErrorActionPreference = 'Continue'

# The audit must be able to fail. Until this existed every finding was printed and the exit code was
# 0 regardless, so a caller could not tell a clean run from a private key in history - the two
# sibling scripts (install-kit, workspace-sync) both exit 1, and README calls this one the audit the
# repository is held to. Each section adds what it detected to this counter while the data is still
# in hand, rather than the verdict being re-derived later from the printed text: prose can contain
# the word "missing" without meaning a failure.
$script:issues = 0
$script:issueKinds = [ordered]@{}
$script:verified = 0
$script:launcherAbsent = 0
$script:ran = [ordered]@{}
$AG   = "$env:USERPROFILE\.copilot\agents"
$SK   = "$env:USERPROFILE\.copilot\skills"
$MEM  = "$env:APPDATA\Code\User\globalStorage\github.copilot-chat\memory-tool\memories"

# Kit root. This script runs from two places: the repository (tooling\) and the live copy
# (~/.copilot/state\). Resolve it instead of hardcoding, so a clone on another machine works.
# Order: $env:ABAP_KIT_ROOT, then the pin file install-kit.ps1 writes beside the copied scripts,
# then one level up from this script.
$REPO = $env:ABAP_KIT_ROOT
if (-not $REPO -or -not (Test-Path (Join-Path $REPO 'INDEX.md'))) {
    $pin = Join-Path $PSScriptRoot 'kit-root.txt'
    if (Test-Path $pin) {
        # Guarded even though a failure here only falls through to the next resolution step: an
        # unguarded read under EAP=Continue leaves $pinned holding whatever it held before, which is
        # the same defect that produced a confident wrong diagnosis further down this file.
        $pinned = $null
        try { $pinned = ([System.IO.File]::ReadAllText($pin, [System.Text.Encoding]::UTF8)).Trim() }
        catch { $pinned = $null }
        if ($pinned -and (Test-Path (Join-Path $pinned 'INDEX.md'))) { $REPO = $pinned }
    }
}
if (-not $REPO -or -not (Test-Path (Join-Path $REPO 'INDEX.md'))) {
    $up = Split-Path $PSScriptRoot -Parent
    if ($up -and (Test-Path (Join-Path $up 'INDEX.md'))) { $REPO = $up }
}
$repoOk = [bool]($REPO -and (Test-Path (Join-Path $REPO 'INDEX.md')))

# Repo memory sits under a per-workspace folder named by a hash of the workspace path, so the name
# differs per machine - the hardcoded hash only ever worked on one install. Pick the folder that
# actually holds notes; override with $env:ABAP_REPO_MEMORY when several workspaces have them.
$AWS = $env:ABAP_REPO_MEMORY
if (-not $AWS -or -not (Test-Path $AWS)) {
    $wsBase = "$env:APPDATA\Code\User\workspaceStorage"
    $picks = @()
    if (Test-Path $wsBase) {
        foreach ($d in Get-ChildItem $wsBase -Directory -ErrorAction SilentlyContinue) {
            $p = Join-Path $d.FullName 'GitHub.copilot-chat\memory-tool\memories\repo'
            if (Test-Path $p) {
                $n = @(Get-ChildItem $p -Recurse -File -Filter *.md -ErrorAction SilentlyContinue).Count
                $picks += [pscustomobject]@{ Path = $p; Notes = $n }
            }
        }
    }
    $top = $picks | Sort-Object Notes -Descending | Select-Object -First 1
    if ($top) { $AWS = $top.Path }
}
$awsOk = [bool]($AWS -and (Test-Path $AWS))

function Line($t) { if (-not $Summary) { Write-Output ""; Write-Output ("=== " + $t + " ===") } }

# Counters. `issues` is what the exit code reads; the dictionary keeps the kinds so the closing line
# can name them instead of pointing at a token that may not have been printed. `verified` counts the
# inputs a section actually examined, because "clean" and "nothing to check" were the same output
# before: no agents, no skills, no roster and no memory produced six zero lines and exit 0.
#
# Two PowerShell 5.1 traps fixed here, both measured:
#   - [ordered]@{} is an OrderedDictionary and has NO ContainsKey method; it has Contains. The first
#     version called ContainsKey, so every real finding threw "Method invocation failed" to stderr
#     while the counts survived by accident (the increment ran before the throw). A guard that only
#     appears to work is worse than no guard, because the next reader trusts it.
#   - a parameter typed [int] throws when handed an empty array, which is what
#     @($items | Where-Object {...}) produces when nothing matches. The parameter is untyped and
#     coerced here instead.
function Note([string]$kind, $n) {
    $count = 0
    if ($null -ne $n) {
        if ($n -is [array] -or $n -is [System.Collections.ICollection]) {
            # An array means "this many findings", so its length is the count. Summing the elements
            # was wrong and was measured wrong: @(1,2,3) added 6. An empty array is the normal
            # result of a Where-Object that matched nothing and must add nothing.
            foreach ($x in @($n)) { if ($null -ne $x) { $count++ } }
        }
        else { $count = [int]$n }
    }
    if ($count -le 0) { return }
    $script:issues += $count
    if ($script:issueKinds.Contains($kind)) { $script:issueKinds[$kind] += $count }
    else { $script:issueKinds[$kind] = $count }
}
function Skip($t) { Write-Output ("  SKIP    " + $t) }

# A file whose last line ends in a newline has one fewer line than -split reports. Measured 2026-11-16
# on the live memory folder: 21/56/25 lines reported for 20/55/24 real ones, total 102 for 99. The
# 200-line budget is a gate, so the phantom line turned a compliant tree into "exceeds by 1".
function Get-RealLineCount([string]$t) {
    if ([string]::IsNullOrEmpty($t)) { return 0 }
    $n = ($t -split "`r?`n").Count
    if ($t.EndsWith("`n")) { $n-- }
    return $n
}
# git cat-file --batch-check="%(objecttype)" answers a resolvable object with its type ALONE, and an
# unresolvable one with "<input> missing" - one line either way. Comparing the raw line to 'commit'
# therefore described a missing commit as "resolves to a <sha> missing, not a commit", and the
# 'no such object' branch could never fire. Proved 2026-11-16: a 40-hex non-object printed
# "deadbeef... missing" and exited 0.
function Get-EvidenceType([string]$line) {
    if ([string]::IsNullOrWhiteSpace($line)) { return 'missing' }
    $v = $line.Trim()
    if ($v -match '\smissing$') { return 'missing' }
    return $v
}

# Records how many inputs a section actually examined. A section that saw nothing is either a SKIP
# (its input is optional and absent) or a silent failure, and the two were indistinguishable before.
function Ran([string]$name, $n) {
    $c = 0
    if ($null -ne $n) { if ($n -is [array]) { $c = @($n).Count } else { $c = [int]$n } }
    # Accumulates. Two skill roots report under the same name, and assigning overwrote the first
    # root's count with the second's: a clean profile whose second root was empty reported
    # "inconclusive - skills" while three skills had in fact been read.
    if ($script:ran.Contains($name)) { $script:ran[$name] += $c } else { $script:ran[$name] = $c }
    $script:verified += $c
}

Line '1. Agent files: structure and encoding'
$agBad = 0; $agCount = 0
if (-not (Test-Path $AG)) {
    Write-Output ("  ISSUE   agent folder not found: " + $AG)
    Note 'ISSUE' 1
} else {
foreach ($f in Get-ChildItem $AG -Filter *.agent.md | Where-Object { -not $_.PSIsContainer } | Sort-Object Name) {
    # Two traps here, both measured. ReadAllBytes throws on a locked file, which aborted the loop and
    # left the summary reporting a healthy count. And `-Filter *.agent.md` matches a DIRECTORY with
    # that name; the directory was then validated using the previous file's bytes and counted as a
    # passing agent. So the read is guarded and non-files are excluded before anything else.
    $b = $null
    try { $b = [System.IO.File]::ReadAllBytes($f.FullName) }
    catch { $agCount++; $agBad++; Write-Output ("  ISSUE  " + $f.Name + " (unreadable: " + $_.Exception.GetType().Name + ")"); continue }
    $u = [System.Text.Encoding]::UTF8.GetString($b)
    $lines = $u -split "`r?`n"
    # Frontmatter opens on line 1 and nowhere else. Searching from line 2 accepted any later '---' - a
    # markdown horizontal rule - so a file whose frontmatter an edit had destroyed still reported
    # "fm=L5" and passed. The BOM is trimmed first because GetString does not remove it.
    $fm = 0
    if ($lines.Count -gt 0 -and $lines[0].TrimStart([char]0xFEFF) -eq '---') {
        for ($i = 1; $i -lt $lines.Count; $i++) { if ($lines[$i] -eq '---') { $fm = $i + 1; break } }
    }
    $fences = @($lines | Where-Object { $_ -match '^```' }).Count
    $bad = ([regex]::Matches($u, [string][char]0xFFFD)).Count
    $dup = @($lines | Where-Object { $_ -match '^#{2,3} ' } | Group-Object | Where-Object { $_.Count -gt 1 }).Count
    $ok = ($bad -eq 0 -and ($fences % 2) -eq 0 -and $dup -eq 0 -and $fm -gt 0)
    $agCount++; if (-not $ok) { $agBad++ }
    if (-not $Summary -or -not $ok) {
        $tag = if ($ok) { 'OK     ' } else { 'ISSUE  ' }
        # Get-RealLineCount, not $lines.Count. -split counts a phantom final element for any file that
        # ends in a newline, so this line printed 576 for a 575-line agent and 37 for 36 - the same
        # off-by-one the memory budget already refuses to tolerate one section further down.
        Write-Output ("  {0} {1,-46} fm=L{2,-3} lines={3,-4} fences={4} dupH={5} repl={6}" -f $tag, $f.Name, $fm, (Get-RealLineCount $u), $fences, $dup, $bad)
    }
}
if ($Summary) { Write-Output ("  {0} agent files checked, {1} with issues" -f $agCount, $agBad) }
Ran 'agents' $agCount
Note 'ISSUE' $agBad
}

Line '1b. Every script parses (the cheapest check that would have caught my own mistakes)'
# A syntax error is the least subtle defect a file can have and the easiest to produce: a bad edit that
# eats a newline breaks a PowerShell script and the tool still reads as "present". Two separate edits
# in one session produced exactly that, and neither was caught until something ran the file. Parsing is
# static, fast, and needs no execution.
# A file that was never parsed is not a file that parsed. The pass line used to count every Node file
# even when `node` was absent (both loops did `continue` after incrementing), so on a machine without
# node the audit still printed "4 Node file(s) parse" and the same 332 verified - the one check that
# can catch a syntax error in the hooks had silently left the room.
$psBad = 0; $psCount = 0; $jsBad = 0; $jsCount = 0; $jsSkipped = 0
$node = Get-Command node -ErrorAction SilentlyContinue
if ($repoOk) {
    foreach ($f in @(Get-ChildItem (Join-Path $REPO 'tooling') -File -Filter '*.ps1' -ErrorAction SilentlyContinue) +
                     @(Get-ChildItem (Join-Path $REPO 'hooks') -File -Filter '*.cjs' -ErrorAction SilentlyContinue) +
                     @(Get-ChildItem (Join-Path $REPO 'hooks') -File -Filter '*.ps1' -ErrorAction SilentlyContinue)) {
        if ($f.Extension -eq '.ps1') {
            $psCount++
            $errs = $null
            [void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$errs)
            if (@($errs).Count -gt 0) {
                $psBad++
                foreach ($e in @($errs | Select-Object -First 2)) {
                    Write-Output ("  ISSUE   {0}:L{1} {2}" -f $f.Name, $e.Extent.StartLineNumber, $e.Message)
                }
            }
        }
        else {
            $jsCount++
            if (-not $node) { $jsSkipped++; continue }
            $out = & $node.Source --check $f.FullName 2>&1
            if ($LASTEXITCODE -ne 0) {
                $jsBad++
                Write-Output ("  ISSUE   {0}: does not parse ({1})" -f $f.Name, (($out | Select-Object -First 1) -join ''))
            }
        }
    }
    foreach ($f in Get-ChildItem (Join-Path $REPO 'tooling') -File -Filter '*.js' -ErrorAction SilentlyContinue) {
        $jsCount++
        if (-not $node) { $jsSkipped++; continue }
        $out = & $node.Source --check $f.FullName 2>&1
        if ($LASTEXITCODE -ne 0) {
            $jsBad++
            Write-Output ("  ISSUE   {0}: does not parse ({1})" -f $f.Name, (($out | Select-Object -First 1) -join ''))
        }
    }
    $jsParsed = $jsCount - $jsSkipped
    if ($psBad -eq 0 -and $jsBad -eq 0) {
        Write-Output ("  {0} PowerShell file(s) and {1} Node file(s) parse" -f $psCount, $jsParsed)
    }
    if ($jsSkipped -gt 0) {
        Write-Output ("  SKIP    {0} Node file(s) not parsed - node is not on PATH" -f $jsSkipped)
    }
    Ran 'scripts' ($psCount + $jsParsed)
    Note 'ISSUE' ($psBad + $jsBad)
    if ($psCount -eq 0) { Write-Output '  ISSUE   no .ps1 found to parse'; Note 'ISSUE' 1 }
}
else {
    Write-Output '  SKIP    kit repository not found (set $env:ABAP_KIT_ROOT)'
}

Line '1c. No read can lie (a failed read must not leave a previous value behind)'
# This is the single most productive defect class in this repository: nine instances across four audit
# rounds. The mechanism is always the same. Under ErrorActionPreference = Continue, a failed .NET read
# is statement-terminating only: the assignment does not happen, the variable keeps the value from the
# previous loop iteration, and the rest of the block runs. The report then describes a file nobody
# opened, in the confident voice of a measurement.
#
# Files with EAP=Stop are excluded on purpose: a failed read there terminates the script, which is
# loud and safe. Narrowing to the files that CAN lie is what makes this output actionable.
#
# The check parses each file and asks the syntax tree whether the read node sits inside a try body.
# A text scan with a brace counter was tried first and produced a false positive on a multi-line try,
# which is worse than no check: "no output" has to mean "none".
if ($repoOk) {
    # The filter reads each file to decide whether it can lie, so that read is guarded too - the gate
    # caught itself on the first run, which is the best evidence that it works.
    $lieFiles = @()
    foreach ($cand in @(Get-ChildItem (Join-Path $REPO 'tooling') -File -Filter '*.ps1' -ErrorAction SilentlyContinue)) {
        $candText = $null
        try { $candText = [System.IO.File]::ReadAllText($cand.FullName) } catch { continue }
        # Population rule, corrected 2026-11-15. This selected scripts that contain a literal
        # `$ErrorActionPreference = 'Continue'` declaration, which excluded every script that never
        # mentions the variable - and those inherit Continue, the very mode that lets a read fail
        # silently while the block keeps running. who-locks.ps1 was outside this gate for that
        # reason, so its reads were never examined and the summary still claimed to have covered
        # "M continue-on-error script(s)". A script is now examined unless it opts into the loud
        # behaviour with a top-level 'Stop'.
        if ($candText -notmatch "(?m)^\`$ErrorActionPreference\s*=\s*'Stop'") { $lieFiles += $cand }
    }
    $unguarded = @()
    $lieChecked = 0
    foreach ($file in $lieFiles) {
        $tok = $null; $err = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tok, [ref]$err)
        if (@($err).Count -gt 0) { continue }
        $tryBodies = @()
        foreach ($t in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.TryStatementAst] }, $true)) {
            $tryBodies += , @($t.Body.Extent.StartOffset, $t.Body.Extent.EndOffset)
        }
        $reads = $ast.FindAll({
            param($n)
            if ($n -is [System.Management.Automation.Language.InvokeMemberExpressionAst]) {
                $m = $n.Member.Extent.Text
                return ($m -match "^'?(ReadAllText|ReadAllBytes|ReadAllLines)'?$")
            }
            if ($n -is [System.Management.Automation.Language.CommandAst]) { return ($n.GetCommandName() -eq 'Get-Content') }
            return $false
        }, $true)
        foreach ($r in $reads) {
            $lieChecked++
            $off = $r.Extent.StartOffset
            $guarded = $false
            foreach ($tb in $tryBodies) { if ($off -ge $tb[0] -and $off -le $tb[1]) { $guarded = $true; break } }
            if (-not $guarded) { $unguarded += ($file.Name + ':' + $r.Extent.StartLineNumber) }
        }
    }
    if ($unguarded.Count -eq 0) {
        Write-Output ("  {0} read(s) in {1} continue-on-error script(s), all inside try" -f $lieChecked, $lieFiles.Count)
    }
    else {
        foreach ($u in $unguarded) { Write-Output ("  ISSUE   unguarded read can report a stale value: " + $u) }
    }
    Ran 'reads' $lieChecked
    Note 'ISSUE' $unguarded.Count
    if ($lieFiles.Count -eq 0) { Write-Output '  ISSUE   no continue-on-error script found to check'; Note 'ISSUE' 1 }
}
else {
    Write-Output '  SKIP    kit repository not found (set $env:ABAP_KIT_ROOT)'
}

Line '2. Skill frontmatter parses (both roots)'
foreach ($root in @($SK, "$env:USERPROFILE\.agents\skills")) {
    if (-not (Test-Path $root)) {
        # A root that should exist and does not is a defect, not a skip: every skill under it is
        # silently absent, and the run would otherwise report a healthy zero.
        Write-Output ("  ISSUE   skill root not found: " + $root)
        Note 'ISSUE' 1
        continue
    }
    $n = 0; $bad = 0; $badLinks = 0
    $yamlOwners = $null   # loaded once, only if a scalar actually needs the ownership check
    foreach ($d in Get-ChildItem $root -Directory) {
        $s = Join-Path $d.FullName 'SKILL.md'
        if (-not (Test-Path $s)) { continue }
        $n++
        # An unreadable file aborted the loop and the summary still printed a healthy count, so a
        # locked or half-copied SKILL.md looked like a pass. Reading is guarded and counted instead.
        $t = $null
        try { $t = [System.IO.File]::ReadAllText($s, [System.Text.Encoding]::UTF8) }
        catch { Write-Output ("    BAD  " + $d.Name + ' (unreadable: ' + $_.Exception.GetType().Name + ')'); $bad++; continue }
        $m = [regex]::Match($t, "(?s)^---\r?\n(.*?)\r?\n---")
        # Both keys are tested inside the frontmatter block, not against the whole file. Measured
        # 2026-11-16: `$t -notmatch 'description:'` was satisfied by the word appearing anywhere in
        # the body, so a skill whose frontmatter had lost its description passed. The same mistake
        # had already been fixed for `name:` one round earlier and was left in place for the other
        # half of the pair.
        $fmText = if ($m.Success) { $m.Groups[1].Value } else { '' }
        $hasName = [bool]([regex]::IsMatch($fmText, '(?m)^name:\s*\S'))
        $hasDesc = [bool]([regex]::IsMatch($fmText, '(?m)^description:\s*\S'))
        if (-not $m.Success -or -not $hasName -or -not $hasDesc) { $bad++; Write-Output ("    BAD  " + $d.Name + $(if (-not $m.Success) { ' (no frontmatter)' } elseif (-not $hasName) { ' (frontmatter has no name)' } else { ' (frontmatter has no description)' })) }
        # A plain scalar that contains ": " is not valid YAML: the colon is read as a mapping
        # separator. GitHub's renderer rejects the file while this regex-only check used to pass.
        # Measured 2026-11-18: long-task-control and rap-lifecycle each failed at the colon after
        # "request" / "object", columns 69 and 74. Quoted or folded scalars are exempt, so check
        # only unquoted single-line values.
        foreach ($fmLine in ($fmText -split "`r?`n")) {
            if ($fmLine -notmatch '^(description|name):\s*(\S.*)$') { continue }
            $key = $Matches[1]
            $scalar = $Matches[2]
            if ($scalar.StartsWith('"') -or $scalar.StartsWith("'") -or $scalar -eq '>' -or $scalar -eq '|') { continue }
            # Search the whole line, then skip the separator after the key itself. Searching only
            # the scalar made a short description report its own "description:" as a defect.
            $ci = $fmLine.IndexOf(': ', $key.Length + 3)
            if ($ci -ge 0) {
                # Installer-owned skills are not editable here; the next upgrade overwrites the
                # edit. Report them once as a NOTE so the defect is not hidden, but do not fail the
                # kit's own audit for a file its owner must fix upstream.
                $assetKey = 'skills\' + $d.Name + '\SKILL.md'
                $owned = $false
                # Section 5b reads the same manifest later under $tkDoc; this check runs earlier,
                # so load it here under a separate name. A missing or broken manifest means we
                # cannot prove ownership, so the file is treated as ours and reported.
                if ($null -eq $yamlOwners) {
                    $ymPath = "$env:USERPROFILE\.copilot\.sap-ai-dev-toolkit-assets.json"
                    if (Test-Path $ymPath) {
                        try { $yamlOwners = Get-Content $ymPath -Raw | ConvertFrom-Json } catch { $yamlOwners = $false }
                    }
                    else { $yamlOwners = $false }
                }
                if ($yamlOwners -and $yamlOwners.files -and $yamlOwners.files.PSObject.Properties.Name -contains $assetKey) { $owned = $true }
                # A skill in the kit's own skills/ folder is ours to fix. Anything else under a
                # loader root belongs to its installer or to the user; report the defect once and
                # leave the file alone, because an edit there is overwritten on the next update.
                $kitPath = Join-Path (Join-Path $REPO 'skills') ($d.Name + '\SKILL.md')
                $isKit = Test-Path -LiteralPath $kitPath
                if ($owned -or -not $isKit) {
                    Write-Output ("    NOTE  " + $d.Name + ' (external YAML scalar has ": " at column ' + ($ci + 1) + '; fix at the source)')
                }
                else {
                    $bad++
                    Write-Output ("    BAD  " + $d.Name + ' (invalid YAML scalar: ": " at column ' + ($ci + 1) + ')')
                }
            }
        }
        # `name` must equal the folder name. Until now the test above was a bare substring match on
        # 'name:', which is satisfied by the word appearing anywhere in the file - including inside the
        # body - so a skill whose frontmatter names something else passed. The check is worth a few
        # lines because the folder is what the loader indexes and `name` is what the model is told;
        # when they disagree the skill is selectable under a name that resolves to nothing.
        # Borrowed from the upstream validator (likweitan/abap-skills, scripts/validate_skills.py:
        # `if name != skill_file.parent.name`), which is one of four SKILL.md invariants we did not check.
        if ($m.Success) {
            $nm = [regex]::Match($m.Groups[1].Value, '(?m)^name:\s*(.+?)\s*$')
            if ($nm.Success) {
                $declared = $nm.Groups[1].Value.Trim().Trim('"').Trim("'")
                if ($declared -cne $d.Name) {
                    $bad++; Write-Output ("    BAD  " + $d.Name + ' (frontmatter name is "' + $declared + '", folder is "' + $d.Name + '")')
                }
            }
        }
        # A deferral to references/ is only worth writing if the target exists. A skill collection met
        # in the wild on 2026-11-16 had a 9,333-char reference its SKILL.md never mentioned and no
        # check that could notice; the reverse - a link to a file nobody wrote - fails at the moment
        # the agent needs it, which is worse. Zero cost: the file is already in memory here.
        #
        # Two spellings, because both are in live use: a markdown link and a bare backticked path.
        # Measured 2026-11-16 across the three loader roots: 3 markdown links and 76 backticked paths,
        # all 76 resolving. Checking only the link form would have validated 3 of 79 references, which
        # is the coverage problem this gate exists to fix rather than repeat.
        $seenRef = @{}
        foreach ($rx in @('\]\((\./)?(references/[^)\s]+)\)', '`(references/[^`\s]+\.md)`')) {
            foreach ($m in [regex]::Matches($t, $rx)) {
                $rel = $m.Groups[$m.Groups.Count - 1].Value
                if ($seenRef.ContainsKey($rel)) { continue }
                $seenRef[$rel] = $true
                if (-not (Test-Path (Join-Path $d.FullName $rel))) { $badLinks++; Write-Output ("    BAD  " + $d.Name + ' (broken reference: ' + $rel + ')') }
            }
        }
    }
    $label = (Split-Path $root -Parent | Split-Path -Leaf) + ':' + (Split-Path $root -Leaf)
    if ($n -eq 0) {
        # Zero skills is not a pass. Measured 2026-11-16: two empty roots printed
        # "skills=  0  bad_frontmatter=0  bad_links=0" - a line shaped exactly like a clean result -
        # and Ran recorded 0, so the verdict never noticed the section had checked nothing. A root
        # that exists and holds no SKILL.md is a broken install or a wrong path, never a healthy tree.
        Write-Output ("  {0,-30} skills=  0  ISSUE no SKILL.md under this root - nothing was checked" -f $label)
        Note 'ISSUE' 1
        continue
    }
    Write-Output ("  {0,-30} skills={1,3}  bad_frontmatter={2}  bad_links={3}" -f $label, $n, $bad, $badLinks)
    Ran 'skills' $n
    Note 'BAD' ($bad + $badLinks)
}

Line '2b. Parked skills stayed parked (a designed state must not revert silently)'
# Every skill's name and description loads into every request, so an irrelevant skill costs tokens
# forever. Parking one in `skills-disabled\` is the only way to stop that, and it is not durable:
# measured 2026-11-15, eleven toolkit-owned skills were parked, the toolkit was upgraded, and all
# eleven came back into the live folder - 805 tokens per request, with the parked copies still on
# disk. Nothing reported it, because the state that reverted was a designed state rather than a
# failure. A probe that only looks for breakage cannot see a restored default.
$parkedDir = "$env:USERPROFILE\.copilot\skills-disabled"
$revived = @(); $parkedCost = 0
if (Test-Path $parkedDir) {
    foreach ($d in Get-ChildItem $parkedDir -Directory -ErrorAction SilentlyContinue) {
        $liveSkill = Join-Path (Join-Path $SK $d.Name) 'SKILL.md'
        if (-not (Test-Path $liveSkill)) { continue }
        $revived += $d.Name
        $t = $null
        try { $t = [System.IO.File]::ReadAllText($liveSkill, [System.Text.Encoding]::UTF8) } catch { continue }
        if ($t -match '(?s)^---\r?\n(.*?)\r?\n---') { $parkedCost += $Matches[1].Length }
    }
}
if (-not (Test-Path $parkedDir)) {
    Write-Output '  SKIP    no skills-disabled folder - nothing is parked'
    # No Ran here: an absent folder examined nothing. The old unconditional Ran 'parked' 1 counted a
    # SKIP as verified on every machine and made the section unreachable for the verdict.
}
elseif ($revived.Count -eq 0) {
    Write-Output '  parked skills stayed parked'
    Ran 'parked' 1
}
else {
    foreach ($r in $revived) { Write-Output ("  ISSUE   parked but live again: " + $r) }
    Write-Output ("  unparking cost ~{0} chars (~{1} tokens) in every request" -f $parkedCost, [math]::Round($parkedCost / 4))
    Note 'ISSUE' $revived.Count
    Ran 'parked' 1
}

# A third designed state: DELETED. tools/removed-on-purpose.json declares it, because the setup guide
# tells the operator to delete nine skills after every reinstall while also requiring this audit to
# exit 0 - so without the declaration the documented procedure makes the documented success condition
# impossible. A revival here costs tokens on every request (the name+description come back), which is
# exactly what the deletions bought back.
$removedFile = if ($REPO) { Join-Path $REPO 'tooling\removed-on-purpose.json' } else { $null }
$removedDoc = $null
if ($removedFile -and (Test-Path $removedFile)) {
    try { $removedDoc = [System.IO.File]::ReadAllText($removedFile, [System.Text.Encoding]::UTF8) | ConvertFrom-Json }
    catch { Write-Output '  ISSUE   removed-on-purpose.json is not valid JSON'; Note 'ISSUE' 1 }
}
else { Write-Output '  WARNING removed-on-purpose.json not found - declared deletions cannot be honoured' }
if ($removedDoc) {
    $pubRemoved = @($removedDoc.published_skills | Where-Object { $_ -and $_.name })
    $pubBack = @(); $pubCost = 0
    foreach ($r in $pubRemoved) {
        $live = Join-Path (Join-Path "$env:USERPROFILE\.agents\skills" $r.name) 'SKILL.md'
        if (-not (Test-Path $live)) { continue }
        $pubBack += $r.name
        $rt = $null
        try { $rt = [System.IO.File]::ReadAllText($live, [System.Text.Encoding]::UTF8) } catch { continue }
        if ($rt -match '(?s)^---\r?\n(.*?)\r?\n---') { $pubCost += $Matches[1].Length }
    }
    if ($pubRemoved.Count -eq 0) {
        # A declaration that declares nothing is a broken declaration, not a quiet machine. Measured
        # 2026-11-16: emptying published_skills printed a WARNING, registered nothing with Ran, and the
        # run still ended "clean - 444 item(s)" with exit 0 - the deletion gate had left the room and
        # the verdict had no way to say so. The toolkit_skills half fails loudly; this half did not.
        Write-Output '  ISSUE   removed-on-purpose.json declares no published skill - the deletion gate can no longer fail'
        Note 'ISSUE' 1
    }
    elseif ($pubBack.Count -eq 0) {
        Write-Output ("  {0} skill(s) declared deleted stay deleted" -f $pubRemoved.Count)
        Ran 'removed' $pubRemoved.Count
    }
    else {
        foreach ($r in $pubBack) { Write-Output ("  ISSUE   declared deleted but installed again: " + $r) }
        Write-Output ("  reinstalling cost ~{0} chars (~{1} tokens) in every request - delete again, see SETUP-NEW-MACHINE.md section 7" -f $pubCost, [math]::Round($pubCost / 4))
        Note 'ISSUE' $pubBack.Count
        Ran 'removed' $pubRemoved.Count
    }
}

Line '3. Cross-file rule duplication (a rule must have one home)'
# Every file a probe reads is guarded. A missing skill file used to throw inside the ordered
# literal, which left $probes null and printed "0 of 0 flagged" - a pass-shaped line for a check
# that had run nothing at all.
$agentFile = "$AG\abap-developer-by-pongg.agent.md"
$auditSkill = "$SK\mcp-surface-audit\SKILL.md"
$lessonSkill = "$SK\capture-lesson\SKILL.md"
$missingProbeInputs = @()
foreach ($p in @($agentFile, $auditSkill, $lessonSkill)) { if (-not (Test-Path $p)) { $missingProbeInputs += $p } }
if ($missingProbeInputs.Count -gt 0) {
    foreach ($m in $missingProbeInputs) { Write-Output ("  ISSUE   duplication probe input missing: " + $m) }
    Note 'ISSUE' $missingProbeInputs.Count
} else {
# Under ErrorActionPreference=Continue a failed .NET read is only statement-terminating: the assignment
# does not happen, the variable KEEPS ITS PREVIOUS VALUE, and the rest of the block runs. Three reads
# here fed six probes, so a locked agent file produced "agent lost the detail-levels pointer" - a
# confident wrong diagnosis about a file nobody had opened. Reset to $null, read inside try, and treat
# a failure as an ISSUE that skips the probes rather than as a probe result.
$agent = $null; $auditText = $null; $lessonText = $null
$readFailed = @()
try { $agent = [System.IO.File]::ReadAllText($agentFile, [System.Text.Encoding]::UTF8) } catch { $readFailed += 'agent' }
try { $auditText = [System.IO.File]::ReadAllText($auditSkill, [System.Text.Encoding]::UTF8) } catch { $readFailed += 'mcp-surface-audit' }
try { $lessonText = [System.IO.File]::ReadAllText($lessonSkill, [System.Text.Encoding]::UTF8) } catch { $readFailed += 'capture-lesson' }
if ($readFailed.Count -gt 0) {
    Write-Output ("  ISSUE   probe input unreadable: " + ($readFailed -join ', '))
    Note 'ISSUE' $readFailed.Count
}
else {
# Each probe is TRUE when the duplication EXISTS - that is the failure state.
$probes = [ordered]@{
    'agent hardcodes a roster count'      = $agent -match '\b\d+ (known|not delegatable|delegatable\b)'
    'audit skill hardcodes a roster count' = $auditText -match '\b\d+ (known|live)\b'
    'capture-lesson restates the evidence rule' = $lessonText -match 'never guess'
    'agent restates the delegation table' = ($agent -split 'roster.json').Count -gt 3
    'agent lost the detail-levels pointer' = $agent -notmatch 'detail-levels\.md'
    'agent copies the detail-level rules' = $agent -match 'enum is closed|terse is deterministic'
}
# A variable used under two different capitalisations is the same variable in PowerShell, and a type
# constraint or a null assignment then silently clobbers the other use. It cost two debug cycles in
# this file alone ($store/[string]$Store, and $TK/$tk), so it is detected rather than remembered.
$selfPath = $PSCommandPath
if ($selfPath -and (Test-Path $selfPath)) {
    $seen = @{}
    $clash = @()
    # Guarded for the same reason as the reads above: a failed read skipped the loop body, found no
    # clash, and printed OK - a silent pass on the check that exists to catch a silent pass.
    $selfLines = @()
    try { $selfLines = [System.IO.File]::ReadAllLines($selfPath, [System.Text.Encoding]::UTF8) }
    catch { Write-Output ('  ISSUE   cannot read own source for the collision probe: ' + $_.Exception.GetType().Name); Note 'ISSUE' 1 }
    foreach ($line in $selfLines) {
        if ($line.TrimStart().StartsWith('#')) { continue }
        foreach ($m in [regex]::Matches($line, '\$([A-Za-z_][A-Za-z0-9_]*)')) {
            $n = $m.Groups[1].Value
            $lower = $n.ToLower()
            if ($seen.ContainsKey($lower)) { if ($seen[$lower] -cne $n) { $clash += ($seen[$lower] + '/' + $n) } }
            else { $seen[$lower] = $n }
        }
    }
    $probes['a variable is used under two capitalisations (' + (@($clash | Sort-Object -Unique) -join ', ') + ')'] = (@($clash).Count -gt 0)
}
foreach ($k in $probes.Keys) {
    if (-not $Summary -or $probes[$k]) {
        Write-Output ("  {0} {1}" -f $(if ($probes[$k]) { 'DUP     ' } else { 'OK      ' }), $k)
    }
}
if ($Summary) { Write-Output ("  duplication probes: {0} of {1} flagged" -f @($probes.Keys | Where-Object { $probes[$_] }).Count, $probes.Count) }
Ran 'probes' $probes.Count
Note 'DUP' @($probes.Keys | Where-Object { $probes[$_] }).Count
}
}

Line '3b. Every skill a repository file names is a skill that can be loaded'
# Measured 2026-11-16: nine skills were deleted on purpose and the agent file still said
# "`surgical-patch` (bug fix) vs `safe-refactor` (structure) vs `tdd` (test-first)" in three places.
# Nothing noticed, because a skill name in prose is just text - and the instruction it carries fails
# at the moment an agent tries to follow it, which is the worst time. Only repository-owned files are
# checked: the user's own skills may legitimately name a skill that a VS Code extension ships, and
# those live under no loader root this script knows about.
if (-not $repoOk) {
    Skip 'kit repository not found - nothing to check for named skills'
} else {
    $installedSkills = @{}
    $skillRootsSeen = 0
    foreach ($r in @($SK, "$env:USERPROFILE\.agents\skills")) {
        if (-not (Test-Path $r)) { continue }
        $skillRootsSeen++
        foreach ($d in Get-ChildItem $r -Directory -ErrorAction SilentlyContinue) { $installedSkills[$d.Name] = $true }
    }
    if ($skillRootsSeen -eq 0) {
        Skip 'no skill root found - cannot tell which skill names resolve'
    } else {
        $namedFiles = @()
        $namedFiles += @(Get-ChildItem (Join-Path $REPO 'agents') -File -Filter '*.agent.md' -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
        $namedFiles += @(Get-ChildItem (Join-Path $REPO 'skills') -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { Join-Path $_.FullName 'SKILL.md' } | Where-Object { Test-Path $_ })
        # A skill table is not prose: `| ABAP style | `abap-code-review` |` has no "use" before the
        # name, so the regex above walked straight past it. Measured 2026-11-18 on the new
        # sap-evidence-audit skill: three dead handoffs in one table, and this section reported
        # "all resolve". Scan table rows too, but only in repository-owned SKILL.md files - agent
        # tables name MCP servers and tools, which are not skills and must not be reported here.
        $gateTableRx = '`([a-z0-9]+(?:-[a-z0-9]+)+)`'
        # Status words that look like skill names but are not skills. Keep this list short and
        # explicit; a tool like abaplint has no hyphen and cannot match the pattern at all.
        $gateNonSkill = @{}
        foreach ($gateToken in @('pending-test', 'not-applicable', 'in-progress')) { $gateNonSkill[$gateToken] = $true }
        # Self-test the guard, not just the regex: the synthetic prose line must be ignored while
        # the table line yields one token. Without this, a broken guard prints a healthy zero.
        $gateSelfLines = @('| Question | Go to |', '| x | `no-such-skill-here` |', 'Use `no-such-skill-here` here')
        $gateSelfHits = @()
        foreach ($gateLine in $gateSelfLines) {
            if ($gateLine -notmatch '^\s*\|') { continue }
            foreach ($gateMatch in [regex]::Matches($gateLine, $gateTableRx)) { $gateSelfHits += $gateMatch.Groups[1].Value }
        }
        if (($gateSelfHits -join ',') -ne 'no-such-skill-here') {
            Write-Output '  ISSUE   named-skill table self-test failed - the table scan cannot be trusted'
            Note 'ISSUE' 1
        }
        $gateSeen = @{}
        $dangling = @(); $named = 0; $namedRead = 0
        foreach ($f in $namedFiles) {
            $nt = $null
            try { $nt = [System.IO.File]::ReadAllText($f, [System.Text.Encoding]::UTF8) } catch { continue }
            $namedRead++
            foreach ($m in [regex]::Matches($nt, '(?i)(?:load|loads|loading|use|using|skill)\s+`([a-z0-9]+(?:-[a-z0-9]+)+)`')) {
                $n2 = $m.Groups[1].Value
                $gateKey = $f + '|' + $n2
                if ($gateSeen.ContainsKey($gateKey)) { continue }
                $gateSeen[$gateKey] = $true
                $named++
                if (-not $installedSkills.ContainsKey($n2)) { $dangling += ((Split-Path $f -Leaf) + ' -> ' + $n2) }
            }
            # Tables only in SKILL.md. The file list already holds only repo-owned files, so a hit
            # here is always something this repository can fix.
            if ($f -like (Join-Path $REPO 'skills\*')) {
                foreach ($gateLine in ($nt -split "`r?`n")) {
                    if ($gateLine -notmatch '^\s*\|') { continue }
                    foreach ($gateMatch in [regex]::Matches($gateLine, $gateTableRx)) {
                        $gateToken = $gateMatch.Groups[1].Value
                        if ($gateNonSkill.ContainsKey($gateToken)) { continue }
                        $gateKey = $f + '|' + $gateToken
                        if ($gateSeen.ContainsKey($gateKey)) { continue }
                        $gateSeen[$gateKey] = $true
                        $named++
                        if (-not $installedSkills.ContainsKey($gateToken)) { $dangling += ((Split-Path $f -Leaf) + ' -> ' + $gateToken) }
                    }
                }
            }
        }
        $dangling = @($dangling | Sort-Object -Unique)
        foreach ($d in $dangling) { Write-Output ("  ISSUE   names a skill that is not installed: " + $d) }
        if ($dangling.Count -eq 0) {
            Write-Output ("  {0} named skill(s) across {1} repository file(s) all resolve" -f $named, $namedRead)
        }
        Ran 'named-skills' $named
        Note 'ISSUE' $dangling.Count
        if ($namedRead -eq 0) { Write-Output '  ISSUE   no repository file could be read to check its skill names'; Note 'ISSUE' 1 }
    }
}

Line '3c. Write gate survives edits to the agent and plan template'
# The write gate was added after runtime probes verified hash detection and CAS rejection on
# 2026-11-19. It is behaviour, not documentation: if a later edit drops it, the agent silently
# returns to unguarded writes. Each signal is cheap and independent so a partial deletion is named.
$writeGateFile = "$AG\abap-developer-by-pongg.agent.md"
$planTemplateFile = Join-Path $REPO 'templates\plan.md'
$gateInputs = @($writeGateFile, $planTemplateFile)
$gateMissing = @($gateInputs | Where-Object { -not (Test-Path $_) })
if ($gateMissing.Count -gt 0) {
    foreach ($m in $gateMissing) { Write-Output ("  ISSUE   write-gate input missing: " + $m) }
    Note 'ISSUE' $gateMissing.Count
} else {
    $wgAgent = $null; $wgPlan = $null
    $wgReadFailed = @()
    try { $wgAgent = [System.IO.File]::ReadAllText($writeGateFile, [System.Text.Encoding]::UTF8) } catch { $wgReadFailed += 'agent' }
    try { $wgPlan = [System.IO.File]::ReadAllText($planTemplateFile, [System.Text.Encoding]::UTF8) } catch { $wgReadFailed += 'plan' }
    if ($wgReadFailed.Count -gt 0) {
        Write-Output ("  ISSUE   write-gate input unreadable: " + ($wgReadFailed -join ', '))
        Note 'ISSUE' $wgReadFailed.Count
    } else {
        $wgChecks = [ordered]@{
            'agent lost the fresh-read precondition' = $wgAgent -notmatch 'Write gate: the commit window'
            'agent lost expectedSourceHash'          = $wgAgent -notmatch 'expectedSourceHash'
            'agent lost the unsupported-CAS gate'    = $wgAgent -notmatch 'no\s+precondition, use an explicit human gate'
            'agent lost OUTCOME_UNKNOWN'             = $wgAgent -notmatch 'OUTCOME_UNKNOWN'
            'agent lost the anti-loop budget'        = $wgAgent -notmatch 'Anti-loop budget'
            'plan lost locator + hash engine'        = $wgPlan -notmatch 'locator \+ hash engine per object'
        }
        foreach ($k in $wgChecks.Keys) {
            if (-not $Summary -or $wgChecks[$k]) {
                Write-Output ("  {0} {1}" -f $(if ($wgChecks[$k]) { 'ISSUE   ' } else { 'OK      ' }), $k)
            }
        }
        $wgBad = @($wgChecks.Keys | Where-Object { $wgChecks[$_] }).Count
        Ran 'write-gate' $wgChecks.Count
        Note 'ISSUE' $wgBad
    }
}

Line '4. Memory budget and shape'
if (-not (Test-Path $MEM)) {
    Write-Output ("  SKIP    user memory folder not found: " + $MEM)
} else {
$tot = 0; $rules = 0; $facts = 0
$memRead = 0
foreach ($f in Get-ChildItem $MEM -File -Filter *.md) {
    $t = $null
    try { $t = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8) }
    catch { Write-Output ("  ISSUE   unreadable memory file: " + $f.Name); Note 'ISSUE' 1; continue }
    $memRead++
    $tot += Get-RealLineCount $t
    foreach ($l in ($t -split "`r?`n")) {
        if ($l -match '^\s*[-*]\s' -and $l -match '\b(never|always|do not|prefer|ask|verify)\b') { $rules++ }
        elseif ($l -match '^\s*[-*]\s') { $facts++ }
    }
}
$over = $tot - 200
# Self-test, because this arithmetic had no gate and was therefore wrong on every run. A helper that
# is only ever called from the place it was written for is not tested at all.
$lcProbe = @((Get-RealLineCount "a`nb`n"), (Get-RealLineCount "a`r`nb"), (Get-RealLineCount ''), (Get-RealLineCount 'a'))
if (($lcProbe -join ',') -ne '2,2,0,1') { Write-Output ("  ISSUE   line-count self-test failed: " + ($lcProbe -join ',')); Note 'ISSUE' 1 }
Write-Output ("  used={0}/200 lines  headroom={1}  rule-bullets={2}  fact-bullets={3}" -f $tot, (0 - $over), $rules, $facts)
# Coverage, in this branch specifically. The section had no Ran call at all, so an empty memory
# folder printed used=0/200 and the verdict could not tell it from a memory that was read and fine.
Ran 'memory.budget' $memRead
if ($memRead -eq 0) {
    Write-Output '  ISSUE   the user memory folder holds no .md files'
    Note 'ISSUE' 1
}
# The budget is the one number in this file that is a limit rather than a report. Exceeding it used to
# print a negative headroom and still exit 0, which is a check that cannot fail.
if ($over -gt 0) {
    Write-Output ("  ISSUE   user memory exceeds the 200-line budget by {0}" -f $over)
    Note 'ISSUE' 1
}
}

Line '5. Repo facts: counts that could rot'
$rosterPath = "$env:USERPROFILE\.copilot\roster.json"
# Defined before the roster is read. It used to be created only inside the success branch, so a
# roster that failed to parse left it undefined and section 5b reported every installed toolkit
# agent as "not in roster" - one parse error became N spurious findings.
$known = @()
$rosterOk = $false
if (-not (Test-Path $rosterPath)) {
    Write-Output ("  ISSUE   roster not found: " + $rosterPath)
    Note 'ISSUE' 1
} else {
$roster = $null
$parseFailed = $false
try { $roster = Get-Content $rosterPath -Raw | ConvertFrom-Json }
catch { $parseFailed = $true; Write-Output '  ISSUE   roster.json is not valid JSON'; Note 'ISSUE' 1 }
# `false`, `0`, `""` and `[]` all parse without error and are falsy, and null never has the two
# arrays. The test is on the shape, not on truthiness: only something carrying `delegatable` or
# `not_delegatable` can answer the question this section asks.
#
# The null branch used to print an ISSUE without counting it, and it also fired after the catch above,
# so one broken file produced two ISSUE lines and one count. Both are fixed: the branch is skipped
# when the parse already failed, and it Notes what it prints.
if (-not $parseFailed -and $null -eq $roster) {
    Write-Output '  ISSUE   roster.json parsed to nothing'
    Note 'ISSUE' 1
}
elseif (-not $parseFailed -and -not ($roster.PSObject.Properties.Name -contains 'delegatable') -and -not ($roster.PSObject.Properties.Name -contains 'not_delegatable')) {
    Write-Output '  ISSUE   roster.json has neither delegatable nor not_delegatable'
    Note 'ISSUE' 1
}
elseif (-not $parseFailed) {
# `$known` stays FILE STEMS only. Adding the display names here would make every display name look
# like an agent that is installed nowhere, and GONE would report three false positives. Guarded for
# null so a roster entry carrying only a display does not inject an empty entry.
# Both spellings, because the roster's own comment permits `file` (or `files`) and the hook supports
# both. Reading only `.file` on the allow side meant a valid roster written with files:[...] made
# section 5 report its installed agents as GONE and section 5b raise "toolkit agent not in roster" -
# a false exit 1 from exactly the asymmetry F-035 fixed in the hook. Measured 2026-11-16 by adding a
# files:[...] entry to a copy of the roster.
foreach ($d in $roster.delegatable) {
    if (-not $d) { continue }
    if ($d.file) { $known += $d.file }
    foreach ($f in @($d.files)) { if ($f) { $known += $f } }
}
foreach ($g in $roster.not_delegatable) {
    if (-not $g) { continue }
    if ($g.file) { $known += $g.file }
    foreach ($f in @($g.files)) { if ($f) { $known += $f } }
}
# An empty allowlist is not a usable roster: it would make every installed toolkit agent "not in
# roster", which is the roster's defect reported N times as the toolkit's.
if ($known.Count -gt 0) { $rosterOk = $true }
else { Write-Output '  ISSUE   roster.json lists no agents at all'; Note 'ISSUE' 1 }
$live = @(Get-ChildItem $AG -Filter *.agent.md -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer } | ForEach-Object { $_.Name -replace '\.agent\.md$', '' })
Write-Output ("  roster known={0} live={1} NEW={2} GONE={3}" -f $known.Count, $live.Count, @($live | Where-Object { $known -notcontains $_ }).Count, @($known | Where-Object { $live -notcontains $_ }).Count)
# GONE is a defect: the roster names an agent that is not installed. NEW is a decision pending -
# a human has to classify it - so it is reported but does not fail the run.
Ran 'roster' $live.Count
Note 'ISSUE' @($known | Where-Object { $live -notcontains $_ }).Count
}
}

Line '5b. SAP AI Dev Toolkit: does the roster still cover what it installs?'
# The toolkit gains agents and skills when it is upgraded, so a number written in prose goes
# stale on its own. Derive everything from its own manifest instead of assuming a count.
#
# The local is $tkDoc, not $tk: PowerShell variable names are case-insensitive, so `$tk` and `$TK`
# are the SAME variable. `$tk = $null` therefore cleared the path before it was read, every run, and
# the section reported "toolkit manifest is not valid JSON" for a file that parses perfectly. That
# trap is listed in this repository's own guidance and it still cost a debug cycle.
$TK = "$env:USERPROFILE\.copilot\.sap-ai-dev-toolkit-assets.json"
if (-not (Test-Path $TK)) {
    Write-Output '  no toolkit manifest - nothing to reconcile'
    # An optional input that is absent is a decision that was examined, not a section that ran nothing.
    # Counting it as 0 made the verdict "inconclusive" (exit 2) on every machine without the toolkit,
    # with no way to reach a clean run - a gate that can only fail is as useless as one that cannot.
    Ran 'toolkit' 1
} else {
    $tkDoc = $null
    try { $tkDoc = Get-Content $TK -Raw | ConvertFrom-Json }
    catch { Write-Output '  ISSUE   toolkit manifest is not valid JSON'; Note 'ISSUE' 1 }
    $map = if ($tkDoc) { @($tkDoc.files)[0] } else { $null }
    $tkAgents = @(); $tkSkills = @(); $hashDrift = @(); $gone = @(); $parkedGone = @(); $removedGone = @(); $removedBack = @()
    # Declared deletions, keyed by the manifest's own spelling so the comparison cannot drift.
    $declaredRemoved = @{}
    foreach ($r in @(if ($removedDoc) { $removedDoc.toolkit_skills })) {
        if ($r -and $r.name) { $declaredRemoved['skills\' + $r.name + '\SKILL.md'] = [string]$r.reason }
    }
    foreach ($p in @(if ($map) { $map.PSObject.Properties })) {
        if ($p.Name -like 'agents\*') { $tkAgents += ($p.Name -replace '^agents\\', '' -replace '\.agent\.md$', '') }
        elseif ($p.Name -like 'skills\*') { $tkSkills += @(($p.Name -split '\\')[1]) }
        $f = Join-Path "$env:USERPROFILE\.copilot" $p.Name
        if (-not (Test-Path $f)) {
            # A file the toolkit installed but which is deliberately parked is not missing - it is
            # where a human put it. Section 2b reports parking as its own state; this section must not
            # count the same decision as a defect, or the audit can never pass once a skill is parked.
            $parkedCopy = Join-Path "$env:USERPROFILE\.copilot\skills-disabled" ($p.Name -replace '^skills\\', '')
            if ($p.Name -like 'skills\*' -and (Test-Path $parkedCopy)) { $parkedGone += $p.Name; continue }
            # A declared deletion is a third designed state, and it is the one SETUP-NEW-MACHINE.md
            # section 7 creates on purpose. Without this branch that documented step made the
            # documented "must exit 0" impossible on every machine, for ever - the operator could
            # not tell a correct deletion from a broken install.
            if ($declaredRemoved.ContainsKey($p.Name)) { $removedGone += $p.Name; continue }
            $gone += $p.Name; continue
        }
        # ...and the reverse: a file the owner deleted that a reinstall put back. That is not a
        # missing file, it is the token cost coming back, so it is reported with the reason that
        # justified deleting it in the first place.
        if ($declaredRemoved.ContainsKey($p.Name)) { $removedBack += $p.Name }
        # An unreadable file threw here and left the drift count at zero, so a locked file read as
        # "not edited since install". Reading is guarded and reported as drift instead.
        try { $actual = (Get-FileHash $f -Algorithm SHA256).Hash.ToLower() }
        catch { $hashDrift += ($p.Name + ' (unreadable)'); continue }
        if ($actual -ne $p.Value) { $hashDrift += $p.Name }
    }
    # An agent the toolkit installs that the roster has not decided about is the failure case:
    # it stays non-delegatable by default-deny, so nobody notices it is undocumented. When the
    # roster itself could not be read, comparing against an empty list would blame the toolkit for
    # the roster's defect, so the comparison is skipped and said to be skipped.
    Write-Output ("  toolkit installs: {0} agents, {1} skills" -f $tkAgents.Count, $tkSkills.Count)
    if (-not $rosterOk) {
        Skip 'roster unreadable - cannot tell which toolkit agents are undecided'
    } else {
        $undecided = @($tkAgents | Where-Object { $known -notcontains $_ })
        if ($undecided.Count -eq 0) {
            Write-Output '  OK      every toolkit agent appears in the roster'
        } else {
            foreach ($u in $undecided) { Write-Output ("  ISSUE   toolkit agent not in roster: " + $u) }
        }
        Note 'ISSUE' $undecided.Count
    }
    Write-Output ("  {0} toolkit files edited since install, {1} missing{2}" -f $hashDrift.Count, $gone.Count, $(if ($parkedGone.Count -gt 0) { ", $($parkedGone.Count) parked on purpose" } else { '' }))
    foreach ($h in $hashDrift) { Write-Output ("          EDITED  " + $h) }
    foreach ($g in $gone) { Write-Output ("          MISSING " + $g) }
    if ($removedGone.Count -gt 0) {
        Write-Output ("          removed on purpose: {0} (declared in tooling\removed-on-purpose.json)" -f ($removedGone -join ', '))
    }
    foreach ($rb in $removedBack) {
        $why = $declaredRemoved[$rb]
        Write-Output ("  ISSUE   declared deleted but reinstalled: " + $rb)
        Write-Output ("          reason it was deleted: " + $why)
    }
    Note 'ISSUE' $removedBack.Count
    Ran 'toolkit' $tkAgents.Count
    Note 'ISSUE' ($hashDrift.Count + $gone.Count)
}

Line '5c. The subagent gate answers the names the harness actually sends'
# The roster is an allowlist, so the hook must recognise the SAME string the harness puts in the
# event. It did not: normalise() stripped a " by pongg" suffix that exists only in the display name,
# while the roster is keyed on file stems - so every allowlisted agent fell through to "not listed in
# roster.json" and was restricted. This machine's own log recorded it on 2026-11-15:
#   restricted  SAP ABAP Reverse Engineering Analyst by Pongg  agent is not listed in roster.json
# No amount of reading the code finds that, because both sides look right on their own. So the check
# runs the hook with the shapes the product sends and compares the verdict with the roster.
$hookFile = "$env:USERPROFILE\.copilot\hooks\subagent-rules.cjs"
if (-not (Test-Path $hookFile)) { $hookFile = Join-Path $REPO 'hooks\subagent-rules.cjs' }
if (-not $node) {
    Skip 'node is not on PATH - the gate cannot be exercised'
}
elseif (-not (Test-Path $hookFile)) {
    Skip 'subagent-rules.cjs not found - nothing to exercise'
}
elseif (-not $rosterOk) {
    Skip 'roster unreadable - no expected verdicts to compare against'
}
else {
    # The hook reads $HOME\.copilot\roster.json and appends its own log, so the probes run against a
    # throwaway home holding a copy of the live roster. Nothing outside that folder is touched.
    # A killed run never reaches the finally below, so every hard-stopped audit left its probe home in
    # TEMP for ever. Measured 2026-11-16: hookprobe-15060 survived a Ctrl+C the night before, with two
    # files in it. Sweep the stale ones only - a concurrent run's home is minutes old, not hours.
    # Age alone is not enough: a directory's timestamp does not advance when a file is written into a
    # SUBdirectory, and the hook writes its log that way. Measured 2026-11-16: a subdirectory write
    # left the parent's LastWriteTime unchanged. So a run alive for over an hour would have had its
    # home deleted by another run's sweep, and its remaining probes would then read no roster and
    # report a trusted agent as RESTRICTED - a false exit 1 from a clean tree. The PID is in the name;
    # if that process is alive, skip it.
    Get-ChildItem ([System.IO.Path]::GetTempPath()) -Directory -Filter 'hookprobe-*' -ErrorAction SilentlyContinue |
        Where-Object {
            if ($_.LastWriteTime -ge (Get-Date).AddHours(-1)) { return $false }
            $suffix = $_.Name -replace '^hookprobe-', ''
            if ($suffix -match '^\d+$') { return -not [bool](Get-Process -Id ([int]$suffix) -ErrorAction SilentlyContinue) }
            return $true
        } |
        ForEach-Object { Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }
    $probeHome = Join-Path ([System.IO.Path]::GetTempPath()) ('hookprobe-' + $PID)
    New-Item -ItemType Directory -Force -Path (Join-Path $probeHome '.copilot') | Out-Null
    Copy-Item $rosterPath (Join-Path $probeHome '.copilot\roster.json') -Force
    $cases = @()
    foreach ($d in $roster.delegatable) {
        $names = @()
        if ($d.file) { $names += [string]$d.file }
        foreach ($f in @($d.files)) { if ($f) { $names += [string]$f } }
        foreach ($n in $names) {
            $cases += , @($n, $true)
            $cases += , @(($n + '-evil'), $false)
        }
        foreach ($x in @(@($d.display) + @($d.displays))) {
            if (-not $x) { continue }
            $cases += , @([string]$x, $true)
            # The hook ALSO accepts the display with its " by <author>" suffix stripped, because the
            # harness spells the coordinator's name that way. On the allow list that extra key is a
            # permission the roster never granted: an agent installed as `<display minus " by X">`
            # was trusted without appearing in the roster, which contradicts the hook's own stated
            # rule. Probe it and expect RESTRICTED, unless the roster itself names it.
            $derived = ([string]$x -replace '\s+by\s+.*$', '')
            $derivedKey = ($derived.ToLower() -replace '[^a-z0-9]+', '-').Trim('-')
            if ($derived -ne [string]$x -and $derivedKey -and $known -notcontains $derivedKey) {
                $cases += , @($derived, $false)
            }
        }
    }
    $cases += , @('no-such-agent-by-pongg', $false)
    $cases += , @('', $false)
    # subagent-rules.cjs accepts five spellings of the agent-name field but the main probe above
    # only sends agent_type. A regression in any other alias would pass this gate until a real
    # delegation failed. Add one trusted and one denied case for each remaining spelling, rather
    # than multiplying every roster case by five: the roster semantics are already covered above,
    # and four node spawns per alias would add seconds to every audit for no extra verdict.
    $aliasFields = @('agentType', 'agentName', 'agent_name', 'agent_id')
    $aliasKnown = [string]$roster.delegatable[0].file
    foreach ($field in $aliasFields) {
        $cases += , @($aliasKnown, $true, $field)
        $cases += , @(($aliasKnown + '-evil'), $false, $field)
    }
    $savedHome = $env:USERPROFILE
    $wrong = 0
    try {
        $env:USERPROFILE = $probeHome
        # Sequential, and measured twice before it stayed that way. Section 5c is the slowest section
        # in the audit - 786 ms of a 2,081 ms run when it was first instrumented, and still about a
        # quarter of the run at 505 items - and the obvious fix is to overlap the probes.
        # Built and measured, 2026-11-16: 14 node children started together through .NET Process with
        # redirected streams (no temp file, no runspace, ~1.2 KB of output each so no pipe can block).
        # In isolation it was 3.5x faster - 2,435 -> 697 ms - and inside the audit it made the whole
        # run 51% SLOWER: 2,070 -> 3,119 ms median, interleaved A/B, three pairs each. The isolated win
        # came from an empty HOME that the hook reads once; in the audit each probe reads the roster,
        # and fourteen concurrent starts contend for one disk and one CPU rather than overlapping I/O.
        # So the sequential form stays, and the honest reason is that the alternative was tried.
        foreach ($c in $cases) {
            $name = [string]$c[0]
            $field = if ($c.Count -gt 2) { [string]$c[2] } else { 'agent_type' }
            $escaped = $name.Replace('\', '\\').Replace('"', '\"')
            $payload = '{"hookEventName":"SubagentStart","' + $field + '":"' + $escaped + '"}'
            $out = ''
            try { $out = (($payload | & $node.Source $hookFile) -join '') } catch { $out = '' }
            $plainLabel = if ($name -eq '') { '(empty)' } else { $name }
            $label = if ($field -eq 'agent_type') { $plainLabel } else { $field + ':' + $plainLabel }
            # An empty or unparseable answer is not a verdict. Treating "no Restricted text" as trusted
            # made the gate report success precisely when the hook had crashed - the same shape of
            # mistake as a read that leaves the previous value behind.
            $trusted = $false; $answered = $false
            try {
                $verdictJson = $out | ConvertFrom-Json
                $ctx = $verdictJson.hookSpecificOutput.additionalContext
                if ($ctx) { $answered = $true; $trusted = ($ctx -notmatch 'Restricted delegation context') }
            }
            catch { $answered = $false }
            if (-not $answered) {
                Write-Output ("  ISSUE   '{0}': the hook returned no verdict" -f $label)
                $wrong++
                continue
            }
            if ($trusted -ne [bool]$c[1]) {
                $want = if ([bool]$c[1]) { 'trusted' } else { 'restricted' }
                Write-Output ("  ISSUE   '{0}' should be {1}" -f $label, $want)
                $wrong++
            }
            elseif (-not $Summary) {
                Write-Output ("  OK      '{0}' -> {1}" -f $label, $(if ($trusted) { 'trusted' } else { 'restricted' }))
            }
        }
    }
    finally {
        $env:USERPROFILE = $savedHome
        Remove-Item $probeHome -Recurse -Force -ErrorAction SilentlyContinue
    }
    if ($wrong -eq 0) { Write-Output ("  {0} probe(s) matched the roster" -f $cases.Count) }
    Ran 'subagent-gate' $cases.Count
    Note 'ISSUE' $wrong
}

Line '6. Repo memory: does it duplicate the agent?'
$rmN = 0; $rmMirror = 0
if (-not $awsOk) {
    Write-Output '  SKIP    repo memory not found (set $env:ABAP_REPO_MEMORY, or open a workspace with notes)'
} else {
foreach ($f in Get-ChildItem "$AWS" -Recurse -File -Filter *.md) {
    # The last unguarded read in a loop. Under EAP=Continue a failed ReadAllText is only
    # statement-terminating: $t keeps the PREVIOUS file's text and the rest of the body still runs, so
    # a locked file was reported with another file's verdict while stderr held the IOException.
    $t = $null
    try { $t = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8) }
    catch { Write-Output ("  ISSUE   unreadable repo-memory file: " + $f.Name); Note 'ISSUE' 1; continue }
    # (?m) is required: without it ^ anchors at the start of the whole string, so a table row on any
    # line but the first never matched - the probe had been dead since it was written.
    #
    # A mention of a server name is not a routing table. The row has to START with the server or tool
    # name, which is how every row of the real table in the agent file begins. Matching any row that
    # merely contains "ARC-1" flagged an index line that only says where the password pipeline is
    # documented, and a probe that fires on prose is a probe someone turns off.
    $mirror = $t -match '(?m)^\|\s*`?(arc-1|adt-mcp-server|murbani\.vscode-abap-remote-fs|SAPRead|SAPWrite|SAPSearch|SAPContext)\b'
    $dated = $t -match 'verified \d{4}-\d{2}-\d{2}'
    $rmN++; if ($mirror) { $rmMirror++ }
    if (-not $Summary -or $mirror) {
        Write-Output ("  {0,-40} mirrors_table={1,-5} dated={2}" -f $f.Name, $mirror, $dated)
    }
}
if ($Summary) { Write-Output ("  {0} repo-memory files, {1} mirror the agent table" -f $rmN, $rmMirror) }
Ran 'memory' $rmN
# A memory file that restates the routing table is a second home for a rule that already lives in
# the agent. It was detected and then dropped on the floor: the number was printed, nothing counted it.
Note 'ISSUE' $rmMirror

# A note that nothing points at is the same as no note. Measured 2026-11-15: the most expensive
# file in this folder (a 14.5 KB reverse-engineering deliverable) was named in no index and read by
# no skill, so it was effectively invisible for the 11 days it existed.
$rmIndex = Join-Path $AWS 'INDEX.md'
if (Test-Path $rmIndex) {
    # $null -notmatch <anything> is True, so an unreadable index reported every file as an orphan.
    $idxText = $null
    try { $idxText = [System.IO.File]::ReadAllText($rmIndex, [System.Text.Encoding]::UTF8) }
    catch { Write-Output ('  ISSUE   INDEX.md is unreadable: ' + $_.Exception.GetType().Name); Note 'ISSUE' 1 }
    $orphans = @()
    if ($null -ne $idxText) {
    foreach ($f in Get-ChildItem $AWS -Recurse -File -Filter *.md) {
        if ($f.Name -eq 'INDEX.md') { continue }
        $rel = ($f.FullName.Substring($AWS.Length).TrimStart('\') -replace '\\', '/')
        if ($idxText -notmatch [regex]::Escape($f.Name) -and $idxText -notmatch [regex]::Escape($rel)) {
            $orphans += $rel
        }
    }
    }
    if ($orphans.Count -eq 0) {
        Write-Output '  OK      every repo-memory file is named in INDEX.md'
    } else {
        foreach ($o in $orphans) { Write-Output ("  ISSUE   repo-memory file not in INDEX.md: " + $o) }
    }
    Note 'ISSUE' $orphans.Count
} else {
    Write-Output '  ISSUE   repo memory has no INDEX.md'
    Note 'ISSUE' 1
}

# A file that exists both in repo memory and in a Projects program folder is two homes for one fact.
# It happened for real: a record was moved to its program, deleted from memory, and came back - the
# index still said "Moved out" while the file sat there, so the index and the folder disagreed.
$dupInProjects = @()
if ($repoOk) {
    $projDocs = @(Get-ChildItem (Join-Path $REPO 'Projects') -Recurse -File -Filter *.md -ErrorAction SilentlyContinue)
    foreach ($f in Get-ChildItem $AWS -Recurse -File -Filter *.md -ErrorAction SilentlyContinue) {
        if ($f.Name -eq 'INDEX.md') { continue }
        $mine = $null
        try { $mine = ([System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8) -replace "`r`n", "`n") } catch { continue }
        if ($mine.Length -lt 200) { continue }
        foreach ($p in $projDocs) {
            $theirs = $null
            try { $theirs = ([System.IO.File]::ReadAllText($p.FullName, [System.Text.Encoding]::UTF8) -replace "`r`n", "`n") } catch { continue }
            if ($theirs.Contains($mine)) {
                $dupInProjects += ($f.Name + ' == ' + $p.FullName.Substring($REPO.Length).TrimStart('\'))
                break
            }
        }
    }
}
if ($dupInProjects.Count -gt 0) {
    foreach ($d in $dupInProjects) { Write-Output ("  ISSUE   same content in repo memory and Projects: " + $d) }
    Note 'ISSUE' $dupInProjects.Count
}
# Registered, because an unregistered check is invisible to the examined-nothing verdict. This block
# only ever printed on a hit, so a run in which it compared nothing was indistinguishable from one in
# which it compared everything and found nothing. $dupInProjects was measured empty on 2026-11-16.
# No Max(1,...) floor: a floor of one makes the registration unable to report zero, which is the exact
# state this line exists to expose. As written before, Ran always got at least 1 and the section could
# never reach the exit-2 list its own comment promised.
Ran 'memory.dup' @(Get-ChildItem $AWS -Recurse -File -Filter *.md -ErrorAction SilentlyContinue).Count
}

Line '7. Git state of the kit'
if (-not $repoOk) {
    Write-Output '  SKIP    kit repository not found (clone it, or set $env:ABAP_KIT_ROOT)'
} else {
Push-Location $REPO
# One git process instead of four, and failure must not read as a pass.
# Measured 2026-11-15: four separate `git rev-parse` calls plus status cost 214 ms; the batched form
# costs 88 ms. More important is the correctness half: `(git rev-parse HEAD) -eq (git rev-parse
# origin/main)` compares $null with $null when git fails, and $null -eq $null is True - so a broken
# repository, a missing origin, or a git that is not on PATH all printed the GOOD state. The same
# shape applied to dirty: `@(git status --porcelain).Count` is 0 when the command failed, so an
# unreadable repository reported zero changes. Both are now read from the exit code first.
$refs = @(git rev-parse HEAD origin/main 2>$null)
$refRc = $LASTEXITCODE
$dirtyLines = @(git status --porcelain 2>$null)
$dirtyRc = $LASTEXITCODE
if ($refRc -ne 0 -or $refs.Count -lt 2 -or $dirtyRc -ne 0) {
    Write-Output ("  ISSUE   git could not report state (rev-parse rc={0}, status rc={1}, {2} ref(s))" -f $refRc, $dirtyRc, $refs.Count)
    Note 'ISSUE' 1
}
else {
    $headFull = [string]$refs[0]
    $origFull = [string]$refs[1]
    # A short hash is a prefix of the full one; --short's collision extension is not reproduced here,
    # because git refuses to batch --short for two revisions (`Needed a single revision`).
    Write-Output ("  HEAD={0}  origin={1}  synced={2}  dirty={3}" -f $headFull.Substring(0, 7), $origFull.Substring(0, 7), ($headFull -eq $origFull), $dirtyLines.Count)
}
$drift = @()
# Every user-owned agent is mirrored, not just the main one. Before this, only
# abap-developer-by-pongg was compared, so an edit to any of the other three agents sat in the
# working tree unnoticed - which is exactly what happened to the reverse-engineer agent.
$agentMirrors = @(Get-ChildItem "$REPO\agents" -Filter '*-by-pongg.agent.md' -ErrorAction SilentlyContinue | ForEach-Object { 'agents\' + $_.Name })
# Skills are derived from the repository, not listed by hand. The list was hardcoded at three names
# and stayed at three while a fourth and fifth skill were added, so a new skill was installed and
# never drift-checked - the exact failure the agent mirror list was made dynamic to avoid.
$skillMirrors = @(Get-ChildItem "$REPO\skills" -Directory -ErrorAction SilentlyContinue |
    Where-Object { Test-Path (Join-Path $_.FullName 'SKILL.md') } |
    ForEach-Object { 'skills\' + $_.Name + '\SKILL.md' })
# Hooks are mirrored too, and were the one folder this section never compared. Measured 2026-11-15: the
# live subagent-rules.cjs was a full version behind the clone - it still ran the fuzzy allowlist a
# previous release replaced - and no section noticed, because the installer had never copied hooks/
# either. A file that runs on every session and is compared nowhere is the worst place to be stale.
$hookMirrors = @(Get-ChildItem "$REPO\hooks" -Filter '*.cjs' -ErrorAction SilentlyContinue | ForEach-Object { 'hooks\' + $_.Name })
$pairs = @() + $agentMirrors + $skillMirrors + $hookMirrors + @('roster.json', 'tooling\verify-all.ps1', 'tooling\measure-context.ps1', 'tooling\who-locks.ps1', 'tooling\sap-secret.ps1', 'tooling\sap-connection.ps1', 'tooling\sap-arc1-launcher.ps1', 'tooling\sap-auth-probe.js', 'tooling\workspace-sync.ps1', 'tooling\install-kit.ps1', 'tooling\findings.json', 'tooling\removed-on-purpose.json')
# findings.json is on the list because install-kit copies it: the installer's tooling filter takes
# every .ps1, .js and .json except surface.json, so the ledger became a live file that no section
# compared. Measured 2026-11-15: the live copy held 26 findings in 14,721 bytes while the clone held
# 26 in 17,834 - a divergence with no DRIFT line, and -Force would have silently replaced the live
# one. A file the installer writes and the audit does not compare is the exact hole hooks/ fell in.
# tooling\surface.json is deliberately absent from the list. It is runtime state: the sessionStart
# hook rewrites the LIVE copy on every run, so comparing it against the repository snapshot would
# report DRIFT forever, from the first session in which the hook fires. A check that can only fail is
# as useless as one that can only pass.
#
# tooling\removed-on-purpose.json was absent for a different reason and a worse one: nothing had ever
# put it on the list. Measured 2026-11-16, the backup folder held a copy that no section compared, so
# the repository could declare an exemption the running hooks never saw - and sections 2b and 9d both
# trust that file to decide whether a deleted skill or a damaged tag is reported or excused. A gate
# whose own exceptions can drift from the file it enforces is enforcing the wrong rules.
$missingLive = @()
$compared = 0
foreach ($rel in $pairs) {
    $src = if ($rel -eq 'roster.json') { "$env:USERPROFILE\.copilot\roster.json" }
           elseif ($rel -like 'agents*') { Join-Path $AG (Split-Path $rel -Leaf) }
           elseif ($rel -like 'hooks*') { Join-Path "$env:USERPROFILE\.copilot\hooks" (Split-Path $rel -Leaf) }
           elseif ($rel -like 'tooling*') { Join-Path "$env:USERPROFILE\.copilot\state" (Split-Path $rel -Leaf) }
           else { Join-Path $SK ($rel -replace 'skills\\', '') }
    if (-not (Test-Path (Join-Path $REPO $rel))) { $missingLive += ($rel + ' (absent from the repository)'); continue }
    if (-not (Test-Path $src)) { $missingLive += ($rel + ' (not installed on this machine)'); continue }
    # Both reads are guarded. An unreadable source file used to throw here and leave $b holding the
    # PREVIOUS pair's text, so the comparison was against the wrong file and the verdict was whatever
    # that produced.
    try {
        $a = [System.IO.File]::ReadAllText((Join-Path $REPO $rel), [System.Text.Encoding]::UTF8) -replace "`r`n", "`n"
        $b = [System.IO.File]::ReadAllText($src, [System.Text.Encoding]::UTF8) -replace "`r`n", "`n"
    }
    catch { $missingLive += ($rel + ' (unreadable: ' + $_.Exception.GetType().Name + ')'); continue }
    $compared++
    # -cne, not -ne. A PowerShell string comparison is case-insensitive by default, so a live file that
    # differed from the repository only in letter case reported "identical". Measured 2026-11-16:
    # 'ABC' -ne 'abc' is False on 5.1.26100, while 'ABC' -cne 'abc' is True. A mirror check that cannot
    # see case cannot be trusted to prove two trees agree.
    if ($a -cne $b) { $drift += $rel }
}
if (@($drift).Count -eq 0 -and $missingLive.Count -eq 0) { Write-Output '  repo mirrors live files: identical' }
else { foreach ($d in $drift) { Write-Output ("  DRIFT: " + $d) }
       foreach ($m in $missingLive) { Write-Output ("  MISSING: " + $m) } }
Ran 'mirror' $compared
Note 'DRIFT' @($drift).Count
Note 'MISSING' $missingLive.Count
Pop-Location
}

Line '8. SAP password in any harness config: literal, or indirection?'
# VS Code supports ${input:...} and the Copilot CLI does not, which is why the two configs are not
# interchangeable. The CLI accepts only --env KEY=VALUE, so its config once held the real password as
# plaintext - invisible to a scan that only looks at the repository. A literal here is an ISSUE
# wherever the file lives.
$configs = [ordered]@{
    'vscode'   = "$env:APPDATA\Code\User\mcp.json"
    'copilot'  = "$env:USERPROFILE\.copilot\mcp-config.json"
}
# A literal is a quoted value on a secret-bearing key that is not ${input:...} and not a
# placeholder. The key list covers what ARC-1 itself reads as a secret (SAP_PASSWORD,
# SAP_COOKIE_STRING, SAP_BTP_SERVICE_KEY, ARC1_API_KEYS, ...) - a narrower list than that was
# measured to miss three of them. Keys ending _FILE hold a path, not a secret, so they are out.
$litRx = '"[A-Za-z0-9_]*(?:PASSWORD|SECRET|TOKEN|COOKIE|SERVICE_KEY|API_KEY|_KEYS|CRED)[A-Za-z0-9_]*(?<!_FILE)"\s*:\s*"(?!\$\{input:)(?!<)[^"]{1,200}"'
# The second syntax, and the reason this section exists at all: the Copilot CLI has no ${input:...}
# support and takes the secret as `"--env", "SAP_PASSWORD=..."`. The JSON-shape regex cannot see
# that - it needs `"KEY":` with a quote after the colon - and the SHAPE check in section 9 needs a
# quote immediately after '=', so a secret in argument form was invisible to BOTH sections while the
# run printed "OK no literal secret" and exited 0. Measured 2026-11-15: an object-form secret scored
# 1 here; the identical secret written as an --env argument pair scored 0 here and 0 in section 9.
$argRx = '(?<![A-Za-z0-9_])(?<k>[A-Za-z0-9_]*(?:PASSWORD|SECRET|TOKEN|COOKIE|SERVICE_KEY|API_KEY|_KEYS|CRED)[A-Za-z0-9_]*)=(?<v>[^"\s,]{1,200})'

# Both detectors are self-tested before they are trusted, because on 2026-11-15 this section twice
# produced a line that was wrong in a way nothing noticed. A detector that cannot fire is worse than
# no detector: "OK no literal secret" is the one line in this toolkit whose being wrong cannot be
# undone once it is pushed.
#
# Four independent assertions, written out. The first version packed them into nested arrays and the
# labels came back as "1" and "0" - which the self-test itself reported as a failure, so the shape was
# wrong in an obvious way rather than a quiet one.
#
# The fixtures are ASSEMBLED, not written as literals. Measured 2026-11-16: the object-form fixture
# that used to sit here was itself scanned by section 9 as a credential-shaped line, because the
# widened shape rule now anchors on `{` and a comma as well as line start. That is the rule working
# correctly on a synthetic string - but a self-test that trips its own gate makes every future run
# red for a non-defect. Joining the pieces at run time keeps the assertion and removes the false hit.
# The comment names the parts and never the whole assignment, for the same reason.
$stKey = 'SAP_' + 'PASSWORD'
$stObjectHit = ([regex]::Matches(('{"env":{"' + $stKey + '":"' + 'hunter2' + 'secret"}}'), $litRx)).Count
$stObjectInd = ([regex]::Matches(('{"env":{"' + $stKey + '":"${input:p}"}}'), $litRx)).Count
$stArgHit = @([regex]::Matches(('["--env","' + $stKey + '=' + 'hunter2' + 'secret"]'), $argRx) | Where-Object { $_.Groups['v'].Value -notmatch '^(\$\{|@secret$|%|<)' }).Count
$stArgInd = @([regex]::Matches(('["--env","' + $stKey + '=${input:p}"]'), $argRx) | Where-Object { $_.Groups['v'].Value -notmatch '^(\$\{|@secret$|%|<)' }).Count
if ($stObjectHit -ne 1) { Write-Output '  ISSUE   secret detector self-test: the object form was not detected'; Note 'ISSUE' 1 }
if ($stObjectInd -ne 0) { Write-Output '  ISSUE   secret detector self-test: ${input:...} was reported as a literal'; Note 'ISSUE' 1 }
if ($stArgHit -ne 1) { Write-Output '  ISSUE   secret detector self-test: the KEY=VALUE form was not detected'; Note 'ISSUE' 1 }
if ($stArgInd -ne 0) { Write-Output '  ISSUE   secret detector self-test: a KEY=${input:...} was reported as a literal'; Note 'ISSUE' 1 }
Ran 'secret-selftest' 4

$credChecked = 0
# Every config that was examined must produce exactly one verdict line. Two versions of this loop
# threw inside the reporting statement - once because ${input:...} expanded to nothing in a
# double-quoted string, once because the same text was a format placeholder for -f and -f threw under
# EAP=Continue, which is statement-terminating - so the detector found the secret and the run printed
# no line about it. Counting the verdicts makes a swallowed finding impossible to miss.
$cfgVerdicts = 0
foreach ($k in $configs.Keys) {
    $p = $configs[$k]
    if (-not (Test-Path $p)) { Write-Output ("  {0,-8} no config" -f $k); $cfgVerdicts++; continue }
    # $t is read inside the guard and reset each iteration. Reading it outside a guard meant a
    # throwing read left the PREVIOUS config's text in $t, so a directory in place of mcp.json
    # produced "OK no literal secret" for a file that was never opened.
    $t = $null
    try { $t = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8) }
    catch { Write-Output ("  {0,-8} ISSUE   unreadable: {1}" -f $k, $_.Exception.GetType().Name); Note 'ISSUE' 1; $cfgVerdicts++; continue }
    $credChecked++
    $lit = [regex]::Matches($t, $litRx)
    $argHits = @()
    foreach ($m in [regex]::Matches($t, $argRx)) {
        $secretKey = $m.Groups['k'].Value
        $val = $m.Groups['v'].Value
        if ($secretKey -match '_FILE$') { continue }
        # ${input:...}, @secret, %VAR%, $env:NAME and <PLACEHOLDER> are indirections, not values.
        if ($val -match '^(\$\{|\$env:|@secret$|%|<)') { continue }
        if ($val -match 'PLACEHOLDER|CHANGEME|xxxx') { continue }
        $argHits += $secretKey
    }
    if ($lit.Count -eq 0 -and $argHits.Count -eq 0) { Write-Output ("  {0,-8} OK      no literal secret" -f $k) }
    else {
        if ($lit.Count -gt 0) {
            Write-Output ("  {0,-8} ISSUE   {1} literal secret field(s) - move to a credential store" -f $k, $lit.Count)
            foreach ($m in $lit) { Write-Output ("           key: " + (($m.Value -split '"')[1])) }
        }
        if ($argHits.Count -gt 0) {
            # Built by concatenation, not with -f. In a double-quoted string "${input:...}" is a
            # variable and expands to empty; in a single-quoted string passed through -f, "{input:...}"
            # is a format placeholder and -f throws. Measured both, 2026-11-15.
            Write-Output ('  ' + $k.PadRight(8) + ' ISSUE   ' + $argHits.Count + ' secret(s) passed as KEY=VALUE - use ${input:...} or a credential store')
            foreach ($a in $argHits) { Write-Output ("           key: " + $a) }
        }
        Note 'HIT' ($lit.Count + $argHits.Count)
    }
    $cfgVerdicts++
}
if ($cfgVerdicts -ne $configs.Count) {
    Write-Output ("  ISSUE   {0} of {1} config(s) produced a verdict - a finding may have been swallowed" -f $cfgVerdicts, $configs.Count)
    Note 'ISSUE' 1
}

# The env file that replaced those literals needs the same check, in a different syntax: a secret
# key whose value is not the @secret marker is a plaintext secret sitting in the user profile.
$envFile = "$env:USERPROFILE\.copilot\state\arc1.env"
if (-not (Test-Path $envFile)) {
    Write-Output '  envfile  absent  (arc1.env not created yet - credential-store mode inactive)'
} else {
    $plainSecrets = @()
    $envLines = @()
    $envReadable = $true
    try { $envLines = [System.IO.File]::ReadAllLines($envFile, [System.Text.Encoding]::UTF8) }
    # The catch used to fall through to the OK branch: an unreadable file printed ISSUE and then
    # "OK every secret line uses @secret" on the next line, because an empty list trivially passes.
    catch { Write-Output ("  envfile  ISSUE   unreadable: " + $_.Exception.GetType().Name); Note 'ISSUE' 1; $envReadable = $false }
    foreach ($l in $envLines) {
        $s = $l.Trim()
        if ($s -eq '' -or $s.StartsWith('#')) { continue }
        $eq = $s.IndexOf('=')
        if ($eq -lt 1) { $plainSecrets += 'malformed: ' + $s; continue }
        $key = $s.Substring(0, $eq).Trim()
        $val = $s.Substring($eq + 1).Trim()
        if ($key -match '(PASSWORD|SECRET|TOKEN|COOKIE|SERVICE_KEY|API_KEY|_KEYS|CRED)' -and
            $key -notmatch '_FILE$' -and $val -ne '@secret' -and $val -ne '') {
            $plainSecrets += $key
        }
    }
    if (-not $envReadable) { }
    elseif ($plainSecrets.Count -eq 0) { Write-Output '  envfile  OK      every secret line uses @secret' }
    else {
        foreach ($s in $plainSecrets) { Write-Output ("  envfile  ISSUE   plaintext secret or bad line: " + $s) }
        Note 'HIT' $plainSecrets.Count
    }

    # And it must not sit inside a repository, where a stray `git add -f` could publish it.
    $dir = Split-Path $envFile -Parent
    $inRepo = $null
    while ($dir -and $dir -ne (Split-Path $dir -Parent)) {
        if (Test-Path (Join-Path $dir '.git')) { $inRepo = $dir; break }
        $dir = Split-Path $dir -Parent
    }
    if ($inRepo) { Write-Output ("  envfile  ISSUE   arc1.env is inside a repository: " + $inRepo); $script:issues++ }
    else { Write-Output '  envfile  OK      outside every repository' }
}

# The connection list replaced the single-credential design. It holds one block per SAP logon, so
# the same two questions apply: is every password a @secret marker, and is the file out of reach of
# a repository.
$connFile = "$env:USERPROFILE\.copilot\state\arc1-connections.json"
if (-not (Test-Path $connFile)) {
    Write-Output '  conns    absent  (arc1-connections.json not created yet)'
} else {
    try { $cj = [System.IO.File]::ReadAllText($connFile, [System.Text.Encoding]::UTF8) | ConvertFrom-Json }
    catch { $cj = $null; Write-Output '  conns    ISSUE   arc1-connections.json is not valid JSON'; $script:issues++ }
    if ($cj) {
        $bad = @()
        foreach ($p in $cj.connections.PSObject.Properties) {
            $pw = $p.Value.password
            if ([string]::IsNullOrEmpty($pw)) { $bad += ($p.Name + ' (no password)') }
            elseif ($pw -ne '@secret') { $bad += ($p.Name + ' (plaintext)') }
            if ($p.Value.url -notmatch '^https?://') { $bad += ($p.Name + ' (bad url)') }
            if ($p.Value.client -notmatch '^\d{2,3}$') { $bad += ($p.Name + ' (bad client)') }
        }
        # A null connections object and an empty one both used to reach the OK branch: the foreach
        # above ran zero times, and @($null.PSObject.Properties).Count is 1, not 0, so the line read
        # "1 connection(s), every password is @secret" for a store with nothing in it. Measured.
        $conns = @($cj.connections.PSObject.Properties | Where-Object { $_ })
        $n = $conns.Count
        if ($n -eq 0) {
            Write-Output '  conns    ISSUE   the store holds no connections'
            $script:issues++
        }
        elseif ($bad.Count -eq 0) { Write-Output ("  conns    OK      {0} connection(s), every password is @secret" -f $n) }
        else {
            foreach ($b in $bad) { Write-Output ("  conns    ISSUE   " + $b) }
            # One connection can be wrong in three ways, and three lines were counted as three
            # problems. A reader needs the count of connections to fix, not of complaints.
            Note 'ISSUE' 1
        }
        if ($cj.active -and -not ($conns.Name -contains $cj.active)) {
            Write-Output ("  conns    ISSUE   active names a missing connection: " + $cj.active)
            $script:issues++
        }
        $dir = Split-Path $connFile -Parent
        $inRepo = $null
        while ($dir -and $dir -ne (Split-Path $dir -Parent)) {
            if (Test-Path (Join-Path $dir '.git')) { $inRepo = $dir; break }
            $dir = Split-Path $dir -Parent
        }
        if ($inRepo) { Write-Output ("  conns    ISSUE   inside a repository: " + $inRepo); $script:issues++ }
    }
}

# Coverage for the whole credential section. Every line above can print "absent"/"no config" and
# reach the verdict having inspected nothing, which reads the same as a pass.
Ran 'credentials' ($credChecked + $(if (Test-Path $connFile) { 1 } else { 0 }))
if ($credChecked -eq 0 -and -not (Test-Path $envFile) -and -not (Test-Path $connFile)) {
    Write-Output '  ISSUE   no credential source found - mcp.json, mcp-config.json, arc1.env and the connection store are all absent'
    Note 'ISSUE' 1
}

# The launcher is what keeps the MCP configs free of a password, so the wiring matters as much as
# the store. Two ways to lose it: the config goes back to a literal password, or it names a
# connection that no longer exists - in which case the server starts and fails at the first SAP call
# instead of at startup, which is much harder to read.
#
# Checked for both harnesses, with one implementation: the Copilot CLI reads mcp-config.json under
# "mcpServers", VS Code reads mcp.json under "servers". The rule has one home.
function Test-LauncherWiring($path, $rootKey, $label) {
    if (-not (Test-Path $path)) {
        # Printed, and also remembered. The line was already honest, but the section then returned
        # before recording coverage - so with both configs absent the run printed "launcher absent"
        # twice and still ended "clean - 444 item(s) verified", a count that silently excluded the
        # launcher wiring. Absent is not a defect; absent being invisible is.
        Write-Output ("  {0,-8} absent  ({1})" -f $label, (Split-Path $path -Leaf))
        $script:launcherAbsent++
        return
    }
    # Coverage is registered through Ran, not by incrementing $script:verified directly. The direct
    # increment inflated the "clean - N item(s)" count while leaving the launcher out of the
    # coverage set, so the examined-nothing verdict could not see it. Measured 2026-11-16: 505 items
    # against a ran-sum of 503, the difference being exactly these two call sites.
    Ran 'launcher' 1
    try { $cfg = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8) | ConvertFrom-Json }
    catch { Write-Output ("  {0,-8} ISSUE   {1} is not valid JSON" -f $label, (Split-Path $path -Leaf)); $script:issues++; return }

    $arc = $cfg.$rootKey.'arc-1'
    if (-not $arc) { Write-Output ("  {0,-8} ISSUE   no arc-1 server in {1}" -f $label, (Split-Path $path -Leaf)); $script:issues++; return }

    $argLine = @($arc.args) -join ' '
    $named = $null
    if ($argLine -match 'sap-arc1-launcher\.ps1') {
        if ($argLine -match '-Connection\s+"?([A-Za-z0-9][A-Za-z0-9_-]*)"?') { $named = $Matches[1] }
    }

    # A bare interpreter name only resolves while its own folder is on PATH. Measured: with a
    # trimmed PATH (sandboxed parent) "powershell" was ENOENT, the server never started, and the
    # only visible symptom was that its tools never appeared. Absolute path, always.
    $cmd = [string]$arc.command
    $cmdIsAbsolute = $cmd -match '^([A-Za-z]:\\|\\\\)'

    if (-not $named) {
        Write-Output ("  {0,-8} ISSUE   arc-1 does not start through sap-arc1-launcher.ps1 -Connection <name>" -f $label); $script:issues++
    }
    elseif (-not $cmdIsAbsolute) {
        Write-Output ("  {0,-8} ISSUE   arc-1 command '{1}' depends on PATH - use the absolute interpreter path" -f $label, $cmd); $script:issues++
    }
    elseif ($arc.env.PSObject.Properties.Name -contains 'SAP_PASSWORD') {
        Write-Output ("  {0,-8} ISSUE   arc-1 still passes SAP_PASSWORD in env" -f $label); $script:issues++
    }
    elseif ($arc.env.PSObject.Properties.Name -contains 'SAP_URL') {
        Write-Output ("  {0,-8} ISSUE   arc-1 still sets SAP_URL in env - the connection store owns that value" -f $label); $script:issues++
    }
    elseif (-not (Test-Path $connFile)) {
        Write-Output ("  {0,-8} ISSUE   names '{1}' but there is no connection store" -f $label, $named); $script:issues++
    }
    else {
        try { $lc = [System.IO.File]::ReadAllText($connFile, [System.Text.Encoding]::UTF8) | ConvertFrom-Json } catch { $lc = $null }
        if (-not $lc) { Write-Output ("  {0,-8} ISSUE   connection store is not valid JSON" -f $label); $script:issues++ }
        elseif (-not ($lc.connections.PSObject.Properties.Name -contains $named)) {
            Write-Output ("  {0,-8} ISSUE   names a connection that does not exist: {1}" -f $label, $named); $script:issues++
        }
        else { Write-Output ("  {0,-8} OK      arc-1 -> launcher -> '{1}', no password in the config" -f $label, $named) }
    }
}

Test-LauncherWiring "$env:USERPROFILE\.copilot\mcp-config.json" 'mcpServers' 'launcher'
Test-LauncherWiring "$env:APPDATA\Code\User\mcp.json" 'servers' 'launcher2'
if ($script:launcherAbsent -eq 2) {
    # Said out loud, because the section's own lines were "absent" and the verdict still counted a
    # clean run. Nothing is wrong on a machine with no MCP config; something is wrong with a report
    # that implies the wiring was checked.
    Write-Output '  WARNING neither MCP config exists - the launcher wiring was NOT verified on this machine'
}

Line '8b. Two MCP config files, one server list (a duplicate is silently disabled)'
# VS Code 1.146 reads %USERPROFILE%\.copilot\mcp-config.json as a discovery source named "copilot",
# and that source is ON by default. When the same server label appears in both files, the setting
# chat.mcp.collisionBehavior decides what happens, and its default is "disable": the second copy is
# disabled at runtime and still listed in the tool picker, as a name that contributes no tools.
# Measured in the shipped workbench bundle on 2026-11-15:
#   Pyo  = {"claude-desktop":!1,"copilot":!0,"windsurf":!1,...}   copilot discovery on by default
#   [ESi]= {enum:["disable","suffix"], default:"disable"}          collision default
#   collision key = serverDefinition.label.toLowerCase()
# So a duplicate is not cosmetic. Either de-duplicate the files or switch the source off.
$vsCfgPath = "$env:APPDATA\Code\User\mcp.json"
$clCfgPath = "$env:USERPROFILE\.copilot\mcp-config.json"
$vsNames = @(); $clNames = @(); $cfgRead = 0
foreach ($pair in @(, @($vsCfgPath, 'servers', 'vscode')) + @(, @($clCfgPath, 'mcpServers', 'cli'))) {
    $path = $pair[0]; $rootKey = $pair[1]; $label = $pair[2]
    if (-not (Test-Path $path)) { Write-Output ("  {0,-8} absent" -f $label); continue }
    $cfg = $null
    try { $cfg = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8) | ConvertFrom-Json }
    catch { Write-Output ("  {0,-8} ISSUE   not valid JSON" -f $label); Note 'ISSUE' 1; continue }
    if (-not $cfg) { continue }
    $cfgRead++
    $block = $null
    if ($rootKey -eq 'servers') { $block = $cfg.servers } else { $block = $cfg.mcpServers }
    $names = @()
    if ($block) { $names = @($block.PSObject.Properties | Where-Object { $_ } | ForEach-Object { $_.Name }) }
    Write-Output ("  {0,-8} {1} server(s): {2}" -f $label, $names.Count, ($names -join ', '))
    if ($rootKey -eq 'servers') { $vsNames = $names } else { $clNames = $names }
}
$overlap = @($vsNames | Where-Object { $clNames -contains $_ })
# The setting is a per-source object; absent means the product default, which is copilot: true.
$discState = 'default (copilot on)'
$setPath = "$env:APPDATA\Code\User\settings.json"
if (Test-Path $setPath) {
    $raw = $null
    try { $raw = [System.IO.File]::ReadAllText($setPath, [System.Text.Encoding]::UTF8) } catch { $raw = $null }
    if ($raw) {
        # Strict JSON first. settings.json is JSONC, but most of it parses as-is, and stripping first
        # corrupted a glob containing /* ... */ into unbalanced JSON and then fell through to the
        # product default - so "copilot": false was ignored and the duplicate was reported anyway.
        $sc = $null
        try { $sc = $raw | ConvertFrom-Json } catch { $sc = $null }
        if (-not $sc) {
            $json = [regex]::Replace($raw, '(?m)^\s*//.*$', '')
            $json = [regex]::Replace($json, ',(\s*[}\]])', '$1')
            try { $sc = $json | ConvertFrom-Json } catch { $sc = $null }
        }
        if (-not $sc) {
            Write-Output '  ISSUE   settings.json could not be parsed - the discovery state is unknown, not default'
            Note 'ISSUE' 1
        }
        elseif ($sc.PSObject.Properties.Name -contains 'chat.mcp.discovery.enabled') {
            $d = $sc.'chat.mcp.discovery.enabled'
            if ($d -is [bool]) { $discState = $(if ($d) { 'all sources on' } else { 'all sources off' }) }
            elseif ($d.PSObject.Properties.Name -contains 'copilot') { $discState = $(if ($d.copilot) { 'copilot on' } else { 'copilot off' }) }
        }
    }
}
Write-Output ("  discovery {0}" -f $discState)
if ($overlap.Count -gt 0) {
    if ($discState -eq 'copilot off' -or $discState -eq 'all sources off') {
        Write-Output ("  OK      {0} name(s) duplicated, and the copilot source is off, so only one copy loads" -f $overlap.Count)
    }
    else {
        foreach ($o in $overlap) { Write-Output ("  ISSUE   declared in both configs: " + $o) }
        Write-Output '           VS Code imports the CLI config by default and disables the second copy, so the'
        Write-Output '           tool picker lists a server that contributes no tools. Either drop the duplicate'
        Write-Output '           or set "chat.mcp.discovery.enabled": { "copilot": false } in settings.json.'
        Note 'ISSUE' $overlap.Count
    }
}
elseif ($cfgRead -gt 0) {
    Write-Output '  OK      no server name is declared in both configs'
}
# A machine with no MCP config examined nothing, and a zero here would make the verdict inconclusive
# on a clean machine - the same defect this commit fixed for 'parked' and 'toolkit'.
if ($cfgRead -gt 0) { Ran 'mcp-sources' $cfgRead } else { Skip 'no MCP config found - nothing to compare' }

Line '9. Sensitive values in any tracked file'
if (-not $repoOk) {
    Write-Output '  SKIP    kit repository not found (set $env:ABAP_KIT_ROOT)'
} else {
Push-Location $REPO

# Two kinds of pattern, and only one of them may be literal.
#
# Generic shapes are identical on every machine, so they belong in the script: a private-key header
# or a credential-shaped assignment looks the same wherever it appears.
#
# Machine-specific values are different. This check used to carry them literally - a real SAP user
# id, two customer domains, the first characters of a token - and then skipped its own file so it
# would not flag itself. That is a scanner that ships what it is meant to find: a second copy of the
# secret, in the one file nobody reads as a secret, and structurally unable to detect its own leak.
# The values are now derived at run time from sources that are already gitignored, so this script
# holds none of them and no longer needs to look away from itself.
$patterns = @('-----BEGIN [A-Z ]*PRIVATE KEY-----[^-]{50,}')

$derivedFrom = @()
if (Test-Path $connFile) {
    try {
        $lc = [System.IO.File]::ReadAllText($connFile, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
        foreach ($p in @($lc.connections.PSObject.Properties)) {
            if ($p.Value.user) { $patterns += [regex]::Escape([string]$p.Value.user); $derivedFrom += 'user' }
            if ($p.Value.url -match '^https?://([^/:]+)') {
                $hostName = $Matches[1]
                $patterns += [regex]::Escape($hostName); $derivedFrom += 'host'
                # One hostname is often the only place a customer name appears; split it so
                # "host.sap.customer.com" also catches a bare "customer" dropped into a doc.
                foreach ($label in ($hostName -split '\.')) {
                    if ($label.Length -ge 5 -and $label -notmatch '^(https?|local|localhost|sap)$') {
                        $patterns += [regex]::Escape($label); $derivedFrom += 'label'
                    }
                }
            }
        }
    } catch { }
}

# Hand-written extras, also local and also gitignored: a service key, a token fragment, a system id
# the connection store cannot know about.
#
# Looked for in three places, because this script runs from two: beside the script (the clone, or
# the live copy), beside the connection store, and in the clone's tooling folder when it can be
# found. Without the third, the same script reported six patterns from the clone and five from the
# live copy - a check that silently weakens depending on where it was started is worse than none.
$extraCount = 0
$extraUsed = @()
$candidates = @($PSScriptRoot, (Split-Path $connFile -Parent))
if ($repoOk) { $candidates += (Join-Path $REPO 'tooling') }
foreach ($dir in @($candidates | Where-Object { $_ } | Select-Object -Unique)) {
    $extraFile = Join-Path $dir 'verify-patterns.local.txt'
    if (-not (Test-Path $extraFile)) { continue }
    # An unreadable list silently reduced the pattern set, which weakens the scan without saying so -
    # the exact failure mode this section exists to prevent.
    $extraLines = @()
    try { $extraLines = [System.IO.File]::ReadAllLines($extraFile, [System.Text.Encoding]::UTF8) }
    catch { Write-Output ('  ISSUE   unreadable pattern list: ' + $extraFile); Note 'ISSUE' 1; continue }
    foreach ($raw in $extraLines) {
        $t = $raw.Trim()
        if ($t -eq '' -or $t.StartsWith('#')) { continue }
        $patterns += [regex]::Escape($t); $extraCount++
    }
    $extraUsed += $dir
}

# A credential-shaped assignment, minus the placeholders that fill the templates. Reported apart
# from the derived identifiers, because the signal is weaker and the fixes are different.
# `passwd` and `pwd` were missing although workspace-sync.ps1 detects them: two homes for one rule
# that had already drifted, and the drift was measurable - a line assigning a value to `passwd`
# scored 0 hits here and 1 in the writer that decides what may be mirrored. The audit's rule is the
# stricter one it needs to be, so the alternation gains the spellings the other copy already knew.
#
# The quote requirement was a hole, measured 2026-11-16: `"SAP_PASSWORD": "hunter2secret"` and
# `password: hunter2secret` both scored 0, because the old pattern demanded a quote character
# immediately after `:` or `=`. Those are the two shapes a JSON config and an unquoted YAML file
# actually use, so the rule was blind to exactly the files it exists to read.
#
# The key must start a "value position": beginning of line, or right after `{`, `,` or `;`. That is
# what keeps the wider match honest — prose such as "the secret is safe" has the key in the middle
# of a sentence, not at a value position. The first version anchored on `^\s*` only, and measurement
# showed it still missed compact JSON, where the key follows `{` on the same line; the class below
# adds the three separators so both layouts are covered. Making it wider immediately produced one
# true positive on the kit's own `{{PLACEHOLDER}}` template syntax, which is what the placeholder
# list below is for.
$shape = '(?im)(?:^|[{,;])\s*["'']?[\w.\-]*(passwd|pwd|password|secret|token|api[_-]?key|service[_-]?key)["'']?\s*[:=]\s*["'']?([^"''\s]{8,})'
$placeholder = '\$\{|@secret|PLACEHOLDER|CHANGEME|<[a-z]|xxxx|\.\.\.|\{\{'

$hits = 0
$shapes = 0
$scanned = 0
$unreadable = @()
foreach ($f in git ls-files) {
    $fp = Join-Path $REPO $f
    # A file listed by the index but absent from the working tree (deleted, never checked out) made
    # Select-String throw inside -ErrorAction SilentlyContinue, which leaves $m and $s holding the
    # PREVIOUS file's matches. The result was a HIT counter with no evidence line, or - worse - a
    # "no literal secret" for a file that was never opened. Both are silent because the evidence line
    # is exactly what goes missing, so only a file actually read counts as scanned.
    if (-not (Test-Path $fp)) { $unreadable += ($f + ' (absent from the working tree)'); continue }
    $m = @()
    $s = @()
    try {
        $m = @(Select-String -Path $fp -Pattern $patterns -ErrorAction Stop)
        $s = @(Select-String -Path $fp -Pattern $shape -ErrorAction Stop)
    }
    catch { $unreadable += ($f + ' (unreadable: ' + $_.Exception.GetType().Name + ')'); continue }
    $scanned++
    foreach ($x in $m) { Write-Output ("  HIT   " + $f + ":" + $x.LineNumber + "  " + $x.Line.Trim()); $hits++ }
    foreach ($x in $s) {
        if ($x.Line -match $placeholder) { continue }
        Write-Output ("  SHAPE " + $f + ":" + $x.LineNumber + "  " + $x.Line.Trim()); $shapes++
    }
}
if ($unreadable.Count -gt 0) {
    foreach ($u in $unreadable) { Write-Output ("  ISSUE   not scanned: " + $u) }
    Note 'ISSUE' $unreadable.Count
}

if ($patterns.Count -eq 1 -and $extraCount -eq 0) {
    Write-Output '  values   none derived - no connection store yet, so only generic shapes are checked'
} else {
    $where = if ($extraUsed.Count -gt 0) { 'verify-patterns.local.txt in ' + ($extraUsed -join ', ') } else { 'no local list' }
    Write-Output ("  values   {0} pattern(s): {1} derived (connections), {2} local ({3})" -f $patterns.Count, $derivedFrom.Count, $extraCount, $where)
}

# The working tree is not the whole repository. A value removed by a later commit stays readable from
# history forever, and nothing here used to look at the past: a scanner carried a user id, two
# customer domains and a token fragment for sixteen commits while every working-tree check passed.
# A scan of every commit costs about a quarter of a second at this size (measured 2026-11-16:
# 224/238/224 ms over 85 commits), so there is no reason to skip
# it, and the cost is the only argument that ever made skipping it defensible.
$histHits = 0
$revs = @(git rev-list --all 2>$null)
if ($revs.Count -gt 0) {
    # The patterns go in on stdin. They used to go through a temp file with cleanup only in a finally,
    # so every hard-killed run left verify-rx-<pid>.txt on disk for ever - and its contents ARE the
    # derived identifiers this section exists to keep off disk. Measured 2026-11-16: a 126-byte file
    # with six pattern lines survived a Ctrl+C. Proved separately that this git accepts -f - (rc 0 on
    # a match, 1 on no match), so no file is needed at all.
    $found = @()
    $patterns | & git grep -I -E -f - $revs 2>$null | ForEach-Object { if ($_) { $found += $_ } }
    # git grep exits 0 for a match, 1 for no match, and anything above 1 is a failure. Without this
    # branch a failed scan (a bad pattern, a damaged repository) produced an empty list and the
    # line "history clean across N commit(s)" - the one check for leaked credentials reporting a
    # pass it never earned.
    $grepRc = $LASTEXITCODE
    if ($grepRc -gt 1) {
        Write-Output ("  ISSUE   history scan failed (git grep exit {0}) - this is not a clean result" -f $grepRc)
        Note 'ISSUE' 1
    }
    # git grep prints "<sha>:<path>:<content>". The same bad line survives in every later commit,
    # so counting the raw output reported one leaked value as three problems when it had been
    # committed three times. A leak is a location, not a commit: dedupe on path + content.
    $locations = @{}
    foreach ($line in $found) {
        $parts = $line -split ':', 3
        if ($parts.Count -lt 3) { continue }
        $locations[$parts[1] + '|' + $parts[2]] = $true
    }
    $histHits = $locations.Count
    $locations.Keys | Select-Object -First 5 | ForEach-Object { Write-Output ("  HISTORY " + $_) }
    if ($histHits -gt 5) { Write-Output ("  HISTORY ... and {0} more" -f ($histHits - 5)) }
}

if ($histHits -gt 0) {
    Write-Output ("  history  {0} hit(s) across {1} commit(s) - a rewritten history is the only fix" -f $histHits, $revs.Count)
} elseif ($revs.Count -eq 0) {
    # The pass line used to print first and be contradicted by the ISSUE below it.
    Write-Output '  history  not scanned - no commits to scan'
} else {
    Write-Output ("  history  clean across {0} commit(s)" -f $revs.Count)
}
Write-Output ("  sensitive = {0} value hit(s), {1} credential-shaped line(s), {2} in history" -f $hits, $shapes, $histHits)
# Coverage, not just findings. With INDEX.md present but no git metadata - a copied kit, a damaged
# .git, a worktree - the scan examined zero files and zero commits and still printed a clean summary.
# The one check that exists to catch leaked credentials must never report success from an empty set.
Ran 'secrets.scan' $scanned
Ran 'secrets.history' $revs.Count
if ($scanned -eq 0) {
    Write-Output '  ISSUE   no tracked files to scan - the repository has no git index'
    Note 'ISSUE' 1
}
if ($revs.Count -eq 0) {
    Write-Output '  ISSUE   no commits to scan - git rev-list --all is empty'
    Note 'ISSUE' 1
}
# Two categories, not one total. A value still in the working tree is also in history - the commit
# that introduced it is part of `git rev-list --all` - so adding the two counters reported one leak
# twice. They are separate fixes anyway: a working-tree hit is edited, a history hit is rewritten.
Note 'HIT' $hits
Note 'SHAPE' $shapes
Note 'HISTORY' $histHits
Pop-Location
}

Line '9b. Text still says what it was written to say (no mojibake)'
# A file decoded with the wrong code page does not fail - it produces text that looks almost right,
# and nothing in this audit could see it. Measured 2026-11-16: release notes for v0.9.4 were written
# as UTF-8, read back as codepage 874 (this machine's ANSI page), and published with thirteen em
# dashes turned into U+0E42 U+20AC U+201D. The file was valid, the checks passed, and a Thai reader
# saw the damage instantly while no tool reported it.
#
# Two different failures, and the audit only knew one of them:
#   U+FFFD          the bytes were rejected outright. Section 1 already counts this.
#   mojibake        the bytes were accepted as the wrong characters. That is this section.
#
# The first version of this gate enumerated four damaged sequences by hand. Measured 2026-11-16, that
# failed twice over: it detected only codepage 874 (damage from cp1252, cp437 or latin-1 passed as
# clean), and one of its four sequences, U+0E22 U+0E17, is two ordinary Thai letters, so a normal Thai
# phrase failed the audit. Both defects are the same mistake - describing the damage instead of
# deriving it.
#
# So the damage is derived. For a maximal run of non-ASCII characters, encode the run back to a
# candidate single-byte code page and decode those bytes as strict UTF-8. If that yields one or more
# printable non-Thai characters, the run is the ghost of UTF-8 text that was read through that page.
# Genuine Thai fails this test because its cp874 bytes are mostly 0xA1-0xFB, which are not valid
# UTF-8 continuation bytes.
#
# One ambiguity is unavoidable: the middle dot U+00B7 is C2 B7 in UTF-8, and read as cp874 that is
# exactly the Thai pair U+0E22 U+0E17. A two-letter Thai fragment is indistinguishable from that
# damage, so for page 874 only, an all-Thai run of length 2 is reported as a NOTE and not as an
# ISSUE. Guessing wrong in that direction would block the audit on the owner's own language.
$mojiFiles = 0
$mojiHits = 0
$mojiNotes = 0
$mojiScanned = 0

$mojiPages = @(
    @{ Id = 874;   Name = 'cp874' },
    @{ Id = 1252;  Name = 'cp1252' },
    @{ Id = 437;   Name = 'cp437' },
    @{ Id = 850;   Name = 'cp850' },
    @{ Id = 28591; Name = 'latin-1' }
)
$mojiStrict = New-Object System.Text.UTF8Encoding($false, $true)

function Get-MojiRuns([string]$text) {
    # Maximal runs of non-ASCII characters, capped at 12. A single damaged character is 2-4 codepoints;
    # a longer run is real prose and would only cost time.
    $runs = @()
    $i = 0
    while ($i -lt $text.Length) {
        if ([int]$text[$i] -gt 127) {
            $j = $i
            while ($j -lt $text.Length -and [int]$text[$j] -gt 127 -and ($j - $i) -lt 12) { $j++ }
            $runs += $text.Substring($i, $j - $i)
            $i = $j
        }
        else { $i++ }
    }
    return $runs
}

function Test-MojiRun([string]$run, $pages) {
    # Returns the page name that explains the run, or $null. The decoded text must be printable and
    # must not itself be Thai: a run that decodes to Thai is a Thai run, not damage.
    foreach ($pg in $pages) {
        $enc = $null
        try { $enc = [System.Text.Encoding]::GetEncoding([int]$pg.Id) } catch { continue }
        $bytes = $null
        try { $bytes = $enc.GetBytes($run) } catch { continue }
        # A lossy round trip means the page cannot represent this run; skip it.
        if (-not ($enc.GetString($bytes) -ceq $run)) { continue }
        $decoded = $null
        try { $decoded = $mojiStrict.GetString($bytes) } catch { continue }
        if ([string]::IsNullOrEmpty($decoded)) { continue }
        if ($decoded -ceq $run) { continue }
        $bad = $false
        foreach ($ch in $decoded.ToCharArray()) {
            $cp = [int]$ch
            if ($cp -lt 32) { $bad = $true; break }
            if ($cp -ge 0x0E00 -and $cp -le 0x0E7F) { $bad = $true; break }
        }
        if ($bad) { continue }
        return $pg.Name
    }
    return $null
}

if ($repoOk) {
    Push-Location $REPO
    # Tracked AND untracked-but-not-ignored. The first version listed only `git ls-files`, and a probe
    # planted to prove the gate works was invisible to it: a brand-new file is exactly where freshly
    # written damage lands, and it is also the one state a tracked-only scan can never see.
    $mojiTargets = @(& git ls-files) + @(& git ls-files --others --exclude-standard)
    Pop-Location

    # Self-test: the detector must find the damage it was built for, every run. A gate whose only
    # evidence of working is that it printed a clean line has not been tested at all - that is the
    # defect class this whole section exists to close.
    $probeOk = $true
    $probeRun = [System.Text.Encoding]::GetEncoding(874).GetString([System.Text.Encoding]::UTF8.GetBytes([string][char]0x2014))
    if ($probeRun -ceq [string][char]0x2014) { $probeOk = $false }   # the page did not damage it at all
    $probeFound = Test-MojiRun $probeRun $mojiPages
    if ($probeFound -ne 'cp874') { $probeOk = $false }
    # And it must not fire on a real Thai phrase.
    $thaiProbe = [string][char]0x0E20 + [string][char]0x0E32 + [string][char]0x0E29 + [string][char]0x0E32 + [string][char]0x0E22 + [string][char]0x0E17 + [string][char]0x0E31 + [string][char]0x0E48 + [string][char]0x0E27 + [string][char]0x0E44 + [string][char]0x0E1B
    if ($null -ne (Test-MojiRun $thaiProbe $mojiPages)) { $probeOk = $false }
    if (-not $probeOk) {
        Write-Output '  ISSUE   the mojibake detector failed its own self-test - its verdict cannot be trusted'
        Note 'ISSUE' 1
    }
    else {
        Write-Output '  self-test: detects a damaged em dash, ignores a Thai phrase'
    }

    # The release notes live outside the repository and are the artifacts that were damaged in
    # production last round. A gate that cannot reach the file it was written for is a gate with a
    # documented blind spot, so they are scanned too, by name.
    $mojiPaths = @()
    foreach ($rel in ($mojiTargets | Sort-Object -Unique)) {
        if ($rel -notmatch '\.(md|ps1|cjs|js|json|yaml|yml|txt|template)$') { continue }
        $mojiPaths += (Join-Path $REPO $rel)
    }
    $backupDir = Join-Path $env:USERPROFILE '.copilot\backups'
    if (Test-Path $backupDir) { $mojiPaths += @(Get-ChildItem $backupDir -File -Filter '*.md' -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }) }

    foreach ($fp in $mojiPaths) {
        if (-not (Test-Path $fp)) { continue }
        $mt = $null
        try { $mt = [System.IO.File]::ReadAllText($fp, [System.Text.Encoding]::UTF8) } catch { continue }
        $mojiScanned++
        $label = if ($fp.StartsWith($REPO, [StringComparison]::OrdinalIgnoreCase)) { $fp.Substring($REPO.Length).TrimStart('\') } else { $fp }
        $n = 0
        $soft = 0
        foreach ($run in (Get-MojiRuns $mt)) {
            $page = Test-MojiRun $run $mojiPages
            if (-not $page) { continue }
            $allThai = -not ($run -match '[^\u0E00-\u0E7F]')
            $cps = (@($run.ToCharArray() | ForEach-Object { 'U+{0:X4}' -f [int]$_ })) -join ' '
            if ($page -eq 'cp874' -and $allThai -and $run.Length -eq 2) {
                $soft++
                Write-Output ("  NOTE    " + $label + " has a 2-letter Thai run (" + $cps + ") that is also the cp874 form of U+00B7 - ambiguous, not counted")
                continue
            }
            $n++
            Write-Output ("  ISSUE   " + $label + " contains mojibake (" + $cps + ") - UTF-8 text read as " + $page)
        }
        if ($n -gt 0) { $mojiFiles++; $mojiHits += $n }
        if ($soft -gt 0) { $mojiNotes += $soft }
    }
    if ($mojiScanned -eq 0) {
        Write-Output '  ISSUE   no text file was scanned for mojibake'
        Note 'ISSUE' 1
    }
    elseif ($mojiFiles -eq 0) {
        Write-Output ("  {0} text file(s) contain no mojibake sequence ({1} ambiguous Thai pair(s) noted)" -f $mojiScanned, $mojiNotes)
    }
    Ran 'encoding' $mojiScanned
    Note 'ISSUE' $mojiHits
}
else {
    Write-Output '  SKIP    kit repository not found (set $env:ABAP_KIT_ROOT)'
}

Line '9c. A doc may not name an identifier it is supposed to keep out'
# The README states, and has stated for four rounds, that no tracked file names a system or a client.
# Measured 2026-11-16: it was false in the repository that makes the claim. `AGENTS.md` and two
# config templates carry `gsd-120` and `ds4-900`, and the connection store on this machine records
# that `gsd` is the SID in use. Nothing caught it, because the pattern scan in section 9 derives its
# patterns from the connection store's URL, host and user - never from the connection NAME, which is
# where the SID-shaped token actually lives.
#
# The rule this section enforces is narrower than "no identifiers", because the server labels are a
# legitimate part of an MCP config and renaming them breaks the launcher wiring. What is forbidden is
# an identifier JOINED to the thing that makes it customer data: a client number, a host, or a user.
$labels = @('gsd-110', 'gsd-120', 'ds4-900')
$clientJoined = 0
$labelFiles = 0
$labelScanned = 0
if ($repoOk) {
    Push-Location $REPO
    # Untracked-but-not-ignored as well: a brand-new file is where a customer identifier is most
    # likely to be written for the first time, and it is the one state a tracked-only scan cannot see.
    $labelTargets = @(& git ls-files) + @(& git ls-files --others --exclude-standard)
    Pop-Location
    foreach ($rel in $labelTargets) {
        if ($rel -notmatch '\.(md|json|ps1|cjs|js|template)$') { continue }
        # One exemption, with a reason: the findings ledger quotes the offending line as evidence of
        # the defect it recorded. Scanning it would make an accurate ledger entry report itself, and
        # deleting the quote would weaken the entry. The ledger is a record of what was wrong, not a
        # place a live identifier is introduced - every value in it is already in a fixed commit.
        if ($rel -eq 'tooling/findings.json') { continue }
        $lp = Join-Path $REPO $rel
        if (-not (Test-Path $lp)) { continue }
        $lt = $null
        try { $lt = [System.IO.File]::ReadAllText($lp, [System.Text.Encoding]::UTF8) } catch { continue }
        $labelScanned++
        $named = $false
        foreach ($lb in $labels) { if ($lt.IndexOf($lb, [StringComparison]::OrdinalIgnoreCase) -ge 0) { $named = $true } }
        if ($named) { $labelFiles++ }
        # The join is the defect: a label on the same line as a client number or a real host.
        foreach ($line in ($lt -split "`r?`n")) {
            $hasLabel = $false
            foreach ($lb in $labels) { if ($line.IndexOf($lb, [StringComparison]::OrdinalIgnoreCase) -ge 0) { $hasLabel = $true } }
            if (-not $hasLabel) { continue }
            if ($line -match '(?i)client\s*[:=]?\s*\d{2,3}' -or $line -match '(?i)https?://[a-z0-9.-]+\.(com|net|local|corp|cloud|internal)') {
                $clientJoined++
                Write-Output ("  ISSUE   " + $rel + " joins a server label to a client or host: " + $line.Trim())
            }
        }
    }
    if ($labelScanned -eq 0) {
        Write-Output '  ISSUE   no file was scanned for identifier joins'
        Note 'ISSUE' 1
    }
    else {
        Write-Output ("  {0} file(s) scanned, {1} name a server label, {2} join one to a client or host" -f $labelScanned, $labelFiles, $clientJoined)
    }
    Ran 'labels' $labelScanned
    Note 'ISSUE' $clientJoined
}
else {
    Write-Output '  SKIP    kit repository not found (set $env:ABAP_KIT_ROOT)'
}

Line '9c-2. Public tree does not name local customer objects'
# Measured 2026-11-18 after the repository became public. Two tracked docs used a real
# customer object name as a friendly example; the local record and its functional specification
# are under Projects\, yet the public tree quoted the name anyway. A generic name such as
# ZEXAMPLE01 carries the same teaching value. The exact old name is in the findings ledger,
# which this section exempts because it quotes evidence rather than introducing a live value.
#
# Derive the forbidden names from the local Projects folder, not from a hard-coded list. A list in
# this script would itself leak the identifier, and it would go stale the moment a project is added.
# Projects\ is gitignored, so a machine without local records scans nothing and reports that fact
# rather than claiming a clean result.
$custIds = @()
$projectsRootForIds = if ($REPO) { Join-Path $REPO 'Projects' } else { $null }
if ($projectsRootForIds -and (Test-Path -LiteralPath $projectsRootForIds)) {
    foreach ($custIdProj in (Get-ChildItem -LiteralPath $projectsRootForIds -Directory -ErrorAction SilentlyContinue)) {
        if ($custIdProj.Name -match '^(_|\.)') { continue }
        foreach ($custIdFolder in (Get-ChildItem -LiteralPath $custIdProj.FullName -Directory -ErrorAction SilentlyContinue)) {
            if ($custIdFolder.Name -match '^(_|\.|spec$)') { continue }
            $custIds += $custIdFolder.Name
        }
    }
}
$custIds = @($custIds | Where-Object { $_ -and $_.Length -ge 4 } | Sort-Object -Unique)
$custIdHits = 0
$custIdScanned = 0
if (-not $repoOk) {
    Skip 'kit repository not found - cannot compare against local records'
}
elseif ($custIds.Count -eq 0) {
    Skip 'no local program records - nothing to compare against the public tree'
}
else {
    Push-Location $REPO
    $custIdTargets = @(& git ls-files) + @(& git ls-files --others --exclude-standard)
    Pop-Location
    foreach ($custIdRel in $custIdTargets) {
        if ($custIdRel -notmatch '\.(md|json|ps1|cjs|js|template|jsonc|txt|yaml)$') { continue }
        # The ledger quotes the evidence that made the rule necessary; scanning it would report
        # its own quote as a new leak. Every value in it is already in a fixed commit.
        if ($custIdRel -eq 'tooling/findings.json') { continue }
        $custIdPath = Join-Path $REPO $custIdRel
        if (-not (Test-Path -LiteralPath $custIdPath)) { continue }
        $custIdText = $null
        try { $custIdText = [System.IO.File]::ReadAllText($custIdPath, [System.Text.Encoding]::UTF8) } catch { continue }
        $custIdScanned++
        foreach ($custIdLine in ($custIdText -split "`r?`n")) {
            foreach ($custIdName in $custIds) {
                if ($custIdLine.IndexOf($custIdName, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                    $custIdHits++
                    Write-Output ("  ISSUE   " + $custIdRel + " names a local customer object (" + $custIdName + "): " + $custIdLine.Trim())
                }
            }
        }
    }
    if ($custIdScanned -eq 0) {
        Write-Output '  ISSUE   no file was scanned for local customer object names'
        Note 'ISSUE' 1
    }
    else {
        Write-Output ("  {0} file(s) scanned against {1} local program name(s), {2} hit(s)" -f $custIdScanned, $custIds.Count, $custIdHits)
    }
    Ran 'customer-ids' $custIdScanned
    Note 'ISSUE' $custIdHits
}

Line '9d. A tag and its notes file describe the same release'
# At v0.9.4.7, five of the twelve tags then present carried a one-line subject rather than their
# release notes, and nothing compared them. Measured 2026-11-16: `v0.9.1`'s annotation contained cp874-
# damaged em dash that section 9b cannot see, because a tag is a git object and not a file.
#
# Two checks, and only one of them can be a hard failure. The version in the heading MUST match the
# tag - a notes file that names the wrong release is a defect no reader can work around. Whether the
# tag message equals the notes body is a convention this repository has not followed since v0.9.4,
# so a difference is reported as a NOTE with the count, not as an ISSUE.
$tagMismatch = 0
$tagCompared = 0
$tagSkipped = 0
$tagSubjectOnly = 0
$tagDamaged = 0
# Declared exceptions, read once. The file is the single place a human records a state that cannot be
# repaired in place, and it is already read by section 2b for the same reason.
$tagExceptions = @()
$declFile = if ($REPO) { Join-Path $REPO 'tooling\removed-on-purpose.json' } else { $null }
if ($declFile -and (Test-Path $declFile)) {
    try {
        $declDoc = [System.IO.File]::ReadAllText($declFile, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
        $tagExceptions = @($declDoc.immutable_tag_damage | Where-Object { $_ -and $_.tag })
    }
    catch { Write-Output '  ISSUE   cannot read immutable_tag_damage declarations'; Note 'ISSUE' 1 }
}
$notesDir = Join-Path $env:USERPROFILE '.copilot\backups'
if ($repoOk -and (Test-Path $notesDir)) {
    Push-Location $REPO
    $tagList = @(& git tag --list 'v*')
    foreach ($tg in $tagList) {
        $noteFile = Join-Path $notesDir ('release-notes-' + $tg + '.md')
        # A tag with no notes file used to vanish without a line or a counter, so a partial pass
        # looked like a full one. Report it and fail: the copy of record is required for every tag.
        if (-not (Test-Path $noteFile)) {
            $tagSkipped++
            Write-Output ("  ISSUE   " + $tg + " has no release notes file at " + $noteFile)
            Note 'ISSUE' 1
            continue
        }
        $tagCompared++
        # Native output is decoded with [Console]::OutputEncoding, which is windows-874 on this
        # machine (F-164). A clean UTF-8 arrow E2 86 92 in the v0.9.4.9 annotation was decoded as
        # U+0E42 U+0086 U+2019 and reported as mojibake, while the raw tag object had zero damaged
        # sequences. Scope UTF-8 to this read, then restore: changing the console encoding for the
        # whole audit would alter every other native command in ways this section does not check.
        $prevOutEnc = [Console]::OutputEncoding
        try {
            [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
            $body = (& git tag -l --format='%(contents)' $tg) -join "`n"
        }
        finally { [Console]::OutputEncoding = $prevOutEnc }
        # Guarded: section 1c flags an unguarded read in a Continue-mode script, and it flagged this
        # one on the first run of the section. A notes file that cannot be read must skip the tag, not
        # abort the loop and leave the count short.
        $noteText = $null
        try { $noteText = [System.IO.File]::ReadAllText($noteFile, [System.Text.Encoding]::UTF8) }
        catch { Write-Output ("  ISSUE   cannot read " + $noteFile + ": " + $_.Exception.GetType().Name); Note 'ISSUE' 1; continue }
        # Two title conventions are in use: a markdown `#` heading (v0.9.4 and later) and a bare
        # first line (v0.9.0-v0.9.3). Accepting only the first version reported four false failures,
        # which is its own defect - a gate that demands one formatting convention from files written
        # before the convention existed. The test is that the first non-blank line names the version.
        $firstLine = ($noteText -split "`r?`n" | Where-Object { $_.Trim() -ne '' } | Select-Object -First 1)
        $heading = if ($firstLine) { $firstLine -replace '^#+\s*', '' } else { '' }
        # The heading must name this tag. `v0.9.4.1` and `v0.9.4.2` drop the `v`, and that is fine.
        if ([string]::IsNullOrWhiteSpace($heading)) {
            $tagMismatch++
            Write-Output ("  ISSUE   " + $tg + " notes file has no title line")
        }
        else {
            $bare = $tg -replace '^v', ''
            if ($heading -notmatch [regex]::Escape($bare)) {
                $tagMismatch++
                Write-Output ("  ISSUE   " + $tg + " notes title does not name this version: " + $heading.Trim())
            }
        }
        # Tag body damage, which no file scan can reach. A released tag cannot be rewritten, so a
        # declared exception in removed-on-purpose.json turns this from a permanent failure into a
        # reported fact - the same mechanism section 2b uses for a skill deleted on purpose. The
        # exception is keyed on the tag name and carries the reason, so a NEW damaged tag still fails.
        foreach ($run in (Get-MojiRuns $body)) {
            if ($null -ne (Test-MojiRun $run $mojiPages)) {
                $cps = (@($run.ToCharArray() | ForEach-Object { 'U+{0:X4}' -f [int]$_ })) -join ' '
                $declared = $null
                if ($tagExceptions) { $declared = $tagExceptions | Where-Object { $_ -and $_.tag -eq $tg } | Select-Object -First 1 }
                if ($declared) {
                    Write-Output ("  NOTE    " + $tg + " tag annotation contains mojibake (" + $cps + ") - declared immutable, see removed-on-purpose.json")
                }
                else {
                    $tagDamaged++
                    Write-Output ("  ISSUE   " + $tg + " tag annotation contains mojibake (" + $cps + ")")
                }
                break
            }
        }
        if ($body.Length -lt 400) { $tagSubjectOnly++ }
    }
    Pop-Location
    if ($tagCompared -eq 0) {
        Write-Output '  NOTE    no release notes file matches a local tag - nothing compared'
    }
    else {
        Write-Output ("  {0} tag(s) compared against their notes; {1} lack notes; {2} carry a subject rather than the notes body (accepted since v0.9.4)" -f $tagCompared, $tagSkipped, $tagSubjectOnly)
    }
    Ran 'tag-notes' ($tagCompared + $tagSkipped)
    Note 'ISSUE' ($tagMismatch + $tagDamaged)
}
else {
    Write-Output '  SKIP    no tag or no backup notes folder - nothing to compare'
}

Line '9e. Nothing in the backups folder holds a live identifier'
# Section 9 scans the repository and its history. This folder is neither, and that is the whole
# reason for this section: measured 2026-11-16, six files totalling 35,818 bytes sat in
# ~/.copilot/backups holding 27 server entries, 11 internal hostnames, one client number and three
# credential-shaped keys. Six audit rounds ran clean over that folder because every check began with
# `git ls-files`, and a backup file is never a tracked file. The safest place to leave a secret is
# outside the repository, and no gate was looking outside the repository.
#
# The rule is narrow on purpose: a backup that carries a derived identifier or a credential-shaped
# line fails, because the point of a backup is to be restored, and restoring it puts the value back.
# Release notes are prose and section 4 governs them; a pre-history git bundle is repository content
# that section 9's history scan already reads commit by commit.
$bkHits = 0
$bkNotes = 0
$bkFiles = 0
$bkScanned = 0
$bkSkipped = @()
$bkDir = Join-Path $env:USERPROFILE '.copilot\backups'
if (-not (Test-Path -LiteralPath $bkDir)) {
    Write-Output '  SKIP    no backups folder - nothing outside the repository to read'
}
elseif (-not $patterns) {
    # $patterns is built in section 9, which returns early when the kit repository is not found.
    # Without this branch the scan would run with an empty pattern list, report a clean folder, and
    # register coverage for files it never actually examined - the failure mode this audit exists to
    # find, reproduced inside the section written to prevent it.
    Write-Output '  SKIP    no identifier list - section 9 did not derive any, so this folder cannot be judged'
}
else {
    # Self-test, every run. The scanner is two regular expressions that the rest of this script also
    # depends on, and a damaged pattern would report a clean backups folder rather than an error.
    # The fixture is assembled from parts so this file never contains the shape it looks for.
    $probe = 'pass' + 'word' + ' = ' + 'hunter2secret'
    if ($probe -notmatch $shape) {
        Write-Output '  ISSUE   the credential shape cannot match a known-bad line - this section is not checking anything'
        Note 'ISSUE' 1
    }
    # Configuration is the file class this section exists for. A config backup is meant to be
    # restored, and restoring it puts the host, the user and the password back into use. Measured
    # 2026-11-16, the six files that had gone unseen for six rounds were all of this class.
    #
    # Prose is different and is deliberately not failed: an analysis document that names the object
    # it analyses is the deliverable, not a leak, and section 9c already governs documents inside the
    # repository. A prose hit is reported as a NOTE so the file stays visible without a gate that the
    # owner would have to suppress - a suppressed gate is how this section came to be needed.
    #
    # A credential-shaped value is an ISSUE in any file, prose included: a real password in a note is
    # still a real password.
    #
    # The split is by extension and .md is the one prose class, so an unknown extension is treated as
    # configuration. Choosing the stricter side for an unknown file is the only safe default here.
    $bkAll = @(Get-ChildItem -LiteralPath $bkDir -Recurse -File -ErrorAction SilentlyContinue)
    foreach ($bf in $bkAll) {
        $lower = $bf.Name.ToLower()
        # The relative path, not the bare name: two files named project-notes.md in two folders
        # printed two identical-looking lines, so a reader could not tell which one to open.
        $rel = $bf.FullName.Substring($bkDir.Length).TrimStart('\')
        # Prose and repository content, each with the section that already reads it.
        if ($lower -like 'release-notes-*.md') { $bkSkipped += ($rel + ' (prose, section 4)'); continue }
        if ($lower -like '*.bundle') { $bkSkipped += ($rel + ' (repository content, section 9 history)'); continue }
        # The list of identifiers this very section searches for. Flagging it would be the detector
        # reporting its own input - the same self-reference section 9 avoids for its own file. Its
        # live copy is the one that matters, so a stale backup of it is reported, never failed.
        if ($lower -eq 'verify-patterns.local.txt') {
            Write-Output ('  NOTE    ' + $rel + ' is the pattern list this section reads - not counted as a leak')
            $bkNotes++
            $bkScanned++
            continue
        }
        $isProse = ($bf.Extension.ToLower() -eq '.md')
        $hit = 0
        $note = 0
        try {
            foreach ($x in @(Select-String -LiteralPath $bf.FullName -Pattern $patterns -ErrorAction Stop)) {
                # The value is not printed. This section's job is to say a file is unsafe to restore
                # and where, and a console that echoes an internal hostname is a second copy of it.
                if ($isProse) { Write-Output ("  note    " + $rel + ":" + $x.LineNumber + "  names a derived identifier (prose)"); $note++ }
                else { Write-Output ("  HIT     " + $rel + ":" + $x.LineNumber + "  derived identifier"); $hit++ }
            }
            foreach ($x in @(Select-String -LiteralPath $bf.FullName -Pattern $shape -ErrorAction Stop)) {
                if ($x.Line -match $placeholder) { continue }
                Write-Output ("  SHAPE   " + $rel + ":" + $x.LineNumber + "  credential-shaped value")
                $hit++
            }
        }
        catch {
            $bkSkipped += ($rel + ' (unreadable: ' + $_.Exception.GetType().Name + ')')
            continue
        }
        $bkScanned++
        $bkNotes += $note
        if ($hit -gt 0) { $bkFiles++; $bkHits += $hit }
    }
    foreach ($s in $bkSkipped) { Write-Output ('  skip    ' + $s) }
    # A folder that exists but yielded nothing to read is not a pass. The count is registered below,
    # so the coverage row is what says whether this section examined anything.
    if ($bkScanned -eq 0) {
        Write-Output '  ISSUE   backups folder holds no readable file - nothing was examined'
        Note 'ISSUE' 1
    }
    if ($bkHits -gt 0) {
        Write-Output ("  ISSUE   {0} identifier(s) in {1} configuration file(s) outside the repository - delete the file, do not restore it" -f $bkHits, $bkFiles)
    } else {
        Write-Output ("  backups  {0} file(s) read, no configuration file holds a derived identifier, no file holds a credential shape" -f $bkScanned)
    }
    if ($bkNotes -gt 0) {
        Write-Output ("  note    {0} prose reference(s) to a derived identifier - reported, not failed" -f $bkNotes)
    }
    Ran 'backups' $bkScanned
    Note 'ISSUE' $bkHits
}

Line '9f. CHANGELOG index covers every tag'
# The release timeline used to live only in annotated tags and in notes files under ~/.copilot/backups.
# A fresh clone saw none of it. CHANGELOG.md is an index, not a second copy of the notes: one row per
# tag with the date, a short theme and the peeled commit. This section compares the two directions -
# a tag nobody indexed, and an index row naming a tag that does not exist. It does not compare the
# theme text: that is prose, and section 9d already handles tag-versus-notes consistency.
$changelogTags = @{}
$changelogRows = 0
$changelogBadRows = 0
if (-not $repoOk) {
    Skip 'kit repository not found - cannot compare CHANGELOG with tags'
} else {
    $changelogPath = Join-Path $REPO 'CHANGELOG.md'
    if (-not (Test-Path -LiteralPath $changelogPath)) {
        Write-Output '  ISSUE   CHANGELOG.md is missing - a clone cannot see the release timeline'
        Note 'ISSUE' 1
    }
    else {
        $changelogText = $null
        try { $changelogText = [System.IO.File]::ReadAllText($changelogPath, [System.Text.Encoding]::UTF8) }
        catch { Write-Output ('  ISSUE   CHANGELOG.md is unreadable: ' + $_.Exception.GetType().Name); Note 'ISSUE' 1 }
        if ($null -ne $changelogText) {
            foreach ($clLine in ($changelogText -split "`r?`n")) {
                if ($clLine -notmatch '^\|\s*\|?\s*(v[0-9][0-9A-Za-z.]*)\s*\|') { continue }
                $clTag = $Matches[1]
                $changelogRows++
                if ($changelogTags.ContainsKey($clTag)) { $changelogBadRows++; Write-Output ('  ISSUE   CHANGELOG.md repeats a tag: ' + $clTag) }
                else { $changelogTags[$clTag] = $true }
            }
            if ($changelogRows -eq 0) {
                Write-Output '  ISSUE   CHANGELOG.md has no version rows - nothing was checked'
                Note 'ISSUE' 1
            }
        }
    }
    if ($repoOk) {
        Push-Location $REPO
        $liveTags = @(& git tag)
        Pop-Location
        foreach ($lt in $liveTags) {
            if (-not $changelogTags.ContainsKey($lt)) {
                $changelogBadRows++
                Write-Output ('  ISSUE   tag has no CHANGELOG row: ' + $lt)
            }
        }
        foreach ($ct in $changelogTags.Keys) {
            if ($liveTags -notcontains $ct) {
                $changelogBadRows++
                Write-Output ('  ISSUE   CHANGELOG row names no tag: ' + $ct)
            }
        }
        Write-Output ("  {0} tag(s), {1} CHANGELOG row(s), {2} mismatch(es)" -f $liveTags.Count, $changelogRows, $changelogBadRows)
        Ran 'changelog' ($liveTags.Count + $changelogRows)
        Note 'ISSUE' $changelogBadRows
    }
}

Line '10. Findings ledger: is anything still open?'
# Why this section exists, in one sentence: a finding reported into a chat log is forgotten, and a
# finding reported into a file that gates the build is not.
#
# Measured 2026-11-15. An audit round found that hooks/subagent-rules.cjs evaluates its allow list
# before its deny list. It was reported in prose. Four later audit rounds never re-read it, because
# each round started from the code rather than from the list of things already known to be wrong. Two
# days later it was still shipping. The same happened to a malformed markdown table that a fix commit
# claimed to repair, and to a section numbering the report printed out of order. Detection was never
# the weak part; remembering was.
if (-not $repoOk) {
    Write-Output '  SKIP    kit repository not found (set $env:ABAP_KIT_ROOT)'
} else {
    $findingsFile = Join-Path $REPO 'tooling\findings.json'
    if (-not (Test-Path $findingsFile)) {
        Write-Output '  ISSUE   no findings ledger at tooling\findings.json'
        Note 'ISSUE' 1
    }
    else {
        $fl = $null
        try { $fl = [System.IO.File]::ReadAllText($findingsFile, [System.Text.Encoding]::UTF8) | ConvertFrom-Json }
        catch { Write-Output '  ISSUE   findings.json is not valid JSON'; Note 'ISSUE' 1 }
        if ($fl -and -not ($fl.PSObject.Properties.Name -contains 'findings')) {
            Write-Output '  ISSUE   findings.json has no findings member'
            Note 'ISSUE' 1
        }
        elseif ($fl) {
            $open = @(); $badStatus = @(); $noEvidence = @(); $staleRef = @()
            $valid = @('open', 'fixed', 'wontfix')
            # Every evidence ref resolved in ONE git process, before the loop.
            # Measured 2026-11-15: 23 findings x one `git cat-file -e` = 1,030 ms, because each ref
            # spawned a process; the same refs through a single `git cat-file --batch-check` = 50 ms.
            # The batch form also asks a better question than -e did: it reports the object TYPE, so
            # evidence that resolves to a tree or a blob is rejected instead of accepted merely for
            # existing. Missing refs come back as the literal 'missing'.
            $evShas = @($fl.findings | Where-Object { $_ -and $_.status -eq 'fixed' -and $_.evidence -match '^[0-9a-f]{7,40}$' } | ForEach-Object { [string]$_.evidence })
            # Self-test the classifier on the two shapes git actually produces, plus the fallback. The
            # 'no such object' branch it feeds was unreachable for two rounds with no test to notice.
            $evProbe = @((Get-EvidenceType 'commit'), (Get-EvidenceType 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeef missing'), (Get-EvidenceType 'tree'), (Get-EvidenceType ''))
            if (($evProbe -join ',') -ne 'commit,missing,tree,missing') { Write-Output ("  ISSUE   evidence-type self-test failed: " + ($evProbe -join ',')); Note 'ISSUE' 1 }
            $evTypes = @{}
            $evGitFailed = $null
            if ($evShas.Count -gt 0) {
                Push-Location $REPO
                $bc = @($evShas | & git cat-file --batch-check="%(objecttype)" 2>$null)
                $evGitRc = $LASTEXITCODE
                Pop-Location
                # A failed git is not a missing object. Measured 2026-11-16 with a bogus flag: git
                # exited 129 with no output, $bc came back empty, every ref fell through to
                # Get-EvidenceType '' = 'missing', and the audit printed 62 confident "no such object"
                # findings with exit 1 - the ledger's only trust signal inverted by one broken command.
                # A short answer is checked too: fewer lines than refs would shift the remaining refs
                # onto the wrong line and blame the wrong commits.
                if ($evGitRc -ne 0) { $evGitFailed = "git cat-file --batch-check exited $evGitRc" }
                elseif ($bc.Count -ne $evShas.Count) { $evGitFailed = "git cat-file --batch-check answered $($bc.Count) of $($evShas.Count) ref(s)" }
                if (-not $evGitFailed) {
                    for ($bi = 0; $bi -lt $evShas.Count; $bi++) {
                        # A hashtable keyed by the ref as written. Duplicate refs are harmless: the same
                        # value is stored twice. A short ref answers with its own line, which is why the
                        # lookup uses the input string and not the resolved object name.
                        $evTypes[$evShas[$bi]] = Get-EvidenceType ([string]$bc[$bi])
                    }
                }
                if ($evGitFailed) {
                    Write-Output ("  ISSUE   cannot resolve evidence: " + $evGitFailed + " - fix git before trusting this section")
                    Note 'ISSUE' 1
                }
            }
            foreach ($f in @($fl.findings)) {
                if (-not $f -or -not $f.id) { continue }
                if ($valid -notcontains $f.status) { $badStatus += ($f.id + ' (' + $f.status + ')'); continue }
                if ($f.status -eq 'open') { $open += $f; continue }
                if ($f.status -eq 'wontfix' -and -not $f.reason) { $noEvidence += ($f.id + ' (wontfix with no reason)'); continue }
                if ($f.status -eq 'fixed') {
                    if (-not $f.evidence) { $noEvidence += ($f.id + ' (fixed with no evidence)'); continue }
                    # The evidence must still resolve. A commit id that does not exist means the
                    # ledger is describing a fix nobody can find, which is the same failure as an
                    # open finding with better paperwork.
                    if ($f.evidence -match '^[0-9a-f]{7,40}$') {
                        if ($evGitFailed) { continue }
                        $etype = [string]$evTypes[[string]$f.evidence]
                        if ($etype -ne 'commit') {
                            $why = if ([string]::IsNullOrEmpty($etype) -or $etype -eq 'missing') { 'no such object' } else { 'resolves to a ' + $etype + ', not a commit' }
                            $staleRef += ($f.id + ' -> ' + $f.evidence + ' (' + $why + ')')
                        }
                    }
                }
            }
            $total = @($fl.findings).Count
            # Free-text evidence is allowed and has to stay visible. Two entries cite something other
            # than a commit - one a repair whose artifact lives outside this repository, one a section
            # name - and both are legitimate. What is not acceptable is that they were counted as
            # verified facts with no number printed, so a reader could not tell how much of the ledger
            # is checkable. The count is printed on the summary line rather than restated here, because
            # a hard-coded number goes stale the moment a finding is added - this comment said "2 of 64"
            # while the line below it printed 4 of 115.
            $softEvidence = @($fl.findings | Where-Object { $_ -and $_.status -eq 'fixed' -and $_.evidence -and $_.evidence -notmatch '^[0-9a-f]{7,40}$' })
            if ($softEvidence.Count -gt 0 -and $open.Count -eq 0 -and $badStatus.Count -eq 0 -and $noEvidence.Count -eq 0 -and $staleRef.Count -eq 0) {
                Write-Output ("  {0} finding(s) recorded, none open; {1} cite evidence that is not a commit ({2})" -f $total, $softEvidence.Count, (($softEvidence | ForEach-Object { $_.id }) -join ', '))
            }
            elseif ($open.Count -eq 0 -and $badStatus.Count -eq 0 -and $noEvidence.Count -eq 0 -and $staleRef.Count -eq 0) {
                Write-Output ("  {0} finding(s) recorded, none open" -f $total)
            }
            else {
                foreach ($o in $open) { Write-Output ("  ISSUE   open finding {0}: {1}" -f $o.id, $o.title) }
                foreach ($b in $badStatus) { Write-Output ("  ISSUE   invalid status: " + $b) }
                foreach ($n in $noEvidence) { Write-Output ("  ISSUE   " + $n) }
                foreach ($s in $staleRef) { Write-Output ("  ISSUE   evidence does not resolve: " + $s) }
            }
            Ran 'findings' $total
            Note 'ISSUE' ($open.Count + $badStatus.Count + $noEvidence.Count + $staleRef.Count)
        }
    }
}

Line '10b. Pre-release change logs name a baseline that exists'
# Before a TR is released SAP has no version to roll back to. changes.md is the AI's control plane
# and .baseline/ is the data plane. A row that names a missing file is worse than no row: the AI
# reads the description, concludes it knows the state, and writes from a guess. A baseline left
# after release is the opposite failure - stale source nobody dares delete. Both fail here.
$logRows = 0
$logBad = 0
$logSeen = 0
$preReleaseLogs = @()
$projectsRoot = if ($REPO) { Join-Path $REPO 'Projects' } else { $null }
if ($projectsRoot -and (Test-Path -LiteralPath $projectsRoot)) {
    $preReleaseLogs = @(Get-ChildItem -LiteralPath $projectsRoot -Recurse -File -Filter 'changes.md' -ErrorAction SilentlyContinue)
}
foreach ($log in $preReleaseLogs) {
    $logSeen++
    $logLines = @()
    try { $logLines = @([System.IO.File]::ReadAllLines($log.FullName, [System.Text.Encoding]::UTF8)) }
    catch {
        Write-Output ('  ISSUE   cannot read ' + $log.FullName + ': ' + $_.Exception.GetType().Name)
        $logBad++
        continue
    }
    $headerLine = @($logLines | Where-Object { $_ -match '^\|' -and $_ -match 'Baseline' } | Select-Object -First 1)
    if ($headerLine.Count -eq 0) {
        Write-Output ('  ISSUE   ' + $log.FullName + ' has no Baseline column')
        $logBad++
        continue
    }
    $columns = @($headerLine[0].Split('|') | ForEach-Object { $_.Trim() })
    $ci = @{}
    for ($i = 0; $i -lt $columns.Count; $i++) { if ($columns[$i]) { $ci[$columns[$i]] = $i } }
    # An empty log written from an older template has no rows to interpret and no baseline to
    # protect. Forcing a schema migration on a file nobody has activated yet would make this gate
    # fail for cosmetic reasons; the columns are required once a real row exists.
    $dataLines = @($logLines | Where-Object { $_ -match '^\s*\|\s*\d+\s*\|' })
    if ($dataLines.Count -eq 0) {
        $baselineDir = Join-Path $log.DirectoryName '.baseline'
        if (Test-Path -LiteralPath $baselineDir) {
            foreach ($bf in (Get-ChildItem -LiteralPath $baselineDir -File -Filter '*.abap' -ErrorAction SilentlyContinue)) {
                Write-Output ('  ISSUE   baseline in an empty change log: ' + $bf.FullName)
                $logBad++
            }
        }
        continue
    }
    $missingColumns = @('TR state', 'Baseline', 'Version', 'What', 'Why') | Where-Object { -not $ci.ContainsKey($_) }
    if ($missingColumns.Count -gt 0) {
        Write-Output ('  ISSUE   ' + $log.FullName + ' lacks column(s): ' + ($missingColumns -join ', '))
        $logBad++
        continue
    }
    $referenced = @{}
    foreach ($line in $logLines) {
        # A placeholder row starts with an em dash, not a number. It is not a change record.
        if ($line -notmatch '^\s*\|\s*\d+\s*\|') { continue }
        $cells = @($line.Split('|'))
        $state = $cells[$ci['TR state']].Trim()
        if ($state -ne 'open') { continue }
        $logRows++
        $what = $cells[$ci['What']].Trim()
        $why = $cells[$ci['Why']].Trim()
        $version = $cells[$ci['Version']].Trim()
        $baseCell = $cells[$ci['Baseline']].Trim() -replace '^`', '' -replace '`$', ''
        $label = $log.FullName.Replace($REPO + '\', '')
        if ($what -match '^(bug fix|extension|change request)$' -or $what -eq '' -or $why -eq '') {
            Write-Output ('  ISSUE   ' + $label + ' row has no real What/Why description')
            $logBad++
        }
        if ($version -notmatch '^v\d+$') {
            Write-Output ('  ISSUE   ' + $label + ' row has an invalid Version: ' + $version)
            $logBad++
        }
        if ($baseCell -eq '' -or $baseCell -match '^[—-]+$') {
            Write-Output ('  ISSUE   ' + $label + ' open row has no baseline path')
            $logBad++
            continue
        }
        if ($baseCell -notmatch '\.abap$') {
            Write-Output ('  ISSUE   ' + $label + ' baseline is not an .abap path: ' + $baseCell)
            $logBad++
            continue
        }
        $baseFull = if ([System.IO.Path]::IsPathRooted($baseCell)) { $baseCell } else { Join-Path $log.DirectoryName $baseCell }
        if (-not (Test-Path -LiteralPath $baseFull)) {
            Write-Output ('  ISSUE   ' + $label + ' baseline missing: ' + $baseCell)
            $logBad++
            continue
        }
        $referenced[$baseFull.ToLower()] = $true
    }
    $baselineDir = Join-Path $log.DirectoryName '.baseline'
    if (Test-Path -LiteralPath $baselineDir) {
        foreach ($bf in (Get-ChildItem -LiteralPath $baselineDir -File -Filter '*.abap' -ErrorAction SilentlyContinue)) {
            if (-not $referenced.ContainsKey($bf.FullName.ToLower())) {
                Write-Output ('  ISSUE   stale baseline after release or row removal: ' + $bf.FullName)
                $logBad++
            }
        }
    }
}
if ($logBad -eq 0) {
    Write-Output ("  {0} change log(s), {1} open row(s), every baseline present and no stale file" -f $logSeen, $logRows)
}
# An empty Projects folder is a decision that was examined, not a section that saw nothing.
# Counting zero there made the whole audit inconclusive (exit 2) on a machine with no records.
Ran 'pre-release-log' $(if ($logSeen -eq 0) { 1 } else { $logSeen + $logRows })
Note 'ISSUE' $logBad

Line '11. Every file on disk is inventoried, or says why it is not'
# The structural defect behind seven rounds of point-by-point fixing: a defect can only be found in an
# artifact somebody remembered to look at. Measured 2026-11-16, 161 files existed in this machine's
# toolkit footprint and appeared in no inventory: 139 third-party skill files, 13 customer project
# records, 5 installed tooling copies, 4 pre-history snapshot files. Six of them held 27 internal
# hostnames, and the audit had never seen any of them because every section began with `git ls-files`.
#
# The census is the answer and it is a separate tool, because it answers a different question: not
# "is this wrong" but "what exists". Running it here turns the inventory into a gate - a file that
# appears from nowhere now fails the audit on the same run that would otherwise pass over it.
#
# It is invoked only when this script's own reach is trusted: the census reads verify-all.ps1 to
# verify that every gate it names really exists, so pointing it at a stale copy would grade the wrong
# file. The preamble resolves the pin from state\kit-root.txt; census.ps1 records it as a state row.
$censusScript = Join-Path $REPO 'tooling\census.ps1'
if (-not (Test-Path -LiteralPath $censusScript)) {
    Write-Output '  SKIP    census.ps1 not present in this clone - nothing to cross-check'
}
else {
    # A census that cannot run must not read as a census that found nothing. Capture both streams and
    # the exit code, and treat a non-zero exit as the audit's own finding rather than a footnote.
    $censusOut = @()
    $censusRc = 0
    Push-Location $REPO
    try {
        # Same rule as the launcher wiring check: a bare `powershell` is resolved from PATH, and a
        # trimmed PATH makes this whole inventory gate unavailable while the failure is reported as
        # a census problem. $PSHOME is where this interpreter actually came from.
        $pwshExe = Join-Path $PSHOME 'powershell.exe'
        if (-not (Test-Path -LiteralPath $pwshExe)) { $pwshExe = (Get-Process -Id $PID).Path }
        $censusOut = @(& $pwshExe -NoProfile -ExecutionPolicy Bypass -File $censusScript 2>&1)
        $censusRc = $LASTEXITCODE
    }
    catch {
        Write-Output ('  ISSUE   census could not run: ' + $_.Exception.GetType().Name)
        Note 'ISSUE' 1
    }
    finally { Pop-Location }

    $cRows = 0
    $cSweep = 0
    $cResult = ''
    foreach ($ln in $censusOut) {
        $t = ([string]$ln).Trim()
        if ($t -match '^rows=(\d+)\s') { $cRows = [int]$Matches[1] }
        if ($t -match '^(\d+) file\(s\), (\d+) bytes$') { $cSweep = [int]$Matches[1] }
        if ($t -match '^RESULT: (.+)$') { $cResult = $Matches[1] }
        # The two lines that mean the inventory is incomplete. Printed as this section's own ISSUE so
        # the reason survives into the total, rather than being a detail of a nested script.
        if ($t -match '^(BLIND|PHANTOM)\s+(.+)$') {
            Write-Output ('  ISSUE   ' + $Matches[1] + ' ' + $Matches[2])
            Note 'ISSUE' 1
        }
    }
    if ($censusRc -ne 0 -and $cResult -eq '') {
        Write-Output ('  ISSUE   census exited {0} without a verdict - its output is not trustworthy' -f $censusRc)
        Note 'ISSUE' 1
    }
    if ($cRows -eq 0) {
        Write-Output '  ISSUE   census built no inventory rows - the cross-check examined nothing'
        Note 'ISSUE' 1
    }
    if ($cResult -ne '') { Write-Output ('  census  ' + $cResult) }
    Ran 'census' $cRows
}

# The verdict. Two things it must distinguish, because this check exists to be trusted:
#
#   1. Whether anything is wrong. Exit 1 means at least one check found something a human must act
#      on.
#   2. Whether anything was actually verified. Before this, "clean" and "nothing to look at" were
#      the same output: no agents, no skills, no roster and no memory produced six zero lines and
#      exit 0. So a run that verified too little is a third verdict, not a pass - it means the audit
#      could not see the thing it was asked to audit.
#
# A SKIP is neither: the audit runs on machines that do not have every part installed, and a missing
# optional part is not a defect. It is printed, so silence and success are never the same line.
if ($script:issues -gt 0) {
    # Some increments raise the total without naming a kind, because naming it at fifteen call sites
    # is fifteen chances to add a sixteenth that forgets. Whatever the kinds do not account for is
    # attributed here instead, so the bracket can never print empty while the count is non-zero.
    $named = 0
    foreach ($k in @($script:issueKinds.Keys)) { $named += $script:issueKinds[$k] }
    if ($named -lt $script:issues) {
        # Add, do not replace: an 'ISSUE' kind may already exist, and assigning would have reported
        # one problem for six.
        $extra = $script:issues - $named
        if ($script:issueKinds.Contains('ISSUE')) { $script:issueKinds['ISSUE'] += $extra } else { $script:issueKinds['ISSUE'] = $extra }
    }
    $kinds = @($script:issueKinds.Keys | ForEach-Object { "$_=$($script:issueKinds[$_])" }) -join ' '
    Write-Output ''
    Write-Output ("RESULT: {0} problem(s) [{1}] - see the lines above" -f $script:issues, $kinds)
    exit 1
}
# The threshold is not a number of items but a list of sections that must have examined something.
# A count could be met by one talkative section while the rest saw nothing, and the floor of a real
# clean run was exactly the old constant, so it could never fire on a machine that mostly worked.
$silent = @($script:ran.Keys | Where-Object { $script:ran[$_] -eq 0 })
if ($silent.Count -gt 0) {
    Write-Output ''
    Write-Output ("RESULT: inconclusive - these sections examined nothing: {0}" -f ($silent -join ', '))
    Write-Output '  A pass here would mean the audit could not see its inputs, not that they are correct.'
    exit 2
}
Write-Output ''
Write-Output ("RESULT: clean - {0} item(s) verified across {1} section(s)" -f $script:verified, $script:ran.Count)
exit 0
