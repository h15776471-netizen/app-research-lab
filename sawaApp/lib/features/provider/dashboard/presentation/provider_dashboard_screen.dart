import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_notifier.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/errors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/ui.dart';
import '../../../../data/data_providers.dart';
import '../../../../data/models/catalog_models.dart';
import '../../state/portal_providers.dart';
import '../../widgets/portal_widgets.dart';

class ProviderDashboardScreen extends ConsumerWidget {
  const ProviderDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).user;
    if (!ref.watch(providerPortalRepositoryProvider).isAvailable) {
      return const Scaffold(body: PortalOffline());
    }
    final business = ref.watch(myBusinessProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('لوحة التحكم'), automaticallyImplyLeading: false),
      body: business.when(
        loading: () => const Padding(padding: EdgeInsets.all(16), child: Skeleton(height: 200)),
        error: (e, _) => ErrorView(message: friendlyError(e), onRetry: () => ref.invalidate(myBusinessProvider)),
        data: (b) => b == null
            ? const NoBusinessYet()
            : RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(myBusinessProvider);
                  ref.invalidate(myStatsProvider);
                  ref.invalidate(forwardedRequestsProvider);
                },
                child: _Content(business: b, ownerName: user?.displayName ?? ''),
              ),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.business, required this.ownerName});

  final SawaProvider business;
  final String ownerName;

  Future<void> _submitForReview(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(providerPortalRepositoryProvider).setStatus(business.id, ListingStatus.pending);
      ref.invalidate(myBusinessProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أُرسل ملفك لمراجعة فريق SAWA')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(myStatsProvider);
    final requests = ref.watch(forwardedRequestsProvider);
    final items = completeness(business);
    final done = items.where((i) => i.done).length;
    final pad = pagePadding(context);
    final s = stats.valueOrNull;

    Widget? statusAction;
    if (business.status == ListingStatus.draft) {
      statusAction = TextButton(
        onPressed: readyForReview(business) ? () => _submitForReview(context, ref) : null,
        child: const Text('إرسال للمراجعة'),
      );
    }

    return ListView(padding: EdgeInsets.all(pad), children: [
      ContentFrame(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('أهلاً $ownerName', style: AppTextStyles.h1),
          Text(business.businessName, style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          ListingStatusBanner(status: business.status, action: statusAction),
          if (business.status == ListingStatus.draft && !readyForReview(business)) ...[
            const SizedBox(height: 6),
            Text('للإرسال للمراجعة: أضف وصفاً، المنطقة، وخدمة واحدة على الأقل.', style: AppTextStyles.caption),
          ],
          const SizedBox(height: 20),
          const SectionHeader(title: 'نشاطك', subtitle: 'أرقام حقيقية من قاعدة البيانات — لا تقديرات'),
          const SizedBox(height: 12),
          if (stats.hasError)
            InfoBanner(message: friendlyError(stats.error!), color: AppColors.error)
          else
            LayoutBuilder(builder: (context, c) {
              final cols = c.maxWidth >= 760 ? 4 : 2;
              final w = (c.maxWidth - (cols - 1) * 12) / cols;
              final tiles = [
                StatTile(
                    label: 'مشاهدات الملف (30 يوم)',
                    value: s?.viewsLast30Days,
                    icon: Icons.visibility_outlined,
                    hint: s == null ? null : 'الإجمالي ${s.viewsTotal}'),
                StatTile(
                    label: 'طلبات وصلتك',
                    value: s?.requestsTotal,
                    icon: Icons.inbox_outlined,
                    hint: s == null ? null : '${s.requestsNew} جديد'),
                StatTile(
                    label: 'خدمات نشطة',
                    value: s?.servicesActive,
                    icon: Icons.design_services_outlined,
                    hint: s == null ? null : 'من ${s.servicesTotal}'),
                StatTile(label: 'الصور', value: business.galleryImages.length, icon: Icons.photo_library_outlined),
              ];
              return Wrap(spacing: 12, runSpacing: 12, children: [for (final t in tiles) SizedBox(width: w, child: t)]);
            }),
          if (s != null && s.viewsTotal == 0 && s.requestsTotal == 0) ...[
            const SizedBox(height: 8),
            Text(
              business.status == ListingStatus.published
                  ? 'لا توجد بيانات كافية حالياً — ستظهر المشاهدات والطلبات هنا عند حدوثها.'
                  : 'تبدأ المشاهدات والطلبات بعد نشر ملفك.',
              style: AppTextStyles.caption,
            ),
          ],
          const SizedBox(height: 24),
          LayoutBuilder(builder: (context, c) {
            final completenessCard = SurfaceCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('اكتمال الملف', style: AppTextStyles.h3)),
                  Text('$done/${items.length}', style: AppTextStyles.h3.copyWith(color: AppColors.primary)),
                ]),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: done / items.length,
                    minHeight: 6,
                    color: AppColors.primary,
                    backgroundColor: AppColors.borderLight,
                  ),
                ),
                const SizedBox(height: 12),
                for (final i in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      Icon(i.done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                          size: 18, color: i.done ? AppColors.success : AppColors.textHint),
                      const SizedBox(width: 8),
                      Text(i.label, style: AppTextStyles.bodySmall),
                    ]),
                  ),
                const SizedBox(height: 6),
                Wrap(spacing: 8, children: [
                  OutlinedButton(
                      onPressed: () => context.pushNamed(AppRoute.providerOnboarding),
                      child: const Text('تعديل البيانات')),
                  OutlinedButton(onPressed: () => context.go('/p/profile'), child: const Text('الصور')),
                  OutlinedButton(onPressed: () => context.go('/p/services'), child: const Text('الخدمات')),
                ]),
              ]),
            );
            final requestsCard = SurfaceCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('أحدث الطلبات', style: AppTextStyles.h3)),
                  TextButton(onPressed: () => context.go('/p/requests'), child: const Text('الكل')),
                ]),
                Text('تصلك الطلبات بعد أن يراجعها فريق SAWA.', style: AppTextStyles.caption),
                const SizedBox(height: 10),
                ...requests.when(
                  loading: () => [const Skeleton(height: 60)],
                  error: (e, _) => [Text(friendlyError(e), style: AppTextStyles.caption)],
                  data: (list) => list.isEmpty
                      ? [Text('لا توجد طلبات بعد.', style: AppTextStyles.bodySmall)]
                      : [
                          for (final r in list.take(3))
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const CircleAvatar(
                                backgroundColor: AppColors.primaryLight,
                                child: Icon(Icons.person_outline, color: AppColors.primary),
                              ),
                              title: Text(r.userName, style: AppTextStyles.body),
                              subtitle: Text('${r.status.labelAr} · ${formatDate(r.createdAt)}',
                                  style: AppTextStyles.caption),
                            ),
                        ],
                ),
              ]),
            );
            return c.maxWidth >= 760
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: completenessCard),
                    const SizedBox(width: 16),
                    Expanded(child: requestsCard),
                  ])
                : Column(children: [completenessCard, const SizedBox(height: 16), requestsCard]);
          }),
          const SizedBox(height: 24),
        ]),
      ),
    ]);
  }
}
