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

    @Test("Camp feedback stays readable between the selection panel and tabs")
    func campFeedbackFrameAvoidsSelectionAndTabs() throws {
        let scene = makeScene(
            size: CGSize(width: 393, height: 852),
            store: try makeStore(initialState: KingdomGameState(gold: 100)),
            router: RouteSpy()
        )

        scene.selectSlotForTesting(1)

        let frames = try #require(scene.campLayoutFramesForTesting)
        let selectionFrame = try #require(frames.selection)
        let feedbackFrame = try #require(frames.feedback)
        let renderedFrame = try #require(scene.feedbackLabelFrameForTesting)

        #expect(!feedbackFrame.intersects(selectionFrame))
        #expect(!feedbackFrame.intersects(frames.tabs))
        #expect(frames.lots.contains(feedbackFrame))
        #expect(!renderedFrame.intersects(selectionFrame))
        #expect(!renderedFrame.intersects(frames.tabs))
        #expect(renderedFrame.width > 0)
        #expect(scene.feedbackTextForTesting.contains("selected"))
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

    @Test("Camp successful build and upgrade each save exactly once")
    func successfulMutationsSaveExactlyOnce() throws {
        let suiteName = "PyxisTests.\(UUID().uuidString)"
        let defaults = try #require(
            CountingUserDefaults(suiteName: suiteName, countedKey: "state")
        )
        defaults.removePersistentDomain(forName: suiteName)
        let store = KingdomGameStore(defaults: defaults, key: "state")
        store.save(KingdomGameState(gold: 100))
        defaults.resetStateSaveCount()
        let scene = makeScene(store: store, router: RouteSpy())

        scene.selectSlotForTesting(2)
        scene.buildSelectedSlotForTesting(.barracks)
        #expect(defaults.stateSaveCount == 1)

        defaults.resetStateSaveCount()
        scene.upgradeSelectedSlotForTesting()
        #expect(defaults.stateSaveCount == 1)
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
        #expect(feedback.events == [.goldReward, .cityConquest])
        // HPA-478: deliberate build conquest stays on Camp with exactly this
        // pointer; the report itself waits in the pending result.
        #expect(scene.feedbackTextForTesting == "City conquered. Open Battle for the report.")
        #expect(scene.selectedSlotForTesting == 2)
        #expect(router.requestedTabs.isEmpty)

        scene.requestGameplayTabForTesting(.map)
        #expect(router.requestedTabs == [.map])
    }

    @Test("Camp upgrade conquest stays on camp with a pointer to the pending report")
    func upgradeSettlementConquestStaysOnCampWithPointer() throws {
        let start = Date.distantPast
        var state = KingdomGameState(
            gold: 1_000,
            cityRemainingPower: 1,
            lastBackgroundedAt: start,
            cityNumberInCountry: 5,
            completedCityCount: 4
        )
        _ = state.buildBuilding(.barracks, inSlot: 1, at: start)
        _ = state.buildBuilding(.archeryRange, inSlot: 2, at: start)
        let store = try makeStore(initialState: state)
        let feedback = BuildingViewFeedbackRecorder()
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router, feedback: feedback)

        scene.selectSlotForTesting(2)
        scene.upgradeSelectedSlotForTesting()

        #expect(store.load().pendingBattleResult != nil)
        #expect(store.load().stageStatus == .cityConqueredPendingMap)
        #expect(feedback.events == [.goldReward, .cityConquest])
        #expect(scene.feedbackTextForTesting == "City conquered. Open Battle for the report.")
        #expect(router.requestedTabs.isEmpty)

        scene.requestGameplayTabForTesting(.battle)
        #expect(router.requestedTabs == [.battle])
    }

    @Test("Camp layout gate conquest stays unrouted while paused and routes once on resume")
    func campLayoutGateConquestRoutesOnceOnResume() throws {
        let start = Date.distantPast
        var state = KingdomGameState(
            gold: 100,
            cityRemainingPower: 1,
            lastBackgroundedAt: start
        )
        _ = state.buildBuilding(.barracks, inSlot: 1, at: start)
        let store = try makeStore(initialState: state)
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        scene.layoutGateWillPause(at: start.addingTimeInterval(10_000))

        let saved = store.load()
        #expect(saved.stageStatus == .cityConqueredPendingMap)
        #expect(saved.pendingBattleResult?.conquestMode == .idle)
        // The gate pause itself never routes; the pending result waits.
        #expect(router.requestedTabs.isEmpty)

        scene.layoutGateWillResume(at: start.addingTimeInterval(10_100))

        #expect(store.load() == saved)
        #expect(router.requestedTabs == [.battle])
        #expect(scene.isRoutingToBattleForTesting)
    }

    @Test("Camp pending conquest foregrounded under a paused gate routes once on resume")
    func campPendingConquestForegroundedUnderPausedGateRoutesOnResume() throws {
        let start = Date.distantPast
        var state = KingdomGameState(
            gold: 100,
            cityRemainingPower: 1,
            lastBackgroundedAt: start
        )
        _ = state.buildBuilding(.barracks, inSlot: 1, at: start)
        let store = try makeStore(initialState: state)
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        scene.layoutGateWillPause(at: start.addingTimeInterval(10_000))
        scene.sceneDidEnterBackgroundForTesting(at: start.addingTimeInterval(10_050))

        // Foreground while the gate is still paused must not route.
        scene.sceneWillEnterForegroundForTesting(at: start.addingTimeInterval(10_100))
        #expect(router.requestedTabs.isEmpty)

        scene.layoutGateWillResume(at: start.addingTimeInterval(10_150))

        #expect(router.requestedTabs == [.battle])
        #expect(scene.isRoutingToBattleForTesting)
    }

    @Test("Camp pending conquest gate-resumed while backgrounded routes once on foreground")
    func campPendingConquestResumedWhileBackgroundedRoutesOnForeground() throws {
        let start = Date.distantPast
        var state = KingdomGameState(
            gold: 100,
            cityRemainingPower: 1,
            lastBackgroundedAt: start
        )
        _ = state.buildBuilding(.barracks, inSlot: 1, at: start)
        let store = try makeStore(initialState: state)
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        scene.layoutGateWillPause(at: start.addingTimeInterval(10_000))
        scene.sceneDidEnterBackgroundForTesting(at: start.addingTimeInterval(10_050))

        // Gate resume while still system-backgrounded must not route.
        scene.layoutGateWillResume(at: start.addingTimeInterval(10_100))
        #expect(router.requestedTabs.isEmpty)

        scene.sceneWillEnterForegroundForTesting(at: start.addingTimeInterval(10_150))

        #expect(router.requestedTabs == [.battle])
        #expect(scene.isRoutingToBattleForTesting)
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

    @Test("Camp route latch clears when the router is absent or refuses")
    func campRouteLatchClearsWhenRouterDoesNotAccept() throws {
        let nilRouterScene = makeScene(
            store: try makeStore(initialState: KingdomGameState(gold: 100)),
            router: nil
        )
        nilRouterScene.requestGameplayTabForTesting(.battle)
        #expect(!nilRouterScene.isRoutingToBattleForTesting)

        let refusingRouter = RefusingRouteSpy()
        let refusingScene = makeScene(
            store: try makeStore(initialState: KingdomGameState(gold: 100)),
            router: refusingRouter
        )
        refusingScene.requestGameplayTabForTesting(.battle)
        #expect(refusingRouter.requestedTabs == [.battle])
        #expect(!refusingScene.isRoutingToBattleForTesting)
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

    @Test("Camp remount registers one lifecycle observer")
    func campRemountDoesNotDuplicateLifecycleNotificationHandling() throws {
        let scene = makeScene(
            store: try makeStore(initialState: KingdomGameState(gold: 100)),
            router: RouteSpy()
        )
        scene.repeatDidMoveForTesting()
        let beforeNotification = scene.layoutInterfaceCallCountForTesting

        NotificationCenter.default.post(
            name: .pyxisSceneWillEnterForeground,
            object: nil
        )

        #expect(scene.layoutInterfaceCallCountForTesting == beforeNotification + 1)
    }

    @Test("Camp layout gate accounts idle time and rearms only in active battle")
    func campLayoutGateAccountsIdleTimeAndRearmsOnlyWhenBattleActive() throws {
        let origin = Date(timeIntervalSinceReferenceDate: 3_000)
        let activeStore = try makeStore(initialState: makeIdleAccruingState(since: origin))
        let activeScene = makeScene(store: activeStore, router: RouteSpy())

        activeScene.layoutGateWillPause(at: origin.addingTimeInterval(10))
        #expect(activeScene.lastIdleProgressResultForTesting.elapsedSeconds == 10)
        activeScene.layoutGateWillPause(at: origin.addingTimeInterval(20))
        #expect(activeScene.lastIdleProgressResultForTesting.elapsedSeconds == 10)

        activeScene.layoutGateWillResume(at: origin.addingTimeInterval(30))
        #expect(activeStore.load().lastBackgroundedAt == origin.addingTimeInterval(30))

        var pendingState = makeIdleAccruingState(since: origin)
        pendingState.stageStatus = .cityConqueredPendingMap
        let pendingStore = try makeStore(initialState: pendingState)
        let pendingScene = makeScene(store: pendingStore, router: RouteSpy())
        pendingScene.layoutGateWillPause(at: origin.addingTimeInterval(10))
        pendingScene.layoutGateWillResume(at: origin.addingTimeInterval(30))

        #expect(pendingStore.load().lastBackgroundedAt == nil)
    }

    @Test("Camp conquest feedback is fresh once across redraw and remount")
    func campConquestFeedbackDoesNotRepeatAfterRedrawOrRemount() throws {
        let start = Date.distantPast
        var state = KingdomGameState(
            gold: 100,
            cityRemainingPower: 1,
            lastBackgroundedAt: start
        )
        _ = state.buildBuilding(.barracks, inSlot: 1, at: start)
        let feedback = BuildingViewFeedbackRecorder()
        let router = RouteSpy()
        let scene = makeScene(
            store: try makeStore(initialState: state),
            router: router,
            feedback: feedback
        )

        scene.sceneWillEnterForegroundForTesting(at: start.addingTimeInterval(10_000))
        #expect(feedback.events == [.goldReward, .cityConquest])
        // HPA-478: idle foreground conquest routes to the pending report.
        #expect(router.requestedTabs == [.battle])

        scene.redrawForTesting()
        scene.repeatDidMoveForTesting()
        scene.sceneWillEnterForegroundForTesting(at: start.addingTimeInterval(20_000))

        #expect(feedback.events == [.goldReward, .cityConquest])
        #expect(router.requestedTabs == [.battle])
    }

    @Test("Camp foreground idle damage summary uses compact copy")
    func campForegroundPositiveIdleDamageUsesCompactSummary() throws {
        // City 15 has ~23K power, so five barracks resolving the 8-hour idle
        // cap deal 1,440 damage — compact-formatted, positive, non-conquest.
        let origin = Date(timeIntervalSince1970: 1_000)
        var state = KingdomGameState(
            gold: 100,
            cityLevel: 15,
            lastBackgroundedAt: origin,
            cityNumberInCountry: 15,
            completedCityCount: 14
        )
        for slot in 1...5 {
            _ = state.buildBuilding(.barracks, inSlot: slot, at: origin)
        }
        let store = try makeStore(initialState: state)
        let scene = makeScene(store: store, router: RouteSpy())

        let catchUpSeconds = KingdomGameState.maxIdleCatchUpSeconds
        scene.sceneDidEnterBackgroundForTesting(at: origin)
        scene.sceneWillEnterForegroundForTesting(
            at: origin.addingTimeInterval(TimeInterval(catchUpSeconds))
        )

        #expect(scene.lastIdleProgressResultForTesting == .init(
            elapsedSeconds: catchUpSeconds,
            damageDealt: 1_440,
            conqueredCities: 0,
            goldEarned: 0
        ))
        #expect(scene.feedbackTextForTesting == "Buildings dealt 1.4K idle damage.")
    }

    @Test("Camp foreground zero-damage idle return resets to the hidden default")
    func campForegroundZeroDamageIdleReturnResetsDefaultFeedback() throws {
        // Camp arms idle tracking via `markCurrentCityBuildingProgressInactive`
        // only when its layout gate is paused, so seed the credited return by
        // backgrounding the state before mounting the scene (mirrors the
        // existing camp conquest foreground test).
        let origin = Date(timeIntervalSince1970: 1_000)
        let store = try makeStore(initialState: KingdomGameState(
            gold: 100,
            lastBackgroundedAt: origin
        ))
        let scene = makeScene(store: store, router: RouteSpy())

        scene.selectSlotForTesting(1)
        #expect(scene.feedbackTextForTesting == "Empty lot 1 selected.")

        // A real credited return with no buildings resolves zero damage and
        // must fall back to the hidden default instead of a no-damage copy.
        scene.sceneDidEnterBackgroundForTesting(at: origin)
        scene.sceneWillEnterForegroundForTesting(at: origin.addingTimeInterval(300))

        #expect(scene.lastIdleProgressResultForTesting.elapsedSeconds == 300)
        #expect(scene.lastIdleProgressResultForTesting.damageDealt == 0)
        #expect(scene.feedbackTextForTesting == "Select a city lot.")
        #expect(scene.isFeedbackLabelHiddenForTesting)
    }

    @Test("Camp Settings modal shields builder, lot, and tab touches")
    func campSettingsModalShieldsUnderlyingCampControls() throws {
        let initialState = KingdomGameState(gold: 100)
        let feedback = BuildingViewFeedbackRecorder()
        let router = RouteSpy()
        let store = try makeStore(initialState: initialState)
        let scene = makeScene(
            store: store,
            router: router,
            feedback: feedback
        )
        scene.selectSlotForTesting(1)
        let selection = try #require(scene.campLayoutFramesForTesting)
        let builderFrame = try #require(selection.builderOptions[.barracks])
        let lotPoint = try #require(scene.slotHitAreaCenterPointForTesting(2))
        let gearFrame = try #require(scene.feedbackSettingsGearFrameForTesting)

        scene.handleTouchForTesting(at: center(of: gearFrame))
        #expect(scene.isFeedbackSettingsVisibleForTesting)

        scene.handleTouchForTesting(at: center(of: builderFrame))
        scene.handleTouchForTesting(at: lotPoint)
        // The bottom sheet covers the tab centers; use the exposed edge of the
        // hit frame to verify the modal still consumes tab touches.
        let tabPoint = CGPoint(x: selection.tabs.midX, y: selection.tabs.minY + 4)
        scene.handleTouchForTesting(at: tabPoint)

        #expect(scene.isFeedbackSettingsVisibleForTesting)
        #expect(scene.selectedSlotForTesting == 1)
        #expect(store.load() == initialState)
        #expect(router.requestedTabs.isEmpty)
        #expect(feedback.events.isEmpty)
    }

    @Test("Camp Settings accessibility guard blocks opening during layout pause")
    func campSettingsAccessibilityGuardBlocksOpeningDuringLayoutPause() throws {
        let scene = makeScene(
            store: try makeStore(initialState: KingdomGameState(gold: 100)),
            router: RouteSpy()
        )
        let gearFrame = try #require(scene.feedbackSettingsGearFrameForTesting)
        scene.layoutGateWillPause(at: Date(timeIntervalSinceReferenceDate: 10))
        scene.handleTouchForTesting(at: center(of: gearFrame))

        #expect(!scene.isFeedbackSettingsVisibleForTesting)
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

    private final class CountingUserDefaults: UserDefaults {
        private let countedKey: String
        private(set) var stateSaveCount = 0

        init?(suiteName: String, countedKey: String) {
            self.countedKey = countedKey
            super.init(suiteName: suiteName)
        }

        override func set(_ value: Any?, forKey defaultName: String) {
            if defaultName == countedKey {
                stateSaveCount += 1
            }
            super.set(value, forKey: defaultName)
        }

        func resetStateSaveCount() {
            stateSaveCount = 0
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

    private final class RefusingRouteSpy: BuildingViewSceneRouting {
        private(set) var requestedTabs: [GameplayTab] = []

        func buildingViewSceneDidRequestGameplayTab(
            _ scene: BuildingViewScene,
            tab: GameplayTab
        ) -> Bool {
            requestedTabs.append(tab)
            return false
        }
    }
}
