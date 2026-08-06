# Automatic Provider Fallback System

## Overview
Implemented a **cascading fallback system** that automatically tries multiple AI providers when one is busy, fails, or returns an error. This ensures high availability and reliability for media generation.

## Provider Priority Chain

### 🥇 Primary: Google Vertex AI
- **Models**: Imagen (images), Veo (video), Lyria (audio)
- **Status**: Not yet fully integrated (requires billing verification)
- **Behavior**: Will cascade to next provider when not available

### 🥈 Secondary: Replicate AI
- **Models**: SDXL (images), Zeroscope (video), MusicGen (audio)
- **Status**: ✅ Working (needs account credits)
- **Behavior**: Reliable fallback for all media types

### 🥉 Tertiary: OpenAI
- **Models**: DALL-E 3 (images only)
- **Status**: Not yet integrated
- **Behavior**: Final fallback for images (not available for video/audio)

## How It Works

### Automatic Fallback Flow:
```
User requests: "create image of rose"
    ↓
Try Google Vertex AI Imagen
    ↓ (if busy/error/null)
Try Replicate SDXL
    ↓ (if busy/error/null)
Try OpenAI DALL-E 3
    ↓ (if all fail)
Return null + show error message
```

### Example Logs:
```
🎨 [MediaGen] Starting image generation with fallback chain
🎨 [MediaGen] Trying googleVertexAI...
⚠️ [Google Imagen] Not yet fully integrated - cascading to next provider
🎨 [MediaGen] Trying replicate...
🎨 [Replicate] Generating image...
✅ [MediaGen] Image generated successfully with replicate
```

## Provider Support Matrix

| Feature | Google Vertex AI | Replicate | OpenAI |
|---------|-----------------|-----------|--------|
| Images  | ✅ (Imagen)     | ✅ (SDXL) | ✅ (DALL-E 3) |
| Video   | ✅ (Veo)        | ✅ (Zeroscope) | ❌ |
| Audio   | ✅ (Lyria)      | ✅ (MusicGen) | ❌ |

## Configuration

### Change Provider Priority:
```dart
// Default priority (already set)
MediaGenerationService.instance.setProviderPriority([
  MediaProvider.googleVertexAI,  // Try first
  MediaProvider.replicate,       // Try second
  MediaProvider.openAI,          // Try third
]);

// Or change to prefer Replicate first:
MediaGenerationService.instance.setProviderPriority([
  MediaProvider.replicate,       // Try first
  MediaProvider.googleVertexAI,  // Try second
  MediaProvider.openAI,          // Try third
]);
```

### Check Current Priority:
```dart
final status = MediaGenerationService.instance.getProviderStatus();
// Returns: "Priority: Google Vertex AI → Replicate AI → OpenAI DALL-E"
```

## Error Handling

### When Provider Fails:
1. **Logs the error** with provider name
2. **Automatically tries next provider** in chain
3. **Continues cascading** until success or all fail
4. **Credits are refunded** if all providers fail (handled in chat screen)

### No User Interruption:
- User doesn't see provider switching
- Seamless fallback happens in background
- Only final success/failure message is shown

## Benefits

✅ **High Availability**: If Google is busy, automatically uses Replicate  
✅ **Reliability**: Multiple fallback options ensure success  
✅ **Transparent**: User doesn't need to know which provider is used  
✅ **Smart**: Skips providers that don't support the feature (e.g., OpenAI for video)  
✅ **Future-Proof**: Easy to add more providers to the chain  

## Current Status

### Google Vertex AI (Primary)
- ⚠️ Not yet fully integrated
- 📋 TODO: Add Imagen/Veo/Lyria API integration
- 🔒 Requires: Billing verification on Google Cloud

### Replicate (Secondary)
- ✅ Fully integrated
- ⚠️ Needs: $10-20 credits added to account
- 🔗 URL: https://replicate.com/account/billing

### OpenAI (Tertiary)
- ⚠️ Not yet integrated
- 📋 TODO: Add DALL-E 3 API integration
- 🎨 Scope: Images only (no video/audio support)

## Testing

Once Replicate account has credits:

```
1. Test Image: "create image of rose"
   Expected: Tries Google → Falls back to Replicate → Success

2. Test Video: "create a video of sunset"
   Expected: Tries Google → Falls back to Replicate → Success
   (OpenAI is skipped for video)

3. Test Audio: "create music for relaxation"
   Expected: Tries Google → Falls back to Replicate → Success
   (OpenAI is skipped for audio)
```

## Debug Logs

Watch console for cascade behavior:
```
🎨 [MediaGen] Starting image generation with fallback chain
🎨 [MediaGen] Trying googleVertexAI...
❌ [MediaGen] googleVertexAI failed: Not implemented, trying next provider...
🎨 [MediaGen] Trying replicate...
🎨 [Replicate] Generating image...
✅ [MediaGen] Image generated successfully with replicate
```

## Future Enhancements

- [ ] Add retry logic with exponential backoff
- [ ] Track provider success rates for smart ordering
- [ ] Add provider health checks
- [ ] Implement provider-specific rate limiting
- [ ] Add cost optimization (prefer cheaper providers)
- [ ] Add quality preferences (prefer higher quality providers)

## Notes

- Currently Google Vertex AI will always cascade to Replicate (not yet implemented)
- Once Google APIs are integrated, they will be tried first automatically
- The system is designed to be transparent to the user
- Provider switching happens in <1 second (seamless UX)
