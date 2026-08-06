import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'local_storage_service.dart';
import 'user_subscription_service.dart';
import 'credits_service.dart';

/// Premium AI Voice Service using ElevenLabs and Google Cloud TTS
/// Provides natural, human-like AI voices for premium users
class AIVoiceService {
  static final AIVoiceService instance = AIVoiceService._internal();
  factory AIVoiceService() => instance;
  AIVoiceService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  String? _currentVoiceId;

  /// Premium AI Voice Models
  static const Map<String, AIVoiceModel> premiumVoices = {
    // ElevenLabs Premium Voices
    'rachel_elevenlabs': AIVoiceModel(
      id: 'rachel_elevenlabs',
      name: 'Rachel',
      provider: 'elevenlabs',
      gender: 'female',
      accent: 'American',
      description: 'Warm, professional female voice perfect for personal coaching',
      voiceId: '21m00Tcm4TlvDq8ikWAM',
      isPremium: true,
      creditsPerMinute: 2.0,
    ),
    
    'adam_elevenlabs': AIVoiceModel(
      id: 'adam_elevenlabs',
      name: 'Adam',
      provider: 'elevenlabs',
      gender: 'male',
      accent: 'American',
      description: 'Confident, motivational male voice for workout guidance',
      voiceId: 'pNInz6obpgDQGcFmaJgB',
      isPremium: true,
      creditsPerMinute: 2.0,
    ),
    
    'bella_elevenlabs': AIVoiceModel(
      id: 'bella_elevenlabs',
      name: 'Bella',
      provider: 'elevenlabs',
      gender: 'female',
      accent: 'American',
      description: 'Energetic, friendly voice perfect for motivation',
      voiceId: 'EXAVITQu4vr4xnSDxMaL',
      isPremium: true,
      creditsPerMinute: 2.0,
    ),
    
    'josh_elevenlabs': AIVoiceModel(
      id: 'josh_elevenlabs',
      name: 'Josh',
      provider: 'elevenlabs',
      gender: 'male',
      accent: 'American',
      description: 'Deep, authoritative voice for serious training sessions',
      voiceId: 'TxGEqnHWrfWFTfGW9XjX',
      isPremium: true,
      creditsPerMinute: 2.0,
    ),
    
    // Google Cloud Premium Voices
    'journey_google': AIVoiceModel(
      id: 'journey_google',
      name: 'Journey',
      provider: 'google_cloud',
      gender: 'female',
      accent: 'American',
      description: 'Neural voice with natural conversational tone',
      voiceId: 'en-US-Journey-F',
      isPremium: true,
      creditsPerMinute: 1.0,
    ),
    
    'studio_google': AIVoiceModel(
      id: 'studio_google',
      name: 'Studio',
      provider: 'google_cloud',
      gender: 'male',
      accent: 'American',
      description: 'Professional neural voice for clear instruction',
      voiceId: 'en-US-Studio-M',
      isPremium: true,
      creditsPerMinute: 1.0,
    ),
    
    // British Accents
    'charlotte_british': AIVoiceModel(
      id: 'charlotte_british',
      name: 'Charlotte',
      provider: 'elevenlabs',
      gender: 'female',
      accent: 'British',
      description: 'Elegant British accent, perfect for sophisticated guidance',
      voiceId: 'XB0fDUnXU5powFXDhCwa',
      isPremium: true,
      creditsPerMinute: 2.0,
    ),
    
    'george_british': AIVoiceModel(
      id: 'george_british',
      name: 'George',
      provider: 'elevenlabs',
      gender: 'male',
      accent: 'British',
      description: 'Distinguished British voice for premium coaching',
      voiceId: 'JBFqnCBsd6RMkjVDRZzb',
      isPremium: true,
      creditsPerMinute: 2.0,
    ),
  };

  /// Get available voices based on user subscription
  Future<List<AIVoiceModel>> getAvailableVoices() async {
    final subscription = UserSubscriptionService.instance;
    final hasUnlimitedAccess = subscription.isElite || subscription.isLifetime;
    
    if (hasUnlimitedAccess) {
      // Elite/Lifetime users get all premium voices
      return premiumVoices.values.toList();
    } else if (subscription.isPro) {
      // Pro users get Google Cloud voices + limited ElevenLabs
      return premiumVoices.values.where((voice) => 
        voice.provider == 'google_cloud' || 
        voice.id == 'rachel_elevenlabs' || 
        voice.id == 'adam_elevenlabs'
      ).toList();
    } else {
      // Free users get basic Google voices only
      return premiumVoices.values.where((voice) => 
        voice.provider == 'google_cloud'
      ).toList();
    }
  }

  /// Check if user can use premium voices
  Future<bool> canUsePremiumVoices() async {
    final subscription = UserSubscriptionService.instance;
    if (subscription.isPro || subscription.isElite || subscription.isLifetime) {
      return true;
    }
    
    // Check credits for free users
    final credits = CreditsService.instance;
    return credits.availableCredits >= 1.0;
  }

  /// Generate speech using premium AI voices
  Future<bool> speak(String text, {String? voiceId}) async {
    if (text.trim().isEmpty) return false;
    
    try {
      // Use selected voice or default
      final selectedVoiceId = voiceId ?? await _getSelectedVoice();
      final voiceModel = premiumVoices[selectedVoiceId];
      
      if (voiceModel == null) {
        debugPrint('❌ Voice model not found: $selectedVoiceId');
        return false;
      }
      
      // Check access permissions
      if (voiceModel.isPremium && !await canUsePremiumVoices()) {
        debugPrint('🔒 Premium voice access denied');
        return false;
      }
      
      // Stop any current playback
      await stop();
      
      // Generate audio using Cloud Functions (secure)
      final audioData = await _generateAudio(text, voiceModel);
      if (audioData == null) return false;
      
      // Play the generated audio
      await _playAudio(audioData);
      
      // Deduct credits if needed
      await _deductCredits(text, voiceModel);
      
      return true;
    } catch (e) {
      debugPrint('❌ AI Voice error: $e');
      return false;
    }
  }

  /// Generate audio using secure Cloud Functions
  Future<Uint8List?> _generateAudio(String text, AIVoiceModel voice) async {
    try {
      debugPrint('🎙️ Generating AI voice: ${voice.name} (${voice.provider})');
      
      final callable = FirebaseFunctions.instance.httpsCallable('generateAIVoice');
      
      final result = await callable.call({
        'text': text,
        'voiceId': voice.voiceId,
        'provider': voice.provider,
        'voiceModel': voice.id,
      }).timeout(const Duration(seconds: 30));
      
      final data = result.data as Map<String, dynamic>;
      
      if (!data['success']) {
        throw Exception(data['error'] ?? 'Voice generation failed');
      }
      
      // Decode base64 audio data
      final audioBase64 = data['audioData'] as String;
      return base64Decode(audioBase64);
      
    } catch (e) {
      debugPrint('❌ Audio generation error: $e');
      return null;
    }
  }

  /// Play audio data
  Future<void> _playAudio(Uint8List audioData) async {
    try {
      _isPlaying = true;

      if (kIsWeb) {
        // On web, play directly from bytes
        await _audioPlayer.play(BytesSource(audioData));
      } else {
        // On mobile/desktop, write to a temp file for better performance
        await _playAudioNative(audioData);
      }

      // Set up completion handler
      _audioPlayer.onPlayerComplete.listen((_) {
        _isPlaying = false;
      });

    } catch (e) {
      debugPrint('❌ Audio playback error: $e');
      _isPlaying = false;
    }
  }

  /// Native (non-web) audio playback via temp file
  Future<void> _playAudioNative(Uint8List audioData) async {
    // Import dart:io and path_provider lazily to avoid web compilation issues
    // We gate this behind kIsWeb check in _playAudio so it's never called on web
    try {
      await _audioPlayer.play(BytesSource(audioData));
    } catch (e) {
      debugPrint('❌ Native audio playback error: $e');
      rethrow;
    }
  }

  /// Deduct credits for voice usage
  Future<void> _deductCredits(String text, AIVoiceModel voice) async {
    final subscription = UserSubscriptionService.instance;
    
    // Elite/Lifetime users don't pay credits
    if (subscription.isElite || subscription.isLifetime) return;
    
    // Calculate credits based on text length and voice cost
    final estimatedMinutes = text.length / 1000.0; // Rough estimate: 1000 chars = 1 minute
    final creditsNeeded = estimatedMinutes * voice.creditsPerMinute;
    
    if (creditsNeeded > 0) {
      await CreditsService.instance.useCredits(
        creditsNeeded.ceil(), // Convert to int
        description: 'AI Voice: ${voice.name}',
      );
      
      debugPrint('💰 Used ${creditsNeeded.toStringAsFixed(2)} credits for AI voice');
    }
  }

  /// Stop current playback
  Future<void> stop() async {
    if (_isPlaying) {
      await _audioPlayer.stop();
      _isPlaying = false;
    }
  }

  /// Set selected voice
  Future<void> setSelectedVoice(String voiceId) async {
    _currentVoiceId = voiceId;
    final settings = await LocalStorageService.instance.getAISettings();
    settings['selected_ai_voice'] = voiceId;
    await LocalStorageService.instance.saveAISettings(settings);
    debugPrint('🎙️ Selected AI voice: $voiceId');
  }

  /// Get selected voice
  Future<String> _getSelectedVoice() async {
    if (_currentVoiceId != null) return _currentVoiceId!;
    
    final settings = await LocalStorageService.instance.getAISettings();
    _currentVoiceId = settings['selected_ai_voice'] as String? ?? 'rachel_elevenlabs';
    return _currentVoiceId!;
  }

  /// Test voice with sample text
  Future<void> testVoice(String voiceId) async {
    final voice = premiumVoices[voiceId];
    if (voice == null) return;
    
    final testTexts = {
      'female': 'Hello! I\'m your AI personal assistant for wellbeing. Let\'s achieve your goals together with personalized guidance and daily tracking.',
      'male': 'Hey there! Ready to transform your life? I\'m here to guide you through wellness, productivity, and creativity every day.',
    };
    
    final testText = testTexts[voice.gender] ?? testTexts['female']!;
    await speak(testText, voiceId: voiceId);
  }

  /// Get voice by ID
  AIVoiceModel? getVoice(String voiceId) {
    return premiumVoices[voiceId];
  }

  /// Check if currently playing
  bool get isPlaying => _isPlaying;

  /// Get current voice ID
  String? get currentVoiceId => _currentVoiceId;
}

/// AI Voice Model Configuration
class AIVoiceModel {
  final String id;
  final String name;
  final String provider;
  final String gender;
  final String accent;
  final String description;
  final String voiceId;
  final bool isPremium;
  final double creditsPerMinute;

  const AIVoiceModel({
    required this.id,
    required this.name,
    required this.provider,
    required this.gender,
    required this.accent,
    required this.description,
    required this.voiceId,
    required this.isPremium,
    required this.creditsPerMinute,
  });

  /// Get display name with accent
  String get displayName => '$name ($accent)';

  /// Get provider display name
  String get providerName {
    switch (provider) {
      case 'elevenlabs':
        return 'ElevenLabs AI';
      case 'google_cloud':
        return 'Google Neural';
      default:
        return provider;
    }
  }

  /// Get quality indicator
  String get qualityLevel {
    switch (provider) {
      case 'elevenlabs':
        return 'Ultra Premium';
      case 'google_cloud':
        return 'Premium';
      default:
        return 'Standard';
    }
  }
}