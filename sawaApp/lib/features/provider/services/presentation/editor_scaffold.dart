import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/ui.dart';
import '../../../../data/data_providers.dart';
import '../../../../data/models/catalog_models.dart';
import '../../state/portal_providers.dart';
import '../../widgets/portal_widgets.dart';

/// Loads the provider's business and hands it to an editor form.
class BusinessEditorGate extends ConsumerWidget {
  const BusinessEditorGate({super.key, required this.title, required this.builder});

  final String title;
  final Widget Function(SawaProvider business) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(providerPortalRepositoryProvider).isAvailable) {
      return Scaffold(appBar: AppBar(title: Text(title)), body: const PortalOffline());
    }
    final b = ref.watch(myBusinessProvider);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: b.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const NoBusinessYet(),
        data: (business) => business == null ? const NoBusinessYet() : builder(business),
      ),
    );
  }
}

class EditorBody extends StatelessWidget {
  const EditorBody(
      {super.key, required this.formKey, required this.children, required this.onSave, required this.busy, this.error});

  final GlobalKey<FormState> formKey;
  final List<Widget> children;
  final VoidCallback onSave;
  final bool busy;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        ContentFrame(
          maxWidth: 640,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (error != null) ...[
              InfoBanner(message: error!, color: AppColors.error, icon: Icons.error_outline),
              const SizedBox(height: 14),
            ],
            ...children,
            const SizedBox(height: 20),
            AppPrimaryButton(label: 'حفظ', isLoading: busy, onPressed: onSave),
          ]),
        ),
      ]),
    );
  }
}

double? parseMoney(String s) => s.trim().isEmpty ? null : double.tryParse(normalizePhone(s).replaceAll(',', ''));

String? validateMoney(String? v) {
  if (v == null || v.trim().isEmpty) return null;
  final d = parseMoney(v);
  return (d == null || d < 0) ? 'رقم غير صحيح' : null;
}

String moneyText(double? v) => v == null ? '' : v.round().toString();
