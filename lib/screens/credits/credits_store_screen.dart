import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/app_theme.dart';
import '../../services/credits_service.dart';
import '../../services/currency_service.dart';
import '../../services/payment_service.dart';
import '../../services/firebase_subscription_service.dart';
import '../../widgets/gradient_scaffold.dart';

class CreditsStoreScreen extends StatefulWidget {
  const CreditsStoreScreen({super.key});

  @override
  State<CreditsStoreScreen> createState() => _CreditsStoreScreenState();
}

class _CreditsStoreScreenState extends State<CreditsStoreScreen> {
  final CreditsService _creditsService = CreditsService.instance;
  final CurrencyService _currencyService = CurrencyService.instance;
  late final PaymentService _paymentService;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _paymentService = PaymentService();
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
        SnackBar(content: Text('✅ Added $credits credits!'), backgroundColor: Colors.green),
      );
    };
    _paymentService.onPaymentFailure = (message) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ $message'), backgroundColor: Colors.red),
      );
    };
  }

  @override
  void dispose() {
    _paymentService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Buy Credits'),
        actions: [
          // Current balance
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.stars, size: 16, color: AppColors.primary),
                const SizedBox(width: 4),
                AnimatedBuilder(
                  animation: _creditsService,
                  builder: (context, _) => Text(
                    '${_creditsService.availableCredits}',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card.withOpacity(0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'How Credits Work',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildCreditInfo('AI Chat Message', '1 credit'),
                  _buildCreditInfo('Meal Photo Analysis', '2 credits'),
                  _buildCreditInfo('Workout Form Analysis', '3 credits'),
                  _buildCreditInfo('Live Coaching Session', '5 credits'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.language, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Prices shown in ${_currencyService.currencyInfo.name}',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Credit packages
            const Text(
              'Credit Packages',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            ...(_creditsService.localizedPackages.map((package) => 
                _buildPackageCard(package))),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditInfo(String feature, String cost) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const SizedBox(width: 8),
          const Text('•', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              feature,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          Text(
            cost,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard(CreditPackageLocalized package) {
    final isPopular = package.badge == 'Most Popular';
    final hasBonus = package.bonusCredits > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPopular 
              ? AppColors.primary.withOpacity(0.5)
              : Colors.white.withOpacity(0.08),
          width: isPopular ? 2 : 1,
        ),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            package.name,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.stars, size: 16, color: AppColors.secondary),
                              const SizedBox(width: 4),
                              Text(
                                '${package.credits} credits',
                                style: TextStyle(
                                  color: AppColors.secondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (hasBonus) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '+${package.bonusCredits} bonus',
                                    style: const TextStyle(
                                      color: Colors.greenAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          package.localPrice,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (package.totalCredits != package.credits)
                          Text(
                            '${package.totalCredits} total',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => _purchasePackage(package),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isPopular ? AppColors.primary : AppColors.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Purchase',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Badge
          if (package.badge != null)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPopular ? AppColors.primary : AppColors.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  package.badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _purchasePackage(CreditPackageLocalized package) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      await _paymentService.openCreditsCheckout(
        packageKey: package.key,
        email: user?.email,
        name: user?.displayName,
      );
      
      // Reset loading state after a timeout if no callback received
      // This handles cases where Razorpay modal fails to open or user closes it
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _isProcessing) {
          setState(() => _isProcessing = false);
        }
      });
    } catch (e) {
      debugPrint('❌ Purchase error: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
