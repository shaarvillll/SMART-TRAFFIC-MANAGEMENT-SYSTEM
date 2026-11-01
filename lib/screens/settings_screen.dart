import 'package:flutter/material.dart';
import '../models/traffic_state.dart';
import '../services/traffic_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/connection_status.dart';

class SettingsScreen extends StatefulWidget {
  final TrafficRepository repository;
  final ThemeMode currentThemeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  const SettingsScreen({
    super.key,
    required this.repository,
    required this.currentThemeMode,
    required this.onThemeModeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final connectionStatus = widget.repository.currentConnectionStatus;

    return Scaffold(
      appBar: AppBar(
        title: const Text('System Settings'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: ConnectionStatusBadge(status: connectionStatus),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DemoModeNoticeBanner(repository: widget.repository),
          const SizedBox(height: 16),

          // Section 1: Appearance & Theme Selection
          _buildSectionHeader('APPEARANCE & THEME', Icons.palette_outlined),
          const SizedBox(height: 10),
          Material(
            color: AppColors.darkSurface,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: Column(
                children: [
                  _buildThemeRadio(
                    title: 'Dark Navy & Charcoal (Recommended)',
                    subtitle: 'Optimized high-contrast control room theme',
                    value: ThemeMode.dark,
                    groupValue: widget.currentThemeMode,
                    onChanged: (mode) {
                      if (mode != null) widget.onThemeModeChanged(mode);
                    },
                  ),
                  const Divider(height: 1),
                  _buildThemeRadio(
                    title: 'Light Theme',
                    subtitle: 'High brightness daylight view',
                    value: ThemeMode.light,
                    groupValue: widget.currentThemeMode,
                    onChanged: (mode) {
                      if (mode != null) widget.onThemeModeChanged(mode);
                    },
                  ),
                  const Divider(height: 1),
                  _buildThemeRadio(
                    title: 'System Default',
                    subtitle: 'Follow device OS preference',
                    value: ThemeMode.system,
                    groupValue: widget.currentThemeMode,
                    onChanged: (mode) {
                      if (mode != null) widget.onThemeModeChanged(mode);
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Section 2: Simulator Connection Mode
          _buildSectionHeader('SIMULATION CONNECTION MODE', Icons.cable_outlined),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Connection Mode',
                      style: TextStyle(
                        color: AppColors.textPrimaryDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    ConnectionStatusBadge(status: connectionStatus),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  connectionStatus.description,
                  style: const TextStyle(
                    color: AppColors.textSecondaryDark,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 10),
                const Text(
                  'Switch Operating State (Testing / Verification):',
                  style: TextStyle(
                    color: AppColors.textMutedDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ConnectionStatus.values.map((status) {
                    final isCurrent = status == connectionStatus;
                    return ChoiceChip(
                      label: Text(status.label),
                      selected: isCurrent,
                      selectedColor: AppColors.primaryBlue.withOpacity(0.2),
                      backgroundColor: AppColors.darkSurfaceVariant,
                      labelStyle: TextStyle(
                        color: isCurrent ? AppColors.primaryBlue : AppColors.textSecondaryDark,
                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 11.5,
                      ),
                      onSelected: (_) async {
                        await widget.repository.setConnectionMode(status);
                        setState(() {});
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Section 3: Data Source Status
          _buildSectionHeader('DATA SOURCE STATUS', Icons.storage_outlined),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Column(
              children: [
                _buildInfoTile('Active Repository', 'DemoTrafficRepository (Local Simulation)'),
                const Divider(height: 20),
                _buildInfoTile('Simulator Bridge Protocol', 'Ready for WebSocket / REST Socket'),
                const Divider(height: 20),
                _buildInfoTile('Virtual Map Pipeline', 'Ready for Simulation Map Canvas Stream'),
                const Divider(height: 20),
                _buildInfoTile('Permissions Required', 'None (Privacy preserved; no GPS/Location needed)'),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Section 4: App Information
          _buildSectionHeader('APPLICATION INFORMATION', Icons.info_outline),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Column(
              children: [
                _buildInfoTile('Application', 'Intelligent Traffic Management System'),
                const Divider(height: 20),
                _buildInfoTile('Build Platform', 'Flutter 3.x / Material Design 3 (Android)'),
                const Divider(height: 20),
                _buildInfoTile('Version', 'v1.0.0 (College Engineering Edition)'),
                const Divider(height: 20),
                _buildInfoTile('Target Environment', 'Standalone Mobile Telemetry & Control App'),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primaryBlue),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textMutedDark,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }

  Widget _buildThemeRadio({
    required String title,
    required String subtitle,
    required ThemeMode value,
    required ThemeMode groupValue,
    required ValueChanged<ThemeMode?> onChanged,
  }) {
    return RadioListTile<ThemeMode>(
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimaryDark,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppColors.textSecondaryDark,
          fontSize: 11.5,
        ),
      ),
      activeColor: AppColors.primaryBlue,
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textMutedDark,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
