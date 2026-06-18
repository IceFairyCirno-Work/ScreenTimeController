import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _AppEntryState extends State<_AppEntry> {
  bool _welcomeGemChecked = false;
  GemUnlockInfo? _welcomeGemInfo;
  UserData? _userData;
  int _lastUserDataResetVersion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStartupState();
      _attachAccountResetListener();
    });
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
    _userData?.removeListener(_onUserDataChanged);
    super.dispose();
  }

  Future<void> _loadStartupState() async {
    if (!mounted) return;
    final userData = context.read<UserData>();
    final permissions = context.read<PermissionsProvider>();
    final folderApps = context.read<FolderAppsProvider>();
    final timer = context.read<TimerProvider>();
    final gems = context.read<GemAchievementProvider>();
    final emergencyPass = context.read<EmergencyPassProvider>();
    await Future.wait([
      _initNotifications(),
      userData.loadFromPrefs(),
      permissions.load(),
      folderApps.load(),
      timer.load(),
      gems.load(),
      emergencyPass.load(),
    ]);
  }

  Future<void> _initNotifications() async {
    try {
      await RuleNotificationService.instance.initialize();
    } catch (e, stack) {
      debugPrint('RuleNotificationService init failed: $e\n$stack');
    }
  }

  Future<void> _checkWelcomeGem() async {
    if (_welcomeGemChecked) return;
    GemUnlockInfo? info;
    try {
      final gems = context.read<GemAchievementProvider>();
      info = await gems.prepareWelcomeGem();
    } catch (e, stack) {
      debugPrint('Welcome gem check failed: $e\n$stack');
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

    if (!userData.initialized ||
        !permissions.initialized ||
        !folderApps.initialized ||
        !timer.initialized ||
        !gems.initialized ||
        !emergencyPass.initialized) {
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
