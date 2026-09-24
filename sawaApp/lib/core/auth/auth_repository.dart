import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum UserRole { customer, provider }

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.role,
    this.displayName,
  });

  final String id;
  final String email;
  final UserRole role;
  final String? displayName;
}

class AuthRepository {
  AuthRepository({SupabaseClient? client}) : _override = client;

  final SupabaseClient? _override;
  SupabaseClient get _client => _override ?? Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<AppUser?> fetchAppUser() async {
    final user = currentUser;
    if (user == null) return null;
    try {
      final data = await _client
          .from('profiles')
          .select('role, display_name')
          .eq('id', user.id)
          .maybeSingle();
      if (data == null) return null;
      final role = (data['role'] as String?) == 'provider'
          ? UserRole.provider
          : UserRole.customer;
      return AppUser(
        id: user.id,
        email: user.email ?? '',
        role: role,
        displayName: data['display_name'] as String?,
      );
    } catch (e) {
      debugPrint('AuthRepository.fetchAppUser: $e');
      return null;
    }
  }

  Future<AppUser> signUp({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
  }) async {
    final res = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName, 'role': role.name},
    );
    final user = res.user;
    if (user == null) throw Exception('Sign-up failed: no user returned');

    // Upsert profile (trigger may already have created it)
    await _client.from('profiles').upsert({
      'id': user.id,
      'role': role.name,
      'display_name': displayName,
    });

    return AppUser(
      id: user.id,
      email: email,
      role: role,
      displayName: displayName,
    );
  }

  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final res = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = res.user;
    if (user == null) throw Exception('Sign-in failed');
    return fetchAppUser().then((u) =>
        u ??
        AppUser(
          id: user.id,
          email: email,
          role: UserRole.customer,
        ));
  }

  Future<void> signOut() => _client.auth.signOut();
}
