# sap-secret.ps1 - keep ARC-1 secrets in Windows Credential Manager instead of in JSON or .env.
#
# Copilot CLI reads ~/.copilot/mcp-config.json and can only pass secrets as --env KEY=VALUE, so
# there is no ${input:...} there. ~/.copilot also grants CodexSandboxUsers ReadAndExecute, so a
# plaintext file in that folder is not private. This stores each secret as its own credential
# entry, addressed by the ARC-1 variable name.
#
#   -Set -Key NAME   prompt once and store (interactive; the value never enters a chat or a file)
#   -Set -Gui -Key   same, but in a Windows dialog instead of the console. Use this when the
#                    terminal that runs the script is not the one you can see.
#   -Read -Key NAME   print it to stdout (the launcher captures it)
#   -Test -Key NAME   report PRESENT/ABSENT and the length, without revealing the value
#   -Remove -Key NAME delete the entry
#   -List             list the ARC1 entries that exist
#
# Any ARC-1 secret works without editing this script: SAP_PASSWORD, SAP_COOKIE_STRING,
# SAP_BTP_SERVICE_KEY, ARC1_API_KEYS, or one it gains later.
#
# ASCII only, on purpose: a .ps1 without a BOM is decoded as ANSI here.
param(
    [switch]$Read,
    [switch]$Set,
    [switch]$Remove,
    [switch]$Test,
    [switch]$List,
    [switch]$Gui,
    [string]$Key
)

$ErrorActionPreference = 'Stop'
$Prefix = 'ARC1:'

if (($Set -or $Read -or $Remove -or $Test) -and -not $Key) {
    Write-Error 'Specify -Key NAME (for example -Key SAP_PASSWORD, or gsd-120_SAP_PASSWORD).'
    exit 1
}
if ($Key -and $Key -notmatch '^[A-Za-z_][A-Za-z0-9_-]*$') {
    Write-Error "Invalid key name '$Key'. Letters, digits, underscore and dash only."
    exit 1
}
$Target = if ($Key) { $Prefix + $Key } else { $Prefix.TrimEnd(':') }

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

    [DllImport("advapi32.dll", EntryPoint = "CredEnumerateW", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool CredEnumerate(string filter, uint flags, out uint count, out IntPtr credentials);

    // Returns the target names whose credential target starts with the given prefix. Names only -
    // never the secrets themselves.
    public static string[] Enumerate(string prefix) {
        uint count;
        IntPtr ptr;
        if (!CredEnumerate(prefix + "*", 0, out count, out ptr)) return new string[0];
        try {
            string[] result = new string[count];
            for (int i = 0; i < count; i++) {
                IntPtr item = Marshal.ReadIntPtr(ptr, i * IntPtr.Size);
                CREDENTIAL cred = (CREDENTIAL)Marshal.PtrToStructure(item, typeof(CREDENTIAL));
                string target = Marshal.PtrToStringUni(cred.TargetName);
                result[i] = target.StartsWith(prefix) ? target.Substring(prefix.Length) : target;
            }
            return result;
        } finally { CredFree(ptr); }
    }
}
'@

if (-not ('CredMan' -as [type])) { Add-Type -TypeDefinition $sig -Language CSharp }

# A modal dialog that returns the typed value, or $null if cancelled. The console prompt below is
# invisible when this script is started from a terminal the user cannot see - which happened, and
# read as "nothing is happening". A window cannot be missed.
function Read-SecretGui([string]$Label) {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'ARC-1 credential'
    $form.ClientSize = New-Object System.Drawing.Size(420, 130)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.TopMost = $true

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $Label
    $lbl.Location = New-Object System.Drawing.Point(12, 12)
    $lbl.Size = New-Object System.Drawing.Size(396, 36)
    $form.Controls.Add($lbl)

    $tb = New-Object System.Windows.Forms.TextBox
    $tb.UseSystemPasswordChar = $true
    $tb.Location = New-Object System.Drawing.Point(12, 52)
    $tb.Size = New-Object System.Drawing.Size(396, 23)
    $tb.TabIndex = 0
    $form.Controls.Add($tb)

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = 'Store'
    $ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $ok.Location = New-Object System.Drawing.Point(252, 88)
    $form.Controls.Add($ok)

    $no = New-Object System.Windows.Forms.Button
    $no.Text = 'Cancel'
    $no.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $no.Location = New-Object System.Drawing.Point(333, 88)
    $form.Controls.Add($no)

    $form.AcceptButton = $ok
    $form.CancelButton = $no
    $form.Add_Shown({ $tb.Focus() })
    $result = $form.ShowDialog()
    $value = $tb.Text
    $form.Dispose()
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) { return $null }
    return $value
}

if ($Set) {
    if ($Gui) {
        $plain = Read-SecretGui ("Value for " + $Key + " (stored as " + $Target + ")")
        if ($null -eq $plain) { Write-Error 'Cancelled - nothing stored.'; exit 1 }
    }
    else {
        $sec = Read-Host -AsSecureString "Value for $Key (stored as $Target)"
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
        try { $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
        finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
    }
    if ([string]::IsNullOrEmpty($plain)) { Write-Error 'Empty value - nothing stored.'; exit 1 }
    if ([CredMan]::Write($Target, $Key, $plain)) { Write-Output "stored: $Target" }
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
    if ($null -eq $v) { Write-Error "nothing stored for $Key - run: sap-secret.ps1 -Set -Key $Key"; exit 1 }
    Write-Output $v
    exit 0
}

if ($List) {
    $names = @([CredMan]::Enumerate($Prefix))
    if ($names.Count -eq 0) { Write-Output "no entries under $Prefix" ; exit 0 }
    foreach ($n in ($names | Sort-Object)) { Write-Output ("  " + $n) }
    Write-Output ("{0} entries under {1}" -f $names.Count, $Prefix)
    exit 0
}

Write-Output 'Usage: sap-secret.ps1 -Set|-Read|-Test|-Remove -Key NAME   |   -List'
