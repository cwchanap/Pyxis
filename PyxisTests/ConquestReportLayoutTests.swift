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
    rows: Int,
    achievements: Int
) -> ConquestReportLayout? {
    let compactHeight = size.height < 500
    let horizontalMargin = max(8, min(compactHeight ? 16 : 18, size.width * 0.045))
    let battleContentWidth = min(max(0, size.width - horizontalMargin * 2), 560)
    return ConquestReportLayout.compute(.init(
        sceneSize: size,
        safeAreaInsets: insets,
        battleContentWidth: battleContentWidth,
        summaryRowCount: rows,
        achievementCount: achievements,
        compactHeight: compactHeight
    ))
}

struct ConquestReportLayoutTests {

    @Test func deterministicHeightsMatchConstants() throws {
        let standard = try #require(makeLayout(
            size: .init(width: 375, height: 667), rows: 4, achievements: 2
        ))
        let compact = try #require(makeLayout(
            size: .init(width: 375, height: 499), rows: 4, achievements: 2
        ))
        let threeRows = try #require(makeLayout(
            size: .init(width: 375, height: 667), rows: 3, achievements: 0
        ))
        #expect(standard.panelFrame.height == 282)
        #expect(compact.panelFrame.height == 230)
        #expect(threeRows.panelFrame.height == 220)
    }

    @Test func badgeStripWidthUsesCountSizeAndGap() throws {
        let one = try #require(makeLayout(rows: 4, achievements: 1))
        let two = try #require(makeLayout(rows: 4, achievements: 2))
        #expect(one.achievementStripFrame?.width == 24)
        #expect(two.achievementStripFrame?.width == 56)
    }

    @Test func badgeFramesHonorConfiguredGap() throws {
        let standard = try #require(makeLayout(rows: 4, achievements: 2))
        let compact = try #require(makeLayout(
            size: .init(width: 375, height: 499), rows: 4, achievements: 2
        ))
        let single = try #require(makeLayout(rows: 4, achievements: 1))
        let strip = try #require(standard.achievementStripFrame)

        // Standard: 24pt badges with an 8pt edge-to-edge gap.
        #expect(standard.badgeFrames.count == 2)
        #expect(standard.badgeFrames[0].size == CGSize(width: 24, height: 24))
        #expect(standard.badgeFrames[1].size == CGSize(width: 24, height: 24))
        #expect(standard.badgeFrames[0].maxX + 8 == standard.badgeFrames[1].minX)
        #expect(standard.badgeFrames[0].minX == strip.minX)
        #expect(standard.badgeFrames[1].maxX == strip.maxX)

        // Compact: 20pt badges with a 6pt edge-to-edge gap.
        #expect(compact.badgeFrames.count == 2)
        #expect(compact.badgeFrames[0].size == CGSize(width: 20, height: 20))
        #expect(compact.badgeFrames[0].maxX + 6 == compact.badgeFrames[1].minX)

        // A single badge is centered by the strip itself.
        let singleStrip = try #require(single.achievementStripFrame)
        #expect(single.badgeFrames.count == 1)
        #expect(single.badgeFrames[0] == singleStrip)
    }

    @Test func everySupportedFixtureContainsAllFrames() throws {
        for fixture in supportedFixtures {
            let layout = try #require(makeLayout(
                size: fixture.size,
                insets: fixture.insets,
                rows: 4,
                achievements: 2
            ))
            #expect(layout.safeFrame.contains(layout.panelFrame))
            #expect(layout.panelFrame.contains(layout.titleFrame))
            #expect(layout.summaryRowFrames.allSatisfy { layout.panelFrame.contains($0) })
            #expect(layout.achievementStripFrame.map { layout.panelFrame.contains($0) } ?? true)
            #expect(layout.panelFrame.contains(layout.continueFrame))
            // Ordered, non-overlapping summary rows: each row sits strictly
            // below the one above it (rows are emitted top-to-bottom as the
            // cursor descends, so a higher index has a lower Y).
            for index in 1..<layout.summaryRowFrames.count {
                let upper = layout.summaryRowFrames[index - 1]
                let lower = layout.summaryRowFrames[index]
                #expect(lower.maxY <= upper.minY)
            }
            // Separation between the summary rows and the achievement badge
            // strip: the strip sits below the last (lowest) summary row.
            if let strip = layout.achievementStripFrame {
                let lastRow = try #require(layout.summaryRowFrames.last)
                #expect(strip.maxY <= lastRow.minY)
            }
            // Complete Continue hit frame containment. continueFrame is both
            // the visual background and the enabled hit target
            // (ConquestReportNode.continueHitFrame), so the containment check
            // above already covers the complete hit frame; assert it again
            // explicitly against the safe region to document the intent.
            #expect(layout.safeFrame.contains(layout.continueFrame))
        }
    }

    @Test func sideInsetsCenterInsideSafeRegion() throws {
        let layout = try #require(makeLayout(
            size: .init(width: 834, height: 1194),
            insets: .init(top: 24, left: 50, bottom: 20, right: 50),
            rows: 4,
            achievements: 2
        ))
        #expect(layout.safeFrame == CGRect(x: 50, y: 20, width: 734, height: 1_150))
        #expect(layout.panelFrame.midX == layout.safeFrame.midX)
    }

    @Test func invalidCountsAndInsufficientGeometryReturnNil() {
        #expect(makeLayout(rows: 2, achievements: 0) == nil)
        #expect(makeLayout(rows: 5, achievements: 0) == nil)
        #expect(makeLayout(rows: 4, achievements: 3) == nil)
        #expect(makeLayout(
            size: .init(width: 80, height: 200),
            insets: .init(top: 0, left: 20, bottom: 0, right: 20),
            rows: 4,
            achievements: 2
        ) == nil)
        #expect(makeLayout(
            size: .init(width: 375, height: 200),
            insets: .init(top: 20, left: 0, bottom: 20, right: 0),
            rows: 4,
            achievements: 2
        ) == nil)
    }

    @Test func noAchievementsOmitBadgeStripAndGap() throws {
        let layout = try #require(makeLayout(rows: 4, achievements: 0))
        #expect(layout.achievementStripFrame == nil)
    }

    @Test func continuesFrameWidthMatchesPanelInset() throws {
        let layout = try #require(makeLayout(rows: 4, achievements: 2))
        #expect(layout.continueFrame.width == layout.panelFrame.width - 48)
    }

    @Test func cornerRadiusIsConstant() throws {
        let layout = try #require(makeLayout(rows: 4, achievements: 2))
        #expect(layout.panelCornerRadius == 14)
    }

    @Test func fontMetricsReflectCompactClassification() throws {
        let standard = try #require(makeLayout(
            size: .init(width: 375, height: 667), rows: 4, achievements: 2
        ))
        let compact = try #require(makeLayout(
            size: .init(width: 375, height: 499), rows: 4, achievements: 2
        ))
        #expect(standard.titleStartingFontSize == 22)
        #expect(standard.summaryStartingFontSize == 17)
        #expect(standard.continueStartingFontSize == 16)
        #expect(compact.titleStartingFontSize == 19)
        #expect(compact.summaryStartingFontSize == 14)
        #expect(compact.continueStartingFontSize == 15)
        #expect(standard.titleMinimumFontSize == 14)
        #expect(standard.summaryMinimumFontSize == 12)
        #expect(standard.continueMinimumFontSize == 15)
    }
}
