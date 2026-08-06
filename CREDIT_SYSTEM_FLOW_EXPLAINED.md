# VerveStride Credit System - Complete Flow & Calculations

## 📊 Quick Overview

```
User Action → API Call → Gemini Charges → Calculate Cost → Deduct Credits
    ↓           ↓            ↓              ↓                  ↓
Chat      Tokens Count   $0.30-$10/1M   Convert to Credits   Balance Updated
```

---

## 1️⃣ CREDIT PACKAGES (What Users Buy)

| Package | Credits | Price USD | Price INR | Bonus | $/Credit |
|---------|---------|-----------|-----------|-------|----------|
| Starter | 50 | $2.99 | ₹249 | None | **$0.0598** |
| Basic | 100 | $4.99 | ₹415 | None | **$0.0499** |
| Value | 250 | $9.99 | ₹830 | +30 (280 total) | **$0.0357** |
| Power | 500 | $17.99 | ₹1,499 | +75 (575 total) | **$0.0313** |

**Your Credit Price:** **$0.06 per credit** (baseline for calculations)

---

## 2️⃣ GEMINI API ACTUAL PRICING

### Gemini 2.5 Flash (Most Used - Fastest & Cheapest)
```
Input:  $0.30 per 1M tokens
Output: $2.50 per 1M tokens
```

### Gemini 2.5 Pro (Advanced - Better Quality)
```
Input:  $1.25 per 1M tokens
Output: $10.00 per 1M tokens
```

### Example: One 100-token message
```
Flash Model:
  Input:  100 × ($0.30 / 1,000,000) = $0.00003
  Output: 100 × ($2.50 / 1,000,000) = $0.00025
  Total:  $0.00028 USD
  
Pro Model:
  Input:  100 × ($1.25 / 1,000,000) = $0.000125
  Output: 100 × ($10.00 / 1,000,000) = $0.001
  Total:  $0.001125 USD
```

---

## 3️⃣ CREDIT COST MAPPING (Credits = API Cost ÷ $0.06)

### The Formula
```
Credits Used = (API Cost in USD) / 0.06
```

### Real Examples

#### Example 1: Short Chat Message
```
Message: "How do I get bigger arms?"
Estimated tokens: 10 input + 100 output = 110 total

API Cost (Flash):
  Input:  10 × (0.30 / 1,000,000) = $0.000003
  Output: 100 × (2.50 / 1,000,000) = $0.00025
  Total:  $0.000253

Credits: $0.000253 / 0.06 = 0.00422 credits
Deducted: ~0.004 credits (almost free!)
```

#### Example 2: Long Chat Message with Analysis
```
Message: "Analyze my workout form. I've been training for 2 years..."
[With 2 images attached]

Estimated tokens: 500 input (text + images) + 300 output

API Cost (Flash):
  Input:  500 × (0.30 / 1,000,000) = $0.00015
  Output: 300 × (2.50 / 1,000,000) = $0.00075
  Total:  $0.0009

Credits: $0.0009 / 0.06 = 0.015 credits
Deducted: ~0.015 credits (very cheap!)
```

#### Example 3: Very Long Response (Comprehensive Analysis)
```
User Request: "Create a detailed 4-week meal plan for bulking"
Response is very long: ~2000 tokens

API Cost (Flash):
  Input:  200 × (0.30 / 1,000,000) = $0.00006
  Output: 2000 × (2.50 / 1,000,000) = $0.005
  Total:  $0.00506

Credits: $0.00506 / 0.06 = 0.0843 credits
Deducted: ~0.084 credits
```

#### Example 4: Using Pro Model (More Expensive)
```
Same request but with Pro model:

API Cost (Pro):
  Input:  200 × (1.25 / 1,000,000) = $00000.00025
  Output: 2000 × (10.00 / 1,000,000) = $0.020
  Total:  $0.02003

Credits: $0.02003 / 0.06 = 0.334 credits
Deducted: ~0.334 credits (4x more expensive!)
```

---

## 4️⃣ FIXED CREDIT COSTS (Per Feature)

**Text-Based Features:**
- Chat Message: **1 credit** (approximate for average message)
- Voice Command: **1 credit**
- Workout Suggestion: **2 credits**
- Meal Plan Generation: **3 credits**
- Progress Insights: **2 credits**

**Vision Features (Photo Analysis):**
- Meal Photo Analysis: **2 credits**
- Form Check (Photo): **3 credits**
- Exercise Form Photo: **3 credits**

**Video Features (Most Expensive):**
- Workout Video Analysis: **5 credits**
- Form Check (Video): **5 credits**
- Rep Counting (Video): **4 credits**

**Audio Features:**
- Voice to Text: **1 credit**
- Audio Coaching: **2 credits**

**Live Coaching:**
- Live Workout Coaching (per session): **5 credits**
- Live Form Correction: **5 credits**

---

## 5️⃣ COMPLETE FLOW: USER SENDS MESSAGE

### Step 1: User Sends Message
```dart
User: "Create a meal plan for tomorrow"
_textController.text = "Create a meal plan for tomorrow";
_sendMessage();  // Called
```

### Step 2: Check Available Credits
```dart
// File: floating_ai_assistant.dart, line 3220
final preciseCredits = CreditsService.instance.preciseCredits;
debugPrint('🟣 User has $preciseCredits credits');

// Example: User has 50.5 credits
if (preciseCredits >= 1.0) {
  // Continue with message
} else {
  // Show error: "Not enough credits"
  return;
}
```

### Step 3: Send to Gemini API
```dart
// File: firebase_ai_service.dart
final response = await geminiModel.generateContent(
  content: [
    Content.text("Create a meal plan for tomorrow"),
    // ... system prompt, conversation history, etc
  ],
);
```

### Step 4: Gemini Returns Response + Token Count
```dart
response = {
  "text": "Here's a meal plan...",
  "usageMetadata": {
    "promptTokenCount": 234,        // Input tokens
    "candidatesTokenCount": 612,    // Output tokens
  }
}
```

### Step 5: Calculate Credit Cost
```dart
// File: firebase_ai_service.dart, line 1031-1046
final inputTokens = response.usageMetadata?.promptTokenCount ?? 0;  // 234
final outputTokens = response.usageMetadata?.candidatesTokenCount ?? 0;  // 612

// Flash model costs
final inputCostPer1M = 0.30;    // $0.30 per 1M input tokens
final outputCostPer1M = 2.50;   // $2.50 per 1M output tokens

// Calculate API cost in USD
final apiCostUsd = (inputTokens * inputCostPer1M / 1000000.0) + 
                   (outputTokens * outputCostPer1M / 1000000.0);

// Example calculation:
// Input:  234 × (0.30 / 1,000,000) = $0.00007020
// Output: 612 × (2.50 / 1,000,000) = $0.00153000
// Total:  $0.00160020

// Convert to credits ($0.06 per credit)
final creditsUsed = apiCostUsd / 0.06;
// $0.00160020 / 0.06 = 0.0267 credits
```

### Step 6: Deduct Credits from User Account
```dart
// File: firebase_ai_service.dart, line 1178
await CreditsService.instance.usePreciseCredits(
  creditsUsed,  // 0.0267
  description: 'AI Chat'
);
```

**What happens inside usePreciseCredits:**
```dart
// File: credits_service.dart, line 190
if (_preciseCredits < amount) {
  // Reject if not enough
  return false;
}

// Call Cloud Function to deduct securely (backend)
final result = await FirebaseFunctions.instance
    .httpsCallable('deductCredits')
    .call({
      'amount': 0.0267,  // Fractional amount
      'description': 'AI Chat'
    });

// Backend updates Firestore:
// User.credits.precise = 50.5 - 0.0267 = 50.4733
// User.credits.available = ceil(50.4733) = 51

// Update local state
_preciseCredits = 50.4733;
_availableCredits = 51;

notifyListeners();  // UI updates to show new balance
```

### Step 7: UI Updates
```dart
// FloatingAI toolbar shows new credit balance
💎 50  // Was 50, now rounded from 50.4733
```

### Step 8: Log Credit Usage
```dart
// File: credits_service.dart, line 380
await FirebaseFirestore.instance.collection('credit_usage').add({
  'userId': 'user123',
  'amount': 0.0267,
  'description': 'AI Chat',
  'timestamp': now(),
  'remainingCredits': 50.4733,
});
```

---

## 6️⃣ STREAMING RESPONSES (Real-Time Deduction)

When user gets streaming response (word-by-word), credits are calculated like this:

```dart
// File: firebase_ai_service.dart, line 1152-1174
int inputTokens = 0;
int outputTokens = 0;

await for (final chunk in responseStream) {
  fullResponse += chunk.text;
  
  // Update token counts as we receive chunks
  if (chunk.usageMetadata != null) {
    inputTokens = chunk.usageMetadata!.promptTokenCount ?? inputTokens;
    outputTokens = chunk.usageMetadata!.candidatesTokenCount ?? outputTokens;
  }
}

// After stream completes, deduct final amount
final creditsUsed = ((inputTokens * 0.30 + outputTokens * 2.50) / 1000000.0) / 0.06;
await CreditsService.instance.usePreciseCredits(creditsUsed);
```

**Why streaming?**
- User sees response appearing in real-time
- We don't know final token count until stream ends
- Credits deducted AFTER response fully received

---

## 7️⃣ ERROR HANDLING & REFUNDS

### Scenario: API Fails After Credits Deducted

```dart
// Video generation starts (50 credits deducted)
await CreditsService.instance.useCredits(50, description: 'Video generation');

try {
  final video = await generateVideo(prompt);
  
  if (video == null) {
    // Generation failed
    await CreditsService.instance.refundCredits(50);
    return null;
  }
} catch (e) {
  // Error occurred
  await CreditsService.instance.refundCredits(50);
  throw e;
}
```

**Flow:**
```
User has 100 credits
↓
User requests video (deduct 50) → Now has 50 credits
↓
Video generation fails
↓
Refund 50 credits → Back to 100 credits
↓
Show error message to user
```

---

## 8️⃣ DAILY BONUS SYSTEM

```dart
// File: credits_service.dart, line 358
Future<bool> claimDailyBonus() async {
  // Call backend Cloud Function
  final result = await FirebaseFunctions.instance
      .httpsCallable('claimDailyBonus')
      .call();
  
  // Backend checks:
  // - Has user claimed bonus today? (checks Firestore timestamp)
  // - If not, grant +1 credit
  // - If yes, reject
  
  final granted = result.data?['granted'] == true;
  
  if (granted) {
    final available = result.data?['available'] as int;  // New balance
    _availableCredits = available;
    await _saveLocal();
    notifyListeners();
    debugPrint('🎁 Daily bonus claimed: +1 credit');
  }
}
```

---

## 9️⃣ OFFLINE MODE

When user is offline, credits work locally:

```dart
// File: credits_service.dart, line 167
final uid = FirebaseAuth.instance.currentUser?.uid;
if (uid == null) {
  // Offline - deduct locally only
  _availableCredits -= amount;
  _preciseCredits -= amount.toDouble();
  await _saveLocal();
  notifyListeners();
  return true;
}
```

**What happens when app goes online again:**
```
Offline deductions: 5 credits
Backend balance: 100 credits
↓
Next sync: Backend overrides with Firestore truth
↓
Local balance resets to 100 (online source of truth)
```

---

## 🔟 CREDIT USAGE SUMMARY TABLE

| Action | Fixed Cost | Actual Cost Range | Reason |
|--------|-----------|------------------|--------|
| Chat Message | 1 credit | 0.004 - 0.25 credits | Depends on response length |
| Short Question | 1 credit | 0.001 - 0.05 credits | Very cheap for short Q&A |
| Meal Plan Gen | 3 credits | 0.05 - 0.15 credits | Takes ~500-1000 tokens |
| Photo Analysis | 2-3 credits | 0.02 - 0.1 credits | Vision token pricing |
| Video Analysis | 4-5 credits | 0.1 - 0.3 credits | Video = more tokens |
| Image Generation | 10 credits | Variable | Uses different API |
| Video Generation | 50 credits | Variable | Uses different API |

---

## 1️⃣1️⃣ KEY CODE LOCATIONS

```
✅ Load Credits:
   File: credits_service.dart:78-127
   Function: load()

✅ Use Credits:
   File: credits_service.dart:190-245
   Function: useCredits() / usePreciseCredits()

✅ Calculate API Cost:
   File: firebase_ai_service.dart:1031-1050
   Formula: (inputTokens * 0.30 + outputTokens * 2.50) / 1000000 / 0.06

✅ Deduct on Send Message:
   File: firebase_ai_service.dart:1178
   Line: await CreditsService.instance.usePreciseCredits(creditsUsed)

✅ Streaming Deduction:
   File: firebase_ai_service.dart:1173-1178
   Happens after stream completes

✅ Credit Costs Per Feature:
   File: models/ai_credit_costs.dart
   All static constants defined here

✅ Daily Bonus:
   File: credits_service.dart:358-378
   Function: claimDailyBonus()
```

---

## 1️⃣2️⃣ REAL-WORLD EXAMPLE: User's Day

```
Morning: User has 100 credits
  
10:00 AM - Chat about meal plan
  Message: "Plan for today?"
  Tokens: 50 input + 200 output
  Cost: (50 × 0.30 + 200 × 2.50) / 1000000 / 0.06 = 0.0083 credits
  Balance: 100 - 0.0083 = 99.9917 credits

11:30 AM - Analyze meal photo
  Tokens: 300 input + 150 output  
  Cost: (300 × 0.30 + 150 × 2.50) / 1000000 / 0.06 = 0.0083 credits
  Balance: 99.9917 - 0.0083 = 99.9834 credits

2:00 PM - Request video analysis
  Tokens: 500 input + 400 output
  Cost: (500 × 0.30 + 400 × 2.50) / 1000000 / 0.06 = 0.0278 credits
  Balance: 99.9834 - 0.0278 = 99.9556 credits

Evening: Daily bonus claimed
  Balance: 99.9556 + 1 = 100.9556 credits → displays as "101 cr"

Total usage today: 0.0444 credits (EXTREMELY CHEAP!)
```

---

## 1️⃣3️⃣ TRANSPARENCY: Why Credits Are So Cheap

Your pricing is designed to be **user-friendly** while covering API costs:

```
1 Credit = $0.06

Gemini 2.5 Flash Chat:
  Typical message = 0.001 - 0.05 credits = $0.00006 - $0.003

What you pay Google:
  $0.30-$2.50 per 1M tokens
  
What user pays you:
  $0.06 per credit

Profit margin: Built into the price!
Users get cheap AI ✅
You cover API + infrastructure ✅
```

---

## 🎯 Summary

| Phase | What Happens | Code Location |
|-------|--------------|-----------------|
| 1. User Sends | Message entered | floating_ai_assistant.dart:3200+ |
| 2. Check Credits | Verify balance ≥ cost | firebase_ai_service.dart:1030 |
| 3. Send to API | Call Gemini API | firebase_ai_service.dart:1020 |
| 4. Get Response | Receive text + tokens | firebase_ai_service.dart:1031 |
| 5. Calculate Cost | API cost → credits | firebase_ai_service.dart:1046 |
| 6. Deduct Credits | Update user balance | credits_service.dart:210 |
| 7. Save & Notify | Update UI | credits_service.dart:240 |
| 8. Log Usage | Track for analytics | credits_service.dart:380 |

