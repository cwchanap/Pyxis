//
//  GameplaySoundCatalog.swift
//  Pyxis
//

import Foundation

struct GameplaySoundResource: Equatable {
    let id: GameplaySoundID
    let resourceName: String
    let fileExtension: String
    let soundClass: GameplaySoundClass
    let maximumDuration: TimeInterval?
}

enum GameplaySoundCatalog {
    static let all: [GameplaySoundID: GameplaySoundResource] = [
        .deployment: resource(
            id: .deployment,
            resourceName: "deployment",
            soundClass: .nonAutomatic
        ),
        .attackMelee: resource(
            id: .attackMelee,
            resourceName: "attack-melee",
            soundClass: .automaticCombat,
            maximumDuration: 0.750
        ),
        .attackRanged: resource(
            id: .attackRanged,
            resourceName: "attack-ranged",
            soundClass: .automaticCombat,
            maximumDuration: 0.750
        ),
        .attackSiege: resource(
            id: .attackSiege,
            resourceName: "attack-siege",
            soundClass: .automaticCombat,
            maximumDuration: 0.750
        ),
        .towerFire: resource(
            id: .towerFire,
            resourceName: "tower-fire",
            soundClass: .automaticCombat,
            maximumDuration: 0.750
        ),
        .soldierHit: resource(
            id: .soldierHit,
            resourceName: "soldier-hit",
            soundClass: .automaticCombat,
            maximumDuration: 0.750
        ),
        .soldierDeath: resource(
            id: .soldierDeath,
            resourceName: "soldier-death",
            soundClass: .automaticCombat,
            maximumDuration: 0.750
        ),
        .construction: resource(
            id: .construction,
            resourceName: "construction",
            soundClass: .nonAutomatic
        ),
        .blocked: resource(
            id: .blocked,
            resourceName: "blocked",
            soundClass: .nonAutomatic
        ),
        .goldReward: resource(
            id: .goldReward,
            resourceName: "gold-reward",
            soundClass: .nonAutomatic
        ),
        .cityConquest: resource(
            id: .cityConquest,
            resourceName: "city-conquest",
            soundClass: .nonAutomatic
        ),
        .countryCompletion: resource(
            id: .countryCompletion,
            resourceName: "country-completion",
            soundClass: .nonAutomatic
        )
    ]

    private static func resource(
        id: GameplaySoundID,
        resourceName: String,
        soundClass: GameplaySoundClass,
        maximumDuration: TimeInterval? = nil
    ) -> GameplaySoundResource {
        GameplaySoundResource(
            id: id,
            resourceName: resourceName,
            fileExtension: "caf",
            soundClass: soundClass,
            maximumDuration: maximumDuration
        )
    }
}
