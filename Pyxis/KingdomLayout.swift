//
//  KingdomLayout.swift
//  Pyxis
//

import CoreGraphics

/// Pure CoreGraphics layout for the Kingdom Treasury/Armory screen
/// (HPA-670, HPA-671). No SpriteKit/UIKit: the scene only applies
/// precomputed frames and the math is tested without a render loop.
/// Returns nil when the three live Treasury rows cannot fit — the
/// Armory section (HPA-671) reuses the SAME content band, so it fits
/// wherever Treasury does; future-section space is only reserved when
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
    /// HPA-671 header section controls: two adjacent 60×44 targets in the
    /// header's top 44pt line, 8pt left of Settings. The boundary
    /// arithmetic is binding: at 320×454 zero-inset the 288pt content
    /// column spends 180pt on Settings + controls + gaps, leaving exactly
    /// the authored 100pt title plus the 8pt `titleSpareWidth`. The
    /// fail-closed floor is the width the shrunk title still needs, not
    /// the authored allocation — a starved-but-usable content column
    /// (e.g. under a large side inset) keeps fitting.
    static let sectionSelectorSize = CGSize(width: 60, height: 44)
    static let sectionSelectorGap: CGFloat = 8
    static let minimumTitleWidth: CGFloat = 60
    /// The 8pt spare the boundary leaves between the 100pt title
    /// allocation and the selector cluster — never absorbed by the
    /// font-shrunk title.
    static let titleSpareWidth: CGFloat = 8
    /// HPA-671 alternative Armory band: five whole-row targets in the same
    /// span the Treasury rows occupy — (260 − 4×6) / 5 = 47.2pt rows at the
    /// 320×454 boundary, capped at 60pt on taller viewports.
    static let armoryRowCount = 5
    static let armoryRowGap: CGFloat = 6
    static let armoryMinimumRowHeight: CGFloat = 44
    static let armoryMaximumRowHeight: CGFloat = 60
    static let armoryIconSize: CGFloat = 32
    static let armoryLine1LineHeight: CGFloat = 18
    static let armoryLine2LineHeight: CGFloat = 14
    static let armoryLabelGap: CGFloat = 2
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
    /// HPA-671 Treasury/Armory section controls in the header's top line.
    let treasurySelectorFrame: CGRect
    let armorySelectorFrame: CGRect
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
    /// HPA-671 Armory rows, index-aligned with `SoldierType.allCases`.
    /// Whole-row hit targets: the row frame IS the tap target.
    let armoryRowFrames: [CGRect]
    let armoryIconFrames: [CGRect]
    let armoryTextFrames: [CGRect]
    /// Two compact stacked lines per Armory row (type/equipped, then
    /// effect/next drop) inside `armoryTextFrames`.
    let armoryLine1LabelFrames: [CGRect]
    let armoryLine2LabelFrames: [CGRect]
    /// Noninteractive reservation between the last row and the tab bar for
    /// future Kingdom sections (HPA-672). Never hosts controls.
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
        let settingsFrame = CGRect(
            x: headerFrame.maxX - minimumBuyHitSize,
            y: headerFrame.midY - minimumBuyHitSize / 2,
            width: minimumBuyHitSize,
            height: minimumBuyHitSize
        )

        // HPA-671: the Treasury/Armory controls sit in the header's top
        // 44pt line and the title frame shrinks around them. Zero new
        // header height; the bottom 44pt gold line keeps the full width.
        let headerTopLine = Self.headerTopLineFrames(
            headerFrame: headerFrame,
            settingsFrame: settingsFrame,
            textWidth: textWidth
        )
        guard let headerTopLine else { return nil }
        let titleFrame = headerTopLine.titleFrame
        let treasurySelectorFrame = headerTopLine.treasurySelectorFrame
        let armorySelectorFrame = headerTopLine.armorySelectorFrame
        let goldFrame = CGRect(
            x: headerFrame.minX,
            y: headerFrame.minY,
            width: textWidth,
            height: 44
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

        let treasuryBand = Self.treasuryBandFrames(
            contentX: contentX,
            contentWidth: contentWidth,
            rowsTop: rowsTop,
            rowHeight: rowHeight
        )
        guard let treasuryBand else { return nil }

        let lastRow = treasuryBand.rowFrames[treasuryBand.rowFrames.count - 1]
        let futureSectionFrame = CGRect(
            x: contentX,
            y: rowsBottom,
            width: contentWidth,
            height: max(0, lastRow.minY - rowGap - rowsBottom)
        )

        // HPA-671 alternative Armory layout: five whole-row targets in the
        // SAME band the Treasury rows span (rowsTop…rowsBottom). The guard
        // cannot fail while Treasury fits (band ≥ 260 ⇒ slot ≥ 47.2), but
        // the layout stays fail-closed on its own terms.
        let armoryBand = Self.armoryBandFrames(
            contentX: contentX,
            contentWidth: contentWidth,
            rowsTop: rowsTop,
            rowsBottom: rowsBottom
        )
        guard let armoryBand else { return nil }

        guard treasuryBand.buyHitFrames.allSatisfy({ safeFrame.contains($0) }),
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
            treasurySelectorFrame: treasurySelectorFrame,
            armorySelectorFrame: armorySelectorFrame,
            rowFrames: treasuryBand.rowFrames,
            iconFrames: treasuryBand.iconFrames,
            textFrames: treasuryBand.textFrames,
            nameLabelFrames: treasuryBand.nameLabelFrames,
            levelLabelFrames: treasuryBand.levelLabelFrames,
            effectLabelFrames: treasuryBand.effectLabelFrames,
            priceLabelFrames: treasuryBand.priceLabelFrames,
            buyHitFrames: treasuryBand.buyHitFrames,
            armoryRowFrames: armoryBand.rowFrames,
            armoryIconFrames: armoryBand.iconFrames,
            armoryTextFrames: armoryBand.textFrames,
            armoryLine1LabelFrames: armoryBand.line1LabelFrames,
            armoryLine2LabelFrames: armoryBand.line2LabelFrames,
            futureSectionFrame: futureSectionFrame,
            tabBarFrame: tabBarFrame,
            tabHitFrames: tabHitFrames
        )
    }

    /// Header top-line frames for one compute pass: the width-fitted title
    /// plus the two adjacent section controls, all inside the existing
    /// 44pt title line. Nil when the title cannot fit beside the cluster.
    private struct HeaderTopLine {
        let titleFrame: CGRect
        let treasurySelectorFrame: CGRect
        let armorySelectorFrame: CGRect
    }

    private static func headerTopLineFrames(
        headerFrame: CGRect,
        settingsFrame: CGRect,
        textWidth: CGFloat
    ) -> HeaderTopLine? {
        let topLineMinY = headerFrame.maxY - sectionSelectorSize.height
        let armorySelectorFrame = CGRect(
            x: settingsFrame.minX - sectionSelectorGap - sectionSelectorSize.width,
            y: topLineMinY,
            width: sectionSelectorSize.width,
            height: sectionSelectorSize.height
        )
        let treasurySelectorFrame = CGRect(
            x: armorySelectorFrame.minX - sectionSelectorSize.width,
            y: topLineMinY,
            width: sectionSelectorSize.width,
            height: sectionSelectorSize.height
        )
        let titleWidth = min(
            textWidth,
            treasurySelectorFrame.minX - sectionSelectorGap - titleSpareWidth - headerFrame.minX
        )
        guard titleWidth >= minimumTitleWidth else { return nil }
        return HeaderTopLine(
            titleFrame: CGRect(
                x: headerFrame.minX,
                y: topLineMinY,
                width: titleWidth,
                height: sectionSelectorSize.height
            ),
            treasurySelectorFrame: treasurySelectorFrame,
            armorySelectorFrame: armorySelectorFrame
        )
    }

    /// The three Treasury row frame sets stacked top-down from `rowsTop`
    /// at the shared `rowHeight`: icon, text, the four reserved label
    /// boxes and each row's Buy hit target. Nil when the text column
    /// starves below `minimumTextWidth`.
    private struct TreasuryBand {
        let rowFrames: [CGRect]
        let iconFrames: [CGRect]
        let textFrames: [CGRect]
        let nameLabelFrames: [CGRect]
        let levelLabelFrames: [CGRect]
        let effectLabelFrames: [CGRect]
        let priceLabelFrames: [CGRect]
        let buyHitFrames: [CGRect]
    }

    private static func treasuryBandFrames(
        contentX: CGFloat,
        contentWidth: CGFloat,
        rowsTop: CGFloat,
        rowHeight: CGFloat
    ) -> TreasuryBand? {
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
            var stackTop = textFrame.midY + rowLabelStackHeight / 2
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
        return TreasuryBand(
            rowFrames: rowFrames,
            iconFrames: iconFrames,
            textFrames: textFrames,
            nameLabelFrames: nameLabelFrames,
            levelLabelFrames: levelLabelFrames,
            effectLabelFrames: effectLabelFrames,
            priceLabelFrames: priceLabelFrames,
            buyHitFrames: buyHitFrames
        )
    }

    /// The five Armory row frames stacked top-down in the band the
    /// Treasury rows span: whole-row hit targets, one icon column, one
    /// text column with two centered compact label lines. Nil when the
    /// band cannot host five ≥44pt rows (impossible while Treasury fits).
    private struct ArmoryBand {
        let rowFrames: [CGRect]
        let iconFrames: [CGRect]
        let textFrames: [CGRect]
        let line1LabelFrames: [CGRect]
        let line2LabelFrames: [CGRect]
    }

    private static func armoryBandFrames(
        contentX: CGFloat,
        contentWidth: CGFloat,
        rowsTop: CGFloat,
        rowsBottom: CGFloat
    ) -> ArmoryBand? {
        let availableHeight = rowsTop - rowsBottom
            - CGFloat(armoryRowCount - 1) * armoryRowGap
        let slotHeight = availableHeight / CGFloat(armoryRowCount)
        let rowHeight = min(armoryMaximumRowHeight, slotHeight)
        guard rowHeight >= armoryMinimumRowHeight else { return nil }

        var rowFrames: [CGRect] = []
        var iconFrames: [CGRect] = []
        var textFrames: [CGRect] = []
        var line1LabelFrames: [CGRect] = []
        var line2LabelFrames: [CGRect] = []
        for index in 0..<armoryRowCount {
            let rowFrame = CGRect(
                x: contentX,
                y: rowsTop - CGFloat(index + 1) * rowHeight - CGFloat(index) * armoryRowGap,
                width: contentWidth,
                height: rowHeight
            )
            let iconFrame = CGRect(
                x: rowFrame.minX + 12,
                y: rowFrame.midY - armoryIconSize / 2,
                width: armoryIconSize,
                height: armoryIconSize
            )
            let rowTextWidth = rowFrame.maxX - 10 - (iconFrame.maxX + 8)
            guard rowTextWidth >= minimumTextWidth else { return nil }
            let textFrame = CGRect(
                x: iconFrame.maxX + 8,
                y: rowFrame.minY,
                width: rowTextWidth,
                height: rowFrame.height
            )

            // The two compact lines stack centered in the text column; the
            // 44pt row minimum keeps the reserved boxes pairwise disjoint.
            let stackHeight = armoryLine1LineHeight + armoryLabelGap + armoryLine2LineHeight
            var stackTop = textFrame.midY + stackHeight / 2
            let line1Frame = CGRect(
                x: textFrame.minX,
                y: stackTop - armoryLine1LineHeight,
                width: textFrame.width,
                height: armoryLine1LineHeight
            )
            stackTop = line1Frame.minY - armoryLabelGap
            let line2Frame = CGRect(
                x: textFrame.minX,
                y: stackTop - armoryLine2LineHeight,
                width: textFrame.width,
                height: armoryLine2LineHeight
            )

            rowFrames.append(rowFrame)
            iconFrames.append(iconFrame)
            textFrames.append(textFrame)
            line1LabelFrames.append(line1Frame)
            line2LabelFrames.append(line2Frame)
        }
        return ArmoryBand(
            rowFrames: rowFrames,
            iconFrames: iconFrames,
            textFrames: textFrames,
            line1LabelFrames: line1LabelFrames,
            line2LabelFrames: line2LabelFrames
        )
    }
}
