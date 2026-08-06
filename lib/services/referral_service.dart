import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'credits_service.dart';

class ReferralService {
  ReferralService._();
  static final ReferralService instance = ReferralService._();

  String? _referralCode;
  String? get referralCode => _referralCode;

  /// Load or generate the user's referral code
  Future<String?> loadReferralCode() async {
    if (FirebaseAuth.instance.currentUser == null) return null;
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('getReferralCode')
          .call();
      _referralCode = result.data?['code'] as String?;
      debugPrint('🔗 Referral code: $_referralCode');
      return _referralCode;
    } catch (e) {
      debugPrint('⚠️ Failed to load referral code: $e');
      return null;
    }
  }

  /// Apply a referral code entered by the user
  Future<ReferralResult> applyReferralCode(String code) async {
    if (FirebaseAuth.instance.currentUser == null) {
      return ReferralResult.error('Please sign in first');
    }
    if (code.trim().isEmpty) {
      return ReferralResult.error('Enter a referral code');
    }

    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('applyReferralCode')
          .call({'code': code.trim().toUpperCase()});

      final bonus = (result.data?['bonusCredits'] as num?)?.toInt() ?? 10;
      // Reload credits to reflect the bonus
      await CreditsService.instance.load(force: true);
      return ReferralResult.success(bonus);
    } on FirebaseFunctionsException catch (e) {
      switch (e.code) {
        case 'not-found':
          return ReferralResult.error('Referral code not found');
        case 'already-exists':
          return ReferralResult.error('You have already used a referral code');
        case 'invalid-argument':
          return ReferralResult.error(e.message ?? 'Invalid code');
        default:
          return ReferralResult.error('Something went wrong. Try again.');
      }
    } catch (e) {
      return ReferralResult.error('Something went wrong. Try again.');
    }
  }
}

class ReferralResult {
  final bool success;
  final String? message;
  final int bonusCredits;

  const ReferralResult._({required this.success, this.message, this.bonusCredits = 0});

  factory ReferralResult.success(int bonus) =>
      ReferralResult._(success: true, bonusCredits: bonus);

  factory ReferralResult.error(String message) =>
      ReferralResult._(success: false, message: message);
}
