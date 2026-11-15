# sap-arc1-launcher.ps1 - start ARC-1 from a local env file, resolving any secret from DPAPI.
#
# Why a file instead of one hardcoded credential: ARC-1 gains environment variables between
# releases (1.x ships every few days). With a file, a new setting is one added line - the launcher
# never changes. Measured from ARC-1's own config.js, the secrets it reads are SAP_PASSWORD,
# SAP_COOKIE_STRING, SAP_BTP_SERVICE_KEY and ARC1_API_KEYS; *_FILE keys hold a path, not a secret.
#
# Two kinds of line:
#
#   SAP_URL=https://host:44300        <- plaintext, not a secret, readable on purpose
#   SAP_PASSWORD=@secret              <- resolved from DPAPI, never stored in this file
#
# The @secret marker is what keeps this honest: you still read the whole file and see every
# variable, while the value itself stays encrypted and bound to your Windows account. Plaintext
# was rejected because ~/.copilot grants CodexSandboxUsers ReadAndExecute - a plaintext password
# here would be readable by that group, where DPAPI ciphertext is not.
#
# Store a secret:
#   powershell -ExecutionPolicy Bypass -File sap-secret.ps1 -Set -Key SAP_PASSWORD
# Check without starting anything:
#   powershell -ExecutionPolicy Bypass -File sap-arc1-launcher.ps1 -Check
#
# ASCII only, on purpose: a .ps1 without a BOM is decoded as ANSI here.
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Forward,
    [switch]$Check,
    [string]$EnvFile
)

$ErrorActionPreference = 'Stop'
$secretScript = Join-Path $PSScriptRoot 'sap-secret.ps1'
if (-not $EnvFile) { $EnvFile = Join-Path $PSScriptRoot 'arc1.env' }

if (-not (Test-Path $secretScript)) {
    [Console]::Error.WriteLine("sap-arc1-launcher: missing helper at $secretScript")
    exit 1
}
if (-not (Test-Path $EnvFile)) {
    [Console]::Error.WriteLine("sap-arc1-launcher: env file not found: $EnvFile")
    [Console]::Error.WriteLine("Copy config-templates/arc1.env.template from the kit next to this script, then fill it in.")
    exit 1
}

$plain = @()
$secretKeys = @()
$errors = @()

foreach ($raw in [System.IO.File]::ReadAllLines($EnvFile, [System.Text.Encoding]::UTF8)) {
    $line = $raw.TrimEnd("`r")
    if ($line.Trim() -eq '' -or $line.TrimStart().StartsWith('#')) { continue }
    $eq = $line.IndexOf('=')
    if ($eq -lt 1) { $errors += "not KEY=value: $line"; continue }
    $key = $line.Substring(0, $eq).Trim()
    $val = $line.Substring($eq + 1)
    if ($key -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') { $errors += "invalid key name: $key"; continue }

    if ($val.Trim() -eq '@secret') {
        # Relaxed for the child call: under 'Stop', a child's stderr becomes a terminating error
        # and the actionable message below would never print.
        $prev = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $resolved = & powershell -NoProfile -ExecutionPolicy Bypass -File $secretScript -Read -Key $key 2>$null
        $rc = $LASTEXITCODE
        $ErrorActionPreference = $prev
        if ($rc -ne 0 -or [string]::IsNullOrEmpty($resolved)) {
            $errors += "$key is marked @secret but nothing is stored for it"
            continue
        }
        Set-Item -Path ("Env:" + $key) -Value $resolved
        $secretKeys += $key
    }
    else {
        Set-Item -Path ("Env:" + $key) -Value $val
        $plain += $key
    }
}

if ($errors.Count -gt 0) {
    foreach ($e in $errors) { [Console]::Error.WriteLine("sap-arc1-launcher: $e") }
    # Only mention the credential store when that is actually the problem, so a syntax error does
    # not send someone looking for a secret.
    if (@($errors | Where-Object { $_ -match '@secret' }).Count -gt 0) {
        [Console]::Error.WriteLine("Store a missing secret with: sap-secret.ps1 -Set -Key <NAME>")
    }
    exit 1
}

if ($Check) {
    Write-Output ("env file : {0}" -f $EnvFile)
    Write-Output ("           {0} plaintext, {1} from the credential store" -f $plain.Count, $secretKeys.Count)
    foreach ($k in $plain) { Write-Output ("  {0,-30} = {1}" -f $k, (Get-Item ("Env:" + $k)).Value) }
    foreach ($k in $secretKeys) { Write-Output ("  {0,-30} = <resolved, {1} chars, not shown>" -f $k, (Get-Item ("Env:" + $k)).Value.Length) }
    if ($Forward.Count -gt 0) { Write-Output ("would run: " + ($Forward -join ' ')) }
    else { Write-Output 'would run: npx -y arc-1@latest serve' }
    exit 0
}

# Default to the invocation the CLI config used before: npx -y arc-1@latest serve
if ($Forward.Count -eq 0) { $Forward = @('npx', '-y', 'arc-1@latest', 'serve') }

$exe = $Forward[0]
$rest = @($Forward | Select-Object -Skip 1)
& $exe @rest
exit $LASTEXITCODE
