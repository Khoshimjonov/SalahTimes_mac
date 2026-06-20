import Foundation

/// One special Islamic day in the calendar — direct port of
/// `IslamicCalendar.IslamicEvent` from the Java app.
public struct IslamicEvent: Sendable, Equatable {

    public enum EventType: String, Sendable, Codable {
        case eid, holyNight, blessedDay, fastingDay, monthStart, historical
    }

    public let nameEn: String
    public let nameRu: String
    public let nameUz: String
    public let nameAr: String
    public let descriptionEn: String
    public let descriptionRu: String
    public let descriptionUz: String
    public let hijriDate: HijriDate
    public let type: EventType
    public let isFastingDay: Bool
    public let isFastingProhibited: Bool
    public let isPublicHoliday: Bool

    public func name(language: String) -> String {
        switch language.lowercased() {
        case "ru": return nameRu
        case "uz": return nameUz
        case "ar": return nameAr
        default:   return nameEn
        }
    }

    public func description(language: String) -> String {
        switch language.lowercased() {
        case "ru": return descriptionRu
        case "uz": return descriptionUz
        default:   return descriptionEn
        }
    }

    /// Gregorian date for this event, computed by converting `hijriDate` back.
    public var gregorianDate: DateComponents { hijriDate.toGregorian() }
}

/// Catalogue of Islamic events for any Hijri year. Same set of 26 events per
/// year as the Java reference (`IslamicCalendar.getEventsForHijriYear`).
public enum IslamicEvents {

    /// All events for a given Hijri year.
    public static func eventsForHijriYear(_ year: Int) -> [IslamicEvent] {
        eventTemplates.map { tpl in
            IslamicEvent(
                nameEn: tpl.nameEn, nameRu: tpl.nameRu, nameUz: tpl.nameUz, nameAr: tpl.nameAr,
                descriptionEn: tpl.descriptionEn, descriptionRu: tpl.descriptionRu, descriptionUz: tpl.descriptionUz,
                hijriDate: HijriDate(year: year, month: tpl.month, day: tpl.day),
                type: tpl.type,
                isFastingDay: tpl.fasting,
                isFastingProhibited: tpl.prohibited,
                isPublicHoliday: tpl.holiday
            )
        }
    }

    /// Events whose Gregorian date falls in a given Gregorian year, sorted.
    public static func eventsForGregorianYear(_ gregorianYear: Int, in zone: TimeZone = .current) -> [IslamicEvent] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = zone
        let startH = HijriDate.from(gregorianYear: gregorianYear, month: 1, day: 1)
        let endH   = HijriDate.from(gregorianYear: gregorianYear, month: 12, day: 31)
        var out: [IslamicEvent] = []
        for hy in startH.year...endH.year {
            for ev in eventsForHijriYear(hy) {
                let g = ev.gregorianDate
                if g.year == gregorianYear {
                    out.append(ev)
                }
            }
        }
        return out.sorted { lhs, rhs in
            compareGregorian(lhs.gregorianDate, rhs.gregorianDate) < 0
        }
    }

    /// Up to `count` events whose Gregorian date is on or after `from`.
    public static func upcoming(from date: Date, count: Int, in zone: TimeZone = .current) -> [IslamicEvent] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = zone
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        let y = comps.year!
        let pool = eventsForGregorianYear(y, in: zone) + eventsForGregorianYear(y + 1, in: zone)
        let upcoming = pool.filter { ev in
            compareGregorian(ev.gregorianDate, comps) >= 0
        }
        return Array(upcoming.prefix(count))
    }

    private static func compareGregorian(_ a: DateComponents, _ b: DateComponents) -> Int {
        if (a.year ?? 0) != (b.year ?? 0)   { return (a.year ?? 0) < (b.year ?? 0) ? -1 : 1 }
        if (a.month ?? 0) != (b.month ?? 0) { return (a.month ?? 0) < (b.month ?? 0) ? -1 : 1 }
        if (a.day ?? 0) != (b.day ?? 0)     { return (a.day ?? 0) < (b.day ?? 0) ? -1 : 1 }
        return 0
    }

    // MARK: - Event templates (data ported verbatim from IslamicCalendar.java)

    private struct Template {
        let month: Int
        let day: Int
        let nameEn: String
        let nameRu: String
        let nameUz: String
        let nameAr: String
        let descriptionEn: String
        let descriptionRu: String
        let descriptionUz: String
        let type: IslamicEvent.EventType
        let fasting: Bool
        let prohibited: Bool
        let holiday: Bool
    }

    private static let eventTemplates: [Template] = [
        Template(month: 1, day: 1,
            nameEn: "Islamic New Year", nameRu: "Исламский Новый год",
            nameUz: "Islomiy Yangi yil", nameAr: "رأس السنة الهجرية",
            descriptionEn: "First day of the Islamic calendar year",
            descriptionRu: "Первый день исламского календарного года",
            descriptionUz: "Islomiy taqvim yilining birinchi kuni",
            type: .monthStart, fasting: false, prohibited: false, holiday: true),

        Template(month: 1, day: 10,
            nameEn: "Day of Ashura", nameRu: "День Ашура",
            nameUz: "Ashuro kuni", nameAr: "يوم عاشوراء",
            descriptionEn: "10th of Muharram",
            descriptionRu: "10-е Мухаррама",
            descriptionUz: "Muharramning 10-kuni",
            type: .blessedDay, fasting: true, prohibited: false, holiday: false),

        Template(month: 2, day: 1,
            nameEn: "Start of Safar", nameRu: "Начало месяца Сафар",
            nameUz: "Safar oyining boshlanishi", nameAr: "بداية شهر صفر",
            descriptionEn: "Beginning of the month of Safar",
            descriptionRu: "Начало месяца Сафар",
            descriptionUz: "Safar oyining boshlanishi",
            type: .monthStart, fasting: false, prohibited: false, holiday: false),

        Template(month: 3, day: 12,
            nameEn: "Mawlid al-Nabi", nameRu: "Мавлид ан-Наби",
            nameUz: "Mavlud an-Nabiy", nameAr: "المولد النبوي الشريف",
            descriptionEn: "Birth of Prophet Muhammad ﷺ (12th Rabi' al-Awwal according to majority)",
            descriptionRu: "Рождение Пророка Мухаммада ﷺ (12-е Раби аль-Авваль по мнению большинства)",
            descriptionUz: "Payg'ambarimiz Muhammad ﷺ ning tug'ilgan kuni (ko'pchilik bo'yicha Rabiul-avvalning 12-kuni)",
            type: .blessedDay, fasting: false, prohibited: false, holiday: true),

        Template(month: 7, day: 1,
            nameEn: "Start of Rajab", nameRu: "Начало месяца Раджаб",
            nameUz: "Rajab oyining boshlanishi", nameAr: "بداية شهر رجب",
            descriptionEn: "Beginning of Rajab, one of the four sacred months",
            descriptionRu: "Начало Раджаба, одного из четырёх священных месяцев",
            descriptionUz: "Rajab oyining boshlanishi, to'rtta muqaddas oylardan biri",
            type: .monthStart, fasting: false, prohibited: false, holiday: false),

        Template(month: 7, day: 27,
            nameEn: "Isra and Mi'raj", nameRu: "Исра и Мирадж",
            nameUz: "Isro va Me'roj", nameAr: "الإسراء والمعراج",
            descriptionEn: "Night Journey and Ascension of Prophet Muhammad ﷺ",
            descriptionRu: "Ночное путешествие и Вознесение Пророка Мухаммада ﷺ",
            descriptionUz: "Payg'ambarimiz Muhammad ﷺ ning tungi sayohati va Me'rojga ko'tarilishi",
            type: .holyNight, fasting: false, prohibited: false, holiday: false),

        Template(month: 8, day: 1,
            nameEn: "Start of Sha'ban", nameRu: "Начало месяца Шаабан",
            nameUz: "Sha'bon oyining boshlanishi", nameAr: "بداية شهر شعبان",
            descriptionEn: "Beginning of Sha'ban",
            descriptionRu: "Начало месяца Шаабан",
            descriptionUz: "Sha'bon oyining boshlanishi",
            type: .monthStart, fasting: false, prohibited: false, holiday: false),

        Template(month: 8, day: 15,
            nameEn: "Laylat al-Bara'at", nameRu: "Ночь Бараат",
            nameUz: "Baro'at kechasi", nameAr: "ليلة البراءة",
            descriptionEn: "Laylat al-Bara'at",
            descriptionRu: "Ночь Бараат",
            descriptionUz: "Baro'at kechasi",
            type: .holyNight, fasting: true, prohibited: false, holiday: false),

        Template(month: 9, day: 1,
            nameEn: "First day of Ramadan", nameRu: "Первый день Рамадана",
            nameUz: "Ramazonning birinchi kuni", nameAr: "أول يوم رمضان",
            descriptionEn: "Beginning of the month of fasting",
            descriptionRu: "Начало месяца поста",
            descriptionUz: "Ro'za oyi boshlanishi",
            type: .monthStart, fasting: true, prohibited: false, holiday: true),

        Template(month: 9, day: 21,
            nameEn: "Laylat al-Qadr (21st night)", nameRu: "Ляйлят аль-Кадр (21-я ночь)",
            nameUz: "Qadr kechasi (21-kecha)", nameAr: "ليلة القدر",
            descriptionEn: "Night of Power - possible date",
            descriptionRu: "Ночь Предопределения - возможная дата",
            descriptionUz: "Qadr kechasi - ehtimoliy sana",
            type: .holyNight, fasting: true, prohibited: false, holiday: false),

        Template(month: 9, day: 23,
            nameEn: "Laylat al-Qadr (23rd night)", nameRu: "Ляйлят аль-Кадр (23-я ночь)",
            nameUz: "Qadr kechasi (23-kecha)", nameAr: "ليلة القدر",
            descriptionEn: "Night of Power - possible date",
            descriptionRu: "Ночь Предопределения - возможная дата",
            descriptionUz: "Qadr kechasi - ehtimoliy sana",
            type: .holyNight, fasting: true, prohibited: false, holiday: false),

        Template(month: 9, day: 25,
            nameEn: "Laylat al-Qadr (25th night)", nameRu: "Ляйлят аль-Кадр (25-я ночь)",
            nameUz: "Qadr kechasi (25-kecha)", nameAr: "ليلة القدر",
            descriptionEn: "Night of Power - possible date",
            descriptionRu: "Ночь Предопределения - возможная дата",
            descriptionUz: "Qadr kechasi - ehtimoliy sana",
            type: .holyNight, fasting: true, prohibited: false, holiday: false),

        Template(month: 9, day: 27,
            nameEn: "Laylat al-Qadr (27th night)", nameRu: "Ляйлят аль-Кадр (27-я ночь)",
            nameUz: "Qadr kechasi (27-kecha)", nameAr: "ليلة القدر",
            descriptionEn: "Night of Power - most commonly observed date",
            descriptionRu: "Ночь Предопределения - наиболее распространённая дата",
            descriptionUz: "Qadr kechasi - eng ko'p nishonlanadigan sana",
            type: .holyNight, fasting: true, prohibited: false, holiday: false),

        Template(month: 9, day: 29,
            nameEn: "Laylat al-Qadr (29th night)", nameRu: "Ляйлят аль-Кадр (29-я ночь)",
            nameUz: "Qadr kechasi (29-kecha)", nameAr: "ليلة القدر",
            descriptionEn: "Night of Power - possible date",
            descriptionRu: "Ночь Предопределения - возможная дата",
            descriptionUz: "Qadr kechasi - ehtimoliy sana",
            type: .holyNight, fasting: true, prohibited: false, holiday: false),

        Template(month: 10, day: 1,
            nameEn: "Eid al-Fitr", nameRu: "Ид аль-Фитр (Ураза-байрам)",
            nameUz: "Ramazon hayiti", nameAr: "عيد الفطر",
            descriptionEn: "Eid al-Fitr",
            descriptionRu: "Ид аль-Фитр",
            descriptionUz: "Ramazon hayiti",
            type: .eid, fasting: false, prohibited: true, holiday: true),

        Template(month: 10, day: 2,
            nameEn: "Eid al-Fitr (Day 2)", nameRu: "Ид аль-Фитр (День 2)",
            nameUz: "Ramazon hayiti (2-kun)", nameAr: "عيد الفطر - اليوم الثاني",
            descriptionEn: "Second day of Eid al-Fitr",
            descriptionRu: "Второй день Ид аль-Фитр",
            descriptionUz: "Ramazon hayitining ikkinchi kuni",
            type: .eid, fasting: false, prohibited: false, holiday: true),

        Template(month: 10, day: 3,
            nameEn: "Eid al-Fitr (Day 3)", nameRu: "Ид аль-Фитр (День 3)",
            nameUz: "Ramazon hayiti (3-kun)", nameAr: "عيد الفطر - اليوم الثالث",
            descriptionEn: "Third day of Eid al-Fitr",
            descriptionRu: "Третий день Ид аль-Фитр",
            descriptionUz: "Ramazon hayitining uchinchi kuni",
            type: .eid, fasting: false, prohibited: false, holiday: true),

        Template(month: 10, day: 2,
            nameEn: "Six Days of Shawwal Begin", nameRu: "Начало шести дней Шавваля",
            nameUz: "Shavvolning olti kunlik ro'zasi boshlanishi", nameAr: "صيام ستة أيام من شوال",
            descriptionEn: "Recommended to fast 6 days in Shawwal after Eid",
            descriptionRu: "Рекомендуется поститься 6 дней в Шаввале после Ида",
            descriptionUz: "Hayitdan keyin Shavvolda 6 kun ro'za tutish tavsiya etiladi",
            type: .fastingDay, fasting: true, prohibited: false, holiday: false),

        Template(month: 11, day: 1,
            nameEn: "Start of Dhu al-Qi'dah", nameRu: "Начало месяца Зуль-Каада",
            nameUz: "Zulqa'da oyining boshlanishi", nameAr: "بداية شهر ذو القعدة",
            descriptionEn: "Beginning of Dhu al-Qi'dah, one of the sacred months",
            descriptionRu: "Начало Зуль-Каада, одного из священных месяцев",
            descriptionUz: "Zulqa'da oyining boshlanishi, muqaddas oylardan biri",
            type: .monthStart, fasting: false, prohibited: false, holiday: false),

        Template(month: 12, day: 1,
            nameEn: "Start of Dhu al-Hijjah", nameRu: "Начало месяца Зуль-Хиджа",
            nameUz: "Zulhijja oyining boshlanishi", nameAr: "بداية شهر ذو الحجة",
            descriptionEn: "Beginning of the month of Hajj, one of the sacred months",
            descriptionRu: "Начало месяца Хаджа, одного из священных месяцев",
            descriptionUz: "Haj oyi boshlanishi, muqaddas oylardan biri",
            type: .monthStart, fasting: true, prohibited: false, holiday: false),

        Template(month: 12, day: 1,
            nameEn: "First 10 Days of Dhu al-Hijjah", nameRu: "Первые 10 дней Зуль-Хиджа",
            nameUz: "Zulhijjaning dastlabki 10 kuni", nameAr: "العشر الأوائل من ذي الحجة",
            descriptionEn: "First 10 Days of Dhu al-Hijjah",
            descriptionRu: "Первые 10 дней Зуль-Хиджа",
            descriptionUz: "Zulhijjaning dastlabki 10 kuni",
            type: .blessedDay, fasting: true, prohibited: false, holiday: false),

        Template(month: 12, day: 9,
            nameEn: "Day of Arafah", nameRu: "День Арафат",
            nameUz: "Arafa kuni", nameAr: "يوم عرفة",
            descriptionEn: "9th of Dhu al-Hijjah - most important day of Hajj",
            descriptionRu: "9-е Зуль-Хиджа - самый важный день Хаджа",
            descriptionUz: "Zulhijjaning 9-kuni - Hajning eng muhim kuni",
            type: .blessedDay, fasting: true, prohibited: false, holiday: false),

        Template(month: 12, day: 10,
            nameEn: "Eid al-Adha", nameRu: "Ид аль-Адха (Курбан-байрам)",
            nameUz: "Qurbon hayiti", nameAr: "عيد الأضحى",
            descriptionEn: "Festival of Sacrifice",
            descriptionRu: "Праздник жертвоприношения",
            descriptionUz: "Qurbonlik bayrami",
            type: .eid, fasting: false, prohibited: true, holiday: true),

        Template(month: 12, day: 11,
            nameEn: "Days of Tashreeq (Day 1)", nameRu: "Дни Ташрик (День 1)",
            nameUz: "Tashriq kunlari (1-kun)", nameAr: "أيام التشريق - اليوم الأول",
            descriptionEn: "11th of Dhu al-Hijjah - fasting prohibited",
            descriptionRu: "11-е Зуль-Хиджа - пост запрещён",
            descriptionUz: "Zulhijjaning 11-kuni - ro'za tutish taqiqlangan",
            type: .eid, fasting: false, prohibited: true, holiday: true),

        Template(month: 12, day: 12,
            nameEn: "Days of Tashreeq (Day 2)", nameRu: "Дни Ташрик (День 2)",
            nameUz: "Tashriq kunlari (2-kun)", nameAr: "أيام التشريق - اليوم الثاني",
            descriptionEn: "12th of Dhu al-Hijjah - fasting prohibited",
            descriptionRu: "12-е Зуль-Хиджа - пост запрещён",
            descriptionUz: "Zulhijjaning 12-kuni - ro'za tutish taqiqlangan",
            type: .eid, fasting: false, prohibited: true, holiday: true),

        Template(month: 12, day: 13,
            nameEn: "Days of Tashreeq (Day 3)", nameRu: "Дни Ташрик (День 3)",
            nameUz: "Tashriq kunlari (3-kun)", nameAr: "أيام التشريق - اليوم الثالث",
            descriptionEn: "13th of Dhu al-Hijjah - fasting prohibited",
            descriptionRu: "13-е Зуль-Хиджа - пост запрещён",
            descriptionUz: "Zulhijjaning 13-kuni - ro'za tutish taqiqlangan",
            type: .eid, fasting: false, prohibited: true, holiday: true)
    ]
}
