import Foundation

/// Strategy for adjusting Fajr/Isha when the sun does not reach the required
/// depression angle (high-latitude locations).
public enum HighLatitudeRule: String, CaseIterable, Sendable, Codable {
    case none
    case nightMiddle
    case oneSeventh
    case angleBased

    /// Fraction of the night to use when computing the Fajr/Isha offset from
    /// sunrise/sunset. The `angleBased` variant is angle-dependent and resolved
    /// inside the calculator, so this returns 0 for it.
    public func nightPortion(forAngle angle: Double) -> Double {
        switch self {
        case .none:        return 0
        case .nightMiddle: return 0.5
        case .oneSeventh:  return 1.0 / 7.0
        case .angleBased:  return angle / 60.0
        }
    }
}
