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

    static func quranFont(size: CGFloat, appLanguage: AppLanguage) -> Font {
        registerFontIfNeeded()
        guard appLanguage == .arabic, let name = cachedPostScriptName else {
            return .system(size: size, weight: .semibold, design: .rounded)
        }
        return .custom(name, size: size)
    }

    static func dayFont(size: CGFloat, appLanguage: AppLanguage, weight: Font.Weight = .bold) -> Font {
        registerFontIfNeeded()
        guard appLanguage == .arabic, let name = cachedPostScriptName else {
            return .system(size: size, weight: weight, design: .rounded)
        }
        return .custom(name, size: size)
    }

    private static func postScriptName(from url: URL) -> String? {
        guard let dataProvider = CGDataProvider(url: url as CFURL),
              let cgFont = CGFont(dataProvider) else { return nil }
        return cgFont.postScriptName as String?
    }
}
