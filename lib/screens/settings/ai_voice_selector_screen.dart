import 'package:flutter/material.dart';
import 'package:vervestride/core/app_theme.dart';
import 'package:vervestride/services/ai_voice_service.dart';
import 'package:vervestride/services/user_subscription_service.dart';
import 'package:vervestride/services/credits_service.dart';

class AIVoiceSelectorScreen extends StatefulWidget {
  const AIVoiceSelectorScreen({super.key});

  @override
  State<AIVoiceSelectorScreen> createState() => _AIVoiceSelectorScreenState();
}

class _AIVoiceSelectorScreenState extends State<AIVoiceSelectorScreen> {
  String? _selectedVoiceId;
  List<AIVoiceModel> _availableVoices = [];
  bool _isLoading = false;
  bool _isTestingVoice = false;

  @override
  void initState() {
    super.initState();
    _loadVoices();
  }

  Future<void> _loadVoices() async {
    setState(() => _isLoading = true);
    
    try {
      final voices = await AIVoiceService.instance.getAvailableVoices();
      final currentVoice = AIVoiceService.instance.currentVoiceId;
      
      if (mounted) {
        setState(() {
          _availableVoices = voices;
          _selectedVoiceId = currentVoice ?? voices.first.id;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load voices: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectVoice(String voiceId) async {
    setState(() => _selectedVoiceId = voiceId);
    await AIVoiceService.instance.setSelectedVoice(voiceId);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Voice changed to ${AIVoiceService.instance.getVoice(voiceId)?.name ?? voiceId}'),
          backgroundColor: AppColors.secondary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _testVoice(String voiceId) async {
    if (_isTestingVoice) return;
    
    setState(() => _isTestingVoice = true);
    
    try {
      await AIVoiceService.instance.testVoice(voiceId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Voice test failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTestingVoice = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('AI Voice Selection'),
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
                  _buildHeaderCard(),
                  const SizedBox(height: 24),
                  _buildVoiceGroups(),
                  const SizedBox(height: 24),
                  _buildUpgradeCard(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.2),
            AppColors.secondary.withOpacity(0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
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
                Icons.record_voice_over,
                color: AppColors.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text(
                'Premium AI Voices',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Choose from our collection of natural, human-like AI voices powered by advanced neural networks. Each voice is carefully crafted for the perfect fitness coaching experience.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceGroups() {
    // Group voices by provider and accent
    final groupedVoices = <String, List<AIVoiceModel>>{};
    
    for (final voice in _availableVoices) {
      final key = '${voice.providerName} - ${voice.accent}';
      groupedVoices.putIfAbsent(key, () => []).add(voice);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: groupedVoices.entries.map((entry) {
        final groupName = entry.key;
        final voices = entry.value;
        
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
            
            ...voices.map((voice) => _buildVoiceCard(voice)),
            
            const SizedBox(height: 16),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildVoiceCard(AIVoiceModel voice) {
    final isSelected = _selectedVoiceId == voice.id;
    final canUse = _canUseVoice(voice);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected 
            ? AppColors.primary.withOpacity(0.15)
            : AppColors.card.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? AppColors.primary.withOpacity(0.5)
              : Colors.white.withOpacity(0.1),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _getVoiceColor(voice).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            voice.gender == 'female' ? Icons.face_3 : Icons.face,
            color: _getVoiceColor(voice),
            size: 24,
          ),
        ),
        title: Row(
          children: [
            Text(
              voice.name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getQualityColor(voice.qualityLevel).withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                voice.qualityLevel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _getQualityColor(voice.qualityLevel),
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              voice.description,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.psychology,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  voice.providerName,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                if (voice.isPremium) ...[
                  Icon(
                    Icons.star,
                    size: 14,
                    color: Colors.amber,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${voice.creditsPerMinute}/min',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Test button
            IconButton(
              onPressed: canUse && !_isTestingVoice 
                  ? () => _testVoice(voice.id)
                  : null,
              icon: _isTestingVoice
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow, size: 20),
              color: canUse ? AppColors.primary : AppColors.textSecondary,
              tooltip: canUse ? 'Test voice' : 'Upgrade required',
            ),
            
            // Selection indicator
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: AppColors.primary,
                size: 24,
              )
            else if (canUse)
              Icon(
                Icons.radio_button_unchecked,
                color: AppColors.textSecondary,
                size: 24,
              )
            else
              Icon(
                Icons.lock,
                color: AppColors.textSecondary,
                size: 24,
              ),
          ],
        ),
        onTap: canUse ? () => _selectVoice(voice.id) : null,
      ),
      ),
    );
  }

  Widget _buildUpgradeCard() {
    final subscription = UserSubscriptionService.instance;
    final credits = CreditsService.instance;
    
    if (subscription.isElite || subscription.isLifetime) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.secondary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.secondary.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.verified,
              color: AppColors.secondary,
              size: 24,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'You have unlimited access to all premium AI voices!',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
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
                'Voice Access',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subscription.isPro
                ? 'Pro users get Google Neural voices + limited ElevenLabs access'
                : 'Free users get Google Neural voices. Credits: ${credits.availableCredits.toStringAsFixed(1)}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '• Elite plan: Unlimited access to all premium voices\n'
            '• Pro plan: Google Neural + select ElevenLabs voices\n'
            '• Free plan: Google Neural voices with credits',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  bool _canUseVoice(AIVoiceModel voice) {
    final subscription = UserSubscriptionService.instance;
    final credits = CreditsService.instance;
    
    if (subscription.isElite || subscription.isLifetime) {
      return true;
    }
    
    if (subscription.isPro) {
      return voice.provider == 'google_cloud' || 
             voice.id == 'rachel_elevenlabs' || 
             voice.id == 'adam_elevenlabs';
    }
    
    // Free users
    if (voice.provider == 'google_cloud') {
      return credits.availableCredits >= voice.creditsPerMinute;
    }
    
    return false;
  }

  Color _getVoiceColor(AIVoiceModel voice) {
    switch (voice.provider) {
      case 'elevenlabs':
        return Colors.purple;
      case 'google_cloud':
        return Colors.blue;
      default:
        return AppColors.primary;
    }
  }

  Color _getQualityColor(String quality) {
    switch (quality) {
      case 'Ultra Premium':
        return Colors.purple;
      case 'Premium':
        return Colors.blue;
      default:
        return AppColors.textSecondary;
    }
  }
}