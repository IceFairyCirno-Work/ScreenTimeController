import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/folder_apps_provider.dart';
import '../../providers/timer_provider.dart';
import '../../services/installed_apps_cache.dart';
import '../../theme/app_theme.dart';
import '../../widgets/blocking_sync_listener.dart';
import '../../widgets/home/home_bottom_nav.dart';
import '../profile/profile_screen.dart';
import 'home_screen.dart';
import 'my_apps_screen.dart';
import 'timer_screen.dart';

/// Keeps every tab's state alive while fading out → swapping → fading in.
class _FadeIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;

  const _FadeIndexedStack({
    required this.index,
    required this.children,
  });

  @override
  State<_FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<_FadeIndexedStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  int _displayedIndex = 0;
  bool _pendingSwap = false;

  static const _fadeOutDuration = Duration(milliseconds: 150);
  static const _fadeInDuration = Duration(milliseconds: 200);

  @override
  void initState() {
    super.initState();
    _displayedIndex = widget.index;
    _controller = AnimationController(
      vsync: this,
      duration: _fadeInDuration,
      reverseDuration: _fadeOutDuration,
      value: 1.0,
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
      reverseCurve: Curves.easeInOut,
    );
  }

  @override
  void didUpdateWidget(covariant _FadeIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != _displayedIndex && !_pendingSwap) {
      _pendingSwap = true;
      _controller.reverse().then((_) {
        if (!mounted) return;
        setState(() => _displayedIndex = widget.index);
        _pendingSwap = false;
        _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: _pendingSwap,
      child: FadeTransition(
        opacity: _fade,
        child: IndexedStack(
          index: _displayedIndex,
          children: widget.children,
        ),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with TickerProviderStateMixin {
  late int _currentIndex;
  bool _isProfileOpen = false;
  bool _isProfileDismissing = false;
  late final AnimationController _profileDismissController;
  late final Animation<Offset> _profileDismissSlide;

  static const _timerTabIndex = 2;
  static const _profileDismissDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    final timer = context.read<TimerProvider>();
    _currentIndex =
        timer.consumeOpenTimerTab() ? _timerTabIndex : widget.initialTabIndex;
    _profileDismissController = AnimationController(
      vsync: this,
      duration: _profileDismissDuration,
    );
    _profileDismissSlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(1.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _profileDismissController,
      curve: Curves.fastOutSlowIn,
    ));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<FolderAppsProvider>().trySeedDefaultFolders();
      syncBlockingPackages(context);
      InstalledAppsCache.instance.preload();
    });
  }

  @override
  void dispose() {
    _profileDismissController.dispose();
    super.dispose();
  }

  void _openProfile() {
    setState(() => _isProfileOpen = true);
  }

  Future<void> _closeProfile() async {
    if (!_isProfileOpen || _isProfileDismissing) return;
    setState(() => _isProfileDismissing = true);
    await _profileDismissController.forward();
    if (!mounted) return;
    setState(() {
      _isProfileOpen = false;
      _isProfileDismissing = false;
    });
    _profileDismissController.reset();
  }

  void _onNavTap(int index) {
    if (_isProfileOpen && !_isProfileDismissing) {
      setState(() => _currentIndex = index);
      _closeProfile();
      return;
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final showProfile = _isProfileOpen || _isProfileDismissing;
    final showHome = !_isProfileOpen || _isProfileDismissing;

    return Scaffold(
      backgroundColor: AppTheme.background,
      extendBody: true,
      body: Stack(
        children: [
          if (showHome)
            _FadeIndexedStack(
              index: _currentIndex,
              children: [
                HomeScreen(onOpenProfile: _openProfile),
                const MyAppsScreen(),
                const TimerScreen(),
              ],
            ),
          if (showProfile)
            SlideTransition(
              position: _profileDismissSlide,
              child: ProfileScreen(onClose: _closeProfile),
            ),
        ],
      ),
      bottomNavigationBar: HomeBottomNav(
        currentIndex: showProfile && !_isProfileDismissing ? 0 : _currentIndex,
        onTap: _onNavTap,
      ),
    );
  }
}
