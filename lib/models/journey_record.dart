import 'vehicle.dart';

class JourneyRecord {
  final String id;
  final String vehicleId;
  final VehicleType vehicleType;
  final String sourceIntersectionId;
  final String sourceIntersectionName;
  final String destinationIntersectionId;
  final String destinationIntersectionName;
  final DateTime startTime;
  final DateTime? endTime;
  final double durationSeconds;
  final double waitTimeSeconds;
  final double distanceMeters;
  final String status; // 'In Progress', 'Completed', 'Cancelled'
  final List<String> routePath;

  const JourneyRecord({
    required this.id,
    required this.vehicleId,
    required this.vehicleType,
    required this.sourceIntersectionId,
    required this.sourceIntersectionName,
    required this.destinationIntersectionId,
    required this.destinationIntersectionName,
    required this.startTime,
    this.endTime,
    this.durationSeconds = 0.0,
    this.waitTimeSeconds = 0.0,
    this.distanceMeters = 0.0,
    this.status = 'In Progress',
    this.routePath = const [],
  });

  JourneyRecord copyWith({
    String? id,
    String? vehicleId,
    VehicleType? vehicleType,
    String? sourceIntersectionId,
    String? sourceIntersectionName,
    String? destinationIntersectionId,
    String? destinationIntersectionName,
    DateTime? startTime,
    DateTime? endTime,
    double? durationSeconds,
    double? waitTimeSeconds,
    double? distanceMeters,
    String? status,
    List<String>? routePath,
  }) {
    return JourneyRecord(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      vehicleType: vehicleType ?? this.vehicleType,
      sourceIntersectionId: sourceIntersectionId ?? this.sourceIntersectionId,
      sourceIntersectionName: sourceIntersectionName ?? this.sourceIntersectionName,
      destinationIntersectionId: destinationIntersectionId ?? this.destinationIntersectionId,
      destinationIntersectionName: destinationIntersectionName ?? this.destinationIntersectionName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      waitTimeSeconds: waitTimeSeconds ?? this.waitTimeSeconds,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      status: status ?? this.status,
      routePath: routePath ?? this.routePath,
    );
  }
}
