import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/auth/auth_notifier.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/errors.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/sawa_image.dart';
import '../../../../core/widgets/ui.dart';
import '../../../../data/data_providers.dart';
import '../../../../data/models/catalog_models.dart';
import '../../../providers_list/presentation/provider_card.dart';
import '../../state/portal_providers.dart';
import '../../widgets/portal_widgets.dart';

class ProviderProfileScreen extends ConsumerWidget {
  const ProviderProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).user;
    final online = ref.watch(providerPortalRepositoryProvider).isAvailable;
    final business = online ? ref.watch(myBusinessProvider) : const AsyncValue<SawaProvider?>.data(null);

    return Scaffold(
      appBar: AppBar(title: const Text('ملفي التجاري'), automaticallyImplyLeading: false),
      body: ListView(padding: EdgeInsets.all(pagePadding(context)), children: [
        ContentFrame(
          maxWidth: 900,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (!online)
              const InfoBanner(message: offlineMessage, color: AppColors.warning, icon: Icons.cloud_off_outlined)
            else
              business.when(
                loading: () => const Skeleton(height: 240),
                error: (e, _) =>
                    ErrorView(message: friendlyError(e), onRetry: () => ref.invalidate(myBusinessProvider)),
                data: (b) =>
                    b == null ? const SizedBox(height: 320, child: NoBusinessYet()) : _BusinessSection(business: b),
              ),
            const SizedBox(height: 24),
            const SectionHeader(title: 'الحساب'),
            const SizedBox(height: 10),
            SurfaceCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(user?.displayName ?? '', style: AppTextStyles.h3),
                Text(user?.email ?? '', style: AppTextStyles.bodySmall, textDirection: TextDirection.ltr),
                const SizedBox(height: 12),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  onPressed: () async {
                    await ref.read(authNotifierProvider.notifier).signOut();
                    if (context.mounted) context.go('/welcome');
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('تسجيل الخروج'),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _BusinessSection extends ConsumerStatefulWidget {
  const _BusinessSection({required this.business});

  final SawaProvider business;

  @override
  ConsumerState<_BusinessSection> createState() => _BusinessSectionState();
}

class _BusinessSectionState extends ConsumerState<_BusinessSection> {
  bool _uploading = false;

  Future<void> _upload() async {
    final b = widget.business;
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2000, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      _snack('حجم الصورة أكبر من 5 ميغابايت.');
      return;
    }
    final name = file.name.toLowerCase();
    final ext = name.contains('.') ? name.split('.').last : 'jpg';
    if (!{'jpg', 'jpeg', 'png', 'webp'}.contains(ext)) {
      _snack('الصيغ المسموحة: JPG أو PNG أو WebP.');
      return;
    }
    setState(() => _uploading = true);
    try {
      await ref.read(providerPortalRepositoryProvider).uploadImage(
            providerId: b.id,
            bytes: bytes,
            extension: ext,
            asCover: b.cardImageUrl == null,
            sortOrder: b.images.length,
          );
      ref.invalidate(myBusinessProvider);
      _snack('تم رفع الصورة');
    } catch (e) {
      _snack(friendlyError(e));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _act(Future<void> Function() f, String ok) async {
    try {
      await f();
      ref.invalidate(myBusinessProvider);
      _snack(ok);
    } catch (e) {
      _snack(friendlyError(e));
    }
  }

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.business;
    final repo = ref.read(providerPortalRepositoryProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ListingStatusBanner(status: b.status),
      const SizedBox(height: 20),
      SectionHeader(
        title: 'معاينة البطاقة',
        subtitle: 'هكذا يظهر ملفك للعملاء بعد النشر',
        actionLabel: 'تعديل البيانات',
        onAction: () => context.pushNamed(AppRoute.providerOnboarding),
      ),
      const SizedBox(height: 12),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: SizedBox(
          width: 320,
          height: 420,
          child: ProviderCard(provider: b, onTap: () => context.pushNamed(AppRoute.providerOnboarding)),
        ),
      ),
      const SizedBox(height: 24),
      SectionHeader(
        title: 'معرض الصور',
        subtitle: 'صور حقيقية لعملك فقط · JPG/PNG/WebP حتى 5MB',
        actionLabel: _uploading ? null : 'رفع صورة',
        onAction: _upload,
      ),
      const SizedBox(height: 12),
      if (_uploading) const LinearProgressIndicator(color: AppColors.primary),
      if (b.images.isEmpty)
        SurfaceCard(
          child: Column(children: [
            const SizedBox(height: 100, child: BrandedPlaceholder(compact: true)),
            const SizedBox(height: 10),
            Text('لا توجد صور بعد. أول صورة ترفعها تصبح صورة الغلاف.', style: AppTextStyles.bodySmall),
            TextButton.icon(
                onPressed: _uploading ? null : _upload,
                icon: const Icon(Icons.upload_rounded),
                label: const Text('رفع صورة')),
          ]),
        )
      else
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth > 700 ? 4 : (c.maxWidth > 420 ? 3 : 2);
          return GridView.count(
            crossAxisCount: cols,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [
              for (final img in b.images)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(fit: StackFit.expand, children: [
                    SawaImage(url: img.url, categoryId: b.categoryId),
                    if (img.kind == ImageKind.cover)
                      const PositionedDirectional(
                        top: 8,
                        start: 8,
                        child: StatusPill(label: 'الغلاف', color: Colors.white, background: AppColors.primary),
                      ),
                    PositionedDirectional(
                      bottom: 4,
                      end: 4,
                      child: PopupMenuButton<String>(
                        tooltip: 'خيارات',
                        icon: const CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.more_horiz, size: 18, color: AppColors.textPrimary),
                        ),
                        onSelected: (v) {
                          if (v == 'cover') _act(() => repo.setCover(b.id, img), 'تم تعيين صورة الغلاف');
                          if (v == 'delete') _act(() => repo.deleteImage(b.id, img), 'تم حذف الصورة');
                        },
                        itemBuilder: (_) => [
                          if (img.kind != ImageKind.cover)
                            const PopupMenuItem(value: 'cover', child: Text('تعيين كغلاف')),
                          const PopupMenuItem(value: 'delete', child: Text('حذف')),
                        ],
                      ),
                    ),
                  ]),
                ),
            ],
          );
        }),
    ]);
  }
}
