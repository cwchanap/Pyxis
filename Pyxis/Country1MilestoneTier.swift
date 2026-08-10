enum Country1MilestoneTier: Int, Equatable {
    case first = 1
    case second = 2
    case finale = 3

    static func forCity(_ cityNumber: Int) -> Country1MilestoneTier? {
        if cityNumber == KingdomGameState.firstCountryCityCount {
            return .finale
        }
        switch cityNumber {
        case 5:
            return .first
        case 10:
            return .second
        default:
            return nil
        }
    }

    var isCountryFinale: Bool {
        self == .finale
    }
}
