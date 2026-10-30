import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

import '../../../core/utils/failure.dart';
import '../../../core/utils/validators.dart';
import '../../auth/models/app_user.dart';
import '../data/incident_repository.dart';
import '../models/incident.dart';

enum FormSubmit { editing, submitting, success, failure }

class ReportFormState extends Equatable {
  const ReportFormState({
    this.draft = const IncidentDraft(),
    this.submit = FormSubmit.editing,
    this.progress,
    this.message,
    this.resultId,
    this.queued = false,
    this.restored = false,
  });

  final IncidentDraft draft;
  final FormSubmit submit;

  /// Photo upload progress 0..1 while submitting; null when not uploading.
  final double? progress;
  final String? message;
  final String? resultId;
  final bool queued;

  /// True when the draft was brought back from disk.
  final bool restored;

  ReportFormState copyWith({
    IncidentDraft? draft,
    FormSubmit? submit,
    double? progress,
    bool clearProgress = false,
    String? message,
    String? resultId,
    bool? queued,
    bool? restored,
  }) {
    return ReportFormState(
      draft: draft ?? this.draft,
      submit: submit ?? this.submit,
      progress: clearProgress ? null : (progress ?? this.progress),
      message: message,
      resultId: resultId ?? this.resultId,
      queued: queued ?? this.queued,
      restored: restored ?? this.restored,
    );
  }

  @override
  List<Object?> get props => [draft, submit, progress, message, resultId, queued, restored];
}

/// Drives the create and edit report form.
///
/// In create mode the draft is persisted on every change, so a half-written
/// report survives leaving the screen, switching tabs or restarting the app.
/// Edit mode never persists (the source of truth is the existing document).
class ReportFormCubit extends HydratedCubit<ReportFormState> {
  ReportFormCubit({required IncidentRepository repository, this.editing})
      : _repo = repository,
        super(ReportFormState(
          draft: editing == null ? const IncidentDraft() : IncidentDraft.fromIncident(editing),
        ));

  final IncidentRepository _repo;
  final Incident? editing;

  static const cooldown = Duration(seconds: 60);

  bool get isEditing => editing != null;

  @override
  String get id => isEditing ? 'edit' : 'new';

  void update(IncidentDraft draft) => emit(state.copyWith(draft: draft, submit: FormSubmit.editing));

  void setPhoto(String path) =>
      emit(state.copyWith(draft: state.draft.copyWith(photoLocalPath: path), submit: FormSubmit.editing));

  void removePhoto() => emit(state.copyWith(
        draft: state.draft.copyWith(clearPhoto: true, keepExistingPhoto: false),
        submit: FormSubmit.editing,
      ));

  void dismissRestoredBanner() => emit(state.copyWith(restored: false));

  Future<void> discard() async {
    await clear();
    emit(ReportFormState(draft: isEditing ? IncidentDraft.fromIncident(editing!) : const IncidentDraft()));
  }

  /// Returns a message when the draft is incomplete, otherwise null. Field
  /// level messages are shown by the form itself; this covers the pickers.
  String? missingPickers() {
    final d = state.draft;
    if (d.category == null) return 'Choose a category';
    if (d.area == null) return 'Choose where on campus this is';
    return null;
  }

  Future<void> submit(AppUser user, {DateTime? now}) async {
    if (state.submit == FormSubmit.submitting) return;
    final d = state.draft;
    final invalid = missingPickers() ??
        Validators.title(d.title) ??
        Validators.description(d.description) ??
        Validators.location(d.locationDetail);
    if (invalid != null) {
      emit(state.copyWith(submit: FormSubmit.failure, message: invalid));
      return;
    }
    if (!isEditing && user.lastReportAt != null) {
      final wait = cooldown - (now ?? DateTime.now()).difference(user.lastReportAt!);
      if (wait > Duration.zero) {
        emit(state.copyWith(
          submit: FormSubmit.failure,
          message: 'You can send another report in ${(wait.inMilliseconds / 1000).ceil()}s. '
              'This limit keeps the queue free of spam.',
        ));
        return;
      }
    }

    emit(state.copyWith(submit: FormSubmit.submitting, progress: d.photoLocalPath == null ? null : 0));
    void onProgress(double p) {
      if (!isClosed) emit(state.copyWith(submit: FormSubmit.submitting, progress: p));
    }

    try {
      if (isEditing) {
        await _repo.edit(incident: editing!, draft: d, user: user, onProgress: onProgress);
        emit(state.copyWith(submit: FormSubmit.success, resultId: editing!.id, clearProgress: true));
      } else {
        final result = await _repo.create(draft: d, user: user, onProgress: onProgress);
        await clear();
        emit(ReportFormState(submit: FormSubmit.success, resultId: result.id, queued: result.queued));
      }
    } catch (e) {
      final f = Failure.from(e);
      final message = f.code == 'permission-denied' && !isEditing
          ? 'The server refused this report. If you just sent one, wait a minute and try again.'
          : f.message;
      if (!isClosed) emit(state.copyWith(submit: FormSubmit.failure, message: message, clearProgress: true));
    }
  }

  @override
  ReportFormState? fromJson(Map<String, dynamic> json) {
    if (isEditing) return null;
    var draft = IncidentDraft.fromJson(json);
    final path = draft.photoLocalPath;
    // The OS may have cleared the picker's cache since the draft was saved.
    if (path != null && !File(path).existsSync()) draft = draft.copyWith(clearPhoto: true);
    return ReportFormState(draft: draft, restored: !draft.isEmpty);
  }

  @override
  Map<String, dynamic>? toJson(ReportFormState state) {
    if (isEditing || state.submit == FormSubmit.success) return null;
    return state.draft.toJson();
  }
}
