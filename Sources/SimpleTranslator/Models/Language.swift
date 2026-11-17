import Foundation
import NaturalLanguage

enum Languages {
    static let auto = "auto"
    static let common = ["ru", "en", "de", "fr", "es", "it", "pt", "zh", "ja", "ko", "tr", "uk", "pl", "ar", "he", "kk"]
    static let all: [String] = Array(Set(Locale.LanguageCode.isoLanguageCodes.map(\.identifier) + common)).filter { $0.count == 2 }
        .sorted { name($0).localizedCaseInsensitiveCompare(name($1)) == .orderedAscending }
    static func name(_ code: String) -> String {
        if code == auto { return "Авто" }
        return Locale(identifier: "ru").localizedString(forLanguageCode: code)?.localizedCapitalized ?? code
    }
    static func englishName(_ code: String) -> String {
        Locale(identifier: "en").localizedString(forLanguageCode: code) ?? code
    }
    static func detect(_ text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(String(text.prefix(8_000)))
        return recognizer.dominantLanguage?.rawValue.components(separatedBy: "-").first
    }
    static func target(selected: String, source: String?) -> String {
        selected == auto ? (source == "ru" ? "en" : "ru") : selected
    }
}
