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
        static let upgrade = "upgradeBuildingButton"
        static let battle = "buildingViewBattleButton"
    }

    private enum SlotName {
        static let prefix = "buildingSlot-"
    }

    private enum AssetName {
        static let backdrop = "building-view-countryside-backdrop"
        static let emptyPad = "building-pad-empty"
    }

    private struct BuildButtonBundle {
        let button: SKNode
        let background: SKShapeNode
        let icon: SKSpriteNode
        let label: SKLabelNode
        let assetName: String
    }

    private struct SlotNodeBundle {
        let container: SKNode
        let hitArea: SKShapeNode
        let padSprite: SKSpriteNode
        let buildingSprite: SKSpriteNode
        let selectionOutline: SKShapeNode
        let levelBadge: SKShapeNode
        let levelLabel: SKLabelNode
        let label: SKLabelNode
        let padAssetName: String
        var buildingAssetName: String?
    }

    private struct ScenicSlotLayout {
        let slot: Int
        let x: CGFloat
        let y: CGFloat
        let scale: CGFloat
    }

    private static let scenicSlotLayouts: [ScenicSlotLayout] = [
        ScenicSlotLayout(slot: 1, x: 0.18, y: 0.78, scale: 0.96),
        ScenicSlotLayout(slot: 2, x: 0.34, y: 0.82, scale: 0.90),
        ScenicSlotLayout(slot: 3, x: 0.52, y: 0.78, scale: 0.98),
        ScenicSlotLayout(slot: 4, x: 0.70, y: 0.82, scale: 0.90),
        ScenicSlotLayout(slot: 5, x: 0.84, y: 0.72, scale: 0.88),
        ScenicSlotLayout(slot: 6, x: 0.24, y: 0.64, scale: 1.02),
        ScenicSlotLayout(slot: 7, x: 0.43, y: 0.66, scale: 0.94),
        ScenicSlotLayout(slot: 8, x: 0.62, y: 0.62, scale: 1.02),
        ScenicSlotLayout(slot: 9, x: 0.78, y: 0.56, scale: 0.92),
        ScenicSlotLayout(slot: 10, x: 0.13, y: 0.49, scale: 0.86),
        ScenicSlotLayout(slot: 11, x: 0.31, y: 0.50, scale: 1.02),
        ScenicSlotLayout(slot: 12, x: 0.51, y: 0.48, scale: 1.10),
        ScenicSlotLayout(slot: 13, x: 0.68, y: 0.43, scale: 0.98),
        ScenicSlotLayout(slot: 14, x: 0.87, y: 0.42, scale: 0.86),
        ScenicSlotLayout(slot: 15, x: 0.20, y: 0.34, scale: 0.94),
        ScenicSlotLayout(slot: 16, x: 0.39, y: 0.32, scale: 1.06),
        ScenicSlotLayout(slot: 17, x: 0.58, y: 0.31, scale: 0.96),
        ScenicSlotLayout(slot: 18, x: 0.76, y: 0.27, scale: 0.94),
        ScenicSlotLayout(slot: 19, x: 0.10, y: 0.19, scale: 0.82),
        ScenicSlotLayout(slot: 20, x: 0.28, y: 0.17, scale: 0.94),
        ScenicSlotLayout(slot: 21, x: 0.46, y: 0.15, scale: 1.02),
        ScenicSlotLayout(slot: 22, x: 0.64, y: 0.13, scale: 0.94),
        ScenicSlotLayout(slot: 23, x: 0.82, y: 0.14, scale: 0.84),
        ScenicSlotLayout(slot: 24, x: 0.56, y: 0.88, scale: 0.86),
        ScenicSlotLayout(slot: 25, x: 0.90, y: 0.62, scale: 0.80)
    ]

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
    private let backdropNode = SKSpriteNode(imageNamed: AssetName.backdrop)
    private let gridLayer = SKNode()
    private let upgradeButton = SKNode()
    private let upgradeBackground = SKShapeNode()
    private let upgradeLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let battleButton = SKNode()
    private let battleBackground = SKShapeNode()
    private let battleLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)

    private var buildButtonBundles: [BuildingType: BuildButtonBundle] = [:]
    private var slotNodes: [Int: SlotNodeBundle] = [:]
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

        let tappedButtonName = buttonName(at: point)
        if let tappedButtonName,
           let type = buildingType(forButtonName: tappedButtonName) {
            buildSelectedSlot(type)
            return
        }

        switch tappedButtonName {
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

        backdropNode.name = AssetName.backdrop
        backdropNode.zPosition = GameUITheme.Z.background
        addChild(backdropNode)
        addChild(gridLayer)
        addChild(titlePanel)
        addChild(actionPanel)

        configureLabel(titleLabel, fontSize: 26, color: GameUITheme.Color.textPrimary)
        configureLabel(goldLabel, fontSize: 18, color: GameUITheme.Color.gold)
        configureLabel(feedbackLabel, fontSize: 15, color: GameUITheme.Color.textSecondary)

        for type in BuildingType.allCases {
            let bundle = BuildButtonBundle(
                button: SKNode(),
                background: SKShapeNode(),
                icon: SKSpriteNode(imageNamed: type.paletteIconAssetName),
                label: SKLabelNode(fontNamed: GameUITheme.Font.bold),
                assetName: type.paletteIconAssetName
            )
            configureButton(
                bundle.button,
                background: bundle.background,
                icon: bundle.icon,
                label: bundle.label,
                name: buttonName(for: type),
                color: buildColor(for: type)
            )
            buildButtonBundles[type] = bundle
        }
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
            upgradeButton,
            battleButton
        ].forEach { $0.zPosition = GameUITheme.Z.hud + 1 }
        buildButtonBundles.values.forEach { $0.button.zPosition = GameUITheme.Z.hud + 1 }

        addChild(titleLabel)
        addChild(goldLabel)
        addChild(feedbackLabel)
        BuildingType.allCases.compactMap { buildButtonBundles[$0]?.button }.forEach(addChild)
        addChild(upgradeButton)
        addChild(battleButton)

        for slot in CityBattleState.slotRange {
            let container = SKNode()
            container.name = "\(SlotName.prefix)\(slot)"

            let hitArea = SKShapeNode()
            hitArea.name = container.name
            hitArea.fillColor = .clear
            hitArea.strokeColor = .clear

            let padSprite = SKSpriteNode(imageNamed: AssetName.emptyPad)
            padSprite.alpha = 0.78
            padSprite.zPosition = 0

            let buildingSprite = SKSpriteNode()
            buildingSprite.zPosition = 2

            let selectionOutline = SKShapeNode()
            selectionOutline.fillColor = .clear
            selectionOutline.strokeColor = GameUITheme.Color.gold
            selectionOutline.lineWidth = 3
            selectionOutline.alpha = 0
            selectionOutline.zPosition = 3

            let levelBadge = SKShapeNode()
            levelBadge.fillColor = SKColor(red: 0.07, green: 0.10, blue: 0.13, alpha: 0.92)
            levelBadge.strokeColor = GameUITheme.Color.gold
            levelBadge.lineWidth = 1
            levelBadge.zPosition = 4

            let levelLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
            levelLabel.fontSize = 10
            levelLabel.fontColor = GameUITheme.Color.textPrimary
            levelLabel.horizontalAlignmentMode = .center
            levelLabel.verticalAlignmentMode = .center
            levelLabel.zPosition = 5
            levelBadge.addChild(levelLabel)

            let label = SKLabelNode(fontNamed: GameUITheme.Font.medium)
            label.fontSize = 10
            label.fontColor = GameUITheme.Color.textPrimary
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.zPosition = 5

            container.addChild(hitArea)
            container.addChild(padSprite)
            container.addChild(buildingSprite)
            container.addChild(selectionOutline)
            container.addChild(levelBadge)
            container.addChild(label)
            gridLayer.addChild(container)

            slotNodes[slot] = SlotNodeBundle(
                container: container,
                hitArea: hitArea,
                padSprite: padSprite,
                buildingSprite: buildingSprite,
                selectionOutline: selectionOutline,
                levelBadge: levelBadge,
                levelLabel: levelLabel,
                label: label,
                padAssetName: AssetName.emptyPad,
                buildingAssetName: nil
            )
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
        icon: SKSpriteNode? = nil,
        label: SKLabelNode,
        name: String,
        color: SKColor
    ) {
        button.name = name
        background.name = name
        background.fillColor = color
        background.strokeColor = SKColor(white: 1.0, alpha: 0.22)
        background.lineWidth = 2

        icon?.name = name
        icon?.zPosition = 1

        label.name = name
        label.fontSize = 15
        label.fontColor = GameUITheme.Color.textPrimary
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.zPosition = 2

        button.addChild(background)
        if let icon {
            button.addChild(icon)
        }
        button.addChild(label)
    }

    private func buttonName(for type: BuildingType) -> String {
        "build-\(type.rawValue)-button"
    }

    private func buildingType(forButtonName name: String) -> BuildingType? {
        BuildingType.allCases.first { buttonName(for: $0) == name }
    }

    private func buildColor(for type: BuildingType) -> SKColor {
        switch type {
        case .barracks:
            return GameUITheme.Color.spawn
        case .archeryRange:
            return SKColor(red: 0.12, green: 0.55, blue: 0.48, alpha: 1.0)
        case .stable:
            return SKColor(red: 0.44, green: 0.32, blue: 0.18, alpha: 1.0)
        case .mageTower:
            return SKColor(red: 0.34, green: 0.24, blue: 0.62, alpha: 1.0)
        case .siegeWorkshop:
            return SKColor(red: 0.50, green: 0.28, blue: 0.18, alpha: 1.0)
        }
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
        let veryShortLandscape = size.width > size.height && size.height <= 340

        let titleHeight: CGFloat = veryShortLandscape ? 48 : (compactHeight ? 56 : 68)
        let actionHeight: CGFloat = veryShortLandscape ? 132 : (compactHeight ? 158 : 176)
        let topMargin = veryShortLandscape ? max(safeTop + 4, 8) : max(safeTop + 8, compactHeight ? 12 : 14)
        let bottomMargin = veryShortLandscape ? max(safeBottom + 4, 8) : max(safeBottom + 8, compactHeight ? 10 : 14)
        let panelGridGap: CGFloat = veryShortLandscape ? 8 : 18
        let titleCenterY = size.height - topMargin - titleHeight / 2
        let actionCenterY = bottomMargin + actionHeight / 2

        titlePanel.update(size: CGSize(width: contentWidth, height: titleHeight))
        titlePanel.position = CGPoint(x: size.width / 2, y: titleCenterY)
        actionPanel.update(size: CGSize(width: contentWidth, height: actionHeight))
        actionPanel.position = CGPoint(x: size.width / 2, y: actionCenterY)

        titleLabel.position = CGPoint(x: size.width / 2, y: titleCenterY + titleHeight * 0.20)
        goldLabel.position = CGPoint(x: size.width / 2, y: titleCenterY - titleHeight * 0.22)
        feedbackLabel.position = CGPoint(x: size.width / 2, y: actionCenterY + actionHeight * 0.33)

        let gridTop = titleCenterY - titleHeight / 2 - panelGridGap
        let gridBottom = actionCenterY + actionHeight / 2 + panelGridGap
        let gridHeight = max(0, gridTop - gridBottom)

        let backdropScale = max(
            size.width / max(backdropNode.size.width, 1),
            size.height / max(backdropNode.size.height, 1)
        )
        backdropNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        backdropNode.setScale(backdropScale)

        let slotArea = CGRect(
            x: horizontalMargin,
            y: gridBottom,
            width: contentWidth,
            height: gridHeight
        )
        let minimumSlotSize: CGFloat = veryShortLandscape ? 30 : 34
        let baseSlotSize = max(minimumSlotSize, min(slotArea.width * 0.16, slotArea.height * 0.22, 82))

        for layout in Self.scenicSlotLayouts {
            guard let bundle = slotNodes[layout.slot] else {
                continue
            }

            let slotSize = baseSlotSize * layout.scale
            let x = slotArea.minX + slotArea.width * layout.x
            let y = slotArea.minY + slotArea.height * layout.y

            bundle.container.position = CGPoint(x: x, y: y)
            bundle.hitArea.path = CGPath(
                ellipseIn: CGRect(x: -slotSize / 2, y: -slotSize / 2, width: slotSize, height: slotSize),
                transform: nil
            )
            bundle.padSprite.size = CGSize(width: slotSize * 1.08, height: slotSize * 0.72)
            bundle.buildingSprite.size = CGSize(width: slotSize * 1.16, height: slotSize * 1.16)
            bundle.buildingSprite.position = CGPoint(x: 0, y: slotSize * 0.12)
            bundle.selectionOutline.path = CGPath(
                ellipseIn: CGRect(
                    x: -slotSize * 0.62,
                    y: -slotSize * 0.42,
                    width: slotSize * 1.24,
                    height: slotSize * 0.84
                ),
                transform: nil
            )
            bundle.levelBadge.path = CGPath(
                roundedRect: CGRect(x: -18, y: -9, width: 36, height: 18),
                cornerWidth: 6,
                cornerHeight: 6,
                transform: nil
            )
            bundle.levelBadge.position = CGPoint(x: slotSize * 0.34, y: -slotSize * 0.24)
            bundle.label.position = CGPoint(x: 0, y: -slotSize * 0.50)
            bundle.label.fontSize = slotSize < 48 ? 8 : 10
        }

        let buttonHeight: CGFloat = veryShortLandscape ? 24 : (compactHeight ? 30 : 34)
        let buttonGap: CGFloat = veryShortLandscape ? 7 : (compactHeight ? 7 : 8)
        let buttonAreaWidth = contentWidth - 28
        let buildButtonWidth = (buttonAreaWidth - buttonGap * 2) / 3
        let buildStartX = size.width / 2 - buttonAreaWidth / 2 + buildButtonWidth / 2
        let buildTopY = actionCenterY + actionHeight * 0.13

        for (index, type) in BuildingType.allCases.enumerated() {
            guard let bundle = buildButtonBundles[type] else {
                continue
            }

            let row = index / 3
            let column = index % 3
            let x = buildStartX + CGFloat(column) * (buildButtonWidth + buttonGap)
            let y = buildTopY - CGFloat(row) * (buttonHeight + buttonGap)
            layoutButton(
                bundle.button,
                background: bundle.background,
                size: CGSize(width: buildButtonWidth, height: buttonHeight),
                position: CGPoint(x: x, y: y)
            )
            let iconSize = min(buttonHeight * 0.82, buildButtonWidth * 0.24)
            bundle.icon.size = CGSize(width: iconSize, height: iconSize)
            bundle.icon.position = CGPoint(x: -buildButtonWidth / 2 + iconSize * 0.72, y: 0)
            bundle.label.position = CGPoint(x: iconSize * 0.36, y: 0)
            fitLabel(bundle.label, maxWidth: buildButtonWidth - iconSize - 16)
        }

        let bottomButtonWidth = (buttonAreaWidth - buttonGap) / 2
        let leftX = size.width / 2 - bottomButtonWidth / 2 - buttonGap / 2
        let rightX = size.width / 2 + bottomButtonWidth / 2 + buttonGap / 2
        let bottomButtonY = actionCenterY - actionHeight * 0.34
        layoutButton(
            upgradeButton,
            background: upgradeBackground,
            size: CGSize(width: bottomButtonWidth, height: buttonHeight),
            position: CGPoint(x: leftX, y: bottomButtonY)
        )
        layoutButton(
            battleButton,
            background: battleBackground,
            size: CGSize(width: bottomButtonWidth, height: buttonHeight),
            position: CGPoint(x: rightX, y: bottomButtonY)
        )

        fitLabel(titleLabel, maxWidth: contentWidth - 28)
        fitLabel(goldLabel, maxWidth: contentWidth - 28)
        fitLabel(feedbackLabel, maxWidth: contentWidth - 28)
        fitLabel(upgradeLabel, maxWidth: bottomButtonWidth - 18)
        fitLabel(battleLabel, maxWidth: bottomButtonWidth - 18)

        layoutFrames = LayoutFrames(
            scene: CGRect(origin: .zero, size: size),
            titlePanel: sceneFrame(for: titlePanel) ?? .zero,
            actionPanel: sceneFrame(for: actionPanel) ?? .zero,
            grid: gridFrameForSlots(),
            buildButtonFrames: buildButtonFrameMap(),
            upgradeButton: sceneFrame(for: upgradeButton) ?? .zero,
            battleButton: sceneFrame(for: battleButton) ?? .zero
        )
    }

    private func resetFontSizes() {
        let veryShortLandscape = size.width > size.height && size.height <= 340

        titleLabel.fontSize = veryShortLandscape ? 22 : 26
        goldLabel.fontSize = veryShortLandscape ? 15 : 18
        feedbackLabel.fontSize = veryShortLandscape ? 13 : 15
        buildButtonBundles.values.forEach { $0.label.fontSize = veryShortLandscape ? 13 : 15 }
        upgradeLabel.fontSize = veryShortLandscape ? 13 : 15
        battleLabel.fontSize = veryShortLandscape ? 13 : 15
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
        battleLabel.text = "Battle"

        for type in BuildingType.allCases {
            guard let bundle = buildButtonBundles[type] else {
                continue
            }

            let unlocked = state.isBuildingTypeUnlocked(type)
            if unlocked {
                bundle.label.text = "Build \(type.shortDisplayName)"
            } else {
                bundle.label.text = "\(type.shortDisplayName) City \(KingdomGameState.unlockCity(for: type))"
            }

            let buildable = canBuild(type)
            bundle.background.fillColor = buildable
                ? buildColor(for: type)
                : GameUITheme.Color.upgradeUnavailable
            if !unlocked {
                bundle.icon.alpha = GameUITheme.Alpha.lockedIcon
            } else if canPresentEnabledIcon(for: type) {
                bundle.icon.alpha = GameUITheme.Alpha.enabledIcon
            } else {
                bundle.icon.alpha = GameUITheme.Alpha.unaffordableIcon
            }
        }

        let selectedBuilding = selectedSlot.flatMap { state.cityBattleStateForCurrentCity.building(inSlot: $0) }
        if let selectedBuilding {
            upgradeLabel.text = "Upgrade \(KingdomGameState.buildingUpgradeCost(for: selectedBuilding.type, currentLevel: selectedBuilding.level))g"
        } else {
            upgradeLabel.text = "Upgrade"
        }

        upgradeBackground.fillColor = canUpgradeSelectedSlot ? GameUITheme.Color.upgradeAvailable : GameUITheme.Color.upgradeUnavailable

        for slot in CityBattleState.slotRange {
            redrawSlot(slot)
        }

        layoutInterface()
    }

    private func redrawSlot(_ slot: Int) {
        guard var bundle = slotNodes[slot] else {
            return
        }

        if let building = state.cityBattleStateForCurrentCity.building(inSlot: slot) {
            bundle.label.text = building.type.displayName
            bundle.buildingSprite.texture = SKTexture(imageNamed: building.type.buildingAssetName)
            bundle.buildingSprite.alpha = 1
            bundle.levelLabel.text = "Lv \(building.level)"
            bundle.levelBadge.alpha = 1
            bundle.buildingAssetName = building.type.buildingAssetName
        } else {
            bundle.label.text = "Lot \(slot)"
            bundle.buildingSprite.texture = nil
            bundle.buildingSprite.alpha = 0
            bundle.levelLabel.text = nil
            bundle.levelBadge.alpha = 0
            bundle.buildingAssetName = nil
        }

        bundle.padSprite.alpha = selectedSlot == slot ? 1.0 : 0.78
        bundle.selectionOutline.alpha = selectedSlot == slot ? 1.0 : 0
        slotNodes[slot] = bundle
    }

    private func canBuild(_ type: BuildingType) -> Bool {
        guard state.stageStatus == .battleActive,
              let selectedSlot,
              state.cityBattleStateForCurrentCity.building(inSlot: selectedSlot) == nil else {
            return false
        }

        guard state.isBuildingTypeUnlocked(type) else {
            return false
        }

        let cityState = state.cityBattleStateForCurrentCity
        guard cityState.buildingCount(for: type) < CityBattleState.maxBuildingsPerType else {
            return false
        }

        return state.gold >= KingdomGameState.buildingBuildCost(for: type)
    }

    private func canPresentEnabledIcon(for type: BuildingType) -> Bool {
        guard state.stageStatus == .battleActive,
              state.isBuildingTypeUnlocked(type) else {
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
        case let .lockedBuilding(unlocksAtCity):
            feedbackText = "\(type.displayName) unlocks at City \(unlocksAtCity)."
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
        for slot in CityBattleState.slotRange {
            guard let hitArea = slotNodes[slot]?.hitArea,
                  let path = hitArea.path else {
                continue
            }

            let pointInHitArea = convert(point, to: hitArea)
            if path.contains(pointInHitArea) {
                return slot
            }
        }

        return nil
    }

    private func buttonName(at point: CGPoint) -> String? {
        for node in nodes(at: point) {
            guard let name = node.name else {
                continue
            }

            if buildingType(forButtonName: name) != nil || name == ButtonName.upgrade || name == ButtonName.battle {
                return name
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
        var buildButtonFrames: [BuildingType: CGRect] = [:]
        var upgradeButton = CGRect.zero
        var battleButton = CGRect.zero
    }

    private func buildButtonFrameMap() -> [BuildingType: CGRect] {
        var frames: [BuildingType: CGRect] = [:]
        for (type, bundle) in buildButtonBundles {
            frames[type] = sceneFrame(for: bundle.button) ?? .zero
        }
        return frames
    }

    private func gridFrameForSlots() -> CGRect {
        slotNodes.values
            .compactMap { sceneFrame(for: $0.hitArea) }
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
        let buildButtonFrames: [BuildingType: CGRect]
        let upgradeButton: CGRect
        let battleButton: CGRect
    }

    var buildingLayoutFramesForTesting: BuildingLayoutFrames? {
        BuildingLayoutFrames(
            scene: layoutFrames.scene,
            titlePanel: layoutFrames.titlePanel,
            actionPanel: layoutFrames.actionPanel,
            grid: layoutFrames.grid,
            buildButtonFrames: layoutFrames.buildButtonFrames,
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

    var backdropAssetNameForTesting: String {
        AssetName.backdrop
    }

    var slotCenterPointsForTesting: [Int: CGPoint] {
        Dictionary(uniqueKeysWithValues: slotNodes.map { slot, bundle in
            (slot, bundle.container.position)
        })
    }

    func slotHitAreaCenterPointForTesting(_ slot: Int) -> CGPoint? {
        guard let hitArea = slotNodes[slot]?.hitArea else {
            return nil
        }

        return hitArea.convert(.zero, to: self)
    }

    func slotLabelOverhangPointForTesting(_ slot: Int) -> CGPoint? {
        guard let label = slotNodes[slot]?.label,
              let frame = sceneFrame(for: label) else {
            return nil
        }

        return CGPoint(x: frame.midX, y: frame.minY + 1)
    }

    func slotAtPointForTesting(_ point: CGPoint) -> Int? {
        slot(at: point)
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

    var buildButtonTextsForTesting: [String] {
        BuildingType.allCases.compactMap { buildButtonBundles[$0]?.label.text }
    }

    var buildButtonIconAssetNamesForTesting: [BuildingType: String] {
        Dictionary(uniqueKeysWithValues: buildButtonBundles.map { type, bundle in
            (type, bundle.assetName)
        })
    }

    func buildButtonIconAlphaForTesting(_ type: BuildingType) -> CGFloat? {
        guard let alpha = buildButtonBundles[type]?.icon.alpha else {
            return nil
        }

        return (alpha * 100).rounded() / 100
    }

    func canBuildForTesting(_ type: BuildingType) -> Bool {
        canBuild(type)
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
        slotNodes[slot]?.label.text
    }

    func slotPadAssetNameForTesting(_ slot: Int) -> String? {
        slotNodes[slot]?.padAssetName
    }

    func slotBuildingAssetNameForTesting(_ slot: Int) -> String? {
        slotNodes[slot]?.buildingAssetName
    }

    func slotLevelTextForTesting(_ slot: Int) -> String? {
        slotNodes[slot]?.levelLabel.text
    }
}
#endif
