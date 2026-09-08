import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/animated_gradient_bg.dart';
import '../../vitals/application/vitals_providers.dart';
import '../../vitals/domain/vital_reading.dart';
import '../domain/report_models.dart';

/// Reports feature (Module 8) — generate & share CSV / PDF reports.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readings = ref.watch(recentReadingsProvider);

    return AnimatedGradientBg(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Reports'),
        ),
        body: readings.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (data) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _Header(count: data.length),
                const SizedBox(height: 20),
                _ReportButton(
                  label: 'Export as CSV',
                  icon: Icons.table_chart_rounded,
                  color: AppColors.tertiary,
                  onTap: data.isEmpty
                      ? null
                      : () => _share(context, data, ReportKind.csv),
                ),
                const SizedBox(height: 12),
                _ReportButton(
                  label: 'Export as PDF',
                  icon: Icons.picture_as_pdf_rounded,
                  color: AppColors.critical,
                  onTap: data.isEmpty
                      ? null
                      : () => _share(context, data, ReportKind.pdf),
                ),
                const SizedBox(height: 24),
                _Preview(readings: data),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _share(
    BuildContext context,
    List<VitalReading> data,
    ReportKind kind,
  ) async {
    try {
      final Uint8List blob = kind == ReportKind.csv
          ? buildCsv(data)
          : await buildPdf(data);
      final String ext = kind == ReportKind.csv ? 'csv' : 'pdf';
      final String fname =
          'vitalsense_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.$ext';

      final dir = await getTemporaryDirectory();
      final f = await File.fromUri(dir.uri.resolve(fname)).writeAsBytes(blob);

      await Share.shareXFiles(
        <XFile>[
          XFile(
            f.path,
            mimeType: kind == ReportKind.csv
                ? 'text/csv'
                : 'application/pdf',
          ),
        ],
        text: 'VitalSense report (${data.length} readings)',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: <Color>[
            AppColors.primary.withValues(alpha: 0.20),
            AppColors.tertiary.withValues(alpha: 0.10),
          ],
        ),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.assignment_rounded, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Health Reports',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                Text(
                  '$count readings available · exported as CSV or PDF.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportButton extends StatelessWidget {
  const _ReportButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: color.withValues(alpha: enabled ? 0.18 : 0.06),
            border: Border.all(
              color: color.withValues(alpha: enabled ? 0.6 : 0.2),
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: enabled
                            ? color
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              Icon(Icons.ios_share_rounded,
                  color: enabled
                      ? color
                      : Theme.of(context).colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.readings});
  final List<VitalReading> readings;

  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) return const SizedBox.shrink();
    final recent = readings.length > 6
        ? readings.sublist(readings.length - 6)
        : readings;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E2F38)
            : Colors.white,
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Preview (last ${recent.length})',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(height: 8),
          ...recent.reversed.map(
            (r) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      DateFormat('MMM d HH:mm:ss').format(r.timestamp),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    'HR ${r.heartRateBpm}  SpO₂ ${r.spo2Percent}%  ${r.temperatureC.toStringAsFixed(1)}°C',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}