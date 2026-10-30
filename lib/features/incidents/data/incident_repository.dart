import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/failure.dart';
import '../../auth/models/app_user.dart';
import '../models/incident.dart';
import '../models/incident_enums.dart';
import '../models/incident_event.dart';
import 'photo_storage.dart';

/// Result of creating a report. [queued] is true when the device is offline:
/// Firestore has saved the write locally and will send it on reconnect.
class CreateResult {
  const CreateResult(this.id, {this.queued = false});
  final String id;
  final bool queued;
}

/// The only class that reads or writes incident data in Firestore.
///
/// Every multi-document change is a single batched write so the incident,
/// its timeline entry and the reporter record can never disagree, and the
/// security rules can validate them together (getAfter).
class IncidentRepository {
  IncidentRepository({FirebaseFirestore? firestore, required PhotoStorage photos})
      : _db = firestore ?? FirebaseFirestore.instance,
        _photos = photos;

  final FirebaseFirestore _db;
  final PhotoStorage _photos;

  /// How many recent reports the feed keeps live on the device. Search and
  /// filters run over this window (see technical report, section 9).
  static const feedWindow = 200;

  /// If the server has not acknowledged a write by then, treat it as queued.
  static const _offlineAfter = Duration(seconds: 8);

  CollectionReference<Map<String, dynamic>> get _incidents => _db.collection('incidents');

  // ---------------------------------------------------------------- READ --

  Stream<List<Incident>> watchRecent() {
    return _incidents
        .orderBy('createdAt', descending: true)
        .limit(feedWindow)
        .snapshots(includeMetadataChanges: true)
        .map((q) => q.docs.map(Incident.fromSnapshot).toList());
  }

  /// Single-field equality query: served by Firestore's automatic index, so
  /// no composite index has to be deployed. Sorted on the device.
  Stream<List<Incident>> watchMine(String uid) {
    return _incidents
        .where('reporterId', isEqualTo: uid)
        .snapshots(includeMetadataChanges: true)
        .map((q) => q.docs.map(Incident.fromSnapshot).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }

  Stream<Incident?> watchIncident(String id) {
    return _incidents
        .doc(id)
        .snapshots(includeMetadataChanges: true)
        .map((s) => s.exists ? Incident.fromSnapshot(s) : null);
  }

  Stream<List<IncidentEvent>> watchHistory(String id) {
    return _incidents
        .doc(id)
        .collection('history')
        .orderBy('createdAt')
        .snapshots()
        .map((q) => q.docs.map(IncidentEvent.fromSnapshot).toList());
  }

  Future<ReporterInfo?> fetchReporter(String id) async {
    try {
      final snap = await _incidents.doc(id).collection('private').doc('reporter').get();
      return snap.exists ? ReporterInfo.fromMap(snap.data()!) : null;
    } catch (e) {
      throw Failure.from(e);
    }
  }

  // -------------------------------------------------------------- CREATE --

  Future<CreateResult> create({
    required IncidentDraft draft,
    required AppUser user,
    void Function(double progress)? onProgress,
  }) async {
    final ref = _incidents.doc();
    UploadedPhoto? photo;
    try {
      if (draft.photoLocalPath != null) {
        photo = await _photos.upload(
          uid: user.uid,
          incidentId: ref.id,
          file: File(draft.photoLocalPath!),
          onProgress: onProgress,
        );
      }
      final now = FieldValue.serverTimestamp();
      final batch = _db.batch()
        ..set(ref, {
          ..._content(draft),
          'photoUrl': photo?.url,
          'photoPath': photo?.path,
          'status': IncidentStatus.submitted.wire,
          'statusNote': null,
          'reporterId': user.uid,
          'affectedBy': <String>[],
          'reopenCount': 0,
          'resolvedAt': null,
          'createdAt': now,
          'updatedAt': now,
        })
        ..set(ref.collection('private').doc('reporter'), {
          'uid': user.uid,
          'name': user.displayName,
          'email': user.email,
        })
        ..set(ref.collection('history').doc(), {
          'type': IncidentEventType.created.name,
          'from': null,
          'to': IncidentStatus.submitted.wire,
          'note': null,
          'actorRole': 'student',
          'actorName': null,
          'createdAt': now,
        })
        // Server-enforced cooldown: rules compare this with the previous value.
        ..update(_db.collection('users').doc(user.uid), {'lastReportAt': now});

      final queued = await _commit(batch);
      return CreateResult(ref.id, queued: queued);
    } catch (e) {
      await _photos.deleteQuietly(photo?.path);
      throw Failure.from(e);
    }
  }

  // ---------------------------------------------------------------- UPDATE --

  /// Reporter edits while the report is still `submitted`.
  Future<void> edit({
    required Incident incident,
    required IncidentDraft draft,
    required AppUser user,
    void Function(double progress)? onProgress,
  }) async {
    final ref = _incidents.doc(incident.id);
    UploadedPhoto? photo;
    try {
      if (draft.photoLocalPath != null) {
        photo = await _photos.upload(
          uid: user.uid,
          incidentId: incident.id,
          file: File(draft.photoLocalPath!),
          onProgress: onProgress,
        );
      }
      final removePhoto = !draft.keepExistingPhoto && photo == null;
      final batch = _db.batch()
        ..update(ref, {
          ..._content(draft),
          if (photo != null) 'photoUrl': photo.url,
          if (photo != null) 'photoPath': photo.path,
          if (removePhoto) 'photoUrl': null,
          if (removePhoto) 'photoPath': null,
          'updatedAt': FieldValue.serverTimestamp(),
        })
        ..set(ref.collection('history').doc(), {
          'type': IncidentEventType.edited.name,
          'from': IncidentStatus.submitted.wire,
          'to': IncidentStatus.submitted.wire,
          'note': null,
          'actorRole': 'student',
          'actorName': null,
          'createdAt': FieldValue.serverTimestamp(),
        });
      await _commit(batch);
      if (photo != null || removePhoto) await _photos.deleteQuietly(incident.photoPath);
    } catch (e) {
      await _photos.deleteQuietly(photo?.path);
      throw Failure.from(e);
    }
  }

  /// Toggle "Affects me too". Rules only allow adding or removing the
  /// caller's own UID, and never on their own report.
  Future<void> setAffected({required String incidentId, required String uid, required bool affected}) async {
    try {
      await _commit(_db.batch()
        ..update(_incidents.doc(incidentId), {
          'affectedBy': affected ? FieldValue.arrayUnion([uid]) : FieldValue.arrayRemove([uid]),
        }));
    } catch (e) {
      throw Failure.from(e);
    }
  }

  /// Staff moves a report along the workflow and/or re-grades severity.
  Future<void> changeStatus({
    required Incident incident,
    required IncidentStatus to,
    required Severity severity,
    required String? note,
    required AppUser staff,
  }) async {
    final ref = _incidents.doc(incident.id);
    final now = FieldValue.serverTimestamp();
    final statusChanged = to != incident.status;
    final trimmed = note?.trim();
    try {
      final batch = _db.batch()
        ..update(ref, {
          'status': to.wire,
          'severity': severity.wire,
          'statusNote': (trimmed == null || trimmed.isEmpty) ? incident.statusNote : trimmed,
          'updatedAt': now,
          if (statusChanged) 'resolvedAt': to == IncidentStatus.resolved ? now : null,
        })
        ..set(ref.collection('history').doc(), {
          'type': IncidentEventType.status.name,
          'from': incident.status.wire,
          'to': to.wire,
          'note': _composeNote(trimmed, incident.severity, severity),
          'actorRole': 'staff',
          'actorName': '${staff.displayName} (${staff.department ?? 'Staff'})',
          'createdAt': now,
        });
      await _commit(batch);
    } catch (e) {
      throw Failure.from(e);
    }
  }

  /// Reporter says a resolved problem came back.
  Future<void> reopen({required Incident incident, required String note}) async {
    final ref = _incidents.doc(incident.id);
    final now = FieldValue.serverTimestamp();
    try {
      final batch = _db.batch()
        ..update(ref, {
          'status': IncidentStatus.inProgress.wire,
          'reopenCount': incident.reopenCount + 1,
          'resolvedAt': null,
          'statusNote': note.trim(),
          'updatedAt': now,
        })
        ..set(ref.collection('history').doc(), {
          'type': IncidentEventType.reopened.name,
          'from': IncidentStatus.resolved.wire,
          'to': IncidentStatus.inProgress.wire,
          'note': note.trim(),
          'actorRole': 'student',
          'actorName': null,
          'createdAt': now,
        });
      await _commit(batch);
    } catch (e) {
      throw Failure.from(e);
    }
  }

  // ---------------------------------------------------------------- DELETE --

  /// Reporter deletes a report staff have not touched yet. Subcollections are
  /// removed in the same batch (Firestore does not cascade deletes), then
  /// the photo is removed from Storage.
  Future<void> delete(Incident incident) async {
    final ref = _incidents.doc(incident.id);
    try {
      final history = await ref.collection('history').get();
      final batch = _db.batch();
      for (final doc in history.docs) {
        batch.delete(doc.reference);
      }
      batch
        ..delete(ref.collection('private').doc('reporter'))
        ..delete(ref);
      await _commit(batch);
      await _photos.deleteQuietly(incident.photoPath);
    } catch (e) {
      throw Failure.from(e);
    }
  }

  // ------------------------------------------------------------- HELPERS --

  Map<String, dynamic> _content(IncidentDraft d) => {
        'title': d.title.trim(),
        'description': d.description.trim(),
        'category': d.category!.wire,
        'severity': d.severity.wire,
        'locationArea': d.area!.wire,
        'locationDetail': d.locationDetail.trim(),
      };

  static String? _composeNote(String? note, Severity before, Severity after) {
    final parts = <String>[
      if (before != after) 'Severity changed from ${before.label} to ${after.label}.',
      if (note != null && note.isNotEmpty) note,
    ];
    return parts.isEmpty ? null : parts.join(' ');
  }

  /// Commits and reports whether the write was only queued locally.
  /// Firestore applies the write to the local cache immediately (so every
  /// screen updates at once) but the future waits for the server; on a dead
  /// connection we stop waiting and let the "Syncing" chip tell the story.
  Future<bool> _commit(WriteBatch batch) async {
    var queued = false;
    await batch.commit().timeout(_offlineAfter, onTimeout: () => queued = true);
    return queued;
  }
}
