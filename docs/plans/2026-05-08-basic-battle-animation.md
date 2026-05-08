# Basic Battle Animation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the immediate text-only spawn action with visible chibi anime battle animation where soldiers walk from the player castle to the enemy city and apply damage on impact.

**Architecture:** Keep `KingdomGameState` as the SpriteKit-free source of combat truth. `GameScene` owns generated art nodes, soldier animation timing, pending soldiers, impact callbacks, persistence, and redraws. Generated art lives in `Pyxis/Assets.xcassets`; do not edit `project.pbxproj` because this project uses file-system-synchronized groups.

**Tech Stack:** Swift 5, SpriteKit, UIKit asset catalog images, Swift Testing, Xcode `xcodebuild`.

---

## Task 1: Add Generated Chibi Battle Art Assets

**Files:**
- Create: `Pyxis/Assets.xcassets/player-castle.imageset/Contents.json`
- Create: `Pyxis/Assets.xcassets/player-castle.imageset/player-castle.png`
- Create: `Pyxis/Assets.xcassets/enemy-city.imageset/Contents.json`
- Create: `Pyxis/Assets.xcassets/enemy-city.imageset/enemy-city.png`
- Create: `Pyxis/Assets.xcassets/normal-soldier.imageset/Contents.json`
- Create: `Pyxis/Assets.xcassets/normal-soldier.imageset/normal-soldier.png`

**Step 1: Generate the player castle image**

Use the image generation tool with this prompt:

```text
Transparent PNG game sprite, chibi anime fantasy style, friendly player kingdom castle, bright heroic colors, readable silhouette for mobile idle game, three-quarter side view facing right, clean edges, no text, no background, no shadow outside the transparent sprite.
```

Save the result as:

```text
Pyxis/Assets.xcassets/player-castle.imageset/player-castle.png
```

**Step 2: Generate the enemy city image**

Use the image generation tool with this prompt:

```text
Transparent PNG game sprite, chibi anime fantasy style, enemy fortified city castle, slightly ominous but colorful, readable silhouette for mobile idle game, three-quarter side view facing left, clean edges, no text, no background, no shadow outside the transparent sprite.
```

Save the result as:

```text
Pyxis/Assets.xcassets/enemy-city.imageset/enemy-city.png
```

**Step 3: Generate the normal soldier image**

Use the image generation tool with this prompt:

```text
Transparent PNG game sprite, chibi anime fantasy normal soldier, small armored infantry with sword and shield, friendly kingdom colors, side view facing right, readable at tiny mobile size, clean edges, no text, no background, no shadow outside the transparent sprite.
```

Save the result as:

```text
Pyxis/Assets.xcassets/normal-soldier.imageset/normal-soldier.png
```

**Step 4: Add asset catalog metadata**

Create each `Contents.json` with this structure, changing the `filename` for each image set:

```json
{
  "images": [
    {
      "filename": "player-castle.png",
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

Use `enemy-city.png` and `normal-soldier.png` in their matching image sets.

**Step 5: Verify files exist**

Run:

```bash
find Pyxis/Assets.xcassets -maxdepth 2 -type f | sort
```

Expected: the three PNG files and three new `Contents.json` files appear under their image set directories.

**Step 6: Commit**

```bash
git add Pyxis/Assets.xcassets/player-castle.imageset Pyxis/Assets.xcassets/enemy-city.imageset Pyxis/Assets.xcassets/normal-soldier.imageset
git commit -m "Add battle animation sprite assets"
```

---

## Task 2: Add Failing Scene Tests For Delayed Impact

**Files:**
- Create: `PyxisTests/GameSceneAnimationTests.swift`
- Modify later: `Pyxis/GameScene.swift`

**Step 1: Write the failing tests**

Create `PyxisTests/GameSceneAnimationTests.swift`:

```swift
//
//  GameSceneAnimationTests.swift
//  PyxisTests
//

import Foundation
import SpriteKit
import Testing
@testable import Pyxis

@MainActor
struct GameSceneAnimationTests {
    @Test func spawnWaitsForSoldierImpactBeforeDamagingCity() throws {
        let store = try makeStore(initialState: KingdomGameState(cityRemainingPower: 20))
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()

        #expect(scene.pendingSoldierAttackCountForTesting == 1)
        #expect(store.load().cityRemainingPower == 20)

        scene.completeFirstPendingSoldierAttackForTesting()

        #expect(scene.pendingSoldierAttackCountForTesting == 0)
        #expect(store.load().cityRemainingPower == 19)
    }

    @Test func repeatedSpawnsCreateMultiplePendingSoldiers() throws {
        let store = try makeStore(initialState: KingdomGameState(cityRemainingPower: 20))
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()
        scene.spawnSoldierForTesting()
        scene.spawnSoldierForTesting()

        #expect(scene.pendingSoldierAttackCountForTesting == 3)
        #expect(store.load().cityRemainingPower == 20)

        scene.completeFirstPendingSoldierAttackForTesting()
        scene.completeFirstPendingSoldierAttackForTesting()

        #expect(scene.pendingSoldierAttackCountForTesting == 1)
        #expect(store.load().cityRemainingPower == 18)
    }

    @Test func soldierImpactCanConquerCityAndSaveReward() throws {
        let store = try makeStore(initialState: KingdomGameState(cityRemainingPower: 1))
        let scene = makeScene(store: store)

        scene.spawnSoldierForTesting()
        scene.completeFirstPendingSoldierAttackForTesting()

        let savedState = store.load()
        #expect(savedState.gold == 8)
        #expect(savedState.cityLevel == 2)
        #expect(savedState.cityRemainingPower == KingdomGameState.cityMaxPower(for: 2))
    }

    private func makeScene(store: KingdomGameStore) -> GameScene {
        let size = CGSize(width: 390, height: 844)
        let scene = GameScene(size: size, store: store)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        scene.didMove(to: view)
        return scene
    }

    private func makeStore(initialState: KingdomGameState) throws -> KingdomGameStore {
        let suiteName = "PyxisTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let store = KingdomGameStore(defaults: defaults, key: "state")
        store.save(initialState)
        return store
    }
}
```

**Step 2: Run the focused tests to verify they fail**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:PyxisTests/GameSceneAnimationTests
```

Expected: FAIL at compile time because `GameScene` does not have `spawnSoldierForTesting`, `pendingSoldierAttackCountForTesting`, or `completeFirstPendingSoldierAttackForTesting`.

If `iPhone 16` is not available, run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -showdestinations
```

Then rerun the focused test command with an available simulator destination.

**Step 3: Commit the failing tests**

```bash
git add PyxisTests/GameSceneAnimationTests.swift
git commit -m "Add delayed soldier impact scene tests"
```

---

## Task 3: Implement Pending Soldiers And Impact-Only Damage

**Files:**
- Modify: `Pyxis/GameScene.swift`
- Test: `PyxisTests/GameSceneAnimationTests.swift`

**Step 1: Add animation configuration and pending soldier tracking**

Near the top of `GameScene`, after `ButtonName`, add:

```swift
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
```

Add these properties to `GameScene`:

```swift
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
```

**Step 2: Route spawn taps to animation instead of immediate damage**

Replace the current `spawnSoldier()` body with:

```swift
private func spawnSoldier() {
    let soldier = makeSoldierNode()
    soldier.position = castleGatePoint
    soldier.zPosition = 20 + CGFloat(pendingSoldiers.count)
    soldierLayer.addChild(soldier)
    pendingSoldiers.append(soldier)
    runSoldierAttackAnimation(for: soldier)
}
```

**Step 3: Add soldier animation and impact resolution**

Add these methods before `upgradeSoldier()`:

```swift
private func runSoldierAttackAnimation(for soldier: SKNode) {
    let bob = SKAction.sequence([
        SKAction.scale(to: 1.08, duration: 0.18),
        SKAction.scale(to: 1.0, duration: 0.18)
    ]).repeatedForever()
    soldier.run(bob, withKey: "soldierBob")

    let walk = SKAction.move(to: enemyGatePoint, duration: animationConfiguration.walkDuration)
    walk.timingMode = .easeInEaseOut

    let stopBob = SKAction.run { [weak soldier] in
        soldier?.removeAction(forKey: "soldierBob")
    }
    let lunge = SKAction.sequence([
        SKAction.moveBy(x: 10, y: 0, duration: animationConfiguration.attackDuration / 2),
        SKAction.moveBy(x: -10, y: 0, duration: animationConfiguration.attackDuration / 2)
    ])
    let impact = SKAction.run { [weak self, weak soldier] in
        guard let self, let soldier else {
            return
        }

        self.completeSoldierAttack(soldier)
    }

    soldier.run(SKAction.sequence([
        walk,
        stopBob,
        lunge,
        impact
    ]))
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
```

The `playCityHitFeedback()` and `playCityConquestFeedback()` methods can be simple stubs in this task if visual nodes are not ready yet:

```swift
private func playCityHitFeedback() {}

private func playCityConquestFeedback() {}
```

**Step 4: Add temporary fallback soldier node**

Add:

```swift
private func makeSoldierNode() -> SKNode {
    let body = SKShapeNode(circleOfRadius: 10)
    body.fillColor = SKColor(red: 0.24, green: 0.54, blue: 0.95, alpha: 1.0)
    body.strokeColor = SKColor(white: 1.0, alpha: 0.45)
    body.lineWidth = 2
    return body
}
```

Task 4 will replace this with asset-backed sprite creation and fallback behavior.

**Step 5: Add test-only accessors**

At the bottom of `GameScene.swift`, after the class closing brace, add:

```swift
#if DEBUG
extension GameScene {
    var pendingSoldierAttackCountForTesting: Int {
        pendingSoldiers.count
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
#endif
```

If the test target cannot see the extension under `#if DEBUG`, remove the conditional and keep the accessors internal. Do not make production state public.

**Step 6: Ensure layers are added**

In `buildInterface()`, add these nodes before the labels/buttons:

```swift
addChild(battlefieldLayer)
battlefieldLayer.addChild(environmentLayer)
battlefieldLayer.addChild(soldierLayer)
battlefieldLayer.addChild(effectsLayer)
```

Set baseline z positions:

```swift
battlefieldLayer.zPosition = 0
environmentLayer.zPosition = 0
soldierLayer.zPosition = 10
effectsLayer.zPosition = 30
```

Set existing labels/buttons to higher z positions if needed:

```swift
goldLabel.zPosition = 100
cityLevelLabel.zPosition = 100
soldierAttackLabel.zPosition = 100
cityHPLabel.zPosition = 100
hpBarBackground.zPosition = 100
hpBarFill.zPosition = 101
feedbackLabel.zPosition = 100
spawnButton.zPosition = 100
upgradeButton.zPosition = 100
```

**Step 7: Run focused tests**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:PyxisTests/GameSceneAnimationTests
```

Expected: PASS.

**Step 8: Commit**

```bash
git add Pyxis/GameScene.swift PyxisTests/GameSceneAnimationTests.swift
git commit -m "Delay soldier damage until impact"
```

---

## Task 4: Add Battlefield Layout And Asset-Backed Nodes

**Files:**
- Modify: `Pyxis/GameScene.swift`
- Test: `PyxisTests/GameSceneAnimationTests.swift`

**Step 1: Build static battlefield nodes**

In `buildInterface()`, after layer setup and before adding labels/buttons, add:

```swift
buildBattlefield()
```

Add:

```swift
private func buildBattlefield() {
    let castle = makeBattleSprite(named: BattleAssetName.playerCastle, fallbackColor: SKColor(red: 0.22, green: 0.48, blue: 0.83, alpha: 1.0))
    let city = makeBattleSprite(named: BattleAssetName.enemyCity, fallbackColor: SKColor(red: 0.62, green: 0.24, blue: 0.28, alpha: 1.0))

    castle.name = BattleAssetName.playerCastle
    city.name = BattleAssetName.enemyCity

    playerCastleNode = castle
    enemyCityNode = city

    environmentLayer.addChild(castle)
    environmentLayer.addChild(city)
}
```

**Step 2: Add asset loading with fallback**

Add `import UIKit` to `GameScene.swift`.

Add:

```swift
private func makeBattleSprite(named assetName: String, fallbackColor: SKColor) -> SKNode {
    if UIImage(named: assetName) != nil {
        let sprite = SKSpriteNode(imageNamed: assetName)
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        return sprite
    }

    let fallback = SKShapeNode(rect: CGRect(x: -48, y: 0, width: 96, height: 92), cornerRadius: 8)
    fallback.fillColor = fallbackColor
    fallback.strokeColor = SKColor(white: 1.0, alpha: 0.28)
    fallback.lineWidth = 2
    return fallback
}

private func makeSoldierNode() -> SKNode {
    if UIImage(named: BattleAssetName.normalSoldier) != nil {
        let sprite = SKSpriteNode(imageNamed: BattleAssetName.normalSoldier)
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        return sprite
    }

    let body = SKShapeNode(circleOfRadius: 10)
    body.fillColor = SKColor(red: 0.24, green: 0.54, blue: 0.95, alpha: 1.0)
    body.strokeColor = SKColor(white: 1.0, alpha: 0.45)
    body.lineWidth = 2
    return body
}
```

Replace the temporary `makeSoldierNode()` from Task 3 with this version.

**Step 3: Add responsive battlefield layout**

In `layoutInterface()`, after button positions and before fitting labels, call:

```swift
layoutBattlefield(
    contentWidth: contentWidth,
    hpBarBottomY: hpBarBackground.position.y - hpBarSize.height / 2,
    spawnButtonTopY: spawnButtonTopY
)
```

Add:

```swift
private func layoutBattlefield(contentWidth: CGFloat, hpBarBottomY: CGFloat, spawnButtonTopY: CGFloat) {
    let horizontalPadding = max(24, (size.width - contentWidth) / 2)
    let battleTopY = hpBarBottomY - 26
    let battleBottomY = spawnButtonTopY + 52
    let availableHeight = max(110, battleTopY - battleBottomY)
    let groundY = battleBottomY + availableHeight * 0.26
    let castleX = horizontalPadding + contentWidth * 0.16
    let cityX = size.width - horizontalPadding - contentWidth * 0.16
    let structureHeight = min(availableHeight * 0.72, contentWidth * 0.32)
    let soldierHeight = max(28, min(42, structureHeight * 0.36))

    if let playerCastleNode {
        playerCastleNode.position = CGPoint(x: castleX, y: groundY)
        fitBattleNode(playerCastleNode, targetHeight: structureHeight)
    }

    if let enemyCityNode {
        enemyCityNode.position = CGPoint(x: cityX, y: groundY)
        fitBattleNode(enemyCityNode, targetHeight: structureHeight)
    }

    castleGatePoint = CGPoint(x: castleX + structureHeight * 0.24, y: groundY + soldierHeight * 0.08)
    enemyGatePoint = CGPoint(x: cityX - structureHeight * 0.24, y: groundY + soldierHeight * 0.08)

    for soldier in pendingSoldiers {
        fitBattleNode(soldier, targetHeight: soldierHeight)
    }

    battlefieldLayer.position = .zero
    drawGroundLane(from: CGPoint(x: horizontalPadding, y: groundY), to: CGPoint(x: size.width - horizontalPadding, y: groundY))
}

private func fitBattleNode(_ node: SKNode, targetHeight: CGFloat) {
    guard targetHeight > 0 else {
        return
    }

    if let sprite = node as? SKSpriteNode {
        let textureHeight = max(sprite.texture?.size().height ?? sprite.size.height, 1)
        sprite.setScale(targetHeight / textureHeight)
    } else if let shape = node as? SKShapeNode {
        let currentHeight = max(shape.frame.height, 1)
        shape.setScale(targetHeight / currentHeight)
    }
}

private func drawGroundLane(from start: CGPoint, to end: CGPoint) {
    environmentLayer.childNode(withName: "battleGroundLane")?.removeFromParent()

    let lane = SKShapeNode(rectOf: CGSize(width: max(1, end.x - start.x), height: 18), cornerRadius: 9)
    lane.name = "battleGroundLane"
    lane.position = CGPoint(x: (start.x + end.x) / 2, y: start.y + 2)
    lane.fillColor = SKColor(red: 0.30, green: 0.24, blue: 0.17, alpha: 1.0)
    lane.strokeColor = SKColor(white: 1.0, alpha: 0.12)
    lane.lineWidth = 1
    lane.zPosition = -1
    environmentLayer.addChild(lane)
}
```

**Step 4: Size new soldiers when they spawn**

In `spawnSoldier()`, after `let soldier = makeSoldierNode()`, add:

```swift
fitBattleNode(soldier, targetHeight: max(28, min(42, size.height * 0.05)))
```

**Step 5: Run focused tests**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:PyxisTests/GameSceneAnimationTests
```

Expected: PASS.

**Step 6: Commit**

```bash
git add Pyxis/GameScene.swift
git commit -m "Render animated battle scene assets"
```

---

## Task 5: Add Hit And Conquest Feedback Effects

**Files:**
- Modify: `Pyxis/GameScene.swift`
- Test: `PyxisTests/GameSceneAnimationTests.swift`

**Step 1: Implement city hit feedback**

Replace the stub:

```swift
private func playCityHitFeedback() {
    guard let enemyCityNode else {
        return
    }

    enemyCityNode.removeAction(forKey: "cityHitFeedback")
    let flash = SKAction.sequence([
        SKAction.colorize(with: .white, colorBlendFactor: 0.45, duration: 0.06),
        SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.12)
    ])

    if let sprite = enemyCityNode as? SKSpriteNode {
        sprite.run(flash, withKey: "cityHitFeedback")
    } else {
        enemyCityNode.run(SKAction.sequence([
            SKAction.moveBy(x: -4, y: 0, duration: 0.04),
            SKAction.moveBy(x: 8, y: 0, duration: 0.08),
            SKAction.moveBy(x: -4, y: 0, duration: 0.04)
        ]), withKey: "cityHitFeedback")
    }

    playImpactFlash()
}
```

If `SKAction.colorize` is not available for the inferred node type, keep the shake action for all node types:

```swift
enemyCityNode.run(SKAction.sequence([
    SKAction.moveBy(x: -4, y: 0, duration: 0.04),
    SKAction.moveBy(x: 8, y: 0, duration: 0.08),
    SKAction.moveBy(x: -4, y: 0, duration: 0.04)
]), withKey: "cityHitFeedback")
```

**Step 2: Implement conquest feedback**

Replace the stub:

```swift
private func playCityConquestFeedback() {
    guard let enemyCityNode else {
        return
    }

    let originalXScale = enemyCityNode.xScale
    let originalYScale = enemyCityNode.yScale
    enemyCityNode.removeAction(forKey: "cityConquestFeedback")
    enemyCityNode.run(SKAction.sequence([
        SKAction.scaleX(to: originalXScale * 1.08, y: originalYScale * 1.08, duration: 0.08),
        SKAction.scaleX(to: originalXScale, y: originalYScale, duration: 0.14)
    ]), withKey: "cityConquestFeedback")

    playImpactFlash()
}
```

**Step 3: Add impact flash**

Add:

```swift
private func playImpactFlash() {
    let flash = SKShapeNode(circleOfRadius: 12)
    flash.fillColor = SKColor(red: 1.0, green: 0.88, blue: 0.30, alpha: 0.85)
    flash.strokeColor = .clear
    flash.position = enemyGatePoint
    flash.zPosition = 40
    effectsLayer.addChild(flash)

    flash.run(SKAction.sequence([
        SKAction.group([
            SKAction.scale(to: 2.2, duration: 0.18),
            SKAction.fadeOut(withDuration: 0.18)
        ]),
        SKAction.removeFromParent()
    ]))
}
```

**Step 4: Run focused tests**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:PyxisTests/GameSceneAnimationTests
```

Expected: PASS.

**Step 5: Commit**

```bash
git add Pyxis/GameScene.swift
git commit -m "Add battle hit feedback effects"
```

---

## Task 6: Final Verification And Cleanup

**Files:**
- Review: `Pyxis/GameScene.swift`
- Review: `PyxisTests/GameSceneAnimationTests.swift`
- Review: `Pyxis/Assets.xcassets/*`

**Step 1: Run all unit and UI tests**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test
```

Expected: PASS for unit and UI tests.

If the simulator destination is unavailable, run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -showdestinations
```

Then rerun the full test suite with an available simulator.

**Step 2: Build only if full tests are blocked by UI simulator issues**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: BUILD SUCCEEDED.

**Step 3: Manual simulator smoke check**

Run the app in the simulator from Xcode or with the available simulator workflow and check:

- player castle renders on the left
- enemy city renders on the right
- spawn and upgrade buttons remain visible
- tapping `Spawn Soldier` creates a soldier at the castle
- HP does not change immediately on tap
- HP changes when the soldier reaches the city
- repeated taps show multiple soldiers in flight
- conquest still grants gold and advances the city level

**Step 4: Inspect git status**

Run:

```bash
git status --short
```

Expected: only intentional files changed.

**Step 5: Final commit if anything remains uncommitted**

```bash
git add Pyxis/GameScene.swift PyxisTests/GameSceneAnimationTests.swift Pyxis/Assets.xcassets/player-castle.imageset Pyxis/Assets.xcassets/enemy-city.imageset Pyxis/Assets.xcassets/normal-soldier.imageset
git commit -m "Implement basic battle animation"
```

Skip this commit if all previous task commits already captured the complete implementation.
