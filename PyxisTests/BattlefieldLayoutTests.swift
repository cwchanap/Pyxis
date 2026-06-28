//
//  BattlefieldLayoutTests.swift
//  PyxisTests
//

import Testing
import CoreGraphics
import Foundation
@testable import Pyxis

struct BattlefieldLayoutTests {
    private func makeConstraints(
        sceneWidth: CGFloat = 390,
        sceneHeight: CGFloat = 844,
        contentWidth: CGFloat? = nil,
        safeTopY: CGFloat? = nil,
        safeBottomY: CGFloat? = nil,
        feedbackY: CGFloat? = nil,
        feedbackFontSize: CGFloat = 15
    ) -> BattlefieldLayout.Constraints {
        let cw = contentWidth ?? min(sceneWidth - 36, 560)
        let top = safeTopY ?? sceneHeight - 60
        let bottom = safeBottomY ?? 120
        return BattlefieldLayout.Constraints(
            sceneSize: CGSize(width: sceneWidth, height: sceneHeight),
            contentWidth: cw,
            safeTopY: top,
            safeBottomY: bottom,
            feedbackY: feedbackY ?? bottom + 40,
            feedbackFontSize: feedbackFontSize
        )
    }

    @Test func normalLayoutIsVisible() {
        let layout = BattlefieldLayout.compute(constraints: makeConstraints())
        #expect(layout.isVisible)
        #expect(layout.structureHeight > 0)
        #expect(layout.frame.height > 0)
    }

    @Test func normalLayoutHasGatePointsForAllLanes() {
        let layout = BattlefieldLayout.compute(constraints: makeConstraints())
        for lane in BattleLane.allCases {
            #expect(layout.castleGatePoints[lane] != nil)
            #expect(layout.enemyGatePoints[lane] != nil)
        }
    }

    @Test func castleGatesAreBelowEnemyGates() {
        let layout = BattlefieldLayout.compute(constraints: makeConstraints())
        for lane in BattleLane.allCases {
            let castle = layout.castleGatePoints[lane]!
            let enemy = layout.enemyGatePoints[lane]!
            #expect(castle.y < enemy.y)
        }
    }

    @Test func lanesAreEvenlySpaced() {
        let layout = BattlefieldLayout.compute(constraints: makeConstraints())
        let xs = BattleLane.allCases.map { layout.castleGatePoints[$0]!.x }
        let gap1 = xs[1] - xs[0]
        let gap2 = xs[2] - xs[1]
        #expect(abs(gap1 - gap2) < 0.01)
    }

    @Test func lanesDivideFrameIntoEqualThirds() {
        let layout = BattlefieldLayout.compute(constraints: makeConstraints())
        let left = layout.castleGatePoints[.left]!
        let center = layout.castleGatePoints[.center]!
        let right = layout.castleGatePoints[.right]!

        #expect(abs(left.x - (layout.frame.minX + layout.frame.width / 6)) < 0.01)
        #expect(abs(center.x - layout.frame.midX) < 0.01)
        #expect(abs(right.x - (layout.frame.minX + layout.frame.width * 5 / 6)) < 0.01)
        #expect(abs((center.x - left.x) - (right.x - center.x)) < 0.01)
    }

    @Test func fallbackLanesDivideFrameIntoEqualThirds() {
        let layout = BattlefieldLayout.compute(constraints: makeConstraints(
            sceneWidth: 200,
            sceneHeight: 100,
            safeTopY: 80,
            safeBottomY: 70
        ))
        let xs = BattleLane.allCases.map { layout.castleGatePoints[$0]!.x }

        #expect(abs(xs[0] - layout.frame.minX - layout.frame.width / 6) < 0.01)
        #expect(abs(xs[1] - layout.frame.midX) < 0.01)
        #expect(abs(xs[2] - layout.frame.minX - layout.frame.width * 5 / 6) < 0.01)
    }

    @Test func tinySceneFallsBackToInvisible() {
        // Very small scene with no room for battlefield.
        let layout = BattlefieldLayout.compute(constraints: makeConstraints(
            sceneWidth: 200,
            sceneHeight: 100,
            safeTopY: 80,
            safeBottomY: 70
        ))
        #expect(!layout.isVisible)
    }

    @Test func fallbackHasCollapsedGatePoints() {
        let layout = BattlefieldLayout.compute(constraints: makeConstraints(
            sceneWidth: 200,
            sceneHeight: 100,
            safeTopY: 80,
            safeBottomY: 70
        ))
        for lane in BattleLane.allCases {
            let castle = layout.castleGatePoints[lane]!
            let enemy = layout.enemyGatePoints[lane]!
            #expect(castle == enemy)
        }
    }

    @Test func pointMapsPosition0ToCastleGate() {
        let layout = BattlefieldLayout.compute(constraints: makeConstraints())
        for lane in BattleLane.allCases {
            let p = layout.point(forLane: lane, position: 0)
            let castle = layout.castleGatePoints[lane]!
            #expect(abs(p.x - castle.x) < 0.01)
            #expect(abs(p.y - castle.y) < 0.01)
        }
    }

    @Test func pointMapsPosition1ToEnemyGate() {
        let layout = BattlefieldLayout.compute(constraints: makeConstraints())
        for lane in BattleLane.allCases {
            let p = layout.point(forLane: lane, position: 1)
            let enemy = layout.enemyGatePoints[lane]!
            #expect(abs(p.x - enemy.x) < 0.01)
            #expect(abs(p.y - enemy.y) < 0.01)
        }
    }

    @Test func pointClampsOutOfRangePositions() {
        let layout = BattlefieldLayout.compute(constraints: makeConstraints())
        let below = layout.point(forLane: .center, position: -0.5)
        let castle = layout.castleGatePoints[.center]!
        #expect(abs(below.y - castle.y) < 0.01)

        let above = layout.point(forLane: .center, position: 1.5)
        let enemy = layout.enemyGatePoints[.center]!
        #expect(abs(above.y - enemy.y) < 0.01)
    }

    @Test func enemyCityImpactPointIsCenterEnemyGate() {
        let layout = BattlefieldLayout.compute(constraints: makeConstraints())
        let impact = layout.enemyCityImpactPoint
        let centerGate = layout.enemyGatePoints[.center]!
        #expect(abs(impact.x - centerGate.x) < 0.01)
        #expect(abs(impact.y - centerGate.y) < 0.01)
    }

    @Test func enemyCityTargetHeightIsSlightlyTallerThanStructure() {
        let layout = BattlefieldLayout.compute(constraints: makeConstraints())
        #expect(layout.enemyCityTargetHeight > layout.structureHeight)
        #expect(layout.enemyCityTargetHeight == layout.structureHeight * 1.04)
    }

    @Test func enemyGateSitsAtCityBaseInsideFrameTop() {
        let layout = BattlefieldLayout.compute(constraints: makeConstraints())
        let enemyGate = layout.enemyGatePoints[.center]!
        // Gate is the city's base: one city-height plus the HP bar clearance below the frame top.
        let expectedY = layout.frame.maxY
            - BattlefieldLayout.enemyCityHPBarClearance
            - layout.enemyCityTargetHeight
        #expect(abs(enemyGate.y - expectedY) < 0.01)
        #expect(enemyGate.y < layout.frame.maxY)
        #expect(enemyGate.y >= layout.frame.minY)
    }

    @Test func enemyCityReservesRoomForHPBarAboveBody() {
        let layout = BattlefieldLayout.compute(constraints: makeConstraints())
        let enemyGate = layout.enemyGatePoints[.center]!
        let cityTopY = enemyGate.y + layout.enemyCityTargetHeight

        #expect(layout.frame.maxY - cityTopY >= BattlefieldLayout.enemyCityHPBarClearance)
    }

    @Test func lanePathWidthScalesWithSceneWidth() {
        let narrow = BattlefieldLayout.lanePathWidth(for: 200)
        let wide = BattlefieldLayout.lanePathWidth(for: 600)
        #expect(wide > narrow)
    }

    @Test func lanePathWidthHasMinAndMaxBounds() {
        let tiny = BattlefieldLayout.lanePathWidth(for: 0)
        let huge = BattlefieldLayout.lanePathWidth(for: 10_000)
        #expect(tiny >= 54)
        #expect(huge <= 180)
    }

    @Test func normalLanePathReadsAsWideBand() {
        let layout = BattlefieldLayout.compute(constraints: makeConstraints())

        #expect(layout.lanePathWidth >= layout.frame.width * 0.28)
        #expect(layout.lanePathWidth <= layout.frame.width / 3)
    }

    @Test func zeroFeedbackFontSizeDoesNotReserveTooltipClearance() {
        let safeBottomY: CGFloat = 120
        let feedbackY: CGFloat = 260
        let withoutTooltip = BattlefieldLayout.compute(constraints: makeConstraints(
            safeBottomY: safeBottomY,
            feedbackY: feedbackY,
            feedbackFontSize: 0
        ))
        let withTooltip = BattlefieldLayout.compute(constraints: makeConstraints(
            safeBottomY: safeBottomY,
            feedbackY: feedbackY,
            feedbackFontSize: 15
        ))

        #expect(abs(withoutTooltip.frame.minY - safeBottomY) < 0.01)
        #expect(withTooltip.frame.minY > withoutTooltip.frame.minY)
    }

    @Test func frameXCentersContentHorizontally() {
        let sceneWidth: CGFloat = 400
        let contentWidth: CGFloat = 300
        let layout = BattlefieldLayout.compute(constraints: makeConstraints(
            sceneWidth: sceneWidth,
            contentWidth: contentWidth
        ))
        #expect(layout.frame.minX == (sceneWidth - contentWidth) / 2)
        #expect(layout.frame.width == contentWidth)
    }

    @Test func structureHeightCappedAt144() {
        // Very tall scene — structure should still cap at the 1.5x battle-art size.
        let layout = BattlefieldLayout.compute(constraints: makeConstraints(
            sceneHeight: 2000,
            safeTopY: 1900,
            safeBottomY: 100
        ))
        #expect(layout.structureHeight <= 144)
        #expect(layout.structureHeight > 96)
    }
}
