//
//  GameplayFeedback.swift
//  Pyxis
//

import Foundation

/// Semantic gameplay feedback events carried without interpretation by HPA-364.
enum GameplayFeedbackEvent: Equatable {
    case manualDeployment
    case soldierAttack(SoldierAttackSoundCategory)
    case towerFire
    case soldierDamage(SoldierDamageSoundKind)
    case buildingChanged
    case invalidAction
    case goldReward
    case cityConquest
    case countryCompletion

    /// Unreachable until HPA-362 supplies the producer.
    case fortifiedLaneWarning
}

/// HPA-389 maps Infantry/Cavalry to melee, Archer/Mage to ranged, and Siege to siege;
/// magic has no separate category. `allCases` exists for completeness only.
enum SoldierAttackSoundCategory: CaseIterable, Equatable {
    case melee
    case ranged
    case siege
}

enum SoldierDamageSoundKind: Equatable {
    case hit
    case death
}

/// HPA-364 preserves event identity and order, performing no validation, projection,
/// selection, throttling, queueing, or playback.
protocol GameplayFeedbackProviding: AnyObject {
    func emit(_ event: GameplayFeedbackEvent)

    /// Emits one caller-ordered batch per authoritative combat tick.
    func emitAutomaticCombat(_ orderedEvents: [GameplayFeedbackEvent])
}

final class NoOpGameplayFeedbackProvider: GameplayFeedbackProviding {
    func emit(_ event: GameplayFeedbackEvent) {}
    func emitAutomaticCombat(_ orderedEvents: [GameplayFeedbackEvent]) {}
}

protocol MonotonicClock {
    var now: TimeInterval { get }
}

struct SystemMonotonicClock: MonotonicClock {
    var now: TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }
}
