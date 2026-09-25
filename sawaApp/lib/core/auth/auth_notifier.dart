import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../data/data_providers.dart';
import '../../data/models/account_models.dart';
import '../utils/errors.dart';

@immutable
class AuthState {
  const AuthState({this.user, this.isLoading = false, this.error, this.info});

  final AppUser? user;
  final bool isLoading;
  final String? error;

  /// Non-error notice, e.g. "check your e-mail to confirm".
  final String? info;

  bool get isAuthenticated => user != null;
  bool get isProvider => user?.role == UserRole.provider;
  bool get isCustomer => user != null && user!.role != UserRole.provider;
}

final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

/// Session state. UI role checks here are for navigation only — every
/// permission is enforced by Postgres RLS / triggers.
class AuthNotifier extends Notifier<AuthState> {
  StreamSubscription<sb.AuthState>? _sub;

  @override
  AuthState build() {
    final repo = ref.watch(authRepositoryProvider);
    ref.onDispose(() => _sub?.cancel());
    if (!repo.isAvailable) return const AuthState();

    _sub = repo.authStateChanges.listen((event) {
      if (event.event == sb.AuthChangeEvent.signedOut) {
        state = const AuthState();
      } else if (event.event == sb.AuthChangeEvent.userUpdated || event.event == sb.AuthChangeEvent.tokenRefreshed) {
        _refresh();
      }
    });
    Future.microtask(_restore);
    return const AuthState(isLoading: true);
  }

  Future<void> _restore() async {
    try {
      state = AuthState(user: await ref.read(authRepositoryProvider).currentUser());
    } catch (e) {
      debugPrint('AuthNotifier.restore: $e');
      state = const AuthState();
    }
  }

  Future<void> _refresh() async {
    try {
      final u = await ref.read(authRepositoryProvider).currentUser();
      state = AuthState(user: u);
    } catch (_) {}
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    String? phone,
  }) async {
    state = const AuthState(isLoading: true);
    try {
      final r = await ref
          .read(authRepositoryProvider)
          .signUp(email: email, password: password, fullName: fullName, role: role, phone: phone);
      if (r.needsEmailConfirmation) {
        state = const AuthState(info: 'أرسلنا رابط تأكيد إلى بريدك. أكّد البريد ثم سجّل الدخول.');
        return false;
      }
      state = AuthState(user: r.user);
      return r.user != null;
    } catch (e) {
      state = AuthState(error: friendlyError(e));
      return false;
    }
  }

  Future<bool> signIn({required String email, required String password}) async {
    state = const AuthState(isLoading: true);
    try {
      final u = await ref.read(authRepositoryProvider).signIn(email: email, password: password);
      state = AuthState(user: u);
      return u != null;
    } catch (e) {
      state = AuthState(error: friendlyError(e));
      return false;
    }
  }

  Future<String?> sendPasswordReset(String email) async {
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
      return null;
    } catch (e) {
      return friendlyError(e);
    }
  }

  Future<String?> updateProfile({String? fullName, String? phone}) async {
    final u = state.user;
    if (u == null) return 'سجّل الدخول أولاً.';
    try {
      await ref.read(authRepositoryProvider).updateProfile(userId: u.id, fullName: fullName, phone: phone);
      await _refresh();
      return null;
    } catch (e) {
      return friendlyError(e);
    }
  }

  Future<void> signOut() async {
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (_) {}
    state = const AuthState();
  }

  void clearMessages() => state = AuthState(user: state.user);
}
