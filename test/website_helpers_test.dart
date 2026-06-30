import 'package:flutter_test/flutter_test.dart';
import 'package:screen_time_controller/models/app_rule.dart';
import 'package:screen_time_controller/utils/website_helpers.dart';

void main() {
  group('WebsiteHelpers.normalizeDomain', () {
    test('strips scheme and www', () {
      expect(
        WebsiteHelpers.normalizeDomain('https://www.Example.com/path?q=1'),
        'example.com',
      );
      expect(WebsiteHelpers.normalizeDomain('http://twitter.com'), 'twitter.com');
    });

    test('trims whitespace', () {
      expect(WebsiteHelpers.normalizeDomain('  reddit.com  '), 'reddit.com');
    });
  });

  group('WebsiteHelpers.isValidDomain', () {
    test('accepts common domains', () {
      expect(WebsiteHelpers.isValidDomain('example.com'), isTrue);
      expect(WebsiteHelpers.isValidDomain('sub.example.co.uk'), isTrue);
    });

    test('rejects invalid domains', () {
      expect(WebsiteHelpers.isValidDomain(''), isFalse);
      expect(WebsiteHelpers.isValidDomain('not a domain'), isFalse);
      expect(WebsiteHelpers.isValidDomain('localhost'), isFalse);
    });
  });

  group('WebsiteHelpers package encoding', () {
    test('round-trips domain through web: prefix', () {
      const domain = 'instagram.com';
      final pkg = WebsiteHelpers.packageForDomain(domain);
      expect(WebsiteHelpers.isWebsitePackage(pkg), isTrue);
      expect(WebsiteHelpers.domainFromPackage(pkg), domain);
    });
  });

  group('WebsiteHelpers.colorForDomain', () {
    test('is deterministic per domain', () {
      final a = WebsiteHelpers.colorForDomain('twitter.com');
      final b = WebsiteHelpers.colorForDomain('twitter.com');
      final c = WebsiteHelpers.colorForDomain('facebook.com');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('returns opaque colors', () {
      final color = WebsiteHelpers.colorForDomain('test.com');
      expect(color.a, 1.0);
    });
  });

  group('WebsiteHelpers rule target labels', () {
    final targets = [
      const AppRuleItem(packageName: 'com.app.one', appName: 'One'),
      const AppRuleItem(packageName: 'com.app.two', appName: 'Two'),
      AppRuleItem(
        packageName: WebsiteHelpers.packageForDomain('news.com'),
        appName: 'News',
      ),
    ];

    test('blocked label pluralizes apps and websites', () {
      expect(
        WebsiteHelpers.ruleTargetsBlockedLabel(targets),
        '2 apps, 1 website blocked',
      );
    });

    test('block label prefixes with Block', () {
      expect(
        WebsiteHelpers.ruleTargetsBlockLabel(targets),
        'Block 2 apps, 1 website',
      );
    });

    test('empty targets', () {
      expect(WebsiteHelpers.ruleTargetsBlockedLabel([]), 'No apps blocked');
      expect(WebsiteHelpers.ruleTargetsBlockLabel([]), 'Block 0 apps');
    });

    test('singular forms', () {
      expect(
        WebsiteHelpers.ruleTargetsBlockedLabel([
          const AppRuleItem(packageName: 'com.a', appName: 'A'),
        ]),
        '1 app blocked',
      );
      expect(
        WebsiteHelpers.ruleTargetsBlockedLabel([
          AppRuleItem(
            packageName: WebsiteHelpers.packageForDomain('x.com'),
            appName: 'X',
          ),
        ]),
        '1 website blocked',
      );
    });
  });
}
