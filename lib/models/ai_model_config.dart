import 'package:flutter/material.dart';

/// AI Model Configuration — current Google Gemini models (April 2026)
/// branded as VerveStride AI.
///
/// Latest available:
///   Gemini 3 Pro    → most capable
///   Gemini 2.5 Pro  → advanced reasoning
///   Gemini 2.5 Flash → best price/performance
///   Gemini 2.5 Flash-Lite → fastest/cheapest
class AIModelConfig {
  final String id;
  final String displayName;
  final String description;
  final String googleModelId;
  final bool supportsVision;
  final bool supportsAudio;
  final bool isLive;
  final int maxTokens;
  final String category;
  final String badge;
  final int creditsPerMessage;

  const AIModelConfig({
    required this.id,
    required this.displayName,
    required this.description,
    required this.googleModelId,
    this.supportsVision = false,
    this.supportsAudio = false,
    this.isLive = false,
    this.maxTokens = 8192,
    this.category = 'general',
    this.badge = '',
    this.creditsPerMessage = 1,
  });

  // ── All models ─────────────────────────────────────────────────────────────

  static const List<AIModelConfig> allModels = [
    // ── Speed (1 credit) ─────────────────────────────────────────────────────

    AIModelConfig(
      id: 'vs_speed',
      displayName: 'VerveStride AI Speed',
      description: 'Fast & lightweight — quick answers, everyday tasks',
      googleModelId: 'gemini-2.5-flash-lite',
      supportsVision: true,
      maxTokens: 8192,
      category: 'speed',
      badge: 'Fast',
      creditsPerMessage: 1,
    ),

    // ── Smart (2 credits) ─────────────────────────────────────────────────

    AIModelConfig(
      id: 'vs_smart',
      displayName: 'VerveStride AI Smart',
      description: 'Intelligent reasoning — coding, writing, analysis',
      googleModelId: 'gemini-2.5-flash',
      supportsVision: true,
      maxTokens: 32768,
      category: 'smart',
      badge: 'Popular',
      creditsPerMessage: 2,
    ),

    // ── Advanced (3 credits) ─────────────────────────────────────────────

    AIModelConfig(
      id: 'vs_advanced',
      displayName: 'VerveStride AI Advanced',
      description: 'Deep analysis — complex problems & premium features',
      googleModelId: 'gemini-2.5-pro',
      supportsVision: true,
      maxTokens: 65536,
      category: 'advanced',
      badge: 'Premium',
      creditsPerMessage: 3,
    ),

    // ── Vision ─────────────────────────────────────────────────────────────

    AIModelConfig(
      id: 'vs_vision',
      displayName: 'VerveStride AI Vision',
      description: 'Photo & image analysis — meal tracking, form check',
      googleModelId: 'gemini-2.5-flash',
      supportsVision: true,
      maxTokens: 8192,
      category: 'vision',
      badge: 'Vision',
      creditsPerMessage: 1,
    ),

    // ── Live ─────────────────────────────────────────────────────────────────

    AIModelConfig(
      id: 'vs_live',
      displayName: 'VerveStride AI Live',
      description: 'Real-time coaching — interactive workout guidance',
      googleModelId: 'gemini-2.5-flash',
      supportsAudio: false,
      isLive: false,
      maxTokens: 8192,
      category: 'live',
      badge: 'Live',
      creditsPerMessage: 2,
    ),
  ];

  // ── Helpers ────────────────────────────────────────────────────────────────

  static AIModelConfig? getById(String id) {
    try {
      return allModels.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  static List<AIModelConfig> getByCategory(String category) =>
      allModels.where((m) => m.category == category).toList();

  static List<AIModelConfig> get selectableModels =>
      allModels.where((m) => !m.isLive).toList();

  static AIModelConfig get defaultGeneral =>
      allModels.firstWhere((m) => m.id == 'vs_flash');

  static AIModelConfig get defaultLive =>
      allModels.firstWhere((m) => m.isLive, orElse: () => allModels.first);

  static AIModelConfig get defaultVision => allModels.firstWhere(
        (m) => m.supportsVision && m.category == 'vision',
        orElse: () => allModels.first,
      );

  static Color badgeColor(String badge) {
    switch (badge) {
      case 'Cheapest':
        return const Color(0xFF66BB6A);
      case 'Fast':
        return const Color(0xFF6C63FF);
      case 'Smart':
        return const Color(0xFF42A5F5);
      case 'Powerful':
        return const Color(0xFFFF6584);
      case 'Vision':
        return const Color(0xFF66BB6A);
      case 'Live':
        return const Color(0xFFFFB74D);
      default:
        return const Color(0xFF6C63FF);
    }
  }

  static Color creditColor(int credits) {
    if (credits == 1) return const Color(0xFF66BB6A);
    if (credits <= 2) return const Color(0xFF42A5F5);
    if (credits <= 3) return const Color(0xFFFFB74D);
    return const Color(0xFFFF6584);
  }

  @override
  String toString() => 'AIModelConfig($displayName)';
}
