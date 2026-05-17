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

    @Test func liveCombatStatusUpdatesWhenTowerKillsLastSoldierWithoutCityDamage() throws {
        let store = try makeStore(
            initialState: KingdomGameState(
                cityRemainingPower: 20,
                cityNumberInCountry: 8,
                completedCityCount: 7
            )
        )
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()

        #expect(scene.liveCombatStatusTextForTesting == "Soldiers: 1")

        scene.advanceCombatForTesting(deltaTime: 1.2)

        #expect(scene.liveSoldierCountForTesting == 0)
        #expect(scene.cityRemainingPowerForTesting == 20)
        #expect(store.load().cityRemainingPower == 20)
        #expect(scene.liveCombatStatusTextForTesting == "Soldiers: 0")
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

    @Test func commanderHUDKeepsTopClustersAndActionsInsideScene() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 30, cityRemainingPower: 20))
        let scene = makeScene(store: store)
        let frames = try #require(scene.battleLayoutFramesForTesting)

        #expect(frames.leftHUD.minX >= 12)
        #expect(frames.rightHUD.maxX <= scene.size.width - 12)
        #expect(frames.leftHUD.maxX < frames.rightHUD.minX)
        #expect(frames.leftHUD.height >= 70)
        #expect(frames.rightHUD.height >= 70)
        #expect(frames.spawnButton.maxY <= frames.battlefield.minY)
        #expect(frames.upgradeButton.maxY <= frames.battlefield.minY)
        #expect(frames.feedback.maxY <= frames.battlefield.minY)
        #expect(frames.battlefield.maxY < frames.leftHUD.minY)
        #expect(frames.battlefield.maxY < frames.rightHUD.minY)
        #expect(frames.spawnButton.minX >= 12)
        #expect(frames.upgradeButton.maxX <= scene.size.width - 12)
        #expect(frames.spawnButton.maxX < frames.upgradeButton.minX)
        #expect(frames.upgradeButton.minY >= 12)
        #expect(frames.spawnButtonLabel.minX >= frames.spawnButton.minX + 14)
        #expect(frames.spawnButtonLabel.maxX <= frames.spawnButton.maxX - 14)
        #expect(frames.upgradeButtonLabel.minX >= frames.upgradeButton.minX + 14)
        #expect(frames.upgradeButtonLabel.maxX <= frames.upgradeButton.maxX - 14)
    }

    @Test func commanderHUDSurvivesCompactLandscapeWithoutOverlap() throws {
        let size = CGSize(width: 667, height: 375)
        let store = try makeStore(initialState: KingdomGameState(gold: 30, cityRemainingPower: 20))
        let scene = BattleScene(size: size, store: store, router: nil)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        scene.didMove(to: view)

        let frames = try #require(scene.battleLayoutFramesForTesting)

        #expect(frames.leftHUD.minX >= 8)
        #expect(frames.rightHUD.maxX <= size.width - 8)
        #expect(frames.leftHUD.maxX < frames.rightHUD.minX)
        #expect(frames.leftHUD.height >= 56)
        #expect(frames.rightHUD.height >= 56)
        #expect(frames.spawnButton.maxY <= frames.battlefield.minY)
        #expect(frames.upgradeButton.maxY <= frames.battlefield.minY)
        #expect(frames.feedback.maxY <= frames.battlefield.minY)
        #expect(frames.feedback.minY >= frames.spawnButton.maxY)
        #expect(frames.feedback.minY >= frames.upgradeButton.maxY)
        #expect(frames.battlefield.maxY < frames.leftHUD.minY)
        #expect(frames.battlefield.maxY < frames.rightHUD.minY)
        #expect(frames.spawnButton.minY >= 8)
        #expect(frames.upgradeButton.minY >= 8)
        #expect(frames.spawnButton.maxX < frames.upgradeButton.minX)
    }

    @Test func commanderHUDFitsNarrowViewportWithoutOverflow() throws {
        let size = CGSize(width: 320, height: 568)
        let store = try makeStore(initialState: KingdomGameState(gold: 30, cityRemainingPower: 20))
        let scene = BattleScene(size: size, store: store, router: nil)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        scene.didMove(to: view)

        let frames = try #require(scene.battleLayoutFramesForTesting)

        #expect(frames.leftHUD.minX >= 8)
        #expect(frames.rightHUD.maxX <= size.width - 8)
        #expect(frames.leftHUD.maxX < frames.rightHUD.minX)
        #expect(frames.spawnButton.minX >= 8)
        #expect(frames.upgradeButton.maxX <= size.width - 8)
        #expect(frames.spawnButton.maxX < frames.upgradeButton.minX)
        #expect(frames.spawnButtonLabel.minX >= frames.spawnButton.minX + 14)
        #expect(frames.spawnButtonLabel.maxX <= frames.spawnButton.maxX - 14)
        #expect(frames.upgradeButtonLabel.minX >= frames.upgradeButton.minX + 14)
        #expect(frames.upgradeButtonLabel.maxX <= frames.upgradeButton.maxX - 14)

        scene.spawnSoldierForTesting()
        let updatedFrames = try #require(scene.battleLayoutFramesForTesting)
        #expect(updatedFrames.liveCombatStatus.minX >= updatedFrames.leftHUD.minX + 10)
        #expect(updatedFrames.liveCombatStatus.maxX <= updatedFrames.leftHUD.maxX - 10)
    }

    @Test func upgradeButtonCommunicatesAffordabilityWithoutBlockingTapFeedback() throws {
        let affordableStore = try makeStore(initialState: KingdomGameState(gold: 30, cityRemainingPower: 20))
        let affordableScene = makeScene(store: affordableStore)
        #expect(affordableScene.isUpgradeVisuallyAffordableForTesting)

        let store = try makeStore(initialState: KingdomGameState(gold: 0, cityRemainingPower: 20))
        let scene = makeScene(store: store)

        #expect(scene.isUpgradeVisuallyAffordableForTesting == false)

        scene.upgradeSoldierForTesting()

        #expect(scene.feedbackTextForTesting == "Need 10 gold. You have 0.")
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
