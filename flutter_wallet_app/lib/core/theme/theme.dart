import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sistema de Diseño "Obsidian Flow" — Stitch Material 3 Dark Theme
/// Configura la paleta exacta de Wallet by BudgetBakers (#121212 Canvas Base,
/// #00E676 Inflow Emerald, #FF5252 Outflow Crimson, #00E5FF Analytics Cyan).
class ObsidianFlowColors {
  ObsidianFlowColors._();

  // Canvas & Surface Hierarchy (Obsidian Flow Spec)
  static const Color canvasBase = Color(0xFF121212);
  static const Color surface = Color(0xFF131313);
  static const Color surfaceDim = Color(0xFF131313);
  static const Color surfaceBright = Color(0xFF393939);
  static const Color surfaceContainerLowest = Color(0xFF0E0E0E);
  static const Color surfaceContainerLow = Color(0xFF1C1B1B);
  static const Color surfaceContainer = Color(0xFF201F1F);
  static const Color surfaceContainerHigh = Color(0xFF2A2A2A);
  static const Color surfaceContainerHighest = Color(0xFF353534);

  // Elevations & Borders
  static const Color elevation1 = Color(0xFF1E1E1E);
  static const Color elevation2 = Color(0xFF252525);
  static const Color elevation3 = Color(0xFF2E2E2E);
  static const Color dividerBorder = Color(0xFF2C2C2C);

  // Semantic Accents (Material 3 Tokens + Stitch Spec)
  static const Color primary = Color(0xFF75FF9E);
  static const Color onPrimary = Color(0xFF003918);
  static const Color primaryContainer = Color(0xFF00E676); // Inflow Emerald
  static const Color onPrimaryContainer = Color(0xFF00612E);
  static const Color primaryFixed = Color(0xFF62FF96);
  static const Color primaryFixedDim = Color(0xFF00E475);

  static const Color secondary = Color(0xFFFFB3AE);
  static const Color onSecondary = Color(0xFF68000C);
  static const Color secondaryContainer = Color(0xFFA00118);
  static const Color onSecondaryContainer = Color(0xFFFFA8A3);
  static const Color outflowCrimson = Color(0xFFFF5252); // Outflow Accent

  static const Color tertiary = Color(0xFFA3F1FF);
  static const Color onTertiary = Color(0xFF00363D);
  static const Color tertiaryContainer = Color(0xFF00DCF5);
  static const Color onTertiaryContainer = Color(0xFF005D68);
  static const Color analyticsCyan = Color(0xFF00E5FF); // Analytics Accent
  static const Color calculatorHeaderCyan = Color(0xFF00ACC1);

  static const Color categoryViolet = Color(0xFF9C27B0); // Quaternary Accent

  static const Color error = Color(0xFFFFB4AB);
  static const Color onError = Color(0xFF690005);
  static const Color errorContainer = Color(0xFF93000A);
  static const Color onErrorContainer = Color(0xFFFFDAD6);

  // Typography & Foregrounds
  static const Color onSurface = Color(0xFFE5E2E1);
  static const Color onSurfaceVariant = Color(0xFFBACBB9);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA0A0A0);
  static const Color textMuted = Color(0xFF666666);
  static const Color outline = Color(0xFF859585);
  static const Color outlineVariant = Color(0xFF3B4A3D);
}

class ObsidianFlowTheme {
  ObsidianFlowTheme._();

  static ThemeData get darkTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: ObsidianFlowColors.primary,
      onPrimary: ObsidianFlowColors.onPrimary,
      primaryContainer: ObsidianFlowColors.primaryContainer,
      onPrimaryContainer: ObsidianFlowColors.onPrimaryContainer,
      secondary: ObsidianFlowColors.secondary,
      onSecondary: ObsidianFlowColors.onSecondary,
      secondaryContainer: ObsidianFlowColors.secondaryContainer,
      onSecondaryContainer: ObsidianFlowColors.onSecondaryContainer,
      tertiary: ObsidianFlowColors.tertiary,
      onTertiary: ObsidianFlowColors.onTertiary,
      tertiaryContainer: ObsidianFlowColors.tertiaryContainer,
      onTertiaryContainer: ObsidianFlowColors.onTertiaryContainer,
      error: ObsidianFlowColors.error,
      onError: ObsidianFlowColors.onError,
      errorContainer: ObsidianFlowColors.errorContainer,
      onErrorContainer: ObsidianFlowColors.onErrorContainer,
      surface: ObsidianFlowColors.canvasBase,
      onSurface: ObsidianFlowColors.onSurface,
      surfaceContainerHighest: ObsidianFlowColors.surfaceContainerHighest,
      onSurfaceVariant: ObsidianFlowColors.onSurfaceVariant,
      outline: ObsidianFlowColors.outline,
      outlineVariant: ObsidianFlowColors.outlineVariant,
      surfaceTint: ObsidianFlowColors.primaryFixedDim,
      inverseSurface: Color(0xFFE5E2E1),
      onInverseSurface: Color(0xFF313030),
      inversePrimary: Color(0xFF006D35),
    );

    final baseTextTheme = GoogleFonts.interTextTheme(
      ThemeData.dark().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: ObsidianFlowColors.canvasBase,
      colorScheme: colorScheme,
      dividerColor: ObsidianFlowColors.dividerBorder,
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 40,
          height: 48 / 40,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
          color: ObsidianFlowColors.textPrimary,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        displayMedium: GoogleFonts.inter(
          fontSize: 34, // currency-display
          height: 42 / 34,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.0,
          color: ObsidianFlowColors.textPrimary,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        headlineLarge: GoogleFonts.inter(
          fontSize: 28,
          height: 36 / 28,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.28,
          color: ObsidianFlowColors.onSurface,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 22,
          height: 28 / 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.22,
          color: ObsidianFlowColors.onSurface,
        ),
        headlineSmall: GoogleFonts.inter(
          fontSize: 18,
          height: 24 / 18,
          fontWeight: FontWeight.w600,
          color: ObsidianFlowColors.onSurface,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 16,
          height: 22 / 16,
          fontWeight: FontWeight.w600,
          color: ObsidianFlowColors.onSurface,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          height: 24 / 16,
          fontWeight: FontWeight.w400,
          color: ObsidianFlowColors.onSurface,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          height: 20 / 14,
          fontWeight: FontWeight.w400,
          color: ObsidianFlowColors.onSurface,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          height: 16 / 12,
          fontWeight: FontWeight.w400,
          color: ObsidianFlowColors.textSecondary,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          height: 18 / 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.14,
          color: ObsidianFlowColors.onSurface,
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 12,
          height: 16 / 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.24,
          color: ObsidianFlowColors.onSurfaceVariant,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 10,
          height: 14 / 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: ObsidianFlowColors.onSurfaceVariant,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: ObsidianFlowColors.surface,
        foregroundColor: ObsidianFlowColors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: ObsidianFlowColors.elevation1,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ObsidianFlowColors.primaryContainer,
          foregroundColor: ObsidianFlowColors.canvasBase,
          minimumSize: const Size.fromHeight(48),
          elevation: 0,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ObsidianFlowColors.elevation2,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: const TextStyle(color: ObsidianFlowColors.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: ObsidianFlowColors.primaryContainer,
            width: 1.5,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF181818),
        indicatorColor: ObsidianFlowColors.primaryContainer.withOpacity(0.18),
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: ObsidianFlowColors.primaryContainer,
            );
          }
          return GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: ObsidianFlowColors.textSecondary,
          );
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: ObsidianFlowColors.primaryContainer,
        foregroundColor: ObsidianFlowColors.canvasBase,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
