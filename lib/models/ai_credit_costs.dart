/// AI Credit Costs for all VerveStride AI features
/// Shows users exactly how many credits each action costs
class AICreditCosts {
  // ═══════════════════════════════════════════════════════════════════════════
  // TEXT-BASED FEATURES
  // ═══════════════════════════════════════════════════════════════════════════
  
  static const int chatMessage = 1;
  static const int voiceCommand = 1;
  static const int quickQuestion = 1;
  static const int workoutSuggestion = 2;
  static const int mealPlanGeneration = 3;
  static const int progressInsights = 2;
  static const int goalRecommendation = 2;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // VISION FEATURES (Photo/Image Analysis)
  // ═══════════════════════════════════════════════════════════════════════════
  
  static const int mealPhotoAnalysis = 2;
  static const int formCheckPhoto = 3;
  static const int progressPhotoAnalysis = 2;
  static const int ingredientIdentification = 2;
  static const int exerciseFormPhoto = 3;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // VIDEO FEATURES (Video Analysis)
  // ═══════════════════════════════════════════════════════════════════════════
  
  static const int workoutVideoAnalysis = 5;
  static const int formCheckVideo = 5;
  static const int exerciseTechniqueVideo = 5;
  static const int repCountingVideo = 4;
  static const int poseDetectionVideo = 4;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // AUDIO FEATURES (Voice/Audio Processing)
  // ═══════════════════════════════════════════════════════════════════════════
  
  static const int voiceToText = 1;
  static const int audioCoaching = 2;
  static const int voiceConversation = 2;
  static const int audioFeedback = 2;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // LIVE/REAL-TIME FEATURES
  // ═══════════════════════════════════════════════════════════════════════════
  
  static const int liveWorkoutCoaching = 5; // Per workout session
  static const int liveFormCorrection = 5; // Per workout session
  static const int realTimeMotivation = 3; // Per workout session
  static const int liveRepCounting = 4; // Per workout session
  
  // ═══════════════════════════════════════════════════════════════════════════
  // ADVANCED FEATURES
  // ═══════════════════════════════════════════════════════════════════════════
  
  static const int comprehensiveAnalysis = 5;
  static const int longTermPlanning = 4;
  static const int nutritionStrategy = 4;
  static const int injuryPrevention = 3;
  static const int performanceOptimization = 5;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // CONTENT GENERATION
  // ═══════════════════════════════════════════════════════════════════════════
  
  static const int workoutPlanGeneration = 4;
  static const int mealPlanWeekly = 5;
  static const int customRecipeGeneration = 3;
  static const int motivationalContent = 2;
  static const int progressReport = 3;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Get cost for a specific feature
  static int getCost(String feature) {
    switch (feature) {
      // Text
      case 'chat_message': return chatMessage;
      case 'voice_command': return voiceCommand;
      case 'quick_question': return quickQuestion;
      case 'workout_suggestion': return workoutSuggestion;
      case 'meal_plan': return mealPlanGeneration;
      case 'insights': return progressInsights;
      case 'goal_recommendation': return goalRecommendation;
      
      // Vision
      case 'meal_photo': return mealPhotoAnalysis;
      case 'form_photo': return formCheckPhoto;
      case 'progress_photo': return progressPhotoAnalysis;
      case 'ingredient_id': return ingredientIdentification;
      case 'exercise_photo': return exerciseFormPhoto;
      
      // Video
      case 'workout_video': return workoutVideoAnalysis;
      case 'form_video': return formCheckVideo;
      case 'technique_video': return exerciseTechniqueVideo;
      case 'rep_counting': return repCountingVideo;
      case 'pose_detection': return poseDetectionVideo;
      
      // Audio
      case 'voice_to_text': return voiceToText;
      case 'audio_coaching': return audioCoaching;
      case 'voice_conversation': return voiceConversation;
      case 'audio_feedback': return audioFeedback;
      
      // Live
      case 'live_coaching': return liveWorkoutCoaching;
      case 'live_form': return liveFormCorrection;
      case 'live_motivation': return realTimeMotivation;
      case 'live_reps': return liveRepCounting;
      
      // Advanced
      case 'comprehensive': return comprehensiveAnalysis;
      case 'long_term': return longTermPlanning;
      case 'nutrition_strategy': return nutritionStrategy;
      case 'injury_prevention': return injuryPrevention;
      case 'performance': return performanceOptimization;
      
      // Content
      case 'workout_plan': return workoutPlanGeneration;
      case 'weekly_meals': return mealPlanWeekly;
      case 'recipe': return customRecipeGeneration;
      case 'motivation': return motivationalContent;
      case 'report': return progressReport;
      
      default: return 1;
    }
  }
  
  /// Get user-friendly description
  static String getDescription(String feature) {
    switch (feature) {
      // Text
      case 'chat_message': return 'AI Chat Message';
      case 'voice_command': return 'Voice Command';
      case 'quick_question': return 'Quick Question';
      case 'workout_suggestion': return 'Workout Suggestion';
      case 'meal_plan': return 'Meal Plan Generation';
      case 'insights': return 'Progress Insights';
      case 'goal_recommendation': return 'Goal Recommendation';
      
      // Vision
      case 'meal_photo': return 'Meal Photo Analysis';
      case 'form_photo': return 'Form Check (Photo)';
      case 'progress_photo': return 'Progress Photo Analysis';
      case 'ingredient_id': return 'Ingredient Identification';
      case 'exercise_photo': return 'Exercise Form (Photo)';
      
      // Video
      case 'workout_video': return 'Workout Video Analysis';
      case 'form_video': return 'Form Check (Video)';
      case 'technique_video': return 'Exercise Technique (Video)';
      case 'rep_counting': return 'Rep Counting (Video)';
      case 'pose_detection': return 'Pose Detection (Video)';
      
      // Audio
      case 'voice_to_text': return 'Voice to Text';
      case 'audio_coaching': return 'Audio Coaching';
      case 'voice_conversation': return 'Voice Conversation';
      case 'audio_feedback': return 'Audio Feedback';
      
      // Live
      case 'live_coaching': return 'Live Workout Coaching';
      case 'live_form': return 'Live Form Correction';
      case 'live_motivation': return 'Real-time Motivation';
      case 'live_reps': return 'Live Rep Counting';
      
      // Advanced
      case 'comprehensive': return 'Comprehensive Analysis';
      case 'long_term': return 'Long-term Planning';
      case 'nutrition_strategy': return 'Nutrition Strategy';
      case 'injury_prevention': return 'Injury Prevention';
      case 'performance': return 'Performance Optimization';
      
      // Content
      case 'workout_plan': return 'Workout Plan Generation';
      case 'weekly_meals': return 'Weekly Meal Plan';
      case 'recipe': return 'Custom Recipe';
      case 'motivation': return 'Motivational Content';
      case 'report': return 'Progress Report';
      
      default: return 'AI Feature';
    }
  }
  
  /// Get icon for feature
  static String getIcon(String feature) {
    if (feature.contains('meal') || feature.contains('recipe') || feature.contains('ingredient')) {
      return '🍽️';
    } else if (feature.contains('workout') || feature.contains('exercise') || feature.contains('form')) {
      return '💪';
    } else if (feature.contains('video')) {
      return '🎥';
    } else if (feature.contains('audio') || feature.contains('voice')) {
      return '🎤';
    } else if (feature.contains('live') || feature.contains('real')) {
      return '🔴';
    } else if (feature.contains('photo') || feature.contains('image')) {
      return '📸';
    } else if (feature.contains('chat') || feature.contains('message')) {
      return '💬';
    } else if (feature.contains('plan') || feature.contains('strategy')) {
      return '📋';
    } else if (feature.contains('insight') || feature.contains('analysis')) {
      return '📊';
    } else {
      return '🤖';
    }
  }
  
  /// Get all features grouped by category
  static Map<String, List<Map<String, dynamic>>> getAllFeatures() {
    return {
      'Text & Chat': [
        {'key': 'chat_message', 'cost': chatMessage, 'desc': 'AI Chat Message'},
        {'key': 'voice_command', 'cost': voiceCommand, 'desc': 'Voice Command'},
        {'key': 'quick_question', 'cost': quickQuestion, 'desc': 'Quick Question'},
        {'key': 'workout_suggestion', 'cost': workoutSuggestion, 'desc': 'Workout Suggestion'},
        {'key': 'meal_plan', 'cost': mealPlanGeneration, 'desc': 'Meal Plan'},
        {'key': 'insights', 'cost': progressInsights, 'desc': 'Progress Insights'},
      ],
      'Photo Analysis': [
        {'key': 'meal_photo', 'cost': mealPhotoAnalysis, 'desc': 'Meal Photo Analysis'},
        {'key': 'form_photo', 'cost': formCheckPhoto, 'desc': 'Form Check (Photo)'},
        {'key': 'progress_photo', 'cost': progressPhotoAnalysis, 'desc': 'Progress Photo'},
        {'key': 'ingredient_id', 'cost': ingredientIdentification, 'desc': 'Ingredient ID'},
        {'key': 'exercise_photo', 'cost': exerciseFormPhoto, 'desc': 'Exercise Form'},
      ],
      'Video Analysis': [
        {'key': 'workout_video', 'cost': workoutVideoAnalysis, 'desc': 'Workout Video'},
        {'key': 'form_video', 'cost': formCheckVideo, 'desc': 'Form Check (Video)'},
        {'key': 'technique_video', 'cost': exerciseTechniqueVideo, 'desc': 'Exercise Technique'},
        {'key': 'rep_counting', 'cost': repCountingVideo, 'desc': 'Rep Counting'},
        {'key': 'pose_detection', 'cost': poseDetectionVideo, 'desc': 'Pose Detection'},
      ],
      'Audio & Voice': [
        {'key': 'voice_to_text', 'cost': voiceToText, 'desc': 'Voice to Text'},
        {'key': 'audio_coaching', 'cost': audioCoaching, 'desc': 'Audio Coaching'},
        {'key': 'voice_conversation', 'cost': voiceConversation, 'desc': 'Voice Chat'},
        {'key': 'audio_feedback', 'cost': audioFeedback, 'desc': 'Audio Feedback'},
      ],
      'Live Coaching': [
        {'key': 'live_coaching', 'cost': liveWorkoutCoaching, 'desc': 'Live Workout Coaching'},
        {'key': 'live_form', 'cost': liveFormCorrection, 'desc': 'Live Form Correction'},
        {'key': 'live_motivation', 'cost': realTimeMotivation, 'desc': 'Real-time Motivation'},
        {'key': 'live_reps', 'cost': liveRepCounting, 'desc': 'Live Rep Counting'},
      ],
      'Advanced Features': [
        {'key': 'comprehensive', 'cost': comprehensiveAnalysis, 'desc': 'Comprehensive Analysis'},
        {'key': 'long_term', 'cost': longTermPlanning, 'desc': 'Long-term Planning'},
        {'key': 'nutrition_strategy', 'cost': nutritionStrategy, 'desc': 'Nutrition Strategy'},
        {'key': 'injury_prevention', 'cost': injuryPrevention, 'desc': 'Injury Prevention'},
        {'key': 'performance', 'cost': performanceOptimization, 'desc': 'Performance Optimization'},
      ],
      'Content Generation': [
        {'key': 'workout_plan', 'cost': workoutPlanGeneration, 'desc': 'Workout Plan'},
        {'key': 'weekly_meals', 'cost': mealPlanWeekly, 'desc': 'Weekly Meal Plan'},
        {'key': 'recipe', 'cost': customRecipeGeneration, 'desc': 'Custom Recipe'},
        {'key': 'motivation', 'cost': motivationalContent, 'desc': 'Motivational Content'},
        {'key': 'report', 'cost': progressReport, 'desc': 'Progress Report'},
      ],
    };
  }
  
  /// Calculate total credits for multiple features
  static int calculateTotal(List<String> features) {
    return features.fold(0, (sum, feature) => sum + getCost(feature));
  }
  
  /// Get estimated usage examples
  static Map<String, String> getUsageExamples(int credits) {
    return {
      'Chat Messages': '${credits ~/ chatMessage} messages',
      'Meal Photos': '${credits ~/ mealPhotoAnalysis} meal analyses',
      'Workout Videos': '${credits ~/ workoutVideoAnalysis} video analyses',
      'Live Coaching': '${credits ~/ liveWorkoutCoaching} workout sessions',
      'Meal Plans': '${credits ~/ mealPlanGeneration} meal plans',
      'Form Checks': '${credits ~/ formCheckVideo} form checks',
    };
  }
}
