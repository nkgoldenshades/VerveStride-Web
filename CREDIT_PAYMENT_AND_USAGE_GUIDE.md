# VerveStride Credit System - Payment & Usage Complete Guide

## 📱 System Overview

```
USER WORKFLOW:
┌─────────────────────────────────────────────────────────────┐
│ 1. User Wants AI Feature                                    │
│    (Chat, Photo Analysis, etc.)                             │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. Check Available Credits                                  │
│    CreditsService.availableCredits >= cost?                 │
└─────────────────────────────────────────────────────────────┘
                          ↓
        ┌─────────────────┴─────────────────┐
        │                                   │
        ▼ YES                               ▼ NO
    Use Feature                         Show "Buy Credits" Dialog
        │                                   │
        └─────────────────┬─────────────────┘
                          ▼
        ┌─────────────────────────────────────────┐
        │ 3. Deduct Credits from Balance          │
        │    _preciseCredits -= cost              │
        └─────────────────────────────────────────┘
                          ↓
        ┌─────────────────────────────────────────┐
        │ 4. UI Updates to Show New Balance       │
        │    💎 45 credits (was 50)               │
        └─────────────────────────────────────────┘
```

---

## 💳 PART 1: CREDIT PURCHASE (Payment)

### Step 1: User Views Credit Packages

**Location:** Settings → Credits / Purchase Screen

```dart
// Credits available to purchase
50 credits   → $2.99 USD   / ₹249 INR
100 credits  → $4.99 USD   / ₹415 INR
250 credits  → $9.99 USD   / ₹830 INR  (+30 bonus = 280 total)
500 credits  → $17.99 USD  / ₹1,499 INR (+75 bonus = 575 total)
```

### Step 2: User Selects Package & Pays

```dart
// File: lib/services/firebase_subscription_service.dart

User taps "Buy 100 Credits for $4.99"
                    ↓
         Payment Processing (via Stripe/Pay)
                    ↓
         Payment Successful ✅
                    ↓
    Stripe sends webhook to backend
                    ↓
     Cloud Function: addCreditsAfterPayment()
                    ↓
    Firestore updated:
    User.credits.available += 100
    User.credits.precise += 100.0
                    ↓
    Frontend reloaded:
    CreditsService.load(force: true)
                    ↓
    UI shows new balance: 💎 150 credits
```

### Step 3: Backend Security

**Important:** Credits are ONLY added via Cloud Functions (backend)

```dart
// ❌ NOT ALLOWED - Frontend cannot directly modify credits
User.credits.available = 999;  // Firebase rules BLOCK this

// ✅ ONLY ALLOWED - Backend transaction after payment verified
Cloud Function receives:
  - Payment ID (from Stripe)
  - Amount (100 credits)
  - User ID (verified via Firebase Auth)
  
Then safely updates Firestore
```

---

## 🎯 PART 2: CREDIT USAGE (When User Uses AI)

### When User Sends Chat Message

```
BEFORE:
💎 50.5000 credits available

USER SENDS: "Create a meal plan"
                    ↓
    CHECK: Do I have enough credits?
    Cost = 0.0267 credits (from Gemini tokens)
    50.5000 >= 0.0267? YES ✅
                    ↓
    DEDUCT: 50.5000 - 0.0267 = 50.4733 credits
                    ↓
    UPDATE FIRESTORE via Cloud Function
                    ↓
AFTER:
💎 50 credits (displayed as ceil(50.4733))
```

### Step-by-Step Code Flow

```dart
// FILE: lib/widgets/floating_ai_assistant.dart (Line 3200+)

void _sendMessage(String message) async {
  // Step 1: Get current balance
  final currentCredits = CreditsService.instance.preciseCredits;  // 50.5000
  
  // Step 2: Estimate cost (rough)
  final estimatedCost = (message.length / 4 / 1000000 * 0.30) + 500 / 1000000 * 2.50;
  // = ~0.006 credits
  
  // Step 3: Check if user has enough
  if (currentCredits < 1.0 && !isPro) {
    // Free user without credits
    showDialog("Not enough credits. Buy now?");
    return;
  }
  
  // Step 4: Send to AI
  setState(() => _isProcessing = true);
  
  final response = await FirebaseAIService.instance.generateContent(message);
  
  // FILE: lib/services/firebase_ai_service.dart (Line 1031+)
  
  // Step 5: Get actual token usage from response
  final inputTokens = response.usageMetadata?.promptTokenCount ?? 0;      // 234
  final outputTokens = response.usageMetadata?.candidatesTokenCount ?? 0; // 612
  
  // Step 6: Calculate ACTUAL cost
  // Formula: (input_tokens * 0.30 + output_tokens * 2.50) / 1,000,000 / 0.06
  final apiCostUsd = (inputTokens * 0.30 + outputTokens * 2.50) / 1000000.0;
  // = $0.001602 USD
  
  final creditsUsed = apiCostUsd / 0.06;
  // = 0.0267 credits
  
  // Step 7: Deduct from user account via Cloud Function
  await CreditsService.instance.usePreciseCredits(
    creditsUsed,  // 0.0267
    description: 'AI Chat'
  );
  
  // FILE: lib/services/credits_service.dart (Line 190+)
  
  // Step 8: Cloud Function deducts (backend transaction)
  final result = await FirebaseFunctions.instance
      .httpsCallable('deductCredits')
      .call({
        'amount': 0.0267,
        'description': 'AI Chat'
      });
  
  // Backend updates Firestore:
  // User.credits.precise = 50.5000 - 0.0267 = 50.4733
  // User.credits.available = ceil(50.4733) = 51
  
  // Step 9: Update local UI
  _preciseCredits = 50.4733;
  _availableCredits = 51;
  notifyListeners();
  
  // UI rebuilds and shows: 💎 50 credits
}
```

---

## 📊 REAL EXAMPLE: User's Complete Journey

### Day 1: User Registers

```
🎁 Welcome bonus: +20 credits
Balance: 20.0000 credits
```

### Day 1, 10:00 AM: First Chat

```
User: "How do I gain muscle mass?"

Tokens: 50 input + 200 output = 250 total
Cost: (50 × 0.30 + 200 × 2.50) / 1M / 0.06 = 0.0083 credits

Balance BEFORE: 20.0000
Balance AFTER:  19.9917 credits
Display: 💎 20 credits
```

### Day 1, 2:00 PM: Photo Analysis

```
User uploads meal photo

Tokens: 300 input + 150 output = 450 total
Cost: (300 × 0.30 + 150 × 2.50) / 1M / 0.06 = 0.0083 credits

Balance BEFORE: 19.9917
Balance AFTER:  19.9834 credits
Display: 💎 20 credits
```

### Day 1, Evening: Daily Bonus

```
✅ Claimed daily bonus: +1 credit

Balance BEFORE: 19.9834
Balance AFTER:  20.9834 credits
Display: 💎 21 credits
```

### Day 2, 9:00 AM: Out of Credits (Hypothetically)

```
User: "Analyze my workout video"

Tokens: 500 input + 1000 output
Cost: (500 × 0.30 + 1000 × 2.50) / 1M / 0.06 = 0.0417 credits

Balance: 0.0234 credits (too low!)

❌ Not enough credits
   Show: "Buy credits to continue"
   
User taps "Buy 100 Credits"
   → Stripe payment screen
   → User enters card
   → Payment successful
   → +100 credits added
   → Balance: 100.0234 credits
   
Now can use the feature! ✅
```

---

## 💰 PART 3: PAYMENT INTEGRATION POINTS

### Where Payments Happen

```
1. Credit Purchase Screen (Settings)
   └─ User selects package
   └─ Taps "Buy Now"
   └─ Payment processor opens (Stripe/GooglePay/ApplePay)
   
2. Low Balance Warning Dialog
   └─ User tries feature without credits
   └─ Dialog shows "Buy Credits?"
   └─ Taps "Yes"
   └─ Payment processor opens
   
3. In-App Purchase (Mobile)
   └─ For iOS/Android native payments
   └─ Uses App Store / Google Play
   └─ Safer but takes 30% cut
```

### Payment Flow Diagram

```
┌────────────────────────────────────────────────────────┐
│ USER TAPS "BUY 100 CREDITS"                            │
└────────────────────────────────────────────────────────┘
                        ↓
┌────────────────────────────────────────────────────────┐
│ FRONTEND: Show Stripe Payment Sheet                    │
│ (or GooglePay / ApplePay)                              │
└────────────────────────────────────────────────────────┘
                        ↓
┌────────────────────────────────────────────────────────┐
│ USER ENTERS PAYMENT DETAILS                            │
│ (Card, Google Account, Apple Account)                  │
└────────────────────────────────────────────────────────┘
                        ↓
┌────────────────────────────────────────────────────────┐
│ PAYMENT PROCESSOR CHARGES CARD                         │
│ (Stripe / Google / Apple)                              │
└────────────────────────────────────────────────────────┘
                        ↓
        ┌───────────────┴───────────────┐
        │                               │
        ▼ SUCCESS                       ▼ FAILED
    Webhook sent to              Show error:
    backend server               "Payment failed"
        │                            │
        ▼                            ▼
    Cloud Function:            User retries or
    addCreditsAfterPayment()    cancels
        │
        ▼
    Verify payment was real
    (Check Stripe records)
        │
        ▼
    Add credits to user:
    User.credits.available += 100
    User.credits.precise += 100.0
        │
        ▼
    Send confirmation to frontend
        │
        ▼
    Frontend reloads balance
    CreditsService.load(force: true)
        │
        ▼
    UI updates: 💎 150 credits
        │
        ▼
    Show success: "100 credits added!"
```

---

## 🔄 PART 4: COMPLETE TRANSACTION EXAMPLE

### Scenario: User Buys 100 Credits for $4.99

#### Backend Cloud Function (Pseudo-code)

```dart
// Cloud Function: addCreditsAfterPayment

Future<void> addCreditsAfterPayment(
  String userId,
  int creditsToAdd,
  String paymentId,
  double amountPaid
) async {
  // 1. VERIFY PAYMENT
  // ─────────────────────────
  final stripePayment = await stripe.retrievePaymentIntent(paymentId);
  
  if (stripePayment.status != 'succeeded') {
    throw Exception('Payment not confirmed: ${stripePayment.status}');
  }
  
  // 2. VERIFY AMOUNT
  // ─────────────────────────
  const double pricePerCredit = 0.06;
  final expectedPrice = creditsToAdd * pricePerCredit;
  
  if ((amountPaid - expectedPrice).abs() > 0.01) {
    // Amount doesn't match (fraud check)
    throw Exception('Amount mismatch: paid $amountPaid, expected $expectedPrice');
  }
  
  // 3. GET CURRENT BALANCE
  // ─────────────────────────
  final userDoc = await firestore.collection('Users').doc(userId).get();
  final currentCredits = userDoc.data()?['credits']?['available'] ?? 0;
  final currentPrecise = userDoc.data()?['credits']?['precise'] ?? 0.0;
  
  // 3. ADD CREDITS
  // ─────────────────────────
  final newBalance = currentCredits + creditsToAdd;
  final newPrecise = currentPrecise + creditsToAdd.toDouble();
  
  // 4. UPDATE FIRESTORE (Atomic transaction)
  // ─────────────────────────
  await firestore.runTransaction((transaction) async {
    transaction.update(
      firestore.collection('Users').doc(userId),
      {
        'credits.available': newBalance,
        'credits.precise': newPrecise,
        'lastCreditsPurchaseAt': FieldValue.serverTimestamp(),
        'lastCreditsPurchaseAmount': creditsToAdd,
      }
    );
    
    // Log transaction for accounting
    transaction.set(
      firestore.collection('credit_purchases').doc(),
      {
        'userId': userId,
        'creditsAdded': creditsToAdd,
        'amountPaid': amountPaid,
        'paymentId': paymentId,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'completed',
      }
    );
  });
  
  // 5. SEND CONFIRMATION
  // ─────────────────────────
  return {
    'success': true,
    'creditsAdded': creditsToAdd,
    'newBalance': newBalance,
    'message': '$creditsToAdd credits added!'
  };
}
```

#### Frontend Flow

```dart
// File: lib/services/firebase_subscription_service.dart

Future<void> purchaseCredits(String packageKey) async {
  final package = CreditsService.getPackageByKey(packageKey);
  // Returns: 100 credits, $4.99
  
  try {
    // 1. Show loading
    showLoadingDialog('Processing payment...');
    
    // 2. Create Stripe Payment Intent on backend
    final paymentResult = await FirebaseFunctions.instance
        .httpsCallable('createPaymentIntent')
        .call({
          'amount': (package.priceUsd * 100).toInt(),  // 499 cents
          'currency': 'usd'
        });
    
    final clientSecret = paymentResult.data?['clientSecret'];
    
    // 3. Show Stripe payment sheet
    final paymentResponse = await Stripe.instance.confirmPaymentSheetPayment(
      clientSecret: clientSecret,
    );
    
    if (paymentResponse.status != 'succeeded') {
      showError('Payment failed');
      return;
    }
    
    // 4. Call cloud function to add credits
    final result = await FirebaseFunctions.instance
        .httpsCallable('addCreditsAfterPayment')
        .call({
          'creditsToAdd': package.credits,
          'paymentId': paymentResponse.id,
          'amountPaid': package.priceUsd
        });
    
    // 5. Reload credits from Firestore
    await CreditsService.instance.load(force: true);
    
    // 6. Show success
    showSuccess('${package.credits} credits added!');
    
    // 7. Close dialogs
    Navigator.pop(context);
    
  } catch (e) {
    showError('Purchase failed: $e');
    // Refund if needed (Stripe handles this)
  }
}
```

---

## 📈 PART 5: USAGE TRACKING & ANALYTICS

### Every Time Credits Are Used

```dart
// File: lib/services/credits_service.dart (Line 380+)

Future<void> _logUsage(num amount, String description) async {
  try {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    await FirebaseFirestore.instance.collection('credit_usage').add({
      'userId': uid,
      'amount': amount,                    // 0.0267
      'description': description,          // 'AI Chat'
      'timestamp': FieldValue.serverTimestamp(),
      'remainingCredits': _availableCredits,
      'remainingPreciseCredits': _preciseCredits,
    });
  } catch (e) {
    debugPrint('⚠️ Failed to log credit usage: $e');
  }
}
```

### What You Can Analyze

```
From credit_usage collection:
├─ Most used features
├─ Average credits per user per day
├─ Retention (users who keep buying)
├─ Churn (users who run out and never buy)
├─ Average session duration
├─ Revenue per user
└─ Popular times/days
```

---

## 🔐 PART 6: SECURITY CONSIDERATIONS

### Backend Protection

```
✅ Credits ONLY modified via Cloud Functions
✅ Payment verified with payment provider
✅ Amount validated before crediting
✅ Transaction logged for audit trail
✅ Firestore security rules block direct writes
✅ Each transaction atomic (all-or-nothing)
```

### Frontend Honesty System

```
⚠️ Frontend shows balance (not authoritative)
⚠️ Backend is source of truth
⚠️ On each app open: load(force: true)
⚠️ Offline deductions sync when online
```

### Fraud Prevention

```
✅ Stripe handles payment verification
✅ Check amount matches package
✅ Verify userId matches auth token
✅ Log all transactions
✅ Monitor for unusual patterns
✅ Rate limit credit purchases
```

---

## 💾 PART 7: DATA STRUCTURE

### Firestore User Document

```json
{
  "uid": "user123",
  "credits": {
    "available": 50,           // For display (rounded up)
    "precise": 50.4733,        // Actual precise value
    "lastUpdated": "2026-07-23T10:30:00Z",
    "dailyBonusClaimedDate": "2026-07-23"
  },
  "subscriptionTier": "free",  // or "pro", "elite"
  "createdAt": "2026-01-15T...",
  "lastLoginAt": "2026-07-23T..."
}
```

### Credit Purchase Collection

```json
{
  "userId": "user123",
  "creditsAdded": 100,
  "amountPaid": 4.99,
  "currency": "USD",
  "paymentId": "stripe_pi_xxxxx",
  "paymentMethod": "card",
  "status": "completed",       // or "pending", "failed"
  "timestamp": "2026-07-23T10:30:00Z"
}
```

### Credit Usage Collection

```json
{
  "userId": "user123",
  "amount": 0.0267,
  "description": "AI Chat",
  "timestamp": "2026-07-23T10:35:00Z",
  "remainingCredits": 50,
  "remainingPreciseCredits": 50.4733
}
```

---

## 📱 PART 8: USER EXPERIENCE FLOW

### Purchase Journey

```
1️⃣ User opens Settings
   ├─ Sees current balance: 💎 20 credits
   └─ Sees "Add Credits" button

2️⃣ User taps "Add Credits"
   └─ Credit packages displayed
      ├─ 50 cr for $2.99
      ├─ 100 cr for $4.99 ⭐
      ├─ 250 cr (+30 bonus) for $9.99
      └─ 500 cr (+75 bonus) for $17.99

3️⃣ User selects package
   └─ Taps "100 Credits - $4.99"

4️⃣ Payment sheet appears
   ├─ Card details entered
   ├─ "Pay $4.99" button

5️⃣ Payment processing
   └─ Loading screen shown

6️⃣ Success! ✅
   ├─ Balance updates: 💎 120 credits
   ├─ Receipt shown
   └─ Toast: "100 credits added!"
```

### Usage Journey

```
1️⃣ User types chat message
   └─ Taps send

2️⃣ System checks credits
   ├─ Have 50 credits
   ├─ Need 0.03 credits
   └─ ✅ Allowed

3️⃣ Message sent to AI
   └─ Response generated

4️⃣ Credits deducted
   ├─ UI updates
   └─ 💎 49 credits (displayed)

5️⃣ Response displayed
   └─ User reads AI reply
```

### Low Balance Warning

```
1️⃣ User tries to use AI feature
   └─ System: "Only 0.2 credits left"

2️⃣ Low balance dialog shown
   ├─ "Not enough credits"
   ├─ "Buy more?" button
   └─ "Later" button

3️⃣ User taps "Buy more?"
   └─ Goes to credit purchase screen
   └─ Back to Purchase Journey (step 2)
```

---

## 🎯 SUMMARY TABLE

| Phase | Action | Cost | Example |
|-------|--------|------|---------|
| **PAYMENT** | User buys 100 cr | $4.99 | Stripe charges card |
| | Backend receives | 100 cr | Cloud Function adds to DB |
| | Frontend reloads | | Shows new balance |
| **USAGE** | User sends message | API call | Gemini returns tokens |
| | Calculate cost | 0.0267 cr | (234 in × 0.30 + 612 out × 2.50) / 1M / 0.06 |
| | Deduct credits | | Balance: 99.9733 |
| | Update UI | | Display: 💎 100 |
| | Log transaction | | Saved in Firestore |

---

## 🔗 Key Code Files

| File | Purpose | Lines |
|------|---------|-------|
| `credits_service.dart` | Load/use/track credits | 78-380 |
| `firebase_ai_service.dart` | Calculate API costs | 1031-1046, 1173 |
| `floating_ai_assistant.dart` | Show balance, check before use | 2072, 3220 |
| `firebase_subscription_service.dart` | Handle purchases | TBD |
| Cloud Functions (Backend) | Add credits, deduct credits | `deductCredits()`, `addCreditsAfterPayment()` |
| Firestore Rules | Secure database | Block direct writes to credits |

