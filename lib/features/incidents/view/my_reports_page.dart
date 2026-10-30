import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../shell/session.dart';
import '../bloc/incident_list_bloc.dart';
import '../models/incident.dart';
import 'incident_detail_page.dart';
import 'widgets/incident_card.dart';

/// The student's own reports, split into what is still open and what is done.
class MyReportsPage extends StatelessWidget {
  const MyReportsPage({super.key, required this.onReport});

  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MyReportsBloc>().state;
    final active = state.items.where((i) => i.status.isOpen).toList();
    final closed = state.items.where((i) => !i.status.isOpen).toList();
    return DefaultTabController(
      length: 2,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.l, Gap.l, Gap.l, Gap.s),
              child: Text('My reports', style: context.text.displaySmall),
            ),
            TabBar(
              labelStyle: context.text.labelLarge,
              indicatorColor: context.palette.signal,
              labelColor: context.palette.ink,
              unselectedLabelColor: context.palette.inkMuted,
              dividerColor: context.palette.line,
              tabs: [Tab(text: 'Active (${active.length})'), Tab(text: 'Closed (${closed.length})')],
            ),
            Expanded(
              child: switch (state.status) {
                ListStatus.loading when state.items.isEmpty => const TicketSkeletonList(count: 3),
                ListStatus.failure when state.items.isEmpty => ErrorState(
                    message: state.message ?? 'Unknown error',
                    onRetry: () => context.read<MyReportsBloc>().add(const IncidentListSubscriptionRequested()),
                  ),
                _ => TabBarView(
                    children: [
                      _List(
                        items: active,
                        empty: EmptyState(
                          icon: Icons.task_alt,
                          title: 'Nothing open',
                          message: 'When you report an issue you can follow every step from here.',
                          action: FilledButton.icon(
                            onPressed: onReport,
                            icon: const Icon(Icons.add),
                            label: const Text('Report an issue'),
                          ),
                        ),
                      ),
                      _List(
                        items: closed,
                        empty: const EmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: 'No closed reports yet',
                          message: 'Resolved and closed reports move here.',
                        ),
                      ),
                    ],
                  ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.items, required this.empty});

  final List<Incident> items;
  final Widget empty;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return empty;
    final uid = context.select<AuthBloc, String?>((b) => b.state.user?.uid);
    return CustomScrollView(
      slivers: [
        ResponsiveSliverList<Incident>(
          items: items,
          itemBuilder: (context, i) => IncidentCard(
            incident: i,
            viewerUid: uid,
            showSeverity: true,
            onTap: () => Navigator.of(context).push(SessionScope.route(context, IncidentDetailPage(incidentId: i.id))),
          ),
        ),
      ],
    );
  }
}
