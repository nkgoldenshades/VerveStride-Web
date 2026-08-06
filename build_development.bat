@echo off
REM Development Build Script for VerveStride (Windows)
REM Uses test keys for development

echo =========================================
echo VerveStride Development Build
echo =========================================
echo.
echo [!] Using TEST keys for development
echo.

REM Test keys (safe to commit - these are your test keys)
set TEST_KEY_ID=rzp_test_SMpj1xxJxAcT6K
set TEST_KEY_SECRET=PZKW95oZEjcavJ5flTEZVjeU

REM Build arguments
set BUILD_ARGS=--dart-define=RAZORPAY_KEY_ID=%TEST_KEY_ID% --dart-define=RAZORPAY_KEY_SECRET=%TEST_KEY_SECRET%

REM Run in debug mode
flutter run %BUILD_ARGS%
