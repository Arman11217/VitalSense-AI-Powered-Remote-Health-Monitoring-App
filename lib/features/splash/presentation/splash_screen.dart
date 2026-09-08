import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/animated_gradient_bg.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/data/models/app_user.dart';

/// Initial splash screen.
///
/// Shown for ~1.8 s, then inspects the current auth state and pushes the
/// user to the correct destination.
///
/// The router's `redirect` callback takes over after the first navigation,
/// so the choices below are only ever seen **once per cold start**.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  Future<void> _route() async {
    // Brief branding delay.
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;

    // Wait for the auth stream's **first real emission** instead of trusting
    // a cached snapshot. Firebase's `authStateChanges()` flushes a cached
    // user synchronously on first read — but on cold-start that cache may
    // belong to a stale session on the same device, so we want the actual
    // server-confirmed user before deciding where to go.
    AppUser? user;
    try {
      final Stream<AppUser?> stream =
          ref.read(authRepositoryProvider).authStateChanges;
      user = await stream
          .first
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () => null,
          );
    } catch (e) {
      debugPrint('[Splash] auth stream wait failed: $e');
      user = null;
    }
    if (!mounted) return;

    debugPrint(
      '[Splash] routing decision: '
      'user=${user?.email ?? 'null'} '
      'verified=${user?.isEmailVerified ?? '-'}',
    );

    if (user == null) {
      context.go(AppRoutes.onboarding);
    } else if (user.isEmailVerified) {
      context.go(AppRoutes.home);
    } else {
      // Unverified cached users get re-prompted on the verify-email screen.
      context.go(AppRoutes.emailVerification);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedGradientBg(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Colors.white,
                  size: 80,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                AppStrings.appName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.appTagline,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 40),
              const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
