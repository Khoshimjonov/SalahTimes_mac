import Foundation

/// Qibla bearing and great-circle distance to the Ka'aba in Makkah.
public enum Qibla {

    /// Ka'aba coordinates used by the Java reference app — keep these exact.
    public static let kaabaLatitude: Double = 21.4225
    public static let kaabaLongitude: Double = 39.8262
    public static let earthRadiusKm: Double = 6371.0

    /// Initial bearing from `coordinates` to the Ka'aba, in degrees from true
    /// North, in the range 0..<360.
    public static func direction(from coordinates: Coordinates) -> Double {
        let lat1 = coordinates.latitude * Astronomy.degToRad
        let lat2 = kaabaLatitude * Astronomy.degToRad
        let dLon = (kaabaLongitude - coordinates.longitude) * Astronomy.degToRad

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)

        let bearing = atan2(y, x) * Astronomy.radToDeg
        return Astronomy.normalize360(bearing)
    }

    /// Great-circle distance to the Ka'aba in kilometres (Haversine).
    public static func distanceKm(from coordinates: Coordinates) -> Double {
        let lat1 = coordinates.latitude * Astronomy.degToRad
        let lat2 = kaabaLatitude * Astronomy.degToRad
        let dLat = (kaabaLatitude - coordinates.latitude) * Astronomy.degToRad
        let dLon = (kaabaLongitude - coordinates.longitude) * Astronomy.degToRad

        let a = sin(dLat / 2) * sin(dLat / 2)
              + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadiusKm * c
    }
}
