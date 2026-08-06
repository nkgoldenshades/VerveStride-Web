# Token Display Integration - Per-Message Token Tracking

## What You Asked For

You want **every chat message to show**:
- How many input tokens the user's message had
- How many output tokens the AI's response had  
- How many credits that costs (calculated from tokens)

Example:
```
User: "How do I build muscle?" 
[20 input tokens]

AI: "Here's how to build muscle..." 
[500 output tokens] 
📊 20 ↪ + 500 ↩ = 0.00002 credits
```

---

## Changes Already Made ✅

### 1. **ChatMessage Model Updated**
File: `lib/models/conversation_thread.dart`

```dart
// NEW fields added:
final int? inputTokens;  // Tokens in user's message
final int? outputTokens; // Tokens in AI's response
```

✅ Done - toJson() and fromJson() updated

### 2. **Token Display Widget Created**
File: `lib/widgets/token_display.dart` ✅ Created

```dart
// Two display options:
TokenDisplay()          // Full detailed display
CompactTokenDisplay()   // Inline tooltip display
```

---

## Changes Still Needed (Manual Approval Only)

### Step 1: Update UnifiedAIChatService to capture tokens

**File**: `lib/services/unified_ai_chat_service.dart`

When the AI response comes back from `firebase_ai_service.chatWithAIStream()`, it needs to:

```dart
// Get the response map with tokens
final result = await firebaseService.chatWithAIStream(...);
// Result contains: {'text': '...', 'inputTokens': 20, 'outputTokens': 500, 'creditsUsed': 0.00002}

// Attach tokens to the message being built
final aiMessage = ChatMessage(
  role: 'assistant',
  content: result['text'],
  timestamp: DateTime.now(),
  inputTokens: result['inputTokens'],      // NEW
  outputTokens: result['outputTokens'],    // NEW  
  preciseCredits: result['creditsUsed'],
);
```

### Step 2: Display tokens in AI Chat Screen

**File**: `lib/screens/ai_chat/ai_chat_screen.dart`

In the message builder, add token display under each AI message:

```dart
// In message list builder, after message content:
if (message.isAssistant)
  TokenDisplay(
    inputTokens: message.inputTokens,
    outputTokens: message.outputTokens,
    preciseCredits: message.preciseCredits,
  ),
```

### Step 3: Update firebase_ai_service to return tokens

**File**: `lib/services/firebase_ai_service.dart`

The `chatWithAIStream()` method already calculates tokens (lines ~1270-1272):

```dart
// Line 1272:
final creditsUsed = ((inputTokens * 0.30 + outputTokens * 2.50) / 1000000.0) / 0.06;

// It should yield this info somehow - currently it only yields text chunks
// Option A: Yield a special message with metadata at the end
// Option B: Return the metadata separately after yielding all text
// Option C: Store tokens globally during streaming
```

**Current behavior**: chatWithAIStream only yields text chunks, not metadata

---

## Recommendation

### Option 1: **Simple (Recommended)**
- Display tokens **only for AI responses** (not user messages)
- Show in small gray text below message
- Format: `📊 20 input + 500 output = 0.00002 credits`
- **Pro**: Users see exact cost of every question
- **Con**: Makes UI slightly busier

### Option 2: **Minimal**
- Show tokens only on **hover/tap** (tooltip)
- Normal view: just the message
- Tap message: shows `📊 20 + 500 tokens`
- **Pro**: Clean UI, transparency on demand
- **Con**: Requires tap to see

### Option 3: **Detailed Statistics**
- Show token stats in **message header** with timestamp
- Format: `AI · 14:23 · 📊 20+500 · 0.00002cr`
- **Pro**: Comprehensive information
- **Con**: More complex UI

---

## How Tokens Get Calculated

The formula in `firebase_ai_service.dart` (line ~1272):

```dart
creditsUsed = ((inputTokens * 0.30 + outputTokens * 2.50) / 1000000.0) / 0.06

Breakdown:
├─ inputTokens × $0.30  = Input token cost (Gemini pricing)
├─ outputTokens × $2.50 = Output token cost (Gemini pricing)
├─ ÷ 1,000,000          = Convert per-1M to per-token
└─ ÷ $0.06              = Convert USD to credits (1 credit = $0.06)

Example:
├─ 20 input tokens × $0.30 = $0.006
├─ 500 output tokens × $2.50 = $1.25
├─ Total: ($0.006 + $1.25) / 1,000,000 = $0.000001256 / 1,000,000
└─ Credits: $0.000001256 / $0.06 = 0.00002093 credits
```

---

## UI Mockup - Simple Option

```
┌─────────────────────────────────────────┐
│ AI Chat                      💎 99 cr   │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ You: "How do I build muscle?"           │
│ (20 tokens input)                       │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ AI: "Here's how to build muscle...      │
│      ...stay consistent!"               │
│                                         │
│ 📊 20 ↪ + 500 ↩ = 0.00002 credits      │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ You: "What about cardio?"               │
│ (12 tokens input)                       │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ AI: "Cardio is important...             │
│      ...30 minutes daily!"              │
│                                         │
│ 📊 12 ↪ + 350 ↩ = 0.00001 credits      │
└─────────────────────────────────────────┘
```

---

## Files to Modify (When Approved)

1. ✅ `lib/models/conversation_thread.dart` - **DONE**
2. ✅ `lib/widgets/token_display.dart` - **DONE** (created)
3. ⏳ `lib/services/firebase_ai_service.dart` - Needs update to preserve tokens in response
4. ⏳ `lib/services/unified_ai_chat_service.dart` - Attach tokens to ChatMessage
5. ⏳ `lib/screens/ai_chat/ai_chat_screen.dart` - Display token widget in message list
6. ⏳ `lib/widgets/ai_message_content.dart` - Maybe: update message rendering

---

## Summary

**When you approve, I will:**

1. Make firebase_ai_service return token counts with each response
2. Update UnifiedAIChatService to capture and attach tokens to messages
3. Update AI Chat Screen to display TokenDisplay widget
4. Test and verify it compiles

**Result**: Every AI response will show:
```
📊 [input tokens] ↪ + [output tokens] ↩ = [precise credits] credits
```

Users will see exact token usage and understand why each message costs what it costs!

