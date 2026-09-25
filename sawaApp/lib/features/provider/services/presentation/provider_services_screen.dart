import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/errors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/ui.dart';
import '../../../../data/data_providers.dart';
import '../../../../data/models/catalog_models.dart';
import '../../state/portal_providers.dart';
import '../../widgets/portal_widgets.dart';

class ProviderServicesScreen extends ConsumerWidget {
  const ProviderServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(providerPortalRepositoryProvider).isAvailable) return const Scaffold(body: PortalOffline());
    final business = ref.watch(myBusinessProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الخدمات والباقات'),
          automaticallyImplyLeading: false,
          bottom: const TabBar(
            labelColor: AppColors.primary,
            indicatorColor: AppColors.primary,
            tabs: [Tab(text: 'الخدمات'), Tab(text: 'الباقات والعروض')],
          ),
        ),
        body: business.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorView(message: friendlyError(e), onRetry: () => ref.invalidate(myBusinessProvider)),
          data: (b) => b == null
              ? const NoBusinessYet()
              : TabBarView(children: [_ServicesTab(business: b), _PackagesTab(business: b)]),
        ),
      ),
    );
  }
}

Future<void> _confirmDelete(BuildContext context, WidgetRef ref, String what, Future<void> Function() action) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text('حذف $what؟'),
      content: const Text('لا يمكن التراجع عن الحذف.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('تراجع')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.pop(c, true),
          child: const Text('حذف'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await action();
    ref.invalidate(myBusinessProvider);
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
  }
}

class _ServicesTab extends ConsumerWidget {
  const _ServicesTab({required this.business});

  final SawaProvider business;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = business.services;
    final repo = ref.read(providerPortalRepositoryProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-service',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => context.pushNamed(AppRoute.addService),
        icon: const Icon(Icons.add),
        label: const Text('خدمة جديدة'),
      ),
      body: list.isEmpty
          ? const EmptyStateView(
              icon: Icons.design_services_outlined,
              title: 'لا توجد خدمات بعد',
              message: 'أضف ما تقدمه — مثل التصوير، الضيافة، الكوشة — مع السعر إذا كان ثابتاً.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final s = list[i];
                return ContentFrame(
                  maxWidth: 800,
                  child: SurfaceCard(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s.name,
                              style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w700,
                                color: s.isActive ? AppColors.textPrimary : AppColors.textHint,
                              )),
                          Text(
                            s.priceFrom == null
                                ? (s.isActive ? 'بدون سعر معلن' : 'مخفية')
                                : '${formatRange(s.priceFrom, s.priceTo)}${s.unit != null ? ' ${serviceUnits[s.unit]}' : ''}',
                            style: AppTextStyles.caption,
                          ),
                        ]),
                      ),
                      Switch(
                        value: s.isActive,
                        onChanged: (v) async {
                          try {
                            await repo.saveService(business.id, {'is_active': v}, id: s.id);
                            ref.invalidate(myBusinessProvider);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
                            }
                          }
                        },
                      ),
                      IconButton(
                        tooltip: 'تعديل',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => context.pushNamed(AppRoute.editService, pathParameters: {'id': s.id}),
                      ),
                      IconButton(
                        tooltip: 'حذف',
                        icon: const Icon(Icons.delete_outline, color: AppColors.error),
                        onPressed: () => _confirmDelete(context, ref, 'الخدمة', () => repo.deleteService(s.id)),
                      ),
                    ]),
                  ),
                );
              },
            ),
    );
  }
}

class _PackagesTab extends ConsumerWidget {
  const _PackagesTab({required this.business});

  final SawaProvider business;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = business.packages;
    final repo = ref.read(providerPortalRepositoryProvider);
    final now = DateTime.now();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-package',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => context.pushNamed(AppRoute.addPackage),
        icon: const Icon(Icons.add),
        label: const Text('باقة أو عرض'),
      ),
      body: list.isEmpty
          ? const EmptyStateView(
              icon: Icons.inventory_2_outlined,
              title: 'لا توجد باقات بعد',
              message: 'الباقات تساعد العميل يفهم ما يشمله السعر. العروض المؤقتة تُعرض بوسم «عرض».',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final k = list[i];
                return ContentFrame(
                  maxWidth: 800,
                  child: SurfaceCard(
                    padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                            Text(k.title, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
                            if (k.isOffer) const StatusPill(label: 'عرض', color: AppColors.accent),
                            if (k.isExpired(now)) const StatusPill(label: 'منتهي', color: AppColors.textSecondary),
                            if (!k.isActive) const StatusPill(label: 'مخفي', color: AppColors.textSecondary),
                          ]),
                          Text(k.priceFrom == null ? 'بدون سعر' : formatRange(k.priceFrom, k.priceTo),
                              style: AppTextStyles.caption),
                        ]),
                      ),
                      IconButton(
                        tooltip: 'تعديل',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => context.pushNamed(AppRoute.editPackage, pathParameters: {'id': k.id}),
                      ),
                      IconButton(
                        tooltip: 'حذف',
                        icon: const Icon(Icons.delete_outline, color: AppColors.error),
                        onPressed: () => _confirmDelete(context, ref, 'الباقة', () => repo.deletePackage(k.id)),
                      ),
                    ]),
                  ),
                );
              },
            ),
    );
  }
}
