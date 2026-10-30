import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import 'incident_enums.dart';

/// An incident report: `incidents/{id}`.
///
/// The document deliberately holds no reporter name or email. Identity lives
/// in `incidents/{id}/private/reporter`, which security rules expose only to
/// staff and to the reporter, so browsing students can never see who filed a
/// report.
class Incident extends Equatable {
  const Incident({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.severity,
    required this.area,
    required this.locationDetail,
    required this.status,
    required this.reporterId,
    required this.createdAt,
    required this.updatedAt,
    this.photoUrl,
    this.photoPath,
    this.statusNote,
    this.affectedBy = const [],
    this.reopenCount = 0,
    this.resolvedAt,
    this.hasPendingWrites = false,
  });

  final String id;
  final String title;
  final String description;
  final IncidentCategory category;
  final Severity severity;
  final CampusArea area;
  final String locationDetail;
  final IncidentStatus status;
  final String reporterId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? photoUrl;
  final String? photoPath;

  /// Latest note written by staff when changing status.
  final String? statusNote;

  /// UIDs of students who tapped "Affects me too". Opaque IDs only.
  final List<String> affectedBy;
  final int reopenCount;
  final DateTime? resolvedAt;

  /// True while a local write has not reached the server yet (offline).
  final bool hasPendingWrites;

  static const maxReopens = 2;

  /// Short, speakable reference shown on tickets: "SN-4F2KQ".
  String get refCode => 'SN-${id.length >= 5 ? id.substring(0, 5) : id}'.toUpperCase();

  /// Reporter plus everyone who tapped "Affects me too".
  int get affectedCount => affectedBy.length + 1;

  bool isOwnedBy(String uid) => reporterId == uid;
  bool isAffecting(String uid) => affectedBy.contains(uid);

  /// Students may edit or delete only before staff have acted.
  bool get isEditableByOwner => status == IncidentStatus.submitted;

  bool get canBeReopened => status == IncidentStatus.resolved && reopenCount < maxReopens;

  factory Incident.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    final d = snap.data() ?? const <String, dynamic>{};
    // serverTimestamp() fields are null in the local snapshot until the write
    // is acknowledged; fall back to "now" so pending items still sort first.
    DateTime ts(Object? v) => (v as Timestamp?)?.toDate() ?? DateTime.now();
    return Incident(
      id: snap.id,
      title: d['title'] as String? ?? '',
      description: d['description'] as String? ?? '',
      category: IncidentCategory.parse(d['category']),
      severity: Severity.parse(d['severity']),
      area: CampusArea.parse(d['locationArea']),
      locationDetail: d['locationDetail'] as String? ?? '',
      status: IncidentStatus.parse(d['status']),
      reporterId: d['reporterId'] as String? ?? '',
      createdAt: ts(d['createdAt']),
      updatedAt: ts(d['updatedAt']),
      photoUrl: d['photoUrl'] as String?,
      photoPath: d['photoPath'] as String?,
      statusNote: d['statusNote'] as String?,
      affectedBy: List<String>.from(d['affectedBy'] as List? ?? const []),
      reopenCount: (d['reopenCount'] as num?)?.toInt() ?? 0,
      resolvedAt: (d['resolvedAt'] as Timestamp?)?.toDate(),
      hasPendingWrites: snap.metadata.hasPendingWrites,
    );
  }

  Incident copyWith({IncidentStatus? status, List<String>? affectedBy, Severity? severity}) {
    return Incident(
      id: id,
      title: title,
      description: description,
      category: category,
      severity: severity ?? this.severity,
      area: area,
      locationDetail: locationDetail,
      status: status ?? this.status,
      reporterId: reporterId,
      createdAt: createdAt,
      updatedAt: updatedAt,
      photoUrl: photoUrl,
      photoPath: photoPath,
      statusNote: statusNote,
      affectedBy: affectedBy ?? this.affectedBy,
      reopenCount: reopenCount,
      resolvedAt: resolvedAt,
      hasPendingWrites: hasPendingWrites,
    );
  }

  @override
  List<Object?> get props => [
        id, title, description, category, severity, area, locationDetail, status, reporterId,
        createdAt, updatedAt, photoUrl, photoPath, statusNote, affectedBy, reopenCount,
        resolvedAt, hasPendingWrites,
      ];
}

/// The editable content of a report, used for both create and edit.
class IncidentDraft extends Equatable {
  const IncidentDraft({
    this.category,
    this.title = '',
    this.description = '',
    this.area,
    this.locationDetail = '',
    this.severity = Severity.medium,
    this.photoLocalPath,
    this.keepExistingPhoto = true,
  });

  final IncidentCategory? category;
  final String title;
  final String description;
  final CampusArea? area;
  final String locationDetail;
  final Severity severity;

  /// Path of a newly picked photo on the device, not yet uploaded.
  final String? photoLocalPath;

  /// Edit mode only: false when the user removed the existing photo.
  final bool keepExistingPhoto;

  bool get isEmpty =>
      category == null && title.isEmpty && description.isEmpty && area == null && locationDetail.isEmpty &&
      photoLocalPath == null;

  IncidentDraft copyWith({
    IncidentCategory? category,
    String? title,
    String? description,
    CampusArea? area,
    String? locationDetail,
    Severity? severity,
    String? photoLocalPath,
    bool clearPhoto = false,
    bool? keepExistingPhoto,
  }) {
    return IncidentDraft(
      category: category ?? this.category,
      title: title ?? this.title,
      description: description ?? this.description,
      area: area ?? this.area,
      locationDetail: locationDetail ?? this.locationDetail,
      severity: severity ?? this.severity,
      photoLocalPath: clearPhoto ? null : (photoLocalPath ?? this.photoLocalPath),
      keepExistingPhoto: keepExistingPhoto ?? this.keepExistingPhoto,
    );
  }

  factory IncidentDraft.fromIncident(Incident i) => IncidentDraft(
        category: i.category,
        title: i.title,
        description: i.description,
        area: i.area,
        locationDetail: i.locationDetail,
        severity: i.severity,
      );

  Map<String, dynamic> toJson() => {
        'category': category?.wire,
        'title': title,
        'description': description,
        'area': area?.wire,
        'locationDetail': locationDetail,
        'severity': severity.wire,
        'photoLocalPath': photoLocalPath,
      };

  factory IncidentDraft.fromJson(Map<String, dynamic> json) => IncidentDraft(
        category: json['category'] == null ? null : IncidentCategory.parse(json['category']),
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        area: json['area'] == null ? null : CampusArea.parse(json['area']),
        locationDetail: json['locationDetail'] as String? ?? '',
        severity: Severity.parse(json['severity']),
        photoLocalPath: json['photoLocalPath'] as String?,
      );

  @override
  List<Object?> get props =>
      [category, title, description, area, locationDetail, severity, photoLocalPath, keepExistingPhoto];
}
