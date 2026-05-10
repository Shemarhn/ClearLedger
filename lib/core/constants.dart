import 'package:flutter/material.dart';

class AppConstants {
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL',
      defaultValue: 'http://10.0.2.2:8000');

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL',
      defaultValue: 'YOUR_SUPABASE_URL');
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'YOUR_SUPABASE_PUBLISHABLE_KEY',
  );

  // Categories match the backend schema
  static const List<String> categories = [
    'Food',
    'Transport',
    'Utilities',
    'Entertainment',
    'Healthcare',
    'Shopping',
    'Education',
    'Other'
  ];

  static const Map<String, IconData> categoryIcons = {
    'Food': Icons.restaurant,
    'Transport': Icons.directions_car,
    'Utilities': Icons.lightbulb,
    'Entertainment': Icons.movie,
    'Healthcare': Icons.local_hospital,
    'Shopping': Icons.shopping_bag,
    'Education': Icons.school,
    'Other': Icons.more_horiz,
  };

  static const Map<String, Color> categoryColors = {
    'Food': Color(0xFFFF9E7A),
    'Transport': Color(0xFF7CC7D7),
    'Utilities': Color(0xFFFFC857),
    'Entertainment': Color(0xFFA78BFA),
    'Healthcare': Color(0xFFFF7D8F),
    'Shopping': Color(0xFFFFB4D8),
    'Education': Color(0xFF8BE28B),
    'Other': Color(0xFFB9B3AA),
  };

  static const Color dynamicSeed = Color(0xFF006D75);
  static const Color primaryColor = Color(0xFF1B1B1F);
  static const Color accentColor = Color(0xFF00A98F);
  static const Color background = Color(0xFFF8FAF7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceHigh = Color(0xFFE2E8E2);
  static const Color lightStroke = Color(0xFFDDE2EA);
  static const Color darkBackground = Color(0xFF111318);
  static const Color darkSurface = Color(0xFF1B1B20);
  static const Color darkSurfaceHigh = Color(0xFF252A32);
  static const Color darkStroke = Color(0xFF3F4652);
  static const Color darkText = Color(0xFFE5E2E9);
  static const Color darkMuted = Color(0xFFC7C5D0);
  static const Color champagne = Color(0xFFFFDAD6);
  static const Color champagneHigh = Color(0xFFFFEDEA);
  static const Color champagneMuted = Color(0xFFB94742);
  static const Color mint = Color(0xFF00A98F);
  static const Color errorRed = Color(0xFFFF8B8B);
  static const Color successGreen = Color(0xFF6EE7A0);
  static const Color warningAmber = Color(0xFFFFC857);
}
