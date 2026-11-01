class Intersection {
  final String id;
  final String name;
  final String zone;
  final double x;
  final double y;
  final String? landmarkType;
  final String? landmarkName;
  final String? landmarkIcon;
  final Map<String, String>? signals; // roadId -> GREEN/YELLOW/RED

  const Intersection({
    required this.id,
    required this.name,
    required this.zone,
    this.x = 0.0,
    this.y = 0.0,
    this.landmarkType,
    this.landmarkName,
    this.landmarkIcon,
    this.signals,
  });

  Intersection copyWith({
    String? id,
    String? name,
    String? zone,
    double? x,
    double? y,
    String? landmarkType,
    String? landmarkName,
    String? landmarkIcon,
    Map<String, String>? signals,
  }) {
    return Intersection(
      id: id ?? this.id,
      name: name ?? this.name,
      zone: zone ?? this.zone,
      x: x ?? this.x,
      y: y ?? this.y,
      landmarkType: landmarkType ?? this.landmarkType,
      landmarkName: landmarkName ?? this.landmarkName,
      landmarkIcon: landmarkIcon ?? this.landmarkIcon,
      signals: signals ?? this.signals,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Intersection && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
