import 'package:flutter/material.dart';
import '../models/vehicle.dart';
import '../theme/app_theme.dart';

class VehicleCard extends StatelessWidget {
  final Vehicle vehicle;
  final VoidCallback? onTap;

  const VehicleCard({
    super.key,
    required this.vehicle,
    this.onTap,
  });

  Color _getStatusColor(JourneyStatus status) {
    switch (status) {
      case JourneyStatus.initializing:
        return AppColors.accentPurple;
      case JourneyStatus.moving:
        return AppColors.trafficGreen;
      case JourneyStatus.waitingAtSignal:
        return AppColors.trafficYellow;
      case JourneyStatus.delayed:
        return AppColors.trafficRed;
      case JourneyStatus.rerouted:
        return AppColors.primaryBlue;
      case JourneyStatus.arrived:
        return AppColors.secondaryTeal;
      case JourneyStatus.failed:
        return Colors.red.shade700;
    }
  }

  IconData _getTypeIcon(VehicleType type) {
    switch (type) {
      case VehicleType.car:
        return Icons.directions_car_outlined;
      case VehicleType.bus:
        return Icons.directions_bus_outlined;
      case VehicleType.ambulance:
        return Icons.emergency_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(vehicle.status);
    final isEmergency = vehicle.type == VehicleType.ambulance;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isEmergency
                  ? AppColors.trafficRed.withOpacity(0.6)
                  : AppColors.darkBorder,
              width: isEmergency ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Icon + ID + Status badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isEmergency
                          ? AppColors.trafficRed.withOpacity(0.18)
                          : AppColors.primaryBlue.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isEmergency
                            ? AppColors.trafficRed.withOpacity(0.4)
                            : AppColors.primaryBlue.withOpacity(0.3),
                      ),
                    ),
                    child: Icon(
                      _getTypeIcon(vehicle.type),
                      color: isEmergency ? AppColors.trafficRed : AppColors.primaryBlue,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              vehicle.id,
                              style: const TextStyle(
                                color: AppColors.textPrimaryDark,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                            if (isEmergency) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.trafficRed.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'PRIORITY',
                                  style: TextStyle(
                                    color: AppColors.trafficRed,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          vehicle.type.displayName,
                          style: const TextStyle(
                            color: AppColors.textSecondaryDark,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          vehicle.status.displayName,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Source to Destination visual timeline
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.darkSurfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ORIGIN',
                            style: TextStyle(
                              color: AppColors.textMutedDark,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            vehicle.sourceIntersection,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimaryDark,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: AppColors.textMutedDark,
                        size: 16,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'DESTINATION',
                            style: TextStyle(
                              color: AppColors.textMutedDark,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            vehicle.destinationIntersection,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimaryDark,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Current Position & Route snippet
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.navigation_outlined,
                    size: 14,
                    color: AppColors.textSecondaryDark,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Position: ${vehicle.currentPosition}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondaryDark,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),

              if (vehicle.routeInfo.isRerouted) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.alt_route, size: 13, color: AppColors.primaryBlue),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Diversion: ${vehicle.routeInfo.diversionReason ?? "Congestion bypass"}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.primaryBlue,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Progress bar and ETA info
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: vehicle.progressFraction,
                        minHeight: 5,
                        backgroundColor: AppColors.darkSurfaceElevated,
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (vehicle.eta != null) ...[
                    Text(
                      'ETA: ${vehicle.eta}',
                      style: const TextStyle(
                        color: AppColors.textPrimaryDark,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (vehicle.remainingDistance != null)
                    Text(
                      vehicle.remainingDistance!,
                      style: const TextStyle(
                        color: AppColors.textMutedDark,
                        fontSize: 11.5,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
