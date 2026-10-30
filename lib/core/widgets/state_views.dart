import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Shown when a list has loaded and is genuinely empty.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.action});

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: p.surface, shape: BoxShape.circle, border: Border.all(color: p.line)),
              child: Icon(icon, color: p.inkMuted, size: 28),
            ),
            const SizedBox(height: Gap.l),
            Text(title, style: context.text.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: Gap.s),
            Text(message, style: context.text.bodySmall, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: Gap.xl), action!],
          ],
        ),
      ),
    );
  }
}

/// Shown when loading failed. Always offers a way forward.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.cloud_off_outlined,
      title: 'Could not load this',
      message: message,
      action: OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
    );
  }
}

/// Placeholder tickets that pulse while the first snapshot arrives, so the
/// layout does not jump when real cards replace them.
class TicketSkeletonList extends StatefulWidget {
  const TicketSkeletonList({super.key, this.count = 5});

  final int count;

  @override
  State<TicketSkeletonList> createState() => _TicketSkeletonListState();
}

class _TicketSkeletonListState extends State<TicketSkeletonList> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      label: 'Loading reports',
      child: FadeTransition(
        opacity: Tween(begin: 0.45, end: 1.0).animate(_c),
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(Gap.l),
          itemCount: widget.count,
          separatorBuilder: (_, _) => const SizedBox(height: Gap.m),
          itemBuilder: (_, _) => Container(
            height: 112,
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(color: p.line),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  decoration: BoxDecoration(
                    color: p.line.withValues(alpha: 0.5),
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(Radii.card)),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(Gap.l),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _bar(p, 70),
                        const SizedBox(height: Gap.m),
                        _bar(p, 200),
                        const SizedBox(height: Gap.s),
                        _bar(p, 140),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bar(SanaPalette p, double w) => Container(
        width: w,
        height: 10,
        decoration: BoxDecoration(color: p.line, borderRadius: BorderRadius.circular(6)),
      );
}
