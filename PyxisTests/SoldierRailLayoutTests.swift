//
//  SoldierRailLayoutTests.swift
//  PyxisTests
//

import Testing
import CoreGraphics
@testable import Pyxis

struct SoldierRailLayoutTests {
    private let frame = CGRect(x: 0, y: 100, width: 600, height: 800)
    private let body = CGRect(x: -20, y: 4, width: 40, height: 60)
    private let canvas = CGRect(x: -32, y: 0, width: 64, height: 64)

    // MARK: - railWidth

    @Test func railWidthIsOneSixthOfFrameMinusPadding() {
        #expect(abs(SoldierRailLayout.railWidth(battlefieldFrame: frame) - 96) < 0.01)
        #expect(SoldierRailLayout.railWidth(battlefieldFrame: CGRect(x: 0, y: 0, width: 12, height: 50)) == 0)
    }

    // MARK: - seat

    @Test func railsStraddleLaneCenterByQuarterLaneWidth() {
        let center = CGPoint(x: 300, y: 500)
        let left = SoldierRailLayout.seat(
            battlefieldFrame: frame, laneCenter: center, rail: 0,
            footMargin: 0, logicalBody: body, canvas: canvas,
            rootScale: 1, gateFloorY: frame.maxY
        )
        let right = SoldierRailLayout.seat(
            battlefieldFrame: frame, laneCenter: center, rail: 1,
            footMargin: 0, logicalBody: body, canvas: canvas,
            rootScale: 1, gateFloorY: frame.maxY
        )
        #expect(abs(left.x - (300 - 50)) < 0.01)
        #expect(abs(right.x - (300 + 50)) < 0.01)
    }

    @Test func seatRestsFootMarginOnModelPoint() {
        let center = CGPoint(x: 300, y: 500)
        let seat = SoldierRailLayout.seat(
            battlefieldFrame: frame, laneCenter: center, rail: 0,
            footMargin: 10, logicalBody: body, canvas: canvas,
            rootScale: 2, gateFloorY: frame.maxY
        )
        #expect(abs(seat.y - (500 - 20)) < 0.01)
    }

    @Test func seatNeverDropsBelowBattlefieldFloor() {
        let center = CGPoint(x: 300, y: 100)
        let seat = SoldierRailLayout.seat(
            battlefieldFrame: frame, laneCenter: center, rail: 0,
            footMargin: 40, logicalBody: body, canvas: canvas,
            rootScale: 1, gateFloorY: frame.maxY
        )
        // bottom = frame.minY - min(body.minY, canvas.minY) * scale = 100
        #expect(seat.y >= 100)
        #expect(abs(seat.y - 100) < 0.01)
    }

    @Test func seatKeepsCanvasInsideBattlefieldTop() {
        let center = CGPoint(x: 300, y: 880)
        let seat = SoldierRailLayout.seat(
            battlefieldFrame: frame, laneCenter: center, rail: 0,
            footMargin: 0, logicalBody: body, canvas: canvas,
            rootScale: 1, gateFloorY: 1000
        )
        // top = frame.maxY - canvas.maxY * scale = 900 - 64 = 836
        #expect(abs(seat.y - 836) < 0.01)
    }

    @Test func seatClearsGateFloorWithReadableBodyAndBar() {
        let center = CGPoint(x: 300, y: 880)
        let seat = SoldierRailLayout.seat(
            battlefieldFrame: frame, laneCenter: center, rail: 0,
            footMargin: 0, logicalBody: body, canvas: canvas,
            rootScale: 1, gateFloorY: 800
        )
        // top = min(836, 800 - 2 - (64 + 6.5)) = 727.5
        #expect(abs(seat.y - 727.5) < 0.01)
    }

    @Test func seatHoldsFloorWhenGateClampBeatsIt() {
        let center = CGPoint(x: 300, y: 880)
        let seat = SoldierRailLayout.seat(
            battlefieldFrame: frame, laneCenter: center, rail: 0,
            footMargin: 0, logicalBody: body, canvas: canvas,
            rootScale: 1, gateFloorY: 60
        )
        // top would be 60 - 2 - 70.5 < bottom 100, so the floor wins.
        #expect(seat.y >= 100)
    }

    // MARK: - maxStep

    @Test func maxStepCoversProjectedMarchPlusGlide() {
        let step = SoldierRailLayout.maxStep(
            marchPointsPerSecond: 285, glidePointsPerSecond: 200, elapsed: 1.0 / 60
        )
        #expect(abs(step - 485.0 / 60) < 0.01)
    }

    @Test func maxStepIsZeroForNonPositiveElapsed() {
        #expect(SoldierRailLayout.maxStep(
            marchPointsPerSecond: 285, glidePointsPerSecond: 200, elapsed: 0
        ) == 0)
        #expect(SoldierRailLayout.maxStep(
            marchPointsPerSecond: 285, glidePointsPerSecond: 200, elapsed: -1
        ) == 0)
    }

    /// The resolved review invariant: a live soldier's rendered position
    /// must keep pace with the model projection — a glide budget that
    /// ignored march speed left infantry ~165 points behind when its
    /// first attack landed on an iPad-sized lane.
    @Test func renderedSoldierNeverLagsModelMarch() {
        let march: CGFloat = 285
        let dt: Double = 1.0 / 60
        var rendered = CGPoint(x: 300, y: 200)
        var modelY: CGFloat = 200
        for _ in 0..<120 {
            modelY += march * CGFloat(dt)
            let ideal = CGPoint(x: 300, y: modelY)
            rendered = SoldierRailLayout.advanced(
                from: rendered, toward: ideal,
                maxStep: SoldierRailLayout.maxStep(
                    marchPointsPerSecond: march,
                    glidePointsPerSecond: 200,
                    elapsed: dt
                )
            )
        }
        #expect(abs(rendered.y - modelY) < 0.01)
    }

    // MARK: - advanced

    @Test func advancedReachesIdealWithinStep() {
        let moved = SoldierRailLayout.advanced(
            from: CGPoint(x: 0, y: 0), toward: CGPoint(x: 30, y: 40), maxStep: 50
        )
        #expect(moved == CGPoint(x: 30, y: 40))
    }

    @Test func advancedCoversAtMostMaxStep() {
        let moved = SoldierRailLayout.advanced(
            from: CGPoint(x: 0, y: 0), toward: CGPoint(x: 30, y: 40), maxStep: 25
        )
        #expect(abs(hypot(moved.x, moved.y) - 25) < 0.01)
        #expect(abs(moved.x - 15) < 0.01)
        #expect(abs(moved.y - 20) < 0.01)
    }

    @Test func advancedIsStableOnZeroDistanceAndZeroStep() {
        let atIdeal = SoldierRailLayout.advanced(
            from: CGPoint(x: 10, y: 10), toward: CGPoint(x: 10, y: 10), maxStep: 50
        )
        #expect(atIdeal == CGPoint(x: 10, y: 10))
        let frozen = SoldierRailLayout.advanced(
            from: CGPoint(x: 0, y: 0), toward: CGPoint(x: 30, y: 40), maxStep: 0
        )
        #expect(frozen == .zero)
    }

    // MARK: - overflow badge geometry

    @Test func overflowBadgeLaneBudgetIsOneLaneColumnMinusPadding() {
        // 600/3 - 8 = 192; a narrow frame falls back to the 28pt floor.
        #expect(abs(SoldierRailLayout.overflowBadgeLaneBudget(battlefieldFrame: frame) - 192) < 0.01)
        #expect(SoldierRailLayout.overflowBadgeLaneBudget(
            battlefieldFrame: CGRect(x: 0, y: 0, width: 60, height: 50)
        ) == 28)
    }

    @Test func overflowBadgePillPadsLabelAndFloorsAtMinimum() {
        // A short count still gets the 36pt pill; a longer one gets
        // label + 16 padding.
        #expect(SoldierRailLayout.overflowBadgePillWidth(labelWidth: 4, laneBudget: 200) == 36)
        #expect(SoldierRailLayout.overflowBadgePillWidth(labelWidth: 40, laneBudget: 200) == 56)
    }

    @Test func overflowBadgePillNeverOutgrowsItsLaneBudget() {
        #expect(SoldierRailLayout.overflowBadgePillWidth(labelWidth: 500, laneBudget: 192) == 192)
    }

    @Test func overflowBadgeCenterClampsWholePillInsideBattlefield() {
        // Pill half-width 50: an anchor under the left edge pins at
        // minX + 50, under the right edge at maxX - 50, and an interior
        // anchor passes through untouched.
        let left = SoldierRailLayout.overflowBadgeCenter(
            battlefieldFrame: frame, anchorX: 2, pillWidth: 100, badgeHeight: 16
        )
        #expect(left.x == frame.minX + 50)
        let right = SoldierRailLayout.overflowBadgeCenter(
            battlefieldFrame: frame, anchorX: 590, pillWidth: 100, badgeHeight: 16
        )
        #expect(right.x == frame.maxX - 50)
        let mid = SoldierRailLayout.overflowBadgeCenter(
            battlefieldFrame: frame, anchorX: 300, pillWidth: 100, badgeHeight: 16
        )
        #expect(mid.x == 300)
        // The badge always rests just above the battlefield floor.
        #expect(mid.y == frame.minY + 16 / 2 + 2)
    }

    // MARK: - BattlefieldLayout.laneLength

    @Test func laneLengthMatchesProjectedGateDistance() {
        let layout = BattlefieldLayout.compute(constraints: BattlefieldLayout.Constraints(
            sceneSize: CGSize(width: 390, height: 844),
            contentWidth: min(390 - 36, 560),
            safeTopY: 844 - 60,
            safeBottomY: 120,
            feedbackY: 160,
            feedbackFontSize: 15
        ))
        for lane in BattleLane.allCases {
            let start = layout.point(forLane: lane, position: 0)
            let end = layout.point(forLane: lane, position: 1)
            #expect(abs(layout.laneLength(forLane: lane) - hypot(end.x - start.x, end.y - start.y)) < 0.01)
        }
    }
}
