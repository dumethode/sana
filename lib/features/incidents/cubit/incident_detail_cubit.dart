import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/failure.dart';
import '../../auth/models/app_user.dart';
import '../data/incident_repository.dart';
import '../models/incident.dart';
import '../models/incident_event.dart';

enum DetailStatus { loading, ready, missing, failure }

enum DetailAction { none, working, done, failed }

class IncidentDetailState extends Equatable {
  const IncidentDetailState({
    this.status = DetailStatus.loading,
    this.incident,
    this.events = const [],
    this.reporter,
    this.action = DetailAction.none,
    this.message,
    this.deleted = false,
  });

  final DetailStatus status;
  final Incident? incident;
  final List<IncidentEvent> events;
  final ReporterInfo? reporter;
  final DetailAction action;
  final String? message;
  final bool deleted;

  IncidentDetailState copyWith({
    DetailStatus? status,
    Incident? incident,
    List<IncidentEvent>? events,
    ReporterInfo? reporter,
    DetailAction? action,
    String? message,
    bool? deleted,
  }) {
    return IncidentDetailState(
      status: status ?? this.status,
      incident: incident ?? this.incident,
      events: events ?? this.events,
      reporter: reporter ?? this.reporter,
      action: action ?? this.action,
      message: message,
      deleted: deleted ?? this.deleted,
    );
  }

  @override
  List<Object?> get props => [status, incident, events, reporter, action, message, deleted];
}

/// Live view of one report: the document, its timeline and (for staff and
/// the reporter only) the reporter's identity, plus the actions a viewer can
/// take on it.
class IncidentDetailCubit extends Cubit<IncidentDetailState> {
  IncidentDetailCubit({required IncidentRepository repository, required this.incidentId, required this.viewer})
      : _repo = repository,
        super(const IncidentDetailState());

  final IncidentRepository _repo;
  final String incidentId;
  final AppUser viewer;
  StreamSubscription<Incident?>? _incidentSub;
  StreamSubscription<List<IncidentEvent>>? _historySub;
  bool _reporterRequested = false;

  void start() {
    _incidentSub = _repo.watchIncident(incidentId).listen(
      (incident) {
        if (incident == null) {
          emit(state.copyWith(status: DetailStatus.missing));
          return;
        }
        emit(state.copyWith(status: DetailStatus.ready, incident: incident));
        _maybeLoadReporter(incident);
      },
      onError: (Object e) => emit(state.copyWith(status: DetailStatus.failure, message: Failure.from(e).message)),
    );
    _historySub = _repo.watchHistory(incidentId).listen(
      (events) => emit(state.copyWith(events: events)),
      onError: (_) {}, // The incident stream already surfaces access problems.
    );
  }

  Future<void> retry() async {
    await _cancel();
    emit(const IncidentDetailState());
    start();
  }

  Future<void> _maybeLoadReporter(Incident incident) async {
    if (_reporterRequested) return;
    if (!viewer.isStaff && !incident.isOwnedBy(viewer.uid)) return;
    _reporterRequested = true;
    try {
      final r = await _repo.fetchReporter(incident.id);
      if (!isClosed && r != null) emit(state.copyWith(reporter: r));
    } catch (_) {
      _reporterRequested = false;
    }
  }

  Future<void> toggleAffected() async {
    final i = state.incident;
    if (i == null || i.isOwnedBy(viewer.uid)) return;
    final next = !i.isAffecting(viewer.uid);
    await _act(
      () => _repo.setAffected(incidentId: i.id, uid: viewer.uid, affected: next),
      done: next ? 'Added. Staff can see how many people this affects.' : 'Removed.',
    );
  }

  Future<void> reopen(String note) async {
    final i = state.incident;
    if (i == null || !i.canBeReopened) return;
    await _act(() => _repo.reopen(incident: i, note: note), done: 'Reopened. Staff have been sent back to it.');
  }

  Future<void> delete() async {
    final i = state.incident;
    if (i == null || !i.isEditableByOwner) return;
    // Stop listening first so the vanishing document is not shown as "missing".
    await _cancel();
    emit(state.copyWith(action: DetailAction.working));
    try {
      await _repo.delete(i);
      if (!isClosed) emit(state.copyWith(action: DetailAction.done, deleted: true, message: 'Report deleted.'));
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(action: DetailAction.failed, message: Failure.from(e).message));
        start();
      }
    }
  }

  Future<void> _act(Future<void> Function() run, {required String done}) async {
    if (state.action == DetailAction.working) return;
    emit(state.copyWith(action: DetailAction.working));
    try {
      await run();
      if (!isClosed) emit(state.copyWith(action: DetailAction.done, message: done));
    } catch (e) {
      if (!isClosed) emit(state.copyWith(action: DetailAction.failed, message: Failure.from(e).message));
    }
  }

  Future<void> _cancel() async {
    await _incidentSub?.cancel();
    await _historySub?.cancel();
    _incidentSub = null;
    _historySub = null;
  }

  @override
  Future<void> close() async {
    await _cancel();
    return super.close();
  }
}
