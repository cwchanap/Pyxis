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
    @Test("Camp preserves the countryside and all 25 scenic lots")
    func campPreservesScenicGrid() throws {
        let scene = makeScene(
            size: CGSize(width: 393, height: 852),
            store: try makeStore(initialState: KingdomGameState(gold: 100)),
            router: RouteSpy()
        )

        #expect(scene.backdropAssetNameForTesting == "building-view-countryside-backdrop")
        #expect(scene.buildingSlotCountForTesting == CityBattleState.slotRange.count)
        #expect(scene.slotNodeCountForTesting == CityBattleState.slotRange.count)
        #expect(scene.campChromeLayoutForTesting != nil)
        #expect(scene.campSelectionNodeForTesting.visualOptionCountForTesting == 5)
    }

    @Test("Camp uses one existing Settings gear without emitting gameplay feedback")
    func campUsesExistingSettingsDependencies() throws {
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
        #expect(feedback.events.isEmpty)
    }

    @Test("Camp keeps successful build and upgrade on the existing mutation/save path")
    func successfulMutationsSaveBeforeFeedback() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100))
        let feedback = BuildingViewFeedbackRecorder()
        var persistedAtFeedback: CityBuilding?
        feedback.onEvent = { event in
            guard event == .buildingChanged else { return }
            persistedAtFeedback = store.load().cityBattleStateForCurrentCity.building(inSlot: 2)
        }
        let scene = makeScene(store: store, router: RouteSpy(), feedback: feedback)

        scene.selectSlotForTesting(2)
        scene.buildSelectedSlotForTesting(.barracks)

        #expect(persistedAtFeedback?.type == .barracks)
        #expect(persistedAtFeedback?.level == 1)
        #expect(store.load().gold == 85)
        #expect(feedback.events == [.buildingChanged])

        feedback.reset()
        persistedAtFeedback = nil
        scene.upgradeSelectedSlotForTesting()

        #expect(persistedAtFeedback?.level == 2)
        #expect(store.load().gold == 73)
        #expect(feedback.events == [.buildingChanged])
    }

    @Test("Camp invalid builder actions consume input and use existing feedback")
    func invalidBuilderActionsUseFeedback() throws {
        let feedback = BuildingViewFeedbackRecorder()
        let state = KingdomGameState(
            gold: 1000,
            cityNumberInCountry: 5,
            completedCityCount: 4
        )
        let scene = makeScene(
            store: try makeStore(initialState: state),
            router: RouteSpy(),
            feedback: feedback
        )

        scene.selectSlotForTesting(1)
        scene.buildSelectedSlotForTesting(.mageTower)

        #expect(feedback.events == [.invalidAction])
        #expect(scene.feedbackTextForTesting.contains("unlocks"))
        #expect(scene.selectedSlotForTesting == 1)
    }

    @Test("Camp invalid inspector actions do not create a second economy path")
    func invalidUpgradeUsesFeedbackWithoutMutation() throws {
        var state = KingdomGameState(gold: 100)
        _ = state.buildBuilding(.barracks, inSlot: 1)
        state.gold = 0
        let store = try makeStore(initialState: state)
        let feedback = BuildingViewFeedbackRecorder()
        let scene = makeScene(store: store, router: RouteSpy(), feedback: feedback)

        scene.selectSlotForTesting(1)
        scene.upgradeSelectedSlotForTesting()

        #expect(store.load().gold == 0)
        #expect(store.load().cityBattleStateForCurrentCity.building(inSlot: 1)?.level == 1)
        #expect(feedback.events == [.invalidAction])
        #expect(scene.feedbackTextForTesting.contains("gold"))
    }

    @Test("Camp settlement retains pending conquest until the requested route")
    func settlementLeavesPendingResultInCamp() throws {
        let start = Date.distantPast
        var state = KingdomGameState(
            gold: 100,
            cityRemainingPower: 1,
            lastBackgroundedAt: start,
            cityNumberInCountry: 5,
            completedCityCount: 4
        )
        _ = state.buildBuilding(.barracks, inSlot: 1, at: start)
        let store = try makeStore(initialState: state)
        let feedback = BuildingViewFeedbackRecorder()
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router, feedback: feedback)

        scene.selectSlotForTesting(2)
        scene.buildSelectedSlotForTesting(.archeryRange)

        #expect(store.load().pendingBattleResult != nil)
        #expect(scene.selectedSlotForTesting == 2)
        #expect(router.requestedTabs.isEmpty)

        scene.requestGameplayTabForTesting(.map)
        #expect(router.requestedTabs == [.map])
    }

    @Test("Camp exits settle and save before forwarding a gameplay tab")
    func campExitSettlesBeforeRoute() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        scene.requestGameplayTabForTesting(.battle)

        #expect(router.requestedTabs == [.battle])
        #expect(scene.isRoutingToBattleForTesting)
        #expect(store.load().stageStatus == .battleActive)
    }

    @Test("Camp lifecycle remains idempotent across repeated scene moves")
    func campLifecycleObserversDoNotDuplicate() throws {
        let scene = makeScene(
            store: try makeStore(initialState: KingdomGameState(gold: 100)),
            router: RouteSpy()
        )
        let initialLayoutCalls = scene.layoutInterfaceCallCountForTesting

        scene.refreshLayoutForCurrentEnvironment()
        #expect(scene.layoutInterfaceCallCountForTesting > initialLayoutCalls)

        let afterRepeat = scene.layoutInterfaceCallCountForTesting
        let now = Date(timeIntervalSinceReferenceDate: 100)
        scene.sceneDidEnterBackgroundForTesting(at: now)
        scene.sceneWillEnterForegroundForTesting(at: now.addingTimeInterval(1))
        scene.sceneWillEnterForegroundForTesting(at: now.addingTimeInterval(2))

        #expect(scene.layoutInterfaceCallCountForTesting > afterRepeat)
        #expect(scene.lastIdleProgressResultForTesting.elapsedSeconds >= 0)
    }

    @Test("Camp accessibility frame falls back from invalid screen conversion")
    func accessibilityFrameFallback() {
        let local = CGRect(x: 12, y: 34, width: 44, height: 44)
        let valid = CGRect(x: 212, y: 334, width: 44, height: 44)
        let invalid = CGRect(x: CGFloat.nan, y: 334, width: 44, height: 44)

        #expect(BuildingViewScene.feedbackSettingsAccessibilityFrame(
            viewLocalFrame: local,
            screenFrame: invalid
        ) == local)
        #expect(BuildingViewScene.feedbackSettingsAccessibilityFrame(
            viewLocalFrame: local,
            screenFrame: valid
        ) == valid)
    }

    private func makeScene(
        size: CGSize = CGSize(width: 390, height: 844),
        store: KingdomGameStore,
        router: BuildingViewSceneRouting? = nil,
        feedback: GameplayFeedbackProviding? = nil,
        feedbackPreferences: FeedbackPreferencesManaging = MainActor.assumeIsolated {
            RecordingFeedbackPreferencesManager()
        }
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

    private func center(of frame: CGRect) -> CGPoint {
        CGPoint(x: frame.midX, y: frame.midY)
    }

    private func makeStore(initialState: KingdomGameState) throws -> KingdomGameStore {
        let suiteName = "PyxisTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let store = KingdomGameStore(defaults: defaults, key: "state")
        store.save(initialState)
        return store
    }

    private final class BuildingViewFeedbackRecorder: GameplayFeedbackProviding {
        private(set) var events: [GameplayFeedbackEvent] = []
        var onEvent: ((GameplayFeedbackEvent) -> Void)?

        func emit(_ event: GameplayFeedbackEvent) {
            onEvent?(event)
            events.append(event)
        }

        func emitAutomaticCombat(_ result: BattleCombatState.TickResult) {}

        func reset() {
            events.removeAll()
        }
    }

    private final class RouteSpy: BuildingViewSceneRouting {
        private(set) var requestedTabs: [GameplayTab] = []

        func buildingViewSceneDidRequestGameplayTab(
            _ scene: BuildingViewScene,
            tab: GameplayTab
        ) -> Bool {
            requestedTabs.append(tab)
            return true
        }
    }
}
