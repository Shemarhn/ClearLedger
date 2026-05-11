import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../core/supabase_client.dart';
import 'app_refresh_service.dart';
import 'budget_service.dart';
import 'transaction_service.dart';

class AppAccentThemeOption {
  const AppAccentThemeOption({
    required this.id,
    required this.label,
    required this.seedColor,
    this.usesSystemColor = false,
  });

  final String id;
  final String label;
  final Color seedColor;
  final bool usesSystemColor;
}

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
  static const _accentThemeKey = 'accent_theme_id';
  static const systemAccentThemeId = 'system';

  static const accentThemes = [
    AppAccentThemeOption(
      id: systemAccentThemeId,
      label: 'System',
      seedColor: AppConstants.dynamicSeed,
      usesSystemColor: true,
    ),
    AppAccentThemeOption(
      id: 'mint',
      label: 'Mint',
      seedColor: Color(0xFF00A98F),
    ),
    AppAccentThemeOption(
      id: 'graphite',
      label: 'Graphite',
      seedColor: Color(0xFF2E3A46),
    ),
    AppAccentThemeOption(
      id: 'violet',
      label: 'Violet',
      seedColor: Color(0xFF6750A4),
    ),
    AppAccentThemeOption(
      id: 'sky',
      label: 'Sky',
      seedColor: Color(0xFF006DCC),
    ),
    AppAccentThemeOption(
      id: 'rose',
      label: 'Rose',
      seedColor: Color(0xFFB94742),
    ),
  ];

  ThemeMode _themeMode = ThemeMode.system;
  String _preferredCurrency = 'JMD';
  String _accentThemeId = systemAccentThemeId;
  bool _loaded = false;
  String? _profileLoadedUserId;

  ThemeMode get themeMode => _themeMode;
  String get preferredCurrency => _preferredCurrency;
  String get accentThemeId => _accentThemeId;
  AppAccentThemeOption get accentTheme =>
      accentThemes.firstWhere((theme) => theme.id == _accentThemeId);
  Color get accentSeedColor => accentTheme.seedColor;
  bool get usesSystemAccent => accentTheme.usesSystemColor;
  bool get loaded => _loaded;

  Future<void> load() async {
    final user = supabase.auth.currentUser;
    if (_loaded && _profileLoadedUserId == user?.id) return;

    final prefs = await SharedPreferences.getInstance();
    if (!_loaded) {
      _themeMode = _themeModeFromString(prefs.getString(_themeKey)) ?? ThemeMode.system;
      _preferredCurrency = _normalizeCurrency(prefs.getString(_currencyKey)) ?? 'JMD';
      _accentThemeId =
          _normalizeAccentTheme(prefs.getString(_accentThemeKey)) ?? systemAccentThemeId;
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

  Future<void> setAccentTheme(String themeId) async {
    await load();
    final normalized = _normalizeAccentTheme(themeId);
    if (normalized == null) {
      throw Exception('Unsupported theme: $themeId');
    }

    _accentThemeId = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accentThemeKey, normalized);
    notifyListeners();
  }

  Future<void> setPreferredCurrency(String currency) async {
    await load();
    final normalized = _normalizeCurrency(currency);
    if (normalized == null) {
      throw Exception('Unsupported currency: $currency');
    }
    final previousCurrency = _preferredCurrency;
    if (previousCurrency != normalized) {
      await TransactionService().convertUserTransactionsCurrency(
        normalized,
        notify: false,
      );
      await BudgetService().convertUserBudgetsCurrency(
        fromCurrency: previousCurrency,
        toCurrency: normalized,
        notify: false,
      );
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
    if (previousCurrency != normalized) {
      AppRefreshService.instance.transactionsChanged();
      AppRefreshService.instance.budgetsChanged();
      AppRefreshService.instance.accountsChanged();
    }
    AppRefreshService.instance.settingsChanged();
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

  String? _normalizeAccentTheme(String? themeId) {
    final normalized = themeId?.trim().toLowerCase();
    if (normalized == null ||
        !accentThemes.any((theme) => theme.id == normalized)) {
      return null;
    }
    return normalized;
  }

  String? _normalizeCurrency(String? currency) {
    final normalized = currency?.trim().toUpperCase();
    if (normalized == null || !supportedCurrencies.contains(normalized)) {
      return null;
    }
    return normalized;
  }
}
