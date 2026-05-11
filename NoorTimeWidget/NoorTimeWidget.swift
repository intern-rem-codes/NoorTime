import AppIntents
import SwiftUI
import WidgetKit

private enum NoorWidgetShared {
    static let suite = "group.noortime"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: suite) ?? .standard
    }

    static func toArabicDigits(_ value: String) -> String {
        let map: [Character: Character] = [
            "0": "٠", "1": "١", "2": "٢", "3": "٣", "4": "٤",
            "5": "٥", "6": "٦", "7": "٧", "8": "٨", "9": "٩",
        ]
        return String(value.map { map[$0] ?? $0 })
    }

    static func resolvedDigits(_ digits: WidgetDigits, language: WidgetLanguage) -> WidgetDigits {
        switch digits {
        case .auto:
            return resolvedLanguage(language) == .arabic ? .arabic : .english
        case .english, .arabic:
            return digits
        }
    }

    static func resolvedBackground(_ style: WidgetBackgroundStyle) -> WidgetBackgroundStyle {
        switch style {
        case .auto:
            return .black
        case .black, .midnight, .ocean, .emerald, .sand, .plum, .graphite:
            return style
        }
    }

    static func resolvedLanguage(_ language: WidgetLanguage) -> WidgetLanguage {
        switch language {
        case .auto:
            let preferred = Locale.preferredLanguages.first ?? Locale.current.identifier
            return preferred.lowercased().hasPrefix("ar") ? .arabic : .english
        case .english, .arabic:
            return language
        }
    }

    static func formatTime(_ date: Date, language: WidgetLanguage, digits: WidgetDigits) -> String {
        let resolvedLanguage = resolvedLanguage(language)
        let resolvedDigits = resolvedDigits(digits, language: language)
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        formatter.locale =
            resolvedLanguage == .arabic ? Locale(identifier: "ar") : Locale(identifier: "en")
        let raw = formatter.string(from: date)
        return resolvedDigits == .arabic ? toArabicDigits(raw) : raw
    }

    static func formatDate(
        _ date: Date, language: WidgetLanguage, digits: WidgetDigits, calendar: WidgetCalendar,
        format: WidgetDateFormat
    ) -> String {
        let resolvedLanguage = resolvedLanguage(language)
        let resolvedDigits = resolvedDigits(digits, language: language)
        let formatter = DateFormatter()
        switch format {
        case .auto:
            formatter.calendar =
                calendar == .hijri
                ? Calendar(identifier: .islamicUmmAlQura) : Calendar(identifier: .gregorian)
            formatter.locale =
                resolvedLanguage == .arabic ? Locale(identifier: "ar") : Locale(identifier: "en")
            formatter.dateFormat = "dd / MM / yyyy"
            let raw = formatter.string(from: date)
            return resolvedDigits == .arabic ? toArabicDigits(raw) : raw
        case .gregorianArabic:
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "ar")
            formatter.dateFormat = "dd / MM / yyyy"
            return toArabicDigits(formatter.string(from: date))
        case .hijriArabic:
            formatter.calendar = Calendar(identifier: .islamicUmmAlQura)
            formatter.locale = Locale(identifier: "ar")
            formatter.dateFormat = "dd / MM / yyyy"
            return toArabicDigits(formatter.string(from: date))
        case .gregorianEnglish:
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en")
            formatter.dateFormat = "dd / MM / yyyy"
            return formatter.string(from: date)
        case .hijriEnglish:
            formatter.calendar = Calendar(identifier: .islamicUmmAlQura)
            formatter.locale = Locale(identifier: "en")
            formatter.dateFormat = "dd / MM / yyyy"
            return formatter.string(from: date)
        }
    }

    static func widgetBackground(for style: WidgetBackgroundStyle) -> LinearGradient {
        switch resolvedBackground(style) {
        case .black:
            return LinearGradient(
                colors: [Color.black, Color(white: 0.12)], startPoint: .top, endPoint: .bottom)
        case .midnight:
            return LinearGradient(
                colors: [Color(red: 0.05, green: 0.08, blue: 0.16), Color.black],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        case .ocean:
            return LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.24, blue: 0.38),
                    Color(red: 0.01, green: 0.09, blue: 0.18),
                ], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .emerald:
            return LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.28, blue: 0.20),
                    Color(red: 0.01, green: 0.10, blue: 0.08),
                ], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .sand:
            return LinearGradient(
                colors: [
                    Color(red: 0.42, green: 0.31, blue: 0.18),
                    Color(red: 0.16, green: 0.11, blue: 0.05),
                ], startPoint: .top, endPoint: .bottom)
        case .plum:
            return LinearGradient(
                colors: [
                    Color(red: 0.28, green: 0.11, blue: 0.24),
                    Color(red: 0.09, green: 0.03, blue: 0.09),
                ], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .graphite:
            return LinearGradient(
                colors: [
                    Color(red: 0.22, green: 0.24, blue: 0.27),
                    Color(red: 0.08, green: 0.09, blue: 0.11),
                ], startPoint: .top, endPoint: .bottom)
        case .auto:
            return LinearGradient(
                colors: [Color.black, Color(white: 0.12)], startPoint: .top, endPoint: .bottom)
        }
    }

    static func prayerTimes(for date: Date, latitude: Double, longitude: Double) -> [(String, Date)]
    {
        guard
            let times = SolarPrayerCalculator.compute(
                for: date, latitude: latitude, longitude: longitude)
        else {
            return []
        }
        return [
            ("Fajr", times.fajr),
            ("Sunrise", times.sunrise),
            ("Dhuhr", times.dhuhr),
            ("Asr", times.asr),
            ("Maghrib", times.maghrib),
            ("Isha", times.isha),
        ]
    }

    static func fetchWeather(latitude: Double, longitude: Double) async -> WeatherSnapshot? {
        let urlString =
            "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&current=temperature_2m,weathercode&daily=temperature_2m_max,temperature_2m_min&timezone=auto"
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (bytes, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: bytes)
            guard let current = decoded.current else { return nil }
            let meta = condition(for: current.weathercode)
            let high = decoded.daily?.temperature_2m_max?.first
            let low = decoded.daily?.temperature_2m_min?.first
            return WeatherSnapshot(
                symbol: meta.symbol, label: meta.label, tempC: current.temperature_2m, highC: high,
                lowC: low)
        } catch {
            return nil
        }
    }

    static func condition(for code: Int) -> (symbol: String, label: String) {
        switch code {
        case 0: return ("sun.max.fill", "Clear")
        case 1, 2, 3: return ("cloud.sun.fill", "Partly Cloudy")
        case 45, 48: return ("cloud.fog.fill", "Fog")
        case 51, 53, 55, 56, 57: return ("cloud.drizzle.fill", "Drizzle")
        case 61, 63, 65, 66, 67: return ("cloud.rain.fill", "Rain")
        case 71, 73, 75, 77: return ("cloud.snow.fill", "Snow")
        case 80, 81, 82: return ("cloud.heavyrain.fill", "Showers")
        case 95, 96, 99: return ("cloud.bolt.rain.fill", "Thunder")
        default: return ("cloud.fill", "Weather")
        }
    }

    static func shortMonth(_ date: Date, language: WidgetLanguage) -> String {
        let formatter = DateFormatter()
        formatter.locale =
            resolvedLanguage(language) == .arabic
            ? Locale(identifier: "ar") : Locale(identifier: "en")
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        return formatter.string(from: date)
    }

    static func monthName(_ date: Date, language: WidgetLanguage) -> String {
        let formatter = DateFormatter()
        formatter.locale =
            resolvedLanguage(language) == .arabic
            ? Locale(identifier: "ar") : Locale(identifier: "en")
        formatter.setLocalizedDateFormatFromTemplate("MMMM")
        return formatter.string(from: date)
    }

    static func weekdayNameFull(_ date: Date, language: WidgetLanguage) -> String {
        let formatter = DateFormatter()
        formatter.locale =
            resolvedLanguage(language) == .arabic
            ? Locale(identifier: "ar") : Locale(identifier: "en")
        formatter.setLocalizedDateFormatFromTemplate("EEEE")
        return formatter.string(from: date)
    }

    static func yearNumber(_ date: Date, digits: WidgetDigits, language: WidgetLanguage) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en")
        formatter.dateFormat = "yyyy"
        let raw = formatter.string(from: date)
        return resolvedDigits(digits, language: language) == .arabic ? toArabicDigits(raw) : raw
    }

    static func hijriMonthName(_ date: Date, language: WidgetLanguage) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .islamicUmmAlQura)
        formatter.locale =
            resolvedLanguage(language) == .arabic
            ? Locale(identifier: "ar") : Locale(identifier: "en")
        formatter.setLocalizedDateFormatFromTemplate("MMMM")
        return formatter.string(from: date)
    }

    static func dayNumber(_ date: Date, digits: WidgetDigits, language: WidgetLanguage) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en")
        formatter.dateFormat = "d"
        let raw = formatter.string(from: date)
        return resolvedDigits(digits, language: language) == .arabic ? toArabicDigits(raw) : raw
    }

    static func hijriDayNumber(_ date: Date, digits: WidgetDigits, language: WidgetLanguage)
        -> String
    {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .islamicUmmAlQura)
        formatter.locale = Locale(identifier: "en")
        formatter.dateFormat = "d"
        let raw = formatter.string(from: date)
        return resolvedDigits(digits, language: language) == .arabic ? toArabicDigits(raw) : raw
    }

    static func hijriYearNumber(_ date: Date, digits: WidgetDigits, language: WidgetLanguage)
        -> String
    {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .islamicUmmAlQura)
        formatter.locale = Locale(identifier: "en")
        formatter.dateFormat = "yyyy"
        let raw = formatter.string(from: date)
        return resolvedDigits(digits, language: language) == .arabic ? toArabicDigits(raw) : raw
    }

    static func qiblaDirection(latitude: Double, longitude: Double) -> Double {
        let kLat = 21.4225 * .pi / 180
        let kLon = 39.8262 * .pi / 180
        let lat1 = latitude * .pi / 180
        let dLon = kLon - longitude * .pi / 180
        let y = sin(dLon) * cos(kLat)
        let x = cos(lat1) * sin(kLat) - sin(lat1) * cos(kLat) * cos(dLon)
        var bearing = atan2(y, x) * 180 / .pi
        if bearing < 0 { bearing += 360 }
        return bearing
    }
}

// ─────────────────────────────────────────────────────────────────
// MARK: - Solar Prayer Calculator
// ─────────────────────────────────────────────────────────────────
private struct SolarPrayerCalculator {

    struct Times {
        let fajr: Date
        let sunrise: Date
        let dhuhr: Date
        let asr: Date
        let maghrib: Date
        let isha: Date
    }

    static func compute(for day: Date, latitude: Double, longitude: Double) -> Times? {
        let calendar = Calendar.current
        guard let dayOfYear = calendar.ordinality(of: .day, in: .year, for: day) else { return nil }

        let gamma = 2.0 * Double.pi / 365.0 * (Double(dayOfYear) - 1.0)
        let equation =
            229.18
            * (0.000075 + 0.001868 * cos(gamma) - 0.032077 * sin(gamma) - 0.014615 * cos(2 * gamma)
                - 0.040849 * sin(2 * gamma))
        let declination =
            0.006918 - 0.399912 * cos(gamma) + 0.070257 * sin(gamma) - 0.006758 * cos(2 * gamma)
            + 0.000907 * sin(2 * gamma) - 0.002697 * cos(3 * gamma) + 0.00148 * sin(3 * gamma)

        let tz = TimeZone.current
        let tzOffset = Double(tz.secondsFromGMT(for: day)) / 60.0
        let noon = 720.0 - 4.0 * longitude - equation + tzOffset

        guard
            let sunriseHA = hourAngle(
                latitude: latitude, declination: declination, zenithDegrees: 90.833)
        else { return nil }

        let sunrise = noon - 4.0 * sunriseHA
        let sunset = noon + 4.0 * sunriseHA

        let fajrHA = hourAngle(latitude: latitude, declination: declination, zenithDegrees: 108.0)
        let ishaHA = hourAngle(latitude: latitude, declination: declination, zenithDegrees: 107.0)

        let fajr = (fajrHA.map { noon - 4.0 * $0 }) ?? (sunrise - 90.0)
        let isha = (ishaHA.map { noon + 4.0 * $0 }) ?? (sunset + 90.0)

        let latRad = latitude * .pi / 180.0
        let shadowAngle = atan(1.0 / (1.0 + tan(abs(latRad - declination))))
        let asrZenith = 90.0 - shadowAngle * 180.0 / .pi
        let asrHA = hourAngle(
            latitude: latitude, declination: declination, zenithDegrees: asrZenith)
        let asr = (asrHA.map { noon + 4.0 * $0 }) ?? ((noon + sunset) / 2.0)

        return Times(
            fajr: date(fromMinutes: fajr, day: day, timeZone: tz),
            sunrise: date(fromMinutes: sunrise, day: day, timeZone: tz),
            dhuhr: date(fromMinutes: noon, day: day, timeZone: tz),
            asr: date(fromMinutes: asr, day: day, timeZone: tz),
            maghrib: date(fromMinutes: sunset, day: day, timeZone: tz),
            isha: date(fromMinutes: isha, day: day, timeZone: tz)
        )
    }

    private static func hourAngle(latitude: Double, declination: Double, zenithDegrees: Double)
        -> Double?
    {
        let lat = latitude * .pi / 180.0
        let zenith = zenithDegrees * .pi / 180.0
        let numerator = cos(zenith) - sin(lat) * sin(declination)
        let denominator = cos(lat) * cos(declination)
        guard denominator != 0 else { return nil }
        let raw = numerator / denominator
        guard raw >= -1, raw <= 1 else { return nil }
        return acos(raw) * 180.0 / .pi
    }

    private static func date(fromMinutes minutes: Double, day: Date, timeZone: TimeZone) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let start = cal.startOfDay(for: day)
        return start.addingTimeInterval(minutes * 60.0)
    }
}

// ─────────────────────────────────────────────────────────────────
// MARK: - Enums
// ─────────────────────────────────────────────────────────────────

enum WidgetFace: String, AppEnum {
    case clock
    case date
    case weather
    case minimalist
    case gradientRing
    case retroNeon
    case geometric
    case luxuryGold
    case midnight
    case prayerProgress
    case qiblaCompass
    case currentWeather
    case compactWeather
    case prayerTimes
    case arabicMonthTile

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Widget Type"
    static var caseDisplayRepresentations: [WidgetFace: DisplayRepresentation] = [
        .clock: "Clock",
        .date: "Date",
        .weather: "Weather",
        .minimalist: "Minimalist",
        .gradientRing: "Gradient Ring",
        .retroNeon: "Retro Neon",
        .geometric: "Geometric",
        .luxuryGold: "Luxury Gold",
        .midnight: "Midnight",
        .prayerProgress: "Prayer Progress",
        .qiblaCompass: "Qibla Compass",
        .currentWeather: "Current Weather",
        .compactWeather: "Compact Weather",
        .prayerTimes: "Prayer Times",
        .arabicMonthTile: "Arabic Month Tile",
    ]
}

enum WidgetFaceLarge: String, AppEnum {
    case clock
    case date
    case todayDate
    case dualCalendar
    case monthGrid
    case islamicDate
    case weather
    case currentWeather
    case compactWeather
    case prayerTimes
    case nextPrayer
    case prayerTimeline
    case prayerProgress
    case qiblaCompass
    case weekPulse
    case monthProgress
    case yearJourney
    case tripleOrbit
    case luminousDigital
    case calendarDuo
    case minimalClock
    case dualLineTime
    case gregorian
    case hijri
    case thuluthSmall
    case thuluthMedium
    case thuluthLarge
    case monthPosterEnglish
    case monthPosterArabic

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Large Widget Style"
    static var caseDisplayRepresentations: [WidgetFaceLarge: DisplayRepresentation] = [
        .clock: "Clock",
        .date: "Date",
        .todayDate: "Today Date",
        .dualCalendar: "Dual Calendar",
        .monthGrid: "Month Grid",
        .islamicDate: "Islamic Date",
        .weather: "Weather",
        .currentWeather: "Current Weather",
        .compactWeather: "Compact Weather",
        .prayerTimes: "Prayer Times",
        .nextPrayer: "Next Prayer",
        .prayerTimeline: "Prayer Timeline",
        .prayerProgress: "Prayer Progress",
        .qiblaCompass: "Qibla Compass",
        .weekPulse: "Week Pulse",
        .monthProgress: "Month Progress",
        .yearJourney: "Year Journey",
        .tripleOrbit: "Triple Orbit",
        .luminousDigital: "Luminous Digital",
        .calendarDuo: "Calendar Duo",
        .minimalClock: "Minimal Clock",
        .dualLineTime: "Dual Line Time",
        .gregorian: "Gregorian",
        .hijri: "Hijri",
        .thuluthSmall: "Thuluth Small",
        .thuluthMedium: "Thuluth Medium",
        .thuluthLarge: "Thuluth Large",
        .monthPosterEnglish: "Month Poster (EN)",
        .monthPosterArabic: "Month Poster (AR)",
    ]
}

enum WidgetFaceMedium: String, AppEnum {
    case clock
    case date
    case weather
    case currentWeather
    case compactWeather
    case luminousDigital
    case calendarDuo
    case minimalClock
    case dualLineTime
    case gregorian
    case hijri
    case weekPulse
    case monthProgress
    case yearJourney
    case quranAyah
    case quranDhikr
    case quranTicker
    case quranVerse1
    case quranVerse2
    case quranVerse3
    case quranVerse4
    case arabicWeekday
    case arabicToday
    case arabicMonthPoster

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Medium Widget Style"
    static var caseDisplayRepresentations: [WidgetFaceMedium: DisplayRepresentation] = [
        .clock: "Clock",
        .date: "Date",
        .weather: "Weather",
        .currentWeather: "Current Weather",
        .compactWeather: "Compact Weather",
        .luminousDigital: "Luminous Digital",
        .calendarDuo: "Calendar Duo",
        .minimalClock: "Minimal Clock",
        .dualLineTime: "Dual Line Time",
        .gregorian: "Gregorian",
        .hijri: "Hijri",
        .weekPulse: "Week Pulse",
        .monthProgress: "Month Progress",
        .yearJourney: "Year Journey",
        .quranAyah: "Quran Ayah",
        .quranDhikr: "Quran Dhikr",
        .quranTicker: "Ayah Ticker",
        .quranVerse1: "Quran Verse 1",
        .quranVerse2: "Quran Verse 2",
        .quranVerse3: "Quran Verse 3",
        .quranVerse4: "Quran Verse 4",
        .arabicWeekday: "Arabic Weekday",
        .arabicToday: "Arabic Today",
        .arabicMonthPoster: "Arabic Month Poster",
    ]
}

enum WidgetDigits: String, AppEnum {
    case auto
    case english
    case arabic

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Number Pattern"
    static var caseDisplayRepresentations: [WidgetDigits: DisplayRepresentation] = [
        .auto: "Auto",
        .english: "123",
        .arabic: "١٢٣",
    ]
}

enum WidgetLanguage: String, AppEnum {
    case auto
    case english
    case arabic

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Language"
    static var caseDisplayRepresentations: [WidgetLanguage: DisplayRepresentation] = [
        .auto: "Auto",
        .english: "English",
        .arabic: "العربية",
    ]
}

enum WidgetCalendar: String, AppEnum {
    case gregorian
    case hijri

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Calendar"
    static var caseDisplayRepresentations: [WidgetCalendar: DisplayRepresentation] = [
        .gregorian: "Gregorian",
        .hijri: "Hijri",
    ]
}

enum WidgetDateFormat: String, AppEnum {
    case auto
    case gregorianArabic
    case hijriArabic
    case gregorianEnglish
    case hijriEnglish

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Date Format"
    static var caseDisplayRepresentations: [WidgetDateFormat: DisplayRepresentation] = [
        .auto: "Auto",
        .gregorianArabic: "٢٠٢٦ / ٠٤ / ٠٧",
        .hijriArabic: "١٤٤٧ / ١٠ / ١٩",
        .gregorianEnglish: "07 / 04 / 2026",
        .hijriEnglish: "19 / 10 / 1447",
    ]
}

enum WidgetBackgroundStyle: String, AppEnum {
    case auto
    case black
    case midnight
    case ocean
    case emerald
    case sand
    case plum
    case graphite

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Background"
    static var caseDisplayRepresentations: [WidgetBackgroundStyle: DisplayRepresentation] = [
        .auto: "Auto",
        .black: "Black",
        .midnight: "Midnight",
        .ocean: "Ocean",
        .emerald: "Emerald",
        .sand: "Sand",
        .plum: "Plum",
        .graphite: "Graphite",
    ]
}

// ─────────────────────────────────────────────────────────────────
// MARK: - Intents / Entries / Providers
// ─────────────────────────────────────────────────────────────────

struct NoorWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Noor Time Widget"
    static var description = IntentDescription(
        "Choose widget style, digits, language, calendar, background and date format.")

    @Parameter(title: "Widget", default: .clock)
    var face: WidgetFace

    @Parameter(title: "Number Pattern", default: .auto)
    var digits: WidgetDigits

    @Parameter(title: "Language", default: .auto)
    var language: WidgetLanguage

    @Parameter(title: "Calendar", default: .gregorian)
    var calendar: WidgetCalendar

    @Parameter(title: "Background", default: .auto)
    var background: WidgetBackgroundStyle

    @Parameter(title: "Date Format", default: .auto)
    var dateFormat: WidgetDateFormat

    static var parameterSummary: some ParameterSummary {
        Summary {
            \.$face
            \.$digits
            \.$language
            \.$calendar
            \.$background
            \.$dateFormat
        }
    }
}

struct NoorWidgetEntry: TimelineEntry {
    let date: Date
    let configuration: NoorWidgetIntent
    let weather: WeatherSnapshot?
    let prayerTimes: [(String, Date)]
}

// ─────────────────────────────────────────────────────────────────
// MARK: - Small Provider (1-second entries voor vloeiende klokwijzers)
// ─────────────────────────────────────────────────────────────────
private struct NoorWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> NoorWidgetEntry {
        NoorWidgetEntry(
            date: .now, configuration: NoorWidgetIntent(), weather: nil, prayerTimes: [])
    }

    func snapshot(for configuration: NoorWidgetIntent, in context: Context) async -> NoorWidgetEntry
    {
        await makeEntry(configuration: configuration)
    }

    func timeline(for configuration: NoorWidgetIntent, in context: Context) async -> Timeline<
        NoorWidgetEntry
    > {
        let defaults = NoorWidgetShared.defaults
        let lat = defaults.double(forKey: "noor.lastLatitude")
        let lon = defaults.double(forKey: "noor.lastLongitude")
        let effectiveLat = (lat == 0 && lon == 0) ? 52.3676 : lat
        let effectiveLon = (lat == 0 && lon == 0) ? 4.9041 : lon

        let weather = await NoorWidgetShared.fetchWeather(
            latitude: effectiveLat, longitude: effectiveLon)
        let prayers = NoorWidgetShared.prayerTimes(
            for: .now, latitude: effectiveLat, longitude: effectiveLon)

        let cal = Calendar.current
        // Snap to current second (no sub-second jitter)
        let now =
            cal.date(
                bySetting: .nanosecond, value: 0,
                of: .now) ?? .now

        // ── SLEUTEL FIX ──────────────────────────────────────────
        // Bepaal of de huidige face een analoge klok is.
        // Analoge klokken hebben 1-seconde entries nodig.
        // Andere faces (datum, weer, gebed) gaan per minuut — dat spaart resources.
        let needsSeconds =
            configuration.face == .minimalist
            || configuration.face == .gradientRing
            || configuration.face == .retroNeon
            || configuration.face == .geometric
            || configuration.face == .luxuryGold
            || configuration.face == .midnight

        let entries: [NoorWidgetEntry]
        let reloadDate: Date

        if needsSeconds {
            // 10 minuten aan 1-seconde entries (= 600 entries)
            // iOS vernieuwt de timeline na reloadDate automatisch.
            let totalSeconds = 600
            entries = (0..<totalSeconds).map { i in
                let entryDate = cal.date(byAdding: .second, value: i, to: now) ?? now
                return NoorWidgetEntry(
                    date: entryDate,
                    configuration: configuration,
                    weather: weather,
                    prayerTimes: prayers
                )
            }
            reloadDate =
                cal.date(byAdding: .second, value: totalSeconds, to: now)
                ?? now.addingTimeInterval(TimeInterval(totalSeconds))
        } else {
            // Niet-analoge faces: 60 entries van 1 minuut
            entries = (0..<60).map { minute in
                let entryDate = cal.date(byAdding: .minute, value: minute, to: now) ?? now
                return NoorWidgetEntry(
                    date: entryDate,
                    configuration: configuration,
                    weather: weather,
                    prayerTimes: prayers
                )
            }
            reloadDate =
                cal.date(byAdding: .minute, value: 60, to: now)
                ?? now.addingTimeInterval(3600)
        }

        return Timeline(entries: entries, policy: .after(reloadDate))
    }

    private func makeEntry(configuration: NoorWidgetIntent) async -> NoorWidgetEntry {
        let defaults = NoorWidgetShared.defaults
        let lat = defaults.double(forKey: "noor.lastLatitude")
        let lon = defaults.double(forKey: "noor.lastLongitude")
        let effectiveLat = (lat == 0 && lon == 0) ? 52.3676 : lat
        let effectiveLon = (lat == 0 && lon == 0) ? 4.9041 : lon

        let weather = await NoorWidgetShared.fetchWeather(
            latitude: effectiveLat, longitude: effectiveLon)
        let prayers = NoorWidgetShared.prayerTimes(
            for: .now, latitude: effectiveLat, longitude: effectiveLon)

        return NoorWidgetEntry(
            date: .now, configuration: configuration, weather: weather, prayerTimes: prayers)
    }
}

// ─────────────────────────────────────────────────────────────────
// MARK: - Large intent / entry / provider
// ─────────────────────────────────────────────────────────────────

struct NoorLargeWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Noor Time Large Widget"
    static var description = IntentDescription(
        "Choose large widget style, digits, language, calendar, background and date format.")

    @Parameter(title: "Widget", default: .clock)
    var face: WidgetFaceLarge

    @Parameter(title: "Number Pattern", default: .auto)
    var digits: WidgetDigits

    @Parameter(title: "Language", default: .auto)
    var language: WidgetLanguage

    @Parameter(title: "Calendar", default: .gregorian)
    var calendar: WidgetCalendar

    @Parameter(title: "Background", default: .auto)
    var background: WidgetBackgroundStyle

    @Parameter(title: "Date Format", default: .auto)
    var dateFormat: WidgetDateFormat

    static var parameterSummary: some ParameterSummary {
        Summary {
            \.$face
            \.$digits
            \.$language
            \.$calendar
            \.$background
            \.$dateFormat
        }
    }
}

struct NoorLargeWidgetEntry: TimelineEntry {
    let date: Date
    let configuration: NoorLargeWidgetIntent
    let weather: WeatherSnapshot?
    let prayerTimes: [(String, Date)]
}

struct NoorLargeWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> NoorLargeWidgetEntry {
        NoorLargeWidgetEntry(
            date: .now, configuration: NoorLargeWidgetIntent(), weather: nil, prayerTimes: [])
    }

    func snapshot(for configuration: NoorLargeWidgetIntent, in context: Context) async
        -> NoorLargeWidgetEntry
    {
        await makeEntry(configuration: configuration)
    }

    func timeline(for configuration: NoorLargeWidgetIntent, in context: Context) async -> Timeline<
        NoorLargeWidgetEntry
    > {
        let defaults = NoorWidgetShared.defaults
        let lat = defaults.double(forKey: "noor.lastLatitude")
        let lon = defaults.double(forKey: "noor.lastLongitude")
        let effectiveLat = (lat == 0 && lon == 0) ? 52.3676 : lat
        let effectiveLon = (lat == 0 && lon == 0) ? 4.9041 : lon

        let weather = await NoorWidgetShared.fetchWeather(
            latitude: effectiveLat, longitude: effectiveLon)
        let prayers = NoorWidgetShared.prayerTimes(
            for: .now, latitude: effectiveLat, longitude: effectiveLon)

        let cal = Calendar.current
        let now = cal.date(bySetting: .nanosecond, value: 0, of: .now) ?? .now

        let entries: [NoorLargeWidgetEntry] = (0..<60).map { minute in
            let entryDate = cal.date(byAdding: .minute, value: minute, to: now) ?? now
            return NoorLargeWidgetEntry(
                date: entryDate,
                configuration: configuration,
                weather: weather,
                prayerTimes: prayers
            )
        }

        let reload = cal.date(byAdding: .minute, value: 60, to: now) ?? now.addingTimeInterval(3600)
        return Timeline(entries: entries, policy: .after(reload))
    }

    private func makeEntry(configuration: NoorLargeWidgetIntent) async -> NoorLargeWidgetEntry {
        let defaults = NoorWidgetShared.defaults
        let lat = defaults.double(forKey: "noor.lastLatitude")
        let lon = defaults.double(forKey: "noor.lastLongitude")
        let effectiveLat = (lat == 0 && lon == 0) ? 52.3676 : lat
        let effectiveLon = (lat == 0 && lon == 0) ? 4.9041 : lon

        let weather = await NoorWidgetShared.fetchWeather(
            latitude: effectiveLat, longitude: effectiveLon)
        let prayers = NoorWidgetShared.prayerTimes(
            for: .now, latitude: effectiveLat, longitude: effectiveLon)

        return NoorLargeWidgetEntry(
            date: .now, configuration: configuration, weather: weather, prayerTimes: prayers)
    }
}

struct NoorMediumWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Noor Time Medium Widget"
    static var description = IntentDescription(
        "Choose medium widget style, digits, language, calendar, background and date format.")

    @Parameter(title: "Widget", default: .clock)
    var face: WidgetFaceMedium

    @Parameter(title: "Number Pattern", default: .auto)
    var digits: WidgetDigits

    @Parameter(title: "Language", default: .auto)
    var language: WidgetLanguage

    @Parameter(title: "Calendar", default: .gregorian)
    var calendar: WidgetCalendar

    @Parameter(title: "Background", default: .auto)
    var background: WidgetBackgroundStyle

    @Parameter(title: "Date Format", default: .auto)
    var dateFormat: WidgetDateFormat

    static var parameterSummary: some ParameterSummary {
        Summary {
            \.$face
            \.$digits
            \.$language
            \.$calendar
            \.$background
            \.$dateFormat
        }
    }
}

struct NoorMediumWidgetEntry: TimelineEntry {
    let date: Date
    let configuration: NoorMediumWidgetIntent
    let weather: WeatherSnapshot?
    let prayerTimes: [(String, Date)]
}

struct NoorMediumWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> NoorMediumWidgetEntry {
        NoorMediumWidgetEntry(
            date: .now, configuration: NoorMediumWidgetIntent(), weather: nil, prayerTimes: [])
    }

    func snapshot(for configuration: NoorMediumWidgetIntent, in context: Context) async
        -> NoorMediumWidgetEntry
    {
        await makeEntry(configuration: configuration)
    }

    func timeline(for configuration: NoorMediumWidgetIntent, in context: Context) async -> Timeline<
        NoorMediumWidgetEntry
    > {
        let defaults = NoorWidgetShared.defaults
        let lat = defaults.double(forKey: "noor.lastLatitude")
        let lon = defaults.double(forKey: "noor.lastLongitude")
        let effectiveLat = (lat == 0 && lon == 0) ? 52.3676 : lat
        let effectiveLon = (lat == 0 && lon == 0) ? 4.9041 : lon

        let weather = await NoorWidgetShared.fetchWeather(
            latitude: effectiveLat, longitude: effectiveLon)
        let prayers = NoorWidgetShared.prayerTimes(
            for: .now, latitude: effectiveLat, longitude: effectiveLon)

        let cal = Calendar.current
        let nowNoSeconds =
            cal.date(
                bySetting: .second, value: 0,
                of: cal.date(bySetting: .nanosecond, value: 0, of: .now) ?? .now)
            ?? .now

        let entries: [NoorMediumWidgetEntry] = (0..<60).map { minute in
            let entryDate =
                cal.date(byAdding: .minute, value: minute, to: nowNoSeconds) ?? nowNoSeconds
            return NoorMediumWidgetEntry(
                date: entryDate,
                configuration: configuration,
                weather: weather,
                prayerTimes: prayers
            )
        }

        let reload =
            cal.date(byAdding: .minute, value: 60, to: nowNoSeconds)
            ?? nowNoSeconds.addingTimeInterval(3600)
        return Timeline(entries: entries, policy: .after(reload))
    }

    private func makeEntry(configuration: NoorMediumWidgetIntent) async -> NoorMediumWidgetEntry {
        let defaults = NoorWidgetShared.defaults
        let lat = defaults.double(forKey: "noor.lastLatitude")
        let lon = defaults.double(forKey: "noor.lastLongitude")
        let effectiveLat = (lat == 0 && lon == 0) ? 52.3676 : lat
        let effectiveLon = (lat == 0 && lon == 0) ? 4.9041 : lon

        let weather = await NoorWidgetShared.fetchWeather(
            latitude: effectiveLat, longitude: effectiveLon)
        let prayers = NoorWidgetShared.prayerTimes(
            for: .now, latitude: effectiveLat, longitude: effectiveLon)

        return NoorMediumWidgetEntry(
            date: .now, configuration: configuration, weather: weather, prayerTimes: prayers)
    }
}

// ─────────────────────────────────────────────────────────────────
// MARK: - OpenMeteoResponse / WeatherSnapshot
// ─────────────────────────────────────────────────────────────────

struct OpenMeteoResponse: Decodable {
    struct Current: Decodable {
        let temperature_2m: Double
        let weathercode: Int
    }
    struct Daily: Decodable {
        let temperature_2m_max: [Double]?
        let temperature_2m_min: [Double]?
    }
    let current: Current?
    let daily: Daily?
}

struct WeatherSnapshot {
    let symbol: String
    let label: String
    let tempC: Double
    let highC: Double?
    let lowC: Double?
}

// ─────────────────────────────────────────────────────────────────
// MARK: - Klokwijzer helpers (gebruikt entry.date — GEEN TimelineView)
//
//  ⚠️  TimelineView(.animation) werkt NIET in Widget extensions.
//      De oplossing: de provider bouwt 1-seconde entries aan.
//      Elke render-doorgang leest entry.date en berekent de hoeken.
//      Zo bewegen de wijzers per seconde zonder extra animatie-code.
// ─────────────────────────────────────────────────────────────────

private func clockAngles(from date: Date) -> (hour: Double, minute: Double, second: Double) {
    let c = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
    let h = Double(c.hour ?? 0)
    let m = Double(c.minute ?? 0)
    let s = Double(c.second ?? 0)
    let preciseMin = m + s / 60.0
    let preciseHour = (h.truncatingRemainder(dividingBy: 12)) + preciseMin / 60.0
    return (preciseHour / 12.0 * 360.0, preciseMin / 60.0 * 360.0, s / 60.0 * 360.0)
}

private struct WidgetHand: View {
    let length: CGFloat
    let width: CGFloat
    let color: Color
    let angleDeg: Double

    var body: some View {
        Capsule()
            .fill(color)
            .frame(width: width, height: length)
            .offset(y: -length / 2)
            .rotationEffect(.degrees(angleDeg))
    }
}

// ─────────────────────────────────────────────────────────────────
// MARK: - NoorLargeWidgetView
// ─────────────────────────────────────────────────────────────────

struct NoorLargeWidgetView: View {
    let entry: NoorLargeWidgetEntry

    private var cfg: NoorLargeWidgetIntent { entry.configuration }
    private var lang: WidgetLanguage { cfg.language }
    private var digits: WidgetDigits { cfg.digits }
    private var resolvedLang: WidgetLanguage { NoorWidgetShared.resolvedLanguage(lang) }
    private var isArabic: Bool { resolvedLang == .arabic }

    var body: some View {
        ZStack {
            switch cfg.face {
            case .clock: largeClockBody
            case .date: largeDateBody
            case .todayDate: LargeTodayDateBody(entry: entry)
            case .dualCalendar: LargeDualCalendarBody(entry: entry)
            case .monthGrid: LargeMonthGridBody(entry: entry)
            case .islamicDate: LargeIslamicDateBody(entry: entry)
            case .weather: largeWeatherBody
            case .currentWeather: LargeCurrentWeatherBody(entry: entry)
            case .compactWeather: LargeCompactWeatherBody(entry: entry)
            case .prayerTimes: LargePrayerTimesBody(entry: entry)
            case .nextPrayer: LargeNextPrayerBody(entry: entry)
            case .prayerTimeline: LargePrayerTimelineBody(entry: entry)
            case .prayerProgress: LargePrayerProgressBody(entry: entry)
            case .qiblaCompass: LargeQiblaCompassBody(entry: entry)
            case .weekPulse: LargeWeekPulseBody(entry: entry)
            case .monthProgress: LargeMonthProgressBody(entry: entry)
            case .yearJourney: LargeYearJourneyBody(entry: entry)
            case .tripleOrbit: LargeTripleOrbitBody(entry: entry)
            case .luminousDigital: LargeLuminousDigitalBody(entry: entry)
            case .calendarDuo: LargeCalendarDuoBody(entry: entry)
            case .minimalClock: LargeMinimalClockBody(entry: entry)
            case .dualLineTime: LargeDualLineTimeBody(entry: entry)
            case .gregorian: LargeGregorianBody(entry: entry)
            case .hijri: LargeHijriBody(entry: entry)
            case .thuluthSmall: LargeThuluthSmallBody(entry: entry)
            case .thuluthMedium: LargeThuluthMediumBody(entry: entry)
            case .thuluthLarge: LargeThuluthLargeBody(entry: entry)
            case .monthPosterEnglish: LargeMonthPosterEnglishBody(entry: entry)
            case .monthPosterArabic: LargeMonthPosterArabicBody(entry: entry)
            }
        }
        .containerBackground(for: .widget) {
            NoorWidgetShared.widgetBackground(for: cfg.background)
        }
    }

    private var largeClockBody: some View {
        VStack(spacing: 10) {
            Text(NoorWidgetShared.formatTime(entry.date, language: lang, digits: digits))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(
                NoorWidgetShared.formatDate(
                    entry.date, language: lang, digits: digits,
                    calendar: cfg.calendar, format: cfg.dateFormat)
            )
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.75))
        }
        .padding(20)
    }

    private var largeDateBody: some View {
        VStack(spacing: 12) {
            Text(
                NoorWidgetShared.formatDate(
                    entry.date, language: lang, digits: digits,
                    calendar: cfg.calendar, format: cfg.dateFormat)
            )
            .font(.system(size: 22, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineLimit(2)
        }
        .padding(16)
    }

    private var largeWeatherBody: some View {
        VStack(spacing: 8) {
            if let weather = entry.weather {
                Image(systemName: weather.symbol)
                    .font(.system(size: 40, weight: .regular))
                    .foregroundStyle(.white)
                let temperatureText = "\(Int(weather.tempC.rounded()))"
                Text(
                    (NoorWidgetShared.resolvedDigits(digits, language: lang) == .arabic
                        ? NoorWidgetShared.toArabicDigits(temperatureText) : temperatureText) + "°"
                )
                .font(.system(size: 52, weight: .heavy, design: .rounded))
                .foregroundStyle(.yellow)
                Text(isArabic ? localizedConditionArabic(weather.label) : weather.label)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            } else {
                Text("--")
                    .font(.system(size: 52, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .padding(16)
    }

    private func localizedConditionArabic(_ english: String) -> String {
        switch english {
        case "Clear": return "صحو"
        case "Partly Cloudy": return "غائم جزئياً"
        case "Fog": return "ضباب"
        case "Drizzle": return "رذاذ"
        case "Rain": return "مطر"
        case "Snow": return "ثلج"
        case "Showers": return "زخات"
        case "Thunder": return "عاصفة"
        default: return english
        }
    }
}

// ─────────────────────────────────────────────────────────────────
// MARK: - Large sub-views (ongewijzigd t.o.v. origineel)
// ─────────────────────────────────────────────────────────────────

private struct LargeTodayDateBody: View {
    let entry: NoorLargeWidgetEntry
    private var lang: WidgetLanguage { entry.configuration.language }
    private var digits: WidgetDigits { entry.configuration.digits }

    var body: some View {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: entry.date)
        VStack(spacing: 20) {
            Text(NoorWidgetShared.weekdayNameFull(entry.date, language: lang).uppercased())
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
            Text(
                NoorWidgetShared.resolvedDigits(digits, language: lang) == .arabic
                    ? NoorWidgetShared.toArabicDigits("\(day)") : "\(day)"
            )
            .font(.system(size: 110, weight: .heavy, design: .rounded))
            .foregroundStyle(.yellow)
            Text(NoorWidgetShared.monthName(entry.date, language: lang).uppercased())
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(NoorWidgetShared.yearNumber(entry.date, digits: digits, language: lang))
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 32)
    }
}

private struct LargeDualCalendarBody: View {
    let entry: NoorLargeWidgetEntry
    private var lang: WidgetLanguage { entry.configuration.language }
    private var digits: WidgetDigits { entry.configuration.digits }

    var body: some View {
        HStack(spacing: 20) {
            VStack(spacing: 12) {
                Text("GREGORIAN")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                Text(NoorWidgetShared.dayNumber(entry.date, digits: digits, language: lang))
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(.yellow)
                Text(NoorWidgetShared.shortMonth(entry.date, language: lang).uppercased())
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(NoorWidgetShared.yearNumber(entry.date, digits: digits, language: lang))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 28)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(spacing: 12) {
                Text("HIJRI")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                let hijri = Calendar(identifier: .islamicUmmAlQura)
                let comps = hijri.dateComponents([.day, .month, .year], from: entry.date)
                let dayStr =
                    NoorWidgetShared.resolvedDigits(digits, language: lang) == .arabic
                    ? NoorWidgetShared.toArabicDigits(String(comps.day ?? 0))
                    : String(comps.day ?? 0)
                Text(dayStr)
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(NoorWidgetShared.hijriMonthName(entry.date, language: lang))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(NoorWidgetShared.hijriYearNumber(entry.date, digits: digits, language: lang))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 28)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(16)
    }
}

private struct LargeMonthGridBody: View {
    let entry: NoorLargeWidgetEntry
    private var lang: WidgetLanguage { entry.configuration.language }
    private var digits: WidgetDigits { entry.configuration.digits }

    var body: some View {
        let calendar = Calendar.current
        let currentDay = calendar.component(.day, from: entry.date)
        let daysInMonth = calendar.range(of: .day, in: .month, for: entry.date)?.count ?? 30
        let columns = 7
        let rows = Int(ceil(Double(daysInMonth) / Double(columns)))

        VStack(spacing: 16) {
            HStack {
                Text(NoorWidgetShared.monthName(entry.date, language: lang).uppercased())
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Text(NoorWidgetShared.yearNumber(entry.date, digits: digits, language: lang))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
            VStack(spacing: 8) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 6) {
                        ForEach(0..<columns, id: \.self) { col in
                            let dayNum = row * columns + col + 1
                            if dayNum <= daysInMonth {
                                let isToday = dayNum == currentDay
                                let dayStr =
                                    NoorWidgetShared.resolvedDigits(digits, language: lang)
                                        == .arabic
                                    ? NoorWidgetShared.toArabicDigits("\(dayNum)") : "\(dayNum)"
                                Text(dayStr)
                                    .font(
                                        .system(
                                            size: isToday ? 15 : 13,
                                            weight: isToday ? .bold : .medium, design: .rounded)
                                    )
                                    .foregroundStyle(isToday ? .black : .white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 36)
                                    .background(isToday ? Color.yellow : Color.white.opacity(0.06))
                                    .clipShape(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous))
                            } else {
                                Color.clear.frame(maxWidth: .infinity).frame(height: 36)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(16)
    }
}

private struct LargeIslamicDateBody: View {
    let entry: NoorLargeWidgetEntry
    private var lang: WidgetLanguage { entry.configuration.language }
    private var digits: WidgetDigits { entry.configuration.digits }

    var body: some View {
        let hijri = Calendar(identifier: .islamicUmmAlQura)
        let comps = hijri.dateComponents([.day, .month, .year], from: entry.date)
        let dayStr =
            NoorWidgetShared.resolvedDigits(digits, language: lang) == .arabic
            ? NoorWidgetShared.toArabicDigits(String(comps.day ?? 0))
            : String(comps.day ?? 0)

        VStack(spacing: 20) {
            Text("التقويم الهجري")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
            Text(dayStr)
                .font(.system(size: 100, weight: .heavy, design: .rounded))
                .foregroundStyle(.yellow)
            Text(NoorWidgetShared.hijriMonthName(entry.date, language: lang))
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(
                NoorWidgetShared.hijriYearNumber(entry.date, digits: digits, language: lang) + " هـ"
            )
            .font(.system(size: 20, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 32)
    }
}

private struct LargeCurrentWeatherBody: View {
    let entry: NoorLargeWidgetEntry
    private var lang: WidgetLanguage { entry.configuration.language }
    private var digits: WidgetDigits { entry.configuration.digits }
    private var locationName: String {
        NoorWidgetShared.defaults.string(forKey: "noor.lastLocationName") ?? "—"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(locationName)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                if let weather = entry.weather {
                    Image(systemName: weather.symbol)
                        .font(.system(size: 32, weight: .regular))
                        .foregroundStyle(.white)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                if let weather = entry.weather {
                    let tempText = "\(Int(weather.tempC.rounded()))"
                    Text(
                        (NoorWidgetShared.resolvedDigits(digits, language: lang) == .arabic
                            ? NoorWidgetShared.toArabicDigits(tempText) : tempText) + "°"
                    )
                    .font(.system(size: 72, weight: .heavy, design: .rounded))
                    .foregroundStyle(.yellow)
                } else {
                    Text("--").font(.system(size: 72, weight: .heavy, design: .rounded))
                        .foregroundStyle(.yellow)
                }
                Spacer()
                if let weather = entry.weather, let high = weather.highC, let low = weather.lowC {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("H: \(Int(high.rounded()))°")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.75))
                        Text("L: \(Int(low.rounded()))°")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
            }
            Spacer()
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.date, style: .time)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(
                        NoorWidgetShared.formatDate(
                            entry.date, language: lang, digits: digits,
                            calendar: entry.configuration.calendar,
                            format: entry.configuration.dateFormat)
                    )
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                Text("Updated now")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(20)
    }
}

private struct LargeCompactWeatherBody: View {
    let entry: NoorLargeWidgetEntry
    private var lang: WidgetLanguage { entry.configuration.language }
    private var digits: WidgetDigits { entry.configuration.digits }
    private var locationName: String {
        NoorWidgetShared.defaults.string(forKey: "noor.lastLocationName") ?? "—"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if let weather = entry.weather {
                    Image(systemName: weather.symbol)
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(.white.opacity(0.85))
                }
                Text(locationName)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer()
            if let weather = entry.weather {
                let tempText = "\(Int(weather.tempC.rounded()))"
                let displayTemp =
                    NoorWidgetShared.resolvedDigits(digits, language: lang) == .arabic
                    ? NoorWidgetShared.toArabicDigits(tempText) : tempText
                Text(displayTemp + "°")
                    .font(.system(size: 80, weight: .heavy, design: .rounded))
                    .foregroundStyle(.yellow)
                Text(weather.label)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                if let high = weather.highC, let low = weather.lowC {
                    Text("H:\(Int(high.rounded()))°  L:\(Int(low.rounded()))°")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                        .padding(.top, 4)
                }
            } else {
                Text("--")
                    .font(.system(size: 80, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(20)
    }
}

private struct LargePrayerTimesBody: View {
    let entry: NoorLargeWidgetEntry
    private var lang: WidgetLanguage { entry.configuration.language }
    private var isArabic: Bool { NoorWidgetShared.resolvedLanguage(lang) == .arabic }

    private func arabicName(_ english: String) -> String {
        switch english {
        case "Fajr": return "الفجر"
        case "Sunrise": return "الشروق"
        case "Dhuhr": return "الظهر"
        case "Asr": return "العصر"
        case "Maghrib": return "المغرب"
        case "Isha": return "العشاء"
        default: return english
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(isArabic ? "مواقيت الصلاة" : "Prayer Times")
                    .font(ArabicTypography.dayFont(size: 14, language: lang, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Text(entry.date, format: Date.FormatStyle().day().month(.abbreviated))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
            if entry.prayerTimes.isEmpty {
                Spacer()
                Text(isArabic ? "يلزم تحديد الموقع" : "Location needed")
                    .font(ArabicTypography.dayFont(size: 14, language: lang, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(entry.prayerTimes.enumerated()), id: \.offset) { _, prayer in
                        let isPast = prayer.1 <= entry.date
                        HStack {
                            if isArabic {
                                Text(arabicName(prayer.0))
                                    .font(
                                        ArabicTypography.dayFont(
                                            size: 20, language: lang, weight: .semibold)
                                    )
                                    .foregroundStyle(.yellow)
                                    .frame(width: 80, alignment: .trailing)
                            }
                            Text(prayer.0.uppercased())
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(isPast ? .white.opacity(0.5) : .white.opacity(0.8))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(prayer.1, style: .time)
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundStyle(isPast ? .white.opacity(0.5) : .white)
                            if isPast {
                                Text("✓").font(.system(size: 14, weight: .bold)).foregroundStyle(
                                    .yellow.opacity(0.6))
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(16)
    }
}

private struct LargeNextPrayerBody: View {
    let entry: NoorLargeWidgetEntry
    private var lang: WidgetLanguage { entry.configuration.language }
    private var isArabic: Bool { NoorWidgetShared.resolvedLanguage(lang) == .arabic }

    private func arabicName(_ english: String) -> String {
        switch english {
        case "Fajr": return "الفجر"
        case "Sunrise": return "الشروق"
        case "Dhuhr": return "الظهر"
        case "Asr": return "العصر"
        case "Maghrib": return "المغرب"
        case "Isha": return "العشاء"
        default: return english
        }
    }

    private var nextPrayer: (String, Date)? { entry.prayerTimes.first { $0.1 > entry.date } }

    var body: some View {
        VStack(spacing: 24) {
            Text(isArabic ? "الصلاة القادمة" : "Next Prayer")
                .font(ArabicTypography.dayFont(size: 14, language: lang, weight: .bold))
                .foregroundStyle(.white.opacity(0.6))
            if let next = nextPrayer {
                Text(isArabic ? arabicName(next.0) : next.0)
                    .font(ArabicTypography.dayFont(size: 44, language: lang, weight: .bold))
                    .foregroundStyle(.yellow)
                Text(next.0.uppercased())
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(next.1, style: .time)
                    .font(.system(size: 64, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white)
                VStack(alignment: .center, spacing: 6) {
                    Text(isArabic ? "بعد" : "in")
                        .font(ArabicTypography.dayFont(size: 14, language: lang, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        Text(next.1, style: .timer)
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.yellow)
                            .multilineTextAlignment(.center)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 22).padding(.vertical, 12)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                Text(isArabic ? "يلزم تحديد الموقع" : "Location needed")
                    .font(ArabicTypography.dayFont(size: 14, language: lang, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 32)
    }
}

private struct LargePrayerTimelineBody: View {
    let entry: NoorLargeWidgetEntry
    private var lang: WidgetLanguage { entry.configuration.language }
    private var isArabic: Bool { NoorWidgetShared.resolvedLanguage(lang) == .arabic }
    private var visiblePrayers: [(String, Date)] { entry.prayerTimes.filter { $0.0 != "Sunrise" } }

    private func arabicName(_ english: String) -> String {
        switch english {
        case "Fajr": return "الفجر"
        case "Dhuhr": return "الظهر"
        case "Asr": return "العصر"
        case "Maghrib": return "المغرب"
        case "Isha": return "العشاء"
        default: return english
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(isArabic ? "الجدول" : "Timeline")
                .font(ArabicTypography.dayFont(size: 16, language: lang, weight: .bold))
                .foregroundStyle(.white.opacity(0.6))
            VStack(spacing: 0) {
                ForEach(Array(visiblePrayers.enumerated()), id: \.offset) { index, prayer in
                    let isPast = prayer.1 <= entry.date
                    HStack(spacing: 18) {
                        Text(prayer.1, style: .time)
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundStyle(isPast ? .white.opacity(0.5) : .white)
                            .frame(width: 80, alignment: .trailing)
                        VStack(spacing: 0) {
                            Circle()
                                .fill(isPast ? Color.yellow.opacity(0.5) : Color.yellow)
                                .frame(width: isPast ? 12 : 16, height: isPast ? 12 : 16)
                            if index < visiblePrayers.count - 1 {
                                Rectangle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: 2, height: 48)
                            }
                        }
                        Text(isArabic ? arabicName(prayer.0) : prayer.0.uppercased())
                            .font(ArabicTypography.dayFont(size: 20, language: lang, weight: .bold))
                            .foregroundStyle(isPast ? .white.opacity(0.5) : .white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if isPast {
                            Text("✓").font(.system(size: 16, weight: .bold)).foregroundStyle(
                                .yellow.opacity(0.6))
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(20)
    }
}

private struct LargePrayerProgressBody: View {
    let entry: NoorLargeWidgetEntry
    private var lang: WidgetLanguage { entry.configuration.language }
    private var isArabic: Bool { NoorWidgetShared.resolvedLanguage(lang) == .arabic }
    private var obligatoryPrayers: [(String, Date)] {
        entry.prayerTimes.filter { $0.0 != "Sunrise" }
    }
    private var completedCount: Int { obligatoryPrayers.filter { $0.1 <= entry.date }.count }
    private var progress: Double {
        guard obligatoryPrayers.count > 0 else { return 0 }
        return Double(completedCount) / Double(obligatoryPrayers.count)
    }
    private var nextPrayer: (String, Date)? { entry.prayerTimes.first { $0.1 > entry.date } }

    private func arabicName(_ english: String) -> String {
        switch english {
        case "Fajr": return "الفجر"
        case "Dhuhr": return "الظهر"
        case "Asr": return "العصر"
        case "Maghrib": return "المغرب"
        case "Isha": return "العشاء"
        default: return english
        }
    }

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.08), lineWidth: 18).padding(24)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.yellow, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(24)
            VStack(spacing: 6) {
                Text("\(completedCount)/5")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(isArabic ? "صلوات" : "Prayers")
                    .font(ArabicTypography.dayFont(size: 14, language: lang, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                if let next = nextPrayer {
                    Text(isArabic ? arabicName(next.0) : next.0)
                        .font(ArabicTypography.dayFont(size: 18, language: lang, weight: .bold))
                        .foregroundStyle(.yellow)
                        .padding(.top, 4)
                } else {
                    Text("الحمد لله")
                        .font(ArabicTypography.dayFont(size: 16, language: lang, weight: .semibold))
                        .foregroundStyle(.yellow.opacity(0.8))
                        .padding(.top, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
    }
}

private struct LargeQiblaCompassBody: View {
    let entry: NoorLargeWidgetEntry
    private var qiblaDir: Double? {
        let lat = NoorWidgetShared.defaults.double(forKey: "noor.lastLatitude")
        let lon = NoorWidgetShared.defaults.double(forKey: "noor.lastLongitude")
        guard lat != 0 || lon != 0 else { return nil }
        return NoorWidgetShared.qiblaDirection(latitude: lat, longitude: lon)
    }

    var body: some View {
        if let dir = qiblaDir {
            ZStack {
                ForEach(0..<24) { i in
                    let isMajor = i % 6 == 0
                    let isNorth = i == 0
                    Capsule()
                        .fill(isNorth ? Color.yellow : Color.white.opacity(isMajor ? 0.6 : 0.25))
                        .frame(width: isMajor ? 3 : 1.5, height: isMajor ? 16 : 9)
                        .offset(y: -130)
                        .rotationEffect(.degrees(Double(i) * 15))
                }
                Text("N")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.yellow)
                    .offset(y: -108)
                VStack(spacing: 0) {
                    Image(systemName: "arrowtriangle.up.fill")
                        .font(.system(size: 36, weight: .regular))
                        .foregroundStyle(.yellow)
                        .shadow(color: .yellow.opacity(0.6), radius: 10)
                    Circle().fill(Color.yellow).frame(width: 10, height: 10)
                }
                .rotationEffect(.degrees(dir))
                VStack(spacing: 4) {
                    Spacer()
                    Text("\(Int(dir.rounded()))°")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("QIBLA")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .tracking(2)
                }
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 10) {
                Image(systemName: "location.slash").font(.system(size: 36)).foregroundStyle(
                    .white.opacity(0.4))
                Text("Set Location").font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5)).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct LargeWeekPulseBody: View {
    let entry: NoorLargeWidgetEntry
    private var lang: WidgetLanguage { entry.configuration.language }
    private var isArabic: Bool { NoorWidgetShared.resolvedLanguage(lang) == .arabic }

    var body: some View {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: entry.date)
        let adjustedDay = weekday == 1 ? 7 : weekday - 1

        VStack(spacing: 28) {
            Text(isArabic ? "نبض الأسبوع" : "Week Pulse")
                .font(ArabicTypography.dayFont(size: 18, language: lang, weight: .bold))
                .foregroundStyle(.white.opacity(0.6))
            HStack(spacing: 18) {
                ForEach(1...7, id: \.self) { day in
                    let isToday = day == adjustedDay
                    Circle()
                        .fill(isToday ? Color.yellow : Color.white.opacity(0.15))
                        .frame(width: isToday ? 28 : 18, height: isToday ? 28 : 18)
                        .overlay(
                            Circle().stroke(Color.white.opacity(isToday ? 0.4 : 0.1), lineWidth: 2)
                                .scaleEffect(isToday ? 1.4 : 1.0))
                }
            }
            Text(NoorWidgetShared.weekdayNameFull(entry.date, language: lang))
                .font(ArabicTypography.dayFont(size: 26, language: lang, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }
}

private struct LargeMonthProgressBody: View {
    let entry: NoorLargeWidgetEntry
    private var lang: WidgetLanguage { entry.configuration.language }
    private var digits: WidgetDigits { entry.configuration.digits }
    private var isArabic: Bool { NoorWidgetShared.resolvedLanguage(lang) == .arabic }

    var body: some View {
        let calendar = Calendar.current
        let dayOfMonth = calendar.component(.day, from: entry.date)
        let daysInMonth = calendar.range(of: .day, in: .month, for: entry.date)?.count ?? 30
        let columns = 10
        let rows = Int(ceil(Double(daysInMonth) / Double(columns)))

        VStack(spacing: 24) {
            Text(isArabic ? "تقدم الشهر" : "Month Progress")
                .font(ArabicTypography.dayFont(size: 18, language: lang, weight: .bold))
                .foregroundStyle(.white.opacity(0.6))
            VStack(spacing: 8) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(0..<columns, id: \.self) { col in
                            let dayNum = row * columns + col + 1
                            if dayNum <= daysInMonth {
                                let isPassed = dayNum <= dayOfMonth
                                Circle()
                                    .fill(isPassed ? Color.yellow : Color.white.opacity(0.15))
                                    .frame(width: isPassed ? 14 : 10, height: isPassed ? 14 : 10)
                            } else {
                                Color.clear.frame(width: 10, height: 10)
                            }
                        }
                    }
                }
            }
            HStack {
                Text(isArabic ? "يوم" : "Day")
                    .font(ArabicTypography.dayFont(size: 18, language: lang, weight: .semibold))
                    .foregroundStyle(.white)
                Text(
                    NoorWidgetShared.resolvedDigits(digits, language: lang) == .arabic
                        ? NoorWidgetShared.toArabicDigits("\(dayOfMonth)") : "\(dayOfMonth)"
                )
                .font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(.yellow)
                Text(isArabic ? "من" : "of")
                    .font(ArabicTypography.dayFont(size: 18, language: lang, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                Text(
                    NoorWidgetShared.resolvedDigits(digits, language: lang) == .arabic
                        ? NoorWidgetShared.toArabicDigits("\(daysInMonth)") : "\(daysInMonth)"
                )
                .font(.system(size: 18, weight: .medium, design: .rounded)).foregroundStyle(
                    .white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 36)
    }
}

private struct LargeYearJourneyBody: View {
    let entry: NoorLargeWidgetEntry
    private var lang: WidgetLanguage { entry.configuration.language }
    private var digits: WidgetDigits { entry.configuration.digits }
    private var isArabic: Bool { NoorWidgetShared.resolvedLanguage(lang) == .arabic }

    var body: some View {
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: entry.date) ?? 1
        let year = calendar.component(.year, from: entry.date)
        let isLeapYear = calendar.range(of: .day, in: .year, for: entry.date)?.count == 366
        let totalDays = isLeapYear ? 366 : 365
        let currentMonth = calendar.component(.month, from: entry.date)

        VStack(spacing: 28) {
            Text(isArabic ? "رحلة السنة" : "Year Journey")
                .font(ArabicTypography.dayFont(size: 18, language: lang, weight: .bold))
                .foregroundStyle(.white.opacity(0.6))
            HStack(spacing: 14) {
                ForEach(1...12, id: \.self) { month in
                    let isPassed = month < currentMonth
                    let isCurrent = month == currentMonth
                    Circle()
                        .fill(
                            isCurrent
                                ? Color.yellow
                                : (isPassed ? Color.white.opacity(0.5) : Color.white.opacity(0.15))
                        )
                        .frame(width: isCurrent ? 22 : 13, height: isCurrent ? 22 : 13)
                        .overlay(
                            Circle().stroke(Color.yellow.opacity(isCurrent ? 0.6 : 0), lineWidth: 3)
                                .scaleEffect(isCurrent ? 1.5 : 1.0))
                }
            }
            VStack(spacing: 8) {
                Text(
                    NoorWidgetShared.resolvedDigits(digits, language: lang) == .arabic
                        ? NoorWidgetShared.toArabicDigits("\(year)") : "\(year)"
                )
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                HStack {
                    Text(isArabic ? "يوم" : "Day")
                        .font(ArabicTypography.dayFont(size: 16, language: lang, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                    Text(
                        NoorWidgetShared.resolvedDigits(digits, language: lang) == .arabic
                            ? NoorWidgetShared.toArabicDigits("\(dayOfYear)") : "\(dayOfYear)"
                    )
                    .font(.system(size: 20, weight: .semibold, design: .rounded)).foregroundStyle(
                        .yellow)
                    Text(isArabic ? "من" : "of")
                        .font(ArabicTypography.dayFont(size: 16, language: lang, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                    Text(
                        NoorWidgetShared.resolvedDigits(digits, language: lang) == .arabic
                            ? NoorWidgetShared.toArabicDigits("\(totalDays)") : "\(totalDays)"
                    )
                    .font(.system(size: 16, weight: .medium, design: .rounded)).foregroundStyle(
                        .white.opacity(0.6))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }
}

private struct LargeTripleOrbitBody: View {
    let entry: NoorLargeWidgetEntry
    private var isArabic: Bool {
        NoorWidgetShared.resolvedLanguage(entry.configuration.language) == .arabic
    }

    var body: some View {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: entry.date)
        let adjustedDay = weekday == 1 ? 7 : weekday - 1
        let weekProgress = Double(adjustedDay) / 7.0
        let dayOfMonth = calendar.component(.day, from: entry.date)
        let daysInMonth = Double(calendar.range(of: .day, in: .month, for: entry.date)?.count ?? 30)
        let monthProgress = Double(dayOfMonth) / daysInMonth
        let dayOfYear = Double(calendar.ordinality(of: .day, in: .year, for: entry.date) ?? 1)
        let totalDays = Double(calendar.range(of: .day, in: .year, for: entry.date)?.count ?? 365)
        let yearProgress = dayOfYear / totalDays
        let orbitSize: CGFloat = 290

        ZStack {
            Circle().fill(.black.opacity(0.9)).overlay(
                Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
            Circle().stroke(Color.white.opacity(0.1), lineWidth: 2).padding(10)
            Circle().fill(Color.white.opacity(0.8)).frame(width: 10, height: 10)
                .offset(y: -(orbitSize / 2 - 10 - 5))
                .rotationEffect(.degrees(yearProgress * 360 - 90))
            Circle().stroke(Color.white.opacity(0.15), lineWidth: 2).padding(50)
            Circle().fill(Color.white).frame(width: 12, height: 12)
                .offset(y: -(orbitSize / 2 - 50 - 6))
                .rotationEffect(.degrees(monthProgress * 360 - 90))
            Circle().stroke(Color.yellow.opacity(0.3), lineWidth: 2).padding(95)
            Circle().fill(Color.yellow).frame(width: 15, height: 15)
                .offset(y: -(orbitSize / 2 - 95 - 8))
                .rotationEffect(.degrees(weekProgress * 360 - 90))
                .shadow(color: .yellow.opacity(0.6), radius: 8)
            VStack(spacing: 6) {
                Text(isArabic ? "المدارات" : "Orbits")
                    .font(
                        ArabicTypography.dayFont(
                            size: 12, language: entry.configuration.language, weight: .bold)
                    )
                    .foregroundStyle(.white.opacity(0.5))
                Text("W • M • Y")
                    .font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(
                        .yellow)
            }
        }
        .frame(width: orbitSize, height: orbitSize)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct LargeLuminousDigitalBody: View {
    let entry: NoorLargeWidgetEntry
    private var lang: WidgetLanguage { entry.configuration.language }
    private var digits: WidgetDigits { entry.configuration.digits }
    private var isArabic: Bool { NoorWidgetShared.resolvedLanguage(lang) == .arabic }

    var body: some View {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: entry.date)
        let hour = comps.hour ?? 0
        let minute = comps.minute ?? 0
        let hourStr =
            NoorWidgetShared.resolvedDigits(digits, language: lang) == .arabic
            ? NoorWidgetShared.toArabicDigits(String(format: "%02d", hour))
            : String(format: "%02d", hour)
        let minuteStr =
            NoorWidgetShared.resolvedDigits(digits, language: lang) == .arabic
            ? NoorWidgetShared.toArabicDigits(String(format: "%02d", minute))
            : String(format: "%02d", minute)

        return VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: -2) {
                Text(hourStr).font(.system(size: 100, weight: .heavy, design: .rounded))
                    .foregroundStyle(.yellow)
                Text(minuteStr).font(.system(size: 88, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            Text(isArabic ? "رقمي مضيء" : "Luminous Digital")
                .font(ArabicTypography.dayFont(size: 14, language: lang, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(20)
    }
}

private struct LargeCalendarDuoBody: View {
    let entry: NoorLargeWidgetEntry
    private var lang: WidgetLanguage { entry.configuration.language }
    private var digits: WidgetDigits { entry.configuration.digits }

    var body: some View {
        let month = NoorWidgetShared.monthName(entry.date, language: lang).uppercased()
        let weekday = NoorWidgetShared.weekdayNameFull(entry.date, language: lang).uppercased()
        let day = NoorWidgetShared.dayNumber(entry.date, digits: digits, language: lang)
        let shortMonth = NoorWidgetShared.shortMonth(entry.date, language: lang).uppercased()

        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 16) {
                Text(month).font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                LargeCapsuleLabel(
                    text: weekday, color: .white.opacity(0.10), textColor: .white, language: lang)
            }
            Spacer()
            VStack(spacing: 16) {
                LargeCapsuleLabel(
                    text: shortMonth, color: .yellow, textColor: .black, language: lang)
                LargeCapsuleLabel(
                    text: day, color: .white.opacity(0.10), textColor: .white, language: lang)
            }
        }
        .padding(24)
    }
}

private struct LargeCapsuleLabel: View {
    let text: String
    let color: Color
    let textColor: Color
    let language: WidgetLanguage

    var body: some View {
        Text(text)
            .font(ArabicTypography.dayFont(size: 18, language: language, weight: .bold))
            .foregroundStyle(textColor)
            .padding(.horizontal, 20).padding(.vertical, 12)
            .background(color).clipShape(Capsule())
    }
}

private struct LargeMinimalClockBody: View {
    let entry: NoorLargeWidgetEntry

    var body: some View {
        let formatter = DateFormatter()
        let _ = {
            formatter.dateFormat = "hh:mm a"
            formatter.locale = Locale.current
        }()
        return Text(formatter.string(from: entry.date))
            .font(.system(size: 56, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(24)
    }
}

private struct LargeDualLineTimeBody: View {
    let entry: NoorLargeWidgetEntry
    private var lang: WidgetLanguage { entry.configuration.language }
    private var digits: WidgetDigits { entry.configuration.digits }
    private var isArabic: Bool { NoorWidgetShared.resolvedLanguage(lang) == .arabic }

    var body: some View {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: entry.date)
        let hour = comps.hour ?? 0
        let minute = comps.minute ?? 0
        let timeStr =
            NoorWidgetShared.resolvedDigits(digits, language: lang) == .arabic
            ? NoorWidgetShared.toArabicDigits(String(format: "%02d:%02d", hour, minute))
            : String(format: "%02d:%02d", hour, minute)

        return VStack(alignment: .leading, spacing: 12) {
            Text(timeStr)
                .font(.system(size: 72, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .overlay(alignment: .bottomLeading) {
                    Rectangle().fill(Color.yellow).frame(height: 8).offset(y: 14)
                }
            Text(isArabic ? "وقت ثنائي" : "Dual Line Time")
                .font(ArabicTypography.dayFont(size: 16, language: lang, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(24)
    }
}

private struct LargeGregorianBody: View {
    let entry: NoorLargeWidgetEntry
    private var lang: WidgetLanguage { entry.configuration.language }
    private var digits: WidgetDigits { entry.configuration.digits }

    var body: some View {
        HStack(spacing: 20) {
            LargeRoundedRectInfo(
                title: NoorWidgetShared.shortMonth(entry.date, language: lang).uppercased(),
                value: NoorWidgetShared.dayNumber(entry.date, digits: digits, language: lang),
                accent: .yellow, textColor: .black)
            LargeRoundedRectInfo(
                title: NoorWidgetShared.weekdayNameFull(entry.date, language: lang).uppercased(),
                value: NoorWidgetShared.yearNumber(entry.date, digits: digits, language: lang),
                accent: .white.opacity(0.10), textColor: .white)
        }
        .padding(20)
    }
}

private struct LargeHijriBody: View {
    let entry: NoorLargeWidgetEntry
    private var lang: WidgetLanguage { entry.configuration.language }
    private var digits: WidgetDigits { entry.configuration.digits }

    var body: some View {
        let hijri = Calendar(identifier: .islamicUmmAlQura)
        let comps = hijri.dateComponents([.day, .month, .year], from: entry.date)
        let dayStr =
            NoorWidgetShared.resolvedDigits(digits, language: lang) == .arabic
            ? NoorWidgetShared.toArabicDigits(String(comps.day ?? 0))
            : String(comps.day ?? 0)

        return HStack(spacing: 20) {
            LargeRoundedRectInfo(
                title: NoorWidgetShared.hijriMonthName(entry.date, language: lang), value: dayStr,
                accent: .white.opacity(0.10), textColor: .white)
            LargeRoundedRectInfo(
                title: "Hijri",
                value: NoorWidgetShared.hijriYearNumber(entry.date, digits: digits, language: lang),
                accent: .yellow, textColor: .black)
        }
        .padding(20)
    }
}

private struct LargeRoundedRectInfo: View {
    let title: String
    let value: String
    var accent: Color = .yellow
    var textColor: Color = .black

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(textColor == .black ? .black.opacity(0.7) : textColor.opacity(0.7))
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(value)
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(textColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 28)
        .background(accent)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct LargeThuluthSmallBody: View {
    let entry: NoorLargeWidgetEntry
    private var lang: WidgetLanguage { entry.configuration.language }
    private var digits: WidgetDigits { entry.configuration.digits }

    var body: some View {
        let hijri = Calendar(identifier: .islamicUmmAlQura)
        let hComps = hijri.dateComponents([.day, .month, .year], from: entry.date)
        let dayStr =
            NoorWidgetShared.resolvedDigits(digits, language: lang) == .arabic
            ? NoorWidgetShared.toArabicDigits(String(hComps.day ?? 0))
            : String(hComps.day ?? 0)

        VStack(spacing: 10) {
            Text(NoorWidgetShared.dayNumber(entry.date, digits: digits, language: lang))
                .font(.custom("DecoType Thuluth", size: 100)).foregroundStyle(.yellow).shadow(
                    color: Color.yellow.opacity(0.3), radius: 8)
            Text(NoorWidgetShared.shortMonth(entry.date, language: lang).uppercased())
                .font(.custom("DecoType Thuluth", size: 28)).foregroundStyle(.white)
            Text(dayStr + " " + NoorWidgetShared.hijriMonthName(entry.date, language: lang))
                .font(.custom("DecoType Thuluth", size: 22)).foregroundStyle(.white.opacity(0.7))
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(20)
    }
}

private struct LargeThuluthMediumBody: View {
    let entry: NoorLargeWidgetEntry
    private var lang: WidgetLanguage { entry.configuration.language }
    private var digits: WidgetDigits { entry.configuration.digits }

    var body: some View {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: entry.date)
        let hour = comps.hour ?? 0
        let minute = comps.minute ?? 0
        let hourStr =
            NoorWidgetShared.resolvedDigits(digits, language: lang) == .arabic
            ? NoorWidgetShared.toArabicDigits(String(format: "%02d", hour))
            : String(format: "%02d", hour)
        let minuteStr =
            NoorWidgetShared.resolvedDigits(digits, language: lang) == .arabic
            ? NoorWidgetShared.toArabicDigits(String(format: "%02d", minute))
            : String(format: "%02d", minute)

        return VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(hourStr).font(.custom("DecoType Thuluth", size: 80)).foregroundStyle(.white)
                Text(":").font(.system(size: 64, weight: .thin)).foregroundStyle(.yellow).offset(
                    y: -4)
                Text(minuteStr).font(.custom("DecoType Thuluth", size: 80)).foregroundStyle(.yellow)
            }
            Text(
                NoorWidgetShared.weekdayNameFull(entry.date, language: lang) + " · "
                    + NoorWidgetShared.dayNumber(entry.date, digits: digits, language: lang) + " "
                    + NoorWidgetShared.monthName(entry.date, language: lang)
            )
            .font(.custom("DecoType Thuluth", size: 28)).foregroundStyle(.white.opacity(0.7))
            .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center).padding(20)
    }
}

private struct LargeThuluthLargeBody: View {
    let entry: NoorLargeWidgetEntry
    private var lang: WidgetLanguage { entry.configuration.language }
    private var digits: WidgetDigits { entry.configuration.digits }

    var body: some View {
        let hijri = Calendar(identifier: .islamicUmmAlQura)
        let hComps = hijri.dateComponents([.day, .month, .year], from: entry.date)
        let dayOfYear = Double(hijri.ordinality(of: .day, in: .year, for: entry.date) ?? 1)
        let totalDays = Double(hijri.range(of: .day, in: .year, for: entry.date)?.count ?? 354)
        let progress = max(0.0, min(1.0, dayOfYear / totalDays))
        let dayStr =
            NoorWidgetShared.resolvedDigits(digits, language: lang) == .arabic
            ? NoorWidgetShared.toArabicDigits(String(hComps.day ?? 0)) : String(hComps.day ?? 0)
        let yearStr =
            NoorWidgetShared.resolvedDigits(digits, language: lang) == .arabic
            ? NoorWidgetShared.toArabicDigits(String(hComps.year ?? 0)) : String(hComps.year ?? 0)

        return ZStack {
            Circle().stroke(Color.white.opacity(0.08), lineWidth: 20).padding(16)
            Circle().trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.yellow.opacity(0.3), Color.yellow, Color.yellow.opacity(0.3),
                        ]), center: .center), style: StrokeStyle(lineWidth: 20, lineCap: .round)
                )
                .rotationEffect(.degrees(-90)).padding(16)
            VStack(spacing: 6) {
                Text(dayStr).font(.custom("DecoType Thuluth", size: 80)).foregroundStyle(.yellow)
                Text(NoorWidgetShared.hijriMonthName(entry.date, language: lang))
                    .font(.custom("DecoType Thuluth", size: 30)).foregroundStyle(.white).lineLimit(
                        1
                    ).minimumScaleFactor(0.7).padding(.horizontal, 36)
                Text(yearStr + " هـ").font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(20)
    }
}

private struct LargeMonthPosterEnglishBody: View {
    let entry: NoorLargeWidgetEntry
    private var digits: WidgetDigits { entry.configuration.digits }

    var body: some View {
        let day = NoorWidgetShared.dayNumber(entry.date, digits: digits, language: .english)
        let month = NoorWidgetShared.monthName(entry.date, language: .english).uppercased()

        return ZStack {
            Text(day)
                .font(.system(size: 160, weight: .heavy, design: .rounded))
                .foregroundStyle(.yellow.opacity(0.14))
                .offset(y: -18)
            Text(month)
                .font(.system(size: 78, weight: .bold, design: .serif))
                .foregroundStyle(.white.opacity(0.95))
                .tracking(6)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .padding(.horizontal, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 28)
    }
}

private struct LargeMonthPosterArabicBody: View {
    let entry: NoorLargeWidgetEntry
    private var digits: WidgetDigits { entry.configuration.digits }
    private var lang: WidgetLanguage { entry.configuration.language }

    var body: some View {
        let day = NoorWidgetShared.dayNumber(entry.date, digits: digits, language: lang)
        let monthArabic = NoorWidgetShared.monthName(entry.date, language: .arabic)

        return ZStack {
            Text(day)
                .font(.system(size: 160, weight: .heavy, design: .rounded))
                .foregroundStyle(.yellow.opacity(0.14))
                .offset(y: -18)
            Text(monthArabic)
                .font(ArabicTypography.dayFont(size: 96, language: lang, weight: .regular))
                .foregroundStyle(.white.opacity(0.95))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 28)
    }
}

// ─────────────────────────────────────────────────────────────────
// MARK: - NoorMediumWidgetView
// ─────────────────────────────────────────────────────────────────

struct NoorMediumWidgetView: View {
    let entry: NoorMediumWidgetEntry

    var body: some View {
        let _ = ArabicTypography.registerFontIfNeeded()
        ZStack {
            switch entry.configuration.face {
            case .clock: clockBody
            case .date: dateBody
            case .weather: weatherBody
            case .currentWeather: currentWeatherBody
            case .compactWeather: compactWeatherBody
            case .luminousDigital: luminousDigitalBody
            case .calendarDuo: calendarDuoBody
            case .minimalClock: minimalClockBody
            case .dualLineTime: dualLineTimeBody
            case .gregorian: gregorianBody
            case .hijri: hijriBody
            case .weekPulse: weekPulseBody
            case .monthProgress: monthProgressBody
            case .yearJourney: yearJourneyBody
            case .quranAyah: quranAyahBody
            case .quranDhikr: quranDhikrBody
            case .quranTicker: quranTickerBody
            case .quranVerse1: quranVerseBody(index: 0)
            case .quranVerse2: quranVerseBody(index: 1)
            case .quranVerse3: quranVerseBody(index: 2)
            case .quranVerse4: quranVerseBody(index: 3)
            case .arabicWeekday: arabicWeekdayBody
            case .arabicToday: arabicTodayBody
            case .arabicMonthPoster: arabicMonthPosterBody
            }
        }
        .containerBackground(for: .widget) {
            NoorWidgetShared.widgetBackground(for: entry.configuration.background)
        }
    }

    private var clockBody: some View {
        VStack(spacing: 6) {
            Text(
                NoorWidgetShared.formatTime(
                    entry.date, language: entry.configuration.language,
                    digits: entry.configuration.digits)
            )
            .font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(.white)
            let dateText = NoorWidgetShared.formatDate(
                entry.date, language: entry.configuration.language,
                digits: entry.configuration.digits, calendar: entry.configuration.calendar,
                format: entry.configuration.dateFormat)
            if !dateText.isEmpty {
                Text(dateText).font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .padding(14)
    }

    private var dateBody: some View {
        VStack(spacing: 8) {
            Text(
                NoorWidgetShared.formatDate(
                    entry.date, language: entry.configuration.language,
                    digits: entry.configuration.digits, calendar: entry.configuration.calendar,
                    format: entry.configuration.dateFormat)
            )
            .font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundStyle(.white)
            .multilineTextAlignment(.center).lineLimit(2)
        }
        .padding(12)
    }

    private var weatherBody: some View {
        let resolvedLanguage = NoorWidgetShared.resolvedLanguage(entry.configuration.language)
        return VStack(spacing: 6) {
            if let weather = entry.weather {
                Image(systemName: weather.symbol).font(.system(size: 24, weight: .regular))
                    .foregroundStyle(.white)
                let temperatureText = "\(Int(weather.tempC.rounded()))"
                Text(
                    (NoorWidgetShared.resolvedDigits(
                        entry.configuration.digits, language: entry.configuration.language)
                        == .arabic
                        ? NoorWidgetShared.toArabicDigits(temperatureText) : temperatureText) + "°"
                )
                .font(.system(size: 30, weight: .heavy, design: .rounded)).foregroundStyle(.yellow)
                Text(
                    resolvedLanguage == .arabic
                        ? localizedConditionArabic(weather.label) : weather.label
                )
                .font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(
                    .white.opacity(0.8))
            } else {
                Text("--").font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .padding(12)
    }

    private var currentWeatherBody: some View {
        let locationName = NoorWidgetShared.defaults.string(forKey: "noor.lastLocationName") ?? "—"
        let resolvedLanguage = NoorWidgetShared.resolvedLanguage(entry.configuration.language)
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        timeFormatter.locale = Locale(identifier: resolvedLanguage == .arabic ? "ar" : "en")
        let dateFormatter = DateFormatter()
        dateFormatter.setLocalizedDateFormatFromTemplate("d MMM y")
        dateFormatter.locale = Locale(identifier: resolvedLanguage == .arabic ? "ar" : "en")

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(locationName).font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7)).lineLimit(1).truncationMode(.tail)
                Spacer()
                if let weather = entry.weather {
                    Image(systemName: weather.symbol).font(.system(size: 22, weight: .regular))
                        .foregroundStyle(.white)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let weather = entry.weather {
                    let temperatureText = "\(Int(weather.tempC.rounded()))"
                    Text(
                        (NoorWidgetShared.resolvedDigits(
                            entry.configuration.digits, language: entry.configuration.language)
                            == .arabic
                            ? NoorWidgetShared.toArabicDigits(temperatureText) : temperatureText)
                            + "°"
                    )
                    .font(.system(size: 42, weight: .heavy, design: .rounded)).foregroundStyle(
                        .yellow)
                } else {
                    Text("--").font(.system(size: 42, weight: .heavy, design: .rounded))
                        .foregroundStyle(.yellow)
                }
                Spacer()
                if let weather = entry.weather, let high = weather.highC, let low = weather.lowC {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("H: \(Int(high.rounded()))°").font(
                            .system(size: 10, weight: .semibold, design: .rounded)
                        ).foregroundStyle(.white.opacity(0.75))
                        Text("L: \(Int(low.rounded()))°").font(
                            .system(size: 10, weight: .semibold, design: .rounded)
                        ).foregroundStyle(.white.opacity(0.75))
                    }
                }
            }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(timeFormatter.string(from: entry.date)).font(
                        .system(size: 22, weight: .bold, design: .rounded)
                    ).foregroundStyle(.white)
                    Text(dateFormatter.string(from: entry.date)).font(
                        .system(size: 11, weight: .semibold, design: .rounded)
                    ).foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                Text("Updated now").font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(14).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var compactWeatherBody: some View {
        let locationName = NoorWidgetShared.defaults.string(forKey: "noor.lastLocationName") ?? "—"
        let resolvedLanguage = NoorWidgetShared.resolvedLanguage(entry.configuration.language)
        let locale = Locale(identifier: resolvedLanguage == .arabic ? "ar" : "en")
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        timeFormatter.locale = locale
        let dayFormatter = DateFormatter()
        dayFormatter.setLocalizedDateFormatFromTemplate("EEEE")
        dayFormatter.locale = locale
        let monthFormatter = DateFormatter()
        monthFormatter.setLocalizedDateFormatFromTemplate("d MMM")
        monthFormatter.locale = locale

        return GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let scale = min(w / 310.0, h / 146.0)
            HStack(alignment: .center, spacing: 12 * scale) {
                VStack(alignment: .leading, spacing: 4 * scale) {
                    if let weather = entry.weather {
                        HStack(spacing: 5 * scale) {
                            Image(systemName: weather.symbol).font(
                                .system(size: 36 * scale, weight: .regular)
                            ).foregroundStyle(.white)
                            Text(
                                (NoorWidgetShared.resolvedDigits(
                                    entry.configuration.digits,
                                    language: entry.configuration.language) == .arabic
                                    ? NoorWidgetShared.toArabicDigits(
                                        String(Int(weather.tempC.rounded())))
                                    : "\(Int(weather.tempC.rounded()))") + "°"
                            )
                            .font(.system(size: 24 * scale, weight: .heavy, design: .rounded))
                            .foregroundStyle(.yellow)
                        }
                    } else {
                        Text("--").font(.system(size: 24 * scale, weight: .heavy, design: .rounded))
                            .foregroundStyle(.yellow)
                    }
                    VStack(alignment: .leading, spacing: 2 * scale) {
                        if let weather = entry.weather {
                            Text(weather.label).font(
                                .system(size: 11 * scale, weight: .semibold, design: .rounded)
                            ).foregroundStyle(.white.opacity(0.7)).lineLimit(1).minimumScaleFactor(
                                0.8)
                        }
                        if let weather = entry.weather, let high = weather.highC,
                            let low = weather.lowC
                        {
                            let digits = NoorWidgetShared.resolvedDigits(
                                entry.configuration.digits, language: entry.configuration.language)
                            let highText =
                                digits == .arabic
                                ? NoorWidgetShared.toArabicDigits(String(Int(high.rounded())))
                                : "\(Int(high.rounded()))"
                            let lowText =
                                digits == .arabic
                                ? NoorWidgetShared.toArabicDigits(String(Int(low.rounded())))
                                : "\(Int(low.rounded()))"
                            Text("H: \(highText)  L: \(lowText)°").font(
                                .system(size: 10 * scale, weight: .semibold, design: .rounded)
                            ).foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2 * scale) {
                    Text(locationName).font(
                        .system(size: 11 * scale, weight: .bold, design: .rounded)
                    ).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
                    Text(dayFormatter.string(from: entry.date)).font(
                        .custom("DecoType Thuluth", size: 18 * scale)
                    ).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
                    Spacer().frame(height: 4 * scale)
                    Text(timeFormatter.string(from: entry.date)).font(
                        .system(size: 14 * scale, weight: .bold, design: .rounded)
                    ).foregroundStyle(.white)
                    Text(monthFormatter.string(from: entry.date)).font(
                        .system(size: 10 * scale, weight: .semibold, design: .rounded)
                    ).foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 14 * scale).padding(.vertical, 10 * scale)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var luminousDigitalBody: some View {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: entry.date)
        return VStack(alignment: .leading, spacing: 4) {
            Text(String(format: "%02d", comps.hour ?? 0)).font(
                .system(size: 50, weight: .heavy, design: .rounded)
            ).foregroundStyle(.yellow)
            Text(String(format: "%02d", comps.minute ?? 0)).font(
                .system(size: 44, weight: .bold, design: .rounded)
            ).foregroundStyle(.white)
            Text("Luminous Digital").font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(14)
    }

    private var calendarDuoBody: some View {
        let month = NoorWidgetShared.monthName(entry.date, language: entry.configuration.language)
            .uppercased()
        let weekday = NoorWidgetShared.weekdayNameFull(
            entry.date, language: NoorWidgetShared.resolvedLanguage(entry.configuration.language)
        ).uppercased()
        let day = NoorWidgetShared.dayNumber(
            entry.date, digits: entry.configuration.digits, language: entry.configuration.language)
        let shortMonth = NoorWidgetShared.shortMonth(
            entry.date, language: entry.configuration.language
        ).uppercased()

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(month)
                    .font(
                        ArabicTypography.dayFont(
                            size: 14, language: entry.configuration.language, weight: .medium)
                    )
                    .foregroundStyle(.white.opacity(0.7))
                MediumCapsuleLabel(
                    text: weekday,
                    color: .white.opacity(0.10),
                    textColor: .white,
                    language: entry.configuration.language
                )
            }
            Spacer()
            VStack(spacing: 8) {
                MediumCapsuleLabel(
                    text: shortMonth, color: .yellow, textColor: .black,
                    language: entry.configuration.language)
                MediumCapsuleLabel(
                    text: day, color: .white.opacity(0.10), textColor: .white,
                    language: entry.configuration.language)
            }
        }
        .padding(14)
    }

    private var minimalClockBody: some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        formatter.locale = Locale.current
        return Text(formatter.string(from: entry.date))
            .font(.system(size: 40, weight: .bold, design: .monospaced)).foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading).padding(14)
    }

    private var dualLineTimeBody: some View {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: entry.date)
        return VStack(alignment: .leading, spacing: 6) {
            Text(String(format: "%02d:%02d", comps.hour ?? 0, comps.minute ?? 0))
                .font(.system(size: 44, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                .overlay(alignment: .bottomLeading) {
                    Rectangle().fill(Color.yellow).frame(height: 5).offset(y: 8)
                }
            Text("Dual Line Time").font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(14)
    }

    private var gregorianBody: some View {
        let weekday = NoorWidgetShared.weekdayNameFull(
            entry.date, language: NoorWidgetShared.resolvedLanguage(entry.configuration.language)
        ).uppercased()
        let day = NoorWidgetShared.dayNumber(
            entry.date, digits: entry.configuration.digits, language: entry.configuration.language)
        let month = NoorWidgetShared.shortMonth(entry.date, language: entry.configuration.language)
            .uppercased()
        let year = NoorWidgetShared.yearNumber(
            entry.date, digits: entry.configuration.digits, language: entry.configuration.language)

        return HStack(spacing: 12) {
            MediumRoundedRectInfo(
                title: weekday,
                value: year,
                accent: .white.opacity(0.10),
                textColor: .white,
                language: entry.configuration.language
            )
            MediumRoundedRectInfo(
                title: month,
                value: day,
                accent: .yellow,
                textColor: .black,
                language: entry.configuration.language
            )
        }
        .padding(14)
    }

    private var hijriBody: some View {
        let hijri = Calendar(identifier: .islamicUmmAlQura)
        let comps = hijri.dateComponents([.day, .month, .year], from: entry.date)
        let day =
            NoorWidgetShared.resolvedDigits(
                entry.configuration.digits, language: entry.configuration.language) == .arabic
            ? NoorWidgetShared.toArabicDigits(String(comps.day ?? 0)) : String(comps.day ?? 0)
        let month = NoorWidgetShared.hijriMonthName(
            entry.date, language: NoorWidgetShared.resolvedLanguage(entry.configuration.language))
        let year = NoorWidgetShared.hijriYearNumber(
            entry.date, digits: entry.configuration.digits, language: entry.configuration.language)

        return HStack(spacing: 12) {
            MediumRoundedRectInfo(
                title: month,
                value: day,
                accent: .white.opacity(0.10),
                textColor: .white,
                language: entry.configuration.language
            )
            MediumRoundedRectInfo(
                title: "Hijri",
                value: year,
                accent: .yellow,
                textColor: .black,
                language: entry.configuration.language
            )
        }
        .padding(14)
    }

    private struct QuranSnippet {
        let arabic: String
        let translation: String
        let reference: String
    }

    private static let mediumQuranSnippets: [QuranSnippet] = [
        QuranSnippet(
            arabic: "فَإِنَّ مَعَ الْعُسْرِ يُسْرًا",
            translation: "For indeed, with hardship [will be] ease.",
            reference: "94:5"
        ),
        QuranSnippet(
            arabic: "وَهُوَ مَعَكُمْ أَيْنَ مَا كُنتُمْ",
            translation: "And He is with you wherever you are.",
            reference: "57:4"
        ),
        QuranSnippet(
            arabic: "أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ",
            translation: "Verily, in the remembrance of Allah do hearts find rest.",
            reference: "13:28"
        ),
        QuranSnippet(
            arabic: "إِنَّ اللَّهَ مَعَ الصَّابِرِينَ",
            translation: "Indeed, Allah is with the patient.",
            reference: "2:153"
        ),
    ]

    private var selectedQuranSnippet: QuranSnippet {
        let hourBucket = Int(entry.date.timeIntervalSinceReferenceDate / 3600)
        let index = abs(hourBucket) % Self.mediumQuranSnippets.count
        return Self.mediumQuranSnippets[index]
    }

    private var quranAyahBody: some View {
        let resolvedLanguage = NoorWidgetShared.resolvedLanguage(entry.configuration.language)
        let snippet = selectedQuranSnippet
        return VStack(alignment: .leading, spacing: 8) {
            Text("﷽")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))

            if resolvedLanguage == .arabic {
                Text(snippet.arabic)
                    .font(
                        ArabicTypography.quranFont(size: 30, language: entry.configuration.language)
                    )
                    .foregroundStyle(.yellow)
                    .lineLimit(2)
                    .minimumScaleFactor(0.65)
                Text(snippet.translation)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            } else {
                Text(snippet.translation)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Text(snippet.arabic)
                    .font(
                        ArabicTypography.quranFont(size: 26, language: entry.configuration.language)
                    )
                    .foregroundStyle(.yellow.opacity(0.9))
                    .lineLimit(2)
                    .minimumScaleFactor(0.65)
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Text("QURAN")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .tracking(1.2)
                Text(snippet.reference)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var quranDhikrBody: some View {
        let resolvedLanguage = NoorWidgetShared.resolvedLanguage(entry.configuration.language)
        return VStack(spacing: 10) {
            Text("﷽")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
            Text("سبحان الله وبحمده\nسبحان الله العظيم")
                .font(ArabicTypography.quranFont(size: 32, language: entry.configuration.language))
                .foregroundStyle(.yellow)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
            if resolvedLanguage != .arabic {
                Text("Glory be to Allah and praise Him.\nGlory be to Allah, the العظيم.")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var quranTickerBody: some View {
        ZStack {
            LinearGradient(
                colors: [.white.opacity(0.06), .clear], startPoint: .top, endPoint: .bottom
            )
            .mask(
                VStack(spacing: 5) {
                    ForEach(0..<10, id: \.self) { _ in
                        Rectangle().frame(height: 5)
                        Spacer(minLength: 5)
                    }
                }
            )
            Text("سبحان الله وبحمده، سبحان الله العظيم")
                .font(ArabicTypography.quranFont(size: 30, language: entry.configuration.language))
                .foregroundStyle(.yellow)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func quranVerseBody(index: Int) -> some View {
        let resolvedLanguage = NoorWidgetShared.resolvedLanguage(entry.configuration.language)
        let safeIndex = max(0, min(index, Self.mediumQuranSnippets.count - 1))
        let snippet = Self.mediumQuranSnippets[safeIndex]
        return VStack(alignment: .leading, spacing: 8) {
            Text("﷽")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))

            if resolvedLanguage == .arabic {
                Text(snippet.arabic)
                    .font(
                        ArabicTypography.quranFont(size: 34, language: entry.configuration.language)
                    )
                    .foregroundStyle(.yellow)
                    .lineLimit(2)
                    .minimumScaleFactor(0.62)
            } else {
                Text(snippet.translation)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Text(snippet.arabic)
                    .font(
                        ArabicTypography.quranFont(size: 26, language: entry.configuration.language)
                    )
                    .foregroundStyle(.yellow.opacity(0.9))
                    .lineLimit(2)
                    .minimumScaleFactor(0.65)
            }

            Spacer(minLength: 0)

            Text(snippet.reference)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var arabicWeekdayBody: some View {
        let resolvedLanguage = NoorWidgetShared.resolvedLanguage(entry.configuration.language)
        let weekdayArabic = NoorWidgetShared.weekdayNameFull(entry.date, language: .arabic)
        let weekdayEnglish = NoorWidgetShared.weekdayNameFull(entry.date, language: .english)

        return Text(resolvedLanguage == .arabic ? weekdayArabic : weekdayEnglish)
            .font(
                ArabicTypography.dayFont(
                    size: 68,
                    language: entry.configuration.language,
                    weight: .regular
                )
            )
            .foregroundStyle(.yellow)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, 16)
    }

    private var arabicTodayBody: some View {
        let resolvedLanguage = NoorWidgetShared.resolvedLanguage(entry.configuration.language)
        let weekdayArabic = NoorWidgetShared.weekdayNameFull(entry.date, language: .arabic)
        let weekdayEnglish = NoorWidgetShared.weekdayNameFull(entry.date, language: .english)
        let day = NoorWidgetShared.dayNumber(
            entry.date, digits: entry.configuration.digits, language: entry.configuration.language)
        let month = NoorWidgetShared.monthName(entry.date, language: entry.configuration.language)
            .uppercased()

        return VStack(spacing: 6) {
            Text(resolvedLanguage == .arabic ? weekdayArabic : weekdayEnglish)
                .font(
                    ArabicTypography.dayFont(
                        size: 40, language: entry.configuration.language, weight: .regular)
                )
                .foregroundStyle(.yellow)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.center)
            Text(day)
                .font(.system(size: 72, weight: .heavy, design: .rounded))
                .foregroundStyle(.yellow)
                .opacity(0.18)
                .overlay {
                    Text(month)
                        .font(.system(size: 42, weight: .bold, design: .serif))
                        .foregroundStyle(.white.opacity(0.95))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var arabicMonthPosterBody: some View {
        let resolvedLanguage = NoorWidgetShared.resolvedLanguage(entry.configuration.language)
        let day = NoorWidgetShared.dayNumber(
            entry.date,
            digits: entry.configuration.digits,
            language: entry.configuration.language
        )
        let monthArabic = NoorWidgetShared.monthName(entry.date, language: .arabic)
        let monthEnglish = NoorWidgetShared.monthName(entry.date, language: .english).uppercased()

        return ZStack {
            Text(day)
                .font(.system(size: 120, weight: .heavy, design: .rounded))
                .foregroundStyle(.yellow.opacity(0.12))
                .offset(y: -10)
            if resolvedLanguage == .arabic {
                Text(monthArabic)
                    .font(
                        ArabicTypography.dayFont(
                            size: 62, language: entry.configuration.language, weight: .regular)
                    )
                    .foregroundStyle(.white.opacity(0.95))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            } else {
                Text(monthEnglish)
                    .font(.system(size: 54, weight: .bold, design: .serif))
                    .foregroundStyle(.white.opacity(0.95))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
    }

    private var weekPulseBody: some View {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: entry.date)
        let adjustedDay = weekday == 1 ? 7 : weekday - 1

        return VStack(spacing: 10) {
            Text("Week Pulse").font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
            HStack(spacing: 10) {
                ForEach(1...7, id: \.self) { day in
                    let isToday = day == adjustedDay
                    Circle().fill(isToday ? Color.yellow : Color.white.opacity(0.15))
                        .frame(width: isToday ? 16 : 10, height: isToday ? 16 : 10)
                }
            }
            Text(
                NoorWidgetShared.weekdayNameFull(
                    entry.date,
                    language: NoorWidgetShared.resolvedLanguage(entry.configuration.language))
            )
            .font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.white)
        }
        .padding(14)
    }

    private var monthProgressBody: some View {
        let calendar = Calendar.current
        let dayOfMonth = calendar.component(.day, from: entry.date)
        let daysInMonth = calendar.range(of: .day, in: .month, for: entry.date)?.count ?? 30
        let columns = 10
        let rows = Int(ceil(Double(daysInMonth) / Double(columns)))

        return VStack(spacing: 10) {
            Text("Month Progress").font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
            VStack(spacing: 4) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 4) {
                        ForEach(0..<columns, id: \.self) { col in
                            let dayNum = row * columns + col + 1
                            if dayNum <= daysInMonth {
                                let isPassed = dayNum <= dayOfMonth
                                Circle().fill(isPassed ? Color.yellow : Color.white.opacity(0.15))
                                    .frame(width: isPassed ? 8 : 6, height: isPassed ? 8 : 6)
                            } else {
                                Color.clear.frame(width: 6, height: 6)
                            }
                        }
                    }
                }
            }
            Text("Day \(dayOfMonth) of \(daysInMonth)").font(
                .system(size: 12, weight: .semibold, design: .rounded)
            ).foregroundStyle(.white.opacity(0.7))
        }
        .padding(14)
    }

    private var yearJourneyBody: some View {
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: entry.date) ?? 1
        let year = calendar.component(.year, from: entry.date)
        let totalDays = calendar.range(of: .day, in: .year, for: entry.date)?.count ?? 365
        let currentMonth = calendar.component(.month, from: entry.date)

        return VStack(spacing: 10) {
            Text("Year Journey").font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
            HStack(spacing: 8) {
                ForEach(1...12, id: \.self) { month in
                    let isCurrent = month == currentMonth
                    Circle().fill(isCurrent ? Color.yellow : Color.white.opacity(0.15))
                        .frame(width: isCurrent ? 14 : 8, height: isCurrent ? 14 : 8)
                }
            }
            VStack(spacing: 2) {
                Text("\(year)").font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Day \(dayOfYear) of \(totalDays)").font(
                    .system(size: 12, weight: .semibold, design: .rounded)
                ).foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(14)
    }

    private func localizedConditionArabic(_ english: String) -> String {
        switch english {
        case "Clear": return "صحو"
        case "Partly Cloudy": return "غائم جزئياً"
        case "Fog": return "ضباب"
        case "Drizzle": return "رذاذ"
        case "Rain": return "مطر"
        case "Snow": return "ثلج"
        case "Showers": return "زخات"
        case "Thunder": return "عاصفة"
        default: return english
        }
    }
}

private struct MediumCapsuleLabel: View {
    let text: String
    let color: Color
    let textColor: Color
    let language: WidgetLanguage

    init(text: String, color: Color, textColor: Color, language: WidgetLanguage) {
        self.text = text
        self.color = color
        self.textColor = textColor
        self.language = language
    }
    var body: some View {
        Text(text)
            .font(ArabicTypography.dayFont(size: 12, language: language, weight: .bold))
            .foregroundStyle(textColor)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(color).clipShape(Capsule())
    }
}

private struct MediumRoundedRectInfo: View {
    let title: String
    let value: String
    let accent: Color
    let textColor: Color
    let language: WidgetLanguage
    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(ArabicTypography.dayFont(size: 11, language: language, weight: .semibold))
                .foregroundStyle(textColor == .black ? .black.opacity(0.7) : textColor.opacity(0.7))
            Text(value).font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(
                textColor)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 16).background(accent).clipShape(
            RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// ─────────────────────────────────────────────────────────────────
// MARK: - NoorSmallWidgetView
// ─────────────────────────────────────────────────────────────────

struct NoorSmallWidgetView: View {
    let entry: NoorWidgetEntry

    var body: some View {
        ZStack {
            switch entry.configuration.face {
            case .clock: smallClockBody
            case .date: smallDateBody
            case .weather: smallWeatherBody
            case .minimalist: SmallMinimalistBody(entry: entry)
            case .gradientRing: SmallGradientRingBody(entry: entry)
            case .retroNeon: SmallRetroNeonBody(entry: entry)
            case .geometric: SmallGeometricBody(entry: entry)
            case .luxuryGold: SmallLuxuryGoldBody(entry: entry)
            case .midnight: SmallMidnightBody(entry: entry)
            case .prayerProgress: SmallPrayerProgressBody(entry: entry)
            case .qiblaCompass: SmallQiblaCompassBody(entry: entry)
            case .currentWeather: SmallCurrentWeatherBody(entry: entry)
            case .compactWeather: SmallCompactWeatherBody(entry: entry)
            case .prayerTimes: SmallPrayerTimesBody(entry: entry)
            case .arabicMonthTile: SmallArabicMonthTileBody(entry: entry)
            }
        }
        .containerBackground(for: .widget) {
            NoorWidgetShared.widgetBackground(for: entry.configuration.background)
        }
    }

    private var smallDateBody: some View {
        Group {
            if entry.configuration.calendar == .hijri { hijriDateBody } else { gregorianDateBody }
        }
    }

    private var hijriDateBody: some View {
        let resolvedLanguage = NoorWidgetShared.resolvedLanguage(entry.configuration.language)
        return VStack(spacing: 6) {
            Text(
                NoorWidgetShared.dayNumber(
                    entry.date, digits: entry.configuration.digits,
                    language: entry.configuration.language)
            )
            .font(.custom("DecoType Thuluth", size: 56)).foregroundStyle(.yellow).shadow(
                color: Color.yellow.opacity(0.3), radius: 6)
            Text(
                NoorWidgetShared.shortMonth(entry.date, language: entry.configuration.language)
                    .uppercased()
            )
            .font(.custom("DecoType Thuluth", size: 16)).foregroundStyle(.white)
            Text(
                NoorWidgetShared.hijriDayNumber(
                    entry.date, digits: entry.configuration.digits,
                    language: entry.configuration.language) + " "
                    + NoorWidgetShared.hijriMonthName(entry.date, language: resolvedLanguage)
            )
            .font(.custom("DecoType Thuluth", size: 14)).foregroundStyle(.white.opacity(0.7))
            .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(12)
    }

    private var gregorianDateBody: some View {
        let resolvedLanguage = NoorWidgetShared.resolvedLanguage(entry.configuration.language)
        return VStack(spacing: 10) {
            Text(
                NoorWidgetShared.weekdayNameFull(entry.date, language: resolvedLanguage)
                    .uppercased()
            )
            .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(
                .white.opacity(0.6)
            ).lineLimit(1).minimumScaleFactor(0.7)
            Text(
                NoorWidgetShared.dayNumber(
                    entry.date, digits: entry.configuration.digits,
                    language: entry.configuration.language)
            )
            .font(.system(size: 76, weight: .heavy, design: .rounded)).foregroundStyle(.yellow)
            .lineLimit(1).minimumScaleFactor(0.7)
            Text(NoorWidgetShared.monthName(entry.date, language: resolvedLanguage).uppercased())
                .font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(
                NoorWidgetShared.yearNumber(
                    entry.date, digits: entry.configuration.digits,
                    language: entry.configuration.language)
            )
            .font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(
                .white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(.vertical, 18).padding(
            .horizontal, 12)
    }

    private var smallClockBody: some View {
        VStack(spacing: 10) {
            Text(
                NoorWidgetShared.formatTime(
                    entry.date, language: entry.configuration.language,
                    digits: entry.configuration.digits)
            )
            .font(.system(size: 36, weight: .bold, design: .monospaced)).foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(
                NoorWidgetShared.formatDate(
                    entry.date, language: entry.configuration.language,
                    digits: entry.configuration.digits, calendar: entry.configuration.calendar,
                    format: entry.configuration.dateFormat)
            )
            .font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(
                .white.opacity(0.75)
            ).frame(maxWidth: .infinity, alignment: .leading).lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading).padding(12)
    }

    private var smallWeatherBody: some View {
        let resolvedLanguage = NoorWidgetShared.resolvedLanguage(entry.configuration.language)
        return VStack(spacing: 6) {
            if let weather = entry.weather {
                Image(systemName: weather.symbol).font(.system(size: 22, weight: .regular))
                    .foregroundStyle(.white)
                let temperatureText = "\(Int(weather.tempC.rounded()))"
                Text(
                    (NoorWidgetShared.resolvedDigits(
                        entry.configuration.digits, language: entry.configuration.language)
                        == .arabic
                        ? NoorWidgetShared.toArabicDigits(temperatureText) : temperatureText) + "°"
                )
                .font(.system(size: 38, weight: .heavy, design: .rounded)).foregroundStyle(.yellow)
                Text(
                    resolvedLanguage == .arabic
                        ? localizedConditionArabic(weather.label) : weather.label
                )
                .font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(
                    .white.opacity(0.8)
                ).lineLimit(1)
            } else {
                Text("--").font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .padding(12)
    }

    private func localizedConditionArabic(_ english: String) -> String {
        switch english {
        case "Clear": return "صحو"
        case "Partly Cloudy": return "غائم جزئياً"
        case "Fog": return "ضباب"
        case "Drizzle": return "رذاذ"
        case "Rain": return "مطر"
        case "Snow": return "ثلج"
        case "Showers": return "زخات"
        case "Thunder": return "عاصفة"
        default: return english
        }
    }
}

// ─────────────────────────────────────────────────────────────────
// MARK: - Small analog clock bodies
//  ✅  FIX: TimelineView(.animation) verwijderd.
//      Alle analoge klokken lezen nu entry.date direct.
//      De provider bouwt 1-seconde entries zodat iOS de view
//      elke seconde opnieuw rendert met de juiste hoeken.
// ─────────────────────────────────────────────────────────────────

private struct SmallMinimalistBody: View {
    let entry: NoorWidgetEntry

    var body: some View {
        // ✅ Gebruik entry.date — geen TimelineView(.animation)
        let angles = clockAngles(from: entry.date)
        let size: CGFloat = 130

        ZStack {
            Circle()
                .fill(Color.black.opacity(0.0))
                .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))

            ForEach(0..<60) { i in
                let isHour = i % 5 == 0
                Rectangle()
                    .fill(Color.white.opacity(isHour ? 0.85 : 0.25))
                    .frame(width: isHour ? 2 : 1, height: isHour ? 10 : 5)
                    .offset(y: -(size / 2 - 14))
                    .rotationEffect(.degrees(Double(i) * 6))
            }

            WidgetHand(length: size * 0.30, width: 4, color: .white, angleDeg: angles.hour)
            WidgetHand(
                length: size * 0.42, width: 2.5, color: .white.opacity(0.85),
                angleDeg: angles.minute)
            WidgetHand(length: size * 0.46, width: 1.5, color: .yellow, angleDeg: angles.second)
                .shadow(color: .yellow.opacity(0.5), radius: 3)

            Circle().fill(Color.yellow).frame(width: 6, height: 6)
                .overlay(Circle().stroke(Color.black, lineWidth: 1))
        }
        .frame(width: size, height: size)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SmallGradientRingBody: View {
    let entry: NoorWidgetEntry

    var body: some View {
        // ✅ Gebruik entry.date — geen TimelineView(.animation)
        let angles = clockAngles(from: entry.date)
        let size: CGFloat = 130

        ZStack {
            Circle()
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.yellow, Color.white.opacity(0.7), Color.yellow.opacity(0.3),
                            Color.yellow,
                        ]),
                        center: .center
                    ),
                    lineWidth: 7
                )
                .padding(4)

            Circle().stroke(Color.white.opacity(0.08), lineWidth: 1).padding(14)

            ForEach(0..<12) { i in
                let isMajor = i % 3 == 0
                Circle()
                    .fill(Color.white.opacity(isMajor ? 0.85 : 0.35))
                    .frame(width: isMajor ? 5 : 3, height: isMajor ? 5 : 3)
                    .offset(y: -(size / 2 - 22))
                    .rotationEffect(.degrees(Double(i) * 30))
            }

            WidgetHand(length: size * 0.28, width: 5, color: .white, angleDeg: angles.hour)
            WidgetHand(
                length: size * 0.40, width: 3, color: .white.opacity(0.8), angleDeg: angles.minute)
            WidgetHand(length: size * 0.44, width: 2, color: .yellow, angleDeg: angles.second)

            Circle().fill(Color.white).frame(width: 8, height: 8)
                .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
        }
        .frame(width: size, height: size)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SmallRetroNeonBody: View {
    let entry: NoorWidgetEntry
    private let neon = Color.yellow

    var body: some View {
        // ✅ Gebruik entry.date — geen TimelineView(.animation)
        let angles = clockAngles(from: entry.date)
        let size: CGFloat = 128

        ZStack {
            Circle().stroke(neon.opacity(0.75), lineWidth: 2).shadow(
                color: neon.opacity(0.5), radius: 6)

            ForEach(1...12, id: \.self) { i in
                Text("\(i)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(neon.opacity(0.8))
                    .offset(y: -(size / 2 - 22))
                    .rotationEffect(.degrees(Double(i) * 30))
                    .rotationEffect(.degrees(-Double(i) * 30), anchor: .center)
                    .rotationEffect(.degrees(Double(i) * 30), anchor: .center)
            }

            WidgetHand(length: size * 0.28, width: 4, color: .white, angleDeg: angles.hour)
            WidgetHand(
                length: size * 0.40, width: 2.5, color: .white.opacity(0.9), angleDeg: angles.minute
            )
            WidgetHand(length: size * 0.44, width: 1.5, color: neon, angleDeg: angles.second)
                .shadow(color: neon.opacity(0.8), radius: 5)

            Circle().fill(neon).frame(width: 7, height: 7)
                .overlay(Circle().stroke(Color.black, lineWidth: 1))
                .shadow(color: neon.opacity(0.6), radius: 4)
        }
        .frame(width: size, height: size)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SmallGeometricBody: View {
    let entry: NoorWidgetEntry

    var body: some View {
        // ✅ Gebruik entry.date — geen TimelineView(.animation)
        let angles = clockAngles(from: entry.date)
        let size: CGFloat = 130

        ZStack {
            ForEach(0..<4) { i in
                SmallHexagon()
                    .stroke(Color.white.opacity(0.10 - Double(i) * 0.02), lineWidth: 1)
                    .padding(CGFloat(i) * 12)
            }

            ForEach(0..<12) { i in
                SmallTriangle()
                    .fill(Color.white.opacity(0.55))
                    .frame(width: 6, height: 8)
                    .offset(y: -(size / 2 - 20))
                    .rotationEffect(.degrees(Double(i) * 30))
            }

            WidgetHand(length: size * 0.30, width: 5, color: .white, angleDeg: angles.hour)
            WidgetHand(
                length: size * 0.42, width: 3, color: .white.opacity(0.8), angleDeg: angles.minute)
            WidgetHand(length: size * 0.46, width: 2, color: .yellow, angleDeg: angles.second)

            Circle().fill(Color.yellow).frame(width: 8, height: 8)
        }
        .frame(width: size, height: size)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SmallHexagon: Shape {
    func path(in rect: CGRect) -> Path {
        let cx = rect.midX
        let cy = rect.midY
        let r = min(rect.width, rect.height) / 2
        var p = Path()
        for i in 0..<6 {
            let angle = (Double(i) * 60.0 - 30.0) * .pi / 180.0
            let pt = CGPoint(x: cx + r * CGFloat(cos(angle)), y: cy + r * CGFloat(sin(angle)))
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        p.closeSubpath()
        return p
    }
}

private struct SmallTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct SmallLuxuryGoldBody: View {
    let entry: NoorWidgetEntry
    private let romanNumerals = [
        "XII", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI",
    ]

    var body: some View {
        // ✅ Gebruik entry.date — geen TimelineView(.animation)
        let angles = clockAngles(from: entry.date)
        let size: CGFloat = 130

        ZStack {
            Circle().stroke(Color.yellow.opacity(0.55), lineWidth: 2)
            Circle().stroke(Color.yellow.opacity(0.2), lineWidth: 1).padding(8)

            ForEach(0..<12) { i in
                Text(romanNumerals[i])
                    .font(.system(size: 10, weight: .medium, design: .serif))
                    .foregroundStyle(Color.yellow.opacity(0.85))
                    .offset(y: -(size / 2 - 26))
                    .rotationEffect(.degrees(Double(i) * 30))
                    .rotationEffect(.degrees(-Double(i) * 30), anchor: .center)
                    .rotationEffect(.degrees(Double(i) * 30), anchor: .center)
            }

            WidgetHand(length: size * 0.27, width: 5, color: .yellow, angleDeg: angles.hour)
            WidgetHand(
                length: size * 0.38, width: 3, color: .yellow.opacity(0.8), angleDeg: angles.minute)
            WidgetHand(length: size * 0.44, width: 1.5, color: .white, angleDeg: angles.second)

            Circle().fill(Color.yellow).frame(width: 8, height: 8)
                .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
                .shadow(color: .yellow.opacity(0.5), radius: 4)
        }
        .frame(width: size, height: size)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SmallMidnightBody: View {
    let entry: NoorWidgetEntry

    var body: some View {
        // ✅ Gebruik entry.date — geen TimelineView(.animation)
        let angles = clockAngles(from: entry.date)
        let size: CGFloat = 130

        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(white: 0.12), Color.black], center: .center, startRadius: 10,
                        endRadius: size / 2))
            Circle().stroke(Color.white.opacity(0.08), lineWidth: 1)

            ForEach(0..<12) { i in
                Circle().fill(Color.white.opacity(0.28)).frame(width: 3, height: 3)
                    .offset(y: -(size / 2 - 16))
                    .rotationEffect(.degrees(Double(i) * 30))
            }

            Circle()
                .trim(from: 0, to: 0.5)
                .stroke(Color.yellow.opacity(0.35), lineWidth: 2)
                .rotationEffect(.degrees(angles.second))
                .padding(size * 0.12)

            WidgetHand(
                length: size * 0.30, width: 4, color: .white.opacity(0.9), angleDeg: angles.hour)
            WidgetHand(
                length: size * 0.42, width: 2.5, color: .white.opacity(0.7), angleDeg: angles.minute
            )
            WidgetHand(length: size * 0.46, width: 1.2, color: .yellow, angleDeg: angles.second)
                .shadow(color: .yellow.opacity(0.4), radius: 3)

            Circle().fill(Color.yellow).frame(width: 5, height: 5)
        }
        .frame(width: size, height: size)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// ─────────────────────────────────────────────────────────────────
// MARK: - Small non-clock bodies (ongewijzigd)
// ─────────────────────────────────────────────────────────────────

private struct SmallPrayerProgressBody: View {
    let entry: NoorWidgetEntry

    private var obligatoryPrayers: [(String, Date)] {
        entry.prayerTimes.filter { $0.0 != "Sunrise" }
    }
    private var completedCount: Int { obligatoryPrayers.filter { $0.1 <= entry.date }.count }
    private var nextPrayer: (String, Date)? { entry.prayerTimes.first { $0.1 > entry.date } }
    private var progress: Double {
        guard obligatoryPrayers.count > 0 else { return 0 }
        return Double(completedCount) / Double(obligatoryPrayers.count)
    }

    private func arabicName(_ english: String) -> String {
        switch english {
        case "Fajr": return "الفجر"
        case "Dhuhr": return "الظهر"
        case "Asr": return "العصر"
        case "Maghrib": return "المغرب"
        case "Isha": return "العشاء"
        case "Sunrise": return "الشروق"
        default: return english
        }
    }

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.08), lineWidth: 10).padding(10)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.yellow, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90)).padding(10)
            VStack(spacing: 2) {
                Text("\(completedCount)/5").font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                if let next = nextPrayer {
                    let isArabic =
                        NoorWidgetShared.resolvedLanguage(entry.configuration.language) == .arabic
                    Text(isArabic ? arabicName(next.0) : next.0)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.yellow).lineLimit(1).minimumScaleFactor(0.7)
                } else {
                    Text("الحمد لله").font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.yellow.opacity(0.8))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(8)
    }
}

private struct SmallQiblaCompassBody: View {
    let entry: NoorWidgetEntry
    private var qiblaDir: Double? {
        let lat = NoorWidgetShared.defaults.double(forKey: "noor.lastLatitude")
        let lon = NoorWidgetShared.defaults.double(forKey: "noor.lastLongitude")
        guard lat != 0 || lon != 0 else { return nil }
        return NoorWidgetShared.qiblaDirection(latitude: lat, longitude: lon)
    }

    var body: some View {
        if let dir = qiblaDir {
            ZStack {
                ForEach(0..<12) { i in
                    Capsule()
                        .fill(i == 0 ? Color.yellow : Color.white.opacity(0.3))
                        .frame(width: i % 3 == 0 ? 2 : 1, height: i % 3 == 0 ? 8 : 5)
                        .offset(y: -54).rotationEffect(.degrees(Double(i) * 30))
                }
                Text("N").font(.system(size: 9, weight: .bold, design: .rounded)).foregroundStyle(
                    .yellow
                ).offset(y: -40)
                VStack(spacing: 0) {
                    Image(systemName: "arrowtriangle.up.fill").font(
                        .system(size: 20, weight: .regular)
                    ).foregroundStyle(.yellow).shadow(color: .yellow.opacity(0.5), radius: 5)
                    Circle().fill(Color.yellow).frame(width: 5, height: 5)
                }
                .rotationEffect(.degrees(dir))
                VStack {
                    Spacer()
                    Text("\(Int(dir.rounded()))°").font(
                        .system(size: 14, weight: .bold, design: .rounded)
                    ).foregroundStyle(.white)
                    Text("QIBLA").font(.system(size: 8, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55)).tracking(1.5)
                }
                .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 6) {
                Image(systemName: "location.slash").font(.system(size: 24)).foregroundStyle(
                    .white.opacity(0.4))
                Text("Set Location").font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5)).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity).padding(14)
        }
    }
}

private struct SmallCurrentWeatherBody: View {
    let entry: NoorWidgetEntry

    var body: some View {
        VStack(spacing: 5) {
            if let weather = entry.weather {
                Image(systemName: weather.symbol).font(.system(size: 28, weight: .light))
                    .foregroundStyle(.white)
                let tempText = "\(Int(weather.tempC.rounded()))"
                let displayTemp =
                    NoorWidgetShared.resolvedDigits(
                        entry.configuration.digits, language: entry.configuration.language)
                        == .arabic
                    ? NoorWidgetShared.toArabicDigits(tempText) : tempText
                Text(displayTemp + "°").font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundStyle(.yellow)
                Text(
                    NoorWidgetShared.resolvedLanguage(entry.configuration.language) == .arabic
                        ? localizedConditionArabic(weather.label) : weather.label
                )
                .font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundStyle(
                    .white.opacity(0.75)
                ).lineLimit(1).minimumScaleFactor(0.7)
                if let high = weather.highC, let low = weather.lowC {
                    HStack(spacing: 8) {
                        Label("\(Int(high.rounded()))°", systemImage: "arrow.up")
                        Label("\(Int(low.rounded()))°", systemImage: "arrow.down")
                    }
                    .font(.system(size: 9, weight: .semibold, design: .rounded)).foregroundStyle(
                        .white.opacity(0.5))
                }
            } else {
                Image(systemName: "cloud.fill").font(.system(size: 28)).foregroundStyle(
                    .white.opacity(0.4))
                Text("--").font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(10)
    }

    private func localizedConditionArabic(_ english: String) -> String {
        switch english {
        case "Clear": return "صحو"
        case "Partly Cloudy": return "غائم جزئياً"
        case "Fog": return "ضباب"
        case "Drizzle": return "رذاذ"
        case "Rain": return "مطر"
        case "Snow": return "ثلج"
        case "Showers": return "زخات"
        case "Thunder": return "عاصفة"
        default: return english
        }
    }
}

private struct SmallCompactWeatherBody: View {
    let entry: NoorWidgetEntry
    private var locationName: String {
        NoorWidgetShared.defaults.string(forKey: "noor.lastLocationName") ?? "—"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                if let weather = entry.weather {
                    Image(systemName: weather.symbol).font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.white.opacity(0.85))
                }
                Text(locationName).font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55)).lineLimit(1).truncationMode(.tail)
            }
            .padding(.bottom, 6)
            Spacer()
            if let weather = entry.weather {
                let tempText = "\(Int(weather.tempC.rounded()))"
                let displayTemp =
                    NoorWidgetShared.resolvedDigits(
                        entry.configuration.digits, language: entry.configuration.language)
                        == .arabic
                    ? NoorWidgetShared.toArabicDigits(tempText) : tempText
                Text(displayTemp + "°").font(.system(size: 42, weight: .heavy, design: .rounded))
                    .foregroundStyle(.yellow)
                if let high = weather.highC, let low = weather.lowC {
                    Text("H:\(Int(high.rounded()))°  L:\(Int(low.rounded()))°")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45)).padding(.top, 2)
                }
            } else {
                Text("--").font(.system(size: 42, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading).padding(14)
    }
}

private struct SmallPrayerTimesBody: View {
    let entry: NoorWidgetEntry
    private var lang: WidgetLanguage { entry.configuration.language }
    private var isArabic: Bool { NoorWidgetShared.resolvedLanguage(lang) == .arabic }

    private func arabicName(_ english: String) -> String {
        switch english {
        case "Fajr": return "الفجر"
        case "Sunrise": return "الشروق"
        case "Dhuhr": return "الظهر"
        case "Asr": return "العصر"
        case "Maghrib": return "المغرب"
        case "Isha": return "العشاء"
        default: return english
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(isArabic ? "مواقيت الصلاة" : "Prayer Times")
                    .font(.system(size: 8, weight: .bold, design: .rounded)).foregroundStyle(
                        .white.opacity(0.6))
                Spacer()
                Text(entry.date, format: Date.FormatStyle().day().month(.abbreviated))
                    .font(.system(size: 8, weight: .semibold, design: .rounded)).foregroundStyle(
                        .white.opacity(0.6))
            }
            if entry.prayerTimes.isEmpty {
                Spacer()
                Text(isArabic ? "يلزم تحديد الموقع" : "Location needed")
                    .font(.system(size: 8, weight: .semibold, design: .rounded)).foregroundStyle(
                        .white.opacity(0.6))
                Spacer()
            } else {
                VStack(spacing: 2) {
                    ForEach(Array(entry.prayerTimes.enumerated()), id: \.offset) { _, prayer in
                        let isPast = prayer.1 <= entry.date
                        HStack(spacing: 4) {
                            Text(isArabic ? arabicName(prayer.0) : prayer.0.uppercased())
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(.yellow).lineLimit(1).minimumScaleFactor(0.7)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(prayer.1, style: .time)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(isPast ? .white.opacity(0.5) : .white)
                            if isPast {
                                Text("✓").font(.system(size: 8, weight: .bold)).foregroundStyle(
                                    .yellow.opacity(0.6))
                            }
                        }
                        .padding(.vertical, 4).padding(.horizontal, 6)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top).padding(8)
    }
}

private struct SmallArabicMonthTileBody: View {
    let entry: NoorWidgetEntry
    private var digits: WidgetDigits { entry.configuration.digits }
    private var lang: WidgetLanguage { entry.configuration.language }

    var body: some View {
        let day = NoorWidgetShared.dayNumber(entry.date, digits: digits, language: lang)
        let monthArabic = NoorWidgetShared.monthName(entry.date, language: .arabic)

        return ZStack {
            Text(day)
                .font(.system(size: 120, weight: .heavy, design: .rounded))
                .foregroundStyle(.yellow.opacity(0.10))
                .offset(x: -8, y: -6)
            Text(monthArabic)
                .font(ArabicTypography.dayFont(size: 54, language: lang, weight: .regular))
                .foregroundStyle(.white.opacity(0.95))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(10)
    }
}

// ─────────────────────────────────────────────────────────────────
// MARK: - Widget definities
// ─────────────────────────────────────────────────────────────────

struct NoorSmallWidget: Widget {
    let kind: String = "NoorSmallWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind, intent: NoorWidgetIntent.self, provider: NoorWidgetProvider()
        ) { entry in
            NoorSmallWidgetView(entry: entry)
        }
        .configurationDisplayName("Noor Time Small")
        .description("Small Noor widget — clock, date, weather, prayer progress, Qibla and more.")
        .supportedFamilies([.systemSmall])
    }
}

struct NoorMediumWidget: Widget {
    let kind: String = "NoorMediumWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind, intent: NoorMediumWidgetIntent.self, provider: NoorMediumWidgetProvider()
        ) { entry in
            NoorMediumWidgetView(entry: entry)
        }
        .configurationDisplayName("Noor Time Medium")
        .description("Medium Noor widget with clock, date, weather and extra cards.")
        .supportedFamilies([.systemMedium])
    }
}

struct NoorLargeWidget: Widget {
    let kind: String = "NoorLargeWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind, intent: NoorLargeWidgetIntent.self, provider: NoorLargeWidgetProvider()
        ) { entry in
            NoorLargeWidgetView(entry: entry)
        }
        .configurationDisplayName("Noor Time Large")
        .description(
            "Large Noor widget — prayer times, date, clock, weather, dots, Qibla and more."
        )
        .supportedFamilies([.systemLarge])
    }
}

@main
struct NoorTimeWidgetBundle: WidgetBundle {
    var body: some Widget {
        NoorSmallWidget()
        NoorMediumWidget()
        NoorLargeWidget()
    }
}
