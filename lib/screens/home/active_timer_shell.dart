import 'package:flutter/material.dart';

import '../../screens/home/timer_screen.dart';
import '../../theme/app_theme.dart';
import '../../widgets/blocking_sync_listener.dart';

/// Full-screen shell shown when a focus timer is active (including cold start).
class ActiveTimerShell extends StatefulWidget {
  const ActiveTimerShell({super.key});

  @override
  State<ActiveTimerShell> createState() => _ActiveTimerShellState();
}

class _ActiveTimerShellState extends State<ActiveTimerShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      syncBlockingPackages(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.background,
      body: TimerScreen(),
    );
  }
}
