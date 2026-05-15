param(
    [Parameter(Mandatory=$true)] [string]$DriverPath,
    [Parameter(Mandatory=$true)] [string]$CertOutPath
)

# sign_build.ps1 -- signs sysmon.sys at build time and exports cert for distribution
# Uses pure .NET API (no PKI module dependency). Requires signtool.exe (Windows SDK).

$ErrorActionPreference = 'Stop'

$CertName = 'ConfidenceTestCert'
$CertSubj = "CN=$CertName"

if (-not (Test-Path $DriverPath)) {
    Write-Host "[sign_build] ERROR: $DriverPath not found"; exit 1
}

# Locate signtool.exe
$signtool = Get-ChildItem 'C:\Program Files (x86)\Windows Kits\10\bin' `
    -Recurse -Filter 'signtool.exe' -ErrorAction SilentlyContinue |
    Where-Object { $_.DirectoryName -match '\\x64\\?$' } |
    Sort-Object FullName -Descending |
    Select-Object -First 1
if (-not $signtool) {
    Write-Host "[sign_build] ERROR: signtool.exe not found in Windows 10 SDK"
    Write-Host "[sign_build]        install: https://developer.microsoft.com/windows/downloads/windows-sdk/"
    exit 1
}

# Find existing cert in CurrentUser\My
$store = New-Object System.Security.Cryptography.X509Certificates.X509Store('My', 'CurrentUser')
$store.Open('ReadWrite')
$cert = $store.Certificates | Where-Object { $_.Subject -eq $CertSubj } | Select-Object -First 1

if (-not $cert) {
    Write-Host "[sign_build] Creating self-signed cert $CertSubj (pure .NET API)..."

    # Create RSA key
    $rsa = [System.Security.Cryptography.RSA]::Create(2048)

    # Build CertificateRequest with code-signing EKU
    $req = New-Object System.Security.Cryptography.X509Certificates.CertificateRequest(
        $CertSubj,
        $rsa,
        [System.Security.Cryptography.HashAlgorithmName]::SHA256,
        [System.Security.Cryptography.RSASignaturePadding]::Pkcs1
    )

    # Basic constraints: not CA
    $req.CertificateExtensions.Add(
        (New-Object System.Security.Cryptography.X509Certificates.X509BasicConstraintsExtension(
            $false, $false, 0, $true
        ))
    )
    # Key usage: digital signature
    $req.CertificateExtensions.Add(
        (New-Object System.Security.Cryptography.X509Certificates.X509KeyUsageExtension(
            [System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]::DigitalSignature,
            $true
        ))
    )
    # EKU: code signing (1.3.6.1.5.5.7.3.3)
    $eku = New-Object System.Security.Cryptography.OidCollection
    $null = $eku.Add((New-Object System.Security.Cryptography.Oid('1.3.6.1.5.5.7.3.3', 'Code Signing')))
    $req.CertificateExtensions.Add(
        (New-Object System.Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension($eku, $true))
    )

    $notBefore = [DateTimeOffset]::Now.AddDays(-1)
    $notAfter  = [DateTimeOffset]::Now.AddYears(5)
    $tempCert = $req.CreateSelfSigned($notBefore, $notAfter)

    # Re-import with PersistKeySet to make it usable for signing via signtool
    $pfxBytes = $tempCert.Export(
        [System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx,
        '')
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(
        $pfxBytes,
        '',
        ([System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::PersistKeySet -bor
         [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable))
    $store.Add($cert)
    Write-Host "[sign_build] Cert created and stored: $($cert.Thumbprint)"
} else {
    Write-Host "[sign_build] Reusing cert: $($cert.Thumbprint)"
}
$store.Close()

# Sign driver
Write-Host "[sign_build] Signing $DriverPath..."
& $signtool.FullName sign /v `
    /s My /sha1 $cert.Thumbprint /fd SHA256 `
    $DriverPath
if ($LASTEXITCODE -ne 0) {
    Write-Host "[sign_build] ERROR: signtool failed ($LASTEXITCODE)"
    exit 1
}

# Export public cert (.cer) for install.ps1 to import on target machines
$cerBytes = $cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
[System.IO.File]::WriteAllBytes($CertOutPath, $cerBytes)
Write-Host "[sign_build] Cert exported: $CertOutPath"

# Verify signature -- best effort (PSCore needs explicit module import)
try {
    Import-Module Microsoft.PowerShell.Security -ErrorAction SilentlyContinue
    $sig = Get-AuthenticodeSignature $DriverPath -ErrorAction SilentlyContinue
    if ($sig) { Write-Host "[sign_build] Signature status: $($sig.Status)" }
} catch { Write-Host "[sign_build] Sig check skipped: $_" }
exit 0
