class EnhancedPaymentService {
  static final EnhancedPaymentService _instance =
      EnhancedPaymentService._internal();
  factory EnhancedPaymentService() => _instance;
  EnhancedPaymentService._internal();

  void Function(String paymentId)? onPaymentSuccess;
  void Function(String message)? onPaymentFailure;

  /// Opens payment checkout with local payment options (UPI, cards, etc.)
  Future<void> openCheckout({
    required double amount,
    required String name,
    required String description,
    String? email,
    String? contact,
  }) async {
    onPaymentFailure?.call('Payments are currently disabled.');
  }

  List<String> getAvailablePaymentMethods() => const [];

  bool get isLocalPaymentAvailable => false;

  void dispose() {
    // no-op
  }
}
