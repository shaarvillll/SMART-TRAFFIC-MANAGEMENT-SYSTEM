import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'services/traffic_repository.dart';
import 'services/demo_traffic_repository.dart';
import 'services/live_traffic_repository.dart';
import 'theme/app_theme.dart';
import 'screens/main_navigation_screen.dart';

/// Tries to reach the Java API server. Supports configured cloud BACKEND_URL with
/// cold-start retry handling, and falls back to local discovery or Demo mode.
Future<TrafficRepository> _buildRepository() async {
  const configuredBackend = String.fromEnvironment('BACKEND_URL');

  // Case 1: BACKEND_URL provided via --dart-define=BACKEND_URL=...
  if (configuredBackend.isNotEmpty) {
    final ep = BackendEndpoints.fromUrl(configuredBackend);
    debugPrint('[App] Configured BACKEND_URL: $configuredBackend');
    debugPrint('[App] Resolved HTTP Base: ${ep.httpBaseUrl}');
    debugPrint('[App] Resolved WS Live: ${ep.wsLiveUrl}');
    debugPrint('[App] Probing status endpoint: ${ep.statusUrl}');

    // Render Free Tier cold-start handler:
    // Retry probing up to 10 attempts (each attempt with a 5-second timeout, total ~40-50s)
    const maxRetries = 10;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint('[App] Connecting to cloud backend (Attempt $attempt/$maxRetries)...');
        final res = await http
            .get(Uri.parse(ep.statusUrl))
            .timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          debugPrint('[App] Cloud backend active → using LiveTrafficRepository');
          return LiveTrafficRepository(backendUrl: configuredBackend);
        }
      } catch (e) {
        debugPrint('[App] Cloud probe attempt $attempt failed: $e');
      }
      if (attempt < maxRetries) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    debugPrint('[App] Cloud backend unreachable after cold-start attempts → fallback to DemoTrafficRepository');
    return DemoTrafficRepository();
  }

  // Case 2: Local development fallback (probe localhost and local Wi-Fi IP)
  final hosts = ['127.0.0.1', kApiServerHost];
  for (final host in hosts) {
    try {
      final res = await http
          .get(Uri.parse('http://$host:7070/api/status'))
          .timeout(const Duration(milliseconds: 1800));
      if (res.statusCode == 200) {
        debugPrint('[App] Local server reachable on $host:7070 → using LiveTrafficRepository');
        return LiveTrafficRepository(serverHost: host, serverPort: 7070);
      }
    } catch (_) {}
  }
  debugPrint('[App] Server not reachable → using DemoTrafficRepository');
  return DemoTrafficRepository();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = await _buildRepository();
  runApp(IntelligentTrafficApp(repository: repository));
}

class IntelligentTrafficApp extends StatefulWidget {
  final TrafficRepository repository;

  const IntelligentTrafficApp({
    super.key,
    required this.repository,
  });

  @override
  State<IntelligentTrafficApp> createState() => _IntelligentTrafficAppState();
}

class _IntelligentTrafficAppState extends State<IntelligentTrafficApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _handleThemeModeChanged(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  void dispose() {
    widget.repository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Intelligent Traffic Management',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: MainNavigationScreen(
        repository: widget.repository,
        currentThemeMode: _themeMode,
        onThemeModeChanged: _handleThemeModeChanged,
      ),
    );
  }
}
