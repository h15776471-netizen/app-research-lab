import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/ui.dart';
import '../../../data/data_providers.dart';
import '../../../data/models/catalog_models.dart';
import '../domain/provider_filter.dart';
import 'provider_card.dart';

/// Search + filter + results. With [fixedCategoryId] it is a category page;
/// without it, the Explore tab (all categories).
class ProviderBrowser extends ConsumerStatefulWidget {
  const ProviderBrowser({super.key, this.fixedCategoryId, this.initialQuery, this.header});

  final String? fixedCategoryId;
  final String? initialQuery;
  final Widget? header;

  @override
  ConsumerState<ProviderBrowser> createState() => _ProviderBrowserState();
}

class _ProviderBrowserState extends ConsumerState<ProviderBrowser> {
  late ProviderFilter _filter = ProviderFilter(query: widget.initialQuery ?? '', categoryId: widget.fixedCategoryId);
  late final _search = TextEditingController(text: widget.initialQuery ?? '');

  @override
  void didUpdateWidget(covariant ProviderBrowser old) {
    super.didUpdateWidget(old);
    if (old.initialQuery != widget.initialQuery && widget.initialQuery != null) {
      _search.text = widget.initialQuery!;
      _filter = _filter.copyWith(query: widget.initialQuery);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _set(ProviderFilter f) => setState(() => _filter = f);

  @override
  Widget build(BuildContext context) {
    final providers = ref.watch(providersProvider);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const <SawaCategory>[];
    final names = {for (final c in categories) c.id: c.nameAr};
    final counts = ref.watch(categoryCountsProvider);
    final pad = pagePadding(context);

    return providers.when(
      loading: () => CustomScrollView(slivers: [
        if (widget.header != null) SliverToBoxAdapter(child: widget.header),
        SliverPadding(
          padding: EdgeInsets.all(pad),
          sliver: SliverList.separated(
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (_, __) => const ProviderCardSkeleton(),
          ),
        ),
      ]),
      error: (e, _) => ErrorView(message: friendlyError(e), onRetry: () => ref.invalidate(providersProvider)),
      data: (all) {
        final scope = widget.fixedCategoryId == null
            ? (_filter.categoryId == null ? all : all.where((p) => p.categoryId == _filter.categoryId).toList())
            : all.where((p) => p.categoryId == widget.fixedCategoryId).toList();
        final options = FilterOptions.from(scope);
        final results = applyProviderFilter(all, _filter);

        return CustomScrollView(slivers: [
          if (widget.header != null) SliverToBoxAdapter(child: widget.header),
          SliverToBoxAdapter(
            child: ContentFrame(
              child: Padding(
                padding: EdgeInsets.fromLTRB(pad, 16, pad, 4),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      onChanged: (v) => _set(_filter.copyWith(query: v)),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'ابحث بالاسم، المنطقة أو الخدمة',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _filter.query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'مسح',
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  _search.clear();
                                  _set(_filter.copyWith(query: ''));
                                },
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Badge(
                    isLabelVisible: _filter.hasActiveFilters,
                    backgroundColor: AppColors.accent,
                    smallSize: 10,
                    child: IconButton.filledTonal(
                      tooltip: 'الفلاتر والترتيب',
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primaryLight,
                        foregroundColor: AppColors.primary,
                        minimumSize: const Size(52, 52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.card)),
                      ),
                      onPressed: () => _openFilters(context, options),
                      icon: const Icon(Icons.tune_rounded),
                    ),
                  ),
                ]),
              ),
            ),
          ),
          if (widget.fixedCategoryId == null)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 56,
                child: ListView(
                  padding: EdgeInsets.symmetric(horizontal: pad, vertical: 8),
                  scrollDirection: Axis.horizontal,
                  children: [
                    _chip('الكل', _filter.categoryId == null,
                        () => _set(_filter.copyWith(categoryId: () => null).cleared())),
                    for (final c in categories.where((c) => (counts[c.id] ?? 0) > 0))
                      _chip(c.nameAr, _filter.categoryId == c.id,
                          () => _set(_filter.copyWith(categoryId: () => c.id).cleared())),
                  ],
                ),
              ),
            ),
          if (_filter.hasActiveFilters)
            SliverToBoxAdapter(
              child: ContentFrame(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: pad),
                  child: Wrap(spacing: 8, runSpacing: 4, children: [
                    if (_filter.area != null)
                      InputChip(label: Text(_filter.area!), onDeleted: () => _set(_filter.copyWith(area: () => null))),
                    if (_filter.maxPrice != null)
                      InputChip(
                          label: Text('حتى ${formatIqd(_filter.maxPrice!)}'),
                          onDeleted: () => _set(_filter.copyWith(maxPrice: () => null))),
                    if (_filter.minCapacity != null)
                      InputChip(
                          label: Text('${_filter.minCapacity}+ ضيف'),
                          onDeleted: () => _set(_filter.copyWith(minCapacity: () => null))),
                    if (_filter.offersOnly)
                      InputChip(
                          label: const Text('عروض فقط'), onDeleted: () => _set(_filter.copyWith(offersOnly: false))),
                  ]),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: ContentFrame(
              child: Padding(
                padding: EdgeInsets.fromLTRB(pad, 8, pad, 8),
                child: Text(
                  results.isEmpty ? '' : '${results.length} نتيجة',
                  style: AppTextStyles.caption,
                ),
              ),
            ),
          ),
          if (results.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyStateView(
                icon: scope.isEmpty ? Icons.hourglass_empty_rounded : Icons.search_off_rounded,
                title: scope.isEmpty ? 'لا يوجد مزودون في هذه الفئة بعد' : 'لا توجد نتائج مطابقة',
                message: scope.isEmpty
                    ? 'نضيف المزودين فقط بعد التأكد من بياناتهم. تابعنا قريباً.'
                    : 'جرّب كلمة بحث أخرى أو أزل بعض الفلاتر.',
                actionLabel: _filter.hasActiveFilters || _filter.query.isNotEmpty ? 'مسح البحث والفلاتر' : null,
                action: () {
                  _search.clear();
                  _set(ProviderFilter(categoryId: widget.fixedCategoryId ?? _filter.categoryId));
                },
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, 0, pad, 32),
              sliver: SliverConstrainedCrossAxis(
                maxExtent: 1200,
                sliver: ProviderGrid(
                  providers: results,
                  categoryNames: widget.fixedCategoryId == null ? names : const {},
                  onTap: (p) => context.pushNamed(AppRoute.providerDetails, pathParameters: {'providerId': p.id}),
                ),
              ),
            ),
        ]);
      },
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          selectedColor: AppColors.primary,
          labelStyle: AppTextStyles.bodySmall.copyWith(
            color: selected ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          showCheckmark: false,
        ),
      );

  Future<void> _openFilters(BuildContext context, FilterOptions o) async {
    final result = await showModalBottomSheet<ProviderFilter>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => _FilterSheet(initial: _filter, options: o),
    );
    if (result != null) _set(result);
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial, required this.options});

  final ProviderFilter initial;
  final FilterOptions options;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late ProviderFilter f = widget.initial;

  @override
  Widget build(BuildContext context) {
    final o = widget.options;
    Widget title(String t) => Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 8),
          child: Text(t, style: AppTextStyles.h3),
        );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text('الفلاتر والترتيب', style: AppTextStyles.h2)),
            TextButton(onPressed: () => setState(() => f = f.cleared()), child: const Text('إعادة ضبط')),
          ]),
          Text('نعرض فقط الفلاتر التي تدعمها بيانات المزودين الحالية.', style: AppTextStyles.caption),
          title('الترتيب'),
          SegmentedButton<ProviderSort>(
            segments: const [
              ButtonSegment(value: ProviderSort.recommended, label: Text('الأكمل بيانات')),
              ButtonSegment(value: ProviderSort.priceLow, label: Text('الأقل سعراً')),
              ButtonSegment(value: ProviderSort.name, label: Text('الاسم')),
            ],
            selected: {f.sort},
            onSelectionChanged: (s) => setState(() => f = f.copyWith(sort: s.first)),
          ),
          if (o.areas.isNotEmpty) ...[
            title('المنطقة'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final a in o.areas)
                ChoiceChip(
                  label: Text(a),
                  selected: f.area == a,
                  onSelected: (s) => setState(() => f = f.copyWith(area: () => s ? a : null)),
                ),
            ]),
          ],
          if (o.priceSteps.isNotEmpty) ...[
            title('السعر يبدأ من (حد أقصى)'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final p in o.priceSteps)
                ChoiceChip(
                  label: Text('حتى ${formatIqd(p)}'),
                  selected: f.maxPrice == p,
                  onSelected: (s) => setState(() => f = f.copyWith(maxPrice: () => s ? p : null)),
                ),
            ]),
            const SizedBox(height: 6),
            Text('المزودون بدون سعر معلن لا يظهرون عند تفعيل هذا الفلتر.', style: AppTextStyles.caption),
          ],
          if (o.hasCapacity) ...[
            title('عدد الضيوف'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final n in const [100, 200, 300, 500])
                ChoiceChip(
                  label: Text('$n+'),
                  selected: f.minCapacity == n,
                  onSelected: (s) => setState(() => f = f.copyWith(minCapacity: () => s ? n : null)),
                ),
            ]),
            const SizedBox(height: 6),
            Text('السعة معروفة لبعض القاعات فقط.', style: AppTextStyles.caption),
          ],
          if (o.hasOffers) ...[
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('عروض حالية فقط'),
              value: f.offersOnly,
              onChanged: (v) => setState(() => f = f.copyWith(offersOnly: v)),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(context, f),
            child: const Text('عرض النتائج'),
          ),
        ]),
      ),
    );
  }
}
