import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/responsive.dart';
import '../auth/models/app_user.dart';
import '../incidents/view/feed_page.dart';
import '../incidents/view/my_reports_page.dart';
import '../incidents/view/report_form_page.dart';
import '../incidents/view/staff_queue_page.dart';
import '../profile/profile_page.dart';
import 'session.dart';

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Signed-in root. Students and staff get different tabs tuned to their
/// job, but share one set of session blocs (see [SessionScope]).
/// Uses a bottom bar on phones and a navigation rail at 720 px and wider.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.user});

  final AppUser user;

  static Route<void> route(AppUser user) => PageRouteBuilder(
        pageBuilder: (_, _, _) => HomeShell(user: user),
        transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
      );

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  bool get _staff => widget.user.isStaff;

  List<_Destination> get _destinations => _staff
      ? const [
          _Destination('Queue', Icons.inbox_outlined, Icons.inbox),
          _Destination('All reports', Icons.dashboard_outlined, Icons.dashboard),
          _Destination('Profile', Icons.person_outline, Icons.person),
        ]
      : const [
          _Destination('Campus', Icons.dashboard_outlined, Icons.dashboard),
          _Destination('My reports', Icons.receipt_long_outlined, Icons.receipt_long),
          _Destination('Profile', Icons.person_outline, Icons.person),
        ];

  void _openReportForm(BuildContext context) {
    Navigator.of(context).push(SessionScope.route(context, const ReportFormPage(), fullscreenDialog: true));
  }

  Widget _page(BuildContext context, int index) {
    if (_staff) {
      return switch (index) {
        0 => const StaffQueuePage(),
        1 => const FeedPage(title: 'All reports'),
        _ => const ProfilePage(),
      };
    }
    return switch (index) {
      0 => const FeedPage(),
      1 => MyReportsPage(onReport: () => _openReportForm(context)),
      _ => const ProfilePage(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      user: widget.user,
      child: Builder(builder: (context) {
        final wide = Breakpoints.isWide(context);
        final showFab = !_staff && _index < 2;
        final fab = showFab
            ? FloatingActionButton.extended(
                heroTag: 'report',
                backgroundColor: context.palette.signal,
                foregroundColor: context.palette.onSignal,
                elevation: 0,
                highlightElevation: 0,
                onPressed: () => _openReportForm(context),
                icon: const Icon(Icons.add),
                label: const Text('Report'),
              )
            : null;

        // IndexedStack keeps each tab's scroll position when switching;
        // a tab is only built once it has been opened.
        final body = IndexedStack(
          index: _index,
          children: [
            for (var k = 0; k < _destinations.length; k++)
              _visited.contains(k) ? _page(context, k) : const SizedBox.shrink(),
          ],
        );

        if (wide) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: _select,
                  labelType: NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: [
                        const SanaMark(size: 36, showWordmark: false),
                        if (fab != null) ...[
                          const SizedBox(height: 16),
                          FloatingActionButton(
                            heroTag: 'report-rail',
                            tooltip: 'Report an issue',
                            backgroundColor: context.palette.signal,
                            foregroundColor: context.palette.onSignal,
                            elevation: 0,
                            onPressed: () => _openReportForm(context),
                            child: const Icon(Icons.add),
                          ),
                        ],
                      ],
                    ),
                  ),
                  destinations: [
                    for (final d in _destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
                        label: Text(d.label),
                      ),
                  ],
                ),
                VerticalDivider(width: 1, color: context.palette.line),
                Expanded(child: body),
              ],
            ),
          );
        }

        return Scaffold(
          body: body,
          floatingActionButton: fab,
          bottomNavigationBar: DecoratedBox(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: context.palette.line))),
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _select,
              destinations: [
                for (final d in _destinations)
                  NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label),
              ],
            ),
          ),
        );
      }),
    );
  }

  final Set<int> _visited = {0};

  void _select(int i) => setState(() {
        _index = i;
        _visited.add(i);
      });
}
