#Requires -RunAsAdministrator
param([switch]$NoPause)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "========================================"
Write-Host "  Confidence REINSTALL  $(Get-Date)"
Write-Host "========================================"
Write-Host ""

# IMPORTANT: uninstall.ps1 force-unloads ramsi_com.dll from ALL processes -- including the
# current PowerShell host! Continuing with install.ps1 in the same shell triggers an
# Access Violation in AmsiScanBuffer when PowerShell tries to scan install.ps1 content
# (stale function pointer to unloaded DLL).
#
# Workaround: run BOTH child scripts in FRESH PowerShell processes. Each fresh PS process
# loads AMSI providers from the (current) registry at startup -- when ramsi-com is
# unregistered, no provider is loaded for that process.

Write-Host "[Step 1/2] Running uninstall (in fresh PS process)..."
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$ScriptDir\uninstall.ps1" -Force
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Uninstall failed (exit $LASTEXITCODE)"
    exit 1
}

Write-Host ""
Write-Host "Waiting 3 seconds for SCM to settle..."
Start-Sleep -Seconds 3

Write-Host ""
Write-Host "[Step 2/2] Running install (in fresh PS process)..."
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$ScriptDir\install.ps1" -NoPause
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Install failed (exit $LASTEXITCODE)"
    exit 1
}

Write-Host ""
Write-Host "========================================"
Write-Host "  REINSTALL COMPLETE  $(Get-Date)"
Write-Host "========================================"
Write-Host ""
