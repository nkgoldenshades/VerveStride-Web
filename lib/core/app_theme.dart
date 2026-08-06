import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color background = Color(0xFF07162C);
  static const Color surface = Color(0xFF0C1F36);
  static const Color card = Color(0xFF102844);
  static Color primary = const Color(0xFF7C5CFF);
  static Color secondary = const Color(0xFF19E3D6);
  static Color accent = const Color(0xFFFFC857);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFAFC2DD);
  static const Color divider = Color(0xFF1E3A5F);
}

class AppTheme {
  static ThemeData theme() {
    return darkThemeWith(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      accent: AppColors.accent,
    );
  }

  static ThemeData darkThemeWith({
    required Color primary,
    required Color secondary,
    required Color accent,
  }) {
    final baseText = kIsWeb
        ? ThemeData.dark().textTheme
        : (GoogleFonts.plusJakartaSansTextTheme());
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.dark,
        primary: primary,
        secondary: secondary,
        surface: AppColors.surface,
        background: AppColors.background,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.textPrimary,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        titleTextStyle:
            baseText.titleLarge?.copyWith(color: AppColors.textPrimary),
      ),
      iconTheme: IconThemeData(color: AppColors.textPrimary),
      textTheme: baseText.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      useMaterial3: true,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        hintStyle: const TextStyle(color: AppColors.textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: AppColors.textPrimary,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        ),
      ),
    );
  }

  static ThemeData lightThemeWith({
    required Color primary,
    required Color secondary,
    required Color accent,
  }) {
    final baseText = GoogleFonts.plusJakartaSansTextTheme();
    const lightBg = Color(0xFFF7F8FC);
    const lightSurface = Colors.white;
    const lightCard = Colors.white;
    const textPrimary = Color(0xFF0E1222);
    const textSecondary = Color(0xFF5B647A);

    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        primary: primary,
        secondary: secondary,
        surface: lightSurface,
        background: lightBg,
      ),
      scaffoldBackgroundColor: lightBg,
      textTheme: baseText.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: textPrimary,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
            color: textPrimary, fontSize: 22, fontWeight: FontWeight.w600),
      ),
      iconTheme: const IconThemeData(color: textPrimary),
      useMaterial3: true,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        hintStyle: const TextStyle(color: textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: textPrimary,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        ),
      ),
      cardTheme: const CardThemeData(color: lightCard),
      dividerColor: const Color(0xFFE5E5E5),
    );
  }
}

class AppDecorations {
  static BoxDecoration gradientBackground() => const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF040A16), Color(0xFF0C1A2F), Color(0xFF0F1F3A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      );

  static BoxDecoration glassCard({bool highlighted = false}) => BoxDecoration(
        color: AppColors.card.withOpacity(highlighted ? 0.9 : 0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: highlighted
              ? AppColors.primary.withOpacity(0.5)
              : Colors.white.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 30,
            offset: const Offset(0, 20),
          ),
        ],
      );
}
