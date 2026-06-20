import AppKit
import Observation
import SalahCore

/// Owns the `NSStatusItem` directly so we can use a fully-attributed title and
/// update it imperatively at the cadence `AppState` chooses. SwiftUI's
/// `MenuBarExtra` can't accept arbitrary attributed titles, which is why we
/// drop down to AppKit here for the LABEL (the dropdown stays SwiftUI).
@MainActor
public final class MenuBarController {

    public let statusItem: NSStatusItem
    private let settings: AppSettings
    private let state: AppState
    private var observationTask: Task<Void, Never>?
    public var onClick: (NSStatusBarButton) -> Void

    public init(settings: AppSettings, state: AppState,
                onClick: @escaping (NSStatusBarButton) -> Void) {
        self.settings = settings
        self.state = state
        self.onClick = onClick
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureButton()
        rebuildLabel()
        startObserving()
    }
    // App-lifetime owner; no deinit cleanup needed.

    // MARK: - Setup

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(buttonPressed(_:))
        button.sendAction(on: [.leftMouseDown])
        button.imagePosition = .imageLeft
    }

    @objc private func buttonPressed(_ sender: NSStatusBarButton) {
        onClick(sender)
    }

    // MARK: - Live label

    private func startObserving() {
        observationTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                    withObservationTracking {
                        _ = self?.state.secondsToNext
                        _ = self?.state.nextPrayer
                        _ = self?.settings.language
                        _ = self?.settings.menuBarShowPrayerName
                        _ = self?.settings.menuBarShowRemainingTime
                        _ = self?.settings.menuBarShowIcon
                        _ = self?.settings.menuBarUseShortNames
                        _ = self?.settings.menuBarCompactSeconds
                    } onChange: {
                        Task { @MainActor in cont.resume() }
                    }
                }
                self?.rebuildLabel()
            }
        }
    }

    private func rebuildLabel() {
        guard let button = statusItem.button else { return }

        button.image = settings.menuBarShowIcon
            ? NSImage(systemSymbolName: "moon.stars.fill", accessibilityDescription: "Salah Times")
            : nil
        button.image?.isTemplate = true

        guard let nextKey = nextPrayerKey() else {
            button.title = "—"
            return
        }

        let inputs = MenuBarLabelFormatter.Inputs(
            nextPrayerKey: nextKey,
            secondsRemaining: state.secondsToNext,
            language: settings.language,
            showName: settings.menuBarShowPrayerName,
            showRemaining: settings.menuBarShowRemainingTime,
            useShortNames: settings.menuBarUseShortNames,
            compactSeconds: settings.menuBarCompactSeconds
        )
        let text = MenuBarLabelFormatter.format(inputs)
        // Urgency tint: switch to system red when the next prayer is closer
        // than 35 min — same threshold as the default "notify before" lead so
        // the menu-bar gives a visual cue at the same moment a notification
        // would normally arrive.
        var attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.menuBarFont(ofSize: 0)
        ]
        if state.secondsToNext > 0 && state.secondsToNext <= Self.urgencyThresholdSeconds {
            attrs[.foregroundColor] = NSColor.systemRed
        }
        button.attributedTitle = NSAttributedString(string: text, attributes: attrs)
    }

    private static let urgencyThresholdSeconds = 35 * 60

    private func nextPrayerKey() -> String? {
        guard let p = state.nextPrayer else { return nil }
        switch p {
        case .fajr:      return "prayer.fajr"
        case .sunrise:   return "prayer.sunrise"
        case .dhuhr:     return "prayer.dhuhr"
        case .asr:       return "prayer.asr"
        case .maghrib:   return "prayer.maghrib"
        case .isha:      return "prayer.isha"
        default:         return nil
        }
    }
}
