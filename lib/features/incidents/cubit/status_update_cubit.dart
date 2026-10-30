import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/failure.dart';
import '../../../core/utils/validators.dart';
import '../../auth/models/app_user.dart';
import '../data/incident_repository.dart';
import '../logic/status_workflow.dart';
import '../models/incident.dart';
import '../models/incident_enums.dart';

enum UpdateStatus { idle, saving, saved, failed }

class StatusUpdateState extends Equatable {
  const StatusUpdateState({required this.target, required this.severity, this.status = UpdateStatus.idle, this.message});

  final IncidentStatus target;
  final Severity severity;
  final UpdateStatus status;
  final String? message;

  StatusUpdateState copyWith({IncidentStatus? target, Severity? severity, UpdateStatus? status, String? message}) {
    return StatusUpdateState(
      target: target ?? this.target,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      message: message,
    );
  }

  @override
  List<Object?> get props => [target, severity, status, message];
}

/// Staff-only sheet for moving a report along the workflow.
/// The UI only offers legal transitions, and firestore.rules re-checks them.
class StatusUpdateCubit extends Cubit<StatusUpdateState> {
  StatusUpdateCubit({required IncidentRepository repository, required this.incident, required this.staff})
      : _repo = repository,
        super(StatusUpdateState(
          target: StatusWorkflow.nextFor(incident.status).isEmpty
              ? incident.status
              : StatusWorkflow.nextFor(incident.status).first,
          severity: incident.severity,
        ));

  final IncidentRepository _repo;
  final Incident incident;
  final AppUser staff;

  List<IncidentStatus> get options => StatusWorkflow.nextFor(incident.status);

  void selectTarget(IncidentStatus s) => emit(state.copyWith(target: s));
  void selectSeverity(Severity s) => emit(state.copyWith(severity: s));

  bool get noteRequired => StatusWorkflow.requiresNote(state.target);

  Future<void> save(String note) async {
    if (state.status == UpdateStatus.saving) return;
    if (!staff.isStaff) {
      emit(state.copyWith(status: UpdateStatus.failed, message: 'Only campus staff can change status.'));
      return;
    }
    if (noteRequired && Validators.note(note) != null) {
      emit(state.copyWith(status: UpdateStatus.failed, message: 'Add a short note so the reporter knows what happened.'));
      return;
    }
    emit(state.copyWith(status: UpdateStatus.saving));
    try {
      await _repo.changeStatus(
        incident: incident,
        to: state.target,
        severity: state.severity,
        note: note,
        staff: staff,
      );
      emit(state.copyWith(status: UpdateStatus.saved, message: 'Status updated to ${state.target.label}.'));
    } catch (e) {
      emit(state.copyWith(status: UpdateStatus.failed, message: Failure.from(e).message));
    }
  }
}
