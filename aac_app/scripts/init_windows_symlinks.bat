@echo off
:: This script enables Developer Mode on Windows which is required for Flutter symlinks
:: when building native C/C++ plugins (like llama_cpp_dart)

echo Requesting administrative privileges...
net session >nul 2>&1
if %errorLevel% == 0 (
    echo Administrator privileges confirmed.
    echo Enabling Developer Mode...
    reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" /t REG_DWORD /v "AllowDevelopmentWithoutDevLicense" /d "1" /f
    echo Developer Mode has been enabled successfully.
    echo You may need to restart your computer or your IDE for symlink permissions to fully apply.
) else (
    echo Failure: Please run this script as an Administrator.
)
pause
