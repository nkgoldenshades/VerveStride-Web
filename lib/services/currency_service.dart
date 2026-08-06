import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import '../models/ai_credits.dart';

/// Service for currency conversion and localization
class CurrencyService {
  static final CurrencyService _instance = CurrencyService._internal();
  factory CurrencyService() => _instance;
  CurrencyService._internal();

  static CurrencyService get instance => _instance;

  // Cache for exchange rates (refresh every 24 hours)
  Map<String, double> _exchangeRates = {};
  DateTime? _lastRateUpdate;
  String _userCurrency = 'USD';
  String _userCountry = 'US';

  /// Supported currencies with their symbols and country codes
  static const Map<String, CurrencyInfo> supportedCurrencies = {
    'USD': CurrencyInfo('USD', '\$', 'US', 'United States Dollar'),
    'EUR': CurrencyInfo('EUR', '€', 'EU', 'Euro'),
    'GBP': CurrencyInfo('GBP', '£', 'GB', 'British Pound'),
    'INR': CurrencyInfo('INR', '₹', 'IN', 'Indian Rupee'),
    'CAD': CurrencyInfo('CAD', 'C\$', 'CA', 'Canadian Dollar'),
    'AUD': CurrencyInfo('AUD', 'A\$', 'AU', 'Australian Dollar'),
    'JPY': CurrencyInfo('JPY', '¥', 'JP', 'Japanese Yen'),
    'CNY': CurrencyInfo('CNY', '¥', 'CN', 'Chinese Yuan'),
    'KRW': CurrencyInfo('KRW', '₩', 'KR', 'South Korean Won'),
    'SGD': CurrencyInfo('SGD', 'S\$', 'SG', 'Singapore Dollar'),
    'HKD': CurrencyInfo('HKD', 'HK\$', 'HK', 'Hong Kong Dollar'),
    'MXN': CurrencyInfo('MXN', '\$', 'MX', 'Mexican Peso'),
    'BRL': CurrencyInfo('BRL', 'R\$', 'BR', 'Brazilian Real'),
    'AED': CurrencyInfo('AED', 'د.إ', 'AE', 'UAE Dirham'),
    'SAR': CurrencyInfo('SAR', '﷼', 'SA', 'Saudi Riyal'),
    'ZAR': CurrencyInfo('ZAR', 'R', 'ZA', 'South African Rand'),
    'NGN': CurrencyInfo('NGN', '₦', 'NG', 'Nigerian Naira'),
    'EGP': CurrencyInfo('EGP', '£', 'EG', 'Egyptian Pound'),
    'TRY': CurrencyInfo('TRY', '₺', 'TR', 'Turkish Lira'),
    'RUB': CurrencyInfo('RUB', '₽', 'RU', 'Russian Ruble'),
  };

  /// Country to currency mapping
  static const Map<String, String> countryToCurrency = {
    'US': 'USD', 'CA': 'CAD', 'GB': 'GBP', 'AU': 'AUD', 'NZ': 'AUD',
    'IN': 'INR', 'JP': 'JPY', 'CN': 'CNY', 'KR': 'KRW', 'SG': 'SGD',
    'HK': 'HKD', 'MX': 'MXN', 'BR': 'BRL', 'AE': 'AED', 'SA': 'SAR',
    'ZA': 'ZAR', 'NG': 'NGN', 'EG': 'EGP', 'TR': 'TRY', 'RU': 'RUB',
    // European countries
    'DE': 'EUR', 'FR': 'EUR', 'IT': 'EUR', 'ES': 'EUR', 'NL': 'EUR',
    'BE': 'EUR', 'AT': 'EUR', 'PT': 'EUR', 'IE': 'EUR', 'FI': 'EUR',
    'GR': 'EUR', 'LU': 'EUR', 'MT': 'EUR', 'CY': 'EUR', 'SK': 'EUR',
    'SI': 'EUR', 'EE': 'EUR', 'LV': 'EUR', 'LT': 'EUR',
    // Other major countries
    'CH': 'EUR', 'NO': 'EUR', 'SE': 'EUR', 'DK': 'EUR', 'PL': 'EUR',
    'CZ': 'EUR', 'HU': 'EUR', 'RO': 'EUR', 'BG': 'EUR', 'HR': 'EUR',
  };

  String get userCurrency => _userCurrency;
  String get userCountry => _userCountry;
  CurrencyInfo get currencyInfo => supportedCurrencies[_userCurrency]!;

  /// Initialize currency based on device locale
  Future<void> initialize() async {
    try {
      // Get device locale
      final locale = WidgetsBinding.instance.platformDispatcher.locale;
      final countryCode = locale.countryCode?.toUpperCase() ?? 'US';
      
      _userCountry = countryCode;
      _userCurrency = countryToCurrency[countryCode] ?? 'USD';
      
      debugPrint('🌍 Detected country: $countryCode, currency: $_userCurrency');
      
      // Load exchange rates
      await _loadExchangeRates();
    } catch (e) {
      debugPrint('❌ Currency initialization failed: $e');
      _userCurrency = 'USD';
      _userCountry = 'US';
    }
  }

  /// Load exchange rates from API
  Future<void> _loadExchangeRates() async {
    // Check if rates are fresh (less than 24 hours old)
    if (_lastRateUpdate != null && 
        DateTime.now().difference(_lastRateUpdate!).inHours < 24 &&
        _exchangeRates.isNotEmpty) {
      return;
    }

    try {
      // Using exchangerate-api.com (free tier: 1500 requests/month)
      final response = await http.get(
        Uri.parse('https://api.exchangerate-api.com/v4/latest/USD'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _exchangeRates = Map<String, double>.from(data['rates']);
        _lastRateUpdate = DateTime.now();
        debugPrint('💱 Exchange rates updated: ${_exchangeRates.length} currencies');
      } else {
        throw Exception('API returned ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Failed to load exchange rates: $e');
      // Use fallback rates if API fails
      _useFallbackRates();
    }
  }

  /// Fallback exchange rates (approximate, updated periodically)
  void _useFallbackRates() {
    _exchangeRates = {
      'USD': 1.0,
      'EUR': 0.85,
      'GBP': 0.73,
      'INR': 83.0,
      'CAD': 1.35,
      'AUD': 1.50,
      'JPY': 150.0,
      'CNY': 7.2,
      'KRW': 1300.0,
      'SGD': 1.35,
      'HKD': 7.8,
      'MXN': 17.0,
      'BRL': 5.0,
      'AED': 3.67,
      'SAR': 3.75,
      'ZAR': 18.5,
      'NGN': 800.0,
      'EGP': 31.0,
      'TRY': 28.0,
      'RUB': 90.0,
    };
    _lastRateUpdate = DateTime.now();
    debugPrint('💱 Using fallback exchange rates');
  }

  /// Convert USD price to user's currency
  double convertFromUSD(double usdPrice) {
    if (_userCurrency == 'USD') return usdPrice;
    
    final rate = _exchangeRates[_userCurrency];
    if (rate == null) return usdPrice;
    
    return usdPrice * rate;
  }

  /// Format price in user's currency
  String formatPrice(double usdPrice) {
    final convertedPrice = convertFromUSD(usdPrice);
    final info = currencyInfo;
    
    // Round to appropriate decimal places
    final rounded = _roundPrice(convertedPrice, _userCurrency);
    
    // Format with currency symbol
    if (_userCurrency == 'JPY' || _userCurrency == 'KRW') {
      // No decimals for these currencies
      return '${info.symbol}${rounded.toInt()}';
    } else {
      return '${info.symbol}${rounded.toStringAsFixed(2)}';
    }
  }

  /// Round price to local conventions
  double _roundPrice(double price, String currency) {
    switch (currency) {
      case 'JPY':
      case 'KRW':
        // Round to nearest 10
        return (price / 10).round() * 10.0;
      case 'INR':
        // Round to nearest 5
        return (price / 5).round() * 5.0;
      default:
        // Round to nearest 0.99 or 0.49 for psychological pricing
        final rounded = price.round();
        if (rounded > price) {
          return rounded - 0.01;
        }
        return rounded.toDouble();
    }
  }

  /// Get localized credit package with converted prices
  CreditPackageLocalized getLocalizedPackage(CreditPackage package) {
    return CreditPackageLocalized(
      key: package.key,
      name: package.name,
      credits: package.credits,
      bonusCredits: package.bonusCredits ?? 0,
      badge: package.badge,
      localPrice: formatPrice(package.priceUsd),
      localCurrency: _userCurrency,
      originalUsdPrice: package.priceUsd,
    );
  }

  /// Manually set currency (for testing or user preference)
  void setCurrency(String currencyCode) {
    if (supportedCurrencies.containsKey(currencyCode)) {
      _userCurrency = currencyCode;
      debugPrint('💱 Currency manually set to: $currencyCode');
    }
  }
}

/// Currency information
class CurrencyInfo {
  final String code;
  final String symbol;
  final String countryCode;
  final String name;

  const CurrencyInfo(this.code, this.symbol, this.countryCode, this.name);
}

/// Localized credit package
class CreditPackageLocalized {
  final String key;
  final String name;
  final int credits;
  final int bonusCredits;
  final String? badge;
  final String localPrice;
  final String localCurrency;
  final double originalUsdPrice;

  const CreditPackageLocalized({
    required this.key,
    required this.name,
    required this.credits,
    this.bonusCredits = 0,
    this.badge,
    required this.localPrice,
    required this.localCurrency,
    required this.originalUsdPrice,
  });

  int get totalCredits => credits + bonusCredits;
}
