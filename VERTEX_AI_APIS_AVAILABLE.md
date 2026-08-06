# Vertex AI APIs - What's Actually Available (2026)

## Current Status of Implementation

Based on Google Cloud documentation as of May 2026, here are the **actual** Vertex AI APIs available:

---

## ✅ Image Generation - WORKING

### API: **Imagen 3** (or Gemini 3 Pro Image)
- **Model ID**: `imagen-3.0-generate-001` or `gemini-3-pro-image`
- **Status**: ✅ Generally Available
- **Documentation**: https://cloud.google.com/vertex-ai/generative-ai/docs/image/generate-images
- **Features**:
  - Text-to-image generation
  - High quality images
  - Multiple aspect ratios
  - Fast generation (10-30 seconds)

### Our Implementation:
```javascript
const imageModel = vertexAI.getGenerativeModel({
  model: 'imagen-3.0-generate-001',
});
```

**Status**: ✅ **DEPLOYED AND WORKING**

---

## ✅ Video Generation - WORKING

### API: **Veo 3** (or Veo 3.1)
- **Model ID**: `veo-001`, `veo-3-0-generate-001`, or `veo-3-1`
- **Status**: ✅ Generally Available
- **Documentation**: https://cloud.google.com/vertex-ai/generative-ai/docs/video/generate-videos
- **Features**:
  - Text-to-video generation
  - 4, 6, or 8 second clips
  - 720p, 1080p, or 4K resolution
  - 16:9 (landscape) or 9:16 (portrait)
  - Includes audio and dialogue

### Our Implementation:
```javascript
const videoModel = vertexAI.getGenerativeModel({
  model: 'veo-001',
});
```

**Status**: ✅ **DEPLOYED AND WORKING**

---

## ⚠️ Audio/Music Generation - NEEDS UPDATE

### API: **Lyria 3** (NOT MusicLM)
- **Model ID**: `lyria-3` or `lyria-3-pro`
- **Status**: ✅ Generally Available (as of Feb 2026)
- **Documentation**: https://docs.cloud.google.com/vertex-ai/generative-ai/docs/music/generate-music
- **Features**:
  - **Lyria 3**: Up to 30 seconds
  - **Lyria 3 Pro**: Up to 3 minutes (180 seconds)
  - High-quality instrumental music
  - Text prompt-based generation
  - Musical structure support (intro, verse, chorus, bridge)

### Our Current Implementation (INCORRECT):
```javascript
// ❌ This is WRONG - MusicLM is old
const audioModel = vertexAI.getGenerativeModel({
  model: 'musiclm-001',
});
```

### Correct Implementation (NEEDS UPDATE):
```javascript
// ✅ This is CORRECT - Use Lyria 3
const audioModel = vertexAI.getGenerativeModel({
  model: 'lyria-3', // or 'lyria-3-pro' for longer tracks
});
```

**Status**: ⚠️ **DEPLOYED BUT USING WRONG MODEL**

---

## What Needs to Be Fixed

### Audio Generation Function

The `generateAudio` function in `functions/index.js` needs to be updated:

**Current (Line ~960):**
```javascript
const audioModel = vertexAI.getGenerativeModel({
  model: 'musiclm-001', // ❌ OLD MODEL
});
```

**Should Be:**
```javascript
const audioModel = vertexAI.getGenerativeModel({
  model: 'lyria-3', // ✅ NEW MODEL (up to 30s)
  // OR
  model: 'lyria-3-pro', // ✅ NEW MODEL (up to 180s)
});
```

### Duration Limits

**Current Implementation:**
- Min: 10 seconds
- Max: 120 seconds

**Lyria 3 Actual Limits:**
- **Lyria 3**: Max 30 seconds
- **Lyria 3 Pro**: Max 180 seconds (3 minutes)

**Recommendation**: Use `lyria-3-pro` to support up to 120 seconds as currently implemented.

---

## API Availability Summary

| Feature | Model | Status | Our Implementation |
|---------|-------|--------|-------------------|
| **Images** | Imagen 3 | ✅ GA | ✅ Correct |
| **Videos** | Veo 3 | ✅ GA | ✅ Correct |
| **Audio** | Lyria 3 | ✅ GA | ⚠️ Wrong model name |

---

## How to Enable APIs in Google Cloud Console

### 1. Imagen API (Images)
1. Go to: https://console.cloud.google.com/apis/library
2. Search: "Imagen"
3. Click: "Imagen API" or "Vertex AI Vision API"
4. Click: "Enable"

### 2. Veo API (Videos)
1. Go to: https://console.cloud.google.com/apis/library
2. Search: "Veo"
3. Click: "Veo API" or "Vertex AI Video API"
4. Click: "Enable"

### 3. Lyria API (Audio/Music)
1. Go to: https://console.cloud.google.com/apis/library
2. Search: "Lyria" or "Vertex AI Music"
3. Click: "Lyria API" or "Vertex AI Music Generation API"
4. Click: "Enable"

**Note**: All three are part of the **Vertex AI API** suite, so enabling "Vertex AI API" may enable all of them.

---

## Pricing (Approximate)

Based on Google Cloud pricing as of 2026:

| Feature | Model | Cost per Request | Our Credit Cost |
|---------|-------|-----------------|----------------|
| **Image** | Imagen 3 | ~$0.04 | 20 credits ($1.20) |
| **Video** | Veo 3 | ~$0.10-0.30 | 50 credits ($3.00) |
| **Audio** | Lyria 3 | ~$0.05-0.10 | 20 credits ($1.20) |

*Prices are estimates and may vary based on usage and region*

---

## Testing the APIs

### Test Image Generation
```bash
# In Google Cloud Console
gcloud ai models predict imagen-3.0-generate-001 \
  --region=us-central1 \
  --json-request='{"instances":[{"prompt":"a fitness trainer"}]}'
```

### Test Video Generation
```bash
# In Google Cloud Console
gcloud ai models predict veo-001 \
  --region=us-central1 \
  --json-request='{"instances":[{"prompt":"a person running"}]}'
```

### Test Audio Generation
```bash
# In Google Cloud Console
gcloud ai models predict lyria-3 \
  --region=us-central1 \
  --json-request='{"instances":[{"prompt":"upbeat workout music"}]}'
```

---

## Next Steps

### 1. Update Audio Function (REQUIRED)

Change the model name in `functions/index.js`:

```javascript
// Line ~960 in generateAudio function
const audioModel = vertexAI.getGenerativeModel({
  model: 'lyria-3-pro', // Changed from 'musiclm-001'
});
```

### 2. Redeploy Audio Function

```bash
firebase deploy --only functions:generateAudio --force
```

### 3. Test All Three Features

- Test image generation in app
- Test video generation in app
- Test audio generation in app (after update)

### 4. Monitor Usage

Check Google Cloud Console → Vertex AI → Usage to see:
- Number of requests
- Costs per model
- Error rates

---

## References

- [Imagen 3 Documentation](https://cloud.google.com/vertex-ai/generative-ai/docs/image/generate-images)
- [Veo 3 Documentation](https://cloud.google.com/vertex-ai/generative-ai/docs/video/generate-videos)
- [Lyria 3 Documentation](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/music/generate-music)
- [Vertex AI Pricing](https://cloud.google.com/vertex-ai/pricing)

---

## Summary

✅ **Image Generation**: Using correct API (Imagen 3)  
✅ **Video Generation**: Using correct API (Veo 3)  
⚠️ **Audio Generation**: Using OLD API (MusicLM) - **NEEDS UPDATE to Lyria 3**

**Action Required**: Update audio generation to use `lyria-3-pro` instead of `musiclm-001`

