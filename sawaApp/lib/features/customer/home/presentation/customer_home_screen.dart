import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_notifier.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/errors.dart';
import '../../../../core/widgets/category_icon.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/ui.dart';
import '../../../../data/data_providers.dart';
import '../../../../data/models/catalog_models.dart';
import '../../../providers_list/domain/provider_filter.dart';
import '../../../providers_list/presentation/provider_card.dart';

class CustomerHomeScreen extends ConsumerWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final providers = ref.watch(providersProvider);
    final user = ref.watch(authNotifierProvider).user;
    final pad = pagePadding(context);

    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(categoriesProvider);
          ref.invalidate(providersProvider);
          await ref.read(providersProvider.future);
        },
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: _Hero(greeting: user?.displayName)),
          SliverToBoxAdapter(
            child: ContentFrame(
              child: Padding(
                padding: EdgeInsets.fromLTRB(pad, 20, pad, 0),
                child: const _PlannerCta(),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: ContentFrame(
              child: Padding(
                padding: EdgeInsets.fromLTRB(pad, 28, pad, 12),
                child: const SectionHeader(title: 'الفئات', subtitle: 'اختر الخدمة التي تحتاجها'),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: categories.when(
              loading: () => SizedBox(
                height: 118,
                child: ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: pad),
                  scrollDirection: Axis.horizontal,
                  itemCount: 5,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, __) => const Skeleton(width: 132, height: 118, radius: 18),
                ),
              ),
              error: (e, _) => ErrorView(
                message: friendlyError(e),
                onRetry: () => ref.invalidate(categoriesProvider),
              ),
              data: (list) => _CategoryStrip(categories: list, padding: pad),
            ),
          ),
          ...providers.when(
            loading: () => [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(pad, 28, pad, 24),
                sliver: SliverList.separated(
                  itemCount: 2,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (_, __) => const ProviderCardSkeleton(),
                ),
              ),
            ],
            error: (e, _) => [
              SliverToBoxAdapter(
                child: ErrorView(message: friendlyError(e), onRetry: () => ref.invalidate(providersProvider)),
              ),
            ],
            data: (list) => [
              for (final c in categories.valueOrNull ?? const <SawaCategory>[])
                if (list.any((p) => p.categoryId == c.id))
                  SliverToBoxAdapter(
                    child: _CategoryCarousel(
                      category: c,
                      providers: applyProviderFilter(list, ProviderFilter(categoryId: c.id)),
                      padding: pad,
                    ),
                  ),
            ],
          ),
          SliverToBoxAdapter(
            child: ContentFrame(
              child: Padding(padding: EdgeInsets.fromLTRB(pad, 32, pad, 40), child: const _HowItWorks()),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Hero extends StatefulWidget {
  const _Hero({this.greeting});

  final String? greeting;

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _go() {
    final q = _search.text.trim();
    context.goNamed(AppRoute.explore, queryParameters: q.isEmpty ? {} : {'q': q});
  }

  @override
  Widget build(BuildContext context) {
    final pad = pagePadding(context);
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.gradientHero,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: ContentFrame(
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, 20, pad, 28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('sawa', style: AppTextStyles.h2.copyWith(color: Colors.white, letterSpacing: 2)),
                const SizedBox(width: 8),
                Container(width: 1, height: 18, color: AppColors.accent),
                const SizedBox(width: 8),
                Text('بغداد', style: AppTextStyles.bodySmall.copyWith(color: AppColors.champagne)),
              ]),
              const SizedBox(height: 22),
              Text(
                widget.greeting == null
                    ? 'خلّي مناسبتك تبدأ من هنا.'
                    : 'أهلاً ${widget.greeting}،\nخلّي مناسبتك تبدأ من هنا.',
                style: AppTextStyles.h1.copyWith(color: Colors.white, fontSize: 26, height: 1.4),
              ),
              const SizedBox(height: 6),
              Text(
                'قاعات، تصوير، ورد — بمعلومات منظمة من مصادر المزودين.',
                style: AppTextStyles.bodySmall.copyWith(color: Colors.white.withValues(alpha: 0.78)),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _go(),
                decoration: InputDecoration(
                  hintText: 'ابحث باسم مزود أو منطقة أو خدمة…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    tooltip: 'بحث',
                    icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
                    onPressed: _go,
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.full), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.full), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.full),
                    borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _PlannerCta extends StatelessWidget {
  const _PlannerCta();

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => context.pushNamed(AppRoute.eventPlanner),
      semanticLabel: 'مخطط المناسبة',
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: AppColors.gradientChampagne,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.champagne),
          boxShadow: AppColors.softShadow,
        ),
        child: Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.event_note_outlined, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('خطّط مناسبتك', style: AppTextStyles.h3),
              const SizedBox(height: 2),
              Text(
                'حدّد الضيوف والمنطقة والميزانية، ونرتب لك الخيارات بقواعد واضحة.',
                style: AppTextStyles.bodySmall,
              ),
            ]),
          ),
          const Icon(Icons.chevron_left_rounded, color: AppColors.primary),
        ]),
      ),
    );
  }
}

class _CategoryStrip extends ConsumerWidget {
  const _CategoryStrip({required this.categories, required this.padding});

  final List<SawaCategory> categories;
  final double padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(categoryCountsProvider);
    // Categories with providers first, then the honest "coming soon" ones.
    final sorted = [...categories]..sort((a, b) {
        final ca = (counts[a.id] ?? 0) > 0 ? 0 : 1;
        final cb = (counts[b.id] ?? 0) > 0 ? 0 : 1;
        return ca != cb ? ca.compareTo(cb) : a.sortOrder.compareTo(b.sortOrder);
      });
    return SizedBox(
      height: 124,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: padding),
        scrollDirection: Axis.horizontal,
        itemCount: sorted.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final c = sorted[i];
          final n = counts[c.id] ?? 0;
          return _CategoryTile(category: c, count: n);
        },
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.count});

  final SawaCategory category;
  final int count;

  @override
  Widget build(BuildContext context) {
    final active = count > 0;
    return Pressable(
      onTap: () => context.pushNamed(AppRoute.category, pathParameters: {'categoryId': category.id}),
      semanticLabel: category.nameAr,
      child: Container(
        width: 136,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: active ? AppColors.surface : AppColors.surfaceWarm,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: active ? AppColors.border : AppColors.borderLight),
          boxShadow: active ? AppColors.softShadow : null,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: active ? AppColors.primaryLight : AppColors.borderLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(categoryIcon(category.id), color: active ? AppColors.primary : AppColors.textHint, size: 22),
          ),
          const Spacer(),
          Text(category.nameAr,
              style: AppTextStyles.bodySmall.copyWith(
                color: active ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Text(active ? '$count مزود' : 'قريباً', style: AppTextStyles.caption),
        ]),
      ),
    );
  }
}

class _CategoryCarousel extends StatelessWidget {
  const _CategoryCarousel({required this.category, required this.providers, required this.padding});

  final SawaCategory category;
  final List<SawaProvider> providers;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ContentFrame(
        child: Padding(
          padding: EdgeInsets.fromLTRB(padding, 28, padding, 12),
          child: SectionHeader(
            title: category.nameAr,
            actionLabel: 'عرض الكل',
            onAction: () => context.pushNamed(AppRoute.category, pathParameters: {'categoryId': category.id}),
          ),
        ),
      ),
      SizedBox(
        height: 356,
        child: ListView.separated(
          padding: EdgeInsets.symmetric(horizontal: padding, vertical: 4),
          scrollDirection: Axis.horizontal,
          itemCount: providers.length,
          separatorBuilder: (_, __) => const SizedBox(width: 14),
          itemBuilder: (context, i) => SizedBox(
            width: 260,
            child: ProviderCard(
              provider: providers[i],
              onTap: () => context.pushNamed(AppRoute.providerDetails, pathParameters: {'providerId': providers[i].id}),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    const steps = [
      (Icons.search_rounded, 'اكتشف', 'تصفّح المزودين بصور ومعلومات منظمة — بدون حساب.'),
      (Icons.send_outlined, 'اطلب التواصل', 'أرسل طلبك برقمك فقط، وتحصل على رقم مرجعي.'),
      (Icons.support_agent_outlined, 'فريق SAWA يتابع', 'فريقنا يتواصل معك ومع المزود لإكمال طلبك.'),
    ];
    return SurfaceCard(
      color: AppColors.surfaceWarm,
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('كيف يعمل SAWA؟', style: AppTextStyles.h3),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth > 640;
          final items = [
            for (final (i, s) in steps.indexed) _Step(number: i + 1, icon: s.$1, title: s.$2, body: s.$3),
          ];
          return wide
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (final w in items)
                    Expanded(child: Padding(padding: const EdgeInsetsDirectional.only(end: 16), child: w)),
                ])
              : Column(children: [
                  for (final w in items) Padding(padding: const EdgeInsets.only(bottom: 14), child: w),
                ]);
        }),
      ]),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.icon, required this.title, required this.body});

  final int number;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CircleAvatar(
        radius: 18,
        backgroundColor: AppColors.primaryLight,
        child: Icon(icon, size: 18, color: AppColors.primary),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$number. $title', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
          Text(body, style: AppTextStyles.bodySmall),
        ]),
      ),
    ]);
  }
}
