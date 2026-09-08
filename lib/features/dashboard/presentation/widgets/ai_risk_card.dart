import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../vitals/domain/ai_prediction.dart';

/// AI risk summary card — risk level, percentage + first recommendation.
class AIRiskCard extends StatelessWidget {
  const AIRiskCard({super.key, required this.prediction});

  final AIPrediction prediction;

  Color get _riskColor {
    switch (prediction.riskLevel) {
      case RiskLevel.low:
        return AppColors.healthy;
      case RiskLevel.moderate:
        return AppColors.warning;
      case RiskLevel.high:
      case RiskLevel.critical:
        return AppColors.critical;
      case RiskLevel.unknown:
        return AppColors.offline;
    }
  }

  String get _riskLabel {
    switch (prediction.riskLevel) {
      case RiskLevel.low:
        return 'Low Risk';
      case RiskLevel.moderate:
        return 'Moderate Risk';
      case RiskLevel.high:
        return 'High Risk';
      case RiskLevel.critical:
        return 'Critical';
      case RiskLevel.unknown:
        return 'Analyzing…';
    }
  }

  IconData get _icon {
    switch (prediction.riskLevel) {
      case RiskLevel.low:
        return Icons.check_circle_rounded;
      case RiskLevel.moderate:
        return Icons.info_rounded;
      case RiskLevel.high:
      case RiskLevel.critical:
        return Icons.warning_amber_rounded;
      case RiskLevel.unknown:
        return Icons.hourglass_top_rounded;
    }
  }

  static String _hrSourceLabel(HrSource src) {
    switch (src) {
      case HrSource.sensor:
        return 'sensor';
      case HrSource.spo2PpgEstimated:
        return 'estimated from PPG';
      case HrSource.defaults:
        return 'fallback default';
      case HrSource.noFinger:
        return 'no finger';
      case HrSource.unknown:
        return 'unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            _riskColor.withValues(alpha: 0.20),
            _riskColor.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(color: _riskColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _riskColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon, color: _riskColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'AI Heart Risk',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    Text(
                      _riskLabel,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: _riskColor,
                          ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    '${prediction.heartDiseaseRiskPercent}%',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: _riskColor,
                        ),
                  ),
                  Text(
                    'risk',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ],
          ),
          if (prediction.hrResolved > 0 &&
              prediction.hrSource != HrSource.unknown &&
              prediction.hrSource != HrSource.sensor) ...<Widget>[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  prediction.hrSource == HrSource.spo2PpgEstimated
                      ? Icons.auto_graph_rounded
                      : Icons.assistant_photo_rounded,
                  size: 14,
                  color: prediction.hrSource == HrSource.spo2PpgEstimated
                      ? AppColors.warning
                      : const Color(0xFF8E44AD),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Model HR: ${prediction.hrResolved} bpm · ${_hrSourceLabel(prediction.hrSource)}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
          ],
          if (prediction.abnormalHeartCondition) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.critical.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.bolt_rounded,
                      size: 14, color: AppColors.critical),
                  const SizedBox(width: 4),
                  Text(
                    'Abnormal heart pattern detected',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.critical,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ],
          if (prediction.recommendations.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              prediction.recommendations.first,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.8),
                  ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }
}