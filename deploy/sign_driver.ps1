#Requires -RunAsAdministrator
# sign_driver.ps1 -- self-sign sysmon.sys for test signing mode use

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$DriverPath = 'C:\Windows\System32\drivers\sysmon.sys'
$CertName   = 'ConfidenceTestCert'
$CertSubj   = "CN=$CertName"

if (-not (Test-Path $DriverPath)) {
    Write-Host "[ERROR] $DriverPath not found -- run install.bat first" -ForegroundColor Red
    exit 1
}

# 1. Find signtool.exe (Windows SDK)
Write-Host "[1/5] Locating signtool.exe..."
$signtool = Get-ChildItem -Path 'C:\Program Files (x86)\Windows Kits\10\bin' `
    -Recurse -Filter 'signtool.exe' -ErrorAction SilentlyContinue |
    Where-Object { $_.DirectoryName -match 'x64' } |
    Sort-Object FullName -Descending |
    Select-Object -First 1
if (-not $signtool) {
    Write-Host "[ERROR] signtool.exe not found. Install Windows 10 SDK." -ForegroundColor Red
    Write-Host "  https://developer.microsoft.com/windows/downloads/windows-sdk/"
    exit 1
}
Write-Host "  found: $($signtool.FullName)"

# 2. Generate self-signed cert (if not already present)
Write-Host ""
Write-Host "[2/5] Generating self-signed code-signing certificate..."
$existing = Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Subject -eq $CertSubj }
if ($existing) {
    Write-Host "  Cert already exists: $($existing.Thumbprint)"
    $cert = $existing
} else {
    $cert = New-SelfSignedCertificate `
        -Type CodeSigningCert `
        -Subject $CertSubj `
        -KeyUsage DigitalSignature `
        -CertStoreLocation Cert:\LocalMachine\My `
        -KeyExportPolicy Exportable `
        -NotAfter (Get-Date).AddYears(2)
    Write-Host "  Created: $($cert.Thumbprint)"
}

# 3. Add cert to Trusted Root + Trusted Publisher
Write-Host ""
Write-Host "[3/5] Adding cert to Trusted Root and Trusted Publisher stores..."
foreach ($storeName in @('Root', 'TrustedPublisher')) {
    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store($storeName, 'LocalMachine')
    $store.Open('ReadWrite')
    $alreadyThere = $store.Certificates | Where-Object { $_.Thumbprint -eq $cert.Thumbprint }
    if (-not $alreadyThere) {
        $store.Add($cert)
        Write-Host "  Added to $storeName"
    } else {
        Write-Host "  Already in $storeName"
    }
    $store.Close()
}

# 4. Stop service if running (sign requires no handles open)
Write-Host ""
Write-Host "[4/5] Stopping ConfidenceKm if running..."
$svc = Get-Service ConfidenceKm -ErrorAction SilentlyContinue
if ($svc -and $svc.Status -eq 'Running') {
    Stop-Service ConfidenceKm -Force
    Start-Sleep -Seconds 1
    Write-Host "  Stopped"
} else {
    Write-Host "  Service not running or not present"
}

# 5. Sign sysmon.sys
Write-Host ""
Write-Host "[5/5] Signing $DriverPath..."
& $signtool.FullName sign /v `
    /s My /n $CertName /fd SHA256 `
    $DriverPath
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] signtool exited with code $LASTEXITCODE" -ForegroundColor Red
    exit 1
}

# Verify
Write-Host ""
Write-Host "=== Verification ==="
$sig = Get-AuthenticodeSignature $DriverPath
Write-Host "  Status : $($sig.Status)"
Write-Host "  Signer : $($sig.SignerCertificate.Subject)"

Write-Host ""
Write-Host "=== Done. Next steps: ==="
Write-Host "  sc.exe start ConfidenceKm"
Write-Host "  & 'C:\Program Files\Confidence\sysmon-um.exe'"
