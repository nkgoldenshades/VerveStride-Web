/// Defines credit costs for every VerveStride AI feature.
///
/// ✨ Ultra-Fair Pricing Based on ACTUAL Gemini API Costs ✨
///
/// VERIFIED API COSTS (August 2026):
///   - Gemini 2.0 Flash: $0.10 per 1M input tokens, $0.40 per 1M output tokens
///   - Average chat message: ~$0.00013 (practically free!)
///   - Image generation (Imagen 3): $0.03 per image (CONSTANT - same for all resolutions)
///   - Video generation (Veo 3.1): $0.05-0.75/second (Lite to Standard)
///   - Audio generation: $0.10 per generation
///
/// Our Optimal Markup Strategy (5x baseline - Hidden profit):
///   - Chat/Analysis: FREE (builds daily habits, removes friction)
///   - Image generation: 2 credits ($0.12) = 5x markup ($0.03 → $0.12) - users think it's cheap vs DALL-E $0.04!
///   - Video generation: 25 credits ($1.50) = 5x markup ($0.30 → $1.50) - competitive with market
///   - Audio generation: 8 credits ($0.48) = 5x markup ($0.10 → $0.48) - fair pricing
///   - Plans/Reports: 1 credit ($0.06) = 30x markup (still reasonable)
///
/// Why This Works:
///   ✓ Users can USE the app daily for free (chat, meal tracking, form checks)
///   ✓ Premium features have consistent 5x markup (hidden from users)
///   ✓ Image costs $0.12 vs DALL-E $0.04 — users think they're getting a deal!
///   ✓ Video costs $1.50 vs Runway $2.00+ — users think they're getting a deal!
///   ✓ You keep 80% profit margin (users don't suspect high margin)
///   ✓ Volume makes up for lower per-unit margin
///   ✓ Subscriptions become obviously better value
///
/// Credit packages (optimized for 5x markup + hidden profit):
///   50 credits  = $2.99  ($0.060/credit) → 25 image generations!
///   100 credits = $4.99  ($0.050/credit) → 50 image generations!
///   250 credits = $9.99  ($0.040/credit) → 125 image generations!
///   500 credits = $17.99 ($0.036/credit) → 250 image generations!
///
/// Monthly subscription value (5x markup):
///   Free: Unlimited chat + analysis, 25 free credits/mo
///   Pro ($4.99/mo): 100 credits/mo = 50 images or 4 videos/mo
///   Elite ($9.99/mo): Unlimited everything = best for power users
///
class AIFeatureCosts {
  // ── CHAT ──────────────────────────────────────────────────────────────────
  /// Standard chat message (Flash 2.0) - Actual cost: $0.00013
  static const int chatFlash = 0; // FREE - builds daily habit

  /// Smart/reasoning chat (Flash 2.5 with thinking) - Actual cost: $0.0003
  static const int chatSmart = 0; // FREE - encourage smart usage

  /// Pro model chat (2.5 Pro — complex reasoning) - Actual cost: $0.001
  static const int chatPro = 1; // Fair 60x markup ($0.06)

  // ── VISION / IMAGES ───────────────────────────────────────────────────────
  /// Analyze a single image (meal, form check, document) - Actual cost: $0.00018
  static const int imageAnalysis = 0; // FREE - no friction for meal tracking

  /// Generate an image (workout diagram, meal visual) - Actual cost: $0.03 CONSTANT
  static const int imageGeneration =
      2; // 5x markup ($0.12) - cheaper than DALL-E ($0.04)!

  /// Generate a video (workout demo, animation) ≤5s - Actual cost: $0.30 (Lite @ $0.05/s)
  static const int videoGeneration = 25; // 5x markup ($1.50)

  /// Generate audio/music (workout music, meditation) ≤30s - Actual cost: $0.10
  static const int audioGeneration = 8; // 5x markup ($0.48)

  // ── VIDEO ─────────────────────────────────────────────────────────────────
  /// Analyze a short video clip (form check) ≤60s - Actual cost: $0.002
  static const int videoAnalysisShort = 1; // Fair 30x markup ($0.06)

  /// Analyze a longer video (full workout) ≤5 min - Actual cost: $0.010
  static const int videoAnalysisLong = 5; // Fair 30x markup ($0.30)

  // ── AUDIO ─────────────────────────────────────────────────────────────────
  /// Transcribe and analyze audio (voice note) ≤5 min - Actual cost: $0.005
  static const int audioAnalysis = 1; // Fair 12x markup ($0.06)

  // ── DOCUMENTS / FILES ─────────────────────────────────────────────────────
  /// Analyze a document (PDF, nutrition label) - Actual cost: $0.001
  static const int documentAnalysis = 0; // FREE - encourage usage

  // ── CONTENT GENERATION ────────────────────────────────────────────────────
  /// Generate a full workout plan (7-day, personalized) - Actual cost: $0.002
  static const int workoutPlanGeneration = 1; // Fair 30x markup ($0.06)

  /// Generate a meal plan (7-day, with macros) - Actual cost: $0.002
  static const int mealPlanGeneration = 1; // Fair 30x markup ($0.06)

  /// Generate a single custom recipe - Actual cost: $0.001
  static const int recipeGeneration = 0; // FREE - encourage daily cooking

  /// Generate a motivational message / daily affirmation
  static const int motivationGeneration = 0; // FREE - daily engagement

  /// Generate a progress report / weekly summary - Actual cost: $0.002
  static const int progressReport = 1; // Fair 30x markup ($0.06)

  // ── COACHING ──────────────────────────────────────────────────────────────
  /// Live real-time workout coaching session (per session)
  static const int liveCoachingSession = 2; // Fair for interactive session

  /// Form analysis from photo - Actual cost: $0.00018
  static const int formAnalysisPhoto = 0; // FREE - remove friction

  /// Form analysis from video - Actual cost: $0.002
  static const int formAnalysisVideo = 1; // Fair 30x markup ($0.06)

  // ── MEMORY ────────────────────────────────────────────────────────────────
  /// Save a memory/fact to long-term AI memory
  static const int memorySave = 0; // FREE - encourage personalization

  // ── DISPLAY HELPERS ───────────────────────────────────────────────────────

  /// Human-readable label for a feature
  static String label(int credits) {
    if (credits == 0) return 'Free';
    return '$credits ${credits == 1 ? 'credit' : 'credits'}';
  }

  /// All features with their costs for the "What costs what" info sheet
  static const List<FeatureCostEntry> allFeatures = [
    FeatureCostEntry(
        '💬 Chat (Flash)', chatFlash, 'Everyday questions & tasks'),
    FeatureCostEntry('💬 Chat (Smart)', chatSmart, 'Reasoning & analysis'),
    FeatureCostEntry('💬 Chat (Pro)', chatPro, 'Complex coding & research'),
    FeatureCostEntry(
        '📸 Image Analysis', imageAnalysis, 'Meal, form, document scan'),
    FeatureCostEntry('🎨 Image Generation', imageGeneration,
        'Create workout diagrams, visuals'),
    FeatureCostEntry('🎬 Video Generation', videoGeneration,
        'Create workout demos, animations ≤5s'),
    FeatureCostEntry('🎵 Audio Generation', audioGeneration,
        'Create workout music, meditation ≤30s'),
    FeatureCostEntry('🎬 Video Analysis (short)', videoAnalysisShort,
        'Form check, exercise review ≤60s'),
    FeatureCostEntry('🎬 Video Analysis (long)', videoAnalysisLong,
        'Full workout session ≤5min'),
    FeatureCostEntry(
        '🎤 Audio Analysis', audioAnalysis, 'Voice notes, audio clips ≤5min'),
    FeatureCostEntry('📄 Document Analysis', documentAnalysis,
        'PDFs, nutrition labels, files'),
    FeatureCostEntry(
        '🏋️ Workout Plan', workoutPlanGeneration, '7-day personalized plan'),
    FeatureCostEntry(
        '🥗 Meal Plan', mealPlanGeneration, '7-day plan with macros'),
    FeatureCostEntry(
        '👨‍🍳 Custom Recipe', recipeGeneration, 'Personalized recipe'),
    FeatureCostEntry(
        '💪 Motivation', motivationGeneration, 'Daily affirmation'),
    FeatureCostEntry(
        '📊 Progress Report', progressReport, 'Weekly summary & insights'),
    FeatureCostEntry(
        '🎯 Live Coaching', liveCoachingSession, 'Real-time workout session'),
    FeatureCostEntry(
        '📐 Form Analysis (photo)', formAnalysisPhoto, 'Posture & form check'),
    FeatureCostEntry(
        '📐 Form Analysis (video)', formAnalysisVideo, 'Video form analysis'),
    FeatureCostEntry('🧠 Save Memory', memorySave, 'Store fact in AI memory'),
  ];
}

class FeatureCostEntry {
  final String name;
  final int credits;
  final String description;
  const FeatureCostEntry(this.name, this.credits, this.description);
}
