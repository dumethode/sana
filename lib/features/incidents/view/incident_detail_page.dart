import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/models/app_user.dart';
import '../../shell/session.dart';
import '../cubit/incident_detail_cubit.dart';
import '../data/incident_repository.dart';
import '../models/incident.dart';
import '../models/incident_enums.dart';
import 'photo_viewer_page.dart';
import 'report_form_page.dart';
import 'status_update_sheet.dart';
import 'widgets/status_rail.dart';
import 'widgets/tags.dart';
import 'widgets/timeline.dart';

class IncidentDetailPage extends StatelessWidget {
  const IncidentDetailPage({super.key, required this.incidentId});

  final String incidentId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => IncidentDetailCubit(
        repository: ctx.read<IncidentRepository>(),
        incidentId: incidentId,
        viewer: ctx.read<AuthBloc>().state.user!,
      )..start(),
      child: const _DetailView(),
    );
  }
}

class _DetailView extends StatelessWidget {
  const _DetailView();

  @override
  Widget build(BuildContext context) {
    final viewer = context.select<AuthBloc, AppUser?>((b) => b.state.user);
    return BlocConsumer<IncidentDetailCubit, IncidentDetailState>(
      listenWhen: (a, b) => b.message != null && (a.action != b.action || a.deleted != b.deleted),
      listener: (context, state) {
        showMessage(context, state.message!, error: state.action == DetailAction.failed);
        if (state.deleted) Navigator.of(context).pop();
      },
      builder: (context, state) {
        final incident = state.incident;
        return Scaffold(
          appBar: AppBar(
            title: Text(incident?.refCode ?? 'Report', style: monoStyle(context, size: 15, color: context.palette.ink)),
            actions: [
              if (incident != null && viewer != null && incident.isOwnedBy(viewer.uid) && incident.isEditableByOwner)
                _OwnerMenu(incident: incident),
            ],
          ),
          body: switch (state.status) {
            DetailStatus.loading => const Center(child: CircularProgressIndicator()),
            DetailStatus.failure => ErrorState(
                message: state.message ?? 'Unknown error',
                onRetry: () => context.read<IncidentDetailCubit>().retry(),
              ),
            DetailStatus.missing => const EmptyState(
                icon: Icons.delete_outline,
                title: 'Report removed',
                message: 'The reporter deleted this before staff picked it up.',
              ),
            DetailStatus.ready => viewer == null ? const SizedBox.shrink() : _Body(incident: incident!, viewer: viewer),
          },
          bottomNavigationBar: incident == null || viewer == null || state.status != DetailStatus.ready
              ? null
              : _ActionBar(incident: incident, viewer: viewer, busy: state.action == DetailAction.working),
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.incident, required this.viewer});

  final Incident incident;
  final AppUser viewer;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final state = context.watch<IncidentDetailCubit>().state;
    final i = incident;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.xxxl),
      child: MaxWidth(
        width: 720,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (i.photoUrl != null) ...[
              _Photo(incident: i),
              const SizedBox(height: Gap.l),
            ],
            Wrap(
              spacing: Gap.s,
              runSpacing: Gap.s,
              children: [
                CategoryTag(i.category),
                SeverityTag(i.severity),
                if (i.hasPendingWrites) const SyncingTag(),
              ],
            ),
            const SizedBox(height: Gap.m),
            Text(i.title, style: context.text.headlineSmall),
            const SizedBox(height: Gap.s),
            _Meta(icon: Icons.place_outlined, text: '${i.area.label} · ${i.locationDetail}'),
            _Meta(icon: Icons.schedule, text: 'Reported ${TimeFormat.stamp(i.createdAt)}'),
            _Meta(
              icon: Icons.group_outlined,
              text: i.affectedCount == 1 ? 'Affects the reporter' : 'Affects ${i.affectedCount} people',
            ),
            const SizedBox(height: Gap.xl),
            _Section(
              label: 'Progress',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusRail(incident: i),
                  if (i.statusNote != null && i.status != IncidentStatus.rejected) ...[
                    const SizedBox(height: Gap.l),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(Gap.m),
                      decoration: BoxDecoration(
                        color: SanaPalette.tint(i.status.color),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('Latest update: ${i.statusNote}', style: context.text.bodyMedium),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Gap.l),
            _Section(label: 'What is wrong', child: Text(i.description, style: context.text.bodyLarge)),
            if (state.reporter != null) ...[
              const SizedBox(height: Gap.l),
              _Section(
                label: viewer.isStaff ? 'Reporter (staff only)' : 'Your details (hidden from students)',
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: SanaPalette.tint(p.signal),
                      child: Text(
                        state.reporter!.name.isEmpty ? '?' : state.reporter!.name[0].toUpperCase(),
                        style: TextStyle(color: p.signal, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: Gap.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(state.reporter!.name, style: context.text.titleSmall),
                          Text(state.reporter!.email, style: context.text.bodySmall),
                        ],
                      ),
                    ),
                    Icon(Icons.lock_outline, size: 18, color: p.inkMuted),
                  ],
                ),
              ),
            ],
            const SizedBox(height: Gap.l),
            _Section(label: 'Timeline', child: IncidentTimeline(events: state.events)),
          ],
        ),
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.incident});

  final Incident incident;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      label: 'Photo of the issue. Tap to enlarge.',
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(PhotoViewerPage.route(incident.photoUrl!, incident.id)),
        child: Hero(
          tag: 'photo-${incident.id}',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Radii.card),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Image.network(
                incident.photoUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : ColoredBox(color: p.line, child: const Center(child: CircularProgressIndicator())),
                errorBuilder: (_, _, _) => ColoredBox(
                  color: p.line,
                  child: Center(child: Text('Photo could not load', style: context.text.bodySmall)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: context.palette.inkMuted),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: context.text.bodySmall)),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Gap.l),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Overline(label), const SizedBox(height: Gap.m), child],
      ),
    );
  }
}

class _OwnerMenu extends StatelessWidget {
  const _OwnerMenu({required this.incident});

  final Incident incident;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Report options',
      onSelected: (v) async {
        final cubit = context.read<IncidentDetailCubit>();
        if (v == 'edit') {
          await Navigator.of(context).push(
            SessionScope.route(context, ReportFormPage(editing: incident), fullscreenDialog: true),
          );
        } else if (v == 'delete') {
          final ok = await confirm(
            context,
            title: 'Delete this report?',
            message: 'It will be removed for everyone, together with its photo. This cannot be undone.',
            confirmLabel: 'Delete',
            destructive: true,
          );
          if (ok) await cubit.delete();
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit'))),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_outline, color: AppColors.statusRejected),
            title: Text('Delete'),
          ),
        ),
      ],
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.incident, required this.viewer, required this.busy});

  final Incident incident;
  final AppUser viewer;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final cubit = context.read<IncidentDetailCubit>();
    final mine = incident.isOwnedBy(viewer.uid);

    Widget? action;
    String? hint;
    if (viewer.isStaff) {
      action = FilledButton.icon(
        onPressed: busy ? null : () => StatusUpdateSheet.show(context, incident: incident, staff: viewer),
        icon: const Icon(Icons.sync_alt),
        label: const Text('Update status'),
      );
    } else if (mine && incident.isEditableByOwner) {
      hint = 'You can edit or delete this until staff pick it up.';
    } else if (mine && incident.canBeReopened) {
      action = OutlinedButton.icon(
        onPressed: busy ? null : () => _reopen(context, cubit),
        icon: const Icon(Icons.replay),
        label: const Text('Problem is back? Reopen'),
      );
    } else if (!mine && incident.status.isOpen) {
      final on = incident.isAffecting(viewer.uid);
      action = on
          ? OutlinedButton.icon(
              onPressed: busy ? null : cubit.toggleAffected,
              icon: Icon(Icons.group, color: p.signal),
              label: const Text('You are affected too'),
            )
          : FilledButton.icon(
              onPressed: busy ? null : cubit.toggleAffected,
              icon: const Icon(Icons.group_add_outlined),
              label: const Text('Affects me too'),
            );
    }
    if (action == null && hint == null) return const SizedBox.shrink();

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(Gap.l, Gap.m, Gap.l, Gap.m),
        decoration: BoxDecoration(color: p.surface, border: Border(top: BorderSide(color: p.line))),
        child: action != null
            ? SizedBox(height: 52, width: double.infinity, child: action)
            : Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: p.inkMuted),
                  const SizedBox(width: Gap.s),
                  Expanded(child: Text(hint!, style: context.text.bodySmall)),
                ],
              ),
      ),
    );
  }

  Future<void> _reopen(BuildContext context, IncidentDetailCubit cubit) async {
    final note = await showDialog<String>(context: context, builder: (_) => const _ReopenDialog());
    if (note != null) await cubit.reopen(note);
  }
}

class _ReopenDialog extends StatefulWidget {
  const _ReopenDialog();

  @override
  State<_ReopenDialog> createState() => _ReopenDialogState();
}

class _ReopenDialogState extends State<_ReopenDialog> {
  final _form = GlobalKey<FormState>();
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Reopen this report', style: context.text.titleMedium),
      content: Form(
        key: _form,
        child: TextFormField(
          controller: _note,
          autofocus: true,
          maxLines: 3,
          maxLength: Validators.noteMax,
          decoration: const InputDecoration(hintText: 'What is still wrong?'),
          validator: Validators.note,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (_form.currentState!.validate()) Navigator.pop(context, _note.text.trim());
          },
          child: const Text('Reopen'),
        ),
      ],
    );
  }
}
