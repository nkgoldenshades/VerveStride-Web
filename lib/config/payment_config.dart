/// Payment configuration for Razorpay (INR).
///
/// PRODUCTION BUILD:
/// flutter build apk --release --dart-define=RAZORPAY_KEY_ID=rzp_live_xxx --dart-define=RAZORPAY_KEY_SECRET=your_secret
///
/// DEVELOPMENT BUILD:
/// flutter run --dart-define=RAZORPAY_KEY_ID=rzp_test_xxx --dart-define=RAZORPAY_KEY_SECRET=your_test_secret
class PaymentConfig {
  // Keys can be provided at build time via --dart-define
  // Production:  --dart-define=RAZORPAY_KEY_ID=rzp_live_xxx --dart-define=RAZORPAY_KEY_SECRET=your_secret
  // Development: Uses test keys below for local testing

  // PRODUCTION: Live Razorpay Key (safe to expose in client)
  // Get from: https://dashboard.razorpay.com/app/keys
  static const String razorpayKeyId = String.fromEnvironment(
    'RAZORPAY_KEY_ID',
    defaultValue: 'rzp_live_T7wyn6UQYeO8DA',
  );

  static const String razorpayKeySecret = String.fromEnvironment(
    'RAZORPAY_KEY_SECRET',
    defaultValue: '', // No default secret for security
  );

  static const String companyName = 'VerveStride';

  // Logo URL - Update this with your actual logo URL
  // Upload logo to Firebase Storage or use your domain
  static const String companyLogo = String.fromEnvironment(
    'COMPANY_LOGO_URL',
    defaultValue:
        'https://vervestride-app.firebaseapp.com/assets/images/vervestridelogo.jpeg',
  );

  static const String companyColor = '#6C63FF';
  static const String inrCurrency = 'INR';

  /// Validates that payment keys are configured
  static bool get isConfigured {
    // For client-side payments, we only need the key ID
    // The secret is only needed for server-side verification
    return razorpayKeyId.isNotEmpty;
  }

  /// Returns true if using test keys (for development)
  static bool get isTestMode {
    return razorpayKeyId.startsWith('rzp_test_');
  }

  /// Returns true if using live keys (for production)
  static bool get isLiveMode {
    return razorpayKeyId.startsWith('rzp_live_');
  }

  /// Converts a price to paise (smallest INR unit).
  static int toSmallestUnit(double amount) => (amount * 100).round();
}
