import 'package:flutter/material.dart';
import '../models/vehicle.dart';
import '../theme/app_theme.dart';
import '../widgets/connection_status.dart';

class VehicleDetailsScreen extends StatelessWidget {
  final Vehicle vehicle;

  const VehicleDetailsScreen({
    super.key,
    required this.vehicle,
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

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(vehicle.status);
    final isEmergency = vehicle.type == VehicleType.ambulance;

    return Scaffold(
      appBar: AppBar(
        title: Text('Telemetry: ${vehicle.id}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: statusColor.withOpacity(0.5)),
                ),
                child: Text(
                  vehicle.status.displayName,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DemoModeNoticeBanner(),
            const SizedBox(height: 16),

            // Top Hero Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.darkSurfaceVariant,
                    statusColor.withOpacity(0.12),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isEmergency ? AppColors.trafficRed : AppColors.darkBorder,
                  width: isEmergency ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vehicle.id,
                            style: const TextStyle(
                              color: AppColors.textPrimaryDark,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            vehicle.type.displayName,
                            style: const TextStyle(
                              color: AppColors.textSecondaryDark,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.darkSurfaceElevated,
                          shape: BoxShape.circle,
                          border: Border.all(color: statusColor.withOpacity(0.4)),
                        ),
                        child: Icon(
                          vehicle.type == VehicleType.ambulance
                              ? Icons.emergency
                              : vehicle.type == VehicleType.bus
                                  ? Icons.directions_bus
                                  : Icons.directions_car,
                          color: statusColor,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Progress slider
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Journey Trajectory Progress',
                            style: TextStyle(
                              color: AppColors.textMutedDark,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${(vehicle.progressFraction * 100).toInt()}%',
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: vehicle.progressFraction,
                          minHeight: 8,
                          backgroundColor: AppColors.darkSurface,
                          valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildKeyMetric('Estimated ETA', vehicle.eta ?? 'N/A'),
                      Container(width: 1, height: 26, color: AppColors.darkBorder),
                      _buildKeyMetric('Distance Remaining', vehicle.remainingDistance ?? 'N/A'),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Route Information Section (Section 7)
            _buildSectionHeader('ROUTE & DIVERSION AUDIT', Icons.alt_route),
            const SizedBox(height: 12),
            _buildRouteInfoCard(context),

            const SizedBox(height: 24),

            // Step-by-Step Directions
            _buildSectionHeader('STEP-BY-STEP DIRECTIONS', Icons.turn_right_rounded),
            const SizedBox(height: 12),
            _buildDirectionsCard(),

            const SizedBox(height: 24),

            // Live Telemetry Details
            _buildSectionHeader('CURRENT TELEMETRY', Icons.sensors),
            const SizedBox(height: 12),
            _buildTelemetryCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyMetric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimaryDark,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMutedDark,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primaryBlue),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textMutedDark,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }

  Widget _buildRouteInfoCard(BuildContext context) {
    final route = vehicle.routeInfo;
    final rerouteReason = vehicle.rerouteReason ?? route.diversionReason;
    final diversionInstr = vehicle.diversionInstruction;
    final prevRoute = vehicle.previousRoutePath.isNotEmpty
        ? vehicle.previousRoutePath.join(" → ")
        : route.previousRoute;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Current Active Route', route.currentRoute, isHighlight: true),
          if (prevRoute != null) ...[
            const SizedBox(height: 12),
            _buildInfoRow('Previous Original Route', prevRoute),
          ],
          if (route.newRoute != null && route.newRoute != route.currentRoute) ...[
            const SizedBox(height: 12),
            _buildInfoRow('Assigned Bypass Route', route.newRoute!),
          ],
          if (vehicle.rerouteCount > 0) ...[
            const SizedBox(height: 12),
            _buildInfoRow('Dynamic Reroutes', '${vehicle.rerouteCount} optimization events applied'),
          ],
          if (rerouteReason != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.trafficYellow.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.trafficYellow.withOpacity(0.4),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.alt_route_rounded,
                    size: 18,
                    color: AppColors.trafficYellow,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DYNAMIC REROUTING REASON',
                          style: TextStyle(
                            color: AppColors.trafficYellow,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          rerouteReason,
                          style: const TextStyle(
                            color: AppColors.textPrimaryDark,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (diversionInstr != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            diversionInstr,
                            style: const TextStyle(
                              color: AppColors.textSecondaryDark,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Telemetry Timestamp',
                style: TextStyle(color: AppColors.textMutedDark, fontSize: 11),
              ),
              Text(
                '${route.lastUpdateTime.hour.toString().padLeft(2, '0')}:${route.lastUpdateTime.minute.toString().padLeft(2, '0')} (Demo Time)',
                style: const TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionsCard() {
    final directions = vehicle.directions.isNotEmpty
        ? vehicle.directions
        : [
            'Depart from ${vehicle.sourceIntersection}',
            if (vehicle.routePath.length > 2)
              'Follow segments through ${vehicle.routePath.sublist(1, vehicle.routePath.length - 1).join(" → ")}',
            'Arrive safely at destination ${vehicle.destinationIntersection}',
          ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current Navigation Instruction Callout
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0369A1).withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.navigation_rounded, color: Color(0xFF38BDF8), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CURRENT INSTRUCTION',
                        style: TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        vehicle.currentInstruction ?? (directions.isNotEmpty ? directions.first : 'Proceed on current corridor'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Text(
            'Route Navigation Itinerary (${directions.length} steps)',
            style: const TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: directions.length,
            separatorBuilder: (_, __) => const Divider(color: Color(0xFF1E293B), height: 16),
            itemBuilder: (ctx, idx) {
              final isCurrent = idx == 0;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCurrent ? const Color(0xFF0284C7) : const Color(0xFF1E293B),
                    ),
                    child: Text(
                      '${idx + 1}',
                      style: TextStyle(
                        color: isCurrent ? Colors.white : Colors.white70,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      directions[idx],
                      style: TextStyle(
                        color: isCurrent ? const Color(0xFF38BDF8) : AppColors.textPrimaryDark,
                        fontSize: 12.5,
                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        children: [
          _buildInfoRow('Origin Node', vehicle.sourceIntersection),
          const SizedBox(height: 12),
          _buildInfoRow('Destination Node', vehicle.destinationIntersection),
          const SizedBox(height: 12),
          _buildInfoRow('Current Physical Position', vehicle.currentPosition, isHighlight: true),
          if (vehicle.currentInstruction != null) ...[
            const SizedBox(height: 12),
            _buildInfoRow('Active Instruction', vehicle.currentInstruction!),
          ],
          const SizedBox(height: 12),
          _buildInfoRow('Operational State', vehicle.status.displayName),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textMutedDark,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: isHighlight ? AppColors.primaryBlue : AppColors.textPrimaryDark,
              fontSize: 12.5,
              fontWeight: isHighlight ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}
