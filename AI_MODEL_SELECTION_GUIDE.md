# 🤖 VerveStride AI - Model Selection System

## Overview

VerveStride AI now supports **multiple Google Gemini models** with custom branding. Users can select different models for different tasks based on their needs.

---

## ✨ Features

### **1. Multiple AI Models**
- **VerveStride Flash** - Fast responses (gemini-2.5-flash)
- **VerveStride Pro** - Advanced reasoning (gemini-2.0-pro)
- **VerveStride Ultra** - Most powerful (gemini-2.0-ultra)
- **VerveStride Vision** - Meal photo analysis (gemini-2.5-flash)
- **VerveStride Coach** - Live workout coaching (gemini-2.5-flash-native-audio)
- **VerveStride Thinking** - Deep analysis (gemini-2.0-flash-thinking)
- **VerveStride Experimental** - Latest features (gemini-exp-1206)

### **2. Task-Specific Selection**
Users can choose different models for:
- **General Chat** - Everyday conversations and fitness advice
- **Meal Analysis** - Photo analysis and nutrition breakdown
- **Live Coaching** - Real-time workout voice coaching

### **3. Custom Branding**
- All models branded as "VerveStride AI"
- User-friendly names (Flash, Pro, Ultra, etc.)
- Clear descriptions of capabilities
- Feature badges (Vision, Audio, Token limits)

---

## 📁 Files Created

### **1. Model Configuration**
```
lib/models/ai_model_config.dart
```
- Defines all available AI models
- Maps Google model IDs to VerveStride names
- Includes capabilities (vision, audio, live)
- Categorizes models (general, vision, live, advanced, experimental)

### **2. Model Selector Screen**
```
lib/screens/settings/ai_model_selector_screen.dart
```
- UI for selecting models
- Organized by category
- Shows model capabilities
- Saves user preferences

### **3. Updated AI Service**
```
lib/services/firebase_ai_service.dart
```
- Loads selected models from settings
- Uses appropriate model for each task
- Logs which model is being used
- Handles model switching

---

## 🎯 How It Works

### **1. User Selects Models**
```dart
// Navigate to model selector
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => AIModelSelectorScreen(),
  ),
);
```

### **2. Settings Are Saved**
```dart
// Saved in LocalStorageService
{
  'selected_general_model': 'vervestride_flash',
  'selected_live_model': 'vervestride_coach',
  'selected_vision_model': 'vervestride_vision',
}
```

### **3. AI Service Uses Selected Model**
```dart
// Automatically loads selected model
final model = await _getModel(type: 'general');
// Uses VerveStride Flash for general chat

final visionModel = await _getModel(type: 'vision');
// Uses VerveStride Vision for meal analysis

final liveModel = await _getLiveModel();
// Uses VerveStride Coach for live coaching
```

---

## 🔧 Integration

### **Add to Settings Screen**

```dart
// In your settings screen
ListTile(
  leading: Icon(Icons.psychology),
  title: Text('AI Models'),
  subtitle: Text('Choose AI models for different tasks'),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AIModelSelectorScreen(),
      ),
    );
  },
),
```

### **Add to Routes**

```dart
// In lib/core/routes.dart
static const String aiModelSelector = '/ai-model-selector';

// In lib/core/route_generator.dart
case Routes.aiModelSelector:
  return MaterialPageRoute(
    builder: (_) => const AIModelSelectorScreen(),
  );
```

---

## 📊 Available Models

### **General Purpose**

| Model | Speed | Quality | Use Case |
|-------|-------|---------|----------|
| **VerveStride Flash** | ⚡⚡⚡ | ⭐⭐⭐ | Quick questions, meal analysis |
| **VerveStride Pro** | ⚡⚡ | ⭐⭐⭐⭐ | Complex fitness plans |
| **VerveStride Ultra** | ⚡ | ⭐⭐⭐⭐⭐ | Comprehensive health analysis |

### **Specialized**

| Model | Specialty | Features |
|-------|-----------|----------|
| **VerveStride Vision** | Photo Analysis | 📸 Vision, Fast |
| **VerveStride Coach** | Live Coaching | 🎤 Audio, Real-time |
| **VerveStride Thinking** | Deep Analysis | 🧠 Advanced reasoning |

### **Experimental**

| Model | Status | Notes |
|-------|--------|-------|
| **VerveStride Experimental** | 🔬 Beta | Latest features, may be unstable |

---

## 💡 User Benefits

### **1. Flexibility**
- Choose fast models for quick tasks
- Choose powerful models for complex analysis
- Switch models anytime

### **2. Performance**
- Fast models = quick responses
- Powerful models = better quality
- Live models = real-time coaching

### **3. Cost Optimization**
- Use cheaper models for simple tasks
- Use expensive models only when needed
- Balance speed vs quality

---

## 🎨 UI Features

### **Model Cards**
- ✅ Selection indicator
- 📝 Model name and description
- 🏷️ Feature badges (Vision, Audio, Tokens)
- 🎯 Category organization

### **Categories**
- 💬 General Chat & Questions
- 👁️ Meal Photo Analysis
- 🎤 Live Workout Coaching
- 🧠 Advanced Analysis
- 🔬 Experimental Features

### **Info Section**
- About VerveStride AI
- Powered by Google Gemini
- Safety and accuracy info

---

## 🔍 Technical Details

### **Model Loading**
```dart
// Get selected model ID
final modelId = await _getSelectedModelId('general');

// Get model config
final config = AIModelConfig.getById(modelId);

// Create Firebase AI model
final model = FirebaseAI.googleAI().generativeModel(
  model: config.googleModelId,
  systemInstruction: Content.system(systemPrompt),
);
```

### **Model Caching**
- Models are cached after first use
- Cache is cleared when model changes
- Reduces initialization time

### **Error Handling**
- Falls back to default model if invalid
- Logs which model is being used
- Handles model switching gracefully

---

## 📈 Future Enhancements

### **Planned Features**
- [ ] Model performance metrics
- [ ] Cost tracking per model
- [ ] Auto-select best model for task
- [ ] Model comparison tool
- [ ] Usage statistics
- [ ] Model recommendations

### **Potential Models**
- [ ] VerveStride Nano (ultra-fast, basic)
- [ ] VerveStride Multimodal (video analysis)
- [ ] VerveStride Code (workout plan generation)
- [ ] VerveStride Medical (health analysis)

---

## 🚀 Getting Started

### **1. User Flow**
1. Open Settings
2. Tap "AI Models"
3. Select models for each category
4. Models are saved automatically
5. AI uses selected models

### **2. Default Models**
- General: VerveStride Flash
- Vision: VerveStride Vision
- Live: VerveStride Coach

### **3. Recommendations**
- **Beginners**: Use Flash for everything
- **Power Users**: Use Pro for chat, Vision for meals, Coach for workouts
- **Experimenters**: Try different models and see what works best

---

## ✅ Summary

**What Changed:**
- ✅ Added 7 different AI models
- ✅ Created model selection UI
- ✅ Updated AI service to use selected models
- ✅ Branded all models as "VerveStride AI"
- ✅ Organized by task type (general, vision, live)

**User Benefits:**
- 🎯 Choose models based on needs
- ⚡ Fast models for quick tasks
- 🧠 Powerful models for complex analysis
- 💰 Optimize cost vs performance

**Next Steps:**
- Add to settings screen
- Test model switching
- Gather user feedback
- Add more models as Google releases them

---

**VerveStride AI - Powered by Google Gemini, Customized for Fitness** 🏃💪🤖
