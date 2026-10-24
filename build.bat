@echo off
setlocal

rem Builds the Media Shortcuts Magisk zip.
rem Tries PowerShell first, falls back to nothing fancy.

cd /d "%~dp0"

where pwsh >nul 2>&1
if %errorlevel%==0 (
    pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0build.ps1"
    goto :done
)

where powershell >nul 2>&1
if %errorlevel%==0 (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build.ps1"
    goto :done
)

echo PowerShell not found. Use build.sh under WSL or Git Bash instead.
exit /b 1

:done
if errorlevel 1 (
    echo.
    echo Build failed.
    exit /b 1
)

echo.
echo Done.
endlocal
