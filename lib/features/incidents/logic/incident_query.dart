import '../models/incident.dart';
import '../models/incident_enums.dart';
import '../models/incident_filter.dart';

/// Pure list logic: no Flutter, no Firebase. Blocs and widgets call these,
/// and test/features/incidents/incident_query_test.dart covers them.
abstract final class IncidentQuery {
  /// Applies search, chips and sort to the live list.
  static List<Incident> apply(List<Incident> items, IncidentFilter f) {
    final q = f.query.trim().toLowerCase();
    final out = items.where((i) {
      if (f.categories.isNotEmpty && !f.categories.contains(i.category)) return false;
      if (f.statuses.isNotEmpty && !f.statuses.contains(i.status)) return false;
      if (q.isEmpty) return true;
      return i.title.toLowerCase().contains(q) ||
          i.description.toLowerCase().contains(q) ||
          i.locationDetail.toLowerCase().contains(q) ||
          i.area.label.toLowerCase().contains(q) ||
          i.refCode.toLowerCase().contains(q);
    }).toList();

    switch (f.sort) {
      case IncidentSort.newest:
        out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case IncidentSort.mostAffected:
        out.sort((a, b) {
          final byCount = b.affectedCount.compareTo(a.affectedCount);
          return byCount != 0 ? byCount : b.createdAt.compareTo(a.createdAt);
        });
      case IncidentSort.severity:
        out.sort(_bySeverityThenAge);
    }
    return out;
  }

  /// Staff triage order: open before closed, most severe first, then the
  /// oldest waiting report first so nothing starves at the bottom.
  static List<Incident> triage(List<Incident> items) {
    final out = [...items];
    out.sort((a, b) {
      if (a.status.isOpen != b.status.isOpen) return a.status.isOpen ? -1 : 1;
      return _bySeverityThenAge(a, b);
    });
    return out;
  }

  static int _bySeverityThenAge(Incident a, Incident b) {
    final bySeverity = b.severity.weight.compareTo(a.severity.weight);
    if (bySeverity != 0) return bySeverity;
    final byAffected = b.affectedCount.compareTo(a.affectedCount);
    if (byAffected != 0) return byAffected;
    return a.createdAt.compareTo(b.createdAt);
  }

  /// Open reports a student might be about to duplicate: same category and
  /// area, created within [window]. Shown on the report form so the student
  /// can tap "Affects me too" instead of filing again.
  static List<Incident> similar(
    List<Incident> items, {
    required IncidentCategory? category,
    required CampusArea? area,
    String? excludeId,
    DateTime? now,
    Duration window = const Duration(days: 14),
  }) {
    if (category == null || area == null) return const [];
    final cutoff = (now ?? DateTime.now()).subtract(window);
    return items
        .where((i) =>
            i.id != excludeId &&
            i.status.isOpen &&
            i.category == category &&
            i.area == area &&
            i.createdAt.isAfter(cutoff))
        .take(3)
        .toList();
  }
}

/// Numbers for the staff dashboard, computed from the live list.
class IncidentStats {
  const IncidentStats({
    required this.byStatus,
    required this.openCritical,
    required this.medianResolution,
    required this.total,
  });

  final Map<IncidentStatus, int> byStatus;
  final int openCritical;

  /// Median time from submission to resolution over resolved reports in the
  /// loaded window; null when nothing has been resolved yet.
  final Duration? medianResolution;
  final int total;

  int get open => (byStatus[IncidentStatus.submitted] ?? 0) +
      (byStatus[IncidentStatus.acknowledged] ?? 0) +
      (byStatus[IncidentStatus.inProgress] ?? 0);

  factory IncidentStats.from(List<Incident> items) {
    final byStatus = {for (final s in IncidentStatus.values) s: 0};
    var critical = 0;
    final durations = <Duration>[];
    for (final i in items) {
      byStatus[i.status] = byStatus[i.status]! + 1;
      if (i.status.isOpen && i.severity == Severity.critical) critical++;
      if (i.status == IncidentStatus.resolved && i.resolvedAt != null) {
        durations.add(i.resolvedAt!.difference(i.createdAt));
      }
    }
    Duration? median;
    if (durations.isNotEmpty) {
      durations.sort();
      final mid = durations.length ~/ 2;
      median = durations.length.isOdd
          ? durations[mid]
          : Duration(microseconds: (durations[mid - 1].inMicroseconds + durations[mid].inMicroseconds) ~/ 2);
    }
    return IncidentStats(byStatus: byStatus, openCritical: critical, medianResolution: median, total: items.length);
  }
}
