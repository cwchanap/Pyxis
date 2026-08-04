//
//  GameplayFeedbackPolicy.swift
//  Pyxis
//

enum GameplayFeedbackPolicy {
    static func directive(for event: GameplayFeedbackEvent) -> GameplayFeedbackDirective {
        switch event {
        case .manualDeployment:
            GameplayFeedbackDirective(
                sound: .deployment,
                soundClass: .nonAutomatic,
                soundGate: .deploymentSound,
                haptic: .lightImpact,
                hapticGate: .deploymentHaptic
            )
        case .soldierAttack(.melee):
            GameplayFeedbackDirective(
                sound: .attackMelee,
                soundClass: .automaticCombat,
                soundGate: nil,
                haptic: nil,
                hapticGate: nil
            )
        case .soldierAttack(.ranged):
            GameplayFeedbackDirective(
                sound: .attackRanged,
                soundClass: .automaticCombat,
                soundGate: nil,
                haptic: nil,
                hapticGate: nil
            )
        case .soldierAttack(.siege):
            GameplayFeedbackDirective(
                sound: .attackSiege,
                soundClass: .automaticCombat,
                soundGate: nil,
                haptic: nil,
                hapticGate: nil
            )
        case .towerFire:
            GameplayFeedbackDirective(
                sound: .towerFire,
                soundClass: .automaticCombat,
                soundGate: nil,
                haptic: nil,
                hapticGate: nil
            )
        case .soldierDamage(.hit):
            GameplayFeedbackDirective(
                sound: .soldierHit,
                soundClass: .automaticCombat,
                soundGate: nil,
                haptic: nil,
                hapticGate: nil
            )
        case .soldierDamage(.death):
            GameplayFeedbackDirective(
                sound: .soldierDeath,
                soundClass: .automaticCombat,
                soundGate: nil,
                haptic: nil,
                hapticGate: nil
            )
        case .buildingChanged:
            GameplayFeedbackDirective(
                sound: .construction,
                soundClass: .nonAutomatic,
                soundGate: .constructionSound,
                haptic: .mediumImpact,
                hapticGate: .constructionHaptic
            )
        case .invalidAction:
            GameplayFeedbackDirective(
                sound: .blocked,
                soundClass: .nonAutomatic,
                soundGate: .invalidSound,
                haptic: .warning,
                hapticGate: .invalidHaptic
            )
        case .goldReward:
            GameplayFeedbackDirective(
                sound: .goldReward,
                soundClass: .nonAutomatic,
                soundGate: nil,
                haptic: nil,
                hapticGate: nil
            )
        case .cityConquest:
            GameplayFeedbackDirective(
                sound: .cityConquest,
                soundClass: .nonAutomatic,
                soundGate: nil,
                haptic: .strongSuccess,
                hapticGate: nil
            )
        case .countryCompletion:
            GameplayFeedbackDirective(
                sound: .countryCompletion,
                soundClass: .nonAutomatic,
                soundGate: nil,
                haptic: .strongSuccess,
                hapticGate: nil
            )
        case .fortifiedLaneWarning:
            GameplayFeedbackDirective(
                sound: .fortifiedWarning,
                soundClass: .nonAutomatic,
                soundGate: .fortifiedWarningSound,
                haptic: nil,
                hapticGate: nil
            )
        }
    }
}
