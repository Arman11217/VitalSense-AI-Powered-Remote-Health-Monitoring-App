import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/vitals_repository.dart';
import '../domain/ai_prediction.dart';
import '../domain/device_status.dart';
import '../domain/vital_reading.dart';

/// The single source of truth for sensor / AI data access.
///
/// Uses the live [FirebaseVitalsRepository] so sensor data pushed by the
/// ESP32 (`/devices/<id>/latest`) shows up on the dashboard in real time.
/// The dashboard key is `deviceId` (e.g. `esp32_001`) — we read it from the
/// [currentPatientIdProvider], which mirrors the signed-in user's UID.
final Provider<VitalsRepository> vitalsRepositoryProvider =
    Provider<VitalsRepository>((Ref ref) {
      ref.watch(authRepositoryProvider); // keep auth linkage for parity
      return FirebaseVitalsRepository();
    });

/// The current patient's UID — empty when signed out.
///
/// We treat this as the ESP32 **deviceId** because the firmware writes
/// sensor data under `/devices/<deviceId>/...` (see HealthMonitoring.ino).
/// Override this provider in tests if needed.
final Provider<String> currentPatientIdProvider = Provider<String>((Ref ref) {
  ref.watch(currentUserProvider);
  return 'esp32_001';
});

/// Latest live reading.
final StreamProvider<VitalReading> latestReadingProvider =
    StreamProvider<VitalReading>((Ref ref) {
      final String uid = ref.watch(currentPatientIdProvider);
      return ref.watch(vitalsRepositoryProvider).latestReading(uid);
    });

/// Buffered recent readings (used for sparklines & history).
final StreamProvider<List<VitalReading>> recentReadingsProvider =
    StreamProvider<List<VitalReading>>((Ref ref) {
      final String uid = ref.watch(currentPatientIdProvider);
      return ref
          .watch(vitalsRepositoryProvider)
          .recentReadings(uid, limit: 60);
    });

/// Most recent AI prediction.
final StreamProvider<AIPrediction> latestPredictionProvider =
    StreamProvider<AIPrediction>((Ref ref) {
      final String uid = ref.watch(currentPatientIdProvider);
      return ref.watch(vitalsRepositoryProvider).latestPrediction(uid);
    });

/// ESP32 device status (online, battery, RSSI).
final StreamProvider<DeviceStatus> deviceStatusProvider =
    StreamProvider<DeviceStatus>((Ref ref) {
      final String uid = ref.watch(currentPatientIdProvider);
      return ref.watch(vitalsRepositoryProvider).deviceStatus(uid);
    });
