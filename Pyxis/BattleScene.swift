//
//  BattleScene.swift
//  Pyxis
//
//  Created by Chan Wai Chan on 5/5/2026.
//

import Foundation
import SpriteKit
import UIKit

protocol BattleSceneRouting: AnyObject {
    func battleSceneDidRequestCountryMap(_ scene: BattleScene)
    func battleSceneDidRequestBuildingView(_ scene: BattleScene)
}

final class BattleScene: SKScene {
    private enum BattleAssetName {
        static let playerCastle = "player-castle"
        static let enemyCity = "enemy-city"
        static let normalSoldier = "normal-soldier"
        static let archerSoldier = "archer-soldier"
        static let battlefieldBackdrop = "battlefield-backdrop"
        static let buildingPadEmpty = "building-pad-empty"
        static let countryMarker = "conquered-marker"
        static let hitFlash = "hit-flash"
        static let towerProjectile = "tower-projectile"
        static let goldBurst = "gold-burst"
    }

    private enum ButtonName {
        static let spawn = "spawnSoldierButton"
        static let manualType = "manualType"
        static let world = "worldButton"
        static let build = "buildButton"
        static let goldInfo = "goldInfoButton"
        static let cityInfo = "cityInfoButton"
        static let popupContinue = "conquestPopupContinueButton"
    }

    private enum EffectName {
        static let floatingFeedback = "floatingFeedback"
        static let goldBurst = "goldBurst"
    }

    private enum BattlefieldNodeName {
        static let cityHPBarBackground = "cityHPBarBackground"
        static let cityHPBarFill = "cityHPBarFill"
    }

    private enum EffectStyle {
        static let floatingFeedbackFontSize: CGFloat = 16
        static let floatingFeedbackZ: CGFloat = 55
        static let goldBurstZ = GameUITheme.Z.modal + 0.5
        static let goldBurstSparkleZ: CGFloat = 0
        static let goldBurstRemovalDelayNanoseconds: UInt64 = 650_000_000
        static let tooltipVisibleDuration: TimeInterval = 1.65
    }

    private enum SoldierAnimationKey {
        static let walk = "soldierWalkAnimation"
        static let attack = "soldierAttackAnimation"
        static let hit = "soldierHitAnimation"
        static let delayedRemoval = "soldierDelayedRemoval"
    }

    private struct SoldierNodeBundle {
        let root: SKNode
        let body: SKNode
        let hpBarBackground: SKShapeNode
        let hpBarFill: SKShapeNode
        let type: SoldierType
        let lane: BattleLane
        let formationSlot: Int
        /// `true` when `body` is an animation-canvas sprite whose texture is a
        /// 128px full-canvas animation frame and whose size is therefore owned
        /// by `SoldierAnimationGeometry`. `false` for the static fallback
        /// sprite (a standalone asset not authored against those normalized
        /// bounds), which must stay on the legacy `fitBattleNode` fit path.
        let isAnimatedCanvas: Bool
    }

    private enum SoldierFormation {
        static let columns = [0, -1, 1]
        static let lateralSpacingScale: CGFloat = 0.42
        static let rowSpacingScale: CGFloat = 0.30
    }

    private struct ManualTypeButtonBundle {
        let button: SKNode
        let background: SKShapeNode
        let icon: SKSpriteNode
        let label: SKLabelNode
    }

    private let store: KingdomGameStore
    private weak var router: BattleSceneRouting?
    private var state: KingdomGameState
    private var combat: BattleCombatState
    private var lastUpdateTime: TimeInterval?
    private var soldierNodes: [BattleCombatState.SoldierID: SoldierNodeBundle] = [:]
    private var didBuildInterface = false
    private var isObservingLifecycle = false
    private var selectedManualSoldierType: SoldierType = .infantry
    private var isManualTypeMenuOpen = false
    private var manualTypeMenuTopY: CGFloat = 0

    private let battlefieldLayer = SKNode()
    private let environmentLayer = SKNode()
    private let soldierLayer = SKNode()
    private let effectsLayer = SKNode()
    private var playerCastleNode: SKNode?
    private var enemyCityNode: SKNode?
    private var battlefieldBackdropNode: SKSpriteNode?
    private var battlefieldLayout = BattlefieldLayout(
        frame: .zero, structureHeight: 0,
        castleGatePoints: [:], enemyGatePoints: [:],
        isVisible: false, lanePathWidth: 14
    )
    private var laneNodes: [SKShapeNode] = []
    private var laneIndicatorNodes: [SKNode] = []
    private var pendingAnimatedRemovalSoldierIDs: Set<BattleCombatState.SoldierID> = []

    /// Memoized per-(type, action) animation textures. Each call to
    /// `soldierAnimationTextures` previously performed ~20 `UIImage(named:)`
    /// lookups plus fresh `SKTexture` allocations; this cache returns the same
    /// `SKTexture` instances across soldiers and across the scene's lifetime.
    /// Textures are keyed by static asset names, so they never need invalidation.
    private var soldierAnimationTextureCache: [SoldierType: [SoldierAnimationAction: [SKTexture]]] = [:]

    /// Memoized per-type HUD icon textures. `updateHUDIcons` runs on every
    /// combat-damage tick via `redraw` → `applyCombatResult`; without this cache
    /// it reallocated ~16 `SKTexture` objects per tick even though the resolved
    /// asset name is deterministic per `SoldierType`. Keyed by static asset
    /// names, so entries never need invalidation.
    private var soldierHUDIconTextureCache: [SoldierType: SKTexture] = [:]

    private var enemyCityImpactPoint: CGPoint {
        battlefieldLayout.enemyCityImpactPoint
    }

    private let goldLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let cityLevelLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let defenseTraitLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let cityHPLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let liveCombatStatusLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let feedbackLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let leftHUDPanel = PanelNode(size: CGSize(width: 160, height: 78))
    private let rightHUDPanel = PanelNode(size: CGSize(width: 190, height: 86))
    private let feedbackPanel = PanelNode(size: CGSize(width: 260, height: 34))
    private let cityHPBarBackground = SKShapeNode()
    private let cityHPBarFill = SKShapeNode()
    private let goldStatusIcon = SKSpriteNode(imageNamed: BattleAssetName.goldBurst)
    private let soldierStatusIcon = SKSpriteNode()
    private let cityStatusIcon = SKSpriteNode(imageNamed: BattleAssetName.enemyCity)
    private let traitStatusIcon = SKShapeNode()
    private let manualTypeButton = SKNode()
    private let manualTypeButtonBackground = SKShapeNode()
    private let manualTypeButtonIcon = SKSpriteNode()
    private let manualTypeButtonLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private var manualTypeButtonBundles: [SoldierType: ManualTypeButtonBundle] = [:]
    private let spawnButton = SKNode()
    private let spawnButtonBackground = SKShapeNode()
    private let spawnButtonIcon = SKSpriteNode()
    private let spawnButtonLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let worldButton = SKNode()
    private let worldButtonBackground = SKShapeNode()
    private let worldButtonIcon = SKSpriteNode(imageNamed: BattleAssetName.countryMarker)
    private let worldButtonLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let buildButton = SKNode()
    private let buildButtonBackground = SKShapeNode()
    private let buildButtonIcon = SKSpriteNode(imageNamed: BattleAssetName.buildingPadEmpty)
    private let buildButtonLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let popupOverlay = SKShapeNode()
    private let popupTitleLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let popupRewardLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let popupContinueButton = SKNode()
    private let popupContinueBackground = SKShapeNode()
    private let popupContinueLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private var isConquestPopupVisible = false
    private var isGoldBurstRemovalScheduled = false
    private var goldBurstRemovalTask: Task<Void, Never>?

    private var feedbackText = ""
    private var lastPresentedTooltipText = ""
    private var currentLeftHUDLabelWidth: CGFloat = 140
    /// Cached `LayoutMetrics.contentWidth` from the most recent layout pass.
    /// `showTooltip` reads this instead of recomputing the full metrics struct.
    /// Defaults to a sane positive floor so a tooltip fired before the first
    /// layout pass still gets a non-zero panel width.
    private var cachedContentWidth: CGFloat = 220
    #if DEBUG
    private var battlefieldLayoutCount = 0
    private var recentSoldierAttackAnimationCount = 0
    private var recentSoldierHitAnimationCount = 0
    /// Call counter for `layoutCityHPBar`, exposed via
    /// `layoutCityHPBarCallCountForTesting` so tests can verify `redraw` does
    /// not invoke it twice when `shouldLayout` is true (the layout pass in
    /// `layoutInterface` already runs it). DEBUG-only like the sibling layout
    /// counters above; release builds never read it.
    private var layoutCityHPBarCallCount = 0
    #endif
    private var buildingProgressSaveAccumulator: TimeInterval = 0
    private static let buildingProgressSaveInterval: TimeInterval = 2.0
    private let combatSeed: UInt64?

    init(
        size: CGSize,
        store: KingdomGameStore = .shared,
        router: BattleSceneRouting? = nil,
        combatSeed: UInt64? = nil
    ) {
        let loadedState = store.load()
        self.store = store
        self.state = loadedState
        self.combatSeed = combatSeed
        self.combat = Self.makeCombat(for: loadedState, seed: combatSeed)
        self.router = router
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        let loadedState = KingdomGameStore.shared.load()
        self.store = .shared
        self.state = loadedState
        self.combatSeed = nil
        self.combat = Self.makeCombat(for: loadedState, seed: nil)
        self.router = nil
        super.init(coder: aDecoder)
    }

    private static func makeCombat(for state: KingdomGameState, seed: UInt64?) -> BattleCombatState {
        let configuration = BattleCombatState.Configuration.live(
            cityLevel: state.cityLevel,
            laneDamageMultipliers: state.currentCityLaneDefenseProfile.towerDamageMultipliers
        )
        if let seed {
            return BattleCombatState(configuration: configuration, seed: seed)
        }
        return BattleCombatState(configuration: configuration)
    }

    deinit {
        goldBurstRemovalTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.07, green: 0.10, blue: 0.13, alpha: 1.0)

        if !didBuildInterface {
            buildInterface()
            didBuildInterface = true
        }

        observeLifecycleNotificationsIfNeeded()
        redraw()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutInterface()
    }

    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)

        defer {
            lastUpdateTime = currentTime
        }

        guard let lastUpdateTime else {
            return
        }

        guard state.stageStatus == .battleActive, !isConquestPopupVisible else {
            return
        }

        advanceCombat(deltaTime: currentTime - lastUpdateTime)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else {
            return
        }

        handleTouch(named: buttonName(at: touch.location(in: self)))
    }

    private func handleTouch(named touchedButtonName: String?) {
        guard let touchedButtonName else {
            hideManualTypeMenuIfOpen()
            return
        }

        if let soldierType = soldierType(forManualTypeButtonName: touchedButtonName) {
            selectManualSoldierType(soldierType)
            return
        }

        guard !handlePrimaryButton(named: touchedButtonName),
              !handleInfoButton(named: touchedButtonName) else {
            return
        }

        hideManualTypeMenuIfOpen()
    }

    private func handlePrimaryButton(named touchedButtonName: String) -> Bool {
        switch touchedButtonName {
        case ButtonName.manualType:
            toggleManualTypeMenu()
        case ButtonName.spawn:
            hideManualTypeMenuWithoutLayoutIfNeeded()
            spawnSoldier()
        case ButtonName.world:
            hideManualTypeMenuWithoutLayoutIfNeeded()
            requestCountryMap()
        case ButtonName.build:
            hideManualTypeMenuWithoutLayoutIfNeeded()
            requestBuildingView()
        case ButtonName.popupContinue:
            hideManualTypeMenuWithoutLayoutIfNeeded()
            closeConquestPopup()
        default:
            return false
        }

        return true
    }

    private func handleInfoButton(named touchedButtonName: String) -> Bool {
        // Info tooltips must not fire while the conquest popup is overlaying
        // the HUD — otherwise the tooltip renders behind the popup overlay.
        guard !isConquestPopupVisible else {
            return false
        }
        switch touchedButtonName {
        case ButtonName.goldInfo:
            hideManualTypeMenuWithoutLayoutIfNeeded()
            showGoldInfoTooltip()
        case ButtonName.cityInfo:
            hideManualTypeMenuWithoutLayoutIfNeeded()
            showCityInfoTooltip()
        default:
            return false
        }

        return true
    }

    private func hideManualTypeMenuIfOpen() {
        if isManualTypeMenuOpen {
            hideManualTypeMenuWithoutLayoutIfNeeded()
        }
    }

    private func buildInterface() {
        battlefieldLayer.zPosition = 0
        environmentLayer.zPosition = 10
        soldierLayer.zPosition = 20
        effectsLayer.zPosition = 30

        addChild(battlefieldLayer)
        battlefieldLayer.addChild(environmentLayer)
        battlefieldLayer.addChild(soldierLayer)
        battlefieldLayer.addChild(effectsLayer)

        buildBattlefield()

        [leftHUDPanel, rightHUDPanel].forEach { $0.zPosition = GameUITheme.Z.hud }
        feedbackPanel.zPosition = GameUITheme.Z.hud - 1
        leftHUDPanel.name = ButtonName.goldInfo
        rightHUDPanel.name = ButtonName.cityInfo
        addChild(leftHUDPanel)
        addChild(rightHUDPanel)
        addChild(feedbackPanel)

        configureHUDIcon(goldStatusIcon, name: ButtonName.goldInfo)
        configureHUDIcon(soldierStatusIcon, name: ButtonName.goldInfo)
        configureHUDIcon(cityStatusIcon, name: ButtonName.cityInfo)
        configureTraitIcon()
        traitStatusIcon.name = ButtonName.cityInfo
        traitStatusIcon.zPosition = 2
        leftHUDPanel.addChild(goldStatusIcon)
        leftHUDPanel.addChild(soldierStatusIcon)
        rightHUDPanel.addChild(cityStatusIcon)
        rightHUDPanel.addChild(traitStatusIcon)

        configureLabel(goldLabel, fontSize: 21, color: GameUITheme.Color.gold)
        configureLabel(cityLevelLabel, fontSize: 18, color: GameUITheme.Color.textPrimary)
        configureLabel(defenseTraitLabel, fontSize: 13, color: GameUITheme.Color.textSecondary)
        configureLabel(cityHPLabel, fontSize: 14, color: GameUITheme.Color.textPrimary)
        configureLabel(liveCombatStatusLabel, fontSize: 18, color: GameUITheme.Color.textPrimary)
        configureLabel(feedbackLabel, fontSize: 15, color: GameUITheme.Color.gold)

        configureButton(
            manualTypeButton,
            background: manualTypeButtonBackground,
            label: manualTypeButtonLabel,
            name: ButtonName.manualType,
            icon: manualTypeButtonIcon,
            color: SKColor(red: 0.24, green: 0.33, blue: 0.38, alpha: 1.0)
        )
        for soldierType in SoldierType.allCases {
            let bundle = ManualTypeButtonBundle(
                button: SKNode(),
                background: SKShapeNode(),
                icon: SKSpriteNode(),
                label: SKLabelNode(fontNamed: "AvenirNext-DemiBold")
            )
            configureButton(
                bundle.button,
                background: bundle.background,
                label: bundle.label,
                name: manualTypeButtonName(for: soldierType),
                icon: bundle.icon,
                color: SKColor(red: 0.18, green: 0.34, blue: 0.42, alpha: 1.0)
            )
            bundle.button.zPosition = GameUITheme.Z.hud + 1
            bundle.button.isHidden = true
            manualTypeButtonBundles[soldierType] = bundle
        }
        configureButton(
            spawnButton,
            background: spawnButtonBackground,
            label: spawnButtonLabel,
            name: ButtonName.spawn,
            icon: spawnButtonIcon,
            color: GameUITheme.Color.spawn
        )
        configureButton(
            worldButton,
            background: worldButtonBackground,
            label: worldButtonLabel,
            name: ButtonName.world,
            icon: worldButtonIcon,
            color: SKColor(red: 0.22, green: 0.42, blue: 0.54, alpha: 1.0)
        )
        configureButton(
            buildButton,
            background: buildButtonBackground,
            label: buildButtonLabel,
            name: ButtonName.build,
            icon: buildButtonIcon,
            color: SKColor(red: 0.50, green: 0.28, blue: 0.18, alpha: 1.0)
        )
        popupOverlay.fillColor = SKColor(white: 0.02, alpha: 0.86)
        popupOverlay.strokeColor = SKColor(white: 1.0, alpha: 0.24)
        popupOverlay.lineWidth = 2
        popupOverlay.zPosition = 200
        popupOverlay.isHidden = true

        configureLabel(popupTitleLabel, fontSize: 22, color: .white)
        configureLabel(popupRewardLabel, fontSize: 18, color: SKColor(red: 1.0, green: 0.84, blue: 0.25, alpha: 1.0))
        configureButton(
            popupContinueButton,
            background: popupContinueBackground,
            label: popupContinueLabel,
            name: ButtonName.popupContinue,
            color: SKColor(red: 0.18, green: 0.58, blue: 0.42, alpha: 1.0)
        )

        popupTitleLabel.zPosition = 201
        popupRewardLabel.zPosition = 201
        popupContinueButton.zPosition = 201

        [
            goldLabel,
            cityLevelLabel,
            defenseTraitLabel,
            cityHPLabel,
            liveCombatStatusLabel,
            feedbackLabel,
            manualTypeButton,
            spawnButton,
            worldButton,
            buildButton
        ].forEach { $0.zPosition = GameUITheme.Z.hud }

        addChild(goldLabel)
        addChild(cityLevelLabel)
        addChild(defenseTraitLabel)
        addChild(cityHPLabel)
        addChild(liveCombatStatusLabel)
        addChild(feedbackLabel)
        addChild(manualTypeButton)
        for bundle in manualTypeButtonBundles.values {
            addChild(bundle.button)
        }
        addChild(spawnButton)
        addChild(worldButton)
        addChild(buildButton)
        addChild(popupOverlay)
        addChild(popupTitleLabel)
        addChild(popupRewardLabel)
        addChild(popupContinueButton)

        applyPersistentHUDTextVisibility()
        feedbackPanel.alpha = 0
        feedbackLabel.alpha = 0
        setConquestPopupHidden(true)
    }

    private func configureHUDIcon(_ icon: SKSpriteNode, name: String) {
        icon.name = name
        icon.zPosition = 2
        icon.alpha = 0.95
    }

    private func configureTraitIcon() {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 14))
        path.addLine(to: CGPoint(x: 12, y: 8))
        path.addLine(to: CGPoint(x: 11, y: -4))
        path.addCurve(
            to: CGPoint(x: 0, y: -16),
            control1: CGPoint(x: 10, y: -10),
            control2: CGPoint(x: 5, y: -15)
        )
        path.addCurve(
            to: CGPoint(x: -11, y: -4),
            control1: CGPoint(x: -5, y: -15),
            control2: CGPoint(x: -10, y: -10)
        )
        path.addLine(to: CGPoint(x: -12, y: 8))
        path.closeSubpath()

        traitStatusIcon.path = path
        traitStatusIcon.fillColor = GameUITheme.Color.danger
        traitStatusIcon.strokeColor = SKColor(white: 1.0, alpha: 0.55)
        traitStatusIcon.lineWidth = 1.5
    }

    private func applyPersistentHUDTextVisibility() {
        [goldLabel, cityLevelLabel, liveCombatStatusLabel, manualTypeButtonLabel, spawnButtonLabel]
            .forEach { $0.alpha = 1 }
        cityHPLabel.alpha = 0
        [defenseTraitLabel, worldButtonLabel, buildButtonLabel].forEach { $0.alpha = 0 }

        for bundle in manualTypeButtonBundles.values {
            bundle.label.alpha = 1
        }
    }

    private func configureLabel(_ label: SKLabelNode, fontSize: CGFloat, color: SKColor) {
        label.fontSize = fontSize
        label.fontColor = color
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
    }

    private func configureButton(
        _ button: SKNode,
        background: SKShapeNode,
        label: SKLabelNode,
        name: String,
        icon: SKSpriteNode? = nil,
        color: SKColor
    ) {
        button.name = name
        background.name = name
        background.fillColor = color
        background.strokeColor = SKColor(white: 1.0, alpha: 0.18)
        background.lineWidth = 2

        label.name = name
        label.fontSize = 16
        label.fontColor = GameUITheme.Color.textPrimary
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center

        button.addChild(background)
        if let icon {
            icon.name = name
            icon.zPosition = 1
            button.addChild(icon)
        }
        button.addChild(label)
    }

    private func layoutInterface() {
        guard didBuildInterface else {
            return
        }

        resetFontSizes()
        let metrics = layoutMetrics()

        let centerX = size.width / 2

        let hudCenterY = size.height - metrics.topMargin
        let leftHUDCenterX = metrics.horizontalMargin + metrics.leftHUDWidth / 2
        let rightHUDCenterX = size.width - metrics.horizontalMargin - metrics.rightHUDWidth / 2

        leftHUDPanel.update(size: CGSize(width: metrics.leftHUDWidth, height: metrics.hudHeight))
        rightHUDPanel.update(size: CGSize(width: metrics.rightHUDWidth, height: metrics.hudHeight))
        leftHUDPanel.position = CGPoint(x: leftHUDCenterX, y: hudCenterY)
        rightHUDPanel.position = CGPoint(x: rightHUDCenterX, y: hudCenterY)
        layoutStatusIcons(metrics)

        goldLabel.horizontalAlignmentMode = .left
        liveCombatStatusLabel.horizontalAlignmentMode = .left
        cityLevelLabel.horizontalAlignmentMode = .left
        cityHPLabel.horizontalAlignmentMode = .left
        let resourceValueX = leftHUDCenterX - metrics.leftHUDWidth * 0.10
        goldLabel.position = CGPoint(
            x: resourceValueX,
            y: hudCenterY + metrics.hudHeight * 0.20
        )
        liveCombatStatusLabel.position = CGPoint(
            x: resourceValueX,
            y: hudCenterY - metrics.hudHeight * 0.20
        )

        cityLevelLabel.position = CGPoint(
            x: rightHUDCenterX - metrics.rightHUDWidth * 0.24,
            y: hudCenterY + metrics.hudHeight * 0.22
        )
        defenseTraitLabel.position = CGPoint(x: rightHUDCenterX, y: hudCenterY + metrics.hudHeight * 0.06)
        cityHPLabel.position = CGPoint(
            x: rightHUDCenterX - metrics.rightHUDWidth * 0.24,
            y: hudCenterY - metrics.hudHeight * 0.18
        )

        let buttonY = metrics.bottomMargin + metrics.buttonHeight / 2
        let primaryActionLeftX = metrics.horizontalMargin
        layoutButton(
            spawnButton,
            background: spawnButtonBackground,
            size: CGSize(width: metrics.spawnButtonWidth, height: metrics.buttonHeight),
            position: CGPoint(x: primaryActionLeftX + metrics.spawnButtonWidth / 2, y: buttonY)
        )
        layoutIcon(
            spawnButtonIcon,
            maximumSize: CGSize(width: metrics.spawnButtonWidth * 0.30, height: metrics.buttonHeight - 2)
        )
        spawnButtonIcon.position = CGPoint(x: -metrics.spawnButtonWidth * 0.24, y: 0)
        spawnButtonLabel.position = CGPoint(x: metrics.spawnButtonWidth * 0.12, y: 0)
        let manualTypeButtonSize = CGSize(
            width: min(metrics.spawnButtonWidth, 112),
            height: metrics.compactHeight ? 28 : 30
        )
        let manualTypeButtonPosition = CGPoint(
            x: primaryActionLeftX + manualTypeButtonSize.width / 2,
            y: buttonY + metrics.buttonHeight / 2 + 4 + manualTypeButtonSize.height / 2
        )
        layoutButton(
            manualTypeButton,
            background: manualTypeButtonBackground,
            size: manualTypeButtonSize,
            position: manualTypeButtonPosition
        )
        layoutIcon(
            manualTypeButtonIcon,
            maximumSize: CGSize(width: manualTypeButtonSize.width * 0.32, height: manualTypeButtonSize.height - 2)
        )
        manualTypeButtonIcon.position = CGPoint(x: -manualTypeButtonSize.width * 0.28, y: 0)
        manualTypeButtonLabel.position = CGPoint(x: manualTypeButtonSize.width * 0.12, y: 0)
        let rightActionReservation = metrics.buildButtonWidth + metrics.buttonGap
        let manualTypeMenuItemSize = self.manualTypeMenuItemSize(
            horizontalMargin: metrics.horizontalMargin,
            reservedRightWidth: rightActionReservation
        )
        layoutManualTypeMenu(
            selectorPosition: manualTypeButtonPosition,
            selectorSize: manualTypeButtonSize,
            itemSize: manualTypeMenuItemSize,
            horizontalMargin: metrics.horizontalMargin,
            reservedRightWidth: rightActionReservation
        )
        layoutButton(
            buildButton,
            background: buildButtonBackground,
            size: CGSize(width: metrics.buildButtonWidth, height: metrics.buttonHeight),
            position: CGPoint(
                x: size.width - metrics.horizontalMargin - metrics.buildButtonWidth / 2,
                y: buttonY
            )
        )
        layoutIcon(
            buildButtonIcon,
            maximumSize: CGSize(width: metrics.buildButtonWidth - 8, height: metrics.buttonHeight - 8)
        )
        let worldButtonSize = CGSize(width: metrics.worldButtonWidth, height: metrics.buttonHeight)
        layoutButton(
            worldButton,
            background: worldButtonBackground,
            size: worldButtonSize,
            position: CGPoint(
                x: buildButton.position.x,
                y: buttonY + metrics.buttonHeight / 2 + 4 + worldButtonSize.height / 2
            )
        )
        layoutIcon(
            worldButtonIcon,
            maximumSize: CGSize(width: worldButtonSize.width - 8, height: worldButtonSize.height - 8)
        )

        let hudBottomY = hudCenterY - metrics.hudHeight / 2
        let buttonTopY = buttonY + metrics.buttonHeight / 2
        let bottomControlsTopY = max(
            buttonTopY,
            manualTypeButtonPosition.y + manualTypeButtonSize.height / 2,
            manualTypeMenuTopY,
            worldButton.position.y + worldButtonSize.height / 2
        )
        let feedbackY = bottomControlsTopY + max(32, (hudBottomY - bottomControlsTopY) * 0.25)
        feedbackLabel.position = CGPoint(x: centerX, y: feedbackY)

        layoutConquestPopup(contentWidth: metrics.contentWidth)

        layoutBattlefield(
            contentWidth: metrics.battlefieldWidth,
            hpBarBottomY: hudBottomY,
            spawnButtonTopY: bottomControlsTopY,
            feedbackY: feedbackY
        )

        currentLeftHUDLabelWidth = metrics.leftHUDLabelWidth
        cachedContentWidth = metrics.contentWidth
        fitLabel(goldLabel, maxWidth: metrics.leftHUDWidth * 0.58)
        fitLabel(cityLevelLabel, maxWidth: metrics.rightHUDLabelWidth - 44)
        fitLabel(defenseTraitLabel, maxWidth: metrics.rightHUDLabelWidth)
        fitLabel(cityHPLabel, maxWidth: metrics.rightHUDLabelWidth - 44)
        fitLabel(liveCombatStatusLabel, maxWidth: metrics.leftHUDLabelWidth)
        fitLabel(feedbackLabel, maxWidth: metrics.contentWidth)
        fitLabel(manualTypeButtonLabel, maxWidth: manualTypeButtonSize.width - 18)
        for bundle in manualTypeButtonBundles.values {
            fitLabel(bundle.label, maxWidth: manualTypeMenuItemSize.width - 18)
        }
        fitLabel(spawnButtonLabel, maxWidth: metrics.spawnButtonWidth - 28)
        fitLabel(worldButtonLabel, maxWidth: metrics.worldButtonWidth - 20)
        fitLabel(buildButtonLabel, maxWidth: metrics.buildButtonWidth - 24)
        fitLabel(popupTitleLabel, maxWidth: metrics.contentWidth - 48)
        fitLabel(popupRewardLabel, maxWidth: metrics.contentWidth - 48)
        fitLabel(popupContinueLabel, maxWidth: metrics.contentWidth - 76)

        let feedbackPanelWidth = min(metrics.contentWidth, max(220, feedbackLabel.frame.width + 32))
        feedbackPanel.update(size: CGSize(width: feedbackPanelWidth, height: max(32, feedbackLabel.fontSize + 18)))
        feedbackPanel.position = feedbackLabel.position
    }

    private func resetFontSizes() {
        goldLabel.fontSize = 21
        cityLevelLabel.fontSize = 18
        defenseTraitLabel.fontSize = 13
        cityHPLabel.fontSize = 14
        liveCombatStatusLabel.fontSize = 18
        feedbackLabel.fontSize = 15
        manualTypeButtonLabel.fontSize = 13
        for bundle in manualTypeButtonBundles.values {
            bundle.label.fontSize = 13
        }
        spawnButtonLabel.fontSize = 16
        worldButtonLabel.fontSize = 16
        buildButtonLabel.fontSize = 16
        popupTitleLabel.fontSize = 22
        popupRewardLabel.fontSize = 18
        popupContinueLabel.fontSize = 16
    }

    private struct LayoutMetrics {
        let compactHeight: Bool
        let horizontalMargin: CGFloat
        let topMargin: CGFloat
        let buttonHeight: CGFloat
        let bottomMargin: CGFloat
        let leftHUDWidth: CGFloat
        let rightHUDWidth: CGFloat
        let hudHeight: CGFloat
        let spawnButtonWidth: CGFloat
        let worldButtonWidth: CGFloat
        let buildButtonWidth: CGFloat
        let contentWidth: CGFloat
        let buttonGap: CGFloat
        let battlefieldWidth: CGFloat

        var leftHUDLabelWidth: CGFloat {
            leftHUDWidth - 20
        }

        var rightHUDLabelWidth: CGFloat {
            rightHUDWidth - 20
        }
    }

    private func layoutMetrics() -> LayoutMetrics {
        let compactHeight = size.height < 500
        let horizontalMargin = max(8, min(compactHeight ? 16 : 18, size.width * 0.045))
        let buttonHeight: CGFloat = compactHeight ? 42 : 52
        let buttonGap: CGFloat = compactHeight ? 10 : 12
        let safeBottomInset = GameUITheme.bottomUnsafeInset(sceneSize: size, view: view)
        let bottomMargin = max(compactHeight ? 20 : 30, safeBottomInset + (compactHeight ? 8 : 12))

        let hudGap: CGFloat = compactHeight ? 10 : 12
        let availableHUDWidth = max(0, size.width - horizontalMargin * 2 - hudGap)
        let preferredLeftHUDWidth = min(180, availableHUDWidth * 0.44)
        let leftHUDWidth = max(0, preferredLeftHUDWidth)
        let rightHUDWidth = max(0, availableHUDWidth - leftHUDWidth)
        let hudHeight: CGFloat = compactHeight ? 58 : 66
        let safeTopInset = GameUITheme.topUnsafeInset(sceneSize: size, view: view)
        let topMargin = max(
            compactHeight ? 24 : 34,
            safeTopInset + (compactHeight ? 6 : 10) + hudHeight / 2
        )

        let availableButtonWidth = max(0, size.width - horizontalMargin * 2 - buttonGap)
        let buildButtonWidth = min(buttonHeight * 1.05, availableButtonWidth * 0.24)
        let worldButtonWidth = buildButtonWidth
        let spawnButtonWidth = max(0, min(156, availableButtonWidth - buildButtonWidth))
        let contentWidth = min(max(0, size.width - horizontalMargin * 2), 560)
        let battlefieldWidth = max(0, size.width)

        return LayoutMetrics(
            compactHeight: compactHeight,
            horizontalMargin: horizontalMargin,
            topMargin: topMargin,
            buttonHeight: buttonHeight,
            bottomMargin: bottomMargin,
            leftHUDWidth: leftHUDWidth,
            rightHUDWidth: rightHUDWidth,
            hudHeight: hudHeight,
            spawnButtonWidth: spawnButtonWidth,
            worldButtonWidth: worldButtonWidth,
            buildButtonWidth: buildButtonWidth,
            contentWidth: contentWidth,
            buttonGap: buttonGap,
            battlefieldWidth: battlefieldWidth
        )
    }

    private func layoutButton(_ button: SKNode, background: SKShapeNode, size: CGSize, position: CGPoint) {
        background.path = CGPath(
            roundedRect: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height),
            cornerWidth: 10,
            cornerHeight: 10,
            transform: nil
        )
        button.position = position
    }

    private func layoutStatusIcons(_ metrics: LayoutMetrics) {
        let resourceIconSize = metrics.compactHeight
            ? CGSize(width: 30, height: 30)
            : CGSize(width: 36, height: 36)
        let cityIconSize = metrics.compactHeight ? CGSize(width: 28, height: 28) : CGSize(width: 36, height: 36)
        layoutIcon(goldStatusIcon, maximumSize: resourceIconSize)
        layoutIcon(soldierStatusIcon, maximumSize: resourceIconSize)
        layoutIcon(cityStatusIcon, maximumSize: cityIconSize)

        goldStatusIcon.position = CGPoint(x: -metrics.leftHUDWidth * 0.36, y: metrics.hudHeight * 0.20)
        soldierStatusIcon.position = CGPoint(x: -metrics.leftHUDWidth * 0.36, y: -metrics.hudHeight * 0.20)
        cityStatusIcon.position = CGPoint(x: -metrics.rightHUDWidth * 0.42, y: metrics.hudHeight * 0.12)

        let traitScale = (metrics.compactHeight ? 0.78 : 0.92)
        traitStatusIcon.setScale(traitScale)
        traitStatusIcon.position = CGPoint(x: -metrics.rightHUDWidth * 0.42, y: -metrics.hudHeight * 0.18)
    }

    private func layoutIcon(_ icon: SKSpriteNode, maximumSize: CGSize) {
        guard maximumSize.width > 0, maximumSize.height > 0 else {
            icon.size = .zero
            return
        }

        icon.size = aspectFitSize(for: icon.texture, maximumSize: maximumSize)
        icon.position = .zero
    }

    private func aspectFitSize(for texture: SKTexture?, maximumSize: CGSize) -> CGSize {
        guard let texture else {
            return maximumSize
        }

        let textureSize = texture.size()
        guard textureSize.width > 0, textureSize.height > 0 else {
            return maximumSize
        }

        let scale = min(maximumSize.width / textureSize.width, maximumSize.height / textureSize.height)
        return CGSize(width: textureSize.width * scale, height: textureSize.height * scale)
    }

    private func manualTypeMenuItemSize(horizontalMargin: CGFloat, reservedRightWidth: CGFloat) -> CGSize {
        let itemGap: CGFloat = 4
        let minimumItemWidth: CGFloat = 52
        let maximumItemWidth: CGFloat = 88
        let itemCount = max(1, manualSpawnableSoldierTypes.count)
        let availableWidth = max(1, size.width - horizontalMargin * 2 - reservedRightWidth)
        let columnCount = max(
            1,
            min(itemCount, Int((availableWidth + itemGap) / (minimumItemWidth + itemGap)))
        )
        let fittedWidth = (availableWidth - itemGap * CGFloat(columnCount - 1)) / CGFloat(columnCount)
        let itemWidth = max(minimumItemWidth, min(maximumItemWidth, fittedWidth))

        return CGSize(width: itemWidth, height: manualSpawnableSoldierTypes.count > 0 ? 30 : 1)
    }

    private func layoutManualTypeMenu(
        selectorPosition: CGPoint,
        selectorSize: CGSize,
        itemSize: CGSize,
        horizontalMargin: CGFloat,
        reservedRightWidth: CGFloat
    ) {
        let itemGap: CGFloat = 4
        let visibleTypes = manualSpawnableSoldierTypes
        manualTypeMenuTopY = selectorPosition.y + selectorSize.height / 2
        guard !visibleTypes.isEmpty else {
            return
        }

        let availableWidth = max(1, size.width - horizontalMargin * 2 - reservedRightWidth)
        let columnCount = max(
            1,
            min(visibleTypes.count, Int((availableWidth + itemGap) / (itemSize.width + itemGap)))
        )
        let rowStartY = selectorPosition.y + selectorSize.height / 2 + itemGap + itemSize.height / 2
        let rowWidth = itemSize.width * CGFloat(columnCount) + itemGap * CGFloat(max(0, columnCount - 1))
        let firstX = horizontalMargin + (availableWidth - rowWidth) / 2 + itemSize.width / 2
        let rowCount = (visibleTypes.count + columnCount - 1) / columnCount
        manualTypeMenuTopY = rowStartY
            + CGFloat(max(0, rowCount - 1)) * (itemSize.height + itemGap)
            + itemSize.height / 2

        for (index, soldierType) in visibleTypes.enumerated() {
            guard let bundle = manualTypeButtonBundles[soldierType] else {
                continue
            }

            let column = index % columnCount
            let row = index / columnCount
            layoutButton(
                bundle.button,
                background: bundle.background,
                size: itemSize,
                position: CGPoint(
                    x: firstX + CGFloat(column) * (itemSize.width + itemGap),
                    y: rowStartY + CGFloat(row) * (itemSize.height + itemGap)
                )
            )
            layoutIcon(
                bundle.icon,
                maximumSize: CGSize(width: itemSize.width * 0.32, height: itemSize.height - 2)
            )
            bundle.icon.position = CGPoint(x: -itemSize.width * 0.28, y: 0)
            bundle.label.position = CGPoint(x: itemSize.width * 0.12, y: 0)
        }
    }

    private func buildBattlefield() {
        if UIImage(named: BattleAssetName.battlefieldBackdrop) != nil {
            let backdrop = SKSpriteNode(imageNamed: BattleAssetName.battlefieldBackdrop)
            backdrop.name = BattleAssetName.battlefieldBackdrop
            backdrop.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            backdrop.zPosition = GameUITheme.Z.background
            environmentLayer.addChild(backdrop)
            battlefieldBackdropNode = backdrop
        }

        let castleNode = makeBattleSprite(
            named: BattleAssetName.playerCastle,
            fallbackColor: SKColor(red: 0.22, green: 0.40, blue: 0.64, alpha: 1.0)
        )
        let cityNode = makeBattleSprite(
            named: BattleAssetName.enemyCity,
            fallbackColor: SKColor(red: 0.58, green: 0.28, blue: 0.26, alpha: 1.0)
        )

        castleNode.name = BattleAssetName.playerCastle
        cityNode.name = BattleAssetName.enemyCity
        playerCastleNode = castleNode
        enemyCityNode = cityNode
        environmentLayer.addChild(castleNode)
        environmentLayer.addChild(cityNode)
        configureCityHPBar()
        environmentLayer.addChild(cityHPBarBackground)
        environmentLayer.addChild(cityHPBarFill)
    }

    private func configureCityHPBar() {
        cityHPBarBackground.name = BattlefieldNodeName.cityHPBarBackground
        cityHPBarBackground.fillColor = SKColor(white: 0.05, alpha: 0.9)
        cityHPBarBackground.strokeColor = SKColor(white: 1.0, alpha: 0.3)
        cityHPBarBackground.lineWidth = 1
        cityHPBarBackground.zPosition = 4

        cityHPBarFill.name = BattlefieldNodeName.cityHPBarFill
        cityHPBarFill.fillColor = SKColor(red: 0.25, green: 0.9, blue: 0.38, alpha: 1.0)
        cityHPBarFill.strokeColor = .clear
        cityHPBarFill.zPosition = 5
    }

    private func makeBattleSprite(named assetName: String, fallbackColor: SKColor) -> SKNode {
        if UIImage(named: assetName) != nil {
            let sprite = SKSpriteNode(imageNamed: assetName)
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
            return sprite
        }

        let node = SKShapeNode(rect: CGRect(x: -48, y: 0, width: 96, height: 92), cornerRadius: 8)
        node.fillColor = fallbackColor
        node.strokeColor = SKColor(white: 1.0, alpha: 0.22)
        node.lineWidth = 2
        return node
    }

    private func layoutBattlefield(
        contentWidth: CGFloat,
        hpBarBottomY: CGFloat,
        spawnButtonTopY: CGFloat,
        feedbackY: CGFloat
    ) {
        #if DEBUG
        battlefieldLayoutCount += 1
        #endif

        battlefieldLayout = BattlefieldLayout.compute(constraints: .init(
            sceneSize: size,
            contentWidth: contentWidth,
            safeTopY: hpBarBottomY - 8,
            safeBottomY: spawnButtonTopY + 2,
            feedbackY: feedbackY,
            feedbackFontSize: 0
        ))

        if !isConquestPopupVisible {
            cancelCityFeedbackActions()
        }

        if !battlefieldLayout.isVisible {
            setBattlefieldHidden(true)
            removeLaneNodes()
            removeLaneIndicatorNodes()
            return
        }

        setBattlefieldHidden(false)

        if let battlefieldBackdropNode {
            battlefieldBackdropNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
            battlefieldBackdropNode.setScale(1)
            let scale = max(
                size.width / max(1, battlefieldBackdropNode.size.width),
                size.height / max(1, battlefieldBackdropNode.size.height)
            )
            battlefieldBackdropNode.setScale(scale)
        }

        if let playerCastleNode {
            fitBattleNode(playerCastleNode, targetHeight: battlefieldLayout.structureHeight)
        }
        if let enemyCityNode {
            fitBattleNode(enemyCityNode, targetHeight: battlefieldLayout.enemyCityTargetHeight)
        }

        let centerX = size.width / 2
        playerCastleNode?.position = CGPoint(x: centerX, y: battlefieldLayout.frame.minY)
        // The city sprite uses a bottom anchor; the layout's enemy gate is the
        // city base after reserving room for the HP bar above the body.
        enemyCityNode?.position = CGPoint(
            x: centerX,
            y: battlefieldLayout.enemyGatePoints[.center]?.y ?? (
                battlefieldLayout.frame.maxY
                    - BattlefieldLayout.enemyCityHPBarClearance
                    - battlefieldLayout.enemyCityTargetHeight
            )
        )

        layoutCityHPBar()
        drawLanePaths()
        layoutLaneIndicators()
        syncSoldierNodes()
    }

    private func layoutCityHPBar() {
        #if DEBUG
        layoutCityHPBarCallCount &+= 1
        #endif
        guard battlefieldLayout.isVisible, let enemyCityNode else {
            cityHPBarBackground.path = nil
            cityHPBarFill.path = nil
            return
        }

        let cityFrame = enemyCityNode.calculateAccumulatedFrame()
        guard cityFrame.width > 0, cityFrame.height > 0 else {
            cityHPBarBackground.path = nil
            cityHPBarFill.path = nil
            return
        }

        let width = max(96, min(180, cityFrame.width * 0.72))
        let height: CGFloat = 7
        let topLimitY = battlefieldLayout.frame.maxY - height - 2
        let y = min(topLimitY, cityFrame.maxY + 4)
        let percent = min(max(CGFloat(state.cityRemainingPower) / CGFloat(max(1, state.cityMaxPower)), 0), 1)
        let backgroundRect = CGRect(
            x: cityFrame.midX - width / 2,
            y: y,
            width: width,
            height: height
        )
        let fillRect = CGRect(
            x: backgroundRect.minX,
            y: backgroundRect.minY,
            width: max(1, backgroundRect.width * percent),
            height: backgroundRect.height
        )

        cityHPBarBackground.path = CGPath(
            roundedRect: backgroundRect,
            cornerWidth: height / 2,
            cornerHeight: height / 2,
            transform: nil
        )
        if state.cityRemainingPower > 0 {
            cityHPBarFill.path = CGPath(
                roundedRect: fillRect,
                cornerWidth: height / 2,
                cornerHeight: height / 2,
                transform: nil
            )
        } else {
            cityHPBarFill.path = nil
        }
    }

    private func fitBattleNode(_ node: SKNode, targetHeight: CGFloat) {
        guard targetHeight > 0 else {
            return
        }

        node.setScale(1)

        let currentHeight: CGFloat
        if let sprite = node as? SKSpriteNode {
            currentHeight = sprite.size.height
        } else if let shape = node as? SKShapeNode {
            currentHeight = shape.frame.height
        } else {
            currentHeight = node.calculateAccumulatedFrame().height
        }

        guard currentHeight > 0 else {
            return
        }

        node.setScale(targetHeight / currentHeight)
    }

    private func drawLanePaths() {
        removeLaneNodes()

        let laneWidth = battlefieldLayout.lanePathWidth
        for lane in BattleLane.allCases {
            guard let start = battlefieldLayout.castleGatePoints[lane],
                  let end = battlefieldLayout.enemyGatePoints[lane] else {
                continue
            }

            let laneRect = CGRect(
                x: start.x - laneWidth / 2,
                y: start.y,
                width: laneWidth,
                height: max(0, end.y - start.y)
            )
            let node = SKShapeNode(rect: laneRect, cornerRadius: min(22, laneWidth * 0.22))
            node.name = "battleLaneTerrain-\(lane.rawValue)"
            node.fillColor = laneTerrainColor(for: lane)
            node.strokeColor = SKColor(red: 0.75, green: 0.64, blue: 0.39, alpha: 0.22)
            node.lineWidth = 1
            node.zPosition = -1
            addLaneTerrainDetails(to: node, lane: lane, rect: laneRect)
            environmentLayer.addChild(node)
            laneNodes.append(node)
        }
    }

    private func laneTerrainColor(for lane: BattleLane) -> SKColor {
        switch lane {
        case .left:
            return SKColor(red: 0.32, green: 0.42, blue: 0.23, alpha: 0.12)
        case .center:
            return SKColor(red: 0.70, green: 0.54, blue: 0.29, alpha: 0.14)
        case .right:
            return SKColor(red: 0.30, green: 0.40, blue: 0.24, alpha: 0.12)
        }
    }

    private func addLaneTerrainDetails(to laneNode: SKShapeNode, lane: BattleLane, rect: CGRect) {
        let detailCount = max(4, min(9, Int(rect.height / 58)))
        guard detailCount > 0 else {
            return
        }

        for index in 0..<detailCount {
            let progress = (CGFloat(index) + 0.5) / CGFloat(detailCount)
            let lateralPattern = CGFloat(((index * 37 + lane.rawValue * 19) % 100)) / 100
            let x = rect.minX + rect.width * (0.20 + lateralPattern * 0.60)
            let y = rect.minY + rect.height * progress
            let radius = CGFloat(2 + ((index + lane.rawValue) % 3))
            let detail = SKShapeNode(circleOfRadius: radius)
            detail.name = "battleLaneDetail-\(lane.rawValue)-\(index)"
            detail.fillColor = index.isMultiple(of: 2)
                ? SKColor(red: 0.20, green: 0.29, blue: 0.14, alpha: 0.28)
                : SKColor(red: 0.62, green: 0.51, blue: 0.32, alpha: 0.24)
            detail.strokeColor = .clear
            detail.position = CGPoint(x: x, y: y)
            detail.zPosition = 1
            laneNode.addChild(detail)
        }

        let ridgeRect = CGRect(
            x: rect.midX - rect.width * 0.08,
            y: rect.minY,
            width: rect.width * 0.16,
            height: rect.height
        )
        let centerRidge = SKShapeNode(rect: ridgeRect, cornerRadius: rect.width * 0.08)
        centerRidge.name = "battleLaneDetail-\(lane.rawValue)-ridge"
        centerRidge.fillColor = SKColor(red: 0.77, green: 0.62, blue: 0.34, alpha: 0.08)
        centerRidge.strokeColor = .clear
        centerRidge.zPosition = 0.5
        laneNode.addChild(centerRidge)
    }

    private func removeLaneNodes() {
        laneNodes.forEach { $0.removeFromParent() }
        laneNodes.removeAll()
    }

    private func layoutLaneIndicators() {
        removeLaneIndicatorNodes()

        let profile = state.currentCityLaneDefenseProfile
        for lane in BattleLane.allCases {
            let role = profile.role(for: lane)
            guard role != .standard, let gate = battlefieldLayout.enemyGatePoints[lane] else {
                continue
            }

            let indicator = makeLaneIndicator(role: role)
            indicator.position = CGPoint(x: gate.x, y: gate.y - 18)
            indicator.zPosition = 2
            environmentLayer.addChild(indicator)
            laneIndicatorNodes.append(indicator)
        }
    }

    /// Builds a lane-defense-role indicator glyph (shield, cracked shield, or plain).
    /// Shield is drawn in a ~16×19 pt local coordinate space (x: −8…+8, y: −10…+9).
    private func makeLaneIndicator(role: LaneDefenseRole) -> SKNode {
        let container = SKNode()
        container.name = "laneIndicator-\(role.rawValue)"

        // Shield outline in a 16×19 pt local space
        let shieldPath = CGMutablePath()
        shieldPath.move(to: CGPoint(x: 0, y: 9))
        shieldPath.addLine(to: CGPoint(x: 8, y: 5))
        shieldPath.addLine(to: CGPoint(x: 8, y: -2))
        shieldPath.addCurve(
            to: CGPoint(x: 0, y: -10),
            control1: CGPoint(x: 8, y: -6),
            control2: CGPoint(x: 5, y: -9)
        )
        shieldPath.addCurve(
            to: CGPoint(x: -8, y: -2),
            control1: CGPoint(x: -5, y: -9),
            control2: CGPoint(x: -8, y: -6)
        )
        shieldPath.addLine(to: CGPoint(x: -8, y: 5))
        shieldPath.closeSubpath()

        let shield = SKShapeNode(path: shieldPath)
        shield.lineWidth = 1.5

        switch role {
        case .fortified:
            shield.fillColor = GameUITheme.Color.danger
            shield.strokeColor = SKColor(white: 1.0, alpha: 0.7)
        case .exposed:
            shield.fillColor = SKColor(white: 0.55, alpha: 0.55)
            shield.strokeColor = SKColor(white: 1.0, alpha: 0.4)
            let crackPath = CGMutablePath()
            crackPath.move(to: CGPoint(x: -2, y: 9))
            crackPath.addLine(to: CGPoint(x: 2, y: 2))
            crackPath.addLine(to: CGPoint(x: -1, y: -3))
            crackPath.addLine(to: CGPoint(x: 2, y: -10))
            let crack = SKShapeNode(path: crackPath)
            crack.strokeColor = SKColor(red: 0.07, green: 0.10, blue: 0.13, alpha: 1.0)
            crack.lineWidth = 2
            crack.zPosition = 1
            container.addChild(crack)
        case .standard:
            break
        }

        container.addChild(shield)
        return container
    }

    private func removeLaneIndicatorNodes() {
        laneIndicatorNodes.forEach { $0.removeFromParent() }
        laneIndicatorNodes.removeAll()
    }

    private func setBattlefieldHidden(_ isHidden: Bool) {
        environmentLayer.isHidden = isHidden
        soldierLayer.isHidden = isHidden
        effectsLayer.isHidden = isHidden
    }

    private var manualSpawnableSoldierTypes: [SoldierType] {
        state.manualSpawnableSoldierTypes()
    }

    private func reconcileSelectedManualSoldierType() {
        let spawnableTypes = manualSpawnableSoldierTypes
        if !spawnableTypes.contains(selectedManualSoldierType), let firstSpawnableType = spawnableTypes.first {
            selectedManualSoldierType = firstSpawnableType
        }
    }

    private func manualTypeButtonName(for soldierType: SoldierType) -> String {
        "\(ButtonName.manualType)-\(soldierType.rawValue)"
    }

    private func soldierType(forManualTypeButtonName buttonName: String) -> SoldierType? {
        guard buttonName.hasPrefix("\(ButtonName.manualType)-") else {
            return nil
        }

        let rawValue = String(buttonName.dropFirst(ButtonName.manualType.count + 1))
        return SoldierType(rawValue: rawValue)
    }

    private func redraw(shouldLayout: Bool = true) {
        reconcileSelectedManualSoldierType()
        updateHUDIcons()

        goldLabel.text = compactNumber(state.gold)
        cityLevelLabel.text = state.displayCityTitle
        defenseTraitLabel.text = "Trait: \(state.currentCityDefenseTrait.displayName)"
        cityHPLabel.text = ""
        // When `shouldLayout` is true, `layoutInterface()` below re-runs
        // `layoutCityHPBar()` as part of the full layout pass, so calling it
        // here would build CGPaths that are immediately discarded. Skip it in
        // that case; when `shouldLayout` is false (the per-damage-tick hot
        // path), `layoutInterface()` does not run, so the HP bar must be
        // refreshed here to reflect the new `cityRemainingPower`.
        if !shouldLayout {
            layoutCityHPBar()
        }
        updateLiveCombatStatusLabel()
        feedbackLabel.text = feedbackText
        let spawnableTypes = manualSpawnableSoldierTypes
        manualTypeButtonLabel.text = spawnableTypes.isEmpty ? "No Units" : selectedManualSoldierType.displayName
        for (soldierType, bundle) in manualTypeButtonBundles {
            bundle.label.text = soldierType.displayName
            bundle.background.fillColor = selectedManualSoldierType == soldierType
                ? GameUITheme.Color.spawn
                : SKColor(red: 0.18, green: 0.34, blue: 0.42, alpha: 1.0)
            bundle.button.isHidden = !isManualTypeMenuOpen || !spawnableTypes.contains(soldierType)
        }
        spawnButtonLabel.text = spawnableTypes.isEmpty ? "Build Unit" : "Spawn"
        buildButtonLabel.text = ""
        worldButtonLabel.text = ""
        if shouldLayout {
            layoutInterface()
        }
        presentFeedbackTooltipIfNeeded()
    }

    private func updateHUDIcons() {
        setIconTexture(manualTypeButtonIcon, type: selectedManualSoldierType)
        setIconTexture(spawnButtonIcon, type: selectedManualSoldierType)
        setIconTexture(soldierStatusIcon, type: selectedManualSoldierType)

        for (soldierType, bundle) in manualTypeButtonBundles {
            setIconTexture(bundle.icon, type: soldierType)
        }
    }

    private func soldierIconAssetName(for type: SoldierType) -> String {
        firstAvailableSoldierAnimationFrameName(for: type) ?? soldierAssetName(for: type)
    }

    /// Returns the cached HUD icon texture for `type`, allocating it once.
    /// The resolved asset name is deterministic per `SoldierType` (animation
    /// frame availability is stable across the scene's lifetime), so the cached
    /// `SKTexture` is reused across every `updateHUDIcons` call.
    private func soldierHUDIconTexture(for type: SoldierType) -> SKTexture {
        if let cached = soldierHUDIconTextureCache[type] {
            return cached
        }
        let assetName = soldierIconAssetName(for: type)
        let source = SKTexture(imageNamed: assetName)
        // Crop the full-canvas walk frame to the authored body bounds so the
        // icon shows the full body (hood/head included) without the transparent
        // canvas padding. The body region is per-type and matches the actual
        // opaque artwork, so no edge of the silhouette is clipped.
        let texture = isSoldierAnimationFrameAssetName(assetName)
            ? SKTexture(rect: SoldierAnimationGeometry(type: type).bodyRegion, in: source)
            : source
        soldierHUDIconTextureCache[type] = texture
        return texture
    }

    private func setIconTexture(_ icon: SKSpriteNode, type: SoldierType) {
        let texture = soldierHUDIconTexture(for: type)
        // Pointer equality guards redundant reassignment on the hot path: the
        // cache returns the same `SKTexture` instance for a given type, so this
        // skips the texture swap entirely when the type is unchanged.
        if icon.texture !== texture {
            icon.texture = texture
        }
        icon.colorBlendFactor = 0
    }

    private func isSoldierAnimationFrameAssetName(_ assetName: String) -> Bool {
        SoldierType.allCases.contains { type in
            assetName.hasPrefix("\(type.rawValue)-\(SoldierAnimationAction.walk.rawValue)-")
        }
    }

    private func presentFeedbackTooltipIfNeeded() {
        guard !feedbackText.isEmpty, feedbackText != lastPresentedTooltipText else {
            return
        }

        showTooltip(feedbackText)
    }

    private func showTooltip(_ text: String) {
        guard !text.isEmpty else {
            return
        }

        lastPresentedTooltipText = text
        feedbackLabel.text = text
        let feedbackPanelWidth = min(cachedContentWidth, max(220, feedbackLabel.frame.width + 32))
        feedbackPanel.update(size: CGSize(width: feedbackPanelWidth, height: max(32, feedbackLabel.fontSize + 18)))
        feedbackPanel.position = feedbackLabel.position
        feedbackPanel.removeAllActions()
        feedbackLabel.removeAllActions()
        feedbackPanel.alpha = 1
        feedbackLabel.alpha = 1

        let panelWait = SKAction.wait(forDuration: EffectStyle.tooltipVisibleDuration)
        let panelFade = SKAction.fadeOut(withDuration: 0.22)
        let labelWait = SKAction.wait(forDuration: EffectStyle.tooltipVisibleDuration)
        let labelFade = SKAction.fadeOut(withDuration: 0.22)
        // Reset the dedupe token once the tooltip finishes fading out so that a
        // repeated identical message (e.g. "Soldiers dealt 5 damage." tick after
        // tick from a single infantry) can re-trigger the tooltip. Without this,
        // `presentFeedbackTooltipIfNeeded` would suppress it forever.
        let resetToken = SKAction.run { [weak self] in
            self?.resetFeedbackTooltipDedupeToken()
        }
        feedbackPanel.run(SKAction.sequence([panelWait, panelFade, resetToken]), withKey: "feedbackTooltip")
        feedbackLabel.run(SKAction.sequence([labelWait, labelFade]), withKey: "feedbackTooltip")
    }

    /// Clears the tooltip dedupe token. Called by the fade-out `SKAction` once
    /// the tooltip has fully hidden, so a subsequent identical feedback message
    /// can re-trigger the tooltip instead of being silently suppressed.
    private func resetFeedbackTooltipDedupeToken() {
        lastPresentedTooltipText = ""
    }

    private func updateLiveCombatStatusLabel() {
        liveCombatStatusLabel.fontSize = 18
        liveCombatStatusLabel.text = "\(combat.livingSoldierCount)"
        fitLabel(liveCombatStatusLabel, maxWidth: currentLeftHUDLabelWidth)
    }

    private func advanceCombat(deltaTime: TimeInterval) {
        guard state.stageStatus == .battleActive, !isConquestPopupVisible else {
            return
        }

        let shouldSaveBuildingProgress = deltaTime > 0 && state.cityBattleStateForCurrentCity.occupiedSlotCount > 0
        let buildingSpawns = state.resolveActiveBuildingSpawns(deltaTime: deltaTime)
        for spawn in buildingSpawns {
            let soldierID = combat.spawnSoldier(
                type: spawn.soldierType,
                source: .building,
                level: spawn.level,
                attackPower: state.traitAdjustedSoldierAttackPower(for: spawn.soldierType, level: spawn.level)
            )
            createSoldierNode(id: soldierID)
        }
        if shouldSaveBuildingProgress {
            if !buildingSpawns.isEmpty {
                // A spawn fired — persist immediately to prevent duplicate-spawn
                // on crash. Reset the throttle accumulator since we just saved.
                buildingProgressSaveAccumulator = 0
                store.save(state)
            } else {
                buildingProgressSaveAccumulator += deltaTime
                if buildingProgressSaveAccumulator >= Self.buildingProgressSaveInterval {
                    buildingProgressSaveAccumulator = 0
                    store.save(state)
                }
            }
        }

        let result = combat.tick(deltaTime: deltaTime, cityRemainingHP: state.cityRemainingPower)
        applyCombatResult(result)
        syncSoldierNodes()
        if !buildingSpawns.isEmpty {
            updateLiveCombatStatusLabel()
        }
    }

    private func applyCombatResult(_ result: BattleCombatState.TickResult) {
        for towerShot in result.towerShots {
            playTowerShot(at: towerShot.soldierID)
        }

        for soldierID in result.soldierAttackIDs {
            playSoldierAttackFeedback(for: soldierID)
        }

        let killedSoldierIDs = Set(result.killedSoldierIDs)

        for soldierID in result.damagedSoldierIDs {
            playSoldierHitFeedback(for: soldierID, schedulesRemoval: killedSoldierIDs.contains(soldierID))
        }

        // Note: `killedSoldierIDs` is a structural subset of `damagedSoldierIDs`
        // (BattleCombatState appends to both in the same tower-shot block), so
        // every killed soldier is already routed through playSoldierHitFeedback
        // above with schedulesRemoval=true. No separate killed-loop is needed.

        if !result.killedSoldierIDs.isEmpty {
            updateLiveCombatStatusLabel()
        }

        guard result.cityDamage > 0 else {
            return
        }

        let damageResult = state.applyLiveCombatDamage(result.cityDamage)
        guard damageResult.attackApplied else {
            return
        }

        let conqueredCity = damageResult.conqueredCities > 0

        if conqueredCity {
            clearLiveCombat()
            // The conquest popup communicates the result; clear any stale
            // feedback so the tooltip doesn't present behind the overlay and
            // linger after the popup closes. Clearing (rather than just not
            // setting) also covers a stale message left over from an earlier
            // damage tick whose tooltip has already faded (dedupe token reset).
            feedbackText = ""
        } else {
            feedbackText = "Soldiers dealt \(compactNumber(damageResult.damageDealt)) damage."
        }

        store.save(state)
        redraw(shouldLayout: conqueredCity)

        if conqueredCity {
            playFloatingFeedback(text: "-\(compactNumber(damageResult.damageDealt))", at: enemyCityImpactPoint)
            playCityConquestFeedback()
            showConquestPopup(goldEarned: damageResult.goldEarned)
        } else {
            playFloatingFeedback(text: "-\(compactNumber(damageResult.damageDealt))", at: enemyCityImpactPoint)
            playCityHitFeedback()
        }
    }

    private func spawnSoldier() {
        guard !isConquestPopupVisible, state.stageStatus == .battleActive else {
            return
        }

        guard let manualSoldierLevel = state.manualSoldierLevel(for: selectedManualSoldierType) else {
            feedbackText = manualSpawnableSoldierTypes.isEmpty
                ? "Build a unit building first."
                : "Build \(selectedManualSoldierType.displayName) first."
            redraw()
            return
        }

        guard combat.livingSoldierCount(source: .manual) < KingdomGameState.manualSoldierCap else {
            feedbackText = "Manual squad is full."
            redraw()
            return
        }

        let soldierID = combat.spawnSoldier(
            type: selectedManualSoldierType,
            source: .manual,
            level: manualSoldierLevel,
            attackPower: state.traitAdjustedSoldierAttackPower(
                for: selectedManualSoldierType,
                level: manualSoldierLevel
            )
        )
        createSoldierNode(id: soldierID)
        syncSoldierNodes()
        updateLiveCombatStatusLabel()
    }

    private func toggleManualTypeMenu() {
        guard !isConquestPopupVisible, state.stageStatus == .battleActive else {
            return
        }

        if manualSpawnableSoldierTypes.isEmpty {
            feedbackText = "Build a unit building first."
            isManualTypeMenuOpen = false
            redraw(shouldLayout: false)
            return
        }

        isManualTypeMenuOpen.toggle()
        redraw(shouldLayout: false)
    }

    private func selectManualSoldierType(_ type: SoldierType) {
        guard !isConquestPopupVisible, state.stageStatus == .battleActive else {
            return
        }

        guard manualSpawnableSoldierTypes.contains(type) else {
            feedbackText = "Build \(type.displayName) first."
            isManualTypeMenuOpen = false
            redraw(shouldLayout: false)
            return
        }

        selectedManualSoldierType = type
        isManualTypeMenuOpen = false
        redraw(shouldLayout: false)
    }

    private func hideManualTypeMenuWithoutLayoutIfNeeded() {
        guard isManualTypeMenuOpen else {
            return
        }

        isManualTypeMenuOpen = false
        redraw(shouldLayout: false)
    }

    private func showGoldInfoTooltip() {
        showTooltip("Gold \(compactNumber(state.gold)) | Soldiers \(combat.livingSoldierCount)")
    }

    private func showCityInfoTooltip() {
        showTooltip(
            "\(state.displayCityTitle) | \(state.currentCityDefenseTrait.displayName) | HP "
                + "\(compactNumber(state.cityRemainingPower))/\(compactNumber(state.cityMaxPower))"
        )
    }

    private func requestCountryMap() {
        guard !isConquestPopupVisible, state.stageStatus == .battleActive else {
            return
        }

        guard combat.livingSoldierCount(source: .manual) == 0 else {
            feedbackText = "Finish the current squad before viewing world."
            redraw()
            return
        }

        state.markCurrentCityBuildingProgressInactive(at: Date())
        store.save(state)
        router?.battleSceneDidRequestCountryMap(self)
    }

    private func requestBuildingView() {
        guard !isConquestPopupVisible, state.stageStatus == .battleActive else {
            return
        }

        // BuildingViewScene does not carry over BattleCombatState's live soldier roster.
        // Transitioning with living manual soldiers would lose them without refund.
        guard combat.livingSoldierCount(source: .manual) == 0 else {
            feedbackText = "Finish the current squad before building."
            redraw()
            return
        }

        state.markCurrentCityBuildingProgressInactive(at: Date())
        store.save(state)
        router?.battleSceneDidRequestBuildingView(self)
    }

    private func createSoldierNode(id: BattleCombatState.SoldierID) {
        guard soldierNodes[id] == nil else {
            return
        }
        guard let soldier = combat.soldier(id: id) else {
            return
        }

        let root = SKNode()
        root.name = BattleAssetName.normalSoldier

        let body = makeSoldierNode(for: soldier.type)
        body.zPosition = 1
        root.addChild(body)

        let hpBackground = SKShapeNode()
        hpBackground.fillColor = SKColor(white: 0.05, alpha: 0.9)
        hpBackground.strokeColor = SKColor(white: 1.0, alpha: 0.3)
        hpBackground.lineWidth = 1
        hpBackground.zPosition = 2

        let hpFill = SKShapeNode()
        hpFill.fillColor = SKColor(red: 0.25, green: 0.9, blue: 0.38, alpha: 1.0)
        hpFill.strokeColor = .clear
        hpFill.zPosition = 3

        let formationSlot = nextAvailableFormationSlot(for: soldier.lane)
        let isAnimatedCanvas = firstAvailableSoldierAnimationFrameName(for: soldier.type) != nil

        root.addChild(hpBackground)
        root.addChild(hpFill)
        soldierLayer.addChild(root)
        soldierNodes[id] = SoldierNodeBundle(
            root: root,
            body: body,
            hpBarBackground: hpBackground,
            hpBarFill: hpFill,
            type: soldier.type,
            lane: soldier.lane,
            formationSlot: formationSlot,
            isAnimatedCanvas: isAnimatedCanvas
        )
    }

    private func nextAvailableFormationSlot(for lane: BattleLane) -> Int {
        let occupiedSlots = Set(
            soldierNodes.values
                .filter { $0.lane == lane }
                .map(\.formationSlot)
        )
        // The slot space is unbounded and only as many slots are occupied as
        // there are live soldiers in this lane, so a free slot always exists.
        var slot = 0
        while occupiedSlots.contains(slot) {
            slot += 1
        }
        return slot
    }

    private func soldierFormationOffset(for slot: Int) -> CGPoint {
        let clampedSlot = max(0, slot)
        let column = SoldierFormation.columns[clampedSlot % SoldierFormation.columns.count]
        let row = clampedSlot / SoldierFormation.columns.count
        let bodyHeight = soldierTargetHeight()
        return CGPoint(
            x: CGFloat(column) * bodyHeight * SoldierFormation.lateralSpacingScale,
            y: -CGFloat(row) * bodyHeight * SoldierFormation.rowSpacingScale
        )
    }

    private func syncSoldierNodes() {
        let liveSoldiers = combat.soldiers.filter(\.isAlive)
        let liveIDs = Set(liveSoldiers.map(\.id))

        for id in Array(soldierNodes.keys)
            where !liveIDs.contains(id) && !pendingAnimatedRemovalSoldierIDs.contains(id) {
            removeSoldierNode(id: id, animated: false)
        }

        for soldier in liveSoldiers {
            if soldierNodes[soldier.id] == nil {
                createSoldierNode(id: soldier.id)
            }

            guard let bundle = soldierNodes[soldier.id] else {
                continue
            }

            let lanePoint = point(forLane: soldier.lane, position: soldier.position)
            let formationOffset = soldierFormationOffset(for: bundle.formationSlot)
            // Animated sprites use full-canvas frames with a transparent foot
            // margin (bodyRegion.minY). With anchorPoint.y == 0 the canvas
            // bottom sits at the root, so the visible feet float above the lane
            // by that margin. Shift the root down by the scaled margin so the
            // feet land on the lane baseline.
            let footMargin = animatedSoldierFootMargin(for: bundle)
            bundle.root.position = CGPoint(
                x: lanePoint.x + formationOffset.x,
                y: lanePoint.y + formationOffset.y - footMargin
            )
            bundle.root.setScale(1)
            fitSoldierBodyNode(
                bundle.body,
                type: bundle.type,
                targetHeight: soldierTargetHeight(),
                isAnimatedCanvas: bundle.isAnimatedCanvas
            )
            layoutSoldierHPBar(bundle, soldier: soldier)
            startSoldierWalkAnimation(for: soldier.id, type: soldier.type)
        }
    }

    /// Scaled transparent-foot margin for an animated soldier — the vertical
    /// distance between the canvas bottom (anchorPoint.y == 0) and the visible
    /// feet. Returns 0 for non-animated (static fallback) sprites, which are
    /// authored without the full-canvas margin.
    private func animatedSoldierFootMargin(for bundle: SoldierNodeBundle) -> CGFloat {
        guard bundle.isAnimatedCanvas else {
            return 0
        }

        let geometry = SoldierAnimationGeometry(type: bundle.type)
        let frameSize = geometry.frameSize(forBodyHeight: soldierTargetHeight())
        return geometry.bodyRegion.minY * frameSize.height
    }

    private func soldierTargetHeight() -> CGFloat {
        if size.height < 500 {
            return max(38, min(50, size.height * 0.12))
        }

        return max(54, min(70, size.height * 0.075))
    }

    private func fitSoldierBodyNode(
        _ node: SKNode,
        type: SoldierType,
        targetHeight: CGFloat,
        isAnimatedCanvas: Bool
    ) {
        guard let sprite = node as? SKSpriteNode else {
            fitBattleNode(node, targetHeight: targetHeight)
            return
        }

        // Only the animation-canvas sprite is authored against the normalized
        // `SoldierAnimationGeometry` body bounds. The static fallback sprite is
        // a standalone asset; sizing it via the geometry would stretch it to
        // the full animation canvas and misplace its HP bar, so it stays on the
        // legacy fit path that scales to its intrinsic texture dimensions.
        guard isAnimatedCanvas else {
            fitBattleNode(sprite, targetHeight: targetHeight)
            return
        }

        sprite.setScale(1)
        sprite.size = SoldierAnimationGeometry(type: type).frameSize(forBodyHeight: targetHeight)
    }

    private func point(forLane lane: BattleLane, position: Double) -> CGPoint {
        battlefieldLayout.point(forLane: lane, position: position)
    }

    private func layoutSoldierHPBar(_ bundle: SoldierNodeBundle, soldier: BattleCombatState.Soldier) {
        let bodyFrame = soldierLogicalBodyFrame(for: bundle)
        let width = max(36, min(56, bodyFrame.width * 0.72))
        let height: CGFloat = 5
        let y = bodyFrame.maxY + 1.5
        let percent = min(max(CGFloat(soldier.currentHP) / CGFloat(max(1, soldier.maxHP)), 0), 1)

        bundle.hpBarBackground.path = CGPath(
            roundedRect: CGRect(x: -width / 2, y: y, width: width, height: height),
            cornerWidth: height / 2,
            cornerHeight: height / 2,
            transform: nil
        )
        bundle.hpBarFill.path = CGPath(
            roundedRect: CGRect(x: -width / 2, y: y, width: max(1, width * percent), height: height),
            cornerWidth: height / 2,
            cornerHeight: height / 2,
            transform: nil
        )
    }

    private func soldierLogicalBodyFrame(for bundle: SoldierNodeBundle) -> CGRect {
        guard bundle.isAnimatedCanvas,
              let sprite = bundle.body as? SKSpriteNode else {
            return bundle.body.calculateAccumulatedFrame()
        }

        return SoldierAnimationGeometry(type: bundle.type).logicalBodyFrame(frameSize: sprite.size)
    }

    private func clearLiveCombat() {
        combat = Self.makeCombat(for: state, seed: combatSeed)
        lastUpdateTime = nil

        for id in Array(soldierNodes.keys) {
            removeSoldierNode(id: id, animated: false)
        }
        pendingAnimatedRemovalSoldierIDs.removeAll()

        updateLiveCombatStatusLabel()
    }

    private func removeSoldierNode(id: BattleCombatState.SoldierID, animated: Bool) {
        guard let bundle = soldierNodes.removeValue(forKey: id) else {
            return
        }
        pendingAnimatedRemovalSoldierIDs.remove(id)

        bundle.root.removeAllActions()
        // Body actions (walk/attack/hit) live on `bundle.body`, not `root`.
        // Stop them too so a killed soldier doesn't keep animating its body
        // during the fade-out.
        bundle.body.removeAllActions()

        if animated {
            let fade = SKAction.fadeOut(withDuration: 0.18)
            let remove = SKAction.removeFromParent()
            bundle.root.run(SKAction.sequence([fade, remove]))
        } else {
            bundle.root.removeFromParent()
        }
    }

    private func makeSoldierNode(for type: SoldierType) -> SKNode {
        let soldier: SKNode
        let visualColor = soldierVisualColor(for: type)
        let preferredAssetName = soldierAssetName(for: type)
        let fallbackAssetName = BattleAssetName.normalSoldier
        let assetName = UIImage(named: preferredAssetName) != nil ? preferredAssetName : fallbackAssetName

        if let animatedTextureName = firstAvailableSoldierAnimationFrameName(for: type) {
            let sprite = SKSpriteNode(texture: soldierAnimationTexture(named: animatedTextureName))
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
            soldier = sprite
        } else if UIImage(named: assetName) != nil {
            let sprite = SKSpriteNode(imageNamed: assetName)
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
            if assetName == fallbackAssetName {
                sprite.color = visualColor
                sprite.colorBlendFactor = type == .infantry ? 0.15 : 0.55
            }
            soldier = sprite
        } else {
            let shape = SKShapeNode(rect: CGRect(x: -10, y: 0, width: 20, height: 28), cornerRadius: 5)
            shape.fillColor = visualColor
            shape.strokeColor = SKColor(white: 1.0, alpha: 0.4)
            shape.lineWidth = 2
            soldier = shape
        }

        soldier.name = assetName
        return soldier
    }

    private func soldierAssetName(for type: SoldierType) -> String {
        switch type {
        case .archer:
            return BattleAssetName.archerSoldier
        case .infantry, .cavalry, .mage, .siege:
            return BattleAssetName.normalSoldier
        }
    }

    private func soldierAnimationFrameNames(for type: SoldierType, action: SoldierAnimationAction) -> [String] {
        (1...SoldierAnimationTiming.frameCount).map {
            "\(type.rawValue)-\(action.rawValue)-\(String(format: "%02d", $0))"
        }
    }

    /// Probes whether the animated-canvas sprite path is available for `type`
    /// by checking only the first walk frame (`<type>-walk-01`). This is a
    /// deliberate granularity mismatch with `soldierAnimationTextures`, which
    /// validates every frame of a specific action: a type can report
    /// `isAnimatedCanvas == true` here (walk-01 exists) yet still have an
    /// incomplete attack/hit set, in which case `playSoldierAnimation` falls
    /// back to its silent no-op for that action and the soldier keeps walking.
    /// The all-or-nothing storyboard validation in
    /// `tools/slice_soldier_animation_strips.py` makes this a non-issue in
    /// practice (a type either ships all 30 frames or none), so the walk-01
    /// probe is sufficient as a cheap availability gate.
    private func firstAvailableSoldierAnimationFrameName(for type: SoldierType) -> String? {
        let frameNames = soldierAnimationFrameNames(for: type, action: .walk)
        guard let firstFrameName = frameNames.first, UIImage(named: firstFrameName) != nil else {
            return nil
        }
        return firstFrameName
    }

    private func soldierAnimationTextures(for type: SoldierType, action: SoldierAnimationAction) -> [SKTexture] {
        if let cached = soldierAnimationTextureCache[type]?[action] {
            return cached
        }
        let frameNames = soldierAnimationFrameNames(for: type, action: action)
        let missingFrameNames = frameNames.filter { UIImage(named: $0) == nil }
        if !missingFrameNames.isEmpty {
            // An incomplete texture set usually means an asset was dropped or
            // misnamed. In DEBUG this is almost always a build/asset mistake
            // worth failing loudly on; in release we fall through to the
            // static fallback sprite path.
            #if DEBUG
            let actionKey = "\(type.rawValue)-\(action.rawValue)"
            assertionFailure("Missing soldier animation frames for \(actionKey): \(missingFrameNames)")
            #endif
            return []
        }
        let textures = frameNames.map { soldierAnimationTexture(named: $0) }
        // Only cache complete (non-empty) texture sets; an incomplete set likely
        // means an asset is missing at this call, which we want to re-resolve
        // rather than pin the empty result for the scene's lifetime.
        if !textures.isEmpty {
            if soldierAnimationTextureCache[type] == nil {
                soldierAnimationTextureCache[type] = [:]
            }
            soldierAnimationTextureCache[type]?[action] = textures
        }
        return textures
    }

    private func soldierAnimationTexture(named frameName: String) -> SKTexture {
        SKTexture(imageNamed: frameName)
    }

    private func soldierVisualColor(for type: SoldierType) -> SKColor {
        switch type {
        case .infantry:
            return SKColor(red: 0.18, green: 0.52, blue: 1.0, alpha: 1.0)
        case .archer:
            return SKColor(red: 0.18, green: 0.76, blue: 0.34, alpha: 1.0)
        case .cavalry:
            return SKColor(red: 0.92, green: 0.58, blue: 0.22, alpha: 1.0)
        case .mage:
            return SKColor(red: 0.62, green: 0.38, blue: 0.94, alpha: 1.0)
        case .siege:
            return SKColor(red: 0.64, green: 0.68, blue: 0.70, alpha: 1.0)
        }
    }

    private func playCityHitFeedback() {
        guard let enemyCityNode else {
            return
        }

        enemyCityNode.removeAction(forKey: "cityHitFeedback")

        if let sprite = enemyCityNode as? SKSpriteNode {
            let originalColor = sprite.color
            let originalBlendFactor = sprite.colorBlendFactor
            let flash = SKAction.colorize(with: .white, colorBlendFactor: 0.8, duration: 0.06)
            let restore = SKAction.colorize(with: originalColor, colorBlendFactor: originalBlendFactor, duration: 0.12)
            sprite.run(SKAction.sequence([flash, restore]), withKey: "cityHitFeedback")
        } else {
            enemyCityNode.run(cityShakeAction(), withKey: "cityHitFeedback")
        }

        playImpactFlash()
    }

    private func playCityConquestFeedback() {
        guard let enemyCityNode else {
            return
        }

        enemyCityNode.removeAction(forKey: "cityConquestFeedback")

        if let sprite = enemyCityNode as? SKSpriteNode {
            let originalColor = sprite.color
            let originalBlendFactor = sprite.colorBlendFactor
            let flash = SKAction.colorize(with: GameUITheme.Color.gold, colorBlendFactor: 0.65, duration: 0.09)
            let restore = SKAction.colorize(with: originalColor, colorBlendFactor: originalBlendFactor, duration: 0.18)
            sprite.run(SKAction.sequence([flash, restore]), withKey: "cityConquestFeedback")
        } else {
            enemyCityNode.run(cityShakeAction(), withKey: "cityConquestFeedback")
        }

        playImpactFlash()
    }

    private func playImpactFlash() {
        let flash: SKNode
        if UIImage(named: BattleAssetName.hitFlash) != nil {
            let sprite = SKSpriteNode(imageNamed: BattleAssetName.hitFlash)
            sprite.size = CGSize(width: 34, height: 34)
            flash = sprite
        } else {
            let shape = SKShapeNode(circleOfRadius: 9)
            shape.fillColor = SKColor(red: 1.0, green: 0.78, blue: 0.16, alpha: 0.9)
            shape.strokeColor = SKColor(red: 1.0, green: 0.38, blue: 0.08, alpha: 0.95)
            shape.lineWidth = 2
            flash = shape
        }
        flash.position = enemyCityImpactPoint
        flash.zPosition = GameUITheme.Z.effects
        flash.setScale(1)
        effectsLayer.addChild(flash)

        let fade = SKAction.fadeOut(withDuration: 0.18)
        fade.timingMode = .easeOut
        let remove = SKAction.removeFromParent()
        flash.run(SKAction.sequence([fade, remove]))
    }

    private func playFloatingFeedback(text: String, at position: CGPoint, color: SKColor = GameUITheme.Color.gold) {
        let label = SKLabelNode(fontNamed: GameUITheme.Font.bold)
        label.name = EffectName.floatingFeedback
        label.text = text
        label.fontSize = EffectStyle.floatingFeedbackFontSize
        label.fontColor = color
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: position.x, y: position.y + 26)
        label.zPosition = EffectStyle.floatingFeedbackZ
        label.alpha = 0
        effectsLayer.addChild(label)

        let appear = SKAction.fadeIn(withDuration: 0.05)
        let rise = SKAction.moveBy(x: 0, y: 24, duration: 0.5)
        rise.timingMode = .easeOut
        let fade = SKAction.fadeOut(withDuration: 0.2)
        let remove = SKAction.removeFromParent()
        label.run(SKAction.sequence([appear, SKAction.group([rise, fade]), remove]))
    }

    private func playTowerShot(at soldierID: BattleCombatState.SoldierID) {
        guard let bundle = soldierNodes[soldierID] else {
            return
        }

        let target = towerShotTargetPoint(for: bundle)
        let shot: SKNode
        if UIImage(named: BattleAssetName.towerProjectile) != nil {
            let sprite = SKSpriteNode(imageNamed: BattleAssetName.towerProjectile)
            sprite.size = CGSize(width: 26, height: 16)
            shot = sprite
        } else {
            let shape = SKShapeNode(circleOfRadius: 4)
            shape.fillColor = SKColor(red: 1.0, green: 0.28, blue: 0.18, alpha: 1.0)
            shape.strokeColor = .clear
            shot = shape
        }
        shot.position = battlefieldLayout.enemyGatePoints[bundle.lane] ?? enemyCityImpactPoint
        shot.zPosition = GameUITheme.Z.effects
        effectsLayer.addChild(shot)

        let move = SKAction.move(to: target, duration: 0.12)
        let remove = SKAction.removeFromParent()
        shot.run(SKAction.sequence([move, remove]))
    }

    /// Scene-space point where a tower projectile should connect with a
    /// soldier. Targets the body center (via `soldierLogicalBodyFrame`) rather
    /// than the raw root position, which — after the foot-margin offset is
    /// applied to animated soldiers — sits below the lane baseline.
    private func towerShotTargetPoint(for bundle: SoldierNodeBundle) -> CGPoint {
        let bodyFrame = soldierLogicalBodyFrame(for: bundle)
        return CGPoint(
            x: bundle.root.position.x + bodyFrame.midX,
            y: bundle.root.position.y + bodyFrame.midY
        )
    }

    private func playSoldierAttackFeedback(for soldierID: BattleCombatState.SoldierID) {
        playSoldierAnimation(.attack, for: soldierID, resumesWalk: true)
    }

    private func playSoldierHitFeedback(
        for soldierID: BattleCombatState.SoldierID,
        schedulesRemoval: Bool
    ) {
        playSoldierAnimation(.hit, for: soldierID, resumesWalk: !schedulesRemoval)
        if schedulesRemoval {
            scheduleDelayedSoldierRemoval(for: soldierID)
        }
    }

    private func startSoldierWalkAnimation(for soldierID: BattleCombatState.SoldierID, type: SoldierType) {
        guard let bundle = soldierNodes[soldierID],
              let sprite = bundle.body as? SKSpriteNode,
              sprite.action(forKey: SoldierAnimationKey.walk) == nil,
              sprite.action(forKey: SoldierAnimationKey.attack) == nil,
              sprite.action(forKey: SoldierAnimationKey.hit) == nil else {
            return
        }

        let textures = soldierAnimationTextures(for: type, action: .walk)
        guard !textures.isEmpty else {
            return
        }

        sprite.run(
            SKAction.repeatForever(soldierTextureAction(
                textures: textures,
                action: .walk,
                type: type,
                sprite: sprite
            )),
            withKey: SoldierAnimationKey.walk
        )
    }

    private func soldierTextureAction(
        textures: [SKTexture],
        action: SoldierAnimationAction,
        type: SoldierType,
        sprite: SKSpriteNode
    ) -> SKAction {
        let durations = SoldierAnimationTiming.frameDurations(for: action, type: type)
        let steps = zip(textures, durations).flatMap { texture, duration in
            // On iOS 26, SKAction.setTexture can restore the texture's intrinsic
            // size even with resize disabled. Direct assignment preserves the
            // fitted geometry owned by fitSoldierBodyNode.
            [SKAction.run { [weak sprite] in
                sprite?.texture = texture
            }, SKAction.wait(forDuration: duration)]
        }
        return SKAction.sequence(steps)
    }

    private func playSoldierAnimation(
        _ action: SoldierAnimationAction,
        for soldierID: BattleCombatState.SoldierID,
        resumesWalk: Bool
    ) {
        guard let bundle = soldierNodes[soldierID],
              let sprite = bundle.body as? SKSpriteNode else {
            return
        }

        let textures = soldierAnimationTextures(for: bundle.type, action: action)
        guard !textures.isEmpty else {
            return
        }
        let soldierType = bundle.type

        // Attack animations last longer than the combat attack interval for
        // infantry, archer, cavalry, and mage (e.g. infantry attacks every
        // 1.0s but its attack cycle is 1.2s). Restarting the attack sequence
        // on every attack tick would pop it back to frame 1 before it ever
        // reaches the final frames or resumes walking. Ignore attack triggers
        // while an attack animation is already in flight; the in-flight cycle
        // finishes, resumes walk, and the next trigger starts a fresh cycle.
        // Hit still interrupts an in-flight attack (a tower-hit reaction
        // should override the attack pose), so this guard is attack-only.
        //
        // Documented side-effect: because every other attack trigger lands
        // while the previous cycle is still playing, the *visual* attack
        // cadence for those four types is ~2x their damage cadence (infantry
        // and archer cycle every ~2.0s, cavalry every ~1.74s, mage every
        // ~2.36s; siege is unaffected because its 1.6s animation is shorter
        // than its 1.82s damage interval). This is an accepted tradeoff —
        // the alternative (restarting on every trigger) never reaches the
        // strike frames and looks worse. See CLAUDE.md "Attack animations
        // last longer..." note for the design rationale.
        if action == .attack,
           sprite.action(forKey: SoldierAnimationKey.attack) != nil {
            return
        }

        #if DEBUG
        switch action {
        case .attack:
            recentSoldierAttackAnimationCount += 1
        case .hit:
            recentSoldierHitAnimationCount += 1
        case .walk:
            break
        }
        #endif

        let key: String
        switch action {
        case .walk:
            key = SoldierAnimationKey.walk
        case .attack:
            key = SoldierAnimationKey.attack
        case .hit:
            key = SoldierAnimationKey.hit
        }

        // Remove every transient soldier-animation key before installing the new
        // one. A soldier can both land a city attack and be hit by a tower in the
        // same tick; if we only removed `walk` + the current key, the other
        // transient animate-action would keep running concurrently and the two
        // SKAction.animate streams would fight over `sprite.texture` every frame.
        sprite.removeAction(forKey: SoldierAnimationKey.walk)
        sprite.removeAction(forKey: SoldierAnimationKey.attack)
        sprite.removeAction(forKey: SoldierAnimationKey.hit)

        let animate = soldierTextureAction(
            textures: textures,
            action: action,
            type: soldierType,
            sprite: sprite
        )
        let resumeWalk = SKAction.run { [weak self] in
            self?.resumeWalkForSoldierIfNeeded(
                id: soldierID,
                type: soldierType,
                isAllowed: resumesWalk
            )
        }
        sprite.run(SKAction.sequence([animate, resumeWalk]), withKey: key)
    }

    /// Restarts the looping walk animation for a soldier after a transient
    /// (attack/hit) animation finishes, iff the soldier is still alive and the
    /// calling animation was allowed to resume walk. Extracted from
    /// `playSoldierAnimation` so the resume path is unit-testable without
    /// driving the SpriteKit render loop.
    ///
    /// The transient action key is still installed on the sprite when this runs
    /// in production: the `SKAction.run` closure fires as the final step of the
    /// `[animate, resumeWalk]` sequence, which SpriteKit removes only *after*
    /// the closure returns. We therefore clear the transient keys here before
    /// starting walk — otherwise `startSoldierWalkAnimation`'s guard would bail
    /// and walk would never resume from the closure (it would only resume on
    /// the next `syncSoldierNodes` tick).
    private func resumeWalkForSoldierIfNeeded(
        id: BattleCombatState.SoldierID,
        type: SoldierType,
        isAllowed: Bool
    ) {
        guard isAllowed, combat.soldier(id: id)?.isAlive == true else {
            return
        }
        if let sprite = soldierNodes[id]?.body as? SKSpriteNode {
            sprite.removeAction(forKey: SoldierAnimationKey.attack)
            sprite.removeAction(forKey: SoldierAnimationKey.hit)
        }
        startSoldierWalkAnimation(for: id, type: type)
    }

    private func scheduleDelayedSoldierRemoval(for soldierID: BattleCombatState.SoldierID) {
        guard let bundle = soldierNodes[soldierID] else {
            return
        }

        pendingAnimatedRemovalSoldierIDs.insert(soldierID)
        bundle.root.removeAction(forKey: SoldierAnimationKey.delayedRemoval)

        // Match the full hit animation duration so killed soldiers finish the
        // authored hit cycle before fading out.
        let duration = SoldierAnimationTiming.totalDuration(for: .hit, type: bundle.type)
        let wait = SKAction.wait(forDuration: duration)
        let remove = SKAction.run { [weak self] in
            self?.removeSoldierNode(id: soldierID, animated: true)
        }
        bundle.root.run(SKAction.sequence([wait, remove]), withKey: SoldierAnimationKey.delayedRemoval)
    }

    private func cancelCityFeedbackActions() {
        guard let enemyCityNode else {
            return
        }

        enemyCityNode.removeAction(forKey: "cityConquestFeedback")
        enemyCityNode.removeAction(forKey: "cityHitFeedback")

        if let sprite = enemyCityNode as? SKSpriteNode {
            sprite.colorBlendFactor = 0
            sprite.color = .clear
        }
    }

    private func cityShakeAction() -> SKAction {
        SKAction.sequence([
            SKAction.moveBy(x: -5, y: 0, duration: 0.03),
            SKAction.moveBy(x: 10, y: 0, duration: 0.05),
            SKAction.moveBy(x: -8, y: 0, duration: 0.04),
            SKAction.moveBy(x: 3, y: 0, duration: 0.03)
        ])
    }

    private func observeLifecycleNotificationsIfNeeded() {
        guard !isObservingLifecycle else {
            return
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sceneDidEnterBackground),
            name: .pyxisSceneDidEnterBackground,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sceneWillEnterForeground),
            name: .pyxisSceneWillEnterForeground,
            object: nil
        )
        isObservingLifecycle = true
    }

    @objc private func sceneDidEnterBackground(_ notification: Notification) {
        state.enterBackground(at: Date())
        store.save(state)
        clearLiveCombat()
    }

    @objc private func sceneWillEnterForeground(_ notification: Notification) {
        let result = state.returnFromBackground(at: Date())

        store.save(state)
        reconcileSelectedManualSoldierType()

        if result.elapsedSeconds > 0 {
            if result.conqueredCities > 0 {
                clearLiveCombat()
                // The conquest popup communicates the result; clear any stale
                // feedback so the tooltip doesn't present behind the overlay and
                // linger after the popup closes. Mirrors the live-combat conquest
                // path. Clearing (rather than just not setting) also covers a
                // stale message left over from before backgrounding.
                feedbackText = ""
            } else if result.damageDealt > 0 {
                feedbackText = "Buildings dealt \(compactNumber(result.damageDealt)) idle damage."
            } else {
                feedbackText = "No building damage while away."
            }
        }

        redraw()

        if result.conqueredCities > 0 {
            showConquestPopup(goldEarned: result.goldEarned)
        }
    }

    private func buttonName(at point: CGPoint) -> String? {
        let priority = manualSpawnableSoldierTypes.map { manualTypeButtonName(for: $0) } + [
            ButtonName.manualType,
            ButtonName.spawn,
            ButtonName.world,
            ButtonName.build,
            ButtonName.goldInfo,
            ButtonName.cityInfo,
            ButtonName.popupContinue
        ]
        let touchedNames = Set(nodes(at: point).compactMap(\.name))
        for name in priority where touchedNames.contains(name) {
            return name
        }

        return nil
    }

    private func fitLabel(_ label: SKLabelNode, maxWidth: CGFloat) {
        guard maxWidth > 0 else {
            return
        }

        while label.frame.width > maxWidth && label.fontSize > 8 {
            label.fontSize -= 1
        }
    }

    private func compactNumber(_ value: Int) -> String {
        let absValue = abs(value)
        let sign = value < 0 ? "-" : ""

        let units: [(threshold: Int, suffix: String)] = [
            (1_000_000_000_000, "T"),
            (1_000_000_000, "B"),
            (1_000_000, "M"),
            (1_000, "K")
        ]

        guard let unitIndex = units.firstIndex(where: { absValue >= $0.threshold }) else {
            return "\(value)"
        }

        let unit = units[unitIndex]
        let scaled = Double(absValue) / Double(unit.threshold)
        let roundedTenths = (scaled * 10).rounded() / 10

        // Promote when integer rounding would produce "1000" in the current unit
        let integerRounded = roundedTenths.rounded()
        if integerRounded >= 1000, unitIndex > 0 {
            let promotedUnit = units[unitIndex - 1]
            let promotedScaled = Double(absValue) / Double(promotedUnit.threshold)
            let promotedRounded = (promotedScaled * 10).rounded() / 10
            let body = promotedRounded >= 10 || promotedRounded.rounded() == promotedRounded
                ? String(format: "%.0f", promotedRounded)
                : String(format: "%.1f", promotedRounded)
            return "\(sign)\(body)\(promotedUnit.suffix)"
        }

        let body = roundedTenths >= 10 || roundedTenths.rounded() == roundedTenths
            ? String(format: "%.0f", roundedTenths)
            : String(format: "%.1f", roundedTenths)
        return "\(sign)\(body)\(unit.suffix)"
    }

    private func layoutConquestPopup(contentWidth: CGFloat) {
        let popupWidth = min(contentWidth, size.width - 56)
        let popupHeight: CGFloat = 188
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        popupOverlay.path = CGPath(
            roundedRect: CGRect(x: -popupWidth / 2, y: -popupHeight / 2, width: popupWidth, height: popupHeight),
            cornerWidth: 14,
            cornerHeight: 14,
            transform: nil
        )
        popupOverlay.position = center
        popupTitleLabel.position = CGPoint(x: center.x, y: center.y + 52)
        popupRewardLabel.position = CGPoint(x: center.x, y: center.y + 12)
        layoutButton(
            popupContinueButton,
            background: popupContinueBackground,
            size: CGSize(width: popupWidth - 48, height: 48),
            position: CGPoint(x: center.x, y: center.y - 54)
        )
    }

    private func showConquestPopup(goldEarned: Int) {
        isConquestPopupVisible = true
        popupTitleLabel.text = state.stageStatus == .countryComplete
            ? "Country \(state.countryNumber) Conquered"
            : "\(state.displayCityTitle) Conquered"
        popupRewardLabel.text = "+\(goldEarned) gold"
        popupContinueLabel.text = "Continue"
        setConquestPopupHidden(false)
        layoutInterface()
        playGoldBurst(goldEarned: goldEarned)
    }

    private func playGoldBurst(goldEarned _: Int) {
        goldBurstRemovalTask?.cancel()
        childNode(withName: EffectName.goldBurst)?.removeFromParent()
        isGoldBurstRemovalScheduled = false

        let burst = SKNode()
        burst.name = EffectName.goldBurst
        burst.position = CGPoint(x: popupRewardLabel.position.x, y: popupRewardLabel.position.y + 10)
        burst.zPosition = EffectStyle.goldBurstZ
        addChild(burst)

        if UIImage(named: BattleAssetName.goldBurst) != nil {
            let sprite = SKSpriteNode(imageNamed: BattleAssetName.goldBurst)
            sprite.size = CGSize(width: 120, height: 120)
            sprite.zPosition = EffectStyle.goldBurstSparkleZ
            sprite.alpha = 0.72
            burst.addChild(sprite)
        }

        for index in 0..<6 {
            let sparkle = SKShapeNode(circleOfRadius: 3)
            sparkle.fillColor = GameUITheme.Color.gold
            sparkle.strokeColor = .clear
            sparkle.position = .zero
            sparkle.zPosition = EffectStyle.goldBurstSparkleZ
            burst.addChild(sparkle)

            let angle = CGFloat(index) * (.pi * 2 / 6)
            let distance: CGFloat = 30
            let destination = CGPoint(x: cos(angle) * distance, y: sin(angle) * distance)
            let move = SKAction.move(to: destination, duration: 0.32)
            move.timingMode = .easeOut
            let fade = SKAction.fadeOut(withDuration: 0.32)
            sparkle.run(SKAction.group([move, fade]))
        }

        let scale = SKAction.scale(to: 1.12, duration: 0.12)
        scale.timingMode = .easeOut
        let settle = SKAction.scale(to: 1.0, duration: 0.12)
        settle.timingMode = .easeIn
        let wait = SKAction.wait(forDuration: 0.18)
        let fade = SKAction.fadeOut(withDuration: 0.18)
        let markComplete = SKAction.run { [weak self, weak burst] in
            guard let self, let burst, self.childNode(withName: EffectName.goldBurst) === burst else {
                return
            }
            self.isGoldBurstRemovalScheduled = false
        }
        let remove = SKAction.removeFromParent()
        isGoldBurstRemovalScheduled = true
        burst.run(SKAction.sequence([scale, settle, wait, fade, markComplete, remove]), withKey: EffectName.goldBurst)

        goldBurstRemovalTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: EffectStyle.goldBurstRemovalDelayNanoseconds)
            guard !Task.isCancelled, let self else {
                return
            }

            self.childNode(withName: EffectName.goldBurst)?.removeFromParent()
            self.isGoldBurstRemovalScheduled = false
            self.goldBurstRemovalTask = nil
        }
    }

    private func setConquestPopupHidden(_ isHidden: Bool) {
        popupOverlay.isHidden = isHidden
        popupTitleLabel.isHidden = isHidden
        popupRewardLabel.isHidden = isHidden
        popupContinueButton.isHidden = isHidden
    }

    private func closeConquestPopup() {
        guard isConquestPopupVisible else {
            return
        }
        guard let router else {
            return
        }

        isConquestPopupVisible = false
        setConquestPopupHidden(true)
        router.battleSceneDidRequestCountryMap(self)
    }
}

#if DEBUG
extension BattleScene {
    struct BattleLayoutFrames {
        let leftHUD: CGRect
        let rightHUD: CGRect
        let battlefield: CGRect
        let feedback: CGRect
        let feedbackPanel: CGRect
        let spawnButton: CGRect
        let spawnButtonBackground: CGRect
        let worldButton: CGRect
        let worldButtonBackground: CGRect
        let buildButton: CGRect
        let buildButtonBackground: CGRect
        let manualTypeButton: CGRect
        let manualTypeButtonBackground: CGRect
        let manualTypeMenuButtons: [SoldierType: CGRect]
        let goldLabel: CGRect
        let defenseTraitLabel: CGRect
        let cityLevelLabel: CGRect
        let cityHPLabel: CGRect
        let cityHPBar: CGRect
        let spawnButtonLabel: CGRect
        let worldButtonLabel: CGRect
        let buildButtonLabel: CGRect
        let liveCombatStatus: CGRect
    }

    var battleLayoutFramesForTesting: BattleLayoutFrames? {
        guard
            let leftHUD = sceneFrame(for: leftHUDPanel),
            let rightHUD = sceneFrame(for: rightHUDPanel),
            let feedback = sceneFrame(for: feedbackLabel),
            let feedbackPanel = sceneFrame(for: feedbackPanel),
            let spawnFrame = sceneFrame(for: spawnButton),
            let spawnBackgroundFrame = sceneFrame(for: spawnButtonBackground),
            let worldFrame = sceneFrame(for: worldButton),
            let worldBackgroundFrame = sceneFrame(for: worldButtonBackground),
            let buildFrame = sceneFrame(for: buildButton),
            let buildBackgroundFrame = sceneFrame(for: buildButtonBackground),
            let manualTypeFrame = sceneFrame(for: manualTypeButton),
            let manualTypeBackgroundFrame = sceneFrame(for: manualTypeButtonBackground),
            let goldFrame = sceneFrame(for: goldLabel),
            let defenseTraitFrame = sceneFrame(for: defenseTraitLabel),
            let cityLevelFrame = sceneFrame(for: cityLevelLabel),
            let cityHPFrame = sceneFrame(for: cityHPLabel),
            let cityHPBarFrame = sceneFrame(for: cityHPBarBackground),
            let spawnLabelFrame = sceneFrame(for: spawnButtonLabel),
            let worldLabelFrame = sceneFrame(for: worldButtonLabel),
            let buildLabelFrame = sceneFrame(for: buildButtonLabel),
            let liveCombatStatusFrame = sceneFrame(for: liveCombatStatusLabel)
        else {
            return nil
        }

        let menuButtonFrames = manualTypeButtonBundles.reduce(into: [SoldierType: CGRect]()) { frames, element in
            guard !element.value.button.isHidden, let frame = sceneFrame(for: element.value.button) else {
                return
            }
            frames[element.key] = frame
        }

        let battlefieldFrame = battlefieldLayout.frame
        return BattleLayoutFrames(
            leftHUD: leftHUD,
            rightHUD: rightHUD,
            battlefield: battlefieldFrame,
            feedback: feedback,
            feedbackPanel: feedbackPanel,
            spawnButton: spawnFrame,
            spawnButtonBackground: spawnBackgroundFrame,
            worldButton: worldFrame,
            worldButtonBackground: worldBackgroundFrame,
            buildButton: buildFrame,
            buildButtonBackground: buildBackgroundFrame,
            manualTypeButton: manualTypeFrame,
            manualTypeButtonBackground: manualTypeBackgroundFrame,
            manualTypeMenuButtons: menuButtonFrames,
            goldLabel: goldFrame,
            defenseTraitLabel: defenseTraitFrame,
            cityLevelLabel: cityLevelFrame,
            cityHPLabel: cityHPFrame,
            cityHPBar: cityHPBarFrame,
            spawnButtonLabel: spawnLabelFrame,
            worldButtonLabel: worldLabelFrame,
            buildButtonLabel: buildLabelFrame,
            liveCombatStatus: liveCombatStatusFrame
        )
    }

    var feedbackTextForTesting: String {
        feedbackText
    }

    /// Injects a feedback message without driving the tooltip pipeline, so tests
    /// can reproduce the post-fade stale state (a prior message left in
    /// `feedbackText` after its tooltip has faded and reset the dedupe token).
    func setFeedbackTextForTesting(_ text: String) {
        feedbackText = text
    }

    var defenseTraitTextForTesting: String? {
        defenseTraitLabel.text
    }

    var isUpgradeButtonVisibleForTesting: Bool {
        false
    }

    var manualSpawnableSoldierTypesForTesting: [SoldierType] {
        manualSpawnableSoldierTypes
    }

    var liveSoldierCountForTesting: Int {
        combat.livingSoldierCount
    }

    var selectedManualSoldierTypeForTesting: SoldierType {
        selectedManualSoldierType
    }

    var manualLiveSoldierCountForTesting: Int {
        combat.livingSoldierCount(source: .manual)
    }

    var buildingLiveSoldierCountForTesting: Int {
        combat.livingSoldierCount(source: .building)
    }

    var combatLaneDamageMultipliersForTesting: [BattleLane: Double] {
        combat.configuration.laneDamageMultipliers
    }

    var enemyCityFrameForTesting: CGRect? {
        enemyCityNode.map { $0.calculateAccumulatedFrame() }
    }

    var playerCastleFrameForTesting: CGRect? {
        playerCastleNode.map { $0.calculateAccumulatedFrame() }
    }

    var battlefieldBackdropFrameForTesting: CGRect? {
        battlefieldBackdropNode?.calculateAccumulatedFrame()
    }

    var laneCenterXsForTesting: [CGFloat] {
        BattleLane.allCases.compactMap { battlefieldLayout.enemyGatePoints[$0]?.x }
    }

    func castleGatePointForTesting(lane: BattleLane) -> CGPoint? {
        battlefieldLayout.castleGatePoints[lane]
    }

    func enemyGatePointForTesting(lane: BattleLane) -> CGPoint? {
        battlefieldLayout.enemyGatePoints[lane]
    }

    var laneIndicatorsForTesting: [(role: LaneDefenseRole, position: CGPoint)] {
        laneIndicatorNodes.compactMap { node in
            guard let name = node.name,
                  name.hasPrefix("laneIndicator-"),
                  let role = LaneDefenseRole(rawValue: String(name.dropFirst("laneIndicator-".count)))
            else {
                return nil
            }
            return (role: role, position: node.position)
        }
    }

    var soldierLanePlacementsForTesting: [(lane: BattleLane, nodePosition: CGPoint)] {
        combat.soldiers.filter(\.isAlive).compactMap { soldier in
            soldierNodes[soldier.id].map { (lane: soldier.lane, nodePosition: $0.root.position) }
        }
    }

    var liveSoldierTypesForTesting: [SoldierType] {
        combat.soldiers.filter(\.isAlive).map(\.type)
    }

    var liveSoldierLevelsForTesting: [Int] {
        combat.soldiers.filter(\.isAlive).map(\.level)
    }

    var liveSoldierAttackPowersForTesting: [Int] {
        combat.soldiers.filter(\.isAlive).map(\.attackPower)
    }

    var firstLiveSoldierHPBarFrameForTesting: CGRect? {
        guard let soldierID = firstLiveSoldierIDForTesting,
              let bundle = soldierNodes[soldierID] else {
            return nil
        }

        return sceneFrame(for: bundle.hpBarBackground)
    }

    var firstLiveSoldierBodyFrameForTesting: CGRect? {
        guard let soldierID = firstLiveSoldierIDForTesting,
              let bundle = soldierNodes[soldierID] else {
            return nil
        }

        return sceneFrame(for: bundle.body)
    }

    /// Returns the first live soldier's body as an `SKSpriteNode` for tests
    /// that need to sample texture/size across animation frames. Returns nil
    /// when the body is the static `SKShapeNode` fallback or no live soldier
    /// exists.
    var firstLiveSoldierBodySpriteForTesting: SKSpriteNode? {
        guard let soldierID = firstLiveSoldierIDForTesting,
              let bundle = soldierNodes[soldierID] else {
            return nil
        }
        return bundle.body as? SKSpriteNode
    }

    var firstLiveSoldierTowerShotTargetForTesting: CGPoint? {
        guard let soldierID = firstLiveSoldierIDForTesting,
              let bundle = soldierNodes[soldierID] else {
            return nil
        }

        return towerShotTargetPoint(for: bundle)
    }

    var firstLiveSoldierBodyNameForTesting: String? {
        guard let soldierID = firstLiveSoldierIDForTesting,
              let bundle = soldierNodes[soldierID] else {
            return nil
        }

        return bundle.body.name
    }

    var soldierTargetHeightForTesting: CGFloat {
        soldierTargetHeight()
    }

    var soldierFormationMaximumLateralOffsetForTesting: CGFloat {
        soldierTargetHeight() * SoldierFormation.lateralSpacingScale
    }

    func soldierAnimationFrameDurationsForTesting(
        action: String,
        soldierType: SoldierType = .infantry
    ) -> [TimeInterval] {
        guard let action = SoldierAnimationAction(rawValue: action) else { return [] }
        return SoldierAnimationTiming.frameDurations(for: action, type: soldierType)
    }

    func soldierAnimationDurationForTesting(
        action: String,
        soldierType: SoldierType = .infantry
    ) -> TimeInterval {
        guard let action = SoldierAnimationAction(rawValue: action) else {
            return 0
        }

        return SoldierAnimationTiming.totalDuration(for: action, type: soldierType)
    }

    func soldierDelayedRemovalWaitDurationForTesting(soldierType: SoldierType) -> TimeInterval {
        SoldierAnimationTiming.totalDuration(for: .hit, type: soldierType)
    }

    /// Deterministic resolution of "the first live soldier" for test accessors.
    /// Uses the combat roster (stable ordering) instead of `soldierNodes.first`
    /// (Dictionary, non-deterministic across hash seeds) so tests stay
    /// reproducible as the suite grows beyond a single soldier.
    private var firstLiveSoldierIDForTesting: BattleCombatState.SoldierID? {
        combat.soldiers.first(where: \.isAlive)?.id
    }

    func triggerFirstLiveSoldierAnimationForTesting(_ rawAction: String) {
        guard let soldierID = firstLiveSoldierIDForTesting,
              let action = SoldierAnimationAction(rawValue: rawAction) else {
            return
        }
        playSoldierAnimation(action, for: soldierID, resumesWalk: true)
    }

    func firstLiveSoldierHasActionForTesting(_ key: String) -> Bool {
        guard let soldierID = firstLiveSoldierIDForTesting,
              let bundle = soldierNodes[soldierID] else {
            return false
        }

        return bundle.body.action(forKey: key) != nil
            || bundle.root.action(forKey: key) != nil
    }

    func anyVisibleSoldierHasActionForTesting(_ key: String) -> Bool {
        soldierNodes.values.contains { bundle in
            bundle.body.action(forKey: key) != nil
                || bundle.root.action(forKey: key) != nil
        }
    }

    /// Simulates the SpriteKit render loop completing the first live soldier's
    /// current transient (attack/hit) animation by invoking the same
    /// resume-walk path the `SKAction.run` closure fires on the real render
    /// loop. Crucially, this does NOT pre-clear the transient action key — in
    /// production the closure runs as the final step of the keyed sequence, so
    /// the key is still installed when `resumeWalkForSoldierIfNeeded` enters.
    /// `resumeWalkForSoldierIfNeeded` is responsible for clearing it. Lets tests
    /// verify the spec's "resume walk after attack/hit" contract without
    /// driving SKAction time, while exercising the real production ordering.
    ///
    /// `isAllowed` mirrors the `resumesWalk` flag the production path passes
    /// to `resumeWalkForSoldierIfNeeded` (`true` for attacks, `!schedulesRemoval`
    /// for hits). It defaults to `true` for the positive-case tests and can be
    /// set to `false` to exercise the guard's negative branch.
    func completeFirstLiveSoldierTransientAnimationForTesting(isAllowed: Bool = true) {
        guard let soldierID = firstLiveSoldierIDForTesting,
              let bundle = soldierNodes[soldierID] else {
            return
        }
        resumeWalkForSoldierIfNeeded(id: soldierID, type: bundle.type, isAllowed: isAllowed)
    }

    var recentSoldierAttackAnimationCountForTesting: Int {
        recentSoldierAttackAnimationCount
    }

    var recentSoldierHitAnimationCountForTesting: Int {
        recentSoldierHitAnimationCount
    }

    func firstLiveSoldierVisualMatchesForTesting(_ type: SoldierType) -> Bool {
        guard
            let soldier = combat.soldiers.first(where: \.isAlive),
            let bundle = soldierNodes[soldier.id]
        else {
            return false
        }

        let preferredAssetName = soldierAssetName(for: type)
        if bundle.body.name == preferredAssetName {
            return true
        }

        return colorsMatch(soldierBodyColor(bundle.body), soldierVisualColor(for: type))
    }

    var isCityConquestFeedbackRunningForTesting: Bool {
        enemyCityNode?.action(forKey: "cityConquestFeedback") != nil
    }

    var floatingFeedbackCountForTesting: Int {
        effectsLayer.children.filter { $0.name == EffectName.floatingFeedback }.count
    }

    var impactEffectScalesForTesting: [(x: CGFloat, y: CGFloat)] {
        effectsLayer.children
            .filter { $0.zPosition == GameUITheme.Z.effects }
            .map { (x: $0.xScale, y: $0.yScale) }
    }

    var battlefieldLayoutCountForTesting: Int {
        battlefieldLayoutCount
    }

    var isGoldBurstVisibleForTesting: Bool {
        childNode(withName: EffectName.goldBurst) != nil
    }

    var isGoldBurstRemovalScheduledForTesting: Bool {
        isGoldBurstRemovalScheduled
    }

    var goldBurstZPositionForTesting: CGFloat {
        childNode(withName: EffectName.goldBurst)?.zPosition ?? -.greatestFiniteMagnitude
    }

    var popupRewardZPositionForTesting: CGFloat {
        popupRewardLabel.zPosition
    }

    var goldBurstContainsRewardTextForTesting: Bool {
        guard let goldBurst = childNode(withName: EffectName.goldBurst) else {
            return false
        }

        return containsLabelWithText(in: goldBurst, text: popupRewardLabel.text)
    }

    var cityRemainingPowerForTesting: Int {
        state.cityRemainingPower
    }

    var cityLevelForTesting: Int {
        state.cityLevel
    }

    var goldForTesting: Int {
        state.gold
    }

    var cityTitleTextForTesting: String? {
        cityLevelLabel.text
    }

    var liveCombatStatusTextForTesting: String? {
        liveCombatStatusLabel.text
    }

    var isConquestPopupVisibleForTesting: Bool {
        isConquestPopupVisible
    }

    /// True when the feedback tooltip panel is currently shown (alpha > 0).
    /// A fresh scene presents no tooltip, so this starts false.
    var isFeedbackTooltipVisibleForTesting: Bool {
        feedbackPanel.alpha > 0.01
    }

    /// The current tooltip dedupe token. Tests use this to verify that an
    /// identical feedback message re-triggers the tooltip after the fade-out
    /// completion resets the token.
    var lastPresentedTooltipTextForTesting: String {
        lastPresentedTooltipText
    }

    /// Simulates the tooltip fade-out `SKAction` completing, clearing the
    /// dedupe token so a repeated identical message can re-trigger the tooltip.
    /// Tests can't drive `SKAction` time without a render loop, so this invokes
    /// the same production reset path the action's `run` block calls.
    func completeFeedbackTooltipFadeOutForTesting() {
        resetFeedbackTooltipDedupeToken()
    }

    /// True when the city HP bar fill is hidden because `cityRemainingPower`
    /// has reached 0 (the fill path is nulled to avoid rendering a sliver).
    var isCityHPBarFillHiddenForTesting: Bool {
        cityHPBarFill.path == nil
    }

    /// Number of times `layoutCityHPBar` has run since scene creation. Tests
    /// use this to verify `redraw(shouldLayout: true)` invokes it exactly once
    /// (via `layoutInterface`) rather than twice (a discarded first pass).
    var layoutCityHPBarCallCountForTesting: Int {
        layoutCityHPBarCallCount
    }

    /// Drives `redraw` with an explicit `shouldLayout` flag so tests can verify
    /// the HP bar layout count under each path.
    func redrawForTesting(shouldLayout: Bool) {
        redraw(shouldLayout: shouldLayout)
    }

    func spawnSoldierForTesting() {
        spawnSoldier()
    }

    func selectManualSoldierTypeForTesting(_ type: SoldierType) {
        selectManualSoldierType(type)
    }

    func animationFrameNamesForTesting(soldierType: SoldierType, action: String) -> [String] {
        guard let action = SoldierAnimationAction(rawValue: action) else {
            return []
        }
        return soldierAnimationFrameNames(for: soldierType, action: action)
    }

    /// Returns the (cached) `[SKTexture]` for `soldierType`/`action`. Exposed so
    /// tests can verify the cache memoizes — repeated calls must return the same
    /// `SKTexture` instances rather than re-allocating from `UIImage(named:)`.
    func cachedSoldierAnimationTexturesForTesting(soldierType: SoldierType, action: String) -> [SKTexture] {
        guard let action = SoldierAnimationAction(rawValue: action) else {
            return []
        }
        return soldierAnimationTextures(for: soldierType, action: action)
    }

    /// Number of (type, action) entries currently held in the texture cache.
    var soldierAnimationTextureCacheEntryCountForTesting: Int {
        soldierAnimationTextureCache.values.reduce(0) { $0 + $1.count }
    }

    /// Returns the cached HUD icon texture for `soldierType`. Exposed so tests
    /// can verify the cache memoizes — repeated calls must return the same
    /// `SKTexture` instance rather than re-allocating from `UIImage(named:)`.
    func cachedSoldierHUDIconTextureForTesting(soldierType: SoldierType) -> SKTexture {
        soldierHUDIconTexture(for: soldierType)
    }

    /// Number of type entries currently held in the HUD icon texture cache.
    var soldierHUDIconTextureCacheEntryCountForTesting: Int {
        soldierHUDIconTextureCache.count
    }

    /// IDs of soldiers awaiting animated removal after a tower kill. Exposed so
    /// tests can verify the death-flow scheduler fires for killed soldiers.
    var pendingAnimatedRemovalSoldierIDsForTesting: Set<BattleCombatState.SoldierID> {
        pendingAnimatedRemovalSoldierIDs
    }

    func openManualTypeMenuForTesting() {
        isManualTypeMenuOpen = true
        redraw(shouldLayout: false)
    }

    func toggleManualTypeMenuForTesting() {
        toggleManualTypeMenu()
    }

    var isManualTypeMenuOpenForTesting: Bool {
        isManualTypeMenuOpen
    }

    func requestBuildingViewForTesting() {
        requestBuildingView()
    }

    func requestCountryMapForTesting() {
        requestCountryMap()
    }

    func advanceCombatForTesting(deltaTime: TimeInterval) {
        var remaining = max(0, deltaTime)

        while remaining > 0 {
            let step = min(remaining, 0.1)
            advanceCombat(deltaTime: step)
            remaining -= step
        }
    }

    func closeConquestPopupForTesting() {
        closeConquestPopup()
    }

    /// Presents the conquest popup without requiring a live conquest, so tests
    /// can verify HUD interactions are gated while the popup is overlaying.
    func presentConquestPopupForTesting(goldEarned: Int = 0) {
        showConquestPopup(goldEarned: goldEarned)
    }

    /// Drives the info-button touch path. Returns whether an info tooltip was
    /// presented (true) or suppressed (false, e.g. while the conquest popup is
    /// visible).
    @discardableResult
    func handleInfoButtonForTesting(named buttonName: String) -> Bool {
        handleInfoButton(named: buttonName)
    }

    var goldInfoButtonNameForTesting: String { ButtonName.goldInfo }
    var cityInfoButtonNameForTesting: String { ButtonName.cityInfo }

    func flushBuildingProgressSaveForTesting() {
        buildingProgressSaveAccumulator = 0
        store.save(state)
    }

    func compactNumberForTesting(_ value: Int) -> String {
        compactNumber(value)
    }

    var popupContinueButtonFrameForTesting: CGRect? {
        sceneFrame(for: popupContinueButton)
    }

    private func sceneFrame(for node: SKNode) -> CGRect? {
        guard let parent = node.parent else {
            return nil
        }

        let frame = node.calculateAccumulatedFrame()
        let points = [
            CGPoint(x: frame.minX, y: frame.minY),
            CGPoint(x: frame.maxX, y: frame.minY),
            CGPoint(x: frame.minX, y: frame.maxY),
            CGPoint(x: frame.maxX, y: frame.maxY)
        ].map { parent.convert($0, to: self) }

        guard
            let minX = points.map(\.x).min(),
            let maxX = points.map(\.x).max(),
            let minY = points.map(\.y).min(),
            let maxY = points.map(\.y).max()
        else {
            return nil
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func containsLabelWithText(in node: SKNode, text: String?) -> Bool {
        if let label = node as? SKLabelNode, label.text == text {
            return true
        }

        return node.children.contains { containsLabelWithText(in: $0, text: text) }
    }

    private func soldierBodyColor(_ node: SKNode) -> SKColor {
        if let sprite = node as? SKSpriteNode {
            return sprite.color
        }
        if let shape = node as? SKShapeNode {
            return shape.fillColor
        }
        return .clear
    }

    private func colorsMatch(_ lhs: SKColor, _ rhs: SKColor) -> Bool {
        var lhsRed: CGFloat = 0
        var lhsGreen: CGFloat = 0
        var lhsBlue: CGFloat = 0
        var lhsAlpha: CGFloat = 0
        var rhsRed: CGFloat = 0
        var rhsGreen: CGFloat = 0
        var rhsBlue: CGFloat = 0
        var rhsAlpha: CGFloat = 0

        lhs.getRed(&lhsRed, green: &lhsGreen, blue: &lhsBlue, alpha: &lhsAlpha)
        rhs.getRed(&rhsRed, green: &rhsGreen, blue: &rhsBlue, alpha: &rhsAlpha)

        return abs(lhsRed - rhsRed) < 0.001
            && abs(lhsGreen - rhsGreen) < 0.001
            && abs(lhsBlue - rhsBlue) < 0.001
            && abs(lhsAlpha - rhsAlpha) < 0.001
    }
}
#endif
