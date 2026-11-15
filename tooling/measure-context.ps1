# measure-context.ps1 - measures what actually enters the model context each session.
# Facts: characters read from disk. Estimates: tokens at 4 chars/token (English prose).
# Never deletes or writes anything except stdout.
#
#   -Detail terse | full | raw    (default terse)   See docs/reference/detail-levels.md
#     terse  totals + the two files worth cutting first
#     full   every section, as this script has always printed
#     raw    byte/encoding audit per file, for when a character count looks wrong
#   -Summary   legacy alias for -Detail terse
param(
    [ValidateSet('terse', 'full', 'raw')]
    [string]$Detail = 'terse',
    [switch]$Summary
)
if ($Summary) { $Detail = 'terse' }

$ErrorActionPreference = 'Continue'
$MEM   = "$env:APPDATA\Code\User\globalStorage\github.copilot-chat\memory-tool\memories"
$ROOTS = @("$env:USERPROFILE\.copilot\skills", "$env:USERPROFILE\.agents\skills")
$AGDIR = "$env:USERPROFILE\.copilot\agents"
$main  = Join-Path $AGDIR 'abap-developer-by-pongg.agent.md'

function Read-Utf8([string]$p) {
    # Under EAP=Continue a failed read returns nothing and the caller receives $null, so every number
    # computed downstream describes a file that was never opened. Returning a sentinel string makes the
    # failure visible in the output instead of arithmetically plausible.
    try { return [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8) }
    catch { return '' }
}
function Tok([int]$chars) { return [int]($chars / 4) }
function Num([int]$n) { return $n.ToString('N0') }

function Get-Sections([string]$path) {
    $raw = Read-Utf8 $path
    $lines = $raw -split "`r?`n"
    $cur = '(preamble)'; $start = 0; $out = @()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^#{1,3}\s') {
            if ($i -gt 0) {
                $txt = ($lines[$start..($i - 1)] -join "`n")
                $out += [pscustomobject]@{ Section = $cur; Chars = $txt.Length; Lines = ($i - $start) }
            }
            $cur = $lines[$i]; $start = $i
        }
    }
    $txt = ($lines[$start..($lines.Count - 1)] -join "`n")
    $out += [pscustomobject]@{ Section = $cur; Chars = $txt.Length; Lines = ($lines.Count - $start) }
    return $out
}

# -- gather: one source of truth for every level, so the levels cannot drift --
# The memory folder is guarded, like the skill roots and the agent folder below. It was the one root
# read without a Test-Path, so on a machine whose memories folder had not been created yet the tool
# printed "memory 0 files 0 chars", a smaller TOTAL, and exit 0 - the same failure the WARNING lines
# exist to prevent for the other roots. Measured 2026-11-15: APPDATA redirected to an empty tree gave
# "memory 0 files", TOTAL 25,574 instead of 31,625, and no warning at all.
$memRows = @()
$memMissing = -not (Test-Path $MEM)
if (-not $memMissing) {
    foreach ($f in Get-ChildItem $MEM -File -Filter *.md | Sort-Object Name) {
        $t = Read-Utf8 $f.FullName
        $memRows += [pscustomobject]@{ Name = $f.Name; Chars = $t.Length; Lines = (($t -split "`r?`n").Count) }
    }
}
$grand = 0
foreach ($r in $memRows) { $grand += $r.Chars }

$skillRows = @()
# A missing root is reported, not skipped. Skipping it printed "skills 0 files" and exited 0, so a
# person who moved ~/.agents/skills saw the always-on cost halve and believed it - the tool's only job
# is that number, and it was answering a question it had not been able to examine.
$missingRoots = @()
foreach ($root in $ROOTS) {
    if (-not (Test-Path $root)) { $missingRoots += $root; continue }
    foreach ($d in Get-ChildItem $root -Directory) {
        $s = Join-Path $d.FullName 'SKILL.md'
        if (-not (Test-Path $s)) { continue }
        $t = Read-Utf8 $s
        $m = [regex]::Match($t, "(?s)^---\r?\n(.*?)\r?\n---")
        $len = 0
        if ($m.Success) { $len = $m.Groups[1].Value.Length }
        $skillRows += [pscustomobject]@{ Root = $root; Name = $d.Name; FM = $len; Full = $t.Length }
    }
}
$skillTotal = 0
foreach ($r in $skillRows) { $skillTotal += $r.FM }
$skillCount = $skillRows.Count

# == terse =====================================================================
if ($Detail -eq 'terse') {
    $always = $grand + $skillTotal
    Write-Output ("always-on  memory  {0,3} files  {1,7} chars  ~{2,6} tok" -f $memRows.Count, (Num $grand), (Num (Tok $grand)))
    Write-Output ("           skills  {0,3} files  {1,7} chars  ~{2,6} tok" -f $skillCount, (Num $skillTotal), (Num (Tok $skillTotal)))
    if ($memMissing) { Write-Output ("           WARNING memory folder not found, its notes are NOT in this total: {0}" -f $MEM) }
    foreach ($mr in $missingRoots) { Write-Output ("           WARNING root not found, its skills are NOT in this total: {0}" -f $mr) }
    if (-not (Test-Path $AGDIR)) { Write-Output ("           WARNING agent folder not found: {0}" -f $AGDIR) }
    Write-Output ("           TOTAL           {0,7} chars  ~{1,6} tok   every request" -f (Num $always), (Num (Tok $always)))
    $mainChars = 0
    if (Test-Path $main) { $mainChars = (Read-Utf8 $main).Length }
    Write-Output ("per-run    main agent          {0,7} chars  ~{1,6} tok   only when it runs" -f (Num $mainChars), (Num (Tok $mainChars)))
    $heavy = $skillRows | Sort-Object FM -Descending | Select-Object -First 1
    if ($heavy) {
        $tag = 'agents'
        if ($heavy.Root -match '\.copilot') { $tag = 'copilot' }
        Write-Output ("heaviest   {0}/{1}  {2} chars" -f $tag, $heavy.Name, (Num $heavy.FM))
    }
    $topMem = $memRows | Sort-Object Chars -Descending | Select-Object -First 1
    if ($topMem) { Write-Output ("           memory/{0}  {1} chars" -f $topMem.Name, (Num $topMem.Chars)) }
    Write-Output ("omitted    section tables and the per-skill list - use -Detail full")
    exit 0
}

# == raw =======================================================================
# Byte-level truth: why a character count disagrees with what you see is usually a BOM,
# mixed line endings, or U+FFFD replacement characters from a bad decode.
if ($Detail -eq 'raw') {
    Write-Output '=== byte/encoding audit (chars from a decoded read, bytes from disk) ==='
    Write-Output ("  {0,-46} {1,8} {2,8} {3,4} {4,6} {5,7}" -f 'file', 'bytes', 'chars', 'BOM', 'CRLF', 'U+FFFD')
    $targets = @()
    if (-not $memMissing) { foreach ($f in Get-ChildItem $MEM -File -Filter *.md) { $targets += $f.FullName } }
    foreach ($root in $ROOTS) {
        if (-not (Test-Path $root)) { continue }
        foreach ($d in Get-ChildItem $root -Directory) {
            $s = Join-Path $d.FullName 'SKILL.md'
            if (Test-Path $s) { $targets += $s }
        }
    }
    foreach ($f in Get-ChildItem $AGDIR -Filter *.md) { $targets += $f.FullName }
    foreach ($p in $targets) {
        # $b persisted across iterations, so a locked file was measured using the PREVIOUS file's
        # bytes and its numbers looked plausible. Reset first, and skip on failure.
        $b = $null
        try { $b = [System.IO.File]::ReadAllBytes($p) }
        catch { Write-Output ('  {0,-46} unreadable: {1}' -f $p, $_.Exception.GetType().Name); continue }
        $u = [System.Text.Encoding]::UTF8.GetString($b)
        $bom = 0
        if ($b.Length -ge 3) { if ($b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF) { $bom = 1 } }
        $crlf = ([regex]::Matches($u, "`r`n")).Count
        $bad = ([regex]::Matches($u, [string][char]0xFFFD)).Count
        $rel = $p
        if ($p.StartsWith($MEM)) { $rel = 'memory/' + (Split-Path $p -Leaf) }
        if ($p.StartsWith($AGDIR)) { $rel = 'agents/' + (Split-Path $p -Leaf) }
        Write-Output ("  {0,-46} {1,8} {2,8} {3,4} {4,6} {5,7}" -f $rel, $b.Length, $u.Length, $bom, $crlf, $bad)
    }
    Write-Output ''
    Write-Output ("  files={0}. bytes exceed chars only where multibyte characters occur." -f $targets.Count)
    exit 0
}

Write-Output '=== 1. USER MEMORY (loaded into every request) ==='
foreach ($r in $memRows) {
    Write-Output ("  {0,-20} {1,6} chars  ~{2,5} tok  ({3} lines)" -f $r.Name, $r.Chars, (Tok $r.Chars), $r.Lines)
}
Write-Output ("  SUBTOTAL {0} chars  ~{1} tok" -f $grand, (Tok $grand))

Write-Output ''
Write-Output '=== 2. SKILL FRONTMATTER (name+description only = always in the prompt) ==='
foreach ($root in $ROOTS) {
    if (-not (Test-Path $root)) { continue }
    $sub = 0; $n = 0
    foreach ($r in $skillRows) {
        if ($r.Root -ne $root) { continue }
        $sub += $r.FM; $n++
    }
    $label = (Split-Path $root -Leaf) + ' [' + $root + ']'
    Write-Output ("  {0,-58} {1,3} skills  {2,6} chars  ~{3} tok" -f $label, $n, $sub, (Tok $sub))
}
Write-Output ("  SUBTOTAL {0} skills  {1} chars  ~{2} tok" -f $skillCount, $skillTotal, (Tok $skillTotal))

Write-Output ''
Write-Output '=== 3. AGENT FILES (full body loads only when that agent runs) ==='
$agentTotal = 0
foreach ($f in Get-ChildItem $AGDIR -Filter *.md | Sort-Object Name) {
    $t = Read-Utf8 $f.FullName
    $agentTotal += $t.Length
    Write-Output ("  {0,-50} {1,6} chars  ~{2,5} tok" -f $f.Name, $t.Length, [int]($t.Length / 4))
}
Write-Output ("  TOTAL {0} chars  ~{1} tok (only one loads per run)" -f $agentTotal, [int]($agentTotal / 4))

Write-Output ''
Write-Output '=== 4. MAIN AGENT - 12 heaviest sections ==='
Get-Sections $main | Sort-Object Chars -Descending | Select-Object -First 12 | ForEach-Object {
    Write-Output ("  {0,5} chars {1,4} lines  {2}" -f $_.Chars, $_.Lines, $_.Section)
}

Write-Output ''
Write-Output '=== 5. MEMORY - 10 heaviest sections ==='
if ($memMissing) { Write-Output ("  memory folder not found: {0}" -f $MEM) }
else {
foreach ($f in Get-ChildItem $MEM -File -Filter *.md) {
    foreach ($s in (Get-Sections $f.FullName | Sort-Object Chars -Descending | Select-Object -First 4)) {
        Write-Output ("  {0,-18} {1,5} chars {2,3} lines  {3}" -f $f.Name, $s.Chars, $s.Lines, $s.Section)
    }
}
}

Write-Output ''
Write-Output '=== 6. PER-SKILL COST, top 15 ==='
$skillRows | Sort-Object FM -Descending | Select-Object -First 15 | ForEach-Object {
    $tag = 'agents'
    if ($_.Root -match '\.copilot') { $tag = 'copilot' }
    Write-Output ("  {0,-8} {1,-42} {2,5} chars  {3,7} body" -f $tag, $_.Name, $_.FM, $_.Full)
}

Write-Output ''
Write-Output '=== 7. TOTALS ==='
$always = $grand + $skillTotal
Write-Output ("  always-on (memory+skills): {0} chars  ~{1} tok" -f $always, [int]($always / 4))
Write-Output ("  if the main agent runs:    +{0} chars  ~{1} tok" -f (Read-Utf8 $main).Length, [int]((Read-Utf8 $main).Length / 4))
