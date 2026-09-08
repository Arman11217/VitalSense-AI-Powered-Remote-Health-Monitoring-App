import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../vitals/application/vitals_providers.dart';
import '../data/emergency_repository.dart';
import '../domain/emergency_models.dart';

/// Singleton repository — swap for a Firebase-backed implementation later.
final Provider<EmergencyRepository> emergencyRepositoryProvider =
    Provider<EmergencyRepository>((Ref ref) {
      // TODO(emergency): depend on auth state here when this repo reads/writes
      // per-user data (e.g. contacts stored under uid/emergency).
      return InMemoryEmergencyRepository();
    });

/// All emergency contacts for the signed-in patient.
final FutureProvider<List<EmergencyContact>> emergencyContactsProvider =
    FutureProvider<List<EmergencyContact>>((Ref ref) async {
      final uid = ref.watch(currentPatientIdProvider);
      return ref.watch(emergencyRepositoryProvider).getContacts(uid);
    });

/// Latest emergency event (if any).
final StreamProvider<EmergencyEvent> latestEmergencyEventProvider =
    StreamProvider<EmergencyEvent>((Ref ref) {
      final uid = ref.watch(currentPatientIdProvider);
      return ref.watch(emergencyRepositoryProvider).latestEvent(uid);
    });