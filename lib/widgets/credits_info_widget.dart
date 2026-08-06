import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../services/credits_service.dart';

class CreditsInfoWidget extends StatelessWidget {
  const CreditsInfoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CreditsService.instance,
      builder: (context, _) {
        final credits = CreditsService.instance.availableCredits;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF6C63FF).withOpacity(0.15),
                const Color(0xFF5A52D5).withOpacity(0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF6C63FF).withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.stars_rounded,
                    color: Color(0xFF6C63FF),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'AI Credits',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$credits',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6C63FF),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              const Text(
                'Credit Usage:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              _buildUsageRow(
                'Meal Analysis',
                CreditsService.creditsPerMealAnalysis,
              ),
              _buildUsageRow(
                'Workout Coaching',
                CreditsService.creditsPerWorkoutCoaching,
              ),
              _buildUsageRow(
                'Form Analysis',
                CreditsService.creditsPerFormAnalysis,
              ),
              _buildUsageRow(
                'Chat Message',
                CreditsService.creditsPerChatMessage,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUsageRow(String feature, int credits) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(
            Icons.circle,
            size: 6,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              feature,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            '$credits credit${credits > 1 ? 's' : ''}',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6C63FF),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
