//
//  CampSelectionNode.swift
//  Pyxis
//

import Foundation
import SpriteKit
import UIKit

struct CampSelectionContent: Equatable {
    enum OptionState: Equatable {
        case available(cost: Int)
        case unaffordable(cost: Int, currentGold: Int)
        case locked(unlocksAtCity: Int)
        case capped(maximum: Int)

        var isAvailable: Bool {
            if case .available = self { return true }
            return false
        }

        var cost: Int? {
            switch self {
            case .available(let cost), .unaffordable(let cost, _):
                return cost
            case .locked, .capped:
                return nil
            }
        }
    }

    struct Option: Equatable {
        let buildingType: BuildingType
        let state: OptionState
        let isRecommended: Bool

        var type: BuildingType { buildingType }
    }

    enum InspectorAction: Equatable {
        case upgrade(cost: Int)
        case unavailable(cost: Int)
    }

    struct Inspector: Equatable {
        let buildingType: BuildingType
        let buildingAssetName: String
        let buildingName: String
        let level: Int
        let levelPips: [Bool]
        let lotNumber: Int
        let producedSoldier: SoldierType
        let upgradeCost: Int
        let action: InspectorAction
        let isRecommended: Bool

        var lot: Int { lotNumber }
        var soldierType: SoldierType { producedSoldier }
        var canUpgrade: Bool {
            if case .upgrade = action { return true }
            return false
        }
    }

    let selectedSlot: Int?
    let gold: Int
    let cityTitle: String
    let occupiedSlotCount: Int
    let options: [Option]
    let inspector: Inspector?
    let recommendation: RecommendedCampRecommendation
    let enabledTabs: Set<GameplayTab>

    var tabContent: GameplayTabBarNode.Content {
        GameplayTabBarNode.Content(
            selected: enabledTabs.contains(.camp) ? .camp : .battle,
            enabledTabs: enabledTabs,
            showsCampAttention: false
        )
    }

    static func project(
        from state: KingdomGameState,
        selectedSlot: Int?
    ) -> CampSelectionContent {
        let cityState = state.cityBattleStateForCurrentCity
        let recommendation = RecommendedCampRecommendation.make(for: state)
        let recommendationAction: RecommendedCampRecommendation.Action?
        switch recommendation {
        case .ready(let action, _), .saveFor(let action, _, _):
            recommendationAction = action
        case .noAction:
            recommendationAction = nil
        }

        let options = BuildingType.allCases.map { type in
            let optionState: OptionState
            if !state.isBuildingTypeUnlocked(type) {
                optionState = .locked(unlocksAtCity: KingdomGameState.unlockCity(for: type))
            } else if cityState.buildingCount(for: type) >= CityBattleState.maxBuildingsPerType {
                optionState = .capped(maximum: CityBattleState.maxBuildingsPerType)
            } else {
                let cost = KingdomGameState.buildingBuildCost(for: type)
                optionState = state.gold >= cost
                    ? .available(cost: cost)
                    : .unaffordable(cost: cost, currentGold: state.gold)
            }

            let isRecommended = selectedSlot != nil
                && recommendationAction.map {
                    $0.kind == .build
                        && $0.slot == selectedSlot
                        && $0.buildingType == type
                } == true
            return Option(
                buildingType: type,
                state: optionState,
                isRecommended: isRecommended
            )
        }

        let inspector: Inspector?
        if let selectedSlot,
           let building = cityState.building(inSlot: selectedSlot) {
            let upgradeCost = KingdomGameState.buildingUpgradeCost(
                for: building.type,
                currentLevel: building.level
            )
            let level = max(1, building.level)
            let isRecommended = selectedSlot == recommendationAction?.slot
                && recommendationAction?.kind == .upgrade
                && recommendationAction?.buildingType == building.type
            inspector = Inspector(
                buildingType: building.type,
                buildingAssetName: building.type.buildingAssetName,
                buildingName: building.type.displayName,
                level: level,
                levelPips: (0..<5).map { $0 < min(level, 5) },
                lotNumber: selectedSlot,
                producedSoldier: building.type.soldierType,
                upgradeCost: upgradeCost,
                action: state.gold >= upgradeCost
                    ? .upgrade(cost: upgradeCost)
                    : .unavailable(cost: upgradeCost),
                isRecommended: isRecommended
            )
        } else {
            inspector = nil
        }

        return CampSelectionContent(
            selectedSlot: selectedSlot,
            gold: state.gold,
            cityTitle: state.displayCityTitle,
            occupiedSlotCount: cityState.occupiedSlotCount,
            options: options,
            inspector: inspector,
            recommendation: recommendation,
            enabledTabs: state.pendingBattleResult == nil
                && state.stageStatus == .battleActive
                ? Set(GameplayTab.allCases)
                : [.battle]
        )
    }

    static func project(
        from state: KingdomGameState,
        selectedLot: Int?
    ) -> CampSelectionContent {
        project(from: state, selectedSlot: selectedLot)
    }

    func option(for type: BuildingType) -> Option? {
        options.first { $0.buildingType == type }
    }
}

final class CampSelectionNode: SKNode {
    enum Action: Equatable {
        case build(BuildingType)
        case requirement(BuildingType)
        case upgrade
        case tab(GameplayTab)
    }

    enum ApplyResult: Equatable {
        case presented
        case requiredContentDoesNotFit
    }

    private struct OptionBundle {
        let root: SKNode
        let panel: PanelNode
        let icon: SKSpriteNode
        let nameLabel: SKLabelNode
        let statusLabel: SKLabelNode
        let recommendationMark: SKShapeNode
    }

    private let builderPanel = PanelNode(size: .zero)
    private let inspectorPanel = PanelNode(size: .zero)
    private let inspectorIcon = SKSpriteNode()
    private let inspectorNameLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let inspectorLevelLabel = SKLabelNode(fontNamed: GameUITheme.Font.medium)
    private let inspectorLotLabel = SKLabelNode(fontNamed: GameUITheme.Font.medium)
    private let inspectorProducedLabel = SKLabelNode(fontNamed: GameUITheme.Font.medium)
    private let inspectorActionPanel = PanelNode(size: .zero)
    private let inspectorActionLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let inspectorLevelPips: [SKShapeNode]
    private let optionBundles: [BuildingType: OptionBundle]
    private let tabBar = GameplayTabBarNode()

    private var currentContent: CampSelectionContent?
    private var currentLayout: CampChromeLayout?

    override init() {
        optionBundles = Dictionary(uniqueKeysWithValues: BuildingType.allCases.map { type in
            let root = SKNode()
            let panel = PanelNode(size: .zero)
            let icon = SKSpriteNode(imageNamed: type.buildingAssetName)
            let nameLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
            let statusLabel = SKLabelNode(fontNamed: GameUITheme.Font.medium)
            let recommendationMark = SKShapeNode(circleOfRadius: 4)

            root.name = "campBuilderOption-\(type.rawValue)"
            panel.name = "campBuilderOptionPanel-\(type.rawValue)"
            icon.name = "campBuilderOptionIcon-\(type.rawValue)"
            nameLabel.name = "campBuilderOptionName-\(type.rawValue)"
            statusLabel.name = "campBuilderOptionStatus-\(type.rawValue)"
            recommendationMark.name = "campBuilderRecommendation-\(type.rawValue)"
            icon.userData = NSMutableDictionary()
            icon.userData?["assetName"] = type.buildingAssetName
            icon.color = GameUITheme.Color.textPrimary
            icon.colorBlendFactor = 0.15
            nameLabel.fontColor = GameUITheme.Color.textPrimary
            statusLabel.fontColor = GameUITheme.Color.textSecondary
            nameLabel.horizontalAlignmentMode = .center
            nameLabel.verticalAlignmentMode = .center
            statusLabel.horizontalAlignmentMode = .center
            statusLabel.verticalAlignmentMode = .center
            nameLabel.fontSize = 9
            statusLabel.fontSize = 8
            recommendationMark.fillColor = GameUITheme.Color.gold
            recommendationMark.strokeColor = .clear
            recommendationMark.isHidden = true

            root.addChild(panel)
            root.addChild(icon)
            root.addChild(nameLabel)
            root.addChild(statusLabel)
            root.addChild(recommendationMark)
            return (
                type,
                OptionBundle(
                    root: root,
                    panel: panel,
                    icon: icon,
                    nameLabel: nameLabel,
                    statusLabel: statusLabel,
                    recommendationMark: recommendationMark
                )
            )
        })
        inspectorLevelPips = (0..<5).map { index in
            let pip = SKShapeNode()
            pip.name = "campInspectorLevelPip-\(index)"
            pip.strokeColor = .clear
            return pip
        }
        super.init()
        name = "campSelection"
        builderPanel.name = "campBuilderPanel"
        inspectorPanel.name = "campInspectorPanel"
        inspectorIcon.name = "campInspectorIcon"
        inspectorNameLabel.name = "campInspectorName"
        inspectorLevelLabel.name = "campInspectorLevel"
        inspectorLotLabel.name = "campInspectorLot"
        inspectorProducedLabel.name = "campInspectorProducedSoldier"
        inspectorActionPanel.name = "campInspectorActionPanel"
        inspectorActionLabel.name = "campInspectorAction"
        for label in [
            inspectorNameLabel,
            inspectorLevelLabel,
            inspectorLotLabel,
            inspectorProducedLabel,
            inspectorActionLabel
        ] {
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.fontColor = GameUITheme.Color.textPrimary
        }
        inspectorNameLabel.fontSize = 14
        inspectorLevelLabel.fontSize = 10
        inspectorLotLabel.fontSize = 9
        inspectorProducedLabel.fontSize = 9
        inspectorActionLabel.fontSize = 15

        addChild(builderPanel)
        addChild(inspectorPanel)
        addChild(inspectorIcon)
        addChild(inspectorNameLabel)
        addChild(inspectorLevelLabel)
        addChild(inspectorLotLabel)
        addChild(inspectorProducedLabel)
        for pip in inspectorLevelPips {
            addChild(pip)
        }
        addChild(inspectorActionPanel)
        addChild(inspectorActionLabel)
        for type in BuildingType.allCases {
            addChild(optionBundles[type]!.root)
        }
        addChild(tabBar)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @discardableResult
    func apply(content: CampSelectionContent, layout: CampChromeLayout) -> ApplyResult {
        guard content.options.count == BuildingType.allCases.count,
              content.options.map(\.buildingType) == BuildingType.allCases,
              layout.lotHitFrames.count == CityBattleState.slotRange.count,
              layout.tabHitFrames.count == GameplayTab.allCases.count,
              layout.tabBarFrame.height >= CampChromeLayout.tabBarHeight,
              layout.safeFrame.contains(layout.tabBarFrame),
              layout.lotHitFrames.values.allSatisfy({
                  layout.safeFrame.contains($0)
                      && $0.width >= CampChromeLayout.minimumInteractiveSize
                      && $0.height >= CampChromeLayout.minimumInteractiveSize
              }) else {
            return failApply()
        }

        if let builderFrame = layout.builderFrame {
            guard layout.builderOptionFrames.count == BuildingType.allCases.count,
                  layout.builderOptionFrames.values.allSatisfy({
                      builderFrame.contains($0)
                          && $0.width >= CampChromeLayout.minimumInteractiveSize
                          && $0.height >= CampChromeLayout.minimumInteractiveSize
                  }) else {
                return failApply()
            }
        }
        if let inspectorFrame = layout.inspectorFrame,
           let actionFrame = layout.inspectorActionFrame {
            guard inspectorFrame.contains(actionFrame),
                  actionFrame.width >= CampChromeLayout.minimumInteractiveSize,
                  actionFrame.height >= CampChromeLayout.minimumInteractiveSize else {
                return failApply()
            }
        }

        isHidden = false
        currentContent = content
        currentLayout = layout
        builderPanel.isHidden = layout.builderFrame == nil
        inspectorPanel.isHidden = layout.inspectorFrame == nil || content.inspector == nil
        optionBundles.values.forEach { $0.root.isHidden = layout.builderFrame == nil }
        inspectorIcon.isHidden = inspectorPanel.isHidden
        inspectorNameLabel.isHidden = inspectorPanel.isHidden
        inspectorLevelLabel.isHidden = inspectorPanel.isHidden
        inspectorLotLabel.isHidden = inspectorPanel.isHidden
        inspectorProducedLabel.isHidden = inspectorPanel.isHidden
        inspectorActionPanel.isHidden = inspectorPanel.isHidden
        inspectorActionLabel.isHidden = inspectorPanel.isHidden
        inspectorLevelPips.forEach { $0.isHidden = inspectorPanel.isHidden }

        if let builderFrame = layout.builderFrame {
            builderPanel.apply(size: builderFrame.size, style: .normal, showsRivets: true)
            builderPanel.position = CGPoint(x: builderFrame.midX, y: builderFrame.midY)
            for option in content.options {
                guard let frame = layout.builderOptionFrames[option.buildingType],
                      let bundle = optionBundles[option.buildingType] else {
                    return failApply()
                }
                bundle.root.position = CGPoint(x: frame.midX, y: frame.midY)
                bundle.panel.apply(
                    size: frame.size,
                    style: option.isRecommended
                        ? .selected
                        : Self.panelStyle(for: option.state),
                    showsRivets: false
                )
                bundle.icon.size = Self.aspectFitSize(
                    for: bundle.icon.texture,
                    maximumSize: CGSize(width: frame.width * 0.46, height: frame.height * 0.46)
                )
                bundle.icon.position = CGPoint(x: 0, y: 8)
                bundle.nameLabel.text = option.buildingType.shortDisplayName.uppercased()
                bundle.nameLabel.position = CGPoint(x: 0, y: -frame.height * 0.27)
                bundle.statusLabel.text = Self.statusText(for: option.state)
                bundle.statusLabel.position = CGPoint(x: 0, y: -frame.height * 0.43)
                let enabled = option.state.isAvailable
                bundle.icon.alpha = enabled ? 1 : 0.42
                bundle.nameLabel.alpha = enabled ? 1 : 0.60
                bundle.statusLabel.alpha = enabled ? 1 : 0.75
                bundle.recommendationMark.position = CGPoint(
                    x: frame.width / 2 - 9,
                    y: frame.height / 2 - 9
                )
                bundle.recommendationMark.isHidden = !option.isRecommended
            }
        }

        if let inspectorFrame = layout.inspectorFrame,
           let actionFrame = layout.inspectorActionFrame,
           let inspector = content.inspector {
            inspectorPanel.apply(size: inspectorFrame.size, style: .normal, showsRivets: true)
            inspectorPanel.position = CGPoint(x: inspectorFrame.midX, y: inspectorFrame.midY)
            inspectorIcon.texture = SKTexture(imageNamed: inspector.buildingAssetName)
            inspectorIcon.size = Self.aspectFitSize(
                for: inspectorIcon.texture,
                maximumSize: CGSize(width: 72, height: inspectorFrame.height - 18)
            )
            inspectorIcon.position = CGPoint(x: inspectorFrame.minX + 46, y: inspectorFrame.midY + 3)
            inspectorNameLabel.text = inspector.buildingName
            inspectorNameLabel.horizontalAlignmentMode = .left
            inspectorNameLabel.position = CGPoint(x: inspectorFrame.minX + 86, y: inspectorFrame.midY + 24)
            inspectorLevelLabel.text = "Lv \(inspector.level)"
            inspectorLevelLabel.horizontalAlignmentMode = .left
            inspectorLevelLabel.position = CGPoint(x: inspectorFrame.minX + 86, y: inspectorFrame.midY + 8)
            inspectorLotLabel.text = "LOT \(inspector.lotNumber)"
            inspectorLotLabel.horizontalAlignmentMode = .left
            inspectorLotLabel.position = CGPoint(x: inspectorFrame.minX + 86, y: inspectorFrame.midY - 27)
            inspectorProducedLabel.text = "Produces \(inspector.producedSoldier.displayName)"
            inspectorProducedLabel.horizontalAlignmentMode = .left
            inspectorProducedLabel.position = CGPoint(x: inspectorFrame.minX + 86, y: inspectorFrame.midY - 10)

            let pipStartX = inspectorFrame.minX + 86
            for (index, pip) in inspectorLevelPips.enumerated() {
                pip.path = CGPath(
                    roundedRect: CGRect(x: -8, y: -3, width: 16, height: 6),
                    cornerWidth: 3,
                    cornerHeight: 3,
                    transform: nil
                )
                pip.position = CGPoint(
                    x: pipStartX + CGFloat(index) * 19,
                    y: inspectorFrame.midY - 39
                )
                pip.fillColor = inspector.levelPips[index]
                    ? GameUITheme.Color.gold
                    : GameUITheme.Color.panelStroke
            }
            inspectorActionPanel.apply(
                size: actionFrame.size,
                style: inspector.isRecommended
                    ? .selected
                    : inspector.canUpgrade ? .primaryAction : .disabled,
                showsRivets: true
            )
            inspectorActionPanel.position = CGPoint(x: actionFrame.midX, y: actionFrame.midY)
            inspectorActionLabel.text = "↑\n\(CompactNumberFormatter.string(from: inspector.upgradeCost))"
            inspectorActionLabel.numberOfLines = 2
            inspectorActionLabel.position = CGPoint(x: actionFrame.midX, y: actionFrame.midY)
            inspectorActionLabel.fontColor = inspector.canUpgrade
                ? GameUITheme.Color.textPrimary
                : GameUITheme.Color.textSecondary
        }

        tabBar.apply(
            content: content.tabContent,
            frame: layout.tabBarFrame
        )
        return .presented
    }

    func action(at point: CGPoint) -> Action? {
        guard !isHidden,
              let content = currentContent,
              let layout = currentLayout else {
            return nil
        }
        if let builderFrame = layout.builderFrame,
           builderFrame.contains(point) {
            for option in content.options {
                guard let frame = layout.builderOptionFrames[option.buildingType],
                      frame.contains(point) else {
                    continue
                }
                return option.state.isAvailable
                    ? .build(option.buildingType)
                    : .requirement(option.buildingType)
            }
            return nil
        }
        if let actionFrame = layout.inspectorActionFrame,
           actionFrame.contains(point),
           content.inspector != nil {
            return .upgrade
        }
        if let tab = tabBar.tab(at: point) {
            return .tab(tab)
        }
        return nil
    }

    private func failApply() -> ApplyResult {
        isHidden = true
        currentContent = nil
        currentLayout = nil
        return .requiredContentDoesNotFit
    }

    private static func panelStyle(for state: CampSelectionContent.OptionState) -> PanelNode.Style {
        switch state {
        case .available:
            return .normal
        case .unaffordable, .locked, .capped:
            return .disabled
        }
    }

    private static func statusText(for state: CampSelectionContent.OptionState) -> String {
        switch state {
        case .available(let cost):
            return "\(CompactNumberFormatter.string(from: cost))g"
        case .unaffordable(let cost, _):
            return "NEED \(CompactNumberFormatter.string(from: cost))g"
        case .locked(let city):
            return "CITY \(city)"
        case .capped(let maximum):
            return "MAX \(maximum)"
        }
    }

    private static func aspectFitSize(for texture: SKTexture?, maximumSize: CGSize) -> CGSize {
        guard let texture else { return maximumSize }
        let sourceSize = texture.size()
        guard sourceSize.width > 0,
              sourceSize.height > 0,
              maximumSize.width > 0,
              maximumSize.height > 0 else {
            return maximumSize
        }
        let scale = min(maximumSize.width / sourceSize.width, maximumSize.height / sourceSize.height)
        return CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
    }
}

#if DEBUG
extension CampSelectionNode {
    var visualOptionCountForTesting: Int {
        optionBundles.count
    }

    var currentContentForTesting: CampSelectionContent? {
        currentContent
    }

    var currentLayoutForTesting: CampChromeLayout? {
        currentLayout
    }

    var tabBarForTesting: GameplayTabBarNode {
        tabBar
    }

    func optionPanelStyleForTesting(_ type: BuildingType) -> PanelNode.Style? {
        optionBundles[type]?.panel.styleForTesting
    }

    func optionIconAssetNameForTesting(_ type: BuildingType) -> String? {
        optionBundles[type]?.icon.userData?["assetName"] as? String
    }

    func optionStatusTextForTesting(_ type: BuildingType) -> String? {
        optionBundles[type]?.statusLabel.text
    }

    var inspectorNameTextForTesting: String? {
        inspectorNameLabel.text
    }

    var inspectorLevelTextForTesting: String? {
        inspectorLevelLabel.text
    }

    var inspectorLotTextForTesting: String? {
        inspectorLotLabel.text
    }

    var inspectorProducedTextForTesting: String? {
        inspectorProducedLabel.text
    }

    var inspectorActionTextForTesting: String? {
        inspectorActionLabel.text
    }

    var inspectorLevelPipCountForTesting: Int {
        inspectorLevelPips.count
    }
}
#endif
