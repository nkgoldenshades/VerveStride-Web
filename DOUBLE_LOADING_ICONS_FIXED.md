# Double Loading Icons Fixed ✅

## Problem
When sending a message in either Floating AI or AI Settings chat, **TWO loading indicators** were showing simultaneously:
1. **Floating AI**: Thinking dots bubble (left side)
2. **AI Settings**: Circular spinner in send button

This happened because both screens had their own independent `_isProcessing` / `_isChatLoading` states, even though they share the same `UnifiedAIChatService`.

## Root Cause
- Both screens listen to the same unified chat service
- When one screen sends a message, the service notifies ALL listeners
- Each screen was showing its own loading indicator independently
- Result: **Double loading icons** visible at the same time

## Solution
Added **shared processing state** to `UnifiedAIChatService`:

```dart
// In UnifiedAIChatService
bool _isProcessing = false;
bool get isProcessing => _isProcessing;
```

### Changes Made

#### 1. UnifiedAIChatService (`lib/services/unified_ai_chat_service.dart`)
- Added `_isProcessing` state and `isProcessing` getter
- Set `_isProcessing = true` when message starts processing
- Set `_isProcessing = false` when message completes (or errors)
- Both `sendMessage()` and `sendMessageStream()` now manage this state

#### 2. Floating AI (`lib/widgets/floating_ai_assistant.dart`)
- Changed thinking indicator to use `_chatService.isProcessing` instead of local `_isProcessing`
- Attachment button now checks `_chatService.isProcessing` instead of local state
- **Voice toggle fix**: Only speaks if `_voiceEnabled` OR `_continuousVoice` is active

#### 3. AI Settings (`lib/screens/settings/ai_settings_screen.dart`)
- Removed local `_isChatLoading` state (no longer needed)
- Send button now uses `_chatService.isProcessing` to show spinner
- Text field disabled during `_chatService.isProcessing`

## Result
✅ **Only ONE loading indicator shows at a time**, regardless of which screen initiated the AI request
✅ **Voice toggle works correctly** - AI only speaks when voice is enabled
✅ **Attachment button works correctly** - Uses shared processing state

## Testing
1. Open Floating AI and send a message → See thinking dots
2. Open AI Settings chat and send a message → See spinner in send button
3. Send message from one screen while other is open → Only ONE indicator shows
4. Turn OFF voice commands → AI should NOT speak responses
5. Click attachment button during processing → Should be disabled

## Commit
```
Fix: Sync AI processing state across Floating AI and Settings chat
Commit: 27ac2b1
```
