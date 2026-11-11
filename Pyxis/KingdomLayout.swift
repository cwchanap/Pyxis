//
//  KingdomLayout.swift
//  Pyxis
//

import CoreGraphics

/// HPA-671/672 ephemeral Kingdom tab sections. Never persisted:
/// switching sections neither settles nor saves. Lives beside the layout
/// (not the scene) — the layout sizes one selector per case, so the
/// section list is layout-owned, never scene-owned.
enum KingdomSection: Equatable, CaseIterable {
    case treasury
    case armory
    case ascend

    var displayName: String {
        switch self {
        case .treasury:
            return "Treasury"
        case .armory:
            return "Armory"
        case .ascend:
            return "Ascend"
        }
    }
}

/// Pure CoreGraphics layout for the Kingdom Treasury/Armory/Ascend
/// screen (HPA-670, HPA-671, HPA-672). No SpriteKit/UIKit: the scene only
/// applies precomputed frames and the math is tested without a render
/// loop. Returns nil when the three live Treasury rows cannot fit — the
/// Armory and Ascend sections reuse the SAME content band, so they fit
/// wherever Treasury does.
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
    /// HPA-672 header section controls: three adaptive ≥44pt targets in
    /// the header's top 44pt line, 8pt left of Settings, Treasury → Armory
    /// → Ascend. With the visible title gone (the tab bar identifies the
    /// screen; accessibility keeps a constant `Kingdom` header) the free
    /// width distributes across the cluster: (available − 2 gaps) / 3,
    /// capped at 88pt. At 320pt that is ~70.7pt per selector; at the 232pt
    /// content floor ~52pt — the rows starve before the cluster does.
    static let sectionSelectorMinimumWidth: CGFloat = 44
    static let sectionSelectorMaximumWidth: CGFloat = 88
    static let sectionSelectorHeight: CGFloat = 44
    static let sectionSelectorGap: CGFloat = 8
    /// HPA-672 Renown bottom-header box: right-aligned in the gold line,
    /// clear of the Settings column. The reservation yields to keep gold
    /// a usable measured column (≥ ~80pt) but never shrinks below the
    /// minimum a fitted "Renown N · +N%" needs on the narrowest layout.
    static let renownLabelMinimumWidth: CGFloat = 88
    static let renownLabelMaximumWidth: CGFloat = 120
    static let goldRenownGap: CGFloat = 8
    /// The gold text width the Renown reservation must leave intact.
    static let minimumGoldTextWidth: CGFloat = 96
    /// HPA-672 Ascend band: one panel sharing the Treasury/Armory content
    /// band, an emblem up top, four stacked lines (bonus, resets, keeps and
    /// the visible unlock requirement), and two ≥44pt actions anchored at
    /// the band's bottom clear of the tab bar. The Resets/Keeps disclosure
    /// lines wrap once (their reserved boxes are two lines tall) so every
    /// required fact stays legible at the compact widths. The stack needs
    /// ~255pt — always inside the ≥260pt band the three Treasury rows
    /// already guarantee, so Ascend never becomes the binding constraint.
    static let ascendBandInset: CGFloat = 12
    static let ascendIconSize: CGFloat = 44
    static let ascendIconGap: CGFloat = 10
    static let ascendBonusLineHeight: CGFloat = 18
    static let ascendPreviewLineHeight: CGFloat = 15
    /// Reserved height for the once-wrapped disclosure lines: two 13pt
    /// AvenirNext lines render ~38pt tall (the fitter only ever shrinks
    /// them, so this is the tallest they get).
    static let ascendPreviewTwoLineHeight: CGFloat = 38
    static let ascendStackGap: CGFloat = 6
    static let ascendActionHeight: CGFloat = 44
    static let ascendActionGap: CGFloat = 8
    /// HPA-671 alternative Armory band: one whole-row target per soldier
    /// type in the same span the Treasury rows occupy — (260 − 4×6) / 5 =
    /// 47.2pt rows at the 320×454 boundary, capped at 60pt on taller
    /// viewports. Derived from `SoldierType.allCases` so a future type
    /// automatically gets its own row instead of overflowing the band.
    static let armoryRowCount = SoldierType.allCases.count
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
    let goldFrame: CGRect
    let settingsFrame: CGRect
    /// Treasury/Armory/Ascend section controls in the header's top line.
    let treasurySelectorFrame: CGRect
    let armorySelectorFrame: CGRect
    let ascendSelectorFrame: CGRect
    /// Right-aligned Renown box in the header's bottom (gold) line —
    /// visible only when the ascension count is positive.
    let renownFrame: CGRect
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
    let armoryChevronFrames: [CGRect]
    /// Two compact stacked lines per Armory row (type/equipped, then
    /// effect/next drop) inside `armoryTextFrames`.
    let armoryLine1LabelFrames: [CGRect]
    let armoryLine2LabelFrames: [CGRect]
    /// HPA-672 Ascend content sharing the same band: one panel, an emblem
    /// frame, four stacked label boxes and the Confirm/Cancel targets.
    let ascendPanelFrame: CGRect
    let ascendIconFrame: CGRect
    let ascendBonusLabelFrame: CGRect
    let ascendResetsLabelFrame: CGRect
    let ascendKeepsLabelFrame: CGRect
    /// The visible unlock requirement line under Keeps — the one addition
    /// to the summary stack (review: sighted players must be able to
    /// inspect the requirement, not just hear it).
    let ascendRequirementLabelFrame: CGRect
    let ascendPrimaryActionFrame: CGRect
    let ascendCancelFrame: CGRect
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
        let settingsFrame = CGRect(
            x: headerFrame.maxX - minimumBuyHitSize - 4,
            y: headerFrame.midY - minimumBuyHitSize / 2,
            width: minimumBuyHitSize,
            height: minimumBuyHitSize
        )

        // HPA-672: three adaptive section controls share the header's top
        // 44pt line — no visible title (the selected tab identifies the
        // screen; accessibility keeps a constant `Kingdom` header label).
        // Zero new header height; the bottom 44pt gold line keeps an inset
        // column with a right-aligned Renown reservation.
        let headerTopLine = Self.headerTopLineFrames(
            headerFrame: headerFrame,
            settingsFrame: settingsFrame
        )
        guard let headerTopLine else { return nil }
        let treasurySelectorFrame = headerTopLine.treasurySelectorFrame
        let armorySelectorFrame = headerTopLine.armorySelectorFrame
        let ascendSelectorFrame = headerTopLine.ascendSelectorFrame
        let goldFrame = CGRect(
            x: headerFrame.minX + 8,
            y: headerFrame.minY,
            width: settingsFrame.minX - headerFrame.minX - 8,
            height: 44
        )
        let textWidth = goldFrame.width
        guard textWidth > 0 else { return nil }
        // The 8pt gold/Renown gap is part of the reservation: leave it
        // inside the Renown column so the gold text keeps its documented
        // `minimumGoldTextWidth` — subtracting the gap again in
        // `goldTextMaxWidth` would shrink gold 8pt below the minimum.
        let renownWidth = min(
            renownLabelMaximumWidth,
            max(renownLabelMinimumWidth, textWidth - minimumGoldTextWidth - goldRenownGap)
        )
        let renownFrame = CGRect(
            x: goldFrame.maxX - renownWidth,
            y: headerFrame.minY,
            width: renownWidth,
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
            rowsTop: rowsTop - (rowsTop - rowsBottom
                - CGFloat(TreasuryUpgrade.allCases.count) * rowHeight - 2 * rowGap) / 2,
            rowHeight: rowHeight
        )
        guard let treasuryBand else { return nil }

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

        // HPA-672: the Ascend content shares the SAME band — no second
        // content area, no scrolling, no new header height.
        let ascendBand = Self.ascendBandFrames(
            contentX: contentX,
            contentWidth: contentWidth,
            rowsTop: rowsTop,
            rowsBottom: rowsBottom
        )
        guard let ascendBand else { return nil }

        guard treasuryBand.buyHitFrames.allSatisfy({ safeFrame.contains($0) }),
              tabHitFrames.allSatisfy({ safeFrame.contains($0) && $0.width >= 44 && $0.height >= 44 })
        else {
            return nil
        }

        return KingdomLayout(
            safeFrame: safeFrame,
            headerFrame: headerFrame,
            goldFrame: goldFrame,
            settingsFrame: settingsFrame,
            treasurySelectorFrame: treasurySelectorFrame,
            armorySelectorFrame: armorySelectorFrame,
            ascendSelectorFrame: ascendSelectorFrame,
            renownFrame: renownFrame,
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
            armoryChevronFrames: armoryBand.chevronFrames,
            armoryLine1LabelFrames: armoryBand.line1LabelFrames,
            armoryLine2LabelFrames: armoryBand.line2LabelFrames,
            ascendPanelFrame: ascendBand.panelFrame,
            ascendIconFrame: ascendBand.iconFrame,
            ascendBonusLabelFrame: ascendBand.bonusLabelFrame,
            ascendResetsLabelFrame: ascendBand.resetsLabelFrame,
            ascendKeepsLabelFrame: ascendBand.keepsLabelFrame,
            ascendRequirementLabelFrame: ascendBand.requirementLabelFrame,
            ascendPrimaryActionFrame: ascendBand.primaryActionFrame,
            ascendCancelFrame: ascendBand.cancelFrame,
            tabBarFrame: tabBarFrame,
            tabHitFrames: tabHitFrames
        )
    }

    /// The measured gold-label width: the full gold line, or the column
    /// left of the Renown reservation when the Renown label is visible.
    func goldTextMaxWidth(showingRenown: Bool) -> CGFloat {
        guard showingRenown else { return goldFrame.width }
        return renownFrame.minX - Self.goldRenownGap - goldFrame.minX
    }

    /// Header top-line frames for one compute pass: three adaptive
    /// ≥44pt section controls right-aligned 8pt left of Settings. Nil
    /// only when even the 44pt minimum cannot fit — the Treasury rows'
    /// own floor starves first on every accepted viewport.
    private struct HeaderTopLine {
        let treasurySelectorFrame: CGRect
        let armorySelectorFrame: CGRect
        let ascendSelectorFrame: CGRect
    }

    private static func headerTopLineFrames(
        headerFrame: CGRect,
        settingsFrame: CGRect
    ) -> HeaderTopLine? {
        let topLineMinY = headerFrame.maxY - sectionSelectorHeight
        let available = settingsFrame.minX - sectionSelectorGap - headerFrame.minX - 4
        let count = CGFloat(KingdomSection.allCases.count)
        let width = min(
            sectionSelectorMaximumWidth,
            (available - (count - 1) * sectionSelectorGap) / count
        )
        guard width >= sectionSelectorMinimumWidth else { return nil }
        // Treasury → Armory → Ascend, left to right, ending 8pt left of
        // Settings.
        let clusterMinX = settingsFrame.minX - sectionSelectorGap
            - count * width - (count - 1) * sectionSelectorGap
        func selectorFrame(_ index: Int) -> CGRect {
            CGRect(
                x: clusterMinX + CGFloat(index) * (width + sectionSelectorGap),
                y: topLineMinY,
                width: width,
                height: sectionSelectorHeight
            )
        }
        return HeaderTopLine(
            treasurySelectorFrame: selectorFrame(0),
            armorySelectorFrame: selectorFrame(1),
            ascendSelectorFrame: selectorFrame(2)
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
        let chevronFrames: [CGRect]
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
        var chevronFrames: [CGRect] = []
        var line1LabelFrames: [CGRect] = []
        var line2LabelFrames: [CGRect] = []
        let centeredTop = rowsTop - (rowsTop - rowsBottom
            - CGFloat(armoryRowCount) * rowHeight - CGFloat(armoryRowCount - 1) * armoryRowGap) / 2
        for index in 0..<armoryRowCount {
            let rowFrame = CGRect(
                x: contentX,
                y: centeredTop - CGFloat(index + 1) * rowHeight - CGFloat(index) * armoryRowGap,
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
            chevronFrames.append(CGRect(x: rowFrame.maxX - 9, y: rowFrame.midY - 4, width: 8, height: 8))
            line1LabelFrames.append(line1Frame)
            line2LabelFrames.append(line2Frame)
        }
        return ArmoryBand(
            rowFrames: rowFrames,
            iconFrames: iconFrames,
            textFrames: textFrames,
            chevronFrames: chevronFrames,
            line1LabelFrames: line1LabelFrames,
            line2LabelFrames: line2LabelFrames
        )
    }

    /// The HPA-672 Ascend content in the band the Treasury/Armory rows
    /// span: one panel, an emblem top-center, bonus/resets/keeps label
    /// boxes stacked below it, and the Confirm/Cancel targets anchored at
    /// the band's bottom. Nil when the stack cannot fit (impossible while
    /// Treasury fits — the band is ≥260pt and the stack needs ~255pt).
    private struct AscendBand {
        let panelFrame: CGRect
        let iconFrame: CGRect
        let bonusLabelFrame: CGRect
        let resetsLabelFrame: CGRect
        let keepsLabelFrame: CGRect
        let requirementLabelFrame: CGRect
        let primaryActionFrame: CGRect
        let cancelFrame: CGRect
    }

    private static func ascendBandFrames(
        contentX: CGFloat,
        contentWidth: CGFloat,
        rowsTop: CGFloat,
        rowsBottom: CGFloat
    ) -> AscendBand? {
        let panelFrame = CGRect(
            x: contentX,
            y: rowsBottom,
            width: contentWidth,
            height: rowsTop - rowsBottom
        )
        let iconFrame = CGRect(
            x: panelFrame.midX - ascendIconSize / 2,
            y: rowsTop - ascendBandInset - ascendIconSize,
            width: ascendIconSize,
            height: ascendIconSize
        )
        let textWidth = contentWidth - ascendBandInset * 2
        guard textWidth >= minimumTextWidth else { return nil }
        func lineFrame(under upperMinY: CGFloat, gap: CGFloat, height: CGFloat) -> CGRect {
            CGRect(
                x: contentX + ascendBandInset,
                y: upperMinY - gap - height,
                width: textWidth,
                height: height
            )
        }
        let bonusLabelFrame = lineFrame(
            under: iconFrame.minY,
            gap: ascendIconGap,
            height: ascendBonusLineHeight
        )
        let resetsLabelFrame = lineFrame(
            under: bonusLabelFrame.minY,
            gap: ascendStackGap,
            height: ascendPreviewTwoLineHeight
        )
        let keepsLabelFrame = lineFrame(
            under: resetsLabelFrame.minY,
            gap: ascendStackGap,
            height: ascendPreviewTwoLineHeight
        )
        let requirementLabelFrame = lineFrame(
            under: keepsLabelFrame.minY,
            gap: ascendStackGap,
            height: ascendPreviewLineHeight
        )
        let actionWidth = max(
            minimumBuyHitSize,
            (contentWidth - ascendBandInset * 2 - ascendActionGap) / 2
        )
        let actionY = rowsBottom + ascendBandInset
        let primaryActionFrame = CGRect(
            x: panelFrame.maxX - ascendBandInset - actionWidth,
            y: actionY,
            width: actionWidth,
            height: ascendActionHeight
        )
        let cancelFrame = CGRect(
            x: contentX + ascendBandInset,
            y: actionY,
            width: actionWidth,
            height: ascendActionHeight
        )
        guard requirementLabelFrame.minY >= primaryActionFrame.maxY + ascendStackGap else {
            return nil
        }
        return AscendBand(
            panelFrame: panelFrame,
            iconFrame: iconFrame,
            bonusLabelFrame: bonusLabelFrame,
            resetsLabelFrame: resetsLabelFrame,
            keepsLabelFrame: keepsLabelFrame,
            requirementLabelFrame: requirementLabelFrame,
            primaryActionFrame: primaryActionFrame,
            cancelFrame: cancelFrame
        )
    }
}
