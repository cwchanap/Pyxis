//
//  GameSceneAnimationTests.swift
//  PyxisTests
//

import Foundation
import SpriteKit
import Testing
@testable import Pyxis

@MainActor
struct GameSceneAnimationTests {
    @Test func spawnWaitsForSoldierImpactBeforeDamagingCity() throws {
        let store = try makeStore(initialState: KingdomGameState(cityRemainingPower: 20))
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()

        #expect(scene.pendingSoldierAttackCountForTesting == 1)
        #expect(store.load().cityRemainingPower == 20)

        scene.completeFirstPendingSoldierAttackForTesting()

        #expect(scene.pendingSoldierAttackCountForTesting == 0)
        #expect(store.load().cityRemainingPower == 19)
    }

    @Test func repeatedSpawnsCreateMultiplePendingSoldiers() throws {
        let store = try makeStore(initialState: KingdomGameState(cityRemainingPower: 20))
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()
        scene.spawnSoldierForTesting()
        scene.spawnSoldierForTesting()

        #expect(scene.pendingSoldierAttackCountForTesting == 3)
        #expect(store.load().cityRemainingPower == 20)

        scene.completeFirstPendingSoldierAttackForTesting()
        scene.completeFirstPendingSoldierAttackForTesting()

        #expect(scene.pendingSoldierAttackCountForTesting == 1)
        #expect(store.load().cityRemainingPower == 18)
    }

    @Test func soldierImpactCanConquerCityAndSaveReward() throws {
        let store = try makeStore(initialState: KingdomGameState(cityRemainingPower: 1))
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()
        scene.completeFirstPendingSoldierAttackForTesting()

        let savedState = store.load()
        #expect(savedState.gold == 8)
        #expect(savedState.cityLevel == 2)
        #expect(savedState.cityRemainingPower == KingdomGameState.cityMaxPower(for: 2))
    }

    private func makeScene(store: KingdomGameStore) -> GameScene {
        let size = CGSize(width: 390, height: 844)
        let scene = GameScene(size: size, store: store)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        scene.didMove(to: view)
        return scene
    }

    private func makeStore(initialState: KingdomGameState) throws -> KingdomGameStore {
        let suiteName = "PyxisTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let store = KingdomGameStore(defaults: defaults, key: "state")
        store.save(initialState)
        return store
    }
}
