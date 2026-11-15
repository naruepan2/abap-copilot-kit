# sap-arc1-launcher.ps1 - start ARC-1 with the SAP password pulled from Windows Credential Manager.
#
# Why this exists: ~/.copilot/mcp-config.json (Copilot CLI) can only pass secrets as
# --env KEY=VALUE, so there is no ${input:...} indirection like VS Code has. That config used to
# carry the password in plaintext. This launcher is the MCP `command` instead: it reads the
# secret from the OS credential store, puts it in the child's environment, and never writes it.
#
# Setup, once, in a normal terminal (the value is typed by you and is not echoed):
#   powershell -ExecutionPolicy Bypass -File $env:USERPROFILE\.copilot\state\sap-secret.ps1 -Set
#
# Check it without starting the server:
#   powershell -ExecutionPolicy Bypass -File $env:USERPROFILE\.copilot\state\sap-arc1-launcher.ps1 -Check
#
# ASCII only, on purpose: a .ps1 without a BOM is decoded as ANSI here.
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Forward,
    [switch]$Check,
    [string]$Target = 'SAP_ARC1_PASSWORD'
)

$ErrorActionPreference = 'Stop'
$secretScript = Join-Path $PSScriptRoot 'sap-secret.ps1'

if (-not (Test-Path $secretScript)) {
    [Console]::Error.WriteLine("sap-arc1-launcher: missing helper at $secretScript")
    exit 1
}

# -Read prints the secret to stdout, which is the MCP protocol channel when this runs as a server.
# Capture it through a child process so the value never reaches this process's stdout.
# ErrorActionPreference is relaxed for the call: with 'Stop', a child's stderr becomes a
# terminating error and the useful message below never prints.
$prev = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$secret = & powershell -NoProfile -ExecutionPolicy Bypass -File $secretScript -Read -Target $Target 2>$null
$rc = $LASTEXITCODE
$ErrorActionPreference = $prev
if ($rc -ne 0 -or [string]::IsNullOrEmpty($secret)) {
    [Console]::Error.WriteLine("sap-arc1-launcher: no credential stored as $Target.")
    [Console]::Error.WriteLine("Run: powershell -ExecutionPolicy Bypass -File `"$secretScript`" -Set")
    exit 1
}
$env:SAP_PASSWORD = $secret

if ($Check) {
    Write-Output ("credential found: {0} ({1} chars, value not shown)" -f $Target, $secret.Length)
    $cmd = if ($Forward.Count -gt 1) { $Forward[0] } else { 'npx' }
    Write-Output ("would run: {0} {1}" -f $cmd, (($Forward | Select-Object -Skip 1) -join ' '))
    exit 0
}

# Default to the invocation the CLI config used before: npx -y arc-1@latest serve
if ($Forward.Count -eq 0) { $Forward = @('npx', '-y', 'arc-1@latest', 'serve') }

$exe = $Forward[0]
$rest = @($Forward | Select-Object -Skip 1)
& $exe @rest
exit $LASTEXITCODE
