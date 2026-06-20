import Foundation

/// Geographic location used by the prayer-times calculator.
///
/// Matches the constructor contract of `SalahTimesCalculator.Coordinates` —
/// elevation is clamped to non-negative, timezone defaults to the system zone.
public struct Coordinates: Sendable, Equatable {
    public let latitude: Double
    public let longitude: Double
    public let elevation: Double
    public let timeZone: TimeZone

    public init(
        latitude: Double,
        longitude: Double,
        elevation: Double = 0,
        timeZone: TimeZone = .current
    ) {
        // Clamp out-of-range or NaN values rather than crashing — bad data
        // can flow in from settings.json or geocoder responses, and a hard
        // precondition would make the whole app unusable on a single corrupt
        // value. Valid inputs round-trip unchanged so parity is preserved.
        let lat = latitude.isFinite ? min(90, max(-90, latitude)) : 0
        let lon = longitude.isFinite ? min(180, max(-180, longitude)) : 0
        let elev = elevation.isFinite ? max(0, elevation) : 0
        self.latitude = lat
        self.longitude = lon
        self.elevation = elev
        self.timeZone = timeZone
    }
}
