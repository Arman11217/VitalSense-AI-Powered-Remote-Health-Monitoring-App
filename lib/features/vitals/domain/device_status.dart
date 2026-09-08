import 'package:equatable/equatable.dart';

/// Live status of the ESP32 sensor rig.
class DeviceStatus extends Equatable {
  const DeviceStatus({
    required this.deviceId,
    required this.isOnline,
    required this.wifiRssi,
    required this.firmwareVersion,
    required this.batteryPercent,
    required this.lastSeen,
  });

  final String deviceId;
  final bool isOnline;
  final int wifiRssi;
  final String firmwareVersion;
  final int batteryPercent;
  final DateTime lastSeen;

  factory DeviceStatus.fromJson(Map<dynamic, dynamic> json) {
    // Accept either our own schema (`rssi`, `fw`, `battery`) or the ESP32
    // firmware's snake_case (`wifi_rssi`, `firmware`, etc.).
    final num? rssi = (json['rssi'] as num?) ?? (json['wifi_rssi'] as num?);
    final String? fw =
        (json['fw'] as String?) ?? (json['firmware'] as String?);
    final num? batt = (json['battery'] as num?) ?? (json['battery_pct'] as num?);
    final String? id = (json['deviceId'] as String?) ??
        (json['device_id'] as String?) ??
        (json['id'] as String?);

    return DeviceStatus(
      deviceId: id ?? 'ESP32-UNKNOWN',
      isOnline: (json['online'] as bool?) ??
          (json['isOnline'] as bool?) ??
          true,
      wifiRssi: rssi?.toInt() ?? -100,
      firmwareVersion: fw ?? '—',
      batteryPercent: batt?.toInt() ?? 0,
      lastSeen: DateTime.fromMillisecondsSinceEpoch(
        (json['lastSeen'] as num?)?.toInt() ??
            (json['last_seen_ms'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'deviceId': deviceId,
        'online': isOnline,
        'rssi': wifiRssi,
        'fw': firmwareVersion,
        'battery': batteryPercent,
        'lastSeen': lastSeen.millisecondsSinceEpoch,
      };

  factory DeviceStatus.empty() => DeviceStatus(
        deviceId: 'ESP32-—',
        isOnline: false,
        wifiRssi: 0,
        firmwareVersion: '—',
        batteryPercent: 0,
        lastSeen: DateTime.fromMillisecondsSinceEpoch(0),
      );

  @override
  List<Object?> get props => <Object?>[
        deviceId,
        isOnline,
        wifiRssi,
        firmwareVersion,
        batteryPercent,
        lastSeen,
      ];
}
