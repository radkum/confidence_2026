@echo off
:: Confidence installer -- thin launcher for install.ps1
:: Requires Administrator privileges

net session >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Requires ADMINISTRATOR privileges.
    echo Right-click and select "Run as administrator".
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
exit /b %ERRORLEVEL%
