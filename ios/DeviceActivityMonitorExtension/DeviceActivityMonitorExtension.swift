import Foundation

#if FAMILY_CONTROLS_ENABLED
import DeviceActivity

/// Enforces schedules, time limits, and focus timer windows when Family Controls is enabled.
@main
final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    // TODO: Handle interval start/end and event thresholds when entitlement is granted.
}
#else

/// Stub principal type so the extension target compiles without Family Controls frameworks.
@objc(DeviceActivityMonitorExtension)
final class DeviceActivityMonitorExtension: NSObject {
    // Family Controls not configured — no monitoring until entitlement is granted.
}

#endif
