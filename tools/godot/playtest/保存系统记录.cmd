@echo off
setlocal
cd /d "%~dp0"
if not exist "logs" mkdir "logs"
set "trace_file=%~dp0logs\system-stall-%RANDOM%-%RANDOM%.etl"
wpr -stop "%trace_file%" "Keyabyss periodic stall" -skipPdbGen -compress
if errorlevel 1 (
    echo Saving failed. Keep the error above; recording may still be active.
    pause
    exit /b 1
)
echo Recording stopped and saved to:
echo "%trace_file%"
pause
