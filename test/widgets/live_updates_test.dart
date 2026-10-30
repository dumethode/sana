import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sana/core/theme/app_theme.dart';
import 'package:sana/features/auth/bloc/auth_bloc.dart';
import 'package:sana/features/auth/models/app_user.dart';
import 'package:sana/features/incidents/bloc/incident_list_bloc.dart';
import 'package:sana/features/incidents/cubit/incident_filter_cubit.dart';
import 'package:sana/features/incidents/models/incident.dart';
import 'package:sana/features/incidents/models/incident_enums.dart';
import 'package:sana/features/incidents/view/feed_page.dart';
import 'package:sana/features/incidents/view/staff_queue_page.dart';
import 'package:sana/features/shell/session.dart';

import '../helpers/fakes.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

/// One Firestore snapshot, several screens: when the stream behind FeedBloc
/// emits a new status, both the student feed and the staff dashboard change
/// without any refresh call. This is the behaviour shown live in the demo.
void main() {
  late StreamController<List<Incident>> snapshots;
  late MockIncidentRepository repo;
  late MockAuthBloc auth;

  setUp(() {
    HydratedBloc.storage = MemoryStorage();
    snapshots = StreamController<List<Incident>>.broadcast();
    repo = MockIncidentRepository();
    when(() => repo.watchRecent()).thenAnswer((_) => snapshots.stream);
    auth = MockAuthBloc();
    when(() => auth.state).thenReturn(
      const AuthState.authenticated(
        AuthAccount(uid: 'staff1', email: 'facilities@alueducation.com', emailVerified: true),
        staff,
      ),
    );
  });

  tearDown(() => snapshots.close());

  Widget harness(Widget child) => MaterialApp(
        theme: AppTheme.light(),
        home: MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: auth),
            BlocProvider<FeedBloc>(create: (_) => FeedBloc(repo)..add(const IncidentListSubscriptionRequested())),
            BlocProvider(create: (_) => IncidentFilterCubit(storageId: 'test')),
          ],
          child: Scaffold(body: child),
        ),
      );

  testWidgets('feed shows skeletons, then live data, then a status change', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    await tester.pumpWidget(harness(const FeedPage()));
    expect(find.bySemanticsLabel('Loading reports'), findsOneWidget);

    snapshots.add([incident()]);
    await tester.pumpAndSettle();
    expect(find.text('No water in Block B'), findsOneWidget);
    expect(find.text('Submitted'), findsOneWidget);

    snapshots.add([incident(status: IncidentStatus.inProgress)]);
    await tester.pumpAndSettle();
    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('Submitted'), findsNothing);
  });

  testWidgets('staff dashboard numbers follow the same stream', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    await tester.pumpWidget(harness(const StaffQueuePage()));
    snapshots.add([
      incident(id: 'a0001', severity: Severity.critical),
      incident(id: 'b0002'),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('2'), findsWidgets); // open
    expect(find.text('1'), findsWidgets); // critical

    snapshots.add([
      incident(id: 'a0001', severity: Severity.critical, status: IncidentStatus.resolved, resolvedAt: DateTime(2026, 10, 20, 12)),
      incident(id: 'b0002'),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('3h'), findsOneWidget); // median fix time appears
  });

  testWidgets('an empty search result offers a way out', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    await tester.pumpWidget(harness(const FeedPage()));
    snapshots.add([incident()]);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'zzz-no-match');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('No reports match'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.text('No water in Block B'), findsOneWidget);
  });
}
