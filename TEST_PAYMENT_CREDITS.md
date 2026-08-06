# Test Payment Credits Flow - Quick Guide

## ⚠️ IMPORTANT: Deploy Cloud Functions First!

Before testing, you MUST deploy the updated Cloud Functions:

```bash
cd functions
npm install
firebase deploy --only functions:addCredits,functions:deductCredits,functions:grantWelcomeCredits,functions:refundCredits
```

Wait for deployment to complete (1-2 minutes).

---

## Test Steps (Web Platform)

### **1. Start the App:**
```bash
flutter run -d chrome
```

### **2. Navigate to Credits Store:**
- Open the app
- Go to Settings → Credits Store (or wherever the credits purchase is)
- You should see your current balance in the top-right corner

### **3. Make a Test Purchase:**
- Click "Purchase" on any package (e.g., "Starter Pack - 50 credits")
- Razorpay Checkout modal will open
- Use test card details:
  - **Card Number:** `4111 1111 1111 1111`
  - **Expiry:** Any future date (e.g., `12/25`)
  - **CVV:** Any 3 digits (e.g., `123`)
  - **Name:** Any name
- Click "Pay"

### **4. Watch the Debug Console:**
You should see logs like:
```
✅ Razorpay web credits checkout opened: ₹249.00 [TEST]
✅ Razorpay credits success: pay_test_xyz123
🔄 Calling addCredits Cloud Function with paymentId: pay_test_xyz123, packageKey: credits_50
✅ Cloud Function response: {success: true, credits: {remaining: 70, precise: 70.0, added: true, creditsAdded: 50}}
💳 Credits loaded from Firestore: 70 (70.0000 precise)
```

### **5. Verify in Firebase Console:**

**Firestore → Users → {your_uid} → (refresh):**
```json
{
  "credits": {
    "available": 70,
    "precise": 70.0,
    "totalPurchased": 50,
    "totalUsed": 0,
    "welcomeGranted": true,
    "updatedAt": "<timestamp>"
  }
}
```

**Firestore → creditPayments → pay_test_xyz123:**
```json
{
  "userId": "{your_uid}",
  "paymentId": "pay_test_xyz123",
  "packageKey": "credits_50",
  "creditsAdded": 50,
  "processedAt": "<timestamp>"
}
```

**Functions → Logs (filter by "addCredits"):**
```
INFO: Adding credits: uid={your_uid}, paymentId=pay_test_xyz123, package=credits_50, credits=50
INFO: Credits added successfully: 50 credits to uid={your_uid}
```

### **6. Test Idempotency (Optional but Recommended):**

Open Firebase Console → Functions → addCredits → Test:

**Input:**
```json
{
  "paymentId": "pay_test_xyz123",
  "packageKey": "credits_50"
}
```

**Expected Response:**
```json
{
  "success": true,
  "credits": {
    "remaining": 70,
    "precise": 70.0,
    "added": false,
    "creditsAdded": 0
  }
}
```

✅ `added: false` means idempotency is working — same payment ID won't add credits twice!

---

## Expected Results ✅

### **Success Indicators:**
- ✅ Real payment ID in logs (starts with `pay_test_` or `pay_`)
- ✅ Cloud Function called with correct parameters
- ✅ Firestore `available` and `precise` fields updated
- ✅ Payment record created in `creditPayments` collection
- ✅ UI shows updated balance immediately
- ✅ Green success snackbar: "✅ Added 50 credits!"
- ✅ Idempotency: duplicate calls return same balance without adding again

### **Failure Indicators (What to Watch For):**
- ❌ Payment ID is fake: `payment_credits_50` → Cloud Function not called correctly
- ❌ Infinite loading → Check Firebase Functions logs for errors
- ❌ Balance doesn't update → Reload issue or Firestore rules blocking read
- ❌ Duplicate credits added → Idempotency broken

---

## Troubleshooting

### **Issue: "Kept loading" / Infinite Spinner**

**Check 1: Cloud Functions Deployed?**
```bash
firebase functions:list
```
Verify `addCredits` is listed and deployed.

**Check 2: Firebase Functions Logs:**
```bash
firebase functions:log --only addCredits --limit 50
```
Look for errors like:
- `Missing required fields`
- `Invalid packageKey`
- `Insufficient permissions`

**Check 3: Authentication:**
Make sure you're logged in! Cloud Function requires authentication.

### **Issue: Balance Not Updating**

**Solution 1: Force Reload**
Add a manual reload button that calls:
```dart
await CreditsService.instance.load(force: true);
```

**Solution 2: Check Firestore Rules**
Make sure user can read their own credits:
```javascript
match /Users/{userId} {
  allow read: if request.auth.uid == userId;
  allow write: if false;  // Only Cloud Functions can write
}
```

### **Issue: Fake Payment ID in Logs**

This means the payment flow is broken. Check:
1. Is `PaymentService.onCreditsSuccess` being called?
2. Is the callback receiving the real `paymentId` from Razorpay?
3. Is `FirebaseSubscriptionService.addCredits` being called with correct params?

**Debug:** Add breakpoints in:
- `web_payment_service.dart` → `openCreditsCheckout` → `handler` callback
- `firebase_subscription_service.dart` → `addCredits` method

---

## Mobile Testing (Android/iOS)

Same steps as web, but:
- Razorpay native SDK will open (not Checkout.js)
- Payment ID format same: `pay_test_xyz123`
- Everything else identical

```bash
# Android
flutter run -d <android_device>

# iOS
flutter run -d <ios_device>
```

---

## Success! 🎉

If you see:
1. ✅ Real payment ID in logs
2. ✅ Cloud Function executed successfully
3. ✅ Firestore updated with correct values
4. ✅ UI shows new balance
5. ✅ Idempotency working (duplicate calls ignored)

**Then the payment system is working correctly!** 🚀

You can now deploy to production with confidence.
