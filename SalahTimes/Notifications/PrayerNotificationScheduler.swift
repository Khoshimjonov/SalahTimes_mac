import Foundation
import UserNotifications
import SalahCore

/// Schedules prayer notifications via the OS so delivery happens even when the
/// app is suspended. Reschedules on launch, midnight rollover, and any change
/// to settings that affects prayer times — never on a per-second tick.
@MainActor
public final class PrayerNotificationScheduler {

    private let center = UNUserNotificationCenter.current()
    private let settings: AppSettings
    private var inFlight: Task<Void, Never>?

    public init(settings: AppSettings) {
        self.settings = settings
    }

    public func requestAuthorizationIfNeeded() async {
        let current = await center.notificationSettings()
        guard current.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Public entry point. Serializes calls so two reschedules can't
    /// interleave on the MainActor between `await` suspension points —
    /// which otherwise produced duplicate pending requests despite stable
    /// identifiers.
    public func reschedule() async {
        let prev = inFlight
        let task = Task { @MainActor in
            await prev?.value
            await self.runReschedule()
        }
        inFlight = task
        await task.value
    }

    private func runReschedule() async {
        // Wipe every pending request, then rebuild from scratch with stable
        // IDs. Cheap, idempotent, and immune to whatever leftover UUIDs the
        // pre-fix builds had accumulated. Safe under serialization: no other
        // reschedule can sneak in between the wipe and the adds.
        center.removeAllPendingNotificationRequests()

        guard settings.notifyBefore || settings.notifyOnTime else { return }

        let calc = settings.calculator
        let zone = settings.timeZone
        let now = Date()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = zone

        let dates = (0...1).compactMap { offset in
            cal.date(byAdding: .day, value: offset, to: now)
        }

        let prayers: [(PrayerTimesDay.Prayer, String)] = [
            (.fajr,    "prayer.fajr"),
            (.dhuhr,   "prayer.dhuhr"),
            (.asr,     "prayer.asr"),
            (.maghrib, "prayer.maghrib"),
            (.isha,    "prayer.isha")
        ]
        let dayFmt = DateFormatter()
        dayFmt.timeZone = zone
        dayFmt.dateFormat = "yyyy-MM-dd"

        // Deterministic identifiers per (prayer, kind, day) keep `add(_:)`
        // calls idempotent if any escape the wipe — same ID just replaces.
        for date in dates {
            let day = calc.calculate(on: date)
            let dayKey = dayFmt.string(from: date)
            for (prayer, key) in prayers {
                guard let fireAt = day.time(for: prayer), fireAt > now else { continue }
                let prayerName = LocalizedStrings.string(key, language: settings.language)

                if settings.notifyBefore {
                    let lead = TimeInterval(settings.notifyBeforeMinutes * 60)
                    let preFire = fireAt.addingTimeInterval(-lead)
                    if preFire > now {
                        // Positional placeholders in the format strings let
                        // each language reorder %1$d (minutes) and %2$@ (name).
                        await schedule(id: "\(key).before.\(dayKey)",
                                       at: preFire, in: zone,
                                       titleKey: "notify.before.title",
                                       bodyKey: "notify.before.body",
                                       bodyArgs: [settings.notifyBeforeMinutes, prayerName])
                    }
                }
                if settings.notifyOnTime {
                    await schedule(id: "\(key).ontime.\(dayKey)",
                                   at: fireAt, in: zone,
                                   titleKey: "notify.ontime.title",
                                   titleArgs: [prayerName],
                                   bodyKey: "notify.ontime.body",
                                   bodyArgs: [prayerName])
                }
            }
        }
    }

    private func schedule(
        id: String,
        at date: Date, in zone: TimeZone,
        titleKey: String, titleArgs: [CVarArg] = [],
        bodyKey: String, bodyArgs: [CVarArg]
    ) async {
        let content = UNMutableNotificationContent()
        let titleTpl = LocalizedStrings.string(titleKey, language: settings.language)
        content.title = titleArgs.isEmpty ? titleTpl : String(format: titleTpl, arguments: titleArgs)
        let bodyTpl = LocalizedStrings.string(bodyKey, language: settings.language)
        content.body = String(format: bodyTpl, arguments: bodyArgs)
        content.sound = .default

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = zone
        var comps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        comps.timeZone = zone
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(req)
    }
}
