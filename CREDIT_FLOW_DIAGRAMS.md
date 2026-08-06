# Credit System - Visual Flows & Diagrams

## 1. Complete Message Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         USER SENDS MESSAGE                                   │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
         ┌──────────────────────────────────────────────────┐
         │ floating_ai_assistant.dart (Line 3200+)          │
         │                                                   │
         │ User types: "Create a meal plan"                │
         │ _sendMessage() called                            │
         └──────────────────────────────────────────────────┘
                                    │
                                    ▼
         ┌──────────────────────────────────────────────────┐
         │ STEP 1: CHECK CREDITS                            │
         │                                                   │
         │ CreditsService.instance.preciseCredits >= 1.0?   │
         │                                                   │
         │ YES ✅ → Continue                               │
         │ NO ❌ → Show error, return                      │
         └──────────────────────────────────────────────────┘
                                    │
                                    ▼
         ┌──────────────────────────────────────────────────┐
         │ STEP 2: SEND TO GEMINI API                       │
         │                                                   │
         │ firebase_ai_service.dart (Line 1020+)           │
         │                                                   │
         │ geminiModel.generateContent(                      │
         │   content=[                                       │
         │     Content.text("Create a meal plan"),           │
         │     // + system prompt + context                │
         │   ]                                               │
         │ )                                                 │
         └──────────────────────────────────────────────────┘
                                    │
                      ┌─────────────┴─────────────┐
                      │                           │
                      ▼                           ▼
         ┌──────────────────────┐  ┌──────────────────────┐
         │ SINGLE RESPONSE      │  │ STREAMING RESPONSE   │
         │ (Poll-based)         │  │ (Word-by-word)       │
         │                      │  │                      │
         │ Get all at once      │  │ Receive chunks       │
         │ Then calculate cost  │  │ in real-time         │
         └──────────────────────┘  └──────────────────────┘
                      │                           │
                      └─────────────┬─────────────┘
                                    ▼
         ┌──────────────────────────────────────────────────┐
         │ STEP 3: RECEIVE RESPONSE                         │
         │                                                   │
         │ response = {                                      │
         │   "text": "Here's a meal plan...",               │
         │   "usageMetadata": {                             │
         │     "promptTokenCount": 234,       ← INPUT        │
         │     "candidatesTokenCount": 612    ← OUTPUT       │
         │   }                                               │
         │ }                                                 │
         └──────────────────────────────────────────────────┘
                                    │
                                    ▼
         ┌──────────────────────────────────────────────────┐
         │ STEP 4: CALCULATE CREDIT COST                    │
         │                                                   │
         │ firebase_ai_service.dart (Line 1031-1046)       │
         │                                                   │
         │ Input Tokens:  234                                │
         │ Output Tokens: 612                                │
         │                                                   │
         │ Model = Gemini 2.5 Flash                         │
         │   Input Cost:  $0.30 per 1M                      │
         │   Output Cost: $2.50 per 1M                      │
         │                                                   │
         │ API Cost USD = (234 × 0.30 + 612 × 2.50) / 1M   │
         │             = (70.2 + 1530) / 1,000,000          │
         │             = $0.001602 USD                       │
         │                                                   │
         │ Credits = $0.001602 / $0.06 = 0.0267 credits    │
         └──────────────────────────────────────────────────┘
                                    │
                                    ▼
         ┌──────────────────────────────────────────────────┐
         │ STEP 5: DEDUCT CREDITS                           │
         │                                                   │
         │ credits_service.dart (Line 190+)                │
         │                                                   │
         │ CreditsService.instance.usePreciseCredits(       │
         │   0.0267,                                        │
         │   description: 'AI Chat'                         │
         │ )                                                 │
         │                                                   │
         │ Is user online?                                  │
         │   YES → Call Cloud Function                      │
         │   NO → Deduct locally                            │
         └──────────────────────────────────────────────────┘
                                    │
                      ┌─────────────┴─────────────┐
                      │                           │
                      ▼                           ▼
         ┌──────────────────────┐  ┌──────────────────────┐
         │ ONLINE PATH          │  │ OFFLINE PATH         │
         │                      │  │                      │
         │ Call Cloud Function: │  │ _preciseCredits -= 0.0267
         │ deductCredits()      │  │ _availableCredits = ceil(...)
         │                      │  │ _saveLocal()         │
         │ Backend (Firestore): │  │                      │
         │ User.credits.precise │  │ (Synced when online) │
         │   = 50.5 - 0.0267    │  │                      │
         │   = 50.4733          │  │                      │
         │                      │  │                      │
         │ User.credits.avail   │  │                      │
         │   = ceil(50.4733)    │  │                      │
         │   = 51               │  │                      │
         └──────────────────────┘  └──────────────────────┘
                      │                           │
                      └─────────────┬─────────────┘
                                    ▼
         ┌──────────────────────────────────────────────────┐
         │ STEP 6: UPDATE UI                                │
         │                                                   │
         │ notifyListeners()                                 │
         │ setState() → UI rebuilds                         │
         │                                                   │
         │ Toolbar shows:                                    │
         │ 💎 50 credits  (was 50, displayed: ceil(50.47))  │
         └──────────────────────────────────────────────────┘
                                    │
                                    ▼
         ┌──────────────────────────────────────────────────┐
         │ STEP 7: LOG USAGE (ANALYTICS)                    │
         │                                                   │
         │ Firestore collection('credit_usage').add({        │
         │   userId: 'user123',                             │
         │   amount: 0.0267,                                │
         │   description: 'AI Chat',                        │
         │   timestamp: now(),                              │
         │   remainingCredits: 50.4733                      │
         │ })                                                │
         └──────────────────────────────────────────────────┘
                                    │
                                    ▼
                         ✅ COMPLETE
```

---

## 2. Token to Credit Conversion

```
┌────────────────────────────────────────────────────────────────────────┐
│                    HOW GEMINI TOKENS BECOME CREDITS                     │
└────────────────────────────────────────────────────────────────────────┘

INPUT TOKENS (Words user sends)                OUTPUT TOKENS (AI's response)
         │                                              │
         │ 234 tokens                                  │ 612 tokens
         │                                              │
         ├─ User message: 50 tokens                    ├─ "Here's a meal plan"
         ├─ Context: 100 tokens                        ├─ Plan details: 400
         ├─ History: 84 tokens                         └─ Recommendations: 212
         │
         ▼
    Pricing: $0.30 per 1M         Pricing: $2.50 per 1M
         │                                  │
         ▼                                  ▼
    234 × 0.30 / 1M = $0.00007020  612 × 2.50 / 1M = $0.00153000
         │                                  │
         └──────────────┬──────────────────┘
                        ▼
                TOTAL API COST
                $0.00160020 USD
                        │
         ┌──────────────────────────────┐
         │ Divide by Credit Price ($0.06)│
         └──────────────────────────────┘
                        │
                        ▼
                YOUR CREDIT PRICE
                0.0267 Credits
                        │
         ┌──────────────────────────────┐
         │ Deduct from User's Balance    │
         └──────────────────────────────┘
                        │
                        ▼
                    DONE ✅
```

---

## 3. Real-Time Streaming Flow

```
User sends message "Create workout plan"
                │
                ▼
    Start receiving response in chunks
                │
    ┌───────────┴───────────┬───────────┬───────────┐
    ▼                       ▼           ▼           ▼
 CHUNK 1              CHUNK 2       CHUNK 3      CHUNK 4
 "Here's"             "a great"     "workout"    "plan..."
                                                      │
    ┌───────────────────────────────────────────────┤
    ▼                                               │
Show on screen immediately                          │
(User sees text appearing)                          │
                                                    ▼
                                        Stream completed
                                        │
                                        ▼
                        Total Tokens Collected:
                        Input: 200
                        Output: 1200
                                        │
                                        ▼
                        Calculate final cost:
                        (200×0.30 + 1200×2.50)/1M/0.06
                        = 0.067 credits
                                        │
                                        ▼
                        Deduct 0.067 from balance
                                        │
                                        ▼
                        Show response (already on screen!)
                        Show credit deduction in toolbar
```

---

## 4. Credit Deduction Lifecycle

```
USER BALANCE OVER TIME

Start: 100.0000 credits
                                        ✅ Add 50-credit package
                                        150.0000 credits
                                                │
                                                ▼
Chat message 1 (-0.0083)  →  149.9917
                                │
Chat message 2 (-0.0050)  →  149.9867
                                │
Photo analysis (-0.0156)  →  149.9711
                                │
Chat message 3 (-0.0200)  →  149.9511
                                │
        ✅ Daily bonus (+1)  →  150.9511
                                │
Video analysis (-0.1500)  →  150.8011
                                │
Chat message 4 (-0.0312)  →  150.7699
                                │
Display (rounded up):
    149 credits
    150 credits
    150 credits
    150 credits
    151 credits
    150 credits
    150 credits
```

---

## 5. Error & Refund Flow

```
USER REQUESTS VIDEO GENERATION (50 credits)

Start Balance: 100 credits
      │
      ▼
Check balance: 100 >= 50? YES ✅
      │
      ▼
┌─────────────────────────────────┐
│ DEDUCT 50 CREDITS               │
│ Balance: 100 - 50 = 50 credits │
└─────────────────────────────────┘
      │
      ▼
Start video generation...
      │
      ├─ Video generation failed ❌
      │  (API error or timeout)
      │
      ▼
┌─────────────────────────────────┐
│ REFUND 50 CREDITS               │
│ Balance: 50 + 50 = 100 credits │
└─────────────────────────────────┘
      │
      ▼
Show error: "Video generation failed"
      │
      ▼
Final Balance: 100 credits (restored!)
```

---

## 6. Offline vs Online Modes

```
┌──────────────────────────────────────────────────────────┐
│                    OFFLINE MODE                           │
└──────────────────────────────────────────────────────────┘

User sends message while offline
                │
                ▼
    NOT connected to Firestore
                │
                ▼
    Deduct from LOCAL storage only
    CreditsService._preciseCredits -= 0.05
                │
                ▼
    Save to local device storage
    LocalStorageService.saveAppSettings()
                │
                ▼
    No Cloud Function call needed
    No Firestore update
                │
                ▼
    Balance updates immediately on device


┌──────────────────────────────────────────────────────────┐
│              COMES BACK ONLINE                           │
└──────────────────────────────────────────────────────────┘

App reconnects to internet
                │
                ▼
    Call Firestore to get true balance
    CreditsService.load(force: true)
                │
                ▼
    Check Firestore against offline changes
                │
        ┌───────┴───────┐
        │               │
        ▼               ▼
    OPTION A:      OPTION B:
    Same value     Different value
        │               │
        ▼               ▼
    Keep local     Use Firestore value
    values        (server is source of truth)
        │               │
        └───────┬───────┘
                ▼
        Update UI with accurate balance
```

---

## 7. Credit Packages & Value

```
CREDIT PACKAGES

STARTER PACK (50 credits = $2.99)
├─ Can chat ~500 times
├─ Or analyze 25 meal photos
└─ Or watch 10 video analyses
    🏷️ $/credit: $0.0598

BASIC PACK (100 credits = $4.99)
├─ Can chat ~1000 times
├─ Or analyze 50 meal photos
└─ Or watch 20 video analyses
    🏷️ $/credit: $0.0499

VALUE PACK (280 total, $9.99)
├─ +30 BONUS credits
├─ Can chat ~2800 times
├─ Or analyze 140 meal photos
└─ Or watch 56 video analyses
    🏷️ $/credit: $0.0357 ⭐ Best value

POWER PACK (575 total, $17.99)
├─ +75 BONUS credits
├─ Can chat ~5750 times
├─ Or analyze 287 meal photos
└─ Or watch 115 video analyses
    🏷️ $/credit: $0.0313 ⭐⭐ Best value
```

---

## 8. Feature Cost Breakdown

```
ESTIMATED USAGE WITH 100 CREDITS

Text & Chat:
├─ 1000+ chat messages  (0.1 cr each avg)
├─ 100 meal plans       (1.0 cr each)
└─ 500 quick questions  (0.2 cr each)

Photo Analysis:
├─ 500 meal photos      (0.2 cr each)
├─ 300 form checks      (0.3 cr each)
└─ 200 progress photos  (0.5 cr each)

Video Analysis:
├─ 100 workout videos   (1.0 cr each)
├─ 50 form checks       (2.0 cr each)
└─ 25 pose detections   (4.0 cr each)

Live Features:
└─ 20 coaching sessions (5 cr each)
```

---

## 9. Token Estimation

```
ROUGH TOKEN COUNTS (For estimation)

📝 Text:
   ~4 characters = 1 token
   
   "How do I get bigger arms?" = 6 words ≈ 7 tokens
   
   Average message = 50-200 tokens
   Average response = 200-1000 tokens

📊 Image:
   Any image = ~258 tokens (fixed)
   + text tokens
   
   "Analyze this image" + image = ~265 tokens input

📹 Video:
   NOT directly supported by Gemini
   Must extract frames + analyze

💬 System Prompt:
   ~500 tokens (added to every message)

🧠 Conversation History:
   Last 5 messages ≈ 500-1000 tokens
   (Depends on message length)
```

---

## 10. Daily Usage Pattern

```
TYPICAL USER DAY (100 credits)

9:00 AM: 3 chat messages
├─ Tokens: 100 in + 300 out each
├─ Cost per message: 0.0083 credits
└─ Total: -0.025 credits
   Balance: 99.975

12:00 PM: Meal photo analysis
├─ Tokens: 300 in + 200 out
├─ Cost: 0.0083 credits
└─ Balance: 99.967

3:00 PM: 2 more chats
├─ Cost: -0.016 credits
└─ Balance: 99.951

6:00 PM: Workout video analysis
├─ Tokens: 500 in + 800 out
├─ Cost: 0.0278 credits
└─ Balance: 99.923

✅ Daily Bonus: +1 credit
Final Balance: 100.923

TOTAL USAGE: -0.077 credits
= Only $0.0046 spent in a whole day! 🎉
```

---

## Summary Table

| Phase | Action | File | Line |
|-------|--------|------|------|
| 1️⃣ Send | User types message | floating_ai_assistant.dart | 3200+ |
| 2️⃣ Check | Verify available credits | firebase_ai_service.dart | 1030 |
| 3️⃣ Call | Send to Gemini API | firebase_ai_service.dart | 1020 |
| 4️⃣ Receive | Get response + tokens | firebase_ai_service.dart | 1031 |
| 5️⃣ Calculate | Convert tokens to credits | firebase_ai_service.dart | 1046 |
| 6️⃣ Deduct | Update balance | credits_service.dart | 210 |
| 7️⃣ Save | Store locally/cloud | credits_service.dart | 240 |
| 8️⃣ Notify | Update UI | credits_service.dart | 241 |

