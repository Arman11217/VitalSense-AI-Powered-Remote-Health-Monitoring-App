import '../data/models/app_user.dart';

/// Sealed result wrapper for every authentication action.
///
/// Using a sealed class (Dart 3) gives us exhaustive pattern matching at
/// the call site — the compiler enforces handling both success and
/// failure paths.
sealed class AuthResult {
  const AuthResult();

  /// Convenience constructor for the success branch.
  const factory AuthResult.success(AppUser user) = AuthSuccess;

  /// Convenience constructor for the failure branch.
  const factory AuthResult.failure(String message, [String? code]) =
      AuthFailure;

  /// Returns the authenticated user, or `null` if this is a failure.
  AppUser? get appUser => switch (this) {
    AuthSuccess(:final AppUser user) => user,
    AuthFailure() => null,
  };

  /// Returns the human-readable error message, or `null` on success.
  String? get errorMessage => switch (this) {
    AuthSuccess() => null,
    AuthFailure(:final String message) => message,
  };

  /// `true` when the operation succeeded.
  bool get isSuccess => this is AuthSuccess;
}

/// Successful authentication — carries the signed-in user.
class AuthSuccess extends AuthResult {
  const AuthSuccess(this.user);

  final AppUser user;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is AuthSuccess && other.user == user);

  @override
  int get hashCode => user.hashCode;
}

/// Failed authentication — carries an error message and an optional code.
class AuthFailure extends AuthResult {
  const AuthFailure(this.message, [this.code]);

  final String message;
  final String? code;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthFailure && other.message == message && other.code == code;

  @override
  int get hashCode => Object.hash(message, code);
}
