import 'package:flutter/material.dart';
import '../models/vehicle.dart';
import '../models/intersection.dart';
import '../services/traffic_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/connection_status.dart';

class JourneyScreen extends StatefulWidget {
  final TrafficRepository repository;

  const JourneyScreen({
    super.key,
    required this.repository,
  });

  @override
  State<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends State<JourneyScreen> {
  final _formKey = GlobalKey<FormState>();

  VehicleType _selectedType = VehicleType.car;
  Intersection? _selectedSource;
  Intersection? _selectedDestination;

  bool _isSubmitting = false;
  JourneyCreationResult? _lastResult;

  @override
  Widget build(BuildContext context) {
    final intersections = widget.repository.availableIntersections;
    final activeVehicle = widget.repository.activeUserVehicle;
    final hasActive = activeVehicle != null && activeVehicle.status != JourneyStatus.arrived;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Start Journey'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Notice Banner
              DemoModeNoticeBanner(repository: widget.repository),
              const SizedBox(height: 20),

              if (hasActive) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0x22F59E0B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_clock, color: Color(0xFFF59E0B), size: 28),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Active Journey in Transit',
                              style: TextStyle(
                                color: Color(0xFFF59E0B),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Your vehicle is currently travelling to ${activeVehicle.destinationIntersection}. Only 1 active journey is allowed. Please wait until arrival or cancel it to start a new one.',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Form Description Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.darkSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.alt_route_rounded,
                      color: AppColors.primaryBlue,
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dispatch New Transit Vehicle',
                            style: TextStyle(
                              color: AppColors.textPrimaryDark,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Select vehicle type and route endpoints. Validates rules before simulator handoff.',
                            style: TextStyle(
                              color: AppColors.textSecondaryDark,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Field 1: Vehicle Type Selection
              const Text(
                'VEHICLE TYPE',
                style: TextStyle(
                  color: AppColors.textMutedDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildTypeChoice(
                    type: VehicleType.car,
                    label: 'Car',
                    icon: Icons.directions_car,
                  ),
                  const SizedBox(width: 10),
                  _buildTypeChoice(
                    type: VehicleType.bus,
                    label: 'Bus',
                    icon: Icons.directions_bus,
                  ),
                  const SizedBox(width: 10),
                  _buildTypeChoice(
                    type: VehicleType.ambulance,
                    label: 'Ambulance',
                    icon: Icons.emergency,
                    isEmergency: true,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Field 2: Starting Intersection
              const Text(
                'STARTING INTERSECTION',
                style: TextStyle(
                  color: AppColors.textMutedDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<Intersection>(
                value: _selectedSource,
                hint: const Text('Select Origin Intersection'),
                isExpanded: true,
                dropdownColor: AppColors.darkSurfaceElevated,
                items: intersections.map((intersection) {
                  return DropdownMenuItem<Intersection>(
                    value: intersection,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.trip_origin,
                          size: 16,
                          color: AppColors.trafficGreen,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${intersection.name} (${intersection.zone})',
                            style: const TextStyle(fontSize: 13.5),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                validator: (val) {
                  if (val == null) {
                    return 'Please select a starting intersection';
                  }
                  return null;
                },
                onChanged: (val) {
                  setState(() {
                    _selectedSource = val;
                  });
                },
              ),

              const SizedBox(height: 20),

              // Field 3: Destination Intersection
              const Text(
                'DESTINATION INTERSECTION',
                style: TextStyle(
                  color: AppColors.textMutedDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<Intersection>(
                value: _selectedDestination,
                hint: const Text('Select Destination Intersection'),
                isExpanded: true,
                dropdownColor: AppColors.darkSurfaceElevated,
                items: intersections.map((intersection) {
                  return DropdownMenuItem<Intersection>(
                    value: intersection,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 16,
                          color: AppColors.trafficRed,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${intersection.name} (${intersection.zone})',
                            style: const TextStyle(fontSize: 13.5),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                validator: (val) {
                  if (val == null) {
                    return 'Please select a destination intersection';
                  }
                  if (_selectedSource != null && val.id == _selectedSource!.id) {
                    return 'Source and destination must differ';
                  }
                  return null;
                },
                onChanged: (val) {
                  setState(() {
                    _selectedDestination = val;
                  });
                },
              ),

              const SizedBox(height: 28),

              // Submit Button with duplicate prevention
              ElevatedButton(
                onPressed: (hasActive || _isSubmitting) ? null : _submitJourney,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  disabledBackgroundColor: hasActive
                      ? Colors.grey.withOpacity(0.2)
                      : AppColors.primaryBlue.withOpacity(0.4),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Color(0xFF090D16),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Verifying & Dispatching...',
                            style: TextStyle(
                              color: Color(0xFF090D16),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      )
                    : hasActive
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.lock_outline, color: Colors.white54),
                              SizedBox(width: 8),
                              Text(
                                'Active Journey Running (Locked)',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.play_arrow_rounded, color: Color(0xFF090D16)),
                              SizedBox(width: 8),
                              Text(
                                'Confirm & Start Journey',
                                style: TextStyle(
                                  color: Color(0xFF090D16),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
              ),

              // Demo Result Section (Clearly Labelled)
              if (_lastResult != null) ...[
                const SizedBox(height: 24),
                _buildDemoResultCard(_lastResult!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChoice({
    required VehicleType type,
    required String label,
    required IconData icon,
    bool isEmergency = false,
  }) {
    final isSelected = _selectedType == type;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedType = type;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? (isEmergency
                    ? AppColors.trafficRed.withOpacity(0.18)
                    : AppColors.primaryBlue.withOpacity(0.18))
                : AppColors.darkSurfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? (isEmergency ? AppColors.trafficRed : AppColors.primaryBlue)
                  : AppColors.darkBorder,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? (isEmergency ? AppColors.trafficRed : AppColors.primaryBlue)
                    : AppColors.textSecondaryDark,
                size: 24,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.textPrimaryDark
                      : AppColors.textSecondaryDark,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDemoResultCard(JourneyCreationResult result) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondaryTeal.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.secondaryTeal.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.secondaryTeal,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DEMO JOURNEY INITIATED',
                      style: TextStyle(
                        color: AppColors.secondaryTeal,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Sample Record Generated (No External Sim Connected)',
                      style: TextStyle(
                        color: AppColors.textMutedDark,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            result.message,
            style: const TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          if (result.vehicle != null) ...[
            const SizedBox(height: 10),
            Text(
              'Route Assigned: ${result.vehicle!.routeInfo.currentRoute}',
              style: const TextStyle(
                color: AppColors.primaryBlue,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Return to Dashboard'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submitJourney() async {
    // Prevent duplicate submissions
    if (_isSubmitting) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final res = await widget.repository.startJourney(
        type: _selectedType,
        sourceIntersectionId: _selectedSource!.id,
        destinationIntersectionId: _selectedDestination!.id,
      );

      if (mounted) {
        if (res.isSuccess) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Journey Started! Vehicle is now active on the map.',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          setState(() {
            _lastResult = res;
            _isSubmitting = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.message),
              backgroundColor: AppColors.trafficRed,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting journey: $e'),
            backgroundColor: AppColors.trafficRed,
          ),
        );
      }
    }
  }
}
