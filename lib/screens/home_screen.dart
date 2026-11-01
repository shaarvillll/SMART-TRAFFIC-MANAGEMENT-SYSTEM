import 'package:flutter/material.dart';
import '../models/traffic_state.dart';
import '../models/vehicle.dart';
import '../services/traffic_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/traffic_map_container.dart';
import '../widgets/virtual_city_map_widget.dart';
import '../widgets/connection_status.dart';
import 'journey_screen.dart';

class HomeScreen extends StatelessWidget {
  final TrafficRepository repository;
  final VoidCallback onNavigateToVehicles;

  const HomeScreen({
    super.key,
    required this.repository,
    required this.onNavigateToVehicles,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.navigation_rounded,
                color: AppColors.primaryBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Smart Traffic Navigation',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => repository.refresh(),
        color: AppColors.primaryBlue,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // User Journey Action Banner (Start Journey or Active Trip in Progress)
            StreamBuilder<Vehicle?>(
              stream: repository.activeUserVehicleStream,
              initialData: repository.activeUserVehicle,
              builder: (context, snapshot) {
                final activeVehicle = snapshot.data ?? repository.activeUserVehicle;
                if (activeVehicle != null && activeVehicle.status != JourneyStatus.arrived) {
                  return _buildActiveTripCard(context, activeVehicle);
                }
                return _buildStartJourneyBanner(context);
              },
            ),
            const SizedBox(height: 18),

            // Live Virtual City Map
            TrafficMapContainer(
              mapContent: VirtualCityMapWidget(
                repository: repository,
                height: 420,
              ),
            ),
            const SizedBox(height: 18),

            // User Trips Quick Action Card
            _buildTripHistoryCard(context),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStartJourneyBanner(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0284C7), // Sky 600
            Color(0xFF2563EB), // Indigo 600
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => JourneyScreen(repository: repository),
              ),
            );
          },
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Start New Journey',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Select vehicle and route to navigate across the city',
                        style: TextStyle(
                          color: Color(0xFFE0F2FE),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTripCard(BuildContext context, Vehicle v) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F2027),
            Color(0xFF203A43),
            Color(0xFF2C5364),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF06B6D4), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x4006B6D4),
            blurRadius: 16,
            offset: Offset(0, 6),
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
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFF06B6D4),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'ACTIVE TRIP IN PROGRESS',
                    style: TextStyle(
                      color: Color(0xFF22D3EE),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${v.sourceIntersection} → ${v.destinationIntersection}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.speed, color: Colors.white70, size: 14),
              const SizedBox(width: 4),
              Text(
                '${v.speed.toStringAsFixed(0)} km/h',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(width: 14),
              const Icon(Icons.schedule, color: Colors.white70, size: 14),
              const SizedBox(width: 4),
              Text(
                'ETA: ${v.eta ?? "--"}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: v.status == JourneyStatus.waitingAtSignal
                      ? Colors.red.withOpacity(0.3)
                      : Colors.green.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  v.status == JourneyStatus.waitingAtSignal ? 'Signal Waiting' : 'Moving',
                  style: TextStyle(
                    color: v.status == JourneyStatus.waitingAtSignal ? Colors.redAccent : Colors.greenAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 10),

          // Current Position Display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withOpacity(0.8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.my_location_rounded, color: Color(0xFF38BDF8), size: 15),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    v.currentPosition,
                    style: const TextStyle(color: Color(0xFFE0F2FE), fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Turn-by-Turn / Next Direction Instruction
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.turn_right_rounded, color: Color(0xFF38BDF8), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NEXT INSTRUCTION',
                        style: TextStyle(color: Color(0xFF7DD3FC), fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        v.currentInstruction ?? 'Proceed along route towards ${v.destinationIntersection}',
                        style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Dynamic Rerouting Alert Banner (Shown prominently if rerouted)
          if (v.routeInfo.isRerouted || v.status == JourneyStatus.rerouted) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF831843), Color(0xFF4C0519)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF43F5E), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF43F5E).withOpacity(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.alt_route_rounded, color: Color(0xFFFDA4AF), size: 18),
                      SizedBox(width: 8),
                      Text(
                        'AI DYNAMIC REROUTE ACTIVE',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11.5, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Reason for Rerouting: ${v.routeInfo.diversionReason ?? "Congestion detected ahead"}',
                    style: const TextStyle(color: Color(0xFFFFE4E6), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  if (v.routeInfo.diversionInstruction != null && v.routeInfo.diversionInstruction!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Action: ${v.routeInfo.diversionInstruction}',
                      style: const TextStyle(color: Color(0xFFFEE2E2), fontSize: 11),
                    ),
                  ],
                  const SizedBox(height: 6),
                  if (v.routeInfo.previousRoute != null)
                    Text(
                      'Old Route: ${v.routeInfo.previousRoute}',
                      style: const TextStyle(color: Colors.white54, fontSize: 10.5, decoration: TextDecoration.lineThrough),
                    ),
                  Text(
                    'New Route: ${v.routeInfo.currentRoute}',
                    style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Directions Sheet Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showDirectionsSheet(context, v),
              icon: const Icon(Icons.format_list_bulleted_rounded, size: 16),
              label: const Text('View Full Turn-by-Turn Directions'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF38BDF8),
                side: const BorderSide(color: Color(0xFF0284C7)),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(height: 10),

          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: v.progressFraction,
              backgroundColor: const Color(0xFF1E293B),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF06B6D4)),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Only 1 active journey allowed. New journey unlocks upon arrival.',
                  style: TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ),
              TextButton(
                onPressed: () async {
                  await repository.endActiveJourney();
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
                child: const Text('End Trip'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDirectionsSheet(BuildContext context, Vehicle v) {
    final steps = v.directions.isNotEmpty
        ? v.directions
        : (v.routePath.length >= 2
            ? [
                '1. Depart from ${v.sourceIntersection}',
                for (int i = 0; i < v.routePath.length - 1; i++)
                  '${i + 2}. Proceed from ${v.routePath[i]} to ${v.routePath[i + 1]}',
                '${v.routePath.length + 1}. Arrive at destination: ${v.destinationIntersection}',
              ]
            : ['1. Travel from ${v.sourceIntersection} to ${v.destinationIntersection}']);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B132B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.directions_rounded, color: Color(0xFF38BDF8), size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Turn-by-Turn Navigation',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${v.sourceIntersection} → ${v.destinationIntersection}',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              if (v.routeInfo.isRerouted) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF831843).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF43F5E)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.alt_route, color: Color(0xFFFDA4AF), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Rerouted: ${v.routeInfo.diversionReason ?? "Congestion bypass active"}',
                          style: const TextStyle(color: Color(0xFFFFE4E6), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: steps.length,
                  separatorBuilder: (_, __) => const Divider(color: Color(0xFF1E293B), height: 16),
                  itemBuilder: (ctx, i) {
                    final isFirst = i == 0;
                    final isLast = i == steps.length - 1;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: isFirst
                              ? const Color(0xFF0284C7)
                              : (isLast ? const Color(0xFF10B981) : const Color(0xFF1E293B)),
                          child: Icon(
                            isFirst ? Icons.play_arrow : (isLast ? Icons.flag : Icons.arrow_downward),
                            size: 13,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            steps[i],
                            style: TextStyle(
                              color: isLast ? const Color(0xFF6EE7B7) : Colors.white,
                              fontSize: 13,
                              fontWeight: isLast || isFirst ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTripHistoryCard(BuildContext context) {
    final history = repository.journeyHistory;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.history_rounded,
              color: AppColors.primaryBlue,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Previous Journeys',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  history.isEmpty
                      ? 'No journeys recorded yet'
                      : '${history.length} completed trip${history.length == 1 ? "" : "s"} logged',
                  style: const TextStyle(
                    color: AppColors.textSecondaryDark,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onNavigateToVehicles,
            child: const Text('View All'),
          ),
        ],
      ),
    );
  }
}
