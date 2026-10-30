import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sana/features/auth/models/app_user.dart';
import 'package:sana/features/incidents/cubit/incident_filter_cubit.dart';
import 'package:sana/features/incidents/cubit/report_form_cubit.dart';
import 'package:sana/features/incidents/data/incident_repository.dart';
import 'package:sana/features/incidents/models/incident.dart';
import 'package:sana/features/incidents/models/incident_enums.dart';
import 'package:sana/features/incidents/models/incident_filter.dart';

import '../../helpers/fakes.dart';

/// State that must survive leaving a page, switching tabs, and restarting.
void main() {
  late MemoryStorage storage;

  setUpAll(() {
    registerFallbackValue(const IncidentDraft());
    registerFallbackValue(student);
  });

  setUp(() {
    storage = MemoryStorage();
    HydratedBloc.storage = storage;
  });

  group('IncidentFilterCubit', () {
    test('a new instance (next page visit or app restart) restores the filter', () {
      IncidentFilterCubit(storageId: 'feed-filter-stu1')
        ..toggleCategory(IncidentCategory.water)
        ..toggleStatus(IncidentStatus.inProgress)
        ..setQuery('block b')
        ..setSort(IncidentSort.mostAffected);

      final restored = IncidentFilterCubit(storageId: 'feed-filter-stu1');
      expect(restored.state.categories, {IncidentCategory.water});
      expect(restored.state.statuses, {IncidentStatus.inProgress});
      expect(restored.state.query, 'block b');
      expect(restored.state.sort, IncidentSort.mostAffected);
    });

    test('different users on the same phone do not share filters', () {
      IncidentFilterCubit(storageId: 'feed-filter-stu1').toggleCategory(IncidentCategory.safety);
      expect(IncidentFilterCubit(storageId: 'feed-filter-stu2').state.categories, isEmpty);
    });

    test('staff start on the open queue sorted by severity', () {
      final c = IncidentFilterCubit(
        storageId: 'staff-filter-staff1',
        initial: const IncidentFilter(
          statuses: {IncidentStatus.submitted, IncidentStatus.acknowledged, IncidentStatus.inProgress},
          sort: IncidentSort.severity,
        ),
      );
      expect(c.state.statuses.length, 3);
      expect(c.state.sort, IncidentSort.severity);
    });

    blocTest<IncidentFilterCubit, IncidentFilter>(
      'clearFilters keeps the chosen sort',
      build: () => IncidentFilterCubit(storageId: 'x'),
      act: (c) => c
        ..setSort(IncidentSort.severity)
        ..toggleCategory(IncidentCategory.water)
        ..clearFilters(),
      skip: 2,
      expect: () => [const IncidentFilter(sort: IncidentSort.severity)],
    );
  });

  group('ReportFormCubit draft', () {
    late MockIncidentRepository repo;

    setUp(() => repo = MockIncidentRepository());

    IncidentDraft complete() => const IncidentDraft(
          category: IncidentCategory.water,
          area: CampusArea.residence,
          title: 'No water in Block B',
          description: 'The third floor showers have had no water since morning.',
          locationDetail: 'Block B, 3rd floor',
          severity: Severity.high,
        );

    test('an unfinished report is restored the next time the form opens', () {
      ReportFormCubit(repository: repo).update(const IncidentDraft(title: 'Leaking roof', category: IncidentCategory.facilities));

      final reopened = ReportFormCubit(repository: repo);
      expect(reopened.state.draft.title, 'Leaking roof');
      expect(reopened.state.draft.category, IncidentCategory.facilities);
      expect(reopened.state.restored, isTrue);
    });

    test('edit mode never touches the saved draft', () {
      ReportFormCubit(repository: repo).update(const IncidentDraft(title: 'My new draft'));
      ReportFormCubit(repository: repo, editing: incident()).update(const IncidentDraft(title: 'Edited title'));
      expect(ReportFormCubit(repository: repo).state.draft.title, 'My new draft');
    });

    blocTest<ReportFormCubit, ReportFormState>(
      'refuses to submit an incomplete report and says what is missing',
      build: () => ReportFormCubit(repository: repo),
      act: (c) => c.submit(student),
      expect: () => [
        isA<ReportFormState>()
            .having((s) => s.submit, 'submit', FormSubmit.failure)
            .having((s) => s.message, 'message', 'Choose a category'),
      ],
      verify: (_) => verifyNever(() => repo.create(draft: any(named: 'draft'), user: any(named: 'user'))),
    );

    blocTest<ReportFormCubit, ReportFormState>(
      'applies the 60 second cooldown before calling the server',
      build: () => ReportFormCubit(repository: repo),
      seed: () => ReportFormState(draft: complete()),
      act: (c) => c.submit(
        AppUser(
          uid: student.uid,
          email: student.email,
          displayName: student.displayName,
          role: UserRole.student,
          lastReportAt: DateTime(2026, 10, 30, 10, 0, 0),
        ),
        now: DateTime(2026, 10, 30, 10, 0, 20),
      ),
      expect: () => [
        isA<ReportFormState>().having((s) => s.message, 'message', contains('40s')),
      ],
    );

    blocTest<ReportFormCubit, ReportFormState>(
      'submits, reports success and clears the saved draft',
      setUp: () => when(() => repo.create(
            draft: any(named: 'draft'),
            user: any(named: 'user'),
            onProgress: any(named: 'onProgress'),
          )).thenAnswer((_) async => const CreateResult('new123')),
      build: () => ReportFormCubit(repository: repo),
      seed: () => ReportFormState(draft: complete()),
      act: (c) => c.submit(student),
      expect: () => [
        isA<ReportFormState>().having((s) => s.submit, 'submit', FormSubmit.submitting),
        isA<ReportFormState>()
            .having((s) => s.submit, 'submit', FormSubmit.success)
            .having((s) => s.resultId, 'id', 'new123'),
      ],
      verify: (_) => expect(ReportFormCubit(repository: repo).state.draft.isEmpty, isTrue),
    );
  });
}
