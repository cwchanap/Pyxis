import Foundation
import SpriteKit
import Testing
import UIKit
@testable import Pyxis

@MainActor
struct GameViewControllerTests {
    @Test func controllerOrientationPolicyMatchesApprovedMatrix() {
        #expect(GameViewController.interfaceOrientations(for: .phone) == .portrait)
        #expect(GameViewController.interfaceOrientations(for: .pad)
            == [.portrait, .portraitUpsideDown])
        #expect(GameViewController.interfaceOrientations(for: .unspecified) == .portrait)
        #expect(GameViewController().preferredInterfaceOrientationForPresentation == .portrait)
    }

    @Test func generatedInfoPlistMatchesApprovedOrientationMatrix() throws {
        let appBundle = try #require(Bundle.allBundles.first {
            $0.bundleIdentifier == "cwchanap.Pyxis"
        })
        let infoURL = try #require(
            appBundle.url(forResource: "Info", withExtension: "plist")
        )
        let infoData = try Data(contentsOf: infoURL)
        let info = try #require(
            try PropertyListSerialization.propertyList(
                from: infoData,
                format: nil
            ) as? [String: Any]
        )
        let phone = Set(try #require(
            info["UISupportedInterfaceOrientations~iphone"] as? [String]
        ))
        let pad = Set(try #require(
            info["UISupportedInterfaceOrientations~ipad"] as? [String]
        ))

        #expect(phone == ["UIInterfaceOrientationPortrait"])
        #expect(pad == [
            "UIInterfaceOrientationPortrait",
            "UIInterfaceOrientationPortraitUpsideDown"
        ])
    }

    @Test func unsupportedGeometryPausesAndBlocksThenResumesWithoutBattleStateMutation() throws {
        let initialState = KingdomGameState(gold: 37)
        let store = try makeStore(initialState: initialState)
        let controller = makeGameViewController(store: store)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        controller.view = view
        controller.viewDidLoad()

        controller.refreshLayoutSupportForTesting(environment: .init(
            safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0),
            layoutClass: .phone
        ))
        #expect(!controller.isLayoutGateVisibleForTesting)
        #expect(!view.isPaused)

        view.frame.size = CGSize(width: 667, height: 375)
        controller.refreshLayoutSupportForTesting(environment: .init(
            safeAreaInsets: .zero,
            layoutClass: .phone
        ))
        #expect(controller.layoutGateReasonForTesting == .unsupportedGeometry)
        #expect(controller.layoutGateTextForTesting
            == "Pyxis needs a supported portrait window. Rotate or resize to continue.")
        #expect(view.isPaused)
        #expect(view.scene?.isUserInteractionEnabled == false)
        #expect(store.load() == initialState)

        view.frame.size = CGSize(width: 393, height: 852)
        controller.refreshLayoutSupportForTesting(environment: .init(
            safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0),
            layoutClass: .phone
        ))
        #expect(!controller.isLayoutGateVisibleForTesting)
        #expect(!view.isPaused)
        #expect(view.scene?.isUserInteractionEnabled == true)
        #expect(store.load() == initialState)
    }

    @Test func normallyMountedBuildingViewUsesTheAppWideGate() throws {
        let store = try makeStore(initialState: .init(stageStatus: .battleActive))
        let controller = makeGameViewController(store: store)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        controller.view = view
        controller.viewDidLoad()
        let battle = try #require(view.scene as? BattleScene)
        controller.battleSceneDidRequestBuildingView(battle)
        #expect(view.scene is BuildingViewScene)

        view.frame.size = CGSize(width: 678, height: 834)
        controller.refreshLayoutSupportForTesting(environment: .init(
            safeAreaInsets: .init(top: 24, left: 0, bottom: 20, right: 0),
            layoutClass: .pad
        ))

        #expect(controller.layoutGateReasonForTesting == .unsupportedGeometry)
        #expect(view.isPaused)
        #expect(view.scene?.isUserInteractionEnabled == false)
    }

    @Test func controllerPreparesAndBindsItsSharedFeedbackRuntimeAfterSKViewExists() throws {
        let store = try makeStore(initialState: .init(stageStatus: .battleActive))
        let context = GameViewControllerRuntimeTestContext()
        let controller = GameViewController(
            store: store,
            feedbackRuntime: context.runtime
        )
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        controller.view = view
        controller.viewDidLoad()

        #expect(context.sound.calls == [.prepareIfNeeded])
        #expect(context.accessibilityAdapterFactoryCallCount == 1)
        #expect(context.runtime.accessibilityAdapter === context.accessibilityAdapter)
        #expect(view.scene is BattleScene)
    }

    @Test func controllerInjectsOneRuntimeIntoBattleMapAndBuildingScenes() throws {
        let store = try makeStore(initialState: .init(stageStatus: .battleActive))
        let context = GameViewControllerRuntimeTestContext()
        let controller = GameViewController(
            store: store,
            feedbackRuntime: context.runtime
        )
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        controller.view = view
        controller.viewDidLoad()

        let battle = try #require(view.scene as? BattleScene)
        battle.didMove(to: view)
        let battleFrameConversions = context.accessibilityFrameConversionCount
        #expect(battleFrameConversions > 0)
        battle.advanceCombatForTesting(deltaTime: 0.1)
        #expect(context.feedback.automaticCombatBatches.count == 1)

        controller.battleSceneDidRequestBuildingView(battle)
        let building = try #require(view.scene as? BuildingViewScene)
        building.didMove(to: view)
        let buildingFrameConversions = context.accessibilityFrameConversionCount
        #expect(buildingFrameConversions > battleFrameConversions)
        building.buildSelectedSlotForTesting(.barracks)
        #expect(context.feedback.events.count == 1)

        controller.buildingViewSceneDidRequestBattle(building)
        let returnedBattle = try #require(view.scene as? BattleScene)
        controller.battleSceneDidRequestCountryMap(returnedBattle)
        let map = try #require(view.scene as? CountryMapScene)
        map.didMove(to: view)
        #expect(context.accessibilityFrameConversionCount > buildingFrameConversions)
        map.enterCityForTesting(3)
        #expect(context.feedback.events.count == 2)
        #expect(context.accessibilityAdapterFactoryCallCount == 1)
    }

    @Test func controllerStopsOnBackgroundAndLightlyPreparesOnForegroundOrInterruption() throws {
        let store = try makeStore(initialState: .init(stageStatus: .battleActive))
        let context = GameViewControllerRuntimeTestContext()
        let controller = GameViewController(
            store: store,
            feedbackRuntime: context.runtime
        )
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        controller.view = view
        controller.viewDidLoad()

        NotificationCenter.default.post(name: .pyxisSceneDidEnterBackground, object: nil)
        #expect(context.sound.calls == [.prepareIfNeeded, .handleAppDidEnterBackground])

        NotificationCenter.default.post(name: .pyxisSceneWillEnterForeground, object: nil)
        #expect(context.sound.calls == [
            .prepareIfNeeded,
            .handleAppDidEnterBackground,
            .handleAppWillEnterForeground
        ])

        context.runtime.handleAudioInterruptionBegan()
        context.runtime.handleAudioInterruptionEnded(shouldResume: true)
        context.runtime.recoverSoundAfterLifecycle()
        #expect(context.sound.calls == [
            .prepareIfNeeded,
            .handleAppDidEnterBackground,
            .handleAppWillEnterForeground,
            .handleAudioInterruptionBegan,
            .handleAudioInterruptionEnded(true),
            .handleLifecycleRecovery
        ])
    }

    @Test func ordinaryForegroundPreservesReadySoundOutputForFreshIdleConquest() throws {
        let start = Date(timeIntervalSinceNow: -1_000)
        var initialState = KingdomGameState(
            gold: 100,
            cityRemainingPower: 1,
            lastBackgroundedAt: start
        )
        #expect(initialState.buildBuilding(.barracks, inSlot: 1, at: start) == .built(
            cost: 15,
            remainingGold: 85
        ))

        let store = try makeStore(initialState: initialState)
        let context = GameViewOutputRuntimeTestContext()
        let controller = GameViewController(
            store: store,
            feedbackRuntime: context.runtime
        )
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        controller.view = view
        controller.viewDidLoad()
        let battle = try #require(view.scene as? BattleScene)
        battle.didMove(to: view)

        NotificationCenter.default.post(name: .pyxisSceneWillEnterForeground, object: nil)

        #expect(context.sound.calls == [
            .prepareIfNeeded,
            .handleAppWillEnterForeground,
            .play(.goldReward, .nonAutomatic),
            .play(.cityConquest, .nonAutomatic)
        ])
        #expect(!context.sound.calls.contains(.handleLifecycleRecovery))
        #expect(store.load().pendingBattleResult?.conquestMode == .idle)
    }

    @Test func layoutGateRecoveryKeepsSettingsOpenAndReappliesTheSharedAdapterWithoutCatchUp() throws {
        let store = try makeStore(initialState: .init(stageStatus: .battleActive))
        let context = GameViewControllerRuntimeTestContext()
        let controller = GameViewController(
            store: store,
            feedbackRuntime: context.runtime
        )
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        controller.view = view
        controller.viewDidLoad()
        let battle = try #require(view.scene as? BattleScene)
        battle.didMove(to: view)

        let gearFrame = try #require(battle.feedbackSettingsGearFrameForTesting)
        battle.handleTouchForTesting(at: CGPoint(x: gearFrame.midX, y: gearFrame.midY))
        #expect(battle.isFeedbackSettingsVisibleForTesting)
        let frameConversionsBeforeGate = context.accessibilityFrameConversionCount

        view.frame.size = CGSize(width: 667, height: 375)
        controller.refreshLayoutSupportForTesting(environment: .init(
            safeAreaInsets: .zero,
            layoutClass: .phone
        ))
        #expect(controller.isLayoutGateVisibleForTesting)
        #expect(view.isPaused)
        #expect(battle.isFeedbackSettingsVisibleForTesting)

        view.frame.size = CGSize(width: 393, height: 852)
        controller.refreshLayoutSupportForTesting(environment: .init(
            safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0),
            layoutClass: .phone
        ))

        #expect(!controller.isLayoutGateVisibleForTesting)
        #expect(!view.isPaused)
        #expect(battle.isFeedbackSettingsVisibleForTesting)
        #expect(context.accessibilityFrameConversionCount > frameConversionsBeforeGate)
        #expect(battle.lastUpdateTimeForTesting == nil)
        #expect(context.feedback.events.isEmpty)
        #expect(context.feedback.automaticCombatBatches.isEmpty)
        #expect(context.sound.calls == [.prepareIfNeeded])
    }

    @Test func controllerKeepsFeedbackPreferencesAcrossSceneReplacement() throws {
        let store = try makeStore(initialState: .init(stageStatus: .battleActive))
        let context = GameViewControllerRuntimeTestContext()
        let controller = GameViewController(
            store: store,
            feedbackRuntime: context.runtime
        )
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        controller.view = view
        controller.viewDidLoad()
        let battle = try #require(view.scene as? BattleScene)
        battle.didMove(to: view)
        let settingsLayout = try #require(FeedbackSettingsLayout.compute(
            sceneSize: battle.size,
            safeAreaInsets: .zero
        ))
        let battleGear = try #require(battle.feedbackSettingsGearFrameForTesting)
        battle.handleTouchForTesting(at: CGPoint(x: battleGear.midX, y: battleGear.midY))
        battle.handleTouchForTesting(at: CGPoint(
            x: settingsLayout.soundRowFrame.midX,
            y: settingsLayout.soundRowFrame.midY
        ))
        #expect(!context.preferences.current.soundEffectsEnabled)
        battle.handleTouchForTesting(at: CGPoint(
            x: settingsLayout.closeFrame.midX,
            y: settingsLayout.closeFrame.midY
        ))

        controller.battleSceneDidRequestBuildingView(battle)
        let building = try #require(view.scene as? BuildingViewScene)
        building.didMove(to: view)
        let buildingGear = try #require(building.feedbackSettingsGearFrameForTesting)
        building.handleTouchForTesting(at: CGPoint(
            x: buildingGear.midX,
            y: buildingGear.midY
        ))
        let soundEffectsElement = try #require(view.accessibilityElements?.first as? UIAccessibilityElement)

        #expect(soundEffectsElement.accessibilityLabel == "Sound Effects")
        #expect(soundEffectsElement.accessibilityValue == "Off")
    }

    @Test func mapUnavailableIsDistinctFromSupportedGeometry() throws {
        let store = try makeStore(initialState: .init(
            cityRemainingPower: 0,
            stageStatus: .cityConqueredPendingMap
        ))
        let controller = makeGameViewController(store: store)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        controller.view = view
        controller.viewDidLoad()
        let map = try #require(view.scene as? CountryMapScene)

        controller.countryMapScene(map, didRequestLayoutGate: .mapUnavailable)

        #expect(controller.layoutGateReasonForTesting == .mapUnavailable)
        #expect(controller.layoutGateTextForTesting == "Map unavailable")
        #expect(view.isPaused)
    }

    @Test func mapUnavailableReasonDoesNotPersistIntoBattleScene() throws {
        let store = try makeStore(initialState: .init(
            cityRemainingPower: 0,
            stageStatus: .cityConqueredPendingMap
        ))
        let controller = makeGameViewController(store: store)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        controller.view = view
        controller.viewDidLoad()
        let map = try #require(view.scene as? CountryMapScene)

        controller.countryMapScene(map, didRequestLayoutGate: .mapUnavailable)
        #expect(controller.layoutGateReasonForTesting == .mapUnavailable)

        // Transitioning to battle must clear the map-scoped reason so the
        // battle scene is not gated as map-unavailable.
        let accepted = controller.countryMapSceneDidRequestBattle(map)

        #expect(accepted)
        #expect(view.scene is BattleScene)
        #expect(controller.layoutGateReasonForTesting == nil)
        #expect(!view.isPaused)
        #expect(view.scene?.isUserInteractionEnabled == true)
    }

    @Test func scoutCardFitFailureMapsToUnsupportedGeometryNotMapUnavailableAndClearsWhenFlagResolves() throws {
        // Verifies the VC's gate-state mapping only: a scout card fit failure
        // must surface as .unsupportedGeometry (NOT .mapUnavailable), and the
        // gate must clear once the scene reports the fit as resolved.
        //
        // The flag is toggled via setScoutCardFitFailedForTesting rather than
        // driven by a real resize because the VC-presented scene has no
        // layoutEnvironmentOverride, so its layoutInterface reads layoutClass
        // from view.traitCollection.userInterfaceIdiom — .phone in the
        // simulator (CI runs on iPhone 17) and .unspecified for a bare headless
        // SKView, never .pad. The .pad scout-card fit failure/recovery on
        // resize is covered end-to-end by
        // CountryMapSceneTests.narrowPadScoutCardFitFailureDoesNotLatchAndRecoversOnWiderResize,
        // which injects a .pad environment override directly into the scene.
        let store = try makeStore(initialState: .init(
            cityRemainingPower: 0,
            cityNumberInCountry: 8,
            completedCityCount: 8,
            stageStatus: .cityConqueredPendingMap
        ))
        let controller = makeGameViewController(store: store)
        // 400x956 .pad: outer layout supported, scout card footer doesn't fit
        // for City 9 (.arcaneWard, 3 favorable types).
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 400, height: 956))
        controller.view = view
        controller.viewDidLoad()
        let map = try #require(view.scene as? CountryMapScene)
        map.didMove(to: view)

        // Force the fit-failed flag the scene would set at a narrow .pad width.
        map.setScoutCardFitFailedForTesting(true)
        controller.refreshLayoutSupportForTesting(environment: .init(
            safeAreaInsets: .init(top: 24, left: 0, bottom: 20, right: 0),
            layoutClass: .pad
        ))

        #expect(controller.layoutGateReasonForTesting == .unsupportedGeometry)
        #expect(controller.layoutGateReasonForTesting != .mapUnavailable)
        #expect(view.isPaused)

        // Simulate the scene reporting the fit as resolved.
        map.setScoutCardFitFailedForTesting(false)
        controller.refreshLayoutSupportForTesting(environment: .init(
            safeAreaInsets: .init(top: 24, left: 0, bottom: 20, right: 0),
            layoutClass: .pad
        ))

        #expect(controller.layoutGateReasonForTesting == nil)
        #expect(!view.isPaused)
        #expect(view.scene?.isUserInteractionEnabled == true)
    }

    @Test func battleRequestWithoutSKViewReturnsFalse() throws {
        let store = try makeStore(initialState: .init(
            cityRemainingPower: 0,
            stageStatus: .cityConqueredPendingMap
        ))
        let controller = makeGameViewController(store: store)
        let map = CountryMapScene(
            size: CGSize(width: 393, height: 852),
            store: store,
            router: controller
        )

        let accepted = controller.countryMapSceneDidRequestBattle(map)

        #expect(!accepted)
        #expect(!(controller.view is SKView))
    }

    @Test func battleRequestReturnsTrueAfterPresentingSavedState() throws {
        let savedState = KingdomGameState(
            gold: 77,
            cityLevel: 4,
            cityRemainingPower: 321,
            cityNumberInCountry: 4,
            completedCityCount: 3,
            stageStatus: .battleActive
        )
        let store = try makeStore(initialState: savedState)
        let controller = makeGameViewController(store: store)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        controller.view = view
        let map = CountryMapScene(
            size: view.bounds.size,
            store: store,
            router: controller
        )

        let accepted = controller.countryMapSceneDidRequestBattle(map)

        #expect(accepted)
        let battle = try #require(view.scene as? BattleScene)
        #expect(battle.goldForTesting == savedState.gold)
        #expect(battle.cityLevelForTesting == savedState.cityLevel)
        #expect(battle.cityRemainingPowerForTesting == savedState.cityRemainingPower)
    }

    @Test func safeAreaInsetsDidChangeRefreshesBattleSceneLayout() throws {
        let store = try makeStore(initialState: .init(stageStatus: .battleActive))
        let controller = makeGameViewController(store: store)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        controller.view = view
        controller.viewDidLoad()
        let battle = try #require(view.scene as? BattleScene)
        // `presentScene` does not reliably invoke `didMove(to:)` synchronously
        // in a headless test environment, so drive it explicitly to build the
        // interface before sampling the layout counter.
        battle.didMove(to: view)

        let countBefore = battle.battlefieldLayoutCountForTesting
        controller.viewSafeAreaInsetsDidChange()
        #expect(battle.battlefieldLayoutCountForTesting > countBefore)
    }

    @Test func safeAreaInsetsDidChangeRefreshesBuildingViewSceneLayout() throws {
        let store = try makeStore(initialState: .init(stageStatus: .battleActive))
        let controller = makeGameViewController(store: store)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        controller.view = view
        controller.viewDidLoad()
        let battle = try #require(view.scene as? BattleScene)
        battle.didMove(to: view)
        controller.battleSceneDidRequestBuildingView(battle)
        let building = try #require(view.scene as? BuildingViewScene)
        building.didMove(to: view)

        let countBefore = building.layoutInterfaceCallCountForTesting
        controller.viewSafeAreaInsetsDidChange()
        #expect(building.layoutInterfaceCallCountForTesting > countBefore)
    }

    @Test func pendingResultWinsOverBothConqueredStagesAtLaunch() throws {
        for stage in [KingdomGameState.StageStatus.cityConqueredPendingMap, .countryComplete] {
            let city = stage == .countryComplete ? 15 : 3
            let store = try makeStore(initialState: pendingConqueredState(city: city, stage: stage))
            let controller = makeGameViewController(store: store)
            let view = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
            controller.view = view
            controller.viewDidLoad()
            #expect(view.scene is BattleScene)
        }
    }

    @Test func conqueredStateWithoutPendingStillUsesMap() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 3,
            completedCityCount: 3,
            stageStatus: .cityConqueredPendingMap
        ))
        let controller = makeGameViewController(store: store)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        controller.view = view
        controller.viewDidLoad()
        #expect(view.scene is CountryMapScene)
    }

    @Test func buildingViewBattleRequestRestoresPendingIdleReport() throws {
        let store = try makeStore(initialState: pendingConqueredState(
            city: 1, stage: .cityConqueredPendingMap, mode: .idle
        ))
        let controller = makeGameViewController(store: store)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        controller.view = view
        let building = BuildingViewScene(size: view.bounds.size, store: store, router: controller)
        controller.buildingViewSceneDidRequestBattle(building)
        let battle = try #require(view.scene as? BattleScene)
        battle.didMove(to: view)
        #expect(battle.conquestReportLinesForTesting[1] == "Conquered by your buildings")
        #expect(!battle.isGoldBurstVisibleForTesting)
    }

    @Test func mismatchedPendingResultNormalizedAwayByInitAndRoutesToMap() throws {
        // A pending result for city 3 while the current city is 1 is a stale
        // persisted state. KingdomGameState.init normalizes the mismatched
        // pending result to nil (the city key does not match the current
        // city), so the saved state already has no pending result and
        // GameViewController presents the Country Map via normal stage-status
        // routing. The scene-level mismatch guard in
        // pendingResultForPresentation is defense-in-depth for a case that
        // cannot reach it through any normal flow (init normalizes on
        // construct and decode; completeCurrentCity guards on city match
        // before setting pendingBattleResult).
        let store = try makeStore(initialState: KingdomGameState(
            cityLevel: 1,
            cityNumberInCountry: 1,
            completedCityCount: 0,
            stageStatus: .cityConqueredPendingMap,
            pendingBattleResult: pendingResult(city: 3)
        ))
        let controller = makeGameViewController(store: store)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        controller.view = view
        controller.viewDidLoad()

        #expect(view.scene is CountryMapScene)
        #expect(store.load().pendingBattleResult == nil)
    }

    @Test func liveConquestFitFailureGatesControllerViaCallbackOnly() throws {
        // Start with an active battle (no pending result) and normal insets.
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 1
        ))
        let controller = makeGameViewController(store: store)
        let view = SafeAreaOverridingSKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        controller.view = view
        controller.viewDidLoad()
        let battle = try #require(view.scene as? BattleScene)

        // No gate with normal insets and no fit failure.
        #expect(controller.layoutGateReasonForTesting == nil)
        #expect(!battle.isConquestReportFitFailedForTesting)

        // Shrink the safe area so the conquest report cannot render. The inset
        // change alone does NOT gate — no layout refresh has been called since
        // viewDidLoad, so the controller has not re-evaluated.
        view.overrideInsets = UIEdgeInsets(top: 1_000, left: 0, bottom: 0, right: 0)
        #expect(controller.layoutGateReasonForTesting == nil)

        // Trigger a live conquest. The report fit fails inside the combat
        // tick, and the scene's didRequestLayoutGate callback fires
        // synchronously — gating the controller without any manual refresh.
        battle.spawnSoldierForTesting()
        battle.advanceCombatForTesting(deltaTime: 3.0)

        #expect(battle.isConquestReportFitFailedForTesting)
        #expect(controller.layoutGateReasonForTesting == .unsupportedGeometry)
        #expect(view.isPaused)
        #expect(view.scene?.isUserInteractionEnabled == false)

        // Recovery: supported geometry lets the report re-apply, and the next
        // layout event clears the gate.
        view.overrideInsets = .zero
        battle.refreshLayoutForCurrentEnvironment()
        #expect(!battle.isConquestReportFitFailedForTesting)
        #expect(battle.isConquestPopupVisibleForTesting)
        controller.refreshLayoutSupportForTesting(environment: .init(
            safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0),
            layoutClass: .phone
        ))
        #expect(controller.layoutGateReasonForTesting == nil)
        #expect(!view.isPaused)
        #expect(view.scene?.isUserInteractionEnabled == true)
    }

    @Test func conquestReportLayoutReadsHorizontalSafeAreaInsetsFromView() throws {
        let store = try makeStore(initialState: pendingConqueredState(city: 3, stage: .cityConqueredPendingMap))
        let controller = makeGameViewController(store: store)
        let view = SafeAreaOverridingSKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        view.overrideInsets = UIEdgeInsets(top: 0, left: 50, bottom: 0, right: 50)
        controller.view = view
        controller.viewDidLoad()
        let battle = try #require(view.scene as? BattleScene)
        battle.didMove(to: view)
        let input = try #require(battle.lastConquestReportLayoutInputForTesting)
        #expect(input.safeAreaInsets.left == 50)
        #expect(input.safeAreaInsets.right == 50)
    }

    @Test func compatiblePreReleasePendingResultDisplaysOnce() throws {
        let store = try makeStore(initialState: pendingConqueredState())
        let first = makeGameViewController(store: store)
        let firstView = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        first.view = firstView
        first.viewDidLoad()
        let battle = try #require(firstView.scene as? BattleScene)
        battle.didMove(to: firstView)
        battle.tapConquestContinueForTesting()
        #expect(store.load().pendingBattleResult == nil)

        let second = makeGameViewController(store: store)
        let secondView = SKView(frame: firstView.frame)
        second.view = secondView
        second.viewDidLoad()
        #expect(secondView.scene is CountryMapScene)
    }

    private func makeGameViewController(store: KingdomGameStore) -> GameViewController {
        GameViewController(
            store: store,
            feedbackRuntime: GameViewControllerRuntimeTestContext().runtime
        )
    }

    private func makeStore(
        initialState: KingdomGameState
    ) throws -> KingdomGameStore {
        let suiteName = "GameViewControllerTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let store = KingdomGameStore(defaults: defaults, key: "state")
        store.save(initialState)
        return store
    }

    private func pendingResult(city: Int, mode: BattleConquestMode = .live) -> BattleResult {
        BattleResult(
            cityKey: CityKey(countryNumber: 1, cityNumber: city),
            conquestMode: mode,
            activeBattleSeconds: 65,
            deployments: [],
            appliedDamage: [],
            losses: [],
            idleDamageByType: [],
            mvpSoldierType: nil,
            mvpDamageSharePercent: nil,
            usedFavorableUnit: false,
            usedExposedLane: false,
            goldEarned: 8
        )
    }

    private func pendingConqueredState(
        city: Int = 1,
        stage: KingdomGameState.StageStatus = .cityConqueredPendingMap,
        mode: BattleConquestMode = .live
    ) -> KingdomGameState {
        KingdomGameState(
            cityLevel: city,
            cityNumberInCountry: city,
            completedCityCount: city - 1,
            stageStatus: stage,
            pendingBattleResult: pendingResult(city: city, mode: mode)
        )
    }
}

private final class SafeAreaOverridingSKView: SKView {
    var overrideInsets: UIEdgeInsets = .zero
    override var safeAreaInsets: UIEdgeInsets { overrideInsets }
}

@MainActor
private final class GameViewControllerRuntimeTestContext {
    let preferences = RecordingFeedbackPreferencesManager()
    let feedback = RecordingControllerFeedback()
    let sound = RecordingControllerSound()
    private let accessibilityAdapterState = AccessibilityAdapterState()
    let runtime: GameViewControllerFeedbackRuntime

    var accessibilityAdapterFactoryCallCount: Int {
        accessibilityAdapterState.factoryCallCount
    }

    var accessibilityAdapter: FeedbackSettingsAccessibilityAdapter? {
        accessibilityAdapterState.adapter
    }

    var accessibilityFrameConversionCount: Int {
        accessibilityAdapterState.frameConversionCount
    }

    init() {
        let accessibilityAdapterState = accessibilityAdapterState
        runtime = GameViewControllerFeedbackRuntime(
            preferences: preferences,
            feedback: feedback,
            sound: sound,
            makeAccessibilityAdapter: { view in
                let adapter = FeedbackSettingsAccessibilityAdapter(
                    containerView: view,
                    sceneToScreenFrame: { frame in
                        accessibilityAdapterState.frameConversionCount += 1
                        return frame
                    },
                    postNotification: { _, _ in }
                )
                accessibilityAdapterState.factoryCallCount += 1
                accessibilityAdapterState.adapter = adapter
                return adapter
            }
        )
    }
}

@MainActor
private final class AccessibilityAdapterState {
    var factoryCallCount = 0
    var frameConversionCount = 0
    var adapter: FeedbackSettingsAccessibilityAdapter?
}

private final class RecordingControllerFeedback: GameplayFeedbackProviding {
    private(set) var events: [GameplayFeedbackEvent] = []
    private(set) var automaticCombatBatches: [[GameplayFeedbackEvent]] = []

    func emit(_ event: GameplayFeedbackEvent) {
        events.append(event)
    }

    func emitAutomaticCombat(_ orderedEvents: [GameplayFeedbackEvent]) {
        automaticCombatBatches.append(orderedEvents)
    }
}

private final class RecordingControllerSound: GameplayFeedbackRuntimeSoundControlling {
    enum Call: Equatable {
        case prepareIfNeeded
        case handleAppDidEnterBackground
        case handleAppWillEnterForeground
        case handleAudioInterruptionBegan
        case handleAudioInterruptionEnded(Bool)
        case handleLifecycleRecovery
        case stopAllAndDeactivate
        case play(GameplaySoundID, GameplaySoundClass)
    }

    private(set) var calls: [Call] = []

    func prepareIfNeeded() {
        calls.append(.prepareIfNeeded)
    }

    func handleAppDidEnterBackground() {
        calls.append(.handleAppDidEnterBackground)
    }

    func handleAppWillEnterForeground() {
        calls.append(.handleAppWillEnterForeground)
    }

    func handleAudioInterruptionBegan() {
        calls.append(.handleAudioInterruptionBegan)
    }

    func handleAudioInterruptionEnded(shouldResume: Bool) {
        calls.append(.handleAudioInterruptionEnded(shouldResume))
    }

    func handleLifecycleRecovery() {
        calls.append(.handleLifecycleRecovery)
    }

    func play(_ sound: GameplaySoundID, soundClass: GameplaySoundClass) {
        calls.append(.play(sound, soundClass))
    }
}

extension RecordingControllerSound: GameplaySoundOutput {
    func stopAllAndDeactivate() {
        calls.append(.stopAllAndDeactivate)
    }
}

@MainActor
private final class GameViewOutputRuntimeTestContext {
    let preferences = RecordingFeedbackPreferencesManager()
    let sound = RecordingControllerSound()
    let runtime: GameViewControllerFeedbackRuntime

    init() {
        let feedback = DefaultGameplayFeedbackCoordinator(
            preferences: preferences,
            soundOutput: sound,
            hapticOutput: RecordingGameplayHapticOutput(),
            clock: ManualMonotonicClock(now: 0)
        )
        runtime = GameViewControllerFeedbackRuntime(
            preferences: preferences,
            feedback: feedback,
            sound: sound,
            makeAccessibilityAdapter: { view in
                FeedbackSettingsAccessibilityAdapter(
                    containerView: view,
                    sceneToScreenFrame: { $0 },
                    postNotification: { _, _ in }
                )
            }
        )
    }
}
