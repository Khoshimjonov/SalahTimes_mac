import Foundation
import ServiceManagement

/// Wraps `SMAppService.mainApp` so the autostart toggle in Settings just sets a
/// `Bool`. Reads the live status from the OS so external changes (user removing
/// the app from System Settings → Login Items) are reflected on next read.
@MainActor
public enum LoginItemManager {

    public static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Returns the resulting `isEnabled` after the call. Failures (e.g. system
    /// denied) are intentionally swallowed — the caller can read back to detect
    /// a no-op, and the failure is also logged.
    @discardableResult
    public static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("LoginItemManager: %@", "\(error)")
        }
        return isEnabled
    }
}
