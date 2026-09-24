import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';

class CustomerShell extends StatelessWidget {
  const CustomerShell({super.key, required this.child});

  final Widget child;

  static const _tabs = [
    _Tab(route: AppRoute.customerHome, icon: Icons.home_outlined, activeIcon: Icons.home, label: 'الرئيسية'),
    _Tab(route: AppRoute.explore, icon: Icons.grid_view_outlined, activeIcon: Icons.grid_view, label: 'اكتشف'),
    _Tab(route: AppRoute.myRequests, icon: Icons.inbox_outlined, activeIcon: Icons.inbox, label: 'طلباتي'),
    _Tab(route: AppRoute.customerProfile, icon: Icons.person_outlined, activeIcon: Icons.person, label: 'حسابي'),
  ];

  int _activeIndex(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    if (path.startsWith('/c/explore')) return 1;
    if (path.startsWith('/c/requests')) return 2;
    if (path.startsWith('/c/profile')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _activeIndex(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: BottomNavigationBar(
          currentIndex: index,
          onTap: (i) => context.goNamed(_tabs[i].route),
          items: _tabs
              .asMap()
              .entries
              .map((e) => BottomNavigationBarItem(
                    icon: Icon(e.value.icon),
                    activeIcon: Icon(e.value.activeIcon),
                    label: e.value.label,
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _Tab {
  const _Tab({
    required this.route,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
  final String route;
  final IconData icon;
  final IconData activeIcon;
  final String label;
}
