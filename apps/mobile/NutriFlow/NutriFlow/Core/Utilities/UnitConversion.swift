import Foundation

struct UnitConversion {

    static let gramsPerOunce = 28.35
    static let mlPerFluidOunce = 29.5735
    static let kgPerPound = 0.45359237
    static let cmPerInch = 2.54
    static let kjPerKcal = 4.184
    static let nutritionFractionDigits = 1
    static let portionFractionDigits = 3

    /// Nutrition values persisted by food and goal APIs use PostgreSQL numeric(10, 1).
    static func roundedForNutritionStorage(_ value: Double) -> Double {
        let multiplier = pow(10, Double(nutritionFractionDigits))
        return (value * multiplier).rounded() / multiplier
    }

    /// Accepts only the decimal precision and range that numeric(10, 1) can store.
    static func isValidNutritionInput(
        _ text: String,
        maximumFractionDigits: Int = nutritionFractionDigits
    ) -> Bool {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        let parts = normalized.split(separator: ".", omittingEmptySubsequences: false)

        guard parts.count <= 2,
              let integerPart = parts.first,
              integerPart.count <= 9,
              integerPart.allSatisfy(\.isNumber) else {
            return false
        }

        guard parts.count == 2 else { return true }

        let fractionalPart = parts[1]
        return fractionalPart.count <= maximumFractionDigits
            && fractionalPart.allSatisfy(\.isNumber)
    }

    static func isVolumeUnit(_ unit: String?) -> Bool {
        unit == "ml" || unit == "l"
    }

    static func displayUnit(for baseUnit: String, preferred: PreferredUnits) -> String {
        if isVolumeUnit(baseUnit) {
            return preferred.volume == .imperial ? "fl oz" : "ml"
        }

        return preferred.weight == .imperial ? "oz" : "g"
    }

    /// Formats values stored by food APIs with up to one fractional digit.
    static func formatNutritionValue(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...nutritionFractionDigits)))
    }

    static func formatMetricValue(_ value: Double) -> String {
        formatNutritionValue(value)
    }

    static func grams(fromOunces ounces: Double) -> Double {
        ounces * gramsPerOunce
    }

    static func ounces(fromGrams grams: Double) -> Double {
        grams / gramsPerOunce
    }

    /// Formats kilogram values with up to three fractional digits.
    static func formatKilogramValue(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...3)))
    }

    /// Formats imperial values with up to three fractional digits.
    static func formatImperialValue(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...3)))
    }

    static func formatAmount(grams: Double, unit: String, preferred: PreferredUnits) -> String {
        if isVolumeUnit(unit) {
            switch preferred.volume {
            case .imperial:
                return "\(formatImperialValue(grams / mlPerFluidOunce)) fl oz"

            case .metric:
                if grams >= 1000 {
                    return "\(formatMetricValue(grams / 1000)) l"
                }

                return "\(formatMetricValue(grams)) ml"
            }
        }

        switch preferred.weight {
        case .imperial:
            let ounces = grams / gramsPerOunce

            if ounces >= 16 {
                return "\(formatImperialValue(ounces / 16)) lb"
            }

            return "\(formatImperialValue(ounces)) oz"

        case .metric:
            if grams >= 1000 {
                return "\(formatKilogramValue(grams / 1000)) kg"
            }

            return "\(formatMetricValue(grams)) g"
        }
    }

    static func formatAmount(grams: Int, unit: String, preferred: PreferredUnits) -> String {
        formatAmount(grams: Double(grams), unit: unit, preferred: preferred)
    }

    static func formatMacro(grams: Double, preferred: PreferredUnits) -> String {
        formatAmount(grams: grams, unit: "g", preferred: preferred)
    }

    static func formatMacro(grams: Int, preferred: PreferredUnits) -> String {
        formatMacro(grams: Double(grams), preferred: preferred)
    }

    static func formatEnergy(kcal: Double, preferred: PreferredUnits) -> String {
        "\(formatEnergyValueText(kcal: kcal, preferred: preferred)) \(formatEnergyUnit(preferred: preferred))"
    }

    static func formatEnergyValueText(kcal: Double, preferred: PreferredUnits) -> String {
        formatMetricValue(formatEnergyValue(kcal: kcal, preferred: preferred))
    }

    static func formatEnergyValue(kcal: Double, preferred: PreferredUnits) -> Double {
        switch preferred.energy {
        case .kj:
            kcal * kjPerKcal
        case .kcal:
            kcal
        }
    }

    static func formatEnergy(kcal: Int, preferred: PreferredUnits) -> String {
        formatEnergy(kcal: Double(kcal), preferred: preferred)
    }

    static func formatEnergyValue(kcal: Int, preferred: PreferredUnits) -> Int {
        Int(formatEnergyValue(kcal: Double(kcal), preferred: preferred).rounded())
    }

    static func formatEnergyUnit(preferred: PreferredUnits) -> String {
        switch preferred.energy {
        case .kj: "kJ"
        case .kcal: "kcal"
        }
    }

    /// User-entered value in the display unit -> canonical grams (or ml).
    static func grams(fromDisplay value: Double, baseUnit: String, preferred: PreferredUnits) -> Double {
        if isVolumeUnit(baseUnit) {
            return preferred.volume == .imperial ? value * mlPerFluidOunce : value
        }

        return preferred.weight == .imperial ? grams(fromOunces: value) : value
    }

    /// Canonical grams (or ml) -> value in the display unit.
    static func displayValue(fromGrams grams: Double, baseUnit: String, preferred: PreferredUnits) -> Double {
        if isVolumeUnit(baseUnit) {
            return preferred.volume == .imperial ? grams / mlPerFluidOunce : grams
        }

        return preferred.weight == .imperial ? ounces(fromGrams: grams) : grams
    }

    /// Keeps converted display values precise enough to round-trip to stored grams.
    static func formatDisplayValue(_ value: Double, displayUnit: String) -> String {
        switch displayUnit {
        case "oz", "lb", "fl oz":
            formatImperialValue(value)
        case "kg":
            formatKilogramValue(value)
        default:
            formatNutritionValue(value)
        }
    }

    static func bodyWeightUnitLabel(preferred: PreferredUnits) -> String {
        preferred.weight == .imperial ? "lb" : "kg"
    }

    static func bodyWeightToDisplay(kg: Double, preferred: PreferredUnits) -> Double {
        preferred.weight == .imperial ? kg / kgPerPound : kg
    }

    /// Converts a displayed body weight to the backend's canonical kilograms.
    static func bodyWeightToKg(_ value: Double, preferred: PreferredUnits) -> Double {
        let kilograms = preferred.weight == .imperial ? value * kgPerPound : value
        return (kilograms * 100).rounded() / 100
    }

    static func formatBodyWeight(kg: Double, preferred: PreferredUnits) -> String {
        let value = bodyWeightToDisplay(kg: kg, preferred: preferred)

        return preferred.weight == .imperial
            ? formatImperialValue(value)
            : formatKilogramValue(value)
    }

    static func heightUnitLabel(preferred: PreferredUnits) -> String {
        preferred.weight == .imperial ? "in" : "cm"
    }

    static func heightToDisplay(cm: Double, preferred: PreferredUnits) -> Double {
        preferred.weight == .imperial ? cm / cmPerInch : cm
    }

    static func heightToCm(_ value: Double, preferred: PreferredUnits) -> Double {
        preferred.weight == .imperial ? value * cmPerInch : value
    }

    static func energyToKcal(_ value: Double, preferred: PreferredUnits) -> Double {
        preferred.energy == .kj ? value / kjPerKcal : value
    }

    /// Parses user-entered decimal text, tolerating comma as decimal separator.
    static func parseDecimal(_ text: String) -> Double? {
        guard !text.isEmpty else { return nil }
        return Double(text.replacingOccurrences(of: ",", with: "."))
    }

    /// Canonical grams (or ml) for a user-entered display value, falling back when invalid.
    static func grams(fromText text: String, baseUnit: String, fallback: Double, preferred: PreferredUnits) -> Double {
        guard let value = parseDecimal(text), value > 0 else { return fallback }
        return grams(fromDisplay: value, baseUnit: baseUnit, preferred: preferred)
    }

    /// Macro amount in the display unit -> canonical grams (or ml).
    static func macroGrams(fromDisplay text: String, preferred: PreferredUnits) -> Double? {
        guard let value = parseDecimal(text) else { return nil }
        return preferred.weight == .imperial ? grams(fromOunces: value) : value
    }

    /// Macro grams -> display value.
    static func macroDisplay(grams: Double, preferred: PreferredUnits) -> String {
        let value = preferred.weight == .imperial
            ? grams / gramsPerOunce
            : grams

        return preferred.weight == .imperial
            ? formatImperialValue(value)
            : formatNutritionValue(value)
    }

    /// Re-expresses a user-entered amount when the preferred unit system changes.
    static func convertWeightText(
        _ text: String,
        from old: PreferredUnits,
        to new: PreferredUnits,
        baseUnit: String = "g"
    ) -> String {
        let dimensionChanged = isVolumeUnit(baseUnit)
            ? old.volume != new.volume
            : old.weight != new.weight

        guard dimensionChanged, let value = parseDecimal(text) else {
            return text
        }

        let canonical = grams(fromDisplay: value, baseUnit: baseUnit, preferred: old)
        let display = displayValue(fromGrams: canonical, baseUnit: baseUnit, preferred: new)

        return formatDisplayValue(
            display,
            displayUnit: displayUnit(for: baseUnit, preferred: new)
        )
    }

    /// Same as convertWeightText, for an energy value moving between kcal and kJ.
    static func convertEnergyText(
        _ text: String,
        from old: PreferredUnits,
        to new: PreferredUnits
    ) -> String {
        guard old.energy != new.energy, let value = parseDecimal(text) else {
            return text
        }

        let kcal = energyToKcal(value, preferred: old)
        let display = new.energy == .kj ? kcal * kjPerKcal : kcal

        return formatMetricValue(display)
    }
}

