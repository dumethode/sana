import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/incident_enums.dart';

/// Pill showing a coloured dot and label on a 12% tint of the same colour.
class _TintPill extends StatelessWidget {
  const _TintPill({required this.color, required this.label, this.icon, this.dense = false});

  final Color color;
  final String label;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Color.lerp(color, Colors.white, 0.35)! : color;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(color: SanaPalette.tint(color), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: dense ? 13 : 15, color: fg)
          else
            Container(width: 7, height: 7, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontSize: dense ? 12 : 13,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key, this.dense = false});

  final IncidentStatus status;
  final bool dense;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Status: ${status.label}',
        child: ExcludeSemantics(child: _TintPill(color: status.color, label: status.label, dense: dense)),
      );
}

class SeverityTag extends StatelessWidget {
  const SeverityTag(this.severity, {super.key, this.dense = false});

  final Severity severity;
  final bool dense;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Severity: ${severity.label}',
        child: ExcludeSemantics(
          child: _TintPill(
            color: severity.color,
            label: severity.label,
            icon: severity.weight >= 3 ? Icons.priority_high_rounded : Icons.signal_cellular_alt_rounded,
            dense: dense,
          ),
        ),
      );
}

class CategoryTag extends StatelessWidget {
  const CategoryTag(this.category, {super.key, this.dense = false});

  final IncidentCategory category;
  final bool dense;

  @override
  Widget build(BuildContext context) =>
      _TintPill(color: category.color, label: category.label, icon: category.icon, dense: dense);
}

/// Shown while a write has not reached the server (offline or slow network).
class SyncingTag extends StatelessWidget {
  const SyncingTag({super.key});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: 'Saved on this phone. It will sync when you are back online.',
        child: _TintPill(color: context.palette.inkMuted, label: 'Syncing', icon: Icons.cloud_upload_outlined, dense: true),
      );
}
