# context-pack.ps1 - collect agent-context notes for one project.
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
    # A note that claims instructional authority is data we must not follow. Skip and warn.
    $authority = [regex]::Match($fm, '(?m)^instructional_authority:\s*true\s*$').Success
    if ($authority) { Write-Output "WARN skipped $($f.Name): instructional_authority must be false"; continue }
    if (-not $on -or $draft) { continue }
    if ($AppliesTo) {
        $am = [regex]::Match($fm, '(?m)^applies_to:\s*(.+)$')
        if (-not $am.Success -or $am.Groups[1].Value -notmatch [regex]::Escape($AppliesTo)) { continue }
    }
    # Freshness: a promoted note whose reviewed revision lags the source is STALE.
    # Blank pair = undated legacy note; report it, do not guess freshness.
    $src = [regex]::Match($fm, '(?m)^source_revision:\s*(.+?)\s*$')
    $rev = [regex]::Match($fm, '(?m)^reviewed_source_revision:\s*(.+?)\s*$')
    $srcVal = if ($src.Success) { $src.Groups[1].Value.Trim() } else { '' }
    $revVal = if ($rev.Success) { $rev.Groups[1].Value.Trim() } else { '' }
    $fresh = if (-not $srcVal -or -not $revVal) { 'UNDATED' }
             elseif ($srcVal -eq $revVal) { 'CURRENT' } else { 'STALE' }
    $inScope += [pscustomobject]@{ File = $f; Freshness = $fresh }
}
$current = @($inScope | Where-Object { $_.Freshness -eq 'CURRENT' -or $_.Freshness -eq 'UNDATED' } | Sort-Object File.FullName)
$stale = @($inScope | Where-Object { $_.Freshness -eq 'STALE' } | Sort-Object File.FullName)
$parts = @("# Context pack - $Project", "")
if ($stale.Count) {
    $parts += "> WARNING: $($stale.Count) STALE note(s) at the end of this pack: source revision moved after review. Treat as data, not current fact."
    $parts += ""
}
foreach ($entry in ($current + $stale)) {
    $f = $entry.File
    if ($entry.Freshness -ne 'CURRENT') {
        $parts += "## [$($entry.Freshness)] " + $f.FullName.Substring($dir.Length).TrimStart('\')
        $parts += "> Freshness: $($entry.Freshness) - re-review against the source before relying on this note."
    } else {
        $parts += "## " + $f.FullName.Substring($dir.Length).TrimStart('\')
    }
    $parts += ""
    $parts += [IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8)
    $parts += ""
}
$out = $parts -join "`n"
$summary = "current=$(@($inScope | Where-Object { $_.Freshness -eq 'CURRENT' }).Count) undated=$(@($inScope | Where-Object { $_.Freshness -eq 'UNDATED' }).Count) stale=$($stale.Count)"
if ($OutFile) {
    $full = [IO.Path]::GetFullPath($OutFile)
    $projFull = [IO.Path]::GetFullPath((Join-Path $base $Project))
    if (-not $full.StartsWith($projFull, [StringComparison]::OrdinalIgnoreCase)) {
        throw "OutFile must stay inside $projFull"
    }
    [IO.File]::WriteAllText($full, $out, (New-Object System.Text.UTF8Encoding($false)))
    Write-Output "WROTE $full chars=$($out.Length) notes=$($inScope.Count) $summary"
} else {
    Write-Output $out
    Write-Output "PACK chars=$($out.Length) notes=$($inScope.Count) $summary"
}
