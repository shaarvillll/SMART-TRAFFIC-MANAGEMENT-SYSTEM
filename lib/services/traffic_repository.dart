import '../models/vehicle.dart';
import '../models/road.dart';
import '../models/intersection.dart';
import '../models/traffic_state.dart';
import '../models/notification_item.dart';
import '../models/journey_record.dart';

class JourneyCreationResult {
  final bool isSuccess;
  final Vehicle? vehicle;
  final String message;
  final bool isDemoResult;

  const JourneyCreationResult({
    required this.isSuccess,
    this.vehicle,
    required this.message,
    this.isDemoResult = true,
  });
}

abstract class TrafficRepository {
  Stream<TrafficStatistics> get statisticsStream;
  TrafficStatistics get currentStatistics;

  Stream<ConnectionStatus> get connectionStatusStream;
  ConnectionStatus get currentConnectionStatus;

  Stream<List<Vehicle>> get vehiclesStream;
  List<Vehicle> get currentVehicles;

  Stream<List<Intersection>> get intersectionsStream;
  List<Intersection> get availableIntersections;

  Stream<List<Road>> get roadsStream;
  List<Road> get monitoredRoads;

  Stream<List<NotificationItem>> get notificationsStream;
  List<NotificationItem> get currentNotifications;

  // ─── Single-Vehicle User Journey Management ──────────────────────────────
  String? get activeUserVehicleId;
  Vehicle? get activeUserVehicle;
  Stream<Vehicle?> get activeUserVehicleStream;

  List<JourneyRecord> get journeyHistory;
  Stream<List<JourneyRecord>> get journeyHistoryStream;

  Future<void> endActiveJourney();

  Future<JourneyCreationResult> startJourney({
    required VehicleType type,
    required String sourceIntersectionId,
    required String destinationIntersectionId,
  });

  Future<void> simulateCongestion(String action);
  Future<void> setConnectionMode(ConnectionStatus mode);
  Future<void> markNotificationAsRead(String notificationId);
  Future<void> clearAllNotifications();
  Future<void> refresh();
  void dispose();
}
