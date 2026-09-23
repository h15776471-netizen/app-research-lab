import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../data/contact_request_model.dart';
import '../data/contact_request_repository.dart';

/// Simple flat state — four meaningful conditions, no boolean soup.
@immutable
class ContactRequestState {
  const ContactRequestState({
    this.isSubmitting = false,
    this.isSuccess = false,
    this.errorMessage,
  });

  final bool isSubmitting;
  final bool isSuccess;
  final String? errorMessage;

  bool get hasError => errorMessage != null;
}

/// Repository provider — lazy; ContactRequestRepository only accesses
/// Supabase.instance.client at submit-time, so no crash when Supabase is
/// not configured (contact browsing remains fully functional offline).
final contactRequestRepositoryProvider = Provider<ContactRequestRepository>(
  (ref) => ContactRequestRepository(),
);

/// AutoDispose: the state is reset automatically when the Contact Request
/// screen is popped, preventing a "success" state leaking across sessions.
final contactRequestNotifierProvider =
    NotifierProvider.autoDispose<ContactRequestNotifier, ContactRequestState>(
  ContactRequestNotifier.new,
);

class ContactRequestNotifier extends AutoDisposeNotifier<ContactRequestState> {
  @override
  ContactRequestState build() => const ContactRequestState();

  Future<void> submit({
    required String providerId,
    required String userName,
    required String userContact,
    String? note,
  }) async {
    if (state.isSubmitting) return;
    state = const ContactRequestState(isSubmitting: true);

    try {
      final request = ContactRequest(
        providerId: providerId,
        userName: userName.trim(),
        userContact: userContact.trim(),
        note: (note != null && note.trim().isNotEmpty) ? note.trim() : null,
        createdAt: DateTime.now().toUtc(),
      );
      final repo = ref.read(contactRequestRepositoryProvider);
      await repo.submit(request);
      state = const ContactRequestState(isSuccess: true);
    } catch (_) {
      state = const ContactRequestState(
        errorMessage: AppStrings.contactSubmitError,
      );
    }
  }

  void clearError() {
    if (state.hasError) {
      state = const ContactRequestState();
    }
  }
}
