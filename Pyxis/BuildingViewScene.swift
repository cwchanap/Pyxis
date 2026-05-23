//
//  BuildingViewScene.swift
//  Pyxis
//

import Foundation
import SpriteKit

protocol BuildingViewSceneRouting: AnyObject {
    func buildingViewSceneDidRequestBattle(_ scene: BuildingViewScene)
}

final class BuildingViewScene: SKScene {
    private enum ButtonName {
        static let buildBarracks = "buildBarracksButton"
        static let buildArchery = "buildArcheryButton"
        static let upgrade = "upgradeBuildingButton"
        static let battle = "buildingViewBattleButton"
    }

    private enum SlotName {
        static let prefix = "buildingSlot-"
    }

    private let store: KingdomGameStore
    private weak var router: BuildingViewSceneRouting?
    private var state: KingdomGameState
    private var didBuildInterface = false
    private var isObservingLifecycle = false
    private var selectedSlot: Int?
    private var feedbackText = "Select a city lot."

    private let titlePanel = PanelNode(size: CGSize(width: 320, height: 64))
    private let actionPanel = PanelNode(size: CGSize(width: 320, height: 138))
    private let titleLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let goldLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let feedbackLabel = SKLabelNode(fontNamed: GameUITheme.Font.medium)
    private let gridLayer = SKNode()
    private let buildBarracksButton = SKNode()
    private let buildBarracksBackground = SKShapeNode()
    private let buildBarracksLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let buildArcheryButton = SKNode()
    private let buildArcheryBackground = SKShapeNode()
    private let buildArcheryLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let upgradeButton = SKNode()
    private let upgradeBackground = SKShapeNode()
    private let upgradeLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let battleButton = SKNode()
    private let battleBackground = SKShapeNode()
    private let battleLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)

    private var slotNodes: [Int: SKShapeNode] = [:]
    private var slotLabels: [Int: SKLabelNode] = [:]
    private var layoutFrames = LayoutFrames()

    init(size: CGSize, store: KingdomGameStore = .shared, router: BuildingViewSceneRouting? = nil) {
        self.store = store
        self.router = router
        self.state = store.load()
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        self.store = .shared
        self.router = nil
        self.state = KingdomGameStore.shared.load()
        super.init(coder: aDecoder)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.06, green: 0.10, blue: 0.12, alpha: 1.0)
        state = store.load()

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

        let point = touch.location(in: self)
        if let slot = slot(at: point) {
            selectSlot(slot)
            return
        }

        switch buttonName(at: point) {
        case ButtonName.buildBarracks:
            buildSelectedSlot(.barracks)
        case ButtonName.buildArchery:
            buildSelectedSlot(.archeryRange)
        case ButtonName.upgrade:
            upgradeSelectedSlot()
        case ButtonName.battle:
            requestBattle()
        default:
            break
        }
    }

    private func buildInterface() {
        titlePanel.zPosition = GameUITheme.Z.hud
        actionPanel.zPosition = GameUITheme.Z.hud
        gridLayer.zPosition = GameUITheme.Z.battlefield

        addChild(gridLayer)
        addChild(titlePanel)
        addChild(actionPanel)

        configureLabel(titleLabel, fontSize: 26, color: GameUITheme.Color.textPrimary)
        configureLabel(goldLabel, fontSize: 18, color: GameUITheme.Color.gold)
        configureLabel(feedbackLabel, fontSize: 15, color: GameUITheme.Color.textSecondary)

        configureButton(
            buildBarracksButton,
            background: buildBarracksBackground,
            label: buildBarracksLabel,
            name: ButtonName.buildBarracks,
            color: GameUITheme.Color.spawn
        )
        configureButton(
            buildArcheryButton,
            background: buildArcheryBackground,
            label: buildArcheryLabel,
            name: ButtonName.buildArchery,
            color: SKColor(red: 0.12, green: 0.55, blue: 0.48, alpha: 1.0)
        )
        configureButton(
            upgradeButton,
            background: upgradeBackground,
            label: upgradeLabel,
            name: ButtonName.upgrade,
            color: GameUITheme.Color.upgradeAvailable
        )
        configureButton(
            battleButton,
            background: battleBackground,
            label: battleLabel,
            name: ButtonName.battle,
            color: SKColor(red: 0.50, green: 0.28, blue: 0.18, alpha: 1.0)
        )

        [
            titleLabel,
            goldLabel,
            feedbackLabel,
            buildBarracksButton,
            buildArcheryButton,
            upgradeButton,
            battleButton
        ].forEach { $0.zPosition = GameUITheme.Z.hud + 1 }

        addChild(titleLabel)
        addChild(goldLabel)
        addChild(feedbackLabel)
        addChild(buildBarracksButton)
        addChild(buildArcheryButton)
        addChild(upgradeButton)
        addChild(battleButton)

        for slot in CityBattleState.slotRange {
            let node = SKShapeNode()
            node.name = "\(SlotName.prefix)\(slot)"
            node.lineWidth = 2

            let label = SKLabelNode(fontNamed: GameUITheme.Font.medium)
            label.name = node.name
            label.fontSize = 11
            label.fontColor = GameUITheme.Color.textPrimary
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            node.addChild(label)

            gridLayer.addChild(node)
            slotNodes[slot] = node
            slotLabels[slot] = label
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
        color: SKColor
    ) {
        button.name = name
        background.name = name
        background.fillColor = color
        background.strokeColor = SKColor(white: 1.0, alpha: 0.22)
        background.lineWidth = 2

        label.name = name
        label.fontSize = 15
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

        let safeTop = GameUITheme.topUnsafeInset(sceneSize: size, view: view)
        let safeBottom = GameUITheme.bottomUnsafeInset(sceneSize: size, view: view)
        let horizontalMargin = max(14, min(22, size.width * 0.05))
        let contentWidth = min(size.width - horizontalMargin * 2, 560)
        let compactHeight = size.height < 620

        let titleHeight: CGFloat = compactHeight ? 56 : 68
        let actionHeight: CGFloat = compactHeight ? 128 : 148
        let titleCenterY = size.height - max(safeTop + 8, compactHeight ? 12 : 14) - titleHeight / 2
        let actionCenterY = max(safeBottom + 8, compactHeight ? 10 : 14) + actionHeight / 2

        titlePanel.update(size: CGSize(width: contentWidth, height: titleHeight))
        titlePanel.position = CGPoint(x: size.width / 2, y: titleCenterY)
        actionPanel.update(size: CGSize(width: contentWidth, height: actionHeight))
        actionPanel.position = CGPoint(x: size.width / 2, y: actionCenterY)

        titleLabel.position = CGPoint(x: size.width / 2, y: titleCenterY + titleHeight * 0.20)
        goldLabel.position = CGPoint(x: size.width / 2, y: titleCenterY - titleHeight * 0.22)
        feedbackLabel.position = CGPoint(x: size.width / 2, y: actionCenterY + actionHeight * 0.33)

        let gridTop = titleCenterY - titleHeight / 2 - 18
        let gridBottom = actionCenterY + actionHeight / 2 + 18
        let gridHeight = max(0, gridTop - gridBottom)
        let slotGap: CGFloat = compactHeight ? 6 : 8
        let slotSize = max(12, min((contentWidth - slotGap * 4) / 5, (gridHeight - slotGap * 4) / 5))
        let gridWidth = slotSize * 5 + slotGap * 4
        let startX = (size.width - gridWidth) / 2
        let startY = gridBottom + (gridHeight - gridWidth) / 2 + gridWidth - slotSize

        for slot in CityBattleState.slotRange {
            guard let node = slotNodes[slot] else {
                continue
            }

            let index = slot - 1
            let row = index / 5
            let column = index % 5
            let x = startX + CGFloat(column) * (slotSize + slotGap) + slotSize / 2
            let y = startY - CGFloat(row) * (slotSize + slotGap) + slotSize / 2

            node.path = CGPath(
                roundedRect: CGRect(x: -slotSize / 2, y: -slotSize / 2, width: slotSize, height: slotSize),
                cornerWidth: 8,
                cornerHeight: 8,
                transform: nil
            )
            node.position = CGPoint(x: x, y: y)
            slotLabels[slot]?.fontSize = slotSize < 48 ? 9 : 11
            fitLabel(slotLabels[slot], maxWidth: slotSize - 8)
        }

        let buttonHeight: CGFloat = compactHeight ? 38 : 42
        let buttonGap: CGFloat = 8
        let buttonWidth = (contentWidth - buttonGap) / 2
        let leftX = size.width / 2 - buttonWidth / 2 - buttonGap / 2
        let rightX = size.width / 2 + buttonWidth / 2 + buttonGap / 2
        let topButtonY = actionCenterY + actionHeight * 0.04
        let bottomButtonY = actionCenterY - actionHeight * 0.28

        layoutButton(
            buildBarracksButton,
            background: buildBarracksBackground,
            size: CGSize(width: buttonWidth, height: buttonHeight),
            position: CGPoint(x: leftX, y: topButtonY)
        )
        layoutButton(
            buildArcheryButton,
            background: buildArcheryBackground,
            size: CGSize(width: buttonWidth, height: buttonHeight),
            position: CGPoint(x: rightX, y: topButtonY)
        )
        layoutButton(
            upgradeButton,
            background: upgradeBackground,
            size: CGSize(width: buttonWidth, height: buttonHeight),
            position: CGPoint(x: leftX, y: bottomButtonY)
        )
        layoutButton(
            battleButton,
            background: battleBackground,
            size: CGSize(width: buttonWidth, height: buttonHeight),
            position: CGPoint(x: rightX, y: bottomButtonY)
        )

        fitLabel(titleLabel, maxWidth: contentWidth - 28)
        fitLabel(goldLabel, maxWidth: contentWidth - 28)
        fitLabel(feedbackLabel, maxWidth: contentWidth - 28)
        fitLabel(buildBarracksLabel, maxWidth: buttonWidth - 18)
        fitLabel(buildArcheryLabel, maxWidth: buttonWidth - 18)
        fitLabel(upgradeLabel, maxWidth: buttonWidth - 18)
        fitLabel(battleLabel, maxWidth: buttonWidth - 18)

        layoutFrames = LayoutFrames(
            scene: CGRect(origin: .zero, size: size),
            titlePanel: sceneFrame(for: titlePanel) ?? .zero,
            actionPanel: sceneFrame(for: actionPanel) ?? .zero,
            grid: gridFrameForSlots(),
            buildBarracksButton: sceneFrame(for: buildBarracksButton) ?? .zero,
            buildArcheryButton: sceneFrame(for: buildArcheryButton) ?? .zero,
            upgradeButton: sceneFrame(for: upgradeButton) ?? .zero,
            battleButton: sceneFrame(for: battleButton) ?? .zero
        )
    }

    private func resetFontSizes() {
        titleLabel.fontSize = 26
        goldLabel.fontSize = 18
        feedbackLabel.fontSize = 15
        buildBarracksLabel.fontSize = 15
        buildArcheryLabel.fontSize = 15
        upgradeLabel.fontSize = 15
        battleLabel.fontSize = 15
    }

    private func layoutButton(_ button: SKNode, background: SKShapeNode, size: CGSize, position: CGPoint) {
        background.path = CGPath(
            roundedRect: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height),
            cornerWidth: 9,
            cornerHeight: 9,
            transform: nil
        )
        button.position = position
    }

    private func redraw() {
        titleLabel.text = "City Lots"
        goldLabel.text = "Gold: \(state.gold)"
        feedbackLabel.text = feedbackText
        buildBarracksLabel.text = "Build Barracks"
        buildArcheryLabel.text = "Build Archery"
        battleLabel.text = "Battle"

        let selectedBuilding = selectedSlot.flatMap { state.cityBattleStateForCurrentCity.building(inSlot: $0) }
        if let selectedBuilding {
            upgradeLabel.text = "Upgrade \(KingdomGameState.buildingUpgradeCost(for: selectedBuilding.type, currentLevel: selectedBuilding.level))g"
        } else {
            upgradeLabel.text = "Upgrade"
        }

        buildBarracksBackground.fillColor = canBuild(.barracks) ? GameUITheme.Color.spawn : GameUITheme.Color.upgradeUnavailable
        buildArcheryBackground.fillColor = canBuild(.archeryRange)
            ? SKColor(red: 0.12, green: 0.55, blue: 0.48, alpha: 1.0)
            : GameUITheme.Color.upgradeUnavailable
        upgradeBackground.fillColor = canUpgradeSelectedSlot ? GameUITheme.Color.upgradeAvailable : GameUITheme.Color.upgradeUnavailable

        for slot in CityBattleState.slotRange {
            redrawSlot(slot)
        }

        layoutInterface()
    }

    private func redrawSlot(_ slot: Int) {
        guard let node = slotNodes[slot], let label = slotLabels[slot] else {
            return
        }

        if let building = state.cityBattleStateForCurrentCity.building(inSlot: slot) {
            label.text = "\(building.type.displayName) Lv \(building.level)"
            switch building.type {
            case .barracks:
                node.fillColor = SKColor(red: 0.16, green: 0.36, blue: 0.62, alpha: 0.95)
            case .archeryRange:
                node.fillColor = SKColor(red: 0.16, green: 0.46, blue: 0.36, alpha: 0.95)
            }
        } else {
            label.text = "Lot \(slot)"
            node.fillColor = SKColor(red: 0.15, green: 0.20, blue: 0.21, alpha: 0.94)
        }

        node.strokeColor = selectedSlot == slot
            ? GameUITheme.Color.gold
            : SKColor(white: 1.0, alpha: 0.20)
        node.lineWidth = selectedSlot == slot ? 4 : 2
    }

    private func canBuild(_ type: BuildingType) -> Bool {
        guard state.stageStatus == .battleActive,
              let selectedSlot,
              state.cityBattleStateForCurrentCity.building(inSlot: selectedSlot) == nil else {
            return false
        }

        let cityState = state.cityBattleStateForCurrentCity
        guard cityState.buildingCount(for: type) < CityBattleState.maxBuildingsPerType else {
            return false
        }

        return state.gold >= KingdomGameState.buildingBuildCost(for: type)
    }

    private var canUpgradeSelectedSlot: Bool {
        guard state.stageStatus == .battleActive,
              let selectedSlot,
              let building = state.cityBattleStateForCurrentCity.building(inSlot: selectedSlot) else {
            return false
        }

        return state.gold >= KingdomGameState.buildingUpgradeCost(for: building.type, currentLevel: building.level)
    }

    private func selectSlot(_ slot: Int) {
        guard CityBattleState.slotRange.contains(slot) else {
            return
        }

        selectedSlot = slot
        if let building = state.cityBattleStateForCurrentCity.building(inSlot: slot) {
            feedbackText = "\(building.type.displayName) Lv \(building.level) selected."
        } else {
            feedbackText = "Empty lot \(slot) selected."
        }
        redraw()
    }

    private func buildSelectedSlot(_ type: BuildingType) {
        guard let selectedSlot else {
            feedbackText = "Select a city lot first."
            redraw()
            return
        }

        let result = state.buildBuilding(type, inSlot: selectedSlot, at: Date())
        switch result {
        case .built:
            feedbackText = "\(type.displayName) built."
            store.save(state)
        case let .insufficientGold(cost, currentGold):
            feedbackText = "Need \(cost) gold. You have \(currentGold)."
        case .invalidSlot:
            feedbackText = "Select a city lot first."
        case .slotOccupied:
            feedbackText = "That lot is occupied."
        case .typeCapReached:
            feedbackText = "\(type.displayName) limit reached."
        case let .cityConqueredDuringSettlement(goldEarned, _):
            feedbackText = "Buildings conquered \(state.displayCityTitle). Earned \(goldEarned) gold."
            store.save(state)
        case .unavailable:
            feedbackText = "Enter a city before building."
        }
        redraw()
    }

    private func upgradeSelectedSlot() {
        guard let selectedSlot else {
            feedbackText = "Select a building first."
            redraw()
            return
        }

        let result = state.upgradeBuilding(inSlot: selectedSlot)
        switch result {
        case let .upgraded(_, newLevel, _):
            feedbackText = "Upgraded to level \(newLevel)."
            store.save(state)
        case let .insufficientGold(cost, currentGold):
            feedbackText = "Need \(cost) gold. You have \(currentGold)."
        case .invalidSlot, .missingBuilding:
            feedbackText = "Select a building first."
        case let .cityConqueredDuringSettlement(goldEarned, _):
            feedbackText = "Buildings conquered \(state.displayCityTitle). Earned \(goldEarned) gold."
            store.save(state)
        case .unavailable:
            feedbackText = "Enter a city before upgrading."
        }
        redraw()
    }

    private func requestBattle() {
        let result = state.returnFromBackground(at: Date())
        store.save(state)
        applyIdleProgressFeedback(result)
        redraw()
        router?.buildingViewSceneDidRequestBattle(self)
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
        // Do NOT call state.enterBackground(at:) here. The building view already
        // counts time as idle progress (via markCurrentCityBuildingProgressInactive).
        // Calling enterBackground would overwrite lastBackgroundedAt and shorten the
        // idle window — see idleCatchUpFromBuildingViewPreservesEntireIdlePeriod.
        store.save(state)
    }

    @objc private func sceneWillEnterForeground(_ notification: Notification) {
        let result = state.returnFromBackground(at: Date())
        if state.stageStatus == .battleActive {
            state.markCurrentCityBuildingProgressInactive(at: Date())
        }
        store.save(state)

        applyIdleProgressFeedback(result)
        redraw()
    }

    private func applyIdleProgressFeedback(_ result: KingdomGameState.IdleProgressResult) {
        if result.elapsedSeconds > 0 {
            if result.conqueredCities > 0 {
                feedbackText = "Buildings conquered \(state.displayCityTitle)."
            } else if result.damageDealt > 0 {
                feedbackText = "Buildings dealt \(result.damageDealt) idle damage."
            } else {
                feedbackText = "No building damage while away."
            }
        }
    }

    private func slot(at point: CGPoint) -> Int? {
        for node in nodes(at: point) {
            guard let name = node.name, name.hasPrefix(SlotName.prefix) else {
                continue
            }

            let slotText = name.dropFirst(SlotName.prefix.count)
            if let slot = Int(slotText) {
                return slot
            }
        }

        return nil
    }

    private func buttonName(at point: CGPoint) -> String? {
        for node in nodes(at: point) {
            switch node.name {
            case ButtonName.buildBarracks, ButtonName.buildArchery, ButtonName.upgrade, ButtonName.battle:
                return node.name
            default:
                continue
            }
        }

        return nil
    }

    private func fitLabel(_ label: SKLabelNode?, maxWidth: CGFloat) {
        guard let label, maxWidth > 0 else {
            return
        }

        while label.frame.width > maxWidth && label.fontSize > 8 {
            label.fontSize -= 1
        }
    }

    private struct LayoutFrames {
        var scene = CGRect.zero
        var titlePanel = CGRect.zero
        var actionPanel = CGRect.zero
        var grid = CGRect.zero
        var buildBarracksButton = CGRect.zero
        var buildArcheryButton = CGRect.zero
        var upgradeButton = CGRect.zero
        var battleButton = CGRect.zero
    }

    private func gridFrameForSlots() -> CGRect {
        slotNodes.values
            .compactMap { sceneFrame(for: $0) }
            .reduce(nil) { partialFrame, frame in
                partialFrame?.union(frame) ?? frame
            } ?? .zero
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

        guard let firstPoint = points.first else {
            return nil
        }

        return points.dropFirst().reduce(CGRect(origin: firstPoint, size: .zero)) { partialFrame, point in
            partialFrame.union(CGRect(origin: point, size: .zero))
        }
    }
}

#if DEBUG
extension BuildingViewScene {
    struct BuildingLayoutFrames {
        let scene: CGRect
        let titlePanel: CGRect
        let actionPanel: CGRect
        let grid: CGRect
        let buildBarracksButton: CGRect
        let buildArcheryButton: CGRect
        let upgradeButton: CGRect
        let battleButton: CGRect
    }

    var buildingLayoutFramesForTesting: BuildingLayoutFrames? {
        BuildingLayoutFrames(
            scene: layoutFrames.scene,
            titlePanel: layoutFrames.titlePanel,
            actionPanel: layoutFrames.actionPanel,
            grid: layoutFrames.grid,
            buildBarracksButton: layoutFrames.buildBarracksButton,
            buildArcheryButton: layoutFrames.buildArcheryButton,
            upgradeButton: layoutFrames.upgradeButton,
            battleButton: layoutFrames.battleButton
        )
    }

    var buildingSlotCountForTesting: Int {
        CityBattleState.slotRange.count
    }

    var slotNodeCountForTesting: Int {
        slotNodes.count
    }

    var selectedSlotForTesting: Int? {
        selectedSlot
    }

    var goldTextForTesting: String? {
        goldLabel.text
    }

    var feedbackTextForTesting: String {
        feedbackText
    }

    var buildBarracksTextForTesting: String? {
        buildBarracksLabel.text
    }

    var buildArcheryTextForTesting: String? {
        buildArcheryLabel.text
    }

    var canBuildBarracksForTesting: Bool {
        canBuild(.barracks)
    }

    var canBuildArcheryRangeForTesting: Bool {
        canBuild(.archeryRange)
    }

    var canUpgradeSelectedSlotForTesting: Bool {
        canUpgradeSelectedSlot
    }

    func selectSlotForTesting(_ slot: Int) {
        selectSlot(slot)
    }

    func buildSelectedSlotForTesting(_ type: BuildingType) {
        buildSelectedSlot(type)
    }

    func upgradeSelectedSlotForTesting() {
        upgradeSelectedSlot()
    }

    func requestBattleForTesting() {
        requestBattle()
    }

    func slotTextForTesting(_ slot: Int) -> String? {
        slotLabels[slot]?.text
    }
}
#endif
