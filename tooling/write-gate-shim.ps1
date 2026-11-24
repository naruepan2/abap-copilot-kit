# Location-independent PreToolUse shim for the ABAP Auto Delivery agent.
#
# Why this exists: the agent frontmatter cannot expand %USERPROFILE% or a kit-root
# variable, so a direct hook path to <kit>\tooling\aad_write_gate.py breaks the moment
# the kit is cloned to another drive. install-kit.ps1 copies this file next to the
# pin (~\.copilot\state\write-gate-shim.ps1); the pin is rewritten on every install.
# The agent's hook calls this fixed user-level path, which asks the pin where the kit is.
#
# ASCII only on purpose: PowerShell 5.1 decodes a BOM-less .ps1 as ANSI here.
# Read-only against SAP. Stdin (the hook payload) is passed through untouched.
$ErrorActionPreference = 'Stop'
$pin = Join-Path $env:USERPROFILE '.copilot\state\kit-root.txt'
$kit = $null
if (Test-Path -LiteralPath $pin) {
    $kit = ([System.IO.File]::ReadAllText($pin, [System.Text.Encoding]::UTF8)).Trim()
}
if (-not $kit -or -not (Test-Path -LiteralPath (Join-Path $kit 'tooling\aad_write_gate.py'))) {
    # Fail OPEN, like the gate itself: an unknown kit location must not block ordinary work.
    # The relocation runbook asks for one explicit deny test after every install.
    Write-Error 'write-gate-shim: kit root missing or pin stale; run install-kit.ps1 after moving the kit'
    exit 0
}
$gate = Join-Path $kit 'tooling\aad_write_gate.py'
$payload = [Console]::In.ReadToEnd()
$payload | & python $gate
exit $LASTEXITCODE
