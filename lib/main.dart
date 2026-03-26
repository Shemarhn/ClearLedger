import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/supabase_client.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseHelper.initialize();
  await Firebase.initializeApp();
  await NotificationService.instance.initialize();
  runApp(const ClearLedgerApp());
}
