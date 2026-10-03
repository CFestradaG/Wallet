import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFFB68D57);
  static const Color accentColor = Color(0xFFE7C58F);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color errorColor = Color(0xFFE53935);
  static const Color graphite = Color(0xFF111111);
  static const Color surfaceDark = Color(0xFF181818);
  static const Color surfaceDarkHigh = Color(0xFF202020);
  static const Color borderDark = Color(0xFF2E2E2E);
  static const Color textPrimaryDark = Color(0xFFF5F1E8);
  static const Color textMutedDark = Color(0xFFA49B8C);
  static const Color canvasLight = Color(0xFFF3EFE8);
  static const Color surfaceLight = Color(0xFFFFFCF7);
  static const Color borderLight = Color(0xFFD9D0C4);
  static const Color textPrimaryLight = Color(0xFF181512);
  static const Color textMutedLight = Color(0xFF746B5F);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color pageBackground(BuildContext context) =>
      isDark(context) ? graphite : canvasLight;

  static Color panel(BuildContext context) =>
      isDark(context) ? surfaceDark : surfaceLight;

  static Color panelAlt(BuildContext context) =>
      isDark(context) ? surfaceDarkHigh : const Color(0xFFF7F2EA);

  static Color border(BuildContext context) =>
      isDark(context) ? borderDark : borderLight;

  static Color textPrimary(BuildContext context) =>
      isDark(context) ? textPrimaryDark : textPrimaryLight;

  static Color textMuted(BuildContext context) =>
      isDark(context) ? textMutedDark : textMutedLight;

  static Color navBackground(BuildContext context) =>
      isDark(context) ? surfaceDark : surfaceLight;

  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: primaryColor,
            brightness: Brightness.light,
          ).copyWith(
            primary: primaryColor,
            onPrimary: Colors.black,
            secondary: accentColor,
            onSecondary: Colors.black,
            surface: surfaceLight,
            onSurface: const Color(0xFF181512),
            error: const Color(0xFFB94A48),
            onError: Colors.white,
          ),
      scaffoldBackgroundColor: canvasLight,
      dividerColor: borderLight,
      cardTheme: CardThemeData(
        color: surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: borderLight),
        ),
        elevation: 0,
        clipBehavior: Clip.antiAlias,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.black,
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.ibmPlexSansTextTheme(base.textTheme).apply(
        bodyColor: const Color(0xFF181512),
        displayColor: const Color(0xFF181512),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Color(0xFF181512),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: primaryColor, width: 1.4),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: primaryColor,
            brightness: Brightness.dark,
          ).copyWith(
            primary: primaryColor,
            onPrimary: Colors.black,
            secondary: accentColor,
            onSecondary: Colors.black,
            surface: surfaceDark,
            onSurface: textPrimaryDark,
            error: const Color(0xFFE06C68),
            onError: Colors.black,
          ),
      scaffoldBackgroundColor: graphite,
      dividerColor: borderDark,
      cardTheme: CardThemeData(
        color: surfaceDark,
        shadowColor: const Color(0x66000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: borderDark),
        ),
        elevation: 0,
        clipBehavior: Clip.antiAlias,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.black,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: accentColor,
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.ibmPlexSansTextTheme(
        base.textTheme,
      ).apply(bodyColor: textPrimaryDark, displayColor: textPrimaryDark),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimaryDark,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceDarkHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: accentColor, width: 1.4),
        ),
      ),
    );
  }
}
