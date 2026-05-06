import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricLockService {
  BiometricLockService._();
  static final BiometricLockService instance = BiometricLockService._();

  static const _enabledKey = 'biometric_lock_enabled';
  final LocalAuthentication _localAuth = LocalAuthentication();
  DateTime? _unlockCooldownUntil;

  bool get isUnlockCoolingDown {
    final cooldownUntil = _unlockCooldownUntil;
    return cooldownUntil != null && DateTime.now().isBefore(cooldownUntil);
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  Future<bool> canUseBiometrics() async {
    final supported = await _localAuth.isDeviceSupported();
    final canCheck = await _localAuth.canCheckBiometrics;
    return supported && canCheck;
  }

  Future<bool> authenticate({String reason = 'Unlock ClearLedger'}) async {
    final authenticated = await _localAuth.authenticate(
      localizedReason: reason,
      biometricOnly: true,
    );
    if (authenticated) {
      _unlockCooldownUntil = DateTime.now().add(const Duration(seconds: 3));
    }
    return authenticated;
  }
}
