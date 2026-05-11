import CoreText
import SwiftUI

enum ArabicTypography {
    private static let fontResourceName = "dima-thuluth"
    private static let fontResourceExtension = "ttf"
    private static var didRegister = false
    private static var cachedPostScriptName: String?

    static func registerFontIfNeeded() {
        guard !didRegister else { return }
        defer { didRegister = true }

        guard let url = Bundle.main.url(forResource: fontResourceName, withExtension: fontResourceExtension) else {
            return
        }

        cachedPostScriptName = postScriptName(from: url)
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

    static func quranFont(size: CGFloat, language: WidgetLanguage) -> Font {
        registerFontIfNeeded()
        guard resolvedLanguage(language) == .arabic, let name = cachedPostScriptName else {
            return .system(size: size, weight: .semibold, design: .rounded)
        }
        return .custom(name, size: size)
    }

    static func dayFont(size: CGFloat, language: WidgetLanguage, weight: Font.Weight = .bold) -> Font {
        registerFontIfNeeded()
        guard resolvedLanguage(language) == .arabic, let name = cachedPostScriptName else {
            return .system(size: size, weight: weight, design: .rounded)
        }
        return .custom(name, size: size)
    }

    private static func resolvedLanguage(_ language: WidgetLanguage) -> WidgetLanguage {
        switch language {
        case .arabic: return .arabic
        case .english: return .english
        case .auto:
            let preferred = Locale.preferredLanguages.first?.lowercased() ?? ""
            return preferred.hasPrefix("ar") ? .arabic : .english
        }
    }

    private static func postScriptName(from url: URL) -> String? {
        guard let dataProvider = CGDataProvider(url: url as CFURL),
              let cgFont = CGFont(dataProvider) else { return nil }
        return cgFont.postScriptName as String?
    }
}
