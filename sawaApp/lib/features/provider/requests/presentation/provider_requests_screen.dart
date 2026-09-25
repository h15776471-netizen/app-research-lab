import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/errors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/ui.dart';
import '../../../../data/data_providers.dart';
import '../../../../data/models/account_models.dart';
import '../../state/portal_providers.dart';
import '../../widgets/portal_widgets.dart';

/// Requests SAWA has reviewed and forwarded to this business (RLS shows
/// nothing else). The provider can move each request forward.
class ProviderRequestsScreen extends ConsumerWidget {
  const ProviderRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(providerPortalRepositoryProvider).isAvailable) return const Scaffold(body: PortalOffline());
    final business = ref.watch(myBusinessProvider).valueOrNull;
    final requests = ref.watch(forwardedRequestsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('الطلبات'), automaticallyImplyLeading: false),
      body: business == null && !ref.watch(myBusinessProvider).isLoading
          ? const NoBusinessYet()
          : requests.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  ErrorView(message: friendlyError(e), onRetry: () => ref.invalidate(forwardedRequestsProvider)),
              data: (list) => list.isEmpty
                  ? const EmptyStateView(
                      icon: Icons.inbox_outlined,
                      title: 'لا توجد طلبات بعد',
                      message: 'طلبات العملاء تصل أولاً إلى فريق SAWA، وبعد مراجعتها تُحوَّل إليك وتظهر هنا.',
                    )
                  : RefreshIndicator(
                      onRefresh: () async => ref.invalidate(forwardedRequestsProvider),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => ContentFrame(maxWidth: 800, child: _RequestCard(request: list[i])),
                      ),
                    ),
            ),
    );
  }
}

class _RequestCard extends ConsumerWidget {
  const _RequestCard({required this.request});

  final ContactRequestRecord request;

  Future<void> _setStatus(BuildContext context, WidgetRef ref, RequestStatus s) async {
    try {
      await ref.read(providerPortalRepositoryProvider).updateRequestStatus(request.id, s);
      ref.invalidate(forwardedRequestsProvider);
      ref.invalidate(myStatsProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = request;
    final closed = r.status == RequestStatus.completed || r.status == RequestStatus.cancelled;
    return SurfaceCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(r.userName, style: AppTextStyles.h3)),
          StatusPill(
              label: r.status == RequestStatus.newRequest ? 'جديد' : r.status.labelAr,
              color: closed ? AppColors.textSecondary : AppColors.primary),
        ]),
        const SizedBox(height: 4),
        Text('${r.referenceCode} · حُوِّل ${formatDate(r.forwardedAt ?? r.createdAt)}', style: AppTextStyles.caption),
        if (r.note != null) ...[
          const SizedBox(height: 8),
          Text(r.note!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary)),
        ],
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          OutlinedButton.icon(
            onPressed: () => launchUrl(Uri(scheme: 'tel', path: r.userContact)),
            icon: const Icon(Icons.phone_outlined, size: 18),
            label: Text(r.userContact, textDirection: TextDirection.ltr),
          ),
          if (!closed)
            PopupMenuButton<RequestStatus>(
              tooltip: 'تحديث الحالة',
              onSelected: (s) => _setStatus(context, ref, s),
              itemBuilder: (_) => const [
                PopupMenuItem(value: RequestStatus.viewed, child: Text('تمت المشاهدة')),
                PopupMenuItem(value: RequestStatus.contacted, child: Text('تم التواصل')),
                PopupMenuItem(value: RequestStatus.completed, child: Text('مكتمل')),
                PopupMenuItem(value: RequestStatus.cancelled, child: Text('إلغاء')),
              ],
              child: const Chip(avatar: Icon(Icons.sync_alt_rounded, size: 18), label: Text('تحديث الحالة')),
            ),
        ]),
      ]),
    );
  }
}
