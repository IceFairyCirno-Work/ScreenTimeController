import Flutter
import UIKit

enum UsageDataChannel {
    static let name = "com.screentime.screen_time_controller/usage_data"

    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: name, binaryMessenger: messenger)
        channel.setMethodCallHandler(handle)
    }

    private static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        FamilyControlsBridge.logNotConfigured()

        switch call.method {
        case "hasUsagePermission":
            result(false)

        case "openUsageSettings":
            openSettings()
            result(nil)

        case "getUsageData":
            result(emptyUsagePayload())

        case "getAppIcon":
            result(nil)

        case "getInstalledApps":
            result([])

        case "getDayTotalMs":
            result(nil)

        case "getDayPickupTimes":
            result([
                "firstPickupMs": NSNull(),
                "lastPickupMs": NSNull(),
            ])

        case "getBlockedAppTodayStats":
            result(["opens": 0, "usageMs": 0, "unblocks": 0])

        case "getOpensSince":
            result(0)

        case "recordAppUnblock":
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private static func emptyUsagePayload() -> [String: Any] {
        [
            "todayTotalMs": 0,
            "weekTotalMs": 0,
            "nightUsageMinutes": 0,
            "apps": [],
        ]
    }

    private static func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        DispatchQueue.main.async {
            UIApplication.shared.open(url)
        }
    }
}
