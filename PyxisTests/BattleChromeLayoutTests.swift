//
//  BattleChromeLayoutTests.swift
//  PyxisTests
//

import CoreGraphics
import Testing
@testable import Pyxis

struct BattleChromeLayoutTests {
    @Test func minimumFieldBudgetMatchesBattlefieldDerivation() {
        #expect(BattleChromeLayout.minimumBattlefieldHeight == 416)
        // 144 + (144 * 1.04 + 14) + (60 + 48) = 415.76, rounded up.
        #expect(Int(ceil(144 + (144 * 1.04 + 14) + 108)) == Int(BattleChromeLayout.minimumBattlefieldHeight))
        #expect(BattleChromeLayout.compactMinimumBattlefieldHeight == 340)
    }

    @Test func referencePhoneKeepsRequiredWidthsAndFieldBudget() throws {
        let layout = try #require(BattleChromeLayout.compute(.init(
            sceneSize: CGSize(width: 393, height: 852),
            safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0)
        )))

        #expect(layout.deployFrame.width == 361)
        #expect(layout.tabBarFrame.width == 361)
        #expect(layout.battlefieldFrame.height >= 424)
        #expect(layout.battlefieldFrame.height <= 440)
        #expect(layout.battlefieldFrame.minX == 16)
        #expect(layout.battlefieldFrame.maxX == 377)
        #expect(layout.manualCountFrame.isContained(in: layout.deployFrame))
        #expect(layout.battlefield.isVisible)
    }

    @Test func topBandReservesReadableCityProgressRow() throws {
        let layout = try #require(BattleChromeLayout.compute(.init(
            sceneSize: CGSize(width: 393, height: 852),
            safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0)
        )))

        #expect(layout.incomeFrame.height >= 40)
        #expect(layout.cityProgressFrame.height >= 40)
        #expect(layout.topBandFrame.contains(layout.incomeFrame))
        #expect(layout.topBandFrame.contains(layout.cityProgressFrame))
        #expect(layout.topBandFrame.contains(layout.recommendationFrame))
        #expect(!layout.cityProgressFrame.intersects(layout.recommendationFrame))
    }

    @Test func compactPhoneKeepsVisibleBattlefieldAboveCompactFloor() throws {
        let layout = try #require(BattleChromeLayout.compute(.init(
            sceneSize: CGSize(width: 375, height: 667),
            safeAreaInsets: .zero
        )))

        #expect(layout.isCompact)
        #expect(layout.battlefieldFrame.height >= BattleChromeLayout.compactMinimumBattlefieldHeight)
        #expect(layout.battlefield.isVisible)
    }

    @Test func iPadFixtureKeepsAllRequiredGeometryContained() throws {
        let layout = try #require(BattleChromeLayout.compute(.init(
            sceneSize: CGSize(width: 834, height: 1194),
            safeAreaInsets: .init(top: 24, left: 0, bottom: 20, right: 0)
        )))

        #expect(layout.safeFrame.contains(layout.tabBarFrame))
        #expect(layout.safeFrame.contains(layout.deployFrame))
        #expect(layout.safeFrame.contains(layout.battlefieldFrame))
        #expect(layout.medallionFrames.count == 5)
        #expect(layout.medallionHitFrames.allSatisfy { $0.width >= 44 && $0.height >= 44 })
    }

    @Test func laneChipsOverlayTheBattlefieldWithoutChangingItsFrame() throws {
        let layout = try #require(BattleChromeLayout.compute(.init(
            sceneSize: CGSize(width: 393, height: 852),
            safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0)
        )))

        #expect(layout.laneChipFrames.count == BattleLane.allCases.count)
        #expect(layout.laneChipFrames.values.allSatisfy { layout.battlefieldFrame.contains($0) })
        #expect(layout.battlefieldFrame.height >= 424)
    }

    @Test func impossibleSafeContentFailsClosed() {
        let layout = BattleChromeLayout.compute(.init(
            sceneSize: CGSize(width: 375, height: 667),
            safeAreaInsets: .init(top: 300, left: 180, bottom: 300, right: 180)
        ))

        #expect(layout == nil)
    }
}

private extension CGRect {
    func isContained(in other: CGRect) -> Bool {
        other.contains(self)
    }
}
