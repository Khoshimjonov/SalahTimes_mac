import SwiftUI
import SalahCore

/// Standard macOS Settings scene with TabView. Each tab is a Form with
/// Sections — the System Settings idiom. No custom palette; macOS provides
/// the look-and-feel.
struct SettingsRoot: View {
    @Bindable var settings: AppSettings
    var geocoder = Geocoder()
    @State private var lookupBusy = false
    @State private var lookupError: String?

    var body: some View {
        TabView {
            generalTab.tabItem { Label(L("settings.tab.general", settings.language), systemImage: "gear") }
            locationTab.tabItem { Label(L("settings.tab.location", settings.language), systemImage: "location") }
            calculationTab.tabItem { Label(L("settings.tab.calculation", settings.language), systemImage: "function") }
            notificationsTab.tabItem { Label(L("settings.tab.notifications", settings.language), systemImage: "bell") }
            menuBarTab.tabItem { Label(L("settings.tab.menubar", settings.language), systemImage: "menubar.rectangle") }
            aboutTab.tabItem { Label(L("settings.tab.about", settings.language), systemImage: "info.circle") }
        }
        .frame(width: 520, height: 460)
        .padding(.top, 8)
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Section {
                Picker(L("settings.language", settings.language),
                       selection: $settings.language) {
                    Text(L("settings.language.en", settings.language)).tag("en")
                    Text(L("settings.language.uz", settings.language)).tag("uz")
                    Text(L("settings.language.ru", settings.language)).tag("ru")
                }
                Toggle(L("settings.autostart", settings.language),
                       isOn: Binding(
                        get: { settings.autoStart },
                        set: { newValue in
                            let actual = LoginItemManager.setEnabled(newValue)
                            settings.autoStart = actual
                            settings.scheduleSave()
                        }))
            }
        }
        .formStyle(.grouped)
        .onChange(of: settings.language) { settings.scheduleSave() }
    }

    // MARK: - Location

    private var locationTab: some View {
        Form {
            Section {
                LabeledContent(L("settings.address", settings.language)) {
                    HStack {
                        TextField("", text: $settings.address)
                            .textFieldStyle(.roundedBorder)
                        Button(L("settings.address.lookup", settings.language)) {
                            Task { await lookupAddress() }
                        }
                        .disabled(lookupBusy)
                    }
                }
                if let err = lookupError {
                    Text(err).foregroundStyle(.red).font(.caption)
                }
                LabeledContent(L("settings.latitude", settings.language)) {
                    TextField("", value: $settings.latitude, format: .number.precision(.fractionLength(0...6)))
                        .textFieldStyle(.roundedBorder)
                }
                LabeledContent(L("settings.longitude", settings.language)) {
                    TextField("", value: $settings.longitude, format: .number.precision(.fractionLength(0...6)))
                        .textFieldStyle(.roundedBorder)
                }
                LabeledContent(L("settings.elevation", settings.language)) {
                    TextField("", value: $settings.elevation, format: .number.precision(.fractionLength(0...1)))
                        .textFieldStyle(.roundedBorder)
                }
                Picker(L("settings.timezone", settings.language),
                       selection: $settings.timeZoneIdentifier) {
                    ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) { id in
                        Text(id).tag(id)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: settings.latitude) { settings.scheduleSave() }
        .onChange(of: settings.longitude) { settings.scheduleSave() }
        .onChange(of: settings.elevation) { settings.scheduleSave() }
        .onChange(of: settings.address) { settings.scheduleSave() }
        .onChange(of: settings.timeZoneIdentifier) { settings.scheduleSave() }
    }

    private func lookupAddress() async {
        lookupError = nil
        lookupBusy = true
        defer { lookupBusy = false }
        do {
            let r = try await geocoder.lookup(address: settings.address)
            settings.latitude = r.latitude
            settings.longitude = r.longitude
            settings.elevation = r.elevation
            settings.address = r.displayName
            settings.scheduleSave()
        } catch {
            lookupError = L("error.location", settings.language)
        }
    }

    // MARK: - Calculation

    private var calculationTab: some View {
        Form {
            Section {
                Picker(L("settings.method", settings.language),
                       selection: $settings.calculationMethodCode) {
                    ForEach(CalculationMethod.allCases, id: \.self) { m in
                        Text(m.displayName).tag(m.code)
                    }
                }
                Picker(L("settings.school", settings.language),
                       selection: $settings.asrSchoolCode) {
                    Text(L("settings.school.shafii", settings.language)).tag(0)
                    Text(L("settings.school.hanafi", settings.language)).tag(1)
                }
                Picker(L("settings.highlat", settings.language),
                       selection: $settings.highLatitudeRule) {
                    Text(L("settings.highlat.none", settings.language)).tag(HighLatitudeRule.none)
                    Text(L("settings.highlat.nightMiddle", settings.language)).tag(HighLatitudeRule.nightMiddle)
                    Text(L("settings.highlat.oneSeventh", settings.language)).tag(HighLatitudeRule.oneSeventh)
                    Text(L("settings.highlat.angleBased", settings.language)).tag(HighLatitudeRule.angleBased)
                }
                Stepper(value: $settings.imsakMinutes, in: 0...60) {
                    LabeledContent(L("settings.imsak", settings.language)) {
                        Text("\(settings.imsakMinutes)")
                    }
                }
            }
            Section(L("settings.adjustments", settings.language)) {
                AdjStepper(label: "settings.adj.imsak", value: $settings.adjustmentImsak, lang: settings.language)
                AdjStepper(label: "settings.adj.fajr", value: $settings.adjustmentFajr, lang: settings.language)
                AdjStepper(label: "settings.adj.sunrise", value: $settings.adjustmentSunrise, lang: settings.language)
                AdjStepper(label: "settings.adj.dhuhr", value: $settings.adjustmentDhuhr, lang: settings.language)
                AdjStepper(label: "settings.adj.asr", value: $settings.adjustmentAsr, lang: settings.language)
                AdjStepper(label: "settings.adj.maghrib", value: $settings.adjustmentMaghrib, lang: settings.language)
                AdjStepper(label: "settings.adj.isha", value: $settings.adjustmentIsha, lang: settings.language)
            }
        }
        .formStyle(.grouped)
        .onChange(of: settings.calculationMethodCode) { settings.scheduleSave() }
        .onChange(of: settings.asrSchoolCode) { settings.scheduleSave() }
        .onChange(of: settings.highLatitudeRule) { settings.scheduleSave() }
        .onChange(of: settings.imsakMinutes) { settings.scheduleSave() }
        .onChange(of: settings.adjustmentImsak) { settings.scheduleSave() }
        .onChange(of: settings.adjustmentFajr) { settings.scheduleSave() }
        .onChange(of: settings.adjustmentSunrise) { settings.scheduleSave() }
        .onChange(of: settings.adjustmentDhuhr) { settings.scheduleSave() }
        .onChange(of: settings.adjustmentAsr) { settings.scheduleSave() }
        .onChange(of: settings.adjustmentMaghrib) { settings.scheduleSave() }
        .onChange(of: settings.adjustmentIsha) { settings.scheduleSave() }
    }

    // MARK: - Notifications

    private var notificationsTab: some View {
        Form {
            Section {
                Toggle(L("settings.notify.before", settings.language),
                       isOn: $settings.notifyBefore)
                Stepper(value: $settings.notifyBeforeMinutes, in: 1...180) {
                    LabeledContent(L("settings.notify.before.minutes", settings.language)) {
                        Text("\(settings.notifyBeforeMinutes)")
                    }
                }
                .disabled(!settings.notifyBefore)
                Toggle(L("settings.notify.ontime", settings.language),
                       isOn: $settings.notifyOnTime)
            }
        }
        .formStyle(.grouped)
        .onChange(of: settings.notifyBefore) { settings.scheduleSave() }
        .onChange(of: settings.notifyBeforeMinutes) { settings.scheduleSave() }
        .onChange(of: settings.notifyOnTime) { settings.scheduleSave() }
    }

    // MARK: - Menu bar

    private var menuBarTab: some View {
        Form {
            Section {
                Toggle(L("settings.menubar.showName", settings.language),
                       isOn: $settings.menuBarShowPrayerName)
                Toggle(L("settings.menubar.showRemaining", settings.language),
                       isOn: $settings.menuBarShowRemainingTime)
                Toggle(L("settings.menubar.showIcon", settings.language),
                       isOn: $settings.menuBarShowIcon)
                Toggle(L("settings.menubar.shortNames", settings.language),
                       isOn: $settings.menuBarUseShortNames)
                Toggle(L("settings.menubar.compactSeconds", settings.language),
                       isOn: $settings.menuBarCompactSeconds)
            }
        }
        .formStyle(.grouped)
        .onChange(of: settings.menuBarShowPrayerName) { settings.scheduleSave() }
        .onChange(of: settings.menuBarShowRemainingTime) { settings.scheduleSave() }
        .onChange(of: settings.menuBarShowIcon) { settings.scheduleSave() }
        .onChange(of: settings.menuBarUseShortNames) { settings.scheduleSave() }
        .onChange(of: settings.menuBarCompactSeconds) { settings.scheduleSave() }
    }

    // MARK: - About

    private var aboutTab: some View {
        VStack(spacing: 8) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text(L("settings.about.title", settings.language))
                .font(.title2)
            let version = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0.0"
            Text(String(format: L("settings.about.version", settings.language), version))
                .foregroundStyle(.secondary)
                .font(.callout)
            Text(L("settings.about.copyright", settings.language))
                .foregroundStyle(.tertiary)
                .font(.caption)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private struct AdjStepper: View {
    let label: String
    @Binding var value: Int
    let lang: String

    var body: some View {
        Stepper(value: $value, in: -30...30) {
            LabeledContent(L(label, lang)) {
                Text(value >= 0 ? "+\(value)" : "\(value)")
                    .monospacedDigit()
            }
        }
    }
}
