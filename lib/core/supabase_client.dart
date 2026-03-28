import 'package:supabase_flutter/supabase_flutter.dart';
import 'constants.dart';

class SupabaseHelper {
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}

final supabase = SupabaseHelper.client;
