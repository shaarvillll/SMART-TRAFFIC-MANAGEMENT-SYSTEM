import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Reusable widget for displaying the Virtual City Map or its future interactive simulator feed.
/// Strictly avoids Google Maps, OSM, GPS, and location permissions.
class TrafficMapContainer extends StatelessWidget {
  final Widget? mapContent;
  final VoidCallback? onRefreshTap;
  final bool isLive;

  const TrafficMapContainer({
    super.key,
    this.mapContent,
    this.onRefreshTap,
    this.isLive = true,
  });

  @override
  Widget build(BuildContext context) {
    final activeLive = mapContent != null || isLive;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.darkBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Map Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppColors.darkSurfaceVariant,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.map_outlined,
                    color: AppColors.primaryBlue,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Virtual City Simulation Map',
                        style: TextStyle(
                          color: AppColors.textPrimaryDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.1,
                        ),
                      ),
                      Text(
                        activeLive
                            ? 'Interactive 2D City Network • Pan & Zoom'
                            : 'Simulator feed endpoint placeholder',
                        style: const TextStyle(
                          color: AppColors.textMutedDark,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.darkSurfaceElevated,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.darkBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: activeLive ? AppColors.trafficGreen : AppColors.trafficYellow,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        activeLive ? 'Live Feed' : 'Awaiting Feed',
                        style: TextStyle(
                          color: activeLive ? AppColors.trafficGreen : AppColors.textSecondaryDark,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Map Canvas or Placeholder
          if (mapContent != null)
            mapContent!
          else
            _buildMapPlaceholder(context),

          // Congestion Legend Footer
          _buildCongestionLegend(),
        ],
      ),
    );
  }

  Widget _buildMapPlaceholder(BuildContext context) {
    return Container(
      height: 220,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1424),
        image: DecorationImage(
          image: const AssetImage('assets/images/grid_pattern.png'),
          onError: (_, __) {},
          fit: BoxFit.cover,
          opacity: 0.04,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Radar / Satellite simulation icon with pulse effect
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.darkSurfaceElevated,
                border: Border.all(
                  color: AppColors.primaryBlue.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withOpacity(0.12),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.hub_outlined,
                color: AppColors.primaryBlue,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Virtual city map will appear here when connected to the traffic simulation system.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimaryDark,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Hardware & Desktop Simulator Socket Listener Ready',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMutedDark,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCongestionLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.darkSurfaceVariant.withOpacity(0.7),
      child: Wrap(
        alignment: WrapAlignment.spaceAround,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 6,
        children: [
          _buildLegendItem(
            color: AppColors.trafficGreen,
            label: 'Green',
            description: 'Low congestion',
          ),
          _buildLegendItem(
            color: AppColors.trafficYellow,
            label: 'Yellow',
            description: 'Moderate congestion',
          ),
          _buildLegendItem(
            color: AppColors.trafficRed,
            label: 'Red',
            description: 'Heavy congestion',
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required String description,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.5),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 11),
            children: [
              TextSpan(
                text: '$label: ',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextSpan(
                text: description,
                style: const TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
