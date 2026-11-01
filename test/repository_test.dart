import 'package:flutter_test/flutter_test.dart';
import 'package:intelligent_traffic_management/models/vehicle.dart';
import 'package:intelligent_traffic_management/models/traffic_state.dart';
import 'package:intelligent_traffic_management/services/demo_traffic_repository.dart';

void main() {
  group('DemoTrafficRepository Unit Tests', () {
    late DemoTrafficRepository repository;

    setUp(() {
      repository = DemoTrafficRepository();
    });

    tearDown(() {
      repository.dispose();
    });

    test('Initial repository state loads demo vehicles and metrics', () {
      expect(repository.currentConnectionStatus, equals(ConnectionStatus.demoMode));
      expect(repository.currentVehicles.isNotEmpty, isTrue);
      expect(repository.monitoredRoads.isNotEmpty, isTrue);
      expect(repository.availableIntersections.length, greaterThanOrEqualTo(5));

      final stats = repository.currentStatistics;
      expect(stats.activeVehicles, greaterThan(0));
      expect(stats.overallCondition, equals(OverallTrafficCondition.moderate));
    });

    test('startJourney adds new vehicle and records demo event', () async {
      final initialCount = repository.currentVehicles.length;

      final result = await repository.startJourney(
        type: VehicleType.ambulance,
        sourceIntersectionId: 'INT-01',
        destinationIntersectionId: 'INT-04',
      );

      expect(result.isSuccess, isTrue);
      expect(result.isDemoResult, isTrue);
      expect(result.vehicle, isNotNull);
      expect(result.vehicle!.type, equals(VehicleType.ambulance));
      expect(repository.currentVehicles.length, equals(initialCount + 1));
      expect(repository.currentVehicles.first.id, contains('DEMO-AMB'));
    });

    test('setConnectionMode updates status correctly', () async {
      await repository.setConnectionMode(ConnectionStatus.connected);
      expect(repository.currentConnectionStatus, equals(ConnectionStatus.connected));

      await repository.setConnectionMode(ConnectionStatus.demoMode);
      expect(repository.currentConnectionStatus, equals(ConnectionStatus.demoMode));
    });
  });
}
