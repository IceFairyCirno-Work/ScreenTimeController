import 'package:flutter/material.dart';
import '../../models/screen_time_data.dart';
import '../../services/screen_time_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/platform_capabilities.dart';
import '../shared/app_icon.dart';

class TopTodayCard extends StatelessWidget {
  static const maxVisibleApps = 5;

  final List<AppUsageItem> apps;
  final bool hasPermission;

  const TopTodayCard({
    super.key,
    required this.apps,
    required this.hasPermission,
  });

  List<AppUsageItem> get _visibleApps {
    final filtered = apps
        .where((app) => app.usage.inMilliseconds >= ScreenTimeService.minUsageMs)
        .toList()
      ..sort((a, b) => b.usage.compareTo(a.usage));
    return filtered.take(maxVisibleApps).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.screenTimerControllerCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: _visibleApps.isEmpty ? _buildEmpty() : _buildContent(),
    );
  }

  Widget _buildEmpty() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Top today', style: _sectionTitle),
        const SizedBox(height: 12),
        Text(
          _emptyMessage,
          style: AppTheme.bodyMedium,
        ),
      ],
    );
  }

  String get _emptyMessage {
    if (!hasPermission) {
      if (!PlatformCapabilities.supportsUsageStats) {
        return 'Screen-time stats are available on Android.';
      }
      return 'Grant usage access to see your apps.';
    }
    return 'No usage data yet. Pull down to refresh.';
  }

  Widget _buildContent() {
    final visible = _visibleApps;
    final topApp = visible.first;
    final topDuration = ScreenTimeData.formatDuration(topApp.usage);
    final maxMs = topApp.usage.inMilliseconds.clamp(1, 999999999);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Top today', style: _sectionTitle),
        const SizedBox(height: 14),
        RichText(
          text: TextSpan(
            style: AppTheme.bodyLarge.copyWith(fontSize: 15, height: 1.5),
            children: [
              TextSpan(text: '${topApp.appName} consumed '),
              TextSpan(
                text: topDuration,
                style: const TextStyle(
                  color: AppTheme.screenTimerControllerMint,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const TextSpan(text: ' of your time today'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...visible.map(
          (app) => _AppUsageRow(
            app: app,
            progress: app.usage.inMilliseconds / maxMs,
          ),
        ),
      ],
    );
  }

  TextStyle get _sectionTitle => AppTheme.bodyLarge.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: AppTheme.textPrimary,
      );
}

class _AppUsageRow extends StatelessWidget {
  final AppUsageItem app;
  final double progress;

  const _AppUsageRow({
    required this.app,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final duration = ScreenTimeData.formatDuration(app.usage);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          AppIcon(iconBytes: app.iconBytes, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app.appName,
                  style: AppTheme.bodyLarge.copyWith(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: AppTheme.surface,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppTheme.screenTimerControllerMint),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            duration,
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
