# Test Payment Checklist

## 🧪 Pre-Test Setup

### 1. Verify Firebase Configuration
- [ ] Firebase project is configured
- [ ] Cloud Functions are deployed (check Firebase Console → Functions)
- [ ] Firestore database exists
- [ ] User is logged in (Firebase Auth)

### 2. Verify Razorpay Configuration
- [ ] Test keys are configured in `lib/config/payment_config.dart`
- [ ] `web/index.html` has Razorpay Checkout.js script loaded
- [ ] Current mode: **TEST** (using `rzp_test_` keys)

### 3. Check Current Credit Balance
- [ ] Open Credits Store screen
- [ ] Note current balance (e.g., 20 credits)
- [ ] This will help verify the addition worked

---

## 🎯 Test Scenarios

### Test 1: Basic Purchase Flow (Web)

**Steps:**
1. Run: `flutter run -d chrome`
2. Navigate to Credits Store (Menu → Buy Credits)
3. Click "Purchase" on "Basic Pack" (100 credits, ₹415)
4. Razorpay modal opens
5. Use test card: `4111 1111 1111 1111`, any future date, any CVV
6. Click "Pay"
7. Wait for modal to close

**Expected Results:**
- [ ] Razorpay modal closes automatically
- [ ] Green snackbar appears: "✅ Added 100 credits!"
- [ ] Credit balance updates in header (previous + 100)
- [ ] No errors in browser console

**Console Logs to Check:**
```
✅ Razorpay web credits checkout opened: ₹415 [TEST]
🔄 Calling addCredits Cloud Function with paymentId: pay_xxx...
✅ Cloud Function response: {success: true, ...}
💳 Credits added via Cloud Function: 100
```

**Firestore to Verify:**
- [ ] `Users/{your_uid}/credits/available` increased by 100
- [ ] `Users/{your_uid}/credits/precise` increased by 100.0
- [ ] `creditPayments/{pay_xxx}` document created with:
  - `userId: your_uid`
  - `paymentId: pay_xxx...`
  - `packageKey: credits_100`
  - `creditsAdded: 100`

---

### Test 2: Bonus Credits Package

**Steps:**
1. Click "Purchase" on "Value Pack" (250 credits + 30 bonus = 280 total, ₹830)
2. Complete payment with test card
3. Check balance

**Expected Results:**
- [ ] Balance increases by **280** (not 250)
- [ ] Success message: "✅ Added 280 credits!"
- [ ] Firestore shows `creditsAdded: 280`

**This verifies:** Server-side package validation (client can't fake bonus amount)

---

### Test 3: Payment Cancellation

**Steps:**
1. Click "Purchase" on any package
2. Razorpay modal opens
3. Click "X" or "Cancel" in modal
4. Modal closes

**Expected Results:**
- [ ] Red snackbar: "❌ Payment cancelled by user"
- [ ] Balance unchanged
- [ ] No Cloud Function call in logs
- [ ] No Firestore document created

---

### Test 4: Multiple Quick Purchases

**Steps:**
1. Purchase "Starter Pack" (50 credits)
2. Immediately purchase "Starter Pack" again
3. Wait for both to complete

**Expected Results:**
- [ ] Both purchases succeed
- [ ] Balance increases by 100 total (50 + 50)
- [ ] Two different payment IDs in Firestore
- [ ] No duplicate processing errors

**This verifies:** Each payment gets unique ID from Razorpay

---

### Test 5: Idempotency Check (Advanced)

**This requires manual Cloud Function call - skip if not technical**

**Steps:**
1. Complete a purchase, note the payment ID (e.g., `pay_test_abc123`)
2. Open browser console
3. Run this code:
```javascript
firebase.functions().httpsCallable('addCredits')({
  paymentId: 'pay_test_abc123',  // Same ID as before
  packageKey: 'credits_50'
}).then(result => console.log(result.data));
```

**Expected Results:**
- [ ] Response: `{added: false, remaining: X, ...}`
- [ ] Balance unchanged (not added again)
- [ ] Console log: "Payment pay_test_abc123 already processed"

**This verifies:** Idempotency protection works

---

### Test 6: Invalid Package Key (Advanced)

**Steps:**
1. Open browser console
2. Run:
```javascript
firebase.functions().httpsCallable('addCredits')({
  paymentId: 'pay_test_999',
  packageKey: 'credits_999'  // Invalid
}).then(result => console.log(result.data))
.catch(err => console.error(err));
```

**Expected Results:**
- [ ] Error: "Invalid packageKey"
- [ ] Balance unchanged
- [ ] No Firestore document created

**This verifies:** Server-side validation prevents fake packages

---

### Test 7: Precise Credits Usage

**Steps:**
1. Purchase 100 credits
2. Use AI Chat (costs 1 credit per message)
3. Send 1 message
4. Check Firestore

**Expected Results:**
- [ ] `available`: 99 (integer)
- [ ] `precise`: 99.0 (decimal)
- [ ] UI shows: 99 credits

**Then use a fractional amount:**
1. Trigger an operation that costs 0.5 credits (if you have one)
2. Check Firestore again

**Expected Results:**
- [ ] `available`: 99 (ceiling of 98.5)
- [ ] `precise`: 98.5 (exact)
- [ ] UI shows: 99 credits

**This verifies:** Precise credits tracking works

---

### Test 8: Offline Payment Attempt

**Steps:**
1. Open DevTools → Network tab
2. Set to "Offline" mode
3. Try to purchase credits
4. Razorpay modal won't open or will fail

**Expected Results:**
- [ ] Error message shown
- [ ] No credits added
- [ ] App doesn't crash

---

### Test 9: Different Packages

Test all 4 packages to verify correct amounts:

| Package | Display | Actual | Price |
|---------|---------|--------|-------|
| Starter Pack | 50 credits | 50 | ₹249 |
| Basic Pack | 100 credits | 100 | ₹415 |
| Value Pack | 250 credits | **280** (+30 bonus) | ₹830 |
| Power Pack | 500 credits | **575** (+75 bonus) | ₹1499 |

**Expected:** Each package adds correct amount including bonuses

---

## 📊 Firestore Data to Verify

After ANY successful purchase, check these collections:

### 1. Users/{uid}/credits
```json
{
  "available": 100,        // Integer (what UI shows)
  "precise": 100.0,        // Decimal (accurate tracking)
  "totalPurchased": 100,   // Lifetime purchased
  "totalUsed": 0,          // Lifetime used
  "welcomeGranted": true,  // Welcome bonus flag
  "updatedAt": "Timestamp"
}
```

### 2. creditPayments/{paymentId}
```json
{
  "userId": "abc123...",
  "paymentId": "pay_NZl8P3wjmqG9jY",  // Real Razorpay ID
  "packageKey": "credits_100",
  "creditsAdded": 100,
  "processedAt": "Timestamp",
  "createdAt": "Timestamp"
}
```

### 3. credit_usage/{usageId} (after using credits)
```json
{
  "userId": "abc123...",
  "amount": 1,
  "description": "AI Chat",
  "timestamp": "Timestamp",
  "remainingCredits": 99,
  "remainingPreciseCredits": 99.0
}
```

---

## 🚨 Common Issues & Solutions

### Issue: "Payment success but no credits added"

**Symptoms:**
- Razorpay modal closes
- No success message
- Balance unchanged

**Debug Steps:**
1. Check browser console for errors
2. Look for "🔄 Calling addCredits Cloud Function" log
3. If missing → callback chain broken
4. If present but failed → check Firebase Console → Functions → Logs

**Possible Causes:**
- Cloud Function not deployed
- User not authenticated
- Firebase Functions offline/error
- Network issue

### Issue: "Modal won't open"

**Symptoms:**
- Click "Purchase" but nothing happens
- Console error: "Razorpay not found"

**Solution:**
- Check `web/index.html` has: `<script src="https://checkout.razorpay.com/v1/checkout.js"></script>`
- Refresh page
- Clear browser cache

### Issue: "Payment failed - insufficient balance"

**Symptoms:**
- Error during Razorpay checkout
- Using test cards but still failing

**Solution:**
- Use valid test card: `4111 1111 1111 1111`
- Any future expiry date (e.g., 12/25)
- Any CVV (e.g., 123)
- Make sure test mode is enabled (rzp_test_ key)

### Issue: "Credits show wrong amount"

**Symptoms:**
- Purchased 100 but only got 50
- Or balance didn't increase

**Debug:**
1. Check Firestore → Users/{uid}/credits → `available` field
2. Check creditPayments → verify `creditsAdded` matches package
3. Check console logs for Cloud Function response

**If mismatch:**
- Cloud Function might have wrong package mapping
- Check `functions/src/index.ts` → PACKAGES constant

### Issue: "Duplicate credits added"

**Symptoms:**
- Purchased once but got credits twice
- Balance way higher than expected

**This should NOT happen** (idempotency protection)

**If it does:**
- Check creditPayments collection → multiple docs with same paymentId?
- If yes → idempotency broken, needs investigation
- If no → user made multiple purchases

---

## ✅ Success Criteria

After running all tests, you should have:

- [x] ✅ All purchases complete successfully
- [x] ✅ Correct credit amounts added (including bonuses)
- [x] ✅ Real payment IDs in Firestore (format: `pay_xxx...`)
- [x] ✅ No duplicate processing
- [x] ✅ Precise credits tracked accurately
- [x] ✅ UI updates immediately after purchase
- [x] ✅ No console errors
- [x] ✅ Cancellation works correctly

---

## 🚀 Ready for Production

Before switching to live keys:

1. [ ] All tests passing in test mode
2. [ ] Firestore security rules reviewed
3. [ ] Cloud Functions deployed and working
4. [ ] Razorpay webhook configured (optional but recommended)
5. [ ] Receipt email system added (optional)
6. [ ] Analytics/tracking added (optional)
7. [ ] Switch keys in `payment_config.dart`:
   ```dart
   RAZORPAY_KEY_ID = 'rzp_live_xxx...'  // Live key
   ```
8. [ ] Update webhook secret in Cloud Functions config
9. [ ] Test with small real purchase ($0.01 or minimum)
10. [ ] Monitor Cloud Functions logs for first few days

---

**Current Status:** ✅ READY FOR TESTING
**Test Mode:** ✅ ENABLED (using rzp_test_ keys)
**Risk Level:** 🟢 LOW (test mode, can't charge real money)

Start with Test 1 (Basic Purchase Flow) and work through the list!
