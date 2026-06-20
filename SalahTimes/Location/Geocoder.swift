import Foundation

/// Thin async wrapper around Nominatim (free OSM geocoder) and open-elevation.
/// Used only when the user explicitly clicks "Look up" in Settings — never
/// during normal app operation, so it costs nothing on the hot path.
public struct Geocoder: Sendable {

    public struct Result: Sendable {
        public let displayName: String
        public let latitude: Double
        public let longitude: Double
        public let elevation: Double  // metres, 0 if elevation lookup failed
    }

    public enum Failure: Error { case noResult, network }

    public let userAgent: String

    public init(userAgent: String = "SalahTimes-macOS/1.0 (uz.khoshimjonov.SalahTimes)") {
        self.userAgent = userAgent
    }

    public func lookup(address: String) async throws -> Result {
        var comps = URLComponents(string: "https://nominatim.openstreetmap.org/search")!
        comps.queryItems = [
            URLQueryItem(name: "q", value: address),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "limit", value: "1")
        ]
        var req = URLRequest(url: comps.url!)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: req)
        guard let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = arr.first,
              let latStr = first["lat"] as? String,
              let lonStr = first["lon"] as? String,
              let lat = Double(latStr), let lon = Double(lonStr) else {
            throw Failure.noResult
        }
        let displayName = first["display_name"] as? String ?? address
        let elev = (try? await lookupElevation(latitude: lat, longitude: lon)) ?? 0
        return Result(displayName: displayName, latitude: lat, longitude: lon, elevation: elev)
    }

    public func lookupElevation(latitude: Double, longitude: Double) async throws -> Double {
        var comps = URLComponents(string: "https://api.open-elevation.com/api/v1/lookup")!
        comps.queryItems = [URLQueryItem(name: "locations", value: "\(latitude),\(longitude)")]
        var req = URLRequest(url: comps.url!)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: req)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = root["results"] as? [[String: Any]],
              let first = results.first,
              let elev = first["elevation"] as? Double else {
            return 0
        }
        return elev
    }
}
