@echo off
setlocal EnableDelayedExpansion

:: Simple winget update script - upgrades all packages
:: Safe to double-click (self-elevates and keeps window open)

rem Self-elevate if not running as admin
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator privileges...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

rem Check if winget is available
where winget >nul 2>&1
if errorlevel 1 (
    echo ERROR: winget not found. Install "App Installer" from Microsoft Store.
    goto :end
)

rem Update sources
echo Updating winget sources...
winget source update --disable-interactivity --ignore-warnings

rem Upgrade all packages
echo.
echo Upgrading all packages...
winget upgrade --all --include-pinned --force --include-unknown --silent --ignore-warnings --accept-package-agreements --accept-source-agreements --disable-interactivity --source winget

rem Check result
if errorlevel 1 (
    echo.
    echo Some upgrades may have failed. Check output above.
    set "RESULT=1"
) else (
    echo.
    echo All upgrades completed successfully.
    set "RESULT=0"
)

:end
echo.
echo Press any key to close...
pause >nul
exit /b %RESULT%

