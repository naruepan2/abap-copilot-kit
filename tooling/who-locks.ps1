# who-locks.ps1 - reports the current working directory of every given PID.
# Read-only: opens each process for PROCESS_QUERY_INFORMATION|PROCESS_VM_READ and reads
# RTL_USER_PROCESS_PARAMETERS.CurrentDirectory. Writes nothing except stdout.
param([string]$Match = '')

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

$targets = Get-Process | Where-Object { $_.ProcessName -in @('powershell', 'pwsh', 'Code', 'node', 'cmd') }
foreach ($p in $targets) {
    $cwd = $null
    try { $cwd = Get-ProcCwd -processId $p.Id } catch { $cwd = $null }
    if ($null -eq $cwd) { continue }
    if ($Match -ne '' -and $cwd -notlike $Match) { continue }
    Write-Output ("pid={0,-7} {1,-14} cwd={2}" -f $p.Id, $p.ProcessName, $cwd)
}
