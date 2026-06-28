@echo off
TITLE Gearmulator Installer

:: Check for parameters
if "%~1"=="" (
    echo No parameters provided. Automatically installing the latest version...
    echo.
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0gm-install.ps1" -Latest
) else (
    :: If parameters were provided, pass them all (%*) to the script
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0gm-install.ps1" %*
)

pause

