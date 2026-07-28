import CoreGraphics
import Testing
@testable import Pyxis

struct CountryMapScoutCardLayoutTests {
    @Test(arguments: CountryMapLayoutTestFixtures.supported)
    func supportedLayoutsKeepScoutCardFramesInsideInformationRegion(
        fixture: CountryMapLayoutTestFixture
    ) throws {
        let (outerLayout, cardLayout) = try scoutCardLayout(for: fixture)
        let informationRegion = outerLayout.informationRegionFrame

        #expect(cardLayout.cardFrame == informationRegion)
        #expect(cardLayout.overlayFrame == informationRegion)

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
    }

    @Test(arguments: CountryMapLayoutTestFixtures.supported.filter(isPhoneFixture))
    func phoneLayoutsUseLockedRowsFooterGroupsAndTitleGaps(
        fixture: CountryMapLayoutTestFixture
    ) throws {
        let (outerLayout, cardLayout) = try scoutCardLayout(for: fixture)
        let contentFrame = outerLayout.informationRegionFrame.insetBy(dx: 6, dy: 2)
        let traitFrame = try #require(cardLayout.traitLineFrames.first)

        #expect(cardLayout.badgeFrame.height == 22)
        #expect(traitFrame.height == 24)
        #expect(cardLayout.favorableFrame.height == 12)
        #expect(cardLayout.badgeFrame.minY == contentFrame.minY)
        #expect(traitFrame.minY == cardLayout.badgeFrame.maxY + 1)
        #expect(cardLayout.favorableFrame.minY == traitFrame.maxY + 1)
        #expect(cardLayout.favorableFrame.width == 106)
        #expect(cardLayout.disadvantagedFrame.width == 70)
        #expect(cardLayout.exposedLaneFrame.maxX == traitFrame.maxX)
        #expect(cardLayout.attackFrame.size == CGSize(width: 70, height: 44))
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
        let firstTraitLine = try #require(cardLayout.traitLineFrames.first)
        let secondTraitLine = try #require(cardLayout.traitLineFrames.last)

        #expect(cardLayout.badgeFrame.height == 32)
        #expect(firstTraitLine.height == 28)
        #expect(secondTraitLine.height == 28)
        #expect(cardLayout.badgeFrame.minY == contentFrame.minY)
        #expect(firstTraitLine.minY == cardLayout.badgeFrame.maxY + 4)
        #expect(secondTraitLine.minY == firstTraitLine.maxY + 4)
        #expect(cardLayout.favorableFrame == firstTraitLine)
        #expect(cardLayout.disadvantagedFrame.minY == secondTraitLine.minY)
        #expect(cardLayout.disadvantagedFrame.maxY == secondTraitLine.maxY)
        #expect(cardLayout.exposedLaneFrame.minY == secondTraitLine.minY)
        #expect(cardLayout.exposedLaneFrame.maxY == secondTraitLine.maxY)
        #expect(cardLayout.titleFrame.minX == cardLayout.badgeFrame.maxX + 8)
        #expect(cardLayout.titleFrame.maxX == cardLayout.goldIconFrame.minX - 8)
    }

    @Test func minimumLayoutsLockExpectedFooterAndAttackArithmetic() throws {
        let phoneFixture = try #require(CountryMapLayoutTestFixtures.supported.first {
            $0.name == "small phone"
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
