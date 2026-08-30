//
//  CountryMapScene.swift
//  Pyxis
//

import Foundation
import SpriteKit
import UIKit

protocol CountryMapSceneRouting: AnyObject {
    @discardableResult
    func countryMapSceneDidRequestGameplayTab(
        _ scene: CountryMapScene,
        tab: GameplayTab
    ) -> Bool
    func countryMapScene(
        _ scene: CountryMapScene,
        didRequestLayoutGate reason: AppLayoutGateReason
    )
}

enum CountryMapCityVisualState: Equatable {
    case completed
    case unlocked
    case locked
}

#if DEBUG
struct CountryMapLayoutFrames {
    let sceneFrame: CGRect
    let titlePanelFrame: CGRect
    let illustratedRegionFrame: CGRect
    let scoutCardFrame: CGRect
}
#endif

final class CountryMapScene: SKScene, LayoutGateLifecycleHandling, SceneLayoutRefreshable {
    private enum NodeName {
        static let cityPrefix = "countryMapCity-"
    }

    private enum MapAssetName {
        static let countryMapBackdrop = "country-map-backdrop"
        static let conqueredMarker = "conquered-marker"
        static let goldBurst = "gold-burst"
    }

    private enum ActionKey {
        static let unlockedPulse = "countryMapUnlockedPulse"
    }

    private let store: KingdomGameStore
    private weak var router: CountryMapSceneRouting?
    private let feedback: GameplayFeedbackProviding
    private let feedbackPreferences: FeedbackPreferencesManaging
    private let feedbackSettingsAccessibilityAdapter: FeedbackSettingsAccessibilityAdapter?
    private var feedbackSettingsController: FeedbackSettingsController?
    private var state: KingdomGameState
    private let layoutEnvironmentOverride: CountryMapLayoutEnvironment?
    private let imageLoaderOverride: ((String) -> UIImage?)?
    private var didBuildInterface = false
    private var isMapUnavailable = false
    private(set) var isScoutCardFitFailed = false
    private var isObservingLifecycle = false
    private var isLayoutGatePaused = false
    private var isSystemBackgrounded = false
    private var isRoutingToBattle = false
    private var lastIdleProgressResult = KingdomGameState.IdleProgressResult.none
    private(set) var pendingIdleConquestBuildingCountForRouting: Int?

    private(set) var lastLayoutResult: CountryMapLayoutResult?
    private(set) var countryMapLayout: CountryMapLayout?

    private let backdropLayer = SKNode()
    private let routeLayer = SKNode()
    private let cityLayer = SKNode()
    private let titlePanel = PanelNode(size: CGSize(width: 320, height: 68))
    private let titleLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let resourcePanel = PanelNode(size: .zero)
    private let resourceIcon = SKSpriteNode()
    private let resourceLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let progressLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let progressSegments = (0..<KingdomGameState.firstCountryCityCount).map { index in
        let segment = SKShapeNode()
        segment.name = "countryMapProgressSegment-\(index + 1)"
        return segment
    }
    private let scoutCardNode: CountryMapScoutCardNode
    private var backdropNode: SKSpriteNode?
    private var cityNodes: [Int: SKShapeNode] = [:]
    private var cityHitTargets: [Int: SKShapeNode] = [:]
    private var cityLabels: [Int: SKLabelNode] = [:]
    private var conqueredMarkers: [Int: SKSpriteNode] = [:]
    private var cityVisualStates: [Int: CountryMapCityVisualState] = [:]
    private var cityBaseScales: [Int: CGFloat] = [:]
    private var selectedCityNumber: Int?
    private var scoutCardLayout: CountryMapScoutCardLayout?
    private var transientFeedback: CountryMapTransientFeedback?
    private var previousUpdateTime: TimeInterval?
    private let gameplayTabBar = GameplayTabBarNode()
    private var gameplayTabBarFrame = CGRect.zero
    private var gameplayTabContent = GameplayTabBarNode.Content(
        selected: .map,
        enabledTabs: [],
        showsCampAttention: false
    )
    private var mapResourceFrame = CGRect.zero
    private var mapProgressText = ""
    private var mapProgressCompletedCount = 0
    private var layoutFrames = (
        scene: CGRect.zero,
        titlePanel: CGRect.zero,
        illustratedRegion: CGRect.zero,
        scoutCard: CGRect.zero
    )

    init(
        size: CGSize,
        store: KingdomGameStore = .shared,
        router: CountryMapSceneRouting? = nil,
        layoutEnvironmentOverride: CountryMapLayoutEnvironment? = nil,
        imageLoaderOverride: ((String) -> UIImage?)? = nil,
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
        self.layoutEnvironmentOverride = layoutEnvironmentOverride
        self.imageLoaderOverride = imageLoaderOverride
        self.scoutCardNode = CountryMapScoutCardNode(
            imageLoader: imageLoaderOverride ?? { UIImage(named: $0) }
        )
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        self.store = .shared
        self.router = nil
        self.feedback = NoOpGameplayFeedbackProvider()
        self.feedbackPreferences = FeedbackPreferencesStore.shared
        self.feedbackSettingsAccessibilityAdapter = nil
        self.state = KingdomGameStore.shared.load()
        self.layoutEnvironmentOverride = nil
        self.imageLoaderOverride = nil
        self.scoutCardNode = CountryMapScoutCardNode()
        super.init(coder: aDecoder)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    static func isBackdropAvailable(
        named name: String,
        imageLoader: (String) -> UIImage?
    ) -> Bool {
        imageLoader(name) != nil
    }

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.07, green: 0.12, blue: 0.14, alpha: 1.0)
        state = store.load()
        previousUpdateTime = nil

        if !didBuildInterface {
            buildInterface()
            didBuildInterface = true
        }

        configureFeedbackSettingsIfNeeded(in: view)
        observeLifecycleNotificationsIfNeeded()
        layoutInterface()
    }

    override func update(_ currentTime: TimeInterval) {
        defer { previousUpdateTime = currentTime }
        guard let previousUpdateTime else {
            return
        }

        guard !isFeedbackSettingsVisible else {
            return
        }

        advanceFeedback(by: currentTime - previousUpdateTime)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutInterface()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else {
            return
        }

        handleTouch(at: touch.location(in: self))
    }

    private func handleTouch(at point: CGPoint) {
        if isMapUnavailable || countryMapLayout == nil || scoutCardLayout == nil {
            return
        }
        if isRoutingToBattle {
            return
        }
        if let feedbackSettingsController,
           feedbackSettingsController.isVisible {
            _ = feedbackSettingsController.handleTouch(at: point)
            return
        }
        if feedbackSettingsController?.gear.contains(point, in: self) == true {
            openFeedbackSettings()
            return
        }
        if handleGameplayTabTouch(at: point) {
            return
        }
        if handleScoutCardTouch(at: point) {
            return
        }
        if let cityNumber = cityNumber(at: point) {
            handleCityNodeTouch(cityNumber)
        }
    }

    private func handleScoutCardTouch(at point: CGPoint) -> Bool {
        if scoutCardNode.overlayHitFrame?.contains(point) == true {
            return true
        }
        if scoutCardNode.attackHitFrame?.contains(point) == true {
            requestSelectedCityAction()
            return true
        }
        if scoutCardNode.cardHitFrame?.contains(point) == true {
            // Tapping the Scout card body shows the current scout's flavor
            // text as a non-blocking overlay. It never mutates state, routes,
            // or emits gameplay feedback, and only fires when a real scout is
            // showing (not the country-complete card) and entry would
            // otherwise be allowed. Input priority stays overlay -> Attack ->
            // Scout body: when flavor is up its overlay excludes Attack, so an
            // Attack tap falls through to `attackHitFrame` above.
            if case .scout(let scout) = projectedScoutContent,
               state.stageStatus != .countryComplete,
               !isRoutingToBattle,
               transientFeedback?.kind.blocksScoutEntry != true {
                showFeedback(.flavor(scout.flavorText))
            }
            return true
        }

        return false
    }

    private func handleGameplayTabTouch(at point: CGPoint) -> Bool {
        guard cityNumber(at: point) == nil,
              let tab = gameplayTabBar.tab(at: point) else {
            return false
        }

        requestGameplayTab(tab)
        return true
    }

    private func buildInterface() {
        backdropLayer.zPosition = -20
        routeLayer.zPosition = 0
        cityLayer.zPosition = 10
        titlePanel.zPosition = GameUITheme.Z.hud
        resourcePanel.name = "countryMapGoldPanel"
        resourcePanel.zPosition = GameUITheme.Z.hud + 2
        resourceIcon.name = "countryMapGoldIcon"
        resourceIcon.zPosition = GameUITheme.Z.hud + 3
        resourceLabel.name = "countryMapGoldLabel"
        resourceLabel.zPosition = GameUITheme.Z.hud + 3
        progressLabel.name = "countryMapProgressLabel"
        progressLabel.zPosition = GameUITheme.Z.hud + 1
        progressSegments.forEach { $0.zPosition = GameUITheme.Z.hud + 1 }
        addChild(backdropLayer)
        addChild(routeLayer)
        addChild(cityLayer)
        addChild(titlePanel)
        addChild(resourcePanel)
        addChild(resourceIcon)
        addChild(resourceLabel)
        addChild(progressLabel)
        progressSegments.forEach(addChild)
        addChild(scoutCardNode)
        gameplayTabBar.zPosition = GameUITheme.Z.hud
        addChild(gameplayTabBar)

        guard Self.isBackdropAvailable(
            named: MapAssetName.countryMapBackdrop,
            imageLoader: imageLoaderOverride ?? { UIImage(named: $0) }
        ) else {
            isMapUnavailable = true
            clearLayoutGeometry()
            router?.countryMapScene(self, didRequestLayoutGate: .mapUnavailable)
            return
        }

        let backdrop = SKSpriteNode(imageNamed: MapAssetName.countryMapBackdrop)
        backdrop.name = MapAssetName.countryMapBackdrop
        backdrop.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backdrop.zPosition = 0
        backdropLayer.addChild(backdrop)
        backdropNode = backdrop

        configureLabel(titleLabel, fontSize: 30, color: GameUITheme.Color.textPrimary)
        titlePanel.addChild(titleLabel)
        configureLabel(resourceLabel, fontSize: 16, color: GameUITheme.Color.gold)
        resourceLabel.horizontalAlignmentMode = .left
        configureLabel(progressLabel, fontSize: 11, color: GameUITheme.Color.textPrimary)
        progressLabel.horizontalAlignmentMode = .right
        if let image = (imageLoaderOverride ?? { UIImage(named: $0) })(MapAssetName.goldBurst) {
            resourceIcon.texture = SKTexture(image: image)
        } else if let image = UIImage(systemName: "circle.fill") {
            resourceIcon.texture = SKTexture(image: image)
            resourceIcon.color = GameUITheme.Color.gold
            resourceIcon.colorBlendFactor = 1
        }

        let hasConqueredMarkerAsset = UIImage(named: MapAssetName.conqueredMarker) != nil

        for cityNumber in 1...KingdomGameState.firstCountryCityCount {
            let cityNode = SKShapeNode(circleOfRadius: 15)
            cityNode.name = "\(NodeName.cityPrefix)\(cityNumber)"
            cityNode.lineWidth = 3
            cityLayer.addChild(cityNode)
            cityNodes[cityNumber] = cityNode

            let cityHitTarget = SKShapeNode(rectOf: CGSize(width: 44, height: 44))
            cityHitTarget.name = cityNode.name
            cityHitTarget.fillColor = .clear
            cityHitTarget.strokeColor = .clear
            cityLayer.addChild(cityHitTarget)
            cityHitTargets[cityNumber] = cityHitTarget

            let cityLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
            configureLabel(cityLabel, fontSize: 13, color: .white)
            cityLabel.text = "\(cityNumber)"
            cityLabel.name = cityNode.name
            cityLayer.addChild(cityLabel)
            cityLabels[cityNumber] = cityLabel

            if hasConqueredMarkerAsset {
                let marker = SKSpriteNode(imageNamed: MapAssetName.conqueredMarker)
                marker.name = cityNode.name
                marker.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                marker.zPosition = 2
                marker.isHidden = true
                cityLayer.addChild(marker)
                conqueredMarkers[cityNumber] = marker
            }
        }
    }

    private func configureLabel(_ label: SKLabelNode, fontSize: CGFloat, color: SKColor) {
        label.fontSize = fontSize
        label.fontColor = color
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
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

        guard let feedbackSettingsController else {
            return
        }

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
                guard let self else {
                    return .zero
                }

                let viewFrame = CGRect(
                    x: sceneFrame.minX,
                    y: (view?.bounds.height ?? self.size.height) - sceneFrame.maxY,
                    width: sceneFrame.width,
                    height: sceneFrame.height
                )

                guard let view, view.window != nil else {
                    return viewFrame
                }
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
        guard !isMapUnavailable,
              countryMapLayout != nil,
              scoutCardLayout != nil,
              !isLayoutGatePaused,
              !isRoutingToBattle,
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
        guard let environment = layoutEnvironmentOverride
            ?? view.flatMap({ CountryMapLayoutUIKitAdapter.environment(for: $0) })
        else {
            return nil
        }
        return FeedbackSettingsLayout.compute(
            sceneSize: size,
            safeAreaInsets: .init(
                top: environment.safeAreaInsets.top,
                left: environment.safeAreaInsets.left,
                bottom: environment.safeAreaInsets.bottom,
                right: environment.safeAreaInsets.right
            )
        )
    }

    private func layoutInterface() {
        guard didBuildInterface, !isMapUnavailable else { return }
        isScoutCardFitFailed = false

        guard let environment = layoutEnvironmentOverride
            ?? view.flatMap({ CountryMapLayoutUIKitAdapter.environment(for: $0) })
        else {
            lastLayoutResult = .unsupported(.unsupportedGeometry)
            clearLayoutGeometry()
            return
        }

        let result = CountryMapLayout.compute(.init(
            sceneSize: size,
            environment: environment,
            definition: .country1
        ))
        lastLayoutResult = result

        let layout: CountryMapLayout
        switch result {
        case .supported(let supportedLayout):
            layout = supportedLayout
        case .unsupported(.invalidAuthoredData):
            clearLayoutGeometry()
            assertionFailure("Invalid authored country map data")
            router?.countryMapScene(self, didRequestLayoutGate: .mapUnavailable)
            return
        case .unsupported(.unsupportedGeometry):
            clearLayoutGeometry()
            return
        }

        countryMapLayout = layout
        scoutCardLayout = CountryMapScoutCardLayout.compute(
            in: layout.informationRegionFrame,
            layoutClass: environment.layoutClass
        )
        guard apply(layout, environment: environment) else {
            clearLayoutGeometry()
            router?.countryMapScene(self, didRequestLayoutGate: .unsupportedGeometry)
            return
        }
        redraw()
    }

    func refreshLayoutForCurrentEnvironment() {
        layoutInterface()
    }

    func layoutGateWillPause(at date: Date) {
        guard !isLayoutGatePaused else { return }
        isLayoutGatePaused = true
        previousUpdateTime = nil

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
        previousUpdateTime = nil

        if state.stageStatus == .battleActive && !isSystemBackgrounded {
            state.markCurrentCityBuildingProgressInactive(at: date)
        }
        store.save(state)
        redraw()
    }

    private func clearLayoutGeometry() {
        countryMapLayout = nil
        scoutCardLayout = nil
        layoutFrames = (.zero, .zero, .zero, .zero)
        routeLayer.removeAllChildren()

        backdropNode?.isHidden = true
        backdropNode?.size = .zero
        backdropNode?.position = .zero
        titlePanel.isHidden = true
        titlePanel.update(size: .zero)
        titlePanel.position = .zero
        resourcePanel.isHidden = true
        resourcePanel.update(size: .zero)
        resourcePanel.position = .zero
        resourceIcon.isHidden = true
        resourceIcon.size = .zero
        resourceIcon.position = .zero
        resourceLabel.isHidden = true
        resourceLabel.text = nil
        progressLabel.isHidden = true
        progressLabel.text = nil
        progressSegments.forEach {
            $0.isHidden = true
            $0.path = nil
            $0.position = .zero
        }
        mapResourceFrame = .zero
        mapProgressText = ""
        mapProgressCompletedCount = 0
        scoutCardNode.clearLayout()
        feedbackSettingsController?.applyGearFrame(.zero)
        gameplayTabBarFrame = .zero
        gameplayTabBar.apply(content: gameplayTabContent, frame: .zero)

        cityBaseScales.removeAll()
        cityVisualStates.removeAll()
        for cityNumber in 1...KingdomGameState.firstCountryCityCount {
            cityNodes[cityNumber]?.removeAction(forKey: ActionKey.unlockedPulse)
            cityNodes[cityNumber]?.isHidden = true
            cityNodes[cityNumber]?.position = .zero
            cityNodes[cityNumber]?.setScale(1)
            cityHitTargets[cityNumber]?.isHidden = true
            cityHitTargets[cityNumber]?.position = .zero
            cityLabels[cityNumber]?.isHidden = true
            cityLabels[cityNumber]?.position = .zero
            conqueredMarkers[cityNumber]?.isHidden = true
            conqueredMarkers[cityNumber]?.position = .zero
            conqueredMarkers[cityNumber]?.size = .zero
        }
    }

    private func apply(
        _ layout: CountryMapLayout,
        environment: CountryMapLayoutEnvironment
    ) -> Bool {
        guard !isMapUnavailable else { return false }

        if let backdropNode {
            backdropNode.isHidden = false
            backdropNode.setScale(1)
            backdropNode.size = layout.displayedBackdropFrame.size
            backdropNode.position = CGPoint(
                x: layout.displayedBackdropFrame.midX,
                y: layout.displayedBackdropFrame.midY
            )
        }

        titlePanel.update(size: layout.titleControlRegionFrame.size)
        titlePanel.isHidden = false
        titlePanel.position = CGPoint(
            x: layout.titleControlRegionFrame.midX,
            y: layout.titleControlRegionFrame.midY
        )
        layoutFrames = (
            scene: layout.sceneFrame,
            titlePanel: layout.titleControlRegionFrame,
            illustratedRegion: layout.illustratedMapRegionFrame,
            scoutCard: layout.informationRegionFrame
        )
        layoutGameplayTabBar(informationRegionFrame: layout.informationRegionFrame)

        titleLabel.text = "Country \(state.countryNumber)"
        titleLabel.fontSize = 20
        titleLabel.horizontalAlignmentMode = .left
        guard fitTitleLabel(titleLabel, maxWidth: layout.titleTextFrame.width) else {
            return false
        }
        titleLabel.position = titlePanel.convert(
            CGPoint(x: layout.titleTextFrame.minX, y: layout.titleTextFrame.midY),
            from: self
        )
        layoutMapChrome(layout)
        layoutFeedbackSettings(layout, environment: environment)

        drawRoutes(layout.routes)

        for (cityNumber, position) in layout.cityPositions {
            cityBaseScales[cityNumber] = 1
            cityNodes[cityNumber]?.setScale(1)
            cityNodes[cityNumber]?.isHidden = false
            cityNodes[cityNumber]?.lineWidth = 3
            cityNodes[cityNumber]?.position = position
            cityHitTargets[cityNumber]?.isHidden = false
            cityHitTargets[cityNumber]?.position = position
            cityLabels[cityNumber]?.isHidden = false
            cityLabels[cityNumber]?.fontSize = 12
            cityLabels[cityNumber]?.position = position
            conqueredMarkers[cityNumber]?.isHidden = false
            conqueredMarkers[cityNumber]?.position = CGPoint(
                x: position.x + 0.74 * 15,
                y: position.y + 0.62 * 15
            )
            conqueredMarkers[cityNumber]?.size = CGSize(width: 1.35 * 15, height: 1.35 * 15)
        }

        return true
    }

    private func layoutGameplayTabBar(informationRegionFrame: CGRect) {
        let horizontalMargin = max(16, min(22, size.width * 0.05))
        gameplayTabBarFrame = CGRect(
            x: horizontalMargin,
            y: informationRegionFrame.minY - CountryMapLayout.tabBarHeight - 8,
            width: max(0, size.width - horizontalMargin * 2),
            height: CountryMapLayout.tabBarHeight
        )
        gameplayTabBar.apply(content: gameplayTabContent, frame: gameplayTabBarFrame)
    }

    private func fitLabel(_ label: SKLabelNode, maxWidth: CGFloat) {
        guard maxWidth > 0 else {
            return
        }

        while label.frame.width > maxWidth && label.fontSize > 8 {
            label.fontSize -= 1
        }
    }

    private func fitTitleLabel(_ label: SKLabelNode, maxWidth: CGFloat) -> Bool {
        guard maxWidth >= CountryMapLayout.minimumTitleTextWidth else {
            return false
        }

        while label.frame.width > maxWidth,
              label.fontSize > CountryMapLayout.minimumTitleFontSize {
            label.fontSize -= 1
        }
        return label.frame.width <= maxWidth
    }

    private func layoutMapChrome(_ layout: CountryMapLayout) {
        let resourceFrame = layout.resourceFrame
        mapResourceFrame = resourceFrame
        resourcePanel.apply(
            size: resourceFrame.size,
            style: .normal,
            showsRivets: true
        )
        resourcePanel.position = CGPoint(x: resourceFrame.midX, y: resourceFrame.midY)
        resourcePanel.isHidden = false

        let iconFrame = CGRect(
            x: resourceFrame.minX + 8,
            y: resourceFrame.minY + 8,
            width: 28,
            height: 28
        )
        if let texture = resourceIcon.texture {
            resourceIcon.size = fitResourceIconSize(texture.size(), in: iconFrame.size)
            resourceIcon.position = CGPoint(x: iconFrame.midX, y: iconFrame.midY)
            resourceIcon.isHidden = false
        } else {
            resourceIcon.isHidden = true
            resourceIcon.size = .zero
        }
        resourceLabel.text = CompactNumberFormatter.string(from: state.gold)
        resourceLabel.fontSize = 16
        resourceLabel.position = CGPoint(
            x: resourceFrame.minX + 42,
            y: resourceFrame.midY
        )
        resourceLabel.isHidden = false

        let progressFrame = layout.progressFrame
        mapProgressText = "\(state.completedCityCount)/\(KingdomGameState.firstCountryCityCount)"
        mapProgressCompletedCount = min(
            KingdomGameState.firstCountryCityCount,
            max(0, state.completedCityCount)
        )
        progressLabel.text = mapProgressText
        progressLabel.fontSize = 11
        progressLabel.position = CGPoint(x: progressFrame.maxX, y: progressFrame.midY)
        progressLabel.isHidden = false

        let labelReservation: CGFloat = 32
        let segmentGap: CGFloat = 2
        let segmentRegionWidth = max(
            0,
            progressFrame.width - labelReservation
        )
        let segmentWidth = max(
            2,
            (segmentRegionWidth - segmentGap * CGFloat(progressSegments.count - 1))
                / CGFloat(progressSegments.count)
        )
        let segmentHeight: CGFloat = 8
        for (index, segment) in progressSegments.enumerated() {
            let x = progressFrame.minX
                + CGFloat(index) * (segmentWidth + segmentGap)
                + segmentWidth / 2
            let rect = CGRect(
                x: -segmentWidth / 2,
                y: -segmentHeight / 2,
                width: segmentWidth,
                height: segmentHeight
            )
            segment.path = CGPath(
                roundedRect: rect,
                cornerWidth: segmentHeight / 2,
                cornerHeight: segmentHeight / 2,
                transform: nil
            )
            segment.fillColor = index < mapProgressCompletedCount
                ? GameUITheme.Color.gold
                : GameUITheme.Color.locked.withAlphaComponent(0.75)
            segment.strokeColor = .clear
            segment.position = CGPoint(x: x, y: progressFrame.midY)
            segment.isHidden = false
        }
    }

    private func fitResourceIconSize(_ sourceSize: CGSize, in targetSize: CGSize) -> CGSize {
        guard sourceSize.width > 0,
              sourceSize.height > 0,
              targetSize.width > 0,
              targetSize.height > 0 else {
            return .zero
        }
        let scale = min(
            targetSize.width / sourceSize.width,
            targetSize.height / sourceSize.height
        )
        return CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
    }

    private func layoutFeedbackSettings(
        _ layout: CountryMapLayout,
        environment: CountryMapLayoutEnvironment
    ) {
        guard let feedbackSettingsController else {
            return
        }

        feedbackSettingsController.applyGearFrame(layout.settingsControlFrame)
        feedbackSettingsController.reapply(layout: FeedbackSettingsLayout.compute(
            sceneSize: size,
            safeAreaInsets: .init(
                top: environment.safeAreaInsets.top,
                left: environment.safeAreaInsets.left,
                bottom: environment.safeAreaInsets.bottom,
                right: environment.safeAreaInsets.right
            )
        ))
    }

    private func drawRoutes(_ routes: [CountryMapRouteLayout]) {
        routeLayer.removeAllChildren()

        for route in routes {
            let alpha: CGFloat = route.lineWidth >= 6 ? 0.9 : 0.38
            routeLayer.addChild(routeLine(
                from: route.start,
                to: route.end,
                alpha: alpha,
                width: route.lineWidth
            ))
        }
    }

    private func routeLine(from start: CGPoint, to end: CGPoint, alpha: CGFloat, width: CGFloat) -> SKShapeNode {
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)

        let line = SKShapeNode(path: path)
        line.strokeColor = SKColor(red: 0.72, green: 0.56, blue: 0.28, alpha: alpha)
        line.lineWidth = width
        line.lineCap = .round
        return line
    }

    private func redraw() {
        titleLabel.text = "Country \(state.countryNumber)"
        if let layout = countryMapLayout {
            layoutMapChrome(layout)
        }
        applyGameplayTabBar()

        guard countryMapLayout != nil,
              let scoutCardLayout else {
            scoutCardNode.clearLayout()
            for marker in conqueredMarkers.values {
                marker.isHidden = true
            }
            return
        }

        if selectedCityNumber == nil {
            selectedCityNumber = state.unlockedMapCityNumber ?? state.cityNumberInCountry
        }
        let content = projectedScoutContent
        let entryCanBeRequested: Bool
        if case .scout(let scout) = content {
            entryCanBeRequested = scout.actionTitle != nil
        } else {
            entryCanBeRequested = false
        }
        let result = scoutCardNode.apply(
            content: content,
            layout: scoutCardLayout,
            isEntryEnabled: entryCanBeRequested
                && !isRoutingToBattle
                && transientFeedback?.kind.blocksScoutEntry != true
        )
        guard result == .presented else {
            isScoutCardFitFailed = true
            clearLayoutGeometry()
            router?.countryMapScene(self, didRequestLayoutGate: .unsupportedGeometry)
            return
        }
        applyFeedbackPresentation()

        for cityNumber in 1...KingdomGameState.firstCountryCityCount {
            applyVisualState(visualState(for: cityNumber), to: cityNumber)
        }
    }

    private func applyGameplayTabBar() {
        let enabledTabs: Set<GameplayTab> = state.stageStatus == .battleActive
            && state.pendingBattleResult == nil
            ? Set(GameplayTab.allCases)
            : [.map]
        let showsCampAttention: Bool
        switch RecommendedCampRecommendation.make(for: state) {
        case .ready, .saveFor:
            showsCampAttention = true
        case .noAction:
            showsCampAttention = false
        }

        gameplayTabContent = GameplayTabBarNode.Content(
            selected: .map,
            enabledTabs: enabledTabs,
            showsCampAttention: showsCampAttention
        )
        gameplayTabBar.apply(content: gameplayTabContent, frame: gameplayTabBarFrame)
    }

    private func visualState(for cityNumber: Int) -> CountryMapCityVisualState {
        switch state.mapStatus(for: cityNumber) {
        case .completed:
            return .completed
        case .unlocked:
            return .unlocked
        case .locked:
            return .locked
        }
    }

    private func applyVisualState(_ visualState: CountryMapCityVisualState, to cityNumber: Int) {
        cityVisualStates[cityNumber] = visualState
        let cityNode = cityNodes[cityNumber]
        let cityLabel = cityLabels[cityNumber]
        let conqueredMarker = conqueredMarkers[cityNumber]

        cityNode?.removeAction(forKey: ActionKey.unlockedPulse)
        cityNode?.alpha = 1
        cityNode?.setScale(cityBaseScales[cityNumber] ?? cityNode?.xScale ?? 1)
        conqueredMarker?.isHidden = true

        switch visualState {
        case .completed:
            cityNode?.fillColor = GameUITheme.Color.gold
            cityNode?.strokeColor = SKColor(red: 1.0, green: 0.96, blue: 0.72, alpha: 1.0)
            cityNode?.lineWidth = max(2, cityNode?.lineWidth ?? 2)
            cityLabel?.fontColor = SKColor(red: 0.13, green: 0.10, blue: 0.04, alpha: 1.0)
            conqueredMarker?.isHidden = false
        case .unlocked:
            cityNode?.fillColor = GameUITheme.Color.hpFill
            cityNode?.strokeColor = SKColor.white
            cityNode?.lineWidth = max(3, cityNode?.lineWidth ?? 3)
            cityLabel?.fontColor = .white
            startUnlockedPulse(for: cityNode)
        case .locked:
            cityNode?.fillColor = GameUITheme.Color.locked
            cityNode?.strokeColor = SKColor(white: 1.0, alpha: 0.24)
            cityNode?.lineWidth = max(2, cityNode?.lineWidth ?? 2)
            cityNode?.alpha = 0.78
            cityLabel?.fontColor = SKColor(white: 1.0, alpha: 0.52)
        }
    }

    private func startUnlockedPulse(for cityNode: SKShapeNode?) {
        guard let cityNode else {
            return
        }

        let pulseUp = SKAction.group([
            SKAction.scale(to: cityNode.xScale * 1.08, duration: 0.8),
            SKAction.fadeAlpha(to: 0.86, duration: 0.8)
        ])
        let pulseDown = SKAction.group([
            SKAction.scale(to: cityNode.xScale, duration: 0.8),
            SKAction.fadeAlpha(to: 1.0, duration: 0.8)
        ])
        cityNode.run(SKAction.repeatForever(SKAction.sequence([pulseUp, pulseDown])), withKey: ActionKey.unlockedPulse)
    }

    private func showFeedback(_ feedback: CountryMapTransientFeedback) {
        transientFeedback = feedback
        previousUpdateTime = nil
        applyFeedbackPresentation()
    }

    private func applyFeedbackPresentation() {
        scoutCardNode.applyFeedback(
            text: transientFeedback?.text,
            alpha: transientFeedback?.alpha ?? 0,
            blocksAttack: transientFeedback?.kind.blocksScoutEntry ?? false
        )
    }

    private func advanceFeedback(by deltaTime: TimeInterval) {
        guard var feedback = transientFeedback else {
            return
        }

        feedback.advance(by: deltaTime)
        transientFeedback = feedback.isFinished ? nil : feedback
        if feedback.isFinished {
            redraw()
        } else {
            applyFeedbackPresentation()
        }
    }

    private func cityNumber(at point: CGPoint) -> Int? {
        for node in nodes(at: point) {
            guard let name = node.name, name.hasPrefix(NodeName.cityPrefix) else {
                continue
            }

            return Int(name.dropFirst(NodeName.cityPrefix.count))
        }

        return nil
    }

    private var projectedScoutContent: CountryMapScoutCardContent {
        CountryMapScoutCardContent.project(
            from: state,
            selectedCityNumber: selectedCityNumber
        )
    }

    private func requestSelectedCityAction() {
        guard case .scout(let scout) = projectedScoutContent else {
            return
        }

        switch scout.status {
        case .current:
            requestEntry(for: scout.cityNumber)
        case .attackable:
            requestEntry(for: scout.cityNumber)
        case .completed:
            feedback.emit(.invalidAction)
            showFeedback(.completed(cityNumber: scout.cityNumber))
        case .locked:
            feedback.emit(.invalidAction)
            showFeedback(.locked(cityNumber: scout.cityNumber))
        }
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
        previousUpdateTime = nil
        if isLayoutGatePaused {
            state.enterBackground(at: date)
        }
        store.save(state)
    }

    private func handleSceneWillEnterForeground(at date: Date) {
        isSystemBackgrounded = false
        previousUpdateTime = nil
        let result = state.returnFromBackground(at: date)
        lastIdleProgressResult = result
        if state.stageStatus == .battleActive && !isLayoutGatePaused {
            state.markCurrentCityBuildingProgressInactive(at: date)
        }
        store.save(state)
        applyIdleProgressFeedback(result)
        redraw()
    }

    private func applyIdleProgressFeedback(
        _ result: KingdomGameState.IdleProgressResult
    ) {
        guard result.elapsedSeconds > 0 else {
            return
        }

        if result.conqueredCities > 0 {
            closeFeedbackSettings(focusTarget: .systemDefault)
            emitFreshOutcomeFeedback(
                goldEarned: result.goldEarned,
                conqueredCities: result.conqueredCities
            )
        }

        if let feedback = CountryMapTransientFeedback.idle(
            result: result,
            state: state
        ) {
            showFeedback(feedback)
        }
    }

    private func emitFreshOutcomeFeedback(
        goldEarned: Int,
        conqueredCities: Int
    ) {
        guard conqueredCities > 0 else {
            return
        }

        if goldEarned > 0 {
            feedback.emit(.goldReward)
        }

        switch state.stageStatus {
        case .countryComplete:
            feedback.emit(.countryCompletion)
        case .cityConqueredPendingMap:
            feedback.emit(.cityConquest)
        case .battleActive:
            assertionFailure("Fresh Country Map outcome did not advance stage status")
        }
    }

    private func handleCityNodeTouch(_ cityNumber: Int) {
        let latestState = store.load()
        state = latestState
        guard Country1CityCatalog.cityRange.contains(cityNumber) else {
            return
        }
        selectedCityNumber = cityNumber
        switch latestState.mapStatus(for: cityNumber) {
        case .completed:
            feedback.emit(.invalidAction)
            showFeedback(.completed(cityNumber: cityNumber))
        case .locked:
            feedback.emit(.invalidAction)
            showFeedback(.locked(cityNumber: cityNumber))
        case .unlocked:
            break
        }
        redraw()
    }

    private func requestGameplayTab(_ tab: GameplayTab) {
        guard tab != .map,
              !isRoutingToBattle,
              state.stageStatus == .battleActive,
              countryMapLayout != nil,
              scoutCardLayout != nil else {
            return
        }

        pendingIdleConquestBuildingCountForRouting = nil
        let buildingCount = state.cityBattleStateForCurrentCity.occupiedSlotCount
        let idleResult = state.returnFromBackground(at: Date())
        lastIdleProgressResult = idleResult
        store.save(state)
        applyIdleProgressFeedback(idleResult)
        redraw()

        if idleResult.conqueredCities > 0 {
            pendingIdleConquestBuildingCountForRouting = buildingCount
        }

        isRoutingToBattle = true
        guard router?.countryMapSceneDidRequestGameplayTab(self, tab: tab) ?? false else {
            isRoutingToBattle = false
            redraw()
            return
        }
    }

    private func requestEntry(for cityNumber: Int) {
        guard !isRoutingToBattle,
              countryMapLayout != nil,
              scoutCardLayout != nil else {
            return
        }

        var latestState = store.load()

        switch latestState.startCityFromMap(cityNumber) {
        case .entered:
            guard let router else {
                state = store.load()
                feedback.emit(.invalidAction)
                showFeedback(.cannotEnterCityYet())
                redraw()
                return
            }

            let idleResult = latestState.returnFromBackground(at: Date())
            state = latestState
            store.save(state)

            guard state.stageStatus == .battleActive else {
                selectedCityNumber = state.unlockedMapCityNumber ?? state.cityNumberInCountry
                applyIdleProgressFeedback(idleResult)
                redraw()
                return
            }

            selectedCityNumber = cityNumber
            isRoutingToBattle = true
            redraw()

            guard router.countryMapSceneDidRequestGameplayTab(self, tab: .battle) else {
                isRoutingToBattle = false
                feedback.emit(.invalidAction)
                showFeedback(.cannotEnterCityYet())
                redraw()
                return
            }
        case .locked:
            state = latestState
            feedback.emit(.invalidAction)
            showFeedback(.locked(cityNumber: cityNumber))
            redraw()
        case .alreadyCompleted:
            state = latestState
            if let unlockedCityNumber = latestState.unlockedMapCityNumber,
               cityNumber < unlockedCityNumber {
                selectedCityNumber = unlockedCityNumber
            }
            feedback.emit(.invalidAction)
            showFeedback(.completed(cityNumber: cityNumber))
            redraw()
        case .countryComplete:
            state = latestState
            redraw()
        }
    }
}

#if DEBUG
extension CountryMapScene {
    var isFeedbackSettingsVisibleForTesting: Bool {
        isFeedbackSettingsVisible
    }

    var feedbackSettingsGearFrameForTesting: CGRect? {
        feedbackSettingsController?.gear.hitFrameForTesting
    }

    var mapResourceFrameForTesting: CGRect? {
        resourcePanel.isHidden ? nil : mapResourceFrame
    }

    var mapGoldTextForTesting: String? {
        resourceLabel.isHidden ? nil : resourceLabel.text
    }

    var mapProgressTextForTesting: String? {
        progressLabel.isHidden ? nil : mapProgressText
    }

    var mapProgressSegmentCountForTesting: Int {
        progressSegments.filter { !$0.isHidden }.count
    }

    var mapProgressCompletedCountForTesting: Int {
        mapProgressCompletedCount
    }

    func activateFeedbackSettingsForTesting(_ action: FeedbackSettingsAction) {
        activateFeedbackSettings(action)
    }

    var titleLabelFrameForTesting: CGRect {
        titlePanel.convert(titleLabel.frame, to: self)
    }

    var lastIdleProgressResultForTesting: KingdomGameState.IdleProgressResult {
        lastIdleProgressResult
    }

    func sceneDidEnterBackgroundForTesting(at date: Date) {
        handleSceneDidEnterBackground(at: date)
    }

    func sceneWillEnterForegroundForTesting(at date: Date) {
        handleSceneWillEnterForeground(at: date)
    }

    var lastLayoutResultForTesting: CountryMapLayoutResult? {
        lastLayoutResult
    }

    var countryMapLayoutForTesting: CountryMapLayout? {
        countryMapLayout
    }

    var isMapUnavailableForTesting: Bool {
        isMapUnavailable
    }

    var isScoutCardFitFailedForTesting: Bool {
        isScoutCardFitFailed
    }

    func setScoutCardFitFailedForTesting(_ value: Bool) {
        isScoutCardFitFailed = value
    }

    var routeLayoutCountForTesting: Int {
        routeLayer.children.count
    }

    var mapLayoutFramesForTesting: CountryMapLayoutFrames {
        CountryMapLayoutFrames(
            sceneFrame: layoutFrames.scene,
            titlePanelFrame: layoutFrames.titlePanel,
            illustratedRegionFrame: layoutFrames.illustratedRegion,
            scoutCardFrame: layoutFrames.scoutCard
        )
    }

    var scoutCardFrameForTesting: CGRect? {
        scoutCardLayout?.cardFrame
    }

    var projectedScoutCardContentForTesting: CountryMapScoutCardContent? {
        guard countryMapLayout != nil, scoutCardLayout != nil else {
            return nil
        }
        return projectedScoutContent
    }

    var scoutCardBaseContentForTesting: CountryMapScoutCardNode.BaseContentReadback? {
        guard scoutCardLayout != nil else { return nil }
        return scoutCardNode.baseContentReadbackForTesting
    }

    var visibleScoutCardTextsForTesting: [String] {
        var texts = [String]()

        func collectVisibleTexts(from node: SKNode, ancestorsAreVisible: Bool) {
            let isVisible = ancestorsAreVisible && !node.isHidden && node.alpha > 0
            guard isVisible else { return }

            if let label = node as? SKLabelNode,
               let text = label.text,
               !text.isEmpty {
                texts.append(text)
            }
            for child in node.children {
                collectVisibleTexts(from: child, ancestorsAreVisible: isVisible)
            }
        }

        collectVisibleTexts(from: scoutCardNode, ancestorsAreVisible: true)
        return texts.sorted()
    }

    var scoutCardHitFrameForTesting: CGRect? {
        scoutCardNode.cardHitFrame
    }

    var scoutCardAttackHitFrameForTesting: CGRect? {
        scoutCardNode.attackHitFrame
    }

    var scoutCardOverlayHitFrameForTesting: CGRect? {
        scoutCardNode.overlayHitFrame
    }

    var visibleFeedbackTextForTesting: String? {
        scoutCardNode.feedbackTextForTesting
    }

    var visibleFeedbackAlphaForTesting: CGFloat {
        scoutCardNode.feedbackAlphaForTesting
    }

    var feedbackElapsedForTesting: TimeInterval? {
        transientFeedback?.elapsed
    }

    var feedbackRemainingDurationForTesting: TimeInterval? {
        transientFeedback.map { max(0, $0.totalDuration - $0.elapsed) }
    }

    func advanceFeedbackForTesting(by deltaTime: TimeInterval) {
        advanceFeedback(by: deltaTime)
    }

    func enterCityForTesting(_ cityNumber: Int) {
        requestEntry(for: cityNumber)
    }

    func requestSelectedCityActionForTesting() {
        requestSelectedCityAction()
    }

    func requestGameplayTabForTesting(_ tab: GameplayTab) {
        requestGameplayTab(tab)
    }

    var selectedCityNumberForTesting: Int? {
        selectedCityNumber
    }

    var gameplayTabBarForTesting: GameplayTabBarNode {
        gameplayTabBar
    }

    var gameplayTabContentForTesting: GameplayTabBarNode.Content {
        gameplayTabContent
    }

    var gameplayTabBarFrameForTesting: CGRect {
        gameplayTabBarFrame
    }

    func cityNumberAtPointForTesting(_ point: CGPoint) -> Int? {
        cityNumber(at: point)
    }

    func cityNodePositionForTesting(_ cityNumber: Int) -> CGPoint? {
        cityNodes[cityNumber]?.position
    }

    func cityLabelPositionForTesting(_ cityNumber: Int) -> CGPoint? {
        cityLabels[cityNumber]?.position
    }

    func cityHitFrameForTesting(_ cityNumber: Int) -> CGRect? {
        cityHitTargets[cityNumber]?.frame
    }

    func conqueredMarkerFrameForTesting(_ cityNumber: Int) -> CGRect? {
        conqueredMarkers[cityNumber]?.frame
    }

    func cityVisualStateForTesting(_ cityNumber: Int) -> CountryMapCityVisualState? {
        cityVisualStates[cityNumber]
    }

    func isUnlockedCityPulseRunningForTesting(_ cityNumber: Int) -> Bool {
        cityNodes[cityNumber]?.action(forKey: ActionKey.unlockedPulse) != nil
    }

    var titleLabelFontSizeForTesting: CGFloat {
        titleLabel.fontSize
    }

    var titleLabelFrameWidthForTesting: CGFloat {
        titleLabel.frame.width
    }

    var isRoutingToBattleForTesting: Bool {
        isRoutingToBattle
    }

    func fitLabelForTesting(_ label: SKLabelNode, maxWidth: CGFloat) {
        fitLabel(label, maxWidth: maxWidth)
    }

    func fitTitleLabelForTesting(_ label: SKLabelNode, maxWidth: CGFloat) -> Bool {
        fitTitleLabel(label, maxWidth: maxWidth)
    }

    func handleTouchForTesting(at point: CGPoint) {
        handleTouch(at: point)
    }

}
#endif
