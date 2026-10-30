import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/failure.dart';
import '../data/auth_repository.dart';
import '../data/user_repository.dart';
import '../models/app_user.dart';

part 'auth_event.dart';
part 'auth_state.dart';

/// Owns the session for the whole app.
///
/// It listens to Firebase Auth, gates unverified accounts, makes sure a
/// profile document exists, and then keeps that profile live (so a changed
/// display name or the reporting cooldown update everywhere at once). The
/// root navigator reacts to [AuthState.status] and swaps the whole stack, so
/// signing out from a deep page always lands on the sign-in screen.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({required AuthRepository auth, required UserRepository users})
      : _auth = auth,
        _users = users,
        super(const AuthState.unknown()) {
    on<AuthSubscriptionRequested>(_onSubscriptionRequested);
    // Sequential: two quick account emissions must not both try to create
    // the profile document.
    on<_AuthAccountChanged>(_onAccountChanged, transformer: _sequential());
    on<_AuthProfileChanged>(_onProfileChanged);
    on<AuthVerificationCheckRequested>(_onVerificationCheck);
    on<AuthProfileRetryRequested>(_onRetry);
    on<AuthSignOutRequested>(_onSignOut);
  }

  final AuthRepository _auth;
  final UserRepository _users;
  StreamSubscription<AppUser?>? _profileSub;

  static EventTransformer<E> _sequential<E>() => (events, mapper) => events.asyncExpand(mapper);

  Future<void> _onSubscriptionRequested(AuthSubscriptionRequested event, Emitter<AuthState> emit) {
    return emit.onEach<AuthAccount?>(
      _auth.accountChanges,
      onData: (account) => add(_AuthAccountChanged(account)),
      onError: (_, _) => emit(const AuthState.unauthenticated()),
    );
  }

  Future<void> _onAccountChanged(_AuthAccountChanged event, Emitter<AuthState> emit) async {
    final account = event.account;
    if (account == null) {
      await _profileSub?.cancel();
      _profileSub = null;
      emit(const AuthState.unauthenticated());
      return;
    }
    if (!account.emailVerified) {
      emit(AuthState.unverified(account));
      return;
    }
    // Token refreshes re-emit the same account; nothing to do.
    if (state.status == AuthStatus.authenticated && state.user?.uid == account.uid) return;

    try {
      final user = await _users.ensureProfile(account);
      emit(AuthState.authenticated(account, user));
      await _profileSub?.cancel();
      _profileSub = _users.watch(account.uid).listen(
            (u) => add(_AuthProfileChanged(u)),
            onError: (_) {}, // Keep the last good profile; screens show their own errors.
          );
    } on Failure catch (f) {
      emit(AuthState.profileError(account, f.message));
    }
  }

  void _onProfileChanged(_AuthProfileChanged event, Emitter<AuthState> emit) {
    final user = event.user;
    if (user == null || state.account == null || state.status != AuthStatus.authenticated) return;
    emit(AuthState.authenticated(state.account!, user));
  }

  Future<void> _onVerificationCheck(AuthVerificationCheckRequested event, Emitter<AuthState> emit) async {
    // Clear the previous message so the same text can be shown again.
    if (state.message != null) emit(state.copyWith());
    try {
      final verified = await _auth.refreshVerification();
      if (verified) {
        add(_AuthAccountChanged(_auth.currentAccount));
      } else if (!event.silent) {
        emit(state.copyWith(message: 'Not verified yet. Open the link in your inbox, then try again.'));
      }
    } on Failure catch (f) {
      if (!event.silent) emit(state.copyWith(message: f.message));
    }
  }

  void _onRetry(AuthProfileRetryRequested event, Emitter<AuthState> emit) {
    add(_AuthAccountChanged(_auth.currentAccount));
  }

  Future<void> _onSignOut(AuthSignOutRequested event, Emitter<AuthState> emit) async {
    await _profileSub?.cancel();
    _profileSub = null;
    await _auth.signOut();
  }

  @override
  Future<void> close() async {
    await _profileSub?.cancel();
    return super.close();
  }
}
