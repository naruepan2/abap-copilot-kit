# sap-connection.ps1 - the SAP logon list for ARC-1, the same idea as ABAP FS's Connection Manager.
#
# One named entry per system lives in arc1-connections.json, outside every repository. Adding or
# removing a logon edits that file only - the MCP server entry that starts the launcher never
# changes, because it names the connection instead of listing thirteen environment variables.
#
# Shape, deliberately close to ABAP FS's abapfs.remote so the two are easy to hold in mind:
#
#   { "active": "gsd-120",
#     "connections": {
#       "gsd-120": { "url": "https://host:44381", "client": "120", "user": "<sap user id>",
#                    "language": "EN", "password": "@secret" } } }
#
# "password": "@secret" means the value is in Windows Credential Manager under
# ARC1:<connection>_SAP_PASSWORD. Any other non-empty value is plaintext, and section 9 of
# verify-all.ps1 reports it.
#
#   (no action)                                        list every connection and its secret state
#   -Add -Name x -Url .. -Client .. -User ..           add or replace one
#   -Remove -Name x [-AlsoSecret]                      remove one
#   -Use -Name x                                       mark active, for a launcher without -Connection
#   -Show -Name x                                      one connection, secret masked
#
# ASCII only, on purpose: a .ps1 without a BOM is decoded as ANSI here.
param(
    [switch]$Add,
    [switch]$Remove,
    [switch]$Use,
    [switch]$Show,
    [switch]$AlsoSecret,
    [string]$Name,
    [string]$Url,
    [string]$Client,
    [string]$User,
    [string]$Language = 'EN',
    [string]$Store,
    [string]$SecretScript
)

$ErrorActionPreference = 'Stop'
if (-not $Store) { $Store = Join-Path $PSScriptRoot 'arc1-connections.json' }
if (-not $SecretScript) { $SecretScript = Join-Path $PSScriptRoot 'sap-secret.ps1' }

# Bare 'powershell' only resolves while its own folder is on PATH, which a sandboxed parent may
# trim. $PSHOME is the interpreter that is already running, so it is always correct.
$PwshExe = Join-Path $PSHOME 'powershell.exe'
if (-not (Test-Path $PwshExe)) { $PwshExe = (Get-Process -Id $PID).Path }

function Read-Store {
    if (-not (Test-Path $Store)) { return [pscustomobject]@{ active = $null; connections = [pscustomobject]@{} } }
    $raw = [System.IO.File]::ReadAllText($Store, [System.Text.Encoding]::UTF8)
    if ($raw.Trim() -eq '') { return [pscustomobject]@{ active = $null; connections = [pscustomobject]@{} } }
    $j = $raw | ConvertFrom-Json

    # Both members are back-filled, not just `connections`. Assigning a property that does not exist
    # on a PSCustomObject throws "The property 'active' cannot be found on this object", so a store
    # written by hand or by an older version made -Add and -Use abort without writing anything.
    # Measured: exit -1 and no output.
    #
    # The test is on the shape (`-contains` over the member names), not `String.Contains`. On an
    # object with one property, `.Contains` binds to the STRING method and does a substring test, so
    # a key called `connections2` or `Connections` took the wrong branch depending on how many other
    # keys the file happened to have.
    $names = @($j.PSObject.Properties.Name)
    if ($names -notcontains 'connections' -or $null -eq $j.connections) {
        $j | Add-Member -NotePropertyName connections -NotePropertyValue ([pscustomobject]@{}) -Force
    }
    if ($names -notcontains 'active') {
        $j | Add-Member -NotePropertyName active -NotePropertyValue $null -Force
    }
    return $j
}

function Write-Store($obj) {
    [System.IO.File]::WriteAllText($Store, ($obj | ConvertTo-Json -Depth 8), (New-Object System.Text.UTF8Encoding($false)))
}

# Names of the connections, with nulls filtered out. An empty JSON object comes back as $null, and
# @($null) is an array of length one - which used to render a phantom blank row.
function Get-Names($data) {
    return @($data.connections.PSObject.Properties.Name | Where-Object { $_ })
}

function Secret-Key($n) { return $n + '_SAP_PASSWORD' }

function Secret-Present($n) {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $o = & $PwshExe -NoProfile -ExecutionPolicy Bypass -File $SecretScript -Test -Key (Secret-Key $n) 2>$null
    $ErrorActionPreference = $prev
    return (($o -join '') -match '^PRESENT')
}

$data = Read-Store

if ($Add) {
    if (-not $Name -or -not $Url -or -not $Client -or -not $User) {
        [Console]::Error.WriteLine('Add needs -Name, -Url, -Client and -User.')
        exit 1
    }
    if ($Name -notmatch '^[A-Za-z0-9][A-Za-z0-9_-]*$') {
        [Console]::Error.WriteLine("Invalid -Name '$Name'. Letters, digits, underscore and dash; must not start with a symbol.")
        exit 1
    }
    if ($Url -notmatch '^https?://') { [Console]::Error.WriteLine('-Url must start with http:// or https://'); exit 1 }
    if ($Client -notmatch '^\d{2,3}$') { [Console]::Error.WriteLine('-Client must be 2 or 3 digits.'); exit 1 }

    $entry = [pscustomobject]@{
        url      = $Url
        client   = $Client
        user     = $User
        language = $Language
        password = '@secret'
    }
    $data.connections | Add-Member -NotePropertyName $Name -NotePropertyValue $entry -Force
    if (-not $data.active) { $data.active = $Name }
    Write-Store $data
    Write-Output "added: $Name  ($Url client $Client, user $User)"
    if (-not (Secret-Present $Name)) {
        Write-Output ''
        Write-Output 'Next: store its password (you type it; it is not echoed):'
        Write-Output ("  powershell -ExecutionPolicy Bypass -File `"$SecretScript`" -Set -Key " + (Secret-Key $Name))
    }
    exit 0
}

if ($Remove) {
    if (-not $Name) { [Console]::Error.WriteLine('Remove needs -Name.'); exit 1 }
    if ((Get-Names $data) -notcontains $Name) { [Console]::Error.WriteLine("No connection named '$Name'."); exit 1 }
    $data.connections.PSObject.Properties.Remove($Name)
    if ($data.active -eq $Name) {
        $left = Get-Names $data
        $data.active = if ($left.Count -gt 0) { $left[0] } else { $null }
    }
    Write-Store $data
    Write-Output "removed: $Name"
    if ($data.active) { Write-Output "active is now: $($data.active)" } else { Write-Output 'no connections left' }
    if ($AlsoSecret) {
        $prev = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        & $PwshExe -NoProfile -ExecutionPolicy Bypass -File $SecretScript -Remove -Key (Secret-Key $Name) 2>$null | Out-Null
        $ErrorActionPreference = $prev
        Write-Output ("also removed its stored secret: " + (Secret-Key $Name))
    } else {
        Write-Output ("its stored secret was kept: " + (Secret-Key $Name) + "  (add -AlsoSecret to remove it)")
    }
    exit 0
}

if ($Use) {
    if (-not $Name) { [Console]::Error.WriteLine('Use needs -Name.'); exit 1 }
    if ((Get-Names $data) -notcontains $Name) { [Console]::Error.WriteLine("No connection named '$Name'. Run with no action to list."); exit 1 }
    $data.active = $Name
    Write-Store $data
    Write-Output "active: $Name"
    exit 0
}

if ($Show) {
    if (-not $Name) { [Console]::Error.WriteLine('Show needs -Name.'); exit 1 }
    if ((Get-Names $data) -notcontains $Name) { [Console]::Error.WriteLine("No connection named '$Name'."); exit 1 }
    $c = $data.connections.$Name
    Write-Output ("name      : " + $Name + $(if ($data.active -eq $Name) { '  (active)' } else { '' }))
    Write-Output ("url       : " + $c.url)
    Write-Output ("client    : " + $c.client)
    Write-Output ("user      : " + $c.user)
    Write-Output ("language  : " + $c.language)
    Write-Output ("password  : " + $(if ($c.password -eq '@secret') { 'in the credential store' } elseif ([string]::IsNullOrEmpty($c.password)) { 'not set' } else { 'PLAINTEXT IN FILE' }))
    Write-Output ("secret key: " + (Secret-Key $Name) + "  " + $(if (Secret-Present $Name) { 'PRESENT' } else { 'ABSENT' }))
    exit 0
}

# default action: list
Write-Output ("store: " + $Store)
$names = Get-Names $data
if ($names.Count -eq 0) {
    Write-Output 'no connections - add one with -Add -Name <name> -Url <url> -Client <n> -User <user>'
    exit 0
}
Write-Output ''
Write-Output ("  {0,-16} {1,-8} {2,-42} {3}" -f 'NAME', 'CLIENT', 'URL', 'SECRET')
foreach ($n in $names) {
    $c = $data.connections.$n
    $mark = if ($data.active -eq $n) { '*' } else { ' ' }
    $sec = if (Secret-Present $n) { 'stored' } elseif ($c.password -eq '@secret') { 'MISSING' } else { 'PLAINTEXT' }
    Write-Output ("{0} {1,-16} {2,-8} {3,-42} {4}" -f $mark, $n, $c.client, $c.url, $sec)
}
Write-Output ''
Write-Output '* = active, used by a launcher started without -Connection'
