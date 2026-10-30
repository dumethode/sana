import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sana/core/theme/app_theme.dart';
import 'package:sana/core/utils/failure.dart';
import 'package:sana/features/auth/data/auth_repository.dart';
import 'package:sana/features/auth/view/sign_in_page.dart';

import '../helpers/fakes.dart';

void main() {
  late MockAuthRepository auth;

  setUp(() => auth = MockAuthRepository());

  Widget app() => RepositoryProvider<AuthRepository>.value(
        value: auth,
        child: MaterialApp(theme: AppTheme.light(), home: const SignInPage()),
      );

  testWidgets('validates before any network call', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1000));
    await tester.pumpWidget(app());
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    verifyNever(() => auth.signIn(email: any(named: 'email'), password: any(named: 'password')));
  });

  testWidgets('shows the plain-language reason when sign-in fails', (tester) async {
    when(() => auth.signIn(email: any(named: 'email'), password: any(named: 'password')))
        .thenThrow(const Failure('Email or password is incorrect.'));
    await tester.binding.setSurfaceSize(const Size(420, 1000));
    await tester.pumpWidget(app());
    await tester.enterText(find.byType(TextFormField).at(0), 'amina@alustudent.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrongpass1');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Email or password is incorrect.'), findsOneWidget);
  });
}
