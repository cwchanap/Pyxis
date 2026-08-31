//
//  GameUIComponents.swift
//  Pyxis
//

import CoreGraphics
import SpriteKit
import UIKit

func gameUISymbolImage(named name: String, color: SKColor) -> UIImage? {
    guard let symbol = UIImage(systemName: name) else { return nil }
    let bounds = CGRect(origin: .zero, size: symbol.size)
    return UIGraphicsImageRenderer(size: symbol.size).image { context in
        context.cgContext.setFillColor(color.cgColor)
        context.cgContext.fill(bounds)
        symbol.draw(in: bounds, blendMode: .destinationIn, alpha: 1)
    }
}

final class PanelNode: SKNode {
    private static let shadowColor = SKColor(white: 0, alpha: 0.42)
    private static let primaryActionFillColor = SKColor(red: 0.42, green: 0.25, blue: 0.08, alpha: 0.98)

    enum Appearance: Equatable {
        case standard
        case forged
    }

    enum Shape: Equatable {
        case roundedRectangle
        case hexagon
    }

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
    private var appearance: Appearance = .standard
    private var shape: Shape = .roundedRectangle
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

    func apply(
        size: CGSize,
        style: Style,
        showsRivets: Bool,
        appearance: Appearance = .standard,
        shape: Shape = .roundedRectangle
    ) {
        self.style = style
        self.appearance = appearance
        self.shape = shape
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
        shadow.path = panelPath(in: rect, cornerRadius: cornerRadius)
        plate.path = panelPath(in: rect, cornerRadius: cornerRadius)
        let highlightRect = rect.insetBy(dx: 2, dy: 2)
        highlight.path = panelPath(
            in: highlightRect,
            cornerRadius: max(0, cornerRadius - 2)
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

    private func panelPath(in rect: CGRect, cornerRadius: CGFloat) -> CGPath {
        switch shape {
        case .roundedRectangle:
            return CGPath(
                roundedRect: rect,
                cornerWidth: cornerRadius,
                cornerHeight: cornerRadius,
                transform: nil
            )
        case .hexagon:
            let path = CGMutablePath()
            let points = [
                CGPoint(x: rect.midX, y: rect.maxY),
                CGPoint(x: rect.minX + rect.width * 0.93, y: rect.minY + rect.height * 0.75),
                CGPoint(x: rect.minX + rect.width * 0.93, y: rect.minY + rect.height * 0.25),
                CGPoint(x: rect.midX, y: rect.minY),
                CGPoint(x: rect.minX + rect.width * 0.07, y: rect.minY + rect.height * 0.25),
                CGPoint(x: rect.minX + rect.width * 0.07, y: rect.minY + rect.height * 0.75)
            ]
            path.move(to: points[0])
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            path.addLine(to: points[0])
            path.closeSubpath()
            return path
        }
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
        shadow.position = appearance == .forged ? CGPoint(x: 0, y: -3) : .zero
        shadow.fillColor = appearance == .forged
            ? SKColor(white: 0, alpha: 0.60)
            : Self.shadowColor
        shadow.strokeColor = .clear
        shadow.lineWidth = 0
        let fillColor: SKColor
        let gradientTopColor: SKColor
        let strokeColor: SKColor
        let highlightColor: SKColor
        let rivetColor: SKColor
        if appearance == .forged {
            switch style {
            case .normal:
                fillColor = SKColor(red: 25 / 255, green: 17 / 255, blue: 8 / 255, alpha: 1)
                gradientTopColor = SKColor(red: 59 / 255, green: 44 / 255, blue: 28 / 255, alpha: 1)
                strokeColor = SKColor(red: 198 / 255, green: 150 / 255, blue: 80 / 255, alpha: 0.60)
                highlightColor = SKColor(red: 255 / 255, green: 206 / 255, blue: 140 / 255, alpha: 0.45)
                rivetColor = SKColor(red: 255 / 255, green: 220 / 255, blue: 160 / 255, alpha: 0.55)
            case .selected:
                fillColor = SKColor(red: 112 / 255, green: 72 / 255, blue: 16 / 255, alpha: 1)
                gradientTopColor = SKColor(red: 196 / 255, green: 132 / 255, blue: 36 / 255, alpha: 1)
                strokeColor = SKColor(red: 255 / 255, green: 196 / 255, blue: 75 / 255, alpha: 0.96)
                highlightColor = SKColor(red: 255 / 255, green: 224 / 255, blue: 150 / 255, alpha: 0.72)
                rivetColor = SKColor(red: 255 / 255, green: 214 / 255, blue: 120 / 255, alpha: 1)
                shadow.strokeColor = SKColor(red: 255 / 255, green: 166 / 255, blue: 34 / 255, alpha: 0.52)
                shadow.lineWidth = 8
            case .primaryAction:
                fillColor = SKColor(red: 51 / 255, green: 31 / 255, blue: 8 / 255, alpha: 1)
                gradientTopColor = SKColor(red: 111 / 255, green: 69 / 255, blue: 21 / 255, alpha: 1)
                strokeColor = SKColor(red: 255 / 255, green: 180 / 255, blue: 60 / 255, alpha: 0.75)
                highlightColor = SKColor(red: 255 / 255, green: 214 / 255, blue: 150 / 255, alpha: 0.60)
                rivetColor = SKColor(red: 255 / 255, green: 206 / 255, blue: 120 / 255, alpha: 0.92)
                shadow.strokeColor = SKColor(red: 255 / 255, green: 120 / 255, blue: 20 / 255, alpha: 0.38)
                shadow.lineWidth = 7
            case .disabled:
                fillColor = SKColor(red: 16 / 255, green: 13 / 255, blue: 9 / 255, alpha: 1)
                gradientTopColor = SKColor(red: 42 / 255, green: 38 / 255, blue: 32 / 255, alpha: 1)
                strokeColor = SKColor(red: 120 / 255, green: 104 / 255, blue: 74 / 255, alpha: 0.60)
                highlightColor = SKColor(white: 1, alpha: 0.14)
                rivetColor = SKColor(red: 120 / 255, green: 104 / 255, blue: 74 / 255, alpha: 0.50)
            }
        } else {
            gradientTopColor = .clear
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
                fillColor = Self.primaryActionFillColor
                strokeColor = GameUITheme.Color.gold.withAlphaComponent(0.9)
                highlightColor = GameUITheme.Color.gold.withAlphaComponent(0.5)
                rivetColor = GameUITheme.Color.gold
            case .disabled:
                fillColor = GameUITheme.Color.panelFill.withAlphaComponent(0.55)
                strokeColor = GameUITheme.Color.panelStroke.withAlphaComponent(0.4)
                highlightColor = GameUITheme.Color.panelStroke.withAlphaComponent(0.08)
                rivetColor = GameUITheme.Color.panelStroke.withAlphaComponent(0.45)
            }
        }

        plate.lineWidth = 1.5
        plate.fillColor = fillColor
        plate.fillTexture = appearance == .forged
            ? Self.gradientTexture(top: gradientTopColor, bottom: fillColor)
            : nil
        plate.strokeColor = strokeColor
        highlight.strokeColor = highlightColor
        rivets.forEach {
            $0.fillColor = rivetColor
            $0.strokeColor = .clear
        }
    }

    private static func gradientTexture(top: SKColor, bottom: SKColor) -> SKTexture? {
        let size = CGSize(width: 2, height: 128)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let colors = [bottom.cgColor, top.cgColor] as CFArray
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: [0, 1]
            ) else {
                return
            }
            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: size.width / 2, y: size.height),
                end: CGPoint(x: size.width / 2, y: 0),
                options: []
            )
        }
        return SKTexture(image: image)
    }
}

final class ProgressBarNode: SKNode {
    enum Appearance {
        case standard
        case forged
    }

    private let background = SKShapeNode()
    private let fill = SKShapeNode()
    private let segmentTicks: [SKShapeNode]
    private var size: CGSize
    private var progress: CGFloat = 0
    private var fillWidth: CGFloat = 0

    init(size: CGSize, appearance: Appearance = .standard) {
        self.size = size
        segmentTicks = appearance == .forged
            ? (0..<9).map { _ in SKShapeNode() }
            : []
        super.init()
        switch appearance {
        case .standard:
            background.fillColor = GameUITheme.Color.hpBackground
            background.strokeColor = GameUITheme.Color.panelStroke
            background.lineWidth = 1
            fill.fillColor = GameUITheme.Color.hpFill
        case .forged:
            background.fillColor = SKColor(
                red: 21 / 255,
                green: 13 / 255,
                blue: 6 / 255,
                alpha: 1
            )
            background.strokeColor = SKColor(
                red: 198 / 255,
                green: 150 / 255,
                blue: 80 / 255,
                alpha: 0.65
            )
            background.lineWidth = 1.5
            fill.fillColor = SKColor(
                red: 46 / 255,
                green: 199 / 255,
                blue: 107 / 255,
                alpha: 1
            )
        }
        fill.strokeColor = .clear
        addChild(background)
        addChild(fill)
        for (index, tick) in segmentTicks.enumerated() {
            tick.name = "progressTick-\(index)"
            tick.strokeColor = SKColor(
                red: 20 / 255,
                green: 12 / 255,
                blue: 4 / 255,
                alpha: 0.75
            )
            tick.lineWidth = 1
            addChild(tick)
        }
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
        for (index, tick) in segmentTicks.enumerated() {
            let x = -size.width / 2
                + size.width * CGFloat(index + 1) / CGFloat(segmentTicks.count + 1)
            let path = CGMutablePath()
            path.move(to: CGPoint(x: x, y: -size.height / 2))
            path.addLine(to: CGPoint(x: x, y: size.height / 2))
            tick.path = path
        }
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
