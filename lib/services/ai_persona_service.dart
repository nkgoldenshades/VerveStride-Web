/// AI Persona Service
///
/// Makes VerveStride AI adaptive — it detects what persona the user wants
/// and mirrors their communication style throughout the conversation.
///
/// Examples:
///   "be my mirror"         → mirrors user's exact tone and style
///   "be my fitness coach"  → strict, motivating, coach-like
///   "be my friend"         → casual, warm, supportive
///   "be my nutritionist"   → clinical, precise, food-focused
///   "be strict with me"    → no-nonsense, direct, challenging
///   "be gentle"            → soft, encouraging, patient
class AIPersonaService {
  AIPersonaService._();
  static final AIPersonaService instance = AIPersonaService._();

  // ── Persona detection ────────────────────────────────────────────────────

  /// Detect if the user is setting a persona in their message.
  /// Returns the detected persona string, or null if no persona set.
  String? detectPersonaChange(String message) {
    final text = message.toLowerCase().trim();

    // Direct persona commands
    final patterns = <String, String>{
      // Mirror / clone
      r"(be|act|you are|you're).*(my mirror|like me|mirror me|copy me|mimic me)": 'mirror',
      r'(mirror|mimic|copy) (me|my style|how i talk)': 'mirror',

      // Fitness coach
      r"(be|act|you are|you're).*(my (fitness |workout |personal )?coach)": 'fitness_coach',
      r'(coach me|train me|be my trainer)': 'fitness_coach',

      // Strict trainer
      r'(be|act).*(strict|tough|hard on me|no excuses|push me)': 'strict_trainer',
      r"(don't go easy|be harsh|be brutal|no mercy)": 'strict_trainer',

      // Friend
      r"(be|act|you are|you're).*(my friend|like a friend|friendly)": 'friend',
      r'(talk to me like|treat me like).*(friend|buddy|pal|bro|mate)': 'friend',

      // Nutritionist / dietitian
      r"(be|act|you are|you're).*(my (nutritionist|dietitian|diet coach))": 'nutritionist',
      r'(focus on|talk about).*(food|nutrition|diet|eating|calories)': 'nutritionist',

      // Motivator
      r'(be|act).*(motivat|hype|encourage|inspire)': 'motivator',
      r'(motivate me|hype me up|keep me going)': 'motivator',

      // Gentle / soft
      r'(be|act).*(gentle|soft|kind|patient|easy on me)': 'gentle',
      r"(don't be harsh|be nice|be sweet)": 'gentle',

      // Professional / formal
      r'(be|act).*(professional|formal|serious|clinical)': 'professional',

      // Reset to default
      r'(be yourself|default|normal|reset|stop being|go back to)': 'default',
    };

    for (final entry in patterns.entries) {
      if (RegExp(entry.key).hasMatch(text)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Detect the user's communication style from their messages.
  String detectUserStyle(List<String> recentMessages) {
    if (recentMessages.isEmpty) return 'casual';

    final combined = recentMessages.join(' ').toLowerCase();
    final wordCount = combined.split(' ').length;
    final avgLength = wordCount / recentMessages.length;

    // Even from a single short message, detect style
    final single = recentMessages.last.toLowerCase();

    // ALL CAPS = shouting/energetic
    if (recentMessages.last == recentMessages.last.toUpperCase() &&
        recentMessages.last.length > 3) return 'energetic';

    // Short messages = casual
    if (avgLength < 5) return 'casual_short';

    // Check for formal indicators
    final formalWords = ['please', 'could you', 'would you', 'kindly', 'regarding', 'i would like'];
    final formalCount = formalWords.where((w) => combined.contains(w)).length;
    if (formalCount >= 1) return 'formal';

    // Check for casual/slang
    final casualWords = ['lol', 'haha', 'bro', 'dude', 'gonna', 'wanna', 'tbh', 'ngl', 'fr', 'bruh', 'omg', 'wtf', 'imo'];
    final casualCount = casualWords.where((w) => combined.contains(w)).length;
    if (casualCount >= 1) return 'casual_slang';

    // Check for motivational/energetic
    final energyWords = ['!', "let's go", 'yes', 'amazing', 'great', 'awesome', 'love', 'fire', 'lit'];
    final energyCount = energyWords.where((w) => combined.contains(w)).length;
    if (energyCount >= 2) return 'energetic';

    // Single word or very short = casual_short
    if (single.split(' ').length <= 2) return 'casual_short';

    return 'casual';
  }

  // ── Persona system prompts ────────────────────────────────────────────────

  /// Build the persona instruction to inject into the system prompt.
  String buildPersonaInstruction(String? persona, String? userStyle) {
    final styleInstruction = _styleInstruction(userStyle);
    final personaInstruction = _personaInstruction(persona);

    if (personaInstruction.isEmpty && styleInstruction.isEmpty) return '';

    return '\n\nADAPTIVE BEHAVIOR:\n$personaInstruction$styleInstruction';
  }

  String _personaInstruction(String? persona) {
    switch (persona) {
      case 'mirror':
        return
            'MIRROR MODE: You are the user\'s mirror. '
            'Completely match their tone, energy, vocabulary, and communication style. '
            'If they are casual, be casual. If they use slang, use slang back. '
            'If they are excited, match their excitement. '
            'Reflect their personality back at them — be their echo, their twin. '
            'Still give accurate, helpful information, but in their exact voice.\n';

      case 'fitness_coach':
        return
            'COACH MODE: You are their dedicated personal fitness coach. '
            'Be motivating, structured, and goal-focused. '
            'Use coaching language: "Let\'s go!", "You\'ve got this!", "Here\'s your plan:". '
            'Always bring conversations back to their fitness goals. '
            'Celebrate wins, address setbacks constructively. '
            'Give specific, actionable advice — not vague encouragement.\n';

      case 'strict_trainer':
        return
            'STRICT TRAINER MODE: No excuses. No hand-holding. '
            'Be direct, demanding, and results-focused. '
            'Call out laziness or excuses firmly but fairly. '
            'Push the user beyond their comfort zone. '
            'Short, punchy responses. No fluff. '
            'Example tone: "That\'s not good enough. You can do better. Here\'s what you\'re doing tomorrow:"\n';

      case 'friend':
        return
            'FRIEND MODE: You are their close, supportive friend. '
            'Be warm, casual, and genuinely caring. '
            'Use their name, ask follow-up questions, remember what they share. '
            'Celebrate with them, support them through struggles. '
            'Talk like a real friend — not a robot, not a professional. '
            'It\'s okay to be funny, relatable, and human.\n';

      case 'nutritionist':
        return
            'NUTRITIONIST MODE: You are their personal nutritionist. '
            'Focus on food, nutrition, macros, meal timing, and dietary habits. '
            'Be precise with numbers (calories, protein, carbs, fat). '
            'Give evidence-based advice. '
            'Always connect food choices to their specific goals.\n';

      case 'motivator':
        return
            'MOTIVATOR MODE: Your job is to hype them up and keep them going. '
            'Be high-energy, enthusiastic, and relentlessly positive. '
            'Use power words: "Unstoppable!", "You\'re crushing it!", "Let\'s GO!". '
            'Turn every obstacle into an opportunity. '
            'Make them feel like they can achieve anything.\n';

      case 'gentle':
        return
            'GENTLE MODE: Be soft, patient, and deeply encouraging. '
            'Never pressure or rush. Celebrate every small win. '
            'Use warm, caring language. '
            'If they\'re struggling, validate their feelings first before giving advice. '
            'Be their safe space — judgment-free, always supportive.\n';

      case 'professional':
        return
            'PROFESSIONAL MODE: Be formal, precise, and clinical. '
            'Use proper terminology. Structure responses clearly. '
            'Avoid casual language or emojis. '
            'Be thorough and evidence-based in all advice.\n';

      case 'default':
      case null:
        return '';

      default:
        // Custom persona — use the raw string
        return
            'CUSTOM PERSONA: The user has asked you to be "$persona". '
            'Adapt your tone, style, and approach to match this persona '
            'while still being helpful and accurate.\n';
    }
  }

  String _styleInstruction(String? style) {
    switch (style) {
      case 'casual_slang':
        return 'STYLE: User is casual and uses slang. Match their vibe — keep it real, short, relatable. Use their language back.\n';
      case 'casual_short':
        return 'STYLE: User sends short messages. Mirror that — be brief, punchy, no long paragraphs.\n';
      case 'formal':
        return 'STYLE: User is polite and formal. Match their professional tone.\n';
      case 'energetic':
        return 'STYLE: User is high-energy. Match their enthusiasm — be upbeat, use exclamations, keep the energy up!\n';
      case 'casual':
      default:
        return 'STYLE: Keep it natural and conversational — like texting a smart friend.\n';
    }
  }

  // ── Persona display ───────────────────────────────────────────────────────

  /// Human-readable label for the current persona
  static String personaLabel(String? persona) {
    switch (persona) {
      case 'mirror':         return '🪞 Mirror Mode';
      case 'fitness_coach':  return '🏋️ Fitness Coach';
      case 'strict_trainer': return '💪 Strict Trainer';
      case 'friend':         return '👋 Friend Mode';
      case 'nutritionist':   return '🥗 Nutritionist';
      case 'motivator':      return '🔥 Motivator';
      case 'gentle':         return '🌸 Gentle Mode';
      case 'professional':   return '💼 Professional';
      case null:             return '🤖 VerveStride AI';
      default:               return '✨ $persona';
    }
  }

  /// Emoji for the current persona
  static String personaEmoji(String? persona) {
    switch (persona) {
      case 'mirror':         return '🪞';
      case 'fitness_coach':  return '🏋️';
      case 'strict_trainer': return '💪';
      case 'friend':         return '👋';
      case 'nutritionist':   return '🥗';
      case 'motivator':      return '🔥';
      case 'gentle':         return '🌸';
      case 'professional':   return '💼';
      default:               return '🤖';
    }
  }
}
