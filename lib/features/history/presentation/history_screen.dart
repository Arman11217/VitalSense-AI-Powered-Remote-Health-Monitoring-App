import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/animated_gradient_bg.dart';
import '../../vitals/application/vitals_providers.dart';
import '../../vitals/domain/vital_reading.dart';
import '../../dashboard/presentation/widgets/sparkline_chart.dart';

/// Health History (Module 7) — past readings with filters and sparklines.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

enum _Filter { all, hr, spo2, temp }

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final readings = ref.watch(recentReadingsProvider);
    return AnimatedGradientBg(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Health History'),
        ),
        body: readings.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (data) {
            if (data.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No history yet — keep your device connected.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            final List<VitalReading> sorted = List<VitalReading>.from(data)
              ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
            return Column(
              children: <Widget>[
                _FilterBar(
                  current: _filter,
                  onChanged: (f) => setState(() => _filter = f),
                ),
                _TrendStrip(readings: data),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: sorted.length,
                    itemBuilder: (BuildContext c, int i) {
                      return _ReadingRow(
                        key: ValueKey<String>(
                          '${sorted[i].timestamp.millisecondsSinceEpoch}-${sorted[i].heartRateBpm}-${sorted[i].spo2Percent}-${sorted[i].temperatureC.toStringAsFixed(1)}',
                        ),
                        reading: sorted[i],
                        filter: _filter,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.current, required this.onChanged});
  final _Filter current;
  final ValueChanged<_Filter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: <Widget>[
          for (final _Filter f in _Filter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(_label(f)),
                selected: current == f,
                onSelected: (_) => onChanged(f),
              ),
            ),
        ],
      ),
    );
  }

  String _label(_Filter f) {
    switch (f) {
      case _Filter.all:
        return 'All';
      case _Filter.hr:
        return 'Heart Rate';
      case _Filter.spo2:
        return 'SpO₂';
      case _Filter.temp:
        return 'Temp';
    }
  }
}

class _TrendStrip extends StatelessWidget {
  const _TrendStrip({required this.readings});
  final List<VitalReading> readings;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: <Widget>[
          _TrendCard(
            title: 'HR avg',
            value: _avg(readings.map((r) => r.heartRateBpm.toDouble())),
            unit: 'bpm',
            color: AppColors.hrColor,
            values:
                readings.map((r) => r.heartRateBpm.toDouble()).toList(),
          ),
          const SizedBox(width: 8),
          _TrendCard(
            title: 'SpO₂ avg',
            value: _avg(readings.map((r) => r.spo2Percent.toDouble())),
            unit: '%',
            color: AppColors.spo2Color,
            values: readings.map((r) => r.spo2Percent.toDouble()).toList(),
          ),
          const SizedBox(width: 8),
          _TrendCard(
            title: 'Temp avg',
            value: _avg(readings.map((r) => r.temperatureC)),
            unit: '°C',
            color: AppColors.tempColor,
            values: readings.map((r) => r.temperatureC).toList(),
          ),
        ],
      ),
    );
  }

  double _avg(Iterable<double> xs) {
    final list = xs.toList();
    if (list.isEmpty) return 0;
    return list.reduce((a, b) => a + b) / list.length;
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.color,
    required this.values,
  });
  final String title;
  final double value;
  final String unit;
  final Color color;
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                value.toStringAsFixed(1),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          Expanded(child: SparklineChart(values: values, color: color)),
        ],
      ),
    );
  }
}

class _ReadingRow extends StatelessWidget {
  const _ReadingRow({required this.reading, required this.filter, super.key,});
  final VitalReading reading;
  final _Filter filter;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final String ts = DateFormat('MMM d  HH:mm:ss').format(reading.timestamp);
    final List<_Metric> metrics = <_Metric>[
      _Metric('HR', '${reading.heartRateBpm}', 'bpm', AppColors.hrColor),
      _Metric('SpO₂', '${reading.spo2Percent}', '%', AppColors.spo2Color),
      _Metric('Temp', reading.temperatureC.toStringAsFixed(1), '°C',
          AppColors.tempColor),
    ];

    final List<_Metric> visible = switch (filter) {
      _Filter.all => metrics,
      _Filter.hr => <_Metric>[metrics[0]],
      _Filter.spo2 => <_Metric>[metrics[1]],
      _Filter.temp => <_Metric>[metrics[2]],
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E2F38)
            : Colors.white,
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 8,
            height: 36,
            decoration: BoxDecoration(
              color: reading.status == VitalStatus.critical
                  ? AppColors.critical
                  : reading.status == VitalStatus.warning
                      ? AppColors.warning
                      : AppColors.healthy,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              ts,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          ...visible.map((m) => Expanded(
                flex: 2,
                child: _MetricChip(metric: m),
              )),
        ],
      ),
    );
  }
}

class _Metric {
  const _Metric(this.label, this.value, this.unit, this.color);
  final String label;
  final String value;
  final String unit;
  final Color color;
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.metric});
  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          metric.label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: metric.color,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            Text(
              metric.value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(width: 2),
            Text(
              metric.unit,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ],
    );
  }
}
