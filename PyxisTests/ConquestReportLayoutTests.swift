import CoreGraphics
import Testing
@testable import Pyxis

private struct ReportLayoutFixture {
    let size: CGSize
    let insets: ConquestReportSafeAreaInsets
}

private let supportedFixtures: [ReportLayoutFixture] = CountryMapLayoutTestFixtures.supported.map {
    ReportLayoutFixture(
        size: $0.size,
        insets: ConquestReportSafeAreaInsets(
            top: $0.insets.top,
            left: $0.insets.left,
            bottom: $0.insets.bottom,
            right: $0.insets.right
        )
    )
}

private func makeLayout(
    size: CGSize = CGSize(width: 375, height: 667),
    insets: ConquestReportSafeAreaInsets = ConquestReportSafeAreaInsets(top: 0, left: 0, bottom: 0, right: 0),
    tiles: Int,
    chips: Int,
    includesCountryCompletion: Bool = false
) -> ConquestReportLayout? {
    let compactHeight = size.height < 500
    let horizontalMargin = max(8, min(compactHeight ? 16 : 18, size.width * 0.045))
    let battleContentWidth = min(max(0, size.width - horizontalMargin * 2), 560)
    return ConquestReportLayout.compute(.init(
        sceneSize: size,
        safeAreaInsets: insets,
        battleContentWidth: battleContentWidth,
        tileCount: tiles,
        chipCount: chips,
        compactHeight: compactHeight,
        includesCountryCompletion: includesCountryCompletion
    ))
}

struct ConquestReportLayoutTests {
    @Test func referencePhoneMatchesAuthoredForgedReportGeometry() throws {
        let layout = try #require(makeLayout(
            size: CGSize(width: 393, height: 852),
            insets: .init(top: 59, left: 0, bottom: 34, right: 0),
            tiles: 3,
            chips: 2
        ))

        #expect(layout.panelFrame == CGRect(x: 24, y: 185, width: 345, height: 419))
        #expect(layout.takenMedallionFrame == CGRect(x: 137.5, y: 584, width: 118, height: 118))
        #expect(layout.continueFrame == CGRect(x: 46, y: 207, width: 301, height: 54))
    }

    @Test func tileAndChipCountsAreAcceptedAtTheContractBoundaries() throws {
        let two = try #require(makeLayout(tiles: 2, chips: 0))
        let three = try #require(makeLayout(tiles: 3, chips: 2))
        #expect(two.tileFrames.count == 2)
        #expect(two.chipFrames.isEmpty)
        #expect(three.tileFrames.count == 3)
        #expect(three.chipFrames.count == 2)
        #expect(three.rewardFrame.width > 0)
        #expect(three.continueFrame.width >= 44)
    }

    @Test func tileFramesAndChipFramesAreContainedAndSeparated() throws {
        let layout = try #require(makeLayout(tiles: 3, chips: 2))
        #expect(layout.safeFrame.contains(layout.panelFrame))
        #expect(layout.panelFrame.contains(layout.titleFrame))
        #expect(layout.panelFrame.contains(layout.rewardFrame))
        #expect(layout.tileFrames.allSatisfy { layout.panelFrame.contains($0) })
        #expect(layout.chipFrames.allSatisfy { layout.panelFrame.contains($0) })
        #expect(layout.panelFrame.contains(layout.continueFrame))
        let medallion = try #require(layout.takenMedallionFrame)
        #expect(layout.safeFrame.contains(medallion))
        for index in 1..<layout.tileFrames.count {
            #expect(layout.tileFrames[index - 1].maxX <= layout.tileFrames[index].minX)
        }
        #expect(layout.chipFrames[0].maxX + 8 == layout.chipFrames[1].minX)
        #expect(layout.chipStripFrame?.contains(layout.chipFrames[0]) == true)
    }

    @Test func zeroChipsReserveNoChipHeight() throws {
        let noChips = try #require(makeLayout(tiles: 2, chips: 0))
        let chips = try #require(makeLayout(tiles: 2, chips: 1))
        #expect(noChips.chipStripFrame == nil)
        #expect(noChips.chipFrames.isEmpty)
        #expect(chips.panelFrame.height > noChips.panelFrame.height)
    }

    @Test func everySupportedFixtureContainsAllFrames() throws {
        for fixture in supportedFixtures {
            let layout = try #require(makeLayout(
                size: fixture.size,
                insets: fixture.insets,
                tiles: 3,
                chips: 2
            ))
            #expect(layout.safeFrame.contains(layout.panelFrame))
            #expect(layout.panelFrame.contains(layout.rewardFrame))
            #expect(layout.tileFrames.allSatisfy { layout.panelFrame.contains($0) })
            #expect(layout.chipFrames.allSatisfy { layout.panelFrame.contains($0) })
            #expect(layout.panelFrame.contains(layout.continueFrame))
        }
    }

    @Test func sideInsetsCenterInsideSafeRegion() throws {
        let layout = try #require(makeLayout(
            size: .init(width: 834, height: 1194),
            insets: .init(top: 24, left: 50, bottom: 20, right: 50),
            tiles: 3,
            chips: 2
        ))
        #expect(layout.safeFrame == CGRect(x: 50, y: 20, width: 734, height: 1_150))
        #expect(layout.panelFrame.midX == layout.safeFrame.midX)
    }

    @Test func invalidCountsAndInsufficientGeometryReturnNil() {
        #expect(makeLayout(tiles: 1, chips: 0) == nil)
        #expect(makeLayout(tiles: 4, chips: 0) == nil)
        #expect(makeLayout(tiles: 2, chips: 3) == nil)
        #expect(makeLayout(
            size: .init(width: 80, height: 200),
            insets: .init(top: 0, left: 20, bottom: 0, right: 20),
            tiles: 3,
            chips: 2
        ) == nil)
        #expect(makeLayout(
            size: .init(width: 375, height: 200),
            insets: .init(top: 20, left: 0, bottom: 20, right: 0),
            tiles: 3,
            chips: 2
        ) == nil)
    }

    @Test("Country completion fits supported geometry gates")
    func countryCompletionFitsSupportedGates() throws {
        for size in [
            CGSize(width: 568, height: 320),
            CGSize(width: 667, height: 375),
            CGSize(width: 320, height: 568)
        ] {
            let layout = try #require(makeLayout(
                size: size,
                tiles: 3,
                chips: 2,
                includesCountryCompletion: true
            ))
            let completion = try #require(layout.countryCompleteFrame)
            #expect(layout.safeFrame.contains(layout.panelFrame))
            #expect(layout.safeFrame.contains(completion))
            #expect(!completion.intersects(layout.panelFrame))
            #expect(!completion.intersects(layout.continueFrame))
            if let medallion = layout.takenMedallionFrame {
                #expect(!medallion.intersects(layout.titleFrame))
                #expect(!medallion.intersects(layout.rewardFrame))
                #expect(!medallion.intersects(completion))
            }
        }
    }

    @Test func constrainedCountryCompletionOmitsDecorativeMedallion() throws {
        let layout = try #require(makeLayout(
            size: CGSize(width: 320, height: 568),
            tiles: 3,
            chips: 2,
            includesCountryCompletion: true
        ))
        #expect(layout.takenMedallionFrame == nil)
    }

    @Test func countryCompletionFailsClosedAtPureBoundary() throws {
        let size = CGSize(width: 568, height: 270)
        let base = try #require(makeLayout(
            size: size,
            tiles: 2,
            chips: 0,
            includesCountryCompletion: false
        ))
        #expect(base.countryCompleteFrame == nil)
        #expect(makeLayout(
            size: size,
            tiles: 2,
            chips: 0,
            includesCountryCompletion: true
        ) == nil)
    }
}
