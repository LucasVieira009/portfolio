#Requires -RunAsAdministrator
# Corrige a ACL travada da chave do servico Windows Update (wuauserv)
# e religa o servico para permitir a instalacao do WSL 2.

$ErrorActionPreference = 'Stop'

Write-Host "== Corrigindo permissoes do servico Windows Update ==" -ForegroundColor Cyan

function Enable-Privilege([string]$name) {
    if (-not ('PrivilegeHelper' -as [type])) {
        Add-Type -Language CSharp -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class PrivilegeHelper {
    [StructLayout(LayoutKind.Sequential, Pack = 4)]
    private struct TOKEN_PRIVILEGES { public int Count; public long Luid; public int Attributes; }

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool OpenProcessToken(IntPtr process, uint access, out IntPtr token);

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool LookupPrivilegeValue(string system, string name, ref long luid);

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool AdjustTokenPrivileges(IntPtr token, bool disableAll, ref TOKEN_PRIVILEGES newState, int bufferLength, IntPtr previousState, IntPtr returnLength);

    [DllImport("kernel32.dll")]
    private static extern IntPtr GetCurrentProcess();

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool CloseHandle(IntPtr handle);

    public static string Enable(string name) {
        IntPtr token;
        if (!OpenProcessToken(GetCurrentProcess(), 0x28, out token))
            return "OpenProcessToken: " + Marshal.GetLastWin32Error();
        try {
            long luid = 0;
            if (!LookupPrivilegeValue(null, name, ref luid))
                return "LookupPrivilegeValue: " + Marshal.GetLastWin32Error();
            TOKEN_PRIVILEGES tp = new TOKEN_PRIVILEGES();
            tp.Count = 1;
            tp.Luid = luid;
            tp.Attributes = 2;
            bool ok = AdjustTokenPrivileges(token, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
            int err = Marshal.GetLastWin32Error();
            if (!ok) return "AdjustTokenPrivileges: " + err;
            if (err == 1300) return "ERROR_NOT_ALL_ASSIGNED (1300): o processo nao tem o privilegio";
            return null;
        } finally {
            CloseHandle(token);
        }
    }
}
"@
    }
    return [PrivilegeHelper]::Enable($name)
}

$err = Enable-Privilege 'SeTakeOwnershipPrivilege'
if ($null -ne $err) { throw "Falha ao habilitar SeTakeOwnershipPrivilege: $err" }

$path   = 'SYSTEM\CurrentControlSet\Services\wuauserv'
$admins = New-Object System.Security.Principal.SecurityIdentifier 'S-1-5-32-544'
$system = New-Object System.Security.Principal.SecurityIdentifier 'S-1-5-18'

# 1) assume a posse da chave
$key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(
    $path,
    [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,
    [System.Security.AccessControl.RegistryRights]::TakeOwnership)
$acl = $key.GetAccessControl()
$acl.SetOwner($admins)
$key.SetAccessControl($acl)
$key.Close()
Write-Host "  posse da chave ......... OK" -ForegroundColor Green

# 2) devolve FullControl para SYSTEM e Administradores
$key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(
    $path,
    [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,
    [System.Security.AccessControl.RegistryRights]::ChangePermissions)
$acl = $key.GetAccessControl()
$acl.SetAccessRuleProtection($false, $true)
$acl.AddAccessRule((New-Object System.Security.AccessControl.RegistryAccessRule($system, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')))
$acl.AddAccessRule((New-Object System.Security.AccessControl.RegistryAccessRule($admins, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')))
$key.SetAccessControl($acl)
$key.Close()
Write-Host "  permissoes restauradas .. OK" -ForegroundColor Green

# 3) religa o servico
Set-Service -Name wuauserv -StartupType Manual
Start-Service -Name wuauserv
Write-Host "  Windows Update .......... $((Get-Service wuauserv).Status)" -ForegroundColor Green

# 4) remove a politica que mantinha as atualizacoes desligadas
if (Test-Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU') {
    Remove-Item 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -Recurse -Force
    Write-Host "  politica NoAutoUpdate ... removida" -ForegroundColor Green
}

Write-Host ""
Write-Host "Pronto. Agora rode na mesma janela:" -ForegroundColor Cyan
Write-Host "   wsl --install --no-distribution" -ForegroundColor Yellow
