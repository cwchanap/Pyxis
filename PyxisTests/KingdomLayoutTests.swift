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

        // The four tab hit frames reuse the shared Battle chrome math.
        #expect(layout.tabHitFrames.count == GameplayTab.allCases.count)
        #expect(layout.tabHitFrames == BattleChromeLayout.tabHitFramesInSafeArea(
            for: layout.tabBarFrame,
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
            for: layout.tabBarFrame,
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

    @Test("Viewport too short for three real rows returns nil")
    func rowsDoNotFitReturnsNil() {
        // 88 (header) + 3 rows of 64 + gaps + 82 tab bar cannot fit in 330pt.
        #expect(
            KingdomLayout.compute(.init(
                sceneSize: CGSize(width: 320, height: 330),
                safeAreaInsets: .zero
            )) == nil
        )
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
}
