import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../shell/session.dart';
import '../bloc/incident_list_bloc.dart';
import '../cubit/incident_filter_cubit.dart';
import '../logic/incident_query.dart';
import '../models/incident.dart';
import '../models/incident_enums.dart';
import '../models/incident_filter.dart';
import 'incident_detail_page.dart';
import 'widgets/filter_bar.dart';
import 'widgets/incident_card.dart';

/// Staff triage view: live numbers on top, then the queue ordered so the
/// most severe and longest-waiting reports come first.
class StaffQueuePage extends StatelessWidget {
  const StaffQueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    final list = context.watch<FeedBloc>().state;
    final filter = context.watch<IncidentFilterCubit>().state;
    final user = context.select<AuthBloc, String>((b) => b.state.user?.firstName ?? '');
    final dept = context.select<AuthBloc, String?>((b) => b.state.user?.department);
    final stats = IncidentStats.from(list.items);
    final filtered = IncidentQuery.apply(list.items, filter);
    final queue = filter.sort == IncidentSort.severity ? IncidentQuery.triage(filtered) : filtered;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Gap.l, Gap.l, Gap.l, Gap.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Overline(dept == null ? 'Staff' : 'Staff · $dept'),
                  const SizedBox(height: 4),
                  Text('Hi $user, here is the queue', style: context.text.headlineSmall),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.l),
            child: _StatsRow(stats: stats),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: Gap.l)),
        const SliverToBoxAdapter(child: FilterBar(hint: 'Search the queue')),
        const SliverToBoxAdapter(child: SizedBox(height: Gap.s)),
        if (list.status == ListStatus.loading && list.items.isEmpty)
          const SliverFillRemaining(child: TicketSkeletonList())
        else if (list.status == ListStatus.failure && list.items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: ErrorState(
              message: list.message ?? 'Unknown error',
              onRetry: () => context.read<FeedBloc>().add(const IncidentListSubscriptionRequested()),
            ),
          )
        else if (queue.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.verified_outlined,
              title: filter.isActive ? 'Queue clear for this filter' : 'Queue is clear',
              message: 'New reports land here the moment a student sends them.',
              action: filter.isActive
                  ? OutlinedButton(
                      onPressed: () => context.read<IncidentFilterCubit>().clearFilters(),
                      child: const Text('Show everything'),
                    )
                  : null,
            ),
          )
        else
          ResponsiveSliverList<Incident>(
            items: queue,
            itemBuilder: (context, i) => IncidentCard(
              incident: i,
              showSeverity: true,
              onTap: () =>
                  Navigator.of(context).push(SessionScope.route(context, IncidentDetailPage(incidentId: i.id))),
              trailing: i.status.isOpen ? _Waiting(since: i.createdAt) : null,
            ),
          ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final IncidentStats stats;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _Stat(label: 'Open', value: '${stats.open}', color: AppColors.statusAcknowledged),
      _Stat(label: 'Critical', value: '${stats.openCritical}', color: AppColors.statusRejected),
      _Stat(label: 'In progress', value: '${stats.byStatus[IncidentStatus.inProgress] ?? 0}', color: AppColors.statusInProgress),
      _Stat(
        label: 'Median fix',
        value: stats.medianResolution == null ? 'n/a' : TimeFormat.duration(stats.medianResolution!),
        color: AppColors.statusResolved,
      ),
    ];
    return LayoutBuilder(builder: (context, c) {
      final columns = c.maxWidth >= 560 ? 4 : 2;
      final w = (c.maxWidth - Gap.s * (columns - 1)) / columns;
      return Wrap(
        spacing: Gap.s,
        runSpacing: Gap.s,
        children: [for (final t in tiles) SizedBox(width: w, child: t)],
      );
    });
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(Gap.m),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Expanded(child: Overline(label)),
            ],
          ),
          const SizedBox(height: Gap.s),
          Text(value, style: context.text.displaySmall),
        ],
      ),
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting({required this.since});

  final DateTime since;

  @override
  Widget build(BuildContext context) {
    final waited = DateTime.now().difference(since);
    final late = waited > const Duration(hours: 48);
    return Text(
      'waiting ${TimeFormat.duration(waited)}',
      style: monoStyle(context, color: late ? AppColors.statusRejected : null),
    );
  }
}
