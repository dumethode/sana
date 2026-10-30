part of 'auth_bloc.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Start listening to Firebase Auth. Dispatched once at app start.
final class AuthSubscriptionRequested extends AuthEvent {
  const AuthSubscriptionRequested();
}

final class _AuthAccountChanged extends AuthEvent {
  const _AuthAccountChanged(this.account);
  final AuthAccount? account;

  @override
  List<Object?> get props => [account];
}

final class _AuthProfileChanged extends AuthEvent {
  const _AuthProfileChanged(this.user);
  final AppUser? user;

  @override
  List<Object?> get props => [user];
}

/// Ask Firebase whether the email link has been clicked yet. [silent] is used
/// by the background poll so it does not flash a message every few seconds.
final class AuthVerificationCheckRequested extends AuthEvent {
  const AuthVerificationCheckRequested({this.silent = false});
  final bool silent;

  @override
  List<Object?> get props => [silent];
}

final class AuthProfileRetryRequested extends AuthEvent {
  const AuthProfileRetryRequested();
}

final class AuthSignOutRequested extends AuthEvent {
  const AuthSignOutRequested();
}
