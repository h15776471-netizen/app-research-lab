import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/errors.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/ui.dart';
import '../../../data/models/catalog_models.dart';

/// Shown on portal tabs before the business exists.
class NoBusinessYet extends StatelessWidget {
  const NoBusinessYet({super.key});

  @override
  Widget build(BuildContext context) => EmptyStateView(
        icon: Icons.storefront_outlined,
        title: 'ابدأ بإنشاء ملفك التجاري',
        message: 'اختر فئة خدمتك وأضف معلوماتك، ثم أرسل الملف لمراجعة فريق SAWA قبل النشر.',
        actionLabel: 'إنشاء الملف التجاري',
        action: () => context.pushNamed(AppRoute.providerOnboarding),
      );
}

class PortalOffline extends StatelessWidget {
  const PortalOffline({super.key});

  @override
  Widget build(BuildContext context) => const EmptyStateView(
        icon: Icons.cloud_off_outlined,
        title: 'غير متصل',
        message: offlineMessage,
      );
}

/// Listing status banner with the honest meaning of each state.
class ListingStatusBanner extends StatelessWidget {
  const ListingStatusBanner({super.key, required this.status, this.action});

  final ListingStatus status;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final (color, icon, text) = switch (status) {
      ListingStatus.draft => (
          AppColors.info,
          Icons.edit_note_rounded,
          'ملفك مسودة — غير ظاهر للعملاء. أكمل البيانات ثم أرسله للمراجعة.'
        ),
      ListingStatus.pending => (
          AppColors.warning,
          Icons.hourglass_top_rounded,
          'ملفك قيد مراجعة فريق SAWA. سيظهر للعملاء بعد الموافقة.'
        ),
      ListingStatus.published => (
          AppColors.success,
          Icons.verified_outlined,
          'ملفك منشور ويظهر للعملاء. تصلك الطلبات بعد أن يراجعها فريق SAWA.'
        ),
      ListingStatus.suspended => (AppColors.error, Icons.block_rounded, 'ملفك موقوف مؤقتاً. تواصل مع فريق SAWA.'),
    };
    return InfoBanner(message: text, icon: icon, color: color, action: action);
  }
}

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, required this.icon, this.hint});

  final String label;
  final int? value;
  final IconData icon;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const Spacer(),
        ]),
        const SizedBox(height: 12),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: (value ?? 0).toDouble()),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => Text(
            value == null ? '—' : v.round().toString(),
            style: AppTextStyles.display.copyWith(fontSize: 28, color: AppColors.textPrimary),
          ),
        ),
        Text(label, style: AppTextStyles.bodySmall),
        if (hint != null) Text(hint!, style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
      ]),
    );
  }
}
