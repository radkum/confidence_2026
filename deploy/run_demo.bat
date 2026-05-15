@echo off
setlocal EnableDelayedExpansion

:: ============================================================
::  run_demo.bat  -- scans PS1 samples through PSParser and
::                   collects a detection report
::  No admin required (PSParser CLI = regular dotnet exe)
::
::  Usage:
::    run_demo.bat                     -- scan all default samples
::    run_demo.bat /dir  <path>        -- scan specific directory
::    run_demo.bat /file <file.ps1>    -- scan one file
::    run_demo.bat /amsi-check         -- check AMSI provider status only
::
::  Output: deploy\reports\report_<timestamp>\
::    report.txt   -- human-readable
::    report.csv   -- for Excel/analysis
::    json\        -- raw PSParser JSON per file
::    errors.log   -- scan errors
:: ============================================================

set "ROOT=%~dp0.."
set "PSPARSER_DIR=%ROOT%\PsParser"
set "SAMPLES_DIR=%ROOT%\samples"
set "REPORTS_BASE=%~dp0reports"
set "TIMESTAMP=%date:~-4,4%%date:~-7,2%%date:~0,2%_%time:~0,2%%time:~3,2%%time:~6,2%"
set "TIMESTAMP=%TIMESTAMP: =0%"
set "REPORT_DIR=%REPORTS_BASE%\report_%TIMESTAMP%"

set "AMSI_CLSID={b8614e83-84ac-45fb-82a8-21711aaf07f2}"

:: Parse args
set "SCAN_DIR="
set "SCAN_FILE="
set "AMSI_ONLY=0"

:PARSE_ARGS
if "%~1"=="" goto :ARGS_DONE
if /i "%~1"=="/dir"        ( set "SCAN_DIR=%~2"  & shift & shift & goto :PARSE_ARGS )
if /i "%~1"=="/file"       ( set "SCAN_FILE=%~2" & shift & shift & goto :PARSE_ARGS )
if /i "%~1"=="/amsi-check" ( set "AMSI_ONLY=1"   & shift & goto :PARSE_ARGS )
shift
goto :PARSE_ARGS
:ARGS_DONE

if not exist "%REPORTS_BASE%" mkdir "%REPORTS_BASE%"
mkdir "%REPORT_DIR%"
mkdir "%REPORT_DIR%\json"

set "RPT=%REPORT_DIR%\report.txt"
set "CSV=%REPORT_DIR%\report.csv"
set "ERRLOG=%REPORT_DIR%\errors.log"

:: Global counters
set /a "CNT_TOTAL=0"
set /a "CNT_BYPASS=0"
set /a "CNT_SUSPICIOUS=0"
set /a "CNT_CLEAN=0"
set /a "CNT_ERROR=0"

call :H1 "Confidence Detection Report -- %date% %time%"
call :RPT "Generator : run_demo.bat"
call :RPT "PSParser  : %PSPARSER_DIR%"
call :RPT "Report    : %REPORT_DIR%"
call :RPT ""

echo File,Category,IsAmsiBypass,ConfidenceScore,ObfuscationScore > "%CSV%"

:: ============================================================
:: SECTION 0: System status
:: ============================================================
call :H2 "SYSTEM STATUS"

:: dotnet available?
where dotnet >nul 2>&1
if errorlevel 1 (
    call :RPT "[ERROR] dotnet not found in PATH -- PSParser cannot run"
    echo [ERROR] dotnet not found
    exit /b 1
)
for /f "tokens=*" %%V in ('dotnet --version 2^>nul') do call :RPT "[OK] dotnet version: %%V"

:: PSParser project present?
if not exist "%PSPARSER_DIR%\PSParser.csproj" (
    call :RPT "[ERROR] PSParser.csproj not found in %PSPARSER_DIR%"
    exit /b 1
)
call :RPT "[OK] PSParser.csproj: %PSPARSER_DIR%"

:: First build check (dotnet build, not run-every-time)
call :RPT ""
call :RPT "Building PSParser (first-time / incremental)..."
dotnet build "%PSPARSER_DIR%\PSParser.csproj" -c Debug --nologo -v quiet >> "%ERRLOG%" 2>&1
if errorlevel 1 (
    call :RPT "[ERROR] PSParser build failed -- see errors.log"
    echo [ERROR] PSParser build failed. Check: %ERRLOG%
    exit /b 1
)
call :RPT "[OK] PSParser build OK"

:: AMSI provider registered?
call :RPT ""
call :RPT "AMSI Provider (ramsi-com):"
reg query "HKLM\SOFTWARE\Microsoft\AMSI\Providers\%AMSI_CLSID%" >nul 2>&1
if errorlevel 1 (
    call :RPT "  [--] NOT REGISTERED -- static scan only (PSParser CLI)"
    call :RPT "  Run deploy\install.bat to activate AMSI protection"
    set "AMSI_ACTIVE=0"
) else (
    call :RPT "  [OK] ACTIVE -- CLSID: %AMSI_CLSID%"
    for /f "skip=2 tokens=3" %%V in ('reg query "HKLM\SOFTWARE\Classes\CLSID\%AMSI_CLSID%\InProcServer32" /ve 2^>nul') do (
        call :RPT "  [OK] DLL: %%V"
    )
    set "AMSI_ACTIVE=1"
)

:: ConfidenceKm driver status
call :RPT ""
call :RPT "Kernel driver (ConfidenceKm):"
sc query ConfidenceKm >nul 2>&1
if errorlevel 1 (
    call :RPT "  [--] NOT INSTALLED"
) else (
    for /f "tokens=4" %%S in ('sc query ConfidenceKm ^| findstr /i "STATE"') do (
        call :RPT "  State: %%S"
    )
)

if "!AMSI_ONLY!"=="1" (
    call :RPT ""
    call :RPT "Mode /amsi-check -- done."
    goto :FINAL_REPORT
)

:: ============================================================
:: SECTION 1: Scan samples
:: ============================================================
call :H2 "SCANNING SAMPLES"

if defined SCAN_FILE (
    :: Single file mode
    call :SCAN_ONE_FILE "!SCAN_FILE!" "manual"
    goto :FINAL_REPORT
)

if defined SCAN_DIR (
    :: Single directory mode
    call :SCAN_DIRECTORY "!SCAN_DIR!" "custom"
    goto :FINAL_REPORT
)

:: Default: scan all sample subdirectories
call :SCAN_DIRECTORY "%SAMPLES_DIR%\Obfuscated_Malicious_Powershell" "malicious"
call :SCAN_DIRECTORY "%SAMPLES_DIR%\amsi-bypass\AmsiScanBufferBypass" "amsi-bypass"
call :SCAN_DIRECTORY "%SAMPLES_DIR%\benign" "benign"
call :SCAN_DIRECTORY "%~dp0confidence-release\samples\test-synthetic" "synthetic"

:: ============================================================
:: SECTION 2: Final report
:: ============================================================
:FINAL_REPORT
call :H1 "SUMMARY"
call :RPT "  Files scanned    : !CNT_TOTAL!"
call :RPT "  AMSI Bypass      : !CNT_BYPASS!"
call :RPT "  Suspicious       : !CNT_SUSPICIOUS!"
call :RPT "  Clean            : !CNT_CLEAN!"
call :RPT "  Scan errors      : !CNT_ERROR!"
call :RPT ""
call :RPT "  Report files:"
call :RPT "    Text  : %RPT%"
call :RPT "    CSV   : %CSV%"
call :RPT "    JSON  : %REPORT_DIR%\json\"
call :RPT "    Errors: %ERRLOG%"

echo.
echo ========================================
echo  SUMMARY
echo ========================================
echo  Total scanned : !CNT_TOTAL!
echo  AMSI Bypass   : !CNT_BYPASS!
echo  Suspicious    : !CNT_SUSPICIOUS!
echo  Clean         : !CNT_CLEAN!
echo  Errors        : !CNT_ERROR!
echo ========================================
echo  Report: %REPORT_DIR%
echo ========================================
exit /b 0

:: ============================================================
:: :SCAN_DIRECTORY  <dir> <category>
:: ============================================================
:SCAN_DIRECTORY
set "_SD_DIR=%~1"
set "_SD_CAT=%~2"

if not exist "!_SD_DIR!" (
    call :RPT "[SKIP] Directory not found: !_SD_DIR!"
    goto :EOF
)

call :RPT ""
call :RPT "--- Directory: !_SD_DIR! [!_SD_CAT!] ---"

set /a "_SD_CNT=0"
for %%F in ("!_SD_DIR!\*.ps1") do (
    call :SCAN_ONE_FILE "%%F" "!_SD_CAT!"
    set /a "_SD_CNT+=1"
)
if "!_SD_CNT!"=="0" (
    call :RPT "  (no .ps1 files found)"
)
goto :EOF

:: ============================================================
:: :SCAN_ONE_FILE  <filepath> <category>
:: ============================================================
:SCAN_ONE_FILE
set "_SF_FILE=%~1"
set "_SF_CAT=%~2"
set "_SF_NAME=%~nx1"

set /a "CNT_TOTAL+=1"

:: Sanitize name for JSON filename (replace spaces)
set "_SF_SAFE=%_SF_NAME: =_%"
set "_SF_JSON=%REPORT_DIR%\json\%_SF_SAFE%.json"

:: Run PSParser with --json flag
dotnet run --project "%PSPARSER_DIR%\PSParser.csproj" --no-build -- --json "!_SF_FILE!" > "!_SF_JSON!" 2>> "%ERRLOG%"
set "_SF_CODE=%errorlevel%"

if "!_SF_CODE!" NEQ "0" (
    call :RPT "  [ERR] !_SF_NAME! -- PSParser exit !_SF_CODE!"
    set /a "CNT_ERROR+=1"
    echo !_SF_NAME!,!_SF_CAT!,ERROR,,,  >> "%CSV%"
    goto :EOF
)

:: Parse JSON output for key fields
:: PSParser outputs one JSON object; we extract with findstr/for
set "_IS_BYPASS=unknown"
set "_CONF=0"
set "_OBF=0"

for /f "usebackq delims=" %%L in ("!_SF_JSON!") do (
    set "_LINE=%%L"
    echo !_LINE! | findstr /i "\"IsAmsiBypass\".*true" >nul 2>&1  && set "_IS_BYPASS=true"
    echo !_LINE! | findstr /i "\"IsAmsiBypass\".*false" >nul 2>&1 && set "_IS_BYPASS=false"
    for /f "tokens=2 delims=:," %%V in ('echo !_LINE! ^| findstr /i "\"ConfidenceScore\""') do (
        set "_CONF=%%V"
        set "_CONF=!_CONF: =!"
        set "_CONF=!_CONF:}=!"
    )
    for /f "tokens=2 delims=:," %%V in ('echo !_LINE! ^| findstr /i "\"ObfuscationScore\""') do (
        set "_OBF=%%V"
        set "_OBF=!_OBF: =!"
        set "_OBF=!_OBF:}=!"
    )
)

:: Classify result
set "_STATUS=CLEAN"
set "_MARK=[   ]"
if "!_IS_BYPASS!"=="true" (
    set "_STATUS=AMSI_BYPASS"
    set "_MARK=[!!!]"
    set /a "CNT_BYPASS+=1"
) else (
    set /a "_SC=0"
    if defined _CONF (
        for /f %%N in ('echo !_CONF! ^| findstr /r "^[0-9]*$"') do set /a "_SC=%%N" 2>nul
    )
    if !_SC! GEQ 40 (
        set "_STATUS=SUSPICIOUS"
        set "_MARK"="[ ? ]"
        set /a "CNT_SUSPICIOUS+=1"
    ) else (
        set /a "CNT_CLEAN+=1"
    )
)

call :RPT "  !_MARK! !_SF_NAME!"
call :RPT "        Status    : !_STATUS!"
call :RPT "        AmsiBypass: !_IS_BYPASS!"
call :RPT "        Score     : !_CONF! (obfuscation: !_OBF!)"

echo !_SF_NAME!,!_SF_CAT!,!_IS_BYPASS!,!_CONF!,!_OBF! >> "%CSV%"
goto :EOF

:: ============================================================
:: Formatting helpers
:: ============================================================
:H1
echo.
echo ========================================
echo   %~1
echo ========================================
echo. >> "%RPT%"
echo ======================================== >> "%RPT%"
echo   %~1 >> "%RPT%"
echo ======================================== >> "%RPT%"
goto :EOF

:H2
echo.
echo --- %~1 ---
echo. >> "%RPT%"
echo --- %~1 --- >> "%RPT%"
goto :EOF

:RPT
echo %~1
echo %~1 >> "%RPT%"
goto :EOF
