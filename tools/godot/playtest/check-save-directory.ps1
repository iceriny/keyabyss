[CmdletBinding()]
param(
    [string]$UserDataDirectory,
    [string]$LogDirectory,
    [string]$GameDirectory
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
# Use Windows PowerShell's bundled security module even when launched from pwsh.
Import-Module (Join-Path $PSHOME 'Modules/Microsoft.PowerShell.Security/Microsoft.PowerShell.Security.psd1')
if (-not $UserDataDirectory) { $UserDataDirectory = Join-Path $env:APPDATA 'Keyabyss' }
if (-not $LogDirectory) { $LogDirectory = Join-Path $PSScriptRoot 'logs' }
if (-not $GameDirectory) { $GameDirectory = $PSScriptRoot }
New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
$reportPath = Join-Path $LogDirectory ('save-directory-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + $PID + '.log')

function Get-FailureDescription([Exception]$Failure) {
    $cause = $Failure.GetBaseException()
    return '{0}: {1} (HRESULT 0x{2:X8})' -f $cause.GetType().FullName, $cause.Message, $cause.HResult
}

function Show-PathAccess([string]$Location) {
    'Inspect: ' + $Location
    try {
        $item = Get-Item -LiteralPath $Location -Force
        'Directory: {0}; attributes: {1}; link target: {2}' -f $item.PSIsContainer, $item.Attributes, ($item.Target -join ', ')
        $acl = Get-Acl -LiteralPath $Location
        'Owner: {0}; inheritance disabled: {1}' -f $acl.Owner, $acl.AreAccessRulesProtected
        'SDDL: ' + $acl.Sddl
        $acl.AccessToString
    } catch { Get-FailureDescription $_.Exception }
}

function Test-SaveDirectory([string]$Location) {
    'Probe: ' + $Location
    $source = Join-Path $Location ('.keyabyss-write-probe-' + [Guid]::NewGuid().ToString('N') + '.tmp')
    $target = $source + '.renamed'
    $probe = $null
    $created = $false
    try {
        [IO.Directory]::CreateDirectory($Location) | Out-Null
        'Directory creation: OK'
        $probe = [IO.FileStream]::new($source, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        $created = $true
        $probe.WriteByte(75)
        $probe.Flush()
        $probe.Dispose()
        $probe = $null
        'File write: OK'
        [IO.File]::Move($source, $target)
        'File rename: OK'
        if ([IO.File]::ReadAllBytes($target)[0] -ne 75) { throw 'Probe readback did not match.' }
        'File readback: OK'
    } catch { Get-FailureDescription $_.Exception }
    finally {
        if ($null -ne $probe) { $probe.Dispose() }
        # Only the two unique files created by this probe are removed.
        if ($created) {
            foreach ($temporary in @($source, $target)) {
                try { [IO.File]::Delete($temporary) }
                catch { 'Probe cleanup: ' + (Get-FailureDescription $_.Exception) }
            }
        }
    }
}

function Show-RelevantEvents([string]$Channel, [int[]]$EventIds) {
    'Event log: ' + $Channel
    $eventErrors = @()
    $events = @(Get-WinEvent -FilterHashtable @{ LogName = $Channel; Id = $EventIds; StartTime = (Get-Date).AddDays(-2) } -MaxEvents 200 -ErrorAction SilentlyContinue -ErrorVariable eventErrors)
    foreach ($failure in $eventErrors) {
        if ($failure.FullyQualifiedErrorId -notlike 'NoMatchingEventsFound*') { Get-FailureDescription $failure.Exception }
    }
    $matches = @($events | Where-Object { $_.Message -match ('(?i)keyabyss|' + [regex]::Escape($UserDataDirectory)) } | Select-Object -First 10)
    if ($matches.Count -eq 0) { 'No matching game events found; this does not rule out blocking.' }
    foreach ($entry in $matches) {
        'Time: {0}; event: {1}' -f $entry.TimeCreated.ToString('o'), $entry.Id
        $entry.Message
    }
}

& {
    'Time: ' + (Get-Date -Format o)
    'Identity: ' + [Security.Principal.WindowsIdentity]::GetCurrent().Name
    'APPDATA: ' + $env:APPDATA
    'Known folder: ' + [Environment]::GetFolderPath([Environment+SpecialFolder]::ApplicationData)
    'User data: ' + $UserDataDirectory
    'Game directory: ' + $GameDirectory
    'PowerShell: ' + $PSVersionTable.PSVersion
    $tokenReaderReady = $false
    try {
        Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
public static class KeyabyssTokenReader {
    [DllImport("kernel32.dll", SetLastError=true)] static extern IntPtr OpenProcess(uint access, bool inherit, int pid);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
    [DllImport("advapi32.dll", SetLastError=true)] static extern bool OpenProcessToken(IntPtr process, uint access, out IntPtr token);
    [DllImport("advapi32.dll", EntryPoint="GetTokenInformation", SetLastError=true)] static extern bool TokenInt(IntPtr token, int kind, out int value, int length, out int needed);
    [DllImport("advapi32.dll", EntryPoint="GetTokenInformation", SetLastError=true)] static extern bool TokenBuffer(IntPtr token, int kind, IntPtr value, int length, out int needed);
    [DllImport("advapi32.dll")] static extern IntPtr GetSidSubAuthorityCount(IntPtr sid);
    [DllImport("advapi32.dll")] static extern IntPtr GetSidSubAuthority(IntPtr sid, uint index);
    [DllImport("advapi32.dll")] static extern bool IsTokenRestricted(IntPtr token);
    public static string Read(int pid) {
        IntPtr process = OpenProcess(0x1000, false, pid);
        if (process == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
        IntPtr token = IntPtr.Zero, buffer = IntPtr.Zero;
        try {
            if (!OpenProcessToken(process, 8, out token)) throw new Win32Exception(Marshal.GetLastWin32Error());
            int elevated, container, needed;
            if (!TokenInt(token, 20, out elevated, 4, out needed)) throw new Win32Exception(Marshal.GetLastWin32Error());
            if (!TokenInt(token, 29, out container, 4, out needed)) throw new Win32Exception(Marshal.GetLastWin32Error());
            TokenBuffer(token, 25, IntPtr.Zero, 0, out needed);
            buffer = Marshal.AllocHGlobal(needed);
            if (!TokenBuffer(token, 25, buffer, needed, out needed)) throw new Win32Exception(Marshal.GetLastWin32Error());
            IntPtr sid = Marshal.ReadIntPtr(buffer);
            uint index = (uint)(Marshal.ReadByte(GetSidSubAuthorityCount(sid)) - 1);
            int level = Marshal.ReadInt32(GetSidSubAuthority(sid, index));
            string label = level < 0x1000 ? "Untrusted" : level < 0x2000 ? "Low" : level < 0x3000 ? "Medium" : level < 0x4000 ? "High" : "System";
            return "Integrity=" + label + " (0x" + level.ToString("X") + "); elevated=" + (elevated != 0) + "; AppContainer=" + (container != 0) + "; restricted=" + IsTokenRestricted(token);
        } finally {
            if (buffer != IntPtr.Zero) Marshal.FreeHGlobal(buffer);
            if (token != IntPtr.Zero) CloseHandle(token);
            CloseHandle(process);
        }
    }
}
'@
        $tokenReaderReady = $true
        'Diagnostic process token: ' + [KeyabyssTokenReader]::Read($PID)
    } catch { 'Token inspection unavailable: ' + (Get-FailureDescription $_.Exception) }
    'Current token groups and integrity level:'
    & "$env:SystemRoot\System32\whoami.exe" /groups
    foreach ($location in @((Split-Path -Parent $UserDataDirectory), $UserDataDirectory, $GameDirectory)) { Show-PathAccess $location }
    foreach ($relative in @('', 'vocabulary/indices', 'profiles/normal', 'profiles/god', 'shader_cache')) {
        $location = if ($relative) { Join-Path $UserDataDirectory $relative } else { $UserDataDirectory }
        if ($relative) { Show-PathAccess $location }
        Test-SaveDirectory $location
    }
    'Existing settings files:'
    foreach ($name in @('settings.cfg', 'settings.cfg.tmp', 'settings.cfg.bak')) {
        $location = Join-Path $UserDataDirectory $name
        try {
            if (Test-Path -LiteralPath $location) {
                $item = Get-Item -LiteralPath $location -Force
                '{0}: directory={1}; attributes={2}' -f $name, $item.PSIsContainer, $item.Attributes
                Show-PathAccess $location
                if (-not $item.PSIsContainer) {
                    $file = [IO.File]::Open($location, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::ReadWrite)
                    $file.Dispose()
                    'Existing file can be opened for read/write; contents were not changed.'
                }
            } else { $name + ': absent' }
        } catch { Get-FailureDescription $_.Exception }
    }
    'Game executables:'
    foreach ($name in @('keyabyss.exe', 'keyabyss.console.exe')) {
        $location = Join-Path $GameDirectory $name
        if (-not (Test-Path -LiteralPath $location -PathType Leaf)) {
            $name + ': NOT FOUND. Put the check files beside the game EXE.'
            continue
        }
        Show-PathAccess $location
        try {
            $signature = Get-AuthenticodeSignature -LiteralPath $location
            'Signature status: ' + $signature.Status
            $zones = @(Get-Item -LiteralPath $location -Stream '*' | Where-Object { $_.Stream -eq 'Zone.Identifier' })
            if ($zones.Count -gt 0) {
                'Download marker:'
                Get-Content -LiteralPath $location -Stream Zone.Identifier | Where-Object { $_ -match '^\[|^ZoneId=' }
            } else { 'Download marker: absent' }
            foreach ($hive in @([Microsoft.Win32.Registry]::CurrentUser, [Microsoft.Win32.Registry]::LocalMachine)) {
                $key = $hive.OpenSubKey('Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers')
                try {
                    $flags = if ($null -ne $key) { $key.GetValue($location, '(none)') } else { '(none)' }
                    $hive.Name + ' compatibility flags: ' + $flags
                } finally { if ($null -ne $key) { $key.Dispose() } }
            }
        } catch { Get-FailureDescription $_.Exception }
    }
    'Running game processes:'
    try {
        $processes = @(Get-CimInstance Win32_Process -Filter "Name='keyabyss.exe' OR Name='keyabyss.console.exe'")
        if ($processes.Count -eq 0) { 'Game is not running.' }
        foreach ($process in $processes) {
            $owner = Invoke-CimMethod -InputObject $process -MethodName GetOwner
            'PID={0}; path={1}; owner={2}\{3}; owner query result={4}' -f $process.ProcessId, $process.ExecutablePath, $owner.Domain, $owner.User, $owner.ReturnValue
            if ($tokenReaderReady) {
                try { 'Game process token: ' + [KeyabyssTokenReader]::Read([int]$process.ProcessId) }
                catch { Get-FailureDescription $_.Exception }
            }
        }
    } catch { Get-FailureDescription $_.Exception }
    'Installed antivirus:'
    try {
        Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct | ForEach-Object { '{0}; product state={1}' -f $_.displayName, $_.productState }
    } catch { Get-FailureDescription $_.Exception }
    'Defender controlled folder access:'
    try {
        $preferences = Get-MpPreference
        'Mode: ' + $preferences.EnableControlledFolderAccess
        'Additional protected folders: ' + ($preferences.ControlledFolderAccessProtectedFolders -join ', ')
        'Allowed game applications: ' + (($preferences.ControlledFolderAccessAllowedApplications | Where-Object { $_ -match '(?i)keyabyss' }) -join ', ')
    } catch { Get-FailureDescription $_.Exception }
    Show-RelevantEvents 'Microsoft-Windows-Windows Defender/Operational' @(1123, 1124, 1116, 1117)
    Show-RelevantEvents 'Microsoft-Windows-AppLocker/EXE and DLL' @(8003, 8004)
    Show-RelevantEvents 'Microsoft-Windows-CodeIntegrity/Operational' @(3076, 3077)
    'The PowerShell probe uses its own process token; success does not prove that the game EXE is allowed to write.'
} | Tee-Object -FilePath $reportPath
Write-Output ('Report: ' + $reportPath)
