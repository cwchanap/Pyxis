//
//  GameplayOutputProtocols.swift
//  Pyxis
//

enum GameplaySoundID: String, CaseIterable, Equatable {
    case deployment
    case attackMelee
    case attackRanged
    case attackSiege
    case towerFire
    case soldierHit
    case soldierDeath
    case construction
    case blocked
    case goldReward
    case cityConquest
    case countryCompletion
    case fortifiedWarning
}

enum GameplayHapticKind: Equatable {
    case lightImpact
    case mediumImpact
    case warning
    case strongSuccess
}

enum GameplaySoundClass: Equatable {
    case automaticCombat
    case nonAutomatic
}

enum GameplayGateID: Hashable {
    case deploymentSound
    case deploymentHaptic
    case constructionSound
    case invalidSound
    case invalidHaptic
    case fortifiedWarningSound
}

protocol GameplaySoundOutput: AnyObject {
    func prepareIfNeeded()
    func play(_ sound: GameplaySoundID, soundClass: GameplaySoundClass)
    func stopAllAndDeactivate()
}

protocol GameplayHapticOutput: AnyObject {
    func play(_ kind: GameplayHapticKind)
}

struct GameplayFeedbackDirective: Equatable {
    let sound: GameplaySoundID?
    let soundClass: GameplaySoundClass?
    let soundGate: GameplayGateID?
    let haptic: GameplayHapticKind?
    let hapticGate: GameplayGateID?
}
