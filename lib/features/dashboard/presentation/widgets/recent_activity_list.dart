import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../vitals/domain/vital_reading.dart';
import 'sparkline_chart.dart';

/// Three rows of recent activity (HR, SpO₂, Temp) with sparkline trends.
class RecentActivityList extends StatelessWidget {
  const RecentActivityList({super.key, required this.readings});

  final List<VitalReading> readings;

  List<double> _hrSeries() =>
      readings.map((VitalReading r) => r.heartRateBpm.toDouble()).toList();
  List<double> _spo2Series() =>
      readings.map((VitalReading r) => r.spo2Percent.toDouble()).toList();
  List<double> _tempSeries() =>
      readings.map((VitalReading r) => r.temperatureC).toList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _ActivityTile(
          title: 'Heart Rate',
          unit: 'bpm',
          current: readings.isNotEmpty
              ? readings.last.heartRateBpm.toString()
              : '—',
          values: _hrSeries(),
          color: AppColors.hrColor,
          icon: Icons.favorite_rounded,
        ),
        const SizedBox(height: 10),
        _ActivityTile(
          title: 'Blood Oxygen',
          unit: '%',
          current: readings.isNotEmpty
              ? readings.last.spo2Percent.toString()
              : '—',
          values: _spo2Series(),
          color: AppColors.spo2Color,
          icon: Icons.water_drop_rounded,
        ),
        const SizedBox(height: 10),
        _ActivityTile(
          title: 'Temperature',
          unit: '°C',
          current: readings.isNotEmpty
              ? readings.last.temperatureC.toStringAsFixed(1)
              : '—',
          values: _tempSeries(),
          color: AppColors.tempColor,
          icon: Icons.thermostat_rounded,
        ),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.title,
    required this.unit,
    required this.current,
    required this.values,
    required this.color,
    required this.icon,
  });

  final String title;
  final String unit;
  final String current;
  final List<double> values;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E2F38)
            : Colors.white,
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    Text(
                      current,
                      style:
                          Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      unit,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            width: 90,
            child: SparklineChart(values: values, color: color),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideX(begin: 0.05, end: 0);
  }
}

/// Helper to format timestamps for "last updated" labels.
String formatTime(DateTime dt) {
  if (dt.millisecondsSinceEpoch == 0) return '—';
  return DateFormat('HH:mm:ss').format(dt);
}