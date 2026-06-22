import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'models/gem_achievement.dart';
import 'models/gem_unlock_info.dart';
import 'models/user_data.dart';
import 'providers/emergency_pass_provider.dart';
import 'providers/folder_apps_provider.dart';
import 'providers/gem_achievement_provider.dart';
import 'providers/permissions_provider.dart';
import 'providers/rules_provider.dart';
import 'providers/screen_time_provider.dart';
import 'providers/timer_provider.dart';
import 'screens/home/active_timer_shell.dart';
import 'screens/permissions/permissions_gate_screen.dart';
import 'screens/home/home_shell.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/welcome/welcome_gem_screen.dart';
import 'services/rule_notification_service.dart';
import 'theme/app_theme.dart';
import 'widgets/blocking_sync_listener.dart';
import 'widgets/rule_notification_listener.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Preload AppTheme font variants, then disable CDN fetches so later screens
  // don't hit loadFontIfNecessary without a cached glyph. If preload fails
  // (e.g. offline cold start), keep runtime fetching enabled as fallback.
  try {
    await GoogleFonts.pendingFonts([
      GoogleFonts.inter(fontWeight: FontWeight.w400),
      GoogleFonts.inter(fontWeight: FontWeight.w500),
      GoogleFonts.inter(fontWeight: FontWeight.w600),
      GoogleFonts.inter(fontWeight: FontWeight.w700),
      GoogleFonts.orbitron(fontWeight: FontWeight.w700),
    ]);
    GoogleFonts.config.allowRuntimeFetching = false;
  } catch (_) {
    GoogleFonts.config.allowRuntimeFetching = true;
  }
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );
  runApp(const ScreenTimeControllerApp());
}

class ScreenTimeControllerApp extends StatelessWidget {
  const ScreenTimeControllerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserData()),
        ChangeNotifierProvider(create: (_) => ScreenTimeProvider()),
        ChangeNotifierProvider(create: (_) => PermissionsProvider()),
        ChangeNotifierProvider(create: (_) => RulesProvider()),
        ChangeNotifierProvider(create: (_) => EmergencyPassProvider()),
        ChangeNotifierProvider(create: (_) => FolderAppsProvider()),
        ChangeNotifierProvider(create: (_) => GemAchievementProvider()),
        ChangeNotifierProvider(create: (_) => TimerProvider()),
      ],
      child: RuleNotificationListener(
        child: BlockingSyncListener(
          child: Selector<UserData, int>(
            selector: (_, userData) => userData.resetVersion,
            builder: (context, resetVersion, _) {
              return MaterialApp(
                key: ValueKey(resetVersion),
                title: 'Silo',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.darkTheme,
                home: const _AppEntry(),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> with WidgetsBindingObserver {
  bool _welcomeGemChecked = false;
  bool _welcomeGemCheckInFlight = false;
  bool _startupComplete = false;
  bool _startupBypass = false;
  GemUnlockInfo? _welcomeGemInfo;
  UserData? _userData;
  int _lastUserDataResetVersion = 0;
  Timer? _startupWatchdog;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStartupState();
      _attachAccountResetListener();
    });
    _armStartupWatchdog();
  }

  void _armStartupWatchdog() {
    _startupWatchdog?.cancel();
    _startupWatchdog = Timer(const Duration(seconds: 12), () {
      if (!mounted || _startupComplete) return;
      debugPrint('SiloStartup: watchdog fired — bypassing provider gate');
      _forceProvidersInitialized();
      setState(() => _startupBypass = true);
    });
  }

  void _forceProvidersInitialized() {
    context.read<UserData>().ensureInitializedForStartup();
    context.read<PermissionsProvider>().ensureInitializedForStartup();
    context.read<FolderAppsProvider>().ensureInitializedForStartup();
    context.read<TimerProvider>().ensureInitializedForStartup();
    context.read<GemAchievementProvider>().ensureInitializedForStartup();
    context.read<EmergencyPassProvider>().ensureInitializedForStartup();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_startupComplete) {
      debugPrint('SiloStartup: resumed while still loading — retrying');
      _loadStartupState();
    }
  }

  void _attachAccountResetListener() {
    _userData = context.read<UserData>();
    _lastUserDataResetVersion = _userData!.resetVersion;
    _userData!.addListener(_onUserDataChanged);
  }

  void _onUserDataChanged() {
    final userData = _userData;
    if (userData == null || userData.resetVersion == _lastUserDataResetVersion) {
      return;
    }
    _lastUserDataResetVersion = userData.resetVersion;
    setState(() {
      _welcomeGemChecked = false;
      _welcomeGemInfo = null;
    });
  }

  @override
  void dispose() {
    _startupWatchdog?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _userData?.removeListener(_onUserDataChanged);
    super.dispose();
  }

  Future<void> _loadStartupState() async {
    if (!mounted || _startupComplete) return;
    debugPrint('SiloStartup: loading state…');
    final userData = context.read<UserData>();
    final permissions = context.read<PermissionsProvider>();
    final folderApps = context.read<FolderAppsProvider>();
    final timer = context.read<TimerProvider>();
    final gems = context.read<GemAchievementProvider>();
    final emergencyPass = context.read<EmergencyPassProvider>();

    // Prefs-backed state can load in parallel; each provider enforces its own
    // timeout and always marks itself initialized in `finally`.
    await Future.wait([
      userData.loadFromPrefs(),
      folderApps.load(),
      timer.load(),
      gems.load(),
      emergencyPass.load(),
    ]);

    if (!mounted) return;

    // Notifications must finish before permission refresh — both touch the
    // local notifications plugin and can deadlock when started together.
    await _initNotifications();

    if (!mounted) return;
    await permissions.load();

    if (!mounted) return;
    debugPrint('SiloStartup: load complete');
    setState(() => _startupComplete = true);
    _startupWatchdog?.cancel();
  }

  Future<void> _initNotifications() async {
    try {
      await RuleNotificationService.instance.initialize().timeout(
        const Duration(seconds: 8),
      );
    } on TimeoutException {
      debugPrint('RuleNotificationService init timed out');
    } catch (e, stack) {
      debugPrint('RuleNotificationService init failed: $e\n$stack');
    }
  }

  Future<void> _checkWelcomeGem() async {
    if (_welcomeGemChecked || _welcomeGemCheckInFlight) return;
    _welcomeGemCheckInFlight = true;
    GemUnlockInfo? info;
    try {
      final gems = context.read<GemAchievementProvider>();
      info = await gems.prepareWelcomeGem().timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );
    } on TimeoutException {
      debugPrint('Welcome gem check timed out');
    } catch (e, stack) {
      debugPrint('Welcome gem check failed: $e\n$stack');
    } finally {
      _welcomeGemCheckInFlight = false;
    }
    if (!mounted) return;
    setState(() {
      _welcomeGemChecked = true;
      _welcomeGemInfo = info;
    });
  }

  Future<void> _confirmWelcomeGem() async {
    final gems = context.read<GemAchievementProvider>();
    await gems.setSelectedHeroGem(GemAchievementId.firstStreak);
    await gems.markUnlockSheetShown(GemAchievementId.firstStreak);
    if (!mounted) return;
    setState(() => _welcomeGemInfo = null);
  }

  @override
  Widget build(BuildContext context) {
    final userData = context.watch<UserData>();
    final permissions = context.watch<PermissionsProvider>();
    final folderApps = context.watch<FolderAppsProvider>();
    final timer = context.watch<TimerProvider>();
    final gems = context.watch<GemAchievementProvider>();
    final emergencyPass = context.watch<EmergencyPassProvider>();

    final providersReady = userData.initialized &&
        permissions.initialized &&
        folderApps.initialized &&
        timer.initialized &&
        gems.initialized &&
        emergencyPass.initialized;

    if (!providersReady && !_startupBypass) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.highlightPurple),
        ),
      );
    }

    if (!userData.isOnboardingComplete) {
      return const OnboardingScreen();
    }

    if (!permissions.allRequiredGranted) {
      return const PermissionsGateScreen();
    }

    if (timer.isRunning) {
      return const ActiveTimerShell();
    }

    if (!_welcomeGemChecked) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkWelcomeGem());
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.highlightPurple),
        ),
      );
    }

    if (_welcomeGemInfo != null) {
      return WelcomeGemScreen(
        info: _welcomeGemInfo!,
        onConfirm: _confirmWelcomeGem,
      );
    }

    return const HomeShell();
  }
}
