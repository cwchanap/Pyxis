//
//  CountryMapSceneTests.swift
//  PyxisTests
//

import Foundation
import SpriteKit
import Testing
@testable import Pyxis

@MainActor
struct CountryMapSceneTests {
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
        #expect(router.didRequestBattle)
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
        #expect(!router.didRequestBattle)
        #expect(scene.feedbackTextForTesting == "City 3 is locked.")
    }

    @Test func completedCountryHasNoEnterableNextCity() throws {
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

        scene.enterCityForTesting(15)

        #expect(store.load() == initialState)
        #expect(!router.didRequestBattle)
        #expect(scene.feedbackTextForTesting == "Country 1 conquered.")
    }

    @Test func completedCountryStartsWithConqueredFeedback() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityLevel: 15,
            cityRemainingPower: 0,
            cityNumberInCountry: 15,
            completedCityCount: 15,
            stageStatus: .countryComplete
        ))
        let scene = makeScene(store: store, router: RouteSpy())

        #expect(scene.feedbackTextForTesting == "Country 1 conquered.")
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
        #expect(router.didRequestBattle)
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
        #expect(router.didRequestBattle)
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
        #expect(!router.didRequestBattle)
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
        #expect(router.didRequestBattle)
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
        #expect(!router.didRequestBattle)
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

    @Test func mapShowsTraitForUnlockedCityInFeedback() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 3,
            completedCityCount: 3,
            stageStatus: .cityConqueredPendingMap
        ))
        let scene = makeScene(store: store, router: RouteSpy())

        #expect(scene.feedbackTextForTesting.contains("Spiked Gate"))
    }

    @Test func selectingCompletedCityReportsDefenseTrait() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 3,
            completedCityCount: 3,
            stageStatus: .cityConqueredPendingMap
        ))
        let scene = makeScene(store: store, router: RouteSpy())

        scene.enterCityForTesting(3)

        #expect(scene.feedbackTextForTesting == "City 3 complete. Arrow Tower.")
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
        #expect(router.didRequestBattle)
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
        #expect(scene.feedbackTextForTesting == "Cannot enter city yet.")
    }

    @Test func compactLandscapeLayoutKeepsCityNodesInsideMapArea() throws {
        let size = CGSize(width: 667, height: 375)
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let scene = makeScene(size: size, store: store, router: RouteSpy())
        let topMapLimit = size.height - 64

        for cityNumber in 1...KingdomGameState.firstCountryCityCount {
            let cityNode = try #require(scene.childNode(withName: "//countryMapCity-\(cityNumber)"))
            let frame = cityNode.calculateAccumulatedFrame()

            #expect(frame.minX >= 0)
            #expect(frame.maxX <= size.width)
            #expect(frame.minY >= 0)
            #expect(frame.maxY <= topMapLimit)
        }
    }

    @Test func fullBackdropMapLayoutKeepsTitleFeedbackAndAllCitiesVisible() throws {
        let size = CGSize(width: 390, height: 844)
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let scene = makeScene(size: size, store: store, router: RouteSpy())
        let frames = scene.mapLayoutFramesForTesting

        #expect(frames.sceneFrame.contains(frames.titlePanelFrame))
        #expect(frames.sceneFrame.contains(frames.feedbackPanelFrame))
        #expect(frames.sceneFrame.contains(frames.illustratedRegionFrame))
        #expect(frames.titlePanelFrame.minY > frames.illustratedRegionFrame.maxY)
        #expect(frames.feedbackPanelFrame.maxY < frames.illustratedRegionFrame.minY)

        for cityNumber in 1...KingdomGameState.firstCountryCityCount {
            let cityNode = try #require(scene.childNode(withName: "//countryMapCity-\(cityNumber)"))
            let frame = cityNode.calculateAccumulatedFrame()

            #expect(frames.sceneFrame.contains(frame))
            #expect(!frames.titlePanelFrame.intersects(frame))
            #expect(!frames.feedbackPanelFrame.intersects(frame))
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
        let frames = scene.mapLayoutFramesForTesting
        let backdrop = try #require(scene.childNode(withName: "//country-map-backdrop"))
        let backdropFrame = backdrop.calculateAccumulatedFrame()

        #expect(backdropFrame.minX <= 0)
        #expect(backdropFrame.maxX >= size.width)
        #expect(backdropFrame.minY <= 0)
        #expect(backdropFrame.maxY >= size.height)
        #expect(backdropFrame.contains(frames.titlePanelFrame))
        #expect(backdropFrame.contains(frames.feedbackPanelFrame))
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
        let backdrop = try #require(scene.childNode(withName: "//country-map-backdrop"))
        let backdropFrame = backdrop.calculateAccumulatedFrame()
        let authoredPadAnchors = [
            1: CGPoint(x: 0.4000, y: 0.1696),
            2: CGPoint(x: 0.7528, y: 0.2020),
            3: CGPoint(x: 0.6846, y: 0.2874),
            4: CGPoint(x: 0.6904, y: 0.3721),
            5: CGPoint(x: 0.2776, y: 0.2517),
            6: CGPoint(x: 0.3518, y: 0.3386),
            7: CGPoint(x: 0.4171, y: 0.4171),
            8: CGPoint(x: 0.7078, y: 0.4598),
            9: CGPoint(x: 0.7200, y: 0.6160),
            10: CGPoint(x: 0.5894, y: 0.6473),
            11: CGPoint(x: 0.3468, y: 0.5793),
            12: CGPoint(x: 0.4225, y: 0.6725),
            13: CGPoint(x: 0.3452, y: 0.7280),
            14: CGPoint(x: 0.4865, y: 0.7651),
            15: CGPoint(x: 0.6807, y: 0.7931)
        ]

        for (cityNumber, anchor) in authoredPadAnchors {
            let cityPosition = try #require(scene.cityNodePositionForTesting(cityNumber))
            let expectedPosition = CGPoint(
                x: backdropFrame.minX + backdropFrame.width * anchor.x,
                y: backdropFrame.minY + backdropFrame.height * anchor.y
            )

            #expect(abs(cityPosition.x - expectedPosition.x) <= 1.0)
            #expect(abs(cityPosition.y - expectedPosition.y) <= 1.0)
        }
    }

    @Test func illustratedRegionMapAvoidsTallPhoneSensorArea() throws {
        let size = CGSize(width: 390, height: 844)
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let scene = makeScene(size: size, store: store, router: RouteSpy())
        let frames = scene.mapLayoutFramesForTesting

        #expect(frames.titlePanelFrame.maxY <= size.height - 58)
        #expect(frames.feedbackPanelFrame.minY >= 26)
        #expect(frames.illustratedRegionFrame.maxY < frames.titlePanelFrame.minY)
        #expect(frames.illustratedRegionFrame.minY > frames.feedbackPanelFrame.maxY)
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
        let size = CGSize(width: 320, height: 568)
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 5,
            completedCityCount: 4,
            stageStatus: .cityConqueredPendingMap
        ))
        let scene = makeScene(size: size, store: store, router: RouteSpy())
        let frames = scene.mapLayoutFramesForTesting

        #expect(scene.titleLabelFrameWidthForTesting <= frames.titlePanelFrame.width)
        #expect(scene.titleLabelFontSizeForTesting >= 8)
    }

    @Test func titleLabelFitsWithCurrentCityButtonVisible() throws {
        let size = CGSize(width: 320, height: 568)
        let store = try makeStore(initialState: KingdomGameState(
            cityLevel: 3,
            cityRemainingPower: 50,
            cityNumberInCountry: 3,
            completedCityCount: 2,
            stageStatus: .battleActive
        ))
        let scene = makeScene(size: size, store: store, router: RouteSpy())
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

        #expect(!router.didRequestBattle)
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

        #expect(router.didRequestBattle)
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

        #expect(!router.didRequestBattle)
    }

    @Test func touchesEndedCurrentCityButtonRequestsBattle() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityLevel: 3,
            cityRemainingPower: 50,
            cityNumberInCountry: 3,
            completedCityCount: 2,
            stageStatus: .battleActive
        ))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        let point = try #require(scene.currentCityButtonPositionForTesting)

        scene.touchesEnded([MockTouch(location: point)], with: nil)

        #expect(router.didRequestBattle)
    }

    @Test func requestCurrentCityBattleWhenNotBattleActiveShowsFeedback() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 3,
            completedCityCount: 3,
            stageStatus: .cityConqueredPendingMap
        ))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        scene.requestCurrentCityBattleForTesting()

        #expect(!router.didRequestBattle)
        #expect(scene.feedbackTextForTesting == "City 4: Spiked Gate")
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

        #expect(scene.feedbackTextForTesting == "Cannot enter city yet.")
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

    private final class RouteSpy: CountryMapSceneRouting {
        private(set) var didRequestBattle = false

        func countryMapSceneDidRequestBattle(_ scene: CountryMapScene) {
            didRequestBattle = true
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

    private func makeScene(store: KingdomGameStore, router: CountryMapSceneRouting?) -> CountryMapScene {
        makeScene(size: CGSize(width: 390, height: 844), store: store, router: router)
    }

    private func makeScene(
        size: CGSize,
        store: KingdomGameStore,
        router: CountryMapSceneRouting?
    ) -> CountryMapScene {
        let scene = CountryMapScene(size: size, store: store, router: router)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        scene.didMove(to: view)
        return scene
    }

    private func makeStore(initialState: KingdomGameState) throws -> KingdomGameStore {
        let suiteName = "PyxisTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let store = KingdomGameStore(defaults: defaults, key: "state")
        store.save(initialState)
        return store
    }
}
