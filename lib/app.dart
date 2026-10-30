import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_cubit.dart';
import 'core/widgets/brand.dart';
import 'core/widgets/state_views.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/data/user_repository.dart';
import 'features/auth/view/sign_in_page.dart';
import 'features/auth/view/verify_email_page.dart';
import 'features/incidents/data/incident_repository.dart';
import 'features/shell/home_shell.dart';

/// Root widget. Repositories are injected so tests can pass fakes.
class SanaApp extends StatelessWidget {
  const SanaApp({
    super.key,
    required this.authRepository,
    required this.userRepository,
    required this.incidentRepository,
  });

  final AuthRepository authRepository;
  final UserRepository userRepository;
  final IncidentRepository incidentRepository;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authRepository),
        RepositoryProvider.value(value: userRepository),
        RepositoryProvider.value(value: incidentRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => AuthBloc(auth: authRepository, users: userRepository)
              ..add(const AuthSubscriptionRequested()),
          ),
          BlocProvider(create: (_) => ThemeCubit()),
        ],
        child: const _AppView(),
      ),
    );
  }
}

class _AppView extends StatefulWidget {
  const _AppView();

  @override
  State<_AppView> createState() => _AppViewState();
}

class _AppViewState extends State<_AppView> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  NavigatorState get _nav => _navigatorKey.currentState!;

  /// Replaces the entire stack whenever the session changes. This is why a
  /// sign-out from a deep page, or a staff allowlist change, always lands on
  /// the right root with nothing stale underneath.
  void _onAuthChanged(BuildContext context, AuthState state) {
    final Route<void> route = switch (state.status) {
      AuthStatus.unknown => _SplashPage.route(),
      AuthStatus.unauthenticated => SignInPage.route(),
      AuthStatus.unverified => VerifyEmailPage.route(),
      AuthStatus.profileError => _ProfileErrorPage.route(),
      AuthStatus.authenticated => HomeShell.route(state.user!),
    };
    _nav.pushAndRemoveUntil(route, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<ThemeCubit>().state;
    return MaterialApp(
      title: 'Sana',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      builder: (context, child) => BlocListener<AuthBloc, AuthState>(
        listenWhen: (a, b) =>
            a.status != b.status || a.user?.uid != b.user?.uid || a.user?.role != b.user?.role,
        listener: _onAuthChanged,
        child: child!,
      ),
      onGenerateRoute: (_) => _SplashPage.route(),
    );
  }
}

class _SplashPage extends StatelessWidget {
  const _SplashPage();

  static Route<void> route() => MaterialPageRoute(builder: (_) => const _SplashPage());

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SanaMark(size: 56),
            SizedBox(height: Gap.xxl),
            SizedBox(width: 120, child: LinearProgressIndicator()),
          ],
        ),
      ),
    );
  }
}

/// Signed in and verified, but the profile could not be loaded or created
/// (usually offline on first launch, or rules not yet published).
class _ProfileErrorPage extends StatelessWidget {
  const _ProfileErrorPage();

  static Route<void> route() => MaterialPageRoute(builder: (_) => const _ProfileErrorPage());

  @override
  Widget build(BuildContext context) {
    final message = context.select((AuthBloc b) => b.state.message ?? 'Unknown error');
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ErrorState(
                message: message,
                onRetry: () => context.read<AuthBloc>().add(const AuthProfileRetryRequested()),
              ),
            ),
            TextButton(
              onPressed: () => context.read<AuthBloc>().add(const AuthSignOutRequested()),
              child: const Text('Sign out'),
            ),
            const SizedBox(height: Gap.l),
          ],
        ),
      ),
    );
  }
}
