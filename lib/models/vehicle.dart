enum VehicleType {
  car,
  bus,
  ambulance,
}

extension VehicleTypeExtension on VehicleType {
  String get displayName {
    switch (this) {
      case VehicleType.car:
        return 'Car';
      case VehicleType.bus:
        return 'Bus';
      case VehicleType.ambulance:
        return 'Ambulance (Emergency)';
    }
  }

  String get shortName {
    switch (this) {
      case VehicleType.car:
        return 'Car';
      case VehicleType.bus:
        return 'Bus';
      case VehicleType.ambulance:
        return 'Ambulance';
    }
  }
}

enum JourneyStatus {
  initializing,
  moving,
  waitingAtSignal,
  delayed,
  rerouted,
  arrived,
  failed,
}

extension JourneyStatusExtension on JourneyStatus {
  String get displayName {
    switch (this) {
      case JourneyStatus.initializing:
        return 'Initializing';
      case JourneyStatus.moving:
        return 'Moving';
      case JourneyStatus.waitingAtSignal:
        return 'Waiting at Signal';
      case JourneyStatus.delayed:
        return 'Delayed';
      case JourneyStatus.rerouted:
        return 'Rerouted';
      case JourneyStatus.arrived:
        return 'Arrived';
      case JourneyStatus.failed:
        return 'Failed';
    }
  }
}

class RouteInfo {
  final String currentRoute;
  final String? previousRoute;
  final String? newRoute;
  final String? diversionReason;
  final String? diversionInstruction;
  final DateTime lastUpdateTime;

  const RouteInfo({
    required this.currentRoute,
    this.previousRoute,
    this.newRoute,
    this.diversionReason,
    this.diversionInstruction,
    required this.lastUpdateTime,
  });

  bool get isRerouted => (previousRoute != null && previousRoute != currentRoute) || (diversionReason != null && diversionReason!.isNotEmpty);
}

class Vehicle {
  final String id;
  final VehicleType type;
  final String sourceIntersection;
  final String destinationIntersection;
  final String currentPosition;
  final JourneyStatus status;
  final RouteInfo routeInfo;
  final String? eta;
  final String? remainingDistance;
  final double progressFraction; // 0.0 to 1.0
  final double x;
  final double y;
  final double speed;
  final List<String> routePath;
  final List<String> previousRoutePath;
  final String? currentInstruction;
  final List<String> directions;
  final int rerouteCount;

  const Vehicle({
    required this.id,
    required this.type,
    required this.sourceIntersection,
    required this.destinationIntersection,
    required this.currentPosition,
    required this.status,
    required this.routeInfo,
    this.eta,
    this.remainingDistance,
    this.progressFraction = 0.0,
    this.x = 0.0,
    this.y = 0.0,
    this.speed = 0.0,
    this.routePath = const [],
    this.previousRoutePath = const [],
    this.currentInstruction,
    this.directions = const [],
    this.rerouteCount = 0,
  });

  Vehicle copyWith({
    String? id,
    VehicleType? type,
    String? sourceIntersection,
    String? destinationIntersection,
    String? currentPosition,
    JourneyStatus? status,
    RouteInfo? routeInfo,
    String? eta,
    String? remainingDistance,
    double? progressFraction,
    double? x,
    double? y,
    double? speed,
    List<String>? routePath,
    List<String>? previousRoutePath,
    String? currentInstruction,
    List<String>? directions,
    int? rerouteCount,
  }) {
    return Vehicle(
      id: id ?? this.id,
      type: type ?? this.type,
      sourceIntersection: sourceIntersection ?? this.sourceIntersection,
      destinationIntersection: destinationIntersection ?? this.destinationIntersection,
      currentPosition: currentPosition ?? this.currentPosition,
      status: status ?? this.status,
      routeInfo: routeInfo ?? this.routeInfo,
      eta: eta ?? this.eta,
      remainingDistance: remainingDistance ?? this.remainingDistance,
      progressFraction: progressFraction ?? this.progressFraction,
      x: x ?? this.x,
      y: y ?? this.y,
      speed: speed ?? this.speed,
      routePath: routePath ?? this.routePath,
      previousRoutePath: previousRoutePath ?? this.previousRoutePath,
      currentInstruction: currentInstruction ?? this.currentInstruction,
      directions: directions ?? this.directions,
      rerouteCount: rerouteCount ?? this.rerouteCount,
    );
  }

  bool get isRerouted => routeInfo.isRerouted || previousRoutePath.isNotEmpty || rerouteCount > 0;
  String? get rerouteReason => routeInfo.diversionReason;
  String? get diversionInstruction => routeInfo.diversionInstruction;
}
