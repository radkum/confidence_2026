#Requires -RunAsAdministrator
# Raw read from \\.\SysMon to test IPC without sysmon-um.

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class _K32 {
    [DllImport("kernel32", SetLastError=true, CharSet=CharSet.Unicode)]
    public static extern IntPtr CreateFileW(string n, uint a, uint s, IntPtr sa, uint cd, uint fa, IntPtr t);
    [DllImport("kernel32", SetLastError=true)]
    public static extern bool ReadFile(IntPtr h, byte[] buf, uint sz, out uint read, IntPtr ovl);
    [DllImport("kernel32", SetLastError=true)]
    public static extern bool CloseHandle(IntPtr h);
}
"@

$INVALID = [IntPtr]::new(-1)
$ACCESS  = [uint32]'0xC0000000'   # GENERIC_READ|GENERIC_WRITE
$h = [_K32]::CreateFileW(
    "\\.\SysMon",
    $ACCESS,
    [uint32]0,             # share none
    [IntPtr]::Zero,
    [uint32]3,             # OPEN_EXISTING
    [uint32]0,
    [IntPtr]::Zero)

if ($h -eq $INVALID -or $h -eq [IntPtr]::Zero) {
    $err = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
    Write-Host "CreateFile failed: handle=$h err=$err" -ForegroundColor Red
    exit 1
}
Write-Host "Device opened OK. Polling for events..." -ForegroundColor Green
Write-Host "(In other window: run 'reg query HKLM\SOFTWARE\Microsoft\AMSI\Providers')"
Write-Host ""

$buf = New-Object byte[] 65536
$totalReads = 0
for ($i = 0; $i -lt 30; $i++) {
    $read = [uint32]0
    $ok = [_K32]::ReadFile($h, $buf, $buf.Length, [ref]$read, [IntPtr]::Zero)
    if ($ok -and $read -gt 0) {
        $totalReads++
        Write-Host "[$i] read $read bytes:" -ForegroundColor Cyan
        $hex = ($buf[0..([Math]::Min(63,[int]$read-1))] | ForEach-Object { '{0:X2}' -f $_ }) -join ' '
        Write-Host "    first 64: $hex"
        # Try to interpret first 4 bytes as discriminant
        $disc = [BitConverter]::ToUInt32($buf, 0)
        Write-Host "    discriminant: $disc  (0=ProcCreate, 1=ProcExit, 2=TidCreate, 3=TidExit, 4=ImgLoad, 5=RegSetValue, 6=RegEnumerate)"
    } elseif (-not $ok) {
        $err = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        if ($err -ne 0) { Write-Host "ReadFile err=$err" -ForegroundColor Yellow }
    }
    Start-Sleep -Milliseconds 200
}

Write-Host ""
Write-Host "Total reads with data: $totalReads"
[_K32]::CloseHandle($h) | Out-Null
