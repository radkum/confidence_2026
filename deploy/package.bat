@echo off
setlocal EnableDelayedExpansion

:: ============================================================
::  package.bat  -- collects binaries + scripts -> confidence-release\
::                  then creates confidence-release.zip
::  Run AFTER build.bat  (no admin required)
:: ============================================================

set "SDIR=%~dp0"
set "ROOT=%~dp0.."
set "PKG=%SDIR%confidence-release"
set "ZIP=%SDIR%confidence-release.zip"
if not exist "%SDIR%logs" mkdir "%SDIR%logs"
set "LOG=%SDIR%logs\package.log"

echo. > "%LOG%"
call :L "========================================"
call :L "Confidence PACKAGE  %date% %time%"
call :L "PKG = %PKG%"
call :L "ZIP = %ZIP%"

:: Clean
if exist "%PKG%" rmdir /s /q "%PKG%"
if exist "%ZIP%"  del /f "%ZIP%"

:: Dirs
mkdir "%PKG%"
mkdir "%PKG%\bin"
mkdir "%PKG%\samples"
mkdir "%PKG%\samples\malicious"
mkdir "%PKG%\samples\amsi-bypass"
mkdir "%PKG%\samples\benign"
mkdir "%PKG%\samples\test-synthetic"

:: ----------------------------------------------------------------
call :L ""
call :L "[1/4] Binaries..."
set "ERRS=0"

call :CP_BIN "%ROOT%\PsParser\publish\PSParser.dll"              "PSParser.dll"
call :CP_BIN "%ROOT%\PsParser\publish_exe\PSParser.exe"          "PSParser.exe"
call :CP_BIN "%ROOT%\ramsi-rs\target\release\ps-parser-cli.exe"  "ps-parser-cli.exe"
call :CP_BIN "%ROOT%\ramsi-rs\target\release\ramsi_com.dll"      "ramsi_com.dll"
call :CP_BIN "%ROOT%\sysmon-rs\target\release\sysmon.sys"        "sysmon.sys"
call :CP_BIN "%ROOT%\sysmon-rs\target\release\sysmon-client.exe" "sysmon-um.exe"

if !ERRS! NEQ 0 (
    call :L "ERROR: !ERRS! binary file^(s^) missing -- run build.bat first"
    goto :FAIL
)

:: Sign the driver and export the cert for install-time import
call :L ""
call :L "[1b/4] Signing driver..."
:: Use Windows PowerShell 5 (has Cert: drive); pwsh 7 doesn't have it by default
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%SDIR%sign_build.ps1" ^
    -DriverPath "%PKG%\bin\sysmon.sys" ^
    -CertOutPath "%PKG%\bin\confidence_test.cer" >> "%LOG%" 2>&1
if errorlevel 1 (
    call :L "  [WARNING] driver sign FAILED -- sysmon.sys remains unsigned"
    call :L "             install.ps1 will skip cert import; you must self-sign on target"
) else (
    call :L "  [OK] sysmon.sys signed + confidence_test.cer exported"
)

:: ----------------------------------------------------------------
call :L ""
call :L "[2/4] Scripts..."
for %%S in (install.bat uninstall.bat reinstall.bat run_demo.bat build.bat install.ps1 uninstall.ps1 reinstall.ps1 test_amsi.ps1 sign_driver.ps1 compare_layers.ps1) do (
    if exist "%SDIR%%%S" (
        copy /y "%SDIR%%%S" "%PKG%\%%S" >nul
        echo   [OK] %%S
        echo   [OK] %%S >> "%LOG%"
    ) else (
        echo   [MISS] %%S
        echo   [MISS] %%S >> "%LOG%"
    )
)

:: Force-delete helper (used by uninstall.ps1 for locked DLLs)
if exist "%SDIR%ramon-client.exe" (
    copy /y "%SDIR%ramon-client.exe" "%PKG%\ramon-client.exe" >nul
    echo   [OK] ramon-client.exe
    echo   [OK] ramon-client.exe >> "%LOG%"
) else (
    echo   [MISS] ramon-client.exe  (build redr-rs/cli first)
    echo   [MISS] ramon-client.exe >> "%LOG%"
)

:: ----------------------------------------------------------------
call :L ""
call :L "[3/4] Samples..."

set "D1=%ROOT%\samples\Obfuscated_Malicious_Powershell"
if exist "!D1!" (
    for %%F in ("!D1!\*.ps1") do copy /y "%%F" "%PKG%\samples\malicious\" >nul
    call :L "  malicious  OK"
) else ( call :L "  [skip] !D1! not found" )

set "D2=%ROOT%\samples\amsi-bypass\AmsiScanBufferBypass"
if exist "!D2!" (
    for %%F in ("!D2!\*.ps1") do copy /y "%%F" "%PKG%\samples\amsi-bypass\" >nul
    call :L "  amsi-bypass OK"
) else ( call :L "  [skip] !D2! not found" )

set "D3=%ROOT%\samples\benign"
if exist "!D3!" (
    for %%F in ("!D3!\*.ps1") do copy /y "%%F" "%PKG%\samples\benign\" >nul
    call :L "  benign OK"
) else ( call :L "  [skip] !D3! not found" )

:: Synthetic samples
call :SYNTHETICS "%PKG%\samples\test-synthetic"
call :L "  synthetic OK"

:: ----------------------------------------------------------------
call :L ""
call :L "[4/4] README + ZIP..."

call :README "%PKG%\README.txt"

if exist "%ZIP%" del /f "%ZIP%"
powershell -NoProfile -NonInteractive -Command "Compress-Archive -Path '%PKG%\*' -DestinationPath '%ZIP%' -CompressionLevel Optimal" >> "%LOG%" 2>&1
if errorlevel 1 ( call :L "ERROR: Compress-Archive failed" & goto :FAIL )

for %%Z in ("%ZIP%") do set "ZSZ=%%~zZ"
call :L "OK: %ZIP%  (!ZSZ! bytes)"

call :L "========================================"
call :L "PACKAGE READY -- ZIP: %ZIP%"
call :L "========================================"
echo.
echo [OK] Package ready: %ZIP%
exit /b 0

:FAIL
call :L "PACKAGE FAILED"
echo [ERROR] Package failed -- see: %LOG%
exit /b 1

:: ================================================================
:L
echo %~1
echo %~1 >> "%LOG%"
goto :EOF

:CP_BIN
if exist "%~1" (
    copy /y "%~1" "%PKG%\bin\%~2" >nul
    call :L "  [OK  ] %~2"
) else (
    call :L "  [MISS] %~2  (src: %~1)"
    set /a ERRS+=1
)
goto :EOF

:: ================================================================
:SYNTHETICS
set "T=%~1"
:: test 1: reflection bypass => AMSI_BYPASS
echo $a = [Ref].Assembly.GetType^('System.Management.Automation.AmsiUtils'^) > "%T%\test_01_reflection_bypass.ps1"
echo $b = $a.GetField^('amsiInitFailed','NonPublic,Static'^) >> "%T%\test_01_reflection_bypass.ps1"
echo $b.SetValue^($null,$true^) >> "%T%\test_01_reflection_bypass.ps1"
:: test 2: PSv2 downgrade => SUSPICIOUS
echo powershell -Version 2 -Command "Invoke-Expression $payload" > "%T%\test_02_psv2_downgrade.ps1"
:: test 3: ETW bypass => AMSI_BYPASS
echo $f = [System.Management.Automation.Tracing.PSEtwLogProvider].GetField^('etwProvider','NonPublic,Static'^) > "%T%\test_03_etw_bypass.ps1"
echo $f.SetValue^($null,$null^) >> "%T%\test_03_etw_bypass.ps1"
:: test 4: base64 obfuscation => SUSPICIOUS
echo $d = [Convert]::FromBase64String^('SQBuAHYAbwBrAGUALQBFAHgAcAByAGUAcwBzAGkAbwBuAA=='^) > "%T%\test_04_base64.ps1"
echo $e = [Text.Encoding]::Unicode.GetString^($d^) >> "%T%\test_04_base64.ps1"
echo Invoke-Expression $e >> "%T%\test_04_base64.ps1"
:: test 5: benign => CLEAN
echo Get-Process ^| Select-Object Name, CPU > "%T%\test_05_benign.ps1"
echo Write-Host "System OK" >> "%T%\test_05_benign.ps1"
goto :EOF

:: ================================================================
:README
set "R=%~1"
echo ============================================================ > "%R%"
echo  Confidence -- AMSI + Kernel Detection System >> "%R%"
echo  Deployment package -- %date% %time% >> "%R%"
echo ============================================================ >> "%R%"
echo. >> "%R%"
echo CONTENTS: >> "%R%"
echo   bin\PSParser.dll      C# NativeAOT detector >> "%R%"
echo   bin\ramsi_com.dll     Rust AMSI COM provider (Layer 1) >> "%R%"
echo   bin\sysmon.sys        Rust kernel driver (Layer 2) >> "%R%"
echo   bin\sysmon-um.exe     Userspace daemon (Layer 2) >> "%R%"
echo   samples\malicious\    Obfuscated bypass scripts >> "%R%"
echo   samples\amsi-bypass\  AMSI scan buffer bypass >> "%R%"
echo   samples\benign\       Clean scripts (false-positive check) >> "%R%"
echo   samples\test-synthetic\ Synthetic test samples >> "%R%"
echo   install.bat           Install (requires admin) >> "%R%"
echo   uninstall.bat         Uninstall (requires admin) >> "%R%"
echo   reinstall.bat         Reinstall (requires admin) >> "%R%"
echo   run_demo.bat          Scan samples + report >> "%R%"
echo   build.bat             Build binaries from source >> "%R%"
echo. >> "%R%"
echo REQUIREMENTS: >> "%R%"
echo   Windows 10/11 x64, .NET 8 Runtime >> "%R%"
echo   Test Signing Mode OR signed driver certificate for sysmon.sys >> "%R%"
echo. >> "%R%"
echo INSTALLATION: >> "%R%"
echo   1. (optional) build.bat >> "%R%"
echo   2. bcdedit /set testsigning on   [then reboot] >> "%R%"
echo   3. install.bat  (run as Administrator) >> "%R%"
echo   4. "C:\Program Files\Confidence\sysmon-um.exe"  (Layer 2 daemon) >> "%R%"
echo   5. run_demo.bat >> "%R%"
echo. >> "%R%"
echo UNINSTALL:  uninstall.bat >> "%R%"
echo REINSTALL:  reinstall.bat >> "%R%"
echo. >> "%R%"
echo LOGS: >> "%R%"
echo   C:\ProgramData\Confidence\logs\  (install/uninstall) >> "%R%"
echo   deploy\reports\report_TIMESTAMP\  (demo scan) >> "%R%"
echo. >> "%R%"
echo AMSI CLSID : {b8614e83-84ac-45fb-82a8-21711aaf07f2} >> "%R%"
echo Service    : ConfidenceKm >> "%R%"
echo. >> "%R%"
echo TROUBLESHOOTING: >> "%R%"
echo   regsvr32 fails : PSParser.dll must be in same dir as ramsi_com.dll >> "%R%"
echo   sc start fails : bcdedit /enum -- verify testsigning is On, then reboot >> "%R%"
echo   AMSI logs      : Event Viewer > Application > Source: ramsi >> "%R%"
echo   Driver logs    : DebugView (Sysinternals) or WinDbg kernel debug >> "%R%"
goto :EOF
