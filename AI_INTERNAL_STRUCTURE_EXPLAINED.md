# How Internal Structure Changes When Working with AI

## ⚠️ IMPORTANT: Privacy Control via ML Analytics Setting

**Your personal data is ONLY sent to AI when "ML Analytics" is enabled in AI Settings.**

When ML Analytics is **OFF**:
- ❌ AI does NOT receive your profile (age, weight, goals)
- ❌ AI does NOT receive your activity history
- ❌ AI does NOT receive your meal logs
- ❌ AI does NOT receive your water intake
- ✅ AI works as a generic assistant (like ChatGPT)
- ✅ You can still use all AI features (chat, meal analysis, etc.)
- ✅ Responses are generic, not personalized

When ML Analytics is **ON**:
- ✅ AI receives your complete fitness context
- ✅ AI provides personalized coaching based on YOUR data
- ✅ AI references your actual workouts, meals, and progress
- ✅ AI celebrates your achievements and motivates you
- ✅ AI adapts advice to your specific goals

**Default**: ML Analytics is **enabled** by default. You can disable it anytime in **Settings → AI Settings → ML Analytics**.

---

## Overview
When you interact with VerveStride AI **with ML Analytics enabled**, the app collects, processes, and sends your personal data to provide personalized coaching. Here's exactly what happens behind the scenes.

---

## 🧠 The AI Context System

### What is "Context"?
Context is **everything the AI knows about you**. It's like giving the AI your fitness journal, profile, and recent activity history so it can give personalized advice instead of generic responses.

### Key Services Involved

#### 1. **UnifiedAIContextService** (`unified_ai_context_service.dart`)
**Purpose**: The "brain" that gathers ALL your data into one package for the AI.

**What it collects**:

```dart
{
  // === WHO YOU ARE ===
  'user_profile': {
    'name': 'John Doe',
    'age': 30,
    'gender': 'male',
    'height_cm': 175,
    'weight_kg': 80,
    'activity_level': 3,
    'goal': 'lose_weight',
    'target_weight_kg': 75,
  },

  // === YOUR SUBSCRIPTION ===
  'subscription': {
    'tier': 'pro',  // free, pro, elite, lifetime
    'is_pro': true,
    'is_elite': false,
    'ai_meal_analysis_limit': 30,
  },

  // === TODAY'S ACTIVITY ===
  'today': {
    'date': '2026-05-27',
    'activities': [
      {
        'type': 'running',
        'duration_minutes': 30,
        'calories_burned': 300,
        'distance_km': 5.0,
      }
    ],
    'total_calories_burned': 300,
    'total_duration_minutes': 30,
    'water_intake_ml': 1500,
  },

  // === RECENT HISTORY (last 7 days) ===
  'history': {
    'days': 7,
    'activities': [...],  // All activities from past week
    'water_intake': [...],  // Daily water logs
    'total_workouts': 5,
    'total_calories_burned': 1500,
    'average_daily_calories': 214,
  },

  // === YOUR GOALS ===
  'goals': {
    'daily_calorie_target': 2000,
    'daily_water_target_ml': 3000,
    'weight_goal': 'lose_weight',
    'target_weight_kg': 75,
  },

  // === CONVERSATION MEMORY ===
  'chat_history': [
    // Last 20 messages you sent to AI
  ],
}
```

**Methods**:
- `buildUserContext()` - Collects everything
- `buildContextSummary()` - Converts data to natural language for AI
- `getContextForFeature()` - Optimized context for specific features

---

#### 2. **FirebaseAIService** (`firebase_ai_service.dart`)
**Purpose**: The "messenger" that talks to Google's AI models (Gemini) via Firebase.

**What it does**:

1. **Builds System Prompt** (AI's instructions):
   ```
   ═══════════════════════════════════════════════════════════════
   VERVESTRIDE AI — YOUR PERSONAL AI ASSISTANT
   ═══════════════════════════════════════════════════════════════
   
   You are VerveStride AI — created by VerveStride.
   You are NOT Gemini, NOT ChatGPT, NOT Claude.
   
   [... 500+ lines of instructions ...]
   
   USER CONTEXT — YOUR USER'S PERSONAL FITNESS DATA
   ═══════════════════════════════════════════════════════════════
   
   USER PROFILE:
   - Name: John Doe
   - Age: 30 years, Gender: male
   - Weight: 80 kg, Height: 175 cm
   - Goal: lose_weight
   - Target Weight: 75 kg
   
   TODAY (2026-05-27):
   - 1 activities logged
   - Total calories burned: 300 kcal
   - Water intake: 1500 ml / 3000 ml goal
   
   RECENT HISTORY (last 7 days):
   - Total workouts: 5
   - Total calories burned: 1500 kcal
   - Average daily calories: 214 kcal
   
   DAILY GOALS:
   - Calorie target: 2000 kcal
   - Water target: 3000 ml
   ```

2. **Sends to Google Vertex AI**:
   - Uses Firebase AI SDK
   - Connects to Google's Gemini models
   - Includes your context in every request

3. **Manages Different AI Models**:
   - **General Chat**: `gemini-2.0-flash-exp` (fast, smart)
   - **Meal Analysis**: `gemini-2.0-flash-exp` (vision-enabled)
   - **Live Coaching**: `gemini-2.0-flash-live` (real-time audio)

---

## 📊 Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        USER ACTION                          │
│  (Send message, analyze meal, start workout coaching)       │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              UnifiedAIContextService                        │
│  • Reads LocalStorageService (Isar database)               │
│  • Collects profile, activities, meals, water, goals       │
│  • Builds comprehensive context map                         │
│  • Converts to natural language summary                     │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              FirebaseAIService                              │
│  • Builds system prompt with context                        │
│  • Selects appropriate AI model                             │
│  • Checks subscription/credits                              │
│  • Sends request to Firebase AI                             │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              Firebase AI (Vertex AI)                        │
│  • Routes to Google Cloud                                   │
│  • Processes with Gemini model                              │
│  • Returns AI response                                      │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              Response Processing                            │
│  • FirebaseAIService receives response                      │
│  • Parses JSON (for meal analysis)                          │
│  • Streams text (for chat)                                  │
│  • Plays audio (for live coaching)                          │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              UI Update                                      │
│  • Display AI message in chat                               │
│  • Show meal nutrition data                                 │
│  • Play coaching audio                                      │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔄 What Changes Internally?

### 1. **Local Storage (Isar Database)**
**Location**: Device storage (encrypted)

**What's stored**:
- User profile
- Activity logs (workouts, runs, walks)
- Meal logs (food items, calories, macros)
- Water intake logs
- AI chat history (last 20 messages)
- AI settings (selected models, language, persona)

**Changes when using AI**:
- ✅ Chat messages are saved to `ai_chat_history` collection
- ✅ Meal analysis results are saved to `meals` collection
- ✅ AI settings are updated when you change models/language
- ❌ No data is deleted or modified by AI (read-only access)

---

### 2. **Memory (RAM)**
**What's cached**:
- Current AI model instance (`_modelInstance`)
- Live coaching model instance (`_liveModelInstance`)
- User context (rebuilt on each request)
- Chat conversation history (in UI state)

**Changes when using AI**:
- ✅ Model instances are created and cached
- ✅ Context is built fresh each time (no stale data)
- ✅ Chat history grows in memory (cleared on app restart)
- ✅ Model instances are reset when you change models

---

### 3. **Network Requests**
**What's sent to Google Cloud**:

#### For Chat:
```json
{
  "model": "gemini-2.0-flash-exp",
  "systemInstruction": "You are VerveStride AI... [500+ lines] ... USER CONTEXT: [your data]",
  "contents": [
    {
      "role": "user",
      "parts": [{"text": "How many calories should I eat today?"}]
    }
  ],
  "generationConfig": {
    "temperature": 0.9,
    "maxOutputTokens": 8192
  }
}
```

#### For Meal Analysis:
```json
{
  "model": "gemini-2.0-flash-exp",
  "systemInstruction": "...",
  "contents": [
    {
      "role": "user",
      "parts": [
        {"text": "Analyze this meal photo..."},
        {"inlineData": {"mimeType": "image/jpeg", "data": "<base64 image>"}}
      ]
    }
  ]
}
```

**What's received**:
```json
{
  "candidates": [
    {
      "content": {
        "parts": [
          {"text": "Based on your goal to lose weight and your 300 calories burned today..."}
        ]
      }
    }
  ]
}
```

---

### 4. **Credits System**
**How it works**:
- Free users: Pay per use with credits
- Pro users: Pay per use with credits (no monthly limits)
- Elite/Lifetime users: Unlimited (no credits deducted)

**Credit costs**:
- Chat message: 1 credit
- Meal analysis: 5 credits
- Image generation: 20 credits
- Video generation: 50 credits
- Audio generation: 20 credits

**Changes when using AI**:
- ✅ Credits are deducted from `CreditsService`
- ✅ Usage is logged to `credits_transactions` collection
- ✅ Balance is updated in real-time

---

## 🔒 Privacy & Security

### ML Analytics Toggle - Your Privacy Control

**Location**: Settings → AI Settings → ML Analytics

**When ENABLED (default)**:
- ✅ AI receives your complete fitness context
- ✅ Personalized coaching based on YOUR data
- ✅ AI knows your goals, progress, and patterns
- ✅ Responses reference your actual workouts and meals

**When DISABLED**:
- ❌ AI does NOT receive any personal data
- ✅ AI works as generic assistant (like ChatGPT)
- ✅ All AI features still work (chat, meal analysis, etc.)
- ✅ Responses are generic, not personalized
- ℹ️ AI will suggest enabling ML Analytics if you ask for personalized advice

### What's Sent to Google (when ML Analytics is ON):
✅ **Sent**:
- Your profile (name, age, weight, goals)
- Your activity history (last 7 days)
- Your meal logs (if relevant to question)
- Your water intake
- Your chat messages
- Meal photos (for analysis)

❌ **NOT Sent**:
- Your email/password
- Payment information
- Device identifiers
- Location data (unless in workout route)
- Full database (only last 7 days)

### What's Sent to Google (when ML Analytics is OFF):
✅ **Sent**:
- Your chat messages only
- Meal photos (for analysis)
- No personal fitness data

❌ **NOT Sent**:
- Profile, activities, meals, water, goals
- Any personal fitness data

### Data Retention:
- **Google Cloud**: Processes data in real-time, does NOT store your personal data permanently
- **VerveStride**: Stores all data locally on your device (Isar database)
- **Chat History**: Last 20 messages kept in local storage

### Encryption:
- ✅ HTTPS for all network requests
- ✅ Isar database encrypted on device
- ✅ No data stored on VerveStride servers (serverless architecture)

---

## 🎯 Feature-Specific Changes

### 1. **Chat with AI**
**Internal changes**:
1. User types message → saved to local chat history
2. **IF ML Analytics is ON**: Context service builds your profile + recent data
3. **IF ML Analytics is OFF**: No context is built, AI gets message only
4. Firebase AI service sends to Gemini with/without context
5. Response streams back word-by-word
6. Response saved to chat history
7. Credits deducted (1 credit)

**Data modified**:
- `ai_chat_history` collection (append only)
- `credits_transactions` collection (new entry)
- `available_credits` field (decremented)

**With ML Analytics ON**: "Based on your 3 workouts this week and 1500 calories burned..."
**With ML Analytics OFF**: "Generally, aim for 150 minutes of moderate exercise per week..."

---

### 2. **Meal Photo Analysis**
**Internal changes**:
1. User takes photo → image bytes loaded
2. **IF ML Analytics is ON**: Context service gets your calorie goals
3. **IF ML Analytics is OFF**: No context, generic analysis only
4. Firebase AI service sends image + context to Gemini Vision
5. AI returns JSON with nutrition data
6. Meal saved to database with AI-generated data
7. Credits deducted (5 credits)

**Data modified**:
- `meals` collection (new meal entry)
- `credits_transactions` collection (new entry)
- `available_credits` field (decremented)

**With ML Analytics ON**: "This 450-calorie meal fits your 2000-calorie goal..."
**With ML Analytics OFF**: "This appears to be approximately 450 calories..."

---

### 3. **Live Workout Coaching**
**Internal changes**:
1. User starts workout → live session created
2. Every 30 seconds: exercise data sent to Gemini Live
3. AI returns audio coaching cue (< 1 second latency)
4. Audio played through device speakers
5. Session closed when workout ends
6. No credits deducted (Elite-only feature)

**Data modified**:
- `activities` collection (workout saved at end)
- No chat history saved (real-time only)

---

### 4. **Image/Video/Audio Generation**
**Internal changes**:
1. User enters prompt → sent to Cloud Function
2. Cloud Function calls Vertex AI Imagen/Veo/Lyria
3. Generated content returned as URL or bytes
4. Credits deducted (20-50 credits)
5. Content displayed in app (not saved to database)

**Data modified**:
- `credits_transactions` collection (new entry)
- `available_credits` field (decremented)

---

## 🔧 Configuration Changes

### AI Settings Stored:
```dart
{
  'selected_general_model': 'vs_flash_2_0',
  'selected_live_model': 'vs_live',
  'selected_vision_model': 'vs_vision',
  'selected_language': 'en_us',
  'selected_persona': 'motivational',
  'user_communication_style': 'casual',
  'photo_analysis_enabled': true,
  'conversational_ai_enabled': true,
  'data_analytics_enabled': true,
  'tts_voice_gender': 'female',
}
```

**When you change settings**:
- ✅ Model instances are reset (`_modelInstance = null`)
- ✅ Next AI request uses new model
- ✅ System prompt rebuilt with new language/persona
- ✅ Settings saved to local storage immediately

---

## 📈 Performance Impact

### Memory Usage:
- **Idle**: ~50 MB (app baseline)
- **Chat active**: +10 MB (model instance + context)
- **Meal analysis**: +5 MB (image bytes in memory)
- **Live coaching**: +15 MB (audio streaming)

### Network Usage:
- **Chat message**: ~5-10 KB request, ~2-5 KB response
- **Meal analysis**: ~500 KB request (image), ~1 KB response
- **Live coaching**: ~1 KB/second (bidirectional audio)

### Battery Impact:
- **Chat**: Minimal (text processing)
- **Meal analysis**: Low (one-time image upload)
- **Live coaching**: Moderate (continuous audio streaming)

---

## 🚀 Optimization Strategies

### 1. **Context Caching** (Future Enhancement)
Currently, context is rebuilt on every request. Future optimization:
```dart
// Cache context for 5 minutes
Map<String, dynamic>? _cachedContext;
DateTime? _cacheTime;

Future<Map<String, dynamic>> buildUserContext() async {
  if (_cachedContext != null && 
      DateTime.now().difference(_cacheTime!) < Duration(minutes: 5)) {
    return _cachedContext!;
  }
  // Rebuild context...
}
```

### 2. **Lazy Model Loading**
Models are only created when needed:
```dart
Future<GenerativeModel> _getModel() async {
  if (_modelInstance != null) return _modelInstance!;
  // Create new instance...
}
```

### 3. **Selective Context**
Different features get different context:
- **Chat**: Full context (profile + history + goals)
- **Meal analysis**: Nutrition context only (goals + today's meals)
- **Live coaching**: Fitness context only (profile + recent workouts)

---

## 🔍 Debugging AI Issues

### Enable Debug Logs:
```dart
debugPrint('🧠 AI Context Built:');
debugPrint('  Profile: ${profile?.name}, ${profile?.age}y');
debugPrint('  Today: ${todayActivities.length} activities');
debugPrint('🤖 Using ${modelConfig.displayName}');
```

### Check Context:
```dart
final context = await UnifiedAIContextService.instance.buildUserContext();
print(jsonEncode(context)); // See exactly what AI receives
```

### Verify Model Selection:
```dart
final modelId = await _getSelectedModelId('general');
print('Selected model: $modelId'); // Should be 'vs_flash_2_0'
```

---

## 📝 Summary

**What changes when you use AI**:
1. ✅ Your data is read from local database (if ML Analytics is ON)
2. ✅ Context is built and sent to Google Cloud (if ML Analytics is ON)
3. ✅ AI response is received and displayed
4. ✅ Chat history is saved locally
5. ✅ Credits are deducted (if applicable)
6. ❌ No data is modified or deleted by AI

**Key takeaway**: 
- **ML Analytics ON**: AI is personalized and reads your fitness data to give tailored advice
- **ML Analytics OFF**: AI is generic (like ChatGPT) and does NOT access your personal data
- **Always**: AI never modifies your workouts, meals, or goals. Only YOU can change your data through the app UI.

**Privacy Control**: You have full control over whether AI sees your personal data via the ML Analytics toggle in Settings → AI Settings.
