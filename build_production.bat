@echo off
REM Production Build Script for VerveStride (Windows)
REM Usage: build_production.bat [android|ios|web|all]

echo ========================================
echo VerveStride Production Build
echo ========================================
echo.

REM Check if environment variables are set
if "%RAZORPAY_KEY_ID%"=="" (
    echo ERROR: RAZORPAY_KEY_ID not set
    echo Set it with: set RAZORPAY_KEY_ID=rzp_live_xxx
    exit /b 1
)

if "%RAZORPAY_KEY_SECRET%"=="" (
    echo ERROR: RAZORPAY_KEY_SECRET not set
    echo Set it with: set RAZORPAY_KEY_SECRET=your_secret
    exit /b 1
)

REM Optional: Company logo URL
if "%COMPANY_LOGO_URL%"=="" (
    set LOGO_URL=https://vervestride-app.firebaseapp.com/assets/images/vervestridelogo.jpeg
) else (
    set LOGO_URL=%COMPANY_LOGO_URL%
)

echo [OK] Environment variables configured
echo   Key ID: %RAZORPAY_KEY_ID:~0,15%...
echo   Logo: %LOGO_URL%
echo.

REM Build arguments
set BUILD_ARGS=--release --dart-define=RAZORPAY_KEY_ID=%RAZORPAY_KEY_ID% --dart-define=RAZORPAY_KEY_SECRET=%RAZORPAY_KEY_SECRET% --dart-define=COMPANY_LOGO_URL=%LOGO_URL%

REM Determine what to build
set TARGET=%1
if "%TARGET%"=="" set TARGET=all

if "%TARGET%"=="android" goto build_android
if "%TARGET%"=="ios" goto build_ios
if "%TARGET%"=="web" goto build_web
if "%TARGET%"=="all" goto build_all
goto unknown_target

:build_android
echo Building Android APK...
call flutter build apk %BUILD_ARGS%
echo [OK] Android APK built: build\app\outputs\flutter-apk\app-release.apk
echo.

echo Building Android App Bundle...
call flutter build appbundle %BUILD_ARGS%
echo [OK] Android App Bundle built: build\app\outputs\bundle\release\app-release.aab
echo.
goto end

:build_ios
echo Building iOS...
call flutter build ios %BUILD_ARGS% --no-codesign
echo [OK] iOS built (requires Xcode for signing)
echo.
goto end

:build_web
echo Building Web...
call flutter build web %BUILD_ARGS%
echo [OK] Web built: build\web\
echo.
goto end

:build_all
call :build_android
call :build_ios
call :build_web
goto end

:unknown_target
echo ERROR: Unknown target: %TARGET%
echo Usage: build_production.bat [android^|ios^|web^|all]
exit /b 1

:end
echo ========================================
echo Build Complete!
echo ========================================
