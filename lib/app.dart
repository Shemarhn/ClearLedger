import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import 'core/theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'services/auth_service.dart';

class ClearLedgerApp extends StatefulWidget {
  const ClearLedgerApp({super.key});

  @override
  State<ClearLedgerApp> createState() => _ClearLedgerAppState();
}

class _ClearLedgerAppState extends State<ClearLedgerApp> with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) {
        return;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Unlock ClearLedger',
        options: const AuthenticationOptions(biometricOnly: true),
      );

      if (!authenticated && mounted) {
        await _authService.signOut();
        setState(() {});
      }
    } catch (_) {
      // Keep UX resilient if biometric APIs are unavailable.
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
