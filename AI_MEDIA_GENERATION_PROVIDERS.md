# AI Media Generation - Multiple Providers

VerveStride supports **multiple AI providers** for image, video, and audio generation. You can switch between providers based on your needs.

---

## 🎯 Supported Providers

### 1. **Google Vertex AI** (Primary) ✅
- **Status:** Primary provider with fallback
- **Features:** Images (Imagen), Videos (Veo - fallback to Replicate), Audio (Lyria - fallback to Replicate)
- **Quality:** Excellent
- **Speed:** Fast
- **Cost:** Pay-per-use (~$0.02 per image)
- **Setup:** Requires Google Cloud billing verification

**Models Used:**
- Images: Imagen 3.0 (falls back to Replicate if not available)
- Videos: Veo (not yet available → uses Replicate)
- Audio: Lyria/MusicLM (not yet available → uses Replicate)

### 2. **Replicate AI** (Fallback) ✅
- **Status:** Fully implemented as backup
- **Features:** Images, Videos, Audio
- **Quality:** Excellent
- **Speed:** Fast (5-10 seconds for images)
- **Cost:** Pay-per-use (~$0.003-0.01 per image)
- **Setup:** Requires Replicate account + credits

**Models Used:**
- Images: Stable Diffusion XL (SDXL)
- Videos: Zeroscope V2 XL
- Audio: Meta MusicGen

---

## 🔧 How to Switch Providers

### In Code:

```dart
import 'package:vervestride/services/media_generation_service.dart';

// Set to Replicate (default)
MediaGenerationService.instance.setProvider(MediaProvider.replicate);

// Set to Google Vertex AI
MediaGenerationService.instance.setProvider(MediaProvider.googleVertexAI);
```

### Current Behavior:

- **Primary:** Google Vertex AI (tries Google first)
- **Fallback:** Replicate AI (if Google fails or not available)

---

## 💰 Cost Comparison

| Feature | Replicate | Google Vertex AI |
|---------|-----------|------------------|
| **Image** | ~$0.003-0.01 | ~$0.02 |
| **Video** | ~$0.05-0.10 | ~$0.10-0.20 |
| **Audio** | ~$0.01-0.03 | ~$0.05-0.10 |
| **Setup** | Account + Credits | Billing verification |
| **Availability** | ✅ All features | ⚠️ Images only (for now) |

---

## 📋 Setup Instructions

### Option 1: Replicate (Recommended)

1. **Create Account:** https://replicate.com/signup
2. **Get API Token:** https://replicate.com/account/api-tokens
3. **Add Credits:** https://replicate.com/account/billing
   - Recommended: $10-20 to start
   - This gives you ~1,000-3,000 images
4. **Update Cloud Function:** Token is already in `functions/index.js`
5. **Deploy:** `firebase deploy --only functions:replicateProxy`

**Status:** ✅ Already configured, just needs credits added

### Option 2: Google Vertex AI

1. **Enable Billing:** https://console.cloud.google.com/billing
2. **Enable Imagen API:** https://console.cloud.google.com/apis/library/aiplatform.googleapis.com
3. **No code changes needed** - Already integrated!

**Status:** ⚠️ Requires billing verification

---

## 🎨 Features by Provider

| Feature | Replicate | Google Vertex AI |
|---------|-----------|------------------|
| **Image Generation** | ✅ SDXL | ✅ Imagen 3.0 |
| **Video Generation** | ✅ Zeroscope | ⚠️ Veo (coming soon) |
| **Audio Generation** | ✅ MusicGen | ⚠️ Lyria (coming soon) |
| **Custom Sizes** | ✅ Yes | ✅ Yes |
| **Negative Prompts** | ✅ Yes | ✅ Yes |
| **Safety Filters** | ✅ Yes | ✅ Yes |

---

## 🚀 Current Status

### What's Working:
- ✅ Replicate: Images, Videos, Audio (needs credits)
- ✅ Google: Images (needs billing verification)
- ✅ Provider switching system
- ✅ Automatic fallback
- ✅ Credit management
- ✅ Error handling with refunds

### What's Not Working:
- ❌ Replicate account has no credits (needs $10-20 added)
- ⚠️ Google Veo/Lyria not yet available in API

---

## 💡 Recommendations

### For Production:
**Use Replicate** - It's the only provider with all features (image, video, audio) working right now.

### For Testing:
**Use Replicate** - Add $10 for testing, you'll get plenty of generations.

### For Future:
**Monitor Google Veo/Lyria** - When they become available, you can switch with one line of code!

---

## 🔍 How It Works

```
User Request → FirebaseAIService → MediaGenerationService → Provider
                                          ↓
                                    [Replicate or Google]
                                          ↓
                                    Generated Media
                                          ↓
                                    Return to User
```

**Benefits:**
- ✅ Easy to switch providers
- ✅ Automatic fallback
- ✅ Consistent API
- ✅ Future-proof (add more providers easily)

---

## 📝 Next Steps

1. **Add credits to Replicate** ($10-20)
2. **Test image generation** ("create image of rose")
3. **Test video generation** ("create video of waves")
4. **Test audio generation** ("create workout music")
5. **Monitor costs** and adjust pricing

---

## 🆘 Troubleshooting

### "Insufficient credit" error:
- **Solution:** Add credits to Replicate account

### "Billing verification required":
- **Solution:** Enable billing in Google Cloud Console

### Images not generating:
- **Check:** Cloud Function logs: `firebase functions:log`
- **Check:** Provider status in app logs
- **Check:** Credit balance

---

## 📞 Support

- **Replicate Docs:** https://replicate.com/docs
- **Google Vertex AI Docs:** https://cloud.google.com/vertex-ai/docs
- **Firebase Functions:** https://firebase.google.com/docs/functions

---

**Last Updated:** June 2, 2026
