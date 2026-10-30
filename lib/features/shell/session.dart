import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../auth/bloc/auth_bloc.dart';
import '../auth/models/app_user.dart';
import '../incidents/bloc/incident_list_bloc.dart';
import '../incidents/cubit/incident_filter_cubit.dart';
import '../incidents/data/incident_repository.dart';
import '../incidents/models/incident_enums.dart';
import '../incidents/models/incident_filter.dart';

/// Live list of recent campus reports (feed, staff queue, stats).
class FeedBloc extends IncidentListBloc {
  FeedBloc(IncidentRepository repo) : super(repo.watchRecent);
}

/// Live list of the signed-in student's own reports.
class MyReportsBloc extends IncidentListBloc {
  MyReportsBloc(IncidentRepository repo, String uid) : super(() => repo.watchMine(uid));
}

/// Creates the blocs that live for the whole signed-in session and sit above
/// every tab. Filter storage is keyed by UID so two people sharing a phone
/// never see each other's saved searches.
class SessionScope extends StatelessWidget {
  const SessionScope({super.key, required this.user, required this.child});

  final AppUser user;
  final Widget child;

  static const openStatuses = {IncidentStatus.submitted, IncidentStatus.acknowledged, IncidentStatus.inProgress};

  @override
  Widget build(BuildContext context) {
    final repo = context.read<IncidentRepository>();
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => FeedBloc(repo)..add(const IncidentListSubscriptionRequested())),
        BlocProvider(
          create: (_) => MyReportsBloc(repo, user.uid)..add(const IncidentListSubscriptionRequested()),
        ),
        BlocProvider(
          create: (_) => IncidentFilterCubit(
            storageId: '${user.isStaff ? 'staff' : 'feed'}-filter-${user.uid}',
            initial: user.isStaff
                ? const IncidentFilter(statuses: openStatuses, sort: IncidentSort.severity)
                : const IncidentFilter(),
          ),
        ),
      ],
      child: child,
    );
  }

  /// Pushed pages are siblings of the shell in the Navigator, not children,
  /// so they re-receive the session blocs explicitly. This is what lets a
  /// detail page or the report form read the same live state as the tabs.
  static Route<T> route<T>(BuildContext context, Widget page, {bool fullscreenDialog = false}) {
    final feed = context.read<FeedBloc>();
    final mine = context.read<MyReportsBloc>();
    final filter = context.read<IncidentFilterCubit>();
    return MaterialPageRoute<T>(
      fullscreenDialog: fullscreenDialog,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: feed),
          BlocProvider.value(value: mine),
          BlocProvider.value(value: filter),
        ],
        child: page,
      ),
    );
  }
}

/// The signed-in user. Only valid below an authenticated shell.
extension CurrentUserX on BuildContext {
  AppUser get currentUser => read<AuthBloc>().state.user!;
}
