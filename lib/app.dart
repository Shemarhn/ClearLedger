import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'services/auth_service.dart';
import 'services/biometric_lock_service.dart';

class ClearLedgerApp extends StatefulWidget {
  const ClearLedgerApp({super.key});

  @override
  State<ClearLedgerApp> createState() => _ClearLedgerAppState();
}

class _ClearLedgerAppState extends State<ClearLedgerApp> with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  final BiometricLockService _biometricLockService = BiometricLockService.instance;
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_authService.isLoggedIn) {
        _authenticateOnResume();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _authService.isLoggedIn) {
      _authenticateOnResume();
    }
  }

  Future<void> _authenticateOnResume() async {
    if (_authenticating || _biometricLockService.isUnlockCoolingDown) {
      return;
    }

    _authenticating = true;
    try {
      final enabled = await _biometricLockService.isEnabled();
      if (!enabled) {
        return;
      }

      final canUseBiometrics = await _biometricLockService.canUseBiometrics();
      if (!canUseBiometrics) {
        return;
      }

      final authenticated = await _biometricLockService.authenticate();

      if (!authenticated && mounted) {
        await _authService.signOut();
        setState(() {});
      }
    } catch (_) {
      // Keep UX resilient if biometric APIs are unavailable.
    } finally {
      _authenticating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ClearLedger',
      theme: AppTheme.lightTheme,
      home: StreamBuilder(
        stream: _authService.authStateChanges,
        builder: (context, snapshot) {
          if (_authService.isLoggedIn) {
            return const HomeScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
