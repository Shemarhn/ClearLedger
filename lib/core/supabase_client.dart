import 'package:supabase_flutter/supabase_flutter.dart';
import 'constants.dart';

class SupabaseHelper {
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabasePublishableKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}

SupabaseClient get supabase => SupabaseHelper.client;
