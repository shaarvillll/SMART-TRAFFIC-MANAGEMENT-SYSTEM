enum ConnectionStatus {
  demoMode,
  connecting,
  connected,
  disconnected,
}

extension ConnectionStatusExtension on ConnectionStatus {
  String get label {
    switch (this) {
      case ConnectionStatus.demoMode:
        return 'Demo Mode';
      case ConnectionStatus.connecting:
        return 'Connecting...';
      case ConnectionStatus.connected:
        return 'Connected';
      case ConnectionStatus.disconnected:
        return 'Disconnected';
    }
  }

  String get description {
    switch (this) {
      case ConnectionStatus.demoMode:
        return 'Operating with local simulated sample dataset';
      case ConnectionStatus.connecting:
        return 'Establishing link with external simulation server';
      case ConnectionStatus.connected:
        return 'Real-time telemetry streaming from simulator';
      case ConnectionStatus.disconnected:
        return 'No active server connection. Falling back to offline view';
    }
  }
}

enum OverallTrafficCondition {
  smooth,
  moderate,
  heavyCongestion,
}

extension OverallTrafficConditionExtension on OverallTrafficCondition {
  String get label {
    switch (this) {
      case OverallTrafficCondition.smooth:
        return 'Smooth Flow';
      case OverallTrafficCondition.moderate:
        return 'Moderate Density';
      case OverallTrafficCondition.heavyCongestion:
        return 'Heavy Congestion';
    }
  }
}

class TrafficStatistics {
  final int activeVehicles;
  final int congestedRoads;
  final int movingVehicles;
  final int waitingAtSignals;
  final int completedJourneys;
  final int routeDiversions;
  final OverallTrafficCondition overallCondition;
  final double networkEfficiencyPercent;

  const TrafficStatistics({
    required this.activeVehicles,
    required this.congestedRoads,
    required this.movingVehicles,
    required this.waitingAtSignals,
    required this.completedJourneys,
    required this.routeDiversions,
    required this.overallCondition,
    required this.networkEfficiencyPercent,
  });
}
