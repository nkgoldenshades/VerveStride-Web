# 🔐 Razorpay Payment Setup Guide

## ⚠️ SECURITY FIRST

**NEVER commit your API keys to version control!**

The keys you shared earlier should be:
1. ✅ Revoked immediately at https://dashboard.razorpay.com/app/keys
2. ✅ Regenerated with new values
3. ✅ Stored securely (see below)

---

## Step 1: Get Your Razorpay Keys

### Test Mode (Development)
1. Go to https://dashboard.razorpay.com/app/keys
2. Switch to **Test Mode** (toggle in top-left)
3. Copy your **Key ID** (starts with `rzp_test_`)
4. Copy your **Key Secret** (click "Show" to reveal)

### Live Mode (Production)
1. Complete KYC verification
2. Switch to **Live Mode**
3. Copy your **Key ID** (starts with `rzp_live_`)
4. Copy your **Key Secret**

---

## Step 2: Secure Key Storage

### Option A: Environment Variables (Recommended)

**1. Create `.env` file in project root:**
```bash
# .env
RAZORPAY_KEY_ID=rzp_test_YOUR_NEW_KEY_ID
RAZORPAY_KEY_SECRET=YOUR_NEW_KEY_SECRET
```

**2. Add to `.gitignore`:**
```
.env
*.env
lib/config/payment_config.dart
```

**3. Update `lib/config/payment_config.dart`:**
```dart
static const String razorpayKeyId = String.fromEnvironment(
  'RAZORPAY_KEY_ID',
  defaultValue: 'rzp_test_YOUR_KEY_HERE',
);

static const String razorpayKeySecret = String.fromEnvironment(
  'RAZORPAY_KEY_SECRET',
  defaultValue: 'YOUR_SECRET_HERE',
);
```

**4. Run with environment variables:**
```bash
flutter run --dart-define=RAZORPAY_KEY_ID=rzp_test_xxx --dart-define=RAZORPAY_KEY_SECRET=xxx
```

### Option B: Direct Configuration (Quick Setup)

**Edit `lib/config/payment_config.dart`:**
```dart
static const String razorpayKeyId = 'rzp_test_YOUR_NEW_KEY_ID';
static const String razorpayKeySecret = 'YOUR_NEW_KEY_SECRET';
```

**⚠️ WARNING:** Add this file to `.gitignore` immediately!

### Option C: Firebase Remote Config (Production)

Store keys in Firebase Remote Config and fetch at runtime.

---

## Step 3: Configure Payment Settings

**Edit `lib/config/payment_config.dart`:**

```dart
// Company details
static const String companyName = 'VerveStride';
static const String companyLogo = 'https://your-domain.com/logo.png';
static const String companyColor = '#6C63FF'; // Your brand color

// Currency
static const String currency = 'INR'; // or 'USD', 'EUR', etc.

// Test mode
static const bool isTestMode = true; // Set to false in production
```

---

## Step 4: Install Dependencies

```bash
flutter pub get
```

This will install:
- `razorpay_flutter: ^1.3.7`

---

## Step 5: Platform-Specific Setup

### Android

**1. Update `android/app/build.gradle`:**
```gradle
android {
    defaultConfig {
        minSdkVersion 19 // Razorpay requires minimum 19
    }
}
```

**2. Add Proguard rules (if using):**
Create `android/app/proguard-rules.pro`:
```
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn com.razorpay.**
-keep class com.razorpay.** {*;}
```

### iOS

**1. Update `ios/Podfile`:**
```ruby
platform :ios, '11.0' # Razorpay requires minimum 11.0
```

**2. Run:**
```bash
cd ios
pod install
cd ..
```

### Web

Razorpay Flutter plugin doesn't support web directly. For web:
1. Use Razorpay Standard Checkout (JavaScript)
2. Or use Firebase Functions to create payment links

---

## Step 6: Test the Integration

### Test Cards (Test Mode Only)

**Successful Payment:**
- Card: `4111 1111 1111 1111`
- CVV: Any 3 digits
- Expiry: Any future date

**Failed Payment:**
- Card: `4000 0000 0000 0002`
- CVV: Any 3 digits
- Expiry: Any future date

**UPI (Test Mode):**
- UPI ID: `success@razorpay`
- UPI ID (fail): `failure@razorpay`

### Test the Flow

1. Run the app: `flutter run`
2. Navigate to Premium screen
3. Select a plan
4. Click "Get Premium" or "Get Pro"
5. Razorpay checkout should open
6. Use test card to complete payment
7. Verify success callback

---

## Step 7: Handle Payment Callbacks

The payment service is already set up with callbacks:

```dart
_paymentService.onPaymentSuccess = (paymentId, planKey) {
  // Payment successful!
  // Save subscription to database
  // Update user's premium status
  // Show success message
};

_paymentService.onPaymentFailure = (message) {
  // Payment failed
  // Show error message
  // Log for debugging
};
```

---

## Step 8: Verify Payments (Backend)

**⚠️ IMPORTANT:** Always verify payments on your backend!

### Why?
- Client-side can be manipulated
- Users could fake payment success
- You need to verify signature

### How?

**1. Create Firebase Function:**
```javascript
const crypto = require('crypto');

exports.verifyRazorpayPayment = functions.https.onCall(async (data, context) => {
  const { paymentId, orderId, signature } = data;
  
  const generatedSignature = crypto
    .createHmac('sha256', 'YOUR_KEY_SECRET')
    .update(orderId + '|' + paymentId)
    .digest('hex');
  
  if (generatedSignature === signature) {
    // Payment is valid
    // Update user's subscription in Firestore
    return { success: true };
  } else {
    // Payment is invalid
    return { success: false, error: 'Invalid signature' };
  }
});
```

**2. Call from app after payment success:**
```dart
final result = await FirebaseFunctions.instance
    .httpsCallable('verifyRazorpayPayment')
    .call({
      'paymentId': paymentId,
      'orderId': orderId,
      'signature': signature,
    });
```

---

## Step 9: Webhooks (Production)

Set up webhooks to handle payment events:

### 1. Create Webhook Endpoint

**Firebase Function:**
```javascript
exports.razorpayWebhook = functions.https.onRequest(async (req, res) => {
  const secret = 'YOUR_WEBHOOK_SECRET';
  const signature = req.headers['x-razorpay-signature'];
  
  // Verify webhook signature
  const expectedSignature = crypto
    .createHmac('sha256', secret)
    .update(JSON.stringify(req.body))
    .digest('hex');
  
  if (signature !== expectedSignature) {
    return res.status(400).send('Invalid signature');
  }
  
  const event = req.body.event;
  const payload = req.body.payload;
  
  switch (event) {
    case 'payment.captured':
      // Handle successful payment
      break;
    case 'payment.failed':
      // Handle failed payment
      break;
    case 'subscription.charged':
      // Handle subscription renewal
      break;
  }
  
  res.status(200).send('OK');
});
```

### 2. Configure in Razorpay Dashboard

1. Go to https://dashboard.razorpay.com/app/webhooks
2. Click "Add New Webhook"
3. Enter your webhook URL: `https://your-function-url.com/razorpayWebhook`
4. Select events to listen for
5. Copy the webhook secret
6. Save

---

## Step 10: Go Live Checklist

Before switching to live mode:

- [ ] Complete KYC verification
- [ ] Test all payment flows thoroughly
- [ ] Implement backend verification
- [ ] Set up webhooks
- [ ] Update keys to live mode
- [ ] Set `isTestMode = false` in config
- [ ] Test with real small amount
- [ ] Monitor first few transactions
- [ ] Set up payment failure alerts

---

## Pricing Configuration

The pricing is already set in `lib/services/subscription_service.dart`:

| Plan | Price | Features |
|------|-------|----------|
| **Premium Monthly** | ₹799/month | 50 AI meals, ad-free, analytics |
| **Premium Yearly** | ₹6,399/year | Save 33%, all Premium features |
| **Pro Monthly** | ₹1,599/month | Unlimited AI, video recording |
| **Pro Yearly** | ₹12,799/year | Save 33%, all Pro features |
| **Lifetime** | ₹15,999 | All Pro features forever |

**To change prices:**
Edit `lib/services/subscription_service.dart` and update the `price` field.

**For USD pricing:**
1. Change `currency` to `'USD'` in `payment_config.dart`
2. Update prices in `subscription_service.dart`

---

## Troubleshooting

### "Razorpay not initialized"
- Make sure you called `flutter pub get`
- Restart the app
- Check if keys are set correctly

### "Invalid key ID"
- Verify key starts with `rzp_test_` or `rzp_live_`
- Check for extra spaces
- Regenerate keys if needed

### "Payment failed"
- Check if using test cards in test mode
- Verify internet connection
- Check Razorpay dashboard for error details

### "Signature verification failed"
- Make sure you're using the correct key secret
- Check if order ID matches
- Verify signature generation logic

### Android build fails
- Update `minSdkVersion` to 19 or higher
- Run `flutter clean` and rebuild

### iOS build fails
- Update iOS deployment target to 11.0
- Run `pod install` in ios folder
- Clean and rebuild

---

## Support

**Razorpay Documentation:**
- https://razorpay.com/docs/
- https://razorpay.com/docs/payments/payment-gateway/flutter/

**Razorpay Support:**
- Email: support@razorpay.com
- Dashboard: https://dashboard.razorpay.com/support

**Test Your Integration:**
- https://dashboard.razorpay.com/app/payments

---

## Security Best Practices

1. ✅ Never commit API keys to Git
2. ✅ Use environment variables
3. ✅ Verify payments on backend
4. ✅ Use webhooks for reliability
5. ✅ Log all transactions
6. ✅ Monitor for suspicious activity
7. ✅ Rotate keys periodically
8. ✅ Use HTTPS only
9. ✅ Implement rate limiting
10. ✅ Keep dependencies updated

---

## Next Steps

1. ✅ Revoke the old keys you shared
2. ✅ Generate new keys
3. ✅ Add keys to `payment_config.dart`
4. ✅ Test with test cards
5. ✅ Implement backend verification
6. ✅ Set up webhooks
7. ✅ Go live!

**Your Razorpay payment integration is ready! 🎉**
