import Foundation

struct UnitConversion {

    static func formatAmount(grams: Int, unit: String, preferred: PreferredUnits) -> String {
        if unit == "ml" || unit == "l" {
            switch preferred.volume {
            case .imperial:
                let flOz = Double(grams) / 29.5735
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
            let oz = Double(grams) / 28.35
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
            let kj = Int(Double(kcal) * 4.184)
            return "\(kj) kJ"
        case .kcal:
            return "\(kcal) kcal"
        }
    }

    static func formatEnergyValue(kcal: Int, preferred: PreferredUnits) -> Int {
        switch preferred.energy {
        case .kj:
            return Int(Double(kcal) * 4.184)
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
}
