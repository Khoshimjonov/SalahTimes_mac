import Foundation

/// One of the 14 supported prayer-time calculation methods.
///
/// Mirrors `SalahTimesCalculator.CalculationMethod` and `MethodEnum` from the
/// Java reference app. Constants are reproduced verbatim — changing any value
/// here breaks calculation parity with the Java implementation.
public enum CalculationMethod: String, CaseIterable, Sendable, Codable {
    case mwl
    case isna
    case egypt
    case makkah
    case karachi
    case tehran
    case jafari
    case singapore
    case turkey
    case dubai
    case kuwait
    case qatar
    case russia
    case france

    /// Display name as used in the Java app's settings dialog.
    public var displayName: String {
        switch self {
        case .mwl:        return "Muslim World League"
        case .isna:       return "Islamic Society of North America"
        case .egypt:      return "Egyptian General Authority of Survey"
        case .makkah:     return "Umm Al-Qura University, Makkah"
        case .karachi:    return "University of Islamic Sciences, Karachi"
        case .tehran:     return "Institute of Geophysics, University of Tehran"
        case .jafari:     return "Shia Ithna-Ashari, Leva Institute, Qum"
        case .singapore:  return "Singapore Islamic Religious Council"
        case .turkey:     return "Diyanet İşleri Başkanlığı, Turkey"
        case .dubai:      return "Gulf Region"
        case .kuwait:     return "Kuwait"
        case .qatar:      return "Qatar"
        case .russia:     return "Spiritual Administration of Muslims of Russia"
        case .france:     return "Union of Islamic Organizations of France"
        }
    }

    /// Sun depression angle below the horizon at which Fajr begins.
    public var fajrAngle: Double {
        switch self {
        case .mwl:        return 18.0
        case .isna:       return 15.0
        case .egypt:      return 19.5
        case .makkah:     return 18.5
        case .karachi:    return 18.0
        case .tehran:     return 17.7
        case .jafari:     return 16.0
        case .singapore:  return 20.0
        case .turkey:     return 18.0
        case .dubai:      return 18.2
        case .kuwait:     return 18.0
        case .qatar:      return 18.0
        case .russia:     return 16.0
        case .france:     return 12.0
        }
    }

    /// Sun depression angle for Isha. Ignored when ``ishaMinutes`` is non-zero.
    public var ishaAngle: Double {
        switch self {
        case .mwl:        return 17.0
        case .isna:       return 15.0
        case .egypt:      return 17.5
        case .makkah:     return 0.0
        case .karachi:    return 18.0
        case .tehran:     return 14.0
        case .jafari:     return 14.0
        case .singapore:  return 18.0
        case .turkey:     return 17.0
        case .dubai:      return 18.2
        case .kuwait:     return 17.5
        case .qatar:      return 0.0
        case .russia:     return 15.0
        case .france:     return 12.0
        }
    }

    /// When > 0, Isha is `Maghrib + ishaMinutes` instead of an angle-based time.
    /// Used by Makkah (Umm al-Qura) and Qatar.
    public var ishaMinutes: Int {
        switch self {
        case .makkah, .qatar: return 90
        default:              return 0
        }
    }

    /// Stable integer code matching `MethodEnum` in the Java app, used for
    /// settings persistence so the macOS and Java apps share the same config
    /// vocabulary.
    public var code: Int {
        switch self {
        case .karachi:    return 1
        case .isna:       return 2
        case .mwl:        return 3
        case .makkah:     return 4
        case .egypt:      return 5
        case .tehran:     return 7
        case .dubai:      return 8
        case .kuwait:     return 9
        case .qatar:      return 10
        case .singapore:  return 11
        case .france:     return 12
        case .turkey:     return 13
        case .russia:     return 14
        case .jafari:     return 99
        }
    }

    /// Resolves a method by its `MethodEnum` code, falling back to `mwl`
    /// for unknown codes — matches `CalculationMethod.getByCode` in Java.
    public static func byCode(_ code: Int) -> CalculationMethod {
        switch code {
        case 1:        return .karachi
        case 2:        return .isna
        case 3:        return .mwl
        case 4:        return .makkah
        case 5:        return .egypt
        case 7:        return .tehran
        case 8, 16:    return .dubai
        case 9:        return .kuwait
        case 10:       return .qatar
        case 11:       return .singapore
        case 12:       return .france
        case 13:       return .turkey
        case 14:       return .russia
        case 99:       return .jafari
        default:       return .mwl
        }
    }
}
