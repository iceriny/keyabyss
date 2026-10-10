@echo off
setlocal
cd /d "%~dp0"
if not exist "logs" mkdir "logs"
"keyabyss.console.exe" --verbose --log-file "%~dp0logs\engine-control-%RANDOM%-%RANDOM%.log" -- --no-debug-log
pause
