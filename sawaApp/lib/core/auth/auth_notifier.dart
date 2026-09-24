import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_repository.dart';

@immutable
class AuthState {
  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
  });

  final AppUser? user;
  final bool isLoading;
  final String? error;

  bool get isAuthenticated => user != null;
  bool get isProvider => user?.role == UserRole.provider;
  bool get isCustomer => user?.role == UserRole.customer;
  bool get hasError => error != null;

  AuthState copyWith({AppUser? user, bool? isLoading, String? error}) =>
      AuthState(
        user: user ?? this.user,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

final authRepositoryProvider = Provider<AuthRepository>(
  (_) => AuthRepository(),
);

final authNotifierProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Restore session if Supabase is initialized
    _restoreSession();
    return const AuthState(isLoading: true);
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> _restoreSession() async {
    try {
      final user = await _repo.fetchAppUser();
      state = AuthState(user: user);
    } catch (e) {
      debugPrint('AuthNotifier._restoreSession: $e');
      state = const AuthState();
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
  }) async {
    state = const AuthState(isLoading: true);
    try {
      final user = await _repo.signUp(
        email: email,
        password: password,
        displayName: displayName,
        role: role,
      );
      state = AuthState(user: user);
    } catch (e) {
      state = AuthState(error: _message(e));
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AuthState(isLoading: true);
    try {
      final user = await _repo.signIn(email: email, password: password);
      state = AuthState(user: user);
    } catch (e) {
      state = AuthState(error: _message(e));
    }
  }

  Future<void> signOut() async {
    try {
      await _repo.signOut();
    } catch (_) {}
    state = const AuthState();
  }

  void clearError() => state = AuthState(user: state.user);

  String _message(Object e) {
    if (e is AuthException) return e.message;
    return 'حدث خطأ غير متوقع، حاول مرة ثانية.';
  }
}
