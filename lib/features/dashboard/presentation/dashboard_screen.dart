import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/animated_gradient_bg.dart';
import '../../auth/application/auth_providers.dart';
import '../../vitals/application/vitals_providers.dart';
import '../../vitals/domain/ai_prediction.dart';
import '../../vitals/domain/vital_reading.dart';
import 'widgets/ai_risk_card.dart';
import 'widgets/device_status_header.dart';
import 'widgets/health_score_ring.dart';
import 'widgets/recent_activity_list.dart';
import 'widgets/vital_card.dart';

/// Top-level dashboard — the default tab inside HomeShell.
///
/// Watches 4 Riverpod streams and composes them into:
///   1. Greeting + last-updated
///   2. Device status header
///   3. Health score ring + AI risk card (side-by-side on wide layouts)
///   4. Vitals grid (HR / SpO₂ / Temp / ECG placeholder)
///   5. Recent activity sparklines
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final reading = ref.watch(latestReadingProvider);
    final readings = ref.watch(recentReadingsProvider);
    final prediction = ref.watch(latestPredictionProvider);
    final device = ref.watch(deviceStatusProvider);

    final String firstName = (user?.displayName ?? 'there').split(' ').first;

    return AnimatedGradientBg(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(latestReadingProvider);
              ref.invalidate(recentReadingsProvider);
              ref.invalidate(latestPredictionProvider);
              ref.invalidate(deviceStatusProvider);
              await Future<void>.delayed(const Duration(milliseconds: 600));
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              children: <Widget>[
                _Greeting(name: firstName, email: user?.email),
                const SizedBox(height: 16),
                device.when(
                  data: (d) => DeviceStatusHeader(device: d),
                  loading: () => const _HeaderSkeleton(),
                  error: (_, _) => DeviceStatusHeader(
                    device: device.valueOrNull ?? _placeholderDevice(),
                  ),
                ),
                const SizedBox(height: 20),
                _HealthSection(
                  reading: reading,
                  prediction: prediction,
                ),
                const SizedBox(height: 20),
                _VitalsGrid(reading: reading, prediction: prediction),
                const SizedBox(height: 24),
                _SectionHeader(
                  title: 'Recent Activity',
                  subtitle: readings.maybeWhen(
                    data: (r) => r.isEmpty
                        ? 'No history yet'
                        : '${r.length} samples · live',
                    orElse: () => 'Loading…',
                  ),
                ),
                const SizedBox(height: 12),
                readings.when(
                  data: (r) => RecentActivityList(readings: r),
                  loading: () => const _ActivitySkeleton(),
                  error: (_, _) => RecentActivityList(
                    readings: const <VitalReading>[],
                  ),
                ),
                const SizedBox(height: 16),
                _LastUpdated(
                  ts: reading.maybeWhen(
                    data: (r) => r.timestamp,
                    orElse: () => null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static dynamic _placeholderDevice() => null;
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name, required this.email});
  final String name;
  final String? email;

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          _greeting(),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                letterSpacing: 0.6,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        if (email != null && email!.isNotEmpty) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            email!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ],
    );
  }
}

class _HealthSection extends StatelessWidget {
  const _HealthSection({required this.reading, required this.prediction});
  final AsyncValue<dynamic> reading;
  final AsyncValue<dynamic> prediction;

  @override
  Widget build(BuildContext context) {
    return prediction.when(
      data: (p) => LayoutBuilder(
        builder: (context, c) {
          final bool wide = c.maxWidth >= 360;
          final Widget ring = HealthScoreRing(score: p.healthScore);
          final Widget card = AIRiskCard(prediction: p);
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                ring,
                const SizedBox(width: 16),
                Expanded(child: card),
              ],
            );
          }
          return Column(
            children: <Widget>[
              Center(child: ring),
              const SizedBox(height: 16),
              card,
            ],
          );
        },
      ),
      loading: () => const _HealthSkeleton(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _VitalsGrid extends StatelessWidget {
  const _VitalsGrid({required this.reading, required this.prediction});
  final AsyncValue<dynamic> reading;
  final AsyncValue<AIPrediction> prediction;

  ({String? label, Color? color}) _hrBadge() {
    final AIPrediction? p = prediction.valueOrNull;
    if (p == null || p.hrSource == HrSource.unknown) {
      return (label: null, color: null);
    }
    switch (p.hrSource) {
      case HrSource.sensor:
        return (label: 'Sensor', color: AppColors.healthy);
      case HrSource.spo2PpgEstimated:
        return (label: 'Estimated', color: AppColors.warning);
      case HrSource.defaults:
        return (label: 'Default', color: const Color(0xFF8E44AD));
      case HrSource.noFinger:
        return (label: 'No finger', color: AppColors.offline);
      case HrSource.unknown:
        return (label: null, color: null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return reading.when(
      data: (r) {
        final int rawHr = r.heartRateBpm ?? 0;
        final int spo2 = r.spo2Percent ?? 0;
        final double temp = (r.temperatureC ?? 0).toDouble();
        final hrBadge = _hrBadge();

        // Prefer the AI-resolved HR when the sensor isn't sending one.
        // Sensor HR (rawHr > 0) wins; otherwise fall back to the value
        // the backend actually used for the prediction.
        final AIPrediction? pred = prediction.valueOrNull;
        final int displayHr = rawHr > 0
            ? rawHr
            : (pred?.hrResolved ?? 0);
        final String hrValue = displayHr > 0 ? displayHr.toString() : '—';
        final Color hrColor = AppColors.vitalsColor(
          heartRate: displayHr > 0 ? displayHr : 75,
          spo2: 100,
        );

        return Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: VitalCard(
                    icon: Icons.favorite_rounded,
                    label: 'Heart Rate',
                    value: hrValue,
                    unit: 'bpm',
                    statusColor: hrColor,
                    sourceLabel: hrBadge.label,
                    sourceColor: hrBadge.color,
                    statusLabel: rawHr > 0
                        ? 'Live sensor'
                        : (displayHr > 0 ? 'AI-resolved' : 'No data'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: VitalCard(
                    icon: Icons.water_drop_rounded,
                    label: 'SpO₂',
                    value: spo2 > 0 ? spo2.toString() : '—',
                    unit: '%',
                    statusColor: AppColors.vitalsColor(
                      heartRate: 75,
                      spo2: spo2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: VitalCard(
                    icon: Icons.thermostat_rounded,
                    label: 'Temperature',
                    value: temp > 0 ? temp.toStringAsFixed(1) : '—',
                    unit: '°C',
                    statusColor: temp >= 36 && temp <= 37.5
                        ? AppColors.healthy
                        : (temp > 0 ? AppColors.warning : AppColors.offline),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: VitalCard(
                    icon: Icons.monitor_heart_rounded,
                    label: 'ECG',
                    value: rawHr > 0 ? 'Live' : '—',
                    unit: '',
                    statusColor: rawHr > 0 ? AppColors.healthy : AppColors.offline,
                    statusLabel: rawHr > 0 ? 'Streaming' : 'Offline',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Open the ECG tab for live waveform.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
      loading: () => const _VitalsSkeleton(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _LastUpdated extends StatelessWidget {
  const _LastUpdated({required this.ts});
  final DateTime? ts;

  @override
  Widget build(BuildContext context) {
    if (ts == null) return const SizedBox.shrink();
    final fmt = DateFormat('MMM d · HH:mm:ss').format(ts!);
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(Icons.access_time_rounded, size: 14, color: scheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          'Last reading at $fmt',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _HeaderSkeleton extends StatelessWidget {
  const _HeaderSkeleton();
  @override
  Widget build(BuildContext context) => const _Pulse(height: 72);
}

class _VitalsSkeleton extends StatelessWidget {
  const _VitalsSkeleton();
  @override
  Widget build(BuildContext context) => Column(
        children: <Widget>[
          Row(children: const <Widget>[
            Expanded(child: _Pulse(height: 150)),
            SizedBox(width: 12),
            Expanded(child: _Pulse(height: 150)),
          ]),
          const SizedBox(height: 12),
          Row(children: const <Widget>[
            Expanded(child: _Pulse(height: 150)),
            SizedBox(width: 12),
            Expanded(child: _Pulse(height: 150)),
          ]),
        ],
      );
}

class _ActivitySkeleton extends StatelessWidget {
  const _ActivitySkeleton();
  @override
  Widget build(BuildContext context) => Column(
        children: const <Widget>[
          _Pulse(height: 64),
          SizedBox(height: 10),
          _Pulse(height: 64),
          SizedBox(height: 10),
          _Pulse(height: 64),
        ],
      );
}

class _HealthSkeleton extends StatelessWidget {
  const _HealthSkeleton();
  @override
  Widget build(BuildContext context) => Row(
        children: const <Widget>[
          _Pulse(height: 140, width: 140),
          SizedBox(width: 16),
          Expanded(child: _Pulse(height: 140)),
        ],
      );
}

class _Pulse extends StatelessWidget {
  const _Pulse({required this.height, this.width});
  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
      ),
    );
  }
}