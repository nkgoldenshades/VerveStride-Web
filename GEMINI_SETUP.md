# 🔑 Gemini API Setup Instructions

## Getting Your Gemini API Key

1. **Visit Google AI Studio**
   - Go to: https://makersuite.google.com/app/apikey
   - Sign in with your Google account

2. **Create API Key**
   - Click "Create API Key"
   - Select "Create API key in new project" or choose existing project
   - Copy the generated API key

3. **Add to Your App**
   - Open `lib/services/gemini_vision_service.dart`
   - Replace `YOUR_GEMINI_API_KEY_HERE` with your actual API key:
   
   ```dart
   static const String _apiKey = 'AIzaSy...your-key-here';
   ```

## Important Security Notes

⚠️ **DO NOT commit your API key to version control!**

### Best Practices:

1. **Use Environment Variables** (Recommended for production):
   ```dart
   static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');
   ```
   
   Then run with:
   ```bash
   flutter run --dart-define=GEMINI_API_KEY=your-key-here
   ```

2. **Use a Config File** (Add to .gitignore):
   Create `lib/config/api_keys.dart`:
   ```dart
   class ApiKeys {
     static const String geminiApiKey = 'your-key-here';
   }
   ```
   
   Add to `.gitignore`:
   ```
   lib/config/api_keys.dart
   ```

3. **Use Firebase Remote Config** (Best for production):
   - Store API key in Firebase Remote Config
   - Fetch at runtime
   - Update without app updates

## API Usage & Costs

### Gemini 1.5 Flash Pricing (as of 2024):
- **Free tier**: 15 requests per minute
- **Paid tier**: $0.00025 per image (very affordable!)

### Estimated Costs:
- 100 meal analyses/month = $0.025 (~2.5 cents)
- 1000 meal analyses/month = $0.25 (~25 cents)

**Conclusion**: Very affordable for personal use! 🎉

## Testing the Integration

1. **Test Connection**:
   ```dart
   final service = GeminiVisionService();
   final isConnected = await service.testConnection();
   print('Gemini connected: $isConnected');
   ```

2. **Test Food Analysis**:
   - Take a photo of food
   - App will analyze and return nutrition info
   - Check confidence level (0-1)

## Troubleshooting

### Error: "API key not valid"
- ✅ Check if you copied the full API key
- ✅ Ensure no extra spaces
- ✅ Verify API key is enabled in Google Cloud Console

### Error: "Quota exceeded"
- ✅ You've hit the free tier limit (15 requests/min)
- ✅ Wait a minute and try again
- ✅ Consider upgrading to paid tier

### Error: "Model not found"
- ✅ Check if you're using the correct model name
- ✅ Current model: `gemini-1.5-flash`
- ✅ Alternative: `gemini-1.5-pro` (more accurate, more expensive)

## Alternative: Use Mock Analysis

If you don't want to use AI right now, the app will fall back to mock analysis:

```dart
// In meals_screen.dart, the mock analysis is still available
// Just don't set the API key and it will use mock data
```

## Next Steps

1. ✅ Get your API key
2. ✅ Add it to the app
3. ✅ Test with a food photo
4. ✅ Enjoy AI-powered nutrition tracking!

---

**Need help?** Check the [Gemini API documentation](https://ai.google.dev/docs)
