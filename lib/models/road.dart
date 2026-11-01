enum CongestionLevel {
  low,
  moderate,
  heavy,
}

extension CongestionLevelExtension on CongestionLevel {
  String get label {
    switch (this) {
      case CongestionLevel.low:
        return 'Low Congestion';
      case CongestionLevel.moderate:
        return 'Moderate Congestion';
      case CongestionLevel.heavy:
        return 'Heavy Congestion';
    }
  }
}

class Road {
  final String id;
  final String name;
  final CongestionLevel congestionLevel;
  final int vehicleCount;
  final double averageSpeedKmH;
  final String fromId;
  final String toId;
  final double length;
  final String type; // MAIN_GRID, DIAGONAL
  final String condition; // NORMAL, CONGESTED, CLOSED

  const Road({
    required this.id,
    required this.name,
    required this.congestionLevel,
    required this.vehicleCount,
    required this.averageSpeedKmH,
    this.fromId = '',
    this.toId = '',
    this.length = 0.0,
    this.type = 'MAIN_GRID',
    this.condition = 'NORMAL',
  });

  Road copyWith({
    String? id,
    String? name,
    CongestionLevel? congestionLevel,
    int? vehicleCount,
    double? averageSpeedKmH,
    String? fromId,
    String? toId,
    double? length,
    String? type,
    String? condition,
  }) {
    return Road(
      id: id ?? this.id,
      name: name ?? this.name,
      congestionLevel: congestionLevel ?? this.congestionLevel,
      vehicleCount: vehicleCount ?? this.vehicleCount,
      averageSpeedKmH: averageSpeedKmH ?? this.averageSpeedKmH,
      fromId: fromId ?? this.fromId,
      toId: toId ?? this.toId,
      length: length ?? this.length,
      type: type ?? this.type,
      condition: condition ?? this.condition,
    );
  }
}
