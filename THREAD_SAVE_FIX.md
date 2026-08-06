# Thread Save Fix - Conversation History Not Persisting

## Problem
When users clicked "New Conversation" in the floating AI assistant, the thread would vanish when switching conversations. The conversation history was not being properly saved.

## Root Cause
The `_createNewThread()` method in `floating_ai_assistant.dart` was calling `getActiveThread()`, which only creates a new thread if `_activeThread` is null. If there was already an active thread, it would just return the existing one instead of creating a new thread.

**Before:**
```dart
void _createNewThread() async {
  // This would NOT create a new thread if one already exists!
  final newThread = await _chatService.getActiveThread();
  // ...
}
```

## Solution
1. **Added public method** in `UnifiedAIChatService`:
   - Created `createNewThread()` as a public method that always creates a new thread
   - Keeps the private `_createNewThread()` for internal use

2. **Updated floating AI assistant**:
   - Changed `_createNewThread()` to call `_chatService.createNewThread()` instead of `getActiveThread()`
   - This ensures a brand new thread is always created when the user clicks "New Conversation"

**After:**
```dart
void _createNewThread() async {
  // Now always creates a new thread!
  final newThread = await _chatService.createNewThread();
  // ...
}
```

## Files Modified
- `lib/services/unified_ai_chat_service.dart` - Added public `createNewThread()` method
- `lib/widgets/floating_ai_assistant.dart` - Updated to use the new public method

## Testing
1. Open the floating AI assistant
2. Start a conversation
3. Click "New Conversation" button
4. Verify a new thread is created in the sidebar
5. Switch between threads - all conversations should persist
6. Close and reopen the app - all threads should still be there

## Technical Details
- Threads are saved to local storage via `LocalStorageService`
- Storage key: `unified_ai_threads` in app settings
- Each thread has a unique ID: `thread_${timestamp}`
- Threads are automatically sorted by `lastMessageAt` timestamp
- The `_saveThreads()` method is called after every thread creation/modification
