import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/category_icon.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/sawa_image.dart';
import '../../../core/widgets/ui.dart';
import '../../../data/data_providers.dart';
import '../../../data/models/catalog_models.dart';
import 'gallery_viewer.dart';

class ProviderDetailsScreen extends ConsumerStatefulWidget {
  const ProviderDetailsScreen({super.key, required this.providerId});

  final String providerId;

  @override
  ConsumerState<ProviderDetailsScreen> createState() => _ProviderDetailsScreenState();
}

class _ProviderDetailsScreenState extends ConsumerState<ProviderDetailsScreen> {
  bool _viewRecorded = false;

  void _recordView(SawaProvider p) {
    if (_viewRecorded) return;
    _viewRecorded = true;
    ref.read(catalogRepositoryProvider).recordView(p.id);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(providerByIdProvider(widget.providerId));
    return async.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: ContentFrame(maxWidth: 560, child: ProviderCardSkeleton()),
        ),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(
            message: friendlyError(e), onRetry: () => ref.invalidate(providerByIdProvider(widget.providerId))),
      ),
      data: (p) {
        if (p == null) {
          return Scaffold(
            appBar: AppBar(),
            body: EmptyStateView(
              icon: Icons.storefront_outlined,
              title: 'المزود غير متاح',
              message: 'ربما لم يعد منشوراً أو أن الرابط غير صحيح.',
              actionLabel: 'تصفح المزودين',
              action: () => context.go('/c/explore'),
            ),
          );
        }
        WidgetsBinding.instance.addPostFrameCallback((_) => _recordView(p));
        return _Details(provider: p);
      },
    );
  }
}

class _Details extends ConsumerWidget {
  const _Details({required this.provider});

  final SawaProvider provider;

  void _contact(BuildContext context, {String? serviceId, String? package}) {
    context.pushNamed(
      AppRoute.contactRequest,
      pathParameters: {'providerId': provider.id},
      queryParameters: {
        if (serviceId != null) 'service': serviceId,
        if (package != null) 'package': package,
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = provider;
    final now = DateTime.now();
    final category = (ref.watch(categoriesProvider).valueOrNull ?? const <SawaCategory>[])
        .where((c) => c.id == p.categoryId)
        .firstOrNull;
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.desktop;
    final pad = pagePadding(context);

    final sections = <Widget>[
      _Header(provider: p, categoryName: category?.nameAr),
      if (p.description != null || p.shortDescription != null)
        _Section(title: 'نبذة', child: Text(p.description ?? p.shortDescription!, style: AppTextStyles.body)),
      _PackagesSection(provider: p, now: now, onAsk: (t) => _contact(context, package: t)),
      _ServicesSection(provider: p, onAsk: (id) => _contact(context, serviceId: id)),
      _LocationSection(provider: p),
      _InstagramSection(provider: p),
      _DataQualitySection(provider: p),
      const SizedBox(height: 24),
    ];

    final gallery = _Gallery(provider: p);

    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: wide ? 420 : 320,
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          leading: Padding(
            padding: const EdgeInsets.all(8),
            child: CircleAvatar(
              backgroundColor: Colors.white.withValues(alpha: 0.92),
              child: BackButton(
                color: AppColors.textPrimary,
                onPressed: () => context.canPop() ? context.pop() : context.go('/c/home'),
              ),
            ),
          ),
          flexibleSpace: FlexibleSpaceBar(background: gallery),
        ),
        SliverToBoxAdapter(
          child: ContentFrame(
            child: Padding(
              padding: EdgeInsets.fromLTRB(pad, 20, pad, 0),
              child: wide
                  ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                          flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: sections)),
                      const SizedBox(width: 28),
                      Expanded(flex: 2, child: _SideCard(provider: p, now: now, onContact: () => _contact(context))),
                    ])
                  : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: sections),
            ),
          ),
        ),
      ]),
      bottomNavigationBar: wide
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(children: [
                  Expanded(child: _PriceSummary(provider: p, now: now, compact: true)),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(150, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.button)),
                    ),
                    onPressed: () => _contact(context),
                    icon: const Icon(Icons.send_outlined, size: 18),
                    label: const Text('اطلب تواصل'),
                  ),
                ]),
              ),
            ),
    );
  }
}

class _Gallery extends StatefulWidget {
  const _Gallery({required this.provider});

  final SawaProvider provider;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  final _page = PageController();
  int _index = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.provider;
    final images = p.galleryImages;
    if (images.isEmpty) {
      return Hero(
        tag: 'provider-image-${p.id}',
        child: Stack(fit: StackFit.expand, children: [
          BrandedPlaceholder(categoryId: p.categoryId),
          PositionedDirectional(
            bottom: 14,
            start: 14,
            child: StatusPill(
              label: 'لا توجد صور من المزود بعد',
              color: AppColors.textSecondary,
              background: Colors.white.withValues(alpha: 0.9),
              icon: Icons.image_not_supported_outlined,
            ),
          ),
        ]),
      );
    }
    return Stack(fit: StackFit.expand, children: [
      PageView.builder(
        controller: _page,
        itemCount: images.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) {
          final img = SawaImage(url: images[i].url, categoryId: p.categoryId, semanticLabel: images[i].altText);
          return GestureDetector(
            onTap: () => openGalleryViewer(context, images, i, p.categoryId),
            child: i == 0 && images[0].url == p.cardImageUrl ? Hero(tag: 'provider-image-${p.id}', child: img) : img,
          );
        },
      ),
      const Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        height: 90,
        child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: AppColors.gradientCard))),
      ),
      if (images[_index].altText != null)
        PositionedDirectional(
          bottom: 16,
          start: 16,
          end: 90,
          child: Text(
            images[_index].altText!,
            style: AppTextStyles.bodySmall.copyWith(color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      if (images.length > 1)
        PositionedDirectional(
          bottom: 18,
          end: 16,
          child: Row(children: [
            for (var i = 0; i < images.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: i == _index ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _index ? Colors.white : Colors.white54,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ]),
        ),
    ]);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.provider, this.categoryName});

  final SawaProvider provider;
  final String? categoryName;

  @override
  Widget build(BuildContext context) {
    final p = provider;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 6, children: [
        if (categoryName != null) StatusPill(label: categoryName!, icon: categoryIcon(p.categoryId)),
        if (p.capacity != null)
          StatusPill(label: 'تتسع لـ${p.capacity} ضيف', icon: Icons.groups_outlined, color: AppColors.textSecondary),
      ]),
      const SizedBox(height: 10),
      Text(p.businessName, style: AppTextStyles.h1),
      const SizedBox(height: 6),
      Row(children: [
        const Icon(Icons.place_outlined, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Expanded(
          child: Text([p.area, p.city].whereType<String>().toSet().join(' · '), style: AppTextStyles.bodySmall),
        ),
      ]),
      if (p.shortDescription != null && p.description != null) ...[
        const SizedBox(height: 10),
        Text(p.shortDescription!, style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
      ],
    ]);
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionHeader(title: title),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}

class _PriceSummary extends StatelessWidget {
  const _PriceSummary({required this.provider, required this.now, this.compact = false});

  final SawaProvider provider;
  final DateTime now;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final base = provider.basePrice(now);
    final offer = provider.lowestOffer(now);
    if (base == null && offer == null) {
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('السعر', style: AppTextStyles.caption),
        Text('غير متوفر — اسأل عنه', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700)),
      ]);
    }
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (base != null) ...[
        Text(base.to == null ? 'يبدأ من' : 'نطاق السعر', style: AppTextStyles.caption),
        Text(formatRange(base.from, base.to),
            style: (compact ? AppTextStyles.body : AppTextStyles.h2)
                .copyWith(color: AppColors.primary, fontWeight: FontWeight.w800)),
      ],
      if (offer != null && (!compact || base == null)) ...[
        if (base != null) const SizedBox(height: 4),
        Text('عروض من ${formatIqd(offer.from)}',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700)),
      ],
      if (!compact && provider.priceNote != null) ...[
        const SizedBox(height: 6),
        Text(provider.priceNote!, style: AppTextStyles.caption),
      ],
    ]);
  }
}

class _SideCard extends StatelessWidget {
  const _SideCard({required this.provider, required this.now, required this.onContact});

  final SawaProvider provider;
  final DateTime now;
  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _PriceSummary(provider: provider, now: now),
        const SizedBox(height: 18),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary, minimumSize: const Size.fromHeight(52)),
          onPressed: onContact,
          icon: const Icon(Icons.send_outlined, size: 18),
          label: const Text('اطلب تواصل'),
        ),
        const SizedBox(height: 10),
        Text(
          'يصل طلبك إلى فريق SAWA أولاً، ثم نتواصل معك ومع المزود. لا حاجة لحساب.',
          style: AppTextStyles.caption,
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }
}

class _PackagesSection extends StatelessWidget {
  const _PackagesSection({required this.provider, required this.now, required this.onAsk});

  final SawaProvider provider;
  final DateTime now;
  final void Function(String title) onAsk;

  @override
  Widget build(BuildContext context) {
    final list = provider.activePackages(now);
    if (list.isEmpty) return const SizedBox.shrink();
    final offers = list.where((k) => k.isOffer).length;
    return _Section(
      title: offers == list.length ? 'العروض' : (offers == 0 ? 'الباقات والأسعار' : 'الباقات والعروض'),
      child: Column(children: [
        for (final k in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: k.isOffer ? AppColors.accentLight.withValues(alpha: 0.55) : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(color: k.isOffer ? AppColors.champagne : AppColors.border),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Text(k.title, style: AppTextStyles.h3)),
                  if (k.isOffer)
                    const StatusPill(label: 'عرض', color: AppColors.accent, icon: Icons.local_offer_outlined),
                ]),
                if (k.priceFrom != null) ...[
                  const SizedBox(height: 6),
                  Text(formatRange(k.priceFrom, k.priceTo, currency: k.currency),
                      style: AppTextStyles.h3.copyWith(color: AppColors.primary)),
                ],
                if (k.description != null) ...[
                  const SizedBox(height: 8),
                  Text(k.description!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary)),
                ],
                if (k.conditions != null) ...[
                  const SizedBox(height: 8),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.info_outline, size: 15, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(child: Text(k.conditions!, style: AppTextStyles.caption)),
                  ]),
                ],
                if (k.validUntil != null) ...[
                  const SizedBox(height: 6),
                  Text('ساري حتى ${formatDate(k.validUntil!)}', style: AppTextStyles.caption),
                ],
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(onPressed: () => onAsk(k.title), child: const Text('اسأل عن هذه الباقة')),
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _ServicesSection extends StatelessWidget {
  const _ServicesSection({required this.provider, required this.onAsk});

  final SawaProvider provider;
  final void Function(String serviceId) onAsk;

  @override
  Widget build(BuildContext context) {
    final list = provider.activeServices;
    if (list.isEmpty) return const SizedBox.shrink();
    final detailed = list.where((s) => s.priceFrom != null || s.imageUrl != null || s.description != null).toList();
    final simple = list.where((s) => !detailed.contains(s)).toList();
    return _Section(
      title: 'الخدمات',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (simple.isNotEmpty)
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in simple)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWarm,
                  borderRadius: BorderRadius.circular(AppRadii.full),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.check_rounded, size: 16, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Flexible(child: Text(s.name, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary))),
                ]),
              ),
          ]),
        if (simple.isNotEmpty && detailed.isNotEmpty) const SizedBox(height: 14),
        for (final s in detailed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.card),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (s.imageUrl != null)
                  SizedBox(width: 96, height: 96, child: SawaImage(url: s.imageUrl, categoryId: provider.categoryId)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.name, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
                      if (s.description != null) Text(s.description!, style: AppTextStyles.caption),
                      if (s.priceFrom != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${formatRange(s.priceFrom, s.priceTo, currency: s.currency)}'
                          '${s.unit != null ? ' ${serviceUnits[s.unit]}' : ''}',
                          style:
                              AppTextStyles.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ]),
                  ),
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}

class _LocationSection extends StatelessWidget {
  const _LocationSection({required this.provider});

  final SawaProvider provider;

  @override
  Widget build(BuildContext context) {
    final p = provider;
    return _Section(
      title: 'الموقع',
      child: SurfaceCard(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.location_on_outlined, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.city, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
              if (p.address != null)
                Text(p.address!, style: AppTextStyles.bodySmall)
              else if (p.area != null)
                Text(p.area!, style: AppTextStyles.bodySmall)
              else
                Text('العنوان التفصيلي غير متوفر', style: AppTextStyles.caption),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _InstagramSection extends StatelessWidget {
  const _InstagramSection({required this.provider});

  final SawaProvider provider;

  Future<void> _open(BuildContext context, String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذّر فتح الرابط')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = provider;
    final status = p.fieldStatus('instagram_url');
    final note = p.fieldSources['instagram_url']?.note;
    final Widget body;
    if (p.instagramUrl != null &&
        (status == FieldStatus.sourceOnly || status == FieldStatus.verified || p.fieldSources.isEmpty)) {
      body = OutlinedButton.icon(
        onPressed: () => _open(context, p.instagramUrl!),
        icon: const Icon(Icons.camera_alt_outlined, size: 18),
        label: Text('@${p.instagramHandle ?? ''}', textDirection: TextDirection.ltr),
      );
    } else if (status == FieldStatus.unverified) {
      body = InfoBanner(
        icon: Icons.help_outline,
        color: AppColors.warning,
        message: 'حساب إنستغرام غير مؤكد${note != null ? ' — $note' : ''}. نتحقق منه قبل عرضه.',
      );
    } else {
      body = Text('حساب إنستغرام غير متوفر في مصدر البيانات.', style: AppTextStyles.bodySmall);
    }
    return _Section(title: 'إنستغرام', child: Align(alignment: AlignmentDirectional.centerStart, child: body));
  }
}

class _DataQualitySection extends StatelessWidget {
  const _DataQualitySection({required this.provider});

  final SawaProvider provider;

  static const _labels = {
    'price': 'السعر',
    'capacity': 'السعة',
    'address': 'العنوان التفصيلي',
    'area': 'المنطقة',
    'images': 'الصور',
    'packages': 'الباقات',
    'phone': 'رقم التواصل',
    'instagram_url': 'إنستغرام',
  };

  @override
  Widget build(BuildContext context) {
    final p = provider;
    if (p.fieldSources.isEmpty) return const SizedBox.shrink();
    final missing =
        _labels.entries.where((e) => p.fieldStatus(e.key) == FieldStatus.missing).map((e) => e.value).toList();
    final unverified =
        _labels.entries.where((e) => p.fieldStatus(e.key) == FieldStatus.unverified).map((e) => e.value).toList();
    final priceNote = p.fieldSources['price']?.note;
    return _Section(
      title: 'عن هذه البيانات',
      child: SurfaceCard(
        color: AppColors.surfaceWarm,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.fact_check_outlined, size: 18, color: AppColors.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                p.isSawaManaged
                    ? 'جمعها فريق SAWA من كتالوج المزود، ولم يتم التحقق منها مع المزود بعد.'
                    : 'أضافها المزود بنفسه وراجعها فريق SAWA قبل النشر.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
              ),
            ),
          ]),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('غير متوفر في المصدر: ${missing.join('، ')}', style: AppTextStyles.caption),
          ],
          if (unverified.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('غير مؤكد: ${unverified.join('، ')}', style: AppTextStyles.caption.copyWith(color: AppColors.warning)),
          ],
          if (priceNote != null) ...[
            const SizedBox(height: 4),
            Text('ملاحظة السعر: $priceNote', style: AppTextStyles.caption),
          ],
          const SizedBox(height: 8),
          Text('الأسعار والعروض قد تتغير — يؤكدها فريقنا عند التواصل.', style: AppTextStyles.caption),
        ]),
      ),
    );
  }
}
