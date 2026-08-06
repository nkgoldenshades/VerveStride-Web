# In-App Usage Tour Guide

Add an interactive tour showing users how to use VerveStride AI features after they sign in.

---

## Tour Screens Overview

### Tour Structure
```
1. Welcome to VerveStride AI
2. How Credits Work
3. AI Chat Features
4. Memory System
5. Generate Images/Videos
6. Your First Message
```

---

## Screen 1: Welcome to VerveStride AI

```
┌─────────────────────────────────────────┐
│                                         │
│          ✨ Welcome to                  │
│       VerveStride AI                    │
│                                         │
│  Your personal fitness AI coach         │
│  powered by Google Gemini               │
│                                         │
│  Let's get you started!                 │
│                                         │
│                                         │
│           [Continue]                    │
│           Skip Tour                     │
└─────────────────────────────────────────┘
```

---

## Screen 2: How Credits Work

```
┌─────────────────────────────────────────┐
│                                         │
│     💳 Understanding Credits            │
│                                         │
│  You have: 100 credits                  │
│  (Purchased for ₹415)                   │
│                                         │
│  How credits are used:                  │
│                                         │
│  💬 Chat messages                       │
│     ~0.00002 credits per message        │
│     (basically FREE!)                   │
│                                         │
│  🎨 Generate Image                      │
│     1 credit per image                  │
│                                         │
│  🎬 Generate Video                      │
│     8 credits per video                 │
│                                         │
│  📊 Each message shows its cost         │
│                                         │
│        [Next]                           │
│        Skip Tour                        │
└─────────────────────────────────────────┘
```

---

## Screen 3: AI Chat Features

```
┌─────────────────────────────────────────┐
│                                         │
│     💬 Chat with Your AI Coach          │
│                                         │
│  What you can ask:                      │
│                                         │
│  ✓ Fitness advice & workouts            │
│  ✓ Meal planning & nutrition            │
│  ✓ Health & wellness tips               │
│  ✓ Form checking (upload photo/video)   │
│  ✓ Progress analysis                    │
│  ✓ Motivation & accountability          │
│                                         │
│  The AI reads your fitness data         │
│  and gives personalized advice!         │
│                                         │
│  📍 Try: "How do I build muscle?"       │
│                                         │
│        [Next]                           │
│        Skip Tour                        │
└─────────────────────────────────────────┘
```

---

## Screen 4: Memory System

```
┌─────────────────────────────────────────┐
│                                         │
│     🧠 AI Memory                        │
│                                         │
│  The AI can remember you!               │
│                                         │
│  🧵 Thread Memory                       │
│     "Remember this conversation"        │
│     AI keeps context within one chat    │
│     (Turn ON for natural chat flow)     │
│                                         │
│  💬 Chat Memory                         │
│     "Remember across all chats"         │
│     AI recalls past conversations       │
│     (Turn ON for personalized advice)   │
│                                         │
│  Icon in toolbar:                       │
│  🧠 = Both ON                           │
│  🧵 = Thread only                       │
│  💬 = Chat only                         │
│  🆕 = Both OFF (fresh start)            │
│                                         │
│        [Next]                           │
│        Skip Tour                        │
└─────────────────────────────────────────┘
```

---

## Screen 5: Generate Images & Videos

```
┌─────────────────────────────────────────┐
│                                         │
│   🎨 Generate Images & Videos           │
│                                         │
│  Create visual fitness content:         │
│                                         │
│  🎨 Images (1 credit each)              │
│     "Create a workout diagram"          │
│     "Show me proper form for squats"    │
│                                         │
│  🎬 Videos (8 credits each)             │
│     "Generate a 10-sec demo video"      │
│     "Show stretching routine"           │
│                                         │
│  🎵 Audio (3 credits each)              │
│     "Create workout music"              │
│     "Generate meditation audio"         │
│                                         │
│  💡 Tip: Long prompts = better results! │
│                                         │
│  Example:                               │
│  "Create a workout diagram showing     │
│   proper form for deadlifts with       │
│   step-by-step hand positioning"       │
│                                         │
│        [Next]                           │
│        Skip Tour                        │
└─────────────────────────────────────────┘
```

---

## Screen 6: Send Your First Message

```
┌─────────────────────────────────────────┐
│                                         │
│    ✨ Ready? Let's chat!                │
│                                         │
│  You're now ready to use                │
│  VerveStride AI!                        │
│                                         │
│  Quick tips:                            │
│                                         │
│  ✓ Ask anything fitness-related         │
│  ✓ Upload photos for form check         │
│  ✓ Tap 📊 token button for cost         │
│  ✓ Check credits in top right           │
│  ✓ Toggle memory with 🧠 icon           │
│                                         │
│  Try these first:                       │
│                                         │
│  "What's my daily calorie need?"        │
│  "Create a 7-day workout plan"          │
│  "Analyze my form in this photo"        │
│  "Generate a quick warmup routine"      │
│                                         │
│              [Start Chatting]           │
│              (Goes to AI Chat)          │
│                                         │
│        Skip Tour                        │
└─────────────────────────────────────────┘
```

---

## Implementation Approach

### Option 1: **Separate Tour Screen** (Recommended)
Create `lib/screens/onboarding/app_tour_screen.dart`

```dart
class AppTourScreen extends StatefulWidget {
  const AppTourScreen({super.key});
  
  @override
  State<AppTourScreen> createState() => _AppTourScreenState();
}

class _AppTourScreenState extends State<AppTourScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;
  
  List<Widget> _getTourPages() => [
    _buildWelcomePage(),
    _buildCreditsPage(),
    _buildChatPage(),
    _buildMemoryPage(),
    _buildGeneratePage(),
    _buildFirstMessagePage(),
  ];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _controller,
        onPageChanged: (i) => setState(() => _currentPage = i),
        children: _getTourPages(),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }
}
```

### Option 2: **Inline Tooltips**
Show tooltips on first app launch pointing to features

### Option 3: **Settings > Help Section**
Add "App Tour" button in Settings that user can tap anytime

---

## When to Show Tour

**After Sign-In:**
```
User signs in → 
  If first time:
    Show tour → 
    Then go to AI Chat
  Else:
    Go directly to AI Chat
```

**Implementation in `main.dart`:**
```dart
final hasSeenTour = await LocalStorageService.instance.getHasSeenAppTour();

if (!hasSeenTour) {
  Navigator.pushReplacementNamed(context, Routes.appTour);
  // After tour completes:
  await LocalStorageService.instance.setHasSeenAppTour(true);
  Navigator.pushReplacementNamed(context, Routes.navigation);
} else {
  Navigator.pushReplacementNamed(context, Routes.navigation);
}
```

---

## Files to Create/Modify

1. **Create**: `lib/screens/onboarding/app_tour_screen.dart`
   - Tour UI with PageView
   - 6 tour pages
   - Navigation buttons

2. **Modify**: `lib/core/routes.dart`
   - Add: `static const appTour = '/app-tour';`

3. **Modify**: `lib/core/route_generator.dart`
   - Add route for `Routes.appTour`

4. **Modify**: `lib/main.dart`
   - Add tour check after sign-in
   - Redirect to tour if first time

5. **Modify**: `lib/services/local_storage_service.dart`
   - Add: `setHasSeenAppTour(bool)`
   - Add: `getHasSeenAppTour()`

6. **Modify**: `lib/screens/settings/` (Optional)
   - Add "View App Tour" button in Settings

---

## Tour Features

✅ Swipe to navigate pages
✅ Skip button to exit anytime
✅ Shows only once per user
✅ Can be revisited from Settings
✅ Beautiful animations
✅ Clear CTAs ("Continue", "Start Chatting")
✅ Real examples users can try
✅ Icons & emojis for clarity

---

## Quick Demo Examples

Users can try after tour:

1. **"How do I build muscle?"**
   - Shows AI understanding of fitness
   - Demonstrates chat capability
   - Uses minimal credits

2. **"Analyze my meal photo"**
   - Shows AI vision capability
   - Demonstrates image upload
   - Free (0 credits)

3. **"Create a workout diagram"**
   - Shows image generation
   - Teaches about credit costs (1 credit)
   - Visual output

---

## Alternative: Video Tour

If you want a video demo instead:
- Create short video showing:
  - How to ask questions
  - How credits work
  - How to upload images
  - How to toggle memory
- Store on Cloudflare R2
- Link from tour screen

---

## Summary

**Tour shows users:**
- ✅ What credits are & how they work
- ✅ How to chat with AI
- ✅ Memory system (thread vs chat)
- ✅ How to generate content
- ✅ Real examples to try
- ✅ UI navigation (toolbar, buttons, icons)

**Result:** New users feel confident and guided!

