import CoreGraphics
import Testing
@testable import Pyxis

struct CountryMapLayoutTests {
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
        fixture: Fixture
    ) throws {
        let layout = try supportedLayout(
            size: fixture.size,
            insets: fixture.insets,
            layoutClass: fixture.layoutClass
        )

        #expect(layout.sceneFrame.contains(layout.titleControlRegionFrame))
        #expect(layout.sceneFrame.contains(layout.currentCityControlFrame))
        #expect(layout.titleControlRegionFrame.contains(layout.currentCityControlFrame))
        #expect(layout.sceneFrame.contains(layout.informationRegionFrame))
        #expect(layout.cityPositions.count == 15)
        #expect(layout.routes.count == 18)
        #expect(layout.displayedBackdropFrame.minX <= layout.sceneFrame.minX)
        #expect(layout.displayedBackdropFrame.maxX >= layout.sceneFrame.maxX)
        #expect(layout.displayedBackdropFrame.minY <= layout.sceneFrame.minY)
        #expect(layout.displayedBackdropFrame.maxY >= layout.sceneFrame.maxY)

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
            #expect(layout.illustratedMapRegionFrame.contains(route.strokeExpandedBounds))
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
        #expect(upright.informationRegionFrame.minY == 36)

        let upsideDown = try supportedLayout(
            size: CGSize(width: 834, height: 1194),
            insets: .init(top: 36, left: 11, bottom: 24, right: 7),
            layoutClass: .pad
        )
        #expect(upsideDown.titleControlRegionFrame.maxY == 1148)
        #expect(upsideDown.informationRegionFrame.minY == 24)
    }

    @Test func reviewedNarrowBoundaryRejects375By1194AndAccepts480By1194() {
        let insets = CountryMapSafeAreaInsets(top: 24, left: 0, bottom: 20, right: 0)
        #expect(result(
            size: .init(width: 375, height: 1194),
            insets: insets,
            layoutClass: .pad
        ) == .unsupported(.unsupportedGeometry))
        guard case .supported = result(
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

        #expect(layout.informationRegionFrame.height == 64)
        #expect(city1Frame.minY - layout.illustratedMapRegionFrame.minY >= 8)
    }

    @Test func horizontalSafeBoundsContainChromeOnSideInsetFixture() throws {
        // A supported layout with meaningful side insets must keep the title,
        // current-city control, and information region inside the horizontal
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
        #expect(layout.currentCityControlFrame.minX >= safeMinX)
        #expect(layout.currentCityControlFrame.maxX <= safeMaxX)
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
}

private struct Fixture: Sendable {
    let name: String
    let size: CGSize
    let insets: CountryMapSafeAreaInsets
    let layoutClass: CountryMapLayoutClass
}

private let supportedFixtures = [
    Fixture(
        name: "small phone",
        size: .init(width: 375, height: 667),
        insets: .zero,
        layoutClass: .phone
    ),
    Fixture(
        name: "iPhone 12/13 mini",
        size: .init(width: 375, height: 812),
        insets: .init(top: 50, left: 0, bottom: 34, right: 0),
        layoutClass: .phone
    ),
    Fixture(
        name: "modern phone",
        size: .init(width: 393, height: 852),
        insets: .init(top: 59, left: 0, bottom: 34, right: 0),
        layoutClass: .phone
    ),
    Fixture(
        name: "large phone",
        size: .init(width: 440, height: 956),
        insets: .init(top: 62, left: 0, bottom: 34, right: 0),
        layoutClass: .phone
    ),
    Fixture(
        name: "iPad mini",
        size: .init(width: 744, height: 1133),
        insets: .init(top: 24, left: 0, bottom: 20, right: 0),
        layoutClass: .pad
    ),
    Fixture(
        name: "11-inch iPad",
        size: .init(width: 834, height: 1194),
        insets: .init(top: 24, left: 0, bottom: 20, right: 0),
        layoutClass: .pad
    ),
    Fixture(
        name: "13-inch iPad",
        size: .init(width: 1032, height: 1376),
        insets: .init(top: 24, left: 0, bottom: 20, right: 0),
        layoutClass: .pad
    ),
    Fixture(
        name: "Stage Manager",
        size: .init(width: 600, height: 1008),
        insets: .init(top: 28, left: 0, bottom: 20, right: 0),
        layoutClass: .pad
    ),
    Fixture(
        name: "narrow iPad",
        size: .init(width: 480, height: 1194),
        insets: .init(top: 24, left: 0, bottom: 20, right: 0),
        layoutClass: .pad
    ),
    Fixture(
        name: "iPad with side insets",
        size: .init(width: 834, height: 1194),
        insets: .init(top: 24, left: 50, bottom: 20, right: 50),
        layoutClass: .pad
    )
]

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
    ),
    Fixture(
        name: "over-cropped narrow iPad",
        size: .init(width: 375, height: 1194),
        insets: .init(top: 24, left: 0, bottom: 20, right: 0),
        layoutClass: .pad
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
