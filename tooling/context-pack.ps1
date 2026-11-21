# context-pack.ps1 — collect agent-context notes for one project.
# Read-only against SAP. Reads only Projects/<Project>/agent-context/.
# Writes only when -OutFile is given, and only inside that project folder.
param(
    [Parameter(Mandatory=$true)][string]$Project,
    [string]$AppliesTo,
    [string]$OutFile
)
$ErrorActionPreference = 'Stop'
$kit = if ($env:ABAP_KIT_ROOT) { $env:ABAP_KIT_ROOT } else {
    $pin = Join-Path $PSScriptRoot 'kit-root.txt'
    if (Test-Path -LiteralPath $pin) { (Get-Content -LiteralPath $pin -Raw).Trim() } else { Split-Path $PSScriptRoot -Parent }
}
$base = Join-Path $kit 'Projects'
$dir = Join-Path $base (Join-Path $Project 'agent-context')
if (-not (Test-Path -LiteralPath $dir)) {
    Write-Output "NO_NOTES $Project (no agent-context folder)"
    exit 0
}
$inScope = @()
foreach ($f in Get-ChildItem -LiteralPath $dir -Recurse -File -Filter *.md) {
    if ($f.FullName -match '\\inbox\\') { continue }
    $text = [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8)
    $m = [regex]::Match($text, '(?s)^---\r?\n(.*?)\r?\n---')
    if (-not $m.Success) { continue }
    $fm = $m.Groups[1].Value
    $on = [regex]::Match($fm, '(?m)^agent_context:\s*true\s*$').Success
    $draft = [regex]::Match($fm, '(?m)^status:\s*draft\s*$').Success
    if (-not $on -or $draft) { continue }
    if ($AppliesTo) {
        $am = [regex]::Match($fm, '(?m)^applies_to:\s*(.+)$')
        if (-not $am.Success -or $am.Groups[1].Value -notmatch [regex]::Escape($AppliesTo)) { continue }
    }
    $inScope += $f
}
$parts = @("# Context pack - $Project", "")
foreach ($f in ($inScope | Sort-Object FullName)) {
    $parts += "## " + $f.FullName.Substring($dir.Length).TrimStart('\')
    $parts += ""
    $parts += [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8)
    $parts += ""
}
$out = $parts -join "`n"
if ($OutFile) {
    $full = [IO.Path]::GetFullPath($OutFile)
    $projFull = [IO.Path]::GetFullPath((Join-Path $base $Project))
    if (-not $full.StartsWith($projFull, [StringComparison]::OrdinalIgnoreCase)) {
        throw "OutFile must stay inside $projFull"
    }
    [IO.File]::WriteAllText($full, $out, (New-Object System.Text.UTF8Encoding($false)))
    Write-Output "WROTE $full chars=$($out.Length) notes=$($inScope.Count)"
} else {
    Write-Output $out
    Write-Output "PACK chars=$($out.Length) notes=$($inScope.Count)"
}
