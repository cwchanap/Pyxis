//
//  GameUIComponents.swift
//  Pyxis
//

import CoreGraphics
import SpriteKit

final class PanelNode: SKNode {
    private let background = SKShapeNode()
    private(set) var contentSize: CGSize

    init(size: CGSize) {
        self.contentSize = size
        super.init()
        background.fillColor = GameUITheme.Color.panelFill
        background.strokeColor = GameUITheme.Color.panelStroke
        background.lineWidth = 1.5
        addChild(background)
        update(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(size: CGSize) {
        contentSize = size
        background.path = CGPath(
            roundedRect: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height),
            cornerWidth: min(12, size.height / 4),
            cornerHeight: min(12, size.height / 4),
            transform: nil
        )
    }
}

final class ProgressBarNode: SKNode {
    private let background = SKShapeNode()
    private let fill = SKShapeNode()
    private var size: CGSize
    private var fillWidth: CGFloat = 0

    init(size: CGSize) {
        self.size = size
        super.init()
        background.fillColor = GameUITheme.Color.hpBackground
        background.strokeColor = GameUITheme.Color.panelStroke
        background.lineWidth = 1
        fill.fillColor = GameUITheme.Color.hpFill
        fill.strokeColor = .clear
        addChild(background)
        addChild(fill)
        update(size: size)
        update(progress: 0)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(size: CGSize) {
        let progress = self.size.width == 0 ? 0 : fillWidth / self.size.width
        self.size = size
        background.path = CGPath(
            roundedRect: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height),
            cornerWidth: size.height / 2,
            cornerHeight: size.height / 2,
            transform: nil
        )
        update(progress: progress)
    }

    func update(progress: CGFloat) {
        fillWidth = size.width * GameUITheme.clampedProgress(progress)
        let fillRect = CGRect(x: -size.width / 2, y: -size.height / 2, width: fillWidth, height: size.height)
        fill.path = fillWidth <= 0
            ? CGPath(rect: CGRect(x: -size.width / 2, y: -size.height / 2, width: 0, height: size.height), transform: nil)
            : CGPath(roundedRect: fillRect, cornerWidth: size.height / 2, cornerHeight: size.height / 2, transform: nil)
    }
}

#if DEBUG
extension PanelNode {
    var contentSizeForTesting: CGSize {
        contentSize
    }
}

extension ProgressBarNode {
    var fillWidthForTesting: CGFloat {
        fillWidth
    }
}

#endif
