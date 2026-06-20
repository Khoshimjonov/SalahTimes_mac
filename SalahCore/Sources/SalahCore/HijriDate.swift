import Foundation

/// Hijri (Islamic) calendar date, computed via the Umm al-Qura / Kuwaiti
/// arithmetic algorithm.
///
/// Direct port of `HijriDate.java` — same epoch (JD 1948439.5), same 30-year
/// cycle (10631 days), same leap-year set {2,5,7,10,13,16,18,21,24,26,29},
/// same month-length rule (odd=30, even=29, month 12 = 30 in leap years).
public struct HijriDate: Sendable, Equatable, Hashable {

    public let year: Int
    public let month: Int   // 1...12
    public let day: Int     // 1...30

    public init(year: Int, month: Int, day: Int) {
        precondition((1...12).contains(month), "Month must be 1..12")
        precondition((1...30).contains(day), "Day must be 1..30")
        self.year = year
        self.month = month
        self.day = day
    }

    // MARK: - Month names (English / Uzbek / Russian / Arabic)

    public static let monthsEn: [String] = [
        "Muharram", "Safar", "Rabi' al-Awwal", "Rabi' al-Thani",
        "Jumada al-Awwal", "Jumada al-Thani", "Rajab", "Sha'ban",
        "Ramadan", "Shawwal", "Dhu al-Qi'dah", "Dhu al-Hijjah"
    ]

    public static let monthsUz: [String] = [
        "Muharram", "Safar", "Rabiul-avval", "Rabiul-oxir",
        "Jumadil-avval", "Jumadil-oxir", "Rajab", "Sha'bon",
        "Ramazon", "Shavvol", "Zulqa'da", "Zulhijja"
    ]

    public static let monthsRu: [String] = [
        "Мухаррам", "Сафар", "Раби аль-авваль", "Раби ас-сани",
        "Джумада аль-уля", "Джумада ас-сани", "Раджаб", "Шабан",
        "Рамадан", "Шавваль", "Зуль-када", "Зуль-хиджа"
    ]

    public static let monthsAr: [String] = [
        "مُحَرَّم", "صَفَر", "رَبِيع الأَوَّل", "رَبِيع الثَّانِي",
        "جُمَادَى الأُولَى", "جُمَادَى الآخِرَة", "رَجَب", "شَعْبَان",
        "رَمَضَان", "شَوَّال", "ذُو القَعْدَة", "ذُو الحِجَّة"
    ]

    public func monthName(language: String = "en") -> String {
        switch language.lowercased() {
        case "uz": return Self.monthsUz[month - 1]
        case "ru": return Self.monthsRu[month - 1]
        case "ar": return Self.monthsAr[month - 1]
        default:   return Self.monthsEn[month - 1]
        }
    }

    // MARK: - Conversion

    /// Hijri epoch: July 19, 622 CE Gregorian = JD 1948439.5.
    static let hijriEpoch: Double = 1_948_439.5

    public static func from(gregorianYear y: Int, month: Int, day: Int) -> HijriDate {
        let jd = Astronomy.julianDate(year: y, month: month, day: day)
        return julianToHijri(jd)
    }

    public static func from(_ date: Date, in zone: TimeZone = .current) -> HijriDate {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = zone
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return from(gregorianYear: c.year!, month: c.month!, day: c.day!)
    }

    public func toGregorian() -> DateComponents {
        let jd = HijriDate.hijriToJulian(year: year, month: month, day: day)
        return HijriDate.julianToGregorian(jd)
    }

    // MARK: - Internal arithmetic (mirrors Java private methods)

    private static func julianToHijri(_ jdIn: Double) -> HijriDate {
        let jd = floor(jdIn) + 0.5
        let totalDays = jd - hijriEpoch

        let cycles = Int(floor(totalDays / 10631.0))
        var remaining = totalDays - Double(cycles) * 10631.0

        var yearInCycle = 0
        var dayCount: Double = 0

        for y in 1...30 {
            let dpy: Double = isLeap(yearInCycle: y) ? 355 : 354
            if dayCount + dpy > remaining {
                yearInCycle = y
                remaining -= dayCount
                break
            }
            dayCount += dpy
            if y == 30 {
                yearInCycle = 30
                remaining -= dayCount
            }
        }

        let year = cycles * 30 + yearInCycle

        var month = 1
        var dayOfYear = Int(floor(remaining)) + 1

        for m in 1...12 {
            let dim = daysInMonthInternal(year: year, month: m)
            if dayOfYear <= dim {
                month = m
                break
            }
            dayOfYear -= dim
            month = m + 1
        }

        var day = dayOfYear
        if month > 12 {
            month = 12
            day = daysInMonthInternal(year: year, month: 12)
        }
        if day < 1 { day = 1 }
        if day > 30 { day = 30 }

        return HijriDate(year: year, month: month, day: day)
    }

    private static func hijriToJulian(year: Int, month: Int, day: Int) -> Double {
        let cycles = (year - 1) / 30
        let remainingYears = (year - 1) % 30

        var days = Double(cycles) * 10631.0

        if remainingYears >= 1 {
            for y in 1...remainingYears {
                days += isLeap(yearInCycle: y) ? 355 : 354
            }
        }

        if month >= 2 {
            for m in 1..<month {
                days += Double(daysInMonthInternal(year: year, month: m))
            }
        }

        days += Double(day)
        return hijriEpoch + days - 1
    }

    private static func julianToGregorian(_ jd: Double) -> DateComponents {
        let Z = Int(floor(jd + 0.5))
        let A: Int
        if Z < 2_299_161 {
            A = Z
        } else {
            let alpha = Int(floor((Double(Z) - 1_867_216.25) / 36524.25))
            A = Z + 1 + alpha - alpha / 4
        }

        let B = A + 1524
        let C = Int(floor((Double(B) - 122.1) / 365.25))
        let D = Int(floor(365.25 * Double(C)))
        let E = Int(floor((Double(B - D)) / 30.6001))

        let day = B - D - Int(floor(30.6001 * Double(E)))
        let month = (E < 14) ? E - 1 : E - 13
        let year = (month > 2) ? C - 4716 : C - 4715

        var c = DateComponents()
        c.year = year
        c.month = month
        c.day = day
        return c
    }

    private static let cycleLeapYears: Set<Int> = [2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29]

    private static func isLeap(yearInCycle y: Int) -> Bool {
        cycleLeapYears.contains(y)
    }

    public static func isLeapYear(_ hijriYear: Int) -> Bool {
        let pos = ((hijriYear - 1) % 30) + 1
        return isLeap(yearInCycle: pos)
    }

    private static func daysInMonthInternal(year: Int, month: Int) -> Int {
        if month % 2 == 1 { return 30 }
        if month == 12 && isLeapYear(year) { return 30 }
        return 29
    }

    public static func daysInMonth(year: Int, month: Int) -> Int {
        precondition((1...12).contains(month), "Month must be 1..12")
        return daysInMonthInternal(year: year, month: month)
    }

    // MARK: - Arithmetic

    public func plusDays(_ days: Int) -> HijriDate {
        let jd = HijriDate.hijriToJulian(year: year, month: month, day: day)
        return HijriDate.julianToHijri(jd + Double(days))
    }

    public func minusDays(_ days: Int) -> HijriDate { plusDays(-days) }

    // MARK: - Special days

    /// Returns a stable identifier (English) for the special Islamic day on
    /// this date, or `nil`. UI code is expected to localise these.
    public var specialDayKey: String? {
        switch (month, day) {
        case (1, 1):   return "islamic_new_year"
        case (1, 10):  return "ashura"
        case (3, 12):  return "mawlid_an_nabi"
        case (7, 27):  return "isra_miraj"
        case (8, 15):  return "laylat_al_baraat"
        case (9, 1):   return "ramadan_begins"
        case (9, 27):  return "laylat_al_qadr"
        case (10, 1):  return "eid_al_fitr"
        case (12, 8):  return "tarwiyah"
        case (12, 9):  return "arafah"
        case (12, 10): return "eid_al_adha"
        case (12, 11), (12, 12), (12, 13): return "tashreeq"
        default:       return nil
        }
    }
}
