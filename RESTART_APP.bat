@echo off
echo ===================================
echo STOPPING OLD APP AND RESTARTING
echo ===================================

echo.
echo Killing all Flutter/Dart processes...
taskkill /F /IM dart.exe /T >nul 2>&1
taskkill /F /IM dartvm.exe /T >nul 2>&1

echo.
echo Waiting 2 seconds...
timeout /t 2 >nul

echo.
echo Starting fresh Flutter app on Chrome...
cd /d d:\vervestride
start cmd /k "flutter run -d chrome"

echo.
echo ===================================
echo App will open in a new window
echo The beep should be GONE!
echo ===================================
pause
