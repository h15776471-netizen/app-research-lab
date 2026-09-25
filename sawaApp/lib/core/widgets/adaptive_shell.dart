import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/sawa_wordmark.dart';
import '../theme/app_colors.dart';
import 'ui.dart';

class ShellDestination {
  const ShellDestination({required this.path, required this.icon, required this.activeIcon, required this.label});
  final String path;
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Bottom navigation on phones, a navigation rail on tablet / desktop.
class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({super.key, required this.destinations, required this.child, this.railFooter});

  final List<ShellDestination> destinations;
  final Widget child;
  final Widget? railFooter;

  int _index(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final i = destinations.indexWhere((d) => path.startsWith(d.path));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final index = _index(context);
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.tablet;
    if (wide) {
      final extended = MediaQuery.sizeOf(context).width >= Breakpoints.desktop;
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            extended: extended,
            minExtendedWidth: 220,
            selectedIndex: index,
            onDestinationSelected: (i) => context.go(destinations[i].path),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: SawaWordmark(size: extended ? 30 : 20),
            ),
            trailing: railFooter == null
                ? null
                : Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(padding: const EdgeInsets.only(bottom: 20), child: railFooter),
                    ),
                  ),
            destinations: [
              for (final d in destinations)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.activeIcon),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1, color: AppColors.border),
          Expanded(child: child),
        ]),
      );
    }
    return Scaffold(
      body: child,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) => context.go(destinations[i].path),
          destinations: [
            for (final d in destinations)
              NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.activeIcon), label: d.label),
          ],
        ),
      ),
    );
  }
}
