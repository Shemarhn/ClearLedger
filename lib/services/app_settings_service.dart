import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/supabase_client.dart';

class AppSettingsService extends ChangeNotifier {
  AppSettingsService._();

  static final AppSettingsService instance = AppSettingsService._();

  static const supportedCurrencies = [
    'JMD',
    'USD',
    'EUR',
    'GBP',
    'CAD',
    'AUD',
    'MXN',
    'TTD',
    'BBD',
    'KYD',
    'XCD',
    'JPY',
    'CHF',
  ];

  static const _themeKey = 'app_theme_mode';
  static const _currencyKey = 'preferred_currency';

  ThemeMode _themeMode = ThemeMode.dark;
  String _preferredCurrency = 'JMD';
  bool _loaded = false;
  String? _profileLoadedUserId;

  ThemeMode get themeMode => _themeMode;
  String get preferredCurrency => _preferredCurrency;
  bool get loaded => _loaded;

  Future<void> load() async {
    final user = supabase.auth.currentUser;
    if (_loaded && _profileLoadedUserId == user?.id) return;

    final prefs = await SharedPreferences.getInstance();
    if (!_loaded) {
      _themeMode = _themeModeFromString(prefs.getString(_themeKey)) ?? ThemeMode.dark;
      _preferredCurrency = _normalizeCurrency(prefs.getString(_currencyKey)) ?? 'JMD';
    }

    if (user != null) {
      try {
        final profile = await supabase
            .from('profiles')
            .select('currency')
            .eq('id', user.id)
            .maybeSingle();
        final profileCurrency = _normalizeCurrency(profile?['currency'] as String?);
        if (profileCurrency != null) {
          _preferredCurrency = profileCurrency;
          await prefs.setString(_currencyKey, profileCurrency);
        }
        _profileLoadedUserId = user.id;
      } catch (_) {
        // Local preferences still keep the app usable if profile sync is unavailable.
      }
    } else {
      _profileLoadedUserId = null;
    }

    _loaded = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await load();
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, _themeModeToString(mode));
    notifyListeners();
  }

  Future<void> setPreferredCurrency(String currency) async {
    await load();
    final normalized = _normalizeCurrency(currency);
    if (normalized == null) {
      throw Exception('Unsupported currency: $currency');
    }

    _preferredCurrency = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currencyKey, normalized);
    notifyListeners();

    final user = supabase.auth.currentUser;
    if (user != null) {
      try {
        await supabase
            .from('profiles')
            .update({'currency': normalized})
            .eq('id', user.id);
      } catch (_) {
        // Keep the local setting even if the profile row is temporarily unavailable.
      }
    }
  }

  ThemeMode? _themeModeFromString(String? value) {
    switch (value) {
      case 'system':
        return ThemeMode.system;
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return null;
    }
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'system';
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
    }
  }

  String? _normalizeCurrency(String? currency) {
    final normalized = currency?.trim().toUpperCase();
    if (normalized == null || !supportedCurrencies.contains(normalized)) {
      return null;
    }
    return normalized;
  }
}
