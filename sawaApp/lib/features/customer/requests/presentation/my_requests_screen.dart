import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_notifier.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/errors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/ui.dart';
import '../../../../data/data_providers.dart';
import '../../../../data/models/account_models.dart';
import '../../../../data/models/catalog_models.dart';

final myContactRequestsProvider = FutureProvider.autoDispose<List<ContactRequestRecord>>((ref) {
  final user = ref.watch(authNotifierProvider).user;
  if (user == null) return const [];
  return ref.watch(requestsRepositoryProvider).myContactRequests(user.id);
});

final myInquiriesProvider = FutureProvider.autoDispose<List<EventInquiryRecord>>((ref) {
  final user = ref.watch(authNotifierProvider).user;
  if (user == null) return const [];
  return ref.watch(requestsRepositoryProvider).myInquiries(user.id);
});

class MyRequestsScreen extends ConsumerWidget {
  const MyRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final online = ref.watch(requestsRepositoryProvider).isAvailable;

    if (!auth.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('طلباتي'), automaticallyImplyLeading: false),
        body: EmptyStateView(
          icon: Icons.inbox_outlined,
          title: 'تابع طلباتك في مكان واحد',
          message: online ? 'يمكنك إرسال طلبات بدون حساب. سجّل الدخول لترى طلباتك وحالتها هنا.' : offlineMessage,
          actionLabel: online ? 'تسجيل الدخول' : null,
          action: online ? () => context.pushNamed(AppRoute.login, queryParameters: {'from': '/c/requests'}) : null,
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('طلباتي'),
          automaticallyImplyLeading: false,
          bottom: const TabBar(
            labelColor: AppColors.primary,
            indicatorColor: AppColors.primary,
            tabs: [Tab(text: 'طلبات التواصل'), Tab(text: 'طلبات التخطيط')],
          ),
        ),
        body: const TabBarView(children: [_ContactList(), _InquiryList()]),
      ),
    );
  }
}

class _ContactList extends ConsumerWidget {
  const _ContactList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myContactRequestsProvider);
    final providers = ref.watch(providersProvider).valueOrNull ?? const <SawaProvider>[];
    String nameFor(ContactRequestRecord r) =>
        providers.where((p) => p.id == r.providerUuid || p.legacyId == r.providerKey).firstOrNull?.businessName ??
        'مزود خدمة';

    return async.when(
      loading: () => const _ListSkeleton(),
      error: (e, _) => ErrorView(message: friendlyError(e), onRetry: () => ref.invalidate(myContactRequestsProvider)),
      data: (list) => list.isEmpty
          ? EmptyStateView(
              icon: Icons.send_outlined,
              title: 'لا توجد طلبات بعد',
              message: 'اختر مزوداً واضغط «اطلب تواصل».',
              actionLabel: 'تصفح المزودين',
              action: () => context.go('/c/explore'),
            )
          : RefreshIndicator(
              onRefresh: () async => ref.invalidate(myContactRequestsProvider),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final r = list[i];
                  return ContentFrame(
                    maxWidth: 760,
                    child: SurfaceCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(nameFor(r), style: AppTextStyles.h3)),
                          _StatusChip(label: r.status.labelAr, cancelled: r.status == RequestStatus.cancelled),
                        ]),
                        const SizedBox(height: 6),
                        Text('${r.referenceCode} · ${formatDate(r.createdAt)}', style: AppTextStyles.caption),
                        if (r.note != null) ...[
                          const SizedBox(height: 8),
                          Text(r.note!, style: AppTextStyles.bodySmall, maxLines: 3, overflow: TextOverflow.ellipsis),
                        ],
                        if (r.canCancel)
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: TextButton(
                              style: TextButton.styleFrom(foregroundColor: AppColors.error),
                              onPressed: () => _cancel(
                                  context,
                                  ref,
                                  () => ref.read(requestsRepositoryProvider).cancelContactRequest(r.id),
                                  myContactRequestsProvider),
                              child: const Text('إلغاء الطلب'),
                            ),
                          ),
                      ]),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _InquiryList extends ConsumerWidget {
  const _InquiryList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myInquiriesProvider);
    return async.when(
      loading: () => const _ListSkeleton(),
      error: (e, _) => ErrorView(message: friendlyError(e), onRetry: () => ref.invalidate(myInquiriesProvider)),
      data: (list) => list.isEmpty
          ? EmptyStateView(
              icon: Icons.event_note_outlined,
              title: 'لم ترسل طلب تخطيط بعد',
              message: 'استخدم مخطط المناسبة وأرسل احتياجاتك لفريق SAWA.',
              actionLabel: 'خطّط مناسبتك',
              action: () => context.pushNamed(AppRoute.eventPlanner),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final r = list[i];
                final details = [
                  if (r.guestCount != null) '${r.guestCount} ضيف',
                  if (r.area != null) r.area!,
                  if (r.eventDate != null) formatDate(r.eventDate!),
                  if (r.budgetMax != null) 'ميزانية ${formatIqd(r.budgetMax!)}',
                ].join(' · ');
                return ContentFrame(
                  maxWidth: 760,
                  child: SurfaceCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(r.eventType.labelAr, style: AppTextStyles.h3)),
                        _StatusChip(label: r.status.labelAr, cancelled: r.status == InquiryStatus.cancelled),
                      ]),
                      const SizedBox(height: 6),
                      Text('${r.referenceCode} · ${formatDate(r.createdAt)}', style: AppTextStyles.caption),
                      if (details.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(details, style: AppTextStyles.bodySmall),
                      ],
                      if (r.canCancel)
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton(
                            style: TextButton.styleFrom(foregroundColor: AppColors.error),
                            onPressed: () => _cancel(context, ref,
                                () => ref.read(requestsRepositoryProvider).cancelInquiry(r.id), myInquiriesProvider),
                            child: const Text('إلغاء'),
                          ),
                        ),
                    ]),
                  ),
                );
              },
            ),
    );
  }
}

Future<void> _cancel(
    BuildContext context, WidgetRef ref, Future<void> Function() action, ProviderOrFamily toRefresh) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('إلغاء الطلب؟'),
      content: const Text('سيتوقف فريق SAWA عن متابعة هذا الطلب.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('تراجع')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.pop(c, true),
          child: const Text('إلغاء الطلب'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await action();
    ref.invalidate(toRefresh);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.cancelled});

  final String label;
  final bool cancelled;

  @override
  Widget build(BuildContext context) =>
      StatusPill(label: label, color: cancelled ? AppColors.textSecondary : AppColors.primary);
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) => ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => const Skeleton(height: 96, radius: 18),
      );
}
