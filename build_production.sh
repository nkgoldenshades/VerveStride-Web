#!/bin/bash
# Production Build Script for VerveStride
# Usage: ./build_production.sh [android|ios|web|all]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}VerveStride Production Build${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if environment variables are set
if [ -z "$RAZORPAY_KEY_ID" ]; then
    echo -e "${RED}ERROR: RAZORPAY_KEY_ID not set${NC}"
    echo "Set it with: export RAZORPAY_KEY_ID=rzp_live_xxx"
    exit 1
fi

if [ -z "$RAZORPAY_KEY_SECRET" ]; then
    echo -e "${RED}ERROR: RAZORPAY_KEY_SECRET not set${NC}"
    echo "Set it with: export RAZORPAY_KEY_SECRET=your_secret"
    exit 1
fi

# Optional: Company logo URL
LOGO_URL="${COMPANY_LOGO_URL:-https://vervestride-app.firebaseapp.com/assets/images/vervestridelogo.jpeg}"

echo -e "${GREEN}✓ Environment variables configured${NC}"
echo -e "  Key ID: ${RAZORPAY_KEY_ID:0:15}..."
echo -e "  Logo: $LOGO_URL"
echo ""

# Build arguments
BUILD_ARGS="--release --dart-define=RAZORPAY_KEY_ID=$RAZORPAY_KEY_ID --dart-define=RAZORPAY_KEY_SECRET=$RAZORPAY_KEY_SECRET --dart-define=COMPANY_LOGO_URL=$LOGO_URL"

# Determine what to build
TARGET="${1:-all}"

build_android() {
    echo -e "${YELLOW}Building Android APK...${NC}"
    flutter build apk $BUILD_ARGS
    echo -e "${GREEN}✓ Android APK built: build/app/outputs/flutter-apk/app-release.apk${NC}"
    echo ""
    
    echo -e "${YELLOW}Building Android App Bundle...${NC}"
    flutter build appbundle $BUILD_ARGS
    echo -e "${GREEN}✓ Android App Bundle built: build/app/outputs/bundle/release/app-release.aab${NC}"
    echo ""
}

build_ios() {
    echo -e "${YELLOW}Building iOS...${NC}"
    flutter build ios $BUILD_ARGS --no-codesign
    echo -e "${GREEN}✓ iOS built (requires Xcode for signing)${NC}"
    echo ""
}

build_web() {
    echo -e "${YELLOW}Building Web...${NC}"
    flutter build web $BUILD_ARGS
    echo -e "${GREEN}✓ Web built: build/web/${NC}"
    echo ""
}

case $TARGET in
    android)
        build_android
        ;;
    ios)
        build_ios
        ;;
    web)
        build_web
        ;;
    all)
        build_android
        build_ios
        build_web
        ;;
    *)
        echo -e "${RED}Unknown target: $TARGET${NC}"
        echo "Usage: ./build_production.sh [android|ios|web|all]"
        exit 1
        ;;
esac

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Build Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
