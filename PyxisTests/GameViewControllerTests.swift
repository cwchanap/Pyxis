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
        let controller = GameViewController(store: store)
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
        let controller = GameViewController(store: store)
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

    @Test func mapUnavailableIsDistinctFromSupportedGeometry() throws {
        let store = try makeStore(initialState: .init(
            cityRemainingPower: 0,
            stageStatus: .cityConqueredPendingMap
        ))
        let controller = GameViewController(store: store)
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
        let controller = GameViewController(store: store)
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
        let controller = GameViewController(store: store)
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
        let controller = GameViewController(store: store)
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
        let controller = GameViewController(store: store)
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
        let controller = GameViewController(store: store)
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
        let controller = GameViewController(store: store)
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
            let controller = GameViewController(store: store)
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
        let controller = GameViewController(store: store)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        controller.view = view
        controller.viewDidLoad()
        #expect(view.scene is CountryMapScene)
    }

    @Test func buildingViewBattleRequestRestoresPendingIdleReport() throws {
        let store = try makeStore(initialState: pendingConqueredState(
            city: 1, stage: .cityConqueredPendingMap, mode: .idle
        ))
        let controller = GameViewController(store: store)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        controller.view = view
        let building = BuildingViewScene(size: view.bounds.size, store: store, router: controller)
        controller.buildingViewSceneDidRequestBattle(building)
        let battle = try #require(view.scene as? BattleScene)
        battle.didMove(to: view)
        #expect(battle.conquestReportLinesForTesting[1] == "Conquered by your buildings")
        #expect(!battle.isGoldBurstVisibleForTesting)
    }

    @Test func battleReportFitFailureUsesExistingGateAndRecovers() throws {
        let store = try makeStore(initialState: KingdomGameState(stageStatus: .battleActive))
        let controller = GameViewController(store: store)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        controller.view = view
        controller.viewDidLoad()
        let battle = try #require(view.scene as? BattleScene)
        battle.setConquestReportFitFailedForTesting(true)
        controller.refreshLayoutSupportForTesting(environment: .init(
            safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0),
            layoutClass: .phone
        ))
        #expect(controller.layoutGateReasonForTesting == .unsupportedGeometry)
        battle.setConquestReportFitFailedForTesting(false)
        controller.refreshLayoutSupportForTesting(environment: .init(
            safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0),
            layoutClass: .phone
        ))
        #expect(controller.layoutGateReasonForTesting == nil)
    }

    @Test func conquestReportLayoutReadsHorizontalSafeAreaInsetsFromView() throws {
        let store = try makeStore(initialState: pendingConqueredState(city: 3, stage: .cityConqueredPendingMap))
        let controller = GameViewController(store: store)
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
        let first = GameViewController(store: store)
        let firstView = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        first.view = firstView
        first.viewDidLoad()
        let battle = try #require(firstView.scene as? BattleScene)
        battle.didMove(to: firstView)
        battle.tapConquestContinueForTesting()
        #expect(store.load().pendingBattleResult == nil)

        let second = GameViewController(store: store)
        let secondView = SKView(frame: firstView.frame)
        second.view = secondView
        second.viewDidLoad()
        #expect(secondView.scene is CountryMapScene)
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
