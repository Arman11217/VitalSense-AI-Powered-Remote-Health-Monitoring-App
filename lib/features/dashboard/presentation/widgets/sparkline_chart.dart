import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// Tiny line chart used for the "recent activity" rows on the dashboard.
class SparklineChart extends StatelessWidget {
  const SparklineChart({
    super.key,
    required this.values,
    this.color,
    this.height = 36,
  });

  final List<double> values;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return SizedBox(height: height);
    }
    final double minV = values.reduce((a, b) => a < b ? a : b);
    final double maxV = values.reduce((a, b) => a > b ? a : b);
    final double range = (maxV - minV).abs() < 0.001 ? 1 : (maxV - minV);

    final List<FlSpot> spots = <FlSpot>[
      for (int i = 0; i < values.length; i++)
        FlSpot(i.toDouble(), values[i]),
    ];

    final Color line = color ?? AppColors.primary;

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          minX: 0,
          maxX: (values.length - 1).toDouble(),
          minY: minV - range * 0.2,
          maxY: maxV + range * 0.2,
          lineBarsData: <LineChartBarData>[
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: line,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    line.withValues(alpha: 0.30),
                    line.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 350),
      ),
    );
  }
}