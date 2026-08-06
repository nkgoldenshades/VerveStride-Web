// AI Language and Accent Configuration
// Supports different languages and regional accents for AI voice and responses

class AILanguageConfig {
  final String id;
  final String displayName;
  final String languageCode; // e.g., 'en-US', 'en-GB'
  final String flag; // Emoji flag
  final String description;
  final List<String> voicePatterns; // Patterns to match voices
  final double defaultSpeechRate;
  final double defaultPitch;
  final String systemPromptAddition; // Additional prompt for this language/accent

  const AILanguageConfig({
    required this.id,
    required this.displayName,
    required this.languageCode,
    required this.flag,
    required this.description,
    required this.voicePatterns,
    this.defaultSpeechRate = 0.6,
    this.defaultPitch = 1.0,
    this.systemPromptAddition = '',
  });

  /// All available language configurations
  static const List<AILanguageConfig> all = [
    // English variants
    americanEnglish,
    britishEnglish,
    australianEnglish,
    canadianEnglish,
    indianEnglish,
    southAfricanEnglish,
    
    // Other major languages
    spanish,
    french,
    german,
    italian,
    portuguese,
    dutch,
    russian,
    japanese,
    korean,
    chinese,
    arabic,
    hindi,
  ];

  /// Default language (American English)
  static const AILanguageConfig defaultLanguage = americanEnglish;

  /// English Language Variants
  static const AILanguageConfig americanEnglish = AILanguageConfig(
    id: 'en_us',
    displayName: 'American English',
    languageCode: 'en-US',
    flag: '🇺🇸',
    description: 'Standard American English with neutral accent',
    voicePatterns: [
      'en-us', 'en_us', 'american', 'usa', 'united states',
      'samantha', 'alex', 'victoria', 'allison', 'tom'
    ],
    defaultSpeechRate: 0.6,
    defaultPitch: 1.0,
    systemPromptAddition: '',
  );

  static const AILanguageConfig britishEnglish = AILanguageConfig(
    id: 'en_gb',
    displayName: 'British English',
    languageCode: 'en-GB',
    flag: '🇬🇧',
    description: 'British English with UK spelling and expressions',
    voicePatterns: [
      'en-gb', 'en_gb', 'british', 'uk', 'united kingdom', 'england',
      'daniel', 'kate', 'serena', 'arthur', 'martha'
    ],
    defaultSpeechRate: 0.55,
    defaultPitch: 1.05,
    systemPromptAddition: '''

LANGUAGE STYLE: Use British English throughout your responses:
- Spelling: colour, realise, centre, programme, etc.
- Vocabulary: lift (elevator), lorry (truck), biscuit (cookie), etc.
- Expressions: "brilliant", "lovely", "quite good", "rather", "I say"
- Politeness: More formal and polite tone typical of British English
- Fitness terms: "training" (workout), "kit" (gear), "brilliant session"''',
  );

  static const AILanguageConfig australianEnglish = AILanguageConfig(
    id: 'en_au',
    displayName: 'Australian English',
    languageCode: 'en-AU',
    flag: '🇦🇺',
    description: 'Australian English with Aussie expressions',
    voicePatterns: [
      'en-au', 'en_au', 'australian', 'aussie', 'australia',
      'nicole', 'russell', 'karen'
    ],
    defaultSpeechRate: 0.65,
    defaultPitch: 1.1,
    systemPromptAddition: '''

LANGUAGE STYLE: Use Australian English with Aussie expressions:
- Vocabulary: "mate", "no worries", "fair dinkum", "good on ya"
- Fitness terms: "training sesh", "smashing it", "too right"
- Casual and friendly tone with Australian slang where appropriate
- Spelling follows British conventions but with Australian expressions''',
  );

  static const AILanguageConfig canadianEnglish = AILanguageConfig(
    id: 'en_ca',
    displayName: 'Canadian English',
    languageCode: 'en-CA',
    flag: '🇨🇦',
    description: 'Canadian English with polite Canadian expressions',
    voicePatterns: [
      'en-ca', 'en_ca', 'canadian', 'canada',
      'nora', 'felix'
    ],
    defaultSpeechRate: 0.6,
    defaultPitch: 1.0,
    systemPromptAddition: '''

LANGUAGE STYLE: Use Canadian English with polite Canadian expressions:
- Vocabulary: "eh", "sorry", "about" (pronounced "aboot"), "toque"
- Very polite and friendly tone
- Mix of American and British spelling conventions
- Fitness terms: "hockey training", "outdoor activities", "winter sports"''',
  );

  static const AILanguageConfig indianEnglish = AILanguageConfig(
    id: 'en_in',
    displayName: 'Indian English',
    languageCode: 'en-IN',
    flag: '🇮🇳',
    description: 'Indian English with local expressions',
    voicePatterns: [
      'en-in', 'en_in', 'indian', 'india',
      'rishi', 'veena'
    ],
    defaultSpeechRate: 0.65,
    defaultPitch: 1.05,
    systemPromptAddition: '''

LANGUAGE STYLE: Use Indian English with respectful expressions:
- Vocabulary: "ji", "yaar", "actually", "only", "itself"
- Respectful and warm tone
- British spelling conventions
- Fitness terms: "yoga", "pranayama", "namaste", "good health"''',
  );

  static const AILanguageConfig southAfricanEnglish = AILanguageConfig(
    id: 'en_za',
    displayName: 'South African English',
    languageCode: 'en-ZA',
    flag: '🇿🇦',
    description: 'South African English with local expressions',
    voicePatterns: [
      'en-za', 'en_za', 'south african', 'south africa',
      'tessa'
    ],
    defaultSpeechRate: 0.6,
    defaultPitch: 1.0,
    systemPromptAddition: '''

LANGUAGE STYLE: Use South African English expressions:
- Vocabulary: "lekker", "braai", "howzit", "sharp"
- Friendly and warm tone
- Mix of British and local expressions
- Fitness terms: "lekker workout", "sharp training"''',
  );

  /// Other Major Languages
  static const AILanguageConfig spanish = AILanguageConfig(
    id: 'es',
    displayName: 'Español',
    languageCode: 'es-ES',
    flag: '🇪🇸',
    description: 'Spanish language responses',
    voicePatterns: [
      'es-es', 'es_es', 'spanish', 'spain', 'español',
      'monica', 'jorge', 'esperanza'
    ],
    defaultSpeechRate: 0.65,
    defaultPitch: 1.1,
    systemPromptAddition: '''

LANGUAGE: Respond in Spanish (Español):
- Use proper Spanish grammar and vocabulary
- Fitness terms: "entrenamiento", "ejercicio", "salud", "bienestar"
- Warm and encouraging tone typical of Spanish culture''',
  );

  static const AILanguageConfig french = AILanguageConfig(
    id: 'fr',
    displayName: 'Français',
    languageCode: 'fr-FR',
    flag: '🇫🇷',
    description: 'French language responses',
    voicePatterns: [
      'fr-fr', 'fr_fr', 'french', 'france', 'français',
      'amelie', 'thomas', 'marie'
    ],
    defaultSpeechRate: 0.6,
    defaultPitch: 1.05,
    systemPromptAddition: '''

LANGUAGE: Respond in French (Français):
- Use proper French grammar and vocabulary
- Fitness terms: "entraînement", "exercice", "santé", "bien-être"
- Elegant and refined tone typical of French culture''',
  );

  static const AILanguageConfig german = AILanguageConfig(
    id: 'de',
    displayName: 'Deutsch',
    languageCode: 'de-DE',
    flag: '🇩🇪',
    description: 'German language responses',
    voicePatterns: [
      'de-de', 'de_de', 'german', 'germany', 'deutsch',
      'anna', 'markus', 'petra'
    ],
    defaultSpeechRate: 0.55,
    defaultPitch: 0.95,
    systemPromptAddition: '''

LANGUAGE: Respond in German (Deutsch):
- Use proper German grammar and vocabulary
- Fitness terms: "Training", "Übung", "Gesundheit", "Wohlbefinden"
- Direct and efficient tone typical of German culture''',
  );

  static const AILanguageConfig italian = AILanguageConfig(
    id: 'it',
    displayName: 'Italiano',
    languageCode: 'it-IT',
    flag: '🇮🇹',
    description: 'Italian language responses',
    voicePatterns: [
      'it-it', 'it_it', 'italian', 'italy', 'italiano',
      'alice', 'luca', 'federica'
    ],
    defaultSpeechRate: 0.65,
    defaultPitch: 1.1,
    systemPromptAddition: '''

LANGUAGE: Respond in Italian (Italiano):
- Use proper Italian grammar and vocabulary
- Fitness terms: "allenamento", "esercizio", "salute", "benessere"
- Expressive and passionate tone typical of Italian culture''',
  );

  static const AILanguageConfig portuguese = AILanguageConfig(
    id: 'pt',
    displayName: 'Português',
    languageCode: 'pt-PT',
    flag: '🇵🇹',
    description: 'Portuguese language responses',
    voicePatterns: [
      'pt-pt', 'pt_pt', 'portuguese', 'portugal', 'português',
      'joana', 'ricardo'
    ],
    defaultSpeechRate: 0.6,
    defaultPitch: 1.05,
    systemPromptAddition: '''

LANGUAGE: Respond in Portuguese (Português):
- Use proper Portuguese grammar and vocabulary
- Fitness terms: "treino", "exercício", "saúde", "bem-estar"
- Warm and friendly tone typical of Portuguese culture''',
  );

  static const AILanguageConfig dutch = AILanguageConfig(
    id: 'nl',
    displayName: 'Nederlands',
    languageCode: 'nl-NL',
    flag: '🇳🇱',
    description: 'Dutch language responses',
    voicePatterns: [
      'nl-nl', 'nl_nl', 'dutch', 'netherlands', 'nederlands',
      'claire', 'xander'
    ],
    defaultSpeechRate: 0.6,
    defaultPitch: 1.0,
    systemPromptAddition: '''

LANGUAGE: Respond in Dutch (Nederlands):
- Use proper Dutch grammar and vocabulary
- Fitness terms: "training", "oefening", "gezondheid", "welzijn"
- Direct and friendly tone typical of Dutch culture''',
  );

  static const AILanguageConfig russian = AILanguageConfig(
    id: 'ru',
    displayName: 'Русский',
    languageCode: 'ru-RU',
    flag: '🇷🇺',
    description: 'Russian language responses',
    voicePatterns: [
      'ru-ru', 'ru_ru', 'russian', 'russia', 'русский',
      'milena', 'yuri'
    ],
    defaultSpeechRate: 0.55,
    defaultPitch: 0.95,
    systemPromptAddition: '''

LANGUAGE: Respond in Russian (Русский):
- Use proper Russian grammar and vocabulary
- Fitness terms: "тренировка", "упражнение", "здоровье", "благополучие"
- Formal but warm tone typical of Russian culture''',
  );

  static const AILanguageConfig japanese = AILanguageConfig(
    id: 'ja',
    displayName: '日本語',
    languageCode: 'ja-JP',
    flag: '🇯🇵',
    description: 'Japanese language responses',
    voicePatterns: [
      'ja-jp', 'ja_jp', 'japanese', 'japan', '日本語',
      'kyoko', 'otoya'
    ],
    defaultSpeechRate: 0.5,
    defaultPitch: 1.1,
    systemPromptAddition: '''

LANGUAGE: Respond in Japanese (日本語):
- Use proper Japanese grammar and vocabulary
- Fitness terms: "トレーニング", "運動", "健康", "ウェルネス"
- Polite and respectful tone typical of Japanese culture''',
  );

  static const AILanguageConfig korean = AILanguageConfig(
    id: 'ko',
    displayName: '한국어',
    languageCode: 'ko-KR',
    flag: '🇰🇷',
    description: 'Korean language responses',
    voicePatterns: [
      'ko-kr', 'ko_kr', 'korean', 'korea', '한국어',
      'yuna', 'insu'
    ],
    defaultSpeechRate: 0.55,
    defaultPitch: 1.05,
    systemPromptAddition: '''

LANGUAGE: Respond in Korean (한국어):
- Use proper Korean grammar and vocabulary
- Fitness terms: "운동", "트레이닝", "건강", "웰빙"
- Respectful and encouraging tone typical of Korean culture''',
  );

  static const AILanguageConfig chinese = AILanguageConfig(
    id: 'zh',
    displayName: '中文',
    languageCode: 'zh-CN',
    flag: '🇨🇳',
    description: 'Chinese language responses',
    voicePatterns: [
      'zh-cn', 'zh_cn', 'chinese', 'china', '中文',
      'ting-ting', 'huihui'
    ],
    defaultSpeechRate: 0.6,
    defaultPitch: 1.0,
    systemPromptAddition: '''

LANGUAGE: Respond in Chinese (中文):
- Use proper Chinese grammar and vocabulary
- Fitness terms: "训练", "锻炼", "健康", "健身"
- Respectful and encouraging tone typical of Chinese culture''',
  );

  static const AILanguageConfig arabic = AILanguageConfig(
    id: 'ar',
    displayName: 'العربية',
    languageCode: 'ar-SA',
    flag: '🇸🇦',
    description: 'Arabic language responses',
    voicePatterns: [
      'ar-sa', 'ar_sa', 'arabic', 'العربية',
      'maged', 'hoda'
    ],
    defaultSpeechRate: 0.6,
    defaultPitch: 1.0,
    systemPromptAddition: '''

LANGUAGE: Respond in Arabic (العربية):
- Use proper Arabic grammar and vocabulary
- Fitness terms: "تدريب", "تمرين", "صحة", "عافية"
- Respectful and warm tone typical of Arabic culture''',
  );

  static const AILanguageConfig hindi = AILanguageConfig(
    id: 'hi',
    displayName: 'हिन्दी',
    languageCode: 'hi-IN',
    flag: '🇮🇳',
    description: 'Hindi language responses',
    voicePatterns: [
      'hi-in', 'hi_in', 'hindi', 'हिन्दी',
      'kalpana', 'hemant'
    ],
    defaultSpeechRate: 0.65,
    defaultPitch: 1.05,
    systemPromptAddition: '''

LANGUAGE: Respond in Hindi (हिन्दी):
- Use proper Hindi grammar and vocabulary
- Fitness terms: "प्रशिक्षण", "व्यायाम", "स्वास्थ्य", "कल्याण"
- Respectful and warm tone typical of Hindi culture''',
  );

  /// Get language config by ID
  static AILanguageConfig? getById(String id) {
    try {
      return all.firstWhere((lang) => lang.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get language config by language code
  static AILanguageConfig? getByLanguageCode(String code) {
    try {
      return all.firstWhere((lang) => lang.languageCode == code);
    } catch (e) {
      return null;
    }
  }

  /// Find best matching voice for this language
  String? findBestVoice(List<Map<String, String>> availableVoices) {
    // First try exact language code match
    for (final voice in availableVoices) {
      final locale = voice['locale']?.toLowerCase() ?? '';
      if (locale == languageCode.toLowerCase()) {
        return voice['name'];
      }
    }

    // Then try pattern matching
    for (final pattern in voicePatterns) {
      for (final voice in availableVoices) {
        final name = voice['name']?.toLowerCase() ?? '';
        final locale = voice['locale']?.toLowerCase() ?? '';
        if (name.contains(pattern.toLowerCase()) || 
            locale.contains(pattern.toLowerCase())) {
          return voice['name'];
        }
      }
    }

    return null;
  }

  /// Get grouped languages for UI display
  static Map<String, List<AILanguageConfig>> getGroupedLanguages() {
    return {
      'English Variants': [
        americanEnglish,
        britishEnglish,
        australianEnglish,
        canadianEnglish,
        indianEnglish,
        southAfricanEnglish,
      ],
      'European Languages': [
        spanish,
        french,
        german,
        italian,
        portuguese,
        dutch,
        russian,
      ],
      'Asian Languages': [
        japanese,
        korean,
        chinese,
        hindi,
      ],
      'Other Languages': [
        arabic,
      ],
    };
  }
}