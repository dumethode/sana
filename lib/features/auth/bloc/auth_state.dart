part of 'auth_bloc.dart';

enum AuthStatus { unknown, unauthenticated, unverified, authenticated, profileError }

final class AuthState extends Equatable {
  const AuthState._({required this.status, this.account, this.user, this.message});

  const AuthState.unknown() : this._(status: AuthStatus.unknown);
  const AuthState.unauthenticated() : this._(status: AuthStatus.unauthenticated);
  const AuthState.unverified(AuthAccount account) : this._(status: AuthStatus.unverified, account: account);
  const AuthState.authenticated(AuthAccount account, AppUser user)
      : this._(status: AuthStatus.authenticated, account: account, user: user);
  const AuthState.profileError(AuthAccount account, String message)
      : this._(status: AuthStatus.profileError, account: account, message: message);

  final AuthStatus status;
  final AuthAccount? account;
  final AppUser? user;

  /// One-off information for the current screen (e.g. "not verified yet").
  final String? message;

  AuthState copyWith({String? message}) =>
      AuthState._(status: status, account: account, user: user, message: message);

  @override
  List<Object?> get props => [status, account, user, message];
}
