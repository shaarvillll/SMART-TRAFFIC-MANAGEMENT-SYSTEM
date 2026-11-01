import 'package:flutter/material.dart';
import '../models/traffic_state.dart';
import '../theme/app_theme.dart';

class TrafficSummaryCard extends StatelessWidget {
  final TrafficStatistics stats;

  const TrafficSummaryCard({
    super.key,
    required this.stats,
  });

  Color get _conditionColor {
    switch (stats.overallCondition) {
      case OverallTrafficCondition.smooth:
        return AppColors.trafficGreen;
      case OverallTrafficCondition.moderate:
        return AppColors.trafficYellow;
      case OverallTrafficCondition.heavyCongestion:
        return AppColors.trafficRed;
    }
  }

  IconData get _conditionIcon {
    switch (stats.overallCondition) {
      case OverallTrafficCondition.smooth:
        return Icons.check_circle_outline;
      case OverallTrafficCondition.moderate:
        return Icons.warning_amber_rounded;
      case OverallTrafficCondition.heavyCongestion:
        return Icons.error_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.darkSurfaceElevated,
            _conditionColor.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _conditionColor.withOpacity(0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _conditionColor.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_conditionIcon, color: _conditionColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Overall Traffic Condition',
                        style: TextStyle(
                          color: AppColors.textSecondaryDark,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        stats.overallCondition.label,
                        style: TextStyle(
                          color: _conditionColor,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.darkSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: Column(
                  children: [
                    Text(
                      '${stats.networkEfficiencyPercent.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: AppColors.primaryBlue,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text(
                      'Flow Rate',
                      style: TextStyle(
                        color: AppColors.textMutedDark,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildMiniStat('Active Nodes', '${stats.activeVehicles}', AppColors.primaryBlue)),
              Expanded(child: _buildMiniStat('Bottlenecks', '${stats.congestedRoads}', AppColors.trafficRed)),
              Expanded(child: _buildMiniStat('Signal Queues', '${stats.waitingAtSignals}', AppColors.trafficYellow)),
              Expanded(child: _buildMiniStat('Completed', '${stats.completedJourneys}', AppColors.trafficGreen)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textMutedDark,
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }
}
