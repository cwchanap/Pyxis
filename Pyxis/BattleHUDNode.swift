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
    let cityNumber: Int
    let gold: Int
    let goldReward: Int
    let cityRemainingPower: Int
    let cityMaxPower: Int
    let laneDefenseProfile: LaneDefenseProfile
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
            cityNumber: state.cityNumberInCountry,
            gold: state.gold,
            goldReward: state.currentGoldReward,
            cityRemainingPower: state.cityRemainingPower,
            cityMaxPower: state.cityMaxPower,
            laneDefenseProfile: state.currentCityLaneDefenseProfile,
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

    private let incomePanel = PanelNode(size: .zero)
    private let cityProgressPanel = PanelNode(size: .zero)
    private let recommendationPanel = PanelNode(size: .zero)
    private let goldIcon = SKSpriteNode()
    private let recommendationIcon = SKSpriteNode()
    private let statusLabel = SKLabelNode(fontNamed: GameUITheme.Font.medium)
    private let objectiveLabel = SKLabelNode(fontNamed: GameUITheme.Font.medium)
    private let rewardLabel = SKLabelNode(fontNamed: GameUITheme.Font.medium)
    private let cityProgressLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let cityHPLabel = SKLabelNode(fontNamed: GameUITheme.Font.medium)
    private let recommendationDetailLabel = SKLabelNode(fontNamed: GameUITheme.Font.medium)
    private let cityProgressBar = ProgressBarNode(size: .zero)
    private let deployPanel = PanelNode(size: .zero)
    private let deployLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let manualCountLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let tabBar = GameplayTabBarNode()
    private let medallions: [MedallionBundle]
    private let laneChips: [BattleLane: LaneChipBundle]

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
            icon.userData = NSMutableDictionary()
            icon.userData?["assetName"] = Self.assetName(for: soldierType)
            icon.size = CGSize(width: 42, height: 42)
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
        incomePanel.name = "battleIncomePanel"
        cityProgressPanel.name = "battleCityProgressPanel"
        recommendationPanel.name = "battleRecommendationPanel"
        goldIcon.name = "battleGoldIcon"
        recommendationIcon.name = "battleRecommendationIcon"
        statusLabel.name = "battleGoldLabel"
        objectiveLabel.name = "battleRecommendationLabel"
        rewardLabel.name = "battleIncomeLabel"
        cityProgressLabel.name = "battleCityProgressLabel"
        cityHPLabel.name = "battleCityHPLabel"
        recommendationDetailLabel.name = "battleRecommendationDetailLabel"
        cityProgressBar.name = "battleCityProgressBar"
        deployPanel.name = "battleDeployPanel"
        deployLabel.name = "battleDeployLabel"
        manualCountLabel.name = "battleManualCountLabel"

        for label in [
            statusLabel,
            objectiveLabel,
            rewardLabel,
            cityProgressLabel,
            cityHPLabel,
            recommendationDetailLabel,
            deployLabel,
            manualCountLabel
        ] {
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.fontColor = GameUITheme.Color.textPrimary
        }
        statusLabel.fontSize = 12
        statusLabel.fontColor = GameUITheme.Color.textSecondary
        objectiveLabel.fontSize = 11
        rewardLabel.fontSize = 9
        rewardLabel.fontColor = GameUITheme.Color.gold
        cityProgressLabel.fontSize = 10
        cityHPLabel.fontSize = 8
        cityHPLabel.fontColor = GameUITheme.Color.textSecondary
        recommendationDetailLabel.fontSize = 8
        recommendationDetailLabel.fontColor = GameUITheme.Color.textSecondary
        deployLabel.fontSize = 16
        manualCountLabel.fontSize = 13

        addChild(incomePanel)
        addChild(cityProgressPanel)
        addChild(recommendationPanel)
        addChild(goldIcon)
        addChild(recommendationIcon)
        addChild(statusLabel)
        addChild(objectiveLabel)
        addChild(rewardLabel)
        addChild(cityProgressLabel)
        addChild(cityHPLabel)
        addChild(recommendationDetailLabel)
        addChild(cityProgressBar)
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
              layout.topBandFrame.contains(layout.incomeFrame),
              layout.topBandFrame.contains(layout.cityProgressFrame),
              layout.topBandFrame.contains(layout.recommendationFrame),
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
        incomePanel.apply(size: layout.incomeFrame.size, style: .normal, showsRivets: false)
        incomePanel.position = CGPoint(x: layout.incomeFrame.midX, y: layout.incomeFrame.midY)
        cityProgressPanel.apply(size: layout.cityProgressFrame.size, style: .normal, showsRivets: false)
        cityProgressPanel.position = CGPoint(
            x: layout.cityProgressFrame.midX,
            y: layout.cityProgressFrame.midY
        )
        // The authored city row sits directly on the battlefield art. Keep
        // the panel in the fixed tree for ownership/tests, but let the
        // progress, HP, and title read against the scenic background.
        cityProgressPanel.alpha = 0
        recommendationPanel.apply(
            size: layout.recommendationFrame.size,
            style: .normal,
            showsRivets: false
        )
        recommendationPanel.position = CGPoint(
            x: layout.recommendationFrame.midX,
            y: layout.recommendationFrame.midY
        )
        goldIcon.texture = Self.goldTexture()
        goldIcon.size = CGSize(width: 22, height: 22)
        goldIcon.position = CGPoint(
            x: layout.incomeFrame.minX + 16,
            y: layout.incomeFrame.midY + 7
        )
        statusLabel.text = CompactNumberFormatter.string(from: content.gold)
        statusLabel.horizontalAlignmentMode = .left
        statusLabel.position = CGPoint(
            x: layout.incomeFrame.minX + 34,
            y: layout.incomeFrame.midY + 7
        )
        rewardLabel.text = "+\(CompactNumberFormatter.string(from: content.goldReward)) ↑"
        rewardLabel.horizontalAlignmentMode = .left
        rewardLabel.position = CGPoint(
            x: layout.incomeFrame.minX + 34,
            y: layout.incomeFrame.midY - 9
        )
        cityProgressLabel.text = "\(content.cityNumber) / \(KingdomGameState.firstCountryCityCount) "
            + content.cityTitle.uppercased()
        cityProgressLabel.fontSize = 12
        cityProgressLabel.position = CGPoint(
            x: layout.cityProgressFrame.midX,
            y: layout.cityProgressFrame.midY + 11
        )
        cityHPLabel.text = "\(CompactNumberFormatter.string(from: content.cityRemainingPower)) / "
            + CompactNumberFormatter.string(from: content.cityMaxPower)
        cityHPLabel.fontSize = 9
        cityHPLabel.position = CGPoint(
            x: layout.cityProgressFrame.midX,
            y: layout.cityProgressFrame.midY - 6
        )
        cityProgressBar.update(size: CGSize(
            width: max(44, layout.cityProgressFrame.width - 16),
            height: 4
        ))
        cityProgressBar.update(progress: CGFloat(content.cityRemainingPower)
            / CGFloat(max(1, content.cityMaxPower)))
        cityProgressBar.position = CGPoint(
            x: layout.cityProgressFrame.midX,
            y: layout.cityProgressFrame.minY + 5
        )
        objectiveLabel.text = "NEXT"
        objectiveLabel.horizontalAlignmentMode = .left
        objectiveLabel.position = CGPoint(
            x: layout.recommendationFrame.minX + 45,
            y: layout.recommendationFrame.midY + 11
        )
        recommendationDetailLabel.text = Self.objectiveText(for: content.recommendation)
        recommendationDetailLabel.horizontalAlignmentMode = .center
        recommendationDetailLabel.fontSize = Self.objectiveFontSize(for: content.recommendation)
        recommendationDetailLabel.position = CGPoint(
            x: layout.recommendationFrame.midX + 22,
            y: layout.recommendationFrame.midY - 8
        )
        recommendationIcon.texture = Self.recommendationTexture(for: content.recommendation)
        recommendationIcon.size = CGSize(width: 28, height: 28)
        recommendationIcon.position = CGPoint(
            x: layout.recommendationFrame.minX + 18,
            y: layout.recommendationFrame.midY
        )

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
            bundle.icon.position = CGPoint(x: 0, y: 7)
            bundle.typeLabel.text = medallion.soldierType.displayName.uppercased()
            bundle.typeLabel.position = CGPoint(x: 0, y: -18)
            bundle.statusLabel.text = Self.statusText(for: medallion.availability)
            bundle.statusLabel.position = CGPoint(x: 0, y: -28)
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
            let role = content.laneDefenseProfile.role(for: lane)
            let chipText: String?
            let chipColor: SKColor
            switch role {
            case .exposed:
                chipText = "OPEN"
                chipColor = GameUITheme.Color.hpFill
            case .fortified:
                chipText = "HELD"
                chipColor = GameUITheme.Color.danger
            case .standard:
                chipText = nil
                chipColor = GameUITheme.Color.textPrimary
            }
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
            bundle.background.strokeColor = chipColor.withAlphaComponent(0.75)
            bundle.background.isHidden = chipText == nil
            bundle.label.text = chipText
            bundle.label.fontColor = chipColor
            bundle.label.position = CGPoint(x: frame.midX, y: frame.midY)
            bundle.label.isHidden = chipText == nil
        }
        tabBar.apply(content: content.tabContent, frame: layout.tabBarFrame)

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
        case .ready(let action, _):
            return "\(action.buildingType.shortDisplayName) · \(CompactNumberFormatter.string(from: action.cost))"
        case .saveFor(let action, let missingGold, _):
            let costText = CompactNumberFormatter.string(from: action.cost)
            let missingGoldText = CompactNumberFormatter.string(from: missingGold)
            return "\(action.buildingType.shortDisplayName) · \(costText) · +\(missingGoldText)"
        case .noAction(let message):
            return message
        }
    }

    private static func objectiveFontSize(
        for recommendation: RecommendedCampRecommendation
    ) -> CGFloat {
        switch recommendation {
        case .noAction:
            return 8
        case .ready:
            return 12
        case .saveFor:
            return 10
        }
    }

    private static func texture(for type: SoldierType) -> SKTexture? {
        let assetName = assetName(for: type)
        if UIImage(named: assetName) != nil {
            let source = SKTexture(imageNamed: assetName)
            return assetName.contains("-walk-")
                ? SKTexture(rect: SoldierAnimationGeometry(type: type).bodyRegion, in: source)
                : source
        }
        return UIImage(systemName: symbolName(for: type)).map(SKTexture.init(image:))
    }

    private static func assetName(for type: SoldierType) -> String {
        let animationFrameName = "\(type.rawValue)-walk-01"
        if UIImage(named: animationFrameName) != nil {
            return animationFrameName
        }
        return type == .infantry ? "normal-soldier" : "\(type.rawValue)-soldier"
    }

    private static func goldTexture() -> SKTexture? {
        guard UIImage(named: "gold-burst") != nil else {
            return UIImage(systemName: "circle.fill").map(SKTexture.init(image:))
        }
        return SKTexture(imageNamed: "gold-burst")
    }

    private static func recommendationTexture(
        for recommendation: RecommendedCampRecommendation
    ) -> SKTexture? {
        let buildingType: BuildingType?
        switch recommendation {
        case .ready(let action, _), .saveFor(let action, _, _):
            buildingType = action.buildingType
        case .noAction:
            buildingType = nil
        }
        guard let buildingType,
              UIImage(named: buildingType.buildingAssetName) != nil else {
            return UIImage(systemName: "sparkles").map(SKTexture.init(image:))
        }
        return SKTexture(imageNamed: buildingType.buildingAssetName)
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

    var currentContentForTesting: BattleHUDContent? {
        currentContent
    }
}
#endif
