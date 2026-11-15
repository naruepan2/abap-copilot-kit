# sap-arc1-launcher.ps1 - start ARC-1 for one named SAP connection.
#
# What an MCP client stores is only this (the connection name, not its details):
#
#   "command": "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe",
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
#   -NoProbe             skip the credential check (use when no node is available)
#   -PromptTimeoutSec N  how long the credential dialog may wait for an answer (default 180)
#   -Check               resolve everything and print it, start nothing
#
# A stored password can go stale: people change it, and policies expire it. Before starting, the
# launcher asks the system whether the password still works, using sap-auth-probe.js - the same
# Node stack ARC-1 uses, so the verdict matches what the server would get. On 401 it opens the
# Windows credential dialog (hidden console: only the dialog appears), stores what you type, and
# probes once more. Anything other than 401 - no route, TLS, server down - is never treated as a
# bad password, because asking for a new password would not fix a network.
#
# ASCII only, on purpose: a .ps1 without a BOM is decoded as ANSI here.
param(
    [string]$Connection,
    [string]$EnvFile,
    [switch]$Check,
    [switch]$NoProbe,
    [int]$PromptTimeoutSec = 180,
    [string[]]$Forward,
    [string]$Store,
    [string]$SecretScript
)

$ErrorActionPreference = 'Stop'
if (-not $Store) { $Store = Join-Path $PSScriptRoot 'arc1-connections.json' }
if (-not $SecretScript) { $SecretScript = Join-Path $PSScriptRoot 'sap-secret.ps1' }

# Never launch 'powershell' by bare name. It only resolves while its own folder is on PATH
# (System32\WindowsPowerShell\v1.0), and a sandboxed or trimmed parent environment does not have
# it. That failed with "no credential stored", which was a wrong diagnosis: the stored credential
# was fine, the helper had never started. $PSHOME always points at the interpreter that is running.
$PwshExe = Join-Path $PSHOME 'powershell.exe'
if (-not (Test-Path $PwshExe)) { $PwshExe = (Get-Process -Id $PID).Path }

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
# actionable message below would never print. The exit code is kept in a script variable because a
# function returns only its output.
function Read-StoredSecret([string]$k) {
    $prevR = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $v = & $PwshExe -NoProfile -ExecutionPolicy Bypass -File $SecretScript -Read -Key $k 2>$null
    $script:SecretReadCode = $LASTEXITCODE
    $ErrorActionPreference = $prevR
    return $v
}

$secret = Read-StoredSecret $secretKey
$rc = $script:SecretReadCode

$errors = @()
if ($c.password -eq '@secret') {
    if ($rc -ne 0 -or [string]::IsNullOrEmpty($secret)) {
        # Key the message off the exit code alone. The two failures read differently and a reader has to
        # be able to tell them apart: the helper exited non-zero (it may have printed nothing at all),
        # or it ran and reported no stored value.
        if ($rc -ne 0) {
            $errors += "could not read credential for '$Connection' (key $secretKey) - the helper exited $rc, which is either 'nothing stored' or a failure to start; run: sap-secret.ps1 -Test -Key $secretKey"
        }
        else {
            $errors += "no credential stored for '$Connection' (key $secretKey)"
        }
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

# Asks the system whether these credentials authenticate. Returns OK, STALE or UNKNOWN - see the
# header of sap-auth-probe.js for why only STALE may lead to asking the user for a new password.
$probeScript = Join-Path $PSScriptRoot 'sap-auth-probe.js'
$nodeExe = $null
if (-not $NoProbe -and (Test-Path $probeScript)) {
    $nodeExe = (Get-Command node -ErrorAction SilentlyContinue).Source
}

function Test-Credentials([string]$pass) {
    if (-not $nodeExe) { return 'UNKNOWN no node' }
    $prevQ = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $env:ARC1_PROBE_URL = $c.url.TrimEnd('/') + '/sap/bc/adt/discovery?sap-client=' + $c.client
    $env:ARC1_PROBE_USER = $c.user
    $env:ARC1_PROBE_PASS = $pass
    $env:ARC1_PROBE_CLIENT = $c.client
    $out = & $nodeExe $probeScript 2>$null
    $ErrorActionPreference = $prevQ
    Remove-Item Env:ARC1_PROBE_URL, Env:ARC1_PROBE_USER, Env:ARC1_PROBE_PASS, Env:ARC1_PROBE_CLIENT -ErrorAction SilentlyContinue
    if ($null -eq $out) { return 'UNKNOWN no output' }
    $line = (@($out) -join ' ').Trim()
    if ($line -eq '') { return 'UNKNOWN no output' }
    return $line
}

if ($errors.Count -gt 0) {
    foreach ($e in $errors) { [Console]::Error.WriteLine("sap-arc1-launcher: $e") }
    if (@($errors | Where-Object { $_ -match 'credential' }).Count -gt 0) {
        [Console]::Error.WriteLine("Store it with: sap-secret.ps1 -Set -Key $secretKey")
    }
    exit 1
}

$verdict = Test-Credentials $secret
$status = ($verdict -split ' ')[0]

# The dialog is drawn by CredentialUIBroker, a separate process: if we are killed, it stays on
# screen. So the wait is bounded and, on timeout, the window we caused is closed explicitly. Only
# windows that did not exist before the prompt are touched, so an unrelated security prompt is safe.
$winSig = @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public static class WinUi {
    delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] static extern bool PostMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);

    const uint WM_CLOSE = 0x0010;

    public static long[] CredentialWindows() {
        List<long> r = new List<long>();
        EnumWindows((h, l) => {
            if (!IsWindowVisible(h)) return true;
            StringBuilder sb = new StringBuilder(256);
            GetWindowTextW(h, sb, 256);
            if (sb.ToString() == "Windows Security") r.Add(h.ToInt64());
            return true;
        }, IntPtr.Zero);
        return r.ToArray();
    }

    public static void Close(long handle) {
        PostMessageW(new IntPtr(handle), WM_CLOSE, IntPtr.Zero, IntPtr.Zero);
    }
}
'@

if ($status -eq 'STALE') {
    [Console]::Error.WriteLine("sap-arc1-launcher: the stored password for '$Connection' was rejected ($verdict)")
    [Console]::Error.WriteLine('  Asking for a new one - the dialog is the only window that will appear.')

    if (-not ('WinUi' -as [type])) { Add-Type -TypeDefinition $winSig -Language CSharp }
    $before = @([WinUi]::CredentialWindows())

    # Hidden on purpose: the credential dialog must not come with a console window behind it.
    $prompt = Start-Process $PwshExe -PassThru -WindowStyle Hidden -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $SecretScript,
        '-Set', '-Gui', '-Key', $secretKey
    )

    if (-not $prompt.WaitForExit($PromptTimeoutSec * 1000)) {
        try { $prompt.Kill() } catch { }
        foreach ($h in @([WinUi]::CredentialWindows() | Where-Object { $before -notcontains $_ })) {
            [WinUi]::Close($h)
        }
        [Console]::Error.WriteLine("sap-arc1-launcher: no answer in $PromptTimeoutSec s - cannot start")
        exit 1
    }
    if ($prompt.ExitCode -ne 0) {
        [Console]::Error.WriteLine('sap-arc1-launcher: no new password was stored - cannot start')
        exit 1
    }
    $secret = Read-StoredSecret $secretKey
    if ([string]::IsNullOrEmpty($secret)) {
        [Console]::Error.WriteLine("sap-arc1-launcher: nothing stored for $secretKey - cannot start")
        exit 1
    }
    $verdict = Test-Credentials $secret
    $status = ($verdict -split ' ')[0]
    if ($status -eq 'STALE') {
        [Console]::Error.WriteLine("sap-arc1-launcher: the new password was rejected too ($verdict)")
        exit 1
    }
}
elseif ($status -ne 'OK') {
    # Not a credential problem. Say so once and carry on; refusing to start would be worse.
    [Console]::Error.WriteLine("sap-arc1-launcher: credential check inconclusive ($verdict) - starting anyway")
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
            $r2 = & $PwshExe -NoProfile -ExecutionPolicy Bypass -File $SecretScript -Read -Key $k 2>$null
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
