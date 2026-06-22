import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_data.dart';
import '../../models/app_permission.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/screen_time_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/platform_capabilities.dart';
import '../../widgets/next_button.dart';
import '../../widgets/option_card.dart';
import '../../widgets/onboarding/lifetime_years_wheel.dart';
import '../../widgets/progress_indicator.dart';
import '../../widgets/settings/permissions_group_list.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  int _highestQuestionReached = 0;
  int _highestResultStepReached = 0;

  static const _questionCount = 4;
  static const _resultIntroPage = 4;
  static const _calculationPage = 5;
  static const _goodNewsPage = 6;
  static const _permissionPage = 7;
  static const _resultStepCount = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recoverInterruptedOnboarding();
    });
  }

  /// If the user finished the questionnaire but the app restarted while they
  /// were granting permissions in system settings, route them to the
  /// post-onboarding permission gate instead of page 0.
  Future<void> _recoverInterruptedOnboarding() async {
    final userData = context.read<UserData>();
    if (userData.isOnboardingComplete) return;
    if (userData.dailyScreenTime == null ||
        userData.habitToChange == null ||
        userData.ageRange == null ||
        userData.occupation == null) {
      return;
    }
    await userData.markOnboardingComplete();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _currentPage == _permissionPage) {
      _handlePermissionResume();
    }
  }

  Future<void> _handlePermissionResume() async {
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

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _nextPage() {
    if (_currentPage == _goodNewsPage) {
      context.read<UserData>().markOnboardingComplete();
      return;
    }
    if (_currentPage < _permissionPage) {
      _goToPage(_currentPage + 1);
    }
  }

  void _onQuestionProgressTap(int step) {
    if (step <= _highestQuestionReached && step < _questionCount) {
      _goToPage(step);
    }
  }

  void _onResultProgressTap(int step) {
    if (step <= _highestResultStepReached && step < _resultStepCount) {
      _goToPage(_resultIntroPage + step);
    }
  }

  int get _resultStep =>
      (_currentPage - _resultIntroPage).clamp(0, _resultStepCount - 1);

  Future<void> _requestPermission() async {
    final permissions = context.read<PermissionsProvider>();
    final screenTime = context.read<ScreenTimeProvider>();

    await permissions.refresh();

    if (permissions.allRequiredGranted) {
      if (permissions.isGranted(AppPermissionType.screenTime)) {
        await screenTime.loadUsage();
      }
      _goToHome();
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

  void _goToHome() {
    final permissions = context.read<PermissionsProvider>();
    if (!permissions.allRequiredGranted) return;

    context.read<UserData>().markOnboardingComplete();
  }

  bool _canContinue(UserData userData) {
    switch (_currentPage) {
      case 0:
        return userData.dailyScreenTime != null;
      case 1:
        return userData.habitToChange != null;
      case 2:
        return userData.ageRange != null;
      case 3:
        return userData.occupation != null;
      default:
        return true;
    }
  }

  String _continueLabel() {
    if (_currentPage == 3) return 'See My Results';
    if (_currentPage == _permissionPage) return 'Set Up Permissions';
    return 'Continue';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            if (_currentPage < _questionCount)
              OnboardingProgressIndicator(
                currentStep: _currentPage,
                totalSteps: _questionCount,
                maxReachableStep:
                    _highestQuestionReached.clamp(0, _questionCount - 1),
                onStepTap: _onQuestionProgressTap,
              )
            else if (_currentPage <= _goodNewsPage)
              OnboardingProgressIndicator(
                currentStep: _resultStep,
                totalSteps: _resultStepCount,
                maxReachableStep:
                    _highestResultStepReached.clamp(0, _resultStepCount - 1),
                onStepTap: _onResultProgressTap,
              ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) {
                  if (page == _permissionPage) {
                    context.read<UserData>().markOnboardingComplete();
                  }
                  setState(() {
                    _currentPage = page;
                    if (page < _questionCount) {
                      if (page > _highestQuestionReached) {
                        _highestQuestionReached = page;
                      }
                    } else if (page <= _goodNewsPage) {
                      final step = page - _resultIntroPage;
                      if (step > _highestResultStepReached) {
                        _highestResultStepReached = step;
                      }
                    }
                  });
                },
                children: [
                  _QuestionPage(
                    title: 'What is your daily\naverage Screen Time?',
                    subtitle: 'On your phone only. Your best guess is ok.',
                    options: const [
                      'Under 1 hour',
                      '1-3 hours',
                      '3-4 hours',
                      '4-5 hours',
                      '5-7 hours',
                      'More than 7 hours',
                    ],
                    selected: context.watch<UserData>().dailyScreenTime,
                    onSelect: context.read<UserData>().setDailyScreenTime,
                  ),
                  _QuestionPage(
                    title: 'What habit would you\nlike to change?',
                    subtitle: 'We\'ll help you build healthier habits.',
                    options: const [
                      'Social Media',
                      'Gaming',
                      'Streaming',
                      'Browsing',
                      'Notifications',
                      'Other',
                    ],
                    selected: context.watch<UserData>().habitToChange,
                    onSelect: context.read<UserData>().setHabitToChange,
                  ),
                  _QuestionPage(
                    title: 'How old are you?',
                    subtitle: 'This helps us personalize your experience.',
                    options: const [
                      'Under 18',
                      '18-24',
                      '25-34',
                      '35-44',
                      '45-54',
                      '55+',
                    ],
                    selected: context.watch<UserData>().ageRange,
                    onSelect: context.read<UserData>().setAgeRange,
                  ),
                  _QuestionPage(
                    title: 'What is your\noccupation?',
                    subtitle: 'We\'ll tailor insights for your lifestyle.',
                    options: const [
                      'Student',
                      'Professional',
                      'Freelancer',
                      'Homemaker',
                      'Retired',
                      'Other',
                    ],
                    selected: context.watch<UserData>().occupation,
                    onSelect: context.read<UserData>().setOccupation,
                  ),
                  const _ResultIntroContent(),
                  _CalculationContent(
                    shouldAnimate: _currentPage == _calculationPage,
                  ),
                  _GoodNewsContent(
                    shouldAnimate: _currentPage == _goodNewsPage,
                  ),
                  const _PermissionContent(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Consumer<UserData>(
                builder: (context, userData, _) {
                  if (_currentPage == _permissionPage) {
                    final permissions = context.watch<PermissionsProvider>();
                    return NextButton(
                      text: _permissionCtaLabel(permissions),
                      onTap: _requestPermission,
                    );
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_currentPage == _calculationPage) ...[
                        const _CalculationDisclaimer(),
                        const SizedBox(height: 16),
                      ],
                      if (_currentPage == _goodNewsPage) ...[
                        const _GoodNewsDisclaimer(),
                        const SizedBox(height: 16),
                      ],
                      NextButton(
                        text: _continueLabel(),
                        isEnabled: _canContinue(userData),
                        onTap: _nextPage,
                      ),
                    ],
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

class _QuestionPage extends StatelessWidget {
  static final _titleStyle = AppTheme.headingLarge.copyWith(fontSize: 24);

  final String title;
  final String subtitle;
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelect;

  const _QuestionPage({
    required this.title,
    required this.subtitle,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(title, style: _titleStyle),
          const SizedBox(height: 8),
          Text(subtitle, style: AppTheme.bodyMedium),
          const SizedBox(height: 28),
          Expanded(
            child: ListView.separated(
              itemCount: options.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final option = options[index];
                return OptionCard(
                  label: option,
                  isSelected: selected == option,
                  onTap: () => onSelect(option),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultIntroContent extends StatelessWidget {
  const _ResultIntroContent();

  @override
  Widget build(BuildContext context) {
    return _CenteredResultPage(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Text(
        'We\'ve got some not-so-good news about your screen time — '
        'and some great news about what you can do about it.',
        style: AppTheme.bodyLarge.copyWith(height: 1.6),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _CalculationContent extends StatelessWidget {
  final bool shouldAnimate;

  const _CalculationContent({required this.shouldAnimate});

  @override
  Widget build(BuildContext context) {
    final userData = context.watch<UserData>();
    final daysThisYear = userData.daysSpentThisYear.round();
    final lifetimeYears = userData.lifetimeYearsOnScreen;

    return _CenteredResultPage(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: AppTheme.bodyLarge.copyWith(height: 1.6),
              children: [
                const TextSpan(
                  text: 'The bad news is that you\'ll spend ',
                ),
                TextSpan(
                  text: '$daysThisYear days',
                  style: AppTheme.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.highlightPurple,
                    height: 1.6,
                  ),
                ),
                const TextSpan(
                  text:
                      ' on your phone this year. Meaning that you\'re on track to spend',
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          OnboardingLifetimeYearsWheel(
            lifetimeYears: lifetimeYears,
            animate: shouldAnimate,
          ),
          const SizedBox(height: 20),
          Text(
            'of your life looking down at your phone. Yep, you read this right.',
            style: AppTheme.bodyLarge.copyWith(height: 1.6),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _GoodNewsContent extends StatelessWidget {
  final bool shouldAnimate;

  const _GoodNewsContent({required this.shouldAnimate});

  @override
  Widget build(BuildContext context) {
    final reclaimableYears = context.watch<UserData>().reclaimableLifetimeYears;

    return _CenteredResultPage(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'The good news is that Silo can help you get back',
            style: AppTheme.bodyLarge.copyWith(height: 1.6),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          OnboardingLifetimeYearsWheel(
            lifetimeYears: reclaimableYears,
            animate: shouldAnimate,
            suffix: ' years+',
          ),
          const SizedBox(height: 20),
          Text(
            'of your life free from distractions, and help you achieve your dreams.',
            style: AppTheme.bodyLarge.copyWith(height: 1.6),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _CalculationDisclaimer extends StatelessWidget {
  const _CalculationDisclaimer();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Projection of your current Screen Time habits, based on an average 16 waking hours each day.',
      style: AppTheme.bodySmall.copyWith(
        color: AppTheme.textSecondary,
        height: 1.5,
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// Vertically centers result-page content while still allowing scroll on
/// short screens or with large accessibility text.
class _CenteredResultPage extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final Widget child;

  const _CenteredResultPage({
    required this.padding,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: child),
          ),
        );
      },
    );
  }
}

class _GoodNewsDisclaimer extends StatelessWidget {
  const _GoodNewsDisclaimer();

  @override
  Widget build(BuildContext context) {
    return Text(
      'According to your profile combined with Silo program',
      style: AppTheme.bodySmall.copyWith(
        color: AppTheme.textSecondary,
        height: 1.5,
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _PermissionContent extends StatefulWidget {
  const _PermissionContent();

  @override
  State<_PermissionContent> createState() => _PermissionContentState();
}

class _PermissionContentState extends State<_PermissionContent> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PermissionsProvider>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'Permissions',
            style: AppTheme.headingLarge,
          ),
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
    );
  }
}
