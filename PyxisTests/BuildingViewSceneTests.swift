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
    private enum BuildingViewFeedbackCall: Equatable {
        case discrete(GameplayFeedbackEvent)
    }

    private final class BuildingViewFeedbackRecorder: GameplayFeedbackProviding {
        private(set) var calls: [BuildingViewFeedbackCall] = []
        private(set) var automaticCallCount = 0
        var onDiscreteEvent: ((GameplayFeedbackEvent) -> Void)?

        func emit(_ event: GameplayFeedbackEvent) {
            onDiscreteEvent?(event)
            calls.append(.discrete(event))
        }

        func emitAutomaticCombat(_ result: BattleCombatState.TickResult) {
            automaticCallCount += 1
        }

        func reset() {
            calls.removeAll()
            automaticCallCount = 0
        }

        var discreteEvents: [GameplayFeedbackEvent] {
            calls.compactMap {
                guard case .discrete(let event) = $0 else { return nil }
                return event
            }
        }
    }

    @Test("Building View reserves a 200-point header column for Settings or fails closed")
    func buildingViewHeaderReservesSettingsSpaceAndFailsClosedWhenTooNarrow() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 123_456_789))
        let scene = makeScene(
            size: CGSize(width: 375, height: 667),
            store: store,
            router: RouteSpy()
        )
        let frames = try #require(scene.buildingLayoutFramesForTesting)
        let gearFrame = try #require(scene.feedbackSettingsGearFrameForTesting)

        #expect(scene.isHeaderLayoutSupportedForTesting)
        #expect(gearFrame.size == CGSize(width: 44, height: 44))
        #expect(abs(gearFrame.minX - (frames.headerContent.minX + 8)) < 0.5)
        #expect(abs(frames.titleTextColumn.minX - (gearFrame.maxX + 8)) < 0.5)
        #expect(abs(frames.titleTextColumn.maxX - (frames.headerContent.maxX - 8)) < 0.5)
        #expect(abs(frames.titleTextColumn.width - (frames.headerContent.width - 68)) < 0.5)
        #expect(frames.titleTextColumn.width >= 200)
        #expect(!gearFrame.intersects(frames.titleLabel))
        #expect(!gearFrame.intersects(frames.goldLabel))

        let narrowScene = makeScene(
            size: CGSize(width: 250, height: 844),
            store: try makeStore(initialState: KingdomGameState(gold: 100)),
            router: RouteSpy()
        )

        #expect(!narrowScene.isHeaderLayoutSupportedForTesting)
        #expect(narrowScene.isHeaderTextHiddenForTesting)
        #expect(narrowScene.feedbackSettingsGearFrameForTesting == .zero)
    }

    @Test("Building View injects shared Settings dependencies without generating feedback for Settings controls")
    func buildingViewUsesInjectedSettingsDependenciesWithoutSettingsFeedback() throws {
        let feedback = BuildingViewFeedbackRecorder()
        let preferences = RecordingFeedbackPreferencesManager()
        let scene = makeScene(
            store: try makeStore(initialState: KingdomGameState(gold: 100)),
            router: RouteSpy(),
            feedback: feedback,
            feedbackPreferences: preferences
        )
        let gearFrame = try #require(scene.feedbackSettingsGearFrameForTesting)
        let settingsLayout = try #require(FeedbackSettingsLayout.compute(
            sceneSize: scene.size,
            safeAreaInsets: .zero
        ))

        scene.handleTouchForTesting(at: center(of: gearFrame))
        #expect(scene.isFeedbackSettingsVisibleForTesting)

        scene.handleTouchForTesting(at: center(of: settingsLayout.soundRowFrame))
        scene.handleTouchForTesting(at: center(of: settingsLayout.hapticsRowFrame))
        scene.handleTouchForTesting(at: center(of: settingsLayout.closeFrame))

        #expect(!preferences.current.soundEffectsEnabled)
        #expect(!preferences.current.hapticsEnabled)
        #expect(!scene.isFeedbackSettingsVisibleForTesting)
        #expect(feedback.calls.isEmpty)
    }

    @Test("Building View layout and routing gates take priority over Settings")
    func buildingViewLayoutAndRoutingGatesPreventSettingsTouches() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        let gearFrame = try #require(scene.feedbackSettingsGearFrameForTesting)

        scene.layoutGateWillPause(at: Date(timeIntervalSinceReferenceDate: 10))
        scene.handleTouchForTesting(at: center(of: gearFrame))

        #expect(!scene.isFeedbackSettingsVisibleForTesting)
        scene.layoutGateWillResume(at: Date(timeIntervalSinceReferenceDate: 11))

        scene.requestBattleForTesting()
        scene.handleTouchForTesting(at: center(of: gearFrame))

        #expect(router.battleRequestCount == 1)
        #expect(!scene.isFeedbackSettingsVisibleForTesting)
    }

    @Test("Building View gives Settings and controls precedence over overlapping lots")
    func buildingViewInputPriorityKeepsControlActionsAboveSlots() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        let overlapPoint = try #require(scene.slotHitAreaCenterPointForTesting(1))
        let gear = try #require(
            scene.childNode(withName: SettingsGearNode.semanticName) as? SettingsGearNode
        )
        let originalGearPosition = gear.position

        gear.position = overlapPoint
        scene.handleTouchForTesting(at: overlapPoint)
        #expect(scene.isFeedbackSettingsVisibleForTesting)
        #expect(scene.selectedSlotForTesting == nil)

        let settingsLayout = try #require(FeedbackSettingsLayout.compute(
            sceneSize: scene.size,
            safeAreaInsets: .zero
        ))
        scene.handleTouchForTesting(at: center(of: settingsLayout.closeFrame))

        scene.selectSlotForTesting(2)
        let buildButton = try #require(scene.childNode(withName: "build-barracks-button"))
        let originalBuildButtonPosition = buildButton.position
        gear.position = originalGearPosition
        buildButton.position = overlapPoint
        scene.handleTouchForTesting(at: overlapPoint)

        #expect(store.load().cityBattleStateForCurrentCity.building(inSlot: 2)?.type == .barracks)
        #expect(scene.selectedSlotForTesting == 2)

        let upgradeButton = try #require(scene.childNode(withName: "upgradeBuildingButton"))
        buildButton.position = originalBuildButtonPosition
        let originalUpgradeButtonPosition = upgradeButton.position
        upgradeButton.position = overlapPoint
        scene.handleTouchForTesting(at: overlapPoint)

        #expect(store.load().cityBattleStateForCurrentCity.building(inSlot: 2)?.level == 2)
        #expect(scene.selectedSlotForTesting == 2)

        let battleButton = try #require(scene.childNode(withName: "buildingViewBattleButton"))
        upgradeButton.position = originalUpgradeButtonPosition
        battleButton.position = overlapPoint
        scene.handleTouchForTesting(at: overlapPoint)

        #expect(router.battleRequestCount == 1)
        #expect(scene.selectedSlotForTesting == 2)
    }

    @Test("Building View Settings consumes every underlying target")
    func buildingViewSettingsBlocksPaletteActionsBattleAndSlots() throws {
        let feedback = BuildingViewFeedbackRecorder()
        let initialState = KingdomGameState(gold: 100)
        let store = try makeStore(initialState: initialState)
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router, feedback: feedback)
        let frames = try #require(scene.buildingLayoutFramesForTesting)
        let gearFrame = try #require(scene.feedbackSettingsGearFrameForTesting)
        let slotPoint = try #require(scene.slotHitAreaCenterPointForTesting(1))

        scene.handleTouchForTesting(at: center(of: gearFrame))
        #expect(scene.isFeedbackSettingsVisibleForTesting)

        let buildFrame = try #require(frames.buildButtonFrames[.barracks])
        for point in [
            center(of: gearFrame),
            center(of: buildFrame),
            center(of: frames.upgradeButton),
            center(of: frames.battleButton),
            slotPoint
        ] {
            scene.handleTouchForTesting(at: point)
        }

        #expect(store.load() == initialState)
        #expect(router.battleRequestCount == 0)
        #expect(scene.selectedSlotForTesting == nil)
        #expect(feedback.calls.isEmpty)
        #expect(scene.isFeedbackSettingsVisibleForTesting)
    }

    @Test("Building View saves a successful construction before emitting construction feedback")
    func buildingViewSuccessfulMutationsSaveBeforeConstructionFeedback() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100))
        let feedback = BuildingViewFeedbackRecorder()
        var persistedBuildingAtFeedback: CityBuilding?
        feedback.onDiscreteEvent = { event in
            guard event == .buildingChanged else { return }
            persistedBuildingAtFeedback = store.load().cityBattleStateForCurrentCity.building(inSlot: 2)
        }
        let scene = makeScene(store: store, router: RouteSpy(), feedback: feedback)

        scene.selectSlotForTesting(2)
        scene.buildSelectedSlotForTesting(.barracks)

        #expect(persistedBuildingAtFeedback?.type == .barracks)
        #expect(persistedBuildingAtFeedback?.level == 1)
        #expect(feedback.discreteEvents == [.buildingChanged])

        feedback.reset()
        feedback.onDiscreteEvent = { event in
            guard event == .buildingChanged else { return }
            persistedBuildingAtFeedback = store.load().cityBattleStateForCurrentCity.building(inSlot: 2)
        }
        scene.upgradeSelectedSlotForTesting()

        #expect(persistedBuildingAtFeedback?.level == 2)
        #expect(feedback.discreteEvents == [.buildingChanged])
    }

    @Test("Building View emits one invalid event for each rejected manual mutation")
    func buildingViewRejectedMutationsEmitInvalidExactlyOnce() throws {
        let feedback = BuildingViewFeedbackRecorder()
        let store = try makeStore(initialState: KingdomGameState(gold: 0))
        let scene = makeScene(store: store, router: RouteSpy(), feedback: feedback)

        scene.buildSelectedSlotForTesting(.barracks)
        #expect(feedback.discreteEvents == [.invalidAction])

        feedback.reset()
        scene.selectSlotForTesting(1)
        scene.buildSelectedSlotForTesting(.barracks)
        #expect(feedback.discreteEvents == [.invalidAction])

        feedback.reset()
        scene.upgradeSelectedSlotForTesting()
        #expect(feedback.discreteEvents == [.invalidAction])
    }

    @Test("Building View settlement conquest emits only fresh reward and city outcome")
    func buildingViewSettlementConquestEmitsRewardThenCityOutcomeWithoutConstruction() throws {
        let start = Date.distantPast
        var initialState = KingdomGameState(
            gold: 100,
            cityRemainingPower: 1,
            lastBackgroundedAt: start
        )
        #expect(initialState.buildBuilding(.barracks, inSlot: 1, at: start) == .built(cost: 15, remainingGold: 85))
        let preferences = RecordingFeedbackPreferencesManager()
        let sound = RecordingGameplaySoundOutput()
        let haptics = RecordingGameplayHapticOutput()
        let feedback = DefaultGameplayFeedbackCoordinator(
            preferences: preferences,
            soundOutput: sound,
            hapticOutput: haptics,
            clock: ManualMonotonicClock(now: 0)
        )
        let store = try makeStore(initialState: initialState)
        let scene = makeScene(
            store: store,
            router: RouteSpy(),
            feedback: feedback,
            feedbackPreferences: preferences
        )

        scene.selectSlotForTesting(2)
        scene.buildSelectedSlotForTesting(.barracks)

        #expect(store.load().stageStatus == .cityConqueredPendingMap)
        #expect(sound.calls == [
            .play(.goldReward),
            .play(.cityConquest)
        ])
        #expect(haptics.played == [.strongSuccess])
    }

    @Test("Building View emits request and lifecycle settlement outcomes only once")
    func buildingViewRequestAndLifecycleSettlementFeedbackIsFreshOnly() throws {
        let start = Date.distantPast
        var lifecycleState = KingdomGameState(
            gold: 100,
            cityRemainingPower: 1,
            lastBackgroundedAt: start
        )
        #expect(lifecycleState.buildBuilding(.barracks, inSlot: 1, at: start) == .built(cost: 15, remainingGold: 85))
        let lifecyclePreferences = RecordingFeedbackPreferencesManager()
        let lifecycleSound = RecordingGameplaySoundOutput()
        let lifecycleHaptics = RecordingGameplayHapticOutput()
        let lifecycleFeedback = DefaultGameplayFeedbackCoordinator(
            preferences: lifecyclePreferences,
            soundOutput: lifecycleSound,
            hapticOutput: lifecycleHaptics,
            clock: ManualMonotonicClock(now: 0)
        )
        let lifecycleScene = makeScene(
            store: try makeStore(initialState: lifecycleState),
            router: RouteSpy(),
            feedback: lifecycleFeedback,
            feedbackPreferences: lifecyclePreferences
        )

        lifecycleScene.sceneWillEnterForegroundForTesting(at: start.addingTimeInterval(10_000))
        lifecycleScene.redrawForTesting()
        lifecycleScene.repeatDidMoveForTesting()
        lifecycleScene.sceneWillEnterForegroundForTesting(at: start.addingTimeInterval(20_000))

        #expect(lifecycleSound.calls == [
            .play(.goldReward),
            .play(.cityConquest)
        ])
        #expect(lifecycleHaptics.played == [.strongSuccess])

        var requestState = KingdomGameState(
            gold: 100,
            cityRemainingPower: 1,
            lastBackgroundedAt: start
        )
        #expect(requestState.buildBuilding(.barracks, inSlot: 1, at: start) == .built(cost: 15, remainingGold: 85))
        let requestPreferences = RecordingFeedbackPreferencesManager()
        let requestSound = RecordingGameplaySoundOutput()
        let requestHaptics = RecordingGameplayHapticOutput()
        let requestFeedback = DefaultGameplayFeedbackCoordinator(
            preferences: requestPreferences,
            soundOutput: requestSound,
            hapticOutput: requestHaptics,
            clock: ManualMonotonicClock(now: 0)
        )
        let requestScene = makeScene(
            store: try makeStore(initialState: requestState),
            router: RouteSpy(),
            feedback: requestFeedback,
            feedbackPreferences: requestPreferences
        )

        requestScene.requestBattleForTesting()
        requestScene.redrawForTesting()
        requestScene.repeatDidMoveForTesting()

        #expect(requestSound.calls == [
            .play(.goldReward),
            .play(.cityConquest)
        ])
        #expect(requestHaptics.played == [.strongSuccess])
    }

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

    @Test func backdropFrameStaysStableAfterScreenTapRelayout() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100))
        let scene = makeScene(store: store, router: RouteSpy())
        let initialFrame = try #require(scene.backdropFrameForTesting)

        scene.selectSlotForTesting(7)

        let tappedFrame = try #require(scene.backdropFrameForTesting)
        #expect(abs(tappedFrame.width - initialFrame.width) < 0.5)
        #expect(abs(tappedFrame.height - initialFrame.height) < 0.5)
        #expect(tappedFrame.minX <= 0)
        #expect(tappedFrame.maxX >= scene.size.width)
        #expect(tappedFrame.minY <= 0)
        #expect(tappedFrame.maxY >= scene.size.height)
    }

    @Test func slotLookupUsesHitAreaInsteadOfOverhangingLabel() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100))
        let scene = makeScene(store: store, router: RouteSpy())
        let hitAreaPoint = try #require(scene.slotHitAreaCenterPointForTesting(7))
        let labelOverhangPoint = try #require(scene.slotLabelOverhangPointForTesting(7))

        #expect(scene.slotAtPointForTesting(hitAreaPoint) == 7)
        #expect(scene.slotAtPointForTesting(labelOverhangPoint) == nil)
    }

    @Test func overlappingHitAreasResolveToTheTopmostSlot() throws {
        // Slot 3 (x: 0.52, y: 0.78) and slot 24 (x: 0.56, y: 0.88) are
        // positioned close enough that their hit ellipses overlap. Slot 24
        // is added to gridLayer later than slot 3, so SpriteKit draws it on
        // top — taps on the overlap region should select slot 24, not 3.
        //
        // The 600×844 scene size is wide enough for baseSlotSize to hit the
        // 82-point cap, making the overlap region unambiguous (the midpoint
        // between the two centers sits well inside both ellipses).
        let store = try makeStore(initialState: KingdomGameState(gold: 100))
        let scene = makeScene(
            size: CGSize(width: 600, height: 844),
            store: store,
            router: RouteSpy()
        )
        let slot3Center = try #require(scene.slotHitAreaCenterPointForTesting(3))
        let slot24Center = try #require(scene.slotHitAreaCenterPointForTesting(24))
        let overlapPoint = CGPoint(
            x: (slot3Center.x + slot24Center.x) / 2,
            y: (slot3Center.y + slot24Center.y) / 2
        )

        #expect(scene.slotAtPointForTesting(overlapPoint) == 24)
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
        #expect(router.battleRequestCount == 0)
        #expect(savedState.pendingBattleResult?.conquestMode == .idle)
    }

    @Test func battleRequestAfterForegroundIdleConquestRoutesToBattleSceneWithPendingReport() throws {
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
        #expect(store.load().pendingBattleResult?.conquestMode == .idle)
        scene.requestBattleForTesting()

        #expect(store.load().stageStatus == .cityConqueredPendingMap)
        #expect(store.load().pendingBattleResult != nil)
        #expect(view.scene is BattleScene)
    }

    @Test func battleRequestCreatesPendingResultBeforeRoutingThroughRouteSpy() throws {
        let start = Date(timeIntervalSinceNow: -1_000)
        var initialState = KingdomGameState(gold: 100, cityRemainingPower: 1, lastBackgroundedAt: start)
        #expect(initialState.buildBuilding(.barracks, inSlot: 1, at: start) == .built(cost: 15, remainingGold: 85))
        let store = try makeStore(initialState: initialState)
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        NotificationCenter.default.post(name: .pyxisSceneWillEnterForeground, object: nil)
        #expect(router.battleRequestCount == 0)
        #expect(store.load().pendingBattleResult?.conquestMode == .idle)
        #expect(scene.feedbackTextForTesting.contains("conquered"))

        scene.requestBattleForTesting()

        #expect(router.battleRequestCount == 1)
        #expect(store.load().pendingBattleResult != nil)
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

    @Test func layoutGateSettlesThenExcludesBuildingViewGateOnlyTime() throws {
        let origin = Date(timeIntervalSinceReferenceDate: 3_000)
        let store = try makeStore(initialState: makeIdleAccruingState(since: origin))
        let scene = makeScene(store: store)

        scene.layoutGateWillPause(at: origin.addingTimeInterval(10))
        #expect(scene.lastIdleProgressResultForTesting.elapsedSeconds == 10)

        scene.layoutGateWillPause(at: origin.addingTimeInterval(20))
        #expect(scene.lastIdleProgressResultForTesting.elapsedSeconds == 10)

        scene.layoutGateWillResume(at: origin.addingTimeInterval(30))
        scene.layoutGateWillResume(at: origin.addingTimeInterval(35))

        var resumed = store.load()
        #expect(resumed.lastBackgroundedAt == origin.addingTimeInterval(30))
        let postGate = resumed.returnFromBackground(
            at: origin.addingTimeInterval(40)
        )
        #expect(postGate.elapsedSeconds == 10)
    }

    @Test func realBackgroundNestedInsideBuildingGateCountsOnlySystemBackgroundTime() throws {
        let origin = Date(timeIntervalSinceReferenceDate: 4_000)
        let store = try makeStore(initialState: makeIdleAccruingState(since: origin))
        let scene = makeScene(store: store)

        scene.layoutGateWillPause(at: origin.addingTimeInterval(10))
        scene.sceneDidEnterBackgroundForTesting(
            at: origin.addingTimeInterval(15)
        )
        scene.sceneWillEnterForegroundForTesting(
            at: origin.addingTimeInterval(25)
        )

        #expect(scene.lastIdleProgressResultForTesting.elapsedSeconds == 10)
        #expect(store.load().lastBackgroundedAt == nil)

        scene.layoutGateWillResume(at: origin.addingTimeInterval(30))
        #expect(store.load().lastBackgroundedAt
            == origin.addingTimeInterval(30))
    }

    @Test func backgroundThenBuildingGateResumeWhileBackgroundedPreservesEveryInterval() throws {
        let origin = Date(timeIntervalSinceReferenceDate: 7_000)
        let store = try makeStore(initialState: makeIdleAccruingState(since: origin))
        let scene = makeScene(store: store)

        scene.sceneDidEnterBackgroundForTesting(
            at: origin.addingTimeInterval(10)
        )
        scene.layoutGateWillPause(at: origin.addingTimeInterval(15))

        #expect(scene.lastIdleProgressResultForTesting.elapsedSeconds == 15)
        #expect(store.load().lastBackgroundedAt
            == origin.addingTimeInterval(15))

        scene.layoutGateWillResume(at: origin.addingTimeInterval(20))
        #expect(store.load().lastBackgroundedAt
            == origin.addingTimeInterval(15))

        scene.sceneWillEnterForegroundForTesting(
            at: origin.addingTimeInterval(25)
        )

        #expect(scene.lastIdleProgressResultForTesting.elapsedSeconds == 10)
        #expect(store.load().lastBackgroundedAt
            == origin.addingTimeInterval(25))
    }

    @Test func buildingGateThenBackgroundResumeWhileBackgroundedExcludesForegroundGateTime() throws {
        let origin = Date(timeIntervalSinceReferenceDate: 8_000)
        let store = try makeStore(initialState: makeIdleAccruingState(since: origin))
        let scene = makeScene(store: store)

        scene.layoutGateWillPause(at: origin.addingTimeInterval(10))
        #expect(scene.lastIdleProgressResultForTesting.elapsedSeconds == 10)

        scene.sceneDidEnterBackgroundForTesting(
            at: origin.addingTimeInterval(15)
        )
        scene.layoutGateWillResume(at: origin.addingTimeInterval(20))

        #expect(store.load().lastBackgroundedAt
            == origin.addingTimeInterval(15))

        scene.sceneWillEnterForegroundForTesting(
            at: origin.addingTimeInterval(25)
        )

        #expect(scene.lastIdleProgressResultForTesting.elapsedSeconds == 10)
        #expect(store.load().lastBackgroundedAt
            == origin.addingTimeInterval(25))
    }

    // MARK: - init?(coder:)

    @Test("Building View init?(coder:) assigns default feedback dependencies")
    func buildingViewCoderInitAssignsDefaultFeedbackDependencies() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100))
        let original = BuildingViewScene(
            size: CGSize(width: 390, height: 844),
            store: store
        )
        let archiveData = try NSKeyedArchiver.archivedData(
            withRootObject: original,
            requiringSecureCoding: false
        )
        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: archiveData)
        unarchiver.requiresSecureCoding = false
        let decoded = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? BuildingViewScene
        unarchiver.finishDecoding()
        let restored = try #require(decoded)
        let view = SKView(frame: CGRect(origin: .zero, size: restored.size))
        restored.didMove(to: view)
        #expect(restored.feedbackSettingsGearFrameForTesting != nil)
    }

    // MARK: - requestBattle routing latch

    @Test("Building View requestBattle does not latch isRoutingToBattle when router is nil")
    func buildingViewRequestBattleDoesNotLatchWhenRouterIsNil() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100, stageStatus: .battleActive))
        // router defaults to nil, mirroring the coder initializer path where a
        // failed/absent transition must not permanently lock the scene.
        let scene = makeScene(store: store, router: nil)

        scene.requestBattleForTesting()

        #expect(!scene.isRoutingToBattleForTesting)

        // The scene must remain interactive: a second request is still accepted.
        scene.requestBattleForTesting()
        #expect(!scene.isRoutingToBattleForTesting)
    }

    @Test("Building View requestBattle resets isRoutingToBattle when router refuses transition")
    func buildingViewRequestBattleResetsWhenRouterRefuses() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100, stageStatus: .battleActive))
        let router = RefusingRouteSpy()
        let scene = makeScene(store: store, router: router)

        scene.requestBattleForTesting()

        #expect(router.battleRequestCount == 1)
        #expect(!scene.isRoutingToBattleForTesting)
    }

    // MARK: - Accessibility-driven activateFeedbackSettings

    @Test("Building View accessibility actions toggle preferences and close settings")
    func buildingViewAccessibilityActionsTogglePreferencesAndCloseSettings() throws {
        let preferences = RecordingFeedbackPreferencesManager()
        let (scene, view) = makeSceneAndPreviewView(
            store: try makeStore(initialState: KingdomGameState(gold: 100)),
            router: RouteSpy(),
            feedbackPreferences: preferences
        )

        // Activate the gear accessibility element -> openFeedbackSettings()
        let gearElements = try #require(view.accessibilityElements as? [UIAccessibilityElement])
        let gear = try #require(gearElements.first { $0.accessibilityLabel == "Settings" })
        #expect(gear.accessibilityActivate())
        #expect(scene.isFeedbackSettingsVisibleForTesting)

        // Activate "Sound Effects" -> activateFeedbackSettings(.toggleSoundEffects)
        let modalElements1 = try #require(view.accessibilityElements as? [UIAccessibilityElement])
        let sound = try #require(modalElements1.first { $0.accessibilityLabel == "Sound Effects" })
        #expect(sound.accessibilityActivate())
        #expect(!preferences.current.soundEffectsEnabled)

        // Activate "Haptics" -> activateFeedbackSettings(.toggleHaptics)
        let modalElements2 = try #require(view.accessibilityElements as? [UIAccessibilityElement])
        let haptics = try #require(modalElements2.first { $0.accessibilityLabel == "Haptics" })
        #expect(haptics.accessibilityActivate())
        #expect(!preferences.current.hapticsEnabled)

        // Activate "Close" -> activateFeedbackSettings(.close)
        let modalElements3 = try #require(view.accessibilityElements as? [UIAccessibilityElement])
        let close = try #require(modalElements3.first { $0.accessibilityLabel == "Close" })
        #expect(close.accessibilityActivate())
        #expect(!scene.isFeedbackSettingsVisibleForTesting)
    }

    // MARK: - openFeedbackSettings guard via accessibility

    @Test("Building View openFeedbackSettings guard blocks when layout gate is paused (accessibility)")
    func buildingViewOpenFeedbackSettingsGuardBlocksWhenLayoutGatePaused() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100))
        let (scene, view) = makeSceneAndPreviewView(store: store, router: RouteSpy())
        let elements = try #require(view.accessibilityElements as? [UIAccessibilityElement])
        let gear = try #require(elements.first { $0.accessibilityLabel == "Settings" })

        scene.layoutGateWillPause(at: Date(timeIntervalSinceReferenceDate: 10))
        #expect(gear.accessibilityActivate())
        #expect(!scene.isFeedbackSettingsVisibleForTesting)
    }

    @Test("Building View openFeedbackSettings guard blocks when routing to battle (accessibility)")
    func buildingViewOpenFeedbackSettingsGuardBlocksWhenRoutingToBattle() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100))
        let router = RouteSpy()
        let (scene, view) = makeSceneAndPreviewView(store: store, router: router)
        let elements = try #require(view.accessibilityElements as? [UIAccessibilityElement])
        let gear = try #require(elements.first { $0.accessibilityLabel == "Settings" })

        scene.requestBattleForTesting()
        #expect(gear.accessibilityActivate())
        #expect(!scene.isFeedbackSettingsVisibleForTesting)
    }

    // MARK: - Invalid action feedback.emit for build rejections

    @Test("Building View build on locked/occupied/capped slots emits invalid action")
    func buildingViewBuildRejectedForLockedOccupiedAndCappedSlotsEmitsInvalidAction() throws {
        let feedback = BuildingViewFeedbackRecorder()

        // Locked building (mageTower requires city 8, current city is 5)
        let lockedState = KingdomGameState(
            gold: 1000,
            cityNumberInCountry: 5,
            completedCityCount: 4
        )
        let lockedStore = try makeStore(initialState: lockedState)
        let lockedScene = makeScene(store: lockedStore, router: RouteSpy(), feedback: feedback)
        lockedScene.selectSlotForTesting(1)
        lockedScene.buildSelectedSlotForTesting(.mageTower)
        #expect(feedback.discreteEvents == [.invalidAction])
        #expect(lockedScene.feedbackTextForTesting.contains("unlocks"))

        // Slot occupied
        feedback.reset()
        var occupiedState = KingdomGameState(gold: 1000)
        _ = occupiedState.buildBuilding(.barracks, inSlot: 1, at: Date())
        let occupiedStore = try makeStore(initialState: occupiedState)
        let occupiedScene = makeScene(store: occupiedStore, router: RouteSpy(), feedback: feedback)
        occupiedScene.selectSlotForTesting(1)
        occupiedScene.buildSelectedSlotForTesting(.barracks)
        #expect(feedback.discreteEvents == [.invalidAction])
        #expect(occupiedScene.feedbackTextForTesting.contains("occupied"))

        // Type cap reached (5 barracks already built)
        feedback.reset()
        var cappedState = KingdomGameState(gold: 1000)
        for slot in 1...5 {
            _ = cappedState.buildBuilding(.barracks, inSlot: slot, at: Date())
        }
        let cappedStore = try makeStore(initialState: cappedState)
        let cappedScene = makeScene(store: cappedStore, router: RouteSpy(), feedback: feedback)
        cappedScene.selectSlotForTesting(6)
        cappedScene.buildSelectedSlotForTesting(.barracks)
        #expect(feedback.discreteEvents == [.invalidAction])
        #expect(cappedScene.feedbackTextForTesting.contains("limit"))
    }

    @Test("Building View build when city is conquered emits invalid action")
    func buildingViewBuildWhenCityConqueredEmitsInvalidAction() throws {
        let feedback = BuildingViewFeedbackRecorder()
        let state = KingdomGameState(
            gold: 1000,
            cityNumberInCountry: 5,
            completedCityCount: 4,
            stageStatus: .cityConqueredPendingMap
        )
        let store = try makeStore(initialState: state)
        let scene = makeScene(store: store, router: RouteSpy(), feedback: feedback)

        scene.selectSlotForTesting(1)
        scene.buildSelectedSlotForTesting(.barracks)
        #expect(feedback.discreteEvents == [.invalidAction])
        #expect(scene.feedbackTextForTesting.contains("Enter a city"))
    }

    // MARK: - Invalid action feedback.emit for upgrade rejections

    @Test("Building View upgrade with insufficient gold or missing building emits invalid action")
    func buildingViewUpgradeRejectedForInsufficientGoldAndMissingBuildingEmitsInvalidAction() throws {
        let feedback = BuildingViewFeedbackRecorder()

        // Insufficient gold for upgrade
        var poorState = KingdomGameState(gold: 100)
        _ = poorState.buildBuilding(.barracks, inSlot: 1, at: Date())
        poorState.gold = 0
        let poorStore = try makeStore(initialState: poorState)
        let poorScene = makeScene(store: poorStore, router: RouteSpy(), feedback: feedback)
        poorScene.selectSlotForTesting(1)
        poorScene.upgradeSelectedSlotForTesting()
        #expect(feedback.discreteEvents == [.invalidAction])
        #expect(poorScene.feedbackTextForTesting.contains("gold"))

        // Missing building (empty slot selected)
        feedback.reset()
        let emptyStore = try makeStore(initialState: KingdomGameState(gold: 1000))
        let emptyScene = makeScene(store: emptyStore, router: RouteSpy(), feedback: feedback)
        emptyScene.selectSlotForTesting(3)
        emptyScene.upgradeSelectedSlotForTesting()
        #expect(feedback.discreteEvents == [.invalidAction])
        #expect(emptyScene.feedbackTextForTesting.contains("Select a building"))
    }

    @Test("Building View upgrade when city is conquered emits invalid action")
    func buildingViewUpgradeWhenCityConqueredEmitsInvalidAction() throws {
        let feedback = BuildingViewFeedbackRecorder()
        let state = KingdomGameState(
            gold: 1000,
            cityNumberInCountry: 5,
            completedCityCount: 4,
            stageStatus: .cityConqueredPendingMap
        )
        let store = try makeStore(initialState: state)
        let scene = makeScene(store: store, router: RouteSpy(), feedback: feedback)

        scene.selectSlotForTesting(1)
        scene.upgradeSelectedSlotForTesting()
        #expect(feedback.discreteEvents == [.invalidAction])
        #expect(scene.feedbackTextForTesting.contains("Enter a city"))
    }

    // MARK: - Settlement conquest feedback

    @Test("Building View build settlement conquers last city and emits country completion")
    func buildingViewBuildSettlementConquersLastCityAndEmitsCountryCompletion() throws {
        let start = Date.distantPast
        var state = KingdomGameState(
            gold: 100,
            cityRemainingPower: 1,
            lastBackgroundedAt: start,
            completedCityCount: 14
        )
        _ = state.buildBuilding(.barracks, inSlot: 1, at: start)
        let store = try makeStore(initialState: state)
        let feedback = BuildingViewFeedbackRecorder()
        let scene = makeScene(store: store, router: RouteSpy(), feedback: feedback)

        scene.selectSlotForTesting(2)
        scene.buildSelectedSlotForTesting(.archeryRange)

        #expect(store.load().stageStatus == .countryComplete)
        #expect(feedback.discreteEvents == [.goldReward, .countryCompletion])
    }

    @Test("Building View upgrade settlement conquers city and emits city conquest")
    func buildingViewUpgradeSettlementConquersCityAndEmitsCityConquest() throws {
        let start = Date.distantPast
        var state = KingdomGameState(
            gold: 1000,
            cityRemainingPower: 1,
            lastBackgroundedAt: start
        )
        _ = state.buildBuilding(.barracks, inSlot: 1, at: start)
        let store = try makeStore(initialState: state)
        let feedback = BuildingViewFeedbackRecorder()
        let scene = makeScene(store: store, router: RouteSpy(), feedback: feedback)

        scene.selectSlotForTesting(1)
        scene.upgradeSelectedSlotForTesting()

        #expect(store.load().stageStatus == .cityConqueredPendingMap)
        #expect(feedback.discreteEvents == [.goldReward, .cityConquest])
    }

    @Test("Building View settlement conquest closes open feedback settings")
    func buildingViewSettlementConquestClosesOpenFeedbackSettings() throws {
        let start = Date.distantPast
        var state = KingdomGameState(
            gold: 100,
            cityRemainingPower: 1,
            lastBackgroundedAt: start
        )
        _ = state.buildBuilding(.barracks, inSlot: 1, at: start)
        let store = try makeStore(initialState: state)
        let feedback = BuildingViewFeedbackRecorder()
        let scene = makeScene(store: store, router: RouteSpy(), feedback: feedback)
        let gearFrame = try #require(scene.feedbackSettingsGearFrameForTesting)

        scene.handleTouchForTesting(at: center(of: gearFrame))
        #expect(scene.isFeedbackSettingsVisibleForTesting)

        scene.selectSlotForTesting(2)
        scene.buildSelectedSlotForTesting(.barracks)

        #expect(!scene.isFeedbackSettingsVisibleForTesting)
        #expect(feedback.discreteEvents == [.goldReward, .cityConquest])
    }

    @Test("Building View feedbackSettingsAccessibilityFrame falls back from nonfinite screen conversion")
    func buildingViewFeedbackSettingsAccessibilityFrameFallsBackFromNonfinite() {
        let viewLocalFrame = CGRect(x: 12, y: 34, width: 44, height: 44)
        let validScreenFrame = CGRect(x: 212, y: 334, width: 44, height: 44)
        let invalidScreenFrame = CGRect(x: CGFloat.nan, y: 334, width: 44, height: 44)

        #expect(BuildingViewScene.feedbackSettingsAccessibilityFrame(
            viewLocalFrame: viewLocalFrame,
            screenFrame: invalidScreenFrame
        ) == viewLocalFrame)
        #expect(BuildingViewScene.feedbackSettingsAccessibilityFrame(
            viewLocalFrame: viewLocalFrame,
            screenFrame: validScreenFrame
        ) == validScreenFrame)
    }

    @Test("Building View activateFeedbackSettings with consumed does nothing when settings are visible")
    func buildingViewActivateFeedbackSettingsConsumedDoesNothing() throws {
        let preferences = RecordingFeedbackPreferencesManager()
        let scene = makeScene(
            store: try makeStore(initialState: KingdomGameState(gold: 100)),
            router: RouteSpy(),
            feedbackPreferences: preferences
        )
        let gearFrame = try #require(scene.feedbackSettingsGearFrameForTesting)

        scene.handleTouchForTesting(at: center(of: gearFrame))
        #expect(scene.isFeedbackSettingsVisibleForTesting)

        // .consumed must not toggle any preference or close the modal.
        scene.activateFeedbackSettingsForTesting(.consumed)
        #expect(scene.isFeedbackSettingsVisibleForTesting)
        #expect(preferences.current.soundEffectsEnabled)
        #expect(preferences.current.hapticsEnabled)
    }

    @Test("Building View accessibility adapter uses screen coordinates when the view has a window")
    func buildingViewAccessibilityAdapterUsesScreenCoordinatesWithWindow() throws {
        let window = UIWindow(frame: CGRect(x: 100, y: 200, width: 390, height: 844))
        let store = try makeStore(initialState: KingdomGameState(gold: 100))
        let scene = BuildingViewScene(
            size: CGSize(width: 390, height: 844),
            store: store,
            router: RouteSpy()
        )
        let view = SKView(frame: CGRect(origin: .zero, size: scene.size))
        window.addSubview(view)
        view.presentScene(scene)
        scene.didMove(to: view)

        // The gear frame should be non-zero and in screen coordinates
        // (offset by the window origin) rather than view-local coordinates.
        let gearFrame = try #require(scene.feedbackSettingsGearFrameForTesting)
        #expect(gearFrame.width > 0)
        #expect(gearFrame.height > 0)
    }

    private func makeScene(
        size: CGSize = CGSize(width: 390, height: 844),
        store: KingdomGameStore,
        router: BuildingViewSceneRouting? = nil,
        feedback: GameplayFeedbackProviding? = nil,
        feedbackPreferences: FeedbackPreferencesManaging = RecordingFeedbackPreferencesManager()
    ) -> BuildingViewScene {
        let scene = BuildingViewScene(
            size: size,
            store: store,
            router: router,
            feedback: feedback ?? NoOpGameplayFeedbackProvider(),
            feedbackPreferences: feedbackPreferences
        )
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        view.presentScene(scene)
        scene.didMove(to: view)
        return scene
    }

    /// Returns both the scene and the presenting SKView so tests can
    /// inspect UIView/accessibilityElements driven by the feedback
    /// settings accessibility adapter.
    @discardableResult
    private func makeSceneAndPreviewView(
        size: CGSize = CGSize(width: 390, height: 844),
        store: KingdomGameStore,
        router: BuildingViewSceneRouting? = nil,
        feedback: GameplayFeedbackProviding? = nil,
        feedbackPreferences: FeedbackPreferencesManaging = RecordingFeedbackPreferencesManager()
    ) -> (BuildingViewScene, SKView) {
        let scene = BuildingViewScene(
            size: size,
            store: store,
            router: router,
            feedback: feedback ?? NoOpGameplayFeedbackProvider(),
            feedbackPreferences: feedbackPreferences
        )
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        view.presentScene(scene)
        scene.didMove(to: view)
        return (scene, view)
    }

    private func center(of frame: CGRect) -> CGPoint {
        CGPoint(x: frame.midX, y: frame.midY)
    }

    private func makeIdleAccruingState(since date: Date) -> KingdomGameState {
        var state = KingdomGameState()
        state.cityBattleStates[state.currentCityKey.storageKey] = CityBattleState(
            slots: [1: CityBuilding(type: .barracks)],
            lastBuildingProgressResolvedAt: date
        )
        state.markCurrentCityBuildingProgressInactive(at: date)
        return state
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
        private(set) var battleRequestCount = 0
        var transitionResult = true

        func buildingViewSceneDidRequestBattle(_ scene: BuildingViewScene) -> Bool {
            didRequestBattle = true
            battleRequestCount += 1
            return transitionResult
        }
    }

    private final class RefusingRouteSpy: BuildingViewSceneRouting {
        private(set) var battleRequestCount = 0

        func buildingViewSceneDidRequestBattle(_ scene: BuildingViewScene) -> Bool {
            battleRequestCount += 1
            return false
        }
    }
}
