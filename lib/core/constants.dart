import 'package:flutter/material.dart';

class AppConstants {
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL',
      defaultValue: 'http://10.0.2.2:8000');

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL',
      defaultValue: 'YOUR_SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY',
      defaultValue: 'YOUR_SUPABASE_ANON_KEY');

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
    'Food': Color(0xFFE76F51),
    'Transport': Color(0xFF457B9D),
    'Utilities': Color(0xFFF4A261),
    'Entertainment': Color(0xFF2A9D8F),
    'Healthcare': Color(0xFFE63946),
    'Shopping': Color(0xFFB56576),
    'Education': Color(0xFF6A994E),
    'Other': Color(0xFF6C757D),
  };

  static const Color primaryColor = Color(0xFF073B4C);
  static const Color accentColor = Color(0xFF118AB2);
  static const Color background = Color(0xFFF4F7F5);
  static const Color surface = Colors.white;
  static const Color errorRed = Color(0xFFE63946);
  static const Color successGreen = Color(0xFF2A9D8F);
  static const Color warningAmber = Color(0xFFF4A261);
}
