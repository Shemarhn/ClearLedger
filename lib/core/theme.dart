import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'constants.dart';

class AppTheme {
  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.interTextTheme(ThemeData.light().textTheme);

    return _baseTheme(
      brightness: Brightness.light,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppConstants.background,
      surface: AppConstants.surface,
      surfaceHigh: const Color(0xFFF0F5F2),
      stroke: const Color(0xFFDCE6E1),
      onSurface: const Color(0xFF17211E),
      muted: const Color(0xFF66756F),
    );
  }

  static ThemeData get darkTheme {
    final textTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

    return _baseTheme(
      brightness: Brightness.dark,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppConstants.darkBackground,
      surface: AppConstants.darkSurface,
      surfaceHigh: AppConstants.darkSurfaceHigh,
      stroke: AppConstants.darkStroke,
      onSurface: AppConstants.darkText,
      muted: AppConstants.darkMuted,
    );
  }

  static ThemeData _baseTheme({
    required Brightness brightness,
    required TextTheme textTheme,
    required Color scaffoldBackgroundColor,
    required Color surface,
    required Color surfaceHigh,
    required Color stroke,
    required Color onSurface,
    required Color muted,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      textTheme: textTheme,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppConstants.mint,
        brightness: brightness,
      ).copyWith(
        primary: AppConstants.mint,
        secondary: AppConstants.successGreen,
        surface: surface,
        error: AppConstants.errorRed,
        onSurface: onSurface,
      ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHigh,
        labelStyle: TextStyle(color: muted),
        hintStyle: TextStyle(color: muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: stroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppConstants.mint),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConstants.mint,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          minimumSize: const Size.fromHeight(48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          side: BorderSide(color: stroke),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          minimumSize: const Size.fromHeight(48),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: AppConstants.mint.withValues(alpha: 0.16),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? AppConstants.mint
                : AppConstants.darkMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppConstants.mint
                : AppConstants.darkMuted,
          ),
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: muted,
        textColor: onSurface,
      ),
    );
  }
}
