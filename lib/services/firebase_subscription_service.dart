import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'user_subscription_service.dart';
import 'credits_service.dart';

/// Service to interact with Firebase Cloud Functions for subscription management
/// This provides server-side validation and prevents client-side manipulation
class FirebaseSubscriptionService {
  static final FirebaseSubscriptionService instance = FirebaseSubscriptionService._();
  FirebaseSubscriptionService._();

  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Activate subscription after successful Razorpay payment
  Future<Map<String, dynamic>> activateSubscription({
    required String paymentId,
    required String planKey,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      debugPrint('🔄 Calling Cloud Function: activateSubscription');
      debugPrint('   Payment ID: $paymentId');
      debugPrint('   Plan Key: $planKey');

      final callable = _functions.httpsCallable('activateSubscription');
      final result = await callable.call({
        'paymentId': paymentId,
        'planKey': planKey,
      });

      debugPrint('✅ Subscription activated: ${result.data}');

      // Sync local state with server
      await _syncSubscriptionFromServer();

      return {
        'success': true,
        'data': result.data,
      };
    } catch (e) {
      debugPrint('❌ Error activating subscription: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Add credits after successful Razorpay payment (via Cloud Function)
  Future<Map<String, dynamic>> addCredits({
    required String paymentId,
    required String packageKey,
    required int credits,
  }) async {
    try {
      debugPrint('🔄 Calling addCredits Cloud Function with paymentId: $paymentId, packageKey: $packageKey');
      
      // Call Cloud Function with the REAL payment ID from Razorpay
      final result = await _functions.httpsCallable('addCredits').call({
        'paymentId': paymentId,
        'packageKey': packageKey,
      });

      debugPrint('✅ Cloud Function response: ${result.data}');

      // Sync local credits from server response (including precise field)
      final remaining = (result.data?['credits']?['remaining'] as num?)?.toInt();
      final precise = (result.data?['credits']?['precise'] as num?)?.toDouble();
      
      if (precise != null) {
        CreditsService.instance.forceSetPrecise(precise);
      } else if (remaining != null) {
        CreditsService.instance.forceSet(remaining);
      } else {
        // Fallback: reload from Firestore
        await CreditsService.instance.load(force: true);
      }

      return {
        'success': true,
        'data': result.data,
      };
    } catch (e) {
      debugPrint('❌ Error adding credits via Cloud Function: $e');
      // Reload to get accurate balance
      await CreditsService.instance.load(force: true);
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Deduct credits for AI usage (direct Firestore)
  Future<Map<String, dynamic>> deductCredits({
    required int amount,
    String? description,
  }) async {
    try {
      final success = await CreditsService.instance.useCredits(
        amount,
        description: description,
      );
      return {
        'success': success,
        'data': {
          'credits': {'remaining': CreditsService.instance.availableCredits}
        },
      };
    } catch (e) {
      debugPrint('❌ Error deducting credits: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Refund credits (direct Firestore)
  Future<Map<String, dynamic>> refundCredits({
    required int amount,
    String? reason,
  }) async {
    try {
      await CreditsService.instance.refundCredits(amount);
      return {
        'success': true,
        'data': {
          'credits': {'total': CreditsService.instance.availableCredits}
        },
      };
    } catch (e) {
      debugPrint('❌ Error refunding credits: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get subscription status from server
  Future<Map<String, dynamic>> getSubscriptionStatus() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      debugPrint('🔄 Calling Cloud Function: getSubscriptionStatus');

      final callable = _functions.httpsCallable('getSubscriptionStatus');
      final result = await callable.call();

      debugPrint('✅ Subscription status: ${result.data}');

      // Sync local state with server
      await _syncFromServerData(result.data);

      return {
        'success': true,
        'data': result.data,
      };
    } catch (e) {
      debugPrint('❌ Error getting subscription status: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Listen to real-time subscription updates from Firestore
  Stream<Map<String, dynamic>?> subscriptionStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(null);
    }

    return _firestore
        .collection('Users')
        .doc(user.uid)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      
      final data = snapshot.data();
      return {
        'subscription': data?['subscription'],
        'credits': data?['credits'],
      };
    });
  }

  /// Sync subscription from server to local storage
  Future<void> _syncSubscriptionFromServer() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final doc = await _firestore.collection('Users').doc(user.uid).get();
      if (!doc.exists) return;

      final data = doc.data();
      final subscription = data?['subscription'];

      if (subscription != null) {
        // Update UserSubscriptionService
        final planKey = subscription['planKey'] as String?;

        if (planKey != null) {
          // Update local storage
          await UserSubscriptionService.instance.load(force: true);
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error syncing subscription from server: $e');
    }
  }

  /// Update local credits
  Future<void> _updateLocalCredits(int amount) async {
    // This is a simplified version - you may want to update CreditsService directly
    debugPrint('💳 Local credits updated: $amount');
    await CreditsService.instance.load(force: true);
  }

  /// Sync all data from server response
  Future<void> _syncFromServerData(Map<String, dynamic> data) async {
    try {
      // Sync subscription
      final subscription = data['subscription'];
      if (subscription != null) {
        await UserSubscriptionService.instance.load(force: true);
      }

      // Sync credits
      final credits = data['credits'];
      if (credits != null) {
        final available = credits['available'] as int? ?? 0;
        await _updateLocalCredits(available);
      }
    } catch (e) {
      debugPrint('⚠️ Error syncing from server data: $e');
    }
  }
}
