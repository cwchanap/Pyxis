//
//  ConquestReportNode.swift
//  Pyxis
//

import SpriteKit
import UIKit

final class ConquestReportNode: SKNode {
    enum ApplyResult: Equatable {
        case presented
        case requiredContentDoesNotFit
    }

    private static let favorableUnitSymbol = "checkmark.shield.fill"
    private static let exposedLaneSymbol = "shield.slash.fill"
    private static let summaryLabelCount = 4
    private static let badgeCount = 2

    private let textWidth: (String, String, CGFloat) -> CGFloat

    private let panel: SKShapeNode
    private let titleLabel: SKLabelNode
    private let summaryLabels: [SKLabelNode]
    private let badgeSprites: [SKSpriteNode]
    private let continueContainer: SKNode
    private let continueBackground: SKShapeNode
    private let continueLabel: SKLabelNode

    private var goldAnchor: CGPoint?
    private var continueHitFrame: CGRect?
    private var renderedTitleFontSize: CGFloat = 0
    private var renderedSummaryFontSizes: [CGFloat] = []
    private var renderedSummaryLines: [String] = []
    private var renderedAchievementSymbols: [String] = []

    init(textWidth: @escaping (String, String, CGFloat) -> CGFloat = ConquestReportNode.defaultTextWidth) {
        self.textWidth = textWidth
        self.panel = SKShapeNode()
        self.titleLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
        self.summaryLabels = (0..<Self.summaryLabelCount).map { _ in
            SKLabelNode(fontNamed: GameUITheme.Font.medium)
        }
        self.badgeSprites = (0..<Self.badgeCount).map { _ in SKSpriteNode() }
        self.continueContainer = SKNode()
        self.continueBackground = SKShapeNode()
        self.continueLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
        super.init()
        configureTree()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(
        content: ConquestReportContent,
        layout: ConquestReportLayout,
        isContinueEnabled: Bool
    ) -> ApplyResult {
        guard content.summaryLines.count == layout.summaryRowFrames.count,
              let titleSize = fitSize(
                content.title,
                fontName: GameUITheme.Font.bold,
                start: layout.titleStartingFontSize,
                minimum: layout.titleMinimumFontSize,
                width: layout.titleFrame.width
              ) else {
            return failApply()
        }

        var rowSizes: [CGFloat] = []
        for (line, frame) in zip(content.summaryLines, layout.summaryRowFrames) {
            guard let size = fitSize(
                line,
                fontName: GameUITheme.Font.medium,
                start: layout.summaryStartingFontSize,
                minimum: layout.summaryMinimumFontSize,
                width: frame.width
            ) else {
                return failApply()
            }
            rowSizes.append(size)
        }

        renderPanel(layout)
        renderTitle(content.title, size: titleSize, frame: layout.titleFrame)
        renderSummary(content.summaryLines, sizes: rowSizes, frames: layout.summaryRowFrames)
        renderAchievements(content.achievements, strip: layout.achievementStripFrame)
        renderContinue(layout, enabled: isContinueEnabled)

        isHidden = false
        goldAnchor = CGPoint(x: layout.summaryRowFrames[0].midX, y: layout.summaryRowFrames[0].midY)
        continueHitFrame = isContinueEnabled ? layout.continueFrame : nil

        renderedTitleFontSize = titleSize
        renderedSummaryFontSizes = rowSizes
        renderedSummaryLines = content.summaryLines
        return .presented
    }

    func containsContinue(_ scenePoint: CGPoint) -> Bool {
        guard let frame = continueHitFrame else { return false }
        return frame.contains(scenePoint)
    }

    func goldEffectAnchor(in coordinateNode: SKNode) -> CGPoint? {
        guard let anchor = goldAnchor else { return nil }
        return convert(anchor, to: coordinateNode)
    }

    // MARK: - Rendering

    private func renderPanel(_ layout: ConquestReportLayout) {
        panel.isHidden = false
        panel.path = CGPath(
            roundedRect: layout.panelFrame,
            cornerWidth: layout.panelCornerRadius,
            cornerHeight: layout.panelCornerRadius,
            transform: nil
        )
        panel.position = .zero
    }

    private func renderTitle(_ text: String, size: CGFloat, frame: CGRect) {
        titleLabel.isHidden = false
        titleLabel.text = text
        titleLabel.fontSize = size
        titleLabel.position = CGPoint(x: frame.midX, y: frame.midY)
    }

    private func renderSummary(_ lines: [String], sizes: [CGFloat], frames: [CGRect]) {
        for (index, label) in summaryLabels.enumerated() {
            if index < lines.count {
                label.isHidden = false
                label.text = lines[index]
                label.fontSize = sizes[index]
                label.position = CGPoint(x: frames[index].midX, y: frames[index].midY)
            } else {
                label.isHidden = true
                label.text = nil
            }
        }
    }

    private struct AchievementBadge {
        let achievement: ConquestReportContent.Achievement
        let symbol: String
        let sprite: SKSpriteNode
    }

    private func renderAchievements(_ achievements: [ConquestReportContent.Achievement], strip: CGRect?) {
        let ordered = [
            AchievementBadge(achievement: .favorableUnit, symbol: Self.favorableUnitSymbol, sprite: badgeSprites[0]),
            AchievementBadge(achievement: .exposedLane, symbol: Self.exposedLaneSymbol, sprite: badgeSprites[1])
        ]

        var visible: [SKSpriteNode] = []
        var symbols: [String] = []
        for badge in ordered {
            if achievements.contains(badge.achievement) {
                visible.append(badge.sprite)
                symbols.append(badge.symbol)
            } else {
                badge.sprite.isHidden = true
            }
        }

        guard let stripFrame = strip, !visible.isEmpty else {
            for sprite in visible { sprite.isHidden = true }
            renderedAchievementSymbols = []
            return
        }

        let total = CGFloat(visible.count)
        for (index, sprite) in visible.enumerated() {
            sprite.isHidden = false
            let badgeSize = CGSize(width: stripFrame.height, height: stripFrame.height)
            sprite.size = badgeSize
            let center = stripFrame.minX + (CGFloat(index) + 0.5) * stripFrame.width / total
            sprite.position = CGPoint(x: center, y: stripFrame.midY)
        }
        renderedAchievementSymbols = symbols
    }

    private func renderContinue(_ layout: ConquestReportLayout, enabled: Bool) {
        continueContainer.isHidden = false
        continueBackground.isHidden = false
        continueLabel.isHidden = false
        continueBackground.path = CGPath(
            roundedRect: layout.continueFrame,
            cornerWidth: layout.panelCornerRadius,
            cornerHeight: layout.panelCornerRadius,
            transform: nil
        )
        continueBackground.position = .zero
        continueLabel.text = "Continue"
        continueLabel.fontSize = layout.continueStartingFontSize
        continueLabel.position = CGPoint(x: layout.continueFrame.midX, y: layout.continueFrame.midY)
    }

    private func failApply() -> ApplyResult {
        isHidden = true
        continueHitFrame = nil
        goldAnchor = nil
        renderedTitleFontSize = 0
        renderedSummaryFontSizes = []
        renderedSummaryLines = []
        renderedAchievementSymbols = []
        return .requiredContentDoesNotFit
    }

    private func fitSize(
        _ text: String,
        fontName: String,
        start: CGFloat,
        minimum: CGFloat,
        width: CGFloat
    ) -> CGFloat? {
        SingleLineTextFitter.fittedFontSize(
            text,
            startingAt: start,
            minimum: minimum,
            maximumWidth: width,
            measure: { [weak self] candidate, size in
                guard let self else { return .greatestFiniteMagnitude }
                return self.textWidth(candidate, fontName, size)
            }
        )
    }

    private func configureTree() {
        panel.fillColor = GameUITheme.Color.panelFill
        panel.strokeColor = GameUITheme.Color.panelStroke
        panel.lineWidth = 1.5
        panel.zPosition = 0
        panel.isHidden = true
        addChild(panel)

        titleLabel.fontColor = GameUITheme.Color.textPrimary
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.verticalAlignmentMode = .center
        titleLabel.zPosition = 1
        titleLabel.isHidden = true
        addChild(titleLabel)

        for label in summaryLabels {
            label.fontColor = GameUITheme.Color.textSecondary
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.zPosition = 1
            label.isHidden = true
            addChild(label)
        }

        let badgeSymbols = [Self.favorableUnitSymbol, Self.exposedLaneSymbol]
        for (sprite, symbol) in zip(badgeSprites, badgeSymbols) {
            let image = UIImage(systemName: symbol)
            assert(image != nil, "Missing SF Symbol: \(symbol)")
            if let image {
                sprite.texture = SKTexture(image: image)
                sprite.color = GameUITheme.Color.gold
                sprite.colorBlendFactor = 1.0
            }
            sprite.zPosition = 1
            sprite.isHidden = true
            addChild(sprite)
        }

        continueBackground.fillColor = GameUITheme.Color.spawn
        continueBackground.strokeColor = GameUITheme.Color.panelStroke
        continueBackground.lineWidth = 1.5
        continueBackground.zPosition = 1
        continueBackground.isHidden = true
        continueLabel.fontColor = GameUITheme.Color.textPrimary
        continueLabel.horizontalAlignmentMode = .center
        continueLabel.verticalAlignmentMode = .center
        continueLabel.zPosition = 2
        continueLabel.isHidden = true
        continueContainer.addChild(continueBackground)
        continueContainer.addChild(continueLabel)
        continueContainer.isHidden = true
        addChild(continueContainer)

        isHidden = true
    }

    private static let defaultTextWidth: (String, String, CGFloat) -> CGFloat = { text, fontName, fontSize in
        let font = UIFont(name: fontName, size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)
        return (text as NSString).size(withAttributes: [.font: font]).width
    }
}

#if DEBUG
extension ConquestReportNode {
    var nodeCountsForTesting: Int {
        var count = 0
        var stack: [SKNode] = [self]
        while let node = stack.popLast() {
            count += 1
            stack.append(contentsOf: node.children)
        }
        return count
    }

    var continueControlCountForTesting: Int {
        children.filter { $0 === continueContainer }.count
    }

    var renderedSummaryLinesForTesting: [String] { renderedSummaryLines }
    var renderedAchievementSymbolsForTesting: [String] { renderedAchievementSymbols }
    var goldEffectAnchorForTesting: CGPoint? { goldAnchor }
    var continueHitFrameForTesting: CGRect? { continueHitFrame }
    var titleFontSizeForTesting: CGFloat { renderedTitleFontSize }
    var summaryFontSizesForTesting: [CGFloat] { renderedSummaryFontSizes }
}
#endif
