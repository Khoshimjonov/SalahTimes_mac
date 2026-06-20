import Foundation

/// One day's worth of computed prayer times.
///
/// Times are stored as fractional hours from local-zone midnight (`nil` if the
/// sun never reaches the required angle and no high-latitude rule produced a
/// value). Use ``time(for:)`` to convert to a wall-clock `Date`.
public struct PrayerTimesDay: Sendable, Equatable {
    public let date: DateComponents     // year/month/day in the location's zone
    public let timeZone: TimeZone

    public let imsak: Double?
    public let fajr: Double?
    public let sunrise: Double?
    public let dhuhr: Double?
    public let asr: Double?
    public let maghrib: Double?
    public let isha: Double?
    public let midnight: Double?
    public let lastThird: Double?

    public enum Prayer: Int, CaseIterable, Sendable {
        case imsak, fajr, sunrise, dhuhr, asr, maghrib, isha, midnight, lastThird
    }

    public func hours(_ prayer: Prayer) -> Double? {
        switch prayer {
        case .imsak:     return imsak
        case .fajr:      return fajr
        case .sunrise:   return sunrise
        case .dhuhr:     return dhuhr
        case .asr:       return asr
        case .maghrib:   return maghrib
        case .isha:      return isha
        case .midnight:  return midnight
        case .lastThird: return lastThird
        }
    }

    /// Wall-clock `Date` for the given prayer in the location's timezone.
    public func time(for prayer: Prayer) -> Date? {
        guard let h = hours(prayer) else { return nil }
        var comps = date
        comps.timeZone = timeZone
        let totalSeconds = Int((h * 3600.0).rounded()) % 86_400
        comps.hour = totalSeconds / 3600
        comps.minute = (totalSeconds % 3600) / 60
        comps.second = totalSeconds % 60
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return cal.date(from: comps)
    }

    /// Formatted as `HH:mm:ss` in the location's timezone (or `"null"` for
    /// missing values). Matches the Java `toJson` time formatting so fixtures
    /// generated on the Java side parse back identically.
    public func formatted(_ prayer: Prayer) -> String {
        guard let h = hours(prayer) else { return "null" }
        let totalSeconds = Int((h * 3600.0).rounded()) % 86_400
        let hh = totalSeconds / 3600
        let mm = (totalSeconds % 3600) / 60
        let ss = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hh, mm, ss)
    }
}
