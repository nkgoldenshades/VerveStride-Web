// Web Speech API interop for Flutter Web TTS

window.ttsInterop = {
  /// Speak text using Web Speech API (cancels any ongoing speech)
  speak: function(text, rate, pitch, volume) {
    if (!('speechSynthesis' in window)) {
      console.error('❌ Web Speech API not supported');
      return false;
    }

    try {
      // Cancel any ongoing speech
      window.speechSynthesis.cancel();

      // Create utterance
      const utterance = new SpeechSynthesisUtterance(text);
      utterance.rate = rate || 1.0;      // 0.1 - 10
      utterance.pitch = pitch || 1.0;    // 0 - 2
      utterance.volume = volume || 1.0;  // 0 - 1
      utterance.lang = 'en-US';

      // Callbacks
      utterance.onstart = function() {
        console.log('🎤 Speech started');
      };

      utterance.onend = function() {
        console.log('✅ Speech ended');
      };

      utterance.onerror = function(event) {
        console.error('❌ Speech error:', event.error || event.type || 'unknown');
        // Common errors:
        // - 'not-allowed': Browser blocked auto-play (need user interaction first)
        // - 'canceled': Speech was canceled
        // - 'interrupted': Speech was interrupted by another utterance
        if (event.error === 'not-allowed') {
          console.warn('⚠️ Browser blocked TTS - user interaction required. Click speaker icon first!');
        }
      };

      // Speak
      window.speechSynthesis.speak(utterance);
      console.log('🎤 Speaking: ' + text.substring(0, 50) + '...');
      return true;
    } catch (e) {
      console.error('❌ TTS error:', e);
      return false;
    }
  },

  /// Queue speech without canceling (for streaming chunks)
  speakQueued: function(text, rate, pitch, volume) {
    if (!('speechSynthesis' in window)) {
      console.error('❌ Web Speech API not supported');
      return false;
    }

    try {
      // Create utterance WITHOUT canceling previous speech
      const utterance = new SpeechSynthesisUtterance(text);
      utterance.rate = rate || 1.0;
      utterance.pitch = pitch || 1.0;
      utterance.volume = volume || 1.0;
      utterance.lang = 'en-US';

      // Callbacks
      utterance.onend = function() {
        console.log('✅ Chunk ended: ' + text.substring(0, 30) + '...');
      };

      utterance.onerror = function(event) {
        console.error('❌ Chunk error:', event.error || 'unknown');
      };

      // Queue this utterance (browser will speak them in order)
      window.speechSynthesis.speak(utterance);
      console.log('📝 Queued chunk: ' + text.substring(0, 50) + '...');
      return true;
    } catch (e) {
      console.error('❌ TTS queue error:', e);
      return false;
    }
  },

  /// Stop speaking
  stop: function() {
    if ('speechSynthesis' in window) {
      window.speechSynthesis.cancel();
      console.log('⏹️ Speech stopped');
      return true;
    }
    return false;
  },

  /// Check if speechSynthesis is available
  isAvailable: function() {
    return 'speechSynthesis' in window;
  },

  /// Get list of available voices
  getVoices: function() {
    if (!('speechSynthesis' in window)) {
      return [];
    }

    const voices = window.speechSynthesis.getVoices();
    return voices.map(v => ({
      name: v.name,
      lang: v.lang,
      localService: v.localService,
      default: v.default
    }));
  },

  /// Set voice by name
  setVoice: function(voiceName) {
    if (!('speechSynthesis' in window)) {
      return false;
    }

    const voices = window.speechSynthesis.getVoices();
    const voice = voices.find(v => v.name === voiceName);
    
    if (voice) {
      window.ttsInterop._selectedVoice = voice;
      console.log('🎙️ Voice set to:', voiceName);
      return true;
    }

    console.warn('⚠️ Voice not found:', voiceName);
    return false;
  },

  /// Check if currently speaking
  isSpeaking: function() {
    return 'speechSynthesis' in window && window.speechSynthesis.speaking;
  },

  // Internal state
  _selectedVoice: null
};

// Log when voices are loaded
if ('speechSynthesis' in window) {
  window.speechSynthesis.onvoiceschanged = function() {
    const voices = window.speechSynthesis.getVoices();
    console.log('🎙️ Web Speech API voices loaded:', voices.length);
  };
}

console.log('✅ TTS Interop loaded');
