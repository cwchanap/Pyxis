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
}

final class BattleScene: SKScene {
    private enum BattleAssetName {
        static let playerCastle = "player-castle"
        static let enemyCity = "enemy-city"
        static let normalSoldier = "normal-soldier"
    }

    private enum ButtonName {
        static let spawn = "spawnSoldierButton"
        static let upgrade = "upgradeSoldierButton"
        static let popupContinue = "conquestPopupContinueButton"
    }

    private struct SoldierNodeBundle {
        let root: SKNode
        let body: SKNode
        let hpBarBackground: SKShapeNode
        let hpBarFill: SKShapeNode
    }

    private let store: KingdomGameStore
    private weak var router: BattleSceneRouting?
    private var state: KingdomGameState
    private var combat: BattleCombatState
    private var lastUpdateTime: TimeInterval?
    private var soldierNodes: [BattleCombatState.SoldierID: SoldierNodeBundle] = [:]
    private var didBuildInterface = false
    private var isObservingLifecycle = false

    private let battlefieldLayer = SKNode()
    private let environmentLayer = SKNode()
    private let soldierLayer = SKNode()
    private let effectsLayer = SKNode()
    private var playerCastleNode: SKNode?
    private var enemyCityNode: SKNode?
    private var castleGatePoint = CGPoint.zero
    private var enemyGatePoint = CGPoint.zero
    private var battleGroundLane: SKShapeNode?

    private let goldLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let cityLevelLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let soldierAttackLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let cityHPLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let liveCombatStatusLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let feedbackLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let hpBarBackground = SKShapeNode()
    private let hpBarFill = SKShapeNode()
    private let spawnButton = SKNode()
    private let spawnButtonBackground = SKShapeNode()
    private let spawnButtonLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let upgradeButton = SKNode()
    private let upgradeButtonBackground = SKShapeNode()
    private let upgradeButtonLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let popupOverlay = SKShapeNode()
    private let popupTitleLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let popupRewardLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let popupContinueButton = SKNode()
    private let popupContinueBackground = SKShapeNode()
    private let popupContinueLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private var isConquestPopupVisible = false

    private var feedbackText = "Tap Spawn Soldier to attack the city."

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

        switch buttonName(at: touch.location(in: self)) {
        case ButtonName.spawn:
            spawnSoldier()
        case ButtonName.upgrade:
            upgradeSoldier()
        case ButtonName.popupContinue:
            closeConquestPopup()
        default:
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

        configureLabel(goldLabel, fontSize: 28, color: SKColor(red: 1.0, green: 0.84, blue: 0.25, alpha: 1.0))
        configureLabel(cityLevelLabel, fontSize: 22, color: .white)
        configureLabel(soldierAttackLabel, fontSize: 18, color: SKColor(red: 0.74, green: 0.86, blue: 1.0, alpha: 1.0))
        configureLabel(cityHPLabel, fontSize: 18, color: SKColor(red: 0.88, green: 0.95, blue: 0.90, alpha: 1.0))
        configureLabel(liveCombatStatusLabel, fontSize: 15, color: SKColor(red: 0.77, green: 0.86, blue: 0.92, alpha: 1.0))
        configureLabel(feedbackLabel, fontSize: 16, color: SKColor(red: 0.95, green: 0.91, blue: 0.78, alpha: 1.0))

        hpBarBackground.fillColor = SKColor(red: 0.17, green: 0.19, blue: 0.22, alpha: 1.0)
        hpBarBackground.strokeColor = SKColor(red: 0.31, green: 0.35, blue: 0.39, alpha: 1.0)
        hpBarBackground.lineWidth = 2
        hpBarFill.fillColor = SKColor(red: 0.16, green: 0.76, blue: 0.43, alpha: 1.0)
        hpBarFill.strokeColor = .clear

        configureButton(
            spawnButton,
            background: spawnButtonBackground,
            label: spawnButtonLabel,
            name: ButtonName.spawn,
            color: SKColor(red: 0.12, green: 0.47, blue: 0.84, alpha: 1.0)
        )
        configureButton(
            upgradeButton,
            background: upgradeButtonBackground,
            label: upgradeButtonLabel,
            name: ButtonName.upgrade,
            color: SKColor(red: 0.56, green: 0.30, blue: 0.78, alpha: 1.0)
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
            soldierAttackLabel,
            cityHPLabel,
            liveCombatStatusLabel,
            hpBarBackground,
            hpBarFill,
            feedbackLabel,
            spawnButton,
            upgradeButton
        ].forEach { $0.zPosition = 100 }

        addChild(goldLabel)
        addChild(cityLevelLabel)
        addChild(soldierAttackLabel)
        addChild(cityHPLabel)
        addChild(liveCombatStatusLabel)
        addChild(hpBarBackground)
        addChild(hpBarFill)
        addChild(feedbackLabel)
        addChild(spawnButton)
        addChild(upgradeButton)
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
        label.fontColor = .white
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

        let compactHeight = size.height < 500
        let topMargin: CGFloat = compactHeight ? 36 : 72
        let primaryStatusGap: CGFloat = compactHeight ? 32 : 42
        let secondaryStatusGap: CGFloat = compactHeight ? 28 : 34
        let hpLabelToStatusGap: CGFloat = compactHeight ? 17 : 19
        let statusToBarGap: CGFloat = compactHeight ? 18 : 20
        let buttonHeight: CGFloat = compactHeight ? 44 : 52
        let buttonGap: CGFloat = compactHeight ? 10 : 12
        let bottomMargin: CGFloat = compactHeight ? 32 : 38

        let contentWidth = max(160, min(size.width - 48, 430))
        let centerX = size.width / 2
        let topY = size.height - topMargin
        let upgradeButtonY = bottomMargin + buttonHeight / 2
        let spawnButtonY = upgradeButtonY + buttonHeight + buttonGap
        let spawnButtonTopY = spawnButtonY + buttonHeight / 2

        goldLabel.position = CGPoint(x: centerX, y: topY)
        cityLevelLabel.position = CGPoint(x: centerX, y: topY - primaryStatusGap)
        soldierAttackLabel.position = CGPoint(x: centerX, y: cityLevelLabel.position.y - secondaryStatusGap)
        cityHPLabel.position = CGPoint(x: centerX, y: soldierAttackLabel.position.y - secondaryStatusGap)
        liveCombatStatusLabel.position = CGPoint(x: centerX, y: cityHPLabel.position.y - hpLabelToStatusGap)

        let hpBarSize = CGSize(width: contentWidth, height: 18)
        hpBarBackground.path = CGPath(
            roundedRect: CGRect(x: -hpBarSize.width / 2, y: -hpBarSize.height / 2, width: hpBarSize.width, height: hpBarSize.height),
            cornerWidth: 9,
            cornerHeight: 9,
            transform: nil
        )
        hpBarBackground.position = CGPoint(x: centerX, y: liveCombatStatusLabel.position.y - statusToBarGap)

        let hpPercent = CGFloat(state.cityRemainingPower) / CGFloat(max(1, state.cityMaxPower))
        let fillWidth = max(4, hpBarSize.width * min(max(hpPercent, 0), 1))
        hpBarFill.path = CGPath(
            roundedRect: CGRect(x: -hpBarSize.width / 2, y: -hpBarSize.height / 2, width: fillWidth, height: hpBarSize.height),
            cornerWidth: 9,
            cornerHeight: 9,
            transform: nil
        )
        hpBarFill.position = hpBarBackground.position

        // Keep feedback in the open band between the HP bar and action buttons.
        let hpBarBottomY = hpBarBackground.position.y - hpBarSize.height / 2
        let availableFeedbackGap = hpBarBottomY - spawnButtonTopY
        let idealFeedbackY = hpBarBottomY - (compactHeight ? 30 : 46)
        let feedbackY: CGFloat
        if availableFeedbackGap < 64 {
            feedbackY = spawnButtonTopY + availableFeedbackGap / 2
        } else {
            feedbackY = max(spawnButtonTopY + 32, min(idealFeedbackY, hpBarBottomY - 26))
        }
        feedbackLabel.position = CGPoint(x: centerX, y: feedbackY)

        let buttonSize = CGSize(width: contentWidth, height: buttonHeight)
        layoutButton(spawnButton, background: spawnButtonBackground, size: buttonSize, position: CGPoint(x: centerX, y: spawnButtonY))
        layoutButton(upgradeButton, background: upgradeButtonBackground, size: buttonSize, position: CGPoint(x: centerX, y: upgradeButtonY))
        layoutConquestPopup(contentWidth: contentWidth)

        layoutBattlefield(
            contentWidth: contentWidth,
            hpBarBottomY: hpBarBottomY,
            spawnButtonTopY: spawnButtonTopY,
            feedbackY: feedbackY
        )

        fitLabel(goldLabel, maxWidth: contentWidth)
        fitLabel(cityLevelLabel, maxWidth: contentWidth)
        fitLabel(soldierAttackLabel, maxWidth: contentWidth)
        fitLabel(cityHPLabel, maxWidth: contentWidth)
        fitLabel(liveCombatStatusLabel, maxWidth: contentWidth)
        fitLabel(feedbackLabel, maxWidth: contentWidth)
        fitLabel(spawnButtonLabel, maxWidth: contentWidth - 28)
        fitLabel(upgradeButtonLabel, maxWidth: contentWidth - 28)
        fitLabel(popupTitleLabel, maxWidth: contentWidth - 48)
        fitLabel(popupRewardLabel, maxWidth: contentWidth - 48)
        fitLabel(popupContinueLabel, maxWidth: contentWidth - 76)
    }

    private func resetFontSizes() {
        goldLabel.fontSize = 28
        cityLevelLabel.fontSize = 22
        soldierAttackLabel.fontSize = 18
        cityHPLabel.fontSize = 18
        liveCombatStatusLabel.fontSize = 15
        feedbackLabel.fontSize = 16
        spawnButtonLabel.fontSize = 16
        upgradeButtonLabel.fontSize = 16
        popupTitleLabel.fontSize = 22
        popupRewardLabel.fontSize = 18
        popupContinueLabel.fontSize = 16
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

    private func buildBattlefield() {
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
        let feedbackClearance = max(24, feedbackLabel.fontSize + 10)
        let safeTopY = min(hpBarBottomY - verticalPadding, feedbackY - feedbackClearance)
        let safeBottomY = spawnButtonTopY + verticalPadding
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

    private func redraw() {
        goldLabel.text = "Gold: \(state.gold)"
        cityLevelLabel.text = state.displayCityTitle
        soldierAttackLabel.text = "Soldier Attack: \(state.normalSoldierAttackPower)"
        cityHPLabel.text = "City HP: \(state.cityRemainingPower) / \(state.cityMaxPower)"
        updateLiveCombatStatusLabel()
        feedbackLabel.text = feedbackText
        spawnButtonLabel.text = "Spawn Soldier"
        upgradeButtonLabel.text = "Upgrade Soldier (\(state.normalSoldierUpgradeCost) gold)"
        layoutInterface()
    }

    private func updateLiveCombatStatusLabel() {
        liveCombatStatusLabel.fontSize = 15
        liveCombatStatusLabel.text = "Soldiers: \(combat.livingSoldierCount)"
        fitLabel(liveCombatStatusLabel, maxWidth: max(160, min(size.width - 48, 430)))
    }

    private func advanceCombat(deltaTime: TimeInterval) {
        guard state.stageStatus == .battleActive, !isConquestPopupVisible else {
            return
        }

        let result = combat.tick(deltaTime: deltaTime, cityRemainingHP: state.cityRemainingPower)
        applyCombatResult(result)
        syncSoldierNodes()
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
            feedbackText = "Soldiers dealt \(damageResult.damageDealt) damage."
        }

        store.save(state)
        redraw()

        if conqueredCity {
            playCityConquestFeedback()
            showConquestPopup(goldEarned: damageResult.goldEarned)
        } else {
            playCityHitFeedback()
        }
    }

    private func spawnSoldier() {
        guard !isConquestPopupVisible, state.stageStatus == .battleActive else {
            return
        }

        let soldierID = combat.spawnSoldier(attackPower: state.normalSoldierAttackPower)
        createSoldierNode(id: soldierID)
        syncSoldierNodes()
        updateLiveCombatStatusLabel()
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
        let flash = SKShapeNode(circleOfRadius: 9)
        flash.fillColor = SKColor(red: 1.0, green: 0.78, blue: 0.16, alpha: 0.9)
        flash.strokeColor = SKColor(red: 1.0, green: 0.38, blue: 0.08, alpha: 0.95)
        flash.lineWidth = 2
        flash.position = enemyGatePoint
        flash.zPosition = 40
        flash.setScale(0.4)
        effectsLayer.addChild(flash)

        let expand = SKAction.scale(to: 2.2, duration: 0.22)
        expand.timingMode = .easeOut
        let fade = SKAction.fadeOut(withDuration: 0.22)
        let remove = SKAction.removeFromParent()
        flash.run(SKAction.sequence([SKAction.group([expand, fade]), remove]))
    }

    private func playTowerShot(at soldierID: BattleCombatState.SoldierID) {
        guard let bundle = soldierNodes[soldierID] else {
            return
        }

        let shot = SKShapeNode(circleOfRadius: 4)
        shot.fillColor = SKColor(red: 1.0, green: 0.28, blue: 0.18, alpha: 1.0)
        shot.strokeColor = .clear
        shot.position = enemyGatePoint
        shot.zPosition = 45
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

    private func upgradeSoldier() {
        guard !isConquestPopupVisible, state.stageStatus == .battleActive else {
            return
        }

        let result = state.upgradeNormalSoldier()

        switch result {
        case let .upgraded(cost, newAttackPower):
            feedbackText = "Upgraded for \(cost) gold. Attack: \(newAttackPower)."
        case let .insufficientGold(cost, currentGold):
            feedbackText = "Need \(cost) gold. You have \(currentGold)."
        case .unavailable:
            feedbackText = "Enter a city to upgrade soldiers."
        }

        store.save(state)
        redraw()
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

        if result.elapsedSeconds > 0 {
            if result.conqueredCities > 0 {
                clearLiveCombat()
                feedbackText = "Idle attacks conquered \(state.displayCityTitle)."
            } else {
                feedbackText = "Idle attacks dealt \(result.damageDealt) damage."
            }
        }

        redraw()

        if result.conqueredCities > 0 {
            showConquestPopup(goldEarned: result.goldEarned)
        }
    }

    private func buttonName(at point: CGPoint) -> String? {
        for node in nodes(at: point) {
            if node.name == ButtonName.spawn || node.name == ButtonName.upgrade || node.name == ButtonName.popupContinue {
                return node.name
            }
        }

        return nil
    }

    private func fitLabel(_ label: SKLabelNode, maxWidth: CGFloat) {
        guard maxWidth > 0 else {
            return
        }

        while label.frame.width > maxWidth && label.fontSize > 12 {
            label.fontSize -= 1
        }
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
    var liveSoldierCountForTesting: Int {
        combat.livingSoldierCount
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
}
#endif
