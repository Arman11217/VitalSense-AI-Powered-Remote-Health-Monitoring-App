import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/animated_gradient_bg.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../main.dart';
import '../application/auth_providers.dart';
import '../domain/result.dart';

/// **Login** screen.
///
/// Collects email + password and delegates to [AuthController].
/// On success, navigates to `/home` (router redirect handles the
/// email-verification gate if needed).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // ═══ State ═══
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ═══ Submit ═══
  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    debugPrint(
      '[Login] submitting email=${_emailCtrl.text.trim()} '
      'len=${_passwordCtrl.text.length}',
    );
    final AuthResult result = await ref
        .read(authControllerProvider.notifier)
        .signIn(email: _emailCtrl.text, password: _passwordCtrl.text);

    debugPrint(
      '[Login] result isSuccess=${result.isSuccess} '
      'error=${result.errorMessage}',
    );

    if (!mounted) return;

    if (result.isSuccess) {
      // The router's redirect logic will handle verification + home.
      context.go(AppRoutes.home);
    } else {
      _showError(result.errorMessage ?? 'Sign-in failed.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 10),
          showCloseIcon: true,
        ),
      );
    ref.read(authControllerProvider.notifier).clearError();
  }

  // ═══ Diagnose dialog ═══
  Future<void> _showDiagnoseDialog() async {
    final String? startErr = ref.read(startupErrorProvider);
    final bool ready = ref.read(firebaseReadyProvider);
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Firebase health check'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _DiagRow(
                  ok: ready,
                  label: ready
                      ? 'Firebase initialised OK on this device.'
                      : 'Firebase init FAILED on this device.',
                ),
                if (startErr != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      startErr,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'If login/signup still fails, open Firebase Console and '
                  'verify ALL of the following:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text('① Authentication → Sign-in method → '
                    'Email/Password must be ENABLED.'),
                const Text('② Authentication → Settings → '
                    'Authorized domains must include "localhost".'),
                const Text('③ Project Settings → Your apps → Web app → '
                    'copy apiKey, appId, authDomain, projectId into '
                    'lib/firebase_options.dart (web block).'),
                const SizedBox(height: 8),
                const Text(
                  'After any change run:\n'
                  '  flutter clean\n'
                  '  flutter pub get\n'
                  '  flutter run -d chrome',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Open browser DevTools (F12) → Console tab for the raw '
                  'FirebaseAuthException code.',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AuthState authState = ref.watch(authControllerProvider);
    final bool isLoading = authState.isLoading;
    // Pull lastError from the underlying state so we can show it inline.
    final String? errorFromState = ref.watch(
      authControllerProvider.select((s) => s.lastError),
    );
    // Surface Firebase startup failures (bad apiKey, missing plugin, …).
    final String? startupError = ref.watch(startupErrorProvider);
    final bool firebaseReady = ref.watch(firebaseReadyProvider);

    return Scaffold(
      body: AnimatedGradientBg(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    MediaQuery.sizeOf(context).height -
                    MediaQuery.paddingOf(context).vertical -
                    56,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // ═══ Header ═══
                  const SizedBox(height: 32),
                  _Logo(),
                  const SizedBox(height: 16),
                  Text(
                    AppStrings.appName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppStrings.appTagline,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ═══ Firebase startup banner (only when init failed) ═══
                  if (!firebaseReady && startupError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _StartupWarningBanner(
                        message: startupError,
                      ),
                    ),

                  // ═══ Firebase startup banner (only when init failed) ═══
                  if (!firebaseReady && startupError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _StartupWarningBanner(
                        message: startupError,
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    AppStrings.appName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppStrings.appTagline,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ═══ Card ═══
                  GlassCard(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    child: Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            AppStrings.login,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Welcome back. Sign in to continue monitoring.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 20),

                          // ── Email ──
                          TextFormField(
                            controller: _emailCtrl,
                            focusNode: _emailFocus,
                            textInputAction: TextInputAction.next,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            enableSuggestions: false,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              hintText: 'you@vitalsense.app',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: Validators.email,
                            onFieldSubmitted: (_) =>
                                _passwordFocus.requestFocus(),
                          ),
                          const SizedBox(height: 14),

                          // ── Password ──
                          TextFormField(
                            controller: _passwordCtrl,
                            focusNode: _passwordFocus,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              hintText: 'At least 8 characters',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Show password'
                                    : 'Hide password',
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                            validator: (String? v) {
                              if (v == null || v.isEmpty) {
                                return 'Password is required';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _submit(),
                          ),

                          // ── Forgot link ──
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: isLoading
                                  ? null
                                  : () => context.go(AppRoutes.forgotPassword),
                              child: const Text(AppStrings.forgotPassword),
                            ),
                          ),

                          // ── Inline error ──
                          if (errorFromState != null) ...<Widget>[
                            const SizedBox(height: 4),
                            _InlineError(message: errorFromState),
                          ],

                          const SizedBox(height: 12),

                          // ── Login button ──
                          FilledButton(
                            onPressed: isLoading ? null : _submit,
                            child: isLoading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(AppStrings.login),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ═══ Footer ═══
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        "Don't have an account?",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                      ),
                      TextButton(
                        onPressed: isLoading
                            ? null
                            : () => context.go(AppRoutes.register),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        child: const Text(
                          'Sign up',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // ═══ Diagnose Firebase (helps when login keeps failing) ═══
                  Center(
                    child: TextButton.icon(
                      onPressed: isLoading ? null : _showDiagnoseDialog,
                      icon: const Icon(
                        Icons.health_and_safety_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                      label: const Text(
                        'Diagnose Firebase',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══ Small reusable widgets (kept in same file for cohesion) ═══

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: const Icon(
          Icons.favorite_rounded,
          color: Colors.white,
          size: 40,
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.error_outline, color: scheme.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// Yellow warning banner shown on top of the login card when Firebase
/// initialisation failed at app startup (web: bad apiKey, phone: missing
/// plugin, etc.). Helps the user understand *why* their sign-in is
/// failing instead of showing a generic "auth failed" toast.
class _StartupWarningBanner extends StatelessWidget {
  const _StartupWarningBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade100.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade700, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Firebase not initialised',
                  style: TextStyle(
                    color: Colors.amber.shade900,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.amber.shade900,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Single check row in the diagnose dialog.
class _DiagRow extends StatelessWidget {
  const _DiagRow({required this.ok, required this.label});

  final bool ok;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          ok ? Icons.check_circle : Icons.cancel,
          color: ok ? Colors.green : Colors.red,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
      ],
    );
  }
}
