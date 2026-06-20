import Foundation
import Observation
import AppKit
import SalahCore

/// Central live-state container — single timer for the whole app, owns the
/// "current PrayerTimesDay + next prayer + remaining seconds" tuple that the
/// menu-bar label and dropdown both read.
///
/// Cadence (drives every refresh in the app):
/// - 30 s when far from rollover (cheap, OS-coalesced via Timer.tolerance).
/// - 5 s when within 120 s of next rollover.
/// - 1 s within the final 60 s, only if `menuBarCompactSeconds` is on.
///
/// Suspends on sleep, resumes (and recomputes) on wake. No NotificationCenter
/// observer is left dangling — see `deinit`.
@Observable
@MainActor
public final class AppState {

    // MARK: - Public live state (observed by views & menu-bar controller)

    public private(set) var todayTimes: PrayerTimesDay?
    public private(set) var tomorrowTimes: PrayerTimesDay?
    public private(set) var nextPrayer: PrayerTimesDay.Prayer?
    public private(set) var nextPrayerAt: Date?
    public private(set) var secondsToNext: Int = 0
    public private(set) var now: Date = Date()

    // MARK: - Wiring

    private let settings: AppSettings
    private var timer: Timer?
    private var sleepToken: NSObjectProtocol?
    private var wakeToken: NSObjectProtocol?
    private var settingsObservation: Task<Void, Never>?

    public init(settings: AppSettings) {
        self.settings = settings
        recomputeTimes(at: Date())
        startObservingSleepWake()
        startObservingSettings()
        scheduleNextTick()
    }
    // No deinit: `AppState` is owned by the app delegate for the whole
    // process lifetime, so OS observers and the timer outlive any cleanup
    // window. If this ever becomes non-singleton, expose an explicit stop().

    // MARK: - Recompute

    /// Recomputes the day's prayer times and figures out the next prayer.
    /// Called on launch, at midnight, on wake, and when settings change.
    public func recomputeTimes(at date: Date) {
        let calc = settings.calculator
        let day = calc.calculate(on: date)

        // Tomorrow's day so we can roll over past Isha.
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = settings.timeZone
        let tomorrow = cal.date(byAdding: .day, value: 1, to: date) ?? date
        let nextDay = calc.calculate(on: tomorrow)

        self.todayTimes = day
        self.tomorrowTimes = nextDay
        self.now = date
        updateNext(at: date)
    }

    private func updateNext(at date: Date) {
        guard let today = todayTimes else { return }
        let displayPrayers: [PrayerTimesDay.Prayer] =
            [.fajr, .sunrise, .dhuhr, .asr, .maghrib, .isha]

        var next: (PrayerTimesDay.Prayer, Date)?
        for p in displayPrayers {
            if let t = today.time(for: p), t > date {
                next = (p, t); break
            }
        }
        if next == nil, let tomorrow = tomorrowTimes,
           let fajr = tomorrow.time(for: .fajr) {
            next = (.fajr, fajr)
        }

        if let (p, at) = next {
            nextPrayer = p
            nextPrayerAt = at
            secondsToNext = Int(at.timeIntervalSince(date).rounded())
        } else {
            nextPrayer = nil
            nextPrayerAt = nil
            secondsToNext = 0
        }
        now = date
    }

    // MARK: - Timer driver

    private func scheduleNextTick() {
        timer?.invalidate()
        let interval = chooseInterval()
        let t = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
        // Coalesce wake-ups; cheap power profile when idle.
        t.tolerance = max(1, interval * 0.2)
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func chooseInterval() -> TimeInterval {
        let s = secondsToNext
        if s <= 60 && settings.menuBarCompactSeconds { return 1 }
        if s <= 120 { return 5 }
        // Snap to the next minute so labels flip on minute boundaries.
        let secondsIntoMinute = Int(Date().timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 60))
        let toMinuteEdge = max(1, 60 - secondsIntoMinute)
        return TimeInterval(min(30, toMinuteEdge))
    }

    private func tick() {
        let now = Date()
        // Detect day rollover OR a "next prayer fired" condition → recompute.
        // Day comparison must happen in the *location's* timezone — comparing
        // in system-local time would fire the rollover at the wrong moment for
        // users whose configured timezone differs from the system one.
        var locCal = Calendar(identifier: .gregorian)
        locCal.timeZone = settings.timeZone
        if let last = todayTimes,
           let lastDay = locCal.date(from: last.date),
           !locCal.isDate(lastDay, inSameDayAs: now) {
            recomputeTimes(at: now)
        } else if let next = nextPrayerAt, now > next {
            recomputeTimes(at: now)
        } else {
            updateNext(at: now)
        }
        scheduleNextTick()
    }

    // MARK: - Observers

    private func startObservingSleepWake() {
        let nc = NSWorkspace.shared.notificationCenter
        sleepToken = nc.addObserver(forName: NSWorkspace.willSleepNotification,
                                    object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.timer?.invalidate()
                self?.timer = nil
            }
        }
        wakeToken = nc.addObserver(forName: NSWorkspace.didWakeNotification,
                                   object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.recomputeTimes(at: Date())
                self.scheduleNextTick()
            }
        }
    }

    private func startObservingSettings() {
        // Whenever any calc-relevant setting changes, recompute. Observation
        // tracking auto-resubscribes after each call.
        settingsObservation = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                    withObservationTracking {
                        _ = self?.settings.calculationMethodCode
                        _ = self?.settings.asrSchoolCode
                        _ = self?.settings.highLatitudeRule
                        _ = self?.settings.imsakMinutes
                        _ = self?.settings.latitude
                        _ = self?.settings.longitude
                        _ = self?.settings.elevation
                        _ = self?.settings.timeZoneIdentifier
                        _ = self?.settings.adjustmentImsak
                        _ = self?.settings.adjustmentFajr
                        _ = self?.settings.adjustmentSunrise
                        _ = self?.settings.adjustmentDhuhr
                        _ = self?.settings.adjustmentAsr
                        _ = self?.settings.adjustmentMaghrib
                        _ = self?.settings.adjustmentIsha
                    } onChange: {
                        Task { @MainActor in cont.resume() }
                    }
                }
                self?.recomputeTimes(at: Date())
                self?.scheduleNextTick()
            }
        }
    }
}
