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

class SignUpPage extends StatelessWidget {
  const SignUpPage({super.key});

  static Route<void> route() => MaterialPageRoute(builder: (_) => const SignUpPage());

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => AuthFormCubit(ctx.read<AuthRepository>()),
      child: const _SignUpView(),
    );
  }
}

class _SignUpView extends StatefulWidget {
  const _SignUpView();

  @override
  State<_SignUpView> createState() => _SignUpViewState();
}

class _SignUpViewState extends State<_SignUpView> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _email.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    context.read<AuthFormCubit>().signUp(_name.text, _email.text, _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final email = _email.text.trim();
    final showDomainHint = email.contains('@') && Validators.email(email) == null && !Validators.isAluEmail(email);

    return BlocListener<AuthFormCubit, AuthFormState>(
      listenWhen: (a, b) => a.status != b.status && b.status == SubmitStatus.failure,
      listener: (context, state) => showMessage(context, state.message!, error: true),
      child: AuthFrame(
        showBack: true,
        title: 'Create your account',
        subtitle: 'Use your ALU email. We will send a link to confirm it belongs to you.',
        child: Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)),
                  validator: Validators.name,
                ),
                const SizedBox(height: Gap.l),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'ALU email',
                    hintText: 'name@alustudent.com',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                  validator: Validators.email,
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  child: showDomainHint
                      ? Padding(
                          padding: const EdgeInsets.only(top: Gap.s),
                          child: Container(
                            padding: const EdgeInsets.all(Gap.m),
                            decoration: BoxDecoration(
                              color: SanaPalette.tint(AppColors.statusInProgress),
                              borderRadius: BorderRadius.circular(Radii.control),
                            ),
                            child: Text(
                              'This is not an ALU address. It will only work if campus administration '
                              'has registered it for a staff member.',
                              style: context.text.bodySmall?.copyWith(color: context.palette.ink),
                            ),
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
                const SizedBox(height: Gap.l),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    helperText: 'At least 8 characters with a letter and a number',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: _obscure ? 'Show password' : 'Hide password',
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: Validators.password,
                ),
                const SizedBox(height: Gap.l),
                TextFormField(
                  controller: _confirm,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(labelText: 'Confirm password', prefixIcon: Icon(Icons.lock_outline)),
                  validator: (v) => v != _password.text ? 'Passwords do not match' : null,
                ),
                const SizedBox(height: Gap.xxl),
                BlocBuilder<AuthFormCubit, AuthFormState>(
                  builder: (context, state) => BusyButton(
                    label: 'Create account',
                    busyLabel: 'Creating account',
                    busy: state.isSubmitting,
                    onPressed: _submit,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
