import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/busy_button.dart';
import '../../../core/widgets/feedback.dart';
import '../bloc/auth_bloc.dart';
import '../cubit/auth_form_cubit.dart';
import '../data/auth_repository.dart';

/// Gate for accounts whose email is not verified yet. Nothing else in the
/// app is reachable from here, and security rules refuse every read and
/// write from an unverified token, so the gate holds even for a modified
/// client.
class VerifyEmailPage extends StatelessWidget {
  const VerifyEmailPage({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const VerifyEmailPage());

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => AuthFormCubit(ctx.read<AuthRepository>()),
      child: const _VerifyView(),
    );
  }
}

class _VerifyView extends StatefulWidget {
  const _VerifyView();

  @override
  State<_VerifyView> createState() => _VerifyViewState();
}

class _VerifyViewState extends State<_VerifyView> with WidgetsBindingObserver {
  Timer? _poll;
  Timer? _cooldownTimer;
  int _cooldown = 30;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Quietly re-check while the student is in their inbox.
    _poll = Timer.periodic(const Duration(seconds: 6), (_) {
      context.read<AuthBloc>().add(const AuthVerificationCheckRequested(silent: true));
    });
    _startCooldown();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the mail app is the most likely moment of success.
    if (state == AppLifecycleState.resumed) {
      context.read<AuthBloc>().add(const AuthVerificationCheckRequested(silent: true));
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = 30);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkNow() async {
    setState(() => _checking = true);
    context.read<AuthBloc>().add(const AuthVerificationCheckRequested());
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    final email = context.select((AuthBloc b) => b.state.account?.email ?? '');
    final p = context.palette;
    return MultiBlocListener(
      listeners: [
        BlocListener<AuthBloc, AuthState>(
          listenWhen: (a, b) => b.message != null && a.message != b.message,
          listener: (context, state) => showMessage(context, state.message!, error: true),
        ),
        BlocListener<AuthFormCubit, AuthFormState>(
          listenWhen: (a, b) => a.status != b.status && b.status != SubmitStatus.submitting,
          listener: (context, state) {
            if (state.status == SubmitStatus.failure) showMessage(context, state.message!, error: true);
            if (state.status == SubmitStatus.success) {
              showMessage(context, state.message!);
              _startCooldown();
            }
          },
        ),
      ],
      child: AuthFrame(
        title: 'Check your inbox',
        subtitle: 'Verification keeps Sana for the ALU community and makes every report accountable.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(Gap.l),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(Radii.card),
                border: Border.all(color: p.line),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: SanaPalette.tint(p.signal), shape: BoxShape.circle),
                    child: Icon(Icons.mark_email_unread_outlined, color: p.signal),
                  ),
                  const SizedBox(width: Gap.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Link sent to', style: context.text.bodySmall),
                        Text(email, style: context.text.titleSmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Gap.l),
            Text(
              'Open the link, then come back. This screen checks automatically every few seconds. '
              'Not there? Look in Junk or Other.',
              style: context.text.bodyMedium,
            ),
            const SizedBox(height: Gap.xxl),
            BusyButton(label: 'I have verified my email', busyLabel: 'Checking', busy: _checking, onPressed: _checkNow),
            const SizedBox(height: Gap.m),
            BlocBuilder<AuthFormCubit, AuthFormState>(
              builder: (context, state) => OutlinedButton(
                onPressed: _cooldown > 0 || state.isSubmitting
                    ? null
                    : () => context.read<AuthFormCubit>().resendVerification(),
                child: Text(_cooldown > 0 ? 'Resend email in ${_cooldown}s' : 'Resend email'),
              ),
            ),
            const SizedBox(height: Gap.s),
            TextButton(
              onPressed: () => context.read<AuthBloc>().add(const AuthSignOutRequested()),
              child: const Text('Use a different account'),
            ),
          ],
        ),
      ),
    );
  }
}
