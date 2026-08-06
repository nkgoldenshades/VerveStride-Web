import 'package:flutter/material.dart';
import '../core/app_theme.dart';

class TermsAndConditionsPage extends StatelessWidget {
  const TermsAndConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              'TERMS AND CONDITIONS',
              'Last Updated: August 6, 2026\n\n'
                  'These Terms and Conditions ("Terms") govern your access to and use of the VerveStride application '
                  'and services ("Service"). By downloading, installing, or using VerveStride, you agree to be bound by these Terms. '
                  'If you do not agree to any part of these Terms, you may not use the Service.',
            ),
            _buildSection(
              '1. SERVICE DESCRIPTION',
              'VerveStride is an AI-powered wellness platform providing:\n\n'
                  '• AI-powered chat and conversational assistance\n'
                  '• Image analysis and generation capabilities\n'
                  '• Video analysis and generation services\n'
                  '• Fitness and wellness tracking tools\n'
                  '• Meal planning and nutrition analysis\n'
                  '• Audio generation and analysis features\n'
                  '• Document processing and analysis\n'
                  '• Real-time coaching and personalized recommendations\n\n'
                  'VerveStride operates as an eCommerce platform where users purchase digital credits to access AI features.',
            ),
            _buildSection(
              '2. CREDIT SYSTEM',
              '2.1 Credit Purchase\n'
                  '• Credits are digital goods purchased via Razorpay secure checkout\n'
                  '• 1 credit = ₹4.15 (INR) or equivalent in your currency\n'
                  '• Packages: 50, 100, 250, 500+ credits available\n'
                  '• Prices subject to change with 30 days notice\n\n'
                  '2.2 Credit Usage\n'
                  '• Every feature consumes credits based on actual usage\n'
                  '• Chat: Credits calculated on input/output tokens\n'
                  '• Image Generation: Fixed credits per image (all resolutions)\n'
                  '• Video Generation: Fixed credits per video (≤5 seconds)\n'
                  '• Audio Generation: Fixed credits per audio file (≤30 seconds)\n'
                  '• Image/Video Analysis: Variable credits based on content\n'
                  '• Form analysis, meal tracking, recipe generation: FREE\n\n'
                  '2.3 Daily Login Bonus\n'
                  '• 1 free credit granted daily upon app opening\n'
                  '• Bonuses are non-cumulative (max 1 per calendar day)\n'
                  '• Valid for 1 year from grant date, then expire\n\n'
                  '2.4 Credit Expiration & Refunds\n'
                  '• Credits purchased do not expire\n'
                  '• Daily bonus credits expire 1 year from grant date\n'
                  '• Credits are non-refundable digital goods\n'
                  '• No refunds for unused, expired, or lost credits\n'
                  '• No refunds for service dissatisfaction\n'
                  '• Errors in credit calculation may result in reversal',
            ),
            _buildSection(
              '3. ACCEPTABLE USE POLICY',
              '3.1 Prohibited Activities\nYou agree NOT to:\n\n'
                  '• Use the Service for illegal purposes or violate any law\n'
                  '• Harass, abuse, or threaten other users or staff\n'
                  '• Attempt to gain unauthorized access to Service systems\n'
                  '• Create multiple accounts to circumvent restrictions\n'
                  '• Sell, resell, or redistribute credits\n'
                  '• Use automated bots, scrapers, or scripts (except official APIs)\n'
                  '• Reverse engineer, decompile, or attempt to extract source code\n'
                  '• Interfere with Service stability or security\n'
                  '• Generate hateful, violent, or discriminatory content\n'
                  '• Use AI outputs for defamation, fraud, or deception\n'
                  '• Bypass content filters or safety mechanisms\n\n'
                  '3.2 Content Responsibility\n'
                  '• You are solely responsible for all content you input\n'
                  '• You retain all rights to your input content\n'
                  '• AI-generated outputs may be used by VerveStride for model improvement\n'
                  '• Do not input confidential, proprietary, or personally identifiable information\n'
                  '• Do not input protected health information (PHI) or personal data without consent',
            ),
            _buildSection(
              '4. AI OUTPUT DISCLAIMER',
              '4.1 No Guarantees\n'
                  '• AI outputs are generated algorithmically and may contain errors, inaccuracies, or hallucinations\n'
                  '• AI is not a substitute for professional medical, legal, financial, or mental health advice\n'
                  '• Always verify important information with qualified professionals\n'
                  '• VerveStride is not liable for AI output accuracy or consequences\n\n'
                  '4.2 Fitness & Health\n'
                  '• Fitness recommendations are general guidance only\n'
                  '• Consult physicians before starting exercise programs\n'
                  '• Nutritional advice does not replace registered dietitian consultation\n'
                  '• Mental health support is not a substitute for professional therapy\n\n'
                  '4.3 Financial & Legal\n'
                  '• Financial projections and analysis are not investment advice\n'
                  '• Legal information is educational and not legal counsel\n'
                  '• Consult qualified professionals before making decisions',
            ),
            _buildSection(
              '5. DATA & PRIVACY',
              '5.1 Data Storage\n'
                  '• User data is stored locally on your device by default\n'
                  '• Optional cloud sync requires explicit opt-in\n'
                  '• No data is transmitted to VerveStride servers without your consent\n'
                  '• Firebase stores authentication data and usage analytics\n\n'
                  '5.2 Privacy Standards\n'
                  '• VerveStride is GDPR compliant\n'
                  '• We implement industry-standard security measures\n'
                  '• Encryption is used for data in transit and at rest\n'
                  '• We do not sell user data to third parties\n\n'
                  '5.3 Data Retention\n'
                  '• Chat history: Retained until user deletion\n'
                  '• Account deletion removes all associated data (within 30 days)\n'
                  '• Analytics data may be retained for 90 days\n'
                  '• We comply with user data deletion requests within 30 days',
            ),
            _buildSection(
              '6. PAYMENT & RAZORPAY',
              '6.1 Payment Processing\n'
                  '• Payments processed securely via Razorpay\n'
                  '• Razorpay is a certified Level 1 PCI DSS compliant payment processor\n'
                  '• Credit card details never stored on VerveStride servers\n\n'
                  '6.2 Transaction Disputes\n'
                  '• Disputed transactions must be reported within 90 days\n'
                  '• Contact support@vervestrideai.com for payment issues\n'
                  '• Chargebacks may result in account suspension\n\n'
                  '6.3 Billing\n'
                  '• Credits are billed immediately upon purchase\n'
                  '• Receipts available in your account dashboard\n'
                  '• Subscription plans (if available) auto-renew unless cancelled\n'
                  '• Cancellation takes effect at next billing cycle',
            ),
            _buildSection(
              '7. INTELLECTUAL PROPERTY',
              '7.1 VerveStride IP\n'
                  '• The Service, including all code, design, and functionality, is owned by VerveStride\n'
                  '• Licensed to you under non-exclusive, non-transferable license\n'
                  '• You may not distribute, modify, or create derivative works\n\n'
                  '7.2 User Content\n'
                  '• You retain ownership of content you create\n'
                  '• By using the Service, you grant VerveStride license to use your inputs for:\n'
                  '  - Model training and improvement\n'
                  '  - Analytics and research\n'
                  '  - Service optimization\n'
                  '• We will not use your content for commercial purposes without consent',
            ),
            _buildSection(
              '8. LIABILITY & DISCLAIMERS',
              '8.1 "AS-IS" Service\n'
                  '• VerveStride is provided "AS-IS" without warranties\n'
                  '• We do not warrant uninterrupted, error-free service\n'
                  '• No warranty of merchantability, fitness for purpose, or non-infringement\n\n'
                  '8.2 Limitation of Liability\n'
                  '• VerveStride is not liable for:\n'
                  '  - Data loss, corruption, or unauthorized access\n'
                  '  - AI output inaccuracies or consequences\n'
                  '  - Service interruptions or downtime\n'
                  '  - Third-party actions or content\n'
                  '  - Indirect, incidental, or consequential damages\n\n'
                  '8.3 Maximum Liability\n'
                  '• Our total liability shall not exceed credits purchased in the last 90 days\n'
                  '• This limitation applies even if advised of possibility of damages',
            ),
            _buildSection(
              '9. ACCOUNT TERMINATION',
              '9.1 Suspension\n'
                  '• We may suspend access for:\n'
                  '  - Violation of these Terms\n'
                  '  - Illegal activity\n'
                  '  - Payment fraud or chargebacks\n'
                  '  - Abuse or harassment\n'
                  '  - Security threats\n\n'
                  '9.2 Termination\n'
                  '• Account termination results in loss of all credits and data\n'
                  '• No refunds upon termination\n'
                  '• You may request account deletion anytime\n'
                  '• Data deletion is permanent and irreversible',
            ),
            _buildSection(
              '10. CHANGES & UPDATES',
              '• VerveStride reserves right to modify Service, features, or pricing\n'
                  '• Price changes take effect 30 days after notice\n'
                  '• Material Terms changes will be notified via email\n'
                  '• Continued use after changes constitutes acceptance\n'
                  '• We may discontinue Service with 30 days notice',
            ),
            _buildSection(
              '11. CONTACT & SUPPORT',
              'For questions about these Terms:\n\n'
                  '📧 Email: support@vervestrideai.com\n'
                  '🌐 Website: https://vervestrideai.com\n'
                  '📱 In-app: Settings → Help & Support\n\n'
                  'For urgent issues: support@vervestrideai.com',
            ),
            _buildSection(
              '12. GOVERNING LAW',
              '• These Terms are governed by laws of India (Bangalore, Karnataka)\n'
                  '• Disputes resolved through arbitration per Indian Arbitration Act, 1996\n'
                  '• Exclusive jurisdiction in Bangalore courts\n'
                  '• Any legal action must commence within 1 year of dispute',
            ),
            const SizedBox(height: 32),
            Center(
              child: Column(
                children: [
                  Text(
                    'Last Updated: August 6, 2026',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Version 2.0',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('I Understand & Accept'),
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

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              fontSize: 13,
              height: 1.6,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}
