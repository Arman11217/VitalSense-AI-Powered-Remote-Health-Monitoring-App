import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ai_analysis/presentation/ai_analysis_screen.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../ecg/presentation/ecg_screen.dart';
import '../../history/presentation/history_screen.dart';
import '../../profile/presentation/profile_screen.dart';

/// Indexed bottom navigation tabs.
const List<_NavTab> _tabs = <_NavTab>[
  _NavTab(
    label: 'Home',
    icon: Icons.dashboard_rounded,
    selectedIcon: Icons.dashboard_rounded,
    route: '/home',
  ),
  _NavTab(
    label: 'ECG',
    icon: Icons.monitor_heart_outlined,
    selectedIcon: Icons.monitor_heart_rounded,
    route: '/home/ecg',
  ),
  _NavTab(
    label: 'AI',
    icon: Icons.psychology_outlined,
    selectedIcon: Icons.psychology_rounded,
    route: '/home/ai',
  ),
  _NavTab(
    label: 'History',
    icon: Icons.history_rounded,
    selectedIcon: Icons.history_rounded,
    route: '/home/history',
  ),
  _NavTab(
    label: 'Profile',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
    route: '/home/profile',
  ),
];

class _NavTab {
  const _NavTab({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
  });
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;
}

/// Persistent bottom-nav shell that wraps every `/home/*` sub-route.
///
/// We derive both the active tab index and the screen content from the
/// current `GoRouterState.uri`. This keeps the shell compatible with
/// plain nested `GoRoute`s instead of `StatefulShellRoute.indexedStack`,
/// whose branch paths were not being registered as top-level routes —
/// a redirect returning `/home` fell through to `errorBuilder`.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, this.child});

  /// The matched sub-screen (e.g. dashboard, ecg, …). When omitted the
  /// shell hosts an [IndexedStack] of all branches so the bottom-nav
  /// remains usable on the bare `/home` location.
  final Widget? child;

  int _indexFor(String location) {
    if (location.startsWith('/home/ecg')) return 1;
    if (location.startsWith('/home/ai')) return 2;
    if (location.startsWith('/home/history')) return 3;
    if (location.startsWith('/home/profile')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final GoRouterState state = GoRouterState.of(context);
    final int current = _indexFor(state.matchedLocation);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final Widget body = child ??
        IndexedStack(
          index: current,
          children: const <Widget>[
            DashboardScreen(),
            EcgScreen(),
            AiAnalysisScreen(),
            HistoryScreen(),
            ProfileScreen(),
          ],
        );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: current,
        onDestinationSelected: (int i) => context.go(_tabs[i].route),
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.18),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: <NavigationDestination>[
          for (int i = 0; i < _tabs.length; i++)
            NavigationDestination(
              icon: Icon(_tabs[i].icon),
              selectedIcon: Icon(_tabs[i].selectedIcon),
              label: _tabs[i].label,
            ),
        ],
      ),
    );
  }
}

/// Top-level branch builders consumed by the nested `GoRoute`s in
/// `app_router.dart`. Kept as plain widgets (no params) so they can be
/// used as `GoRoute` builders directly.
class HomeBranches {
  HomeBranches._();

  static final List<WidgetBuilder> builders = <WidgetBuilder>[
    (BuildContext _) => const DashboardScreen(),
    (BuildContext _) => const EcgScreen(),
    (BuildContext _) => const AiAnalysisScreen(),
    (BuildContext _) => const HistoryScreen(),
    (BuildContext _) => const ProfileScreen(),
  ];
}
