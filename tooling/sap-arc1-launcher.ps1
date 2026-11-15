# sap-arc1-launcher.ps1 - start ARC-1 for one named SAP connection.
#
# What an MCP client stores is only this (the connection name, not its details):
#
#   "command": "powershell",
#   "args": ["-NoProfile","-ExecutionPolicy","Bypass","-File",
#            "C:\\Users\\<you>\\.copilot\\state\\sap-arc1-launcher.ps1","-Connection","gsd-120"]
#
# Add or remove a logon with sap-connection.ps1; this file does not change. It reads
# arc1-connections.json, resolves the password from Windows Credential Manager, exports the
# variables ARC-1 reads, and starts the server.
#
# Why the password is not passed as --password: ARC-1 accepts that flag, but argv is visible to any
# process of the same user, which is worse than a file. The secret travels in the child's
# environment instead.
#
#   -Connection <name>   which entry in arc1-connections.json (default: the active one)
#   -EnvFile <path>      optional extra KEY=value lines, applied after the connection
#   -Check               resolve everything and print it, start nothing
#
# ASCII only, on purpose: a .ps1 without a BOM is decoded as ANSI here.
param(
    [string]$Connection,
    [string]$EnvFile,
    [switch]$Check,
    [string[]]$Forward,
    [string]$Store,
    [string]$SecretScript
)

$ErrorActionPreference = 'Stop'
if (-not $Store) { $Store = Join-Path $PSScriptRoot 'arc1-connections.json' }
if (-not $SecretScript) { $SecretScript = Join-Path $PSScriptRoot 'sap-secret.ps1' }

if (-not (Test-Path $SecretScript)) {
    [Console]::Error.WriteLine("sap-arc1-launcher: missing helper at $SecretScript")
    exit 1
}
if (-not (Test-Path $Store)) {
    [Console]::Error.WriteLine("sap-arc1-launcher: no connection store at $Store")
    [Console]::Error.WriteLine("Add one with: sap-connection.ps1 -Add -Name <name> -Url <url> -Client <n> -User <user>")
    exit 1
}

$data = [System.IO.File]::ReadAllText($Store, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
# An empty connections object comes back as $null, and @($null) has length one - a phantom entry.
$names = @($data.connections.PSObject.Properties.Name | Where-Object { $_ })
if ($names.Count -eq 0) {
    [Console]::Error.WriteLine("sap-arc1-launcher: $Store holds no connections")
    exit 1
}
if (-not $Connection) {
    $Connection = $data.active
    if (-not $Connection) {
        [Console]::Error.WriteLine('sap-arc1-launcher: -Connection not given and no active entry set')
        [Console]::Error.WriteLine('Known: ' + ($names -join ', '))
        exit 1
    }
}
if ($names -notcontains $Connection) {
    [Console]::Error.WriteLine("sap-arc1-launcher: no connection named '$Connection'")
    [Console]::Error.WriteLine('Known: ' + ($names -join ', '))
    exit 1
}

$c = $data.connections.$Connection
$secretKey = $Connection + '_SAP_PASSWORD'

# Relaxed for the child call: under 'Stop', a child's stderr becomes a terminating error and the
# actionable message below would never print.
$prev = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$secret = & powershell -NoProfile -ExecutionPolicy Bypass -File $SecretScript -Read -Key $secretKey 2>$null
$rc = $LASTEXITCODE
$ErrorActionPreference = $prev

$errors = @()
if ($c.password -eq '@secret') {
    if ($rc -ne 0 -or [string]::IsNullOrEmpty($secret)) {
        $errors += "no credential stored for '$Connection' (key $secretKey)"
    }
}
elseif ([string]::IsNullOrEmpty($c.password)) {
    $errors += "connection '$Connection' has no password and no @secret marker"
}
else {
    $errors += "connection '$Connection' keeps its password in plaintext - set it to @secret"
}
if ($c.url -notmatch '^https?://') { $errors += "connection '$Connection' has an invalid url: $($c.url)" }
if ($c.client -notmatch '^\d{2,3}$') { $errors += "connection '$Connection' has an invalid client: $($c.client)" }
if (-not $c.user) { $errors += "connection '$Connection' has no user" }

if ($errors.Count -gt 0) {
    foreach ($e in $errors) { [Console]::Error.WriteLine("sap-arc1-launcher: $e") }
    if (@($errors | Where-Object { $_ -match 'credential' }).Count -gt 0) {
        [Console]::Error.WriteLine("Store it with: sap-secret.ps1 -Set -Key $secretKey")
    }
    exit 1
}

Set-Item -Path 'Env:SAP_URL'         -Value $c.url
Set-Item -Path 'Env:SAP_CLIENT'      -Value $c.client
Set-Item -Path 'Env:SAP_USER'        -Value $c.user
Set-Item -Path 'Env:SAP_LANGUAGE'    -Value $(if ($c.language) { $c.language } else { 'EN' })
Set-Item -Path 'Env:SAP_PASSWORD'    -Value $secret
Set-Item -Path 'Env:ARC1_CONNECTION' -Value $Connection

$extra = @()
if ($EnvFile) {
    if (-not (Test-Path $EnvFile)) {
        [Console]::Error.WriteLine("sap-arc1-launcher: env file not found: $EnvFile")
        exit 1
    }
    foreach ($raw in [System.IO.File]::ReadAllLines($EnvFile, [System.Text.Encoding]::UTF8)) {
        $line = $raw.TrimEnd("`r")
        if ($line.Trim() -eq '' -or $line.TrimStart().StartsWith('#')) { continue }
        $eq = $line.IndexOf('=')
        if ($eq -lt 1) { [Console]::Error.WriteLine("sap-arc1-launcher: not KEY=value: $line"); exit 1 }
        $k = $line.Substring(0, $eq).Trim()
        $v = $line.Substring($eq + 1)
        if ($k -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
            [Console]::Error.WriteLine("sap-arc1-launcher: invalid key name: $k")
            exit 1
        }
        if ($v.Trim() -eq '@secret') {
            $prev2 = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            $r2 = & powershell -NoProfile -ExecutionPolicy Bypass -File $SecretScript -Read -Key $k 2>$null
            $rc2 = $LASTEXITCODE
            $ErrorActionPreference = $prev2
            if ($rc2 -ne 0 -or [string]::IsNullOrEmpty($r2)) {
                [Console]::Error.WriteLine("sap-arc1-launcher: $k is marked @secret but nothing is stored for it")
                [Console]::Error.WriteLine("Store it with: sap-secret.ps1 -Set -Key $k")
                exit 1
            }
            Set-Item -Path ('Env:' + $k) -Value $r2
            $extra += ($k + ' (secret)')
        }
        else {
            Set-Item -Path ('Env:' + $k) -Value $v
            $extra += $k
        }
    }
}

if ($Check) {
    Write-Output ("connection : {0}   {1} client {2} user {3}" -f $Connection, $c.url, $c.client, $c.user)
    Write-Output ("password   : <from credential store, {0} chars, not shown>" -f $secret.Length)
    if ($extra.Count -gt 0) { Write-Output ("env file   : {0}  ({1})" -f $EnvFile, ($extra -join ', ')) }
    if ($Forward -and $Forward.Count -gt 0) { Write-Output ("would run  : " + ($Forward -join ' ')) }
    else { Write-Output 'would run  : npx -y arc-1@latest serve' }
    exit 0
}

if (-not $Forward -or $Forward.Count -eq 0) { $Forward = @('npx', '-y', 'arc-1@latest', 'serve') }

$exe = $Forward[0]
$rest = @($Forward | Select-Object -Skip 1)
& $exe @rest
exit $LASTEXITCODE
