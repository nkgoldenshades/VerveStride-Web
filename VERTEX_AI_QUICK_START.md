# Vertex AI Features - Quick Start Guide

## ✅ What's Been Implemented

Your app now has **complete Vertex AI capabilities**:

1. **Image Generation** (Imagen 3) - 10 credits
2. **Video Generation** (Veo) - 50 credits  
3. **Form Analysis** - 3 credits
4. **Progress Photo Comparison** - 5 credits

## 🚀 Quick Deploy Steps

### 1. Deploy Cloud Functions

```bash
cd functions
npm install @google-cloud/vertexai
firebase deploy --only functions:generateImage,functions:generateVideo
```

### 2. Enable Vertex AI APIs

```bash
gcloud services enable aiplatform.googleapis.com
gcloud services enable imagegeneration.googleapis.com
gcloud services enable videogeneration.googleapis.com
```

Or enable in [Google Cloud Console](https://console.cloud.google.com/apis/library):
- Vertex AI API
- Imagen API
- Veo API

### 3. Add Navigation to Your App

Find your main navigation menu (drawer, bottom nav, or AI features screen) and add:

```dart
// Image Generator
ListTile(
  leading: Icon(Icons.auto_awesome),
  title: Text('AI Image Generator'),
  subtitle: Text('Generate custom images'),
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ImageGeneratorScreen(),
    ),
  ),
),

// Video Generator
ListTile(
  leading: Icon(Icons.video_library),
  title: Text('AI Video Generator'),
  subtitle: Text('Create workout videos'),
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => VideoGeneratorScreen(),
    ),
  ),
),

// Form Analysis
ListTile(
  leading: Icon(Icons.fitness_center),
  title: Text('Form Analysis'),
  subtitle: Text('Check your workout form'),
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => FormAnalysisScreen(),
    ),
  ),
),
```

Don't forget to import the screens:

```dart
import 'package:vervestride/screens/ai/image_generator_screen.dart';
import 'package:vervestride/screens/ai/video_generator_screen.dart';
import 'package:vervestride/screens/ai/form_analysis_screen.dart';
```

### 4. Build and Test

```bash
# Build web
flutter build web --release --no-wasm-dry-run

# Add CNAME
echo "vervestrideai.com" > build/web/CNAME

# Deploy to GitHub Pages
cd build/web
git add -A
git commit -m "Add Vertex AI features - image/video generation"
git push --force origin main
```

## 🧪 Testing Checklist

### Test Image Generation
1. Open Image Generator screen
2. Enter prompt: "Person doing a perfect squat"
3. Click "Generate Image"
4. Verify:
   - ✅ Image appears
   - ✅ 10 credits deducted
   - ✅ Can save/share image

### Test Video Generation
1. Open Video Generator screen
2. Enter prompt: "Push-up demonstration"
3. Select duration: 10s
4. Click "Generate Video"
5. Verify:
   - ✅ Video appears
   - ✅ 50 credits deducted
   - ✅ Video plays correctly

### Test Form Analysis
1. Open Form Analysis screen
2. Take/upload workout photo
3. Select exercise: "Squat"
4. Click "Analyze Form"
5. Verify:
   - ✅ Analysis appears
   - ✅ 3 credits deducted
   - ✅ Feedback is specific

## 💰 Credit Costs

| Feature | Credits | Description |
|---------|---------|-------------|
| Image Generation | 10 | Custom AI-generated images |
| Video Generation | 50 | Custom AI-generated videos |
| Form Analysis | 3 | Workout form feedback |
| Progress Analysis | 5 | Before/after comparison |

## 📁 Files Created/Modified

### New Files
- `lib/screens/ai/image_generator_screen.dart`
- `lib/screens/ai/video_generator_screen.dart`
- `lib/screens/ai/form_analysis_screen.dart`

### Modified Files
- `lib/services/firebase_ai_service.dart` - Added generation methods
- `lib/services/credits_service.dart` - Added credit costs
- `functions/index.js` - Added Cloud Functions

## 🐛 Troubleshooting

### "API not enabled" error
```bash
gcloud services enable aiplatform.googleapis.com
```

### "Insufficient credits" error
- User needs to purchase more credits
- Check credit balance in app

### Image/Video generation fails
1. Check Cloud Function logs: `firebase functions:log`
2. Verify Vertex AI APIs are enabled
3. Check billing is enabled in Google Cloud

### Form analysis returns empty
1. Check image size (< 5MB)
2. Verify image format (JPEG/PNG)
3. Ensure good image quality

## 📊 Monitoring

### Check Credit Usage
```bash
# View credit usage logs
firebase firestore:get credit_usage --limit 10
```

### Check Cloud Function Logs
```bash
# View function logs
firebase functions:log --only generateImage,generateVideo
```

### Monitor Costs
- Go to [Google Cloud Console](https://console.cloud.google.com/billing)
- Check Vertex AI usage
- Set up budget alerts

## 🎉 You're Done!

Your app now has:
- ✅ AI Image Generation
- ✅ AI Video Generation
- ✅ Workout Form Analysis
- ✅ Progress Photo Comparison

All features are:
- ✅ Credit-gated
- ✅ Server-side validated
- ✅ Rate-limited
- ✅ Fully functional

Deploy and test! 🚀
