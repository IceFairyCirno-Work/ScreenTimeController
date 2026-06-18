import 'package:flutter/material.dart';



import '../models/app_rule.dart';



/// Helpers for website targets stored as `web:<domain>` package names in rules.

class WebsiteHelpers {

  WebsiteHelpers._();



  static const websitePackagePrefix = 'web:';



  static bool isWebsitePackage(String packageName) =>

      packageName.startsWith(websitePackagePrefix);



  static String packageForDomain(String domain) =>

      '$websitePackagePrefix$domain';



  static String domainFromPackage(String packageName) {

    if (!isWebsitePackage(packageName)) return packageName;

    return packageName.substring(websitePackagePrefix.length);

  }



  /// Strips scheme, `www.`, and path segments from user input.

  static String normalizeDomain(String input) {

    var value = input.trim().toLowerCase();

    if (value.startsWith('http://')) {

      value = value.substring(7);

    } else if (value.startsWith('https://')) {

      value = value.substring(8);

    }

    if (value.startsWith('www.')) {

      value = value.substring(4);

    }

    final slash = value.indexOf('/');

    if (slash >= 0) {

      value = value.substring(0, slash);

    }

    final query = value.indexOf('?');

    if (query >= 0) {

      value = value.substring(0, query);

    }

    return value;

  }



  /// Accepts domains like `example.com` or `sub.example.co.uk`.

  static bool isValidDomain(String domain) {

    if (domain.isEmpty || domain.length > 253) return false;

    final regex = RegExp(

      r'^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,}$',

    );

    return regex.hasMatch(domain);

  }



  /// Deterministic accent color per domain for list avatars.

  static Color colorForDomain(String domain) {

    final hash = domain.hashCode.abs();

    const hues = [12.0, 28.0, 145.0, 195.0, 220.0, 265.0, 310.0];

    final hue = hues[hash % hues.length];

    return HSLColor.fromAHSL(1.0, hue, 0.52, 0.48).toColor();

  }



  /// Label for rule cards, e.g. `2 apps, 1 website blocked`.

  static String ruleTargetsBlockedLabel(List<AppRuleItem> targets) =>

      _ruleTargetsLabel(targets, prefix: 'blocked');



  /// Label for time-limit rule cards, e.g. `Block 2 apps, 1 website`.

  static String ruleTargetsBlockLabel(List<AppRuleItem> targets) =>

      _ruleTargetsLabel(targets, prefix: 'Block');



  static String _ruleTargetsLabel(

    List<AppRuleItem> targets, {

    required String prefix,

  }) {

    var appCount = 0;

    var websiteCount = 0;

    for (final item in targets) {

      if (isWebsitePackage(item.packageName)) {

        websiteCount++;

      } else {

        appCount++;

      }

    }



    if (appCount == 0 && websiteCount == 0) {

      return prefix == 'Block' ? 'Block 0 apps' : 'No apps blocked';

    }



    final parts = <String>[];

    if (appCount > 0) {

      parts.add('$appCount ${appCount == 1 ? 'app' : 'apps'}');

    }

    if (websiteCount > 0) {

      parts.add(

        '$websiteCount ${websiteCount == 1 ? 'website' : 'websites'}',

      );

    }



    if (prefix == 'Block') {

      return 'Block ${parts.join(', ')}';

    }

    return '${parts.join(', ')} blocked';

  }

}

