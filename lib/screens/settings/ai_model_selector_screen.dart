import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../models/ai_model_config.dart';
import '../../services/local_storage_service.dart';

/// Full-screen model selector — accessible from Settings
class AIModelSelectorScreen extends StatefulWidget {
  const AIModelSelectorScreen({super.key});

  @override
  State<AIModelSelectorScreen> createState() => _AIModelSelectorScreenState();
}

class _AIModelSelectorScreenState extends State<AIModelSelectorScreen> {
  String? _selectedId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await LocalStorageService.instance.getAISettings();
    setState(() {
      _selectedId = settings['selected_general_model'] as String? ??
          AIModelConfig.defaultGeneral.id;
      _isLoading = false;
    });
  }

  Future<void> _select(AIModelConfig model) async {
    setState(() => _selectedId = model.id);
    final settings = await LocalStorageService.instance.getAISettings();
    settings['selected_general_model'] = model.id;
    // Also update vision model if it supports vision
    if (model.supportsVision) {
      settings['selected_vision_model'] = model.id;
    }
    await LocalStorageService.instance.saveAISettings(settings);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Switched to ${model.displayName}'),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'VerveStride AI Models',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                // Intro
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primary, AppColors.secondary],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.smart_toy, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Choose your AI model',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'All models are powered by Google Gemini, branded as VerveStride AI.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Model cards
                ...AIModelConfig.selectableModels.map(
                  (model) => _ModelCard(
                    model: model,
                    isSelected: _selectedId == model.id,
                    onTap: () => _select(model),
                  ),
                ),

                const SizedBox(height: 16),

                // Live model info (not selectable for chat)
                _LiveModelInfo(),
              ],
            ),
    );
  }
}

// ── Model card ────────────────────────────────────────────────────────────────

class _ModelCard extends StatelessWidget {
  final AIModelConfig model;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModelCard({
    required this.model,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AIModelConfig.badgeColor(model.badge);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withOpacity(0.1)
              : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? accent.withOpacity(0.7)
                : Colors.white.withOpacity(0.08),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Radio circle
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? accent : AppColors.textSecondary,
                  width: 2,
                ),
                color: isSelected ? accent : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          model.displayName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? accent : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (model.badge.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: accent.withOpacity(0.4),
                            ),
                          ),
                          child: Text(
                            model.badge,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: accent,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    model.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Capability chips
                  Wrap(
                    spacing: 6,
                    children: [
                      if (model.supportsVision)
                        _Chip('📸 Vision'),
                      if (model.supportsAudio)
                        _Chip('🎤 Audio'),
                      _Chip('${(model.maxTokens / 1000).toStringAsFixed(0)}K ctx'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
      ),
    );
  }
}

class _LiveModelInfo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final live = AIModelConfig.defaultLive;
    final accent = AIModelConfig.badgeColor(live.badge);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.mic, color: accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  live.displayName,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Used automatically for real-time voice sessions. Not selectable for chat.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom sheet picker (used from chat header) ───────────────────────────────

/// Shows a compact model picker as a bottom sheet.
/// Call from anywhere: `ModelPickerSheet.show(context)`
class ModelPickerSheet extends StatefulWidget {
  const ModelPickerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => const ModelPickerSheet(),
    );
  }

  @override
  State<ModelPickerSheet> createState() => _ModelPickerSheetState();
}

class _ModelPickerSheetState extends State<ModelPickerSheet> {
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await LocalStorageService.instance.getAISettings();
    if (mounted) {
      setState(() {
        _selectedId = settings['selected_general_model'] as String? ??
            AIModelConfig.defaultGeneral.id;
      });
    }
  }

  Future<void> _select(AIModelConfig model) async {
    setState(() => _selectedId = model.id);
    final settings = await LocalStorageService.instance.getAISettings();
    settings['selected_general_model'] = model.id;
    if (model.supportsVision) settings['selected_vision_model'] = model.id;
    await LocalStorageService.instance.saveAISettings(settings);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.smart_toy, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Select AI Model',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Model list
            ...AIModelConfig.selectableModels.map((model) {
              final isSelected = _selectedId == model.id;
              final accent = AIModelConfig.badgeColor(model.badge);
              return GestureDetector(
                onTap: () => _select(model),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accent.withOpacity(0.12)
                        : Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? accent.withOpacity(0.6)
                          : Colors.white.withOpacity(0.07),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Radio
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? accent : AppColors.textSecondary,
                            width: 2,
                          ),
                          color: isSelected ? accent : Colors.transparent,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, size: 12, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      // Name + description
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              model.displayName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? accent : AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              model.description,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Badge
                      if (model.badge.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            model.badge,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: accent,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
