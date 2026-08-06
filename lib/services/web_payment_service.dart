// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:js';
import 'package:flutter/foundation.dart';
import '../config/payment_config.dart';
import 'subscription_service.dart';
import 'credits_service.dart';

/// Web-specific payment service using Razorpay Checkout.js
/// This service handles payments on web platform using JavaScript interop
class WebPaymentService {
  void Function(String paymentId, String planKey)? onPaymentSuccess;
  void Function(String paymentId, String packageKey, int credits)? onCreditsSuccess;
  void Function(String message)? onPaymentFailure;

  /// Open Razorpay checkout for subscription
  Future<void> openCheckout({
    required String planKey,
    String? email,
    String? name,
    String? contact,
  }) async {
    if (!kIsWeb) {
      onPaymentFailure?.call('This service is for web only');
      return;
    }

    if (!PaymentConfig.isConfigured) {
      onPaymentFailure?.call('Payment system not configured. Please contact support.');
      return;
    }

    final plan = SubscriptionService.getPlanByKey(planKey);
    if (plan == null) {
      onPaymentFailure?.call('Invalid subscription plan');
      return;
    }

    try {
      // Check if Razorpay is loaded
      if (context['Razorpay'] == null) {
        onPaymentFailure?.call('Payment system not loaded. Please refresh the page and try again.');
        if (kDebugMode) {
          print('❌ Razorpay not found in window context. Make sure checkout.js is loaded in index.html');
        }
        return;
      }

      // Create options object
      final options = JsObject.jsify({
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
        'theme': {
          'color': PaymentConfig.companyColor,
        },
        'notes': {
          'plan_key': planKey,
          'tier': plan.tier,
          'period': plan.period,
        },
      });

      // Add handler as a property using JsFunction
      options['handler'] = JsFunction.withThis((self, response) {
        final paymentId = response['razorpay_payment_id'];
        if (paymentId != null) {
          onPaymentSuccess?.call(paymentId.toString(), planKey);
        } else {
          onPaymentFailure?.call('Payment ID not received');
        }
      });

      // Add modal dismiss handler
      final modal = JsObject.jsify({});
      modal['ondismiss'] = JsFunction.withThis((self) {
        onPaymentFailure?.call('Payment cancelled by user');
      });
      options['modal'] = modal;

      // Create and open Razorpay instance
      final razorpay = JsObject(context['Razorpay'], [options]);
      razorpay.callMethod('open', []);
      
      if (kDebugMode) {
        print('✅ Razorpay web checkout opened: ${plan.displayInr()} [${PaymentConfig.isTestMode ? "TEST" : "LIVE"}]');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Razorpay web error: $e');
      }
      onPaymentFailure?.call('Failed to open payment: $e');
    }
  }

  /// Open Razorpay checkout for credits
  Future<void> openCreditsCheckout({
    required String packageKey,
    String? email,
    String? name,
    String? contact,
  }) async {
    if (!kIsWeb) {
      onPaymentFailure?.call('This service is for web only');
      return;
    }

    if (!PaymentConfig.isConfigured) {
      onPaymentFailure?.call('Payment system not configured. Please contact support.');
      return;
    }

    final package = CreditsService.getPackageByKey(packageKey);
    if (package == null) {
      onPaymentFailure?.call('Invalid credit package');
      return;
    }

    try {
      // Check if Razorpay is loaded
      if (context['Razorpay'] == null) {
        onPaymentFailure?.call('Payment system not loaded. Please refresh the page and try again.');
        if (kDebugMode) {
          print('❌ Razorpay not found in window context. Make sure checkout.js is loaded in index.html');
        }
        return;
      }

      // Create options object
      final options = JsObject.jsify({
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
        'theme': {
          'color': PaymentConfig.companyColor,
        },
        'notes': {
          'package_key': packageKey,
          'credits': package.totalCredits.toString(),
          'type': 'credits',
        },
      });

      // Add handler as a property using JsFunction
      options['handler'] = JsFunction.withThis((self, response) {
        final paymentId = response['razorpay_payment_id'];
        if (paymentId != null) {
          onCreditsSuccess?.call(paymentId.toString(), packageKey, package.totalCredits);
        } else {
          onPaymentFailure?.call('Payment ID not received');
        }
      });

      // Add modal dismiss handler
      final modal = JsObject.jsify({});
      modal['ondismiss'] = JsFunction.withThis((self) {
        onPaymentFailure?.call('Payment cancelled by user');
      });
      options['modal'] = modal;

      // Create and open Razorpay instance
      final razorpay = JsObject(context['Razorpay'], [options]);
      razorpay.callMethod('open', []);
      
      if (kDebugMode) {
        print('✅ Razorpay web credits checkout opened: ${package.displayInr()} [${PaymentConfig.isTestMode ? "TEST" : "LIVE"}]');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Razorpay web credits error: $e');
      }
      onPaymentFailure?.call('Failed to open payment: $e');
    }
  }

  void dispose() {
    // No cleanup needed for web
  }
}
