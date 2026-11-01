import 'package:flutter/material.dart';
import '../models/notification_item.dart';
import '../services/traffic_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/connection_status.dart';

class NotificationsScreen extends StatelessWidget {
  final TrafficRepository repository;

  const NotificationsScreen({
    super.key,
    required this.repository,
  });

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.journeyStarted:
        return Icons.play_arrow_rounded;
      case NotificationType.routeChanged:
        return Icons.alt_route;
      case NotificationType.trafficDelay:
        return Icons.timer_outlined;
      case NotificationType.journeyCompleted:
        return Icons.check_circle_outline;
      case NotificationType.connectionStatusChanged:
        return Icons.sensors;
    }
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.journeyStarted:
        return AppColors.primaryBlue;
      case NotificationType.routeChanged:
        return AppColors.trafficYellow;
      case NotificationType.trafficDelay:
        return AppColors.trafficRed;
      case NotificationType.journeyCompleted:
        return AppColors.trafficGreen;
      case NotificationType.connectionStatusChanged:
        return AppColors.accentPurple;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Traffic Alerts & Events'),
        actions: [
          IconButton(
            tooltip: 'Clear All',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () => repository.clearAllNotifications(),
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationItem>>(
        stream: repository.notificationsStream,
        initialData: repository.currentNotifications,
        builder: (context, snapshot) {
          final notifications = snapshot.data ?? [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const DemoModeNoticeBanner(),
              const SizedBox(height: 16),
              if (notifications.isEmpty)
                _buildEmptyState()
              else
                ...notifications.map((item) {
                  final color = _getNotificationColor(item.type);
                  final icon = _getNotificationIcon(item.type);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.darkSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: item.isRead ? AppColors.darkBorder : color.withOpacity(0.5),
                        width: item.isRead ? 1.0 : 1.3,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, color: color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: TextStyle(
                                        color: AppColors.textPrimaryDark,
                                        fontSize: 13.5,
                                        fontWeight: item.isRead
                                            ? FontWeight.w500
                                            : FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _formatTime(item.timestamp),
                                    style: const TextStyle(
                                      color: AppColors.textMutedDark,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.message,
                                style: const TextStyle(
                                  color: AppColors.textSecondaryDark,
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: const Column(
        children: [
          Icon(Icons.notifications_none, size: 40, color: AppColors.textMutedDark),
          SizedBox(height: 12),
          Text(
            'No Traffic Alerts',
            style: TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'System alerts, signal queues, and reroute notices will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
