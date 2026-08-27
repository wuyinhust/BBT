import Foundation

enum AppLanguage: String, CaseIterable {
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case english = "en"

    #if DEBUG
    static let auditOverrideKey = "bb_ui_audit_language_override_v1"
    #endif

    var displayName: String {
        switch self {
        case .simplifiedChinese: return "简体中文"
        case .traditionalChinese: return "繁體中文"
        case .english: return "English"
        }
    }

    static var current: AppLanguage {
        #if DEBUG
        if let override = UserDefaults.standard.string(forKey: auditOverrideKey),
           let language = AppLanguage(rawValue: override) {
            return language
        }
        #endif

        let preferred = Bundle.main.preferredLocalizations.first
            ?? Locale.autoupdatingCurrent.language.languageCode?.identifier
            ?? AppLanguage.simplifiedChinese.rawValue

        if preferred.hasPrefix("zh-Hant") || preferred.hasPrefix("zh-TW") || preferred.hasPrefix("zh-HK") {
            return .traditionalChinese
        }
        if preferred.hasPrefix("en") {
            return .english
        }
        return .simplifiedChinese
    }
}

enum AppSemanticIcon {
    static let language = "globe"
    static let measurement = "ruler"
    static let basicMode = "list.bullet.rectangle"
    static let easyMode = "repeat"
    static let recommended = "star.fill"
}

enum MeasurementSystemPreference: String, CaseIterable, Identifiable {
    case followRegion
    case metric
    case imperial

    static let storageKey = "measurement_system_preference_v1"
    static let appGroupID = "group.73AUQDMCJ2.babybuddy"
    static let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
    static var testingOverride: MeasurementSystemPreference?

    var id: String { rawValue }

    static var current: MeasurementSystemPreference {
        if let testingOverride {
            return testingOverride
        }
        guard let rawValue = defaults.string(forKey: storageKey),
              let preference = MeasurementSystemPreference(rawValue: rawValue) else {
            return .followRegion
        }
        return preference
    }

    var title: String {
        switch self {
        case .followRegion: return "跟随地区".localized
        case .metric: return "公制".localized
        case .imperial: return "英制".localized
        }
    }
}

enum AppResolvedMeasurementSystem: Equatable {
    case metric
    case imperial
}

/// The single localization entry point for text that is assembled outside a
/// SwiftUI `Text` initializer. Static SwiftUI strings continue to use Apple's
/// native String Catalog lookup automatically.
enum AppLocalization {
    static var language: AppLanguage { AppLanguage.current }

    /// Keeps the user's regional calendar and number separators while applying
    /// the language selected for this app and BBBuddy's app-wide 24-hour clock.
    static var locale: Locale {
        var components = Locale.Components(locale: .autoupdatingCurrent)
        components.languageComponents = Locale.Language.Components(identifier: language.rawValue)
        components.hourCycle = .zeroToTwentyThree
        return Locale(components: components)
    }

    static func string(_ key: String, table: String? = nil) -> String {
        #if DEBUG
        if let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
           let languageBundle = Bundle(path: path) {
            return languageBundle.localizedString(forKey: key, value: key, table: table)
        }
        #endif
        return Bundle.main.localizedString(forKey: key, value: key, table: table)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), locale: locale, arguments: arguments)
    }

    static func list(_ values: [String]) -> String {
        let formatter = ListFormatter()
        formatter.locale = locale
        return formatter.string(from: values) ?? values.joined(separator: ", ")
    }
}

extension String {
    /// Use for model-owned display strings. Unknown keys intentionally fall
    /// back to the original value, so user-entered names and notes are never
    /// modified.
    var localized: String { AppLocalization.string(self) }
}

enum AppQuantityFormat {
    static func minutes(_ value: Int) -> String {
        AppLocalization.format(value == 1 ? "quantity.minute.one" : "quantity.minute.other", value)
    }

    static func hours(_ value: Int) -> String {
        AppLocalization.format(value == 1 ? "quantity.hour.one" : "quantity.hour.other", value)
    }

    static func hoursAndMinutes(_ totalMinutes: Int) -> String {
        let safeMinutes = max(totalMinutes, 0)
        let hours = safeMinutes / 60
        let minutes = safeMinutes % 60

        if hours == 0 { return self.minutes(minutes) }
        if minutes == 0 { return self.hours(hours) }
        return AppLocalization.format("quantity.duration.hours_minutes", hours, minutes)
    }

    /// Fixed-width-friendly duration text for compact home summaries.
    /// Unlike the localized quantity helpers above, home cards always use
    /// Latin `m`/`h` units so the layout stays compact in every locale.
    static func compactDuration(_ totalMinutes: Int) -> String {
        let safeMinutes = max(totalMinutes, 0)
        let hours = safeMinutes / 60
        let minutes = safeMinutes % 60

        if hours == 0 { return "\(minutes)m" }
        return minutes == 0 ? "\(hours)h" : "\(hours)h\(minutes)m"
    }

    static func records(_ value: Int) -> String {
        AppLocalization.format(value == 1 ? "quantity.record.one" : "quantity.record.other", value)
    }

    static func days(_ value: Int) -> String {
        AppLocalization.format(value == 1 ? "quantity.day.one" : "quantity.day.other", value)
    }

    static func people(_ value: Int) -> String {
        AppLocalization.format(value == 1 ? "quantity.person.one" : "quantity.person.other", value)
    }

    static func photos(_ value: Int) -> String {
        AppLocalization.format(value == 1 ? "quantity.photo.one" : "quantity.photo.other", value)
    }
}

/// Centralizes presentation-unit conversion while keeping every persisted
/// value in the app's canonical metric representation (kg, cm, ml and g).
enum AppMeasurementFormat {
    static func resolvedSystem(
        preference: MeasurementSystemPreference = .current,
        locale: Locale = AppLocalization.locale
    ) -> AppResolvedMeasurementSystem {
        switch preference {
        case .metric:
            return .metric
        case .imperial:
            return .imperial
        case .followRegion:
            return locale.measurementSystem == .metric ? .metric : .imperial
        }
    }

    static var currentSystem: AppResolvedMeasurementSystem {
        resolvedSystem()
    }

    static var preferenceSummary: String {
        let preference = MeasurementSystemPreference.current
        guard preference == .followRegion else { return preference.title }
        let resolved = currentSystem == .metric ? "公制".localized : "英制".localized
        return AppLocalization.format("measurement.follow_region.summary", resolved)
    }

    static var heightUnit: String { currentSystem == .metric ? "cm" : "in" }
    static var weightPrimaryUnit: String { currentSystem == .metric ? "kg" : "lb" }
    static var weightSecondaryUnit: String { "oz" }
    static var volumeUnit: String { currentSystem == .metric ? "ml" : "fl oz" }
    static var massUnit: String { currentSystem == .metric ? "g" : "oz" }

    static func heightValue(fromCentimeters centimeters: Double) -> Double {
        guard currentSystem == .imperial else { return centimeters }
        return Measurement(value: centimeters, unit: UnitLength.centimeters)
            .converted(to: .inches).value
    }

    static func centimeters(fromHeightValue value: Double) -> Double {
        guard currentSystem == .imperial else { return value }
        return Measurement(value: value, unit: UnitLength.inches)
            .converted(to: .centimeters).value
    }

    static func poundsAndOunces(fromKilograms kilograms: Double) -> (pounds: Int, ounces: Double) {
        let totalOunces = Measurement(value: kilograms, unit: UnitMass.kilograms)
            .converted(to: .ounces).value
        var pounds = max(Int(floor(totalOunces / 16)), 0)
        var ounces = max(totalOunces - Double(pounds * 16), 0)
        ounces = (ounces * 10).rounded() / 10
        if ounces >= 16 {
            pounds += 1
            ounces = 0
        }
        return (pounds, ounces)
    }

    static func kilograms(pounds: Double, ounces: Double) -> Double {
        let totalOunces = max(pounds, 0) * 16 + max(ounces, 0)
        return Measurement(value: totalOunces, unit: UnitMass.ounces)
            .converted(to: .kilograms).value
    }

    static func volumeValue(fromMilliliters milliliters: Double) -> Double {
        guard currentSystem == .imperial else { return milliliters }
        return Measurement(value: milliliters, unit: UnitVolume.milliliters)
            .converted(to: .fluidOunces).value
    }

    static func milliliters(fromVolumeValue value: Double) -> Double {
        guard currentSystem == .imperial else { return value }
        return Measurement(value: value, unit: UnitVolume.fluidOunces)
            .converted(to: .milliliters).value
    }

    static func massValue(fromGrams grams: Double) -> Double {
        guard currentSystem == .imperial else { return grams }
        return Measurement(value: grams, unit: UnitMass.grams)
            .converted(to: .ounces).value
    }

    static func grams(fromMassValue value: Double) -> Double {
        guard currentSystem == .imperial else { return value }
        return Measurement(value: value, unit: UnitMass.ounces)
            .converted(to: .grams).value
    }

    static func height(_ centimeters: Double) -> String {
        "\(number(heightValue(fromCentimeters: centimeters), maximumFractionDigits: 1)) \(heightUnit)"
    }

    static func weight(_ kilograms: Double) -> String {
        guard currentSystem == .imperial else {
            return "\(number(kilograms, maximumFractionDigits: 2)) kg"
        }
        let value = poundsAndOunces(fromKilograms: kilograms)
        return "\(value.pounds) lb \(number(value.ounces, maximumFractionDigits: 1)) oz"
    }

    static func volume(_ milliliters: Double) -> String {
        let digits = currentSystem == .metric ? 0 : 1
        return "\(number(volumeValue(fromMilliliters: milliliters), maximumFractionDigits: digits)) \(volumeUnit)"
    }

    static func mass(_ grams: Double) -> String {
        let digits = currentSystem == .metric ? 0 : 1
        return "\(number(massValue(fromGrams: grams), maximumFractionDigits: digits)) \(massUnit)"
    }

    static func inputNumber(_ value: Double, maximumFractionDigits: Int = 1) -> String {
        number(value, maximumFractionDigits: maximumFractionDigits)
    }

    static func parseNumber(_ text: String) -> Double? {
        let formatter = NumberFormatter()
        formatter.locale = AppLocalization.locale
        formatter.numberStyle = .decimal
        if let value = formatter.number(from: text)?.doubleValue { return value }
        return Double(text.replacingOccurrences(of: ",", with: "."))
    }

    private static func number(_ value: Double, maximumFractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = AppLocalization.locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maximumFractionDigits
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}
