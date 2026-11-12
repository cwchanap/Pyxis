//
//  BattleSceneTests.swift
//  PyxisTests
//

import Foundation
import SpriteKit
import Testing
import UIKit
@testable import Pyxis

@MainActor
struct BattleSceneTests {
    private struct PixelBounds {
        let minX: Int
        let minY: Int
        let maxXExclusive: Int
        let maxYExclusive: Int

        var width: Int { maxXExclusive - minX }
        var height: Int { maxYExclusive - minY }
    }

    private enum BattleFeedbackCall: Equatable {
        case discrete(GameplayFeedbackEvent)
    }

    private final class BattleFeedbackRecorder: GameplayFeedbackProviding {
        private(set) var calls: [BattleFeedbackCall] = []
        private(set) var automaticCallCount = 0
        var onDiscreteEvent: ((GameplayFeedbackEvent) -> Void)?

        func emit(_ event: GameplayFeedbackEvent) {
            calls.append(.discrete(event))
            onDiscreteEvent?(event)
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

    private func activeMilestoneState(city: Int, gold: Int = 100) -> KingdomGameState {
        KingdomGameState(
            gold: gold,
            cityLevel: city,
            cityNumberInCountry: city,
            completedCityCount: city - 1,
            stageStatus: .battleActive
        )
    }

    @Test("City 5 presents authored milestone arrival without pausing combat")
    func city5PresentsReadableArrivalWithoutPausingCombat() throws {
        let scene = makeScene(
            store: try makeStore(initialState: activeMilestoneState(city: 5))
        )

        #expect(scene.milestoneTierForTesting == 1)
        #expect(scene.isMilestoneArrivalVisibleForTesting)
        #expect(scene.milestoneArrivalTitleForTesting == "City 5 · Highcrest")
        #expect(scene.milestoneArrivalSubtitleForTesting == "A proud hill fortress crowns the frontier.")
        #expect(scene.milestoneArrivalTitleFontSizeForTesting >= 12)
        #expect(scene.milestoneArrivalSubtitleFontSizeForTesting >= 12)
        #expect(scene.milestoneCityAccentFrameForTesting != nil)

        scene.update(10)
        scene.update(11)
        #expect(scene.lastAdvanceCombatDeltaForTesting == 1)
    }

    @Test("Ordinary cities create no milestone presentation")
    func ordinaryCityHasNoMilestonePresentation() throws {
        let scene = makeScene(store: try makeStore(initialState: KingdomGameState(
            cityLevel: 6,
            cityNumberInCountry: 6,
            completedCityCount: 5
        )))

        #expect(scene.milestoneTierForTesting == nil)
        #expect(!scene.isMilestoneArrivalVisibleForTesting)
        #expect(scene.milestoneCityAccentFrameForTesting == nil)
    }

    @Test("DEBUG freeze marker stops combat advancement without changing routing")
    func freezeCombatLaunchArgumentStopsCombatAdvancement() throws {
        let scene = makeScene(
            store: try makeStore(initialState: stateWithBarracks()),
            launchArguments: [BattleScene.freezeCombatLaunchArgument]
        )

        scene.update(10)
        scene.update(11)

        #expect(scene.lastUpdateTimeForTesting == 11)
        #expect(scene.lastAdvanceCombatDeltaForTesting == nil)
        #expect(scene.liveSoldierCountForTesting == 0)
    }

    @Test("Arrival consumes one Settings-gear tap and the next tap opens Settings")
    func milestoneArrivalConsumesUnderlyingTap() throws {
        let scene = makeScene(
            store: try makeStore(initialState: activeMilestoneState(city: 5))
        )
        let gearFrame = try #require(scene.feedbackSettingsGearFrameForTesting)

        scene.handleTouchForTesting(at: gearFrame.center)
        #expect(!scene.isMilestoneArrivalVisibleForTesting)
        #expect(!scene.isFeedbackSettingsVisibleForTesting)

        scene.handleTouchForTesting(at: gearFrame.center)
        #expect(scene.isFeedbackSettingsVisibleForTesting)
        #expect(scene.milestoneArrivalFrameForTesting == nil)
    }

    @Test("Arrival does not replay on didMove redraw or layout refresh")
    func milestoneArrivalDoesNotReplayOnLayoutRefresh() throws {
        let scene = makeScene(
            store: try makeStore(initialState: activeMilestoneState(city: 10))
        )
        let count = scene.milestoneArrivalPresentationCountForTesting

        scene.refreshLayoutForCurrentEnvironment()
        scene.redrawForTesting(shouldLayout: true)
        scene.repeatDidMoveForTesting()

        #expect(scene.milestoneArrivalPresentationCountForTesting == count)
    }

    @Test("VoiceOver Settings activation dismisses milestone arrival before opening")
    func milestoneArrivalDismissesForAccessibilitySettingsActivation() throws {
        let size = CGSize(width: 390, height: 844)
        let containerView = UIView(frame: CGRect(origin: .zero, size: size))
        let adapter = FeedbackSettingsAccessibilityAdapter(
            containerView: containerView,
            sceneToScreenFrame: { $0 },
            postNotification: { _, _ in }
        )
        let scene = makeScene(
            store: try makeStore(initialState: activeMilestoneState(city: 5)),
            size: size,
            feedbackSettingsAccessibilityAdapter: adapter
        )
        let retainedGear = try #require(try accessibilityElements(in: containerView).onlyElement)

        #expect(scene.isMilestoneArrivalVisibleForTesting)
        #expect(retainedGear.accessibilityActivate())

        #expect(!scene.isMilestoneArrivalVisibleForTesting)
        #expect(scene.isFeedbackSettingsVisibleForTesting)
    }

    @Test("Finale arrival stays readable at supported narrow and landscape gates")
    func finaleArrivalFitsSupportedGates() throws {
        for size in [
            CGSize(width: 568, height: 320),
            CGSize(width: 667, height: 375),
            CGSize(width: 320, height: 568)
        ] {
            let scene = makeScene(
                store: try makeStore(initialState: activeMilestoneState(
                    city: KingdomGameState.firstCountryCityCount
                )),
                size: size
            )
            let banner = try #require(scene.milestoneArrivalFrameForTesting)
            let title = try #require(scene.milestoneArrivalTitleFrameForTesting)
            let subtitle = try #require(scene.milestoneArrivalSubtitleFrameForTesting)

            #expect(banner.contains(title))
            #expect(banner.contains(subtitle))
            #expect(!title.intersects(subtitle))
            #expect(scene.milestoneArrivalTitleFontSizeForTesting >= 12)
            #expect(scene.milestoneArrivalSubtitleFontSizeForTesting >= 12)
        }
    }

    @Test("Arrival layout failure releases input instead of leaving an invisible interceptor")
    func milestoneArrivalFailsOpenOnUnusableGeometry() throws {
        let scene = makeScene(
            store: try makeStore(initialState: activeMilestoneState(city: 5)),
            size: CGSize(width: 110, height: 568)
        )

        #expect(!scene.isMilestoneArrivalVisibleForTesting)
        #expect(scene.milestoneArrivalFrameForTesting == nil)
    }

    @Test func battleSceneDisplaysCampaignCityTitle() throws {
        let store = try makeStore(
            initialState: KingdomGameState(
                cityLevel: 3,
                cityNumberInCountry: 3,
                completedCityCount: 2
            )
        )
        let scene = makeScene(store: store)

        #expect(scene.cityTitleTextForTesting == "Falconridge")
    }

    @Test("BattleScene uses BattleChromeLayout's field and retries failed chrome")
    func battleSceneUsesChromeFieldAndRetriesFailedChrome() throws {
        let router = BattleRouterSpy()
        let store = try makeStore(initialState: KingdomGameState())
        let scene = makeScene(
            store: store,
            router: router,
            size: CGSize(width: 393, height: 852)
        )
        let expected = try #require(BattleChromeLayout.compute(.init(
            sceneSize: CGSize(width: 393, height: 852)
        )))

        #expect(scene.battleChromeLayoutForTesting?.battlefieldFrame == expected.battlefieldFrame)
        #expect(!scene.isBattleChromeFitFailedForTesting)

        scene.size = CGSize(width: 320, height: 568)
        scene.refreshLayoutForCurrentEnvironment()
        #expect(scene.isBattleChromeFitFailedForTesting)
        #expect(router.lastLayoutGateReason == .unsupportedGeometry)

        scene.size = CGSize(width: 393, height: 852)
        scene.refreshLayoutForCurrentEnvironment()
        #expect(!scene.isBattleChromeFitFailedForTesting)
        #expect(scene.battleChromeLayoutForTesting?.battlefieldFrame == expected.battlefieldFrame)
    }

    @Test("Battle settings gear follows BattleChromeLayout and remains the only gear")
    func battleSettingsGearUsesChromeSettingsFrame() throws {
        let size = CGSize(width: 393, height: 852)
        let scene = makeScene(
            store: try makeStore(initialState: KingdomGameState()),
            size: size
        )
        let layout = try #require(BattleChromeLayout.compute(.init(sceneSize: size)))
        let gear = try #require(scene.feedbackSettingsGearFrameForTesting)
        let gearNode = try #require(firstNode(of: SettingsGearNode.self, in: scene))
        let gearTile = try #require(
            gearNode.childNode(withName: "settingsGearTile") as? PanelNode
        )
        let gearPlate = try #require(
            gearTile.childNode(withName: "panelPlate") as? SKShapeNode
        )

        #expect(gear == layout.settingsFrame)
        #expect(nodeCount(in: scene, of: SettingsGearNode.self) == 1)
        #expect(gearPlate.fillTexture != nil)
        #expect(rgbaBytes(gearPlate.fillColor) == [255, 255, 255, 255])
        #expect(rgbaBytes(gearPlate.strokeColor) == [198, 150, 80, 153])
        scene.handleTouchForTesting(at: gear.center)
        #expect(scene.isFeedbackSettingsVisibleForTesting)
    }

    @Test("Battle chrome gate preserves an open Settings modal across recovery")
    func battleChromeGatePreservesSettingsModal() throws {
        let scene = makeScene(
            store: try makeStore(initialState: KingdomGameState()),
            size: CGSize(width: 393, height: 852)
        )
        scene.handleTouchForTesting(
            at: try #require(scene.feedbackSettingsGearFrameForTesting).center
        )
        #expect(scene.isFeedbackSettingsVisibleForTesting)

        scene.size = CGSize(width: 320, height: 568)
        scene.refreshLayoutForCurrentEnvironment()
        #expect(scene.isBattleChromeFitFailedForTesting)
        #expect(scene.isFeedbackSettingsVisibleForTesting)
        #expect(scene.isBattlefieldActionLayerPausedForTesting)

        scene.size = CGSize(width: 393, height: 852)
        scene.refreshLayoutForCurrentEnvironment()
        #expect(!scene.isBattleChromeFitFailedForTesting)
        #expect(scene.isFeedbackSettingsVisibleForTesting)
        #expect(scene.feedbackSettingsGearFrameForTesting
            == scene.battleChromeLayoutForTesting?.settingsFrame)
    }

    @Test("Battle HUD deploys Infantry fallback and reports unavailable unit requirements")
    func battleHUDHandlesFallbackAndRequirements() throws {
        let size = CGSize(width: 393, height: 852)
        let layout = try #require(BattleChromeLayout.compute(.init(sceneSize: size)))

        let fallbackScene = makeScene(
            store: try makeStore(initialState: KingdomGameState()),
            size: size
        )
        fallbackScene.handleTouchForTesting(at: layout.deployFrame.center)
        #expect(fallbackScene.liveSoldierCountForTesting == 1)

        let router = BattleRouterSpy()
        let blockedScene = makeScene(
            store: try makeStore(initialState: KingdomGameState(
                cityNumberInCountry: 5,
                completedCityCount: 4
            )),
            router: router,
            size: size
        )
        blockedScene.dismissMilestoneArrivalForTesting()
        blockedScene.handleTouchForTesting(at: layout.medallionHitFrames[1].center)
        #expect(blockedScene.feedbackTextForTesting == "Build Archer first.")
        #expect(!router.didRequestCountryMap)
        #expect(!router.didRequestBuildingView)

        blockedScene.handleTouchForTesting(at: layout.medallionHitFrames[3].center)
        #expect(blockedScene.feedbackTextForTesting == "Mage unlocks at City 8.")
    }

    @Test("Blocked squad feedback uses a dedicated non-overlapping anchor")
    func blockedSquadFeedbackUsesDedicatedAnchor() throws {
        let scene = makeScene(
            store: try makeStore(initialState: stateWithBarracks(keepRemaining: 20)),
            router: BattleRouterSpy(),
            size: CGSize(width: 393, height: 852)
        )
        let layout = try #require(scene.battleChromeLayoutForTesting)
        scene.spawnSoldierForTesting()
        scene.requestGameplayTabForTesting(.camp)

        let feedbackPanel = try #require(
            scene.childNode(withName: "feedbackPanel") as? PanelNode
        )
        let campPanel = try #require(
            scene.battleHUDForTesting.tabBarForTesting.childNode(
                withName: "gameplayTab-camp/gameplayTabPanel-camp"
            ) as? PanelNode
        )

        #expect(!feedbackPanel.calculateAccumulatedFrame().intersects(layout.recommendationFrame))
        #expect(campPanel.styleForTesting == .disabled)
        #expect(scene.battleHUDForTesting.tabBarForTesting.hitFrameForTesting(for: .camp) == nil)
        #expect(scene.battleHUDForTesting.tabBarForTesting.hitFrameForTesting(for: .map) == nil)
    }

    @Test("Tapping the visible income band presents Gold info")
    func tappingIncomeBandPresentsGoldInfo() throws {
        let scene = makeScene(
            store: try makeStore(initialState: stateWithBarracks(gold: 123, keepRemaining: 200)),
            size: CGSize(width: 393, height: 852)
        )
        let layout = try #require(scene.battleChromeLayoutForTesting)

        scene.handleTouchForTesting(at: layout.incomeFrame.center)

        #expect(scene.lastPresentedTooltipTextForTesting.hasPrefix("Gold "))
        #expect(scene.lastPresentedTooltipTextForTesting.contains("Soldiers"))
    }

    @Test("Tapping the visible city progress band presents City info")
    func tappingCityProgressBandPresentsCityInfo() throws {
        let scene = makeScene(
            store: try makeStore(initialState: stateWithBarracks(gold: 123, keepRemaining: 200)),
            size: CGSize(width: 393, height: 852)
        )
        let layout = try #require(scene.battleChromeLayoutForTesting)

        scene.handleTouchForTesting(at: layout.cityProgressFrame.center)

        #expect(scene.lastPresentedTooltipTextForTesting.contains(scene.gameStateForTesting.displayCityTitle))
        #expect(scene.lastPresentedTooltipTextForTesting.contains("HP "))
    }

    @Test func combatUsesCurrentCityLaneDefenseMultipliers() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 30))
        let scene = makeScene(store: store)

        // City 1: left fortified (1.25), center standard (1.0), right exposed (0.80).
        let multipliers = scene.combatLaneDamageMultipliersForTesting
        #expect(multipliers[.left] == 1.25)
        #expect(multipliers[.center] == 1.0)
        #expect(multipliers[.right] == 0.80)
    }

    @Test func battleSceneKeepsSoldierHUDValueWithoutTitle() throws {
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 20))
        let scene = makeScene(store: store)

        #expect(scene.liveCombatStatusTextForTesting == "0")

        scene.spawnSoldierForTesting()

        #expect(scene.liveCombatStatusTextForTesting == "1")
        #expect(scene.liveSoldierCountForTesting == 1)
    }

    @Test("Battle reserves the left HUD status column for Settings without shrinking resource values")
    func battleHUDReservesSettingsSpaceAcrossPhoneFixtures() throws {
        for size in [CGSize(width: 393, height: 852), CGSize(width: 393, height: 700)] {
            let store = try makeStore(initialState: stateWithBarracks(gold: 123_456_789, keepRemaining: 20))
            let scene = makeScene(store: store, size: size)
            let layout = try #require(scene.battleChromeLayoutForTesting)
            let gearFrame = try #require(scene.feedbackSettingsGearFrameForTesting)

            #expect(gearFrame == layout.settingsFrame)
            let expectedGearSize = size.height >= 780
                ? CGSize(width: 46, height: 46)
                : CGSize(width: 44, height: 44)
            #expect(gearFrame.size == expectedGearSize)
            #expect(layout.topBandFrame.contains(gearFrame))
            #expect(nodeCount(in: scene, of: SettingsGearNode.self) == 1)
        }

    }

    @Test("Battle uses injected feedback and preferences for Settings and manual deployment")
    func battleUsesInjectedFeedbackAndSettingsDependencies() throws {
        let feedback = BattleFeedbackRecorder()
        let preferences = RecordingFeedbackPreferencesManager()
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 20))
        let scene = makeScene(
            store: store,
            feedback: feedback,
            feedbackPreferences: preferences
        )

        scene.handleTouchForTesting(at: try #require(scene.feedbackSettingsGearFrameForTesting).center)
        #expect(scene.isFeedbackSettingsVisibleForTesting)
        let layout = try #require(FeedbackSettingsLayout.compute(
            sceneSize: scene.size,
            safeAreaInsets: .zero
        ))
        scene.handleTouchForTesting(at: layout.soundRowFrame.center)

        #expect(preferences.current.soundEffectsEnabled == false)

        scene.handleTouchForTesting(at: layout.closeFrame.center)
        scene.spawnSoldierForTesting()

        #expect(feedback.discreteEvents == [.manualDeployment])
    }

    @Test("Battle Settings uses finite view-local accessibility coordinates when screen conversion is invalid")
    func battleSettingsAccessibilityFallsBackFromNonfiniteScreenConversion() {
        let viewLocalFrame = CGRect(x: 12, y: 34, width: 44, height: 44)
        let validScreenFrame = CGRect(x: 212, y: 334, width: 44, height: 44)
        let invalidScreenFrame = CGRect(x: CGFloat.nan, y: 334, width: 44, height: 44)

        #expect(FeedbackSettingsAccessibilityAdapter.feedbackSettingsAccessibilityFrame(
            viewLocalFrame: viewLocalFrame,
            screenFrame: invalidScreenFrame
        ) == viewLocalFrame)
        #expect(FeedbackSettingsAccessibilityAdapter.feedbackSettingsAccessibilityFrame(
            viewLocalFrame: viewLocalFrame,
            screenFrame: validScreenFrame
        ) == validScreenFrame)
    }

    @Test("Battle Settings activateFeedbackSettings with consumed does nothing when settings are visible")
    func battleSettingsActivateFeedbackSettingsConsumedDoesNothing() throws {
        let preferences = RecordingFeedbackPreferencesManager()
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 100))
        let scene = makeScene(store: store, router: BattleRouterSpy(), feedbackPreferences: preferences)
        let gearFrame = try #require(scene.feedbackSettingsGearFrameForTesting)

        scene.handleTouchForTesting(at: gearFrame.center)
        #expect(scene.isFeedbackSettingsVisibleForTesting)

        // .consumed must not toggle any preference or close the modal.
        scene.activateFeedbackSettingsForTesting(.consumed)
        #expect(scene.isFeedbackSettingsVisibleForTesting)
        #expect(preferences.current.soundEffectsEnabled)
        #expect(preferences.current.hapticsEnabled)
    }

    @Test("Battle Settings consumes underlying controls and pauses only combat actions")
    func battleSettingsBlocksInputAndPausesTheBattlefieldActionLayer() throws {
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 100))
        let router = BattleRouterSpy()
        let scene = makeScene(store: store, router: router)
        let layout = try #require(scene.battleChromeLayoutForTesting)

        scene.handleTouchForTesting(at: try #require(scene.feedbackSettingsGearFrameForTesting).center)

        #expect(scene.isFeedbackSettingsVisibleForTesting)
        #expect(scene.isBattlefieldActionLayerPausedForTesting)
        #expect(!scene.isBattlefieldLayerPausedForTesting)
        #expect(scene.battlefieldActionLayerPositionForTesting == .zero)

        let settingsLayout = try #require(FeedbackSettingsLayout.compute(
            sceneSize: scene.size,
            safeAreaInsets: .zero
        ))
        let tabPoints = [layout.tabHitFrames[2], layout.tabHitFrames[1]].map { frame in
            // The bottom sheet covers the tab centers; use the exposed edge
            // above its close button to verify the modal still consumes tabs.
            CGPoint(x: frame.midX, y: frame.maxY - 4)
        }
        #expect(tabPoints.allSatisfy { point in
            !settingsLayout.closeFrame.contains(point)
        })
        for point in [layout.deployFrame.center] + tabPoints + [
            layout.incomeFrame.center,
            layout.cityProgressFrame.center
        ] {
            scene.handleTouchForTesting(at: point)
        }

        #expect(scene.liveSoldierCountForTesting == 0)
        #expect(!router.didRequestCountryMap)
        #expect(!router.didRequestBuildingView)

        scene.handleTouchForTesting(at: settingsLayout.closeFrame.center)

        #expect(!scene.isFeedbackSettingsVisibleForTesting)
        #expect(!scene.isBattlefieldActionLayerPausedForTesting)
    }

    @Test("Battle Settings pauses an active city-hit action until Settings closes")
    func battleSettingsPausesCityHitFeedbackUntilClose() async throws {
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 500, selectedLane: .right))
        let size = CGSize(width: 390, height: 844)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        let controller = UIViewController()
        controller.view = view
        let windowScene = try #require(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        let previousKeyWindow = windowScene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: windowScene)
        window.frame = CGRect(origin: .zero, size: size)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer {
            view.presentScene(nil)
            window.isHidden = true
            previousKeyWindow?.makeKeyAndVisible()
        }

        let scene = BattleScene(size: size, store: store, combatSeed: 1)
        view.presentScene(scene)
        try await Task.sleep(for: .milliseconds(100))
        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 3.0)

        let city = try #require(firstNode(named: "enemy-city", in: scene))
        #expect(city.action(forKey: "cityHitFeedback") != nil)

        scene.handleTouchForTesting(at: try #require(scene.feedbackSettingsGearFrameForTesting).center)
        #expect(scene.isFeedbackSettingsVisibleForTesting)

        try await Task.sleep(for: .milliseconds(300))
        #expect(city.action(forKey: "cityHitFeedback") != nil)

        let safeAreaInsets = view.safeAreaInsets
        let settingsLayout = try #require(FeedbackSettingsLayout.compute(
            sceneSize: scene.size,
            safeAreaInsets: .init(
                top: safeAreaInsets.top,
                left: safeAreaInsets.left,
                bottom: safeAreaInsets.bottom,
                right: safeAreaInsets.right
            )
        ))
        scene.handleTouchForTesting(at: settingsLayout.closeFrame.center)
        #expect(!scene.isFeedbackSettingsVisibleForTesting)
        try await pollUntil(timeout: .seconds(1), interval: .milliseconds(20)) {
            city.action(forKey: "cityHitFeedback") == nil
        }
    }

    @Test("Battle Settings blocks updates without resetting the battle clock")
    func battleSettingsRefreshesTheClockAndResumesWithoutCatchUp() throws {
        let scene = try makeScene()

        scene.update(10)
        scene.handleTouchForTesting(at: try #require(scene.feedbackSettingsGearFrameForTesting).center)
        scene.update(20)

        #expect(scene.lastUpdateTimeForTesting == 20)
        #expect(scene.lastAdvanceCombatDeltaForTesting == nil)

        let layout = try #require(FeedbackSettingsLayout.compute(
            sceneSize: scene.size,
            safeAreaInsets: .zero
        ))
        scene.handleTouchForTesting(at: layout.closeFrame.center)
        #expect(scene.lastUpdateTimeForTesting == 20)

        scene.update(21)
        #expect(scene.lastAdvanceCombatDeltaForTesting == 1)
    }

    @Test("Only an actual Battle layout-gate recovery clears the battle clock")
    func battleLayoutGateRecoveryResetsTheClockOnceAndPreservesSettings() throws {
        let scene = try makeScene()

        scene.update(10)
        scene.handleTouchForTesting(at: try #require(scene.feedbackSettingsGearFrameForTesting).center)
        scene.layoutGateWillPause(at: Date(timeIntervalSinceReferenceDate: 11))
        scene.layoutGateWillResume(at: Date(timeIntervalSinceReferenceDate: 12))

        #expect(scene.lastUpdateTimeForTesting == nil)
        #expect(scene.isFeedbackSettingsVisibleForTesting)

        scene.update(20)
        scene.layoutGateWillResume(at: Date(timeIntervalSinceReferenceDate: 21))

        #expect(scene.lastUpdateTimeForTesting == 20)
        #expect(scene.isFeedbackSettingsVisibleForTesting)
    }

    @Test("Battle layout gate refuses retained Settings accessibility activation")
    func battleLayoutGateRefusesRetainedSettingsAccessibilityActivation() throws {
        let size = CGSize(width: 390, height: 844)
        let accessibilityContainer = UIView(frame: CGRect(origin: .zero, size: size))
        let accessibilityAdapter = FeedbackSettingsAccessibilityAdapter(
            containerView: accessibilityContainer,
            sceneToScreenFrame: { $0 },
            postNotification: { _, _ in }
        )
        let feedback = BattleFeedbackRecorder()
        let router = BattleRouterSpy()
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 100))
        let scene = makeScene(
            store: store,
            router: router,
            size: size,
            feedback: feedback,
            feedbackSettingsAccessibilityAdapter: accessibilityAdapter
        )
        let retainedGear = try #require(try accessibilityElements(in: accessibilityContainer).onlyElement)
        let stateBeforeActivation = scene.gameStateForTesting

        #expect(retainedGear.accessibilityLabel == "Settings")
        scene.layoutGateWillPause(at: Date(timeIntervalSinceReferenceDate: 11))
        #expect(retainedGear.accessibilityActivate())

        #expect(!scene.isFeedbackSettingsVisibleForTesting)
        #expect(try accessibilityElements(in: accessibilityContainer).onlyElement === retainedGear)
        #expect(feedback.calls.isEmpty)
        #expect(!router.didRequestCountryMap)
        #expect(!router.didRequestBuildingView)
        #expect(scene.gameStateForTesting == stateBeforeActivation)
        #expect(store.load() == stateBeforeActivation)
    }

    @Test("Battle preserves feedback Settings, report, and reward-effect Z tiers")
    func battlePreservesSettingsAndConquestPresentationZOrder() throws {
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 1, selectedLane: .right))
        let scene = makeScene(store: store)
        let gear = try #require(firstNode(of: SettingsGearNode.self, in: scene))
        let gearHitTarget = try #require(
            gear.children.first(where: { $0.name == SettingsGearNode.semanticName })
        )
        let hudPanel = try #require(gear.parent)
        let settingsModal = try #require(firstNode(of: FeedbackSettingsNode.self, in: scene))
        let conquestReport = try #require(firstNode(of: ConquestReportNode.self, in: scene))

        #expect(effectiveZPosition(of: gear) == GameUITheme.Z.hud + 2)
        #expect(effectiveZPosition(of: gearHitTarget) == GameUITheme.Z.hud + 2)
        #expect(effectiveZPosition(of: gear) > effectiveZPosition(of: hudPanel))
        #expect(effectiveZPosition(of: gear) < effectiveZPosition(of: settingsModal))
        #expect(effectiveZPosition(of: settingsModal) < effectiveZPosition(of: conquestReport))

        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 3.0)

        let goldBurst = try #require(firstNode(named: "goldBurst", in: scene))
        #expect(effectiveZPosition(of: goldBurst) == GameUITheme.Z.modal + 0.5)
        #expect(effectiveZPosition(of: goldBurst) > effectiveZPosition(of: conquestReport))
        #expect(effectiveZPosition(of: gear) < effectiveZPosition(of: goldBurst))
    }

    @Test("A successful manual Battle deployment emits exactly one discrete event")
    func battleManualDeploymentEmitsOnceAfterTheAuthoritativeMutation() throws {
        let feedback = BattleFeedbackRecorder()
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 20))
        let scene = makeScene(store: store, feedback: feedback)

        scene.spawnSoldierForTesting()

        #expect(scene.gameStateForTesting.activeSiegeSession?.deployments.count == 1)
        #expect(feedback.calls == [.discrete(.manualDeployment)])
    }

    @Test("An automatically spawned Battle soldier does not emit deployment feedback")
    func battleBuildingSpawnRemainsSilent() throws {
        let feedback = BattleFeedbackRecorder()
        let cityKey = CityKey(countryNumber: 1, cityNumber: 1)
        let cityState = CityBattleState(
            slots: [1: CityBuilding(type: .barracks, spawnTimerElapsed: 9.95)]
        )
        let store = try makeStore(initialState: KingdomGameState(
            cityBattleStates: [cityKey.storageKey: cityState]
        ))
        let scene = makeScene(store: store, feedback: feedback)

        scene.advanceCombatSingleStepForTesting(deltaTime: 0.1)

        #expect(scene.buildingLiveSoldierCountForTesting == 1)
        #expect(feedback.discreteEvents.isEmpty)
        #expect(feedback.automaticCallCount == 1)
    }

    @Test("A rejected Battle deployment emits one invalid action event")
    func battleRejectedManualDeploymentEmitsInvalidOnce() throws {
        let feedback = BattleFeedbackRecorder()
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 100))
        let scene = makeScene(store: store, feedback: feedback)

        // Reaching the 10-live cap needs recharge time that would conquer
        // the tiny authored camps, so the squad is filled directly; the tap
        // below still exercises the production cap guard before any charge
        // spend.
        scene.spawnManualSoldiersDirectlyForTesting(KingdomGameState.manualSoldierCap)
        feedback.reset()

        scene.spawnSoldierForTesting()

        #expect(scene.manualLiveSoldierCountForTesting == KingdomGameState.manualSoldierCap)
        #expect(scene.manualDeployChargesForTesting == 3)
        #expect(scene.feedbackTextForTesting == "Manual squad is full.")
        #expect(feedback.calls == [.discrete(.invalidAction)])
    }

    @Test("Manual deploy drains transient charges and denies the fourth tap")
    func manualDeployDrainsChargesAndDeniesWhenEmpty() throws {
        let feedback = BattleFeedbackRecorder()
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 100))
        let scene = makeScene(store: store, feedback: feedback)

        for _ in 0..<3 {
            scene.spawnSoldierForTesting()
        }
        #expect(scene.manualDeployChargesForTesting == 0)
        feedback.reset()

        scene.spawnSoldierForTesting()

        #expect(scene.manualLiveSoldierCountForTesting == 3)
        #expect(
            scene.gameStateForTesting.activeSiegeSession?.deployments.map(\.count).reduce(0, +) == 3
        )
        #expect(feedback.calls == [.discrete(.invalidAction)])
    }

    @Test("Unbuilt soldier type is rejected without spending a charge")
    func typeGuardRefusesBeforeSpendingCharges() throws {
        let feedback = BattleFeedbackRecorder()
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 100))
        let scene = makeScene(store: store, feedback: feedback)

        scene.selectManualSoldierTypeForTesting(.archer)

        // The rejected selection emits invalid action, falls back to the
        // spawnable starter type, and never touches the charge pool.
        #expect(scene.selectedManualSoldierTypeForTesting == .infantry)
        #expect(scene.manualDeployChargesForTesting == 3)
        #expect(scene.manualLiveSoldierCountForTesting == 0)
        #expect(feedback.calls == [.discrete(.invalidAction)])
    }

    @Test("Settings-modal pause time never recharges manual deploy charges")
    func settingsModalTimeNeverRechargesCharges() throws {
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 100))
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()
        #expect(scene.manualDeployChargesForTesting == 2)

        scene.handleTouchForTesting(at: try #require(scene.feedbackSettingsGearFrameForTesting).center)
        #expect(scene.isFeedbackSettingsVisibleForTesting)
        scene.advanceCombatForTesting(deltaTime: 1.5)

        #expect(scene.manualDeployChargesForTesting == 2)
    }

    @Test("Building-spawned soldiers never spend manual deploy charges")
    func buildingSpawnsLeaveChargesUntouched() throws {
        let cityKey = CityKey(countryNumber: 1, cityNumber: 1)
        let cityState = CityBattleState(
            slots: [1: CityBuilding(type: .barracks, spawnTimerElapsed: 9.95)]
        )
        let store = try makeStore(initialState: KingdomGameState(
            cityBattleStates: [cityKey.storageKey: cityState]
        ))
        let scene = makeScene(store: store)

        scene.advanceCombatSingleStepForTesting(deltaTime: 0.1)

        #expect(scene.buildingLiveSoldierCountForTesting == 1)
        #expect(scene.manualDeployChargesForTesting == 3)
    }

    @Test("A deployed Captain never spends manual deploy charges")
    func captainDeploymentLeavesChargesUntouched() throws {
        let (scene, _) = try makeCaptainScene(
            state: makeCaptainState(cityNumber: 3, selectedLane: .right)
        )

        #expect(scene.livingCaptainForTesting != nil)
        #expect(scene.manualDeployChargesForTesting == 3)
    }

    @Test("Deploy HUD follows the integer charge count, not fractional recharge")
    func deployHUDFollowsIntegerChargeChanges() throws {
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 100))
        let scene = makeScene(store: store)

        #expect(scene.battleHUDCurrentContentForTesting?.manualDeployCharges == 3)

        scene.spawnSoldierForTesting()
        #expect(scene.battleHUDCurrentContentForTesting?.manualDeployCharges == 2)

        scene.advanceCombatForTesting(deltaTime: 1.5)
        #expect(scene.manualDeployChargesForTesting == 3)
        #expect(scene.battleHUDCurrentContentForTesting?.manualDeployCharges == 3)
    }

    @Test("Background/foreground keeps banked charges and recharge progress")
    func deployChargesSurviveCombatRebuildAcrossBackground() throws {
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 100))
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()
        #expect(scene.manualDeployChargesForTesting == 2)

        // Bank 1.0s of fractional recharge, then rebuild combat through the
        // real background/foreground handlers — the rebuild must not
        // silently refill or wipe the pool.
        scene.advanceCombatForTesting(deltaTime: 1.0)
        scene.enterBackgroundForTesting(at: Date(timeIntervalSinceReferenceDate: 1_000))
        scene.enterForegroundForTesting(at: Date(timeIntervalSinceReferenceDate: 1_001))

        #expect(scene.manualDeployChargesForTesting == 2)

        // The banked fraction carries too: ~0.6 more tick seconds tops the
        // 1.5s interval back up.
        scene.advanceCombatForTesting(deltaTime: 0.6)
        #expect(scene.manualDeployChargesForTesting == 3)
    }

    @Test("A charge refill retires the stale 'Deploy is recharging.' denial")
    func chargeRefillClearsRechargingDenial() throws {
        var state = captainless(stateWithBarracks(
            keepRemaining: 1_000,
            cityNumberInCountry: 5,
            completedCityCount: 4,
            selectedLane: .left
        ))
        state.siegeProgress.guardReinforcements = GuardReinforcementProgress(
            waveElapsedSeconds: 0,
            remainingReserve: 0,
            unresolvedGuards: [GuardSnapshot(lane: .left, remainingHP: 12)]
        )
        let store = try makeStore(initialState: state)
        let scene = makeScene(store: store)

        // A live Guard holds the left lane, so the three deployed soldiers
        // spend the whole window hitting it (trait-only) and never touch a
        // structure — feedbackText would keep the stale denial without the
        // refill clear.
        for _ in 0..<3 {
            scene.spawnSoldierForTesting()
        }
        scene.spawnSoldierForTesting()
        #expect(scene.feedbackTextForTesting == "Deploy is recharging.")

        scene.advanceCombatForTesting(deltaTime: 1.6)

        #expect(scene.manualDeployChargesForTesting == 1)
        #expect(scene.feedbackTextForTesting == "")
    }

    @Test("Battle submits one automatic feedback batch for every combat tick")
    func battleSubmitsOneAutomaticFeedbackBatchPerTickResult() throws {
        let feedback = BattleFeedbackRecorder()
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 500))
        let scene = makeScene(store: store, feedback: feedback)
        scene.spawnSoldierForTesting()
        feedback.reset()

        for _ in 0..<30 {
            scene.advanceCombatSingleStepForTesting(deltaTime: 0.1)
        }

        #expect(feedback.automaticCallCount == 30)
    }

    @Test("Fresh live Battle conquest emits reward before city outcome and never replays")
    func battleFreshLiveOutcomeEmitsRewardThenConquestOnce() throws {
        let feedback = BattleFeedbackRecorder()
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 1, selectedLane: .right))
        let scene = makeScene(store: store, feedback: feedback)
        scene.spawnSoldierForTesting()
        feedback.reset()

        scene.advanceCombatForTesting(deltaTime: 3.0)

        #expect(scene.gameStateForTesting.pendingBattleResult != nil)
        #expect(feedback.discreteEvents == [.goldReward, .cityConquest])

        scene.repeatDidMoveForTesting()
        scene.refreshLayoutForCurrentEnvironment()
        scene.redrawForTesting(shouldLayout: true)

        #expect(feedback.discreteEvents == [.goldReward, .cityConquest])
    }

    @Test("Fresh live Battle outcome is durable before each semantic feedback event")
    func battleFreshLiveOutcomePersistsBeforeEachSemanticFeedbackEvent() throws {
        let feedback = BattleFeedbackRecorder()
        let initialGold = 100
        let store = try makeStore(
            initialState: stateWithBarracks(gold: initialGold, keepRemaining: 1, selectedLane: .right)
        )
        let scene = makeScene(store: store, feedback: feedback)
        scene.spawnSoldierForTesting()
        feedback.reset()

        var persistedStatesAtFeedback: [KingdomGameState] = []
        feedback.onDiscreteEvent = { _ in
            persistedStatesAtFeedback.append(store.load())
        }

        scene.advanceCombatForTesting(deltaTime: 3.0)

        #expect(feedback.discreteEvents == [.goldReward, .cityConquest])
        #expect(persistedStatesAtFeedback.count == 2)
        #expect(persistedStatesAtFeedback.allSatisfy { state in
            state.gold == initialGold + 8
                && state.stageStatus == .cityConqueredPendingMap
                && state.pendingBattleResult?.conquestMode == .live
                && state.pendingBattleResult?.goldEarned == 8
        })
    }

    @Test("Fresh idle Battle conquest emits reward before city outcome")
    func battleFreshIdleOutcomeEmitsRewardThenConquest() throws {
        let feedback = BattleFeedbackRecorder()
        let store = try makeStore(initialState: idleConquestReadyState())
        let scene = makeScene(store: store, feedback: feedback)

        scene.enterBackgroundForTesting(at: Date(timeIntervalSince1970: 1_000))
        feedback.reset()
        scene.enterForegroundForTesting(at: Date(timeIntervalSince1970: 10_000))

        #expect(scene.gameStateForTesting.pendingBattleResult != nil)
        #expect(feedback.discreteEvents == [.goldReward, .cityConquest])
    }

    @Test("A final-city Battle outcome emits reward before country completion")
    func battleFinalCityOutcomeEmitsRewardThenCountryCompletion() throws {
        let feedback = BattleFeedbackRecorder()
        let cityKey = CityKey(countryNumber: 1, cityNumber: 15)
        var finalCityState = KingdomGameState(
            cityLevel: 15,
            cityNumberInCountry: 15,
            completedCityCount: 14,
            cityBattleStates: [
                cityKey.storageKey: CityBattleState(
                    // A level-6 infantry soldier lands the live conquest hit.
                    slots: [1: CityBuilding(type: .barracks, level: 6)]
                )
            ]
        )
        // Every support objective is destroyed first, so the soldier's first hit lands on the Keep
        // (1 HP) and produces the live conquest on any authored route.
        SiegeTestSupport.setKeepRemaining(1, on: &finalCityState)
        SiegeTestSupport.destroySupportObjectives(of: &finalCityState)
        let store = try makeStore(initialState: finalCityState)
        let scene = makeScene(store: store, feedback: feedback)
        scene.spawnSoldierForTesting()
        feedback.reset()

        scene.advanceCombatForTesting(deltaTime: 3.0)

        #expect(feedback.discreteEvents == [.goldReward, .countryCompletion])
    }

    @Test("Restored Battle reports are silent across reapplication and resize")
    func battleRestoredOutcomeNeverEmitsFeedback() throws {
        let feedback = BattleFeedbackRecorder()
        let store = try makeStore(initialState: pendingConqueredState())
        let scene = makeScene(store: store, feedback: feedback)

        scene.repeatDidMoveForTesting()
        scene.refreshLayoutForCurrentEnvironment()
        scene.redrawForTesting(shouldLayout: true)

        #expect(feedback.calls.isEmpty)
    }

    @Test("Restored Battle report hides Settings accessibility and uses system-default focus")
    func restoredBattleReportHidesSettingsAccessibilityWhenSettingsWasClosed() throws {
        let size = CGSize(width: 390, height: 844)
        let containerView = UIView(frame: CGRect(origin: .zero, size: size))
        var posts: [AccessibilityPost] = []
        let accessibilityAdapter = FeedbackSettingsAccessibilityAdapter(
            containerView: containerView,
            sceneToScreenFrame: { $0 },
            postNotification: { notification, target in
                posts.append(AccessibilityPost(notification: notification, target: target))
            }
        )
        let scene = makeScene(
            store: try makeStore(initialState: pendingConqueredState()),
            size: size,
            feedbackSettingsAccessibilityAdapter: accessibilityAdapter
        )

        #expect(scene.isConquestPopupVisibleForTesting)
        #expect(try accessibilityElements(in: containerView).isEmpty)
        #expect(posts.count == 1)
        let post = try #require(posts.first)
        #expect(post.notification == .screenChanged)
        #expect(post.target == nil)
    }

    @Test("Fresh Battle conquest hides Settings accessibility when Settings was closed")
    func freshBattleConquestHidesSettingsAccessibilityWhenSettingsWasClosed() throws {
        let size = CGSize(width: 390, height: 844)
        let containerView = UIView(frame: CGRect(origin: .zero, size: size))
        var posts: [AccessibilityPost] = []
        let accessibilityAdapter = FeedbackSettingsAccessibilityAdapter(
            containerView: containerView,
            sceneToScreenFrame: { $0 },
            postNotification: { notification, target in
                posts.append(AccessibilityPost(notification: notification, target: target))
            }
        )
        let scene = makeScene(
            store: try makeStore(initialState: stateWithBarracks(keepRemaining: 1, selectedLane: .right)),
            size: size,
            feedbackSettingsAccessibilityAdapter: accessibilityAdapter
        )

        #expect(try accessibilityElements(in: containerView).count == 1)
        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 3.0)

        #expect(scene.isConquestPopupVisibleForTesting)
        #expect(try accessibilityElements(in: containerView).isEmpty)
        #expect(posts.count == 1)
        let post = try #require(posts.first)
        #expect(post.notification == .screenChanged)
        #expect(post.target == nil)
    }

    @Test func tappingSpawnCreatesLiveCombatSoldierWithoutImmediateCityDamage() throws {
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 20))
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()

        #expect(scene.liveSoldierCountForTesting == 1)
        let keepMax = store.load().currentKeepMaxPower
        #expect(scene.keepRemainingPowerForTesting == keepMax)
        #expect(store.load().currentKeepRemainingPower == keepMax)
    }

    @Test func infantrySoldierVisualMatchesAssetName() throws {
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 20))
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()

        #expect(scene.firstLiveSoldierVisualMatchesForTesting(.infantry))
    }

    @Test func mismatchedSoldierTypeFallsBackToColorComparison() throws {
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 20))
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()

        // Infantry soldier body does not match archer asset name, so it falls back to color comparison
        #expect(!scene.firstLiveSoldierVisualMatchesForTesting(.archer))
    }

    @Test func cavalrySoldierVisualMatches() throws {
        let state = stateWithBuildings([.stable], keepRemaining: 20)
        let store = try makeStore(initialState: state)
        let scene = makeScene(store: store)

        scene.selectManualSoldierTypeForTesting(.cavalry)
        scene.spawnSoldierForTesting()

        #expect(scene.firstLiveSoldierVisualMatchesForTesting(.cavalry))
    }

    @Test func allSoldierTypesExposeTenAnimationFramesForEachAction() throws {
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 20))
        let scene = makeScene(store: store)

        for soldierType in SoldierType.allCases {
            for action in ["walk", "attack", "hit"] {
                let names = scene.animationFrameNamesForTesting(soldierType: soldierType, action: action)
                let expectedNames = (1...10).map {
                    "\(soldierType.rawValue)-\(action)-\(String(format: "%02d", $0))"
                }

                #expect(names == expectedNames)
            }
        }
    }

    @Test func spawnedSoldierStartsWalkingAnimation() throws {
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 50))
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()

        #expect(scene.firstLiveSoldierHasActionForTesting("soldierWalkAnimation"))
    }

    @Test("A static-fallback soldier (partial catalog) does not play transient animations on its fallback sprite")
    func staticFallbackSoldierSkipsTransientPlayback() throws {
        // Simulates the release-build failure mode where the catalog is
        // partially installed: `isAnimatedCanvas` is false (so the soldier is
        // built on the static-fallback path and sized to the static sprite's
        // intrinsic dimensions), but `soldierAnimationTextures(for:action:)`
        // still returns the real textures for whichever actions ARE complete.
        // Without gating `playSoldierAnimation` on `isAnimatedCanvas`, the
        // complete action's full-canvas textures would be installed on the
        // differently-sized static sprite, mixing fallback and animated
        // rendering. The gate must apply to transient playback (attack/hit),
        // not just walk.
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 50))
        let scene = makeScene(store: store)

        scene.forceStaticFallbackCanvasForTesting(soldierType: .infantry)
        scene.spawnSoldierForTesting()

        #expect(scene.firstLiveSoldierIsAnimatedCanvasForTesting == false)
        // Walk is already gated — this anchors the existing behavior.
        #expect(!scene.firstLiveSoldierHasActionForTesting("soldierWalkAnimation"))
        // Attack textures are still available (the texture cache is untouched
        // by the hook), so without the gate this would install the attack
        // animation on the static sprite.
        #expect(!scene.cachedSoldierAnimationTexturesForTesting(soldierType: .infantry, action: "attack").isEmpty)

        scene.triggerFirstLiveSoldierAnimationForTesting("attack")
        #expect(!scene.firstLiveSoldierHasActionForTesting("soldierAttackAnimation"))
        #expect(scene.soldierAttackAnimationTriggerCountForTesting == 0)

        scene.triggerFirstLiveSoldierAnimationForTesting("hit")
        #expect(!scene.firstLiveSoldierHasActionForTesting("soldierHitAnimation"))
        #expect(scene.soldierHitAnimationTriggerCountForTesting == 0)
    }

    @Test func cityDamageStartsAttackAnimation() throws {
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 50))
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 3.0)

        #expect(scene.soldierAttackAnimationTriggerCountForTesting > 0)
    }

    @Test("Attack triggers while an attack cycle is in flight are ignored, not restarted")
    func attackTriggerWhileAttackInFlightIsIgnored() throws {
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 50))
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()

        scene.triggerFirstLiveSoldierAnimationForTesting("attack")
        let countAfterFirst = scene.soldierAttackAnimationTriggerCountForTesting
        #expect(countAfterFirst == 1)
        #expect(scene.firstLiveSoldierHasActionForTesting("soldierAttackAnimation"))

        // A second attack trigger while the first cycle is still running must
        // not restart the sequence (which would pop it back to frame 1).
        scene.triggerFirstLiveSoldierAnimationForTesting("attack")
        #expect(scene.soldierAttackAnimationTriggerCountForTesting == countAfterFirst)
        #expect(scene.firstLiveSoldierHasActionForTesting("soldierAttackAnimation"))
    }

    @Test func remainingApprovedAttacksDoNotLayerProceduralFeedback() throws {
        for soldierType in [SoldierType.mage, .siege] {
            let buildingType = buildingTypeForSoldier(soldierType)
            let store = try makeStore(initialState: stateWithBuildings([buildingType], keepRemaining: 500))
            let scene = makeScene(store: store)

            scene.selectManualSoldierTypeForTesting(soldierType)
            scene.spawnSoldierForTesting()

            for _ in 0..<70 where scene.soldierAttackAnimationTriggerCountForTesting == 0 {
                scene.advanceCombatForTesting(deltaTime: 0.1)
            }

            #expect(scene.soldierAttackAnimationTriggerCountForTesting > 0)
            #expect(!scene.firstLiveSoldierHasActionForTesting("soldierAttackBodyFeedback"))
            #expect(visibleNodeCount(in: scene, namePrefix: "soldierAttackCue") == 0)
            #expect(visibleNodeCount(in: scene, namePrefix: "soldierAttackPose") == 0)
        }
    }

    @Test func approvedArcherAttackDoesNotLayerProceduralFeedback() throws {
        let store = try makeStore(initialState: stateWithBuildings([.archeryRange], keepRemaining: 500))
        let scene = makeScene(store: store)

        scene.selectManualSoldierTypeForTesting(.archer)
        scene.spawnSoldierForTesting()

        for _ in 0..<70 where scene.soldierAttackAnimationTriggerCountForTesting == 0 {
            scene.advanceCombatForTesting(deltaTime: 0.1)
        }

        #expect(scene.soldierAttackAnimationTriggerCountForTesting > 0)
        #expect(!scene.firstLiveSoldierHasActionForTesting("soldierAttackBodyFeedback"))
        #expect(visibleNodeCount(in: scene, namePrefix: "soldierAttackCue") == 0)
        #expect(visibleNodeCount(in: scene, namePrefix: "soldierAttackPose") == 0)
    }

    @Test func approvedInfantryAttackDoesNotLayerProceduralFeedback() throws {
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 500))
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()

        for _ in 0..<70 where scene.soldierAttackAnimationTriggerCountForTesting == 0 {
            scene.advanceCombatForTesting(deltaTime: 0.1)
        }

        #expect(scene.soldierAttackAnimationTriggerCountForTesting > 0)
        #expect(!scene.firstLiveSoldierHasActionForTesting("soldierAttackBodyFeedback"))
        #expect(visibleNodeCount(in: scene, namePrefix: "soldierAttackCue") == 0)
        #expect(visibleNodeCount(in: scene, namePrefix: "soldierAttackPose") == 0)
    }

    @Test func approvedCavalryAttackDoesNotLayerProceduralFeedback() throws {
        let store = try makeStore(initialState: stateWithBuildings([.stable], keepRemaining: 500))
        let scene = makeScene(store: store)

        scene.selectManualSoldierTypeForTesting(.cavalry)
        scene.spawnSoldierForTesting()

        for _ in 0..<70 where scene.soldierAttackAnimationTriggerCountForTesting == 0 {
            scene.advanceCombatForTesting(deltaTime: 0.1)
        }

        #expect(scene.soldierAttackAnimationTriggerCountForTesting > 0)
        #expect(!scene.firstLiveSoldierHasActionForTesting("soldierAttackBodyFeedback"))
        #expect(visibleNodeCount(in: scene, namePrefix: "soldierAttackCue") == 0)
        #expect(visibleNodeCount(in: scene, namePrefix: "soldierAttackPose") == 0)
    }

    @Test("Walk animation resumes after a transient attack/hit animation completes (spec §Runtime animation)")
    func walkAnimationResumesAfterTransientAnimationCompletes() throws {
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 50))
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()
        #expect(scene.firstLiveSoldierHasActionForTesting("soldierWalkAnimation"))

        scene.advanceCombatForTesting(deltaTime: 3.0)

        // An attack must have fired. The transient attack (or hit) animation
        // replaces the looping walk action — syncSoldierNodes no-ops the walk
        // restart while any transient action key is present.
        #expect(scene.soldierAttackAnimationTriggerCountForTesting > 0)
        #expect(scene.liveSoldierCountForTesting == 1)
        #expect(!scene.firstLiveSoldierHasActionForTesting("soldierWalkAnimation"))

        // Simulate the render loop finishing the transient animation: the
        // resume-walk closure fires and reinstalls the looping walk action.
        scene.completeFirstLiveSoldierTransientAnimationForTesting()

        #expect(scene.firstLiveSoldierHasActionForTesting("soldierWalkAnimation"))
    }

    @Test("Walk does not resume when transient animation clears with resumesWalk=false (spec §Runtime animation)")
    func walkDoesNotResumeWhenTransientAnimationClearsWithResumesWalkFalse() throws {
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 50))
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()
        #expect(scene.firstLiveSoldierHasActionForTesting("soldierWalkAnimation"))

        scene.advanceCombatForTesting(deltaTime: 3.0)

        // A transient attack/hit animation must have replaced the walk loop.
        #expect(scene.soldierAttackAnimationTriggerCountForTesting > 0)
        #expect(scene.liveSoldierCountForTesting == 1)
        #expect(!scene.firstLiveSoldierHasActionForTesting("soldierWalkAnimation"))

        // Mirror the production path for a fatal hit: the hit animation is
        // scheduled with `resumesWalk: !schedulesRemoval` → `false` when the
        // soldier is pending removal. The resume-walk guard must short-circuit
        // and leave the walk action uninstalled.
        scene.completeFirstLiveSoldierTransientAnimationForTesting(isAllowed: false)

        #expect(!scene.firstLiveSoldierHasActionForTesting("soldierWalkAnimation"))
    }

    @Test func towerDamageStartsHitAnimation() throws {
        let store = try makeStore(
            initialState: captainless(stateWithBarracks(
                keepRemaining: 100,
                cityNumberInCountry: 9,
                completedCityCount: 8
            ))
        )
        let scene = makeScene(store: store, combatSeed: 1)

        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 1.2)

        #expect(scene.soldierHitAnimationTriggerCountForTesting > 0)
    }

    @Test func towerDamageUsesAuthoredArcherHitWithoutProceduralOverlay() throws {
        let store = try makeStore(
            initialState: captainless(stateWithBuildings(
                [.archeryRange],
                keepRemaining: 100,
                cityNumberInCountry: 9,
                completedCityCount: 8
            ))
        )
        let scene = makeScene(store: store, combatSeed: 1)

        scene.selectManualSoldierTypeForTesting(.archer)
        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 1.2)

        #expect(scene.soldierHitAnimationTriggerCountForTesting > 0)
        #expect(!scene.anyVisibleSoldierHasActionForTesting("soldierHitBodyFeedback"))
        #expect(visibleNodeCount(in: scene, namePrefix: "soldierHitExpression") == 0)
        #expect(visibleNodeCount(in: scene, namePrefix: "soldierHitPosture") == 0)
    }

    @Test func towerDamageUsesAuthoredInfantryHitWithoutProceduralOverlay() throws {
        let store = try makeStore(
            initialState: captainless(stateWithBarracks(
                keepRemaining: 100,
                cityNumberInCountry: 9,
                completedCityCount: 8
            ))
        )
        let scene = makeScene(store: store, combatSeed: 1)

        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 1.2)

        #expect(scene.soldierHitAnimationTriggerCountForTesting > 0)
        #expect(!scene.anyVisibleSoldierHasActionForTesting("soldierHitBodyFeedback"))
        #expect(visibleNodeCount(in: scene, namePrefix: "soldierHitExpression") == 0)
        #expect(visibleNodeCount(in: scene, namePrefix: "soldierHitPosture") == 0)
    }

    @Test func towerDamageUsesAuthoredCavalryHitWithoutProceduralOverlay() throws {
        let store = try makeStore(
            initialState: stateWithBuildings(
                [.stable],
                keepRemaining: 100,
                cityNumberInCountry: 9,
                completedCityCount: 8
            )
        )
        let scene = makeScene(store: store, combatSeed: 1)

        scene.selectManualSoldierTypeForTesting(.cavalry)
        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 1.2)

        #expect(scene.soldierHitAnimationTriggerCountForTesting > 0)
        #expect(!scene.anyVisibleSoldierHasActionForTesting("soldierHitBodyFeedback"))
        #expect(visibleNodeCount(in: scene, namePrefix: "soldierHitExpression") == 0)
        #expect(visibleNodeCount(in: scene, namePrefix: "soldierHitPosture") == 0)
    }

    @Test func remainingApprovedHitsDoNotLayerProceduralFeedback() throws {
        for soldierType in [SoldierType.mage, .siege] {
            let store = try makeStore(
                initialState: stateWithBuildings(
                    [buildingTypeForSoldier(soldierType)],
                    keepRemaining: 100,
                    cityNumberInCountry: 9,
                    completedCityCount: 8
                )
            )
            let scene = makeScene(store: store, combatSeed: 1)

            scene.selectManualSoldierTypeForTesting(soldierType)
            scene.spawnSoldierForTesting()
            for _ in 0..<40 where scene.soldierHitAnimationTriggerCountForTesting == 0 {
                scene.advanceCombatForTesting(deltaTime: 0.1)
            }

            #expect(scene.soldierHitAnimationTriggerCountForTesting > 0)
            #expect(!scene.anyVisibleSoldierHasActionForTesting("soldierHitBodyFeedback"))
            #expect(visibleNodeCount(in: scene, namePrefix: "soldierHitExpression") == 0)
            #expect(visibleNodeCount(in: scene, namePrefix: "soldierHitPosture") == 0)
        }
    }

    @Test("Soldier animations use authored weighted playback timing")
    func soldierAnimationsUseAuthoredWeightedPlaybackTiming() throws {
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 50))
        let scene = makeScene(store: store)

        // Authored per-frame weights (each sums to 10) from
        // SoldierAnimationTiming / the July 12 full-animation spec. Pinning the
        // actual non-uniform arrays — not just the per-action total — means a
        // regression to uniform frame timing cannot satisfy this test.
        let attackWeights: [Double] = [1.10, 1.20, 1.30, 0.75, 0.70, 0.85, 1.00, 1.15, 1.10, 0.85]
        let hitWeights: [Double] = [0.90, 1.00, 1.10, 1.20, 1.20, 1.00, 0.95, 0.90, 0.90, 0.85]
        let walkWeights: [Double] = Array(repeating: 1.0, count: 10)

        func attackTotal(for type: SoldierType) -> Double {
            switch type {
            case .infantry, .cavalry: return 1.2
            case .archer, .mage: return 1.4
            case .siege: return 1.6
            }
        }

        func assertWeightedDurations(
            action: String,
            weights: [Double],
            total: Double,
            soldierType: SoldierType,
            expectUniform: Bool
        ) {
            let durations = scene.soldierAnimationFrameDurationsForTesting(
                action: action, soldierType: soldierType
            )
            #expect(durations.count == weights.count)
            let unit = total / weights.reduce(0, +)
            for index in 0..<weights.count {
                #expect(abs(durations[index] - weights[index] * unit) < 0.001)
            }
            let span = (durations.max() ?? 0) - (durations.min() ?? 0)
            if expectUniform {
                #expect(span < 0.001)
            } else {
                #expect(span > 0.001)
            }
            #expect(abs(durations.reduce(0, +) - total) < 0.001)
        }

        for type in SoldierType.allCases {
            assertWeightedDurations(
                action: "walk", weights: walkWeights, total: 1.0,
                soldierType: type, expectUniform: true
            )
            assertWeightedDurations(
                action: "attack", weights: attackWeights, total: attackTotal(for: type),
                soldierType: type, expectUniform: false
            )
            assertWeightedDurations(
                action: "hit", weights: hitWeights, total: 0.9,
                soldierType: type, expectUniform: false
            )
            #expect(abs(scene.soldierDelayedRemovalWaitDurationForTesting(soldierType: type) - 0.9) < 0.001)
        }
    }

    @Test("Hit animation interrupts an in-flight attack animation")
    func hitAnimationInterruptsInFlightAttackAnimation() throws {
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 50))
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()
        scene.triggerFirstLiveSoldierAnimationForTesting("attack")
        #expect(scene.firstLiveSoldierHasActionForTesting("soldierAttackAnimation"))

        scene.triggerFirstLiveSoldierAnimationForTesting("hit")
        #expect(!scene.firstLiveSoldierHasActionForTesting("soldierAttackAnimation"))
        #expect(scene.firstLiveSoldierHasActionForTesting("soldierHitAnimation"))
    }

    @Test("Attack trigger while a hit reaction is in flight is deferred, not interrupting the hit")
    func attackTriggerWhileHitInFlightIsDeferred() throws {
        // Cavalry is the only soldier type whose hit duration (0.9s) exceeds
        // its attack interval (1/1.15 ~= 0.87s). Without the suppression
        // guard in playSoldierAnimation, the next attack tick would land
        // mid-hit and the remove-all-transient-keys block would cut off the
        // authored hit reaction. The guard defers the attack: the hit cycle
        // finishes, resumes walk, and the next attack tick starts a fresh
        // attack cycle.
        let store = try makeStore(initialState: stateWithBuildings([.stable], keepRemaining: 50))
        let scene = makeScene(store: store)

        scene.selectManualSoldierTypeForTesting(.cavalry)
        scene.spawnSoldierForTesting()
        scene.triggerFirstLiveSoldierAnimationForTesting("hit")
        #expect(scene.firstLiveSoldierHasActionForTesting("soldierHitAnimation"))

        let hitCountBefore = scene.soldierHitAnimationTriggerCountForTesting
        let attackCountBefore = scene.soldierAttackAnimationTriggerCountForTesting

        scene.triggerFirstLiveSoldierAnimationForTesting("attack")

        // The hit reaction must still be playing — attack did not remove it.
        #expect(scene.firstLiveSoldierHasActionForTesting("soldierHitAnimation"))
        #expect(!scene.firstLiveSoldierHasActionForTesting("soldierAttackAnimation"))
        // The attack trigger was suppressed (counter unchanged).
        #expect(scene.soldierAttackAnimationTriggerCountForTesting == attackCountBefore)
        // The hit counter is also unchanged (we did not re-trigger hit).
        #expect(scene.soldierHitAnimationTriggerCountForTesting == hitCountBefore)
    }

    @Test("Attack trigger while a hit reaction is in flight is NOT suppressed for types where hit < attack interval")
    func attackTriggerWhileHitInFlightIsNotSuppressedForNonCavalryTypes() throws {
        // Symmetric counterpart to `attackTriggerWhileHitInFlightIsDeferred`.
        // For every non-cavalry type, hit duration (0.9s) is shorter than the
        // per-type attack interval, so `hitDurationExceedsAttackInterval` is
        // false and the suppression guard must NOT fire — an attack trigger
        // replaces the in-flight hit animation rather than deferring to it.
        // This guards the type discrimination in the guard across all four
        // non-cavalry types: if the gate were accidentally widened to all
        // types, every type below would stop visually attacking (infantry
        // ~72% of the time, per the CLAUDE.md cadence note). Parameterized
        // over all four non-cavalry types as cheap insurance against a future
        // comparison inversion that only breaks one type's branch.
        for soldierType in [SoldierType.infantry, .archer, .mage, .siege] {
            let buildingType = buildingTypeForSoldier(soldierType)
            let store = try makeStore(initialState: stateWithBuildings([buildingType], keepRemaining: 50))
            let scene = makeScene(store: store)

            scene.selectManualSoldierTypeForTesting(soldierType)
            scene.spawnSoldierForTesting()
            scene.triggerFirstLiveSoldierAnimationForTesting("hit")
            #expect(scene.firstLiveSoldierHasActionForTesting("soldierHitAnimation"))

            let attackCountBefore = scene.soldierAttackAnimationTriggerCountForTesting

            scene.triggerFirstLiveSoldierAnimationForTesting("attack")

            // The attack replaced the hit — hit is no longer playing.
            #expect(!scene.firstLiveSoldierHasActionForTesting("soldierHitAnimation"))
            #expect(scene.firstLiveSoldierHasActionForTesting("soldierAttackAnimation"))
            // The attack counter incremented (not suppressed).
            #expect(scene.soldierAttackAnimationTriggerCountForTesting > attackCountBefore)
        }
    }

    @Test("Tower-generated hit arms the full 0.9s countdown and stays suppressed past the cavalry attack interval")
    func towerGeneratedHitArmsFullDurationAndStaysSuppressedPastAttackInterval() throws {
        // Regression for the reorder of `decrementSoldierHitAnimationRemaining`
        // before `combat.tick` in `advanceCombat`. With the old order, a tower
        // hit armed the timer at 0.9s in `applyCombatResult` and then
        // `decrementSoldierHitAnimationRemaining(deltaTime:)` immediately
        // subtracted the tick's deltaTime, so the timer held `0.9 - deltaTime`
        // and the hit animation played short by one frame every time. With the
        // fix, the decrement runs before the tick, so a timer armed this tick
        // keeps the full 0.9s and is first reduced on the next tick.
        //
        // Cavalry is the type where this matters most: hit duration (0.9s) >
        // attack interval (~0.87s), so the attack-while-hit suppression guard
        // relies on the countdown staying positive past 0.87s. With the old
        // order the timer would reach zero at 0.8s elapsed (before the attack
        // interval) and the guard would lift early; with the fix it reaches
        // zero at 0.9s (after the attack interval), matching the authored hit.
        // City 1: tower damage is 2, so after defense (1) and lane multiplier
        // the cavalry takes 1 damage and survives with 8 HP — the timer must
        // remain armed on a LIVING soldier so `firstLiveSoldierIDForTesting`
        // can still resolve it. (City 9's tower one-shots a level-1 cavalry,
        // which would remove the soldier from `combat.soldiers` and make the
        // accessor return nil.) `keepRemaining: 500` keeps the city alive
        // across the full 0.9s window so `stageStatus` stays `.battleActive`.
        let store = try makeStore(
            initialState: stateWithBuildings(
                [.stable],
                gold: 100,
                keepRemaining: 500,
                cityNumberInCountry: 1,
                completedCityCount: 0,
                selectedLane: .right
            )
        )
        let scene = makeScene(store: store, combatSeed: 1)

        scene.selectManualSoldierTypeForTesting(.cavalry)
        scene.spawnSoldierForTesting()

        // Advance in 0.1s steps until the tower fires and lands a hit. The
        // tower interval is 1.25s, so only one tower shot can land during this
        // window; subsequent steps won't re-arm the timer.
        var hitCount = 0
        var stepsSinceSpawn = 0
        while hitCount == 0 && stepsSinceSpawn < 30 {
            scene.advanceCombatForTesting(deltaTime: 0.1)
            hitCount = scene.soldierHitAnimationTriggerCountForTesting
            stepsSinceSpawn += 1
        }
        #expect(hitCount > 0, "Tower should have hit the cavalry soldier within 3.0s")

        // Immediately after the tower-hit tick, the timer must hold the full
        // authored 0.9s — not 0.9s minus the 0.1s tick step (the old-order bug).
        let remainingAfterHit = try #require(scene.firstLiveSoldierHitAnimationRemainingForTesting)
        #expect(abs(remainingAfterHit - 0.9) < 0.001)

        // Advance 0.8s more (eight 0.1s steps). The timer should read ~0.1s,
        // i.e. suppression is still active. This window spans the cavalry
        // attack interval (~0.87s): at 0.8s elapsed the timer is 0.1 > 0, and
        // it stays positive through 0.87s. With the old order the timer would
        // have been armed at 0.8s and would already be zero here.
        for _ in 0..<8 {
            scene.advanceCombatForTesting(deltaTime: 0.1)
        }
        let remainingAtEightTenths = scene.firstLiveSoldierHitAnimationRemainingForTesting
        #expect(remainingAtEightTenths.map { $0 > 0 } == true,
                "Hit suppression must still be active 0.8s after the tower hit")
        if let remaining = remainingAtEightTenths {
            #expect(abs(remaining - 0.1) < 0.001)
        }

        // One more 0.1s step reaches the authored 0.9s; the timer lifts and
        // suppression ends.
        scene.advanceCombatForTesting(deltaTime: 0.1)
        #expect(scene.firstLiveSoldierHitAnimationRemainingForTesting == nil)
    }

    @Test("Combat-tick-driven cavalry attack during a tower-hit reaction is suppressed end-to-end")
    func cavalryAttackTickDuringTowerHitReactionIsSuppressed() throws {
        // End-to-end integration test closing the gap between
        // `attackTriggerWhileHitInFlightIsDeferred` (guard tested via direct
        // trigger) and `towerGeneratedHitArmsFullDurationAndStaysSuppressedPastAttackInterval`
        // (countdown timing tested but not attack suppression). This test
        // verifies the full path: `BattleCombatState.tick` produces attack IDs
        // for a cavalry soldier while its hit-reaction countdown is armed by a
        // real tower hit, `applyCombatResult` routes them through
        // `playSoldierAttackFeedback` → `playSoldierAnimation`, and the guard
        // defers them — the attack animation counter must not increment while
        // the countdown is positive, even though the combat tick is still
        // dealing city damage (proving attack IDs are being produced).
        //
        // City 1: tower damage 2, cavalry takes 1 damage per shot (survives
        // 9 hits). keepRemaining 500 keeps the city alive across the
        // test window so stageStatus stays .battleActive. The tower re-fires
        // every 1.25s, continuously re-arming the 0.9s hit timer — since
        // cavalry's attack interval (~0.87s) < hit duration (0.9s), every
        // attack during sustained tower fire is suppressed. This is the
        // real-world cavalry scenario: the soldier keeps dealing damage
        // (combat tick) but visually stays in the hit reaction.
        let store = try makeStore(
            initialState: stateWithBuildings(
                [.stable],
                gold: 100,
                keepRemaining: 500,
                cityNumberInCountry: 1,
                completedCityCount: 0,
                selectedLane: .right
            )
        )
        let scene = makeScene(store: store, combatSeed: 1)

        scene.selectManualSoldierTypeForTesting(.cavalry)
        scene.spawnSoldierForTesting()

        // Advance until the cavalry has reached attack range and landed at
        // least one attack tick. This proves the cavalry CAN attack (the
        // counter increments), so a flat counter later is meaningful — it
        // means suppression, not "never could attack."
        var steps = 0
        while scene.soldierAttackAnimationTriggerCountForTesting == 0 && steps < 40 {
            scene.advanceCombatForTesting(deltaTime: 0.1)
            steps += 1
        }
        #expect(scene.soldierAttackAnimationTriggerCountForTesting > 0,
                "Cavalry should reach attack range and attack within 4.0s")

        // Advance until the next tower hit lands. The tower interval is 1.25s,
        // so this completes within one tower cycle. The cavalry is now in
        // attack range AND in a hit reaction (countdown armed at 0.9s).
        let hitCountBefore = scene.soldierHitAnimationTriggerCountForTesting
        steps = 0
        while scene.soldierHitAnimationTriggerCountForTesting == hitCountBefore && steps < 20 {
            scene.advanceCombatForTesting(deltaTime: 0.1)
            steps += 1
        }
        #expect(scene.soldierHitAnimationTriggerCountForTesting > hitCountBefore,
                "Tower should hit the cavalry within 2.0s")
        #expect(scene.firstLiveSoldierHitAnimationRemainingForTesting != nil,
                "Hit-reaction countdown must be armed after the tower hit")

        // During sustained tower fire, the hit-reaction countdown is
        // continuously armed. The combat tick still produces attack IDs
        // (city power must decrease — the soldier is in range and dealing
        // damage), but the animation guard suppresses every attack trigger.
        // Advance 1.5s (spanning one full tower cycle + extra) to verify
        // the attack counter stays flat while city damage accumulates.
        let attackCountAtHit = scene.soldierAttackAnimationTriggerCountForTesting
        let keepPowerAtHit = scene.keepRemainingPowerForTesting
        for _ in 0..<15 {
            scene.advanceCombatForTesting(deltaTime: 0.1)
        }
        #expect(scene.soldierAttackAnimationTriggerCountForTesting == attackCountAtHit,
                "Combat-tick attack triggers during sustained hit reactions must be suppressed")
        #expect(scene.keepRemainingPowerForTesting < keepPowerAtHit,
                "Combat tick must still deal city damage (attack IDs are produced, only the animation is suppressed)")
        #expect(scene.firstLiveSoldierHitAnimationRemainingForTesting != nil,
                "Hit-reaction countdown must still be armed (tower re-hit within the window)")
    }

    @Test("Hit-reaction countdown tracks real frame time during stalls, matching the SKAction clock")
    func hitReactionCountdownTracksRealFrameTimeDuringStalls() throws {
        // The per-soldier hit-reaction countdown is the attack suppression gate
        // for cavalry (hit duration 0.9s > attack interval ~0.87s). It must
        // track the SAME clock as the hit SKAction — real frame time — so that
        // the countdown lifts exactly when the visual hit pose finishes.
        //
        // `BattleCombatState.tick` clamps `rawDeltaTime` to
        // `configuration.maxDeltaTime` (0.25s for `.live`), but SpriteKit does
        // NOT clamp SKAction deltas: during a render stall longer than the hit
        // duration, the hit SKAction advances by the full frame interval and
        // completes, while a clamped countdown would still report time
        // remaining and falsely suppress the next attack trigger even though no
        // hit pose is playing. The combat tick's attack cooldown is also
        // clamped, so lifting the countdown early cannot produce an attack ID
        // the combat tick hasn't authorized.
        //
        // This test arms the countdown with a real tower hit, then drives a
        // single 1.0s step (exceeding both maxDeltaTime and the 0.9s hit
        // duration) via `advanceCombatSingleStepForTesting`. The countdown must
        // decrement by the full 1.0s and lift (be removed), matching the
        // SKAction completing — not cling to 0.65s as a clamped countdown would.
        let store = try makeStore(
            initialState: stateWithBuildings(
                [.stable],
                gold: 100,
                keepRemaining: 500,
                cityNumberInCountry: 1,
                completedCityCount: 0,
                selectedLane: .right
            )
        )
        let scene = makeScene(store: store, combatSeed: 1)

        scene.selectManualSoldierTypeForTesting(.cavalry)
        scene.spawnSoldierForTesting()

        // Step in 0.1s chunks (under maxDeltaTime) until the tower lands a
        // hit and arms the 0.9s countdown.
        var hitCount = 0
        var stepsSinceSpawn = 0
        while hitCount == 0 && stepsSinceSpawn < 30 {
            scene.advanceCombatForTesting(deltaTime: 0.1)
            hitCount = scene.soldierHitAnimationTriggerCountForTesting
            stepsSinceSpawn += 1
        }
        #expect(hitCount > 0, "Tower should have hit the cavalry soldier within 3.0s")

        let remainingBeforeStall = try #require(scene.firstLiveSoldierHitAnimationRemainingForTesting)
        #expect(abs(remainingBeforeStall - 0.9) < 0.001)

        // Single 1.0s step — exceeds maxDeltaTime (0.25s) AND the hit duration
        // (0.9s). The countdown must decrement by the full 1.0s and lift.
        scene.advanceCombatSingleStepForTesting(deltaTime: 1.0)

        #expect(scene.firstLiveSoldierHitAnimationRemainingForTesting == nil,
                "Hit-reaction countdown must lift after a stall exceeding the hit duration (SKAction has finished)")
    }

    @Test("Formation rows are clamped to the battlefield floor during long battles")
    func formationRowsClampToBattlefieldFloorDuringLongBattles() throws {
        // Building-driven spawns have no global live-soldier cap, so formation
        // slots grow without bound. Without compression, enough same-lane soldiers
        // at the attack position would push back rows below the battlefield
        // frame, where they keep dealing combat damage with invisible bodies
        // and HP bars. `syncSoldierNodes` compresses rows within the available depth
        // and keeps each root at or above `battlefieldLayout.frame.minY`, so
        // overflow soldiers do not all stack at the bottom edge.
        //
        // This test fills the roster with 25 buildings (5 of each type) and
        // drives ~200s of building spawns via single-step stalls (each call
        // advances 10s of building production but only 0.25s of clamped combat,
        // so soldiers reach the attack position and accumulate). With enough
        // soldiers, unclamped formation rows would extend past the floor.
        let buildingTypes: [BuildingType] = [
            .barracks, .barracks, .barracks, .barracks, .barracks,
            .archeryRange, .archeryRange, .archeryRange, .archeryRange, .archeryRange,
            .stable, .stable, .stable, .stable, .stable,
            .mageTower, .mageTower, .mageTower, .mageTower, .mageTower,
            .siegeWorkshop, .siegeWorkshop, .siegeWorkshop, .siegeWorkshop, .siegeWorkshop
        ]
        // City 15's authored Keep holds 773,076 of the 901,921 city HP (the Tower,
        // Barracks and Gates hold the rest). The Keep starts at that full authored
        // maximum, so the roster can grow for the full 200s without a conquest
        // tearing it down.
        let city15Layout = Country1CityCatalog.definition(for: 15).siegeLayout
        let city15KeepMax = city15Layout.maxPowerAllocation(
            totalBudget: KingdomGameState.cityMaxPower(for: 15)
        )[city15Layout.keepObjective.id, default: 0]
        let store = try makeStore(
            initialState: stateWithBuildings(
                buildingTypes,
                gold: 100,
                keepRemaining: city15KeepMax,
                cityNumberInCountry: 15,
                completedCityCount: 14
            )
        )
        let scene = makeScene(store: store, combatSeed: 1)

        // 20 single-step stalls of 10s each: 200s of building spawns, 5s of
        // clamped combat — enough for soldiers to reach the attack position
        // and for the roster to grow well past the formation's visible depth.
        for _ in 0..<20 {
            scene.advanceCombatSingleStepForTesting(deltaTime: 10.0)
        }

        guard let battlefieldFrame = scene.battleChromeLayoutForTesting?.battlefieldFrame else {
            Issue.record("Battlefield layout must be visible")
            return
        }

        let placements = scene.soldierLanePlacementsForTesting
        #expect(placements.count > 50,
                "Test must produce enough soldiers to overflow unclamped formation rows")

        let floorY = battlefieldFrame.minY
        let floorCount = placements.filter { $0.nodePosition.y <= floorY + 0.5 }.count
        #expect(floorCount * 4 < placements.count)
        for placement in placements {
            #expect(placement.nodePosition.y >= floorY,
                    "Soldier y (\(placement.nodePosition.y)) below floor (\(floorY)), lane \(placement.lane)")
        }
        var hpFrames: [CGRect] = []
        scene.enumerateChildNodes(withName: "//normal-soldier") { node, _ in
            if let bar = node.children.compactMap({ $0 as? SKShapeNode }).first(where: { $0.zPosition == 2 }),
               let path = bar.path {
                let bounds = path.boundingBox
                let min = node.convert(CGPoint(x: bounds.minX, y: bounds.minY), to: scene)
                let max = node.convert(CGPoint(x: bounds.maxX, y: bounds.maxY), to: scene)
                hpFrames.append(CGRect(x: min.x, y: min.y, width: max.x - min.x, height: max.y - min.y))
            }
        }
        #expect(hpFrames.count >= placements.count)
        let outside = hpFrames.filter { !battlefieldFrame.contains($0) }
        #expect(
            outside.isEmpty,
            "HP bars outside \(battlefieldFrame): \(outside)"
        )
    }

    @Test("Soldier animation textures are memoized across calls (no per-call UIImage lookup)")
    func soldierAnimationTexturesAreCachedAndReusedAcrossCalls() throws {
        let store = try makeStore(initialState: stateWithBuildings([.mageTower], keepRemaining: 20))
        let scene = makeScene(store: store)

        #expect(scene.soldierAnimationTextureCacheEntryCountForTesting == 0)

        // First call resolves and caches the walk textures.
        let first = scene.cachedSoldierAnimationTexturesForTesting(soldierType: .mage, action: "walk")
        #expect(first.count == 10)
        #expect(scene.soldierAnimationTextureCacheEntryCountForTesting == 1)

        // Second call must return the *same* SKTexture instances (cache hit).
        let second = scene.cachedSoldierAnimationTexturesForTesting(soldierType: .mage, action: "walk")
        #expect(second.count == first.count)
        for (a, b) in zip(first, second) {
            #expect(a === b)
        }
        // No duplicate cache entry was inserted.
        #expect(scene.soldierAnimationTextureCacheEntryCountForTesting == 1)

        // Authored attack playback has its own cached texture entry.
        let attack = scene.cachedSoldierAnimationTexturesForTesting(soldierType: .mage, action: "attack")
        #expect(attack.count == first.count)
        for (attackTexture, walkTexture) in zip(attack, first) {
            #expect(attackTexture !== walkTexture)
        }
        #expect(scene.soldierAnimationTextureCacheEntryCountForTesting == 2)

        let hit = scene.cachedSoldierAnimationTexturesForTesting(soldierType: .mage, action: "hit")
        for ((hitTexture, walkTexture), attackTexture) in zip(zip(hit, first), attack) {
            #expect(hitTexture !== walkTexture)
            #expect(hitTexture !== attackTexture)
        }
        #expect(scene.soldierAnimationTextureCacheEntryCountForTesting == 3)
    }

    @Test("Battle HUD mounts one authored icon for each soldier type")
    func battleHUDMountsOneIconPerSoldierType() throws {
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 20))
        let scene = makeScene(store: store)

        #expect(scene.battleHUDForTesting.visualMedallionCountForTesting == SoldierType.allCases.count)
        for soldierType in SoldierType.allCases {
            #expect(visibleSpriteCount(
                in: scene,
                named: "battleMedallionIcon-\(soldierType.rawValue)"
            ) == 1)
        }
    }

    @Test("Every approved soldier trio uses pairwise-distinct action frames")
    func approvedSoldierTriosUsePairwiseDistinctFrameIdentity() throws {
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 20))
        let scene = makeScene(store: store)

        for soldierType in SoldierType.allCases {
            let walkTextures = scene.cachedSoldierAnimationTexturesForTesting(
                soldierType: soldierType,
                action: "walk"
            )
            let attackTextures = scene.cachedSoldierAnimationTexturesForTesting(
                soldierType: soldierType,
                action: "attack"
            )
            let hitTextures = scene.cachedSoldierAnimationTexturesForTesting(
                soldierType: soldierType,
                action: "hit"
            )

            #expect(attackTextures.count == walkTextures.count)
            #expect(hitTextures.count == walkTextures.count)
            for ((walkTexture, attackTexture), hitTexture) in zip(
                zip(walkTextures, attackTextures),
                hitTextures
            ) {
                #expect(walkTexture !== attackTexture)
                #expect(walkTexture !== hitTexture)
                #expect(attackTexture !== hitTexture)
            }
        }
    }

    @Test func approvedArcherFullCanvasPreservesLogicalBodyHeight() throws {
        let store = try makeStore(initialState: stateWithBuildings([.archeryRange], keepRemaining: 50))
        let scene = makeScene(store: store)

        scene.selectManualSoldierTypeForTesting(.archer)
        scene.spawnSoldierForTesting()

        let bodyFrame = try #require(scene.firstLiveSoldierBodyFrameForTesting)
        let expectedFrameSize = SoldierAnimationGeometry(type: .archer).frameSize(
            forBodyHeight: scene.soldierTargetHeightForTesting
        )

        #expect(abs(bodyFrame.width - expectedFrameSize.width) < 0.001)
        #expect(abs(bodyFrame.height - expectedFrameSize.height) < 0.001)
    }

    @Test func approvedArcherHPBarUsesLogicalBodyTopInsteadOfCanvasTop() throws {
        let store = try makeStore(initialState: stateWithBuildings([.archeryRange], keepRemaining: 50))
        let scene = makeScene(store: store)

        scene.selectManualSoldierTypeForTesting(.archer)
        scene.spawnSoldierForTesting()

        let hpBarFrame = try #require(scene.firstLiveSoldierHPBarFrameForTesting)
        let placement = try #require(scene.soldierLanePlacementsForTesting.first)
        // The logical body top is the silhouette top (bodyRegion.maxY * frameSize),
        // not the requested body height: the regenerated frames have a
        // transparent margin below the feet, so the silhouette top sits above
        // the body-height offset from the feet.
        let geometry = SoldierAnimationGeometry(type: .archer)
        let frameSize = geometry.frameSize(forBodyHeight: scene.soldierTargetHeightForTesting)
        let logicalBodyTop = placement.nodePosition.y + geometry.logicalBodyFrame(frameSize: frameSize).maxY
        let gap = hpBarFrame.minY - logicalBodyTop

        #expect(gap >= 0)
        #expect(gap <= 1.5)
    }

    @Test func animatedSoldierFeetAlignWithLaneBaseline() throws {
        let store = try makeStore(initialState: stateWithBuildings([.archeryRange], keepRemaining: 50))
        let scene = makeScene(store: store)

        scene.selectManualSoldierTypeForTesting(.archer)
        scene.spawnSoldierForTesting()

        let placement = try #require(scene.soldierLanePlacementsForTesting.first)
        let gatePoint = try #require(scene.castleGatePointForTesting(lane: placement.lane))
        let geometry = SoldierAnimationGeometry(type: .archer)
        let frameSize = geometry.frameSize(forBodyHeight: scene.soldierTargetHeightForTesting)
        let footMargin = geometry.bodyRegion.minY * frameSize.height
        // The visible feet (root + scaled bottom margin) must sit on the lane
        // baseline, not float above it by the transparent foot margin.
        let feetY = placement.nodePosition.y + footMargin
        #expect(abs(feetY - gatePoint.y) < 0.5)
    }

    @Test func towerShotTargetsSoldierBodyCenter() throws {
        let store = try makeStore(initialState: stateWithBuildings([.archeryRange], keepRemaining: 50))
        let scene = makeScene(store: store)

        scene.selectManualSoldierTypeForTesting(.archer)
        scene.spawnSoldierForTesting()

        let placement = try #require(scene.soldierLanePlacementsForTesting.first)
        let geometry = SoldierAnimationGeometry(type: .archer)
        let frameSize = geometry.frameSize(forBodyHeight: scene.soldierTargetHeightForTesting)
        let bodyCenterY = placement.nodePosition.y + geometry.logicalBodyFrame(frameSize: frameSize).midY

        let target = try #require(scene.firstLiveSoldierTowerShotTargetForTesting)
        #expect(abs(target.y - bodyCenterY) < 0.5)
        // The target must not be the raw root position (which sits below the
        // body after the foot-margin offset is applied).
        #expect(abs(target.y - placement.nodePosition.y) > 1)
    }

    @Test func towerShotTargetsScaledFormationSoldierBodyCenters() throws {
        // A lane holding more than one soldier scales every formation root
        // (at most 0.8, less when bodies are wide). The tower-shot endpoint
        // must convert the logical body midpoint through that root
        // transform — adding the unscaled midpoint instead would float the
        // endpoint visibly above the rendered body center (HPA-812 final
        // review: ~8pt for infantry, ~19pt for siege at this size).
        for (soldierType, buildings) in [
            (SoldierType.infantry, [BuildingType.barracks]),
            (.siege, [.siegeWorkshop])
        ] {
            let store = try makeStore(initialState: stateWithBuildings(
                buildings,
                gold: 100,
                keepRemaining: 1_000,
                selectedLane: .center
            ))
            let scene = makeScene(store: store)
            scene.selectManualSoldierTypeForTesting(soldierType)
            scene.spawnManualSoldiersDirectlyForTesting(4)

            let targets = scene.liveSoldierTowerShotTargetsForTesting
            #expect(targets.count == 4)
            #expect(targets.allSatisfy { $0.type == soldierType })
            // The scenario is only meaningful when the roots really are
            // scaled down; pin that precondition explicitly.
            #expect(targets.allSatisfy { $0.rootScale < 1 })

            let geometry = SoldierAnimationGeometry(type: soldierType)
            let frameSize = geometry.frameSize(forBodyHeight: scene.soldierTargetHeightForTesting)
            let bodyFrame = geometry.logicalBodyFrame(frameSize: frameSize)
            for entry in targets {
                // Root-local midpoint converted through the root's scale:
                // root.position + scale * midpoint in this origin-aligned
                // flat layer hierarchy.
                let scaled = CGPoint(
                    x: entry.rootPosition.x + bodyFrame.midX * entry.rootScale,
                    y: entry.rootPosition.y + bodyFrame.midY * entry.rootScale
                )
                #expect(abs(entry.target.x - scaled.x) < 0.5)
                #expect(abs(entry.target.y - scaled.y) < 0.5)
                // And it must not be the unscaled midpoint — that is the
                // regression this test guards.
                let unscaled = CGPoint(
                    x: entry.rootPosition.x + bodyFrame.midX,
                    y: entry.rootPosition.y + bodyFrame.midY
                )
                #expect(hypot(entry.target.x - unscaled.x, entry.target.y - unscaled.y) > 1)
            }
        }
    }

    @Test func infantryAttackFramesKeepMotionInsideCanvasInset() throws {
        let fullCanvas = CGRect(x: 0, y: 0, width: 1, height: 1)

        for frameIndex in 1...10 {
            let imageName = "infantry-attack-\(String(format: "%02d", frameIndex))"
            let image = try #require(UIImage(named: imageName))
            let cgImage = try #require(image.cgImage)
            let bounds = try #require(opaquePixelBounds(in: image))
            let cropMinX = Int(floor(fullCanvas.minX * CGFloat(cgImage.width)))
            let cropMaxX = Int(ceil(fullCanvas.maxX * CGFloat(cgImage.width)))

            #expect(bounds.minX - cropMinX >= 3)
            #expect(cropMaxX - bounds.maxXExclusive >= 3)
        }
    }

    @Test("Living Kingdom fortress assets match the shipping display envelope")
    func livingKingdomFortressAssetsMatchContract() throws {
        for family in ["frontier", "ember", "arcane", "royal"] {
            for stage in ["intact", "damaged", "breached", "conquered"] {
                let name = "lk-city-\(family)-\(stage)"
                let image = try #require(UIImage(named: name))
                let cgImage = try #require(image.cgImage)
                let bounds = try #require(opaquePixelBounds(in: image))

                #expect(cgImage.width == 512)
                #expect(cgImage.height == 540)

                let widthRatio = Double(bounds.width) / 512.0
                let heightRatio = Double(bounds.height) / 540.0
                let bottomGapRatio = Double(540 - bounds.maxYExclusive) / 540.0
                let center = Double(bounds.minX + bounds.maxXExclusive) / 2.0

                #expect((0.72...0.80).contains(widthRatio))
                #expect((0.94...0.98).contains(heightRatio))
                #expect((0.015...0.030).contains(bottomGapRatio))
                #expect(abs(center - 256.0) <= 10.24)
                if stage == "intact" {
                    #expect(widthRatio <= 0.78)
                }
            }
        }
    }

    @Test("Living Kingdom transition effects match the shipping FX contract")
    func livingKingdomTransitionEffectsMatchContract() throws {
        for sequence in ["breach", "collapse"] {
            for frameIndex in 1...6 {
                let name = "lk-fx-\(sequence)-\(String(format: "%02d", frameIndex))"
                let image = try #require(UIImage(named: name))
                let cgImage = try #require(image.cgImage)
                #expect(cgImage.width == 512)
                #expect(cgImage.height == 512)
            }
        }

        // Nonterminal FX frames are transparent overlays: each must carry at
        // least one transparent pixel so it cannot fully occlude the battlefield
        // during the transition. Frame 06 is fully transparent so the static
        // breached/conquered fortress owns the terminal appearance.
        for sequence in ["breach", "collapse"] {
            for frameIndex in 1...5 {
                let name = "lk-fx-\(sequence)-\(String(format: "%02d", frameIndex))"
                let image = try #require(UIImage(named: name))
                #expect(hasTransparentPixel(in: image), "\(name) must not be fully opaque")
            }
        }

        for name in ["lk-fx-breach-06", "lk-fx-collapse-06"] {
            let image = try #require(UIImage(named: name))
            #expect(opaquePixelBounds(in: image) == nil)
        }
    }

    @Test("Living Kingdom map overlays match the canonical registration canvas")
    func livingKingdomMapOverlaysMatchContract() throws {
        let expected: [(String, CGSize)] = [
            ("lk-map-secured-city", CGSize(width: 96, height: 96)),
            ("lk-map-caravan", CGSize(width: 128, height: 64)),
            ("lk-map-route-6-7-worn", CGSize(width: 192, height: 192)),
            ("lk-map-route-6-7-repaired", CGSize(width: 192, height: 192))
        ]

        for (name, size) in expected {
            let image = try #require(UIImage(named: name))
            let cgImage = try #require(image.cgImage)
            #expect(cgImage.width == Int(size.width), "\(name) width")
            #expect(cgImage.height == Int(size.height), "\(name) height")
            // Map overlays are transparent per the asset contract; an opaque
            // replacement would cover the shipping map when HPA-478 consumes the pack.
            #expect(hasTransparentPixel(in: image), "\(name) must not be fully opaque")
        }
    }

    @Test("Living Kingdom battlefield treatments match the shipping backdrop canvas")
    func livingKingdomBattlefieldTreatmentsMatchContract() throws {
        for name in ["lk-battlefield-ember", "lk-battlefield-arcane", "lk-battlefield-royal"] {
            let image = try #require(UIImage(named: name))
            let cgImage = try #require(image.cgImage)
            #expect(cgImage.width == 864)
            #expect(cgImage.height == 1821)
            // Battlefield treatments are transparent overlays composited over the
            // opaque backdrop; an opaque replacement would hide the shipping battlefield.
            #expect(hasTransparentPixel(in: image), "\(name) must not be fully opaque")
        }
    }

    private var actorAnimationCases: [(prefix: String, type: SoldierType)] {
        SoldierType.allCases.map { ($0.rawValue, $0) }
            + [("siege-guard", .infantry), ("vanguard-captain", .infantry)]
    }

    @Test("Captain portrait and Rally accent ship transparent 128px art")
    func captainAndRallyAssetsAreInstalled() throws {
        for name in ["vanguard-captain-portrait", "rally-protection-accent"] {
            let image = try #require(UIImage(named: name))
            let cgImage = try #require(image.cgImage)
            #expect(cgImage.width == 128 && cgImage.height == 128)
            #expect(opaquePixelBounds(in: image) != nil)
            #expect(hasTransparentPixel(in: image))
        }
    }

    @Test("Every authored actor animation trio is complete and uses 128px frames")
    func allSoldierAnimationFramesAreInstalled() {
        for actor in actorAnimationCases {
            var frameCount = 0
            for action in SoldierAnimationAction.allCases {
                for index in 1...SoldierAnimationTiming.frameCount {
                    let name = "\(actor.prefix)-\(action.rawValue)-\(String(format: "%02d", index))"
                    guard let image = UIImage(named: name), let cgImage = image.cgImage else {
                        Issue.record("Missing actor animation frame: \(name)")
                        continue
                    }
                    #expect(cgImage.width == 128 && cgImage.height == 128, "\(name)")
                    frameCount += 1
                }
            }
            #expect(frameCount == 30)
        }
    }

    @Test("Walk silhouettes match each actor's logical body size and foot margin")
    func actorWalkBoundsMatchBodyGeometry() throws {
        for actor in actorAnimationCases {
            var minX = 128
            var minY = 128
            var maxX = 0
            var maxY = 0
            for index in 1...10 {
                let name = "\(actor.prefix)-walk-\(String(format: "%02d", index))"
                let image = try #require(UIImage(named: name))
                let bounds = try #require(opaquePixelBounds(in: image))
                minX = min(minX, bounds.minX)
                minY = min(minY, bounds.minY)
                maxX = max(maxX, bounds.maxXExclusive)
                maxY = max(maxY, bounds.maxYExclusive)
            }
            let region = SoldierAnimationGeometry(type: actor.type).bodyRegion
            #expect(abs(CGFloat(maxX - minX) - region.width * 128) <= 2, "\(actor.prefix) width")
            #expect(abs(CGFloat(maxY - minY) - region.height * 128) <= 2, "\(actor.prefix) height")
            // Pixel rows start at the top; the geometry's foot margin starts at the bottom.
            #expect(abs(CGFloat(128 - maxY) - region.minY * 128) <= 2, "\(actor.prefix) foot margin")
        }
    }

    @Test("A tower-killed soldier is routed through the delayed-removal scheduler")
    func towerKilledSoldierSchedulesDelayedRemoval() throws {
        // City 9 with maxed-out city power so a tower shot is lethal. The combat
        // seed is fixed so the tower targets the spawned soldier's lane.
        let store = try makeStore(
            initialState: captainless(stateWithBarracks(
                keepRemaining: 100,
                cityNumberInCountry: 9,
                completedCityCount: 8
            ))
        )
        let scene = makeScene(store: store, combatSeed: 1)

        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 1.2)

        // Killed soldiers must be in pendingAnimatedRemovalSoldierIDs — this is
        // the regression for the removed dead branch (killed ⊆ damaged is a
        // structural invariant, so the death flow rides entirely on the
        // schedulesRemoval path inside playSoldierHitFeedback).
        #expect(!scene.pendingAnimatedRemovalSoldierIDsForTesting.isEmpty)
    }

    @Test func manualSelectorChangesSpawnedSoldierType() throws {
        let state = stateWithBuildings(
            [.barracks, .archeryRange],
            keepRemaining: 20,
            cityNumberInCountry: 2,
            completedCityCount: 1
        )
        let store = try makeStore(initialState: state)
        let scene = makeScene(store: store)

        #expect(scene.selectedManualSoldierTypeForTesting == .infantry)

        scene.selectManualSoldierTypeForTesting(.archer)
        scene.spawnSoldierForTesting()

        #expect(scene.selectedManualSoldierTypeForTesting == .archer)
        #expect(scene.liveSoldierTypesForTesting == [.archer])
    }

    @Test func manualSpawnCapBlocksEleventhManualSoldier() throws {
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 100))
        let scene = makeScene(store: store)

        scene.spawnManualSoldiersDirectlyForTesting(KingdomGameState.manualSoldierCap)

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
                cityBattleStates: [cityKey.storageKey: cityState]
            )
        )
        let scene = makeScene(store: store)

        scene.spawnManualSoldiersDirectlyForTesting(KingdomGameState.manualSoldierCap)

        scene.advanceCombatForTesting(deltaTime: 0.1)

        #expect(scene.manualLiveSoldierCountForTesting == KingdomGameState.manualSoldierCap)
        #expect(scene.buildingLiveSoldierCountForTesting == 1)
        #expect(scene.liveSoldierCountForTesting == KingdomGameState.manualSoldierCap + 1)
        let infantryCount = scene.liveSoldierTypesForTesting.filter { $0 == .infantry }.count
        #expect(infantryCount == KingdomGameState.manualSoldierCap + 1)
        scene.flushBuildingProgressSaveForTesting()
        #expect(store.load().cityBattleState(for: cityKey).building(inSlot: 1)?.spawnTimerElapsed ?? 10 < 1)
    }

    @Test func archeryRangeBuildingSpawnUsesArcherVisual() throws {
        let cityKey = CityKey(countryNumber: 1, cityNumber: 2)
        let interval = KingdomGameState.activeSpawnInterval(for: .archeryRange)
        let cityState = CityBattleState(
            slots: [1: CityBuilding(type: .archeryRange, spawnTimerElapsed: interval - 0.1)]
        )
        let store = try makeStore(
            initialState: KingdomGameState(
                cityNumberInCountry: 2,
                completedCityCount: 1,
                cityBattleStates: [cityKey.storageKey: cityState]
            )
        )
        let scene = makeScene(store: store)

        scene.advanceCombatForTesting(deltaTime: 0.2)

        #expect(scene.liveSoldierTypesForTesting == [.archer])
        #expect(scene.firstLiveSoldierBodyNameForTesting == "archer-soldier")
        #expect(scene.firstLiveSoldierVisualMatchesForTesting(.archer))
    }

    @Test func battleSceneShowsDefenseTraitAndRemovesUpgradeAction() throws {
        let store = try makeStore(
            initialState: stateWithBarracks(
                keepRemaining: 100,
                cityNumberInCountry: 11,
                completedCityCount: 10
            )
        )
        let scene = makeScene(store: store)

        #expect(scene.defenseTraitTextForTesting?.contains("Reinforced Keep") == true)
        #expect(scene.isUpgradeButtonVisibleForTesting == false)
    }

    @Test func manualSpawnAlwaysAllowsInfantryWithoutBuilding() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100))
        let scene = makeScene(store: store)

        // Infantry is always available as the starter unit
        #expect(scene.manualSpawnableSoldierTypesForTesting == [.infantry])

        scene.spawnSoldierForTesting()

        #expect(scene.liveSoldierCountForTesting == 1)
    }

    @Test func manualSelectorUsesBuiltCurrentCityUnitsOnly() throws {
        let state = stateWithBuildings(
            [.barracks, .mageTower],
            gold: 200,
            keepRemaining: 100,
            cityNumberInCountry: 8,
            completedCityCount: 7
        )
        let store = try makeStore(initialState: state)
        let scene = makeScene(store: store)

        #expect(scene.manualSpawnableSoldierTypesForTesting == [.infantry, .mage])

        scene.selectManualSoldierTypeForTesting(.mage)
        scene.spawnSoldierForTesting()

        #expect(scene.selectedManualSoldierTypeForTesting == .mage)
        #expect(scene.liveSoldierTypesForTesting == [.mage])
    }

    @Test func manualSpawnUsesHighestMatchingBuildingLevelAndTraitAdjustedDamage() throws {
        // City 6 (Granite Pass, stoneWall) has no Barracks, so no Guard absorption applies. Siege is
        // favorable against stone (1.25x). Every route meets a Gate or Tower before the Keep, so the
        // damage is read from total objective HP rather than the Keep alone.
        let cityKey = CityKey(countryNumber: 1, cityNumber: 6)
        let cityState = CityBattleState(
            slots: [
                1: CityBuilding(type: .siegeWorkshop, level: 1),
                2: CityBuilding(type: .siegeWorkshop, level: 3)
            ]
        )
        let state = captainless(KingdomGameState(
            gold: 200,
            cityNumberInCountry: 6,
            completedCityCount: 5,
            cityBattleStates: [cityKey.storageKey: cityState]
        ))
        #expect(state.currentCityDefenseTrait == .stoneWall)
        let initialObjectivePower = SiegeTestSupport.totalObjectiveRemainingPower(of: state)
        let store = try makeStore(initialState: state)
        let scene = makeScene(store: store)

        let expectedAttackPower = KingdomGameState.traitAdjustedSoldierAttackPower(
            for: .siege,
            level: 3,
            defenseTrait: .stoneWall
        )

        scene.selectManualSoldierTypeForTesting(.siege)
        // Three charges drain instantly; the fourth tap needs one 1.5s
        // recharge of valid combat time (city 6 objective pools absorb it).
        for _ in 0..<3 {
            scene.spawnSoldierForTesting()
        }
        scene.advanceCombatForTesting(deltaTime: 1.5)
        scene.spawnSoldierForTesting()

        #expect(scene.liveSoldierLevelsForTesting == Array(repeating: 3, count: 4))
        #expect(scene.liveSoldierAttackPowersForTesting == Array(repeating: expectedAttackPower, count: 4))

        scene.advanceCombatForTesting(deltaTime: 4.0)

        #expect(SiegeTestSupport.totalObjectiveRemainingPower(of: store.load()) < initialObjectivePower)
    }

    @Test func buildingSpawnUsesTraitAdjustedAttackPower() throws {
        let cityKey = CityKey(countryNumber: 1, cityNumber: 11)
        let interval = KingdomGameState.activeSpawnInterval(for: .siegeWorkshop)
        let cityState = CityBattleState(
            slots: [1: CityBuilding(type: .siegeWorkshop, level: 3, spawnTimerElapsed: interval - 0.1)]
        )
        var state = KingdomGameState(
            gold: 200,
            cityNumberInCountry: 11,
            completedCityCount: 10,
            cityBattleStates: [cityKey.storageKey: cityState]
        )
        SiegeTestSupport.setKeepRemaining(100, on: &state)
        let store = try makeStore(initialState: state)
        let scene = makeScene(store: store)

        scene.advanceCombatForTesting(deltaTime: 0.2)

        #expect(scene.buildingLiveSoldierCountForTesting == 1)
        #expect(scene.liveSoldierTypesForTesting == [.siege])
        #expect(scene.liveSoldierLevelsForTesting == [3])
        #expect(scene.liveSoldierAttackPowersForTesting == [
            KingdomGameState.traitAdjustedSoldierAttackPower(
                for: .siege,
                level: 3,
                defenseTrait: .reinforcedKeep
            )
        ])
    }

    // MARK: - HPA-671 equipment at the two spawn callers

    @Test func manualSpawnCarriesEquipmentToughnessAndSpecialistSnapshot() throws {
        // Toughness: the Falconridge Bulwark lifts the deployed infantry's
        // cached max HP by the authored +25% before the final round
        // (round(10 × 1.25) = 13).
        var toughState = SiegeTestSupport.makeBattleState(
            atCity: 1,
            keepRemaining: 100_000,
            ownedEquipmentIDs: ["c03-infantry-toughness"]
        )
        #expect(toughState.equip(itemID: "c03-infantry-toughness") == .success)
        let toughScene = makeScene(store: try makeStore(initialState: toughState))

        toughScene.spawnSoldierForTesting()

        #expect(toughScene.liveSoldierCountForTesting == 1)
        #expect(toughScene.liveSoldierMaxHPsForTesting == [13])
        #expect(toughScene.liveSoldierSpecialistBonusesForTesting == [nil])

        // Specialist: the Granite Ram's gate target + 1.40 factor is
        // snapshotted onto the transient soldier at deploy time.
        var specialistState = SiegeTestSupport.makeBattleState(
            atCity: 1,
            keepRemaining: 100_000,
            ownedEquipmentIDs: ["c06-infantry-gate"]
        )
        #expect(specialistState.equip(itemID: "c06-infantry-gate") == .success)
        let specialistScene = makeScene(store: try makeStore(initialState: specialistState))

        specialistScene.spawnSoldierForTesting()

        #expect(specialistScene.liveSoldierCountForTesting == 1)
        #expect(specialistScene.liveSoldierMaxHPsForTesting == [10])
        #expect(specialistScene.liveSoldierSpecialistBonusesForTesting == [
            SoldierSpecialistBonus(target: .gate, multiplier: 1.4)
        ])
    }

    @Test func buildingSpawnCarriesEquipmentToughnessAndSpecialistSnapshot() throws {
        let interval = KingdomGameState.activeSpawnInterval(for: .barracks)
        func spawnScene(equippedItemID: String) throws -> BattleScene {
            let cityKey = CityKey(countryNumber: 1, cityNumber: 1)
            let cityState = CityBattleState(
                slots: [1: CityBuilding(type: .barracks, level: 1, spawnTimerElapsed: interval - 0.1)]
            )
            var state = KingdomGameState(
                gold: 200,
                cityNumberInCountry: 1,
                completedCityCount: 0,
                cityBattleStates: [cityKey.storageKey: cityState],
                ownedEquipmentIDs: [equippedItemID]
            )
            SiegeTestSupport.setKeepRemaining(100, on: &state)
            #expect(state.equip(itemID: equippedItemID) == .success)
            let scene = makeScene(store: try makeStore(initialState: state))
            scene.advanceCombatForTesting(deltaTime: 0.2)
            return scene
        }

        let toughScene = try spawnScene(equippedItemID: "c03-infantry-toughness")
        #expect(toughScene.buildingLiveSoldierCountForTesting == 1)
        #expect(toughScene.liveSoldierMaxHPsForTesting == [13])
        #expect(toughScene.liveSoldierSpecialistBonusesForTesting == [nil])

        let specialistScene = try spawnScene(equippedItemID: "c06-infantry-gate")
        #expect(specialistScene.buildingLiveSoldierCountForTesting == 1)
        #expect(specialistScene.liveSoldierMaxHPsForTesting == [10])
        #expect(specialistScene.liveSoldierSpecialistBonusesForTesting == [
            SoldierSpecialistBonus(target: .gate, multiplier: 1.4)
        ])
    }

    @Test func activeBuildingPartialTimerProgressPersistsWithoutSpawn() throws {
        let cityKey = CityKey(countryNumber: 1, cityNumber: 1)
        let cityState = CityBattleState(
            slots: [1: CityBuilding(type: .barracks, spawnTimerElapsed: 0)]
        )
        let store = try makeStore(
            initialState: KingdomGameState(
                cityBattleStates: [cityKey.storageKey: cityState]
            )
        )
        let scene = makeScene(store: store)

        scene.advanceCombatForTesting(deltaTime: 5.0)

        #expect(scene.buildingLiveSoldierCountForTesting == 0)
        scene.flushBuildingProgressSaveForTesting()
        let savedElapsed = try #require(
            store.load().cityBattleState(for: cityKey).building(inSlot: 1)?.spawnTimerElapsed
        )
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
                cityBattleStates: [cityKey.storageKey: cityState]
            )
        )
        let scene = makeScene(store: store)

        // Advance less than the throttle interval — no save should occur
        scene.advanceCombatForTesting(deltaTime: 1.0)

        let persisted = store.load().cityBattleState(for: cityKey).building(inSlot: 1)?.spawnTimerElapsed ?? 0
        #expect(persisted == 0)
    }

    @Test func buildingProgressSaveFlushesImmediatelyWhenSpawnFires() throws {
        let cityKey = CityKey(countryNumber: 1, cityNumber: 1)
        let interval = KingdomGameState.activeSpawnInterval(for: .barracks)
        let cityState = CityBattleState(
            slots: [1: CityBuilding(type: .barracks, spawnTimerElapsed: interval - 0.1)]
        )
        let store = try makeStore(
            initialState: KingdomGameState(
                cityBattleStates: [cityKey.storageKey: cityState]
            )
        )
        let scene = makeScene(store: store)

        // Small advance crosses the spawn threshold
        scene.advanceCombatForTesting(deltaTime: 0.2)

        // A building soldier should have spawned
        #expect(scene.buildingLiveSoldierCountForTesting == 1)
        // The timer reset must be persisted immediately without waiting for the throttle
        let savedState = store.load()
        let persisted = savedState.cityBattleState(for: cityKey).building(inSlot: 1)?.spawnTimerElapsed ?? interval
        #expect(persisted < interval * 0.5)
        #expect(savedState.activeSiegeSession?.deployments.contains {
            $0.type == .infantry && $0.source == .building && $0.count == 1
        } == true)
    }

    @Test func liveSoldierHPBarStaysAttachedToScaledBodyTopEdge() throws {
        let store = try makeStore(initialState: stateWithBuildings([.mageTower], keepRemaining: 20))
        let scene = makeScene(store: store)

        scene.selectManualSoldierTypeForTesting(.mage)
        scene.spawnSoldierForTesting()

        let hpBarFrame = try #require(scene.firstLiveSoldierHPBarFrameForTesting)
        let placement = try #require(scene.soldierLanePlacementsForTesting.first)
        let geometry = SoldierAnimationGeometry(type: .mage)
        let frameSize = geometry.frameSize(forBodyHeight: scene.soldierTargetHeightForTesting)
        let logicalBodyTop = placement.nodePosition.y + geometry.logicalBodyFrame(frameSize: frameSize).maxY
        let gap = hpBarFrame.minY - logicalBodyTop

        #expect(hpBarFrame.height >= 4.5)
        #expect(gap >= 0)
        #expect(gap <= 1.5)
    }

    @Test func combatTickCanDamageDurableCityHPAndSaveIt() throws {
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 20))
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 3.0)

        #expect(scene.liveSoldierCountForTesting == 1)
        #expect(store.load().currentKeepRemainingPower < 20)
    }

    @Test func cityDamageCreatesFloatingFeedbackNode() throws {
        let store = try makeStore(
            initialState: captainless(stateWithBarracks(
                keepRemaining: 50,
                cityNumberInCountry: 3,
                completedCityCount: 2
            ))
        )
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()
        advanceCombatUntil(scene) { scene.floatingFeedbackCountForTesting > 0 }

        #expect(scene.floatingFeedbackCountForTesting > 0)
        #expect(scene.feedbackTextForTesting.isEmpty)
        #expect(!scene.isFeedbackTooltipVisibleForTesting)
        let damageLabel = try #require(
            scene.childNode(withName: "//floatingFeedback") as? SKLabelNode
        )
        let enemyFrame = try #require(scene.enemyCityFrameForTesting)
        #expect(damageLabel.frame.maxY <= enemyFrame.minY - 4)
        #expect(damageLabel.fontSize == 22)
        #expect(
            damageLabel.attributedText?.attribute(
                .shadow,
                at: 0,
                effectiveRange: nil
            ) is NSShadow
        )
        let actionDuration = try #require(
            damageLabel.action(forKey: "floatingFeedback")?.duration
        )
        #expect(abs(actionDuration - 1.1) < 0.001)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        let fontColor = try #require(damageLabel.fontColor)
        fontColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #expect(abs(red - 142 / 255) < 0.01)
        #expect(abs(green - 247 / 255) < 0.01)
        #expect(abs(blue - 173 / 255) < 0.01)
        #expect(alpha == 1)
    }

    @Test func falconridgeArcherTowerDamageShowsGreenRoleAdvantageColor() throws {
        // HPA-582: the damage color reads the per-event trait×role product.
        // Falconridge archers are trait-disadvantaged (×0.80) but their tower
        // role (×1.5) nets ×1.20 — green, not the old trait-only white.
        let store = try makeStore(
            initialState: stateWithBuildings(
                [.archeryRange],
                keepRemaining: 26,
                cityNumberInCountry: 3,
                completedCityCount: 2,
                selectedLane: .left
            )
        )
        let scene = makeScene(store: store, combatSeed: 1)

        scene.selectManualSoldierTypeForTesting(.archer)
        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 3.0)

        let damageLabel = try #require(
            scene.childNode(withName: "//floatingFeedback") as? SKLabelNode
        )
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        let fontColor = try #require(damageLabel.fontColor)
        fontColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #expect(abs(red - 142 / 255) < 0.01)
        #expect(abs(green - 247 / 255) < 0.01)
        #expect(abs(blue - 173 / 255) < 0.01)
    }

    @Test func falconridgeArcherGateDamageStaysWhiteWithoutARoleBonus() throws {
        // Same disadvantaged archer on the gate-first center route: no tower,
        // no role, so the ×0.80 product keeps the neutral white color.
        let store = try makeStore(
            initialState: stateWithBuildings(
                [.archeryRange],
                keepRemaining: 26,
                cityNumberInCountry: 3,
                completedCityCount: 2,
                selectedLane: .center
            )
        )
        let scene = makeScene(store: store, combatSeed: 1)

        scene.selectManualSoldierTypeForTesting(.archer)
        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 3.0)

        let damageLabel = try #require(
            scene.childNode(withName: "//floatingFeedback") as? SKLabelNode
        )
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        let fontColor = try #require(damageLabel.fontColor)
        fontColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #expect(abs(red - 1) < 0.01)
        #expect(abs(green - 1) < 0.01)
        #expect(abs(blue - 1) < 0.01)
    }

    @Test func attackGearMakesNeutralCityDamageGreen() throws {
        let state = SiegeTestSupport.makeBattleState(
            keepRemaining: 15,
            selectedLane: .center,
            ownedEquipmentIDs: ["c01-infantry-attack"],
            equippedItemBySoldierType: ["infantry": "c01-infantry-attack"]
        )
        let scene = makeScene(store: try makeStore(initialState: state))
        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 3)

        let label = try #require(scene.childNode(withName: "//floatingFeedback") as? SKLabelNode)
        var red: CGFloat = 0
        try #require(label.fontColor).getRed(&red, green: nil, blue: nil, alpha: nil)
        #expect(abs(red - 142 / 255) < 0.01)
    }

    @Test func specialistGearMakesMatchingNeutralCityDamageGreen() throws {
        let state = SiegeTestSupport.makeBattleState(
            keepRemaining: 15,
            selectedLane: .center,
            ownedEquipmentIDs: ["c06-infantry-gate"],
            equippedItemBySoldierType: ["infantry": "c06-infantry-gate"]
        )
        let scene = makeScene(store: try makeStore(initialState: state))
        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 3)

        let label = try #require(scene.childNode(withName: "//floatingFeedback") as? SKLabelNode)
        var red: CGFloat = 0
        try #require(label.fontColor).getRed(&red, green: nil, blue: nil, alpha: nil)
        #expect(abs(red - 142 / 255) < 0.01)
    }

    @Test func newlyAwardedGearDoesNotRecolorTheConquestHit() throws {
        let state = SiegeTestSupport.makeBattleState(keepRemaining: 1, selectedLane: .right)
        let store = try makeStore(initialState: state)
        let scene = makeScene(store: store)
        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 3)

        #expect(store.load().equippedItemBySoldierType["infantry"] == "c01-infantry-attack")
        let label = try #require(scene.childNode(withName: "//floatingFeedback") as? SKLabelNode)
        var red: CGFloat = 0
        try #require(label.fontColor).getRed(&red, green: nil, blue: nil, alpha: nil)
        #expect(abs(red - 1) < 0.01)
    }

    @Test func gateHitFeedbackLandsOnTheGateNodeAndSparesTheKeep() throws {
        // Falconridge center route: the shared Ridge Gate blocks before the
        // Keep, so a fresh soldier's first hits strike the Gate. Its hit
        // flash must run on the Gate node and its floating damage beside it
        // — the Keep displays stay untouched (HPA-468 review C2).
        let store = try makeStore(initialState: SiegeTestSupport.makeBattleState(
            atCity: 3,
            keepRemaining: 26,
            selectedLane: .center
        ))
        let scene = makeScene(store: store, combatSeed: 1)
        let keep = try #require(firstNode(named: "enemy-city", in: scene))

        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 1.6)

        // The Keep took no damage in this window: every hit landed on the Gate.
        #expect(store.load().currentKeepRemainingPower == 26)
        let gate = try #require(scene.siegeObjectiveNodeForTesting(.gate))
        #expect(gate.action(forKey: "cityHitFeedback") != nil)
        #expect(keep.action(forKey: "cityHitFeedback") == nil)

        // Frozen actions keep every floating label at its spawn point:
        // beside the Gate structure, never at the Keep.
        let gateFrame = gate.calculateAccumulatedFrame()
        let labelPoints = scene.floatingFeedbackPositionsForTesting
        #expect(!labelPoints.isEmpty)
        for point in labelPoints {
            #expect(abs(point.x - gateFrame.midX) < 1)
            #expect(abs(point.y - (gateFrame.midY - 20)) < 1)
        }
    }

    @Test func repeatedGateDamageReusesAndResetsTheLatestTickLabel() throws {
        let state = captainless(SiegeTestSupport.makeBattleState(
            atCity: 3, keepRemaining: 26, selectedLane: .center
        ))
        let gateID = try #require(SiegeTestSupport.objectiveID(for: .gate, in: state))
        let scene = makeScene(store: try makeStore(initialState: state), combatSeed: 1)
        scene.isReduceMotionEnabled = { false }
        scene.spawnSoldierForTesting()
        advanceCombatUntil(scene) {
            scene.gameStateForTesting.siegeProgress.damageByObjectiveID[gateID, default: 0] > 0
        }

        func damageLabels() -> [SKLabelNode] {
            var labels: [SKLabelNode] = []
            scene.enumerateChildNodes(withName: "//floatingFeedback") { node, _ in
                if let label = node as? SKLabelNode, label.text?.hasPrefix("-") == true {
                    labels.append(label)
                }
            }
            return labels
        }

        let first = try #require(damageLabels().first)
        let origin = first.position
        for reducedMotion in [false, true] {
            let previousDamage = scene.gameStateForTesting.siegeProgress.damageByObjectiveID[gateID, default: 0]
            first.position.y += 47
            first.alpha = 0.6
            first.setScale(1.4)
            scene.isReduceMotionEnabled = { reducedMotion }
            advanceCombatUntil(scene) {
                scene.gameStateForTesting.siegeProgress.damageByObjectiveID[gateID, default: 0] > previousDamage
            }
            let delta = scene.gameStateForTesting.siegeProgress.damageByObjectiveID[gateID, default: 0] - previousDamage
            let labels = damageLabels()
            #expect(delta > 0)
            #expect(labels.count == 1)
            #expect(labels.first === first)
            #expect(first.text == "-\(CompactNumberFormatter.string(from: delta))")
            #expect(first.position == origin)
            #expect(first.alpha == 0)
            #expect(abs(first.xScale - (reducedMotion ? 1 : 0.7)) < 0.001)
            #expect(abs(first.yScale - (reducedMotion ? 1 : 0.7)) < 0.001)
            #expect(first.action(forKey: "floatingFeedback") != nil)
        }

        first.removeFromParent()
        let previousDamage = scene.gameStateForTesting.siegeProgress.damageByObjectiveID[gateID, default: 0]
        advanceCombatUntil(scene) {
            scene.gameStateForTesting.siegeProgress.damageByObjectiveID[gateID, default: 0] > previousDamage
        }
        let replacement = try #require(damageLabels().first)
        #expect(damageLabels().count == 1)
        #expect(replacement !== first)
        #expect(replacement.position == origin)
    }

    @Test func separateObjectivesKeepSeparateDamageAndFallFeedback() throws {
        let state = captainless(SiegeTestSupport.makeBattleState(
            atCity: 3, keepRemaining: 26, supportDamage: [.gate: 5, .arrowTower: 34],
            selectedLane: .center
        ))
        let scene = makeScene(store: try makeStore(initialState: state), combatSeed: 1)
        scene.spawnSoldierForTesting()
        advanceCombatUntil(scene) { scene.gameStateForTesting.currentKeepRemainingPower < 26 }
        var labels: [SKLabelNode] = []
        scene.enumerateChildNodes(withName: "//floatingFeedback") { node, _ in
            if let label = node as? SKLabelNode { labels.append(label) }
        }
        let damage = labels.filter { $0.text?.hasPrefix("-") == true }
        #expect(damage.count == 2)
        #expect(Set(damage.map(\.position.x)).count == 2)
        #expect(labels.filter { $0.text == "Gate down" }.count == 1)
    }

    @Test func sameTickCaptainAndSoldierDamageUsesOneAggregate() throws {
        // The level-1 Captain applies 2 per gate hit and the fresh
        // infantry 1, so a same-tick delta of 3+ proves BOTH sinks fed the
        // aggregate. The label still reads as one combined figure and —
        // per the explicit same-tick color policy (HPA-812 final review) —
        // renders deterministic neutral white, never whichever color the
        // later-running sink happened to pass.
        let state = SiegeTestSupport.makeBattleState(atCity: 3, keepRemaining: 26, selectedLane: .center)
        let gateID = try #require(SiegeTestSupport.objectiveID(for: .gate, in: state))
        let scene = makeScene(store: try makeStore(initialState: state), combatSeed: 1)
        scene.spawnSoldierForTesting()
        var sawCombinedHit = false
        for _ in 0..<120 where !sawCombinedHit {
            let before = scene.gameStateForTesting.siegeProgress.damageByObjectiveID[gateID, default: 0]
            scene.advanceCombatForTesting(deltaTime: 0.1)
            let delta = scene.gameStateForTesting.siegeProgress.damageByObjectiveID[gateID, default: 0] - before
            guard delta >= 3, scene.structureFallRequestsForTesting.isEmpty else { continue }
            sawCombinedHit = true
            let label = try #require(scene.childNode(withName: "//floatingFeedback") as? SKLabelNode)
            #expect(label.text == "-\(CompactNumberFormatter.string(from: delta))")
            #expect(scene.floatingFeedbackCountForTesting == 1)
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            try #require(label.fontColor).getRed(&red, green: &green, blue: &blue, alpha: nil)
            #expect(abs(red - 1) < 0.01)
            #expect(abs(green - 1) < 0.01)
            #expect(abs(blue - 1) < 0.01)
        }
        #expect(sawCombinedHit)

        // Single-source arms keep their own colors — the policy only
        // neutralizes an aggregate BOTH sinks contributed to. A Captain
        // fighting alone stays flat white...
        let (captainOnlyScene, _) = try makeCaptainScene(
            state: makeCaptainState(keepRemaining: 26, selectedLane: .center)
        )
        advanceCombatUntil(captainOnlyScene) {
            captainOnlyScene.gameStateForTesting.siegeProgress.damageByObjectiveID[gateID, default: 0] > 0
        }
        let captainOnlyLabel = try #require(
            captainOnlyScene.childNode(withName: "//floatingFeedback") as? SKLabelNode
        )
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        try #require(captainOnlyLabel.fontColor).getRed(&red, green: &green, blue: &blue, alpha: nil)
        #expect(abs(red - 1) < 0.01)
        #expect(abs(green - 1) < 0.01)
        #expect(abs(blue - 1) < 0.01)

        // ...and an ordinary advantaged tick keeps its green — Falconridge's
        // Arrow Tower trait favors infantry (x1.25). The mixed rule must
        // never recolor a single-source tick.
        let ordinaryScene = makeScene(store: try makeStore(initialState: captainless(
            SiegeTestSupport.makeBattleState(atCity: 3, keepRemaining: 26, selectedLane: .center)
        )), combatSeed: 1)
        ordinaryScene.spawnSoldierForTesting()
        advanceCombatUntil(ordinaryScene) {
            ordinaryScene.gameStateForTesting.siegeProgress.damageByObjectiveID[gateID, default: 0] > 0
        }
        let ordinaryLabel = try #require(
            ordinaryScene.childNode(withName: "//floatingFeedback") as? SKLabelNode
        )
        try #require(ordinaryLabel.fontColor).getRed(&red, green: &green, blue: &blue, alpha: nil)
        #expect(abs(red - 142 / 255) < 0.01)
        #expect(abs(green - 247 / 255) < 0.01)
        #expect(abs(blue - 173 / 255) < 0.01)
    }

    @Test func keepHitFeedbackReturnsToTheKeepOnceTheFalconridgeGateFalls() throws {
        // With the Ridge Gate one hit from ruin and the Arrow Tower already
        // destroyed (no defensive fire), the killing blow flashes the Gate
        // and the following hits flash the Keep itself — Keep damage
        // legitimately targets the Keep displays (HPA-468 review C2).
        let store = try makeStore(initialState: captainless(SiegeTestSupport.makeBattleState(
            atCity: 3,
            keepRemaining: 26,
            supportDamage: [.gate: 7, .arrowTower: 34],
            selectedLane: .center
        )))
        let scene = makeScene(store: store, combatSeed: 1)
        let keep = try #require(firstNode(named: "enemy-city", in: scene))

        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 3.6)

        let gate = try #require(scene.siegeObjectiveNodeForTesting(.gate))
        #expect(keep.action(forKey: "cityHitFeedback") != nil) // the follow-up hits
        #expect(store.load().currentKeepRemainingPower < 26)
        #expect(store.load().stageStatus == .battleActive) // damaged, not conquered

        // Both placements appear: a gate label centered on the Gate (its
        // flash ran on the then-current node before later keep-hit batches
        // rebuilt the objective nodes), and a keep label centered on the
        // Keep's column at its canonical below-the-city damage spot (same
        // clearance the Keep-damage feedback contract pins elsewhere).
        let gateFrame = gate.calculateAccumulatedFrame()
        let keepFrame = try #require(scene.enemyCityFrameForTesting)
        let labelPoints = scene.floatingFeedbackPositionsForTesting
        #expect(labelPoints.contains { abs($0.x - gateFrame.midX) < 1 })
        #expect(labelPoints.contains {
            abs($0.x - keepFrame.midX) < 1 && $0.y + 14 <= keepFrame.minY - 4
        })
    }

    @Test func cityDamageDoesNotCreateScalingImpactEffect() throws {
        let store = try makeStore(
            initialState: stateWithBarracks(
                keepRemaining: 50,
                completedCityCount: 0
            )
        )
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 3.0)

        let impactEffectScales = scene.impactEffectScalesForTesting

        #expect(!impactEffectScales.isEmpty)
        #expect(impactEffectScales.allSatisfy { $0.x == 1 && $0.y == 1 })
    }

    @Test func cityDamageDoesNotRelayoutBattlefieldBackdrop() throws {
        let store = try makeStore(
            initialState: stateWithBarracks(
                keepRemaining: 50,
                completedCityCount: 0,
                selectedLane: .right
            )
        )
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()
        let keepBeforeDamage = scene.keepRemainingPowerForTesting
        let layoutCountBeforeDamage = scene.battlefieldLayoutCountForTesting

        scene.advanceCombatForTesting(deltaTime: 3.0)

        #expect(scene.keepRemainingPowerForTesting < keepBeforeDamage)
        #expect(scene.battlefieldLayoutCountForTesting == layoutCountBeforeDamage)
    }

    @Test func infantrySelectorDoesNotRelayoutBattlefieldBackdrop() throws {
        let store = try makeStore(
            initialState: stateWithBarracks(
                keepRemaining: 50,
                completedCityCount: 0
            )
        )
        let scene = makeScene(store: store)

        let layoutCountBeforeInfantrySelection = scene.battlefieldLayoutCountForTesting

        scene.selectManualSoldierTypeForTesting(.infantry)

        #expect(scene.battlefieldLayoutCountForTesting == layoutCountBeforeInfantrySelection)
    }

    // City 9 tower damage (14 - 1 defense = 13 base) kills a 10-HP soldier in
    // one shot across ALL lanes: exposed lane 0.80× → 10, standard 1.0× → 13,
    // fortified 1.25× → 16. With a fixed seed the lane assignment is
    // deterministic, eliminating the balance-coincidence flakiness.
    @Test func towerDamageCanKillAndRemoveVisibleSoldier() throws {
        let store = try makeStore(
            initialState: captainless(stateWithBarracks(
                keepRemaining: 100,
                cityNumberInCountry: 9,
                completedCityCount: 8
            ))
        )
        let scene = makeScene(store: store, combatSeed: 1)

        scene.spawnSoldierForTesting()
        // Two seconds of combat: enough for the tower kill (which lands by
        // ~1.2s, per the delayed-removal pin) while the parked recovering
        // Captain stays down (its 12s recovery outlives the test).
        scene.advanceCombatForTesting(deltaTime: 2.0)

        let savedState = store.load()
        #expect(scene.liveSoldierCountForTesting == 0)
        #expect(!scene.isConquestPopupVisibleForTesting)
        #expect(savedState.stageStatus == .battleActive)
        #expect(savedState.currentKeepRemainingPower == 100)
        #expect(savedState.activeSiegeSession?.losses.contains {
            $0.type == .infantry && $0.source == .manual && $0.count == 1
        } == true)
    }

    @Test func liveCombatStatusUpdatesWhenTowerKillsLastSoldierWithoutCityDamage() throws {
        let store = try makeStore(
            initialState: captainless(stateWithBarracks(
                keepRemaining: 20,
                cityNumberInCountry: 9,
                completedCityCount: 8
            ))
        )
        let scene = makeScene(store: store, combatSeed: 1)

        scene.spawnSoldierForTesting()

        #expect(scene.liveCombatStatusTextForTesting == "1")

        scene.advanceCombatForTesting(deltaTime: 1.2)

        #expect(scene.liveSoldierCountForTesting == 0)
        #expect(scene.keepRemainingPowerForTesting == 20)
        #expect(store.load().currentKeepRemainingPower == 20)
        #expect(scene.liveCombatStatusTextForTesting == "0")
    }

    @Test func lossOnlyTickReenablesGameplayTabsAfterFinalManualSoldierDeath() throws {
        let store = try makeStore(
            initialState: captainless(stateWithBarracks(
                keepRemaining: 20,
                cityNumberInCountry: 9,
                completedCityCount: 8
            ))
        )
        let scene = makeScene(store: store, combatSeed: 1)

        scene.spawnSoldierForTesting()
        #expect(scene.battleHUDContentForTesting.enabledTabs == [.battle])
        #expect(scene.battleHUDTabBarForTesting.hitFrameForTesting(for: .camp) == nil)
        #expect(scene.battleHUDTabBarForTesting.hitFrameForTesting(for: .map) == nil)

        scene.advanceCombatForTesting(deltaTime: 1.2)

        #expect(scene.liveSoldierCountForTesting == 0)
        #expect(scene.keepRemainingPowerForTesting == 20)
        #expect(scene.battleHUDContentForTesting.enabledTabs == Set(GameplayTab.allCases))
        #expect(scene.battleHUDTabBarForTesting.hitFrameForTesting(for: .camp) != nil)
        #expect(scene.battleHUDTabBarForTesting.hitFrameForTesting(for: .map) != nil)
    }

    @Test func liveCombatConquestClearsSoldiersAndShowsPopup() throws {
        let initialGold = 100
        let store = try makeStore(
            initialState: stateWithBarracks(
                gold: initialGold,
                keepRemaining: 1,
                completedCityCount: 0
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
        #expect(savedState.gold == 108)
        #expect(savedState.completedCityCount == 1)
        #expect(savedState.stageStatus == .cityConqueredPendingMap)
        let pendingResult = try #require(savedState.pendingBattleResult)
        #expect(pendingResult.conquestMode == .live)
        #expect(pendingResult.goldEarned == savedState.gold - initialGold)
        #expect(!pendingResult.deployments.isEmpty)
        #expect(pendingResult.mvpSoldierType == .infantry)

        scene.advanceCombatForTesting(deltaTime: 3.0)

        let laterState = store.load()
        #expect(scene.liveSoldierCountForTesting == 0)
        #expect(scene.isConquestPopupVisibleForTesting)
        #expect(laterState.gold == savedState.gold)
        #expect(laterState.completedCityCount == savedState.completedCityCount)
        #expect(laterState.stageStatus == savedState.stageStatus)
    }

    @Test func backgroundClearPreservesDeploymentsWithoutRecordingLosses() throws {
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 100))
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()
        #expect(scene.gameStateForTesting.activeSiegeSession?.deployments.isEmpty == false)

        NotificationCenter.default.post(name: .pyxisSceneDidEnterBackground, object: nil)

        let savedSession = try #require(store.load().activeSiegeSession)
        #expect(scene.liveSoldierCountForTesting == 0)
        #expect(!savedSession.deployments.isEmpty)
        #expect(savedSession.losses.isEmpty)
    }

    @Test func lossOnlyTickPersistsSiegeSessionWithoutBuildingSavePath() throws {
        // No buildings → building-progress saves cannot mask a missing loss save.
        let store = try makeStore(
            initialState: captainless(KingdomGameState(
                gold: 100,
                cityNumberInCountry: 9,
                completedCityCount: 8
            ))
        )
        #expect(store.load().cityBattleStateForCurrentCity.occupiedSlotCount == 0)

        let scene = makeScene(store: store, combatSeed: 1)
        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 1.2)

        let savedSession = try #require(store.load().activeSiegeSession)
        #expect(scene.liveSoldierCountForTesting == 0)
        #expect(!savedSession.losses.isEmpty)
        #expect(savedSession.appliedDamage.isEmpty)
    }

    @Test func activeBattleTimeAdvancesOnlyWhileConquestPopupIsHidden() throws {
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 100))
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 0.2)

        let activeSeconds = try #require(scene.gameStateForTesting.activeSiegeSession?.activeBattleSeconds)
        #expect(activeSeconds > 0)

        scene.presentConquestPopupForTesting()
        scene.advanceCombatForTesting(deltaTime: 1.0)

        #expect(scene.gameStateForTesting.activeSiegeSession?.activeBattleSeconds == activeSeconds)
    }

    @Test func conquestPopupLayoutKeepsCityConquestFeedbackRunning() throws {
        let store = try makeStore(
            initialState: stateWithBarracks(
                keepRemaining: 1,
                completedCityCount: 0
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

    @Test func visualMatchReturnsFalseWithNoSoldiers() throws {
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 20))
        let scene = makeScene(store: store)
        #expect(!scene.firstLiveSoldierVisualMatchesForTesting(.infantry))
    }

    @Test func goldBurstZPositionFallsBackWhenAbsent() throws {
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 20))
        let scene = makeScene(store: store)
        #expect(scene.goldBurstZPositionForTesting < 0)
    }

    @Test func conquestPopupUsesRewardPresentationNodes() throws {
        let store = try makeStore(
            initialState: stateWithBarracks(
                keepRemaining: 1,
                completedCityCount: 0
            )
        )
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()
        scene.spawnSoldierForTesting()
        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 3.0)

        #expect(scene.isConquestPopupVisibleForTesting)
        #expect(scene.isGoldBurstVisibleForTesting)
        // The gold burst renders above the report panel so sparkles are visible.
        #expect(scene.goldBurstZPositionForTesting > scene.conquestReportNodeZPositionForTesting)
        // The report carries the dedicated reward copy.
        #expect(scene.conquestReportRewardTextForTesting == "+8")
    }

    @Test func conquestPopupRemovesGoldBurstAfterTransientActions() async throws {
        let store = try makeStore(
            initialState: stateWithBarracks(
                keepRemaining: 1,
                completedCityCount: 0
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

    @Test func campTabRequestsBuildingViewRoute() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100))
        let router = BattleRouterSpy()
        let scene = makeScene(store: store, router: router)

        scene.requestGameplayTabForTesting(.camp)

        #expect(router.didRequestBuildingView)
    }

    @Test func mapTabRequestsCountryMapRoute() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100))
        let router = BattleRouterSpy()
        let scene = makeScene(store: store, router: router)

        scene.requestGameplayTabForTesting(.map)

        #expect(router.didRequestCountryMap)
    }

    @Test func campTabWaitsForLiveSoldiersBeforeRouting() throws {
        let start = Date(timeIntervalSinceReferenceDate: 500)
        var initialState = KingdomGameState(gold: 100)
        #expect(initialState.buildBuilding(.barracks, inSlot: 1, at: start) == .built(cost: 15, remainingGold: 85))
        let store = try makeStore(initialState: initialState)
        let router = BattleRouterSpy()
        let scene = makeScene(store: store, router: router)

        scene.spawnSoldierForTesting()
        scene.requestGameplayTabForTesting(.camp)

        #expect(!router.didRequestBuildingView)
        #expect(scene.feedbackTextForTesting == "Finish the current squad before building.")
        #expect(scene.liveSoldierCountForTesting == 1)
        #expect(store.load() == initialState)
    }

    @Test func campTabAllowsRoutingWithOnlyBuildingSpawnedSoldiers() throws {
        let cityKey = CityKey(countryNumber: 1, cityNumber: 1)
        let cityState = CityBattleState(
            slots: [1: CityBuilding(type: .barracks, spawnTimerElapsed: 9.95)]
        )
        let store = try makeStore(
            initialState: KingdomGameState(
                gold: 100,
                cityBattleStates: [cityKey.storageKey: cityState]
            )
        )
        let router = BattleRouterSpy()
        let scene = makeScene(store: store, router: router)

        // Advance combat to trigger a building spawn
        scene.advanceCombatForTesting(deltaTime: 0.1)

        #expect(scene.buildingLiveSoldierCountForTesting == 1)
        #expect(scene.manualLiveSoldierCountForTesting == 0)

        scene.requestGameplayTabForTesting(.camp)

        #expect(router.didRequestBuildingView)
    }

    @Test func idleConquestClearsLiveSoldiersBeforeShowingPopup() throws {
        let start = Date(timeIntervalSinceNow: -1_000)
        var initialState = KingdomGameState(gold: 100, lastBackgroundedAt: start)
        SiegeTestSupport.setKeepRemaining(1, on: &initialState)
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
        #expect(savedState.pendingBattleResult?.conquestMode == .idle)
    }

    @Test func idleConquestSuppressesFeedbackTooltipBehindPopup() throws {
        // Regression: `sceneWillEnterForeground` set a non-empty conquest
        // `feedbackText` then called `redraw()` before `showConquestPopup`,
        // so `presentFeedbackTooltipIfNeeded` (invoked at the tail of `redraw`)
        // presented the tooltip behind the modal, where it could linger after
        // the popup closed. The live-combat conquest path already avoided this;
        // the idle path must too.
        let start = Date(timeIntervalSinceNow: -1_000)
        var initialState = KingdomGameState(gold: 100, lastBackgroundedAt: start)
        SiegeTestSupport.setKeepRemaining(1, on: &initialState)
        #expect(initialState.buildBuilding(.barracks, inSlot: 1, at: start) == .built(cost: 15, remainingGold: 85))
        let store = try makeStore(initialState: initialState)
        let scene = makeScene(store: store)

        // Fresh scene: no tooltip presented yet.
        #expect(!scene.isFeedbackTooltipVisibleForTesting)
        #expect(scene.lastPresentedTooltipTextForTesting.isEmpty)

        NotificationCenter.default.post(name: .pyxisSceneWillEnterForeground, object: nil)

        // The conquest popup is shown, and the feedback tooltip stays hidden
        // with no dedupe token recorded — the popup communicates the result.
        #expect(scene.isConquestPopupVisibleForTesting)
        #expect(!scene.isFeedbackTooltipVisibleForTesting)
        #expect(scene.lastPresentedTooltipTextForTesting.isEmpty)
        #expect(scene.feedbackTextForTesting.isEmpty)
    }

    @Test func liveConquestClearsStaleFeedbackSoTooltipStaysHiddenBehindPopup() throws {
        // A stale action warning must not be re-presented behind the conquest
        // popup during the conquest redraw.
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 1))
        let scene = makeScene(store: store)

        // Reproduce the post-fade stale state: an action warning remains in
        // `feedbackText` while the dedupe token has since reset.
        scene.setFeedbackTextForTesting("Manual squad is full.")
        #expect(!scene.feedbackTextForTesting.isEmpty)
        #expect(scene.lastPresentedTooltipTextForTesting.isEmpty)

        // Conquer via live combat (3 soldiers vs power 1).
        scene.spawnSoldierForTesting()
        scene.spawnSoldierForTesting()
        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 3.0)

        // The conquest popup is shown and the stale feedback is cleared so the
        // tooltip is not re-presented behind the overlay (no dedupe token).
        #expect(scene.isConquestPopupVisibleForTesting)
        #expect(scene.feedbackTextForTesting.isEmpty)
        #expect(scene.lastPresentedTooltipTextForTesting.isEmpty)
    }

    @Test func restoredPendingReportIsStatic() throws {
        let store = try makeStore(initialState: pendingConqueredState(city: 3, mode: .live))
        let scene = makeScene(store: store)
        #expect(scene.isConquestPopupVisibleForTesting)
        #expect(scene.feedbackSettingsGearHiddenForTesting)
        #expect(scene.conquestReportTitleForTesting == "Falconridge Silenced")
        #expect(scene.conquestReportTilesForTesting[0] == .battleTime(seconds: 65))
        #expect(!scene.isGoldBurstVisibleForTesting)
        #expect(!scene.isCityConquestFeedbackRunningForTesting)
        #expect(scene.lastConquestReportOriginForTesting == "restored")
        #expect(scene.conquestEffectPresentationCountForTesting == 0)
    }

    @Test("Conquest report hides Settings gear until its modal block clears")
    func conquestReportHidesSettingsGearUntilDismissed() throws {
        let scene = makeScene(
            store: try makeStore(initialState: pendingConqueredState(city: 3, mode: .live))
        )

        #expect(scene.feedbackSettingsGearHiddenForTesting)

        scene.forceDismissConquestOverlayForTesting()
        #expect(!scene.feedbackSettingsGearHiddenForTesting)

        scene.presentConquestPopupForTesting()
        #expect(scene.feedbackSettingsGearHiddenForTesting)

        scene.forceDismissConquestOverlayForTesting()
        scene.setConquestReportFitFailedForTesting(true)
        scene.redrawForTesting(shouldLayout: false)
        #expect(scene.feedbackSettingsGearHiddenForTesting)

        scene.setConquestReportFitFailedForTesting(false)
        scene.redrawForTesting(shouldLayout: false)
        #expect(!scene.feedbackSettingsGearHiddenForTesting)
    }

    @Test("Restored City 10 gets static milestone treatment without flourish replay")
    func restoredCity10ReportDoesNotReplayMilestoneFlourish() throws {
        let scene = makeScene(
            store: try makeStore(initialState: pendingConqueredState(city: 10, mode: .live))
        )

        #expect(scene.lastConquestReportOriginForTesting == "restored")
        #expect(scene.milestoneConquestFlourishCountForTesting == 0)
        #expect(scene.milestoneConquestAccentFrameForTesting != nil)
        #expect(!scene.isMilestoneArrivalVisibleForTesting)
    }

    @Test func liveConquestUsesFreshLiveEffectsOnce() throws {
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 1, selectedLane: .right))
        let scene = makeScene(store: store)
        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 3)
        #expect(scene.lastConquestReportOriginForTesting == "freshLive")
        #expect(scene.isGoldBurstVisibleForTesting)
        #expect(scene.isCityConquestFeedbackRunningForTesting)
        #expect(scene.goldBurstAnchorForTesting == scene.conquestReportGoldAnchorForTesting)
        let count = scene.conquestEffectPresentationCountForTesting
        scene.redrawForTesting(shouldLayout: true)
        scene.refreshLayoutForCurrentEnvironment()
        #expect(scene.conquestEffectPresentationCountForTesting == count)
    }

    @Test func battleForegroundIdleUsesFreshIdleGoldOnly() throws {
        let store = try makeStore(initialState: idleConquestReadyState(selectedLane: .right))
        let scene = makeScene(store: store)
        scene.enterBackgroundForTesting(at: Date(timeIntervalSince1970: 1_000))
        scene.enterForegroundForTesting(at: Date(timeIntervalSince1970: 10_000))
        #expect(scene.lastConquestReportOriginForTesting == "freshIdle")
        #expect(scene.conquestReportTilesForTesting == [
            .mvp(soldierType: .infantry, sharePercent: 100),
            .idleDamage(damage: 1),
            .sentLost(sent: 0, lost: 0)
        ])
        #expect(scene.isGoldBurstVisibleForTesting)
        #expect(!scene.isCityConquestFeedbackRunningForTesting)
        #expect(scene.floatingFeedbackCountForTesting == 0)
    }

    @Test func battleForegroundPositiveIdleDamageUsesCompactSummary() throws {
        let origin = Date(timeIntervalSince1970: 1_000)
        var state = KingdomGameState(gold: 100)
        _ = state.buildBuilding(.barracks, inSlot: 1, at: origin)
        let store = try makeStore(initialState: state)
        let scene = makeScene(store: store)

        scene.enterBackgroundForTesting(at: origin)
        scene.enterForegroundForTesting(at: origin.addingTimeInterval(300))

        // City 1 has 20 power; 300 credited idle seconds spawn three level-1
        // infantry for 3 damage — positive but non-conquest.
        #expect(scene.feedbackTextForTesting == "Buildings dealt 3 idle damage.")
        #expect(scene.gameStateForTesting.stageStatus == .battleActive)
        #expect(scene.gameStateForTesting.pendingBattleResult == nil)
    }

    @Test func battleForegroundZeroDamageIdleClearsStaleFeedback() throws {
        let origin = Date(timeIntervalSince1970: 1_000)
        let store = try makeStore(initialState: KingdomGameState(gold: 100))
        let scene = makeScene(store: store)

        scene.setFeedbackTextForTesting("Manual squad is full.")
        #expect(scene.feedbackTextForTesting == "Manual squad is full.")

        // A real credited return with no buildings resolves zero damage and
        // must clear the stale message instead of reporting a no-damage copy.
        scene.enterBackgroundForTesting(at: origin)
        scene.enterForegroundForTesting(at: origin.addingTimeInterval(300))

        #expect(scene.feedbackTextForTesting == "")
    }

    @Test func countryCompleteIsAnInertReportHost() throws {
        let store = try makeStore(initialState: pendingConqueredState(city: 15, mode: .idle, countryComplete: true))
        let scene = makeScene(store: store)
        let before = scene.gameStateForTesting
        scene.advanceCombatForTesting(deltaTime: 10)
        scene.spawnSoldierForTesting()
        #expect(scene.conquestReportTitleForTesting == "Crownspire Keep Falls")
        #expect(scene.gameStateForTesting == before)
        #expect(scene.liveSoldierCountForTesting == 0)
    }

    @Test func presentabilityRequiresMatchingCityKey() {
        #expect(BattleScene.isPendingResultPresentableForTesting(
            pendingResult(city: 3), currentCityKey: CityKey(countryNumber: 1, cityNumber: 3)
        ))
        #expect(!BattleScene.isPendingResultPresentableForTesting(
            pendingResult(city: 2), currentCityKey: CityKey(countryNumber: 1, cityNumber: 3)
        ))
    }

    @Test func repeatedDidMoveResizeAndRedrawDoNotDuplicateOrReplay() throws {
        let scene = makeScene(store: try makeStore(initialState: pendingConqueredState()))
        let controlCount = scene.conquestReportControlCountForTesting
        let effects = scene.conquestEffectPresentationCountForTesting
        scene.repeatDidMoveForTesting()
        scene.refreshLayoutForCurrentEnvironment()
        scene.redrawForTesting(shouldLayout: true)
        #expect(scene.conquestReportControlCountForTesting == controlCount)
        #expect(scene.conquestEffectPresentationCountForTesting == effects)
    }

    @Test func zeroDeploymentLossAndNoMVPRemainReadable() throws {
        let store = try makeStore(initialState: pendingConqueredState(city: 3))
        let scene = makeScene(store: store)
        #expect(scene.conquestReportTitleForTesting == "Falconridge Silenced")
        #expect(scene.conquestReportRewardTextForTesting == "+8")
        #expect(scene.conquestReportTilesForTesting == [
            .battleTime(seconds: 65),
            .sentLost(sent: 0, lost: 0)
        ])
        #expect(scene.conquestReportChipCountForTesting == 0)
        #expect(scene.popupContinueButtonFrameForTesting != nil)
        #expect(!scene.isConquestReportFitFailedForTesting)
        #expect(scene.isConquestPopupVisibleForTesting)
    }

    @Test func oneAchievementRendersOneBadge() throws {
        let store = try makeStore(initialState: pendingConqueredState(
            city: 3, usedFavorableUnit: true
        ))
        let scene = makeScene(store: store)
        #expect(scene.conquestReportChipCountForTesting == 1)
        #expect(scene.conquestReportTilesForTesting.count == 2)
        #expect(scene.popupContinueButtonFrameForTesting != nil)
        #expect(!scene.isConquestReportFitFailedForTesting)
    }

    @Test func threeRowCompactLayoutKeepsContinueVisible() throws {
        let store = try makeStore(initialState: pendingConqueredState(city: 3))
        let scene = makeScene(store: store)
        #expect(scene.conquestReportTilesForTesting.count == 2)
        let continueFrame = try #require(scene.popupContinueButtonFrameForTesting)
        #expect(continueFrame.minX >= 0)
        #expect(continueFrame.maxX <= scene.size.width)
        #expect(continueFrame.minY >= 0)
        #expect(continueFrame.maxY <= scene.size.height)
        #expect(continueFrame.width > 0)
        #expect(continueFrame.height > 0)
        #expect(!scene.isConquestReportFitFailedForTesting)
    }

    @Test func fitFailureRetriesAndClearsAfterSupportedResize() throws {
        let store = try makeStore(initialState: pendingConqueredState(city: 3))
        let scene = makeScene(store: store)
        #expect(!scene.isConquestReportFitFailedForTesting)
        scene.setConquestReportFitFailedForTesting(true)
        #expect(scene.isConquestReportFitFailedForTesting)
        scene.redrawForTesting(shouldLayout: true)
        #expect(!scene.isConquestReportFitFailedForTesting)
        #expect(scene.isConquestPopupVisibleForTesting)
        #expect(scene.popupContinueButtonFrameForTesting != nil)
    }

    @Test func countryCompleteContinueRoutesToFinalMapOnce() throws {
        let store = try makeStore(initialState: pendingConqueredState(
            city: 15, mode: .idle, countryComplete: true
        ))
        let router = BattleRouterSpy()
        let scene = makeScene(store: store, router: router)
        #expect(scene.conquestReportTitleForTesting == "Crownspire Keep Falls")
        #expect(scene.countryCompleteTextForTesting == "Country 1 Complete")
        #expect(scene.countryCompleteFrameForTesting != nil)
        #expect(scene.milestoneConquestFlourishCountForTesting == 0)
        scene.tapConquestContinueForTesting()
        scene.tapConquestContinueForTesting()
        #expect(router.countryMapRequestCount == 1)
        #expect(store.load().pendingBattleResult == nil)
    }

    @Test("A new-gear receipt adds one optional line without touching core metrics")
    func conquestReportShowsNewGearLineOnRoomyReport() throws {
        let router = BattleRouterSpy()
        let scene = makeScene(
            store: try makeStore(initialState: pendingConqueredState(
                city: 1, newGear: "c01-infantry-attack"
            )),
            router: router
        )

        #expect(scene.isConquestPopupVisibleForTesting)
        #expect(!scene.isConquestReportFitFailedForTesting)
        #expect(scene.conquestReportGearLineTextForTesting == "New gear: Willowford Blade · Lv 1")
        #expect(scene.conquestReportRewardTextForTesting == "+8")
        #expect(scene.conquestReportTilesForTesting == [
            .battleTime(seconds: 65),
            .sentLost(sent: 0, lost: 0)
        ])

        scene.tapConquestContinueForTesting()
        #expect(router.countryMapRequestCount == 1)
        #expect(scene.gameStateForTesting.pendingBattleResult == nil)
    }

    @Test("A restored report still shows its gear line after a relaunch re-encode")
    func restoredReportShowsNewGearLineAfterRelaunchReencode() throws {
        let original = pendingConqueredState(city: 1, newGear: "c01-infantry-attack")
        let decoded = try JSONDecoder().decode(
            KingdomGameState.self,
            from: JSONEncoder().encode(original)
        )
        #expect(
            decoded.pendingBattleResult?.equipmentReward
                == EquipmentReward(itemID: "c01-infantry-attack", level: 1)
        )

        let scene = makeScene(store: try makeStore(initialState: decoded))
        #expect(scene.lastConquestReportOriginForTesting == "restored")
        #expect(scene.conquestReportGearLineTextForTesting == "New gear: Willowford Blade · Lv 1")
        #expect(!scene.isConquestReportFitFailedForTesting)
    }

    @Test("A compact scene hides the gear line but keeps the report and Continue")
    func compactSceneHidesGearLineButKeepsReportAndContinue() throws {
        let scene = makeScene(
            store: try makeStore(initialState: pendingConqueredState(
                city: 1, newGear: "c01-infantry-attack"
            )),
            size: CGSize(width: 320, height: 568)
        )

        #expect(scene.isConquestPopupVisibleForTesting)
        #expect(!scene.isConquestReportFitFailedForTesting)
        #expect(scene.conquestReportGearLineTextForTesting == nil)
        #expect(scene.popupContinueButtonFrameForTesting != nil)
    }

    @Test("Relayout keeps the gear line in sync with the current geometry")
    func gearLineSurvivesRelayoutAndHidesOnCompactResize() throws {
        let scene = makeScene(
            store: try makeStore(initialState: pendingConqueredState(
                city: 1, newGear: "c01-infantry-attack"
            ))
        )
        #expect(scene.conquestReportGearLineTextForTesting == "New gear: Willowford Blade · Lv 1")

        scene.size = CGSize(width: 393, height: 700)
        scene.refreshLayoutForCurrentEnvironment()
        #expect(scene.isConquestPopupVisibleForTesting)
        #expect(scene.conquestReportGearLineTextForTesting == nil)

        scene.size = CGSize(width: 390, height: 844)
        scene.refreshLayoutForCurrentEnvironment()
        #expect(scene.conquestReportGearLineTextForTesting == "New gear: Willowford Blade · Lv 1")
    }

    @Test("The City 15 finale shows its gear line without displacing finale content")
    func city15FinaleShowsGearLineWithoutDisplacingFinaleContent() throws {
        let router = BattleRouterSpy()
        let scene = makeScene(
            store: try makeStore(initialState: pendingConqueredState(
                city: 15, mode: .idle, countryComplete: true, newGear: "c15-siege-keep"
            )),
            router: router
        )

        #expect(scene.conquestReportTitleForTesting == "Crownspire Keep Falls")
        #expect(scene.conquestReportGearLineTextForTesting == "New gear: Crownspire Breaker · Lv 1")
        #expect(scene.countryCompleteTextForTesting == "Country 1 Complete")
        #expect(scene.countryCompleteFrameForTesting != nil)
        #expect(!scene.isConquestReportFitFailedForTesting)

        scene.tapConquestContinueForTesting()
        #expect(router.countryMapRequestCount == 1)
        #expect(scene.gameStateForTesting.pendingBattleResult == nil)
    }

    @Test("Fresh City 5 flourish uses the applied result once")
    func freshCity5ConquestPresentsMilestoneFlourishOnce() throws {
        let key = CityKey(countryNumber: 1, cityNumber: 5)
        var state = KingdomGameState(
            gold: 100,
            cityLevel: 5,
            cityNumberInCountry: 5,
            completedCityCount: 4,
            cityBattleStates: [
                key.storageKey: CityBattleState(
                    slots: [1: CityBuilding(type: .barracks, level: 6)]
                )
            ]
        )
        SiegeTestSupport.setKeepRemaining(1, on: &state)
        let scene = makeScene(store: try makeStore(initialState: state))
        scene.dismissMilestoneArrivalForTesting()

        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 3)

        #expect(scene.lastConquestReportOriginForTesting == "freshLive")
        #expect(scene.milestoneConquestFlourishCountForTesting == 1)
        #expect(scene.lastMilestoneFlourishCityForTesting == 5)

        let count = scene.milestoneConquestFlourishCountForTesting
        scene.redrawForTesting(shouldLayout: true)
        scene.refreshLayoutForCurrentEnvironment()
        #expect(scene.milestoneConquestFlourishCountForTesting == count)
    }

    @Test("Finale completion layout failure reuses Battle unsupported-geometry gate")
    func finaleCompletionLayoutFailureUsesExistingGate() throws {
        let router = BattleRouterSpy()
        let scene = makeScene(
            store: try makeStore(initialState: pendingConqueredState(
                city: KingdomGameState.firstCountryCityCount,
                mode: .idle,
                countryComplete: true
            )),
            router: router,
            size: CGSize(width: 568, height: 205)
        )

        #expect(scene.isConquestReportFitFailedForTesting)
        #expect(!scene.isConquestPopupVisibleForTesting)
        #expect(router.lastLayoutGateReason == .unsupportedGeometry)
    }

    @Test func commanderHUDKeepsTopClustersAndActionsInsideScene() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 30))
        let scene = makeScene(store: store)
        let layout = try #require(scene.battleChromeLayoutForTesting)

        #expect(layout.safeFrame.contains(layout.topBandFrame))
        #expect(layout.safeFrame.contains(layout.deployFrame))
        #expect(layout.safeFrame.contains(layout.battlefieldFrame))
        #expect(layout.sceneFrame.contains(layout.tabBarFrame))
        #expect(layout.battlefieldFrame.height >= BattleChromeLayout.minimumBattlefieldHeight)
        #expect(layout.battlefieldFrame.maxY <= layout.topBandFrame.minY)
        #expect(layout.medallionFrames.allSatisfy { layout.safeFrame.contains($0) })
        #expect(layout.tabHitFrames.allSatisfy { $0.width >= 44 && $0.height >= 44 })
    }

    @Test func battleHUDUsesResourceValuesWithoutTitlesAndTextForCommands() throws {
        let store = try makeStore(initialState: stateWithBarracks(gold: 30, keepRemaining: 20))
        let scene = makeScene(store: store)

        let texts = visibleLabelTexts(in: scene)
        #expect(!texts.contains { $0.hasPrefix("Gold:") })
        #expect(!texts.contains { $0.hasPrefix("Soldiers:") })
        #expect(!texts.contains { $0.hasPrefix("HP:") })
        #expect(texts.contains("30"))
        #expect(texts.contains("0/10"))
        #expect(texts.contains("1 / 15"))
        #expect(texts.contains("WILLOWFORD"))
        #expect(texts.contains("DEPLOY · 3"))
        #expect(SoldierType.allCases.reduce(0) { count, soldierType in
            count + visibleSpriteCount(
                in: scene,
                named: "battleMedallionIcon-\(soldierType.rawValue)"
            )
        } == 5)
    }

    @Test func commonActionButtonsUseCompactIconShapes() throws {
        let store = try makeStore(initialState: stateWithBarracks(gold: 30, keepRemaining: 20))
        let scene = makeScene(store: store)
        let layout = try #require(scene.battleChromeLayoutForTesting)

        #expect(layout.deployFrame.width == layout.tabBarFrame.width)
        #expect(layout.tabHitFrames.count == GameplayTab.allCases.count)
        #expect(layout.tabHitFrames.allSatisfy { $0.height >= 44 })
    }

    @Test func infantryAndSpawnButtonsAreCompactAndLeftAligned() throws {
        let store = try makeStore(initialState: stateWithBarracks(gold: 30, keepRemaining: 20))
        let scene = makeScene(store: store)
        let layout = try #require(scene.battleChromeLayoutForTesting)

        #expect(layout.medallionFrames.first?.width == BattleChromeLayout.medallionVisualSize)
        #expect(layout.deployFrame.width == layout.tabBarFrame.width)
        #expect(layout.manualCountFrame.maxX <= layout.deployFrame.maxX)
    }

    @Test func buttonIconsAreLargeEnoughToRead() throws {
        let store = try makeStore(initialState: stateWithBarracks(gold: 30, keepRemaining: 20))
        let scene = makeScene(store: store)

        let layout = try #require(scene.battleChromeLayoutForTesting)
        #expect(scene.battleHUDForTesting.visualMedallionCountForTesting == 5)
        #expect(layout.medallionFrames.allSatisfy { $0.width == BattleChromeLayout.medallionVisualSize })
    }

    @Test func battleHUDMedallionIconsUseAuthoredUnitArt() throws {
        let store = try makeStore(initialState: stateWithBarracks(gold: 30, keepRemaining: 20))
        let scene = makeScene(store: store)

        for soldierType in SoldierType.allCases {
            #expect(visibleSpriteCount(
                in: scene,
                named: "battleMedallionIcon-\(soldierType.rawValue)"
            ) == 1)
        }
    }

    @Test func buttonIconsStayInsideTheirPaintedButtonBackgrounds() throws {
        let store = try makeStore(initialState: stateWithBarracks(gold: 30, keepRemaining: 20))
        let scene = makeScene(store: store)
        let layout = try #require(scene.battleChromeLayoutForTesting)
        let hud = scene.battleHUDForTesting

        #expect(layout.medallionFrames.allSatisfy { layout.safeFrame.contains($0) })
        #expect(layout.deployFrame.contains(layout.manualCountFrame))
        #expect(hud.currentLayoutForTesting == layout)
    }

    @Test func commanderHUDSurvivesCompactLandscapeWithoutOverlap() throws {
        let size = CGSize(width: 667, height: 375)
        let store = try makeStore(initialState: KingdomGameState(gold: 30))
        let scene = BattleScene(size: size, store: store, router: nil)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        scene.didMove(to: view)

        #expect(scene.battleChromeLayoutForTesting == nil)
        #expect(scene.isBattleChromeFitFailedForTesting)
    }

    @Test func battleChromeAvoidsFeedbackAndBattlefieldOverlapInCompactAndNarrowLayouts() throws {
        for size in [CGSize(width: 393, height: 700)] {
            let store = try makeStore(initialState: stateWithBarracks(gold: 30, keepRemaining: 20))
            let scene = BattleScene(size: size, store: store, router: nil)
            let view = SKView(frame: CGRect(origin: .zero, size: size))
            scene.didMove(to: view)

            let layout = try #require(scene.battleChromeLayoutForTesting)
            #expect(layout.isCompact)
            #expect(layout.battlefieldFrame.height >= BattleChromeLayout.compactMinimumBattlefieldHeight)
            #expect(layout.medallionHitFrames.allSatisfy { $0.width >= 44 && $0.height >= 44 })
        }
    }

    @Test func battleChromeKeepsFiveSpawnableUnitsTappableInNarrowLayout() throws {
        let size = CGSize(width: 393, height: 700)
        let store = try makeStore(
            initialState: stateWithBuildings(
                BuildingType.allCases,
                gold: 200,
                keepRemaining: 100,
                cityNumberInCountry: 11,
                completedCityCount: 10
            )
        )
        let scene = BattleScene(size: size, store: store, router: nil)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        scene.didMove(to: view)

        let layout = try #require(scene.battleChromeLayoutForTesting)
        #expect(layout.medallionFrames.count == SoldierType.allCases.count)
        #expect(layout.medallionHitFrames.allSatisfy { $0.width >= 44 && $0.height >= 44 })
    }

    @Test func commanderHUDFitsNarrowViewportWithoutOverflow() throws {
        let size = CGSize(width: 393, height: 700)
        let store = try makeStore(initialState: stateWithBarracks(gold: 30, keepRemaining: 20))
        let scene = BattleScene(size: size, store: store, router: nil)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        scene.didMove(to: view)

        let layout = try #require(scene.battleChromeLayoutForTesting)
        #expect(layout.safeFrame.contains(layout.battlefieldFrame))
        #expect(layout.sceneFrame.contains(layout.tabBarFrame))

        scene.spawnSoldierForTesting()
        #expect(scene.battleHUDForTesting.currentLayoutForTesting == layout)
    }

    @Test func worldToggleDoesNotCompressInfantryAndBuildControlsInNarrowViewport() throws {
        let size = CGSize(width: 393, height: 700)
        let store = try makeStore(initialState: stateWithBarracks(gold: 30, keepRemaining: 20))
        let scene = BattleScene(size: size, store: store, router: nil)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        scene.didMove(to: view)

        let layout = try #require(scene.battleChromeLayoutForTesting)
        #expect(layout.deployFrame.width >= 340)
        #expect(layout.tabHitFrames.count == GameplayTab.allCases.count)
    }

    @Test func commanderHUDFitsLateGameNumbersInNarrowViewport() throws {
        let size = CGSize(width: 393, height: 700)
        let state = KingdomGameState(
            gold: 123_456_789,
            cityNumberInCountry: 15,
            completedCityCount: 14
        )
        let store = try makeStore(initialState: state)
        let scene = BattleScene(size: size, store: store, router: nil)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        scene.didMove(to: view)

        let layout = try #require(scene.battleChromeLayoutForTesting)
        #expect(layout.topBandFrame.maxX <= size.width)
        #expect(layout.settingsFrame.width == 44)
        #expect(layout.battlefieldFrame.height >= BattleChromeLayout.compactMinimumBattlefieldHeight)
    }

    @Test func commanderHUDAvoidsTallPhoneSensorArea() throws {
        let size = CGSize(width: 390, height: 844)
        let store = try makeStore(initialState: KingdomGameState(gold: 30))
        let scene = BattleScene(size: size, store: store, router: nil)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        scene.didMove(to: view)

        let layout = try #require(scene.battleChromeLayoutForTesting)

        #expect(layout.topBandFrame.maxY <= size.height)
        #expect(layout.settingsFrame.maxY <= size.height)
        #expect(layout.battlefieldFrame.minY >= 0)
    }

    @Test func verticalBattlefieldPlacesEnemyCityAboveCastle() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 30))
        let scene = makeScene(store: store)

        let enemyFrame = try #require(scene.enemyCityFrameForTesting)
        let castleFrame = try #require(scene.playerCastleFrameForTesting)
        let battlefield = try #require(scene.battleChromeLayoutForTesting).battlefieldFrame

        // Enemy city sits inside the top of the battlefield frame; castle at the bottom.
        #expect(enemyFrame.minY > castleFrame.maxY)
        #expect(enemyFrame.maxY < battlefield.maxY)
        #expect(enemyFrame.minY >= battlefield.minY)
        #expect(enemyFrame.maxY <= battlefield.maxY)
        #expect(abs(castleFrame.minY - battlefield.minY) <= 6)
    }

    @Test func forgedReferencePhoneUsesAuthoredStructureBoxes() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 30))
        let scene = makeScene(store: store, size: CGSize(width: 393, height: 852))

        let enemyFrame = try #require(scene.enemyCityFrameForTesting)
        let castleFrame = try #require(scene.playerCastleFrameForTesting)

        #expect(abs(enemyFrame.width - 125.5) < 0.6)
        #expect(abs(enemyFrame.height - 132) < 0.1)
        #expect(abs(enemyFrame.minY - 502) < 0.1)
        #expect(abs(castleFrame.width - 98.8) < 0.6)
        #expect(abs(castleFrame.height - 104) < 0.1)
        #expect(abs(castleFrame.minY - 216) < 0.1)
        #expect(scene.childNode(withName: "//cityHPBarBackground")?.isHidden == true)
    }

    @Test func cityHPBarFillVisibleWhenCityHasPower() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 30))
        let scene = makeScene(store: store, size: CGSize(width: 393, height: 700))
        let hpBar = try #require(scene.childNode(withName: "//cityHPBarBackground"))

        // Positive case: with power remaining the fill path is non-nil so the
        // green HP sliver renders. Paired with the zero-power test below to
        // isolate the power==0 branch from full conquest teardown.
        #expect(!hpBar.isHidden)
        #expect(!scene.isCityHPBarFillHiddenForTesting)
    }

    @Test func cityHPBarFillHiddenWhenCityPowerIsZero() throws {
        let store = try makeStore(
            initialState: stateWithBarracks(keepRemaining: 1, completedCityCount: 0)
        )
        let scene = makeScene(store: store, size: CGSize(width: 393, height: 700))

        scene.spawnSoldierForTesting()
        scene.spawnSoldierForTesting()
        scene.spawnSoldierForTesting()

        scene.advanceCombatForTesting(deltaTime: 3.0)

        // Regression for the zero-power sliver: previously the fill kept a
        // 1px-wide path (`max(1, width * 0)`) and rendered a tiny green line
        // after the city was drained. The fix nils the path at power==0.
        #expect(scene.keepRemainingPowerForTesting == 0)
        #expect(scene.isCityHPBarFillHiddenForTesting)
    }

    @Test func redrawWithLayoutRunsCityHPBarLayoutExactlyOnce() throws {
        // Regression: `redraw(shouldLayout: true)` called `layoutCityHPBar()`
        // directly and then again via `layoutInterface()`, building CGPaths on
        // the first pass that were immediately discarded by the second. The fix
        // defers to `layoutInterface()` when `shouldLayout` is true.
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 20))
        let scene = makeScene(store: store)

        // Baseline count after scene construction.
        let baseline = scene.layoutCityHPBarCallCountForTesting

        // A full-layout redraw must run `layoutCityHPBar` exactly once (via the
        // `layoutInterface` pass), not twice.
        scene.redrawForTesting(shouldLayout: true)
        #expect(scene.layoutCityHPBarCallCountForTesting == baseline + 1)

        // A no-layout redraw (the per-damage-tick hot path) must still run
        // `layoutCityHPBar` exactly once so the HP bar reflects new damage
        // without a full interface layout.
        let baselineAfterLayout = scene.layoutCityHPBarCallCountForTesting
        scene.redrawForTesting(shouldLayout: false)
        #expect(scene.layoutCityHPBarCallCountForTesting == baselineAfterLayout + 1)
    }

    @Test func feedbackTooltipHiddenByDefaultOnFreshScene() throws {
        let store = try makeStore(initialState: stateWithBarracks(gold: 30, keepRemaining: 20))
        let scene = makeScene(store: store)

        // The feedback panel starts transparent and is only revealed briefly
        // as a tooltip after an action. Guards against a regression that
        // leaves the tooltip permanently visible.
        #expect(!scene.isFeedbackTooltipVisibleForTesting)
    }

    @Test func infoTooltipSuppressedWhileConquestPopupIsVisible() throws {
        // Regression: `handleInfoButton` had no `isConquestPopupVisible` guard,
        // so tapping a HUD info button (gold/city) while the conquest popup
        // overlayed the scene could present a tooltip rendered behind the popup.
        let store = try makeStore(initialState: stateWithBarracks(gold: 30, keepRemaining: 20))
        let router = BattleRouterSpy()
        let scene = makeScene(store: store, router: router)

        // Fresh scene: no tooltip presented yet.
        #expect(!scene.isFeedbackTooltipVisibleForTesting)
        #expect(scene.lastPresentedTooltipTextForTesting.isEmpty)

        // Present the conquest report (overlaying the HUD).
        scene.presentConquestPopupForTesting()
        #expect(scene.isConquestPopupVisibleForTesting)

        // While the popup is visible, both info buttons must be suppressed —
        // no tooltip presentation (panel stays hidden), no dedupe token recorded.
        let layout = try #require(scene.battleChromeLayoutForTesting)
        scene.handleTouchForTesting(at: layout.incomeFrame.center)
        scene.handleTouchForTesting(at: layout.cityProgressFrame.center)
        #expect(!scene.isFeedbackTooltipVisibleForTesting)
        #expect(scene.lastPresentedTooltipTextForTesting.isEmpty)

        // After the overlay lifts, info tooltips work again. This resets only
        // the report-gated state — it is NOT the production Continue path
        // (which is covered by `touchesEndedContinueDisablesAndRoutes`).
        scene.forceDismissConquestOverlayForTesting()
        #expect(!scene.isConquestPopupVisibleForTesting)
        scene.handleTouchForTesting(at: layout.cityProgressFrame.center)
        #expect(scene.isFeedbackTooltipVisibleForTesting)
        #expect(!scene.lastPresentedTooltipTextForTesting.isEmpty)
    }

    @Test func repeatedIdenticalFeedbackRetriggersTooltipAfterFadeOut() throws {
        // Regression: `lastPresentedTooltipText` was never reset after the
        // tooltip faded out, so a repeated identical action warning would show
        // once and then never again.
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 2000))
        let scene = makeScene(store: store)

        for _ in 0...KingdomGameState.manualSoldierCap {
            scene.spawnSoldierForTesting()
        }

        // First attack: tooltip presents and records the dedupe token.
        let firstToken = scene.lastPresentedTooltipTextForTesting
        #expect(!firstToken.isEmpty)

        // Simulate the fade-out SKAction completing: the token resets so the
        // next identical message can re-trigger the tooltip.
        scene.completeFeedbackTooltipFadeOutForTesting()
        #expect(scene.lastPresentedTooltipTextForTesting.isEmpty)

        // Repeating the blocked deploy must re-present the same warning.
        scene.spawnSoldierForTesting()
        #expect(scene.lastPresentedTooltipTextForTesting == firstToken)
    }

    @Test func threeVerticalLanesSpanCastleGateToEnemyGate() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 30))
        let scene = makeScene(store: store)

        let laneXs = scene.laneCenterXsForTesting
        #expect(laneXs.count == 3)
        // Distinct, ascending lane columns.
        #expect(laneXs[0] < laneXs[1])
        #expect(laneXs[1] < laneXs[2])

        for lane in BattleLane.allCases {
            let start = try #require(scene.castleGatePointForTesting(lane: lane))
            let end = try #require(scene.enemyGatePointForTesting(lane: lane))
            // Vertical marching: same x, gaining y.
            #expect(start.x == end.x)
            #expect(end.y > start.y)
        }
    }

    @Test func laneRenderingUsesTerrainStripsWithDetail() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 30))
        let scene = makeScene(store: store)

        #expect(visibleNodeCount(in: scene, namePrefix: "battleLaneTerrain-") == 3)
        #expect(visibleNodeCount(in: scene, namePrefix: "battleLaneDetail-") >= 12)
    }

    @Test func laneTerrainBlendsIntoBackdropInsteadOfCoveringIt() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 30))
        let scene = makeScene(store: store)

        let alphas = visibleShapeAlphas(in: scene, namePrefix: "battleLaneTerrain-")
        #expect(alphas.count == 3)
        for alpha in alphas {
            #expect(alpha.fill <= 0.18)
            #expect(alpha.stroke <= 0.28)
        }
    }

    @Test func soldierNodesRenderAtTheirLaneColumn() throws {
        let store = try makeStore(initialState: stateWithBarracks(gold: 100, keepRemaining: 1_000))
        let scene = makeScene(store: store)

        // Placement is the subject here; six soldiers are injected straight
        // into the roster because the transient charge pool only allows
        // three real taps.
        scene.spawnManualSoldiersDirectlyForTesting(6)

        let placements = scene.soldierLanePlacementsForTesting
        #expect(placements.count == 6)
        for placement in placements {
            let expectedX = try #require(scene.castleGatePointForTesting(lane: placement.lane)?.x)
            #expect(
                abs(placement.nodePosition.x - expectedX)
                    <= scene.soldierFormationMaximumLateralOffsetForTesting + 0.5
            )
        }
    }

    @Test func denseFormationKeepsDistinctSoldiersAndHPBarsWithinBattlefield() throws {
        for size in [CGSize(width: 393, height: 700), CGSize(width: 393, height: 852)] {
            let state = stateWithBarracks(gold: 100, keepRemaining: 1_000, selectedLane: .center)
            let scene = makeScene(store: try makeStore(initialState: state), size: size)
            scene.spawnManualSoldiersDirectlyForTesting(10)
            let battlefield = try #require(scene.battleChromeLayoutForTesting?.battlefieldFrame)
            let placements = scene.soldierLanePlacementsForTesting
            #expect(placements.count == 10)
            // Distinctness is a RENDERED property: the HPA-812 overflow
            // presentation may fold surplus soldiers into the lane's "+N"
            // badge — their hidden roots keep in-battlefield bookkeeping
            // positions, but bounded depth cannot keep unbounded parked
            // positions pairwise-separated, so the pairwise floor only
            // applies to soldiers actually on screen. The rendered cohort
            // itself must be non-vacuous: ten soldiers in one lane present
            // a real formation, not a token one- or two-man front.
            let rendered = scene.soldierPresentationsForTesting.filter { !$0.isFolded }
            #expect(rendered.count >= 6)
            for i in rendered.indices {
                for j in rendered.indices where j > i {
                    let a = rendered[i].nodePosition
                    let b = rendered[j].nodePosition
                    #expect(hypot(a.x - b.x, a.y - b.y) >= scene.soldierTargetHeightForTesting * 0.16)
                }
            }
            // Folded roots must still stay inside the battlefield.
            for folded in scene.soldierPresentationsForTesting where folded.isFolded {
                #expect(folded.nodePosition.y >= battlefield.minY - 0.5)
                #expect(folded.nodePosition.y <= battlefield.maxY + 0.5)
            }
            var roots: [SKNode] = []
            scene.enumerateChildNodes(withName: "//normal-soldier") { node, _ in
                if node.children.contains(where: { $0 is SKShapeNode && $0.zPosition == 2 }) {
                    roots.append(node)
                }
            }
            #expect(roots.count == 10)
            for root in roots {
                let bar = try #require(root.children.compactMap { $0 as? SKShapeNode }.first { $0.zPosition == 2 })
                let path = try #require(bar.path)
                func sceneFrame(_ bounds: CGRect) -> CGRect {
                    let min = root.convert(CGPoint(x: bounds.minX, y: bounds.minY), to: scene)
                    let max = root.convert(CGPoint(x: bounds.maxX, y: bounds.maxY), to: scene)
                    return CGRect(x: min.x, y: min.y, width: max.x - min.x, height: max.y - min.y)
                }
                let frame = sceneFrame(path.boundingBox)
                #expect(battlefield.contains(frame))
                let body = try #require(root.children.first { $0.zPosition == 1 } as? SKSpriteNode)
                let bodyFrame = sceneFrame(
                    SoldierAnimationGeometry(type: .infantry).logicalBodyFrame(frameSize: body.size)
                )
                #expect(battlefield.contains(bodyFrame))
            }
        }
    }

    @Test func outwardFormationSurvivorsRemainInsideBattlefieldAfterTowerCasualties() throws {
        for size in [CGSize(width: 393, height: 700), CGSize(width: 393, height: 852)] {
            for lane in [BattleLane.left, .right] {
                let state = captainless(stateWithBuildings(
                    [],
                    keepRemaining: 100,
                    cityNumberInCountry: 9,
                    completedCityCount: 8,
                    selectedLane: lane
                ))
                let scene = makeScene(store: try makeStore(initialState: state), combatSeed: 1, size: size)
                let initialCount = lane == .left ? 2 : 3
                scene.spawnManualSoldiersDirectlyForTesting(initialCount)
                #expect(scene.liveSoldierCountForTesting == initialCount)
                var roots: [SKNode] = []
                scene.enumerateChildNodes(withName: "//normal-soldier") { node, _ in
                    if node.children.contains(where: { $0 is SKShapeNode && $0.zPosition == 2 }) {
                        roots.append(node)
                    }
                }
                #expect(roots.count == initialCount)
                let survivor = try #require(lane == .left
                    ? roots.min { $0.position.x < $1.position.x }
                    : roots.max { $0.position.x < $1.position.x })
                let battlefield = try #require(scene.battleChromeLayoutForTesting?.battlefieldFrame)
                let screen = CGRect(origin: .zero, size: size)
                var previousX = survivor.position.x
                for _ in 0..<100 where scene.liveSoldierCountForTesting > 1 {
                    previousX = survivor.position.x
                    scene.advanceCombatSingleStepForTesting(deltaTime: 0.05)
                }
                #expect(scene.liveSoldierCountForTesting == 1)
                let liveBody = try #require(scene.firstLiveSoldierBodySpriteForTesting)
                #expect(liveBody.parent === survivor)
                #expect(scene.pendingAnimatedRemovalSoldierIDsForTesting.count == initialCount - 1)
                #expect(survivor.action(forKey: "soldierDelayedRemoval") == nil)
                for root in roots where root !== survivor {
                    #expect(root.action(forKey: "soldierDelayedRemoval") != nil)
                }
                #expect(abs(survivor.position.x - previousX) < scene.soldierTargetHeightForTesting * 0.5)
                let bar = try #require(survivor.children.compactMap { $0 as? SKShapeNode }
                    .first { $0.zPosition == 2 })
                let barPath = try #require(bar.path)
                func sceneFrame(_ local: CGRect) -> CGRect {
                    let min = survivor.convert(CGPoint(x: local.minX, y: local.minY), to: scene)
                    let max = survivor.convert(CGPoint(x: local.maxX, y: local.maxY), to: scene)
                    return CGRect(x: min.x, y: min.y, width: max.x - min.x, height: max.y - min.y)
                }
                for _ in 0..<10 {
                    let body = sceneFrame(SoldierAnimationGeometry(type: .infantry).logicalBodyFrame(
                        frameSize: liveBody.size
                    ))
                    let canvas = sceneFrame(liveBody.frame)
                    let hp = sceneFrame(barPath.boundingBox.insetBy(dx: -0.5, dy: -0.5))
                    #expect(battlefield.contains(body), "\(lane) \(size) body \(body) battlefield \(battlefield)")
                    #expect(battlefield.contains(canvas), "\(lane) \(size) canvas \(canvas) battlefield \(battlefield)")
                    #expect(battlefield.contains(hp), "\(lane) \(size) HP \(hp) battlefield \(battlefield)")
                    #expect(screen.contains(body))
                    #expect(screen.contains(canvas))
                    #expect(screen.contains(hp))
                    scene.advanceCombatSingleStepForTesting(deltaTime: 0.05)
                    #expect(scene.liveSoldierCountForTesting == 1)
                }
            }
        }
    }

    @Test func denseFormationDoesNotTeleportWhileMarchingToGate() throws {
        let state = try durableRightGateState(buildingCount: 5)
        for size in [CGSize(width: 393, height: 700), CGSize(width: 393, height: 852)] {
            let scene = makeScene(store: try makeStore(initialState: state), combatSeed: 1, size: size)
            scene.advanceCombatSingleStepForTesting(
                deltaTime: KingdomGameState.activeSpawnInterval(for: .barracks) * 4
            )
            var previous = scene.soldierLanePlacementsForTesting
            #expect(previous.count == 20)
            var greatestStep: CGFloat = 0
            for _ in 0..<60 {
                scene.advanceCombatSingleStepForTesting(deltaTime: 0.05)
                let current = scene.soldierLanePlacementsForTesting
                #expect(current.count == previous.count)
                for (before, after) in zip(previous, current) {
                    #expect(before.lane == after.lane)
                    greatestStep = max(greatestStep, hypot(
                        after.nodePosition.x - before.nodePosition.x,
                        after.nodePosition.y - before.nodePosition.y
                    ))
                }
                previous = current
            }
            #expect(greatestStep < scene.soldierTargetHeightForTesting * 0.2)
        }
    }

    @Test func denseGateFormationKeepsBodiesAndHPBarsReadable() throws {
        let state = try durableRightGateState(buildingCount: 0)
        let gateID = try #require(state.currentSiegeLayout.objectives.first {
            $0.kind == .gate && $0.visualLane == .right
        }?.id)
        for size in [CGSize(width: 393, height: 700), CGSize(width: 393, height: 852)] {
            let scene = makeScene(store: try makeStore(initialState: state), combatSeed: 1, size: size)
            scene.spawnManualSoldiersDirectlyForTesting(9)
            advanceCombatUntil(scene) {
                scene.gameStateForTesting.siegeProgress.damageByObjectiveID[gateID, default: 0] > 0
            }
            #expect(scene.gameStateForTesting.siegeProgress.damageByObjectiveID[gateID, default: 0] > 0)
            let battlefield = try #require(scene.battleChromeLayoutForTesting?.battlefieldFrame)
            let gate = try #require(scene.childNode(withName: "//siegeObjective-\(gateID)"))
            let gateBar = try #require(gate.childNode(withName: "siegeHPBackground") as? SKShapeNode)
            let gateBounds = try #require(gateBar.path).boundingBox
            let gateMin = gateBar.convert(CGPoint(x: gateBounds.minX, y: gateBounds.minY), to: scene)
            let gateMax = gateBar.convert(CGPoint(x: gateBounds.maxX, y: gateBounds.maxY), to: scene)
            let gateBarFrame = CGRect(
                x: gateMin.x, y: gateMin.y, width: gateMax.x - gateMin.x, height: gateMax.y - gateMin.y
            )
            var roots: [SKNode] = []
            scene.enumerateChildNodes(withName: "//normal-soldier") { node, _ in
                if node.children.contains(where: { $0 is SKShapeNode && $0.zPosition == 2 }) {
                    roots.append(node)
                }
            }
            #expect(roots.count == 9)
            var bodies: [CGRect] = []
            var bars: [CGRect] = []
            for root in roots {
                let sprite = try #require(root.children.first { $0.zPosition == 1 } as? SKSpriteNode)
                let bar = try #require(root.children.compactMap { $0 as? SKShapeNode }.first { $0.zPosition == 2 })
                let barPath = try #require(bar.path)
                func sceneFrame(_ local: CGRect) -> CGRect {
                    let min = root.convert(CGPoint(x: local.minX, y: local.minY), to: scene)
                    let max = root.convert(CGPoint(x: local.maxX, y: local.maxY), to: scene)
                    return CGRect(x: min.x, y: min.y, width: max.x - min.x, height: max.y - min.y)
                }
                bodies.append(sceneFrame(SoldierAnimationGeometry(type: .infantry).logicalBodyFrame(
                    frameSize: sprite.size
                )))
                bars.append(sceneFrame(barPath.boundingBox))
            }
            for index in bars.indices {
                #expect(battlefield.contains(bars[index]))
                #expect(battlefield.contains(bodies[index]))
                #expect(bars[index].width >= 22)
                #expect(bodies[index].height >= 30)
                #expect(!bars[index].insetBy(dx: -0.5, dy: -0.5).intersects(gateBarFrame))
                for other in bars.indices where other != index {
                    #expect(!bars[index].intersects(bars[other]))
                    #expect(!bars[index].intersects(bodies[other]))
                }
            }
        }
    }

    private func durableRightGateState(buildingCount: Int) throws -> KingdomGameState {
        let city = 15
        let layout = Country1CityCatalog.definition(for: city).siegeLayout
        let maxPowers = layout.maxPowerAllocation(totalBudget: KingdomGameState.cityMaxPower(for: city))
        var state = captainless(stateWithBuildings(
            Array(repeating: .barracks, count: buildingCount),
            keepRemaining: maxPowers[layout.keepObjective.id, default: 0],
            cityNumberInCountry: city,
            completedCityCount: city - 1,
            selectedLane: .right
        ))
        let towerID = try #require(layout.objectives.first { $0.kind == .arrowTower }?.id)
        state.siegeProgress.damageByObjectiveID[towerID] = maxPowers[towerID, default: 0]
        return state
    }

    // MARK: Dense live-formation overflow (HPA-812 Task 3)

    /// Scene-space rect of a node's local bounding box, mirroring the
    /// conversion `denseGateFormationKeepsBodiesAndHPBarsReadable` uses.
    private func sceneRect(of bounds: CGRect, in node: SKNode, scene: BattleScene) -> CGRect {
        let minPoint = node.convert(CGPoint(x: bounds.minX, y: bounds.minY), to: scene)
        let maxPoint = node.convert(CGPoint(x: bounds.maxX, y: bounds.maxY), to: scene)
        return CGRect(
            x: minPoint.x, y: minPoint.y,
            width: maxPoint.x - minPoint.x, height: maxPoint.y - minPoint.y
        )
    }

    /// Rendered-node accounting for the stable-seat model: how many
    /// `//normal-soldier` roots currently render vs sit folded under the
    /// badge, and how many of the folded ones are pending casualties.
    private struct SoldierPresentationCounts {
        let presented: Int
        let folded: Int
        let pendingHidden: Int
    }

    /// The three scene-space rects one rendered soldier root is measured
    /// by: `art` is the actual accumulated canvas (transient attack/swing
    /// reach included), `body` is the logical walk-pose rect seats are
    /// pitched on, and `bar` is its HP bar.
    private struct PresentedSoldierFrames {
        let art: CGRect
        let body: CGRect
        let bar: CGRect
    }

    /// Counts soldier roots by presentation state under the dense-formation
    /// overflow policy: `presented` roots still render body + HP bar;
    /// `folded` roots are hidden and must be accounted for by the lane's
    /// overflow badge. Casualty-in-flight roots keep their nodes until the
    /// authored hit/fade SKActions land — which never advance under
    /// `advanceCombatForTesting` — so presented + folded totals equal
    /// live + pending-removal, not the live count alone.
    private func soldierPresentationCounts(
        in scene: BattleScene
    ) -> SoldierPresentationCounts {
        var presented = 0
        var folded = 0
        scene.enumerateChildNodes(withName: "//normal-soldier") { node, _ in
            guard node.children.contains(where: { $0 is SKShapeNode && $0.zPosition == 2 }) else {
                return
            }
            if node.isHidden {
                folded += 1
            } else {
                presented += 1
            }
        }
        // Hidden pending corpses (a folded casualty that has not yet
        // found collision-free reveal ground) count in `folded` above but
        // are NOT badge members — the "+N" summarizes LIVE soldiers only.
        let pendingHidden = scene.pendingAnimatedRemovalSoldierIDsForTesting.filter {
            scene.soldierNodePresentationForTesting($0)?.isHidden == true
        }.count
        return SoldierPresentationCounts(
            presented: presented,
            folded: folded,
            pendingHidden: pendingHidden
        )
    }

    /// The lane's dense-formation overflow badge
    /// (`soldierOverflowBadge-<lane.rawValue>`): a non-interactive pill
    /// carrying a "+N" label that reports how many live soldiers are folded
    /// out of the lane's individual presentation. A nil badge is only
    /// correct while nothing is folded.
    private func overflowBadge(in scene: BattleScene, lane: BattleLane) -> SKNode? {
        var found: SKNode?
        scene.enumerateChildNodes(withName: "//soldierOverflowBadge-\(lane.rawValue)") { node, _ in
            found = node
        }
        return found
    }

    /// Parses the "+N" count off the lane's overflow badge label, or nil
    /// when the badge or its count label is missing.
    private func overflowBadgeCount(in scene: BattleScene, lane: BattleLane) -> Int? {
        guard let badge = overflowBadge(in: scene, lane: lane) else {
            return nil
        }
        var text: String?
        for child in badge.children {
            if let label = child as? SKLabelNode, let value = label.text, !value.isEmpty {
                text = value
            }
        }
        guard let text, text.hasPrefix("+"), let value = Int(text.dropFirst()) else {
            return nil
        }
        return value
    }

    @Test func denseGateLivePileBoundsPresentationAndReportsOverflowCount() throws {
        // The dense-gate-live evidence scenario (evidence/hpa-812/
        // dense-gate-live.png): five level-1 Barracks feed the intact
        // Crownspire east gate on the right lane with the Arrow Tower
        // destroyed, so twenty soldiers share one lane with no attrition —
        // the population every manual-only fixture missed (cap 10).
        let state = try durableRightGateState(buildingCount: 5)
        let gateID = try #require(state.currentSiegeLayout.objectives.first {
            $0.kind == .gate && $0.visualLane == .right
        }?.id)
        for size in [CGSize(width: 393, height: 700), CGSize(width: 393, height: 852)] {
            let scene = makeScene(
                store: try makeStore(initialState: state), combatSeed: 1, size: size
            )
            // One 40 s stall resolves all four pending spawn intervals at
            // once (the same burst the no-teleport regression uses); a short
            // march then parks all twenty at the gate stop position.
            scene.advanceCombatSingleStepForTesting(
                deltaTime: KingdomGameState.activeSpawnInterval(for: .barracks) * 4
            )
            #expect(scene.buildingLiveSoldierCountForTesting == 20)
            scene.advanceCombatForTesting(deltaTime: 2.5)
            // A second wave pushes past the readable-seat capacity so the
            // fold/badge path is genuinely exercised at every layout —
            // canvas-conservative footprints grew the seat budget enough
            // that twenty alone can all present on the tall layout.
            scene.advanceCombatSingleStepForTesting(
                deltaTime: KingdomGameState.activeSpawnInterval(for: .barracks) * 2
            )
            #expect(scene.liveSoldierCountForTesting == 30)
            #expect(scene.soldierNodeCountForTesting == 30)

            let battlefield = try #require(scene.battleChromeLayoutForTesting?.battlefieldFrame)
            let gate = try #require(scene.childNode(withName: "//siegeObjective-\(gateID)"))
            let gateBar = try #require(gate.childNode(withName: "siegeHPBackground") as? SKShapeNode)
            let gateBounds = try #require(gateBar.path).boundingBox
            let gateBarFrame = sceneRect(of: gateBounds, in: gateBar, scene: scene)

            // Presented roots keep full bodies + HP bars; folded roots are
            // hidden and must be counted by the lane's overflow badge.
            // Two body measures: `body` is the logical walk-pose rect (the
            // readable unit seats are pitched on); `art` is the actual
            // accumulated canvas including transient attack/swing reach.
            var presented: [PresentedSoldierFrames] = []
            var foldedRoots = 0
            var malformedRoots = 0
            scene.enumerateChildNodes(withName: "//normal-soldier") { node, _ in
                guard node.children.contains(where: { $0 is SKShapeNode && $0.zPosition == 2 }) else {
                    return
                }
                if node.isHidden {
                    foldedRoots += 1
                    return
                }
                guard
                    let body = node.children.first(where: { $0.zPosition == 1 }),
                    let sprite = body as? SKSpriteNode,
                    let bar = node.children
                        .compactMap({ $0 as? SKShapeNode })
                        .first(where: { $0.zPosition == 2 }),
                    let barPath = bar.path
                else {
                    malformedRoots += 1
                    return
                }
                presented.append(PresentedSoldierFrames(
                    art: sceneRect(
                        of: body.calculateAccumulatedFrame(),
                        in: node,
                        scene: scene
                    ),
                    body: sceneRect(
                        of: SoldierAnimationGeometry(type: .infantry)
                            .logicalBodyFrame(frameSize: sprite.size),
                        in: node,
                        scene: scene
                    ),
                    bar: sceneRect(of: barPath.boundingBox, in: node, scene: scene)
                ))
            }
            #expect(malformedRoots == 0)
            #expect(presented.count + foldedRoots == 30)

            // Bounded: thirty soldiers cannot all render readable bodies
            // and HP bars — the overflow is folded into a summary instead
            // of merging into a solid block.
            #expect(foldedRoots >= 4)
            #expect(presented.count >= 6)

            // Truthful: the lane's badge reports exactly the folded count.
            #expect(overflowBadgeCount(in: scene, lane: .right) == foldedRoots)

            // Readable: presented soldiers keep disjoint HP bars, clear of
            // each other's bodies and of the gate's own HP bar. The
            // contained unit is the logical body + bar; transient swing
            // art may reach past a seat edge but stays within a small,
            // bounded overhang of the field — it can never fly off-screen.
            let readableField = battlefield
            let artField = battlefield.insetBy(dx: -12, dy: -12)
            for index in presented.indices {
                let frames = presented[index]
                #expect(readableField.contains(frames.bar))
                #expect(readableField.contains(frames.body))
                #expect(artField.contains(frames.art))
                #expect(frames.bar.width >= 22)
                #expect(frames.body.height >= 30)
                #expect(!frames.bar.insetBy(dx: -0.5, dy: -0.5).intersects(gateBarFrame))
                for other in presented.indices where other != index {
                    #expect(!frames.bar.intersects(presented[other].bar))
                    #expect(!frames.bar.intersects(presented[other].body))
                }
            }

            // The badge is readable chrome: inside the battlefield, clear
            // of the gate HP bar, and not parked over a presented soldier.
            let badge = overflowBadge(in: scene, lane: .right)
            #expect(badge != nil)
            if let badge {
                let badgeFrame = badge.calculateAccumulatedFrame()
                #expect(battlefield.contains(badgeFrame))
                #expect(!badgeFrame.intersects(gateBarFrame))
                for frames in presented {
                    #expect(!badgeFrame.intersects(frames.body))
                    #expect(!badgeFrame.intersects(frames.bar))
                }
            }
        }
    }

    @Test func denseGateLivePileCasualtiesKeepAccountingAndForemostTargetPresented() throws {
        // Same pile with the Arrow Tower left alive: level-8 Barracks
        // produce 48-HP infantry that still out-pace the tower's ~3.75 s
        // kill cadence, so the lane stays dense while the foremost soldiers
        // fall — folded reserves must promote, corpses must not be counted,
        // and the tower's target must always be a presented body.
        let city = 15
        let layout = Country1CityCatalog.definition(for: city).siegeLayout
        let maxPowers = layout.maxPowerAllocation(
            totalBudget: KingdomGameState.cityMaxPower(for: city)
        )
        let slots = Dictionary(
            uniqueKeysWithValues: (1...5).map { ($0, CityBuilding(type: .barracks, level: 8)) }
        )
        var state = KingdomGameState(
            gold: 100,
            cityNumberInCountry: city,
            completedCityCount: city - 1,
            cityBattleStates: [
                CityKey(countryNumber: 1, cityNumber: city).storageKey:
                    CityBattleState(slots: slots)
            ]
        )
        state.siegeProgress.selectedLane = .right
        SiegeTestSupport.setKeepRemaining(
            maxPowers[layout.keepObjective.id, default: 0], on: &state
        )
        state = captainless(state)

        let scene = makeScene(
            store: try makeStore(initialState: state),
            combatSeed: 1,
            size: CGSize(width: 393, height: 852)
        )
        scene.advanceCombatSingleStepForTesting(
            deltaTime: KingdomGameState.activeSpawnInterval(for: .barracks) * 4
        )
        #expect(scene.buildingLiveSoldierCountForTesting == 20)
        // A second wave pushes past the readable-seat budget so the fold
        // path is genuinely exercised under fire.
        scene.advanceCombatSingleStepForTesting(
            deltaTime: KingdomGameState.activeSpawnInterval(for: .barracks) * 2
        )
        // March under fire until the tower schedules its first casualty.
        advanceCombatUntil(scene) {
            !scene.pendingAnimatedRemovalSoldierIDsForTesting.isEmpty
        }
        #expect(!scene.pendingAnimatedRemovalSoldierIDsForTesting.isEmpty)
        #expect(scene.liveSoldierCountForTesting < 30)

        // Accounting: live roster + in-flight casualty removals, nothing
        // stale. Folded roots stay live-only — a fading corpse is neither
        // presented nor summarized.
        let live = scene.liveSoldierCountForTesting
        let pending = scene.pendingAnimatedRemovalSoldierIDsForTesting.count
        #expect(scene.soldierNodeCountForTesting == live + pending)
        let counts = soldierPresentationCounts(in: scene)
        #expect(counts.presented + counts.folded == live + pending)
        // The lane is still dense after casualties: reserves must be folded,
        // not merged into the block.
        #expect(counts.folded - counts.pendingHidden >= 4)

        // The badge still reports exactly the folded live remainder —
        // casualties promote reserves; corpses are never counted.
        #expect((overflowBadgeCount(in: scene, lane: .right) ?? 0) == counts.folded - counts.pendingHidden)

        // The tower's target is the foremost soldier — roster order ties at
        // the shared stop position — and must always be a presented body,
        // never one folded into the overflow summary.
        let body = try #require(scene.firstLiveSoldierBodySpriteForTesting)
        #expect(body.parent?.isHidden == false)
        #expect(scene.firstLiveSoldierHPBarFrameForTesting != nil)

        // The ACTUAL combat-chosen tower target — the foremost in-range
        // soldier the last projectile was aimed at, not an assumed slot-0
        // rank — resolves to a presented body or an in-flight corpse, never
        // a silently folded root. `!= true` would accept a missing node;
        // require the exact rendered-or-pending state.
        let targetID = try #require(scene.lastTowerShotSoldierIDForTesting)
        let targetPresentation = try #require(scene.soldierNodePresentationForTesting(targetID))
        #expect(
            !targetPresentation.isHidden
                || scene.pendingAnimatedRemovalSoldierIDsForTesting.contains(targetID)
        )
    }

    @Test func denseGateReinforcementsAtFloorStayPresentedBehindThePile() throws {
        // After the pile is bounded, fresh building spawns still enter as
        // visible bodies near the lane start — they are a sparse cluster of
        // their own, not part of the folded mass. Folding them too would
        // silently freeze the marching stream the live recording shows.
        let state = try durableRightGateState(buildingCount: 5)
        let scene = makeScene(
            store: try makeStore(initialState: state),
            combatSeed: 1,
            size: CGSize(width: 393, height: 852)
        )
        scene.advanceCombatSingleStepForTesting(
            deltaTime: KingdomGameState.activeSpawnInterval(for: .barracks) * 4
        )
        scene.advanceCombatForTesting(deltaTime: 2.5)
        #expect(scene.liveSoldierCountForTesting == 20)
        // A second 20 s stall adds ten fresh soldiers at the lane start.
        scene.advanceCombatSingleStepForTesting(
            deltaTime: KingdomGameState.activeSpawnInterval(for: .barracks) * 2
        )
        #expect(scene.liveSoldierCountForTesting == 30)

        let castleGate = try #require(scene.castleGatePointForTesting(lane: .right))
        let presentedArrivals = scene.soldierPresentationsForTesting.filter {
            !$0.isFolded
                && abs($0.nodePosition.x - castleGate.x) <= 45
                && abs($0.nodePosition.y - castleGate.y) <= 60
        }.count
        #expect(presentedArrivals >= 4)

        // The pile AND the trailing wave present disjoint bodies + HP bars —
        // the wave is a readable marching column, not a second merged block.
        // The disjointness unit is the READABLE footprint (logical body ∪
        // HP bar): transient attack canvas reach is pose art, and members
        // still gliding to their seat are legitimately in transit — parked
        // members are the ones that must never merge. Settle one tick so
        // members whose seats re-anchored have converged, then check the
        // members that did not move.
        let settle = scene.soldierReadableFootprintsForTesting
        scene.advanceCombatSingleStepForTesting(deltaTime: 0.05)
        let parked = scene.soldierReadableFootprintsForTesting.filter { entry in
            settle.contains {
                $0.id == entry.id
                    && hypot(
                        $0.position.x - entry.position.x,
                        $0.position.y - entry.position.y
                    ) <= 1
            }
        }
        #expect(parked.count >= 6)
        for index in parked.indices {
            for other in parked.indices where other != index {
                #expect(
                    !parked[index].rect.intersects(parked[other].rect),
                    "parked readable footprints overlap: \(parked[index].rect) vs \(parked[other].rect)"
                )
            }
        }

        // The badge still covers exactly the folded remainder as the live
        // population grows.
        let counts = soldierPresentationCounts(in: scene)
        #expect(counts.presented + counts.folded == 30)
        #expect((overflowBadgeCount(in: scene, lane: .right) ?? 0) == counts.folded - counts.pendingHidden)
    }

    @Test func denseGateBandsStepThroughBoundariesWithoutOverlapOrStaleCounts() throws {
        // The second wave marches the ~60-pt gap between its own head and
        // the gate pile's head: while separated by a full pitch it is its
        // own presentation band, then the bands merge as the fronts
        // converge. Stepping the merge tick-by-tick — not sampling a single
        // instant — pins the invariants that must hold through every
        // boundary transition: exact live+pending node accounting, a
        // truthful badge, disjoint presented HP bars/bodies, a presented
        // foremost soldier, and no teleport of a soldier that stays
        // presented across the step.
        let state = try durableRightGateState(buildingCount: 5)
        let scene = makeScene(
            store: try makeStore(initialState: state),
            combatSeed: 1,
            size: CGSize(width: 393, height: 852)
        )
        scene.advanceCombatSingleStepForTesting(
            deltaTime: KingdomGameState.activeSpawnInterval(for: .barracks) * 4
        )
        scene.advanceCombatForTesting(deltaTime: 2.5)
        scene.advanceCombatSingleStepForTesting(
            deltaTime: KingdomGameState.activeSpawnInterval(for: .barracks) * 2
        )
        #expect(scene.liveSoldierCountForTesting == 30)

        // A soldier's presented root may slide by a march step — or one
        // formation row when a casualty closes ranks — but never teleport.
        let maxPresentedStep = scene.soldierTargetHeightForTesting * 1.2
        var foldedRange = (min: Int.max, max: Int.min)
        var visibleRowTransitions = 0
        var foldTransitions = 0
        var previous: [BattleCombatState.SoldierID: (folded: Bool, position: CGPoint, progress: Double)] = [:]
        for _ in 0..<60 {
            scene.advanceCombatSingleStepForTesting(deltaTime: 0.05)

            let live = scene.liveSoldierCountForTesting
            let pending = scene.pendingAnimatedRemovalSoldierIDsForTesting.count
            #expect(scene.soldierNodeCountForTesting == live + pending)
            let counts = soldierPresentationCounts(in: scene)
            #expect(counts.presented + counts.folded == live + pending)
            #expect((overflowBadgeCount(in: scene, lane: .right) ?? 0) == counts.folded - counts.pendingHidden)
            #expect(counts.presented >= 6)

            // Disjointness is a RESTING invariant: soldiers seated on their
            // formation cells keep disjoint bodies and HP bars. A root
            // visibly gliding to a re-slotted cell is legitimately between
            // positions this tick, so pairwise checks apply to members that
            // are tracking their formation point — movement within normal
            // march drift, not the bounded re-slot step.
            let followWindow = scene.soldierTargetHeightForTesting * 0.1
            // The disjointness unit is the READABLE footprint (logical body
            // ∪ HP bar): transient attack canvas reach is pose art and would
            // make a resting invariant fail only by coincidence of the
            // animation frame. A member counts as parked when it tracks its
            // OWN previous presented position within the march window.
            let parked = scene.soldierReadableFootprintsForTesting.filter { entry in
                guard let before = previous[entry.id], !before.folded else { return false }
                return hypot(
                    before.position.x - entry.position.x,
                    before.position.y - entry.position.y
                ) <= followWindow
            }
            for index in parked.indices {
                for other in parked.indices where other != index {
                    #expect(
                        !parked[index].rect.intersects(parked[other].rect),
                        "parked readable footprints overlap: \(parked[index].rect) vs \(parked[other].rect)"
                    )
                }
            }

            let current = Dictionary(
                uniqueKeysWithValues: scene.soldierPresentationsForTesting.map {
                    (
                        $0.id,
                        (folded: $0.isFolded, position: $0.nodePosition, progress: $0.position)
                    )
                }
            )
            foldedRange.min = min(foldedRange.min, counts.folded)
            foldedRange.max = max(foldedRange.max, counts.folded)
            #expect(scene.firstLiveSoldierBodySpriteForTesting?.parent?.isHidden == false)

            // Identity must survive every presentation transition: a live
            // soldier keeps its node across fold/unfold boundaries and every
            // root — rendered or bookkeeping — moves at a bounded step. A
            // member that stays VISIBLE through a row re-slot glides a full
            // pitch; that is an actual boundary transition, which this test
            // must observe at least once (not merely tolerate).
            for (id, after) in current {
                if let before = previous[id] {
                    #expect(hypot(
                        after.position.x - before.position.x,
                        after.position.y - before.position.y
                    ) < maxPresentedStep)
                    if before.folded != after.folded {
                        foldTransitions += 1
                    }
                    if !before.folded, !after.folded,
                       hypot(
                        after.position.x - before.position.x,
                        after.position.y - before.position.y
                       ) >= scene.soldierTargetHeightForTesting * 0.4 {
                        visibleRowTransitions += 1
                    }
                }
            }
            previous = current
        }
        // The run must actually traverse the boundary regime: a folded mass
        // existed while the wave was still marching in, and at least one
        // soldier visibly crossed a row boundary — otherwise the merge
        // scenario under test never happened.
        #expect(foldedRange.max > 0)
        #expect(visibleRowTransitions + foldTransitions > 0)
    }

    @Test func sparseGateFormationNeedsNoOverflowBadge() throws {
        // The pre-existing readable case must not grow a badge: nine manual
        // soldiers still fit the lane at full pitch, so nothing is folded
        // and no overflow summary appears.
        let state = try durableRightGateState(buildingCount: 0)
        let scene = makeScene(
            store: try makeStore(initialState: state),
            combatSeed: 1,
            size: CGSize(width: 393, height: 852)
        )
        scene.spawnManualSoldiersDirectlyForTesting(9)
        let counts = soldierPresentationCounts(in: scene)
        #expect(counts.presented == 9)
        #expect(counts.folded == 0)
        #expect(overflowBadge(in: scene, lane: .right) == nil)
    }

    @Test func denseGateStaggeredArrivalsNeverVanishVisibleSoldiersInBatches() throws {
        // Live battles produce STAGGERED arrivals: each Barracks wave spawns
        // one interval apart and marches in behind a formation that is
        // already fighting at the gate. A trailing soldier entering the
        // readable region must never collapse the visible formation — the
        // review repro parks nine readable soldiers, drops one arrival
        // behind them, and watches six fold at once under the band-budget
        // policy. Visible soldiers may step back into the badge only one at
        // a time (a fold is one soldier's accounting change, not a mass
        // disappearance).
        let state = try durableRightGateState(buildingCount: 5)
        let scene = makeScene(
            store: try makeStore(initialState: state),
            combatSeed: 1,
            size: CGSize(width: 393, height: 852)
        )
        let interval = KingdomGameState.activeSpawnInterval(for: .barracks)
        // Staggered production: spawn a wave, let it march part of the way,
        // spawn the next — soldiers arrive trailing, not in bursts.
        scene.advanceCombatSingleStepForTesting(deltaTime: interval)
        scene.advanceCombatForTesting(deltaTime: 2.0)
        #expect(scene.liveSoldierCountForTesting == 5)
        scene.advanceCombatSingleStepForTesting(deltaTime: interval)
        #expect(scene.liveSoldierCountForTesting == 10)

        var previousVisible: Set<BattleCombatState.SoldierID> = []
        var previousLiveCount = 0
        var largestSingleTickLoss = 0
        var sawFoldedMass = false
        for _ in 0..<160 {
            scene.advanceCombatSingleStepForTesting(deltaTime: 0.05)
            let live = scene.liveSoldierCountForTesting
            let pending = scene.pendingAnimatedRemovalSoldierIDsForTesting.count
            #expect(scene.soldierNodeCountForTesting == live + pending)
            let counts = soldierPresentationCounts(in: scene)
            #expect(counts.presented + counts.folded == live + pending)
            #expect(
                (overflowBadgeCount(in: scene, lane: .right) ?? 0) == counts.folded - counts.pendingHidden
            )
            if counts.folded > 0 {
                sawFoldedMass = true
            }

            let visible = Set(
                scene.soldierPresentationsForTesting
                    .filter { !$0.isFolded }
                    .map(\.id)
            )
            // While the roster only grows, at most one previously visible
            // soldier may step back per tick. Batch disappearances are a
            // presentation bug, not formation math.
            if live >= previousLiveCount {
                let vanished = previousVisible.subtracting(visible).count
                largestSingleTickLoss = max(largestSingleTickLoss, vanished)
                #expect(vanished <= 1)
            }
            previousVisible = visible
            previousLiveCount = live
        }
        // Non-vacuous: the roster really grew and the folded regime was
        // exercised, so the per-tick bound covered real transitions.
        #expect(scene.liveSoldierCountForTesting > 10)
        #expect(sawFoldedMass || largestSingleTickLoss == 0)
    }

    @Test func denseGateMixedTypesCaptainAndTowerTargetStayRendered() throws {
        // The tower stays alive and the lane Captain is deployed: barracks
        // infantry pile at the gate while manually deployed cavalry — 1.45×
        // march speed — overtakes them from behind. The Captain and the
        // combat-chosen tower target must keep rendered continuity through
        // every re-rank and re-slot; Rally protection must accent a VISIBLE
        // root, never a folded one.
        let city = 15
        let layout = Country1CityCatalog.definition(for: city).siegeLayout
        let maxPowers = layout.maxPowerAllocation(
            totalBudget: KingdomGameState.cityMaxPower(for: city)
        )
        let slots = Dictionary(
            uniqueKeysWithValues: (1...5).map { ($0, CityBuilding(type: .barracks, level: 8)) }
        )
        var state = KingdomGameState(
            gold: 100,
            cityNumberInCountry: city,
            completedCityCount: city - 1,
            cityBattleStates: [
                CityKey(countryNumber: 1, cityNumber: city).storageKey:
                    CityBattleState(slots: slots)
            ]
        )
        state.siegeProgress.selectedLane = .right
        SiegeTestSupport.setKeepRemaining(
            maxPowers[layout.keepObjective.id, default: 0], on: &state
        )
        // Deployed, full-HP Captain on the assault lane (city 15 ≥ 3, so the
        // Captain is available); the Arrow Tower is left alive. The level
        // matches the camp-derived captainLevel projection (highest camp
        // building level = 8) — a level-1 seed gets 20 HP and retreats
        // under tower fire before the march even reaches the gate, which
        // would make the Rally tap below a dead-on-arrival no-op.
        state.siegeProgress.captain = .freshCaptain(
            selectedLane: .right, captainLevel: 8
        )
        let scene = makeScene(
            store: try makeStore(initialState: state),
            combatSeed: 1,
            size: CGSize(width: 393, height: 852)
        )
        let captain = try #require(scene.livingCaptainForTesting)

        // Infantry stream in first; cavalry deploy behind them and catch up.
        let interval = KingdomGameState.activeSpawnInterval(for: .barracks)
        scene.advanceCombatSingleStepForTesting(deltaTime: interval)

        // Rally through the real HUD tap path while the Captain is
        // guaranteed alive — the Arrow Tower CAN kill him inside the
        // sampled window, after which a tap is a dead-on-arrival no-op
        // that proves nothing, so the tap lands as soon as lane soldiers
        // exist to carry accents. A milestone-arrival panel eats touches
        // as a dismissal, so clear it through the real dismiss path first.
        scene.dismissMilestoneArrivalForTesting()
        // Fixture precondition for a meaningful window: the Captain is
        // still alive in combat — a `.recovering` strip is inert by
        // design and a tap on it proves nothing.
        #expect(scene.livingCaptainForTesting != nil)
        // Fire Rally through the real HUD tap path — unless the auto-
        // trigger already opened the window under tower fire (either is
        // the one shared production funnel; what matters is that a real
        // window exists for the accent checks below).
        if scene.rallyRemainingSecondsForTesting == 0 {
            let rallyHitFrame = try #require(
                scene.battleChromeLayoutForTesting?.rallyHitFrame
            )
            scene.handleTouchForTesting(
                at: CGPoint(x: rallyHitFrame.midX, y: rallyHitFrame.midY)
            )
        }
        // A real Rally window must exist — manual or automatic — or the
        // accent assertions in the loop can never execute.
        scene.advanceCombatSingleStepForTesting(deltaTime: 0.05)
        #expect(scene.rallyRemainingSecondsForTesting > 0)

        scene.advanceCombatForTesting(deltaTime: 1.5)
        let beforeCavalry = Set(scene.soldierPresentationsForTesting.map(\.id))
        scene.selectManualSoldierTypeForTesting(.cavalry)
        scene.spawnManualSoldiersDirectlyForTesting(3)
        let cavalryIDs = Set(scene.soldierPresentationsForTesting.map(\.id))
            .subtracting(beforeCavalry)
        #expect(!cavalryIDs.isEmpty)

        var sawCavalryCatchUp = false
        var towerFired = false
        var sawRallyAccents = false
        for _ in 0..<160 {
            scene.advanceCombatSingleStepForTesting(deltaTime: 0.05)

            // The Captain never folds into the badge and never hides
            // mid-transition — he is readable while recovering behind the
            // pile and while fighting beside it.
            #expect(scene.soldierRootIsHiddenForTesting(captain.id) == false)

            // The tower's actual combat-chosen target — not an assumed
            // rank — always resolves to a RENDERED root or an in-flight
            // pending casualty still on screen, so its projectile lands
            // on the body it was aimed at. `!= true` would also accept a
            // missing node; require the exact rendered-or-corpse state.
            if let target = scene.lastTowerShotSoldierIDForTesting {
                towerFired = true
                let presentation = scene.soldierNodePresentationForTesting(target)
                let pendingCorpse = scene.pendingAnimatedRemovalSoldierIDsForTesting
                    .contains(target)
                #expect(
                    presentation != nil && (!presentation!.isHidden || pendingCorpse),
                    "tower target \(target) is neither rendered nor a visible corpse"
                )
            }

            // livingSoldierCount is ordinary soldiers only — a live
            // Captain is the extra node; a dead one lands in `pending`
            // through the retreat path, so he is never double-counted.
            let live = scene.liveSoldierCountForTesting
            let pending = scene.pendingAnimatedRemovalSoldierIDsForTesting.count
            let captainLive = scene.livingCaptainForTesting != nil ? 1 : 0
            #expect(scene.soldierNodeCountForTesting == live + pending + captainLive)
            let counts = soldierPresentationCounts(in: scene)
            #expect(counts.presented + counts.folded == live + pending + captainLive)
            #expect(
                (overflowBadgeCount(in: scene, lane: .right) ?? 0) == counts.folded - counts.pendingHidden
            )

            // Rally window (manual above; auto may also fire): the accent
            // sync ran inside this very step — protection accents must
            // actually EXIST and resolve to real soldier nodes (an accent
            // on a phantom id proved nothing), and at least one must ride
            // a rendered root, never only folded ones.
            if scene.rallyRemainingSecondsForTesting > 0 {
                let accents = scene.rallyAccentVisibleSoldierIDsForTesting
                #expect(!accents.isEmpty)
                #expect(accents.allSatisfy {
                    scene.soldierNodePresentationForTesting($0) != nil
                })
                #expect(accents.contains {
                    scene.soldierRootIsHiddenForTesting($0) == false
                })
                sawRallyAccents = true
            }

            let lane = scene.soldierPresentationsForTesting.filter { $0.lane == .right }
            // The cavalry's faster march is exercised for real when it
            // closes the gap it spawned behind and reaches/passes the
            // leading NON-cavalry soldier — `cavMax > laneMax - 1` was
            // vacuous whenever the lane had already thinned to cavalry
            // alone, because then cavMax == laneMax by definition.
            let cavalry = lane.filter { cavalryIDs.contains($0.id) }
            let nonCavalry = lane.filter { !cavalryIDs.contains($0.id) }
            if let cavMax = cavalry.map(\.position).max(),
               let nonCavMax = nonCavalry.map(\.position).max(),
               cavMax >= nonCavMax {
                sawCavalryCatchUp = true
            }
        }

        // Non-vacuous: the Captain fought, the tower fired, the late-
        // spawned 1.45× cavalry actually closed on the front, and the
        // manually-fired Rally window really rendered accents — every
        // protected invariant was exercised, not merely tolerated.
        #expect(towerFired)
        #expect(sawCavalryCatchUp)
        #expect(sawRallyAccents)
    }

    @Test func denseGatePresentationMovesAtCombatSpeedAcrossCadences() throws {
        // Presentation motion is clocked by combat time, not sync count: the
        // same pile advancing at 20 FPS-equivalent 0.05 s ticks and at
        // coarse 0.25 s stalls keeps its readable rows the whole march.
        // Frame-quantized easing let a 13 pt/tick march outrun a ~10
        // pt/sync step, hiding every marching soldier until it stopped.
        let state = try durableRightGateState(buildingCount: 5)
        var seriesByStep: [Double: [Int]] = [:]
        for step in [0.05, 0.25] {
            let scene = makeScene(
                store: try makeStore(initialState: state),
                combatSeed: 1,
                size: CGSize(width: 393, height: 852)
            )
            scene.advanceCombatSingleStepForTesting(
                deltaTime: KingdomGameState.activeSpawnInterval(for: .barracks) * 4
            )
            #expect(scene.liveSoldierCountForTesting == 20)
            var presentedSeries: [Int] = []
            // 5 s of combat at both cadences; the fine run samples only at
            // the matched 0.25 s instants so the comparison is between
            // identical combat states, not identical tick counts.
            let ticks = Int((5.0 / step).rounded())
            for i in 1...ticks {
                scene.advanceCombatSingleStepForTesting(deltaTime: step)
                if step == 0.25 || i % 5 == 0 {
                    presentedSeries.append(soldierPresentationCounts(in: scene).presented)
                }
            }
            seriesByStep[step] = presentedSeries
            // The marching pile stays readable at BOTH cadences — no
            // hidden-until-stopped regime at the coarse one (the old
            // frame-quantized easing parked it at ≤3 mid-march).
            #expect(presentedSeries.last ?? 0 >= 12)
        }
        // Same combat time → same bounded presentation: per-instant counts
        // may jitter by a member still gliding between cells, but never by
        // the everyone-hidden divergence frame-quantized easing produced.
        let fine = try #require(seriesByStep[0.05])
        let coarse = try #require(seriesByStep[0.25])
        #expect(fine.count == coarse.count)
        for (index, pair) in zip(fine, coarse).enumerated() {
            #expect(
                abs(pair.0 - pair.1) <= 4,
                "instant \(index): 0.05s cadence=\(pair.0) vs 0.25s cadence=\(pair.1)"
            )
        }
    }

    @Test func denseGateCasualtyFootprintStaysClearThroughRemoval() throws {
        // First casualty on the dense tower-alive fixture: the corpse plays
        // its authored hit/fade on the ground it died on. Its formation
        // cell stays RESERVED until removal — no promotion may glide into
        // the space the corpse still occupies, and a folded casualty
        // reveals at a collision-free cell rather than its parked slot.
        let city = 15
        let layout = Country1CityCatalog.definition(for: city).siegeLayout
        let maxPowers = layout.maxPowerAllocation(
            totalBudget: KingdomGameState.cityMaxPower(for: city)
        )
        let slots = Dictionary(
            uniqueKeysWithValues: (1...5).map { ($0, CityBuilding(type: .barracks, level: 8)) }
        )
        var state = KingdomGameState(
            gold: 100,
            cityNumberInCountry: city,
            completedCityCount: city - 1,
            cityBattleStates: [
                CityKey(countryNumber: 1, cityNumber: city).storageKey:
                    CityBattleState(slots: slots)
            ]
        )
        state.siegeProgress.selectedLane = .right
        SiegeTestSupport.setKeepRemaining(
            maxPowers[layout.keepObjective.id, default: 0], on: &state
        )
        state = captainless(state)

        let scene = makeScene(
            store: try makeStore(initialState: state),
            combatSeed: 1,
            size: CGSize(width: 393, height: 852)
        )
        scene.advanceCombatSingleStepForTesting(
            deltaTime: KingdomGameState.activeSpawnInterval(for: .barracks) * 4
        )
        #expect(scene.buildingLiveSoldierCountForTesting == 20)
        advanceCombatUntil(scene) {
            !scene.pendingAnimatedRemovalSoldierIDsForTesting.isEmpty
        }
        #expect(!scene.pendingAnimatedRemovalSoldierIDsForTesting.isEmpty)

        let clearance = scene.soldierTargetHeightForTesting * 0.35
        var presentedPrevious: [BattleCombatState.SoldierID: CGPoint] = [:]
        for _ in 0..<24 {
            scene.advanceCombatSingleStepForTesting(deltaTime: 0.05)
            let live = scene.liveSoldierCountForTesting
            let pending = scene.pendingAnimatedRemovalSoldierIDsForTesting
            #expect(scene.soldierNodeCountForTesting == live + pending.count)

            let presented = scene.soldierPresentationsForTesting.filter { !$0.isFolded }
            for corpseID in pending {
                let corpse = try #require(scene.soldierNodePresentationForTesting(corpseID))
                // A casualty that died rendered keeps the ground it fell
                // on; one that died folded reveals only collision-free
                // ground — when every candidate is contested it stays
                // hidden rather than landing on someone (round-3: reveals
                // never fail open). A reserved corpse is always visible.
                if let reserved = scene.soldierCorpseFootprintForTesting(corpseID) {
                    #expect(!corpse.isHidden)
                    // …and no living soldier PARKS on it — a member still
                    // gliding to its own seat may legitimately transit.
                    for member in presented {
                        let moved = presentedPrevious[member.id].map {
                            hypot(member.nodePosition.x - $0.x, member.nodePosition.y - $0.y) > 1
                        } ?? true
                        if !moved {
                            #expect(!reserved.contains(member.nodePosition))
                            #expect(hypot(
                                member.nodePosition.x - corpse.position.x,
                                member.nodePosition.y - corpse.position.y
                            ) > clearance)
                        }
                    }
                }
            }
            presentedPrevious = Dictionary(
                uniqueKeysWithValues: presented.map { ($0.id, $0.nodePosition) }
            )
            let counts = soldierPresentationCounts(in: scene)
            #expect(counts.presented + counts.folded == live + pending.count)
            #expect((overflowBadgeCount(in: scene, lane: .right) ?? 0) == counts.folded - counts.pendingHidden)
        }

        // Full teardown: once the removal animations complete (driven here
        // through the test seam — SpriteKit actions never advance under
        // advanceCombatForTesting), the reserved cells release and the node
        // ledger drops back to the live roster exactly.
        scene.completePendingAnimatedSoldierRemovalsForTesting()
        scene.advanceCombatSingleStepForTesting(deltaTime: 0.05)
        #expect(scene.pendingAnimatedRemovalSoldierIDsForTesting.isEmpty)
        #expect(scene.soldierNodeCountForTesting == scene.liveSoldierCountForTesting)
        let counts = soldierPresentationCounts(in: scene)
        #expect(counts.presented + counts.folded == scene.liveSoldierCountForTesting)
        #expect((overflowBadgeCount(in: scene, lane: .right) ?? 0) == counts.folded - counts.pendingHidden)
    }

    @Test func denseGateOldestFrontlineSoldierIsCombatTargetCandidate() throws {
        // Combat's `.max` foremost selection keeps roster precedence at a
        // shared stop position: the OLDEST soldier — lowest id — is the
        // defensive-fire candidate, not the lowest reused formation slot.
        // As waves die and respawn, low slots recycle onto new soldiers;
        // presentation must still keep the combat candidate rendered.
        let city = 15
        let layout = Country1CityCatalog.definition(for: city).siegeLayout
        let maxPowers = layout.maxPowerAllocation(
            totalBudget: KingdomGameState.cityMaxPower(for: city)
        )
        let slots = Dictionary(
            uniqueKeysWithValues: (1...5).map { ($0, CityBuilding(type: .barracks, level: 8)) }
        )
        var state = KingdomGameState(
            gold: 100,
            cityNumberInCountry: city,
            completedCityCount: city - 1,
            cityBattleStates: [
                CityKey(countryNumber: 1, cityNumber: city).storageKey:
                    CityBattleState(slots: slots)
            ]
        )
        state.siegeProgress.selectedLane = .right
        SiegeTestSupport.setKeepRemaining(
            maxPowers[layout.keepObjective.id, default: 0], on: &state
        )
        state = captainless(state)

        let scene = makeScene(
            store: try makeStore(initialState: state),
            combatSeed: 1,
            size: CGSize(width: 393, height: 852)
        )
        scene.advanceCombatSingleStepForTesting(
            deltaTime: KingdomGameState.activeSpawnInterval(for: .barracks) * 4
        )
        #expect(scene.buildingLiveSoldierCountForTesting == 20)

        var sharedStopSamples = 0
        for _ in 0..<240 {
            scene.advanceCombatSingleStepForTesting(deltaTime: 0.05)
            // The tower kills the FOREMOST — the oldest member at the
            // shared stop is routinely a pending corpse, which correctly
            // folds when no safe reveal exists. Combat's target candidate
            // is the foremost LIVE soldier, so pending removals are out.
            let pending = scene.pendingAnimatedRemovalSoldierIDsForTesting
            let lane = scene.soldierPresentationsForTesting.filter {
                $0.lane == .right && !pending.contains($0.id)
            }
            guard let maxPosition = lane.map(\.position).max() else { continue }
            let cohort = lane.filter { $0.position == maxPosition }
            // Only meaningful when several soldiers genuinely share the
            // stop position — the tie regime the finding is about.
            guard cohort.count > 1 else { continue }
            sharedStopSamples += 1
            // Combat picks the first maximal roster index: the lowest id.
            if let candidate = cohort.min(by: { $0.id < $1.id }) {
                let corpseRects = pending.map {
                    "\($0):\(scene.soldierCorpseFootprintForTesting($0) ?? .null)"
                }
                let cohortReport = cohort.map {
                    "\($0.id):\($0.isFolded ? "folded" : "presented")@\($0.nodePosition)"
                }
                let diagnostics = "seats=\(scene.soldierSeatFootprintsForTesting)"
                    + " corpses=\(corpseRects)"
                    + " fades=\(scene.fadingSoldierFootprintsForTesting)"
                    + " pending=\(pending) cohort=\(cohortReport)"
                #expect(
                    !candidate.isFolded,
                    "candidate \(candidate.id) folded; \(diagnostics)"
                )
            }
            // And the whole cohort presents in combat order: every
            // presented member must outrank every folded one, so the folded
            // remainder is always the newest soldiers at the shared stop —
            // never a recycled low slot evicting an older body.
            for presented in cohort where !presented.isFolded {
                for folded in cohort where folded.isFolded {
                    #expect(presented.id < folded.id)
                }
            }
        }
        #expect(sharedStopSamples >= 5)
    }

    @Test func overflowBadgePillContainsItsCount() throws {
        // The badge must fit whatever truthful count it reports: a fixed-
        // width pill behind an unrestricted decimal label lets large counts
        // spill off the contrasting background. Spawn past two digits so the
        // fit is exercised for real, then require the pill to cover the
        // label with padding inside the lane bounds.
        let state = try durableRightGateState(buildingCount: 5)
        let scene = makeScene(
            store: try makeStore(initialState: state),
            combatSeed: 1,
            size: CGSize(width: 393, height: 852)
        )
        // Staggered stalls grow the roster past three digits: each single
        // step resolves one spawn interval per Barracks.
        for _ in 0..<24 {
            scene.advanceCombatSingleStepForTesting(
                deltaTime: KingdomGameState.activeSpawnInterval(for: .barracks)
            )
        }
        #expect(scene.liveSoldierCountForTesting > 100)

        let badge = try #require(overflowBadge(in: scene, lane: .right))
        let folded = try #require(overflowBadgeCount(in: scene, lane: .right))
        #expect(folded > 0)
        let label = try #require(
            badge.children.compactMap({ $0 as? SKLabelNode }).first
        )
        #expect(label.text == "+\(folded)")
        let pill = try #require(
            badge.children.compactMap({ $0 as? SKShapeNode }).first
        )
        // The contrasting pill contains the whole label with padding —
        // at any count, not just two digits.
        #expect(pill.frame.width >= label.frame.width + 12)
        let battlefield = try #require(scene.battleChromeLayoutForTesting?.battlefieldFrame)
        #expect(battlefield.contains(badge.calculateAccumulatedFrame()))
    }

    @Test func overflowBadgeClearsOnBackgroundTeardown() throws {
        // clearLiveCombat removes every soldier root — the overflow badge
        // must leave with them. The background handler tears down without a
        // subsequent soldier sync, so a stale "+N" would sit in the cleared
        // scene and in the background snapshot.
        let state = try durableRightGateState(buildingCount: 5)
        let scene = makeScene(
            store: try makeStore(initialState: state),
            combatSeed: 1,
            size: CGSize(width: 393, height: 852)
        )
        scene.advanceCombatSingleStepForTesting(
            deltaTime: KingdomGameState.activeSpawnInterval(for: .barracks) * 4
        )
        scene.advanceCombatForTesting(deltaTime: 2.5)
        #expect(overflowBadge(in: scene, lane: .right) != nil)

        scene.enterBackgroundForTesting(at: Date(timeIntervalSince1970: 1_000))

        #expect(scene.soldierNodeCountForTesting == 0)
        #expect(overflowBadge(in: scene, lane: .right) == nil)
        #expect(overflowBadge(in: scene, lane: .left) == nil)
        #expect(overflowBadge(in: scene, lane: .center) == nil)
    }

    @Test func casualtyFadeRootsDetachOnTeardownAndResize() throws {
        // Round-3 review: fading roots are still PARENTED when the
        // reservation map clears — teardown that only drops the ledger
        // leaves ghost corpses rendering forever. Both teardown paths
        // must detach the roots, and the resize path lands their removal
        // explicitly (stale-coordinate ghosts). The tower-alive fixture
        // also exercises the defensive-shot protection clear for real.
        let city = 15
        let layout = Country1CityCatalog.definition(for: city).siegeLayout
        let maxPowers = layout.maxPowerAllocation(
            totalBudget: KingdomGameState.cityMaxPower(for: city)
        )
        let slots = Dictionary(
            uniqueKeysWithValues: (1...5).map { ($0, CityBuilding(type: .barracks, level: 8)) }
        )
        var state = KingdomGameState(
            gold: 100,
            cityNumberInCountry: city,
            completedCityCount: city - 1,
            cityBattleStates: [
                CityKey(countryNumber: 1, cityNumber: city).storageKey:
                    CityBattleState(slots: slots)
            ]
        )
        state.siegeProgress.selectedLane = .right
        SiegeTestSupport.setKeepRemaining(
            maxPowers[layout.keepObjective.id, default: 0], on: &state
        )
        state = captainless(state)

        let scene = makeScene(
            store: try makeStore(initialState: state),
            combatSeed: 1,
            size: CGSize(width: 393, height: 852)
        )
        scene.advanceCombatSingleStepForTesting(
            deltaTime: KingdomGameState.activeSpawnInterval(for: .barracks) * 4
        )
        advanceCombatUntil(scene) {
            scene.lastTowerShotSoldierIDForTesting != nil
                && !scene.pendingAnimatedRemovalSoldierIDsForTesting.isEmpty
        }
        // The tower really fired — protection was exercised for real.
        #expect(scene.lastTowerShotSoldierIDForTesting != nil)

        let corpseID = try #require(scene.pendingAnimatedRemovalSoldierIDsForTesting.first)
        scene.removeSoldierNodeForTesting(id: corpseID, animated: true)
        let fadingRoot = try #require(scene.fadingSoldierRootsForTesting.first)
        #expect(fadingRoot.parent != nil)

        // A resize while the fade is in flight explicitly lands the
        // removal — the old coordinate system cannot host a stale ghost.
        scene.size = CGSize(width: 375, height: 667)
        scene.refreshLayoutForCurrentEnvironment()
        #expect(scene.fadingSoldierFootprintCountForTesting == 0)
        #expect(fadingRoot.parent == nil)

        // Same for background teardown while a second fade is in flight —
        // and it clears the shot-target protection ledger too.
        let secondID = try #require(scene.soldierPresentationsForTesting.first?.id)
        scene.removeSoldierNodeForTesting(id: secondID, animated: true)
        let secondRoot = try #require(scene.fadingSoldierRootsForTesting.first)
        #expect(secondRoot.parent != nil)
        scene.enterBackgroundForTesting(at: Date(timeIntervalSince1970: 1_000))
        #expect(scene.fadingSoldierFootprintCountForTesting == 0)
        #expect(secondRoot.parent == nil)
        #expect(scene.lastTowerShotSoldierIDForTesting == nil)
    }

    // MARK: Rendered-ground reservation (HPA-812 Task 3 round 2)

    /// Scene-space body∪HP-bar footprint of every soldier root that is
    /// actually RENDERING this frame — presented members, pending corpses,
    /// and fading-removal roots alike. This is the disjointness unit the
    /// round-3 stable-seat model must keep converged-clean: seats are
    /// mutually exclusive by construction, so a parked member never
    /// overlaps anything — only a member still in transit may.
    private func renderedSoldierFootprints(
        in scene: BattleScene
    ) -> [(node: SKNode, rect: CGRect)] {
        var footprints: [(node: SKNode, rect: CGRect)] = []
        scene.enumerateChildNodes(withName: "//normal-soldier") { node, _ in
            guard
                !node.isHidden,
                node.children.contains(where: { $0 is SKShapeNode && $0.zPosition == 2 }),
                let body = node.children.first(where: { $0.zPosition == 1 }),
                let bar = node.children
                    .compactMap({ $0 as? SKShapeNode })
                    .first(where: { $0.zPosition == 2 }),
                let barPath = bar.path
            else { return }
            // The footprint is everything the node can actually draw: the
            // body node's own accumulated frame — the FULL animation
            // canvas for canvas sprites, so wider attack/hit poses and
            // the Captain banner are inside it, and no per-type geometry
            // constant is baked in — unioned with the HP bar's path
            // bounds.
            let bodyRect = sceneRect(
                of: body.calculateAccumulatedFrame(),
                in: node,
                scene: scene
            )
            footprints.append((
                node,
                bodyRect.union(sceneRect(of: barPath.boundingBox, in: node, scene: scene))
            ))
        }
        return footprints
    }

    /// One sync's worth of the round-3 stable-seat contract, asserted from
    /// rendered state — not from the production formula:
    /// * every rendered member's claimed seat CELL is pairwise disjoint
    ///   from the others AND from every corpse/fade reservation;
    /// * a member that did not move this sync is CONVERGED — its READABLE
    ///   footprint (logical body ∪ HP bar, the unit seats are pitched on)
    ///   overlaps no other readable footprint and no reserved ground;
    /// * any residual overlap involves a member still in transit and must
    ///   clear within `transitLimit` consecutive syncs — a pair parked
    ///   overlapping is a real bug, not an exemption.
    /// The full animation canvas is intentionally NOT the member
    /// disjointness unit: attack/hit reach is transient pose art. Corpses
    /// and fades keep their ACTUAL canvas reservations — seats and
    /// readable bodies must stay off them.
    /// Returns whether any member moved (for non-vacuousness counters).
    @discardableResult
    private func assertStableSeatContract(
        in scene: BattleScene,
        previousPositions: inout [BattleCombatState.SoldierID: CGPoint],
        overlapStreaks: inout [String: Int],
        transitLimit: Int = 15
    ) -> Bool {
        let members = scene.soldierReadableFootprintsForTesting
        let seatRects = Array(scene.soldierSeatFootprintsForTesting.values)
        // Reservations are the corpses'/fades' ACTUAL canvas footprints.
        // Live members only — a corpse's own root is not in `members`, so
        // self-intersection is impossible by construction.
        var reservations: [CGRect] = []
        for id in scene.pendingAnimatedRemovalSoldierIDsForTesting {
            if let rect = scene.soldierCorpseFootprintForTesting(id) {
                reservations.append(rect)
            }
        }
        reservations.append(contentsOf: scene.fadingSoldierFootprintsForTesting)

        // Seats: exclusive by construction and corpse-free — the invariant
        // that makes parked bodies + bars impossible to merge.
        for index in seatRects.indices {
            for other in seatRects.indices where other > index {
                #expect(
                    !seatRects[index].intersects(seatRects[other]),
                    "claimed seats overlap: \(seatRects[index]) vs \(seatRects[other])"
                )
            }
            for reservation in reservations {
                #expect(
                    !seatRects[index].intersects(reservation),
                    "seat \(seatRects[index]) overlaps corpse/fade \(reservation)"
                )
            }
        }

        var stationary = Set<BattleCombatState.SoldierID>()
        var moved = false
        for member in members {
            if let before = previousPositions[member.id],
               hypot(
                member.position.x - before.x,
                member.position.y - before.y
               ) <= 1 {
                stationary.insert(member.id)
            } else {
                moved = true
            }
        }
        previousPositions = Dictionary(
            uniqueKeysWithValues: members.map { ($0.id, $0.position) }
        )

        // Two CONVERGED members never overlap — parked bodies are the bug
        // the seat model exists to prevent. A member still in transit may
        // legitimately brush a seated one (paths are not reservations);
        // the streak bound below is what keeps that transient.
        for entry in members where stationary.contains(entry.id) {
            for other in members
            where other.id != entry.id && stationary.contains(other.id) {
                #expect(
                    !entry.rect.intersects(other.rect),
                    "converged members parked overlapping: \(entry.rect) vs \(other.rect)"
                )
            }
            // A live member never parks on corpse/fade ground either.
            for reservation in reservations {
                #expect(
                    !entry.rect.intersects(reservation),
                    "converged member \(entry.rect) overlaps corpse/fade \(reservation)"
                )
            }
        }

        // Transit bound: any overlap that DOES occur must resolve inside
        // the bounded glide window — parked overlap is the bug.
        var nextStreaks: [String: Int] = [:]
        for index in members.indices {
            for other in members.indices where other > index {
                guard members[index].rect.intersects(members[other].rect) else {
                    continue
                }
                let key = "\(members[index].id):\(members[other].id)"
                let streak = (overlapStreaks[key] ?? 0) + 1
                #expect(
                    streak <= transitLimit,
                    "footprint overlap parked \(streak) syncs: \(members[index].rect) vs \(members[other].rect)"
                )
                nextStreaks[key] = streak
            }
            for (corpseIndex, reservation) in reservations.enumerated()
            where members[index].rect.intersects(reservation) {
                let key = "\(members[index].id):corpse\(corpseIndex)"
                let streak = (overlapStreaks[key] ?? 0) + 1
                #expect(
                    streak <= transitLimit,
                    "corpse overlap parked \(streak) syncs: \(members[index].rect) vs \(reservation)"
                )
                nextStreaks[key] = streak
            }
        }
        overlapStreaks = nextStreaks
        return moved
    }

    @Test func denseGateStableSeatsStayExclusiveWithOnlyTransientOverlap() throws {
        // N1 repro under the round-3 stable-seat model: no path solver —
        // seats are exclusive by construction, converged members never
        // overlap, and transit overlap must resolve in bounded time.
        // Marching, re-slots, and a mid-run deploy all count.
        let state = try durableRightGateState(buildingCount: 5)
        let scene = makeScene(
            store: try makeStore(initialState: state),
            combatSeed: 1,
            size: CGSize(width: 393, height: 852)
        )
        scene.advanceCombatSingleStepForTesting(
            deltaTime: KingdomGameState.activeSpawnInterval(for: .barracks) * 4
        )
        scene.advanceCombatForTesting(deltaTime: 2.5)
        #expect(scene.liveSoldierCountForTesting == 20)

        // A second wave marches in: the merge regime re-slots and promotes
        // members every tick while the seat contract must hold.
        scene.advanceCombatSingleStepForTesting(
            deltaTime: KingdomGameState.activeSpawnInterval(for: .barracks) * 2
        )
        #expect(scene.liveSoldierCountForTesting == 30)

        var previousPositions: [BattleCombatState.SoldierID: CGPoint] = [:]
        var overlapStreaks: [String: Int] = [:]
        var glidingTicks = 0
        var seatCountSeen = 0
        for _ in 0..<70 {
            scene.advanceCombatSingleStepForTesting(deltaTime: 0.05)
            #expect(scene.soldierReadableFootprintsForTesting.count >= 6)
            seatCountSeen = max(seatCountSeen, scene.soldierSeatFootprintsForTesting.count)
            if assertStableSeatContract(
                in: scene,
                previousPositions: &previousPositions,
                overlapStreaks: &overlapStreaks
            ) {
                glidingTicks += 1
            }
        }

        // The review repro: a fresh deploy behind the occupied pile — the
        // zero-elapsed deploy sync already ran inside spawn, so the FIRST
        // frame after it must already satisfy the seat contract.
        scene.selectManualSoldierTypeForTesting(.infantry)
        scene.spawnManualSoldiersDirectlyForTesting(1)
        #expect(scene.liveSoldierCountForTesting == 31)
        _ = assertStableSeatContract(
            in: scene,
            previousPositions: &previousPositions,
            overlapStreaks: &overlapStreaks
        )
        for _ in 0..<30 {
            scene.advanceCombatSingleStepForTesting(deltaTime: 0.05)
            #expect(scene.soldierReadableFootprintsForTesting.count >= 6)
            if assertStableSeatContract(
                in: scene,
                previousPositions: &previousPositions,
                overlapStreaks: &overlapStreaks
            ) {
                glidingTicks += 1
            }
        }

        // Non-vacuous: the lane really ran a multi-seat formation with
        // members in motion across most of the run — the seat contract
        // covered actual transitions, not a parked formation.
        #expect(seatCountSeen >= 6)
        #expect(glidingTicks >= 10)
    }

    @Test func denseGateCasualtyKeepsActualFootprintThroughAuthoredFade() throws {
        // N2: the corpse reservation was its nearest grid CELL — a moving
        // grid detached it from where the body really sat — and it ended
        // when the bundle left soldierNodes, before the 0.18 s fade did.
        // The reservation must be the corpse's REAL rect, held until the
        // node is actually gone.
        let city = 15
        let layout = Country1CityCatalog.definition(for: city).siegeLayout
        let maxPowers = layout.maxPowerAllocation(
            totalBudget: KingdomGameState.cityMaxPower(for: city)
        )
        let slots = Dictionary(
            uniqueKeysWithValues: (1...5).map { ($0, CityBuilding(type: .barracks, level: 8)) }
        )
        var state = KingdomGameState(
            gold: 100,
            cityNumberInCountry: city,
            completedCityCount: city - 1,
            cityBattleStates: [
                CityKey(countryNumber: 1, cityNumber: city).storageKey:
                    CityBattleState(slots: slots)
            ]
        )
        state.siegeProgress.selectedLane = .right
        SiegeTestSupport.setKeepRemaining(
            maxPowers[layout.keepObjective.id, default: 0], on: &state
        )
        state = captainless(state)

        let scene = makeScene(
            store: try makeStore(initialState: state),
            combatSeed: 1,
            size: CGSize(width: 393, height: 852)
        )
        scene.advanceCombatSingleStepForTesting(
            deltaTime: KingdomGameState.activeSpawnInterval(for: .barracks) * 4
        )
        #expect(scene.buildingLiveSoldierCountForTesting == 20)
        // A casualty that died FOLDED legitimately retries its reveal
        // while every spot is contested (no fail-open); the lifecycle this
        // test inspects needs a casualty that actually holds reserved
        // ground — wait for one that died rendered or revealed cleanly.
        advanceCombatUntil(scene) {
            scene.pendingAnimatedRemovalSoldierIDsForTesting.contains {
                scene.soldierCorpseFootprintForTesting($0) != nil
            }
        }
        let corpseID = try #require(
            scene.pendingAnimatedRemovalSoldierIDsForTesting.first {
                scene.soldierCorpseFootprintForTesting($0) != nil
            }
        )
        let corpse = try #require(scene.soldierNodePresentationForTesting(corpseID))
        #expect(!corpse.isHidden)
        #expect(scene.soldierCorpseStateForTesting(corpseID)?.revealed == true)
        // The authored hit-then-remove SKAction really is the lifecycle
        // driver — SpriteKit actions never advance under test stepping, so
        // asserting the queued action exists is the timing evidence (the
        // landing below runs the same removeSoldierNode the action calls).
        #expect(scene.soldierNodeHasDelayedRemovalActionForTesting(corpseID))
        let corpseRect = try #require(scene.soldierCorpseFootprintForTesting(corpseID))

        // The reservation is the corpse's REAL rendered footprint: it
        // contains the body+bar actually on screen — not just the grid
        // cell nearest it — and stays put while the grid keeps marching.
        let corpseFootprint = try #require(
            renderedSoldierFootprints(in: scene).first(where: {
                abs($0.node.position.x - corpse.position.x) < 0.5
                    && abs($0.node.position.y - corpse.position.y) < 0.5
            })?.rect
        )
        // The reservation is a formula rect; the measured footprint goes
        // through the sprite's accumulated frame + CGPath.boundingBox —
        // same value, different CGFloat pipeline, so single-precision
        // dust (~3e-5 pt) shows up on every edge. Inflating by 1/20 pt
        // forgives that dust while still catching any REAL containment
        // leak (a cell-anchored rect misses by whole points).
        #expect(corpseRect.insetBy(dx: -0.05, dy: -0.05).contains(corpseFootprint))

        // Through the authored hit window the reservation holds: a member
        // parked on the corpse's ground is a bug; a member still gliding
        // to its seat may legitimately transit across in bounded time.
        // Readable footprints are LIVE members only — the corpse's own
        // root self-excludes, so no owner-skip is needed.
        var previousPositions: [BattleCombatState.SoldierID: CGPoint] = [:]
        var overlapStreaks: [String: Int] = [:]
        for _ in 0..<10 {
            scene.advanceCombatSingleStepForTesting(deltaTime: 0.05)
            guard let reserved = scene.soldierCorpseFootprintForTesting(corpseID) else {
                break
            }
            let members = scene.soldierReadableFootprintsForTesting
            for entry in members {
                let stationary = previousPositions[entry.id].map {
                    hypot(entry.position.x - $0.x, entry.position.y - $0.y) <= 1
                } ?? false
                if stationary {
                    #expect(
                        !entry.rect.intersects(reserved),
                        "parked member \(entry.rect) on corpse \(reserved)"
                    )
                } else {
                    let streak = (overlapStreaks["\(entry.id)"] ?? 0) + 1
                    #expect(
                        streak <= 15,
                        "member transit across corpse parked \(streak) syncs"
                    )
                    overlapStreaks["\(entry.id)"] = streak
                }
            }
            previousPositions = Dictionary(
                uniqueKeysWithValues: members.map { ($0.id, $0.position) }
            )
        }

        // The authored delayed-removal landing — animated: true is the
        // production fade the delayed-removal SKAction performs: bundle
        // leaves soldierNodes but the ground stays reserved while the
        // 0.18 s fade still renders, and the root is still parented.
        scene.removeSoldierNodeForTesting(id: corpseID, animated: true)
        #expect(scene.soldierNodePresentationForTesting(corpseID) == nil)
        #expect(scene.fadingSoldierFootprintCountForTesting == 1)
        #expect(scene.fadingSoldierRootsForTesting.first?.parent != nil)
        let fadingRect = try #require(scene.fadingSoldierFootprintsForTesting.first)
        #expect(fadingRect == corpseRect)

        for _ in 0..<4 {
            scene.advanceCombatSingleStepForTesting(deltaTime: 0.05)
            #expect(scene.fadingSoldierFootprintCountForTesting == 1)
            #expect(scene.fadingSoldierRootsForTesting.first?.parent != nil)
            // Live readable footprints only — the fading root self-excludes.
            for entry in scene.soldierReadableFootprintsForTesting {
                #expect(!entry.rect.intersects(fadingRect))
            }
        }

        // The fade's landing releases the ground exactly when the node
        // detaches: after it, the ledger drops to live + pending.
        scene.finishFadingSoldierRemovalsForTesting()
        #expect(scene.fadingSoldierFootprintCountForTesting == 0)
        scene.advanceCombatSingleStepForTesting(deltaTime: 0.05)
        #expect(
            scene.soldierNodeCountForTesting
                == scene.liveSoldierCountForTesting
                    + scene.pendingAnimatedRemovalSoldierIDsForTesting.count
        )
    }

    @Test func pausedResizeReplacesSoldierGroundInNewCoordinates() throws {
        // N3: layoutInterface re-syncs with zero elapsed — combat-time
        // glides can never repair stale coordinates while ticking is
        // paused (Settings open). On the FIRST resized frame every
        // rendered root must already sit in the new coordinate system.
        let state = try durableRightGateState(buildingCount: 5)
        let scene = makeScene(
            store: try makeStore(initialState: state),
            combatSeed: 1,
            size: CGSize(width: 430, height: 932)
        )
        scene.advanceCombatSingleStepForTesting(
            deltaTime: KingdomGameState.activeSpawnInterval(for: .barracks) * 4
        )
        scene.advanceCombatForTesting(deltaTime: 2.5)
        #expect(scene.liveSoldierCountForTesting == 20)

        let oldBattlefield = try #require(
            scene.battleChromeLayoutForTesting?.battlefieldFrame
        )
        let oldPositions = Set(
            renderedSoldierFootprints(in: scene).map(\.node.position)
        )

        // Settings open = paused combat: no tick can run between the
        // resize and these first-frame assertions. A milestone-arrival
        // panel (city 15 presents one) would eat the first touch as a
        // dismissal, so clear it through the real dismiss path first.
        scene.dismissMilestoneArrivalForTesting()
        scene.handleTouchForTesting(
            at: try #require(scene.feedbackSettingsGearFrameForTesting).center
        )
        #expect(scene.isFeedbackSettingsVisibleForTesting)

        scene.size = CGSize(width: 375, height: 667)
        scene.refreshLayoutForCurrentEnvironment()
        let newBattlefield = try #require(
            scene.battleChromeLayoutForTesting?.battlefieldFrame
        )
        #expect(newBattlefield != oldBattlefield)

        // First resized frame, still paused: every rendered body+bar is
        // already inside the NEW field and pairwise disjoint — no stale-
        // coordinate stragglers waiting for a glide that cannot run. The
        // READABLE footprint (logical body ∪ bar) is the containment
        // unit — transient canvas reach is pose art, not stale coords.
        let footprints = scene.soldierReadableFootprintsForTesting
        #expect(footprints.count >= 8)
        for entry in footprints {
            #expect(
                newBattlefield.contains(entry.rect),
                "rendered footprint \(entry.rect) outside resized battlefield \(newBattlefield)"
            )
        }
        for index in footprints.indices {
            for other in footprints.indices where other > index {
                #expect(
                    !footprints[index].rect.intersects(footprints[other].rect),
                    "rendered soldier footprints overlap: \(footprints[index].rect) vs \(footprints[other].rect)"
                )
            }
        }
        let moved = footprints.filter {
            !oldPositions.contains($0.position)
        }
        #expect(!moved.isEmpty)

        // Accounting still lands: live+pending nodes and a truthful badge.
        let live = scene.liveSoldierCountForTesting
        let pending = scene.pendingAnimatedRemovalSoldierIDsForTesting.count
        #expect(scene.soldierNodeCountForTesting == live + pending)
        let counts = soldierPresentationCounts(in: scene)
        #expect(counts.presented + counts.folded == live + pending)
        #expect((overflowBadgeCount(in: scene, lane: .right) ?? 0) == counts.folded - counts.pendingHidden)
    }

    @Test func denseGateGenuinelyStaggeredSpawnsStayDisjointEachArrival() throws {
        // Review gap: prior staggered tests used whole-interval stalls —
        // five Barracks resolving at once is a BURST, not staggered
        // production. Per-slot spawnTimerElapsed offsets make a genuinely
        // staggered stream: one Barracks fires every ~2 s, so each arrival
        // lands in a formation that is already moving.
        let city = 15
        let layout = Country1CityCatalog.definition(for: city).siegeLayout
        let maxPowers = layout.maxPowerAllocation(
            totalBudget: KingdomGameState.cityMaxPower(for: city)
        )
        let interval = KingdomGameState.activeSpawnInterval(for: .barracks)
        let slots = Dictionary(
            uniqueKeysWithValues: (1...5).map {
                (
                    $0,
                    CityBuilding(
                        type: .barracks,
                        level: 8,
                        spawnTimerElapsed: Double($0 - 1) * interval / 5
                    )
                )
            }
        )
        var state = KingdomGameState(
            gold: 100,
            cityNumberInCountry: city,
            completedCityCount: city - 1,
            cityBattleStates: [
                CityKey(countryNumber: 1, cityNumber: city).storageKey:
                    CityBattleState(slots: slots)
            ]
        )
        state.siegeProgress.selectedLane = .right
        SiegeTestSupport.setKeepRemaining(
            maxPowers[layout.keepObjective.id, default: 0], on: &state
        )
        state = captainless(state)
        let towerID = try #require(
            layout.objectives.first { $0.kind == .arrowTower }?.id
        )
        state.siegeProgress.damageByObjectiveID[towerID] = maxPowers[towerID, default: 0]

        let scene = makeScene(
            store: try makeStore(initialState: state),
            combatSeed: 1,
            size: CGSize(width: 393, height: 852)
        )

        var previousLive = 0
        var arrivalTicks = 0
        var previousPositions: [BattleCombatState.SoldierID: CGPoint] = [:]
        var overlapStreaks: [String: Int] = [:]
        var glidingTicks = 0
        // 20 s at 20-tick granularity: with 2 s-staggered timers the lane
        // sees ~10 distinct arrival ticks across two production rounds,
        // never a whole-interval burst.
        for _ in 0..<400 {
            scene.advanceCombatSingleStepForTesting(deltaTime: 0.05)
            let live = scene.liveSoldierCountForTesting
            if live > previousLive {
                arrivalTicks += 1
            }
            previousLive = live
            if assertStableSeatContract(
                in: scene,
                previousPositions: &previousPositions,
                overlapStreaks: &overlapStreaks
            ) {
                glidingTicks += 1
            }
        }

        // Non-vacuous: arrivals really were staggered across several ticks
        // (not one stall-resolved burst — the burst shape lands ≤2 arrival
        // ticks), the roster actually grew well past the initial wave
        // (two production rounds at 10 s intervals ≈ 10 soldiers), and the
        // formation was in motion while the seat contract held.
        #expect(arrivalTicks >= 5)
        #expect(glidingTicks >= 20)
        #expect(scene.liveSoldierCountForTesting >= 8)
    }

    @Test func overflowBadgeFitsTruthfulCountsInsideLaneAndField() throws {
        // The round-1 three-digit test died at its >100-soldier
        // prerequisite, so containment past two digits was never actually
        // exercised. Drive the REAL badge sync at counts no live battle
        // can reach — the pill must still cover the exact label, stay
        // lane-bounded, and keep the badge inside the battlefield — and
        // do it at every layout class, not just the 393×852 the earlier
        // version proved.
        let state = try durableRightGateState(buildingCount: 5)
        for size in [
            CGSize(width: 393, height: 852),
            CGSize(width: 393, height: 700),
            // 375×667 is the narrowest compact class the chrome can fit —
            // anything shorter than ~652pt is genuinely unsupported
            // geometry (the app presents the unsupported-geometry gate,
            // not a battlefield), so it cannot host a badge assertion.
            CGSize(width: 375, height: 667)
        ] {
            let scene = makeScene(
                store: try makeStore(initialState: state),
                combatSeed: 1,
                size: size
            )
            let battlefield = try #require(scene.battleChromeLayoutForTesting?.battlefieldFrame)
            let laneWidth = battlefield.width / 3
            for count in [123, 4_567, 98_765, Int.max] {
                scene.updateSoldierOverflowBadgeForTesting(lane: .right, foldedCount: count)
                let badge = try #require(overflowBadge(in: scene, lane: .right))
                let label = try #require(
                    badge.children.compactMap({ $0 as? SKLabelNode }).first
                )
                // The count is truthful and exact — never truncated.
                #expect(label.text == "+\(count)")
                let pill = try #require(
                    badge.children.compactMap({ $0 as? SKShapeNode }).first
                )
                // The contrasting pill covers the whole label with
                // padding, and never outgrows its lane column.
                #expect(pill.frame.width >= label.frame.width + 12)
                #expect(pill.frame.width <= laneWidth + 0.5)
                #expect(
                    battlefield.contains(badge.calculateAccumulatedFrame()),
                    "size \(size): badge \(badge.calculateAccumulatedFrame()) outside \(battlefield)"
                )
            }
        }
    }

    @Test func denseGateHiddenRosterSyncCostStaysRepresentative() throws {
        // Perf smoke: presentation work is bounded per sync — a rank sort
        // plus O(1) seat bookkeeping per member and O(capacity) cell
        // marking — never O(live²) collision/path work. Three roster
        // sizes must each complete 30 ticks in a fraction of a second on
        // a debug build; this is a bound, not a microbenchmark, and the
        // numbers are reported in the task report rather than tuned.
        let state = try durableRightGateState(buildingCount: 5)
        let interval = KingdomGameState.activeSpawnInterval(for: .barracks)
        var timings: [(roster: Int, elapsed: TimeInterval)] = []
        for stallRounds in [10, 19, 30] {
            let scene = makeScene(
                store: try makeStore(initialState: state),
                combatSeed: 1,
                size: CGSize(width: 393, height: 852)
            )
            for _ in 0..<stallRounds {
                scene.advanceCombatSingleStepForTesting(deltaTime: interval)
            }
            let roster = scene.liveSoldierCountForTesting
            let start = Date()
            for _ in 0..<30 {
                scene.advanceCombatSingleStepForTesting(deltaTime: 0.05)
            }
            timings.append((roster, Date().timeIntervalSince(start)))
        }
        // Every size ran a genuinely large hidden roster — the lane is
        // mostly folded members whose bookkeeping must stay O(1).
        #expect(timings[0].roster >= 45)
        #expect(timings[1].roster >= 90)
        #expect(timings[2].roster >= 140)
        for timing in timings {
            #expect(
                timing.elapsed < 2.5,
                "30 ticks at \(timing.roster) live took \(timing.elapsed)s"
            )
        }
        // Tripling the roster must not multiply the per-tick cost —
        // seconds-level scaling differences are the O(live²) signature.
        #expect(
            timings[2].elapsed < timings[0].elapsed * 4 + 1.0,
            "cost scales worse than ~linear: \(timings.map { "\($0.roster):\(String(format: "%.2f", $0.elapsed))s" })"
        )
    }

    @Test func soldiersSharingALaneDoNotRenderAtTheSamePoint() throws {
        let store = try makeStore(initialState: stateWithBarracks(gold: 100, keepRemaining: 1_000))
        let scene = makeScene(store: store)

        // Sharing/lane separation is the subject here; six soldiers are
        // injected straight into the roster because the transient charge
        // pool only allows three real taps.
        scene.spawnManualSoldiersDirectlyForTesting(6)

        let placementsByLane = Dictionary(grouping: scene.soldierLanePlacementsForTesting, by: \.lane)
        #expect(scene.soldierLanePlacementsForTesting.count == 6)
        #expect(placementsByLane.values.contains { $0.count > 1 })
        for placements in placementsByLane.values where placements.count > 1 {
            for firstIndex in placements.indices {
                for secondIndex in placements.indices where secondIndex > firstIndex {
                    let first = placements[firstIndex].nodePosition
                    let second = placements[secondIndex].nodePosition
                    #expect(
                        hypot(first.x - second.x, first.y - second.y)
                            >= scene.soldierTargetHeightForTesting * 0.25
                    )
                }
            }
        }
    }

    @Test func approvedMageFullCanvasPreservesLogicalBodyHeight() throws {
        let store = try makeStore(
            initialState: stateWithBuildings([.mageTower], gold: 100, keepRemaining: 1_000)
        )
        let scene = makeScene(store: store)

        scene.selectManualSoldierTypeForTesting(.mage)
        scene.spawnSoldierForTesting()

        let bodyFrame = try #require(scene.firstLiveSoldierBodyFrameForTesting)
        let hpFrame = try #require(scene.firstLiveSoldierHPBarFrameForTesting)
        let geometry = SoldierAnimationGeometry(type: .mage)
        let expectedFrameSize = geometry.frameSize(
            forBodyHeight: scene.soldierTargetHeightForTesting
        )
        let placement = try #require(scene.soldierLanePlacementsForTesting.first)
        let logicalBodyTop = placement.nodePosition.y + geometry.logicalBodyFrame(frameSize: expectedFrameSize).maxY

        #expect(abs(bodyFrame.width - expectedFrameSize.width) < 0.001)
        #expect(abs(bodyFrame.height - expectedFrameSize.height) < 0.001)
        #expect(hpFrame.width >= 36)
        #expect(hpFrame.width <= 56)
        #expect(hpFrame.minY - logicalBodyTop >= 0)
        #expect(hpFrame.minY - logicalBodyTop <= 1.5)
    }

    @Test func approvedSiegeFullCanvasPreservesLogicalBodyHeight() throws {
        let store = try makeStore(
            initialState: stateWithBuildings([.siegeWorkshop], gold: 100, keepRemaining: 1_000)
        )
        let scene = makeScene(store: store)

        scene.selectManualSoldierTypeForTesting(.siege)
        scene.spawnSoldierForTesting()

        let bodyFrame = try #require(scene.firstLiveSoldierBodyFrameForTesting)
        let expectedFrameSize = SoldierAnimationGeometry(type: .siege).frameSize(
            forBodyHeight: scene.soldierTargetHeightForTesting
        )

        #expect(abs(bodyFrame.width - expectedFrameSize.width) < 0.001)
        #expect(abs(bodyFrame.height - expectedFrameSize.height) < 0.001)
    }

    @Test func layoutGateResumePrimesBattleClockWithoutPausedDelta() throws {
        let scene = try makeScene()

        scene.update(10)
        #expect(scene.lastUpdateTimeForTesting == 10)

        scene.layoutGateWillPause(at: Date(timeIntervalSinceReferenceDate: 19))
        scene.layoutGateWillResume(at: Date(timeIntervalSinceReferenceDate: 20))
        #expect(scene.lastUpdateTimeForTesting == nil)

        scene.update(10_000)
        #expect(scene.lastUpdateTimeForTesting == 10_000)
        #expect(scene.lastAdvanceCombatDeltaForTesting == nil)
    }

    @Test func laneIndicatorsMarkFortifiedAndExposedLanesOnly() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 30))
        let scene = makeScene(store: store)

        // City 1: left fortified, center standard, right exposed.
        let indicators = scene.laneIndicatorsForTesting
        #expect(indicators.count == 2)

        let fortified = try #require(indicators.first { $0.role == .fortified })
        let exposed = try #require(indicators.first { $0.role == .exposed })
        let leftGateX = try #require(scene.enemyGatePointForTesting(lane: .left)?.x)
        let rightGateX = try #require(scene.enemyGatePointForTesting(lane: .right)?.x)

        #expect(abs(fortified.position.x - leftGateX) <= 0.5)
        #expect(abs(exposed.position.x - rightGateX) <= 0.5)
        #expect(indicators.allSatisfy { $0.role != .standard })
    }

    @Test func backdropCoversFullScene() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 30))
        let scene = makeScene(store: store)

        guard let backdropFrame = scene.battlefieldBackdropFrameForTesting else {
            // No backdrop asset bundled — nothing to assert.
            return
        }

        #expect(backdropFrame.minX <= 0)
        #expect(backdropFrame.maxX >= scene.size.width)
        #expect(backdropFrame.minY <= 0)
        #expect(backdropFrame.maxY >= scene.size.height)
    }

    @Test func forgedAtmosphereWarmsTheFullBackdropBehindGameplay() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 30))
        let scene = makeScene(store: store)
        let atmosphere = try #require(
            scene.childNode(withName: "//battleForgedAtmosphere") as? SKSpriteNode
        )

        #expect(atmosphere.size == scene.size)
        #expect(atmosphere.position == CGPoint(x: scene.size.width / 2, y: scene.size.height / 2))
        #expect(atmosphere.blendMode == .alpha)
        #expect(atmosphere.texture != nil)
        #expect(atmosphere.colorBlendFactor == 0)
        #expect(abs(atmosphere.alpha - 1) < 0.001)
        #expect(atmosphere.zPosition == GameUITheme.Z.background + 1)

        let firstTexture = try #require(atmosphere.texture)
        scene.refreshLayoutForCurrentEnvironment()
        let secondTexture = try #require(atmosphere.texture)
        #expect(firstTexture === secondTexture)
    }

    @Test func forgedAtmosphereKeepsTheInsetVignetteAtThePhoneEdges() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 30))
        let scene = makeScene(store: store, size: CGSize(width: 393, height: 852))
        let atmosphere = try #require(
            scene.childNode(withName: "//battleForgedAtmosphere") as? SKSpriteNode
        )
        let texture = try #require(atmosphere.texture)
        let center = try #require(pixel(in: texture, normalized: CGPoint(x: 0.5, y: 0.5)))
        let nearEdge = try #require(pixel(in: texture, normalized: CGPoint(x: 0.25, y: 0.5)))
        let edge = try #require(pixel(in: texture, normalized: CGPoint(x: 0.02, y: 0.5)))

        #expect(nearEdge[3] > center[3] + 8)
        #expect(edge[3] > nearEdge[3] + 12)
        #expect(edge[3] > center[3] + 24)
        #expect(edge[0] < 70)
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

    private func makeScene(
        store: KingdomGameStore,
        router: BattleSceneRouting? = nil,
        combatSeed: UInt64? = nil,
        launchArguments: [String]? = nil,
        size: CGSize = CGSize(width: 390, height: 844),
        feedback: GameplayFeedbackProviding? = nil,
        feedbackPreferences: FeedbackPreferencesManaging? = nil,
        feedbackSettingsAccessibilityAdapter: FeedbackSettingsAccessibilityAdapter? = nil
    ) -> BattleScene {
        let resolvedFeedback = feedback ?? NoOpGameplayFeedbackProvider()
        let resolvedFeedbackPreferences = feedbackPreferences ?? makePreferencesStore()
        let scene = BattleScene(
            size: size,
            store: store,
            router: router,
            feedback: resolvedFeedback,
            feedbackPreferences: resolvedFeedbackPreferences,
            feedbackSettingsAccessibilityAdapter: feedbackSettingsAccessibilityAdapter,
            launchArguments: launchArguments,
            combatSeed: combatSeed
        )
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        scene.didMove(to: view)
        return scene
    }

    private func makeScene() throws -> BattleScene {
        makeScene(store: try makeStore(initialState: .init()))
    }

    private func makeStore(initialState: KingdomGameState) throws -> KingdomGameStore {
        let suiteName = "PyxisTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let store = KingdomGameStore(defaults: defaults, key: "state")
        store.save(initialState)
        return store
    }

    private func makePreferencesStore() -> FeedbackPreferencesStore {
        let suiteName = "PyxisTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return FeedbackPreferencesStore(defaults: defaults, keyPrefix: "prefs")
    }

    private func stateWithBarracks(
        gold: Int = 100,
        keepRemaining: Int = 20,
        cityNumberInCountry: Int = 1,
        completedCityCount: Int = 0,
        selectedLane: BattleLane? = nil
    ) -> KingdomGameState {
        stateWithBuildings(
            [.barracks],
            gold: gold,
            keepRemaining: keepRemaining,
            cityNumberInCountry: cityNumberInCountry,
            completedCityCount: completedCityCount,
            selectedLane: selectedLane
        )
    }

    /// `selectedLane` pins the assault lane. City 1's default center route spends
    /// damage on the Gate first, so Keep-direct and tower-covered tests pass `.right`.
    private func stateWithBuildings(
        _ buildingTypes: [BuildingType],
        gold: Int = 100,
        keepRemaining: Int = 20,
        cityNumberInCountry: Int = 1,
        completedCityCount: Int = 0,
        selectedLane: BattleLane? = nil
    ) -> KingdomGameState {
        let cityKey = CityKey(countryNumber: 1, cityNumber: cityNumberInCountry)
        let slots = Dictionary(
            uniqueKeysWithValues: buildingTypes.enumerated().map { index, buildingType in
                (index + 1, CityBuilding(type: buildingType))
            }
        )
        // Battle states are built by Keep HP (HPA-468): the Keep is the sole
        // conquest/liveness authority, so fixtures pin it directly.
        var state = KingdomGameState(
            gold: gold,
            cityNumberInCountry: cityNumberInCountry,
            completedCityCount: completedCityCount,
            cityBattleStates: [cityKey.storageKey: CityBattleState(slots: slots)]
        )
        if let selectedLane {
            state.siegeProgress.selectedLane = selectedLane
        }
        SiegeTestSupport.setKeepRemaining(keepRemaining, on: &state)
        return state
    }

    private func idleConquestReadyState(selectedLane: BattleLane? = nil) -> KingdomGameState {
        let backgroundAt = Date(timeIntervalSince1970: 1_000)
        var state = KingdomGameState(gold: 100)
        if let selectedLane {
            state.siegeProgress.selectedLane = selectedLane
        }
        SiegeTestSupport.setKeepRemaining(1, on: &state)
        _ = state.buildBuilding(.barracks, inSlot: 1, at: backgroundAt)
        return state
    }

    private func pendingResult(
        city: Int,
        mode: BattleConquestMode = .live,
        activeBattleSeconds: TimeInterval = 65,
        usedFavorableUnit: Bool = false,
        usedExposedLane: Bool = false,
        newGear: String? = nil
    ) -> BattleResult {
        BattleResult(
            cityKey: CityKey(countryNumber: 1, cityNumber: city),
            conquestMode: mode,
            activeBattleSeconds: activeBattleSeconds,
            deployments: [],
            appliedDamage: [],
            losses: [],
            idleDamageByType: [],
            mvpSoldierType: nil,
            mvpDamageSharePercent: nil,
            usedFavorableUnit: usedFavorableUnit,
            usedExposedLane: usedExposedLane,
            goldEarned: 8,
            equipmentReward: newGear.map { EquipmentReward(itemID: $0, level: 1) }
        )
    }

    private func pendingConqueredState(
        city: Int = 1,
        mode: BattleConquestMode = .live,
        countryComplete: Bool = false,
        usedFavorableUnit: Bool = false,
        usedExposedLane: Bool = false,
        newGear: String? = nil
    ) -> KingdomGameState {
        KingdomGameState(
            cityLevel: city,
            cityNumberInCountry: city,
            completedCityCount: city - 1,
            stageStatus: countryComplete ? .countryComplete : .cityConqueredPendingMap,
            pendingBattleResult: pendingResult(
                city: city,
                mode: mode,
                usedFavorableUnit: usedFavorableUnit,
                usedExposedLane: usedExposedLane,
                newGear: newGear
            )
        )
    }

    private func buildingTypeForSoldier(_ soldierType: SoldierType) -> BuildingType {
        switch soldierType {
        case .infantry:
            return .barracks
        case .archer:
            return .archeryRange
        case .cavalry:
            return .stable
        case .mage:
            return .mageTower
        case .siege:
            return .siegeWorkshop
        }
    }

    // MARK: Vanguard Captain scene wiring (HPA-475 Task 5)

    private func makeCaptainState(
        cityNumber: Int = 3,
        gold: Int = 0,
        keepRemaining: Int = 10_000,
        supportDamage: [CitySiegeLayout.ObjectiveKind: Int] = [:],
        selectedLane: BattleLane? = nil,
        captain: VanguardCaptainProgress? = nil
    ) -> KingdomGameState {
        var state = SiegeTestSupport.makeBattleState(
            atCity: cityNumber,
            gold: gold,
            keepRemaining: keepRemaining,
            supportDamage: supportDamage,
            selectedLane: selectedLane
        )
        if let captain {
            state.siegeProgress.captain = captain
        }
        return state
    }

    private func makeCaptainScene(
        state: KingdomGameState,
        size: CGSize = CGSize(width: 390, height: 844),
        router: BattleSceneRouting? = nil
    ) throws -> (scene: BattleScene, store: KingdomGameStore) {
        let store = try makeStore(initialState: state)
        let scene = makeScene(store: store, router: router, size: size)
        return (scene, store)
    }

    private func damagedCaptain(lane: BattleLane, hp: Int) -> VanguardCaptainProgress {
        VanguardCaptainProgress(
            lane: lane,
            remainingHP: hp,
            recoveryRemainingSeconds: 0,
            rallyConsumed: false
        )
    }

    /// Parks the City 3+ default Captain (HPA-475) in recovery for pre-
    /// existing tests authored against tower/ordinary-soldier mechanics.
    /// Clearing the captain entirely does not survive a store round-trip:
    /// the state normalizer re-grants a fresh captain for battle-active
    /// City 3+ cities on decode. A recovering (HP 0) Captain survives
    /// normalization, spawns no live actor, and never attacks or counts
    /// toward the manual cap or navigation lock.
    private func captainless(_ state: KingdomGameState) -> KingdomGameState {
        var state = state
        state.siegeProgress.captain = VanguardCaptainProgress(
            lane: .left,
            remainingHP: 0,
            recoveryRemainingSeconds: VanguardCaptainRules.recoverySeconds,
            rallyConsumed: false
        )
        return state
    }

    private func retreatingCaptain(
        lane: BattleLane,
        recovery: Double
    ) -> VanguardCaptainProgress {
        VanguardCaptainProgress(
            lane: lane,
            remainingHP: 0,
            recoveryRemainingSeconds: recovery,
            rallyConsumed: false
        )
    }

    @Test("City 2 scene deploys no Captain")
    func city2SceneDeploysNoCaptain() throws {
        let (scene, _) = try makeCaptainScene(
            state: makeCaptainState(cityNumber: 2, selectedLane: .right)
        )

        #expect(scene.livingCaptainForTesting == nil)
        #expect(scene.soldierNodeCountForTesting == 0)
    }

    @Test("City 3 scene restores exactly one flagged Captain from durable lane + HP")
    func city3SceneRestoresFlaggedCaptainFromDurableState() throws {
        let (scene, store) = try makeCaptainScene(
            state: makeCaptainState(
                selectedLane: .left,
                captain: damagedCaptain(lane: .left, hp: 13)
            )
        )

        let captain = try #require(scene.livingCaptainForTesting)
        #expect(captain.lane == .left)
        #expect(captain.currentHP == 13)
        #expect(captain.maxHP == VanguardCaptainRules.maxHP(for: 1))
        // The flagged Soldier is discovered by the ordinary node sync — no
        // Captain node bundle.
        #expect(scene.soldierNodeCountForTesting == 1)
        // Ordinary soldier counts still exclude the Captain.
        #expect(scene.manualLiveSoldierCountForTesting == 0)
        #expect(scene.liveSoldierCountForTesting == 0)
        // Persisted state was untouched by restore.
        #expect(store.load().siegeProgress.captain?.remainingHP == 13)
    }

    @Test("City 3 Captain renders through the ordinary soldier node pipeline")
    func captainRendersThroughOrdinarySoldierNodePipeline() throws {
        let (scene, _) = try makeCaptainScene(
            state: makeCaptainState(
                selectedLane: .left,
                captain: damagedCaptain(lane: .left, hp: 13)
            )
        )

        // The Captain is the only live soldier, so the "first live soldier"
        // accessors address it directly. Locks that the Captain renders
        // through the ordinary soldier bundle — the body is the shared
        // makeSoldierNode SKSpriteNode (never a bespoke Captain node), and
        // its HP bar fill is driven by the shared layoutSoldierHPBar sync at
        // the durable 13/max fraction, with the complete Captain trio using
        // the shared animation path.
        let body = try #require(scene.firstLiveSoldierBodySpriteForTesting)
        let texture = try #require(body.texture)
        let firstWalk = try #require(UIImage(named: "vanguard-captain-walk-01"))
        #expect(rgbaPixels(in: UIImage(cgImage: texture.cgImage())) == rgbaPixels(in: firstWalk))
        #expect(scene.firstLiveSoldierIsAnimatedCanvasForTesting == true)
        #expect(scene.firstLiveSoldierHasActionForTesting("soldierWalkAnimation"))
        let bars = try #require(scene.firstLiveSoldierHPBarPathBoundsForTesting)
        let expected = bars.background.width * CGFloat(13) / CGFloat(VanguardCaptainRules.maxHP(for: 1))
        #expect(abs(bars.fill.width - expected) < 0.01)
        #expect(bars.fill.height == bars.background.height)
    }

    @Test("Recovering Captain restores no live actor")
    func recoveringCaptainRestoresNoLiveActor() throws {
        let (scene, _) = try makeCaptainScene(
            state: makeCaptainState(
                selectedLane: .left,
                captain: retreatingCaptain(lane: .left, recovery: 5)
            )
        )

        #expect(scene.livingCaptainForTesting == nil)
        #expect(scene.soldierNodeCountForTesting == 0)
    }

    @Test("Lane-chip tap never moves the live Captain")
    func laneChipTapDoesNotMoveLiveCaptain() throws {
        let (scene, store) = try makeCaptainScene(
            state: makeCaptainState(
                selectedLane: .left,
                captain: damagedCaptain(lane: .left, hp: 20)
            )
        )
        guard let layout = scene.battleChromeLayoutForTesting,
              let rightChip = layout.laneChipHitFrames[.right] else {
            Issue.record("expected lane chip hit frame")
            return
        }

        scene.handleTouchForTesting(at: CGPoint(x: rightChip.midX, y: rightChip.midY))
        #expect(store.load().siegeProgress.selectedLane == .right)

        scene.advanceCombatForTesting(deltaTime: 0.5)

        #expect(scene.livingCaptainForTesting?.lane == .left)
        #expect(store.load().siegeProgress.captain?.lane == .left)
    }

    @Test("Battle → Camp → Battle reconstruction restores persisted lane + HP")
    func sceneReconstructionRestoresPersistedCaptainLaneAndHP() throws {
        let (scene, store) = try makeCaptainScene(
            state: makeCaptainState(selectedLane: .center)
        )

        // Tower fire (City 3 center lane, standard 4/shot) damages the live
        // Captain; the sibling syncs it into durable progress.
        scene.advanceCombatForTesting(deltaTime: 1.5)
        let persisted = try #require(store.load().siegeProgress.captain)
        #expect(persisted.remainingHP < VanguardCaptainRules.maxHP(for: 1))

        // A fresh scene (the Camp → Battle reconstruction) restores exactly
        // the persisted lane + HP.
        let restoredScene = makeScene(store: store)
        let restoredCaptain = try #require(restoredScene.livingCaptainForTesting)
        #expect(restoredCaptain.lane == persisted.lane)
        #expect(restoredCaptain.currentHP == persisted.remainingHP)
    }

    @Test("Background teardown and foreground restore preserve lane + HP")
    func backgroundForegroundCyclePreservesCaptainLaneAndHP() throws {
        let (scene, store) = try makeCaptainScene(
            state: makeCaptainState(selectedLane: .center)
        )
        scene.advanceCombatForTesting(deltaTime: 1.5)
        let persisted = try #require(store.load().siegeProgress.captain)
        #expect(persisted.remainingHP < VanguardCaptainRules.maxHP(for: 1))

        scene.enterBackgroundForTesting(at: Date(timeIntervalSinceReferenceDate: 10_000))
        #expect(scene.livingCaptainForTesting == nil)

        scene.enterForegroundForTesting(at: Date(timeIntervalSinceReferenceDate: 10_001))
        let restoredCaptain = try #require(scene.livingCaptainForTesting)
        #expect(restoredCaptain.lane == persisted.lane)
        #expect(restoredCaptain.currentHP == persisted.remainingHP)
    }

    @Test("Battle foreground settlement does not spend background time on Captain recovery")
    func foregroundSettlementDoesNotAdvanceCaptainRecovery() throws {
        let (scene, store) = try makeCaptainScene(
            state: makeCaptainState(
                selectedLane: .left,
                captain: retreatingCaptain(lane: .left, recovery: 8.0)
            )
        )

        scene.enterBackgroundForTesting(at: Date(timeIntervalSinceReferenceDate: 10_000))
        scene.enterForegroundForTesting(at: Date(timeIntervalSinceReferenceDate: 10_100))

        let captain = try #require(store.load().siegeProgress.captain)
        #expect(captain.remainingHP == 0)
        #expect(abs(captain.recoveryRemainingSeconds - 8.0) < 0.001)
        #expect(scene.livingCaptainForTesting == nil)
    }

    @Test("Live combat advances and persists Captain recovery on the shared cadence")
    func liveCombatAdvancesCaptainRecoveryByClampedDelta() throws {
        let (scene, store) = try makeCaptainScene(
            state: makeCaptainState(
                selectedLane: .left,
                captain: retreatingCaptain(lane: .left, recovery: 8.0)
            )
        )

        scene.advanceCombatForTesting(deltaTime: 2.1)

        let liveCaptain = try #require(scene.gameStateForTesting.siegeProgress.captain)
        #expect(liveCaptain.remainingHP == 0)
        #expect(abs(liveCaptain.recoveryRemainingSeconds - 5.9) < 0.001)
        let persistedCaptain = try #require(store.load().siegeProgress.captain)
        #expect(persistedCaptain.remainingHP == 0)
        // The helper advances in 0.1s ticks, so the shared two-second cadence
        // persists the 6.0s snapshot; the final 0.1s remains in memory.
        #expect(abs(persistedCaptain.recoveryRemainingSeconds - 6.0) < 0.001)
    }

    @Test("Recovery completion restores max HP on the selected lane and spawns one Captain")
    func recoveryCompletionSpawnsOneCaptainAtSelectedLane() throws {
        let (scene, store) = try makeCaptainScene(
            state: makeCaptainState(
                selectedLane: .right,
                captain: retreatingCaptain(lane: .left, recovery: 0.4)
            )
        )

        scene.advanceCombatForTesting(deltaTime: 0.6)

        let captain = try #require(store.load().siegeProgress.captain)
        #expect(captain.remainingHP == VanguardCaptainRules.maxHP(for: 1))
        #expect(captain.lane == .right)
        #expect(captain.recoveryRemainingSeconds == 0)
        let liveCaptain = try #require(scene.livingCaptainForTesting)
        #expect(liveCaptain.lane == .right)
        #expect(liveCaptain.currentHP == VanguardCaptainRules.maxHP(for: 1))
        #expect(scene.soldierNodeCountForTesting == 1)
    }

    @Test("Automatic Rally fallback fires through the live tick funnel")
    func autoRallyFiresThroughLiveTickFunnel() throws {
        // City 3, exposed .left lane (tower deals 3/shot): the durable
        // Captain is 0.4s from recovery completion, so it spawns mid-battle
        // behind the already-advancing manual soldier and never tanks the
        // tower. The soldier crosses 7 → 4 (below half, alive) on the
        // second tower shot — the ticket-required auto fallback must consume
        // Rally through the same funnel as the manual action.
        var state = makeCaptainState(
            gold: 15,
            keepRemaining: 10_000,
            selectedLane: .left,
            captain: retreatingCaptain(lane: .left, recovery: 0.4)
        )
        #expect(state.buildBuilding(.barracks, inSlot: 1, at: Date(timeIntervalSinceReferenceDate: 0))
            == .built(cost: 15, remainingGold: 0))
        let (scene, store) = try makeCaptainScene(state: state)
        scene.spawnSoldierForTesting()

        var rallyActivated = false
        for _ in 0..<40 {
            scene.advanceCombatForTesting(deltaTime: 0.1)
            if scene.rallyRemainingSecondsForTesting > 0 {
                rallyActivated = true
                break
            }
        }

        #expect(rallyActivated)
        let captain = try #require(store.load().siegeProgress.captain)
        #expect(captain.rallyConsumed)
        #expect(captain.remainingHP == VanguardCaptainRules.maxHP(for: 1))
        #expect(captain.recoveryRemainingSeconds == 0)
        #expect(scene.livingCaptainForTesting != nil)
    }

    @Test("Manual Rally consumes once, emits its cue, and cannot restart after expiry")
    func manualRallyConsumesOnceAndCannotRestart() throws {
        let feedback = BattleFeedbackRecorder()
        let store = try makeStore(initialState: makeCaptainState(selectedLane: .center))
        let scene = makeScene(store: store, feedback: feedback)
        guard let layout = scene.battleChromeLayoutForTesting else {
            Issue.record("expected battle chrome layout")
            return
        }

        scene.handleTouchForTesting(at: CGPoint(x: layout.rallyHitFrame.midX, y: layout.rallyHitFrame.midY))
        #expect(store.load().siegeProgress.captain?.rallyConsumed == true)
        #expect(scene.rallyRemainingSecondsForTesting == VanguardCaptainRules.rallyDurationSeconds)
        #expect(feedback.discreteEvents == [.manualDeployment])

        scene.advanceCombatForTesting(deltaTime: 5.5)
        #expect(scene.rallyRemainingSecondsForTesting == 0)

        scene.handleTouchForTesting(at: CGPoint(x: layout.rallyHitFrame.midX, y: layout.rallyHitFrame.midY))
        #expect(scene.rallyRemainingSecondsForTesting == 0)
        #expect(store.load().siegeProgress.captain?.rallyConsumed == true)
        #expect(feedback.discreteEvents == [.manualDeployment])
    }

    @Test("Rally accent shows on protected ordinary soldiers only and expires with the timer")
    func rallyAccentTracksProtectionWindow() throws {
        // City 3 center lane: the Captain tanks at the front (equal-position
        // tie-break) while one ordinary soldier marches behind it. Manual
        // Rally through the HUD funnel protects the soldier, never the
        // Captain, and expiry hides the accent again.
        var state = makeCaptainState(gold: 15, selectedLane: .center)
        #expect(state.buildBuilding(.barracks, inSlot: 1, at: Date(timeIntervalSinceReferenceDate: 0))
            == .built(cost: 15, remainingGold: 0))
        let (scene, _) = try makeCaptainScene(state: state)
        scene.spawnSoldierForTesting()

        guard let layout = scene.battleChromeLayoutForTesting else {
            Issue.record("expected battle chrome layout")
            return
        }
        scene.handleTouchForTesting(at: CGPoint(x: layout.rallyHitFrame.midX, y: layout.rallyHitFrame.midY))
        #expect(scene.rallyRemainingSecondsForTesting > 0)

        let captainID = try #require(scene.livingCaptainForTesting).id
        scene.advanceCombatForTesting(deltaTime: 0.2)

        let protectedIDs = scene.rallyAccentVisibleSoldierIDsForTesting
        #expect(protectedIDs.count == 1)
        #expect(!protectedIDs.contains(captainID))

        scene.advanceCombatForTesting(deltaTime: 5.0)
        #expect(scene.rallyAccentVisibleSoldierIDsForTesting.isEmpty)
    }

    @Test("Active Rally reconstruction loses the timer but stays Used")
    func activeRallyReconstructionLosesTimerStaysUsed() throws {
        let (scene, store) = try makeCaptainScene(
            state: makeCaptainState(selectedLane: .center)
        )
        guard let layout = scene.battleChromeLayoutForTesting else {
            Issue.record("expected battle chrome layout")
            return
        }
        scene.handleTouchForTesting(at: CGPoint(x: layout.rallyHitFrame.midX, y: layout.rallyHitFrame.midY))
        #expect(scene.rallyRemainingSecondsForTesting > 0)

        let reconstructed = makeScene(store: store)

        #expect(reconstructed.rallyRemainingSecondsForTesting == 0)
        #expect(store.load().siegeProgress.captain?.rallyConsumed == true)
    }

    @Test("Captain retreat during an active Rally keeps Rally live beside recovery")
    func captainRetreatDuringActiveRallyProjectsRecoveryAndLiveRally() throws {
        // City 3 center lane (standard 4/shot): a 4-HP Captain dies to the
        // first tower shot inside the 5s Rally window. Protection rides the
        // captured lane without the Captain, so the strip must project the
        // recovery countdown AND the still-running Rally — not Used —
        // and the Rally hit target goes inert (HPA-475).
        let (scene, store) = try makeCaptainScene(
            state: makeCaptainState(
                selectedLane: .center,
                captain: damagedCaptain(lane: .center, hp: 4)
            )
        )
        guard let layout = scene.battleChromeLayoutForTesting else {
            Issue.record("expected battle chrome layout")
            return
        }
        let rallyPoint = CGPoint(x: layout.rallyHitFrame.midX, y: layout.rallyHitFrame.midY)
        scene.handleTouchForTesting(at: rallyPoint)
        #expect(scene.rallyRemainingSecondsForTesting == VanguardCaptainRules.rallyDurationSeconds)

        scene.advanceCombatForTesting(deltaTime: 2.0)

        #expect(scene.livingCaptainForTesting == nil)
        #expect(scene.rallyRemainingSecondsForTesting > 0)
        #expect(store.load().siegeProgress.captain?.rallyConsumed == true)
        guard case .recovering(let seconds, let rallyConsumed, let rallyActive) =
            scene.battleHUDForTesting.currentContentForTesting?.captainStatus
        else {
            Issue.record("expected recovering captain status")
            return
        }
        #expect(seconds > 0)
        #expect(rallyConsumed)
        #expect(rallyActive)
        // The Rally zone is informational only while the Captain is down —
        // the HUD produces no .rally action there.
        #expect(scene.battleHUDForTesting.action(at: rallyPoint) == nil)

        // Once the timer drains mid-recovery the strip settles to Used.
        scene.advanceCombatForTesting(deltaTime: 5.0)
        #expect(scene.rallyRemainingSecondsForTesting == 0)
        guard case .recovering(_, let drainedConsumed, let drainedActive) =
            scene.battleHUDForTesting.currentContentForTesting?.captainStatus
        else {
            Issue.record("expected recovering captain status")
            return
        }
        #expect(drainedConsumed)
        #expect(!drainedActive)
    }

    @Test("Captain-only objective damage persists through the sibling without ordinary attribution")
    func captainOnlyObjectiveDamagePersistsWithoutOrdinaryAttribution() throws {
        let (scene, store) = try makeCaptainScene(
            state: makeCaptainState(selectedLane: .center)
        )

        scene.advanceCombatForTesting(deltaTime: 4)

        let persisted = store.load()
        let gateID = try #require(SiegeTestSupport.objectiveID(for: .gate, in: persisted))
        #expect((persisted.siegeProgress.damageByObjectiveID[gateID] ?? 0) > 0)
        // Captain structure damage never enters the ordinary siege session:
        // only the ambient battle clock exists — no deployments, damage, or
        // losses attributed to ordinary soldiers.
        #expect(persisted.activeSiegeSession?.deployments.isEmpty == true)
        #expect(persisted.activeSiegeSession?.appliedDamage.isEmpty == true)
        #expect(persisted.activeSiegeSession?.losses.isEmpty == true)
    }

    @Test("Captain-only Keep kill produces one reward and one freshLive report")
    func captainOnlyKeepKillPresentsFreshLiveReportExactlyOnce() throws {
        let (scene, store) = try makeCaptainScene(
            state: makeCaptainState(
                keepRemaining: 2,
                supportDamage: [.gate: 10_000],
                selectedLane: .center
            )
        )

        var conquered = false
        for _ in 0..<60 {
            scene.advanceCombatForTesting(deltaTime: 0.1)
            if store.load().pendingBattleResult != nil {
                conquered = true
                break
            }
        }

        #expect(conquered)
        let persisted = store.load()
        let pending = try #require(persisted.pendingBattleResult)
        #expect(pending.cityKey == CityKey(countryNumber: 1, cityNumber: 3))
        #expect(persisted.gold == pending.goldEarned)
        #expect(persisted.stageStatus == .cityConqueredPendingMap)
        // One fresh-live presentation, no replay.
        #expect(scene.conquestEffectPresentationCountForTesting == 1)
        #expect(scene.lastConquestReportOriginForTesting == "freshLive")
    }

    @Test("Captain retreat records recovery and never ordinary losses")
    func captainRetreatRecordsRecoveryAndNeverOrdinaryLosses() throws {
        let (scene, store) = try makeCaptainScene(
            state: makeCaptainState(selectedLane: .left)
        )

        var retreated = false
        for _ in 0..<120 {
            scene.advanceCombatForTesting(deltaTime: 0.1)
            if store.load().siegeProgress.captain?.remainingHP == 0 {
                retreated = true
                break
            }
        }

        #expect(retreated)
        let persisted = store.load()
        let captain = try #require(persisted.siegeProgress.captain)
        #expect(captain.recoveryRemainingSeconds == VanguardCaptainRules.recoverySeconds)
        #expect(captain.lane == .left)
        // A retreat is not an ordinary soldier casualty and never conquers.
        #expect(persisted.activeSiegeSession?.losses.isEmpty == true)
        #expect(persisted.pendingBattleResult == nil)
        #expect(persisted.stageStatus == .battleActive)
    }

    @Test("Captain never consumes manual cap or arms the navigation lock")
    func captainIgnoresManualCapAndNavigationLock() throws {
        let router = BattleRouterSpy()
        let store = try makeStore(initialState: makeCaptainState(gold: 15, selectedLane: .center))
        let scene = makeScene(store: store, router: router)

        // Navigation lock ignores the Captain: no manual soldiers → free tab.
        scene.requestGameplayTabForTesting(.camp)
        #expect(router.buildingRequestCount == 1)

        // Re-enter Battle state for the manual-cap probe: ten manual spawns
        // fill the cap while the Captain is alive.
        var state = store.load()
        #expect(state.buildBuilding(.barracks, inSlot: 1, at: Date(timeIntervalSinceReferenceDate: 0))
            == .built(cost: 15, remainingGold: 0))
        let store2 = try makeStore(initialState: state)
        let scene2 = makeScene(store: store2, router: router)
        scene2.spawnManualSoldiersDirectlyForTesting(KingdomGameState.manualSoldierCap)
        #expect(scene2.manualLiveSoldierCountForTesting == KingdomGameState.manualSoldierCap)
        #expect(scene2.livingCaptainForTesting != nil)
        #expect(scene2.liveSoldierCountForTesting == KingdomGameState.manualSoldierCap)
    }

    @Test("City 3+ scene smoke keeps chrome intact at compact and pad sizes")
    func captainSceneSmokeKeepsChromeIntactAtCompactAndPadSizes() throws {
        for size in [CGSize(width: 375, height: 667), CGSize(width: 820, height: 1180)] {
            let (scene, store) = try makeCaptainScene(
                state: makeCaptainState(selectedLane: .center),
                size: size
            )

            #expect(!scene.isBattleChromeFitFailedForTesting)
            #expect(scene.livingCaptainForTesting != nil)
            scene.advanceCombatForTesting(deltaTime: 1)
            #expect(store.load().siegeProgress.captain != nil)
        }
    }

    private final class BattleRouterSpy: BattleSceneRouting {
        private(set) var didRequestCountryMap = false
        private(set) var didRequestBuildingView = false
        private(set) var requestedTabs: [GameplayTab] = []
        private(set) var countryMapRequestCount = 0
        private(set) var buildingRequestCount = 0
        var onCountryMapRequest: ((BattleScene) -> Void)?

        func battleSceneDidRequestGameplayTab(_ scene: BattleScene, tab: GameplayTab) {
            requestedTabs.append(tab)
            switch tab {
            case .map:
                didRequestCountryMap = true
                countryMapRequestCount += 1
                onCountryMapRequest?(scene)
            case .camp:
                didRequestBuildingView = true
                buildingRequestCount += 1
            case .battle:
                break
            case .kingdom:
                break
            }
        }

        private(set) var layoutGateRequestCount = 0
        private(set) var lastLayoutGateReason: AppLayoutGateReason?

        func battleScene(_ scene: BattleScene, didRequestLayoutGate reason: AppLayoutGateReason) {
            layoutGateRequestCount += 1
            lastLayoutGateReason = reason
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

    private func visibleLabelTexts(
        in node: SKNode,
        inheritedHidden: Bool = false,
        inheritedAlpha: CGFloat = 1
    ) -> [String] {
        let isHidden = inheritedHidden || node.isHidden
        let alpha = inheritedAlpha * node.alpha
        guard !isHidden, alpha > 0.01 else {
            return []
        }

        var texts: [String] = []
        if let label = node as? SKLabelNode,
           let text = label.text,
           !text.isEmpty {
            texts.append(text)
        }

        for child in node.children {
            texts.append(contentsOf: visibleLabelTexts(
                in: child,
                inheritedHidden: isHidden,
                inheritedAlpha: alpha
            ))
        }
        return texts
    }

    private func visibleSpriteCount(
        in node: SKNode,
        named name: String,
        inheritedHidden: Bool = false,
        inheritedAlpha: CGFloat = 1
    ) -> Int {
        let isHidden = inheritedHidden || node.isHidden
        let alpha = inheritedAlpha * node.alpha
        guard !isHidden, alpha > 0.01 else {
            return 0
        }

        let selfCount = (node as? SKSpriteNode) != nil && node.name == name ? 1 : 0
        return node.children.reduce(selfCount) { count, child in
            count + visibleSpriteCount(
                in: child,
                named: name,
                inheritedHidden: isHidden,
                inheritedAlpha: alpha
            )
        }
    }

    private func visibleSpriteFrames(
        in node: SKNode,
        named name: String,
        inheritedHidden: Bool = false,
        inheritedAlpha: CGFloat = 1
    ) -> [CGRect] {
        let isHidden = inheritedHidden || node.isHidden
        let alpha = inheritedAlpha * node.alpha
        guard !isHidden, alpha > 0.01 else {
            return []
        }

        var frames: [CGRect] = []
        if (node as? SKSpriteNode) != nil,
           node.name == name,
           let sceneFrame = sceneFrameInTest(for: node) {
            frames.append(sceneFrame)
        }

        for child in node.children {
            frames.append(contentsOf: visibleSpriteFrames(
                in: child,
                named: name,
                inheritedHidden: isHidden,
                inheritedAlpha: alpha
            ))
        }
        return frames
    }

    private func sceneFrameInTest(for node: SKNode) -> CGRect? {
        guard let parent = node.parent else {
            return nil
        }

        let frame = node.calculateAccumulatedFrame()
        let corners = [
            CGPoint(x: frame.minX, y: frame.minY),
            CGPoint(x: frame.maxX, y: frame.minY),
            CGPoint(x: frame.minX, y: frame.maxY),
            CGPoint(x: frame.maxX, y: frame.maxY)
        ].map { parent.convert($0, to: node.scene ?? parent) }

        guard let first = corners.first else {
            return nil
        }

        return corners.dropFirst().reduce(
            CGRect(origin: first, size: .zero)
        ) { partial, point in
            partial.union(CGRect(origin: point, size: .zero))
        }
    }

    private func visibleNodeCount(
        in node: SKNode,
        namePrefix: String,
        inheritedHidden: Bool = false,
        inheritedAlpha: CGFloat = 1
    ) -> Int {
        let isHidden = inheritedHidden || node.isHidden
        let alpha = inheritedAlpha * node.alpha
        guard !isHidden, alpha > 0.01 else {
            return 0
        }

        let selfCount = node.name?.hasPrefix(namePrefix) == true ? 1 : 0
        return node.children.reduce(selfCount) { count, child in
            count + visibleNodeCount(
                in: child,
                namePrefix: namePrefix,
                inheritedHidden: isHidden,
                inheritedAlpha: alpha
            )
        }
    }

    private func nodeCount<T: SKNode>(in node: SKNode, of type: T.Type) -> Int {
        let selfCount = node is T ? 1 : 0
        return node.children.reduce(selfCount) { count, child in
            count + nodeCount(in: child, of: type)
        }
    }

    private func firstNode(named name: String, in node: SKNode) -> SKNode? {
        if node.name == name {
            return node
        }

        for child in node.children {
            if let match = firstNode(named: name, in: child) {
                return match
            }
        }

        return nil
    }

    private func firstNode<T: SKNode>(of type: T.Type, in node: SKNode) -> T? {
        if let typedNode = node as? T {
            return typedNode
        }

        for child in node.children {
            if let match = firstNode(of: type, in: child) {
                return match
            }
        }

        return nil
    }

    private func effectiveZPosition(of node: SKNode) -> CGFloat {
        var effectiveZPosition: CGFloat = 0
        var currentNode: SKNode? = node
        while let current = currentNode {
            effectiveZPosition += current.zPosition
            currentNode = current.parent
        }
        return effectiveZPosition
    }

    private func visibleNodeHasAction(
        in node: SKNode,
        namePrefix: String,
        actionKey: String,
        inheritedHidden: Bool = false,
        inheritedAlpha: CGFloat = 1
    ) -> Bool {
        let isHidden = inheritedHidden || node.isHidden
        let alpha = inheritedAlpha * node.alpha
        guard !isHidden, alpha > 0.01 else {
            return false
        }

        if node.name?.hasPrefix(namePrefix) == true,
           node.action(forKey: actionKey) != nil {
            return true
        }

        return node.children.contains { child in
            visibleNodeHasAction(
                in: child,
                namePrefix: namePrefix,
                actionKey: actionKey,
                inheritedHidden: isHidden,
                inheritedAlpha: alpha
            )
        }
    }

    private func visibleShapeAlphas(
        in node: SKNode,
        namePrefix: String,
        inheritedHidden: Bool = false,
        inheritedAlpha: CGFloat = 1
    ) -> [(fill: CGFloat, stroke: CGFloat)] {
        let isHidden = inheritedHidden || node.isHidden
        let alpha = inheritedAlpha * node.alpha
        guard !isHidden, alpha > 0.01 else {
            return []
        }

        var alphas: [(fill: CGFloat, stroke: CGFloat)] = []
        if let shape = node as? SKShapeNode,
           node.name?.hasPrefix(namePrefix) == true {
            alphas.append((
                fill: alphaComponent(of: shape.fillColor) * alpha,
                stroke: alphaComponent(of: shape.strokeColor) * alpha
            ))
        }

        for child in node.children {
            alphas.append(contentsOf: visibleShapeAlphas(
                in: child,
                namePrefix: namePrefix,
                inheritedHidden: isHidden,
                inheritedAlpha: alpha
            ))
        }
        return alphas
    }

    private func alphaComponent(of color: SKColor) -> CGFloat {
        var alpha: CGFloat = 0
        color.getRed(nil, green: nil, blue: nil, alpha: &alpha)
        return alpha
    }

    private func rgbaBytes(_ color: SKColor) -> [Int] {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return [red, green, blue, alpha].map { Int(($0 * 255).rounded()) }
    }

    private func pixel(in texture: SKTexture, normalized point: CGPoint) -> [Int]? {
        let image = texture.cgImage()
        guard image.width > 0, image.height > 0 else {
            return nil
        }

        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: image.width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return false
            }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        guard drawn else {
            return nil
        }

        let x = min(image.width - 1, max(0, Int(point.x * CGFloat(image.width))))
        let y = min(image.height - 1, max(0, Int((1 - point.y) * CGFloat(image.height))))
        let offset = (y * image.width + x) * 4
        return Array(pixels[offset..<(offset + 4)]).map(Int.init)
    }

    private func rgbaPixels(in image: UIImage) -> [UInt8]? {
        guard let cgImage = image.cgImage else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var didDraw = false

        pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return
            }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            didDraw = true
        }

        return didDraw ? pixels : nil
    }

    private func opaquePixelBounds(in image: UIImage) -> PixelBounds? {
        guard let cgImage = image.cgImage,
              let pixels = rgbaPixels(in: image) else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height

        var minX = width
        var minY = height
        var maxXExclusive = 0
        var maxYExclusive = 0
        for y in 0..<height {
            for x in 0..<width {
                let alphaIndex = (y * width + x) * 4 + 3
                guard pixels[alphaIndex] > 0 else {
                    continue
                }
                minX = min(minX, x)
                minY = min(minY, y)
                maxXExclusive = max(maxXExclusive, x + 1)
                maxYExclusive = max(maxYExclusive, y + 1)
            }
        }

        guard minX < width, minY < height else {
            return nil
        }
        return PixelBounds(
            minX: minX,
            minY: minY,
            maxXExclusive: maxXExclusive,
            maxYExclusive: maxYExclusive
        )
    }

    /// Returns true when the image has at least one fully transparent pixel
    /// (alpha == 0). Used to enforce the "transparent overlay" contract for map
    /// and battlefield overlays, and the nonterminal FX frames: an opaque
    /// replacement would occlude the shipping map/battlefield during playback.
    private func hasTransparentPixel(in image: UIImage) -> Bool {
        guard let pixels = rgbaPixels(in: image) else {
            return false
        }
        for offset in stride(from: 3, to: pixels.count, by: 4) where pixels[offset] == 0 {
            return true
        }
        return false
    }

    // MARK: - touchesEnded

    @Test func touchesEndedEmptyTouchesDoesNothing() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100))
        let router = BattleRouterSpy()
        let scene = makeScene(store: store, router: router)
        let liveCountBefore = scene.liveSoldierCountForTesting

        scene.touchesEnded([], with: nil)

        #expect(scene.liveSoldierCountForTesting == liveCountBefore)
        #expect(!router.didRequestCountryMap)
        #expect(!router.didRequestBuildingView)
    }

    @Test func touchesEndedSpawnButtonSpawnsSoldier() throws {
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 20))
        let scene = makeScene(store: store)
        let layout = try #require(scene.battleChromeLayoutForTesting)
        let point = layout.deployFrame.center

        scene.touchesEnded([MockTouch(location: point)], with: nil)

        #expect(scene.liveSoldierCountForTesting == 1)
    }

    @Test func touchesEndedBuildButtonRequestsBuildingView() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100))
        let router = BattleRouterSpy()
        let scene = makeScene(store: store, router: router)
        let layout = try #require(scene.battleChromeLayoutForTesting)
        let point = layout.tabHitFrames[1].center

        scene.touchesEnded([MockTouch(location: point)], with: nil)

        #expect(router.didRequestBuildingView)
    }

    @Test func touchesEndedWorldButtonRequestsCountryMap() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100))
        let router = BattleRouterSpy()
        let scene = makeScene(store: store, router: router)
        let layout = try #require(scene.battleChromeLayoutForTesting)
        let point = layout.tabHitFrames[2].center

        scene.touchesEnded([MockTouch(location: point)], with: nil)

        #expect(router.didRequestCountryMap)
    }

    @Test func touchesEndedMapTabUsesAuthoritativeSafeHitFrame() throws {
        let size = CGSize(width: 393, height: 852)
        let store = try makeStore(initialState: KingdomGameState(gold: 100))
        let router = BattleRouterSpy()
        let scene = BattleScene(size: size, store: store, router: router)
        let view = SafeAreaOverridingSKView(
            frame: CGRect(origin: .zero, size: size),
            overrideInsets: UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0)
        )
        scene.didMove(to: view)
        let layout = try #require(scene.battleChromeLayoutForTesting)
        let mapHitFrame = layout.tabHitFrames[2]
        let point = CGPoint(x: mapHitFrame.midX, y: mapHitFrame.maxY - 1)

        #expect(mapHitFrame.contains(point))
        #expect(layout.safeFrame.contains(mapHitFrame))
        scene.touchesEnded([MockTouch(location: point)], with: nil)

        #expect(router.didRequestCountryMap)
    }

    @Test func touchesEndedContinueDisablesAndRoutes() throws {
        let store = try makeStore(
            initialState: stateWithBarracks(keepRemaining: 1, completedCityCount: 0, selectedLane: .right)
        )
        let router = BattleRouterSpy()
        let scene = makeScene(store: store, router: router)
        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 3.0)
        #expect(scene.isConquestPopupVisibleForTesting)

        let frame = try #require(scene.popupContinueButtonFrameForTesting)
        let point = CGPoint(x: frame.midX, y: frame.midY)
        scene.touchesEnded([MockTouch(location: point)], with: nil)

        #expect(router.didRequestCountryMap)
        #expect(!scene.isConquestContinueEnabledForTesting)
        #expect(scene.gameStateForTesting.pendingBattleResult == nil)
    }

    @Test func continueDisablesAcknowledgesSavesThenRoutesOnce() throws {
        let store = try makeStore(initialState: pendingConqueredState())
        let router = BattleRouterSpy()
        let scene = makeScene(store: store, router: router)
        router.onCountryMapRequest = { routed in
            #expect(!routed.isConquestContinueEnabledForTesting)
            #expect(routed.gameStateForTesting.pendingBattleResult == nil)
            #expect(store.load().pendingBattleResult == nil)
        }
        scene.tapConquestContinueForTesting()
        scene.tapConquestContinueForTesting()
        #expect(router.countryMapRequestCount == 1)
    }

    @Test func missingRouterLeavesReportPendingAndEnabled() throws {
        let store = try makeStore(initialState: pendingConqueredState())
        let scene = makeScene(store: store, router: nil)
        scene.tapConquestContinueForTesting()
        #expect(scene.isConquestContinueEnabledForTesting)
        #expect(store.load().pendingBattleResult != nil)
    }

    @Test func reportBlocksEveryUnderlyingTouchPath() throws {
        let store = try makeStore(initialState: pendingConqueredState())
        let router = BattleRouterSpy()
        let scene = makeScene(store: store, router: router)
        let before = scene.gameStateForTesting
        for point in scene.underlyingControlCentersForTesting {
            scene.handleTouchForTesting(at: point)
        }
        #expect(scene.gameStateForTesting == before)
        #expect(scene.liveSoldierCountForTesting == 0)
        #expect(router.buildingRequestCount == 0)
        #expect(router.countryMapRequestCount == 0)
        #expect(!scene.isFeedbackTooltipVisibleForTesting)
    }

    @Test func resizeAfterDisableCannotReenableContinue() throws {
        let store = try makeStore(initialState: pendingConqueredState())
        let router = BattleRouterSpy()
        let scene = makeScene(store: store, router: router)
        scene.tapConquestContinueForTesting()
        scene.refreshLayoutForCurrentEnvironment()
        scene.redrawForTesting(shouldLayout: true)
        #expect(!scene.isConquestContinueEnabledForTesting)
    }

    @Test func requestCountryMapBlocksWithManualSoldiersAlive() throws {
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 20))
        let router = BattleRouterSpy()
        let scene = makeScene(store: store, router: router)
        scene.spawnSoldierForTesting()

        scene.requestGameplayTabForTesting(.map)

        #expect(!router.didRequestCountryMap)
        #expect(scene.feedbackTextForTesting == "Finish the current squad before viewing world.")
    }

    @Test func requestCountryMapBlocksWhenConquestPopupVisible() throws {
        let store = try makeStore(
            initialState: stateWithBarracks(keepRemaining: 1, completedCityCount: 0, selectedLane: .right)
        )
        let router = BattleRouterSpy()
        let scene = makeScene(store: store, router: router)
        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 3.0)
        #expect(scene.isConquestPopupVisibleForTesting)

        scene.requestGameplayTabForTesting(.map)

        #expect(!router.didRequestCountryMap)
    }

    @Test func gameplayTabsDisableCampAndMapWhenManualSoldierLives() throws {
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 20))
        let scene = makeScene(store: store)

        #expect(scene.battleHUDContentForTesting.enabledTabs == Set(GameplayTab.allCases))
        #expect(scene.battleHUDTabBarForTesting.visualCellCountForTesting == GameplayTab.allCases.count)
        #expect(scene.battleHUDTabBarForTesting.hitFrameForTesting(for: .camp) != nil)
        #expect(scene.battleHUDTabBarForTesting.hitFrameForTesting(for: .map) != nil)

        scene.spawnSoldierForTesting()

        #expect(scene.battleHUDContentForTesting.enabledTabs == [.battle])
        #expect(scene.battleHUDTabBarForTesting.visualCellCountForTesting == GameplayTab.allCases.count)
        #expect(scene.battleHUDTabBarForTesting.hitFrameForTesting(for: .camp) == nil)
        #expect(scene.battleHUDTabBarForTesting.hitFrameForTesting(for: .map) == nil)
    }

    @Test func directGameplayTabRouteKeepsManualSquadGuardFeedback() throws {
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 20))
        let router = BattleRouterSpy()
        let scene = makeScene(store: store, router: router)
        scene.spawnSoldierForTesting()

        scene.requestGameplayTabForTesting(.camp)

        #expect(!router.requestedTabs.contains(.camp))
        #expect(scene.feedbackTextForTesting == "Finish the current squad before building.")
    }

    @Test func kingdomTabGuardNamesTheTreasuryNotBuilding() throws {
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 20))
        let router = BattleRouterSpy()
        let scene = makeScene(store: store, router: router)
        scene.spawnSoldierForTesting()

        scene.requestGameplayTabForTesting(.kingdom)

        #expect(!router.requestedTabs.contains(.kingdom))
        #expect(scene.feedbackTextForTesting == "Finish the current squad before opening the treasury.")
    }

    // MARK: - Feedback Settings (HPA-389)

    @Test("init?(coder:) assigns default feedback providers")
    func initCoderAssignsDefaultFeedbackProviders() throws {
        let original = BattleScene(size: CGSize(width: 390, height: 844))
        let data = try NSKeyedArchiver.archivedData(
            withRootObject: original,
            requiringSecureCoding: false
        )
        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
        unarchiver.requiresSecureCoding = false
        let scene = try #require(
            unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? BattleScene
        )

        // init?(coder:) should produce a valid scene that can lay out feedback
        // settings when moved to a view, proving the default providers were set.
        let view = SKView(frame: CGRect(origin: .zero, size: scene.size))
        scene.didMove(to: view)

        #expect(scene.feedbackSettingsGearFrameForTesting != nil)
        #expect(scene.feedbackSettingsGearZPositionForTesting == 2)
    }

    @Test("Tapping the Settings gear opens the feedback settings modal")
    func tappingSettingsGearOpensFeedbackSettings() throws {
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 20))
        let scene = makeScene(store: store)

        #expect(!scene.isFeedbackSettingsVisibleForTesting)

        scene.handleTouchForTesting(
            at: try #require(scene.feedbackSettingsGearFrameForTesting).center
        )

        #expect(scene.isFeedbackSettingsVisibleForTesting)
        #expect(scene.isBattlefieldActionLayerPausedForTesting)
    }

    @Test("Feedback settings modal blocks touch handling to game elements")
    func feedbackSettingsModalBlocksTouchesToGameElements() throws {
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 20))
        let scene = makeScene(store: store)

        // Open settings
        scene.handleTouchForTesting(
            at: try #require(scene.feedbackSettingsGearFrameForTesting).center
        )
        #expect(scene.isFeedbackSettingsVisibleForTesting)

        // Tap the spawn button area while settings are visible
        let layout = try #require(scene.battleChromeLayoutForTesting)
        scene.handleTouchForTesting(at: CGPoint(
            x: layout.deployFrame.midX,
            y: layout.deployFrame.midY
        ))

        // No soldier should have been spawned
        #expect(scene.liveSoldierCountForTesting == 0)
        // Settings should still be visible
        #expect(scene.isFeedbackSettingsVisibleForTesting)
    }

    @Test("Feedback settings modal blocks the update loop")
    func feedbackSettingsModalBlocksUpdateLoop() throws {
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 500))
        let scene = makeScene(store: store)

        // Prime the battle clock without advancing combat
        scene.update(10)
        #expect(scene.lastAdvanceCombatDeltaForTesting == nil)

        // Open settings
        scene.handleTouchForTesting(
            at: try #require(scene.feedbackSettingsGearFrameForTesting).center
        )
        #expect(scene.isFeedbackSettingsVisibleForTesting)

        scene.update(11)

        // Update loop should be blocked — no combat advance occurred
        #expect(scene.lastAdvanceCombatDeltaForTesting == nil)
        #expect(scene.lastUpdateTimeForTesting == 11)
    }

    @Test("Closing feedback settings resumes the update loop and unpauses the battlefield")
    func closingFeedbackSettingsResumesUpdateLoop() throws {
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 500))
        let scene = makeScene(store: store)

        scene.update(10)
        scene.handleTouchForTesting(
            at: try #require(scene.feedbackSettingsGearFrameForTesting).center
        )
        #expect(scene.isFeedbackSettingsVisibleForTesting)
        #expect(scene.isBattlefieldActionLayerPausedForTesting)

        let layout = try #require(FeedbackSettingsLayout.compute(
            sceneSize: scene.size,
            safeAreaInsets: .zero
        ))
        scene.handleTouchForTesting(at: layout.closeFrame.center)

        #expect(!scene.isFeedbackSettingsVisibleForTesting)
        #expect(!scene.isBattlefieldActionLayerPausedForTesting)

        scene.update(11)
        #expect(scene.lastAdvanceCombatDeltaForTesting == 1)
    }

    @Test("openFeedbackSettings returns early when gear accessibility is disabled")
    func openFeedbackSettingsFailsWhenGearNotActionable() throws {
        let size = CGSize(width: 390, height: 844)
        let containerView = UIView(frame: CGRect(origin: .zero, size: size))
        let accessibilityAdapter = FeedbackSettingsAccessibilityAdapter(
            containerView: containerView,
            sceneToScreenFrame: { $0 },
            postNotification: { _, _ in }
        )
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 20))
        let scene = makeScene(
            store: store,
            size: size,
            feedbackSettingsAccessibilityAdapter: accessibilityAdapter
        )

        // Disable gear actionable after didMove configured it
        accessibilityAdapter.setSceneGearActionable(false)

        scene.handleTouchForTesting(
            at: try #require(scene.feedbackSettingsGearFrameForTesting).center
        )

        #expect(!scene.isFeedbackSettingsVisibleForTesting)
    }

    @Test("activateFeedbackSettings toggleSoundEffects toggles the preference via accessibility")
    func activateFeedbackSettingsToggleSoundEffectsViaAccessibility() throws {
        let size = CGSize(width: 390, height: 844)
        let containerView = UIView(frame: CGRect(origin: .zero, size: size))
        let accessibilityAdapter = FeedbackSettingsAccessibilityAdapter(
            containerView: containerView,
            sceneToScreenFrame: { $0 },
            postNotification: { _, _ in }
        )
        let suiteName = "PyxisTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let prefsStore = FeedbackPreferencesStore(defaults: defaults, keyPrefix: "prefs")
        let initialSoundEnabled = prefsStore.current.soundEffectsEnabled

        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 20))
        let scene = makeScene(
            store: store,
            size: size,
            feedbackPreferences: prefsStore,
            feedbackSettingsAccessibilityAdapter: accessibilityAdapter
        )

        // Open settings
        scene.handleTouchForTesting(
            at: try #require(scene.feedbackSettingsGearFrameForTesting).center
        )
        #expect(scene.isFeedbackSettingsVisibleForTesting)

        // The modal exposes sound, haptics, and close accessibility elements
        let elements = try accessibilityElements(in: containerView)
        #expect(elements.count == 3)

        let soundElement = try #require(
            elements.first(where: { $0.accessibilityLabel == "Sound Effects" })
        )
        #expect(soundElement.accessibilityActivate())

        // The preference should have been toggled
        #expect(prefsStore.current.soundEffectsEnabled != initialSoundEnabled)
        // Settings should still be visible (toggling doesn't close)
        #expect(scene.isFeedbackSettingsVisibleForTesting)
    }

    @Test("activateFeedbackSettings toggleHaptics toggles the preference via accessibility")
    func activateFeedbackSettingsToggleHapticsViaAccessibility() throws {
        let size = CGSize(width: 390, height: 844)
        let containerView = UIView(frame: CGRect(origin: .zero, size: size))
        let accessibilityAdapter = FeedbackSettingsAccessibilityAdapter(
            containerView: containerView,
            sceneToScreenFrame: { $0 },
            postNotification: { _, _ in }
        )
        let suiteName = "PyxisTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let prefsStore = FeedbackPreferencesStore(defaults: defaults, keyPrefix: "prefs")
        let initialHapticsEnabled = prefsStore.current.hapticsEnabled

        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 20))
        let scene = makeScene(
            store: store,
            size: size,
            feedbackPreferences: prefsStore,
            feedbackSettingsAccessibilityAdapter: accessibilityAdapter
        )

        scene.handleTouchForTesting(
            at: try #require(scene.feedbackSettingsGearFrameForTesting).center
        )

        let elements = try accessibilityElements(in: containerView)
        let hapticsElement = try #require(
            elements.first(where: { $0.accessibilityLabel == "Haptics" })
        )
        #expect(hapticsElement.accessibilityActivate())

        #expect(prefsStore.current.hapticsEnabled != initialHapticsEnabled)
        #expect(scene.isFeedbackSettingsVisibleForTesting)
    }

    @Test("activateFeedbackSettings close dismisses the modal via accessibility")
    func activateFeedbackSettingsCloseViaAccessibility() throws {
        let size = CGSize(width: 390, height: 844)
        let containerView = UIView(frame: CGRect(origin: .zero, size: size))
        let accessibilityAdapter = FeedbackSettingsAccessibilityAdapter(
            containerView: containerView,
            sceneToScreenFrame: { $0 },
            postNotification: { _, _ in }
        )
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 20))
        let scene = makeScene(
            store: store,
            size: size,
            feedbackSettingsAccessibilityAdapter: accessibilityAdapter
        )

        scene.handleTouchForTesting(
            at: try #require(scene.feedbackSettingsGearFrameForTesting).center
        )
        #expect(scene.isFeedbackSettingsVisibleForTesting)

        let elements = try accessibilityElements(in: containerView)
        let closeElement = try #require(
            elements.first(where: { $0.accessibilityLabel == "Close" })
        )
        #expect(closeElement.accessibilityActivate())

        #expect(!scene.isFeedbackSettingsVisibleForTesting)
    }

    @Test("Feedback settings layout applies gear z-position and modal z-position")
    func feedbackSettingsLayoutAppliesZPositions() throws {
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 20))
        let scene = makeScene(store: store)

        // The gear is parented under the left HUD panel with a local z of 2,
        // so its effective z is hud + 2.
        #expect(scene.feedbackSettingsGearZPositionForTesting == 2)
        // The modal z-position should be above the HUD tier.
        let modalZ = try #require(scene.feedbackSettingsModalZPositionForTesting)
        #expect(modalZ > GameUITheme.Z.hud)
    }

    @Test("Selecting an unavailable soldier type emits invalidAction feedback")
    func selectingUnavailableSoldierTypeEmitsInvalidAction() throws {
        let feedback = BattleFeedbackRecorder()
        // Only barracks → only infantry is spawnable
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 20))
        let scene = makeScene(store: store, feedback: feedback)

        #expect(scene.manualSpawnableSoldierTypesForTesting == [.infantry])

        feedback.reset()
        scene.selectManualSoldierTypeForTesting(.cavalry)

        #expect(feedback.calls == [.discrete(.invalidAction)])
        #expect(scene.feedbackTextForTesting == "Build Cavalry first.")
        #expect(scene.selectedManualSoldierTypeForTesting == .infantry)
    }

    @Test("Tapping inside the settings modal scrim is consumed without spawning")
    func tappingSettingsScrimIsConsumed() throws {
        let store = try makeStore(initialState: stateWithBarracks(keepRemaining: 20))
        let scene = makeScene(store: store)

        scene.handleTouchForTesting(
            at: try #require(scene.feedbackSettingsGearFrameForTesting).center
        )
        #expect(scene.isFeedbackSettingsVisibleForTesting)

        // Tap at the center of the scene (inside the modal scrim area)
        scene.handleTouchForTesting(at: CGPoint(
            x: scene.size.width / 2,
            y: scene.size.height / 2
        ))

        // The touch should be consumed by the settings modal, not reach game elements
        #expect(scene.liveSoldierCountForTesting == 0)
        // Settings should still be open (scrim doesn't close on tap)
        #expect(scene.isFeedbackSettingsVisibleForTesting)
    }

    // MARK: - Living Kingdom battle presentation (HPA-478)

    /// City 1 (frontier, Standard Watch) holding at 13/20 HP — intact — with a
    /// level-8 barracks, so a single live attack (power 10, 1.0× trait) drops
    /// the city straight from intact to breached in one mutation.
    private func intactFrontierCityWithEliteBarracksState() -> KingdomGameState {
        var state = KingdomGameState(
            gold: 100,
            cityBattleStates: [
                CityKey(countryNumber: 1, cityNumber: 1).storageKey:
                    CityBattleState(slots: [1: CityBuilding(type: .barracks, level: 8)])
            ]
        )
        SiegeTestSupport.setKeepRemaining(13, on: &state)
        return state
    }

    /// Advances combat until `condition` holds (or the step budget runs out).
    private func advanceCombatUntil(_ scene: BattleScene, _ condition: () -> Bool) {
        for _ in 0..<120 where !condition() {
            scene.advanceCombatForTesting(deltaTime: 0.1)
        }
    }

    @Test("Living Kingdom projection drives enemy-city texture and battlefield treatment")
    func livingKingdomProjectionDrivesFortressTextureAndTreatment() throws {
        let city3MaxPower = KingdomGameState.cityMaxPower(for: 3)
        let city3Layout = Country1CityCatalog.definition(for: 3).siegeLayout
        // City 3's Keep budget is its authored share of the city total, so
        // the damaged/breached stage boundaries are Keep-relative (HPA-468).
        let city3KeepMax = city3Layout
            .maxPowerAllocation(totalBudget: city3MaxPower)[city3Layout.keepObjective.id] ?? 0
        func city3Scene(keepRemaining: Int) throws -> BattleScene {
            makeScene(store: try makeStore(initialState: stateWithBarracks(
                keepRemaining: keepRemaining,
                cityNumberInCountry: 3,
                completedCityCount: 2
            )))
        }

        // Full-HP City 3 → frontier intact, no treatment.
        let intact = try city3Scene(keepRemaining: city3MaxPower)
        #expect(intact.appliedLivingKingdomFortressAssetForTesting == "lk-city-frontier-intact")
        #expect(intact.appliedLivingKingdomTreatmentAssetForTesting == nil)
        #expect(try #require(intact.livingKingdomTreatmentNodeForTesting).isHidden)

        // City 3 at its real 60% Keep boundary → damaged.
        let damagedAtBoundary = try city3Scene(keepRemaining: city3KeepMax * 3 / 5)
        #expect(damagedAtBoundary.appliedLivingKingdomFortressAssetForTesting == "lk-city-frontier-damaged")

        // City 3 at its real 25% Keep boundary → breached.
        let breachedAtBoundary = try city3Scene(keepRemaining: city3KeepMax / 4)
        #expect(breachedAtBoundary.appliedLivingKingdomFortressAssetForTesting == "lk-city-frontier-breached")

        // Family + treatment per authored city.
        let familyByCity: [(cityNumber: Int, family: String)] = [
            (7, "ember"), (9, "arcane"), (15, "royal")
        ]
        for entry in familyByCity {
            let scene = makeScene(store: try makeStore(initialState: stateWithBarracks(
                keepRemaining: KingdomGameState.cityMaxPower(for: entry.cityNumber),
                cityNumberInCountry: entry.cityNumber,
                completedCityCount: entry.cityNumber - 1
            )))
            #expect(scene.appliedLivingKingdomFortressAssetForTesting == "lk-city-\(entry.family)-intact")
            #expect(scene.appliedLivingKingdomTreatmentAssetForTesting == "lk-battlefield-\(entry.family)")
            #expect(try #require(scene.livingKingdomTreatmentNodeForTesting).isHidden == false)
        }

        // Pending conquest → conquered immediately.
        let pending = makeScene(store: try makeStore(initialState: pendingConqueredState(city: 3)))
        #expect(pending.appliedLivingKingdomFortressAssetForTesting == "lk-city-frontier-conquered")

        // The semantic node still resolves after every texture selection above.
        for scene in [intact, damagedAtBoundary, breachedAtBoundary, pending] {
            #expect(firstNode(named: "enemy-city", in: scene) != nil)
        }
    }

    // MARK: - Falconridge siege objective visuals (HPA-468 Task 5)

    /// Falconridge (City 3) battle state with optional Keep/support damage.
    private func falconridgeState(
        keepRemaining: Int = 26,
        supportDamage: [CitySiegeLayout.ObjectiveKind: Int] = [:]
    ) -> KingdomGameState {
        SiegeTestSupport.makeBattleState(
            atCity: 3,
            keepRemaining: keepRemaining,
            supportDamage: supportDamage
        )
    }

    /// Scene-space point for `progress` along `lane`, derived from the
    /// scene's own gate geometry rather than duplicating layout math.
    private func lanePoint(
        _ scene: BattleScene,
        lane: BattleLane,
        progress: Double
    ) -> CGPoint {
        guard let castle = scene.castleGatePointForTesting(lane: lane),
              let enemy = scene.enemyGatePointForTesting(lane: lane) else {
            return .zero
        }
        let clamped = CGFloat(min(max(progress, 0), 1))
        return CGPoint(
            x: castle.x + (enemy.x - castle.x) * clamped,
            y: castle.y + (enemy.y - castle.y) * clamped
        )
    }

    @Test("Falconridge renders a procedural arrow tower at its authored progress")
    func falconridgeRendersArrowTowerAtAuthoredProgress() throws {
        let scene = makeScene(store: try makeStore(initialState: falconridgeState()))
        let tower = try #require(scene.siegeObjectiveNodeForTesting(.arrowTower))

        #expect(tower.name == "siegeObjective-falconridge.arrow-tower")
        let expected = lanePoint(scene, lane: .left, progress: 0.68)
        #expect(abs(tower.position.x - expected.x) < 0.5)
        #expect(abs(tower.position.y - expected.y) < 0.5)
        #expect(tower.childNode(withName: "siegeStructure") != nil)
        #expect(tower.childNode(withName: "siegeHPFill") != nil)
        #expect(tower.childNode(withName: "siegeRuin") == nil)
    }

    @Test("Falconridge renders one shared ridge gate spanning center and right")
    func falconridgeRendersOneSharedGateSpanningCenterAndRight() throws {
        let scene = makeScene(store: try makeStore(initialState: falconridgeState()))
        let gate = try #require(scene.siegeObjectiveNodeForTesting(.gate))
        let frame = try #require(sceneFrameInTest(for: gate))

        let centerPoint = lanePoint(scene, lane: .center, progress: 0.58)
        let rightPoint = lanePoint(scene, lane: .right, progress: 0.58)

        // One barrier spans both approaches at the authored progress.
        #expect(frame.minX <= centerPoint.x)
        #expect(frame.maxX >= rightPoint.x)
        #expect(frame.minY <= centerPoint.y && frame.maxY >= centerPoint.y)
        // Bottom-center anchor contract (HPA-476): the gate structure is
        // bottom-anchored and sunk half a gate height so its frame still
        // straddles the container origin (the route line it barriers).
        let structure = try #require(gate.childNode(withName: "siegeStructure"))
        #expect(abs(structure.frame.midY) < 0.5)
        // Exactly two pilot objective nodes exist: tower + gate (no keep).
        #expect(scene.siegeObjectiveNodeCountForTesting == 2)
        #expect(scene.siegeObjectiveNodeForTesting(.keep) == nil)
    }

    @Test("A Keep-only lane renders the Gate but no Keep node or tower coverage")
    func keepOnlyLaneRendersNoKeepNodeOrCoverage() throws {
        // City 1 (Willowford): the Gate is its only non-Keep objective, and it has no arrow tower.
        let scene = makeScene(store: try makeStore(
            initialState: stateWithBarracks(selectedLane: .right)
        ))

        #expect(scene.siegeObjectiveNodeForTesting(.keep) == nil)
        #expect(scene.siegeObjectiveNodeCountForTesting == 1)
        #expect(scene.siegeCoveredLanesForTesting.isEmpty)
    }

    @Test("Destroyed objectives render ruins spanning the same approaches")
    func destroyedObjectivesRenderRuinsSpanningSameApproaches() throws {
        let intact = makeScene(store: try makeStore(initialState: falconridgeState()))
        let destroyed = makeScene(store: try makeStore(initialState: falconridgeState(
            keepRemaining: 26,
            supportDamage: [.arrowTower: 34, .gate: 8]
        )))

        // The ruined gate spans exactly the intact gate's approaches.
        let intactGate = try #require(intact.siegeObjectiveNodeForTesting(.gate))
        let intactFrame = try #require(sceneFrameInTest(for: intactGate))
        let ruinedGate = try #require(destroyed.siegeObjectiveNodeForTesting(.gate))
        let ruinedFrame = try #require(sceneFrameInTest(for: ruinedGate))
        #expect(abs(ruinedFrame.minX - intactFrame.minX) < 0.5)
        #expect(abs(ruinedFrame.maxX - intactFrame.maxX) < 0.5)
        // The ruined barrier sits at the same authored route position.
        #expect(abs(ruinedGate.position.y - intactGate.position.y) < 0.5)

        // Ruined tower: ruin marker visible, HP fill removed.
        let tower = try #require(destroyed.siegeObjectiveNodeForTesting(.arrowTower))
        let ruin = try #require(tower.childNode(withName: "siegeRuin"))
        #expect(!ruin.isHidden)
        #expect(tower.childNode(withName: "siegeHPFill") == nil)

        // Support-objective destruction alone never changes the fortress stage.
        #expect(destroyed.livingKingdomBattlePresentationForTesting.stage == .intact)
    }

    @Test("A live arrow tower projects coverage over its covered lanes")
    func liveTowerProjectsCoverageOverCoveredLanes() throws {
        let live = makeScene(store: try makeStore(initialState: falconridgeState()))
        #expect(Set(live.siegeCoveredLanesForTesting) == Set(BattleLane.allCases))

        let deadTower = makeScene(store: try makeStore(initialState: falconridgeState(
            supportDamage: [.arrowTower: 34]
        )))
        #expect(deadTower.siegeCoveredLanesForTesting.isEmpty)

        let nonPilot = makeScene(store: try makeStore(initialState: stateWithBarracks()))
        #expect(nonPilot.siegeCoveredLanesForTesting.isEmpty)
    }

    @Test("Falconridge defensive fire leaves the tower node, not the lane gate point")
    func falconridgeDefensiveFireLeavesTheTowerNode() throws {
        let scene = makeScene(store: try makeStore(initialState: falconridgeState()))
        let towerPosition = try #require(
            scene.siegeObjectiveNodeForTesting(.arrowTower)
        ).position

        scene.spawnSoldierForTesting()
        advanceCombatUntil(scene) { scene.defensiveFireProjectileOriginForTesting != nil }

        let origin = try #require(scene.defensiveFireProjectileOriginForTesting)
        #expect(abs(origin.x - towerPosition.x) < 0.5)
        #expect(abs(origin.y - towerPosition.y) < 0.5)
        let centerGate = try #require(scene.enemyGatePointForTesting(lane: .center))
        #expect(abs(origin.y - centerGate.y) > 1)
    }

    @Test("Keep-sourced defensive fire keeps the per-lane gate origin")
    func keepSourcedDefensiveFireKeepsLaneGateOrigin() throws {
        // City 1 (Willowford): the Keep is the fire source and covers only the .right lane.
        let scene = makeScene(store: try makeStore(
            initialState: stateWithBarracks(keepRemaining: 100, selectedLane: .right)
        ))
        let lane = scene.gameStateForTesting.siegeProgress.selectedLane

        scene.spawnSoldierForTesting()
        advanceCombatUntil(scene) { scene.defensiveFireProjectileOriginForTesting != nil }

        let origin = try #require(scene.defensiveFireProjectileOriginForTesting)
        let gate = try #require(scene.enemyGatePointForTesting(lane: lane))
        #expect(abs(origin.x - gate.x) < 0.5)
        #expect(abs(origin.y - gate.y) < 0.5)
    }

    @Test("Falconridge fortress stage tracks Keep HP only")
    func falconridgeFortressStageTracksKeepHPOnly() throws {
        func stage(for state: KingdomGameState) throws -> LivingKingdomPresentation.FortressStage {
            makeScene(store: try makeStore(initialState: state))
                .livingKingdomBattlePresentationForTesting.stage
        }

        #expect(try stage(for: falconridgeState()) == .intact)
        #expect(try stage(for: falconridgeState(
            supportDamage: [.gate: 8, .arrowTower: 34]
        )) == .intact)
        #expect(try stage(for: falconridgeState(keepRemaining: 12)) == .damaged)
        #expect(try stage(for: falconridgeState(keepRemaining: 6)) == .breached)
    }

    @Test("Tactical structures ship complete, distinct intact and ruined art")
    func siegeObjectiveAssetContractPinsProductionAssets() throws {
        #expect(BattleScene.SiegeObjectiveAssetContract.barracks == "siege-barracks")
        #expect(BattleScene.SiegeObjectiveAssetContract.gate == "siege-gate")
        #expect(BattleScene.SiegeObjectiveAssetContract.arrowTower == "siege-arrow-tower")
        for (prefix, width, height) in [
            ("siege-gate", 256, 128),
            ("siege-arrow-tower", 320, 576),
            ("siege-barracks", 320, 480)
        ] {
            let intact = try #require(UIImage(named: prefix), "Missing \(prefix)")
            let ruined = try #require(UIImage(named: prefix + "-ruined"))
            for image in [intact, ruined] {
                let cgImage = try #require(image.cgImage)
                #expect(cgImage.width == width && cgImage.height == height)
                #expect(hasTransparentPixel(in: image))
            }
            let intactBounds = try #require(opaquePixelBounds(in: intact))
            let ruinedBounds = try #require(opaquePixelBounds(in: ruined))
            #expect(intactBounds.maxYExclusive == ruinedBounds.maxYExclusive)
            #expect(rgbaPixels(in: intact) != rgbaPixels(in: ruined))
        }
    }

    @Test("Gate segments cover every blocked lane without filling a safe middle lane")
    func gateSegmentsCoverBlockedLanes() throws {
        let scene = makeScene(store: try makeStore(initialState: falconridgeState()),
                              size: CGSize(width: 393, height: 852))
        let laneWidth = try #require(scene.battleChromeLayoutForTesting).battlefield.lanePathWidth
        let gate = CitySiegeLayout.Objective(id: "gate", kind: .gate, durabilityWeight: 1,
                                            visualLane: .center, visualProgress: 0.5)
        let keep = CitySiegeLayout.Objective(id: "keep", kind: .keep, durabilityWeight: 1,
                                            visualLane: .center, visualProgress: 1)
        for mask in 1...7 {
            let lanes = BattleLane.allCases.filter { mask & (1 << $0.rawValue) != 0 }
            let layout = CitySiegeLayout(
                objectives: [gate, keep],
                routes: Dictionary(uniqueKeysWithValues: BattleLane.allCases.map {
                    ($0, lanes.contains($0) ? ["gate", "keep"] : ["keep"])
                }),
                defaultLane: .center,
                defensiveFire: .init(sourceObjectiveID: "keep", coveredLanes: BattleLane.allCases)
            )
            for remaining in [0, 10] {
                let node = scene.makeGateObjectiveForTesting(gate, layout: layout,
                                                            remainingPower: remaining, maxPower: 10)
                let segments = node.children.filter { $0.name == "siegeStructure" }
                    .sorted { $0.position.x < $1.position.x }
                #expect(segments.count == lanes.count, "lane subset \(mask)")
                let centers = lanes.map { lanePoint(scene, lane: $0, progress: 0.5).x }.sorted()
                for (segment, center) in zip(segments, centers) {
                    #expect(abs(segment.frame.width - laneWidth) <= laneWidth * 0.05)
                    #expect(abs(segment.frame.midX + node.position.x - center) < 0.5)
                    #expect(abs(segment.frame.midY) < 0.5)
                }
                let union = segments.reduce(CGRect.null) { $0.union($1.frame) }
                #expect(abs(union.minX + node.position.x - (centers[0] - laneWidth / 2)) < laneWidth * 0.05)
                #expect(abs(union.maxX + node.position.x - (centers[centers.count - 1] + laneWidth / 2))
                        < laneWidth * 0.05)
                let feedback = node.children.filter {
                    $0.name == (remaining == 0 ? "siegeRuin" : "siegeHPBackground")
                }
                #expect(feedback.count == 1, "lane subset \(mask)")
                let indicator = try #require(feedback.first)
                #expect(abs(indicator.position.x) < 0.5)
                if remaining == 0 {
                    let firstSegment = try #require(segments.first)
                    #expect(abs(indicator.position.y - firstSegment.position.y) < 0.5)
                }
                #expect(node.children.filter { $0.name == "siegeHPFill" }.count == (remaining > 0 ? 1 : 0))
            }
        }
    }

    @Test("Unchanged siege redraws retain objective nodes and resizes reuse their textures")
    func siegeRedrawReusesNodesAndTextures() throws {
        let scene = makeScene(store: try makeStore(initialState: falconridgeState()))
        let tower = try #require(scene.siegeObjectiveNodeForTesting(.arrowTower))
        let texture = try #require((tower.childNode(withName: "siegeStructure") as? SKSpriteNode)?.texture)
        scene.redrawForTesting(shouldLayout: false)
        #expect(scene.siegeObjectiveNodeForTesting(.arrowTower) === tower)
        scene.size = CGSize(width: 393, height: 852)
        scene.redrawForTesting(shouldLayout: true)
        let resized = try #require(scene.siegeObjectiveNodeForTesting(.arrowTower))
        #expect(resized !== tower)
        #expect((resized.childNode(withName: "siegeStructure") as? SKSpriteNode)?.texture === texture)
    }

    @Test("Ruin markers draw above their ruined structure art")
    func ruinMarkersDrawAboveStructureArt() throws {
        for state in [falconridgeState(supportDamage: [.gate: 8, .arrowTower: 34]),
                      highcrestState(supportDamage: [.barracks: 11])] {
            let scene = makeScene(store: try makeStore(initialState: state))
            for kind in [CitySiegeLayout.ObjectiveKind.gate, .arrowTower, .barracks] {
                guard let objective = scene.siegeObjectiveNodeForTesting(kind) else { continue }
                let structure = try #require(objective.childNode(withName: "siegeStructure"))
                let ruin = try #require(objective.childNode(withName: "siegeRuin"))
                #expect(ruin.zPosition > structure.zPosition)
            }
        }
    }

    @Test("A live hit inside the damaged stage requests no Living Kingdom transition")
    func liveHitWithinDamagedStageRequestsNoTransition() throws {
        // City 1's Keep max is 15 (Gate holds 5): 7 sits in the damaged band (4...9).
        let scene = makeScene(store: try makeStore(
            initialState: stateWithBarracks(keepRemaining: 7, selectedLane: .right)
        ))
        #expect(scene.appliedLivingKingdomFortressAssetForTesting == "lk-city-frontier-damaged")

        scene.spawnSoldierForTesting()
        advanceCombatUntil(scene) { scene.keepRemainingPowerForTesting < 7 }

        #expect(scene.keepRemainingPowerForTesting < 7)
        #expect(scene.livingKingdomTransitionEffectsForTesting.isEmpty)
        #expect(scene.appliedLivingKingdomFortressAssetForTesting == "lk-city-frontier-damaged")
    }

    @Test("An intact-to-breached live hit requests exactly one breach effect")
    func intactToBreachedLiveHitRequestsExactlyOneBreachEffect() throws {
        let scene = makeScene(store: try makeStore(
            initialState: intactFrontierCityWithEliteBarracksState()
        ))
        #expect(scene.appliedLivingKingdomFortressAssetForTesting == "lk-city-frontier-intact")
        let enemyCity = try #require(firstNode(named: "enemy-city", in: scene))

        scene.spawnSoldierForTesting()
        advanceCombatUntil(scene) { !scene.livingKingdomTransitionEffectsForTesting.isEmpty }

        #expect(scene.livingKingdomTransitionEffectsForTesting == [.breach])
        #expect(scene.appliedLivingKingdomFortressAssetForTesting == "lk-city-frontier-breached")
        #expect(scene.keepRemainingPowerForTesting >= 1)
        #expect(firstNode(named: "enemy-city", in: scene) === enemyCity)
    }

    @Test("A direct live conquest requests exactly one collapse effect")
    func directLiveConquestRequestsExactlyOneCollapseEffect() throws {
        let scene = makeScene(store: try makeStore(initialState: stateWithBarracks(keepRemaining: 1)))
        let enemyCity = try #require(firstNode(named: "enemy-city", in: scene))

        scene.spawnSoldierForTesting()
        advanceCombatUntil(scene) { scene.gameStateForTesting.pendingBattleResult != nil }

        #expect(scene.livingKingdomTransitionEffectsForTesting == [.collapse])
        #expect(scene.appliedLivingKingdomFortressAssetForTesting == "lk-city-frontier-conquered")
        #expect(firstNode(named: "enemy-city", in: scene) === enemyCity)
    }

    @Test("A restored pending-conquest scene requests no transition effects")
    func restoredPendingConquestSceneRequestsNoTransitionEffects() throws {
        let scene = makeScene(store: try makeStore(initialState: pendingConqueredState(city: 1)))

        scene.redrawForTesting(shouldLayout: true)

        #expect(scene.appliedLivingKingdomFortressAssetForTesting == "lk-city-frontier-conquered")
        #expect(scene.livingKingdomTransitionEffectsForTesting.isEmpty)
    }

    @Test("Layout refresh after a live breach does not append a transition request")
    func layoutRefreshAfterLiveBreachDoesNotAppendTransitionRequest() throws {
        let scene = makeScene(store: try makeStore(
            initialState: intactFrontierCityWithEliteBarracksState()
        ))
        scene.spawnSoldierForTesting()
        advanceCombatUntil(scene) { !scene.livingKingdomTransitionEffectsForTesting.isEmpty }
        #expect(scene.livingKingdomTransitionEffectsForTesting == [.breach])

        scene.refreshLayoutForCurrentEnvironment()
        scene.redrawForTesting(shouldLayout: true)
        scene.repeatDidMoveForTesting()

        #expect(scene.livingKingdomTransitionEffectsForTesting == [.breach])
    }

    @Test("No-layout redraw after a live hit appends no request and keeps enemy-city")
    func noLayoutRedrawAfterLiveHitAppendsNoRequestAndKeepsEnemyCity() throws {
        let scene = makeScene(store: try makeStore(initialState: stateWithBarracks(keepRemaining: 12)))
        scene.spawnSoldierForTesting()
        advanceCombatUntil(scene) { scene.keepRemainingPowerForTesting < 12 }
        #expect(scene.keepRemainingPowerForTesting < 12)

        let enemyCity = try #require(firstNode(named: "enemy-city", in: scene))
        scene.redrawForTesting(shouldLayout: false)

        #expect(scene.livingKingdomTransitionEffectsForTesting.isEmpty)
        #expect(firstNode(named: "enemy-city", in: scene) === enemyCity)
    }

    @Test("Living Kingdom transition FX plays under the pausable battlefield action layer")
    func transitionFXPlaysUnderPausableBattlefieldActionLayer() throws {
        let scene = makeScene(store: try makeStore(
            initialState: intactFrontierCityWithEliteBarracksState()
        ))
        scene.spawnSoldierForTesting()
        advanceCombatUntil(scene) { !scene.livingKingdomTransitionEffectsForTesting.isEmpty }

        let fx = try #require(scene.livingKingdomTransitionFXNodeForTesting)
        #expect(scene.isLivingKingdomTransitionFXUnderBattlefieldActionLayerForTesting)

        scene.handleTouchForTesting(at: try #require(scene.feedbackSettingsGearFrameForTesting).center)
        #expect(scene.isFeedbackSettingsVisibleForTesting)
        #expect(scene.isBattlefieldActionLayerPausedForTesting)
        #expect(scene.livingKingdomTransitionFXNodeForTesting === fx)
    }

    // MARK: Assault lane selection (HPA-468)

    @Test func tappingALaneChipSelectsTheLaneAndPersistsIt() throws {
        let store = try makeStore(initialState: SiegeTestSupport.makeBattleState(
            gold: 100,
            keepRemaining: 12,
            selectedLane: .left
        ))
        let scene = makeScene(store: store)
        let layout = try #require(scene.battleChromeLayoutForTesting)

        let hit = try #require(layout.laneChipHitFrames[.right])
        scene.handleTouchForTesting(at: CGPoint(x: hit.midX, y: hit.midY))

        #expect(scene.gameStateForTesting.siegeProgress.selectedLane == .right)
        #expect(store.load().siegeProgress.selectedLane == .right)
    }

    @Test func tappingTheAlreadySelectedLaneKeepsStageAndSelectionStable() throws {
        let store = try makeStore(initialState: SiegeTestSupport.makeBattleState(
            gold: 100,
            keepRemaining: 12,
            selectedLane: .left
        ))
        let scene = makeScene(store: store)
        let layout = try #require(scene.battleChromeLayoutForTesting)

        let hit = try #require(layout.laneChipHitFrames[.left])
        scene.handleTouchForTesting(at: CGPoint(x: hit.midX, y: hit.midY))

        #expect(scene.gameStateForTesting.stageStatus == .battleActive)
        #expect(scene.gameStateForTesting.siegeProgress.selectedLane == .left)
        #expect(store.load().siegeProgress.selectedLane == .left)
    }

    @Test func laneChipTapThatConquersDuringSettlementPresentsThePendingReport() throws {
        let start = Date(timeIntervalSinceNow: -1_000)
        var state = SiegeTestSupport.makeBattleState(gold: 100, keepRemaining: 1, selectedLane: .left)
        #expect(state.buildBuilding(.barracks, inSlot: 1, at: start) == .built(cost: 15, remainingGold: 85))
        state.enterBackground(at: start)
        let store = try makeStore(initialState: state)
        let scene = makeScene(store: store)
        let layout = try #require(scene.battleChromeLayoutForTesting)

        let hit = try #require(layout.laneChipHitFrames[.center])
        scene.handleTouchForTesting(at: CGPoint(x: hit.midX, y: hit.midY))

        #expect(scene.isConquestPopupVisibleForTesting)
        let saved = store.load()
        #expect(saved.stageStatus == .cityConqueredPendingMap)
        #expect(saved.pendingBattleResult != nil)
    }

    @Test func unrelatedBattleControlsNeverSelectTheAssaultLane() throws {
        let store = try makeStore(initialState: SiegeTestSupport.makeBattleState(
            gold: 100,
            keepRemaining: 12,
            selectedLane: .left
        ))
        let scene = makeScene(store: store)
        let layout = try #require(scene.battleChromeLayoutForTesting)

        var points = scene.underlyingControlCentersForTesting
        points.append(CGPoint(x: layout.settingsFrame.midX, y: layout.settingsFrame.midY))
        for frame in layout.medallionHitFrames {
            points.append(CGPoint(x: frame.midX, y: frame.midY))
        }
        for point in points {
            scene.handleTouchForTesting(at: point)
        }

        #expect(scene.gameStateForTesting.siegeProgress.selectedLane == .left)
        #expect(store.load().siegeProgress.selectedLane == .left)
    }

    @Test func laneChipTapsDoNothingWhileTheConquestReportOverlays() throws {
        let store = try makeStore(initialState: SiegeTestSupport.makeBattleState(
            gold: 100,
            keepRemaining: 12,
            selectedLane: .left
        ))
        let scene = makeScene(store: store)
        scene.presentConquestPopupForTesting()
        let layout = try #require(scene.battleChromeLayoutForTesting)

        for lane in BattleLane.allCases {
            let hit = try #require(layout.laneChipHitFrames[lane])
            scene.handleTouchForTesting(at: CGPoint(x: hit.midX, y: hit.midY))
        }

        #expect(scene.gameStateForTesting.siegeProgress.selectedLane == .left)
    }

    // MARK: Keep HP player-facing displays (HPA-468)

    @Test func cityInfoTooltipShowsKeepCurrentAndMaxPower() throws {
        let store = try makeStore(initialState: SiegeTestSupport.makeBattleState(
            gold: 100,
            keepRemaining: 10
        ))
        let scene = makeScene(store: store)
        let layout = try #require(scene.battleChromeLayoutForTesting)

        scene.handleTouchForTesting(at: CGPoint(x: layout.cityProgressFrame.midX, y: layout.cityProgressFrame.midY))

        let tooltip = try #require(scene.lastPresentedTooltipTextForTesting)
        let keepMax = store.load().currentKeepMaxPower
        #expect(tooltip.contains("10/\(keepMax)"))
    }

    @Test func keepSpriteHPBarReflectsTheKeepHPRatio() throws {
        // A compact size lays out the legacy Keep HP bar (the default 390x844 hides it).
        let size = CGSize(width: 393, height: 700)
        let state = SiegeTestSupport.makeBattleState(gold: 100, keepRemaining: 10)
        let keepMax = state.currentKeepMaxPower
        let scene = makeScene(store: try makeStore(initialState: state), size: size)
        let fullScene = makeScene(
            store: try makeStore(initialState: SiegeTestSupport.makeBattleState(gold: 100, keepRemaining: keepMax)),
            size: size
        )

        let fill = try #require(scene.cityHPBarFillFrameForTesting)
        let fullFill = try #require(fullScene.cityHPBarFillFrameForTesting)

        // A hidden or unlaid-out bar reports a zero-width frame, which would satisfy the ratio check
        // below vacuously (0 against 0). Both frames must carry a real width first.
        #expect(fullFill.width > 1)
        #expect(fill.width > 1)

        // Keep 10 of its authored max (15 for City 1) → the fill is 10 / keepMax of a full bar.
        // Compared against a full-Keep scene so the background stroke does not skew the frame.
        #expect(abs(fill.width - fullFill.width * 10.0 / Double(keepMax)) < 1.0)
    }

    // MARK: Highcrest Barracks + Guard presentation (HPA-469)

    private static let highcrestKeepMax = highcrestMaxPowers().keep
    private static let highcrestKeepProgress = Country1CityCatalog.definition(for: 5)
        .siegeLayout.keepObjective.visualProgress

    private static func highcrestMaxPowers() -> (keep: Int, barracks: Int) {
        let layout = Country1CityCatalog.definition(for: 5).siegeLayout
        let maxPowers = layout.maxPowerAllocation(totalBudget: KingdomGameState.cityMaxPower(for: 5))
        return (
            keep: maxPowers[layout.keepObjective.id] ?? 0,
            barracks: maxPowers[layout.barracksObjective?.id ?? ""] ?? 0
        )
    }

    /// The multiplier the HUD last applied for `type` — reads the node's
    /// current content, i.e. what the player actually sees (HPA-582 review).
    private func hudMultiplier(_ type: SoldierType, in scene: BattleScene) -> Double? {
        scene.battleHUDForTesting.currentContentForTesting?
            .medallions.first { $0.soldierType == type }?
            .damageMultiplier
    }

    /// Highcrest (City 5) battle state with durable Guard progress.
    private func highcrestState(
        keepRemaining: Int = BattleSceneTests.highcrestKeepMax,
        supportDamage: [CitySiegeLayout.ObjectiveKind: Int] = [:],
        selectedLane: BattleLane = .left,
        guardProgress: GuardReinforcementProgress = .freshCountry1(),
        slots: [Int: CityBuilding] = [:]
    ) -> KingdomGameState {
        var state = SiegeTestSupport.makeBattleState(
            atCity: 5,
            gold: 100,
            keepRemaining: keepRemaining,
            supportDamage: supportDamage,
            selectedLane: selectedLane
        )
        state.siegeProgress.guardReinforcements = guardProgress
        if !slots.isEmpty {
            state.cityBattleStates[state.currentCityKey.storageKey] = CityBattleState(slots: slots)
        }
        return state
    }

    @Test("Persisted 5-HP Guard reconstructs at Keep progress without healing")
    func persistedDamagedGuardRestoresAtKeepProgressWithoutHealing() throws {
        var state = highcrestState()
        state.siegeProgress.guardReinforcements?.unresolvedGuards = [
            GuardSnapshot(lane: .left, remainingHP: 5)
        ]
        let scene = makeScene(store: try makeStore(initialState: state))

        let guards = scene.livingGuardsForTesting
        #expect(guards.count == 1)
        let restored = try #require(guards.first)
        #expect(restored.lane == .left)
        // Persisted HP is honored verbatim — reconstruction never heals to max.
        #expect(restored.currentHP == 5)
        #expect(restored.position == BattleSceneTests.highcrestKeepProgress)
    }

    @Test("Battle reconstruction deliberately resets Guard position to Keep progress")
    func reconstructionResetsGuardPositionToKeepProgress() throws {
        var state = highcrestState()
        state.siegeProgress.guardReinforcements?.unresolvedGuards = [
            GuardSnapshot(lane: .left, remainingHP: 12)
        ]
        let firstScene = makeScene(store: try makeStore(initialState: state))
        firstScene.spawnSoldierForTesting()
        firstScene.advanceCombatForTesting(deltaTime: 0.2)

        // The Guard closed on the soldier during live combat...
        let moved = try #require(firstScene.livingGuardsForTesting.first)
        #expect(moved.position < BattleSceneTests.highcrestKeepProgress)
        #expect(moved.currentHP == 12)

        // ...and Battle reconstruction deliberately rebuilds it at the Keep.
        let secondScene = makeScene(store: try makeStore(initialState: firstScene.gameStateForTesting))
        let restored = try #require(secondScene.livingGuardsForTesting.first)
        #expect(restored.position == BattleSceneTests.highcrestKeepProgress)
        #expect(restored.currentHP == 12)
    }

    @Test("Unpaired foreground does not duplicate the restored Guard roster")
    func unpairedForegroundDoesNotDuplicateRestoredGuards() throws {
        // UIKit fires willEnterForeground on initial app activation too —
        // with no prior background. Scene init already restored the persisted
        // Guards, so the foreground restore must be idempotent: appending the
        // roster twice would persist duplicates on the next sync, and decode
        // normalization would charge the phantom Guards against the finite
        // reserve.
        var state = highcrestState()
        state.siegeProgress.guardReinforcements?.unresolvedGuards = [
            GuardSnapshot(lane: .left, remainingHP: 5)
        ]
        let store = try makeStore(initialState: state)
        let scene = makeScene(store: store)
        #expect(scene.livingGuardsForTesting.count == 1)

        NotificationCenter.default.post(name: .pyxisSceneWillEnterForeground, object: nil)

        #expect(scene.livingGuardsForTesting.count == 1)

        // The next live-snapshot sync persists exactly the restored roster.
        scene.advanceCombatForTesting(deltaTime: 0.2)
        let persisted = try #require(store.load().siegeProgress.guardReinforcements)
        #expect(persisted.unresolvedGuards == [GuardSnapshot(lane: .left, remainingHP: 5)])
        #expect(persisted.remainingReserve == Country1GuardRules.totalReserve - 1)
    }

    @Test("Cold relaunch foreground rebuilds combat Guards from the settled roster")
    func coldRelaunchForegroundRebuildsGuardsFromSettlement() throws {
        // A relaunched save still carrying `lastBackgroundedAt`: scene init
        // restores the PRE-idle roster, then the initial willEnterForeground
        // settles it — so the foreground restore must REPLACE combat's roster
        // from the post-settlement state, not skip because it is non-empty.
        // Otherwise the first tick's live-snapshot sync writes pre-idle HP
        // back over the settled damage and drops wave-materialized Guards
        // while their reserve stays consumed.
        let start = Date(timeIntervalSinceNow: -1_000)
        var state = highcrestState(
            guardProgress: GuardReinforcementProgress(
                waveElapsedSeconds: Country1GuardRules.waveIntervalSeconds - 1,
                remainingReserve: Country1GuardRules.totalReserve,
                unresolvedGuards: [
                    GuardSnapshot(lane: .left, remainingHP: Country1GuardRules.maxHP)
                ]
            )
        )
        #expect(state.buildBuilding(.barracks, inSlot: 1, at: start) == .built(cost: 15, remainingGold: 85))
        state.lastBackgroundedAt = start
        let store = try makeStore(initialState: state)
        let scene = makeScene(store: store)

        // Init restored the lone pre-idle Guard.
        #expect(scene.livingGuardsForTesting.count == 1)

        NotificationCenter.default.post(name: .pyxisSceneWillEnterForeground, object: nil)

        // 1000 idle seconds crossed the 30s wave: the whole reserve deployed
        // (one snapshot already counted against it, so 11 more materialize),
        // then ten level-1 infantry spawn hits — power 1 each on the selected
        // left lane — left the original Guard at 2 HP.
        let settled = try #require(scene.gameStateForTesting.siegeProgress.guardReinforcements)
        #expect(settled.remainingReserve == 0)
        #expect(settled.unresolvedGuards.count == Country1GuardRules.totalReserve)
        #expect(settled.unresolvedGuards.first == GuardSnapshot(lane: .left, remainingHP: 2))
        #expect(settled.unresolvedGuards.dropFirst().allSatisfy {
            $0 == GuardSnapshot(lane: .left, remainingHP: Country1GuardRules.maxHP)
        })

        // Combat now mirrors the settled roster, not the stale pre-idle one.
        let combatSnapshots = scene.livingGuardsForTesting.map {
            GuardSnapshot(lane: $0.lane, remainingHP: $0.currentHP)
        }
        #expect(combatSnapshots == settled.unresolvedGuards)

        // The first tick's sync persists the settled roster verbatim — no
        // resurrected HP and no dropped wave Guards under a consumed reserve.
        scene.advanceCombatForTesting(deltaTime: 0.2)
        let persisted = try #require(store.load().siegeProgress.guardReinforcements)
        #expect(persisted.unresolvedGuards == settled.unresolvedGuards)
        #expect(persisted.remainingReserve == settled.remainingReserve)
    }

    @Test("A guard-only tick updates SiegeProgress even when soldierAttacks is empty")
    func guardOnlyTickPersistsProgressWithoutStructureAttacks() throws {
        let barracksMax = try Self.highcrestMaxPowers().barracks
        // A level-2 infantry (from the Barracks slot) survives the Keep
        // tower's fire long enough to reach the Guard's blockade and land a
        // hit.
        var state = highcrestState(
            supportDamage: [.barracks: barracksMax - 2],
            slots: [1: CityBuilding(type: .barracks, level: 2)]
        )
        state.siegeProgress.guardReinforcements?.unresolvedGuards = [
            GuardSnapshot(lane: .left, remainingHP: 12)
        ]
        state = captainless(state)
        let store = try makeStore(initialState: state)
        let scene = makeScene(store: store)
        scene.spawnSoldierForTesting()

        let barracksID = try #require(
            SiegeTestSupport.objectiveID(for: .barracks, in: scene.gameStateForTesting)
        )
        for _ in 0..<40 {
            scene.advanceCombatSingleStepForTesting(deltaTime: 0.1)
            let persistedHP = store.load().siegeProgress.guardReinforcements?
                .unresolvedGuards.first?.remainingHP ?? 12
            if persistedHP < 12 {
                break
            }
        }

        // The Guard absorbed the soldier's attacks: HP synced into
        // SiegeProgress (an immediate save outside applyCombatResult's
        // soldierAttacks guard). The Guard's 0.28 range lets it engage the
        // soldier before the Barracks is ever reached: the Barracks shows
        // zero new structure hits — the Guard shields it completely.
        let persisted = try #require(store.load().siegeProgress.guardReinforcements)
        #expect(persisted.unresolvedGuards == [GuardSnapshot(lane: .left, remainingHP: 9)])
        #expect(store.load().siegeProgress.damageByObjectiveID[barracksID] == barracksMax - 2)
        #expect(scene.gameStateForTesting.currentKeepRemainingPower == BattleSceneTests.highcrestKeepMax)
    }

    @Test("Medallion tracks Guard-blocker engagement through the whole fight, not Guard presence")
    func medallionTracksGuardBlockerEngagementAcrossFight() throws {
        // Highcrest's left route opens at the Barracks: the mage pill reads
        // ×1.20 unblocked and trait-only ×0.80 while diverted onto a Guard.
        // Guard-only ticks produce no soldier attacks, so the engagement
        // transition refresh is the only path that can flip the pill
        // (HPA-582 review). Direct injection bypasses the deploy-charge
        // pool so no charge refill can fire an unrelated mid-fight apply.
        // The fresh Captain stays deployed: Highcrest's Keep fire (7 net
        // per shot at city level 5) plus the Guard's 3 kills a lone
        // level-1 infantry on the very tick it crosses tower range, and
        // the equal-position tie-break makes the equal-speed Captain the
        // tower/Guard target so the infantry survives to fight. The Guard
        // carries 4 HP so the first combined hit (Captain 2 + infantry 1)
        // leaves it alive — the ×0.80 window is observable — before the
        // second infantry hit finishes it.
        var state = highcrestState(
            guardProgress: GuardReinforcementProgress(
                waveElapsedSeconds: 0,
                remainingReserve: Country1GuardRules.totalReserve - 1,
                unresolvedGuards: [GuardSnapshot(lane: .left, remainingHP: 4)]
            )
        )
        let scene = makeScene(store: try makeStore(initialState: state))

        // No one has closed to the lane Guard's reach yet — the lane-level
        // "any live Guard" check would already show ×0.80 here.
        #expect(!scene.isSelectedLaneGuardBlockerEngagedForTesting)
        #expect(abs(try #require(hudMultiplier(.mage, in: scene)) - 1.2) < 0.0001)

        scene.spawnManualSoldiersDirectlyForTesting(1)

        var sawEngagedBlocked = false
        var sawRestored = false
        for _ in 0..<80 {
            scene.advanceCombatSingleStepForTesting(deltaTime: 0.1)
            let mage = try #require(hudMultiplier(.mage, in: scene))
            if scene.livingGuardsForTesting.isEmpty {
                // The last-Guard death emits only a guardLoss — no
                // soldierAttacks apply — so this same-tick restoration
                // can only come from the transition refresh.
                sawRestored = sawRestored || abs(mage - 1.2) < 0.0001
                break
            }
            if scene.isSelectedLaneGuardBlockerEngagedForTesting {
                // Same-tick as the engagement flip: without the transition
                // refresh the pill lags at ×1.20 until an unrelated apply.
                sawEngagedBlocked = sawEngagedBlocked || abs(mage - 0.8) < 0.0001
            } else {
                // Still-approaching Guard: soldiers keep hitting the
                // Barracks role-adjusted — the pill must not suppress.
                #expect(abs(mage - 1.2) < 0.0001)
            }
        }

        #expect(sawEngagedBlocked)
        #expect(sawRestored)
    }

    @Test("Wave Guards parked past soldier reach keep the Barracks bonus while they attack")
    func parkedWaveGuardsAttackingEntrenchedSoldierKeepRoleBonus() throws {
        // The wave lands after the soldier digs in at the Barracks stall,
        // so the Guards can only park at foremost-soldier + their own
        // 0.28 range — just outside every soldier's own reach — and pelt
        // it. Nothing is diverted: the pill must stay at ×1.20 through
        // the whole standoff, including the wave-arrival tick and every
        // structure-hit apply (HPA-582 review). The fresh Captain stays
        // deployed to absorb the Keep's fire: a lone level-1 infantry
        // dies to the second tower shot right after the wave lands, so
        // without the tank the Barracks damage could never keep
        // accumulating through the standoff.
        var state = highcrestState(
            guardProgress: GuardReinforcementProgress(
                waveElapsedSeconds: Country1GuardRules.waveIntervalSeconds - 2,
                remainingReserve: Country1GuardRules.totalReserve,
                unresolvedGuards: []
            )
        )
        let scene = makeScene(store: try makeStore(initialState: state))
        scene.spawnManualSoldiersDirectlyForTesting(1)

        let barracksID = try #require(
            SiegeTestSupport.objectiveID(for: .barracks, in: scene.gameStateForTesting)
        )

        var barracksDamageAtWaveArrival = 0
        var sawWaveGuards = false
        for _ in 0..<40 {
            scene.advanceCombatSingleStepForTesting(deltaTime: 0.1)
            #expect(!scene.isSelectedLaneGuardBlockerEngagedForTesting)
            #expect(abs(try #require(hudMultiplier(.mage, in: scene)) - 1.2) < 0.0001)
            if !sawWaveGuards, scene.livingGuardsForTesting.count >= 2 {
                sawWaveGuards = true
                barracksDamageAtWaveArrival = scene.gameStateForTesting
                    .siegeProgress.damageByObjectiveID[barracksID] ?? 0
            }
        }

        #expect(sawWaveGuards)
        // The Guards are live on the lane (arrived, parked, attacking)
        // while the soldier's Barracks damage kept accumulating the whole
        // time — proof the unsuppressed bonus is the honest projection.
        #expect(scene.livingGuardsForTesting.allSatisfy { $0.lane == .left })
        #expect(
            scene.gameStateForTesting.siegeProgress.damageByObjectiveID[barracksID] ?? 0
                > barracksDamageAtWaveArrival
        )
    }

    @Test("Guard wave elapsed persists through the two-second save cadence even with no player buildings")
    func guardWaveElapsedPersistsThroughSaveCadenceWithoutBuildings() throws {
        // No cityBattleState slots: the old building-only cadence never saved.
        let store = try makeStore(initialState: highcrestState())
        let scene = makeScene(store: store)

        scene.advanceCombatForTesting(deltaTime: 2.1)

        // The broadened two-second cadence fired at the 2s boundary, so the
        // persisted wave clock reads the phase saved at that boundary.
        let persisted = try #require(store.load().siegeProgress.guardReinforcements)
        #expect(abs(persisted.waveElapsedSeconds - 2.0) < 0.11)
        #expect(persisted.unresolvedGuards.isEmpty)
    }

    @Test("Barracks destroyed in the current combat tick prevents a same-frame wave")
    func barracksKillPreventsSameFrameWave() throws {
        let barracksMax = Country1CityCatalog.definition(for: 5).siegeLayout
            .maxPowerAllocation(totalBudget: KingdomGameState.cityMaxPower(for: 5))[
            Country1CityCatalog.definition(for: 5).siegeLayout.barracksObjective!.id
        ] ?? 0

        // Discovery run: with fresh wave progress, find the deterministic tick
        // where the soldier's first in-range attack kills the 1-HP Barracks.
        func killTick(waveElapsedSeed: Double) -> Int? {
            let store = try? makeStore(initialState: highcrestState(
                supportDamage: [.barracks: barracksMax - 1],
                guardProgress: GuardReinforcementProgress(
                    waveElapsedSeconds: waveElapsedSeed,
                    remainingReserve: 12,
                    unresolvedGuards: []
                )
            ))
            guard let store else {
                return nil
            }
            let scene = makeScene(store: store)
            scene.spawnSoldierForTesting()
            guard let barracksID = SiegeTestSupport.objectiveID(for: .barracks, in: scene.gameStateForTesting) else {
                return nil
            }
            func isBarracksDead() -> Bool {
                (store.load().currentSiegeSnapshot.objectiveRemainingPower[barracksID] ?? 1) <= 0
            }
            #expect(!isBarracksDead())
            for step in 0..<60 {
                scene.advanceCombatSingleStepForTesting(deltaTime: 0.1)
                if isBarracksDead() {
                    return step + 1
                }
            }
            return nil
        }

        let tick = try #require(killTick(waveElapsedSeed: 0))
        // Seed so the wave becomes due exactly on the kill tick (with a 0.05
        // margin against float drift) and not one tick earlier.
        let alignedSeed = Country1GuardRules.waveIntervalSeconds + 0.05 - Double(tick) * 0.1
        let store = try makeStore(initialState: highcrestState(
            supportDamage: [.barracks: barracksMax - 1],
            guardProgress: GuardReinforcementProgress(
                waveElapsedSeconds: alignedSeed,
                remainingReserve: 12,
                unresolvedGuards: []
            )
        ))
        let scene = makeScene(store: store)
        scene.spawnSoldierForTesting()

        var killed = false
        let barracksID = "highcrest.barracks"
        for _ in 0..<60 where !killed {
            scene.advanceCombatSingleStepForTesting(deltaTime: 0.1)
            killed = (store.load().currentSiegeSnapshot.objectiveRemainingPower[barracksID] ?? 1) <= 0
        }
        #expect(killed)

        // The wave was due exactly on the kill frame: wave clock had advanced
        // up to the kill tick, but the dead Barracks blocked the same-frame
        // spawn — and keeps blocking every later advance.
        var persisted = try #require(store.load().siegeProgress.guardReinforcements)
        #expect(abs(persisted.waveElapsedSeconds - (alignedSeed + Double(tick - 1) * 0.1)) < 0.001)
        #expect(persisted.unresolvedGuards.isEmpty)
        #expect(persisted.remainingReserve == 12)

        for _ in 0..<70 {
            scene.advanceCombatSingleStepForTesting(deltaTime: 0.1)
        }
        persisted = try #require(store.load().siegeProgress.guardReinforcements)
        #expect(persisted.unresolvedGuards.isEmpty)
        #expect(persisted.remainingReserve == 12)
    }

    @Test("A Keep-only lane creates no Guard or Barracks nodes")
    func keepOnlyLaneCreatesNoGuardOrBarracksNodes() throws {
        // City 1 (Willowford) authors no Barracks objective, so its Barracks building spawns no Guards.
        let scene = makeScene(store: try makeStore(
            initialState: stateWithBarracks(selectedLane: .right)
        ))
        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 6.2)

        #expect(scene.siegeObjectiveNodeForTesting(.barracks) == nil)
        #expect(scene.siegeObjectiveNodeCountForTesting == 1)
        #expect(scene.livingGuardsForTesting.isEmpty)
        #expect(scene.guardNodeCountForTesting == 0)
    }

    @Test("Highcrest renders a procedural barracks with a GUARDS label at its authored progress")
    func highcrestRendersBarracksWithGuardsLabel() throws {
        let scene = makeScene(store: try makeStore(initialState: highcrestState()))
        let barracks = try #require(scene.siegeObjectiveNodeForTesting(.barracks))

        #expect(barracks.name == "siegeObjective-highcrest.barracks")
        let expected = lanePoint(scene, lane: .left, progress: 0.72)
        #expect(abs(barracks.position.x - expected.x) < 0.5)
        #expect(abs(barracks.position.y - expected.y) < 0.5)
        #expect(barracks.childNode(withName: "siegeStructure") != nil)
        #expect(barracks.childNode(withName: "siegeHPFill") != nil)
        let label = try #require(
            barracks.childNode(withName: "siegeBarracksStatus") as? SKLabelNode
        )
        // Reserve remains with zero Guards resolved so far.
        #expect(label.text == "GUARDS 0")
    }

    @Test("Guard waves spawn into combat and the label tracks the living count")
    func wavesSpawnIntoCombatAndLabelTracksCount() throws {
        // The guard clock starts at 29.95s so the first wave is due after one
        // 0.1s tick, and the window stays far below the City 3+ Captain's 12s
        // revival: a full 30s run would deploy a Captain onto the guards'
        // lane (fresh or revived), and any soldier there marches the wave off
        // Keep progress — the Highcrest Barracks is only 11 HP now, so the
        // old full-window shape also risked a Barracks shutdown.
        var state = captainless(highcrestState(
            guardProgress: GuardReinforcementProgress(
                waveElapsedSeconds: 29.95,
                remainingReserve: Country1GuardRules.totalReserve,
                unresolvedGuards: []
            )
        ))
        let scene = makeScene(store: try makeStore(initialState: state))

        scene.advanceCombatForTesting(deltaTime: 0.5)

        // One due wave: 2 full-HP Guards restored at Keep progress with nodes.
        #expect(scene.livingGuardsForTesting.count == 2)
        #expect(scene.guardNodeCountForTesting == 2)
        for restored in scene.livingGuardsForTesting {
            #expect(restored.currentHP == 12)
            #expect(restored.position == BattleSceneTests.highcrestKeepProgress)
        }
        let label = try #require(
            scene.siegeObjectiveNodeForTesting(.barracks)?.childNode(
                withName: "siegeBarracksStatus"
            ) as? SKLabelNode
        )
        #expect(label.text == "GUARDS 2")
    }

    private func sceneWithOneGuard() throws -> BattleScene {
        var state = highcrestState()
        state.siegeProgress.guardReinforcements?.unresolvedGuards = [
            GuardSnapshot(lane: .left, remainingHP: 12)
        ]
        return makeScene(store: try makeStore(initialState: captainless(state)),
                         size: CGSize(width: 393, height: 852))
    }

    @Test("Guard uses authored enemy art at infantry body height with grounded feet")
    func guardUsesAuthoredArtAndInfantryGeometry() throws {
        let scene = try sceneWithOneGuard()
        let root = try #require(scene.firstLivingGuardRootNodeForTesting)
        let visual = try #require(scene.firstLivingGuardVisualNodeForTesting)
        let body = try #require(visual.childNode(withName: "guardBody") as? SKSpriteNode)
        let texture = try #require(body.texture)
        let firstWalk = try #require(UIImage(named: "siege-guard-walk-01"))
        #expect(root.name == "siege-guard")
        #expect(rgbaPixels(in: UIImage(cgImage: texture.cgImage())) == rgbaPixels(in: firstWalk))
        // At 852pt scene height the body is 63.9pt; infantry's canvas/body ratio is 128/94.
        #expect(abs(body.size.width * root.xScale - 63.9 * 128 / 94) < 0.01)
        #expect(abs(body.size.height * root.yScale - 63.9 * 128 / 94) < 0.01)
        #expect(body.anchorPoint == CGPoint(x: 0.5, y: 0))
        #expect(abs(body.position.y * root.yScale + 63.9 * 8 / 94) < 0.01)
        #expect(visual.action(forKey: "soldierWalkAnimation") == nil)
    }

    @Test("Guard art leaves Barracks count and objective HP overlays in front")
    func guardArtKeepsObjectiveOverlaysReadable() throws {
        let scene = try sceneWithOneGuard()
        let visual = try #require(scene.firstLivingGuardVisualNodeForTesting)
        let body = try #require(visual.childNode(withName: "guardBody"))
        let barracks = try #require(scene.siegeObjectiveNodeForTesting(.barracks))
        let status = try #require(barracks.childNode(withName: "siegeBarracksStatus"))
        let background = try #require(barracks.childNode(withName: "siegeHPBackground"))
        let fill = try #require(barracks.childNode(withName: "siegeHPFill"))
        scene.spawnSoldierForTesting()
        let soldier = try #require(firstNode(named: "normal-soldier", in: scene))
        let soldierHP = try #require(soldier.children.first { $0.zPosition == 3 })
        func stackingZ(_ node: SKNode) -> CGFloat {
            sequence(first: node, next: { $0.parent }).reduce(0) { $0 + $1.zPosition }
        }
        #expect(stackingZ(status) > stackingZ(body))
        #expect(stackingZ(background) > stackingZ(body))
        #expect(stackingZ(background) > stackingZ(soldierHP))
        #expect(stackingZ(fill) > stackingZ(background))
    }

    @Test("A moving Guard starts its authored walk loop")
    func movingGuardStartsWalkArt() throws {
        let scene = try sceneWithOneGuard()
        let before = try #require(scene.livingGuardsForTesting.first).position
        scene.spawnSoldierForTesting()
        scene.advanceCombatSingleStepForTesting(deltaTime: 0.1)
        let after = try #require(scene.livingGuardsForTesting.first).position
        #expect(after < before)
        #expect(scene.firstLivingGuardVisualNodeForTesting?.action(forKey: "soldierWalkAnimation") != nil)
    }

    @Test("A redundant Guard sync without movement keeps the walk loop running")
    func redundantGuardSyncKeepsWalkLoop() throws {
        // Objective-damage and auto-Rally ticks run `redraw` → a second
        // `syncGuardNodes` after positions already advanced. That extra sync
        // sees unchanged progress and must not clear a walk loop the tick
        // already started; movement is observed per combat tick, not per
        // sync call. Combat is frozen so only the explicit step moves the
        // Guard — a racing render-loop tick would legitimately restart the
        // loop and mask the regression.
        var state = highcrestState()
        state.siegeProgress.guardReinforcements?.unresolvedGuards = [
            GuardSnapshot(lane: .left, remainingHP: 12)
        ]
        let scene = makeScene(
            store: try makeStore(initialState: captainless(state)),
            launchArguments: [BattleScene.freezeCombatLaunchArgument],
            size: CGSize(width: 393, height: 852)
        )
        scene.spawnSoldierForTesting()
        scene.advanceCombatSingleStepForTesting(deltaTime: 0.1)
        let before = try #require(scene.livingGuardsForTesting.first).position
        let visual = try #require(scene.firstLivingGuardVisualNodeForTesting)
        #expect(visual.action(forKey: "soldierWalkAnimation") != nil)

        scene.redrawForTesting(shouldLayout: false)

        let visualAfter = try #require(scene.firstLivingGuardVisualNodeForTesting)
        #expect(visualAfter === visual)
        #expect(scene.livingGuardsForTesting.first?.position == before)
        #expect(visualAfter.action(forKey: "soldierWalkAnimation") != nil)
    }

    @Test("Guard attack does not restart and progress sync preserves the transient")
    func guardAttackDoesNotRestartDuringSync() throws {
        let scene = try sceneWithOneGuard()
        let visual = try #require(scene.firstLivingGuardVisualNodeForTesting)
        scene.playGuardAttackFeedbackForTesting()
        let attack = try #require(visual.action(forKey: "soldierAttackAnimation"))
        let body = try #require(visual.childNode(withName: "guardBody") as? SKSpriteNode)
        let texture = try #require(body.texture)
        let firstAttack = try #require(UIImage(named: "siege-guard-attack-01"))
        #expect(rgbaPixels(in: UIImage(cgImage: texture.cgImage())) == rgbaPixels(in: firstAttack))
        scene.playGuardAttackFeedbackForTesting()
        #expect(visual.action(forKey: "soldierAttackAnimation") === attack)
        scene.spawnSoldierForTesting()
        scene.advanceCombatSingleStepForTesting(deltaTime: 0.1)
        #expect(visual.action(forKey: "soldierAttackAnimation") === attack)
        #expect(visual.action(forKey: "soldierWalkAnimation") == nil)
    }

    @Test("Guard hit preempts attack, and repeated hits or a mid-hit attack never restart the live hit")
    func guardHitPreemptsAttackWithoutRestart() throws {
        let scene = try sceneWithOneGuard()
        let visual = try #require(scene.firstLivingGuardVisualNodeForTesting)
        scene.playGuardAttackFeedbackForTesting()
        scene.playGuardHitFeedbackForTesting()
        let hit = try #require(visual.action(forKey: "soldierHitAnimation"))
        let body = try #require(visual.childNode(withName: "guardBody") as? SKSpriteNode)
        let texture = try #require(body.texture)
        let firstHit = try #require(UIImage(named: "siege-guard-hit-01"))
        #expect(rgbaPixels(in: UIImage(cgImage: texture.cgImage())) == rgbaPixels(in: firstHit))
        #expect(visual.action(forKey: "soldierAttackAnimation") == nil)

        // A live hit absorbs repeated hits and blocks attacks outright —
        // the in-flight pose and its countdown are left untouched.
        let hitRemaining = try #require(scene.firstLivingGuardTransientRemainingForTesting)
        for _ in 0..<3 { scene.playGuardHitFeedbackForTesting() }
        #expect(visual.action(forKey: "soldierHitAnimation") === hit)
        #expect(scene.firstLivingGuardTransientRemainingForTesting == hitRemaining)
        scene.playGuardAttackFeedbackForTesting()
        #expect(visual.action(forKey: "soldierHitAnimation") === hit)
        #expect(visual.action(forKey: "soldierAttackAnimation") == nil)
        #expect(scene.firstLivingGuardTransientRemainingForTesting == hitRemaining)

        // Once the hit expires on combat elapsed time, the next attack
        // starts a fresh cycle. No soldier is spawned, so the model emits
        // no competing Guard events while the countdown drains.
        for _ in 0..<10 { scene.advanceCombatSingleStepForTesting(deltaTime: 0.1) }
        #expect(visual.action(forKey: "soldierHitAnimation") == nil)
        scene.playGuardAttackFeedbackForTesting()
        #expect(visual.action(forKey: "soldierAttackAnimation") != nil)
        #expect(visual.action(forKey: "soldierWalkAnimation") == nil)
    }

    @Test("Guard transients expire on elapsed time without a SpriteKit render loop")
    func guardTransientsExpireWithoutRenderLoop() throws {
        let scene = try sceneWithOneGuard()
        let visual = try #require(scene.firstLivingGuardVisualNodeForTesting)
        scene.playGuardAttackFeedbackForTesting()
        let firstAttack = try #require(visual.action(forKey: "soldierAttackAnimation"))
        for _ in 0..<21 { scene.advanceCombatSingleStepForTesting(deltaTime: 0.1) }
        #expect(visual.action(forKey: "soldierAttackAnimation") == nil)
        scene.playGuardAttackFeedbackForTesting()
        #expect(visual.action(forKey: "soldierAttackAnimation") !== firstAttack)
        scene.playGuardHitFeedbackForTesting()
        for _ in 0..<10 { scene.advanceCombatSingleStepForTesting(deltaTime: 0.1) }
        #expect(visual.action(forKey: "soldierHitAnimation") == nil)
        scene.spawnSoldierForTesting()
        scene.advanceCombatSingleStepForTesting(deltaTime: 0.1)
        #expect(visual.action(forKey: "soldierWalkAnimation") != nil)
        scene.advanceCombatSingleStepForTesting(deltaTime: 0)
        #expect(visual.action(forKey: "soldierWalkAnimation") == nil)
    }

    @Test("A Guard hit countdown expires at the authored duration without floating-point residue")
    func guardHitCountdownExpiresAtAuthoredDuration() throws {
        // Nine 0.1s decrements from the 0.9s hit leave ~1.4e-16 rather than
        // zero; without the 1ms snap the residue keeps `transientRemaining`
        // positive and `playGuardTransient` drops an attack landing at the
        // expiry boundary — the failure mode the soldier hit countdown
        // already tolerates. No soldier is spawned, so the model emits no
        // competing Guard events while the countdown drains.
        let scene = try sceneWithOneGuard()
        let visual = try #require(scene.firstLivingGuardVisualNodeForTesting)
        scene.playGuardHitFeedbackForTesting()
        #expect(visual.action(forKey: "soldierHitAnimation") != nil)

        for _ in 0..<9 { scene.advanceCombatSingleStepForTesting(deltaTime: 0.1) }

        #expect(scene.firstLivingGuardTransientRemainingForTesting == nil)
        #expect(visual.action(forKey: "soldierHitAnimation") == nil)
        scene.playGuardAttackFeedbackForTesting()
        #expect(visual.action(forKey: "soldierAttackAnimation") != nil)
    }

    @Test("A static-fallback Guard (partial catalog) keeps a procedural body and skips transient playback")
    func staticFallbackGuardKeepsProceduralBodyAndSkipsTransients() throws {
        // Simulates the release-build failure mode where the `siege-guard`
        // trio is partially installed: the animated-canvas probe fails, so
        // the Guard must keep the pre-art procedural body instead of a
        // textureless sprite, and walk/transient playback must not install
        // on it — mirroring the soldier `isAnimatedCanvas` gate.
        let scene = try sceneWithOneGuard()
        scene.forceGuardStaticFallbackCanvasForTesting()

        #expect(scene.firstLivingGuardIsAnimatedCanvasForTesting == false)
        let visual = try #require(scene.firstLivingGuardVisualNodeForTesting)
        let body = try #require(visual.childNode(withName: "guardBody"))
        #expect(body is SKShapeNode)
        #expect(visual.childNode(withName: "guardShield") != nil)

        scene.playGuardAttackFeedbackForTesting()
        #expect(visual.action(forKey: "soldierAttackAnimation") == nil)
        scene.playGuardHitFeedbackForTesting()
        #expect(visual.action(forKey: "soldierHitAnimation") == nil)
        #expect(scene.firstLivingGuardTransientRemainingForTesting == nil)

        // A moving fallback Guard never starts the walk loop either.
        scene.spawnSoldierForTesting()
        scene.advanceCombatSingleStepForTesting(deltaTime: 0.1)
        #expect(visual.action(forKey: "soldierWalkAnimation") == nil)
    }

    @Test("Barracks death shows SHUT DOWN and keeps surviving Guards")
    func barracksDeathShowsShutdownWithSurvivingGuard() throws {
        var state = highcrestState(supportDamage: [.barracks: Int.max])
        state.siegeProgress.guardReinforcements?.unresolvedGuards = [
            GuardSnapshot(lane: .left, remainingHP: 7)
        ]
        let scene = makeScene(store: try makeStore(initialState: state))
        let barracks = try #require(scene.siegeObjectiveNodeForTesting(.barracks))

        #expect(barracks.childNode(withName: "siegeRuin") != nil)
        #expect(barracks.childNode(withName: "siegeHPFill") == nil)
        let label = try #require(
            barracks.childNode(withName: "siegeBarracksStatus") as? SKLabelNode
        )
        #expect(label.text == "SHUT DOWN")
        #expect(scene.livingGuardsForTesting.count == 1)
        #expect(scene.guardNodeCountForTesting == 1)
    }

    @Test("Guard hit and loss events map to observational actions and persisted removal")
    func guardHitAndLossMapToObservationalActions() throws {
        // Level-5 soldier (power 5): the first contact hit wounds the Guard
        // 12→7 with the hit action observable on a living Guard's node, and
        // the third hit kills it — all within the step budget and before the
        // Keep tower can chew through the soldier's HP. A one-hit kill would
        // land the hit action and the loss in the same tick, where the
        // post-tick lookup can never observe the action.
        var state = highcrestState(slots: [1: CityBuilding(type: .barracks, level: 5)])
        state.siegeProgress.guardReinforcements?.unresolvedGuards = [
            GuardSnapshot(lane: .left, remainingHP: 12)
        ]
        let store = try makeStore(initialState: state)
        let scene = makeScene(store: store)
        scene.spawnSoldierForTesting()

        var sawHitAction = false
        for _ in 0..<50 {
            scene.advanceCombatSingleStepForTesting(deltaTime: 0.1)
            if let visual = scene.firstLivingGuardVisualNodeForTesting {
                sawHitAction = sawHitAction || visual.action(forKey: "soldierHitAnimation") != nil
            }
            if scene.guardNodeCountForTesting == 0 {
                break
            }
        }

        #expect(sawHitAction)
        // The Guard died: the fade-out removal cleared its node and the sync
        // persisted the removal into SiegeProgress.
        #expect(scene.guardNodeCountForTesting == 0)
        let persisted = try #require(store.load().siegeProgress.guardReinforcements)
        #expect(persisted.unresolvedGuards.isEmpty)
    }

    @Test("Guard attack events map to an observational lunge action")
    func guardAttackMapsToObservationalAction() throws {
        // Right lane bypasses the Barracks: the descending Guard meets the
        // marching cavalry well above the Barracks floor. Cavalry's faster
        // march closes the gap strictly inside the Guard's 0.28 attack range
        // during descent, so the Guard's counterattack fires deterministically
        // while it is alive.
        var state = highcrestState(
            selectedLane: .right,
            slots: [1: CityBuilding(type: .stable, level: 7)]
        )
        state.siegeProgress.guardReinforcements?.unresolvedGuards = [
            GuardSnapshot(lane: .right, remainingHP: 12)
        ]
        let scene = makeScene(store: try makeStore(initialState: state))
        scene.selectManualSoldierTypeForTesting(.cavalry)
        scene.spawnSoldierForTesting()

        var sawAttackAction = false
        for _ in 0..<30 where !sawAttackAction {
            scene.advanceCombatSingleStepForTesting(deltaTime: 0.1)
            if let visual = scene.firstLivingGuardVisualNodeForTesting {
                sawAttackAction = visual.action(forKey: "soldierAttackAnimation") != nil
            }
        }

        #expect(sawAttackAction)
    }

    @Test("Living Guards survive a background and foreground cycle")
    func guardsSurviveBackgroundForegroundCycle() throws {
        var state = highcrestState()
        state.siegeProgress.guardReinforcements?.unresolvedGuards = [
            GuardSnapshot(lane: .left, remainingHP: 5)
        ]
        let store = try makeStore(initialState: state)
        let scene = makeScene(store: store)

        scene.enterBackgroundForTesting(at: Date(timeIntervalSince1970: 1_000))
        scene.enterForegroundForTesting(at: Date(timeIntervalSince1970: 1_002))

        // The first tick after foreground syncs the live combat roster back
        // into SiegeProgress; the persisted damaged Guard must survive it.
        scene.advanceCombatForTesting(deltaTime: 0.1)

        let persisted = try #require(store.load().siegeProgress.guardReinforcements)
        #expect(persisted.unresolvedGuards == [GuardSnapshot(lane: .left, remainingHP: 5)])
        #expect(scene.livingGuardsForTesting.count == 1)
        #expect(scene.guardNodeCountForTesting == 1)
    }

    // MARK: Non-Keep structure-fall feedback (HPA-582 Task 5)

    /// Battle state whose `kind` objective sits at exactly 1 HP, so the next
    /// live hit is a fresh destruction while the Keep stays comfortably
    /// alive. `selectedLane` pins the assault lane.
    private func stateWithObjectiveAtOneHP(
        cityNumber: Int,
        kind: CitySiegeLayout.ObjectiveKind,
        keepRemaining: Int,
        selectedLane: BattleLane? = nil
    ) throws -> KingdomGameState {
        var state = SiegeTestSupport.makeBattleState(
            atCity: cityNumber,
            keepRemaining: keepRemaining,
            selectedLane: selectedLane
        )
        let objectiveID = try #require(SiegeTestSupport.objectiveID(for: kind, in: state))
        let maxPower = try #require(
            state.currentCityDefinition.siegeLayout
                .maxPowerAllocation(totalBudget: state.cityMaxPower)[objectiveID]
        )
        state.siegeProgress.damageByObjectiveID[objectiveID] = maxPower - 1
        return state
    }

    @Test("A fresh Gate kill requests exactly one structure fall")
    func freshGateKillRequestsExactlyOneFallEvent() throws {
        // City 1's default center route opens with the Gate; its Keep holds
        // 15 HP, so the kill is the Gate alone and the siege continues.
        let state = try stateWithObjectiveAtOneHP(
            cityNumber: 1,
            kind: .gate,
            keepRemaining: 15
        )
        let gateID = try #require(SiegeTestSupport.objectiveID(for: .gate, in: state))
        let scene = makeScene(store: try makeStore(initialState: state))

        scene.spawnSoldierForTesting()
        advanceCombatUntil(scene) { !scene.structureFallRequestsForTesting.isEmpty }
        // Keep marching past the kill: the dead Gate must never fall twice.
        scene.advanceCombatForTesting(deltaTime: 2.0)

        #expect(scene.structureFallRequestsForTesting == [gateID])
        #expect(scene.gameStateForTesting.stageStatus == .battleActive)
    }

    @Test("A fresh Arrow Tower kill requests exactly one structure fall")
    func freshArrowTowerKillRequestsExactlyOneFallEvent() throws {
        // Falconridge's left route opens with the Arrow Tower; captainless so
        // the ordinary-soldier path is the only trigger.
        let state = captainless(try stateWithObjectiveAtOneHP(
            cityNumber: 3,
            kind: .arrowTower,
            keepRemaining: 26,
            selectedLane: .left
        ))
        let towerID = try #require(SiegeTestSupport.objectiveID(for: .arrowTower, in: state))
        let scene = makeScene(store: try makeStore(initialState: state))

        scene.spawnSoldierForTesting()
        advanceCombatUntil(scene) { !scene.structureFallRequestsForTesting.isEmpty }
        scene.advanceCombatForTesting(deltaTime: 2.0)

        #expect(scene.structureFallRequestsForTesting == [towerID])
        #expect(scene.gameStateForTesting.stageStatus == .battleActive)
    }

    @Test("A fresh Barracks kill requests exactly one structure fall")
    func freshBarracksKillRequestsExactlyOneFallEvent() throws {
        // Highcrest's left route opens with the Barracks.
        let state = captainless(try stateWithObjectiveAtOneHP(
            cityNumber: 5,
            kind: .barracks,
            keepRemaining: 1_000,
            selectedLane: .left
        ))
        let barracksID = try #require(SiegeTestSupport.objectiveID(for: .barracks, in: state))
        let scene = makeScene(store: try makeStore(initialState: state))

        scene.spawnSoldierForTesting()
        advanceCombatUntil(scene) { !scene.structureFallRequestsForTesting.isEmpty }
        scene.advanceCombatForTesting(deltaTime: 2.0)

        #expect(scene.structureFallRequestsForTesting == [barracksID])
        #expect(scene.gameStateForTesting.stageStatus == .battleActive)
    }

    @Test("Reduce Motion still announces a support-structure fall without motion")
    func reduceMotionStillAnnouncesStructureFall() throws {
        // The killing hit skips the shake/rise variant but keeps the label
        // and flash — Reduce Motion must not silence the kill entirely.
        let state = captainless(try stateWithObjectiveAtOneHP(
            cityNumber: 3,
            kind: .arrowTower,
            keepRemaining: 26,
            selectedLane: .left
        ))
        let towerID = try #require(SiegeTestSupport.objectiveID(for: .arrowTower, in: state))
        let scene = makeScene(store: try makeStore(initialState: state))
        scene.isReduceMotionEnabled = { true }

        scene.spawnSoldierForTesting()
        advanceCombatUntil(scene) { !scene.structureFallRequestsForTesting.isEmpty }
        scene.advanceCombatForTesting(deltaTime: 2.0)

        #expect(scene.structureFallRequestsForTesting == [towerID])
        #expect(scene.floatingFeedbackTextsForTesting.contains("Tower down"))
        #expect(scene.gameStateForTesting.stageStatus == .battleActive)
    }

    @Test("Same-tick hits that destroy an objective coalesce into one fall")
    func sameTickKillingHitsCoalesceIntoOneFallEvent() throws {
        // The Gate holds 2 HP and three lockstep infantry each deal exactly
        // 1, so the first in-range tick carries multiple killing-batch hits
        // on the same objective — grouped aggregation must emit one fall.
        var state = try stateWithObjectiveAtOneHP(
            cityNumber: 1,
            kind: .gate,
            keepRemaining: 15
        )
        let gateID = try #require(SiegeTestSupport.objectiveID(for: .gate, in: state))
        state.siegeProgress.damageByObjectiveID[gateID, default: 0] -= 1
        let scene = makeScene(store: try makeStore(initialState: state))

        scene.spawnManualSoldiersDirectlyForTesting(3)
        advanceCombatUntil(scene) { !scene.structureFallRequestsForTesting.isEmpty }
        scene.advanceCombatForTesting(deltaTime: 2.0)

        #expect(scene.structureFallRequestsForTesting == [gateID])
        // Both 1-damage hits landed: the 2-HP Gate absorbed its full budget.
        let gateMax = try #require(
            state.currentCityDefinition.siegeLayout
                .maxPowerAllocation(totalBudget: state.cityMaxPower)[gateID]
        )
        #expect(scene.gameStateForTesting.siegeProgress.damageByObjectiveID[gateID] == gateMax)
    }

    @Test("A Keep kill stays conquest-only and requests no structure fall")
    func keepKillRequestsNoStructureFall() throws {
        var state = SiegeTestSupport.makeBattleState(atCity: 1, keepRemaining: 1)
        SiegeTestSupport.destroySupportObjectives(of: &state)
        let scene = makeScene(store: try makeStore(initialState: state))

        scene.spawnSoldierForTesting()
        advanceCombatUntil(scene) { scene.gameStateForTesting.pendingBattleResult != nil }

        #expect(scene.structureFallRequestsForTesting.isEmpty)
        #expect(scene.livingKingdomTransitionEffectsForTesting == [.collapse])
    }

    @Test("Restore, resize, and pre-existing ruins request no structure falls")
    func restoreResizeAndOldRuinsRequestNoFalls() throws {
        // Restored pending-conquest scene: no live tick, no fall.
        let restored = makeScene(store: try makeStore(initialState: pendingConqueredState(city: 3)))
        restored.redrawForTesting(shouldLayout: true)
        restored.repeatDidMoveForTesting()
        #expect(restored.structureFallRequestsForTesting.isEmpty)

        // Mid-siege restore: ruins persisted from a previous session. Live
        // ticks after restore march past the ruins without re-killing them.
        let midSiegeState = captainless(SiegeTestSupport.makeBattleState(
            atCity: 3,
            keepRemaining: 26,
            supportDamage: [.gate: 8, .arrowTower: 34],
            selectedLane: .center
        ))
        let scene = makeScene(store: try makeStore(initialState: midSiegeState))
        scene.redrawForTesting(shouldLayout: true)
        scene.repeatDidMoveForTesting()

        scene.spawnSoldierForTesting()
        advanceCombatUntil(scene) { scene.keepRemainingPowerForTesting < 26 }

        #expect(scene.structureFallRequestsForTesting.isEmpty)
        #expect(scene.gameStateForTesting.stageStatus == .battleActive)
    }

    @Test("Layout refresh and didMove replay never repeat a fall request")
    func layoutRefreshAndDidMoveNeverRepeatFallRequest() throws {
        let state = try stateWithObjectiveAtOneHP(
            cityNumber: 1,
            kind: .gate,
            keepRemaining: 15
        )
        let gateID = try #require(SiegeTestSupport.objectiveID(for: .gate, in: state))
        let scene = makeScene(store: try makeStore(initialState: state))

        scene.spawnSoldierForTesting()
        advanceCombatUntil(scene) { !scene.structureFallRequestsForTesting.isEmpty }
        #expect(scene.structureFallRequestsForTesting == [gateID])

        scene.refreshLayoutForCurrentEnvironment()
        scene.redrawForTesting(shouldLayout: true)
        scene.repeatDidMoveForTesting()

        #expect(scene.structureFallRequestsForTesting == [gateID])
    }

    @Test("Idle settlement damage requests no structure fall")
    func idleSettlementRequestsNoStructureFall() throws {
        // A 1-HP Keep with a built Barracks: the foreground idle settlement
        // deals enough offline damage to conquer without any live tick.
        let state = idleConquestReadyState()
        let scene = makeScene(store: try makeStore(initialState: state))

        scene.enterBackgroundForTesting(at: Date(timeIntervalSince1970: 1_000))
        scene.enterForegroundForTesting(at: Date(timeIntervalSince1970: 10_000))

        #expect(scene.gameStateForTesting.pendingBattleResult != nil)
        #expect(scene.structureFallRequestsForTesting.isEmpty)
    }

    @Test("A Captain kill requests exactly one structure fall")
    func captainKillRequestsExactlyOneFallEvent() throws {
        // City 3 seeds a fresh Captain on the entry-selected lane and no
        // manual soldier is spawned, so the Captain's attack path is the
        // only possible trigger of the fall.
        let state = try stateWithObjectiveAtOneHP(
            cityNumber: 3,
            kind: .arrowTower,
            keepRemaining: 26,
            selectedLane: .left
        )
        let towerID = try #require(SiegeTestSupport.objectiveID(for: .arrowTower, in: state))
        let scene = makeScene(store: try makeStore(initialState: state))

        advanceCombatUntil(scene) { !scene.structureFallRequestsForTesting.isEmpty }
        scene.advanceCombatForTesting(deltaTime: 2.0)

        #expect(scene.structureFallRequestsForTesting == [towerID])
        #expect(scene.gameStateForTesting.stageStatus == .battleActive)
    }

    @Test("A fresh fall lands its label on the destroyed objective's geometry")
    func freshFallAnchorsAtObjectiveGeometry() throws {
        let state = try stateWithObjectiveAtOneHP(
            cityNumber: 1,
            kind: .gate,
            keepRemaining: 15
        )
        let scene = makeScene(store: try makeStore(initialState: state))

        scene.spawnSoldierForTesting()
        advanceCombatUntil(scene) { !scene.structureFallRequestsForTesting.isEmpty }

        // SKActions never advance without a render loop, so the just-added
        // fall label still sits at its spawn point: the Gate's feedback
        // geometry (its ruin frame), not the Keep's damage spot.
        let gate = try #require(scene.siegeObjectiveNodeForTesting(.gate))
        let gateFrame = gate.calculateAccumulatedFrame()
        let labelPoints = scene.floatingFeedbackPositionsForTesting
        #expect(labelPoints.contains {
            abs($0.x - gateFrame.midX) < 1 && abs($0.y - (gateFrame.midY - 20)) < 1
        })
    }
}

private extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}

private final class SafeAreaOverridingSKView: SKView {
    private let overrideInsets: UIEdgeInsets

    init(frame: CGRect, overrideInsets: UIEdgeInsets) {
        self.overrideInsets = overrideInsets
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var safeAreaInsets: UIEdgeInsets {
        overrideInsets
    }
}
