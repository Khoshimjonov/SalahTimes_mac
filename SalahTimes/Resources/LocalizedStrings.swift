import Foundation

/// Runtime language lookup that bypasses `AppleLanguages` UserDefaults so the
/// menu-bar string and dropdown can re-render the moment the user picks a new
/// language in Settings — no app restart, no per-launch quirks.
///
/// Loads `en.lproj/uz.lproj/ru.lproj/Localizable.strings` from the app bundle
/// once and caches the per-language `Bundle` instances.
enum LocalizedStrings {

    static func string(_ key: String, language: String) -> String {
        let lang = supportedLanguages.contains(language) ? language : "en"
        let bundle = bundles[lang] ?? .main
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    private static let supportedLanguages: Set<String> = ["en", "uz", "ru"]

    private static let bundles: [String: Bundle] = {
        var dict: [String: Bundle] = [:]
        for lang in supportedLanguages {
            if let path = Bundle.main.path(forResource: lang, ofType: "lproj"),
               let b = Bundle(path: path) {
                dict[lang] = b
            }
        }
        return dict
    }()
}

/// Convenience wrapper used everywhere in views: `L("settings.title", lang)`.
func L(_ key: String, _ language: String) -> String {
    LocalizedStrings.string(key, language: language)
}
