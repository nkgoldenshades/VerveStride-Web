# Floating AI Assistant - Global Voice & Chat Interface

## Overview
Created a floating AI assistant that's available anywhere in the app, including during workouts. Users can tap to chat or hold to speak with the AI from any screen.

## Features

### 1. Floating Button
- **Location**: Bottom-right corner (above bottom navigation)
- **Always Visible**: Follows you through all screens
- **Visual States**:
  - Normal: Blue/purple gradient with robot icon
  - Listening: Red pulsing animation with mic icon
  - Processing: Loading spinner overlay
  - Expanded: Close icon (X)

### 2. Voice Input
- **Activation**: Long-press the floating button
- **Visual Feedback**: 
  - Button turns red and pulses
  - "Listening... Release to send" text appears
- **How it Works**:
  1. User long-presses button
  2. Voice recording starts (red pulsing animation)
  3. User speaks their question/command
  4. User releases button
  5. Speech converts to text
  6. Message sent to AI automatically

### 3. Chat Interface
- **Activation**: Tap the floating button
- **Expandable Panel**: Slides up from bottom
- **Features**:
  - Full chat interface
  - Message history (user + AI)
  - Text input field
  - Voice button (hold to speak)
  - Send button
  - Close button

### 4. Chat Panel Layout
```
┌─────────────────────────────────┐
│ 🤖 VerveStride AI          [X] │
│ Your fitness companion          │
├─────────────────────────────────┤
│                                 │
│  [User Message]                 │
│                                 │
│         [AI Response]           │
│                                 │
│  [User Message]                 │
│                                 │
│         [AI Response]           │
│                                 │
├─────────────────────────────────┤
│ [🎤] [Type a message...] [📤]  │
└─────────────────────────────────┘
```

### 5. Message Bubbles
- **User Messages**: 
  - Right-aligned
  - Blue background
  - Max 70% screen width
- **AI Responses**:
  - Left-aligned
  - Green background
  - Max 70% screen width
  - Better line height for readability

### 6. Empty State
When no messages:
```
👋
Hi! How can I help?
Tap to type or hold to speak
```

## User Interactions

### Tap Floating Button
- Opens/closes chat panel
- Quick access to full chat interface

### Long-Press Floating Button
- Starts voice input immediately
- No need to open chat panel
- Quick voice commands during workouts

### Hold Voice Button in Chat
- Alternative way to use voice
- Same as long-pressing floating button
- Visual feedback with red color

### Type Message
- Traditional text input
- Press Enter or tap send button
- Good for detailed questions

## Integration Points

### 1. Navigation Container
- Added to main navigation stack
- Available on: Home, Log, Calendar, Profile screens
- Positioned above bottom navigation bar

### 2. Workout Screen (Future)
- Can be added to workout screen
- Useful for mid-workout questions
- "How many calories burned?"
- "What's my heart rate target?"

### 3. Any Screen (Future)
- Can be added to any screen by wrapping in Stack
- Consistent position and behavior

## Technical Implementation

### Files Created:
1. `lib/widgets/floating_ai_assistant.dart` - Main widget

### Files Modified:
1. `lib/screens/navigation_container.dart` - Added floating AI to main navigation

### Key Components:

#### 1. Floating Button Widget
```dart
GestureDetector(
  onTap: () => toggleExpanded(),
  onLongPress: () => startVoiceInput(),
  child: AnimatedContainer(
    // Pulsing animation when listening
    // Gradient colors
    // Shadow effects
  ),
)
```

#### 2. Chat Panel Widget
```dart
Positioned(
  right: 16,
  bottom: 150,
  child: Material(
    // Expandable chat interface
    // Message history
    // Input controls
  ),
)
```

#### 3. Animation Controller
```dart
AnimationController _pulseController;
Animation<double> _pulseAnimation;

// Pulsing effect when listening
Transform.scale(
  scale: _isListening ? _pulseAnimation.value : 1.0,
  child: floatingButton,
)
```

### State Management:
- `_isExpanded`: Chat panel open/closed
- `_isListening`: Voice input active
- `_isProcessing`: AI thinking
- `_currentMessage`: User's message
- `_aiResponse`: AI's response

### AI Integration:
```dart
// Send message to AI
final response = await FirebaseAIService.instance.chatWithAI(message);

// Voice command processing (future)
final voiceCommand = await FirebaseAIService.instance.processVoiceCommand(text);
```

## Use Cases

### During Workout
```
User: [Long-press button]
User: "How many calories have I burned?"
AI: "You've burned 245 calories in the last 15 minutes. Keep it up!"
```

### Quick Question
```
User: [Tap button]
User: [Types] "What should I eat for lunch?"
AI: "Based on your goals, try a grilled chicken salad with quinoa..."
```

### Meal Logging
```
User: [Long-press button]
User: "I just ate a banana"
AI: "Logged! That's about 105 calories. Want to add anything else?"
```

### Progress Check
```
User: [Tap button]
User: [Types] "How am I doing this week?"
AI: "Great progress! You've completed 4 workouts and stayed within your calorie goal 5 days."
```

## Visual Design

### Colors:
- **Primary Gradient**: Blue to Purple (AppColors.primary → AppColors.secondary)
- **Listening State**: Red to Red Accent
- **User Messages**: Primary color with 20% opacity
- **AI Messages**: Secondary color with 20% opacity

### Animations:
- **Pulse**: 1.5s duration, 1.0 to 1.2 scale
- **Shadow**: Increases when listening (blur: 15 → 20, spread: 2 → 5)
- **Panel**: Slides up from bottom

### Positioning:
- **Right**: 16px from edge
- **Bottom**: 80px from bottom (above nav bar)
- **Panel Width**: Screen width - 32px
- **Panel Height**: 400px

## Accessibility Features

1. **Visual Feedback**: Clear states (normal, listening, processing)
2. **Multiple Input Methods**: Voice OR text
3. **Large Touch Targets**: 60x60 button, 44x44 controls
4. **High Contrast**: Clear text on colored backgrounds
5. **Tooltips**: Helpful hints for new users

## Future Enhancements

### 1. Speech-to-Text Integration
Currently simulated. Need to integrate:
```dart
import 'package:speech_to_text/speech_to_text.dart';

final speech = SpeechToText();
await speech.initialize();
await speech.listen(onResult: (result) {
  setState(() => _textController.text = result.recognizedWords);
});
```

### 2. Text-to-Speech for AI Responses
```dart
import 'package:flutter_tts/flutter_tts.dart';

final tts = FlutterTts();
await tts.speak(aiResponse);
```

### 3. Conversation History
- Save chat history locally
- Load previous conversations
- Clear history option

### 4. Quick Actions
- Predefined buttons: "Log meal", "Start workout", "Check progress"
- One-tap common commands

### 5. Context Awareness
- Know which screen user is on
- Provide relevant suggestions
- "You're on the workout screen. Want to start a session?"

### 6. Minimized Mode
- Collapse to just the button
- Show notification badge for new messages
- Expand on tap

### 7. Workout-Specific Features
- Real-time coaching during workouts
- Form corrections
- Motivation messages
- Rep counting

## Testing Checklist

- [x] Floating button appears on all main screens
- [x] Button opens/closes chat panel
- [x] Long-press starts voice input
- [x] Visual feedback for listening state
- [x] Pulsing animation works
- [x] Chat messages display correctly
- [x] Text input works
- [x] Send button works
- [x] AI responses appear
- [x] Processing indicator shows
- [x] Close button works
- [x] No diagnostics or errors
- [ ] Speech-to-text integration (TODO)
- [ ] Text-to-speech integration (TODO)
- [ ] Works during active workout
- [ ] Doesn't interfere with other UI elements
- [ ] Proper z-index/stacking

## Known Limitations

1. **Voice Input**: Currently simulated, needs speech_to_text package
2. **Single Conversation**: Only shows last message pair, not full history
3. **No Persistence**: Messages cleared when panel closes
4. **No Notifications**: No badge or alert for new AI messages

## Dependencies Needed

Add to `pubspec.yaml`:
```yaml
dependencies:
  speech_to_text: ^6.6.0  # For voice input
  flutter_tts: ^3.8.5      # For AI voice responses
  permission_handler: ^11.0.1  # For microphone permissions
```

## Permissions Required

### Android (`android/app/src/main/AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>
```

### iOS (`ios/Runner/Info.plist`):
```xml
<key>NSMicrophoneUsageDescription</key>
<string>We need microphone access for voice commands</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>We need speech recognition for voice commands</string>
```

## Status
✅ **IMPLEMENTED** - Basic floating AI with chat interface
⏳ **PENDING** - Speech-to-text integration
⏳ **PENDING** - Text-to-speech integration
⏳ **PENDING** - Conversation history persistence

## Next Steps
1. Add speech_to_text package
2. Implement real voice input
3. Add text-to-speech for AI responses
4. Test during actual workouts
5. Add conversation history
6. Add quick action buttons
