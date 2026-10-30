import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/busy_button.dart';
import '../../../core/widgets/feedback.dart';
import '../../auth/models/app_user.dart';
import '../cubit/status_update_cubit.dart';
import '../data/incident_repository.dart';
import '../models/incident.dart';
import '../models/incident_enums.dart';
import 'widgets/tags.dart';

/// Staff-only sheet: pick the next status (only legal moves are offered),
/// optionally re-grade severity, and leave a note the reporter will read.
class StatusUpdateSheet extends StatefulWidget {
  const StatusUpdateSheet({super.key});

  static Future<void> show(BuildContext context, {required Incident incident, required AppUser staff}) {
    final repo = context.read<IncidentRepository>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider(
        create: (_) => StatusUpdateCubit(repository: repo, incident: incident, staff: staff),
        child: const StatusUpdateSheet(),
      ),
    );
  }

  @override
  State<StatusUpdateSheet> createState() => _StatusUpdateSheetState();
}

class _StatusUpdateSheetState extends State<StatusUpdateSheet> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<StatusUpdateCubit>();
    final p = context.palette;
    return BlocConsumer<StatusUpdateCubit, StatusUpdateState>(
      listenWhen: (a, b) => a.status != b.status && (b.status == UpdateStatus.saved || b.status == UpdateStatus.failed),
      listener: (context, state) {
        if (state.status == UpdateStatus.saved) {
          final messenger = ScaffoldMessenger.of(context);
          Navigator.pop(context);
          messenger.showSnackBar(SnackBar(content: Text(state.message!)));
        } else {
          showMessage(context, state.message!, error: true);
        }
      },
      builder: (context, state) {
        final required = cubit.noteRequired;
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, MediaQuery.viewInsetsOf(context).bottom + Gap.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Update ${cubit.incident.refCode}', style: context.text.titleLarge)),
                    StatusPill(cubit.incident.status, dense: true),
                  ],
                ),
                const SizedBox(height: Gap.l),
                const Overline('Move to'),
                const SizedBox(height: Gap.s),
                for (final s in cubit.options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Gap.s),
                    child: _StatusOption(
                      status: s,
                      selected: state.target == s,
                      onTap: () => cubit.selectTarget(s),
                    ),
                  ),
                const SizedBox(height: Gap.m),
                const Overline('Severity'),
                const SizedBox(height: Gap.s),
                SegmentedButton<Severity>(
                  segments: [for (final s in Severity.values) ButtonSegment(value: s, label: Text(s.label))],
                  selected: {state.severity},
                  onSelectionChanged: (v) => cubit.selectSeverity(v.first),
                ),
                const SizedBox(height: Gap.l),
                TextField(
                  controller: _note,
                  maxLines: 3,
                  maxLength: Validators.noteMax,
                  decoration: InputDecoration(
                    labelText: required ? 'Note to reporter (required)' : 'Note to reporter (optional)',
                    hintText: state.target == IncidentStatus.rejected
                        ? 'Why no action is needed, e.g. duplicate of SN-...'
                        : 'What was done, or what happens next',
                    alignLabelWithHint: true,
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.visibility_outlined, size: 16, color: p.inkMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'The reporter and anyone following this report will see the note and your name.',
                        style: context.text.bodySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.l),
                BusyButton(
                  label: 'Save update',
                  busyLabel: 'Saving',
                  busy: state.status == UpdateStatus.saving,
                  onPressed: () => cubit.save(_note.text),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatusOption extends StatelessWidget {
  const _StatusOption({required this.status, required this.selected, required this.onTap});

  final IncidentStatus status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? SanaPalette.tint(status.color) : p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.control),
          side: BorderSide(color: selected ? status.color : p.line, width: selected ? 1.6 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.control),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.l, vertical: Gap.m),
            child: Row(
              children: [
                Icon(status.icon, color: status.color),
                const SizedBox(width: Gap.m),
                Expanded(child: Text(status.label, style: context.text.titleSmall)),
                Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: selected ? status.color : p.inkMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
