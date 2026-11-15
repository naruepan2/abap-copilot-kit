# workspace-sync.ps1 - mirror the program contracts into the private workspace repository.
#
# Why a mirror at all: the spec is edited where the work happens, in Projects\<PROJECT>\<PROGRAM>,
# which is gitignored because it holds customer identifiers. So the contract - the spec index, the
# change ledger, the yaml that wires them - has no history and no off-machine copy. This script
# copies that contract into a separate private repository, which does have both, without turning a
# 16 MB program folder into a repository.
#
# What is mirrored is an ALLOWLIST, not a denylist. A file type added tomorrow is not mirrored until
# someone names it here, which is the same rule the agent roster follows and for the same reason:
# a denylist leaks the first time nobody notices a new extension.
#
#   Mirrored                          Never mirrored
#   README.md                         spec\source\**   the functional's document, theirs
#   project.yaml, program.yaml        .baseline\**     customer source captured before a TR
#   changes.md                        anything else
#   spec\INDEX.md, spec\notes.md
#   spec\spec.md, spec\CHANGELOG.md
#
# The spec source is deliberately excluded, and the index is not trusted blindly because of it:
# program.yaml records spec_lines and spec_bytes, and -Check compares those against the file on
# disk. A mismatch means the functional sent a new version and nobody re-derived the section map.
# That is reported as a warning, not a failure - -Write cannot fix it, a human has to re-map.
#
#   (no action)                 report what would be mirrored
#   -Check                      report drift; exit 1 if the mirror does not match the source
#   -Write                      copy the contract files and regenerate manifest.json
#   -ShowPaths                  print the resolved paths and exit
#
# ASCII only, on purpose: a .ps1 without a BOM is decoded as ANSI here.
param(
    [string]$Projects,
    [string]$Workspace,
    [string]$RepoMemory,
    [switch]$Check,
    [switch]$Write,
    [switch]$ShowPaths
)

$ErrorActionPreference = 'Stop'

# Same resolution as verify-all.ps1 and install-kit.ps1: environment, pin, then parent folder.
$KitRoot = $env:ABAP_KIT_ROOT
if (-not $KitRoot) {
    $pin = Join-Path $PSScriptRoot 'kit-root.txt'
    if (Test-Path $pin) {
        $pinned = ([System.IO.File]::ReadAllText($pin, [System.Text.Encoding]::UTF8)).Trim()
        if ($pinned -and (Test-Path (Join-Path $pinned 'INDEX.md'))) { $KitRoot = $pinned }
    }
}
if (-not $KitRoot -or -not (Test-Path (Join-Path $KitRoot 'INDEX.md'))) {
    $up = Split-Path $PSScriptRoot -Parent
    if ($up -and (Test-Path (Join-Path $up 'INDEX.md'))) { $KitRoot = $up }
}

if (-not $Projects) {
    if ($KitRoot) { $Projects = Join-Path $KitRoot 'Projects' }
}
if (-not $Workspace) { $Workspace = $env:ABAP_WORKSPACE }

if ($ShowPaths) {
    Write-Output ("kit root  : " + $(if ($KitRoot) { $KitRoot } else { '(not found)' }))
    Write-Output ("projects  : " + $(if ($Projects) { $Projects } else { '(not set)' }))
    Write-Output ("workspace : " + $(if ($Workspace) { $Workspace } else { '(not set - pass -Workspace or set $env:ABAP_WORKSPACE)' }))
    Write-Output ("repo memory: " + $(if ($RepoMemory) { $RepoMemory } else { '(not set - optional, -RepoMemory <path>)' }))
    exit 0
}

if (-not $Projects -or -not (Test-Path $Projects)) {
    [Console]::Error.WriteLine('workspace-sync: no Projects folder at ' + $(if ($Projects) { $Projects } else { '(unresolved)' }))
    [Console]::Error.WriteLine('Pass -Projects <path>, or set $env:ABAP_KIT_ROOT.')
    exit 1
}
if (-not $Workspace) {
    [Console]::Error.WriteLine('workspace-sync: no workspace repository path.')
    [Console]::Error.WriteLine('Pass -Workspace <path>, or set $env:ABAP_WORKSPACE to the clone.')
    exit 1
}
if (-not (Test-Path (Join-Path $Workspace '.git'))) {
    [Console]::Error.WriteLine('workspace-sync: ' + $Workspace + ' is not a git clone.')
    [Console]::Error.WriteLine('Clone it first: git clone https://github.com/naruepan2/abap-copilot-workspace-private.git')
    exit 1
}

# Every destination path is built from $Workspace by string arithmetic (Substring for relative names,
# Join-Path for targets). With a relative -Workspace that arithmetic produces garbage: -Check reported
# every file as EXTRA and -Write deleted what it had just written. Both relative and absolute inputs
# are normalised to one absolute form here, once, before anything is computed from it.
$Workspace = (Resolve-Path -LiteralPath $Workspace).Path.TrimEnd('\')

# Contract files, by name, relative to a program or project folder. The value is the name used in
# the mirror, so a case change on disk cannot silently create a second file.
$contractFiles = @(
    'README.md',
    'project.yaml',
    'program.yaml',
    'changes.md',
    'spec\INDEX.md',
    'spec\notes.md',
    'spec\spec.md',
    'spec\CHANGELOG.md'
)

# Line endings and byte-order marks are normalised before anything is compared or hashed.
#
# Measured: a source file written by an editor is CRLF while one written by a script is LF, the mirror
# copies bytes, and git stores LF because .gitattributes says so. Hashing raw bytes then made a fresh
# clone report five files as differing on a machine where not one byte of content had changed. Content
# equality is what a mirror is about, so the comparison is made on normalised text and the stored hash
# is the hash of that same normalised text - one definition, used by -Check, -Write and the manifest.
function Get-NormText([string]$path) {
    $t = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
    return ($t -replace "`r`n", "`n")
}

function Get-NormBytes([string]$path) {
    return (New-Object System.Text.UTF8Encoding($false)).GetBytes((Get-NormText $path))
}

function Get-RelSha([string]$path) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return ([System.BitConverter]::ToString($sha.ComputeHash((Get-NormBytes $path))) -replace '-', '').ToLower() }
    finally { $sha.Dispose() }
}

function Get-LineCount([string]$path) {    $t = Get-NormText $path
    if ($t -eq '') { return 0 }
    $n = @($t -split "`n").Count
    if ($t.EndsWith("`n")) { $n-- }
    return $n
}

# Minimal scalar read from a yaml file: first "<key>: value" wins. A real parser would be better,
# but this file is written by the templates in this kit, so the shape is known and a dependency is
# not worth carrying for five keys.
function Get-YamlValue([string]$path, [string]$key) {
    if (-not (Test-Path $path)) { return $null }
    $lines = @()
    try { $lines = [System.IO.File]::ReadAllLines($path, [System.Text.Encoding]::UTF8) }
    catch { return $null }
    foreach ($line in $lines) {
        if ($line -match ('^\s*' + [regex]::Escape($key) + '\s*:\s*(.*)$')) {
            $v = $Matches[1]
            $v = ($v -replace '\s+#.*$', '').Trim()
            if ($v -eq '') { return $null }
            return $v
        }
    }
    return $null
}

# Files the mirror repository owns itself. -Check must ignore them and -Write's cleanup must never
# delete them, so there is one definition rather than two lists that drift.
#
# The previous cleanup excluded four names and deleted everything else it did not recognise, which
# means a .gitignore, a LICENSE or a .github/ folder in the workspace repository was destroyed on
# every run. Now the rule is the inverse: only files under `programs\` or `memory\` are considered
# mirror output, and anything else in that repository belongs to the repository.
function Test-RepoOwnedFile([string]$rel) {
    $r = $rel -replace '\\', '/'
    if ($r -eq 'manifest.json' -or $r -eq 'README.md' -or $r -eq '.gitattributes') { return $true }
    if ($r -like '.git/*' -or $r -like '.github/*') { return $true }
    if ($r.StartsWith('.')) { return $true }
    return (-not ($r -like 'programs/*' -or $r -like 'memory/*'))
}

# Build the plan: every file that should exist in the mirror, with its destination path.
$plan = @()
$programsMeta = [ordered]@{}
$sourceWarn = @()

$projectDirs = @(Get-ChildItem $Projects -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notmatch '^(\.|_|node_modules)' })

foreach ($proj in $projectDirs) {
    $projRel = $proj.Name

    foreach ($name in $contractFiles) {
        if ($name -like 'spec\*') { continue }
        $src = Join-Path $proj.FullName $name
        if (Test-Path $src) {
            $plan += [pscustomobject]@{ Src = $src; Rel = ('programs\' + $projRel + '\' + $name) }
        }
    }

    $progDirs = @(Get-ChildItem $proj.FullName -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch '^(\.|_|spec$|node_modules)' })

    foreach ($prog in $progDirs) {
        $key = $projRel + '/' + $prog.Name
        $meta = [ordered]@{}
        $py = Join-Path $prog.FullName 'program.yaml'
        foreach ($k in 'program', 'project', 'transport', 'spec_mode', 'spec_status', 'spec_lines', 'spec_bytes', 'spec_source', 'updated') {
            $v = Get-YamlValue $py $k
            if ($null -ne $v) { $meta[$k] = $v }
        }

        foreach ($name in $contractFiles) {
            $src = Join-Path $prog.FullName $name
            if (Test-Path $src) {
                $plan += [pscustomobject]@{ Src = $src; Rel = ('programs\' + $projRel + '\' + $prog.Name + '\' + $name) }
            }
        }

        # The spec source is not mirrored, so its integrity is checked here instead: if the file on
        # disk no longer matches what program.yaml recorded, the section map describes an older
        # document and the agent would read the wrong lines.
        if ($meta['spec_source'] -and $meta['spec_bytes']) {
            $srcFile = Join-Path $prog.FullName ($meta['spec_source'] -replace '/', '\')
            if (-not (Test-Path $srcFile)) {
                $sourceWarn += ($key + ': spec_source points at a file that is not there')
            }
            else {
                $bytes = (Get-Item $srcFile).Length
                if ([string]$bytes -ne [string]$meta['spec_bytes']) {
                    $sourceWarn += ($key + ': source is ' + $bytes + ' bytes, program.yaml says ' + $meta['spec_bytes'])
                }
            }
        }

        $programsMeta[$key] = $meta
    }
}

if ($plan.Count -eq 0) {
    [Console]::Error.WriteLine('workspace-sync: nothing to mirror - no project folders under ' + $Projects)
    exit 1
}

# This repository is private and exists to hold customer program data, so a customer name or a system
# id is expected here and is not flagged. A password or a token value is different: it must never be
# in any file, private or not, because a private repository is one visibility change away from being
# a public one and history cannot be taken back.
$shape = '(?i)(password|passwd|secret|token|api[_-]?key|service[_-]?key)\s*[:=]\s*["'']([^"'']{8,})["'']'
$placeholder = '\$\{|@secret|PLACEHOLDER|CHANGEME|<[a-z]|xxxx|\.\.\.|_SAP_PASSWORD'

# Repo memory is workspace-scoped and its folder name is a hash, so it is never guessed: the path is
# given explicitly or memory is not mirrored at all.
#
# Recursive, not top-level only. The memory folder has a hierarchy - a parent handbook, then one per
# client, then per-package deltas - and mirroring only the root left five files with no history and no
# off-machine copy. A backup with holes is worse than no backup, because it is trusted.
$memoryPlan = @()
if ($RepoMemory) {
    if (-not (Test-Path $RepoMemory)) {
        [Console]::Error.WriteLine('workspace-sync: -RepoMemory path does not exist: ' + $RepoMemory)
        exit 1
    }
    $rootLen = (Resolve-Path $RepoMemory).Path.Length
    foreach ($f in Get-ChildItem $RepoMemory -File -Filter '*.md' -Recurse -ErrorAction SilentlyContinue) {
        $rel = $f.FullName.Substring($rootLen).TrimStart('\')
        $memoryPlan += [pscustomobject]@{ Src = $f.FullName; Rel = ('memory\' + $rel) }
    }
}

# A broad scan would flag every customer name and be turned off within a week; this one only fires on
# a value where a secret is supposed to be.
$credentialFiles = @()
foreach ($p in @($plan) + @($memoryPlan)) {
    if (-not $p -or -not $p.Src) { continue }
    foreach ($m in @(Select-String -Path $p.Src -Pattern $shape -ErrorAction SilentlyContinue)) {
        if ($m.Line -match $placeholder) { continue }
        $credentialFiles += ($p.Rel + ':' + $m.LineNumber + '  ' + $m.Line.Trim())
    }
}
if ($credentialFiles.Count -gt 0) {
    [Console]::Error.WriteLine('workspace-sync: refusing to mirror - a credential value is present:')
    foreach ($c in $credentialFiles) { [Console]::Error.WriteLine('  ' + $c) }
    [Console]::Error.WriteLine('A password or token belongs in Windows Credential Manager, never in a file.')
    exit 1
}

if (-not $Check -and -not $Write) {
    Write-Output ('projects  : ' + $Projects)
    Write-Output ('workspace : ' + $Workspace)
    Write-Output ('files     : ' + $plan.Count + ' contract file(s), ' + $memoryPlan.Count + ' memory file(s)')
    Write-Output ''
    foreach ($p in $plan + $memoryPlan) { Write-Output ('  ' + $p.Rel) }
    if ($sourceWarn.Count -gt 0) {
        Write-Output ''
        foreach ($w in $sourceWarn) { Write-Output ('  WARN ' + $w) }
    }
    Write-Output ''
    Write-Output 'Nothing was written. Use -Check to compare, -Write to mirror.'
    exit 0
}

if ($Check) {
    $missing = 0
    $differ = 0
    $extra = 0
    $mfIssues = 0

    $expected = @{}
    foreach ($p in $plan + $memoryPlan) { $expected[$p.Rel] = $true }

    foreach ($p in $plan + $memoryPlan) {
        $dest = Join-Path $Workspace $p.Rel
        if (-not (Test-Path $dest)) { Write-Output ('  MISSING ' + $p.Rel); $missing++; continue }
        $a = Get-RelSha $p.Src
        $b = Get-RelSha $dest
        if ($a -ne $b) { Write-Output ('  DIFFER  ' + $p.Rel); $differ++ }
    }

    foreach ($f in Get-ChildItem $Workspace -Recurse -File -ErrorAction SilentlyContinue) {
        $rel = $f.FullName.Substring($Workspace.Length).TrimStart('\')
        if (Test-RepoOwnedFile $rel) { continue }
        if (-not $expected.ContainsKey($rel)) { Write-Output ('  EXTRA   ' + $rel); $extra++ }
    }

    $manifestFile = Join-Path $Workspace 'manifest.json'
    if (-not (Test-Path $manifestFile)) {
        Write-Output '  MISSING manifest.json'; $missing++
    }
    else {
        # A manifest nobody verifies is decoration: it would keep claiming a hash for a file that has
        # since changed. Every entry is re-hashed here, and a file present in the mirror but absent
        # from the manifest is reported too, because that is the case a stale manifest hides.
        try { $mj = [System.IO.File]::ReadAllText($manifestFile, [System.Text.Encoding]::UTF8) | ConvertFrom-Json }
        catch { $mj = $null; Write-Output '  ISSUE   manifest.json is not valid JSON' }
        if ($mj) {
            foreach ($p in $plan + $memoryPlan) {
                $key = ($p.Rel -replace '\\', '/')
                $entry = $mj.files.$key
                if (-not $entry) { Write-Output ('  MANIFEST missing entry: ' + $key); $mfIssues++; continue }
                if ((Get-RelSha $p.Src) -ne [string]$entry.sha256) { Write-Output ('  MANIFEST stale hash:   ' + $key); $mfIssues++ }
            }
        }
    }

    foreach ($w in $sourceWarn) { Write-Output ('  WARN    ' + $w) }

    Write-Output ''
    if ($missing + $differ + $extra + $mfIssues -eq 0) {
        Write-Output ('  mirror matches the source: ' + $plan.Count + ' contract file(s), ' + $memoryPlan.Count + ' memory file(s)')
        if ($sourceWarn.Count -gt 0) { Write-Output ('  ' + $sourceWarn.Count + ' source warning(s) - a human decides, -Write cannot fix them') }
        exit 0
    }
    Write-Output ('  drift: ' + $missing + ' missing, ' + $differ + ' differ, ' + $extra + ' extra, ' + $mfIssues + ' manifest - run -Write')
    exit 1
}

# -Write
$copied = 0
$unchanged = 0
foreach ($p in $plan + $memoryPlan) {
    $dest = Join-Path $Workspace $p.Rel
    $destDir = Split-Path $dest -Parent
    if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }

    $same = (Test-Path $dest) -and ((Get-RelSha $p.Src) -eq (Get-RelSha $dest))
    if ($same) { $unchanged++; continue }

    # Written as normalised text rather than copied, so the mirror has exactly one representation of
    # a file regardless of which editor wrote the source. Copy-Item would preserve CRLF and force the
    # next reader to wonder why a byte comparison and a content comparison disagree.
    [System.IO.File]::WriteAllText($dest, (Get-NormText $p.Src), (New-Object System.Text.UTF8Encoding($false)))
    $copied++
}

# A program that was removed from Projects must not leave a ghost in the mirror.
$removed = 0
$expected = @{}
foreach ($p in $plan + $memoryPlan) { $expected[$p.Rel] = $true }
foreach ($f in Get-ChildItem $Workspace -Recurse -File -ErrorAction SilentlyContinue) {
    $rel = $f.FullName.Substring($Workspace.Length).TrimStart('\')
    # Only mirror output is removable. See Test-RepoOwnedFile: an earlier version deleted every file
    # it did not recognise, which included files the repository owns.
    if (Test-RepoOwnedFile $rel) { continue }
    if (-not $expected.ContainsKey($rel)) { Remove-Item $f.FullName -Force; $removed++ }
}

# The manifest records what was mirrored and how big it was. No timestamp and no absolute path: a
# timestamp makes every run produce a diff, and a machine path is the one thing this repository must
# never carry.
#
# Written by hand rather than with ConvertTo-Json, because that escapes angle brackets as \u003c and
# indents nested objects so far that a one-line change shows up as forty. A manifest is read in a
# diff more often than it is read by a program, so it is formatted for the diff.
$sb = New-Object System.Text.StringBuilder
function Add-Line([string]$text) { [void]$sb.AppendLine($text) }

Add-Line '{'
Add-Line '  "generated_by": "tooling/workspace-sync.ps1",'
Add-Line '  "mirror_of": "the contract files of each program under Projects",'
Add-Line '  "excludes": ["spec/source/**", ".baseline/**", "any file the script does not name"],'

Add-Line '  "program": {'
$pk = @($programsMeta.Keys)
for ($i = 0; $i -lt $pk.Count; $i++) {
    $key = $pk[$i]
    $comma = if ($i -lt $pk.Count - 1) { ',' } else { '' }
    Add-Line ('    "' + $key + '": {')
    $mk = @($programsMeta[$key].Keys)
    for ($j = 0; $j -lt $mk.Count; $j++) {
        $k = $mk[$j]
        $v = ([string]$programsMeta[$key][$k]) -replace '\\', '\\' -replace '"', '\"'
        $c2 = if ($j -lt $mk.Count - 1) { ',' } else { '' }
        Add-Line ('      "' + $k + '": "' + $v + '"' + $c2)
    }
    Add-Line ('    }' + $comma)
}
Add-Line '  },'

Add-Line '  "files": {'
$all = @($plan) + @($memoryPlan)
for ($i = 0; $i -lt $all.Count; $i++) {
    $p = $all[$i]
    $rel = $p.Rel -replace '\\', '/'
    $comma = if ($i -lt $all.Count - 1) { ',' } else { '' }
    Add-Line ('    "' + $rel + '": { "sha256": "' + (Get-RelSha $p.Src) + '", "bytes": ' + (Get-NormBytes $p.Src).Length + ', "lines": ' + (Get-LineCount $p.Src) + ' }' + $comma)
}
Add-Line '  }'
Add-Line '}'

[System.IO.File]::WriteAllText((Join-Path $Workspace 'manifest.json'), $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))

Write-Output ('  mirrored: ' + $copied + ' copied, ' + $unchanged + ' unchanged, ' + $removed + ' removed')
Write-Output ('  manifest: ' + $plan.Count + ' contract file(s), ' + $memoryPlan.Count + ' memory file(s), ' + $programsMeta.Count + ' program(s)')
foreach ($w in $sourceWarn) { Write-Output ('  WARN ' + $w) }
Write-Output ''
Write-Output ('Next: cd "' + $Workspace + '"; git add -A; git commit -m "..."; git push')
exit 0
