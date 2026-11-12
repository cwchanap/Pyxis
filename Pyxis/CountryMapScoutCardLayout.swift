import CoreGraphics

struct CountryMapScoutCardLayout: Equatable {
    let layoutClass: CountryMapLayoutClass
    let cardFrame: CGRect
    let badgeFrame: CGRect
    let titleFrame: CGRect
    let goldIconFrame: CGRect
    let rewardFrame: CGRect
    let traitLineFrames: [CGRect]
    let favorableFrame: CGRect
    let disadvantagedFrame: CGRect
    let exposedLaneFrame: CGRect
    let attackFrame: CGRect
    let overlayFrame: CGRect
    let nonBlockingOverlayFrame: CGRect

    var isCompact: Bool {
        layoutClass == .phone
            && cardFrame.height <= CountryMapLayout.minimumCompactInformationHeight
    }

    static func compute(
        in informationRegionFrame: CGRect,
        layoutClass: CountryMapLayoutClass
    ) -> Self {
        guard informationRegionFrame.width.isFinite,
              informationRegionFrame.height.isFinite,
              informationRegionFrame.width > 0,
              informationRegionFrame.height > 0
        else {
            return Self.empty(in: informationRegionFrame, layoutClass: layoutClass)
        }

        if layoutClass == .phone,
           informationRegionFrame.height <= CountryMapLayout.minimumCompactInformationHeight {
            return compactPhone(in: informationRegionFrame)
        }

        switch layoutClass {
        case .phone:
            if informationRegionFrame.height < 132 {
                return shortPhone(in: informationRegionFrame)
            }
            return phone(in: informationRegionFrame)
        case .pad:
            return pad(in: informationRegionFrame)
        }
    }

    private static func shortPhone(in cardFrame: CGRect) -> Self {
        let left = cardFrame.minX + 8
        let attack = CGRect(x: cardFrame.maxX - 84, y: cardFrame.midY - 22, width: 76, height: 44)
        let infoMaxX = attack.minX - 8
        let usesSingleTraitRow = cardFrame.height < 54
        let row = min(14, (cardFrame.height - 4) / (usesSingleTraitRow ? 4 : 5))
        let top = cardFrame.maxY - 2
        let badge = CGRect(x: left, y: top - row, width: 36, height: row)
        let gold = CGRect(x: infoMaxX - 54, y: top - row, width: min(14, row), height: row)
        let reward = CGRect(x: infoMaxX - 39, y: top - row, width: 39, height: row)
        let title = CGRect(x: badge.maxX + 4, y: top - row,
                           width: gold.minX - 4 - (badge.maxX + 4), height: row)
        let lane = CGRect(x: infoMaxX - 90, y: top - (usesSingleTraitRow ? 2 : 3) * row, width: 90, height: row)
        let traitWidth = lane.minX - 4 - left
        var traits = [CGRect(x: left, y: top - 2 * row, width: traitWidth, height: row)]
        if !usesSingleTraitRow {
            traits.append(CGRect(x: left, y: top - 3 * row, width: traitWidth, height: row))
        }
        let favorable = CGRect(
            x: left, y: top - (usesSingleTraitRow ? 3 : 4) * row, width: infoMaxX - left, height: row)
        let disadvantaged = CGRect(
            x: left, y: top - (usesSingleTraitRow ? 4 : 5) * row, width: infoMaxX - left, height: row)
        return Self(
            layoutClass: .phone, cardFrame: cardFrame, badgeFrame: badge, titleFrame: title,
            goldIconFrame: gold, rewardFrame: reward, traitLineFrames: traits,
            favorableFrame: favorable, disadvantagedFrame: disadvantaged, exposedLaneFrame: lane,
            attackFrame: attack, overlayFrame: cardFrame,
            nonBlockingOverlayFrame: CGRect(x: cardFrame.minX, y: cardFrame.minY,
                                            width: attack.minX - cardFrame.minX, height: cardFrame.height)
        )
    }

    private static func compactPhone(in informationRegionFrame: CGRect) -> Self {
        let contentFrame = informationRegionFrame.insetBy(dx: 8, dy: 2)
        let attackWidth: CGFloat = min(96, max(70, contentFrame.width * 0.28))
        let attackFrame = CGRect(
            x: contentFrame.maxX - attackWidth,
            y: informationRegionFrame.midY - 22,
            width: attackWidth,
            height: 44
        )
        let badgeFrame = CGRect(
            x: contentFrame.minX,
            y: informationRegionFrame.midY - 11,
            width: 22,
            height: 22
        )
        let titleFrame = CGRect(
            x: badgeFrame.maxX + 4,
            y: informationRegionFrame.midY - 11,
            width: max(0, attackFrame.minX - 8 - (badgeFrame.maxX + 4)),
            height: 22
        )
        // Compact tactical lane footer (HPA-468): the freed strip below the
        // title row carries the measured footer ("L Tower · C/R Gate" or
        // "Open: <lane>") so Falconridge still presents it on compact
        // phones. The Attack button stays clear to the right.
        let exposedLaneFrame = CGRect(
            x: contentFrame.minX,
            y: contentFrame.minY,
            width: max(0, attackFrame.minX - 8 - contentFrame.minX),
            height: max(0, titleFrame.minY - contentFrame.minY)
        )
        let emptyFrame = CGRect(x: contentFrame.minX, y: contentFrame.minY, width: 0, height: 0)
        let nonBlockingOverlayFrame = CGRect(
            x: informationRegionFrame.minX,
            y: informationRegionFrame.minY,
            width: attackFrame.minX - informationRegionFrame.minX,
            height: informationRegionFrame.height
        )

        return Self(
            layoutClass: .phone,
            cardFrame: informationRegionFrame,
            badgeFrame: badgeFrame,
            titleFrame: titleFrame,
            goldIconFrame: emptyFrame,
            rewardFrame: emptyFrame,
            traitLineFrames: [],
            favorableFrame: emptyFrame,
            disadvantagedFrame: emptyFrame,
            exposedLaneFrame: exposedLaneFrame,
            attackFrame: attackFrame,
            overlayFrame: informationRegionFrame,
            nonBlockingOverlayFrame: nonBlockingOverlayFrame
        )
    }

    private static func phone(in informationRegionFrame: CGRect) -> Self {
        let cardFrame = informationRegionFrame
        let contentFrame = cardFrame.insetBy(dx: 14, dy: 10)
        let attackFrame = CGRect(
            x: contentFrame.minX,
            y: cardFrame.minY + 6,
            width: contentFrame.width,
            height: 44
        )
        let laneX = contentFrame.maxX - 115
        let topTraitLine = CGRect(
            x: cardFrame.minX + 64,
            y: cardFrame.maxY - 38,
            width: laneX - 4 - (cardFrame.minX + 64),
            height: 14
        )
        let bottomTraitLine = CGRect(
            x: topTraitLine.minX,
            y: topTraitLine.minY - 14,
            width: topTraitLine.width,
            height: 14
        )
        let badgeFrame = CGRect(
            x: cardFrame.minX + 64,
            y: cardFrame.maxY - 24,
            width: 40,
            height: 16
        )
        let goldIconFrame = CGRect(
            x: cardFrame.maxX - 73,
            y: cardFrame.maxY - 24,
            width: 15,
            height: 15
        )
        let rewardFrame = CGRect(
            x: goldIconFrame.maxX + 5,
            y: cardFrame.maxY - 24,
            width: 39,
            height: 16
        )
        let titleFrame = CGRect(
            x: badgeFrame.maxX + 4,
            y: cardFrame.maxY - 24,
            width: goldIconFrame.minX - 4 - (badgeFrame.maxX + 4),
            height: 16
        )
        // Adaptive portrait rows (HPA-812 follow-up): the repacked card
        // leaves a slack band between the lane row and Attack. The footer
        // rows buy the authored 8pt inter-row gap first, then grow evenly
        // toward the authored 30pt scale, keeping a ≥4pt gap under the lane
        // row and the existing 2pt gap above Attack. The tightest supported
        // card keeps the original 14pt adjacent rows.
        let footerBandTop = bottomTraitLine.minY
        let footerBandBottom = attackFrame.maxY + 2
        let footerBand = footerBandTop - footerBandBottom
        let footerRowHeight = min(30, max(14, floor((footerBand - 12) / 2)))
        let footerRowGap: CGFloat = footerBand >= 2 * footerRowHeight + 12 ? 8 : 0
        let disadvantagedFrame = CGRect(
            x: contentFrame.minX,
            y: footerBandBottom,
            width: contentFrame.width,
            height: footerRowHeight
        )
        let favorableFrame = CGRect(
            x: contentFrame.minX,
            y: disadvantagedFrame.maxY + footerRowGap,
            width: contentFrame.width,
            height: footerRowHeight
        )
        let exposedLaneFrame = CGRect(
            x: laneX,
            y: bottomTraitLine.minY,
            width: 115,
            height: 14
        )
        let nonBlockingOverlayFrame = CGRect(
            x: cardFrame.minX,
            y: attackFrame.maxY,
            width: cardFrame.width,
            height: cardFrame.maxY - attackFrame.maxY
        )

        return Self(
            layoutClass: .phone,
            cardFrame: cardFrame,
            badgeFrame: badgeFrame,
            titleFrame: titleFrame,
            goldIconFrame: goldIconFrame,
            rewardFrame: rewardFrame,
            traitLineFrames: [topTraitLine, bottomTraitLine],
            favorableFrame: favorableFrame,
            disadvantagedFrame: disadvantagedFrame,
            exposedLaneFrame: exposedLaneFrame,
            attackFrame: attackFrame,
            overlayFrame: cardFrame,
            nonBlockingOverlayFrame: nonBlockingOverlayFrame
        )
    }

    private static func pad(in informationRegionFrame: CGRect) -> Self {
        let contentFrame = informationRegionFrame.insetBy(dx: 12, dy: 8)
        let attackFrame = CGRect(
            x: contentFrame.maxX - 96,
            y: informationRegionFrame.midY - 26,
            width: 96,
            height: 52
        )
        let informationalMaxX = attackFrame.minX - 12
        let headerFrame = CGRect(
            x: contentFrame.minX,
            y: contentFrame.maxY - 32,
            width: informationalMaxX - contentFrame.minX,
            height: 32
        )
        let topTraitLine = CGRect(
            x: contentFrame.minX,
            y: headerFrame.minY - 4 - 14,
            width: headerFrame.width,
            height: 14
        )
        let bottomTraitLine = CGRect(
            x: contentFrame.minX,
            y: topTraitLine.minY - 14,
            width: headerFrame.width,
            height: 14
        )
        let favorableFrame = CGRect(
            x: contentFrame.minX,
            y: bottomTraitLine.minY - 4 - 14,
            width: headerFrame.width,
            height: 14
        )
        let secondFooterLine = CGRect(
            x: contentFrame.minX,
            y: favorableFrame.minY - 14,
            width: headerFrame.width,
            height: 14
        )
        let badgeFrame = CGRect(x: headerFrame.minX, y: headerFrame.minY, width: 32, height: 32)
        let goldIconFrame = CGRect(
            x: headerFrame.maxX - 70,
            y: headerFrame.midY - 9,
            width: 18,
            height: 18
        )
        let rewardFrame = CGRect(
            x: goldIconFrame.maxX + 4,
            y: headerFrame.minY,
            width: 48,
            height: 32
        )
        let titleFrame = CGRect(
            x: badgeFrame.maxX + 8,
            y: headerFrame.minY,
            width: max(0, goldIconFrame.minX - 8 - (badgeFrame.maxX + 8)),
            height: 32
        )
        let exposedLaneFrame = CGRect(
            x: secondFooterLine.maxX - 82,
            y: secondFooterLine.minY,
            width: 82,
            height: 14
        )
        let disadvantagedFrame = CGRect(
            x: secondFooterLine.minX,
            y: secondFooterLine.minY,
            width: max(0, exposedLaneFrame.minX - 12 - secondFooterLine.minX),
            height: 14
        )
        let nonBlockingOverlayFrame = CGRect(
            x: informationRegionFrame.minX,
            y: informationRegionFrame.minY,
            width: attackFrame.minX - informationRegionFrame.minX,
            height: informationRegionFrame.height
        )

        return Self(
            layoutClass: .pad,
            cardFrame: informationRegionFrame,
            badgeFrame: badgeFrame,
            titleFrame: titleFrame,
            goldIconFrame: goldIconFrame,
            rewardFrame: rewardFrame,
            traitLineFrames: [topTraitLine, bottomTraitLine],
            favorableFrame: favorableFrame,
            disadvantagedFrame: disadvantagedFrame,
            exposedLaneFrame: exposedLaneFrame,
            attackFrame: attackFrame,
            overlayFrame: informationRegionFrame,
            nonBlockingOverlayFrame: nonBlockingOverlayFrame
        )
    }

    private static func empty(
        in informationRegionFrame: CGRect,
        layoutClass: CountryMapLayoutClass
    ) -> Self {
        let point = CGPoint(x: informationRegionFrame.minX, y: informationRegionFrame.minY)
        let frame = CGRect(origin: point, size: .zero)
        return Self(
            layoutClass: layoutClass,
            cardFrame: informationRegionFrame,
            badgeFrame: frame,
            titleFrame: frame,
            goldIconFrame: frame,
            rewardFrame: frame,
            traitLineFrames: [],
            favorableFrame: frame,
            disadvantagedFrame: frame,
            exposedLaneFrame: frame,
            attackFrame: frame,
            overlayFrame: informationRegionFrame,
            nonBlockingOverlayFrame: frame
        )
    }
}
