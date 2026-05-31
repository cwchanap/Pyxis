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
        static let battlefieldBackdrop = "battlefield-backdrop"
        static let hitFlash = "hit-flash"
        static let towerProjectile = "tower-projectile"
        static let goldBurst = "gold-burst"
    }

    private enum ButtonName {
        static let spawn = "spawnSoldierButton"
        static let manualType = "manualType"
        static let build = "buildButton"
        static let popupContinue = "conquestPopupContinueButton"
    }

    private enum EffectName {
        static let floatingFeedback = "floatingFeedback"
        static let goldBurst = "goldBurst"
    }

    private enum EffectStyle {
        static let floatingFeedbackFontSize: CGFloat = 16
        static let floatingFeedbackZ: CGFloat = 55
        static let goldBurstZ = GameUITheme.Z.modal + 0.5
        static let goldBurstSparkleZ: CGFloat = 0
        static let goldBurstRemovalDelayNanoseconds: UInt64 = 650_000_000
    }

    private struct SoldierNodeBundle {
        let root: SKNode
        let body: SKNode
        let hpBarBackground: SKShapeNode
        let hpBarFill: SKShapeNode
    }

    private struct ManualTypeButtonBundle {
        let button: SKNode
        let background: SKShapeNode
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

    private let battlefieldLayer = SKNode()
    private let environmentLayer = SKNode()
    private let soldierLayer = SKNode()
    private let effectsLayer = SKNode()
    private var playerCastleNode: SKNode?
    private var enemyCityNode: SKNode?
    private var battlefieldBackdropNode: SKSpriteNode?
    private var castleGatePoint = CGPoint.zero
    private var enemyGatePoint = CGPoint.zero
    private var battleGroundLane: SKShapeNode?
    private var battlefieldLayoutFrame = CGRect.zero

    private let goldLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let cityLevelLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let defenseTraitLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let cityHPLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let liveCombatStatusLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let feedbackLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let leftHUDPanel = PanelNode(size: CGSize(width: 160, height: 78))
    private let rightHUDPanel = PanelNode(size: CGSize(width: 190, height: 86))
    private let feedbackPanel = PanelNode(size: CGSize(width: 260, height: 34))
    private let cityHPBarNode = ProgressBarNode(size: CGSize(width: 160, height: 12))
    private let manualTypeButton = SKNode()
    private let manualTypeButtonBackground = SKShapeNode()
    private let manualTypeButtonLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private var manualTypeButtonBundles: [SoldierType: ManualTypeButtonBundle] = [:]
    private let spawnButton = SKNode()
    private let spawnButtonBackground = SKShapeNode()
    private let spawnButtonLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let buildButton = SKNode()
    private let buildButtonBackground = SKShapeNode()
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

    private var feedbackText = "Tap Spawn Soldier to attack the city."
    private var currentLeftHUDLabelWidth: CGFloat = 140
    private var buildingProgressSaveAccumulator: TimeInterval = 0
    private static let buildingProgressSaveInterval: TimeInterval = 2.0

    init(size: CGSize, store: KingdomGameStore = .shared, router: BattleSceneRouting? = nil) {
        let loadedState = store.load()
        self.store = store
        self.state = loadedState
        self.combat = BattleCombatState(cityLevel: loadedState.cityLevel)
        self.router = router
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        let loadedState = KingdomGameStore.shared.load()
        self.store = .shared
        self.state = loadedState
        self.combat = BattleCombatState(cityLevel: loadedState.cityLevel)
        self.router = nil
        super.init(coder: aDecoder)
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
        layoutInterface()
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

        let touchedButtonName = buttonName(at: touch.location(in: self))
        if let touchedButtonName,
           let soldierType = soldierType(forManualTypeButtonName: touchedButtonName) {
            selectManualSoldierType(soldierType)
            return
        }

        switch touchedButtonName {
        case ButtonName.manualType:
            toggleManualTypeMenu()
        case ButtonName.spawn:
            isManualTypeMenuOpen = false
            spawnSoldier()
        case ButtonName.build:
            isManualTypeMenuOpen = false
            requestBuildingView()
        case ButtonName.popupContinue:
            isManualTypeMenuOpen = false
            closeConquestPopup()
        default:
            if isManualTypeMenuOpen {
                isManualTypeMenuOpen = false
                redraw()
            }
            break
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

        [leftHUDPanel, rightHUDPanel, cityHPBarNode].forEach { $0.zPosition = GameUITheme.Z.hud }
        feedbackPanel.zPosition = GameUITheme.Z.hud - 1
        addChild(leftHUDPanel)
        addChild(rightHUDPanel)
        addChild(feedbackPanel)
        addChild(cityHPBarNode)

        configureLabel(goldLabel, fontSize: 21, color: GameUITheme.Color.gold)
        configureLabel(cityLevelLabel, fontSize: 18, color: GameUITheme.Color.textPrimary)
        configureLabel(defenseTraitLabel, fontSize: 13, color: GameUITheme.Color.textSecondary)
        configureLabel(cityHPLabel, fontSize: 14, color: GameUITheme.Color.textPrimary)
        configureLabel(liveCombatStatusLabel, fontSize: 13, color: GameUITheme.Color.textSecondary)
        configureLabel(feedbackLabel, fontSize: 15, color: GameUITheme.Color.gold)

        configureButton(
            manualTypeButton,
            background: manualTypeButtonBackground,
            label: manualTypeButtonLabel,
            name: ButtonName.manualType,
            color: SKColor(red: 0.24, green: 0.33, blue: 0.38, alpha: 1.0)
        )
        for soldierType in SoldierType.allCases {
            let bundle = ManualTypeButtonBundle(
                button: SKNode(),
                background: SKShapeNode(),
                label: SKLabelNode(fontNamed: "AvenirNext-DemiBold")
            )
            configureButton(
                bundle.button,
                background: bundle.background,
                label: bundle.label,
                name: manualTypeButtonName(for: soldierType),
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
            color: GameUITheme.Color.spawn
        )
        configureButton(
            buildButton,
            background: buildButtonBackground,
            label: buildButtonLabel,
            name: ButtonName.build,
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
        addChild(buildButton)
        addChild(popupOverlay)
        addChild(popupTitleLabel)
        addChild(popupRewardLabel)
        addChild(popupContinueButton)

        setConquestPopupHidden(true)
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

        goldLabel.position = CGPoint(x: leftHUDCenterX, y: hudCenterY + metrics.hudHeight * 0.24)
        liveCombatStatusLabel.position = CGPoint(x: leftHUDCenterX, y: hudCenterY - metrics.hudHeight * 0.24)

        cityLevelLabel.position = CGPoint(x: rightHUDCenterX, y: hudCenterY + metrics.hudHeight * 0.28)
        defenseTraitLabel.position = CGPoint(x: rightHUDCenterX, y: hudCenterY + metrics.hudHeight * 0.06)
        cityHPLabel.position = CGPoint(x: rightHUDCenterX, y: hudCenterY - metrics.hudHeight * 0.16)
        cityHPBarNode.position = CGPoint(x: rightHUDCenterX, y: hudCenterY - metrics.hudHeight * 0.34)
        cityHPBarNode.update(size: CGSize(width: metrics.rightHUDWidth - 26, height: metrics.compactHeight ? 10 : 12))
        let hpPercent = CGFloat(state.cityRemainingPower) / CGFloat(max(1, state.cityMaxPower))
        cityHPBarNode.update(progress: hpPercent)

        let buttonY = metrics.bottomMargin + metrics.buttonHeight / 2
        layoutButton(
            spawnButton,
            background: spawnButtonBackground,
            size: CGSize(width: metrics.spawnButtonWidth, height: metrics.buttonHeight),
            position: CGPoint(x: metrics.horizontalMargin + metrics.spawnButtonWidth / 2, y: buttonY)
        )
        let manualTypeButtonSize = CGSize(
            width: min(metrics.spawnButtonWidth, metrics.compactHeight ? 112 : 128),
            height: metrics.compactHeight ? 28 : 30
        )
        let manualTypeButtonPosition = CGPoint(
            x: spawnButton.position.x,
            y: buttonY + metrics.buttonHeight / 2 + 4 + manualTypeButtonSize.height / 2
        )
        layoutButton(
            manualTypeButton,
            background: manualTypeButtonBackground,
            size: manualTypeButtonSize,
            position: manualTypeButtonPosition
        )
        let manualTypeMenuItemSize = self.manualTypeMenuItemSize(horizontalMargin: metrics.horizontalMargin)
        layoutManualTypeMenu(
            selectorPosition: manualTypeButtonPosition,
            selectorSize: manualTypeButtonSize,
            itemSize: manualTypeMenuItemSize,
            horizontalMargin: metrics.horizontalMargin
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

        let hudBottomY = hudCenterY - metrics.hudHeight / 2
        let buttonTopY = buttonY + metrics.buttonHeight / 2
        let feedbackY = buttonTopY + max(32, (hudBottomY - buttonTopY) * 0.25)
        feedbackLabel.position = CGPoint(x: centerX, y: feedbackY)

        layoutConquestPopup(contentWidth: metrics.contentWidth)

        layoutBattlefield(
            contentWidth: metrics.contentWidth,
            hpBarBottomY: hudBottomY,
            spawnButtonTopY: buttonTopY,
            feedbackY: feedbackY
        )

        currentLeftHUDLabelWidth = metrics.leftHUDLabelWidth
        fitLabel(goldLabel, maxWidth: metrics.leftHUDLabelWidth)
        fitLabel(cityLevelLabel, maxWidth: metrics.rightHUDLabelWidth)
        fitLabel(defenseTraitLabel, maxWidth: metrics.rightHUDLabelWidth)
        fitLabel(cityHPLabel, maxWidth: metrics.rightHUDLabelWidth)
        fitLabel(liveCombatStatusLabel, maxWidth: metrics.leftHUDLabelWidth)
        fitLabel(feedbackLabel, maxWidth: metrics.contentWidth)
        fitLabel(manualTypeButtonLabel, maxWidth: manualTypeButtonSize.width - 18)
        for bundle in manualTypeButtonBundles.values {
            fitLabel(bundle.label, maxWidth: manualTypeMenuItemSize.width - 18)
        }
        fitLabel(spawnButtonLabel, maxWidth: metrics.spawnButtonWidth - 28)
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
        liveCombatStatusLabel.fontSize = 13
        feedbackLabel.fontSize = 15
        manualTypeButtonLabel.fontSize = 13
        for bundle in manualTypeButtonBundles.values {
            bundle.label.fontSize = 13
        }
        spawnButtonLabel.fontSize = 16
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
        let buildButtonWidth: CGFloat
        let contentWidth: CGFloat
        let buttonGap: CGFloat

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
        let hudHeight: CGFloat = compactHeight ? 74 : 92
        let safeTopInset = GameUITheme.topUnsafeInset(sceneSize: size, view: view)
        let topMargin = max(
            compactHeight ? 26 : 46,
            safeTopInset + (compactHeight ? 8 : 10) + hudHeight / 2
        )

        let availableButtonWidth = max(0, size.width - horizontalMargin * 2 - buttonGap)
        let buildButtonWidth = min(compactHeight ? 92 : 104, availableButtonWidth * 0.30)
        let spawnButtonWidth = max(0, min(220, availableButtonWidth - buildButtonWidth))
        let contentWidth = min(max(0, size.width - horizontalMargin * 2), 560)

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
            buildButtonWidth: buildButtonWidth,
            contentWidth: contentWidth,
            buttonGap: buttonGap
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

    private func manualTypeMenuItemSize(horizontalMargin: CGFloat) -> CGSize {
        let itemGap: CGFloat = 4
        let minimumItemWidth: CGFloat = 52
        let maximumItemWidth: CGFloat = 88
        let itemCount = max(1, manualSpawnableSoldierTypes.count)
        let availableWidth = max(1, size.width - horizontalMargin * 2)
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
        horizontalMargin: CGFloat
    ) {
        let itemGap: CGFloat = 4
        let visibleTypes = manualSpawnableSoldierTypes
        guard !visibleTypes.isEmpty else {
            return
        }

        if visibleTypes.count <= 2 {
            let selectorMaxX = selectorPosition.x + selectorSize.width / 2
            let availableRowWidth = max(0, size.width - horizontalMargin - selectorMaxX - itemGap)
            let fittedWidth = (
                availableRowWidth - itemGap * CGFloat(max(0, visibleTypes.count - 1))
            ) / CGFloat(visibleTypes.count)

            if fittedWidth >= 52 {
                let rowItemSize = CGSize(width: min(itemSize.width, fittedWidth), height: itemSize.height)
                let firstX = selectorMaxX + itemGap + rowItemSize.width / 2
                let rowY = selectorPosition.y + max(0, (rowItemSize.height - selectorSize.height) / 2) + 2

                for (index, soldierType) in visibleTypes.enumerated() {
                    guard let bundle = manualTypeButtonBundles[soldierType] else {
                        continue
                    }

                    layoutButton(
                        bundle.button,
                        background: bundle.background,
                        size: rowItemSize,
                        position: CGPoint(
                            x: firstX + CGFloat(index) * (rowItemSize.width + itemGap),
                            y: rowY
                        )
                    )
                }
                return
            }
        }

        let availableWidth = max(1, size.width - horizontalMargin * 2)
        let columnCount = max(
            1,
            min(visibleTypes.count, Int((availableWidth + itemGap) / (itemSize.width + itemGap)))
        )
        let rowStartY = selectorPosition.y + selectorSize.height / 2 + itemGap + itemSize.height / 2
        let rowWidth = itemSize.width * CGFloat(columnCount) + itemGap * CGFloat(max(0, columnCount - 1))
        let firstX = size.width / 2 - rowWidth / 2 + itemSize.width / 2

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
        let actualGap = hpBarBottomY - spawnButtonTopY
        let verticalPadding: CGFloat = 8
        let feedbackClearance = max(30, feedbackLabel.fontSize + 18)
        let safeTopY = hpBarBottomY - verticalPadding
        let safeBottomY = max(spawnButtonTopY + verticalPadding, feedbackY + feedbackClearance)
        battlefieldLayoutFrame = CGRect(
            x: (size.width - contentWidth) / 2,
            y: safeBottomY,
            width: contentWidth,
            height: max(0, safeTopY - safeBottomY)
        )
        let availableHeight = safeTopY - safeBottomY
        let tallestStructureHeightMultiplier: CGFloat = 1.04
        let laneHeight = groundLaneHeight()
        let minimumStructureHeight: CGFloat = 28
        let laneY = safeBottomY + laneHeight / 2
        let maxStructureHeight = (safeTopY - laneY) / tallestStructureHeightMultiplier

        if !isConquestPopupVisible {
            cancelCityFeedbackActions()
        }

        guard availableHeight >= 44, maxStructureHeight >= minimumStructureHeight else {
            setBattlefieldHidden(true)
            battleGroundLane?.removeFromParent()
            battleGroundLane = nil
            castleGatePoint = CGPoint(x: size.width * 0.24, y: spawnButtonTopY + max(10, actualGap * 0.25))
            enemyGatePoint = CGPoint(x: size.width * 0.76, y: castleGatePoint.y)
            return
        }

        setBattlefieldHidden(false)

        if let battlefieldBackdropNode {
            battlefieldBackdropNode.position = CGPoint(x: size.width / 2, y: (safeBottomY + safeTopY) / 2)
            let targetSize = CGSize(width: size.width, height: max(1, safeTopY - safeBottomY + 44))
            let scale = max(
                targetSize.width / max(1, battlefieldBackdropNode.size.width),
                targetSize.height / max(1, battlefieldBackdropNode.size.height)
            )
            battlefieldBackdropNode.setScale(scale)
        }

        let targetHeight = min(96, maxStructureHeight, size.height * 0.16, contentWidth * 0.30)

        if let playerCastleNode {
            fitBattleNode(playerCastleNode, targetHeight: targetHeight)
        }
        if let enemyCityNode {
            fitBattleNode(enemyCityNode, targetHeight: targetHeight * tallestStructureHeightMultiplier)
        }

        let horizontalInset = max(24, (size.width - contentWidth) / 2 + 18)
        let castleWidth = playerCastleNode?.calculateAccumulatedFrame().width ?? targetHeight
        let cityWidth = enemyCityNode?.calculateAccumulatedFrame().width ?? targetHeight
        let castleX = horizontalInset + castleWidth / 2
        let enemyX = size.width - horizontalInset - cityWidth / 2
        let gateY = laneY + min(max(8, targetHeight * 0.10), max(0, safeTopY - laneY))

        playerCastleNode?.position = CGPoint(x: castleX, y: laneY)
        enemyCityNode?.position = CGPoint(x: enemyX, y: laneY)
        castleGatePoint = CGPoint(x: castleX + castleWidth * 0.32, y: gateY)
        enemyGatePoint = CGPoint(x: enemyX - cityWidth * 0.34, y: gateY)

        drawGroundLane(from: CGPoint(x: castleX, y: laneY), to: CGPoint(x: enemyX, y: laneY))
        syncSoldierNodes()
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

    private func drawGroundLane(from start: CGPoint, to end: CGPoint) {
        battleGroundLane?.removeFromParent()

        let laneHeight = groundLaneHeight()
        let laneInset: CGFloat = 20
        let minX = min(start.x, end.x) - laneInset
        let maxX = max(start.x, end.x) + laneInset
        let laneRect = CGRect(x: minX, y: start.y - laneHeight / 2, width: maxX - minX, height: laneHeight)
        let lane = SKShapeNode(rect: laneRect, cornerRadius: laneHeight / 2)
        lane.name = "battleGroundLane"
        lane.fillColor = SKColor(red: 0.25, green: 0.34, blue: 0.27, alpha: 1.0)
        lane.strokeColor = SKColor(red: 0.43, green: 0.52, blue: 0.36, alpha: 1.0)
        lane.lineWidth = 2
        lane.zPosition = -1
        environmentLayer.addChild(lane)
        battleGroundLane = lane
    }

    private func groundLaneHeight() -> CGFloat {
        max(14, min(26, size.height * 0.025))
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

    private func redraw() {
        reconcileSelectedManualSoldierType()

        goldLabel.text = "Gold: \(compactNumber(state.gold))"
        cityLevelLabel.text = state.displayCityTitle
        defenseTraitLabel.text = "Trait: \(state.currentCityDefenseTrait.displayName)"
        cityHPLabel.text = "City HP: \(compactNumber(state.cityRemainingPower)) / \(compactNumber(state.cityMaxPower))"
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
        spawnButtonLabel.text = spawnableTypes.isEmpty ? "Build Unit" : "Spawn \(selectedManualSoldierType.displayName)"
        buildButtonLabel.text = "Build"
        layoutInterface()
    }

    private func updateLiveCombatStatusLabel() {
        liveCombatStatusLabel.fontSize = 13
        liveCombatStatusLabel.text = "Soldiers: \(combat.livingSoldierCount)"
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

        for soldierID in result.killedSoldierIDs {
            removeSoldierNode(id: soldierID, animated: true)
        }

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
            feedbackText = "\(state.displayCityTitle) conquered! +\(damageResult.goldEarned) gold."
        } else {
            feedbackText = "Soldiers dealt \(compactNumber(damageResult.damageDealt)) damage."
        }

        store.save(state)
        redraw()

        if conqueredCity {
            playFloatingFeedback(text: "-\(compactNumber(damageResult.damageDealt))", at: enemyGatePoint)
            playCityConquestFeedback()
            showConquestPopup(goldEarned: damageResult.goldEarned)
        } else {
            playFloatingFeedback(text: "-\(compactNumber(damageResult.damageDealt))", at: enemyGatePoint)
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

        isManualTypeMenuOpen.toggle()
        redraw()
    }

    private func selectManualSoldierType(_ type: SoldierType) {
        guard !isConquestPopupVisible, state.stageStatus == .battleActive else {
            return
        }

        guard manualSpawnableSoldierTypes.contains(type) else {
            feedbackText = "Build \(type.displayName) first."
            isManualTypeMenuOpen = false
            redraw()
            return
        }

        selectedManualSoldierType = type
        isManualTypeMenuOpen = false
        redraw()
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

        let root = SKNode()
        root.name = BattleAssetName.normalSoldier

        let body = makeSoldierNode()
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

        root.addChild(hpBackground)
        root.addChild(hpFill)
        soldierLayer.addChild(root)
        soldierNodes[id] = SoldierNodeBundle(root: root, body: body, hpBarBackground: hpBackground, hpBarFill: hpFill)
    }

    private func syncSoldierNodes() {
        let liveSoldiers = combat.soldiers.filter(\.isAlive)
        let liveIDs = Set(liveSoldiers.map(\.id))

        for id in Array(soldierNodes.keys) where !liveIDs.contains(id) {
            removeSoldierNode(id: id, animated: false)
        }

        for soldier in liveSoldiers {
            if soldierNodes[soldier.id] == nil {
                createSoldierNode(id: soldier.id)
            }

            guard let bundle = soldierNodes[soldier.id] else {
                continue
            }

            bundle.root.position = pointForSoldierPosition(soldier.position)
            bundle.root.setScale(1)
            fitBattleNode(bundle.body, targetHeight: max(28, min(42, size.height * 0.05)))
            layoutSoldierHPBar(bundle, soldier: soldier)
        }
    }

    private func pointForSoldierPosition(_ position: Double) -> CGPoint {
        let clamped = CGFloat(min(max(0, position), 1))
        return CGPoint(
            x: castleGatePoint.x + (enemyGatePoint.x - castleGatePoint.x) * clamped,
            y: castleGatePoint.y + (enemyGatePoint.y - castleGatePoint.y) * clamped
        )
    }

    private func layoutSoldierHPBar(_ bundle: SoldierNodeBundle, soldier: BattleCombatState.Soldier) {
        let width: CGFloat = 28
        let height: CGFloat = 5
        let bodyFrame = bundle.body.calculateAccumulatedFrame()
        let y = bodyFrame.maxY + 6
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

    private func clearLiveCombat() {
        combat = BattleCombatState(cityLevel: state.cityLevel)
        lastUpdateTime = nil

        for id in Array(soldierNodes.keys) {
            removeSoldierNode(id: id, animated: false)
        }

        updateLiveCombatStatusLabel()
    }

    private func removeSoldierNode(id: BattleCombatState.SoldierID, animated: Bool) {
        guard let bundle = soldierNodes.removeValue(forKey: id) else {
            return
        }

        bundle.root.removeAllActions()

        if animated {
            let fade = SKAction.fadeOut(withDuration: 0.18)
            let remove = SKAction.removeFromParent()
            bundle.root.run(SKAction.sequence([fade, remove]))
        } else {
            bundle.root.removeFromParent()
        }
    }

    private func makeSoldierNode() -> SKNode {
        let soldier: SKNode

        if UIImage(named: BattleAssetName.normalSoldier) != nil {
            let sprite = SKSpriteNode(imageNamed: BattleAssetName.normalSoldier)
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
            soldier = sprite
        } else {
            let shape = SKShapeNode(rect: CGRect(x: -10, y: 0, width: 20, height: 28), cornerRadius: 5)
            shape.fillColor = SKColor(red: 0.18, green: 0.52, blue: 1.0, alpha: 1.0)
            shape.strokeColor = SKColor(white: 1.0, alpha: 0.4)
            shape.lineWidth = 2
            soldier = shape
        }

        soldier.name = BattleAssetName.normalSoldier
        return soldier
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

        let originalXScale = enemyCityNode.xScale
        let originalYScale = enemyCityNode.yScale
        let pulse = SKAction.scaleX(to: originalXScale * 1.12, y: originalYScale * 1.12, duration: 0.09)
        pulse.timingMode = .easeOut
        let restore = SKAction.scaleX(to: originalXScale, y: originalYScale, duration: 0.14)
        restore.timingMode = .easeIn
        enemyCityNode.run(SKAction.sequence([pulse, restore]), withKey: "cityConquestFeedback")

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
        flash.position = enemyGatePoint
        flash.zPosition = GameUITheme.Z.effects
        flash.setScale(0.4)
        effectsLayer.addChild(flash)

        let expand = SKAction.scale(to: 2.2, duration: 0.22)
        expand.timingMode = .easeOut
        let fade = SKAction.fadeOut(withDuration: 0.22)
        let remove = SKAction.removeFromParent()
        flash.run(SKAction.sequence([SKAction.group([expand, fade]), remove]))
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
        shot.position = enemyGatePoint
        shot.zPosition = GameUITheme.Z.effects
        effectsLayer.addChild(shot)

        let move = SKAction.move(to: bundle.root.position, duration: 0.12)
        let remove = SKAction.removeFromParent()
        shot.run(SKAction.sequence([move, remove]))
    }

    private func playSoldierAttackFeedback(for soldierID: BattleCombatState.SoldierID) {
        guard let bundle = soldierNodes[soldierID] else {
            return
        }

        let lunge = SKAction.moveBy(x: 8, y: 0, duration: 0.06)
        let back = SKAction.moveBy(x: -8, y: 0, duration: 0.08)
        bundle.root.run(SKAction.sequence([lunge, back]), withKey: "soldierAttackFeedback")
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
                feedbackText = "Buildings conquered \(state.displayCityTitle)."
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
            ButtonName.build,
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
        let buildButton: CGRect
        let manualTypeButton: CGRect
        let manualTypeMenuButtons: [SoldierType: CGRect]
        let goldLabel: CGRect
        let defenseTraitLabel: CGRect
        let cityLevelLabel: CGRect
        let cityHPLabel: CGRect
        let spawnButtonLabel: CGRect
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
            let buildFrame = sceneFrame(for: buildButton),
            let manualTypeFrame = sceneFrame(for: manualTypeButton),
            let goldFrame = sceneFrame(for: goldLabel),
            let defenseTraitFrame = sceneFrame(for: defenseTraitLabel),
            let cityLevelFrame = sceneFrame(for: cityLevelLabel),
            let cityHPFrame = sceneFrame(for: cityHPLabel),
            let spawnLabelFrame = sceneFrame(for: spawnButtonLabel),
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

        let battlefieldFrame = battlefieldLayoutFrame
        return BattleLayoutFrames(
            leftHUD: leftHUD,
            rightHUD: rightHUD,
            battlefield: battlefieldFrame,
            feedback: feedback,
            feedbackPanel: feedbackPanel,
            spawnButton: spawnFrame,
            buildButton: buildFrame,
            manualTypeButton: manualTypeFrame,
            manualTypeMenuButtons: menuButtonFrames,
            goldLabel: goldFrame,
            defenseTraitLabel: defenseTraitFrame,
            cityLevelLabel: cityLevelFrame,
            cityHPLabel: cityHPFrame,
            spawnButtonLabel: spawnLabelFrame,
            buildButtonLabel: buildLabelFrame,
            liveCombatStatus: liveCombatStatusFrame
        )
    }

    var feedbackTextForTesting: String {
        feedbackText
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
        guard let bundle = soldierNodes.values.first else {
            return nil
        }

        return sceneFrame(for: bundle.hpBarBackground)
    }

    var firstLiveSoldierBodyFrameForTesting: CGRect? {
        guard let bundle = soldierNodes.values.first else {
            return nil
        }

        return sceneFrame(for: bundle.body)
    }

    var isCityConquestFeedbackRunningForTesting: Bool {
        enemyCityNode?.action(forKey: "cityConquestFeedback") != nil
    }

    var floatingFeedbackCountForTesting: Int {
        effectsLayer.children.filter { $0.name == EffectName.floatingFeedback }.count
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

    func spawnSoldierForTesting() {
        spawnSoldier()
    }

    func selectManualSoldierTypeForTesting(_ type: SoldierType) {
        selectManualSoldierType(type)
    }

    func openManualTypeMenuForTesting() {
        isManualTypeMenuOpen = true
        redraw()
    }

    func requestBuildingViewForTesting() {
        requestBuildingView()
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

    func flushBuildingProgressSaveForTesting() {
        buildingProgressSaveAccumulator = 0
        store.save(state)
    }

    func compactNumberForTesting(_ value: Int) -> String {
        compactNumber(value)
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
}
#endif
