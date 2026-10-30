import 'package:flutter/material.dart';

/// Primary button that shows its own progress and blocks double taps.
/// Pass [progress] (0..1) to show determinate progress, e.g. a photo upload.
class BusyButton extends StatelessWidget {
  const BusyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.busyLabel,
    this.progress,
    this.icon,
  });

  final String label;
  final String? busyLabel;
  final VoidCallback? onPressed;
  final bool busy;
  final double? progress;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final busyText = progress != null ? '${busyLabel ?? 'Uploading'} ${(progress! * 100).round()}%' : busyLabel ?? label;
    return Semantics(
      button: true,
      label: busy ? busyText : label,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          disabledBackgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.55),
          disabledForegroundColor: Colors.white,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: busy
              ? Row(
                  key: const ValueKey('busy'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white, value: progress),
                    ),
                    const SizedBox(width: 12),
                    Text(busyText),
                  ],
                )
              : Row(
                  key: const ValueKey('idle'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
                    Text(label),
                  ],
                ),
        ),
      ),
    );
  }
}
