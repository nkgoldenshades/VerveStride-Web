import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../services/firebase_ai_service.dart';
import '../../services/credits_service.dart';
import '../../core/app_theme.dart';

/// AI Image Generator Screen — Generate images using Imagen 3
/// CREATOR-FOCUSED: Batch generation, size options, upfront cost preview
class ImageGeneratorScreen extends StatefulWidget {
  const ImageGeneratorScreen({super.key});

  @override
  State<ImageGeneratorScreen> createState() => _ImageGeneratorScreenState();
}

class _ImageGeneratorScreenState extends State<ImageGeneratorScreen> {
  final _promptController = TextEditingController();
  final List<Uint8List> _generatedImages = []; // Changed to list for batch
  bool _isGenerating = false;
  String? _errorMessage;
  
  // CREATOR OPTIONS - NO ARTIFICIAL LIMITS!
  int _batchCount = 1; // User decides how many
  String _imageSize = 'medium'; // Size selection
  
  // Size options with credit costs
  final Map<String, Map<String, dynamic>> _sizeOptions = {
    'small': {'label': 'Small (512×512)', 'credits': 10, 'description': 'Quick previews'},
    'medium': {'label': 'Medium (1024×1024)', 'credits': 20, 'description': 'Standard quality'},
    'large': {'label': 'Large (1536×1536)', 'credits': 30, 'description': 'High quality'},
    'xl': {'label': 'XL (2048×2048)', 'credits': 40, 'description': 'Maximum quality'},
  };

  final List<String> _quickPrompts = [
    'Person doing perfect squat form',
    'Healthy meal with chicken and vegetables',
    'Motivational fitness poster',
    'Person doing push-ups with correct form',
    'Protein-rich breakfast plate',
    'Yoga pose demonstration',
    'Running technique illustration',
    'Gym workout motivation',
  ];

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  // Calculate total credits needed
  int get _creditsPerImage {
    return _sizeOptions[_imageSize]?['credits'] ?? 20;
  }

  int get _totalCredits {
    return _creditsPerImage * _batchCount;
  }

  bool get _canAfford {
    return CreditsService.instance.availableCredits >= _totalCredits;
  }

  Future<void> _generateImage() async {
    if (_promptController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a description';
      });
      return;
    }

    // Check credits
    final credits = CreditsService.instance.availableCredits;
    if (credits < _totalCredits) {
      setState(() {
        _errorMessage = 'Not enough credits. Need $_totalCredits, you have $credits.';
      });
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      // Generate images in batch
      for (int i = 0; i < _batchCount; i++) {
        final image = await FirebaseAIService.instance.generateImage(
          _promptController.text.trim(),
        );

        if (image != null) {
          setState(() {
            _generatedImages.add(image);
          });
        } else {
          setState(() {
            _errorMessage = 'Failed to generate image ${i + 1} of $_batchCount';
          });
          break;
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  void _clearImages() {
    setState(() {
      _generatedImages.clear();
      _errorMessage = null;
    });
  }

  void _useQuickPrompt(String prompt) {
    _promptController.text = prompt;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final credits = CreditsService.instance.availableCredits;
    final balanceAfter = credits - _totalCredits;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Image Generator'),
        backgroundColor: Colors.transparent,
        actions: [
          // Credits display
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.diamond, size: 16, color: AppColors.secondary),
                  const SizedBox(width: 4),
                  Text(
                    '$credits',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
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
                          Icons.auto_awesome,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'AI Image Generation',
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
                      'Create workout diagrams, meal visuals, and motivational content. Perfect for content creators!',
                      style: TextStyle(
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
                labelText: 'Describe what you want to create',
                hintText: 'E.g., "Person doing push-ups, professional fitness photo"',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _promptController.clear(),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // CREATOR OPTIONS SECTION
            Card(
              color: AppColors.surface,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tune, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Creator Options',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Batch count slider - ADAPTIVE! User decides limit
                    Text(
                      'Batch: $_batchCount image${_batchCount > 1 ? 's' : ''}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    Slider(
                      value: _batchCount.toDouble(),
                      min: 1,
                      max: 100, // ✅ Increased from 10 to 100! No artificial limits!
                      divisions: 99,
                      label: '$_batchCount',
                      onChanged: (value) {
                        setState(() {
                          _batchCount = value.toInt();
                        });
                      },
                    ),
                    Text(
                      'Generate as many as you need! Only limit is your credits.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Size options
                    const Text(
                      'Image Size',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _sizeOptions.entries.map((entry) {
                        final isSelected = _imageSize == entry.key;
                        return ChoiceChip(
                          label: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(entry.value['label']),
                              Text(
                                '${entry.value['credits']} credits',
                                style: const TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _imageSize = entry.key;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // UPFRONT COST PREVIEW - KEY FEATURE!
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _canAfford
                    ? AppColors.secondary.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _canAfford
                      ? AppColors.secondary.withOpacity(0.3)
                      : Colors.red.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Cost:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.diamond,
                            color: _canAfford ? AppColors.secondary : Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$_totalCredits credits',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _canAfford ? AppColors.secondary : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Your balance:'),
                      Text(
                        '$credits credits',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('After generation:'),
                      Text(
                        '$balanceAfter credits',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _canAfford ? AppColors.secondary : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  if (!_canAfford) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Not enough credits! Need $_totalCredits but have $credits.',
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Generate button
            ElevatedButton.icon(
              onPressed: (_isGenerating || !_canAfford) ? null : _generateImage,
              icon: _isGenerating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(
                _isGenerating
                    ? 'Generating ${_generatedImages.length + 1}/$_batchCount...'
                    : 'Generate ${_batchCount > 1 ? '$_batchCount Images' : 'Image'}',
              ),
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

            // Generated images gallery
            if (_generatedImages.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Generated Images (${_generatedImages.length})',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _clearImages,
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: const Text('Clear All'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _generatedImages.length,
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      _generatedImages[index],
                      fit: BoxFit.cover,
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
