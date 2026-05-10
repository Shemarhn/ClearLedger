import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'constants.dart';

class AppTheme {
  static ThemeData get lightTheme => lightThemeFor();

  static ThemeData get darkTheme => darkThemeFor();

  static ThemeData lightThemeFor([
    ColorScheme? dynamicScheme,
    Color? seedColor,
  ]) {
    final textTheme = GoogleFonts.interTextTheme(ThemeData.light().textTheme);
    final scheme = _colorScheme(Brightness.light, dynamicScheme, seedColor);

    return _baseTheme(
      colorScheme: scheme,
      brightness: Brightness.light,
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      surface: scheme.surfaceContainerLowest,
      surfaceHigh: scheme.surfaceContainerHighest,
      stroke: scheme.outlineVariant,
      onSurface: scheme.onSurface,
      muted: scheme.onSurfaceVariant,
    );
  }

  static ThemeData darkThemeFor([
    ColorScheme? dynamicScheme,
    Color? seedColor,
  ]) {
    final textTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);
    final scheme = _colorScheme(Brightness.dark, dynamicScheme, seedColor);

    return _baseTheme(
      colorScheme: scheme,
      brightness: Brightness.dark,
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      surface: scheme.surfaceContainerLow,
      surfaceHigh: scheme.surfaceContainerHighest,
      stroke: scheme.outlineVariant,
      onSurface: scheme.onSurface,
      muted: scheme.onSurfaceVariant,
    );
  }

  static ColorScheme _colorScheme(
    Brightness brightness,
    ColorScheme? dynamicScheme,
    Color? seedColor,
  ) {
    final scheme = dynamicScheme ??
        ColorScheme.fromSeed(
          seedColor: seedColor ?? AppConstants.dynamicSeed,
          brightness: brightness,
        );

    if (brightness == Brightness.dark) {
      return scheme.copyWith(
        surface: const Color(0xFF101413),
        surfaceContainerLowest: const Color(0xFF0B0F0E),
        surfaceContainerLow: const Color(0xFF171C1A),
        surfaceContainer: const Color(0xFF1C2220),
        surfaceContainerHigh: const Color(0xFF232A27),
        surfaceContainerHighest: const Color(0xFF2C3430),
        outlineVariant: const Color(0xFF3E4944),
        error: AppConstants.errorRed,
      );
    }

    return scheme.copyWith(
      surface: const Color(0xFFF8FAF7),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFF2F5F1),
      surfaceContainer: const Color(0xFFEFF3EE),
      surfaceContainerHigh: const Color(0xFFE9EEE8),
      surfaceContainerHighest: const Color(0xFFE2E8E2),
      outlineVariant: const Color(0xFFD5DDD4),
      error: AppConstants.errorRed,
    );
  }

  static ThemeData _baseTheme({
    required ColorScheme colorScheme,
    required Brightness brightness,
    required TextTheme textTheme,
    required Color scaffoldBackgroundColor,
    required Color surface,
    required Color surfaceHigh,
    required Color stroke,
    required Color onSurface,
    required Color muted,
  }) {
    final accentText = colorScheme.primary;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      textTheme: textTheme,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
        foregroundColor: onSurface,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: onSurface,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: TextStyle(color: muted),
        hintStyle: TextStyle(color: muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: stroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: surfaceHigh,
          disabledForegroundColor: muted,
          elevation: 0,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          minimumSize: const Size.fromHeight(52),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          side: BorderSide(color: stroke),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          minimumSize: const Size.fromHeight(52),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentText,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        elevation: 0,
        height: 76,
        indicatorColor: colorScheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? accentText
                : muted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? accentText
                : muted,
            size: 28,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceHigh,
        selectedColor: colorScheme.primaryContainer,
        side: BorderSide(color: stroke),
        labelStyle: TextStyle(color: onSurface, fontWeight: FontWeight.w700),
        secondaryLabelStyle: TextStyle(color: onSurface, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.onPrimary
              : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.primary
              : surfaceHigh,
        ),
      ),
      dividerTheme: DividerThemeData(color: stroke, space: 24),
      drawerTheme: DrawerThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: muted,
        textColor: onSurface,
        titleTextStyle: TextStyle(color: onSurface, fontWeight: FontWeight.w800),
        subtitleTextStyle: TextStyle(color: muted),
      ),
    );
  }
}
