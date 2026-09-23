import 'package:flutter/material.dart';

import '../constants/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_button.dart';

/// Honest failure state — always offers a retry, never a dead end and
/// never a silent hang (Skill Module 6/9). Never render success copy here.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    this.message = AppStrings.contactSubmitError,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 32),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppSecondaryButton(label: 'إعادة المحاولة', onPressed: onRetry),
            ],
          ],
        ),
      ),
    );
  }
}
