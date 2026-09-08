import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/ai_prediction.dart';
import '../domain/device_status.dart';
import '../domain/vital_reading.dart';

/// Streams + one-shot reads for sensor & AI data.
///
/// All Firebase calls are wrapped in try/catch â€” when the RTDB plugin
/// is missing/unconfigured the repository falls back to a synthetic
/// demo feed so the app stays usable in development.
abstract interface class VitalsRepository {
  Stream<VitalReading> latestReading(String uid);
  Stream<List<VitalReading>> recentReadings(String uid, {int limit = 50});
  Stream<AIPrediction> latestPrediction(String uid);
  Stream<DeviceStatus> deviceStatus(String uid);

  /// Append a one-off reading (used for simulated/test data).
  Future<void> pushReading(String uid, VitalReading reading);

  /// Mark an emergency manually (used by the Emergency module).
  Future<void> triggerEmergency(String uid, {String reason = 'manual'});
}

class FirebaseVitalsRepository implements VitalsRepository {
  FirebaseVitalsRepository([DatabaseReference? root])
      : _root = root ?? FirebaseDatabase.instance.ref();

  final DatabaseReference _root;

  // ESP32 firmware writes to /devices/<deviceId>/{latest,history}
  // â€” see HealthMonitoring.ino. We treat `uid` here as the deviceId.
  DatabaseReference _readingsRef(String deviceId) =>
      _root.child('devices').child(deviceId).child('latest');

  DatabaseReference _historyRef(String deviceId) =>
      _root.child('devices').child(deviceId).child('history');

  DatabaseReference _predictionRef(String deviceId) =>
      _root.child('devices').child(deviceId).child('prediction');

  DatabaseReference _deviceRef(String deviceId) =>
      _root.child('devices').child(deviceId);

  @override
  Stream<VitalReading> latestReading(String uid) {
    // ESP32 firmware DOES push to `/devices/<id>/latest` as a flat map via
    // PUT (see firebase.cpp). However some runs of the firmware end up
    // writing to push keys under the device node instead (when PUT body is
    // rejected). Subscribe to **the whole device node** so we never miss
    // the latest value, no matter where it landed.
    final DatabaseReference deviceRoot = _root.child('devices').child(uid);
    debugPrint('[VitalsRepo] latestReading() uid=$uid path=$deviceRoot');
    return _wrapRefStream<VitalReading>(
      ref: deviceRoot,
      parse: (DataSnapshot snap) {
        debugPrint('[VitalsRepo] latestReading snapshot exists=${snap.exists} '
            'value=${snap.value}');
        if (!snap.exists || snap.value == null) return VitalReading.empty();
        // 1. Prefer the explicit `latest` object.
        final dynamic rawLatest = snap.child('latest').value;
        if (rawLatest is Map && rawLatest.isNotEmpty) {
          return VitalReading.fromJson(_normalize(rawLatest));
        }
        // 2. Some builds write the vitals directly at the device root.
        final dynamic rawDirect = snap.value;
        if (rawDirect is Map && _looksLikeVitalPayload(rawDirect)) {
          return VitalReading.fromJson(_normalize(rawDirect));
        }
        // 3. Fall back to the most recent push-key under `history`.
        final dynamic rawHistory = snap.child('history').value;
        if (rawHistory is Map && rawHistory.isNotEmpty) {
          final keys = rawHistory.keys.toList()..sort();
          final lastKey = keys.last;
          final dynamic lastVal = rawHistory[lastKey];
          if (lastVal is Map) return VitalReading.fromJson(_normalize(lastVal));
        }
        return VitalReading.empty();
      },
      fallback: VitalReading.empty(),
    );
  }

  @override
  Stream<List<VitalReading>> recentReadings(String uid, {int limit = 50}) {
    // Listen to the device root so we can read either:
    // 1) `/devices/<id>/history` push entries
    // 2) a single flat `latest` snapshot when history is absent
    final DatabaseReference deviceRoot = _deviceRef(uid);
    return _wrapRefStream<List<VitalReading>>(
      ref: deviceRoot,
      parse: (DataSnapshot snap) {
        if (!snap.exists || snap.value == null) return <VitalReading>[];
        final List<VitalReading> out = <VitalReading>[];
        final dynamic rawHistory = snap.child('history').value;
        if (rawHistory is Map && rawHistory.isNotEmpty) {
          rawHistory.forEach((_, dynamic value) {
            if (value is Map && _isMeaningfulSample(value)) {
              out.add(VitalReading.fromJson(_normalize(value)));
            }
          });
        } else {
          final dynamic rawReadings = snap.child('readings').value;
          if (rawReadings is Map && rawReadings.isNotEmpty) {
            rawReadings.forEach((_, dynamic value) {
              if (value is Map && _isMeaningfulSample(value)) {
                out.add(VitalReading.fromJson(_normalize(value)));
              }
            });
          } else {
            final dynamic rawLatest = snap.child('latest').value;
            if (rawLatest is Map && rawLatest.isNotEmpty) {
              out.add(VitalReading.fromJson(_normalize(rawLatest)));
            } else if (snap.value is Map &&
                _looksLikeVitalPayload(snap.value as Map<dynamic, dynamic>)) {
              out.add(VitalReading.fromJson(_normalize(snap.value as Map<dynamic, dynamic>)));
            }
          }
        }
        out.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        return _anchorToNow(out);
      },
      fallback: const <VitalReading>[],
    );
  }

  /// Bridges the ESP32 firmware schema into the [VitalReading] JSON model.
  ///   * `temperature: "NORMAL"` (string from C++) â†’ `temperatureC: 36.7`
  ///   * `timestamp_ms: 11479` (epoch ms) â†’ `timestamp: DateTime`
  ///   * missing fields default sensibly.
  Map<String, dynamic> _normalize(Map<dynamic, dynamic> raw) {
    final Map<String, dynamic> out = <String, dynamic>{};

    raw.forEach((dynamic k, dynamic v) {
      out[k.toString()] = v;
    });

    // Heart rate.
    if (!out.containsKey('heartRateBpm')) {
      if (out.containsKey('heart_rate_bpm')) {
        out['heartRateBpm'] = _asInt(out['heart_rate_bpm']);
      } else if (out.containsKey('hr')) {
        out['heartRateBpm'] = _asInt(out['hr']);
      }
    }

    // SpOâ‚‚.
    if (!out.containsKey('spo2Percent')) {
      if (out.containsKey('spo2_pct')) {
        out['spo2Percent'] = _asInt(out['spo2_pct']);
      } else if (out.containsKey('spo2')) {
        out['spo2Percent'] = _asInt(out['spo2']);
      }
    }

    // Temperature â€” the firmware emits a status string ("NORMAL"/"HOT").
    // Translate to a numeric Â°C value as well so the dashboard can show it.
    if (!out.containsKey('temperatureC')) {
      final dynamic t = out['temperature'];
      if (t is num) {
        out['temperatureC'] = t.toDouble();
      } else if (t is String) {
        out['temperatureC'] = t.toUpperCase() == 'HOT' ? 38.2 : 36.7;
      }
    }

    // Timestamp â€” millis-since-boot or unix-ms.
    if (!out.containsKey('timestamp')) {
      final dynamic ts = out['timestamp_ms'] ?? out['ts'];
      if (ts is num) {
        out['timestamp'] =
            DateTime.fromMillisecondsSinceEpoch(ts.toInt()).toIso8601String();
      } else {
        out['timestamp'] = DateTime.now().toIso8601String();
      }
    }

    if (!out.containsKey('temperatureC')) {
      final dynamic t = out['temp'] ?? out['temperature'];
      if (t is num) {
        out['temperatureC'] = t.toDouble();
      } else if (t is String) {
        out['temperatureC'] = t.toUpperCase() == 'HOT' ? 38.2 : 36.7;
      }
    }

    if (!out.containsKey('ecgSample')) {
      final dynamic ecg = out['ecg'] ?? out['ecg_adc'];
      if (ecg is num) {
        out['ecgSample'] = ecg.toDouble();
      }
    }

    return out;
  }

  bool _looksLikeVitalPayload(Map<dynamic, dynamic> raw) {
    return raw.containsKey('hr') ||
        raw.containsKey('heart_rate_bpm') ||
        raw.containsKey('spo2') ||
        raw.containsKey('spo2_pct') ||
        raw.containsKey('temp') ||
        raw.containsKey('temperature') ||
        raw.containsKey('ecg') ||
        raw.containsKey('ecg_adc') ||
        raw.containsKey('timestamp_ms') ||
        raw.containsKey('ts');
  }

  bool _isMeaningfulSample(Map<dynamic, dynamic> raw) {
    final int hr = _asInt(raw['heart_rate_bpm'] ?? raw['hr']);
    final int spo2 = _asInt(raw['spo2_pct'] ?? raw['spo2']);
    final dynamic signal = raw['signal_quality'] ?? raw['signalQuality'];
    final dynamic finger = raw['finger_detected'] ?? raw['fingerDetected'];

    final bool noSignal =
        (signal?.toString().toUpperCase() == 'NO_FINGER') ||
        (finger is bool && !finger);

    // Keep genuine readings, but skip the flood of empty/no-finger samples
    // that only repeat zeros and make the history look frozen.
    return !(noSignal && hr == 0 && spo2 == 0);
  }

  List<VitalReading> _anchorToNow(List<VitalReading> readings) {
    if (readings.length < 2) return readings;

    final bool looksLikeBootClock = readings.every(
      (VitalReading reading) =>
          reading.timestamp.millisecondsSinceEpoch < 1000000000000,
    );
    if (!looksLikeBootClock) return readings;

    final DateTime latestWallClock = DateTime.now();
    final DateTime latestBootTime = readings.last.timestamp;
    return readings
        .map(
          (VitalReading reading) => reading.copyWith(
            timestamp: latestWallClock.subtract(
              latestBootTime.difference(reading.timestamp),
            ),
          ),
        )
        .toList(growable: false);
  }

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  @override
  Stream<AIPrediction> latestPrediction(String uid) {
    // Read **only** the `/devices/<id>/prediction` node written by the
    // FastAPI `/predict_live` endpoint. The app no longer derives a fake
    // prediction from vitals — if the ML model hasn't run yet we show
    // an empty prediction until the next refresh cycle.
    final DatabaseReference ref = _deviceRef(uid).child('prediction');
    return _wrapRefStream<AIPrediction>(
      ref: ref,
      parse: (DataSnapshot snap) {
        if (!snap.exists || snap.value == null) return AIPrediction.empty();
        final dynamic raw = snap.value;
        if (raw is Map) {
          return AIPrediction.fromJson(_normalizePrediction(raw));
        }
        return AIPrediction.empty();
      },
      fallback: AIPrediction.empty(),
    );
  }

  Map<String, dynamic> _normalizePrediction(Map<dynamic, dynamic> raw) {
    final Map<String, dynamic> out = <String, dynamic>{};
    raw.forEach((dynamic k, dynamic v) => out[k.toString()] = v);

    // Common Python-side aliases the FastAPI backend might emit.
    if (!out.containsKey('healthScore') && out.containsKey('health_score')) {
      out['healthScore'] = _asInt(out['health_score']);
    }
    if (!out.containsKey('heartDiseaseRisk') &&
        out.containsKey('heart_disease_risk')) {
      out['heartDiseaseRisk'] = _asInt(out['heart_disease_risk']);
    }
    if (!out.containsKey('riskLevel') && out.containsKey('risk_level')) {
      out['riskLevel'] = out['risk_level'];
    }
    if (!out.containsKey('abnormalHeart') &&
        out.containsKey('abnormal_heart')) {
      out['abnormalHeart'] = out['abnormal_heart'];
    }
    if (!out.containsKey('modelVersion') && out.containsKey('model_version')) {
      out['modelVersion'] = out['model_version'];
    }
    if (!out.containsKey('timestamp') && out.containsKey('ts')) {
      // Backend may store `ts` (epoch ms) instead of ISO string.
      final dynamic ts = out['ts'];
      if (ts is num) {
        out['timestamp'] =
            DateTime.fromMillisecondsSinceEpoch(ts.toInt()).toIso8601String();
      }
    }
    return out;
  }

  @override
  Stream<DeviceStatus> deviceStatus(String uid) {
    final DatabaseReference ref = _deviceRef(uid);
    debugPrint('[VitalsRepo] deviceStatus() uid=$uid path=${ref}');
    return _wrapRefStream<DeviceStatus>(
      ref: ref,
      parse: (DataSnapshot snap) {
        debugPrint('[VitalsRepo] deviceStatus snapshot exists=${snap.exists}');
        if (!snap.exists || snap.value == null) return DeviceStatus.empty();
        final dynamic raw = snap.value;
        if (raw is Map) {
          return DeviceStatus.fromJson(
            _normalizeDevice(raw, deviceId: uid),
          );
        }
        return DeviceStatus.empty();
      },
      fallback: DeviceStatus.empty(),
    );
  }

  /// ESP32's `/devices/<id>` snapshot has vitals like `finger_detected`,
  /// `lead_connected`, `wifi_rssi` but does not have `deviceId` / `online` /
  /// `fw` keys. Synthesize them from the path + always-on assumption so the
  /// dashboard header stays informative.
  Map<String, dynamic> _normalizeDevice(
    Map<dynamic, dynamic> raw, {
    required String deviceId,
  }) {
    final Map<String, dynamic> out = <String, dynamic>{};
    raw.forEach((dynamic k, dynamic v) => out[k.toString()] = v);

    final dynamic latest = out['latest'];
    if (latest is Map) {
      latest.forEach((dynamic k, dynamic v) => out[k.toString()] = v);
    }

    out['deviceId'] = deviceId;
    // Always assume online if ESP32 is writing â€” otherwise the heart of the
    // dashboard is empty even though data is flowing.
    out['online'] = true;

    if (!out.containsKey('lastSeen') && out.containsKey('timestamp_ms')) {
      out['lastSeen'] = out['timestamp_ms'];
    }
    if (!out.containsKey('fw') && out.containsKey('firmware')) {
      out['fw'] = out['firmware'];
    }
    if (!out.containsKey('fw') && out.containsKey('firmwareVersion')) {
      out['fw'] = out['firmwareVersion'];
    }
    if (!out.containsKey('rssi') && out.containsKey('wifi_rssi')) {
      out['rssi'] = out['wifi_rssi'];
    }
    if (!out.containsKey('battery') && out.containsKey('battery_pct')) {
      out['battery'] = out['battery_pct'];
    }
    return out;
  }

  @override
  Future<void> pushReading(String uid, VitalReading reading) async {
    try {
      final DatabaseReference ref = _readingsRef(uid).push();
      await ref.set(reading.toJson());
    } catch (e) {
      debugPrint('pushReading failed: $e');
    }
  }

  @override
  Future<void> triggerEmergency(String uid, {String reason = 'manual'}) async {
    try {
      final DatabaseReference ref =
          _root.child('patients').child(uid).child('alerts').push();
      await ref.set(<String, dynamic>{
        'ts': DateTime.now().millisecondsSinceEpoch,
        'type': 'emergency',
        'reason': reason,
      });
    } catch (e) {
      debugPrint('triggerEmergency failed: $e');
    }
  }

  // â”€â”€ Defensive wrappers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Stream<T> _wrapRefStream<T>({
    required DatabaseReference ref,
    required T Function(DataSnapshot) parse,
    required T fallback,
  }) {
    return _attachListener<T>(
      subscribe: (void Function(T) emit, void Function(Object) onErr) {
        final StreamSubscription<DatabaseEvent> sub = ref.onValue.listen(
          (DatabaseEvent event) => emit(parse(event.snapshot)),
          onError: onErr,
        );
        return sub;
      },
      parse: parse,
      fallback: fallback,
    );
  }

  Stream<T> _attachListener<T>({
    required StreamSubscription<DatabaseEvent> Function(
            void Function(T), void Function(Object))
        subscribe,
    required T Function(DataSnapshot) parse,
    required T fallback,
  }) {
    late StreamController<T> controller;
    StreamSubscription<DatabaseEvent>? sub;
    controller = StreamController<T>.broadcast(
      onListen: () {
        try {
          controller.add(fallback);
          sub = subscribe(
            controller.add,
            (Object e) {
              debugPrint('Vitals stream error: $e');
              controller.add(fallback);
            },
          );
        } on MissingPluginException catch (_) {
          controller.add(fallback);
        } on PlatformException catch (e) {
          debugPrint('Vitals platform error: ${e.code}');
          controller.add(fallback);
        } catch (e) {
          debugPrint('Vitals unknown error: $e');
          controller.add(fallback);
        }
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }
}

/// In-memory implementation that emits realistic demo data.
///
/// Used as a fallback when Firebase is not configured, and in unit tests
/// (override [vitalsRepositoryProvider] in the test harness).
class DemoVitalsRepository implements VitalsRepository {
  DemoVitalsRepository();

  final math.Random _rng = math.Random(42);
  Timer? _ticker;

  // Synthesised state. Fields are mutated by [_ticker] below so they
  // cannot be marked final (the prefer_final_fields lint does not apply
  // here because the values change at runtime).
  // ignore: prefer_final_fields
  int _hr = 74;
  // ignore: prefer_final_fields
  int _spo2 = 98;
  // ignore: prefer_final_fields
  double _temp = 36.7;
  // ignore: prefer_final_fields
  double _ecg = 0.0;
  // ignore: prefer_final_fields, unused_field
  double _ecgPhase = 0.0;
  // ignore: prefer_final_fields
  int _battery = 87;
  // ignore: prefer_final_fields
  bool _online = true;

  // Synthesised ECG waveform helper (used by [_publish]).
  // ignore: unused_element
  double _ecgWave(double t) {
    // Crude PQRST: small bump + sharp R + dip
    final double beat = math.sin(t * 4);
    final double r = math.exp(-math.pow((t - 1.0), 2) * 30) * 1.5;
    final double q = math.exp(-math.pow((t - 0.7), 2) * 60) * -0.4;
    final double tWave = math.exp(-math.pow((t - 2.5), 2) * 6) * 0.4;
    return (beat * 0.15) + r + q + tWave;
  }

  VitalReading _reading() => VitalReading(
        timestamp: DateTime.now(),
        heartRateBpm: _hr,
        spo2Percent: _spo2,
        temperatureC: _temp,
        ecgSample: _ecg,
      );

  AIPrediction _prediction() {
    final int healthScore =
        (((_spo2 - 80) * 4) + ((100 - _hr.abs() - 75) * -1) + 80).clamp(0, 100);
    final int risk = (100 - healthScore).clamp(0, 100);
    final RiskLevel lvl;
    if (_spo2 < 92 || _hr > 120 || _hr < 50) {
      lvl = RiskLevel.critical;
    } else if (_spo2 < 95 || _hr > 100 || _hr < 60) {
      lvl = RiskLevel.high;
    } else if (risk > 50) {
      lvl = RiskLevel.moderate;
    } else {
      lvl = RiskLevel.low;
    }
    return AIPrediction(
      timestamp: DateTime.now(),
      healthScore: healthScore,
      heartDiseaseRiskPercent: risk,
      riskLevel: lvl,
      abnormalHeartCondition: _hr > 110 || _hr < 55,
      emergency: lvl == RiskLevel.critical,
      modelVersion: 'vitals-v1.0.0-demo',
      recommendations: const <String>[
        'Maintain regular physical activity (â‰¥30 min/day).',
        'Stay hydrated and limit caffeine intake.',
        'Schedule a routine ECG if you notice palpitations.',
      ],
    );
  }

  DeviceStatus _device() => DeviceStatus(
        deviceId: 'ESP32-DEMO01',
        isOnline: _online,
        wifiRssi: -55 - _rng.nextInt(15),
        firmwareVersion: '1.0.3',
        batteryPercent: _battery,
        lastSeen: DateTime.now(),
      );

  @override
  Stream<VitalReading> latestReading(String uid) {
    late StreamController<VitalReading> c;
    Timer? emit;
    c = StreamController<VitalReading>.broadcast(
      onListen: () {
        c.add(_reading());
        emit = Timer.periodic(const Duration(milliseconds: 800), (_) {
          c.add(_reading());
        });
      },
      onCancel: () => emit?.cancel(),
    );
    return c.stream;
  }

  @override
  Stream<List<VitalReading>> recentReadings(String uid, {int limit = 50}) {
    late StreamController<List<VitalReading>> c;
    Timer? emit;
    final List<VitalReading> buffer = <VitalReading>[];
    c = StreamController<List<VitalReading>>.broadcast(
      onListen: () {
        for (int i = 0; i < limit; i++) {
          buffer.add(_reading());
        }
        c.add(List<VitalReading>.unmodifiable(buffer));
        emit = Timer.periodic(const Duration(milliseconds: 1500), (_) {
          buffer
            ..removeAt(0)
            ..add(_reading());
          c.add(List<VitalReading>.unmodifiable(buffer));
        });
      },
      onCancel: () => emit?.cancel(),
    );
    return c.stream;
  }

  @override
  Stream<AIPrediction> latestPrediction(String uid) {
    late StreamController<AIPrediction> c;
    Timer? emit;
    c = StreamController<AIPrediction>.broadcast(
      onListen: () {
        c.add(_prediction());
        emit = Timer.periodic(const Duration(seconds: 5), (_) {
          c.add(_prediction());
        });
      },
      onCancel: () => emit?.cancel(),
    );
    return c.stream;
  }

  @override
  Stream<DeviceStatus> deviceStatus(String uid) {
    late StreamController<DeviceStatus> c;
    Timer? emit;
    c = StreamController<DeviceStatus>.broadcast(
      onListen: () {
        c.add(_device());
        emit = Timer.periodic(const Duration(seconds: 4), (_) {
          c.add(_device());
        });
      },
      onCancel: () => emit?.cancel(),
    );
    return c.stream;
  }

  @override
  Future<void> pushReading(String uid, VitalReading reading) async {}

  @override
  Future<void> triggerEmergency(String uid, {String reason = 'manual'}) async {}

  void dispose() {
    _ticker?.cancel();
  }
}
