import Foundation

struct UnitConversion {

    // MARK: - Canonical factors (single source of truth)

    static let gramsPerOunce = 28.35
    static let mlPerFluidOunce = 29.5735
    static let kgPerPound = 0.45359237
    static let cmPerInch = 2.54
    static let kjPerKcal = 4.184

    // MARK: - Unit classification

    static func isVolumeUnit(_ unit: String?) -> Bool {
        unit == "ml" || unit == "l"
    }

    static func displayUnit(for baseUnit: String, preferred: PreferredUnits) -> String {
        if isVolumeUnit(baseUnit) {
            return preferred.volume == .imperial ? "fl oz" : "ml"
        }
        return preferred.weight == .imperial ? "oz" : "g"
    }

    // MARK: - Display formatting

    static func formatAmount(grams: Int, unit: String, preferred: PreferredUnits) -> String {
        if isVolumeUnit(unit) {
            switch preferred.volume {
            case .imperial:
                let flOz = Double(grams) / mlPerFluidOunce
                return "\(String(format: "%.1f", flOz)) fl oz"
            case .metric:
                if grams >= 1000 {
                    let liters = Double(grams) / 1000.0
                    return "\(String(format: "%.1f", liters)) l"
                }
                return "\(grams) ml"
            }
        }

        switch preferred.weight {
        case .imperial:
            let oz = Double(grams) / gramsPerOunce
            if oz >= 16 {
                let lb = oz / 16
                return "\(String(format: "%.1f", lb)) lb"
            }
            return "\(String(format: "%.1f", oz)) oz"
        case .metric:
            if grams >= 1000 {
                let kg = Double(grams) / 1000.0
                return "\(String(format: "%.1f", kg)) kg"
            }
            return "\(grams) g"
        }
    }

    static func formatMacro(grams: Int, preferred: PreferredUnits) -> String {
        formatAmount(grams: grams, unit: "g", preferred: preferred)
    }

    static func formatEnergy(kcal: Int, preferred: PreferredUnits) -> String {
        switch preferred.energy {
        case .kj:
            let kj = Int(Double(kcal) * kjPerKcal)
            return "\(kj) kJ"
        case .kcal:
            return "\(kcal) kcal"
        }
    }

    static func formatEnergyValue(kcal: Int, preferred: PreferredUnits) -> Int {
        switch preferred.energy {
        case .kj:
            return Int(Double(kcal) * kjPerKcal)
        case .kcal:
            return kcal
        }
    }

    static func formatEnergyUnit(preferred: PreferredUnits) -> String {
        switch preferred.energy {
        case .kj: "kJ"
        case .kcal: "kcal"
        }
    }

    // MARK: - Bidirectional amount conversion (display <-> canonical grams/ml)

    /// User-entered value in the display unit -> canonical grams (or ml).
    static func grams(fromDisplay value: Double, baseUnit: String, preferred: PreferredUnits) -> Double {
        if isVolumeUnit(baseUnit) {
            return preferred.volume == .imperial ? value * mlPerFluidOunce : value
        }
        return preferred.weight == .imperial ? value * gramsPerOunce : value
    }

    /// Canonical grams (or ml) -> value in the display unit.
    static func displayValue(fromGrams grams: Double, baseUnit: String, preferred: PreferredUnits) -> Double {
        if isVolumeUnit(baseUnit) {
            return preferred.volume == .imperial ? grams / mlPerFluidOunce : grams
        }
        return preferred.weight == .imperial ? grams / gramsPerOunce : grams
    }

    static func formatDisplayValue(_ value: Double, displayUnit: String) -> String {
        switch displayUnit {
        case "fl oz", "oz":
            return String(format: "%.2f", value)
        default:
            return String(Int(value.rounded()))
        }
    }

    // MARK: - Body weight / height (canonical: kg, cm)

    static func bodyWeightUnitLabel(preferred: PreferredUnits) -> String {
        preferred.weight == .imperial ? "lb" : "kg"
    }

    static func bodyWeightToDisplay(kg: Double, preferred: PreferredUnits) -> Double {
        preferred.weight == .imperial ? kg / kgPerPound : kg
    }

    static func bodyWeightToKg(_ value: Double, preferred: PreferredUnits) -> Double {
        preferred.weight == .imperial ? value * kgPerPound : value
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

    // MARK: - Energy (canonical: kcal)

    static func energyToKcal(_ value: Double, preferred: PreferredUnits) -> Double {
        preferred.energy == .kj ? value / kjPerKcal : value
    }
}
