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

/// HPA-671 ephemeral Kingdom tab section. Never persisted: switching
/// sections neither settles nor saves — HPA-672 may extend the header
/// control later.
enum KingdomSection: Equatable {
    case treasury
    case armory

    var displayName: String {
        switch self {
        case .treasury:
            return "Treasury"
        case .armory:
            return "Armory"
        }
    }
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
        static let armoryRowPrefix = "kingdomArmoryRow-"
        static let armoryIconPrefix = "kingdomArmoryIcon-"
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
    /// Ephemeral section selection (HPA-671): scene UI state only.
    private var selectedSection: KingdomSection = .treasury

    private let headerPanel = PanelNode(size: .zero)
    private let titleLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let goldLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let treasurySelectorPanel = PanelNode(size: .zero)
    private let treasurySelectorLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let armorySelectorPanel = PanelNode(size: .zero)
    private let armorySelectorLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
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

        for (panel, label, name, text) in [
            (treasurySelectorPanel, treasurySelectorLabel, NodeName.treasurySelector, "Treasury"),
            (armorySelectorPanel, armorySelectorLabel, NodeName.armorySelector, "Armory")
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
            iconHolder.name = "\(NodeName.armoryIconPrefix)\(type.rawValue)"
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

        for (frame, panel, label) in [
            (layout.treasurySelectorFrame, treasurySelectorPanel, treasurySelectorLabel),
            (layout.armorySelectorFrame, armorySelectorPanel, armorySelectorLabel)
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
        for bundle in rowBundles.values {
            bundle.panel.isHidden = !treasuryVisible
        }
        for bundle in armoryRowBundles.values {
            bundle.panel.isHidden = !armoryVisible
        }
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
        gameplayTabBar.apply(content: gameplayTabContent, frame: .zero)
        feedbackSettingsController?.applyGearFrame(.zero)
    }

    // MARK: - Redraw

    private func redraw() {
        goldLabel.text = "Gold " + CompactNumberFormatter.string(from: state.gold)

        // The section controls narrowed the header's title line (HPA-671):
        // reset then shrink so a wider resize can re-grow the font.
        titleLabel.fontSize = 26
        if let layout = kingdomLayout {
            titleLabel.shrinkFontSize(
                toFitWidth: layout.titleFrame.width,
                floor: 12
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
            }
            let contentAlpha: CGFloat = dimmed ? GameUITheme.Alpha.lockedIcon : 1
            bundle.line1Label.alpha = contentAlpha
            bundle.line2Label.alpha = contentAlpha
            bundle.iconHolder.alpha = contentAlpha

            bundle.iconHolder.removeAllChildren()
            let icon = makeArmoryIconNode(
                for: state.equippedItem(for: type),
                soldierType: type
            )
            icon.name = "\(NodeName.armoryIconPrefix)\(type.rawValue)"
            icon.zPosition = 1
            bundle.iconHolder.addChild(icon)
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
    /// selected, the other stays a plain button.
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
        if let equipped {
            line2Parts.append(equipmentEffectText(for: equipped.effect))
        }
        if let nextDrop {
            line2Parts.append("Drops at City \(nextDrop.cityNumber)")
        }
        if line2Parts.isEmpty {
            line2Parts.append("All gear earned")
        }
        return (line1, line2Parts.joined(separator: " · "))
    }

    static func equipmentEffectText(for effect: EquipmentEffect) -> String {
        switch effect {
        case .attackBonus(let fraction):
            return "Attack +\(wholePercent(fraction))%"
        case .maxHPBonus(let fraction):
            return "Max HP +\(wholePercent(fraction))%"
        case .specialistBonus(let target, let fraction):
            return "vs \(objectiveDisplayName(target)) +\(wholePercent(fraction))%"
        }
    }

    /// A type stays dimmed until its spawning building unlocks — the same
    /// seam Building View uses, matching the catalog's earliest drop city.
    static func armoryRowIsDimmed(_ type: SoldierType, state: KingdomGameState) -> Bool {
        !state.isBuildingTypeUnlocked(buildingType(for: type))
    }

    private static func buildingType(for type: SoldierType) -> BuildingType {
        BuildingType.allCases.first { $0.soldierType == type } ?? .barracks
    }

    private static func wholePercent(_ fraction: Double) -> Int {
        Int((fraction * 100).rounded())
    }

    private static func objectiveDisplayName(
        _ kind: CitySiegeLayout.ObjectiveKind
    ) -> String {
        switch kind {
        case .keep:
            return "Keep"
        case .gate:
            return "Gate"
        case .arrowTower:
            return "Arrow Tower"
        case .barracks:
            return "Barracks"
        }
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
    /// visibility and selector styling change. The exposed element
    /// membership changes with the section, so the adapter re-exposes.
    private func selectSection(_ section: KingdomSection) {
        guard selectedSection != section else { return }
        selectedSection = section
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

        var sections: [KingdomSection: ActionAccessibilityElement] = [:]
        for section in [KingdomSection.treasury, .armory] {
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
        return SceneAccessibilityElements(
            header: header,
            sections: sections,
            rows: rows,
            buys: buys,
            armoryRows: armoryRows
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
        for section in [KingdomSection.treasury, .armory] {
            if let control = elements.sections[section] { ordered.append(control) }
        }
        // Only the selected section's rows are visible — expose those.
        if selectedSection == .treasury {
            for upgrade in TreasuryUpgrade.allCases {
                if let row = elements.rows[upgrade] { ordered.append(row) }
                if let buy = elements.buys[upgrade] { ordered.append(buy) }
            }
        } else {
            for type in SoldierType.allCases {
                if let row = elements.armoryRows[type] { ordered.append(row) }
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

        elements.header.accessibilityLabel = titleLabel.text
        elements.header.accessibilityValue = goldLabel.text
        elements.header.accessibilityFrame = adapter.screenAccessibilityFrame(
            for: layout.headerFrame
        ) ?? .zero

        for section in [KingdomSection.treasury, .armory] {
            guard let control = elements.sections[section] else { continue }
            control.accessibilityLabel = "\(section.displayName) section"
            control.accessibilityTraits = selectedSection == section
                ? [.button, .selected]
                : .button
            let frame = section == .treasury
                ? layout.treasurySelectorFrame
                : layout.armorySelectorFrame
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

    struct ArmoryRowTextForTesting {
        let line1: String
        let line2: String
    }

    var titleTextForTesting: String? { titleLabel.text }

    var goldTextForTesting: String? { goldLabel.text }

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

    func treasurySelectorHitFrameForTesting() -> CGRect? {
        kingdomLayout?.treasurySelectorFrame
    }

    func armorySelectorHitFrameForTesting() -> CGRect? {
        kingdomLayout?.armorySelectorFrame
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
