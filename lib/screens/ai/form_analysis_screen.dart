import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/firebase_ai_service.dart';
import '../../services/credits_service.dart';

/// AI Form Analysis Screen — Analyze workout form from photos
class FormAnalysisScreen extends StatefulWidget {
  const FormAnalysisScreen({super.key});

  @override
  State<FormAnalysisScreen> createState() => _FormAnalysisScreenState();
}

class _FormAnalysisScreenState extends State<FormAnalysisScreen> {
  Uint8List? _selectedImage;
  String? _analysis;
  bool _isAnalyzing = false;
  String? _errorMessage;
  String _selectedExercise = 'Squat';

  final List<String> _exercises = [
    'Squat',
    'Deadlift',
    'Bench Press',
    'Push-up',
    'Pull-up',
    'Plank',
    'Lunge',
    'Overhead Press',
    'Row',
    'Bicep Curl',
  ];

  final _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _selectedImage = bytes;
          _analysis = null;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to pick image: $e';
      });
    }
  }

  Future<void> _analyzeForm() async {
    if (_selectedImage == null) {
      setState(() {
        _errorMessage = 'Please select an image first';
      });
      return;
    }

    // Check credits
    final credits = CreditsService.instance.availableCredits;
    if (credits < CreditsService.creditsPerFormAnalysis) {
      setState(() {
        _errorMessage = 'Not enough credits. Need ${CreditsService.creditsPerFormAnalysis} credits.';
      });
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _analysis = null;
    });

    try {
      final analysis = await FirebaseAIService.instance.analyzeWorkoutForm(
        imageBytes: _selectedImage!,
        exerciseType: _selectedExercise,
      );

      setState(() {
        _analysis = analysis;
        _isAnalyzing = false;
        if (analysis == null) {
          _errorMessage = 'Failed to analyze form. Please try again.';
        }
      });
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final credits = CreditsService.instance.availableCredits;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Form Analysis'),
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
                          Icons.fitness_center,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'AI Form Analysis',
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
                      'Upload a photo of your workout and get AI-powered form analysis with specific corrections.',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cost: ${CreditsService.creditsPerFormAnalysis} credits per analysis',
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

            // Exercise selector
            DropdownButtonFormField<String>(
              initialValue: _selectedExercise,
              decoration: const InputDecoration(
                labelText: 'Exercise Type',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.fitness_center),
              ),
              items: _exercises.map((exercise) {
                return DropdownMenuItem(
                  value: exercise,
                  child: Text(exercise),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedExercise = value;
                  });
                }
              },
            ),
            const SizedBox(height: 24),

            // Image picker buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),

            // Selected image
            if (_selectedImage != null) ...[
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  _selectedImage!,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isAnalyzing ? null : _analyzeForm,
                icon: _isAnalyzing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.analytics),
                label: Text(_isAnalyzing ? 'Analyzing...' : 'Analyze Form'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ],

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

            // Analysis result
            if (_analysis != null) ...[
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Form Analysis',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _analysis!,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Tips
            if (_selectedImage == null) ...[
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.tips_and_updates,
                            color: theme.colorScheme.secondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Tips for Best Results',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('• Take photo from the side or front'),
                      const SizedBox(height: 4),
                      const Text('• Ensure good lighting'),
                      const SizedBox(height: 4),
                      const Text('• Capture full body in frame'),
                      const SizedBox(height: 4),
                      const Text('• Take photo at mid-point of exercise'),
                      const SizedBox(height: 4),
                      const Text('• Wear form-fitting clothes'),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
