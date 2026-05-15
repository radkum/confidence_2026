@echo off
:: Confidence reinstaller -- thin launcher for reinstall.ps1
:: Requires Administrator privileges

net session >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Requires ADMINISTRATOR privileges.
    echo Right-click and select "Run as administrator".
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0reinstall.ps1" %*
exit /b %ERRORLEVEL%
