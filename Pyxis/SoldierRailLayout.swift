//
//  SoldierRailLayout.swift
//  Pyxis
//

import CoreGraphics

/// Pure-value geometry for the two-rail soldier presentation in `BattleScene`.
///
/// The scene measures each rail owner's body/canvas bounds, foot margin, root
/// scale, and the siege HP bar's gate clearance, then applies the seat and
/// march-through values computed here — keeping the containment and motion
/// invariants testable without a running scene.
enum SoldierRailLayout {
    /// HP-bar dimensions shared by `BattleScene.layoutSoldierHPBar` and the
    /// rail/footprint containment bounds below.
    static let hpBarHeight: CGFloat = 5
    static let hpBarBodyGap: CGFloat = 1.5
    static var hpBarTopOffset: CGFloat { hpBarHeight + hpBarBodyGap }

    /// Horizontal room each rail seat budgets inside its lane column —
    /// one sixth of the battlefield per rail, minus padding.
    static func railWidth(battlefieldFrame: CGRect) -> CGFloat {
        max(0, battlefieldFrame.width / 6 - 4)
    }

    /// Target body height for a rail owner — capped by the rail width's
    /// 74:98 widest-frame envelope so neighbours stay clear of each other.
    static func railBodyHeight(battlefieldFrame: CGRect, targetHeight: CGFloat) -> CGFloat {
        min(targetHeight, railWidth(battlefieldFrame: battlefieldFrame) * 74 / 98)
    }

    /// Bookkeeping position for a folded (hidden) soldier root, kept inside
    /// `battlefieldFrame` without touching rail placement.
    static func foldedPosition(
        battlefieldFrame: CGRect,
        laneCenter: CGPoint,
        logicalBodyMaxY: CGFloat
    ) -> CGPoint {
        let maxY = max(
            battlefieldFrame.minY,
            battlefieldFrame.maxY - logicalBodyMaxY - hpBarTopOffset
        )
        return CGPoint(
            x: laneCenter.x,
            y: min(max(laneCenter.y, battlefieldFrame.minY), maxY)
        )
    }

    /// The seated position for a rail owner: `laneCenter` is the model
    /// position projected onto the lane path; rail 0 sits a quarter
    /// lane-width to its left, rail 1 to its right. Vertically the seat
    /// rests the body's foot margin on the model point, clamped so the
    /// bundle's full canvas stays inside the battlefield and the readable
    /// body plus HP bar clears `gateFloorY` (the siege bar's lower edge)
    /// by 2 points. When the gate clamp beats the floor, the floor wins.
    static func seat(
        battlefieldFrame: CGRect,
        laneCenter: CGPoint,
        rail: Int,
        footMargin: CGFloat,
        logicalBody: CGRect,
        canvas: CGRect,
        rootScale: CGFloat,
        gateFloorY: CGFloat
    ) -> CGPoint {
        let laneWidth = battlefieldFrame.width / 3
        let bottom = battlefieldFrame.minY - min(logicalBody.minY, canvas.minY) * rootScale
        let top = min(
            battlefieldFrame.maxY - canvas.maxY * rootScale,
            gateFloorY - 2 - (logicalBody.maxY + hpBarTopOffset) * rootScale
        )
        return CGPoint(
            x: laneCenter.x + (rail == 0 ? -laneWidth / 4 : laneWidth / 4),
            y: min(max(laneCenter.y - footMargin * rootScale, bottom), max(bottom, top))
        )
    }

    /// Rendered reservation rectangle for a soldier node at `position`
    /// covering the full sprite canvas unioned with its HP bar.
    static func renderedFootprint(
        at position: CGPoint,
        scale: CGFloat,
        horizontalBounds: ClosedRange<CGFloat>,
        verticalBounds: (footMargin: CGFloat, bodyMaxY: CGFloat),
        accumulatedBodyFrame: CGRect
    ) -> CGRect {
        let width = (horizontalBounds.upperBound - horizontalBounds.lowerBound) * scale
        let bottom = min(verticalBounds.footMargin, accumulatedBodyFrame.minY)
        let top = max(verticalBounds.bodyMaxY + hpBarTopOffset, accumulatedBodyFrame.maxY)
        return CGRect(
            x: position.x + horizontalBounds.lowerBound * scale,
            y: position.y + bottom * scale,
            width: width,
            height: max(4, (top - bottom) * scale)
        )
    }

    /// Readable presentation rectangle for a soldier node at `position` —
    /// logical walk-pose body unioned with its HP bar at `scale`.
    static func readableFootprint(
        at position: CGPoint,
        scale: CGFloat,
        logicalBody: CGRect,
        barExtentWidth: CGFloat,
        footMargin: CGFloat
    ) -> CGRect {
        let barHalfWidth = barExtentWidth / 2
        let minX = min(logicalBody.minX, -barHalfWidth)
        let maxX = max(logicalBody.maxX, barHalfWidth)
        return CGRect(
            x: position.x + minX * scale,
            y: position.y + footMargin * scale,
            width: (maxX - minX) * scale,
            height: (logicalBody.maxY + hpBarTopOffset - footMargin) * scale
        )
    }

    /// The per-sync presentation step allowance: the soldier's own
    /// projected march speed always passes through — the rendered node
    /// must never fall behind a model position it can track — plus the
    /// glide budget that eases seat and clamp changes instead of popping.
    static func maxStep(
        marchPointsPerSecond: CGFloat,
        glidePointsPerSecond: CGFloat,
        elapsed: Double
    ) -> CGFloat {
        (marchPointsPerSecond + glidePointsPerSecond) * CGFloat(max(0, elapsed))
    }

    /// Presentation motion toward `ideal`, covering at most `maxStep`
    /// points — the elapsed-clocked glide that keeps seat refits and clamp
    /// shifts from popping while staying deterministic per sync.
    static func advanced(
        from current: CGPoint,
        toward ideal: CGPoint,
        maxStep: CGFloat
    ) -> CGPoint {
        let deltaX = ideal.x - current.x
        let deltaY = ideal.y - current.y
        let distance = hypot(deltaX, deltaY)
        guard distance > 0 else { return current }
        let fraction = min(1, max(0, maxStep) / distance)
        return CGPoint(x: current.x + deltaX * fraction, y: current.y + deltaY * fraction)
    }

    /// Horizontal padding the "+N" overflow pill adds around its measured
    /// count text — also the shrink loop's fit budget: the font shrinks
    /// until `labelWidth + padding` clears the lane budget, so a truthful
    /// count never crops.
    static let overflowBadgeTextPadding: CGFloat = 16

    /// The smallest "+N" pill — short counts still get a readable badge.
    static let overflowBadgeMinPillWidth: CGFloat = 36

    /// Horizontal room the "+N" overflow pill may occupy: its lane column
    /// minus padding, floored so narrow battlefields keep a usable budget.
    /// Past this width the font shrinks rather than the pill spilling over
    /// a neighbouring lane's ground.
    static func overflowBadgeLaneBudget(battlefieldFrame: CGRect) -> CGFloat {
        max(28, battlefieldFrame.width / 3 - 8)
    }

    /// The pill width for a measured count label: padded, floored for
    /// short counts, and capped by the lane budget so a long count can
    /// never outgrow its lane column.
    static func overflowBadgePillWidth(labelWidth: CGFloat, laneBudget: CGFloat) -> CGFloat {
        min(laneBudget, max(overflowBadgeMinPillWidth, labelWidth + overflowBadgeTextPadding))
    }

    /// The badge center: `anchorX` clamped so the whole pill stays inside
    /// the battlefield either way — a wide count under a lane edge must
    /// not push chrome off the field — pinned just above the floor under
    /// its lane column.
    static func overflowBadgeCenter(
        battlefieldFrame: CGRect,
        anchorX: CGFloat,
        pillWidth: CGFloat,
        badgeHeight: CGFloat
    ) -> CGPoint {
        let pillHalf = pillWidth / 2
        return CGPoint(
            x: min(
                max(anchorX, battlefieldFrame.minX + pillHalf),
                battlefieldFrame.maxX - pillHalf
            ),
            y: battlefieldFrame.minY + badgeHeight / 2 + 2
        )
    }
}
