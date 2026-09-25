import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/errors.dart';
import '../../../data/data_providers.dart';

sealed class ContactSubmitState {
  const ContactSubmitState();
}

class ContactIdle extends ContactSubmitState {
  const ContactIdle();
}

class ContactSubmitting extends ContactSubmitState {
  const ContactSubmitting();
}

class ContactSubmitted extends ContactSubmitState {
  const ContactSubmitted(this.referenceCode);
  final String referenceCode;
}

class ContactFailed extends ContactSubmitState {
  const ContactFailed(this.message);
  final String message;
}

/// One submission per screen instance. Success only on a real server
/// reference code — never a fake success.
final contactSubmitProvider =
    NotifierProvider.autoDispose<ContactSubmitNotifier, ContactSubmitState>(ContactSubmitNotifier.new);

class ContactSubmitNotifier extends AutoDisposeNotifier<ContactSubmitState> {
  @override
  ContactSubmitState build() => const ContactIdle();

  Future<void> submit({
    required String providerId,
    required String name,
    required String contact,
    String? message,
    String? serviceId,
  }) async {
    if (state is ContactSubmitting) return;
    state = const ContactSubmitting();
    try {
      final r = await ref.read(requestsRepositoryProvider).submitContactRequest(
            providerId: providerId,
            name: name,
            contact: contact,
            message: message,
            serviceId: serviceId,
          );
      state = ContactSubmitted(r.referenceCode);
    } catch (e) {
      state = ContactFailed(friendlyError(e));
    }
  }
}
