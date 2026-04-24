//
//  ContentView.swift
//  Noor Time
//
//  Created by Intern on 02/04/2026.
//

import Combine
import SwiftUI

#if os(iOS)
    import CoreLocation
    import UIKit
#endif

// MARK: - Noor Support Types

struct NoorSharedDefaults {
    static let shared: UserDefaults = {
        if let defaults = UserDefaults(suiteName: "group.noortime") {
            return defaults
        }
        return .standard
    }()
}

enum NoorSharedKeys {
    static let timeFormat = "noor.timeFormat"
    static let calculationMethod = "noor.calculationMethod"
    static let hijriOffset = "noor.hijriOffset"
    static let temperatureUnit = "noor.temperatureUnit"
    static let language = "noor.language"
    static let locationMode = "noor.locationMode"
    static let manualCity = "noor.manualCity"
    static let manualCountry = "noor.manualCountry"
    static let dataSource = "noor.dataSource"

    static let lastLatitude = "noor.lastLatitude"
    static let lastLongitude = "noor.lastLongitude"
    static let lastLocationName = "noor.lastLocationName"
}

enum NoorCalculationMethodKey: String, CaseIterable {
    case muslimWorldLeague
    case isna
    case karachi
    case ummAlQura
    case dubai
    case qatar
    case kuwait
    case jordan
    case egyptian
    case tunisia
    case morocco
    case turkey
    case jafari
}

enum AppLanguage: String, CaseIterable, Equatable {
    case english
    case arabic

    static func resolve(from setting: NoorSettings.Language) -> AppLanguage {
        switch setting {
        case .english: return .english
        case .arabic: return .arabic
        case .auto:
            let preferred = Locale.preferredLanguages.first?.lowercased() ?? ""
            if preferred.hasPrefix("ar") { return .arabic }
            return .english
        }
    }
}

private struct AppLanguageEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppLanguage = .english
}

extension EnvironmentValues {
    var appLanguage: AppLanguage {
        get { self[AppLanguageEnvironmentKey.self] }
        set { self[AppLanguageEnvironmentKey.self] = newValue }
    }
}

enum AppStrings {
    static func t(_ key: String, _ lang: AppLanguage) -> String {
        // Lightweight fallback localization until a proper strings system is added.
        // If a key isn't known, show a friendly title-cased version.
        if let known = knownStrings[lang]?[key] { return known }
        return key
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "label ", with: "")
            .replacingOccurrences(of: "settings ", with: "")
            .capitalized
    }

    static func locationMode(_ mode: NoorSettings.LocationMode, _ lang: AppLanguage) -> String {
        switch (lang, mode) {
        case (.english, .automatic): return "Automatic"
        case (.english, .manual): return "Manual"
        case (.arabic, .automatic): return "تلقائي"
        case (.arabic, .manual): return "يدوي"
        }
    }

    static func prayerSource(_ source: NoorSettings.PrayerDataSource, _ lang: AppLanguage) -> String {
        switch (lang, source) {
        case (.english, .auto): return "Auto"
        case (.english, .local): return "Local"
        case (.english, .api): return "API"
        case (.arabic, .auto): return "تلقائي"
        case (.arabic, .local): return "محلي"
        case (.arabic, .api): return "واجهة"
        }
    }

    static func languageOption(_ option: NoorSettings.Language, _ lang: AppLanguage) -> String {
        switch (lang, option) {
        case (.english, .auto): return "Automatic"
        case (.english, .english): return "English"
        case (.english, .arabic): return "Arabic"
        case (.arabic, .auto): return "تلقائي"
        case (.arabic, .english): return "الإنجليزية"
        case (.arabic, .arabic): return "العربية"
        }
    }

    private static let knownStrings: [AppLanguage: [String: String]] = [
        .english: [
            "settings_title": "Settings",
            "settings_done": "Done",
            "time_format": "Time Format",
            "calculation_method": "Calculation Method",
            "location": "Location",
            "city": "City",
            "country": "Country",
            "use_location": "Use Location",
            "current_location": "Current location",
            "open_settings": "Open Settings",
            "refresh_location": "Refresh location",
            "prayer_source": "Prayer source",
            "hijri_adjustment": "Hijri adjustment",
            "hijri_note": "This adjusts the Hijri date display.",
            "temperature": "Temperature",
            "language": "Language",
            "app_title": "Noor Time",
            "filter_all": "All",
            "filter_analog": "Analog",
            "filter_digital": "Digital",
            "filter_quran": "Quran",
            "filter_dots": "Dots",
            "filter_date": "Date",
            "filter_prayer": "Prayer",
            "filter_weather": "Weather",
            "label_prayer_times": "Prayer Times",
            "label_next_prayer": "Next Prayer",
            "label_in": "in",
            "label_prayers": "Prayers",
            "label_timeline": "Timeline",
            "location_needed": "Location needed",
        ],
        .arabic: [
            "settings_title": "الإعدادات",
            "settings_done": "تم",
            "time_format": "تنسيق الوقت",
            "calculation_method": "طريقة الحساب",
            "location": "الموقع",
            "city": "المدينة",
            "country": "الدولة",
            "use_location": "استخدم الموقع",
            "current_location": "الموقع الحالي",
            "open_settings": "افتح الإعدادات",
            "refresh_location": "تحديث الموقع",
            "prayer_source": "مصدر المواقيت",
            "hijri_adjustment": "تعديل الهجري",
            "hijri_note": "هذا يغيّر عرض التاريخ الهجري.",
            "temperature": "الطقس",
            "language": "اللغة",
            "app_title": "نور تايم",
            "filter_all": "الكل",
            "filter_analog": "عقارب",
            "filter_digital": "رقمي",
            "filter_quran": "القرآن",
            "filter_dots": "نقاط",
            "filter_date": "تاريخ",
            "filter_prayer": "الصلوات",
            "filter_weather": "الطقس",
            "label_prayer_times": "مواقيت الصلاة",
            "label_next_prayer": "الصلاة القادمة",
            "label_in": "بعد",
            "label_prayers": "صلوات",
            "label_timeline": "الجدول",
            "location_needed": "يلزم تحديد الموقع",
        ],
    ]
}

enum NoorTimeFormatSetting: Equatable {
    case auto
    case twelveHour
    case twentyFourHour

    static func fromStorage(_ raw: String?) -> NoorTimeFormatSetting {
        switch raw {
        case NoorSettings.TimeFormat.twelveHour.rawValue: return .twelveHour
        case NoorSettings.TimeFormat.twentyFourHour.rawValue: return .twentyFourHour
        default: return .auto
        }
    }
}

enum NoorTemperatureUnit: String, CaseIterable, Equatable {
    case celsius
    case fahrenheit

    static func resolve(from setting: NoorSettings.TemperatureUnit) -> NoorTemperatureUnit {
        switch setting {
        case .celsius: return .celsius
        case .fahrenheit: return .fahrenheit
        }
    }
}

enum NoorTemperatureFormatter {
    static func format(_ temperatureC: Double, unit: NoorTemperatureUnit) -> String {
        switch unit {
        case .celsius:
            return "\(Int(temperatureC.rounded()))°C"
        case .fahrenheit:
            let f = temperatureC * 9.0 / 5.0 + 32.0
            return "\(Int(f.rounded()))°F"
        }
    }
}

enum NoorPrayerTimeFormatter {
    static func format(_ date: Date, timeFormat: NoorTimeFormatSetting, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .none
        formatter.timeStyle = .short

        switch timeFormat {
        case .auto:
            break
        case .twelveHour:
            formatter.dateFormat = "h:mm a"
        case .twentyFourHour:
            formatter.dateFormat = "HH:mm"
        }

        return formatter.string(from: date)
    }
}

enum NoorPrayerName: String, CaseIterable, Equatable {
    case fajr
    case sunrise
    case dhuhr
    case asr
    case maghrib
    case isha

    var english: String {
        switch self {
        case .fajr: return "Fajr"
        case .sunrise: return "Sunrise"
        case .dhuhr: return "Dhuhr"
        case .asr: return "Asr"
        case .maghrib: return "Maghrib"
        case .isha: return "Isha"
        }
    }

    var arabic: String {
        switch self {
        case .fajr: return "الفجر"
        case .sunrise: return "الشروق"
        case .dhuhr: return "الظهر"
        case .asr: return "العصر"
        case .maghrib: return "المغرب"
        case .isha: return "العشاء"
        }
    }
}

struct NoorPrayerTime: Identifiable, Hashable {
    let id = UUID()
    let name: NoorPrayerName
    let time: Date
}

struct PrayerTimesData {
    let date: Date
    let times: [NoorPrayerTime]
}

#if os(iOS)
final class PrayerTimesViewModel: NSObject, ObservableObject {
    @Published var data: PrayerTimesData?
    @Published var locationName: String = ""
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var now: Date = .now

    private let settings: NoorSettings
    private let locationManager = CLLocationManager()
    private var cancellables: Set<AnyCancellable> = []


    private func degreesToRadians(_ degrees: Double) -> Double {
        degrees * .pi / 180.0
    }

    private func radiansToDegrees(_ radians: Double) -> Double {
        radians * 180.0 / .pi
    }

    private func minuteOffsetDate(_ minutes: Double, from day: Date, timeZone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let start = calendar.startOfDay(for: day)
        return start.addingTimeInterval(minutes * 60.0)
    }

    private func solarGeometry(
        for day: Date,
        latitude: Double,
        longitude: Double,
        timeZone: TimeZone
    ) -> (declination: Double, equationOfTime: Double, solarNoon: Double)? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        guard let dayOfYear = calendar.ordinality(of: .day, in: .year, for: day) else {
            return nil
        }

        let gamma = 2.0 * Double.pi / 365.0 * (Double(dayOfYear) - 1.0)
        let equationOfTime = 229.18
            * (0.000075
                + 0.001868 * cos(gamma)
                - 0.032077 * sin(gamma)
                - 0.014615 * cos(2.0 * gamma)
                - 0.040849 * sin(2.0 * gamma))
        let declination = 0.006918
            - 0.399912 * cos(gamma)
            + 0.070257 * sin(gamma)
            - 0.006758 * cos(2.0 * gamma)
            + 0.000907 * sin(2.0 * gamma)
            - 0.002697 * cos(3.0 * gamma)
            + 0.00148 * sin(3.0 * gamma)

        let tzOffsetMinutes = Double(timeZone.secondsFromGMT(for: day)) / 60.0
        let solarNoon = 720.0 - 4.0 * longitude - equationOfTime + tzOffsetMinutes
        _ = latitude
        return (declination, equationOfTime, solarNoon)
    }

    private func hourAngleDegrees(
        latitude: Double,
        declination: Double,
        zenithDegrees: Double
    ) -> Double? {
        let latitudeRad = degreesToRadians(latitude)
        let zenithRad = degreesToRadians(zenithDegrees)

        let numerator = cos(zenithRad) - sin(latitudeRad) * sin(declination)
        let denominator = cos(latitudeRad) * cos(declination)
        guard denominator != 0 else { return nil }

        let raw = numerator / denominator
        guard raw >= -1.0, raw <= 1.0 else { return nil }

        return radiansToDegrees(acos(raw))
    }

    private func solarTimeData(
        for day: Date,
        latitude: Double,
        longitude: Double,
        timeZone: TimeZone
    ) -> (fajr: Date, sunrise: Date, dhuhr: Date, asr: Date, maghrib: Date, isha: Date)? {
        guard let geometry = solarGeometry(
            for: day,
            latitude: latitude,
            longitude: longitude,
            timeZone: timeZone
        ) else {
            return nil
        }

        guard let sunriseHA = hourAngleDegrees(
            latitude: latitude,
            declination: geometry.declination,
            zenithDegrees: 90.833
        ) else {
            return nil
        }

        let sunrise = geometry.solarNoon - 4.0 * sunriseHA
        let sunset = geometry.solarNoon + 4.0 * sunriseHA
        let dhuhr = geometry.solarNoon

        let fajrHA = hourAngleDegrees(
            latitude: latitude,
            declination: geometry.declination,
            zenithDegrees: 108.0
        )
        let ishaHA = hourAngleDegrees(
            latitude: latitude,
            declination: geometry.declination,
            zenithDegrees: 107.0
        )

        let fajr = (fajrHA.map { dhuhr - 4.0 * $0 }) ?? (sunrise - 90.0)
        let isha = (ishaHA.map { dhuhr + 4.0 * $0 }) ?? (sunset + 90.0)

        let latitudeRad = degreesToRadians(latitude)
        let shadowAngle = atan(1.0 / (1.0 + tan(abs(latitudeRad - geometry.declination))))
        let asrZenith = 90.0 - radiansToDegrees(shadowAngle)
        let asrHA = hourAngleDegrees(
            latitude: latitude,
            declination: geometry.declination,
            zenithDegrees: asrZenith
        )
        let asr = (asrHA.map { dhuhr + 4.0 * $0 }) ?? ((dhuhr + sunset) / 2.0)

        return (
            fajr: minuteOffsetDate(fajr, from: day, timeZone: timeZone),
            sunrise: minuteOffsetDate(sunrise, from: day, timeZone: timeZone),
            dhuhr: minuteOffsetDate(dhuhr, from: day, timeZone: timeZone),
            asr: minuteOffsetDate(asr, from: day, timeZone: timeZone),
            maghrib: minuteOffsetDate(sunset, from: day, timeZone: timeZone),
            isha: minuteOffsetDate(isha, from: day, timeZone: timeZone)
        )
    }

    init(settings: NoorSettings) {
        self.settings = settings
        super.init()

        locationManager.delegate = self
        authorizationStatus = locationManager.authorizationStatus

        Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] in self?.now = $0 }
            .store(in: &cancellables)

        // Prime from defaults if present (avoids empty UI on first launch).
        let defaults = NoorSharedDefaults.shared
        locationName = defaults.string(forKey: NoorSharedKeys.lastLocationName) ?? ""

        requestLocationIfNeeded()
        refreshIfNeeded(force: true)
    }

    func requestLocationIfNeeded() {
        guard settings.locationMode == .automatic else { return }

        // Avoid a runtime crash if the usage description isn't configured.
        let hasUsage = (Bundle.main.object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") as? String)?.isEmpty == false
        guard hasUsage else { return }

        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.requestLocation()
        default:
            break
        }
    }

    func applyManualLocation() {
        settings.locationMode = .manual

        let city = settings.manualCity.trimmingCharacters(in: .whitespacesAndNewlines)
        let country = settings.manualCountry.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = [city, country].filter { !$0.isEmpty }.joined(separator: ", ")
        locationName = name.isEmpty ? "Manual location" : name

        let defaults = NoorSharedDefaults.shared
        defaults.set(locationName, forKey: NoorSharedKeys.lastLocationName)

        // Best effort geocoding for manual city/country.
        let query = locationName
        Task {
            do {
                let placemarks = try await CLGeocoder().geocodeAddressString(query)
                if let location = placemarks.first?.location {
                    defaults.set(location.coordinate.latitude, forKey: NoorSharedKeys.lastLatitude)
                    defaults.set(location.coordinate.longitude, forKey: NoorSharedKeys.lastLongitude)
                } else {
                    // Fall back to a safe default if we have no coordinates yet.
                    if defaults.double(forKey: NoorSharedKeys.lastLatitude) == 0,
                        defaults.double(forKey: NoorSharedKeys.lastLongitude) == 0
                    {
                        defaults.set(52.3676, forKey: NoorSharedKeys.lastLatitude)
                        defaults.set(4.9041, forKey: NoorSharedKeys.lastLongitude)
                    }
                }
            } catch {
                if defaults.double(forKey: NoorSharedKeys.lastLatitude) == 0,
                    defaults.double(forKey: NoorSharedKeys.lastLongitude) == 0
                {
                    defaults.set(52.3676, forKey: NoorSharedKeys.lastLatitude)
                    defaults.set(4.9041, forKey: NoorSharedKeys.lastLongitude)
                }
            }

            await MainActor.run {
                self.refreshIfNeeded(force: true)
            }
        }
    }


    func refreshIfNeeded(force: Bool) {
        let today = Calendar.current.startOfDay(for: Date())
        if !force, let existing = data, Calendar.current.isDate(existing.date, inSameDayAs: today) {
            return
        }

        let defaults = NoorSharedDefaults.shared
        let lat = defaults.double(forKey: NoorSharedKeys.lastLatitude)
        let lon = defaults.double(forKey: NoorSharedKeys.lastLongitude)

        guard lat != 0 || lon != 0 else {
            data = nil
            requestLocationIfNeeded()
            return
        }

        let timeZone = TimeZone.current
        guard let times = solarTimeData(
            for: today,
            latitude: lat,
            longitude: lon,
            timeZone: timeZone
        ) else {
            data = nil
            return
        }

        data = PrayerTimesData(
            date: today,
            times: [
                .init(name: .fajr, time: times.fajr),
                .init(name: .sunrise, time: times.sunrise),
                .init(name: .dhuhr, time: times.dhuhr),
                .init(name: .asr, time: times.asr),
                .init(name: .maghrib, time: times.maghrib),
                .init(name: .isha, time: times.isha),
            ]
        )
    }

}

extension PrayerTimesViewModel: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        let defaults = NoorSharedDefaults.shared
        defaults.set(location.coordinate.latitude, forKey: NoorSharedKeys.lastLatitude)
        defaults.set(location.coordinate.longitude, forKey: NoorSharedKeys.lastLongitude)

        Task {
            // Best-effort reverse geocode for a friendly label.
            let placemark = (try? await CLGeocoder().reverseGeocodeLocation(location))?.first
            let parts = [placemark?.locality, placemark?.country].compactMap { $0 }.filter { !$0.isEmpty }
            let resolvedName = parts.isEmpty
                ? String(format: "%.3f, %.3f", location.coordinate.latitude, location.coordinate.longitude)
                : parts.joined(separator: ", ")

            defaults.set(resolvedName, forKey: NoorSharedKeys.lastLocationName)

            await MainActor.run {
                self.locationName = resolvedName
                self.refreshIfNeeded(force: true)
            }
        }
    }



    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Ignore for now; UI already handles missing data.
    }
}
#else
final class PrayerTimesViewModel: ObservableObject {
    @Published var data: PrayerTimesData?
    @Published var locationName: String = ""
    @Published var now: Date = .now

    init(settings: NoorSettings) {
        _ = settings
    }

    func requestLocationIfNeeded() {}
    func applyManualLocation() {}
    func refreshIfNeeded(force: Bool) { _ = force }
}
#endif

struct WeatherSnapshot: Equatable {
    let symbolName: String
    let temperatureC: Double
    let condition: String
    let highC: Double?
    let lowC: Double?
}

final class WeatherViewModel: ObservableObject {
    @Published var snapshot: WeatherSnapshot?

    private let settings: NoorSettings

    // MARK: - Weather API (Open-Meteo)
    private struct OpenMeteoResponse: Decodable {
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

    private static func condition(for code: Int) -> (symbol: String, label: String) {
        switch code {
        case 0:
            return ("sun.max.fill", "Clear")
        case 1, 2, 3:
            return ("cloud.sun.fill", "Partly Cloudy")
        case 45, 48:
            return ("cloud.fog.fill", "Fog")
        case 51, 53, 55, 56, 57:
            return ("cloud.drizzle.fill", "Drizzle")
        case 61, 63, 65, 66, 67:
            return ("cloud.rain.fill", "Rain")
        case 71, 73, 75, 77:
            return ("cloud.snow.fill", "Snow")
        case 80, 81, 82:
            return ("cloud.heavyrain.fill", "Showers")
        case 95, 96, 99:
            return ("cloud.bolt.rain.fill", "Thunderstorm")
        default:
            return ("cloud.fill", "Weather")
        }
    }

    init(settings: NoorSettings) {
        self.settings = settings
    }

    var unit: NoorTemperatureUnit {
        NoorTemperatureUnit.resolve(from: settings.temperatureUnit)
    }

    func refreshIfPossible() {
        let defaults = NoorSharedDefaults.shared
        let lat = defaults.double(forKey: NoorSharedKeys.lastLatitude)
        let lon = defaults.double(forKey: NoorSharedKeys.lastLongitude)

        guard lat != 0 || lon != 0 else {
            return
        }

        let urlString =
            "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,weathercode&daily=temperature_2m_max,temperature_2m_min&timezone=auto"

        guard let url = URL(string: urlString) else {
            return
        }

        Task {
            do {
                let (bytes, _) = try await URLSession.shared.data(from: url)
                let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: bytes)

                guard let current = decoded.current else { return }

                let meta = Self.condition(for: current.weathercode)
                let high = decoded.daily?.temperature_2m_max?.first
                let low = decoded.daily?.temperature_2m_min?.first

                let newSnapshot = WeatherSnapshot(
                    symbolName: meta.symbol,
                    temperatureC: current.temperature_2m,
                    condition: meta.label,
                    highC: high,
                    lowC: low
                )

                await MainActor.run {
                    self.snapshot = newSnapshot
                }
            } catch {
                // Keep last snapshot if fetch fails.
            }
        }
    }

}

struct Coordinates: Equatable {
    let latitude: Double
    let longitude: Double
}

struct Qibla {
    let direction: Double

    init(coordinates: Coordinates) {
        // Bearing from current location to the Kaaba.
        // Kaaba coords: 21.4225° N, 39.8262° E
        let kaabaLat = 21.4225
        let kaabaLon = 39.8262

        func deg2rad(_ d: Double) -> Double { d * .pi / 180.0 }
        func rad2deg(_ r: Double) -> Double { r * 180.0 / .pi }

        let lat1 = deg2rad(coordinates.latitude)
        let lon1 = deg2rad(coordinates.longitude)
        let lat2 = deg2rad(kaabaLat)
        let lon2 = deg2rad(kaabaLon)

        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        var bearing = rad2deg(atan2(y, x))
        if bearing < 0 { bearing += 360 }
        direction = bearing
    }
}


// MARK: - App Settings
class NoorSettings: ObservableObject {
    @Published var timeFormat: TimeFormat = .auto
    @Published var calculationMethod: CalculationMethod = .muslimWorldLeague
    @Published var hijriOffset: Int = 0
    @Published var temperatureUnit: TemperatureUnit = .celsius
    @Published var language: Language = .auto
    @Published var locationMode: LocationMode = .automatic
    @Published var manualCity: String = ""
    @Published var manualCountry: String = ""
    @Published var dataSource: PrayerDataSource = .auto

    private var cancellables: Set<AnyCancellable> = []

    init() {
        loadFromDefaults()
        bindToDefaults()
    }

    private func loadFromDefaults() {
        let defaults = NoorSharedDefaults.shared

        if let raw = defaults.string(forKey: NoorSharedKeys.timeFormat),
            let value = TimeFormat(rawValue: raw)
        {
            timeFormat = value
        }
        if let raw = defaults.string(forKey: NoorSharedKeys.calculationMethod),
            let value = CalculationMethod(storageKey: raw)
        {
            calculationMethod = value
        }
        let hijri = defaults.integer(forKey: NoorSharedKeys.hijriOffset)
        if hijri != 0 {
            hijriOffset = hijri
        }
        if let raw = defaults.string(forKey: NoorSharedKeys.temperatureUnit),
            let value = TemperatureUnit(rawValue: raw)
        {
            temperatureUnit = value
        }
        if let raw = defaults.string(forKey: NoorSharedKeys.language),
            let value = Language(rawValue: raw)
        {
            language = value
        }
        if let raw = defaults.string(forKey: NoorSharedKeys.locationMode),
            let value = LocationMode(rawValue: raw)
        {
            locationMode = value
        }
        manualCity = defaults.string(forKey: NoorSharedKeys.manualCity) ?? ""
        manualCountry = defaults.string(forKey: NoorSharedKeys.manualCountry) ?? ""
        if let raw = defaults.string(forKey: NoorSharedKeys.dataSource),
            let value = PrayerDataSource(rawValue: raw)
        {
            dataSource = value
        }
    }

    private func bindToDefaults() {
        let defaults = NoorSharedDefaults.shared
        $timeFormat
            .sink { defaults.set($0.rawValue, forKey: NoorSharedKeys.timeFormat) }
            .store(in: &cancellables)
        $calculationMethod
            .sink { defaults.set($0.storageKey, forKey: NoorSharedKeys.calculationMethod) }
            .store(in: &cancellables)
        $hijriOffset
            .sink { defaults.set($0, forKey: NoorSharedKeys.hijriOffset) }
            .store(in: &cancellables)
        $temperatureUnit
            .sink { defaults.set($0.rawValue, forKey: NoorSharedKeys.temperatureUnit) }
            .store(in: &cancellables)
        $language
            .sink { defaults.set($0.rawValue, forKey: NoorSharedKeys.language) }
            .store(in: &cancellables)
        $locationMode
            .sink { defaults.set($0.rawValue, forKey: NoorSharedKeys.locationMode) }
            .store(in: &cancellables)
        $manualCity
            .sink { defaults.set($0, forKey: NoorSharedKeys.manualCity) }
            .store(in: &cancellables)
        $manualCountry
            .sink { defaults.set($0, forKey: NoorSharedKeys.manualCountry) }
            .store(in: &cancellables)
        $dataSource
            .sink { defaults.set($0.rawValue, forKey: NoorSharedKeys.dataSource) }
            .store(in: &cancellables)
    }

    enum TimeFormat: String, CaseIterable {
        case auto
        case twelveHour
        case twentyFourHour

        func label(_ lang: AppLanguage) -> String {
            switch lang {
            case .english:
                switch self {
                case .auto: return "Automatic"
                case .twelveHour: return "12-hour"
                case .twentyFourHour: return "24-hour"
                }
            case .arabic:
                switch self {
                case .auto: return "تلقائي"
                case .twelveHour: return "12-ساعة"
                case .twentyFourHour: return "24-ساعة"
                }
            }
        }
    }

    enum CalculationMethod: String, CaseIterable {
        case muslimWorldLeague = "Muslim World League"
        case isna = "North America (ISNA)"
        case karachi = "Karachi"
        case ummAlQura = "Umm Al-Qura (Makkah)"
        case dubai = "Dubai"
        case qatar = "Qatar"
        case kuwait = "Kuwait"
        case jordan = "Jordan"
        case egyptian = "Egyptian"
        case tunisia = "Tunisia"
        case morocco = "Morocco"
        case turkey = "Turkey (Diyanet)"
        case jafari = "Jafari"

        var storageKey: String { methodKey.rawValue }

        init?(storageKey: String) {
            switch storageKey {
            case NoorCalculationMethodKey.muslimWorldLeague.rawValue: self = .muslimWorldLeague
            case NoorCalculationMethodKey.isna.rawValue: self = .isna
            case NoorCalculationMethodKey.karachi.rawValue: self = .karachi
            case NoorCalculationMethodKey.ummAlQura.rawValue: self = .ummAlQura
            case NoorCalculationMethodKey.dubai.rawValue: self = .dubai
            case NoorCalculationMethodKey.qatar.rawValue: self = .qatar
            case NoorCalculationMethodKey.kuwait.rawValue: self = .kuwait
            case NoorCalculationMethodKey.jordan.rawValue: self = .jordan
            case NoorCalculationMethodKey.egyptian.rawValue: self = .egyptian
            case NoorCalculationMethodKey.tunisia.rawValue: self = .tunisia
            case NoorCalculationMethodKey.morocco.rawValue: self = .morocco
            case NoorCalculationMethodKey.turkey.rawValue: self = .turkey
            case NoorCalculationMethodKey.jafari.rawValue: self = .jafari
            default: return nil
            }
        }

        var methodKey: NoorCalculationMethodKey {
            switch self {
            case .muslimWorldLeague: return .muslimWorldLeague
            case .isna: return .isna
            case .karachi: return .karachi
            case .ummAlQura: return .ummAlQura
            case .dubai: return .dubai
            case .qatar: return .qatar
            case .kuwait: return .kuwait
            case .jordan: return .jordan
            case .egyptian: return .egyptian
            case .tunisia: return .tunisia
            case .morocco: return .morocco
            case .turkey: return .turkey
            case .jafari: return .jafari
            }
        }

        func label(_ lang: AppLanguage) -> String {
            switch lang {
            case .english:
                return rawValue
            case .arabic:
                switch self {
                case .muslimWorldLeague: return "رابطة العالم الإسلامي"
                case .isna: return "أمريكا الشمالية (ISNA)"
                case .karachi: return "كراتشي"
                case .ummAlQura: return "أم القرى (مكة)"
                case .dubai: return "دبي"
                case .qatar: return "قطر"
                case .kuwait: return "الكويت"
                case .jordan: return "الأردن"
                case .egyptian: return "المصري"
                case .tunisia: return "تونس"
                case .morocco: return "المغرب"
                case .turkey: return "تركيا (ديانت)"
                case .jafari: return "جعفري"
                }
            }
        }
    }

    enum TemperatureUnit: String, CaseIterable {
        case celsius = "°C"
        case fahrenheit = "°F"
    }

    enum Language: String, CaseIterable {
        case auto = "Automatic"
        case english = "English"
        case arabic = "Arabic"
        var label: String { rawValue }
    }

    enum LocationMode: String, CaseIterable {
        case automatic
        case manual
    }

    enum PrayerDataSource: String, CaseIterable {
        case auto
        case local
        case api
    }
}

// MARK: - Noor Design System
struct NoorDesignSystem {
    static let backgroundDeep = Color.black.opacity(0.95)
    static let backgroundElevated = Color.white.opacity(0.06)
    static let accentGold = Color.yellow
    static let accentGoldMuted = Color.yellow.opacity(0.7)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let textTertiary = Color.white.opacity(0.5)
    static let strokeSubtle = Color.white.opacity(0.08)
    static let strokeStrong = Color.white.opacity(0.15)

    static let hourHandColor = Color.white
    static let minuteHandColor = Color(red: 0.85, green: 0.85, blue: 0.95)
    static let secondHandColor = Color.yellow

    static let dialGradient = RadialGradient(
        colors: [backgroundDeep, Color.black.opacity(0.8)],
        center: .center,
        startRadius: 2,
        endRadius: 120
    )

    static let glossGradient = LinearGradient(
        colors: [Color.white.opacity(0.18), .clear],
        startPoint: .top,
        endPoint: .bottom
    )

    static let shadowDeep = ShadowStyle(color: .black.opacity(0.6), radius: 24, x: 0, y: 12)
    static let shadowInner = ShadowStyle(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)

    static func titleSmall() -> Font { .system(size: 12, weight: .bold, design: .rounded) }
    static func titleMedium() -> Font { .system(size: 14, weight: .semibold, design: .rounded) }
    static func numberLarge() -> Font { .system(size: 48, weight: .heavy, design: .rounded) }

    static let animationSnappy = Animation.spring(response: 0.3, dampingFraction: 0.7)
    static let animationSmooth = Animation.easeInOut(duration: 0.2)
}

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Settings Sheet
struct SettingsSheet: View {
    @ObservedObject var settings: NoorSettings
    @EnvironmentObject private var prayerModel: PrayerTimesViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private var appLanguage: AppLanguage {
        AppLanguage.resolve(from: settings.language)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {

                        // Time Format
                        SettingsSection(
                            title: AppStrings.t("time_format", appLanguage), icon: "clock"
                        ) {
                            HStack(spacing: 0) {
                                ForEach(NoorSettings.TimeFormat.allCases, id: \.self) { format in
                                    let isSelected = settings.timeFormat == format
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3)) {
                                            settings.timeFormat = format
                                        }
                                    }) {
                                        Text(format.label(appLanguage))
                                            .font(
                                                .system(size: 14, weight: .bold, design: .rounded)
                                            )
                                            .foregroundStyle(
                                                isSelected ? .black : .white.opacity(0.6)
                                            )
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(isSelected ? Color.yellow : Color.clear)
                                            .clipShape(
                                                RoundedRectangle(
                                                    cornerRadius: 10, style: .continuous))
                                    }
                                }
                            }
                            .padding(4)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        // Calculation Method
                        SettingsSection(
                            title: AppStrings.t("calculation_method", appLanguage),
                            icon: "location.circle"
                        ) {
                            let columns = [GridItem(.adaptive(minimum: 130), spacing: 10)]
                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(NoorSettings.CalculationMethod.allCases, id: \.self) {
                                    method in
                                    let isSelected = settings.calculationMethod == method
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3)) {
                                            settings.calculationMethod = method
                                        }
                                        prayerModel.refreshIfNeeded(force: true)
                                    }) {
                                        Text(method.label(appLanguage))
                                            .font(
                                                .system(
                                                    size: 13, weight: .semibold, design: .rounded)
                                            )
                                            .foregroundStyle(
                                                isSelected ? .black : .white.opacity(0.8)
                                            )
                                            .padding(.vertical, 10)
                                            .padding(.horizontal, 14)
                                            .frame(maxWidth: .infinity)
                                            .background(
                                                isSelected
                                                    ? Color.yellow : Color.white.opacity(0.06)
                                            )
                                            .clipShape(Capsule())
                                            .overlay(
                                                Capsule().stroke(
                                                    Color.white.opacity(isSelected ? 0 : 0.08),
                                                    lineWidth: 1)
                                            )
                                    }
                                }
                            }
                        }

                        // Location
                        SettingsSection(
                            title: AppStrings.t("location", appLanguage), icon: "location"
                        ) {
                            VStack(spacing: 12) {
                                HStack(spacing: 0) {
                                    ForEach(NoorSettings.LocationMode.allCases, id: \.self) {
                                        mode in
                                        let isSelected = settings.locationMode == mode
                                        Button(action: {
                                            withAnimation(.spring(response: 0.3)) {
                                                settings.locationMode = mode
                                            }
                                        }) {
                                            Text(AppStrings.locationMode(mode, appLanguage))
                                                .font(
                                                    .system(
                                                        size: 14, weight: .bold, design: .rounded)
                                                )
                                                .foregroundStyle(
                                                    isSelected ? .black : .white.opacity(0.6)
                                                )
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 12)
                                                .background(isSelected ? Color.yellow : Color.clear)
                                                .clipShape(
                                                    RoundedRectangle(
                                                        cornerRadius: 10, style: .continuous))
                                        }
                                    }
                                }
                                .padding(4)
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                                if settings.locationMode == .manual {
                                    VStack(spacing: 10) {
                                        TextField(
                                            AppStrings.t("city", appLanguage),
                                            text: $settings.manualCity
                                        )
                                        .textInputAutocapitalization(.words)
                                        .disableAutocorrection(true)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(Color.white.opacity(0.06))
                                        .clipShape(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        )
                                        .foregroundStyle(.white)

                                        TextField(
                                            AppStrings.t("country", appLanguage),
                                            text: $settings.manualCountry
                                        )
                                        .textInputAutocapitalization(.words)
                                        .disableAutocorrection(true)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(Color.white.opacity(0.06))
                                        .clipShape(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        )
                                        .foregroundStyle(.white)

                                        Button(action: { prayerModel.applyManualLocation() }) {
                                            Text(AppStrings.t("use_location", appLanguage))
                                                .font(
                                                    .system(
                                                        size: 13, weight: .semibold,
                                                        design: .rounded)
                                                )
                                                .foregroundStyle(.black)
                                                .padding(.vertical, 10)
                                                .frame(maxWidth: .infinity)
                                                .background(Color.yellow)
                                                .clipShape(Capsule())
                                        }
                                    }
                                } else {
                                    VStack(spacing: 8) {
                                        if !prayerModel.locationName.isEmpty {
                                            Text(
                                                AppStrings.t("current_location", appLanguage) + ": "
                                                    + prayerModel.locationName
                                            )
                                            .font(
                                                .system(
                                                    size: 12, weight: .semibold, design: .rounded)
                                            )
                                            .foregroundStyle(.white.opacity(0.7))
                                        }
                                        if prayerModel.authorizationStatus == .denied
                                            || prayerModel.authorizationStatus == .restricted
                                        {
                                            Button(action: {
                                                #if os(iOS)
                                                    if let url = URL(
                                                        string: UIApplication.openSettingsURLString)
                                                    {
                                                        openURL(url)
                                                    }
                                                #endif
                                            }) {
                                                Text(AppStrings.t("open_settings", appLanguage))
                                                    .font(
                                                        .system(
                                                            size: 12, weight: .semibold,
                                                            design: .rounded)
                                                    )
                                                    .foregroundStyle(.yellow)
                                                    .padding(.vertical, 8)
                                                    .padding(.horizontal, 16)
                                                    .background(Color.white.opacity(0.08))
                                                    .clipShape(Capsule())
                                            }
                                        } else {
                                            Button(action: { prayerModel.requestLocationIfNeeded() }
                                            ) {
                                                Text(AppStrings.t("refresh_location", appLanguage))
                                                    .font(
                                                        .system(
                                                            size: 12, weight: .semibold,
                                                            design: .rounded)
                                                    )
                                                    .foregroundStyle(.white.opacity(0.8))
                                                    .padding(.vertical, 8)
                                                    .padding(.horizontal, 16)
                                                    .background(Color.white.opacity(0.08))
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Prayer Times Source
                        SettingsSection(
                            title: AppStrings.t("prayer_source", appLanguage), icon: "network"
                        ) {
                            HStack(spacing: 0) {
                                ForEach(NoorSettings.PrayerDataSource.allCases, id: \.self) {
                                    source in
                                    let isSelected = settings.dataSource == source
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3)) {
                                            settings.dataSource = source
                                        }
                                        prayerModel.refreshIfNeeded(force: true)
                                    }) {
                                        Text(AppStrings.prayerSource(source, appLanguage))
                                            .font(
                                                .system(size: 14, weight: .bold, design: .rounded)
                                            )
                                            .foregroundStyle(
                                                isSelected ? .black : .white.opacity(0.6)
                                            )
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(isSelected ? Color.yellow : Color.clear)
                                            .clipShape(
                                                RoundedRectangle(
                                                    cornerRadius: 10, style: .continuous))
                                    }
                                }
                            }
                            .padding(4)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        // Hijri Offset
                        SettingsSection(
                            title: AppStrings.t("hijri_adjustment", appLanguage), icon: "moon.stars"
                        ) {
                            HStack(spacing: 0) {
                                ForEach([-2, -1, 0, 1, 2], id: \.self) { offset in
                                    let isSelected = settings.hijriOffset == offset
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3)) {
                                            settings.hijriOffset = offset
                                        }
                                    }) {
                                        Text(
                                            offset == 0
                                                ? "0" : (offset > 0 ? "+\(offset)" : "\(offset)")
                                        )
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(isSelected ? .black : .white.opacity(0.6))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(isSelected ? Color.yellow : Color.clear)
                                        .clipShape(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    }
                                }
                            }
                            .padding(4)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                            Text(AppStrings.t("hijri_note", appLanguage))
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundStyle(.white.opacity(0.4))
                                .padding(.top, 4)
                        }

                        // Temperature
                        SettingsSection(
                            title: AppStrings.t("temperature", appLanguage), icon: "thermometer"
                        ) {
                            HStack(spacing: 0) {
                                ForEach(NoorSettings.TemperatureUnit.allCases, id: \.self) { unit in
                                    let isSelected = settings.temperatureUnit == unit
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3)) {
                                            settings.temperatureUnit = unit
                                        }
                                    }) {
                                        Text(unit.rawValue)
                                            .font(
                                                .system(size: 18, weight: .bold, design: .rounded)
                                            )
                                            .foregroundStyle(
                                                isSelected ? .black : .white.opacity(0.6)
                                            )
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 14)
                                            .background(isSelected ? Color.yellow : Color.clear)
                                            .clipShape(
                                                RoundedRectangle(
                                                    cornerRadius: 10, style: .continuous))
                                    }
                                }
                            }
                            .padding(4)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        // Language
                        SettingsSection(title: AppStrings.t("language", appLanguage), icon: "globe")
                        {
                            HStack(spacing: 0) {
                                ForEach(NoorSettings.Language.allCases, id: \.self) { option in
                                    let isSelected = settings.language == option
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3)) {
                                            settings.language = option
                                        }
                                    }) {
                                        Text(AppStrings.languageOption(option, appLanguage))
                                            .font(
                                                .system(size: 14, weight: .bold, design: .rounded)
                                            )
                                            .foregroundStyle(
                                                isSelected ? .black : .white.opacity(0.6)
                                            )
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(isSelected ? Color.yellow : Color.clear)
                                            .clipShape(
                                                RoundedRectangle(
                                                    cornerRadius: 10, style: .continuous))
                                    }
                                }
                            }
                            .padding(4)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle(AppStrings.t("settings_title", appLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(AppStrings.t("settings_done", appLanguage)) { dismiss() }
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.yellow)
                }
            }
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.yellow)
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
            content
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - NoorDialBackground (kept for compatibility)
struct NoorDialBackground: View {
    var size: CGFloat
    var cornerRadius: CGFloat? = nil

    var body: some View {
        baseShape
            .overlay(strokeOverlay)
            .overlay(outerGlow)
            .shadow(
                color: NoorDesignSystem.shadowDeep.color,
                radius: NoorDesignSystem.shadowDeep.radius,
                x: NoorDesignSystem.shadowDeep.x,
                y: NoorDesignSystem.shadowDeep.y
            )
    }

    @ViewBuilder
    private var baseShape: some View {
        if let radius = cornerRadius {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(NoorDesignSystem.backgroundDeep)
        } else {
            Circle()
                .fill(NoorDesignSystem.dialGradient)
        }
    }

    @ViewBuilder
    private var strokeOverlay: some View {
        if let radius = cornerRadius {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(NoorDesignSystem.strokeSubtle, lineWidth: 1)
        } else {
            Circle()
                .stroke(NoorDesignSystem.strokeSubtle, lineWidth: 1)
        }
    }

    @ViewBuilder
    private var outerGlow: some View {
        if let radius = cornerRadius {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(NoorDesignSystem.strokeStrong, lineWidth: size * 0.06)
                .blur(radius: 6)
        } else {
            Circle()
                .stroke(NoorDesignSystem.strokeStrong, lineWidth: size * 0.06)
                .blur(radius: 6)
        }
    }
}

// MARK: - NoorClockMarkers (kept for compatibility)
struct NoorClockMarkers: View {
    var size: CGFloat
    var style: MarkerStyle = .standard

    enum MarkerStyle {
        case standard, minimal, luxury, dots
    }

    var body: some View {
        switch style {
        case .standard: standardMarkers
        case .minimal: minimalMarkers
        case .luxury: luxuryMarkers
        case .dots: dotMarkers
        }
    }

    private var standardMarkers: some View {
        ForEach(0..<60, id: \.self) { i in
            let isHour = i % 5 == 0
            markerView(isHour: isHour, index: i)
        }
    }

    private func markerView(isHour: Bool, index: Int) -> some View {
        let width = isHour ? max(2.5, size * 0.010) : max(1, size * 0.004)
        let height = isHour ? max(14, size * 0.09) : max(8, size * 0.045)
        let opacity = isHour ? 0.9 : 0.30

        return Capsule()
            .fill(Color.white.opacity(opacity))
            .frame(width: width, height: height)
            .offset(y: -(size / 2 - max(22, size * 0.14)))
            .rotationEffect(.degrees(Double(index) / 60.0 * 360.0))
    }

    private var minimalMarkers: some View {
        ForEach(0..<12, id: \.self) { i in
            Capsule()
                .fill(Color.white.opacity(i % 3 == 0 ? 0.9 : 0.5))
                .frame(width: max(2, size * 0.008), height: max(14, size * 0.09))
                .offset(y: -(size / 2 - max(22, size * 0.14)))
                .rotationEffect(.degrees(Double(i) / 12.0 * 360.0))
        }
    }

    private var luxuryMarkers: some View {
        ForEach(0..<12, id: \.self) { i in
            luxuryMarkerView(index: i)
        }
    }

    private func luxuryMarkerView(index: Int) -> some View {
        let isMajor = index % 3 == 0
        let width = isMajor ? max(3, size * 0.012) : max(2, size * 0.006)
        let height = isMajor ? max(18, size * 0.12) : max(10, size * 0.06)
        let color = isMajor ? NoorDesignSystem.accentGold : Color.white.opacity(0.6)

        return Capsule()
            .fill(color)
            .frame(width: width, height: height)
            .offset(y: -(size / 2 - max(24, size * 0.16)))
            .rotationEffect(.degrees(Double(index) / 12.0 * 360.0))
    }

    private var dotMarkers: some View {
        ForEach(0..<12, id: \.self) { i in
            let isMajor = i % 3 == 0
            let dotSize = isMajor ? max(6, size * 0.025) : max(4, size * 0.015)
            let color = isMajor ? NoorDesignSystem.accentGold : Color.white.opacity(0.5)

            return Circle()
                .fill(color)
                .frame(width: dotSize, height: dotSize)
                .offset(y: -(size / 2 - max(24, size * 0.16)))
                .rotationEffect(.degrees(Double(i) / 12.0 * 360.0))
        }
    }
}

// MARK: - NoorClockHand (kept for compatibility)
struct NoorClockHand: View {
    var type: HandType
    var length: CGFloat
    var width: CGFloat
    var color: Color
    var angle: Double

    enum HandType {
        case hour, minute, second
    }

    var body: some View {
        ZStack {
            if type != .second {
                Capsule()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: width + 2, height: length + 2)
                    .offset(y: -length / 2)
                    .rotationEffect(.degrees(angle))
            }

            Capsule()
                .fill(handGradient)
                .frame(width: width, height: length)
                .offset(y: -length / 2)
                .rotationEffect(.degrees(angle))
                .shadow(
                    color: type == .second
                        ? NoorDesignSystem.accentGold.opacity(0.6) : Color.white.opacity(0.3),
                    radius: type == .second ? 6 : 3,
                    x: 0, y: 0
                )
        }
    }

    private var handGradient: LinearGradient {
        switch type {
        case .hour:
            return LinearGradient(
                colors: [Color.white, Color.white.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .minute:
            return LinearGradient(
                colors: [
                    Color(red: 0.9, green: 0.9, blue: 1.0),
                    Color(red: 0.75, green: 0.75, blue: 0.9),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .second:
            return LinearGradient(
                colors: [Color.yellow, Color.yellow.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

// MARK: - NoorCenterCap (kept for compatibility)
struct NoorCenterCap: View {
    var size: CGFloat
    var showRing: Bool = true

    var body: some View {
        let strokeColor = showRing ? NoorDesignSystem.accentGold : Color.white.opacity(0.3)
        let lineWidth = showRing ? 2.0 : 1.0

        return Circle()
            .fill(Color.black)
            .frame(width: size, height: size)
            .overlay(Circle().stroke(strokeColor, lineWidth: lineWidth))
            .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
    }
}

// MARK: - NoorGlossOverlay (kept for compatibility)
struct NoorGlossOverlay: View {
    var size: CGFloat

    var body: some View {
        let mask = Circle()
            .padding(size * 0.18)
            .offset(y: -size * 0.12)

        return Circle()
            .fill(NoorDesignSystem.glossGradient)
            .blur(radius: 12)
            .mask(mask)
            .allowsHitTesting(false)
    }
}

// MARK: - NoorArcIndicator (kept for compatibility)
struct NoorArcIndicator: View {
    var progress: Double
    var color: Color
    var lineWidth: CGFloat
    var size: CGFloat

    var body: some View {
        Circle()
            .trim(from: 0, to: progress)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .padding(size * 0.15)
    }
}

// ============================================================
// MARK: - NEW ANALOG CLOCK FACES (completely redesigned, live seconds)
// ============================================================

// MARK: MinimalistAnalogFace
struct MinimalistAnalogFace: View {
    var size: CGFloat = 169

    var body: some View {
        TimelineView(.animation) { context in
            let angles = clockAngles(from: context.date)

            ZStack {
                Circle()
                    .fill(NoorDesignSystem.backgroundDeep)
                    .overlay(Circle().stroke(NoorDesignSystem.strokeSubtle, lineWidth: 1))

                // Thin minute ticks
                ForEach(0..<60) { i in
                    let isHour = i % 5 == 0
                    let tickWidth: CGFloat = isHour ? 2 : 1
                    let tickHeight: CGFloat = isHour ? 12 : 6
                    let tickColor =
                        isHour ? NoorDesignSystem.textPrimary : NoorDesignSystem.textTertiary
                    Rectangle()
                        .fill(tickColor)
                        .frame(width: tickWidth, height: tickHeight)
                        .offset(y: -(size / 2 - 18))
                        .rotationEffect(.degrees(Double(i) * 6))
                }

                HandShape(length: size * 0.3, width: 4, color: NoorDesignSystem.textPrimary)
                    .rotationEffect(.degrees(angles.hour))
                HandShape(length: size * 0.42, width: 2.5, color: NoorDesignSystem.textSecondary)
                    .rotationEffect(.degrees(angles.minute))
                HandShape(length: size * 0.46, width: 1.5, color: NoorDesignSystem.accentGold)
                    .rotationEffect(.degrees(angles.second))
                    .shadow(color: NoorDesignSystem.accentGold.opacity(0.5), radius: 3)

                Circle()
                    .fill(NoorDesignSystem.accentGold)
                    .frame(width: 6, height: 6)
                    .overlay(Circle().stroke(NoorDesignSystem.backgroundDeep, lineWidth: 1))
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: GradientRingAnalogFace
struct GradientRingAnalogFace: View {
    var size: CGFloat = 169

    var body: some View {
        TimelineView(.animation) { context in
            let angles = clockAngles(from: context.date)

            ZStack {
                Circle()
                    .fill(NoorDesignSystem.backgroundDeep)

                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                NoorDesignSystem.accentGold,
                                NoorDesignSystem.textPrimary.opacity(0.7),
                                NoorDesignSystem.accentGold.opacity(0.5),
                            ],
                            startPoint: .top, endPoint: .bottom),
                        lineWidth: 8
                    )
                    .padding(6)

                Circle()
                    .stroke(NoorDesignSystem.strokeSubtle, lineWidth: 1)
                    .padding(6)

                // Dot markers
                ForEach(0..<12) { i in
                    Circle()
                        .fill(NoorDesignSystem.textPrimary.opacity(i % 3 == 0 ? 0.8 : 0.4))
                        .frame(width: i % 3 == 0 ? 5 : 3, height: i % 3 == 0 ? 5 : 3)
                        .offset(y: -(size / 2 - 22))
                        .rotationEffect(.degrees(Double(i) * 30))
                }

                HandShape(length: size * 0.28, width: 5, color: NoorDesignSystem.textPrimary)
                    .rotationEffect(.degrees(angles.hour))
                HandShape(
                    length: size * 0.4, width: 3, color: NoorDesignSystem.textPrimary.opacity(0.8)
                )
                .rotationEffect(.degrees(angles.minute))
                HandShape(length: size * 0.44, width: 2, color: NoorDesignSystem.accentGold)
                    .rotationEffect(.degrees(angles.second))

                Circle()
                    .fill(NoorDesignSystem.textPrimary)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().stroke(NoorDesignSystem.backgroundDeep, lineWidth: 1.5))
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: RetroNeonAnalogFace
struct RetroNeonAnalogFace: View {
    var size: CGFloat = 169

    var body: some View {
        TimelineView(.animation) { context in
            let angles = clockAngles(from: context.date)

            ZStack {
                Circle()
                    .fill(NoorDesignSystem.backgroundDeep)
                    .overlay(
                        Circle().stroke(NoorDesignSystem.accentGold.opacity(0.8), lineWidth: 2)
                    )
                    .shadow(color: NoorDesignSystem.accentGold.opacity(0.4), radius: 8)

                // Retro style numbers
                ForEach(1...12, id: \.self) { i in
                    Text("\(i)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(NoorDesignSystem.accentGold.opacity(0.8))
                        .offset(y: -(size / 2 - 24))
                        .rotationEffect(.degrees(Double(i) * 30))
                }

                HandShape(length: size * 0.28, width: 4, color: NoorDesignSystem.textPrimary)
                    .rotationEffect(.degrees(angles.hour))
                HandShape(
                    length: size * 0.4, width: 2.5, color: NoorDesignSystem.textPrimary.opacity(0.9)
                )
                .rotationEffect(.degrees(angles.minute))
                HandShape(length: size * 0.44, width: 1.5, color: NoorDesignSystem.accentGold)
                    .rotationEffect(.degrees(angles.second))
                    .shadow(color: NoorDesignSystem.accentGold.opacity(0.6), radius: 4)

                Circle()
                    .fill(NoorDesignSystem.accentGold)
                    .frame(width: 7, height: 7)
                    .overlay(Circle().stroke(NoorDesignSystem.backgroundDeep, lineWidth: 1))
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: GeometricAnalogFace
struct GeometricAnalogFace: View {
    var size: CGFloat = 169

    var body: some View {
        TimelineView(.animation) { context in
            let angles = clockAngles(from: context.date)

            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.85))

                // Hexagonal pattern
                ForEach(0..<6) { i in
                    PolygonShape(sides: 6)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        .frame(width: size - CGFloat(i) * 20, height: size - CGFloat(i) * 20)
                }

                // Triangular markers
                ForEach(0..<12) { i in
                    TriangleMarker()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 8, height: 12)
                        .offset(y: -(size / 2 - 22))
                        .rotationEffect(.degrees(Double(i) * 30))
                }

                HandShape(length: size * 0.3, width: 5, color: .white)
                    .rotationEffect(.degrees(angles.hour))
                HandShape(length: size * 0.42, width: 3, color: .white.opacity(0.8))
                    .rotationEffect(.degrees(angles.minute))
                HandShape(length: size * 0.46, width: 2, color: .yellow)
                    .rotationEffect(.degrees(angles.second))

                Circle()
                    .fill(Color.yellow)
                    .frame(width: 8, height: 8)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: LuxuryGoldAnalogFace
struct LuxuryGoldAnalogFace: View {
    var size: CGFloat = 169

    var body: some View {
        TimelineView(.animation) { context in
            let angles = clockAngles(from: context.date)

            ZStack {
                Circle()
                    .fill(Color(white: 0.05))
                    .overlay(Circle().stroke(Color.yellow.opacity(0.5), lineWidth: 2))

                Circle()
                    .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                    .padding(8)

                // Roman numerals
                let romanNumerals = [
                    "XII", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI",
                ]
                ForEach(0..<12, id: \.self) { i in
                    Text(romanNumerals[i])
                        .font(.system(size: 11, weight: .medium, design: .serif))
                        .foregroundStyle(Color.yellow.opacity(0.8))
                        .offset(y: -(size / 2 - 28))
                        .rotationEffect(.degrees(Double(i) * 30))
                }

                HandShape(length: size * 0.27, width: 5, color: .yellow)
                    .rotationEffect(.degrees(angles.hour))
                HandShape(length: size * 0.38, width: 3, color: .yellow.opacity(0.8))
                    .rotationEffect(.degrees(angles.minute))
                HandShape(length: size * 0.44, width: 1.5, color: .white)
                    .rotationEffect(.degrees(angles.second))

                Circle()
                    .fill(Color.yellow)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
                    .shadow(color: .yellow.opacity(0.5), radius: 4)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: MidnightAnalogFace
struct MidnightAnalogFace: View {
    var size: CGFloat = 169

    var body: some View {
        TimelineView(.animation) { context in
            let angles = clockAngles(from: context.date)

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(white: 0.1), .black], center: .center, startRadius: 20,
                            endRadius: size / 2)
                    )
                    .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))

                // Subtle dot markers
                ForEach(0..<12) { i in
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 3, height: 3)
                        .offset(y: -(size / 2 - 18))
                        .rotationEffect(.degrees(Double(i) * 30))
                }

                // Moon phase indicator (approximate)
                Circle()
                    .trim(from: 0, to: 0.5)
                    .stroke(Color.yellow.opacity(0.4), lineWidth: 2)
                    .rotationEffect(.degrees(angles.second))
                    .padding(size * 0.1)

                HandShape(length: size * 0.3, width: 4, color: .white.opacity(0.9))
                    .rotationEffect(.degrees(angles.hour))
                HandShape(length: size * 0.42, width: 2.5, color: .white.opacity(0.7))
                    .rotationEffect(.degrees(angles.minute))
                HandShape(length: size * 0.46, width: 1.2, color: .yellow)
                    .rotationEffect(.degrees(angles.second))
                    .shadow(color: .yellow.opacity(0.4), radius: 3)

                Circle()
                    .fill(Color.yellow)
                    .frame(width: 5, height: 5)
            }
        }
        .frame(width: size, height: size)
    }
}

// Helper: HandShape for all new analog faces
struct HandShape: View {
    let length: CGFloat
    let width: CGFloat
    let color: Color

    var body: some View {
        Capsule()
            .fill(color)
            .frame(width: width, height: length)
            .offset(y: -length / 2)
    }
}

// Helper: PolygonShape
struct PolygonShape: Shape {
    var sides: Int
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        for i in 0..<sides {
            let angle = (Double(i) * 360.0 / Double(sides) - 90) * .pi / 180
            let point = CGPoint(
                x: center.x + radius * CGFloat(cos(angle)),
                y: center.y + radius * CGFloat(sin(angle)))
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

// Helper: TriangleMarker
struct TriangleMarker: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// ============================================================
// MARK: - Quran Model
// ============================================================
struct QuranVerse: Identifiable, Hashable {
    let id = UUID()
    let arabic: String
    let translation: String
    let surah: String
    let ayah: String
}

// MARK: - ContentView
struct ContentView: View {
    @StateObject private var settings: NoorSettings
    @StateObject private var prayerModel: PrayerTimesViewModel
    @StateObject private var weatherModel: WeatherViewModel
    @State private var selectedFilter: String = "ALL"
    @State private var showSettings = false
    @State private var scrollOffset: CGFloat = 0

    private let filters = [
        "ALL", "ANALOG", "DIGITAL", "QURAN", "DOTS", "DATE", "GEBEDSTIJDEN", "WEATHER",
    ]
    private var selectedIndex: Int { filters.firstIndex(of: selectedFilter) ?? 0 }

    init() {
        let settings = NoorSettings()
        _settings = StateObject(wrappedValue: settings)
        _prayerModel = StateObject(wrappedValue: PrayerTimesViewModel(settings: settings))
        _weatherModel = StateObject(wrappedValue: WeatherViewModel(settings: settings))
    }

    private let quranVerses: [QuranVerse] = [
        QuranVerse(
            arabic: "فَإِنَّ مَعَ الْعُسْرِ يُسْرًا", translation: "For indeed, with hardship [will be] ease.",
            surah: "Surah Ash-Sharh", ayah: "94:5"),
        QuranVerse(
            arabic: "وَهُوَ مَعَكُمْ أَيْنَ مَا كُنتُمْ", translation: "And He is with you wherever you are.",
            surah: "Surah Al-Hadid", ayah: "57:4"),
        QuranVerse(
            arabic: "أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ",
            translation: "Verily, in the remembrance of Allah do hearts find rest.",
            surah: "Surah Ar-Ra'd", ayah: "13:28"),
        QuranVerse(
            arabic: "إِنَّ اللَّهَ مَعَ الصَّابِرِينَ", translation: "Indeed, Allah is with the patient.",
            surah: "Surah Al-Baqarah", ayah: "2:153"),
    ]

    var body: some View {
        let appLang = AppLanguage.resolve(from: settings.language)

        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    GeometryReader { proxy in
                        Color.clear
                            .preference(
                                key: ContentScrollOffsetKey.self,
                                value: proxy.frame(in: .named("contentScroll")).minY
                            )
                    }
                    .frame(height: 0)

                    Color.clear.frame(height: 84)

                    headerAndFilters(appLang: appLang)
                        .padding(.top, 12)
                        .padding(.bottom, 16)

                    swipeableContent(appLang: appLang)
                        .id(selectedFilter)
                        .transition(.opacity)
                        .gesture(
                            DragGesture(minimumDistance: 50)
                                .onEnded { value in
                                    let horizontal = value.translation.width
                                    let vertical = abs(value.translation.height)
                                    guard abs(horizontal) > vertical else { return }
                                    let goingLeft = horizontal < 0
                                    let next =
                                        goingLeft
                                        ? min(selectedIndex + 1, filters.count - 1)
                                        : max(selectedIndex - 1, 0)
                                    guard next != selectedIndex else { return }
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        selectedFilter = filters[next]
                                    }
                                }
                        )
                }
            }
            .coordinateSpace(name: "contentScroll")

            topBar(appLang: appLang, isScrolled: scrollOffset < -6)
                .padding(.horizontal, 20)
                .padding(.top, 8)
        }
        .environment(\.appLanguage, appLang)
        .environment(\.layoutDirection, appLang == .arabic ? .rightToLeft : .leftToRight)
        .environmentObject(prayerModel)
        .onAppear {
            prayerModel.requestLocationIfNeeded()
            weatherModel.refreshIfPossible()
        }
        .onChange(of: prayerModel.locationName) { _ in
            weatherModel.refreshIfPossible()
        }
        .onPreferenceChange(ContentScrollOffsetKey.self) { value in
            scrollOffset = value
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(settings: settings)
                .environmentObject(prayerModel)
                .environment(\.appLanguage, appLang)
                .environment(\.layoutDirection, appLang == .arabic ? .rightToLeft : .leftToRight)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func headerAndFilters(appLang: AppLanguage) -> some View {
        VStack(spacing: 16) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(filters, id: \.self) { item in
                            let isSelected = selectedFilter == item

                            Button {
                                guard item != selectedFilter else { return }

                                withAnimation(.easeInOut(duration: 0.25)) {
                                    selectedFilter = item
                                }

                                DispatchQueue.main.async {
                                    proxy.scrollTo(item, anchor: .center)
                                }
                            } label: {
                                Text(filterLabel(item, lang: appLang))
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(isSelected ? .black : .white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        isSelected ? Color.yellow : Color.white.opacity(0.06)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18)
                                            .stroke(
                                                Color.white.opacity(0.08),
                                                lineWidth: isSelected ? 0 : 1)
                                    )
                                    .clipShape(Capsule())
                            }
                            .id(item)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .onChange(of: selectedFilter) { value in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(value, anchor: .center)
                    }
                }
            }
        }
    }

    private func topBar(appLang: AppLanguage, isScrolled: Bool) -> some View {
        HStack {
            Button(action: {}) {
                Image(systemName: "crown")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Spacer()

            Text(AppStrings.t("app_title", appLang))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(height: 56)
        .padding(.horizontal, 12)
        .background {
            if isScrolled {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .overlay(alignment: .bottom) {
                        LinearGradient(
                            colors: [Color.white.opacity(0.16), Color.clear],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                        .frame(height: 18)
                        .clipShape(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                        )
                    }
                    .shadow(color: .black.opacity(0.22), radius: 10, x: 0, y: 6)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isScrolled)
    }

    @ViewBuilder
    private func swipeableContent(appLang: AppLanguage) -> some View {
        if selectedFilter == "QURAN" {
            VStack(alignment: .leading, spacing: 24) {
                Text("﷽")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(maxWidth: .infinity).padding(.vertical, 4)
                VStack(spacing: 20) {
                    ForEach(quranVerses) { verse in QuranVerseCard(verse: verse) }
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 32)
        } else {
            filterContentContentOnly(appLang: appLang)
        }
    }

    private func filterContentContentOnly(appLang: AppLanguage) -> some View {
        FilterContentRootView(
            selectedFilter: selectedFilter,
            appLang: appLang,
            quranVerses: quranVerses,
            weatherModel: weatherModel
        )
    }

}

private struct ContentScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Filter Content Views

private struct FilterContentRootView: View {
    let selectedFilter: String
    let appLang: AppLanguage
    let quranVerses: [QuranVerse]
    @ObservedObject var weatherModel: WeatherViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("﷽")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)

            content
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
    }

    private var content: AnyView {
        switch selectedFilter {
        case "ALL":
            AnyView(
                AllFilterContentView(
                    appLang: appLang,
                    quranVerses: quranVerses,
                    weatherModel: weatherModel
                )
            )
        case "ANALOG":
            AnyView(AnalogGridContentView())
        case "DIGITAL":
            AnyView(DigitalFilterContentView(appLang: appLang))
        case "DOTS":
            AnyView(DotsFilterContentView(appLang: appLang))
        case "DATE":
            AnyView(DateFilterContentView(appLang: appLang))
        case "GEBEDSTIJDEN":
            AnyView(PrayerFilterContentView(appLang: appLang))
        case "WEATHER":
            AnyView(WeatherFilterContentView(appLang: appLang, weatherModel: weatherModel))
        default:
            AnyView(EmptyView())
        }
    }
}

private struct AllFilterContentView: View {
    let appLang: AppLanguage
    let quranVerses: [QuranVerse]
    @ObservedObject var weatherModel: WeatherViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Analog")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.top, 4)
            AnalogGridContentView()

            Text(AppStrings.t("filter_digital", appLang))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.top, 4)
            DigitalAllSectionView(appLang: appLang)

            Text(AppStrings.t("filter_quran", appLang))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.top, 4)
            QuranVersesContentView(quranVerses: quranVerses)

            Text(AppStrings.t("filter_dots", appLang))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.top, 4)
            DotsFilterContentView(appLang: appLang)

            Text(AppStrings.t("filter_date", appLang))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.top, 4)
            DateFilterContentView(appLang: appLang)

            Text(AppStrings.t("filter_prayer", appLang))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.top, 4)
            PrayerFilterContentView(appLang: appLang)

            Text(AppStrings.t("filter_weather", appLang))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.top, 4)
            WeatherFilterContentView(appLang: appLang, weatherModel: weatherModel)
        }
    }
}

private struct AnalogGridContentView: View {
    var body: some View {
        let analogClockSize: CGFloat = 130

        VStack(spacing: 16) {
            HStack(spacing: 16) {
                SmallWidgetCard(title: "Minimalist") { MinimalistAnalogFace(size: analogClockSize) }
                SmallWidgetCard(title: "Gradient Ring") {
                    GradientRingAnalogFace(size: analogClockSize)
                }
            }
            HStack(spacing: 16) {
                SmallWidgetCard(title: "Retro Neon") { RetroNeonAnalogFace(size: analogClockSize) }
                SmallWidgetCard(title: "Geometric") { GeometricAnalogFace(size: analogClockSize) }
            }
            HStack(spacing: 16) {
                SmallWidgetCard(title: "Luxury Gold") {
                    LuxuryGoldAnalogFace(size: analogClockSize)
                }
                SmallWidgetCard(title: "Midnight") { MidnightAnalogFace(size: analogClockSize) }
            }
        }
    }
}

private struct DigitalAllSectionView: View {
    let appLang: AppLanguage

    var body: some View {
        VStack(spacing: 20) {
            Card(title: AppStrings.t("card_luminous_digital", appLang)) {
                DigitalBoldFace().frame(height: 150)
            }
            Card(title: AppStrings.t("card_calendar_duo", appLang)) {
                DayDateGridCard().frame(height: 150)
            }
            Card(title: AppStrings.t("card_ayah_ticker", appLang)) { QuranTickerCard() }
            Card(title: AppStrings.t("card_minimal_clock", appLang)) {
                DigitalMinimalFace().frame(height: 150)
            }
            Card(title: AppStrings.t("card_dual_line_time", appLang)) {
                DualLineTimeFace().frame(height: 150)
            }
            Card(title: AppStrings.t("card_gregorian", appLang)) {
                GregorianCompactCalendarCard().frame(height: 150)
            }
            Card(title: AppStrings.t("card_hijri", appLang)) {
                HijriCompactCalendarCard().frame(height: 150)
            }
        }
    }
}

private struct DigitalFilterContentView: View {
    let appLang: AppLanguage

    var body: some View {
        VStack(spacing: 20) {
            Card(title: AppStrings.t("card_luminous_digital", appLang)) {
                DigitalBoldFace().frame(height: 150)
            }
            Card(title: AppStrings.t("card_calendar_duo", appLang)) {
                DayDateGridCard().frame(height: 150)
            }
            Card(title: AppStrings.t("card_ayah_ticker", appLang)) { QuranTickerCard() }
            Card(title: AppStrings.t("card_minimal_clock", appLang)) {
                DigitalMinimalFace().frame(height: 150)
            }
            Card(title: AppStrings.t("card_dual_line_time", appLang)) {
                DualLineTimeFace().frame(height: 150)
            }

            Text(AppStrings.t("celestial_calendars", appLang))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.top, 4)

            Card(title: AppStrings.t("card_gregorian", appLang)) {
                GregorianCompactCalendarCard().frame(height: 150)
            }
            Card(title: AppStrings.t("card_hijri", appLang)) {
                HijriCompactCalendarCard().frame(height: 150)
            }
        }
    }
}

private struct QuranVersesContentView: View {
    let quranVerses: [QuranVerse]

    var body: some View {
        VStack(spacing: 20) {
            ForEach(quranVerses) { verse in
                QuranVerseCard(verse: verse)
            }
        }
    }
}

private struct DotsFilterContentView: View {
    let appLang: AppLanguage

    var body: some View {
        VStack(spacing: 20) {
            Card(title: AppStrings.t("card_week_pulse", appLang)) { WeekDotsFace() }
            Card(title: AppStrings.t("card_month_progress", appLang)) { MonthDotsFace() }
            Card(title: AppStrings.t("card_year_journey", appLang)) { YearDotsFace() }
            Card(title: AppStrings.t("card_triple_orbit", appLang)) { TripleOrbitFace() }
        }
    }
}

private struct DateFilterContentView: View {
    let appLang: AppLanguage

    var body: some View {
        VStack(spacing: 20) {
            Card(title: AppStrings.t("card_today_date", appLang)) { TodayDateFace() }
            Card(title: AppStrings.t("card_dual_calendar", appLang)) { DualCalendarFace() }
            Card(title: AppStrings.t("card_week_overview", appLang)) {
                ThuluthWidgetPreview(family: .medium)
            }
            Card(title: AppStrings.t("card_month_grid", appLang)) { MonthGridFace() }
            Card(title: AppStrings.t("card_islamic_calendar", appLang)) { IslamicDateFace() }

            Card(title: "Thuluth Small") { ThuluthWidgetPreview(family: .small) }
            Card(title: "Thuluth Medium") { ThuluthWidgetPreview(family: .medium) }
            Card(title: "Thuluth Large") { ThuluthWidgetPreview(family: .large) }
        }
    }
}

private struct PrayerFilterContentView: View {
    let appLang: AppLanguage

    var body: some View {
        VStack(spacing: 20) {
            Card(title: AppStrings.t("card_prayer_times_today", appLang)) {
                PrayerTimesFace()
            }
            Card(title: AppStrings.t("card_next_prayer", appLang)) { NextPrayerFace() }
            Card(title: AppStrings.t("card_timeline", appLang)) { PrayerTimelineFace() }

            HStack(alignment: .top, spacing: 12) {
                Card(title: AppStrings.t("card_prayer_progress", appLang)) {
                    PrayerProgressFace()
                }
                .frame(maxWidth: .infinity)

                Card(title: AppStrings.t("card_qibla_compass", appLang)) {
                    QiblaFacePreview()
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct WeatherFilterContentView: View {
    let appLang: AppLanguage
    @ObservedObject var weatherModel: WeatherViewModel

    var body: some View {
        VStack(spacing: 18) {
            Card(title: AppStrings.t("card_weather_now", appLang)) {
                WeatherDetailFace(model: weatherModel)
            }
            HStack(spacing: 12) {
                Card(title: "Current Weather") {
                    WeatherSimpleFace(model: weatherModel)
                }
                .frame(maxWidth: .infinity)

                Card(title: "Compact Weather") {
                    WeatherCompactFace(model: weatherModel)
                }
                .frame(maxWidth: .infinity)
            }
            Card(title: "Thuluth Weather") {
                WeatherThuluthFace(model: weatherModel)
                    .aspectRatio(310.0 / 146.0, contentMode: .fit)
            }
        }
    }
}


private func filterLabel(_ item: String, lang: AppLanguage) -> String {
    switch item {
    case "ALL": return AppStrings.t("filter_all", lang)
    case "ANALOG": return AppStrings.t("filter_analog", lang)
    case "DIGITAL": return AppStrings.t("filter_digital", lang)
    case "QURAN": return AppStrings.t("filter_quran", lang)
    case "DOTS": return AppStrings.t("filter_dots", lang)
    case "DATE": return AppStrings.t("filter_date", lang)
    case "GEBEDSTIJDEN": return AppStrings.t("filter_prayer", lang)
    case "WEATHER": return AppStrings.t("filter_weather", lang)
    default: return item
    }
}

// MARK: - Card container
struct Card<Content: View>: View {
    let title: String
    let content: Content
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    var body: some View {
        VStack(spacing: 12) {
            content
                .padding(16)
                .background(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.6), radius: 24, x: 0, y: 12)
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

// MARK: - SmallWidgetCard (square small widget style, 2-column grid)
struct SmallWidgetCard<Content: View>: View {
    let title: String
    let content: Content
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    var body: some View {
        VStack(spacing: 8) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .background(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.5), radius: 16, x: 0, y: 8)
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Thuluth Widget Previews (unchanged)
private enum ThuluthWidgetColors {
    static let background = Color.black
    static let yellow = Color.yellow
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
}

enum WidgetPreviewFamily {
    case small
    case medium
    case large

    var aspectRatio: CGFloat {
        switch self {
        case .small, .large:
            return 1
        case .medium:
            return 364.0 / 170.0
        }
    }
}

struct ThuluthWidgetPreview: View {
    let family: WidgetPreviewFamily

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            WidgetPreviewContainer(family: family) {
                switch family {
                case .small:
                    ThuluthSmallWidgetFace(date: context.date)
                case .medium:
                    ThuluthMediumWidgetFace(date: context.date)
                case .large:
                    ThuluthLargeWidgetFace(date: context.date)
                }
            }
        }
    }
}

struct WidgetPreviewContainer<Content: View>: View {
    let family: WidgetPreviewFamily
    let content: Content

    init(family: WidgetPreviewFamily, @ViewBuilder content: () -> Content) {
        self.family = family
        self.content = content()
    }

    var body: some View {
        ZStack {
            content
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .aspectRatio(family.aspectRatio, contentMode: .fit)
    }
}

struct ThuluthSmallWidgetFace: View {
    let date: Date

    var body: some View {
        let hijri = Calendar(identifier: .islamicUmmAlQura)
        let hComps = hijri.dateComponents([.day, .month, .year], from: date)

        return VStack(spacing: 6) {
            Text(dayNumber(date))
                .font(.custom("DecoType Thuluth", size: 56))
                .foregroundStyle(ThuluthWidgetColors.yellow)
                .shadow(color: ThuluthWidgetColors.yellow.opacity(0.3), radius: 6)
            Text(shortMonth(date).uppercased())
                .font(.custom("DecoType Thuluth", size: 16))
                .foregroundStyle(ThuluthWidgetColors.textPrimary)
            Text(arabicDigits(hComps.day ?? 0) + " " + hijriMonthName(date))
                .font(.custom("DecoType Thuluth", size: 14))
                .foregroundStyle(ThuluthWidgetColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
    }
}

struct ThuluthMediumWidgetFace: View {
    let date: Date

    var body: some View {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        let hour = comps.hour ?? 0
        let minute = comps.minute ?? 0

        return VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%02d", hour))
                    .font(.custom("DecoType Thuluth", size: 48))
                    .foregroundStyle(ThuluthWidgetColors.textPrimary)
                Text(":")
                    .font(.system(size: 40, weight: .thin))
                    .foregroundStyle(ThuluthWidgetColors.yellow)
                    .offset(y: -2)
                Text(String(format: "%02d", minute))
                    .font(.custom("DecoType Thuluth", size: 48))
                    .foregroundStyle(ThuluthWidgetColors.yellow)
            }
            Text(weekdayNameFull(date) + " · " + dayNumber(date) + " " + monthName(date))
                .font(.custom("DecoType Thuluth", size: 18))
                .foregroundStyle(ThuluthWidgetColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

struct ThuluthLargeWidgetFace: View {
    let date: Date

    var body: some View {
        let hijri = Calendar(identifier: .islamicUmmAlQura)
        let hComps = hijri.dateComponents([.day, .month, .year], from: date)
        let dayOfYear = Double(hijri.ordinality(of: .day, in: .year, for: date) ?? 1)
        let totalDays = Double(hijri.range(of: .day, in: .year, for: date)?.count ?? 354)
        let progress = max(0.0, min(1.0, dayOfYear / totalDays))

        return ZStack {
            Circle()
                .stroke(ThuluthWidgetColors.textPrimary.opacity(0.08), lineWidth: 12)
                .padding(8)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            ThuluthWidgetColors.yellow.opacity(0.3), ThuluthWidgetColors.yellow,
                            ThuluthWidgetColors.yellow.opacity(0.3),
                        ]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .padding(8)

            VStack(spacing: 4) {
                Text(arabicDigits(hComps.day ?? 0))
                    .font(.custom("DecoType Thuluth", size: 56))
                    .foregroundStyle(ThuluthWidgetColors.yellow)
                Text(hijriMonthName(date))
                    .font(.custom("DecoType Thuluth", size: 22))
                    .foregroundStyle(ThuluthWidgetColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 24)
                Text(arabicDigits(hComps.year ?? 0) + " هـ")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(ThuluthWidgetColors.textSecondary)
            }
            .padding(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
    }
}

// MARK: - Dot-based Time Faces (unchanged)
struct WeekDotsFace: View {
    @State private var now: Date = .now
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @Environment(\.appLanguage) private var appLanguage

    var body: some View {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)
        let adjustedDay = weekday == 1 ? 7 : weekday - 1

        VStack(spacing: 16) {
            Text(AppStrings.t("label_week_pulse", appLanguage))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))

            HStack(spacing: 12) {
                ForEach(1...7, id: \.self) { day in
                    let isToday = day == adjustedDay
                    Circle()
                        .fill(isToday ? Color.yellow : Color.white.opacity(0.15))
                        .frame(width: isToday ? 18 : 12, height: isToday ? 18 : 12)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(isToday ? 0.4 : 0.1), lineWidth: 2)
                                .scaleEffect(isToday ? 1.4 : 1.0)
                        )
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isToday)
                }
            }

            Text(weekdayNameFull(now))
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .onReceive(timer) { now = $0 }
    }
}

struct MonthDotsFace: View {
    @State private var now: Date = .now
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @Environment(\.appLanguage) private var appLanguage

    var body: some View {
        let calendar = Calendar.current
        let dayOfMonth = calendar.component(.day, from: now)
        let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 30

        let columns = 10
        let rows = Int(ceil(Double(daysInMonth) / Double(columns)))

        VStack(spacing: 16) {
            Text(AppStrings.t("label_month_progress", appLanguage))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))

            VStack(spacing: 6) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 6) {
                        ForEach(0..<columns, id: \.self) { col in
                            let dayNum = row * columns + col + 1
                            if dayNum <= daysInMonth {
                                let isPassed = dayNum <= dayOfMonth
                                Circle()
                                    .fill(isPassed ? Color.yellow : Color.white.opacity(0.15))
                                    .frame(width: isPassed ? 8 : 6, height: isPassed ? 8 : 6)
                            }
                        }
                    }
                }
            }

            HStack {
                Text(AppStrings.t("label_day", appLanguage) + " \(dayOfMonth)")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(AppStrings.t("label_of", appLanguage) + " \(daysInMonth)")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .onReceive(timer) { now = $0 }
    }
}

struct YearDotsFace: View {
    @State private var now: Date = .now
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @Environment(\.appLanguage) private var appLanguage

    var body: some View {
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: now) ?? 1
        let year = calendar.component(.year, from: now)
        let isLeapYear = calendar.range(of: .day, in: .year, for: now)?.count == 366
        let totalDays = isLeapYear ? 366 : 365

        VStack(spacing: 16) {
            Text(AppStrings.t("label_year_journey", appLanguage))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))

            HStack(spacing: 10) {
                ForEach(1...12, id: \.self) { month in
                    let currentMonth = calendar.component(.month, from: now)
                    let isPassed = month < currentMonth
                    let isCurrent = month == currentMonth

                    Circle()
                        .fill(
                            isCurrent
                                ? Color.yellow
                                : (isPassed ? Color.white.opacity(0.5) : Color.white.opacity(0.15))
                        )
                        .frame(width: isCurrent ? 16 : 10, height: isCurrent ? 16 : 10)
                        .overlay(
                            Circle()
                                .stroke(Color.yellow.opacity(isCurrent ? 0.6 : 0), lineWidth: 2)
                                .scaleEffect(isCurrent ? 1.5 : 1.0)
                        )
                }
            }

            VStack(spacing: 4) {
                Text("\(year)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(
                    AppStrings.t("label_day", appLanguage) + " \(dayOfYear) "
                        + AppStrings.t("label_of", appLanguage) + " \(totalDays)"
                )
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .onReceive(timer) { now = $0 }
    }
}

struct TripleOrbitFace: View {
    @State private var now: Date = .now
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @Environment(\.appLanguage) private var appLanguage

    var body: some View {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now)
        let adjustedDay = weekday == 1 ? 7 : weekday - 1
        let weekProgress = Double(adjustedDay) / 7.0
        let dayOfMonth = calendar.component(.day, from: now)
        let daysInMonth = Double(calendar.range(of: .day, in: .month, for: now)?.count ?? 30)
        let monthProgress = Double(dayOfMonth) / daysInMonth
        let dayOfYear = Double(calendar.ordinality(of: .day, in: .year, for: now) ?? 1)
        let totalDays = Double(calendar.range(of: .day, in: .year, for: now)?.count ?? 365)
        let yearProgress = dayOfYear / totalDays

        ZStack {
            Circle()
                .fill(.black.opacity(0.9))
                .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))

            Circle().stroke(Color.white.opacity(0.1), lineWidth: 2).padding(20)
            Circle().fill(Color.white.opacity(0.8)).frame(width: 8, height: 8)
                .offset(y: -(240 / 2 - 20 - 4)).rotationEffect(.degrees(yearProgress * 360 - 90))

            Circle().stroke(Color.white.opacity(0.15), lineWidth: 2).padding(50)
            Circle().fill(Color.white).frame(width: 10, height: 10)
                .offset(y: -(240 / 2 - 50 - 5)).rotationEffect(.degrees(monthProgress * 360 - 90))

            Circle().stroke(Color.yellow.opacity(0.3), lineWidth: 2).padding(80)
            Circle().fill(Color.yellow).frame(width: 12, height: 12)
                .offset(y: -(240 / 2 - 80 - 6)).rotationEffect(.degrees(weekProgress * 360 - 90))
                .shadow(color: .yellow.opacity(0.6), radius: 8)

            VStack(spacing: 4) {
                Text(AppStrings.t("label_orbits", appLanguage))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                Text("W • M • Y")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.yellow)
            }
        }
        .frame(width: 320, height: 320)
        .onReceive(timer) { now = $0 }
    }
}

// MARK: - Digital Faces (unchanged)
struct DigitalBoldFace: View {
    @State private var now: Date = .now
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @Environment(\.appLanguage) private var appLanguage
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: now)
            let hour = comps.hour ?? 0
            let minute = comps.minute ?? 0
            VStack(alignment: .leading, spacing: -2) {
                Text(String(format: "%02d", hour))
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.yellow)
                Text(String(format: "%02d", minute))
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            Text(AppStrings.t("label_luminous_digital", appLanguage))
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .onReceive(timer) { now = $0 }
    }
}

struct DayDateGridCard: View {
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(monthName(Date()).uppercased())
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                CapsuleLabel(
                    text: weekdayName(Date()).uppercased(), color: .white.opacity(0.10),
                    textColor: .white)
            }
            Spacer()
            VStack(spacing: 8) {
                CapsuleLabel(
                    text: shortMonth(Date()).uppercased(), color: .yellow, textColor: .black)
                CapsuleLabel(
                    text: dayNumber(Date()), color: .white.opacity(0.10), textColor: .white)
            }
        }
    }
}

struct CapsuleLabel: View {
    let text: String
    let color: Color
    let textColor: Color
    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(textColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(color)
            .clipShape(Capsule())
    }
}

struct QuranTickerCard: View {
    @State private var phase: CGFloat = 0
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.white.opacity(0.06), .clear], startPoint: .top, endPoint: .bottom
            )
            .mask(
                VStack(spacing: 6) {
                    ForEach(0..<12, id: \.self) { _ in
                        Rectangle().frame(height: 6)
                        Spacer(minLength: 6)
                    }
                })
            Text("سبحان الله وبحمده، سبحان الله العظيم")
                .font(.custom("DecoType Thuluth", size: 32))
                .foregroundStyle(.yellow)
                .offset(x: phase)
                .animation(.linear(duration: 8).repeatForever(autoreverses: false), value: phase)
                .onAppear { phase = -40 }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct DigitalMinimalFace: View {
    @State private var now: Date = .now
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    var body: some View {
        let formatter = DateFormatter()
        let _ = {
            formatter.dateFormat = "hh:mm a"
            formatter.locale = Locale.current
        }()
        return Text(formatter.string(from: now))
            .font(.system(size: 36, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onReceive(timer) { now = $0 }
    }
}

struct DualLineTimeFace: View {
    @State private var now: Date = .now
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @Environment(\.appLanguage) private var appLanguage
    var body: some View {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: now)
        let hour = comps.hour ?? 0
        let minute = comps.minute ?? 0
        return VStack(alignment: .leading, spacing: 8) {
            Text(String(format: "%02d:%02d", hour, minute))
                .font(.system(size: 54, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .overlay(alignment: .bottomLeading) {
                    Rectangle().fill(Color.yellow).frame(height: 6).offset(y: 10)
                }
            Text(AppStrings.t("label_quran_orbital", appLanguage))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onReceive(timer) { now = $0 }
    }
}

struct GregorianCompactCalendarCard: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectInfo(
                title: shortMonth(Date()).uppercased(), value: dayNumber(Date()), accent: .yellow)
            RoundedRectInfo(
                title: weekdayName(Date()).uppercased(), value: yearNumber(Date()),
                accent: .white.opacity(0.10), textColor: .white)
        }
    }
}

struct RoundedRectInfo: View {
    let title: String
    let value: String
    var accent: Color = .yellow
    var textColor: Color = .black
    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(textColor == .black ? .black.opacity(0.7) : textColor.opacity(0.7))
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(textColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(accent)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct HijriCompactCalendarCard: View {
    @State private var now: Date = .now
    var body: some View {
        let hijri = Calendar(identifier: .islamicUmmAlQura)
        let comps = hijri.dateComponents([.day, .month, .year], from: now)
        let day = comps.day ?? 0
        let mName = hijriMonthName(now)
        return HStack(spacing: 12) {
            RoundedRectInfo(
                title: mName, value: arabicDigits(day), accent: .white.opacity(0.10),
                textColor: .white)
            RoundedRectInfo(
                title: "هجري", value: arabicDigits(comps.year ?? 0), accent: .yellow,
                textColor: .black)
        }
    }
}

// MARK: - DATE Widgets (unchanged)
struct TodayDateFace: View {
    @State private var now: Date = .now
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: now)

        VStack(spacing: 16) {
            Text(weekdayNameFull(now).uppercased())
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
            Text("\(day)")
                .font(.system(size: 88, weight: .heavy, design: .rounded))
                .foregroundStyle(.yellow)
            Text(monthName(now).uppercased())
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(yearNumber(now))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .onReceive(timer) { now = $0 }
    }
}

struct DualCalendarFace: View {
    @State private var now: Date = .now
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("GREGORIAN")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                Text(dayNumber(now))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.yellow)
                Text(shortMonth(now).uppercased())
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(yearNumber(now))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(spacing: 8) {
                Text("HIJRI")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                let hijri = Calendar(identifier: .islamicUmmAlQura)
                let comps = hijri.dateComponents([.day, .month, .year], from: now)
                Text(arabicDigits(comps.day ?? 0))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(hijriMonthName(now))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(arabicDigits(comps.year ?? 0))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .onReceive(timer) { now = $0 }
    }
}

struct MonthGridFace: View {
    @State private var now: Date = .now
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        let calendar = Calendar.current
        let currentDay = calendar.component(.day, from: now)
        let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        let columns = 7
        let rows = Int(ceil(Double(daysInMonth) / Double(columns)))

        VStack(spacing: 12) {
            HStack {
                Text(monthName(now).uppercased())
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Text(yearNumber(now))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
            VStack(spacing: 4) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 4) {
                        ForEach(0..<columns, id: \.self) { col in
                            let dayNum = row * columns + col + 1
                            if dayNum <= daysInMonth {
                                let isToday = dayNum == currentDay
                                Text("\(dayNum)")
                                    .font(
                                        .system(
                                            size: isToday ? 12 : 10,
                                            weight: isToday ? .bold : .medium, design: .rounded)
                                    )
                                    .foregroundStyle(isToday ? .black : .white)
                                    .frame(maxWidth: .infinity).frame(height: 28)
                                    .background(isToday ? Color.yellow : Color.white.opacity(0.05))
                                    .clipShape(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous))
                            } else {
                                Color.clear.frame(maxWidth: .infinity).frame(height: 28)
                            }
                        }
                    }
                }
            }
        }
        .onReceive(timer) { now = $0 }
    }
}

struct IslamicDateFace: View {
    @State private var now: Date = .now
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        let hijri = Calendar(identifier: .islamicUmmAlQura)
        let comps = hijri.dateComponents([.day, .month, .year, .weekday], from: now)

        VStack(spacing: 16) {
            Text("التقويم الهجري")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
            Text(arabicDigits(comps.day ?? 0))
                .font(.system(size: 72, weight: .heavy, design: .rounded))
                .foregroundStyle(.yellow)
            Text(hijriMonthName(now))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(arabicDigits(comps.year ?? 0) + " هـ")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .onReceive(timer) { now = $0 }
    }
}

// MARK: - GEBEDSTIJDEN Widgets (unchanged)
struct PrayerTimesFace: View {
    @EnvironmentObject private var prayerModel: PrayerTimesViewModel
    @Environment(\.appLanguage) private var appLanguage

    private var locale: Locale {
        appLanguage == .arabic ? Locale(identifier: "ar") : Locale(identifier: "en")
    }

    private var timeFormat: NoorTimeFormatSetting {
        NoorTimeFormatSetting.fromStorage(
            NoorSharedDefaults.shared.string(forKey: NoorSharedKeys.timeFormat))
    }

    var body: some View {
        let data = prayerModel.data
        let date = data?.date ?? Date()

        VStack(spacing: 12) {
            HStack {
                Text(AppStrings.t("label_prayer_times", appLanguage))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Text(date, format: Date.FormatStyle().day().month(.abbreviated))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }

            if let data {
                VStack(spacing: 8) {
                    ForEach(data.times) { prayer in
                        HStack {
                            Text(prayer.name.arabic)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(.yellow)
                                .frame(width: 60, alignment: .trailing)
                            Text(prayer.name.english.uppercased())
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.7))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(
                                NoorPrayerTimeFormatter.format(
                                    prayer.time, timeFormat: timeFormat, locale: locale)
                            )
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            } else {
                Text(AppStrings.t("location_needed", appLanguage))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.vertical, 16)
            }
        }
    }
}

struct NextPrayerFace: View {
    @EnvironmentObject private var prayerModel: PrayerTimesViewModel
    @Environment(\.appLanguage) private var appLanguage

    private var locale: Locale {
        appLanguage == .arabic ? Locale(identifier: "ar") : Locale(identifier: "en")
    }

    private var timeFormat: NoorTimeFormatSetting {
        NoorTimeFormatSetting.fromStorage(
            NoorSharedDefaults.shared.string(forKey: NoorSharedKeys.timeFormat))
    }

    var body: some View {
        let data = prayerModel.data
        let times = data?.times ?? []
        let next = times.first { $0.time > prayerModel.now }
        let nextPrayer = next?.name
        let nextTime = next?.time

        VStack(spacing: 20) {
            Text(AppStrings.t("label_next_prayer", appLanguage))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))

            if let nextPrayer, let nextTime {
                Text(nextPrayer.arabic)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.yellow)
                Text(nextPrayer.english.uppercased())
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                VStack(spacing: 8) {
                    Text(
                        NoorPrayerTimeFormatter.format(
                            nextTime, timeFormat: timeFormat, locale: locale)
                    )
                    .font(.system(size: 48, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white)
                    HStack(spacing: 4) {
                        Text(AppStrings.t("label_in", appLanguage))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                        Text(countdown(to: nextTime, now: prayerModel.now))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText(countsDown: true))
                            .foregroundStyle(.yellow)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
                }
            } else {
                Text(AppStrings.t("location_needed", appLanguage))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private func countdown(to date: Date, now: Date) -> String {
        let interval = max(0, date.timeIntervalSince(now))
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct PrayerProgressFace: View {
    @EnvironmentObject private var prayerModel: PrayerTimesViewModel
    @Environment(\.appLanguage) private var appLanguage

    var body: some View {
        let times = prayerModel.data?.times ?? []
        let completed = times.filter { $0.name != .sunrise && $0.time <= prayerModel.now }.count
        let progress = 5 == 0 ? 0 : Double(completed) / 5.0

        ZStack {
            Circle().stroke(Color.white.opacity(0.1), lineWidth: 10)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.yellow, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text("\(completed)/5")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Text(AppStrings.t("label_prayers", appLanguage))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(width: 140, height: 140)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
    }
}

struct PrayerTimelineFace: View {
    @EnvironmentObject private var prayerModel: PrayerTimesViewModel
    @Environment(\.appLanguage) private var appLanguage

    private var visiblePrayers: [NoorPrayerTime] {
        (prayerModel.data?.times ?? []).filter { $0.name != .sunrise }
    }

    private var timeFormat: NoorTimeFormatSetting {
        NoorTimeFormatSetting.fromStorage(
            NoorSharedDefaults.shared.string(forKey: NoorSharedKeys.timeFormat))
    }

    private var locale: Locale {
        appLanguage == .arabic ? Locale(identifier: "ar") : Locale(identifier: "en")
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(AppStrings.t("label_timeline", appLanguage))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))

            VStack(spacing: 0) {
                ForEach(Array(visiblePrayers.enumerated()), id: \.offset) { index, prayer in
                    let isPast = prayer.time <= prayerModel.now
                    HStack(spacing: 16) {
                        Text(
                            NoorPrayerTimeFormatter.format(
                                prayer.time, timeFormat: timeFormat, locale: locale)
                        )
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(isPast ? .white.opacity(0.5) : .white)
                        .frame(width: 70, alignment: .trailing)

                        VStack(spacing: 0) {
                            Circle()
                                .fill(isPast ? Color.yellow.opacity(0.5) : Color.yellow)
                                .frame(width: isPast ? 10 : 14, height: isPast ? 10 : 14)
                            if index < visiblePrayers.count - 1 {
                                Rectangle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: 2, height: 40)
                            }
                        }

                        Text(prayer.name.english.uppercased())
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(isPast ? .white.opacity(0.5) : .white)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if isPast {
                            Text("✓")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.yellow.opacity(0.5))
                        }
                    }
                }
            }
        }
        .padding(.vertical, 20)
    }
}

struct QiblaFacePreview: View {
    @EnvironmentObject private var prayerModel: PrayerTimesViewModel
    @State private var direction: Double?

    var body: some View {
        Group {
            if let direction = direction {
                ZStack {
                    NoorDialBackground(size: 140)

                    ForEach(0..<12) { i in
                        let angle = Double(i) * 30.0
                        let isNorth = i == 0
                        VStack {
                            Text(isNorth ? "N" : "")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(isNorth ? .yellow : .white)
                            Rectangle()
                                .fill(isNorth ? .yellow : .white.opacity(0.5))
                                .frame(width: isNorth ? 2 : 1, height: 9)
                            Spacer()
                        }
                        .rotationEffect(.degrees(angle))
                    }
                    .frame(width: 140, height: 140)

                    VStack(spacing: 0) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.yellow)
                        Circle()
                            .fill(.yellow)
                            .frame(width: 7, height: 7)
                    }
                    .rotationEffect(.degrees(direction))
                    .shadow(color: .yellow.opacity(0.5), radius: 8)

                    VStack {
                        Text("\(Int(direction.rounded()))°")
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("QIBLA")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            } else {
                QiblaNotAvailableView()
            }
        }
        .frame(width: 140, height: 140)
        .onAppear(perform: calculateQibla)

        .onChange(of: prayerModel.locationName) { _ in calculateQibla() }
    }

    private func calculateQibla() {
        let defaults = NoorSharedDefaults.shared
        let lat = defaults.double(forKey: NoorSharedKeys.lastLatitude)
        let lon = defaults.double(forKey: NoorSharedKeys.lastLongitude)

        if lat != 0 || lon != 0 {
            let coordinates = Coordinates(latitude: lat, longitude: lon)
            self.direction = Qibla(coordinates: coordinates).direction
        } else {
            self.direction = nil
        }
    }
}

// MARK: - Weather Cards (unchanged)
struct WeatherDetailFace: View {
    @ObservedObject var model: WeatherViewModel
    @Environment(\.appLanguage) private var appLanguage

    private var unit: NoorTemperatureUnit {
        model.unit

    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(
                    model.snapshot == nil
                        ? "—"
                        : (NoorSharedDefaults.shared.string(
                            forKey: NoorSharedKeys.lastLocationName) ?? "—")
                )
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                Spacer()
                if let snapshot = model.snapshot {
                    Image(systemName: snapshot.symbolName)
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(NoorDesignSystem.textPrimary)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(
                    model.snapshot.map {
                        NoorTemperatureFormatter.format($0.temperatureC, unit: unit)
                    } ?? "--"
                )
                .font(.system(size: 42, weight: .heavy, design: .rounded))
                .foregroundStyle(NoorDesignSystem.accentGold)
                Spacer()
                if let snapshot = model.snapshot, let high = snapshot.highC,
                    let low = snapshot.lowC
                {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("H: " + NoorTemperatureFormatter.format(high, unit: unit))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(NoorDesignSystem.textSecondary)
                        Text("L: " + NoorTemperatureFormatter.format(low, unit: unit))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(NoorDesignSystem.textSecondary)
                    }
                }
            }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Date(), style: .time)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(NoorDesignSystem.textPrimary)
                    Text(Date.now, format: Date.FormatStyle().day().month().year())
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(NoorDesignSystem.textTertiary)
                }
                Spacer()
                Text("Updated now")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(NoorDesignSystem.textTertiary)
            }
        }
        .onAppear { model.refreshIfPossible() }
    }
}

struct WeatherSimpleFace: View {
    @ObservedObject var model: WeatherViewModel

    private var unit: NoorTemperatureUnit {
        model.unit
    }

    var body: some View {
        VStack(spacing: 8) {
            if let snapshot = model.snapshot {
                Image(systemName: snapshot.symbolName)
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(NoorDesignSystem.textPrimary)
            }
            Text(
                model.snapshot.map {
                    NoorTemperatureFormatter.format($0.temperatureC, unit: unit)
                } ?? "--"
            )
            .font(.system(size: 38, weight: .heavy, design: .rounded))
            .foregroundStyle(NoorDesignSystem.accentGold)
            Text(model.snapshot?.condition ?? "Weather")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(NoorDesignSystem.textSecondary)
        }
        .frame(width: 140, height: 140)
    }
}

struct WeatherCompactFace: View {
    @ObservedObject var model: WeatherViewModel

    private var unit: NoorTemperatureUnit {
        model.unit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let snapshot = model.snapshot {
                    Image(systemName: snapshot.symbolName)
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(NoorDesignSystem.textPrimary)
                }
                Text(
                    NoorSharedDefaults.shared.string(forKey: NoorSharedKeys.lastLocationName)
                        ?? "—"
                )
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(NoorDesignSystem.textSecondary)
            }
            Text(
                model.snapshot.map {
                    NoorTemperatureFormatter.format($0.temperatureC, unit: unit)
                } ?? "--"
            )
            .font(.system(size: 36, weight: .heavy, design: .rounded))
            .foregroundStyle(NoorDesignSystem.accentGold)
            if let snapshot = model.snapshot, let high = snapshot.highC, let low = snapshot.lowC {
                Text(
                    "H: " + NoorTemperatureFormatter.format(high, unit: unit) + "  L: "
                        + NoorTemperatureFormatter.format(low, unit: unit)
                )
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(NoorDesignSystem.textSecondary)
            }
            Spacer()
        }
        .frame(width: 140, height: 140)
    }
}

struct WeatherThuluthFace: View {
    @ObservedObject var model: WeatherViewModel
    @Environment(\.appLanguage) private var appLanguage

    private var unit: NoorTemperatureUnit {
        model.unit
    }

    private var locale: Locale {
        appLanguage == .arabic ? Locale(identifier: "ar") : Locale(identifier: "en")
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let scale = min(w / 310.0, h / 146.0)

            HStack(alignment: .center, spacing: 12 * scale) {
                VStack(alignment: .leading, spacing: 4 * scale) {
                    if let snapshot = model.snapshot {
                        HStack(spacing: 5 * scale) {
                            Image(systemName: snapshot.symbolName)
                                .font(.system(size: 36 * scale, weight: .regular))
                                .foregroundStyle(NoorDesignSystem.textPrimary)

                            Text(
                                model.snapshot.map {
                                    NoorTemperatureFormatter.format($0.temperatureC, unit: unit)
                                } ?? "--"
                            )
                            .font(.system(size: 24 * scale, weight: .heavy, design: .rounded))
                            .foregroundStyle(NoorDesignSystem.accentGold)
                        }
                    } else {
                        Text("--")
                            .font(.system(size: 24 * scale, weight: .heavy, design: .rounded))
                            .foregroundStyle(NoorDesignSystem.accentGold)
                    }

                    VStack(alignment: .leading, spacing: 2 * scale) {
                        if let snapshot = model.snapshot {
                            Text(snapshot.condition)
                                .font(
                                    .system(size: 11 * scale, weight: .semibold, design: .rounded)
                                )
                                .foregroundStyle(NoorDesignSystem.textSecondary)
                                .lineLimit(1).minimumScaleFactor(0.8)
                        }
                        if let snapshot = model.snapshot, let high = snapshot.highC,
                            let low = snapshot.lowC
                        {
                            Text(
                                "H: " + NoorTemperatureFormatter.format(high, unit: unit) + "  L: "
                                    + NoorTemperatureFormatter.format(low, unit: unit)
                            )
                            .font(.system(size: 10 * scale, weight: .semibold, design: .rounded))
                            .foregroundStyle(NoorDesignSystem.textTertiary)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2 * scale) {
                    Text(
                        NoorSharedDefaults.shared.string(forKey: NoorSharedKeys.lastLocationName)
                            ?? "—"
                    )
                    .font(.system(size: 11 * scale, weight: .bold, design: .rounded))
                    .foregroundStyle(NoorDesignSystem.textSecondary)
                    .lineLimit(1)

                    Text(weekdayNameFull(Date(), locale: locale))
                        .font(.custom("DecoType Thuluth", size: 18 * scale))
                        .foregroundStyle(NoorDesignSystem.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Spacer().frame(height: 4 * scale)

                    Text(Date(), style: .time)
                        .font(.system(size: 14 * scale, weight: .bold, design: .rounded))
                        .foregroundStyle(NoorDesignSystem.textPrimary)
                    Text(Date.now, format: Date.FormatStyle().day().month())
                        .font(.system(size: 10 * scale, weight: .semibold, design: .rounded))
                        .foregroundStyle(NoorDesignSystem.textTertiary)
                }
            }
            .padding(.horizontal, 14 * scale)
            .padding(.vertical, 10 * scale)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - QuranVerseCard (unchanged)
struct QuranVerseCard: View {
    let verse: QuranVerse
    @State private var isSaved = false
    @Environment(\.appLanguage) private var appLanguage

    var body: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Text(verse.arabic)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.yellow)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .multilineTextAlignment(.trailing)

                Text("\"\(verse.translation)\"")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                HStack {
                    Text(verse.surah.uppercased())
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Text(verse.ayah)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 170)
            .background(
                LinearGradient(
                    colors: [Color(white: 0.1), Color(white: 0.05)], startPoint: .topLeading,
                    endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(
                    Color.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.6), radius: 24, x: 0, y: 12)

            Text("\(verse.surah) \(verse.ayah)")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

struct QiblaNotAvailableView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 24))
                .foregroundStyle(.white.opacity(0.5))
            Text("Set Location in Settings")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Helpers (unchanged)
func monthName(_ date: Date) -> String {
    let f = DateFormatter()
    f.setLocalizedDateFormatFromTemplate("MMMM")
    return f.string(from: date)
}
func shortMonth(_ date: Date) -> String {
    let f = DateFormatter()
    f.setLocalizedDateFormatFromTemplate("MMM")
    return f.string(from: date)
}
func weekdayName(_ date: Date) -> String {
    let f = DateFormatter()
    f.setLocalizedDateFormatFromTemplate("EEEE")
    return f.string(from: date)
}
func weekdayNameFull(_ date: Date, locale: Locale = .current) -> String {
    let f = DateFormatter()
    f.locale = locale
    f.setLocalizedDateFormatFromTemplate("EEEE")
    return f.string(from: date)
}
func dayNumber(_ date: Date) -> String {
    let f = DateFormatter()
    f.setLocalizedDateFormatFromTemplate("d")
    return f.string(from: date)
}
func yearNumber(_ date: Date) -> String {
    let f = DateFormatter()
    f.setLocalizedDateFormatFromTemplate("y")
    return f.string(from: date)
}
func arabicDigits(_ number: Int) -> String {
    let nf = NumberFormatter()
    nf.locale = Locale(identifier: "ar")
    return nf.string(from: NSNumber(value: number)) ?? String(number)
}
func hijriMonthName(_ date: Date) -> String {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .islamicUmmAlQura)
    f.locale = Locale(identifier: "ar")
    f.setLocalizedDateFormatFromTemplate("MMMM")
    return f.string(from: date)
}

private func clockAngles(from date: Date) -> (hour: Double, minute: Double, second: Double) {
    let components = Calendar.current.dateComponents(
        [.hour, .minute, .second, .nanosecond], from: date)
    let hour = Double(components.hour ?? 0)
    let minute = Double(components.minute ?? 0)
    let second = Double(components.second ?? 0)
    let nanosecond = Double(components.nanosecond ?? 0)

    let preciseSecond = second + nanosecond / 1_000_000_000
    let preciseMinute = minute + preciseSecond / 60
    let preciseHour = (hour.truncatingRemainder(dividingBy: 12)) + preciseMinute / 60

    let hourAngle = preciseHour / 12 * 360
    let minuteAngle = preciseMinute / 60 * 360
    let secondAngle = preciseSecond / 60 * 360

    return (hourAngle, minuteAngle, secondAngle)
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
