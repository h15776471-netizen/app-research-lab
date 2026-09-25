import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/errors.dart';
import '../models/account_models.dart';

/// Result of a sign-up: either signed in, or waiting for e-mail
/// confirmation (when "Confirm email" is enabled in Supabase Auth).
class SignUpResult {
  const SignUpResult({this.user, this.needsEmailConfirmation = false});
  final AppUser? user;
  final bool needsEmailConfirmation;
}

/// Supabase Auth + `public.profiles`.
///
/// The role is chosen at sign-up (`customer` | `provider`) and written by the
/// database trigger from the sign-up metadata — the client never writes
/// `profiles.role` (a guard trigger rejects it) and `admin` can never be
/// self-assigned.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient? _client;

  SupabaseClient get _c => _client ?? (throw const BackendUnavailable());

  bool get isAvailable => _client != null;

  Stream<AuthState> get authStateChanges => _client?.auth.onAuthStateChange ?? const Stream.empty();

  Future<AppUser?> currentUser() async {
    final c = _client;
    final user = c?.auth.currentUser;
    if (c == null || user == null) return null;
    final row = await c.from('profiles').select('id, role, full_name, phone, email').eq('id', user.id).maybeSingle();
    return AppUser(
      id: user.id,
      email: user.email ?? (row?['email'] as String? ?? ''),
      role: UserRole.parse(row?['role'] as String? ?? user.userMetadata?['role'] as String?),
      fullName: row?['full_name'] as String? ?? user.userMetadata?['full_name'] as String?,
      phone: row?['phone'] as String?,
    );
  }

  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    String? phone,
  }) async {
    assert(role != UserRole.admin);
    final res = await _c.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'full_name': fullName.trim(),
        'role': role.name,
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      },
    );
    if (res.session == null) {
      return const SignUpResult(needsEmailConfirmation: true);
    }
    return SignUpResult(user: await currentUser());
  }

  Future<AppUser?> signIn({required String email, required String password}) async {
    await _c.auth.signInWithPassword(email: email.trim(), password: password);
    return currentUser();
  }

  Future<void> sendPasswordReset(String email) => _c.auth.resetPasswordForEmail(email.trim());

  Future<void> updateProfile({required String userId, String? fullName, String? phone}) async {
    await _c.from('profiles').update({
      'full_name': (fullName == null || fullName.trim().isEmpty) ? null : fullName.trim(),
      'phone': (phone == null || phone.trim().isEmpty) ? null : phone.trim(),
    }).eq('id', userId);
  }

  Future<void> signOut() async {
    if (_client != null) await _client.auth.signOut();
  }
}
