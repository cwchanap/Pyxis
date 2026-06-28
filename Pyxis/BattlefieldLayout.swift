//
//  BattlefieldLayout.swift
//  Pyxis
//

import CoreGraphics
import Foundation

/// Pure-value battlefield geometry computed from scene dimensions and layout constraints.
///
/// `BattlefieldLayout` owns no SpriteKit nodes — it only calculates positions and sizes.
/// `BattleScene` calls ``compute(constraints:)`` then applies the resulting values to its nodes.
struct BattlefieldLayout: Equatable {
    /// Vertical space reserved above the enemy city for its battlefield HP bar.
    static let enemyCityHPBarClearance: CGFloat = 14

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
        let safeTopY = constraints.safeTopY
        let feedbackClearance = constraints.feedbackFontSize > 0
            ? max(30, constraints.feedbackFontSize + 18)
            : 0
        let safeBottomY = feedbackClearance > 0
            ? max(constraints.safeBottomY, constraints.feedbackY + feedbackClearance)
            : constraints.safeBottomY

        let layoutFrame = CGRect(
            x: (constraints.sceneSize.width - constraints.contentWidth) / 2,
            y: safeBottomY,
            width: constraints.contentWidth,
            height: max(0, safeTopY - safeBottomY)
        )
        let availableHeight = safeTopY - safeBottomY

        let minimumStructureHeight: CGFloat = 28
        let minimumLaneLength: CGFloat = 60
        let maximumStructureHeightForLaneLength = max(
            0,
            (availableHeight - Self.enemyCityHPBarClearance - minimumLaneLength) / 2.04
        )
        let structureHeight = min(
            144,
            constraints.sceneSize.height * 0.24,
            constraints.contentWidth * 0.45,
            max(0, availableHeight * 0.48),
            maximumStructureHeightForLaneLength
        )

        let laneWidth = min(layoutFrame.width / 3, Self.lanePathWidth(for: layoutFrame.width))

        // The enemy city sits inside the top of the frame, so its height eats into
        // the marching lane the same way the castle's height does at the bottom.
        let enemyCityHeight = structureHeight * 1.04 + Self.enemyCityHPBarClearance

        // Fallback: not enough room for a proper battlefield.
        guard availableHeight >= 44,
              structureHeight >= minimumStructureHeight,
              (safeTopY - enemyCityHeight) - (safeBottomY + structureHeight) >= minimumLaneLength else {
            let fallbackY = safeBottomY
                + max(10, (safeTopY - safeBottomY) * 0.25)
            var fallbackGates: [BattleLane: CGPoint] = [:]
            for lane in BattleLane.allCases {
                let x = Self.laneCenterX(in: layoutFrame, lane: lane)
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
        let enemyGateY = safeTopY - enemyCityHeight

        var castleGates: [BattleLane: CGPoint] = [:]
        var enemyGates: [BattleLane: CGPoint] = [:]
        for lane in BattleLane.allCases {
            let x = Self.laneCenterX(in: layoutFrame, lane: lane)
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
        max(54, min(180, sceneWidth * 0.30))
    }

    private static func laneCenterX(in frame: CGRect, lane: BattleLane) -> CGFloat {
        switch lane {
        case .left:
            return frame.minX + frame.width / 6
        case .center:
            return frame.midX
        case .right:
            return frame.minX + frame.width * 5 / 6
        }
    }

    /// The target height for the enemy-city node (slightly taller than the castle).
    var enemyCityTargetHeight: CGFloat {
        structureHeight * 1.04
    }
}
