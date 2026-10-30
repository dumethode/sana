import '../models/incident_enums.dart';

/// The staff status workflow. firestore.rules contains the same table
/// (function validTransition) so the server rejects anything the UI would
/// not offer; test/features/incidents/status_workflow_test.dart and
/// firebase_rules_test/ keep the two copies honest.
abstract final class StatusWorkflow {
  static const Map<IncidentStatus, List<IncidentStatus>> _next = {
    IncidentStatus.submitted: [
      IncidentStatus.acknowledged,
      IncidentStatus.inProgress,
      IncidentStatus.resolved,
      IncidentStatus.rejected,
    ],
    IncidentStatus.acknowledged: [
      IncidentStatus.inProgress,
      IncidentStatus.resolved,
      IncidentStatus.rejected,
    ],
    IncidentStatus.inProgress: [IncidentStatus.resolved],
    IncidentStatus.resolved: [IncidentStatus.inProgress],
    IncidentStatus.rejected: [IncidentStatus.acknowledged],
  };

  static List<IncidentStatus> nextFor(IncidentStatus from) => _next[from] ?? const [];

  static bool canMove(IncidentStatus from, IncidentStatus to) => nextFor(from).contains(to);

  /// Closing a report needs an explanation the reporter can read.
  static bool requiresNote(IncidentStatus to) =>
      to == IncidentStatus.resolved || to == IncidentStatus.rejected;
}
