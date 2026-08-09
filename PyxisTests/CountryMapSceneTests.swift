//
//  CountryMapSceneTests.swift
//  PyxisTests
//

import Foundation
import SpriteKit
import Testing
import UIKit
@testable import Pyxis

@MainActor
struct CountryMapSceneTests {
    private enum CountryMapFeedbackCall: Equatable {
        case discrete(GameplayFeedbackEvent)
    }

    private final class CountryMapFeedbackRecorder: GameplayFeedbackProviding {
        private(set) var calls: [CountryMapFeedbackCall] = []
        private(set) var automaticCallCount = 0

        func emit(_ event: GameplayFeedbackEvent) {
            calls.append(.discrete(event))
        }

        func emitAutomaticCombat(_ result: BattleCombatState.TickResult) {
            automaticCallCount += 1
        }

        var discreteEvents: [GameplayFeedbackEvent] {
            calls.compactMap {
                guard case .discrete(let event) = $0 else { return nil }
                return event
            }
        }

        func reset() {
            calls.removeAll()
            automaticCallCount = 0
        }
    }

    @Test("Country Map uses injected feedback and Settings dependencies")
    func countryMapUsesInjectedFeedbackAndSettingsDependencies() throws {
        let feedback = CountryMapFeedbackRecorder()
        let preferences = RecordingFeedbackPreferencesManager()
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let scene = makeScene(
            store: store,
            router: RouteSpy(),
            feedback: feedback,
            feedbackPreferences: preferences
        )
        let gearFrame = try #require(scene.feedbackSettingsGearFrameForTesting)
        let settingsLayout = try #require(FeedbackSettingsLayout.compute(
            sceneSize: scene.size,
            safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0)
        ))

        scene.handleTouchForTesting(at: gearFrame.center)
        #expect(scene.isFeedbackSettingsVisibleForTesting)
        scene.handleTouchForTesting(at: settingsLayout.soundRowFrame.center)
        #expect(preferences.current.soundEffectsEnabled == false)
        scene.handleTouchForTesting(at: settingsLayout.closeFrame.center)

        scene.enterCityForTesting(3)

        #expect(feedback.discreteEvents == [.invalidAction])
    }

    @Test("Country Map Settings consumes every underlying map target")
    func countryMapSettingsBlocksScoutCurrentCityCityAndGearTouches() throws {
        let feedback = CountryMapFeedbackRecorder()
        let initialState = KingdomGameState(
            cityLevel: 3,
            cityRemainingPower: 50,
            cityNumberInCountry: 3,
            completedCityCount: 2,
            stageStatus: .battleActive
        )
        let store = try makeStore(initialState: initialState)
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router, feedback: feedback)
        let gearFrame = try #require(scene.feedbackSettingsGearFrameForTesting)
        let scoutAttackFrame = try #require(scene.scoutCardAttackHitFrameForTesting)
        let scoutCardFrame = try #require(scene.scoutCardHitFrameForTesting)
        let currentCityFrame = scene.currentCityButtonFrameForTesting
        let cityPoint = try #require(scene.cityNodePositionForTesting(4))

        scene.handleTouchForTesting(at: gearFrame.center)
        #expect(scene.isFeedbackSettingsVisibleForTesting)

        for point in [
            gearFrame.center,
            scoutAttackFrame.center,
            CGPoint(x: scoutCardFrame.minX + 2, y: scoutCardFrame.maxY - 2),
            currentCityFrame.center,
            cityPoint
        ] {
            scene.handleTouchForTesting(at: point)
        }

        #expect(store.load() == initialState)
        #expect(router.battleRequestCount == 0)
        #expect(feedback.calls.isEmpty)
        #expect(scene.isFeedbackSettingsVisibleForTesting)
    }

    @Test("Country Map Settings gear wins over an overlapping scout attack")
    func countryMapGearPrecedesScoutAttack() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        let attackFrame = try #require(scene.scoutCardAttackHitFrameForTesting)
        let gear = try #require(
            scene.childNode(withName: SettingsGearNode.semanticName) as? SettingsGearNode
        )
        gear.position = attackFrame.center

        scene.handleTouchForTesting(at: attackFrame.center)

        #expect(scene.isFeedbackSettingsVisibleForTesting)
        #expect(router.battleRequestCount == 0)
        #expect(store.load().stageStatus == .cityConqueredPendingMap)
    }

    @Test("Country Map routing guard wins over Settings gear")
    func countryMapRoutingGuardPreventsOpeningSettings() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        let scoutAttack = try #require(scene.scoutCardAttackHitFrameForTesting)
        let gear = try #require(scene.feedbackSettingsGearFrameForTesting)

        scene.handleTouchForTesting(at: scoutAttack.center)
        scene.handleTouchForTesting(at: gear.center)

        #expect(scene.isRoutingToBattleForTesting)
        #expect(!scene.isFeedbackSettingsVisibleForTesting)
        #expect(router.battleRequestCount == 1)
    }

    @Test("Country Map layout gate refuses a retained Settings accessibility activation")
    func countryMapLayoutGateRefusesRetainedAccessibilityGearActivation() throws {
        let initialState = KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        )
        let countingStore = try makeCountingStore(initialState: initialState)
        let store = countingStore.store
        let router = RouteSpy()
        let feedback = CountryMapFeedbackRecorder()
        let preferences = RecordingFeedbackPreferencesManager()
        let size = CGSize(width: 393, height: 852)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        let accessibilityAdapter = FeedbackSettingsAccessibilityAdapter(
            containerView: view,
            sceneToScreenFrame: { $0 },
            postNotification: { _, _ in }
        )
        let scene = CountryMapScene(
            size: size,
            store: store,
            router: router,
            layoutEnvironmentOverride: .init(
                safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0),
                layoutClass: .phone
            ),
            feedback: feedback,
            feedbackPreferences: preferences,
            feedbackSettingsAccessibilityAdapter: accessibilityAdapter
        )
        scene.didMove(to: view)
        let elements = (view.accessibilityElements as? [UIAccessibilityElement]) ?? []
        let gear = try #require(elements.onlyElement as? ActionAccessibilityElement)

        scene.layoutGateWillPause(at: .init(timeIntervalSinceReferenceDate: 1_000))
        let stateAfterGatePause = store.load()
        countingStore.defaults.resetStateSaveCount()

        #expect(gear.accessibilityActivate())

        #expect(!scene.isFeedbackSettingsVisibleForTesting)
        #expect(feedback.calls.isEmpty)
        #expect(router.battleRequestCount == 0)
        #expect(store.load() == stateAfterGatePause)
        #expect(countingStore.defaults.stateSaveCount == 0)
    }

    @Test("Country Map title uses the layout title frame and fails at the 16-point floor")
    func countryMapTitleUsesLayoutFrameAndNeverShrinksToEightPoints() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityLevel: 3,
            cityRemainingPower: 50,
            cityNumberInCountry: 3,
            completedCityCount: 2,
            stageStatus: .battleActive
        ))
        let scene = makeScene(
            size: CGSize(width: 375, height: 667),
            store: store,
            router: RouteSpy(),
            environment: .init(safeAreaInsets: .zero, layoutClass: .phone)
        )
        let layout = try #require(scene.countryMapLayoutForTesting)
        let titleFrame = scene.titleLabelFrameForTesting
        let label = SKLabelNode(fontNamed: GameUITheme.Font.bold)
        label.text = "A title too long for this narrow test region"
        label.fontSize = 28

        #expect(layout.titleTextFrame.contains(titleFrame))
        #expect(scene.titleLabelFontSizeForTesting >= 16)
        #expect(!scene.fitTitleLabelForTesting(label, maxWidth: 160))
        #expect(label.fontSize == 16)
    }

    @Test("Fresh Country Map idle conquest stays on map and emits reward before one city outcome")
    func countryMapFreshIdleConquestEmitsRewardThenCityOutcomeWithoutReplay() throws {
        let start = Date.distantPast
        var initialState = KingdomGameState(
            gold: 100,
            cityRemainingPower: 1,
            lastBackgroundedAt: start,
            cityNumberInCountry: 3,
            completedCityCount: 2,
            stageStatus: .battleActive
        )
        _ = initialState.buildBuilding(.barracks, inSlot: 1, at: start)
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
        let router = RouteSpy()
        let scene = makeScene(
            store: store,
            router: router,
            feedback: feedback,
            feedbackPreferences: preferences
        )

        scene.sceneWillEnterForegroundForTesting(at: start.addingTimeInterval(10_000))

        #expect(store.load().stageStatus == .cityConqueredPendingMap)
        #expect(router.battleRequestCount == 0)
        #expect(scene.visibleFeedbackTextForTesting == "Next: Bramblegate")
        #expect(sound.calls == [
            .play(.goldReward),
            .play(.cityConquest)
        ])
        #expect(haptics.played == [.strongSuccess])

        let preservedText = scene.visibleFeedbackTextForTesting
        scene.didMove(to: SKView(frame: CGRect(origin: .zero, size: scene.size)))
        scene.refreshLayoutForCurrentEnvironment()

        #expect(scene.visibleFeedbackTextForTesting == preservedText)
        #expect(sound.calls == [
            .play(.goldReward),
            .play(.cityConquest)
        ])
        #expect(haptics.played == [.strongSuccess])
    }

    @Test("Final Country Map idle conquest emits country completion instead of city conquest")
    func countryMapFinalIdleConquestEmitsExactlyOneCountryOutcome() throws {
        let start = Date.distantPast
        var initialState = KingdomGameState(
            gold: 100,
            cityLevel: 15,
            cityRemainingPower: 1,
            lastBackgroundedAt: start,
            cityNumberInCountry: 15,
            completedCityCount: 14,
            stageStatus: .battleActive
        )
        _ = initialState.buildBuilding(.barracks, inSlot: 1, at: start)
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
        let router = RouteSpy()
        let scene = makeScene(
            store: store,
            router: router,
            feedback: feedback,
            feedbackPreferences: preferences
        )

        scene.sceneWillEnterForegroundForTesting(at: start.addingTimeInterval(10_000))

        #expect(store.load().stageStatus == .countryComplete)
        #expect(router.battleRequestCount == 0)
        #expect(scene.visibleFeedbackTextForTesting == "Country 1 conquered at Crownspire Keep.")
        #expect(sound.calls == [
            .play(.goldReward),
            .play(.countryCompletion)
        ])
        #expect(haptics.played == [.strongSuccess])
    }

    @Test func enteringUnlockedCitySavesStateAndRoutesToBattle() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        scene.enterCityForTesting(2)

        let saved = store.load()
        #expect(saved.stageStatus == .battleActive)
        #expect(saved.cityNumberInCountry == 2)
        #expect(saved.cityLevel == 2)
        #expect(saved.cityRemainingPower == KingdomGameState.cityMaxPower(for: 2))
        #expect(router.battleRequestCount == 1)
    }

    @Test func enteringLockedCityDoesNotMutateOrRoute() throws {
        let initialState = KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        )
        let store = try makeStore(initialState: initialState)
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        scene.enterCityForTesting(3)

        #expect(store.load() == initialState)
        #expect(router.battleRequestCount == 0)
        #expect(scene.visibleFeedbackTextForTesting == "Falconridge is locked")
    }

    @Test func completedCountryCityNodeShowsExactFeedbackWithoutMutationOrRoute() throws {
        let initialState = KingdomGameState(
            cityLevel: 15,
            cityRemainingPower: 0,
            cityNumberInCountry: 15,
            completedCityCount: 15,
            stageStatus: .countryComplete
        )
        let store = try makeStore(initialState: initialState)
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        let baseContent = scene.scoutCardBaseContentForTesting
        let cityPoint = try #require(scene.cityNodePositionForTesting(15))

        scene.touchesEnded([MockTouch(location: cityPoint)], with: nil)

        #expect(store.load() == initialState)
        #expect(router.battleRequestCount == 0)
        #expect(scene.visibleFeedbackTextForTesting == "Crownspire Keep complete")
        #expect(scene.feedbackElapsedForTesting == 0)
        #expect(scene.feedbackRemainingDurationForTesting == 1.5)
        #expect(scene.projectedScoutCardContentForTesting
            == .countryComplete(countryNumber: 1, finalCityName: "Crownspire Keep"))
        #expect(scene.scoutCardBaseContentForTesting == baseContent)

        scene.advanceFeedbackForTesting(by: 1.49)
        #expect(scene.visibleFeedbackTextForTesting == "Crownspire Keep complete")
        #expect(abs((scene.feedbackRemainingDurationForTesting ?? 0) - 0.01) < 0.001)

        scene.advanceFeedbackForTesting(by: 0.01)
        #expect(scene.visibleFeedbackTextForTesting == nil)
        #expect(scene.feedbackRemainingDurationForTesting == nil)
        #expect(scene.projectedScoutCardContentForTesting
            == .countryComplete(countryNumber: 1, finalCityName: "Crownspire Keep"))
        #expect(scene.scoutCardBaseContentForTesting == baseContent)
    }

    @Test func completedCountryStartsWithConqueredCardContent() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityLevel: 15,
            cityRemainingPower: 0,
            cityNumberInCountry: 15,
            completedCityCount: 15,
            stageStatus: .countryComplete
        ))
        let scene = makeScene(store: store, router: RouteSpy())

        #expect(scene.visibleFeedbackTextForTesting == nil)
        #expect(scene.projectedScoutCardContentForTesting
            == .countryComplete(countryNumber: 1, finalCityName: "Crownspire Keep"))
    }

    @Test func cityButtonReturnsToActiveBattleWithoutMutatingStore() throws {
        let initialState = KingdomGameState(
            cityLevel: 3,
            cityRemainingPower: 24,
            cityNumberInCountry: 3,
            completedCityCount: 2,
            stageStatus: .battleActive
        )
        let store = try makeStore(initialState: initialState)
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        scene.requestCurrentCityBattleForTesting()

        #expect(store.load() == initialState)
        #expect(router.battleRequestCount == 1)
    }

    @Test func requestCurrentCityBattleResolvesIdleProgress() throws {
        let start = Date.distantPast
        var initialState = KingdomGameState(
            gold: 100,
            cityRemainingPower: 1000,
            lastBackgroundedAt: start,
            cityNumberInCountry: 3,
            completedCityCount: 2,
            stageStatus: .battleActive
        )
        _ = initialState.buildBuilding(.barracks, inSlot: 1, at: start)
        let store = try makeStore(initialState: initialState)
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        scene.requestCurrentCityBattleForTesting()

        let saved = store.load()
        #expect(saved.lastBackgroundedAt == nil)
        #expect(router.battleRequestCount == 1)
        #expect(saved.cityRemainingPower < 1000)
    }

    @Test func requestCurrentCityBattleStaysOnMapWhenIdleProgressConquersCity() throws {
        let start = Date.distantPast
        var initialState = KingdomGameState(
            gold: 100,
            cityRemainingPower: 1,
            lastBackgroundedAt: start,
            cityNumberInCountry: 3,
            completedCityCount: 2,
            stageStatus: .battleActive
        )
        _ = initialState.buildBuilding(.barracks, inSlot: 1, at: start)
        let store = try makeStore(initialState: initialState)
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        scene.requestCurrentCityBattleForTesting()

        let saved = store.load()
        #expect(saved.stageStatus == .cityConqueredPendingMap)
        #expect(router.battleRequestCount == 0)
    }

    @Test func enteringCurrentCityResolvesIdleProgress() throws {
        let start = Date.distantPast
        var initialState = KingdomGameState(
            gold: 100,
            cityRemainingPower: 1000,
            lastBackgroundedAt: start,
            cityNumberInCountry: 3,
            completedCityCount: 2,
            stageStatus: .battleActive
        )
        _ = initialState.buildBuilding(.barracks, inSlot: 1, at: start)
        let store = try makeStore(initialState: initialState)
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        scene.enterCityForTesting(3)

        let saved = store.load()
        #expect(saved.lastBackgroundedAt == nil)
        #expect(router.battleRequestCount == 1)
        #expect(saved.cityRemainingPower < 1000)
    }

    @Test func enteringCityStaysOnMapWhenIdleProgressConquersCity() throws {
        let start = Date.distantPast
        var battleState = KingdomGameState(
            gold: 100,
            cityRemainingPower: 1,
            lastBackgroundedAt: start,
            cityNumberInCountry: 3,
            completedCityCount: 2,
            stageStatus: .battleActive
        )
        _ = battleState.buildBuilding(.barracks, inSlot: 1, at: start)
        let store = try makeStore(initialState: battleState)

        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        scene.enterCityForTesting(3)

        let saved = store.load()
        #expect(saved.stageStatus == .cityConqueredPendingMap)
        #expect(router.battleRequestCount == 0)
    }

    @Test func cityButtonHidesAfterIdleConquestViaRequestCurrentCityBattle() throws {
        let start = Date.distantPast
        var initialState = KingdomGameState(
            gold: 100,
            cityRemainingPower: 1,
            lastBackgroundedAt: start,
            cityNumberInCountry: 3,
            completedCityCount: 2,
            stageStatus: .battleActive
        )
        _ = initialState.buildBuilding(.barracks, inSlot: 1, at: start)
        let store = try makeStore(initialState: initialState)
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        // Button should be visible while battle is active
        #expect(!scene.isCurrentCityButtonHiddenForTesting)

        scene.requestCurrentCityBattleForTesting()

        // Idle progress conquers city → status changes, button must hide
        let saved = store.load()
        #expect(saved.stageStatus == .cityConqueredPendingMap)
        #expect(scene.isCurrentCityButtonHiddenForTesting)
    }

    @Test func cityButtonHidesAfterIdleConquestViaEnterCity() throws {
        let start = Date.distantPast
        let initialState = KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 2,
            completedCityCount: 2,
            stageStatus: .cityConqueredPendingMap
        )
        let store = try makeStore(initialState: initialState)
        store.save(initialState)

        var battleState = KingdomGameState(
            gold: 100,
            cityRemainingPower: 1,
            lastBackgroundedAt: start,
            cityNumberInCountry: 3,
            completedCityCount: 2,
            stageStatus: .battleActive
        )
        _ = battleState.buildBuilding(.barracks, inSlot: 1, at: start)
        store.save(battleState)

        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        // Reload gives scene the battleActive state, so button is visible
        #expect(!scene.isCurrentCityButtonHiddenForTesting)

        scene.enterCityForTesting(3)

        let saved = store.load()
        #expect(saved.stageStatus == .cityConqueredPendingMap)
        #expect(scene.isCurrentCityButtonHiddenForTesting)
    }

    @Test func cityButtonHidesOnMapLoadWhenNoBattleActive() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 3,
            completedCityCount: 3,
            stageStatus: .cityConqueredPendingMap
        ))
        let scene = makeScene(store: store, router: RouteSpy())

        #expect(scene.isCurrentCityButtonHiddenForTesting)
    }

    @Test func mapShowsTraitForUnlockedCityInScoutCard() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 3,
            completedCityCount: 3,
            stageStatus: .cityConqueredPendingMap
        ))
        let scene = makeScene(store: store, router: RouteSpy())

        guard case .scout(let scout) = scene.projectedScoutCardContentForTesting else {
            Issue.record("Expected Scout Card content")
            return
        }
        #expect(scout.defenseTrait == .spikedGate)
    }

    @Test func selectingCompletedCityShowsExactFeedback() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 3,
            completedCityCount: 3,
            stageStatus: .cityConqueredPendingMap
        ))
        let scene = makeScene(store: store, router: RouteSpy())

        scene.enterCityForTesting(3)

        #expect(scene.visibleFeedbackTextForTesting == "Falconridge complete")
    }

    @Test func lockedFeedbackOverlaysUnchangedCardAndExpiresAtExactDuration() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        let baseContent = scene.scoutCardBaseContentForTesting
        let projectedContent = scene.projectedScoutCardContentForTesting

        scene.enterCityForTesting(3)

        #expect(scene.visibleFeedbackTextForTesting == "Falconridge is locked")
        #expect(scene.feedbackElapsedForTesting == 0)
        #expect(scene.feedbackRemainingDurationForTesting == 1.5)
        let feedbackContent = try #require(scene.scoutCardBaseContentForTesting)
        #expect(feedbackContent.badge == baseContent?.badge)
        #expect(feedbackContent.title == baseContent?.title)
        #expect(feedbackContent.traitLines == baseContent?.traitLines)
        #expect(feedbackContent.favorable == baseContent?.favorable)
        #expect(feedbackContent.disadvantaged == baseContent?.disadvantaged)
        #expect(feedbackContent.lane == baseContent?.lane)
        #expect(feedbackContent.reward == baseContent?.reward)
        #expect(feedbackContent.attack == baseContent?.attack)
        #expect(abs(feedbackContent.attackAlpha - GameUITheme.Alpha.lockedIcon) < 0.001)
        #expect(scene.projectedScoutCardContentForTesting == projectedContent)

        let overlayFrame = try #require(scene.scoutCardOverlayHitFrameForTesting)
        let overlayPoint = CGPoint(x: overlayFrame.midX, y: overlayFrame.midY)
        scene.touchesEnded([MockTouch(location: overlayPoint)], with: nil)

        #expect(router.battleRequestCount == 0)
        #expect(scene.visibleFeedbackTextForTesting == "Falconridge is locked")
        #expect(scene.feedbackElapsedForTesting == 0)

        scene.advanceFeedbackForTesting(by: 1.49)
        #expect(scene.visibleFeedbackTextForTesting == "Falconridge is locked")
        #expect(abs((scene.feedbackRemainingDurationForTesting ?? 0) - 0.01) < 0.001)

        scene.advanceFeedbackForTesting(by: 0.01)
        #expect(scene.visibleFeedbackTextForTesting == nil)
        #expect(scene.feedbackElapsedForTesting == nil)
        #expect(scene.feedbackRemainingDurationForTesting == nil)
        #expect(scene.scoutCardOverlayHitFrameForTesting == nil)
        #expect(scene.scoutCardBaseContentForTesting == baseContent)
        #expect(scene.projectedScoutCardContentForTesting == projectedContent)
    }

    @Test func completedFeedbackCannotBeDismissedEarlyByTaps() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 3,
            completedCityCount: 3,
            stageStatus: .cityConqueredPendingMap
        ))
        let scene = makeScene(store: store, router: RouteSpy())

        scene.enterCityForTesting(3)
        scene.advanceFeedbackForTesting(by: 0.75)
        let overlayFrame = try #require(scene.scoutCardOverlayHitFrameForTesting)
        scene.touchesEnded(
            [MockTouch(location: CGPoint(x: overlayFrame.midX, y: overlayFrame.midY))],
            with: nil
        )

        #expect(scene.visibleFeedbackTextForTesting == "Falconridge complete")
        #expect(scene.feedbackElapsedForTesting == 0.75)
        #expect(scene.feedbackRemainingDurationForTesting == 0.75)
    }

    @Test func bodyTapShowsNonBlockingFlavorThenAttackStillRoutesOnce() throws {
        // Pending City 5 completed -> City 6 (Granite Pass) unlocked.
        let initialState = KingdomGameState(
            cityLevel: 5,
            cityRemainingPower: 0,
            cityNumberInCountry: 5,
            completedCityCount: 5,
            stageStatus: .cityConqueredPendingMap
        )
        let store = try makeStore(initialState: initialState)
        let router = RouteSpy()
        let feedback = CountryMapFeedbackRecorder()
        let scene = makeScene(store: store, router: router, feedback: feedback)
        let cardFrame = try #require(scene.scoutCardHitFrameForTesting)
        let attackFrame = try #require(scene.scoutCardAttackHitFrameForTesting)
        let bodyPoint = CGPoint(x: cardFrame.minX + 10, y: cardFrame.midY)

        // Sanity: the body point is on the scout card but outside Attack.
        #expect(cardFrame.contains(bodyPoint))
        #expect(!attackFrame.contains(bodyPoint))

        // Tapping the Scout card BODY shows City 6's flavor (non-blocking),
        // with no state mutation, routing, or gameplay feedback.
        scene.touchesEnded([MockTouch(location: bodyPoint)], with: nil)

        #expect(store.load() == initialState)
        #expect(router.battleRequestCount == 0)
        #expect(feedback.calls.isEmpty)
        #expect(scene.visibleFeedbackTextForTesting == "Stone walls seal the mountain road ahead.")
        #expect(scene.feedbackRemainingDurationForTesting == 2.5)
        // Flavor is non-blocking: overlay excludes Attack, Attack stays tappable.
        let overlayFrame = try #require(scene.scoutCardOverlayHitFrameForTesting)
        #expect(!overlayFrame.intersects(attackFrame))
        #expect(scene.scoutCardAttackHitFrameForTesting == attackFrame)

        // Before the flavor expires, tapping Attack still routes exactly once
        // and City 6 persists as the active battle.
        scene.touchesEnded(
            [MockTouch(location: CGPoint(x: attackFrame.midX, y: attackFrame.midY))],
            with: nil
        )

        let saved = store.load()
        #expect(saved.stageStatus == .battleActive)
        #expect(saved.cityNumberInCountry == 6)
        #expect(saved.cityLevel == 6)
        #expect(saved.cityRemainingPower == KingdomGameState.cityMaxPower(for: 6))
        #expect(router.battleRequestCount == 1)
        #expect(scene.isRoutingToBattleForTesting)
    }

    @Test func bodyTapDoesNotShowFlavorForCountryCompleteCard() throws {
        let initialState = KingdomGameState(
            cityLevel: 15,
            cityRemainingPower: 0,
            cityNumberInCountry: 15,
            completedCityCount: 15,
            stageStatus: .countryComplete
        )
        let store = try makeStore(initialState: initialState)
        let scene = makeScene(store: store, router: RouteSpy())
        let cardFrame = try #require(scene.scoutCardHitFrameForTesting)
        let bodyPoint = CGPoint(x: cardFrame.minX + 10, y: cardFrame.midY)

        scene.touchesEnded([MockTouch(location: bodyPoint)], with: nil)

        // No scout is projected for the country-complete card, so no flavor.
        #expect(scene.visibleFeedbackTextForTesting == nil)
    }

    @Test func blockingLockedFeedbackStillClearsAttackTarget() throws {
        let initialState = KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        )
        let store = try makeStore(initialState: initialState)
        let scene = makeScene(store: store, router: RouteSpy())
        let attackFrame = try #require(scene.scoutCardAttackHitFrameForTesting)

        // Tapping a locked city surfaces blocking feedback.
        scene.enterCityForTesting(3)

        #expect(scene.visibleFeedbackTextForTesting == "Falconridge is locked")
        let overlayFrame = try #require(scene.scoutCardOverlayHitFrameForTesting)
        // Blocking feedback covers the whole card (including Attack).
        #expect(overlayFrame.intersects(attackFrame))
        #expect(scene.scoutCardAttackHitFrameForTesting == nil)

        // While blocking feedback is up, an Attack tap is consumed by the
        // overlay and does not route.
        scene.touchesEnded(
            [MockTouch(location: CGPoint(x: attackFrame.midX, y: attackFrame.midY))],
            with: nil
        )
        #expect(store.load() == initialState)
    }

    @Test func idleFeedbackPreservesExistingWordingAndLongDuration() throws {
        let origin = Date(timeIntervalSinceReferenceDate: 9_000)
        let store = try makeStore(initialState: KingdomGameState(
            lastBackgroundedAt: origin
        ))
        let scene = makeScene(store: store, router: RouteSpy())

        scene.layoutGateWillPause(at: origin.addingTimeInterval(10))

        #expect(scene.lastIdleProgressResultForTesting.elapsedSeconds == 10)
        #expect(scene.visibleFeedbackTextForTesting == "No building damage while away.")
        #expect(scene.feedbackRemainingDurationForTesting == 2.5)
    }

    @Test func countryCompleteCardRemainsVisibleAfterIgnoredEntryRequest() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityLevel: 15,
            cityRemainingPower: 0,
            cityNumberInCountry: 15,
            completedCityCount: 15,
            stageStatus: .countryComplete
        ))
        let scene = makeScene(store: store, router: RouteSpy())
        let baseContent = scene.scoutCardBaseContentForTesting

        #expect(scene.projectedScoutCardContentForTesting
            == .countryComplete(countryNumber: 1, finalCityName: "Crownspire Keep"))

        scene.enterCityForTesting(15)
        #expect(scene.visibleFeedbackTextForTesting == nil)
        #expect(scene.projectedScoutCardContentForTesting
            == .countryComplete(countryNumber: 1, finalCityName: "Crownspire Keep"))
        #expect(scene.scoutCardBaseContentForTesting == baseContent)
    }

    @Test func didChangeSizePreservesActiveFeedbackAndRemainingDuration() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let scene = makeScene(store: store, router: RouteSpy())

        scene.enterCityForTesting(3)
        scene.advanceFeedbackForTesting(by: 0.6)
        let text = scene.visibleFeedbackTextForTesting
        let remaining = scene.feedbackRemainingDurationForTesting

        scene.didChangeSize(scene.size)

        #expect(scene.visibleFeedbackTextForTesting == text)
        #expect(scene.feedbackRemainingDurationForTesting == remaining)
        #expect(scene.scoutCardOverlayHitFrameForTesting != nil)
    }

    @Test func startingAndReplacingFeedbackRebasesTheUpdateClock() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let scene = makeScene(store: store, router: RouteSpy())

        scene.update(10)
        scene.enterCityForTesting(3)
        scene.update(1_000)

        #expect(scene.visibleFeedbackTextForTesting == "Falconridge is locked")
        #expect(scene.feedbackElapsedForTesting == 0)

        scene.update(1_000.4)
        #expect(abs((scene.feedbackElapsedForTesting ?? 0) - 0.4) < 0.001)

        scene.enterCityForTesting(4)
        scene.update(2_000)

        #expect(scene.visibleFeedbackTextForTesting == "Bramblegate is locked")
        #expect(scene.feedbackElapsedForTesting == 0)
    }

    @Test func layoutGatePauseDoesNotAdvanceFeedbackClock() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let scene = makeScene(store: store, router: RouteSpy())

        scene.update(10)
        scene.enterCityForTesting(3)
        scene.update(10)
        scene.update(10.4)
        let elapsedBeforePause = scene.feedbackElapsedForTesting

        scene.layoutGateWillPause(at: .init(timeIntervalSinceReferenceDate: 100))
        scene.layoutGateWillResume(at: .init(timeIntervalSinceReferenceDate: 500))
        scene.update(1_000)

        #expect(scene.visibleFeedbackTextForTesting == "Falconridge is locked")
        #expect(scene.feedbackElapsedForTesting == elapsedBeforePause)

        scene.update(1_000.2)
        #expect(abs((scene.feedbackElapsedForTesting ?? 0) - 0.6) < 0.001)
    }

    @Test func backgroundPauseDoesNotAdvanceFeedbackClock() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let scene = makeScene(store: store, router: RouteSpy())

        scene.update(20)
        scene.enterCityForTesting(3)
        scene.update(20)
        scene.update(20.4)
        let elapsedBeforePause = scene.feedbackElapsedForTesting

        scene.sceneDidEnterBackgroundForTesting(
            at: .init(timeIntervalSinceReferenceDate: 100)
        )
        scene.sceneWillEnterForegroundForTesting(
            at: .init(timeIntervalSinceReferenceDate: 500)
        )
        scene.update(2_000)

        #expect(scene.visibleFeedbackTextForTesting == "Falconridge is locked")
        #expect(scene.feedbackElapsedForTesting == elapsedBeforePause)

        scene.update(2_000.2)
        #expect(abs((scene.feedbackElapsedForTesting ?? 0) - 0.6) < 0.001)
    }

    @Test func enteringCityUsesLatestStoredState() throws {
        let initialState = KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        )
        let store = try makeStore(initialState: initialState)
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        store.save(KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 2,
            completedCityCount: 2,
            stageStatus: .cityConqueredPendingMap
        ))

        scene.enterCityForTesting(3)

        let saved = store.load()
        #expect(saved.stageStatus == .battleActive)
        #expect(saved.cityNumberInCountry == 3)
        #expect(saved.cityLevel == 3)
        #expect(saved.cityRemainingPower == KingdomGameState.cityMaxPower(for: 3))
        #expect(router.battleRequestCount == 1)
    }

    @Test func staleAttackRefreshesToAdvancedPendingMapWithoutSavingOrRouting() throws {
        let countingStore = try makeCountingStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let store = countingStore.store
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        let staleAttackFrame = try #require(scene.scoutCardAttackHitFrameForTesting)

        let latestState = KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 3,
            completedCityCount: 3,
            stageStatus: .cityConqueredPendingMap
        )
        store.save(latestState)
        countingStore.defaults.resetStateSaveCount()

        scene.touchesEnded(
            [MockTouch(location: CGPoint(
                x: staleAttackFrame.midX,
                y: staleAttackFrame.midY
            ))],
            with: nil
        )

        #expect(store.load() == latestState)
        #expect(countingStore.defaults.stateSaveCount == 0)
        #expect(router.battleRequestCount == 0)
        #expect(scene.visibleFeedbackTextForTesting == "Pinewatch complete")
        guard case .scout(let scout) = scene.projectedScoutCardContentForTesting else {
            Issue.record("Expected refreshed Scout Card content")
            return
        }
        #expect(scout.cityNumber == 4)
        #expect(scene.scoutCardBaseContentForTesting?.badge == "4")
        #expect(scene.cityVisualStateForTesting(3) == .completed)
        #expect(scene.cityVisualStateForTesting(4) == .unlocked)
        #expect(scene.scoutCardAttackHitFrameForTesting == nil)

        scene.advanceFeedbackForTesting(by: 1.5)

        #expect(scene.scoutCardAttackHitFrameForTesting != nil)
        #expect(countingStore.defaults.stateSaveCount == 0)
        #expect(router.battleRequestCount == 0)
    }

    @Test func staleCurrentControlRefreshesCountryCompleteWithoutSavingOrRouting() throws {
        let countingStore = try makeCountingStore(initialState: KingdomGameState(
            cityLevel: 15,
            cityRemainingPower: 50,
            cityNumberInCountry: 15,
            completedCityCount: 14,
            stageStatus: .battleActive
        ))
        let store = countingStore.store
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        #expect(!scene.isCurrentCityButtonHiddenForTesting)
        #expect(scene.scoutCardAttackHitFrameForTesting != nil)

        let latestState = KingdomGameState(
            cityLevel: 15,
            cityRemainingPower: 0,
            cityNumberInCountry: 15,
            completedCityCount: 15,
            stageStatus: .countryComplete
        )
        store.save(latestState)
        countingStore.defaults.resetStateSaveCount()

        scene.requestCurrentCityBattleForTesting()

        #expect(store.load() == latestState)
        #expect(countingStore.defaults.stateSaveCount == 0)
        #expect(router.battleRequestCount == 0)
        #expect(scene.visibleFeedbackTextForTesting == nil)
        #expect(scene.projectedScoutCardContentForTesting
            == .countryComplete(countryNumber: 1, finalCityName: "Crownspire Keep"))
        #expect(scene.scoutCardBaseContentForTesting?.title
            == "Country 1 conquered · Crownspire Keep")
        #expect(scene.scoutCardAttackHitFrameForTesting == nil)
        #expect(scene.isCurrentCityButtonHiddenForTesting)
        #expect(scene.cityVisualStateForTesting(15) == .completed)
    }

    @Test func enteringUnlockedCityWithoutRouterDoesNotMutateStore() throws {
        let initialState = KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        )
        let store = try makeStore(initialState: initialState)
        let scene = makeScene(store: store, router: nil)

        scene.enterCityForTesting(2)

        #expect(store.load() == initialState)
        #expect(scene.visibleFeedbackTextForTesting == "Cannot enter city yet.")
    }

    @Test func unsupportedLandscapeDoesNotApplyPartialMapGeometry() throws {
        let scene = makeScene(
            size: CGSize(width: 667, height: 375),
            store: try makeStore(initialState: .init()),
            router: RouteSpy(),
            environment: .init(safeAreaInsets: .zero, layoutClass: .phone)
        )

        #expect(scene.lastLayoutResultForTesting == .unsupported(.unsupportedGeometry))
        #expect(scene.routeLayoutCountForTesting == 0)
    }

    @Test func unsupportedTransitionClearsAndSupportedTransitionRestoresMapGeometry() throws {
        let supportedSize = CGSize(width: 393, height: 852)
        let scene = makeScene(
            size: supportedSize,
            store: try makeStore(initialState: .init(
                cityNumberInCountry: 2,
                completedCityCount: 1,
                stageStatus: .battleActive
            )),
            router: RouteSpy()
        )
        let originalCityPoint = try #require(scene.cityNodePositionForTesting(2))
        let backdrop = try #require(scene.childNode(withName: "//country-map-backdrop"))
        let city = try #require(scene.childNode(withName: "//countryMapCity-2"))
        var conqueredMarker: SKSpriteNode?
        scene.enumerateChildNodes(withName: "//countryMapCity-1") { node, stop in
            guard let marker = node as? SKSpriteNode else { return }
            conqueredMarker = marker
            stop.pointee = true
        }
        let marker = try #require(conqueredMarker)

        #expect(scene.lastLayoutResultForTesting != .unsupported(.unsupportedGeometry))
        #expect(scene.routeLayoutCountForTesting == 18)
        #expect(!backdrop.isHidden)
        #expect(!city.isHidden)
        #expect(!scene.isCurrentCityButtonHiddenForTesting)
        #expect(!marker.isHidden)
        #expect(scene.cityNumberAtPointForTesting(originalCityPoint) == 2)

        scene.size = CGSize(width: 667, height: 375)
        scene.refreshLayoutForCurrentEnvironment()

        #expect(scene.lastLayoutResultForTesting == .unsupported(.unsupportedGeometry))
        #expect(scene.routeLayoutCountForTesting == 0)
        #expect(scene.mapLayoutFramesForTesting.sceneFrame == .zero)
        #expect(scene.mapLayoutFramesForTesting.titlePanelFrame == .zero)
        #expect(scene.mapLayoutFramesForTesting.illustratedRegionFrame == .zero)
        #expect(scene.mapLayoutFramesForTesting.scoutCardFrame == .zero)
        #expect(scene.scoutCardFrameForTesting == nil)
        #expect(scene.scoutCardHitFrameForTesting == nil)
        #expect(scene.scoutCardAttackHitFrameForTesting == nil)
        #expect(scene.scoutCardOverlayHitFrameForTesting == nil)
        #expect(backdrop.isHidden)
        #expect(city.isHidden)
        #expect(scene.isCurrentCityButtonHiddenForTesting)
        #expect(marker.isHidden)
        #expect(scene.cityNumberAtPointForTesting(originalCityPoint) == nil)

        scene.layoutGateWillPause(at: Date(timeIntervalSinceReferenceDate: 10))

        #expect(scene.routeLayoutCountForTesting == 0)
        #expect(scene.isCurrentCityButtonHiddenForTesting)
        #expect(marker.isHidden)
        #expect(scene.cityNumberAtPointForTesting(originalCityPoint) == nil)

        scene.size = supportedSize
        scene.refreshLayoutForCurrentEnvironment()
        scene.layoutGateWillResume(at: Date(timeIntervalSinceReferenceDate: 20))

        let restoredCityPoint = try #require(scene.cityNodePositionForTesting(2))
        #expect(scene.lastLayoutResultForTesting != .unsupported(.unsupportedGeometry))
        #expect(scene.routeLayoutCountForTesting == 18)
        #expect(!backdrop.isHidden)
        #expect(!city.isHidden)
        #expect(!scene.isCurrentCityButtonHiddenForTesting)
        #expect(!marker.isHidden)
        #expect(scene.cityNumberAtPointForTesting(restoredCityPoint) == 2)
    }

    @Test func supportedSceneProjectsTheProductionLayout() throws {
        let scene = makeScene(
            size: CGSize(width: 393, height: 852),
            store: try makeStore(initialState: .init(
                cityRemainingPower: 0,
                cityNumberInCountry: 1,
                completedCityCount: 1,
                stageStatus: .cityConqueredPendingMap
            )),
            router: RouteSpy(),
            environment: .init(
                safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0),
                layoutClass: .phone
            )
        )
        let layout = try #require(scene.countryMapLayoutForTesting)

        #expect(scene.mapLayoutFramesForTesting.sceneFrame == layout.sceneFrame)
        #expect(scene.mapLayoutFramesForTesting.titlePanelFrame == layout.titleControlRegionFrame)
        #expect(scene.mapLayoutFramesForTesting.illustratedRegionFrame == layout.illustratedMapRegionFrame)
        #expect(scene.mapLayoutFramesForTesting.scoutCardFrame == layout.informationRegionFrame)
        #expect(scene.scoutCardFrameForTesting == layout.informationRegionFrame)
        #expect(scene.scoutCardHitFrameForTesting == layout.informationRegionFrame)
        #expect(scene.scoutCardAttackHitFrameForTesting != nil)
        #expect(scene.scoutCardOverlayHitFrameForTesting == nil)
    }

    @Test func fullBackdropMapLayoutKeepsTitleScoutCardAndAllCitiesVisible() throws {
        let size = CGSize(width: 390, height: 844)
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let scene = makeScene(size: size, store: store, router: RouteSpy())
        let layout = try #require(scene.countryMapLayoutForTesting)
        let frames = scene.mapLayoutFramesForTesting

        #expect(frames.sceneFrame == layout.sceneFrame)
        #expect(frames.titlePanelFrame == layout.titleControlRegionFrame)
        #expect(frames.illustratedRegionFrame == layout.illustratedMapRegionFrame)
        #expect(frames.scoutCardFrame == layout.informationRegionFrame)
        #expect(frames.titlePanelFrame.minY > frames.illustratedRegionFrame.maxY)
        #expect(frames.scoutCardFrame.maxY < frames.illustratedRegionFrame.minY)

        for cityNumber in 1...KingdomGameState.firstCountryCityCount {
            let position = try #require(scene.cityNodePositionForTesting(cityNumber))
            let frame = CGRect(x: position.x - 22, y: position.y - 22, width: 44, height: 44)

            #expect(frames.sceneFrame.contains(frame))
            #expect(!frames.titlePanelFrame.intersects(frame))
            #expect(!frames.scoutCardFrame.intersects(frame))
        }
    }

    @Test func countryMapBackdropCoversFullSceneBehindHUD() throws {
        let size = CGSize(width: 390, height: 844)
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let scene = makeScene(size: size, store: store, router: RouteSpy())
        let layout = try #require(scene.countryMapLayoutForTesting)
        let backdrop = try #require(scene.childNode(withName: "//country-map-backdrop"))
        let backdropFrame = backdrop.calculateAccumulatedFrame()

        #expect(abs(backdropFrame.minX - layout.displayedBackdropFrame.minX) <= 0.001)
        #expect(abs(backdropFrame.minY - layout.displayedBackdropFrame.minY) <= 0.001)
        #expect(abs(backdropFrame.width - layout.displayedBackdropFrame.width) <= 0.001)
        #expect(abs(backdropFrame.height - layout.displayedBackdropFrame.height) <= 0.001)
        #expect(backdropFrame.contains(layout.titleControlRegionFrame))
        #expect(backdropFrame.contains(layout.informationRegionFrame))
    }

    @Test func cityNodesAlignToAuthoredBackdropPads() throws {
        let size = CGSize(width: 390, height: 844)
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let scene = makeScene(size: size, store: store, router: RouteSpy())
        let layout = try #require(scene.countryMapLayoutForTesting)

        for (index, anchor) in CountryMapLayoutDefinition.country1.cityAnchors.enumerated() {
            let cityNumber = index + 1
            let cityPosition = try #require(scene.cityNodePositionForTesting(cityNumber))
            let expectedPosition = CGPoint(
                x: layout.displayedBackdropFrame.minX + layout.displayedBackdropFrame.width * anchor.x,
                y: layout.displayedBackdropFrame.minY + layout.displayedBackdropFrame.height * anchor.y
            )

            #expect(abs(cityPosition.x - expectedPosition.x) <= 1.0)
            #expect(abs(cityPosition.y - expectedPosition.y) <= 1.0)
        }
    }

    @Test func semanticSafeAreaInsetsPositionMapChrome() throws {
        let size = CGSize(width: 390, height: 844)
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let environment = CountryMapLayoutEnvironment(
            safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0),
            layoutClass: .phone
        )
        let scene = makeScene(size: size, store: store, router: RouteSpy(), environment: environment)
        let layout = try #require(scene.countryMapLayoutForTesting)

        #expect(layout.titleControlRegionFrame.maxY == size.height - 59 - 10)
        #expect(layout.informationRegionFrame.minY == 34)
        #expect(layout.illustratedMapRegionFrame.maxY < layout.titleControlRegionFrame.minY)
        #expect(layout.illustratedMapRegionFrame.minY > layout.informationRegionFrame.maxY)
    }

    @Test func cityStateStylingDistinguishesCompletedUnlockedAndLocked() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 2,
            completedCityCount: 2,
            stageStatus: .cityConqueredPendingMap
        ))
        let scene = makeScene(store: store, router: RouteSpy())

        #expect(scene.cityVisualStateForTesting(1) == .completed)
        #expect(scene.cityVisualStateForTesting(3) == .unlocked)
        #expect(scene.cityVisualStateForTesting(4) == .locked)
        #expect(!scene.isUnlockedCityPulseRunningForTesting(1))
        #expect(scene.isUnlockedCityPulseRunningForTesting(3))
        #expect(!scene.isUnlockedCityPulseRunningForTesting(4))
    }

    @Test func cityNodeCenterResolvesToCityNumber() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let scene = makeScene(store: store, router: RouteSpy())
        let cityPoint = try #require(scene.cityNodePositionForTesting(2))

        #expect(scene.cityNumberAtPointForTesting(cityPoint) == 2)
    }

    @Test func allCityCentersHave44PointHitTargets() throws {
        let scene = makeScene(
            store: try makeStore(initialState: .init(
                cityRemainingPower: 0,
                completedCityCount: 1,
                stageStatus: .cityConqueredPendingMap
            )),
            router: RouteSpy()
        )
        for cityNumber in 1...15 {
            let center = try #require(scene.cityNodePositionForTesting(cityNumber))
            #expect(scene.cityNumberAtPointForTesting(center) == cityNumber)
            #expect(scene.cityHitFrameForTesting(cityNumber)?.size == CGSize(width: 44, height: 44))
            let clearanceFrame = CGRect(
                x: center.x - 22,
                y: center.y - 22,
                width: 44,
                height: 44
            )
            let markerFrame = try #require(
                scene.conqueredMarkerFrameForTesting(cityNumber)
            )
            #expect(clearanceFrame.contains(markerFrame))
        }
    }

    @Test func currentCityControlFrameIsInsideTitlePanel() throws {
        let scene = makeScene(
            store: try makeStore(initialState: .init(stageStatus: .battleActive)),
            router: RouteSpy()
        )
        let layout = try #require(scene.countryMapLayoutForTesting)
        let currentCityControlFrame = try #require(layout.currentCityControlFrame)
        #expect(layout.titleControlRegionFrame.contains(currentCityControlFrame))
        #expect(scene.currentCityButtonFrameForTesting == currentCityControlFrame)
    }

    @Test func UIKitAdapterUsesIdiomAndPreservesSemanticInsets() throws {
        let phone = try #require(CountryMapLayoutUIKitAdapter.environment(
            safeAreaInsets: .init(top: 59, left: 3, bottom: 34, right: 5),
            idiom: .phone
        ))
        #expect(phone.layoutClass == .phone)
        #expect(phone.safeAreaInsets == .init(top: 59, left: 3, bottom: 34, right: 5))

        let narrowPad = try #require(CountryMapLayoutUIKitAdapter.environment(
            safeAreaInsets: .init(top: 24, left: 11, bottom: 20, right: 7),
            idiom: .pad
        ))
        #expect(narrowPad.layoutClass == .pad)
        #expect(narrowPad.safeAreaInsets == .init(top: 24, left: 11, bottom: 20, right: 7))

        #expect(CountryMapLayoutUIKitAdapter.environment(
            safeAreaInsets: .zero,
            idiom: .unspecified
        ) == nil)
    }

    @Test func missingBackdropIsDetectedSeparatelyFromLayout() {
        #expect(!CountryMapScene.isBackdropAvailable(
            named: "country-map-backdrop",
            imageLoader: { _ in nil }
        ))
        #expect(CountryMapLayout.compute(.init(
            sceneSize: CGSize(width: 393, height: 852),
            environment: .init(
                safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0),
                layoutClass: .phone
            ),
            definition: .country1
        )) != .unsupported(.invalidAuthoredData))
    }

    @Test func missingBackdropMarksSceneUnavailableAndRefusesLayout() throws {
        let store = try makeStore(initialState: KingdomGameState(
            stageStatus: .cityConqueredPendingMap
        ))
        let router = RouteSpy()
        let scene = makeScene(
            store: store,
            router: router,
            imageLoader: { _ in nil }
        )

        #expect(scene.isMapUnavailableForTesting)
        #expect(router.requestedGateReason == .mapUnavailable)
        #expect(scene.countryMapLayoutForTesting == nil)
        #expect(scene.routeLayoutCountForTesting == 0)
        #expect(scene.scoutCardFrameForTesting == nil)
        #expect(scene.scoutCardHitFrameForTesting == nil)
        #expect(scene.scoutCardAttackHitFrameForTesting == nil)
        #expect(scene.scoutCardOverlayHitFrameForTesting == nil)

        // A resize must not promote the half-built interface to a supported layout.
        scene.didChangeSize(CGSize(width: 414, height: 896))
        #expect(scene.countryMapLayoutForTesting == nil)
        #expect(scene.routeLayoutCountForTesting == 0)
    }

    @Test func narrowPadScoutCardFitFailureDoesNotLatchAndRecoversOnWiderResize() throws {
        // City 9 has .arcaneWard (3 favorable types: infantry, cavalry, siege).
        // At 400x955 .pad, the outer layout is supported but favorableFrame.width
        // = 236pt, while 3 items with icons need ~282pt (fixedPadLabelWidth=52
        // applies to prefix too), so the scout card footer does not fit. This
        // must NOT permanently latch isMapUnavailable — widening the window must
        // let the layout recover.
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 8,
            completedCityCount: 8,
            stageStatus: .cityConqueredPendingMap
        ))
        let router = RouteSpy()
        let narrowPad = CGSize(width: 400, height: 956)
        let scene = makeScene(
            size: narrowPad,
            store: store,
            router: router,
            environment: .init(
                safeAreaInsets: .init(top: 24, left: 0, bottom: 20, right: 0),
                layoutClass: .pad
            ),
            imageLoader: { _ in UIImage() }
        )

        // Narrow .pad: outer layout supported, scout card footer doesn't fit.
        #expect(scene.isScoutCardFitFailedForTesting)
        #expect(!scene.isMapUnavailableForTesting)
        #expect(router.requestedGateReason == .unsupportedGeometry)
        #expect(scene.scoutCardFrameForTesting == nil)

        // Resize wider — the layout must re-evaluate and recover.
        scene.size = CGSize(width: 500, height: 956)
        scene.didChangeSize(CGSize(width: 400, height: 956))

        #expect(!scene.isScoutCardFitFailedForTesting)
        #expect(!scene.isMapUnavailableForTesting)
        #expect(scene.scoutCardFrameForTesting != nil)
        #expect(scene.scoutCardHitFrameForTesting != nil)
    }

    @Test func cityLabelCenterResolvesToCityNumber() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let scene = makeScene(store: store, router: RouteSpy())
        let cityPoint = try #require(scene.cityLabelPositionForTesting(2))

        #expect(scene.cityNumberAtPointForTesting(cityPoint) == 2)
    }

    @Test func titleLabelFitsWithinPanelOnFirstLayout() throws {
        let size = CGSize(width: 375, height: 667)
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 5,
            completedCityCount: 4,
            stageStatus: .cityConqueredPendingMap
        ))
        let scene = makeScene(
            size: size,
            store: store,
            router: RouteSpy(),
            environment: .init(safeAreaInsets: .zero, layoutClass: .phone)
        )
        let frames = scene.mapLayoutFramesForTesting

        #expect(scene.titleLabelFrameWidthForTesting <= frames.titlePanelFrame.width)
        #expect(scene.titleLabelFontSizeForTesting >= 8)
    }

    @Test func titleLabelFitsWithCurrentCityButtonVisible() throws {
        let size = CGSize(width: 375, height: 667)
        let store = try makeStore(initialState: KingdomGameState(
            cityLevel: 3,
            cityRemainingPower: 50,
            cityNumberInCountry: 3,
            completedCityCount: 2,
            stageStatus: .battleActive
        ))
        let scene = makeScene(
            size: size,
            store: store,
            router: RouteSpy(),
            environment: .init(safeAreaInsets: .zero, layoutClass: .phone)
        )
        let frames = scene.mapLayoutFramesForTesting

        // With the button visible, available title width is smaller — verify fitting works
        #expect(scene.titleLabelFrameWidthForTesting <= frames.titlePanelFrame.width - 82)
        #expect(scene.titleLabelFontSizeForTesting >= 8)
    }

    @Test func touchesEndedEmptyTouchesDoesNothing() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        scene.touchesEnded([], with: nil)

        #expect(router.battleRequestCount == 0)
    }

    @Test func touchesEndedOnCityNodeEntersUnlockedCity() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        let cityPoint = try #require(scene.cityNodePositionForTesting(2))

        scene.touchesEnded([MockTouch(location: cityPoint)], with: nil)

        let saved = store.load()
        #expect(saved.stageStatus == .battleActive)
        #expect(saved.cityNumberInCountry == 2)
        #expect(router.battleRequestCount == 1)
    }

    @Test func touchesEndedOnAttackEntersProjectedScoutCity() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        let attackFrame = try #require(scene.scoutCardAttackHitFrameForTesting)

        scene.touchesEnded(
            [MockTouch(location: CGPoint(x: attackFrame.midX, y: attackFrame.midY))],
            with: nil
        )

        let saved = store.load()
        #expect(saved.stageStatus == .battleActive)
        #expect(saved.cityNumberInCountry == 2)
        #expect(saved.cityLevel == 2)
        #expect(saved.cityRemainingPower == KingdomGameState.cityMaxPower(for: 2))
        #expect(router.battleRequestCount == 1)
    }

    @Test func touchesEndedOutsideDoesNothing() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        scene.touchesEnded([MockTouch(location: CGPoint(x: 1, y: 1))], with: nil)

        #expect(router.battleRequestCount == 0)
    }

    @Test func touchesEndedCurrentCityButtonRequestsBattle() throws {
        let initialState = KingdomGameState(
            cityLevel: 3,
            cityRemainingPower: 50,
            cityNumberInCountry: 3,
            completedCityCount: 2,
            stageStatus: .battleActive
        )
        let store = try makeStore(initialState: initialState)
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        let point = try #require(scene.currentCityButtonPositionForTesting)

        scene.touchesEnded([MockTouch(location: point)], with: nil)

        #expect(store.load() == initialState)
        #expect(router.battleRequestCount == 1)
    }

    @Test func acceptedTapsAcrossDifferentEntryTargetsRequestBattleOnce() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        let attackFrame = try #require(scene.scoutCardAttackHitFrameForTesting)
        let cityPoint = try #require(scene.cityNodePositionForTesting(2))

        scene.touchesEnded(
            [MockTouch(location: CGPoint(x: attackFrame.midX, y: attackFrame.midY))],
            with: nil
        )
        scene.touchesEnded([MockTouch(location: cityPoint)], with: nil)

        #expect(router.battleRequestCount == 1)
        #expect(scene.isRoutingToBattleForTesting)
    }

    @Test func acceptedRoutingKeepsCardButDisablesEveryEntryTarget() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        let attackFrame = try #require(scene.scoutCardAttackHitFrameForTesting)
        let attackPoint = CGPoint(x: attackFrame.midX, y: attackFrame.midY)
        let cityPoint = try #require(scene.cityNodePositionForTesting(2))

        scene.touchesEnded([MockTouch(location: attackPoint)], with: nil)

        #expect(scene.isRoutingToBattleForTesting)
        #expect(scene.scoutCardHitFrameForTesting != nil)
        #expect(scene.scoutCardAttackHitFrameForTesting == nil)
        #expect(abs(
            (scene.scoutCardBaseContentForTesting?.attackAlpha ?? 0)
                - GameUITheme.Alpha.lockedIcon
        ) < 0.001)

        let currentPoint = try #require(scene.currentCityButtonPositionForTesting)
        scene.touchesEnded([MockTouch(location: attackPoint)], with: nil)
        scene.touchesEnded([MockTouch(location: currentPoint)], with: nil)
        scene.touchesEnded([MockTouch(location: cityPoint)], with: nil)

        #expect(router.battleRequestCount == 1)
    }

    @Test func missingRouterDiscardsEnteredMutationAndLeavesRetryEnabled() throws {
        let initialState = KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        )
        let countingStore = try makeCountingStore(initialState: initialState)
        let store = countingStore.store
        let scene = makeScene(store: store, router: nil)
        let attackFrame = try #require(scene.scoutCardAttackHitFrameForTesting)
        #expect(countingStore.defaults.stateSaveCount == 0)

        scene.touchesEnded(
            [MockTouch(location: CGPoint(x: attackFrame.midX, y: attackFrame.midY))],
            with: nil
        )

        #expect(store.load() == initialState)
        #expect(countingStore.defaults.stateSaveCount == 0)
        #expect(!scene.isRoutingToBattleForTesting)
        #expect(scene.visibleFeedbackTextForTesting == "Cannot enter city yet.")
        #expect(scene.scoutCardAttackHitFrameForTesting == nil)

        scene.advanceFeedbackForTesting(by: 2.5)

        #expect(scene.scoutCardAttackHitFrameForTesting != nil)
    }

    @Test func rejectedRouterRetainsSavedBattleAndRestoresRetry() throws {
        let countingStore = try makeCountingStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let store = countingStore.store
        let router = RouteSpy()
        router.acceptsBattleRequest = false
        router.onBattleRequest = { requestCount in
            #expect(countingStore.defaults.stateSaveCount == requestCount)
        }
        let scene = makeScene(store: store, router: router)
        let attackFrame = try #require(scene.scoutCardAttackHitFrameForTesting)
        let attackPoint = CGPoint(x: attackFrame.midX, y: attackFrame.midY)
        #expect(countingStore.defaults.stateSaveCount == 0)

        scene.touchesEnded([MockTouch(location: attackPoint)], with: nil)

        let saved = store.load()
        #expect(saved.stageStatus == .battleActive)
        #expect(saved.cityNumberInCountry == 2)
        #expect(countingStore.defaults.stateSaveCount == 1)
        #expect(router.battleRequestCount == 1)
        #expect(!scene.isRoutingToBattleForTesting)
        #expect(scene.visibleFeedbackTextForTesting == "Cannot enter city yet.")
        #expect(scene.scoutCardAttackHitFrameForTesting == nil)

        scene.advanceFeedbackForTesting(by: 2.5)
        let retryFrame = try #require(scene.scoutCardAttackHitFrameForTesting)
        scene.touchesEnded(
            [MockTouch(location: CGPoint(x: retryFrame.midX, y: retryFrame.midY))],
            with: nil
        )

        #expect(router.battleRequestCount == 2)
        #expect(countingStore.defaults.stateSaveCount == 2)
        #expect(store.load() == saved)
        #expect(!scene.isRoutingToBattleForTesting)
    }

    @Test func lockedCityNodeShowsExactFeedbackWithoutMutationOrRoute() throws {
        let initialState = KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        )
        let store = try makeStore(initialState: initialState)
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        let cityPoint = try #require(scene.cityNodePositionForTesting(3))

        scene.touchesEnded([MockTouch(location: cityPoint)], with: nil)

        #expect(store.load() == initialState)
        #expect(router.battleRequestCount == 0)
        #expect(scene.visibleFeedbackTextForTesting == "Falconridge is locked")
        #expect(scene.feedbackRemainingDurationForTesting == 1.5)
    }

    @Test func completedCityNodeShowsExactFeedbackWithoutMutationOrRoute() throws {
        let initialState = KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 2,
            completedCityCount: 2,
            stageStatus: .cityConqueredPendingMap
        )
        let store = try makeStore(initialState: initialState)
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        let cityPoint = try #require(scene.cityNodePositionForTesting(2))

        scene.touchesEnded([MockTouch(location: cityPoint)], with: nil)

        #expect(store.load() == initialState)
        #expect(router.battleRequestCount == 0)
        #expect(scene.visibleFeedbackTextForTesting == "Pinewatch complete")
        #expect(scene.feedbackRemainingDurationForTesting == 1.5)
    }

    @Test func countryCompleteExposesNoAttackTarget() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityLevel: 15,
            cityRemainingPower: 0,
            cityNumberInCountry: 15,
            completedCityCount: 15,
            stageStatus: .countryComplete
        ))
        let scene = makeScene(store: store, router: RouteSpy())

        #expect(scene.scoutCardHitFrameForTesting != nil)
        #expect(scene.scoutCardAttackHitFrameForTesting == nil)
    }

    @Test func mapUnavailableGateConsumesTouchesBeforeEveryTarget() throws {
        let router = RouteSpy()
        let scene = makeScene(
            store: try makeStore(initialState: .init(
                cityRemainingPower: 0,
                completedCityCount: 1,
                stageStatus: .cityConqueredPendingMap
            )),
            router: router,
            imageLoader: { _ in nil }
        )

        scene.touchesEnded(
            [MockTouch(location: CGPoint(x: scene.size.width / 2, y: scene.size.height / 2))],
            with: nil
        )

        #expect(router.battleRequestCount == 0)
    }

    @Test func transientOverlayConsumesBeforeCardAndMapTargets() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        scene.enterCityForTesting(3)
        let overlayFrame = try #require(scene.scoutCardOverlayHitFrameForTesting)
        let overlayPoint = CGPoint(x: overlayFrame.midX, y: overlayFrame.midY)
        scene.enumerateChildNodes(withName: "//countryMapCity-2") { node, _ in
            node.position = overlayPoint
        }

        scene.touchesEnded([MockTouch(location: overlayPoint)], with: nil)

        #expect(router.battleRequestCount == 0)
        #expect(scene.visibleFeedbackTextForTesting == "Falconridge is locked")
        #expect(scene.feedbackElapsedForTesting == 0)
    }

    @Test func attackConsumesBeforeOverlappingCurrentCityControl() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        let attackFrame = try #require(scene.scoutCardAttackHitFrameForTesting)
        let attackPoint = CGPoint(x: attackFrame.midX, y: attackFrame.midY)
        let currentControl = try #require(
            scene.childNode(withName: "countryMapCurrentCityButton")
        )
        currentControl.isHidden = false
        currentControl.position = attackPoint

        scene.touchesEnded([MockTouch(location: attackPoint)], with: nil)

        #expect(store.load().cityNumberInCountry == 2)
        #expect(router.battleRequestCount == 1)
    }

    @Test func cardBodyConsumesBeforeOverlappingCityNode() throws {
        let initialState = KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        )
        let store = try makeStore(initialState: initialState)
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        let cardFrame = try #require(scene.scoutCardHitFrameForTesting)
        let attackFrame = try #require(scene.scoutCardAttackHitFrameForTesting)
        let cardPoint = CGPoint(x: cardFrame.minX + 2, y: cardFrame.maxY - 2)
        #expect(!attackFrame.contains(cardPoint))
        scene.enumerateChildNodes(withName: "//countryMapCity-2") { node, _ in
            node.position = cardPoint
        }

        scene.touchesEnded([MockTouch(location: cardPoint)], with: nil)

        #expect(store.load() == initialState)
        #expect(router.battleRequestCount == 0)
    }

    @Test func currentControlConsumesBeforeOverlappingCompletedCityNode() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityLevel: 3,
            cityRemainingPower: 50,
            cityNumberInCountry: 3,
            completedCityCount: 2,
            stageStatus: .battleActive
        ))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        let currentPoint = try #require(scene.currentCityButtonPositionForTesting)
        scene.enumerateChildNodes(withName: "//countryMapCity-2") { node, _ in
            node.position = currentPoint
        }

        scene.touchesEnded([MockTouch(location: currentPoint)], with: nil)

        #expect(router.battleRequestCount == 1)
        #expect(scene.visibleFeedbackTextForTesting == nil)
    }

    @Test func testOnlyCurrentCityRequestUsesUnifiedCompletedResult() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 3,
            completedCityCount: 3,
            stageStatus: .cityConqueredPendingMap
        ))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        scene.requestCurrentCityBattleForTesting()

        #expect(router.battleRequestCount == 0)
        #expect(scene.visibleFeedbackTextForTesting == "Falconridge complete")
        guard case .scout(let scout) = scene.projectedScoutCardContentForTesting else {
            Issue.record("Expected Scout Card content")
            return
        }
        #expect(scout.cityNumber == 4)
        #expect(scout.defenseTrait == .spikedGate)
    }

    @Test func requestCurrentCityBattleWithoutRouterShowsFeedback() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityLevel: 3,
            cityRemainingPower: 50,
            cityNumberInCountry: 3,
            completedCityCount: 2,
            stageStatus: .battleActive
        ))
        let scene = makeScene(store: store, router: nil)

        scene.requestCurrentCityBattleForTesting()

        #expect(scene.visibleFeedbackTextForTesting == "Cannot enter city yet.")
    }

    @Test func fitLabelWithZeroMaxWidthDoesNotCrash() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let scene = makeScene(store: store, router: RouteSpy())
        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.text = "Test"
        label.fontSize = 30

        scene.fitLabelForTesting(label, maxWidth: 0)

        #expect(label.fontSize == 30)
    }

    @Test func fitLabelShrinksFontWhenLabelIsTooWide() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let scene = makeScene(store: store, router: RouteSpy())
        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.text = "Very Long Text That Exceeds Narrow Width"
        label.fontSize = 30

        scene.fitLabelForTesting(label, maxWidth: 20)

        #expect(label.fontSize < 30)
        #expect(label.fontSize >= 8)
    }

    @Test func layoutGateSettlesThenExcludesMapGateOnlyTime() throws {
        let origin = Date(timeIntervalSinceReferenceDate: 1_000)
        let store = try makeStore(initialState: makeIdleAccruingState(since: origin))
        let scene = makeScene(store: store, router: nil)

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

    @Test func realBackgroundNestedInsideMapGateCountsOnlySystemBackgroundTime() throws {
        let origin = Date(timeIntervalSinceReferenceDate: 2_000)
        let store = try makeStore(initialState: makeIdleAccruingState(since: origin))
        let scene = makeScene(store: store, router: nil)

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

    @Test func backgroundThenMapGateResumeWhileBackgroundedPreservesEveryInterval() throws {
        let origin = Date(timeIntervalSinceReferenceDate: 5_000)
        let store = try makeStore(initialState: makeIdleAccruingState(since: origin))
        let scene = makeScene(store: store, router: nil)

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

    @Test func mapGateThenBackgroundResumeWhileBackgroundedExcludesForegroundGateTime() throws {
        let origin = Date(timeIntervalSinceReferenceDate: 6_000)
        let store = try makeStore(initialState: makeIdleAccruingState(since: origin))
        let scene = makeScene(store: store, router: nil)

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

    // MARK: - Feedback settings & uncovered-path tests

    @Test("Country Map init(coder:) assigns default feedback dependencies")
    func countryMapCoderInitAssignsDefaultFeedbackDependencies() throws {
        let archiveData: Data
        do {
            let scene = CountryMapScene(
                size: CGSize(width: 393, height: 852),
                store: try makeStore(initialState: KingdomGameState(
                    stageStatus: .cityConqueredPendingMap
                )),
                router: nil,
                layoutEnvironmentOverride: .init(
                    safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0),
                    layoutClass: .phone
                )
            )
            archiveData = try NSKeyedArchiver.archivedData(
                withRootObject: scene,
                requiringSecureCoding: false
            )
        }
        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: archiveData)
        unarchiver.requiresSecureCoding = false
        let decoded = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? CountryMapScene
        unarchiver.finishDecoding()
        let scene = try #require(decoded)
        #expect(scene.size == CGSize(width: 393, height: 852))
        // The coder init uses NoOpGameplayFeedbackProvider and shared stores.
        // Verify the scene is usable and has no layout yet (didMove not called).
        #expect(scene.countryMapLayoutForTesting == nil)
    }

    @Test("Country Map update returns early while feedback settings are visible")
    func countryMapUpdateReturnsEarlyWhenFeedbackSettingsVisible() throws {
        let feedback = CountryMapFeedbackRecorder()
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let scene = makeScene(store: store, router: RouteSpy(), feedback: feedback)
        let gearFrame = try #require(scene.feedbackSettingsGearFrameForTesting)

        // Show a transient feedback so update would normally advance it.
        scene.enterCityForTesting(3)
        #expect(scene.visibleFeedbackTextForTesting == "Falconridge is locked")

        // Prime the update clock.
        scene.update(10)

        // Open the settings modal.
        scene.handleTouchForTesting(at: gearFrame.center)
        #expect(scene.isFeedbackSettingsVisibleForTesting)

        // Call update again - the settings-visible guard must prevent
        // advanceFeedback from running, so the feedback elapsed stays at 0.
        scene.update(11)
        #expect(scene.feedbackElapsedForTesting == 0)
        #expect(scene.visibleFeedbackTextForTesting == "Falconridge is locked")
    }

    @Test("Country Map openFeedbackSettings is blocked when the map is unavailable")
    func countryMapOpenFeedbackSettingsBlockedWhenMapUnavailable() throws {
        let store = try makeStore(initialState: KingdomGameState(
            stageStatus: .cityConqueredPendingMap
        ))
        let scene = makeScene(
            store: store,
            router: RouteSpy(),
            imageLoader: { _ in nil }
        )
        #expect(scene.isMapUnavailableForTesting)

        // The gear node exists but has a zero frame since layout never ran.
        let gearFrame = try #require(scene.feedbackSettingsGearFrameForTesting)
        #expect(gearFrame == .zero)

        // Tapping the gear's nominal location must not open settings.
        scene.handleTouchForTesting(at: .zero)
        #expect(!scene.isFeedbackSettingsVisibleForTesting)
    }

    @Test("Country Map openFeedbackSettings is blocked while the layout gate is paused")
    func countryMapOpenFeedbackSettingsBlockedWhileLayoutGatePaused() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let scene = makeScene(store: store, router: RouteSpy())
        let gearFrame = try #require(scene.feedbackSettingsGearFrameForTesting)

        scene.layoutGateWillPause(at: .init(timeIntervalSinceReferenceDate: 1_000))

        // Tapping the gear while the layout gate is paused must not open settings.
        scene.handleTouchForTesting(at: gearFrame.center)
        #expect(!scene.isFeedbackSettingsVisibleForTesting)
    }

    @Test("Country Map activateFeedbackSettings toggles preferences via accessibility elements")
    func countryMapActivateFeedbackSettingsViaAccessibilityTogglesPreferences() throws {
        let preferences = RecordingFeedbackPreferencesManager()
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let size = CGSize(width: 393, height: 852)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        let scene = CountryMapScene(
            size: size,
            store: store,
            router: RouteSpy(),
            layoutEnvironmentOverride: .init(
                safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0),
                layoutClass: .phone
            ),
            feedback: NoOpGameplayFeedbackProvider(),
            feedbackPreferences: preferences
        )
        scene.didMove(to: view)

        // Open settings via the gear accessibility element.
        let gearElements = (view.accessibilityElements as? [UIAccessibilityElement]) ?? []
        let gear = try #require(gearElements.onlyElement as? ActionAccessibilityElement)
        #expect(gear.accessibilityActivate())
        #expect(scene.isFeedbackSettingsVisibleForTesting)

        // Now the modal elements should be exposed.
        let modalElements = (view.accessibilityElements as? [UIAccessibilityElement]) ?? []
        let soundElement = try #require(
            modalElements.first { $0.accessibilityLabel == "Sound Effects" }
                as? ActionAccessibilityElement
        )
        let hapticsElement = try #require(
            modalElements.first { $0.accessibilityLabel == "Haptics" }
                as? ActionAccessibilityElement
        )
        let closeElement = try #require(
            modalElements.first { $0.accessibilityLabel == "Close" }
                as? ActionAccessibilityElement
        )

        let initialSound = preferences.current.soundEffectsEnabled
        let initialHaptics = preferences.current.hapticsEnabled

        // Toggle sound effects via accessibility activation.
        #expect(soundElement.accessibilityActivate())
        #expect(preferences.current.soundEffectsEnabled == !initialSound)

        // Toggle haptics via accessibility activation.
        #expect(hapticsElement.accessibilityActivate())
        #expect(preferences.current.hapticsEnabled == !initialHaptics)

        // Close via accessibility activation.
        #expect(closeElement.accessibilityActivate())
        #expect(!scene.isFeedbackSettingsVisibleForTesting)
    }

    @Test("Country Map activateFeedbackSettings is a no-op when the modal is not visible")
    func countryMapActivateFeedbackSettingsNoOpWhenNotVisible() throws {
        let preferences = RecordingFeedbackPreferencesManager()
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let size = CGSize(width: 393, height: 852)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        let scene = CountryMapScene(
            size: size,
            store: store,
            router: RouteSpy(),
            layoutEnvironmentOverride: .init(
                safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0),
                layoutClass: .phone
            ),
            feedback: NoOpGameplayFeedbackProvider(),
            feedbackPreferences: preferences
        )
        scene.didMove(to: view)

        // Open settings, grab the sound element, then close settings.
        let gearElements = (view.accessibilityElements as? [UIAccessibilityElement]) ?? []
        let gear = try #require(gearElements.onlyElement as? ActionAccessibilityElement)
        #expect(gear.accessibilityActivate())
        #expect(scene.isFeedbackSettingsVisibleForTesting)

        let modalElements = (view.accessibilityElements as? [UIAccessibilityElement]) ?? []
        let soundElement = try #require(
            modalElements.first { $0.accessibilityLabel == "Sound Effects" }
                as? ActionAccessibilityElement
        )
        let closeElement = try #require(
            modalElements.first { $0.accessibilityLabel == "Close" }
                as? ActionAccessibilityElement
        )

        // Close settings via the close element.
        #expect(closeElement.accessibilityActivate())
        #expect(!scene.isFeedbackSettingsVisibleForTesting)

        let soundBefore = preferences.current.soundEffectsEnabled
        // Activating the sound element while the modal is not visible must
        // be a no-op: activateFeedbackSettings guards on isVisible.
        #expect(soundElement.accessibilityActivate())
        #expect(preferences.current.soundEffectsEnabled == soundBefore)
    }

    @Test("Country Map fitTitleLabel returns false when maxWidth is below the minimum")
    func countryMapFitTitleLabelReturnsFalseBelowMinimumWidth() throws {
        let store = try makeStore(initialState: KingdomGameState(
            stageStatus: .cityConqueredPendingMap
        ))
        let scene = makeScene(store: store, router: RouteSpy())
        let label = SKLabelNode(fontNamed: GameUITheme.Font.bold)
        label.text = "Country 1"
        label.fontSize = 28

        // A maxWidth below minimumTitleTextWidth (160) must return false
        // without shrinking the font.
        #expect(!scene.fitTitleLabelForTesting(label, maxWidth: 100))
        #expect(label.fontSize == 28)
    }

    @Test("Country Map applyIdleProgressFeedback returns early when no time elapsed")
    func countryMapApplyIdleProgressFeedbackEarlyReturnWhenNoElapsed() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let scene = makeScene(store: store, router: RouteSpy())

        // With no lastBackgroundedAt, returnFromBackground returns .none
        // (elapsedSeconds == 0), so applyIdleProgressFeedback must return
        // early without showing any feedback.
        scene.sceneWillEnterForegroundForTesting(at: Date())

        #expect(scene.lastIdleProgressResultForTesting.elapsedSeconds == 0)
        #expect(scene.visibleFeedbackTextForTesting == nil)
    }

    @Test("Country Map handleCityNodeTouch for locked city emits invalidAction feedback")
    func countryMapHandleCityNodeTouchLockedCityEmitsInvalidAction() throws {
        let feedback = CountryMapFeedbackRecorder()
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let scene = makeScene(store: store, router: RouteSpy(), feedback: feedback)
        let cityPoint = try #require(scene.cityNodePositionForTesting(3))

        scene.handleTouchForTesting(at: cityPoint)

        #expect(feedback.discreteEvents == [.invalidAction])
        #expect(scene.visibleFeedbackTextForTesting == "Falconridge is locked")
        #expect(store.load().stageStatus == .cityConqueredPendingMap)
    }

    @Test("Country Map handleCityNodeTouch for completed city emits invalidAction feedback")
    func countryMapHandleCityNodeTouchCompletedCityEmitsInvalidAction() throws {
        let feedback = CountryMapFeedbackRecorder()
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 2,
            completedCityCount: 2,
            stageStatus: .cityConqueredPendingMap
        ))
        let scene = makeScene(store: store, router: RouteSpy(), feedback: feedback)
        let cityPoint = try #require(scene.cityNodePositionForTesting(2))

        scene.handleTouchForTesting(at: cityPoint)

        #expect(feedback.discreteEvents == [.invalidAction])
        #expect(scene.visibleFeedbackTextForTesting == "Pinewatch complete")
    }

    @Test("Country Map advanceFeedback is a no-op when no transient feedback is active")
    func countryMapAdvanceFeedbackNoOpWithoutTransientFeedback() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let scene = makeScene(store: store, router: RouteSpy())

        // Prime the update clock, then call update again with no feedback.
        scene.update(10)
        #expect(scene.visibleFeedbackTextForTesting == nil)
        scene.update(11)
        #expect(scene.visibleFeedbackTextForTesting == nil)
        #expect(scene.feedbackElapsedForTesting == nil)
    }

    @Test("Country Map cityNumber returns nil for a point not on any city node")
    func countryMapCityNumberReturnsNilForEmptyPoint() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let scene = makeScene(store: store, router: RouteSpy())

        // A point far from any city node must return nil.
        let emptyPoint = CGPoint(x: -500, y: -500)
        #expect(scene.cityNumberAtPointForTesting(emptyPoint) == nil)

        // Tapping empty space must not produce any feedback or mutation.
        let feedback = CountryMapFeedbackRecorder()
        let store2 = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let scene2 = makeScene(store: store2, router: RouteSpy(), feedback: feedback)
        scene2.handleTouchForTesting(at: emptyPoint)
        #expect(feedback.calls.isEmpty)
        #expect(scene2.visibleFeedbackTextForTesting == nil)
    }

    @Test("Country Map projected scout card content is nil when layout is unavailable")
    func countryMapProjectedScoutCardContentIsNilWithoutLayout() throws {
        let store = try makeStore(initialState: KingdomGameState(
            stageStatus: .cityConqueredPendingMap
        ))
        let scene = makeScene(
            store: store,
            router: RouteSpy(),
            imageLoader: { _ in nil }
        )
        #expect(scene.isMapUnavailableForTesting)
        #expect(scene.projectedScoutCardContentForTesting == nil)
        #expect(scene.scoutCardBaseContentForTesting == nil)
    }

    @Test("Country Map visible feedback alpha reflects scout card feedback state")
    func countryMapVisibleFeedbackAlphaReflectsScoutCardState() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let scene = makeScene(store: store, router: RouteSpy())

        // Show feedback - the scout card feedback alpha should be > 0.
        scene.enterCityForTesting(3)
        #expect(scene.visibleFeedbackTextForTesting == "Falconridge is locked")
        #expect(scene.visibleFeedbackAlphaForTesting > 0)
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

    private final class RouteSpy: CountryMapSceneRouting {
        var acceptsBattleRequest = true
        var onBattleRequest: ((Int) -> Void)?
        private(set) var battleRequestCount = 0
        private(set) var requestedGateReason: AppLayoutGateReason?

        func countryMapSceneDidRequestBattle(_ scene: CountryMapScene) -> Bool {
            battleRequestCount += 1
            onBattleRequest?(battleRequestCount)
            return acceptsBattleRequest
        }

        func countryMapScene(
            _ scene: CountryMapScene,
            didRequestLayoutGate reason: AppLayoutGateReason
        ) {
            requestedGateReason = reason
        }
    }

    private final class MockTouch: UITouch {
        private let loc: CGPoint
        init(location: CGPoint) {
            self.loc = location
            super.init()
        }
        override func location(in view: UIView?) -> CGPoint {
            return loc
        }
    }

    @Test("Country Map feedbackSettingsAccessibilityFrame falls back from nonfinite screen conversion")
    func countryMapFeedbackSettingsAccessibilityFrameFallsBackFromNonfinite() {
        let viewLocalFrame = CGRect(x: 12, y: 34, width: 44, height: 44)
        let validScreenFrame = CGRect(x: 212, y: 334, width: 44, height: 44)
        let invalidScreenFrame = CGRect(x: CGFloat.nan, y: 334, width: 44, height: 44)

        #expect(CountryMapScene.feedbackSettingsAccessibilityFrame(
            viewLocalFrame: viewLocalFrame,
            screenFrame: invalidScreenFrame
        ) == viewLocalFrame)
        #expect(CountryMapScene.feedbackSettingsAccessibilityFrame(
            viewLocalFrame: viewLocalFrame,
            screenFrame: validScreenFrame
        ) == validScreenFrame)
    }

    @Test("Country Map activateFeedbackSettings with consumed does nothing when settings are visible")
    func countryMapActivateFeedbackSettingsConsumedDoesNothing() throws {
        let preferences = RecordingFeedbackPreferencesManager()
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let scene = makeScene(store: store, router: RouteSpy(), feedbackPreferences: preferences)
        let gearFrame = try #require(scene.feedbackSettingsGearFrameForTesting)

        scene.handleTouchForTesting(at: gearFrame.center)
        #expect(scene.isFeedbackSettingsVisibleForTesting)

        // .consumed must not toggle any preference or close the modal.
        scene.activateFeedbackSettingsForTesting(.consumed)
        #expect(scene.isFeedbackSettingsVisibleForTesting)
        #expect(preferences.current.soundEffectsEnabled)
        #expect(preferences.current.hapticsEnabled)
    }

    @Test("Country Map accessibility adapter uses screen coordinates when the view has a window")
    func countryMapAccessibilityAdapterUsesScreenCoordinatesWithWindow() throws {
        let window = UIWindow(frame: CGRect(x: 100, y: 200, width: 393, height: 852))
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let scene = CountryMapScene(
            size: CGSize(width: 393, height: 852),
            store: store,
            router: RouteSpy(),
            layoutEnvironmentOverride: .init(
                safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0),
                layoutClass: .phone
            )
        )
        let view = SKView(frame: CGRect(origin: .zero, size: scene.size))
        window.addSubview(view)
        view.presentScene(scene)
        scene.didMove(to: view)

        // The gear accessibility element's frame must be in screen coordinates
        // (derived via UIKit's canonical conversion) rather than view-local
        // coordinates.
        let gearSceneFrame = try #require(scene.feedbackSettingsGearFrameForTesting)
        #expect(gearSceneFrame.width > 0)
        #expect(gearSceneFrame.height > 0)

        // Access the gear accessibility element exposed by the adapter (not
        // just the scene-local hit frame) and verify its accessibilityFrame
        // matches UIKit's scene-to-screen conversion contract.
        let gearElements = (view.accessibilityElements as? [UIAccessibilityElement]) ?? []
        let gear = try #require(gearElements.onlyElement as? ActionAccessibilityElement)

        let viewLocalFrame = CGRect(
            x: gearSceneFrame.minX,
            y: view.bounds.height - gearSceneFrame.maxY,
            width: gearSceneFrame.width,
            height: gearSceneFrame.height
        )
        let expectedScreenFrame = UIAccessibility.convertToScreenCoordinates(
            viewLocalFrame,
            in: view
        )

        #expect(gear.accessibilityFrame == expectedScreenFrame)
    }

    private func makeScene(
        size: CGSize = CGSize(width: 393, height: 852),
        store: KingdomGameStore,
        router: CountryMapSceneRouting?,
        environment: CountryMapLayoutEnvironment = .init(
            safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0),
            layoutClass: .phone
        ),
        imageLoader: ((String) -> UIImage?)? = nil,
        feedback: GameplayFeedbackProviding? = nil,
        feedbackPreferences: FeedbackPreferencesManaging? = nil
    ) -> CountryMapScene {
        let scene = CountryMapScene(
            size: size,
            store: store,
            router: router,
            layoutEnvironmentOverride: environment,
            imageLoaderOverride: imageLoader,
            feedback: feedback ?? NoOpGameplayFeedbackProvider(),
            feedbackPreferences: feedbackPreferences ?? RecordingFeedbackPreferencesManager()
        )
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        scene.didMove(to: view)
        return scene
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

    private func makeCountingStore(
        initialState: KingdomGameState
    ) throws -> (
        store: KingdomGameStore,
        defaults: CountingUserDefaults
    ) {
        let suiteName = "PyxisTests.Counting.\(UUID().uuidString)"
        let defaults = try #require(
            CountingUserDefaults(suiteName: suiteName, countedKey: "state")
        )
        defaults.removePersistentDomain(forName: suiteName)
        let store = KingdomGameStore(defaults: defaults, key: "state")
        store.save(initialState)
        defaults.resetStateSaveCount()
        return (store, defaults)
    }
}

private extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}
