import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sana/core/utils/failure.dart';
import 'package:sana/features/auth/bloc/auth_bloc.dart';
import 'package:sana/features/auth/models/app_user.dart';

import '../../helpers/fakes.dart';

void main() {
  late MockAuthRepository auth;
  late MockUserRepository users;
  late StreamController<AuthAccount?> accounts;

  const unverified = AuthAccount(uid: 'stu1', email: 'amina@alustudent.com', emailVerified: false);
  const verified = AuthAccount(uid: 'stu1', email: 'amina@alustudent.com', emailVerified: true, displayName: 'Amina K');

  setUpAll(() => registerFallbackValue(verified));

  setUp(() {
    auth = MockAuthRepository();
    users = MockUserRepository();
    accounts = StreamController<AuthAccount?>();
    when(() => auth.accountChanges).thenAnswer((_) => accounts.stream);
    when(() => auth.signOut()).thenAnswer((_) async {});
    when(() => users.watch(any())).thenAnswer((_) => const Stream.empty());
  });

  tearDown(() => accounts.close());

  AuthBloc build() => AuthBloc(auth: auth, users: users)..add(const AuthSubscriptionRequested());

  blocTest<AuthBloc, AuthState>(
    'no account means unauthenticated',
    build: build,
    act: (_) => accounts.add(null),
    expect: () => [const AuthState.unauthenticated()],
  );

  blocTest<AuthBloc, AuthState>(
    'an unverified email is held at the verification gate and no profile is touched',
    build: build,
    act: (_) => accounts.add(unverified),
    expect: () => [const AuthState.unverified(unverified)],
    verify: (_) => verifyNever(() => users.ensureProfile(any())),
  );

  blocTest<AuthBloc, AuthState>(
    'a verified account gets its profile and is routed by role',
    setUp: () => when(() => users.ensureProfile(any())).thenAnswer((_) async => staff),
    build: build,
    act: (_) => accounts.add(verified),
    expect: () => [
      isA<AuthState>()
          .having((s) => s.status, 'status', AuthStatus.authenticated)
          .having((s) => s.user?.isStaff, 'isStaff', isTrue),
    ],
  );

  blocTest<AuthBloc, AuthState>(
    'verifying from the gate moves straight to authenticated',
    setUp: () {
      when(() => auth.refreshVerification()).thenAnswer((_) async => true);
      when(() => auth.currentAccount).thenReturn(verified);
      when(() => users.ensureProfile(any())).thenAnswer((_) async => student);
    },
    build: build,
    act: (bloc) async {
      accounts.add(unverified);
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AuthVerificationCheckRequested());
    },
    expect: () => [
      const AuthState.unverified(unverified),
      isA<AuthState>().having((s) => s.status, 'status', AuthStatus.authenticated),
    ],
  );

  blocTest<AuthBloc, AuthState>(
    'tells the student when the link has not been clicked yet',
    setUp: () => when(() => auth.refreshVerification()).thenAnswer((_) async => false),
    build: build,
    act: (bloc) async {
      accounts.add(unverified);
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AuthVerificationCheckRequested());
    },
    expect: () => [
      const AuthState.unverified(unverified),
      isA<AuthState>().having((s) => s.message, 'message', contains('Not verified yet')),
    ],
  );

  blocTest<AuthBloc, AuthState>(
    'a profile failure is shown with a retry, not a blank screen',
    setUp: () => when(() => users.ensureProfile(any())).thenThrow(const Failure('No connection')),
    build: build,
    act: (_) => accounts.add(verified),
    expect: () => [const AuthState.profileError(verified, 'No connection')],
  );

  blocTest<AuthBloc, AuthState>(
    'token refreshes for the same user do not re-create the profile',
    setUp: () => when(() => users.ensureProfile(any())).thenAnswer((_) async => student),
    build: build,
    act: (_) async {
      accounts.add(verified);
      await Future<void>.delayed(Duration.zero);
      accounts.add(verified);
    },
    expect: () => [isA<AuthState>().having((s) => s.status, 'status', AuthStatus.authenticated)],
    verify: (_) => verify(() => users.ensureProfile(any())).called(1),
  );

  blocTest<AuthBloc, AuthState>(
    'signing out returns to unauthenticated',
    setUp: () {
      when(() => users.ensureProfile(any())).thenAnswer((_) async => student);
      when(() => auth.signOut()).thenAnswer((_) async => accounts.add(null));
    },
    build: build,
    act: (bloc) async {
      accounts.add(verified);
      await Future<void>.delayed(Duration.zero);
      bloc.add(const AuthSignOutRequested());
    },
    expect: () => [
      isA<AuthState>().having((s) => s.status, 'status', AuthStatus.authenticated),
      const AuthState.unauthenticated(),
    ],
  );
}
