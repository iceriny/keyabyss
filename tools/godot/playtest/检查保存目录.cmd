@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0check-save-directory.ps1"
if errorlevel 1 goto failed
echo.
echo Please send the save-directory log from the logs folder.
pause
exit /b 0
:failed
echo.
echo The check could not run. Please send the error shown above.
pause
exit /b 1
