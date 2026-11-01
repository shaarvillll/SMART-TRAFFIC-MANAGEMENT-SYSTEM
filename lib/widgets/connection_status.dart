import 'package:flutter/material.dart';
import '../models/traffic_state.dart';
import '../services/traffic_repository.dart';
import '../theme/app_theme.dart';

class ConnectionStatusBadge extends StatelessWidget {
  final ConnectionStatus status;
  final VoidCallback? onTap;

  const ConnectionStatusBadge({
    super.key,
    required this.status,
    this.onTap,
  });

  Color get _statusColor {
    switch (status) {
      case ConnectionStatus.demoMode:
        return AppColors.primaryBlue;
      case ConnectionStatus.connecting:
        return AppColors.trafficYellow;
      case ConnectionStatus.connected:
        return AppColors.trafficGreen;
      case ConnectionStatus.disconnected:
        return AppColors.trafficRed;
    }
  }

  IconData get _statusIcon {
    switch (status) {
      case ConnectionStatus.demoMode:
        return Icons.science_outlined;
      case ConnectionStatus.connecting:
        return Icons.sync;
      case ConnectionStatus.connected:
        return Icons.sensors;
      case ConnectionStatus.disconnected:
        return Icons.cloud_off_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _statusColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _statusColor.withOpacity(0.4),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _statusColor,
                boxShadow: [
                  BoxShadow(
                    color: _statusColor.withOpacity(0.6),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(_statusIcon, size: 13, color: _statusColor),
            const SizedBox(width: 4),
            Text(
              status.label,
              style: TextStyle(
                color: _statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DemoModeNoticeBanner extends StatelessWidget {
  final TrafficRepository? repository;
  const DemoModeNoticeBanner({super.key, this.repository});

  @override
  Widget build(BuildContext context) {
    final isLive = repository != null &&
        repository!.currentConnectionStatus == ConnectionStatus.connected;

    final color = isLive ? AppColors.trafficGreen : AppColors.primaryBlue;
    final icon = isLive ? Icons.sensors : Icons.info_outline;
    final text = isLive
        ? 'Live Simulator Connected: Real-time telemetry synchronized with Desktop Traffic Simulator.'
        : 'Sample Demo Dataset: Running in standalone verification mode. No external simulator attached.';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 11.5,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
