import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/profile_repository.dart';
import '../domain/profile_details.dart';

/// SharedPreferences singleton — overridden in `main()` after init.
final Provider<SharedPreferences> sharedPreferencesProvider =
    Provider<SharedPreferences>((Ref ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in ProviderScope.',
  );
});

final Provider<ProfileRepository> profileRepositoryProvider =
    Provider<ProfileRepository>((Ref ref) {
  return ProfileRepository(ref.watch(sharedPreferencesProvider));
});

/// Reactive profile state — call `ref.read(...).notifier.update(...)` to save.
class ProfileNotifier extends StateNotifier<ProfileDetails> {
  ProfileNotifier(this._repo) : super(_repo.load());
  final ProfileRepository _repo;

  Future<void> update(ProfileDetails next) async {
    state = next;
    await _repo.save(next);
  }

  Future<void> reset() async {
    state = const ProfileDetails();
    await _repo.clear();
  }
}

final StateNotifierProvider<ProfileNotifier, ProfileDetails>
    profileDetailsProvider =
    StateNotifierProvider<ProfileNotifier, ProfileDetails>(
        (Ref ref) => ProfileNotifier(ref.watch(profileRepositoryProvider)));
