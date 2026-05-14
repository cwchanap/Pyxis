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

    @Test func battleSceneDisplaysLiveSoldierCount() throws {
        let store = try makeStore(initialState: KingdomGameState(cityRemainingPower: 20))
        let scene = makeScene(store: store)

        #expect(scene.liveCombatStatusTextForTesting == "Soldiers: 0")

        scene.spawnSoldierForTesting()

        #expect(scene.liveCombatStatusTextForTesting == "Soldiers: 1")
    }

    @Test func tappingSpawnCreatesLiveCombatSoldierWithoutImmediateCityDamage() throws {
        let store = try makeStore(initialState: KingdomGameState(cityRemainingPower: 20))
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()

        #expect(scene.liveSoldierCountForTesting == 1)
        #expect(scene.cityRemainingPowerForTesting == 20)
        #expect(store.load().cityRemainingPower == 20)
    }

    @Test func liveSoldierHPBarStaysReadableAboveScaledBody() throws {
        let store = try makeStore(initialState: KingdomGameState(cityRemainingPower: 20))
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()

        let hpBarFrame = try #require(scene.firstLiveSoldierHPBarFrameForTesting)
        let bodyFrame = try #require(scene.firstLiveSoldierBodyFrameForTesting)
        #expect(hpBarFrame.height >= 4.5)
        #expect(hpBarFrame.minY > bodyFrame.maxY)
    }

    @Test func combatTickCanDamageDurableCityHPAndSaveIt() throws {
        let store = try makeStore(initialState: KingdomGameState(cityRemainingPower: 20))
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 3.0)

        #expect(scene.liveSoldierCountForTesting == 1)
        #expect(store.load().cityRemainingPower < 20)
    }

    @Test func towerDamageCanKillAndRemoveVisibleSoldier() throws {
        let store = try makeStore(initialState: KingdomGameState(cityRemainingPower: 20))
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 18.0)

        let savedState = store.load()
        #expect(scene.liveSoldierCountForTesting == 0)
        #expect(!scene.isConquestPopupVisibleForTesting)
        #expect(savedState.stageStatus == .battleActive)
        #expect(savedState.cityRemainingPower > 0)
        #expect(savedState.cityRemainingPower < 20)
    }

    @Test func liveCombatConquestClearsSoldiersAndShowsPopup() throws {
        let store = try makeStore(
            initialState: KingdomGameState(
                cityRemainingPower: 1,
                normalSoldierUpgradeLevel: 4
            )
        )
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()
        scene.spawnSoldierForTesting()
        scene.spawnSoldierForTesting()

        #expect(scene.liveSoldierCountForTesting == 3)

        scene.advanceCombatForTesting(deltaTime: 3.0)

        let savedState = store.load()
        #expect(scene.liveSoldierCountForTesting == 0)
        #expect(scene.isConquestPopupVisibleForTesting)
        #expect(savedState.gold == 8)
        #expect(savedState.completedCityCount == 1)
        #expect(savedState.stageStatus == .cityConqueredPendingMap)

        scene.advanceCombatForTesting(deltaTime: 3.0)

        let laterState = store.load()
        #expect(scene.liveSoldierCountForTesting == 0)
        #expect(scene.isConquestPopupVisibleForTesting)
        #expect(laterState.gold == savedState.gold)
        #expect(laterState.completedCityCount == savedState.completedCityCount)
        #expect(laterState.stageStatus == savedState.stageStatus)
    }

    @Test func conquestPopupLayoutKeepsCityConquestFeedbackRunning() throws {
        let store = try makeStore(
            initialState: KingdomGameState(
                cityRemainingPower: 1,
                normalSoldierUpgradeLevel: 4
            )
        )
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()
        scene.spawnSoldierForTesting()
        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 3.0)

        #expect(scene.isConquestPopupVisibleForTesting)
        #expect(scene.isCityConquestFeedbackRunningForTesting)
    }

    @Test func closingConquestPopupRequestsCountryMapRoute() throws {
        let store = try makeStore(initialState: KingdomGameState(cityRemainingPower: 1))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 3.0)

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
        scene.advanceCombatForTesting(deltaTime: 3.0)

        #expect(scene.isConquestPopupVisibleForTesting)

        scene.closeConquestPopupForTesting()

        #expect(scene.isConquestPopupVisibleForTesting)
    }

    @Test func idleConquestClearsLiveSoldiersBeforeShowingPopup() throws {
        let store = try makeStore(
            initialState: KingdomGameState(
                cityRemainingPower: 1,
                lastBackgroundedAt: Date(timeIntervalSinceNow: -2)
            )
        )
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()

        #expect(scene.liveSoldierCountForTesting == 1)

        NotificationCenter.default.post(name: .pyxisSceneWillEnterForeground, object: nil)

        let savedState = store.load()
        #expect(scene.liveSoldierCountForTesting == 0)
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
