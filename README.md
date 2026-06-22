# Silo

**Monitor your screen time, build healthier habits, and stay in control of distracting apps.**

Silo is a cross-platform Flutter app that tracks daily usage, scores your digital wellness, and helps you pause before opening distracting apps and websites. On Android it enforces rules natively via Usage Stats, Accessibility, and overlay services. On iOS it integrates with the Screen Time API scaffold for usage data and Family Controls.

---

## Features

### Home & wellness score
- **ScreenTimerController score** — a 0–100 wellness score built from three pillars: **Focus**, **Rest**, and **Sleep**
- **Score breakdown** — daily screen time, distraction usage, top-app time, and first/last pickup times compared to your week-to-date averages
- **Streaks** — track consecutive days of healthy usage
- **Gem achievements** — unlock collectible gems for milestones (streaks, perfect pillar scores, completed focus timers, and more)
- **7-day usage chart** on your profile

### Focus timer
- Full-screen countdown sessions with background imagery
- Integrates with your wellness score and gem unlocks

### App & website rules
- **Session rules** — block apps during scheduled time windows (with repeat days and difficulty levels: Normal, Strict, Deep Focus)
- **Time limit rules** — cap daily usage per app
- **Open limit rules** — limit how many times you can open an app per day
- **Website blocking** — block distracting sites in the browser (Android)
- **App folders** — organise distracting apps into curated folders with smart suggestions

### Safety valves
- **Emergency pass** — biometric-protected temporary unblock
- **Hold-to-confirm** actions for destructive or high-friction changes

### Onboarding & permissions
- Guided onboarding with lifetime screen-time estimate
- Permissions gate for Usage Stats, notifications, overlay, accessibility (Android), and Screen Time (iOS)

---

## Platform support

| Capability | Android | iOS |
|---|---|---|
| Real OS usage stats | Yes | Scaffold (Screen Time API channels) |
| Installed-app picker | Yes | FamilyActivityPicker (scaffold) |
| Native app blocking | Yes | Scaffold |
| Website blocking | Yes | — |
| Distracting-app overlay | Yes | — |
| Native rule enforcement | Yes | Scaffold |

Android is the primary enforcement platform today. iOS builds include Screen Time API integration scaffolding; some flows fall back to onboarding estimates until full Family Controls support is wired up.

---

## Tech stack

| Layer | Choices |
|---|---|
| Framework | [Flutter](https://flutter.dev) 3.12+ / Dart 3.12+ |
| State management | [Provider](https://pub.dev/packages/provider) |
| Charts | [fl_chart](https://pub.dev/packages/fl_chart) |
| Typography | [google_fonts](https://pub.dev/packages/google_fonts) (Inter, Orbitron) |
| Local storage | [shared_preferences](https://pub.dev/packages/shared_preferences) |
| Auth | [local_auth](https://pub.dev/packages/local_auth) |
| Notifications | [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) |
| Android usage stats | [usage_stats](https://pub.dev/packages/usage_stats) + custom Kotlin services |
| iOS | Swift method channels for Screen Time / Family Controls |

---

## Project structure

```
lib/
├── main.dart                  # App entry, providers, routing
├── models/                    # Data models (rules, usage, gems, user)
├── providers/                 # ChangeNotifier state (rules, timer, screen time, …)
├── screens/                   # Full-screen views (home, settings, onboarding, …)
├── services/                  # Business logic, platform bridges, scoring
│   └── platform/              # Method-channel wrappers (usage stats, enforcement)
├── theme/                     # Dark theme, typography, colours
├── utils/                     # Formatters, platform capability flags
└── widgets/                   # Reusable UI components

android/                       # Kotlin: UsageStatsHelper, blocking, overlay services
ios/                           # Swift: UsageDataChannel, Family Controls scaffold
test/                          # Unit & widget tests
```

---

## Getting started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) **3.12** or newer
- Xcode 15+ (for iOS builds)
- Android Studio / Android SDK with API 26+ (for Android builds)
- A physical device is recommended — usage stats and blocking do not work reliably on emulators

### Install dependencies

```bash
flutter pub get
```

### Run the app

```bash
# Android (debug)
flutter run -d android

# iOS (debug, requires macOS + Xcode)
flutter run -d ios
```

### Run tests

```bash
flutter test
```

Key test suites cover the score calculator, streak logic, gem achievements, daily usage history, and shared widgets.

---

## Android permissions

Silo requests the following Android permissions at runtime or via system settings:

| Permission | Purpose |
|---|---|
| `PACKAGE_USAGE_STATS` | Read per-app foreground time |
| `SYSTEM_ALERT_WINDOW` | Show distracting-app overlay pill |
| Accessibility Service | Enforce app blocks and open limits |
| `POST_NOTIFICATIONS` | Rule reminders and timer alerts |
| `SCHEDULE_EXACT_ALARM` | Precise rule schedule firing |

Grant Usage Stats and Accessibility from **Settings → Apps → Silo** (or the in-app permissions screen) before expecting blocking to work.

---

## iOS setup

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Ensure your development team and bundle identifier are configured.
3. Enable the **Family Controls** capability if you are extending native enforcement.
4. Build and run on a physical device — Screen Time APIs are not available on the simulator.

---

## Scoring overview

The wellness score is the average of three 0–100 sub-scores:

- **Focus** — penalises time spent in known distracting apps
- **Rest** — rewards lower top-3 app usage relative to total screen time
- **Sleep** — penalises late-night usage (22:00–06:00) against a 120-minute night budget

Progress bars in the score breakdown compare today's values to your Monday-through-today averages.
