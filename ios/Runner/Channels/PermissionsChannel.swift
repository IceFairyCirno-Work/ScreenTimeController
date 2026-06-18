import Flutter
import UIKit

enum PermissionsChannel {
    static let name = "com.screentime.screen_time_controller/permissions"

    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: name, binaryMessenger: messenger)
        channel.setMethodCallHandler(handle)
    }

    private static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "hasScreenTimeAuthorization":
            FamilyControlsBridge.logNotConfigured()
            result(FamilyControlsBridge.hasAuthorization())

        case "requestScreenTimeAuthorization":
            result(FamilyControlsBridge.requestAuthorization())

        case "openScreenTimeSettings":
            openSettings()
            result(nil)

        case "hasOverlayPermission":
            FamilyControlsBridge.logNotConfigured()
            result(false)

        case "openOverlaySettings":
            openSettings()
            result(nil)

        case "hasAccessibilityPermission":
            FamilyControlsBridge.logNotConfigured()
            result(false)

        case "openAccessibilitySettings":
            openSettings()
            result(nil)

        case "hasNotificationPermission":
            result(false)

        case "requestNotificationPermission":
            result(false)

        case "openNotificationSettings":
            openSettings()
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private static func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        DispatchQueue.main.async {
            UIApplication.shared.open(url)
        }
    }
}
