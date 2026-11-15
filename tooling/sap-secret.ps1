# sap-secret.ps1 - keep the SAP password in Windows Credential Manager instead of in JSON.
#
# Copilot CLI reads ~/.copilot/mcp-config.json and can only pass secrets as --env KEY=VALUE,
# so there is no ${input:...} there. That file used to hold the password in plaintext.
#   -Read   print the stored password to stdout (for a launcher to capture)
#   -Set    prompt once and store it (interactive; the value never enters a chat or a file)
#   -Remove delete the stored entry
#   -Test   report whether an entry exists, without reading it
#
# ASCII only, on purpose: a .ps1 without a BOM is decoded as ANSI here.
param(
    [switch]$Read,
    [switch]$Set,
    [switch]$Remove,
    [switch]$Test,
    [string]$Target = 'SAP_ARC1_PASSWORD'
)

$ErrorActionPreference = 'Stop'

$sig = @'
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class CredMan {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct CREDENTIAL {
        public uint Flags;
        public uint Type;
        public IntPtr TargetName;
        public IntPtr Comment;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
        public uint CredentialBlobSize;
        public IntPtr CredentialBlob;
        public uint Persist;
        public uint AttributeCount;
        public IntPtr Attributes;
        public IntPtr TargetAlias;
        public IntPtr UserName;
    }

    [DllImport("advapi32.dll", EntryPoint = "CredReadW", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool CredRead(string target, uint type, uint flags, out IntPtr credentialPtr);

    [DllImport("advapi32.dll", EntryPoint = "CredWriteW", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool CredWrite(ref CREDENTIAL credential, uint flags);

    [DllImport("advapi32.dll", EntryPoint = "CredDeleteW", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool CredDelete(string target, uint type, uint flags);

    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern void CredFree(IntPtr buffer);

    const uint CRED_TYPE_GENERIC = 1;
    const uint CRED_PERSIST_LOCAL_MACHINE = 2;

    public static string Read(string target) {
        IntPtr ptr;
        if (!CredRead(target, CRED_TYPE_GENERIC, 0, out ptr)) return null;
        try {
            CREDENTIAL cred = (CREDENTIAL)Marshal.PtrToStructure(ptr, typeof(CREDENTIAL));
            return Marshal.PtrToStringUni(cred.CredentialBlob, (int)(cred.CredentialBlobSize / 2));
        } finally { CredFree(ptr); }
    }

    public static bool Write(string target, string user, string secret) {
        CREDENTIAL cred = new CREDENTIAL();
        cred.Type = CRED_TYPE_GENERIC;
        cred.Persist = CRED_PERSIST_LOCAL_MACHINE;
        cred.TargetName = Marshal.StringToCoTaskMemUni(target);
        cred.UserName = Marshal.StringToCoTaskMemUni(user ?? "sap");
        byte[] blob = Encoding.Unicode.GetBytes(secret);
        cred.CredentialBlobSize = (uint)blob.Length;
        cred.CredentialBlob = Marshal.AllocCoTaskMem(blob.Length);
        Marshal.Copy(blob, 0, cred.CredentialBlob, blob.Length);
        try {
            return CredWrite(ref cred, 0);
        } finally {
            Marshal.FreeCoTaskMem(cred.TargetName);
            Marshal.FreeCoTaskMem(cred.UserName);
            Marshal.FreeCoTaskMem(cred.CredentialBlob);
        }
    }

    public static bool Delete(string target) {
        return CredDelete(target, CRED_TYPE_GENERIC, 0);
    }
}
'@

if (-not ('CredMan' -as [type])) { Add-Type -TypeDefinition $sig -Language CSharp }

if ($Set) {
    $sec = Read-Host -AsSecureString "SAP password for ARC-1 (stored as $Target)"
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try { $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
    if ([string]::IsNullOrEmpty($plain)) { Write-Error 'Empty password - nothing stored.'; exit 1 }
    if ([CredMan]::Write($Target, 'sap', $plain)) { Write-Output "stored in Windows Credential Manager: $Target" }
    else { Write-Error ("CredWrite failed: " + [Runtime.InteropServices.Marshal]::GetLastWin32Error()); exit 1 }
    exit 0
}

if ($Remove) {
    if ([CredMan]::Delete($Target)) { Write-Output "removed: $Target" } else { Write-Output "nothing to remove: $Target" }
    exit 0
}

if ($Test) {
    $v = [CredMan]::Read($Target)
    if ($null -eq $v) { Write-Output "ABSENT  $Target" } else { Write-Output ("PRESENT " + $Target + "  (" + $v.Length + " chars)") }
    exit 0
}

if ($Read) {
    $v = [CredMan]::Read($Target)
    if ($null -eq $v) { Write-Error "no credential stored as $Target - run: sap-secret.ps1 -Set"; exit 1 }
    Write-Output $v
    exit 0
}

Write-Output 'Usage: sap-secret.ps1 -Set | -Test | -Remove | -Read'
