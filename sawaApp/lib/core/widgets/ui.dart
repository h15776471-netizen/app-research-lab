import 'package:flutter/material.dart';

import '../../data/models/catalog_models.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';

// ── Responsive ──────────────────────────────────────────────────────────────
abstract final class Breakpoints {
  static const tablet = 700.0;
  static const desktop = 1000.0;

  static bool isWide(BuildContext context) => MediaQuery.sizeOf(context).width >= desktop;

  /// Grid columns for provider cards at a given available width.
  static int cardColumns(double width) => width >= 1180
      ? 4
      : width >= 880
          ? 3
          : width >= 560
              ? 2
              : 1;
}

/// Centers content with a comfortable max width on tablet / desktop.
class ContentFrame extends StatelessWidget {
  const ContentFrame({super.key, required this.child, this.maxWidth = 1200});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );
}

double pagePadding(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  return w >= Breakpoints.desktop ? 32 : (w >= Breakpoints.tablet ? 24 : 16);
}

// ── Headings ────────────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.subtitle, this.actionLabel, this.onAction});

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                Flexible(child: Text(title, style: AppTextStyles.h2)),
              ]),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 12),
                  child: Text(subtitle!, style: AppTextStyles.bodySmall),
                ),
              ],
            ],
          ),
        ),
        if (actionLabel != null) TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

// ── Pills & tags ────────────────────────────────────────────────────────────
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, this.color = AppColors.primary, this.background, this.icon});

  final String label;
  final Color color;
  final Color? background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
        Text(label, style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// Honest data-quality tag for a field: nothing for confirmed/source data,
/// "غير مؤكد" for ambiguous data, "غير متوفر" for missing data.
class ProvenanceTag extends StatelessWidget {
  const ProvenanceTag({super.key, required this.status});

  final FieldStatus status;

  @override
  Widget build(BuildContext context) => switch (status) {
        FieldStatus.unverified =>
          const StatusPill(label: 'غير مؤكد', color: AppColors.warning, icon: Icons.help_outline),
        FieldStatus.missing =>
          const StatusPill(label: 'غير متوفر', color: AppColors.textSecondary, icon: Icons.remove_circle_outline),
        _ => const SizedBox.shrink(),
      };
}

// ── Loading skeletons ───────────────────────────────────────────────────────
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.height, this.width, this.radius = 12});

  final double? height;
  final double? width;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(widget.radius)),
      ),
    );
  }
}

class ProviderCardSkeleton extends StatelessWidget {
  const ProviderCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AspectRatio(aspectRatio: 4 / 3, child: Skeleton(radius: 18)),
      SizedBox(height: 12),
      Skeleton(height: 16, width: 180),
      SizedBox(height: 8),
      Skeleton(height: 12, width: 120),
    ]);
  }
}

// ── Micro-interaction ───────────────────────────────────────────────────────
/// Subtle press-down scale + hover lift for tappable cards.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, required this.onTap, this.semanticLabel});

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scale = _down ? 0.975 : (_hover ? 1.01 : 1.0);
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _down = true),
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// A card surface with the SAWA border + soft shadow.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.softShadow,
      ),
      child: child,
    );
  }
}

/// Info banner (offline mode, pending review, etc.).
class InfoBanner extends StatelessWidget {
  const InfoBanner(
      {super.key, required this.message, this.icon = Icons.info_outline, this.color = AppColors.info, this.action});

  final String message;
  final IconData icon;
  final Color color;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary))),
        if (action != null) action!,
      ]),
    );
  }
}
