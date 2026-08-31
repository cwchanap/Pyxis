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
    let recommendationLevelText: String?
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
        let recommendationLevelText = Self.recommendationLevelText(
            for: recommendation,
            in: state.cityBattleStateForCurrentCity
        )
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
            recommendationLevelText: recommendationLevelText,
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

    private static func recommendationLevelText(
        for recommendation: RecommendedCampRecommendation,
        in cityState: CityBattleState
    ) -> String? {
        let action: RecommendedCampRecommendation.Action
        switch recommendation {
        case .ready(let recommendedAction, _), .saveFor(let recommendedAction, _, _):
            action = recommendedAction
        case .noAction:
            return nil
        }

        switch action.kind {
        case .build:
            return "Lv1"
        case .upgrade:
            let currentLevel = cityState.building(inSlot: action.slot)?.level ?? 1
            return "Lv\(currentLevel)→\(currentLevel + 1)"
        }
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
        let pill: SKShapeNode
        let lockIcon: SKSpriteNode
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
    private let incomeDivider = SKShapeNode()
    private let recommendationIcon = SKSpriteNode()
    private let recommendationCoinIcon = SKSpriteNode()
    private let recommendationCostLabel = SKLabelNode(fontNamed: GameUITheme.Font.medium)
    private let recommendationArrowLabel = SKLabelNode(fontNamed: GameUITheme.Font.medium)
    private let cityTitleLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let statusLabel = SKLabelNode(fontNamed: GameUITheme.Font.medium)
    private let objectiveLabel = SKLabelNode(fontNamed: GameUITheme.Font.medium)
    private let rewardLabel = SKLabelNode(fontNamed: GameUITheme.Font.medium)
    private let cityProgressLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let cityHPLabel = SKLabelNode(fontNamed: GameUITheme.Font.medium)
    private let recommendationDetailLabel = SKLabelNode(fontNamed: GameUITheme.Font.medium)
    private let cityProgressBar = ProgressBarNode(size: .zero, appearance: .forged)
    private let deployPanel = PanelNode(size: .zero)
    private let deployIcon = SKSpriteNode()
    private let deployLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let manualCountLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let tabBar = GameplayTabBarNode(appearance: .forged)
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
            let pill = SKShapeNode()
            let lockIcon = SKSpriteNode()
            let typeLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
            let statusLabel = SKLabelNode(fontNamed: GameUITheme.Font.medium)
            let multiplierLabel = SKLabelNode(fontNamed: GameUITheme.Font.medium)

            root.name = "battleMedallion-\(soldierType.rawValue)"
            panel.name = "battleMedallionPanel-\(soldierType.rawValue)"
            icon.name = "battleMedallionIcon-\(soldierType.rawValue)"
            pill.name = "battleMedallionPill-\(soldierType.rawValue)"
            lockIcon.name = "battleMedallionLock-\(soldierType.rawValue)"
            typeLabel.name = "battleMedallionType-\(soldierType.rawValue)"
            statusLabel.name = "battleMedallionStatus-\(soldierType.rawValue)"
            multiplierLabel.name = "battleMedallionMultiplier-\(soldierType.rawValue)"
            icon.texture = Self.texture(for: soldierType)
            icon.userData = NSMutableDictionary()
            icon.userData?["assetName"] = Self.assetName(for: soldierType)
            icon.size = CGSize(width: 42, height: 42)
            icon.color = GameUITheme.Color.textPrimary
            icon.colorBlendFactor = 0
            lockIcon.texture = UIImage(systemName: "lock.fill").map(SKTexture.init(image:))
            lockIcon.color = SKColor(red: 1, green: 220 / 255, blue: 170 / 255, alpha: 1)
            lockIcon.colorBlendFactor = 1
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
            pill.zPosition = 2
            lockIcon.zPosition = 3
            multiplierLabel.zPosition = 3
            root.addChild(panel)
            root.addChild(icon)
            root.addChild(pill)
            root.addChild(lockIcon)
            root.addChild(typeLabel)
            root.addChild(statusLabel)
            root.addChild(multiplierLabel)
            return MedallionBundle(
                root: root,
                panel: panel,
                icon: icon,
                pill: pill,
                lockIcon: lockIcon,
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
        incomeDivider.name = "battleIncomeDivider"
        recommendationIcon.name = "battleRecommendationIcon"
        recommendationCoinIcon.name = "battleRecommendationCoinIcon"
        recommendationCostLabel.name = "battleRecommendationCostLabel"
        recommendationArrowLabel.name = "battleRecommendationArrowLabel"
        cityTitleLabel.name = "battleCityTitleLabel"
        statusLabel.name = "battleGoldLabel"
        objectiveLabel.name = "battleRecommendationLabel"
        rewardLabel.name = "battleIncomeLabel"
        cityProgressLabel.name = "battleCityProgressLabel"
        cityHPLabel.name = "battleCityHPLabel"
        recommendationDetailLabel.name = "battleRecommendationDetailLabel"
        cityProgressBar.name = "battleCityProgressBar"
        deployPanel.name = "battleDeployPanel"
        deployIcon.name = "battleDeployIcon"
        deployLabel.name = "battleDeployLabel"
        manualCountLabel.name = "battleManualCountLabel"

        for label in [
            statusLabel,
            objectiveLabel,
            rewardLabel,
            cityProgressLabel,
            cityTitleLabel,
            cityHPLabel,
            recommendationDetailLabel,
            recommendationCostLabel,
            recommendationArrowLabel,
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
        cityTitleLabel.fontSize = 21
        cityTitleLabel.fontColor = GameUITheme.Color.textPrimary
        cityHPLabel.fontSize = 8
        cityHPLabel.fontColor = GameUITheme.Color.textSecondary
        recommendationDetailLabel.fontSize = 8
        recommendationDetailLabel.fontColor = GameUITheme.Color.textSecondary
        recommendationCostLabel.fontSize = 15
        recommendationCostLabel.fontColor = SKColor(
            red: 1,
            green: 208 / 255,
            blue: 97 / 255,
            alpha: 1
        )
        recommendationArrowLabel.fontSize = 17
        recommendationArrowLabel.fontColor = GameUITheme.Color.textSecondary
        deployLabel.fontSize = 16
        manualCountLabel.fontSize = 13

        addChild(incomePanel)
        addChild(cityProgressPanel)
        addChild(recommendationPanel)
        addChild(goldIcon)
        addChild(incomeDivider)
        addChild(recommendationIcon)
        addChild(recommendationCoinIcon)
        addChild(recommendationCostLabel)
        addChild(recommendationArrowLabel)
        addChild(cityTitleLabel)
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
        addChild(deployIcon)
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
    // swiftlint:disable:next cyclomatic_complexity
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
              layout.sceneFrame.contains(layout.tabBarFrame),
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
        incomePanel.apply(
            size: layout.incomeFrame.size,
            style: .normal,
            showsRivets: true,
            appearance: .forged
        )
        incomePanel.position = CGPoint(x: layout.incomeFrame.midX, y: layout.incomeFrame.midY)
        cityProgressPanel.apply(
            size: layout.cityProgressFrame.size,
            style: .normal,
            showsRivets: false,
            appearance: .forged
        )
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
            showsRivets: true,
            appearance: .forged
        )
        recommendationPanel.position = CGPoint(
            x: layout.recommendationFrame.midX,
            y: layout.recommendationFrame.midY
        )
        goldIcon.texture = Self.goldTexture()
        goldIcon.size = CGSize(width: 34, height: 34)
        goldIcon.position = CGPoint(
            x: layout.incomeFrame.minX + 22,
            y: layout.incomeFrame.midY
        )
        statusLabel.text = CompactNumberFormatter.string(from: content.gold)
        statusLabel.fontSize = 21
        statusLabel.fontColor = SKColor(red: 1, green: 208 / 255, blue: 97 / 255, alpha: 1)
        statusLabel.horizontalAlignmentMode = .left
        statusLabel.position = CGPoint(
            x: layout.incomeFrame.minX + 46,
            y: layout.incomeFrame.midY
        )
        rewardLabel.text = "+\(CompactNumberFormatter.string(from: content.goldReward))"
        rewardLabel.fontSize = 12
        rewardLabel.fontColor = SKColor(red: 124 / 255, green: 240 / 255, blue: 160 / 255, alpha: 1)
        rewardLabel.horizontalAlignmentMode = .left
        rewardLabel.position = CGPoint(
            x: layout.incomeFrame.minX + 112,
            y: layout.incomeFrame.midY
        )
        incomeDivider.path = CGPath(
            rect: CGRect(
                x: layout.incomeFrame.minX + 101,
                y: layout.incomeFrame.midY - 11,
                width: 1,
                height: 22
            ),
            transform: nil
        )
        incomeDivider.fillColor = SKColor(red: 255 / 255, green: 206 / 255, blue: 140 / 255, alpha: 0.5)
        incomeDivider.strokeColor = .clear
        cityProgressLabel.text = "\(content.cityNumber) / \(KingdomGameState.firstCountryCityCount)"
        cityProgressLabel.fontSize = 11
        cityProgressLabel.fontColor = SKColor(red: 255 / 255, green: 207 / 255, blue: 138 / 255, alpha: 1)
        cityProgressLabel.horizontalAlignmentMode = .left
        cityProgressLabel.position = CGPoint(
            x: layout.cityProgressFrame.minX,
            y: layout.cityProgressFrame.maxY - 21
        )
        cityTitleLabel.text = content.cityTitle.uppercased()
        cityTitleLabel.fontSize = 21
        cityTitleLabel.horizontalAlignmentMode = .left
        cityTitleLabel.position = CGPoint(
            x: layout.cityProgressFrame.minX + cityProgressLabel.frame.width + 9,
            y: layout.cityProgressFrame.maxY - 21
        )
        cityHPLabel.text = nil
        cityHPLabel.isHidden = true
        cityProgressBar.update(size: CGSize(
            width: min(288, max(44, layout.cityProgressFrame.width - 16)),
            height: 14
        ))
        cityProgressBar.update(progress: CGFloat(content.cityRemainingPower)
            / CGFloat(max(1, content.cityMaxPower)))
        cityProgressBar.position = CGPoint(
            x: layout.cityProgressFrame.midX,
            y: layout.cityProgressFrame.minY + 11
        )
        objectiveLabel.text = "NEXT"
        objectiveLabel.fontSize = 9.5
        objectiveLabel.fontColor = SKColor(red: 1, green: 200 / 255, blue: 97 / 255, alpha: 1)
        objectiveLabel.horizontalAlignmentMode = .left
        objectiveLabel.position = CGPoint(
            x: layout.recommendationFrame.minX + 51,
            y: layout.recommendationFrame.midY + 9
        )
        recommendationDetailLabel.text = Self.objectiveText(
            for: content.recommendation,
            levelText: content.recommendationLevelText
        )
        recommendationDetailLabel.horizontalAlignmentMode = .left
        recommendationDetailLabel.fontSize = 15
        recommendationDetailLabel.fontColor = GameUITheme.Color.textPrimary
        recommendationDetailLabel.position = CGPoint(
            x: layout.recommendationFrame.minX + 83,
            y: layout.recommendationFrame.midY - 7
        )
        recommendationIcon.texture = Self.recommendationTexture(for: content.recommendation)
        recommendationIcon.size = CGSize(width: 36, height: 36)
        recommendationIcon.position = CGPoint(
            x: layout.recommendationFrame.minX + 26,
            y: layout.recommendationFrame.midY
        )
        recommendationCoinIcon.texture = Self.goldTexture()
        recommendationCoinIcon.size = CGSize(width: 16, height: 16)
        recommendationCoinIcon.position = CGPoint(
            x: layout.recommendationFrame.maxX - 54,
            y: layout.recommendationFrame.midY
        )
        recommendationCostLabel.text = Self.recommendationCostText(for: content.recommendation)
        recommendationCostLabel.fontSize = 15
        recommendationCostLabel.horizontalAlignmentMode = .left
        recommendationCostLabel.position = CGPoint(
            x: layout.recommendationFrame.maxX - 44,
            y: layout.recommendationFrame.midY - 7
        )
        recommendationArrowLabel.text = "›"
        recommendationArrowLabel.fontSize = 17
        recommendationArrowLabel.horizontalAlignmentMode = .left
        recommendationArrowLabel.position = CGPoint(
            x: layout.recommendationFrame.maxX - 15,
            y: layout.recommendationFrame.midY - 7
        )
        let recommendationHasAction: Bool
        switch content.recommendation {
        case .ready, .saveFor:
            recommendationHasAction = true
        case .noAction:
            recommendationHasAction = false
        }
        recommendationCoinIcon.isHidden = !recommendationHasAction
        recommendationCostLabel.isHidden = !recommendationHasAction
        recommendationArrowLabel.isHidden = !recommendationHasAction

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
            bundle.panel.apply(
                size: frame.size,
                style: style,
                showsRivets: false,
                appearance: .forged,
                shape: .hexagon
            )
            bundle.root.position = CGPoint(x: frame.midX, y: frame.midY)
            bundle.icon.size = CGSize(width: 44, height: 44)
            bundle.icon.position = CGPoint(x: 0, y: 7)
            bundle.icon.alpha = {
                switch medallion.availability {
                case .locked:
                    return 0.28
                case .available, .unbuilt:
                    return 1
                }
            }()
            bundle.typeLabel.text = nil
            bundle.typeLabel.isHidden = true
            bundle.statusLabel.text = nil
            bundle.statusLabel.isHidden = true

            let isLocked: Bool
            let pillColor: SKColor
            let pillTextColor: SKColor
            switch medallion.availability {
            case .locked(let unlocksAtCity):
                isLocked = true
                bundle.multiplierLabel.text = "\(unlocksAtCity)"
                pillColor = SKColor(red: 42 / 255, green: 38 / 255, blue: 32 / 255, alpha: 0.96)
                pillTextColor = SKColor(red: 255 / 255, green: 220 / 255, blue: 170 / 255, alpha: 0.65)
            case .available, .unbuilt:
                isLocked = false
                bundle.multiplierLabel.text = Self.multiplierText(medallion.damageMultiplier)
                pillColor = medallion.damageMultiplier > 1
                    ? SKColor(red: 95 / 255, green: 240 / 255, blue: 154 / 255, alpha: 1)
                    : SKColor(red: 255 / 255, green: 138 / 255, blue: 114 / 255, alpha: 1)
                pillTextColor = medallion.damageMultiplier > 1
                    ? SKColor(red: 4 / 255, green: 37 / 255, blue: 15 / 255, alpha: 1)
                    : GameUITheme.Color.textPrimary
            }
            let pillWidth: CGFloat = isLocked ? 26 : 42
            bundle.pill.path = CGPath(
                roundedRect: CGRect(
                    x: -pillWidth / 2,
                    y: -32,
                    width: pillWidth,
                    height: 17
                ),
                cornerWidth: 8.5,
                cornerHeight: 8.5,
                transform: nil
            )
            bundle.pill.fillColor = pillColor
            bundle.pill.strokeColor = .clear
            bundle.pill.isHidden = false
            bundle.multiplierLabel.fontSize = 9
            bundle.multiplierLabel.fontColor = pillTextColor
            bundle.multiplierLabel.position = CGPoint(
                x: isLocked ? 4 : 0,
                y: -23.5
            )
            bundle.lockIcon.size = CGSize(width: 8, height: 8)
            bundle.lockIcon.position = CGPoint(x: -7, y: -23.5)
            bundle.lockIcon.isHidden = !isLocked
        }

        deployPanel.apply(
            size: layout.deployFrame.size,
            style: .primaryAction,
            showsRivets: true,
            appearance: .forged
        )
        deployPanel.position = CGPoint(x: layout.deployFrame.midX, y: layout.deployFrame.midY)
        deployIcon.texture = Self.texture(for: content.selectedSoldierType)
        deployIcon.size = CGSize(width: 46, height: 46)
        deployIcon.position = CGPoint(
            x: layout.deployFrame.midX - 78,
            y: layout.deployFrame.midY
        )
        deployLabel.text = "DEPLOY"
        deployLabel.fontColor = SKColor(red: 1, green: 244 / 255, blue: 222 / 255, alpha: 1)
        deployLabel.position = CGPoint(
            x: layout.deployFrame.midX - 12,
            y: layout.deployFrame.midY
        )
        manualCountLabel.text = "\(content.manualCount)/\(content.manualCapacity)"
        manualCountLabel.fontColor = SKColor(
            red: 1,
            green: 235 / 255,
            blue: 200 / 255,
            alpha: 0.85
        )
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
                bundle.background.fillColor = SKColor(
                    red: 20 / 255,
                    green: 26 / 255,
                    blue: 16 / 255,
                    alpha: 0.96
                )
            case .fortified:
                chipText = "HELD"
                chipColor = GameUITheme.Color.danger
                bundle.background.fillColor = SKColor(
                    red: 34 / 255,
                    green: 14 / 255,
                    blue: 8 / 255,
                    alpha: 0.96
                )
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
                cornerWidth: 4,
                cornerHeight: 4,
                transform: nil
            )
            bundle.background.strokeColor = chipColor.withAlphaComponent(0.75)
            bundle.background.lineWidth = 1.5
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

    private static func multiplierText(_ multiplier: Double) -> String {
        String(format: "%.2f", multiplier)
    }

    private static func objectiveText(
        for recommendation: RecommendedCampRecommendation,
        levelText: String?
    ) -> String {
        let level = levelText.map { " \($0)" } ?? ""
        switch recommendation {
        case .ready(let action, _), .saveFor(let action, _, _):
            return "\(action.buildingType.shortDisplayName)\(level)"
        case .noAction(let message):
            return message
        }
    }

    private static func recommendationCostText(
        for recommendation: RecommendedCampRecommendation
    ) -> String? {
        switch recommendation {
        case .ready(let action, _), .saveFor(let action, _, _):
            return CompactNumberFormatter.string(from: action.cost)
        case .noAction:
            return nil
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
        let size = CGSize(width: 34, height: 34)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            let colors = [
                SKColor(red: 1, green: 246 / 255, blue: 207 / 255, alpha: 1).cgColor,
                SKColor(red: 1, green: 204 / 255, blue: 56 / 255, alpha: 1).cgColor,
                SKColor(red: 184 / 255, green: 121 / 255, blue: 10 / 255, alpha: 1).cgColor
            ] as CFArray
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: [0, 0.52, 1]
            ) {
                context.cgContext.drawRadialGradient(
                    gradient,
                    startCenter: CGPoint(x: 11, y: 10),
                    startRadius: 1,
                    endCenter: CGPoint(x: 17, y: 17),
                    endRadius: 18,
                    options: []
                )
            }
            context.cgContext.setStrokeColor(
                SKColor(red: 120 / 255, green: 78 / 255, blue: 4 / 255, alpha: 0.6).cgColor
            )
            context.cgContext.setLineWidth(1.5)
            context.cgContext.strokeEllipse(in: CGRect(x: 1.5, y: 1.5, width: 31, height: 31))
        }
        return SKTexture(image: image)
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
