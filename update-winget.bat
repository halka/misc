@echo off
setlocal EnableExtensions DisableDelayedExpansion
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%~dp0update-winget.ps1"
exit /b %errorlevel%
