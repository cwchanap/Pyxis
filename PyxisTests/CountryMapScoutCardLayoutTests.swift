import CoreGraphics
import Testing
@testable import Pyxis

struct CountryMapScoutCardLayoutTests {
    @Test(arguments: [48.01, 48.5, 49.0, 50.0, 51.0, 52.0, 53.0, 53.99, 54.0])
    func narrowPhoneRowsStayInsideCardAndSeparate(height: Double) {
        let region = CGRect(x: 16, y: 80, width: 343, height: height)
        let card = CountryMapScoutCardLayout.compute(in: region, layoutClass: .phone)
        let frames = [card.badgeFrame, card.titleFrame, card.goldIconFrame, card.rewardFrame,
                      card.favorableFrame, card.disadvantagedFrame, card.exposedLaneFrame,
                      card.attackFrame] + card.traitLineFrames
        #expect(card.cardFrame == region)
        #expect(card.attackFrame.width >= 44)
        #expect(card.attackFrame.height >= 44)
        #expect(!card.nonBlockingOverlayFrame.intersects(card.attackFrame))
        for index in frames.indices {
            #expect(region.contains(frames[index]))
            for other in frames.indices.dropFirst(index + 1) {
                #expect(!frames[index].intersects(frames[other]), "height \(height): \(index) / \(other)")
            }
        }
    }

    @Test func intermediatePhoneHeightKeepsRequiredFramesSeparate() throws {
        let fixture = CountryMapLayoutTestFixture(
            name: "intermediate phone", size: CGSize(width: 375, height: 700),
            insets: .zero, layoutClass: .phone
        )
        let (outer, card) = try scoutCardLayout(for: fixture)
        #expect(outer.informationRegionFrame.height > 48)
        #expect(outer.informationRegionFrame.height < 133)
        #expect(card.cardFrame.contains(card.attackFrame))
        let frames = [card.badgeFrame, card.titleFrame, card.goldIconFrame, card.rewardFrame,
                      card.favorableFrame, card.disadvantagedFrame, card.exposedLaneFrame,
                      card.attackFrame] + card.traitLineFrames
        for index in frames.indices {
            for other in frames.indices.dropFirst(index + 1) where !frames[index].isEmpty && !frames[other].isEmpty {
                #expect(!frames[index].intersects(frames[other]), "\(index) and \(other) overlap")
            }
        }
    }

    @Test(arguments: CountryMapLayoutTestFixtures.supported.filter {
        isPhoneFixture($0) && $0.name != "small phone"
    })
    func phoneRequiredInformationFramesDoNotOverlap(fixture: CountryMapLayoutTestFixture) throws {
        let (_, card) = try scoutCardLayout(for: fixture)
        let frames = [card.badgeFrame, card.titleFrame, card.goldIconFrame, card.rewardFrame,
                      card.favorableFrame, card.disadvantagedFrame, card.exposedLaneFrame,
                      card.attackFrame] + card.traitLineFrames
        for index in frames.indices {
            for other in frames.indices.dropFirst(index + 1) {
                #expect(!frames[index].intersects(frames[other]),
                        "\(fixture.name): \(index) and \(other) overlap")
            }
        }
    }

    @Test func referencePhoneCardFitsInsideInformationRegion() throws {
        let fixture = try #require(CountryMapLayoutTestFixtures.supported.first {
            $0.name == "modern phone"
        })
        let (outerLayout, layout) = try scoutCardLayout(for: fixture)

        #expect(outerLayout.informationRegionFrame
            == CGRect(x: 16, y: 114, width: 361, height: 164))
        #expect(layout.cardFrame == outerLayout.informationRegionFrame)
        #expect(outerLayout.informationRegionFrame.contains(layout.cardFrame))
        #expect(!layout.cardFrame.intersects(outerLayout.illustratedMapRegionFrame))
        #expect(layout.cardFrame.contains(layout.attackFrame))
        #expect(layout.attackFrame.width >= 44)
        #expect(layout.attackFrame.height >= 44)
        #expect(!layout.nonBlockingOverlayFrame.intersects(layout.attackFrame))
    }

    @Test(arguments: CountryMapLayoutTestFixtures.supported)
    func cardAndRequiredChildrenFitInsideInformationRegionOnEveryLayout(
        fixture: CountryMapLayoutTestFixture
    ) throws {
        let (outerLayout, cardLayout) = try scoutCardLayout(for: fixture)

        #expect(cardLayout.overlayFrame == cardLayout.cardFrame)
        #expect(outerLayout.informationRegionFrame.contains(cardLayout.cardFrame))
        #expect(!cardLayout.cardFrame.intersects(outerLayout.illustratedMapRegionFrame))

        let requiredFrames = [
            cardLayout.badgeFrame,
            cardLayout.titleFrame,
            cardLayout.goldIconFrame,
            cardLayout.rewardFrame,
            cardLayout.favorableFrame,
            cardLayout.disadvantagedFrame,
            cardLayout.exposedLaneFrame,
            cardLayout.attackFrame,
            cardLayout.overlayFrame,
            cardLayout.nonBlockingOverlayFrame
        ] + cardLayout.traitLineFrames
        for frame in requiredFrames {
            #expect(cardLayout.cardFrame.contains(frame))
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
        let contentFrame = cardLayout.cardFrame.insetBy(dx: 14, dy: 10)
        #expect(cardLayout.traitLineFrames.count == 2)
        let topTraitLine = try #require(cardLayout.traitLineFrames.first)
        let bottomTraitLine = try #require(cardLayout.traitLineFrames.last)

        #expect(cardLayout.badgeFrame.size == CGSize(width: 40, height: 16))
        #expect(cardLayout.goldIconFrame.size == CGSize(width: 15, height: 15))
        #expect(cardLayout.rewardFrame.size == CGSize(width: 39, height: 16))
        #expect(cardLayout.rewardFrame.minX - cardLayout.goldIconFrame.maxX == 5)
        #expect(topTraitLine.height == 14)
        #expect(bottomTraitLine.height == 14)
        #expect(bottomTraitLine.maxY == topTraitLine.minY)
        // Adaptive portrait rows (HPA-812 follow-up): the slack band between
        // the lane row and Attack buys the authored 8pt inter-row gap first,
        // then grows the rows evenly toward the authored 30pt scale (≥4pt
        // left under the lane row, 2pt above Attack). The tightest supported
        // card keeps the original 14pt adjacent rows.
        let footerBand = bottomTraitLine.minY - cardLayout.attackFrame.maxY - 2
        let expectedRowHeight = min(30, max(14, floor((footerBand - 12) / 2)))
        let expectedRowGap: CGFloat = footerBand >= 2 * expectedRowHeight + 12 ? 8 : 0
        #expect(cardLayout.favorableFrame.size
            == CGSize(width: contentFrame.width, height: expectedRowHeight))
        #expect(cardLayout.disadvantagedFrame.size
            == CGSize(width: contentFrame.width, height: expectedRowHeight))
        #expect(cardLayout.disadvantagedFrame.minY == cardLayout.attackFrame.maxY + 2)
        #expect(cardLayout.favorableFrame.minY
            == cardLayout.disadvantagedFrame.maxY + expectedRowGap)
        #expect(bottomTraitLine.minY - cardLayout.favorableFrame.maxY
            == footerBand - 2 * expectedRowHeight - expectedRowGap)
        #expect(cardLayout.attackFrame == CGRect(
            x: contentFrame.minX,
            y: cardLayout.cardFrame.minY + 6,
            width: contentFrame.width,
            height: 44
        ))
        #expect(cardLayout.badgeFrame.maxX + 4 == cardLayout.titleFrame.minX)
        #expect(cardLayout.exposedLaneFrame.maxX == contentFrame.maxX)
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

        #expect(phoneLayout.favorableFrame.width == 315)
        #expect(phoneLayout.disadvantagedFrame.width == 315)
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
