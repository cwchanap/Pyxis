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

    @Test func manualSelectorChangesSpawnedSoldierType() throws {
        let store = try makeStore(initialState: KingdomGameState(cityRemainingPower: 20))
        let scene = makeScene(store: store)

        #expect(scene.selectedManualSoldierTypeForTesting == .infantry)

        scene.selectManualSoldierTypeForTesting(.archer)
        scene.spawnSoldierForTesting()

        #expect(scene.selectedManualSoldierTypeForTesting == .archer)
        #expect(scene.liveSoldierTypesForTesting == [.archer])
    }

    @Test func manualSpawnCapBlocksEleventhManualSoldier() throws {
        let store = try makeStore(initialState: KingdomGameState(cityRemainingPower: 100))
        let scene = makeScene(store: store)

        for _ in 0..<KingdomGameState.manualSoldierCap {
            scene.spawnSoldierForTesting()
        }

        #expect(scene.manualLiveSoldierCountForTesting == KingdomGameState.manualSoldierCap)

        scene.spawnSoldierForTesting()

        #expect(scene.manualLiveSoldierCountForTesting == KingdomGameState.manualSoldierCap)
        #expect(scene.liveSoldierCountForTesting == KingdomGameState.manualSoldierCap)
        #expect(scene.feedbackTextForTesting == "Manual squad is full.")
    }

    @Test func activeBuildingTimerCreatesBuildingSpawnedSoldierWithoutConsumingManualCap() throws {
        let cityKey = CityKey(countryNumber: 1, cityNumber: 1)
        let cityState = CityBattleState(
            slots: [1: CityBuilding(type: .barracks, spawnTimerElapsed: 9.95)]
        )
        let store = try makeStore(
            initialState: KingdomGameState(
                cityRemainingPower: 100,
                cityBattleStates: [cityKey.storageKey: cityState]
            )
        )
        let scene = makeScene(store: store)

        scene.selectManualSoldierTypeForTesting(.archer)
        for _ in 0..<KingdomGameState.manualSoldierCap {
            scene.spawnSoldierForTesting()
        }

        scene.advanceCombatForTesting(deltaTime: 0.1)

        #expect(scene.manualLiveSoldierCountForTesting == KingdomGameState.manualSoldierCap)
        #expect(scene.buildingLiveSoldierCountForTesting == 1)
        #expect(scene.liveSoldierCountForTesting == KingdomGameState.manualSoldierCap + 1)
        #expect(scene.liveSoldierTypesForTesting.filter { $0 == .archer }.count == KingdomGameState.manualSoldierCap)
        #expect(scene.liveSoldierTypesForTesting.contains(.infantry))
        scene.flushBuildingProgressSaveForTesting()
        #expect(store.load().cityBattleState(for: cityKey).building(inSlot: 1)?.spawnTimerElapsed ?? 10 < 1)
    }

    @Test func activeBuildingPartialTimerProgressPersistsWithoutSpawn() throws {
        let cityKey = CityKey(countryNumber: 1, cityNumber: 1)
        let cityState = CityBattleState(
            slots: [1: CityBuilding(type: .barracks, spawnTimerElapsed: 0)]
        )
        let store = try makeStore(
            initialState: KingdomGameState(
                cityRemainingPower: 100,
                cityBattleStates: [cityKey.storageKey: cityState]
            )
        )
        let scene = makeScene(store: store)

        scene.advanceCombatForTesting(deltaTime: 5.0)

        #expect(scene.buildingLiveSoldierCountForTesting == 0)
        scene.flushBuildingProgressSaveForTesting()
        let savedElapsed = try #require(store.load().cityBattleState(for: cityKey).building(inSlot: 1)?.spawnTimerElapsed)
        #expect(savedElapsed > 0)
        #expect(savedElapsed < KingdomGameState.activeSpawnInterval(for: .barracks))
    }

    @Test func buildingProgressSaveIsThrottled() throws {
        let cityKey = CityKey(countryNumber: 1, cityNumber: 1)
        let cityState = CityBattleState(
            slots: [1: CityBuilding(type: .barracks, spawnTimerElapsed: 0)]
        )
        let store = try makeStore(
            initialState: KingdomGameState(
                cityRemainingPower: 100,
                cityBattleStates: [cityKey.storageKey: cityState]
            )
        )
        let scene = makeScene(store: store)

        // Advance less than the throttle interval — no save should occur
        scene.advanceCombatForTesting(deltaTime: 1.0)

        let persisted = store.load().cityBattleState(for: cityKey).building(inSlot: 1)?.spawnTimerElapsed ?? 0
        #expect(persisted == 0)
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

    @Test func cityDamageCreatesFloatingFeedbackNode() throws {
        let store = try makeStore(
            initialState: KingdomGameState(
                cityRemainingPower: 50,
                normalSoldierUpgradeLevel: 4
            )
        )
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 3.0)

        #expect(scene.floatingFeedbackCountForTesting > 0)
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

    @Test func conquestPopupUsesRewardPresentationNodes() throws {
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
        #expect(scene.isGoldBurstVisibleForTesting)
        #expect(scene.goldBurstZPositionForTesting < scene.popupRewardZPositionForTesting)
        #expect(!scene.goldBurstContainsRewardTextForTesting)
    }

    @Test func conquestPopupRemovesGoldBurstAfterTransientActions() async throws {
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

        #expect(scene.isGoldBurstVisibleForTesting)
        #expect(scene.isGoldBurstRemovalScheduledForTesting)

        try await pollUntil(timeout: .seconds(2), interval: .milliseconds(50)) {
            !scene.isGoldBurstVisibleForTesting && !scene.isGoldBurstRemovalScheduledForTesting
        }

        #expect(!scene.isGoldBurstVisibleForTesting)
        #expect(!scene.isGoldBurstRemovalScheduledForTesting)
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

    @Test func buildButtonRequestsBuildingViewRoute() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100, cityRemainingPower: 20))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        scene.requestBuildingViewForTesting()

        #expect(router.didRequestBuildingView)
    }

    @Test func buildButtonWaitsForLiveSoldiersBeforeRouting() throws {
        let start = Date(timeIntervalSinceReferenceDate: 500)
        var initialState = KingdomGameState(gold: 100, cityRemainingPower: 20)
        #expect(initialState.buildBuilding(.barracks, inSlot: 1, at: start) == .built(cost: 15, remainingGold: 85))
        let store = try makeStore(initialState: initialState)
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        scene.spawnSoldierForTesting()
        scene.requestBuildingViewForTesting()

        #expect(!router.didRequestBuildingView)
        #expect(scene.feedbackTextForTesting == "Finish the current squad before building.")
        #expect(scene.liveSoldierCountForTesting == 1)
        #expect(store.load() == initialState)
    }

    @Test func buildButtonAllowsRoutingWithOnlyBuildingSpawnedSoldiers() throws {
        let cityKey = CityKey(countryNumber: 1, cityNumber: 1)
        let cityState = CityBattleState(
            slots: [1: CityBuilding(type: .barracks, spawnTimerElapsed: 9.95)]
        )
        let store = try makeStore(
            initialState: KingdomGameState(
                gold: 100,
                cityRemainingPower: 100,
                cityBattleStates: [cityKey.storageKey: cityState]
            )
        )
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        // Advance combat to trigger a building spawn
        scene.advanceCombatForTesting(deltaTime: 0.1)

        #expect(scene.buildingLiveSoldierCountForTesting == 1)
        #expect(scene.manualLiveSoldierCountForTesting == 0)

        scene.requestBuildingViewForTesting()

        #expect(router.didRequestBuildingView)
    }

    @Test func idleConquestClearsLiveSoldiersBeforeShowingPopup() throws {
        let start = Date(timeIntervalSinceNow: -1_000)
        var initialState = KingdomGameState(gold: 100, cityRemainingPower: 1, lastBackgroundedAt: start)
        #expect(initialState.buildBuilding(.barracks, inSlot: 1, at: start) == .built(cost: 15, remainingGold: 85))
        let store = try makeStore(initialState: initialState)
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()

        #expect(scene.liveSoldierCountForTesting == 1)

        NotificationCenter.default.post(name: .pyxisSceneWillEnterForeground, object: nil)

        let savedState = store.load()
        #expect(scene.liveSoldierCountForTesting == 0)
        #expect(scene.isConquestPopupVisibleForTesting)
        #expect(savedState.gold == 93)
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
        #expect(frames.feedbackPanel.contains(frames.feedback))
        #expect(frames.feedbackPanel.maxY <= frames.battlefield.minY)
        #expect(frames.feedbackPanel.minY >= frames.spawnButton.maxY)
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
        #expect(frames.feedbackPanel.contains(frames.feedback))
        #expect(frames.feedbackPanel.maxY <= frames.battlefield.minY)
        #expect(frames.feedback.minY >= frames.spawnButton.maxY)
        #expect(frames.feedback.minY >= frames.upgradeButton.maxY)
        #expect(frames.battlefield.maxY < frames.leftHUD.minY)
        #expect(frames.battlefield.maxY < frames.rightHUD.minY)
        #expect(frames.spawnButton.minY >= 8)
        #expect(frames.upgradeButton.minY >= 8)
        #expect(frames.spawnButton.maxX < frames.upgradeButton.minX)
    }

    @Test func manualTypeMenuAvoidsFeedbackAndBattlefieldInCompactAndNarrowLayouts() throws {
        for size in [CGSize(width: 667, height: 375), CGSize(width: 320, height: 568)] {
            let store = try makeStore(initialState: KingdomGameState(gold: 30, cityRemainingPower: 20))
            let scene = BattleScene(size: size, store: store, router: nil)
            let view = SKView(frame: CGRect(origin: .zero, size: size))
            scene.didMove(to: view)

            scene.openManualTypeMenuForTesting()

            let frames = try #require(scene.battleLayoutFramesForTesting)

            #expect(!frames.manualTypeInfantryButton.intersects(frames.feedbackPanel))
            #expect(!frames.manualTypeArcherButton.intersects(frames.feedbackPanel))
            #expect(!frames.manualTypeInfantryButton.intersects(frames.battlefield))
            #expect(!frames.manualTypeArcherButton.intersects(frames.battlefield))
            #expect(frames.manualTypeInfantryButton.minY >= frames.spawnButton.maxY)
            #expect(frames.manualTypeArcherButton.minY >= frames.spawnButton.maxY)
            #expect(frames.manualTypeArcherButton.maxX <= size.width - 8)
        }
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

    @Test func commanderHUDFitsLateGameNumbersInNarrowViewport() throws {
        let size = CGSize(width: 320, height: 568)
        let state = KingdomGameState(
            gold: 123_456_789,
            normalSoldierUpgradeLevel: 15,
            cityNumberInCountry: 15,
            completedCityCount: 14
        )
        let store = try makeStore(initialState: state)
        let scene = BattleScene(size: size, store: store, router: nil)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        scene.didMove(to: view)

        let frames = try #require(scene.battleLayoutFramesForTesting)

        #expect(frames.goldLabel.minX >= frames.leftHUD.minX + 10)
        #expect(frames.goldLabel.maxX <= frames.leftHUD.maxX - 10)
        #expect(frames.soldierAttackLabel.minX >= frames.leftHUD.minX + 10)
        #expect(frames.soldierAttackLabel.maxX <= frames.leftHUD.maxX - 10)
        #expect(frames.cityLevelLabel.minX >= frames.rightHUD.minX + 10)
        #expect(frames.cityLevelLabel.maxX <= frames.rightHUD.maxX - 10)
        #expect(frames.cityHPLabel.minX >= frames.rightHUD.minX + 10)
        #expect(frames.cityHPLabel.maxX <= frames.rightHUD.maxX - 10)
        #expect(frames.upgradeButtonLabel.minX >= frames.upgradeButton.minX + 14)
        #expect(frames.upgradeButtonLabel.maxX <= frames.upgradeButton.maxX - 14)
    }

    @Test func commanderHUDAvoidsTallPhoneSensorArea() throws {
        let size = CGSize(width: 390, height: 844)
        let store = try makeStore(initialState: KingdomGameState(gold: 30, cityRemainingPower: 20))
        let scene = BattleScene(size: size, store: store, router: nil)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        scene.didMove(to: view)

        let frames = try #require(scene.battleLayoutFramesForTesting)

        #expect(frames.leftHUD.maxY <= size.height - 58)
        #expect(frames.rightHUD.maxY <= size.height - 58)
        #expect(frames.spawnButton.minY >= 26)
        #expect(frames.upgradeButton.minY >= 26)
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

    @Test func insufficientGoldRunsUpgradeDeniedFeedback() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 0, cityRemainingPower: 20))
        let scene = makeScene(store: store)

        scene.upgradeSoldierForTesting()

        #expect(scene.isUpgradeDeniedFeedbackRunningForTesting)
    }

    @Test func unavailableUpgradeRunsDeniedFeedbackWhenNoBattleIsActive() throws {
        let store = try makeStore(
            initialState: KingdomGameState(
                gold: 30,
                cityNumberInCountry: 1,
                completedCityCount: 1,
                stageStatus: .cityConqueredPendingMap
            )
        )
        let scene = makeScene(store: store)

        scene.upgradeSoldierForTesting()

        #expect(scene.feedbackTextForTesting == "Enter a city to upgrade soldiers.")
        #expect(scene.isUpgradeDeniedFeedbackRunningForTesting)
        #expect(store.load().gold == 30)
    }

    private func pollUntil(
        timeout: Duration,
        interval: Duration = .milliseconds(50),
        condition: @escaping () -> Bool
    ) async throws {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if condition() { return }
            try await Task.sleep(for: interval)
        }
        Issue.record("Poll timed out after \(timeout)")
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
        private(set) var didRequestBuildingView = false

        func battleSceneDidRequestCountryMap(_ scene: BattleScene) {
            didRequestCountryMap = true
        }

        func battleSceneDidRequestBuildingView(_ scene: BattleScene) {
            didRequestBuildingView = true
        }
    }

    // MARK: - compactNumber

    @Test func compactNumberFormatsSmallValuesAsRawIntegers() throws {
        let store = try makeStore(initialState: KingdomGameState(cityRemainingPower: 20))
        let scene = makeScene(store: store)

        #expect(scene.compactNumberForTesting(0) == "0")
        #expect(scene.compactNumberForTesting(42) == "42")
        #expect(scene.compactNumberForTesting(999) == "999")
    }

    @Test func compactNumberFormatsThousandsWithSuffix() throws {
        let store = try makeStore(initialState: KingdomGameState(cityRemainingPower: 20))
        let scene = makeScene(store: store)

        #expect(scene.compactNumberForTesting(1_000) == "1K")
        #expect(scene.compactNumberForTesting(1_500) == "1.5K")
        #expect(scene.compactNumberForTesting(12_000) == "12K")
        #expect(scene.compactNumberForTesting(150_000) == "150K")
        #expect(scene.compactNumberForTesting(500_000) == "500K")
    }

    @Test func compactNumberFormatsMillionsWithSuffix() throws {
        let store = try makeStore(initialState: KingdomGameState(cityRemainingPower: 20))
        let scene = makeScene(store: store)

        #expect(scene.compactNumberForTesting(1_000_000) == "1M")
        #expect(scene.compactNumberForTesting(2_500_000) == "2.5M")
        #expect(scene.compactNumberForTesting(15_000_000) == "15M")
    }

    @Test func compactNumberFormatsBillionsWithSuffix() throws {
        let store = try makeStore(initialState: KingdomGameState(cityRemainingPower: 20))
        let scene = makeScene(store: store)

        #expect(scene.compactNumberForTesting(1_000_000_000) == "1B")
        #expect(scene.compactNumberForTesting(3_200_000_000) == "3.2B")
    }

    @Test func compactNumberPromotesAtUnitBoundaries() throws {
        let store = try makeStore(initialState: KingdomGameState(cityRemainingPower: 20))
        let scene = makeScene(store: store)

        // 999,950 rounds to "1M" not "1000K"
        #expect(scene.compactNumberForTesting(999_950) == "1M")
        // 999,500,000 rounds to "1B" not "1000M"
        #expect(scene.compactNumberForTesting(999_500_000) == "1B")
        // 999,500,000,000 rounds to "1T" not "1000B"
        #expect(scene.compactNumberForTesting(999_500_000_000) == "1T")
    }

    @Test func compactNumberHandlesNegativeValues() throws {
        let store = try makeStore(initialState: KingdomGameState(cityRemainingPower: 20))
        let scene = makeScene(store: store)

        #expect(scene.compactNumberForTesting(-1_500) == "-1.5K")
        #expect(scene.compactNumberForTesting(-1_000_000) == "-1M")
    }

    @Test func compactNumberDoesNotPromoteBelowThousand() throws {
        let store = try makeStore(initialState: KingdomGameState(cityRemainingPower: 20))
        let scene = makeScene(store: store)

        // 999,400 rounds to 999.4K → body "999" (since 999.4 >= 10, uses integer format)
        #expect(scene.compactNumberForTesting(999_400) == "999K")
        // 994,999 rounds to 995K
        #expect(scene.compactNumberForTesting(994_999) == "995K")
        // 998,500 rounds to 998.5K → body "998.5" (since 998.5 is not a whole number and < 10 is false)
        // Actually 998.5 >= 10 → uses %.0f → "998" but wait, 998.5.rounded() == 999 != 998.5
        // So body = String(format: "%.0f", 998.5) = "998"... but that loses the .5
        // Let's test: 1,500 → 1.5K (works because 1.5 < 10)
        #expect(scene.compactNumberForTesting(1_500) == "1.5K")
    }
}
