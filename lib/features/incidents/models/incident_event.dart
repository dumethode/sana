import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import 'incident_enums.dart';

enum IncidentEventType {
  created,
  edited,
  status,
  reopened;

  static IncidentEventType parse(Object? raw) =>
      values.firstWhere((v) => v.name == raw, orElse: () => IncidentEventType.status);
}

/// One immutable entry on an incident's timeline:
/// `incidents/{id}/history/{eventId}`. History is append-only (rules deny
/// update), so it doubles as an audit log of who changed what and when.
class IncidentEvent extends Equatable {
  const IncidentEvent({
    required this.id,
    required this.type,
    required this.to,
    required this.actorRole,
    required this.createdAt,
    this.from,
    this.note,
    this.actorName,
  });

  final String id;
  final IncidentEventType type;
  final IncidentStatus? from;
  final IncidentStatus to;
  final String? note;
  final String actorRole;

  /// Staff name, shown so students know who is handling their report.
  /// Null for student actions, which stay anonymous to other students.
  final String? actorName;
  final DateTime createdAt;

  factory IncidentEvent.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    final d = snap.data() ?? const <String, dynamic>{};
    return IncidentEvent(
      id: snap.id,
      type: IncidentEventType.parse(d['type']),
      from: d['from'] == null ? null : IncidentStatus.parse(d['from']),
      to: IncidentStatus.parse(d['to']),
      note: d['note'] as String?,
      actorRole: d['actorRole'] as String? ?? 'student',
      actorName: d['actorName'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  String get headline => switch (type) {
        IncidentEventType.created => 'Report submitted',
        IncidentEventType.edited => 'Details edited by reporter',
        IncidentEventType.reopened => 'Reopened by reporter',
        IncidentEventType.status => 'Marked ${to.label.toLowerCase()}',
      };

  @override
  List<Object?> get props => [id, type, from, to, note, actorRole, actorName, createdAt];
}

/// `incidents/{id}/private/reporter`, readable by staff and the reporter only.
class ReporterInfo extends Equatable {
  const ReporterInfo({required this.uid, required this.name, required this.email});

  final String uid;
  final String name;
  final String email;

  factory ReporterInfo.fromMap(Map<String, dynamic> d) => ReporterInfo(
        uid: d['uid'] as String? ?? '',
        name: d['name'] as String? ?? '',
        email: d['email'] as String? ?? '',
      );

  @override
  List<Object?> get props => [uid, name, email];
}
