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

    @Test func scoutCardFitFailureDoesNotLatchMapUnavailableAndRecoversOnResize() throws {
        // A scout card fit failure is transient (width-dependent). The VC must
        // show .unsupportedGeometry (not .mapUnavailable) and must remove the
        // gate once the scene reports the fit as resolved.
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

        // Simulate a scout card fit failure at a narrow .pad width.
        map.setScoutCardFitFailedForTesting(true)
        controller.refreshLayoutSupportForTesting(environment: .init(
            safeAreaInsets: .init(top: 24, left: 0, bottom: 20, right: 0),
            layoutClass: .pad
        ))

        #expect(controller.layoutGateReasonForTesting == .unsupportedGeometry)
        #expect(controller.layoutGateReasonForTesting != .mapUnavailable)
        #expect(view.isPaused)

        // Simulate the scene recovering after the window widens.
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
}
