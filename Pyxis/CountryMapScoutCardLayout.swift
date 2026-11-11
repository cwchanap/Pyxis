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

    /// The smallest card height that can carry the full ordinary-phone Scout
    /// repack (header, title, trait row, footer row and a >=44pt action).
    /// Shorter information regions degrade to the compact strip rather than
    /// expanding into the illustrated map.
    static let ordinaryPhoneMinimumCardHeight: CGFloat = 114

    var isCompact: Bool {
        layoutClass == .phone && traitLineFrames.isEmpty
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
           informationRegionFrame.height < ordinaryPhoneMinimumCardHeight {
            return compactPhone(in: informationRegionFrame)
        }

        switch layoutClass {
        case .phone:
            return phone(in: informationRegionFrame)
        case .pad:
            return pad(in: informationRegionFrame)
        }
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
        // The ordinary-phone card stays inside the information region like the
        // compact strip and the pad card do (HPA-812): it no longer expands
        // into the illustrated map. The Scout content is repacked into rows
        // sized from the available height — header, title+lane, trait row(s),
        // the favorable/disadvantaged footer halves and a full-width action.
        let cardFrame = informationRegionFrame
        let roomy = cardFrame.height >= 150
        let contentX = cardFrame.minX + 14
        let contentWidth = cardFrame.width - 28
        let attackHeight: CGFloat = roomy ? 46 : 44
        let footerHeight: CGFloat = roomy ? 20 : 16
        let traitRowHeight: CGFloat = roomy ? 12 : 10
        let titleHeight: CGFloat = roomy ? 18 : 15
        let headerHeight: CGFloat = roomy ? 18 : 14
        let rowGap: CGFloat = roomy ? 3 : 2
        let traitRowCount = cardFrame.height >= 124 ? 2 : 1
        // Roomier cards keep a decorative city-art column to the left of the
        // indented text rows; denser cards spend the width on the text itself.
        let artIndent: CGFloat = cardFrame.height >= 140 ? 56 : 0

        let rowsHeight = headerHeight + titleHeight
            + traitRowHeight * CGFloat(traitRowCount)
            + footerHeight + attackHeight + rowGap * 4
        let verticalPad = max(3, floor((cardFrame.height - rowsHeight) / 2))

        let attackFrame = CGRect(
            x: contentX,
            y: cardFrame.minY + verticalPad,
            width: contentWidth,
            height: attackHeight
        )
        let footerMinY = attackFrame.maxY + rowGap
        let footerHalfWidth = floor((contentWidth - 8) / 2)
        let favorableFrame = CGRect(
            x: contentX,
            y: footerMinY,
            width: footerHalfWidth,
            height: footerHeight
        )
        let disadvantagedFrame = CGRect(
            x: contentX + contentWidth - footerHalfWidth,
            y: footerMinY,
            width: footerHalfWidth,
            height: footerHeight
        )
        let textX = contentX + artIndent
        let textWidth = contentWidth - artIndent
        let bottomTraitLine = CGRect(
            x: textX,
            y: footerMinY + footerHeight + rowGap,
            width: textWidth,
            height: traitRowHeight
        )
        var traitLineFrames = [bottomTraitLine]
        if traitRowCount == 2 {
            traitLineFrames.insert(
                CGRect(
                    x: textX,
                    y: bottomTraitLine.maxY,
                    width: textWidth,
                    height: traitRowHeight
                ),
                at: 0
            )
        }
        let titleMinY = traitLineFrames[0].maxY + rowGap
        let exposedLaneWidth: CGFloat = 115
        let titleFrame = CGRect(
            x: textX,
            y: titleMinY,
            width: textWidth - exposedLaneWidth - 8,
            height: titleHeight
        )
        let exposedLaneFrame = CGRect(
            x: contentX + contentWidth - exposedLaneWidth,
            y: titleMinY,
            width: exposedLaneWidth,
            height: titleHeight
        )
        let headerMinY = titleMinY + titleHeight + rowGap
        let badgeFrame = CGRect(
            x: textX,
            y: headerMinY + (headerHeight - 10) / 2,
            width: 80,
            height: 10
        )
        let goldIconFrame = CGRect(
            x: contentX + contentWidth - 59,
            y: headerMinY + (headerHeight - 15) / 2,
            width: 15,
            height: 15
        )
        let rewardFrame = CGRect(
            x: contentX + contentWidth - 39,
            y: headerMinY,
            width: 39,
            height: headerHeight
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
            traitLineFrames: traitLineFrames,
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
