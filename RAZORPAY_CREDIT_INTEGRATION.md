# VerveStride - Razorpay Credit Payment Integration

## 🎯 Overview

```
User Wants Credits
      ↓
Razorpay Payment Gateway
      ↓
Payment Successful
      ↓
Credits Added to Account
```

---

## 1️⃣ RAZORPAY SETUP

### Razorpay Account Requirements

```
✅ Business registered in India
✅ GST number
✅ Bank account (INR)
✅ Live Razorpay account (not sandbox)
```

### Razorpay API Keys (From Dashboard)

```
KEY_ID:     rzp_live_xxxxxxxxxxxxxxxx
KEY_SECRET: xxxxxxxxxxxxxxxxxxxxxxxx

Store in Firebase Environment:
├─ Environment Variable
├─ Cloud Functions Secret
└─ Never in frontend code!
```

---

## 2️⃣ CREDIT PACKAGES FOR INDIA

```dart
static const List<CreditPackage> packages = [
  CreditPackage(
    key: 'credits_50_inr',
    name: 'Starter',
    credits: 50,
    priceInr: 249,      // ₹249
    priceName: '₹249',
  ),
  CreditPackage(
    key: 'credits_100_inr',
    name: 'Basic Pack',
    credits: 100,
    priceInr: 415,      // ₹415
    priceName: '₹415',
  ),
  CreditPackage(
    key: 'credits_250_inr',
    name: 'Value Pack',
    credits: 250,
    priceInr: 830,      // ₹830
    bonusCredits: 30,   // +30 = 280 total
    priceName: '₹830',
  ),
  CreditPackage(
    key: 'credits_500_inr',
    name: 'Power Pack',
    credits: 500,
    priceInr: 1499,     // ₹1,499
    bonusCredits: 75,   // +75 = 575 total
    priceName: '₹1,499',
  ),
];
```

---

## 3️⃣ RAZORPAY PAYMENT FLOW

### Complete Flow Diagram

```
┌────────────────────────────────────────────┐
│ USER TAPS "BUY 100 CREDITS FOR ₹415"      │
└────────────────────────────────────────────┘
                    ↓
┌────────────────────────────────────────────┐
│ FRONTEND: Create Razorpay Order            │
│ Call: createRazorpayOrder()                │
└────────────────────────────────────────────┘
                    ↓
┌────────────────────────────────────────────┐
│ CLOUD FUNCTION: Create Order               │
│ Backend → Razorpay API                     │
└────────────────────────────────────────────┘
                    ↓
┌────────────────────────────────────────────┐
│ RAZORPAY RETURNS:                          │
│ {                                          │
│   "id": "order_xxxxx",                     │
│   "amount": 41500,    (₹415 × 100 paise)  │
│   "currency": "INR"                        │
│ }                                          │
└────────────────────────────────────────────┘
                    ↓
┌────────────────────────────────────────────┐
│ FRONTEND: Show Razorpay Checkout           │
│ (User selects payment method)              │
└────────────────────────────────────────────┘
                    ↓
        ┌─────────────┬─────────────┐
        │             │             │
        ▼             ▼             ▼
    UPI        Card         Wallet
    (Google    (Debit/      (PayTM
     Pay,      Credit)       Phonepe)
    PhonePe)
                    │
        ┌─────────────┴─────────────┐
        │                           │
        ▼ SUCCESS                   ▼ FAILED
  Payment captured           Show error
  Razorpay returns           "Payment failed"
  Payment ID
        │
        ▼
  WEBHOOK: Razorpay → Backend
  {
    "event": "payment.authorized",
    "payload": {
      "payment": {
        "entity": {
          "id": "pay_xxxxx",
          "order_id": "order_xxxxx",
          "amount": 41500
        }
      }
    }
  }
        │
        ▼
  CLOUD FUNCTION: verifyAndAddCredits()
  ├─ Verify signature (Razorpay → Backend)
  ├─ Verify amount matches
  ├─ Add 100 credits to user
  └─ Update Firestore
        │
        ▼
  FRONTEND: Poll for completion
  OR wait for webhook callback
        │
        ▼
  ✅ Show success: "100 credits added!"
  💎 Balance updates: 150 credits
```

---

## 4️⃣ BACKEND CLOUD FUNCTION

### Setup Razorpay Package

```bash
# Firebase Cloud Functions - package.json
npm install razorpay
```

### Cloud Function: Create Order

```javascript
// Firebase Cloud Function: createRazorpayOrder

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const Razorpay = require('razorpay');

const razorpay = new Razorpay({
  key_id: process.env.RAZORPAY_KEY_ID,      // rzp_live_xxx
  key_secret: process.env.RAZORPAY_KEY_SECRET  // secret_xxx
});

exports.createRazorpayOrder = functions.https.onCall(async (data, context) => {
  // Verify user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be logged in'
    );
  }

  const { credits, amount } = data;
  // Example: credits=100, amount=41500 (paise)

  try {
    // Create order with Razorpay
    const order = await razorpay.orders.create({
      amount: amount,              // In paise (₹415 = 41500 paise)
      currency: 'INR',
      receipt: `receipt_${Date.now()}`,
      notes: {
        userId: context.auth.uid,
        credits: credits
      }
    });

    console.log(`Order created: ${order.id}`);

    return {
      success: true,
      orderId: order.id,
      amount: order.amount,
      currency: order.currency,
      key: process.env.RAZORPAY_KEY_ID  // Send key to frontend
    };
  } catch (error) {
    console.error('Razorpay order creation failed:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to create payment order'
    );
  }
});
```

### Cloud Function: Verify & Add Credits

```javascript
// Firebase Cloud Function: verifyRazorpayPayment

const crypto = require('crypto');

exports.verifyRazorpayPayment = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User not logged in');
  }

  const { orderId, paymentId, signature, credits, amount } = data;

  try {
    // 1. VERIFY SIGNATURE
    // ────────────────────────────────
    const body = orderId + '|' + paymentId;
    const expectedSignature = crypto
      .createHmac('sha256', process.env.RAZORPAY_KEY_SECRET)
      .update(body)
      .digest('hex');

    if (signature !== expectedSignature) {
      console.error('Invalid signature!');
      throw new functions.https.HttpsError(
        'permission-denied',
        'Payment verification failed'
      );
    }

    // 2. VERIFY AMOUNT
    // ────────────────────────────────
    const expectedAmount = amount;  // In paise
    
    // Get order from Razorpay to verify
    const order = await razorpay.orders.fetch(orderId);
    
    if (order.amount !== expectedAmount) {
      console.error('Amount mismatch!');
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Amount mismatch'
      );
    }

    // 3. ADD CREDITS TO USER
    // ────────────────────────────────
    const uid = context.auth.uid;
    const userRef = admin.firestore().collection('Users').doc(uid);
    
    const userDoc = await userRef.get();
    const currentCredits = userDoc.data()?.credits?.available ?? 0;
    const currentPrecise = userDoc.data()?.credits?.precise ?? 0.0;

    const newBalance = currentCredits + credits;
    const newPrecise = currentPrecise + credits;

    // 4. ATOMIC TRANSACTION
    // ────────────────────────────────
    await admin.firestore().runTransaction(async (transaction) => {
      // Update user credits
      transaction.update(userRef, {
        'credits.available': newBalance,
        'credits.precise': newPrecise,
        'lastCreditsPurchaseAt': admin.firestore.FieldValue.serverTimestamp(),
        'lastCreditsPurchaseAmount': credits
      });

      // Log purchase
      transaction.set(
        admin.firestore().collection('credit_purchases').doc(),
        {
          userId: uid,
          creditsAdded: credits,
          amountPaid: amount / 100,  // Convert paise to rupees
          currency: 'INR',
          orderId: orderId,
          paymentId: paymentId,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          status: 'completed'
        }
      );
    });

    console.log(`✅ ${credits} credits added to user ${uid}`);

    return {
      success: true,
      creditsAdded: credits,
      newBalance: newBalance,
      message: `${credits} credits added!`
    };
  } catch (error) {
    console.error('Payment verification failed:', error);
    throw new functions.https.HttpsError(
      'internal',
      `Payment verification failed: ${error.message}`
    );
  }
});
```

### Webhook: Handle Payment Events

```javascript
// Firebase Cloud Function: razorpayWebhook

exports.razorpayWebhook = functions.https.onRequest(async (req, res) => {
  try {
    const signature = req.headers['x-razorpay-signature'];
    const body = JSON.stringify(req.body);

    // Verify webhook signature
    const expectedSignature = crypto
      .createHmac('sha256', process.env.RAZORPAY_WEBHOOK_SECRET)
      .update(body)
      .digest('hex');

    if (signature !== expectedSignature) {
      console.error('Invalid webhook signature');
      return res.status(403).send('Invalid signature');
    }

    const event = req.body.event;
    const payment = req.body.payload.payment.entity;

    if (event === 'payment.authorized') {
      const orderId = payment.order_id;
      const paymentId = payment.id;

      // Get order details
      const order = await razorpay.orders.fetch(orderId);
      const userId = order.notes.userId;
      const credits = order.notes.credits;

      console.log(`Webhook: Payment ${paymentId} authorized. Adding ${credits} credits to ${userId}`);

      // Add credits (same as verifyRazorpayPayment)
      // ... (use same logic as above)

      res.status(200).send({ success: true });
    }

    res.status(200).send({ received: true });
  } catch (error) {
    console.error('Webhook error:', error);
    res.status(500).send({ error: error.message });
  }
});
```

---

## 5️⃣ FRONTEND IMPLEMENTATION

### Install Razorpay Package

```bash
# pubspec.yaml
dependencies:
  razorpay_flutter: ^1.3.7
```

### Create Payment Service

```dart
// lib/services/razorpay_payment_service.dart

import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'credits_service.dart';

class RazorpayPaymentService {
  static final RazorpayPaymentService _instance = RazorpayPaymentService._();
  factory RazorpayPaymentService() => _instance;
  RazorpayPaymentService._();

  late Razorpay _razorpay;
  Function? _onPaymentSuccess;
  Function? _onPaymentError;

  void initialize({
    required Function onPaymentSuccess,
    required Function onPaymentError,
  }) {
    _razorpay = Razorpay();
    _onPaymentSuccess = onPaymentSuccess;
    _onPaymentError = onPaymentError;

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  /// Call this when user clicks "Buy Credits"
  Future<void> startPayment({
    required int credits,
    required int amountInPaise,  // ₹415 = 41500 paise
    required String packageName,
  }) async {
    try {
      // Step 1: Get order from backend
      final result = await FirebaseFunctions.instance
          .httpsCallable('createRazorpayOrder')
          .call({
            'credits': credits,
            'amount': amountInPaise,
          });

      final orderId = result.data['orderId'];
      final keyId = result.data['key'];

      // Step 2: Prepare Razorpay options
      var options = {
        'key': keyId,  // Razorpay key from backend
        'order_id': orderId,
        'amount': amountInPaise,
        'currency': 'INR',
        'name': 'VerveStride',
        'description': '$credits Credits - $packageName',
        'prefill': {
          'contact': '',
          'email': '',
        },
        'theme': {
          'color': '#6366F1',  // Primary color
        }
      };

      // Step 3: Open Razorpay checkout
      _razorpay.open(options);
    } catch (e) {
      debugPrint('❌ Failed to start payment: $e');
      _onPaymentError?.call('Failed to start payment');
    }
  }

  /// Called when payment succeeds
  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      debugPrint('✅ Payment success: ${response.paymentId}');

      // Extract data from response
      final paymentId = response.paymentId;
      final orderId = response.orderId;
      final signature = response.signature;

      // Verify payment on backend
      final result = await FirebaseFunctions.instance
          .httpsCallable('verifyRazorpayPayment')
          .call({
            'orderId': orderId,
            'paymentId': paymentId,
            'signature': signature,
            'credits': _currentCredits,  // Set during payment initiation
            'amount': _currentAmount,
          });

      if (result.data['success']) {
        // Reload credits
        await CreditsService.instance.load(force: true);

        // Notify caller
        _onPaymentSuccess?.call({
          'creditsAdded': result.data['creditsAdded'],
          'newBalance': result.data['newBalance'],
        });

        debugPrint(
            '🎉 ${result.data['creditsAdded']} credits added successfully!');
      }
    } catch (e) {
      debugPrint('❌ Payment verification failed: $e');
      _onPaymentError?.call('Payment verification failed');
    }
  }

  /// Called when payment fails
  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('❌ Payment failed: ${response.message}');
    _onPaymentError?.call(response.message ?? 'Payment failed');
  }

  /// Called for external wallet payments
  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('📱 External wallet: ${response.walletName}');
  }

  int _currentCredits = 0;
  int _currentAmount = 0;

  void setPaymentDetails(int credits, int amount) {
    _currentCredits = credits;
    _currentAmount = amount;
  }

  void dispose() {
    _razorpay.clear();
  }
}
```

### UI: Credit Purchase Screen

```dart
// lib/screens/credits_screen.dart

import 'package:flutter/material.dart';
import 'package:vervestride/services/razorpay_payment_service.dart';
import 'package:vervestride/services/credits_service.dart';

class CreditsScreen extends StatefulWidget {
  const CreditsScreen({super.key});

  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen> {
  late RazorpayPaymentService _paymentService;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _paymentService = RazorpayPaymentService();
    _paymentService.initialize(
      onPaymentSuccess: _handlePaymentSuccess,
      onPaymentError: _handlePaymentError,
    );
  }

  void _handlePaymentSuccess(Map<String, dynamic> result) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${result['creditsAdded']} credits added!'),
        backgroundColor: Colors.green,
      ),
    );
    setState(() => _isProcessing = false);
    Navigator.pop(context);
  }

  void _handlePaymentError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment failed: $error'),
        backgroundColor: Colors.red,
      ),
    );
    setState(() => _isProcessing = false);
  }

  Future<void> _buyCredits(
    int credits,
    int amountInPaise,
    String packageName,
  ) async {
    setState(() => _isProcessing = true);

    // Set payment details
    _paymentService.setPaymentDetails(credits, amountInPaise);

    // Start Razorpay checkout
    await _paymentService.startPayment(
      credits: credits,
      amountInPaise: amountInPaise,
      packageName: packageName,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buy Credits')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Get more credits to use AI features',
              style: TextStyle(fontSize: 16),
            ),
          ),
          // 50 Credits - ₹249
          CreditPackageCard(
            credits: 50,
            price: '₹249',
            bonus: '',
            onTap: () => _buyCredits(50, 24900, 'Starter'),
            isProcessing: _isProcessing,
          ),
          // 100 Credits - ₹415
          CreditPackageCard(
            credits: 100,
            price: '₹415',
            bonus: '',
            badge: '⭐ Most Popular',
            onTap: () => _buyCredits(100, 41500, 'Basic Pack'),
            isProcessing: _isProcessing,
          ),
          // 250 Credits - ₹830 (+30 bonus)
          CreditPackageCard(
            credits: 280,  // 250 + 30
            price: '₹830',
            bonus: '+30 bonus',
            badge: '⭐ Best Value',
            onTap: () => _buyCredits(280, 83000, 'Value Pack'),
            isProcessing: _isProcessing,
          ),
          // 500 Credits - ₹1,499 (+75 bonus)
          CreditPackageCard(
            credits: 575,  // 500 + 75
            price: '₹1,499',
            bonus: '+75 bonus',
            badge: '⭐⭐ Best Value',
            onTap: () => _buyCredits(575, 149900, 'Power Pack'),
            isProcessing: _isProcessing,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _paymentService.dispose();
    super.dispose();
  }
}

// Package Card Widget
class CreditPackageCard extends StatelessWidget {
  final int credits;
  final String price;
  final String bonus;
  final String? badge;
  final VoidCallback onTap;
  final bool isProcessing;

  const CreditPackageCard({
    required this.credits,
    required this.price,
    required this.bonus,
    required this.onTap,
    required this.isProcessing,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (badge != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '💎 $credits Credits',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (bonus.isNotEmpty)
                      Text(
                        bonus,
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: isProcessing ? null : onTap,
                      child: Text(
                        isProcessing ? 'Processing...' : 'Buy Now',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 6️⃣ RAZORPAY LIVE SETUP

### Step 1: Get Live Keys

```
1. Go to razorpay.com/signin
2. Login to dashboard
3. Navigate to Settings → API Keys
4. Copy KEY_ID and KEY_SECRET (Live mode)
```

### Step 2: Add to Firebase

```bash
# Set environment variables in Firebase
firebase functions:config:set razorpay.key_id="rzp_live_xxx"
firebase functions:config:set razorpay.key_secret="xxxxxxxx"
firebase functions:config:set razorpay.webhook_secret="xxxxxxxx"
```

### Step 3: Configure Webhook

```
1. Razorpay Dashboard → Settings → Webhooks
2. Webhook URL: https://us-central1-your-project.cloudfunctions.net/razorpayWebhook
3. Select events:
   ✅ payment.authorized
   ✅ payment.failed
   ✅ payment.captured
4. Save & Get Webhook Secret
```

### Step 4: Deploy Cloud Functions

```bash
firebase deploy --only functions:createRazorpayOrder,functions:verifyRazorpayPayment,functions:razorpayWebhook
```

---

## 7️⃣ TESTING RAZORPAY

### Test Cards (Live Mode)

```
Successful Payment:
Card: 4111 1111 1111 1111
Expiry: 12/25
CVV: 123

Failed Payment:
Card: 4444 3333 2222 1111
Expiry: 12/25
CVV: 123
```

### Test Payments

```
1. User taps "Buy 100 Credits for ₹415"
2. Razorpay checkout opens
3. Select "Card" → Enter test card
4. Complete payment
5. Check Razorpay Dashboard for payment
6. Verify credits added to account
```

---

## 8️⃣ FLOW SUMMARY

```
┌──────────────────────────────────────────────────────────┐
│ USER FLOW                                                │
└──────────────────────────────────────────────────────────┘

1. User opens Credits screen
2. Sees packages: ₹249, ₹415, ₹830, ₹1,499
3. Taps "Buy Now"
4. Razorpay checkout opens
5. User selects payment method:
   - UPI (Google Pay, PhonePe)
   - Card (Debit/Credit)
   - Wallet (PayTM, etc.)
6. Payment successful
7. Credits immediately added
8. UI updates to show new balance

BACKEND:
├─ Razorpay creates order
├─ User pays
├─ Razorpay sends webhook
├─ Cloud Function verifies signature
├─ Adds credits to Firestore
└─ Frontend reloads balance
```

---

## 9️⃣ KEY DIFFERENCES: Razorpay vs Stripe

| Feature | Razorpay | Stripe |
|---------|----------|--------|
| **Best For** | India | Global |
| **Settlement** | INR to Bank | Multiple currencies |
| **Payment Methods** | UPI, Cards, Wallet | Cards, Digital Wallets |
| **Fees** | 2% + GST | 2.9% + 30¢ |
| **Setup** | Simple | Complex |
| **Live Mode** | Invite not needed | Invite-only in India |

---

## 🔟 SECURITY CHECKLIST

```
✅ Keys stored in Firebase secrets (not in code)
✅ Signature verification on backend
✅ Amount validation before crediting
✅ Atomic transactions (all-or-nothing)
✅ Webhook signature verification
✅ Firestore rules block direct writes
✅ All transactions logged
✅ Rate limiting on purchases
✅ Payment verified with Razorpay before adding credits
```

---

## Code Files to Create/Update

```
NEW FILES:
├─ lib/services/razorpay_payment_service.dart
├─ lib/screens/credits_screen.dart
└─ firebase/functions/razorpayFunctions.js

UPDATE:
├─ pubspec.yaml (add razorpay_flutter)
├─ lib/main.dart (initialize payment service)
└─ lib/services/credits_service.dart (no changes needed)

BACKEND:
├─ Cloud Functions/createRazorpayOrder
├─ Cloud Functions/verifyRazorpayPayment
└─ Cloud Functions/razorpayWebhook
```

