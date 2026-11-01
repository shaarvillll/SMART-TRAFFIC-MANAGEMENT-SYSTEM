import 'package:flutter/material.dart';
import '../services/traffic_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/virtual_city_map_widget.dart';
import 'vehicles_screen.dart';
import 'notifications_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final TrafficRepository repository;
  final ThemeMode currentThemeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const MainNavigationScreen({
    super.key,
    required this.repository,
    required this.currentThemeMode,
    required this.onThemeModeChanged,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.navigation_rounded,
                  color: AppColors.primaryBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Smart Traffic Navigation',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            // Traffic Alerts Button
            StreamBuilder(
              stream: widget.repository.notificationsStream,
              initialData: widget.repository.currentNotifications,
              builder: (context, snapshot) {
                final unreadCount = (snapshot.data ?? []).where((n) => !n.isRead).length;

                return IconButton(
                  icon: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.notifications_outlined, size: 22),
                      if (unreadCount > 0)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.trafficRed,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  tooltip: 'Traffic Alerts',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NotificationsScreen(repository: widget.repository),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
        body: VirtualCityMapWidget(
          repository: widget.repository,
          height: double.infinity,
          isFullScreen: true,
        ),
      ),
      VehiclesScreen(
        repository: widget.repository,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex.clamp(0, screens.length - 1),
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex.clamp(0, screens.length - 1),
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label: 'Live Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'Previous Journeys',
          ),
        ],
      ),
    );
  }
}
