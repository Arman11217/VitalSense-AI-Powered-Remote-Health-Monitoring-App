import 'dart:async';

import '../domain/result.dart';
import 'auth_repository.dart';
import 'models/app_user.dart';

/// **In-memory** [AuthRepository] used when Firebase is not available
/// (e.g. running `flutter run -d chrome` without a configured Firebase
/// project, or when [Firebase.initializeApp] throws on a phone build
/// that has not been configured).
///
/// By default ([signedInDemoUser] = `true`) it reports a demo user as
/// signed in so the rest of the navigation flow (router redirect →
/// /home) works without a real backend — useful for offline UX demos.
///
/// Pass [signedInDemoUser] = `false` when [Firebase.initializeApp]
/// **failed** at startup. In that case [authStateChanges] emits `null`,
/// which forces the router to redirect the user to the login screen
/// instead of silently dropping them into the dashboard.
class LocalOnlyAuthRepository implements AuthRepository {
  const LocalOnlyAuthRepository({this.signedInDemoUser = true});

  /// `true`  → emit a fake signed-in demo user (default, offline-demo UX).
  /// `false` → emit `null` so the router pushes the user to /login.
  final bool signedInDemoUser;

  static final AppUser _demoUser = AppUser(
    uid: 'local-demo',
    email: 'demo@vitalsense.local',
    displayName: 'Demo Patient',
    isEmailVerified: true,
    createdAt: DateTime(2026, 1, 1),
  );

  @override
  Stream<AppUser?> get authStateChanges => Stream<AppUser?>.value(
        signedInDemoUser ? _demoUser : null,
      );

  @override
  AppUser? get currentUser => signedInDemoUser ? _demoUser : null;

  Future<AuthResult> _ok() async {
    if (!signedInDemoUser) {
      return const AuthFailure(
        'Authentication backend is not available in this build. '
        'Run `flutterfire configure` and rebuild.',
        'demo-mode',
      );
    }
    return AuthResult.success(_demoUser);
  }

  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) =>
      _ok();

  @override
  Future<AuthResult> register({
    required String email,
    required String password,
    required String displayName,
  }) =>
      _ok();

  @override
  Future<AuthResult> sendPasswordReset({required String email}) => _ok();

  @override
  Future<AuthResult> sendEmailVerification() => _ok();

  @override
  Future<AuthResult> reload() => _ok();

  @override
  Future<AuthResult> signOut() => _ok();

  @override
  Future<AuthResult> deleteAccount() => _ok();
}
