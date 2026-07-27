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
        #expect(scene.mapLayoutFramesForTesting.feedbackPanelFrame.midX == layout.informationRegionFrame.midX)
        #expect(scene.mapLayoutFramesForTesting.feedbackPanelFrame.midY == layout.informationRegionFrame.midY)
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
        let layout = try #require(scene.countryMapLayoutForTesting)
        let frames = scene.mapLayoutFramesForTesting

        #expect(frames.sceneFrame == layout.sceneFrame)
        #expect(frames.titlePanelFrame == layout.titleControlRegionFrame)
        #expect(frames.illustratedRegionFrame == layout.illustratedMapRegionFrame)
        #expect(frames.feedbackPanelFrame.midX == layout.informationRegionFrame.midX)
        #expect(frames.feedbackPanelFrame.midY == layout.informationRegionFrame.midY)
        #expect(frames.titlePanelFrame.minY > frames.illustratedRegionFrame.maxY)
        #expect(frames.feedbackPanelFrame.maxY < frames.illustratedRegionFrame.minY)

        for cityNumber in 1...KingdomGameState.firstCountryCityCount {
            let position = try #require(scene.cityNodePositionForTesting(cityNumber))
            let frame = CGRect(x: position.x - 22, y: position.y - 22, width: 44, height: 44)

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
        #expect(layout.titleControlRegionFrame.contains(layout.currentCityControlFrame))
        #expect(scene.currentCityButtonFrameForTesting == layout.currentCityControlFrame)
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

    private func makeScene(
        size: CGSize = CGSize(width: 393, height: 852),
        store: KingdomGameStore,
        router: CountryMapSceneRouting?,
        environment: CountryMapLayoutEnvironment = .init(
            safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0),
            layoutClass: .phone
        )
    ) -> CountryMapScene {
        let scene = CountryMapScene(
            size: size,
            store: store,
            router: router,
            layoutEnvironmentOverride: environment
        )
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
