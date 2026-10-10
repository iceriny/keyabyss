@echo off
setlocal
cd /d "%~dp0"
wpr -start GeneralProfile -start GPU -filemode
if errorlevel 1 (
    echo Recording did not start. Keep the error above and run this file as administrator.
    echo Do not run the save script unless recording started successfully.
    pause
    exit /b 1
)
echo Recording started. Open the game normally, reproduce several stalls for about 30 seconds,
echo then run the save script as administrator.
pause
