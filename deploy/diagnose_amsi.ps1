#Requires -RunAsAdministrator
# diagnose_amsi.ps1 -- collects everything needed to debug "DLL not logging" on a VM
Set-StrictMode -Version Latest

if (-not [Environment]::Is64BitProcess) {
    Write-Host "[ABORT] Relaunch in 64-bit PowerShell -- our DLL is x64-only" -ForegroundColor Red
    Write-Host "  C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
    exit 1
}

$AmsiClsid  = '{b8614e83-84ac-45fb-82a8-21711aaf07f2}'
$InstallDir = 'C:\Program Files\Confidence'
$LogPath    = 'C:\ProgramData\Confidence\logs\ramsi-com.log'

function H1([string]$t) { Write-Host ""; Write-Host "=== $t ===" -ForegroundColor Yellow }

H1 "Installed DLL"
if (Test-Path "$InstallDir\ramsi_com.dll") {
    $f = Get-Item "$InstallDir\ramsi_com.dll"
    Write-Host "  Size : $($f.Length)"
    Write-Host "  Modif: $($f.LastWriteTime)"
    Write-Host "  SHA  : $((Get-FileHash $f -Algorithm SHA256).Hash)"
    $bytes = [IO.File]::ReadAllBytes($f.FullName)
    $ascii = [Text.Encoding]::ASCII.GetString($bytes)
    foreach ($mark in @('DLL_PROCESS_ATTACH in process', 'DllGetClassObject called', 'AMSI Scan() called', 'scan_script ENTRY')) {
        if ($ascii -match [Regex]::Escape($mark)) { Write-Host "  [OK]   '$mark'" -ForegroundColor Green }
        else { Write-Host "  [MISS] '$mark' -- OLD DLL!" -ForegroundColor Red }
    }
} else {
    Write-Host "  MISSING -- run install.ps1" -ForegroundColor Red
}

H1 "AMSI registry (reg.exe)"
& reg query "HKLM\SOFTWARE\Microsoft\AMSI\Providers" /s 2>&1 | ForEach-Object { Write-Host "  $_" }
Write-Host ""
& reg query "HKLM\SOFTWARE\Classes\CLSID\$AmsiClsid" /s 2>&1 | ForEach-Object { Write-Host "  $_" }

H1 "LoadLibrary test"
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class K {
    [DllImport("kernel32", SetLastError=true)] public static extern IntPtr LoadLibrary(string n);
    [DllImport("kernel32", SetLastError=true)] public static extern int FreeLibrary(IntPtr h);
}
"@
$h = [K]::LoadLibrary("$InstallDir\ramsi_com.dll")
if ($h -ne [IntPtr]::Zero) {
    Write-Host "  LoadLibrary OK -- handle $h" -ForegroundColor Green
    [K]::FreeLibrary($h) | Out-Null
} else {
    $err = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
    Write-Host "  LoadLibrary FAILED -- err $err ($([ComponentModel.Win32Exception]::new($err).Message))" -ForegroundColor Red
}

H1 "Log dir state"
$logDir = Split-Path $LogPath -Parent
if (Test-Path $logDir) {
    $acl = (Get-Acl $logDir).Access | ForEach-Object { "    $($_.IdentityReference) -> $($_.FileSystemRights) ($($_.AccessControlType))" }
    Write-Host "  $logDir exists, ACLs:"
    $acl | ForEach-Object { Write-Host $_ }
} else {
    Write-Host "  $logDir DOES NOT EXIST" -ForegroundColor Red
}

H1 "Delete log + spawn fresh PS + check"
if (Test-Path $LogPath) { Remove-Item $LogPath -Force }
Write-Host "  Log deleted. Spawning fresh powershell.exe..."

$ps = Start-Process powershell.exe -ArgumentList "-NoProfile","-Command","Write-Host hello; Start-Sleep -Seconds 3" -PassThru -WindowStyle Hidden
Start-Sleep -Milliseconds 1500

$proc = Get-Process -Id $ps.Id -ErrorAction SilentlyContinue
if ($proc) {
    $allMods = $proc.Modules
    Write-Host "  PID $($ps.Id) has $($allMods.Count) modules loaded"
    $ramsi = $allMods | Where-Object { $_.ModuleName -like "*ramsi*" }
    $amsi  = $allMods | Where-Object { $_.ModuleName -eq "amsi.dll" }
    if ($amsi)  { Write-Host "    amsi.dll      : $($amsi.FileName)" -ForegroundColor Cyan }
    else        { Write-Host "    amsi.dll      : NOT LOADED" -ForegroundColor Red }
    if ($ramsi) { Write-Host "    ramsi_com.dll : LOADED at $($ramsi.FileName)" -ForegroundColor Green }
    else        { Write-Host "    ramsi_com.dll : NOT loaded" -ForegroundColor Red }
}
$ps.WaitForExit()
Start-Sleep -Milliseconds 500

H1 "Log after fresh PS run"
if (Test-Path $LogPath) {
    $sz = (Get-Item $LogPath).Length
    Write-Host "  File exists, size: $sz bytes"
    if ($sz -gt 0) {
        Get-Content $LogPath | ForEach-Object { Write-Host "  $_" }
    } else {
        Write-Host "  (file empty -- DLL didn't write)" -ForegroundColor Red
    }
} else {
    Write-Host "  Log file NOT created -- ramsi_com.dll never executed file_log!()" -ForegroundColor Red
}

H1 "Done"
