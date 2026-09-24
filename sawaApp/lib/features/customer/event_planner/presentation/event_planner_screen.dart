import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';

// Event service type for planner (broader than ProviderCategory)
enum EventServiceType {
  hall,
  photography,
  decor,
  catering,
  music,
  invitation,
}

extension EventServiceTypeX on EventServiceType {
  String get labelAr => switch (this) {
        EventServiceType.hall => 'قاعة',
        EventServiceType.photography => 'تصوير',
        EventServiceType.decor => 'ديكور',
        EventServiceType.catering => 'تموين',
        EventServiceType.music => 'موسيقى',
        EventServiceType.invitation => 'دعوات',
      };

  String get emoji => switch (this) {
        EventServiceType.hall => '🏛️',
        EventServiceType.photography => '📸',
        EventServiceType.decor => '✨',
        EventServiceType.catering => '🍽️',
        EventServiceType.music => '🎵',
        EventServiceType.invitation => '📜',
      };
}

enum EventType { wedding, engagement, birthday, graduation, corporate, other }

extension EventTypeX on EventType {
  String get labelAr => switch (this) {
        EventType.wedding => 'زفاف',
        EventType.engagement => 'خطوبة',
        EventType.birthday => 'عيد ميلاد',
        EventType.graduation => 'تخرج',
        EventType.corporate => 'مناسبة عمل',
        EventType.other => 'أخرى',
      };

  String get emoji => switch (this) {
        EventType.wedding => '💍',
        EventType.engagement => '💕',
        EventType.birthday => '🎂',
        EventType.graduation => '🎓',
        EventType.corporate => '💼',
        EventType.other => '🎉',
      };
}

// Planner state
class _PlannerState {
  const _PlannerState({
    this.step = 0,
    this.eventType,
    this.services = const {},
    this.guestCount,
    this.notes = '',
  });

  final int step;
  final EventType? eventType;
  final Set<EventServiceType> services;
  final int? guestCount;
  final String notes;

  _PlannerState copyWith({
    int? step,
    EventType? eventType,
    Set<EventServiceType>? services,
    int? guestCount,
    String? notes,
  }) {
    return _PlannerState(
      step: step ?? this.step,
      eventType: eventType ?? this.eventType,
      services: services ?? this.services,
      guestCount: guestCount ?? this.guestCount,
      notes: notes ?? this.notes,
    );
  }
}

class _PlannerNotifier extends Notifier<_PlannerState> {
  @override
  _PlannerState build() => const _PlannerState();

  void setEventType(EventType type) =>
      state = state.copyWith(eventType: type, step: 1);

  void toggleService(EventServiceType s) {
    final updated = Set<EventServiceType>.from(state.services);
    if (updated.contains(s)) {
      updated.remove(s);
    } else {
      updated.add(s);
    }
    state = state.copyWith(services: updated);
  }

  void setGuestCount(int count) => state = state.copyWith(guestCount: count);
  void setNotes(String notes) => state = state.copyWith(notes: notes);
  void goTo(int step) => state = state.copyWith(step: step);
  void reset() => state = const _PlannerState();
}

final _plannerProvider = NotifierProvider<_PlannerNotifier, _PlannerState>(
  _PlannerNotifier.new,
);

// Main screen

class EventPlannerScreen extends ConsumerWidget {
  const EventPlannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_plannerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('خطّط مناسبتك'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            ref.read(_plannerProvider.notifier).reset();
            context.goNamed(AppRoute.customerHome);
          },
        ),
      ),
      body: Column(
        children: [
          _StepIndicator(currentStep: state.step, totalSteps: 3),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: switch (state.step) {
                0 => const _StepEventType(),
                1 => const _StepServices(),
                2 => const _StepDetails(),
                _ => const _StepDone(),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep, required this.totalSteps});

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: List.generate(
          totalSteps,
          (i) => Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: i < totalSteps - 1 ? 4 : 0),
              decoration: BoxDecoration(
                color: i <= currentStep
                    ? AppColors.primary
                    : AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Step 1: Event type

class _StepEventType extends ConsumerWidget {
  const _StepEventType();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text('نوع المناسبة', style: AppTextStyles.h1),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'ما نوع المناسبة التي تخطط لها؟',
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),
        ...EventType.values.map(
          (t) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppSelectCard(
              label: t.labelAr,
              emoji: t.emoji,
              isSelected: false,
              onTap: () =>
                  ref.read(_plannerProvider.notifier).setEventType(t),
            ),
          ),
        ),
      ],
    );
  }
}

// Step 2: Services

class _StepServices extends ConsumerWidget {
  const _StepServices();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_plannerProvider);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text('الخدمات المطلوبة', style: AppTextStyles.h1),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'اختر الخدمات التي تحتاجها (يمكن اختيار أكثر من خدمة)',
                style:
                    AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xl),
              ...EventServiceType.values.map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppSelectCard(
                    label: s.labelAr,
                    emoji: s.emoji,
                    isSelected: state.services.contains(s),
                    onTap: () =>
                        ref.read(_plannerProvider.notifier).toggleService(s),
                  ),
                ),
              ),
            ],
          ),
        ),
        _StepNav(
          onBack: () => ref.read(_plannerProvider.notifier).goTo(0),
          onNext: state.services.isNotEmpty
              ? () => ref.read(_plannerProvider.notifier).goTo(2)
              : null,
          nextLabel: 'التالي',
        ),
      ],
    );
  }
}

// Step 3: Details

class _StepDetails extends ConsumerStatefulWidget {
  const _StepDetails();

  @override
  ConsumerState<_StepDetails> createState() => _StepDetailsState();
}

class _StepDetailsState extends ConsumerState<_StepDetails> {
  final _notesCtrl = TextEditingController();
  int _guests = 50;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text('تفاصيل إضافية', style: AppTextStyles.h1),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'هذه المعلومات تساعدنا في تقديم أنسب المزودين',
                style:
                    AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Guest count
              Text('عدد الضيوف المتوقع', style: AppTextStyles.h3),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      if (_guests > 10) {
                        setState(() => _guests -= 10);
                        ref
                            .read(_plannerProvider.notifier)
                            .setGuestCount(_guests);
                      }
                    },
                    icon: const Icon(Icons.remove_circle_outline),
                    color: AppColors.primary,
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        '$_guests ضيف',
                        style: AppTextStyles.h2,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      if (_guests < 1000) {
                        setState(() => _guests += 10);
                        ref
                            .read(_plannerProvider.notifier)
                            .setGuestCount(_guests);
                      }
                    },
                    icon: const Icon(Icons.add_circle_outline),
                    color: AppColors.primary,
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xl),

              // Notes
              Text('ملاحظات إضافية (اختياري)', style: AppTextStyles.h3),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _notesCtrl,
                maxLines: 4,
                onChanged: (v) =>
                    ref.read(_plannerProvider.notifier).setNotes(v),
                decoration: const InputDecoration(
                  hintText:
                      'أي تفاصيل إضافية عن مناسبتك...',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        _StepNav(
          onBack: () => ref.read(_plannerProvider.notifier).goTo(1),
          onNext: () {
            ref.read(_plannerProvider.notifier).setGuestCount(_guests);
            ref.read(_plannerProvider.notifier).goTo(3);
          },
          nextLabel: 'إنهاء التخطيط',
        ),
      ],
    );
  }
}

// Done step

class _StepDone extends ConsumerWidget {
  const _StepDone();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_plannerProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: AppColors.successLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline,
              color: AppColors.success,
              size: 44,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'تم تسجيل مناسبتك!',
            style: AppTextStyles.h1,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'تصفّح المزودين الآن وتواصل مع من يناسبك',
            style:
                AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),

          // Summary
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state.eventType != null)
                  _SummaryRow(
                    label: 'نوع المناسبة',
                    value:
                        '${state.eventType!.emoji} ${state.eventType!.labelAr}',
                  ),
                if (state.services.isNotEmpty)
                  _SummaryRow(
                    label: 'الخدمات',
                    value: state.services.map((s) => s.labelAr).join('، '),
                  ),
                if (state.guestCount != null)
                  _SummaryRow(
                    label: 'عدد الضيوف',
                    value: '${state.guestCount} ضيف',
                  ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
          AppPrimaryButton(
            label: 'تصفّح المزودين',
            onPressed: () {
              ref.read(_plannerProvider.notifier).reset();
              context.goNamed(AppRoute.explore);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          AppGhostButton(
            label: 'العودة للرئيسية',
            onPressed: () {
              ref.read(_plannerProvider.notifier).reset();
              context.goNamed(AppRoute.customerHome);
            },
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textHint,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Navigation buttons

class _StepNav extends StatelessWidget {
  const _StepNav({
    required this.onBack,
    required this.onNext,
    required this.nextLabel,
  });

  final VoidCallback onBack;
  final VoidCallback? onNext;
  final String nextLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: AppSecondaryButton(
              label: 'رجوع',
              onPressed: onBack,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: AppPrimaryButton(
              label: nextLabel,
              onPressed: onNext,
            ),
          ),
        ],
      ),
    );
  }
}
