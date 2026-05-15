#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
if (-not [Environment]::Is64BitProcess) { Write-Host "[ABORT] use 64-bit PS"; exit 1 }

function H1([string]$t) { Write-Host ""; Write-Host "=== $t ===" -ForegroundColor Yellow }

H1 "1. Driver -- czy zainstalowany sysmon.sys ma nowy kod"
$inst = 'C:\Windows\System32\drivers\sysmon.sys'
$built = 'C:\VSExclude\confidence_2026\sysmon-rs\target\release\sysmon.sys'
$h1 = if (Test-Path $inst) { (Get-FileHash $inst).Hash } else { 'MISSING' }
$h2 = if (Test-Path $built) { (Get-FileHash $built).Hash } else { 'MISSING' }
Write-Host "  Installed: $($h1.Substring(0,32))..."
Write-Host "  Built    : $($h2.Substring(0,32))..."
if ($h1 -eq $h2) { Write-Host "  MATCH -- driver is current build" -ForegroundColor Green }
else { Write-Host "  MISMATCH -- reinstall didn't replace driver" -ForegroundColor Red }

# Sprawdź czy installed driver ma string "AMSI-RECON" / kod nowego eventu
$bytes = [IO.File]::ReadAllBytes($inst)
$ascii = [Text.Encoding]::ASCII.GetString($bytes)
foreach ($s in @('\REGISTRY\MACHINE', 'amsi', 'AMSI')) {
    $has = $ascii.Contains($s)
    Write-Host "  Driver contains '$s' string: $has"
}

H1 "2. sysmon-um.exe -- czy ma obsługę RegistryEnumerate"
$um = 'C:\Program Files\Confidence\sysmon-um.exe'
$umBytes = [IO.File]::ReadAllBytes($um)
$umAscii = [Text.Encoding]::ASCII.GetString($umBytes)
foreach ($s in @('AMSI-RECON', 'RegistryEnumerate', 'reading AMSI provider')) {
    Write-Host "  sysmon-um contains '$s': $($umAscii.Contains($s))"
}

H1 "3. Driver service status"
sc.exe query ConfidenceKm 2>&1 | ForEach-Object { Write-Host "  $_" }

H1 "4. Provoke event manually via reg.exe"
Write-Host "  Running: reg query HKLM\SOFTWARE\Microsoft\AMSI\Providers"
Write-Host "  (Patrz na okno sysmon-um.exe -- powinno wypisać [!] AMSI-RECON)"
Start-Sleep -Seconds 1
& reg query "HKLM\SOFTWARE\Microsoft\AMSI\Providers" 2>&1 | Out-Null
Write-Host "  Done. Sprawdź sysmon-um."
Start-Sleep -Seconds 1
Write-Host ""
Write-Host "  Try again with -s (subkeys):"
& reg query "HKLM\SOFTWARE\Microsoft\AMSI" /s 2>&1 | Out-Null
Write-Host "  Done."

H1 "5. Spawn fresh PS + open subkey via Get-Item (jak sample 27)"
$ps = Start-Process powershell.exe -ArgumentList "-NoProfile","-Command","`$r = Get-Item 'HKLM:\SOFTWARE\Microsoft\'; `$r.opensubkey('AMSI').opensubkey('Providers').getsubkeynames(); Start-Sleep -Seconds 2" -PassThru -WindowStyle Hidden
$ps.WaitForExit()
Write-Host "  Done. PID was: $($ps.Id)"
Write-Host "  Sprawdź czy sysmon-um pokazał AMSI-RECON dla tego PID-u."

Write-Host ""
Write-Host "If sysmon-um shows nothing after steps 4 and 5 -> kernel callback not firing." -ForegroundColor Yellow
