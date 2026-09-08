import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'features/auth/application/auth_providers.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/data/local_auth_repository.dart';
import 'features/profile/application/profile_providers.dart';
import 'firebase_options.dart';

/// **Entry point** of the VitalSense application.
///
/// 1. Locks orientation to portrait (medical dashboards are vertical).
/// 2. Loads [SharedPreferences] before booting.
/// 3. Tries to initialise Firebase. The selected [AuthRepository] is
///    stashed in [_startupError] so the login screen can surface the
///    exact failure reason to the user (no more silent sign-ins).
/// 4. Wraps the tree in [ProviderScope] for Riverpod.
/// 5. Runs [App], which boots routing + theming.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  AuthRepository Function(Ref) authRepoFactory =
      (Ref ref) => const LocalOnlyAuthRepository();
  String? startupError;
  bool firebaseReady = false;

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      Firebase.app();
    }
    authRepoFactory = (Ref ref) => FirebaseAuthRepository();
    firebaseReady = true;
    debugPrint('[Main] Firebase initialised â€” using FirebaseAuthRepository');
  } on FirebaseException catch (e, st) {
    // Most common on the web: bad apiKey, project not found, etc.
    debugPrint('[Main] Firebase init failed (FirebaseException): '
        '${e.code} ${e.message}');
    debugPrintStack(stackTrace: st);
    authRepoFactory = (Ref ref) =>
        const LocalOnlyAuthRepository(signedInDemoUser: false);
    startupError = 'Firebase rejected the configuration '
        '(${e.code}). Check firebase_options.dart.';
  } catch (e, st) {
    // Phone: MissingPluginException, PlatformException, or any other
    // startup-time failure. We intentionally do **not** drop the user
    // into the dashboard â€” that was the old behaviour and it was a bug.
    debugPrint('[Main] Firebase init failed â†’ signed-out fallback');
    debugPrint('[Main]   $e');
    debugPrintStack(stackTrace: st);
    authRepoFactory = (Ref ref) =>
        const LocalOnlyAuthRepository(signedInDemoUser: false);
    startupError = 'Firebase is not available on this device '
        '(${e.runtimeType}). Check `google-services.json` '
        'and the Firebase plugin registration.';
  }

  runApp(
    ProviderScope(
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
        authRepositoryProvider.overrideWith(authRepoFactory),
        startupErrorProvider.overrideWithValue(startupError),
        firebaseReadyProvider.overrideWithValue(firebaseReady),
      ],
      child: const App(),
    ),
  );
}

/// Exposed at startup so the login screen can show a friendly banner
/// when Firebase failed to initialise (web bad-key, phone plugin
/// missing, etc.).
final Provider<String?> startupErrorProvider = Provider<String?>((_) => null);

/// Whether Firebase initialised successfully on the current platform.
final Provider<bool> firebaseReadyProvider = Provider<bool>((_) => false);

// (All widget classes removed â€” root app lives in `app/app.dart`.)

// (Old home page removed â€” replaced by feature modules.)

// (Old state class removed â€” see `app/app.dart`.)
