import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/failure.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/busy_button.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/responsive.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../shell/session.dart';
import '../cubit/report_form_cubit.dart';
import '../data/incident_repository.dart';
import '../data/photo_storage.dart';
import '../logic/incident_query.dart';
import '../models/incident.dart';
import '../models/incident_enums.dart';
import 'incident_detail_page.dart';
import 'widgets/incident_card.dart';

/// Create a new report, or edit one that staff have not picked up yet.
class ReportFormPage extends StatelessWidget {
  const ReportFormPage({super.key, this.editing});

  final Incident? editing;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => ReportFormCubit(repository: ctx.read<IncidentRepository>(), editing: editing),
      child: _FormView(editing: editing),
    );
  }
}

class _FormView extends StatefulWidget {
  const _FormView({required this.editing});

  final Incident? editing;

  @override
  State<_FormView> createState() => _FormViewState();
}

class _FormViewState extends State<_FormView> {
  final _form = GlobalKey<FormState>();
  late final ReportFormCubit _cubit = context.read<ReportFormCubit>();
  late final _title = TextEditingController(text: _cubit.state.draft.title);
  late final _description = TextEditingController(text: _cubit.state.draft.description);
  late final _location = TextEditingController(text: _cubit.state.draft.locationDetail);
  bool _triedSubmit = false;

  bool get _editing => widget.editing != null;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  void _syncText() {
    final d = _cubit.state.draft;
    _cubit.update(d.copyWith(title: _title.text, description: _description.text, locationDetail: _location.text));
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 72, // re-encodes to keep uploads small on campus data
      );
      if (file == null) return;
      final size = await File(file.path).length();
      if (size > PhotoStorage.maxBytes) {
        if (mounted) showMessage(context, 'That photo is over 5 MB. Try another one.', error: true);
        return;
      }
      _cubit.setPhoto(file.path);
    } on PlatformException catch (e) {
      if (!mounted) return;
      final denied = e.code.contains('denied') || e.code.contains('access');
      showMessage(
        context,
        denied ? 'Sana needs permission to use the ${source == ImageSource.camera ? 'camera' : 'photo library'}. '
            'You can allow it in Settings.' : 'Could not open the ${source.name}.',
        error: true,
      );
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _triedSubmit = true);
    _syncText();
    final fieldsOk = _form.currentState!.validate();
    final pickerMessage = _cubit.missingPickers();
    if (!fieldsOk || pickerMessage != null) {
      showMessage(context, pickerMessage ?? 'Check the highlighted fields.', error: true);
      return;
    }
    final user = context.read<AuthBloc>().state.user;
    if (user == null) return;
    await _cubit.submit(user);
  }

  Future<void> _meToo(Incident incident) async {
    final user = context.read<AuthBloc>().state.user;
    if (user == null) return;
    try {
      await context.read<IncidentRepository>().setAffected(incidentId: incident.id, uid: user.uid, affected: true);
      if (!mounted) return;
      final discard = await confirm(
        context,
        title: 'Added you to ${incident.refCode}',
        message: 'Staff now see one more person affected. Discard your draft instead of sending a duplicate?',
        confirmLabel: 'Discard draft',
      );
      if (!mounted) return;
      if (discard) {
        await _cubit.discard();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(SessionScope.route(context, IncidentDetailPage(incidentId: incident.id)));
      }
    } catch (e) {
      if (mounted) showMessage(context, Failure.from(e).message, error: true);
    }
  }

  Future<bool> _confirmLeave() async {
    if (!_editing) {
      // Create mode autosaves, so leaving is always safe.
      if (!_cubit.state.draft.isEmpty && _cubit.state.submit != FormSubmit.success) {
        showMessage(context, 'Draft saved. It will be here when you come back.');
      }
      return true;
    }
    final changed = _cubit.state.draft != IncidentDraft.fromIncident(widget.editing!);
    if (!changed) return true;
    return confirm(
      context,
      title: 'Discard changes?',
      message: 'Your edits to this report will be lost.',
      confirmLabel: 'Discard',
      destructive: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ReportFormCubit, ReportFormState>(
      listenWhen: (a, b) => a.submit != b.submit,
      listener: (context, state) {
        if (state.submit == FormSubmit.failure && state.message != null && _triedSubmit) {
          showMessage(context, state.message!, error: true);
        }
        if (state.submit == FormSubmit.success) {
          if (_editing) {
            showMessage(context, 'Changes saved.');
            Navigator.of(context).pop();
          } else {
            showMessage(
              context,
              state.queued
                  ? 'Saved on your phone. It will be sent as soon as you are online.'
                  : 'Report sent. You will see every update here.',
            );
            Navigator.of(context)
                .pushReplacement(SessionScope.route(context, IncidentDetailPage(incidentId: state.resultId!)));
          }
        }
      },
      builder: (context, state) {
        final d = state.draft;
        final submitting = state.submit == FormSubmit.submitting;
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop || submitting) return;
            _syncText();
            final nav = Navigator.of(context);
            if (await _confirmLeave()) nav.pop();
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(_editing ? 'Edit ${widget.editing!.refCode}' : 'Report an issue'),
              actions: [
                if (!_editing && !d.isEmpty)
                  TextButton(
                    onPressed: submitting
                        ? null
                        : () async {
                            final ok = await confirm(
                              context,
                              title: 'Start over?',
                              message: 'This clears everything you have entered.',
                              confirmLabel: 'Clear',
                              destructive: true,
                            );
                            if (!ok) return;
                            await _cubit.discard();
                            _title.clear();
                            _description.clear();
                            _location.clear();
                          },
                    child: const Text('Clear'),
                  ),
              ],
            ),
            body: Form(
              key: _form,
              autovalidateMode: _triedSubmit ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Gap.l, Gap.s, Gap.l, Gap.xxxl),
                children: [
                  MaxWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (state.restored) _RestoredBanner(onDismiss: _cubit.dismissRestoredBanner),
                        const _Step(number: 1, title: 'What kind of issue?'),
                        _CategoryGrid(
                          selected: d.category,
                          showError: _triedSubmit && d.category == null,
                          onSelect: (c) => _cubit.update(d.copyWith(
                            category: c,
                            // Safety defaults to High unless the student already chose.
                            severity: d.category == null ? c.defaultSeverity : d.severity,
                          )),
                        ),
                        const _Step(number: 2, title: 'Where is it?'),
                        _AreaChips(
                          selected: d.area,
                          showError: _triedSubmit && d.area == null,
                          onSelect: (a) => _cubit.update(d.copyWith(area: a)),
                        ),
                        const SizedBox(height: Gap.m),
                        TextFormField(
                          controller: _location,
                          maxLength: Validators.locationMax,
                          textCapitalization: TextCapitalization.sentences,
                          onChanged: (_) => _syncText(),
                          decoration: const InputDecoration(
                            labelText: 'Exact spot',
                            hintText: 'e.g. Block B, 2nd floor, room 204',
                            prefixIcon: Icon(Icons.place_outlined),
                          ),
                          validator: Validators.location,
                        ),
                        if (!_editing) _SimilarReports(draft: d, onMeToo: _meToo),
                        const _Step(number: 3, title: 'Describe it'),
                        TextFormField(
                          controller: _title,
                          maxLength: Validators.titleMax,
                          textCapitalization: TextCapitalization.sentences,
                          onChanged: (_) => _syncText(),
                          decoration: const InputDecoration(
                            labelText: 'Short title',
                            hintText: 'e.g. No water in 3rd floor showers',
                          ),
                          validator: Validators.title,
                        ),
                        const SizedBox(height: Gap.s),
                        TextFormField(
                          controller: _description,
                          maxLength: Validators.descriptionMax,
                          minLines: 4,
                          maxLines: 8,
                          textCapitalization: TextCapitalization.sentences,
                          onChanged: (_) => _syncText(),
                          decoration: const InputDecoration(
                            labelText: 'What is happening?',
                            hintText: 'Since when, how bad, who is affected. Facts help staff fix it faster.',
                            alignLabelWithHint: true,
                          ),
                          validator: Validators.description,
                        ),
                        const _Step(number: 4, title: 'How urgent?'),
                        _SeverityPicker(
                          selected: d.severity,
                          onSelect: (s) => _cubit.update(d.copyWith(severity: s)),
                        ),
                        const _Step(number: 5, title: 'Add a photo', optional: true),
                        _PhotoField(
                          localPath: d.photoLocalPath,
                          existingUrl: _editing && d.keepExistingPhoto ? widget.editing!.photoUrl : null,
                          onPick: _pick,
                          onRemove: _cubit.removePhoto,
                          enabled: !submitting,
                        ),
                        const SizedBox(height: Gap.xxl),
                        BusyButton(
                          label: _editing ? 'Save changes' : 'Send report',
                          icon: _editing ? Icons.check : Icons.send_outlined,
                          busyLabel: state.progress != null ? 'Uploading photo' : 'Sending',
                          busy: submitting,
                          progress: state.progress,
                          onPressed: _submit,
                        ),
                        const SizedBox(height: Gap.m),
                        Text(
                          'Your name is visible to campus staff only. Other students see the report, never who sent it.',
                          textAlign: TextAlign.center,
                          style: context.text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title, this.optional = false});

  final int number;
  final String title;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: Gap.xxl, bottom: Gap.m),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: p.ink, shape: BoxShape.circle),
            child: Text('$number', style: monoStyle(context, color: p.canvas, size: 12)),
          ),
          const SizedBox(width: Gap.m),
          Text(title, style: context.text.titleMedium),
          if (optional) ...[const SizedBox(width: Gap.s), Text('optional', style: context.text.bodySmall)],
        ],
      ),
    );
  }
}

class _RestoredBanner extends StatelessWidget {
  const _RestoredBanner({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.only(top: Gap.s),
      padding: const EdgeInsets.fromLTRB(Gap.l, Gap.s, Gap.xs, Gap.s),
      decoration: BoxDecoration(color: SanaPalette.tint(AppColors.statusAcknowledged), borderRadius: BorderRadius.circular(Radii.control)),
      child: Row(
        children: [
          const Icon(Icons.history, color: AppColors.statusAcknowledged),
          const SizedBox(width: Gap.m),
          Expanded(child: Text('We kept your unfinished report.', style: context.text.bodyMedium?.copyWith(color: p.ink))),
          IconButton(tooltip: 'Dismiss', onPressed: onDismiss, icon: const Icon(Icons.close)),
        ],
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.selected, required this.onSelect, required this.showError});

  final IncidentCategory? selected;
  final ValueChanged<IncidentCategory> onSelect;
  final bool showError;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(builder: (context, c) {
          final columns = c.maxWidth > 520 ? 4 : 2;
          final width = (c.maxWidth - Gap.s * (columns - 1)) / columns;
          return Wrap(
            spacing: Gap.s,
            runSpacing: Gap.s,
            children: [
              for (final cat in IncidentCategory.values)
                SizedBox(
                  width: width,
                  child: Semantics(
                    selected: cat == selected,
                    button: true,
                    label: '${cat.label}: ${cat.hint}',
                    child: Material(
                      color: cat == selected ? SanaPalette.tint(cat.color) : p.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Radii.control),
                        side: BorderSide(
                          color: cat == selected ? cat.color : (showError ? AppColors.statusRejected : p.line),
                          width: cat == selected ? 1.6 : 1,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(Radii.control),
                        onTap: () => onSelect(cat),
                        child: Padding(
                          padding: const EdgeInsets.all(Gap.m),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(cat.icon, color: context.onTint(cat.color)),
                              const SizedBox(height: Gap.s),
                              Text(cat.label, style: context.text.titleSmall),
                              const SizedBox(height: 2),
                              Text(cat.hint, style: context.text.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        }),
        if (showError)
          Padding(
            padding: const EdgeInsets.only(top: Gap.s, left: Gap.s),
            child: Text('Choose a category', style: context.text.bodySmall?.copyWith(color: AppColors.statusRejected)),
          ),
      ],
    );
  }
}

class _AreaChips extends StatelessWidget {
  const _AreaChips({required this.selected, required this.onSelect, required this.showError});

  final CampusArea? selected;
  final ValueChanged<CampusArea> onSelect;
  final bool showError;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: Gap.s,
          runSpacing: Gap.s,
          children: [
            for (final a in CampusArea.values)
              ChoiceChip(
                label: Text(a.label),
                selected: a == selected,
                onSelected: (_) => onSelect(a),
                side: showError ? const BorderSide(color: AppColors.statusRejected) : null,
              ),
          ],
        ),
        if (showError)
          Padding(
            padding: const EdgeInsets.only(top: Gap.s, left: Gap.s),
            child: Text('Choose an area', style: context.text.bodySmall?.copyWith(color: AppColors.statusRejected)),
          ),
      ],
    );
  }
}

class _SeverityPicker extends StatelessWidget {
  const _SeverityPicker({required this.selected, required this.onSelect});

  final Severity selected;
  final ValueChanged<Severity> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<Severity>(
          segments: [for (final s in Severity.values) ButtonSegment(value: s, label: Text(s.label))],
          selected: {selected},
          onSelectionChanged: (v) => onSelect(v.first),
        ),
        const SizedBox(height: Gap.s),
        Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: selected.color),
            const SizedBox(width: 6),
            Expanded(child: Text(selected.hint, style: context.text.bodySmall)),
          ],
        ),
        if (selected == Severity.critical)
          Container(
            margin: const EdgeInsets.only(top: Gap.m),
            padding: const EdgeInsets.all(Gap.m),
            decoration: BoxDecoration(
              color: SanaPalette.tint(AppColors.statusRejected),
              borderRadius: BorderRadius.circular(Radii.control),
            ),
            child: Text(
              'If someone is in danger right now, call campus security first, then report here.',
              style: context.text.bodyMedium,
            ),
          ),
      ],
    );
  }
}

class _PhotoField extends StatelessWidget {
  const _PhotoField({
    required this.localPath,
    required this.existingUrl,
    required this.onPick,
    required this.onRemove,
    required this.enabled,
  });

  final String? localPath;
  final String? existingUrl;
  final ValueChanged<ImageSource> onPick;
  final VoidCallback onRemove;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hasPhoto = localPath != null || existingUrl != null;
    if (!hasPhoto) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: enabled ? () => onPick(ImageSource.camera) : null,
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Camera'),
            ),
          ),
          const SizedBox(width: Gap.s),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: enabled ? () => onPick(ImageSource.gallery) : null,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Gallery'),
            ),
          ),
        ],
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.card),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: localPath != null
                ? Image.file(File(localPath!), fit: BoxFit.cover)
                : Image.network(existingUrl!, fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => ColoredBox(color: p.line)),
          ),
          Positioned(
            right: Gap.s,
            top: Gap.s,
            child: Row(
              children: [
                _OverlayButton(
                  icon: Icons.swap_horiz,
                  tooltip: 'Replace photo',
                  onTap: enabled ? () => onPick(ImageSource.gallery) : null,
                ),
                const SizedBox(width: Gap.s),
                _OverlayButton(icon: Icons.delete_outline, tooltip: 'Remove photo', onTap: enabled ? onRemove : null),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverlayButton extends StatelessWidget {
  const _OverlayButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      tooltip: tooltip,
      onPressed: onTap,
      style: IconButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: Colors.white),
      icon: Icon(icon),
    );
  }
}

/// Duplicate prevention: open reports in the same category and area.
class _SimilarReports extends StatelessWidget {
  const _SimilarReports({required this.draft, required this.onMeToo});

  final IncidentDraft draft;
  final ValueChanged<Incident> onMeToo;

  @override
  Widget build(BuildContext context) {
    final items = context.select<FeedBloc, List<Incident>>((b) => b.state.items);
    final uid = context.select<AuthBloc, String?>((b) => b.state.user?.uid);
    final similar = IncidentQuery.similar(items, category: draft.category, area: draft.area);
    if (similar.isEmpty) return const SizedBox.shrink();
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.only(top: Gap.l),
      padding: const EdgeInsets.all(Gap.m),
      decoration: BoxDecoration(
        color: SanaPalette.tint(p.signal),
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.content_copy_outlined, size: 18, color: p.signal),
              const SizedBox(width: Gap.s),
              Expanded(
                child: Text(
                  'Already reported? ${similar.length} open ${similar.length == 1 ? 'report matches' : 'reports match'} '
                  'this category and area.',
                  style: context.text.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.m),
          for (final i in similar)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.s),
              child: IncidentCard(
                incident: i,
                viewerUid: uid,
                onTap: () => Navigator.of(context)
                    .push(SessionScope.route(context, IncidentDetailPage(incidentId: i.id))),
                trailing: uid == null || i.isOwnedBy(uid) || i.isAffecting(uid)
                    ? null
                    : TextButton.icon(
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        onPressed: () => onMeToo(i),
                        icon: const Icon(Icons.group_add_outlined, size: 18),
                        label: const Text('Affects me too'),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
