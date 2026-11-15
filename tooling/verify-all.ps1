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
        Write-Output ("  {0} {1,-46} fm=L{2,-3} lines={3,-4} fences={4} dupH={5} repl={6}" -f $tag, $f.Name, $fm, $lines.Count, $fences, $dup, $bad)
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
    $n = 0; $bad = 0
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
        if (-not $m.Success -or $t -notmatch 'name:' -or $t -notmatch 'description:') { $bad++; Write-Output ("    BAD  " + $d.Name) }
    }
    $label = (Split-Path $root -Parent | Split-Path -Leaf) + ':' + (Split-Path $root -Leaf)
    Write-Output ("  {0,-30} skills={1,3}  bad_frontmatter={2}" -f $label, $n, $bad)
    Ran 'skills' $n
    Note 'BAD' $bad
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
    $tot += ($t -split "`r?`n").Count
    foreach ($l in ($t -split "`r?`n")) {
        if ($l -match '^\s*[-*]\s' -and $l -match '\b(never|always|do not|prefer|ask|verify)\b') { $rules++ }
        elseif ($l -match '^\s*[-*]\s') { $facts++ }
    }
}
$over = $tot - 200
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
foreach ($d in $roster.delegatable) { if ($d -and $d.file) { $known += $d.file } }
foreach ($g in $roster.not_delegatable) { if ($g -and $g.files) { foreach ($f in $g.files) { if ($f) { $known += $f } } } }
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
    $tkAgents = @(); $tkSkills = @(); $hashDrift = @(); $gone = @(); $parkedGone = @()
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
            $gone += $p.Name; continue
        }
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
    $probeHome = Join-Path ([System.IO.Path]::GetTempPath()) ('hookprobe-' + $PID)
    New-Item -ItemType Directory -Force -Path (Join-Path $probeHome '.copilot') | Out-Null
    Copy-Item $rosterPath (Join-Path $probeHome '.copilot\roster.json') -Force
    $cases = @()
    foreach ($d in $roster.delegatable) {
        if (-not $d.file) { continue }
        $cases += , @([string]$d.file, $true)
        if ($d.display) { $cases += , @([string]$d.display, $true) }
        $cases += , @(([string]$d.file + '-evil'), $false)
    }
    $cases += , @('no-such-agent-by-pongg', $false)
    $cases += , @('', $false)
    $savedHome = $env:USERPROFILE
    $wrong = 0
    try {
        $env:USERPROFILE = $probeHome
        foreach ($c in $cases) {
            $name = [string]$c[0]
            $payload = '{"hookEventName":"SubagentStart","agent_type":"' + $name.Replace('\', '\\').Replace('"', '\"') + '"}'
            $out = ''
            try { $out = (($payload | & $node.Source $hookFile) -join '') } catch { $out = '' }
            $label = if ($name -eq '') { '(empty)' } else { $name }
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
$pairs = @() + $agentMirrors + $skillMirrors + $hookMirrors + @('roster.json', 'tooling\verify-all.ps1', 'tooling\measure-context.ps1', 'tooling\who-locks.ps1', 'tooling\sap-secret.ps1', 'tooling\sap-connection.ps1', 'tooling\sap-arc1-launcher.ps1', 'tooling\sap-auth-probe.js', 'tooling\workspace-sync.ps1', 'tooling\install-kit.ps1', 'tooling\findings.json')
# findings.json is on the list because install-kit copies it: the installer's tooling filter takes
# every .ps1, .js and .json except surface.json, so the ledger became a live file that no section
# compared. Measured 2026-11-15: the live copy held 26 findings in 14,721 bytes while the clone held
# 26 in 17,834 - a divergence with no DRIFT line, and -Force would have silently replaced the live
# one. A file the installer writes and the audit does not compare is the exact hole hooks/ fell in.
# tooling\surface.json is deliberately absent from the list. It is runtime state: the sessionStart
# hook rewrites the LIVE copy on every run, so comparing it against the repository snapshot would
# report DRIFT forever, from the first session in which the hook fires. A check that can only fail is
# as useless as one that can only pass.
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
    if ($a -ne $b) { $drift += $rel }
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
$stObjectHit = ([regex]::Matches('{"env":{"SAP_PASSWORD":"hunter2secret"}}', $litRx)).Count
$stObjectInd = ([regex]::Matches('{"env":{"SAP_PASSWORD":"${input:p}"}}', $litRx)).Count
$stArgHit = @([regex]::Matches('["--env","SAP_PASSWORD=hunter2secret"]', $argRx) | Where-Object { $_.Groups['v'].Value -notmatch '^(\$\{|@secret$|%|<)' }).Count
$stArgInd = @([regex]::Matches('["--env","SAP_PASSWORD=${input:p}"]', $argRx) | Where-Object { $_.Groups['v'].Value -notmatch '^(\$\{|@secret$|%|<)' }).Count
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
        Write-Output ("  {0,-8} absent  ({1})" -f $label, (Split-Path $path -Leaf))
        return
    }
    # Recorded so the verdict knows this harness was examined. Without it, both harnesses absent
    # reached the verdict as a clean run with the launcher wiring wholly unverified.
    $script:verified++
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
$shape = '(?i)(password|secret|token|api[_-]?key|service[_-]?key)\s*[:=]\s*["'']([^"'']{8,})["'']'
$placeholder = '\$\{|@secret|PLACEHOLDER|CHANGEME|<[a-z]|xxxx|\.\.\.'

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
# A scan of every commit costs about a tenth of a second at this size, so there is no reason to skip
# it, and the cost is the only argument that ever made skipping it defensible.
$histHits = 0
$revs = @(git rev-list --all 2>$null)
if ($revs.Count -gt 0) {
    $rxFile = Join-Path ([System.IO.Path]::GetTempPath()) ('verify-rx-' + $PID + '.txt')
    try {
        [System.IO.File]::WriteAllLines($rxFile, $patterns, (New-Object System.Text.UTF8Encoding($false)))
        $found = @()
        & git grep -I -E -f $rxFile $revs 2>$null | ForEach-Object { if ($_) { $found += $_ } }
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
    finally { Remove-Item $rxFile -Force -ErrorAction SilentlyContinue }
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
            $evTypes = @{}
            if ($evShas.Count -gt 0) {
                Push-Location $REPO
                $bc = @($evShas | & git cat-file --batch-check="%(objecttype)" 2>$null)
                Pop-Location
                for ($bi = 0; $bi -lt $evShas.Count; $bi++) {
                    # A hashtable keyed by the ref as written. Duplicate refs are harmless: the same
                    # value is stored twice. A short ref answers with its own line, which is why the
                    # lookup uses the input string and not the resolved object name.
                    $evTypes[$evShas[$bi]] = if ($bi -lt $bc.Count) { ([string]$bc[$bi]).Trim() } else { 'missing' }
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
                        $etype = [string]$evTypes[[string]$f.evidence]
                        if ($etype -ne 'commit') {
                            $why = if ([string]::IsNullOrEmpty($etype) -or $etype -eq 'missing') { 'no such object' } else { 'resolves to a ' + $etype + ', not a commit' }
                            $staleRef += ($f.id + ' -> ' + $f.evidence + ' (' + $why + ')')
                        }
                    }
                }
            }
            $total = @($fl.findings).Count
            if ($open.Count -eq 0 -and $badStatus.Count -eq 0 -and $noEvidence.Count -eq 0 -and $staleRef.Count -eq 0) {
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
