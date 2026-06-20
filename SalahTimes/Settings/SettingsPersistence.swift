import Foundation

/// Atomic JSON read/write of `AppSettings.Snapshot` at
/// `~/Library/Application Support/SalahTimes/settings.json`.
public struct SettingsPersistence: Sendable {

    public let url: URL

    public static let `default`: SettingsPersistence = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask).first!
        let dir = base.appendingPathComponent("SalahTimes", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir,
                                                 withIntermediateDirectories: true)
        return SettingsPersistence(url: dir.appendingPathComponent("settings.json"))
    }()

    public func load() -> AppSettings.Snapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(AppSettings.Snapshot.self, from: data)
    }

    public func save(_ snapshot: AppSettings.Snapshot) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(snapshot) else { return }
        // `.atomic` writes to a temp file and renames into place — no need
        // for replaceItemAt, which fails on first save when the destination
        // doesn't yet exist.
        try? data.write(to: url, options: .atomic)
    }
}
