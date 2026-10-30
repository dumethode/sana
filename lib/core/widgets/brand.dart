import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// The Sana mark: a ticket-shaped tile with a wrench, plus the wordmark.
class SanaMark extends StatelessWidget {
  const SanaMark({super.key, this.size = 44, this.showWordmark = true});

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: p.signal, borderRadius: BorderRadius.circular(size * 0.28)),
          child: Icon(Icons.handyman_outlined, color: p.onSignal, size: size * 0.55),
        ),
        if (showWordmark) ...[
          SizedBox(width: size * 0.3),
          Text(
            'sana',
            style: TextStyle(
              fontFamily: AppFonts.display,
              fontWeight: FontWeight.w700,
              fontSize: size * 0.62,
              letterSpacing: -0.5,
              color: p.ink,
            ),
          ),
        ],
      ],
    );
  }
}

/// Shared frame for the sign-in, sign-up and verification screens.
class AuthFrame extends StatelessWidget {
  const AuthFrame({super.key, required this.title, required this.subtitle, required this.child, this.showBack = false});

  final String title;
  final String subtitle;
  final Widget child;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showBack ? AppBar() : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Gap.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!showBack) ...[const SanaMark(), const SizedBox(height: Gap.xxxl)],
                  Text(title, style: context.text.displaySmall),
                  const SizedBox(height: Gap.s),
                  Text(subtitle, style: context.text.bodyMedium?.copyWith(color: context.palette.inkMuted)),
                  const SizedBox(height: Gap.xxl),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
