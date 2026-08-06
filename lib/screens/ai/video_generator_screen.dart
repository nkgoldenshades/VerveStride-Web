import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../services/firebase_ai_service.dart';
import '../../services/credits_service.dart';
import '../../models/ai_feature_costs.dart';

/// AI Video Generator Screen — Generate videos using Veo
class VideoGeneratorScreen extends StatefulWidget {
  const VideoGeneratorScreen({super.key});

  @override
  State<VideoGeneratorScreen> createState() => _VideoGeneratorScreenState();
}

class _VideoGeneratorScreenState extends State<VideoGeneratorScreen> {
  final _promptController = TextEditingController();
  VideoPlayerController? _videoController;
  bool _isGenerating = false;
  String? _errorMessage;
  int _selectedDuration = 5;

  final List<String> _quickPrompts = [
    'Demonstration of proper squat technique',
    'Push-up form tutorial',
    'Yoga flow sequence',
    'Running technique demonstration',
    'Plank exercise with variations',
    'Deadlift proper form',
    'Burpee exercise demonstration',
    'Stretching routine',
  ];

  @override
  void dispose() {
    _promptController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _generateVideo() async {
    if (_promptController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a description';
      });
      return;
    }

    // Check credits
    final credits = CreditsService.instance.availableCredits;
    if (credits < AIFeatureCosts.videoGeneration) {
      setState(() {
        _errorMessage =
            'Not enough credits. Need ${AIFeatureCosts.videoGeneration} credits.';
      });
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    // Dispose previous video controller
    await _videoController?.dispose();
    _videoController = null;

    try {
      final videoUrl = await FirebaseAIService.instance.generateVideo(
        _promptController.text.trim(),
        durationSeconds: _selectedDuration,
      );

      if (videoUrl != null) {
        // Initialize video player
        final controller =
            VideoPlayerController.networkUrl(Uri.parse(videoUrl));
        await controller.initialize();

        setState(() {
          _videoController = controller;
          _isGenerating = false;
        });
      } else {
        setState(() {
          _isGenerating = false;
          _errorMessage = 'Failed to generate video. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _isGenerating = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  void _useQuickPrompt(String prompt) {
    _promptController.text = prompt;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final credits = CreditsService.instance.availableCredits;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Video Generator'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.stars, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    '$credits',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info card
            Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.video_library,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'AI Video Generation',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Generate custom workout videos using AI. Perfect for exercise demonstrations and tutorials.',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cost: ${AIFeatureCosts.videoGeneration} credits per video',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Prompt input
            TextField(
              controller: _promptController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Describe the video you want',
                hintText: 'E.g., "Demonstration of proper squat technique"',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _promptController.clear(),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Duration selector
            Row(
              children: [
                Text(
                  'Duration:',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 5, label: Text('5s')),
                      ButtonSegment(value: 10, label: Text('10s')),
                      ButtonSegment(value: 15, label: Text('15s')),
                    ],
                    selected: {_selectedDuration},
                    onSelectionChanged: (Set<int> newSelection) {
                      setState(() {
                        _selectedDuration = newSelection.first;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Generate button
            ElevatedButton.icon(
              onPressed: _isGenerating ? null : _generateVideo,
              icon: _isGenerating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.video_library),
              label: Text(_isGenerating ? 'Generating...' : 'Generate Video'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),

            // Error message
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Quick prompts
            const SizedBox(height: 24),
            Text(
              'Quick Prompts',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickPrompts.map((prompt) {
                return ActionChip(
                  label: Text(prompt),
                  onPressed: () => _useQuickPrompt(prompt),
                  avatar: const Icon(Icons.lightbulb_outline, size: 18),
                );
              }).toList(),
            ),

            // Generated video
            if (_videoController != null &&
                _videoController!.value.isInitialized) ...[
              const SizedBox(height: 24),
              Text(
                'Generated Video',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filled(
                    onPressed: () {
                      setState(() {
                        if (_videoController!.value.isPlaying) {
                          _videoController!.pause();
                        } else {
                          _videoController!.play();
                        }
                      });
                    },
                    icon: Icon(
                      _videoController!.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton.outlined(
                    onPressed: () {
                      _videoController!.seekTo(Duration.zero);
                      _videoController!.pause();
                      setState(() {});
                    },
                    icon: const Icon(Icons.replay),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  // TODO: Implement download functionality
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Download feature coming soon!'),
                    ),
                  );
                },
                icon: const Icon(Icons.download),
                label: const Text('Download Video'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
