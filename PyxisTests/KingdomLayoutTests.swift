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

        // Title and gold frames live inside the header.
        #expect(layout.headerFrame.contains(layout.titleFrame))
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

    @Test("Portrait iPad caps row height and reserves noninteractive future-section space")
    func portraitPadCapsRowsAndReservesFutureSection() throws {
        let layout = try #require(KingdomLayout.compute(.init(
            sceneSize: CGSize(width: 820, height: 1180),
            safeAreaInsets: padInsets
        )))

        for row in layout.rowFrames {
            #expect(row.height == KingdomLayout.maximumRowHeight)
        }

        // The future-section reservation is noninteractive space below the
        // last live row: it must not overlap rows, header or tab bar.
        #expect(layout.futureSectionFrame.width > 0)
        #expect(layout.futureSectionFrame.height > 0)
        #expect(layout.futureSectionFrame.maxY <= layout.rowFrames[2].minY)
        #expect(layout.futureSectionFrame.minY >= layout.tabBarFrame.maxY)
        #expect(layout.safeFrame.contains(layout.futureSectionFrame))
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

    @Test("320×454 header keeps the gold line and fits title + two 60×44 section controls")
    func boundaryHeaderFitsTitleAndSectionControls() throws {
        let layout = try #require(KingdomLayout.compute(.init(
            sceneSize: CGSize(width: 320, height: 454),
            safeAreaInsets: .zero
        )))

        // The binding arithmetic: 288pt content = 44 Settings + 8 gap +
        // 120pt of section controls + ≥100pt width-fitted title (228 of
        // the 236pt remainder allocated, slack absorbed by the title),
        // all inside the unchanged 88pt header — zero new height.
        #expect(layout.headerFrame == CGRect(x: 16, y: 366, width: 288, height: 88))
        #expect(layout.goldFrame == CGRect(x: 16, y: 366, width: 236, height: 44))

        #expect(layout.titleFrame.minX == layout.headerFrame.minX)
        #expect(layout.titleFrame.height == 44)
        #expect(layout.titleFrame.maxY == layout.headerFrame.maxY)
        // The authored compact allocation is 100pt; the boundary leaves 108.
        #expect(layout.titleFrame.width >= 100)

        #expect(layout.treasurySelectorFrame.size == CGSize(width: 60, height: 44))
        #expect(layout.armorySelectorFrame.size == CGSize(width: 60, height: 44))
        #expect(layout.treasurySelectorFrame.maxY == layout.headerFrame.maxY)
        #expect(layout.armorySelectorFrame.maxY == layout.headerFrame.maxY)
        // Adjacent controls, 8pt left of the untouched Settings target.
        #expect(layout.treasurySelectorFrame.maxX == layout.armorySelectorFrame.minX)
        #expect(layout.armorySelectorFrame.maxX + 8 == layout.settingsFrame.minX)
        #expect(layout.titleFrame.maxX + 8 <= layout.treasurySelectorFrame.minX)

        let topLine = [
            layout.titleFrame,
            layout.treasurySelectorFrame,
            layout.armorySelectorFrame,
            layout.settingsFrame
        ]
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

    @Test("Section controls stay disjoint from title and Settings on every accepted size")
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
            #expect(layout.treasurySelectorFrame.size == CGSize(width: 60, height: 44))
            #expect(layout.armorySelectorFrame.size == CGSize(width: 60, height: 44))
            #expect(layout.titleFrame.width >= KingdomLayout.minimumTitleWidth)
            let frames = [
                layout.titleFrame,
                layout.treasurySelectorFrame,
                layout.armorySelectorFrame,
                layout.settingsFrame
            ]
            for frame in frames {
                #expect(layout.headerFrame.contains(frame))
            }
            for i in frames.indices {
                for j in (i + 1)..<frames.count {
                    #expect(!frames[i].intersects(frames[j]))
                }
            }
        }
    }

    @Test("A viewport too narrow for the header selector cluster fails closed")
    func tooNarrowForSectionControlsReturnsNil() {
        // 228pt content minus 180pt of Settings/selector chrome leaves a
        // 28pt title — below the fitted-title floor.
        #expect(KingdomLayout.compute(.init(
            sceneSize: CGSize(width: 260, height: 454),
            safeAreaInsets: .zero
        )) == nil)
    }
}
