import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/animated_gradient_bg.dart';
import '../../../core/widgets/glass_card.dart';
import '../application/auth_providers.dart';
import '../data/models/app_user.dart';
import '../domain/result.dart';

/// **Email verification** screen.
///
/// Two affordances:
///   1. **Resend email** — triggers another verification link.
///   2. **I've verified — continue** — reloads the cached user; if
///      `emailVerified` is now `true`, the router redirect takes them home.
class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;

  @override
  void initState() {
    super.initState();
    // If somehow the user is already verified, bounce to home.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _autoRedirectIfVerified(),
    );
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _autoRedirectIfVerified() {
    final AppUser? user = ref.read(currentUserProvider);
    if (user != null && user.isEmailVerified && mounted) {
      context.go(AppRoutes.home);
    }
  }

  void _startCooldown() {
    setState(() => _cooldownSeconds = 60);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_cooldownSeconds <= 1) {
        t.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds -= 1);
      }
    });
  }

  Future<void> _resend() async {
    if (_cooldownSeconds > 0) return;
    final AuthResult result = await ref
        .read(authControllerProvider.notifier)
        .sendEmailVerification();
    if (!mounted) return;
    if (result.isSuccess) {
      _startCooldown();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Verification email re-sent.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Could not resend email.'),
            behavior: SnackBarBehavior.floating,
            showCloseIcon: true,
          ),
        );
    }
    ref.read(authControllerProvider.notifier).clearError();
  }

  Future<void> _checkVerified() async {
    final AuthResult result = await ref
        .read(authControllerProvider.notifier)
        .reload();
    if (!mounted) return;
    if (result.isSuccess && (result.appUser?.isEmailVerified ?? false)) {
      context.go(AppRoutes.home);
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              "We couldn't confirm your email yet. Please click the link first.",
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
    ref.read(authControllerProvider.notifier).clearError();
  }

  @override
  Widget build(BuildContext context) {
    final AuthState authState = ref.watch(authControllerProvider);
    final AppUser? user = ref.watch(currentUserProvider);
    final bool isLoading = authState.isLoading;
    final TextTheme text = Theme.of(context).textTheme;
    final String email = user?.email ?? 'your email address';

    return Scaffold(
      body: AnimatedGradientBg(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // ═══ Back ═══
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: isLoading
                        ? null
                        : () => context.go(AppRoutes.login),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.emailVerification,
                  textAlign: TextAlign.center,
                  style: text.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'One more step to unlock VitalSense.',
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 28),

                // ═══ Card ═══
                GlassCard(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // Envelope icon
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.mark_email_unread_rounded,
                          size: 56,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Check your inbox',
                        textAlign: TextAlign.center,
                        style: text.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: text.bodyMedium,
                          children: <InlineSpan>[
                            const TextSpan(
                              text: 'We sent a verification link to ',
                            ),
                            TextSpan(
                              text: email,
                              style: text.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const TextSpan(text: '. Open it to continue.'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Don't see it? Check your spam folder or wait a minute.",
                        textAlign: TextAlign.center,
                        style: text.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ── Resend ──
                      OutlinedButton.icon(
                        onPressed: isLoading || _cooldownSeconds > 0
                            ? null
                            : _resend,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(
                          _cooldownSeconds > 0
                              ? 'Resend in ${_cooldownSeconds}s'
                              : 'Resend email',
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── I've verified — continue ──
                      FilledButton.icon(
                        onPressed: isLoading ? null : _checkVerified,
                        icon: const Icon(Icons.verified_rounded),
                        label: isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : const Text("I've verified — continue"),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // ═══ Sign out link ═══
                TextButton.icon(
                  onPressed: isLoading
                      ? () async {
                          await ref
                              .read(authControllerProvider.notifier)
                              .signOut();
                          if (context.mounted) context.go(AppRoutes.login);
                        }
                      : null,
                  icon: const Icon(Icons.logout_rounded, color: Colors.white),
                  label: Text(
                    'Use a different account',
                    style: text.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
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
