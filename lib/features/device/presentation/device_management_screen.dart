import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/animated_gradient_bg.dart';
import '../../vitals/application/vitals_providers.dart';
import '../../vitals/domain/device_status.dart';

/// Device Management (Module 11) — ESP32 details, Wi-Fi signal history,
/// pairing info and OTA firmware updates.
class DeviceManagementScreen extends ConsumerStatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  ConsumerState<DeviceManagementScreen> createState() =>
      _DeviceManagementScreenState();
}

class _DeviceManagementScreenState
    extends ConsumerState<DeviceManagementScreen> {
  final List<int> _rssiHistory = <int>[];
  static const int _maxPoints = 40;
  bool _updating = false;

  @override
  Widget build(BuildContext context) {
    final deviceAsync = ref.watch(deviceStatusProvider);
    final scheme = Theme.of(context).colorScheme;

    return AnimatedGradientBg(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Device'),
        ),
        body: deviceAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (d) {
            // Append to history (keep latest _maxPoints).
            if (_rssiHistory.length >= _maxPoints) _rssiHistory.removeAt(0);
            _rssiHistory.add(d.wifiRssi);

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _DeviceCard(device: d),
                  const SizedBox(height: 16),
                  _SectionTitle('Wi-Fi signal history'),
                  Container(
                    height: 180,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: scheme.surfaceContainerHighest
                          .withValues(alpha: 0.6),
                      border: Border.all(
                        color: scheme.outlineVariant
                            .withValues(alpha: 0.4),
                      ),
                    ),
                    child: _rssiHistory.length < 2
                        ? const Center(child: Text('Collecting samples…'))
                        : LineChart(
                            LineChartData(
                              minY: -100,
                              maxY: -30,
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                horizontalInterval: 20,
                                getDrawingHorizontalLine: (_) => FlLine(
                                  color: scheme.outlineVariant
                                      .withValues(alpha: 0.3),
                                  strokeWidth: 1,
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 32,
                                    getTitlesWidget: (v, _) => Text(
                                      '${v.toInt()}',
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles:
                                      SideTitles(showTitles: false),
                                ),
                                topTitles: const AxisTitles(
                                  sideTitles:
                                      SideTitles(showTitles: false),
                                ),
                                bottomTitles: const AxisTitles(
                                  sideTitles:
                                      SideTitles(showTitles: false),
                                ),
                              ),
                              lineBarsData: <LineChartBarData>[
                                LineChartBarData(
                                  isCurved: true,
                                  color: AppColors.primary,
                                  barWidth: 2.5,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    gradient: LinearGradient(
                                      colors: <Color>[
                                        AppColors.primary
                                            .withValues(alpha: 0.4),
                                        AppColors.primary
                                            .withValues(alpha: 0.0),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                  spots: <FlSpot>[
                                    for (int i = 0;
                                        i < _rssiHistory.length;
                                        i++)
                                      FlSpot(i.toDouble(),
                                          _rssiHistory[i].toDouble()),
                                  ],
                                ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  _SectionTitle('Pairing'),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: scheme.surfaceContainerHighest
                          .withValues(alpha: 0.6),
                    ),
                    child: Column(
                      children: <Widget>[
                        _Row(
                          icon: Icons.qr_code_2_rounded,
                          label: 'Pairing code',
                          value: _generatePairingCode(d.deviceId),
                        ),
                        const Divider(height: 20),
                        _Row(
                          icon: Icons.wifi_rounded,
                          label: 'Wi-Fi',
                          value: d.isOnline ? 'Connected' : 'Disconnected',
                        ),
                        const Divider(height: 20),
                        _Row(
                          icon: Icons.battery_full_rounded,
                          label: 'Battery',
                          value: '${d.batteryPercent}%',
                        ),
                        const Divider(height: 20),
                        _Row(
                          icon: Icons.access_time_rounded,
                          label: 'Last sync',
                          value: DateFormat('MMM d · HH:mm:ss')
                              .format(d.lastSeen),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionTitle('Firmware'),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: scheme.surfaceContainerHighest
                          .withValues(alpha: 0.6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _Row(
                          icon: Icons.memory_rounded,
                          label: 'Current version',
                          value: d.firmwareVersion,
                        ),
                        const SizedBox(height: 8),
                        _Row(
                          icon: Icons.system_update_rounded,
                          label: 'Latest available',
                          value: '1.0.4',
                          valueColor: _hasUpdate(d.firmwareVersion)
                              ? AppColors.warning
                              : null,
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _updating || !_hasUpdate(d.firmwareVersion)
                              ? null
                              : _runOta,
                          icon: _updating
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.download_rounded),
                          label: Text(_updating
                              ? 'Updating…'
                              : (_hasUpdate(d.firmwareVersion)
                                  ? 'Update to 1.0.4'
                                  : 'Up to date')),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _generatePairingCode(String deviceId) {
    if (deviceId.isEmpty) return '------';
    final hash = deviceId.codeUnits.fold<int>(0, (a, b) => a + b);
    final rng = math.Random(hash);
    return (100000 + rng.nextInt(899999)).toString();
  }

  bool _hasUpdate(String current) {
    return current != '1.0.4';
  }

  Future<void> _runOta() async {
    setState(() => _updating = true);
    // Simulate OTA — in real build this would push firmware bytes
    // over BLE / Wi-Fi to the ESP32.
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    setState(() => _updating = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Firmware updated to 1.0.4')),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device});
  final DeviceStatus device;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = device.isOnline ? AppColors.healthy : AppColors.offline;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: <Color>[
            AppColors.primary.withValues(alpha: 0.15),
            AppColors.tertiary.withValues(alpha: 0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: color.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 28,
            backgroundColor: color.withValues(alpha: 0.20),
            child: Icon(
              device.isOnline
                  ? Icons.bluetooth_connected_rounded
                  : Icons.bluetooth_disabled_rounded,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  device.deviceId,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                Text(
                  device.isOnline ? 'Connected' : 'Offline',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: color.withValues(alpha: 0.18),
            ),
            child: Text(
              device.isOnline ? 'LIVE' : 'OFFLINE',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: valueColor ?? scheme.onSurface,
              ),
        ),
      ],
    );
  }
}