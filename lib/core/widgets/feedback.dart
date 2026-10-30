import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// One place for transient messages so they look the same everywhere.
void showMessage(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(error ? Icons.error_outline : Icons.check_circle_outline,
              color: error ? const Color(0xFFFF8A80) : const Color(0xFF7EE2A8), size: 20),
          const SizedBox(width: Gap.m),
          Expanded(child: Text(message)),
        ],
      ),
    ));
}

/// Confirmation for destructive or irreversible actions.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: ctx.text.titleMedium),
      content: Text(message, style: ctx.text.bodyMedium),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: AppColors.statusRejected) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Small mono uppercase label used above sections ("LOCATION", "TIMELINE").
class Overline extends StatelessWidget {
  const Overline(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: monoStyle(context, color: color, size: 11));
}
