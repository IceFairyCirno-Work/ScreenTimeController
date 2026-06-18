import Foundation

/// Central gate for Family Controls APIs. Stubs return safe defaults until Apple grants distribution.
enum FamilyControlsBridge {
    static let isConfigured = false

    private static let logMessage = "Family Controls not configured"

    static func logNotConfigured() {
        NSLog("%@", logMessage)
    }

    static func requestAuthorization() -> [String: Any] {
        logNotConfigured()
        return ["status": "notConfigured"]
    }

    static func hasAuthorization() -> Bool {
        logNotConfigured()
        return false
    }
}
