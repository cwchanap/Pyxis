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

    @Test func selectingEmptySlotExposesUnlockedAndLockedBuildActions() throws {
        let store = try makeStore(
            initialState: KingdomGameState(gold: 500, cityNumberInCountry: 5, completedCityCount: 4)
        )
        let scene = makeScene(store: store, router: RouteSpy())

        scene.selectSlotForTesting(3)

        #expect(scene.selectedSlotForTesting == 3)
        #expect(scene.buildButtonTextsForTesting == [
            "Build Barracks",
            "Build Archery",
            "Build Stable",
            "Mage City 8",
            "Siege City 11"
        ])
        #expect(scene.canBuildForTesting(.barracks))
        #expect(scene.canBuildForTesting(.archeryRange))
        #expect(scene.canBuildForTesting(.stable))
        #expect(!scene.canBuildForTesting(.mageTower))
        #expect(!scene.canBuildForTesting(.siegeWorkshop))
        #expect(!scene.canUpgradeSelectedSlotForTesting)
    }

    @Test func buildAffordanceReturnsFalseWhenGoldIsInsufficient() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 10))
        let scene = makeScene(store: store, router: RouteSpy())

        scene.selectSlotForTesting(3)

        #expect(!scene.canBuildForTesting(.barracks))
        #expect(!scene.canBuildForTesting(.archeryRange))
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

    @Test func buildingTypesExposeBuildingSpriteAssetNames() {
        #expect(BuildingType.barracks.buildingAssetName == "building-barracks")
        #expect(BuildingType.archeryRange.buildingAssetName == "building-archery-range")
        #expect(BuildingType.stable.buildingAssetName == "building-stable")
        #expect(BuildingType.mageTower.buildingAssetName == "building-mage-tower")
        #expect(BuildingType.siegeWorkshop.buildingAssetName == "building-siege-workshop")
    }

    @Test func buildingTypesExposePaletteIconAssetNames() {
        for type in BuildingType.allCases {
            #expect(type.paletteIconAssetName == type.buildingAssetName)
        }
    }

    @Test func buildPaletteShowsAllBuildingIconAssets() throws {
        let store = try makeStore(
            initialState: KingdomGameState(gold: 500, cityNumberInCountry: 11, completedCityCount: 10)
        )
        let scene = makeScene(store: store, router: RouteSpy())

        #expect(scene.buildButtonIconAssetNamesForTesting == [
            .barracks: "building-barracks",
            .archeryRange: "building-archery-range",
            .stable: "building-stable",
            .mageTower: "building-mage-tower",
            .siegeWorkshop: "building-siege-workshop"
        ])
    }

    @Test func lockedFutureBuildingIconsAreDimmedAndShowUnlockCity() throws {
        let store = try makeStore(
            initialState: KingdomGameState(gold: 500, cityNumberInCountry: 5, completedCityCount: 4)
        )
        let scene = makeScene(store: store, router: RouteSpy())

        #expect(scene.buildButtonTextsForTesting == [
            "Build Barracks",
            "Build Archery",
            "Build Stable",
            "Mage City 8",
            "Siege City 11"
        ])
        #expect(scene.buildButtonIconAlphaForTesting(.barracks) == 1.0)
        #expect(scene.buildButtonIconAlphaForTesting(.archeryRange) == 1.0)
        #expect(scene.buildButtonIconAlphaForTesting(.stable) == 1.0)
        #expect(scene.buildButtonIconAlphaForTesting(.mageTower) == 0.35)
        #expect(scene.buildButtonIconAlphaForTesting(.siegeWorkshop) == 0.35)
    }

    @Test func unaffordableUnlockedBuildingIconsRemainVisibleButSubdued() throws {
        let store = try makeStore(
            initialState: KingdomGameState(gold: 0, cityNumberInCountry: 11, completedCityCount: 10)
        )
        let scene = makeScene(store: store, router: RouteSpy())

        scene.selectSlotForTesting(1)

        #expect(scene.buildButtonIconAlphaForTesting(.barracks) == 0.65)
        #expect(scene.buildButtonIconAlphaForTesting(.siegeWorkshop) == 0.65)
    }

    @Test func occupiedSelectedSlotDimsBuildPaletteIcons() throws {
        var initial = KingdomGameState(gold: 500, cityNumberInCountry: 11, completedCityCount: 10)
        #expect(initial.buildBuilding(.barracks, inSlot: 4) == .built(cost: 15, remainingGold: 485))
        let store = try makeStore(initialState: initial)
        let scene = makeScene(store: store, router: RouteSpy())

        // With no slot selected, affordable types render at full alpha so the
        // palette communicates what's buildable in this city.
        #expect(scene.buildButtonIconAlphaForTesting(.archeryRange) == 1.0)

        // Selecting the occupied slot makes build impossible; the icon should
        // dim to match the unaffordable state used by the surrounding background.
        scene.selectSlotForTesting(4)
        #expect(!scene.canBuildForTesting(.archeryRange))
        #expect(scene.buildButtonIconAlphaForTesting(.archeryRange) == 0.65)
        #expect(scene.buildButtonIconAlphaForTesting(.barracks) == 0.65)

        // Re-selecting an empty lot restores the enabled presentation.
        scene.selectSlotForTesting(5)
        #expect(scene.buildButtonIconAlphaForTesting(.archeryRange) == 1.0)
    }

    @Test func scenicLayoutUsesAuthoredNonGridSlotPositions() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100))
        let scene = makeScene(store: store, router: RouteSpy())
        let centers = scene.slotCenterPointsForTesting

        #expect(centers.count == 25)

        let roundedXValues = Set(centers.values.map { Int(($0.x / 4).rounded()) })
        let roundedYValues = Set(centers.values.map { Int(($0.y / 4).rounded()) })

        #expect(roundedXValues.count > 5)
        #expect(roundedYValues.count > 5)
    }

    @Test func emptySlotsUsePadAssetAndNoBuildingAsset() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100))
        let scene = makeScene(store: store, router: RouteSpy())

        #expect(scene.backdropAssetNameForTesting == "building-view-countryside-backdrop")
        #expect(scene.slotPadAssetNameForTesting(1) == "building-pad-empty")
        #expect(scene.slotBuildingAssetNameForTesting(1) == nil)
        #expect(scene.slotLevelTextForTesting(1) == nil)
    }

    @Test func occupiedSlotsUseBuildingAssetAndLevelBadge() throws {
        var initial = KingdomGameState(gold: 200, cityNumberInCountry: 11, completedCityCount: 10)
        #expect(initial.buildBuilding(.mageTower, inSlot: 7) == .built(cost: 40, remainingGold: 160))
        #expect(initial.upgradeBuilding(inSlot: 7) == .upgraded(cost: 30, newLevel: 2, remainingGold: 130))
        let store = try makeStore(initialState: initial)
        let scene = makeScene(store: store, router: RouteSpy())

        #expect(scene.slotPadAssetNameForTesting(7) == "building-pad-empty")
        #expect(scene.slotBuildingAssetNameForTesting(7) == "building-mage-tower")
        #expect(scene.slotLevelTextForTesting(7) == "Lv 2")
    }

    @Test func occupiedSlotBuildingSpritePreservesSourceAssetAspectRatio() throws {
        var initial = KingdomGameState(gold: 500, cityNumberInCountry: 5, completedCityCount: 4)
        #expect(initial.buildBuilding(.stable, inSlot: 7) == .built(cost: 28, remainingGold: 472))
        #expect(initial.buildBuilding(.barracks, inSlot: 8) == .built(cost: 15, remainingGold: 457))
        let store = try makeStore(initialState: initial)
        let scene = makeScene(store: store, router: RouteSpy())

        let stableSize = try #require(scene.slotBuildingSpriteSizeForTesting(7))
        let barracksSize = try #require(scene.slotBuildingSpriteSizeForTesting(8))

        #expect(stableSize.width > stableSize.height)
        #expect(abs(barracksSize.width - barracksSize.height) < 0.5)
    }

    @Test func buildPaletteIconsPreserveSourceAssetAspectRatio() throws {
        let store = try makeStore(
            initialState: KingdomGameState(gold: 500, cityNumberInCountry: 5, completedCityCount: 4)
        )
        let scene = makeScene(store: store, router: RouteSpy())

        let stableSize = try #require(scene.buildButtonIconSizeForTesting(.stable))
        let barracksSize = try #require(scene.buildButtonIconSizeForTesting(.barracks))

        #expect(stableSize.width > stableSize.height)
        #expect(abs(barracksSize.width - barracksSize.height) < 0.5)
    }

    @Test func slotLookupUsesHitAreaInsteadOfOverhangingLabel() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100))
        let scene = makeScene(store: store, router: RouteSpy())
        let hitAreaPoint = try #require(scene.slotHitAreaCenterPointForTesting(7))
        let labelOverhangPoint = try #require(scene.slotLabelOverhangPointForTesting(7))

        #expect(scene.slotAtPointForTesting(hitAreaPoint) == 7)
        #expect(scene.slotAtPointForTesting(labelOverhangPoint) == nil)
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
        scene.buildSelectedSlotForTesting(.barracks)
        scene.selectSlotForTesting(4)

        #expect(!scene.canBuildForTesting(.barracks))
        #expect(!scene.canBuildForTesting(.archeryRange))
        #expect(scene.canUpgradeSelectedSlotForTesting)

        scene.upgradeSelectedSlotForTesting()

        #expect(store.load().cityBattleStateForCurrentCity.building(inSlot: 4)?.level == 2)
    }

    @Test func lockedBuildActionShowsUnlockFeedback() throws {
        let store = try makeStore(
            initialState: KingdomGameState(gold: 500, cityNumberInCountry: 4, completedCityCount: 3)
        )
        let scene = makeScene(store: store, router: RouteSpy())

        scene.selectSlotForTesting(3)
        scene.buildSelectedSlotForTesting(.stable)

        #expect(scene.feedbackTextForTesting == "Stable unlocks at City 5.")
        #expect(store.load().cityBattleStateForCurrentCity.occupiedSlotCount == 0)
    }

    @Test func newBuildingTypesUseReadableSlotLabelsAndAssets() throws {
        let store = try makeStore(
            initialState: KingdomGameState(gold: 500, cityNumberInCountry: 11, completedCityCount: 10)
        )
        let scene = makeScene(store: store, router: RouteSpy())

        scene.selectSlotForTesting(1)
        scene.buildSelectedSlotForTesting(.stable)
        scene.selectSlotForTesting(2)
        scene.buildSelectedSlotForTesting(.mageTower)
        scene.selectSlotForTesting(3)
        scene.buildSelectedSlotForTesting(.siegeWorkshop)

        #expect(scene.slotTextForTesting(1)?.contains("Stable") == true)
        #expect(scene.slotTextForTesting(2)?.contains("Mage Tower") == true)
        #expect(scene.slotTextForTesting(3)?.contains("Siege Workshop") == true)
        #expect(scene.slotBuildingAssetNameForTesting(1) == "building-stable")
        #expect(scene.slotBuildingAssetNameForTesting(2) == "building-mage-tower")
        #expect(scene.slotBuildingAssetNameForTesting(3) == "building-siege-workshop")
    }

    @Test func successfulBuildActionsPersistEveryBuildingType() throws {
        let store = try makeStore(
            initialState: KingdomGameState(gold: 500, cityNumberInCountry: 11, completedCityCount: 10)
        )
        let scene = makeScene(store: store, router: RouteSpy())

        for (index, type) in BuildingType.allCases.enumerated() {
            let slot = index + 1
            scene.selectSlotForTesting(slot)
            scene.buildSelectedSlotForTesting(type)

            #expect(store.load().cityBattleStateForCurrentCity.building(inSlot: slot)?.type == type)
        }
    }

    @Test func typeCapAndInsufficientGoldShowFeedback() throws {
        var initial = KingdomGameState(gold: 75, cityNumberInCountry: 2, completedCityCount: 1)
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
        let buildFrames = try BuildingType.allCases.map { type in
            try #require(frames.buildButtonFrames[type])
        }
        for frame in buildFrames {
            #expect(!frames.grid.intersects(frame))
            #expect(!frame.intersects(frames.upgradeButton))
            #expect(!frame.intersects(frames.battleButton))
        }
        for firstIndex in buildFrames.indices {
            for secondIndex in buildFrames.indices where secondIndex > firstIndex {
                #expect(!buildFrames[firstIndex].intersects(buildFrames[secondIndex]))
            }
        }
        #expect(!frames.grid.intersects(frames.upgradeButton))
        #expect(!frames.grid.intersects(frames.battleButton))
        #expect(!frames.upgradeButton.intersects(frames.battleButton))
    }

    @Test func shortLandscapeLayoutKeepsGridBetweenPanelsAndAwayFromButtons() throws {
        let size = CGSize(width: 568, height: 320)
        let store = try makeStore(initialState: KingdomGameState(gold: 100))
        let scene = makeScene(size: size, store: store, router: RouteSpy())
        let frames = try #require(scene.buildingLayoutFramesForTesting)

        #expect(frames.scene.contains(frames.titlePanel))
        #expect(frames.scene.contains(frames.actionPanel))
        #expect(frames.scene.contains(frames.grid))
        #expect(frames.grid.maxY < frames.titlePanel.minY)
        #expect(frames.grid.minY > frames.actionPanel.maxY)
        let minimumControlGap: CGFloat = 2
        let buildFrames = try BuildingType.allCases.map { type in
            try #require(frames.buildButtonFrames[type])
        }
        for frame in buildFrames {
            #expect(!frames.grid.intersects(frame))
            #expect(!frame.intersects(frames.upgradeButton))
            #expect(!frame.intersects(frames.battleButton))
            #expect(frame.minY - frames.upgradeButton.maxY > minimumControlGap)
            #expect(frame.minY - frames.battleButton.maxY > minimumControlGap)
        }
        for firstIndex in buildFrames.indices {
            for secondIndex in buildFrames.indices where secondIndex > firstIndex {
                #expect(!buildFrames[firstIndex].intersects(buildFrames[secondIndex]))
            }
        }
        #expect(!frames.grid.intersects(frames.upgradeButton))
        #expect(!frames.grid.intersects(frames.battleButton))
        #expect(!frames.upgradeButton.intersects(frames.battleButton))
    }

    @Test func occupiedShortLandscapeLayoutKeepsGridBetweenPanels() throws {
        let size = CGSize(width: 568, height: 320)
        var initial = KingdomGameState(gold: 100)
        #expect(initial.buildBuilding(.barracks, inSlot: 24) == .built(cost: 15, remainingGold: 85))
        let store = try makeStore(initialState: initial)
        let scene = makeScene(size: size, store: store, router: RouteSpy())
        let frames = try #require(scene.buildingLayoutFramesForTesting)

        #expect(frames.scene.contains(frames.grid))
        #expect(frames.grid.maxY < frames.titlePanel.minY)
        #expect(frames.grid.minY > frames.actionPanel.maxY)
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
        scene.buildSelectedSlotForTesting(.barracks)

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
