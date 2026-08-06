import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../config/payment_config.dart';
import 'subscription_service.dart';
import 'credits_service.dart';
import 'web_payment_service.dart' if (dart.library.io) 'web_payment_service_stub.dart';

/// Handles all payments via Razorpay (INR).
/// Uses native Razorpay plugin on mobile and Checkout.js on web.
class PaymentService {
  void Function(String paymentId, String planKey)? onPaymentSuccess;
  void Function(String paymentId, String packageKey, int credits)? onCreditsSuccess;
  void Function(String message)? onPaymentFailure;

  late final Razorpay? _razorpay;
  late final WebPaymentService? _webPaymentService;
  String? _currentPlanKey;
  String? _currentPackageKey;
  bool _isCreditsCheckout = false;

  PaymentService() {
    // Validate payment configuration
    if (!PaymentConfig.isConfigured) {
      debugPrint('⚠️ WARNING: Payment keys not configured!');
      debugPrint('⚠️ Build with: flutter build --dart-define=RAZORPAY_KEY_ID=xxx --dart-define=RAZORPAY_KEY_SECRET=xxx');
    } else if (PaymentConfig.isTestMode) {
      debugPrint('⚠️ DEVELOPMENT MODE: Using Razorpay TEST keys');
    } else if (PaymentConfig.isLiveMode) {
      debugPrint('✅ PRODUCTION MODE: Using Razorpay LIVE keys');
    }
    
    if (kIsWeb) {
      _razorpay = null;
      // Web uses Razorpay Checkout.js (loaded in index.html)
      _webPaymentService = WebPaymentService();
      _webPaymentService!.onPaymentSuccess = (paymentId, planKey) {
        onPaymentSuccess?.call(paymentId, planKey);
      };
      _webPaymentService.onCreditsSuccess = (paymentId, packageKey, credits) {
        onCreditsSuccess?.call(paymentId, packageKey, credits);
      };
      _webPaymentService.onPaymentFailure = (message) {
        onPaymentFailure?.call(message);
      };
    } else {
      _webPaymentService = null;
      final razorpay = Razorpay();
      razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
      razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onError);
      razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
      _razorpay = razorpay;
    }
  }

  Future<void> openCheckout({
    required String planKey,
    String? email,
    String? name,
    String? contact,
  }) async {
    // Validate configuration before opening checkout
    if (!PaymentConfig.isConfigured) {
      onPaymentFailure?.call('Payment system not configured. Please contact support.');
      debugPrint('❌ Payment failed: Keys not configured');
      return;
    }
    
    final plan = SubscriptionService.getPlanByKey(planKey);
    if (plan == null) {
      onPaymentFailure?.call('Invalid subscription plan');
      return;
    }
    _currentPlanKey = planKey;
    _isCreditsCheckout = false;

    // Web: Use Razorpay Checkout.js
    if (kIsWeb) {
      await _webPaymentService!.openCheckout(
        planKey: planKey,
        email: email,
        name: name,
        contact: contact,
      );
      return;
    }

    // Mobile: Use Razorpay Flutter plugin
    try {
      _razorpay!.open({
        'key': PaymentConfig.razorpayKeyId,
        'amount': PaymentConfig.toSmallestUnit(plan.priceInr),
        'currency': PaymentConfig.inrCurrency,
        'name': PaymentConfig.companyName,
        'description': '${plan.tier} · ${plan.period}',
        'image': PaymentConfig.companyLogo,
        'prefill': {
          if (email != null) 'email': email,
          if (contact != null) 'contact': contact,
          if (name != null) 'name': name,
        },
        'theme': {'color': PaymentConfig.companyColor},
        'notes': {'plan_key': planKey, 'tier': plan.tier, 'period': plan.period},
      });
      debugPrint('✅ Razorpay opened: ${plan.displayInr()} [${PaymentConfig.isTestMode ? "TEST" : "LIVE"}]');
    } catch (e) {
      _currentPlanKey = null;
      onPaymentFailure?.call('Failed to open payment: $e');
    }
  }

  Future<void> openCreditsCheckout({
    required String packageKey,
    String? email,
    String? name,
    String? contact,
  }) async {
    // Validate configuration before opening checkout
    if (!PaymentConfig.isConfigured) {
      onPaymentFailure?.call('Payment system not configured. Please contact support.');
      debugPrint('❌ Payment failed: Keys not configured');
      return;
    }
    
    final package = CreditsService.getPackageByKey(packageKey);
    if (package == null) {
      onPaymentFailure?.call('Invalid credit package');
      return;
    }
    _currentPackageKey = packageKey;
    _isCreditsCheckout = true;

    // Web: Use Razorpay Checkout.js
    if (kIsWeb) {
      await _webPaymentService!.openCreditsCheckout(
        packageKey: packageKey,
        email: email,
        name: name,
        contact: contact,
      );
      return;
    }

    // Mobile: Use Razorpay Flutter plugin
    try {
      _razorpay!.open({
        'key': PaymentConfig.razorpayKeyId,
        'amount': PaymentConfig.toSmallestUnit(package.priceInr),
        'currency': PaymentConfig.inrCurrency,
        'name': PaymentConfig.companyName,
        'description': '${package.totalCredits} AI Credits',
        'image': PaymentConfig.companyLogo,
        'prefill': {
          if (email != null) 'email': email,
          if (contact != null) 'contact': contact,
          if (name != null) 'name': name,
        },
        'theme': {'color': PaymentConfig.companyColor},
        'notes': {
          'package_key': packageKey,
          'credits': package.totalCredits.toString(),
          'type': 'credits',
        },
      });
      debugPrint('✅ Razorpay credits opened: ${package.displayInr()} [${PaymentConfig.isTestMode ? "TEST" : "LIVE"}]');
    } catch (e) {
      _currentPackageKey = null;
      _isCreditsCheckout = false;
      onPaymentFailure?.call('Failed to open payment: $e');
    }
  }

  void _onSuccess(PaymentSuccessResponse r) {
    final id = r.paymentId ?? '';
    if (_isCreditsCheckout) {
      final key = _currentPackageKey ?? '';
      final pkg = CreditsService.getPackageByKey(key);
      _currentPackageKey = null;
      _isCreditsCheckout = false;
      if (pkg != null) {
        onCreditsSuccess?.call(id, key, pkg.totalCredits);
      }
      debugPrint('✅ Razorpay credits success: $id');
    } else {
      final key = _currentPlanKey ?? '';
      _currentPlanKey = null;
      onPaymentSuccess?.call(id, key);
      debugPrint('✅ Razorpay success: $id');
    }
  }

  void _onError(PaymentFailureResponse r) {
    _currentPlanKey = null;
    onPaymentFailure?.call(r.message ?? 'Payment failed');
    debugPrint('❌ Razorpay error: ${r.code} ${r.message}');
  }

  void _onExternalWallet(ExternalWalletResponse r) {
    debugPrint('💳 External wallet: ${r.walletName}');
  }

  void dispose() {
    _razorpay?.clear();
    _webPaymentService?.dispose();
  }
}
