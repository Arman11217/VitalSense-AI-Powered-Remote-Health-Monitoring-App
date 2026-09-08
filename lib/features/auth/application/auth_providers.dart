import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../data/models/app_user.dart';
import '../domain/result.dart';

// ════════════════════════════════════════════════════════════════════
// Repository
// ════════════════════════════════════════════════════════════════════

/// The single source of truth for auth backend access.
///
/// Override this provider in tests with an in-memory fake repository.
final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((Ref ref) {
      return FirebaseAuthRepository();
    });

// ════════════════════════════════════════════════════════════════════
// Streams
// ════════════════════════════════════════════════════════════════════

/// Emits the current authenticated user (or `null` when signed out).
/// Initial value is `null` until the first Firebase event arrives.
final StreamProvider<AppUser?> authStateChangesProvider =
    StreamProvider<AppUser?>((Ref ref) {
      final AuthRepository repo = ref.watch(authRepositoryProvider);
      return repo.authStateChanges;
    });

/// Synchronous read of the **latest** auth state value.
///
/// Useful in `initState` and other non-async contexts.
final Provider<AppUser?> currentUserProvider = Provider<AppUser?>((Ref ref) {
  final AsyncValue<AppUser?> state = ref.watch(authStateChangesProvider);
  return state.maybeWhen<AppUser?>(
    data: (AppUser? user) => user,
    orElse: () => ref.read(authRepositoryProvider).currentUser,
  );
});

// ════════════════════════════════════════════════════════════════════
// Controller
// ════════════════════════════════════════════════════════════════════

/// Internal state exposed by [AuthController].
///
/// * `isLoading` drives spinners.
/// * `lastError` is shown via SnackBar on screens that opted into the
///   imperative API.
@immutable
class AuthState {
  const AuthState({this.isLoading = false, this.lastError, this.lastUser});

  final bool isLoading;
  final String? lastError;
  final AppUser? lastUser;

  AuthState copyWith({
    bool? isLoading,
    Object? lastError = _sentinel,
    Object? lastUser = _sentinel,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      lastError: identical(lastError, _sentinel)
          ? this.lastError
          : lastError as String?,
      lastUser: identical(lastUser, _sentinel)
          ? this.lastUser
          : lastUser as AppUser?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthState &&
          other.isLoading == isLoading &&
          other.lastError == lastError &&
          other.lastUser == lastUser;

  @override
  int get hashCode => Object.hash(isLoading, lastError, lastUser);

  static const Object _sentinel = Object();
}

/// State machine coordinating every authentication action.
///
/// UI code calls the methods directly — e.g.
/// `ref.read(authControllerProvider.notifier).signIn(...)` — then reads
/// `ref.watch(authControllerProvider)` to display a spinner.
class AuthController extends Notifier<AuthState> {
  late final AuthRepository _repo;

  @override
  AuthState build() {
    _repo = ref.read(authRepositoryProvider);
    return const AuthState();
  }

  // ─── Helpers ────────────────────────────────────────────────────
  void _setLoading() =>
      state = state.copyWith(isLoading: true, lastError: null);

  void _setError(String? message) =>
      state = state.copyWith(isLoading: false, lastError: message);

  void _setSuccess(AppUser user) =>
      state = state.copyWith(isLoading: false, lastError: null, lastUser: user);

  // ─── Public API ─────────────────────────────────────────────────

  /// Sign in an existing user. Returns the [AuthResult] for callers that
  /// need to react (e.g. navigate).
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    _setLoading();
    final AuthResult result = await _repo.signIn(
      email: email,
      password: password,
    );
    return _apply(result);
  }

  /// Create a new account and persist the display name.
  Future<AuthResult> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _setLoading();
    final AuthResult result = await _repo.register(
      email: email,
      password: password,
      displayName: displayName,
    );
    return _apply(result);
  }

  /// Trigger a password-reset email.
  Future<AuthResult> sendPasswordReset({required String email}) async {
    _setLoading();
    final AuthResult result = await _repo.sendPasswordReset(email: email);
    return _apply(result);
  }

  /// Trigger / resend an email-verification email.
  Future<AuthResult> sendEmailVerification() async {
    _setLoading();
    final AuthResult result = await _repo.sendEmailVerification();
    return _apply(result);
  }

  /// Re-fetch the current user (used after user verifies email).
  Future<AuthResult> reload() async {
    _setLoading();
    final AuthResult result = await _repo.reload();
    return _apply(result);
  }

  /// Sign out the current user.
  Future<AuthResult> signOut() async {
    _setLoading();
    final AuthResult result = await _repo.signOut();
    return _apply(result);
  }

  /// Delete the current account permanently.
  Future<AuthResult> deleteAccount() async {
    _setLoading();
    final AuthResult result = await _repo.deleteAccount();
    return _apply(result);
  }

  /// Wipe any previous error message (called when a screen is dismissed).
  void clearError() => state = state.copyWith(lastError: null);

  // ─── Internal ──────────────────────────────────────────────────

  AuthResult _apply(AuthResult result) {
    if (result.isSuccess) {
      final AppUser? user = result.appUser;
      _setSuccess(user ?? AppUser.empty());
    } else {
      _setError(result.errorMessage);
    }
    return result;
  }
}

/// The [AuthController] instance — listen via `ref.watch`, invoke via
/// `ref.read(...notifier)`.
final NotifierProvider<AuthController, AuthState> authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
