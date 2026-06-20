# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

Native macOS menu-bar app (`LSUIElement=YES`, macOS 14+, SwiftUI + AppKit interop) that ports the prayer-time math from a sibling Java/Swing app at `~/From Windows/projects/Personal/SalahTimes/`. **That Java tree is the read-only reference implementation** — never edit it; port from it. The macOS rebuild lives entirely in this directory.

## Build / test / run

XcodeGen owns the Xcode project — `project.yml` is the source of truth, `SalahTimes.xcodeproj` is generated. Edit `project.yml` and re-run `xcodegen generate` whenever sources, resources, or build settings change. Never hand-edit `project.pbxproj`.

```sh
# Regenerate Xcode project after editing project.yml
xcodegen generate

# Build the app
xcodebuild -project SalahTimes.xcodeproj -scheme SalahTimes \
           -configuration Debug -destination 'platform=macOS' build

# Run the calculation core's tests in isolation (no Xcode needed)
cd SalahCore && swift test

# Run a single test
cd SalahCore && swift test --filter CalculationParityTests/testPrayerTimesParity
```

Built `.app` lands in `~/Library/Developer/Xcode/DerivedData/SalahTimes-*/Build/Products/Debug/SalahTimes.app`; launch with `open`.

## Architecture

Two-layer split, deliberately:

- **`SalahCore/`** — Standalone SwiftPM package. Pure value types, `Sendable`, zero UI/Foundation-app dependencies, callable from any actor. All prayer-time, Hijri, qibla, and astronomy math lives here. Consumed by the app target as a local SwiftPM package via `project.yml`. Builds and tests without Xcode.
  - `PrayerTimesCalculator.swift` is a **line-by-line port** of `SalahTimesCalculator.java`. Method structure mirrors the Java intentionally so the parity test can exercise every code path.
- **`SalahTimes/`** — Xcode app target. Feature folders (`MenuBar/`, `Settings/`, `Location/`, `Notifications/`, `Autostart/`, `Calendar/`, `UI/`, `Resources/{en,uz,ru}.lproj/`). `SalahTimesApp.swift` wires it together: `AppDelegate` owns `AppSettings`, `AppState`, `MenuBarController`, the popover hosting `DropdownView`, and `PrayerNotificationScheduler`. Notification rescheduling uses `withObservationTracking` to react to settings/day changes without timers.
- **`tools/fixture-generator/FixtureGenerator.java`** — Self-contained Java program (no Maven, no Lombok) that copies the Java reference math **verbatim** and emits JSON fixtures to `SalahCore/Tests/SalahCoreTests/Fixtures/`. Compile with `javac`, run with `java`.

## Calculation parity is a hard contract

The Swift calculator must produce **second-identical** output to the Java reference for every (lat, lon, elev, tz, method, school, hi-lat rule, imsak, date) combination. Currently 0-second drift across 8064 cases in `CalculationParityTests`.

Rules:
- Don't "improve" or "simplify" math in `SalahCore/Sources/SalahCore/` without first updating `FixtureGenerator.java`, regenerating fixtures, and confirming 0-drift.
- If the Java reference math itself changes, port it verbatim into both the Swift calculator and the fixture generator together.
- Never touch these constants without re-verification: `0.833`, `0.0347`, `2451545.0`, `357.529`, `0.98560028`, `280.459`, `0.98564736`, `1.915`, `0.020`, `23.439`, `0.00000036`, `1948439.5`, `10631.0`, the leap-year set `{2,5,7,10,13,16,18,21,24,26,29}`, and the Fajr/Isha angles per method.
- `asrHourAngle` deliberately mixes radians (`shadowAngle = atan(...)`) with degree-based helpers — the Java does the same. Don't unify the units; the parity test depends on this exact behaviour.

### Regenerating fixtures

```sh
cd tools/fixture-generator
javac FixtureGenerator.java
java  FixtureGenerator ../../SalahCore/Tests/SalahCoreTests/Fixtures
```
