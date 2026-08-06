---
inclusion: auto
description: Mandatory process rules, past mistakes log, and golden rules that must be read before making any code changes to this project.
---

# 🚨 READ THIS FIRST BEFORE MAKING ANY CHANGES 🚨

## MANDATORY PROCESS FOR ALL CODE CHANGES

### Step 1: ALWAYS Check Git History First
```bash
# Before touching ANY file, run these commands:
git log --oneline -20 -- <file_path>
git show <last_working_commit>:<file_path>
```

**NEVER modify code without checking what worked before!**

### Step 2: Compare Current vs Last Working Version
- Look for what was added that broke things
- Look for what was removed that was needed
- Identify the minimal change needed
- **CHECK ALL RELATED METHODS - not just one!**
- Search for all occurrences of the functionality

### Step 3: Only Overlay Fixes - NEVER Delete Working Code
- ✅ DO: Add new functionality alongside existing code
- ✅ DO: Compare ENTIRE file, not just one method
- ✅ DO: Save working version to compare: `git show <commit>:<file> > working_version.dart`
- ❌ DON'T: Delete or refactor working logic
- ❌ DON'T: "Improve" code that already works
- ❌ DON'T: Add "smart" features without user request
- ❌ DON'T: Assume fixing one method fixes all related methods

---

## 📋 PAST MISTAKES LOG - LEARN FROM THESE

### Mistake #1: AI Chat Title Generation (June 16, 2026)

**What Happened:**
- Replaced simple `_generateThreadTitle()` with complex AI-powered title generation
- Added `_generateAITitle()` that made extra AI calls
- Used `ConversationThread.generateTitle()` with complex logic
- Result: Extra messages in conversation, delays, side effects

**What Broke:**
- Title generation created noise in conversations
- New chat button was blocked with validation
- Added cleanup logic that wasn't in working version

**The Fix:**
- Restored simple `_generateThreadTitle()` from commit `b5e605d`
- Removed AI-powered title generation
- Removed blocking validation in UI components
- Kept it SIMPLE like the working version

**Lesson Learned:**
> "Simple is better. If it works, don't fix it. Check git history FIRST."

**Working Code Reference:**
- File: `lib/services/unified_ai_chat_service.dart`
- Commit: `b5e605d` - "Revert thread creation changes - restore to working state"
- Method: `_generateThreadTitle()` - simple string truncation
- Title timing: `if (thread.messages.length == 1)`

---

## 🎯 GOLDEN RULES

### Rule #1: Git History is Your Friend
**Before ANY change:** `git log --oneline -20 -- <file>`

### Rule #2: Simple > Complex
If the working version is simple, keep it simple. Don't over-engineer.

### Rule #3: Preserve > Replace
Add new code alongside old code. Don't delete working logic.

### Rule #4: Test > Assume
Don't assume your "improvement" is better. The working version is proven.

### Rule #5: Document Mistakes
When you break something, document it HERE so you never repeat it.

---

## 📖 CRITICAL FILES - EXTRA CAUTION REQUIRED

### 1. `lib/services/unified_ai_chat_service.dart`
**Status:** Fragile - broke on June 16, 2026
**Last Good Commit:** `b5e605d`
**Critical Methods:**
- `_createNewThread()` - keep simple, no cleanup logic
- `_generateThreadTitle()` - simple truncation only
- `sendMessage()` / `sendMessageStream()` - don't add AI calls

**Before touching:** `git show b5e605d:lib/services/unified_ai_chat_service.dart`

### 2. `lib/widgets/floating_ai_assistant.dart`
**Critical Methods:**
- `_createNewThread()` - NO validation, NO blocking

### 3. `lib/screens/settings/ai_settings_screen.dart`
**Critical Methods:**
- `_createNewThread()` - NO validation, NO blocking

### 4. `lib/screens/workout/web_pose_view_web.dart`
**Critical Imports:**
```dart
import 'dart:js' as js;
import 'dart:js_util' as js_util;  // REQUIRED for allowInterop
```
**Usage:** `js_util.allowInterop()` NOT `js.allowInterop()`
**Last Issue:** June 16, 2026 - Used wrong import, caused compilation error

---

## ⚠️ WARNING SIGNS YOU'RE ABOUT TO BREAK SOMETHING

Stop immediately if you're about to:
- ❌ Delete a method without checking git history
- ❌ Add validation that blocks user actions
- ❌ Make extra AI calls for "better" results
- ❌ Add cleanup logic that wasn't there before
- ❌ "Refactor" working code to be "cleaner"
- ❌ Change logic flow without comparing to working version
- ❌ Fix only ONE method when multiple methods use the same logic
- ❌ Assume all related methods work the same way

---

## ✅ SAFE PRACTICES

Do this instead:
- ✅ Check `git log` before any change
- ✅ Compare current vs last working commit
- ✅ Add new features alongside existing code
- ✅ Keep working logic intact
- ✅ Test thoroughly after changes
- ✅ Document what you changed and why

---

## 🔄 WHEN SOMETHING BREAKS

1. **Don't panic** - working code exists in git history
2. **Find last working commit:** `git log --oneline -20 -- <file>`
3. **View working code:** `git show <commit>:<file>`
4. **Compare differences:** What was added? What was removed?
5. **Restore working code** with minimal overlay fixes only
6. **Document the mistake** in this file under "Past Mistakes Log"

---

## 📝 TEMPLATE FOR DOCUMENTING NEW MISTAKES

```markdown
### Mistake #X: [Brief Description] (Date)

**What Happened:**
- [Describe what changes were made]

**What Broke:**
- [List what stopped working]

**The Fix:**
- [Describe how it was fixed]

**Lesson Learned:**
> "[One sentence summary]"

**Working Code Reference:**
- File: [file path]
- Commit: [commit hash]
- Key details: [important notes]
```

---

## 🎓 REMEMBER

> **"The best code is code that works. The second best is code that works and you understand. The worst is code you 'improved' without understanding why it worked in the first place."**

**Always ask yourself:**
1. Why did the previous developer write it this way?
2. What will break if I change this?
3. Did I check git history?
4. Is this change actually needed?
5. Am I fixing a problem or creating one?

---

## 🚀 START HERE FOR EVERY TASK

Before you write ANY code:

1. ✅ Read this file completely
2. ✅ Check git history for files you'll modify
3. ✅ Compare current vs last working version
4. ✅ Understand why the working version works
5. ✅ Make minimal changes only
6. ✅ Test thoroughly
7. ✅ Document any new mistakes you discover

**Good luck, and remember: Simple. Careful. Documented.**

---

### Mistake #2: Incomplete Fix - Still Calling _generateAITitle (June 16, 2026 - Second Attempt)

**What Happened:**
- Fixed `sendMessageStream()` but forgot to fix `sendMessage()`
- Left the call to `_generateAITitle()` in `sendMessage()` method
- Changed `thread.messages.length == 1` to `isFirstMessage` variable
- Result: Titles were STILL being generated twice with different logic

**What Broke:**
- Title generation inconsistent - created twice with different methods
- Simple `_generateThreadTitle()` ran first (good)
- Then `_generateAITitle()` replaced it with `ConversationThread.generateTitle()` (bad)
- User saw the problem still existed

**The Fix:**
- Removed `isFirstMessage` variable
- Changed back to `if (thread.messages.length == 1)` 
- Removed `await _generateAITitle(thread, message, response);` call
- Deleted entire `_generateAITitle()` method
- Now exactly matches commit `b5e605d`

**Lesson Learned:**
> "When reverting to a working version, check ALL methods that use the functionality. Don't assume fixing one method is enough."

**Working Code Reference:**
- File: `lib/services/unified_ai_chat_service.dart`
- Commit: `b5e605d`
- Key: ONLY `_generateThreadTitle()` is called, NEVER `_generateAITitle()`
- Check: `if (thread.messages.length == 1)` not `if (isFirstMessage)`

**Why This Happened:**
- I only checked `sendMessageStream()` in git history
- I didn't check `sendMessage()` thoroughly
- I assumed both methods were the same
- I didn't compare ENTIRE file with working commit

**Prevention:**
- When reverting, use: `git show b5e605d:lib/services/unified_ai_chat_service.dart > working.dart`
- Then compare ENTIRE file, not just one method
- Search for ALL occurrences of related functionality
- Don't assume - verify every related method

---

### Mistake #3: Wrong allowInterop Import (June 16, 2026)

**What Happened:**
- Tried to use `js.allowInterop()` syntax
- Got error: "The function 'allowInterop' isn't defined"
- Needed to import `dart:js_util` package

**What Broke:**
- Web pose detection callback registration failed
- Compilation error in web_pose_view_web.dart

**The Fix:**
- Added `import 'dart:js_util' as js_util;`
- Changed `js.allowInterop()` to `js_util.allowInterop()`

**Lesson Learned:**
> "In dart:js for web, allowInterop is in dart:js_util, not dart:js. Always check which package exports the function."

**Working Code Reference:**
- File: `lib/screens/workout/web_pose_view_web.dart`
- Required imports:
  ```dart
  import 'dart:js' as js;
  import 'dart:js_util' as js_util;
  ```
- Usage: `js_util.allowInterop((callback) { ... })`

**Prevention:**
- When using dart:js functions, check the documentation
- `allowInterop` is always in `dart:js_util`
- Don't assume all JS interop is in `dart:js`

---

### Mistake #4: Unrealistic Credit Pricing - Not Checking Actual API Costs (June 17, 2026)

**What Happened:**
- Set credit costs based on arbitrary "industry standard" markups
- Charged 20 credits ($1.20) for image generation
- Charged 5 credits ($0.30) for image analysis
- Charged 1 credit ($0.06) for basic chat
- Never verified actual Gemini API costs
- Created exploitative pricing with 1000x+ markups

**What Broke (User Experience):**
- Users felt nickel-and-dimed
- Basic features like meal tracking cost too much
- Image generation too expensive for regular use
- Free users couldn't actually use the app daily
- No incentive to build daily habit

**The Reality Check:**
- Gemini 2.0 Flash: $0.10 per 1M input tokens, $0.40 per 1M output
- Average chat message: $0.00013 (0.013 cents!)
- Image analysis: $0.00018 (0.018 cents!)
- Image generation (Imagen): $0.04 (4 cents)
- Video generation (Veo): $0.30 (30 cents)

**Old vs New Pricing:**
| Feature | Old Cost | Actual API | Old Markup | New Cost | New Markup |
|---------|----------|------------|------------|----------|------------|
| Chat | 1 credit ($0.06) | $0.00013 | 460x | FREE | 0x |
| Image Analysis | 5 credits ($0.30) | $0.00018 | 1666x | FREE | 0x |
| Image Gen | 20→10 credits | $0.04 | 300x→150x | 5 credits ($0.30) | 7.5x |
| Video Gen | 50→25 credits | $0.30 | 250x→125x | 25 credits ($1.50) | 5x |

**The Fix:**
- Made ALL basic features FREE (chat, analysis, form checks, recipes, motivation)
- Image generation: 5 credits ($0.30) - fair 7.5x markup
- Video generation: 25 credits ($1.50) - fair 5x markup
- Plans: 1 credit ($0.06) - fair 30x markup
- Focus profit on volume + subscriptions, not exploitative per-use fees

**Business Model Change:**
```
OLD: High per-use costs → User avoids using app → No habit → No subscription
NEW: Free daily use → User builds habit → Sees value → Subscribes for premium
```

**User Value Now (50 credits = $2.99):**
- OLD: 2-3 image generations, 10 chat messages, 10 analyses
- NEW: 10 images + UNLIMITED chat + UNLIMITED analysis + 50 plans!

**Lesson Learned:**
> "Always verify actual API costs before setting prices. Gemini is SO cheap that profit comes from volume and subscriptions, not exploitative markups. Fair pricing builds trust and loyalty."

**Working Code Reference:**
- File: `lib/models/ai_feature_costs.dart`
- Documentation: `REALISTIC_PRICING_FINAL.md`, `GEMINI_ACTUAL_COST_ANALYSIS.md`
- Key principle: Make daily features FREE, charge fairly for generation features
- Markup targets: 5-30x for paid features (not 1000x!)

**Prevention:**
- ALWAYS check actual API pricing before setting user costs
- Google "Gemini API pricing" or "Imagen pricing" or "[service] API cost"
- Calculate markup: (Your Price / API Cost) = should be 5-30x, not 1000x
- Think long-term: Volume + subscriptions > per-use exploitation
- Ask: "Would I pay this price if I were the user?"

**Key Resources:**
- Gemini pricing: https://ai.google.dev/gemini-api/docs/pricing
- Imagen pricing: https://cloud.google.com/vertex-ai/generative-ai/pricing
- Rule of thumb: If markup > 100x, you're probably overcharging

---

### Mistake #5: Critical Behavioral Bugs - AI Chat Screen Not Truly "Alike" (June 17, 2026)

**What Happened:**
- Claimed ai_chat_screen.dart and floating_ai_assistant.dart were "alike"
- Actually had 6 critical behavioral inconsistencies
- Some were functional bugs that would burn credits and make unwanted AI calls

**Critical Bugs Found:**

1. **Unwanted AI calls before confirmation** 🔥
   - `_handleImageGeneration()` called `await _chatService.sendMessage(prompt)`
   - This sent the original prompt to AI and got a real response
   - Burned API calls/credits BEFORE user confirmed!
   - Same issue in yes/no handling - "yes"/"no" got sent to AI

2. **Video/audio confirmations never fired** 🔥
   - Yes branch only checked `if (lastMessage.pendingAction == 'generate_image')`
   - No `else if` for 'generate_video' or 'generate_audio'
   - Confirming video/audio silently did nothing
   - `_executeVideoGeneration`/`_executeAudioGeneration` defined but never called

3. **Credit source mismatch** 💰
   - Used old `CreditsService.creditsPerVideoGeneration` (5 credits)
   - Should use `AIFeatureCosts.videoGeneration` (25 credits)
   - Used old `CreditsService.creditsPerAudioGeneration` (3 credits)
   - Should use `AIFeatureCosts.audioGeneration` (10 credits)
   - Inconsistent with "ultra-fair" pricing rollout

4. **Detection keywords differ**
   - floating_ai_assistant checks: image/picture/photo/illustration/design/poster/logo/art
   - ai_chat_screen only checks: image/picture/photo/illustration
   - Same phrase could trigger in one screen but not the other

5. **Credit deduction differs**
   - ai_chat_screen explicitly checks and deducts credits before generating
   - floating_ai_assistant just calls generateImage with no deduction
   - Either one is generating for free or deduction happens elsewhere

6. **Message building inconsistent**
   - ai_chat_screen called `_chatService.sendMessage()` for errors/confirmations
   - floating_ai_assistant built ChatMessage objects manually
   - sendMessage triggers AI responses - wrong for static messages

**The Fix:**
- Rewrote all confirmation handlers to build messages manually
- NO calls to `_chatService.sendMessage()` during confirmation flow
- Used `_chatService.initialize()` for persistence only
- Updated yes/no handling to use Set-based matching (faster)
- Added switch statement for all pending actions (image/video/audio)
- Updated all credit costs to use `AIFeatureCosts` constants
- Added all detection keywords (design/poster/logo/art)
- Made both screens build messages identically

**Working Pattern:**
```dart
// CORRECT: Build messages manually, persist only
final userMessage = ChatMessage(role: 'user', content: prompt, ...);
final confirmMessage = ChatMessage(role: 'assistant', content: '⚠️...', ...);
setState(() {
  final mutableMessages = List<ChatMessage>.from(_thread!.messages)
    ..add(userMessage)
    ..add(confirmMessage);
  _thread = ConversationThread(...);
});
await _chatService.initialize(); // Persist only - NO AI call

// WRONG: This makes a real AI call
await _chatService.sendMessage(prompt); // ❌ Burns credits/API before user confirms!
```

**Lesson Learned:**
> "When claiming two implementations are 'alike', verify behavioral equivalence, not just API similarity. Check: (1) Does it call AI when it shouldn't? (2) Does it use the right pricing constants? (3) Does it handle all cases? (4) Does it build messages the same way?"

**Working Code Reference:**
- File: `lib/screens/ai_chat/ai_chat_screen.dart`
- File: `lib/widgets/floating_ai_assistant.dart`
- Pattern: Manual message building + `initialize()` for persistence
- Switch statement: Handles all pending actions (image/video/audio)
- Credit source: Always use `AIFeatureCosts.*` not `CreditsService.creditsPerX`

**Prevention:**
- When updating two screens to be "alike", diff the actual implementation
- Check if methods with similar names behave identically
- Verify credit costs come from same source
- Test all code paths (not just happy path)
- Check keyword lists are identical
- Verify no unintended AI calls in confirmation flows

**Testing Checklist:**
- [ ] "Create an image" → Shows warning, NO AI call
- [ ] Reply "yes" → Generates image, NO AI reply to "yes"
- [ ] Reply "no" → Cancels, static "No problem" message
- [ ] "Create a video" → Works same as image
- [ ] "Generate audio" → Works same as image
- [ ] All features use AIFeatureCosts pricing
- [ ] Keywords match across screens

---

*Last Updated: June 17, 2026*
*Total Mistakes Documented: 5*
*Files Broken and Fixed: 6*
