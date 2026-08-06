import 'package:flutter/foundation.dart';

/// Shared controller so UI outside the floating widget can show/hide it
/// immediately (without requiring app restart).
class AIFloatingAssistantController {
  AIFloatingAssistantController._();

  /// `true` = hidden, `false` = visible.
  static final ValueNotifier<bool> hidden = ValueNotifier<bool>(false);
  
  /// `true` = floating AI feature enabled, `false` = completely disabled.
  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(false);
}

