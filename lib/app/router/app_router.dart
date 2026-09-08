import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_providers.dart';
import '../../features/auth/data/models/app_user.dart';
import '../../features/auth/presentation/email_verification_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/device/presentation/device_management_screen.dart';
import '../../features/emergency/presentation/emergency_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/shell/presentation/home_shell.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/ecg/presentation/ecg_screen.dart';
import '../../features/ai_analysis/presentation/ai_analysis_screen.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';

/// **GoRouter** configuration for the whole application.
///
/// The `redirect` callback centralises every auth-aware navigation
/// decision so screens stay pure. The router auto-refreshes whenever
/// the auth stream emits a new value via [_AuthRouterRefreshListenable].
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String emailVerification = '/verify-email';
  static const String home = '/home';
}

/// Routes that are reachable **without** an account.
const Set<String> _publicAuthRoutes = <String>{
  AppRoutes.splash,
  AppRoutes.onboarding,
  AppRoutes.login,
  AppRoutes.register,
  AppRoutes.forgotPassword,
};

final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  final _AuthRouterRefreshListenable refreshListenable =
      _AuthRouterRefreshListenable(ref);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    refreshListenable: refreshListenable,
    redirect: (BuildContext context, GoRouterState state) {
      // The auth provider may still be loading — fall back to /splash.
      final AsyncValue<AppUser?> authState = ref.read(authStateChangesProvider);
      final AppUser? user = authState.valueOrNull;
      final String loc = state.matchedLocation;

      debugPrint(
        '[Router] redirect → loc=$loc user=${user?.email ?? 'null'} '
        'verified=${user?.isEmailVerified ?? '-'}',
      );

      // 1. No user → only allow public routes.
      if (user == null) {
        if (_publicAuthRoutes.contains(loc)) return null;
        return AppRoutes.login;
      }

      // 2. Signed in → bounce from pre-auth & verify-email screens to /home.
      //    Email verification is intentionally skipped so the user lands on
      //    the dashboard immediately after sign-in / sign-up.
      if (loc == AppRoutes.splash ||
          loc == AppRoutes.onboarding ||
          loc == AppRoutes.login ||
          loc == AppRoutes.register ||
          loc == AppRoutes.forgotPassword ||
          loc == AppRoutes.emailVerification) {
        return AppRoutes.home;
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.splash,
        builder: (BuildContext context, GoRouterState state) =>
            const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (BuildContext context, GoRouterState state) =>
            const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (BuildContext context, GoRouterState state) =>
            const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (BuildContext context, GoRouterState state) =>
            const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (BuildContext context, GoRouterState state) =>
            const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.emailVerification,
        builder: (BuildContext context, GoRouterState state) =>
            const EmailVerificationScreen(),
      ),
      // Parent /home route that mounts the bottom-nav shell and forwards
      // into the right branch via [HomeShell.currentIndex]. We deliberately
      // avoid [StatefulShellRoute] here because its branch paths are not
      // registered as top-level routes — so any `redirect` returning
      // '/home' (or '/home/<tab>') used to fall through to errorBuilder.
      GoRoute(
        path: AppRoutes.home,
        builder: (BuildContext context, GoRouterState state) =>
            const HomeShell(),
        routes: <RouteBase>[
          GoRoute(
            path: 'ecg',
            builder: (BuildContext context, GoRouterState state) =>
                const HomeShell(child: EcgScreen()),
          ),
          GoRoute(
            path: 'ai',
            builder: (BuildContext context, GoRouterState state) =>
                const HomeShell(child: AiAnalysisScreen()),
          ),
          GoRoute(
            path: 'history',
            builder: (BuildContext context, GoRouterState state) =>
                const HomeShell(child: HistoryScreen()),
          ),
          GoRoute(
            path: 'profile',
            builder: (BuildContext context, GoRouterState state) =>
                const HomeShell(child: ProfileScreen()),
            routes: <RouteBase>[
              GoRoute(
                path: 'reports',
                builder: (BuildContext context, GoRouterState state) =>
                    const ReportsScreen(),
              ),
              GoRoute(
                path: 'emergency',
                builder: (BuildContext context, GoRouterState state) =>
                    const EmergencyScreen(),
              ),
              GoRoute(
                path: 'device',
                builder: (BuildContext context, GoRouterState state) =>
                    const DeviceManagementScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (BuildContext context, GoRouterState state) => Scaffold(
      body: Center(
        child: Text(
          'Route not found: ${state.uri}',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    ),
  );
});

/// Bridges the Riverpod [authStateChangesProvider] stream to GoRouter's
/// `refreshListenable` so the router auto-re-evaluates redirects on every
/// auth change.
class _AuthRouterRefreshListenable extends ChangeNotifier {
  _AuthRouterRefreshListenable(this._ref) {
    _sub = _ref.listen<AsyncValue<AppUser?>>(
      authStateChangesProvider,
      (AsyncValue<AppUser?>? prev, AsyncValue<AppUser?> next) =>
          notifyListeners(),
      fireImmediately: false,
    );
  }

  final Ref _ref;
  late final ProviderSubscription<AsyncValue<AppUser?>> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
