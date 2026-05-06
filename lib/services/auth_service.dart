import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';
import '../models/profile.dart';
import 'notification_service.dart';

class AuthService {
  User? get currentUser => supabase.auth.currentUser;

  bool get isLoggedIn => currentUser != null;

  // Sign up
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    await supabase.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
    await NotificationService.instance.syncPushToken();
  }

  // Log in
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    await NotificationService.instance.syncPushToken();
  }

  // Sign out
  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    await supabase.auth.resetPasswordForEmail(email);
  }

  // Stream auth state changes
  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;

  // Get current user profile
  Future<ProfileModel?> getCurrentProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;

    final response = await supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (response == null) return null;
    return ProfileModel.fromJson(response);
  }
}
