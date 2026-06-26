import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_folder.dart';
import '../../models/gem_unlock_info.dart';
import '../../models/screen_time_data.dart';
import '../../models/screen_timer_controller_metrics.dart';
import '../../models/user_data.dart';
import '../../providers/folder_apps_provider.dart';
import '../../providers/gem_achievement_provider.dart';
import '../../providers/rules_provider.dart';
import '../../providers/screen_time_provider.dart';
import '../../providers/timer_provider.dart';
import '../../services/screen_timer_controller_score_calculator.dart';
import '../../services/streak_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../utils/platform_capabilities.dart';
import '../../widgets/home/home_header.dart';
import '../../widgets/home/home_hero.dart';
import '../../widgets/home/metrics_row.dart';
import 'score_breakdown_screen.dart';
import '../../widgets/home/score_section.dart';
import '../../widgets/home/first_step_card.dart';
import '../../widgets/home/gem_unlock_sheet.dart';
import '../../widgets/home/top_today_card.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onOpenProfile;

  const HomeScreen({super.key, this.onOpenProfile});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  static const _contentTopInset = 28.0;
  static const _heroVignetteScrollRange = 220.0;
  // Parallax tuning — the hero image drifts slower than the content so it
  // appears to "follow" the scroll. Values are conservative so the scaled
  // image buffer always covers the translation, even on small screens.
  static const _heroParallaxFactor = 0.3;
  static const _heroParallaxMax = 48.0;

  final _calculator = ScreenTimerControllerScoreCalculator();
  final _streakService = StreakService();
  final _scrollController = ScrollController();
  late final AnimationController _metricsController;
  late final Animation<double> _metricsAnimation;
  RulesProvider? _rulesProvider;
  TimerProvider? _timerProvider;
  int _streakCount = 0;
  double _heroVignetteProgress = 0;
  double _heroParallaxOffset = 0;
  bool _wasTimerRunning = false;
  bool _isShowingUnlockSheet = false;
  bool _isScoreBreakdownOpen = false;
  Future<void>? _evaluateGemsInFlight;

  @override
  void initState() {
    super.initState();
    _metricsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _metricsAnimation = CurvedAnimation(
      parent: _metricsController,
      curve: Curves.easeOutCubic,
    );
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _rulesProvider = context.read<RulesProvider>();
      _timerProvider = context.read<TimerProvider>();
      _wasTimerRunning = _timerProvider!.isRunning;
      _rulesProvider!.addListener(_onRulesChanged);
      _timerProvider!.addListener(_onTimerChanged);
      _init();
    });
  }

  @override
  void dispose() {
    _rulesProvider?.removeListener(_onRulesChanged);
    _timerProvider?.removeListener(_onTimerChanged);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _metricsController.dispose();
    super.dispose();
  }

  void _playMetricsAnimation() {
    if (!mounted) return;
    _metricsController.forward(from: 0);
  }

  void _onRulesChanged() {
    _refreshStreak();
  }

  void _onTimerChanged() {
    final isRunning = _timerProvider?.isRunning ?? false;
    if (_wasTimerRunning == isRunning) return;
    _wasTimerRunning = isRunning;
    _refreshStreak();
  }

  Future<void> _refreshStreak() async {
    final rules = context.read<RulesProvider>().rules;
    final count = await _streakService.recordAndGetStreak(rules);
    if (!mounted) return;
    setState(() => _streakCount = count);
    await _evaluateGems(streakCount: count);
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    final next = (offset / _heroVignetteScrollRange).clamp(0.0, 1.0);
    final nextParallax =
        (offset * _heroParallaxFactor).clamp(0.0, _heroParallaxMax);
    if (next != _heroVignetteProgress || nextParallax != _heroParallaxOffset) {
      setState(() {
        _heroVignetteProgress = next;
        _heroParallaxOffset = nextParallax;
      });
    }
  }

  Future<void> _init() async {
    final provider = context.read<ScreenTimeProvider>();
    final rules = context.read<RulesProvider>().rules;
    // Streak write + usage fetch are independent — run them concurrently.
    final results = await Future.wait([
      _streakService.recordAndGetStreak(rules),
      provider.loadUsage(),
    ]);
    if (!mounted) return;
    final streakCount = results[0] as int;
    setState(() => _streakCount = streakCount);
    _playMetricsAnimation();
    await _evaluateGems(streakCount: streakCount);
  }

  Future<void> _evaluateGems({required int streakCount}) {
    return _evaluateGemsInFlight ??= _evaluateGemsImpl(streakCount: streakCount)
        .whenComplete(() => _evaluateGemsInFlight = null);
  }

  Future<void> _evaluateGemsImpl({required int streakCount}) async {
    final screenTime = context.read<ScreenTimeProvider>();
    final userData = context.read<UserData>();
    final folderApps = context.read<FolderAppsProvider>();
    final timer = context.read<TimerProvider>();
    final gems = context.read<GemAchievementProvider>();

    final distractingPackages = folderApps
        .appsFor(AppFolderType.distracting)
        .map((item) => item.packageName)
        .toSet();
    final metrics = _metricsFrom(
      data: screenTime.data,
      userData: userData,
      distractingPackages: distractingPackages,
      alwaysAllowedPackages: folderApps.alwaysAllowedPackageNames,
    );
    final canAwardMetricGems = screenTime.data.hasPermission &&
        screenTime.data.todayTotal > Duration.zero;

    final pending = await gems.evaluate(
      streakCount: streakCount,
      metrics: metrics,
      metricsHasPermission: canAwardMetricGems,
      timerJustCompleted: timer.consumeTimerNaturallyCompleted(),
    );
    if (!mounted || pending.isEmpty || _isShowingUnlockSheet) return;
    await _showUnlockSheets(pending);
  }

  Future<void> _showUnlockSheets(List<GemUnlockInfo> pending) async {
    if (_isShowingUnlockSheet || pending.isEmpty) return;
    _isShowingUnlockSheet = true;

    try {
      final gems = context.read<GemAchievementProvider>();
      final latest = pending.last;
      final pendingIds = pending.map((info) => info.id).toSet();

      await gems.markUnlockSheetsShown(pendingIds);
      if (!mounted) return;

      final setAsCurrent = await GemUnlockSheet.show(
        context,
        info: latest,
        hasExistingHeroGem: gems.hasSelectedHeroGem,
      );
      if (!mounted) return;
      if (setAsCurrent) {
        await gems.unlockAndSelectHeroGem(latest.id);
      }
    } finally {
      _isShowingUnlockSheet = false;
    }
  }

  Future<void> _refresh() async {
    await context.read<ScreenTimeProvider>().refreshUsage();
    if (!mounted) return;
    _playMetricsAnimation();
    await _evaluateGems(streakCount: _streakCount);
  }

  void _openProfile() {
    widget.onOpenProfile?.call();
  }

  ScreenTimerControllerMetrics _metricsFrom({
    required ScreenTimeData data,
    required UserData userData,
    required Set<String> distractingPackages,
    required Set<String> alwaysAllowedPackages,
  }) {
    final dailyHoursEstimate = !data.hasPermission &&
            !PlatformCapabilities.supportsRealUsageStats
        ? userData.dailyHoursEstimate
        : null;

    return _calculator.calculate(
      data: data,
      distractingHabit: userData.habitToChange,
      distractingFolderPackages: distractingPackages,
      alwaysAllowedPackages: alwaysAllowedPackages,
      dailyHoursEstimate: dailyHoursEstimate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final heroAsset = context.watch<GemAchievementProvider>().heroAssetPath;

    return ColoredBox(
      color: AppTheme.background,
      child: Consumer3<ScreenTimeProvider, UserData, FolderAppsProvider>(
        builder: (context, provider, userData, folderApps, _) {
          final distractingPackages = folderApps
              .appsFor(AppFolderType.distracting)
              .map((item) => item.packageName)
              .toSet();
          final metrics = _metricsFrom(
            data: provider.data,
            userData: userData,
            distractingPackages: distractingPackages,
            alwaysAllowedPackages: folderApps.alwaysAllowedPackageNames,
          );
          final usage = _calculator.usageBreakdown(
            data: provider.data,
            distractingHabit: userData.habitToChange,
            distractingFolderPackages: distractingPackages,
            alwaysAllowedPackages: folderApps.alwaysAllowedPackageNames,
          );
          final baselines = _calculator.weekBaselines(
            data: provider.data,
            distractingHabit: userData.habitToChange,
            distractingFolderPackages: distractingPackages,
            alwaysAllowedPackages: folderApps.alwaysAllowedPackageNames,
          );
          final screenData = provider.data;
          final heroHeight = Responsive.heroHeight(
            context,
            topInset: _contentTopInset,
          );
          final bottomScrollPadding = Responsive.scrollBottomPadding(context);

          return Stack(
            children: [
              // ── Layer 0: hero image + vignette (parallax-aware) ──
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: heroHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    HomeHero(
                      imageAsset: heroAsset,
                      parallaxOffset: _heroParallaxOffset,
                      contentOffset: _contentTopInset,
                    ),
                  ],
                ),
              ),
              // ── Layer 1: scrollable info with fading top edge ──
              Positioned.fill(
                child: RefreshIndicator(
                  color: AppTheme.screenTimerControllerMint,
                  backgroundColor: AppTheme.screenTimerControllerCard,
                  onRefresh: _refresh,
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // Initial gap so info starts below hero (inset shifts content down)
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: heroHeight,
                        ),
                      ),
                      // Fading content section
                      SliverToBoxAdapter(
                        child: Responsive.centeredContent(
                          context: context,
                          child: DecoratedBox(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                AppTheme.background,
                                AppTheme.background,
                              ],
                              stops: [0.0, 0.08, 1.0],
                            ),
                          ),
                          child: Column(
                            children: [
                              ScoreSection(
                                score: metrics.score,
                                onTap: () => setState(
                                  () => _isScoreBreakdownOpen = true,
                                ),
                              ),
                              const SizedBox(height: 18),
                              AnimatedBuilder(
                                animation: _metricsAnimation,
                                builder: (context, _) => MetricsRow(
                                  sleepScore: metrics.sleepScore,
                                  focus: metrics.focus,
                                  rest: metrics.rest,
                                  animationProgress: _metricsAnimation.value,
                                ),
                              ),
                              TopTodayCard(
                                apps: screenData.topApps,
                                hasPermission: screenData.hasPermission,
                              ),
                              FirstStepCard(streakCount: _streakCount),
                              SizedBox(height: bottomScrollPadding),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  ),
                ),
              ),
              // ── Layer 2: sticky app bar with fading edge scrim ──
              if (!_isScoreBreakdownOpen)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _StickyAppBar(
                    streakCount: _streakCount,
                    onProfileTap: _openProfile,
                    scrollProgress: _heroVignetteProgress,
                  ),
                ),
              // ── Layer 3 (topmost): score breakdown overlay ──
              if (_isScoreBreakdownOpen)
                Positioned.fill(
                  child: ScoreBreakdownScreen(
                    onClose: () =>
                        setState(() => _isScoreBreakdownOpen = false),
                    metrics: metrics,
                    usage: usage,
                    baselines: baselines,
                    screenData: screenData,
                    distractingHabit: userData.habitToChange,
                    distractingFolderPackages: distractingPackages,
                    alwaysAllowedPackages:
                        folderApps.alwaysAllowedPackageNames,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Sticky top app bar rendered above every other layer.
///
/// [scrollProgress] (0→1) drives the background opacity: fully transparent at
/// rest so the hero shows through; fades to solid black as the user scrolls so
/// the title stays legible over scrolling content.
class _StickyAppBar extends StatelessWidget {
  final int streakCount;
  final VoidCallback onProfileTap;
  final double scrollProgress;

  const _StickyAppBar({
    required this.streakCount,
    required this.onProfileTap,
    required this.scrollProgress,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final headerHeight = 56.0;
    final solidHeight = topPadding + headerHeight;
    // Fading tail extends past the solid plate for a soft transition.
    final fadeHeight = 28.0;
    final t = scrollProgress.clamp(0.0, 1.0);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          // One continuous gradient: a solid plate (alpha = scrollProgress)
          // across the header, then a short fade to transparent below it.
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
        Padding(
          padding: EdgeInsets.only(top: topPadding + 4),
          child: HomeHeader(
            streakCount: streakCount,
            onProfileTap: onProfileTap,
          ),
        ),
      ],
    );
  }
}
