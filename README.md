# Intelligent Traffic Management System (Mobile App)

A modern, high-performance Flutter Android mobile application designed for college engineering demonstration and traffic management telemetry.

---

## Architecture Overview

```
lib/
├── main.dart                       # Application entry point & theme state management
├── models/
│   ├── vehicle.dart                # Vehicle, VehicleType, JourneyStatus, RouteInfo
│   ├── road.dart                   # Road, CongestionLevel
│   ├── intersection.dart           # Intersection node model
│   ├── traffic_state.dart          # ConnectionStatus, OverallTrafficCondition, TrafficStatistics
│   └── notification_item.dart      # NotificationItem, NotificationType
├── screens/
│   ├── main_navigation_screen.dart # Material 3 bottom navigation (Dashboard, Vehicles, Settings)
│   ├── home_screen.dart            # Metrics grid, map placeholder, roads, Start Journey button
│   ├── journey_screen.dart         # Validated Start Journey dispatch form
│   ├── vehicles_screen.dart        # Vehicle fleet list with status/type filtering and search
│   ├── vehicle_details_screen.dart # Full vehicle telemetry & route diversion audit
│   ├── notifications_screen.dart   # Traffic alerts, delays, signal queue events
│   └── settings_screen.dart        # Theme selection, connection mode, data source status
├── widgets/
│   ├── traffic_map_container.dart  # Virtual City Map placeholder with congestion legend
│   ├── statistic_card.dart         # Glassmorphic dark navy metric cards
│   ├── traffic_summary.dart        # Overall traffic condition card
│   ├── vehicle_card.dart           # Interactive vehicle telemetry card
│   └── connection_status.dart      # ConnectionStatus badge & demo notice banners
├── services/
│   ├── traffic_repository.dart     # Abstract repository for seamless future simulator integration
│   └── demo_traffic_repository.dart# Sample data implementation with active streams
└── theme/
    └── app_theme.dart              # Dark Navy & Charcoal palette with Material Design 3
```

---

## Key Features

1. **Dark Navy & Charcoal Visual Design**: Designed with deep navy `#090D16`, `#121826`, cyan/sky blue accents (`#38BDF8`), and standard traffic indicators (Green, Yellow, Red).
2. **Virtual City Map Placeholder (`TrafficMapContainer`)**: Reusable widget with congestion legend (Green = Low, Yellow = Moderate, Red = Heavy) ready to receive future simulator interactive streams without using Google Maps, OpenStreetMap, GPS, or location permissions.
3. **Validated "Start Journey" Dispatch**:
   - Supports Car, Bus, and Emergency Ambulance.
   - Requires starting and destination intersection selection.
   - Prevents duplicate submissions and identical origin-destination selections.
   - Clearly labels demo generation results.
4. **Vehicles Telemetry & Filter**:
   - Displays vehicle cards with IDs, route progress, ETA, and status: *Initializing, Moving, Waiting at signal, Delayed, Rerouted, Arrived, Failed*.
   - Filter chips and search bar with empty state handling.
5. **Route Information & Diversion Audit**:
   - Tracks current route, previous route, new route, diversion reason, and timestamp.
6. **Repository Abstraction**:
   - Code is decoupled behind `TrafficRepository`. Switching to WebSocket or REST socket from the future desktop simulation system requires updating only the repository layer.

---

## Prerequisites & Installation

To run this application on your Windows machine and Android device/emulator:

1. **Install Flutter SDK**:
   - Download the latest Flutter SDK for Windows from [https://flutter.dev](https://flutter.dev).
   - Extract to `C:\src\flutter` (or a directory of your choice).
   - Add `C:\src\flutter\bin` to your Windows `Path` environment variable.
2. **Install Android Studio**:
   - Install Android Studio with the Android SDK Command-line Tools and Android Emulator.
3. **Verify Environment**:
   ```powershell
   flutter doctor
   ```
4. **Fetch Dependencies & Run Tests**:
   ```powershell
   flutter pub get
   flutter test
   ```
5. **Launch Application**:
   ```powershell
   flutter run
   ```
