//
//  BuildingViewSceneTests.swift
//  PyxisTests
//

import Foundation
import SpriteKit
import Testing
@testable import Pyxis

@MainActor
struct BuildingViewSceneTests {
    @Test func gridRendersTwentyFiveSelectableSlots() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100))
        let scene = makeScene(store: store, router: RouteSpy())

        #expect(scene.buildingSlotCountForTesting == 25)
        #expect(scene.slotNodeCountForTesting == 25)
        #expect(scene.selectedSlotForTesting == nil)
    }

    @Test func selectingEmptySlotExposesBuildActions() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100))
        let scene = makeScene(store: store, router: RouteSpy())

        scene.selectSlotForTesting(3)

        #expect(scene.selectedSlotForTesting == 3)
        #expect(scene.buildBarracksTextForTesting == "Build Barracks")
        #expect(scene.buildArcheryTextForTesting == "Build Archery")
        #expect(scene.canBuildBarracksForTesting)
        #expect(scene.canBuildArcheryRangeForTesting)
        #expect(!scene.canUpgradeSelectedSlotForTesting)
    }

    @Test func buildAffordanceReturnsFalseWhenGoldIsInsufficient() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 10))
        let scene = makeScene(store: store, router: RouteSpy())

        scene.selectSlotForTesting(3)

        #expect(!scene.canBuildBarracksForTesting)
        #expect(!scene.canBuildArcheryRangeForTesting)
    }

    @Test func upgradeAffordanceReturnsFalseWhenGoldIsInsufficient() throws {
        var initial = KingdomGameState(gold: 100)
        #expect(initial.buildBuilding(.barracks, inSlot: 1) == .built(cost: 15, remainingGold: 85))
        initial.gold = 0
        let store = try makeStore(initialState: initial)
        let scene = makeScene(store: store, router: RouteSpy())

        scene.selectSlotForTesting(1)
        #expect(!scene.canUpgradeSelectedSlotForTesting)
    }

    @Test func buildingUpdatesStoreSlotAndGoldLabel() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100))
        let scene = makeScene(store: store, router: RouteSpy())

        scene.selectSlotForTesting(3)
        scene.buildSelectedSlotForTesting(.barracks)

        #expect(store.load().gold == 85)
        #expect(store.load().cityBattleStateForCurrentCity.building(inSlot: 3)?.type == .barracks)
        #expect(scene.goldTextForTesting == "Gold: 85")
        #expect(scene.slotTextForTesting(3)?.contains("Barracks") == true)
    }

    @Test func occupiedSlotExposesUpgradeAction() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100))
        let scene = makeScene(store: store, router: RouteSpy())

        scene.selectSlotForTesting(4)
        scene.buildSelectedSlotForTesting(.archeryRange)
        scene.selectSlotForTesting(4)

        #expect(!scene.canBuildBarracksForTesting)
        #expect(!scene.canBuildArcheryRangeForTesting)
        #expect(scene.canUpgradeSelectedSlotForTesting)

        scene.upgradeSelectedSlotForTesting()

        #expect(store.load().cityBattleStateForCurrentCity.building(inSlot: 4)?.level == 2)
    }

    @Test func typeCapAndInsufficientGoldShowFeedback() throws {
        var initial = KingdomGameState(gold: 75)
        #expect(initial.buildBuilding(.barracks, inSlot: 1) == .built(cost: 15, remainingGold: 60))
        #expect(initial.buildBuilding(.barracks, inSlot: 2) == .built(cost: 15, remainingGold: 45))
        #expect(initial.buildBuilding(.barracks, inSlot: 3) == .built(cost: 15, remainingGold: 30))
        #expect(initial.buildBuilding(.barracks, inSlot: 4) == .built(cost: 15, remainingGold: 15))
        #expect(initial.buildBuilding(.barracks, inSlot: 5) == .built(cost: 15, remainingGold: 0))
        let store = try makeStore(initialState: initial)
        let scene = makeScene(store: store, router: RouteSpy())

        scene.selectSlotForTesting(6)
        scene.buildSelectedSlotForTesting(.barracks)
        #expect(scene.feedbackTextForTesting == "Barracks limit reached.")

        scene.buildSelectedSlotForTesting(.archeryRange)
        #expect(scene.feedbackTextForTesting == "Need 18 gold. You have 0.")
    }

    @Test func backToBattleRoutesThroughRouter() throws {
        let store = try makeStore(initialState: KingdomGameState())
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        scene.requestBattleForTesting()

        #expect(router.didRequestBattle)
    }

    @Test func battleRequestResolvesTimeSpentInBuildingViewBeforeRouting() throws {
        let start = Date(timeIntervalSinceNow: -120)
        var initialState = KingdomGameState(gold: 100, cityRemainingPower: 20)
        #expect(initialState.buildBuilding(.barracks, inSlot: 1, at: start) == .built(cost: 15, remainingGold: 85))
        initialState.markCurrentCityBuildingProgressInactive(at: start)
        let store = try makeStore(initialState: initialState)
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        scene.requestBattleForTesting()

        let savedState = store.load()
        #expect(router.didRequestBattle)
        #expect(savedState.cityRemainingPower < 20)
        #expect(savedState.stageStatus == .battleActive)
        #expect(savedState.lastBackgroundedAt == nil)
    }

    @Test func foregroundNotificationResolvesBuildingIdleProgressWithoutRouting() throws {
        let start = Date(timeIntervalSinceNow: -1_000)
        var initialState = KingdomGameState(gold: 100, cityRemainingPower: 1, lastBackgroundedAt: start)
        #expect(initialState.buildBuilding(.barracks, inSlot: 1, at: start) == .built(cost: 15, remainingGold: 85))
        let store = try makeStore(initialState: initialState)
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        NotificationCenter.default.post(name: .pyxisSceneWillEnterForeground, object: nil)

        let savedState = store.load()
        #expect(savedState.cityRemainingPower == 0)
        #expect(savedState.stageStatus == .cityConqueredPendingMap)
        #expect(savedState.lastBackgroundedAt == nil)
        #expect(scene.feedbackTextForTesting == "Buildings conquered Country 1 - City 1.")
        #expect(!router.didRequestBattle)
    }

    @Test func battleRequestAfterForegroundIdleConquestRoutesToCountryMap() throws {
        let size = CGSize(width: 390, height: 844)
        let start = Date(timeIntervalSinceNow: -1_000)
        var initialState = KingdomGameState(gold: 100, cityRemainingPower: 1, lastBackgroundedAt: start)
        #expect(initialState.buildBuilding(.barracks, inSlot: 1, at: start) == .built(cost: 15, remainingGold: 85))
        let store = try makeStore(initialState: initialState)
        let controller = GameViewController(store: store)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        controller.view = view
        let scene = makeScene(size: size, store: store, router: controller)

        NotificationCenter.default.post(name: .pyxisSceneWillEnterForeground, object: nil)
        scene.requestBattleForTesting()

        #expect(store.load().stageStatus == .cityConqueredPendingMap)
        #expect(view.scene is CountryMapScene)
    }

    @Test func compactLandscapeLayoutKeepsGridBetweenPanelsAndAwayFromButtons() throws {
        let size = CGSize(width: 667, height: 375)
        let store = try makeStore(initialState: KingdomGameState(gold: 100))
        let scene = makeScene(size: size, store: store, router: RouteSpy())
        let frames = try #require(scene.buildingLayoutFramesForTesting)

        #expect(frames.scene.contains(frames.titlePanel))
        #expect(frames.scene.contains(frames.actionPanel))
        #expect(frames.scene.contains(frames.grid))
        #expect(frames.grid.maxY < frames.titlePanel.minY)
        #expect(frames.grid.minY > frames.actionPanel.maxY)
        #expect(!frames.grid.intersects(frames.buildBarracksButton))
        #expect(!frames.grid.intersects(frames.buildArcheryButton))
        #expect(!frames.grid.intersects(frames.upgradeButton))
        #expect(!frames.grid.intersects(frames.battleButton))
    }

    @Test func foregroundReArmsIdleTrackingWhenBattleRemainsActive() throws {
        let start = Date(timeIntervalSinceNow: -200)
        var initial = KingdomGameState(gold: 100, cityRemainingPower: 10_000)
        #expect(initial.buildBuilding(.barracks, inSlot: 1, at: start) == .built(cost: 15, remainingGold: 85))
        initial.lastBackgroundedAt = start
        let store = try makeStore(initialState: initial)
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        NotificationCenter.default.post(name: .pyxisSceneWillEnterForeground, object: nil)

        let saved = store.load()
        #expect(saved.stageStatus == .battleActive)
        #expect(saved.lastBackgroundedAt != nil)
    }

    @Test func foregroundDoesNotReArmIdleTrackingAfterConquest() throws {
        let start = Date(timeIntervalSinceNow: -1_000)
        var initial = KingdomGameState(gold: 100, cityRemainingPower: 1, lastBackgroundedAt: start)
        #expect(initial.buildBuilding(.barracks, inSlot: 1, at: start) == .built(cost: 15, remainingGold: 85))
        let store = try makeStore(initialState: initial)
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        NotificationCenter.default.post(name: .pyxisSceneWillEnterForeground, object: nil)

        let saved = store.load()
        #expect(saved.stageStatus == .cityConqueredPendingMap)
        #expect(saved.lastBackgroundedAt == nil)
    }

    @Test func buildTriggeringConquestViaSettlementPersistsState() throws {
        let past = Date(timeIntervalSinceNow: -100)
        var initial = KingdomGameState(gold: 100, cityRemainingPower: 1)
        #expect(initial.buildBuilding(.barracks, inSlot: 1, at: past) == .built(cost: 15, remainingGold: 85))
        let store = try makeStore(initialState: initial)
        let scene = makeScene(store: store, router: RouteSpy())

        scene.selectSlotForTesting(2)
        scene.buildSelectedSlotForTesting(.archeryRange)

        let saved = store.load()
        #expect(saved.stageStatus == .cityConqueredPendingMap)
        #expect(saved.gold > 85)
    }

    @Test func upgradeTriggeringConquestViaSettlementPersistsState() throws {
        let past = Date(timeIntervalSinceNow: -100)
        var initial = KingdomGameState(gold: 100, cityRemainingPower: 1)
        #expect(initial.buildBuilding(.barracks, inSlot: 1, at: past) == .built(cost: 15, remainingGold: 85))
        let store = try makeStore(initialState: initial)
        let scene = makeScene(store: store, router: RouteSpy())

        scene.selectSlotForTesting(1)
        scene.upgradeSelectedSlotForTesting()

        let saved = store.load()
        #expect(saved.stageStatus == .cityConqueredPendingMap)
        #expect(saved.gold > 85)
    }

    private func makeScene(
        size: CGSize = CGSize(width: 390, height: 844),
        store: KingdomGameStore,
        router: BuildingViewSceneRouting? = nil
    ) -> BuildingViewScene {
        let scene = BuildingViewScene(size: size, store: store, router: router)
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

    private final class RouteSpy: BuildingViewSceneRouting {
        private(set) var didRequestBattle = false

        func buildingViewSceneDidRequestBattle(_ scene: BuildingViewScene) {
            didRequestBattle = true
        }
    }
}
