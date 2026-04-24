import SwiftUI
import WidgetKit
import AppIntents

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
        formatter.locale = resolvedLanguage == .arabic ? Locale(identifier: "ar") : Locale(identifier: "en")
        let raw = formatter.string(from: date)
        return resolvedDigits == .arabic ? toArabicDigits(raw) : raw
    }

    static func formatDate(_ date: Date, language: WidgetLanguage, digits: WidgetDigits, calendar: WidgetCalendar, format: WidgetDateFormat) -> String {
        let resolvedLanguage = resolvedLanguage(language)
        let resolvedDigits = resolvedDigits(digits, language: language)
        let formatter = DateFormatter()
        switch format {
        case .auto:
            formatter.calendar = calendar == .hijri ? Calendar(identifier: .islamicUmmAlQura) : Calendar(identifier: .gregorian)
            formatter.locale = resolvedLanguage == .arabic ? Locale(identifier: "ar") : Locale(identifier: "en")
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
            return LinearGradient(colors: [Color.black, Color(white: 0.12)], startPoint: .top, endPoint: .bottom)
        case .midnight:
            return LinearGradient(colors: [Color(red: 0.05, green: 0.08, blue: 0.16), Color.black], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .ocean:
            return LinearGradient(colors: [Color(red: 0.04, green: 0.24, blue: 0.38), Color(red: 0.01, green: 0.09, blue: 0.18)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .emerald:
            return LinearGradient(colors: [Color(red: 0.04, green: 0.28, blue: 0.20), Color(red: 0.01, green: 0.10, blue: 0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .sand:
            return LinearGradient(colors: [Color(red: 0.42, green: 0.31, blue: 0.18), Color(red: 0.16, green: 0.11, blue: 0.05)], startPoint: .top, endPoint: .bottom)
        case .plum:
            return LinearGradient(colors: [Color(red: 0.28, green: 0.11, blue: 0.24), Color(red: 0.09, green: 0.03, blue: 0.09)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .graphite:
            return LinearGradient(colors: [Color(red: 0.22, green: 0.24, blue: 0.27), Color(red: 0.08, green: 0.09, blue: 0.11)], startPoint: .top, endPoint: .bottom)
        case .auto:
            return LinearGradient(colors: [Color.black, Color(white: 0.12)], startPoint: .top, endPoint: .bottom)
        }
    }

    static func prayerTimes(for date: Date, latitude: Double, longitude: Double) -> [(String, Date)] {
        guard let times = SolarPrayerCalculator.compute(for: date, latitude: latitude, longitude: longitude) else {
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
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&current=temperature_2m,weathercode&daily=temperature_2m_max,temperature_2m_min&timezone=auto"
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (bytes, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: bytes)
            guard let current = decoded.current else { return nil }
            let meta = condition(for: current.weathercode)
            let high = decoded.daily?.temperature_2m_max?.first
            let low = decoded.daily?.temperature_2m_min?.first
            return WeatherSnapshot(symbol: meta.symbol, label: meta.label, tempC: current.temperature_2m, highC: high, lowC: low)
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
        formatter.locale = resolvedLanguage(language) == .arabic ? Locale(identifier: "ar") : Locale(identifier: "en")
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        return formatter.string(from: date)
    }

    static func monthName(_ date: Date, language: WidgetLanguage) -> String {
        let formatter = DateFormatter()
        formatter.locale = resolvedLanguage(language) == .arabic ? Locale(identifier: "ar") : Locale(identifier: "en")
        formatter.setLocalizedDateFormatFromTemplate("MMMM")
        return formatter.string(from: date)
    }

    static func weekdayNameFull(_ date: Date, language: WidgetLanguage) -> String {
        let formatter = DateFormatter()
        formatter.locale = resolvedLanguage(language) == .arabic ? Locale(identifier: "ar") : Locale(identifier: "en")
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
        formatter.locale = resolvedLanguage(language) == .arabic ? Locale(identifier: "ar") : Locale(identifier: "en")
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

    static func hijriDayNumber(_ date: Date, digits: WidgetDigits, language: WidgetLanguage) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .islamicUmmAlQura)
        formatter.locale = Locale(identifier: "en")
        formatter.dateFormat = "d"
        let raw = formatter.string(from: date)
        return resolvedDigits(digits, language: language) == .arabic ? toArabicDigits(raw) : raw
    }

    static func hijriYearNumber(_ date: Date, digits: WidgetDigits, language: WidgetLanguage) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .islamicUmmAlQura)
        formatter.locale = Locale(identifier: "en")
        formatter.dateFormat = "yyyy"
        let raw = formatter.string(from: date)
        return resolvedDigits(digits, language: language) == .arabic ? toArabicDigits(raw) : raw
    }

    // Qibla bearing from coords to Kaaba (21.4225°N, 39.8262°E)
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
// MARK: - Solar Prayer Calculator (unchanged)
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
        let equation = 229.18 * (0.000075 + 0.001868 * cos(gamma) - 0.032077 * sin(gamma) - 0.014615 * cos(2 * gamma) - 0.040849 * sin(2 * gamma))
        let declination = 0.006918 - 0.399912 * cos(gamma) + 0.070257 * sin(gamma) - 0.006758 * cos(2 * gamma) + 0.000907 * sin(2 * gamma) - 0.002697 * cos(3 * gamma) + 0.00148 * sin(3 * gamma)

        let tz = TimeZone.current
        let tzOffset = Double(tz.secondsFromGMT(for: day)) / 60.0
        let noon = 720.0 - 4.0 * longitude - equation + tzOffset

        guard let sunriseHA = hourAngle(latitude: latitude, declination: declination, zenithDegrees: 90.833) else { return nil }

        let sunrise = noon - 4.0 * sunriseHA
        let sunset = noon + 4.0 * sunriseHA

        let fajrHA = hourAngle(latitude: latitude, declination: declination, zenithDegrees: 108.0)
        let ishaHA = hourAngle(latitude: latitude, declination: declination, zenithDegrees: 107.0)

        let fajr = (fajrHA.map { noon - 4.0 * $0 }) ?? (sunrise - 90.0)
        let isha = (ishaHA.map { noon + 4.0 * $0 }) ?? (sunset + 90.0)

        let latRad = latitude * .pi / 180.0
        let shadowAngle = atan(1.0 / (1.0 + tan(abs(latRad - declination))))
        let asrZenith = 90.0 - shadowAngle * 180.0 / .pi
        let asrHA = hourAngle(latitude: latitude, declination: declination, zenithDegrees: asrZenith)
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

    private static func hourAngle(latitude: Double, declination: Double, zenithDegrees: Double) -> Double? {
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
// MARK: - Enums (WidgetFace uitgebreid met 10 nieuwe cases)
// ─────────────────────────────────────────────────────────────────

enum WidgetFace: String, AppEnum {
    // Bestaande cases — NIET gewijzigd
    case clock
    case date
    case weather

    // ── Nieuwe kleine widget stijlen ──────────────────────────────
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

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Widget Type"
    static var caseDisplayRepresentations: [WidgetFace: DisplayRepresentation] = [
        .clock:          "Clock",
        .date:           "Date",
        .weather:        "Weather",
        .minimalist:     "Minimalist",
        .gradientRing:   "Gradient Ring",
        .retroNeon:      "Retro Neon",
        .geometric:      "Geometric",
        .luxuryGold:     "Luxury Gold",
        .midnight:       "Midnight",
        .prayerProgress: "Prayer Progress",
        .qiblaCompass:   "Qibla Compass",
        .currentWeather: "Current Weather",
        .compactWeather: "Compact Weather",
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
        .auto:            "Auto",
        .gregorianArabic: "٢٠٢٦ / ٠٤ / ٠٧",
        .hijriArabic:     "١٤٤٧ / ١٠ / ١٩",
        .gregorianEnglish: "07 / 04 / 2026",
        .hijriEnglish:    "19 / 10 / 1447",
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
        .auto:     "Auto",
        .black:    "Black",
        .midnight: "Midnight",
        .ocean:    "Ocean",
        .emerald:  "Emerald",
        .sand:     "Sand",
        .plum:     "Plum",
        .graphite: "Graphite",
    ]
}

// ─────────────────────────────────────────────────────────────────
// MARK: - Intent / Entry / Provider (ongewijzigd)
// ─────────────────────────────────────────────────────────────────

struct NoorWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Noor Time Widget"
    static var description = IntentDescription("Choose widget style, digits, language, calendar, background and date format.")

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

struct NoorWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> NoorWidgetEntry {
        NoorWidgetEntry(date: .now, configuration: NoorWidgetIntent(), weather: nil, prayerTimes: [])
    }

    func snapshot(for configuration: NoorWidgetIntent, in context: Context) async -> NoorWidgetEntry {
        await makeEntry(configuration: configuration)
    }

    func timeline(for configuration: NoorWidgetIntent, in context: Context) async -> Timeline<NoorWidgetEntry> {
        let defaults = NoorWidgetShared.defaults
        let lat = defaults.double(forKey: "noor.lastLatitude")
        let lon = defaults.double(forKey: "noor.lastLongitude")
        let effectiveLat = (lat == 0 && lon == 0) ? 52.3676 : lat
        let effectiveLon = (lat == 0 && lon == 0) ? 4.9041 : lon

        // Weer en gebedstijden één keer ophalen — geldt voor alle entries
        let weather = await NoorWidgetShared.fetchWeather(latitude: effectiveLat, longitude: effectiveLon)
        let prayers = NoorWidgetShared.prayerTimes(for: .now, latitude: effectiveLat, longitude: effectiveLon)

        // 60 entries — één per minuut — zodat analoge wijzers elke
        // minuut één stap verder draaien. iOS toont de entry waarvan
        // entry.date <= huidige tijd en de volgende entry nog niet geldt.
        let cal = Calendar.current
        let now = cal.date(bySetting: .second, value: 0,
                           of: cal.date(bySetting: .nanosecond, value: 0, of: .now) ?? .now) ?? .now

        let entries: [NoorWidgetEntry] = (0..<60).map { minute in
            let entryDate = cal.date(byAdding: .minute, value: minute, to: now) ?? now
            return NoorWidgetEntry(
                date: entryDate,
                configuration: configuration,
                weather: weather,
                prayerTimes: prayers
            )
        }

        // Na 60 minuten opnieuw genereren (verse weer- en gebedstijden)
        let reload = cal.date(byAdding: .minute, value: 60, to: now) ?? now.addingTimeInterval(3600)
        return Timeline(entries: entries, policy: .after(reload))
    }

    private func makeEntry(configuration: NoorWidgetIntent) async -> NoorWidgetEntry {
        let defaults = NoorWidgetShared.defaults
        let lat = defaults.double(forKey: "noor.lastLatitude")
        let lon = defaults.double(forKey: "noor.lastLongitude")
        let effectiveLat = (lat == 0 && lon == 0) ? 52.3676 : lat
        let effectiveLon = (lat == 0 && lon == 0) ? 4.9041 : lon

        let weather = await NoorWidgetShared.fetchWeather(latitude: effectiveLat, longitude: effectiveLon)
        let prayers = NoorWidgetShared.prayerTimes(for: .now, latitude: effectiveLat, longitude: effectiveLon)

        return NoorWidgetEntry(date: .now, configuration: configuration, weather: weather, prayerTimes: prayers)
    }
}

// ─────────────────────────────────────────────────────────────────
// MARK: - OpenMeteoResponse / WeatherSnapshot (ongewijzigd)
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
// MARK: - NoorConfigurableWidgetView (medium/large — ongewijzigd)
// ─────────────────────────────────────────────────────────────────

struct NoorConfigurableWidgetView: View {
    var entry: NoorWidgetEntry

    var body: some View {
        ZStack {
            switch entry.configuration.face {
            case .clock:
                clockBody
            case .date:
                dateBody
            case .weather:
                weatherBody
            default:
                clockBody   // fallback voor medium/large bij nieuwe cases
            }
        }
        .containerBackground(for: .widget) {
            NoorWidgetShared.widgetBackground(for: entry.configuration.background)
        }
    }

    private var clockBody: some View {
        VStack(spacing: 6) {
            Text(NoorWidgetShared.formatTime(entry.date, language: entry.configuration.language, digits: entry.configuration.digits))
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            let dateText = NoorWidgetShared.formatDate(entry.date, language: entry.configuration.language, digits: entry.configuration.digits, calendar: entry.configuration.calendar, format: entry.configuration.dateFormat)
            if !dateText.isEmpty {
                Text(dateText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .padding(14)
    }

    private var dateBody: some View {
        VStack(spacing: 8) {
            Text(NoorWidgetShared.formatDate(entry.date, language: entry.configuration.language, digits: entry.configuration.digits, calendar: entry.configuration.calendar, format: entry.configuration.dateFormat))
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(12)
    }

    private var weatherBody: some View {
        let resolvedLanguage = NoorWidgetShared.resolvedLanguage(entry.configuration.language)
        return VStack(spacing: 6) {
            if let weather = entry.weather {
                Image(systemName: weather.symbol)
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(.white)
                let temperatureText = "\(Int(weather.tempC.rounded()))"
                Text((NoorWidgetShared.resolvedDigits(entry.configuration.digits, language: entry.configuration.language) == .arabic ? NoorWidgetShared.toArabicDigits(temperatureText) : temperatureText) + "°")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(.yellow)
                Text(resolvedLanguage == .arabic ? localizedConditionArabic(weather.label) : weather.label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            } else {
                Text("--")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
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
// MARK: - NoorSmallWidgetView  ← HIER ZIJN ALLE WIJZIGINGEN
// ─────────────────────────────────────────────────────────────────

struct NoorSmallWidgetView: View {
    let entry: NoorWidgetEntry

    var body: some View {
        ZStack {
            switch entry.configuration.face {

            // ── Bestaande 3 cases (ongewijzigd) ──────────────────
            case .clock:
                smallClockBody
            case .date:
                smallDateBody
            case .weather:
                smallWeatherBody

            // ── 6 nieuwe analoog-stijl klokken ───────────────────
            case .minimalist:
                SmallMinimalistBody(entry: entry)
            case .gradientRing:
                SmallGradientRingBody(entry: entry)
            case .retroNeon:
                SmallRetroNeonBody(entry: entry)
            case .geometric:
                SmallGeometricBody(entry: entry)
            case .luxuryGold:
                SmallLuxuryGoldBody(entry: entry)
            case .midnight:
                SmallMidnightBody(entry: entry)

            // ── 2 nieuwe gebedstijden kaartjes ────────────────────
            case .prayerProgress:
                SmallPrayerProgressBody(entry: entry)
            case .qiblaCompass:
                SmallQiblaCompassBody(entry: entry)

            // ── 2 nieuwe weer-stijlen ─────────────────────────────
            case .currentWeather:
                SmallCurrentWeatherBody(entry: entry)
            case .compactWeather:
                SmallCompactWeatherBody(entry: entry)
            }
        }
        .containerBackground(for: .widget) {
            NoorWidgetShared.widgetBackground(for: entry.configuration.background)
        }
    }

    // ── Bestaande private vars (ongewijzigd) ──────────────────────

    private var smallDateBody: some View {
        Group {
            if entry.configuration.calendar == .hijri {
                hijriDateBody
            } else {
                gregorianDateBody
            }
        }
    }

    private var hijriDateBody: some View {
        let resolvedLanguage = NoorWidgetShared.resolvedLanguage(entry.configuration.language)
        return VStack(spacing: 6) {
            Text(NoorWidgetShared.dayNumber(entry.date, digits: entry.configuration.digits, language: entry.configuration.language))
                .font(.custom("DecoType Thuluth", size: 56))
                .foregroundStyle(.yellow)
                .shadow(color: Color.yellow.opacity(0.3), radius: 6)
            Text(NoorWidgetShared.shortMonth(entry.date, language: entry.configuration.language).uppercased())
                .font(.custom("DecoType Thuluth", size: 16))
                .foregroundStyle(.white)
            Text(NoorWidgetShared.hijriDayNumber(entry.date, digits: entry.configuration.digits, language: entry.configuration.language) + " " + NoorWidgetShared.hijriMonthName(entry.date, language: resolvedLanguage))
                .font(.custom("DecoType Thuluth", size: 14))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
    }

    private var gregorianDateBody: some View {
        let resolvedLanguage = NoorWidgetShared.resolvedLanguage(entry.configuration.language)
        return VStack(spacing: 10) {
            Text(NoorWidgetShared.weekdayNameFull(entry.date, language: resolvedLanguage).uppercased())
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(NoorWidgetShared.dayNumber(entry.date, digits: entry.configuration.digits, language: entry.configuration.language))
                .font(.system(size: 76, weight: .heavy, design: .rounded))
                .foregroundStyle(.yellow)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(NoorWidgetShared.monthName(entry.date, language: resolvedLanguage).uppercased())
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(NoorWidgetShared.yearNumber(entry.date, digits: entry.configuration.digits, language: entry.configuration.language))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 12)
    }

    private var smallClockBody: some View {
        VStack(spacing: 10) {
            Text(NoorWidgetShared.formatTime(entry.date, language: entry.configuration.language, digits: entry.configuration.digits))
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(NoorWidgetShared.formatDate(entry.date, language: entry.configuration.language, digits: entry.configuration.digits, calendar: entry.configuration.calendar, format: entry.configuration.dateFormat))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(12)
    }

    private var smallWeatherBody: some View {
        let resolvedLanguage = NoorWidgetShared.resolvedLanguage(entry.configuration.language)
        return VStack(spacing: 6) {
            if let weather = entry.weather {
                Image(systemName: weather.symbol)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(.white)
                let temperatureText = "\(Int(weather.tempC.rounded()))"
                Text((NoorWidgetShared.resolvedDigits(entry.configuration.digits, language: entry.configuration.language) == .arabic ? NoorWidgetShared.toArabicDigits(temperatureText) : temperatureText) + "°")
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundStyle(.yellow)
                Text(resolvedLanguage == .arabic ? localizedConditionArabic(weather.label) : weather.label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
            } else {
                Text("--")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
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
// MARK: - Gedeelde helper: wijzerhoeken berekenen vanuit Date
// Widgets hebben geen TimelineView, dus we lezen entry.date direct.
// ─────────────────────────────────────────────────────────────────
private func widgetClockAngles(from date: Date) -> (hour: Double, minute: Double, second: Double) {
    let c = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
    let h = Double(c.hour ?? 0)
    let m = Double(c.minute ?? 0)
    let s = Double(c.second ?? 0)
    let preciseMin  = m + s / 60
    let preciseHour = (h.truncatingRemainder(dividingBy: 12)) + preciseMin / 60
    return (preciseHour / 12 * 360, preciseMin / 60 * 360, s / 60 * 360)
}

// Gedeelde capsule-wijzer (zelfde patroon als ContentView HandShape)
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
// MARK: - 1. Minimalist  (analoge klok)
// Strak, dunne ticks, witte wijzers, gouden secondewijzer
// ─────────────────────────────────────────────────────────────────
private struct SmallMinimalistBody: View {
    let entry: NoorWidgetEntry

    var body: some View {
        let angles = widgetClockAngles(from: entry.date)
        let size: CGFloat = 130

        ZStack {
            // Wijzerplaat achtergrond
            Circle()
                .fill(Color.black.opacity(0.0))   // transparant — containerBackground zorgt voor kleur
                .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))

            // Minuut-ticks (60x)
            ForEach(0..<60) { i in
                let isHour = i % 5 == 0
                Rectangle()
                    .fill(Color.white.opacity(isHour ? 0.85 : 0.25))
                    .frame(width: isHour ? 2 : 1, height: isHour ? 10 : 5)
                    .offset(y: -(size / 2 - 14))
                    .rotationEffect(.degrees(Double(i) * 6))
            }

            // Uurwijzer — dik, wit
            WidgetHand(length: size * 0.30, width: 4, color: .white, angleDeg: angles.hour)
            // Minuutwijzer — iets dunner
            WidgetHand(length: size * 0.42, width: 2.5, color: .white.opacity(0.85), angleDeg: angles.minute)
            // Secondewijzer — goud
            WidgetHand(length: size * 0.46, width: 1.5, color: .yellow, angleDeg: angles.second)
                .shadow(color: .yellow.opacity(0.5), radius: 3)

            // Middelpunt
            Circle().fill(Color.yellow).frame(width: 6, height: 6)
                .overlay(Circle().stroke(Color.black, lineWidth: 1))
        }
        .frame(width: size, height: size)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// ─────────────────────────────────────────────────────────────────
// MARK: - 2. Gradient Ring  (analoge klok)
// Angular gouden gradient-ring, dot-markers, wijzers
// ─────────────────────────────────────────────────────────────────
private struct SmallGradientRingBody: View {
    let entry: NoorWidgetEntry

    var body: some View {
        let angles = widgetClockAngles(from: entry.date)
        let size: CGFloat = 130

        ZStack {
            // Gouden angular gradient ring
            Circle()
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.yellow,
                            Color.white.opacity(0.7),
                            Color.yellow.opacity(0.3),
                            Color.yellow
                        ]),
                        center: .center
                    ),
                    lineWidth: 7
                )
                .padding(4)

            // Binnenste subtiele ring
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                .padding(14)

            // Dot-markers (12x)
            ForEach(0..<12) { i in
                let isMajor = i % 3 == 0
                Circle()
                    .fill(Color.white.opacity(isMajor ? 0.85 : 0.35))
                    .frame(width: isMajor ? 5 : 3, height: isMajor ? 5 : 3)
                    .offset(y: -(size / 2 - 22))
                    .rotationEffect(.degrees(Double(i) * 30))
            }

            // Wijzers
            WidgetHand(length: size * 0.28, width: 5, color: .white, angleDeg: angles.hour)
            WidgetHand(length: size * 0.40, width: 3, color: .white.opacity(0.8), angleDeg: angles.minute)
            WidgetHand(length: size * 0.44, width: 2, color: .yellow, angleDeg: angles.second)

            Circle().fill(Color.white).frame(width: 8, height: 8)
                .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
        }
        .frame(width: size, height: size)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// ─────────────────────────────────────────────────────────────────
// MARK: - 3. Retro Neon  (analoge klok)
// Gele neon-rand, cijfers 1–12, gouden secondewijzer met glow
// ─────────────────────────────────────────────────────────────────
private struct SmallRetroNeonBody: View {
    let entry: NoorWidgetEntry

    private let neon = Color.yellow

    var body: some View {
        let angles = widgetClockAngles(from: entry.date)
        let size: CGFloat = 128

        ZStack {
            // Neon-rand
            Circle()
                .stroke(neon.opacity(0.75), lineWidth: 2)
                .shadow(color: neon.opacity(0.5), radius: 6)

            // Cijfers 1–12
            ForEach(1...12, id: \.self) { i in
                Text("\(i)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(neon.opacity(0.8))
                    .offset(y: -(size / 2 - 22))
                    .rotationEffect(.degrees(Double(i) * 30))
                    // tegenrotatie zodat cijfers rechtop staan
                    .rotationEffect(.degrees(-Double(i) * 30), anchor: .center)
                    // correctie: roteer het label terug rond het middelpunt
                    .rotationEffect(.degrees(Double(i) * 30), anchor: .center)
            }

            // Wijzers
            WidgetHand(length: size * 0.28, width: 4, color: .white, angleDeg: angles.hour)
            WidgetHand(length: size * 0.40, width: 2.5, color: .white.opacity(0.9), angleDeg: angles.minute)
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

// ─────────────────────────────────────────────────────────────────
// MARK: - 4. Geometric  (analoge klok)
// Concentrische zeshoeken, driehoek-markers, gele secondewijzer
// ─────────────────────────────────────────────────────────────────
private struct SmallGeometricBody: View {
    let entry: NoorWidgetEntry

    var body: some View {
        let angles = widgetClockAngles(from: entry.date)
        let size: CGFloat = 130

        ZStack {
            // Concentrische zeshoeken
            ForEach(0..<4) { i in
                SmallHexagon()
                    .stroke(Color.white.opacity(0.10 - Double(i) * 0.02), lineWidth: 1)
                    .padding(CGFloat(i) * 12)
            }

            // Driehoek-markers (12x)
            ForEach(0..<12) { i in
                SmallTriangle()
                    .fill(Color.white.opacity(0.55))
                    .frame(width: 6, height: 8)
                    .offset(y: -(size / 2 - 20))
                    .rotationEffect(.degrees(Double(i) * 30))
            }

            // Wijzers
            WidgetHand(length: size * 0.30, width: 5, color: .white, angleDeg: angles.hour)
            WidgetHand(length: size * 0.42, width: 3, color: .white.opacity(0.8), angleDeg: angles.minute)
            WidgetHand(length: size * 0.46, width: 2, color: .yellow, angleDeg: angles.second)

            Circle().fill(Color.yellow).frame(width: 8, height: 8)
        }
        .frame(width: size, height: size)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Shapes voor Geometric
private struct SmallHexagon: Shape {
    func path(in rect: CGRect) -> Path {
        let cx = rect.midX, cy = rect.midY
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

// ─────────────────────────────────────────────────────────────────
// MARK: - 5. Luxury Gold  (analoge klok)
// Gouden rand, Romeinse cijfers, gouden uurwijzer + minuutwijzer,
// witte secondewijzer
// ─────────────────────────────────────────────────────────────────
private struct SmallLuxuryGoldBody: View {
    let entry: NoorWidgetEntry

    private let romanNumerals = ["XII","I","II","III","IV","V","VI","VII","VIII","IX","X","XI"]

    var body: some View {
        let angles = widgetClockAngles(from: entry.date)
        let size: CGFloat = 130

        ZStack {
            // Gouden buitenrand
            Circle()
                .stroke(Color.yellow.opacity(0.55), lineWidth: 2)
            Circle()
                .stroke(Color.yellow.opacity(0.2), lineWidth: 1)
                .padding(8)

            // Romeinse cijfers
            ForEach(0..<12) { i in
                Text(romanNumerals[i])
                    .font(.system(size: 10, weight: .medium, design: .serif))
                    .foregroundStyle(Color.yellow.opacity(0.85))
                    .offset(y: -(size / 2 - 26))
                    .rotationEffect(.degrees(Double(i) * 30))
                    .rotationEffect(.degrees(-Double(i) * 30), anchor: .center)
                    .rotationEffect(.degrees(Double(i) * 30), anchor: .center)
            }

            // Wijzers — uur + minuut goud, seconde wit
            WidgetHand(length: size * 0.27, width: 5, color: .yellow, angleDeg: angles.hour)
            WidgetHand(length: size * 0.38, width: 3, color: .yellow.opacity(0.8), angleDeg: angles.minute)
            WidgetHand(length: size * 0.44, width: 1.5, color: .white, angleDeg: angles.second)

            Circle().fill(Color.yellow).frame(width: 8, height: 8)
                .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
                .shadow(color: .yellow.opacity(0.5), radius: 4)
        }
        .frame(width: size, height: size)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// ─────────────────────────────────────────────────────────────────
// MARK: - 6. Midnight  (analoge klok)
// Radiale gradient achtergrond, subtiele dot-markers,
// halve-cirkel trim die meedraait met secondewijzer als "maan"
// ─────────────────────────────────────────────────────────────────
private struct SmallMidnightBody: View {
    let entry: NoorWidgetEntry

    var body: some View {
        let angles = widgetClockAngles(from: entry.date)
        let size: CGFloat = 130

        ZStack {
            // Radiale achtergrond (donkerder centrum)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(white: 0.12), Color.black],
                        center: .center,
                        startRadius: 10,
                        endRadius: size / 2
                    )
                )
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)

            // Dot-markers (12x)
            ForEach(0..<12) { i in
                Circle()
                    .fill(Color.white.opacity(0.28))
                    .frame(width: 3, height: 3)
                    .offset(y: -(size / 2 - 16))
                    .rotationEffect(.degrees(Double(i) * 30))
            }

            // Maanfase-boog — draait mee met secondewijzer
            Circle()
                .trim(from: 0, to: 0.5)
                .stroke(Color.yellow.opacity(0.35), lineWidth: 2)
                .rotationEffect(.degrees(angles.second))
                .padding(size * 0.12)

            // Wijzers
            WidgetHand(length: size * 0.30, width: 4, color: .white.opacity(0.9), angleDeg: angles.hour)
            WidgetHand(length: size * 0.42, width: 2.5, color: .white.opacity(0.7), angleDeg: angles.minute)
            WidgetHand(length: size * 0.46, width: 1.2, color: .yellow, angleDeg: angles.second)
                .shadow(color: .yellow.opacity(0.4), radius: 3)

            Circle().fill(Color.yellow).frame(width: 5, height: 5)
        }
        .frame(width: size, height: size)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// ─────────────────────────────────────────────────────────────────
// MARK: - 7. Prayer Progress
// Gebaseerd op ContentView: PrayerProgressFace
// Cirkel-ring: gebeden voltooid / 5, volgende gebedstijd
// ─────────────────────────────────────────────────────────────────
private struct SmallPrayerProgressBody: View {
    let entry: NoorWidgetEntry

    // Gebeden zonder Sunrise = 5 verplichte gebeden
    private var obligatoryPrayers: [(String, Date)] {
        entry.prayerTimes.filter { $0.0 != "Sunrise" }
    }

    private var completedCount: Int {
        obligatoryPrayers.filter { $0.1 <= entry.date }.count
    }

    private var nextPrayer: (String, Date)? {
        entry.prayerTimes.first { $0.1 > entry.date }
    }

    private var progress: Double {
        guard obligatoryPrayers.count > 0 else { return 0 }
        return Double(completedCount) / Double(obligatoryPrayers.count)
    }

    private func arabicName(_ english: String) -> String {
        switch english {
        case "Fajr":    return "الفجر"
        case "Dhuhr":   return "الظهر"
        case "Asr":     return "العصر"
        case "Maghrib": return "المغرب"
        case "Isha":    return "العشاء"
        case "Sunrise": return "الشروق"
        default:        return english
        }
    }

    var body: some View {
        ZStack {
            // Achtergrond ring
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 10)
                .padding(10)

            // Voortgang ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color.yellow,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .padding(10)

            VStack(spacing: 2) {
                // Score
                Text("\(completedCount)/5")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                // Volgende gebedsnaam
                if let next = nextPrayer {
                    let isArabic = NoorWidgetShared.resolvedLanguage(entry.configuration.language) == .arabic
                    Text(isArabic ? arabicName(next.0) : next.0)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.yellow)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } else {
                    Text("الحمد لله")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.yellow.opacity(0.8))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(8)
    }
}

// ─────────────────────────────────────────────────────────────────
// MARK: - 8. Qibla Compass
// Gebaseerd op ContentView: QiblaFacePreview
// Kompas met pijl naar Kaaba + graden
// ─────────────────────────────────────────────────────────────────
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
                // Kompas ticks
                ForEach(0..<12) { i in
                    Capsule()
                        .fill(i == 0 ? Color.yellow : Color.white.opacity(0.3))
                        .frame(width: i % 3 == 0 ? 2 : 1, height: i % 3 == 0 ? 8 : 5)
                        .offset(y: -54)
                        .rotationEffect(.degrees(Double(i) * 30))
                }

                // N label
                Text("N")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.yellow)
                    .offset(y: -40)

                // Qibla pijl
                VStack(spacing: 0) {
                    Image(systemName: "arrowtriangle.up.fill")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(.yellow)
                        .shadow(color: .yellow.opacity(0.5), radius: 5)
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 5, height: 5)
                }
                .rotationEffect(.degrees(dir))

                // Graden onderaan
                VStack {
                    Spacer()
                    Text("\(Int(dir.rounded()))°")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("QIBLA")
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .tracking(1.5)
                }
                .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // Geen locatie beschikbaar
            VStack(spacing: 6) {
                Image(systemName: "location.slash")
                    .font(.system(size: 24))
                    .foregroundStyle(.white.opacity(0.4))
                Text("Set Location")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(14)
        }
    }
}

// ─────────────────────────────────────────────────────────────────
// MARK: - 9. Current Weather
// Gebaseerd op ContentView: WeatherSimpleFace
// Icoon groot, temperatuur, conditie, H/L
// ─────────────────────────────────────────────────────────────────
private struct SmallCurrentWeatherBody: View {
    let entry: NoorWidgetEntry

    var body: some View {
        VStack(spacing: 5) {
            if let weather = entry.weather {
                Image(systemName: weather.symbol)
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.white)

                let tempText = "\(Int(weather.tempC.rounded()))"
                let displayTemp = NoorWidgetShared.resolvedDigits(
                    entry.configuration.digits,
                    language: entry.configuration.language
                ) == .arabic
                    ? NoorWidgetShared.toArabicDigits(tempText)
                    : tempText

                Text(displayTemp + "°")
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundStyle(.yellow)

                Text(NoorWidgetShared.resolvedLanguage(entry.configuration.language) == .arabic
                     ? localizedConditionArabic(weather.label)
                     : weather.label)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                // H / L temperatuur
                if let high = weather.highC, let low = weather.lowC {
                    HStack(spacing: 8) {
                        Label(
                            "\(Int(high.rounded()))°",
                            systemImage: "arrow.up"
                        )
                        Label(
                            "\(Int(low.rounded()))°",
                            systemImage: "arrow.down"
                        )
                    }
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                }
            } else {
                Image(systemName: "cloud.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.4))
                Text("--")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(10)
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
// MARK: - 10. Compact Weather
// Gebaseerd op ContentView: WeatherCompactFace
// Links-uitgelijnd: icoon + locatie bovenaan, temp groot, H/L klein
// ─────────────────────────────────────────────────────────────────
private struct SmallCompactWeatherBody: View {
    let entry: NoorWidgetEntry

    private var locationName: String {
        NoorWidgetShared.defaults.string(forKey: "noor.lastLocationName") ?? "—"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Rij 1: icoon + locatienaam
            HStack(spacing: 5) {
                if let weather = entry.weather {
                    Image(systemName: weather.symbol)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.white.opacity(0.85))
                }
                Text(locationName)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.bottom, 6)

            Spacer()

            // Temperatuur groot
            if let weather = entry.weather {
                let tempText = "\(Int(weather.tempC.rounded()))"
                let displayTemp = NoorWidgetShared.resolvedDigits(
                    entry.configuration.digits,
                    language: entry.configuration.language
                ) == .arabic
                    ? NoorWidgetShared.toArabicDigits(tempText)
                    : tempText

                Text(displayTemp + "°")
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .foregroundStyle(.yellow)

                // H / L
                if let high = weather.highC, let low = weather.lowC {
                    Text("H:\(Int(high.rounded()))°  L:\(Int(low.rounded()))°")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                        .padding(.top, 2)
                }
            } else {
                Text("--")
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(14)
    }
}

// ─────────────────────────────────────────────────────────────────
// MARK: - Widget definities
// NoorSmallWidget  → uitgebreid met nieuwe face-cases
// NoorMediumWidget → ONGEWIJZIGD
// NoorLargeWidget  → ONGEWIJZIGD
// ─────────────────────────────────────────────────────────────────

struct NoorSmallWidget: Widget {
    let kind: String = "NoorSmallWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: NoorWidgetIntent.self, provider: NoorWidgetProvider()) { entry in
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
        AppIntentConfiguration(kind: kind, intent: NoorWidgetIntent.self, provider: NoorWidgetProvider()) { entry in
            NoorConfigurableWidgetView(entry: entry)
        }
        .configurationDisplayName("Noor Time Medium")
        .description("Medium Noor widget with clock, date or weather.")
        .supportedFamilies([.systemMedium])
    }
}

struct NoorLargeWidget: Widget {
    let kind: String = "NoorLargeWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: NoorWidgetIntent.self, provider: NoorWidgetProvider()) { entry in
            NoorConfigurableWidgetView(entry: entry)
        }
        .configurationDisplayName("Noor Time Large")
        .description("Large Noor widget with clock, date or weather.")
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
