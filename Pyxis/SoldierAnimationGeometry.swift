//
//  SoldierAnimationGeometry.swift
//  Pyxis
//

import CoreGraphics

struct SoldierAnimationGeometry: Equatable {
    static let canvasSize = CGSize(width: 128, height: 128)

    let bodyRegion: CGRect

    init(type: SoldierType) {
        // Regions are derived from the union of opaque-pixel bounds across all
        // ten walk frames of each type's regenerated 128x128 full-canvas set
        // (SK texture coordinates: origin bottom-left, y up). `minY` is the
        // transparent margin below the feet (8px = 0.0625 for every type);
        // `height` is the visible silhouette height; `maxY = minY + height`
        // is the silhouette top, where `layoutSoldierHPBar` anchors the bar.
        // Horizontally the region is centered on the canvas (midX = 0.5) so the
        // soldier stands centered on its lane; `width` is the union opaque
        // width, which leaves room for weapons/bows without clipping.
        switch type {
        case .infantry:
            bodyRegion = CGRect(x: 0.1875, y: 0.0625, width: 0.625, height: 0.734375)
        case .archer:
            bodyRegion = CGRect(x: 0.171875, y: 0.0625, width: 0.65625, height: 0.8203125)
        case .cavalry:
            bodyRegion = CGRect(x: 0.23046875, y: 0.0625, width: 0.5390625, height: 0.578125)
        case .mage:
            bodyRegion = CGRect(x: 0.25, y: 0.0625, width: 0.5, height: 0.6640625)
        case .siege:
            bodyRegion = CGRect(x: 0.12890625, y: 0.0625, width: 0.7421875, height: 0.578125)
        }
    }

    func frameSize(forBodyHeight bodyHeight: CGFloat) -> CGSize {
        let side = bodyHeight / bodyRegion.height
        return CGSize(width: side, height: side)
    }

    func logicalBodyFrame(frameSize: CGSize) -> CGRect {
        CGRect(
            x: -frameSize.width / 2 + bodyRegion.minX * frameSize.width,
            y: bodyRegion.minY * frameSize.height,
            width: bodyRegion.width * frameSize.width,
            height: bodyRegion.height * frameSize.height
        )
    }
}
