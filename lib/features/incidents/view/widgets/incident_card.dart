import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/time_format.dart';
import '../../models/incident.dart';
import 'tags.dart';

/// The "ticket": a coloured stub carrying the category on the left, and the
/// report summary on the right. Reused by the feed, My reports, the staff
/// queue and the duplicate hint on the report form.
class IncidentCard extends StatelessWidget {
  const IncidentCard({
    super.key,
    required this.incident,
    required this.onTap,
    this.viewerUid,
    this.showSeverity = false,
    this.trailing,
  });

  final Incident incident;
  final VoidCallback onTap;
  final String? viewerUid;
  final bool showSeverity;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final i = incident;
    final mine = viewerUid != null && i.isOwnedBy(viewerUid!);
    final affectsMe = viewerUid != null && i.isAffecting(viewerUid!);

    return Semantics(
      button: true,
      label: '${i.category.label} report ${i.refCode}: ${i.title}. ${i.status.label}. ${i.area.label}.',
      child: Material(
        color: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(color: p.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Stub(incident: i),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Gap.l, Gap.m, Gap.m, Gap.m),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(i.refCode, style: monoStyle(context)),
                            if (mine) ...[
                              const SizedBox(width: Gap.s),
                              Text('YOURS', style: monoStyle(context, color: p.signal, size: 11)),
                            ],
                            const Spacer(),
                            Text(TimeFormat.relative(i.createdAt), style: monoStyle(context)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(i.title, style: context.text.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.place_outlined, size: 15, color: p.inkMuted),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${i.area.label} · ${i.locationDetail}',
                                style: context.text.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Gap.m),
                        Wrap(
                          spacing: Gap.s,
                          runSpacing: Gap.s,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            StatusPill(i.status, dense: true),
                            if (showSeverity || i.severity.weight >= 3) SeverityTag(i.severity, dense: true),
                            if (i.hasPendingWrites) const SyncingTag(),
                            _AffectedCount(count: i.affectedCount, highlighted: affectsMe),
                            ?trailing,
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (i.photoUrl != null) _Thumb(url: i.photoUrl!),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stub extends StatelessWidget {
  const _Stub({required this.incident});

  final Incident incident;

  @override
  Widget build(BuildContext context) {
    final c = incident.category.color;
    return Container(
      width: 52,
      decoration: BoxDecoration(
        color: SanaPalette.tint(c),
        border: Border(right: BorderSide(color: c.withValues(alpha: 0.35), width: 1.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(incident.category.icon, color: c, size: 24),
          const SizedBox(height: Gap.s),
          // Perforation dots: the visual cue that this is a ticket.
          for (var k = 0; k < 3; k++)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Container(
                width: 3,
                height: 3,
                decoration: BoxDecoration(color: c.withValues(alpha: 0.5), shape: BoxShape.circle),
              ),
            ),
        ],
      ),
    );
  }
}

class _AffectedCount extends StatelessWidget {
  const _AffectedCount({required this.count, required this.highlighted});

  final int count;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = highlighted ? p.signal : p.inkMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(highlighted ? Icons.group : Icons.group_outlined, size: 16, color: color),
        const SizedBox(width: 4),
        Text('$count affected', style: monoStyle(context, color: color)),
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, Gap.m, Gap.m, Gap.m),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 64,
          height: 64,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            cacheWidth: 192,
            errorBuilder: (_, _, _) =>
                ColoredBox(color: p.line, child: Icon(Icons.broken_image_outlined, color: p.inkMuted)),
            loadingBuilder: (_, child, progress) => progress == null ? child : ColoredBox(color: p.line),
          ),
        ),
      ),
    );
  }
}
