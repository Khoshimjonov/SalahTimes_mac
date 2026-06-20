import Foundation

/// Pure-function prayer-time calculator. Single source of truth for all daily
/// times. No timers, no UI dependencies — safe to call from any actor.
///
/// Direct port of `SalahTimesCalculator.java`. The structure of
/// ``compute(jd:tzOffset:)`` and ``hourAngle(angle:decl:)`` mirrors the Java
/// methods line-by-line so a parity test against Java fixtures can verify
/// every code path produces identical hours.
public struct PrayerTimesCalculator: Sendable {

    public let coordinates: Coordinates
    public let method: CalculationMethod
    public let asrSchool: AsrSchool
    public let highLatitudeRule: HighLatitudeRule
    public let imsakMinutes: Double

    /// Per-prayer manual offsets (minutes) — indexed by `Prayer.rawValue`.
    /// Only indices 0..6 are honoured (imsak..isha); midnight and lastThird
    /// are not user-adjustable, matching the Java loop bound.
    public let adjustments: [Int]

    public init(
        coordinates: Coordinates,
        method: CalculationMethod = .mwl,
        asrSchool: AsrSchool = .shafii,
        highLatitudeRule: HighLatitudeRule = .angleBased,
        imsakMinutes: Double = 10.0,
        adjustments: [Int] = Array(repeating: 0, count: 9)
    ) {
        precondition(adjustments.count == 9, "adjustments must have 9 entries")
        self.coordinates = coordinates
        self.method = method
        self.asrSchool = asrSchool
        self.highLatitudeRule = highLatitudeRule
        self.imsakMinutes = imsakMinutes
        self.adjustments = adjustments
    }

    // MARK: - Public API

    /// Computes prayer times for the calendar day containing the given moment
    /// in the calculator's timezone.
    public func calculate(on date: Date = Date()) -> PrayerTimesDay {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = coordinates.timeZone
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        return calculate(year: comps.year!, month: comps.month!, day: comps.day!)
    }

    public func calculate(year: Int, month: Int, day: Int) -> PrayerTimesDay {
        // Timezone offset for the specific date — handles DST correctly.
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = coordinates.timeZone
        var startComps = DateComponents()
        startComps.year = year
        startComps.month = month
        startComps.day = day
        startComps.hour = 0
        startComps.minute = 0
        startComps.second = 0
        let startOfDay = cal.date(from: startComps)!
        let tzOffset = Double(coordinates.timeZone.secondsFromGMT(for: startOfDay)) / 3600.0

        let jd = Astronomy.julianDate(year: year, month: month, day: day)

        var times = compute(jd: jd, tzOffset: tzOffset)

        // Manual per-prayer offsets — only first 7 indices.
        for i in 0..<min(adjustments.count, 7) {
            times[i] += Double(adjustments[i]) / 60.0
        }

        // Normalize all 9 to 0..24.
        for i in 0..<times.count {
            times[i] = Astronomy.normalizeHour(times[i])
        }

        var dateComps = DateComponents()
        dateComps.year = year
        dateComps.month = month
        dateComps.day = day

        return PrayerTimesDay(
            date: dateComps,
            timeZone: coordinates.timeZone,
            imsak:     times[0].nonNaN,
            fajr:      times[1].nonNaN,
            sunrise:   times[2].nonNaN,
            dhuhr:     times[3].nonNaN,
            asr:       times[4].nonNaN,
            maghrib:   times[5].nonNaN,
            isha:      times[6].nonNaN,
            midnight:  times[7].nonNaN,
            lastThird: times[8].nonNaN
        )
    }

    // MARK: - Core algorithm (port of SalahTimesCalculator#computePrayerTimes)

    /// Returns a 9-element array indexed by `Prayer.rawValue`. NaN means the
    /// sun never reaches the required angle and no high-latitude rule applied.
    private func compute(jd: Double, tzOffset: Double) -> [Double] {
        var times = [Double](repeating: .nan, count: 9)

        let decl = Astronomy.sunDeclination(jd: jd)
        let eqt  = Astronomy.equationOfTime(jd: jd)

        let dhuhr = 12.0 + tzOffset - coordinates.longitude / 15.0 - eqt

        // Sunrise/sunset includes elevation refraction.
        let riseSetAngle = 0.833 + 0.0347 * sqrt(coordinates.elevation)

        let sunriseHA = hourAngle(angle: riseSetAngle, decl: decl)
        let fajrHA    = hourAngle(angle: method.fajrAngle, decl: decl)
        let asrHA     = asrHourAngle(decl: decl)
        let ishaHA    = hourAngle(angle: method.ishaAngle, decl: decl)

        times[3] = dhuhr                  // DHUHR
        times[2] = dhuhr - sunriseHA      // SUNRISE
        times[5] = dhuhr + sunriseHA      // MAGHRIB
        times[1] = dhuhr - fajrHA         // FAJR
        times[4] = dhuhr + asrHA          // ASR

        if method.ishaMinutes > 0 {
            times[6] = times[5] + Double(method.ishaMinutes) / 60.0
        } else {
            times[6] = dhuhr + ishaHA
        }

        times[0] = times[1] - imsakMinutes / 60.0  // IMSAK = Fajr - imsakMinutes

        times = adjustHighLatitude(times: times, dhuhr: dhuhr)

        // Midnight & last third — uses next day's Fajr to span the night.
        let nextDecl = Astronomy.sunDeclination(jd: jd + 1)
        let nextEqt  = Astronomy.equationOfTime(jd: jd + 1)
        let nextDhuhr = 12.0 + tzOffset - coordinates.longitude / 15.0 - nextEqt
        let nextFajrHA = hourAngle(angle: method.fajrAngle, decl: nextDecl)
        let nextFajr = nextDhuhr - nextFajrHA

        var nightDuration = (nextFajr + 24.0) - times[5]
        if nightDuration > 24.0 {
            nightDuration -= 24.0
        }

        times[7] = times[5] + nightDuration / 2.0           // MIDNIGHT
        times[8] = times[5] + nightDuration * 2.0 / 3.0     // LAST_THIRD

        return times
    }

    private func hourAngle(angle: Double, decl: Double) -> Double {
        let latRad = coordinates.latitude * Astronomy.degToRad
        let declRad = decl * Astronomy.degToRad
        let angleRad = angle * Astronomy.degToRad

        let cosHA = (-sin(angleRad) - sin(latRad) * sin(declRad))
                  / (cos(latRad) * cos(declRad))

        if cosHA < -1.0 || cosHA > 1.0 {
            return .nan
        }
        return acos(cosHA) * Astronomy.radToDeg / 15.0
    }

    private func asrHourAngle(decl: Double) -> Double {
        let latRad = coordinates.latitude * Astronomy.degToRad
        let declRad = decl * Astronomy.degToRad

        // shadowAngle is computed in RADIANS — note the bare sin/cos below
        // that consume it (they are NOT the deg-prefixed helpers).
        let shadowAngle = atan(1.0 / (Double(asrSchool.shadowRatio)
                              + tan(abs(latRad - declRad))))

        let cosHA = (sin(shadowAngle) - sin(latRad) * sin(declRad))
                  / (cos(latRad) * cos(declRad))

        if cosHA < -1.0 || cosHA > 1.0 {
            return .nan
        }
        return acos(cosHA) * Astronomy.radToDeg / 15.0
    }

    private func adjustHighLatitude(times: [Double], dhuhr: Double) -> [Double] {
        if highLatitudeRule == .none {
            return times
        }
        var t = times
        let sunrise = t[2]
        let sunset  = t[5]

        let nightTime = 24.0 - (sunset - sunrise)

        let fajrDiff = highLatitudeRule.nightPortion(forAngle: method.fajrAngle) * nightTime
        if t[1].isNaN || (sunrise - t[1]) > fajrDiff {
            t[1] = sunrise - fajrDiff
            t[0] = t[1] - imsakMinutes / 60.0
        }

        // Java uses 18° as the angle when Isha is minutes-based.
        let effectiveIsha = method.ishaMinutes > 0 ? 18.0 : method.ishaAngle
        let ishaDiff = highLatitudeRule.nightPortion(forAngle: effectiveIsha) * nightTime
        if t[6].isNaN || (t[6] - sunset) > ishaDiff {
            t[6] = sunset + ishaDiff
        }

        return t
    }
}

private extension Double {
    /// `nil` for NaN/infinite, otherwise self. Used at the edge between the
    /// internal NaN-as-sentinel array and the public optional-typed model.
    var nonNaN: Double? {
        (isNaN || isInfinite) ? nil : self
    }
}
