//
//  GameplayFeedback.swift
//  Pyxis
//

import Foundation

/// Discrete gameplay feedback events carried without interpretation by HPA-364.
enum GameplayFeedbackEvent: Hashable {
    case manualDeployment
    case buildingChanged
    case invalidAction
    case goldReward
    case cityConquest
    case countryCompletion
}

/// HPA-364 preserves discrete event identity, performing no validation, selection,
/// throttling, queueing, or playback.
protocol GameplayFeedbackProviding: AnyObject {
    func emit(_ event: GameplayFeedbackEvent)
    func emitAutomaticCombat(_ result: BattleCombatState.TickResult)
}

final class NoOpGameplayFeedbackProvider: GameplayFeedbackProviding {
    func emit(_ event: GameplayFeedbackEvent) {}
    func emitAutomaticCombat(_ result: BattleCombatState.TickResult) {}
}

protocol MonotonicClock {
    var now: TimeInterval { get }
}

struct SystemMonotonicClock: MonotonicClock {
    var now: TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }
}
