import 'package:flutter/material.dart';
import '../models/vehicle.dart';
import '../models/journey_record.dart';
import '../models/traffic_state.dart';
import '../services/traffic_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/connection_status.dart';
import 'journey_screen.dart';

class VehiclesScreen extends StatelessWidget {
  final TrafficRepository repository;

  const VehiclesScreen({
    super.key,
    required this.repository,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Previous Journeys'),
      ),
      body: StreamBuilder<List<JourneyRecord>>(
        stream: repository.journeyHistoryStream,
        initialData: repository.journeyHistory,
        builder: (context, snapshot) {
          final history = snapshot.data ?? repository.journeyHistory;

          return StreamBuilder<Vehicle?>(
            stream: repository.activeUserVehicleStream,
            initialData: repository.activeUserVehicle,
            builder: (context, activeSnap) {
              final activeVehicle = activeSnap.data ?? repository.activeUserVehicle;

              return RefreshIndicator(
                onRefresh: () => repository.refresh(),
                color: AppColors.primaryBlue,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Active Journey Card (if any active trip is running)
                    if (activeVehicle != null && activeVehicle.status != JourneyStatus.arrived) ...[
                      _buildActiveTripHeader(context, activeVehicle),
                      const SizedBox(height: 20),
                    ],

                    // Section Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TRIP HISTORY',
                          style: TextStyle(
                            color: AppColors.textMutedDark,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                        Text(
                          '${history.length} logged',
                          style: const TextStyle(
                            color: AppColors.textSecondaryDark,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (history.isEmpty)
                      _buildEmptyState(context)
                    else
                      ...history.map((record) => _buildJourneyCard(context, record)),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: StreamBuilder<Vehicle?>(
        stream: repository.activeUserVehicleStream,
        initialData: repository.activeUserVehicle,
        builder: (context, snapshot) {
          final hasActive = snapshot.data != null && snapshot.data!.status != JourneyStatus.arrived;
          if (hasActive) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton.extended(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => JourneyScreen(repository: repository),
                ),
              );
            },
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('New Journey'),
          );
        },
      ),
    );
  }

  Widget _buildActiveTripHeader(BuildContext context, Vehicle v) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xF20B132B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF06B6D4), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3306B6D4),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF06B6D4),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'CURRENT ACTIVE JOURNEY',
                    style: TextStyle(
                      color: Color(0xFF22D3EE),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${v.sourceIntersection} → ${v.destinationIntersection}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // Current Position Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              children: [
                const Icon(Icons.my_location_rounded, color: Color(0xFF38BDF8), size: 14),
                const SizedBox(width: 6),
                const Text('Current: ', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
                Expanded(
                  child: Text(
                    v.currentPosition,
                    style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 11.5, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Next Turn Instruction
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF082F49),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.6)),
            ),
            child: Row(
              children: [
                const Icon(Icons.turn_right_rounded, color: Color(0xFF38BDF8), size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    v.currentInstruction ?? (v.directions.isNotEmpty ? v.directions.first : 'Head towards ${v.destinationIntersection}'),
                    style: const TextStyle(color: Color(0xFFE0F2FE), fontSize: 11.5, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          if (v.isRerouted) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF78350F).withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amberAccent.withOpacity(0.8)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.alt_route_rounded, color: Colors.amberAccent, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'REROUTED: ${v.rerouteReason ?? "Congestion bypass"}',
                          style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                        if (v.diversionInstruction != null)
                          Text(
                            v.diversionInstruction!,
                            style: const TextStyle(color: Colors.white70, fontSize: 10.5),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: v.progressFraction,
              backgroundColor: const Color(0xFF1E293B),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF06B6D4)),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Speed: ${v.speed.toStringAsFixed(0)} km/h • ${(v.progressFraction * 100).toInt()}% Done',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              InkWell(
                onTap: () async {
                  await repository.endActiveJourney();
                },
                child: const Text(
                  'Cancel / End Trip',
                  style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJourneyCard(BuildContext context, JourneyRecord record) {
    final isCompleted = record.status == 'Completed';
    final isCancelled = record.status == 'Cancelled';

    Color statusColor = Colors.green;
    if (isCancelled) statusColor = Colors.orange;
    if (record.status == 'In Progress') statusColor = const Color(0xFF06B6D4);

    IconData vIcon = Icons.directions_car;
    if (record.vehicleType == VehicleType.bus) vIcon = Icons.directions_bus;
    if (record.vehicleType == VehicleType.ambulance) vIcon = Icons.emergency;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(vIcon, color: AppColors.primaryBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.vehicleType.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(record.startTime),
                      style: const TextStyle(
                        color: AppColors.textMutedDark,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  record.status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.trip_origin, color: Color(0xFF10B981), size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  record.sourceIntersectionName,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Container(
              height: 14,
              width: 1.5,
              color: const Color(0xFF475569),
            ),
          ),
          Row(
            children: [
              const Icon(Icons.location_on, color: Color(0xFFEF4444), size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  record.destinationIntersectionName,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (record.durationSeconds > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.timer_outlined, color: AppColors.textMutedDark, size: 13),
                const SizedBox(width: 4),
                Text(
                  'Duration: ${record.durationSeconds.toStringAsFixed(1)}s',
                  style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 11),
                ),
                if (record.routePath.isNotEmpty) ...[
                  const SizedBox(width: 14),
                  const Icon(Icons.alt_route, color: AppColors.textMutedDark, size: 13),
                  const SizedBox(width: 4),
                  Text(
                    '${record.routePath.length} Waypoints',
                    style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 11),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: const Icon(
              Icons.route_outlined,
              size: 40,
              color: AppColors.textMutedDark,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Previous Journeys',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'You haven\'t completed any trips yet.\nStart your first journey from the dashboard map!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
