import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/time_format.dart';
import '../../models/incident_event.dart';

/// Vertical audit trail of everything that happened to a report.
class IncidentTimeline extends StatelessWidget {
  const IncidentTimeline({super.key, required this.events});

  final List<IncidentEvent> events;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (events.isEmpty) {
      return Text('Timeline will appear once the report syncs.', style: context.text.bodySmall);
    }
    final ordered = events.reversed.toList(); // newest first
    return Column(
      children: [
        for (var k = 0; k < ordered.length; k++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 28,
                  child: Column(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        margin: const EdgeInsets.only(top: 3),
                        decoration: BoxDecoration(
                          color: k == 0 ? ordered[k].to.color : p.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: ordered[k].to.color, width: 2),
                        ),
                      ),
                      if (k < ordered.length - 1)
                        Expanded(child: Container(width: 2, color: p.line, margin: const EdgeInsets.symmetric(vertical: 2))),
                    ],
                  ),
                ),
                const SizedBox(width: Gap.s),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: Gap.l),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ordered[k].headline, style: context.text.titleSmall),
                        const SizedBox(height: 2),
                        Text(
                          '${TimeFormat.stamp(ordered[k].createdAt)}  ·  '
                          '${ordered[k].actorName ?? (ordered[k].actorRole == 'staff' ? 'Staff' : 'Reporter')}',
                          style: monoStyle(context, size: 11),
                        ),
                        if (ordered[k].note != null && ordered[k].note!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(Gap.m),
                            decoration: BoxDecoration(
                              color: p.canvas,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: p.line),
                            ),
                            child: Text(ordered[k].note!, style: context.text.bodyMedium),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
