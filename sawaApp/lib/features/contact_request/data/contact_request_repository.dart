import 'package:supabase_flutter/supabase_flutter.dart';

import 'contact_request_model.dart';

/// Insert-only submission of a [ContactRequest] to Supabase.
///
/// Skill Module 6 hard rules: client access is insert-only — no read,
/// update, or delete from the client, ever. RLS must enforce this on the
/// real project, not just be assumed from this code.
///
/// The SupabaseClient is resolved lazily on first [submit] call so that
/// constructing this repository never throws if Supabase was not initialized
/// (e.g., no --dart-define config provided). Provider browsing remains fully
/// functional; only the contact submission path depends on Supabase.
class ContactRequestRepository {
  ContactRequestRepository({SupabaseClient? client}) : _overrideClient = client;

  final SupabaseClient? _overrideClient;

  // Deferred access: throws StateError at submit-time (not construct-time)
  // when Supabase was not initialized — caught by ContactRequestNotifier.
  SupabaseClient get _client => _overrideClient ?? Supabase.instance.client;

  static const table = 'contact_requests';

  /// Insert-only. Throws on failure — callers must show an honest error
  /// state, never a false success (Skill Module 6 anti-pattern).
  Future<void> submit(ContactRequest request) async {
    await _client.from(table).insert(request.toJson());
  }
}
