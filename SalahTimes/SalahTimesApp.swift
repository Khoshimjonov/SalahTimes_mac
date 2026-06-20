import SwiftUI
import AppKit
import UserNotifications
import SalahCore

@main
struct SalahTimesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsRoot(settings: appDelegate.settings)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    let settings = AppSettings()
    lazy var state: AppState = AppState(settings: settings)
    lazy var notifications = PrayerNotificationScheduler(settings: settings)

    private var menuBar: MenuBarController!
    private let popover: NSPopover = {
        let p = NSPopover()
        p.behavior = .transient
        p.animates = true
        return p
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Build the popover content lazily — but install it now so first click is instant.
        let content = DropdownView(
            settings: settings,
            state: state,
            quit: { NSApp.terminate(nil) }
        )
        popover.contentViewController = NSHostingController(rootView: content)
        popover.contentSize = NSSize(width: 360, height: 480)

        menuBar = MenuBarController(settings: settings, state: state) { [weak self] button in
            self?.togglePopover(from: button)
        }

        Task { @MainActor in
            await notifications.requestAuthorizationIfNeeded()
            await notifications.reschedule()
        }

        // Reschedule notifications whenever calc-relevant settings or the day changes.
        Task { @MainActor [weak self] in
            while !Task.isCancelled {
                await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                    withObservationTracking {
                        _ = self?.settings.notifyBefore
                        _ = self?.settings.notifyBeforeMinutes
                        _ = self?.settings.notifyOnTime
                        _ = self?.settings.language
                        _ = self?.state.todayTimes
                    } onChange: {
                        Task { @MainActor in cont.resume() }
                    }
                }
                await self?.notifications.reschedule()
            }
        }
    }

    private func togglePopover(from button: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Activate so keyboard input works in the popover (e.g. text fields).
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // Settings opening is now handled by the SwiftUI @Environment(\.openSettings)
    // action inside DropdownView — no AppKit selector dance needed.
}
