import SwiftUI
import SalahCore

/// The popover content shown when the user clicks the menu-bar item. Pure
/// SwiftUI; no timers of its own — re-renders when `AppState` ticks.
struct DropdownView: View {
    @Bindable var settings: AppSettings
    @Bindable var state: AppState
    var quit: () -> Void

    // macOS 14+ environment action — handles opening the standard Settings
    // scene without us guessing at private selectors.
    @Environment(\.openSettings) private var openSettingsAction

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HeaderSection(settings: settings, state: state)
            Divider()
            NowSection(settings: settings, state: state)
            Divider()
            PrayersSection(settings: settings, state: state)
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 360)
    }

    private var footer: some View {
        HStack {
            Button(L("menu.settings", settings.language)) {
                NSApp.activate(ignoringOtherApps: true)
                openSettingsAction()
            }
            .buttonStyle(.borderless)
            Spacer()
            Button(L("menu.quit", settings.language), action: quit)
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
        }
        .font(.callout)
    }
}

private struct HeaderSection: View {
    let settings: AppSettings
    let state: AppState

    var body: some View {
        let h = HijriDate.from(state.now, in: settings.timeZone)
        VStack(alignment: .leading, spacing: 2) {
            Text(gregorianText)
                .font(.headline)
            Text("\(h.day) \(h.monthName(language: settings.language)) \(h.year) AH")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Image(systemName: "location.fill")
                    .imageScale(.small)
                Text(locationText)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 2)
        }
    }

    private var gregorianText: String {
        let f = DateFormatter()
        f.timeZone = settings.timeZone
        f.locale = Locale(identifier: settings.language)
        f.dateStyle = .full
        f.timeStyle = .none
        return f.string(from: state.now)
    }

    private var locationText: String {
        let trimmed = settings.address.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return String(format: "%.4f, %.4f", settings.latitude, settings.longitude)
    }
}

private struct NowSection: View {
    let settings: AppSettings
    let state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(timeText)
                .font(.system(size: 32, weight: .light, design: .rounded))
                .monospacedDigit()
            if let next = state.nextPrayer {
                let key = key(for: next)
                let name = LocalizedStrings.string(key, language: settings.language)
                let remaining = humanRemaining(state.secondsToNext, language: settings.language)
                Text("\(L("dropdown.next", settings.language)): \(name) · \(remaining)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var timeText: String {
        let f = DateFormatter()
        f.timeZone = settings.timeZone
        // No seconds — the menu only refreshes once a minute by default,
        // so a ticking second hand would be a lie.
        f.dateFormat = "HH:mm"
        return f.string(from: state.now)
    }

    private func key(for p: PrayerTimesDay.Prayer) -> String {
        switch p {
        case .fajr: return "prayer.fajr"
        case .sunrise: return "prayer.sunrise"
        case .dhuhr: return "prayer.dhuhr"
        case .asr: return "prayer.asr"
        case .maghrib: return "prayer.maghrib"
        case .isha: return "prayer.isha"
        default: return "prayer.fajr"
        }
    }
}

private struct PrayersSection: View {
    let settings: AppSettings
    let state: AppState

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.element.key) { (idx, row) in
                VStack(spacing: 2) {
                    HStack {
                        Text(row.localized)
                            .fontWeight(row.isNext ? .semibold : .regular)
                            .foregroundStyle(row.isPast ? .secondary : .primary)
                        Spacer()
                        Text(row.timeText)
                            .monospacedDigit()
                            .foregroundStyle(row.isNext ? Color.accentColor :
                                             (row.isPast ? Color.secondary : Color.primary))
                    }
                    // Interval from the previous prayer in the same row order
                    // (matches the Java app's "Prev → Curr +HH:MM:SS" hint).
                    // Skipped for the first prayer (Fajr) since there's no
                    // previous one to subtract from.
                    if idx > 0, let prev = rows[safe: idx - 1],
                       let interval = formatInterval(from: prev, to: row) {
                        HStack {
                            Spacer()
                            Text("\(prev.localized) → \(row.localized) +\(interval)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Row data

    private struct Row {
        let key: String
        let localized: String
        let timeText: String
        let date: Date
        let isNext: Bool
        let isPast: Bool
    }

    private var rows: [Row] {
        guard let day = state.todayTimes else { return [] }
        let order: [(PrayerTimesDay.Prayer, String)] = [
            (.fajr,    "prayer.fajr"),
            (.sunrise, "prayer.sunrise"),
            (.dhuhr,   "prayer.dhuhr"),
            (.asr,     "prayer.asr"),
            (.maghrib, "prayer.maghrib"),
            (.isha,    "prayer.isha")
        ]
        let f = DateFormatter()
        f.timeZone = settings.timeZone
        f.dateFormat = "HH:mm"
        let now = state.now
        return order.compactMap { (p, key) in
            guard let date = day.time(for: p) else { return nil }
            let isPast = date < now
            let isNext = state.nextPrayer == p
            return Row(
                key: key,
                localized: LocalizedStrings.string(key, language: settings.language),
                timeText: f.string(from: date),
                date: date,
                isNext: isNext,
                isPast: isPast && !isNext
            )
        }
    }

    private func formatInterval(from a: Row, to b: Row) -> String? {
        let total = Int(b.date.timeIntervalSince(a.date).rounded())
        guard total > 0 else { return nil }
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}

private extension Array {
    subscript(safe i: Int) -> Element? {
        indices.contains(i) ? self[i] : nil
    }
}

private func humanRemaining(_ seconds: Int, language: String) -> String {
    let s = max(0, seconds)
    let h = s / 3600
    let m = (s % 3600) / 60
    if h > 0 {
        return String(format: "%dh %02dm", h, m)
    }
    return String(format: "%d min", max(1, m))
}
