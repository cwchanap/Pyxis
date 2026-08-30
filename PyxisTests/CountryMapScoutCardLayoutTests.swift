import CoreGraphics
import Testing
@testable import Pyxis

struct CountryMapScoutCardLayoutTests {
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
    func supportedLayoutsKeepScoutCardFramesInsideInformationRegion(
        fixture: CountryMapLayoutTestFixture
    ) throws {
        let (outerLayout, cardLayout) = try scoutCardLayout(for: fixture)
        let informationRegion = outerLayout.informationRegionFrame

        #expect(cardLayout.cardFrame == informationRegion)
        #expect(cardLayout.overlayFrame == informationRegion)

        // The non-blocking flavor overlay spans the informational area plus
        // the Attack gap but stops at the Attack frame's leading edge, so it
        // never intersects the Attack target (edge-touching rects report
        // `intersects == false` in Core Graphics).
        #expect(cardLayout.nonBlockingOverlayFrame.minX == cardLayout.cardFrame.minX)
        #expect(cardLayout.nonBlockingOverlayFrame.maxX == cardLayout.attackFrame.minX)
        #expect(cardLayout.nonBlockingOverlayFrame.minY == cardLayout.cardFrame.minY)
        #expect(cardLayout.nonBlockingOverlayFrame.height == cardLayout.cardFrame.height)
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
            #expect(informationRegion.contains(frame))
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
        for (index, frame) in informationalFrames.enumerated() {
            guard !frame.isEmpty else {
                continue
            }
            for otherFrame in informationalFrames.dropFirst(index + 1) {
                guard !otherFrame.isEmpty else {
                    continue
                }
                #expect(!frame.intersects(otherFrame))
            }
        }
    }

    @Test(arguments: CountryMapLayoutTestFixtures.supported.filter {
        isPhoneFixture($0) && $0.name != "small phone"
    })
    func phoneLayoutsUseLockedRowsFooterGroupsAndTitleGaps(
        fixture: CountryMapLayoutTestFixture
    ) throws {
        let (outerLayout, cardLayout) = try scoutCardLayout(for: fixture)
        let contentFrame = outerLayout.informationRegionFrame.insetBy(dx: 6, dy: 2)
        #expect(cardLayout.traitLineFrames.count == 2)
        let topTraitLine = try #require(cardLayout.traitLineFrames.first)
        let bottomTraitLine = try #require(cardLayout.traitLineFrames.last)

        #expect(cardLayout.badgeFrame.size == CGSize(width: 22, height: 22))
        #expect(cardLayout.goldIconFrame.size == CGSize(width: 12, height: 12))
        #expect(cardLayout.rewardFrame.size == CGSize(width: 34, height: 22))
        #expect(cardLayout.rewardFrame.minX - cardLayout.goldIconFrame.maxX == 2)
        #expect(topTraitLine.height == 12)
        #expect(bottomTraitLine.height == 12)
        #expect(cardLayout.favorableFrame.height == 12)
        #expect(cardLayout.badgeFrame.maxY == contentFrame.maxY)
        #expect(topTraitLine.maxY == cardLayout.badgeFrame.minY - 1)
        #expect(bottomTraitLine.maxY == topTraitLine.minY)
        // The variable-height phone card preserves its footer at the lower
        // edge while the authored trait rows stay locked below the header.
        #expect(cardLayout.favorableFrame.maxY <= bottomTraitLine.minY - 1)
        #expect(cardLayout.favorableFrame.minY == contentFrame.minY)
        #expect(cardLayout.favorableFrame.width == 106)
        #expect(cardLayout.disadvantagedFrame.width == 70)
        #expect(cardLayout.exposedLaneFrame.maxX == topTraitLine.maxX)
        #expect(cardLayout.attackFrame.size == CGSize(width: 70, height: 44))
        #expect(cardLayout.attackFrame.maxX == contentFrame.maxX)
        #expect(cardLayout.attackFrame.midY == outerLayout.informationRegionFrame.midY)
        #expect(cardLayout.favorableFrame.minY == outerLayout.informationRegionFrame.minY + 2)
        #expect(cardLayout.disadvantagedFrame.minX - cardLayout.favorableFrame.maxX == 6)
        #expect(cardLayout.exposedLaneFrame.minX - cardLayout.disadvantagedFrame.maxX == 6)
        #expect(cardLayout.titleFrame.minX == cardLayout.badgeFrame.maxX + 4)
        #expect(cardLayout.titleFrame.maxX == cardLayout.goldIconFrame.minX - 4)
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

        #expect(phoneLayout.favorableFrame.width == 106)
        #expect(phoneLayout.disadvantagedFrame.width == 70)
        #expect(phoneLayout.exposedLaneFrame.width == 67)
        #expect(phoneLayout.attackFrame.size == CGSize(width: 70, height: 44))

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
