import 'package:shared_preferences/shared_preferences.dart';

import '../domain/profile_details.dart';

/// Persists the user's [ProfileDetails] in `shared_preferences`.
class ProfileRepository {
  ProfileRepository(this._prefs);
  final SharedPreferences _prefs;

  static const String _key = 'vitalsense.profile.v1';

  ProfileDetails load() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const ProfileDetails();
    try {
      // Stored as a simple delimited string to avoid pulling in `dart:convert`.
      final parts = raw.split('\u0001');
      final map = <String, dynamic>{
        'fullName': _get(parts, 0),
        'age': _get(parts, 1),
        'bloodGroup': _get(parts, 2),
        'heightCm': _get(parts, 3),
        'weightKg': _get(parts, 4),
        'emergencyNotes': _get(parts, 5),
        'photoPath': _get(parts, 6),
      };
      return ProfileDetails.fromJson(map);
    } catch (_) {
      return const ProfileDetails();
    }
  }

  Future<void> save(ProfileDetails p) async {
    final raw = <String>[
      p.fullName,
      p.age,
      p.bloodGroup,
      p.heightCm,
      p.weightKg,
      p.emergencyNotes,
      p.photoPath ?? '',
    ].join('\u0001');
    await _prefs.setString(_key, raw);
  }

  Future<void> clear() async => _prefs.remove(_key);

  static String _get(List<String> parts, int i) =>
      i < parts.length ? parts[i] : '';
}
