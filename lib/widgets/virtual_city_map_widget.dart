import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/intersection.dart';
import '../models/road.dart';
import '../models/vehicle.dart';
import '../services/traffic_repository.dart';
import '../screens/journey_screen.dart';
import '../theme/app_theme.dart';

double _hypot(double dx, double dy) => math.sqrt(dx * dx + dy * dy);

/// Interactive 2D Virtual City Simulation Map.
/// Renders the complete irregular city network, roads, signals, landmarks, and live moving vehicles.
class VirtualCityMapWidget extends StatefulWidget {
  final TrafficRepository repository;
  final double height;
  final bool isFullScreen;

  const VirtualCityMapWidget({
    super.key,
    required this.repository,
    this.height = 360,
    this.isFullScreen = false,
  });

  @override
  State<VirtualCityMapWidget> createState() => _VirtualCityMapWidgetState();
}

class _VirtualCityMapWidgetState extends State<VirtualCityMapWidget>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformCtrl = TransformationController();
  Vehicle? _selectedVehicle;
  Intersection? _selectedIntersection;
  late AnimationController _pulseController;

  static const double baseWidth = 1040.0;
  static const double baseHeight = 840.0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _transformCtrl.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transformCtrl.value = Matrix4.identity();
  }

  void _zoomIn() {
    _transformCtrl.value = (_transformCtrl.value.clone()..scale(1.25));
  }

  void _zoomOut() {
    _transformCtrl.value = (_transformCtrl.value.clone()..scale(0.8));
  }

  void _openFullScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('Virtual City Network Map'),
          ),
          body: VirtualCityMapWidget(
            repository: widget.repository,
            height: double.infinity,
            isFullScreen: true,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Intersection>>(
      stream: widget.repository.intersectionsStream,
      initialData: widget.repository.availableIntersections,
      builder: (context, interSnap) {
        final intersections = interSnap.data ?? widget.repository.availableIntersections;

        return StreamBuilder<List<Road>>(
          stream: widget.repository.roadsStream,
          initialData: widget.repository.monitoredRoads,
          builder: (context, roadSnap) {
            final roads = roadSnap.data ?? widget.repository.monitoredRoads;

            return StreamBuilder<List<Vehicle>>(
              stream: widget.repository.vehiclesStream,
              initialData: widget.repository.currentVehicles,
              builder: (context, vehicleSnap) {
                final vehicles = vehicleSnap.data ?? widget.repository.currentVehicles;

                return Container(
                  height: widget.height == double.infinity ? null : widget.height,
                  decoration: BoxDecoration(
                    color: const Color(0xFF090D16),
                    borderRadius: widget.isFullScreen ? null : BorderRadius.circular(16),
                    border: widget.isFullScreen
                        ? null
                        : Border.all(color: AppColors.darkBorder, width: 1.2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      // Live Vector Simulation Map
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final cWidth = constraints.maxWidth;
                          final cHeight = constraints.maxHeight;

                          return InteractiveViewer(
                            transformationController: _transformCtrl,
                            minScale: 0.5,
                            maxScale: 3.5,
                            boundaryMargin: const EdgeInsets.all(80),
                            child: GestureDetector(
                              onTapUp: (details) {
                                _handleCanvasTap(
                                  details.localPosition,
                                  cWidth,
                                  cHeight,
                                  intersections,
                                  vehicles,
                                );
                              },
                              child: AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, _) {
                                  return CustomPaint(
                                    size: Size(cWidth, cHeight),
                                    painter: _CityMapPainter(
                                      intersections: intersections,
                                      roads: roads,
                                      vehicles: vehicles,
                                      selectedVehicle: _selectedVehicle,
                                      selectedIntersection: _selectedIntersection,
                                      activeUserVehicleId: widget.repository.activeUserVehicleId,
                                      pulseValue: _pulseController.value,
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),

                      // Overlay Controls (Top Right)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Column(
                          children: [
                            _buildControlBtn(
                              icon: Icons.add,
                              tooltip: 'Zoom In',
                              onTap: _zoomIn,
                            ),
                            const SizedBox(height: 6),
                            _buildControlBtn(
                              icon: Icons.remove,
                              tooltip: 'Zoom Out',
                              onTap: _zoomOut,
                            ),
                            const SizedBox(height: 6),
                            _buildControlBtn(
                              icon: Icons.center_focus_strong,
                              tooltip: 'Reset View',
                              onTap: _resetZoom,
                            ),
                            if (!widget.isFullScreen) ...[
                              const SizedBox(height: 6),
                              _buildControlBtn(
                                icon: Icons.fullscreen,
                                tooltip: 'Full Screen',
                                onTap: () => _openFullScreen(context),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Active User Vehicle Card OR Selected Item Quick Info (Bottom Card)
                      if (widget.repository.activeUserVehicle != null)
                        Positioned(
                          left: 10,
                          right: 10,
                          bottom: 10,
                          child: _buildUserVehicleCard(widget.repository.activeUserVehicle!),
                        )
                      else if (_selectedVehicle != null)
                        Positioned(
                          left: 10,
                          right: 10,
                          bottom: 10,
                          child: _buildVehicleCard(_selectedVehicle!),
                        )
                      else if (_selectedIntersection != null)
                        Positioned(
                          left: 10,
                          right: 10,
                          bottom: 10,
                          child: _buildIntersectionCard(_selectedIntersection!),
                        )
                      else
                        Positioned(
                          left: 20,
                          right: 20,
                          bottom: 14,
                          child: _buildStartJourneyFloatingButton(context),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _handleCanvasTap(
    Offset tapPos,
    double cWidth,
    double cHeight,
    List<Intersection> intersections,
    List<Vehicle> vehicles,
  ) {
    final scale = math.min(cWidth / baseWidth, cHeight / baseHeight);
    final offsetX = (cWidth - baseWidth * scale) / 2.0;
    final offsetY = (cHeight - baseHeight * scale) / 2.0;

    // Invert transform to model coordinates
    final modelX = (tapPos.dx - offsetX) / scale;
    final modelY = (tapPos.dy - offsetY) / scale;

    // Check vehicles first
    for (final v in vehicles) {
      final dist = _hypot(v.x - modelX, v.y - modelY);
      if (dist < 35.0) {
        setState(() {
          _selectedVehicle = v;
          _selectedIntersection = null;
        });
        return;
      }
    }

    // Check intersections
    for (final node in intersections) {
      final dist = _hypot(node.x - modelX, node.y - modelY);
      if (dist < 40.0) {
        setState(() {
          _selectedIntersection = node;
          _selectedVehicle = null;
        });
        return;
      }
    }

    // Dismiss selection if tapped empty space
    if (_selectedVehicle != null || _selectedIntersection != null) {
      setState(() {
        _selectedVehicle = null;
        _selectedIntersection = null;
      });
    }
  }

  Widget _buildControlBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xD91E293B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF475569)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: iconColor ?? Colors.white, size: 18),
        ),
      ),
    );
  }



  Widget _buildStartJourneyFloatingButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0284C7), // Sky 600
            Color(0xFF2563EB), // Blue 600
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x660284C7),
            blurRadius: 14,
            offset: Offset(0, 4),
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
                builder: (_) => JourneyScreen(repository: widget.repository),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.directions_car_filled_rounded, color: Colors.white, size: 22),
                SizedBox(width: 10),
                Text(
                  'Add Vehicle Journey',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, color: Colors.white70, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDirectionsSheet(BuildContext context, Vehicle v) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final directions = v.directions.isNotEmpty
            ? v.directions
            : [
                'Depart from ${v.sourceIntersection}',
                if (v.routePath.length > 2)
                  'Continue along ${v.routePath.sublist(1, v.routePath.length - 1).join(" → ")}',
                'Arrive at destination: ${v.destinationIntersection}',
              ];

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF06B6D4).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.turn_right_rounded, color: Color(0xFF22D3EE), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Step-by-Step Directions (${directions.length})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.my_location_rounded, color: Color(0xFF38BDF8), size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Current Position: ${v.currentPosition}',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              if (v.isRerouted) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.alt_route_rounded, color: Colors.amber, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rerouting Reason: ${v.rerouteReason ?? "Congestion detected"}',
                              style: const TextStyle(color: Colors.amber, fontSize: 11.5, fontWeight: FontWeight.bold),
                            ),
                            if (v.diversionInstruction != null)
                              Text(
                                v.diversionInstruction!,
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                          ],
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
                  itemCount: directions.length,
                  separatorBuilder: (_, __) => const Divider(color: Color(0xFF1E293B), height: 14),
                  itemBuilder: (ctx, idx) {
                    final isCurrentStep = idx == 0;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCurrentStep ? const Color(0xFF06B6D4) : const Color(0xFF1E293B),
                          ),
                          child: Text(
                            '${idx + 1}',
                            style: TextStyle(
                              color: isCurrentStep ? Colors.black : Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            directions[idx],
                            style: TextStyle(
                              color: isCurrentStep ? const Color(0xFF22D3EE) : Colors.white,
                              fontSize: 13,
                              fontWeight: isCurrentStep ? FontWeight.w700 : FontWeight.w400,
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

  Widget _buildUserVehicleCard(Vehicle v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xF20B132B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF06B6D4), width: 1.8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x6606B6D4),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF06B6D4).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.navigation_rounded,
                  color: Color(0xFF22D3EE),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MY ACTIVE JOURNEY',
                      style: TextStyle(
                        color: Color(0xFF22D3EE),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${v.sourceIntersection} → ${v.destinationIntersection}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => _showDirectionsSheet(context, v),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.directions, color: Color(0xFF22D3EE), size: 14),
                      SizedBox(width: 4),
                      Text('Steps', style: TextStyle(color: Color(0xFF22D3EE), fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              InkWell(
                onTap: () async {
                  await widget.repository.endActiveJourney();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Journey completed / ended.')),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.6)),
                  ),
                  child: const Text(
                    'End',
                    style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Current Position Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withOpacity(0.7),
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
              color: const Color(0xFF082F49).withOpacity(0.8),
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

          // Dynamic Reroute Alert Banner if vehicle was rerouted
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (v.diversionInstruction != null)
                          Text(
                            v.diversionInstruction!,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: v.progressFraction,
                    backgroundColor: const Color(0xFF1E293B),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF06B6D4)),
                    minHeight: 5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${(v.progressFraction * 100).toInt()}%',
                style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              Text(
                '${v.speed.toStringAsFixed(0)} km/h',
                style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(Vehicle v) {
    Color typeColor = Colors.blue;
    if (v.type == VehicleType.bus) typeColor = Colors.amber;
    if (v.type == VehicleType.ambulance) typeColor = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xF0111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: typeColor.withOpacity(0.6), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              v.type == VehicleType.bus
                  ? Icons.directions_bus
                  : v.type == VehicleType.ambulance
                      ? Icons.emergency
                      : Icons.directions_car,
              color: typeColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      v.type.displayName.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: v.status == JourneyStatus.waitingAtSignal
                            ? Colors.red.withOpacity(0.3)
                            : Colors.green.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        v.status == JourneyStatus.waitingAtSignal ? 'WAITING AT SIGNAL' : 'MOVING',
                        style: TextStyle(
                          color: v.status == JourneyStatus.waitingAtSignal
                              ? Colors.redAccent
                              : Colors.greenAccent,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Route: ${v.sourceIntersection} → ${v.destinationIntersection}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                Text(
                  '📍 Current: ${v.currentPosition}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10.5, fontWeight: FontWeight.w600),
                ),
                if (v.isRerouted)
                  Text(
                    '⚠️ Rerouted: ${v.rerouteReason ?? "Congestion bypass"}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                Text(
                  'Speed: ${v.speed.toStringAsFixed(0)} km/h | ETA: ${v.eta ?? "--"}',
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => _showDirectionsSheet(context, v),
            child: Container(
              padding: const EdgeInsets.all(6),
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF06B6D4).withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.turn_right_rounded, color: Color(0xFF22D3EE), size: 16),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54, size: 18),
            onPressed: () {
              setState(() {
                _selectedVehicle = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildIntersectionCard(Intersection node) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xF0111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF38BDF8).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.location_on,
              color: Color(0xFF38BDF8),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${node.id}: ${node.name}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  node.landmarkName != null
                      ? 'Landmark: ${node.landmarkName}'
                      : 'Zone: ${node.zone}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                if (node.signals != null && node.signals!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(
                      children: node.signals!.entries.take(4).map((e) {
                        final isGreen = e.value == 'GREEN';
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isGreen ? Colors.green : Colors.red,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                e.key,
                                style: const TextStyle(color: Colors.white54, fontSize: 9),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white54, size: 18),
            onPressed: () {
              setState(() {
                _selectedIntersection = null;
              });
            },
          ),
        ],
      ),
    );
  }
}

/// Custom painter that draws the virtual city roads, intersections, signals, and live vehicles.
class _CityMapPainter extends CustomPainter {
  final List<Intersection> intersections;
  final List<Road> roads;
  final List<Vehicle> vehicles;
  final Vehicle? selectedVehicle;
  final Intersection? selectedIntersection;
  final String? activeUserVehicleId;
  final double pulseValue;

  static const double baseWidth = 1040.0;
  static const double baseHeight = 840.0;
  static const double roadWidth = 34.0;
  static const double junctionSize = 42.0;

  _CityMapPainter({
    required this.intersections,
    required this.roads,
    required this.vehicles,
    this.selectedVehicle,
    this.selectedIntersection,
    this.activeUserVehicleId,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF090D16),
    );

    final scale = math.min(size.width / baseWidth, size.height / baseHeight);
    final offsetX = (size.width - baseWidth * scale) / 2.0;
    final offsetY = (size.height - baseHeight * scale) / 2.0;

    // Subtle Grid
    _drawGrid(canvas, size);

    canvas.save();
    canvas.translate(offsetX, offsetY);
    canvas.scale(scale, scale);

    final nodeMap = {for (var n in intersections) n.id: n};

    // 1. Draw Roads
    for (final road in roads) {
      final a = nodeMap[road.fromId];
      final b = nodeMap[road.toId];
      if (a != null && b != null) {
        _drawRoad(canvas, road, a, b);
      }
    }

    // 2. Draw Active User Vehicle Route OR Selected Vehicle Route
    Vehicle? routeVehicle = selectedVehicle;
    bool isUserRoute = false;
    if (activeUserVehicleId != null) {
      for (final v in vehicles) {
        if (v.id == activeUserVehicleId) {
          routeVehicle = v;
          isUserRoute = true;
          break;
        }
      }
    }

    if (routeVehicle != null) {
      if (routeVehicle.previousRoutePath.length >= 2) {
        _drawDivertedRoutePath(canvas, routeVehicle.previousRoutePath, nodeMap);
      }
      if (routeVehicle.routePath.length >= 2) {
        _drawRoutePath(canvas, routeVehicle.routePath, nodeMap, isUserRoute: isUserRoute);
      }
    }

    // 3. Draw Intersections & Approach Signals
    for (final node in intersections) {
      _drawIntersection(canvas, node, nodeMap);
    }

    // 4. Draw Vehicles
    for (final vehicle in vehicles) {
      if (vehicle.status != JourneyStatus.arrived) {
        final isSelected = selectedVehicle?.id == vehicle.id;
        final isUserVehicle = vehicle.id == activeUserVehicleId;
        _drawVehicle(canvas, vehicle, isSelected, isUserVehicle: isUserVehicle);
      }
    }

    canvas.restore();
  }

  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0x1F1E293B)
      ..strokeWidth = 1.0;

    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  void _drawRoad(Canvas canvas, Road road, Intersection a, Intersection b) {
    final x1 = a.x;
    final y1 = a.y;
    final x2 = b.x;
    final y2 = b.y;

    final dx = x2 - x1;
    final dy = y2 - y1;
    final dist = _hypot(dx, dy);
    if (dist == 0) return;

    final nx = -dy / dist;
    final ny = dx / dist;

    final isClosed = road.condition == 'CLOSED';
    final isCongested = road.condition == 'CONGESTED' || road.congestionLevel == CongestionLevel.heavy;
    final isModerate = road.congestionLevel == CongestionLevel.moderate;

    Color asphalt = road.type == 'DIAGONAL'
        ? const Color(0xFF334155)
        : const Color(0xFF1E293B);

    if (isClosed) {
      asphalt = const Color(0xFF450A0A); // Deep danger red
    } else if (isCongested) {
      asphalt = const Color(0xFF881337); // Heavy traffic crimson
    } else if (isModerate) {
      asphalt = const Color(0xFF78350F); // Moderate amber
    }

    final halfW = roadWidth / 2.0;

    final path = Path()
      ..moveTo(x1 + nx * halfW, y1 + ny * halfW)
      ..lineTo(x2 + nx * halfW, y2 + ny * halfW)
      ..lineTo(x2 - nx * halfW, y2 - ny * halfW)
      ..lineTo(x1 - nx * halfW, y1 - ny * halfW)
      ..close();

    // Road body
    canvas.drawPath(path, Paint()..color = asphalt);

    // If congested, draw pulsing amber warning overlay
    if (isCongested) {
      final pulseAlpha = (120 + 80 * pulseValue).toInt().clamp(0, 255);
      final warningBorder = Paint()
        ..color = Color.fromARGB(pulseAlpha, 239, 68, 68)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, warningBorder);
    }

    // Curb borders
    final curbPaint = Paint()
      ..color = isClosed ? const Color(0xFFDC2626) : const Color(0xFF475569)
      ..strokeWidth = isClosed ? 2.0 : 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(x1 + nx * halfW, y1 + ny * halfW), Offset(x2 + nx * halfW, y2 + ny * halfW), curbPaint);
    canvas.drawLine(Offset(x1 - nx * halfW, y1 - ny * halfW), Offset(x2 - nx * halfW, y2 - ny * halfW), curbPaint);

    // If closed, draw cross hazard barrier
    if (isClosed) {
      final mx = (x1 + x2) / 2.0;
      final my = (y1 + y2) / 2.0;
      final barrierPaint = Paint()
        ..color = const Color(0xFFEF4444)
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(mx - nx * halfW * 0.9, my - ny * halfW * 0.9),
        Offset(mx + nx * halfW * 0.9, my + ny * halfW * 0.9),
        barrierPaint,
      );
    } else {
      // Center lane divider
      final centerPaint = Paint()
        ..color = const Color(0xFFEAB308)
        ..strokeWidth = 1.5;
      _drawDashedLine(canvas, Offset(x1, y1), Offset(x2, y2), centerPaint, 8.0, 6.0);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint, double dashWidth, double dashSpace) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final dist = _hypot(dx, dy);
    final ux = dx / dist;
    final uy = dy / dist;

    double current = 0.0;
    while (current < dist) {
      final start = Offset(p1.dx + ux * current, p1.dy + uy * current);
      final len = math.min(dashWidth, dist - current);
      final end = Offset(start.dx + ux * len, start.dy + uy * len);
      canvas.drawLine(start, end, paint);
      current += dashWidth + dashSpace;
    }
  }

  void _drawRoutePath(Canvas canvas, List<String> path, Map<String, Intersection> nodeMap, {bool isUserRoute = false}) {
    if (path.length < 2) return;

    final glowPaint = Paint()
      ..color = isUserRoute ? const Color(0x9906B6D4) : const Color(0x660EA5E9)
      ..strokeWidth = isUserRoute ? 14.0 : 12.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final corePaint = Paint()
      ..color = isUserRoute ? const Color(0xFF22D3EE) : const Color(0xFF38BDF8)
      ..strokeWidth = isUserRoute ? 4.5 : 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < path.length - 1; i++) {
      final u = nodeMap[path[i]];
      final v = nodeMap[path[i + 1]];
      if (u != null && v != null) {
        canvas.drawLine(Offset(u.x, u.y), Offset(v.x, v.y), glowPaint);
        canvas.drawLine(Offset(u.x, u.y), Offset(v.x, v.y), corePaint);
      }
    }
  }

  void _drawDivertedRoutePath(Canvas canvas, List<String> path, Map<String, Intersection> nodeMap) {
    if (path.length < 2) return;

    final dashedPaint = Paint()
      ..color = const Color(0xFFEF4444).withOpacity(0.65)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = const Color(0x33EF4444)
      ..strokeWidth = 10.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < path.length - 1; i++) {
      final u = nodeMap[path[i]];
      final v = nodeMap[path[i + 1]];
      if (u != null && v != null) {
        canvas.drawLine(Offset(u.x, u.y), Offset(v.x, v.y), glowPaint);
        _drawDashedLine(canvas, Offset(u.x, u.y), Offset(v.x, v.y), dashedPaint, 7.0, 5.0);
      }
    }
  }

  void _drawIntersection(Canvas canvas, Intersection node, Map<String, Intersection> nodeMap) {
    final cx = node.x;
    final cy = node.y;
    final half = junctionSize / 2.0;

    final isSelected = selectedIntersection?.id == node.id;

    // 1. Draw approach stop lines and 3-aspect vertical traffic signal heads
    _drawApproachSignals(canvas, node, nodeMap);

    // Dynamic signal state
    final hasSignals = node.signals != null && node.signals!.isNotEmpty;
    bool hasGreen = false;
    if (hasSignals) {
      hasGreen = node.signals!.values.any((s) => s.toUpperCase() == 'GREEN');
    }

    // Outer glowing signal aura around junction
    if (hasSignals) {
      final sigColor = hasGreen ? const Color(0xFF10B981) : const Color(0xFFEF4444);
      final pulseR = half + 4.5 + 2.0 * pulseValue;
      canvas.drawCircle(
        Offset(cx, cy),
        pulseR,
        Paint()
          ..color = sigColor.withOpacity(0.35 + 0.15 * pulseValue)
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke,
      );
    }

    // Junction box
    final boxRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: junctionSize, height: junctionSize),
      const Radius.circular(9),
    );

    canvas.drawRRect(
      boxRect,
      Paint()..color = isSelected ? const Color(0xFF1E3A8A) : const Color(0xFF0F172A),
    );

    canvas.drawRRect(
      boxRect,
      Paint()
        ..color = isSelected
            ? const Color(0xFF38BDF8)
            : (hasSignals
                ? (hasGreen ? const Color(0xFF059669) : const Color(0xFF7F1D1D))
                : const Color(0xFF475569))
        ..strokeWidth = isSelected ? 2.5 : 1.8
        ..style = PaintingStyle.stroke,
    );

    // Central circular badge
    canvas.drawCircle(
      Offset(cx, cy),
      13.0,
      Paint()..color = isSelected ? const Color(0xFF2563EB) : const Color(0xFF1E293B),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      13.0,
      Paint()
        ..color = isSelected ? const Color(0xFF38BDF8) : const Color(0xFF475569)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke,
    );

    // Node ID Text
    final textPainter = TextPainter(
      text: TextSpan(
        text: node.id,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(cx - textPainter.width / 2, cy - textPainter.height / 2),
    );

    // Landmark indicator badge
    if (node.landmarkName != null) {
      _drawLandmarkBadge(canvas, node, cx, cy - half - 10);
    }
  }

  void _drawApproachSignals(Canvas canvas, Intersection intersection, Map<String, Intersection> nodeMap) {
    final connectedRoads = roads.where((r) => r.fromId == intersection.id || r.toId == intersection.id).toList();
    if (connectedRoads.length <= 1) return;

    final cx = intersection.x;
    final cy = intersection.y;
    final sigMap = intersection.signals;

    for (final road in connectedRoads) {
      final otherId = (road.fromId == intersection.id) ? road.toId : road.fromId;
      final other = nodeMap[otherId];
      if (other == null) continue;

      final dx = other.x - cx;
      final dy = other.y - cy;
      final dist = _hypot(dx, dy);
      if (dist == 0) continue;

      // Unit vector towards oncoming road
      final ux = dx / dist;
      final uy = dy / dist;

      // Perpendicular curb vector pointing towards incoming lane edge
      final curbX = uy;
      final curbY = -ux;

      const double headDist = 34.0;
      const double stopLineDist = 24.0;
      const double lateralOffset = (roadWidth / 2.0) + 7.5;

      final headX = cx + ux * headDist + curbX * lateralOffset;
      final headY = cy + uy * headDist + curbY * lateralOffset;
      final roadAngle = math.atan2(dy, dx);

      // Determine signal color (GREEN, YELLOW, RED)
      String colorStr = 'RED';
      if (sigMap != null && sigMap.containsKey(road.id)) {
        colorStr = sigMap[road.id]!.toUpperCase();
      }

      // 1. Draw Stop Line
      _drawStopLine(canvas, cx, cy, ux, uy, curbX, curbY, stopLineDist);

      // 2. Draw 3-Aspect Traffic Signal Head
      _drawThreeAspectSignalHead(canvas, headX, headY, roadAngle, colorStr);
    }
  }

  void _drawStopLine(Canvas canvas, double cx, double cy, double ux, double uy, double curbX, double curbY, double stopLineDist) {
    final stopCenterX = cx + ux * stopLineDist;
    final stopCenterY = cy + uy * stopLineDist;

    final p1 = Offset(stopCenterX + curbX * 1.5, stopCenterY + curbY * 1.5);
    final p2 = Offset(stopCenterX + curbX * (roadWidth / 2.0), stopCenterY + curbY * (roadWidth / 2.0));

    canvas.drawLine(
      p1,
      p2,
      Paint()
        ..color = const Color(0xFFF8FAFC)
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.square,
    );
  }

  void _drawThreeAspectSignalHead(Canvas canvas, double x, double y, double angle, String activeColor) {
    const double headW = 11.0;
    const double headH = 28.0;
    const double r = 3.0;

    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(angle + math.pi / 2.0);

    // Protective Housing Box
    final housingRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: headW, height: headH),
      const Radius.circular(5),
    );

    canvas.drawRRect(
      housingRect,
      Paint()..color = const Color(0xFF090D16),
    );
    canvas.drawRRect(
      housingRect,
      Paint()
        ..color = const Color(0xFF64748B)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke,
    );

    const double redY = -7.5;
    const double yellowY = 0.0;
    const double greenY = 7.5;

    final isRed = activeColor == 'RED';
    final isYellow = activeColor == 'YELLOW';
    final isGreen = activeColor == 'GREEN';

    // 🔴 Red Lamp (Top)
    if (isRed) {
      canvas.drawCircle(
        const Offset(0, redY),
        r + 2.5 + 1.0 * pulseValue,
        Paint()..color = const Color(0x66EF4444),
      );
      canvas.drawCircle(
        const Offset(0, redY),
        r,
        Paint()..color = const Color(0xFFFF2222),
      );
    } else {
      canvas.drawCircle(
        const Offset(0, redY),
        r,
        Paint()..color = const Color(0xFF450A0A),
      );
    }

    // 🟡 Yellow Lamp (Middle)
    if (isYellow) {
      canvas.drawCircle(
        const Offset(0, yellowY),
        r + 2.5 + 1.0 * pulseValue,
        Paint()..color = const Color(0x66F59E0B),
      );
      canvas.drawCircle(
        const Offset(0, yellowY),
        r,
        Paint()..color = const Color(0xFFFFCC00),
      );
    } else {
      canvas.drawCircle(
        const Offset(0, yellowY),
        r,
        Paint()..color = const Color(0xFF451A03),
      );
    }

    // 🟢 Green Lamp (Bottom)
    if (isGreen) {
      canvas.drawCircle(
        const Offset(0, greenY),
        r + 2.5 + 1.0 * pulseValue,
        Paint()..color = const Color(0x6610B981),
      );
      canvas.drawCircle(
        const Offset(0, greenY),
        r,
        Paint()..color = const Color(0xFF22C55E),
      );
    } else {
      canvas.drawCircle(
        const Offset(0, greenY),
        r,
        Paint()..color = const Color(0xFF064E3B),
      );
    }

    canvas.restore();
  }

  void _drawLandmarkBadge(Canvas canvas, Intersection node, double x, double y) {
    String label = node.id;
    Color badgeColor = const Color(0xFF0284C7);

    if (node.landmarkType == 'HOSPITAL') {
      label = '🏥 Hospital';
      badgeColor = const Color(0xFFEF4444);
    } else if (node.landmarkType == 'RAILWAY_STATION') {
      label = '🚆 Station';
      badgeColor = const Color(0xFFF59E0B);
    } else if (node.landmarkType == 'SHOPPING_MALL') {
      label = '🛍️ Mall';
      badgeColor = const Color(0xFFEC4899);
    } else if (node.landmarkType == 'UNIVERSITY') {
      label = '🎓 University';
      badgeColor = const Color(0xFF8B5CF6);
    } else if (node.landmarkType == 'CITY_CENTER') {
      label = '🏙️ Downtown';
      badgeColor = const Color(0xFF10B981);
    } else if (node.landmarkType == 'TECH_PARK') {
      label = '🏢 Tech Park';
      badgeColor = const Color(0xFF06B6D4);
    }

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(x, y),
        width: tp.width + 10,
        height: tp.height + 4,
      ),
      const Radius.circular(4),
    );

    canvas.drawRRect(badgeRect, Paint()..color = badgeColor);
    tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
  }

  void _drawVehicle(Canvas canvas, Vehicle v, bool isSelected, {bool isUserVehicle = false}) {
    // Distinctive blinking ambulance vehicle symbol
    if (v.type == VehicleType.ambulance) {
      _drawAmbulance(canvas, v, isSelected, isUserVehicle: isUserVehicle);
      return;
    }

    final x = v.x;
    final y = v.y;

    Color vColor = isUserVehicle ? const Color(0xFF06B6D4) : const Color(0xFF38BDF8); // User cyan, car blue
    double vRadius = isUserVehicle ? 9.5 : 7.0;

    if (!isUserVehicle && v.type == VehicleType.bus) {
      vColor = const Color(0xFFF59E0B); // Bus amber
      vRadius = 9.0;
    }

    // If user vehicle: draw animated cyan radar beacon ring
    if (isUserVehicle) {
      final haloRadius = vRadius + 14.0 * pulseValue;
      canvas.drawCircle(
        Offset(x, y),
        haloRadius,
        Paint()
          ..color = const Color(0xFF06B6D4).withOpacity((0.7 - 0.4 * pulseValue).clamp(0.1, 0.7))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
      canvas.drawCircle(
        Offset(x, y),
        vRadius + 4.5,
        Paint()
          ..color = const Color(0xFF22D3EE)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }

    if (isSelected && !isUserVehicle) {
      // Selection ring
      canvas.drawCircle(
        Offset(x, y),
        vRadius + 5.0,
        Paint()
          ..color = const Color(0xFF38BDF8)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke,
      );
    }

    // Shadow
    canvas.drawCircle(
      Offset(x + 1, y + 1.5),
      vRadius,
      Paint()..color = Colors.black54,
    );

    // Vehicle circle body
    canvas.drawCircle(
      Offset(x, y),
      vRadius,
      Paint()..color = vColor,
    );

    // White core / highlight
    canvas.drawCircle(
      Offset(x, y),
      vRadius * 0.45,
      Paint()..color = Colors.white,
    );

    // Vehicle ID / Badge tag
    if (isUserVehicle) {
      final userTagPainter = TextPainter(
        text: const TextSpan(
          text: '★ MY VEHICLE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 8.5,
            fontWeight: FontWeight.w900,
            backgroundColor: Color(0xFF0E7490),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      userTagPainter.paint(
        canvas,
        Offset(x - userTagPainter.width / 2, y - vRadius - 15),
      );
    }
  }

  void _drawAmbulance(Canvas canvas, Vehicle v, bool isSelected, {bool isUserVehicle = false}) {
    final x = v.x;
    final y = v.y;

    // Fast emergency strobe cadence (~190ms cycle, ~5.2Hz realistic strobe flash)
    final now = DateTime.now().millisecondsSinceEpoch;
    final strobePhase = (now ~/ 190) % 2 == 0;
    const strobeRed = Color(0xFFFF1E1E);
    const strobeBlue = Color(0xFF2563EB);

    final leftLightColor = strobePhase ? strobeRed : strobeBlue;
    final rightLightColor = strobePhase ? strobeBlue : strobeRed;

    // 1. Expanding Siren Warning Aura (Pulsing ripple)
    final auraR = 14.0 + 13.0 * pulseValue;
    canvas.drawCircle(
      Offset(x, y),
      auraR,
      Paint()
        ..color = (strobePhase ? const Color(0xFFEF4444) : const Color(0xFF38BDF8))
            .withOpacity((0.45 * (1.0 - pulseValue)).clamp(0.05, 0.45))
        ..style = PaintingStyle.fill,
    );

    // Outer sharp strobe ring (Blinks size & color)
    canvas.drawCircle(
      Offset(x, y),
      14.0 + (strobePhase ? 2.5 : 0.0),
      Paint()
        ..color = (strobePhase ? strobeRed : strobeBlue).withOpacity(0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    if (isSelected) {
      canvas.drawCircle(
        Offset(x, y),
        21.0,
        Paint()
          ..color = const Color(0xFFFBBF24)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
    }

    // 2. Soft Drop Shadow
    final shadowRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(x + 1.2, y + 2.0), width: 23.0, height: 17.0),
      const Radius.circular(5.0),
    );
    canvas.drawRRect(shadowRect, Paint()..color = const Color(0x99000000));

    // 3. Ambulance Body Chassis (White Emergency Van with Red Trim)
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(x, y), width: 23.0, height: 17.0),
      const Radius.circular(5.0),
    );
    // Pure White ambulance body
    canvas.drawRRect(bodyRect, Paint()..color = const Color(0xFFFFFFFF));

    // Outer emergency red chassis border
    canvas.drawRRect(
      bodyRect,
      Paint()
        ..color = const Color(0xFFDC2626)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );

    // Red emergency side accent stripes
    final redStripePaint = Paint()..color = const Color(0xFFEF4444);
    canvas.drawRect(Rect.fromLTWH(x - 11.5, y - 8.5, 2.5, 17.0), redStripePaint);
    canvas.drawRect(Rect.fromLTWH(x + 9.0, y - 8.5, 2.5, 17.0), redStripePaint);

    // 4. Center Red Medical Cross (+)
    final crossPaint = Paint()..color = const Color(0xFFDC2626);
    // Horizontal cross bar
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, y), width: 10.5, height: 3.6),
        const Radius.circular(1.0),
      ),
      crossPaint,
    );
    // Vertical cross bar
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, y), width: 3.6, height: 10.5),
        const Radius.circular(1.0),
      ),
      crossPaint,
    );

    // 5. Blinking Dual Roof Lightbar (Alternating Red / Blue Strobes)
    const double lightY = -8.5;
    // Lightbar bracket bar
    canvas.drawLine(
      Offset(x - 6.5, y + lightY),
      Offset(x + 6.5, y + lightY),
      Paint()
        ..color = const Color(0xFF0F172A)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );

    // Left flashing strobe (with glow halo)
    canvas.drawCircle(
      Offset(x - 5.0, y + lightY),
      4.0,
      Paint()..color = leftLightColor.withOpacity(0.5),
    );
    canvas.drawCircle(
      Offset(x - 5.0, y + lightY),
      2.5,
      Paint()..color = leftLightColor,
    );

    // Right flashing strobe (with glow halo)
    canvas.drawCircle(
      Offset(x + 5.0, y + lightY),
      4.0,
      Paint()..color = rightLightColor.withOpacity(0.5),
    );
    canvas.drawCircle(
      Offset(x + 5.0, y + lightY),
      2.5,
      Paint()..color = rightLightColor,
    );

    // Center white strobe flash
    if (strobePhase) {
      canvas.drawCircle(
        Offset(x, y + lightY),
        1.8,
        Paint()..color = const Color(0xFFFFFFFF),
      );
    }

    // 6. Floating Emergency Badge Tag (Blinking Red / White border)
    final badgeBorderColor = strobePhase ? const Color(0xFFEF4444) : const Color(0xFFFFFFFF);
    final tagText = isUserVehicle ? '🚨 ★ MY AMBULANCE' : '🚨 AMBULANCE (${v.id})';
    final tagPainter = TextPainter(
      text: TextSpan(
        text: tagText,
        style: const TextStyle(
          color: Color(0xFFFEE2E2),
          fontSize: 7.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final badgeWidth = tagPainter.width + 8.0;
    final badgeHeight = tagPainter.height + 3.0;
    final badgeY = y - 19.0;

    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(x, badgeY), width: badgeWidth, height: badgeHeight),
      const Radius.circular(3.5),
    );

    canvas.drawRRect(
      badgeRect,
      Paint()..color = const Color(0xEE450A0A),
    );
    canvas.drawRRect(
      badgeRect,
      Paint()
        ..color = badgeBorderColor
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke,
    );
    tagPainter.paint(
      canvas,
      Offset(x - tagPainter.width / 2.0, badgeY - tagPainter.height / 2.0),
    );
  }

  @override
  bool shouldRepaint(covariant _CityMapPainter old) => true;
}
