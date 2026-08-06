import 'package:flutter/material.dart';

/// Standardized UI alignment and spacing constants for consistent design across the app
class UIConstants {
  // Prevent instantiation
  UIConstants._();

  // Standard padding values
  static const double paddingXS = 8.0;
  static const double paddingSM = 12.0;
  static const double paddingMD = 16.0;
  static const double paddingLG = 20.0;
  static const double paddingXL = 24.0;
  static const double paddingXXL = 32.0;

  // Standard spacing values
  static const double spacingXS = 4.0;
  static const double spacingSM = 8.0;
  static const double spacingMD = 12.0;
  static const double spacingLG = 16.0;
  static const double spacingXL = 20.0;
  static const double spacingXXL = 24.0;
  static const double spacingXXXL = 32.0;

  // Standard border radius
  static const double radiusSM = 8.0;
  static const double radiusMD = 12.0;
  static const double radiusLG = 16.0;
  static const double radiusXL = 20.0;
  static const double radiusXXL = 24.0;

  // Standard card padding
  static const EdgeInsets cardPadding = EdgeInsets.all(paddingXL);
  static const EdgeInsets cardPaddingHorizontal = EdgeInsets.symmetric(horizontal: paddingXL);
  static const EdgeInsets cardPaddingVertical = EdgeInsets.symmetric(vertical: paddingXL);
  static const EdgeInsets cardPaddingCompact = EdgeInsets.all(paddingLG);

  // Standard screen padding
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: paddingLG);
  static const EdgeInsets screenPaddingCompact = EdgeInsets.symmetric(horizontal: paddingMD);

  // Standard container spacing
  static const SizedBox spacingBetweenCards = SizedBox(height: spacingLG);
  static const SizedBox spacingBetweenSections = SizedBox(height: spacingXXL);
  static const SizedBox spacingBetweenItems = SizedBox(height: spacingMD);
  static const SizedBox spacingBetweenRows = SizedBox(width: spacingMD);

  // Standard card decoration
  static BoxDecoration cardDecoration = BoxDecoration(
    borderRadius: BorderRadius.circular(radiusXL),
    boxShadow: [
      BoxShadow(
        blurRadius: 8,
        color: Colors.black.withOpacity(0.06),
        offset: const Offset(0, 4),
      ),
      BoxShadow(
        blurRadius: 20,
        color: Colors.black.withOpacity(0.03),
        offset: const Offset(0, 8),
      ),
    ],
  );

  // Standard gradient decoration
  static BoxDecoration gradientCardDecoration = BoxDecoration(
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFF2A2A3E),
        Color(0xFF1F1F2E),
      ],
    ),
    borderRadius: BorderRadius.circular(radiusXL),
    boxShadow: [
      BoxShadow(
        blurRadius: 8,
        color: Colors.black.withOpacity(0.06),
        offset: const Offset(0, 4),
      ),
      BoxShadow(
        blurRadius: 20,
        color: Colors.black.withOpacity(0.03),
        offset: const Offset(0, 8),
      ),
    ],
  );

  // Standard button decoration
  static BoxDecoration buttonDecoration = BoxDecoration(
    borderRadius: BorderRadius.circular(radiusMD),
    boxShadow: [
      BoxShadow(
        blurRadius: 4,
        color: Colors.black.withOpacity(0.1),
        offset: const Offset(0, 2),
      ),
    ],
  );

  // Standard text styles
  static const TextStyle cardTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  static const TextStyle cardSubtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Colors.white70,
  );

  static const TextStyle buttonText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  static const TextStyle percentageText = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static const TextStyle statusText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: Colors.white,
  );

  // Standard container constraints
  static const double maxCardWidth = 400.0;
  static const double minCardWidth = 300.0;
  static const double standardButtonHeight = 60.0;
  static const double compactButtonHeight = 48.0;
}
