#!/bin/bash
# Development Build Script for VerveStride
# Uses test keys for development

set -e

# Test keys (safe to commit - these are your test keys)
TEST_KEY_ID="rzp_test_SMpj1xxJxAcT6K"
TEST_KEY_SECRET="PZKW95oZEjcavJ5flTEZVjeU"

echo "========================================="
echo "VerveStride Development Build"
echo "========================================="
echo ""
echo "⚠️  Using TEST keys for development"
echo ""

# Build arguments
BUILD_ARGS="--dart-define=RAZORPAY_KEY_ID=$TEST_KEY_ID --dart-define=RAZORPAY_KEY_SECRET=$TEST_KEY_SECRET"

# Run in debug mode
flutter run $BUILD_ARGS
