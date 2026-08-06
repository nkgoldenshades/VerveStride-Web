import 'package:flutter/material.dart';
import 'package:vervestride/core/app_theme.dart';
import 'package:vervestride/models/ai_language_config.dart';
import 'package:vervestride/services/local_storage_service.dart';
import 'package:vervestride/services/firebase_ai_service.dart';

class AILanguageSelectorScreen extends StatefulWidget {
  const AILanguageSelectorScreen({super.key});

  @override
  State<AILanguageSelectorScreen> createState() => _AILanguageSelectorScreenState();
}

class _AILanguageSelectorScreenState extends State<AILanguageSelectorScreen> {
  String _selectedLanguageId = AILanguageConfig.defaultLanguage.id;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSelectedLanguage();
  }

  Future<void> _loadSelectedLanguage() async {
    final settings = await LocalStorageService.instance.getAISettings();
    final selectedId = settings['selected_language'] as String? ?? AILanguageConfig.defaultLanguage.id;
    
    if (mounted) {
      setState(() {
        _selectedLanguageId = selectedId;
      });
    }
  }

  Future<void> _selectLanguage(AILanguageConfig language) async {
    setState(() {
      _selectedLanguageId = language.id;
      _isLoading = true;
    });

    // Save the selection
    final settings = await LocalStorageService.instance.getAISettings();
    settings['selected_language'] = language.id;
    await LocalStorageService.instance.saveAISettings(settings);

    // Reset AI models to use new language
    FirebaseAIService.instance.resetModels();

    if (mounted) {
      setState(() => _isLoading = false);
      
      // Show confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Language changed to ${language.displayName}'),
          backgroundColor: AppColors.secondary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _testLanguage(AILanguageConfig language) async {
    // Test the language with a sample phrase
    final testPhrases = {
      'en_us': 'Hello! This is how I sound in American English.',
      'en_gb': 'Hello! This is how I sound in British English, rather brilliant!',
      'en_au': 'G\'day mate! This is how I sound in Australian English.',
      'en_ca': 'Hello there, eh! This is how I sound in Canadian English, sorry!',
      'en_in': 'Hello ji! This is how I sound in Indian English.',
      'en_za': 'Howzit! This is how I sound in South African English, lekker!',
      'es': '¡Hola! Así es como sueno en español.',
      'fr': 'Bonjour! Voici comment je sonne en français.',
      'de': 'Hallo! So klinge ich auf Deutsch.',
      'it': 'Ciao! Ecco come suono in italiano.',
      'pt': 'Olá! É assim que eu soo em português.',
      'nl': 'Hallo! Zo klink ik in het Nederlands.',
      'ru': 'Привет! Вот как я звучу по-русски.',
      'ja': 'こんにちは！日本語ではこのように聞こえます。',
      'ko': '안녕하세요! 한국어로는 이렇게 들립니다.',
      'zh': '你好！我用中文是这样说话的。',
      'ar': 'مرحبا! هكذا أتحدث بالعربية.',
      'hi': 'नमस्ते! मैं हिंदी में इस तरह बोलता हूं।',
    };

    final testPhrase = testPhrases[language.id] ?? 'Hello! This is a test of the selected language.';
    
    try {
      // Temporarily set the language for testing
      final currentSettings = await LocalStorageService.instance.getAISettings();
      final originalLanguage = currentSettings['selected_language'];
      
      currentSettings['selected_language'] = language.id;
      await LocalStorageService.instance.saveAISettings(currentSettings);
      
      // Test the TTS
      await FirebaseAIService.instance.speakResponse(testPhrase);
      
      // Restore original language if different
      if (originalLanguage != language.id) {
        currentSettings['selected_language'] = originalLanguage;
        await LocalStorageService.instance.saveAISettings(currentSettings);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupedLanguages = AILanguageConfig.getGroupedLanguages();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('AI Language & Accent'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.language,
                              color: AppColors.primary,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Choose AI Language & Accent',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Select how VerveStride AI speaks and responds. This affects both text responses and voice output.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Language groups
                  ...groupedLanguages.entries.map((entry) {
                    final groupName = entry.key;
                    final languages = entry.value;
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 12),
                          child: Text(
                            groupName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        
                        ...languages.map((language) {
                          final isSelected = _selectedLanguageId == language.id;
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? AppColors.primary.withOpacity(0.15)
                                  : AppColors.card.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary.withOpacity(0.5)
                                    : Colors.white.withOpacity(0.1),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: Text(
                                language.flag,
                                style: const TextStyle(fontSize: 28),
                              ),
                              title: Text(
                                language.displayName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected 
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                language.description,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Test button
                                  IconButton(
                                    onPressed: () => _testLanguage(language),
                                    icon: const Icon(
                                      Icons.play_arrow,
                                      size: 20,
                                    ),
                                    color: AppColors.textSecondary,
                                    tooltip: 'Test voice',
                                  ),
                                  
                                  // Selection indicator
                                  if (isSelected)
                                    Icon(
                                      Icons.check_circle,
                                      color: AppColors.primary,
                                      size: 24,
                                    )
                                  else
                                    Icon(
                                      Icons.radio_button_unchecked,
                                      color: AppColors.textSecondary,
                                      size: 24,
                                    ),
                                ],
                              ),
                              onTap: () => _selectLanguage(language),
                            ),
                            ),
                          );
                        }),
                        
                        const SizedBox(height: 16),
                      ],
                    );
                  }),
                  
                  // Footer info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Language Features',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '• AI responses will use the selected language and cultural expressions\n'
                          '• Voice output will use appropriate accent and pronunciation\n'
                          '• Fitness terminology will be localized\n'
                          '• Tap the play button to test each language before selecting',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}