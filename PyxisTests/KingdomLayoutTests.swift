//
//  KingdomLayoutTests.swift
//  PyxisTests
//

import CoreGraphics
import Testing
@testable import Pyxis

/// Pure CoreGraphics geometry tests for the Kingdom Treasury layout
/// (HPA-670). No SpriteKit: the layout is a value type like
/// `BattlefieldLayout` and is exercised without a render loop.
struct KingdomLayoutTests {
    private let phoneInsets = BattleChromeLayout.SafeAreaInsets(
        top: 59, left: 0, bottom: 34, right: 0
    )
    private let padInsets = BattleChromeLayout.SafeAreaInsets(
        top: 24, left: 0, bottom: 20, right: 0
    )

    @Test("Reference phone lays out header, three rows, Buy targets and shared tab frames")
    func referencePhoneProducesThreeRowsHeaderTabsAndBuyTargets() throws {
        let layout = try #require(KingdomLayout.compute(.init(
            sceneSize: CGSize(width: 393, height: 852),
            safeAreaInsets: phoneInsets
        )))

        #expect(layout.safeFrame == CGRect(x: 0, y: 34, width: 393, height: 759))
        #expect(layout.safeFrame.contains(layout.headerFrame))

        // Exactly three rows, top-down in TreasuryUpgrade order, disjoint,
        // stacked between the header and the tab bar.
        #expect(layout.rowFrames.count == TreasuryUpgrade.allCases.count)
        for (row, next) in zip(layout.rowFrames, layout.rowFrames.dropFirst()) {
            #expect(row.minY >= next.maxY)
        }
        for row in layout.rowFrames {
            #expect(row.maxY <= layout.headerFrame.minY)
            #expect(row.minY >= layout.tabBarFrame.maxY)
            #expect(layout.safeFrame.contains(row))
        }

        // Every Buy hit target is at least 44x44 and nested in its row.
        for (index, hit) in layout.buyHitFrames.enumerated() {
            #expect(hit.width >= 44)
            #expect(hit.height >= 44)
            #expect(layout.rowFrames[index].contains(hit))
        }

        // The four tab hit frames reuse the shared Battle chrome math,
        // applied to the safe content column the rows span.
        #expect(layout.tabHitFrames.count == GameplayTab.allCases.count)
        #expect(layout.tabHitFrames == BattleChromeLayout.tabHitFramesInSafeArea(
            for: CGRect(
                x: layout.rowFrames[0].minX,
                y: layout.tabBarFrame.minY,
                width: layout.rowFrames[0].width,
                height: layout.tabBarFrame.height
            ),
            safeFrame: layout.safeFrame
        ))
        for hit in layout.tabHitFrames {
            #expect(layout.safeFrame.contains(hit))
            #expect(hit.height >= 44)
        }

        // Settings anchor is a 44pt target inside the header.
        #expect(layout.headerFrame.contains(layout.settingsFrame))
        #expect(layout.settingsFrame.width >= 44)
        #expect(layout.settingsFrame.height >= 44)

        // Gold line lives inside the header.
        #expect(layout.headerFrame.contains(layout.goldFrame))
    }

    @Test("Compact phone keeps all three rows with 44pt Buy targets")
    func compactPhoneKeepsRowsAndMinimumTargets() throws {
        let layout = try #require(KingdomLayout.compute(.init(
            sceneSize: CGSize(width: 320, height: 568),
            safeAreaInsets: .zero
        )))

        #expect(layout.rowFrames.count == 3)
        for row in layout.rowFrames {
            #expect(row.height >= KingdomLayout.minimumRowHeight)
        }
        for hit in layout.buyHitFrames {
            #expect(hit.width >= 44)
            #expect(hit.height >= 44)
        }
        #expect(layout.tabHitFrames == BattleChromeLayout.tabHitFramesInSafeArea(
            for: CGRect(
                x: layout.rowFrames[0].minX,
                y: layout.tabBarFrame.minY,
                width: layout.rowFrames[0].width,
                height: layout.tabBarFrame.height
            ),
            safeFrame: layout.safeFrame
        ))
    }

    @Test("Portrait iPad caps row height")
    func portraitPadCapsRowHeight() throws {
        let layout = try #require(KingdomLayout.compute(.init(
            sceneSize: CGSize(width: 820, height: 1180),
            safeAreaInsets: padInsets
        )))

        for row in layout.rowFrames {
            #expect(row.height == KingdomLayout.maximumRowHeight)
        }
    }

    @Test("Row label frames stack disjointly inside each row at the minimum height")
    func labelFramesStayInsideRowsAtMinimumHeight() throws {
        // 454pt viewport puts all three rows at the 80pt minimum: the
        // four-line label stack (including the wrapped Drill Yard effect)
        // must stay inside the text column without overlapping itself.
        let layout = try #require(KingdomLayout.compute(.init(
            sceneSize: CGSize(width: 320, height: 454),
            safeAreaInsets: .zero
        )))

        for index in layout.rowFrames.indices {
            let row = layout.rowFrames[index]
            #expect(row.height == KingdomLayout.minimumRowHeight)
            let labels = [
                layout.nameLabelFrames[index],
                layout.levelLabelFrames[index],
                layout.effectLabelFrames[index],
                layout.priceLabelFrames[index]
            ]
            for frame in labels {
                #expect(layout.textFrames[index].contains(frame))
            }
            for (upper, lower) in zip(labels, labels.dropFirst()) {
                #expect(!upper.intersects(lower))
            }
            #expect(row.contains(layout.buyHitFrames[index]))
        }
    }

    @Test("Viewport too short for three real rows returns nil")
    func rowsDoNotFitReturnsNil() {
        // 88 (header) + 3 rows of 80 + gaps + 82 tab bar cannot fit in 330pt.
        #expect(
            KingdomLayout.compute(.init(
                sceneSize: CGSize(width: 320, height: 330),
                safeAreaInsets: .zero
            )) == nil
        )
    }

    @Test("Side insets keep tab hit targets inside the safe content column")
    func sideInsetsKeepTabHitTargetsInsideContentColumn() throws {
        // The visual bar stays full-bleed, but hit targets derive from the
        // safe content column — a large side inset no longer fails the
        // containment guard (and a starved content column still fails
        // closed earlier).
        let layout = try #require(KingdomLayout.compute(.init(
            sceneSize: CGSize(width: 393, height: 852),
            safeAreaInsets: BattleChromeLayout.SafeAreaInsets(
                top: 59, left: 100, bottom: 34, right: 0
            )
        )))
        #expect(layout.tabBarFrame == CGRect(x: 16, y: 0, width: 361, height: 82))
        for hit in layout.tabHitFrames {
            #expect(layout.safeFrame.contains(hit))
            #expect(hit.minX >= layout.rowFrames[0].minX)
        }

        #expect(KingdomLayout.compute(.init(
            sceneSize: CGSize(width: 393, height: 852),
            safeAreaInsets: BattleChromeLayout.SafeAreaInsets(
                top: 59, left: 280, bottom: 34, right: 0
            )
        )) == nil)
    }

    @Test("Degenerate scene sizes and insets return nil")
    func degenerateInputReturnsNil() {
        #expect(KingdomLayout.compute(.init(
            sceneSize: .zero,
            safeAreaInsets: .zero
        )) == nil)
        #expect(KingdomLayout.compute(.init(
            sceneSize: CGSize(width: -393, height: 852),
            safeAreaInsets: .zero
        )) == nil)
        #expect(KingdomLayout.compute(.init(
            sceneSize: CGSize(width: 393, height: CGFloat.nan),
            safeAreaInsets: .zero
        )) == nil)
        #expect(KingdomLayout.compute(.init(
            sceneSize: CGSize(width: 393, height: 852),
            safeAreaInsets: BattleChromeLayout.SafeAreaInsets(top: -1, left: 0, bottom: 0, right: 0)
        )) == nil)
        #expect(KingdomLayout.compute(.init(
            sceneSize: CGSize(width: 100, height: 852),
            safeAreaInsets: BattleChromeLayout.SafeAreaInsets(top: 0, left: 0, bottom: 0, right: 0)
        )) == nil
        )
    }

    @Test("Compute is deterministic and the value is Equatable")
    func computeIsDeterministic() throws {
        let input = KingdomLayout.Input(
            sceneSize: CGSize(width: 393, height: 852),
            safeAreaInsets: phoneInsets
        )
        let first = try #require(KingdomLayout.compute(input))
        let second = try #require(KingdomLayout.compute(input))
        #expect(first == second)
    }

    // MARK: - HPA-671 Armory section selector and band

    @Test("320×454 header hosts three adaptive ≥44pt selectors beside Settings")
    func boundaryHeaderFitsThreeSectionSelectors() throws {
        let layout = try #require(KingdomLayout.compute(.init(
            sceneSize: CGSize(width: 320, height: 454),
            safeAreaInsets: .zero
        )))

        // The binding arithmetic: 288pt content − 44pt Settings − 8pt gap
        // leaves 236pt for the cluster; minus two 8pt selector gaps that
        // is ~73pt per selector — readable, not the unreadable 44pt floor.
        #expect(layout.headerFrame == CGRect(x: 16, y: 366, width: 288, height: 88))
        #expect(layout.goldFrame == CGRect(x: 16, y: 366, width: 236, height: 44))

        let selectors = [
            layout.treasurySelectorFrame,
            layout.armorySelectorFrame,
            layout.ascendSelectorFrame
        ]
        for frame in selectors {
            #expect(frame.height == 44)
            #expect(frame.maxY == layout.headerFrame.maxY)
            #expect(layout.headerFrame.contains(frame))
            #expect(frame.width >= 44)
            #expect(abs(frame.width - 73.33) < 0.5)
        }
        // Treasury → Armory → Ascend left to right, the cluster ending
        // 8pt left of Settings with an 8pt gap between selectors.
        #expect(
            layout.treasurySelectorFrame.maxX + KingdomLayout.sectionSelectorGap
                == layout.armorySelectorFrame.minX
        )
        #expect(
            layout.armorySelectorFrame.maxX + KingdomLayout.sectionSelectorGap
                == layout.ascendSelectorFrame.minX
        )
        #expect(layout.ascendSelectorFrame.maxX + 8 == layout.settingsFrame.minX)

        var topLine = selectors
        topLine.append(layout.settingsFrame)
        for i in topLine.indices {
            for j in (i + 1)..<topLine.count {
                #expect(!topLine[i].intersects(topLine[j]))
            }
        }
    }

    @Test("Five Armory rows share the Treasury band at 320×454 with ≥44pt whole-row targets")
    func boundaryArmoryRowsShareTreasuryBand() throws {
        let layout = try #require(KingdomLayout.compute(.init(
            sceneSize: CGSize(width: 320, height: 454),
            safeAreaInsets: .zero
        )))

        #expect(layout.armoryRowFrames.count == KingdomLayout.armoryRowCount)
        #expect(KingdomLayout.armoryRowCount == SoldierType.allCases.count)
        for (index, row) in layout.armoryRowFrames.enumerated() {
            // (260 − 4×6) / 5 = 47.2pt rows inside the same content band.
            #expect(abs(row.height - 47.2) < 0.01)
            #expect(row.height >= 44)
            #expect(row.width == layout.rowFrames[0].width)
            #expect(row.maxY <= layout.headerFrame.minY)
            #expect(row.minY >= layout.tabBarFrame.maxY)
            #expect(layout.safeFrame.contains(row))

            #expect(row.contains(layout.armoryIconFrames[index]))
            #expect(row.contains(layout.armoryTextFrames[index]))
            #expect(layout.armoryTextFrames[index].width >= KingdomLayout.minimumTextWidth)
            let line1 = layout.armoryLine1LabelFrames[index]
            let line2 = layout.armoryLine2LabelFrames[index]
            #expect(layout.armoryTextFrames[index].contains(line1))
            #expect(layout.armoryTextFrames[index].contains(line2))
            #expect(!line1.intersects(line2))
        }
        for (row, next) in zip(layout.armoryRowFrames, layout.armoryRowFrames.dropFirst()) {
            #expect(abs(row.minY - next.maxY - KingdomLayout.armoryRowGap) < 0.01)
        }
        // Treasury geometry is untouched in the same band: three 80pt rows.
        for row in layout.rowFrames {
            #expect(row.height == KingdomLayout.minimumRowHeight)
        }
    }

    @Test("Armory rows cap at their maximum on taller viewports")
    func armoryRowsCapAtMaximumHeight() throws {
        let layout = try #require(KingdomLayout.compute(.init(
            sceneSize: CGSize(width: 393, height: 852),
            safeAreaInsets: phoneInsets
        )))
        for row in layout.armoryRowFrames {
            #expect(row.height == KingdomLayout.armoryMaximumRowHeight)
        }
        #expect(layout.armoryRowFrames[0].maxY == layout.headerFrame.minY - 12)
        for (row, next) in zip(layout.armoryRowFrames, layout.armoryRowFrames.dropFirst()) {
            #expect(row.minY - next.maxY == KingdomLayout.armoryRowGap)
        }
    }

    @Test("Section controls stay ≥44pt and disjoint from Settings on every accepted size")
    func selectorControlsStayDisjointAcrossSizes() throws {
        let cases: [(size: CGSize, insets: BattleChromeLayout.SafeAreaInsets)] = [
            (CGSize(width: 320, height: 568), .zero),
            (CGSize(width: 375, height: 812), phoneInsets),
            (CGSize(width: 393, height: 852), phoneInsets),
            (CGSize(width: 414, height: 896), phoneInsets),
            (CGSize(width: 820, height: 1180), padInsets)
        ]
        for testCase in cases {
            let layout = try #require(KingdomLayout.compute(.init(
                sceneSize: testCase.size,
                safeAreaInsets: testCase.insets
            )))
            let selectors = [
                layout.treasurySelectorFrame,
                layout.armorySelectorFrame,
                layout.ascendSelectorFrame
            ]
            for frame in selectors {
                #expect(frame.width >= 44)
                #expect(frame.height == 44)
                #expect(layout.headerFrame.contains(frame))
            }
            var frames = selectors
            frames.append(layout.settingsFrame)
            for i in frames.indices {
                for j in (i + 1)..<frames.count {
                    #expect(!frames[i].intersects(frames[j]))
                }
            }
        }
    }

    @Test("A viewport too narrow for the Treasury rows fails closed")
    func tooNarrowForSectionControlsReturnsNil() {
        // The row-text floor is 232pt of content (264pt scene); the three
        // selectors only need 200pt, so the rows starve first.
        #expect(KingdomLayout.compute(.init(
            sceneSize: CGSize(width: 260, height: 454),
            safeAreaInsets: .zero
        )) == nil)
    }

    @Test("Widths at the Treasury row floor still fit three selectors")
    func rowFloorWidthKeepsSectionControls() throws {
        // The header must never fail where the rows still fit: 232pt of
        // content is the row-text floor, and the selector cluster shrinks
        // to ~(180 − 16) / 3 ≈ 54.7pt per control — still ≥44pt.
        let layout = try #require(KingdomLayout.compute(.init(
            sceneSize: CGSize(width: 264, height: 454),
            safeAreaInsets: .zero
        )))
        for frame in [
            layout.treasurySelectorFrame,
            layout.armorySelectorFrame,
            layout.ascendSelectorFrame
        ] {
            #expect(frame.width >= 44)
            #expect(frame.height == 44)
        }
        // The 164/3 selector width is non-terminating, so the cluster's
        // right edge lands a float epsilon off Settings minus its gap.
        #expect(
            abs(layout.ascendSelectorFrame.maxX + 8 - layout.settingsFrame.minX) < 0.01
        )
        #expect(layout.rowFrames.count == TreasuryUpgrade.allCases.count)
        #expect(layout.armoryRowFrames.count == SoldierType.allCases.count)

        // One point narrower starves the row text column too — the whole
        // layout fails closed, header and band together.
        #expect(KingdomLayout.compute(.init(
            sceneSize: CGSize(width: 263, height: 454),
            safeAreaInsets: .zero
        )) == nil)
    }

    // MARK: - HPA-672 Ascend band and Renown header

    @Test("Ascend shares the Treasury band with ≥44pt Confirm/Cancel targets")
    func ascendBandSharesTreasuryBand() throws {
        let layout = try #require(KingdomLayout.compute(.init(
            sceneSize: CGSize(width: 320, height: 454),
            safeAreaInsets: .zero
        )))

        // The panel spans exactly the band the Treasury/Armory rows span.
        #expect(layout.ascendPanelFrame.minY == layout.tabBarFrame.maxY + 12)
        #expect(layout.ascendPanelFrame.maxY == layout.headerFrame.minY - 12)
        #expect(layout.ascendPanelFrame.width == layout.rowFrames[0].width)
        #expect(layout.safeFrame.contains(layout.ascendPanelFrame))

        // Icon top-center, then bonus/resets/keeps/requirement stacked
        // disjointly.
        #expect(layout.ascendPanelFrame.contains(layout.ascendIconFrame))
        let labels = [
            layout.ascendBonusLabelFrame,
            layout.ascendResetsLabelFrame,
            layout.ascendKeepsLabelFrame,
            layout.ascendRequirementLabelFrame
        ]
        for frame in labels {
            #expect(layout.ascendPanelFrame.contains(frame))
        }
        for (upper, lower) in zip(labels, labels.dropFirst()) {
            #expect(!upper.intersects(lower))
        }
        #expect(!layout.ascendIconFrame.intersects(layout.ascendBonusLabelFrame))

        // Confirm/Cancel: ≥44pt, side by side, disjoint from each other,
        // the tab bar (scene y grows upward — the band sits ABOVE it),
        // the label stack and the header's Settings target.
        for frame in [layout.ascendPrimaryActionFrame, layout.ascendCancelFrame] {
            #expect(frame.width >= 44)
            #expect(frame.height >= 44)
            #expect(layout.ascendPanelFrame.contains(frame))
            #expect(frame.minY >= layout.tabBarFrame.maxY)
            #expect(!frame.intersects(layout.settingsFrame))
            #expect(!frame.intersects(layout.ascendKeepsLabelFrame))
            #expect(!frame.intersects(layout.ascendRequirementLabelFrame))
        }
        #expect(!layout.ascendPrimaryActionFrame.intersects(layout.ascendCancelFrame))
        #expect(layout.ascendPrimaryActionFrame.minX > layout.ascendCancelFrame.maxX)
    }

    @Test("Ascend stack stays inside the band on portrait iPad")
    func ascendBandFitsTallViewports() throws {
        let layout = try #require(KingdomLayout.compute(.init(
            sceneSize: CGSize(width: 820, height: 1180),
            safeAreaInsets: padInsets
        )))
        #expect(layout.safeFrame.contains(layout.ascendPanelFrame))
        #expect(layout.ascendIconFrame.maxY == layout.ascendPanelFrame.maxY - 12)
        for frame in [layout.ascendPrimaryActionFrame, layout.ascendCancelFrame] {
            #expect(layout.safeFrame.contains(frame))
            #expect(frame.minY >= layout.tabBarFrame.maxY)
        }
    }

    @Test("Renown reserves a right-aligned bottom-header box clear of the gear column")
    func renownFrameSitsRightInGoldLine() throws {
        for width in [CGFloat(264), 320, 393] {
            let layout = try #require(KingdomLayout.compute(.init(
                sceneSize: CGSize(width: width, height: 454),
                safeAreaInsets: .zero
            )))
            #expect(layout.headerFrame.contains(layout.renownFrame))
            #expect(layout.renownFrame.height == 44)
            #expect(layout.renownFrame.minY == layout.headerFrame.minY)
            #expect(layout.renownFrame.maxX + 8 <= layout.settingsFrame.minX)
            #expect(layout.renownFrame.width >= KingdomLayout.renownLabelMinimumWidth)
            // With Renown visible gold keeps a usable measured column...
            #expect(layout.goldTextMaxWidth(showingRenown: true) >= 80)
            // ...and without it the full gold line width stays available.
            #expect(layout.goldTextMaxWidth(showingRenown: false) == layout.goldFrame.width)
        }
    }
}
