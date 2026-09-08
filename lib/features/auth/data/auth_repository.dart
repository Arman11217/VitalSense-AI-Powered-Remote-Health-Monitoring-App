import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/result.dart';
import 'models/app_user.dart';

/// **Abstract** contract every auth backend must satisfy.
///
/// Keeping this as an interface makes the app trivially testable — any
/// fake/in-memory implementation can be swapped in via Riverpod without
/// touching the UI layer.
abstract interface class AuthRepository {
  /// Stream of the currently authenticated user (or `null` when signed out).
  Stream<AppUser?> get authStateChanges;

  /// Synchronously fetch the current user, if any.
  AppUser? get currentUser;

  /// Sign in an existing account with email + password.
  Future<AuthResult> signIn({required String email, required String password});

  /// Create a new account and persist [displayName] on the profile.
  Future<AuthResult> register({
    required String email,
    required String password,
    required String displayName,
  });

  /// Send a password-reset email.
  Future<AuthResult> sendPasswordReset({required String email});

  /// Send (or resend) the email-verification link.
  Future<AuthResult> sendEmailVerification();

  /// Refresh the locally cached user (e.g. after user verifies email
  /// in their browser).
  Future<AuthResult> reload();

  /// Sign the current user out.
  Future<AuthResult> signOut();

  /// Permanently delete the current account.
  Future<AuthResult> deleteAccount();
}

// ════════════════════════════════════════════════════════════════════
// Firebase implementation
// ════════════════════════════════════════════════════════════════════

/// Production-grade [AuthRepository] backed by **Firebase Authentication**.
///
/// Every public method is wrapped in a defensive `try/catch`. If Firebase
/// is not yet initialized (e.g. before the user runs `flutterfire configure`)
/// or any platform exception is thrown, the method returns a friendly
/// [AuthFailure] — the app **never crashes** during auth.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository([FirebaseAuth? auth])
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  // Friendly fallback shown whenever Firebase is unreachable / unconfigured.
  static const String _demoModeMessage =
      'Firebase not configured yet — running in demo mode. '
      'Run `flutterfire configure` to enable real authentication.';

  // ── Streams ──────────────────────────────────────────────────────
  @override
  Stream<AppUser?> get authStateChanges => _auth.authStateChanges().map(
    (User? u) => u == null ? null : AppUser.fromFirebaseUser(u),
  );

  @override
  AppUser? get currentUser {
    final User? u = _auth.currentUser;
    return u == null ? null : AppUser.fromFirebaseUser(u);
  }

  // ── Sign in ──────────────────────────────────────────────────────
  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    return _guard(() async {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final User? user = credential.user;
      if (user == null) {
        return const AuthFailure('Sign-in failed. Please try again.');
      }
      return AuthSuccess(AppUser.fromFirebaseUser(user));
    }, fallback: 'Unable to sign in right now.');
  }

  // ── Register ─────────────────────────────────────────────────────
  @override
  Future<AuthResult> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    return _guard(() async {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final User? user = credential.user;
      if (user == null) {
        return const AuthFailure('Account creation failed. Please try again.');
      }
      // Persist the display name on the profile.
      await user.updateDisplayName(displayName.trim());
      // Email verification is intentionally skipped — the user is treated
      // as verified on signup so they land on the dashboard immediately.
      // Re-fetch so the cached `displayName` reflects the update.
      await user.reload();
      final User refreshed = _auth.currentUser ?? user;
      return AuthSuccess(AppUser.fromFirebaseUser(refreshed));
    }, fallback: 'Unable to create account right now.');
  }

  // ── Password reset ───────────────────────────────────────────────
  @override
  Future<AuthResult> sendPasswordReset({required String email}) async {
    return _guard(() async {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return AuthSuccess(_demoUser);
    }, fallback: 'Unable to send password-reset email.');
  }

  // ── Email verification ───────────────────────────────────────────
  @override
  Future<AuthResult> sendEmailVerification() async {
    return _guard(() async {
      final User? user = _auth.currentUser;
      if (user == null) {
        return const AuthFailure('No user is currently signed in.');
      }
      if (user.emailVerified) {
        return const AuthFailure('This email is already verified.');
      }
      await user.sendEmailVerification();
      return AuthSuccess(_demoUser);
    }, fallback: 'Unable to send verification email.');
  }

  // ── Reload cached user ───────────────────────────────────────────
  @override
  Future<AuthResult> reload() async {
    return _guard(() async {
      final User? user = _auth.currentUser;
      if (user == null) {
        return const AuthFailure('No user is currently signed in.');
      }
      await user.reload();
      final User? refreshed = _auth.currentUser;
      if (refreshed == null) {
        return const AuthFailure('Session expired. Please sign in again.');
      }
      return AuthSuccess(AppUser.fromFirebaseUser(refreshed));
    }, fallback: 'Unable to refresh account.');
  }

  // ── Sign out ─────────────────────────────────────────────────────
  @override
  Future<AuthResult> signOut() async {
    return _guard(() async {
      await _auth.signOut();
      return AuthSuccess(_demoUser);
    }, fallback: 'Unable to sign out.');
  }

  // ── Delete account ───────────────────────────────────────────────
  @override
  Future<AuthResult> deleteAccount() async {
    return _guard(() async {
      final User? user = _auth.currentUser;
      if (user == null) {
        return const AuthFailure('No user is currently signed in.');
      }
      await user.delete();
      return AuthSuccess(_demoUser);
    }, fallback: 'Unable to delete account.');
  }

  // ═══ Internal helpers ═══

  /// Wraps [body] in a defensive try/catch. Catches every known Firebase,
  /// plugin, and generic exception so the UI never has to deal with raw
  /// stack traces.
  Future<AuthResult> _guard(
    Future<AuthResult> Function() body, {
    required String fallback,
  }) async {
    try {
      return await body();
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'AuthRepository FirebaseAuthException: ${e.code} ${e.message}',
      );
      return AuthFailure(_mapFirebaseMessage(e), e.code);
    } on FirebaseException catch (e) {
      debugPrint('AuthRepository FirebaseException: ${e.code} ${e.message}');
      return AuthFailure('$fallback (${e.code})');
    } on MissingPluginException catch (_) {
      // Firebase native plugin not registered — app is in demo mode.
      debugPrint('AuthRepository: MissingPluginException → demo mode');
      return const AuthFailure(_demoModeMessage, 'demo-mode');
    } on PlatformException catch (e) {
      debugPrint('AuthRepository PlatformException: ${e.code} ${e.message}');
      return AuthFailure('$fallback (${e.code})');
    } catch (e, st) {
      debugPrint('AuthRepository unexpected: $e\n$st');
      return AuthFailure(fallback);
    }
  }

  /// Translates Firebase's cryptic codes into friendly messages.
  String _mapFirebaseMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Incorrect email or password. '
            '(If the account is brand new, make sure you verified '
            'the email and use the password you set during registration.)';
      case 'email-already-in-use':
        return 'An account already exists with this email. '
            'Try logging in instead.';
      case 'weak-password':
        return 'Password is too weak. Use at least 8 characters.';
      case 'operation-not-allowed':
      case 'configuration-not-found':
        return 'Email/Password sign-in is disabled in Firebase Console.\n\n'
            'Fix: Firebase Console → Authentication → Sign-in method → '
            'Email/Password → Enable → Save.';
      case 'invalid-api-key':
      case 'api-key-not-valid':
        return 'Firebase API key is invalid.\n\n'
            'Fix: open Firebase Console → Project Settings → '
            'Your apps → Web app → copy the apiKey and replace the '
            'web block in lib/firebase_options.dart. Then run '
            '`flutter clean && flutter run -d chrome`.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      case 'requires-recent-login':
        return 'Please sign in again to perform this action.';
      case 'app-not-authorized':
      case 'unauthorized-domain':
        return 'This domain is not authorized for Firebase Auth.\n\n'
            'Fix: Firebase Console → Authentication → Settings → '
            'Authorized domains → Add "localhost". Also add the '
            'production domain once you deploy.';
      default:
        return 'Authentication failed (${e.code}). '
            'Open the browser console (F12) for full details, '
            'and verify Firebase Console settings.';
    }
  }
}

/// Placeholder user used for actions that don't yield one (reset email,
/// verification email, sign-out, account deletion).
final AppUser _demoUser = AppUser(
  uid: '__demo__',
  email: '',
  isEmailVerified: false,
  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
);
