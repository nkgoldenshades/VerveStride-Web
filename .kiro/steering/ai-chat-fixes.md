# AI Chat System - Critical Rules

## ⚠️ CRITICAL: Always Check Git History Before Making Changes

**NEVER delete or refactor working code without checking git history first!**

### Required Process:
1. **ALWAYS run `git log --oneline -20 -- <file>` first**
2. **ALWAYS check previous working commit with `git show <commit>:<file>`**
3. **ONLY overlay fixes - DO NOT delete existing working logic**
4. **Preserve all existing functionality**

## Working Code Reference

### Last Known Good State
- **Commit**: `b5e605d` - "Revert thread creation changes - restore to working state"
- **File**: `lib/services/unified_ai_chat_service.dart`

### Critical Methods (DO NOT MODIFY CORE LOGIC):

#### 1. `_createNewThread()` - Keep Simple
```dart
Future<ConversationThread> _createNewThread() async {
  final thread = ConversationThread(
    id: 'thread_${DateTime.now().millisecondsSinceEpoch}',
    title: 'New Conversation',
    createdAt: DateTime.now(),
    lastMessageAt: DateTime.now(),
    messages: [],
  );
  
  _activeThread = thread;
  _allThreads.insert(0, thread);
  
  await _saveThreads();
  _notifyListeners();
  
  debugPrint('🧵 Created new unified thread: ${thread.id}');
  return thread;
}
```

**DO NOT:**
- ❌ Add cleanup logic that removes empty threads
- ❌ Add extra debug logs that weren't there before
- ❌ Add validation that blocks thread creation
- ❌ Change the basic flow

#### 2. `_generateThreadTitle()` - Use Simple Local Method
```dart
String _generateThreadTitle(String message) {
  // Clean and truncate message for title
  final cleaned = message.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (cleaned.length <= 30) return cleaned;
  
  // Find a good break point
  final words = cleaned.split(' ');
  String title = '';
  for (final word in words) {
    if ((title + word).length > 27) break;
    title += (title.isEmpty ? '' : ' ') + word;
  }
  
  return title.isEmpty ? '${cleaned.substring(0, 27)}...' : '$title...';
}
```

**DO NOT:**
- ❌ Make extra AI calls to generate titles
- ❌ Call `ConversationThread.generateTitle()` which has complex logic
- ❌ Use `_generateAITitle()` which creates side effects

#### 3. Title Generation Timing
```dart
// In sendMessage() and sendMessageStream():
if (thread.messages.length == 1) {
  thread.title = _generateThreadTitle(message);
}
```

**DO NOT:**
- ❌ Generate titles before checking message count
- ❌ Call AI to generate titles (creates noise in conversation)
- ❌ Use complex title generation logic

### UI Components - No Blocking Logic

#### Floating AI Assistant (`lib/widgets/floating_ai_assistant.dart`)
```dart
void _createNewThread() async {
  // Allow creating new thread anytime - NO VALIDATION
  final newThread = await _chatService.createNewThread();
  // ... update UI
}
```

#### AI Settings Screen (`lib/screens/settings/ai_settings_screen.dart`)
```dart
Future<void> _createNewThread() async {
  // Allow creating new thread anytime - NO VALIDATION
  final newThread = await _chatService.createNewThread();
  // ... update UI
}
```

**DO NOT:**
- ❌ Check if current thread is empty before allowing new thread
- ❌ Check if AI has generated a title before allowing new thread
- ❌ Block user from creating new conversations
- ❌ Show orange warning snackbars that prevent action

## Common Mistakes to Avoid

### ❌ MISTAKE 1: Adding "Smart" Cleanup Logic
```dart
// DON'T DO THIS:
void _cleanupEmptyThreads() {
  final emptyThreads = _allThreads.where((t) => t.messages.isEmpty).toList();
  // ... remove empty threads
}
```
**Why**: This creates unexpected behavior and wasn't in working version.

### ❌ MISTAKE 2: Calling AI to Generate Titles
```dart
// DON'T DO THIS:
Future<void> _generateAITitle() async {
  final titlePrompt = '''Generate a title...''';
  final generatedTitle = await _sessionManager.sendMessage(titlePrompt);
  // ...
}
```
**Why**: This creates extra messages in the conversation and adds delays.

### ❌ MISTAKE 3: Blocking New Thread Creation
```dart
// DON'T DO THIS:
if (_currentThread != null && _currentThread!.messages.isEmpty) {
  // Show error and return
  return;
}
```
**Why**: Users should be able to create new threads anytime.

### ❌ MISTAKE 4: Over-Engineering Simple Logic
```dart
// DON'T DO THIS:
final isFirstMessage = thread.messages.isEmpty;
if (isFirstMessage) {
  thread.title = ConversationThread.generateTitle(message);
  await _saveThreads();
  _notifyListeners();
}
```
**Why**: The working version uses `thread.messages.length == 1` check and simple `_generateThreadTitle()`.

## Debugging Process

When AI chat issues occur:

1. **Check git history FIRST**
   ```bash
   git log --oneline -20 -- lib/services/unified_ai_chat_service.dart
   git show b5e605d:lib/services/unified_ai_chat_service.dart
   ```

2. **Compare current vs working version**
   - Look for added validation logic
   - Look for extra AI calls
   - Look for cleanup functions
   - Look for blocking conditions

3. **Restore working code**
   - Copy exact working methods
   - Only overlay minimal fixes
   - Don't "improve" working logic

4. **Test the basics**
   - Can create new thread? ✓
   - Does title generate? ✓
   - No extra messages? ✓
   - No blocking warnings? ✓

## Summary

> **"If it's working, don't fix it. If you must fix something, check git history first and only overlay changes without deleting working logic."**

**Golden Rule**: Simple is better. The working version is simple. Keep it simple.
