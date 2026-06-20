import Foundation

/// Solar-position helpers ported from `SalahTimesCalculator.java` lines
/// 459–545. Constants and order of operations are reproduced verbatim — any
/// drift here will break calculation parity with the Java reference.
enum Astronomy {

    static let degToRad = Double.pi / 180.0
    static let radToDeg = 180.0 / Double.pi

    @inline(__always) static func dsin(_ deg: Double) -> Double { sin(deg * degToRad) }
    @inline(__always) static func dcos(_ deg: Double) -> Double { cos(deg * degToRad) }
    @inline(__always) static func dtan(_ deg: Double) -> Double { tan(deg * degToRad) }
    @inline(__always) static func darcsin(_ x: Double) -> Double { asin(x) * radToDeg }
    @inline(__always) static func darccos(_ x: Double) -> Double { acos(x) * radToDeg }
    @inline(__always) static func darctan(_ x: Double) -> Double { atan(x) * radToDeg }
    @inline(__always) static func darctan2(_ y: Double, _ x: Double) -> Double {
        atan2(y, x) * radToDeg
    }

    static func normalize360(_ degrees: Double) -> Double {
        let r = degrees.truncatingRemainder(dividingBy: 360.0)
        return r < 0 ? r + 360.0 : r
    }

    static func normalizeHour(_ hour: Double) -> Double {
        let r = hour.truncatingRemainder(dividingBy: 24.0)
        return r < 0 ? r + 24.0 : r
    }

    /// Julian date for noon UT of the given Gregorian date — matches the Java
    /// `julianDate(year, month, day)` exactly, including the integer-division
    /// behaviour that yields a value ending in `.5` (noon UT).
    static func julianDate(year: Int, month: Int, day: Int) -> Double {
        var y = year
        var m = month
        if m <= 2 {
            y -= 1
            m += 12
        }
        let A = y / 100
        let B = 2 - A + A / 4
        return floor(365.25 * Double(y + 4716))
            + floor(30.6001 * Double(m + 1))
            + Double(day) + Double(B) - 1524.5
    }

    /// Sun declination in degrees, accurate to ~0.01°.
    static func sunDeclination(jd: Double) -> Double {
        let D = jd - 2451545.0
        let g = normalize360(357.529 + 0.98560028 * D)
        let q = normalize360(280.459 + 0.98564736 * D)
        let L = normalize360(q + 1.915 * dsin(g) + 0.020 * dsin(2 * g))
        let e = 23.439 - 0.00000036 * D
        return darcsin(dsin(e) * dsin(L))
    }

    /// Equation of time in hours.
    static func equationOfTime(jd: Double) -> Double {
        let D = jd - 2451545.0
        let g = normalize360(357.529 + 0.98560028 * D)
        let q = normalize360(280.459 + 0.98564736 * D)
        let L = normalize360(q + 1.915 * dsin(g) + 0.020 * dsin(2 * g))
        let e = 23.439 - 0.00000036 * D
        let RA = darctan2(dcos(e) * dsin(L), dcos(L)) / 15.0
        return q / 15.0 - normalizeHour(RA)
    }
}
