import 'app_rule.dart';

/// Cross-platform app identity helpers for [AppRuleItem].
extension SelectedAppIdentity on AppRuleItem {
  /// Native identifier: iOS ApplicationToken (base64) or Android package name.
  String get nativeId => iosApplicationToken ?? packageName;
}
