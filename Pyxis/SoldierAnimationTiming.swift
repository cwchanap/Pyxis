import Foundation

enum SoldierAnimationAction: String, CaseIterable, Hashable {
    case walk
    case attack
    case hit
}

struct SoldierAnimationTiming {
    static let frameCount = 10

    private static let attackWeights = [1.10, 1.20, 1.30, 0.75, 0.70, 0.85, 1.00, 1.15, 1.10, 0.85]
    private static let hitWeights = [0.90, 1.00, 1.10, 1.20, 1.20, 1.00, 0.95, 0.90, 0.90, 0.85]

    static func totalDuration(
        for action: SoldierAnimationAction,
        type: SoldierType
    ) -> TimeInterval {
        switch action {
        case .walk:
            1.0
        case .hit:
            0.9
        case .attack:
            switch type {
            case .infantry, .cavalry: 1.2
            case .archer, .mage: 1.4
            case .siege: 1.6
            }
        }
    }

    static func frameDurations(
        for action: SoldierAnimationAction,
        type: SoldierType
    ) -> [TimeInterval] {
        let weights: [Double]
        switch action {
        case .walk: weights = Array(repeating: 1, count: frameCount)
        case .attack: weights = attackWeights
        case .hit: weights = hitWeights
        }
        let unit = totalDuration(for: action, type: type) / weights.reduce(0, +)
        return weights.map { $0 * unit }
    }
}
