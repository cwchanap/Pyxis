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
        #expect(router.battleRequestCount == 1)
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
        #expect(router.battleRequestCount == 0)
        #expect(scene.visibleFeedbackTextForTesting == "City 3 is locked")
    }

    @Test func completedCountryCityNodeShowsExactFeedbackWithoutMutationOrRoute() throws {
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
        let baseContent = scene.scoutCardBaseContentForTesting
        let cityPoint = try #require(scene.cityNodePositionForTesting(15))

        scene.touchesEnded([MockTouch(location: cityPoint)], with: nil)

        #expect(store.load() == initialState)
        #expect(router.battleRequestCount == 0)
        #expect(scene.visibleFeedbackTextForTesting == "City 15 complete")
        #expect(scene.feedbackElapsedForTesting == 0)
        #expect(scene.feedbackRemainingDurationForTesting == 1.5)
        #expect(scene.projectedScoutCardContentForTesting
            == .countryComplete(countryNumber: 1))
        #expect(scene.scoutCardBaseContentForTesting == baseContent)

        scene.advanceFeedbackForTesting(by: 1.49)
        #expect(scene.visibleFeedbackTextForTesting == "City 15 complete")
        #expect(abs((scene.feedbackRemainingDurationForTesting ?? 0) - 0.01) < 0.001)

        scene.advanceFeedbackForTesting(by: 0.01)
        #expect(scene.visibleFeedbackTextForTesting == nil)
        #expect(scene.feedbackRemainingDurationForTesting == nil)
        #expect(scene.projectedScoutCardContentForTesting
            == .countryComplete(countryNumber: 1))
        #expect(scene.scoutCardBaseContentForTesting == baseContent)
    }

    @Test func completedCountryStartsWithConqueredCardContent() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityLevel: 15,
            cityRemainingPower: 0,
            cityNumberInCountry: 15,
            completedCityCount: 15,
            stageStatus: .countryComplete
        ))
        let scene = makeScene(store: store, router: RouteSpy())

        #expect(scene.visibleFeedbackTextForTesting == nil)
        #expect(scene.projectedScoutCardContentForTesting == .countryComplete(countryNumber: 1))
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
        #expect(router.battleRequestCount == 1)
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
        #expect(router.battleRequestCount == 1)
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
        #expect(router.battleRequestCount == 0)
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
        #expect(router.battleRequestCount == 1)
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
        #expect(router.battleRequestCount == 0)
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

    @Test func mapShowsTraitForUnlockedCityInScoutCard() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 3,
            completedCityCount: 3,
            stageStatus: .cityConqueredPendingMap
        ))
        let scene = makeScene(store: store, router: RouteSpy())

        guard case .scout(let scout) = scene.projectedScoutCardContentForTesting else {
            Issue.record("Expected Scout Card content")
            return
        }
        #expect(scout.defenseTrait == .spikedGate)
    }

    @Test func selectingCompletedCityShowsExactFeedback() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 3,
            completedCityCount: 3,
            stageStatus: .cityConqueredPendingMap
        ))
        let scene = makeScene(store: store, router: RouteSpy())

        scene.enterCityForTesting(3)

        #expect(scene.visibleFeedbackTextForTesting == "City 3 complete")
    }

    @Test func lockedFeedbackOverlaysUnchangedCardAndExpiresAtExactDuration() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        let baseContent = scene.scoutCardBaseContentForTesting
        let projectedContent = scene.projectedScoutCardContentForTesting

        scene.enterCityForTesting(3)

        #expect(scene.visibleFeedbackTextForTesting == "City 3 is locked")
        #expect(scene.feedbackElapsedForTesting == 0)
        #expect(scene.feedbackRemainingDurationForTesting == 1.5)
        let feedbackContent = try #require(scene.scoutCardBaseContentForTesting)
        #expect(feedbackContent.badge == baseContent?.badge)
        #expect(feedbackContent.title == baseContent?.title)
        #expect(feedbackContent.traitLines == baseContent?.traitLines)
        #expect(feedbackContent.favorable == baseContent?.favorable)
        #expect(feedbackContent.disadvantaged == baseContent?.disadvantaged)
        #expect(feedbackContent.lane == baseContent?.lane)
        #expect(feedbackContent.reward == baseContent?.reward)
        #expect(feedbackContent.attack == baseContent?.attack)
        #expect(abs(feedbackContent.attackAlpha - GameUITheme.Alpha.lockedIcon) < 0.001)
        #expect(scene.projectedScoutCardContentForTesting == projectedContent)

        let overlayFrame = try #require(scene.scoutCardOverlayHitFrameForTesting)
        let overlayPoint = CGPoint(x: overlayFrame.midX, y: overlayFrame.midY)
        scene.touchesEnded([MockTouch(location: overlayPoint)], with: nil)

        #expect(router.battleRequestCount == 0)
        #expect(scene.visibleFeedbackTextForTesting == "City 3 is locked")
        #expect(scene.feedbackElapsedForTesting == 0)

        scene.advanceFeedbackForTesting(by: 1.49)
        #expect(scene.visibleFeedbackTextForTesting == "City 3 is locked")
        #expect(abs((scene.feedbackRemainingDurationForTesting ?? 0) - 0.01) < 0.001)

        scene.advanceFeedbackForTesting(by: 0.01)
        #expect(scene.visibleFeedbackTextForTesting == nil)
        #expect(scene.feedbackElapsedForTesting == nil)
        #expect(scene.feedbackRemainingDurationForTesting == nil)
        #expect(scene.scoutCardOverlayHitFrameForTesting == nil)
        #expect(scene.scoutCardBaseContentForTesting == baseContent)
        #expect(scene.projectedScoutCardContentForTesting == projectedContent)
    }

    @Test func completedFeedbackCannotBeDismissedEarlyByTaps() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 3,
            completedCityCount: 3,
            stageStatus: .cityConqueredPendingMap
        ))
        let scene = makeScene(store: store, router: RouteSpy())

        scene.enterCityForTesting(3)
        scene.advanceFeedbackForTesting(by: 0.75)
        let overlayFrame = try #require(scene.scoutCardOverlayHitFrameForTesting)
        scene.touchesEnded(
            [MockTouch(location: CGPoint(x: overlayFrame.midX, y: overlayFrame.midY))],
            with: nil
        )

        #expect(scene.visibleFeedbackTextForTesting == "City 3 complete")
        #expect(scene.feedbackElapsedForTesting == 0.75)
        #expect(scene.feedbackRemainingDurationForTesting == 0.75)
    }

    @Test func idleFeedbackPreservesExistingWordingAndLongDuration() throws {
        let origin = Date(timeIntervalSinceReferenceDate: 9_000)
        let store = try makeStore(initialState: KingdomGameState(
            lastBackgroundedAt: origin
        ))
        let scene = makeScene(store: store, router: RouteSpy())

        scene.layoutGateWillPause(at: origin.addingTimeInterval(10))

        #expect(scene.lastIdleProgressResultForTesting.elapsedSeconds == 10)
        #expect(scene.visibleFeedbackTextForTesting == "No building damage while away.")
        #expect(scene.feedbackRemainingDurationForTesting == 2.5)
    }

    @Test func countryCompleteCardRemainsVisibleAfterIgnoredEntryRequest() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityLevel: 15,
            cityRemainingPower: 0,
            cityNumberInCountry: 15,
            completedCityCount: 15,
            stageStatus: .countryComplete
        ))
        let scene = makeScene(store: store, router: RouteSpy())
        let baseContent = scene.scoutCardBaseContentForTesting

        #expect(scene.projectedScoutCardContentForTesting == .countryComplete(countryNumber: 1))

        scene.enterCityForTesting(15)
        #expect(scene.visibleFeedbackTextForTesting == nil)
        #expect(scene.projectedScoutCardContentForTesting == .countryComplete(countryNumber: 1))
        #expect(scene.scoutCardBaseContentForTesting == baseContent)
    }

    @Test func didChangeSizePreservesActiveFeedbackAndRemainingDuration() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let scene = makeScene(store: store, router: RouteSpy())

        scene.enterCityForTesting(3)
        scene.advanceFeedbackForTesting(by: 0.6)
        let text = scene.visibleFeedbackTextForTesting
        let remaining = scene.feedbackRemainingDurationForTesting

        scene.didChangeSize(scene.size)

        #expect(scene.visibleFeedbackTextForTesting == text)
        #expect(scene.feedbackRemainingDurationForTesting == remaining)
        #expect(scene.scoutCardOverlayHitFrameForTesting != nil)
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
        #expect(router.battleRequestCount == 1)
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
        #expect(scene.visibleFeedbackTextForTesting == "Cannot enter city yet.")
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

    @Test func unsupportedTransitionClearsAndSupportedTransitionRestoresMapGeometry() throws {
        let supportedSize = CGSize(width: 393, height: 852)
        let scene = makeScene(
            size: supportedSize,
            store: try makeStore(initialState: .init(
                cityNumberInCountry: 2,
                completedCityCount: 1,
                stageStatus: .battleActive
            )),
            router: RouteSpy()
        )
        let originalCityPoint = try #require(scene.cityNodePositionForTesting(2))
        let backdrop = try #require(scene.childNode(withName: "//country-map-backdrop"))
        let city = try #require(scene.childNode(withName: "//countryMapCity-2"))
        var conqueredMarker: SKSpriteNode?
        scene.enumerateChildNodes(withName: "//countryMapCity-1") { node, stop in
            guard let marker = node as? SKSpriteNode else { return }
            conqueredMarker = marker
            stop.pointee = true
        }
        let marker = try #require(conqueredMarker)

        #expect(scene.lastLayoutResultForTesting != .unsupported(.unsupportedGeometry))
        #expect(scene.routeLayoutCountForTesting == 18)
        #expect(!backdrop.isHidden)
        #expect(!city.isHidden)
        #expect(!scene.isCurrentCityButtonHiddenForTesting)
        #expect(!marker.isHidden)
        #expect(scene.cityNumberAtPointForTesting(originalCityPoint) == 2)

        scene.size = CGSize(width: 667, height: 375)
        scene.refreshLayoutForCurrentEnvironment()

        #expect(scene.lastLayoutResultForTesting == .unsupported(.unsupportedGeometry))
        #expect(scene.routeLayoutCountForTesting == 0)
        #expect(scene.mapLayoutFramesForTesting.sceneFrame == .zero)
        #expect(scene.mapLayoutFramesForTesting.titlePanelFrame == .zero)
        #expect(scene.mapLayoutFramesForTesting.illustratedRegionFrame == .zero)
        #expect(scene.mapLayoutFramesForTesting.scoutCardFrame == .zero)
        #expect(scene.scoutCardFrameForTesting == nil)
        #expect(scene.scoutCardHitFrameForTesting == nil)
        #expect(scene.scoutCardAttackHitFrameForTesting == nil)
        #expect(scene.scoutCardOverlayHitFrameForTesting == nil)
        #expect(backdrop.isHidden)
        #expect(city.isHidden)
        #expect(scene.isCurrentCityButtonHiddenForTesting)
        #expect(marker.isHidden)
        #expect(scene.cityNumberAtPointForTesting(originalCityPoint) == nil)

        scene.layoutGateWillPause(at: Date(timeIntervalSinceReferenceDate: 10))

        #expect(scene.routeLayoutCountForTesting == 0)
        #expect(scene.isCurrentCityButtonHiddenForTesting)
        #expect(marker.isHidden)
        #expect(scene.cityNumberAtPointForTesting(originalCityPoint) == nil)

        scene.size = supportedSize
        scene.refreshLayoutForCurrentEnvironment()
        scene.layoutGateWillResume(at: Date(timeIntervalSinceReferenceDate: 20))

        let restoredCityPoint = try #require(scene.cityNodePositionForTesting(2))
        #expect(scene.lastLayoutResultForTesting != .unsupported(.unsupportedGeometry))
        #expect(scene.routeLayoutCountForTesting == 18)
        #expect(!backdrop.isHidden)
        #expect(!city.isHidden)
        #expect(!scene.isCurrentCityButtonHiddenForTesting)
        #expect(!marker.isHidden)
        #expect(scene.cityNumberAtPointForTesting(restoredCityPoint) == 2)
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
        #expect(scene.mapLayoutFramesForTesting.scoutCardFrame == layout.informationRegionFrame)
        #expect(scene.scoutCardFrameForTesting == layout.informationRegionFrame)
        #expect(scene.scoutCardHitFrameForTesting == layout.informationRegionFrame)
        #expect(scene.scoutCardAttackHitFrameForTesting != nil)
        #expect(scene.scoutCardOverlayHitFrameForTesting == nil)
    }

    @Test func fullBackdropMapLayoutKeepsTitleScoutCardAndAllCitiesVisible() throws {
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
        #expect(frames.scoutCardFrame == layout.informationRegionFrame)
        #expect(frames.titlePanelFrame.minY > frames.illustratedRegionFrame.maxY)
        #expect(frames.scoutCardFrame.maxY < frames.illustratedRegionFrame.minY)

        for cityNumber in 1...KingdomGameState.firstCountryCityCount {
            let position = try #require(scene.cityNodePositionForTesting(cityNumber))
            let frame = CGRect(x: position.x - 22, y: position.y - 22, width: 44, height: 44)

            #expect(frames.sceneFrame.contains(frame))
            #expect(!frames.titlePanelFrame.intersects(frame))
            #expect(!frames.scoutCardFrame.intersects(frame))
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

    @Test func missingBackdropIsDetectedSeparatelyFromLayout() {
        #expect(!CountryMapScene.isBackdropAvailable(
            named: "country-map-backdrop",
            imageLoader: { _ in nil }
        ))
        #expect(CountryMapLayout.compute(.init(
            sceneSize: CGSize(width: 393, height: 852),
            environment: .init(
                safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0),
                layoutClass: .phone
            ),
            definition: .country1
        )) != .unsupported(.invalidAuthoredData))
    }

    @Test func missingBackdropMarksSceneUnavailableAndRefusesLayout() throws {
        let store = try makeStore(initialState: KingdomGameState(
            stageStatus: .cityConqueredPendingMap
        ))
        let router = RouteSpy()
        let scene = makeScene(
            store: store,
            router: router,
            imageLoader: { _ in nil }
        )

        #expect(scene.isMapUnavailableForTesting)
        #expect(router.requestedGateReason == .mapUnavailable)
        #expect(scene.countryMapLayoutForTesting == nil)
        #expect(scene.routeLayoutCountForTesting == 0)
        #expect(scene.scoutCardFrameForTesting == nil)
        #expect(scene.scoutCardHitFrameForTesting == nil)
        #expect(scene.scoutCardAttackHitFrameForTesting == nil)
        #expect(scene.scoutCardOverlayHitFrameForTesting == nil)

        // A resize must not promote the half-built interface to a supported layout.
        scene.didChangeSize(CGSize(width: 414, height: 896))
        #expect(scene.countryMapLayoutForTesting == nil)
        #expect(scene.routeLayoutCountForTesting == 0)
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

        #expect(router.battleRequestCount == 0)
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

        let saved = store.load()
        #expect(saved.stageStatus == .battleActive)
        #expect(saved.cityNumberInCountry == 2)
        #expect(router.battleRequestCount == 1)
    }

    @Test func touchesEndedOnAttackEntersProjectedScoutCity() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        let attackFrame = try #require(scene.scoutCardAttackHitFrameForTesting)

        scene.touchesEnded(
            [MockTouch(location: CGPoint(x: attackFrame.midX, y: attackFrame.midY))],
            with: nil
        )

        let saved = store.load()
        #expect(saved.stageStatus == .battleActive)
        #expect(saved.cityNumberInCountry == 2)
        #expect(saved.cityLevel == 2)
        #expect(saved.cityRemainingPower == KingdomGameState.cityMaxPower(for: 2))
        #expect(router.battleRequestCount == 1)
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

        #expect(router.battleRequestCount == 0)
    }

    @Test func touchesEndedCurrentCityButtonRequestsBattle() throws {
        let initialState = KingdomGameState(
            cityLevel: 3,
            cityRemainingPower: 50,
            cityNumberInCountry: 3,
            completedCityCount: 2,
            stageStatus: .battleActive
        )
        let store = try makeStore(initialState: initialState)
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        let point = try #require(scene.currentCityButtonPositionForTesting)

        scene.touchesEnded([MockTouch(location: point)], with: nil)

        #expect(store.load() == initialState)
        #expect(router.battleRequestCount == 1)
    }

    @Test func acceptedTapsAcrossDifferentEntryTargetsRequestBattleOnce() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        let attackFrame = try #require(scene.scoutCardAttackHitFrameForTesting)
        let cityPoint = try #require(scene.cityNodePositionForTesting(2))

        scene.touchesEnded(
            [MockTouch(location: CGPoint(x: attackFrame.midX, y: attackFrame.midY))],
            with: nil
        )
        scene.touchesEnded([MockTouch(location: cityPoint)], with: nil)

        #expect(router.battleRequestCount == 1)
        #expect(scene.isRoutingToBattleForTesting)
    }

    @Test func acceptedRoutingKeepsCardButDisablesEveryEntryTarget() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        let attackFrame = try #require(scene.scoutCardAttackHitFrameForTesting)
        let attackPoint = CGPoint(x: attackFrame.midX, y: attackFrame.midY)
        let cityPoint = try #require(scene.cityNodePositionForTesting(2))

        scene.touchesEnded([MockTouch(location: attackPoint)], with: nil)

        #expect(scene.isRoutingToBattleForTesting)
        #expect(scene.scoutCardHitFrameForTesting != nil)
        #expect(scene.scoutCardAttackHitFrameForTesting == nil)
        #expect(abs(
            (scene.scoutCardBaseContentForTesting?.attackAlpha ?? 0)
                - GameUITheme.Alpha.lockedIcon
        ) < 0.001)

        let currentPoint = try #require(scene.currentCityButtonPositionForTesting)
        scene.touchesEnded([MockTouch(location: attackPoint)], with: nil)
        scene.touchesEnded([MockTouch(location: currentPoint)], with: nil)
        scene.touchesEnded([MockTouch(location: cityPoint)], with: nil)

        #expect(router.battleRequestCount == 1)
    }

    @Test func missingRouterDiscardsEnteredMutationAndLeavesRetryEnabled() throws {
        let initialState = KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        )
        let countingStore = try makeCountingStore(initialState: initialState)
        let store = countingStore.store
        let scene = makeScene(store: store, router: nil)
        let attackFrame = try #require(scene.scoutCardAttackHitFrameForTesting)
        #expect(countingStore.defaults.stateSaveCount == 0)

        scene.touchesEnded(
            [MockTouch(location: CGPoint(x: attackFrame.midX, y: attackFrame.midY))],
            with: nil
        )

        #expect(store.load() == initialState)
        #expect(countingStore.defaults.stateSaveCount == 0)
        #expect(!scene.isRoutingToBattleForTesting)
        #expect(scene.visibleFeedbackTextForTesting == "Cannot enter city yet.")
        #expect(scene.scoutCardAttackHitFrameForTesting == nil)

        scene.advanceFeedbackForTesting(by: 2.5)

        #expect(scene.scoutCardAttackHitFrameForTesting != nil)
    }

    @Test func rejectedRouterRetainsSavedBattleAndRestoresRetry() throws {
        let countingStore = try makeCountingStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let store = countingStore.store
        let router = RouteSpy()
        router.acceptsBattleRequest = false
        router.onBattleRequest = { requestCount in
            #expect(countingStore.defaults.stateSaveCount == requestCount)
        }
        let scene = makeScene(store: store, router: router)
        let attackFrame = try #require(scene.scoutCardAttackHitFrameForTesting)
        let attackPoint = CGPoint(x: attackFrame.midX, y: attackFrame.midY)
        #expect(countingStore.defaults.stateSaveCount == 0)

        scene.touchesEnded([MockTouch(location: attackPoint)], with: nil)

        let saved = store.load()
        #expect(saved.stageStatus == .battleActive)
        #expect(saved.cityNumberInCountry == 2)
        #expect(countingStore.defaults.stateSaveCount == 1)
        #expect(router.battleRequestCount == 1)
        #expect(!scene.isRoutingToBattleForTesting)
        #expect(scene.visibleFeedbackTextForTesting == "Cannot enter city yet.")
        #expect(scene.scoutCardAttackHitFrameForTesting == nil)

        scene.advanceFeedbackForTesting(by: 2.5)
        let retryFrame = try #require(scene.scoutCardAttackHitFrameForTesting)
        scene.touchesEnded(
            [MockTouch(location: CGPoint(x: retryFrame.midX, y: retryFrame.midY))],
            with: nil
        )

        #expect(router.battleRequestCount == 2)
        #expect(countingStore.defaults.stateSaveCount == 2)
        #expect(store.load() == saved)
        #expect(!scene.isRoutingToBattleForTesting)
    }

    @Test func lockedCityNodeShowsExactFeedbackWithoutMutationOrRoute() throws {
        let initialState = KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        )
        let store = try makeStore(initialState: initialState)
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        let cityPoint = try #require(scene.cityNodePositionForTesting(3))

        scene.touchesEnded([MockTouch(location: cityPoint)], with: nil)

        #expect(store.load() == initialState)
        #expect(router.battleRequestCount == 0)
        #expect(scene.visibleFeedbackTextForTesting == "City 3 is locked")
        #expect(scene.feedbackRemainingDurationForTesting == 1.5)
    }

    @Test func completedCityNodeShowsExactFeedbackWithoutMutationOrRoute() throws {
        let initialState = KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 2,
            completedCityCount: 2,
            stageStatus: .cityConqueredPendingMap
        )
        let store = try makeStore(initialState: initialState)
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        let cityPoint = try #require(scene.cityNodePositionForTesting(2))

        scene.touchesEnded([MockTouch(location: cityPoint)], with: nil)

        #expect(store.load() == initialState)
        #expect(router.battleRequestCount == 0)
        #expect(scene.visibleFeedbackTextForTesting == "City 2 complete")
        #expect(scene.feedbackRemainingDurationForTesting == 1.5)
    }

    @Test func countryCompleteExposesNoAttackTarget() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityLevel: 15,
            cityRemainingPower: 0,
            cityNumberInCountry: 15,
            completedCityCount: 15,
            stageStatus: .countryComplete
        ))
        let scene = makeScene(store: store, router: RouteSpy())

        #expect(scene.scoutCardHitFrameForTesting != nil)
        #expect(scene.scoutCardAttackHitFrameForTesting == nil)
    }

    @Test func mapUnavailableGateConsumesTouchesBeforeEveryTarget() throws {
        let router = RouteSpy()
        let scene = makeScene(
            store: try makeStore(initialState: .init(
                cityRemainingPower: 0,
                completedCityCount: 1,
                stageStatus: .cityConqueredPendingMap
            )),
            router: router,
            imageLoader: { _ in nil }
        )

        scene.touchesEnded(
            [MockTouch(location: CGPoint(x: scene.size.width / 2, y: scene.size.height / 2))],
            with: nil
        )

        #expect(router.battleRequestCount == 0)
    }

    @Test func transientOverlayConsumesBeforeCardAndMapTargets() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        scene.enterCityForTesting(3)
        let overlayFrame = try #require(scene.scoutCardOverlayHitFrameForTesting)
        let overlayPoint = CGPoint(x: overlayFrame.midX, y: overlayFrame.midY)
        scene.enumerateChildNodes(withName: "//countryMapCity-2") { node, _ in
            node.position = overlayPoint
        }

        scene.touchesEnded([MockTouch(location: overlayPoint)], with: nil)

        #expect(router.battleRequestCount == 0)
        #expect(scene.visibleFeedbackTextForTesting == "City 3 is locked")
        #expect(scene.feedbackElapsedForTesting == 0)
    }

    @Test func attackConsumesBeforeOverlappingCurrentCityControl() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        let attackFrame = try #require(scene.scoutCardAttackHitFrameForTesting)
        let attackPoint = CGPoint(x: attackFrame.midX, y: attackFrame.midY)
        let currentControl = try #require(
            scene.childNode(withName: "countryMapCurrentCityButton")
        )
        currentControl.isHidden = false
        currentControl.position = attackPoint

        scene.touchesEnded([MockTouch(location: attackPoint)], with: nil)

        #expect(store.load().cityNumberInCountry == 2)
        #expect(router.battleRequestCount == 1)
    }

    @Test func cardBodyConsumesBeforeOverlappingCityNode() throws {
        let initialState = KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        )
        let store = try makeStore(initialState: initialState)
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        let cardFrame = try #require(scene.scoutCardHitFrameForTesting)
        let attackFrame = try #require(scene.scoutCardAttackHitFrameForTesting)
        let cardPoint = CGPoint(x: cardFrame.minX + 2, y: cardFrame.maxY - 2)
        #expect(!attackFrame.contains(cardPoint))
        scene.enumerateChildNodes(withName: "//countryMapCity-2") { node, _ in
            node.position = cardPoint
        }

        scene.touchesEnded([MockTouch(location: cardPoint)], with: nil)

        #expect(store.load() == initialState)
        #expect(router.battleRequestCount == 0)
    }

    @Test func currentControlConsumesBeforeOverlappingCompletedCityNode() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityLevel: 3,
            cityRemainingPower: 50,
            cityNumberInCountry: 3,
            completedCityCount: 2,
            stageStatus: .battleActive
        ))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)
        let currentPoint = try #require(scene.currentCityButtonPositionForTesting)
        scene.enumerateChildNodes(withName: "//countryMapCity-2") { node, _ in
            node.position = currentPoint
        }

        scene.touchesEnded([MockTouch(location: currentPoint)], with: nil)

        #expect(router.battleRequestCount == 1)
        #expect(scene.visibleFeedbackTextForTesting == nil)
    }

    @Test func testOnlyCurrentCityRequestUsesUnifiedCompletedResult() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 3,
            completedCityCount: 3,
            stageStatus: .cityConqueredPendingMap
        ))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        scene.requestCurrentCityBattleForTesting()

        #expect(router.battleRequestCount == 0)
        #expect(scene.visibleFeedbackTextForTesting == "City 3 complete")
        guard case .scout(let scout) = scene.projectedScoutCardContentForTesting else {
            Issue.record("Expected Scout Card content")
            return
        }
        #expect(scout.cityNumber == 4)
        #expect(scout.defenseTrait == .spikedGate)
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

        #expect(scene.visibleFeedbackTextForTesting == "Cannot enter city yet.")
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

    @Test func layoutGateSettlesThenExcludesMapGateOnlyTime() throws {
        let origin = Date(timeIntervalSinceReferenceDate: 1_000)
        let store = try makeStore(initialState: makeIdleAccruingState(since: origin))
        let scene = makeScene(store: store, router: nil)

        scene.layoutGateWillPause(at: origin.addingTimeInterval(10))
        #expect(scene.lastIdleProgressResultForTesting.elapsedSeconds == 10)

        scene.layoutGateWillPause(at: origin.addingTimeInterval(20))
        #expect(scene.lastIdleProgressResultForTesting.elapsedSeconds == 10)

        scene.layoutGateWillResume(at: origin.addingTimeInterval(30))
        scene.layoutGateWillResume(at: origin.addingTimeInterval(35))

        var resumed = store.load()
        #expect(resumed.lastBackgroundedAt == origin.addingTimeInterval(30))
        let postGate = resumed.returnFromBackground(
            at: origin.addingTimeInterval(40)
        )
        #expect(postGate.elapsedSeconds == 10)
    }

    @Test func realBackgroundNestedInsideMapGateCountsOnlySystemBackgroundTime() throws {
        let origin = Date(timeIntervalSinceReferenceDate: 2_000)
        let store = try makeStore(initialState: makeIdleAccruingState(since: origin))
        let scene = makeScene(store: store, router: nil)

        scene.layoutGateWillPause(at: origin.addingTimeInterval(10))
        scene.sceneDidEnterBackgroundForTesting(
            at: origin.addingTimeInterval(15)
        )
        scene.sceneWillEnterForegroundForTesting(
            at: origin.addingTimeInterval(25)
        )

        #expect(scene.lastIdleProgressResultForTesting.elapsedSeconds == 10)
        #expect(store.load().lastBackgroundedAt == nil)

        scene.layoutGateWillResume(at: origin.addingTimeInterval(30))
        #expect(store.load().lastBackgroundedAt
            == origin.addingTimeInterval(30))
    }

    @Test func backgroundThenMapGateResumeWhileBackgroundedPreservesEveryInterval() throws {
        let origin = Date(timeIntervalSinceReferenceDate: 5_000)
        let store = try makeStore(initialState: makeIdleAccruingState(since: origin))
        let scene = makeScene(store: store, router: nil)

        scene.sceneDidEnterBackgroundForTesting(
            at: origin.addingTimeInterval(10)
        )
        scene.layoutGateWillPause(at: origin.addingTimeInterval(15))

        #expect(scene.lastIdleProgressResultForTesting.elapsedSeconds == 15)
        #expect(store.load().lastBackgroundedAt
            == origin.addingTimeInterval(15))

        scene.layoutGateWillResume(at: origin.addingTimeInterval(20))
        #expect(store.load().lastBackgroundedAt
            == origin.addingTimeInterval(15))

        scene.sceneWillEnterForegroundForTesting(
            at: origin.addingTimeInterval(25)
        )

        #expect(scene.lastIdleProgressResultForTesting.elapsedSeconds == 10)
        #expect(store.load().lastBackgroundedAt
            == origin.addingTimeInterval(25))
    }

    @Test func mapGateThenBackgroundResumeWhileBackgroundedExcludesForegroundGateTime() throws {
        let origin = Date(timeIntervalSinceReferenceDate: 6_000)
        let store = try makeStore(initialState: makeIdleAccruingState(since: origin))
        let scene = makeScene(store: store, router: nil)

        scene.layoutGateWillPause(at: origin.addingTimeInterval(10))
        #expect(scene.lastIdleProgressResultForTesting.elapsedSeconds == 10)

        scene.sceneDidEnterBackgroundForTesting(
            at: origin.addingTimeInterval(15)
        )
        scene.layoutGateWillResume(at: origin.addingTimeInterval(20))

        #expect(store.load().lastBackgroundedAt
            == origin.addingTimeInterval(15))

        scene.sceneWillEnterForegroundForTesting(
            at: origin.addingTimeInterval(25)
        )

        #expect(scene.lastIdleProgressResultForTesting.elapsedSeconds == 10)
        #expect(store.load().lastBackgroundedAt
            == origin.addingTimeInterval(25))
    }

    private final class CountingUserDefaults: UserDefaults {
        private let countedKey: String
        private(set) var stateSaveCount = 0

        init?(suiteName: String, countedKey: String) {
            self.countedKey = countedKey
            super.init(suiteName: suiteName)
        }

        override func set(_ value: Any?, forKey defaultName: String) {
            if defaultName == countedKey {
                stateSaveCount += 1
            }
            super.set(value, forKey: defaultName)
        }

        func resetStateSaveCount() {
            stateSaveCount = 0
        }
    }

    private final class RouteSpy: CountryMapSceneRouting {
        var acceptsBattleRequest = true
        var onBattleRequest: ((Int) -> Void)?
        private(set) var battleRequestCount = 0
        private(set) var requestedGateReason: AppLayoutGateReason?

        func countryMapSceneDidRequestBattle(_ scene: CountryMapScene) -> Bool {
            battleRequestCount += 1
            onBattleRequest?(battleRequestCount)
            return acceptsBattleRequest
        }

        func countryMapScene(
            _ scene: CountryMapScene,
            didRequestLayoutGate reason: AppLayoutGateReason
        ) {
            requestedGateReason = reason
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
        ),
        imageLoader: ((String) -> UIImage?)? = nil
    ) -> CountryMapScene {
        let scene = CountryMapScene(
            size: size,
            store: store,
            router: router,
            layoutEnvironmentOverride: environment,
            imageLoaderOverride: imageLoader
        )
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        scene.didMove(to: view)
        return scene
    }

    private func makeIdleAccruingState(since date: Date) -> KingdomGameState {
        var state = KingdomGameState()
        state.cityBattleStates[state.currentCityKey.storageKey] = CityBattleState(
            slots: [1: CityBuilding(type: .barracks)],
            lastBuildingProgressResolvedAt: date
        )
        state.markCurrentCityBuildingProgressInactive(at: date)
        return state
    }

    private func makeStore(initialState: KingdomGameState) throws -> KingdomGameStore {
        let suiteName = "PyxisTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let store = KingdomGameStore(defaults: defaults, key: "state")
        store.save(initialState)
        return store
    }

    private func makeCountingStore(
        initialState: KingdomGameState
    ) throws -> (
        store: KingdomGameStore,
        defaults: CountingUserDefaults
    ) {
        let suiteName = "PyxisTests.Counting.\(UUID().uuidString)"
        let defaults = try #require(
            CountingUserDefaults(suiteName: suiteName, countedKey: "state")
        )
        defaults.removePersistentDomain(forName: suiteName)
        let store = KingdomGameStore(defaults: defaults, key: "state")
        store.save(initialState)
        defaults.resetStateSaveCount()
        return (store, defaults)
    }
}
