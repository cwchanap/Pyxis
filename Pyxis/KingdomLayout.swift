//
//  KingdomLayout.swift
//  Pyxis
//

import CoreGraphics

/// Pure CoreGraphics layout for the Kingdom Treasury screen (HPA-670).
/// No SpriteKit/UIKit: the scene only applies precomputed frames and the
/// math is tested without a render loop. Returns nil when the three live
/// Treasury rows cannot fit — future-section space is only reserved when
/// all three real rows fit first.
struct KingdomLayout: Equatable {
    static let sideMargin: CGFloat = 16
    static let tabBarHeight: CGFloat = 82
    static let headerHeight: CGFloat = 88
    static let minimumRowHeight: CGFloat = 80
    static let maximumRowHeight: CGFloat = 104
    static let rowGap: CGFloat = 10
    static let rowIconSize: CGFloat = 44
    static let minimumBuyHitSize: CGFloat = 44
    static let minimumTextWidth: CGFloat = 100
    /// Reserved line boxes for the four row labels (name/level/effect/price).
    /// The effect box always reserves two lines — the Drill Yard example
    /// wraps — so a row is only as short as its tallest stacked content.
    static let rowNameLineHeight: CGFloat = 18
    static let rowLevelLineHeight: CGFloat = 13
    static let rowEffectLineHeight: CGFloat = 24
    static let rowPriceLineHeight: CGFloat = 15
    static let rowLabelGap: CGFloat = 2
    static var rowLabelStackHeight: CGFloat {
        rowNameLineHeight + rowLevelLineHeight + rowEffectLineHeight
            + rowPriceLineHeight + 3 * rowLabelGap
    }

    struct Input: Equatable {
        let sceneSize: CGSize
        let safeAreaInsets: BattleChromeLayout.SafeAreaInsets
    }

    let safeFrame: CGRect
    let headerFrame: CGRect
    let titleFrame: CGRect
    let goldFrame: CGRect
    let settingsFrame: CGRect
    /// Three row frames, index-aligned with `TreasuryUpgrade.allCases`.
    let rowFrames: [CGRect]
    let iconFrames: [CGRect]
    let textFrames: [CGRect]
    /// Per-row label boxes stacked inside `textFrames` — name/level/effect/
    /// price top-down — so the scene positions labels instead of spacing
    /// them by row-height fractions that collide at short rows.
    let nameLabelFrames: [CGRect]
    let levelLabelFrames: [CGRect]
    let effectLabelFrames: [CGRect]
    let priceLabelFrames: [CGRect]
    let buyHitFrames: [CGRect]
    /// Noninteractive reservation between the last row and the tab bar for
    /// future Kingdom sections (HPA-671/672). Never hosts controls.
    let futureSectionFrame: CGRect
    let tabBarFrame: CGRect
    let tabHitFrames: [CGRect]

    static func compute(_ input: Input) -> KingdomLayout? {
        let size = input.sceneSize
        let insets = input.safeAreaInsets
        guard size.width.isFinite,
              size.height.isFinite,
              size.width > 0,
              size.height > 0,
              [insets.top, insets.left, insets.bottom, insets.right]
                .allSatisfy({ $0.isFinite && $0 >= 0 })
        else {
            return nil
        }

        let safeWidth = size.width - insets.left - insets.right
        let safeHeight = size.height - insets.top - insets.bottom
        guard safeWidth > 0, safeHeight > 0 else { return nil }

        let safeFrame = CGRect(
            x: insets.left,
            y: insets.bottom,
            width: safeWidth,
            height: safeHeight
        )

        // Content column mirrors the other chrome scenes' 16pt margins.
        let horizontalMargin = size.width <= 440
            ? sideMargin
            : max(sideMargin, min(22, size.width * 0.05))
        let contentWidth = safeWidth - horizontalMargin * 2
        guard contentWidth >= rowIconSize + minimumBuyHitSize * 2 else { return nil }
        let contentX = safeFrame.minX + horizontalMargin

        // Header: title over gold, Settings gear anchored on the right.
        let headerFrame = CGRect(
            x: contentX,
            y: safeFrame.maxY - headerHeight,
            width: contentWidth,
            height: headerHeight
        )
        let textWidth = headerFrame.width - minimumBuyHitSize - 8
        guard textWidth > 0 else { return nil }
        let titleFrame = CGRect(
            x: headerFrame.minX,
            y: headerFrame.maxY - 44,
            width: textWidth,
            height: 44
        )
        let goldFrame = CGRect(
            x: headerFrame.minX,
            y: headerFrame.minY,
            width: textWidth,
            height: 44
        )
        let settingsFrame = CGRect(
            x: headerFrame.maxX - minimumBuyHitSize,
            y: headerFrame.midY - minimumBuyHitSize / 2,
            width: minimumBuyHitSize,
            height: minimumBuyHitSize
        )

        // Tab bar is full-bleed at the bottom edge like the other scenes,
        // but its hit targets derive from the safe content column: under a
        // horizontal safe-area inset the full-bleed cells would spill
        // outside the safe frame and fail the containment guard below.
        let tabBarFrame = CGRect(
            x: horizontalMargin,
            y: 0,
            width: size.width - horizontalMargin * 2,
            height: tabBarHeight
        )
        let tabHitFrames = BattleChromeLayout.tabHitFramesInSafeArea(
            for: CGRect(
                x: contentX,
                y: tabBarFrame.minY,
                width: contentWidth,
                height: tabBarFrame.height
            ),
            safeFrame: safeFrame
        )

        // Three live rows between the header and the tab bar. Rows shrink
        // together down to the 80pt minimum (the four-line label stack);
        // when even that fails the whole layout fails closed — no row is
        // sacrificed for future sections.
        let rowsTop = headerFrame.minY - 12
        let rowsBottom = tabBarFrame.maxY + 12
        let availableHeight = rowsTop - rowsBottom - 2 * rowGap
        guard availableHeight > 0 else { return nil }
        let slotHeight = availableHeight / CGFloat(TreasuryUpgrade.allCases.count)
        let rowHeight = min(maximumRowHeight, slotHeight)
        guard rowHeight >= minimumRowHeight else { return nil }

        var rowFrames: [CGRect] = []
        var iconFrames: [CGRect] = []
        var textFrames: [CGRect] = []
        var nameLabelFrames: [CGRect] = []
        var levelLabelFrames: [CGRect] = []
        var effectLabelFrames: [CGRect] = []
        var priceLabelFrames: [CGRect] = []
        var buyHitFrames: [CGRect] = []
        for index in 0..<TreasuryUpgrade.allCases.count {
            let rowFrame = CGRect(
                x: contentX,
                y: rowsTop - CGFloat(index + 1) * rowHeight - CGFloat(index) * rowGap,
                width: contentWidth,
                height: rowHeight
            )
            let iconFrame = CGRect(
                x: rowFrame.minX + 12,
                y: rowFrame.midY - rowIconSize / 2,
                width: rowIconSize,
                height: rowIconSize
            )
            let buyHitFrame = CGRect(
                x: rowFrame.maxX - 12 - minimumBuyHitSize,
                y: rowFrame.midY - minimumBuyHitSize / 2,
                width: minimumBuyHitSize,
                height: minimumBuyHitSize
            )
            let rowTextWidth = buyHitFrame.minX - 10 - (iconFrame.maxX + 10)
            guard rowTextWidth >= minimumTextWidth else { return nil }
            let textFrame = CGRect(
                x: iconFrame.maxX + 10,
                y: rowFrame.minY,
                width: rowTextWidth,
                height: rowFrame.height
            )

            // The label stack is vertically centered in the text column; the
            // 80pt row minimum keeps the reserved boxes pairwise disjoint.
            var stackTop = textFrame.midY + Self.rowLabelStackHeight / 2
            let nameFrame = CGRect(
                x: textFrame.minX,
                y: stackTop - rowNameLineHeight,
                width: textFrame.width,
                height: rowNameLineHeight
            )
            stackTop = nameFrame.minY - rowLabelGap
            let levelFrame = CGRect(
                x: textFrame.minX,
                y: stackTop - rowLevelLineHeight,
                width: textFrame.width,
                height: rowLevelLineHeight
            )
            stackTop = levelFrame.minY - rowLabelGap
            let effectFrame = CGRect(
                x: textFrame.minX,
                y: stackTop - rowEffectLineHeight,
                width: textFrame.width,
                height: rowEffectLineHeight
            )
            stackTop = effectFrame.minY - rowLabelGap
            let priceFrame = CGRect(
                x: textFrame.minX,
                y: stackTop - rowPriceLineHeight,
                width: textFrame.width,
                height: rowPriceLineHeight
            )

            rowFrames.append(rowFrame)
            iconFrames.append(iconFrame)
            textFrames.append(textFrame)
            nameLabelFrames.append(nameFrame)
            levelLabelFrames.append(levelFrame)
            effectLabelFrames.append(effectFrame)
            priceLabelFrames.append(priceFrame)
            buyHitFrames.append(buyHitFrame)
        }

        let lastRow = rowFrames[rowFrames.count - 1]
        let futureSectionFrame = CGRect(
            x: contentX,
            y: rowsBottom,
            width: contentWidth,
            height: max(0, lastRow.minY - rowGap - rowsBottom)
        )

        guard buyHitFrames.allSatisfy({ safeFrame.contains($0) }),
              tabHitFrames.allSatisfy({ safeFrame.contains($0) && $0.width >= 44 && $0.height >= 44 })
        else {
            return nil
        }

        return KingdomLayout(
            safeFrame: safeFrame,
            headerFrame: headerFrame,
            titleFrame: titleFrame,
            goldFrame: goldFrame,
            settingsFrame: settingsFrame,
            rowFrames: rowFrames,
            iconFrames: iconFrames,
            textFrames: textFrames,
            nameLabelFrames: nameLabelFrames,
            levelLabelFrames: levelLabelFrames,
            effectLabelFrames: effectLabelFrames,
            priceLabelFrames: priceLabelFrames,
            buyHitFrames: buyHitFrames,
            futureSectionFrame: futureSectionFrame,
            tabBarFrame: tabBarFrame,
            tabHitFrames: tabHitFrames
        )
    }
}
