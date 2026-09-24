//
//  BattleHUDNode.swift
//  Pyxis
//

import SpriteKit
import UIKit

struct BattleHUDContent: Equatable {
    /// Compact Vanguard Captain view state (HPA-475). Projected from the
    /// durable `siegeProgress.captain` plus the live Rally timer — no new
    /// domain state owner lives here. `.recovering` keeps the Rally timer
    /// beside the countdown because a mid-Rally retreat leaves protection
    /// running on the captured lane.
    enum CaptainStatus: Equatable {
        case unavailable
        case ready(currentHP: Int, maxHP: Int, rallyReady: Bool)
        case active(currentHP: Int, maxHP: Int)
        case used(currentHP: Int, maxHP: Int)
        case recovering(seconds: Double, rallyConsumed: Bool, rallyActive: Bool)

        /// Rally is tappable only in `.ready` with a deployed Captain —
        /// Active, Used, and Recovering all project Rally state but stay
        /// inert, so the strip never offers a control that silently no-ops
        /// (the model's `consumeVanguardRally` gate is the same predicate).
        var isRallyActionable: Bool {
            if case .ready(_, _, let rallyReady) = self {
                return rallyReady
            }
            return false
        }
    }

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
    let keepRemainingPower: Int
    let keepMaxPower: Int
    let selectedLane: BattleLane
    let laneDefenseProfile: LaneDefenseProfile
    let recommendation: RecommendedCampRecommendation
    let recommendationLevelText: String?
    let manualCount: Int
    let manualCapacity: Int
    let selectedSoldierType: SoldierType
    let medallions: [Medallion]
    let enabledTabs: Set<GameplayTab>
    let showsCampAttention: Bool
    /// Test seam: retargeted directly by HUD strip tests; production always
    /// sets this through `project`.
    var captainStatus: CaptainStatus = .unavailable

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
        selectedSoldierType: SoldierType = .infantry,
        captainIsDeployed: Bool = false,
        rallyRemainingSeconds: Double = 0
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

        var content = BattleHUDContent(
            cityTitle: state.displayCityTitle,
            cityNumber: state.cityNumberInCountry,
            gold: state.gold,
            goldReward: state.currentGoldReward,
            keepRemainingPower: state.currentKeepRemainingPower,
            keepMaxPower: state.currentKeepMaxPower,
            selectedLane: state.siegeProgress.selectedLane,
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
        content.captainStatus = Self.captainStatus(
            for: state,
            captainIsDeployed: captainIsDeployed,
            rallyRemainingSeconds: rallyRemainingSeconds
        )
        return content
    }

    /// Active follows the live Rally timer (> 0) alone — protection rides
    /// the captured lane for its full duration even if the Captain falls,
    /// so deployment never gates it and recovery still carries the timer.
    /// A durably consumed Rally with an expired timer shows Used; Ready's
    /// `rallyReady` (the only actionable state) requires a live Captain.
    private static func captainStatus(
        for state: KingdomGameState,
        captainIsDeployed: Bool,
        rallyRemainingSeconds: Double
    ) -> CaptainStatus {
        guard let captain = state.siegeProgress.captain,
              VanguardCaptainRules.isAvailable(cityNumber: state.cityNumberInCountry) else {
            return .unavailable
        }
        let maxHP = VanguardCaptainRules.maxHP(for: state.normalSoldierUpgradeLevel)
        let rallyActive = rallyRemainingSeconds > 0
        if captain.remainingHP <= 0 {
            return .recovering(
                seconds: captain.recoveryRemainingSeconds,
                rallyConsumed: captain.rallyConsumed,
                rallyActive: rallyActive
            )
        }
        if rallyActive {
            return .active(currentHP: captain.remainingHP, maxHP: maxHP)
        }
        if captain.rallyConsumed {
            return .used(currentHP: captain.remainingHP, maxHP: maxHP)
        }
        return .ready(
            currentHP: captain.remainingHP,
            maxHP: maxHP,
            rallyReady: captainIsDeployed
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
        case rally
        case selectLane(BattleLane)
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
        let lockIcon: SKShapeNode
        let typeLabel: SKLabelNode
        let statusLabel: SKLabelNode
        let multiplierLabel: SKLabelNode
    }

    private struct LaneChipBundle {
        let background: SKShapeNode
        let shield: SKShapeNode
        let flag: SKShapeNode
        let label: SKLabelNode
    }

    private let incomePanel = PanelNode(size: .zero)
    private let cityProgressPanel = PanelNode(size: .zero)
    private let recommendationPanel = PanelNode(size: .zero)
    private let goldIcon = SKSpriteNode()
    private let incomeDivider = SKShapeNode()
    private let incomeArrow = SKShapeNode()
    private let recommendationIconWell = SKShapeNode()
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
    private let recommendationLevelLabel = SKLabelNode(fontNamed: GameUITheme.Font.medium)
    private let cityProgressBar = ProgressBarNode(size: .zero, appearance: .forged)
    private let deployPanel = PanelNode(size: .zero)
    private let deployIcon = SKSpriteNode()
    private let deployLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let deployDivider = SKShapeNode()
    private let manualCountLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let captainStripPanel = PanelNode(size: .zero)
    private let captainPortrait = SKSpriteNode()
    private let captainStatusLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let captainRallyLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let tabBar = GameplayTabBarNode(appearance: .forged)
    private let medallions: [MedallionBundle]
    private let laneChips: [BattleLane: LaneChipBundle]

    private var deployHitFrame: CGRect?
    private var rallyHitTarget: CGRect?
    private var currentLayout: BattleChromeLayout?
    private var currentContent: BattleHUDContent?

    override init() {
        medallions = SoldierType.allCases.map { soldierType in
            let root = SKNode()
            let panel = PanelNode(size: .zero)
            let icon = SKSpriteNode()
            let pill = SKShapeNode()
            let lockIcon = SKShapeNode(path: Self.makeLockPath())
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
            lockIcon.fillColor = .clear
            lockIcon.strokeColor = SKColor(red: 1, green: 220 / 255, blue: 170 / 255, alpha: 1)
            lockIcon.lineWidth = 1.2
            lockIcon.lineCap = .round
            lockIcon.lineJoin = .round
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
            let shield = SKShapeNode(path: Self.makeShieldPath())
            let flag = SKShapeNode(path: Self.makeFlagPath())
            let label = SKLabelNode(fontNamed: GameUITheme.Font.bold)
            background.name = "battleLaneChip-\(lane.rawValue)"
            background.fillColor = GameUITheme.Color.panelFill.withAlphaComponent(0.92)
            background.strokeColor = GameUITheme.Color.panelStroke
            background.lineWidth = 1
            shield.name = "battleLaneChipShield-\(lane.rawValue)"
            shield.fillColor = .clear
            shield.strokeColor = GameUITheme.Color.textPrimary
            shield.lineWidth = 1.2
            shield.lineCap = .round
            shield.lineJoin = .round
            flag.name = "battleLaneChipFlag-\(lane.rawValue)"
            flag.fillColor = GameUITheme.Color.textPrimary
            flag.strokeColor = GameUITheme.Color.textPrimary
            flag.lineWidth = 1.2
            flag.lineCap = .round
            flag.lineJoin = .round
            flag.isHidden = true
            label.name = "battleLaneChipLabel-\(lane.rawValue)"
            label.text = "OPEN"
            label.fontSize = 9
            label.fontColor = GameUITheme.Color.textPrimary
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            return (lane, LaneChipBundle(background: background, shield: shield, flag: flag, label: label))
        })
        super.init()
        name = "battleHUD"
        incomePanel.name = "battleIncomePanel"
        cityProgressPanel.name = "battleCityProgressPanel"
        recommendationPanel.name = "battleRecommendationPanel"
        goldIcon.name = "battleGoldIcon"
        incomeDivider.name = "battleIncomeDivider"
        incomeArrow.name = "battleIncomeArrow"
        recommendationIconWell.name = "battleRecommendationIconWell"
        recommendationIcon.name = "battleRecommendationIcon"
        recommendationCoinIcon.name = "battleRecommendationCoinIcon"
        recommendationCostLabel.name = "battleRecommendationCostLabel"
        recommendationArrowLabel.name = "battleRecommendationArrowLabel"
        recommendationLevelLabel.name = "battleRecommendationLevelLabel"
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
        deployDivider.name = "battleDeployDivider"
        manualCountLabel.name = "battleManualCountLabel"
        captainStripPanel.name = "battleCaptainStripPanel"
        captainPortrait.name = "battleCaptainPortrait"
        captainStatusLabel.name = "battleCaptainStatusLabel"
        captainRallyLabel.name = "battleCaptainRallyLabel"

        for label in [
            statusLabel,
            objectiveLabel,
            rewardLabel,
            cityProgressLabel,
            cityTitleLabel,
            cityHPLabel,
            recommendationDetailLabel,
            recommendationLevelLabel,
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
        recommendationLevelLabel.fontSize = 10
        recommendationLevelLabel.fontColor = GameUITheme.Color.textSecondary
        recommendationCostLabel.fontSize = 15
        recommendationCostLabel.fontColor = SKColor(
            red: 1,
            green: 208 / 255,
            blue: 97 / 255,
            alpha: 1
        )
        recommendationArrowLabel.fontSize = 17
        recommendationArrowLabel.fontColor = GameUITheme.Color.textSecondary
        deployLabel.fontSize = 18
        manualCountLabel.fontSize = 13
        captainPortrait.color = GameUITheme.Color.textPrimary
        captainPortrait.colorBlendFactor = 0
        for label in [captainStatusLabel, captainRallyLabel] {
            label.horizontalAlignmentMode = .left
            label.verticalAlignmentMode = .center
            label.fontColor = GameUITheme.Color.textPrimary
            label.isHidden = true
        }
        captainRallyLabel.fontColor = GameUITheme.Color.gold
        captainStripPanel.isHidden = true
        captainPortrait.isHidden = true

        let incomeArrowPath = CGMutablePath()
        incomeArrowPath.move(to: CGPoint(x: 0, y: -4))
        incomeArrowPath.addLine(to: CGPoint(x: 0, y: 4))
        incomeArrowPath.move(to: CGPoint(x: -3, y: 1))
        incomeArrowPath.addLine(to: CGPoint(x: 0, y: 4))
        incomeArrowPath.addLine(to: CGPoint(x: 3, y: 1))
        incomeArrow.path = incomeArrowPath
        incomeArrow.fillColor = .clear
        incomeArrow.strokeColor = SKColor(red: 124 / 255, green: 240 / 255, blue: 160 / 255, alpha: 1)
        incomeArrow.lineWidth = 1.2
        incomeArrow.lineCap = .round
        incomeArrow.lineJoin = .round

        recommendationIconWell.path = CGPath(
            roundedRect: CGRect(x: -20, y: -20, width: 40, height: 40),
            cornerWidth: 8,
            cornerHeight: 8,
            transform: nil
        )
        recommendationIconWell.fillColor = SKColor(red: 17 / 255, green: 10 / 255, blue: 3 / 255, alpha: 0.82)
        recommendationIconWell.strokeColor = SKColor(red: 255 / 255, green: 180 / 255, blue: 60 / 255, alpha: 0.28)
        recommendationIconWell.lineWidth = 1

        addChild(incomePanel)
        addChild(cityProgressPanel)
        addChild(recommendationPanel)
        addChild(goldIcon)
        addChild(incomeDivider)
        addChild(incomeArrow)
        addChild(recommendationIconWell)
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
        addChild(recommendationLevelLabel)
        addChild(cityProgressBar)
        for bundle in medallions {
            addChild(bundle.root)
        }
        addChild(deployPanel)
        addChild(deployIcon)
        addChild(deployLabel)
        addChild(deployDivider)
        addChild(manualCountLabel)
        addChild(captainStripPanel)
        addChild(captainPortrait)
        addChild(captainStatusLabel)
        addChild(captainRallyLabel)
        for lane in BattleLane.allCases {
            addChild(laneChips[lane]!.background)
            addChild(laneChips[lane]!.shield)
            addChild(laneChips[lane]!.flag)
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
              layout.laneChipHitFrames.count == laneChips.count,
              layout.battlefield.isVisible,
              layout.battlefieldFrame.height >= minimumBattlefieldHeight,
              layout.topBandFrame.contains(layout.incomeFrame),
              layout.topBandFrame.contains(layout.cityProgressFrame),
              layout.topBandFrame.contains(layout.recommendationFrame),
              layout.safeFrame.contains(layout.deployFrame),
              [layout.deployActionFrame, layout.captainStripFrame, layout.rallyHitFrame]
                  .allSatisfy({ layout.deployFrame.contains($0) }),
              layout.deployActionFrame.width >= BattleChromeLayout.minimumDeployActionWidth,
              layout.rallyHitFrame.width >= 44,
              layout.rallyHitFrame.height >= 44,
              !layout.deployActionFrame.intersects(layout.captainStripFrame),
              !layout.deployActionFrame.intersects(layout.rallyHitFrame),
              layout.captainStripFrame.contains(layout.rallyHitFrame),
              layout.sceneFrame.contains(layout.tabBarFrame),
              layout.medallionHitFrames.allSatisfy({
                  layout.safeFrame.contains($0) && $0.width >= 44 && $0.height >= 44
              }),
              layout.tabHitFrames.allSatisfy({
                  layout.safeFrame.contains($0) && $0.width >= 44 && $0.height >= 44
              }),
              BattleLane.allCases.allSatisfy({
                  guard let frame = layout.laneChipFrames[$0],
                        let hitFrame = layout.laneChipHitFrames[$0] else { return false }
                  return layout.battlefieldFrame.contains(frame)
                      && layout.battlefieldFrame.contains(hitFrame)
                      && hitFrame.width >= 44
                      && hitFrame.height >= 44
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
            appearance: .forged,
            forgedTreatment: .objective
        )
        recommendationPanel.position = CGPoint(
            x: layout.recommendationFrame.midX,
            y: layout.recommendationFrame.midY
        )
        goldIcon.texture = Self.cachedGoldTexture
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
        // The income row internals are authored for the 160pt panel. Narrower
        // (compact) panels right-anchor the earn-rate chip and pull the divider
        // in so no element can spill into the adjacent city row.
        let incomeUsesAuthoredOffsets = layout.incomeFrame.width >= 150
        rewardLabel.position = CGPoint(
            x: incomeUsesAuthoredOffsets
                ? layout.incomeFrame.minX + 112
                : layout.incomeFrame.maxX - 12 - rewardLabel.frame.width,
            y: layout.incomeFrame.midY
        )
        incomeArrow.position = CGPoint(
            x: rewardLabel.position.x + rewardLabel.frame.width + 7,
            y: layout.incomeFrame.midY
        )
        incomeDivider.path = CGPath(
            rect: CGRect(
                x: incomeUsesAuthoredOffsets
                    ? layout.incomeFrame.minX + 101
                    : layout.incomeFrame.maxX - 52,
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
        cityTitleLabel.text = content.cityTitle.uppercased()
        cityTitleLabel.fontSize = 21
        cityTitleLabel.horizontalAlignmentMode = .left
        let cityGroupGap: CGFloat = 9
        let cityFrame = layout.cityProgressFrame
        let cityProgressBarSize: CGSize
        if layout.isCompact {
            // Compact phones split the authored one-line group: the fitted
            // title takes the row's upper line alone; the counter shares the
            // HP-bar line so neither can spill under the settings gear.
            let titleText = content.cityTitle.uppercased()
            cityTitleLabel.fontSize = SingleLineTextFitter.fittedFontSize(
                titleText,
                startingAt: 21,
                minimum: 9,
                maximumWidth: max(24, cityFrame.width - 8),
                measure: Self.measureBoldTextWidth
            ) ?? 9
            // ponytail: 9pt floor — the longest authored name (16 chars) fits
            // at 9pt in the narrowest supported compact frame; a longer future
            // name would need a copy ceiling, not more shrinking.
            cityTitleLabel.position = CGPoint(
                x: cityFrame.midX - cityTitleLabel.frame.width / 2,
                y: cityFrame.maxY - 21
            )
            cityProgressLabel.position = CGPoint(
                x: cityFrame.minX,
                y: cityFrame.minY + 11
            )
            cityProgressBarSize = CGSize(
                width: max(44, cityFrame.width - cityProgressLabel.frame.width - 10),
                height: 14
            )
        } else {
            let cityGroupWidth = cityProgressLabel.frame.width
                + cityGroupGap
                + cityTitleLabel.frame.width
            let cityGroupMinX = cityFrame.midX - cityGroupWidth / 2
            let cityGroupY = layout.sceneFrame.maxY - 122.5
            cityProgressLabel.position = CGPoint(
                x: cityGroupMinX,
                y: cityGroupY
            )
            cityTitleLabel.position = CGPoint(
                x: cityGroupMinX + cityProgressLabel.frame.width + cityGroupGap,
                y: cityGroupY
            )
            cityProgressBarSize = CGSize(
                width: min(288, max(44, cityFrame.width - 16)),
                height: 14
            )
        }
        cityHPLabel.text = nil
        cityHPLabel.isHidden = true
        cityProgressBar.update(size: cityProgressBarSize)
        cityProgressBar.update(progress: CGFloat(content.keepRemainingPower)
            / CGFloat(max(1, content.keepMaxPower)))
        cityProgressBar.position = CGPoint(
            x: layout.isCompact
                ? cityFrame.maxX - cityProgressBarSize.width / 2
                : cityFrame.midX,
            y: cityFrame.minY + 11
        )
        objectiveLabel.text = "NEXT"
        objectiveLabel.fontSize = 9.5
        objectiveLabel.fontColor = SKColor(red: 1, green: 200 / 255, blue: 97 / 255, alpha: 1)
        objectiveLabel.horizontalAlignmentMode = .left
        objectiveLabel.position = CGPoint(
            x: layout.recommendationFrame.minX + 51,
            y: layout.recommendationFrame.midY
        )
        recommendationDetailLabel.text = Self.objectiveText(
            for: content.recommendation
        )
        recommendationDetailLabel.horizontalAlignmentMode = .left
        recommendationDetailLabel.fontSize = 15
        recommendationDetailLabel.fontColor = GameUITheme.Color.textPrimary
        recommendationDetailLabel.position = CGPoint(
            x: layout.recommendationFrame.minX + 83,
            y: layout.recommendationFrame.midY
        )
        recommendationLevelLabel.text = content.recommendationLevelText
        recommendationLevelLabel.horizontalAlignmentMode = .left
        recommendationLevelLabel.fontSize = 10
        recommendationLevelLabel.fontColor = GameUITheme.Color.textSecondary
        recommendationLevelLabel.position = CGPoint(
            x: recommendationDetailLabel.position.x + recommendationDetailLabel.frame.width + 7,
            y: layout.recommendationFrame.midY
        )
        recommendationIcon.texture = Self.recommendationTexture(for: content.recommendation)
        recommendationIcon.size = CGSize(width: 36, height: 36)
        recommendationIcon.position = CGPoint(
            x: layout.recommendationFrame.minX + 26,
            y: layout.recommendationFrame.midY
        )
        recommendationIconWell.position = recommendationIcon.position
        recommendationCoinIcon.texture = Self.cachedGoldTexture
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
            y: layout.recommendationFrame.midY
        )
        recommendationArrowLabel.text = "›"
        recommendationArrowLabel.fontSize = 17
        recommendationArrowLabel.horizontalAlignmentMode = .left
        recommendationArrowLabel.position = CGPoint(
            x: layout.recommendationFrame.maxX - 15,
            y: layout.recommendationFrame.midY
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
        recommendationLevelLabel.isHidden = !recommendationHasAction

        for (index, bundle) in medallions.enumerated() {
            let medallion = content.medallions[index]
            let frame = layout.medallionFrames[index]
            let isAvailable: Bool
            switch medallion.availability {
            case .available:
                isAvailable = true
            case .unbuilt, .locked:
                isAvailable = false
            }
            let isSelected = medallion.soldierType == content.selectedSoldierType && isAvailable
            let style = isSelected ? PanelNode.Style.selected : Self.panelStyle(for: medallion.availability)
            let treatment: PanelNode.ForgedTreatment
            switch medallion.availability {
            case .locked:
                treatment = .medallionLocked
            case .available, .unbuilt:
                treatment = isSelected ? .medallionSelected : .medallionAvailable
            }
            bundle.panel.apply(
                size: frame.size,
                style: style,
                showsRivets: false,
                appearance: .forged,
                shape: .hexagon,
                forgedTreatment: treatment
            )
            bundle.root.position = CGPoint(
                x: frame.midX,
                y: frame.midY + (isSelected ? 5 : 0)
            )
            bundle.icon.size = CGSize(width: 44, height: 44)
            bundle.icon.position = CGPoint(x: 0, y: 7)
            bundle.icon.alpha = {
                switch medallion.availability {
                case .locked:
                    return 0.22
                case .available:
                    return isSelected ? 1 : 0.66
                case .unbuilt:
                    return 0.66
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
                pillTextColor = medallion.damageMultiplier > 1
                    ? SKColor(red: 4 / 255, green: 37 / 255, blue: 15 / 255, alpha: 1)
                    : GameUITheme.Color.textPrimary
                pillColor = .white
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
            bundle.pill.fillTexture = isLocked
                ? nil
                : medallion.damageMultiplier > 1
                    ? Self.favorableMultiplierTexture
                    : Self.disadvantagedMultiplierTexture
            bundle.pill.fillColor = pillColor
            bundle.pill.strokeColor = isLocked
                ? .clear
                : SKColor(red: 30 / 255, green: 20 / 255, blue: 10 / 255, alpha: 0.60)
            bundle.pill.glowWidth = isLocked ? 0 : 1.5
            bundle.pill.isHidden = isLocked
            bundle.multiplierLabel.fontSize = 9
            bundle.multiplierLabel.fontColor = pillTextColor
            bundle.multiplierLabel.position = CGPoint(
                x: isLocked ? 4 : 0,
                y: isLocked ? -18 : -23.5
            )
            bundle.lockIcon.fillColor = isLocked
                ? SKColor(red: 255 / 255, green: 220 / 255, blue: 170 / 255, alpha: 0.85)
                : .clear
            bundle.lockIcon.strokeColor = isLocked
                ? .clear
                : SKColor(red: 1, green: 220 / 255, blue: 170 / 255, alpha: 1)
            bundle.lockIcon.position = CGPoint(x: -7, y: isLocked ? -18 : -23.5)
            bundle.lockIcon.isHidden = !isLocked
        }

        // City 1–2 keep the authored full-width Deploy bar and full hit
        // target; City 3+ shrink Deploy into the action frame so the
        // Captain strip and Rally hit target stay disjoint.
        let showsCaptainStrip = content.captainStatus != .unavailable
        let deployDisplayFrame = showsCaptainStrip ? layout.deployActionFrame : layout.deployFrame
        deployPanel.apply(
            size: deployDisplayFrame.size,
            style: .primaryAction,
            showsRivets: true,
            appearance: .forged,
            forgedTreatment: .deploy
        )
        deployPanel.position = CGPoint(x: deployDisplayFrame.midX, y: deployDisplayFrame.midY)
        deployIcon.texture = Self.texture(for: content.selectedSoldierType)
        deployIcon.size = CGSize(width: 46, height: 46)
        deployLabel.text = "DEPLOY"
        deployLabel.fontColor = SKColor(red: 1, green: 244 / 255, blue: 222 / 255, alpha: 1)
        manualCountLabel.text = "\(content.manualCount)/\(content.manualCapacity)"
        manualCountLabel.fontColor = SKColor(
            red: 1,
            green: 235 / 255,
            blue: 200 / 255,
            alpha: 0.85
        )
        let deploySpacing: CGFloat = 20
        let deployDividerWidth: CGFloat = 1
        let deployClusterWidth = deployIcon.size.width
            + deploySpacing
            + deployLabel.frame.width
            + deploySpacing
            + deployDividerWidth
            + deploySpacing
            + manualCountLabel.frame.width
        let deployClusterMinX = deployDisplayFrame.midX - deployClusterWidth / 2
        let deployCenterY = deployDisplayFrame.midY
        deployIcon.position = CGPoint(
            x: deployClusterMinX + deployIcon.size.width / 2,
            y: deployCenterY
        )
        deployLabel.position = CGPoint(
            x: deployIcon.position.x + deployIcon.size.width / 2
                + deploySpacing
                + deployLabel.frame.width / 2,
            y: deployCenterY
        )
        let dividerX = deployLabel.position.x + deployLabel.frame.width / 2
            + deploySpacing
            + deployDividerWidth / 2
        deployDivider.path = CGPath(
            rect: CGRect(
                x: -deployDividerWidth / 2,
                y: -11,
                width: deployDividerWidth,
                height: 22
            ),
            transform: nil
        )
        deployDivider.fillColor = SKColor(red: 1, green: 232 / 255, blue: 196 / 255, alpha: 0.65)
        deployDivider.strokeColor = .clear
        deployDivider.position = CGPoint(x: dividerX, y: deployCenterY)
        manualCountLabel.position = CGPoint(
            x: dividerX + deployDividerWidth / 2
                + deploySpacing
                + manualCountLabel.frame.width / 2,
            y: deployCenterY
        )
        for lane in BattleLane.allCases {
            let frame = layout.laneChipFrames[lane]!
            let chipFrame = CGRect(
                x: frame.midX - 35,
                y: frame.minY,
                width: 70,
                height: frame.height
            )
            let bundle = laneChips[lane]!
            let role = content.laneDefenseProfile.role(for: lane)
            let isSelected = lane == content.selectedLane
            let chipText: String?
            let chipColor: SKColor
            switch role {
            case .exposed:
                chipText = isSelected ? "ASSAULT" : "OPEN"
                chipColor = GameUITheme.Color.hpFill
                bundle.background.fillTexture = Self.openLaneTexture
            case .fortified:
                chipText = isSelected ? "ASSAULT" : "HELD"
                chipColor = GameUITheme.Color.danger
                bundle.background.fillTexture = Self.heldLaneTexture
            case .standard:
                chipText = isSelected ? "ASSAULT" : nil
                chipColor = GameUITheme.Color.textPrimary
                bundle.background.fillTexture = nil
            }
            bundle.background.path = CGPath(
                roundedRect: CGRect(
                    x: chipFrame.minX,
                    y: chipFrame.minY,
                    width: chipFrame.width,
                    height: chipFrame.height
                ),
                cornerWidth: 4,
                cornerHeight: 4,
                transform: nil
            )
            bundle.background.fillColor = chipText == nil
                ? .clear
                : (bundle.background.fillTexture == nil
                    ? GameUITheme.Color.panelFill.withAlphaComponent(0.92)
                    : .white)
            bundle.background.strokeColor = chipColor.withAlphaComponent(0.75)
            bundle.background.lineWidth = 1.5
            bundle.background.isHidden = chipText == nil
            bundle.shield.isHidden = isSelected || chipText == nil
            bundle.shield.strokeColor = chipColor
            bundle.shield.fillColor = role == .fortified
                ? chipColor.withAlphaComponent(0.9)
                : .clear
            bundle.shield.position = CGPoint(
                x: chipFrame.minX + 11,
                y: chipFrame.midY
            )
            bundle.flag.isHidden = !isSelected
            bundle.flag.strokeColor = chipColor
            bundle.flag.fillColor = chipColor.withAlphaComponent(0.9)
            bundle.flag.position = CGPoint(
                x: chipFrame.minX + 12,
                y: chipFrame.midY
            )
            bundle.label.text = chipText
            bundle.label.fontColor = chipColor
            bundle.label.position = CGPoint(
                x: isSelected ? chipFrame.midX + 6 : chipFrame.midX + 5,
                y: chipFrame.midY
            )
            bundle.label.isHidden = chipText == nil
        }
        applyCaptainStrip(content: content, layout: layout)
        tabBar.apply(
            content: content.tabContent,
            frame: layout.tabBarFrame,
            hitFrames: layout.tabHitFrames
        )

        deployHitFrame = deployDisplayFrame
        // Rally is actionable only in the Ready status — a Captain that is
        // recovering, mid-Rally, or spent keeps the strip informational so
        // a tap can never silently no-op (HPA-475).
        rallyHitTarget = content.captainStatus.isRallyActionable ? layout.rallyHitFrame : nil
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
        if rallyHitTarget?.contains(point) == true {
            return .rally
        }
        if let tab = tabBar.tab(at: point) {
            return .tab(tab)
        }
        for lane in BattleLane.allCases where layout.laneChipHitFrames[lane]?.contains(point) == true {
            return .selectLane(lane)
        }
        return nil
    }

    private func failApply() -> ApplyResult {
        isHidden = true
        currentLayout = nil
        currentContent = nil
        deployHitFrame = nil
        rallyHitTarget = nil
        return .requiredContentDoesNotFit
    }

    /// HPA-475 Captain strip: portrait/fallback + compact HP/recovery +
    /// Rally Ready/Active/Used, packed inside `captainStripFrame` only.
    private func applyCaptainStrip(content: BattleHUDContent, layout: BattleChromeLayout) {
        let stripFrame = layout.captainStripFrame
        guard content.captainStatus != .unavailable else {
            captainStripPanel.isHidden = true
            captainPortrait.isHidden = true
            captainStatusLabel.isHidden = true
            captainRallyLabel.isHidden = true
            return
        }

        captainStripPanel.isHidden = false
        captainPortrait.isHidden = false
        captainStatusLabel.isHidden = false
        captainRallyLabel.isHidden = false
        captainStripPanel.apply(
            size: stripFrame.size,
            style: .normal,
            showsRivets: false,
            appearance: .forged
        )
        captainStripPanel.position = CGPoint(x: stripFrame.midX, y: stripFrame.midY)
        captainPortrait.texture = Self.captainPortraitTexture()
        captainPortrait.size = CGSize(width: 36, height: 36)
        captainPortrait.position = CGPoint(x: stripFrame.minX + 24, y: stripFrame.midY)

        let hpText: String
        let rallyText: String
        let rallyColor: SKColor
        switch content.captainStatus {
        case .unavailable:
            return
        case .ready(let currentHP, let maxHP, let rallyReady):
            hpText = "\(currentHP)/\(maxHP)"
            // `rallyReady` is the hit target's predicate — a durable-alive
            // Captain with no live actor keeps the Rally read but cannot
            // fire yet, so it reads HELD rather than promising READY.
            rallyText = rallyReady ? "RALLY READY" : "RALLY HELD"
            rallyColor = rallyReady ? GameUITheme.Color.gold : GameUITheme.Color.textSecondary
        case .active(let currentHP, let maxHP):
            hpText = "\(currentHP)/\(maxHP)"
            rallyText = "RALLY ACTIVE"
            rallyColor = GameUITheme.Color.hpFill
        case .used(let currentHP, let maxHP):
            hpText = "\(currentHP)/\(maxHP)"
            rallyText = "RALLY USED"
            rallyColor = GameUITheme.Color.textSecondary
        case .recovering(let seconds, let rallyConsumed, let rallyActive):
            hpText = "BACK \(Int(seconds.rounded(.up)))s"
            if rallyActive {
                // A mid-Rally retreat leaves the timer protecting the
                // captured lane — the strip reads Active beside the
                // recovery countdown (HPA-475).
                rallyText = "RALLY ACTIVE"
                rallyColor = GameUITheme.Color.hpFill
            } else {
                // An unused Rally survives the retreat but cannot fire
                // until the Captain returns — HELD, not READY, since the
                // control is inert (HPA-475).
                rallyText = rallyConsumed ? "RALLY USED" : "RALLY HELD"
                rallyColor = GameUITheme.Color.textSecondary
            }
        }
        captainStatusLabel.text = hpText
        captainRallyLabel.text = rallyText
        captainRallyLabel.fontColor = rallyColor

        // The copy zone sits right of the portrait; fit both lines into it.
        let copyMinX = stripFrame.minX + 46
        let copyWidth = stripFrame.maxX - 6 - copyMinX
        captainStatusLabel.fontSize = SingleLineTextFitter.fittedFontSize(
            hpText,
            startingAt: 10,
            minimum: 7,
            maximumWidth: copyWidth,
            measure: Self.measureBoldTextWidth
        ) ?? 7
        captainRallyLabel.fontSize = SingleLineTextFitter.fittedFontSize(
            rallyText,
            startingAt: 10,
            minimum: 7,
            maximumWidth: copyWidth,
            measure: Self.measureBoldTextWidth
        ) ?? 7
        captainStatusLabel.position = CGPoint(x: copyMinX, y: stripFrame.midY + 9)
        captainRallyLabel.position = CGPoint(x: copyMinX, y: stripFrame.midY - 9)
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

    private static func makeLockPath() -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -3.5, y: -4))
        path.addLine(to: CGPoint(x: 3.5, y: -4))
        path.addLine(to: CGPoint(x: 3.5, y: 1))
        path.addLine(to: CGPoint(x: -3.5, y: 1))
        path.closeSubpath()
        path.move(to: CGPoint(x: -2.5, y: 1))
        path.addCurve(
            to: CGPoint(x: 2.5, y: 1),
            control1: CGPoint(x: -2.5, y: 4),
            control2: CGPoint(x: 2.5, y: 4)
        )
        return path
    }

    private static func makeShieldPath() -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 5))
        path.addLine(to: CGPoint(x: 4, y: 3))
        path.addLine(to: CGPoint(x: 4, y: -1))
        path.addCurve(
            to: CGPoint(x: 0, y: -5),
            control1: CGPoint(x: 4, y: -3),
            control2: CGPoint(x: 2.5, y: -4.5)
        )
        path.addCurve(
            to: CGPoint(x: -4, y: -1),
            control1: CGPoint(x: -2.5, y: -4.5),
            control2: CGPoint(x: -4, y: -3)
        )
        path.addLine(to: CGPoint(x: -4, y: 3))
        path.closeSubpath()
        return path
    }

    /// Procedural assault pennant: pole plus triangle flag.
    private static func makeFlagPath() -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: -6))
        path.addLine(to: CGPoint(x: 0, y: 6))
        path.move(to: CGPoint(x: 0, y: 6))
        path.addLine(to: CGPoint(x: 8, y: 3.5))
        path.addLine(to: CGPoint(x: 0, y: 1))
        path.closeSubpath()
        return path
    }

    private static func measureBoldTextWidth(_ text: String, fontSize: CGFloat) -> CGFloat {
        let font = UIFont(name: GameUITheme.Font.bold, size: fontSize)
            ?? UIFont.systemFont(ofSize: fontSize)
        return (text as NSString).size(withAttributes: [.font: font]).width
    }

    /// HPA-475 ships no generated images; probe the stable portrait name and
    /// fall back to an SF-symbol crown until HPA-476 installs the asset.
    private static func captainPortraitTexture() -> SKTexture? {
        if UIImage(named: "vanguard-captain-portrait") != nil {
            return SKTexture(imageNamed: "vanguard-captain-portrait")
        }
        return UIImage(systemName: "crown.fill").map(SKTexture.init(image:))
    }

    private static func objectiveText(
        for recommendation: RecommendedCampRecommendation
    ) -> String {
        switch recommendation {
        case .ready(let action, _), .saveFor(let action, _, _):
            return action.buildingType.shortDisplayName
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
            return SKTexture(imageNamed: assetName)
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

    private static let favorableMultiplierTexture = PanelNode.gradientTexture(
        top: SKColor(red: 95 / 255, green: 240 / 255, blue: 154 / 255, alpha: 1),
        bottom: SKColor(red: 18 / 255, green: 160 / 255, blue: 82 / 255, alpha: 1)
    )
    private static let disadvantagedMultiplierTexture = PanelNode.gradientTexture(
        top: SKColor(red: 255 / 255, green: 138 / 255, blue: 114 / 255, alpha: 1),
        bottom: SKColor(red: 192 / 255, green: 42 / 255, blue: 26 / 255, alpha: 1)
    )
    private static let openLaneTexture = PanelNode.gradientTexture(
        top: SKColor(red: 44 / 255, green: 58 / 255, blue: 34 / 255, alpha: 1),
        bottom: SKColor(red: 20 / 255, green: 26 / 255, blue: 16 / 255, alpha: 1)
    )
    private static let heldLaneTexture = PanelNode.gradientTexture(
        top: SKColor(red: 74 / 255, green: 31 / 255, blue: 20 / 255, alpha: 1),
        bottom: SKColor(red: 34 / 255, green: 14 / 255, blue: 8 / 255, alpha: 1)
    )
    private static let cachedGoldTexture = makeGoldTexture()

    private static func makeGoldTexture() -> SKTexture? {
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
