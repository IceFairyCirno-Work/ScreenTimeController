import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_data.dart';
import '../../providers/rules_provider.dart';
import '../../providers/screen_time_provider.dart';
import '../../providers/timer_provider.dart';
import '../../screens/settings/settings_screen.dart';
import '../../services/daily_usage_history_service.dart';
import '../../services/streak_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../widgets/profile/profile_analytics_chart.dart';
import '../../widgets/profile/profile_avatar.dart';
import '../../widgets/profile/profile_header.dart';
import '../../widgets/profile/profile_metrics_row.dart';
import '../../widgets/profile/profile_pass_card.dart';

/// Full-screen profile page.
///
/// Layout (top → bottom):
///  1. Fixed header with back / settings buttons.
///  2. Profile summary: hexagon-framed avatar, then "User".
///  3. Metrics row (Focus Hours / Day Streak).
///  4. Analytics & insights (AVG SCREEN TIME callout + trend chart).
///  5. Referral & rewards (header line + pass card + Share app button).
///
/// As the user scrolls, the large avatar morphs continuously — shrinking and
/// drifting up — until it settles at the horizontal center of the header as a
/// miniature version. Scrolling back up reverses the morph.
///
/// [onClose] is invoked by the header back button instead of popping the
/// navigator, so the host (e.g. an IndexedStack tab controller) decides how to
/// dismiss the profile view.
class ProfileScreen extends StatefulWidget {
  final VoidCallback onClose;

  const ProfileScreen({super.key, required this.onClose});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _morphRange = 150.0;

  static const _largeAvatarSize = 110.0;
  static const _compactAvatarSize = 96.0;
  static const _headerAvatarSize = 34.0;

  double _largeAvatarSizeFor(BuildContext context) =>
      Responsive.isCompactPhone(context) ? _compactAvatarSize : _largeAvatarSize;

  final _scrollController = ScrollController();
  final _largeAvatarKey = GlobalKey();
  final _headerSlotKey = GlobalKey();
  final _historyService = DailyUsageHistoryService();
  final _streakService = StreakService();

  RulesProvider? _rulesProvider;
  TimerProvider? _timerProvider;
  int _streakCount = 0;

  double _scrollProgress = 0;
  Offset _largeAvatarCenter = Offset.zero;
  Offset _headerSlotCenter = Offset.zero;

  List<double> _dailyHours = const [];
  List<String> _dayLabels = const [];
  double _averageHours = 0;
  int _measuredDayCount = 0;
  bool _historyIsEstimated = false;
  bool _historyLoading = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _rulesProvider = context.read<RulesProvider>();
      _timerProvider = context.read<TimerProvider>();
      _rulesProvider!.addListener(_onRulesChanged);
      _timerProvider!.addListener(_onTimerChanged);
      _captureGeometry();
      _loadProfileData();
    });
  }

  Future<void> _loadProfileData() async {
    await Future.wait([
      _loadUsageHistory(),
      _refreshStreak(),
    ]);
  }

  Future<void> _refreshStreak() async {
    final rules = context.read<RulesProvider>().rules;
    final count = await _streakService.recordAndGetStreak(rules);
    if (!mounted) return;
    setState(() => _streakCount = count);
  }

  void _onRulesChanged() {
    _refreshStreak();
  }

  void _onTimerChanged() {
    _refreshStreak();
  }

  Future<void> _loadUsageHistory() async {
    final screenTime = context.read<ScreenTimeProvider>();
    final fallbackHours = context.read<UserData>().dailyHoursEstimate;
    await screenTime.refreshUsage();
    if (!mounted) return;

    final todayMs = screenTime.data.todayTotal.inMilliseconds;
    final history = await _historyService.loadLast7Days(
      fallbackHoursPerDay: fallbackHours,
      todayTotalMs: screenTime.data.hasPermission ? todayMs : null,
    );
    if (!mounted) return;
    setState(() {
      _dailyHours = history.dailyHours;
      _dayLabels = history.dayLabels;
      _averageHours = history.averageHours;
      _measuredDayCount = history.measuredDayCount;
      _historyIsEstimated = history.isEstimated;
      _historyLoading = false;
    });
  }

  @override
  void dispose() {
    _rulesProvider?.removeListener(_onRulesChanged);
    _timerProvider?.removeListener(_onTimerChanged);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final next =
        (_scrollController.offset / _morphRange).clamp(0.0, 1.0);
    if (next != _scrollProgress) {
      setState(() => _scrollProgress = next);
    }
  }

  /// Measures the large avatar and the header center slot in screen coordinates
  /// so the overlay can lerp between them. Re-runs after layout changes.
  void _captureGeometry() {
    if (!mounted) return;
    final largeCtx = _largeAvatarKey.currentContext;
    final slotCtx = _headerSlotKey.currentContext;
    if (largeCtx == null || slotCtx == null) return;

    final largeBox = largeCtx.findRenderObject() as RenderBox?;
    final slotBox = slotCtx.findRenderObject() as RenderBox?;
    if (largeBox == null || slotBox == null) return;

    final largeCenter = largeBox.localToGlobal(Offset.zero).translate(
          largeBox.size.width / 2,
          largeBox.size.height / 2,
        );
    final slotCenter = slotBox.localToGlobal(Offset.zero).translate(
          slotBox.size.width / 2,
          slotBox.size.height / 2,
        );

    if (largeCenter != _largeAvatarCenter ||
        slotCenter != _headerSlotCenter) {
      setState(() {
        _largeAvatarCenter = largeCenter;
        _headerSlotCenter = slotCenter;
      });
    }
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  void _showShareSnack() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Sharing coming soon'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.surface,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final t = _scrollProgress;
    final displayName = context.watch<UserData>().displayName;
    final largeAvatarSize = _largeAvatarSizeFor(context);
    final horizontalPadding = Responsive.horizontalPadding(context);
    final bottomScrollPadding = Responsive.scrollBottomPadding(context);

    return NotificationListener<ScrollNotification>(
      onNotification: (_) {
        // Recapture geometry in case layout shifted (rotation, keyboard, etc.).
        WidgetsBinding.instance.addPostFrameCallback((_) => _captureGeometry());
        return false;
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: Stack(
          children: [
            // ── Scrollable content ──
            Positioned.fill(
              child: Responsive.centeredContent(
                context: context,
                child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Top spacing so the first section clears the fixed header.
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: MediaQuery.of(context).padding.top + 64,
                    ),
                  ),
                  // 2. Profile summary: avatar + username.
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        // Placeholder avatar kept fully invisible — it only
                        // exists to measure the morph start position via its
                        // GlobalKey. The overlay renders everything so no
                        // hexagon frame is left behind during the morph.
                        Opacity(
                          opacity: 0,
                          child: ProfileAvatar(
                            key: _largeAvatarKey,
                            size: largeAvatarSize,
                            borderWidth: 2.4,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                          child: Text(
                            displayName,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 34,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.5,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SliverToBoxAdapter(child: const SizedBox(height: 28)),
                  // 3. Metrics row.
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: math.max(horizontalPadding, 32),
                      ),
                      child: ProfileMetricsRow(
                        dayStreakValue: '$_streakCount',
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(child: const SizedBox(height: 44)),
                  // 4. Analytics & insights.
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                      child: ProfileAnalyticsSection(
                        dailyHours: _dailyHours,
                        dayLabels: _dayLabels,
                        averageHours: _averageHours,
                        measuredDayCount: _measuredDayCount,
                        isEstimated: _historyIsEstimated,
                        isLoading: _historyLoading,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(child: const SizedBox(height: 40)),
                  // 5. Referral & rewards + Share app button.
                  SliverToBoxAdapter(
                    child: ProfilePassSection(onShareApp: _showShareSnack),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: bottomScrollPadding,
                    ),
                  ),
                ],
              ),
            ),
            ),
            // ── Fixed header with fading background ──
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _HeaderPlate(
                scrollProgress: t,
                headerSlotKey: _headerSlotKey,
                onBackTap: widget.onClose,
                onSettingsTap: _openSettings,
              ),
            ),
            // ── Morphing avatar overlay (topmost) ──
            // A single avatar whose size + position lerps continuously from the
            // large summary avatar to the header center slot as the user
            // scrolls.
            if (_largeAvatarCenter != Offset.zero &&
                _headerSlotCenter != Offset.zero)
              _MorphAvatarOverlay(
                progress: t,
                fromCenter: _largeAvatarCenter,
                toCenter: _headerSlotCenter,
                fromSize: largeAvatarSize,
                toSize: _headerAvatarSize,
              ),
          ],
        ),
      ),
    );
  }
}

/// Header plate: fading background + the back/settings buttons. Includes an
/// invisible 1×1 slot at the horizontal center used to measure the morph
/// target position.
class _HeaderPlate extends StatelessWidget {
  final double scrollProgress;
  final GlobalKey headerSlotKey;
  final VoidCallback onBackTap;
  final VoidCallback onSettingsTap;

  const _HeaderPlate({
    required this.scrollProgress,
    required this.headerSlotKey,
    required this.onBackTap,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final headerHeight = 52.0;
    final solidHeight = topPadding + headerHeight;
    final fadeHeight = 28.0;
    final t = scrollProgress.clamp(0.0, 1.0);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Fading background plate.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: solidHeight + fadeHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.background.withValues(alpha: t),
                  AppTheme.background.withValues(alpha: t),
                  AppTheme.background.withValues(alpha: 0.0),
                ],
                stops: [
                  0.0,
                  solidHeight / (solidHeight + fadeHeight),
                  1.0,
                ],
              ),
            ),
          ),
        ),
        // Header row (back / gear) with a zero-size measurement slot at the
        // exact horizontal center between the two buttons.
        Stack(
          alignment: Alignment.topCenter,
          children: [
            ProfileHeader(
              onBackTap: onBackTap,
              onSettingsTap: onSettingsTap,
            ),
            // Invisible slot pinned to the vertical center of the header row,
            // used only for measuring the morph target.
            Positioned(
              top: topPadding + 6 + 20,
              child: SizedBox(
                key: headerSlotKey,
                width: 1,
                height: 1,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A single avatar that floats above everything, lerping its center position
/// and size between [fromCenter]/[fromSize] and [toCenter]/[toSize] based on
/// [progress] (0 = at the summary, 1 = at the header).
class _MorphAvatarOverlay extends StatelessWidget {
  final double progress;
  final Offset fromCenter;
  final Offset toCenter;
  final double fromSize;
  final double toSize;

  const _MorphAvatarOverlay({
    required this.progress,
    required this.fromCenter,
    required this.toCenter,
    required this.fromSize,
    required this.toSize,
  });

  @override
  Widget build(BuildContext context) {
    final size = _lerpDouble(fromSize, toSize, progress);
    final center = Offset(
      _lerpDouble(fromCenter.dx, toCenter.dx, progress),
      _lerpDouble(fromCenter.dy, toCenter.dy, progress),
    );

    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      child: ProfileAvatar(
        size: size,
        borderWidth: 1.8 + 0.6 * (1 - progress),
        // Glow fades out as the avatar shrinks toward the header.
        showGlow: progress < 0.65,
      ),
    );
  }

  double _lerpDouble(double a, double b, double t) => a + (b - a) * t;
}
