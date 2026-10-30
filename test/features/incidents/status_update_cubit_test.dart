import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sana/core/utils/failure.dart';
import 'package:sana/features/incidents/cubit/status_update_cubit.dart';
import 'package:sana/features/incidents/models/incident_enums.dart';

import '../../helpers/fakes.dart';

void main() {
  late MockIncidentRepository repo;
  final report = incident();

  setUpAll(() {
    registerFallbackValue(report);
    registerFallbackValue(staff);
    registerFallbackValue(IncidentStatus.submitted);
    registerFallbackValue(Severity.medium);
  });

  setUp(() => repo = MockIncidentRepository());

  When<Future<void>> stubChange() => when(() => repo.changeStatus(
        incident: any(named: 'incident'),
        to: any(named: 'to'),
        severity: any(named: 'severity'),
        note: any(named: 'note'),
        staff: any(named: 'staff'),
      ));

  test('offers only the legal next steps', () {
    final c = StatusUpdateCubit(repository: repo, incident: report, staff: staff);
    expect(c.options, [
      IncidentStatus.acknowledged,
      IncidentStatus.inProgress,
      IncidentStatus.resolved,
      IncidentStatus.rejected,
    ]);
    expect(c.state.target, IncidentStatus.acknowledged);
  });

  blocTest<StatusUpdateCubit, StatusUpdateState>(
    'a student account is refused even if the sheet is opened',
    build: () => StatusUpdateCubit(repository: repo, incident: report, staff: student),
    act: (c) => c.save('Looks fine'),
    expect: () => [isA<StatusUpdateState>().having((s) => s.status, 'status', UpdateStatus.failed)],
  );

  blocTest<StatusUpdateCubit, StatusUpdateState>(
    'resolving without a note is blocked before reaching the server',
    build: () => StatusUpdateCubit(repository: repo, incident: report, staff: staff),
    act: (c) => c
      ..selectTarget(IncidentStatus.resolved)
      ..save(''),
    skip: 1,
    expect: () => [isA<StatusUpdateState>().having((s) => s.message, 'message', contains('note'))],
  );

  blocTest<StatusUpdateCubit, StatusUpdateState>(
    'saves the change with the chosen severity',
    setUp: () => stubChange().thenAnswer((_) async {}),
    build: () => StatusUpdateCubit(repository: repo, incident: report, staff: staff),
    act: (c) => c
      ..selectSeverity(Severity.critical)
      ..save(''),
    skip: 1,
    expect: () => [
      isA<StatusUpdateState>().having((s) => s.status, 'status', UpdateStatus.saving),
      isA<StatusUpdateState>().having((s) => s.status, 'status', UpdateStatus.saved),
    ],
    verify: (_) => verify(() => repo.changeStatus(
          incident: report,
          to: IncidentStatus.acknowledged,
          severity: Severity.critical,
          note: '',
          staff: staff,
        )).called(1),
  );

  blocTest<StatusUpdateCubit, StatusUpdateState>(
    'shows the server refusal in plain language',
    setUp: () => stubChange().thenThrow(const Failure('You do not have permission to do that.', code: 'permission-denied')),
    build: () => StatusUpdateCubit(repository: repo, incident: report, staff: staff),
    act: (c) => c.save('On it'),
    expect: () => [
      isA<StatusUpdateState>().having((s) => s.status, 'status', UpdateStatus.saving),
      isA<StatusUpdateState>().having((s) => s.message, 'message', contains('permission')),
    ],
  );
}
