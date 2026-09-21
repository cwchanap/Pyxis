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

    @Test func referencePhonePinsForgedBandsToCanonicalTopOrigin() throws {
        let sceneHeight: CGFloat = 852
        let layout = try #require(BattleChromeLayout.compute(.init(
            sceneSize: CGSize(width: 393, height: sceneHeight),
            safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0)
        )))

        func topOrigin(_ frame: CGRect) -> CGRect {
            CGRect(
                x: frame.minX,
                y: sceneHeight - frame.maxY,
                width: frame.width,
                height: frame.height
            )
        }

        let income = topOrigin(layout.incomeFrame)
        let settings = topOrigin(layout.settingsFrame)
        let city = topOrigin(layout.cityProgressFrame)
        let recommendation = topOrigin(layout.recommendationFrame)
        let battlefield = topOrigin(layout.battlefieldFrame)
        let medallion = topOrigin(try #require(layout.medallionFrames.first))
        let deploy = topOrigin(layout.deployFrame)
        let tabs = topOrigin(layout.tabBarFrame)

        #expect(income == CGRect(x: 16, y: 56, width: 160, height: 46))
        #expect(settings == CGRect(x: 331, y: 56, width: 46, height: 46))
        #expect(layout.topBandFrame.maxY == sceneHeight)
        #expect(city.minY == 112)
        #expect(city.height == 48)
        #expect(recommendation == CGRect(x: 16, y: 168, width: 361, height: 48))
        #expect(battlefield.minY == 216)
        #expect(battlefield.height >= 424)
        #expect(battlefield.height <= 440)
        #expect(medallion == CGRect(x: 16, y: 642, width: 56, height: 56))
        #expect(deploy == CGRect(x: 16, y: 704, width: 361, height: 58))
        #expect(tabs.minY == 770)
        #expect(tabs.height == 82)
        #expect(layout.medallionHitFrames.allSatisfy { $0.width >= 44 && $0.height >= 44 })
        #expect(layout.tabHitFrames.allSatisfy { $0.width >= 44 && $0.height >= 44 })
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

        #expect(layout.sceneFrame.contains(layout.tabBarFrame))
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

    @Test func laneChipHitFramesPinThreeExpandedTargetsInsideTheBattlefield() throws {
        let layout = try #require(BattleChromeLayout.compute(.init(
            sceneSize: CGSize(width: 393, height: 852),
            safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0)
        )))

        #expect(layout.laneChipHitFrames.count == BattleLane.allCases.count)
        for lane in BattleLane.allCases {
            let visual = try #require(layout.laneChipFrames[lane])
            let hit = try #require(layout.laneChipHitFrames[lane])
            // Visual chips keep their authored 26pt height.
            #expect(visual.height == 26)
            // Hit targets expand around the visual center and clear 44×44.
            #expect(hit.width >= 44)
            #expect(hit.height >= 44)
            #expect(abs(hit.midX - visual.midX) < 0.001)
            #expect(abs(hit.midY - visual.midY) < 0.001)
            #expect(hit.contains(visual))
            // Everything stays inside the battlefield.
            #expect(layout.battlefieldFrame.contains(hit))
        }
    }

    @Test func compactLaneChipHitFramesStayInsideTheBattlefield() throws {
        let layout = try #require(BattleChromeLayout.compute(.init(
            sceneSize: CGSize(width: 375, height: 667),
            safeAreaInsets: .zero
        )))

        #expect(layout.isCompact)
        #expect(layout.laneChipHitFrames.count == BattleLane.allCases.count)
        #expect(layout.laneChipHitFrames.values.allSatisfy {
            $0.width >= 44 && $0.height >= 44 && layout.battlefieldFrame.contains($0)
        })
    }

    @Test func laneChipHitFramesNeverOverlapUnrelatedHUDChrome() throws {
        let layout = try #require(BattleChromeLayout.compute(.init(
            sceneSize: CGSize(width: 393, height: 852),
            safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0)
        )))

        let unrelatedFrames = [
            layout.deployFrame,
            layout.tabBarFrame,
            layout.incomeFrame,
            layout.cityProgressFrame,
            layout.recommendationFrame,
            layout.settingsFrame
        ] + layout.medallionHitFrames + layout.tabHitFrames
        for hit in layout.laneChipHitFrames.values {
            for frame in unrelatedFrames {
                #expect(!hit.intersects(frame))
            }
        }
    }

    // MARK: - HPA-475 Task 4: Deploy/Captain split (pure geometry)

    @Test func deployCaptainSubframesSplitAndStayDisjointOnAllFixtures() throws {
        let fixtures: [(String, BattleChromeLayout.Input)] = [
            ("375x667", .init(sceneSize: CGSize(width: 375, height: 667))),
            (
                "393x852",
                .init(
                    sceneSize: CGSize(width: 393, height: 852),
                    safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0)
                )
            ),
            (
                "iPad 834x1194",
                .init(
                    sceneSize: CGSize(width: 834, height: 1194),
                    safeAreaInsets: .init(top: 24, left: 0, bottom: 20, right: 0)
                )
            )
        ]

        for (_, input) in fixtures {
            let layout = try #require(BattleChromeLayout.compute(input))

            // Authored split: 132pt strip flush right, 8pt gap, action is the remainder.
            #expect(layout.captainStripFrame.width == 132)
            #expect(layout.captainStripFrame.maxX == layout.deployFrame.maxX)
            #expect(layout.captainStripFrame.minY == layout.deployFrame.minY)
            #expect(layout.captainStripFrame.height == layout.deployFrame.height)
            #expect(layout.deployActionFrame.minX == layout.deployFrame.minX)
            #expect(layout.deployActionFrame.maxX == layout.captainStripFrame.minX - 8)
            #expect(layout.deployActionFrame.height == layout.deployFrame.height)
            #expect(
                layout.rallyHitFrame == CGRect(
                    x: layout.captainStripFrame.maxX - 44,
                    y: layout.captainStripFrame.minY,
                    width: 44,
                    height: layout.captainStripFrame.height
                )
            )

            // Containment and minimums.
            for frame in [layout.deployActionFrame, layout.captainStripFrame, layout.rallyHitFrame] {
                #expect(layout.deployFrame.contains(frame))
            }
            #expect(layout.deployActionFrame.width >= 196)
            #expect(layout.rallyHitFrame.width >= 44)
            #expect(layout.rallyHitFrame.height >= 44)

            // Hit targets are pairwise disjoint; the rally hit lives inside the strip.
            #expect(!layout.deployActionFrame.intersects(layout.captainStripFrame))
            #expect(!layout.deployActionFrame.intersects(layout.rallyHitFrame))
            #expect(layout.captainStripFrame.contains(layout.rallyHitFrame))
        }
    }

    @Test func narrowestFixtureLeavesThePinned203PointDeployAction() throws {
        let layout = try #require(BattleChromeLayout.compute(.init(
            sceneSize: CGSize(width: 375, height: 667)
        )))

        #expect(layout.deployFrame.width == 343)
        // 343 - 132 - 8 = 203.
        #expect(layout.deployActionFrame.width == 203)
        #expect(layout.captainStripFrame.minX == layout.deployFrame.minX + 203 + 8)
    }

    @Test func artificiallyNarrowDeployWidthFailsClosed() {
        // 375 - 4 - 4 = 367 safe → content 335 → deploy action 195 < 196.
        let layout = BattleChromeLayout.compute(.init(
            sceneSize: CGSize(width: 375, height: 667),
            safeAreaInsets: .init(top: 0, left: 4, bottom: 0, right: 4)
        ))

        #expect(layout == nil)
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
