//
//  GameUIComponents.swift
//  Pyxis
//

import CoreGraphics
import SpriteKit

final class PanelNode: SKNode {
    enum Style: Equatable {
        case normal
        case selected
        case primaryAction
        case disabled
    }

    private let shadow = SKShapeNode()
    private let plate = SKShapeNode()
    private let highlight = SKShapeNode()
    private let rivets: [SKShapeNode]
    private(set) var contentSize: CGSize
    private(set) var style: Style = .normal
    private var showsRivets = false

    init(size: CGSize) {
        rivets = (0..<4).map { _ in SKShapeNode() }
        self.contentSize = size
        super.init()
        configureTree()
        apply(size: size, style: .normal, showsRivets: false)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(size: CGSize, style: Style, showsRivets: Bool) {
        self.style = style
        self.showsRivets = showsRivets
        update(size: size)
    }

    func update(size: CGSize) {
        contentSize = size
        let rect = CGRect(
            x: -size.width / 2,
            y: -size.height / 2,
            width: size.width,
            height: size.height
        )
        let cornerRadius = min(12, max(0, size.height / 4))
        shadow.path = CGPath(
            roundedRect: rect,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
        plate.path = CGPath(
            roundedRect: rect,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
        let highlightRect = rect.insetBy(dx: 2, dy: 2)
        highlight.path = CGPath(
            roundedRect: highlightRect,
            cornerWidth: max(0, cornerRadius - 2),
            cornerHeight: max(0, cornerRadius - 2),
            transform: nil
        )

        let rivetInset: CGFloat = min(9, max(4, min(size.width, size.height) / 4))
        let rivetRadius = min(3, max(1.5, min(size.width, size.height) / 18))
        let rivetPositions = [
            CGPoint(x: rect.minX + rivetInset, y: rect.minY + rivetInset),
            CGPoint(x: rect.maxX - rivetInset, y: rect.minY + rivetInset),
            CGPoint(x: rect.minX + rivetInset, y: rect.maxY - rivetInset),
            CGPoint(x: rect.maxX - rivetInset, y: rect.maxY - rivetInset)
        ]
        for (rivet, position) in zip(rivets, rivetPositions) {
            rivet.path = CGPath(
                ellipseIn: CGRect(
                    x: position.x - rivetRadius,
                    y: position.y - rivetRadius,
                    width: rivetRadius * 2,
                    height: rivetRadius * 2
                ),
                transform: nil
            )
            rivet.isHidden = !showsRivets
        }
        applyStyle()
    }

    private func configureTree() {
        shadow.name = "panelShadow"
        shadow.zPosition = -2
        addChild(shadow)

        plate.name = "panelPlate"
        plate.zPosition = -1
        plate.lineWidth = 1.5
        addChild(plate)

        highlight.name = "panelHighlight"
        highlight.fillColor = .clear
        highlight.lineWidth = 1
        addChild(highlight)

        for (index, rivet) in rivets.enumerated() {
            rivet.name = "panelRivet-\(index)"
            rivet.lineWidth = 0.75
            addChild(rivet)
        }
    }

    private func applyStyle() {
        shadow.fillColor = GameUITheme.Color.panelShadow
        shadow.strokeColor = .clear

        let fillColor: SKColor
        let strokeColor: SKColor
        let highlightColor: SKColor
        let rivetColor: SKColor
        switch style {
        case .normal:
            fillColor = GameUITheme.Color.panelFill
            strokeColor = GameUITheme.Color.panelStroke
            highlightColor = GameUITheme.Color.panelStroke.withAlphaComponent(0.18)
            rivetColor = GameUITheme.Color.panelStroke
        case .selected:
            fillColor = GameUITheme.Color.panelFill.withAlphaComponent(0.98)
            strokeColor = GameUITheme.Color.gold.withAlphaComponent(0.72)
            highlightColor = GameUITheme.Color.gold.withAlphaComponent(0.34)
            rivetColor = GameUITheme.Color.gold
        case .primaryAction:
            fillColor = GameUITheme.Color.panelPrimaryActionFill
            strokeColor = GameUITheme.Color.gold.withAlphaComponent(0.9)
            highlightColor = GameUITheme.Color.gold.withAlphaComponent(0.5)
            rivetColor = GameUITheme.Color.gold
        case .disabled:
            fillColor = GameUITheme.Color.panelFill.withAlphaComponent(0.55)
            strokeColor = GameUITheme.Color.panelStroke.withAlphaComponent(0.4)
            highlightColor = GameUITheme.Color.panelStroke.withAlphaComponent(0.08)
            rivetColor = GameUITheme.Color.panelStroke.withAlphaComponent(0.45)
        }

        plate.fillColor = fillColor
        plate.strokeColor = strokeColor
        highlight.strokeColor = highlightColor
        rivets.forEach {
            $0.fillColor = rivetColor
            $0.strokeColor = .clear
        }
    }
}

final class ProgressBarNode: SKNode {
    private let background = SKShapeNode()
    private let fill = SKShapeNode()
    private var size: CGSize
    private var progress: CGFloat = 0
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
        self.progress = GameUITheme.clampedProgress(progress)
        fillWidth = size.width * self.progress
        let fillRect = CGRect(x: -size.width / 2, y: -size.height / 2, width: fillWidth, height: size.height)
        fill.path = fillWidth <= 0
            ? CGPath(
                rect: CGRect(x: -size.width / 2, y: -size.height / 2, width: 0, height: size.height),
                transform: nil
            )
            : CGPath(roundedRect: fillRect, cornerWidth: size.height / 2, cornerHeight: size.height / 2, transform: nil)
    }
}

#if DEBUG
extension PanelNode {
    var contentSizeForTesting: CGSize {
        contentSize
    }

    var styleForTesting: Style {
        style
    }

    var visibleRivetCountForTesting: Int {
        rivets.filter { !$0.isHidden }.count
    }
}

extension ProgressBarNode {
    var fillWidthForTesting: CGFloat {
        fillWidth
    }
}

#endif
