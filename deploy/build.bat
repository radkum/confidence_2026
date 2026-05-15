@echo off
setlocal EnableDelayedExpansion

:: ============================================================
::  build.bat  -- builds all Confidence components
::  Requires: Rust (cargo), .NET 8 SDK, VS 2022 (VC tools)
::  Run from normal CMD (no admin needed)
:: ============================================================

set "ROOT=%~dp0.."
set "LOG_DIR=%~dp0logs"
set "LOGFILE=%LOG_DIR%\build_%date:~-4,4%%date:~-7,2%%date:~0,2%_%time:~0,2%%time:~3,2%%time:~6,2%.log"
set "LOGFILE=%LOGFILE: =0%"

if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

call :LOG "========================================"
call :LOG "  Confidence BUILD  %date% %time%"
call :LOG "========================================"
call :LOG "ROOT = %ROOT%"

set "BUILD_ERRORS=0"

:: ---- 1. PSParser NativeAOT DLL ----------------------------------------
call :LOG ""
call :LOG "[1/3] Building PSParser (NativeAOT DLL)..."

set "PSPARSER_DIR=%ROOT%\PsParser"
set "PSPARSER_OUT=%PSPARSER_DIR%\publish"

if exist "%PSPARSER_OUT%\PSParser.dll" (
    call :LOG "  PSParser.dll already exists: %PSPARSER_OUT%\PSParser.dll"
    call :LOG "  Delete publish\ to force rebuild."
    goto :PSPARSER_DONE
)

where dotnet >nul 2>&1
if errorlevel 1 (
    call :LOG "  ERROR: dotnet not found in PATH"
    call :LOG "  Install .NET 8 SDK: https://dotnet.microsoft.com/download"
    set "BUILD_ERRORS=1"
    goto :PSPARSER_DONE
)

:: Find vcvarsall.bat
set "VCVARS="
for %%P in (
    "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat"
    "C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvarsall.bat"
    "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvarsall.bat"
    "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat"
) do (
    if exist %%P set "VCVARS=%%~P"
)

if "%VCVARS%"=="" (
    call :LOG "  ERROR: vcvarsall.bat not found -- required for NativeAOT"
    call :LOG "  Install Visual Studio 2022 with C++ Desktop Development"
    set "BUILD_ERRORS=1"
    goto :PSPARSER_DONE
)

call :LOG "  Using: %VCVARS%"
call "%VCVARS%" x64 >> "%LOGFILE%" 2>&1

call :LOG "  dotnet publish (NativeAOT)..."
cd /d "%PSPARSER_DIR%"
dotnet publish PSParser.csproj -r win-x64 -c Release -p:PublishAot=true -p:NativeLib=Shared -o publish >> "%LOGFILE%" 2>&1
if errorlevel 1 (
    call :LOG "  ERROR: dotnet publish failed (code: %errorlevel%)"
    set "BUILD_ERRORS=1"
) else (
    call :LOG "  OK: %PSPARSER_OUT%\PSParser.dll"
)

:PSPARSER_DONE

:: ---- 2. ramsi-com (Rust AMSI COM provider DLL) -------------------------
call :LOG ""
call :LOG "[2/3] Building ramsi-com (cdylib DLL)..."

set "RAMSI_DIR=%ROOT%\ramsi-rs"
set "RAMSI_OUT=%RAMSI_DIR%\target\release\ramsi_com.dll"

where cargo >nul 2>&1
if errorlevel 1 (
    call :LOG "  ERROR: cargo not found in PATH"
    call :LOG "  Install Rust: https://rustup.rs/"
    set "BUILD_ERRORS=1"
    goto :RAMSI_DONE
)

cd /d "%RAMSI_DIR%"
call :LOG "  cargo build -p ramsi-com --release..."
cargo build -p ramsi-com --release >> "%LOGFILE%" 2>&1
if errorlevel 1 (
    call :LOG "  ERROR: cargo build ramsi-com failed"
    set "BUILD_ERRORS=1"
) else (
    if exist "%RAMSI_OUT%" (
        call :LOG "  OK: %RAMSI_OUT%"
    ) else (
        call :LOG "  ERROR: %RAMSI_OUT% not found after successful cargo build"
        set "BUILD_ERRORS=1"
    )
)

:RAMSI_DONE

:: ---- 3a. sysmon-km (kernel driver) - MUST build from sysmon-km/ subdir -----
::                  so cargo picks up .cargo/config.toml with /SUBSYSTEM:NATIVE flags
call :LOG ""
call :LOG "[3a/3] Building sysmon-km (kernel driver)..."

set "SYSMON_DIR=%ROOT%\sysmon-rs"
set "SYSMON_KM_DIR=%SYSMON_DIR%\sysmon-km"
set "SYSMON_KM_DLL=%SYSMON_DIR%\target\release\sysmon.dll"
set "SYSMON_KM_SYS=%SYSMON_DIR%\target\release\sysmon.sys"

cd /d "%SYSMON_KM_DIR%"
call :LOG "  cargo build --release  (from sysmon-km\)..."
cargo build --release >> "%LOGFILE%" 2>&1
if errorlevel 1 goto :SYSMON_KM_FAIL
if not exist "!SYSMON_KM_DLL!" goto :SYSMON_KM_NO_DLL
if exist "!SYSMON_KM_SYS!" del /f "!SYSMON_KM_SYS!"
ren "!SYSMON_KM_DLL!" "sysmon.sys"
if not exist "!SYSMON_KM_SYS!" goto :SYSMON_KM_RENAME_FAIL
call :LOG "  OK: !SYSMON_KM_SYS!  (renamed from sysmon.dll)"
goto :SYSMON_KM_DONE
:SYSMON_KM_FAIL
call :LOG "  ERROR: cargo build sysmon-km failed"
set "BUILD_ERRORS=1"
goto :SYSMON_KM_DONE
:SYSMON_KM_NO_DLL
call :LOG "  ERROR: !SYSMON_KM_DLL! not produced -- check linker errors"
set "BUILD_ERRORS=1"
goto :SYSMON_KM_DONE
:SYSMON_KM_RENAME_FAIL
call :LOG "  ERROR: rename sysmon.dll -> sysmon.sys failed"
set "BUILD_ERRORS=1"
:SYSMON_KM_DONE

:: ---- 3b. sysmon-um (Rust userspace daemon) ------------------------------
call :LOG ""
call :LOG "[3b/3] Building sysmon-um (sysmon-client exe)..."

set "SYSMON_UM_OUT=%SYSMON_DIR%\target\release\sysmon-client.exe"

cd /d "%SYSMON_DIR%"
call :LOG "  cargo build -p sysmon-client --release..."
cargo build -p sysmon-client --release >> "%LOGFILE%" 2>&1
if errorlevel 1 (
    call :LOG "  ERROR: cargo build sysmon-client failed"
    set "BUILD_ERRORS=1"
) else (
    if exist "%SYSMON_UM_OUT%" (
        call :LOG "  OK: %SYSMON_UM_OUT%"
    ) else (
        call :LOG "  ERROR: %SYSMON_UM_OUT% not found after successful cargo build"
        set "BUILD_ERRORS=1"
    )
)

:: ---- Summary -----------------------------------------------------------
call :LOG ""
call :LOG "========================================"
call :LOG "  Artifact check:"
call :CHECK_FILE "%PSPARSER_DIR%\publish\PSParser.dll"        "PSParser.dll"
call :CHECK_FILE "%RAMSI_DIR%\target\release\ramsi_com.dll"   "ramsi_com.dll"
call :CHECK_FILE "%SYSMON_DIR%\target\release\sysmon.sys"     "sysmon.sys"
call :CHECK_FILE "%SYSMON_UM_OUT%"                            "sysmon-client.exe"

if "%BUILD_ERRORS%"=="1" (
    call :LOG ""
    call :LOG "  RESULT: BUILD ERRORS -- check log: %LOGFILE%"
    echo.
    echo [ERROR] Build failed. Details: %LOGFILE%
    exit /b 1
) else (
    call :LOG "  RESULT: All components built OK"
    echo.
    echo [OK] Build complete. Run install.bat to deploy.
    exit /b 0
)

:: ---- Helpers -----------------------------------------------------------
:LOG
echo %~1
echo %~1 >> "%LOGFILE%"
goto :EOF

:CHECK_FILE
if exist "%~1" (
    call :LOG "  [OK] %~2"
) else (
    call :LOG "  [!!] MISSING: %~2  (%~1)"
)
goto :EOF
