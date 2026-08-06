import 'package:flutter/material.dart';

/// Professional spacing system for consistent UI across the app
/// Use these values everywhere to maintain visual hierarchy and premium feel

class AppSpacing {
  // Screen-level spacing
  static const double screenPadding = 16.0;
  static const double screenPaddingSmall = 12.0;
  static const double screenPaddingLarge = 24.0;

  // Section spacing (between major components)
  static const double sectionSpacing = 24.0;
  static const double sectionSpacingSmall = 16.0;
  static const double sectionSpacingLarge = 32.0;

  // Card spacing
  static const double cardPadding = 20.0;
  static const double cardPaddingSmall = 16.0;
  static const double cardPaddingLarge = 24.0;
  static const double cardMargin = 16.0;
  static const double cardMarginSmall = 12.0;
  static const double cardMarginLarge = 20.0;

  // Text spacing inside cards
  static const double textSpacingXS = 4.0;
  static const double textSpacingS = 6.0;
  static const double textSpacingM = 8.0;
  static const double textSpacingL = 12.0;
  static const double textSpacingXL = 16.0;

  // Button spacing
  static const double buttonSpacing = 16.0;
  static const double buttonHeightS = 40.0;
  static const double buttonHeightM = 48.0;
  static const double buttonHeightL = 52.0;
  static const double buttonHeightXL = 56.0;

  // Form spacing
  static const double fieldSpacing = 16.0;
  static const double fieldSpacingS = 12.0;
  static const double fieldSpacingL = 20.0;

  // List spacing
  static const double listItemSpacing = 12.0;
  static const double listItemSpacingS = 8.0;
  static const double listItemSpacingL = 16.0;

  // Icon spacing
  static const double iconSpacingS = 8.0;
  static const double iconSpacingM = 12.0;
  static const double iconSpacingL = 16.0;

  // Common EdgeInsets shortcuts
  static EdgeInsets get screenPaddingAll => const EdgeInsets.all(screenPadding);
  static EdgeInsets get screenPaddingHorizontal => const EdgeInsets.symmetric(horizontal: screenPadding);
  static EdgeInsets get screenPaddingVertical => const EdgeInsets.symmetric(vertical: screenPadding);
  
  static EdgeInsets get cardPaddingAll => const EdgeInsets.all(cardPadding);
  static EdgeInsets get cardPaddingHorizontal => const EdgeInsets.symmetric(horizontal: cardPadding);
  static EdgeInsets get cardPaddingVertical => const EdgeInsets.symmetric(vertical: cardPadding);
  
  static EdgeInsets get cardMarginHorizontal => const EdgeInsets.symmetric(horizontal: cardMargin);
  static EdgeInsets get cardMarginAll => const EdgeInsets.all(cardMargin);
}

/// Text spacing patterns for consistent typography hierarchy
class TextSpacing {
  static const SizedBox xs = SizedBox(height: AppSpacing.textSpacingXS);
  static const SizedBox s = SizedBox(height: AppSpacing.textSpacingS);
  static const SizedBox m = SizedBox(height: AppSpacing.textSpacingM);
  static const SizedBox l = SizedBox(height: AppSpacing.textSpacingL);
  static const SizedBox xl = SizedBox(height: AppSpacing.textSpacingXL);
}

/// Layout spacing patterns for consistent component spacing
class LayoutSpacing {
  static const SizedBox xs = SizedBox(height: AppSpacing.textSpacingXS);
  static const SizedBox s = SizedBox(height: AppSpacing.textSpacingS);
  static const SizedBox m = SizedBox(height: AppSpacing.textSpacingM);
  static const SizedBox l = SizedBox(height: AppSpacing.textSpacingL);
  static const SizedBox xl = SizedBox(height: AppSpacing.textSpacingXL);
  
  static const SizedBox sectionS = SizedBox(height: AppSpacing.sectionSpacingSmall);
  static const SizedBox section = SizedBox(height: AppSpacing.sectionSpacing);
  static const SizedBox sectionL = SizedBox(height: AppSpacing.sectionSpacingLarge);
}

/// Button spacing patterns
class ButtonSpacing {
  static const SizedBox s = SizedBox(height: AppSpacing.buttonSpacing);
  static const SizedBox m = SizedBox(height: AppSpacing.buttonSpacing);
  static const SizedBox l = SizedBox(height: AppSpacing.fieldSpacingL);
}

/// Card layout patterns
class CardLayout {
  static Widget build({
    required Widget child,
    EdgeInsets? padding,
    EdgeInsets? margin,
    double? width,
  }) {
    return Container(
      width: width,
      margin: margin ?? AppSpacing.cardMarginHorizontal,
      padding: padding ?? AppSpacing.cardPaddingAll,
      child: child,
    );
  }
  
  static Widget buildSection({
    required Widget child,
    EdgeInsets? padding,
    Widget? title,
    Widget? action,
    Widget? footer,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          title,
          const SizedBox(height: AppSpacing.textSpacingS),
        ],
        child,
        if (action != null) ...[
          const SizedBox(height: AppSpacing.textSpacingM),
          action,
        ],
        if (footer != null) ...[
          const SizedBox(height: AppSpacing.textSpacingM),
          footer,
        ],
      ],
    );
  }
}
