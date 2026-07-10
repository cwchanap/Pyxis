//
//  SoldierAnimationGeometry.swift
//  Pyxis
//

import CoreGraphics

struct SoldierAnimationGeometry: Equatable {
    static let canvasSize = CGSize(width: 128, height: 128)

    let bodyRegion: CGRect

    init(type: SoldierType) {
        switch type {
        case .infantry:
            bodyRegion = CGRect(x: 0.25, y: 0, width: 0.50, height: 0.57)
        case .archer:
            bodyRegion = CGRect(x: 0.25, y: 0, width: 0.50, height: 0.59)
        case .cavalry:
            bodyRegion = CGRect(x: 0.25, y: 0, width: 0.50, height: 0.53)
        case .mage:
            bodyRegion = CGRect(x: 0.25, y: 0, width: 0.50, height: 0.58)
        case .siege:
            bodyRegion = CGRect(x: 0.25, y: 0, width: 0.50, height: 0.44)
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
