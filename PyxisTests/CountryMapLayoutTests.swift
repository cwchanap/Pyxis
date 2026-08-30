import CoreGraphics
import Testing
@testable import Pyxis

struct CountryMapLayoutTests {
    @Test func computedPhoneBudgetUsesCompactFloorAndMinimumIllustratedHeight() throws {
        let small = try supportedLayout(
            size: CGSize(width: 375, height: 667),
            insets: .zero,
            layoutClass: .phone
        )
        let mini = try supportedLayout(
            size: CGSize(width: 375, height: 812),
            insets: .init(top: 50, left: 0, bottom: 34, right: 0),
            layoutClass: .phone
        )
        let reference = try supportedLayout(
            size: CGSize(width: 393, height: 852),
            insets: .init(top: 59, left: 0, bottom: 34, right: 0),
            layoutClass: .phone
        )

        #expect(small.informationRegionFrame.height == 48)
        #expect(small.illustratedMapRegionFrame.height == 431)
        #expect(mini.informationRegionFrame.height == 133)
        #expect(mini.illustratedMapRegionFrame.height == 431)
        #expect(reference.informationRegionFrame.height == 164)
        #expect(reference.illustratedMapRegionFrame.height == 431)
    }

    @Test func computedPadBudgetKeepsPreferredCardWhenSpaceAllows() throws {
        let layout = try supportedLayout(
            size: CGSize(width: 834, height: 1194),
            insets: .init(top: 24, left: 0, bottom: 20, right: 0),
            layoutClass: .pad
        )

        #expect(layout.informationRegionFrame.height == 140)
        #expect(layout.illustratedMapRegionFrame.height >= 431)
    }

    @Test func budgetBelowCompactFloorFailsClosed() {
        #expect(result(
            size: CGSize(width: 375, height: 650),
            insets: .zero,
            layoutClass: .phone
        ) == .unsupported(.unsupportedGeometry))
    }

    @Test func referenceTransformPinsCitySpacingAndInteractionHeadroom() throws {
        let layout = try supportedLayout(
            size: CGSize(width: 393, height: 852),
            insets: .init(top: 59, left: 0, bottom: 34, right: 0),
            layoutClass: .phone
        )

        var minimumCenterDistance = CGFloat.greatestFiniteMagnitude
        let positions = CountryMapLayoutDefinition.country1.cityAnchors.indices.map {
            layout.cityPositions[$0 + 1]!
        }
        for index in positions.indices {
            for otherIndex in positions.indices.dropFirst(index + 1) {
                minimumCenterDistance = min(
                    minimumCenterDistance,
                    hypot(
                        positions[index].x - positions[otherIndex].x,
                        positions[index].y - positions[otherIndex].y
                    )
                )
            }
        }

        var minimumCityHeadroom = CGFloat.greatestFiniteMagnitude
        for position in positions {
            let frame = CGRect(x: position.x - 22, y: position.y - 22, width: 44, height: 44)
            minimumCityHeadroom = min(
                minimumCityHeadroom,
                frame.minY - layout.illustratedMapRegionFrame.minY,
                frame.maxY <= layout.illustratedMapRegionFrame.maxY
                    ? layout.illustratedMapRegionFrame.maxY - frame.maxY
                    : -.greatestFiniteMagnitude
            )
        }
        let minimumRouteHeadroom = layout.routes.reduce(CGFloat.greatestFiniteMagnitude) { current, route in
            let bounds = route.strokeExpandedBounds
            return min(
                current,
                bounds.minY - layout.illustratedMapRegionFrame.minY,
                layout.illustratedMapRegionFrame.maxY - bounds.maxY
            )
        }

        #expect(layout.illustratedMapRegionFrame.height == 431)
        #expect(minimumCenterDistance >= 45)
        #expect(minimumCityHeadroom >= 8)
        #expect(minimumRouteHeadroom >= 27)
        #expect(layout.cityPositions.count == 15)
        #expect(layout.routes.count == 18)
    }

    @Test(arguments: supportedFixtures)
    private func titleControlsReserveGearWithoutOverlap(
        fixture: CountryMapLayoutTestFixture
    ) throws {
        let layout = try supportedLayout(
            size: fixture.size,
            insets: fixture.insets,
            layoutClass: fixture.layoutClass
        )

        #expect(layout.settingsControlFrame.size == CGSize(width: 44, height: 44))
        #expect(layout.titleTextFrame.width >= 160)
        #expect(!layout.settingsControlFrame.intersects(layout.titleTextFrame))
        #expect(layout.titleControlRegionFrame.contains(layout.resourceFrame))
        #expect(layout.titleControlRegionFrame.contains(layout.progressFrame))
        #expect(!layout.resourceFrame.intersects(layout.titleTextFrame))
        #expect(!layout.resourceFrame.intersects(layout.settingsControlFrame))
        #expect(!layout.progressFrame.intersects(layout.settingsControlFrame))
        #expect(layout.titleTextFrame.maxX == layout.settingsControlFrame.minX - 8)
    }

    @Test func referenceHeaderChromeDoesNotOverlap() throws {
        let layout = try supportedLayout(
            size: CGSize(width: 393, height: 852),
            insets: CountryMapSafeAreaInsets(top: 59, left: 0, bottom: 34, right: 0),
            layoutClass: .phone
        )

        #expect(layout.resourceFrame == CGRect(x: 28, y: 739, width: 106, height: 44))
        #expect(layout.titleTextFrame == CGRect(x: 30, y: 717, width: 281, height: 22))
        #expect(layout.progressFrame == CGRect(x: 160, y: 717, width: 149, height: 22))
        #expect(layout.settingsControlFrame == CGRect(x: 319, y: 739, width: 44, height: 44))
        #expect(!layout.resourceFrame.intersects(layout.titleTextFrame))
        #expect(!layout.resourceFrame.intersects(layout.progressFrame))
        #expect(!layout.resourceFrame.intersects(layout.settingsControlFrame))
        #expect(!layout.titleTextFrame.intersects(layout.settingsControlFrame))
        #expect(!layout.progressFrame.intersects(layout.settingsControlFrame))
        #expect(layout.titleControlRegionFrame.contains(layout.resourceFrame))
        #expect(layout.titleControlRegionFrame.contains(layout.progressFrame))
        #expect(layout.titleControlRegionFrame.contains(layout.settingsControlFrame))
    }

    @Test func titleControlsUseTheReviewed375PointGeometry() throws {
        let layout = try supportedLayout(
            size: CGSize(width: 375, height: 667),
            insets: .zero,
            layoutClass: .phone
        )

        #expect(layout.settingsControlFrame == CGRect(x: 301, y: 589, width: 44, height: 44))
        #expect(layout.titleTextFrame == CGRect(x: 30, y: 567, width: 263, height: 22))
    }

    @Test func country1DefinitionMatchesCampaignAndRouteContract() {
        let definition = CountryMapLayoutDefinition.country1

        #expect(definition.canonicalBackdropSize == CGSize(width: 1024, height: 1536))
        #expect(definition.cityAnchors.count == KingdomGameState.firstCountryCityCount)
        #expect(definition.primaryRoutes.count == 14)
        #expect(definition.branches.map(\.originCityNumber) == [3, 6, 9, 12])
    }

    @Test func malformedDefinitionFailsWithoutPartialGeometry() {
        let source = CountryMapLayoutDefinition.country1
        let malformed = CountryMapLayoutDefinition(
            canonicalBackdropSize: source.canonicalBackdropSize,
            cityAnchors: Array(source.cityAnchors.dropLast()),
            primaryRoutes: source.primaryRoutes,
            branches: source.branches
        )
        let result = CountryMapLayout.compute(.init(
            sceneSize: CGSize(width: 393, height: 852),
            environment: .init(
                safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0),
                layoutClass: .phone
            ),
            definition: malformed
        ))

        #expect(result == .unsupported(.invalidAuthoredData))
    }

    @Test(arguments: supportedFixtures)
    private func supportedFixturesSatisfyCompleteLayoutInvariants(
        fixture: CountryMapLayoutTestFixture
    ) throws {
        let layout = try supportedLayout(
            size: fixture.size,
            insets: fixture.insets,
            layoutClass: fixture.layoutClass
        )

        #expect(layout.sceneFrame.contains(layout.titleControlRegionFrame))
        #expect(layout.sceneFrame.contains(layout.settingsControlFrame))
        #expect(layout.sceneFrame.contains(layout.informationRegionFrame))
        #expect(layout.cityPositions.count == 15)
        #expect(layout.routes.count == 18)
        #expect(layout.displayedBackdropFrame.minX <= layout.sceneFrame.minX)
        #expect(layout.displayedBackdropFrame.maxX >= layout.sceneFrame.maxX)

        let safeContentMinX = layout.sceneFrame.minX + fixture.insets.left
        let safeContentMaxX = layout.sceneFrame.maxX - fixture.insets.right

        var minimumCityHeadroom = CGFloat.greatestFiniteMagnitude
        for (index, anchor) in CountryMapLayoutDefinition.country1.cityAnchors.enumerated() {
            let cityNumber = index + 1
            let position = try #require(layout.cityPositions[cityNumber])
            let expected = CGPoint(
                x: layout.displayedBackdropFrame.minX + anchor.x * layout.displayedBackdropFrame.width,
                y: layout.displayedBackdropFrame.minY + anchor.y * layout.displayedBackdropFrame.height
            )
            #expect(abs(position.x - expected.x) <= 1)
            #expect(abs(position.y - expected.y) <= 1)

            let cityFrame = CGRect(
                x: position.x - 22,
                y: position.y - 22,
                width: 44,
                height: 44
            )
            #expect(layout.illustratedMapRegionFrame.contains(cityFrame))
            // Interactive city targets must stay clear of horizontal system
            // chrome (Stage Manager / split-view side insets), not just the
            // full-width illustrated region.
            #expect(cityFrame.minX >= safeContentMinX)
            #expect(cityFrame.maxX <= safeContentMaxX)
            let headroom = [
                cityFrame.minX - layout.illustratedMapRegionFrame.minX,
                layout.illustratedMapRegionFrame.maxX - cityFrame.maxX,
                cityFrame.minY - layout.illustratedMapRegionFrame.minY,
                layout.illustratedMapRegionFrame.maxY - cityFrame.maxY
            ].min() ?? -.greatestFiniteMagnitude
            minimumCityHeadroom = min(minimumCityHeadroom, headroom)
        }
        #expect(minimumCityHeadroom >= 8)

        for route in layout.routes {
            let bounds = route.strokeExpandedBounds
            #expect(layout.illustratedMapRegionFrame.contains(bounds))
            #expect(bounds.minX >= safeContentMinX)
            #expect(bounds.maxX <= safeContentMaxX)
        }
    }

    @Test(arguments: unsupportedFixtures) private func unsupportedFixturesHaveNoLayoutPayload(fixture: Fixture) {
        #expect(result(
            size: fixture.size,
            insets: fixture.insets,
            layoutClass: fixture.layoutClass
        ) == .unsupported(.unsupportedGeometry))
    }

    @Test func largeWidthAtLeastHeightIsRejectedIndependentOfAuthoredPlacement() {
        let source = CountryMapLayoutDefinition.country1
        let centeredDefinition = CountryMapLayoutDefinition(
            canonicalBackdropSize: source.canonicalBackdropSize,
            cityAnchors: Array(repeating: CGPoint(x: 0.5, y: 0.5), count: 15),
            primaryRoutes: source.primaryRoutes,
            branches: source.branches
        )

        #expect(CountryMapLayout.compute(.init(
            sceneSize: CGSize(width: 2_000, height: 1_000),
            environment: .init(safeAreaInsets: .zero, layoutClass: .phone),
            definition: centeredDefinition
        )) == .unsupported(.unsupportedGeometry))
    }

    @Test func semanticInsetsAreNotSwappedOrSynthesized() throws {
        let upright = try supportedLayout(
            size: CGSize(width: 834, height: 1194),
            insets: .init(top: 24, left: 7, bottom: 36, right: 11),
            layoutClass: .pad
        )
        #expect(upright.titleControlRegionFrame.maxY == 1160)
        #expect(upright.informationRegionFrame.minY == 116)

        let upsideDown = try supportedLayout(
            size: CGSize(width: 834, height: 1194),
            insets: .init(top: 36, left: 11, bottom: 24, right: 7),
            layoutClass: .pad
        )
        #expect(upsideDown.titleControlRegionFrame.maxY == 1148)
        #expect(upsideDown.informationRegionFrame.minY == 104)
    }

    @Test func reviewedNarrowPortraitPadKeepsAuthoredTargetsContained() {
        let insets = CountryMapSafeAreaInsets(top: 24, left: 0, bottom: 20, right: 0)
        guard case .supported = result(
            size: .init(width: 375, height: 1194),
            insets: insets,
            layoutClass: .pad
        ), case .supported = result(
            size: .init(width: 480, height: 1194),
            insets: insets,
            layoutClass: .pad
        ) else {
            Issue.record("480×1194 must satisfy the complete invariant set")
            return
        }
    }

    @Test func iPhoneMiniRetainsEightPointsOfFixtureHeadroom() throws {
        let layout = try supportedLayout(
            size: CGSize(width: 375, height: 812),
            insets: .init(top: 50, left: 0, bottom: 34, right: 0),
            layoutClass: .phone
        )
        let city1 = try #require(layout.cityPositions[1])
        let city1Frame = CGRect(
            x: city1.x - 22,
            y: city1.y - 22,
            width: 44,
            height: 44
        )

        #expect(layout.informationRegionFrame.height == 133)
        #expect(city1Frame.minY - layout.illustratedMapRegionFrame.minY >= 8)
    }

    @Test func horizontalSafeBoundsContainChromeOnSideInsetFixture() throws {
        // A supported layout with meaningful side insets must keep the title,
        // information region inside the horizontal
        // safe-content rect (scene frame inset by left/right).
        let layout = try supportedLayout(
            size: CGSize(width: 834, height: 1194),
            insets: .init(top: 24, left: 50, bottom: 20, right: 50),
            layoutClass: .pad
        )
        let safeMinX = layout.sceneFrame.minX + 50
        let safeMaxX = layout.sceneFrame.maxX - 50

        #expect(layout.titleControlRegionFrame.minX >= safeMinX)
        #expect(layout.titleControlRegionFrame.maxX <= safeMaxX)
        #expect(layout.settingsControlFrame.minX >= safeMinX)
        #expect(layout.settingsControlFrame.maxX <= safeMaxX)
        #expect(layout.informationRegionFrame.minX >= safeMinX)
        #expect(layout.informationRegionFrame.maxX <= safeMaxX)
    }

    @Test func sideInsetsThatPushChromeBeyondSafeBoundsAreRejected() {
        // The narrow iPad (480×1194) is supported with zero side insets, but
        // side insets large enough to push the centered title or information
        // region into horizontally unsafe content must fail closed.
        let insets = CountryMapSafeAreaInsets(top: 24, left: 80, bottom: 20, right: 80)
        #expect(result(
            size: .init(width: 480, height: 1194),
            insets: insets,
            layoutClass: .pad
        ) == .unsupported(.unsupportedGeometry))
    }

    @Test func sideInsetsThatKeepCityInteractionFramesInsideSafeBoundsAreAccepted() {
        // The authored transform remains horizontally centred while preserving
        // its aspect ratio. This fixture's targets fit inside the 16pt side
        // safe-area inset and should therefore remain renderable.
        let insets = CountryMapSafeAreaInsets(top: 24, left: 16, bottom: 20, right: 16)
        guard case .supported = result(
            size: .init(width: 375, height: 956),
            insets: insets,
            layoutClass: .pad
        ) else {
            Issue.record("375×956 with 16pt side insets should contain all map targets")
            return
        }
    }
}

private struct Fixture: Sendable {
    let name: String
    let size: CGSize
    let insets: CountryMapSafeAreaInsets
    let layoutClass: CountryMapLayoutClass
}

private let supportedFixtures = CountryMapLayoutTestFixtures.supported

private let unsupportedFixtures = [
    Fixture(
        name: "phone landscape",
        size: .init(width: 667, height: 375),
        insets: .zero,
        layoutClass: .phone
    ),
    Fixture(
        name: "iPad landscape",
        size: .init(width: 1194, height: 834),
        insets: .init(top: 24, left: 0, bottom: 20, right: 0),
        layoutClass: .pad
    ),
    Fixture(
        name: "wide split",
        size: .init(width: 678, height: 834),
        insets: .init(top: 24, left: 0, bottom: 20, right: 0),
        layoutClass: .pad
    ),
    Fixture(
        name: "wide iPad",
        size: .init(width: 1024, height: 768),
        insets: .init(top: 24, left: 0, bottom: 20, right: 0),
        layoutClass: .pad
    ),
    Fixture(
        name: "square",
        size: .init(width: 700, height: 700),
        insets: .init(top: 24, left: 0, bottom: 20, right: 0),
        layoutClass: .pad
    ),
    Fixture(
        name: "undersized",
        size: .init(width: 320, height: 568),
        insets: .zero,
        layoutClass: .phone
    )
]

private func result(
    size: CGSize,
    insets: CountryMapSafeAreaInsets = .zero,
    layoutClass: CountryMapLayoutClass
) -> CountryMapLayoutResult {
    CountryMapLayout.compute(.init(
        sceneSize: size,
        environment: .init(safeAreaInsets: insets, layoutClass: layoutClass),
        definition: .country1
    ))
}

private func supportedLayout(
    size: CGSize,
    insets: CountryMapSafeAreaInsets,
    layoutClass: CountryMapLayoutClass
) throws -> CountryMapLayout {
    var supported: CountryMapLayout?
    if case .supported(let layout) = result(
        size: size,
        insets: insets,
        layoutClass: layoutClass
    ) {
        supported = layout
    }
    return try #require(supported)
}
