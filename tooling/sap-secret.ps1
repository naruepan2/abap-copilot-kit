# sap-secret.ps1 - keep ARC-1 secrets in Windows Credential Manager instead of in JSON or .env.
#
# Copilot CLI reads ~/.copilot/mcp-config.json and can only pass secrets as --env KEY=VALUE, so
# there is no ${input:...} there. ~/.copilot also grants CodexSandboxUsers ReadAndExecute, so a
# plaintext file in that folder is not private. This stores each secret as its own credential
# entry, addressed by the ARC-1 variable name.
#
#   -Set -Key NAME   prompt once and store (interactive; the value never enters a chat or a file)
#   -Set -Gui -Key   same, but in the Windows credential dialog instead of the console. Use this
#                    when the terminal that runs the script is not the one you can see.
#   -Read -Key NAME   print it to stdout (the launcher captures it)
#   -Test -Key NAME   report PRESENT/ABSENT and the length, without revealing the value
#   -Remove -Key NAME delete the entry
#   -List             list the ARC1 entries that exist
#
# To keep a console from sitting next to the dialog, start -Gui hidden. Use the full interpreter
# path, not the bare name: the bare name only resolves while its own folder is on PATH, and a
# sandboxed parent process does not have it.
#
#   Start-Process "$PSHOME\powershell.exe" -WindowStyle Hidden -ArgumentList '-NoProfile',
#     '-ExecutionPolicy','Bypass','-File',$script,'-Set','-Gui','-Key','NAME'
#
# -WindowStyle Hidden was measured: the process then owns no visible window at all, and the only
# thing on screen is the credential dialog itself (a CredentialUIBroker window, not ours).
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
    [Console]::Error.WriteLine('Specify -Key NAME (for example -Key SAP_PASSWORD, or gsd-120_SAP_PASSWORD).')
    exit 1
}
if ($Key -and $Key -notmatch '^[A-Za-z_][A-Za-z0-9_-]*$') {
    [Console]::Error.WriteLine("Invalid key name '$Key'. Letters, digits, underscore and dash only.")
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

    public static int LastReadError = 0;

    public static string Read(string target) {
        IntPtr ptr;
        // A failed CredRead is not the same fact as "nothing stored". The Win32 error was discarded,
        // so ERROR_NO_SUCH_LOGON_SESSION (1312), ERROR_ACCESS_DENIED (5) and a damaged store all read
        // as ABSENT, and the caller told the user to re-enter a password that was already there. Same
        // class as F-006/F-017, one layer below the fix they applied.
        LastReadError = 0;
        if (!CredRead(target, CRED_TYPE_GENERIC, 0, out ptr)) { LastReadError = Marshal.GetLastWin32Error(); return null; }
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

# Windows' own credential dialog, not a hand-built form. CredUIPromptForWindowsCredentialsW is the
# same dialog Windows shows for a network share or an RDP logon, so it looks like the operating
# system, scales with DPI, and works with a screen reader and the keyboard. A hand-built WinForms
# form was tried first and looked like an unfinished utility.
$credUiSig = @'
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class CredUi {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct CREDUI_INFO {
        public int cbSize;
        public IntPtr hwndParent;
        public string pszMessageText;
        public string pszCaptionText;
        public IntPtr hbmBanner;
    }

    [DllImport("credui.dll", EntryPoint = "CredUIPromptForWindowsCredentialsW", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern int Prompt(
        ref CREDUI_INFO pUiInfo,
        int dwAuthError,
        ref uint pulAuthPackage,
        IntPtr pvInAuthBuffer,
        uint ulInAuthBufferSize,
        out IntPtr ppvOutAuthBuffer,
        out uint pulOutAuthBufferSize,
        ref int pfSave,
        uint dwFlags);

    [DllImport("credui.dll", EntryPoint = "CredUnPackAuthenticationBufferW", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool Unpack(
        uint dwFlags,
        IntPtr pAuthBuffer,
        uint cbAuthBuffer,
        StringBuilder pszUserName,
        ref uint pcchMaxUserName,
        StringBuilder pszDomainName,
        ref uint pcchMaxDomainName,
        StringBuilder pszPassword,
        ref uint pcchMaxPassword);

    [DllImport("ole32.dll")]
    public static extern void CoTaskMemFree(IntPtr pv);

    const uint CREDUIWIN_GENERIC = 1;
    const int ERROR_CANCELLED = 1223;

    // Returns the password, or null when the user cancelled. The generic package shows a user name
    // and a password field; only the password is returned, because that is all we store.
    public static string AskPassword(string caption, string message) {
        CREDUI_INFO info = new CREDUI_INFO();
        info.cbSize = Marshal.SizeOf(typeof(CREDUI_INFO));
        info.pszCaptionText = caption;
        info.pszMessageText = message;

        uint authPackage = 0;
        int save = 0;
        IntPtr outBuffer;
        uint outSize;
        int rc = Prompt(ref info, 0, ref authPackage, IntPtr.Zero, 0, out outBuffer, out outSize, ref save, CREDUIWIN_GENERIC);
        if (rc == ERROR_CANCELLED) return null;
        if (rc != 0) throw new InvalidOperationException("CredUIPromptForWindowsCredentials returned " + rc);
        try {
            uint userLen = 514, domainLen = 514, passLen = 514;
            StringBuilder u = new StringBuilder((int)userLen);
            StringBuilder d = new StringBuilder((int)domainLen);
            StringBuilder p = new StringBuilder((int)passLen);
            if (!Unpack(0, outBuffer, outSize, u, ref userLen, d, ref domainLen, p, ref passLen)) {
                throw new InvalidOperationException("CredUnPackAuthenticationBuffer failed: " + Marshal.GetLastWin32Error());
            }
            return p.ToString();
        } finally {
            CoTaskMemFree(outBuffer);
        }
    }
}
'@

# Returns the typed secret, or $null if cancelled. The console prompt is invisible when this script
# is started from a terminal the user cannot see - which happened, and read as "nothing is
# happening". A native window cannot be missed.
function Read-SecretGui([string]$Label) {
    if (-not ('CredUi' -as [type])) { Add-Type -TypeDefinition $credUiSig -Language CSharp }
    return [CredUi]::AskPassword('ARC-1 credential store', $Label)
}

if ($Set) {
    if ($Gui) {
        $plain = Read-SecretGui ("Value for " + $Key + " (stored as " + $Target + ")")
        if ($null -eq $plain) { [Console]::Error.WriteLine('Cancelled - nothing stored.'); exit 1 }
    }
    else {
        $sec = Read-Host -AsSecureString "Value for $Key (stored as $Target)"
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
        try { $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
        finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
    }
    if ([string]::IsNullOrEmpty($plain)) { [Console]::Error.WriteLine('Empty value - nothing stored.'); exit 1 }
    if ([CredMan]::Write($Target, $Key, $plain)) { Write-Output "stored: $Target" }
    else { [Console]::Error.WriteLine("CredWrite failed: " + [Runtime.InteropServices.Marshal]::GetLastWin32Error()); exit 1 }
    exit 0
}

if ($Remove) {
    if ([CredMan]::Delete($Target)) { Write-Output "removed: $Target" } else { Write-Output "nothing to remove: $Target" }
    exit 0
}

if ($Test) {
    $v = [CredMan]::Read($Target)
    if ($null -ne $v) { Write-Output ("PRESENT " + $Target + "  (" + $v.Length + " chars)") }
    elseif ([CredMan]::LastReadError -eq 1168) { Write-Output "ABSENT  $Target" }
    else {
        # 1168 = ERROR_NOT_FOUND. Anything else means the read failed, and sap-connection.ps1 already
        # maps any line that is neither PRESENT nor ABSENT to 'ERROR' - so the caller gets UNKNOWN
        # instead of being told to re-enter a working password.
        [Console]::Error.WriteLine("UNKNOWN " + $Target + "  (CredRead failed, Win32 error " + [CredMan]::LastReadError + ")")
        exit 2
    }
    exit 0
}

if ($Read) {
    $v = [CredMan]::Read($Target)
    if ($null -eq $v) {
        if ([CredMan]::LastReadError -ne 1168) {
            [Console]::Error.WriteLine("could not read $Key - CredRead failed (Win32 error " + [CredMan]::LastReadError + "), so this is not a statement that nothing is stored")
            exit 2
        }
        [Console]::Error.WriteLine("nothing stored for $Key - run: sap-secret.ps1 -Set -Key $Key"); exit 1
    }
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
