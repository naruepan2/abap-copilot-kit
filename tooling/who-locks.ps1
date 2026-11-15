# who-locks.ps1 - reports the current working directory of running processes.
# Read-only: opens each process for PROCESS_QUERY_INFORMATION|PROCESS_VM_READ and reads
# RTL_USER_PROCESS_PARAMETERS.CurrentDirectory. Writes nothing except stdout.
#
#   -Match <wildcard>  only rows whose cwd matches (for example 'D:\abap*')
#   -Pid <ids>         only these process ids; default is the interpreters and editors listed below
#
# -Pid is an alias for -ProcessId because $PID is a read-only automatic variable in PowerShell.
param([string]$Match = '', [Alias('Pid')][int[]]$ProcessId = @())

$sig = @'
using System;
using System.Runtime.InteropServices;
public class PebReader {
    [StructLayout(LayoutKind.Sequential)]
    public struct PROCESS_BASIC_INFORMATION {
        public IntPtr Reserved1;
        public IntPtr PebBaseAddress;
        public IntPtr Reserved2_0;
        public IntPtr Reserved2_1;
        public IntPtr UniqueProcessId;
        public IntPtr Reserved3;
    }
    [DllImport("ntdll.dll")]
    public static extern int NtQueryInformationProcess(IntPtr h, int cls,
        ref PROCESS_BASIC_INFORMATION pbi, int len, out int retLen);
    [DllImport("kernel32.dll")]
    public static extern IntPtr OpenProcess(int access, bool inherit, int pid);
    [DllImport("kernel32.dll")]
    public static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, IntPtr size, out IntPtr read);
    [DllImport("kernel32.dll")]
    public static extern bool CloseHandle(IntPtr h);
}
'@
if (-not ('PebReader' -as [type])) { Add-Type -TypeDefinition $sig }

function Get-ProcCwd([int]$processId) {
    $h = [PebReader]::OpenProcess(0x0410, $false, $processId)   # QUERY_INFORMATION | VM_READ
    if ($h -eq [IntPtr]::Zero) { return $null }
    try {
        $pbi = New-Object PebReader+PROCESS_BASIC_INFORMATION
        $rl = 0
        if ([PebReader]::NtQueryInformationProcess($h, 0, [ref]$pbi, 48, [ref]$rl) -ne 0) { return $null }

        $buf = New-Object byte[] 8
        $read = [IntPtr]::Zero
        $ok = [PebReader]::ReadProcessMemory($h, [IntPtr]($pbi.PebBaseAddress.ToInt64() + 0x20), $buf, [IntPtr]8, [ref]$read)
        if (-not $ok) { return $null }
        $params = [BitConverter]::ToInt64($buf, 0)
        if ($params -eq 0) { return $null }

        # CURDIR.DosPath is a UNICODE_STRING at RTL_USER_PROCESS_PARAMETERS + 0x38
        $sb = New-Object byte[] 16
        $ok = [PebReader]::ReadProcessMemory($h, [IntPtr]($params + 0x38), $sb, [IntPtr]16, [ref]$read)
        if (-not $ok) { return $null }
        $len = [BitConverter]::ToUInt16($sb, 0)
        $ptr = [BitConverter]::ToInt64($sb, 8)
        if ($len -le 0 -or $ptr -eq 0) { return '' }

        $tb = New-Object byte[] $len
        $ok = [PebReader]::ReadProcessMemory($h, [IntPtr]$ptr, $tb, [IntPtr]$len, [ref]$read)
        if (-not $ok) { return $null }
        return [System.Text.Encoding]::Unicode.GetString($tb)
    } finally {
        [void][PebReader]::CloseHandle($h)
    }
}

$targets = if ($ProcessId.Count -gt 0) {
    foreach ($procId in $ProcessId) { Get-Process -Id $procId -ErrorAction SilentlyContinue }
} else {
    Get-Process | Where-Object { $_.ProcessName -in @('powershell', 'pwsh', 'Code', 'node', 'cmd') }
}
$rows = 0
foreach ($p in $targets) {
    $cwd = $null
    try { $cwd = Get-ProcCwd -processId $p.Id } catch { $cwd = $null }
    # A null result means the PEB could not be read: another user's process, or no SeDebugPrivilege.
    # Skipping it made an unreadable pid look like a process that holds no directory at all.
    if ($null -eq $cwd) { $cwd = '?' } elseif ($cwd -eq '') { $cwd = '(none)' }
    if ($Match -ne '' -and $cwd -notlike $Match) { continue }
    Write-Output ("pid={0,-7} {1,-14} cwd={2}" -f $p.Id, $p.ProcessName, $cwd)
    $rows++
}
# Zero rows used to be indistinguishable from "nothing holds it": a nonexistent -Pid listed no
# processes and exited 0, and so did a -Match that matched no directory. Both read as a measurement
# when nothing had been examined. Say which case happened instead.
if ($rows -eq 0) {
    if ($ProcessId.Count -gt 0) { Write-Output ("no such process: pid {0}" -f ($ProcessId -join ', ')) }
    elseif ($Match -ne '') { Write-Output ("no process holds a directory matching: {0}" -f $Match) }
    else { Write-Output 'no candidate process found' }
}
