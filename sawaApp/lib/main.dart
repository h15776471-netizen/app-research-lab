import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Never crashes on missing config — see SupabaseConfig.tryInitialize.
  // Provider browsing works with no Supabase config at all.
  await SupabaseConfig.tryInitialize();

  runApp(const ProviderScope(child: SawaApp()));
}
