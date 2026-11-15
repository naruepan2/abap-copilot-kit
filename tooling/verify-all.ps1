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
function Ok($t)   { Write-Output ("  OK      " + $t) }
function Bad($t)  { Write-Output ("  ISSUE   " + $t) }

Line '1. Agent files: structure and encoding'
$agBad = 0; $agCount = 0
foreach ($f in Get-ChildItem $AG -Filter *.agent.md | Sort-Object Name) {
    $b = [System.IO.File]::ReadAllBytes($f.FullName)
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

Line '2. Skill frontmatter parses (both roots)'
foreach ($root in @($SK, "$env:USERPROFILE\.agents\skills")) {
    $n = 0; $bad = 0
    foreach ($d in Get-ChildItem $root -Directory) {
        $s = Join-Path $d.FullName 'SKILL.md'
        if (-not (Test-Path $s)) { continue }
        $n++
        $t = [System.IO.File]::ReadAllText($s, [System.Text.Encoding]::UTF8)
        $m = [regex]::Match($t, "(?s)^---\r?\n(.*?)\r?\n---")
        if (-not $m.Success -or $t -notmatch 'name:' -or $t -notmatch 'description:') { $bad++; Write-Output ("    BAD  " + $d.Name) }
    }
    $label = (Split-Path $root -Parent | Split-Path -Leaf) + ':' + (Split-Path $root -Leaf)
    Write-Output ("  {0,-30} skills={1,3}  bad_frontmatter={2}" -f $label, $n, $bad)
}

Line '3. Cross-file rule duplication (a rule must have one home)'
$agent = [System.IO.File]::ReadAllText("$AG\abap-developer-by-pongg.agent.md", [System.Text.Encoding]::UTF8)
# Each probe is TRUE when the duplication EXISTS - that is the failure state.
$probes = [ordered]@{
    'agent hardcodes a roster count'      = $agent -match '\b\d+ (known|not delegatable|delegatable\b)'
    'audit skill hardcodes a roster count' = ([System.IO.File]::ReadAllText("$SK\mcp-surface-audit\SKILL.md")) -match '\b\d+ (known|live)\b'
    'capture-lesson restates the evidence rule' = ([System.IO.File]::ReadAllText("$SK\capture-lesson\SKILL.md")) -match 'never guess'
    'agent restates the delegation table' = ($agent -split 'roster.json').Count -gt 3
    'agent lost the detail-levels pointer' = $agent -notmatch 'detail-levels\.md'
    'agent copies the detail-level rules' = $agent -match 'enum is closed|terse is deterministic'
}
foreach ($k in $probes.Keys) {
    if (-not $Summary -or $probes[$k]) {
        Write-Output ("  {0} {1}" -f $(if ($probes[$k]) { 'DUP     ' } else { 'OK      ' }), $k)
    }
}
if ($Summary) { Write-Output ("  duplication probes: {0} of {1} flagged" -f @($probes.Keys | Where-Object { $probes[$_] }).Count, $probes.Count) }

Line '4. Memory budget and shape'
$tot = 0; $rules = 0; $facts = 0
foreach ($f in Get-ChildItem $MEM -File -Filter *.md) {
    $t = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
    $tot += ($t -split "`r?`n").Count
    foreach ($l in ($t -split "`r?`n")) {
        if ($l -match '^\s*[-*]\s' -and $l -match '\b(never|always|do not|prefer|ask|verify)\b') { $rules++ }
        elseif ($l -match '^\s*[-*]\s') { $facts++ }
    }
}
Write-Output ("  used={0}/200 lines  headroom={1}  rule-bullets={2}  fact-bullets={3}" -f $tot, (200 - $tot), $rules, $facts)

Line '5. Repo facts: counts that could rot'
$roster = Get-Content "$env:USERPROFILE\.copilot\roster.json" -Raw | ConvertFrom-Json
$known = @(); foreach ($d in $roster.delegatable) { $known += $d.file }; foreach ($g in $roster.not_delegatable) { $known += $g.files }
$live = Get-ChildItem $AG -Filter *.agent.md | ForEach-Object { $_.Name -replace '\.agent\.md$', '' }
Write-Output ("  roster known={0} live={1} NEW={2} GONE={3}" -f $known.Count, $live.Count, @($live | Where-Object { $known -notcontains $_ }).Count, @($known | Where-Object { $live -notcontains $_ }).Count)

Line '5b. SAP AI Dev Toolkit: does the roster still cover what it installs?'
# The toolkit gains agents and skills when it is upgraded, so a number written in prose goes
# stale on its own. Derive everything from its own manifest instead of assuming a count.
$TK = "$env:USERPROFILE\.copilot\.sap-ai-dev-toolkit-assets.json"
if (-not (Test-Path $TK)) {
    Write-Output '  no toolkit manifest - nothing to reconcile'
} else {
    $tk = Get-Content $TK -Raw | ConvertFrom-Json
    $map = @($tk.files)[0]
    $tkAgents = @(); $tkSkills = @(); $hashDrift = @(); $gone = @()
    foreach ($p in $map.PSObject.Properties) {
        if ($p.Name -like 'agents\*') { $tkAgents += ($p.Name -replace '^agents\\', '' -replace '\.agent\.md$', '') }
        elseif ($p.Name -like 'skills\*') { $tkSkills += @(($p.Name -split '\\')[1]) }
        $f = Join-Path "$env:USERPROFILE\.copilot" $p.Name
        if (-not (Test-Path $f)) { $gone += $p.Name }
        elseif ((Get-FileHash $f -Algorithm SHA256).Hash.ToLower() -ne $p.Value) { $hashDrift += $p.Name }
    }
    # An agent the toolkit installs that the roster has not decided about is the failure case:
    # it stays non-delegatable by default-deny, so nobody notices it is undocumented.
    $undecided = @($tkAgents | Where-Object { $known -notcontains $_ })
    Write-Output ("  toolkit installs: {0} agents, {1} skills" -f $tkAgents.Count, $tkSkills.Count)
    if ($undecided.Count -eq 0) {
        Write-Output '  OK      every toolkit agent appears in the roster'
    } else {
        foreach ($u in $undecided) { Write-Output ("  ISSUE   toolkit agent not in roster: " + $u) }
    }
    Write-Output ("  {0} toolkit files edited since install, {1} missing" -f $hashDrift.Count, $gone.Count)
    foreach ($h in $hashDrift) { Write-Output ("          EDITED  " + $h) }
    foreach ($g in $gone) { Write-Output ("          MISSING " + $g) }
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
} else {
    Write-Output '  ISSUE   repo memory has no INDEX.md'
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
$pairs = @() + $agentMirrors + @('skills\mcp-surface-audit\SKILL.md', 'skills\capture-lesson\SKILL.md', 'roster.json', 'tooling\verify-all.ps1', 'tooling\measure-context.ps1', 'tooling\who-locks.ps1', 'tooling\surface.json', 'tooling\sap-secret.ps1', 'tooling\sap-connection.ps1', 'tooling\sap-arc1-launcher.ps1', 'tooling\sap-auth-probe.js', 'tooling\install-kit.ps1')
foreach ($rel in $pairs) {
    $src = if ($rel -eq 'roster.json') { "$env:USERPROFILE\.copilot\roster.json" }
           elseif ($rel -like 'agents*') { Join-Path $AG (Split-Path $rel -Leaf) }
           elseif ($rel -like 'tooling*') { Join-Path "$env:USERPROFILE\.copilot\state" (Split-Path $rel -Leaf) }
           else { Join-Path $SK ($rel -replace 'skills\\', '') }
    if ((Test-Path (Join-Path $REPO $rel)) -and (Test-Path $src)) {
        $a = [System.IO.File]::ReadAllText((Join-Path $REPO $rel), [System.Text.Encoding]::UTF8) -replace "`r`n", "`n"
        $b = [System.IO.File]::ReadAllText($src, [System.Text.Encoding]::UTF8) -replace "`r`n", "`n"
        if ($a -ne $b) { $drift += $rel }
    }
}
if (@($drift).Count -eq 0) { Write-Output '  repo mirrors live files: identical' } else { foreach ($d in $drift) { Write-Output ("  DRIFT: " + $d) } }
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
foreach ($k in $configs.Keys) {
    $p = $configs[$k]
    if (-not (Test-Path $p)) { Write-Output ("  {0,-8} no config" -f $k); continue }
    $t = [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8)
    # A literal is a quoted value on a secret-bearing key that is not ${input:...} and not a
    # placeholder. The key list covers what ARC-1 itself reads as a secret (SAP_PASSWORD,
    # SAP_COOKIE_STRING, SAP_BTP_SERVICE_KEY, ARC1_API_KEYS, ...) - a narrower list than that was
    # measured to miss three of them. Keys ending _FILE hold a path, not a secret, so they are out.
    $lit = [regex]::Matches($t, '"[A-Za-z0-9_]*(?:PASSWORD|SECRET|TOKEN|COOKIE|SERVICE_KEY|API_KEY|_KEYS|CRED)[A-Za-z0-9_]*(?<!_FILE)"\s*:\s*"(?!\$\{input:)(?!<)[^"]{1,200}"')
    if ($lit.Count -eq 0) { Write-Output ("  {0,-8} OK      no literal secret" -f $k) }
    else {
        Write-Output ("  {0,-8} ISSUE   {1} literal secret field(s) - move to a credential store" -f $k, $lit.Count)
        foreach ($m in $lit) { Write-Output ("           key: " + (($m.Value -split '"')[1])) }
    }
}

# The env file that replaced those literals needs the same check, in a different syntax: a secret
# key whose value is not the @secret marker is a plaintext secret sitting in the user profile.
$envFile = "$env:USERPROFILE\.copilot\state\arc1.env"
if (-not (Test-Path $envFile)) {
    Write-Output '  envfile  absent  (arc1.env not created yet - credential-store mode inactive)'
} else {
    $plainSecrets = @()
    foreach ($l in [System.IO.File]::ReadAllLines($envFile, [System.Text.Encoding]::UTF8)) {
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
    else { foreach ($s in $plainSecrets) { Write-Output ("  envfile  ISSUE   plaintext secret or bad line: " + $s) } }

    # And it must not sit inside a repository, where a stray `git add -f` could publish it.
    $dir = Split-Path $envFile -Parent
    $inRepo = $null
    while ($dir -and $dir -ne (Split-Path $dir -Parent)) {
        if (Test-Path (Join-Path $dir '.git')) { $inRepo = $dir; break }
        $dir = Split-Path $dir -Parent
    }
    if ($inRepo) { Write-Output ("  envfile  ISSUE   arc1.env is inside a repository: " + $inRepo) }
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
    catch { $cj = $null; Write-Output '  conns    ISSUE   arc1-connections.json is not valid JSON' }
    if ($cj) {
        $bad = @()
        foreach ($p in $cj.connections.PSObject.Properties) {
            $pw = $p.Value.password
            if ([string]::IsNullOrEmpty($pw)) { $bad += ($p.Name + ' (no password)') }
            elseif ($pw -ne '@secret') { $bad += ($p.Name + ' (plaintext)') }
            if ($p.Value.url -notmatch '^https?://') { $bad += ($p.Name + ' (bad url)') }
            if ($p.Value.client -notmatch '^\d{2,3}$') { $bad += ($p.Name + ' (bad client)') }
        }
        $n = @($cj.connections.PSObject.Properties).Count
        if ($bad.Count -eq 0) { Write-Output ("  conns    OK      {0} connection(s), every password is @secret" -f $n) }
        else { foreach ($b in $bad) { Write-Output ("  conns    ISSUE   " + $b) } }
        if ($cj.active -and -not ($cj.connections.PSObject.Properties.Name -contains $cj.active)) {
            Write-Output ("  conns    ISSUE   active names a missing connection: " + $cj.active)
        }
        $dir = Split-Path $connFile -Parent
        $inRepo = $null
        while ($dir -and $dir -ne (Split-Path $dir -Parent)) {
            if (Test-Path (Join-Path $dir '.git')) { $inRepo = $dir; break }
            $dir = Split-Path $dir -Parent
        }
        if ($inRepo) { Write-Output ("  conns    ISSUE   inside a repository: " + $inRepo) }
    }
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
    try { $cfg = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8) | ConvertFrom-Json }
    catch { Write-Output ("  {0,-8} ISSUE   {1} is not valid JSON" -f $label, (Split-Path $path -Leaf)); return }

    $arc = $cfg.$rootKey.'arc-1'
    if (-not $arc) { Write-Output ("  {0,-8} ISSUE   no arc-1 server in {1}" -f $label, (Split-Path $path -Leaf)); return }

    $argLine = @($arc.args) -join ' '
    $named = $null
    if ($argLine -match 'sap-arc1-launcher\.ps1') {
        if ($argLine -match '-Connection\s+"?([A-Za-z0-9][A-Za-z0-9_-]*)"?') { $named = $Matches[1] }
    }
    if (-not $named) {
        Write-Output ("  {0,-8} ISSUE   arc-1 does not start through sap-arc1-launcher.ps1 -Connection <name>" -f $label)
    }
    elseif ($arc.env.PSObject.Properties.Name -contains 'SAP_PASSWORD') {
        Write-Output ("  {0,-8} ISSUE   arc-1 still passes SAP_PASSWORD in env" -f $label)
    }
    elseif (-not (Test-Path $connFile)) {
        Write-Output ("  {0,-8} ISSUE   names '{1}' but there is no connection store" -f $label, $named)
    }
    else {
        try { $lc = [System.IO.File]::ReadAllText($connFile, [System.Text.Encoding]::UTF8) | ConvertFrom-Json } catch { $lc = $null }
        if (-not $lc) { Write-Output ("  {0,-8} ISSUE   connection store is not valid JSON" -f $label) }
        elseif (-not ($lc.connections.PSObject.Properties.Name -contains $named)) {
            Write-Output ("  {0,-8} ISSUE   names a connection that does not exist: {1}" -f $label, $named)
        }
        else { Write-Output ("  {0,-8} OK      arc-1 -> launcher -> '{1}', no password in the config" -f $label, $named) }
    }
}

Test-LauncherWiring "$env:USERPROFILE\.copilot\mcp-config.json" 'mcpServers' 'launcher'
Test-LauncherWiring "$env:APPDATA\Code\User\mcp.json" 'servers' 'launcher2'

Line '8. Credentials in any tracked file'
if (-not $repoOk) {
    Write-Output '  SKIP    kit repository not found (set $env:ABAP_KIT_ROOT)'
} else {
Push-Location $REPO
$hits = 0
# This file is the scanner, so it necessarily contains the patterns and would flag itself. Skip it
# by relative path rather than weakening the patterns - a scan that ignores its own list is still a
# scan, and keeping the list literal keeps it greppable by a human.
$scanSelf = 'tooling/verify-all.ps1'
foreach ($f in git ls-files) {
    if ($f -eq $scanSelf) { continue }
    $m = Select-String -Path (Join-Path $REPO $f) -Pattern 'Z0000000|example-corp|example\.com|REDACTED|PRIVATE KEY|BEGIN RSA' -ErrorAction SilentlyContinue
    if ($m) { foreach ($x in $m) { Write-Output ("  HIT " + $f + ":" + $x.LineNumber); $hits++ } }
}
Write-Output ("  credential hits = {0}  (scanner itself excluded: {1})" -f $hits, $scanSelf)
Pop-Location
}
