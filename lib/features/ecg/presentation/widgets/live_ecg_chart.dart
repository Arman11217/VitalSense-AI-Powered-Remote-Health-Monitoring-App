import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_colors.dart';

/// Scrolling live ECG waveform rendered with [LineChart].
///
/// Uses a sliding window so the chart looks like a real ECG strip
/// moving left-to-right. The styling mimics a bedside cardiac monitor:
/// dark teal background, neon-green trace, faint green grid.
///
/// [yMin] / [yMax] allow the parent to lock the vertical scale so that
/// small QRS spikes remain visible even when the raw ADC spans the
/// entire 0–4095 range.
class LiveEcgChart extends StatelessWidget {
  const LiveEcgChart({
    super.key,
    required this.samples,
    this.height = 240,
    this.windowSize = 200,
    this.yMin,
    this.yMax,
  });

  /// Most recent samples (oldest → newest). The widget will keep the
  /// newest [windowSize] of them visible at any time.
  final List<double> samples;
  final double height;
  final int windowSize;

  /// Optional fixed vertical axis. When null the chart auto-scales
  /// around the median ± a comfortable window so small PQRST spikes
  /// don't get squashed against the bottom of the canvas.
  final double? yMin;
  final double? yMax;

  @override
  Widget build(BuildContext context) {
    final List<double> visible = samples.length > windowSize
        ? samples.sublist(samples.length - windowSize)
        : samples;

    // Background — dark "monitor" colour regardless of theme.
    const Color traceBg = Color(0xFF0B1620);
    const Color traceGrid = Color(0xFF143040);
    final Color traceLine = AppColors.ecgLine;

    if (visible.length < 2) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: traceBg,
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.4),
          ),
        ),
        child: const Center(
          child: Text(
            'Waiting for ECG stream…',
            style: TextStyle(
              color: Color(0xFF6FE3A1),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
      );
    }

    // Build spots with index on x-axis. Oldest at x=0, newest at x=visible.length-1.
    final List<FlSpot> spots = <FlSpot>[
      for (int i = 0; i < visible.length; i++)
        FlSpot(i.toDouble(), visible[i]),
    ];

    // Vertical scaling: prefer the locked range from the parent.
    // Otherwise auto-zoom around the median so spikes stay legible
    // even when the ADC swings the full 0..4095 range.
    double lo;
    double hi;
    if (yMin != null && yMax != null) {
      lo = yMin!;
      hi = yMax!;
    } else {
      final double mn = visible.reduce(math.min);
      final double mx = visible.reduce(math.max);
      final double range = math.max(1.0, mx - mn);
      final double center = (mn + mx) / 2;
      final double window = range * 1.5; // zoom-in window
      lo = center - window;
      hi = center + window;
    }

    return Container(
      height: height,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: traceBg,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.5),
          width: 1.2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: (visible.length - 1).toDouble(),
            minY: lo,
            maxY: hi,
            clipData: const FlClipData.all(),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: true,
              // Vertical spacing tuned to give a "small squares" feel.
              horizontalInterval: (hi - lo) / 4,
              verticalInterval: math.max(10, (visible.length - 1) / 10),
              getDrawingHorizontalLine: (v) => FlLine(
                color: traceGrid.withValues(alpha: 0.6),
                strokeWidth: 1,
              ),
              getDrawingVerticalLine: (v) => FlLine(
                color: traceGrid.withValues(alpha: 0.4),
                strokeWidth: 1,
              ),
            ),
            titlesData: const FlTitlesData(show: false),
            borderData: FlBorderData(
              show: true,
              border: Border(
                left: BorderSide(color: traceGrid, width: 1),
                bottom: BorderSide(color: traceGrid, width: 1),
              ),
            ),
            lineTouchData: const LineTouchData(enabled: false),
            lineBarsData: <LineChartBarData>[
              LineChartBarData(
                spots: spots,
                isCurved: false,
                color: traceLine,
                barWidth: 2.4,
                dotData: const FlDotData(show: false),
                // Soft glow under the trace for the "phosphor monitor" look.
                belowBarData: BarAreaData(
                  show: true,
                  color: traceLine.withValues(alpha: 0.12),
                ),
              ),
            ],
          ),
          duration: const Duration(milliseconds: 120),
        ),
      ),
    ).animate(target: visible.length.toDouble()).fadeIn(
          duration: 300.ms,
        );
  }
}

/// Big animated BPM number for the header — styled in the same
/// neon-on-dark "monitor" palette as [LiveEcgChart].
class BpmOverlay extends StatelessWidget {
  const BpmOverlay({super.key, required this.bpm});
  final int bpm;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Text(
          bpm > 0 ? bpm.toString() : '—',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: AppColors.ecgLine,
                letterSpacing: 1.5,
                shadows: <Shadow>[
                  Shadow(
                    color: AppColors.ecgLine.withValues(alpha: 0.4),
                    blurRadius: 8,
                  ),
                ],
              ),
        ),
        const SizedBox(width: 6),
        const Text(
          'BPM',
          style: TextStyle(
            color: Color(0xFF6FE3A1),
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
          ),
        ),
      ],
    );
  }
}