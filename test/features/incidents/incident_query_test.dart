import 'package:flutter_test/flutter_test.dart';
import 'package:sana/features/incidents/logic/incident_query.dart';
import 'package:sana/features/incidents/models/incident_enums.dart';
import 'package:sana/features/incidents/models/incident_filter.dart';

import '../../helpers/fakes.dart';

void main() {
  final water = incident(id: 'w0001', title: 'No water in Block B', createdAt: DateTime(2026, 10, 20));
  final power = incident(
    id: 'p0002',
    title: 'Power cut in library',
    category: IncidentCategory.electricity,
    area: CampusArea.library,
    location: 'Ground floor reading room',
    severity: Severity.critical,
    createdAt: DateTime(2026, 10, 22),
    affectedBy: const ['a', 'b', 'c'],
  );
  final chair = incident(
    id: 'c0003',
    title: 'Broken chair',
    category: IncidentCategory.facilities,
    area: CampusArea.classrooms,
    location: 'Room 12',
    status: IncidentStatus.resolved,
    severity: Severity.low,
    createdAt: DateTime(2026, 10, 18),
    resolvedAt: DateTime(2026, 10, 19),
  );
  final all = [water, power, chair];

  group('apply', () {
    test('no filter returns everything, newest first', () {
      expect(IncidentQuery.apply(all, const IncidentFilter()).map((i) => i.id), ['p0002', 'w0001', 'c0003']);
    });

    test('search matches title, location and reference code, case-insensitively', () {
      expect(IncidentQuery.apply(all, const IncidentFilter(query: 'LIBRARY')).single.id, 'p0002');
      expect(IncidentQuery.apply(all, const IncidentFilter(query: 'block b')).single.id, 'w0001');
      expect(IncidentQuery.apply(all, const IncidentFilter(query: 'sn-c0003')).single.id, 'c0003');
    });

    test('category and status chips combine with AND', () {
      const f = IncidentFilter(
        categories: {IncidentCategory.water, IncidentCategory.facilities},
        statuses: {IncidentStatus.resolved},
      );
      expect(IncidentQuery.apply(all, f).single.id, 'c0003');
    });

    test('most affected puts the biggest crowd first', () {
      const f = IncidentFilter(sort: IncidentSort.mostAffected);
      expect(IncidentQuery.apply(all, f).first.id, 'p0002');
    });
  });

  test('triage: open before closed, then severity, then oldest first', () {
    final olderMedium = incident(id: 'old01', createdAt: DateTime(2026, 10, 1));
    final order = IncidentQuery.triage([chair, water, olderMedium, power]).map((i) => i.id).toList();
    expect(order, ['p0002', 'old01', 'w0001', 'c0003']);
  });

  group('similar (duplicate hint)', () {
    test('finds open reports in the same category and area within 14 days', () {
      final hits = IncidentQuery.similar(
        all,
        category: IncidentCategory.water,
        area: CampusArea.residence,
        now: DateTime(2026, 10, 25),
      );
      expect(hits.single.id, 'w0001');
    });

    test('ignores closed, old, or different-area reports', () {
      expect(
        IncidentQuery.similar(all, category: IncidentCategory.facilities, area: CampusArea.classrooms, now: DateTime(2026, 10, 20)),
        isEmpty,
        reason: 'the chair report is resolved',
      );
      expect(
        IncidentQuery.similar(all, category: IncidentCategory.water, area: CampusArea.residence, now: DateTime(2026, 11, 30)),
        isEmpty,
        reason: 'older than 14 days',
      );
    });

    test('returns nothing until both category and area are chosen', () {
      expect(IncidentQuery.similar(all, category: IncidentCategory.water, area: null), isEmpty);
    });
  });

  group('IncidentStats', () {
    test('counts open, critical and the median time to resolve', () {
      final quick = incident(
        id: 'q0004',
        status: IncidentStatus.resolved,
        createdAt: DateTime(2026, 10, 20, 8),
        resolvedAt: DateTime(2026, 10, 20, 10),
      );
      final stats = IncidentStats.from([...all, quick]);
      expect(stats.open, 2);
      expect(stats.openCritical, 1);
      // Resolutions: 2h and 24h, median of two values is their mean.
      expect(stats.medianResolution, const Duration(hours: 13));
    });

    test('median is null when nothing is resolved', () {
      expect(IncidentStats.from([water]).medianResolution, isNull);
    });
  });

  test('affected count includes the reporter', () {
    expect(water.affectedCount, 1);
    expect(power.affectedCount, 4);
  });
}
