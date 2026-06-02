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

    @Test func illustratedMapLayoutKeepsTitleFeedbackAndAllCitiesVisible() throws {
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

            #expect(frames.illustratedRegionFrame.contains(frame))
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

    private final class RouteSpy: CountryMapSceneRouting {
        private(set) var didRequestBattle = false

        func countryMapSceneDidRequestBattle(_ scene: CountryMapScene) {
            didRequestBattle = true
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
