# Firebase Backend Architecture

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                          USER DEVICE                                 │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────┐   │
│  │              Flutter App (VerveStride)                      │   │
│  │                                                              │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │   │
│  │  │   UI Layer   │  │   Services   │  │ Local Cache  │    │   │
│  │  │              │  │              │  │              │    │   │
│  │  │ • Premium    │  │ • Payment    │  │ • Isar DB    │    │   │
│  │  │   Screen     │  │ • Firebase   │  │ • Local      │    │   │
│  │  │ • AI Chat    │  │   Subscription│  │   Storage    │    │   │
│  │  │ • Meal       │  │ • Credits    │  │              │    │   │
│  │  │   Analysis   │  │ • User Sub   │  │              │    │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘    │   │
│  │         │                  │                  │            │   │
│  └─────────┼──────────────────┼──────────────────┼────────────┘   │
│            │                  │                  │                 │
└────────────┼──────────────────┼──────────────────┼─────────────────┘
             │                  │                  │
             ▼                  ▼                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        INTERNET / CLOUD                              │
└─────────────────────────────────────────────────────────────────────┘
             │                  │                  │
             ▼                  ▼                  ▼
┌─────────────────────┐  ┌──────────────────────────────────────────┐
│   Razorpay API      │  │         Firebase Cloud                    │
│                     │  │                                            │
│  • Payment Gateway  │  │  ┌──────────────────────────────────┐   │
│  • Order Creation   │  │  │    Cloud Functions (Node.js)     │   │
│  • Payment Verify   │  │  │                                   │   │
│  • Webhooks         │  │  │  • activateSubscription()        │   │
│                     │  │  │  • addCredits()                  │   │
│  ┌───────────────┐ │  │  │  • deductCredits()               │   │
│  │ Test Mode     │ │  │  │  • refundCredits()               │   │
│  │ rzp_test_xxx  │ │  │  │  • getSubscriptionStatus()       │   │
│  └───────────────┘ │  │  │  • razorpayWebhook()             │   │
│  ┌───────────────┐ │  │  │                                   │   │
│  │ Live Mode     │ │  │  │  ┌─────────────────────────────┐ │   │
│  │ rzp_live_xxx  │ │  │  │  │  Razorpay SDK Integration   │ │   │
│  └───────────────┘ │  │  │  │  • Payment verification     │ │   │
│                     │  │  │  │  • Signature validation     │ │   │
└─────────────────────┘  │  │  └─────────────────────────────┘ │   │
             │            │  │                                   │   │
             │            │  └───────────────┬───────────────────┘   │
             │            │                  │                       │
             │            │                  ▼                       │
             │            │  ┌──────────────────────────────────┐   │
             │            │  │    Firestore Database            │   │
             │            │  │                                   │   │
             │            │  │  Collections:                    │   │
             │            │  │  ┌─────────────────────────────┐ │   │
             │            │  │  │ users/{userId}              │ │   │
             │            │  │  │  ├─ subscription            │ │   │
             │            │  │  │  └─ credits                 │ │   │
             │            │  │  └─────────────────────────────┘ │   │
             │            │  │  ┌─────────────────────────────┐ │   │
             │            │  │  │ transactions/{txnId}        │ │   │
             │            │  │  │  └─ payment logs            │ │   │
             │            │  │  └─────────────────────────────┘ │   │
             │            │  │  ┌─────────────────────────────┐ │   │
             │            │  │  │ payments/{paymentId}        │ │   │
             │            │  │  │  └─ razorpay data           │ │   │
             │            │  │  └─────────────────────────────┘ │   │
             │            │  │  ┌─────────────────────────────┐ │   │
             │            │  │  │ credit_usage/{usageId}      │ │   │
             │            │  │  │  └─ usage logs              │ │   │
             │            │  │  └─────────────────────────────┘ │   │
             │            │  │                                   │   │
             │            │  │  Security Rules:                 │   │
             │            │  │  • Users read own data only      │   │
             │            │  │  • Functions write only          │   │
             │            │  │  • Admin role for management     │   │
             │            │  └──────────────────────────────────┘   │
             │            │                                          │
             │            │  ┌──────────────────────────────────┐   │
             │            │  │    Firebase Auth                 │   │
             │            │  │  • User authentication           │   │
             │            │  │  • JWT tokens                    │   │
             │            │  │  • Session management            │   │
             │            │  └──────────────────────────────────┘   │
             │            │                                          │
             │            │  ┌──────────────────────────────────┐   │
             │            │  │    Firebase Crashlytics          │   │
             │            │  │  • Error tracking                │   │
             │            │  │  • Function logs                 │   │
             │            │  └──────────────────────────────────┘   │
             │            └──────────────────────────────────────────┘
             │
             └──────────────────────────────────────────────────────────┐
                                                                         │
                                                                         ▼
                                                              ┌──────────────────┐
                                                              │  Admin Dashboard │
                                                              │  (Firebase       │
                                                              │   Console)       │
                                                              └──────────────────┘
```

## 📊 Data Flow Diagrams

### 1. Subscription Purchase Flow

```
User                    Flutter App              Razorpay           Cloud Function         Firestore
 │                          │                        │                    │                    │
 │  1. Click "Buy Pro"      │                        │                    │                    │
 ├─────────────────────────>│                        │                    │                    │
 │                          │  2. Open Razorpay      │                    │                    │
 │                          ├───────────────────────>│                    │                    │
 │                          │                        │                    │                    │
 │  3. Enter payment details│                        │                    │                    │
 ├──────────────────────────┼───────────────────────>│                    │                    │
 │                          │                        │                    │                    │
 │                          │  4. Payment success    │                    │                    │
 │                          │<───────────────────────┤                    │                    │
 │                          │                        │                    │                    │
 │                          │  5. Call activateSubscription(paymentId)    │                    │
 │                          ├────────────────────────┼───────────────────>│                    │
 │                          │                        │                    │                    │
 │                          │                        │  6. Verify payment │                    │
 │                          │                        │<───────────────────┤                    │
 │                          │                        │                    │                    │
 │                          │                        │  7. Payment valid  │                    │
 │                          │                        ├───────────────────>│                    │
 │                          │                        │                    │                    │
 │                          │                        │                    │  8. Update user    │
 │                          │                        │                    ├───────────────────>│
 │                          │                        │                    │                    │
 │                          │                        │                    │  9. Log transaction│
 │                          │                        │                    ├───────────────────>│
 │                          │                        │                    │                    │
 │                          │  10. Success response  │                    │                    │
 │                          │<───────────────────────┼────────────────────┤                    │
 │                          │                        │                    │                    │
 │  11. Show success        │                        │                    │                    │
 │<─────────────────────────┤                        │                    │                    │
 │                          │                        │                    │                    │
 │                          │  12. Real-time sync    │                    │                    │
 │                          │<───────────────────────┼────────────────────┼────────────────────┤
 │                          │                        │                    │                    │
```

### 2. Credits Usage Flow (AI Feature)

```
User              Flutter App         Cloud Function       Firestore         AI Service
 │                    │                      │                 │                 │
 │  1. Use AI         │                      │                 │                 │
 ├───────────────────>│                      │                 │                 │
 │                    │                      │                 │                 │
 │                    │  2. Check Elite?     │                 │                 │
 │                    ├──────────────────────┼─────────────────>│                 │
 │                    │                      │                 │                 │
 │                    │  3. Not Elite        │                 │                 │
 │                    │<─────────────────────┼─────────────────┤                 │
 │                    │                      │                 │                 │
 │                    │  4. Deduct credits   │                 │                 │
 │                    ├─────────────────────>│                 │                 │
 │                    │                      │                 │                 │
 │                    │                      │  5. Atomic      │                 │
 │                    │                      │     deduction   │                 │
 │                    │                      ├────────────────>│                 │
 │                    │                      │                 │                 │
 │                    │  6. Credits deducted │                 │                 │
 │                    │<─────────────────────┤                 │                 │
 │                    │                      │                 │                 │
 │                    │  7. Call AI          │                 │                 │
 │                    ├──────────────────────┼─────────────────┼────────────────>│
 │                    │                      │                 │                 │
 │                    │  8. AI response      │                 │                 │
 │                    │<─────────────────────┼─────────────────┼─────────────────┤
 │                    │                      │                 │                 │
 │  9. Show result    │                      │                 │                 │
 │<───────────────────┤                      │                 │                 │
 │                    │                      │                 │                 │
 │                    │  10. Log usage       │                 │                 │
 │                    ├─────────────────────>│                 │                 │
 │                    │                      ├────────────────>│                 │
 │                    │                      │                 │                 │
```

### 3. Credits Refund Flow (AI Failure)

```
User              Flutter App         Cloud Function       Firestore
 │                    │                      │                 │
 │  1. AI call fails  │                      │                 │
 │<───────────────────┤                      │                 │
 │                    │                      │                 │
 │                    │  2. Refund credits   │                 │
 │                    ├─────────────────────>│                 │
 │                    │                      │                 │
 │                    │                      │  3. Atomic      │
 │                    │                      │     refund      │
 │                    │                      ├────────────────>│
 │                    │                      │                 │
 │                    │  4. Credits refunded │                 │
 │                    │<─────────────────────┤                 │
 │                    │                      │                 │
 │  5. Show error +   │                      │                 │
 │     refund notice  │                      │                 │
 │<───────────────────┤                      │                 │
 │                    │                      │                 │
```

## 🔐 Security Layers

```
┌─────────────────────────────────────────────────────────────┐
│                     Security Layers                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Layer 1: Firebase Authentication                           │
│  ├─ JWT tokens                                              │
│  ├─ Session management                                      │
│  └─ User identity verification                              │
│                                                              │
│  Layer 2: Firestore Security Rules                          │
│  ├─ Users can only read own data                            │
│  ├─ Only Cloud Functions can write                          │
│  └─ Admin role for management                               │
│                                                              │
│  Layer 3: Cloud Functions Validation                        │
│  ├─ Payment verification with Razorpay                      │
│  ├─ Atomic transactions (prevent race conditions)           │
│  └─ Business logic enforcement                              │
│                                                              │
│  Layer 4: Razorpay Security                                 │
│  ├─ Payment signature verification                          │
│  ├─ Webhook signature validation                            │
│  └─ PCI DSS compliance                                      │
│                                                              │
│  Layer 5: Audit Trail                                       │
│  ├─ All transactions logged                                 │
│  ├─ Credit usage tracked                                    │
│  └─ Payment history maintained                              │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## 📈 Scalability

```
┌─────────────────────────────────────────────────────────────┐
│                    Scalability Features                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Auto-Scaling Cloud Functions                               │
│  ├─ Scales from 0 to thousands of instances                 │
│  ├─ Pay only for actual usage                               │
│  └─ No server management needed                             │
│                                                              │
│  Firestore Auto-Scaling                                     │
│  ├─ Handles millions of concurrent connections              │
│  ├─ Automatic sharding                                      │
│  └─ Global distribution                                     │
│                                                              │
│  Caching Strategy                                            │
│  ├─ Local cache (Isar + LocalStorage)                       │
│  ├─ Firestore offline persistence                           │
│  └─ Real-time sync when online                              │
│                                                              │
│  Load Distribution                                           │
│  ├─ Firebase CDN for static assets                          │
│  ├─ Regional Cloud Functions                                │
│  └─ Firestore multi-region replication                      │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

**This architecture supports:**
- ✅ Millions of users
- ✅ Thousands of transactions per second
- ✅ Real-time sync
- ✅ Offline support
- ✅ Global distribution
- ✅ 99.95% uptime SLA
