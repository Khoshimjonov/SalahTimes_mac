import XCTest
@testable import SalahCore

/// Verifies the Swift calculator matches the Java reference implementation
/// **second-for-second** across a grid of locations, methods, schools, and
/// dates. Fixtures are emitted by `tools/fixture-generator/FixtureGenerator.java`
/// (a verbatim copy of the Java math) and consumed here.
///
/// Any failure here is a calculation-parity regression — fix the Swift port
/// (or, if the Java math truly changed, regenerate fixtures and explain why).
final class CalculationParityTests: XCTestCase {

    func testPrayerTimesParity() throws {
        let url = try fixtureURL("prayer_times_fixtures.json")
        let data = try Data(contentsOf: url)
        // We need the school field, which collides with the prayer-time
        // "asr" key. Decode raw, then for each entry inspect the original
        // JSON text to pull the school out of position 2 of the "asr" value.
        guard let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            XCTFail("Fixture root is not an array of objects")
            return
        }

        var failures: [String] = []
        for (idx, dict) in array.enumerated() {
            let schoolName = dict["school"] as? String ?? "SHAFII"
            let school: AsrSchool = (schoolName == "HANAFI") ? .hanafi : .shafii
            _ = idx

            let lat = dict["lat"] as? Double ?? 0
            let lon = dict["lon"] as? Double ?? 0
            let elev = dict["elev"] as? Double ?? 0
            let zoneName = dict["zone"] as? String ?? ""
            let methodName = dict["method"] as? String ?? ""
            let hlName = dict["hl"] as? String ?? ""
            let imsakMinutes = dict["imsakMinutes"] as? Double ?? 10
            let dateStr = dict["date"] as? String ?? ""

            guard let zone = TimeZone(identifier: zoneName) else {
                failures.append("[\(idx)] unknown zone \(zoneName)")
                continue
            }
            let method = parseMethod(methodName)
            let hl = parseHighLat(hlName)
            let parts = dateStr.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3 else {
                failures.append("[\(idx)] bad date \(dateStr)")
                continue
            }

            let calc = PrayerTimesCalculator(
                coordinates: Coordinates(latitude: lat, longitude: lon, elevation: elev, timeZone: zone),
                method: method,
                asrSchool: school,
                highLatitudeRule: hl,
                imsakMinutes: imsakMinutes
            )
            let day = calc.calculate(year: parts[0], month: parts[1], day: parts[2])

            let expected: [(String, String?)] = [
                ("imsak", dict["imsak"] as? String),
                ("fajr", dict["fajr"] as? String),
                ("sunrise", dict["sunrise"] as? String),
                ("dhuhr", dict["dhuhr"] as? String),
                ("asr", dict["asr"] as? String),
                ("maghrib", dict["maghrib"] as? String),
                ("isha", dict["isha"] as? String),
                ("midnight", dict["midnight"] as? String),
                ("lastThird", dict["lastThird"] as? String)
            ]
            let actual: [(String, String)] = [
                ("imsak", day.formatted(.imsak)),
                ("fajr", day.formatted(.fajr)),
                ("sunrise", day.formatted(.sunrise)),
                ("dhuhr", day.formatted(.dhuhr)),
                ("asr", day.formatted(.asr)),
                ("maghrib", day.formatted(.maghrib)),
                ("isha", day.formatted(.isha)),
                ("midnight", day.formatted(.midnight)),
                ("lastThird", day.formatted(.lastThird))
            ]

            for (i, e) in expected.enumerated() {
                let exp = e.1 ?? "null"
                let got = actual[i].1
                if exp != got {
                    failures.append("[\(idx)] \(methodName)/\(school)/\(dateStr)@\(zoneName) \(e.0): expected \(exp), got \(got)")
                }
            }
        }

        if !failures.isEmpty {
            XCTFail("Parity drift in \(failures.count) of \(array.count * 9) checks. First 10:\n" +
                    failures.prefix(10).joined(separator: "\n"))
        }
    }

    func testHijriParity() throws {
        let url = try fixtureURL("hijri_fixtures.json")
        let data = try Data(contentsOf: url)
        guard let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            XCTFail("Hijri fixture root is not an array of objects")
            return
        }
        for dict in array {
            let gy = dict["gy"] as! Int
            let gm = dict["gm"] as! Int
            let gd = dict["gd"] as! Int
            let hy = dict["hy"] as! Int
            let hm = dict["hm"] as! Int
            let hd = dict["hd"] as! Int

            let h = HijriDate.from(gregorianYear: gy, month: gm, day: gd)
            XCTAssertEqual(h.year, hy, "year drift for \(gy)-\(gm)-\(gd)")
            XCTAssertEqual(h.month, hm, "month drift for \(gy)-\(gm)-\(gd)")
            XCTAssertEqual(h.day, hd, "day drift for \(gy)-\(gm)-\(gd)")
        }
    }

    // MARK: - Helpers

    private func fixtureURL(_ name: String) throws -> URL {
        let bundle = Bundle.module
        guard let url = bundle.url(forResource: name, withExtension: nil, subdirectory: "Fixtures")
                       ?? bundle.url(forResource: name, withExtension: nil) else {
            throw NSError(domain: "fixture", code: 404,
                          userInfo: [NSLocalizedDescriptionKey: "Fixture not found: \(name)"])
        }
        return url
    }

    private func parseMethod(_ name: String) -> CalculationMethod {
        switch name {
        case "MWL": return .mwl
        case "ISNA": return .isna
        case "EGYPT": return .egypt
        case "MAKKAH": return .makkah
        case "KARACHI": return .karachi
        case "TEHRAN": return .tehran
        case "JAFARI": return .jafari
        case "SINGAPORE": return .singapore
        case "TURKEY": return .turkey
        case "DUBAI": return .dubai
        case "KUWAIT": return .kuwait
        case "QATAR": return .qatar
        case "RUSSIA": return .russia
        case "FRANCE": return .france
        default: fatalError("Unknown method \(name)")
        }
    }

    private func parseHighLat(_ name: String) -> HighLatitudeRule {
        switch name {
        case "NONE":         return .none
        case "NIGHT_MIDDLE": return .nightMiddle
        case "ONE_SEVENTH":  return .oneSeventh
        case "ANGLE_BASED":  return .angleBased
        default: fatalError("Unknown high-lat rule \(name)")
        }
    }

}
