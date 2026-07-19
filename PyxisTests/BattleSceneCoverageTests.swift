//
//  BattleSceneCoverageTests.swift
//  PyxisTests
//

import Foundation
import SpriteKit
import Testing
@testable import Pyxis

@MainActor
struct BattleSceneCoverageTests {
    @Test func animationTestingAccessorsRejectUnknownActions() throws {
        let scene = try makeScene(initialState: stateWithBarracks())

        #expect(scene.animationFrameNamesForTesting(soldierType: .infantry, action: "idle").isEmpty)
        #expect(scene.cachedSoldierAnimationTexturesForTesting(soldierType: .infantry, action: "idle").isEmpty)
        #expect(scene.soldierAnimationFrameDurationsForTesting(action: "idle").isEmpty)
        #expect(scene.soldierAnimationDurationForTesting(action: "idle") == 0)
    }

    @Test func liveSoldierTestingAccessorsAreSafeBeforeSpawn() throws {
        let scene = try makeScene(initialState: stateWithBarracks())

        #expect(scene.firstLiveSoldierBodyFrameForTesting == nil)
        #expect(scene.firstLiveSoldierBodySpriteForTesting == nil)
        #expect(scene.firstLiveSoldierTowerShotTargetForTesting == nil)
        #expect(scene.firstLiveSoldierBodyNameForTesting == nil)
        #expect(scene.firstLiveSoldierHitAnimationRemainingForTesting == nil)
        #expect(!scene.firstLiveSoldierHasActionForTesting("soldierWalkAnimation"))
        #expect(!scene.firstLiveSoldierVisualMatchesForTesting(.infantry))

        scene.triggerFirstLiveSoldierAnimationForTesting("attack")
        scene.triggerFirstLiveSoldierAnimationForTesting("idle")
        scene.completeFirstLiveSoldierTransientAnimationForTesting()

        #expect(scene.soldierAttackAnimationTriggerCountForTesting == 0)
        #expect(scene.soldierHitAnimationTriggerCountForTesting == 0)
    }

    @Test func compactSceneUsesCompactSoldierTargetHeight() throws {
        let sceneSize = CGSize(width: 390, height: 480)
        let scene = try makeScene(initialState: stateWithBarracks(), size: sceneSize)

        #expect(abs(scene.soldierTargetHeightForTesting - 50) < 0.001)
    }

    @Test func zeroDeltaDoesNotConsumeAnActiveHitCountdown() throws {
        let scene = try makeScene(initialState: stateWithBarracks(cityRemainingPower: 100))
        scene.spawnSoldierForTesting()
        scene.triggerFirstLiveSoldierAnimationForTesting("hit")

        let initialRemaining = try #require(scene.firstLiveSoldierHitAnimationRemainingForTesting)
        scene.advanceCombatForTesting(deltaTime: 0)
        let remainingAfterZeroDelta = try #require(scene.firstLiveSoldierHitAnimationRemainingForTesting)

        #expect(abs(initialRemaining - remainingAfterZeroDelta) < 0.000_001)
    }

    private func makeScene(
        initialState: KingdomGameState,
        size: CGSize = CGSize(width: 390, height: 844)
    ) throws -> BattleScene {
        let suiteName = "PyxisTests.BattleSceneCoverageTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let store = KingdomGameStore(defaults: defaults, key: "state")
        store.save(initialState)

        let scene = BattleScene(size: size, store: store)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        scene.didMove(to: view)
        return scene
    }

    private func stateWithBarracks(cityRemainingPower: Int = 20) -> KingdomGameState {
        let cityKey = CityKey(countryNumber: 1, cityNumber: 1)
        return KingdomGameState(
            gold: 100,
            cityRemainingPower: cityRemainingPower,
            cityBattleStates: [
                cityKey.storageKey: CityBattleState(
                    slots: [1: CityBuilding(type: .barracks)]
                )
            ]
        )
    }
}
