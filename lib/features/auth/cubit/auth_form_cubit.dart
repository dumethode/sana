import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/failure.dart';
import '../data/auth_repository.dart';

enum SubmitStatus { idle, submitting, success, failure }

class AuthFormState extends Equatable {
  const AuthFormState({this.status = SubmitStatus.idle, this.message});

  final SubmitStatus status;
  final String? message;

  bool get isSubmitting => status == SubmitStatus.submitting;

  @override
  List<Object?> get props => [status, message];
}

/// Submission state for the sign-in, sign-up and reset-password forms.
/// Navigation after success is driven by [AuthBloc], not by this cubit.
class AuthFormCubit extends Cubit<AuthFormState> {
  AuthFormCubit(this._auth) : super(const AuthFormState());

  final AuthRepository _auth;

  Future<void> signIn(String email, String password) =>
      _run(() => _auth.signIn(email: email, password: password));

  Future<void> signUp(String name, String email, String password) =>
      _run(() => _auth.signUp(name: name, email: email, password: password));

  Future<void> sendReset(String email) => _run(
        () => _auth.sendPasswordReset(email),
        success: 'Reset link sent. Check your inbox.',
      );

  Future<void> resendVerification() => _run(
        _auth.resendVerification,
        success: 'Verification email sent again.',
      );

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    if (state.isSubmitting) return;
    emit(const AuthFormState(status: SubmitStatus.submitting));
    try {
      await action();
      if (!isClosed) emit(AuthFormState(status: SubmitStatus.success, message: success));
    } catch (e) {
      if (!isClosed) emit(AuthFormState(status: SubmitStatus.failure, message: Failure.from(e).message));
    }
  }
}
