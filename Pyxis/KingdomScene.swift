//
//  KingdomScene.swift
//  Pyxis
//

import SpriteKit
import UIKit

protocol KingdomSceneRouting: AnyObject {
    /// Requests a switch to another gameplay tab; returns false when declined.
    @discardableResult
    func kingdomSceneDidRequestGameplayTab(_ scene: KingdomScene, tab: GameplayTab) -> Bool
    /// Requests the shared layout gate when the Treasury layout cannot fit.
    func kingdomScene(_ scene: KingdomScene, didRequestLayoutGate reason: AppLayoutGateReason)
}

/// HPA-670 Kingdom tab: persisted gold plus exactly three Treasury rows.
/// Every exit routes through the controller's pending-first gate; the
/// scene-local lifecycle sequences mirror Map/Camp (entry/foreground settle,
/// gate pause/resume re-arming) without a shared lifecycle abstraction.
final class KingdomScene: SKScene, LayoutGateLifecycleHandling, SceneLayoutRefreshable {
    private enum NodeName {
        static let header = "kingdomHeader"
        static let rowPrefix = "kingdomTreasuryRow-"
        static let buyPrefix = "kingdomTreasuryBuy-"
        static let iconPrefix = "kingdomTreasuryIcon-"
    }

    private struct RowBundle {
        let panel: PanelNode
        let icon: SKNode
        let nameLabel: SKLabelNode
        let levelLabel: SKLabelNode
        let effectLabel: SKLabelNode
        let priceLabel: SKLabelNode
        let buyPanel: PanelNode
        let buyLabel: SKLabelNode
    }

    private let store: KingdomGameStore
    private weak var router: (any KingdomSceneRouting)?
    private let feedbackPreferences: FeedbackPreferencesManaging
    private let feedbackSettingsAccessibilityAdapter: FeedbackSettingsAccessibilityAdapter?
    private let safeAreaInsetsOverride: BattleChromeLayout.SafeAreaInsets?
    private let imageLoader: (String) -> UIImage?
    private var feedbackSettingsController: FeedbackSettingsController?
    private var state: KingdomGameState
    private var kingdomLayout: KingdomLayout?
    private var rowBundles: [TreasuryUpgrade: RowBundle] = [:]

    private let headerPanel = PanelNode(size: .zero)
    private let titleLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let goldLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    /// The tab bar shares the scene's per-instance image loader (the same
    /// injection style as the row icons) instead of a global lookup hook.
    private lazy var gameplayTabBar = GameplayTabBarNode(
        appearance: .forged,
        iconTextureProvider: { [weak self] name in
            self?.imageLoader(name).map(SKTexture.init(image:)) ?? nil
        }
    )
    private var gameplayTabContent = GameplayTabBarNode.Content(
        selected: .kingdom,
        enabledTabs: [],
        showsCampAttention: false
    )

    private var didBuildInterface = false
    private var isObservingLifecycle = false
    private var isLayoutGatePaused = false
    private var isSystemBackgrounded = false
    private var isRoutingToBattle = false
    /// Header/row/Buy elements the scene vends through the adapter's
    /// supplementary-elements seam — created once the hosting view exists.
    private var sceneAccessibilityElements: SceneAccessibilityElements?
    private weak var activeAccessibilityAdapter: FeedbackSettingsAccessibilityAdapter?

    private struct SceneAccessibilityElements {
        let header: UIAccessibilityElement
        let rows: [TreasuryUpgrade: UIAccessibilityElement]
        let buys: [TreasuryUpgrade: ActionAccessibilityElement]
    }
    /// Entry-settle conquests route on the first update instead of inside
    /// didMove: didMove runs within presentScene, so a synchronous route
    /// would nest a second presentation in the first. Gate-resume and
    /// foreground hooks drive `routePendingConquestIfNeeded` directly.
    private var hasDeferredPendingConquestRoute = false
    private var lastIdleProgressResult = KingdomGameState.IdleProgressResult.none
    /// Non-latching: reset on every layout pass, so a resize that makes the
    /// three rows fit recovers automatically (mirrors the Map scout card).
    private(set) var isTreasuryFitFailed = false

    init(
        size: CGSize,
        store: KingdomGameStore = .shared,
        router: (any KingdomSceneRouting)? = nil,
        safeAreaInsetsOverride: BattleChromeLayout.SafeAreaInsets? = nil,
        imageLoaderOverride: ((String) -> UIImage?)? = nil,
        feedbackPreferences: FeedbackPreferencesManaging = MainActor.assumeIsolated {
            FeedbackPreferencesStore.shared
        },
        feedbackSettingsAccessibilityAdapter: FeedbackSettingsAccessibilityAdapter? = nil
    ) {
        self.store = store
        self.router = router
        self.safeAreaInsetsOverride = safeAreaInsetsOverride
        self.imageLoader = imageLoaderOverride ?? { UIImage(named: $0) }
        self.feedbackPreferences = feedbackPreferences
        self.feedbackSettingsAccessibilityAdapter = feedbackSettingsAccessibilityAdapter
        self.state = store.load()
        super.init(size: size)
    }

    required init?(coder: NSCoder) {
        self.store = .shared
        self.router = nil
        self.safeAreaInsetsOverride = nil
        self.imageLoader = { UIImage(named: $0) }
        self.feedbackPreferences = FeedbackPreferencesStore.shared
        self.feedbackSettingsAccessibilityAdapter = nil
        self.state = KingdomGameStore.shared.load()
        super.init(coder: coder)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.07, green: 0.10, blue: 0.13, alpha: 1.0)
        state = store.load()

        if !didBuildInterface {
            buildInterface()
            didBuildInterface = true
        }

        configureFeedbackSettingsIfNeeded(in: view)
        observeLifecycleNotificationsIfNeeded()
        layoutInterface()
        settleIdleProgressOnEntry()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutInterface()
    }

    override func update(_ currentTime: TimeInterval) {
        guard hasDeferredPendingConquestRoute else { return }
        hasDeferredPendingConquestRoute = false
        routePendingConquestIfNeeded()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        handleTouch(at: touch.location(in: self))
    }

    // MARK: - Interface construction

    private func buildInterface() {
        headerPanel.name = NodeName.header
        headerPanel.zPosition = GameUITheme.Z.hud
        addChild(headerPanel)

        configureLabel(titleLabel, fontSize: 26, color: GameUITheme.Color.textPrimary)
        titleLabel.text = "Kingdom"
        titleLabel.zPosition = GameUITheme.Z.hud + 1
        headerPanel.addChild(titleLabel)

        configureLabel(goldLabel, fontSize: 17, color: GameUITheme.Color.gold)
        goldLabel.horizontalAlignmentMode = .left
        goldLabel.zPosition = GameUITheme.Z.hud + 1
        headerPanel.addChild(goldLabel)

        for upgrade in TreasuryUpgrade.allCases {
            let panel = PanelNode(size: .zero)
            panel.name = "\(NodeName.rowPrefix)\(upgrade.rawValue)"
            panel.zPosition = GameUITheme.Z.hud
            addChild(panel)

            let icon = makeIconNode(for: upgrade)
            icon.zPosition = 1
            panel.addChild(icon)

            let nameLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
            configureLabel(nameLabel, fontSize: 15, color: GameUITheme.Color.textPrimary)
            nameLabel.horizontalAlignmentMode = .left
            nameLabel.zPosition = 1
            panel.addChild(nameLabel)

            let levelLabel = SKLabelNode(fontNamed: GameUITheme.Font.medium)
            configureLabel(levelLabel, fontSize: 11, color: GameUITheme.Color.textSecondary)
            levelLabel.horizontalAlignmentMode = .left
            levelLabel.zPosition = 1
            panel.addChild(levelLabel)

            let effectLabel = SKLabelNode(fontNamed: GameUITheme.Font.medium)
            configureLabel(effectLabel, fontSize: 10, color: GameUITheme.Color.textSecondary)
            effectLabel.horizontalAlignmentMode = .left
            effectLabel.numberOfLines = 0
            effectLabel.zPosition = 1
            panel.addChild(effectLabel)

            let priceLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
            configureLabel(priceLabel, fontSize: 12, color: GameUITheme.Color.gold)
            priceLabel.horizontalAlignmentMode = .left
            priceLabel.zPosition = 1
            panel.addChild(priceLabel)

            let buyPanel = PanelNode(size: .zero)
            buyPanel.name = "\(NodeName.buyPrefix)\(upgrade.rawValue)"
            buyPanel.zPosition = 2
            panel.addChild(buyPanel)

            let buyLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
            configureLabel(buyLabel, fontSize: 13, color: GameUITheme.Color.textPrimary)
            buyLabel.text = "Buy"
            buyLabel.zPosition = 1
            buyPanel.addChild(buyLabel)

            rowBundles[upgrade] = RowBundle(
                panel: panel,
                icon: icon,
                nameLabel: nameLabel,
                levelLabel: levelLabel,
                effectLabel: effectLabel,
                priceLabel: priceLabel,
                buyPanel: buyPanel,
                buyLabel: buyLabel
            )
        }

        gameplayTabBar.zPosition = GameUITheme.Z.hud
        addChild(gameplayTabBar)
    }

    private func configureLabel(_ label: SKLabelNode, fontSize: CGFloat, color: SKColor) {
        label.fontSize = fontSize
        label.fontColor = color
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
    }

    /// Treasury art lookup with one shared vector placeholder design when the
    /// asset is missing (HPA-673 owns final imagery); row text differentiates
    /// the upgrades.
    private func makeIconNode(for upgrade: TreasuryUpgrade) -> SKNode {
        let name = "\(NodeName.iconPrefix)\(upgrade.rawValue)"
        if let image = imageLoader(upgrade.assetName) {
            let sprite = SKSpriteNode(texture: SKTexture(image: image))
            sprite.size = CGSize(
                width: KingdomLayout.rowIconSize,
                height: KingdomLayout.rowIconSize
            )
            sprite.name = name
            return sprite
        }
        let placeholder = Self.makePlaceholderIcon()
        placeholder.name = name
        return placeholder
    }

    private static func makePlaceholderIcon() -> SKShapeNode {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 18))
        path.addLine(to: CGPoint(x: 14, y: 12))
        path.addLine(to: CGPoint(x: 14, y: -4))
        path.addLine(to: CGPoint(x: 0, y: -16))
        path.addLine(to: CGPoint(x: -14, y: -4))
        path.addLine(to: CGPoint(x: -14, y: 12))
        path.closeSubpath()
        let shape = SKShapeNode(path: path)
        shape.strokeColor = GameUITheme.Color.gold
        shape.fillColor = SKColor(red: 1, green: 0.8, blue: 0.22, alpha: 0.12)
        shape.lineWidth = 1.5
        shape.lineCap = .round
        shape.lineJoin = .round
        return shape
    }

    // MARK: - Layout

    private func currentSafeAreaInsets() -> BattleChromeLayout.SafeAreaInsets? {
        if let safeAreaInsetsOverride {
            return safeAreaInsetsOverride
        }
        let insets = view?.safeAreaInsets ?? .zero
        return BattleChromeLayout.SafeAreaInsets(
            top: insets.top,
            left: insets.left,
            bottom: insets.bottom,
            right: insets.right
        )
    }

    private func feedbackSettingsLayoutForCurrentEnvironment() -> FeedbackSettingsLayout? {
        guard let insets = currentSafeAreaInsets() else { return nil }
        return FeedbackSettingsLayout.compute(
            sceneSize: size,
            safeAreaInsets: .init(
                top: insets.top,
                left: insets.left,
                bottom: insets.bottom,
                right: insets.right
            )
        )
    }

    func refreshLayoutForCurrentEnvironment() {
        layoutInterface()
    }

    private func layoutInterface() {
        guard didBuildInterface else { return }
        isTreasuryFitFailed = false

        guard let insets = currentSafeAreaInsets(),
              let layout = KingdomLayout.compute(.init(
                  sceneSize: size,
                  safeAreaInsets: insets
              ))
        else {
            kingdomLayout = nil
            isTreasuryFitFailed = true
            clearLayoutGeometry()
            router?.kingdomScene(self, didRequestLayoutGate: .unsupportedGeometry)
            return
        }

        kingdomLayout = layout
        apply(layout)

        if let feedbackSettingsController {
            feedbackSettingsController.applyGearFrame(layout.settingsFrame, appearance: .forged)
            feedbackSettingsController.reapply(
                layout: feedbackSettingsLayoutForCurrentEnvironment()
            )
        }
        redraw()
    }

    /// Applies precomputed frames to the stable node tree — recomputed on
    /// layout change, never rebuilt, so no duplicate nodes appear.
    private func apply(_ layout: KingdomLayout) {
        // Unhide here so a fail→recover resize cycle restores the header
        // (clearLayoutGeometry hides it; mirrors Map/Camp panel unhide).
        headerPanel.isHidden = false
        headerPanel.apply(
            size: layout.headerFrame.size,
            style: .normal,
            showsRivets: true,
            appearance: .forged
        )
        headerPanel.position = CGPoint(
            x: layout.headerFrame.midX,
            y: layout.headerFrame.midY
        )
        titleLabel.position = CGPoint(
            x: layout.titleFrame.midX - layout.headerFrame.midX,
            y: layout.titleFrame.midY - layout.headerFrame.midY
        )
        goldLabel.position = CGPoint(
            x: layout.goldFrame.minX - layout.headerFrame.midX + 2,
            y: layout.goldFrame.midY - layout.headerFrame.midY
        )

        for (index, upgrade) in TreasuryUpgrade.allCases.enumerated() {
            guard let bundle = rowBundles[upgrade] else { continue }
            let rowFrame = layout.rowFrames[index]
            bundle.panel.isHidden = false
            bundle.panel.apply(
                size: rowFrame.size,
                style: .normal,
                showsRivets: true,
                appearance: .forged
            )
            bundle.panel.position = CGPoint(x: rowFrame.midX, y: rowFrame.midY)

            let iconFrame = layout.iconFrames[index]
            bundle.icon.position = CGPoint(
                x: iconFrame.midX - rowFrame.midX,
                y: iconFrame.midY - rowFrame.midY
            )

            let labelFrames = [
                (layout.nameLabelFrames[index], bundle.nameLabel),
                (layout.levelLabelFrames[index], bundle.levelLabel),
                (layout.effectLabelFrames[index], bundle.effectLabel),
                (layout.priceLabelFrames[index], bundle.priceLabel)
            ]
            for (frame, label) in labelFrames {
                label.position = CGPoint(
                    x: frame.minX - rowFrame.midX,
                    y: frame.midY - rowFrame.midY
                )
            }

            let buyFrame = layout.buyHitFrames[index]
            bundle.buyPanel.isHidden = false
            // Geometry only here — `redraw()` applies the enabled/disabled
            // style once, so each layout pass styles the panel exactly once.
            bundle.buyPanel.position = CGPoint(
                x: buyFrame.midX - rowFrame.midX,
                y: buyFrame.midY - rowFrame.midY
            )
            bundle.buyLabel.position = .zero
        }

        gameplayTabBar.isHidden = false
        gameplayTabBar.apply(
            content: gameplayTabContent,
            frame: layout.tabBarFrame,
            hitFrames: layout.tabHitFrames
        )
    }

    private func clearLayoutGeometry() {
        headerPanel.isHidden = true
        for bundle in rowBundles.values {
            bundle.panel.isHidden = true
            bundle.buyPanel.isHidden = true
        }
        gameplayTabBar.apply(content: gameplayTabContent, frame: .zero)
        feedbackSettingsController?.applyGearFrame(.zero)
    }

    // MARK: - Redraw

    private func redraw() {
        goldLabel.text = "Gold " + CompactNumberFormatter.string(from: state.gold)

        for upgrade in TreasuryUpgrade.allCases {
            guard let bundle = rowBundles[upgrade] else { continue }
            let level = state.treasury.level(for: upgrade)
            let isMaxLevel = level >= upgrade.maxLevel
            let price = upgrade.price(forCurrentLevel: level)
            let isAffordable = state.gold >= price

            bundle.nameLabel.text = upgrade.displayName
            bundle.nameLabel.fontSize = 15
            bundle.levelLabel.text = "Lv \(level)/\(upgrade.maxLevel)"
            bundle.effectLabel.text = Self.effectText(for: upgrade, state: state)
            bundle.effectLabel.fontSize = 10
            if let layout = kingdomLayout,
               let index = TreasuryUpgrade.allCases.firstIndex(of: upgrade) {
                bundle.nameLabel.shrinkFontSize(
                    toFitWidth: layout.nameLabelFrames[index].width,
                    floor: 10
                )
                bundle.effectLabel.shrinkFontSize(
                    toFitWidth: layout.effectLabelFrames[index].width,
                    floor: 8
                )
            }
            bundle.priceLabel.text = isMaxLevel
                ? "MAX"
                : "Cost \(CompactNumberFormatter.string(from: price)) gold"
            let buyEnabled = isBuyEnabled(upgrade)
            if let layout = kingdomLayout,
               let index = TreasuryUpgrade.allCases.firstIndex(of: upgrade) {
                bundle.buyPanel.apply(
                    size: layout.buyHitFrames[index].size,
                    style: buyEnabled ? .normal : .disabled,
                    showsRivets: false,
                    appearance: .forged
                )
            }
            bundle.buyLabel.alpha = buyEnabled ? 1 : 0.5
            bundle.priceLabel.alpha = isMaxLevel || isAffordable ? 1 : GameUITheme.Alpha.unaffordableIcon
        }

        applyGameplayTabBar()
        // Keep the exposed elements' labels/values/traits current even when
        // no re-expose happens between a purchase and the next VoiceOver read.
        refreshSceneAccessibilityElements()
    }

    private func applyGameplayTabBar() {
        gameplayTabContent = .makeForNonBattleScene(selected: .kingdom, state: state)
        if let layout = kingdomLayout {
            gameplayTabBar.apply(
                content: gameplayTabContent,
                frame: layout.tabBarFrame,
                hitFrames: layout.tabHitFrames
            )
        } else {
            gameplayTabBar.apply(content: gameplayTabContent, frame: .zero)
        }
    }

    // MARK: - Row content projections

    /// Current → next effect line, driven by the authoritative seams
    /// (`goldReward(forCity:)`, `buildingBuildCost(for:)` and the single-round
    /// attack helper) — no duplicated economy math in the scene.
    static func effectText(for upgrade: TreasuryUpgrade, state: KingdomGameState) -> String {
        switch upgrade {
        case .drillYard:
            return drillYardExampleText(for: state)
        case .warChest:
            guard state.treasury.warChest < upgrade.maxLevel else {
                return upgrade.effectName
            }
            // Quote the city the player will conquer next, not `cityLevel`:
            // after a conquest `cityLevel` still points at the already-paid
            // city, and a finished country has no reward left to quote.
            guard let nextCity = state.unlockedMapCityNumber else {
                return upgrade.effectName
            }
            let current = state.goldReward(forCity: nextCity)
            var projected = state
            projected.treasury.setLevel(state.treasury.warChest + 1, for: .warChest)
            let next = projected.goldReward(forCity: nextCity)
            return "City reward \(CompactNumberFormatter.string(from: current))"
                + " → \(CompactNumberFormatter.string(from: next)) gold"
        case .quartermaster:
            guard state.treasury.quartermaster < upgrade.maxLevel else {
                return upgrade.effectName
            }
            let current = state.buildingBuildCost(for: .barracks)
            var projected = state
            projected.treasury.setLevel(state.treasury.quartermaster + 1, for: .quartermaster)
            let next = projected.buildingBuildCost(for: .barracks)
            return "Barracks \(CompactNumberFormatter.string(from: current))"
                + " → \(CompactNumberFormatter.string(from: next)) gold"
        }
    }

    /// The Drill Yard row's labeled rounded example: the current state's
    /// Infantry level against the current city's defense trait, at the
    /// current and next Drill Yard level, through the same
    /// `traitAdjustedSoldierAttackPower(for:level:)` seam the live/abstract
    /// damage paths use. When the rounded attack is unchanged the row says
    /// so instead of implying a guaranteed gain.
    static func drillYardExampleText(for state: KingdomGameState) -> String {
        let infantryLevel = state.manualSoldierLevel(for: .infantry) ?? 1
        let drillYardLevel = state.treasury.drillYard

        // Read the attack through the same instance seam live/abstract
        // damage uses, on a copy whose Drill Yard level is moved — the
        // multiplier formula stays owned by KingdomGameState.
        func attack(atUpgradeLevel level: Int) -> Int {
            var projected = state
            projected.treasury.setLevel(level, for: .drillYard)
            return projected.traitAdjustedSoldierAttackPower(
                for: .infantry,
                level: infantryLevel
            )
        }

        let current = attack(atUpgradeLevel: drillYardLevel)
        guard drillYardLevel < TreasuryUpgrade.drillYard.maxLevel else {
            return "Infantry Lv \(infantryLevel) vs this city's trait: \(current) attack"
        }
        let next = attack(atUpgradeLevel: drillYardLevel + 1)
        let changeNote = current == next ? " (no damage change yet)" : ""
        // Two lines: the wrapped pair fits every accepted layout's text frame
        // (including 320pt phones) without dropping the no-change note.
        return "Infantry Lv \(infantryLevel) vs this city's trait:\n"
            + "\(current) → \(next) attack\(changeNote)"
    }

    // MARK: - Touch handling

    private func handleTouch(at point: CGPoint) {
        if isRoutingToBattle || kingdomLayout == nil {
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
        if let tab = gameplayTabBar.tab(at: point) {
            requestGameplayTab(tab)
            return
        }
        if let upgrade = buyUpgrade(at: point) {
            handleBuyTouch(upgrade)
        }
    }

    private func buyUpgrade(at point: CGPoint) -> TreasuryUpgrade? {
        guard let layout = kingdomLayout else { return nil }
        for (index, upgrade) in TreasuryUpgrade.allCases.enumerated()
        where layout.buyHitFrames[index].contains(point) {
            return upgrade
        }
        return nil
    }

    // MARK: - Purchase

    private func handleBuyTouch(_ upgrade: TreasuryUpgrade) {
        var latest = store.load()
        // Only a purchasable tap settles: like build/upgrade, a rejected
        // tap never settles or saves. Same eligibility the row exposes —
        // a disabled (unaffordable or maxed) Buy does nothing when tapped
        // or VoiceOver-activated. Treasury has no stage gate: purchases
        // stay valid after the final city.
        guard latest.canPurchaseTreasuryUpgrade(upgrade) else {
            redraw()
            return
        }

        // Camp's build/upgrade settle parity: the armed interval is
        // credited at the levels in effect during it BEFORE the purchase
        // changes them, then re-armed so time on Kingdom keeps accruing.
        let settleDate = Date()
        settleIdleProgress(in: &latest, at: settleDate) {
            $0.conqueredCities == 0
        }

        // Treasury has no stage gate — a completed or pending city does not
        // block a valid purchase (spec), so a settle that conquered does NOT
        // abandon the buy, unlike Camp's stage-gated build/upgrade. The
        // pending result still routes pending-first below.
        _ = latest.purchaseTreasuryUpgrade(upgrade)
        state = latest
        store.save(state)
        redraw()
        routePendingConquestIfNeeded()
    }

    // MARK: - Tab routing

    private func requestGameplayTab(_ tab: GameplayTab) {
        guard tab != .kingdom,
              !isRoutingToBattle,
              // Map stays reachable in every stage; Battle/Camp exits stay
              // gated to an active battle.
              tab == .map || state.stageStatus == .battleActive,
              kingdomLayout != nil else {
            return
        }

        // Settle and save before handing off (Camp's exit behavior): an exit
        // settle that conquers leaves the pending result for the
        // controller's pending-first gate to surface.
        let exitDate = Date()
        // The settle cleared the idle anchor; re-arm it for an inactive
        // destination (Map/Camp) BEFORE routing — the router synchronously
        // constructs the destination scene, which loads its own state copy
        // during that call, so the armed anchor must already be saved for a
        // backgrounding from there to credit idle production. The declined
        // branch below re-arms for the same reason. Battle drives buildings
        // per-frame, so it must never inherit a stale anchor.
        _ = settleIdleProgress(in: &state, at: exitDate) { result in
            tab != .battle && result.conqueredCities == 0
        }
        store.save(state)
        redraw()

        isRoutingToBattle = true
        guard router?.kingdomSceneDidRequestGameplayTab(self, tab: tab) == true else {
            isRoutingToBattle = false
            if rearmIdleProgressAnchor(in: &state, at: exitDate) {
                store.save(state)
            }
            redraw()
            return
        }
    }

    /// Idle conquest that settled while the player was not looking (entry or
    /// foreground settlement, gate-resume settlement) routes to Battle so the
    /// pending report is shown — never silently acknowledged. Routing
    /// requires a live scene: a gate-paused or system-backgrounded scene
    /// defers to its resume/foreground hook.
    @discardableResult
    private func routePendingConquestIfNeeded() -> Bool {
        guard state.pendingBattleResult != nil,
              !isRoutingToBattle,
              !isLayoutGatePaused,
              !isSystemBackgrounded,
              let router else { return false }
        isRoutingToBattle = true
        guard router.kingdomSceneDidRequestGameplayTab(self, tab: .battle) else {
            isRoutingToBattle = false
            return false
        }
        return true
    }

    // MARK: - Lifecycle

    /// Settles the armed idle interval on `state` at `date`, then re-arms
    /// the building-progress anchor when the stage is still an active
    /// battle and `shouldRearm` allows it — the single place Kingdom
    /// decides whether accrual continues after a settle (entry and
    /// foreground: only while not gate-paused; buy and tab exits: only
    /// when nothing conquered and the destination keeps accrual).
    @discardableResult
    private func settleIdleProgress(
        in state: inout KingdomGameState,
        at date: Date,
        shouldRearm: (KingdomGameState.IdleProgressResult) -> Bool
    ) -> KingdomGameState.IdleProgressResult {
        let result = state.returnFromBackground(at: date)
        lastIdleProgressResult = result
        if state.stageStatus == .battleActive, shouldRearm(result) {
            state.markCurrentCityBuildingProgressInactive(at: date)
        }
        return result
    }

    /// Re-arms the building-progress anchor without settling again — used
    /// when an already-settled hand-off is declined, so a backgrounding
    /// from this scene still credits production.
    @discardableResult
    private func rearmIdleProgressAnchor(
        in state: inout KingdomGameState,
        at date: Date
    ) -> Bool {
        guard state.stageStatus == .battleActive else { return false }
        state.markCurrentCityBuildingProgressInactive(at: date)
        return true
    }

    private func settleIdleProgressOnEntry() {
        // Same lifecycle rule as the foreground hook: a gate-paused scene
        // never re-arms (its resume hook owns that), otherwise time stuck
        // on the "can't fit" gate would later be credited as production.
        settleIdleProgress(in: &state, at: Date()) { _ in !isLayoutGatePaused }
        store.save(state)
        redraw()
        // didMove is still inside presentScene, so routing here would nest
        // a second presentation in the first — the first update drives it.
        hasDeferredPendingConquestRoute = state.pendingBattleResult != nil
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
        settleIdleProgress(in: &state, at: date) { _ in !isLayoutGatePaused }
        store.save(state)
        redraw()
        routePendingConquestIfNeeded()
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
        redraw()
    }

    func layoutGateWillResume(at date: Date) {
        guard isLayoutGatePaused else { return }
        isLayoutGatePaused = false

        if !isSystemBackgrounded {
            rearmIdleProgressAnchor(in: &state, at: date)
        }
        store.save(state)
        redraw()
        routePendingConquestIfNeeded()
    }

    // MARK: - Settings plumbing

    private var isFeedbackSettingsVisible: Bool {
        feedbackSettingsController?.isVisible == true
    }

    private func configureFeedbackSettingsIfNeeded(in view: SKView) {
        if sceneAccessibilityElements == nil {
            sceneAccessibilityElements = makeSceneAccessibilityElements(container: view)
        }

        if feedbackSettingsController == nil {
            let accessibilityAdapter = feedbackSettingsAccessibilityAdapter
                ?? FeedbackSettingsAccessibilityAdapter.sceneAdapter(
                    containerView: view,
                    sceneHeight: { [weak self] in self?.size.height ?? 0 }
                )
            activeAccessibilityAdapter = accessibilityAdapter
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

        // After ANY rebind (rebind clears the provider): this scene owns
        // the supplementary exposure while mounted — reinstall on every
        // mount, not just the one that created the controller.
        activeAccessibilityAdapter?.sceneElementsProvider = { [weak self] in
            self?.orderedSceneAccessibilityElements() ?? []
        }

        guard let feedbackSettingsController else { return }
        if feedbackSettingsController.gear.parent !== self {
            addChild(feedbackSettingsController.gear)
        }
        if feedbackSettingsController.modal.parent !== self {
            addChild(feedbackSettingsController.modal)
        }
    }

    private func makeSceneAccessibilityElements(
        container: UIView
    ) -> SceneAccessibilityElements {
        let header = UIAccessibilityElement(accessibilityContainer: container)
        header.accessibilityIdentifier = "kingdom-header"
        header.accessibilityTraits = .header

        var rows: [TreasuryUpgrade: UIAccessibilityElement] = [:]
        var buys: [TreasuryUpgrade: ActionAccessibilityElement] = [:]
        for upgrade in TreasuryUpgrade.allCases {
            let row = UIAccessibilityElement(accessibilityContainer: container)
            row.accessibilityIdentifier = "kingdom-row-\(upgrade.rawValue)"
            row.accessibilityTraits = .staticText
            rows[upgrade] = row

            let buy = ActionAccessibilityElement(accessibilityContainer: container) { [weak self] in
                self?.handleBuyTouch(upgrade)
            }
            buy.accessibilityIdentifier = "kingdom-buy-\(upgrade.rawValue)"
            buy.accessibilityTraits = .button
            buys[upgrade] = buy
        }
        return SceneAccessibilityElements(header: header, rows: rows, buys: buys)
    }

    /// The supplementary elements the adapter exposes alongside the gear:
    /// header, then each row's info element followed by its Buy action.
    /// Frames and values are refreshed on every query so an expose after a
    /// relayout or purchase always reads current geometry and prices.
    private func orderedSceneAccessibilityElements() -> [UIAccessibilityElement] {
        refreshSceneAccessibilityElements()
        // A failed layout hid every control — expose nothing rather than
        // seven elements parked at .zero.
        guard let elements = sceneAccessibilityElements,
              kingdomLayout != nil else { return [] }
        var ordered: [UIAccessibilityElement] = [elements.header]
        for upgrade in TreasuryUpgrade.allCases {
            if let row = elements.rows[upgrade] { ordered.append(row) }
            if let buy = elements.buys[upgrade] { ordered.append(buy) }
        }
        return ordered
    }

    private func refreshSceneAccessibilityElements() {
        guard let elements = sceneAccessibilityElements,
              let layout = kingdomLayout,
              let adapter = activeAccessibilityAdapter else {
            return
        }

        elements.header.accessibilityLabel = titleLabel.text
        elements.header.accessibilityValue = goldLabel.text
        elements.header.accessibilityFrame = adapter.screenAccessibilityFrame(
            for: layout.headerFrame
        ) ?? .zero

        for (index, upgrade) in TreasuryUpgrade.allCases.enumerated() {
            let level = state.treasury.level(for: upgrade)
            let row = elements.rows[upgrade]
            row?.accessibilityLabel = "\(upgrade.displayName), level \(level) of \(upgrade.maxLevel)"
            row?.accessibilityValue = rowBundles[upgrade]?.effectLabel.text
            row?.accessibilityFrame = adapter.screenAccessibilityFrame(
                for: layout.rowFrames[index]
            ) ?? .zero

            let buy = elements.buys[upgrade]
            buy?.accessibilityLabel = "Buy \(upgrade.displayName)"
            buy?.accessibilityValue = rowBundles[upgrade]?.priceLabel.text
            buy?.accessibilityTraits = isBuyEnabled(upgrade)
                ? .button
                : [.button, .notEnabled]
            buy?.accessibilityFrame = adapter.screenAccessibilityFrame(
                for: layout.buyHitFrames[index]
            ) ?? .zero
        }
    }

    /// One definition of the Buy affordance shared by the row redraw and
    /// the accessibility traits: a purchase the state accepts. Treasury has
    /// no stage gate, so a finished country keeps offering valid buys.
    private func isBuyEnabled(_ upgrade: TreasuryUpgrade) -> Bool {
        state.canPurchaseTreasuryUpgrade(upgrade)
    }

    private func openFeedbackSettings() {
        guard !isLayoutGatePaused,
              !isRoutingToBattle,
              kingdomLayout != nil,
              let feedbackSettingsController,
              !feedbackSettingsController.isVisible else {
            return
        }
        _ = feedbackSettingsController.open()
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
}

#if DEBUG
extension KingdomScene {
    struct TreasuryRowTextForTesting {
        let name: String
        let level: String
        let effect: String
        let price: String
    }

    var titleTextForTesting: String? { titleLabel.text }

    var goldTextForTesting: String? { goldLabel.text }

    var kingdomLayoutForTesting: KingdomLayout? { kingdomLayout }

    var gameplayTabContentForTesting: GameplayTabBarNode.Content {
        gameplayTabContent
    }

    var isTreasuryFitFailedForTesting: Bool { isTreasuryFitFailed }

    var isRoutingToBattleForTesting: Bool { isRoutingToBattle }

    var lastIdleProgressResultForTesting: KingdomGameState.IdleProgressResult {
        lastIdleProgressResult
    }

    var headerNodeForTesting: SKNode? { headerPanel }

    var goldLabelNodeForTesting: SKLabelNode { goldLabel }

    var titleLabelNodeForTesting: SKLabelNode { titleLabel }

    func treasuryRowLabelNodesForTesting(
        _ upgrade: TreasuryUpgrade
    ) -> [SKLabelNode]? {
        guard let bundle = rowBundles[upgrade] else { return nil }
        return [bundle.nameLabel, bundle.levelLabel, bundle.effectLabel, bundle.priceLabel]
    }

    func treasuryRowNodeForTesting(_ upgrade: TreasuryUpgrade) -> SKNode? {
        rowBundles[upgrade]?.panel
    }

    func treasuryRowTextForTesting(
        _ upgrade: TreasuryUpgrade
    ) -> TreasuryRowTextForTesting? {
        guard let bundle = rowBundles[upgrade] else { return nil }
        return TreasuryRowTextForTesting(
            name: bundle.nameLabel.text ?? "",
            level: bundle.levelLabel.text ?? "",
            effect: bundle.effectLabel.text ?? "",
            price: bundle.priceLabel.text ?? ""
        )
    }

    func buyHitFrameForTesting(_ upgrade: TreasuryUpgrade) -> CGRect? {
        guard let layout = kingdomLayout,
              let index = TreasuryUpgrade.allCases.firstIndex(of: upgrade) else {
            return nil
        }
        return layout.buyHitFrames[index]
    }

    func isBuyEnabledForTesting(_ upgrade: TreasuryUpgrade) -> Bool {
        guard let bundle = rowBundles[upgrade] else { return false }
        return !bundle.buyPanel.isHidden && bundle.buyLabel.alpha > 0.9
    }

    func handleTouchForTesting(at point: CGPoint) {
        handleTouch(at: point)
    }

    func requestGameplayTabForTesting(_ tab: GameplayTab) {
        requestGameplayTab(tab)
    }

    func repeatDidMoveForTesting() {
        guard let view else { return }
        didMove(to: view)
    }

    func sceneDidEnterBackgroundForTesting(at date: Date) {
        handleSceneDidEnterBackground(at: date)
    }

    func sceneWillEnterForegroundForTesting(at date: Date) {
        handleSceneWillEnterForeground(at: date)
    }

    var isFeedbackSettingsVisibleForTesting: Bool { isFeedbackSettingsVisible }

    func activateFeedbackSettingsForTesting(_ action: FeedbackSettingsAction) {
        activateFeedbackSettings(action)
    }

    var feedbackSettingsGearFrameForTesting: CGRect? {
        feedbackSettingsController?.gear.hitFrameForTesting
    }
}
#endif
