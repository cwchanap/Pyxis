//
//  BattleSceneTests.swift
//  PyxisTests
//

import Foundation
import SpriteKit
import Testing
@testable import Pyxis

@MainActor
struct BattleSceneTests {
    @Test func battleSceneDisplaysCampaignCityTitle() throws {
        let store = try makeStore(
            initialState: KingdomGameState(
                cityLevel: 3,
                cityNumberInCountry: 3,
                completedCityCount: 2
            )
        )
        let scene = makeScene(store: store)

        #expect(scene.cityTitleTextForTesting == "Country 1 - City 3")
    }

    @Test func spawnWaitsForSoldierImpactBeforeDamagingCity() throws {
        let store = try makeStore(initialState: KingdomGameState(cityRemainingPower: 20))
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()

        #expect(scene.pendingSoldierAttackCountForTesting == 1)
        #expect(scene.cityRemainingPowerForTesting == 20)
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

        #expect(scene.cityRemainingPowerForTesting == 1)
        #expect(scene.cityLevelForTesting == 1)
        #expect(scene.goldForTesting == 0)
        let preImpactState = store.load()
        #expect(preImpactState.cityRemainingPower == 1)
        #expect(preImpactState.cityLevel == 1)
        #expect(preImpactState.gold == 0)

        scene.completeFirstPendingSoldierAttackForTesting()

        let savedState = store.load()
        #expect(savedState.gold == 8)
        #expect(savedState.cityLevel == 1)
        #expect(savedState.completedCityCount == 1)
        #expect(savedState.cityRemainingPower == 0)
        #expect(savedState.stageStatus == .cityConqueredPendingMap)
    }

    @Test func closingConquestPopupRequestsCountryMapRoute() throws {
        let store = try makeStore(initialState: KingdomGameState(cityRemainingPower: 1))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        scene.spawnSoldierForTesting()
        scene.completeFirstPendingSoldierAttackForTesting()

        #expect(scene.isConquestPopupVisibleForTesting)
        #expect(!router.didRequestCountryMap)

        scene.closeConquestPopupForTesting()

        #expect(!scene.isConquestPopupVisibleForTesting)
        #expect(router.didRequestCountryMap)
    }

    @Test func closingConquestPopupWithoutRouterKeepsPopupVisible() throws {
        let store = try makeStore(initialState: KingdomGameState(cityRemainingPower: 1))
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()
        scene.completeFirstPendingSoldierAttackForTesting()

        #expect(scene.isConquestPopupVisibleForTesting)

        scene.closeConquestPopupForTesting()

        #expect(scene.isConquestPopupVisibleForTesting)
    }

    @Test func conquestClearsPendingSoldiersBeforeLaterImpactsCanMutateState() throws {
        let store = try makeStore(initialState: KingdomGameState(cityRemainingPower: 1))
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()
        scene.spawnSoldierForTesting()
        scene.spawnSoldierForTesting()

        #expect(scene.pendingSoldierAttackCountForTesting == 3)

        scene.completeFirstPendingSoldierAttackForTesting()

        var savedState = store.load()
        #expect(scene.pendingSoldierAttackCountForTesting == 0)
        #expect(scene.isConquestPopupVisibleForTesting)
        #expect(savedState.gold == 8)
        #expect(savedState.completedCityCount == 1)
        #expect(savedState.stageStatus == .cityConqueredPendingMap)

        scene.completeFirstPendingSoldierAttackForTesting()
        scene.closeConquestPopupForTesting()

        savedState = store.load()
        #expect(scene.isConquestPopupVisibleForTesting)
        #expect(savedState.gold == 8)
        #expect(savedState.completedCityCount == 1)
        #expect(savedState.stageStatus == .cityConqueredPendingMap)
    }

    @Test func idleConquestClearsPendingSoldiersBeforeLaterImpactsCanMutateState() throws {
        let store = try makeStore(
            initialState: KingdomGameState(
                cityRemainingPower: 1,
                lastBackgroundedAt: Date(timeIntervalSinceNow: -2)
            )
        )
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()

        #expect(scene.pendingSoldierAttackCountForTesting == 1)

        NotificationCenter.default.post(name: .pyxisSceneWillEnterForeground, object: nil)

        var savedState = store.load()
        #expect(scene.pendingSoldierAttackCountForTesting == 0)
        #expect(scene.isConquestPopupVisibleForTesting)
        #expect(savedState.gold == 8)
        #expect(savedState.completedCityCount == 1)
        #expect(savedState.stageStatus == .cityConqueredPendingMap)

        scene.completeFirstPendingSoldierAttackForTesting()
        scene.closeConquestPopupForTesting()

        savedState = store.load()
        #expect(scene.isConquestPopupVisibleForTesting)
        #expect(savedState.gold == 8)
        #expect(savedState.completedCityCount == 1)
        #expect(savedState.stageStatus == .cityConqueredPendingMap)
    }

    private func makeScene(store: KingdomGameStore, router: BattleSceneRouting? = nil) -> BattleScene {
        let size = CGSize(width: 390, height: 844)
        let scene = BattleScene(size: size, store: store, router: router)
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

    private final class RouteSpy: BattleSceneRouting {
        private(set) var didRequestCountryMap = false

        func battleSceneDidRequestCountryMap(_ scene: BattleScene) {
            didRequestCountryMap = true
        }
    }
}
