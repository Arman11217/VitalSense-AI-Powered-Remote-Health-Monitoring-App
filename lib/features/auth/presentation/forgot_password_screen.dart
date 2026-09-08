import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/animated_gradient_bg.dart';
import '../../../core/widgets/glass_card.dart';
import '../application/auth_providers.dart';
import '../domain/result.dart';

/// **Forgot password** screen.
///
/// Asks for the user's email and dispatches a Firebase reset link.
/// On success a green confirmation card replaces the form.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailCtrl = TextEditingController();
  final FocusNode _emailFocus = FocusNode();

  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final AuthResult result = await ref
        .read(authControllerProvider.notifier)
        .sendPasswordReset(email: _emailCtrl.text);

    if (!mounted) return;

    if (result.isSuccess) {
      setState(() => _sent = true);
    } else {
      _showError(result.errorMessage ?? 'Could not send reset email.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          showCloseIcon: true,
        ),
      );
    ref.read(authControllerProvider.notifier).clearError();
  }

  @override
  Widget build(BuildContext context) {
    final AuthState authState = ref.watch(authControllerProvider);
    final bool isLoading = authState.isLoading;
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      body: AnimatedGradientBg(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // ═══ Back button ═══
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: isLoading
                        ? null
                        : () => context.go(AppRoutes.login),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),

                // ═══ Header ═══
                Text(
                  'Reset password',
                  textAlign: TextAlign.center,
                  style: text.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "We'll send you a secure link to choose a new one.",
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 28),

                // ═══ Card ═══
                GlassCard(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    switchInCurve: Curves.easeOut,
                    child: _sent
                        ? _SuccessPanel(email: _emailCtrl.text.trim())
                        : _FormPanel(
                            key: const ValueKey<String>('forgot-form'),
                            formKey: _formKey,
                            controller: _emailCtrl,
                            focusNode: _emailFocus,
                            isLoading: isLoading,
                            onSubmit: _submit,
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                // ═══ Footer ═══
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      'Remembered it?',
                      style: text.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                    ),
                    TextButton(
                      onPressed: isLoading
                          ? null
                          : () => context.go(AppRoutes.login),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      child: const Text(
                        'Back to login',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══ Internal sub-widgets ═══

class _FormPanel extends StatelessWidget {
  const _FormPanel({
    super.key,
    required this.formKey,
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Form(
      key: formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Icon(
            Icons.lock_reset_rounded,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Forgot your password?',
            textAlign: TextAlign.center,
            style: text.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Enter the email associated with your account.',
            textAlign: TextAlign.center,
            style: text.bodySmall,
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'you@vitalsense.app',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: Validators.email,
            onFieldSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: isLoading ? null : onSubmit,
            icon: const Icon(Icons.send_rounded),
            label: isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : const Text('Send reset link'),
          ),
        ],
      ),
    );
  }
}

class _SuccessPanel extends StatelessWidget {
  const _SuccessPanel({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Column(
      key: const ValueKey<String>('forgot-success'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_circle_rounded,
            size: 56,
            color: scheme.primary,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Check your inbox',
          textAlign: TextAlign.center,
          style: text.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'We sent a password-reset link to:',
          textAlign: TextAlign.center,
          style: text.bodyMedium,
        ),
        const SizedBox(height: 6),
        Text(
          email,
          textAlign: TextAlign.center,
          style: text.titleMedium?.copyWith(color: scheme.primary),
        ),
        const SizedBox(height: 18),
        Text(
          "Didn't get it? Check your spam folder or wait a minute and try again.",
          textAlign: TextAlign.center,
          style: text.bodySmall?.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: email));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Email copied to clipboard.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          icon: const Icon(Icons.copy_rounded),
          label: const Text('Copy email'),
        ),
      ],
    );
  }
}
