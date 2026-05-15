@echo off
:: Confidence uninstaller -- thin launcher for uninstall.ps1
:: Requires Administrator privileges
:: Usage: uninstall.bat          -- prompts for confirmation
::        uninstall.bat /force   -- no prompt

net session >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Requires ADMINISTRATOR privileges.
    echo Right-click and select "Run as administrator".
    pause
    exit /b 1
)

set "PS_ARGS="
if /i "%~1"=="/force" set "PS_ARGS=-Force"
if /i "%~1"=="-force" set "PS_ARGS=-Force"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1" %PS_ARGS%
exit /b %ERRORLEVEL%
