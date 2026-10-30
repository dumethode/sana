import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../shell/session.dart';
import '../bloc/incident_list_bloc.dart';
import '../cubit/incident_filter_cubit.dart';
import '../logic/incident_query.dart';
import '../models/incident.dart';
import '../models/incident_filter.dart';
import 'incident_detail_page.dart';
import 'widgets/filter_bar.dart';
import 'widgets/incident_card.dart';

/// Campus-wide list of recent reports with search, filters and sort.
class FeedPage extends StatelessWidget {
  const FeedPage({super.key, this.title = 'Campus reports'});

  final String title;

  @override
  Widget build(BuildContext context) {
    final list = context.watch<FeedBloc>().state;
    final filter = context.watch<IncidentFilterCubit>().state;
    final uid = context.select<AuthBloc, String?>((b) => b.state.user?.uid);
    final visible = IncidentQuery.apply(list.items, filter);
    final open = list.items.where((i) => i.status.isOpen).length;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Gap.l, Gap.l, Gap.l, Gap.l),
              child: _Header(title: title, open: open, live: list.status == ListStatus.ready),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: FilterBar()),
        const SliverToBoxAdapter(child: SizedBox(height: Gap.s)),
        ..._body(context, list, filter, visible, uid),
      ],
    );
  }

  List<Widget> _body(
    BuildContext context,
    IncidentListState list,
    IncidentFilter filter,
    List<Incident> visible,
    String? uid,
  ) {
    if (list.status == ListStatus.loading && list.items.isEmpty) {
      return const [SliverFillRemaining(hasScrollBody: true, child: TicketSkeletonList())];
    }
    if (list.status == ListStatus.failure && list.items.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorState(
            message: list.message ?? 'Unknown error',
            onRetry: () => context.read<FeedBloc>().add(const IncidentListSubscriptionRequested()),
          ),
        ),
      ];
    }
    if (visible.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: filter.isActive
              ? EmptyState(
                  icon: Icons.search_off,
                  title: 'No reports match',
                  message: 'Try another word or remove a filter.',
                  action: OutlinedButton(
                    onPressed: () => context.read<IncidentFilterCubit>().clearFilters(),
                    child: const Text('Clear filters'),
                  ),
                )
              : const EmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'Nothing reported yet',
                  message: 'When someone reports a campus issue it shows up here in real time.',
                ),
        ),
      ];
    }
    return [
      ResponsiveSliverList(
        items: visible,
        itemBuilder: (context, incident) => IncidentCard(
          incident: incident,
          viewerUid: uid,
          onTap: () => Navigator.of(context).push(
            SessionScope.route(context, IncidentDetailPage(incidentId: incident.id)),
          ),
        ),
      ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.open, required this.live});

  final String title;
  final int open;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.text.displaySmall),
              const SizedBox(height: 4),
              Text('$open open across campus', style: context.text.bodySmall),
            ],
          ),
        ),
        if (live)
          Tooltip(
            message: 'Connected. New reports and status changes appear instantly.',
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: AppColors.statusResolved, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text('LIVE', style: monoStyle(context, color: p.inkMuted, size: 11)),
              ],
            ),
          ),
      ],
    );
  }
}
