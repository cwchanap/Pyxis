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
    private static let tileCount = 3
    private static let chipCount = 2

    private struct StatTileBundle {
        let root: SKNode
        let panel: PanelNode
        let icon: SKSpriteNode
        let valueLabel: SKLabelNode
        let titleLabel: SKLabelNode
    }

    private struct ChipBundle {
        let root: SKNode
        let background: SKShapeNode
        let icon: SKSpriteNode
        let label: SKLabelNode
    }

    private let textWidth: (String, String, CGFloat) -> CGFloat
    private let panel: SKShapeNode
    private let takenMedallion: SKNode
    private let takenMedallionOuter: SKShapeNode
    private let takenMedallionInner: SKShapeNode
    private let takenMedallionIcon: SKShapeNode
    private let takenMedallionLabel: SKLabelNode
    private let cityNumberLabel: SKLabelNode
    private let titleLabel: SKLabelNode
    private let rewardIcon: SKShapeNode
    private let rewardLabel: SKLabelNode
    private let tileBundles: [StatTileBundle]
    private let chipBundles: [ChipBundle]
    private let continueContainer: SKNode
    private let continuePanel: PanelNode
    private let continueLabel: SKLabelNode

    private var goldAnchor: CGPoint?
    private var continueHitFrame: CGRect?
    private var renderedTitleFontSize: CGFloat = 0
    private var renderedRewardFontSize: CGFloat = 0
    private var renderedTileValueFontSizes: [CGFloat] = []
    private var renderedTiles: [ConquestReportContent.StatTile] = []
    private var renderedChipSymbols: [String] = []

    init(textWidth: @escaping (String, String, CGFloat) -> CGFloat = ConquestReportNode.defaultTextWidth) {
        self.textWidth = textWidth
        self.panel = SKShapeNode()
        self.takenMedallion = SKNode()
        self.takenMedallionOuter = SKShapeNode()
        self.takenMedallionInner = SKShapeNode()
        self.takenMedallionIcon = SKShapeNode()
        self.takenMedallionLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
        self.cityNumberLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
        self.titleLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
        self.rewardIcon = SKShapeNode(circleOfRadius: 18)
        self.rewardLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
        self.tileBundles = (0..<Self.tileCount).map { index in
            let root = SKNode()
            let panel = PanelNode(size: .zero)
            let icon = SKSpriteNode()
            let valueLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
            let titleLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
            root.name = "conquestStatTile-\(index)"
            panel.name = "conquestStatTilePanel-\(index)"
            icon.name = "conquestStatTileIcon-\(index)"
            valueLabel.name = "conquestStatTileValue-\(index)"
            titleLabel.name = "conquestStatTileTitle-\(index)"
            root.addChild(panel)
            root.addChild(icon)
            root.addChild(valueLabel)
            root.addChild(titleLabel)
            return StatTileBundle(
                root: root,
                panel: panel,
                icon: icon,
                valueLabel: valueLabel,
                titleLabel: titleLabel
            )
        }
        self.chipBundles = (0..<Self.chipCount).map { index in
            let root = SKNode()
            let background = SKShapeNode()
            let icon = SKSpriteNode()
            let label = SKLabelNode(fontNamed: GameUITheme.Font.bold)
            root.name = "conquestAchievementChip-\(index)"
            background.name = "conquestAchievementChipBackground-\(index)"
            icon.name = "conquestAchievementChipIcon-\(index)"
            label.name = "conquestAchievementChipLabel-\(index)"
            root.addChild(background)
            root.addChild(icon)
            root.addChild(label)
            return ChipBundle(root: root, background: background, icon: icon, label: label)
        }
        self.continueContainer = SKNode()
        self.continuePanel = PanelNode(size: .zero)
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
        isContinueEnabled: Bool,
        cityNumber: Int? = nil,
        cityName: String? = nil
    ) -> ApplyResult {
        let displayTitle = cityName ?? content.title
        guard (2...3).contains(content.tiles.count),
              content.tiles.count == layout.tileFrames.count,
              content.achievements.count == layout.chipFrames.count,
              let titleSize = fitSize(
                displayTitle,
                fontName: GameUITheme.Font.bold,
                start: layout.titleStartingFontSize,
                minimum: layout.titleMinimumFontSize,
                width: layout.titleFrame.width
              ),
              let rewardSize = fitSize(
                content.rewardText,
                fontName: GameUITheme.Font.bold,
                start: layout.rewardStartingFontSize,
                minimum: layout.rewardMinimumFontSize,
                width: layout.rewardFrame.width
              ) else {
            return failApply()
        }

        var tileValueSizes = [CGFloat]()
        for (tile, frame) in zip(content.tiles, layout.tileFrames) {
            guard let valueSize = fitSize(
                tile.valueText,
                fontName: GameUITheme.Font.bold,
                start: layout.tileValueStartingFontSize,
                minimum: layout.tileValueMinimumFontSize,
                width: frame.width - 10
            ),
            fitSize(
                tile.labelText,
                fontName: GameUITheme.Font.bold,
                start: layout.tileLabelStartingFontSize,
                minimum: layout.tileLabelMinimumFontSize,
                width: frame.width - 10
            ) != nil else {
                return failApply()
            }
            tileValueSizes.append(valueSize)
        }

        for (achievement, frame) in zip(content.achievements, layout.chipFrames) {
            let label = Self.label(for: achievement)
            guard fitSize(
                label,
                fontName: GameUITheme.Font.bold,
                start: layout.chipStartingFontSize,
                minimum: layout.chipMinimumFontSize,
                width: frame.width - 26
            ) != nil else {
                return failApply()
            }
        }

        renderPanel(layout)
        renderTakenMedallion(frame: layout.takenMedallionFrame)
        renderTitle(
            displayTitle,
            size: titleSize,
            frame: layout.titleFrame,
            hasCityHeader: cityNumber != nil
        )
        renderCityNumber(cityNumber, frame: layout.titleFrame)
        renderReward(content.rewardText, size: rewardSize, frame: layout.rewardFrame)
        renderTiles(content.tiles, sizes: tileValueSizes, frames: layout.tileFrames)
        renderChips(content.achievements, frames: layout.chipFrames)
        renderContinue(layout, enabled: isContinueEnabled)

        isHidden = false
        goldAnchor = CGPoint(x: layout.rewardFrame.midX, y: layout.rewardFrame.midY)
        continueHitFrame = isContinueEnabled ? layout.continueFrame : nil
        renderedTitleFontSize = titleSize
        renderedRewardFontSize = rewardSize
        renderedTileValueFontSizes = tileValueSizes
        renderedTiles = content.tiles
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

    private func renderTakenMedallion(frame: CGRect) {
        let radius = frame.width / 2
        let outerRect = CGRect(
            x: -radius,
            y: -radius,
            width: frame.width,
            height: frame.height
        )
        let innerRadius = max(0, radius - 6)
        let innerRect = CGRect(
            x: -innerRadius,
            y: -innerRadius,
            width: innerRadius * 2,
            height: innerRadius * 2
        )
        takenMedallionOuter.path = CGPath(ellipseIn: outerRect, transform: nil)
        takenMedallionOuter.fillColor = GameUITheme.Color.panelFill.withAlphaComponent(1)
        takenMedallionOuter.strokeColor = GameUITheme.Color.gold
        takenMedallionOuter.lineWidth = 2.5
        takenMedallionInner.path = CGPath(ellipseIn: innerRect, transform: nil)
        takenMedallionInner.fillColor = .clear
        takenMedallionInner.strokeColor = GameUITheme.Color.gold.withAlphaComponent(0.52)
        takenMedallionInner.lineWidth = 1
        let flagPath = CGMutablePath()
        flagPath.move(to: CGPoint(x: -3, y: -10))
        flagPath.addLine(to: CGPoint(x: -3, y: 10))
        flagPath.move(to: CGPoint(x: -2, y: 8))
        flagPath.addLine(to: CGPoint(x: 9, y: 4))
        flagPath.addLine(to: CGPoint(x: -2, y: 0))
        flagPath.closeSubpath()
        takenMedallionIcon.path = flagPath
        takenMedallionIcon.fillColor = GameUITheme.Color.gold
        takenMedallionIcon.strokeColor = GameUITheme.Color.gold
        takenMedallionIcon.lineWidth = 1
        takenMedallionIcon.position = CGPoint(x: 0, y: frame.height * 0.10)
        takenMedallionLabel.text = "TAKEN"
        takenMedallionLabel.fontSize = min(10, max(8, frame.width / 12))
        takenMedallionLabel.position = CGPoint(x: 0, y: -frame.height * 0.23)
        takenMedallion.position = CGPoint(x: frame.midX, y: frame.midY)
        takenMedallion.isHidden = false
    }

    private func renderTitle(
        _ text: String,
        size: CGFloat,
        frame: CGRect,
        hasCityHeader: Bool
    ) {
        titleLabel.isHidden = false
        titleLabel.text = text
        titleLabel.fontSize = size
        titleLabel.position = CGPoint(
            x: frame.midX,
            y: frame.midY + (hasCityHeader ? -frame.height * 0.50 : 0)
        )
    }

    private func renderCityNumber(_ cityNumber: Int?, frame: CGRect) {
        guard let cityNumber else {
            cityNumberLabel.text = nil
            cityNumberLabel.isHidden = true
            return
        }
        cityNumberLabel.text = "CITY \(cityNumber)"
        cityNumberLabel.fontSize = min(10, max(8, frame.height * 0.30))
        cityNumberLabel.position = CGPoint(x: frame.midX, y: frame.midY + frame.height * 0.25)
        cityNumberLabel.isHidden = false
    }

    private func renderReward(_ text: String, size: CGFloat, frame: CGRect) {
        rewardIcon.isHidden = false
        rewardIcon.position = CGPoint(x: frame.midX - min(52, frame.width / 4), y: frame.midY)
        rewardIcon.setScale(min(1, frame.height / 48))
        rewardLabel.isHidden = false
        rewardLabel.text = text
        rewardLabel.fontSize = size
        rewardLabel.position = CGPoint(x: frame.midX + min(30, frame.width / 8), y: frame.midY)
    }

    private func renderTiles(
        _ tiles: [ConquestReportContent.StatTile],
        sizes: [CGFloat],
        frames: [CGRect]
    ) {
        for (index, bundle) in tileBundles.enumerated() {
            guard index < tiles.count else {
                bundle.root.isHidden = true
                continue
            }
            let tile = tiles[index]
            let frame = frames[index]
            bundle.root.isHidden = false
            bundle.root.position = .zero
            bundle.panel.apply(size: frame.size, style: .normal, showsRivets: false)
            bundle.panel.position = CGPoint(x: frame.midX, y: frame.midY)
            bundle.icon.texture = texture(for: tile)
            bundle.icon.color = GameUITheme.Color.textPrimary
            bundle.icon.colorBlendFactor = 1
            bundle.icon.size = CGSize(width: 28, height: 28)
            bundle.icon.position = CGPoint(x: frame.midX, y: frame.midY + 18)
            bundle.valueLabel.text = tile.valueText
            bundle.valueLabel.fontSize = sizes[index]
            bundle.valueLabel.position = CGPoint(x: frame.midX, y: frame.midY - 5)
            bundle.titleLabel.text = tile.labelText
            bundle.titleLabel.fontSize = 9
            bundle.titleLabel.position = CGPoint(x: frame.midX, y: frame.minY + 13)
        }
    }

    private func renderChips(
        _ achievements: [ConquestReportContent.Achievement],
        frames: [CGRect]
    ) {
        renderedChipSymbols = []
        for (index, bundle) in chipBundles.enumerated() {
            guard index < achievements.count else {
                bundle.root.isHidden = true
                continue
            }
            let achievement = achievements[index]
            let frame = frames[index]
            let color = Self.color(for: achievement)
            bundle.root.isHidden = false
            bundle.background.path = CGPath(
                roundedRect: CGRect(
                    x: -frame.width / 2,
                    y: -frame.height / 2,
                    width: frame.width,
                    height: frame.height
                ),
                cornerWidth: frame.height / 2,
                cornerHeight: frame.height / 2,
                transform: nil
            )
            bundle.background.position = CGPoint(x: frame.midX, y: frame.midY)
            bundle.background.fillColor = color.withAlphaComponent(0.16)
            bundle.background.strokeColor = color
            bundle.background.lineWidth = 1
            bundle.icon.texture = UIImage(systemName: Self.symbol(for: achievement)).map {
                SKTexture(image: $0)
            }
            bundle.icon.color = color
            bundle.icon.colorBlendFactor = 1
            bundle.icon.size = CGSize(width: 13, height: 13)
            bundle.icon.position = CGPoint(x: frame.minX + 18, y: frame.midY)
            bundle.label.text = Self.label(for: achievement)
            bundle.label.fontSize = 10
            bundle.label.fontColor = color
            bundle.label.position = CGPoint(x: frame.midX + 8, y: frame.midY)
            renderedChipSymbols.append(Self.symbol(for: achievement))
        }
    }

    private func renderContinue(_ layout: ConquestReportLayout, enabled: Bool) {
        continueContainer.isHidden = false
        continuePanel.isHidden = false
        continueLabel.isHidden = false
        continuePanel.apply(size: layout.continueFrame.size, style: .primaryAction, showsRivets: false)
        continuePanel.position = CGPoint(x: layout.continueFrame.midX, y: layout.continueFrame.midY)
        continueLabel.text = "MARCH ON"
        continueLabel.fontSize = layout.continueStartingFontSize
        continueLabel.position = CGPoint(x: layout.continueFrame.midX, y: layout.continueFrame.midY)
        let alpha: CGFloat = enabled ? 1.0 : 0.5
        continuePanel.alpha = alpha
        continueLabel.alpha = alpha
    }

    private func failApply() -> ApplyResult {
        isHidden = true
        continueHitFrame = nil
        goldAnchor = nil
        renderedTitleFontSize = 0
        renderedRewardFontSize = 0
        renderedTileValueFontSizes = []
        renderedTiles = []
        renderedChipSymbols = []
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
        panel.strokeColor = GameUITheme.Color.gold.withAlphaComponent(0.72)
        panel.lineWidth = 1.5
        panel.zPosition = 0
        panel.isHidden = true
        addChild(panel)

        takenMedallion.name = "conquestTakenMedallion"
        takenMedallionOuter.name = "conquestTakenMedallionOuter"
        takenMedallionInner.name = "conquestTakenMedallionInner"
        takenMedallionIcon.name = "conquestTakenMedallionIcon"
        takenMedallionLabel.name = "conquestTakenMedallionLabel"
        takenMedallionOuter.zPosition = 0
        takenMedallionInner.zPosition = 1
        takenMedallionIcon.zPosition = 2
        takenMedallionLabel.fontColor = GameUITheme.Color.gold
        takenMedallionLabel.horizontalAlignmentMode = .center
        takenMedallionLabel.verticalAlignmentMode = .center
        takenMedallionLabel.zPosition = 2
        takenMedallion.addChild(takenMedallionOuter)
        takenMedallion.addChild(takenMedallionInner)
        takenMedallion.addChild(takenMedallionIcon)
        takenMedallion.addChild(takenMedallionLabel)
        takenMedallion.zPosition = 4
        takenMedallion.isHidden = true
        addChild(takenMedallion)

        cityNumberLabel.fontColor = GameUITheme.Color.gold
        cityNumberLabel.horizontalAlignmentMode = .center
        cityNumberLabel.verticalAlignmentMode = .center
        cityNumberLabel.zPosition = 5
        cityNumberLabel.isHidden = true
        addChild(cityNumberLabel)

        titleLabel.fontColor = GameUITheme.Color.textPrimary
        titleLabel.horizontalAlignmentMode = .center
        titleLabel.verticalAlignmentMode = .center
        titleLabel.zPosition = 1
        titleLabel.isHidden = true
        addChild(titleLabel)

        rewardIcon.fillColor = GameUITheme.Color.gold
        rewardIcon.strokeColor = GameUITheme.Color.textPrimary.withAlphaComponent(0.75)
        rewardIcon.lineWidth = 1.5
        rewardIcon.zPosition = 1
        rewardIcon.isHidden = true
        addChild(rewardIcon)

        rewardLabel.fontColor = GameUITheme.Color.gold
        rewardLabel.horizontalAlignmentMode = .center
        rewardLabel.verticalAlignmentMode = .center
        rewardLabel.zPosition = 1
        rewardLabel.isHidden = true
        addChild(rewardLabel)

        for bundle in tileBundles {
            bundle.icon.zPosition = 2
            bundle.valueLabel.fontColor = GameUITheme.Color.textPrimary
            bundle.valueLabel.horizontalAlignmentMode = .center
            bundle.valueLabel.verticalAlignmentMode = .center
            bundle.valueLabel.zPosition = 2
            bundle.titleLabel.fontColor = GameUITheme.Color.textSecondary
            bundle.titleLabel.horizontalAlignmentMode = .center
            bundle.titleLabel.verticalAlignmentMode = .center
            bundle.titleLabel.zPosition = 2
            bundle.root.isHidden = true
            addChild(bundle.root)
        }

        for bundle in chipBundles {
            bundle.background.zPosition = 1
            bundle.icon.zPosition = 2
            bundle.label.horizontalAlignmentMode = .center
            bundle.label.verticalAlignmentMode = .center
            bundle.label.zPosition = 2
            bundle.root.isHidden = true
            addChild(bundle.root)
        }

        continuePanel.zPosition = 1
        continuePanel.isHidden = true
        continueLabel.fontColor = GameUITheme.Color.textPrimary
        continueLabel.horizontalAlignmentMode = .center
        continueLabel.verticalAlignmentMode = .center
        continueLabel.zPosition = 2
        continueLabel.isHidden = true
        continueContainer.addChild(continuePanel)
        continueContainer.addChild(continueLabel)
        continueContainer.isHidden = true
        addChild(continueContainer)

        isHidden = true
    }

    private func texture(for tile: ConquestReportContent.StatTile) -> SKTexture? {
        UIImage(systemName: tile.symbolName).map {
            SKTexture(image: $0)
        }
    }

    private static func symbol(for achievement: ConquestReportContent.Achievement) -> String {
        switch achievement {
        case .favorableUnit: return favorableUnitSymbol
        case .exposedLane: return exposedLaneSymbol
        }
    }

    private static func label(for achievement: ConquestReportContent.Achievement) -> String {
        switch achievement {
        case .favorableUnit: return "FAVOURED"
        case .exposedLane: return "OPEN LANE"
        }
    }

    private static func color(for achievement: ConquestReportContent.Achievement) -> SKColor {
        switch achievement {
        case .favorableUnit: return SKColor(red: 0.24, green: 0.8, blue: 0.38, alpha: 1)
        case .exposedLane: return GameUITheme.Color.gold
        }
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

    var renderedTilesForTesting: [ConquestReportContent.StatTile] { renderedTiles }
    var renderedChipSymbolsForTesting: [String] { renderedChipSymbols }
    var renderedChipCentersForTesting: [CGPoint] {
        chipBundles.filter { !$0.root.isHidden }.map { bundle in
            bundle.background.position
        }
    }
    var goldEffectAnchorForTesting: CGPoint? { goldAnchor }
    var continueHitFrameForTesting: CGRect? { continueHitFrame }
    var titleFontSizeForTesting: CGFloat { renderedTitleFontSize }
    var rewardFontSizeForTesting: CGFloat { renderedRewardFontSize }
    var tileValueFontSizesForTesting: [CGFloat] { renderedTileValueFontSizes }
    var continueBackgroundAlphaForTesting: CGFloat { continuePanel.alpha }
    var continuePanelStyleForTesting: PanelNode.Style { continuePanel.style }
    var renderedTakenStatusTextForTesting: String? { takenMedallionLabel.text }
    var renderedCityNumberTextForTesting: String? { cityNumberLabel.text }
    var renderedCityTitleForTesting: String? { titleLabel.text }
    var renderedContinueTextForTesting: String? { continueLabel.text }
}
#endif
