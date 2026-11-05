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

/// HPA-670 Kingdom tab: persisted gold plus exactly three Treasury rows,
/// with the HPA-671 Armory section sharing the same content band behind a
/// compact header selector. Every exit routes through the controller's
/// pending-first gate; the scene-local lifecycle sequences mirror Map/Camp
/// (entry/foreground settle, gate pause/resume re-arming) without a shared
/// lifecycle abstraction.
final class KingdomScene: SKScene, LayoutGateLifecycleHandling, SceneLayoutRefreshable {
    private enum NodeName {
        static let header = "kingdomHeader"
        static let rowPrefix = "kingdomTreasuryRow-"
        static let buyPrefix = "kingdomTreasuryBuy-"
        static let iconPrefix = "kingdomTreasuryIcon-"
        static let treasurySelector = "kingdomSectionTreasury"
        static let armorySelector = "kingdomSectionArmory"
        static let ascendSelector = "kingdomSectionAscend"
        static let armoryRowPrefix = "kingdomArmoryRow-"
        static let armoryIconHolderPrefix = "kingdomArmoryIconHolder-"
        static let armoryIconPrefix = "kingdomArmoryIcon-"
        static let ascendPanel = "kingdomAscendPanel"
        static let ascendIconHolder = "kingdomAscendIconHolder"
        static let ascendIcon = "kingdomAscendIcon"
        static let ascendPrimaryAction = "kingdomAscendAction"
        static let ascendCancel = "kingdomAscendCancel"
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

    /// HPA-671 Armory row: stable per-`SoldierType` nodes. The icon holder's
    /// child is swapped on redraw (equipped item art vs per-type glyph).
    private struct ArmoryRowBundle {
        let panel: PanelNode
        let iconHolder: SKNode
        let line1Label: SKLabelNode
        let line2Label: SKLabelNode
    }

    /// HPA-672 Ascend content: one panel sharing the Treasury/Armory band.
    /// The emblem is static (built once); the primary action relabels to
    /// "Confirm Ascension" while the two-tap confirmation is armed.
    private struct AscendContentBundle {
        let panel: PanelNode
        let iconHolder: SKNode
        let bonusLabel: SKLabelNode
        let resetsLabel: SKLabelNode
        let keepsLabel: SKLabelNode
        let requirementLabel: SKLabelNode
        let primaryPanel: PanelNode
        let primaryLabel: SKLabelNode
        let cancelPanel: PanelNode
        let cancelLabel: SKLabelNode
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
    private var armoryRowBundles: [SoldierType: ArmoryRowBundle] = [:]
    /// The equipped item each Armory icon holder last rendered — redraw
    /// skips the texture/glyph rebuild while the loadout is unchanged.
    private var armoryIconEquippedItemIDs: [SoldierType: String] = [:]
    /// Ephemeral section selection (HPA-671): scene UI state only.
    private var selectedSection: KingdomSection = .treasury
    /// HPA-672 two-tap Ascension confirmation: transient UI state only —
    /// never persisted, cleared by Cancel, a section change, commit,
    /// rejection, a layout-gate pause or system backgrounding, and scene
    /// dismissal (`willMove(from:)` is the one dismissal boundary).
    private var isAscendConfirmationArmed = false

    private let headerPanel = PanelNode(size: .zero)
    private let goldLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    /// Right-aligned Renown summary in the header's bottom line, visible
    /// only while `ascensionCount > 0` (HPA-672).
    private let renownLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let treasurySelectorPanel = PanelNode(size: .zero)
    private let treasurySelectorLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let armorySelectorPanel = PanelNode(size: .zero)
    private let armorySelectorLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let ascendSelectorPanel = PanelNode(size: .zero)
    private let ascendSelectorLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private var ascendContent: AscendContentBundle?
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
        let sections: [KingdomSection: ActionAccessibilityElement]
        let rows: [TreasuryUpgrade: UIAccessibilityElement]
        let buys: [TreasuryUpgrade: ActionAccessibilityElement]
        let armoryRows: [SoldierType: ActionAccessibilityElement]
        let ascendInfo: UIAccessibilityElement
        let ascendAction: ActionAccessibilityElement
        let ascendCancel: ActionAccessibilityElement
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

    override func willMove(from view: SKView) {
        super.willMove(from: view)
        // Dismissal clears the transient confirmation: a retained instance
        // must not offer Confirm again without a fresh first tap.
        isAscendConfirmationArmed = false
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

        configureLabel(goldLabel, fontSize: 17, color: GameUITheme.Color.gold)
        goldLabel.horizontalAlignmentMode = .left
        goldLabel.zPosition = GameUITheme.Z.hud + 1
        headerPanel.addChild(goldLabel)

        configureLabel(renownLabel, fontSize: 15, color: GameUITheme.Color.gold)
        renownLabel.horizontalAlignmentMode = .right
        renownLabel.zPosition = GameUITheme.Z.hud + 1
        headerPanel.addChild(renownLabel)

        for (panel, label, name, text) in [
            (treasurySelectorPanel, treasurySelectorLabel, NodeName.treasurySelector, "Treasury"),
            (armorySelectorPanel, armorySelectorLabel, NodeName.armorySelector, "Armory"),
            (ascendSelectorPanel, ascendSelectorLabel, NodeName.ascendSelector, "Ascend")
        ] {
            panel.name = name
            panel.zPosition = GameUITheme.Z.hud + 1
            headerPanel.addChild(panel)
            configureLabel(label, fontSize: 13, color: GameUITheme.Color.textPrimary)
            label.text = text
            label.zPosition = 1
            panel.addChild(label)
        }

        for type in SoldierType.allCases {
            let panel = PanelNode(size: .zero)
            panel.name = "\(NodeName.armoryRowPrefix)\(type.rawValue)"
            panel.zPosition = GameUITheme.Z.hud
            addChild(panel)

            let iconHolder = SKNode()
            iconHolder.name = "\(NodeName.armoryIconHolderPrefix)\(type.rawValue)"
            iconHolder.zPosition = 1
            panel.addChild(iconHolder)

            let line1Label = SKLabelNode(fontNamed: GameUITheme.Font.bold)
            configureLabel(line1Label, fontSize: 13, color: GameUITheme.Color.textPrimary)
            line1Label.horizontalAlignmentMode = .left
            line1Label.zPosition = 1
            panel.addChild(line1Label)

            let line2Label = SKLabelNode(fontNamed: GameUITheme.Font.medium)
            configureLabel(line2Label, fontSize: 11, color: GameUITheme.Color.textSecondary)
            line2Label.horizontalAlignmentMode = .left
            line2Label.zPosition = 1
            panel.addChild(line2Label)

            armoryRowBundles[type] = ArmoryRowBundle(
                panel: panel,
                iconHolder: iconHolder,
                line1Label: line1Label,
                line2Label: line2Label
            )
        }

        // HPA-672 Ascend content: one panel in the shared band. The
        // `ascension-renown` emblem is static art-with-vector-fallback
        // (HPA-673 owns the final icon), built once like the row icons.
        do {
            let panel = PanelNode(size: .zero)
            panel.name = NodeName.ascendPanel
            panel.zPosition = GameUITheme.Z.hud
            addChild(panel)

            let iconHolder = SKNode()
            iconHolder.name = NodeName.ascendIconHolder
            iconHolder.zPosition = 1
            let icon = makeAscendIconNode()
            icon.name = NodeName.ascendIcon
            iconHolder.addChild(icon)
            panel.addChild(iconHolder)

            let bonusLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
            configureLabel(bonusLabel, fontSize: 15, color: GameUITheme.Color.textPrimary)
            bonusLabel.zPosition = 1
            panel.addChild(bonusLabel)

            let resetsLabel = SKLabelNode(fontNamed: GameUITheme.Font.medium)
            configureLabel(resetsLabel, fontSize: 13, color: GameUITheme.Color.textSecondary)
            resetsLabel.numberOfLines = 0
            resetsLabel.zPosition = 1
            panel.addChild(resetsLabel)

            let keepsLabel = SKLabelNode(fontNamed: GameUITheme.Font.medium)
            configureLabel(keepsLabel, fontSize: 13, color: GameUITheme.Color.textSecondary)
            keepsLabel.numberOfLines = 0
            keepsLabel.zPosition = 1
            panel.addChild(keepsLabel)

            let requirementLabel = SKLabelNode(fontNamed: GameUITheme.Font.medium)
            configureLabel(requirementLabel, fontSize: 13, color: GameUITheme.Color.textSecondary)
            requirementLabel.zPosition = 1
            panel.addChild(requirementLabel)

            let primaryPanel = PanelNode(size: .zero)
            primaryPanel.name = NodeName.ascendPrimaryAction
            primaryPanel.zPosition = 2
            panel.addChild(primaryPanel)

            let primaryLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
            configureLabel(primaryLabel, fontSize: 15, color: GameUITheme.Color.textPrimary)
            primaryLabel.zPosition = 1
            primaryPanel.addChild(primaryLabel)

            let cancelPanel = PanelNode(size: .zero)
            cancelPanel.name = NodeName.ascendCancel
            cancelPanel.zPosition = 2
            panel.addChild(cancelPanel)

            let cancelLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
            configureLabel(cancelLabel, fontSize: 15, color: GameUITheme.Color.textPrimary)
            cancelLabel.text = "Cancel"
            cancelLabel.zPosition = 1
            cancelPanel.addChild(cancelLabel)

            ascendContent = AscendContentBundle(
                panel: panel,
                iconHolder: iconHolder,
                bonusLabel: bonusLabel,
                resetsLabel: resetsLabel,
                keepsLabel: keepsLabel,
                requirementLabel: requirementLabel,
                primaryPanel: primaryPanel,
                primaryLabel: primaryLabel,
                cancelPanel: cancelPanel,
                cancelLabel: cancelLabel
            )
        }

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

    /// HPA-671 Armory row icon: `equipment-<itemID>` art first (the
    /// HPA-673 art-name contract), one simple per-type vector glyph as the
    /// fallback — also used when nothing is equipped. The art-only PR must
    /// never need Swift integration edits.
    private func makeArmoryIconNode(
        for item: EquipmentItem?,
        soldierType: SoldierType
    ) -> SKNode {
        if let item, let image = imageLoader("equipment-\(item.id)") {
            let sprite = SKSpriteNode(texture: SKTexture(image: image))
            sprite.size = CGSize(
                width: KingdomLayout.armoryIconSize,
                height: KingdomLayout.armoryIconSize
            )
            return sprite
        }
        return Self.makeArmoryFallbackGlyph(for: soldierType)
    }

    /// Five distinct simple silhouettes in the same gold-on-panel language
    /// as the Treasury placeholder: shield, arrow, chevrons, gem, ram head.
    private static func makeArmoryFallbackGlyph(for type: SoldierType) -> SKShapeNode {
        let path = CGMutablePath()
        switch type {
        case .infantry:
            path.move(to: CGPoint(x: 0, y: 15))
            path.addLine(to: CGPoint(x: 12, y: 10))
            path.addLine(to: CGPoint(x: 12, y: -2))
            path.addLine(to: CGPoint(x: 0, y: -14))
            path.addLine(to: CGPoint(x: -12, y: -2))
            path.addLine(to: CGPoint(x: -12, y: 10))
        case .archer:
            path.move(to: CGPoint(x: 0, y: 15))
            path.addLine(to: CGPoint(x: 11, y: 3))
            path.addLine(to: CGPoint(x: 4, y: 3))
            path.addLine(to: CGPoint(x: 4, y: -14))
            path.addLine(to: CGPoint(x: -4, y: -14))
            path.addLine(to: CGPoint(x: -4, y: 3))
            path.addLine(to: CGPoint(x: -11, y: 3))
        case .cavalry:
            path.move(to: CGPoint(x: -12, y: 9))
            path.addLine(to: CGPoint(x: -1, y: 0))
            path.addLine(to: CGPoint(x: -12, y: -9))
            path.addLine(to: CGPoint(x: -8, y: 0))
            path.closeSubpath()
            path.move(to: CGPoint(x: 1, y: 9))
            path.addLine(to: CGPoint(x: 12, y: 0))
            path.addLine(to: CGPoint(x: 1, y: -9))
            path.addLine(to: CGPoint(x: 5, y: 0))
        case .mage:
            path.move(to: CGPoint(x: 0, y: 15))
            path.addLine(to: CGPoint(x: 11, y: 0))
            path.addLine(to: CGPoint(x: 0, y: -15))
            path.addLine(to: CGPoint(x: -11, y: 0))
        case .siege:
            path.move(to: CGPoint(x: -10, y: 10))
            path.addLine(to: CGPoint(x: 6, y: 10))
            path.addLine(to: CGPoint(x: 15, y: 0))
            path.addLine(to: CGPoint(x: 6, y: -10))
            path.addLine(to: CGPoint(x: -10, y: -10))
        }
        path.closeSubpath()
        let shape = SKShapeNode(path: path)
        shape.strokeColor = GameUITheme.Color.gold
        shape.fillColor = SKColor(red: 1, green: 0.8, blue: 0.22, alpha: 0.12)
        shape.lineWidth = 1.5
        shape.lineCap = .round
        shape.lineJoin = .round
        return shape
    }

    /// HPA-672 Ascend emblem: `ascension-renown` art first (the HPA-673
    /// art-name contract), one code-owned vector fallback — the same
    /// probe-and-fallback pattern as the Treasury/Armory icons.
    private func makeAscendIconNode() -> SKNode {
        if let image = imageLoader("ascension-renown") {
            let sprite = SKSpriteNode(texture: SKTexture(image: image))
            sprite.size = CGSize(
                width: KingdomLayout.ascendIconSize,
                height: KingdomLayout.ascendIconSize
            )
            return sprite
        }
        // A rising star over a chevron base: simple, gold-on-panel, and
        // distinct from every Treasury placeholder and Armory glyph.
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 8))
        path.addLine(to: CGPoint(x: 4, y: 0))
        path.addLine(to: CGPoint(x: 0, y: -8))
        path.addLine(to: CGPoint(x: -4, y: 0))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0, y: -10))
        path.addLine(to: CGPoint(x: 12, y: -14))
        path.addLine(to: CGPoint(x: 0, y: -18))
        path.addLine(to: CGPoint(x: -12, y: -14))
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
        goldLabel.position = CGPoint(
            x: layout.goldFrame.minX - layout.headerFrame.midX + 2,
            y: layout.goldFrame.midY - layout.headerFrame.midY
        )
        renownLabel.position = CGPoint(
            x: layout.renownFrame.maxX - layout.headerFrame.midX,
            y: layout.renownFrame.midY - layout.headerFrame.midY
        )

        for (frame, panel, label) in [
            (layout.treasurySelectorFrame, treasurySelectorPanel, treasurySelectorLabel),
            (layout.armorySelectorFrame, armorySelectorPanel, armorySelectorLabel),
            (layout.ascendSelectorFrame, ascendSelectorPanel, ascendSelectorLabel)
        ] {
            panel.isHidden = false
            panel.position = CGPoint(
                x: frame.midX - layout.headerFrame.midX,
                y: frame.midY - layout.headerFrame.midY
            )
            label.position = .zero
        }

        for (index, type) in SoldierType.allCases.enumerated() {
            guard let bundle = armoryRowBundles[type] else { continue }
            let rowFrame = layout.armoryRowFrames[index]
            bundle.panel.position = CGPoint(x: rowFrame.midX, y: rowFrame.midY)
            let iconFrame = layout.armoryIconFrames[index]
            bundle.iconHolder.position = CGPoint(
                x: iconFrame.midX - rowFrame.midX,
                y: iconFrame.midY - rowFrame.midY
            )
            for (frame, label) in [
                (layout.armoryLine1LabelFrames[index], bundle.line1Label),
                (layout.armoryLine2LabelFrames[index], bundle.line2Label)
            ] {
                label.position = CGPoint(
                    x: frame.minX - rowFrame.midX,
                    y: frame.midY - rowFrame.midY
                )
            }
        }

        // HPA-672 Ascend content in the shared band: geometry only here —
        // `redraw()` applies the enabled/armed styles once per pass.
        if let ascend = ascendContent {
            ascend.panel.isHidden = false
            ascend.panel.apply(
                size: layout.ascendPanelFrame.size,
                style: .normal,
                showsRivets: true,
                appearance: .forged
            )
            ascend.panel.position = CGPoint(
                x: layout.ascendPanelFrame.midX,
                y: layout.ascendPanelFrame.midY
            )
            let panelCenter = ascend.panel.position
            ascend.iconHolder.position = CGPoint(
                x: layout.ascendIconFrame.midX - panelCenter.x,
                y: layout.ascendIconFrame.midY - panelCenter.y
            )
            for (frame, label) in [
                (layout.ascendBonusLabelFrame, ascend.bonusLabel),
                (layout.ascendResetsLabelFrame, ascend.resetsLabel),
                (layout.ascendKeepsLabelFrame, ascend.keepsLabel),
                (layout.ascendRequirementLabelFrame, ascend.requirementLabel)
            ] {
                // .center-aligned text anchored on each box's midline —
                // the reserved frame is where the rendered text must sit.
                label.position = CGPoint(
                    x: frame.midX - panelCenter.x,
                    y: frame.midY - panelCenter.y
                )
            }
            ascend.primaryPanel.position = CGPoint(
                x: layout.ascendPrimaryActionFrame.midX - panelCenter.x,
                y: layout.ascendPrimaryActionFrame.midY - panelCenter.y
            )
            ascend.primaryLabel.position = .zero
            ascend.cancelPanel.position = CGPoint(
                x: layout.ascendCancelFrame.midX - panelCenter.x,
                y: layout.ascendCancelFrame.midY - panelCenter.y
            )
            ascend.cancelLabel.position = .zero
        }

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

        // A fail→recover resize cycle must restore the active section's
        // rows (clearLayoutGeometry hid everything).
        applySectionVisibility()
    }

    /// One source for which section's rows are visible — called from both
    /// layout application and redraw, because a section switch redraws
    /// without a relayout. An unsupported layout keeps every row hidden:
    /// gate-pause/foreground redraws run with `kingdomLayout` nil and must
    /// not reveal the selected section's stale rows behind the gate.
    private func applySectionVisibility() {
        let treasuryVisible = kingdomLayout != nil && selectedSection == .treasury
        let armoryVisible = kingdomLayout != nil && selectedSection == .armory
        let ascendVisible = kingdomLayout != nil && selectedSection == .ascend
        for bundle in rowBundles.values {
            bundle.panel.isHidden = !treasuryVisible
        }
        for bundle in armoryRowBundles.values {
            bundle.panel.isHidden = !armoryVisible
        }
        ascendContent?.panel.isHidden = !ascendVisible
    }

    private func clearLayoutGeometry() {
        headerPanel.isHidden = true
        for bundle in rowBundles.values {
            bundle.panel.isHidden = true
            bundle.buyPanel.isHidden = true
        }
        for bundle in armoryRowBundles.values {
            bundle.panel.isHidden = true
        }
        ascendContent?.panel.isHidden = true
        gameplayTabBar.apply(content: gameplayTabContent, frame: .zero)
        feedbackSettingsController?.applyGearFrame(.zero)
    }

    // MARK: - Redraw

    private func redraw() {
        // HPA-672 bottom header: gold (always) and the Renown summary
        // (positive counts only) share the line — reset then shrink so a
        // wider resize can re-grow the fonts, and never let the two
        // fitted labels collide.
        let renownText = Self.headerRenownText(for: state)
        goldLabel.text = "Gold " + CompactNumberFormatter.string(from: state.gold)
        renownLabel.text = renownText
        renownLabel.isHidden = renownText == nil
        goldLabel.fontSize = 17
        renownLabel.fontSize = 15
        if let layout = kingdomLayout {
            goldLabel.shrinkFontSize(
                toFitWidth: layout.goldTextMaxWidth(showingRenown: renownText != nil),
                floor: 10
            )
            renownLabel.shrinkFontSize(
                toFitWidth: layout.renownFrame.width,
                floor: 10
            )
        }

        applySectionSelector(
            treasurySelectorPanel,
            label: treasurySelectorLabel,
            frame: kingdomLayout?.treasurySelectorFrame,
            section: .treasury
        )
        applySectionSelector(
            armorySelectorPanel,
            label: armorySelectorLabel,
            frame: kingdomLayout?.armorySelectorFrame,
            section: .armory
        )
        applySectionSelector(
            ascendSelectorPanel,
            label: ascendSelectorLabel,
            frame: kingdomLayout?.ascendSelectorFrame,
            section: .ascend
        )

        redrawAscendContent()

        for type in SoldierType.allCases {
            guard let bundle = armoryRowBundles[type] else { continue }
            let text = Self.armoryRowText(for: type, state: state)
            let dimmed = Self.armoryRowIsDimmed(type, state: state)
            bundle.line1Label.text = text.line1
            bundle.line2Label.text = text.line2
            bundle.line1Label.fontSize = 13
            bundle.line2Label.fontSize = 11
            if let layout = kingdomLayout,
               let index = SoldierType.allCases.firstIndex(of: type) {
                bundle.panel.apply(
                    size: layout.armoryRowFrames[index].size,
                    style: dimmed ? .disabled : .normal,
                    showsRivets: true,
                    appearance: .forged
                )
                bundle.line1Label.shrinkFontSize(
                    toFitWidth: layout.armoryTextFrames[index].width,
                    floor: 9
                )
                bundle.line2Label.shrinkFontSize(
                    toFitWidth: layout.armoryTextFrames[index].width,
                    floor: 8
                )
                if bundle.line2Label.frame.width > layout.armoryTextFrames[index].width {
                    // Keep the effect and rounding disclosure legible on the
                    // narrowest layouts; accessibility retains the full hint.
                    bundle.line2Label.text = text.line2.replacingOccurrences(
                        of: " · Drops at City ",
                        with: " · City "
                    )
                    if bundle.line2Label.frame.width > layout.armoryTextFrames[index].width {
                        // 264pt scenes: even the compacted hint overflows —
                        // drop the next-drop segment; effect, level, percent
                        // and the no-gain disclosure stay visible.
                        bundle.line2Label.text = text.line2
                            .components(separatedBy: " · ")
                            .filter { !$0.hasPrefix("Drops at City ") }
                            .joined(separator: " · ")
                    }
                }
            }
            let contentAlpha: CGFloat = dimmed ? GameUITheme.Alpha.lockedIcon : 1
            bundle.line1Label.alpha = contentAlpha
            bundle.line2Label.alpha = contentAlpha
            bundle.iconHolder.alpha = contentAlpha

            // Redraw runs on every purchase/equip/section switch — the
            // texture or glyph only needs rebuilding when this row's
            // equipped item actually changed.
            let equippedItem = state.equippedItem(for: type)
            if bundle.iconHolder.children.isEmpty
                || armoryIconEquippedItemIDs[type] != equippedItem?.id {
                bundle.iconHolder.removeAllChildren()
                let icon = makeArmoryIconNode(for: equippedItem, soldierType: type)
                icon.name = "\(NodeName.armoryIconPrefix)\(type.rawValue)"
                icon.zPosition = 1
                bundle.iconHolder.addChild(icon)
                armoryIconEquippedItemIDs[type] = equippedItem?.id
            }
        }

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
                if upgrade == .drillYard,
                   bundle.effectLabel.frame.width > layout.effectLabelFrames[index].width {
                    bundle.effectLabel.text = Self.drillYardExampleText(for: state)
                        .replacingOccurrences(of: "Infantry", with: "Inf")
                        .replacingOccurrences(of: " vs this city's trait", with: " · trait")
                        .replacingOccurrences(of: " + gear, city trait", with: " · gear + trait")
                        .replacingOccurrences(of: ", city trait", with: " · trait")
                        .replacingOccurrences(of: " attack", with: " atk")
                        .replacingOccurrences(of: " (no damage change yet)", with: " (no gain)")
                }
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
        applySectionVisibility()
        // Keep the exposed elements' labels/values/traits current even when
        // no re-expose happens between a purchase and the next VoiceOver read.
        refreshSceneAccessibilityElements()
    }

    /// Styles one header section control: the selected section reads as
    /// selected, the others stay plain buttons.
    private func applySectionSelector(
        _ panel: PanelNode,
        label: SKLabelNode,
        frame: CGRect?,
        section: KingdomSection
    ) {
        let isSelected = selectedSection == section
        if let frame {
            panel.apply(
                size: frame.size,
                style: isSelected ? .selected : .normal,
                showsRivets: false,
                appearance: .forged
            )
            label.fontSize = 13
            label.shrinkFontSize(toFitWidth: frame.width - 8, floor: 9)
        }
        label.alpha = isSelected ? 1 : GameUITheme.Alpha.unaffordableIcon
    }

    /// HPA-672 Ascend content redraw: the inspectable summary (bonus,
    /// resets, keeps and — while the action is locked — the visible
    /// requirement) always renders; the action is disabled until the
    /// campaign is complete with no pending report, and relabels to
    /// "Confirm Ascension" while the two-tap confirmation is armed.
    private func redrawAscendContent() {
        guard let ascend = ascendContent else { return }
        ascend.bonusLabel.text = Self.ascendBonusText(for: state)
        ascend.resetsLabel.text = Self.ascendResetsText
        ascend.keepsLabel.text = Self.ascendKeepsText
        // The locked action's requirement is visible text too, not just
        // an accessibility value (the section is inspectable by sight).
        let requirementText = isAscendActionEnabled
            ? nil
            : Self.ascendRequirementText(for: state)
        ascend.requirementLabel.text = requirementText
        ascend.requirementLabel.isHidden = requirementText == nil
        ascend.bonusLabel.fontSize = 15
        ascend.resetsLabel.fontSize = 13
        ascend.keepsLabel.fontSize = 13
        ascend.requirementLabel.fontSize = 13

        let actionEnabled = isAscendActionEnabled
        let armed = isAscendConfirmationArmed
        ascend.primaryLabel.text = armed ? "Confirm Ascension" : "Ascend"
        ascend.primaryLabel.fontSize = 15
        ascend.cancelLabel.fontSize = 15
        if let layout = kingdomLayout {
            ascend.bonusLabel.shrinkFontSize(
                toFitWidth: layout.ascendBonusLabelFrame.width,
                floor: 9
            )
            ascend.resetsLabel.shrinkFontSize(
                toFitWidth: layout.ascendResetsLabelFrame.width,
                floor: 9
            )
            ascend.keepsLabel.shrinkFontSize(
                toFitWidth: layout.ascendKeepsLabelFrame.width,
                floor: 9
            )
            ascend.requirementLabel.shrinkFontSize(
                toFitWidth: layout.ascendRequirementLabelFrame.width,
                floor: 9
            )
            ascend.primaryPanel.apply(
                size: layout.ascendPrimaryActionFrame.size,
                style: armed ? .primaryAction : (actionEnabled ? .normal : .disabled),
                showsRivets: false,
                appearance: .forged
            )
            ascend.primaryLabel.shrinkFontSize(
                toFitWidth: layout.ascendPrimaryActionFrame.width - 8,
                floor: 9
            )
            ascend.cancelPanel.isHidden = !armed
            if armed {
                ascend.cancelPanel.apply(
                    size: layout.ascendCancelFrame.size,
                    style: .normal,
                    showsRivets: false,
                    appearance: .forged
                )
                ascend.cancelLabel.shrinkFontSize(
                    toFitWidth: layout.ascendCancelFrame.width - 8,
                    floor: 9
                )
            }
        }
        ascend.primaryLabel.alpha = actionEnabled ? 1 : 0.5
    }

    /// One definition of the Ascend action affordance shared by the
    /// redraw and the accessibility traits — the model's own eligibility
    /// rule, never a scene-side copy of the stage gate.
    private var isAscendActionEnabled: Bool {
        state.canAscend
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
    /// damage paths use. Every first-round modifier the seam folds in is
    /// labeled — equipped attack gear and Renown alike — because each can
    /// change the upgrade's rounded result.
    static func drillYardExampleText(for state: KingdomGameState) -> String {
        let infantryLevel = state.manualSoldierLevel(for: .infantry) ?? 1
        let drillYardLevel = state.treasury.drillYard
        var exampleModifiers: [String] = []
        if state.equipmentAttackMultiplier(for: .infantry) != 1 {
            exampleModifiers.append("gear")
        }
        if state.ascensionCount > 0 {
            exampleModifiers.append("Renown")
        }
        let exampleContext = exampleModifiers.isEmpty
            ? "Infantry Lv \(infantryLevel) vs this city's trait"
            : "Infantry Lv \(infantryLevel) + \(exampleModifiers.joined(separator: " + ")), city trait"

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
            return "\(exampleContext): \(current) attack"
        }
        let next = attack(atUpgradeLevel: drillYardLevel + 1)
        let changeNote = current == next ? " (no damage change yet)" : ""
        // Two lines: the wrapped pair fits every accepted layout's text frame
        // (including 320pt phones) without dropping the no-change note.
        return "\(exampleContext):\n"
            + "\(current) → \(next) attack\(changeNote)"
    }

    // MARK: - Armory row projections (HPA-671)

    /// Compact two-line Armory row copy: line 1 type + equipped short
    /// name/`None`; line 2 equipped effect + next unearned drop. Fuller
    /// flavor rides in the row's accessible value, not stacked text.
    static func armoryRowText(
        for type: SoldierType,
        state: KingdomGameState
    ) -> (line1: String, line2: String) {
        let equipped = state.equippedItem(for: type)
        let line1 = "\(type.displayName) · \(equipped?.name ?? "None")"

        let owned = Set(state.ownedEquipmentIDs)
        let nextDrop = EquipmentCatalog.forType(type).first { !owned.contains($0.id) }
        var line2Parts: [String] = []
        if let equipped, let effect = state.equippedEffect(for: type) {
            // HPA-672: text, level and rounding disclosure all read the one
            // leveled-effect accessor — never the raw catalog fraction.
            var effectText = equipmentEffectText(
                for: effect,
                level: state.equipmentLevel(for: equipped.id) ?? 1
            )
            // The two-round integer math can round an equipped bonus back
            // to the unequipped result at this type's current level — the
            // row discloses it instead of claiming a gain the spawn path
            // won't deliver (same honesty as the Drill Yard example).
            if Self.equippedEffectRoundsAway(effect, for: type, state: state) {
                effectText += " (no gain yet)"
            }
            line2Parts.append(effectText)
        }
        if let nextDrop {
            line2Parts.append("Drops at City \(nextDrop.cityNumber)")
        }
        if line2Parts.isEmpty {
            line2Parts.append("All gear earned")
        }
        return (line1, line2Parts.joined(separator: " · "))
    }

    static func equipmentEffectText(for effect: EquipmentEffect, level: Int) -> String {
        switch effect {
        case .attackBonus(let fraction):
            return "Attack Lv \(level) · +\(percentText(fraction))%"
        case .maxHPBonus(let fraction):
            return "Max HP Lv \(level) · +\(percentText(fraction))%"
        case .specialistBonus(let target, let fraction):
            return "vs \(target.displayName) Lv \(level) · +\(percentText(fraction))%"
        }
    }

    /// True when the equipped item's realized integer equals the
    /// unequipped outcome at this type's current level — the bonus is
    /// applied but rounded away by the two-round integer math (the same
    /// granularity the Drill Yard example discloses). The effect passed in
    /// is the leveled `equippedEffect(for:)` value; the projections below
    /// read the same scaled seams combat uses: the one-round attack fold,
    /// the role×gear second round, and `spawnSoldier`'s max-HP formula.
    static func equippedEffectRoundsAway(
        _ effect: EquipmentEffect,
        for type: SoldierType,
        state: KingdomGameState
    ) -> Bool {
        let level = state.manualSoldierLevel(for: type) ?? 1
        switch effect {
        case .attackBonus:
            var bare = state
            bare.unequip(soldierType: type)
            return state.traitAdjustedSoldierAttackPower(for: type, level: level)
                == bare.traitAdjustedSoldierAttackPower(for: type, level: level)
        case .specialistBonus(let target, _):
            let power = state.traitAdjustedSoldierAttackPower(for: type, level: level)
            return type.roleAdjustedDamage(
                power: power,
                against: target,
                specialist: state.equipmentSpecialistBonus(for: type)
            ) == type.roleAdjustedDamage(power: power, against: target)
        case .maxHPBonus:
            let configuration = BattleCombatState.Configuration.live(cityLevel: state.cityLevel)
            return BattleCombatState.soldierMaxHP(
                for: type,
                level: level,
                hpMultiplier: state.equipmentMaxHPMultiplier(for: type),
                configuration: configuration
            ) == BattleCombatState.soldierMaxHP(
                for: type,
                level: level,
                configuration: configuration
            )
        }
    }

    /// A type stays dimmed until its spawning building unlocks — the same
    /// seam Building View uses, matching the catalog's earliest drop city.
    static func armoryRowIsDimmed(_ type: SoldierType, state: KingdomGameState) -> Bool {
        !state.isBuildingTypeUnlocked(BuildingType(soldierType: type))
    }

    /// The one effective-percent formatter (HPA-672): at most one decimal,
    /// so a leveled +22.5% never displays as a claimed 23% — 0.225 renders
    /// "22.5", 0.30 "30".
    private static func percentText(_ fraction: Double) -> String {
        let tenths = (fraction * 1000).rounded()
        let text = String(format: "%.1f", tenths / 10)
        return text.hasSuffix(".0") ? String(text.dropLast(2)) : text
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
        if let section = kingdomSection(at: point) {
            selectSection(section)
            return
        }
        if selectedSection == .ascend, let action = ascendAction(at: point) {
            handleAscendActionTouch(action)
            return
        }
        if selectedSection == .armory, let type = armoryRowType(at: point) {
            handleArmoryRowTouch(type)
            return
        }
        if selectedSection == .treasury, let upgrade = buyUpgrade(at: point) {
            handleBuyTouch(upgrade)
        }
    }

    private func kingdomSection(at point: CGPoint) -> KingdomSection? {
        guard let layout = kingdomLayout else { return nil }
        if layout.armorySelectorFrame.contains(point) { return .armory }
        if layout.treasurySelectorFrame.contains(point) { return .treasury }
        if layout.ascendSelectorFrame.contains(point) { return .ascend }
        return nil
    }

    private func armoryRowType(at point: CGPoint) -> SoldierType? {
        guard let layout = kingdomLayout else { return nil }
        for (index, type) in SoldierType.allCases.enumerated()
        where layout.armoryRowFrames[index].contains(point) {
            return type
        }
        return nil
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

    // MARK: - Armory cycling (HPA-671)

    /// Ephemeral section switch: never settles, never saves — only
    /// visibility and selector styling change. A change also disarms the
    /// transient Ascension confirmation (spec). The exposed element
    /// membership changes with the section, so the adapter re-exposes.
    private func selectSection(_ section: KingdomSection) {
        guard selectedSection != section else { return }
        selectedSection = section
        isAscendConfirmationArmed = false
        redraw()
        activeAccessibilityAdapter?.refreshSceneElements()
    }

    /// Whole-row tap cycles `None → owned items in city order → None`.
    /// Rows with no owned items do nothing; real changes follow the same
    /// settle-before-mutation sequence as a Treasury Buy tap.
    private func handleArmoryRowTouch(_ type: SoldierType) {
        var latest = store.load()
        let ownedBeforeSettle = EquipmentCatalog.forType(type).filter { item in
            latest.ownedEquipmentIDs.contains(item.id)
        }
        guard !ownedBeforeSettle.isEmpty else {
            redraw()
            return
        }

        // Same rule as a Buy tap: credit the armed interval at the OLD
        // loadout before the cycle changes it, then re-arm.
        let settleDate = Date()
        settleIdleProgress(in: &latest, at: settleDate) {
            $0.conqueredCities == 0
        }

        // The settle can itself conquer and grant a new item of this type
        // (the gear-grant seam in completeCurrentCity), so recompute the
        // cycle from post-settle ownership — the stale list would skip the
        // new item straight to None. Ownership never shrinks, so the
        // pre-settle guard above still applies.
        let owned = EquipmentCatalog.forType(type).filter { item in
            latest.ownedEquipmentIDs.contains(item.id)
        }

        let current = latest.equippedItemBySoldierType[type.rawValue]
        let next: String?
        if let current,
           let currentIndex = owned.firstIndex(where: { $0.id == current }) {
            next = currentIndex + 1 < owned.count ? owned[currentIndex + 1].id : nil
        } else {
            next = owned.first?.id
        }
        if let next {
            _ = latest.equip(itemID: next)
        } else {
            _ = latest.unequip(soldierType: type)
        }
        state = latest
        store.save(state)
        redraw()
        routePendingConquestIfNeeded()
    }

    // MARK: - Ascension (HPA-672)

    /// The Ascend section's two ≥44pt targets: the primary action (label
    /// "Ascend", then "Confirm Ascension" once armed) and the Cancel that
    /// exists only while armed.
    private enum AscendAction {
        case primary
        case cancel
    }

    private func ascendAction(at point: CGPoint) -> AscendAction? {
        guard let layout = kingdomLayout else { return nil }
        if layout.ascendPrimaryActionFrame.contains(point) { return .primary }
        if isAscendConfirmationArmed, layout.ascendCancelFrame.contains(point) {
            return .cancel
        }
        return nil
    }

    /// Two-tap confirmation: the first Ascend tap arms, the distinct
    /// Confirm tap commits, Cancel disarms. A disabled tap changes
    /// nothing (the section stays inspectable). VoiceOver activation
    /// bypasses `handleTouch`, so the live-scene gate repeats here: a
    /// gate-paused, backgrounded or mid-route scene never arms, commits
    /// or routes — the full reset can only run while this scene is live.
    private func handleAscendActionTouch(_ action: AscendAction) {
        guard !isRoutingToBattle,
              !isLayoutGatePaused,
              !isSystemBackgrounded,
              kingdomLayout != nil else {
            return
        }
        let wasArmed = isAscendConfirmationArmed
        switch action {
        case .cancel:
            isAscendConfirmationArmed = false
            redraw()
        case .primary:
            if isAscendActionEnabled {
                if isAscendConfirmationArmed {
                    commitAscension()
                } else {
                    isAscendConfirmationArmed = true
                    redraw()
                }
            } else {
                redraw()
            }
        }
        // Arming swaps the exposed membership (the Cancel element
        // appears/disappears) — re-expose like a section switch does.
        if isAscendConfirmationArmed != wasArmed {
            activeAccessibilityAdapter?.refreshSceneElements()
        }
    }

    /// The one commit path (spec): re-read the latest store state — never
    /// the scene's local copy — re-check eligibility through the pure
    /// `ascend()` guard, save once, then route to Battle through the
    /// existing Kingdom routing. Only reachable while the scene is live
    /// (the action gate above blocks paused/backgrounded/mid-route
    /// commits), so the route needs no second pause check. A rejection
    /// changes nothing and saves nothing; an awaiting report is never
    /// acknowledged (the guard itself rejects a pending result).
    private func commitAscension() {
        isAscendConfirmationArmed = false
        var latest = store.load()
        switch latest.ascend() {
        case .ascended:
            state = latest
            store.save(state)
            redraw()
            isRoutingToBattle = true
            if router?.kingdomSceneDidRequestGameplayTab(self, tab: .battle) != true {
                isRoutingToBattle = false
                redraw()
            }
        case .unavailable:
            // The re-read state failed the pure guard: adopt it for display
            // only — no save, no route, no mutation.
            state = latest
            redraw()
        }
    }

    // MARK: - Ascend projections

    /// Header Renown summary: nil at count 0 (gold-only header), otherwise
    /// the spec's "Renown 2 · +50%" shape driven by `renownMultiplier`.
    static func headerRenownText(for state: KingdomGameState) -> String? {
        guard state.ascensionCount > 0 else { return nil }
        let percent = Int(((state.renownMultiplier - 1) * 100).rounded())
        return "Renown \(state.ascensionCount) · +\(percent)%"
    }

    /// Current → next permanent bonus, always inspectable even while the
    /// action is locked. The next step reads the model's own 0.25/count
    /// curve at the post-ascend count — never a hard-coded +25.
    static func ascendBonusText(for state: KingdomGameState) -> String {
        let current = Int(((state.renownMultiplier - 1) * 100).rounded())
        let nextCount = min(
            state.ascensionCount + 1,
            KingdomGameState.maximumAscensionCount
        )
        let next = Int(
            ((KingdomGameState.renownMultiplier(forAscensionCount: nextCount) - 1) * 100).rounded()
        )
        return "Renown bonus +\(current)% → +\(next)%"
    }

    /// The explicit Resets / Keeps preview (the spec's reset-vs-permanent
    /// table, complete): country/city progress AND camp buildings
    /// (cityBattleStates) reset; owned equipment, slot selections
    /// (including deliberately empty slots), gear levels, the Renown count
    /// and the sound/haptic preferences stay. Each line wraps once at an
    /// authored \n so every fact stays visibly legible at the compact
    /// widths — the fitter shrinks to the 9pt floor on the widest line,
    /// it never truncates a fact away.
    static let ascendResetsText =
        "Resets: country/city progress,\ncamp buildings, gold, Treasury"
    static let ascendKeepsText =
        "Keeps: equipment, slot selections (empty\nslots too), gear levels, Renown, sound, haptics"

    /// Why the action is disabled — shown as the content band's visible
    /// requirement line and repeated in the action's accessible value.
    static func ascendRequirementText(for state: KingdomGameState) -> String {
        state.pendingBattleResult != nil
            ? "Confirm the final report first"
            : "Requires Country 1 complete"
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
        // Accepted exit: the synchronous destination presentation inside
        // the routing call dismisses this scene, and `willMove(from:)`
        // owns the disarm — no separate clear here.
        redraw()
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
        // Hours later, one stray Confirm tap must not finish the wipe —
        // time away always disarms the two-tap confirmation.
        isAscendConfirmationArmed = false
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
        // A pause can outlast hours — an armed Confirm must not survive it.
        isAscendConfirmationArmed = false

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

        var sections: [KingdomSection: ActionAccessibilityElement] = [:]
        for section in KingdomSection.allCases {
            let element = ActionAccessibilityElement(accessibilityContainer: container) { [weak self] in
                self?.selectSection(section)
            }
            element.accessibilityIdentifier = "kingdom-section-\(section.displayName.lowercased())"
            element.accessibilityTraits = .button
            sections[section] = element
        }

        var armoryRows: [SoldierType: ActionAccessibilityElement] = [:]
        for type in SoldierType.allCases {
            let row = ActionAccessibilityElement(accessibilityContainer: container) { [weak self] in
                self?.handleArmoryRowTouch(type)
            }
            row.accessibilityIdentifier = "kingdom-armory-row-\(type.rawValue)"
            row.accessibilityTraits = .button
            armoryRows[type] = row
        }

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

        // HPA-672 Ascend exposure: the inspectable summary, the two-tap
        // action (relabeling to Confirm Ascension while armed) and the
        // armed-only Cancel.
        let ascendInfo = UIAccessibilityElement(accessibilityContainer: container)
        ascendInfo.accessibilityIdentifier = "kingdom-ascend-info"
        ascendInfo.accessibilityTraits = .staticText
        let ascendAction = ActionAccessibilityElement(accessibilityContainer: container) { [weak self] in
            self?.handleAscendActionTouch(.primary)
        }
        ascendAction.accessibilityIdentifier = "kingdom-ascend-action"
        ascendAction.accessibilityTraits = .button
        let ascendCancel = ActionAccessibilityElement(accessibilityContainer: container) { [weak self] in
            self?.handleAscendActionTouch(.cancel)
        }
        ascendCancel.accessibilityIdentifier = "kingdom-ascend-cancel"
        ascendCancel.accessibilityTraits = .button

        return SceneAccessibilityElements(
            header: header,
            sections: sections,
            rows: rows,
            buys: buys,
            armoryRows: armoryRows,
            ascendInfo: ascendInfo,
            ascendAction: ascendAction,
            ascendCancel: ascendCancel
        )
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
        for section in KingdomSection.allCases {
            if let control = elements.sections[section] { ordered.append(control) }
        }
        // Only the selected section's rows are visible — expose those.
        if selectedSection == .treasury {
            for upgrade in TreasuryUpgrade.allCases {
                if let row = elements.rows[upgrade] { ordered.append(row) }
                if let buy = elements.buys[upgrade] { ordered.append(buy) }
            }
        } else if selectedSection == .armory {
            for type in SoldierType.allCases {
                if let row = elements.armoryRows[type] { ordered.append(row) }
            }
        } else {
            ordered.append(elements.ascendInfo)
            ordered.append(elements.ascendAction)
            if isAscendConfirmationArmed {
                ordered.append(elements.ascendCancel)
            }
        }
        return ordered
    }

    private func refreshSceneAccessibilityElements() {
        guard let elements = sceneAccessibilityElements,
              let layout = kingdomLayout,
              let adapter = activeAccessibilityAdapter else {
            return
        }

        // Constant accessible header: the visible title is gone, but
        // VoiceOver still identifies the screen (HPA-672).
        elements.header.accessibilityLabel = "Kingdom"
        elements.header.accessibilityValue = [
            goldLabel.text,
            renownLabel.text
        ]
            .compactMap { $0 }
            .joined(separator: ". ")
        elements.header.accessibilityFrame = adapter.screenAccessibilityFrame(
            for: layout.headerFrame
        ) ?? .zero

        for section in KingdomSection.allCases {
            guard let control = elements.sections[section] else { continue }
            control.accessibilityLabel = "\(section.displayName) section"
            control.accessibilityTraits = selectedSection == section
                ? [.button, .selected]
                : .button
            let frame: CGRect
            switch section {
            case .treasury:
                frame = layout.treasurySelectorFrame
            case .armory:
                frame = layout.armorySelectorFrame
            case .ascend:
                frame = layout.ascendSelectorFrame
            }
            control.accessibilityFrame = adapter.screenAccessibilityFrame(for: frame) ?? .zero
        }

        for (index, type) in SoldierType.allCases.enumerated() {
            let text = Self.armoryRowText(for: type, state: state)
            let equipped = state.equippedItem(for: type)
            let row = elements.armoryRows[type]
            row?.accessibilityLabel = "\(type.displayName) gear"
            row?.accessibilityValue = [
                text.line1,
                text.line2,
                equipped?.flavorText
            ]
                .compactMap { $0 }
                .joined(separator: ". ")
            let hasOwnedGear = EquipmentCatalog.forType(type).contains { item in
                state.ownedEquipmentIDs.contains(item.id)
            }
            row?.accessibilityTraits = hasOwnedGear ? .button : [.button, .notEnabled]
            row?.accessibilityFrame = adapter.screenAccessibilityFrame(
                for: layout.armoryRowFrames[index]
            ) ?? .zero
        }

        for (index, upgrade) in TreasuryUpgrade.allCases.enumerated() {
            let level = state.treasury.level(for: upgrade)
            let row = elements.rows[upgrade]
            row?.accessibilityLabel = "\(upgrade.displayName), level \(level) of \(upgrade.maxLevel)"
            row?.accessibilityValue = Self.effectText(for: upgrade, state: state)
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

        // HPA-672 Ascend exposure: the full summary value (fitted visible
        // labels can shrink; VoiceOver never loses the complete text) and
        // the action's selected/disabled state.
        let info = elements.ascendInfo
        info.accessibilityLabel = "Ascension"
        info.accessibilityValue = [
            Self.ascendBonusText(for: state),
            Self.ascendResetsText,
            Self.ascendKeepsText
        ].joined(separator: ". ")
        info.accessibilityFrame = adapter.screenAccessibilityFrame(
            for: CGRect(
                x: layout.ascendPanelFrame.minX,
                y: layout.ascendRequirementLabelFrame.minY,
                width: layout.ascendPanelFrame.width,
                height: layout.ascendPanelFrame.maxY - layout.ascendRequirementLabelFrame.minY
            )
        ) ?? .zero

        let actionEnabled = isAscendActionEnabled
        let action = elements.ascendAction
        action.accessibilityLabel = isAscendConfirmationArmed
            ? "Confirm Ascension"
            : "Ascend"
        action.accessibilityValue = actionEnabled
            ? nil
            : Self.ascendRequirementText(for: state)
        action.accessibilityTraits = actionEnabled
            ? (isAscendConfirmationArmed ? [.button, .selected] : .button)
            : [.button, .notEnabled]
        action.accessibilityFrame = adapter.screenAccessibilityFrame(
            for: layout.ascendPrimaryActionFrame
        ) ?? .zero

        let cancel = elements.ascendCancel
        cancel.accessibilityLabel = "Cancel"
        cancel.accessibilityFrame = adapter.screenAccessibilityFrame(
            for: layout.ascendCancelFrame
        ) ?? .zero
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

    struct ArmoryRowTextForTesting {
        let line1: String
        let line2: String
    }

    struct AscendContentTextForTesting {
        let bonus: String
        let resets: String
        let keeps: String
        let requirement: String?
    }

    var goldTextForTesting: String? { goldLabel.text }

    var renownTextForTesting: String? {
        renownLabel.isHidden ? nil : renownLabel.text
    }

    var selectedSectionForTesting: KingdomSection { selectedSection }

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

    var renownLabelNodeForTesting: SKLabelNode { renownLabel }

    func sectionSelectorLabelForTesting(_ section: KingdomSection) -> SKLabelNode? {
        switch section {
        case .treasury: return treasurySelectorLabel
        case .armory: return armorySelectorLabel
        case .ascend: return ascendSelectorLabel
        }
    }

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

    func treasurySelectorHitFrameForTesting() -> CGRect? {
        kingdomLayout?.treasurySelectorFrame
    }

    func armorySelectorHitFrameForTesting() -> CGRect? {
        kingdomLayout?.armorySelectorFrame
    }

    func ascendSelectorHitFrameForTesting() -> CGRect? {
        kingdomLayout?.ascendSelectorFrame
    }

    func ascendPrimaryActionHitFrameForTesting() -> CGRect? {
        kingdomLayout?.ascendPrimaryActionFrame
    }

    func ascendCancelHitFrameForTesting() -> CGRect? {
        kingdomLayout?.ascendCancelFrame
    }

    var ascendPanelNodeForTesting: SKNode? { ascendContent?.panel }

    var ascendIconNodeForTesting: SKNode? { ascendContent?.iconHolder.children.first }

    var isAscendConfirmationArmedForTesting: Bool { isAscendConfirmationArmed }

    var isAscendActionEnabledForTesting: Bool { isAscendActionEnabled }

    var ascendActionTextForTesting: String? { ascendContent?.primaryLabel.text }

    func ascendContentTextForTesting() -> AscendContentTextForTesting? {
        guard let ascend = ascendContent else { return nil }
        return AscendContentTextForTesting(
            bonus: ascend.bonusLabel.text ?? "",
            resets: ascend.resetsLabel.text ?? "",
            keeps: ascend.keepsLabel.text ?? "",
            requirement: ascend.requirementLabel.isHidden ? nil : ascend.requirementLabel.text
        )
    }

    var ascendRequirementLabelNodeForTesting: SKLabelNode? {
        guard let label = ascendContent?.requirementLabel, !label.isHidden else { return nil }
        return label
    }

    var ascendResetsLabelNodeForTesting: SKLabelNode? {
        guard let label = ascendContent?.resetsLabel, !label.isHidden else { return nil }
        return label
    }

    var ascendKeepsLabelNodeForTesting: SKLabelNode? {
        guard let label = ascendContent?.keepsLabel, !label.isHidden else { return nil }
        return label
    }

    func armoryRowNodeForTesting(_ type: SoldierType) -> SKNode? {
        armoryRowBundles[type]?.panel
    }

    func armoryRowLabelNodesForTesting(_ type: SoldierType) -> (line1: SKLabelNode, line2: SKLabelNode)? {
        guard let bundle = armoryRowBundles[type] else { return nil }
        return (bundle.line1Label, bundle.line2Label)
    }

    func armoryRowTextForTesting(_ type: SoldierType) -> ArmoryRowTextForTesting? {
        guard let bundle = armoryRowBundles[type] else { return nil }
        return ArmoryRowTextForTesting(
            line1: bundle.line1Label.text ?? "",
            line2: bundle.line2Label.text ?? ""
        )
    }

    func armoryRowHitFrameForTesting(_ type: SoldierType) -> CGRect? {
        guard let layout = kingdomLayout,
              let index = SoldierType.allCases.firstIndex(of: type) else {
            return nil
        }
        return layout.armoryRowFrames[index]
    }

    func armoryIconNodeForTesting(_ type: SoldierType) -> SKNode? {
        armoryRowBundles[type]?.iconHolder.children.first
    }

    func isArmoryRowDimmedForTesting(_ type: SoldierType) -> Bool {
        guard let bundle = armoryRowBundles[type] else { return false }
        return bundle.line1Label.alpha < 1
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
