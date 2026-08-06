# Firebase Backend - Quick Start 🚀

## 5-Minute Setup

### 1. Install & Login
```bash
npm install -g firebase-tools
firebase login
```

### 2. Initialize Project
```bash
firebase init
# Select: Firestore, Functions, Hosting
# Use existing project: vervestride
```

### 3. Install Dependencies
```bash
cd functions
npm install
```

### 4. Configure Razorpay Keys
```bash
firebase functions:config:set \
  razorpay.mode="test" \
  razorpay.test_key_id="rzp_test_xxxxx" \
  razorpay.test_key_secret="xxxxx"
```

### 5. Deploy Everything
```bash
firebase deploy
```

**Done!** Your backend is live. ✅

---

## Files Created

```
vervestride/
├── firestore.rules              # Security rules
├── firestore.indexes.json       # Database indexes
├── firebase.json                # Firebase config
├── functions/
│   ├── package.json            # Dependencies
│   ├── index.js                # Cloud Functions
│   └── .env.example            # Environment template
└── lib/services/
    └── firebase_subscription_service.dart  # Flutter integration
```

---

## Cloud Functions Available

| Function | Purpose | Called From |
|----------|---------|-------------|
| `activateSubscription` | Activate plan after payment | Payment success |
| `addCredits` | Add credits after payment | Payment success |
| `deductCredits` | Deduct credits for AI usage | Before AI call |
| `refundCredits` | Refund credits on failure | After AI failure |
| `getSubscriptionStatus` | Get user subscription | App startup |
| `razorpayWebhook` | Handle payment webhooks | Razorpay server |

---

## Usage in Flutter

### Activate Subscription
```dart
final result = await FirebaseSubscriptionService.instance.activateSubscription(
  paymentId: 'pay_xxxxx',
  planKey: 'pro_monthly',
);
```

### Add Credits
```dart
final result = await FirebaseSubscriptionService.instance.addCredits(
  paymentId: 'pay_xxxxx',
  packageKey: 'credits_100',
  credits: 100,
);
```

### Deduct Credits (Server-Side)
```dart
final result = await FirebaseSubscriptionService.instance.deductCredits(
  amount: 2,
  description: 'Meal analysis',
);
```

### Refund Credits
```dart
final result = await FirebaseSubscriptionService.instance.refundCredits(
  amount: 2,
  reason: 'AI call failed',
);
```

---

## Testing

### Local Testing
```bash
firebase emulators:start
```

### View Logs
```bash
firebase functions:log
```

### Check Firestore
https://console.firebase.google.com → Firestore

---

## Cost (Estimated)

| Users | Functions/day | Firestore Ops | Cost/month |
|-------|---------------|---------------|------------|
| 1K    | 10K           | 7K            | **Free** |
| 10K   | 100K          | 70K           | ~$25-50 |
| 100K  | 1M            | 700K          | ~$200-400 |

---

## Security

✅ Users can only read their own data
✅ Only Cloud Functions can write subscriptions/credits
✅ Payment verification server-side
✅ Transaction logging for audit trail

---

## Next Steps

1. Deploy: `firebase deploy`
2. Test with Razorpay test mode
3. Monitor logs: `firebase functions:log`
4. Go live: Switch to Razorpay live keys

---

## Need Help?

- 📖 Full guide: `FIREBASE_SETUP_GUIDE.md`
- 🔧 Troubleshooting: Check function logs
- 💬 Questions: Ask me!

**You're ready to go! 🎉**
