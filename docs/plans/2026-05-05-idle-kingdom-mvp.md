# Idle Kingdom MVP Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build the first playable idle kingdom loop where spawned soldiers automatically damage a city, conquest grants gold, gold upgrades soldier attack power, and background time converts into automatic attacks.

**Architecture:** Keep game rules in a SpriteKit-free `KingdomGameState` model with focused unit tests. Add a small `KingdomGameStore` for `UserDefaults` persistence. Replace the starter `GameScene` behavior with SpriteKit labels, buttons, an HP bar, and lifecycle-driven idle catch-up.

**Tech Stack:** Swift 5, SpriteKit, UIKit scene lifecycle, Swift Testing, `UserDefaults`, Xcode project file-system-synchronized groups.

---

## Current Project Notes

- Spec: `docs/superpowers/specs/2026-05-05-idle-kingdom-mvp-design.md`
- App target source folder: `Pyxis/`
- Unit test folder: `PyxisTests/`
- Existing project uses `PBXFileSystemSynchronizedRootGroup`, so new files placed under `Pyxis/` and `PyxisTests/` should be included by folder sync.
- Main scene currently loads from `GameScene.sks`; the implementation will switch to constructing `GameScene(size:)` in `GameViewController` so the scene is fully code-owned.
- `xcodebuild -list -project Pyxis.xcodeproj` succeeds but may print CoreSimulator sandbox warnings in this environment.

## Verification Commands

Use these during implementation:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test
```

If that destination is not available, first run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -showdestinations
```

Then rerun tests with one listed iOS Simulator destination.

---

### Task 1: Add Formula Tests

**Files:**
- Create: `PyxisTests/KingdomGameStateTests.swift`
- Create later in this task: `Pyxis/KingdomGameState.swift`

**Step 1: Write the failing formula tests**

Create `PyxisTests/KingdomGameStateTests.swift`:

```swift
//
//  KingdomGameStateTests.swift
//  PyxisTests
//

import Testing
@testable import Pyxis

struct KingdomGameStateTests {
    @Test func formulasMatchMVPBalanceCurve() {
        #expect(KingdomGameState.cityMaxPower(for: 1) == 20)
        #expect(KingdomGameState.cityMaxPower(for: 2) == 43)
        #expect(KingdomGameState.cityMaxPower(for: 3) == 92)
        #expect(KingdomGameState.cityMaxPower(for: 10) == 19633)

        #expect(KingdomGameState.goldReward(for: 1) == 8)
        #expect(KingdomGameState.goldReward(for: 2) == 12)

        #expect(KingdomGameState.normalSoldierAttackPower(for: 1) == 1)
        #expect(KingdomGameState.normalSoldierAttackPower(for: 2) == 2)
        #expect(KingdomGameState.normalSoldierAttackPower(for: 4) == 3)

        #expect(KingdomGameState.normalSoldierUpgradeCost(for: 1) == 10)
        #expect(KingdomGameState.normalSoldierUpgradeCost(for: 2) == 17)
    }

    @Test func formulasClampInvalidLevelsToOne() {
        #expect(KingdomGameState.cityMaxPower(for: 0) == 20)
        #expect(KingdomGameState.goldReward(for: 0) == 8)
        #expect(KingdomGameState.normalSoldierAttackPower(for: 0) == 1)
        #expect(KingdomGameState.normalSoldierUpgradeCost(for: 0) == 10)
    }
}
```

**Step 2: Run tests to verify they fail**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test
```

Expected: FAIL because `KingdomGameState` does not exist.

**Step 3: Add the minimal model and formulas**

Create `Pyxis/KingdomGameState.swift`:

```swift
//
//  KingdomGameState.swift
//  Pyxis
//

import Foundation

struct KingdomGameState: Codable, Equatable {
    static let maxIdleCatchUpSeconds = 8 * 60 * 60

    var gold: Int
    var cityLevel: Int
    var cityRemainingPower: Int
    var normalSoldierUpgradeLevel: Int
    var lastBackgroundedAt: Date?

    init(
        gold: Int = 0,
        cityLevel: Int = 1,
        cityRemainingPower: Int? = nil,
        normalSoldierUpgradeLevel: Int = 1,
        lastBackgroundedAt: Date? = nil
    ) {
        self.gold = max(0, gold)
        self.cityLevel = max(1, cityLevel)
        self.cityRemainingPower = max(1, cityRemainingPower ?? Self.cityMaxPower(for: max(1, cityLevel)))
        self.normalSoldierUpgradeLevel = max(1, normalSoldierUpgradeLevel)
        self.lastBackgroundedAt = lastBackgroundedAt
    }

    var cityMaxPower: Int {
        Self.cityMaxPower(for: cityLevel)
    }

    var currentGoldReward: Int {
        Self.goldReward(for: cityLevel)
    }

    var normalSoldierAttackPower: Int {
        Self.normalSoldierAttackPower(for: normalSoldierUpgradeLevel)
    }

    var normalSoldierUpgradeCost: Int {
        Self.normalSoldierUpgradeCost(for: normalSoldierUpgradeLevel)
    }

    static func cityMaxPower(for level: Int) -> Int {
        roundedAtLeastOne(20 * pow(2.15, Double(clampedLevel(level) - 1)))
    }

    static func goldReward(for level: Int) -> Int {
        roundedAtLeastOne(8 * pow(1.45, Double(clampedLevel(level) - 1)))
    }

    static func normalSoldierAttackPower(for upgradeLevel: Int) -> Int {
        max(1, Int(ceil(pow(1.38, Double(clampedLevel(upgradeLevel) - 1)))))
    }

    static func normalSoldierUpgradeCost(for upgradeLevel: Int) -> Int {
        roundedAtLeastOne(10 * pow(1.7, Double(clampedLevel(upgradeLevel) - 1)))
    }

    private static func clampedLevel(_ level: Int) -> Int {
        max(1, level)
    }

    private static func roundedAtLeastOne(_ value: Double) -> Int {
        max(1, Int(value.rounded()))
    }
}
```

**Step 4: Run tests to verify they pass**

Run the same `xcodebuild ... test` command.

Expected: PASS for formula tests.

**Step 5: Commit**

```bash
git add Pyxis/KingdomGameState.swift PyxisTests/KingdomGameStateTests.swift
git commit -m "Add idle kingdom balance formulas"
```

---

### Task 2: Add Spawn Attack And Conquest Logic

**Files:**
- Modify: `Pyxis/KingdomGameState.swift`
- Modify: `PyxisTests/KingdomGameStateTests.swift`

**Step 1: Write failing spawn and conquest tests**

Append these tests inside `KingdomGameStateTests`:

```swift
@Test func spawningSoldierDamagesCurrentCity() {
    var state = KingdomGameState(cityRemainingPower: 20)

    let result = state.spawnSoldierAttack()

    #expect(result.damageDealt == 1)
    #expect(result.conqueredCities == 0)
    #expect(result.goldEarned == 0)
    #expect(state.cityRemainingPower == 19)
    #expect(state.cityLevel == 1)
    #expect(state.gold == 0)
}

@Test func spawnConquersCityAndGrantsGold() {
    var state = KingdomGameState(cityRemainingPower: 1)

    let result = state.spawnSoldierAttack()

    #expect(result.damageDealt == 1)
    #expect(result.conqueredCities == 1)
    #expect(result.goldEarned == 8)
    #expect(state.gold == 8)
    #expect(state.cityLevel == 2)
    #expect(state.cityRemainingPower == KingdomGameState.cityMaxPower(for: 2))
}

@Test func foregroundSpawnDoesNotCarryOverExcessDamage() {
    var state = KingdomGameState(cityRemainingPower: 1, normalSoldierUpgradeLevel: 4)

    let result = state.spawnSoldierAttack()

    #expect(result.damageDealt == 3)
    #expect(result.conqueredCities == 1)
    #expect(state.cityLevel == 2)
    #expect(state.cityRemainingPower == KingdomGameState.cityMaxPower(for: 2))
}
```

**Step 2: Run tests to verify they fail**

Expected: FAIL because `spawnSoldierAttack()` and `AttackResult` do not exist.

**Step 3: Implement attack and conquest**

Add this nested result type and method to `KingdomGameState`:

```swift
struct AttackResult: Equatable {
    let damageDealt: Int
    let conqueredCities: Int
    let goldEarned: Int
}

@discardableResult
mutating func spawnSoldierAttack() -> AttackResult {
    let damage = normalSoldierAttackPower
    cityRemainingPower -= damage

    guard cityRemainingPower <= 0 else {
        return AttackResult(damageDealt: damage, conqueredCities: 0, goldEarned: 0)
    }

    let reward = currentGoldReward
    gold += reward
    cityLevel += 1
    cityRemainingPower = cityMaxPower

    return AttackResult(damageDealt: damage, conqueredCities: 1, goldEarned: reward)
}
```

**Step 4: Run tests to verify they pass**

Run the same `xcodebuild ... test` command.

Expected: PASS.

**Step 5: Commit**

```bash
git add Pyxis/KingdomGameState.swift PyxisTests/KingdomGameStateTests.swift
git commit -m "Add soldier attack conquest loop"
```

---

### Task 3: Add Soldier Upgrade Logic

**Files:**
- Modify: `Pyxis/KingdomGameState.swift`
- Modify: `PyxisTests/KingdomGameStateTests.swift`

**Step 1: Write failing upgrade tests**

Append:

```swift
@Test func successfulUpgradeSpendsGoldAndRaisesAttackPower() {
    var state = KingdomGameState(gold: 30)

    let result = state.upgradeNormalSoldier()

    #expect(result == .upgraded(cost: 10, newAttackPower: 2))
    #expect(state.gold == 20)
    #expect(state.normalSoldierUpgradeLevel == 2)
    #expect(state.normalSoldierAttackPower == 2)
}

@Test func failedUpgradeDoesNotMutateState() {
    let original = KingdomGameState(gold: 9)
    var state = original

    let result = state.upgradeNormalSoldier()

    #expect(result == .insufficientGold(cost: 10, currentGold: 9))
    #expect(state == original)
}
```

**Step 2: Run tests to verify they fail**

Expected: FAIL because `upgradeNormalSoldier()` and `UpgradeResult` do not exist.

**Step 3: Implement upgrade logic**

Add to `KingdomGameState`:

```swift
enum UpgradeResult: Equatable {
    case upgraded(cost: Int, newAttackPower: Int)
    case insufficientGold(cost: Int, currentGold: Int)
}

@discardableResult
mutating func upgradeNormalSoldier() -> UpgradeResult {
    let cost = normalSoldierUpgradeCost

    guard gold >= cost else {
        return .insufficientGold(cost: cost, currentGold: gold)
    }

    gold -= cost
    normalSoldierUpgradeLevel += 1

    return .upgraded(cost: cost, newAttackPower: normalSoldierAttackPower)
}
```

**Step 4: Run tests to verify they pass**

Expected: PASS.

**Step 5: Commit**

```bash
git add Pyxis/KingdomGameState.swift PyxisTests/KingdomGameStateTests.swift
git commit -m "Add soldier attack upgrades"
```

---

### Task 4: Add Background Idle Progress

**Files:**
- Modify: `Pyxis/KingdomGameState.swift`
- Modify: `PyxisTests/KingdomGameStateTests.swift`

**Step 1: Write failing idle tests**

Append:

```swift
@Test func idleCatchUpAppliesAutomaticDamageAndClearsTimestamp() {
    let start = Date(timeIntervalSinceReferenceDate: 1_000)
    let end = start.addingTimeInterval(5)
    var state = KingdomGameState(cityRemainingPower: 20)

    state.enterBackground(at: start)
    let result = state.returnFromBackground(at: end)

    #expect(result.elapsedSeconds == 5)
    #expect(result.damageDealt == 5)
    #expect(result.conqueredCities == 0)
    #expect(result.goldEarned == 0)
    #expect(state.cityRemainingPower == 15)
    #expect(state.lastBackgroundedAt == nil)
}

@Test func idleCatchUpCanConquerMultipleCitiesWithCarryOverDamage() {
    let start = Date(timeIntervalSinceReferenceDate: 2_000)
    let end = start.addingTimeInterval(80)
    var state = KingdomGameState(cityRemainingPower: 10)

    state.enterBackground(at: start)
    let result = state.returnFromBackground(at: end)

    #expect(result.elapsedSeconds == 80)
    #expect(result.damageDealt == 80)
    #expect(result.conqueredCities == 2)
    #expect(result.goldEarned == 20)
    #expect(state.cityLevel == 3)
    #expect(state.cityRemainingPower == 65)
}

@Test func idleCatchUpCannotBeAppliedTwice() {
    let start = Date(timeIntervalSinceReferenceDate: 3_000)
    let end = start.addingTimeInterval(5)
    var state = KingdomGameState(cityRemainingPower: 20)

    state.enterBackground(at: start)
    _ = state.returnFromBackground(at: end)
    let secondResult = state.returnFromBackground(at: end.addingTimeInterval(5))

    #expect(secondResult.elapsedSeconds == 0)
    #expect(secondResult.damageDealt == 0)
    #expect(state.cityRemainingPower == 15)
}

@Test func idleCatchUpIsCappedAtEightHours() {
    let start = Date(timeIntervalSinceReferenceDate: 4_000)
    let end = start.addingTimeInterval(Double(KingdomGameState.maxIdleCatchUpSeconds + 120))
    var state = KingdomGameState(cityRemainingPower: 30_000)

    state.enterBackground(at: start)
    let result = state.returnFromBackground(at: end)

    #expect(result.elapsedSeconds == KingdomGameState.maxIdleCatchUpSeconds)
    #expect(result.damageDealt == KingdomGameState.maxIdleCatchUpSeconds)
}
```

**Step 2: Run tests to verify they fail**

Expected: FAIL because idle methods and result type do not exist.

**Step 3: Implement idle progress**

Add to `KingdomGameState`:

```swift
struct IdleProgressResult: Equatable {
    let elapsedSeconds: Int
    let damageDealt: Int
    let conqueredCities: Int
    let goldEarned: Int

    static let none = IdleProgressResult(
        elapsedSeconds: 0,
        damageDealt: 0,
        conqueredCities: 0,
        goldEarned: 0
    )
}

mutating func enterBackground(at date: Date) {
    lastBackgroundedAt = date
}

@discardableResult
mutating func returnFromBackground(at date: Date) -> IdleProgressResult {
    guard let lastBackgroundedAt else {
        return .none
    }

    self.lastBackgroundedAt = nil

    let rawElapsed = Int(date.timeIntervalSince(lastBackgroundedAt))
    let elapsedSeconds = min(max(0, rawElapsed), Self.maxIdleCatchUpSeconds)

    guard elapsedSeconds > 0 else {
        return .none
    }

    let totalDamage = elapsedSeconds * normalSoldierAttackPower
    var remainingDamage = totalDamage
    var conqueredCities = 0
    var goldEarned = 0

    while remainingDamage > 0 {
        if remainingDamage < cityRemainingPower {
            cityRemainingPower -= remainingDamage
            remainingDamage = 0
        } else {
            remainingDamage -= cityRemainingPower
            let reward = currentGoldReward
            gold += reward
            goldEarned += reward
            conqueredCities += 1
            cityLevel += 1
            cityRemainingPower = cityMaxPower
        }
    }

    return IdleProgressResult(
        elapsedSeconds: elapsedSeconds,
        damageDealt: totalDamage,
        conqueredCities: conqueredCities,
        goldEarned: goldEarned
    )
}
```

**Step 4: Run tests to verify they pass**

Expected: PASS.

**Step 5: Commit**

```bash
git add Pyxis/KingdomGameState.swift PyxisTests/KingdomGameStateTests.swift
git commit -m "Add background idle progress"
```

---

### Task 5: Add UserDefaults Persistence

**Files:**
- Create: `Pyxis/KingdomGameStore.swift`
- Create: `PyxisTests/KingdomGameStoreTests.swift`

**Step 1: Write failing store tests**

Create `PyxisTests/KingdomGameStoreTests.swift`:

```swift
//
//  KingdomGameStoreTests.swift
//  PyxisTests
//

import Foundation
import Testing
@testable import Pyxis

struct KingdomGameStoreTests {
    @Test func loadReturnsFreshStateWhenNoSaveExists() throws {
        let defaults = try makeDefaults()
        let store = KingdomGameStore(defaults: defaults, key: "state")

        let state = store.load()

        #expect(state == KingdomGameState())
    }

    @Test func saveAndLoadRoundTripsMutableState() throws {
        let defaults = try makeDefaults()
        let store = KingdomGameStore(defaults: defaults, key: "state")
        let backgroundDate = Date(timeIntervalSinceReferenceDate: 10_000)
        let saved = KingdomGameState(
            gold: 42,
            cityLevel: 4,
            cityRemainingPower: 123,
            normalSoldierUpgradeLevel: 3,
            lastBackgroundedAt: backgroundDate
        )

        store.save(saved)
        let loaded = store.load()

        #expect(loaded == saved)
        #expect(loaded.cityMaxPower == KingdomGameState.cityMaxPower(for: 4))
        #expect(loaded.normalSoldierAttackPower == KingdomGameState.normalSoldierAttackPower(for: 3))
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "PyxisTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
```

**Step 2: Run tests to verify they fail**

Expected: FAIL because `KingdomGameStore` does not exist.

**Step 3: Implement the store**

Create `Pyxis/KingdomGameStore.swift`:

```swift
//
//  KingdomGameStore.swift
//  Pyxis
//

import Foundation

final class KingdomGameStore {
    static let shared = KingdomGameStore()

    private let defaults: UserDefaults
    private let key: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard, key: String = "pyxis.kingdomGameState") {
        self.defaults = defaults
        self.key = key
    }

    func load() -> KingdomGameState {
        guard let data = defaults.data(forKey: key) else {
            return KingdomGameState()
        }

        do {
            return try decoder.decode(KingdomGameState.self, from: data)
        } catch {
            return KingdomGameState()
        }
    }

    func save(_ state: KingdomGameState) {
        guard let data = try? encoder.encode(state) else {
            return
        }

        defaults.set(data, forKey: key)
    }
}
```

**Step 4: Run tests to verify they pass**

Expected: PASS.

**Step 5: Commit**

```bash
git add Pyxis/KingdomGameStore.swift PyxisTests/KingdomGameStoreTests.swift
git commit -m "Persist idle kingdom state"
```

---

### Task 6: Replace Starter Scene With Idle Kingdom UI

**Files:**
- Modify: `Pyxis/GameScene.swift`
- Modify: `Pyxis/GameViewController.swift`

**Step 1: Prepare scene construction**

Modify `Pyxis/GameViewController.swift` to instantiate `GameScene` directly:

```swift
override func viewDidLoad() {
    super.viewDidLoad()

    if let view = self.view as? SKView {
        let scene = GameScene(size: view.bounds.size)
        scene.scaleMode = .resizeFill
        view.presentScene(scene)

        view.ignoresSiblingOrder = true
        view.showsFPS = true
        view.showsNodeCount = true
    }
}
```

**Step 2: Replace starter scene code**

Replace `Pyxis/GameScene.swift` with a code-owned scene. Use this structure:

```swift
import SpriteKit

final class GameScene: SKScene {
    private enum NodeName {
        static let spawnButton = "spawnButton"
        static let upgradeButton = "upgradeButton"
    }

    private var state: KingdomGameState
    private let store: KingdomGameStore

    private let goldLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let cityLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let attackLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let hpLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let feedbackLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let hpBarBackground = SKShapeNode()
    private let hpBarFill = SKShapeNode()
    private let spawnButton = SKShapeNode()
    private let spawnButtonLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let upgradeButton = SKShapeNode()
    private let upgradeButtonLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")

    init(
        size: CGSize,
        state: KingdomGameState = KingdomGameStore.shared.load(),
        store: KingdomGameStore = .shared
    ) {
        self.state = state
        self.store = store
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        self.state = KingdomGameStore.shared.load()
        self.store = .shared
        super.init(coder: aDecoder)
    }

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.08, green: 0.10, blue: 0.13, alpha: 1)
        buildInterface()
        layoutInterface()
        redraw()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        layoutInterface()
        redraw()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self),
              let button = buttonName(at: point) else {
            return
        }

        switch button {
        case NodeName.spawnButton:
            handleSpawn()
        case NodeName.upgradeButton:
            handleUpgrade()
        default:
            break
        }
    }

    private func buildInterface() {
        [goldLabel, cityLabel, attackLabel, hpLabel, feedbackLabel, spawnButtonLabel, upgradeButtonLabel].forEach {
            $0.verticalAlignmentMode = .center
            $0.horizontalAlignmentMode = .center
            $0.fontColor = .white
            addChild($0)
        }

        hpBarBackground.fillColor = SKColor(white: 1, alpha: 0.18)
        hpBarBackground.strokeColor = .clear
        hpBarFill.fillColor = SKColor(red: 0.82, green: 0.18, blue: 0.15, alpha: 1)
        hpBarFill.strokeColor = .clear
        addChild(hpBarBackground)
        addChild(hpBarFill)

        configureButton(spawnButton, label: spawnButtonLabel, name: NodeName.spawnButton)
        configureButton(upgradeButton, label: upgradeButtonLabel, name: NodeName.upgradeButton)
    }

    private func configureButton(_ node: SKShapeNode, label: SKLabelNode, name: String) {
        node.name = name
        node.fillColor = SKColor(red: 0.18, green: 0.38, blue: 0.72, alpha: 1)
        node.strokeColor = SKColor(white: 1, alpha: 0.22)
        node.lineWidth = 2
        label.name = name
        addChild(node)
    }

    private func layoutInterface() {
        let centerX = size.width / 2
        let topY = size.height - 70
        let buttonWidth = min(size.width - 48, 360)
        let buttonHeight: CGFloat = 58

        goldLabel.position = CGPoint(x: centerX, y: topY)
        cityLabel.position = CGPoint(x: centerX, y: topY - 38)
        attackLabel.position = CGPoint(x: centerX, y: topY - 76)

        hpLabel.position = CGPoint(x: centerX, y: size.height * 0.55)
        let hpBarSize = CGSize(width: min(size.width - 48, 420), height: 24)
        hpBarBackground.path = CGPath(roundedRect: CGRect(origin: .zero, size: hpBarSize), cornerWidth: 8, cornerHeight: 8, transform: nil)
        hpBarBackground.position = CGPoint(x: centerX - hpBarSize.width / 2, y: hpLabel.position.y - 48)

        feedbackLabel.position = CGPoint(x: centerX, y: hpBarBackground.position.y - 54)

        spawnButton.path = CGPath(roundedRect: CGRect(x: -buttonWidth / 2, y: -buttonHeight / 2, width: buttonWidth, height: buttonHeight), cornerWidth: 10, cornerHeight: 10, transform: nil)
        spawnButton.position = CGPoint(x: centerX, y: 150)
        spawnButtonLabel.position = spawnButton.position

        upgradeButton.path = spawnButton.path
        upgradeButton.position = CGPoint(x: centerX, y: 78)
        upgradeButtonLabel.position = upgradeButton.position
    }

    private func redraw() {
        goldLabel.text = "Gold: \(state.gold)"
        cityLabel.text = "City Level \(state.cityLevel)"
        attackLabel.text = "Soldier Attack: \(state.normalSoldierAttackPower)"
        hpLabel.text = "City HP: \(state.cityRemainingPower) / \(state.cityMaxPower)"
        spawnButtonLabel.text = "Spawn Soldier"
        upgradeButtonLabel.text = "Upgrade Soldier (\(state.normalSoldierUpgradeCost) gold)"

        let maxWidth = min(size.width - 48, 420)
        let ratio = max(0, min(1, CGFloat(state.cityRemainingPower) / CGFloat(state.cityMaxPower)))
        let fillSize = CGSize(width: maxWidth * ratio, height: 24)
        hpBarFill.path = CGPath(roundedRect: CGRect(origin: .zero, size: fillSize), cornerWidth: 8, cornerHeight: 8, transform: nil)
        hpBarFill.position = hpBarBackground.position
    }

    private func handleSpawn() {
        let result = state.spawnSoldierAttack()
        if result.conqueredCities > 0 {
            feedbackLabel.text = "Conquered city! +\(result.goldEarned) gold"
        } else {
            feedbackLabel.text = "Soldier dealt \(result.damageDealt) damage"
        }
        store.save(state)
        redraw()
    }

    private func handleUpgrade() {
        switch state.upgradeNormalSoldier() {
        case .upgraded(let cost, let newAttackPower):
            feedbackLabel.text = "Upgraded for \(cost) gold. Attack \(newAttackPower)"
        case .insufficientGold(let cost, let currentGold):
            feedbackLabel.text = "Need \(cost - currentGold) more gold"
        }
        store.save(state)
        redraw()
    }

    private func buttonName(at point: CGPoint) -> String? {
        for node in nodes(at: point) {
            var current: SKNode? = node
            while let candidate = current {
                if candidate.name == NodeName.spawnButton || candidate.name == NodeName.upgradeButton {
                    return candidate.name
                }
                current = candidate.parent
            }
        }
        return nil
    }
}
```

**Step 3: Build**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: BUILD SUCCEEDED.

**Step 4: Commit**

```bash
git add Pyxis/GameScene.swift Pyxis/GameViewController.swift
git commit -m "Build idle kingdom SpriteKit scene"
```

---

### Task 7: Wire Lifecycle Idle Catch-Up

**Files:**
- Create: `Pyxis/GameLifecycleNotifications.swift`
- Modify: `Pyxis/SceneDelegate.swift`
- Modify: `Pyxis/GameScene.swift`

**Step 1: Add notification names**

Create `Pyxis/GameLifecycleNotifications.swift`:

```swift
//
//  GameLifecycleNotifications.swift
//  Pyxis
//

import Foundation

extension Notification.Name {
    static let pyxisSceneDidEnterBackground = Notification.Name("pyxisSceneDidEnterBackground")
    static let pyxisSceneWillEnterForeground = Notification.Name("pyxisSceneWillEnterForeground")
}
```

**Step 2: Post notifications from scene lifecycle**

In `Pyxis/SceneDelegate.swift`, update:

```swift
func sceneWillEnterForeground(_ scene: UIScene) {
    NotificationCenter.default.post(name: .pyxisSceneWillEnterForeground, object: nil)
}

func sceneDidEnterBackground(_ scene: UIScene) {
    NotificationCenter.default.post(name: .pyxisSceneDidEnterBackground, object: nil)
}
```

**Step 3: Observe notifications in `GameScene`**

Add to `didMove(to:)` after interface setup:

```swift
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleDidEnterBackground),
    name: .pyxisSceneDidEnterBackground,
    object: nil
)
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleWillEnterForeground),
    name: .pyxisSceneWillEnterForeground,
    object: nil
)
```

Add:

```swift
deinit {
    NotificationCenter.default.removeObserver(self)
}

@objc private func handleDidEnterBackground() {
    state.enterBackground(at: Date())
    store.save(state)
}

@objc private func handleWillEnterForeground() {
    let result = state.returnFromBackground(at: Date())
    store.save(state)
    redraw()

    guard result.elapsedSeconds > 0 else {
        return
    }

    feedbackLabel.text = "Idle attacks dealt \(result.damageDealt) damage and conquered \(result.conqueredCities) cities"
}
```

If `didMove(to:)` can be called more than once during testing, add a `private var isObservingLifecycle = false` guard so observers are registered once.

**Step 4: Run tests and build**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test
```

Expected: TEST SUCCEEDED.

**Step 5: Commit**

```bash
git add Pyxis/GameLifecycleNotifications.swift Pyxis/SceneDelegate.swift Pyxis/GameScene.swift
git commit -m "Apply idle progress from app lifecycle"
```

---

### Task 8: Add Focused UI Smoke Coverage

**Files:**
- Modify: `PyxisUITests/PyxisUITests.swift`

**Step 1: Keep the existing launch smoke test simple**

Replace the empty `testExample()` body with a launch assertion:

```swift
@MainActor
func testLaunchesGameScene() throws {
    let app = XCUIApplication()
    app.launch()

    XCTAssertEqual(app.state, .runningForeground)
}
```

Do not add fragile SpriteKit node text assertions unless accessibility exposure is added intentionally. SpriteKit labels are not reliable XCUI elements by default.

**Step 2: Run full tests**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test
```

Expected: TEST SUCCEEDED.

**Step 3: Commit**

```bash
git add PyxisUITests/PyxisUITests.swift
git commit -m "Add idle kingdom launch smoke test"
```

---

### Task 9: Final Verification And Cleanup

**Files:**
- Review all touched files.

**Step 1: Check worktree**

Run:

```bash
git status --short
```

Expected: clean, unless there are intentional uncommitted changes.

**Step 2: Run final tests**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test
```

Expected: TEST SUCCEEDED.

**Step 3: Inspect recent commits**

Run:

```bash
git log --oneline -6
```

Expected: commits for formulas, attack loop, upgrades, idle progress, persistence, SpriteKit scene, lifecycle, and UI smoke coverage.

**Step 4: Manual simulator smoke check**

Launch the app from Xcode or with the same simulator destination. Verify:

- screen shows gold, city level, attack power, city HP, spawn button, and upgrade button
- tapping `Spawn Soldier` reduces city HP
- city conquest grants gold and advances city level
- tapping `Upgrade Soldier` without enough gold shows missing gold feedback
- after enough gold, upgrade increases soldier attack
- backgrounding and foregrounding applies idle progress once

**Step 5: Report**

Final implementation report should include:

- files changed
- test command and result
- any simulator or sandbox limitations
- current branch/commit status
