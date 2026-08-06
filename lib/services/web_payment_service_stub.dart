/// Stub implementation for non-web platforms
/// This file is used when compiling for mobile (Android/iOS)
class WebPaymentService {
  void Function(String paymentId, String planKey)? onPaymentSuccess;
  void Function(String paymentId, String packageKey, int credits)? onCreditsSuccess;
  void Function(String message)? onPaymentFailure;

  Future<void> openCheckout({
    required String planKey,
    String? email,
    String? name,
    String? contact,
  }) async {
    onPaymentFailure?.call('Web payment service not available on mobile');
  }

  Future<void> openCreditsCheckout({
    required String packageKey,
    String? email,
    String? name,
    String? contact,
  }) async {
    onPaymentFailure?.call('Web payment service not available on mobile');
  }

  void dispose() {
    // No cleanup needed
  }
}
