# Family Controls Setup (iOS)

This project ships a **blank scaffold** for Apple's Screen Time APIs. Native enforcement and usage data remain disabled until Apple grants the Family Controls distribution entitlement for each bundle identifier.

## Current state

- `FamilyControlsBridge.isConfigured` is `false` in `Runner/FamilyControls/FamilyControlsBridge.swift`.
- Method channel stubs log `Family Controls not configured` and return safe empty defaults.
- Extension targets (`DeviceActivityMonitorExtension`, `ShieldConfigurationExtension`) compile with `FAMILY_CONTROLS_ENABLED` **off** (default) and do not link Family Controls frameworks.
- Entitlement files are empty placeholders.

## When Apple approves your entitlement

### 1. Request distribution access

Submit a [Family Controls distribution request](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.family-controls) for **each** bundle ID:

| Target | Bundle ID |
|--------|-----------|
| Runner | `com.screentime.screenTimeController` |
| DeviceActivityMonitorExtension | `com.screentime.screenTimeController.DeviceActivityMonitorExtension` |
| ShieldConfigurationExtension | `com.screentime.screenTimeController.ShieldConfigurationExtension` |

### 2. Enable capabilities in Xcode

For **Runner** and **both extensions**:

1. Open `Runner.xcworkspace` in Xcode.
2. Select the target → **Signing & Capabilities**.
3. Add **Family Controls**.
4. Add **App Groups** with `group.com.screentime.screen_time_controller` (see `Runner/FamilyControls/AppGroupConstants.swift`).

Update entitlement files (currently empty):

- `Runner/Runner.entitlements`
- `DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.entitlements`
- `ShieldConfigurationExtension/ShieldConfigurationExtension.entitlements`

Example keys (add via Xcode Capabilities UI):

```xml
<key>com.apple.developer.family-controls</key>
<true/>
<key>com.apple.security.application-groups</key>
<array>
  <string>group.com.screentime.screen_time_controller</string>
</array>
```

### 3. Enable compile flag and frameworks

1. For Runner and both extension targets, add build setting **Active Compilation Conditions**: `FAMILY_CONTROLS_ENABLED`.
2. Link frameworks as needed:
   - Runner: `FamilyControls`, `ManagedSettings`, `DeviceActivity`
   - DeviceActivityMonitorExtension: `DeviceActivity`
   - ShieldConfigurationExtension: `ManagedSettingsUI`

### 4. Implement native bridge

In `Runner/FamilyControls/FamilyControlsBridge.swift`:

1. Set `isConfigured = true` after entitlements are active.
2. Call `AuthorizationCenter.shared.requestAuthorization(for: .individual)`.
3. Present `FamilyActivityPicker` for app selection (tokens, not bundle IDs).
4. Apply shields via `ManagedSettingsStore`.
5. Schedule `DeviceActivityMonitor` for session rules and time limits.
6. Share state with extensions through the App Group container.

Fill in extension stubs:

- `DeviceActivityMonitorExtension/DeviceActivityMonitorExtension.swift` — interval and event handlers.
- `ShieldConfigurationExtension/ShieldConfigurationExtension.swift` — custom block screen UI.

### 5. Verify on device

Family Controls APIs do not work in Simulator for enforcement. Test on a physical iPhone (iOS 15+).

Expected after wiring:

- `hasScreenTimeAuthorization` / `hasUsagePermission` reflect real authorization.
- `requestScreenTimeAuthorization` returns `{ status: "authorized" | "denied" }` instead of `notConfigured`.
- Blocking and usage channels perform real work instead of no-ops.

## iOS limitations vs Android

- No installed-app list API — app selection uses Apple's picker only.
- No distracting overlay pill or accessibility-based URL blocking.
- Website blocking uses `ManagedSettings` web domains, not browser accessibility.

## Related Dart integration

After native wiring, the Flutter agent should route `PermissionsService`, `ScreenTimeService`, and `AppBlockingService` through the iOS MethodChannels (Phase 1 platform layer). Android behavior should remain unchanged.
