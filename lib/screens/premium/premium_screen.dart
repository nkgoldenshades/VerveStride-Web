import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/app_theme.dart';
import '../../services/payment_service.dart';
import '../../services/credits_service.dart';
import '../../services/firebase_subscription_service.dart';
import '../../services/referral_service.dart';
import '../../models/ai_credits.dart';
import '../../widgets/gradient_scaffold.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  late final PaymentService _paymentService;
  bool _isProcessing = false;
  String? _myReferralCode;
  final TextEditingController _referralController = TextEditingController();
  bool _applyingCode = false;

  @override
  void initState() {
    super.initState();
    _paymentService = PaymentService();
    _setupPaymentCallbacks();
    CreditsService.instance.load(force: true);
    _loadReferralCode();
  }

  Future<void> _loadReferralCode() async {
    final code = await ReferralService.instance.loadReferralCode();
    if (mounted) setState(() => _myReferralCode = code);
  }

  Future<void> _applyReferralCode() async {
    final code = _referralController.text.trim();
    if (code.isEmpty) return;
    setState(() => _applyingCode = true);
    final result = await ReferralService.instance.applyReferralCode(code);
    if (!mounted) return;
    setState(() => _applyingCode = false);
    if (result.success) {
      _referralController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 +${result.bonusCredits} credits added! Your friend got them too.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ ${result.message}'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _referralController.dispose();
    _paymentService.dispose();
    super.dispose();
  }

  void _setupPaymentCallbacks() {
    _paymentService.onCreditsSuccess = (paymentId, packageKey, credits) async {
      await FirebaseSubscriptionService.instance.addCredits(
        paymentId: paymentId,
        packageKey: packageKey,
        credits: credits,
      );
      await CreditsService.instance.load(force: true);
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Added $credits AI credits!'),
          backgroundColor: Colors.green,
        ),
      );
    };

    _paymentService.onPaymentFailure = (message) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Payment failed: $message'),
          backgroundColor: Colors.red,
        ),
      );
    };
  }

  Future<void> _handleCreditsPurchase(String packageKey) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    final user = FirebaseAuth.instance.currentUser;
    await _paymentService.openCreditsCheckout(
      packageKey: packageKey,
      email: user?.email,
      name: user?.displayName,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        title: const Text('AI Credits'),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Credits balance
            _buildCreditsBalance(),
            const SizedBox(height: 24),

            const Text(
              'Buy AI Credits',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Pay only for what you use. Credits never expire.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Credit packages
            ...CreditsService.packages.map((pkg) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildCreditPackageCard(pkg),
            )),

            const SizedBox(height: 24),

            // What credits get you
            _buildCreditUsageInfo(),

            const SizedBox(height: 24),

            // Referral section
            _buildReferralSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditsBalance() {
    return ListenableBuilder(
      listenable: CreditsService.instance,
      builder: (context, _) {
        final credits = CreditsService.instance.availableCredits;
        return Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFF5A52D5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C63FF).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.stars_rounded, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your AI Credits',
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$credits Credits',
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Icon(
                credits > 0 ? Icons.check_circle : Icons.add_circle_outline,
                color: Colors.white,
                size: 28,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCreditPackageCard(CreditPackage pkg) {
    final hasBonus = pkg.bonusCredits != null && pkg.bonusCredits! > 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasBonus
              ? const Color(0xFF66BB6A).withOpacity(0.5)
              : Colors.white.withOpacity(0.1),
          width: hasBonus ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        pkg.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (pkg.badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF66BB6A),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          pkg.badge!,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${pkg.totalCredits} Credits',
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                ),
                if (hasBonus)
                  Text(
                    '${pkg.credits} + ${pkg.bonusCredits} bonus',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF66BB6A)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  pkg.displayUsd(),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.accent),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : () => _handleCreditsPurchase(pkg.key),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isProcessing
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                        : const Text('Buy', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditUsageInfo() {
    final features = [
      ('💬 Chat message', '1 credit'),
      ('📸 Meal photo analysis', '2 credits'),
      ('🏋️ Workout plan', '10 credits'),
      ('🥗 Meal plan', '8 credits'),
      ('🎨 Image generation', '20 credits'),
      ('🎯 Live coaching session', '5 credits'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What credits get you',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          ...features.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(child: Text(f.$1, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
                Text(f.$2, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6C63FF))),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildReferralSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🎁', style: TextStyle(fontSize: 20)),
              SizedBox(width: 8),
              Text('Refer a friend', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Both you and your friend get +10 credits when they sign up.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),

          // Your referral code
          if (_myReferralCode != null) ...[
            const Text('Your referral code:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: _myReferralCode!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Referral code copied!'), duration: Duration(seconds: 2)),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_myReferralCode!, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF6C63FF), letterSpacing: 3)),
                    const Icon(Icons.copy, color: Color(0xFF6C63FF), size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            // Loading state while code is being generated
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 10),
                  Text('Generating your code...', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Enter a referral code
          const Text('Have a referral code?', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _referralController,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(color: AppColors.textPrimary, letterSpacing: 2),
                  decoration: InputDecoration(
                    hintText: 'Enter code',
                    hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.5)),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _applyingCode ? null : _applyReferralCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _applyingCode
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Apply'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
