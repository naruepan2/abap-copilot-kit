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
    [switch]$Summary
)
# One switch drives the existing $Summary logic below, so the body needs no edits.
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
        $pinned = ([System.IO.File]::ReadAllText($pin, [System.Text.Encoding]::UTF8)).Trim()
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
    $fm = 0; for ($i = 1; $i -lt $lines.Count; $i++) { if ($lines[$i] -eq '---') { $fm = $i + 1; break } }
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
$agent = [System.IO.File]::ReadAllText($agentFile, [System.Text.Encoding]::UTF8)
# Each probe is TRUE when the duplication EXISTS - that is the failure state.
$probes = [ordered]@{
    'agent hardcodes a roster count'      = $agent -match '\b\d+ (known|not delegatable|delegatable\b)'
    'audit skill hardcodes a roster count' = ([System.IO.File]::ReadAllText($auditSkill)) -match '\b\d+ (known|live)\b'
    'capture-lesson restates the evidence rule' = ([System.IO.File]::ReadAllText($lessonSkill)) -match 'never guess'
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
    foreach ($line in [System.IO.File]::ReadAllLines($selfPath, [System.Text.Encoding]::UTF8)) {
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
foreach ($d in $roster.delegatable) { if ($d -and $d.file) { $known += $d.file } }
foreach ($g in $roster.not_delegatable) { if ($g -and $g.files) { $known += $g.files } }
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
    Ran 'toolkit' 0
} else {
    $tkDoc = $null
    try { $tkDoc = Get-Content $TK -Raw | ConvertFrom-Json }
    catch { Write-Output '  ISSUE   toolkit manifest is not valid JSON'; Note 'ISSUE' 1 }
    $map = if ($tkDoc) { @($tkDoc.files)[0] } else { $null }
    $tkAgents = @(); $tkSkills = @(); $hashDrift = @(); $gone = @()
    foreach ($p in @(if ($map) { $map.PSObject.Properties })) {
        if ($p.Name -like 'agents\*') { $tkAgents += ($p.Name -replace '^agents\\', '' -replace '\.agent\.md$', '') }
        elseif ($p.Name -like 'skills\*') { $tkSkills += @(($p.Name -split '\\')[1]) }
        $f = Join-Path "$env:USERPROFILE\.copilot" $p.Name
        if (-not (Test-Path $f)) { $gone += $p.Name; continue }
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
    Write-Output ("  {0} toolkit files edited since install, {1} missing" -f $hashDrift.Count, $gone.Count)
    foreach ($h in $hashDrift) { Write-Output ("          EDITED  " + $h) }
    foreach ($g in $gone) { Write-Output ("          MISSING " + $g) }
    Ran 'toolkit' $tkAgents.Count
    Note 'ISSUE' ($hashDrift.Count + $gone.Count)
}

Line '6. Repo memory: does it duplicate the agent?'
$rmN = 0; $rmMirror = 0
if (-not $awsOk) {
    Write-Output '  SKIP    repo memory not found (set $env:ABAP_REPO_MEMORY, or open a workspace with notes)'
} else {
foreach ($f in Get-ChildItem "$AWS" -Recurse -File -Filter *.md) {
    $t = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
    $mirror = ($t -match '^\|.*ARC-1.*\|') -or ($t -match '^\|.*ADT MCP.*\|')
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
    $idxText = [System.IO.File]::ReadAllText($rmIndex, [System.Text.Encoding]::UTF8)
    $orphans = @()
    foreach ($f in Get-ChildItem $AWS -Recurse -File -Filter *.md) {
        if ($f.Name -eq 'INDEX.md') { continue }
        $rel = ($f.FullName.Substring($AWS.Length).TrimStart('\') -replace '\\', '/')
        if ($idxText -notmatch [regex]::Escape($f.Name) -and $idxText -notmatch [regex]::Escape($rel)) {
            $orphans += $rel
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
Write-Output ("  HEAD={0}  origin={1}  synced={2}  dirty={3}" -f (git rev-parse --short HEAD), (git rev-parse --short origin/main), ((git rev-parse HEAD) -eq (git rev-parse origin/main)), @(git status --porcelain).Count)
$drift = @()
# Every user-owned agent is mirrored, not just the main one. Before this, only
# abap-developer-by-pongg was compared, so an edit to any of the other three agents sat in the
# working tree unnoticed - which is exactly what happened to the reverse-engineer agent.
$agentMirrors = @(Get-ChildItem "$REPO\agents" -Filter '*-by-pongg.agent.md' -ErrorAction SilentlyContinue | ForEach-Object { 'agents\' + $_.Name })
$pairs = @() + $agentMirrors + @('skills\mcp-surface-audit\SKILL.md', 'skills\capture-lesson\SKILL.md', 'skills\new-program\SKILL.md', 'roster.json', 'tooling\verify-all.ps1', 'tooling\measure-context.ps1', 'tooling\who-locks.ps1', 'tooling\sap-secret.ps1', 'tooling\sap-connection.ps1', 'tooling\sap-arc1-launcher.ps1', 'tooling\sap-auth-probe.js', 'tooling\workspace-sync.ps1', 'tooling\install-kit.ps1')
# tooling\surface.json is deliberately absent from the list. It is runtime state: the sessionStart
# hook rewrites the LIVE copy on every run, so comparing it against the repository snapshot would
# report DRIFT forever, from the first session in which the hook fires. A check that can only fail is
# as useless as one that can only pass.
$missingLive = @()
$compared = 0
foreach ($rel in $pairs) {
    $src = if ($rel -eq 'roster.json') { "$env:USERPROFILE\.copilot\roster.json" }
           elseif ($rel -like 'agents*') { Join-Path $AG (Split-Path $rel -Leaf) }
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

Line '9. SAP password in any harness config: literal, or indirection?'
# VS Code supports ${input:...} and ~/.copilot/mcp.json already uses it. The Copilot CLI accepts
# only --env KEY=VALUE, so its config had the real password as plaintext - invisible to a scan
# that only looks at the repository. A literal here is an ISSUE wherever the file lives.
$configs = [ordered]@{
    'vscode'   = "$env:APPDATA\Code\User\mcp.json"
    'copilot'  = "$env:USERPROFILE\.copilot\mcp-config.json"
}
$credChecked = 0
foreach ($k in $configs.Keys) {
    $p = $configs[$k]
    if (-not (Test-Path $p)) { Write-Output ("  {0,-8} no config" -f $k); continue }
    # $t is read inside the guard and reset each iteration. Reading it outside a guard meant a
    # throwing read left the PREVIOUS config's text in $t, so a directory in place of mcp.json
    # produced "OK no literal secret" for a file that was never opened.
    $t = $null
    try { $t = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8) }
    catch { Write-Output ("  {0,-8} ISSUE   unreadable: {1}" -f $k, $_.Exception.GetType().Name); Note 'ISSUE' 1; continue }
    $credChecked++
    # A literal is a quoted value on a secret-bearing key that is not ${input:...} and not a
    # placeholder. The key list covers what ARC-1 itself reads as a secret (SAP_PASSWORD,
    # SAP_COOKIE_STRING, SAP_BTP_SERVICE_KEY, ARC1_API_KEYS, ...) - a narrower list than that was
    # measured to miss three of them. Keys ending _FILE hold a path, not a secret, so they are out.
    $lit = [regex]::Matches($t, '"[A-Za-z0-9_]*(?:PASSWORD|SECRET|TOKEN|COOKIE|SERVICE_KEY|API_KEY|_KEYS|CRED)[A-Za-z0-9_]*(?<!_FILE)"\s*:\s*"(?!\$\{input:)(?!<)[^"]{1,200}"')
    if ($lit.Count -eq 0) { Write-Output ("  {0,-8} OK      no literal secret" -f $k) }
    else {
        Write-Output ("  {0,-8} ISSUE   {1} literal secret field(s) - move to a credential store" -f $k, $lit.Count)
        foreach ($m in $lit) { Write-Output ("           key: " + (($m.Value -split '"')[1])) }
        Note 'HIT' $lit.Count
    }
}

# The env file that replaced those literals needs the same check, in a different syntax: a secret
# key whose value is not the @secret marker is a plaintext secret sitting in the user profile.
$envFile = "$env:USERPROFILE\.copilot\state\arc1.env"
if (-not (Test-Path $envFile)) {
    Write-Output '  envfile  absent  (arc1.env not created yet - credential-store mode inactive)'
} else {
    $plainSecrets = @()
    $envLines = @()
    try { $envLines = [System.IO.File]::ReadAllLines($envFile, [System.Text.Encoding]::UTF8) }
    catch { Write-Output ("  envfile  ISSUE   unreadable: " + $_.Exception.GetType().Name); Note 'ISSUE' 1 }
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
    if ($plainSecrets.Count -eq 0) { Write-Output '  envfile  OK      every secret line uses @secret' }
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

Line '8. Sensitive values in any tracked file'
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
    foreach ($raw in [System.IO.File]::ReadAllLines($extraFile, [System.Text.Encoding]::UTF8)) {
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
        $found = @(git grep -I -E -f $rxFile $revs 2>$null | Where-Object { $_ })
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
