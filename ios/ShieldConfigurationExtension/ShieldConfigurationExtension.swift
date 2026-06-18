import Foundation

#if FAMILY_CONTROLS_ENABLED
import ManagedSettingsUI

/// Custom block screen (replaces Android BlockOverlayActivity) when Family Controls is enabled.
@main
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    // TODO: Return branded shield configuration when entitlement is granted.
}
#else

/// Stub principal type so the extension target compiles without Family Controls frameworks.
@objc(ShieldConfigurationExtension)
final class ShieldConfigurationExtension: NSObject {
    // Family Controls not configured — system default shield until entitlement is granted.
}

#endif
