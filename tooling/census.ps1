<#
census.ps1 - what the toolkit consists of, and which audit gate covers each part.

WHY THIS EXISTS
Seven audit rounds fixed defects one at a time, and each round found roughly ten more. The reason is
structural: every round started from "what looks wrong" instead of "what exists". A defect can only be
found in an artifact somebody remembered to look at, so the artifacts nobody listed were audited by
nobody - and 30% of all findings so far have come from exactly there.

This tool answers three questions with measurements, not memory:

  1. INVENTORY   - every artifact the kit owns or depends on, with size and owner.
  2. COVERAGE    - which verify-all.ps1 gate reads each class of artifact, and which reads none.
  3. UNCLASSIFIED - files that exist on disk and appear in no inventory row. This is the check that
                    finds the things nobody knew were there, which is the whole point.

A gate named here is verified against the real script: the tool reads every `Ran '<name>'` call out of
verify-all.ps1 and reports any gate this table names that the script does not actually have. A
coverage claim that cannot be checked is the defect class this repository keeps rediscovering.

  -Detail summary | full | gaps     (default summary)
#>
param(
    [ValidateSet('summary', 'full', 'gaps')]
    [string]$Detail = 'summary'
)
$ErrorActionPreference = 'Stop'

function Read-Text([string]$p) {
    try { return [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8) } catch { return $null }
}

# -- locate everything ---------------------------------------------------------
$REPO = $env:ABAP_KIT_ROOT
if (-not $REPO) {
    $pin = Join-Path $env:USERPROFILE '.copilot\state\kit-root.txt'
    if (Test-Path $pin) { $REPO = ([System.IO.File]::ReadAllText($pin, [System.Text.Encoding]::UTF8)).Trim() }
}
$COPILOT = Join-Path $env:USERPROFILE '.copilot'
$AGSK    = Join-Path $env:USERPROFILE '.agents\skills'
$PARKED  = Join-Path $COPILOT 'skills-disabled'
$MEM     = Join-Path $env:APPDATA 'Code\User\globalStorage\github.copilot-chat\memory-tool\memories'
$BACKUP  = Join-Path $COPILOT 'backups'
$VSCODE  = Join-Path $env:APPDATA 'Code\User'

if (-not $REPO -or -not (Test-Path $REPO)) { Write-Output 'census: kit root not found (set ABAP_KIT_ROOT)'; exit 2 }
$VER = Join-Path $REPO 'tooling\verify-all.ps1'
if (-not (Test-Path $VER)) { Write-Output ('census: audit script not found: ' + $VER); exit 2 }

# -- the real gate list, read from the script, not from memory -------------------
# `Ran` is matched anywhere on a line that has no `#` before it, because some gates register inside a
# conditional: `if ($cfgRead -gt 0) { Ran 'mcp-sources' $cfgRead } else { Skip ... }`. An anchored
# pattern missed exactly that one and reported a real gate as a phantom. A coverage tool that cries
# wolf is as useless as one that stays silent, so the pattern is fixed rather than the claim.
$verText = Read-Text $VER
$liveGates = @()
foreach ($m in [regex]::Matches($verText, "(?m)^[^#\r\n]*\bRan\s+'([^']+)'")) { $liveGates += $m.Groups[1].Value }
$liveGates = @($liveGates | Sort-Object -Unique)

# -- inventory rows ------------------------------------------------------------
$rows = New-Object System.Collections.ArrayList
$known = New-Object 'System.Collections.Generic.HashSet[string]'

function Add-Row([string]$Scope, [string]$Kind, [string]$Name, [string]$Path, [string]$Owner, [string]$Gate) {
    $bytes = 0
    if ($Path -and (Test-Path -LiteralPath $Path)) {
        $i = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
        if ($i -and -not $i.PSIsContainer) { $bytes = $i.Length }
    }
    [void]$rows.Add([pscustomobject]@{ Scope = $Scope; Kind = $Kind; Name = $Name; Path = $Path; Bytes = $bytes; Owner = $Owner; Gate = $Gate })
    if ($Path) { [void]$known.Add($Path.ToLowerInvariant()) }
}
function Add-Tree([string]$Scope, [string]$Kind, [string]$Root, [string]$Filter, [string]$Owner, [string]$Gate) {
    if (-not (Test-Path -LiteralPath $Root)) { return }
    foreach ($f in (Get-ChildItem -LiteralPath $Root -Recurse -File -Filter $Filter -Force -ErrorAction SilentlyContinue)) {
        if ($f.FullName -match '\\\.git\\|\\node_modules\\') { continue }
        $name = $f.FullName.Substring($Root.Length).TrimStart('\')
        Add-Row $Scope $Kind $name $f.FullName $Owner $Gate
    }
}

# Repo: what the kit ships.
Add-Tree 'repo' 'agent'     (Join-Path $REPO 'agents')          '*.agent.md' 'kit'   'agents, mirror, toolkit'
Add-Tree 'repo' 'skill'     (Join-Path $REPO 'skills')          'SKILL.md'   'kit'   'skills, mirror, toolkit'
Add-Tree 'repo' 'tooling'   (Join-Path $REPO 'tooling')         '*'          'kit'   'scripts, reads, mirror, findings'
Add-Tree 'repo' 'hook'      (Join-Path $REPO 'hooks')           '*'          'kit'   'scripts, reads, mirror, subagent-gate'
Add-Tree 'repo' 'template'  (Join-Path $REPO 'templates')       '*'          'kit'   '-'
Add-Tree 'repo' 'config'    (Join-Path $REPO 'config-templates') '*'         'kit'   'labels, credentials'
# Shared binary/text assets are not SKILL.md files; MANIFEST.sha256 is their integrity record.
Add-Tree 'repo' 'asset'     (Join-Path $REPO 'reference-assets')  '*'         'kit'   '-'
Add-Tree 'repo' 'memptpl'   (Join-Path $REPO 'memory-templates') '*'         'kit'   '-'
Add-Tree 'repo' 'doc'       (Join-Path $REPO 'docs')            '*.md'       'kit'   '-'
Add-Tree 'repo' 'note'      (Join-Path $REPO 'backup')          '*'          'kit'   '-'
foreach ($n in @('README.md', 'INDEX.md', 'AGENTS.md', 'CHANGELOG.md', 'SETUP-NEW-MACHINE.md', 'LICENSE', '.gitattributes', '.gitignore')) {
    Add-Row 'repo' 'root-doc' $n (Join-Path $REPO $n) 'kit' '-'
}
Add-Row 'repo' 'roster'  'roster.json'                 (Join-Path $REPO 'roster.json')                 'kit' 'roster, toolkit, mirror'
Add-Row 'repo' 'ledger'  'tooling\findings.json'        (Join-Path $REPO 'tooling\findings.json')       'kit' 'findings, mirror'
Add-Row 'repo' 'decl'    'tooling\removed-on-purpose.json' (Join-Path $REPO 'tooling\removed-on-purpose.json') 'kit' 'removed, tag-notes'

# Live: what the harness actually loads. This is the half that has no manifest anywhere.
Add-Tree 'live' 'agent'  (Join-Path $COPILOT 'agents')          '*.agent.md' 'toolkit-installed' 'toolkit, mirror, roster'
Add-Tree 'live' 'skill'  (Join-Path $COPILOT 'skills')          'SKILL.md'   'toolkit-installed' 'skills, mirror, parked'
Add-Tree 'live' 'skill'  $AGSK                                   'SKILL.md'   'npx-installed'     'skills, parked, removed'
Add-Tree 'live' 'skill'  $PARKED                                 'SKILL.md'   'parked'            'parked'
Add-Tree 'live' 'hook'   (Join-Path $COPILOT 'hooks')           '*.cjs'      'toolkit-installed' 'scripts, subagent-gate, mirror'
Add-Row  'live' 'hookcfg' 'hooks.json' (Join-Path $COPILOT 'hooks\hooks.json') 'machine' '-'
Add-Row  'live' 'roster'  'roster.json' (Join-Path $COPILOT 'roster.json') 'machine' 'roster'

# State: files the tools and hooks write at run time.
Add-Row 'state' 'tooling'  'verify-all.ps1'       (Join-Path $COPILOT 'state\verify-all.ps1')       'installer' 'mirror'
Add-Row 'state' 'tooling'  'write-gate-shim.ps1'  (Join-Path $COPILOT 'state\write-gate-shim.ps1')  'installer' 'mirror'
Add-Row 'state' 'tooling'  'measure-context.ps1'  (Join-Path $COPILOT 'state\measure-context.ps1')  'installer' 'mirror'
Add-Row 'state' 'tooling'  'sap-connection.ps1'   (Join-Path $COPILOT 'state\sap-connection.ps1')   'installer' 'mirror'
Add-Row 'state' 'tooling'  'sap-secret.ps1'       (Join-Path $COPILOT 'state\sap-secret.ps1')       'installer' 'mirror'
Add-Row 'state' 'tooling'  'sap-arc1-launcher.ps1' (Join-Path $COPILOT 'state\sap-arc1-launcher.ps1') 'installer' 'mirror'
Add-Row 'state' 'ledger'   'findings.json'        (Join-Path $COPILOT 'state\findings.json')        'installer' 'mirror'
Add-Row 'state' 'pin'      'kit-root.txt'         (Join-Path $COPILOT 'state\kit-root.txt')         'installer' '-'
Add-Row 'state' 'state'    'surface.json'         (Join-Path $COPILOT 'state\surface.json')         'hook'      '-'
Add-Row 'state' 'state'    'surface.prev.json'    (Join-Path $COPILOT 'state\surface.prev.json')    'hook'      '-'
Add-Row 'state' 'log'      'subagent-rules.log'   (Join-Path $COPILOT 'state\subagent-rules.log')   'hook'      '-'
Add-Row 'state' 'secret'   'arc1-connections.json' (Join-Path $COPILOT 'state\arc1-connections.json') 'machine' 'credentials, launcher'
Add-Row 'state' 'secret'   'sap-arc1-launcher.ps1' (Join-Path $COPILOT 'state\sap-arc1-launcher.ps1') 'installer' 'launcher'

# Config and memory: loaded on every request, or consulted before the first SAP call.
Add-Row 'config' 'mcp'      'mcp.json'        (Join-Path $VSCODE 'mcp.json')        'machine' 'credentials, mcp-sources, launcher'
Add-Row 'config' 'mcp'      'mcp-config.json' (Join-Path $COPILOT 'mcp-config.json') 'machine' 'credentials, mcp-sources, launcher'
Add-Row 'config' 'settings' 'settings.json'   (Join-Path $VSCODE 'settings.json')   'machine' 'mcp-sources, credentials'
Add-Row 'config' 'env'      'arc1.env'        (Join-Path $COPILOT 'arc1.env')       'machine' 'credentials'
Add-Row 'config' 'lock'     '.skill-lock.json' (Join-Path $env:USERPROFILE '.agents\.skill-lock.json') 'npx' '-'
Add-Tree 'memory' 'memory' $MEM '*.md' 'user' 'memory, memory.dup'
Add-Tree 'backup' 'release-note' $BACKUP '*.md' 'machine' 'encoding, tag-notes'

# -- check the coverage claims against the script ------------------------------
$namedGates = @()
foreach ($r in $rows) { foreach ($g in ([string]$r.Gate -split ',')) { $g = $g.Trim(); if ($g -and $g -ne '-') { $namedGates += $g } } }
$namedGates = @($namedGates | Sort-Object -Unique)
$phantom = @($namedGates | Where-Object { $liveGates -notcontains $_ })
$unused  = @($liveGates | Where-Object { $namedGates -notcontains $_ })

# -- unclassified: files on disk that no row claims ----------------------------
# A file in no row is not automatically a gap. Three groups are out of scope by design, and each has
# to say why in one phrase - "not covered" without a reason is how a real gap hides among benign ones.
# Measured 2026-11-16: of 161 unclassified files, 160 fall in these groups and one did not, and the
# one that did not is the group this function was extended for.
#
# Defined before the sweep that calls it. A PowerShell script runs top to bottom, so a function used
# above its definition is a runtime error rather than a parse error - the kind of defect that only
# appears on a machine whose data takes that path.
function Get-SweepReason([string]$group, [string]$p) {
    if ($group -eq 'live\skills') {
        # kit-authored skill subtrees (references/, templates/, schemas/, tools/) installed by
        # install-kit.ps1; only SKILL.md gets an inventory row, so the rest need a reason. The
        # name is specific so an unknown skill's subtree still fails as BLIND.
        if ($p -match '^sap-abap-reverse-engineering\\') { return 'kit-authored reverse-engineering skill content' }
        if ($p -match '^sap-new-program\\references\\salv\\') { return 'shared SALV asset pointer in installed skill' }
        return $null
    }
    if ($group -eq 'live\agent-skills') {
        # Kit-authored reverse-engineering skill copied locally by the 2026-11-24 session; it is not
        # in .skill-lock.json, so the generic third-party reason below would be inaccurate.
        if ($p -match '^sap-abap-reverse-engineering\\') { return 'kit-authored reverse-engineering skill (local copy)' }
        # Kit-authored evaluation fixture for auto-abap-delivery: an in-scope case and a boundary
        # case, stored beside the skill and copied into backup/self-authored. Measured 2026-11-22.
        if ($p -eq 'auto-abap-delivery\evals\evals.json') { return 'kit-authored delivery skill evals' }
        # Owner-authored skill-version-scan script in the user loader root, not lock-tracked. Name
        # the exact file so any other unknown skill content still fails as BLIND. Measured 2026-11-25.
        if ($p -eq 'skill-version-scan\scan.ps1') { return 'owner-authored version-scan script (local copy)' }
        # Third-party skill content installed by npx. The kit does not own these bytes and never edits
        # them; replacing them is `npx skills` work, not this repository's.
        if ($p -match '\\(references|templates|scripts)\\' -or $p -match '\\agents\\(openai|ui_metadata)\.yaml$') { return 'third-party skill content' }
        if ($p -match '^[^\\]+\\README\.md$' -or $p -match '^[^\\]+\\[A-Z][A-Z0-9\-]+\.md$' -or $p -match '^[^\\]+\\SKILL-MECHANICS\.md$') { return 'third-party skill content' }
        # A .bak the owner made before compacting a skill is the owner's copy of third-party work.
        if ($p -match '\.bak-') { return 'owner backup of a third-party skill' }
        return $null
    }
    if ($group -eq 'repo') {
        # Customer project records live under Projects\ and .gitignore names them. The template README
        # in that folder IS tracked, so it needs its own reason rather than the folder's.
        if ($p -eq 'Projects\README.md') { return 'project template README' }
        if ($p -match '^Projects\\') { return 'customer project record (gitignored by design)' }
        # Shared assets are tracked files outside a SKILL.md folder. Add-Tree 'repo' 'asset' names
        # them for coverage; the sweep still sees them, so they need an explicit reason. The
        # MANIFEST.sha256 beside them is verified by `sap-new-program`'s resolution rules.
        if ($p -match '^reference-assets\\') { return 'shared kit asset (MANIFEST.sha256)' }
        # Kit-authored skills own their references/, templates/, schemas/ and tools/ subtrees;
        # Add-Tree 'repo' 'skill' above names only SKILL.md, so the rest need an explicit reason.
        if ($p -match '^skills\\') { return 'kit-authored skill content' }
        return $null
    }
    if ($group -eq 'live\hooks') {
        # The Orca host writes its own hook state into ~/.copilot/hooks. These files are owned by
        # that host, not by the kit; deleting them would break Orca, and granting them inventory
        # rows would imply the kit manages them. Name only the observed files so any other unknown
        # hook still fails the census. Measured 2026-11-20.
        if ($p -eq 'orca.json' -or $p -eq 'orca.json.bak') { return 'orca-host-owned hook state' }
        return $null
    }
    if ($group -eq 'state') {
        # install-kit copies tooling into state\ ; the mirror list compares every one of them, so a
        # copy here is covered even though its name is not one of the inventory rows.
        if ($p -match '\.(ps1|js)$') { return 'installed tooling copy (mirror gate)' }
        if ($p -eq 'removed-on-purpose.json') { return 'installed tooling copy (mirror gate)' }
        return $null
    }
    if ($group -eq 'backup') {
        # The deliberate snapshot taken before the history rewrite, verified by `git bundle verify`.
        if ($p -match '^abap-copilot-kit-\d{8}-prehistory\\') { return 'pre-history snapshot (bundle verified)' }
        return $null
    }
    return $null
}

$sweep = @()
$sweepRoots = @(
    @{ Root = $REPO;                        Label = 'repo' },
    @{ Root = (Join-Path $COPILOT 'agents');        Label = 'live\agents' },
    @{ Root = (Join-Path $COPILOT 'skills');        Label = 'live\skills' },
    @{ Root = $PARKED;                      Label = 'live\parked' },
    @{ Root = $AGSK;                        Label = 'live\agent-skills' },
    @{ Root = (Join-Path $COPILOT 'hooks');         Label = 'live\hooks' },
    @{ Root = (Join-Path $COPILOT 'state');         Label = 'state' },
    @{ Root = $MEM;                         Label = 'memory' },
    @{ Root = $BACKUP;                      Label = 'backup' }
)
foreach ($s in $sweepRoots) {
    if (-not (Test-Path -LiteralPath $s.Root)) { continue }
    foreach ($f in (Get-ChildItem -LiteralPath $s.Root -Recurse -File -Force -ErrorAction SilentlyContinue)) {
        $full = $f.FullName
        if ($full -match '\\\.git\\') { continue }
        if ($f.Extension -eq '.log' -or $f.Name -like '*.lock') { continue }
        if (-not $known.Contains($full.ToLowerInvariant())) {
            $rel = if ($s.Root -eq $REPO) { $full.Substring($REPO.Length).TrimStart('\') } else { $full.Substring($s.Root.Length).TrimStart('\') }
            $sweep += [pscustomobject]@{ Root = $s.Label; Name = $rel; Bytes = $f.Length; Reason = (Get-SweepReason $s.Label $rel) }
        }
    }
}

# -- report --------------------------------------------------------------------
$totalBytes = 0
foreach ($r in $rows) { $totalBytes += $r.Bytes }

Write-Output ('census  kit=' + $REPO)
Write-Output ('  rows={0}  bytes={1}  gates-in-script={2}  gates-used-here={3}' -f $rows.Count, $totalBytes, $liveGates.Count, $namedGates.Count)
Write-Output ''

Write-Output '=== 1. COVERAGE BY ARTIFACT CLASS ==='
Write-Output ('{0,-10} {1,-12} {2,5} {3,10}  {4}' -f 'scope', 'kind', 'files', 'bytes', 'gate(s)')
$byGroup = $rows | Group-Object { [string]$_.Scope + '|' + [string]$_.Kind } | Sort-Object Name
foreach ($g in $byGroup) {
    $first = $g.Group[0]
    $sum = 0
    foreach ($r in $g.Group) { $sum += $r.Bytes }
    $gate = ([string]$first.Gate)
    if ($gate -eq '-') { $gate = 'NONE' }
    Write-Output ('{0,-10} {1,-12} {2,5} {3,10}  {4}' -f $first.Scope, $first.Kind, $g.Count, $sum, $gate)
}
Write-Output ''

if ($Detail -ne 'gaps') {
    Write-Output '=== 2. COVERAGE CLAIMS VERIFIED AGAINST verify-all.ps1 ==='
    if ($phantom.Count -eq 0) { Write-Output ('  OK      all {0} named gate(s) exist in the script' -f $namedGates.Count) }
    else { foreach ($p in $phantom) { Write-Output ('  ISSUE   census names a gate the script does not have: ' + $p) } }
    if ($unused.Count -gt 0) { Write-Output ('  NOTE    gate(s) in the script that cover nothing in this table: ' + ($unused -join ', ')) }
    Write-Output ''
}

Write-Output '=== 3. NO GATE READS THESE ==='
$uncovered = @($rows | Where-Object { [string]$_.Gate -eq '-' })
$uncBytes = 0
foreach ($r in $uncovered) { $uncBytes += $r.Bytes }
Write-Output ('  {0} file(s), {1} bytes' -f $uncovered.Count, $uncBytes)
$uncovered | Group-Object { [string]$_.Scope + '\' + [string]$_.Kind } | Sort-Object Name | ForEach-Object {
    $sum = 0
    foreach ($r in $_.Group) { $sum += $r.Bytes }
    Write-Output ('    {0,-22} {1,3} file(s) {2,9} B' -f $_.Name, $_.Count, $sum)
    if ($Detail -eq 'full') { foreach ($r in ($_.Group | Sort-Object Name)) { Write-Output ('        ' + $r.Name) } }
}
Write-Output ''

Write-Output '=== 4. ON DISK BUT IN NO ROW (the unknown unknowns) ==='
if ($sweep.Count -eq 0) { Write-Output '  none' }
else {
    $sweepBytes = 0
    foreach ($s in $sweep) { $sweepBytes += $s.Bytes }
    Write-Output ('  {0} file(s), {1} bytes' -f $sweep.Count, $sweepBytes)
    $sweep | Group-Object Root | Sort-Object Name | ForEach-Object {
        $sum = 0
        foreach ($r in $_.Group) { $sum += $r.Bytes }
        Write-Output ('    {0,-20} {1,4} file(s) {2,9} B' -f $_.Name, $_.Count, $sum)
        # A reason per group when the whole group shares one, otherwise per file. Printing a reason
        # only at group level let one unexplained file hide behind thirty explained ones - and the
        # first version of this line hid every reason whenever a group had two, so a group with a
        # mixture printed neither. The per-file suffix is what makes the mixture readable.
        $reasons = @($_.Group | ForEach-Object { if ($_.Reason) { $_.Reason } else { 'UNREASONED' } } | Sort-Object -Unique)
        $showPerFile = ($reasons.Count -gt 1) -or ($Detail -eq 'full')
        if ($reasons.Count -eq 1) { Write-Output ('        reason: ' + $reasons[0]) }
        $show = if ($Detail -eq 'full') { $_.Group } else { $_.Group | Select-Object -First 4 }
        foreach ($r in ($show | Sort-Object Name)) {
            if ($r.Reason) { $why = if ($showPerFile) { '   [' + $r.Reason + ']' } else { '' } }
            else { $why = '   <-- NO REASON' }
            Write-Output ('        ' + $r.Name + $why)
        }
        if ($Detail -ne 'full' -and $_.Count -gt 4) { Write-Output ('        ... ' + ($_.Count - 4) + ' more') }
    }
}
Write-Output ''

Write-Output '=== 5. TOTALS ==='
$byScope = $rows | Group-Object Scope | Sort-Object Name
foreach ($g in $byScope) {
    $sum = 0
    foreach ($r in $g.Group) { $sum += $r.Bytes }
    Write-Output ('  {0,-10} {1,4} artifact(s) {2,10} B' -f $g.Name, $g.Count, $sum)
}
Write-Output ('  {0,-10} {1,4} artifact(s) {2,10} B' -f 'UNCLASSIFIED', $sweep.Count, ($sweep | Measure-Object Bytes -Sum).Sum)
Write-Output ''
$gapCount = $uncovered.Count + $sweep.Count
Write-Output ('  unread by any gate: {0} artifact(s) + {1} unclassified = {2}' -f $uncovered.Count, $sweep.Count, $gapCount)

# -- verdict -------------------------------------------------------------------
# This tool began as a report, and a report nobody has to act on is how 161 files stayed invisible for
# seven rounds. It exits non-zero on the two states that mean the inventory is incomplete:
#
#   Phantom - a row claims a gate that verify-all.ps1 does not define, so the coverage table lies.
#   Blind   - a file exists on disk and no row AND no stated reason accounts for it.
#
# Everything else is a fact to read, not a failure: a file no gate reads is worth knowing about, but
# the repository may have decided that deliberately, and that decision belongs in the reason column
# above rather than in an exit code.
$unreasoned = @($sweep | Where-Object { -not $_.Reason })
Write-Output ''
if ($phantom.Count -gt 0) {
    foreach ($g in $phantom) { Write-Output ('  PHANTOM gate named but not defined in verify-all.ps1: ' + $g) }
}
if ($unreasoned.Count -gt 0) {
    foreach ($r in $unreasoned) { Write-Output ('  BLIND   ' + $r.Root + '\' + $r.Name + '  (' + $r.Bytes + ' B)') }
    Write-Output ('  {0} file(s) exist on disk with no inventory row and no stated reason - add a row or a reason' -f $unreasoned.Count)
}
$phantomFail = ($phantom.Count -gt 0)
$blindFail = ($unreasoned.Count -gt 0)
if ($phantomFail -or $blindFail) {
    $parts = @()
    if ($phantomFail) { $parts += ('PHANTOM=' + $phantom.Count) }
    if ($blindFail) { $parts += ('BLIND=' + $unreasoned.Count) }
    Write-Output ('RESULT: incomplete - ' + ($parts -join ' '))
    exit 1
}
Write-Output ('RESULT: complete - {0} row(s), {1} unclassified all with a stated reason, no phantom gate' -f $rows.Count, $sweep.Count)
exit 0
