# Firebase Backend Setup Guide

## 🎯 What We Built

A complete Firebase backend for subscription and credits management with:
- ✅ Firestore database schema
- ✅ Security rules (prevent client manipulation)
- ✅ Cloud Functions (server-side validation)
- ✅ Real-time sync
- ✅ Transaction logging
- ✅ Razorpay integration

---

## 📋 Prerequisites

1. Firebase project (you already have this)
2. Node.js 18+ installed
3. Firebase CLI installed
4. Razorpay account (test & live keys)

---

## 🚀 Step 1: Install Firebase CLI

```bash
npm install -g firebase-tools
```

Login to Firebase:
```bash
firebase login
```

---

## 🔧 Step 2: Initialize Firebase Functions

In your project root:

```bash
# Initialize Firebase (if not already done)
firebase init

# Select:
# - Firestore (rules and indexes)
# - Functions (JavaScript)
# - Hosting (optional)

# When prompted:
# - Use existing project: vervestride
# - Language: JavaScript
# - ESLint: No (optional)
# - Install dependencies: Yes
```

---

## 📦 Step 3: Install Function Dependencies

```bash
cd functions
npm install
```

This installs:
- `firebase-admin` - Firebase Admin SDK
- `firebase-functions` - Cloud Functions SDK
- `razorpay` - Razorpay Node.js SDK
- `crypto` - For webhook signature verification

---

## 🔑 Step 4: Configure Environment Variables

### Option A: Using Firebase Environment Config (Recommended)

```bash
# Set Razorpay test keys
firebase functions:config:set \
  razorpay.mode="test" \
  razorpay.test_key_id="rzp_test_xxxxxxxxxxxxx" \
  razorpay.test_key_secret="xxxxxxxxxxxxxxxxxxxxx"

# Set Razorpay live keys (for production)
firebase functions:config:set \
  razorpay.live_key_id="rzp_live_xxxxxxxxxxxxx" \
  razorpay.live_key_secret="xxxxxxxxxxxxxxxxxxxxx"

# Set webhook secret
firebase functions:config:set \
  razorpay.webhook_secret="your_webhook_secret"
```

### Option B: Using .env File (Local Development)

Create `functions/.env`:
```env
RAZORPAY_MODE=test
RAZORPAY_TEST_KEY_ID=rzp_test_xxxxxxxxxxxxx
RAZORPAY_TEST_KEY_SECRET=xxxxxxxxxxxxxxxxxxxxx
RAZORPAY_LIVE_KEY_ID=rzp_live_xxxxxxxxxxxxx
RAZORPAY_LIVE_KEY_SECRET=xxxxxxxxxxxxxxxxxxxxx
RAZORPAY_WEBHOOK_SECRET=your_webhook_secret
```

---

## 🗄️ Step 5: Deploy Firestore Rules & Indexes

```bash
# Deploy security rules
firebase deploy --only firestore:rules

# Deploy indexes
firebase deploy --only firestore:indexes
```

**What this does:**
- Sets up security rules (users can only read their own data)
- Creates indexes for efficient queries
- Prevents client-side data manipulation

---

## ☁️ Step 6: Deploy Cloud Functions

```bash
# Deploy all functions
firebase deploy --only functions

# Or deploy specific functions
firebase deploy --only functions:activateSubscription
firebase deploy --only functions:addCredits
firebase deploy --only functions:deductCredits
firebase deploy --only functions:refundCredits
firebase deploy --only functions:getSubscriptionStatus
```

**Functions deployed:**
1. `activateSubscription` - Activate subscription after payment
2. `addCredits` - Add credits after payment
3. `deductCredits` - Deduct credits for AI usage
4. `refundCredits` - Refund credits on failure
5. `getSubscriptionStatus` - Get user subscription status
6. `razorpayWebhook` - Handle Razorpay webhooks (optional)

---

## 🧪 Step 7: Test Locally (Optional)

Start Firebase emulators:

```bash
firebase emulators:start
```

This starts:
- Functions emulator: http://localhost:5001
- Firestore emulator: http://localhost:8080
- Emulator UI: http://localhost:4000

Update your Flutter app to use emulators (for testing):

```dart
// In main.dart (development only)
if (kDebugMode) {
  FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
  FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
}
```

---

## 📱 Step 8: Update Flutter App

### 8.1: Add Cloud Functions Dependency

Already in your `pubspec.yaml`:
```yaml
dependencies:
  cloud_functions: ^6.0.6  # ✅ Already added
```

### 8.2: Update Payment Service

Update `lib/services/payment_service.dart` to call Cloud Functions after payment:

```dart
import 'firebase_subscription_service.dart';

// In _onSuccess method:
void _onSuccess(PaymentSuccessResponse r) {
  final id = r.paymentId ?? '';
  
  if (_isCreditsCheckout) {
    final key = _currentPackageKey ?? '';
    final pkg = CreditsService.getPackageByKey(key);
    _currentPackageKey = null;
    _isCreditsCheckout = false;
    
    if (pkg != null) {
      // Call Cloud Function to add credits
      FirebaseSubscriptionService.instance.addCredits(
        paymentId: id,
        packageKey: key,
        credits: pkg.totalCredits,
      ).then((result) {
        if (result['success']) {
          onCreditsSuccess?.call(id, key, pkg.totalCredits);
        } else {
          onPaymentFailure?.call('Failed to activate credits: ${result['error']}');
        }
      });
    }
  } else {
    final key = _currentPlanKey ?? '';
    _currentPlanKey = null;
    
    // Call Cloud Function to activate subscription
    FirebaseSubscriptionService.instance.activateSubscription(
      paymentId: id,
      planKey: key,
    ).then((result) {
      if (result['success']) {
        onPaymentSuccess?.call(id, key);
      } else {
        onPaymentFailure?.call('Failed to activate subscription: ${result['error']}');
      }
    });
  }
  
  debugPrint('✅ Razorpay success: $id');
}
```

### 8.3: Update Credits Service

Update `lib/services/credits_service.dart` to use server-side deduction:

```dart
import 'firebase_subscription_service.dart';

/// Deduct credits for AI usage (server-side validation)
Future<bool> useCredits(int amount, {String? description}) async {
  // Call Cloud Function for server-side validation
  final result = await FirebaseSubscriptionService.instance.deductCredits(
    amount: amount,
    description: description,
  );

  if (result['success']) {
    // Update local state
    final remaining = result['data']['credits']['remaining'] as int;
    _availableCredits = remaining;
    notifyListeners();
    debugPrint('💳 Used $amount credits. Remaining: $_availableCredits');
    return true;
  } else {
    debugPrint('❌ Failed to deduct credits: ${result['error']}');
    return false;
  }
}

/// Refund credits (e.g., if AI call fails)
Future<void> refundCredits(int amount, String reason) async {
  final result = await FirebaseSubscriptionService.instance.refundCredits(
    amount: amount,
    reason: reason,
  );

  if (result['success']) {
    final total = result['data']['credits']['total'] as int;
    _availableCredits = total;
    notifyListeners();
    debugPrint('💳 Refunded $amount credits. Total: $_availableCredits');
  }
}
```

---

## 🔐 Step 9: Set Up Razorpay Webhook (Optional but Recommended)

### 9.1: Get Webhook URL

After deploying functions, get the webhook URL:

```bash
firebase functions:config:get
```

Your webhook URL will be:
```
https://us-central1-vervestride.cloudfunctions.net/razorpayWebhook
```

### 9.2: Configure in Razorpay Dashboard

1. Go to https://dashboard.razorpay.com/app/webhooks
2. Click "Add New Webhook"
3. Enter webhook URL
4. Select events:
   - `payment.captured`
   - `payment.failed`
5. Generate webhook secret
6. Save the secret in Firebase config:

```bash
firebase functions:config:set razorpay.webhook_secret="your_webhook_secret"
firebase deploy --only functions
```

---

## 📊 Step 10: Monitor & Debug

### View Function Logs

```bash
# Real-time logs
firebase functions:log

# Specific function logs
firebase functions:log --only activateSubscription
```

### Firebase Console

1. Go to https://console.firebase.google.com
2. Select your project
3. Navigate to:
   - **Firestore** - View database
   - **Functions** - View function logs
   - **Authentication** - View users

---

## 🧪 Testing Checklist

### Test Subscription Flow

1. ✅ User signs up
2. ✅ User purchases Pro plan
3. ✅ Razorpay payment succeeds
4. ✅ Cloud Function activates subscription
5. ✅ Firestore updated with subscription data
6. ✅ Local app syncs with server
7. ✅ User has Pro features

### Test Credits Flow

1. ✅ User purchases credits
2. ✅ Razorpay payment succeeds
3. ✅ Cloud Function adds credits
4. ✅ Firestore updated with credits
5. ✅ User uses AI feature
6. ✅ Credits deducted server-side
7. ✅ AI call fails → Credits refunded

### Test Security

1. ✅ Try to modify subscription in Firestore directly → Denied
2. ✅ Try to add credits in Firestore directly → Denied
3. ✅ Try to access another user's data → Denied

---

## 💰 Cost Estimate

### Firebase Free Tier (Spark Plan)

**Firestore:**
- 50K reads/day
- 20K writes/day
- 1GB storage

**Cloud Functions:**
- 2M invocations/month
- 400K GB-seconds/month
- 200K CPU-seconds/month

**For 1,000 active users:**
- ~10K function calls/day
- ~5K Firestore reads/day
- ~2K Firestore writes/day
- **Cost: $0/month** (within free tier)

### Blaze Plan (Pay as you go)

**For 10,000 active users:**
- ~100K function calls/day
- ~50K Firestore reads/day
- ~20K Firestore writes/day
- **Cost: ~$25-50/month**

**For 100,000 active users:**
- ~1M function calls/day
- ~500K Firestore reads/day
- ~200K Firestore writes/day
- **Cost: ~$200-400/month**

---

## 🔧 Troubleshooting

### Function Deployment Fails

```bash
# Check Node.js version
node --version  # Should be 18+

# Reinstall dependencies
cd functions
rm -rf node_modules package-lock.json
npm install

# Deploy again
firebase deploy --only functions
```

### "Permission Denied" Errors

```bash
# Check Firestore rules
firebase deploy --only firestore:rules

# Verify user is authenticated
# Check Firebase Console → Authentication
```

### Credits Not Syncing

```bash
# Check function logs
firebase functions:log --only deductCredits

# Verify Firestore data
# Go to Firebase Console → Firestore
# Check users/{userId}/credits
```

### Razorpay Payment Not Activating

```bash
# Check function logs
firebase functions:log --only activateSubscription

# Verify payment ID is correct
# Check Razorpay Dashboard → Payments
```

---

## 📚 Next Steps

1. ✅ Deploy to production
2. ✅ Test with real payments (small amounts)
3. ✅ Monitor function logs
4. ✅ Set up alerts (Firebase Console → Alerts)
5. ✅ Add analytics (Firebase Analytics)
6. ✅ Create admin dashboard (optional)

---

## 🎉 You're Done!

Your Firebase backend is now set up with:
- ✅ Server-side subscription validation
- ✅ Secure credit management
- ✅ Transaction logging
- ✅ Real-time sync
- ✅ Razorpay integration

**Total setup time: 2-3 hours**

Need help? Check the logs or ask me! 🚀
