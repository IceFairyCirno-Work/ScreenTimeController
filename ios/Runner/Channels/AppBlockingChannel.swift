import Flutter

enum AppBlockingChannel {
    static let name = "com.screentime.screen_time_controller/app_blocking"

    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: name, binaryMessenger: messenger)
        channel.setMethodCallHandler(handle)
    }

    private static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        FamilyControlsBridge.logNotConfigured()

        switch call.method {
        case "syncBlockedPackages", "syncDistractingPackages", "syncActiveTimer",
             "clearActiveTimer", "clearBlockedPackages":
            result(nil)

        case "getActiveTimer":
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
