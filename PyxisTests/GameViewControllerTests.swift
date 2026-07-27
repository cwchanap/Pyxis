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

    @Test func layoutGateUsesInjectedClockRatherThanWallClock() throws {
        let origin = Date(timeIntervalSinceReferenceDate: 9_000)
        let store = try makeStore(initialState: makeIdleAccruingState(since: origin))
        var currentDate = origin
        let controller = GameViewController(store: store, now: { currentDate })
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        controller.view = view
        controller.viewDidLoad()
        let map = try #require(view.scene as? CountryMapScene)

        // Clear whatever gate state the headless test environment produced
        // on initial presentation so the elapsed time below is attributable
        // only to the explicit transition performed next.
        controller.refreshLayoutSupportForTesting(environment: .init(
            safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0),
            layoutClass: .phone
        ))
        #expect(!controller.isLayoutGateVisibleForTesting)

        currentDate = origin.addingTimeInterval(42)
        view.frame.size = CGSize(width: 667, height: 375)
        controller.refreshLayoutSupportForTesting(environment: .init(
            safeAreaInsets: .zero,
            layoutClass: .phone
        ))

        #expect(controller.layoutGateReasonForTesting == .unsupportedGeometry)
        #expect(map.lastIdleProgressResultForTesting.elapsedSeconds == 42)
    }

    @Test func mapUnavailableTakesPriorityOverAnAlreadyActiveGeometryGate() throws {
        let store = try makeStore(initialState: .init(
            cityRemainingPower: 0,
            stageStatus: .cityConqueredPendingMap
        ))
        let controller = GameViewController(store: store)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        controller.view = view
        controller.viewDidLoad()
        let map = try #require(view.scene as? CountryMapScene)

        view.frame.size = CGSize(width: 667, height: 375)
        controller.refreshLayoutSupportForTesting(environment: .init(
            safeAreaInsets: .zero,
            layoutClass: .phone
        ))
        #expect(controller.layoutGateReasonForTesting == .unsupportedGeometry)

        controller.countryMapScene(map, didRequestLayoutGate: .mapUnavailable)

        #expect(controller.layoutGateReasonForTesting == .mapUnavailable)
        #expect(controller.layoutGateTextForTesting == "Map unavailable")
        #expect(view.isPaused)
    }

    @Test func freshMapPresentationClearsAStickyMapUnavailableRequest() throws {
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

        // Leaving for battle and returning to a freshly presented map (e.g.
        // re-entering the map stage) clears the sticky map-unavailable
        // request instead of carrying it forward indefinitely.
        controller.countryMapSceneDidRequestBattle(map)
        let battle = try #require(view.scene as? BattleScene)
        controller.battleSceneDidRequestCountryMap(battle)

        controller.refreshLayoutSupportForTesting(environment: .init(
            safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0),
            layoutClass: .phone
        ))

        #expect(!controller.isLayoutGateVisibleForTesting)
        #expect(!view.isPaused)
    }

    private func makeIdleAccruingState(since date: Date) -> KingdomGameState {
        var state = KingdomGameState(cityRemainingPower: 0, stageStatus: .cityConqueredPendingMap)
        state.cityBattleStates[state.currentCityKey.storageKey] = CityBattleState(
            slots: [1: CityBuilding(type: .barracks)],
            lastBuildingProgressResolvedAt: date
        )
        state.markCurrentCityBuildingProgressInactive(at: date)
        return state
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
