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
        }
    }
}
