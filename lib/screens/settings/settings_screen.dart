import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants.dart';
import '../../services/api_service.dart';
import '../../services/app_settings_service.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_lock_service.dart';
import '../../services/exchange_rate_service.dart';
import '../../widgets/dark_shell.dart';
import '../auth/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _authService = AuthService();
  final _apiService = ApiService();
  final _biometricLockService = BiometricLockService.instance;
  final _settingsService = AppSettingsService.instance;
  final _exchangeRateService = ExchangeRateService();

  bool _exporting = false;
  bool _changingCurrency = false;
  bool _loadingBiometricSetting = true;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  ThemeMode _themeMode = ThemeMode.system;
  String _currency = 'JMD';
  String _accentThemeId = AppSettingsService.systemAccentThemeId;
  ExchangeRateSnapshot? _rateSnapshot;

  @override
  void initState() {
    super.initState();
    _loadBiometricSetting();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _settingsService.load();
    final snapshot = await _exchangeRateService.latestSnapshot(
      _settingsService.preferredCurrency,
    );
    if (!mounted) return;
    setState(() {
      _themeMode = _settingsService.themeMode;
      _currency = _settingsService.preferredCurrency;
      _accentThemeId = _settingsService.accentThemeId;
      _rateSnapshot = snapshot;
    });
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    await _settingsService.setThemeMode(mode);
  }

  Future<void> _setAccentTheme(String themeId) async {
    setState(() => _accentThemeId = themeId);
    await _settingsService.setAccentTheme(themeId);
  }

  Future<void> _setCurrency(String currency) async {
    if (_changingCurrency) return;
    final previous = _currency;
    setState(() => _currency = currency);
    try {
      setState(() => _changingCurrency = true);
      await _settingsService.setPreferredCurrency(currency);
      final snapshot = await _exchangeRateService.latestSnapshot(currency);
      if (!mounted) return;
      setState(() => _rateSnapshot = snapshot);
    } catch (error) {
      if (!mounted) return;
      setState(() => _currency = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not change preferred currency: $error')),
      );
    } finally {
      if (mounted) setState(() => _changingCurrency = false);
    }
  }

  Future<void> _loadBiometricSetting() async {
    final enabled = await _biometricLockService.isEnabled();
    bool available = false;
    try {
      available = await _biometricLockService.canUseBiometrics();
    } catch (_) {
      available = false;
    }

    if (!mounted) return;
    setState(() {
      _biometricEnabled = enabled && available;
      _biometricAvailable = available;
      _loadingBiometricSetting = false;
    });

    if (enabled && !available) {
      await _biometricLockService.setEnabled(false);
    }
  }

  Future<void> _setBiometricLock(bool enabled) async {
    if (_loadingBiometricSetting) return;

    setState(() => _loadingBiometricSetting = true);
    try {
      if (!enabled) {
        await _biometricLockService.setEnabled(false);
        if (!mounted) return;
        setState(() => _biometricEnabled = false);
        return;
      }

      final available = await _biometricLockService.canUseBiometrics();
      if (!available) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric unlock is not available on this device.')),
        );
        return;
      }

      final authenticated = await _biometricLockService.authenticate(
        reason: 'Enable biometric unlock for ClearLedger',
      );
      if (!authenticated) {
        return;
      }

      await _biometricLockService.setEnabled(true);
      if (!mounted) return;
      setState(() {
        _biometricAvailable = true;
        _biometricEnabled = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update biometric unlock: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingBiometricSetting = false);
    }
  }

  Future<void> _logout() async {
    await _authService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _export({required bool pdf}) async {
    setState(() => _exporting = true);
    try {
      final end = DateTime.now();
      final start = DateTime(end.year, end.month, 1);

      final bytes = pdf
          ? await _apiService.exportPdf(startDate: start, endDate: end)
          : await _apiService.exportCsv(startDate: start, endDate: end);

      final dir = await getTemporaryDirectory();
      final extension = pdf ? 'pdf' : 'csv';
      final file = File('${dir.path}/clearledger_export.$extension');
      await file.writeAsBytes(bytes);
      await OpenFilex.open(file.path);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export ready: ${file.path}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62);

    return Scaffold(
      body: DarkShell(
        child: ListView(
          children: [
            ScreenHeader(
              title: 'Settings',
              subtitle: 'Profile, appearance, exports, and security',
              glyph: AppGlyph.settings,
              trailing: IconButton.filledTonal(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back),
              ),
            ),
            const SizedBox(height: 18),
            FinanceCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const AppIconBadge(glyph: AppGlyph.accounts),
                title: Text(user?.email ?? 'No email'),
                subtitle: const Text('Profile & account'),
              ),
            ),
            const SizedBox(height: 12),
            FinanceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Appearance',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _themeChip(ThemeMode.system, Icons.phone_android, 'System'),
                      _themeChip(ThemeMode.light, Icons.light_mode_outlined, 'Light'),
                      _themeChip(ThemeMode.dark, Icons.dark_mode_outlined, 'Dark'),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Accent color',
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.70),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AppSettingsService.accentThemes
                        .map(_accentSwatch)
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FinanceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const AppIconBadge(glyph: AppGlyph.exchange, size: 42),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Currency',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _currency,
                    items: AppSettingsService.supportedCurrencies
                        .map((currency) => DropdownMenuItem(
                              value: currency,
                              child: Text(currency),
                            ))
                        .toList(),
                    onChanged: _changingCurrency ? null : (value) {
                      if (value != null) _setCurrency(value);
                    },
                    decoration: const InputDecoration(labelText: 'Preferred currency'),
                  ),
                  if (_changingCurrency) ...[
                    const SizedBox(height: 10),
                    const LinearProgressIndicator(),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    _rateSnapshot == null
                        ? 'Rates are fetched only when needed and cached once per day.'
                        : 'Last rate update: ${_rateSnapshot!.lastUpdatedUtc ?? 'unknown'}',
                    style: TextStyle(color: muted, height: 1.35),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Rates by ExchangeRate-API',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FinanceCard(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const AppIconBadge(glyph: AppGlyph.settings, size: 42),
                title: const Text('Biometric unlock'),
                subtitle: Text(
                  _biometricAvailable
                      ? 'Require fingerprint when returning to the app'
                      : 'Not available on this device',
                ),
                value: _biometricEnabled,
                onChanged: _loadingBiometricSetting || !_biometricAvailable
                    ? null
                    : _setBiometricLock,
              ),
            ),
            const SizedBox(height: 12),
            FinanceCard(
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const AppIconBadge(glyph: AppGlyph.document, size: 42),
                    title: const Text('Export PDF'),
                    subtitle: const Text('This month'),
                    onTap: _exporting ? null : () => _export(pdf: true),
                  ),
                  const Divider(height: 0),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const AppIconBadge(glyph: AppGlyph.ledger, size: 42),
                    title: const Text('Export CSV'),
                    subtitle: const Text('This month'),
                    onTap: _exporting ? null : () => _export(pdf: false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FinanceCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const AppIconBadge(
                  icon: Icons.logout,
                  color: AppConstants.errorRed,
                  size: 42,
                ),
                title: const Text('Logout', style: TextStyle(color: AppConstants.errorRed)),
                onTap: _logout,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _themeChip(ThemeMode mode, IconData icon, String label) {
    final selected = _themeMode == mode;
    return ChoiceChip(
      selected: selected,
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onSelected: (_) => _setThemeMode(mode),
    );
  }

  Widget _accentSwatch(AppAccentThemeOption option) {
    final selected = _accentThemeId == option.id;
    final scheme = Theme.of(context).colorScheme;
    final swatchColor =
        option.usesSystemColor ? scheme.primary : option.seedColor;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _setAccentTheme(option.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 102,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.18)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 1.7 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: swatchColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: scheme.onSurface.withValues(alpha: 0.12),
                ),
              ),
              child: option.usesSystemColor
                  ? Icon(
                      Icons.palette_outlined,
                      size: 13,
                      color: scheme.onPrimary,
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                option.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
