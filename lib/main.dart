import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/supabase_client.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseHelper.initialize();

  final firebaseReady = await _tryInitializeFirebase();
  try {
    await NotificationService.instance.initialize(enablePush: firebaseReady);
  } catch (error) {
    debugPrint('ClearLedger notifications disabled: $error');
  }

  runApp(const ClearLedgerApp());
}

Future<bool> _tryInitializeFirebase() async {
  try {
    await Firebase.initializeApp();
    return true;
  } catch (error) {
    debugPrint('ClearLedger Firebase disabled: $error');
    return false;
  }
}
