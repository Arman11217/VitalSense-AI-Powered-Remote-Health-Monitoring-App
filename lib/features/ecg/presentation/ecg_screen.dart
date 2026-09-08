import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/animated_gradient_bg.dart';
import '../../vitals/application/vitals_providers.dart';
import 'widgets/live_ecg_chart.dart';

/// Live ECG screen — Module 5.
///
/// Streams the latest [VitalReading.ecgSample] from the repository
/// (via [latestReadingProvider]) and pushes each sample into a local
/// rolling buffer that feeds [LiveEcgChart]. BPM is computed in real
/// time using a simple R-peak detector on the same buffer.
class EcgScreen extends ConsumerStatefulWidget {
  const EcgScreen({super.key});

  @override
  ConsumerState<EcgScreen> createState() => _EcgScreenState();
}

class _EcgScreenState extends ConsumerState<EcgScreen> {
  final List<double> _samples = <double>[];
  static const int _maxSamples = 600;
  StreamSubscription<double>? _sub;

  // R-peak detector state
  static const double _peakThreshold = 0.8;
  final List<DateTime> _rPeakTimes = <DateTime>[];
  int _bpm = 0;
  Timer? _bpmTimer;

  @override
  void initState() {
    super.initState();
    // Recompute BPM every 2 seconds from the rolling peak window.
    _bpmTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _recomputeBpm();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _bpmTimer?.cancel();
    super.dispose();
  }

  void _ingest(double v) {
    setState(() {
      _samples.add(v);
      if (_samples.length > _maxSamples) {
        _samples.removeAt(0);
      }
      // Detect R-peak: current sample > threshold and previous was below.
      if (_samples.length >= 2) {
        final double prev = _samples[_samples.length - 2];
        if (v > _peakThreshold && prev <= _peakThreshold) {
          _rPeakTimes.add(DateTime.now());
        }
      }
    });
  }

  void _recomputeBpm() {
    // Drop peaks older than 10 seconds.
    final cutoff = DateTime.now().subtract(const Duration(seconds: 10));
    _rPeakTimes.removeWhere((t) => t.isBefore(cutoff));
    if (_rPeakTimes.length < 2) {
      setState(() => _bpm = _bpm); // keep last
      return;
    }
    final double avgIntervalMs =
        _rPeakTimes.length > 1
            ? _rPeakTimes.last.difference(_rPeakTimes.first).inMilliseconds /
                (_rPeakTimes.length - 1)
            : 0;
    if (avgIntervalMs <= 0) return;
    final int bpm = (60000 / avgIntervalMs).round().clamp(30, 220);
    setState(() => _bpm = bpm);
  }

  @override
  Widget build(BuildContext context) {
    // Subscribe to the live stream exactly once.
    ref.listen<AsyncValue<double>>(
      _ecgSampleStreamProvider,
      (_, AsyncValue<double> next) {
        next.whenData(_ingest);
      },
    );

    final reading = ref.watch(latestReadingProvider);

    return AnimatedGradientBg(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Live ECG'),
          actions: <Widget>[
            IconButton(
              tooltip: 'Clear buffer',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => setState(() {
                _samples.clear();
                _rPeakTimes.clear();
                _bpm = 0;
              }),
            ),
          ],
        ),
        body: reading.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('ECG error: $e')),
          data: (_) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _EcgHeader(bpm: _bpm, sampleCount: _samples.length),
                const SizedBox(height: 16),
                LiveEcgChart(samples: _samples),
                const SizedBox(height: 20),
                _StatsRow(samples: _samples, bpm: _bpm),
                const SizedBox(height: 12),
                _Legend(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Convenience provider that extracts just the ECG sample stream
/// from the repository. Lives in this file because it's UI-only.
final _ecgSampleStreamProvider = StreamProvider<double>((Ref ref) {
  final repo = ref.watch(vitalsRepositoryProvider);
  final uid = ref.watch(currentPatientIdProvider);
  return repo.latestReading(uid).map((r) => r.ecgSample);
});

class _EcgHeader extends StatelessWidget {
  const _EcgHeader({required this.bpm, required this.sampleCount});
  final int bpm;
  final int sampleCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E2F38)
            : Colors.white,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: AppColors.hrColor,
              shape: BoxShape.circle,
            ),
          )
              .animate(onPlay: (a) => a.repeat(reverse: true))
              .scale(
                duration: 800.ms,
                begin: const Offset(0.6, 0.6),
                end: const Offset(1.4, 1.4),
              )
              .fade(duration: 800.ms),
          const SizedBox(width: 10),
          const Text(
            'LIVE',
            style: TextStyle(
              color: AppColors.hrColor,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const Spacer(),
          BpmOverlay(bpm: bpm),
          const SizedBox(width: 12),
          Text(
            '$sampleCount samples',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.samples, required this.bpm});
  final List<double> samples;
  final int bpm;

  @override
  Widget build(BuildContext context) {
    if (samples.isEmpty) return const SizedBox.shrink();
    final double minV = samples.reduce(math.min);
    final double maxV = samples.reduce(math.max);
    final double mean =
        samples.reduce((a, b) => a + b) / samples.length;
    return Row(
      children: <Widget>[
        Expanded(child: _StatCard(label: 'Min', value: minV.toStringAsFixed(2))),
        const SizedBox(width: 8),
        Expanded(
            child: _StatCard(label: 'Mean', value: mean.toStringAsFixed(2))),
        const SizedBox(width: 8),
        Expanded(child: _StatCard(label: 'Max', value: maxV.toStringAsFixed(2))),
        const SizedBox(width: 8),
        Expanded(child: _StatCard(label: 'BPM', value: bpm.toString())),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
      child: Column(
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 16,
          height: 2,
          color: AppColors.hrColor,
        ),
        const SizedBox(width: 6),
        Text(
          'ECG Lead II',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}