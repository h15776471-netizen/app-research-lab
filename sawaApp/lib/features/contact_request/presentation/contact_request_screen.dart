import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../state/contact_request_notifier.dart';

/// 3-field contact request form (name required, phone required, note optional).
///
/// Rules (Master Spec §13 Screen 4):
/// - Submit button disabled until both required fields are non-empty.
/// - Loading state inside the submit button (no separate spinner).
/// - Honest, retryable error state — never a false success.
/// - Provider phone number is never collected or displayed (locked rule).
/// - Local TextEditingControllers as plain widget state (not in the Notifier).
class ContactRequestScreen extends ConsumerStatefulWidget {
  const ContactRequestScreen({super.key, required this.providerId});

  final String providerId;

  @override
  ConsumerState<ContactRequestScreen> createState() =>
      _ContactRequestScreenState();
}

class _ContactRequestScreenState extends ConsumerState<ContactRequestScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _noteController = TextEditingController();

  bool _isFormValid = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onFieldChanged);
    _phoneController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    final valid = _nameController.text.trim().isNotEmpty &&
        _phoneController.text.trim().isNotEmpty;
    if (valid != _isFormValid) {
      setState(() => _isFormValid = valid);
    }
  }

  Future<void> _submit() async {
    await ref.read(contactRequestNotifierProvider.notifier).submit(
          providerId: widget.providerId,
          userName: _nameController.text,
          userContact: _phoneController.text,
          note: _noteController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    // Navigate to success screen when submission completes.
    ref.listen<ContactRequestState>(
      contactRequestNotifierProvider,
      (previous, next) {
        if (!(previous?.isSuccess ?? false) && next.isSuccess) {
          context.goNamed(AppRoute.contactSuccess);
        }
      },
    );

    final state = ref.watch(contactRequestNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('أرسل طلب تواصلك')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FormField(
              controller: _nameController,
              label: 'الاسم',
              hint: 'اسمك الكريم',
              keyboardType: TextInputType.name,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.md),
            _FormField(
              controller: _phoneController,
              label: 'وسيلة التواصل',
              hint: 'رقم هاتفك أو واتساب',
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.md),
            _FormField(
              controller: _noteController,
              label: 'ملاحظة (اختياري)',
              hint: 'تاريخ المناسبة، عدد الضيوف، أي تفاصيل تساعدنا…',
              maxLines: 3,
              textInputAction: TextInputAction.done,
            ),
            if (state.hasError) ...[
              const SizedBox(height: AppSpacing.md),
              _ErrorBanner(
                message: state.errorMessage!,
                onRetry: () {
                  ref
                      .read(contactRequestNotifierProvider.notifier)
                      .clearError();
                },
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            AppPrimaryButton(
              label: 'إرسال الطلب',
              onPressed: _isFormValid && !state.isSubmitting ? _submit : null,
              isLoading: state.isSubmitting,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'فريق sawa بيتواصل وياك بعد مراجعة الطلب.',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  const _FormField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.maxLines = 1,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final int maxLines;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.bodySmall),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          maxLines: maxLines,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            ),
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}
