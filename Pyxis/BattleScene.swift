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
    func battleSceneDidRequestGameplayTab(_ scene: BattleScene, tab: GameplayTab)
    func battleScene(_ scene: BattleScene, didRequestLayoutGate reason: AppLayoutGateReason)
}

final class BattleScene: SKScene, LayoutGateLifecycleHandling, SceneLayoutRefreshable {
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

    private let store: KingdomGameStore
    private weak var router: BattleSceneRouting?
    private let feedback: GameplayFeedbackProviding
    private let feedbackPreferences: FeedbackPreferencesManaging
    private let feedbackSettingsAccessibilityAdapter: FeedbackSettingsAccessibilityAdapter?
    private var feedbackSettingsController: FeedbackSettingsController?
    private var state: KingdomGameState
    private var combat: BattleCombatState
    private var lastUpdateTime: TimeInterval?
    private var isLayoutGatePaused = false
    #if DEBUG
    private var lastAdvanceCombatDeltaForTestingStorage: TimeInterval?
    #endif
    private var soldierNodes: [BattleCombatState.SoldierID: SoldierNodeBundle] = [:]
    private var didBuildInterface = false
    private var isObservingLifecycle = false
    private var selectedManualSoldierType: SoldierType = .infantry
    private let battleHUD = BattleHUDNode()
    private var battleChromeLayout: BattleChromeLayout?
    private(set) var isBattleChromeFitFailed = false
    private let settingsGearHost = SKNode()

    private let battlefieldLayer = SKNode()
    private let environmentLayer = SKNode()
    /// Keeps simulation-coupled SpriteKit actions in one origin-aligned subtree
    /// so Settings can freeze them without pausing HUD or modal interaction.
    private let battlefieldActionLayer = SKNode()
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

    /// Remaining time (in seconds) of each soldier's authored hit-reaction
    /// animation, decremented per combat tick. Used by
    /// `playSoldierAnimation`'s attack guard to suppress attack triggers
    /// while a hit reaction is still playing — see the guard comment for why
    /// this is a combat-tick countdown rather than an SKAction-key check.
    private var soldierHitAnimationRemaining: [BattleCombatState.SoldierID: TimeInterval] = [:]

    /// Memoized per-(type, action) animation textures. Each call to
    /// `soldierAnimationTextures` previously performed ~20 `UIImage(named:)`
    /// lookups plus fresh `SKTexture` allocations; this cache returns the same
    /// `SKTexture` instances across soldiers and across the scene's lifetime.
    /// Textures are keyed by static asset names, so they never need invalidation.
    private var soldierAnimationTextureCache: [SoldierType: [SoldierAnimationAction: [SKTexture]]] = [:]

    /// Memoized result of `firstAvailableSoldierAnimationFrameName` per
    /// `SoldierType`. The probe validates all 30 trio frames (10 walk + 10
    /// attack + 10 hit) and is called from both `createSoldierNode` and
    /// `makeSoldierNode` for every spawn, so without this cache a single
    /// soldier costs 60 `UIImage(named:)` lookups. The value is the walk-01
    /// frame name when the full trio is installed, or `nil` when any frame is
    /// missing (caching the negative result too, so a missing-asset scenario
    /// doesn't re-probe on every spawn). Asset names are static, so the cache
    /// never needs invalidation — mirrors `soldierAnimationTextureCache`.
    private var soldierAnimatedCanvasFrameNameCache: [SoldierType: String?] = [:]

    private var enemyCityImpactPoint: CGPoint {
        battlefieldLayout.enemyCityImpactPoint
    }

    private var currentMilestoneTier: Country1MilestoneTier? {
        guard state.currentCityKey.countryNumber == 1 else { return nil }
        return Country1MilestoneTier.forCity(state.currentCityKey.cityNumber)
    }

    private let feedbackLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let feedbackPanel = PanelNode(size: CGSize(width: 260, height: 34))
    private let milestoneArrivalPanel = PanelNode(size: .zero)
    private let milestoneArrivalTitleLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let milestoneArrivalSubtitleLabel = SKLabelNode(fontNamed: GameUITheme.Font.medium)
    private let milestoneCityAccent = SKShapeNode()
    private let milestoneConquestAccent = SKShapeNode()
    private let countryCompleteLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let cityHPBarBackground = SKShapeNode()
    private let cityHPBarFill = SKShapeNode()
    private let conquestReportNode = ConquestReportNode()
    private var hasPresentedPendingConquestReport = false
    private var isConquestReportVisible = false
    private var isConquestContinueEnabled = true
    private(set) var isConquestReportFitFailed = false
    private var hasPresentedMilestoneArrival = false
    private var isMilestoneArrivalVisible = false
    private var hasPresentedMilestoneConquestFlourish = false
    private var lastAppliedConquestReportContent: ConquestReportContent?
    private var isGoldBurstRemovalScheduled = false
    private var goldBurstRemovalTask: Task<Void, Never>?

    private enum ConquestReportPresentationOrigin { case freshLive, freshIdle, restored }
    #if DEBUG
    private var milestoneArrivalPresentationCountForTestingStorage = 0
    private var lastConquestReportOriginForTestingStorage: ConquestReportPresentationOrigin?
    private var conquestEffectPresentationCountForTestingStorage = 0
    private var lastGoldBurstAnchorForTestingStorage: CGPoint?
    private var lastConquestReportLayoutInputForTestingStorage: ConquestReportLayout.Input?
    private var milestoneConquestFlourishCountForTestingStorage = 0
    private var lastMilestoneFlourishCityForTestingStorage: Int?
    #endif

    private var feedbackText = ""
    private var lastPresentedTooltipText = ""
    /// Cached battle chrome content width from the most recent layout pass.
    /// `showTooltip` reads this instead of recomputing the full metrics struct.
    /// Defaults to a sane positive floor so a tooltip fired before the first
    /// layout pass still gets a non-zero panel width.
    private var cachedContentWidth: CGFloat = 220
    #if DEBUG
    private var battlefieldLayoutCount = 0
    private var soldierAttackAnimationTriggerCount = 0
    private var soldierHitAnimationTriggerCount = 0
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
        feedback: GameplayFeedbackProviding = NoOpGameplayFeedbackProvider(),
        feedbackPreferences: FeedbackPreferencesManaging = MainActor.assumeIsolated {
            FeedbackPreferencesStore.shared
        },
        feedbackSettingsAccessibilityAdapter: FeedbackSettingsAccessibilityAdapter? = nil,
        combatSeed: UInt64? = nil
    ) {
        let loadedState = store.load()
        self.store = store
        self.state = loadedState
        self.combatSeed = combatSeed
        self.combat = Self.makeCombat(for: loadedState, seed: combatSeed)
        self.router = router
        self.feedback = feedback
        self.feedbackPreferences = feedbackPreferences
        self.feedbackSettingsAccessibilityAdapter = feedbackSettingsAccessibilityAdapter
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        let loadedState = KingdomGameStore.shared.load()
        self.store = .shared
        self.state = loadedState
        self.combatSeed = nil
        self.combat = Self.makeCombat(for: loadedState, seed: nil)
        self.router = nil
        self.feedback = NoOpGameplayFeedbackProvider()
        self.feedbackPreferences = FeedbackPreferencesStore.shared
        self.feedbackSettingsAccessibilityAdapter = nil
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

        configureFeedbackSettingsIfNeeded(in: view)

        observeLifecycleNotificationsIfNeeded()
        redraw()

        if state.pendingBattleResult != nil, !hasPresentedPendingConquestReport {
            _ = presentPendingConquestReport(origin: .restored, resetsContinueState: true)
        } else {
            presentMilestoneArrivalIfNeeded()
        }
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

        guard state.stageStatus == .battleActive,
              !isConquestReportVisible,
              !isFeedbackSettingsVisible else {
            return
        }

        advanceCombat(deltaTime: currentTime - lastUpdateTime)
    }

    func layoutGateWillPause(at date: Date) {
        isLayoutGatePaused = true
    }

    func layoutGateWillResume(at date: Date) {
        guard isLayoutGatePaused else {
            return
        }
        isLayoutGatePaused = false
        lastUpdateTime = nil
        #if DEBUG
        lastAdvanceCombatDeltaForTestingStorage = nil
        #endif
        layoutInterface()
    }

    func refreshLayoutForCurrentEnvironment() {
        layoutInterface()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else {
            return
        }
        handleTouch(at: point)
    }

    private func handleTouch(at point: CGPoint) {
        if isConquestReportVisible || isConquestReportFitFailed {
            guard !isConquestReportFitFailed,
                  conquestReportNode.containsContinue(point) else {
                return
            }
            continueFromConquestReport()
            return
        }

        if isMilestoneArrivalVisible {
            dismissMilestoneArrival()
            return
        }

        if let feedbackSettingsController,
           feedbackSettingsController.isVisible {
            _ = feedbackSettingsController.handleTouch(at: point)
            synchronizeBattlefieldActionPause()
            return
        }

        if feedbackSettingsController?.gear.contains(point, in: self) == true {
            openFeedbackSettings()
            return
        }

        if handleBattleHUDTouch(at: point) {
            return
        }

        if let layout = battleChromeLayout {
            if layout.incomeFrame.contains(point) {
                showGoldInfoTooltip()
                return
            }

            if layout.cityProgressFrame.contains(point) {
                showCityInfoTooltip()
                return
            }
        }

    }

    private func handleBattleHUDTouch(at point: CGPoint) -> Bool {
        guard let action = battleHUD.action(at: point) else {
            return false
        }

        switch action {
        case .select(let soldierType):
            selectManualSoldierType(soldierType)
        case .deploy:
            spawnSoldier()
        case .tab(let tab):
            requestGameplayTab(tab)
        case let .requirement(soldierType, unlocksAtCity):
            feedback.emit(.invalidAction)
            if let unlocksAtCity {
                feedbackText = "\(soldierType.displayName) unlocks at City \(unlocksAtCity)."
            } else {
                feedbackText = "Build \(soldierType.displayName) first."
            }
            redraw(shouldLayout: false)
        }
        return true
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
            if state.pendingBattleResult != nil {
                feedbackSettingsController?.setSettingsAccessibilityActionable(false)
            }
        }

        guard let feedbackSettingsController else {
            return
        }

        if feedbackSettingsController.gear.parent !== settingsGearHost {
            settingsGearHost.addChild(feedbackSettingsController.gear)
        }
        // The shared gear is scene-owned and positioned by BattleChromeLayout;
        // keeping it outside BattleHUDNode prevents the HUD from owning modal
        // Settings behavior.
        feedbackSettingsController.gear.zPosition = 2
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

                // Unit-test scenes are deliberately detached from a UIWindow.
                // Their local view coordinates are still finite and let the
                // Settings controller exercise its real accessibility wiring;
                // an attached production scene converts to screen coordinates
                // via UIKit's canonical conversion (full view→window→screen
                // transform chain, not a translation-only offset).
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
        guard !isLayoutGatePaused,
              !isConquestReportVisible,
              !isConquestReportFitFailed,
              let feedbackSettingsController,
              !feedbackSettingsController.isVisible else {
            return
        }

        dismissMilestoneArrival(animated: false)
        guard feedbackSettingsController.open() else {
            return
        }
        synchronizeBattlefieldActionPause()
    }

    private func closeFeedbackSettings(
        focusTarget: FeedbackSettingsFocusTarget = .openingGear
    ) {
        feedbackSettingsController?.close(focusTarget: focusTarget)
        synchronizeBattlefieldActionPause()
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
        synchronizeBattlefieldActionPause()
    }

    private func synchronizeBattlefieldActionPause() {
        let shouldPauseCombatActions = isFeedbackSettingsVisible
        battlefieldActionLayer.isPaused = shouldPauseCombatActions

        // The city itself stays in the static environment layer, but its hit
        // and conquest feedback actions run directly on that node. Pausing the
        // action host freezes those transient effects without hiding the city.
        enemyCityNode?.isPaused = shouldPauseCombatActions
    }

    private func buildInterface() {
        battlefieldLayer.zPosition = 0
        environmentLayer.zPosition = 10
        battlefieldActionLayer.position = .zero
        battlefieldActionLayer.zPosition = 0
        soldierLayer.zPosition = 20
        effectsLayer.zPosition = 30

        addChild(battlefieldLayer)
        battlefieldLayer.addChild(environmentLayer)
        battlefieldLayer.addChild(battlefieldActionLayer)
        battlefieldActionLayer.addChild(soldierLayer)
        battlefieldActionLayer.addChild(effectsLayer)

        buildBattlefield()

        feedbackPanel.name = "feedbackPanel"
        feedbackLabel.name = "feedbackLabel"
        feedbackPanel.zPosition = GameUITheme.Z.hud - 1
        addChild(feedbackPanel)
        addChild(feedbackLabel)

        settingsGearHost.name = "battleSettingsHost"
        settingsGearHost.zPosition = GameUITheme.Z.hud
        addChild(settingsGearHost)

        milestoneArrivalPanel.zPosition = GameUITheme.Z.modal - 1
        milestoneArrivalPanel.isHidden = true
        milestoneArrivalTitleLabel.fontColor = GameUITheme.Color.textPrimary
        milestoneArrivalTitleLabel.horizontalAlignmentMode = .center
        milestoneArrivalTitleLabel.verticalAlignmentMode = .center
        milestoneArrivalSubtitleLabel.fontColor = GameUITheme.Color.textSecondary
        milestoneArrivalSubtitleLabel.horizontalAlignmentMode = .center
        milestoneArrivalSubtitleLabel.verticalAlignmentMode = .center
        milestoneArrivalPanel.addChild(milestoneArrivalTitleLabel)
        milestoneArrivalPanel.addChild(milestoneArrivalSubtitleLabel)
        addChild(milestoneArrivalPanel)

        milestoneCityAccent.fillColor = .clear
        milestoneCityAccent.strokeColor = GameUITheme.Color.gold
        milestoneCityAccent.isHidden = true
        environmentLayer.addChild(milestoneCityAccent)

        milestoneConquestAccent.fillColor = .clear
        milestoneConquestAccent.strokeColor = GameUITheme.Color.gold
        milestoneConquestAccent.zPosition = GameUITheme.Z.modal - 0.25
        milestoneConquestAccent.isHidden = true
        addChild(milestoneConquestAccent)

        countryCompleteLabel.text = "Country 1 Complete"
        countryCompleteLabel.fontColor = GameUITheme.Color.gold
        countryCompleteLabel.horizontalAlignmentMode = .center
        countryCompleteLabel.verticalAlignmentMode = .center
        countryCompleteLabel.zPosition = GameUITheme.Z.modal + 0.25
        countryCompleteLabel.isHidden = true
        addChild(countryCompleteLabel)

        feedbackLabel.fontSize = 15
        feedbackLabel.fontColor = GameUITheme.Color.gold
        feedbackLabel.horizontalAlignmentMode = .center
        feedbackLabel.verticalAlignmentMode = .center

        conquestReportNode.zPosition = GameUITheme.Z.modal
        battleHUD.zPosition = GameUITheme.Z.hud
        feedbackLabel.zPosition = GameUITheme.Z.hud

        addChild(battleHUD)
        addChild(conquestReportNode)

        feedbackPanel.alpha = 0
        feedbackLabel.alpha = 0
    }

    private func layoutInterface() {
        guard didBuildInterface else {
            return
        }

        layoutForgedInterface()
    }

    private func layoutForgedInterface() {
        let insets = view?.safeAreaInsets ?? .zero
        let chromeInput = BattleChromeLayout.Input(
            sceneSize: size,
            safeAreaInsets: .init(
                top: insets.top,
                left: insets.left,
                bottom: insets.bottom,
                right: insets.right
            )
        )

        guard let layout = BattleChromeLayout.compute(chromeInput) else {
            battleChromeLayout = nil
            battleHUD.isHidden = true
            setBattlefieldHidden(true)
            removeLaneNodes()
            removeLaneIndicatorNodes()
            setBattleChromeFitFailed(true)
            feedbackSettingsController?.applyGearFrame(.zero)
            // Keep an already-open Settings modal alive while the app-level
            // unsupported-geometry gate is presented. Recovery below reapplies
            // the newly fitted layout without synthesizing a close/catch-up.
            return
        }

        battleChromeLayout = layout
        setBattleChromeFitFailed(false)
        layoutBattlefield(
            contentWidth: layout.battlefieldFrame.width,
            hpBarBottomY: layout.battlefieldFrame.maxY,
            fieldBottomY: layout.battlefieldFrame.minY,
            feedbackY: layout.battlefieldFrame.minY,
            precomputed: layout.battlefield
        )
        applyBattleHUD()

        if let feedbackSettingsController {
            feedbackSettingsController.applyGearFrame(layout.settingsFrame)
            feedbackSettingsController.gear.position = settingsGearHost.convert(
                CGPoint(x: layout.settingsFrame.midX, y: layout.settingsFrame.midY),
                from: self
            )
            feedbackSettingsController.reapply(layout: feedbackSettingsLayoutForCurrentEnvironment())
            synchronizeBattlefieldActionPause()
        }

        feedbackLabel.position = CGPoint(
            x: layout.feedbackFrame.midX,
            y: layout.feedbackFrame.midY
        )
        feedbackPanel.position = feedbackLabel.position
        cachedContentWidth = layout.safeFrame.width

        if state.pendingBattleResult != nil,
           hasPresentedPendingConquestReport || isConquestReportFitFailed {
            _ = applyPendingConquestReport(resetsContinueState: false)
        }

        if isMilestoneArrivalVisible {
            _ = layoutMilestoneArrival()
        }
    }

    private func setBattleChromeFitFailed(_ value: Bool) {
        guard isBattleChromeFitFailed != value else {
            return
        }

        isBattleChromeFitFailed = value
        if value {
            router?.battleScene(self, didRequestLayoutGate: .unsupportedGeometry)
        }
    }

    private func applyBattleHUD() {
        guard let layout = battleChromeLayout,
              !isConquestReportVisible,
              !isConquestReportFitFailed else {
            battleHUD.isHidden = true
            return
        }

        let content = BattleHUDContent.project(
            from: state,
            manualLivingSoldierCount: combat.livingSoldierCount(source: .manual),
            selectedSoldierType: selectedManualSoldierType
        )
        switch battleHUD.apply(content: content, layout: layout) {
        case .presented:
            setBattleChromeFitFailed(false)
        case .requiredContentDoesNotFit:
            battleHUD.isHidden = true
            setBattleChromeFitFailed(true)
        }
    }

    private func fitMilestoneLabel(
        _ label: SKLabelNode,
        fontName: String,
        startingAt: CGFloat,
        minimum: CGFloat,
        maximumWidth: CGFloat
    ) -> Bool {
        guard let text = label.text,
              let size = SingleLineTextFitter.fittedFontSize(
                  text,
                  startingAt: startingAt,
                  minimum: minimum,
                  maximumWidth: maximumWidth,
                  measure: { candidate, fontSize in
                      let font = UIFont(name: fontName, size: fontSize)
                          ?? UIFont.systemFont(ofSize: fontSize)
                      return (candidate as NSString).size(withAttributes: [.font: font]).width
                  }
              ) else {
            return false
        }
        label.fontName = fontName
        label.fontSize = size
        return true
    }

    @discardableResult
    private func layoutMilestoneArrival() -> Bool {
        guard isMilestoneArrivalVisible || hasPresentedMilestoneArrival else { return false }

        let insets = view?.safeAreaInsets ?? .zero
        let safeWidth = size.width - insets.left - insets.right
        let safeHeight = size.height - insets.top - insets.bottom
        let compactHeight = battleChromeLayout?.isCompact ?? (size.height < 780)
        let contentWidth = battleChromeLayout?.topBandFrame.width
            ?? min(560, max(0, safeWidth - BattleChromeLayout.sideMargin * 2))
        let width = min(contentWidth, safeWidth - 24)
        let height: CGFloat = compactHeight ? 64 : 76
        guard width >= 120, safeHeight >= height + 24 else {
            finishMilestoneArrivalDismissal()
            return false
        }

        let safeMinY = insets.bottom + 12
        let safeMaxY = size.height - insets.top - 12
        let desiredCenterY = battlefieldLayout.isVisible
            ? battlefieldLayout.frame.midY
            : (safeMinY + safeMaxY) / 2
        let centerY = min(max(desiredCenterY, safeMinY + height / 2), safeMaxY - height / 2)

        milestoneArrivalPanel.update(size: CGSize(width: width, height: height))
        milestoneArrivalPanel.position = CGPoint(x: size.width / 2, y: centerY)
        milestoneArrivalTitleLabel.position = CGPoint(x: 0, y: height * 0.18)
        milestoneArrivalSubtitleLabel.position = CGPoint(x: 0, y: -height * 0.18)

        let titleFits = fitMilestoneLabel(
            milestoneArrivalTitleLabel,
            fontName: GameUITheme.Font.bold,
            startingAt: compactHeight ? 17 : 20,
            minimum: 12,
            maximumWidth: width - 24
        )
        let subtitleFits = fitMilestoneLabel(
            milestoneArrivalSubtitleLabel,
            fontName: GameUITheme.Font.medium,
            startingAt: compactHeight ? 12 : 14,
            minimum: 12,
            maximumWidth: width - 24
        )
        let localBounds = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)
        guard titleFits,
              subtitleFits,
              localBounds.contains(milestoneArrivalTitleLabel.frame),
              localBounds.contains(milestoneArrivalSubtitleLabel.frame),
              !milestoneArrivalTitleLabel.frame.intersects(milestoneArrivalSubtitleLabel.frame) else {
            finishMilestoneArrivalDismissal()
            return false
        }
        return true
    }

    private func presentMilestoneArrivalIfNeeded() {
        guard state.stageStatus == .battleActive,
              state.pendingBattleResult == nil,
              currentMilestoneTier != nil,
              !hasPresentedMilestoneArrival,
              let definition = Country1CityCatalog.definitionIfPresent(
                  for: state.currentCityKey.cityNumber
              ) else {
            return
        }

        hasPresentedMilestoneArrival = true
        isMilestoneArrivalVisible = true
        milestoneArrivalTitleLabel.text = definition.displayTitle
        milestoneArrivalSubtitleLabel.text = definition.flavorText
        guard layoutMilestoneArrival() else { return }

        milestoneArrivalPanel.isHidden = false
        milestoneArrivalPanel.alpha = 0
        milestoneArrivalPanel.setScale(UIAccessibility.isReduceMotionEnabled ? 1 : 0.97)
        #if DEBUG
        milestoneArrivalPresentationCountForTestingStorage += 1
        #endif

        let appear = UIAccessibility.isReduceMotionEnabled
            ? SKAction.fadeIn(withDuration: 0.15)
            : SKAction.group([
                SKAction.fadeIn(withDuration: 0.15),
                SKAction.scale(to: 1, duration: 0.15)
            ])
        let wait = SKAction.wait(forDuration: 1.15)
        let disappear = SKAction.fadeOut(withDuration: 0.20)
        let finish = SKAction.run { [weak self] in
            self?.finishMilestoneArrivalDismissal()
        }
        milestoneArrivalPanel.run(
            SKAction.sequence([appear, wait, disappear, finish]),
            withKey: "milestoneArrival"
        )
    }

    private func finishMilestoneArrivalDismissal() {
        milestoneArrivalPanel.removeAllActions()
        milestoneArrivalPanel.isHidden = true
        milestoneArrivalPanel.alpha = 1
        milestoneArrivalPanel.setScale(1)
        isMilestoneArrivalVisible = false
    }

    private func dismissMilestoneArrival(animated: Bool = true) {
        guard isMilestoneArrivalVisible || !milestoneArrivalPanel.isHidden else { return }
        isMilestoneArrivalVisible = false
        milestoneArrivalPanel.removeAllActions()
        guard animated else {
            finishMilestoneArrivalDismissal()
            return
        }
        milestoneArrivalPanel.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.10),
            SKAction.run { [weak self] in self?.finishMilestoneArrivalDismissal() }
        ]))
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
        fieldBottomY: CGFloat,
        feedbackY: CGFloat,
        precomputed: BattlefieldLayout? = nil
    ) {
        #if DEBUG
        battlefieldLayoutCount += 1
        #endif

        battlefieldLayout = precomputed ?? BattlefieldLayout.compute(constraints: .init(
                sceneSize: size,
                contentWidth: contentWidth,
                safeTopY: hpBarBottomY - 8,
                safeBottomY: fieldBottomY + 2,
                feedbackY: feedbackY,
                feedbackFontSize: 0
            ))

        if !isConquestReportVisible {
            cancelCityFeedbackActions()
        }

        if !battlefieldLayout.isVisible {
            setBattlefieldHidden(true)
            removeLaneNodes()
            removeLaneIndicatorNodes()
            layoutMilestoneCityAccent()
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
        layoutMilestoneCityAccent()
    }

    private func layoutMilestoneCityAccent() {
        guard let tier = currentMilestoneTier,
              battlefieldLayout.isVisible,
              let enemyCityNode else {
            milestoneCityAccent.isHidden = true
            milestoneCityAccent.path = nil
            return
        }

        let cityFrame = enemyCityNode.calculateAccumulatedFrame()
        let expansion: CGFloat
        switch tier {
        case .first:
            expansion = 5
        case .second:
            expansion = 7
        case .finale:
            expansion = 9
        }

        let insets = view?.safeAreaInsets ?? .zero
        let safeFrame = CGRect(
            x: insets.left,
            y: insets.bottom,
            width: max(0, size.width - insets.left - insets.right),
            height: max(0, size.height - insets.top - insets.bottom)
        )
        let accentFrame = cityFrame
            .insetBy(dx: -expansion, dy: -expansion)
            .intersection(safeFrame)
        guard !accentFrame.isNull, accentFrame.width > 0, accentFrame.height > 0 else {
            milestoneCityAccent.isHidden = true
            milestoneCityAccent.path = nil
            return
        }

        milestoneCityAccent.path = CGPath(
            roundedRect: accentFrame,
            cornerWidth: 12,
            cornerHeight: 12,
            transform: nil
        )
        switch tier {
        case .first:
            milestoneCityAccent.lineWidth = 2
            milestoneCityAccent.glowWidth = 1
        case .second:
            milestoneCityAccent.lineWidth = 3
            milestoneCityAccent.glowWidth = 3
        case .finale:
            milestoneCityAccent.lineWidth = 4
            milestoneCityAccent.glowWidth = 5
        }
        milestoneCityAccent.isHidden = false
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

    private func redraw(shouldLayout: Bool = true) {
        reconcileSelectedManualSoldierType()
        feedbackLabel.text = feedbackText
        if shouldLayout {
            layoutInterface()
        } else {
            layoutCityHPBar()
            applyBattleHUD()
        }
        presentFeedbackTooltipIfNeeded()
    }

    private func refreshBattleHUD() {
        applyBattleHUD()
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

    private func advanceCombat(deltaTime: TimeInterval) {
        guard state.stageStatus == .battleActive,
              !isConquestReportVisible,
              !isFeedbackSettingsVisible else {
            return
        }

        let clampedDeltaTime = combat.clampedDeltaTime(deltaTime)
        if clampedDeltaTime > 0 {
            state.recordActiveBattleTime(clampedDeltaTime)
        }

        #if DEBUG
        lastAdvanceCombatDeltaForTestingStorage = deltaTime
        #endif

        let shouldSaveBuildingProgress = deltaTime > 0 && state.cityBattleStateForCurrentCity.occupiedSlotCount > 0
        let buildingSpawns = state.resolveActiveBuildingSpawns(deltaTime: deltaTime)
        for spawn in buildingSpawns {
            let soldierID = combat.spawnSoldier(
                type: spawn.soldierType,
                source: .building,
                level: spawn.level,
                attackPower: state.traitAdjustedSoldierAttackPower(for: spawn.soldierType, level: spawn.level)
            )
            if let soldier = combat.soldier(id: soldierID) {
                state.recordSoldierDeployment(type: soldier.type, source: soldier.source, lane: soldier.lane)
            }
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

        // Decrement hit-reaction countdowns BEFORE combat.tick arms any new
        // timers in applyCombatResult. Arming at 0.9s and then subtracting
        // deltaTime in the same tick would shorten every hit animation by one
        // frame; decrementing first means timers armed this tick keep their
        // full authored duration and are first reduced on the next tick.
        //
        // The countdown is decremented by the RAW frame delta, not the clamped
        // combat delta. The hit SKAction advances by real frame time (SpriteKit
        // does not clamp SKAction deltas), so the countdown must track the same
        // clock to stay in sync with the visual pose. Clamping the countdown to
        // `maxDeltaTime` would make it lag behind the SKAction during a stall
        // longer than the hit duration: the SKAction would finish and remove
        // itself while the countdown still reported time remaining, falsely
        // suppressing the next attack trigger even though no hit pose is
        // playing. The combat tick's attack cooldown is still clamped, so
        // attack IDs cannot fire faster than the clamped combat clock — the
        // countdown lifting early cannot produce an attack that the combat
        // tick hasn't authorized. Building spawn resolution also uses the raw
        // `deltaTime` so production reflects real elapsed time during stalls.
        decrementSoldierHitAnimationRemaining(deltaTime: deltaTime)
        let result = combat.tick(deltaTime: deltaTime, cityRemainingHP: state.cityRemainingPower)
        feedback.emitAutomaticCombat(result)
        applyCombatResult(result)
        syncSoldierNodes()
        if !buildingSpawns.isEmpty {
            applyBattleHUD()
        }
    }

    /// Advances the per-soldier hit-reaction countdown by `deltaTime`,
    /// removing entries that have elapsed. Driven by the combat tick (not
    /// the SpriteKit render loop) so it advances identically in production
    /// and in `advanceCombatForTesting`-driven tests.
    private func decrementSoldierHitAnimationRemaining(deltaTime: TimeInterval) {
        guard !soldierHitAnimationRemaining.isEmpty, deltaTime > 0 else {
            return
        }
        var decremented: [BattleCombatState.SoldierID: TimeInterval] = [:]
        for (id, remaining) in soldierHitAnimationRemaining {
            let newValue = remaining - deltaTime
            // Snap to zero below a 1ms epsilon to avoid floating-point
            // residue (e.g. 1.4e-16 after nine 0.1s steps from 0.9s) that
            // would otherwise keep the suppression active past the authored
            // hit duration and block the next attack trigger.
            if newValue > 0.001 {
                decremented[id] = newValue
            }
        }
        soldierHitAnimationRemaining = decremented
    }

    private func applyCombatResult(_ result: BattleCombatState.TickResult) {
        for towerShot in result.towerShots {
            playTowerShot(at: towerShot.soldierID)
        }

        for attack in result.soldierAttacks {
            playSoldierAttackFeedback(for: attack.soldierID)
        }

        let killedIDs = Set(result.soldierLosses.map(\.soldierID))

        for soldierID in result.damagedSoldierIDs {
            playSoldierHitFeedback(for: soldierID, schedulesRemoval: killedIDs.contains(soldierID))
        }

        // Note: `killedIDs` is a structural subset of `damagedSoldierIDs`
        // (BattleCombatState appends to both in the same tower-shot block), so
        // every killed soldier is already routed through playSoldierHitFeedback
        // above with schedulesRemoval=true. No separate killed-loop is needed.

        if !result.soldierLosses.isEmpty {
            applyBattleHUD()
        }

        state.recordSoldierLosses(result.soldierLosses)

        guard !result.soldierAttacks.isEmpty else {
            if !result.soldierLosses.isEmpty {
                store.save(state)
                refreshBattleHUD()
            }
            return
        }

        let damageResult = state.applyLiveSoldierAttacks(result.soldierAttacks)
        guard damageResult.attackApplied else {
            return
        }

        let conqueredCity = damageResult.conqueredCities > 0
        let damageText = CompactNumberFormatter.string(from: damageResult.damageDealt)

        if conqueredCity {
            feedbackSettingsController?.setSettingsAccessibilityActionable(false)
            closeFeedbackSettings(focusTarget: .systemDefault)
            clearLiveCombat()
            // The conquest popup communicates the result; clear any stale
            // feedback so the tooltip doesn't present behind the overlay and
            // linger after the popup closes. Clearing (rather than just not
            // setting) also covers a stale message left over from an earlier
            // damage tick whose tooltip has already faded (dedupe token reset).
            feedbackText = ""
        } else {
            feedbackText = "Soldiers dealt \(damageText) damage."
        }

        persistLiveCombatStateAndEmitFreshOutcomeFeedback(
            goldEarned: damageResult.goldEarned,
            conqueredCities: damageResult.conqueredCities
        )
        redraw(shouldLayout: conqueredCity)

        if conqueredCity {
            if presentPendingConquestReport(origin: .freshLive, resetsContinueState: true) {
                playFloatingFeedback(text: "-\(damageText)", at: enemyCityImpactPoint)
                playCityConquestFeedback()
            }
        } else {
            playFloatingFeedback(text: "-\(damageText)", at: enemyCityImpactPoint)
            playCityHitFeedback()
        }
    }

    private func persistLiveCombatStateAndEmitFreshOutcomeFeedback(
        goldEarned: Int,
        conqueredCities: Int
    ) {
        store.save(state)
        emitFreshOutcomeFeedback(
            goldEarned: goldEarned,
            conqueredCities: conqueredCities
        )
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
            assertionFailure("Fresh Battle outcome did not advance stage status")
        }
    }

    private func spawnSoldier() {
        guard !isConquestReportVisible, state.stageStatus == .battleActive else {
            return
        }

        guard let manualSoldierLevel = state.manualSoldierLevel(for: selectedManualSoldierType) else {
            feedback.emit(.invalidAction)
            feedbackText = manualSpawnableSoldierTypes.isEmpty
                ? "Build a unit building first."
                : "Build \(selectedManualSoldierType.displayName) first."
            redraw()
            return
        }

        guard combat.livingSoldierCount(source: .manual) < KingdomGameState.manualSoldierCap else {
            feedback.emit(.invalidAction)
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
        if let soldier = combat.soldier(id: soldierID) {
            state.recordSoldierDeployment(type: soldier.type, source: soldier.source, lane: soldier.lane)
            feedback.emit(.manualDeployment)
        }
        createSoldierNode(id: soldierID)
        syncSoldierNodes()
        applyBattleHUD()
    }

    private func selectManualSoldierType(_ type: SoldierType) {
        guard !isConquestReportVisible, state.stageStatus == .battleActive else {
            return
        }

        guard manualSpawnableSoldierTypes.contains(type) else {
            feedback.emit(.invalidAction)
            feedbackText = "Build \(type.displayName) first."
            redraw(shouldLayout: false)
            return
        }

        selectedManualSoldierType = type
        redraw(shouldLayout: false)
    }

    private func showGoldInfoTooltip() {
        showTooltip("Gold \(CompactNumberFormatter.string(from: state.gold)) | Soldiers \(combat.livingSoldierCount)")
    }

    private func showCityInfoTooltip() {
        showTooltip(
            "\(state.displayCityTitle) | \(state.currentCityDefenseTrait.displayName) | HP "
                + "\(CompactNumberFormatter.string(from: state.cityRemainingPower))/\(CompactNumberFormatter.string(from: state.cityMaxPower))"
        )
    }

    private func requestGameplayTab(_ tab: GameplayTab) {
        guard !isConquestReportVisible,
              state.stageStatus == .battleActive,
              tab != .battle else {
            return
        }

        guard combat.livingSoldierCount(source: .manual) == 0 else {
            feedback.emit(.invalidAction)
            feedbackText = tab == .map
                ? "Finish the current squad before viewing world."
                : "Finish the current squad before building."
            redraw()
            return
        }

        state.markCurrentCityBuildingProgressInactive(at: Date())
        store.save(state)
        router?.battleSceneDidRequestGameplayTab(
            self,
            tab: tab
        )
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
            // Formation rows extend downward without bound (there is no global
            // live-soldier cap for building-driven spawns). During a long battle
            // enough same-lane soldiers would push the back rows below the
            // battlefield frame, where they keep dealing combat damage with
            // invisible bodies and HP bars. Clamp the root y to the battlefield
            // floor so overflow soldiers stack at the bottom edge instead of
            // disappearing — the front-row soldier stays at the attack position
            // and only the overflow tail is pulled in.
            let unclampedY = lanePoint.y + formationOffset.y - footMargin
            let battlefieldFloorY = battlefieldLayout.frame.minY
            bundle.root.position = CGPoint(
                x: lanePoint.x + formationOffset.x,
                y: max(battlefieldFloorY, unclampedY)
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
        soldierHitAnimationRemaining.removeAll()

        applyBattleHUD()
    }

    private func removeSoldierNode(id: BattleCombatState.SoldierID, animated: Bool) {
        guard let bundle = soldierNodes.removeValue(forKey: id) else {
            return
        }
        pendingAnimatedRemovalSoldierIDs.remove(id)
        soldierHitAnimationRemaining.removeValue(forKey: id)

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
            // Both the animated canvas and the static sprite asset are missing.
            // This is almost always a build/asset mistake; in DEBUG we fail
            // loudly so it gets noticed, mirroring `soldierAnimationTextures`.
            // In release we keep the colored-rectangle fallback so a missing
            // asset never crashes the game, but it should never ship this far.
            #if DEBUG
            assertionFailure(
                "Missing soldier asset for \(type.rawValue) (no animated canvas or static sprite \"\(assetName)\")"
            )
            #endif
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
    /// by checking every frame of every action in the trio (10 walk + 10
    /// attack + 10 hit = 30 frames). Returns the walk-01 frame name only when
    /// the complete trio is installed, so `isAnimatedCanvas` is true only for
    /// a fully authored set — a partial set (e.g. walk + attack but no hit, or
    /// a hand-edited mid-sequence drop like `cavalry-walk-07` removed while
    /// `cavalry-walk-01` is kept) falls through to the static sprite path
    /// instead of leaving `playSoldierAnimation` to silently no-op the
    /// missing action while the soldier keeps walking.
    ///
    /// This is stricter than the previous first-frame-only probe, which left a
    /// gap: a mid-sequence drop kept `isAnimatedCanvas == true`, then
    /// `soldierAnimationTextures(for:action:)` returned an empty array for the
    /// incomplete action (firing `assertionFailure` in DEBUG) and
    /// `playSoldierAnimation` silently no-oped in release, leaving a frozen or
    /// partially animated soldier instead of using the static fallback.
    /// Requiring all 30 frames here closes that gap at the gate.
    ///
    /// The full 30-frame trio is also guarded synchronously at test time by
    /// `PyxisTests.allSoldierAnimationFramesAreInstalled`, and the all-or-nothing
    /// storyboard validation in `tools/slice_soldier_animation_strips.py` makes
    /// a partial trio unlikely in practice — this probe is the runtime safety
    /// net. Results are memoized in `soldierAnimatedCanvasFrameNameCache`
    /// because the probe is called twice per soldier (once in
    /// `createSoldierNode`, once in `makeSoldierNode`) and 30 `UIImage(named:)`
    /// lookups per call would otherwise dominate spawn cost.
    private func firstAvailableSoldierAnimationFrameName(for type: SoldierType) -> String? {
        if let cached = soldierAnimatedCanvasFrameNameCache[type] {
            return cached
        }
        let walkFrameNames = soldierAnimationFrameNames(for: type, action: .walk)
        guard let firstWalkFrameName = walkFrameNames.first,
              walkFrameNames.allSatisfy({ UIImage(named: $0) != nil }) else {
            soldierAnimatedCanvasFrameNameCache[type] = .some(nil)
            return nil
        }
        for action in SoldierAnimationAction.allCases where action != .walk {
            let actionFrameNames = soldierAnimationFrameNames(for: type, action: action)
            guard !actionFrameNames.isEmpty,
                  actionFrameNames.allSatisfy({ UIImage(named: $0) != nil }) else {
                soldierAnimatedCanvasFrameNameCache[type] = .some(nil)
                return nil
            }
        }
        soldierAnimatedCanvasFrameNameCache[type] = firstWalkFrameName
        return firstWalkFrameName
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
              bundle.isAnimatedCanvas,
              let sprite = bundle.body as? SKSpriteNode,
              sprite.action(forKey: SoldierAnimationKey.walk) == nil,
              sprite.action(forKey: SoldierAnimationKey.attack) == nil,
              sprite.action(forKey: SoldierAnimationKey.hit) == nil else {
            return
        }

        // `isAnimatedCanvas` is false when the catalog is missing any of the
        // 30 trio frames (see `firstAvailableSoldierAnimationFrameName`). In
        // that case the node was built on the static-fallback path and sized
        // via `fitBattleNode` to the static sprite's intrinsic dimensions, not
        // the animation canvas geometry. Starting full-canvas walk textures on
        // it would display the 128×128 canvas at the wrong size. The same gate
        // is applied in `playSoldierAnimation` for transient (attack/hit)
        // playback — without it, a partial catalog where one action is
        // complete but another is missing would let the complete action's
        // full-canvas textures be installed on the differently-sized static
        // sprite, mixing fallback and animated rendering.
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
              bundle.isAnimatedCanvas,
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
        // should override the attack pose), so the attack-action check is
        // attack-only with respect to *re-triggering the same action*.
        //
        // The guard also suppresses attack triggers while a hit reaction is
        // still playing, but ONLY for soldier types whose hit duration
        // exceeds their attack interval (currently cavalry: 0.9s hit vs
        // ~0.87s attack interval). For those types, the next attack tick
        // would always land mid-hit and the remove-all-transient-keys block
        // below would cut off the authored hit reaction. Treating the hit as
        // higher priority lets it finish, resume walk, and the next attack
        // tick starts a fresh attack cycle. This only affects the *visual*
        // pose — combat damage is applied by BattleCombatState.tick
        // regardless of which animation is playing.
        //
        // For types where hit < attack interval (infantry, archer, mage,
        // siege), the hit usually finishes before the next attack tick, so
        // the attack replaces an already-completed hit (not a cut-off).
        // Suppressing attacks for those types would cause a severe visual
        // regression — the tower re-arms the 0.9s hit timer every 1.25s,
        // so the suppression would be active ~72% of the time and soldiers
        // would barely visually attack. The occasional 0.25s hit cut-off
        // for those types is the accepted pre-review behavior.
        //
        // The hit check uses a combat-tick-driven countdown
        // (`soldierHitAnimationRemaining`) rather than
        // `sprite.action(forKey: .hit) != nil` because the test suite drives
        // combat via `advanceCombatForTesting` without a SpriteKit render
        // loop — installed SKActions never advance in tests, so an
        // action-key check would suppress attacks forever after the first
        // hit. The countdown is decremented in `advanceCombat` and lifts
        // after the authored hit duration elapses, matching production
        // behavior where the SKAction completes and removes itself.
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
        let hitDurationExceedsAttackInterval =
            SoldierAnimationTiming.totalDuration(for: .hit, type: soldierType)
                > combat.attackInterval(for: soldierType)
        let attackAnimationInProgress = sprite.action(forKey: SoldierAnimationKey.attack) != nil
        let hitReactionBlockingNextAttack = hitDurationExceedsAttackInterval
            && (soldierHitAnimationRemaining[soldierID] ?? 0) > 0
        if action == .attack,
           attackAnimationInProgress || hitReactionBlockingNextAttack {
            return
        }

        #if DEBUG
        switch action {
        case .attack:
            soldierAttackAnimationTriggerCount += 1
        case .hit:
            soldierHitAnimationTriggerCount += 1
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
            // Arm the hit-reaction countdown so the attack guard can defer
            // attack triggers that would land before this animation finishes
            // (e.g. cavalry: 0.87s attack interval vs 0.9s hit duration).
            soldierHitAnimationRemaining[soldierID] =
                SoldierAnimationTiming.totalDuration(for: .hit, type: soldierType)
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
        handleSceneDidEnterBackground(at: Date())
    }

    @objc private func sceneWillEnterForeground(_ notification: Notification) {
        handleSceneWillEnterForeground(at: Date())
    }

    private func handleSceneDidEnterBackground(at date: Date) {
        state.enterBackground(at: date)
        store.save(state)
        clearLiveCombat()
    }

    private func handleSceneWillEnterForeground(at date: Date) {
        let result = state.returnFromBackground(at: date)

        store.save(state)
        reconcileSelectedManualSoldierType()

        if result.elapsedSeconds > 0 {
            if result.conqueredCities > 0 {
                feedbackSettingsController?.setSettingsAccessibilityActionable(false)
                closeFeedbackSettings(focusTarget: .systemDefault)
                emitFreshOutcomeFeedback(
                    goldEarned: result.goldEarned,
                    conqueredCities: result.conqueredCities
                )
                clearLiveCombat()
                // The conquest popup communicates the result; clear any stale
                // feedback so the tooltip doesn't present behind the overlay and
                // linger after the popup closes. Mirrors the live-combat conquest
                // path. Clearing (rather than just not setting) also covers a
                // stale message left over from before backgrounding.
                feedbackText = ""
            } else if result.damageDealt > 0 {
                feedbackText = "Buildings dealt \(CompactNumberFormatter.string(from: result.damageDealt)) idle damage."
            } else {
                feedbackText = "No building damage while away."
            }
        }

        redraw()

        if result.conqueredCities > 0 {
            _ = presentPendingConquestReport(origin: .freshIdle, resetsContinueState: true)
        }
    }

    private static func isPendingResultPresentable(
        _ result: BattleResult,
        currentCityKey: CityKey
    ) -> Bool {
        result.cityKey == currentCityKey
    }

    private func pendingResultForPresentation() -> BattleResult? {
        guard let result = state.pendingBattleResult else { return nil }
        guard Self.isPendingResultPresentable(result, currentCityKey: state.currentCityKey) else {
            assertionFailure("Pending BattleResult city does not match current city")
            // A stale pending result whose city no longer matches the current
            // city would re-launch BattleScene and re-fail on every subsequent
            // presentation (GameViewController routes on a non-nil pending
            // result regardless of stageStatus). Clear and persist it so the
            // app falls back to normal stage-status routing on the next
            // launch instead of looping on the unpresentable result. This
            // branch is unreachable in practice — KingdomGameState.init
            // normalizes mismatched pending results to nil on construct and
            // decode, and completeCurrentCity guards on city match before
            // setting pendingBattleResult — so the assertionFailure is the
            // real tripwire; the acknowledge+save is defense-in-depth.
            state.acknowledgePendingBattleResult()
            store.save(state)
            return nil
        }
        return result
    }

    private func conquestReportContent(for result: BattleResult) -> ConquestReportContent {
        .project(
            from: result,
            title: KingdomGameState.displayConquestTitle(for: result.cityKey)
        )
    }

    private func conquestReportLayout(
        for content: ConquestReportContent,
        result: BattleResult
    ) -> ConquestReportLayout? {
        let insets = view?.safeAreaInsets ?? .zero
        let safeWidth = size.width - insets.left - insets.right
        let compactHeight = battleChromeLayout?.isCompact ?? (size.height < 780)
        let contentWidth = battleChromeLayout?.topBandFrame.width
            ?? min(560, max(0, safeWidth - BattleChromeLayout.sideMargin * 2))
        let tier = result.cityKey.countryNumber == 1
            ? Country1MilestoneTier.forCity(result.cityKey.cityNumber)
            : nil
        let input = ConquestReportLayout.Input(
            sceneSize: size,
            safeAreaInsets: .init(top: insets.top, left: insets.left,
                                  bottom: insets.bottom, right: insets.right),
            battleContentWidth: contentWidth,
            tileCount: content.tiles.count,
            chipCount: content.achievements.count,
            compactHeight: compactHeight,
            includesCountryCompletion: tier?.isCountryFinale == true
        )
        #if DEBUG
        lastConquestReportLayoutInputForTestingStorage = input
        #endif
        return .compute(input)
    }

    private func applyMilestoneConquestPresentation(
        result: BattleResult,
        layout: ConquestReportLayout
    ) -> Bool {
        let tier = result.cityKey.countryNumber == 1
            ? Country1MilestoneTier.forCity(result.cityKey.cityNumber)
            : nil
        guard let tier else {
            milestoneConquestAccent.isHidden = true
            milestoneConquestAccent.path = nil
            countryCompleteLabel.isHidden = true
            return true
        }

        let expansion: CGFloat
        switch tier {
        case .first:
            expansion = 5
            milestoneConquestAccent.lineWidth = 2
            milestoneConquestAccent.glowWidth = 1
        case .second:
            expansion = 7
            milestoneConquestAccent.lineWidth = 3
            milestoneConquestAccent.glowWidth = 3
        case .finale:
            expansion = 9
            milestoneConquestAccent.lineWidth = 4
            milestoneConquestAccent.glowWidth = 5
        }
        var accentFrame = layout.panelFrame
            .insetBy(dx: -expansion, dy: -expansion)
            .intersection(layout.safeFrame)
        if let completion = layout.countryCompleteFrame,
           accentFrame.maxY > completion.minY - 2 {
            accentFrame.size.height = max(0, completion.minY - 2 - accentFrame.minY)
        }
        if accentFrame.width > 0, accentFrame.height > 0 {
            milestoneConquestAccent.path = CGPath(
                roundedRect: accentFrame,
                cornerWidth: layout.panelCornerRadius + 4,
                cornerHeight: layout.panelCornerRadius + 4,
                transform: nil
            )
            milestoneConquestAccent.isHidden = false
        } else {
            milestoneConquestAccent.isHidden = true
            milestoneConquestAccent.path = nil
        }

        guard tier.isCountryFinale else {
            countryCompleteLabel.isHidden = true
            return true
        }
        guard let frame = layout.countryCompleteFrame else {
            assertionFailure("Finale report layout omitted required Country 1 Complete frame")
            return false
        }

        countryCompleteLabel.text = "Country 1 Complete"
        countryCompleteLabel.position = CGPoint(x: frame.midX, y: frame.midY)
        let fits = fitMilestoneLabel(
            countryCompleteLabel,
            fontName: GameUITheme.Font.bold,
            startingAt: battleChromeLayout?.isCompact ?? (size.height < 780) ? 15 : 18,
            minimum: 15,
            maximumWidth: frame.width
        )
        countryCompleteLabel.isHidden = !fits
        return fits
    }

    @discardableResult
    private func presentPendingConquestReport(
        origin: ConquestReportPresentationOrigin,
        resetsContinueState: Bool
    ) -> Bool {
        guard let result = applyPendingConquestReport(
            resetsContinueState: resetsContinueState
        ) else {
            return false
        }
        #if DEBUG
        lastConquestReportOriginForTestingStorage = origin
        conquestEffectPresentationCountForTestingStorage += origin == .restored ? 0 : 1
        #endif
        presentFreshMilestoneConquestFlourishIfNeeded(result: result, origin: origin)
        if origin != .restored,
           let anchor = conquestReportNode.goldEffectAnchor(in: self) {
            playGoldBurst(at: anchor)
        }
        return true
    }

    private func presentFreshMilestoneConquestFlourishIfNeeded(
        result: BattleResult,
        origin: ConquestReportPresentationOrigin
    ) {
        guard origin != .restored,
              !hasPresentedMilestoneConquestFlourish,
              result.cityKey.countryNumber == 1,
              Country1MilestoneTier.forCity(result.cityKey.cityNumber) != nil else {
            return
        }

        hasPresentedMilestoneConquestFlourish = true
        #if DEBUG
        milestoneConquestFlourishCountForTestingStorage += 1
        lastMilestoneFlourishCityForTestingStorage = result.cityKey.cityNumber
        #endif

        milestoneConquestAccent.removeAllActions()
        milestoneConquestAccent.alpha = 0.45
        milestoneConquestAccent.setScale(UIAccessibility.isReduceMotionEnabled ? 1 : 0.97)
        let fade = SKAction.fadeAlpha(to: 1, duration: 0.24)
        let emphasis = UIAccessibility.isReduceMotionEnabled
            ? fade
            : SKAction.group([fade, SKAction.scale(to: 1, duration: 0.24)])
        milestoneConquestAccent.run(emphasis)
    }

    @discardableResult
    private func applyPendingConquestReport(resetsContinueState: Bool) -> BattleResult? {
        guard let result = pendingResultForPresentation() else { return nil }
        dismissMilestoneArrival(animated: false)
        feedbackSettingsController?.setSettingsAccessibilityActionable(false)
        if resetsContinueState { isConquestContinueEnabled = true }
        let content = conquestReportContent(for: result)
        lastAppliedConquestReportContent = content
        guard let layout = conquestReportLayout(for: content, result: result),
              conquestReportNode.apply(
                  content: content,
                  layout: layout,
                  isContinueEnabled: isConquestContinueEnabled,
                  cityNumber: result.cityKey.cityNumber,
                  cityName: state.displayCityTitle(for: result.cityKey.cityNumber)
              ) == .presented,
              applyMilestoneConquestPresentation(result: result, layout: layout) else {
            isConquestReportVisible = true
            isConquestReportFitFailed = true
            conquestReportNode.isHidden = true
            milestoneConquestAccent.isHidden = true
            countryCompleteLabel.isHidden = true
            refreshBattleHUD()
            // A fresh live/idle conquest that cannot render blocks all scene
            // input, but the fit-failed flag alone never surfaces to the
            // controller unless a layout event happens to refresh the gate.
            // Notify the router immediately so the unsupported-geometry gate
            // appears without waiting for a resize/safe-area change.
            router?.battleScene(self, didRequestLayoutGate: .unsupportedGeometry)
            return nil
        }
        isConquestReportVisible = true
        isConquestReportFitFailed = false
        hasPresentedPendingConquestReport = true
            refreshBattleHUD()
        return result
    }

    private func continueFromConquestReport() {
        guard isConquestReportVisible,
              isConquestContinueEnabled,
              !isConquestReportFitFailed,
              state.pendingBattleResult != nil,
              let router else {
            return
        }
        isConquestContinueEnabled = false
        // Reapply with Continue disabled so the node re-renders dimmed and
        // drops its hit target. If that re-fit fails (e.g. the safe area
        // shrank between presentation and the tap), abort the transaction:
        // keep the pending result, restore Continue, and stay on the battle
        // scene so the player can retry once geometry recovers. Do not
        // acknowledge, save, or route — none of those steps may run.
        guard applyPendingConquestReport(resetsContinueState: false) != nil else {
            isConquestContinueEnabled = true
            return
        }
        state.acknowledgePendingBattleResult()
        store.save(state)
        router.battleSceneDidRequestGameplayTab(self, tab: .map)
    }

    private func playGoldBurst(at anchor: CGPoint) {
        goldBurstRemovalTask?.cancel()
        childNode(withName: EffectName.goldBurst)?.removeFromParent()
        isGoldBurstRemovalScheduled = false
        #if DEBUG
        lastGoldBurstAnchorForTestingStorage = anchor
        #endif

        let burst = SKNode()
        burst.name = EffectName.goldBurst
        burst.position = anchor
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
}

#if DEBUG
extension BattleScene {
    var milestoneTierForTesting: Int? {
        currentMilestoneTier?.rawValue
    }

    var isMilestoneArrivalVisibleForTesting: Bool {
        isMilestoneArrivalVisible
    }

    var milestoneArrivalPresentationCountForTesting: Int {
        milestoneArrivalPresentationCountForTestingStorage
    }

    var milestoneArrivalTitleForTesting: String? {
        milestoneArrivalTitleLabel.text
    }

    var milestoneArrivalSubtitleForTesting: String? {
        milestoneArrivalSubtitleLabel.text
    }

    var milestoneArrivalTitleFontSizeForTesting: CGFloat {
        milestoneArrivalTitleLabel.fontSize
    }

    var milestoneArrivalSubtitleFontSizeForTesting: CGFloat {
        milestoneArrivalSubtitleLabel.fontSize
    }

    var milestoneArrivalFrameForTesting: CGRect? {
        milestoneArrivalPanel.isHidden ? nil : sceneFrame(for: milestoneArrivalPanel)
    }

    var milestoneArrivalTitleFrameForTesting: CGRect? {
        milestoneArrivalPanel.isHidden ? nil : sceneFrame(for: milestoneArrivalTitleLabel)
    }

    var milestoneArrivalSubtitleFrameForTesting: CGRect? {
        milestoneArrivalPanel.isHidden ? nil : sceneFrame(for: milestoneArrivalSubtitleLabel)
    }

    var milestoneCityAccentFrameForTesting: CGRect? {
        milestoneCityAccent.isHidden ? nil : sceneFrame(for: milestoneCityAccent)
    }

    var milestoneConquestFlourishCountForTesting: Int {
        milestoneConquestFlourishCountForTestingStorage
    }

    var lastMilestoneFlourishCityForTesting: Int? {
        lastMilestoneFlourishCityForTestingStorage
    }

    var milestoneConquestAccentFrameForTesting: CGRect? {
        milestoneConquestAccent.isHidden ? nil : sceneFrame(for: milestoneConquestAccent)
    }

    var countryCompleteTextForTesting: String? {
        countryCompleteLabel.isHidden ? nil : countryCompleteLabel.text
    }

    var countryCompleteFrameForTesting: CGRect? {
        countryCompleteLabel.isHidden ? nil : sceneFrame(for: countryCompleteLabel)
    }

    func dismissMilestoneArrivalForTesting() {
        dismissMilestoneArrival(animated: false)
    }

    var lastUpdateTimeForTesting: TimeInterval? {
        lastUpdateTime
    }

    var isFeedbackSettingsVisibleForTesting: Bool {
        isFeedbackSettingsVisible
    }

    var feedbackSettingsGearFrameForTesting: CGRect? {
        feedbackSettingsController?.gear.hitFrameForTesting
    }

    func activateFeedbackSettingsForTesting(_ action: FeedbackSettingsAction) {
        activateFeedbackSettings(action)
    }

    var feedbackSettingsModalZPositionForTesting: CGFloat? {
        feedbackSettingsController?.modal.zPosition
    }

    var feedbackSettingsGearZPositionForTesting: CGFloat? {
        feedbackSettingsController?.gear.zPosition
    }

    var isBattleChromeFitFailedForTesting: Bool {
        isBattleChromeFitFailed
    }

    func setBattleChromeFitFailedForTesting(_ value: Bool) {
        setBattleChromeFitFailed(value)
    }

    var battleChromeLayoutForTesting: BattleChromeLayout? {
        battleChromeLayout
    }

    var battleHUDForTesting: BattleHUDNode {
        battleHUD
    }

    var battlefieldActionLayerPositionForTesting: CGPoint {
        battlefieldActionLayer.position
    }

    var isBattlefieldActionLayerPausedForTesting: Bool {
        battlefieldActionLayer.isPaused
    }

    var isBattlefieldLayerPausedForTesting: Bool {
        battlefieldLayer.isPaused
    }

    var lastAdvanceCombatDeltaForTesting: TimeInterval? {
        lastAdvanceCombatDeltaForTestingStorage
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
        "Trait: \(state.currentCityDefenseTrait.displayName)"
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

    /// Returns the remaining hit-reaction countdown for the first live soldier,
    /// or `nil` if no hit timer is armed. Used by regression tests that verify
    /// a tower-generated hit arms the timer at the full authored duration
    /// (0.9s) rather than `0.9s - deltaTime` (the bug fixed by reordering
    /// `decrementSoldierHitAnimationRemaining` before `combat.tick`).
    var firstLiveSoldierHitAnimationRemainingForTesting: TimeInterval? {
        guard let soldierID = firstLiveSoldierIDForTesting else {
            return nil
        }
        return soldierHitAnimationRemaining[soldierID]
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

    var soldierAttackAnimationTriggerCountForTesting: Int {
        soldierAttackAnimationTriggerCount
    }

    var soldierHitAnimationTriggerCountForTesting: Int {
        soldierHitAnimationTriggerCount
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

    var conquestReportNodeZPositionForTesting: CGFloat {
        conquestReportNode.zPosition
    }

    var conquestReportTitleForTesting: String {
        lastAppliedConquestReportContent?.title ?? ""
    }

    var conquestReportTilesForTesting: [ConquestReportContent.StatTile] {
        lastAppliedConquestReportContent?.tiles ?? []
    }

    var conquestReportRewardTextForTesting: String {
        lastAppliedConquestReportContent?.rewardText ?? ""
    }

    var lastConquestReportOriginForTesting: String? {
        guard let origin = lastConquestReportOriginForTestingStorage else { return nil }
        switch origin {
        case .freshLive: return "freshLive"
        case .freshIdle: return "freshIdle"
        case .restored: return "restored"
        }
    }

    var conquestEffectPresentationCountForTesting: Int {
        conquestEffectPresentationCountForTestingStorage
    }

    var conquestReportGoldAnchorForTesting: CGPoint? {
        conquestReportNode.goldEffectAnchor(in: self)
    }

    var goldBurstAnchorForTesting: CGPoint? {
        lastGoldBurstAnchorForTestingStorage
    }

    var isConquestContinueEnabledForTesting: Bool {
        isConquestContinueEnabled
    }

    var lastConquestReportLayoutInputForTesting: ConquestReportLayout.Input? {
        lastConquestReportLayoutInputForTestingStorage
    }

    func setConquestReportFitFailedForTesting(_ value: Bool) {
        isConquestReportFitFailed = value
    }

    var isConquestReportFitFailedForTesting: Bool {
        isConquestReportFitFailed
    }

    var conquestReportControlCountForTesting: Int {
        conquestReportNode.nodeCountsForTesting
    }

    var conquestReportChipCountForTesting: Int {
        conquestReportNode.renderedChipSymbolsForTesting.count
    }

    func repeatDidMoveForTesting() {
        guard let view else { return }
        didMove(to: view)
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

    var gameStateForTesting: KingdomGameState {
        state
    }

    var cityTitleTextForTesting: String? {
        battleHUD.currentContentForTesting?.cityTitle
    }

    var liveCombatStatusTextForTesting: String? {
        battleHUD.currentContentForTesting.map { "\($0.manualCount)" }
    }

    var isConquestPopupVisibleForTesting: Bool {
        isConquestReportVisible && !isConquestReportFitFailed
    }

    static func isPendingResultPresentableForTesting(
        _ result: BattleResult,
        currentCityKey: CityKey
    ) -> Bool {
        isPendingResultPresentable(result, currentCityKey: currentCityKey)
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

    var cityHPBarFrameForTesting: CGRect? {
        sceneFrame(for: cityHPBarBackground)
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

    /// Forces `isAnimatedCanvas` to be false for `soldierType` on the next
    /// node creation, simulating a partially installed catalog (some actions
    /// complete, at least one frame missing elsewhere) without touching the
    /// texture cache — so `soldierAnimationTextures(for:action:)` still
    /// returns the real textures for whichever actions ARE complete. Mirrors
    /// the release-build failure mode where a static-fallback soldier would
    /// otherwise have transient playback installed on its differently-sized
    /// sprite. Pre-seeds `soldierAnimatedCanvasFrameNameCache` so the probe
    /// short-circuits without re-running 30 `UIImage(named:)` lookups.
    func forceStaticFallbackCanvasForTesting(soldierType: SoldierType) {
        soldierAnimatedCanvasFrameNameCache[soldierType] = .some(nil)
    }

    /// Returns true when the first live soldier's bundle was built on the
    /// animated-canvas path. Exposed so tests can verify the
    /// `forceStaticFallbackCanvasForTesting` hook actually flips the flag on
    /// the spawned node (and, after the fix, that transient playback is
    /// therefore suppressed for that soldier).
    var firstLiveSoldierIsAnimatedCanvasForTesting: Bool? {
        guard let soldierID = firstLiveSoldierIDForTesting,
              let bundle = soldierNodes[soldierID] else {
            return nil
        }
        return bundle.isAnimatedCanvas
    }

    /// IDs of soldiers awaiting animated removal after a tower kill. Exposed so
    /// tests can verify the death-flow scheduler fires for killed soldiers.
    var pendingAnimatedRemovalSoldierIDsForTesting: Set<BattleCombatState.SoldierID> {
        pendingAnimatedRemovalSoldierIDs
    }

    func requestGameplayTabForTesting(_ tab: GameplayTab) {
        requestGameplayTab(tab)
    }

    var battleHUDTabBarForTesting: GameplayTabBarNode {
        battleHUD.tabBarForTesting
    }

    var battleHUDContentForTesting: GameplayTabBarNode.Content {
        battleHUD.currentContentForTesting?.tabContent
            ?? GameplayTabBarNode.Content(selected: .battle, enabledTabs: [], showsCampAttention: false)
    }

    var battleHUDTabBarFrameForTesting: CGRect {
        battleChromeLayout?.tabBarFrame ?? .zero
    }

    func advanceCombatForTesting(deltaTime: TimeInterval) {
        var remaining = max(0, deltaTime)

        while remaining > 0 {
            let step = min(remaining, 0.1)
            advanceCombat(deltaTime: step)
            remaining -= step
        }
    }

    func enterBackgroundForTesting(at date: Date) {
        handleSceneDidEnterBackground(at: date)
    }

    func enterForegroundForTesting(at date: Date) {
        handleSceneWillEnterForeground(at: date)
    }

    /// Drives a single `advanceCombat` call with the raw `deltaTime` (no
    /// chunking), exposing the production frame-stall path where
    /// `deltaTime` can exceed `combat.configuration.maxDeltaTime`. Used to
    /// verify the hit-reaction countdown tracks real frame time (matching
    /// the SKAction clock) rather than the combat tick's clamped delta.
    func advanceCombatSingleStepForTesting(deltaTime: TimeInterval) {
        advanceCombat(deltaTime: deltaTime)
    }

    /// Test-only overlay reset that lifts the conquest report's modal block
    /// without running the production Continue transaction. Use this to leave
    /// the report-gated state in tests that need to confirm behavior re-enables
    /// once the overlay is gone (e.g. info tooltips). It does NOT route, save,
    /// acknowledge, or disable Continue — the real handoff is `handleTouch(at:)`
    /// → `continueFromConquestReport()`.
    func forceDismissConquestOverlayForTesting() {
        isConquestReportVisible = false
        conquestReportNode.isHidden = true
            refreshBattleHUD()
    }

    /// Presents the conquest report flag without requiring a live conquest, so
    /// tests can verify HUD interactions are gated while the report overlays.
    func presentConquestPopupForTesting() {
        isConquestReportVisible = true
        hasPresentedPendingConquestReport = true
        refreshBattleHUD()
    }

    func flushBuildingProgressSaveForTesting() {
        buildingProgressSaveAccumulator = 0
        store.save(state)
    }

    var popupContinueButtonFrameForTesting: CGRect? {
        conquestReportNode.continueHitFrameForTesting
    }

    /// Taps the Continue hit-frame center through the production touch path
    /// (`handleTouch(at:)`), so tests exercise the real Continue transaction
    /// (disable → re-present → acknowledge → save → route) rather than a bypass.
    func tapConquestContinueForTesting() {
        guard let frame = conquestReportNode.continueHitFrameForTesting else {
            return
        }
        let center = CGPoint(x: frame.midX, y: frame.midY)
        handleTouch(at: center)
    }

    /// Drives the production touch dispatcher at an arbitrary scene point.
    func handleTouchForTesting(at point: CGPoint) {
        handleTouch(at: point)
    }

    /// Centers of the spawn/world/build/gold-info/city-info controls, so the
    /// modal-block test can iterate every underlying touch path while the
    /// conquest report overlays the HUD.
    var underlyingControlCentersForTesting: [CGPoint] {
        guard let layout = battleChromeLayout else {
            return []
        }
        return [
            CGPoint(x: layout.deployFrame.midX, y: layout.deployFrame.midY),
            CGPoint(x: layout.tabHitFrames[2].midX, y: layout.tabHitFrames[2].midY),
            CGPoint(x: layout.tabHitFrames[1].midX, y: layout.tabHitFrames[1].midY),
            CGPoint(x: layout.incomeFrame.midX, y: layout.incomeFrame.midY),
            CGPoint(x: layout.cityProgressFrame.midX, y: layout.cityProgressFrame.midY)
        ]
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
