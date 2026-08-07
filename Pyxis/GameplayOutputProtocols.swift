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

protocol GameplaySoundOutput: AnyObject {
    func prepareIfNeeded()
    func play(_ sound: GameplaySoundID)
    func stopAllAndDeactivate()
}

protocol GameplayHapticOutput: AnyObject {
    func play(_ kind: GameplayHapticKind)
}
