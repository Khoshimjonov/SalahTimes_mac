import Foundation
import Observation
import SalahCore

/// User-facing settings that drive every other subsystem (calculator,
/// menu-bar formatter, notifications, autostart). Mutating any property
/// debounces a JSON write to disk and lets observers refresh.
///
/// Designed to mirror the Java `ConfigurationManager` plus new menu-bar fields
/// added for the macOS rebuild — see plan file for the full mapping.
@Observable
@MainActor
public final class AppSettings {

    // MARK: - Persisted fields

    public var address: String = "Tashkent"
    public var latitude: Double = 41.37
    public var longitude: Double = 69.26
    public var elevation: Double = 460
    public var timeZoneIdentifier: String = TimeZone.current.identifier

    public var calculationMethodCode: Int = 14   // Russia (Java default)
    public var asrSchoolCode: Int = 1            // Hanafi (Java default)
    public var highLatitudeRule: HighLatitudeRule = .angleBased
    public var imsakMinutes: Int = 10

    /// Per-prayer manual offsets in minutes — order matches `PrayerTimesDay.Prayer`.
    public var adjustmentImsak: Int = 0
    public var adjustmentFajr: Int = 0
    public var adjustmentSunrise: Int = 0
    public var adjustmentDhuhr: Int = 0
    public var adjustmentAsr: Int = 0
    public var adjustmentMaghrib: Int = 0
    public var adjustmentIsha: Int = 0

    public var notifyBefore: Bool = true
    public var notifyBeforeMinutes: Int = 35
    public var notifyOnTime: Bool = true

    /// "uz", "en", or "ru". Default matches the Java app.
    public var language: String = "uz"

    public var autoStart: Bool = false

    // Menu-bar appearance
    public var menuBarShowPrayerName: Bool = true
    public var menuBarShowRemainingTime: Bool = true
    public var menuBarShowIcon: Bool = false
    public var menuBarUseShortNames: Bool = true
    public var menuBarCompactSeconds: Bool = false

    // MARK: - Derived helpers

    public var calculationMethod: CalculationMethod {
        CalculationMethod.byCode(calculationMethodCode)
    }
    public var asrSchool: AsrSchool {
        AsrSchool.byCode(asrSchoolCode)
    }
    public var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .current
    }
    public var coordinates: Coordinates {
        Coordinates(latitude: latitude, longitude: longitude,
                    elevation: elevation, timeZone: timeZone)
    }
    public var calculator: PrayerTimesCalculator {
        PrayerTimesCalculator(
            coordinates: coordinates,
            method: calculationMethod,
            asrSchool: asrSchool,
            highLatitudeRule: highLatitudeRule,
            imsakMinutes: Double(imsakMinutes),
            adjustments: [
                adjustmentImsak, adjustmentFajr, adjustmentSunrise,
                adjustmentDhuhr, adjustmentAsr, adjustmentMaghrib,
                adjustmentIsha, 0, 0
            ]
        )
    }

    // MARK: - Persistence

    private let persistence: SettingsPersistence
    private var saveTask: Task<Void, Never>?

    public init(persistence: SettingsPersistence = .default) {
        self.persistence = persistence
        if let snapshot = persistence.load() {
            apply(snapshot)
        }
    }

    /// Persist to disk now, debounced 500 ms so flurries of UI edits coalesce.
    public func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard let self else { return }
            self.persistence.save(self.snapshot())
        }
    }

    // MARK: - Snapshot codable

    public struct Snapshot: Codable {
        var address: String
        var latitude: Double
        var longitude: Double
        var elevation: Double
        var timeZoneIdentifier: String
        var calculationMethodCode: Int
        var asrSchoolCode: Int
        var highLatitudeRule: String
        var imsakMinutes: Int
        var adjustmentImsak: Int
        var adjustmentFajr: Int
        var adjustmentSunrise: Int
        var adjustmentDhuhr: Int
        var adjustmentAsr: Int
        var adjustmentMaghrib: Int
        var adjustmentIsha: Int
        var notifyBefore: Bool
        var notifyBeforeMinutes: Int
        var notifyOnTime: Bool
        var language: String
        var autoStart: Bool
        var menuBarShowPrayerName: Bool
        var menuBarShowRemainingTime: Bool
        var menuBarShowIcon: Bool
        var menuBarUseShortNames: Bool
        var menuBarCompactSeconds: Bool
    }

    public func snapshot() -> Snapshot {
        Snapshot(
            address: address, latitude: latitude, longitude: longitude,
            elevation: elevation, timeZoneIdentifier: timeZoneIdentifier,
            calculationMethodCode: calculationMethodCode, asrSchoolCode: asrSchoolCode,
            highLatitudeRule: highLatitudeRule.rawValue, imsakMinutes: imsakMinutes,
            adjustmentImsak: adjustmentImsak, adjustmentFajr: adjustmentFajr,
            adjustmentSunrise: adjustmentSunrise, adjustmentDhuhr: adjustmentDhuhr,
            adjustmentAsr: adjustmentAsr, adjustmentMaghrib: adjustmentMaghrib,
            adjustmentIsha: adjustmentIsha,
            notifyBefore: notifyBefore, notifyBeforeMinutes: notifyBeforeMinutes,
            notifyOnTime: notifyOnTime, language: language, autoStart: autoStart,
            menuBarShowPrayerName: menuBarShowPrayerName,
            menuBarShowRemainingTime: menuBarShowRemainingTime,
            menuBarShowIcon: menuBarShowIcon,
            menuBarUseShortNames: menuBarUseShortNames,
            menuBarCompactSeconds: menuBarCompactSeconds
        )
    }

    public func apply(_ s: Snapshot) {
        address = s.address; latitude = s.latitude; longitude = s.longitude
        elevation = s.elevation; timeZoneIdentifier = s.timeZoneIdentifier
        calculationMethodCode = s.calculationMethodCode
        asrSchoolCode = s.asrSchoolCode
        highLatitudeRule = HighLatitudeRule(rawValue: s.highLatitudeRule) ?? .angleBased
        imsakMinutes = s.imsakMinutes
        adjustmentImsak = s.adjustmentImsak; adjustmentFajr = s.adjustmentFajr
        adjustmentSunrise = s.adjustmentSunrise; adjustmentDhuhr = s.adjustmentDhuhr
        adjustmentAsr = s.adjustmentAsr; adjustmentMaghrib = s.adjustmentMaghrib
        adjustmentIsha = s.adjustmentIsha
        notifyBefore = s.notifyBefore; notifyBeforeMinutes = s.notifyBeforeMinutes
        notifyOnTime = s.notifyOnTime
        language = s.language; autoStart = s.autoStart
        menuBarShowPrayerName = s.menuBarShowPrayerName
        menuBarShowRemainingTime = s.menuBarShowRemainingTime
        menuBarShowIcon = s.menuBarShowIcon
        menuBarUseShortNames = s.menuBarUseShortNames
        menuBarCompactSeconds = s.menuBarCompactSeconds
    }
}
