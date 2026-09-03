//
//  BuildingViewScene.swift
//  Pyxis
//

import Foundation
import SpriteKit
import UIKit

protocol BuildingViewSceneRouting: AnyObject {
    func buildingViewSceneDidRequestGameplayTab(
        _ scene: BuildingViewScene,
        tab: GameplayTab
    ) -> Bool
}

final class BuildingViewScene: SKScene, LayoutGateLifecycleHandling, SceneLayoutRefreshable {
    private enum SlotName {
        static let prefix = "buildingSlot-"
    }

    private enum AssetName {
        static let backdrop = "building-view-countryside-backdrop"
        static let emptyPad = "building-pad-empty"
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

    private let store: KingdomGameStore
    private weak var router: BuildingViewSceneRouting?
    private let feedback: GameplayFeedbackProviding
    private let feedbackPreferences: FeedbackPreferencesManaging
    private let feedbackSettingsAccessibilityAdapter: FeedbackSettingsAccessibilityAdapter?
    private var feedbackSettingsController: FeedbackSettingsController?
    private var state: KingdomGameState
    private var didBuildInterface = false
    private var isObservingLifecycle = false
    private var isLayoutGatePaused = false
    private var isSystemBackgrounded = false
    private var isRoutingToBattle = false
    private var lastIdleProgressResult = KingdomGameState.IdleProgressResult.none
    private var selectedSlot: Int?
    private var feedbackText = "Select a city lot."
    private var campChromeLayout: CampChromeLayout?
    private var renderedCampContent: CampSelectionContent?

    private let goldPanel = PanelNode(size: .zero)
    private let titleLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let goldLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let cityProgressLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let cityProgressBar = ProgressBarNode(size: .zero)
    private let feedbackLabel = SKLabelNode(fontNamed: GameUITheme.Font.medium)
    private let backdropNode = SKSpriteNode(imageNamed: AssetName.backdrop)
    private let gridLayer = SKNode()
    private let campSelectionNode = CampSelectionNode()
    private var gameplayTabContent = GameplayTabBarNode.Content(
        selected: .camp,
        enabledTabs: Set(GameplayTab.allCases),
        showsCampAttention: false
    )
    private var slotNodes: [Int: SlotNodeBundle] = [:]

    #if DEBUG
    private var layoutInterfaceCallCount = 0
    #endif

    init(
        size: CGSize,
        store: KingdomGameStore = .shared,
        router: BuildingViewSceneRouting? = nil,
        feedback: GameplayFeedbackProviding = NoOpGameplayFeedbackProvider(),
        feedbackPreferences: FeedbackPreferencesManaging = MainActor.assumeIsolated {
            FeedbackPreferencesStore.shared
        },
        feedbackSettingsAccessibilityAdapter: FeedbackSettingsAccessibilityAdapter? = nil
    ) {
        self.store = store
        self.router = router
        self.feedback = feedback
        self.feedbackPreferences = feedbackPreferences
        self.feedbackSettingsAccessibilityAdapter = feedbackSettingsAccessibilityAdapter
        self.state = store.load()
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        self.store = .shared
        self.router = nil
        self.feedback = NoOpGameplayFeedbackProvider()
        self.feedbackPreferences = FeedbackPreferencesStore.shared
        self.feedbackSettingsAccessibilityAdapter = nil
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
        configureFeedbackSettingsIfNeeded(in: view)
        observeLifecycleNotificationsIfNeeded()
        redraw()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutInterface()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        handleTouch(at: touch.location(in: self))
    }

    private func handleTouch(at point: CGPoint) {
        guard !isLayoutGatePaused, !isRoutingToBattle else { return }

        if let feedbackSettingsController,
           feedbackSettingsController.isVisible {
            _ = feedbackSettingsController.handleTouch(at: point)
            return
        }

        if feedbackSettingsController?.gear.contains(point, in: self) == true {
            openFeedbackSettings()
            return
        }

        if let action = campSelectionNode.action(at: point) {
            switch action {
            case let .build(type), let .requirement(type):
                buildSelectedSlot(type)
            case .upgrade:
                upgradeSelectedSlot()
            case let .tab(tab):
                requestGameplayTab(tab)
            }
            return
        }

        if let slot = slot(at: point) {
            selectSlot(slot)
        }
    }

    private var isFeedbackSettingsVisible: Bool {
        feedbackSettingsController?.isVisible == true
    }

    private func configureFeedbackSettingsIfNeeded(in view: SKView) {
        if feedbackSettingsController == nil {
            let accessibilityAdapter = feedbackSettingsAccessibilityAdapter
                ?? makeFeedbackSettingsAccessibilityAdapter(for: view)
            feedbackSettingsController = FeedbackSettingsController(
                preferences: feedbackPreferences,
                accessibilityAdapter: accessibilityAdapter
            )
            accessibilityAdapter.configureActions(
                onGearActivate: { [weak self] in
                    self?.openFeedbackSettings()
                },
                onToggleSoundEffects: { [weak self] in
                    self?.activateFeedbackSettings(.toggleSoundEffects)
                },
                onToggleHaptics: { [weak self] in
                    self?.activateFeedbackSettings(.toggleHaptics)
                },
                onClose: { [weak self] in
                    self?.activateFeedbackSettings(.close)
                }
            )
            feedbackSettingsController?.rebindAccessibilityForScene()
        }

        guard let feedbackSettingsController else { return }
        if feedbackSettingsController.gear.parent !== self {
            addChild(feedbackSettingsController.gear)
        }
        if feedbackSettingsController.modal.parent !== self {
            addChild(feedbackSettingsController.modal)
        }
    }

    private func makeFeedbackSettingsAccessibilityAdapter(
        for view: SKView
    ) -> FeedbackSettingsAccessibilityAdapter {
        FeedbackSettingsAccessibilityAdapter(
            containerView: view,
            sceneToScreenFrame: { [weak self, weak view] sceneFrame in
                guard let self else { return .zero }

                let viewFrame = CGRect(
                    x: sceneFrame.minX,
                    y: (view?.bounds.height ?? self.size.height) - sceneFrame.maxY,
                    width: sceneFrame.width,
                    height: sceneFrame.height
                )

                guard let view, view.window != nil else { return viewFrame }
                let screenFrame = UIAccessibility.convertToScreenCoordinates(
                    viewFrame,
                    in: view
                )
                return Self.feedbackSettingsAccessibilityFrame(
                    viewLocalFrame: viewFrame,
                    screenFrame: screenFrame
                )
            },
            postNotification: { notification, target in
                UIAccessibility.post(notification: notification, argument: target)
            }
        )
    }

    static func feedbackSettingsAccessibilityFrame(
        viewLocalFrame: CGRect,
        screenFrame: CGRect
    ) -> CGRect {
        guard screenFrame.origin.x.isFinite,
              screenFrame.origin.y.isFinite,
              screenFrame.width.isFinite,
              screenFrame.height.isFinite,
              screenFrame.width > 0,
              screenFrame.height > 0 else {
            return viewLocalFrame
        }
        return screenFrame
    }

    private func openFeedbackSettings() {
        guard !isLayoutGatePaused,
              !isRoutingToBattle,
              campChromeLayout != nil,
              let feedbackSettingsController,
              !feedbackSettingsController.isVisible else {
            return
        }
        _ = feedbackSettingsController.open()
    }

    private func closeFeedbackSettings(
        focusTarget: FeedbackSettingsFocusTarget = .openingGear
    ) {
        feedbackSettingsController?.close(focusTarget: focusTarget)
    }

    private func activateFeedbackSettings(_ action: FeedbackSettingsAction) {
        guard let feedbackSettingsController,
              feedbackSettingsController.isVisible,
              let layout = feedbackSettingsLayoutForCurrentEnvironment() else {
            return
        }

        let point: CGPoint
        switch action {
        case .toggleSoundEffects:
            point = CGPoint(x: layout.soundRowFrame.midX, y: layout.soundRowFrame.midY)
        case .toggleHaptics:
            point = CGPoint(x: layout.hapticsRowFrame.midX, y: layout.hapticsRowFrame.midY)
        case .close:
            point = CGPoint(x: layout.closeFrame.midX, y: layout.closeFrame.midY)
        case .consumed:
            return
        }
        _ = feedbackSettingsController.handleTouch(at: point)
    }

    private func feedbackSettingsLayoutForCurrentEnvironment() -> FeedbackSettingsLayout? {
        let safeAreaInsets = view?.safeAreaInsets ?? .zero
        return FeedbackSettingsLayout.compute(
            sceneSize: size,
            safeAreaInsets: .init(
                top: safeAreaInsets.top,
                left: safeAreaInsets.left,
                bottom: safeAreaInsets.bottom,
                right: safeAreaInsets.right
            )
        )
    }

    private func buildInterface() {
        backdropNode.name = AssetName.backdrop
        backdropNode.zPosition = GameUITheme.Z.background
        gridLayer.zPosition = GameUITheme.Z.battlefield
        addChild(backdropNode)
        addChild(gridLayer)

        goldPanel.name = "campGoldPanel"
        goldPanel.zPosition = GameUITheme.Z.hud
        addChild(goldPanel)

        configureLabel(titleLabel, fontSize: 24, color: GameUITheme.Color.textPrimary)
        configureLabel(goldLabel, fontSize: 17, color: GameUITheme.Color.textPrimary)
        configureLabel(cityProgressLabel, fontSize: 11, color: GameUITheme.Color.textPrimary)
        configureLabel(feedbackLabel, fontSize: 14, color: GameUITheme.Color.textSecondary)
        [titleLabel, goldLabel, cityProgressLabel, cityProgressBar, feedbackLabel]
            .forEach { $0.zPosition = GameUITheme.Z.hud + 1 }
        addChild(titleLabel)
        addChild(goldLabel)
        addChild(cityProgressLabel)
        addChild(cityProgressBar)
        addChild(feedbackLabel)

        campSelectionNode.zPosition = GameUITheme.Z.hud
        addChild(campSelectionNode)

        for slot in CityBattleState.slotRange {
            let container = SKNode()
            container.name = "\(SlotName.prefix)\(slot)"

            let hitArea = SKShapeNode()
            hitArea.name = container.name
            hitArea.fillColor = .clear
            hitArea.strokeColor = .clear

            let padSprite = SKSpriteNode(imageNamed: AssetName.emptyPad)
            padSprite.alpha = 0.78

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

    private func layoutInterface() {
        guard didBuildInterface else { return }

        #if DEBUG
        layoutInterfaceCallCount += 1
        #endif

        let insets = view?.safeAreaInsets ?? .zero
        let selection: CampChromeLayout.Selection
        if let selectedSlot {
            selection = state.cityBattleStateForCurrentCity.building(inSlot: selectedSlot) == nil
                ? .emptyLot(slot: selectedSlot)
                : .occupiedLot(slot: selectedSlot)
        } else {
            selection = .none
        }
        let input = CampChromeLayout.Input(
            sceneSize: size,
            safeAreaInsets: .init(
                top: insets.top,
                left: insets.left,
                bottom: insets.bottom,
                right: insets.right
            ),
            selection: selection
        )

        guard let layout = CampChromeLayout.compute(input) else {
            campChromeLayout = nil
            campSelectionNode.isHidden = true
            feedbackSettingsController?.applyGearFrame(.zero)
            return
        }

        campChromeLayout = layout
        campSelectionNode.isHidden = false
        let content = CampSelectionContent.project(from: state, selectedSlot: selectedSlot)
        renderedCampContent = content
        gameplayTabContent = content.tabContent
        _ = campSelectionNode.apply(content: content, layout: layout)

        backdropNode.setScale(1)
        let backdropScale = max(
            size.width / max(backdropNode.size.width, 1),
            size.height / max(backdropNode.size.height, 1)
        )
        backdropNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        backdropNode.setScale(backdropScale)

        goldPanel.apply(
            size: layout.goldFrame.size,
            style: .normal,
            showsRivets: true,
            appearance: .forged
        )
        goldPanel.position = CGPoint(x: layout.goldFrame.midX, y: layout.goldFrame.midY)
        titleLabel.text = "Camp"
        titleLabel.position = CGPoint(x: layout.titleFrame.minX, y: layout.titleFrame.midY)
        titleLabel.horizontalAlignmentMode = .left
        goldLabel.text = CompactNumberFormatter.string(from: state.gold)
        goldLabel.position = CGPoint(
            x: layout.goldFrame.minX + 42,
            y: layout.goldFrame.midY
        )
        goldLabel.horizontalAlignmentMode = .left
        let occupied = state.cityBattleStateForCurrentCity.occupiedSlotCount
        cityProgressLabel.text = "\(occupied) / \(CityBattleState.slotRange.count)"
        cityProgressLabel.position = CGPoint(
            x: layout.progressFrame.maxX + 16,
            y: layout.progressFrame.midY
        )
        cityProgressLabel.horizontalAlignmentMode = .left
        cityProgressBar.update(size: layout.progressFrame.size)
        cityProgressBar.update(progress: CGFloat(occupied) / CGFloat(CityBattleState.slotRange.count))
        cityProgressBar.position = CGPoint(x: layout.progressFrame.midX, y: layout.progressFrame.midY)

        let feedbackFrame = layout.feedbackFrame
        feedbackLabel.text = feedbackText
        feedbackLabel.position = CGPoint(x: feedbackFrame.midX, y: feedbackFrame.midY)
        feedbackLabel.isHidden = feedbackText == "Select a city lot."
        // fitLabel only ever shrinks the font; short messages must restart
        // from the authored size instead of inheriting the previous fit.
        feedbackLabel.fontSize = 14
        fitLabel(feedbackLabel, maxWidth: layout.safeFrame.width - 32)

        for slot in CityBattleState.slotRange {
            guard let bundle = slotNodes[slot],
                  let center = layout.lotPositions[slot],
                  let hitFrame = layout.lotHitFrames[slot] else {
                continue
            }

            let authoredScale = campChromeLayout?.lotVisualScales[slot] ?? 1
            let slotSize = max(44, min(68, hitFrame.width * 1.32 * authoredScale))
            bundle.container.position = center
            bundle.hitArea.path = CGPath(
                ellipseIn: CGRect(
                    x: -hitFrame.width / 2,
                    y: -hitFrame.height / 2,
                    width: hitFrame.width,
                    height: hitFrame.height
                ),
                transform: nil
            )
            let padSize = max(28, min(36, hitFrame.width * 0.78))
            bundle.padSprite.size = CGSize(width: padSize, height: padSize)
            bundle.buildingSprite.size = aspectFitSize(
                for: bundle.buildingSprite.texture,
                maximumSize: CGSize(width: slotSize * 1.26, height: slotSize * 1.26)
            )
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
            bundle.label.position = CGPoint(x: 0, y: 0)
            bundle.label.fontSize = slotSize < 48 ? 8 : 10
            slotNodes[slot] = bundle
        }

        if let feedbackSettingsController {
            feedbackSettingsController.applyGearFrame(
                layout.settingsFrame,
                appearance: .forged
            )
            feedbackSettingsController.reapply(layout: feedbackSettingsLayoutForCurrentEnvironment())
        }

        for slot in CityBattleState.slotRange {
            redrawSlot(slot)
        }
    }

    private func redraw() {
        layoutInterface()
    }

    private func redrawSlot(_ slot: Int) {
        guard var bundle = slotNodes[slot] else { return }
        if let building = state.cityBattleStateForCurrentCity.building(inSlot: slot) {
            bundle.label.text = nil
            bundle.buildingSprite.texture = SKTexture(imageNamed: building.type.buildingAssetName)
            bundle.buildingSprite.alpha = 1
            bundle.levelLabel.text = "Lv \(building.level)"
            bundle.levelBadge.alpha = 1
            bundle.buildingAssetName = building.type.buildingAssetName
        } else {
            bundle.label.text = "+"
            bundle.label.fontSize = 18
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
              state.cityBattleStateForCurrentCity.building(inSlot: selectedSlot) == nil,
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
        return state.gold >= KingdomGameState.buildingUpgradeCost(
            for: building.type,
            currentLevel: building.level
        )
    }

    private func selectSlot(_ slot: Int) {
        guard CityBattleState.slotRange.contains(slot) else { return }
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
            feedback.emit(.invalidAction)
            redraw()
            return
        }

        let result = state.buildBuilding(type, inSlot: selectedSlot, at: Date())
        switch result {
        case .built:
            feedbackText = "\(type.displayName) built."
            store.save(state)
            feedback.emit(.buildingChanged)
        case let .insufficientGold(cost, currentGold):
            feedbackText = "Need \(cost) gold. You have \(currentGold)."
            feedback.emit(.invalidAction)
        case .invalidSlot:
            feedbackText = "Select a city lot first."
            feedback.emit(.invalidAction)
        case let .lockedBuilding(unlocksAtCity):
            feedbackText = "\(type.displayName) unlocks at City \(unlocksAtCity)."
            feedback.emit(.invalidAction)
        case .slotOccupied:
            feedbackText = "That lot is occupied."
            feedback.emit(.invalidAction)
        case .typeCapReached:
            feedbackText = "\(type.displayName) limit reached."
            feedback.emit(.invalidAction)
        case let .cityConqueredDuringSettlement(goldEarned, _):
            feedbackText = "Buildings conquered \(state.displayCityTitle). Earned \(goldEarned) gold."
            store.save(state)
            closeFeedbackSettings(focusTarget: .systemDefault)
            emitFreshOutcomeFeedback(goldEarned: goldEarned, conqueredCities: 1)
        case .unavailable:
            feedbackText = "Enter a city before building."
            feedback.emit(.invalidAction)
        }
        redraw()
    }

    private func upgradeSelectedSlot() {
        guard let selectedSlot else {
            feedbackText = "Select a building first."
            feedback.emit(.invalidAction)
            redraw()
            return
        }

        let result = state.upgradeBuilding(inSlot: selectedSlot)
        switch result {
        case let .upgraded(_, newLevel, _):
            feedbackText = "Upgraded to level \(newLevel)."
            store.save(state)
            feedback.emit(.buildingChanged)
        case let .insufficientGold(cost, currentGold):
            feedbackText = "Need \(cost) gold. You have \(currentGold)."
            feedback.emit(.invalidAction)
        case .invalidSlot, .missingBuilding:
            feedbackText = "Select a building first."
            feedback.emit(.invalidAction)
        case let .cityConqueredDuringSettlement(goldEarned, _):
            feedbackText = "Buildings conquered \(state.displayCityTitle). Earned \(goldEarned) gold."
            store.save(state)
            closeFeedbackSettings(focusTarget: .systemDefault)
            emitFreshOutcomeFeedback(goldEarned: goldEarned, conqueredCities: 1)
        case .unavailable:
            feedbackText = "Enter a city before upgrading."
            feedback.emit(.invalidAction)
        }
        redraw()
    }

    private func requestGameplayTab(_ tab: GameplayTab) {
        guard !isLayoutGatePaused,
              !isRoutingToBattle,
              tab != .camp else {
            return
        }

        let result = state.returnFromBackground(at: Date())
        store.save(state)
        applyIdleProgressFeedback(result)
        redraw()
        isRoutingToBattle = true
        guard router?.buildingViewSceneDidRequestGameplayTab(self, tab: tab) ?? false else {
            isRoutingToBattle = false
            return
        }
    }

    func layoutGateWillPause(at date: Date) {
        guard !isLayoutGatePaused else { return }
        isLayoutGatePaused = true

        let result = state.returnFromBackground(at: date)
        lastIdleProgressResult = result
        if isSystemBackgrounded {
            state.enterBackground(at: date)
        }
        store.save(state)
        applyIdleProgressFeedback(result)
        redraw()
    }

    func layoutGateWillResume(at date: Date) {
        guard isLayoutGatePaused else { return }
        isLayoutGatePaused = false

        if state.stageStatus == .battleActive && !isSystemBackgrounded {
            state.markCurrentCityBuildingProgressInactive(at: date)
        }
        store.save(state)
        redraw()
    }

    func refreshLayoutForCurrentEnvironment() {
        layoutInterface()
    }

    private func observeLifecycleNotificationsIfNeeded() {
        guard !isObservingLifecycle else { return }
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
        handleSceneDidEnterBackground(at: Date())
    }

    @objc private func sceneWillEnterForeground(_ notification: Notification) {
        handleSceneWillEnterForeground(at: Date())
    }

    private func handleSceneDidEnterBackground(at date: Date) {
        isSystemBackgrounded = true
        if isLayoutGatePaused {
            state.enterBackground(at: date)
        }
        store.save(state)
    }

    private func handleSceneWillEnterForeground(at date: Date) {
        isSystemBackgrounded = false
        let result = state.returnFromBackground(at: date)
        lastIdleProgressResult = result
        if state.stageStatus == .battleActive && !isLayoutGatePaused {
            state.markCurrentCityBuildingProgressInactive(at: date)
        }
        store.save(state)
        applyIdleProgressFeedback(result)
        redraw()
    }

    private func applyIdleProgressFeedback(_ result: KingdomGameState.IdleProgressResult) {
        guard result.elapsedSeconds > 0 else { return }

        if result.conqueredCities > 0 {
            closeFeedbackSettings(focusTarget: .systemDefault)
            emitFreshOutcomeFeedback(
                goldEarned: result.goldEarned,
                conqueredCities: result.conqueredCities
            )
            feedbackText = "Buildings conquered \(state.displayCityTitle)."
        } else if result.damageDealt > 0 {
            feedbackText = "Buildings dealt \(result.damageDealt) idle damage."
        } else {
            feedbackText = "No building damage while away."
        }
    }

    private func emitFreshOutcomeFeedback(
        goldEarned: Int,
        conqueredCities: Int
    ) {
        guard conqueredCities > 0 else { return }
        if goldEarned > 0 {
            feedback.emit(.goldReward)
        }

        switch state.stageStatus {
        case .countryComplete:
            feedback.emit(.countryCompletion)
        case .cityConqueredPendingMap:
            feedback.emit(.cityConquest)
        case .battleActive:
            assertionFailure("Fresh Building View outcome did not advance stage status")
        }
    }

    private func slot(at point: CGPoint) -> Int? {
        // Higher slot numbers are later in the scenic layer and visually topmost.
        for slot in CityBattleState.slotRange.reversed() {
            guard let hitArea = slotNodes[slot]?.hitArea,
                  let path = hitArea.path else {
                continue
            }
            let pointInHitArea = convert(point, to: hitArea)
            if path.contains(pointInHitArea) { return slot }
        }
        return nil
    }

    private func fitLabel(_ label: SKLabelNode?, maxWidth: CGFloat) {
        guard let label, maxWidth > 0 else { return }
        while label.frame.width > maxWidth && label.fontSize > 8 {
            label.fontSize -= 1
        }
    }

    private func aspectFitSize(for texture: SKTexture?, maximumSize: CGSize) -> CGSize {
        guard let texture else { return maximumSize }
        let sourceSize = texture.size()
        guard sourceSize.width > 0,
              sourceSize.height > 0,
              maximumSize.width > 0,
              maximumSize.height > 0 else {
            return maximumSize
        }
        let scale = min(maximumSize.width / sourceSize.width, maximumSize.height / sourceSize.height)
        return CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
    }

    private func sceneFrame(for node: SKNode) -> CGRect? {
        guard let parent = node.parent else { return nil }
        let frame = node.calculateAccumulatedFrame()
        let points = [
            CGPoint(x: frame.minX, y: frame.minY),
            CGPoint(x: frame.maxX, y: frame.minY),
            CGPoint(x: frame.minX, y: frame.maxY),
            CGPoint(x: frame.maxX, y: frame.maxY)
        ].map { parent.convert($0, to: self) }
        guard let firstPoint = points.first else { return nil }
        return points.dropFirst().reduce(CGRect(origin: firstPoint, size: .zero)) {
            $0.union(CGRect(origin: $1, size: .zero))
        }
    }
}

#if DEBUG
extension BuildingViewScene {
    struct CampLayoutFrames {
        let scene: CGRect
        let safe: CGRect
        let header: CGRect
        let gold: CGRect
        let title: CGRect
        let progress: CGRect
        let settings: CGRect
        let lots: CGRect
        let feedback: CGRect
        let selection: CGRect?
        let builderOptions: [BuildingType: CGRect]
        let inspectorAction: CGRect?
        let tabs: CGRect
    }

    var campChromeLayoutForTesting: CampChromeLayout? { campChromeLayout }

    var campSelectionContentForTesting: CampSelectionContent? { renderedCampContent }

    var campLayoutFramesForTesting: CampLayoutFrames? {
        guard let layout = campChromeLayout else { return nil }
        return CampLayoutFrames(
            scene: layout.sceneFrame,
            safe: layout.safeFrame,
            header: layout.headerFrame,
            gold: layout.goldFrame,
            title: layout.titleFrame,
            progress: layout.progressFrame,
            settings: layout.settingsFrame,
            lots: layout.lotRegionFrame,
            feedback: layout.feedbackFrame,
            selection: layout.selectionFrame,
            builderOptions: layout.builderOptionFrames,
            inspectorAction: layout.inspectorActionFrame,
            tabs: layout.tabBarFrame
        )
    }

    var campSelectionNodeForTesting: CampSelectionNode { campSelectionNode }

    var lastIdleProgressResultForTesting: KingdomGameState.IdleProgressResult {
        lastIdleProgressResult
    }

    func sceneDidEnterBackgroundForTesting(at date: Date) {
        handleSceneDidEnterBackground(at: date)
    }

    func sceneWillEnterForegroundForTesting(at date: Date) {
        handleSceneWillEnterForeground(at: date)
    }

    var layoutInterfaceCallCountForTesting: Int { layoutInterfaceCallCount }

    var isFeedbackSettingsVisibleForTesting: Bool { isFeedbackSettingsVisible }

    var feedbackSettingsGearFrameForTesting: CGRect? {
        feedbackSettingsController?.gear.hitFrameForTesting
    }

    var feedbackLabelFrameForTesting: CGRect? {
        sceneFrame(for: feedbackLabel)
    }

    var isCampLayoutSupportedForTesting: Bool { campChromeLayout != nil }

    func activateFeedbackSettingsForTesting(_ action: FeedbackSettingsAction) {
        activateFeedbackSettings(action)
    }

    var buildingSlotCountForTesting: Int { CityBattleState.slotRange.count }

    var slotNodeCountForTesting: Int { slotNodes.count }

    var backdropAssetNameForTesting: String { backdropNode.name ?? AssetName.backdrop }

    var backdropFrameForTesting: CGRect? { sceneFrame(for: backdropNode) }

    var slotCenterPointsForTesting: [Int: CGPoint] {
        Dictionary(uniqueKeysWithValues: slotNodes.map { ($0.key, $0.value.container.position) })
    }

    func slotHitAreaCenterPointForTesting(_ slot: Int) -> CGPoint? {
        guard let hitArea = slotNodes[slot]?.hitArea else { return nil }
        return hitArea.convert(.zero, to: self)
    }

    func slotLabelOverhangPointForTesting(_ slot: Int) -> CGPoint? {
        guard let label = slotNodes[slot]?.label,
              let frame = sceneFrame(for: label) else { return nil }
        return CGPoint(x: frame.midX, y: frame.minY + 1)
    }

    func slotAtPointForTesting(_ point: CGPoint) -> Int? { slot(at: point) }

    var selectedSlotForTesting: Int? { selectedSlot }

    var goldTextForTesting: String? { goldLabel.text }

    var feedbackTextForTesting: String { feedbackText }

    func canBuildForTesting(_ type: BuildingType) -> Bool { canBuild(type) }

    var canUpgradeSelectedSlotForTesting: Bool { canUpgradeSelectedSlot }

    func selectSlotForTesting(_ slot: Int) { selectSlot(slot) }

    func buildSelectedSlotForTesting(_ type: BuildingType) { buildSelectedSlot(type) }

    func upgradeSelectedSlotForTesting() { upgradeSelectedSlot() }

    func requestGameplayTabForTesting(_ tab: GameplayTab) { requestGameplayTab(tab) }

    var gameplayTabBarForTesting: GameplayTabBarNode { campSelectionNode.tabBarForTesting }

    var gameplayTabContentForTesting: GameplayTabBarNode.Content { gameplayTabContent }

    var gameplayTabBarFrameForTesting: CGRect { campChromeLayout?.tabBarFrame ?? .zero }

    var isRoutingToBattleForTesting: Bool { isRoutingToBattle }

    func handleTouchForTesting(at point: CGPoint) { handleTouch(at: point) }

    func redrawForTesting() { redraw() }

    func repeatDidMoveForTesting() {
        guard let view else { return }
        didMove(to: view)
    }

    func slotTextForTesting(_ slot: Int) -> String? { slotNodes[slot]?.label.text }

    func slotPadAssetNameForTesting(_ slot: Int) -> String? { slotNodes[slot]?.padAssetName }

    func slotBuildingAssetNameForTesting(_ slot: Int) -> String? {
        slotNodes[slot]?.buildingAssetName
    }

    func slotBuildingSpriteSizeForTesting(_ slot: Int) -> CGSize? {
        slotNodes[slot]?.buildingSprite.size
    }

    func slotLevelTextForTesting(_ slot: Int) -> String? { slotNodes[slot]?.levelLabel.text }
}
#endif
