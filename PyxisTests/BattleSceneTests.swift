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
        let maxXExclusive: Int
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
            store: try makeStore(initialState: stateWithBarracks(cityRemainingPower: 20)),
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
            store: try makeStore(initialState: stateWithBarracks(gold: 123, cityRemainingPower: 200)),
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
            store: try makeStore(initialState: stateWithBarracks(gold: 123, cityRemainingPower: 200)),
            size: CGSize(width: 393, height: 852)
        )
        let layout = try #require(scene.battleChromeLayoutForTesting)

        scene.handleTouchForTesting(at: layout.cityProgressFrame.center)

        #expect(scene.lastPresentedTooltipTextForTesting.contains(scene.gameStateForTesting.displayCityTitle))
        #expect(scene.lastPresentedTooltipTextForTesting.contains("HP "))
    }

    @Test func combatUsesCurrentCityLaneDefenseMultipliers() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 30, cityRemainingPower: 20))
        let scene = makeScene(store: store)

        // City 1: left fortified (1.25), center standard (1.0), right exposed (0.80).
        let multipliers = scene.combatLaneDamageMultipliersForTesting
        #expect(multipliers[.left] == 1.25)
        #expect(multipliers[.center] == 1.0)
        #expect(multipliers[.right] == 0.80)
    }

    @Test func battleSceneKeepsSoldierHUDValueWithoutTitle() throws {
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 20))
        let scene = makeScene(store: store)

        #expect(scene.liveCombatStatusTextForTesting == "0")

        scene.spawnSoldierForTesting()

        #expect(scene.liveCombatStatusTextForTesting == "1")
        #expect(scene.liveSoldierCountForTesting == 1)
    }

    @Test("Battle reserves the left HUD status column for Settings without shrinking resource values")
    func battleHUDReservesSettingsSpaceAcrossPhoneFixtures() throws {
        for size in [CGSize(width: 393, height: 852), CGSize(width: 393, height: 700)] {
            let store = try makeStore(initialState: stateWithBarracks(gold: 123_456_789, cityRemainingPower: 20))
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
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 20))
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

        #expect(BattleScene.feedbackSettingsAccessibilityFrame(
            viewLocalFrame: viewLocalFrame,
            screenFrame: invalidScreenFrame
        ) == viewLocalFrame)
        #expect(BattleScene.feedbackSettingsAccessibilityFrame(
            viewLocalFrame: viewLocalFrame,
            screenFrame: validScreenFrame
        ) == validScreenFrame)
    }

    @Test("Battle Settings activateFeedbackSettings with consumed does nothing when settings are visible")
    func battleSettingsActivateFeedbackSettingsConsumedDoesNothing() throws {
        let preferences = RecordingFeedbackPreferencesManager()
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 100))
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
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 100))
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
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 500))
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
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 100))
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
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 1))
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
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 20))
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
            cityRemainingPower: 100,
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
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 100))
        let scene = makeScene(store: store, feedback: feedback)

        for _ in 0..<KingdomGameState.manualSoldierCap {
            scene.spawnSoldierForTesting()
        }
        feedback.reset()

        scene.spawnSoldierForTesting()

        #expect(scene.manualLiveSoldierCountForTesting == KingdomGameState.manualSoldierCap)
        #expect(feedback.calls == [.discrete(.invalidAction)])
    }

    @Test("Battle submits one automatic feedback batch for every combat tick")
    func battleSubmitsOneAutomaticFeedbackBatchPerTickResult() throws {
        let feedback = BattleFeedbackRecorder()
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 500))
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
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 1))
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
            initialState: stateWithBarracks(gold: initialGold, cityRemainingPower: 1)
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
        let store = try makeStore(initialState: KingdomGameState(
            cityLevel: 15,
            cityRemainingPower: 1,
            cityNumberInCountry: 15,
            completedCityCount: 14,
            cityBattleStates: [
                cityKey.storageKey: CityBattleState(
                    // A level-6 infantry survives City 15's first fortified
                    // tower shot long enough to produce the live conquest.
                    slots: [1: CityBuilding(type: .barracks, level: 6)]
                )
            ]
        ))
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
            store: try makeStore(initialState: stateWithBarracks(cityRemainingPower: 1)),
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
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 20))
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()

        #expect(scene.liveSoldierCountForTesting == 1)
        #expect(scene.cityRemainingPowerForTesting == 20)
        #expect(store.load().cityRemainingPower == 20)
    }

    @Test func infantrySoldierVisualMatchesAssetName() throws {
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 20))
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()

        #expect(scene.firstLiveSoldierVisualMatchesForTesting(.infantry))
    }

    @Test func mismatchedSoldierTypeFallsBackToColorComparison() throws {
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 20))
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()

        // Infantry soldier body does not match archer asset name, so it falls back to color comparison
        #expect(!scene.firstLiveSoldierVisualMatchesForTesting(.archer))
    }

    @Test func cavalrySoldierVisualMatches() throws {
        let state = stateWithBuildings([.stable], cityRemainingPower: 20)
        let store = try makeStore(initialState: state)
        let scene = makeScene(store: store)

        scene.selectManualSoldierTypeForTesting(.cavalry)
        scene.spawnSoldierForTesting()

        #expect(scene.firstLiveSoldierVisualMatchesForTesting(.cavalry))
    }

    @Test func allSoldierTypesExposeTenAnimationFramesForEachAction() throws {
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 20))
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
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 50))
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
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 50))
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
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 50))
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 3.0)

        #expect(scene.soldierAttackAnimationTriggerCountForTesting > 0)
    }

    @Test("Attack triggers while an attack cycle is in flight are ignored, not restarted")
    func attackTriggerWhileAttackInFlightIsIgnored() throws {
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 50))
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
            let store = try makeStore(initialState: stateWithBuildings([buildingType], cityRemainingPower: 500))
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
        let store = try makeStore(initialState: stateWithBuildings([.archeryRange], cityRemainingPower: 500))
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
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 500))
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
        let store = try makeStore(initialState: stateWithBuildings([.stable], cityRemainingPower: 500))
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
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 50))
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
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 50))
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
            initialState: stateWithBarracks(
                cityRemainingPower: 100,
                cityNumberInCountry: 9,
                completedCityCount: 8
            )
        )
        let scene = makeScene(store: store, combatSeed: 1)

        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 1.2)

        #expect(scene.soldierHitAnimationTriggerCountForTesting > 0)
    }

    @Test func towerDamageUsesAuthoredArcherHitWithoutProceduralOverlay() throws {
        let store = try makeStore(
            initialState: stateWithBuildings(
                [.archeryRange],
                cityRemainingPower: 100,
                cityNumberInCountry: 9,
                completedCityCount: 8
            )
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
            initialState: stateWithBarracks(
                cityRemainingPower: 100,
                cityNumberInCountry: 9,
                completedCityCount: 8
            )
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
                cityRemainingPower: 100,
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
                    cityRemainingPower: 100,
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
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 50))
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
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 50))
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
        let store = try makeStore(initialState: stateWithBuildings([.stable], cityRemainingPower: 50))
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
            let store = try makeStore(initialState: stateWithBuildings([buildingType], cityRemainingPower: 50))
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
        // accessor return nil.) `cityRemainingPower: 500` keeps the city alive
        // across the full 0.9s window so `stageStatus` stays `.battleActive`.
        let store = try makeStore(
            initialState: stateWithBuildings(
                [.stable],
                gold: 100,
                cityRemainingPower: 500,
                cityNumberInCountry: 1,
                completedCityCount: 0
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
        // 9 hits). cityRemainingPower 500 keeps the city alive across the
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
                cityRemainingPower: 500,
                cityNumberInCountry: 1,
                completedCityCount: 0
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
        let cityPowerAtHit = scene.cityRemainingPowerForTesting
        for _ in 0..<15 {
            scene.advanceCombatForTesting(deltaTime: 0.1)
        }
        #expect(scene.soldierAttackAnimationTriggerCountForTesting == attackCountAtHit,
                "Combat-tick attack triggers during sustained hit reactions must be suppressed")
        #expect(scene.cityRemainingPowerForTesting < cityPowerAtHit,
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
                cityRemainingPower: 500,
                cityNumberInCountry: 1,
                completedCityCount: 0
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
        // slots and row offsets grow without bound. Without a clamp, enough
        // same-lane soldiers at the attack position would push back rows below
        // the battlefield frame, where they keep dealing combat damage with
        // invisible bodies and HP bars. `syncSoldierNodes` clamps each root's
        // y to `battlefieldLayout.frame.minY` so overflow soldiers stack at the
        // bottom edge instead of disappearing.
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
        let store = try makeStore(
            initialState: stateWithBuildings(
                buildingTypes,
                gold: 100,
                cityRemainingPower: 1_000_000,
                cityNumberInCountry: 1,
                completedCityCount: 0
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
        for placement in placements {
            #expect(placement.nodePosition.y >= floorY,
                    "Soldier y (\(placement.nodePosition.y)) below floor (\(floorY)), lane \(placement.lane)")
        }
    }

    @Test("Soldier animation textures are memoized across calls (no per-call UIImage lookup)")
    func soldierAnimationTexturesAreCachedAndReusedAcrossCalls() throws {
        let store = try makeStore(initialState: stateWithBuildings([.mageTower], cityRemainingPower: 20))
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
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 20))
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
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 20))
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
        let store = try makeStore(initialState: stateWithBuildings([.archeryRange], cityRemainingPower: 50))
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
        let store = try makeStore(initialState: stateWithBuildings([.archeryRange], cityRemainingPower: 50))
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
        let store = try makeStore(initialState: stateWithBuildings([.archeryRange], cityRemainingPower: 50))
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
        let store = try makeStore(initialState: stateWithBuildings([.archeryRange], cityRemainingPower: 50))
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

    @Test("Every authored soldier animation frame is installed in the asset catalog")
    func allSoldierAnimationFramesAreInstalled() throws {
        // Closes the lazy-detection hole left after SoldierAnimationManifest was
        // removed: a missing or misnamed frame (e.g. `cavalry-walk-07`) would
        // otherwise only surface at runtime via the silent no-op in
        // `playSoldierAnimation`. Iterating every (type, action, frame) trio
        // synchronously here turns an asset-catalog regression into a test
        // failure on every run, before it can reach a simulator.
        for soldierType in SoldierType.allCases {
            for action in SoldierAnimationAction.allCases {
                for frameIndex in 1...SoldierAnimationTiming.frameCount {
                    let name = "\(soldierType.rawValue)-\(action.rawValue)-\(String(format: "%02d", frameIndex))"
                    #expect(
                        UIImage(named: name) != nil,
                        "Missing soldier animation frame: \(name)"
                    )
                }
            }
        }
    }

    @Test("A tower-killed soldier is routed through the delayed-removal scheduler")
    func towerKilledSoldierSchedulesDelayedRemoval() throws {
        // City 9 with maxed-out city power so a tower shot is lethal. The combat
        // seed is fixed so the tower targets the spawned soldier's lane.
        let store = try makeStore(
            initialState: stateWithBarracks(
                cityRemainingPower: 100,
                cityNumberInCountry: 9,
                completedCityCount: 8
            )
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
            cityRemainingPower: 20,
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
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 100))
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

        for _ in 0..<KingdomGameState.manualSoldierCap {
            scene.spawnSoldierForTesting()
        }

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
                cityRemainingPower: 100,
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
                cityRemainingPower: 100,
                cityNumberInCountry: 11,
                completedCityCount: 10
            )
        )
        let scene = makeScene(store: store)

        #expect(scene.defenseTraitTextForTesting?.contains("Reinforced Keep") == true)
        #expect(scene.isUpgradeButtonVisibleForTesting == false)
    }

    @Test func manualSpawnAlwaysAllowsInfantryWithoutBuilding() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100, cityRemainingPower: 100))
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
            cityRemainingPower: 100,
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
        let cityKey = CityKey(countryNumber: 1, cityNumber: 11)
        let cityState = CityBattleState(
            slots: [
                1: CityBuilding(type: .siegeWorkshop, level: 1),
                2: CityBuilding(type: .siegeWorkshop, level: 3)
            ]
        )
        let store = try makeStore(
            initialState: KingdomGameState(
                gold: 200,
                cityRemainingPower: 100,
                cityNumberInCountry: 11,
                completedCityCount: 10,
                cityBattleStates: [cityKey.storageKey: cityState]
            )
        )
        let scene = makeScene(store: store)

        let initialCityHP = 100
        let expectedAttackPower = KingdomGameState.traitAdjustedSoldierAttackPower(
            for: .siege,
            level: 3,
            defenseTrait: .reinforcedKeep
        )

        scene.selectManualSoldierTypeForTesting(.siege)
        for _ in 0..<4 {
            scene.spawnSoldierForTesting()
        }

        #expect(scene.liveSoldierLevelsForTesting == Array(repeating: 3, count: 4))
        #expect(scene.liveSoldierAttackPowersForTesting == Array(repeating: expectedAttackPower, count: 4))

        scene.advanceCombatForTesting(deltaTime: 4.0)

        #expect(store.load().cityRemainingPower < initialCityHP)
    }

    @Test func buildingSpawnUsesTraitAdjustedAttackPower() throws {
        let cityKey = CityKey(countryNumber: 1, cityNumber: 11)
        let interval = KingdomGameState.activeSpawnInterval(for: .siegeWorkshop)
        let cityState = CityBattleState(
            slots: [1: CityBuilding(type: .siegeWorkshop, level: 3, spawnTimerElapsed: interval - 0.1)]
        )
        let store = try makeStore(
            initialState: KingdomGameState(
                gold: 200,
                cityRemainingPower: 100,
                cityNumberInCountry: 11,
                completedCityCount: 10,
                cityBattleStates: [cityKey.storageKey: cityState]
            )
        )
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

    @Test func buildingProgressSaveFlushesImmediatelyWhenSpawnFires() throws {
        let cityKey = CityKey(countryNumber: 1, cityNumber: 1)
        let interval = KingdomGameState.activeSpawnInterval(for: .barracks)
        let cityState = CityBattleState(
            slots: [1: CityBuilding(type: .barracks, spawnTimerElapsed: interval - 0.1)]
        )
        let store = try makeStore(
            initialState: KingdomGameState(
                cityRemainingPower: 100,
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
        let store = try makeStore(initialState: stateWithBuildings([.mageTower], cityRemainingPower: 20))
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
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 20))
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 3.0)

        #expect(scene.liveSoldierCountForTesting == 1)
        #expect(store.load().cityRemainingPower < 20)
    }

    @Test func cityDamageCreatesFloatingFeedbackNode() throws {
        let store = try makeStore(
            initialState: stateWithBarracks(
                cityRemainingPower: 50,
                cityNumberInCountry: 3,
                completedCityCount: 2
            )
        )
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 3.0)

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

    @Test func cityDamageDoesNotCreateScalingImpactEffect() throws {
        let store = try makeStore(
            initialState: stateWithBarracks(
                cityRemainingPower: 50,
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
                cityRemainingPower: 50,
                completedCityCount: 0
            )
        )
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()
        let layoutCountBeforeDamage = scene.battlefieldLayoutCountForTesting

        scene.advanceCombatForTesting(deltaTime: 3.0)

        #expect(scene.cityRemainingPowerForTesting < 50)
        #expect(scene.battlefieldLayoutCountForTesting == layoutCountBeforeDamage)
    }

    @Test func infantrySelectorDoesNotRelayoutBattlefieldBackdrop() throws {
        let store = try makeStore(
            initialState: stateWithBarracks(
                cityRemainingPower: 50,
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
            initialState: stateWithBarracks(
                cityRemainingPower: 100,
                cityNumberInCountry: 9,
                completedCityCount: 8
            )
        )
        let scene = makeScene(store: store, combatSeed: 1)

        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 18.0)

        let savedState = store.load()
        #expect(scene.liveSoldierCountForTesting == 0)
        #expect(!scene.isConquestPopupVisibleForTesting)
        #expect(savedState.stageStatus == .battleActive)
        #expect(savedState.cityRemainingPower == 100)
        #expect(savedState.activeSiegeSession?.losses.contains {
            $0.type == .infantry && $0.source == .manual && $0.count == 1
        } == true)
    }

    @Test func liveCombatStatusUpdatesWhenTowerKillsLastSoldierWithoutCityDamage() throws {
        let store = try makeStore(
            initialState: stateWithBarracks(
                cityRemainingPower: 20,
                cityNumberInCountry: 9,
                completedCityCount: 8
            )
        )
        let scene = makeScene(store: store, combatSeed: 1)

        scene.spawnSoldierForTesting()

        #expect(scene.liveCombatStatusTextForTesting == "1")

        scene.advanceCombatForTesting(deltaTime: 1.2)

        #expect(scene.liveSoldierCountForTesting == 0)
        #expect(scene.cityRemainingPowerForTesting == 20)
        #expect(store.load().cityRemainingPower == 20)
        #expect(scene.liveCombatStatusTextForTesting == "0")
    }

    @Test func lossOnlyTickReenablesGameplayTabsAfterFinalManualSoldierDeath() throws {
        let store = try makeStore(
            initialState: stateWithBarracks(
                cityRemainingPower: 20,
                cityNumberInCountry: 9,
                completedCityCount: 8
            )
        )
        let scene = makeScene(store: store, combatSeed: 1)

        scene.spawnSoldierForTesting()
        #expect(scene.battleHUDContentForTesting.enabledTabs == [.battle])
        #expect(scene.battleHUDTabBarForTesting.hitFrameForTesting(for: .camp) == nil)
        #expect(scene.battleHUDTabBarForTesting.hitFrameForTesting(for: .map) == nil)

        scene.advanceCombatForTesting(deltaTime: 1.2)

        #expect(scene.liveSoldierCountForTesting == 0)
        #expect(scene.cityRemainingPowerForTesting == 20)
        #expect(scene.battleHUDContentForTesting.enabledTabs == Set(GameplayTab.allCases))
        #expect(scene.battleHUDTabBarForTesting.hitFrameForTesting(for: .camp) != nil)
        #expect(scene.battleHUDTabBarForTesting.hitFrameForTesting(for: .map) != nil)
    }

    @Test func liveCombatConquestClearsSoldiersAndShowsPopup() throws {
        let initialGold = 100
        let store = try makeStore(
            initialState: stateWithBarracks(
                gold: initialGold,
                cityRemainingPower: 1,
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
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 100))
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
            initialState: KingdomGameState(
                gold: 100,
                cityRemainingPower: 100,
                cityNumberInCountry: 9,
                completedCityCount: 8
            )
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
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 100))
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
                cityRemainingPower: 1,
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
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 20))
        let scene = makeScene(store: store)
        #expect(!scene.firstLiveSoldierVisualMatchesForTesting(.infantry))
    }

    @Test func goldBurstZPositionFallsBackWhenAbsent() throws {
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 20))
        let scene = makeScene(store: store)
        #expect(scene.goldBurstZPositionForTesting < 0)
    }

    @Test func conquestPopupUsesRewardPresentationNodes() throws {
        let store = try makeStore(
            initialState: stateWithBarracks(
                cityRemainingPower: 1,
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
                cityRemainingPower: 1,
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
        let store = try makeStore(initialState: KingdomGameState(gold: 100, cityRemainingPower: 20))
        let router = BattleRouterSpy()
        let scene = makeScene(store: store, router: router)

        scene.requestGameplayTabForTesting(.camp)

        #expect(router.didRequestBuildingView)
    }

    @Test func mapTabRequestsCountryMapRoute() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100, cityRemainingPower: 20))
        let router = BattleRouterSpy()
        let scene = makeScene(store: store, router: router)

        scene.requestGameplayTabForTesting(.map)

        #expect(router.didRequestCountryMap)
    }

    @Test func campTabWaitsForLiveSoldiersBeforeRouting() throws {
        let start = Date(timeIntervalSinceReferenceDate: 500)
        var initialState = KingdomGameState(gold: 100, cityRemainingPower: 20)
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
                cityRemainingPower: 100,
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
        var initialState = KingdomGameState(gold: 100, cityRemainingPower: 1, lastBackgroundedAt: start)
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
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 1))
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
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 1))
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
        let store = try makeStore(initialState: idleConquestReadyState())
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

    @Test("Fresh City 5 flourish uses the applied result once")
    func freshCity5ConquestPresentsMilestoneFlourishOnce() throws {
        let key = CityKey(countryNumber: 1, cityNumber: 5)
        let state = KingdomGameState(
            gold: 100,
            cityLevel: 5,
            cityRemainingPower: 1,
            cityNumberInCountry: 5,
            completedCityCount: 4,
            cityBattleStates: [
                key.storageKey: CityBattleState(
                    slots: [1: CityBuilding(type: .barracks, level: 6)]
                )
            ]
        )
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
        let store = try makeStore(initialState: KingdomGameState(gold: 30, cityRemainingPower: 20))
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
        let store = try makeStore(initialState: stateWithBarracks(gold: 30, cityRemainingPower: 20))
        let scene = makeScene(store: store)

        let texts = visibleLabelTexts(in: scene)
        #expect(!texts.contains { $0.hasPrefix("Gold:") })
        #expect(!texts.contains { $0.hasPrefix("Soldiers:") })
        #expect(!texts.contains { $0.hasPrefix("HP:") })
        #expect(texts.contains("30"))
        #expect(texts.contains("0/10"))
        #expect(texts.contains("1 / 15"))
        #expect(texts.contains("WILLOWFORD"))
        #expect(texts.contains("DEPLOY"))
        #expect(SoldierType.allCases.reduce(0) { count, soldierType in
            count + visibleSpriteCount(
                in: scene,
                named: "battleMedallionIcon-\(soldierType.rawValue)"
            )
        } == 5)
    }

    @Test func commonActionButtonsUseCompactIconShapes() throws {
        let store = try makeStore(initialState: stateWithBarracks(gold: 30, cityRemainingPower: 20))
        let scene = makeScene(store: store)
        let layout = try #require(scene.battleChromeLayoutForTesting)

        #expect(layout.deployFrame.width == layout.tabBarFrame.width)
        #expect(layout.tabHitFrames.count == GameplayTab.allCases.count)
        #expect(layout.tabHitFrames.allSatisfy { $0.height >= 44 })
    }

    @Test func infantryAndSpawnButtonsAreCompactAndLeftAligned() throws {
        let store = try makeStore(initialState: stateWithBarracks(gold: 30, cityRemainingPower: 20))
        let scene = makeScene(store: store)
        let layout = try #require(scene.battleChromeLayoutForTesting)

        #expect(layout.medallionFrames.first?.width == BattleChromeLayout.medallionVisualSize)
        #expect(layout.deployFrame.width == layout.tabBarFrame.width)
        #expect(layout.manualCountFrame.maxX <= layout.deployFrame.maxX)
    }

    @Test func buttonIconsAreLargeEnoughToRead() throws {
        let store = try makeStore(initialState: stateWithBarracks(gold: 30, cityRemainingPower: 20))
        let scene = makeScene(store: store)

        let layout = try #require(scene.battleChromeLayoutForTesting)
        #expect(scene.battleHUDForTesting.visualMedallionCountForTesting == 5)
        #expect(layout.medallionFrames.allSatisfy { $0.width == BattleChromeLayout.medallionVisualSize })
    }

    @Test func battleHUDMedallionIconsUseAuthoredUnitArt() throws {
        let store = try makeStore(initialState: stateWithBarracks(gold: 30, cityRemainingPower: 20))
        let scene = makeScene(store: store)

        for soldierType in SoldierType.allCases {
            #expect(visibleSpriteCount(
                in: scene,
                named: "battleMedallionIcon-\(soldierType.rawValue)"
            ) == 1)
        }
    }

    @Test func buttonIconsStayInsideTheirPaintedButtonBackgrounds() throws {
        let store = try makeStore(initialState: stateWithBarracks(gold: 30, cityRemainingPower: 20))
        let scene = makeScene(store: store)
        let layout = try #require(scene.battleChromeLayoutForTesting)
        let hud = scene.battleHUDForTesting

        #expect(layout.medallionFrames.allSatisfy { layout.safeFrame.contains($0) })
        #expect(layout.deployFrame.contains(layout.manualCountFrame))
        #expect(hud.currentLayoutForTesting == layout)
    }

    @Test func commanderHUDSurvivesCompactLandscapeWithoutOverlap() throws {
        let size = CGSize(width: 667, height: 375)
        let store = try makeStore(initialState: KingdomGameState(gold: 30, cityRemainingPower: 20))
        let scene = BattleScene(size: size, store: store, router: nil)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        scene.didMove(to: view)

        #expect(scene.battleChromeLayoutForTesting == nil)
        #expect(scene.isBattleChromeFitFailedForTesting)
    }

    @Test func battleChromeAvoidsFeedbackAndBattlefieldOverlapInCompactAndNarrowLayouts() throws {
        for size in [CGSize(width: 393, height: 700)] {
            let store = try makeStore(initialState: stateWithBarracks(gold: 30, cityRemainingPower: 20))
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
                cityRemainingPower: 100,
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
        let store = try makeStore(initialState: stateWithBarracks(gold: 30, cityRemainingPower: 20))
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
        let store = try makeStore(initialState: stateWithBarracks(gold: 30, cityRemainingPower: 20))
        let scene = BattleScene(size: size, store: store, router: nil)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        scene.didMove(to: view)

        let layout = try #require(scene.battleChromeLayoutForTesting)
        #expect(layout.deployFrame.width >= 340)
        #expect(layout.tabHitFrames.count == 3)
    }

    @Test func commanderHUDFitsLateGameNumbersInNarrowViewport() throws {
        let size = CGSize(width: 393, height: 700)
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

        let layout = try #require(scene.battleChromeLayoutForTesting)
        #expect(layout.topBandFrame.maxX <= size.width)
        #expect(layout.settingsFrame.width == 44)
        #expect(layout.battlefieldFrame.height >= BattleChromeLayout.compactMinimumBattlefieldHeight)
    }

    @Test func commanderHUDAvoidsTallPhoneSensorArea() throws {
        let size = CGSize(width: 390, height: 844)
        let store = try makeStore(initialState: KingdomGameState(gold: 30, cityRemainingPower: 20))
        let scene = BattleScene(size: size, store: store, router: nil)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        scene.didMove(to: view)

        let layout = try #require(scene.battleChromeLayoutForTesting)

        #expect(layout.topBandFrame.maxY <= size.height)
        #expect(layout.settingsFrame.maxY <= size.height)
        #expect(layout.battlefieldFrame.minY >= 0)
    }

    @Test func verticalBattlefieldPlacesEnemyCityAboveCastle() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 30, cityRemainingPower: 20))
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
        let store = try makeStore(initialState: KingdomGameState(gold: 30, cityRemainingPower: 20))
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
        let store = try makeStore(initialState: KingdomGameState(gold: 30, cityRemainingPower: 20))
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
            initialState: stateWithBarracks(cityRemainingPower: 1, completedCityCount: 0)
        )
        let scene = makeScene(store: store, size: CGSize(width: 393, height: 700))

        scene.spawnSoldierForTesting()
        scene.spawnSoldierForTesting()
        scene.spawnSoldierForTesting()

        scene.advanceCombatForTesting(deltaTime: 3.0)

        // Regression for the zero-power sliver: previously the fill kept a
        // 1px-wide path (`max(1, width * 0)`) and rendered a tiny green line
        // after the city was drained. The fix nils the path at power==0.
        #expect(scene.cityRemainingPowerForTesting == 0)
        #expect(scene.isCityHPBarFillHiddenForTesting)
    }

    @Test func redrawWithLayoutRunsCityHPBarLayoutExactlyOnce() throws {
        // Regression: `redraw(shouldLayout: true)` called `layoutCityHPBar()`
        // directly and then again via `layoutInterface()`, building CGPaths on
        // the first pass that were immediately discarded by the second. The fix
        // defers to `layoutInterface()` when `shouldLayout` is true.
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 20))
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
        let store = try makeStore(initialState: stateWithBarracks(gold: 30, cityRemainingPower: 20))
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
        let store = try makeStore(initialState: stateWithBarracks(gold: 30, cityRemainingPower: 20))
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
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 2000))
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
        let store = try makeStore(initialState: KingdomGameState(gold: 30, cityRemainingPower: 20))
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
        let store = try makeStore(initialState: KingdomGameState(gold: 30, cityRemainingPower: 20))
        let scene = makeScene(store: store)

        #expect(visibleNodeCount(in: scene, namePrefix: "battleLaneTerrain-") == 3)
        #expect(visibleNodeCount(in: scene, namePrefix: "battleLaneDetail-") >= 12)
    }

    @Test func laneTerrainBlendsIntoBackdropInsteadOfCoveringIt() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 30, cityRemainingPower: 20))
        let scene = makeScene(store: store)

        let alphas = visibleShapeAlphas(in: scene, namePrefix: "battleLaneTerrain-")
        #expect(alphas.count == 3)
        for alpha in alphas {
            #expect(alpha.fill <= 0.18)
            #expect(alpha.stroke <= 0.28)
        }
    }

    @Test func soldierNodesRenderAtTheirLaneColumn() throws {
        let store = try makeStore(initialState: stateWithBarracks(gold: 100, cityRemainingPower: 1_000))
        let scene = makeScene(store: store)

        for _ in 0..<6 {
            scene.spawnSoldierForTesting()
        }

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

    @Test func soldiersSharingALaneDoNotRenderAtTheSamePoint() throws {
        let store = try makeStore(initialState: stateWithBarracks(gold: 100, cityRemainingPower: 1_000))
        let scene = makeScene(store: store)

        for _ in 0..<6 {
            scene.spawnSoldierForTesting()
        }

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
            initialState: stateWithBuildings([.mageTower], gold: 100, cityRemainingPower: 1_000)
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
            initialState: stateWithBuildings([.siegeWorkshop], gold: 100, cityRemainingPower: 1_000)
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
        let store = try makeStore(initialState: KingdomGameState(gold: 30, cityRemainingPower: 20))
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
        let store = try makeStore(initialState: KingdomGameState(gold: 30, cityRemainingPower: 20))
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
        let store = try makeStore(initialState: KingdomGameState(gold: 30, cityRemainingPower: 20))
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
        let store = try makeStore(initialState: KingdomGameState(gold: 30, cityRemainingPower: 20))
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
        cityRemainingPower: Int = 20,
        cityNumberInCountry: Int = 1,
        completedCityCount: Int = 0
    ) -> KingdomGameState {
        stateWithBuildings(
            [.barracks],
            gold: gold,
            cityRemainingPower: cityRemainingPower,
            cityNumberInCountry: cityNumberInCountry,
            completedCityCount: completedCityCount
        )
    }

    private func stateWithBuildings(
        _ buildingTypes: [BuildingType],
        gold: Int = 100,
        cityRemainingPower: Int = 20,
        cityNumberInCountry: Int = 1,
        completedCityCount: Int = 0
    ) -> KingdomGameState {
        let cityKey = CityKey(countryNumber: 1, cityNumber: cityNumberInCountry)
        let slots = Dictionary(
            uniqueKeysWithValues: buildingTypes.enumerated().map { index, buildingType in
                (index + 1, CityBuilding(type: buildingType))
            }
        )
        return KingdomGameState(
            gold: gold,
            cityRemainingPower: cityRemainingPower,
            cityNumberInCountry: cityNumberInCountry,
            completedCityCount: completedCityCount,
            cityBattleStates: [cityKey.storageKey: CityBattleState(slots: slots)]
        )
    }

    private func idleConquestReadyState() -> KingdomGameState {
        let backgroundAt = Date(timeIntervalSince1970: 1_000)
        var state = KingdomGameState(gold: 100, cityRemainingPower: 1)
        _ = state.buildBuilding(.barracks, inSlot: 1, at: backgroundAt)
        return state
    }

    private func pendingResult(
        city: Int,
        mode: BattleConquestMode = .live,
        activeBattleSeconds: TimeInterval = 65,
        usedFavorableUnit: Bool = false,
        usedExposedLane: Bool = false
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
            goldEarned: 8
        )
    }

    private func pendingConqueredState(
        city: Int = 1,
        mode: BattleConquestMode = .live,
        countryComplete: Bool = false,
        usedFavorableUnit: Bool = false,
        usedExposedLane: Bool = false
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
                usedExposedLane: usedExposedLane
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

    private func opaquePixelBounds(in image: UIImage) -> PixelBounds? {
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

        guard didDraw else {
            return nil
        }

        var minX = width
        var maxXExclusive = 0
        for y in 0..<height {
            for x in 0..<width {
                let alphaIndex = (y * width + x) * 4 + 3
                guard pixels[alphaIndex] > 0 else {
                    continue
                }
                minX = min(minX, x)
                maxXExclusive = max(maxXExclusive, x + 1)
            }
        }

        guard minX < width else {
            return nil
        }
        return PixelBounds(minX: minX, maxXExclusive: maxXExclusive)
    }

    // MARK: - touchesEnded

    @Test func touchesEndedEmptyTouchesDoesNothing() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100, cityRemainingPower: 20))
        let router = BattleRouterSpy()
        let scene = makeScene(store: store, router: router)
        let liveCountBefore = scene.liveSoldierCountForTesting

        scene.touchesEnded([], with: nil)

        #expect(scene.liveSoldierCountForTesting == liveCountBefore)
        #expect(!router.didRequestCountryMap)
        #expect(!router.didRequestBuildingView)
    }

    @Test func touchesEndedSpawnButtonSpawnsSoldier() throws {
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 20))
        let scene = makeScene(store: store)
        let layout = try #require(scene.battleChromeLayoutForTesting)
        let point = layout.deployFrame.center

        scene.touchesEnded([MockTouch(location: point)], with: nil)

        #expect(scene.liveSoldierCountForTesting == 1)
    }

    @Test func touchesEndedBuildButtonRequestsBuildingView() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100, cityRemainingPower: 20))
        let router = BattleRouterSpy()
        let scene = makeScene(store: store, router: router)
        let layout = try #require(scene.battleChromeLayoutForTesting)
        let point = layout.tabHitFrames[1].center

        scene.touchesEnded([MockTouch(location: point)], with: nil)

        #expect(router.didRequestBuildingView)
    }

    @Test func touchesEndedWorldButtonRequestsCountryMap() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 100, cityRemainingPower: 20))
        let router = BattleRouterSpy()
        let scene = makeScene(store: store, router: router)
        let layout = try #require(scene.battleChromeLayoutForTesting)
        let point = layout.tabHitFrames[2].center

        scene.touchesEnded([MockTouch(location: point)], with: nil)

        #expect(router.didRequestCountryMap)
    }

    @Test func touchesEndedMapTabUsesAuthoritativeSafeHitFrame() throws {
        let size = CGSize(width: 393, height: 852)
        let store = try makeStore(initialState: KingdomGameState(gold: 100, cityRemainingPower: 20))
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
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 1, completedCityCount: 0))
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
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 20))
        let router = BattleRouterSpy()
        let scene = makeScene(store: store, router: router)
        scene.spawnSoldierForTesting()

        scene.requestGameplayTabForTesting(.map)

        #expect(!router.didRequestCountryMap)
        #expect(scene.feedbackTextForTesting == "Finish the current squad before viewing world.")
    }

    @Test func requestCountryMapBlocksWhenConquestPopupVisible() throws {
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 1, completedCityCount: 0))
        let router = BattleRouterSpy()
        let scene = makeScene(store: store, router: router)
        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 3.0)
        #expect(scene.isConquestPopupVisibleForTesting)

        scene.requestGameplayTabForTesting(.map)

        #expect(!router.didRequestCountryMap)
    }

    @Test func gameplayTabsDisableCampAndMapWhenManualSoldierLives() throws {
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 20))
        let scene = makeScene(store: store)

        #expect(scene.battleHUDContentForTesting.enabledTabs == Set(GameplayTab.allCases))
        #expect(scene.battleHUDTabBarForTesting.visualCellCountForTesting == 3)
        #expect(scene.battleHUDTabBarForTesting.hitFrameForTesting(for: .camp) != nil)
        #expect(scene.battleHUDTabBarForTesting.hitFrameForTesting(for: .map) != nil)

        scene.spawnSoldierForTesting()

        #expect(scene.battleHUDContentForTesting.enabledTabs == [.battle])
        #expect(scene.battleHUDTabBarForTesting.visualCellCountForTesting == 3)
        #expect(scene.battleHUDTabBarForTesting.hitFrameForTesting(for: .camp) == nil)
        #expect(scene.battleHUDTabBarForTesting.hitFrameForTesting(for: .map) == nil)
    }

    @Test func directGameplayTabRouteKeepsManualSquadGuardFeedback() throws {
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 20))
        let router = BattleRouterSpy()
        let scene = makeScene(store: store, router: router)
        scene.spawnSoldierForTesting()

        scene.requestGameplayTabForTesting(.camp)

        #expect(!router.requestedTabs.contains(.camp))
        #expect(scene.feedbackTextForTesting == "Finish the current squad before building.")
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
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 20))
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
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 20))
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
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 500))
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
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 500))
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
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 20))
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

        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 20))
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

        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 20))
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
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 20))
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
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 20))
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
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 20))
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
        let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 20))
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
