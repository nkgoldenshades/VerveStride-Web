import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Secure logger that sanitizes sensitive data and respects build mode
class SecureLogger {
  static final SecureLogger _instance = SecureLogger._internal();
  factory SecureLogger() => _instance;
  SecureLogger._internal();

  late final Logger _logger;
  bool _initialized = false;

  /// Initialize the logger (call once at app startup)
  void init() {
    if (_initialized) return;

    _logger = Logger(
      filter: _ProductionFilter(),
      printer: _SecurePrinter(),
      output: _SecureOutput(),
      level: kReleaseMode ? Level.warning : Level.debug,
    );

    _initialized = true;
  }

  /// Debug level - only in debug builds
  void d(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    if (!kReleaseMode) {
      _logger.d(_sanitize(message), error: error, stackTrace: stackTrace);
    }
  }

  /// Info level - important but non-sensitive info
  void i(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(_sanitize(message), error: error, stackTrace: stackTrace);
  }

  /// Warning level - potential issues
  void w(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(_sanitize(message), error: error, stackTrace: stackTrace);
  }

  /// Error level - errors that should be logged
  void e(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(_sanitize(message), error: error, stackTrace: stackTrace);
  }

  /// Fatal level - critical errors
  void f(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.f(_sanitize(message), error: error, stackTrace: stackTrace);
  }

  /// Sanitize sensitive data from logs
  String _sanitize(dynamic message) {
    if (message == null) return 'null';
    
    String str = message.toString();

    // Sanitize user IDs (Firebase UIDs are 28 chars alphanumeric)
    str = str.replaceAllMapped(
      RegExp(r'\b[A-Za-z0-9]{20,}\b'),
      (match) => '***UID***',
    );

    // Sanitize email addresses
    str = str.replaceAllMapped(
      RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'),
      (match) => '***EMAIL***',
    );

    // Sanitize tokens and keys
    str = str.replaceAllMapped(
      RegExp(r'(token|key|secret|password|pwd|auth)["\s:=]+[A-Za-z0-9+/=_-]{10,}', caseSensitive: false),
      (match) => '${match.group(1)}: ***REDACTED***',
    );

    // Sanitize credit card numbers
    str = str.replaceAllMapped(
      RegExp(r'\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b'),
      (match) => '***CARD***',
    );

    // Sanitize phone numbers
    str = str.replaceAllMapped(
      RegExp(r'\b\d{3}[-.]?\d{3}[-.]?\d{4}\b'),
      (match) => '***PHONE***',
    );

    // Sanitize referral codes (your format: uppercase alphanumeric)
    str = str.replaceAllMapped(
      RegExp(r'\b[A-Z0-9]{8,12}\b'),
      (match) => '***CODE***',
    );

    return str;
  }
}

/// Custom filter that respects build mode
class _ProductionFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    // In release mode, only log warnings and above
    if (kReleaseMode) {
      return event.level.index >= Level.warning.index;
    }
    // In debug mode, log everything
    return true;
  }
}

/// Custom printer that formats logs securely
class _SecurePrinter extends LogPrinter {
  static final _levelEmojis = {
    Level.debug: '🐛',
    Level.info: 'ℹ️',
    Level.warning: '⚠️',
    Level.error: '❌',
    Level.fatal: '💀',
  };

  @override
  List<String> log(LogEvent event) {
    final emoji = _levelEmojis[event.level] ?? '';
    final message = event.message;
    
    // In release mode, don't include timestamps or detailed info
    if (kReleaseMode) {
      return ['$emoji ${event.level.name.toUpperCase()}: $message'];
    }
    
    // In debug mode, include more context
    final time = DateTime.now().toString().split('.')[0];
    final output = ['$emoji [$time] ${event.level.name.toUpperCase()}: $message'];
    
    if (event.error != null) {
      output.add('Error: ${event.error}');
    }
    
    // Only show stack traces in debug mode for errors
    if (event.stackTrace != null && !kReleaseMode) {
      output.add('Stack trace:');
      output.add(event.stackTrace.toString());
    }
    
    return output;
  }
}

/// Custom output that prevents logging in production web builds
class _SecureOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    // In release mode on web, don't output anything to console
    if (kReleaseMode && kIsWeb) {
      return;
    }
    
    // Otherwise, output to console
    for (var line in event.lines) {
      // ignore: avoid_print
      print(line);
    }
  }
}

/// Global logger instance
final logger = SecureLogger();
