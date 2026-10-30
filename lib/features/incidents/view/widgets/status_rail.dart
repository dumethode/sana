import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/incident.dart';
import '../../models/incident_enums.dart';

/// Four-stop progress rail: Submitted, Acknowledged, In progress, Resolved.
/// A rejected report replaces the rail with a banner carrying staff's note,
/// because "how far along" no longer applies.
class StatusRail extends StatelessWidget {
  const StatusRail({super.key, required this.incident});

  final Incident incident;

  static const _stops = [
    IncidentStatus.submitted,
    IncidentStatus.acknowledged,
    IncidentStatus.inProgress,
    IncidentStatus.resolved,
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (incident.status == IncidentStatus.rejected) {
      return Container(
        padding: const EdgeInsets.all(Gap.l),
        decoration: BoxDecoration(
          color: SanaPalette.tint(AppColors.statusRejected),
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.block_outlined, color: AppColors.statusRejected),
            const SizedBox(width: Gap.m),
            Expanded(
              child: Text(
                'Staff closed this report without action. ${incident.statusNote ?? ''}',
                style: context.text.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    final current = incident.status.railIndex;
    return Semantics(
      label: 'Progress: step ${current + 1} of 4, ${incident.status.label}',
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var k = 0; k < _stops.length; k++) ...[
              _Stop(status: _stops[k], reached: k <= current, isCurrent: k == current),
              if (k < _stops.length - 1)
                Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.only(bottom: 22),
                    decoration: BoxDecoration(
                      color: k < current ? _stops[k + 1].color : p.line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Short plain-language labels so four stops fit a 360 px phone.
String _railLabel(IncidentStatus s) => switch (s) {
      IncidentStatus.submitted => 'Sent',
      IncidentStatus.acknowledged => 'Seen',
      IncidentStatus.inProgress => 'Working',
      IncidentStatus.resolved => 'Fixed',
      IncidentStatus.rejected => 'Closed',
    };

class _Stop extends StatelessWidget {
  const _Stop({required this.status, required this.reached, required this.isCurrent});

  final IncidentStatus status;
  final bool reached;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = reached ? status.color : p.line;
    return SizedBox(
      width: 56,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: isCurrent ? 34 : 28,
            height: isCurrent ? 34 : 28,
            decoration: BoxDecoration(
              color: reached ? color : p.surface,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(status.icon, size: isCurrent ? 18 : 15, color: reached ? Colors.white : p.inkMuted),
          ),
          const SizedBox(height: 6),
          Text(
            _railLabel(status),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.visible,
            softWrap: false,
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 11,
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              color: reached ? p.ink : p.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}
