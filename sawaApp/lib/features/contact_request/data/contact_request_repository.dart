import 'package:supabase_flutter/supabase_flutter.dart';

import 'contact_request_model.dart';

/// Insert-only submission of a [ContactRequest] to Supabase.
///
/// Skill Module 6 hard rules: client access is insert-only — no read,
/// update, or delete from the client, ever. RLS must enforce this on the
/// real project, not just be assumed from this code.
///
/// PHASE 1 STATUS: this is foundation only.
///   - NOT yet wired to any UI/Notifier (Contact Request screen still a
///     placeholder — see Phase 1 report).
///   - The Supabase project + RLS policy have NOT been verified from this
///     environment (no network / no live project access here). Per the
///     Skill's Appendix A, a throwaway insert-only smoke test against the
///     real project ("Phase 1.5") must happen and pass before this class
///     is trusted by the real Contact Request screen.
///   - The Google Form fallback (Technical Architecture §8 Option B) is
///     not implemented here; only add it if Supabase can't be made
///     reliable in time.
class ContactRequestRepository {
  ContactRequestRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const table = 'contact_requests';

  /// Insert-only. Throws on failure — callers (the future submission
  /// Notifier) must show an honest error state, never a false success
  /// (Skill Module 6 anti-pattern: "A submission flow that shows the
  /// success screen optimistically before the insert is confirmed").
  Future<void> submit(ContactRequest request) async {
    await _client.from(table).insert(request.toJson());
  }
}
