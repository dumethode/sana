import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/busy_button.dart';
import '../../../core/widgets/feedback.dart';
import '../cubit/auth_form_cubit.dart';
import '../data/auth_repository.dart';
import 'sign_up_page.dart';

class SignInPage extends StatelessWidget {
  const SignInPage({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const SignInPage());

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => AuthFormCubit(ctx.read<AuthRepository>()),
      child: const _SignInView(),
    );
  }
}

class _SignInView extends StatefulWidget {
  const _SignInView();

  @override
  State<_SignInView> createState() => _SignInViewState();
}

class _SignInViewState extends State<_SignInView> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    context.read<AuthFormCubit>().signIn(_email.text, _password.text);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthFormCubit, AuthFormState>(
      listenWhen: (a, b) => a.status != b.status && b.status == SubmitStatus.failure,
      listener: (context, state) => showMessage(context, state.message!, error: true),
      child: AuthFrame(
        title: 'Report it. Track it. Get it fixed.',
        subtitle: 'Sign in with your ALU account to report campus issues and follow them to resolution.',
        child: Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'ALU email', prefixIcon: Icon(Icons.alternate_email)),
                  validator: Validators.email,
                ),
                const SizedBox(height: Gap.l),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: _obscure ? 'Show password' : 'Hide password',
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) => Validators.required(v, field: 'Password'),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: () => _openReset(context), child: const Text('Forgot password?')),
                ),
                const SizedBox(height: Gap.s),
                BlocBuilder<AuthFormCubit, AuthFormState>(
                  builder: (context, state) => BusyButton(
                    label: 'Sign in',
                    busyLabel: 'Signing in',
                    busy: state.isSubmitting,
                    onPressed: _submit,
                  ),
                ),
                const SizedBox(height: Gap.l),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).push(SignUpPage.route()),
                  child: const Text('Create an account'),
                ),
                const SizedBox(height: Gap.xxl),
                Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 16, color: context.palette.inkMuted),
                    const SizedBox(width: Gap.s),
                    Expanded(
                      child: Text(
                        'Other students never see who filed a report. Only campus staff can.',
                        style: context.text.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openReset(BuildContext context) {
    final cubit = context.read<AuthFormCubit>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(value: cubit, child: _ResetSheet(initialEmail: _email.text)),
    );
  }
}

class _ResetSheet extends StatefulWidget {
  const _ResetSheet({required this.initialEmail});

  final String initialEmail;

  @override
  State<_ResetSheet> createState() => _ResetSheetState();
}

class _ResetSheetState extends State<_ResetSheet> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthFormCubit, AuthFormState>(
      listenWhen: (a, b) => b.status == SubmitStatus.success,
      listener: (context, state) {
        Navigator.pop(context);
        showMessage(context, state.message ?? 'Reset link sent.');
      },
      child: Padding(
        padding: EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, MediaQuery.viewInsetsOf(context).bottom + Gap.xl),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Reset your password', style: context.text.titleLarge),
              const SizedBox(height: Gap.s),
              Text('We will email you a link to choose a new password.', style: context.text.bodySmall),
              const SizedBox(height: Gap.l),
              TextFormField(
                controller: _email,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'ALU email'),
                validator: Validators.email,
              ),
              const SizedBox(height: Gap.l),
              BlocBuilder<AuthFormCubit, AuthFormState>(
                builder: (context, state) => BusyButton(
                  label: 'Send reset link',
                  busyLabel: 'Sending',
                  busy: state.isSubmitting,
                  onPressed: () {
                    if (_form.currentState!.validate()) context.read<AuthFormCubit>().sendReset(_email.text);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
