import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Domain-level representation of an authenticated user.
///
/// Decouples our app from `firebase_auth`'s concrete `User` class so the
/// rest of the codebase never imports Firebase directly.
class AppUser extends Equatable {
  const AppUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    required this.isEmailVerified,
    required this.createdAt,
  });

  /// Unique Firebase UID (also used as the primary key).
  final String uid;

  /// Email address — guaranteed non-null for any signed-in account.
  final String email;

  /// Optional display name set during registration or profile edit.
  final String? displayName;

  /// Optional avatar URL.
  final String? photoUrl;

  /// Mirrors `FirebaseUser.emailVerified` — required to unlock the app.
  final bool isEmailVerified;

  /// Account creation timestamp.
  final DateTime createdAt;

  // ═══ Serialization ═══

  /// Builds an [AppUser] from a Firebase [User] instance.
  factory AppUser.fromFirebaseUser(User user) {
    return AppUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      photoUrl: user.photoURL,
      // Email verification is intentionally bypassed — every signed-in
      // user is treated as verified so the dashboard is reachable
      // immediately after sign-in / sign-up.
      isEmailVerified: true,
      createdAt: user.metadata.creationTime ?? DateTime.now(),
    );
  }

  /// Returns an empty (not-signed-in) placeholder. Useful for loading
  /// states and unit tests.
  factory AppUser.empty() => AppUser(
    uid: '',
    email: '',
    isEmailVerified: false,
    createdAt: DateTime.now(),
  );

  /// Serializes to a plain map — handy for `shared_preferences`, logging
  /// or sending to a backend.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'uid': uid,
    'email': email,
    'displayName': displayName,
    'photoUrl': photoUrl,
    'isEmailVerified': isEmailVerified,
    'createdAt': createdAt.toIso8601String(),
  };

  /// Returns true if this represents an unauthenticated placeholder.
  bool get isAnonymous => uid.isEmpty;

  @override
  List<Object?> get props => <Object?>[
    uid,
    email,
    displayName,
    photoUrl,
    isEmailVerified,
    createdAt,
  ];
}
