# install-kit.ps1 - put this kit's user-scoped files in place on a machine.
#
# This is not a package manager. The kit has no version, no registry and no lockfile, because
# `git pull` in the clone is the update. What this does is copy the files that must live outside
# the clone (agents, tooling, skills) and then tell you the few things a script cannot decide.
#
# It is safe to run repeatedly:
#   unchanged here and there  -> skipped
#   missing at the destination -> copied
#   different                  -> reported, and copied only with -Force
#
# That last rule is the point. The live copy can be newer than the clone - it has happened - and a
# blind copy would silently undo work. verify-all.ps1 section 7 reports the same difference.
#
#   -Check       report what would happen, copy nothing
#   -Force       overwrite a destination that differs
#   -ShowPaths   print the resolved source and destination paths and exit
#
# ASCII only, on purpose: a .ps1 without a BOM is decoded as ANSI here.
param(
    [switch]$Check,
    [switch]$Force,
    [switch]$ShowPaths,
    [string]$KitRoot
)

$ErrorActionPreference = 'Stop'

# Same resolution order as verify-all.ps1, so the two never disagree about where the kit is:
# environment variable, then the pin written by a previous run, then the parent folder.
if (-not $KitRoot) { $KitRoot = $env:ABAP_KIT_ROOT }
if (-not $KitRoot -or -not (Test-Path (Join-Path $KitRoot 'INDEX.md'))) {
    $pinPath = Join-Path $PSScriptRoot 'kit-root.txt'
    if (Test-Path $pinPath) {
        # Guarded, like verify-all's copy of this rule. Under EAP=Stop an unreadable pin - a lock held
        # by a concurrent run, an ACL - terminated the whole script with raw .NET text instead of
        # falling through to the parent-folder fallback three lines down. Measured 2026-11-16: three
        # copies of the rule, one of which knew the trap.
        $pinned = $null
        try { $pinned = ([System.IO.File]::ReadAllText($pinPath, [System.Text.Encoding]::UTF8)).Trim() } catch { $pinned = $null }
        if ($pinned -and (Test-Path (Join-Path $pinned 'INDEX.md'))) { $KitRoot = $pinned }
    }
}
if (-not $KitRoot -or -not (Test-Path (Join-Path $KitRoot 'INDEX.md'))) {
    $up = Split-Path $PSScriptRoot -Parent
    if ($up -and (Test-Path (Join-Path $up 'INDEX.md'))) { $KitRoot = $up }
}
if (-not $KitRoot -or -not (Test-Path (Join-Path $KitRoot 'INDEX.md'))) {
    [Console]::Error.WriteLine('install-kit: cannot find the kit root.')
    [Console]::Error.WriteLine('Clone it, or set $env:ABAP_KIT_ROOT, or pass -KitRoot <path>.')
    exit 1
}

$Copilot = Join-Path $env:USERPROFILE '.copilot'
$dest = [ordered]@{
    agents  = Join-Path $Copilot 'agents'
    tooling = Join-Path $Copilot 'state'
    skills  = Join-Path $Copilot 'skills'
    hooks   = Join-Path $Copilot 'hooks'
}

if ($ShowPaths) {
    Write-Output ("kit root : " + $KitRoot)
    foreach ($k in $dest.Keys) { Write-Output ("  {0,-8} -> {1}" -f $k, $dest[$k]) }
    Write-Output ("  pin      -> " + (Join-Path $dest.tooling 'kit-root.txt'))
    exit 0
}

# The live copies have no way to know where the clone lives, and a drive letter cannot be baked
# into a script that is committed. Write the location once, here, where it belongs.
$pinFile = Join-Path $dest.tooling 'kit-root.txt'
if (-not $Check) {
    if (-not (Test-Path $dest.tooling)) { New-Item -ItemType Directory -Path $dest.tooling -Force | Out-Null }
    [System.IO.File]::WriteAllText($pinFile, $KitRoot, (New-Object System.Text.UTF8Encoding($false)))
}

# What gets copied, and what is deliberately left alone.
#   skills: every directory under skills\ that holds a SKILL.md - the folder is enumerated, not a
#           list, so a skill added later is installed without editing this script. Third-party skills
#           come from `npx skills add <owner>/<repo>`, never from here.
#           and copying them here would fight their own update path.
$plan = @()
foreach ($f in Get-ChildItem (Join-Path $KitRoot 'agents') -File -Filter '*.agent.md' -ErrorAction SilentlyContinue) {
    $plan += [pscustomobject]@{ Kind = 'agents'; Name = $f.Name; Src = $f.FullName; Dest = (Join-Path $dest.agents $f.Name) }
}
# Every file in tooling, not only *.ps1: sap-auth-probe.js is part of the launcher and was silently
# left behind by a *.ps1 filter, which made the launcher report "no node" instead of probing.
#
# surface.json is excluded. It is runtime state: the sessionStart hook writes it on every run, so
# installing a copy of the repository snapshot only plants a file that is wrong the moment a session
# starts. The drift probe skipped it for the same reason; both sides now agree.
foreach ($f in Get-ChildItem (Join-Path $KitRoot 'tooling') -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -in @('.ps1', '.js', '.json') -and $_.Name -ne 'surface.json' }) {
    $plan += [pscustomobject]@{ Kind = 'tooling'; Name = $f.Name; Src = $f.FullName; Dest = (Join-Path $dest.tooling $f.Name) }
}
foreach ($d in Get-ChildItem (Join-Path $KitRoot 'skills') -Directory -ErrorAction SilentlyContinue) {
    $s = Join-Path $d.FullName 'SKILL.md'
    if (-not (Test-Path $s)) { continue }
    $plan += [pscustomobject]@{ Kind = 'skills'; Name = ($d.Name + '\SKILL.md'); Src = $s; Dest = (Join-Path (Join-Path $dest.skills $d.Name) 'SKILL.md') }
}
# Hooks were missed entirely: the installer copied agents, tooling and skills, and never the three
# .cjs files that run on every session. Measured 2026-11-15, the live subagent-rules.cjs was a version
# behind the clone - it still contained the fuzzy allowlist that a previous release had replaced - and
# nothing installed or compared it, so the fix never reached the machine that runs it.
foreach ($f in Get-ChildItem (Join-Path $KitRoot 'hooks') -File -Filter '*.cjs' -ErrorAction SilentlyContinue) {
    $plan += [pscustomobject]@{ Kind = 'hooks'; Name = $f.Name; Src = $f.FullName; Dest = (Join-Path $dest.hooks $f.Name) }
}

foreach ($k in $dest.Keys) {
    # -Check promises to copy nothing, and creating the destination tree is a change to the machine.
    # Measured 2026-11-15: with ~/.copilot absent, -Check created agents\, hooks\, skills\ and state\
    # and still exited 0. The guard is here because this loop runs before the per-file -Check tests.
    if ($Check) { continue }
    if (-not (Test-Path $dest[$k])) { New-Item -ItemType Directory -Path $dest[$k] -Force | Out-Null }
}

$added = 0; $same = 0; $conflict = @(); $forced = 0; $normalised = 0

# Copies are written as normalised text, not copied byte for byte.
#
# The comparison below already normalises line endings, so a CRLF live copy and an LF source count as
# "identical" - but a byte comparison of the same pair disagrees, and the two answers look like a bug
# to anyone who checks with a hash. Measured: sap-arc1-launcher.ps1 was repo-LF and live-CRLF, and
# every check said identical while Get-FileHash said otherwise. Writing the normalised form makes
# both answers agree, and matches what .gitattributes pins in the repository.
function Write-Normalised([string]$src, [string]$dest) {
    $t = [System.IO.File]::ReadAllText($src, [System.Text.Encoding]::UTF8) -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText($dest, $t, (New-Object System.Text.UTF8Encoding($false)))
}

foreach ($i in $plan) {
    if (-not (Test-Path $i.Dest)) {
        if (-not $Check) {
            $parent = Split-Path $i.Dest -Parent
            if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
            Write-Normalised $i.Src $i.Dest
        }
        $added++
        continue
    }
    $a = [System.IO.File]::ReadAllText($i.Src, [System.Text.Encoding]::UTF8) -replace "`r`n", "`n"
    $b = [System.IO.File]::ReadAllText($i.Dest, [System.Text.Encoding]::UTF8) -replace "`r`n", "`n"
    if ($a -eq $b) {
        # Same content, but the bytes may still disagree - a CRLF live copy against an LF source. That
        # is not a conflict (nobody's work is at risk) and it is not "identical" either, because a
        # hash comparison says otherwise. Rewriting it costs one file write and makes the two answers
        # agree; leaving it means every future check has to explain itself.
        #
        # Compare BYTES on both sides, from the files as they are on disk. Comparing the normalised
        # strings here made this test provably false - $a and $b are already CRLF-stripped, so they
        # differ in bytes only when they differ in content, and a CRLF destination was reported
        # "already identical" and never rewritten. The counter converged because it could never fire.
        $rawA = [System.IO.File]::ReadAllBytes($i.Src)
        $rawB = [System.IO.File]::ReadAllBytes($i.Dest)
        $bytesDiffer = -not ([System.Convert]::ToBase64String($rawA) -eq [System.Convert]::ToBase64String($rawB))
        if ($bytesDiffer -and -not $Check) { Write-Normalised $i.Src $i.Dest; $normalised++ }
        elseif ($bytesDiffer) { $normalised++ }
        else { $same++ }
        continue
    }
    if ($Force) {
        if (-not $Check) { Write-Normalised $i.Src $i.Dest }
        $forced++
    }
    else {
        $conflict += $i
    }
}

$mode = if ($Check) { 'check only' } else { 'applied' }
$verb = if ($Check) { 'would copy' } else { 'copied' }
Write-Output ("install-kit: {0}   source {1}" -f $mode, $KitRoot)
Write-Output ("  {0} {1}, {2} already identical, {3} differ{4}{5}" -f $added, $verb, $same, $conflict.Count, $(if ($normalised -gt 0) { ", $normalised line-ending only" } else { '' }), $(if ($forced -gt 0) { ", $forced overwritten by -Force" } else { '' }))
foreach ($c in $conflict) {
    Write-Output ("  DIFFERS  {0}\{1}" -f $c.Kind, $c.Name)
}
if ($conflict.Count -gt 0) {
    Write-Output ''
    Write-Output '  The live copy differs from the clone. Decide which is newer before overwriting:'
    Write-Output '    fewer lines there -> the clone is newer, re-run with -Force'
    Write-Output '    more lines there  -> the live copy is newer, commit it to the kit first'
    Write-Output '  verify-all.ps1 section 7 reports the same difference as DRIFT.'
}

# What a script must not decide for you.
Write-Output ''
Write-Output 'Still manual, on purpose:'
if (-not (Test-Path (Join-Path $Copilot 'roster.json'))) {
    Write-Output '  roster.json      not present - copy kit\roster.json, then edit it yourself (allowlist)'
} else {
    Write-Output '  roster.json      present - left untouched (a human decision, see the file)'
}
Write-Output '  memory           not copied - restore from backup\user-memory only when it is gone'
Write-Output '  mcp.json         not touched - edit it: harness configs hold no secrets, names do'
Write-Output '  hooks.json       not installed - copy hooks\hooks.json.template and resolve {{COPILOT_HOME}}'
Write-Output '  Projects\        not copied - local notebook, gitignored, machine-specific'
Write-Output ''
Write-Output ('Verify with:  powershell -File "' + (Join-Path $dest.tooling 'verify-all.ps1') + '"')
