# Inline Confirmation for Media Generation

## Overview
Replaced popup dialogs with inline chat confirmation messages for image, video, and audio generation. Users now see credit cost confirmation directly in the chat with action buttons, creating a more seamless ChatGPT-like experience.

## Changes Made

### 1. **Model Updates** (`lib/models/conversation_thread.dart`)
Added support for pending actions in chat messages:
- `pendingAction`: String indicating the action awaiting confirmation (e.g., 'generate_image')
- `pendingData`: Map containing data needed for the action (prompt, duration, etc.)
- `hasPendingAction`: Getter to check if message has pending action

### 2. **Widget Updates** (`lib/widgets/ai_message_content.dart`)
Enhanced the message content widget to display action buttons:
- Added `onActionTap` callback parameter
- Added inline action buttons (Generate/Cancel) when `hasPendingAction` is true
- Buttons are styled to match the app theme with clear visual hierarchy

### 3. **Chat Screen Updates** (`lib/screens/ai_chat/ai_chat_screen.dart`)

#### Removed Old Approach:
- ❌ Removed duration asking flow (separate messages for duration)
- ❌ Removed `_awaitingVideoDuration`, `_awaitingAudioDuration` state variables
- ❌ Removed `_pendingVideoPrompt`, `_pendingAudioPrompt` state variables
- ❌ Removed `_handleVideoDurationResponse()` and `_handleAudioDurationResponse()` methods

#### Added New Approach:
- ✅ **Inline Confirmation Messages**: Show credit cost and action details in chat
- ✅ **Action Buttons**: [Generate] and [Cancel] buttons appear inline
- ✅ **Credit Deduction with Refund**: Deduct credits before generation, refund on failure
- ✅ **Default Durations**: Use sensible defaults (10s video, 30s audio) - no need to ask
- ✅ **Execution Methods**: Separate execute methods that run after user confirms

#### New Methods:
- `_handleActionTap()`: Central handler for all action button clicks
- `_executeImageGeneration()`: Execute image generation after confirmation
- `_executeVideoGeneration()`: Execute video generation after confirmation
- `_executeAudioGeneration()`: Execute audio generation after confirmation

## User Flow Example

### Before (Old Popup Approach):
```
User: "create image of rose"
[POPUP DIALOG APPEARS]
Dialog: "This will use 1 credit. Continue?"
User clicks "Yes" in popup
AI: "🎨 Generating..."
```

### After (New Inline Approach):
```
User: "create image of rose"

AI: "🎨 I'll generate an image based on: 'create image of rose'

💳 This will use **1 credit** (≈$0.06)

Ready to create your image?

[Generate Image] [Cancel]"

User clicks [Generate Image]

AI: "🎨 Generating your image..."

AI: "✅ Image generated successfully!
[IMAGE DISPLAYED]"
```

## Credit Management

### Credit Costs:
- **Image**: 1 credit (~$0.06)
- **Video**: 5 credits (~$0.30)
- **Audio**: 3 credits (~$0.18)

### Credit Flow:
1. **Check**: Verify sufficient credits before showing confirmation
2. **Confirm**: Show inline confirmation with cost
3. **Deduct**: Deduct credits when user clicks [Generate]
4. **Generate**: Call the generation service
5. **Refund**: Automatically refund credits if generation fails

### Error Handling:
- Insufficient credits → Show error message with link to purchase
- Generation failure → Refund credits + show error
- API error → Refund credits + show error with details

## Default Settings

To avoid asking for duration every time:

- **Video**: Default 10 seconds (user can request longer/shorter later)
- **Audio**: Default 30 seconds (user can request longer/shorter later)
- **Image**: No duration needed

Users can always ask for variations with different parameters after seeing the result.

## Benefits

1. **No Popup Interruption**: Everything happens in the chat flow
2. **Transparent Pricing**: Credit cost shown before generation
3. **Clear Actions**: Visual buttons make it obvious what to do next
4. **Better UX**: Matches ChatGPT/Gemini inline confirmation pattern
5. **Fail-Safe**: Automatic credit refund on any failure
6. **Simpler Flow**: No need to ask for duration separately

## Testing Checklist

- [ ] Image generation shows inline confirmation
- [ ] Video generation shows inline confirmation  
- [ ] Audio generation shows inline confirmation
- [ ] Cancel button works and shows cancellation message
- [ ] Generate button deducts credits correctly
- [ ] Credits are refunded on generation failure
- [ ] Insufficient credits shows proper error message
- [ ] Generated media displays correctly in chat
- [ ] Action buttons have proper styling
- [ ] Multiple pending actions can exist (edge case)

## Next Steps

Once Replicate account has credits added:
1. Test image generation: "create image of rose"
2. Test video generation: "create a video of sunset"
3. Test audio generation: "create music for relaxation"
4. Verify credit deduction and refund work correctly
5. Test cancel button functionality

## Notes

- The inline confirmation approach is more user-friendly than popups
- Default durations keep the flow simple (users can request changes later)
- Credit refund on failure ensures users aren't charged for failed operations
- The implementation follows ChatGPT's pattern for action confirmations
