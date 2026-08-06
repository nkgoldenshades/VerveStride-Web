import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vervestride/services/local_storage_service.dart';
import 'package:vervestride/services/assistant_voice_profile.dart';

/// Service for Text-to-Speech functionality with voice selection
class TTSService {
  static final TTSService _instance = TTSService._internal();
  factory TTSService() => _instance;
  TTSService._internal();
  static TTSService get instance => _instance;

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;
  String? _selectedVoice;
  double _speechRate = 0.5; // Default speech rate
  double _pitch = 1.0; // Default pitch
  double _volume = 1.0; // Default volume

  // Available voices
  List<Map<String, String>> _availableVoices = [];
  List<Map<String, String>> get availableVoices => List.unmodifiable(_availableVoices);

  String? _resolveVoiceName(String voiceName) {
    final n = voiceName.trim();
    if (n.isEmpty) return null;

    // Legacy / friendly tokens.
    final lower = n.toLowerCase();
    if (lower == VoiceGenderFilter.male || lower == VoiceGenderFilter.female) {
      final wantFemale = lower == VoiceGenderFilter.female;
      debugPrint('🎙️ Looking for ${wantFemale ? "female" : "male"} voice...');
      
      for (final v in _availableVoices) {
        final vn = v['name'] ?? '';
        final vl = v['locale'] ?? '';
        final g = VoiceGenderFilter.inferGender(vn, vl);
        debugPrint('  - Voice: $vn ($vl) -> gender: ${g == true ? "female" : g == false ? "male" : "unknown"}');
        
        if (wantFemale ? g == true : g == false) {
          debugPrint('✅ Selected voice: $vn');
          return vn;
        }
      }
      
      debugPrint('⚠️ No ${wantFemale ? "female" : "male"} voice found, using first available');
      return _availableVoices.isNotEmpty ? _availableVoices.first['name'] : null;
    }

    // Direct name match.
    final match = _availableVoices.where((v) => v['name'] == n).toList();
    if (match.isNotEmpty) return match.first['name'];

    // Best-effort: case-insensitive match.
    final match2 = _availableVoices
        .where((v) => (v['name'] ?? '').toLowerCase() == lower)
        .toList();
    if (match2.isNotEmpty) return match2.first['name'];

    // Fallback.
    return _availableVoices.isNotEmpty ? _availableVoices.first['name'] : null;
  }

  /// Initialize TTS and load saved voice settings
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(_speechRate);
      await _flutterTts.setPitch(_pitch);
      await _flutterTts.setVolume(_volume);

      // Pre-warm the TTS engine to eliminate first-speak lag
      await _flutterTts.awaitSpeakCompletion(true);

      await _loadVoices();
      await _loadSavedVoice();
      await _autoSelectBestVoice();

      _flutterTts.setCompletionHandler(() => _isSpeaking = false);
      _flutterTts.setErrorHandler((msg) {
        debugPrint('TTS Error: $msg');
        _isSpeaking = false;
      });

      _isInitialized = true;
      debugPrint('✅ TTS Service initialized with ${_availableVoices.length} voices');
    } catch (e) {
      debugPrint('❌ TTS initialization error: $e');
      _isInitialized = true; // Mark as initialized even on error to prevent retry loops
    }
  }

  /// Auto-select the best quality voice available on this device
  Future<void> _autoSelectBestVoice() async {
    if (_selectedVoice != null) return; // Already have a saved preference

    // Priority list — best quality voices first
    const preferredVoices = [
      // Google high-quality neural voices (Android)
      'en-us-x-sfg#female_1-local',
      'en-us-x-sfg#male_1-local',
      'en-us-x-iom#female_1-local',
      'en-us-x-iom#male_1-local',
      'en-US-language',
      // iOS premium voices
      'Samantha',
      'Alex',
      'Karen',
      'Daniel',
      'Moira',
    ];

    for (final preferred in preferredVoices) {
      final match = _availableVoices.where(
        (v) => (v['name'] ?? '').toLowerCase().contains(preferred.toLowerCase())
      ).toList();
      if (match.isNotEmpty) {
        await setVoice(match.first['name']!);
        debugPrint('🎙️ Auto-selected best voice: ${match.first['name']}');
        return;
      }
    }

    // Fallback: pick first English voice
    if (_availableVoices.isNotEmpty) {
      await setVoice(_availableVoices.first['name']!);
    }
  }

  /// Load available voices from the TTS engine
  Future<void> _loadVoices() async {
    try {
      final voices = await _flutterTts.getVoices;
      if (voices != null && voices is List) {
        _availableVoices = voices
            .whereType<Map>()
            .map((v) => {
                  'name': (v['name'] ?? 'Unknown').toString(),
                  'locale': (v['locale'] ?? 'en-US').toString(),
                })
            .where((v) => v['locale']!.startsWith('en'))
            .toList();
        debugPrint('🎙️ Found ${_availableVoices.length} voices');
      }
    } catch (e) {
      debugPrint('❌ Error loading voices: $e');
      _availableVoices = [{'name': 'Default', 'locale': 'en-US'}];
    }
  }

  /// Load saved voice preference from storage
  Future<void> _loadSavedVoice() async {
    try {
      final aiSettings = await LocalStorageService.instance.getAISettings();
      final savedVoice = aiSettings['tts_voice'] as String?;
      final savedRate = aiSettings['tts_rate'] as double?;
      final savedPitch = aiSettings['tts_pitch'] as double?;
      final savedVolume = aiSettings['tts_volume'] as double?;

      if (savedVoice != null && savedVoice.isNotEmpty) {
        _selectedVoice = savedVoice;
        await setVoice(savedVoice);
      }

      if (savedRate != null) {
        _speechRate = savedRate.clamp(0.1, 1.0);
        await _flutterTts.setSpeechRate(_speechRate);
      }

      if (savedPitch != null) {
        _pitch = savedPitch.clamp(0.5, 2.0);
        await _flutterTts.setPitch(_pitch);
      }

      if (savedVolume != null) {
        _volume = savedVolume.clamp(0.0, 1.0);
        await _flutterTts.setVolume(_volume);
      }
    } catch (e) {
      debugPrint('❌ Error loading saved voice: $e');
    }
  }

  /// Set the voice for TTS
  Future<bool> setVoice(String voiceName) async {
    try {
      final resolvedName = _resolveVoiceName(voiceName);
      if (resolvedName == null) return false;

      final voice = _availableVoices.firstWhere(
        (v) => v['name'] == resolvedName,
        orElse: () => _availableVoices.isNotEmpty
            ? _availableVoices.first
            : {'name': 'Default', 'locale': 'en-US'},
      );

      await _flutterTts.setVoice({
        'name': voice['name']!,
        'locale': voice['locale']!,
      });

      _selectedVoice = voice['name'];
      debugPrint('🎙️ Voice set to: ${voice['name']} (${voice['locale']})');
      return true;
    } catch (e) {
      debugPrint('❌ Error setting voice: $e');
      return false;
    }
  }

  /// Get the currently selected voice name
  String? get selectedVoice => _selectedVoice;

  /// Get display name for a voice
  String getVoiceDisplayName(String voiceName) {
    final voice = _availableVoices.firstWhere(
      (v) => v['name'] == voiceName,
      orElse: () => {'name': voiceName, 'locale': 'en-US'},
    );
    
    // Format: "Voice Name (en-US)"
    return '${voice['name']} (${voice['locale']})';
  }

  /// Split reply into speakable chunks (sentence-by-sentence streaming).
  static List<String> splitForStreamingSpeech(String text) {
    final t = text.trim();
    if (t.isEmpty) return [];
    var parts = t
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.length <= 1 && t.length > 240) {
      final byComma = t.split(RegExp(r'(?<=[:,])\s+'));
      if (byComma.length > 1) {
        parts = byComma.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      } else {
        parts = _chunkByLength(t, 200);
      }
    }
    return parts;
  }

  static List<String> _chunkByLength(String text, int maxLen) {
    final out = <String>[];
    final words = text.split(RegExp(r'\s+'));
    final buf = StringBuffer();
    for (final w in words) {
      if (buf.isEmpty) {
        buf.write(w);
      } else if (buf.length + 1 + w.length > maxLen) {
        out.add(buf.toString());
        buf.clear();
        buf.write(w);
      } else {
        buf.write(' ');
        buf.write(w);
      }
    }
    if (buf.isNotEmpty) out.add(buf.toString());
    return out;
  }

  /// Speak [text] in chunks so playback starts sooner (sentence-by-sentence).
  Future<void> speakStreaming(String text) async {
    if (!_isInitialized) {
      await initialize();
    }
    final chunks = splitForStreamingSpeech(text);
    if (chunks.isEmpty) return;

    await stop();
    try {
      await _flutterTts.awaitSpeakCompletion(true);
    } catch (e) {
      debugPrint('⚠️ awaitSpeakCompletion unsupported, using single speak: $e');
      await speak(text);
      return;
    }
    try {
      for (final chunk in chunks) {
        if (chunk.trim().isEmpty) continue;
        _isSpeaking = true;
        await _flutterTts.speak(chunk);
      }
    } catch (e) {
      debugPrint('❌ TTS speakStreaming error: $e');
      _isSpeaking = false;
      await speak(text);
    } finally {
      try {
        await _flutterTts.awaitSpeakCompletion(false);
      } catch (_) {}
      _isSpeaking = false;
    }
  }

  /// Speak the given text — fast, natural device TTS with optimal settings
  Future<void> speak(String text) async {
    if (!_isInitialized) await initialize();
    if (text.isEmpty) return;
    if (_isSpeaking) await stop();

    try {
      _isSpeaking = true;
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('❌ TTS speak error: $e');
      _isSpeaking = false;
    }
  }

  /// Stop speaking
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
      _isSpeaking = false;
    } catch (e) {
      debugPrint('❌ TTS stop error: $e');
    }
  }

  /// Check if currently speaking
  bool get isSpeaking => _isSpeaking;

  /// Set speech rate (0.1 to 1.0)
  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.1, 1.0);
    await _flutterTts.setSpeechRate(_speechRate);
    await _saveVoiceSettings();
  }

  /// Set pitch (0.5 to 2.0)
  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.5, 2.0);
    await _flutterTts.setPitch(_pitch);
    await _saveVoiceSettings();
  }

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _flutterTts.setVolume(_volume);
    await _saveVoiceSettings();
  }

  /// Get current speech rate
  double get speechRate => _speechRate;

  /// Get current pitch
  double get pitch => _pitch;

  /// Get current volume
  double get volume => _volume;

  /// Save voice settings to storage
  Future<void> _saveVoiceSettings() async {
    try {
      final aiSettings = await LocalStorageService.instance.getAISettings();
      aiSettings['tts_voice'] = _selectedVoice;
      aiSettings['tts_rate'] = _speechRate;
      aiSettings['tts_pitch'] = _pitch;
      aiSettings['tts_volume'] = _volume;
      await LocalStorageService.instance.saveAISettings(aiSettings);
    } catch (e) {
      debugPrint('❌ Error saving voice settings: $e');
    }
  }

  /// Save selected voice to storage
  Future<void> saveSelectedVoice(String voiceName) async {
    final success = await setVoice(voiceName);
    if (success) {
      await _saveVoiceSettings();
    }
  }

  /// Apply preset speed/pitch for Calm / Balanced / Energetic (AI Settings).
  Future<void> applyAssistantVoiceMode(String mode) async {
    final rate = AssistantVoiceMode.ttsRate(mode);
    final pitch = AssistantVoiceMode.ttsPitch(mode);
    await setSpeechRate(rate);
    await setPitch(pitch);
  }

  /// Test the selected voice with a sample text
  Future<void> testVoice(String sampleText) async {
    final text = sampleText.isEmpty 
        ? 'Hello! This is a test of the text to speech voice.' 
        : sampleText;
    await speak(text);
  }
}
