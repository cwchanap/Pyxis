//
//  BattleHUDNode.swift
//  Pyxis
//

import SpriteKit
import UIKit

struct BattleHUDContent: Equatable {
    enum Availability: Equatable {
        case available(level: Int)
        case unbuilt
        case locked(unlocksAtCity: Int)
    }

    struct Medallion: Equatable {
        let soldierType: SoldierType
        let availability: Availability
        let damageMultiplier: Double
    }

    let cityTitle: String
    let cityLevel: Int
    let gold: Int
    let cityRemainingPower: Int
    let cityMaxPower: Int
    let defenseTrait: CityDefenseTrait
    let recommendation: RecommendedCampRecommendation
    let manualCount: Int
    let manualCapacity: Int
    let selectedSoldierType: SoldierType
    let medallions: [Medallion]
    let enabledTabs: Set<GameplayTab>
    let showsCampAttention: Bool

    var tabContent: GameplayTabBarNode.Content {
        GameplayTabBarNode.Content(
            selected: .battle,
            enabledTabs: enabledTabs,
            showsCampAttention: showsCampAttention
        )
    }

    static func project(
        from state: KingdomGameState,
        manualCount: Int,
        selectedSoldierType: SoldierType = .infantry
    ) -> BattleHUDContent {
        let normalizedManualCount = min(
            max(0, manualCount),
            KingdomGameState.manualSoldierCap
        )
        let medallions = SoldierType.allCases.map { soldierType in
            let availability: Availability
            // Keep this call first: the starter Infantry fallback and the
            // highest existing building level are the same gameplay authority.
            if let level = state.manualSoldierLevel(for: soldierType) {
                availability = .available(level: level)
            } else {
                let buildingType = BuildingType.allCases.first {
                    $0.soldierType == soldierType
                }!
                availability = state.isBuildingTypeUnlocked(buildingType)
                    ? .unbuilt
                    : .locked(unlocksAtCity: KingdomGameState.unlockCity(for: buildingType))
            }

            return Medallion(
                soldierType: soldierType,
                availability: availability,
                damageMultiplier: state.currentCityDefenseTrait.damageMultiplier(for: soldierType)
            )
        }
        let recommendation = RecommendedCampRecommendation.make(for: state)
        let showsCampAttention: Bool
        switch recommendation {
        case .ready, .saveFor:
            showsCampAttention = true
        case .noAction:
            showsCampAttention = false
        }

        return BattleHUDContent(
            cityTitle: state.displayCityTitle,
            cityLevel: state.cityLevel,
            gold: state.gold,
            cityRemainingPower: state.cityRemainingPower,
            cityMaxPower: state.cityMaxPower,
            defenseTrait: state.currentCityDefenseTrait,
            recommendation: recommendation,
            manualCount: normalizedManualCount,
            manualCapacity: KingdomGameState.manualSoldierCap,
            selectedSoldierType: selectedSoldierType,
            medallions: medallions,
            enabledTabs: normalizedManualCount == 0
                ? Set(GameplayTab.allCases)
                : [.battle],
            showsCampAttention: showsCampAttention
        )
    }

    static func project(
        from state: KingdomGameState,
        manualLivingSoldierCount: Int,
        selectedSoldierType: SoldierType = .infantry
    ) -> BattleHUDContent {
        project(
            from: state,
            manualCount: manualLivingSoldierCount,
            selectedSoldierType: selectedSoldierType
        )
    }
}

final class BattleHUDNode: SKNode {
    enum Action: Equatable {
        case select(SoldierType)
        case deploy
        case tab(GameplayTab)
        case requirement(soldierType: SoldierType, unlocksAtCity: Int?)
    }

    enum ApplyResult: Equatable {
        case presented
        case requiredContentDoesNotFit
    }

    private struct MedallionBundle {
        let root: SKNode
        let panel: PanelNode
        let icon: SKSpriteNode
        let typeLabel: SKLabelNode
        let statusLabel: SKLabelNode
        let multiplierLabel: SKLabelNode
    }

    private struct LaneChipBundle {
        let background: SKShapeNode
        let label: SKLabelNode
    }

    private let topPanel = PanelNode(size: .zero)
    private let cityLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let statusLabel = SKLabelNode(fontNamed: GameUITheme.Font.medium)
    private let objectiveLabel = SKLabelNode(fontNamed: GameUITheme.Font.medium)
    private let deployPanel = PanelNode(size: .zero)
    private let deployLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let manualCountLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let tabBar = GameplayTabBarNode()
    private let medallions: [MedallionBundle]
    private let laneChips: [BattleLane: LaneChipBundle]

    private var medallionHitFrames: [CGRect] = []
    private var deployHitFrame: CGRect?
    private var currentLayout: BattleChromeLayout?
    private var currentContent: BattleHUDContent?

    override init() {
        medallions = SoldierType.allCases.map { soldierType in
            let root = SKNode()
            let panel = PanelNode(size: .zero)
            let icon = SKSpriteNode()
            let typeLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
            let statusLabel = SKLabelNode(fontNamed: GameUITheme.Font.medium)
            let multiplierLabel = SKLabelNode(fontNamed: GameUITheme.Font.medium)

            root.name = "battleMedallion-\(soldierType.rawValue)"
            panel.name = "battleMedallionPanel-\(soldierType.rawValue)"
            icon.name = "battleMedallionIcon-\(soldierType.rawValue)"
            typeLabel.name = "battleMedallionType-\(soldierType.rawValue)"
            statusLabel.name = "battleMedallionStatus-\(soldierType.rawValue)"
            multiplierLabel.name = "battleMedallionMultiplier-\(soldierType.rawValue)"
            icon.texture = Self.texture(for: soldierType)
            icon.size = CGSize(width: 34, height: 34)
            icon.color = GameUITheme.Color.textPrimary
            icon.colorBlendFactor = 0.2
            for label in [typeLabel, statusLabel, multiplierLabel] {
                label.horizontalAlignmentMode = .center
                label.verticalAlignmentMode = .center
                label.fontColor = GameUITheme.Color.textPrimary
            }
            typeLabel.fontSize = 9
            statusLabel.fontSize = 9
            multiplierLabel.fontSize = 8
            statusLabel.fontColor = GameUITheme.Color.textSecondary
            multiplierLabel.fontColor = GameUITheme.Color.gold
            root.addChild(panel)
            root.addChild(icon)
            root.addChild(typeLabel)
            root.addChild(statusLabel)
            root.addChild(multiplierLabel)
            return MedallionBundle(
                root: root,
                panel: panel,
                icon: icon,
                typeLabel: typeLabel,
                statusLabel: statusLabel,
                multiplierLabel: multiplierLabel
            )
        }
        laneChips = Dictionary(uniqueKeysWithValues: BattleLane.allCases.map { lane in
            let background = SKShapeNode()
            let label = SKLabelNode(fontNamed: GameUITheme.Font.bold)
            background.name = "battleLaneChip-\(lane.rawValue)"
            background.fillColor = GameUITheme.Color.panelFill.withAlphaComponent(0.92)
            background.strokeColor = GameUITheme.Color.panelStroke
            background.lineWidth = 1
            label.name = "battleLaneChipLabel-\(lane.rawValue)"
            label.text = "OPEN"
            label.fontSize = 9
            label.fontColor = GameUITheme.Color.textPrimary
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            return (lane, LaneChipBundle(background: background, label: label))
        })
        super.init()
        name = "battleHUD"
        topPanel.name = "battleTopPanel"
        cityLabel.name = "battleCityLabel"
        statusLabel.name = "battleStatusLabel"
        objectiveLabel.name = "battleObjectiveLabel"
        deployPanel.name = "battleDeployPanel"
        deployLabel.name = "battleDeployLabel"
        manualCountLabel.name = "battleManualCountLabel"

        for label in [cityLabel, statusLabel, objectiveLabel, deployLabel, manualCountLabel] {
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.fontColor = GameUITheme.Color.textPrimary
        }
        cityLabel.fontSize = 17
        statusLabel.fontSize = 11
        statusLabel.fontColor = GameUITheme.Color.textSecondary
        objectiveLabel.fontSize = 11
        deployLabel.fontSize = 16
        manualCountLabel.fontSize = 13

        addChild(topPanel)
        addChild(cityLabel)
        addChild(statusLabel)
        addChild(objectiveLabel)
        for bundle in medallions {
            addChild(bundle.root)
        }
        addChild(deployPanel)
        addChild(deployLabel)
        addChild(manualCountLabel)
        for lane in BattleLane.allCases {
            addChild(laneChips[lane]!.background)
            addChild(laneChips[lane]!.label)
        }
        addChild(tabBar)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @discardableResult
    func apply(content: BattleHUDContent, layout: BattleChromeLayout) -> ApplyResult {
        let minimumBattlefieldHeight = layout.isCompact
            ? BattleChromeLayout.compactMinimumBattlefieldHeight
            : BattleChromeLayout.minimumBattlefieldHeight
        guard content.medallions.count == medallions.count,
              content.manualCapacity > 0,
              content.manualCount >= 0,
              content.manualCount <= content.manualCapacity,
              layout.medallionFrames.count == medallions.count,
              layout.medallionHitFrames.count == medallions.count,
              layout.tabHitFrames.count == GameplayTab.allCases.count,
              layout.laneChipFrames.count == laneChips.count,
              layout.battlefield.isVisible,
              layout.battlefieldFrame.height >= minimumBattlefieldHeight,
              layout.safeFrame.contains(layout.deployFrame),
              layout.safeFrame.contains(layout.tabBarFrame),
              layout.medallionHitFrames.allSatisfy({
                  layout.safeFrame.contains($0) && $0.width >= 44 && $0.height >= 44
              }),
              layout.tabHitFrames.allSatisfy({
                  layout.safeFrame.contains($0) && $0.width >= 44 && $0.height >= 44
              }),
              BattleLane.allCases.allSatisfy({
                  guard let frame = layout.laneChipFrames[$0] else { return false }
                  return layout.battlefieldFrame.contains(frame)
              })
        else {
            return failApply()
        }

        isHidden = false
        currentLayout = layout
        currentContent = content
        topPanel.apply(size: layout.topBandFrame.size, style: .normal, showsRivets: false)
        topPanel.position = CGPoint(x: layout.topBandFrame.midX, y: layout.topBandFrame.midY)
        cityLabel.text = "CITY \(content.cityLevel) · \(content.cityTitle)"
        cityLabel.position = CGPoint(x: layout.statusFrame.midX, y: layout.statusFrame.midY + 8)
        statusLabel.text = "GOLD \(CompactNumberFormatter.string(from: content.gold))"
            + "  ·  \(content.defenseTrait.displayName)"
        statusLabel.position = CGPoint(x: layout.statusFrame.midX, y: layout.statusFrame.midY - 9)
        objectiveLabel.text = Self.objectiveText(for: content.recommendation)
        objectiveLabel.position = CGPoint(x: layout.objectiveFrame.midX, y: layout.objectiveFrame.midY)

        for (index, bundle) in medallions.enumerated() {
            let medallion = content.medallions[index]
            let frame = layout.medallionFrames[index]
            let style: PanelNode.Style
            if medallion.soldierType == content.selectedSoldierType,
               case .available = medallion.availability {
                style = .selected
            } else {
                style = Self.panelStyle(for: medallion.availability)
            }
            bundle.panel.apply(size: frame.size, style: style, showsRivets: false)
            bundle.root.position = CGPoint(x: frame.midX, y: frame.midY)
            bundle.icon.position = CGPoint(x: 0, y: 8)
            bundle.typeLabel.text = medallion.soldierType.displayName.uppercased()
            bundle.typeLabel.position = CGPoint(x: 0, y: -17)
            bundle.statusLabel.text = Self.statusText(for: medallion.availability)
            bundle.statusLabel.position = CGPoint(x: 0, y: -27)
            bundle.multiplierLabel.text = Self.multiplierText(medallion.damageMultiplier)
            bundle.multiplierLabel.position = CGPoint(x: 0, y: 25)
        }

        deployPanel.apply(size: layout.deployFrame.size, style: .primaryAction, showsRivets: true)
        deployPanel.position = CGPoint(x: layout.deployFrame.midX, y: layout.deployFrame.midY)
        deployLabel.text = "DEPLOY"
        deployLabel.position = CGPoint(
            x: layout.deployFrame.midX - 28,
            y: layout.deployFrame.midY
        )
        manualCountLabel.text = "\(content.manualCount)/\(content.manualCapacity)"
        manualCountLabel.position = CGPoint(
            x: layout.manualCountFrame.midX,
            y: layout.manualCountFrame.midY
        )
        for lane in BattleLane.allCases {
            let frame = layout.laneChipFrames[lane]!
            let bundle = laneChips[lane]!
            bundle.background.path = CGPath(
                roundedRect: CGRect(
                    x: frame.minX,
                    y: frame.minY,
                    width: frame.width,
                    height: frame.height
                ),
                cornerWidth: frame.height / 2,
                cornerHeight: frame.height / 2,
                transform: nil
            )
            bundle.background.isHidden = false
            bundle.label.position = CGPoint(x: frame.midX, y: frame.midY)
            bundle.label.isHidden = false
        }
        tabBar.apply(content: content.tabContent, frame: layout.tabBarFrame)

        medallionHitFrames = layout.medallionHitFrames
        deployHitFrame = layout.deployFrame
        return .presented
    }

    func action(at point: CGPoint) -> Action? {
        guard !isHidden,
              let content = currentContent,
              let layout = currentLayout else {
            return nil
        }
        for (index, frame) in layout.medallionHitFrames.enumerated() where frame.contains(point) {
            let medallion = content.medallions[index]
            switch medallion.availability {
            case .available:
                return .select(medallion.soldierType)
            case .unbuilt:
                return .requirement(soldierType: medallion.soldierType, unlocksAtCity: nil)
            case .locked(let city):
                return .requirement(soldierType: medallion.soldierType, unlocksAtCity: city)
            }
        }
        if deployHitFrame?.contains(point) == true {
            return .deploy
        }
        if let tab = tabBar.tab(at: point) {
            return .tab(tab)
        }
        return nil
    }

    private func failApply() -> ApplyResult {
        isHidden = true
        currentLayout = nil
        currentContent = nil
        medallionHitFrames.removeAll()
        deployHitFrame = nil
        return .requiredContentDoesNotFit
    }

    private static func panelStyle(for availability: BattleHUDContent.Availability) -> PanelNode.Style {
        switch availability {
        case .available:
            return .normal
        case .unbuilt, .locked:
            return .disabled
        }
    }

    private static func statusText(for availability: BattleHUDContent.Availability) -> String {
        switch availability {
        case .available(let level):
            return "L\(level)"
        case .unbuilt:
            return "BUILD"
        case .locked(let city):
            return "CITY \(city)"
        }
    }

    private static func multiplierText(_ multiplier: Double) -> String {
        String(format: "%.2g×", multiplier)
    }

    private static func objectiveText(for recommendation: RecommendedCampRecommendation) -> String {
        switch recommendation {
        case .ready(let action, let reason):
            return "READY · \(action.buildingType.shortDisplayName) · \(reason)"
        case .saveFor(let action, let missingGold, let reason):
            return "SAVE \(missingGold) GOLD · \(action.buildingType.shortDisplayName) · \(reason)"
        case .noAction(let message):
            return message
        }
    }

    private static func texture(for type: SoldierType) -> SKTexture? {
        let assetName = type == .infantry ? "normal-soldier" : "\(type.rawValue)-soldier"
        guard UIImage(named: assetName) != nil else {
            return UIImage(systemName: symbolName(for: type)).map(SKTexture.init(image:))
        }
        return SKTexture(imageNamed: assetName)
    }

    private static func symbolName(for type: SoldierType) -> String {
        switch type {
        case .infantry: return "figure.martial.arts"
        case .archer: return "scope"
        case .cavalry: return "hare.fill"
        case .mage: return "wand.and.stars"
        case .siege: return "shield.lefthalf.filled"
        }
    }
}

#if DEBUG
extension BattleHUDNode {
    var visualMedallionCountForTesting: Int {
        medallions.count
    }

    var medallionVisualSizeForTesting: CGSize {
        medallions.first?.panel.contentSizeForTesting ?? .zero
    }

    var tabBarForTesting: GameplayTabBarNode {
        tabBar
    }

    var currentLayoutForTesting: BattleChromeLayout? {
        currentLayout
    }
}
#endif
