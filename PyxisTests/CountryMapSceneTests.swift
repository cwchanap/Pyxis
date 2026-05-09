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

    private final class RouteSpy: CountryMapSceneRouting {
        private(set) var didRequestBattle = false

        func countryMapSceneDidRequestBattle(_ scene: CountryMapScene) {
            didRequestBattle = true
        }
    }

    private func makeScene(store: KingdomGameStore, router: CountryMapSceneRouting?) -> CountryMapScene {
        let size = CGSize(width: 390, height: 844)
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
