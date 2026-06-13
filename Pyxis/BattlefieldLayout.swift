//
//  BattlefieldLayout.swift
//  Pyxis
//

import CoreGraphics
import Foundation

/// Pure-value battlefield geometry computed from scene dimensions and layout constraints.
///
/// `BattlefieldLayout` owns no SpriteKit nodes — it only calculates positions and sizes.
/// `BattleScene` calls ``compute(sceneSize:contentWidth:safeTopY:safeBottomY:feedbackY:feedbackFontSize:)``
/// then applies the resulting values to its nodes.
struct BattlefieldLayout: Equatable {
    /// The axis-aligned region occupied by the battlefield (between HUD bottom and controls top).
    let frame: CGRect

    /// Height of the castle and enemy-city structures, in points.
    let structureHeight: CGFloat

    /// Per-lane gate positions at the player-castle end of the battlefield.
    let castleGatePoints: [BattleLane: CGPoint]

    /// Per-lane gate positions at the enemy-city end of the battlefield.
    let enemyGatePoints: [BattleLane: CGPoint]

    /// Whether the battlefield area is large enough to render.
    let isVisible: Bool

    /// Width of the lane path in points.
    let lanePathWidth: CGFloat

    // MARK: - Input constraints

    /// Describes the vertical bounds the battlefield must fit inside.
    struct Constraints: Equatable {
        let sceneSize: CGSize
        let contentWidth: CGFloat
        let safeTopY: CGFloat
        let safeBottomY: CGFloat
        let feedbackY: CGFloat
        let feedbackFontSize: CGFloat
    }

    // MARK: - Computation

    /// Compute a layout from the given constraints.
    ///
    /// Returns a layout with ``isVisible`` set to `true` when there is enough room
    /// for structures and lanes; otherwise returns a fallback layout with collapsed
    /// gate points.
    static func compute(constraints: Constraints) -> BattlefieldLayout {
        let verticalPadding: CGFloat = 8
        let feedbackClearance = max(30, constraints.feedbackFontSize + 18)
        let safeTopY = constraints.safeTopY
        let safeBottomY = max(constraints.safeBottomY, constraints.feedbackY + feedbackClearance)

        let layoutFrame = CGRect(
            x: (constraints.sceneSize.width - constraints.contentWidth) / 2,
            y: safeBottomY,
            width: constraints.contentWidth,
            height: max(0, safeTopY - safeBottomY)
        )
        let availableHeight = safeTopY - safeBottomY

        let structureHeight = min(
            96,
            constraints.sceneSize.height * 0.16,
            constraints.contentWidth * 0.30,
            max(0, availableHeight * 0.32)
        )
        let minimumStructureHeight: CGFloat = 28
        let minimumLaneLength: CGFloat = 60

        let laneWidth = Self.lanePathWidth(for: constraints.sceneSize.width)

        // Fallback: not enough room for a proper battlefield.
        guard availableHeight >= 44,
              structureHeight >= minimumStructureHeight,
              safeTopY - (safeBottomY + structureHeight) >= minimumLaneLength else {
            let fallbackY = safeBottomY
                + max(10, (safeTopY - safeBottomY) * 0.25)
            var fallbackGates: [BattleLane: CGPoint] = [:]
            for lane in BattleLane.allCases {
                let x = constraints.sceneSize.width * (0.25 + 0.25 * CGFloat(lane.rawValue))
                fallbackGates[lane] = CGPoint(x: x, y: fallbackY)
            }
            return BattlefieldLayout(
                frame: layoutFrame,
                structureHeight: structureHeight,
                castleGatePoints: fallbackGates,
                enemyGatePoints: fallbackGates,
                isVisible: false,
                lanePathWidth: laneWidth
            )
        }

        let castleGateY = safeBottomY + structureHeight
        let enemyGateY = safeTopY

        var castleGates: [BattleLane: CGPoint] = [:]
        var enemyGates: [BattleLane: CGPoint] = [:]
        for lane in BattleLane.allCases {
            let x = layoutFrame.minX
                + layoutFrame.width * (0.25 + 0.25 * CGFloat(lane.rawValue))
            castleGates[lane] = CGPoint(x: x, y: castleGateY)
            enemyGates[lane] = CGPoint(x: x, y: enemyGateY)
        }

        return BattlefieldLayout(
            frame: layoutFrame,
            structureHeight: structureHeight,
            castleGatePoints: castleGates,
            enemyGatePoints: enemyGates,
            isVisible: true,
            lanePathWidth: laneWidth
        )
    }

    // MARK: - Helpers

    /// Map a combat position (0–1) in a lane to a scene-space point.
    func point(forLane lane: BattleLane, position: Double) -> CGPoint {
        let clamped = CGFloat(min(max(0, position), 1))
        let start = castleGatePoints[lane] ?? .zero
        let end = enemyGatePoints[lane] ?? start
        return CGPoint(
            x: start.x + (end.x - start.x) * clamped,
            y: start.y + (end.y - start.y) * clamped
        )
    }

    /// The scene-space center of the enemy city impact point (center lane gate).
    var enemyCityImpactPoint: CGPoint {
        enemyGatePoints[.center] ?? .zero
    }

    /// Compute the lane path width for a given scene width.
    static func lanePathWidth(for sceneWidth: CGFloat) -> CGFloat {
        max(14, min(26, sceneWidth * 0.05))
    }

    /// The target height for the enemy-city node (slightly taller than the castle).
    var enemyCityTargetHeight: CGFloat {
        structureHeight * 1.04
    }
}
