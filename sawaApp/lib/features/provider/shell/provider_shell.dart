import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';

class ProviderShell extends StatelessWidget {
  const ProviderShell({super.key, required this.child});

  final Widget child;

  static const _tabs = [
    _Tab(route: AppRoute.providerDashboard, icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart, label: 'لوحة التحكم'),
    _Tab(route: AppRoute.providerServices, icon: Icons.design_services_outlined, activeIcon: Icons.design_services, label: 'خدماتي'),
    _Tab(route: AppRoute.providerRequests, icon: Icons.inbox_outlined, activeIcon: Icons.inbox, label: 'الطلبات'),
    _Tab(route: AppRoute.providerProfile, icon: Icons.person_outlined, activeIcon: Icons.person, label: 'حسابي'),
  ];

  int _activeIndex(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    if (path.startsWith('/p/services')) return 1;
    if (path.startsWith('/p/requests')) return 2;
    if (path.startsWith('/p/profile')) return 3;
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
