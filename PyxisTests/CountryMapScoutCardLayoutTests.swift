import CoreGraphics
import Testing
@testable import Pyxis

struct CountryMapScoutCardLayoutTests {
    @Test func referencePhoneMatchesAuthoredForgedCardGeometry() throws {
        let fixture = try #require(CountryMapLayoutTestFixtures.supported.first {
            $0.name == "modern phone"
        })
        let (outerLayout, layout) = try scoutCardLayout(for: fixture)

        // HPA-812: the ordinary-phone card is contained by the information
        // region like the compact strip and pad card; it no longer expands
        // into the illustrated map.
        #expect(outerLayout.informationRegionFrame == CGRect(
            x: 16,
            y: 114,
            width: 361,
            height: 164
        ))
        #expect(layout.cardFrame == outerLayout.informationRegionFrame)
        #expect(layout.attackFrame == CGRect(x: 30, y: 127, width: 333, height: 46))
        #expect(!layout.nonBlockingOverlayFrame.intersects(layout.attackFrame))

        // The first cities' hit frames stay clear of the card and overlay.
        for cityNumber in [1, 2] {
            let position = try #require(outerLayout.cityPositions[cityNumber])
            let hitFrame = CGRect(
                x: position.x - 22,
                y: position.y - 22,
                width: 44,
                height: 44
            )
            #expect(!hitFrame.intersects(layout.cardFrame))
            #expect(!hitFrame.intersects(layout.nonBlockingOverlayFrame))
        }
    }

    @Test(arguments: CountryMapLayoutTestFixtures.supported.filter(isPhoneFixture))
    func phoneCardsStayInsideTheInformationRegionOnEveryPhoneFixture(
        fixture: CountryMapLayoutTestFixture
    ) throws {
        let (outerLayout, cardLayout) = try scoutCardLayout(for: fixture)

        #expect(cardLayout.cardFrame == outerLayout.informationRegionFrame)
        #expect(outerLayout.informationRegionFrame.contains(cardLayout.cardFrame))
        // No city hit frame can sit under the card or its non-blocking
        // overlay on any supported phone fixture.
        for position in outerLayout.cityPositions.values {
            let hitFrame = CGRect(
                x: position.x - 22,
                y: position.y - 22,
                width: 44,
                height: 44
            )
            #expect(!hitFrame.intersects(cardLayout.cardFrame))
            #expect(!hitFrame.intersects(cardLayout.nonBlockingOverlayFrame))
        }
    }

    @Test func compactPhoneCardKeepsIdentityAndPrimaryActionHorizontal() {
        let region = CGRect(x: 16, y: 34, width: 343, height: 48)
        let layout = CountryMapScoutCardLayout.compute(in: region, layoutClass: .phone)

        #expect(layout.isCompact)
        #expect(layout.cardFrame == region)
        #expect(layout.attackFrame.width >= 44)
        #expect(layout.attackFrame.height >= 44)
        #expect(region.contains(layout.attackFrame))
        #expect(region.contains(layout.badgeFrame))
        #expect(region.contains(layout.titleFrame))
        #expect(layout.titleFrame.maxX <= layout.attackFrame.minX)
        #expect(layout.nonBlockingOverlayFrame.maxX == layout.attackFrame.minX)
        #expect(!layout.nonBlockingOverlayFrame.intersects(layout.attackFrame))
    }

    @Test(arguments: CountryMapLayoutTestFixtures.supported)
    func supportedLayoutsKeepScoutCardFramesInsideCardAndScene(
        fixture: CountryMapLayoutTestFixture
    ) throws {
        let (outerLayout, cardLayout) = try scoutCardLayout(for: fixture)

        #expect(cardLayout.overlayFrame == cardLayout.cardFrame)
        #expect(outerLayout.sceneFrame.contains(cardLayout.cardFrame))
        // Every layout class (compact phone, ordinary phone, pad) keeps the
        // card inside the information region (HPA-812).
        #expect(outerLayout.informationRegionFrame.contains(cardLayout.cardFrame))

        // The non-blocking flavor overlay spans the informational area plus
        // the Attack gap but stops at the Attack frame's leading edge, so it
        // never intersects the Attack target (edge-touching rects report
        // `intersects == false` in Core Graphics).
        #expect(cardLayout.nonBlockingOverlayFrame.minX == cardLayout.cardFrame.minX)
        if case .phone = cardLayout.layoutClass, !cardLayout.isCompact {
            #expect(cardLayout.nonBlockingOverlayFrame.maxX == cardLayout.cardFrame.maxX)
            #expect(cardLayout.nonBlockingOverlayFrame.minY == cardLayout.attackFrame.maxY)
            #expect(cardLayout.nonBlockingOverlayFrame.maxY == cardLayout.cardFrame.maxY)
        } else {
            #expect(cardLayout.nonBlockingOverlayFrame.maxX == cardLayout.attackFrame.minX)
            #expect(cardLayout.nonBlockingOverlayFrame.minY == cardLayout.cardFrame.minY)
            #expect(cardLayout.nonBlockingOverlayFrame.height == cardLayout.cardFrame.height)
        }
        #expect(cardLayout.overlayFrame.contains(cardLayout.nonBlockingOverlayFrame))
        #expect(!cardLayout.nonBlockingOverlayFrame.intersects(cardLayout.attackFrame))

        let allFrames = [
            cardLayout.cardFrame,
            cardLayout.badgeFrame,
            cardLayout.titleFrame,
            cardLayout.goldIconFrame,
            cardLayout.rewardFrame,
            cardLayout.favorableFrame,
            cardLayout.disadvantagedFrame,
            cardLayout.exposedLaneFrame,
            cardLayout.attackFrame,
            cardLayout.overlayFrame
        ] + cardLayout.traitLineFrames
        for frame in allFrames {
            #expect(cardLayout.cardFrame.contains(frame))
        }

        #expect(cardLayout.attackFrame.width >= 44)
        #expect(cardLayout.attackFrame.height >= 44)

        let informationalFrames = [
            cardLayout.badgeFrame,
            cardLayout.titleFrame,
            cardLayout.goldIconFrame,
            cardLayout.rewardFrame,
            cardLayout.favorableFrame,
            cardLayout.disadvantagedFrame,
            cardLayout.exposedLaneFrame
        ] + cardLayout.traitLineFrames
        for frame in informationalFrames {
            #expect(!frame.intersects(cardLayout.attackFrame))
        }
    }

    @Test(arguments: CountryMapLayoutTestFixtures.supported.filter {
        isPhoneFixture($0) && $0.name != "small phone"
    })
    func phoneLayoutsUseLockedRowsFooterGroupsAndTitleGaps(
        fixture: CountryMapLayoutTestFixture
    ) throws {
        let (_, cardLayout) = try scoutCardLayout(for: fixture)
        let roomy = cardLayout.cardFrame.height >= 150
        let contentX = cardLayout.cardFrame.minX + 14
        let contentMaxX = cardLayout.cardFrame.maxX - 14
        let rowGap: CGFloat = roomy ? 3 : 2
        #expect(cardLayout.traitLineFrames.count == 2)
        let topTraitLine = try #require(cardLayout.traitLineFrames.first)
        let bottomTraitLine = try #require(cardLayout.traitLineFrames.last)

        // Header row: badge left, gold icon + reward right.
        #expect(cardLayout.badgeFrame.size == CGSize(width: 80, height: 10))
        #expect(cardLayout.badgeFrame.minX == cardLayout.titleFrame.minX)
        #expect(cardLayout.goldIconFrame.size == CGSize(width: 15, height: 15))
        #expect(cardLayout.rewardFrame.width == 39)
        #expect(cardLayout.rewardFrame.maxX == contentMaxX)
        #expect(cardLayout.rewardFrame.minY >= cardLayout.titleFrame.maxY)
        #expect(cardLayout.goldIconFrame.midY == cardLayout.rewardFrame.midY)
        // Title row: title + right-aligned measured lane footer.
        #expect(cardLayout.exposedLaneFrame.width == 115)
        #expect(cardLayout.exposedLaneFrame.maxX == contentMaxX)
        #expect(cardLayout.exposedLaneFrame.minY == cardLayout.titleFrame.minY)
        #expect(cardLayout.titleFrame.maxX == cardLayout.exposedLaneFrame.minX - 8)
        // Trait rows share one leading edge and stay contiguous.
        #expect(topTraitLine.height == (roomy ? 12 : 10))
        #expect(bottomTraitLine.height == topTraitLine.height)
        #expect(topTraitLine.minX == bottomTraitLine.minX)
        #expect(bottomTraitLine.maxY == topTraitLine.minY)
        #expect(cardLayout.titleFrame.minY == topTraitLine.maxY + rowGap)
        // The footer splits into equal favorable/disadvantaged halves.
        #expect(cardLayout.favorableFrame.minX == contentX)
        #expect(cardLayout.disadvantagedFrame.maxX == contentMaxX)
        #expect(cardLayout.favorableFrame.width == cardLayout.disadvantagedFrame.width)
        #expect(cardLayout.favorableFrame.minY == cardLayout.disadvantagedFrame.minY)
        #expect(bottomTraitLine.minY == cardLayout.favorableFrame.maxY + rowGap)
        // The full-width action anchors the card with >=44pt height.
        #expect(cardLayout.attackFrame.minX == contentX)
        #expect(cardLayout.attackFrame.width == contentMaxX - contentX)
        #expect(cardLayout.attackFrame.height == (roomy ? 46 : 44))
        #expect(cardLayout.attackFrame.minY >= cardLayout.cardFrame.minY + 3)
        #expect(cardLayout.favorableFrame.minY == cardLayout.attackFrame.maxY + rowGap)
        #expect(cardLayout.nonBlockingOverlayFrame.minY == cardLayout.attackFrame.maxY)
    }

    @Test(arguments: CountryMapLayoutTestFixtures.supported.filter(isPadFixture))
    func padLayoutsUseLockedRowsFooterLinesAndTitleGaps(
        fixture: CountryMapLayoutTestFixture
    ) throws {
        let (outerLayout, cardLayout) = try scoutCardLayout(for: fixture)
        let contentFrame = outerLayout.informationRegionFrame.insetBy(dx: 12, dy: 8)
        #expect(cardLayout.traitLineFrames.count == 2)
        let topTraitLine = try #require(cardLayout.traitLineFrames.first)
        let bottomTraitLine = try #require(cardLayout.traitLineFrames.last)

        #expect(cardLayout.badgeFrame.size == CGSize(width: 32, height: 32))
        #expect(cardLayout.goldIconFrame.size == CGSize(width: 18, height: 18))
        #expect(cardLayout.rewardFrame.size == CGSize(width: 48, height: 32))
        #expect(cardLayout.rewardFrame.minX - cardLayout.goldIconFrame.maxX == 4)
        #expect(topTraitLine.height == 14)
        #expect(bottomTraitLine.height == 14)
        #expect(cardLayout.badgeFrame.maxY == contentFrame.maxY)
        #expect(topTraitLine.maxY == cardLayout.badgeFrame.minY - 4)
        #expect(bottomTraitLine.maxY == topTraitLine.minY)
        #expect(cardLayout.favorableFrame.height == 14)
        #expect(cardLayout.favorableFrame.maxY == bottomTraitLine.minY - 4)
        #expect(cardLayout.disadvantagedFrame.height == 14)
        #expect(cardLayout.disadvantagedFrame.maxY == cardLayout.favorableFrame.minY)
        #expect(cardLayout.exposedLaneFrame.minY == cardLayout.disadvantagedFrame.minY)
        #expect(cardLayout.exposedLaneFrame.maxY == cardLayout.disadvantagedFrame.maxY)
        #expect(cardLayout.exposedLaneFrame.width == 82)
        #expect(
            cardLayout.exposedLaneFrame.minX
                - cardLayout.disadvantagedFrame.maxX == 12
        )
        #expect(cardLayout.attackFrame.size == CGSize(width: 96, height: 52))
        #expect(cardLayout.attackFrame.maxX == contentFrame.maxX)
        #expect(cardLayout.attackFrame.midY == outerLayout.informationRegionFrame.midY)
        #expect(cardLayout.disadvantagedFrame.minY >= outerLayout.informationRegionFrame.minY + 8)
        #expect(cardLayout.titleFrame.minX == cardLayout.badgeFrame.maxX + 8)
        #expect(cardLayout.titleFrame.maxX == cardLayout.goldIconFrame.minX - 8)
    }

    @Test func minimumLayoutsLockExpectedFooterAndAttackArithmetic() throws {
        let phoneFixture = try #require(CountryMapLayoutTestFixtures.supported.first {
            $0.name == "iPhone 12/13 mini"
        })
        let narrowPadFixture = try #require(CountryMapLayoutTestFixtures.supported.first {
            $0.name == "narrow iPad"
        })
        let (_, phoneLayout) = try scoutCardLayout(for: phoneFixture)
        let (_, narrowPadLayout) = try scoutCardLayout(for: narrowPadFixture)

        #expect(phoneLayout.favorableFrame.width == 153)
        #expect(phoneLayout.disadvantagedFrame.width == 153)
        #expect(phoneLayout.exposedLaneFrame.width == 115)
        #expect(phoneLayout.attackFrame.size == CGSize(width: 315, height: 44))

        #expect(narrowPadLayout.exposedLaneFrame.width == 82)
        #expect(narrowPadLayout.attackFrame.size == CGSize(width: 96, height: 52))
        #expect(
            narrowPadLayout.exposedLaneFrame.minX
                - narrowPadLayout.disadvantagedFrame.maxX == 12
        )
    }

    @Test func computeIsDeterministicForFixedInformationRegion() {
        let informationRegion = CGRect(x: 16, y: 20, width: 343, height: 64)
        let first = CountryMapScoutCardLayout.compute(in: informationRegion, layoutClass: .phone)
        let second = CountryMapScoutCardLayout.compute(in: informationRegion, layoutClass: .phone)

        #expect(first.cardFrame == second.cardFrame)
        #expect(first.badgeFrame == second.badgeFrame)
        #expect(first.titleFrame == second.titleFrame)
        #expect(first.goldIconFrame == second.goldIconFrame)
        #expect(first.rewardFrame == second.rewardFrame)
        #expect(first.traitLineFrames == second.traitLineFrames)
        #expect(first.favorableFrame == second.favorableFrame)
        #expect(first.disadvantagedFrame == second.disadvantagedFrame)
        #expect(first.exposedLaneFrame == second.exposedLaneFrame)
        #expect(first.attackFrame == second.attackFrame)
        #expect(first.overlayFrame == second.overlayFrame)
        #expect(first.nonBlockingOverlayFrame == second.nonBlockingOverlayFrame)
    }
}

private func scoutCardLayout(
    for fixture: CountryMapLayoutTestFixture
) throws -> (CountryMapLayout, CountryMapScoutCardLayout) {
    let outerResult = CountryMapLayout.compute(.init(
        sceneSize: fixture.size,
        environment: .init(safeAreaInsets: fixture.insets, layoutClass: fixture.layoutClass),
        definition: .country1
    ))
    guard case .supported(let outerLayout) = outerResult else {
        Issue.record("Expected supported outer layout for \(fixture.name)")
        throw ScoutCardLayoutTestError.unsupportedFixture
    }
    return (
        outerLayout,
        CountryMapScoutCardLayout.compute(
            in: outerLayout.informationRegionFrame,
            layoutClass: fixture.layoutClass
        )
    )
}

private enum ScoutCardLayoutTestError: Error {
    case unsupportedFixture
}

private func isPhoneFixture(_ fixture: CountryMapLayoutTestFixture) -> Bool {
    if case .phone = fixture.layoutClass {
        return true
    }
    return false
}

private func isPadFixture(_ fixture: CountryMapLayoutTestFixture) -> Bool {
    if case .pad = fixture.layoutClass {
        return true
    }
    return false
}
