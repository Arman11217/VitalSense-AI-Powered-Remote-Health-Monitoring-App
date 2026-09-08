import 'package:equatable/equatable.dart';

/// AI model output attached to a [VitalReading].
///
/// Stored under `/devices/{deviceId}/prediction` (FastAPI writes here).
class AIPrediction extends Equatable {
  const AIPrediction({
    required this.timestamp,
    required this.healthScore,
    required this.heartDiseaseRiskPercent,
    required this.riskLevel,
    required this.abnormalHeartCondition,
    required this.emergency,
    required this.modelVersion,
    required this.recommendations,
    this.hrResolved = 0,
    this.hrSource = HrSource.unknown,
    this.hrConfidence = 0.0,
  });

  /// Time the prediction was generated.
  final DateTime timestamp;

  /// 0-100 score: higher = healthier.
  final int healthScore;

  /// Estimated probability of heart disease, 0-100.
  final int heartDiseaseRiskPercent;

  /// Coarse-grained bucket for quick UI rendering.
  final RiskLevel riskLevel;

  /// True if the ECG suggests an arrhythmia / abnormal pattern.
  final bool abnormalHeartCondition;

  /// True if the patient should be considered in immediate danger.
  final bool emergency;

  /// AI model version string (e.g. "vitals-v1.2.0").
  final String modelVersion;

  /// Human-friendly suggestions returned by the model.
  final List<String> recommendations;

  /// Heart-rate value the model actually saw (after backend resolution).
  /// 0 means "no finger / unknown".
  final int hrResolved;

  /// Where the resolved heart-rate came from.
  final HrSource hrSource;

  /// 0.0-1.0 — backend's confidence in the resolved HR.
  /// 1.0 when source == [HrSource.sensor], lower for estimated / default.
  final double hrConfidence;

  factory AIPrediction.fromJson(Map<dynamic, dynamic> json) {
    final dynamic rawHealthScore = json['healthScore'] ?? json['health_score'];
    final dynamic rawRisk = json['heartDiseaseRisk'] ?? json['heart_disease_risk'];
    final dynamic rawRiskLevel = json['riskLevel'] ?? json['risk_level'];
    final dynamic rawAbnormal = json['abnormalHeart'] ?? json['abnormal_heart'];
    final dynamic rawEmergency = json['emergency'];
    final dynamic rawModelVersion = json['modelVersion'] ?? json['model_version'];
    final dynamic rawRecommendations = json['recommendations'];

    return AIPrediction(
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (json['ts'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      ),
      healthScore: (rawHealthScore as num?)?.toInt() ??
        int.tryParse(rawHealthScore?.toString() ?? '') ??
        0,
      heartDiseaseRiskPercent: (rawRisk as num?)?.toInt() ??
        int.tryParse(rawRisk?.toString() ?? '') ??
        0,
      riskLevel: _riskFrom((rawRiskLevel as String?) ?? 'low'),
      abnormalHeartCondition: (rawAbnormal as bool?) ?? false,
      emergency: (rawEmergency as bool?) ?? false,
      modelVersion: (rawModelVersion as String?) ?? 'v1.0.0',
      recommendations: (rawRecommendations as List?)
              ?.map((dynamic e) => e.toString())
              .toList() ??
          const <String>[],
      hrResolved: (json['hrResolved'] as num?)?.toInt() ??
          (json['hr_resolved'] as num?)?.toInt() ??
          0,
      hrSource: _hrSourceFrom(json['hrSource'] ?? json['hr_source']),
      hrConfidence: (json['hrConfidence'] as num?)?.toDouble() ??
          (json['hr_confidence'] as num?)?.toDouble() ??
          _defaultConfidenceFor(_hrSourceFrom(json['hrSource'] ?? json['hr_source'])),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'ts': timestamp.millisecondsSinceEpoch,
        'healthScore': healthScore,
        'heartDiseaseRisk': heartDiseaseRiskPercent,
        'riskLevel': riskLevel.name,
        'abnormalHeart': abnormalHeartCondition,
        'emergency': emergency,
        'modelVersion': modelVersion,
        'recommendations': recommendations,
        'hrResolved': hrResolved,
        'hrSource': hrSource.name,
        'hrConfidence': hrConfidence,
      };

  factory AIPrediction.empty() => AIPrediction(
        timestamp: DateTime.fromMillisecondsSinceEpoch(0),
        healthScore: 0,
        heartDiseaseRiskPercent: 0,
        riskLevel: RiskLevel.unknown,
        abnormalHeartCondition: false,
        emergency: false,
        modelVersion: '—',
        recommendations: const <String>[],
      );

  @override
  List<Object?> get props => <Object?>[
        timestamp,
        healthScore,
        heartDiseaseRiskPercent,
        riskLevel,
        abnormalHeartCondition,
        emergency,
        modelVersion,
        recommendations,
        hrResolved,
        hrSource,
        hrConfidence,
      ];
}

enum RiskLevel { low, moderate, high, critical, unknown }

RiskLevel _riskFrom(String raw) {
  switch (raw.toLowerCase()) {
    case 'low':
      return RiskLevel.low;
    case 'moderate':
    case 'medium':
      return RiskLevel.moderate;
    case 'high':
      return RiskLevel.high;
    case 'critical':
      return RiskLevel.critical;
    default:
      return RiskLevel.unknown;
  }
}

/// Where the resolved heart-rate in [AIPrediction.hrResolved] came from.
///
/// Backend (FastAPI) emits these in `hrSource`; older payloads (without the
/// field) fall back to [HrSource.unknown].
enum HrSource {
  /// Real MAX30102 sensor HR, in the physiological range [40, 180].
  sensor,

  /// SpO₂ + IR/Red PPG-ratio based estimate (no usable sensor HR).
  spo2PpgEstimated,

  /// Fallback constant when finger is present but signal is too weak.
  defaults,

  /// No finger on the sensor — HR is meaningless (kept as 0).
  noFinger,

  /// Pre-resolver schema (older backend / demo data).
  unknown,
}

HrSource _hrSourceFrom(dynamic raw) {
  final String s = (raw ?? '').toString().toLowerCase();
  switch (s) {
    case 'sensor':
      return HrSource.sensor;
    case 'spo2_ppg_estimated':
    case 'estimated':
      return HrSource.spo2PpgEstimated;
    case 'default':
    case 'fallback':
      return HrSource.defaults;
    case 'no_finger':
    case 'nofinger':
      return HrSource.noFinger;
    default:
      return HrSource.unknown;
  }
}

double _defaultConfidenceFor(HrSource src) {
  switch (src) {
    case HrSource.sensor:
      return 1.0;
    case HrSource.spo2PpgEstimated:
      return 0.6;
    case HrSource.defaults:
      return 0.3;
    case HrSource.noFinger:
      return 0.0;
    case HrSource.unknown:
      return 0.0;
  }
}
