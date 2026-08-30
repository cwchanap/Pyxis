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
        let contentFrame = informationRegionFrame.insetBy(dx: 6, dy: 2)
        let attackFrame = CGRect(
            x: contentFrame.maxX - 70,
            y: informationRegionFrame.midY - 22,
            width: 70,
            height: 44
        )
        let informationalMaxX = attackFrame.minX - 6
        let headerFrame = CGRect(
            x: contentFrame.minX,
            y: contentFrame.maxY - 22,
            width: informationalMaxX - contentFrame.minX,
            height: 22
        )
        let topTraitLine = CGRect(
            x: contentFrame.minX,
            y: headerFrame.minY - 1 - 12,
            width: headerFrame.width,
            height: 12
        )
        let bottomTraitLine = CGRect(
            x: contentFrame.minX,
            y: topTraitLine.minY - 12,
            width: headerFrame.width,
            height: 12
        )
        let footerFrame = CGRect(
            x: contentFrame.minX,
            y: contentFrame.minY,
            width: headerFrame.width,
            height: 12
        )
        let badgeFrame = CGRect(x: headerFrame.minX, y: headerFrame.minY, width: 22, height: 22)
        let goldIconFrame = CGRect(
            x: headerFrame.maxX - 48,
            y: headerFrame.midY - 6,
            width: 12,
            height: 12
        )
        let rewardFrame = CGRect(
            x: goldIconFrame.maxX + 2,
            y: headerFrame.minY,
            width: 34,
            height: 22
        )
        let titleFrame = CGRect(
            x: badgeFrame.maxX + 4,
            y: headerFrame.minY + 2,
            width: max(0, goldIconFrame.minX - 4 - (badgeFrame.maxX + 4)),
            height: 22
        )
        let favorableFrame = CGRect(x: footerFrame.minX, y: footerFrame.minY, width: 106, height: 12)
        let disadvantagedFrame = CGRect(
            x: favorableFrame.maxX + 6,
            y: footerFrame.minY,
            width: 70,
            height: 12
        )
        let exposedLaneFrame = CGRect(
            x: disadvantagedFrame.maxX + 6,
            y: footerFrame.minY,
            width: max(0, footerFrame.maxX - (disadvantagedFrame.maxX + 6)),
            height: 12
        )
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
