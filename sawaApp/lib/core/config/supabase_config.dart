import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads Supabase project config from --dart-define (or a local .env via
/// your run/build tooling) — never hardcoded, never committed.
///
/// Technical Architecture §14 / Skill Module 6.
///
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=xxxx
///
/// See .env.example at the repo root.
abstract final class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  /// Initializes Supabase only when real config was actually provided.
  /// Deliberately never throws/crashes on missing config: provider browsing
  /// must keep working fully offline regardless of Supabase state
  /// (Skill Module 9 — "offline browsing"). Only the Contact Request
  /// submission path depends on this having run successfully.
  ///
  /// NOT YET VERIFIED against a real Supabase project or RLS policy from
  /// this environment — see the Phase 1 report's Blockers section. This is
  /// the Skill's "Phase 1.5 RLS smoke test" and must happen before the
  /// Contact Request screen is wired to [ContactRequestRepository].
  static Future<void> tryInitialize() async {
    if (!isConfigured) {
      debugPrint(
        'SupabaseConfig: SUPABASE_URL/SUPABASE_ANON_KEY were not provided — '
        'Supabase is NOT initialized. Provider browsing still works; the '
        'Contact Request flow will not be able to submit until this is '
        'configured (see .env.example).',
      );
      return;
    }
    await Supabase.initialize(url: url, anonKey: anonKey);
  }
}
