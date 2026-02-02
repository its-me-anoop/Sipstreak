import Foundation

enum UnitSystem: String, Codable, CaseIterable {
    case metric
    case imperial

    var volumeUnit: String {
        switch self {
        case .metric: return "ml"
        case .imperial: return "oz"
        }
    }

    var bodyWeightUnit: String {
        switch self {
        case .metric: return "kg"
        case .imperial: return "lb"
        }
    }

    func ml(from amount: Double) -> Double {
        switch self {
        case .metric:
            return amount
        case .imperial:
            return amount * 29.5735
        }
    }

    func amount(fromML ml: Double) -> Double {
        switch self {
        case .metric:
            return ml
        case .imperial:
            return ml / 29.5735
        }
    }

    func kg(from amount: Double) -> Double {
        switch self {
        case .metric:
            return amount
        case .imperial:
            return amount * 0.453592
        }
    }

    func amountFromKG(_ kg: Double) -> Double {
        switch self {
        case .metric:
            return kg
        case .imperial:
            return kg / 0.453592
        }
    }
}
