import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../vitals/domain/device_status.dart';

/// Top header showing ESP32 connectivity, signal & battery.
class DeviceStatusHeader extends StatelessWidget {
  const DeviceStatusHeader({super.key, required this.device});

  final DeviceStatus device;

  Color get _statusColor =>
      device.isOnline ? AppColors.healthy : AppColors.offline;

  String get _signalLabel {
    final int r = device.wifiRssi;
    if (r >= -55) return 'Excellent';
    if (r >= -67) return 'Good';
    if (r >= -75) return 'Fair';
    if (r >= -85) return 'Weak';
    return 'Poor';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bool online = device.isOnline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E2F38)
            : Colors.white,
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: <Widget>[
          Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
              ),
              Icon(
                online ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                color: _statusColor,
                size: 22,
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      device.deviceId,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _statusColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _statusColor,
                              shape: BoxShape.circle,
                            ),
                          )
                              .animate(
                                onPlay: (a) => a.repeat(reverse: true),
                              )
                              .scale(
                                  duration: 1.seconds,
                                  begin: const Offset(0.7, 0.7),
                                  end: const Offset(1.2, 1.2)),
                          const SizedBox(width: 4),
                          Text(
                            online ? 'Online' : 'Offline',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: _statusColor,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  online
                      ? '$_signalLabel signal · FW ${device.firmwareVersion}'
                      : 'Reconnecting…',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.battery_5_bar_rounded,
                      size: 18,
                      color: device.batteryPercent > 30
                          ? AppColors.healthy
                          : AppColors.warning),
                  const SizedBox(width: 4),
                  Text(
                    '${device.batteryPercent}%',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${device.wifiRssi} dBm',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: -0.1, end: 0);
  }
}