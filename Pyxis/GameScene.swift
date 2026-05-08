//
//  GameScene.swift
//  Pyxis
//
//  Created by Chan Wai Chan on 5/5/2026.
//

import Foundation
import SpriteKit

final class GameScene: SKScene {
    private enum BattleAssetName {
        static let playerCastle = "player-castle"
        static let enemyCity = "enemy-city"
        static let normalSoldier = "normal-soldier"
    }

    private struct SoldierAnimationConfiguration {
        let walkDuration: TimeInterval
        let attackDuration: TimeInterval

        static let live = SoldierAnimationConfiguration(walkDuration: 1.2, attackDuration: 0.18)
    }

    private enum ButtonName {
        static let spawn = "spawnSoldierButton"
        static let upgrade = "upgradeSoldierButton"
    }

    private let store: KingdomGameStore
    private var state: KingdomGameState
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
    private var pendingSoldiers: [SKNode] = []
    private let animationConfiguration = SoldierAnimationConfiguration.live

    private let goldLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let cityLevelLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let soldierAttackLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let cityHPLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let feedbackLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let hpBarBackground = SKShapeNode()
    private let hpBarFill = SKShapeNode()
    private let spawnButton = SKNode()
    private let spawnButtonBackground = SKShapeNode()
    private let spawnButtonLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let upgradeButton = SKNode()
    private let upgradeButtonBackground = SKShapeNode()
    private let upgradeButtonLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")

    private var feedbackText = "Tap Spawn Soldier to attack the city."

    init(size: CGSize, store: KingdomGameStore = .shared) {
        self.store = store
        self.state = store.load()
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        self.store = .shared
        self.state = KingdomGameStore.shared.load()
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

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else {
            return
        }

        switch buttonName(at: touch.location(in: self)) {
        case ButtonName.spawn:
            spawnSoldier()
        case ButtonName.upgrade:
            upgradeSoldier()
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

        let castleNode = makeBattleStructureNode(
            name: BattleAssetName.playerCastle,
            size: CGSize(width: 76, height: 98),
            color: SKColor(red: 0.22, green: 0.40, blue: 0.64, alpha: 1.0)
        )
        let cityNode = makeBattleStructureNode(
            name: BattleAssetName.enemyCity,
            size: CGSize(width: 86, height: 112),
            color: SKColor(red: 0.58, green: 0.28, blue: 0.26, alpha: 1.0)
        )
        playerCastleNode = castleNode
        enemyCityNode = cityNode
        environmentLayer.addChild(castleNode)
        environmentLayer.addChild(cityNode)

        configureLabel(goldLabel, fontSize: 28, color: SKColor(red: 1.0, green: 0.84, blue: 0.25, alpha: 1.0))
        configureLabel(cityLevelLabel, fontSize: 22, color: .white)
        configureLabel(soldierAttackLabel, fontSize: 18, color: SKColor(red: 0.74, green: 0.86, blue: 1.0, alpha: 1.0))
        configureLabel(cityHPLabel, fontSize: 18, color: SKColor(red: 0.88, green: 0.95, blue: 0.90, alpha: 1.0))
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

        [
            goldLabel,
            cityLevelLabel,
            soldierAttackLabel,
            cityHPLabel,
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
        addChild(hpBarBackground)
        addChild(hpBarFill)
        addChild(feedbackLabel)
        addChild(spawnButton)
        addChild(upgradeButton)
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
        let hpLabelToBarGap: CGFloat = compactHeight ? 24 : 30
        let buttonHeight: CGFloat = compactHeight ? 44 : 52
        let buttonGap: CGFloat = compactHeight ? 10 : 12
        let bottomMargin: CGFloat = compactHeight ? 32 : 38

        let contentWidth = max(160, min(size.width - 48, 430))
        let centerX = size.width / 2
        let topY = size.height - topMargin
        let upgradeButtonY = bottomMargin + buttonHeight / 2
        let spawnButtonY = upgradeButtonY + buttonHeight + buttonGap
        let spawnButtonTopY = spawnButtonY + buttonHeight / 2

        let battlefieldBottomY = spawnButtonTopY + 28
        let battlefieldTopY = max(battlefieldBottomY + 90, size.height - topMargin - 148)
        let laneY = battlefieldBottomY + (battlefieldTopY - battlefieldBottomY) * 0.42
        let sideInset = max(52, min(size.width * 0.18, 86))
        let castleX = sideInset
        let enemyX = size.width - sideInset

        playerCastleNode?.position = CGPoint(x: castleX, y: laneY)
        enemyCityNode?.position = CGPoint(x: enemyX, y: laneY)
        castleGatePoint = CGPoint(x: castleX + 34, y: laneY - 24)
        enemyGatePoint = CGPoint(x: enemyX - 38, y: laneY - 24)

        goldLabel.position = CGPoint(x: centerX, y: topY)
        cityLevelLabel.position = CGPoint(x: centerX, y: topY - primaryStatusGap)
        soldierAttackLabel.position = CGPoint(x: centerX, y: cityLevelLabel.position.y - secondaryStatusGap)
        cityHPLabel.position = CGPoint(x: centerX, y: soldierAttackLabel.position.y - secondaryStatusGap)

        let hpBarSize = CGSize(width: contentWidth, height: 18)
        hpBarBackground.path = CGPath(
            roundedRect: CGRect(x: -hpBarSize.width / 2, y: -hpBarSize.height / 2, width: hpBarSize.width, height: hpBarSize.height),
            cornerWidth: 9,
            cornerHeight: 9,
            transform: nil
        )
        hpBarBackground.position = CGPoint(x: centerX, y: cityHPLabel.position.y - hpLabelToBarGap)

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

        fitLabel(goldLabel, maxWidth: contentWidth)
        fitLabel(cityLevelLabel, maxWidth: contentWidth)
        fitLabel(soldierAttackLabel, maxWidth: contentWidth)
        fitLabel(cityHPLabel, maxWidth: contentWidth)
        fitLabel(feedbackLabel, maxWidth: contentWidth)
        fitLabel(spawnButtonLabel, maxWidth: contentWidth - 28)
        fitLabel(upgradeButtonLabel, maxWidth: contentWidth - 28)
    }

    private func resetFontSizes() {
        goldLabel.fontSize = 28
        cityLevelLabel.fontSize = 22
        soldierAttackLabel.fontSize = 18
        cityHPLabel.fontSize = 18
        feedbackLabel.fontSize = 16
        spawnButtonLabel.fontSize = 16
        upgradeButtonLabel.fontSize = 16
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

    private func makeBattleStructureNode(name: String, size: CGSize, color: SKColor) -> SKNode {
        let node = SKShapeNode(
            rectOf: size,
            cornerRadius: 8
        )
        node.name = name
        node.fillColor = color
        node.strokeColor = SKColor(white: 1.0, alpha: 0.22)
        node.lineWidth = 2
        return node
    }

    private func redraw() {
        goldLabel.text = "Gold: \(state.gold)"
        cityLevelLabel.text = "City Level: \(state.cityLevel)"
        soldierAttackLabel.text = "Soldier Attack: \(state.normalSoldierAttackPower)"
        cityHPLabel.text = "City HP: \(state.cityRemainingPower) / \(state.cityMaxPower)"
        feedbackLabel.text = feedbackText
        spawnButtonLabel.text = "Spawn Soldier"
        upgradeButtonLabel.text = "Upgrade Soldier (\(state.normalSoldierUpgradeCost) gold)"
        layoutInterface()
    }

    private func spawnSoldier() {
        let soldier = makeSoldierNode()
        soldier.position = castleGatePoint
        soldierLayer.addChild(soldier)
        pendingSoldiers.append(soldier)
        runSoldierAttackAnimation(for: soldier)
    }

    private func runSoldierAttackAnimation(for soldier: SKNode) {
        let bob = SKAction.repeatForever(
            SKAction.sequence([
                SKAction.moveBy(x: 0, y: 4, duration: 0.18),
                SKAction.moveBy(x: 0, y: -4, duration: 0.18)
            ])
        )
        soldier.run(bob, withKey: "soldierBob")

        let walk = SKAction.move(to: enemyGatePoint, duration: animationConfiguration.walkDuration)
        walk.timingMode = .easeInEaseOut

        let stopBob = SKAction.run { [weak soldier] in
            soldier?.removeAction(forKey: "soldierBob")
        }
        let lungeForward = SKAction.moveBy(x: 12, y: 0, duration: animationConfiguration.attackDuration / 2)
        lungeForward.timingMode = .easeOut
        let lungeBack = SKAction.moveBy(x: -12, y: 0, duration: animationConfiguration.attackDuration / 2)
        lungeBack.timingMode = .easeIn
        let impact = SKAction.run { [weak self, weak soldier] in
            guard let soldier else {
                return
            }

            self?.completeSoldierAttack(soldier)
        }

        soldier.run(SKAction.sequence([walk, stopBob, lungeForward, lungeBack, impact]))
    }

    private func completeSoldierAttack(_ soldier: SKNode) {
        guard let index = pendingSoldiers.firstIndex(where: { $0 === soldier }) else {
            return
        }

        pendingSoldiers.remove(at: index)
        soldier.removeAllActions()
        soldier.removeFromParent()

        let result = state.spawnSoldierAttack()

        if result.conqueredCities > 0 {
            feedbackText = "City conquered! +\(result.goldEarned) gold."
            playCityConquestFeedback()
        } else {
            feedbackText = "Soldier dealt \(result.damageDealt) damage."
            playCityHitFeedback()
        }

        store.save(state)
        redraw()
    }

    private func makeSoldierNode() -> SKNode {
        let soldier = SKShapeNode(circleOfRadius: 10)
        soldier.name = BattleAssetName.normalSoldier
        soldier.fillColor = SKColor(red: 0.18, green: 0.52, blue: 1.0, alpha: 1.0)
        soldier.strokeColor = SKColor(white: 1.0, alpha: 0.4)
        soldier.lineWidth = 2
        return soldier
    }

    private func playCityHitFeedback() {}

    private func playCityConquestFeedback() {}

    private func upgradeSoldier() {
        let result = state.upgradeNormalSoldier()

        switch result {
        case let .upgraded(cost, newAttackPower):
            feedbackText = "Upgraded for \(cost) gold. Attack: \(newAttackPower)."
        case let .insufficientGold(cost, currentGold):
            feedbackText = "Need \(cost) gold. You have \(currentGold)."
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
    }

    @objc private func sceneWillEnterForeground(_ notification: Notification) {
        let result = state.returnFromBackground(at: Date())

        store.save(state)

        if result.elapsedSeconds > 0 {
            feedbackText = "Idle attacks dealt \(result.damageDealt) damage and conquered \(result.conqueredCities) cities."
        }

        redraw()
    }

    private func buttonName(at point: CGPoint) -> String? {
        for node in nodes(at: point) {
            if node.name == ButtonName.spawn || node.name == ButtonName.upgrade {
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
}

extension GameScene {
    var pendingSoldierAttackCountForTesting: Int {
        pendingSoldiers.count
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

    func spawnSoldierForTesting() {
        spawnSoldier()
    }

    func completeFirstPendingSoldierAttackForTesting() {
        guard let soldier = pendingSoldiers.first else {
            return
        }

        completeSoldierAttack(soldier)
    }
}
