# Firestore Database Setup Guide

## Why You Need This
Currently, all subscription and payment data is stored locally on the user's device. This means:
- ❌ You can't see who paid for what
- ❌ Users lose purchases if they reinstall
- ❌ No server-side verificationl the ai credits reduing according to usage

- ❌ Users could manipulate local data

With Firestore, you get:
- ✅ Track all payments and subscriptions
- ✅ Sync across devices
- ✅ Server-side verification
- ✅ Analytics and reporting
- ✅ Customer support capabilities

## Step 1: Enable Firestore in Firebase Console

1. Go to https://console.firebase.google.com/
2. Select your project: `vervestride-app`
3. Click "Firestore Database" in the left menu
4. Click "Create database"
5. Choose "Start in production mode" (we'll add security rules)
6. Select a location (choose closest to your users, e.g., `asia-south1` for India)
7. Click "Enable"

## Step 2: Firestore Database Schema

### Collection: `users/{userId}`
Stores user profile and subscription status.

```
{
  email: string
  displayName: string
  createdAt: timestamp
  
  // Subscription info
  subscriptionTier: string  // "free", "pro", "elite", "lifetime", "remove_ads"
  subscriptionPlanKey: string | null  // e.g., "pro_monthly", "elite_yearly"
  subscriptionExpiresAt: timestamp | null
  subscriptionActivatedAt: timestamp | null
  
  // AI Credits
  aiCredits: number  // Available credits
  totalCreditsEarned: number  // Lifetime total
  totalCreditsSpent: number  // Lifetime spent
  
  // Stats
  lastActiveAt: timestamp
  totalPayments: number  // Count of successful payments
  lifetimeValue: number  // Total amount paid in INR
}
```

### Collection: `payments/{paymentId}`
Tracks every payment transaction.

```
{
  userId: string
  paymentId: string  // Razorpay payment ID
  orderId: string  // Razorpay order ID
  
  // What was purchased
  type: string  // "subscription" or "credits"
  planKey: string | null  // For subscriptions
  packageKey: string | null  // For credits
  
  // Amounts
  amountInr: number  // Amount in INR (what Razorpay charged)
  amountUsd: number  // Display amount in USD
  currency: string  // "INR"
  
  // Credits (if applicable)
  creditsAdded: number | null
  
  // Status
  status: string  // "success", "failed", "pending"
  
  // Timestamps
  createdAt: timestamp
  completedAt: timestamp | null
  
  // Razorpay response
  razorpaySignature: string | null
  razorpayResponse: map | null
}
```

### Collection: `subscriptions/{subscriptionId}`
Tracks subscription periods (for recurring plans).

```
{
  userId: string
  planKey: string  // e.g., "pro_monthly"
  tier: string  // "pro", "elite"
  period: string  // "Monthly", "Yearly", etc.
  
  // Dates
  startDate: timestamp
  endDate: timestamp
  activatedAt: timestamp
  
  // Payment
  paymentId: string  // Reference to payments collection
  amountInr: number
  
  // Status
  status: string  // "active", "expired", "cancelled"
  autoRenew: boolean  // For future subscription management
}
```

### Collection: `credit_transactions/{transactionId}`
Tracks every credit addition and deduction.

```
{
  userId: string
  
  // Transaction details
  type: string  // "purchase", "earned", "spent", "refund"
  amount: number  // Positive for additions, negative for deductions
  
  // Context
  reason: string  // "meal_analysis", "chat_message", "voice_command", "purchase", "signup_bonus"
  paymentId: string | null  // If purchased
  
  // Balance tracking
  balanceBefore: number
  balanceAfter: number
  
  // Timestamp
  createdAt: timestamp
}
```

## Step 3: Security Rules

Go to Firestore → Rules tab and add:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function
    function isSignedIn() {
      return request.auth != null;
    }
    
    function isOwner(userId) {
      return isSignedIn() && request.auth.uid == userId;
    }
    
    // Users can read/write their own data
    match /users/{userId} {
      allow read: if isOwner(userId);
      allow write: if isOwner(userId);
    }
    
    // Users can read their own payments
    match /payments/{paymentId} {
      allow read: if isSignedIn() && resource.data.userId == request.auth.uid;
      allow write: if false;  // Only backend can write
    }
    
    // Users can read their own subscriptions
    match /subscriptions/{subscriptionId} {
      allow read: if isSignedIn() && resource.data.userId == request.auth.uid;
      allow write: if false;  // Only backend can write
    }
    
    // Users can read their own credit transactions
    match /credit_transactions/{transactionId} {
      allow read: if isSignedIn() && resource.data.userId == request.auth.uid;
      allow write: if false;  // Only backend can write
    }
  }
}
```

## Step 4: Update Flutter App to Use Firestore

You'll need to modify these files:

### `lib/services/user_subscription_service.dart`
- Load subscription from Firestore instead of SharedPreferences
- Sync local state with Firestore
- Listen to real-time updates

### `lib/services/credits_service.dart`
- Load credits from Firestore
- Sync credit balance
- Record transactions

### `lib/services/payment_service.dart`
- After successful payment, write to Firestore
- Create payment record
- Update user subscription/credits

## Step 5: Migration Strategy

Since you already have users with local data:

1. On app startup, check if user has local subscription data
2. If yes and Firestore is empty, migrate local → Firestore
3. If Firestore has data, use that (server is source of truth)
4. Keep local cache for offline access

## Step 6: Admin Dashboard (Optional)

You can use Firebase Console to:
- View all users and their subscriptions
- See payment history
- Track revenue
- Handle refunds
- Customer support

Or build a custom admin panel using Firebase Admin SDK.

## Next Steps

1. Enable Firestore in Firebase Console (Step 1)
2. Add security rules (Step 3)
3. I'll update the Flutter code to integrate Firestore (Step 4)

Ready to proceed? Let me know when you've enabled Firestore and I'll update the code.
