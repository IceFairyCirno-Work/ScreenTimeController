import 'package:flutter/material.dart';import 'package:provider/provider.dart';

import '../../models/app_permission.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/screen_time_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/platform_capabilities.dart';
import '../../widgets/next_button.dart';
import '../../widgets/settings/permissions_group_list.dart';

/// Full-screen gate shown until all required permissions are granted.
/// Used after onboarding and for returning users who skipped permissions.
class PermissionsGateScreen extends StatefulWidget {
  final VoidCallback? onAllGranted;

  const PermissionsGateScreen({super.key, this.onAllGranted});

  @override
  State<PermissionsGateScreen> createState() => _PermissionsGateScreenState();
}

class _PermissionsGateScreenState extends State<PermissionsGateScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final permissions = context.read<PermissionsProvider>();
    final screenTime = context.read<ScreenTimeProvider>();

    await permissions.refresh();

    if (permissions.isGranted(AppPermissionType.screenTime)) {
      await screenTime.loadUsage();
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _requestNext() async {
    final permissions = context.read<PermissionsProvider>();

    await permissions.refresh();

    if (permissions.allRequiredGranted) {
      widget.onAllGranted?.call();
      return;
    }

    if (!PlatformCapabilities.supportsNativeBlocking) {
      return;
    }

    await permissions.requestNextRequired();
  }

  String _permissionCtaLabel(PermissionsProvider permissions) {
    if (PlatformCapabilities.isIOS) return 'Continue';
    return permissions.allRequiredGranted ? 'Confirm' : 'Set Up Permissions';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),
                    Text('Permissions', style: AppTheme.headingLarge),
                    const SizedBox(height: 8),
                    Text(
                      PlatformCapabilities.isIOS
                          ? 'Optional notifications keep you on track. Screen-time stats and app blocking are available on Android.'
                          : 'Silo needs a few permissions to track your screen time, pause distracting apps, and block websites.',
                      style: AppTheme.bodyMedium,
                    ),
                    const SizedBox(height: 28),
                    const PermissionsGroupList(lockRequiredWhenGranted: true),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Consumer<PermissionsProvider>(
                builder: (context, permissions, _) {
                  return NextButton(
                    text: _permissionCtaLabel(permissions),
                    onTap: _requestNext,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
