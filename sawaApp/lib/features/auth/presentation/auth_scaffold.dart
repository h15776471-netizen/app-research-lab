import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/ui.dart';

/// Shared, centered layout for login / sign-up / reset.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(title, style: AppTextStyles.h1),
                const SizedBox(height: 6),
                Text(subtitle, style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 24),
                SurfaceCard(padding: const EdgeInsets.all(20), child: child),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class FormMessage extends StatelessWidget {
  const FormMessage({super.key, required this.text, this.isError = true});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final c = isError ? AppColors.error : AppColors.success;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? AppColors.errorLight : AppColors.successLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.mark_email_read_outlined, color: c, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: AppTextStyles.bodySmall.copyWith(color: c))),
      ]),
    );
  }
}

String? validateEmail(String? v) {
  final t = v?.trim() ?? '';
  if (t.isEmpty) return 'يرجى إدخال البريد الإلكتروني';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) return 'البريد الإلكتروني غير صحيح';
  return null;
}
