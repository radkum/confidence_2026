#Requires -RunAsAdministrator
param([switch]$NoPause)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ============================================================
#  install.ps1  -- installs Confidence components
#  Actions:
#    - copies PSParser.dll, ramsi_com.dll -> $InstallDir
#    - copies sysmon.sys -> $DriversDir
#    - copies sysmon-client.exe -> $InstallDir\sysmon-um.exe
#    - sets PSPARSER_DLL_PATH env var (system-wide)
#    - registers ramsi_com.dll as AMSI provider (regsvr32)
#    - creates and starts ConfidenceKm kernel service (sc)
# ============================================================

$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$InstallDir  = 'C:\Program Files\Confidence'
$DriversDir  = "$env:SystemRoot\System32\drivers"
$LogDir      = 'C:\ProgramData\Confidence\logs'
$Timestamp   = Get-Date -Format 'yyyyMMdd_HHmmss'
$LogFile     = "$LogDir\install_$Timestamp.log"
$SvcName     = 'ConfidenceKm'
$SvcDisplay  = 'Confidence Kernel Monitor'
$AmsiClsid   = '{b8614e83-84ac-45fb-82a8-21711aaf07f2}'

# Package layout (bin\ next to scripts) takes priority; fall back to source-tree layout
if (Test-Path "$ScriptDir\bin\PSParser.dll") {
    $BinDir          = "$ScriptDir\bin"
    $SrcPsParser     = "$BinDir\PSParser.dll"
    $SrcPsParserExe  = "$BinDir\PSParser.exe"
    $SrcRamsi        = "$BinDir\ramsi_com.dll"
    $SrcSysmonSys    = "$BinDir\sysmon.sys"
    $SrcSysmonUm     = "$BinDir\sysmon-um.exe"
} else {
    $Root            = Split-Path -Parent $ScriptDir
    $SrcPsParser     = "$Root\PsParser\publish\PSParser.dll"
    $SrcPsParserExe  = "$Root\PsParser\publish_exe\PSParser.exe"
    $SrcRamsi        = "$Root\ramsi-rs\target\release\ramsi_com.dll"
    $SrcSysmonSys    = "$Root\sysmon-rs\target\release\sysmon.sys"
    $SrcSysmonUm     = "$Root\sysmon-rs\target\release\sysmon-client.exe"
}

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

function Log([string]$msg) {
    $line = "  $msg"
    Write-Host $line
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}
function LogH([string]$msg) {
    $line = $msg
    Write-Host $line
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

LogH "========================================"
LogH "  Confidence INSTALL  $(Get-Date)"
LogH "  InstallDir = $InstallDir"
LogH "  DriversDir = $DriversDir"
LogH "  Service    = $SvcName"
LogH "  AMSI CLSID = $AmsiClsid"
LogH "========================================"

# ----------------------------------------------------------------
LogH ""
LogH "[PRE-CHECK] Source files..."
$missing = @()
foreach ($src in @($SrcPsParser, $SrcRamsi, $SrcSysmonSys, $SrcSysmonUm)) {
    if (Test-Path $src) {
        Log "[OK]   $(Split-Path -Leaf $src)"
    } else {
        Log "[MISS] $(Split-Path -Leaf $src)  ($src)"
        $missing += $src
    }
}
if ($missing.Count -gt 0) {
    LogH "[ERROR] $($missing.Count) file(s) missing -- run build.bat first"
    exit 1
}

# ----------------------------------------------------------------
LogH ""
LogH "[1/6] Creating install directory..."
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    Log "Created: $InstallDir"
} else {
    Log "Already exists: $InstallDir"
}

# ----------------------------------------------------------------
LogH ""
LogH "[2/6] Copying files..."

$ForceDelete = "$ScriptDir\ramon-client.exe"

function Copy-FileForce([string]$src, [string]$dst) {
    if (-not (Test-Path $src)) {
        Log "[WARNING] source missing: $src -- skipping"
        return
    }
    $name = Split-Path -Leaf $dst
    try {
        Copy-Item -Path $src -Destination $dst -Force -ErrorAction Stop
        Log "Copied: $name"
        return
    } catch {
        Log "Copy locked ($name): $($_.Exception.Message.Trim()) -- trying force-delete"
    }
    if ((Test-Path $ForceDelete) -and (Test-Path $dst)) {
        & $ForceDelete response delete-file $dst 2>&1 | ForEach-Object { Add-Content -Path $LogFile -Value "    ramon-client: $_" -Encoding UTF8 }
    }
    try {
        Copy-Item -Path $src -Destination $dst -Force -ErrorAction Stop
        Log "Copied (after force-delete): $name"
    } catch {
        Log "[WARNING] Could NOT copy $name -- file still locked, continuing"
    }
}

Copy-FileForce $SrcPsParser    "$InstallDir\PSParser.dll"
Copy-FileForce $SrcPsParserExe "$InstallDir\PSParser.exe"
Copy-FileForce $SrcRamsi       "$InstallDir\ramsi_com.dll"
Copy-FileForce $SrcSysmonUm    "$InstallDir\sysmon-um.exe"
Copy-FileForce $SrcSysmonSys   "$DriversDir\sysmon.sys"

# ----------------------------------------------------------------
LogH ""
LogH "[3/6] Setting PSPARSER_DLL_PATH (system-wide)..."
try {
    [System.Environment]::SetEnvironmentVariable(
        'PSPARSER_DLL_PATH',
        "$InstallDir\PSParser.dll",
        [System.EnvironmentVariableTarget]::Machine
    )
    Log "OK: PSPARSER_DLL_PATH=$InstallDir\PSParser.dll"
} catch {
    Log "[WARNING] SetEnvironmentVariable failed: $_"
}

# ----------------------------------------------------------------
LogH ""
LogH "[4/6] Registering AMSI provider (regsvr32)..."

$amsiKey   = "HKLM:\SOFTWARE\Microsoft\AMSI\Providers\$AmsiClsid"
$clsidKey  = "HKLM:\SOFTWARE\Classes\CLSID\$AmsiClsid"
$inprocKey = "$clsidKey\InProcServer32"
$ramsiDll  = "$InstallDir\ramsi_com.dll"

if (Test-Path $amsiKey) {
    Log "AMSI provider already registered -- unregistering first..."
    $proc = Start-Process -FilePath regsvr32.exe -ArgumentList "/u /s `"$ramsiDll`"" -Wait -PassThru -NoNewWindow
    Log "regsvr32 /u exit code: $($proc.ExitCode)"
}

Log "regsvr32 /s $ramsiDll ..."
$proc = Start-Process -FilePath regsvr32.exe -ArgumentList "/s `"$ramsiDll`"" -Wait -PassThru -NoNewWindow
$regsvr32Exit = $proc.ExitCode
Log "regsvr32 exit code: $regsvr32Exit"

# Show every AMSI provider currently in the registry (diagnostic)
Log "Current AMSI providers:"
Get-ChildItem "HKLM:\SOFTWARE\Microsoft\AMSI\Providers" -ErrorAction SilentlyContinue |
    ForEach-Object { Log "  $($_.PSChildName)" }

if (-not (Test-Path $amsiKey)) {
    if ($regsvr32Exit -ne 0) {
        LogH "[ERROR] regsvr32 failed (code $regsvr32Exit) -- check Event Viewer > Application"
            exit 1
    }

    # regsvr32 returned 0 but key wasn't written -- write keys manually
    Log "[WARNING] regsvr32 returned 0 but AMSI key not found -- writing registry keys manually..."
    try {
        if (-not (Test-Path $clsidKey))  { New-Item -Path $clsidKey  -Force | Out-Null }
        Set-ItemProperty -Path $clsidKey  -Name '(default)' -Value 'Ramsi'
        Set-ItemProperty -Path $clsidKey  -Name 'pipe'      -Value 'ramsi'

        if (-not (Test-Path $inprocKey)) { New-Item -Path $inprocKey -Force | Out-Null }
        Set-ItemProperty -Path $inprocKey -Name '(default)'     -Value $ramsiDll
        Set-ItemProperty -Path $inprocKey -Name 'ThreadingModel' -Value 'Both'

        New-Item -Path $amsiKey -Force | Out-Null
        Set-ItemProperty -Path $amsiKey -Name '(default)' -Value 'Ramsi'
        Log "OK: registry keys written manually"
    } catch {
        LogH "[ERROR] Manual registry write failed: $_"
            exit 1
    }
}

if (Test-Path $amsiKey) {
    Log "Verified: AMSI Provider key present in registry"
    $inproc = Get-ItemProperty -Path $inprocKey -ErrorAction SilentlyContinue
    if ($inproc) { Log "InProcServer32: $($inproc.'(default)')" }
} else {
    LogH "[ERROR] AMSI Provider key NOT found -- registration failed"
    exit 1
}

# ----------------------------------------------------------------
LogH ""
LogH "[4b/6] Importing driver-signing certificate (if shipped)..."

$certPath = if (Test-Path Variable:BinDir) { "$BinDir\confidence_test.cer" } else { "$ScriptDir\confidence_test.cer" }
if (Test-Path $certPath) {
    try {
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 $certPath
        foreach ($storeName in @('Root', 'TrustedPublisher')) {
            $store = New-Object System.Security.Cryptography.X509Certificates.X509Store($storeName, 'LocalMachine')
            $store.Open('ReadWrite')
            $already = $store.Certificates | Where-Object { $_.Thumbprint -eq $cert.Thumbprint }
            if (-not $already) {
                $store.Add($cert)
                Log "Cert added to LocalMachine\$storeName ($($cert.Thumbprint.Substring(0,16))...)"
            } else {
                Log "Cert already in LocalMachine\$storeName"
            }
            $store.Close()
        }
    } catch {
        Log "[WARNING] Cert import failed: $_"
    }
} else {
    Log "No .cer in package -- driver may be unsigned (start will fail unless testsigning + manual sign)"
}

# ----------------------------------------------------------------
LogH ""
LogH "[5/6] Installing kernel driver service ($SvcName)..."

$svc = Get-Service -Name $SvcName -ErrorAction SilentlyContinue
if ($svc) {
    Log "Service already exists -- stopping and removing..."
    if ($svc.Status -eq 'Running') {
        Stop-Service -Name $SvcName -Force
        Start-Sleep -Seconds 2
    }
    & sc.exe delete $SvcName | Out-Null
    Start-Sleep -Seconds 1
    Log "Old service removed."
}

Log "sc create $SvcName ..."
# NOTE: kernel drivers need NT path WITHOUT quotes in binPath.
# Quoted paths store literal " in ImagePath and the kernel cannot find the file.
$scResult = & sc.exe create $SvcName type= kernel start= demand error= normal `
    binPath= '\SystemRoot\System32\drivers\sysmon.sys' `
    DisplayName= $SvcDisplay
$scResult | ForEach-Object { Add-Content -Path $LogFile -Value "  sc: $_" -Encoding UTF8 }

if ($LASTEXITCODE -ne 0) {
    LogH "[ERROR] sc create failed (code $LASTEXITCODE)"
    Log "Is sysmon.sys signed? Check test signing: bcdedit /set testsigning on"
    exit 1
}
Log "OK: service $SvcName created"

LogH ""
LogH "[5b] Starting driver service..."
$startResult = & sc.exe start $SvcName
$startResult | ForEach-Object { Add-Content -Path $LogFile -Value "  sc start: $_" -Encoding UTF8 }

if ($LASTEXITCODE -ne 0) {
    Log "[WARNING] sc start failed (code $LASTEXITCODE)"
    Log "Possible causes:"
    Log "  - Driver not signed (enable: bcdedit /set testsigning on, then reboot)"
    Log "  - Dependency missing"
    Log "  - System requires reboot after enabling test signing"
} else {
    Log "OK: driver started"
}
& sc.exe query $SvcName | Add-Content -Path $LogFile -Encoding UTF8

# ----------------------------------------------------------------
LogH ""
LogH "[6/6] Final verification..."
Log "Files in ${InstallDir}:"
Get-ChildItem $InstallDir | ForEach-Object { Log "  $($_.Name)  ($([Math]::Round($_.Length/1KB,1)) KB)" }

$svcFinal = Get-Service -Name $SvcName -ErrorAction SilentlyContinue
if ($svcFinal) {
    Log "Service $SvcName status: $($svcFinal.Status)"
} else {
    Log "[WARNING] Service $SvcName not found"
}

$amsiPresent = Test-Path $amsiKey
Log "AMSI Provider key present: $amsiPresent"

# ----------------------------------------------------------------
LogH ""
LogH "========================================"
LogH "  INSTALL COMPLETE  $(Get-Date)"
LogH "  Log: $LogFile"
LogH "========================================"
Write-Host ""
Write-Host "[OK] Installation complete."
Write-Host "  Log:  $LogFile"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Start daemon:  & '$InstallDir\sysmon-um.exe'"
Write-Host "  2. Run demo:      .\run_demo.bat"
Write-Host ""
