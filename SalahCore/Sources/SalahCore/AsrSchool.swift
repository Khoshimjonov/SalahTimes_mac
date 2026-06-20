import Foundation

/// Juristic method for Asr time calculation — selects the shadow-length ratio
/// at which Asr begins.
public enum AsrSchool: String, CaseIterable, Sendable, Codable {
    /// Shafi'i, Maliki, Hanbali — Asr when shadow length equals object length.
    case shafii
    /// Hanafi — Asr when shadow length equals twice the object length.
    case hanafi

    /// Shadow ratio used in the Asr hour-angle formula.
    public var shadowRatio: Int {
        switch self {
        case .shafii: return 1
        case .hanafi: return 2
        }
    }

    /// Mirrors the Java `school` config field: 0 = Shafi'i, 1 = Hanafi.
    public var code: Int {
        switch self {
        case .shafii: return 0
        case .hanafi: return 1
        }
    }

    public static func byCode(_ code: Int) -> AsrSchool {
        code == 1 ? .hanafi : .shafii
    }
}
