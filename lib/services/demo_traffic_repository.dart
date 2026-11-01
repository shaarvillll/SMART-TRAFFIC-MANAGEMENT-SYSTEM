import 'dart:async';
import '../models/vehicle.dart';
import '../models/road.dart';
import '../models/intersection.dart';
import '../models/traffic_state.dart';
import '../models/notification_item.dart';
import '../models/journey_record.dart';
import 'traffic_repository.dart';

class DemoTrafficRepository implements TrafficRepository {
  ConnectionStatus _connectionStatus = ConnectionStatus.demoMode;

  final _statisticsController = StreamController<TrafficStatistics>.broadcast();
  final _connectionStatusController = StreamController<ConnectionStatus>.broadcast();
  final _vehiclesController = StreamController<List<Vehicle>>.broadcast();
  final _notificationsController = StreamController<List<NotificationItem>>.broadcast();
  final _activeUserVehicleController = StreamController<Vehicle?>.broadcast();
  final _journeyHistoryController = StreamController<List<JourneyRecord>>.broadcast();

  String? _activeUserVehicleId;
  final List<JourneyRecord> _journeyHistory = [];

  final List<Intersection> _intersections = const [
    Intersection(id: 'J1', name: 'Central Railway Station', zone: 'Sector 1 (Transit)', x: 160.0, y: 140.0, landmarkType: 'RAILWAY_STATION', landmarkName: 'Central Railway Station', landmarkIcon: 'RS'),
    Intersection(id: 'J2', name: 'North Medical Center', zone: 'Sector 2 (Medical)', x: 510.0, y: 140.0, landmarkType: 'HOSPITAL', landmarkName: 'North Medical Center', landmarkIcon: 'HP'),
    Intersection(id: 'J3', name: 'Northeast Tech Park', zone: 'Sector 3 (IT Hub)', x: 860.0, y: 140.0, landmarkType: 'TECH_PARK', landmarkName: 'Northeast Tech Park', landmarkIcon: 'TP'),
    Intersection(id: 'J4', name: 'West District Hub', zone: 'Sector 4 (Commercial)', x: 160.0, y: 420.0),
    Intersection(id: 'J5', name: 'Civic Park Junction', zone: 'Sector 5 (Civic)', x: 450.0, y: 400.0),
    Intersection(id: 'J6', name: 'Downtown City Center', zone: 'Sector 6 (Downtown)', x: 750.0, y: 400.0, landmarkType: 'CITY_CENTER', landmarkName: 'Downtown City Center', landmarkIcon: 'CC'),
    Intersection(id: 'J7', name: 'East Industrial Link', zone: 'Sector 7 (Industrial)', x: 890.0, y: 470.0),
    Intersection(id: 'J8', name: 'Metro University Campus', zone: 'Sector 8 (Education)', x: 240.0, y: 710.0, landmarkType: 'UNIVERSITY', landmarkName: 'Metro State University', landmarkIcon: 'UN'),
    Intersection(id: 'J9', name: 'South Commercial Hub', zone: 'Sector 9 (Business)', x: 560.0, y: 680.0),
    Intersection(id: 'J10', name: 'Grand Galleria Mall', zone: 'Sector 10 (Retail)', x: 860.0, y: 710.0, landmarkType: 'SHOPPING_MALL', landmarkName: 'Grand Galleria Mall', landmarkIcon: 'SM'),
  ];

  final List<Road> _monitoredRoads = const [
    Road(id: 'R1', name: 'North Boulevard West', fromId: 'J1', toId: 'J2', congestionLevel: CongestionLevel.low, vehicleCount: 14, averageSpeedKmH: 55.0, length: 350.0),
    Road(id: 'R2', name: 'North Boulevard East', fromId: 'J2', toId: 'J3', congestionLevel: CongestionLevel.low, vehicleCount: 10, averageSpeedKmH: 52.0, length: 350.0),
    Road(id: 'R3', name: 'Station South Approach', fromId: 'J1', toId: 'J4', congestionLevel: CongestionLevel.low, vehicleCount: 8, averageSpeedKmH: 48.0, length: 280.0),
    Road(id: 'R4', name: 'University West Link', fromId: 'J4', toId: 'J8', congestionLevel: CongestionLevel.low, vehicleCount: 12, averageSpeedKmH: 45.0, length: 300.0),
    Road(id: 'R5', name: 'Station Avenue East', fromId: 'J4', toId: 'J5', congestionLevel: CongestionLevel.moderate, vehicleCount: 22, averageSpeedKmH: 34.0, length: 290.0),
    Road(id: 'R6', name: 'Civic Park Connector', fromId: 'J2', toId: 'J5', congestionLevel: CongestionLevel.low, vehicleCount: 9, averageSpeedKmH: 50.0, length: 266.0),
    Road(id: 'R8', name: 'Metro Central Boulevard', fromId: 'J5', toId: 'J6', congestionLevel: CongestionLevel.heavy, vehicleCount: 38, averageSpeedKmH: 18.0, length: 300.0),
    Road(id: 'R9', name: 'East Commercial Ave', fromId: 'J6', toId: 'J7', congestionLevel: CongestionLevel.moderate, vehicleCount: 16, averageSpeedKmH: 32.0, length: 156.0),
    Road(id: 'R10_D', name: 'Hospital Express Bypass', fromId: 'J2', toId: 'J6', congestionLevel: CongestionLevel.low, vehicleCount: 6, averageSpeedKmH: 60.0, length: 353.0, type: 'DIAGONAL'),
    Road(id: 'R12_D', name: 'Northeast Industrial Link', fromId: 'J3', toId: 'J7', congestionLevel: CongestionLevel.low, vehicleCount: 5, averageSpeedKmH: 58.0, length: 331.0, type: 'DIAGONAL'),
    Road(id: 'R13', name: 'University Ring Road', fromId: 'J8', toId: 'J9', congestionLevel: CongestionLevel.low, vehicleCount: 11, averageSpeedKmH: 48.0, length: 321.0),
    Road(id: 'R14', name: 'Midtown South Link', fromId: 'J5', toId: 'J8', congestionLevel: CongestionLevel.low, vehicleCount: 7, averageSpeedKmH: 46.0, length: 374.0),
    Road(id: 'R15', name: 'Downtown South Parkway', fromId: 'J6', toId: 'J9', congestionLevel: CongestionLevel.moderate, vehicleCount: 20, averageSpeedKmH: 30.0, length: 338.0),
    Road(id: 'R16', name: 'Galleria Mall Boulevard', fromId: 'J9', toId: 'J10', congestionLevel: CongestionLevel.heavy, vehicleCount: 32, averageSpeedKmH: 20.0, length: 301.0),
    Road(id: 'R17', name: 'Terminal East Highway', fromId: 'J7', toId: 'J10', congestionLevel: CongestionLevel.low, vehicleCount: 15, averageSpeedKmH: 54.0, length: 241.0),
  ];

  late List<Vehicle> _vehicles;
  late List<NotificationItem> _notifications;
  int _demoCounter = 105;

  DemoTrafficRepository() {
    _initSampleData();
  }

  void _initSampleData() {
    final now = DateTime.now();

    _vehicles = [
      Vehicle(
        id: 'DEMO-AMB-101',
        type: VehicleType.ambulance,
        sourceIntersection: 'Civic Hospital Square',
        destinationIntersection: 'Metro Plaza Crossroads',
        currentPosition: 'On Hospital Lane • 120m to Central Square',
        status: JourneyStatus.rerouted,
        routeInfo: RouteInfo(
          currentRoute: 'Hospital Lane -> Tech Park By-Pass -> Metro Plaza',
          previousRoute: 'Hospital Lane -> Central Commercial Blvd -> Metro Plaza',
          newRoute: 'Hospital Lane -> Tech Park By-Pass -> Metro Plaza',
          diversionReason: 'Congestion detected on Central Commercial Blvd (Queue: 9 vehicles)',
          diversionInstruction: 'Detour onto Tech Park By-Pass to maintain emergency corridor response time.',
          lastUpdateTime: now.subtract(const Duration(minutes: 3)),
        ),
        currentInstruction: 'In 120m, turn right onto Tech Park By-Pass (Congestion Detour)',
        directions: const [
          '1. Depart Civic Hospital Square (J3)',
          '2. Proceed 280m along Hospital Lane to Central Square (J2)',
          '3. Turn right onto Tech Park By-Pass (360m) avoiding Central Blvd delay',
          '4. Arrive at Metro Plaza Crossroads (J6)'
        ],
        routePath: const ['J3', 'J2', 'J5', 'J6'],
        previousRoutePath: const ['J3', 'J2', 'J6'],
        rerouteCount: 1,
        eta: '4 mins',
        remainingDistance: '2.1 km',
        progressFraction: 0.65,
      ),
      Vehicle(
        id: 'DEMO-BUS-204',
        type: VehicleType.bus,
        sourceIntersection: 'East University Boulevard',
        destinationIntersection: 'South Ring Interchange',
        currentPosition: 'Stopped at Signal at Tech Park Central Junction',
        status: JourneyStatus.waitingAtSignal,
        routeInfo: RouteInfo(
          currentRoute: 'East Blvd -> Tech Park Central -> South Ring Rd',
          diversionReason: null,
          lastUpdateTime: now.subtract(const Duration(minutes: 7)),
        ),
        currentInstruction: 'Wait for green signal at Tech Park Central Junction',
        directions: const [
          '1. Depart East University Boulevard (J8)',
          '2. Proceed 420m along East Blvd to Tech Park Central (J9)',
          '3. Continue 380m onto South Ring Road to South Ring Interchange (J10)',
          '4. Arrive at South Ring Interchange (J10)'
        ],
        routePath: const ['J8', 'J9', 'J10'],
        eta: '12 mins',
        remainingDistance: '5.4 km',
        progressFraction: 0.40,
      ),
      Vehicle(
        id: 'DEMO-CAR-312',
        type: VehicleType.car,
        sourceIntersection: 'North Gateway Junction',
        destinationIntersection: 'Tech Park Central Circle',
        currentPosition: 'On Expressway 101 • 190m to Tech Park Central',
        status: JourneyStatus.moving,
        routeInfo: RouteInfo(
          currentRoute: 'North Gateway -> Expressway 101 -> Tech Park Circle',
          diversionReason: null,
          lastUpdateTime: now.subtract(const Duration(minutes: 1)),
        ),
        currentInstruction: 'Continue 190m along Expressway 101 towards Tech Park Central',
        directions: const [
          '1. Depart North Gateway Junction (J1)',
          '2. Continue 510m along Expressway 101 towards Sector Interchange (J4)',
          '3. Follow connector road 320m to Tech Park Central (J9)',
          '4. Arrive at Tech Park Central Circle (J9)'
        ],
        routePath: const ['J1', 'J4', 'J9'],
        eta: '8 mins',
        remainingDistance: '3.8 km',
        progressFraction: 0.52,
      ),
      Vehicle(
        id: 'DEMO-CAR-428',
        type: VehicleType.car,
        sourceIntersection: 'Metro Plaza Crossroads',
        destinationIntersection: 'South Ring Interchange',
        currentPosition: 'On Commercial Core Link • 85m to South Interchange',
        status: JourneyStatus.delayed,
        routeInfo: RouteInfo(
          currentRoute: 'Metro Plaza -> Downtown Corridor -> South Interchange',
          diversionReason: 'High bottleneck at intersection gridlock',
          diversionInstruction: 'Slow down and prepare for stop-and-go queue.',
          lastUpdateTime: now.subtract(const Duration(minutes: 10)),
        ),
        currentInstruction: 'Proceed with caution: Congestion queue ahead (85m)',
        directions: const [
          '1. Depart Metro Plaza Crossroads (J6)',
          '2. Continue 340m on Downtown Corridor to South Interchange (J10)',
          '3. Arrive at South Ring Interchange (J10)'
        ],
        routePath: const ['J6', 'J10'],
        eta: '22 mins',
        remainingDistance: '4.6 km',
        progressFraction: 0.28,
      ),
      Vehicle(
        id: 'DEMO-BUS-108',
        type: VehicleType.bus,
        sourceIntersection: 'South Ring Interchange',
        destinationIntersection: 'Civic Hospital Square',
        currentPosition: 'Arrived at Destination: Civic Hospital Square (J3)',
        status: JourneyStatus.arrived,
        routeInfo: RouteInfo(
          currentRoute: 'South Ring -> Central Flyover -> Hospital Square',
          diversionReason: null,
          lastUpdateTime: now.subtract(const Duration(minutes: 15)),
        ),
        currentInstruction: 'Trip Completed - You have arrived at Civic Hospital Square',
        directions: const [
          '1. Depart South Ring Interchange (J10)',
          '2. Take Central Flyover (580m) to Market Square (J2)',
          '3. Continue 280m on Hospital Lane to Civic Hospital Square (J3)',
          '4. Arrive at Civic Hospital Square (J3)'
        ],
        routePath: const ['J10', 'J2', 'J3'],
        eta: '0 mins',
        remainingDistance: '0.0 km',
        progressFraction: 1.0,
      ),
    ];

    _notifications = [
      NotificationItem(
        id: 'NOTIF-01',
        title: 'Emergency Priority Reroute',
        message: 'Ambulance DEMO-AMB-101 rerouted via Tech Park By-Pass to bypass congestion.',
        timestamp: now.subtract(const Duration(minutes: 3)),
        type: NotificationType.routeChanged,
      ),
      NotificationItem(
        id: 'NOTIF-02',
        title: 'Signal Wait Queue Alert',
        message: 'Bus DEMO-BUS-204 queued at Tech Park Central red phase (est. 45s cycle).',
        timestamp: now.subtract(const Duration(minutes: 7)),
        type: NotificationType.trafficDelay,
      ),
      NotificationItem(
        id: 'NOTIF-03',
        title: 'Journey Successfully Completed',
        message: 'Bus DEMO-BUS-108 completed scheduled transit run to Civic Hospital Square.',
        timestamp: now.subtract(const Duration(minutes: 15)),
        type: NotificationType.journeyCompleted,
      ),
      NotificationItem(
        id: 'NOTIF-04',
        title: 'Demo Environment Active',
        message: 'Intelligent Traffic Management initialized in offline sample demo mode.',
        timestamp: now.subtract(const Duration(hours: 1)),
        type: NotificationType.connectionStatusChanged,
      ),
    ];
  }

  @override
  Stream<TrafficStatistics> get statisticsStream => _statisticsController.stream;

  @override
  TrafficStatistics get currentStatistics {
    final active = _vehicles.where((v) => v.status != JourneyStatus.arrived && v.status != JourneyStatus.failed).length;
    final moving = _vehicles.where((v) => v.status == JourneyStatus.moving).length;
    final waiting = _vehicles.where((v) => v.status == JourneyStatus.waitingAtSignal).length;
    final arrived = _vehicles.where((v) => v.status == JourneyStatus.arrived).length;
    final rerouted = _vehicles.where((v) => v.status == JourneyStatus.rerouted || v.routeInfo.isRerouted).length;
    final congestedCount = _monitoredRoads.where((r) => r.congestionLevel == CongestionLevel.heavy).length;

    return TrafficStatistics(
      activeVehicles: active,
      congestedRoads: congestedCount,
      movingVehicles: moving,
      waitingAtSignals: waiting,
      completedJourneys: arrived,
      routeDiversions: rerouted,
      overallCondition: OverallTrafficCondition.moderate,
      networkEfficiencyPercent: 78.4,
    );
  }

  @override
  Stream<ConnectionStatus> get connectionStatusStream => _connectionStatusController.stream;

  @override
  ConnectionStatus get currentConnectionStatus => _connectionStatus;

  @override
  Stream<List<Vehicle>> get vehiclesStream => _vehiclesController.stream;

  @override
  List<Vehicle> get currentVehicles => List.unmodifiable(_vehicles);

  @override
  Stream<List<Intersection>> get intersectionsStream => Stream.value(_intersections);

  @override
  List<Intersection> get availableIntersections => _intersections;

  @override
  Stream<List<Road>> get roadsStream => Stream.value(_monitoredRoads);

  @override
  List<Road> get monitoredRoads => _monitoredRoads;

  @override
  Stream<List<NotificationItem>> get notificationsStream => _notificationsController.stream;

  @override
  List<NotificationItem> get currentNotifications => List.unmodifiable(_notifications);

  @override
  String? get activeUserVehicleId => _activeUserVehicleId;

  @override
  Vehicle? get activeUserVehicle {
    if (_activeUserVehicleId == null) return null;
    for (final v in _vehicles) {
      if (v.id == _activeUserVehicleId) return v;
    }
    return null;
  }

  @override
  Stream<Vehicle?> get activeUserVehicleStream => _activeUserVehicleController.stream;

  @override
  List<JourneyRecord> get journeyHistory => List.unmodifiable(_journeyHistory);

  @override
  Stream<List<JourneyRecord>> get journeyHistoryStream => _journeyHistoryController.stream;

  @override
  Future<void> endActiveJourney() async {
    if (_activeUserVehicleId != null) {
      final index = _journeyHistory.indexWhere(
        (r) => r.vehicleId == _activeUserVehicleId && r.status == 'In Progress',
      );
      if (index != -1) {
        final prev = _journeyHistory[index];
        final dur = DateTime.now().difference(prev.startTime).inMilliseconds / 1000.0;
        _journeyHistory[index] = prev.copyWith(
          status: 'Cancelled',
          endTime: DateTime.now(),
          durationSeconds: dur,
        );
        _journeyHistoryController.add(List.unmodifiable(_journeyHistory));
      }
      _activeUserVehicleId = null;
      _activeUserVehicleController.add(null);
    }
  }

  @override
  Future<JourneyCreationResult> startJourney({
    required VehicleType type,
    required String sourceIntersectionId,
    required String destinationIntersectionId,
  }) async {
    if (activeUserVehicle != null && activeUserVehicle!.status != JourneyStatus.arrived) {
      return JourneyCreationResult(
        isSuccess: false,
        message: 'You already have an active journey with vehicle ${activeUserVehicle!.id} in transit. You can start a new journey once it completes.',
        isDemoResult: true,
      );
    }

    // Artificial latency for realistic async interaction
    await Future.delayed(const Duration(milliseconds: 600));

    final sourceIntersection = _intersections.firstWhere(
      (i) => i.id == sourceIntersectionId,
      orElse: () => Intersection(id: sourceIntersectionId, name: sourceIntersectionId, zone: ''),
    );
    final destinationIntersection = _intersections.firstWhere(
      (i) => i.id == destinationIntersectionId,
      orElse: () => Intersection(id: destinationIntersectionId, name: destinationIntersectionId, zone: ''),
    );

    _demoCounter++;
    final prefix = type == VehicleType.ambulance
        ? 'AMB'
        : type == VehicleType.bus
            ? 'BUS'
            : 'CAR';
    final newId = 'DEMO-$prefix-$_demoCounter';

    final initialRoute = '${sourceIntersection.name} -> Transit Sector Link -> ${destinationIntersection.name}';
    final now = DateTime.now();

    final newVehicle = Vehicle(
      id: newId,
      type: type,
      sourceIntersection: sourceIntersection.name,
      destinationIntersection: destinationIntersection.name,
      currentPosition: 'Departing ${sourceIntersection.name}',
      status: JourneyStatus.initializing,
      routeInfo: RouteInfo(
        currentRoute: initialRoute,
        diversionReason: null,
        lastUpdateTime: now,
      ),
      eta: '10 mins (Simulated)',
      remainingDistance: '4.2 km (Simulated)',
      progressFraction: 0.05,
      routePath: [sourceIntersectionId, destinationIntersectionId],
    );

    _activeUserVehicleId = newId;
    _activeUserVehicleController.add(newVehicle);

    final record = JourneyRecord(
      id: 'TRIP-0${_journeyHistory.length + 1}',
      vehicleId: newId,
      vehicleType: type,
      sourceIntersectionId: sourceIntersectionId,
      sourceIntersectionName: sourceIntersection.name,
      destinationIntersectionId: destinationIntersectionId,
      destinationIntersectionName: destinationIntersection.name,
      startTime: now,
      status: 'In Progress',
      routePath: [sourceIntersectionId, destinationIntersectionId],
    );
    _journeyHistory.insert(0, record);
    _journeyHistoryController.add(List.unmodifiable(_journeyHistory));

    // Prepend to vehicles list
    _vehicles.insert(0, newVehicle);
    _vehiclesController.add(List.unmodifiable(_vehicles));

    // Add journey started notification
    final notif = NotificationItem(
      id: 'NOTIF-${DateTime.now().millisecondsSinceEpoch}',
      title: 'Demo Journey Started',
      message: 'Vehicle $newId (${type.displayName}) initiated journey from ${sourceIntersection.name} to ${destinationIntersection.name}.',
      timestamp: now,
      type: NotificationType.journeyStarted,
    );
    _notifications.insert(0, notif);
    _notificationsController.add(List.unmodifiable(_notifications));

    _statisticsController.add(currentStatistics);

    return JourneyCreationResult(
      isSuccess: true,
      vehicle: newVehicle,
      message: 'Demo vehicle $newId registered. (Sample dataset only - external simulation system not connected)',
      isDemoResult: true,
    );
  }

  @override
  Future<void> simulateCongestion(String action) async {
    // In demo mode, simulate congestion action
  }

  @override
  Future<void> setConnectionMode(ConnectionStatus mode) async {
    _connectionStatus = mode;
    _connectionStatusController.add(_connectionStatus);

    final notif = NotificationItem(
      id: 'NOTIF-${DateTime.now().millisecondsSinceEpoch}',
      title: 'Connection Mode Updated',
      message: 'Traffic system connection state switched to ${mode.label}.',
      timestamp: DateTime.now(),
      type: NotificationType.connectionStatusChanged,
    );
    _notifications.insert(0, notif);
    _notificationsController.add(List.unmodifiable(_notifications));
  }

  @override
  Future<void> markNotificationAsRead(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      _notificationsController.add(List.unmodifiable(_notifications));
    }
  }

  @override
  Future<void> clearAllNotifications() async {
    _notifications.clear();
    _notificationsController.add(List.unmodifiable(_notifications));
  }

  @override
  Future<void> refresh() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _statisticsController.add(currentStatistics);
    _vehiclesController.add(List.unmodifiable(_vehicles));
    _notificationsController.add(List.unmodifiable(_notifications));
  }

  @override
  void dispose() {
    _statisticsController.close();
    _connectionStatusController.close();
    _vehiclesController.close();
    _notificationsController.close();
    _activeUserVehicleController.close();
    _journeyHistoryController.close();
  }
}
