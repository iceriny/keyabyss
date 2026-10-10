@echo off
setlocal
cd /d "%~dp0"
if not exist "logs" mkdir "logs"
"keyabyss.console.exe" --verbose --log-file "%~dp0logs\engine-%RANDOM%-%RANDOM%.log" -- --debug-log "--diagnostics-dir=%~dp0logs"
echo.
echo Diagnostic logs are in the logs folder next to the game.
pause
