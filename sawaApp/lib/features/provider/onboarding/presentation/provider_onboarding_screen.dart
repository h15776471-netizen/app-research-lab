import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../providers_list/data/provider_category.dart';

class ProviderOnboardingScreen extends ConsumerStatefulWidget {
  const ProviderOnboardingScreen({super.key});

  @override
  ConsumerState<ProviderOnboardingScreen> createState() =>
      _ProviderOnboardingState();
}

class _ProviderOnboardingState
    extends ConsumerState<ProviderOnboardingScreen> {
  int _step = 0;
  ProviderCategory? _category;
  final _bioCtrl = TextEditingController();
  final _cityCtrl = TextEditingController(text: 'بغداد');

  @override
  void dispose() {
    _bioCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('إعداد الملف الشخصي'),
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new),
                onPressed: () => setState(() => _step--),
              )
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => context.goNamed(AppRoute.providerDashboard),
              ),
      ),
      body: Column(
        children: [
          _StepBar(current: _step, total: 2),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _step == 0
                  ? _CategoryStep(
                      key: const ValueKey(0),
                      selected: _category,
                      onSelect: (c) => setState(() {
                        _category = c;
                        _step = 1;
                      }),
                    )
                  : _ProfileStep(
                      key: const ValueKey(1),
                      bioCtrl: _bioCtrl,
                      cityCtrl: _cityCtrl,
                      onDone: _finish,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _finish() {
    // Profile data would be saved to Supabase provider_profiles table here.
    // For now, navigate to dashboard.
    context.goNamed(AppRoute.providerDashboard);
  }
}

class _StepBar extends StatelessWidget {
  const _StepBar({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Row(
        children: List.generate(
          total,
          (i) => Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: i < total - 1 ? 4 : 0),
              decoration: BoxDecoration(
                color: i <= current ? AppColors.primary : AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryStep extends StatelessWidget {
  const _CategoryStep({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final ProviderCategory? selected;
  final ValueChanged<ProviderCategory> onSelect;

  static const _items = [
    (ProviderCategory.hall, '🏛️', 'قاعات الأفراح'),
    (ProviderCategory.photography, '📸', 'تصوير المناسبات'),
    (ProviderCategory.decor, '✨', 'تزيين وديكور'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text('ما هي فئة خدمتك؟', style: AppTextStyles.h1),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'اختر الفئة الأنسب لتخصصك',
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),
        ..._items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: AppSelectCard(
              label: item.$3,
              emoji: item.$2,
              isSelected: selected == item.$1,
              onTap: () => onSelect(item.$1),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileStep extends StatefulWidget {
  const _ProfileStep({
    super.key,
    required this.bioCtrl,
    required this.cityCtrl,
    required this.onDone,
  });

  final TextEditingController bioCtrl;
  final TextEditingController cityCtrl;
  final VoidCallback onDone;

  @override
  State<_ProfileStep> createState() => _ProfileStepState();
}

class _ProfileStepState extends State<_ProfileStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text('معلومات الملف الشخصي', style: AppTextStyles.h1),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'هذه المعلومات ستظهر للعملاء الذين يبحثون عن خدماتك',
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xl),
              TextField(
                controller: widget.cityCtrl,
                decoration: const InputDecoration(
                  labelText: 'المدينة',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: widget.bioCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'نبذة عن خدمتك',
                  hintText: 'أخبر العملاء عن تخصصك وخبرتك...',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: AppPrimaryButton(
            label: 'حفظ وإكمال',
            onPressed: widget.onDone,
          ),
        ),
      ],
    );
  }
}
