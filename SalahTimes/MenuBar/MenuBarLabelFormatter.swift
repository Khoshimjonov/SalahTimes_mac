import Foundation
import SalahCore

/// Pure formatter for the menu-bar label. Same input → same output, so it's
/// trivially testable without spinning up the timer or the OS status item.
///
/// Format rules:
/// - Always `H:MM`:  "Shom -0:04", "Hufton -1:54"
/// - `< 60 s`:       "-0:42" only when `compactSeconds` is on; otherwise "-0:00"
/// - At fire:        "Shom!" for the first 60 s, then advance.
enum MenuBarLabelFormatter {

    struct Inputs {
        let nextPrayerKey: String       // localised string key
        let secondsRemaining: Int        // can be negative briefly after fire
        let language: String
        let showName: Bool
        let showRemaining: Bool
        let useShortNames: Bool
        let compactSeconds: Bool
    }

    static func format(_ i: Inputs) -> String {
        let nameKey = i.useShortNames ? "prayer.short." + suffix(i.nextPrayerKey)
                                       : i.nextPrayerKey
        let name = LocalizedStrings.string(nameKey, language: i.language)

        var parts: [String] = []
        if i.showName {
            // "Shom!" right at fire moment.
            if i.secondsRemaining <= 0 && i.secondsRemaining > -60 {
                return name + "!"
            }
            parts.append(name)
        }
        if i.showRemaining {
            parts.append(remainingString(seconds: i.secondsRemaining,
                                         compactSeconds: i.compactSeconds))
        }
        return parts.joined(separator: " ")
    }

    private static func suffix(_ key: String) -> String {
        // "prayer.fajr" -> "fajr"
        if let idx = key.lastIndex(of: ".") {
            return String(key[key.index(after: idx)...])
        }
        return key
    }

    private static func remainingString(seconds: Int, compactSeconds: Bool) -> String {
        let s = max(0, seconds)
        if s < 60 && compactSeconds {
            return String(format: "-0:%02d", s)
        }
        let totalMinutes = s / 60
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        return String(format: "-%d:%02d", h, m)
    }
}
