import 'package:flutter_test/flutter_test.dart';
import 'package:screen_time_controller/models/app_folder.dart';
import 'package:screen_time_controller/models/screen_time_data.dart';
import 'package:screen_time_controller/services/default_folder_seeder.dart';

void main() {
  group('buildDefaultFolderAppsFromInstalled', () {
    test('matches all installed apps that fit each target name', () {
      final installed = [
        const AppUsageItem(
          appName: 'Instagram',
          packageName: 'com.instagram.android',
          usage: Duration.zero,
        ),
        const AppUsageItem(
          appName: 'Instagram Lite',
          packageName: 'com.instagram.lite',
          usage: Duration.zero,
        ),
        const AppUsageItem(
          appName: 'YouTube',
          packageName: 'com.google.android.youtube',
          usage: Duration.zero,
        ),
        const AppUsageItem(
          appName: 'YouTube Music',
          packageName: 'com.google.android.apps.youtube.music',
          usage: Duration.zero,
        ),
        const AppUsageItem(
          appName: 'Play Store',
          packageName: 'com.android.vending',
          usage: Duration.zero,
        ),
        const AppUsageItem(
          appName: 'Google Play Games',
          packageName: 'com.google.android.play.games',
          usage: Duration.zero,
        ),
        const AppUsageItem(
          appName: 'WhatsApp',
          packageName: 'com.whatsapp',
          usage: Duration.zero,
        ),
        const AppUsageItem(
          appName: 'WhatsApp Business',
          packageName: 'com.whatsapp.w4b',
          usage: Duration.zero,
        ),
        const AppUsageItem(
          appName: 'Google Chrome',
          packageName: 'com.android.chrome',
          usage: Duration.zero,
        ),
        const AppUsageItem(
          appName: 'Chrome Beta',
          packageName: 'com.chrome.beta',
          usage: Duration.zero,
        ),
        const AppUsageItem(
          appName: 'Gmail',
          packageName: 'com.google.android.gm',
          usage: Duration.zero,
        ),
      ];

      final folders = buildDefaultFolderAppsFromInstalled(installed);

      expect(
        folders[AppFolderType.distracting]!.map((item) => item.appName).toList(),
        ['Instagram', 'Instagram Lite', 'YouTube'],
      );
      expect(
        folders[AppFolderType.alwaysAllowed]!
            .map((item) => item.appName)
            .toList(),
        [
          'Play Store',
          'WhatsApp',
          'WhatsApp Business',
          'Google Chrome',
          'Chrome Beta',
          'Gmail',
        ],
      );
      expect(folders[AppFolderType.neverAllowed], isEmpty);
    });

    test('excludes YouTube Music and Google Play Games', () {
      final folders = buildDefaultFolderAppsFromInstalled(const [
        AppUsageItem(
          appName: 'YouTube Music',
          packageName: 'com.google.android.apps.youtube.music',
          usage: Duration.zero,
        ),
        AppUsageItem(
          appName: 'Google Play Games',
          packageName: 'com.google.android.play.games',
          usage: Duration.zero,
        ),
        AppUsageItem(
          appName: 'Play Games',
          packageName: 'com.google.android.play.games',
          usage: Duration.zero,
        ),
      ]);

      expect(folders[AppFolderType.distracting], isEmpty);
      expect(folders[AppFolderType.alwaysAllowed], isEmpty);
    });

    test('returns empty folders when no target apps are installed', () {
      final folders = buildDefaultFolderAppsFromInstalled(const [
        AppUsageItem(
          appName: 'Calculator',
          packageName: 'com.android.calculator2',
          usage: Duration.zero,
        ),
      ]);

      expect(folders[AppFolderType.distracting], isEmpty);
      expect(folders[AppFolderType.alwaysAllowed], isEmpty);
    });
  });
}
