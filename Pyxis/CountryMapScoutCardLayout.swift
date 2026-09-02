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
            exposedLaneFrame: emptyFrame,
            attackFrame: attackFrame,
            overlayFrame: informationRegionFrame,
            nonBlockingOverlayFrame: nonBlockingOverlayFrame
        )
    }

    private static func phone(in informationRegionFrame: CGRect) -> Self {
        let cardFrame = CGRect(
            x: informationRegionFrame.minX,
            y: max(0, informationRegionFrame.minY - 24),
            width: informationRegionFrame.width,
            height: informationRegionFrame.height + 72
        )
        let contentFrame = cardFrame.insetBy(dx: 14, dy: 10)
        let attackFrame = CGRect(
            x: contentFrame.minX,
            y: cardFrame.minY + 20,
            width: contentFrame.width,
            height: 46
        )
        let topTraitLine = CGRect(
            x: cardFrame.minX + 96,
            y: cardFrame.maxY - 73,
            width: cardFrame.width - 110,
            height: 14
        )
        let bottomTraitLine = CGRect(
            x: topTraitLine.minX,
            y: topTraitLine.minY - 14,
            width: topTraitLine.width,
            height: 14
        )
        let badgeFrame = CGRect(
            x: cardFrame.minX + 96,
            y: cardFrame.maxY - 20,
            width: 80,
            height: 12
        )
        let goldIconFrame = CGRect(
            x: cardFrame.maxX - 73,
            y: cardFrame.maxY - 27,
            width: 15,
            height: 15
        )
        let rewardFrame = CGRect(
            x: goldIconFrame.maxX + 5,
            y: cardFrame.maxY - 34,
            width: 39,
            height: 28
        )
        let titleFrame = CGRect(
            x: badgeFrame.minX,
            y: cardFrame.maxY - 52,
            width: 128,
            height: 24
        )
        let favorableFrame = CGRect(
            x: contentFrame.minX,
            y: cardFrame.minY + 108,
            width: contentFrame.width,
            height: 30
        )
        let disadvantagedFrame = CGRect(
            x: contentFrame.minX,
            y: cardFrame.minY + 70,
            width: contentFrame.width,
            height: 30
        )
        let exposedLaneFrame = CGRect(
            x: cardFrame.maxX - 129,
            y: titleFrame.minY,
            width: 115,
            height: titleFrame.height
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
