import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/vehicle.dart';
import '../models/road.dart';
import '../models/intersection.dart';
import '../models/traffic_state.dart';
import '../models/notification_item.dart';
import '../models/journey_record.dart';
import 'traffic_repository.dart';

const String kApiServerHost = '10.209.248.74'; // Current Wi-Fi IP (Run 'ipconfig' to verify)
const int kApiServerPort = 7070;

/// Endpoint resolver supporting local dev IPs/ports and cloud HTTPS/WSS URLs.
class BackendEndpoints {
  final String httpBaseUrl; // e.g. https://domain.com/api or http://10.209.248.74:7070/api
  final String wsLiveUrl;   // e.g. wss://domain.com/ws/live or ws://10.209.248.74:7070/ws/live
  final String statusUrl;   // e.g. https://domain.com/api/status
  final String host;
  final int? port;

  const BackendEndpoints({
    required this.httpBaseUrl,
    required this.wsLiveUrl,
    required this.statusUrl,
    required this.host,
    this.port,
  });

  factory BackendEndpoints.fromUrl(String urlOrHost, {int defaultLocalPort = 7070}) {
    String trimmed = urlOrHost.trim();
    if (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final uri = Uri.parse(trimmed);
      final isHttps = uri.scheme == 'https';
      final portSuffix = uri.hasPort ? ':${uri.port}' : '';
      var path = uri.path;
      if (path.endsWith('/')) {
        path = path.substring(0, path.length - 1);
      }
      final apiPath = path.endsWith('/api') ? path : '$path/api';
      final base = '${uri.scheme}://${uri.host}$portSuffix$apiPath';
      final wsScheme = isHttps ? 'wss' : 'ws';
      final ws = '$wsScheme://${uri.host}$portSuffix${apiPath.replaceAll(RegExp(r'/api$'), '')}/ws/live';
      final status = '$base/status';

      return BackendEndpoints(
        httpBaseUrl: base,
        wsLiveUrl: ws,
        statusUrl: status,
        host: uri.host,
        port: uri.hasPort ? uri.port : (isHttps ? 443 : 80),
      );
    }

    // No scheme provided.
    // Check if it looks like a local development IP or localhost:
    final isLocal = trimmed == 'localhost' ||
        trimmed == '127.0.0.1' ||
        trimmed.startsWith('192.168.') ||
        trimmed.startsWith('10.') ||
        trimmed.contains(':');

    if (isLocal) {
      final hasPort = trimmed.contains(':');
      final host = hasPort ? trimmed.split(':').first : trimmed;
      final port = hasPort ? int.tryParse(trimmed.split(':').last) ?? defaultLocalPort : defaultLocalPort;

      final base = 'http://$host:$port/api';
      final ws = 'ws://$host:$port/ws/live';
      return BackendEndpoints(
        httpBaseUrl: base,
        wsLiveUrl: ws,
        statusUrl: '$base/status',
        host: host,
        port: port,
      );
    } else {
      // Cloud domain (e.g. smart-traffic.onrender.com)
      final base = 'https://$trimmed/api';
      final ws = 'wss://$trimmed/ws/live';
      return BackendEndpoints(
        httpBaseUrl: base,
        wsLiveUrl: ws,
        statusUrl: '$base/status',
        host: trimmed,
        port: 443,
      );
    }
  }
}


/// Maps Java VehicleStatus names to Flutter JourneyStatus
JourneyStatus _mapStatus(String status) {
  switch (status.toUpperCase()) {
    case 'MOVING': return JourneyStatus.moving;
    case 'STOPPED_AT_SIGNAL': return JourneyStatus.waitingAtSignal;
    case 'WAITING': return JourneyStatus.initializing;
    case 'COMPLETED': return JourneyStatus.arrived;
    default: return JourneyStatus.moving;
  }
}

/// Maps Java VehicleType names to Flutter VehicleType
VehicleType _mapVehicleType(String type) {
  switch (type.toUpperCase()) {
    case 'AMBULANCE': return VehicleType.ambulance;
    case 'BUS':   return VehicleType.bus;
    case 'TRUCK': return VehicleType.ambulance; // mapped to ambulance for UI
    default:      return VehicleType.car;
  }
}

Vehicle _vehicleFromJson(Map<String, dynamic> j) {
  final routePath = (j['routePath'] as List<dynamic>? ?? []).cast<String>();
  final prevRoutePath = (j['previousRoutePath'] as List<dynamic>? ?? []).cast<String>();
  final directions = (j['directions'] as List<dynamic>? ?? []).cast<String>();
  final currentPositionDesc = j['currentPosition'] as String? ?? 'Position: ${(j['x'] as num? ?? 0).toStringAsFixed(0)}, ${(j['y'] as num? ?? 0).toStringAsFixed(0)}';
  final currentInstruction = j['currentInstruction'] as String?;
  final rerouteCount = (j['rerouteCount'] as num? ?? 0).toInt();
  final rerouteReason = (j['rerouteReason'] ?? j['rerouteMessage']) as String?;
  final rerouteInstruction = j['rerouteInstruction'] as String?;

  final progress  = (j['progressPercent'] as num? ?? 0).toDouble() / 100.0;
  final tripSec   = (j['tripDurationSec'] as num? ?? 0).toDouble();
  final x         = (j['x'] as num? ?? 0).toDouble();
  final y         = (j['y'] as num? ?? 0).toDouble();
  final speed     = (j['speed'] as num? ?? 0).toDouble();

  final routeStr = routePath.length >= 2
      ? routePath.join(' → ')
      : '${j['sourceId']} → ${j['destinationId']}';
  final prevRouteStr = prevRoutePath.length >= 2 ? prevRoutePath.join(' → ') : null;

  return Vehicle(
    id: j['id'] as String,
    type: _mapVehicleType(j['type'] as String? ?? 'CAR'),
    sourceIntersection: j['sourceName'] as String? ?? j['sourceId'] as String,
    destinationIntersection: j['destinationName'] as String? ?? j['destinationId'] as String,
    currentPosition: currentPositionDesc,
    status: rerouteCount > 0 && rerouteReason != null && _mapStatus(j['status'] as String? ?? 'MOVING') != JourneyStatus.arrived
        ? JourneyStatus.rerouted
        : _mapStatus(j['status'] as String? ?? 'MOVING'),
    routeInfo: RouteInfo(
      currentRoute: routeStr,
      previousRoute: prevRouteStr,
      newRoute: rerouteCount > 0 ? routeStr : null,
      diversionReason: rerouteReason,
      diversionInstruction: rerouteInstruction,
      lastUpdateTime: DateTime.now(),
    ),
    eta: '${(tripSec / 60).toStringAsFixed(0)} min',
    remainingDistance: '${((1 - progress) * 1000).toStringAsFixed(0)} m',
    progressFraction: progress.clamp(0.0, 1.0),
    x: x,
    y: y,
    speed: speed,
    routePath: routePath,
    previousRoutePath: prevRoutePath,
    currentInstruction: currentInstruction,
    directions: directions,
    rerouteCount: rerouteCount,
  );
}

Intersection _intersectionFromJson(Map<String, dynamic> j) {
  final lm = j['landmark'] as Map<String, dynamic>?;
  final signalsRaw = j['signals'] as Map<String, dynamic>?;
  final Map<String, String>? signals = signalsRaw != null
      ? signalsRaw.map((k, v) => MapEntry(k, v.toString()))
      : null;

  return Intersection(
    id: j['id'] as String,
    name: j['name'] as String,
    zone: lm != null ? (lm['type'] as String? ?? 'General Zone') : 'General Zone',
    x: (j['x'] as num? ?? 0).toDouble(),
    y: (j['y'] as num? ?? 0).toDouble(),
    landmarkType: lm?['type'] as String?,
    landmarkName: lm?['name'] as String?,
    landmarkIcon: lm?['iconCode'] as String?,
    signals: signals,
  );
}

class LiveTrafficRepository implements TrafficRepository {
  ConnectionStatus _connectionStatus = ConnectionStatus.connecting;

  final _statsCtrl         = StreamController<TrafficStatistics>.broadcast();
  final _connCtrl          = StreamController<ConnectionStatus>.broadcast();
  final _vehiclesCtrl      = StreamController<List<Vehicle>>.broadcast();
  final _notifsCtrl        = StreamController<List<NotificationItem>>.broadcast();
  final _intersectionsCtrl = StreamController<List<Intersection>>.broadcast();
  final _roadsCtrl         = StreamController<List<Road>>.broadcast();
  final _activeUserVehicleCtrl = StreamController<Vehicle?>.broadcast();
  final _journeyHistoryCtrl    = StreamController<List<JourneyRecord>>.broadcast();

  String? _activeUserVehicleId;
  final List<JourneyRecord> _journeyHistory = [];

  List<Vehicle>          _vehicles      = [];
  List<Intersection>     _intersections = [];
  List<Road>             _roads         = [];
  final List<NotificationItem> _notifications = [];

  WebSocketChannel? _ws;
  Timer? _reconnectTimer;
  bool _disposed = false;

  final String serverHost;
  final int serverPort;
  late final String _baseUrl;
  late final String _wsUrl;

  LiveTrafficRepository({
    String? backendUrl,
    String? serverHost,
    int? serverPort,
  })  : serverHost = serverHost ??
            (backendUrl != null && backendUrl.isNotEmpty
                ? BackendEndpoints.fromUrl(backendUrl).host
                : kApiServerHost),
        serverPort = serverPort ??
            (backendUrl != null && backendUrl.isNotEmpty
                ? (BackendEndpoints.fromUrl(backendUrl).port ?? 443)
                : kApiServerPort) {
    if (backendUrl != null && backendUrl.isNotEmpty) {
      final ep = BackendEndpoints.fromUrl(backendUrl);
      _baseUrl = ep.httpBaseUrl;
      _wsUrl   = ep.wsLiveUrl;
    } else {
      final ep = BackendEndpoints.fromUrl(this.serverHost, defaultLocalPort: this.serverPort);
      _baseUrl = ep.httpBaseUrl;
      _wsUrl   = ep.wsLiveUrl;
    }
    _fetchMap();
    _connectWebSocket();
  }

  // ─── Internal helpers ───────────────────────────────────────────────────────

  Future<void> _fetchMap() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/map'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        _intersections = (data['intersections'] as List)
            .map((e) => _intersectionFromJson(e as Map<String, dynamic>))
            .toList();
        _roads = (data['roads'] as List).map((e) {
          final r = e as Map<String, dynamic>;
          final condition = r['condition'] as String? ?? 'NORMAL';
          final cong = condition == 'CONGESTED'
              ? CongestionLevel.heavy
              : CongestionLevel.low;
          return Road(
            id: r['id'] as String,
            name: r['name'] as String,
            congestionLevel: cong,
            vehicleCount: 0,
            averageSpeedKmH: 45.0,
            fromId: r['fromId'] as String? ?? '',
            toId: r['toId'] as String? ?? '',
            length: (r['length'] as num? ?? 0).toDouble(),
            type: r['type'] as String? ?? 'MAIN_GRID',
            condition: condition,
          );
        }).toList();
        _intersectionsCtrl.add(List.unmodifiable(_intersections));
        _roadsCtrl.add(List.unmodifiable(_roads));
      }
    } catch (_) {}
  }

  void _connectWebSocket() {
    if (_disposed) return;
    try {
      _ws = WebSocketChannel.connect(Uri.parse(_wsUrl));
      _setConnectionStatus(ConnectionStatus.connected);

      _ws!.stream.listen(
        (message) {
          if (_disposed) return;
          try {
            final data = jsonDecode(message as String) as Map<String, dynamic>;
            _handleLiveUpdate(data);
          } catch (_) {}
        },
        onDone: _handleDisconnect,
        onError: (_) => _handleDisconnect(),
      );
    } catch (_) {
      _handleDisconnect();
    }
  }

  void _handleLiveUpdate(Map<String, dynamic> data) {
    // Update signals on intersections
    if (data['signals'] != null) {
      final sigMap = data['signals'] as Map<String, dynamic>;
      bool updated = false;
      for (int i = 0; i < _intersections.length; i++) {
        final node = _intersections[i];
        if (sigMap.containsKey(node.id)) {
          final raw = sigMap[node.id] as Map<String, dynamic>;
          final parsed = raw.map((k, v) => MapEntry(k, v.toString()));
          _intersections[i] = node.copyWith(signals: parsed);
          updated = true;
        }
      }
      if (updated) {
        _intersectionsCtrl.add(List.unmodifiable(_intersections));
      }
    }

    // Update roads & congestion states
    if (data['roads'] != null) {
      final rawRoads = data['roads'] as List<dynamic>;
      _roads = rawRoads.map((e) {
        final r = e as Map<String, dynamic>;
        final condition = r['condition'] as String? ?? 'NORMAL';
        final cong = condition == 'CONGESTED'
            ? CongestionLevel.heavy
            : (condition == 'CLOSED' ? CongestionLevel.heavy : CongestionLevel.low);
        return Road(
          id: r['id'] as String,
          name: r['name'] as String,
          congestionLevel: cong,
          vehicleCount: 0,
          averageSpeedKmH: condition == 'CONGESTED' ? 14.0 : 48.0,
          fromId: r['fromId'] as String? ?? '',
          toId: r['toId'] as String? ?? '',
          length: (r['length'] as num? ?? 0).toDouble(),
          type: r['type'] as String? ?? 'MAIN_GRID',
          condition: condition,
        );
      }).toList();
      _roadsCtrl.add(List.unmodifiable(_roads));
    }

    // Update vehicles
    final rawVehicles = data['vehicles'] as List<dynamic>? ?? [];
    _vehicles = rawVehicles
        .map((e) => _vehicleFromJson(e as Map<String, dynamic>))
        .toList();
    _vehiclesCtrl.add(List.unmodifiable(_vehicles));
    _statsCtrl.add(currentStatistics);

    // Track active user vehicle
    if (_activeUserVehicleId != null) {
      Vehicle? userV;
      for (final v in _vehicles) {
        if (v.id == _activeUserVehicleId) {
          userV = v;
          break;
        }
      }

      if (userV != null) {
        _activeUserVehicleCtrl.add(userV);

        if (userV.status == JourneyStatus.arrived || userV.progressFraction >= 0.99) {
          _completeCurrentJourney(userV);
        }
      } else {
        // Vehicle completed or removed from simulator
        _completeCurrentJourney(null);
      }
    }
  }

  void _completeCurrentJourney(Vehicle? userV) {
    if (_activeUserVehicleId == null) return;
    final index = _journeyHistory.indexWhere(
      (r) => r.vehicleId == _activeUserVehicleId && r.status == 'In Progress',
    );
    if (index != -1) {
      final prev = _journeyHistory[index];
      final dur = DateTime.now().difference(prev.startTime).inMilliseconds / 1000.0;
      _journeyHistory[index] = prev.copyWith(
        status: 'Completed',
        endTime: DateTime.now(),
        durationSeconds: dur,
      );
      _journeyHistoryCtrl.add(List.unmodifiable(_journeyHistory));
    }

    final dest = userV?.destinationIntersection ?? 'Destination';
    final arrivalNotif = NotificationItem(
      id: 'NOTIF-${DateTime.now().millisecondsSinceEpoch}',
      title: 'Journey Completed 🎉',
      message: 'Vehicle $_activeUserVehicleId reached $dest successfully.',
      timestamp: DateTime.now(),
      type: NotificationType.journeyCompleted,
    );
    _notifications.insert(0, arrivalNotif);
    _notifsCtrl.add(List.unmodifiable(_notifications));

    _activeUserVehicleId = null;
    _activeUserVehicleCtrl.add(null);
  }

  void _handleDisconnect() {
    if (_disposed) return;
    _setConnectionStatus(ConnectionStatus.disconnected);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (!_disposed) _connectWebSocket();
    });
  }

  void _setConnectionStatus(ConnectionStatus s) {
    _connectionStatus = s;
    _connCtrl.add(s);
  }

  // ─── TrafficRepository interface ─────────────────────────────────────────────

  @override
  Stream<TrafficStatistics>    get statisticsStream      => _statsCtrl.stream;
  @override
  Stream<ConnectionStatus>     get connectionStatusStream => _connCtrl.stream;
  @override
  Stream<List<Vehicle>>        get vehiclesStream        => _vehiclesCtrl.stream;
  @override
  Stream<List<NotificationItem>> get notificationsStream => _notifsCtrl.stream;
  @override
  Stream<List<Intersection>>   get intersectionsStream   => _intersectionsCtrl.stream;
  @override
  Stream<List<Road>>           get roadsStream           => _roadsCtrl.stream;

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
  Stream<Vehicle?> get activeUserVehicleStream => _activeUserVehicleCtrl.stream;

  @override
  List<JourneyRecord> get journeyHistory => List.unmodifiable(_journeyHistory);

  @override
  Stream<List<JourneyRecord>> get journeyHistoryStream => _journeyHistoryCtrl.stream;

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
        _journeyHistoryCtrl.add(List.unmodifiable(_journeyHistory));
      }
      _activeUserVehicleId = null;
      _activeUserVehicleCtrl.add(null);
    }
  }

  @override
  ConnectionStatus get currentConnectionStatus => _connectionStatus;

  @override
  List<Vehicle>          get currentVehicles        => List.unmodifiable(_vehicles);
  @override
  List<Intersection>     get availableIntersections => _intersections;
  @override
  List<Road>             get monitoredRoads         => _roads;
  @override
  List<NotificationItem> get currentNotifications   => List.unmodifiable(_notifications);

  @override
  TrafficStatistics get currentStatistics {
    final moving   = _vehicles.where((v) => v.status == JourneyStatus.moving).length;
    final waiting  = _vehicles.where((v) => v.status == JourneyStatus.waitingAtSignal).length;
    final arrived  = _vehicles.where((v) => v.status == JourneyStatus.arrived).length;
    final active   = _vehicles.length - arrived;
    final congestedCount = _roads.where((r) => r.condition == 'CONGESTED' || r.congestionLevel == CongestionLevel.heavy).length;

    final overall = congestedCount >= 3
        ? OverallTrafficCondition.heavyCongestion
        : (congestedCount > 0 ? OverallTrafficCondition.moderate : OverallTrafficCondition.smooth);

    return TrafficStatistics(
      activeVehicles: active,
      congestedRoads: congestedCount,
      movingVehicles: moving,
      waitingAtSignals: waiting,
      completedJourneys: arrived,
      routeDiversions: 0,
      overallCondition: overall,
      networkEfficiencyPercent: active == 0 ? 100.0 : (moving / _vehicles.length * 100).clamp(0, 100),
    );
  }

  @override
  Future<JourneyCreationResult> startJourney({
    required VehicleType type,
    required String sourceIntersectionId,
    required String destinationIntersectionId,
  }) async {
    // Single-vehicle constraint: only one active journey allowed
    if (activeUserVehicle != null && activeUserVehicle!.status != JourneyStatus.arrived) {
      return JourneyCreationResult(
        isSuccess: false,
        message: 'You already have an active journey with vehicle ${activeUserVehicle!.id} in transit. You can start a new journey once it completes.',
        isDemoResult: false,
      );
    }

    final typeStr = type == VehicleType.bus
        ? 'BUS'
        : type == VehicleType.ambulance
            ? 'AMBULANCE'
            : 'CAR';
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/spawn'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'type': typeStr,
          'from': sourceIntersectionId,
          'to':   destinationIntersectionId,
        }),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 201) {
        final v = _vehicleFromJson(jsonDecode(res.body) as Map<String, dynamic>);
        _activeUserVehicleId = v.id;
        _activeUserVehicleCtrl.add(v);

        // Record in history
        final record = JourneyRecord(
          id: 'TRIP-0${_journeyHistory.length + 1}',
          vehicleId: v.id,
          vehicleType: type,
          sourceIntersectionId: sourceIntersectionId,
          sourceIntersectionName: v.sourceIntersection,
          destinationIntersectionId: destinationIntersectionId,
          destinationIntersectionName: v.destinationIntersection,
          startTime: DateTime.now(),
          status: 'In Progress',
          routePath: v.routePath,
        );
        _journeyHistory.insert(0, record);
        _journeyHistoryCtrl.add(List.unmodifiable(_journeyHistory));

        final notif = NotificationItem(
          id: 'NOTIF-${DateTime.now().millisecondsSinceEpoch}',
          title: 'My Journey Started',
          message: 'Vehicle ${v.id} departed from ${v.sourceIntersection} to ${v.destinationIntersection}.',
          timestamp: DateTime.now(),
          type: NotificationType.journeyStarted,
        );
        _notifications.insert(0, notif);
        _notifsCtrl.add(List.unmodifiable(_notifications));
        return JourneyCreationResult(isSuccess: true, vehicle: v, message: 'Your journey with ${v.id} has started!', isDemoResult: false);
      } else {
        final err = jsonDecode(res.body)['error'] ?? 'Server error ${res.statusCode}';
        return JourneyCreationResult(isSuccess: false, message: err as String, isDemoResult: false);
      }
    } catch (e) {
      return JourneyCreationResult(isSuccess: false, message: 'Connection failed: $e', isDemoResult: false);
    }
  }

  @override
  Future<void> simulateCongestion(String action) async {
    try {
      Map<String, dynamic> body;
      if (action == 'rush_hour' || action == 'clear_all') {
        body = {'action': action};
      } else if (action == 'close_r8') {
        body = {'roadId': 'R8', 'condition': 'CLOSED'};
      } else if (action == 'congest_r8') {
        body = {'roadId': 'R8', 'condition': 'CONGESTED'};
      } else if (action == 'normal_r8') {
        body = {'roadId': 'R8', 'condition': 'NORMAL'};
      } else if (action.startsWith('close_')) {
        body = {'roadId': action.substring(6).toUpperCase(), 'condition': 'CLOSED'};
      } else if (action.startsWith('congest_')) {
        body = {'roadId': action.substring(8).toUpperCase(), 'condition': 'CONGESTED'};
      } else if (action.startsWith('normal_')) {
        body = {'roadId': action.substring(7).toUpperCase(), 'condition': 'NORMAL'};
      } else {
        body = {'action': action};
      }
      await http.post(
        Uri.parse('$_baseUrl/congestion'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 4));
    } catch (_) {}
  }

  @override
  Future<void> setConnectionMode(ConnectionStatus mode) async {
    _setConnectionStatus(mode);
  }

  @override
  Future<void> markNotificationAsRead(String notificationId) async {
    final i = _notifications.indexWhere((n) => n.id == notificationId);
    if (i != -1) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
      _notifsCtrl.add(List.unmodifiable(_notifications));
    }
  }

  @override
  Future<void> clearAllNotifications() async {
    _notifications.clear();
    _notifsCtrl.add(const []);
  }

  @override
  Future<void> refresh() async {
    await _fetchMap();
    try {
      final res = await http.get(Uri.parse('$_baseUrl/vehicles'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        _vehicles = (jsonDecode(res.body) as List)
            .map((e) => _vehicleFromJson(e as Map<String, dynamic>))
            .toList();
        _vehiclesCtrl.add(List.unmodifiable(_vehicles));
        _statsCtrl.add(currentStatistics);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _ws?.sink.close();
    _statsCtrl.close();
    _connCtrl.close();
    _vehiclesCtrl.close();
    _notifsCtrl.close();
    _intersectionsCtrl.close();
    _roadsCtrl.close();
    _activeUserVehicleCtrl.close();
    _journeyHistoryCtrl.close();
  }
}
