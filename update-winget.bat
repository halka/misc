@echo off
setlocal EnableExtensions DisableDelayedExpansion

rem Relaunch in an elevated console when needed.
if /i "%~1"=="--elevated" goto :continue
net session >nul 2>&1
if not errorlevel 1 goto :continue
echo Requesting administrator privileges...
powershell.exe -NoProfile -Command "$p = Start-Process -FilePath '%~f0' -ArgumentList '--elevated' -Verb RunAs -Wait -PassThru; exit $p.ExitCode"
exit /b %errorlevel%

:continue
where winget.exe >nul 2>&1
if errorlevel 1 (
    echo ERROR: winget was not found. Install App Installer from Microsoft Store.
    exit /b 1
)

echo Updating WinGet sources...
call :run_winget source update --disable-interactivity --ignore-warnings
if errorlevel 1 goto :failed

echo.
echo Updating desktop apps...
call :run_winget upgrade --all --include-pinned --force --include-unknown --silent --ignore-warnings --accept-package-agreements --accept-source-agreements --disable-interactivity --source winget
if errorlevel 1 goto :failed

echo.
echo Updating Microsoft Store apps...
call :run_winget upgrade --all --include-pinned --force --include-unknown --silent --ignore-warnings --accept-package-agreements --accept-source-agreements --disable-interactivity --source msstore
if errorlevel 1 goto :failed

echo.
echo All update stages completed successfully.
exit /b 0

:run_winget
winget.exe %*
set "RESULT=%errorlevel%"
if "%RESULT%"=="0" exit /b 0
if "%RESULT%"=="-1978335189" exit /b 0
if "%RESULT%"=="-1978335212" exit /b 0
echo ERROR: WinGet failed with exit code %RESULT%.
exit /b 1

:failed
echo.
echo The update stopped because a stage failed. Review the output above.
exit /b 1
