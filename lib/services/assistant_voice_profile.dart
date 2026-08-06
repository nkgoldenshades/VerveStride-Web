/// User-selectable assistant personality (affects AI reply tone + default TTS).
class AssistantVoiceMode {
  static const String calm = 'calm';
  static const String balanced = 'balanced';
  static const String energetic = 'energetic';

  static const List<String> all = [calm, balanced, energetic];

  /// Short instruction injected into chat / smart actions (English).
  static String styleInstruction(String? mode) {
    switch (mode) {
      case calm:
        return 'Tone: calm, warm, and reassuring. Use gentle language and short, easy sentences. '
            'Avoid hype or shouting.';
      case energetic:
        return 'Tone: upbeat and motivating. Be concise and punchy. Sound excited but still helpful '
            'and safe (no reckless fitness advice).';
      case balanced:
      default:
        return 'Tone: friendly, clear, and professional — balanced between supportive and direct.';
    }
  }

  /// Default TTS speech rate (Flutter TTS scale ~0.1–1.0).
  static double ttsRate(String? mode) {
    switch (mode) {
      case calm:
        return 0.42;
      case energetic:
        return 0.62;
      case balanced:
      default:
        return 0.5;
    }
  }

  /// Default TTS pitch multiplier (~0.5–2.0).
  static double ttsPitch(String? mode) {
    switch (mode) {
      case calm:
        return 0.92;
      case energetic:
        return 1.08;
      case balanced:
      default:
        return 1.0;
    }
  }
}

/// Filters device TTS voices by guessed gender (best-effort; engines vary by OS).
class VoiceGenderFilter {
  static const String any = 'any';
  static const String male = 'male';
  static const String female = 'female';

  static const List<String> all = [any, male, female];

  /// true = female, false = male, null = unknown
  static bool? inferGender(String name, String locale) {
    final s = '${name}_$locale'.toLowerCase();

    if (s.contains('#female') || s.contains('female#')) return true;
    if (s.contains('#male') || s.contains('male#')) return false;
    if (RegExp(r'(^|[^a-z])female([^a-z]|$)').hasMatch(s)) return true;
    if (RegExp(r'(^|[^a-z])male([^a-z]|$)').hasMatch(s)) return false;

    // Strong female hints (many Android / Google voices)
    const femaleHints = [
      'female',
      'woman',
      'zira',
      'samantha',
      'karen',
      'susan',
      'victoria',
      'allison',
      'ava',
      'nicky',
      'fiona',
      'moira',
      'tessa',
      'serena',
      'catherine',
      'melina',
      'amelie',
      'anna',
      'carmit',
      'damayanti',
      'ellen',
      'kyoko',
      'laura',
      'lekha',
      'mariska',
      'mei-jia',
      'milena',
      'paulina',
      'sara',
      'satu',
      'sin-ji',
      'tian-tian',
      'ting-ting',
      'veena',
      'xander',
      'yelda',
      'yuna',
      'zosia',
      'zuzana',
      '-gb-female',
      'us-female',
      'en-gb-x-gbf',
      'f#female',
      'female#',
      'woman',
      'girl',
    ];
    for (final h in femaleHints) {
      if (s.contains(h)) return true;
    }

    // Strong male hints
    const maleHints = [
      'male',
      'man',
      'daniel',
      'fred',
      'aaron',
      'tom',
      'alex',
      'bruce',
      'jorge',
      'diego',
      'oliver',
      'lee',
      'nathan',
      'ralph',
      'rocky',
      'gordon',
      'reed',
      'shelley',
      'carlos',
      'jorge',
      'juan',
      'diego',
      'felipe',
      'thomas',
      'xander',
      '-gb-male',
      'us-male',
      'en-us-x-sfg#male',
      'en-us-x-sfg',
      'male#',
      'man',
      'boy',
    ];
    for (final h in maleHints) {
      if (s.contains(h)) return false;
    }

    // Pattern: ...-male / ...-female in compact ids
    if (s.contains('-male') && !s.contains('-female')) return false;
    if (s.contains('-female')) return true;

    return null;
  }

  static List<Map<String, String>> filter(
    List<Map<String, String>> voices,
    String gender,
  ) {
    if (gender == VoiceGenderFilter.any) return List.from(voices);

    final out = <Map<String, String>>[];
    for (final v in voices) {
      final n = v['name'] ?? '';
      final loc = v['locale'] ?? '';
      final g = inferGender(n, loc);
      if (gender == VoiceGenderFilter.female) {
        if (g == true) out.add(v);
      } else if (gender == VoiceGenderFilter.male) {
        if (g == false) out.add(v);
      }
    }
    return out;
  }
}
