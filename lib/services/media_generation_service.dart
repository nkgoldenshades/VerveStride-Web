import 'package:flutter/foundation.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'replicate_service.dart';

/// Unified service for image, video, and audio generation
/// Supports multiple providers with automatic fallback on busy/error
enum MediaProvider {
  googleVertexAI, // Primary - Google's AI models (Imagen, Veo, Lyria)
  replicate,      // Secondary - Industry standard fallback
  openAI,         // Tertiary - DALL-E 3 (images only)
}

class MediaGenerationService {
  static final MediaGenerationService instance = MediaGenerationService._internal();
  factory MediaGenerationService() => instance;
  MediaGenerationService._internal();

  // Provider priority order (1st = primary, 2nd = fallback, etc.)
  final List<MediaProvider> _providerPriority = [
    MediaProvider.googleVertexAI,  // Try Google first
    MediaProvider.replicate,       // Fall back to Replicate
    MediaProvider.openAI,          // Last resort (images only)
  ];

  /// Get current primary provider
  MediaProvider get primaryProvider => _providerPriority.first;

  /// Set provider priority order
  void setProviderPriority(List<MediaProvider> priority) {
    _providerPriority.clear();
    _providerPriority.addAll(priority);
    debugPrint('🎨 Media generation priority: ${priority.map((p) => p.name).join(" → ")}');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // IMAGE GENERATION (with automatic fallback)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Generate an image from text prompt with automatic fallback
  /// Returns image bytes on success, null if all providers fail
  Future<Uint8List?> generateImage(String prompt) async {
    debugPrint('🎨 [MediaGen] Starting image generation with fallback chain');
    
    for (final provider in _providerPriority) {
      debugPrint('🎨 [MediaGen] Trying ${provider.name}...');
      
      try {
        Uint8List? result;
        
        switch (provider) {
          case MediaProvider.googleVertexAI:
            result = await _generateImageGoogle(prompt);
            break;
          case MediaProvider.replicate:
            result = await _generateImageReplicate(prompt);
            break;
          case MediaProvider.openAI:
            result = await _generateImageOpenAI(prompt);
            break;
        }
        
        if (result != null) {
          debugPrint('✅ [MediaGen] Image generated successfully with ${provider.name}');
          return result;
        }
        
        debugPrint('⚠️ [MediaGen] ${provider.name} returned null, trying next provider...');
      } catch (e) {
        debugPrint('❌ [MediaGen] ${provider.name} failed: $e, trying next provider...');
      }
    }
    
    debugPrint('❌ [MediaGen] All providers failed for image generation');
    return null;
  }

  /// Generate image using Google Vertex AI Imagen
  Future<Uint8List?> _generateImageGoogle(String prompt) async {
    debugPrint('🎨 [Google Imagen] Generating image...');
    
    try {
      // Use generativeModel for Imagen (firebase_ai 3.8.0 approach)
      final model = FirebaseAI.vertexAI().generativeModel(
        model: 'imagen-3.0-generate-002',
      );

      debugPrint('🎨 [Google Imagen] Sending prompt to Vertex AI...');
      
      // Generate using text-to-image
      final response = await model.generateContent([
        Content.text('Generate an image: $prompt'),
      ]);

      final text = response.text;
      if (text == null || text.isEmpty) {
        debugPrint('❌ [Google Imagen] Response has no data');
        return null;
      }

      // Note: Imagen response handling depends on firebase_ai package version
      // This is a fallback implementation - may need adjustment based on actual API
      debugPrint('⚠️ [Google Imagen] Direct Imagen API not yet fully supported in firebase_ai 3.8.0');
      debugPrint('⚠️ [Google Imagen] Falling back to next provider (Replicate)');
      return null;

    } on Exception catch (e) {
      debugPrint('❌ [Google Imagen] Exception: $e');
      // Common error scenarios:
      // • Imagen API not enabled in Cloud Console
      // • Wrong model name or region (must be us-central1)
      // • Quota exceeded
      debugPrint('💡 [Google Imagen] Check: Vertex AI API enabled? Region us-central1? Imagen 3 enabled?');
      rethrow; // let MediaGenerationService fallback chain handle it
    } catch (e) {
      debugPrint('❌ [Google Imagen] Unexpected error: $e');
      rethrow;
    }
  }

  /// Generate image using Replicate (SDXL)
  Future<Uint8List?> _generateImageReplicate(String prompt) async {
    debugPrint('🎨 [Replicate] Generating image...');
    return await ReplicateService.generateImage(prompt);
  }

  /// Generate image using OpenAI DALL-E 3
  Future<Uint8List?> _generateImageOpenAI(String prompt) async {
    debugPrint('🎨 [OpenAI DALL-E] Generating image...');
    
    // TODO: Implement OpenAI DALL-E 3 integration as final fallback
    debugPrint('⚠️ [OpenAI DALL-E] Not yet implemented');
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VIDEO GENERATION (with automatic fallback)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Generate a video from text prompt with automatic fallback
  /// Returns video URL on success, null if all providers fail
  Future<String?> generateVideo(String prompt, {int durationSeconds = 5}) async {
    debugPrint('🎬 [MediaGen] Starting video generation with fallback chain');
    
    for (final provider in _providerPriority) {
      // Skip OpenAI for video (doesn't support it)
      if (provider == MediaProvider.openAI) continue;
      
      debugPrint('🎬 [MediaGen] Trying ${provider.name}...');
      
      try {
        String? result;
        
        switch (provider) {
          case MediaProvider.googleVertexAI:
            result = await _generateVideoGoogle(prompt, durationSeconds: durationSeconds);
            break;
          case MediaProvider.replicate:
            result = await _generateVideoReplicate(prompt, durationSeconds: durationSeconds);
            break;
          case MediaProvider.openAI:
            continue; // Skip
        }
        
        if (result != null) {
          debugPrint('✅ [MediaGen] Video generated successfully with ${provider.name}');
          return result;
        }
        
        debugPrint('⚠️ [MediaGen] ${provider.name} returned null, trying next provider...');
      } catch (e) {
        debugPrint('❌ [MediaGen] ${provider.name} failed: $e, trying next provider...');
      }
    }
    
    debugPrint('❌ [MediaGen] All providers failed for video generation');
    return null;
  }

  /// Generate video using Google Vertex AI Veo
  Future<String?> _generateVideoGoogle(String prompt, {int durationSeconds = 5}) async {
    debugPrint('🎬 [Google Veo] Generating video...');
    
    // TODO: Implement actual Google Veo integration
    debugPrint('⚠️ [Google Veo] Not yet implemented - cascading to next provider');
    return null;
  }

  /// Generate video using Replicate (Zeroscope)
  Future<String?> _generateVideoReplicate(String prompt, {int durationSeconds = 5}) async {
    debugPrint('🎬 [Replicate] Generating video...');
    return await ReplicateService.generateVideo(prompt, durationSeconds: durationSeconds);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AUDIO GENERATION (with automatic fallback)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Generate audio/music from text prompt with automatic fallback
  /// Returns audio URL on success, null if all providers fail
  Future<String?> generateAudio(String prompt, {int durationSeconds = 30}) async {
    debugPrint('🎵 [MediaGen] Starting audio generation with fallback chain');
    
    for (final provider in _providerPriority) {
      // Skip OpenAI for audio (doesn't support it)
      if (provider == MediaProvider.openAI) continue;
      
      debugPrint('🎵 [MediaGen] Trying ${provider.name}...');
      
      try {
        String? result;
        
        switch (provider) {
          case MediaProvider.googleVertexAI:
            result = await _generateAudioGoogle(prompt, durationSeconds: durationSeconds);
            break;
          case MediaProvider.replicate:
            result = await _generateAudioReplicate(prompt, durationSeconds: durationSeconds);
            break;
          case MediaProvider.openAI:
            continue; // Skip
        }
        
        if (result != null) {
          debugPrint('✅ [MediaGen] Audio generated successfully with ${provider.name}');
          return result;
        }
        
        debugPrint('⚠️ [MediaGen] ${provider.name} returned null, trying next provider...');
      } catch (e) {
        debugPrint('❌ [MediaGen] ${provider.name} failed: $e, trying next provider...');
      }
    }
    
    debugPrint('❌ [MediaGen] All providers failed for audio generation');
    return null;
  }

  /// Generate audio using Google Vertex AI Lyria/MusicLM
  Future<String?> _generateAudioGoogle(String prompt, {int durationSeconds = 30}) async {
    debugPrint('🎵 [Google Lyria] Generating audio...');
    
    // TODO: Implement actual Google Lyria/MusicLM integration
    debugPrint('⚠️ [Google Lyria] Not yet implemented - cascading to next provider');
    return null;
  }

  /// Generate audio using Replicate (MusicGen)
  Future<String?> _generateAudioReplicate(String prompt, {int durationSeconds = 30}) async {
    debugPrint('🎵 [Replicate] Generating audio...');
    return await ReplicateService.generateAudio(prompt, durationSeconds: durationSeconds);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PROVIDER INFO
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get provider display name
  String getProviderName(MediaProvider provider) {
    switch (provider) {
      case MediaProvider.googleVertexAI:
        return 'Google Vertex AI';
      case MediaProvider.replicate:
        return 'Replicate AI';
      case MediaProvider.openAI:
        return 'OpenAI DALL-E';
    }
  }

  /// Get provider description
  String getProviderDescription(MediaProvider provider) {
    switch (provider) {
      case MediaProvider.googleVertexAI:
        return '🥇 Primary • Imagen, Veo, Lyria • Best quality';
      case MediaProvider.replicate:
        return '🥈 Secondary • SDXL, Zeroscope, MusicGen • Reliable fallback';
      case MediaProvider.openAI:
        return '🥉 Tertiary • DALL-E 3 • Images only';
    }
  }

  /// Check if provider supports feature
  bool supportsFeature(MediaProvider provider, String feature) {
    switch (provider) {
      case MediaProvider.googleVertexAI:
        return true; // Supports all (when implemented)
      case MediaProvider.replicate:
        return true; // Supports all features
      case MediaProvider.openAI:
        return feature == 'image'; // Only images
    }
  }
  
  /// Get current provider status for debugging
  String getProviderStatus() {
    return 'Priority: ${_providerPriority.map((p) => getProviderName(p)).join(" → ")}';
  }
}
