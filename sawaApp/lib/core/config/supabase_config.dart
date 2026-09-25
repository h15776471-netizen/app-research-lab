import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads Supabase project config from --dart-define — never hardcoded,
/// never committed. Only the project URL and the publishable (anon) key are
/// ever used by the app; secret / service-role keys never belong here.
///
///   flutter run -d chrome \
///     --dart-define=SUPABASE_URL=https://<project>.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=<publishable key>
///
/// Without config the app still runs: browsing uses the bundled catalog
/// (assets/data/catalog.json — the same reviewed data that is seeded into
/// Supabase) and every write path shows an honest "not connected" state.
abstract final class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  /// True only after [tryInitialize] actually connected the client.
  static bool isInitialized = false;

  static Future<void> tryInitialize() async {
    if (!isConfigured) {
      debugPrint(
        'SupabaseConfig: SUPABASE_URL/SUPABASE_ANON_KEY not provided — '
        'running in offline catalog mode (browsing only).',
      );
      return;
    }
    try {
      await Supabase.initialize(url: url, publishableKey: anonKey);
      isInitialized = true;
    } catch (e) {
      debugPrint('SupabaseConfig: initialization failed — $e');
    }
  }
}
