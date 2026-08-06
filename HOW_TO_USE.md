# How to Use - Quick Guide

## For Development/Testing (NOW)

### Option 1: Quick Run (Easiest)
```bash
# Linux/Mac
chmod +x build_development.sh
./build_development.sh

# Windows
build_development.bat
```

This uses your test keys automatically. No setup needed!

### Option 2: Manual Run
```bash
flutter run --dart-define=RAZORPAY_KEY_ID=rzp_test_SMpj1xxJxAcT6K --dart-define=RAZORPAY_KEY_SECRET=PZKW95oZEjcavJ5flTEZVjeU
```

### What You'll See:
- App runs normally
- Payments work in TEST mode
- Voice features work (on real device)
- All features available
- Logs show: `⚠️ DEVELOPMENT MODE: Using Razorpay TEST keys`

---

## For Production (LATER)

When you're ready to launch:

### Step 1: Get Live Keys
1. Go to [Razorpay Dashboard](https://dashboard.razorpay.com/)
2. Switch to "Live Mode" (toggle top-left)
3. Settings → API Keys
4. Copy your `rzp_live_xxx` key

### Step 2: Set Environment Variables

**Linux/Mac:**
```bash
export RAZORPAY_KEY_ID="rzp_live_YOUR_KEY"
export RAZORPAY_KEY_SECRET="YOUR_SECRET"
```

**Windows:**
```cmd
set RAZORPAY_KEY_ID=rzp_live_YOUR_KEY
set RAZORPAY_KEY_SECRET=YOUR_SECRET
```

### Step 3: Build Production
```bash
# Linux/Mac
./build_production.sh android

# Windows
build_production.bat android
```

### What Changes:
- Payments use REAL money
- Logs show: `✅ PRODUCTION MODE: Using Razorpay LIVE keys`
- Ready for app store submission

---

## Testing Voice Features

Voice features ONLY work on real devices (not emulator):

1. Build and install on real Android/iOS device
2. Grant microphone permission when prompted
3. Tap the floating AI button
4. Tap microphone icon
5. Speak your message
6. Try saying "VerveStride AI" to activate wake word

---

## Quick Commands

```bash
# Development (test keys)
./build_development.sh

# Production Android
./build_production.sh android

# Production iOS
./build_production.sh ios

# Check for errors
flutter analyze
```

---

## Summary

**Right Now**: Use `build_development.sh` - everything works with test keys

**Before Launch**: Use `build_production.sh` with live keys

That's it! The work is done. Just swap keys when ready for production.
