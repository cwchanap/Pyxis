# Gaming UI Layout Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the Pyxis battle and country-map UI into a polished Bright Kingdom Siege presentation while preserving all combat, idle, save, and map progression rules.

**Architecture:** Keep `KingdomGameState` and `BattleCombatState` unchanged except where existing tests prove a presentation bug has exposed a model issue. Add small SpriteKit-only presentation helpers, then use them from `BattleScene` and `CountryMapScene`. Generated assets live in `Pyxis/Assets.xcassets`; scene code must keep image-backed fallbacks so tests and builds remain stable if an asset is renamed during art iteration.

**Tech Stack:** Swift 5, SpriteKit, UIKit image loading, Swift Testing, Xcode project with file-system-synchronized groups.

---

## File Structure

- Create `Pyxis/GameUITheme.swift`
  - Centralizes SpriteKit colors, fonts, z positions, common shadows, panel metrics, and safe helper functions for clamping progress values.
- Create `Pyxis/GameUIComponents.swift`
  - Defines SpriteKit presentation-only nodes: `PanelNode` and `ProgressBarNode`.
  - These nodes must not import or depend on game rules.
- Create `PyxisTests/GameUIComponentsTests.swift`
  - Tests progress clamping and panel sizing.
- Modify `Pyxis/BattleScene.swift`
  - Replace the centered vertical HUD stack with Commander HUD clusters.
  - Add richer transient feedback effects and reward-style conquest presentation.
  - Keep existing button names so touch routing stays stable.
- Modify `PyxisTests/BattleSceneTests.swift`
  - Add DEBUG-hook-driven layout and feedback assertions.
  - Keep existing combat and routing tests intact.
- Modify `Pyxis/CountryMapScene.swift`
  - Replace the plain route with an illustrated-region map presentation.
  - Keep city node names and tap routing stable.
- Modify `PyxisTests/CountryMapSceneTests.swift`
  - Add map layout and city-state styling assertions.
- Add or update these asset catalog folders:
  - `Pyxis/Assets.xcassets/battlefield-backdrop.imageset/`
  - `Pyxis/Assets.xcassets/country-map-backdrop.imageset/`
  - `Pyxis/Assets.xcassets/hit-flash.imageset/`
  - `Pyxis/Assets.xcassets/tower-projectile.imageset/`
  - `Pyxis/Assets.xcassets/gold-burst.imageset/`
  - `Pyxis/Assets.xcassets/conquered-marker.imageset/`
  - Existing `player-castle.imageset`, `enemy-city.imageset`, and `normal-soldier.imageset` can be replaced with refined art if the generated set is stronger.

Use a feature branch or worktree when executing this plan. Do not edit `project.pbxproj`; this project uses `PBXFileSystemSynchronizedRootGroup`.

---

### Task 1: Add Shared SpriteKit UI Primitives

**Files:**
- Create: `Pyxis/GameUITheme.swift`
- Create: `Pyxis/GameUIComponents.swift`
- Create: `PyxisTests/GameUIComponentsTests.swift`

- [ ] **Step 1: Write failing tests for shared UI primitives**

Create `PyxisTests/GameUIComponentsTests.swift`:

```swift
//
//  GameUIComponentsTests.swift
//  PyxisTests
//

import CoreGraphics
import SpriteKit
import Testing
@testable import Pyxis

@MainActor
struct GameUIComponentsTests {
    @Test func progressBarClampsFillWidthWithinBounds() {
        let bar = ProgressBarNode(size: CGSize(width: 120, height: 14))

        bar.update(progress: 1.7)
        #expect(bar.fillWidthForTesting == 120)

        bar.update(progress: -0.4)
        #expect(bar.fillWidthForTesting == 0)

        bar.update(progress: 0.25)
        #expect(bar.fillWidthForTesting == 30)
    }

    @Test func panelNodeStoresStableContentSize() {
        let panel = PanelNode(size: CGSize(width: 180, height: 72))

        #expect(panel.contentSizeForTesting == CGSize(width: 180, height: 72))

        panel.update(size: CGSize(width: 200, height: 80))

        #expect(panel.contentSizeForTesting == CGSize(width: 200, height: 80))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests/GameUIComponentsTests
```

Expected: fail because `ProgressBarNode`, `PanelNode`, and `GameUITheme` do not exist.

- [ ] **Step 3: Implement the theme and components**

Create `Pyxis/GameUITheme.swift`:

```swift
//
//  GameUITheme.swift
//  Pyxis
//

import CoreGraphics
import SpriteKit

enum GameUITheme {
    enum Font {
        static let bold = "AvenirNext-DemiBold"
        static let medium = "AvenirNext-Medium"
    }

    enum Color {
        static let panelFill = SKColor(red: 0.07, green: 0.10, blue: 0.13, alpha: 0.88)
        static let panelStroke = SKColor(red: 1.0, green: 0.91, blue: 0.55, alpha: 0.26)
        static let textPrimary = SKColor(red: 0.98, green: 0.94, blue: 0.84, alpha: 1.0)
        static let textSecondary = SKColor(red: 0.72, green: 0.82, blue: 0.86, alpha: 1.0)
        static let gold = SKColor(red: 1.0, green: 0.80, blue: 0.22, alpha: 1.0)
        static let hpFill = SKColor(red: 0.18, green: 0.78, blue: 0.42, alpha: 1.0)
        static let hpBackground = SKColor(red: 0.12, green: 0.16, blue: 0.18, alpha: 0.94)
        static let spawn = SKColor(red: 0.10, green: 0.46, blue: 0.82, alpha: 1.0)
        static let upgradeAvailable = SKColor(red: 0.64, green: 0.36, blue: 0.86, alpha: 1.0)
        static let upgradeUnavailable = SKColor(red: 0.28, green: 0.25, blue: 0.34, alpha: 1.0)
        static let danger = SKColor(red: 0.91, green: 0.29, blue: 0.22, alpha: 1.0)
        static let locked = SKColor(red: 0.20, green: 0.28, blue: 0.34, alpha: 1.0)
    }

    enum Z {
        static let background: CGFloat = -20
        static let battlefield: CGFloat = 0
        static let hud: CGFloat = 100
        static let effects: CGFloat = 140
        static let modal: CGFloat = 200
    }

    static func clampedProgress(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }
}
```

Create `Pyxis/GameUIComponents.swift`:

```swift
//
//  GameUIComponents.swift
//  Pyxis
//

import CoreGraphics
import SpriteKit

final class PanelNode: SKNode {
    private let background = SKShapeNode()
    private(set) var contentSize: CGSize

    init(size: CGSize) {
        self.contentSize = size
        super.init()
        background.fillColor = GameUITheme.Color.panelFill
        background.strokeColor = GameUITheme.Color.panelStroke
        background.lineWidth = 1.5
        addChild(background)
        update(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(size: CGSize) {
        contentSize = size
        background.path = CGPath(
            roundedRect: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height),
            cornerWidth: min(12, size.height / 4),
            cornerHeight: min(12, size.height / 4),
            transform: nil
        )
    }
}

final class ProgressBarNode: SKNode {
    private let background = SKShapeNode()
    private let fill = SKShapeNode()
    private var size: CGSize
    private var fillWidth: CGFloat = 0

    init(size: CGSize) {
        self.size = size
        super.init()
        background.fillColor = GameUITheme.Color.hpBackground
        background.strokeColor = GameUITheme.Color.panelStroke
        background.lineWidth = 1
        fill.fillColor = GameUITheme.Color.hpFill
        fill.strokeColor = .clear
        addChild(background)
        addChild(fill)
        update(size: size)
        update(progress: 0)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(size: CGSize) {
        self.size = size
        background.path = CGPath(
            roundedRect: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height),
            cornerWidth: size.height / 2,
            cornerHeight: size.height / 2,
            transform: nil
        )
        update(progress: size.width == 0 ? 0 : fillWidth / size.width)
    }

    func update(progress: CGFloat) {
        fillWidth = size.width * GameUITheme.clampedProgress(progress)
        let fillRect = CGRect(x: -size.width / 2, y: -size.height / 2, width: fillWidth, height: size.height)
        fill.path = fillWidth <= 0
            ? CGPath(rect: CGRect(x: -size.width / 2, y: -size.height / 2, width: 0, height: size.height), transform: nil)
            : CGPath(roundedRect: fillRect, cornerWidth: size.height / 2, cornerHeight: size.height / 2, transform: nil)
    }
}

#if DEBUG
extension PanelNode {
    var contentSizeForTesting: CGSize {
        contentSize
    }
}

extension ProgressBarNode {
    var fillWidthForTesting: CGFloat {
        fillWidth
    }
}

#endif
```

- [ ] **Step 4: Run primitive tests to verify they pass**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests/GameUIComponentsTests
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit shared UI primitives**

Run:

```bash
git add Pyxis/GameUITheme.swift Pyxis/GameUIComponents.swift PyxisTests/GameUIComponentsTests.swift
git commit -m "Add shared SpriteKit UI primitives"
```

---

### Task 2: Convert BattleScene To Commander HUD Layout

**Files:**
- Modify: `Pyxis/BattleScene.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`

- [ ] **Step 1: Add failing tests for Commander HUD layout**

Append these tests to `BattleSceneTests` before the helper methods:

```swift
    @Test func commanderHUDKeepsTopClustersAndActionsInsideScene() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 30, cityRemainingPower: 20))
        let scene = makeScene(store: store)
        let frames = try #require(scene.battleLayoutFramesForTesting)

        #expect(frames.leftHUD.minX >= 12)
        #expect(frames.rightHUD.maxX <= scene.size.width - 12)
        #expect(frames.leftHUD.maxX < frames.rightHUD.minX)
        #expect(frames.spawnButton.maxY <= frames.battlefield.minY)
        #expect(frames.battlefield.maxY < frames.leftHUD.minY)
        #expect(frames.upgradeButton.minY >= 12)
    }

    @Test func commanderHUDSurvivesCompactLandscapeWithoutOverlap() throws {
        let size = CGSize(width: 667, height: 375)
        let store = try makeStore(initialState: KingdomGameState(gold: 30, cityRemainingPower: 20))
        let scene = BattleScene(size: size, store: store, router: nil)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        scene.didMove(to: view)

        let frames = try #require(scene.battleLayoutFramesForTesting)

        #expect(frames.leftHUD.minX >= 8)
        #expect(frames.rightHUD.maxX <= size.width - 8)
        #expect(frames.spawnButton.minY >= 8)
        #expect(frames.upgradeButton.minY >= 8)
        #expect(frames.feedback.maxY < frames.battlefield.maxY)
    }

    @Test func upgradeButtonCommunicatesAffordabilityWithoutBlockingTapFeedback() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 0, cityRemainingPower: 20))
        let scene = makeScene(store: store)

        #expect(scene.isUpgradeVisuallyAffordableForTesting == false)

        scene.upgradeSoldierForTesting()

        #expect(scene.feedbackTextForTesting == "Need 10 gold. You have 0.")
    }
```

- [ ] **Step 2: Run BattleScene tests to verify they fail**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests/BattleSceneTests
```

Expected: fail because `battleLayoutFramesForTesting`, `isUpgradeVisuallyAffordableForTesting`, `feedbackTextForTesting`, and `upgradeSoldierForTesting()` do not exist.

- [ ] **Step 3: Add battle layout DEBUG hooks**

In the `#if DEBUG extension BattleScene`, add:

```swift
    struct BattleLayoutFrames {
        let leftHUD: CGRect
        let rightHUD: CGRect
        let battlefield: CGRect
        let feedback: CGRect
        let spawnButton: CGRect
        let upgradeButton: CGRect
    }

    var battleLayoutFramesForTesting: BattleLayoutFrames? {
        guard
            let leftHUD = sceneFrame(for: goldLabel),
            let rightHUD = sceneFrame(for: cityLevelLabel),
            let feedback = sceneFrame(for: feedbackLabel),
            let spawnFrame = sceneFrame(for: spawnButton),
            let upgradeFrame = sceneFrame(for: upgradeButton)
        else {
            return nil
        }

        let battlefieldFrame = battlefieldLayer.calculateAccumulatedFrame()
        return BattleLayoutFrames(
            leftHUD: leftHUD,
            rightHUD: rightHUD,
            battlefield: battlefieldFrame,
            feedback: feedback,
            spawnButton: spawnFrame,
            upgradeButton: upgradeFrame
        )
    }

    var isUpgradeVisuallyAffordableForTesting: Bool {
        state.gold >= state.normalSoldierUpgradeCost
    }

    var feedbackTextForTesting: String {
        feedbackText
    }

    func upgradeSoldierForTesting() {
        upgradeSoldier()
    }
```

Use this exact hook first even if later implementation changes it to return panel frames. Tests can be tightened once panels exist.

- [ ] **Step 4: Refactor BattleScene HUD nodes**

In `BattleScene.swift`, add new nodes near the current label declarations:

```swift
    private let leftHUDPanel = PanelNode(size: CGSize(width: 160, height: 78))
    private let rightHUDPanel = PanelNode(size: CGSize(width: 190, height: 86))
    private let cityHPBarNode = ProgressBarNode(size: CGSize(width: 160, height: 12))
```

In `buildInterface()`, set their z positions and add them before labels:

```swift
        [leftHUDPanel, rightHUDPanel, cityHPBarNode].forEach { $0.zPosition = GameUITheme.Z.hud }
        addChild(leftHUDPanel)
        addChild(rightHUDPanel)
        addChild(cityHPBarNode)
```

Keep the existing labels for this task, but restyle them with `GameUITheme` colors:

```swift
        configureLabel(goldLabel, fontSize: 21, color: GameUITheme.Color.gold)
        configureLabel(cityLevelLabel, fontSize: 18, color: GameUITheme.Color.textPrimary)
        configureLabel(soldierAttackLabel, fontSize: 14, color: GameUITheme.Color.textSecondary)
        configureLabel(cityHPLabel, fontSize: 14, color: GameUITheme.Color.textPrimary)
        configureLabel(liveCombatStatusLabel, fontSize: 13, color: GameUITheme.Color.textSecondary)
        configureLabel(feedbackLabel, fontSize: 15, color: GameUITheme.Color.gold)
```

Replace the top part of `layoutInterface()` with Commander HUD placement:

```swift
        let compactHeight = size.height < 500
        let horizontalMargin: CGFloat = compactHeight ? 16 : 18
        let topMargin: CGFloat = compactHeight ? 26 : 46
        let buttonHeight: CGFloat = compactHeight ? 42 : 52
        let buttonGap: CGFloat = compactHeight ? 10 : 12
        let bottomMargin: CGFloat = compactHeight ? 20 : 30
        let centerX = size.width / 2

        let hudGap: CGFloat = compactHeight ? 10 : 12
        let availableHUDWidth = size.width - horizontalMargin * 2 - hudGap
        let leftHUDWidth = max(138, min(180, availableHUDWidth * 0.44))
        let rightHUDWidth = max(158, min(230, availableHUDWidth - leftHUDWidth))
        let hudHeight: CGFloat = compactHeight ? 66 : 82
        let hudCenterY = size.height - topMargin
        let leftHUDCenterX = horizontalMargin + leftHUDWidth / 2
        let rightHUDCenterX = size.width - horizontalMargin - rightHUDWidth / 2

        leftHUDPanel.update(size: CGSize(width: leftHUDWidth, height: hudHeight))
        rightHUDPanel.update(size: CGSize(width: rightHUDWidth, height: hudHeight))
        leftHUDPanel.position = CGPoint(x: leftHUDCenterX, y: hudCenterY)
        rightHUDPanel.position = CGPoint(x: rightHUDCenterX, y: hudCenterY)

        goldLabel.position = CGPoint(x: leftHUDCenterX, y: hudCenterY + hudHeight * 0.24)
        soldierAttackLabel.position = CGPoint(x: leftHUDCenterX, y: hudCenterY - 1)
        liveCombatStatusLabel.position = CGPoint(x: leftHUDCenterX, y: hudCenterY - hudHeight * 0.25)

        cityLevelLabel.position = CGPoint(x: rightHUDCenterX, y: hudCenterY + hudHeight * 0.25)
        cityHPLabel.position = CGPoint(x: rightHUDCenterX, y: hudCenterY - 2)
        cityHPBarNode.position = CGPoint(x: rightHUDCenterX, y: hudCenterY - hudHeight * 0.28)
        cityHPBarNode.update(size: CGSize(width: rightHUDWidth - 26, height: compactHeight ? 10 : 12))
        let hpPercent = CGFloat(state.cityRemainingPower) / CGFloat(max(1, state.cityMaxPower))
        cityHPBarNode.update(progress: hpPercent)
```

Then keep the bottom actions as two side-by-side controls:

```swift
        let buttonWidth = min(210, (size.width - horizontalMargin * 2 - buttonGap) * 0.58)
        let upgradeWidth = max(128, size.width - horizontalMargin * 2 - buttonGap - buttonWidth)
        let buttonY = bottomMargin + buttonHeight / 2
        layoutButton(
            spawnButton,
            background: spawnButtonBackground,
            size: CGSize(width: buttonWidth, height: buttonHeight),
            position: CGPoint(x: horizontalMargin + buttonWidth / 2, y: buttonY)
        )
        layoutButton(
            upgradeButton,
            background: upgradeButtonBackground,
            size: CGSize(width: upgradeWidth, height: buttonHeight),
            position: CGPoint(x: size.width - horizontalMargin - upgradeWidth / 2, y: buttonY)
        )
```

Set `upgradeButtonBackground.fillColor` after labels are updated in `redraw()`:

```swift
        upgradeButtonBackground.fillColor = state.gold >= state.normalSoldierUpgradeCost
            ? GameUITheme.Color.upgradeAvailable
            : GameUITheme.Color.upgradeUnavailable
```

Compute the battlefield safe band from HUD bottom to button top:

```swift
        let hudBottomY = hudCenterY - hudHeight / 2
        let buttonTopY = buttonY + buttonHeight / 2
        let feedbackY = buttonTopY + max(30, (hudBottomY - buttonTopY) * 0.22)
        feedbackLabel.position = CGPoint(x: centerX, y: feedbackY)

        layoutBattlefield(
            contentWidth: min(size.width - horizontalMargin * 2, 560),
            hpBarBottomY: hudBottomY,
            spawnButtonTopY: buttonTopY,
            feedbackY: feedbackY
        )
```

Remove the old `hpBarBackground` and `hpBarFill` from the status stack only after `cityHPBarNode` is wired. The old bar nodes can remain unused for one commit if deletion makes the diff harder to review, but they must not be visible.

- [ ] **Step 5: Run BattleScene tests to verify layout passes**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests/BattleSceneTests
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit Commander HUD layout**

Run:

```bash
git add Pyxis/BattleScene.swift PyxisTests/BattleSceneTests.swift
git commit -m "Redesign battle HUD layout"
```

---

### Task 3: Add Battle Feedback And Reward Effects

**Files:**
- Modify: `Pyxis/BattleScene.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`

- [ ] **Step 1: Add failing tests for visual feedback hooks**

Append these tests to `BattleSceneTests` before helper methods:

```swift
    @Test func cityDamageCreatesFloatingFeedbackNode() throws {
        let store = try makeStore(
            initialState: KingdomGameState(
                cityRemainingPower: 20,
                normalSoldierUpgradeLevel: 4
            )
        )
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 3.0)

        #expect(scene.floatingFeedbackCountForTesting > 0)
    }

    @Test func insufficientGoldRunsUpgradeDeniedFeedback() throws {
        let store = try makeStore(initialState: KingdomGameState(gold: 0, cityRemainingPower: 20))
        let scene = makeScene(store: store)

        scene.upgradeSoldierForTesting()

        #expect(scene.isUpgradeDeniedFeedbackRunningForTesting)
    }

    @Test func conquestPopupUsesRewardPresentationNodes() throws {
        let store = try makeStore(
            initialState: KingdomGameState(
                cityRemainingPower: 1,
                normalSoldierUpgradeLevel: 4
            )
        )
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()
        scene.advanceCombatForTesting(deltaTime: 3.0)

        #expect(scene.isConquestPopupVisibleForTesting)
        #expect(scene.isGoldBurstVisibleForTesting)
    }
```

- [ ] **Step 2: Run BattleScene tests to verify they fail**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests/BattleSceneTests
```

Expected: fail because feedback testing hooks and effects do not exist.

- [ ] **Step 3: Add feedback node names and DEBUG hooks**

In `BattleScene.swift`, add:

```swift
    private enum EffectName {
        static let floatingFeedback = "floatingFeedback"
        static let goldBurst = "goldBurst"
        static let upgradeDenied = "upgradeDeniedFeedback"
        static let upgradeSuccess = "upgradeSuccessFeedback"
    }
```

In the DEBUG extension, add:

```swift
    var floatingFeedbackCountForTesting: Int {
        effectsLayer.children.filter { $0.name == EffectName.floatingFeedback }.count
    }

    var isUpgradeDeniedFeedbackRunningForTesting: Bool {
        upgradeButton.action(forKey: EffectName.upgradeDenied) != nil
    }

    var isGoldBurstVisibleForTesting: Bool {
        effectsLayer.children.contains { $0.name == EffectName.goldBurst }
    }
```

- [ ] **Step 4: Implement transient feedback effects**

Add these private methods in `BattleScene`:

```swift
    private func showFloatingFeedback(_ text: String, at point: CGPoint, color: SKColor = GameUITheme.Color.gold) {
        let label = SKLabelNode(fontNamed: GameUITheme.Font.bold)
        label.name = EffectName.floatingFeedback
        label.text = text
        label.fontSize = 17
        label.fontColor = color
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = point
        label.zPosition = GameUITheme.Z.effects
        effectsLayer.addChild(label)

        let rise = SKAction.moveBy(x: 0, y: 26, duration: 0.55)
        rise.timingMode = .easeOut
        let fade = SKAction.fadeOut(withDuration: 0.55)
        let remove = SKAction.removeFromParent()
        label.run(SKAction.sequence([SKAction.group([rise, fade]), remove]))
    }

    private func playUpgradeSuccessFeedback() {
        upgradeButton.removeAction(forKey: EffectName.upgradeSuccess)
        let grow = SKAction.scale(to: 1.05, duration: 0.08)
        let shrink = SKAction.scale(to: 1.0, duration: 0.12)
        upgradeButton.run(SKAction.sequence([grow, shrink]), withKey: EffectName.upgradeSuccess)
        showFloatingFeedback("ATK up", at: CGPoint(x: upgradeButton.position.x, y: upgradeButton.position.y + 44))
    }

    private func playUpgradeDeniedFeedback() {
        upgradeButton.removeAction(forKey: EffectName.upgradeDenied)
        let left = SKAction.moveBy(x: -7, y: 0, duration: 0.04)
        let right = SKAction.moveBy(x: 14, y: 0, duration: 0.06)
        let center = SKAction.moveBy(x: -7, y: 0, duration: 0.04)
        upgradeButton.run(SKAction.sequence([left, right, center]), withKey: EffectName.upgradeDenied)
    }

    private func showGoldBurst(at point: CGPoint) {
        let burst = SKShapeNode(circleOfRadius: 20)
        burst.name = EffectName.goldBurst
        burst.fillColor = SKColor(red: 1.0, green: 0.78, blue: 0.22, alpha: 0.34)
        burst.strokeColor = GameUITheme.Color.gold
        burst.lineWidth = 3
        burst.position = point
        burst.zPosition = GameUITheme.Z.effects
        effectsLayer.addChild(burst)

        let expand = SKAction.scale(to: 3.0, duration: 0.55)
        expand.timingMode = .easeOut
        let fade = SKAction.fadeOut(withDuration: 0.55)
        let remove = SKAction.removeFromParent()
        burst.run(SKAction.sequence([SKAction.group([expand, fade]), remove]))
    }
```

In `applyCombatResult(_:)`, after damage is applied and before `redraw()`:

```swift
        if damageResult.damageDealt > 0 {
            showFloatingFeedback("-\(damageResult.damageDealt)", at: CGPoint(x: enemyGatePoint.x, y: enemyGatePoint.y + 44))
        }
```

In `upgradeSoldier()`, call:

```swift
        switch result {
        case let .upgraded(cost, newAttackPower):
            feedbackText = "Upgraded for \(cost) gold. Attack: \(newAttackPower)."
            playUpgradeSuccessFeedback()
        case let .insufficientGold(cost, currentGold):
            feedbackText = "Need \(cost) gold. You have \(currentGold)."
            playUpgradeDeniedFeedback()
        case .unavailable:
            feedbackText = "Enter a city to upgrade soldiers."
            playUpgradeDeniedFeedback()
        }
```

In `showConquestPopup(goldEarned:)`, call:

```swift
        showGoldBurst(at: CGPoint(x: size.width / 2, y: size.height / 2))
```

- [ ] **Step 5: Run BattleScene tests to verify feedback passes**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests/BattleSceneTests
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit battle feedback effects**

Run:

```bash
git add Pyxis/BattleScene.swift PyxisTests/BattleSceneTests.swift
git commit -m "Add battle feedback effects"
```

---

### Task 4: Generate And Register Bright Kingdom Siege Assets

**Files:**
- Modify: `Pyxis/Assets.xcassets/player-castle.imageset/player-castle.png`
- Modify: `Pyxis/Assets.xcassets/enemy-city.imageset/enemy-city.png`
- Modify: `Pyxis/Assets.xcassets/normal-soldier.imageset/normal-soldier.png`
- Create: `Pyxis/Assets.xcassets/battlefield-backdrop.imageset/Contents.json`
- Create: `Pyxis/Assets.xcassets/battlefield-backdrop.imageset/battlefield-backdrop.png`
- Create: `Pyxis/Assets.xcassets/country-map-backdrop.imageset/Contents.json`
- Create: `Pyxis/Assets.xcassets/country-map-backdrop.imageset/country-map-backdrop.png`
- Create: `Pyxis/Assets.xcassets/hit-flash.imageset/Contents.json`
- Create: `Pyxis/Assets.xcassets/hit-flash.imageset/hit-flash.png`
- Create: `Pyxis/Assets.xcassets/tower-projectile.imageset/Contents.json`
- Create: `Pyxis/Assets.xcassets/tower-projectile.imageset/tower-projectile.png`
- Create: `Pyxis/Assets.xcassets/gold-burst.imageset/Contents.json`
- Create: `Pyxis/Assets.xcassets/gold-burst.imageset/gold-burst.png`
- Create: `Pyxis/Assets.xcassets/conquered-marker.imageset/Contents.json`
- Create: `Pyxis/Assets.xcassets/conquered-marker.imageset/conquered-marker.png`
- Modify: `Pyxis/BattleScene.swift`
- Modify: `Pyxis/CountryMapScene.swift`

- [ ] **Step 1: Generate the asset set**

Use the image generation skill/tool with these prompts and save the returned PNGs to the exact paths above.

Prompt for `player-castle.png`:

```text
Transparent PNG game asset, bright chibi fantasy kingdom castle, friendly blue and teal rooftops, warm stone walls, readable silhouette at mobile game scale, front three-quarter view, no text, no background, no border, polished mobile idle kingdom game style.
```

Prompt for `enemy-city.png`:

```text
Transparent PNG game asset, bright chibi fantasy enemy fortified city with one tower silhouette, orange red roofs, warm stone walls, readable silhouette at mobile game scale, front three-quarter view, no text, no background, no border, polished mobile idle kingdom game style.
```

Prompt for `normal-soldier.png`:

```text
Transparent PNG game asset, small chibi fantasy foot soldier, blue friendly armor, tiny sword and shield, readable at 40 pixels tall, facing right, no text, no background, no border, polished mobile idle kingdom game style.
```

Prompt for `battlefield-backdrop.png`:

```text
Portrait mobile game battlefield background, bright kingdom siege field, friendly castle side on left implied by terrain, enemy city side on right implied by warm distant hills, clear open center road lane, blue green sky, warm gold light, no characters, no text, no UI, polished chibi fantasy idle kingdom game, safe area for HUD at top and buttons at bottom.
```

Prompt for `country-map-backdrop.png`:

```text
Portrait mobile game illustrated region map for a fantasy kingdom campaign, green plains, river, small mountains, winding road space for 15 city markers, bright colorful chibi fantasy style, no text, no city numbers, no UI, polished mobile kingdom game.
```

Prompt for `hit-flash.png`:

```text
Transparent PNG VFX sprite, bright fantasy impact flash, yellow white center, orange edge, compact burst shape, no text, no background, mobile game effect.
```

Prompt for `tower-projectile.png`:

```text
Transparent PNG VFX sprite, small red orange magic projectile orb with short streak, no text, no background, readable at small mobile game scale.
```

Prompt for `gold-burst.png`:

```text
Transparent PNG VFX sprite, celebratory gold coin burst and sparkle, compact circular reward effect, no text, no background, polished mobile game reward style.
```

Prompt for `conquered-marker.png`:

```text
Transparent PNG game UI marker, small golden conquered banner icon, crown motif, no text, no background, readable at 24 pixels.
```

- [ ] **Step 2: Add asset catalog metadata**

For each new `.imageset/Contents.json`, use this content with the matching filename:

```json
{
  "images": [
    {
      "filename": "battlefield-backdrop.png",
      "idiom": "universal",
      "scale": "1x"
    }
  ],
  "info": {
    "author": "xcode",
    "version": 1
  }
}
```

Use `country-map-backdrop.png`, `hit-flash.png`, `tower-projectile.png`, `gold-burst.png`, or `conquered-marker.png` in the `filename` field for the other image sets.

- [ ] **Step 3: Wire optional image-backed effects in BattleScene**

In `BattleScene.BattleAssetName`, add:

```swift
        static let battlefieldBackdrop = "battlefield-backdrop"
        static let hitFlash = "hit-flash"
        static let towerProjectile = "tower-projectile"
        static let goldBurst = "gold-burst"
```

Add:

```swift
    private var battlefieldBackdropNode: SKSpriteNode?
```

In `buildBattlefield()`, before castles:

```swift
        if UIImage(named: BattleAssetName.battlefieldBackdrop) != nil {
            let backdrop = SKSpriteNode(imageNamed: BattleAssetName.battlefieldBackdrop)
            backdrop.name = BattleAssetName.battlefieldBackdrop
            backdrop.zPosition = GameUITheme.Z.background
            backdrop.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            battlefieldLayer.addChild(backdrop)
            battlefieldBackdropNode = backdrop
        }
```

In `layoutBattlefield(...)`, after `setBattlefieldHidden(false)`:

```swift
        if let battlefieldBackdropNode {
            battlefieldBackdropNode.position = CGPoint(x: size.width / 2, y: (safeBottomY + safeTopY) / 2)
            let targetSize = CGSize(width: size.width, height: max(1, safeTopY - safeBottomY + 44))
            let scale = max(
                targetSize.width / max(1, battlefieldBackdropNode.size.width),
                targetSize.height / max(1, battlefieldBackdropNode.size.height)
            )
            battlefieldBackdropNode.setScale(scale)
        }
```

Update `playImpactFlash()`, `playTowerShot(at:)`, and `showGoldBurst(at:)` to use `SKSpriteNode(imageNamed:)` when `UIImage(named:)` exists, and fall back to the current shape effects otherwise.

- [ ] **Step 4: Add build verification**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'generic/platform=iOS Simulator' build
```

Expected: build succeeds with no missing asset catalog errors.

- [ ] **Step 5: Commit generated assets**

Run:

```bash
git add Pyxis/Assets.xcassets Pyxis/BattleScene.swift Pyxis/CountryMapScene.swift
git commit -m "Add bright kingdom siege assets"
```

---

### Task 5: Redesign CountryMapScene As Illustrated Region Map

**Files:**
- Modify: `Pyxis/CountryMapScene.swift`
- Modify: `PyxisTests/CountryMapSceneTests.swift`

- [ ] **Step 1: Add failing tests for map layout and city state styling**

Append these tests to `CountryMapSceneTests` before helper methods:

```swift
    @Test func illustratedMapLayoutKeepsTitleFeedbackAndAllCitiesVisible() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let scene = makeScene(store: store, router: RouteSpy())
        let frames = try #require(scene.mapLayoutFramesForTesting)

        #expect(frames.title.minY > frames.cityBounds.maxY)
        #expect(frames.feedback.maxY < frames.cityBounds.minY)
        #expect(frames.cityBounds.minX >= 0)
        #expect(frames.cityBounds.maxX <= scene.size.width)
        #expect(frames.cityBounds.minY >= 0)
        #expect(frames.cityBounds.maxY <= scene.size.height)
    }

    @Test func cityStateStylingDistinguishesCompletedUnlockedAndLocked() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let scene = makeScene(store: store, router: RouteSpy())

        #expect(scene.cityVisualStateForTesting(1) == .completed)
        #expect(scene.cityVisualStateForTesting(2) == .unlocked)
        #expect(scene.cityVisualStateForTesting(3) == .locked)
        #expect(scene.isUnlockedCityPulseRunningForTesting(2))
        #expect(!scene.isUnlockedCityPulseRunningForTesting(3))
    }
```

- [ ] **Step 2: Run CountryMapScene tests to verify they fail**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests/CountryMapSceneTests
```

Expected: fail because `mapLayoutFramesForTesting`, `cityVisualStateForTesting(_:)`, and `isUnlockedCityPulseRunningForTesting(_:)` do not exist.

- [ ] **Step 3: Add illustrated map nodes and state enum**

In `CountryMapScene`, add to `NodeName`:

```swift
        static let mapBackdrop = "countryMapBackdrop"
        static let unlockedPulse = "countryMapUnlockedPulse"
        static let conqueredMarkerPrefix = "countryMapConqueredMarker-"
```

Add private nodes:

```swift
    private let mapBackdropLayer = SKNode()
    private let titlePanel = PanelNode(size: CGSize(width: 180, height: 44))
    private let feedbackPanel = PanelNode(size: CGSize(width: 220, height: 44))
    private var mapBackdropNode: SKSpriteNode?
```

In `buildInterface()`, add `mapBackdropLayer` before route/city layers:

```swift
        mapBackdropLayer.zPosition = GameUITheme.Z.background
        routeLayer.zPosition = 0
        cityLayer.zPosition = 10
        addChild(mapBackdropLayer)
        addChild(routeLayer)
        addChild(cityLayer)
        titlePanel.zPosition = GameUITheme.Z.hud
        feedbackPanel.zPosition = GameUITheme.Z.hud
        addChild(titlePanel)
        addChild(feedbackPanel)
```

Create the optional backdrop:

```swift
        if UIImage(named: NodeName.mapBackdrop) != nil {
            let backdrop = SKSpriteNode(imageNamed: NodeName.mapBackdrop)
            backdrop.name = NodeName.mapBackdrop
            backdrop.zPosition = GameUITheme.Z.background
            mapBackdropLayer.addChild(backdrop)
            mapBackdropNode = backdrop
        }
```

Because the image set is named `country-map-backdrop`, use this correction immediately after adding `NodeName`:

```swift
        static let mapBackdrop = "country-map-backdrop"
```

- [ ] **Step 4: Replace city positions with illustrated route positions**

Replace `cityPositions(contentWidth:mapBottom:mapHeight:)` with normalized region coordinates:

```swift
    private func cityPositions(contentWidth: CGFloat, mapBottom: CGFloat, mapHeight: CGFloat) -> [Int: CGPoint] {
        let centerX = size.width / 2
        let mapWidth = contentWidth
        let normalized: [(CGFloat, CGFloat)] = [
            (0.18, 0.03),
            (0.36, 0.12),
            (0.27, 0.22),
            (0.52, 0.30),
            (0.70, 0.40),
            (0.48, 0.49),
            (0.28, 0.58),
            (0.43, 0.66),
            (0.62, 0.73),
            (0.78, 0.80),
            (0.58, 0.87),
            (0.38, 0.78),
            (0.22, 0.70),
            (0.32, 0.88),
            (0.52, 0.96)
        ]

        var positions: [Int: CGPoint] = [:]
        for cityNumber in 1...KingdomGameState.firstCountryCityCount {
            let point = normalized[cityNumber - 1]
            positions[cityNumber] = CGPoint(
                x: centerX - mapWidth / 2 + mapWidth * point.0,
                y: mapBottom + mapHeight * point.1
            )
        }
        return positions
    }
```

Update `layoutInterface()` so:

```swift
        let isCompactHeight = size.height < 500
        let horizontalMargin: CGFloat = isCompactHeight ? 24 : 28
        let titleHeight: CGFloat = isCompactHeight ? 36 : 46
        let feedbackHeight: CGFloat = isCompactHeight ? 34 : 44
        let topMargin: CGFloat = isCompactHeight ? 24 : 48
        let bottomMargin: CGFloat = isCompactHeight ? 20 : 34
        let contentWidth = max(260, min(size.width - horizontalMargin * 2, 560))

        titlePanel.update(size: CGSize(width: min(contentWidth, 260), height: titleHeight))
        feedbackPanel.update(size: CGSize(width: min(contentWidth, 320), height: feedbackHeight))
        titlePanel.position = CGPoint(x: size.width / 2, y: size.height - topMargin)
        feedbackPanel.position = CGPoint(x: size.width / 2, y: bottomMargin)
        titleLabel.position = titlePanel.position
        feedbackLabel.position = feedbackPanel.position

        let mapTop = titlePanel.position.y - titleHeight / 2 - 22
        let mapBottom = feedbackPanel.position.y + feedbackHeight / 2 + 22
        let mapHeight = max(80, mapTop - mapBottom)
```

Scale `mapBackdropNode` to cover the map band:

```swift
        if let mapBackdropNode {
            mapBackdropNode.position = CGPoint(x: size.width / 2, y: mapBottom + mapHeight / 2)
            let targetSize = CGSize(width: size.width, height: mapHeight + 72)
            let scale = max(
                targetSize.width / max(1, mapBackdropNode.size.width),
                targetSize.height / max(1, mapBackdropNode.size.height)
            )
            mapBackdropNode.setScale(scale)
        }
```

- [ ] **Step 5: Implement completed, unlocked, and locked styling**

Add a DEBUG-visible enum outside the class:

```swift
enum CountryMapCityVisualState: Equatable {
    case completed
    case unlocked
    case locked
}
```

Add private helper:

```swift
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
```

In `redraw()`, update styling:

```swift
            switch visualState(for: cityNumber) {
            case .completed:
                cityNodes[cityNumber]?.fillColor = GameUITheme.Color.gold
                cityNodes[cityNumber]?.strokeColor = .white
                cityLabels[cityNumber]?.fontColor = SKColor(red: 0.16, green: 0.12, blue: 0.05, alpha: 1.0)
                cityNodes[cityNumber]?.removeAction(forKey: NodeName.unlockedPulse)
            case .unlocked:
                cityNodes[cityNumber]?.fillColor = SKColor(red: 0.18, green: 0.70, blue: 0.44, alpha: 1.0)
                cityNodes[cityNumber]?.strokeColor = SKColor(red: 0.78, green: 1.0, blue: 0.76, alpha: 1.0)
                cityLabels[cityNumber]?.fontColor = .white
                startUnlockedPulseIfNeeded(cityNumber: cityNumber)
            case .locked:
                cityNodes[cityNumber]?.fillColor = GameUITheme.Color.locked
                cityNodes[cityNumber]?.strokeColor = SKColor(white: 1.0, alpha: 0.22)
                cityLabels[cityNumber]?.fontColor = SKColor(white: 1.0, alpha: 0.55)
                cityNodes[cityNumber]?.removeAction(forKey: NodeName.unlockedPulse)
            }
```

Add:

```swift
    private func startUnlockedPulseIfNeeded(cityNumber: Int) {
        guard cityNodes[cityNumber]?.action(forKey: NodeName.unlockedPulse) == nil else {
            return
        }

        let grow = SKAction.scale(to: 1.12, duration: 0.65)
        grow.timingMode = .easeInEaseOut
        let shrink = SKAction.scale(to: 1.0, duration: 0.65)
        shrink.timingMode = .easeInEaseOut
        cityNodes[cityNumber]?.run(SKAction.repeatForever(SKAction.sequence([grow, shrink])), withKey: NodeName.unlockedPulse)
    }
```

- [ ] **Step 6: Add map DEBUG hooks**

In the DEBUG extension for `CountryMapScene`, add:

```swift
    struct CountryMapLayoutFrames {
        let title: CGRect
        let feedback: CGRect
        let cityBounds: CGRect
    }

    var mapLayoutFramesForTesting: CountryMapLayoutFrames? {
        guard
            let titleFrame = sceneFrame(for: titlePanel),
            let feedbackFrame = sceneFrame(for: feedbackPanel)
        else {
            return nil
        }

        let frames = cityNodes.values.map { $0.calculateAccumulatedFrame() }
        guard let firstFrame = frames.first else {
            return nil
        }
        let cityBounds = frames.dropFirst().reduce(firstFrame) { $0.union($1) }
        return CountryMapLayoutFrames(title: titleFrame, feedback: feedbackFrame, cityBounds: cityBounds)
    }

    func cityVisualStateForTesting(_ cityNumber: Int) -> CountryMapCityVisualState {
        visualState(for: cityNumber)
    }

    func isUnlockedCityPulseRunningForTesting(_ cityNumber: Int) -> Bool {
        cityNodes[cityNumber]?.action(forKey: NodeName.unlockedPulse) != nil
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
```

- [ ] **Step 7: Run CountryMapScene tests to verify they pass**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests/CountryMapSceneTests
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 8: Commit illustrated region map redesign**

Run:

```bash
git add Pyxis/CountryMapScene.swift PyxisTests/CountryMapSceneTests.swift
git commit -m "Redesign country map presentation"
```

---

### Task 6: Full Verification And Visual Smoke

**Files:**
- Modify only if verification reveals a bug in files touched by Tasks 1-5.

- [ ] **Step 1: Run focused scene tests**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests/BattleSceneTests -only-testing:PyxisTests/CountryMapSceneTests -only-testing:PyxisTests/GameUIComponentsTests
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 2: Run the full unit and UI suite**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test
```

Expected: `** TEST SUCCEEDED **`.

If `iPhone 17` is unavailable, run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -showdestinations
```

Then rerun the full suite with an available iOS Simulator destination. Do not switch to `iPhone 16` unless `-showdestinations` confirms it exists locally.

- [ ] **Step 3: Build generic simulator for asset catalog sanity**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'generic/platform=iOS Simulator' build
```

Expected: build succeeds with no asset catalog or compile errors.

- [ ] **Step 4: Manual simulator smoke**

Launch the app through Xcode or `xcodebuild`-driven simulator tooling and verify:

- first launch still opens battle when the saved stage is active
- top HUD clusters are readable and do not overlap
- spawn creates visible soldiers
- tower shots and soldier deaths are visible
- city damage creates floating damage feedback
- upgrade success and insufficient-gold feedback are distinguishable
- conquest shows reward presentation and routes to the map
- Country 1 map shows all 15 cities
- completed, unlocked, and locked cities are visually distinct
- tapping unlocked city starts battle
- tapping locked or completed city keeps state unchanged and updates feedback

- [ ] **Step 5: Commit final verification fixes only if needed**

If fixes were required during verification, run:

```bash
git add Pyxis PyxisTests
git commit -m "Polish gaming UI redesign verification"
```

If no fixes were required, do not create an empty commit.
