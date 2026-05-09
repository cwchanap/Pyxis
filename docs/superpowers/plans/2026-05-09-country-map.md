# Country Map Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a two-scene Country 1 progression layer with 15 linear city stages, conquest popups, explicit map entry for the next city, and idle progress that stops at the current city conquest.

**Architecture:** Keep campaign and combat rules in `KingdomGameState`, persist through `KingdomGameStore`, and split SpriteKit presentation into `BattleScene` and `CountryMapScene`. `GameViewController` routes between scenes through small scene routing protocols.

**Tech Stack:** Swift 5, SpriteKit, UIKit, Swift Testing, XCTest UI smoke tests, `xcodebuild`.

---

## File Structure

- Modify `Pyxis/KingdomGameState.swift`: add campaign fields, stage gate, map status helpers, explicit city entry, conquest pause, and idle stop-at-current-city behavior.
- Modify `Pyxis/KingdomGameStore.swift`: keep the same store API; no new storage layer is needed.
- Rename `Pyxis/GameScene.swift` to `Pyxis/BattleScene.swift`: keep existing battle rendering and animation, then add conquest popup and routing.
- Create `Pyxis/CountryMapScene.swift`: render Country 1 nodes and route only the unlocked city into battle.
- Modify `Pyxis/GameViewController.swift`: present `BattleScene` or `CountryMapScene` based on persisted state and route callbacks.
- Modify `PyxisTests/KingdomGameStateTests.swift`: update existing model assertions for pause-on-conquest and idle stop behavior.
- Modify `PyxisTests/KingdomGameStoreTests.swift`: include campaign fields in the round-trip test.
- Rename `PyxisTests/GameSceneAnimationTests.swift` to `PyxisTests/BattleSceneTests.swift`: preserve impact-timing tests and add popup routing coverage.
- Create `PyxisTests/CountryMapSceneTests.swift`: verify unlocked/locked map entry intent.

## Commands

Use this primary verification command:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test
```

If the simulator destination is unavailable, list destinations and rerun with an available iPhone simulator:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -showdestinations
```

---

### Task 1: Campaign Model State

**Files:**
- Modify: `Pyxis/KingdomGameState.swift`
- Modify: `PyxisTests/KingdomGameStateTests.swift`

- [ ] **Step 1: Write failing tests for campaign defaults and foreground conquest pause**

Add these tests to `PyxisTests/KingdomGameStateTests.swift`:

```swift
@Test func firstLaunchStartsBattleReadyAtCountryOneCityOne() {
    let state = KingdomGameState()

    #expect(state.countryNumber == 1)
    #expect(state.cityNumberInCountry == 1)
    #expect(state.completedCityCount == 0)
    #expect(state.cityLevel == 1)
    #expect(state.stageStatus == .battleActive)
    #expect(state.displayCityTitle == "Country 1 - City 1")
    #expect(state.mapStatus(for: 1) == .unlocked)
    #expect(state.mapStatus(for: 2) == .locked)
}

@Test func foregroundConquestMarksCurrentCityConqueredAndPausesCombat() {
    var state = KingdomGameState(cityRemainingPower: 1)

    let result = state.spawnSoldierAttack()

    #expect(result.attackApplied)
    #expect(result.damageDealt == 1)
    #expect(result.conqueredCities == 1)
    #expect(result.goldEarned == 8)
    #expect(state.gold == 8)
    #expect(state.cityLevel == 1)
    #expect(state.cityRemainingPower == 0)
    #expect(state.completedCityCount == 1)
    #expect(state.stageStatus == .cityConqueredPendingMap)
    #expect(state.mapStatus(for: 1) == .completed)
    #expect(state.mapStatus(for: 2) == .unlocked)
}

@Test func combatActionIsRejectedAfterCityIsConquered() {
    var state = KingdomGameState(cityRemainingPower: 1)

    _ = state.spawnSoldierAttack()
    let blockedResult = state.spawnSoldierAttack()

    #expect(!blockedResult.attackApplied)
    #expect(blockedResult.damageDealt == 0)
    #expect(blockedResult.conqueredCities == 0)
    #expect(blockedResult.goldEarned == 0)
    #expect(state.gold == 8)
    #expect(state.completedCityCount == 1)
    #expect(state.cityRemainingPower == 0)
}
```

- [ ] **Step 2: Run the targeted tests and verify they fail**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:PyxisTests/KingdomGameStateTests
```

Expected: FAIL with compile errors for `countryNumber`, `completedCityCount`, `stageStatus`, `displayCityTitle`, `mapStatus(for:)`, and `attackApplied`.

- [ ] **Step 3: Add campaign types and persisted fields**

In `Pyxis/KingdomGameState.swift`, add these nested types inside `struct KingdomGameState`:

```swift
static let firstCountryCityCount = 15

enum StageStatus: String, Codable, Equatable {
    case battleActive
    case cityConqueredPendingMap
    case countryComplete
}

enum MapCityStatus: Equatable {
    case completed
    case unlocked
    case locked
}

enum CityEntryResult: Equatable {
    case entered(country: Int, city: Int)
    case locked
    case alreadyCompleted
    case countryComplete
}
```

Replace `AttackResult` with:

```swift
struct AttackResult: Equatable {
    let attackApplied: Bool
    let damageDealt: Int
    let conqueredCities: Int
    let goldEarned: Int

    static let blocked = AttackResult(
        attackApplied: false,
        damageDealt: 0,
        conqueredCities: 0,
        goldEarned: 0
    )
}
```

Add these stored properties:

```swift
var countryNumber: Int
var cityNumberInCountry: Int
var completedCityCount: Int
var stageStatus: StageStatus
```

Replace `CodingKeys` with:

```swift
private enum CodingKeys: String, CodingKey {
    case gold
    case cityLevel
    case cityRemainingPower
    case normalSoldierUpgradeLevel
    case lastBackgroundedAt
    case countryNumber
    case cityNumberInCountry
    case completedCityCount
    case stageStatus
}
```

Replace the memberwise initializer with:

```swift
init(
    gold: Int = 0,
    cityLevel: Int = 1,
    cityRemainingPower: Int? = nil,
    normalSoldierUpgradeLevel: Int = 1,
    lastBackgroundedAt: Date? = nil,
    countryNumber: Int = 1,
    cityNumberInCountry: Int = 1,
    completedCityCount: Int = 0,
    stageStatus: StageStatus = .battleActive
) {
    let clampedCountryNumber = max(1, countryNumber)
    let clampedCompletedCityCount = min(max(0, completedCityCount), Self.firstCountryCityCount)
    let clampedCityNumber = min(max(1, cityNumberInCountry), Self.firstCountryCityCount)
    let clampedCityLevel = max(1, cityLevel)
    let resolvedStatus: StageStatus

    if clampedCompletedCityCount >= Self.firstCountryCityCount || stageStatus == .countryComplete {
        resolvedStatus = .countryComplete
    } else if stageStatus == .cityConqueredPendingMap {
        resolvedStatus = .cityConqueredPendingMap
    } else {
        resolvedStatus = .battleActive
    }

    self.gold = max(0, gold)
    self.cityLevel = clampedCityLevel
    self.normalSoldierUpgradeLevel = max(1, normalSoldierUpgradeLevel)
    self.lastBackgroundedAt = lastBackgroundedAt
    self.countryNumber = clampedCountryNumber
    self.cityNumberInCountry = clampedCityNumber
    self.completedCityCount = clampedCompletedCityCount
    self.stageStatus = resolvedStatus

    if resolvedStatus == .battleActive {
        self.cityRemainingPower = max(1, cityRemainingPower ?? Self.cityMaxPower(for: clampedCityLevel))
    } else {
        self.cityRemainingPower = max(0, cityRemainingPower ?? 0)
    }
}
```

Replace `init(from:)` with:

```swift
init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    self.init(
        gold: try container.decodeIfPresent(Int.self, forKey: .gold) ?? 0,
        cityLevel: try container.decodeIfPresent(Int.self, forKey: .cityLevel) ?? 1,
        cityRemainingPower: try container.decodeIfPresent(Int.self, forKey: .cityRemainingPower),
        normalSoldierUpgradeLevel: try container.decodeIfPresent(Int.self, forKey: .normalSoldierUpgradeLevel) ?? 1,
        lastBackgroundedAt: try container.decodeIfPresent(Date.self, forKey: .lastBackgroundedAt),
        countryNumber: try container.decodeIfPresent(Int.self, forKey: .countryNumber) ?? 1,
        cityNumberInCountry: try container.decodeIfPresent(Int.self, forKey: .cityNumberInCountry)
            ?? min(max(1, try container.decodeIfPresent(Int.self, forKey: .cityLevel) ?? 1), Self.firstCountryCityCount),
        completedCityCount: try container.decodeIfPresent(Int.self, forKey: .completedCityCount)
            ?? min(max(0, (try container.decodeIfPresent(Int.self, forKey: .cityLevel) ?? 1) - 1), Self.firstCountryCityCount),
        stageStatus: try container.decodeIfPresent(StageStatus.self, forKey: .stageStatus) ?? .battleActive
    )
}
```

- [ ] **Step 4: Add campaign helper methods**

Add these computed properties and methods after the existing formula computed properties:

```swift
var displayCityTitle: String {
    "Country \(countryNumber) - City \(cityNumberInCountry)"
}

var hasNextCityInCountry: Bool {
    completedCityCount < Self.firstCountryCityCount
}

func mapStatus(for cityNumber: Int) -> MapCityStatus {
    guard (1...Self.firstCountryCityCount).contains(cityNumber) else {
        return .locked
    }

    if cityNumber <= completedCityCount {
        return .completed
    }

    if stageStatus != .countryComplete && cityNumber == completedCityCount + 1 {
        return .unlocked
    }

    return .locked
}

@discardableResult
mutating func startCityFromMap(_ cityNumber: Int) -> CityEntryResult {
    guard stageStatus != .countryComplete else {
        return .countryComplete
    }

    guard (1...Self.firstCountryCityCount).contains(cityNumber) else {
        return .locked
    }

    if cityNumber <= completedCityCount {
        return .alreadyCompleted
    }

    guard cityNumber == completedCityCount + 1 else {
        return .locked
    }

    cityNumberInCountry = cityNumber
    cityLevel = completedCityCount + 1
    cityRemainingPower = cityMaxPower
    stageStatus = .battleActive
    lastBackgroundedAt = nil

    return .entered(country: countryNumber, city: cityNumberInCountry)
}
```

- [ ] **Step 5: Change foreground conquest to pause instead of advancing immediately**

Replace `spawnSoldierAttack()` with:

```swift
@discardableResult
mutating func spawnSoldierAttack() -> AttackResult {
    guard stageStatus == .battleActive else {
        return .blocked
    }

    let damage = normalSoldierAttackPower
    cityRemainingPower -= damage

    guard cityRemainingPower <= 0 else {
        return AttackResult(attackApplied: true, damageDealt: damage, conqueredCities: 0, goldEarned: 0)
    }

    let reward = currentGoldReward
    gold += reward
    cityRemainingPower = 0
    completedCityCount = min(Self.firstCountryCityCount, max(completedCityCount, cityNumberInCountry))

    if completedCityCount >= Self.firstCountryCityCount {
        stageStatus = .countryComplete
    } else {
        stageStatus = .cityConqueredPendingMap
    }

    return AttackResult(attackApplied: true, damageDealt: damage, conqueredCities: 1, goldEarned: reward)
}
```

- [ ] **Step 6: Run the targeted tests and verify they pass**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:PyxisTests/KingdomGameStateTests
```

Expected: the three new tests pass, while older tests that still expect automatic city advancement may fail.

- [ ] **Step 7: Update old model tests for explicit map entry**

Replace `spawnConquersCityAndGrantsGold` with:

```swift
@Test func spawnConquersCityAndGrantsGoldWithoutStartingNextCity() {
    var state = KingdomGameState(cityRemainingPower: 1)

    let result = state.spawnSoldierAttack()

    #expect(result.damageDealt == 1)
    #expect(result.conqueredCities == 1)
    #expect(result.goldEarned == 8)
    #expect(state.gold == 8)
    #expect(state.cityLevel == 1)
    #expect(state.completedCityCount == 1)
    #expect(state.cityRemainingPower == 0)
    #expect(state.stageStatus == .cityConqueredPendingMap)
}
```

Replace `foregroundSpawnDoesNotCarryOverExcessDamage` with:

```swift
@Test func foregroundSpawnDoesNotCarryOverExcessDamageIntoNextCity() {
    var state = KingdomGameState(cityRemainingPower: 1, normalSoldierUpgradeLevel: 4)

    let result = state.spawnSoldierAttack()

    #expect(result.damageDealt == 3)
    #expect(result.conqueredCities == 1)
    #expect(state.cityLevel == 1)
    #expect(state.cityRemainingPower == 0)
    #expect(state.stageStatus == .cityConqueredPendingMap)
}
```

Add these city-entry tests:

```swift
@Test func startingNextUnlockedCityAdvancesAndRestoresFullHP() {
    var state = KingdomGameState(cityRemainingPower: 1)
    _ = state.spawnSoldierAttack()

    let result = state.startCityFromMap(2)

    #expect(result == .entered(country: 1, city: 2))
    #expect(state.cityNumberInCountry == 2)
    #expect(state.cityLevel == 2)
    #expect(state.cityRemainingPower == KingdomGameState.cityMaxPower(for: 2))
    #expect(state.stageStatus == .battleActive)
}

@Test func lockedFutureCityEntryIsRejected() {
    var state = KingdomGameState(cityRemainingPower: 1)
    _ = state.spawnSoldierAttack()

    let result = state.startCityFromMap(3)

    #expect(result == .locked)
    #expect(state.cityNumberInCountry == 1)
    #expect(state.cityLevel == 1)
    #expect(state.stageStatus == .cityConqueredPendingMap)
}

@Test func completedCityEntryIsRejected() {
    var state = KingdomGameState(cityRemainingPower: 1)
    _ = state.spawnSoldierAttack()

    let result = state.startCityFromMap(1)

    #expect(result == .alreadyCompleted)
    #expect(state.stageStatus == .cityConqueredPendingMap)
}

@Test func cityFifteenConquestCompletesCountry() {
    var state = KingdomGameState(
        cityLevel: 15,
        cityRemainingPower: 1,
        countryNumber: 1,
        cityNumberInCountry: 15,
        completedCityCount: 14
    )

    let result = state.spawnSoldierAttack()

    #expect(result.conqueredCities == 1)
    #expect(state.completedCityCount == 15)
    #expect(state.stageStatus == .countryComplete)
    #expect(state.mapStatus(for: 15) == .completed)
    #expect(state.startCityFromMap(15) == .countryComplete)
}
```

- [ ] **Step 8: Run model tests again**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:PyxisTests/KingdomGameStateTests
```

Expected: model tests still fail only for idle catch-up expectations that are updated in Task 2.

- [ ] **Step 9: Commit the model campaign state**

Run:

```bash
git add Pyxis/KingdomGameState.swift PyxisTests/KingdomGameStateTests.swift
git commit -m "Add campaign progression state"
```

Expected: commit succeeds.

---

### Task 2: Idle Resume Stops At Current City

**Files:**
- Modify: `Pyxis/KingdomGameState.swift`
- Modify: `PyxisTests/KingdomGameStateTests.swift`

- [ ] **Step 1: Replace idle carry-over tests with stop-at-current-city tests**

Replace `idleCatchUpCanConquerMultipleCitiesWithCarryOverDamage` with:

```swift
@Test func idleCatchUpConquersOnlyCurrentCityAndStops() {
    let start = Date(timeIntervalSinceReferenceDate: 2_000)
    let end = start.addingTimeInterval(80)
    var state = KingdomGameState(cityRemainingPower: 10)

    state.enterBackground(at: start)
    let result = state.returnFromBackground(at: end)

    #expect(result.elapsedSeconds == 80)
    #expect(result.damageDealt == 10)
    #expect(result.conqueredCities == 1)
    #expect(result.goldEarned == 8)
    #expect(state.gold == 8)
    #expect(state.cityLevel == 1)
    #expect(state.cityRemainingPower == 0)
    #expect(state.completedCityCount == 1)
    #expect(state.stageStatus == .cityConqueredPendingMap)
}
```

Add these idle tests:

```swift
@Test func idleCatchUpDoesNothingWhenBattleIsPausedForMap() {
    let start = Date(timeIntervalSinceReferenceDate: 2_500)
    let end = start.addingTimeInterval(80)
    var state = KingdomGameState(cityRemainingPower: 1)

    _ = state.spawnSoldierAttack()
    state.enterBackground(at: start)
    let result = state.returnFromBackground(at: end)

    #expect(result == .none)
    #expect(state.lastBackgroundedAt == nil)
    #expect(state.gold == 8)
    #expect(state.completedCityCount == 1)
    #expect(state.stageStatus == .cityConqueredPendingMap)
}

@Test func idleConquestRewardIsGrantedOnResume() {
    let start = Date(timeIntervalSinceReferenceDate: 2_700)
    let end = start.addingTimeInterval(20)
    var state = KingdomGameState(cityRemainingPower: 5)

    state.enterBackground(at: start)
    #expect(state.gold == 0)
    #expect(state.cityRemainingPower == 5)

    let result = state.returnFromBackground(at: end)

    #expect(result.goldEarned == 8)
    #expect(state.gold == 8)
    #expect(state.stageStatus == .cityConqueredPendingMap)
}
```

- [ ] **Step 2: Run idle tests and verify failure against old carry-over behavior**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:PyxisTests/KingdomGameStateTests
```

Expected: FAIL for idle expectations until `returnFromBackground(at:)` is changed.

- [ ] **Step 3: Replace `returnFromBackground(at:)`**

In `Pyxis/KingdomGameState.swift`, replace `returnFromBackground(at:)` with:

```swift
@discardableResult
mutating func returnFromBackground(at date: Date) -> IdleProgressResult {
    guard let lastBackgroundedAt else {
        return .none
    }

    self.lastBackgroundedAt = nil

    guard stageStatus == .battleActive else {
        return .none
    }

    let rawElapsed = Int(date.timeIntervalSince(lastBackgroundedAt))
    let elapsedSeconds = min(max(0, rawElapsed), Self.maxIdleCatchUpSeconds)

    guard elapsedSeconds > 0 else {
        return .none
    }

    let totalPotentialDamage = elapsedSeconds * normalSoldierAttackPower
    let appliedDamage = min(totalPotentialDamage, cityRemainingPower)

    guard totalPotentialDamage >= cityRemainingPower else {
        cityRemainingPower -= totalPotentialDamage
        return IdleProgressResult(
            elapsedSeconds: elapsedSeconds,
            damageDealt: totalPotentialDamage,
            conqueredCities: 0,
            goldEarned: 0
        )
    }

    let reward = currentGoldReward
    gold += reward
    cityRemainingPower = 0
    completedCityCount = min(Self.firstCountryCityCount, max(completedCityCount, cityNumberInCountry))

    if completedCityCount >= Self.firstCountryCityCount {
        stageStatus = .countryComplete
    } else {
        stageStatus = .cityConqueredPendingMap
    }

    return IdleProgressResult(
        elapsedSeconds: elapsedSeconds,
        damageDealt: appliedDamage,
        conqueredCities: 1,
        goldEarned: reward
    )
}
```

- [ ] **Step 4: Run model tests and verify pass**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:PyxisTests/KingdomGameStateTests
```

Expected: PASS.

- [ ] **Step 5: Commit idle stop behavior**

Run:

```bash
git add Pyxis/KingdomGameState.swift PyxisTests/KingdomGameStateTests.swift
git commit -m "Stop idle progress at current city"
```

Expected: commit succeeds.

---

### Task 3: Persistence Clamping And Round Trip

**Files:**
- Modify: `PyxisTests/KingdomGameStateTests.swift`
- Modify: `PyxisTests/KingdomGameStoreTests.swift`
- Modify: `Pyxis/KingdomGameState.swift`

- [ ] **Step 1: Update decode clamping test for campaign fields**

Replace `decodingInvalidPersistedStateClampsValues` with:

```swift
@Test func decodingInvalidPersistedStateClampsValues() throws {
    let data = """
    {
      "gold": -25,
      "cityLevel": 0,
      "cityRemainingPower": -9,
      "normalSoldierUpgradeLevel": 0,
      "lastBackgroundedAt": null,
      "countryNumber": 0,
      "cityNumberInCountry": 99,
      "completedCityCount": 99,
      "stageStatus": "battleActive"
    }
    """.data(using: .utf8)!

    let state = try JSONDecoder().decode(KingdomGameState.self, from: data)

    #expect(state.gold == 0)
    #expect(state.cityLevel == 1)
    #expect(state.cityRemainingPower == 0)
    #expect(state.normalSoldierUpgradeLevel == 1)
    #expect(state.lastBackgroundedAt == nil)
    #expect(state.countryNumber == 1)
    #expect(state.cityNumberInCountry == 15)
    #expect(state.completedCityCount == 15)
    #expect(state.stageStatus == .countryComplete)
}

@Test func oldPrototypeSaveInfersCountryProgressionFromCityLevel() throws {
    let data = """
    {
      "gold": 12,
      "cityLevel": 4,
      "cityRemainingPower": 123,
      "normalSoldierUpgradeLevel": 3,
      "lastBackgroundedAt": null
    }
    """.data(using: .utf8)!

    let state = try JSONDecoder().decode(KingdomGameState.self, from: data)

    #expect(state.gold == 12)
    #expect(state.cityLevel == 4)
    #expect(state.cityNumberInCountry == 4)
    #expect(state.completedCityCount == 3)
    #expect(state.stageStatus == .battleActive)
}
```

- [ ] **Step 2: Update store round-trip test**

In `PyxisTests/KingdomGameStoreTests.swift`, replace the `saved` value in `saveAndLoadRoundTripsMutableState` with:

```swift
let saved = KingdomGameState(
    gold: 42,
    cityLevel: 4,
    cityRemainingPower: 123,
    normalSoldierUpgradeLevel: 3,
    lastBackgroundedAt: backgroundDate,
    countryNumber: 1,
    cityNumberInCountry: 4,
    completedCityCount: 3,
    stageStatus: .battleActive
)
```

Add these expectations after `#expect(loaded == saved)`:

```swift
#expect(loaded.countryNumber == 1)
#expect(loaded.cityNumberInCountry == 4)
#expect(loaded.completedCityCount == 3)
#expect(loaded.stageStatus == .battleActive)
```

- [ ] **Step 3: Run persistence tests**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:PyxisTests/KingdomGameStateTests -only-testing:PyxisTests/KingdomGameStoreTests
```

Expected: PASS.

- [ ] **Step 4: Commit persistence updates**

Run:

```bash
git add Pyxis/KingdomGameState.swift PyxisTests/KingdomGameStateTests.swift PyxisTests/KingdomGameStoreTests.swift
git commit -m "Persist country map progression"
```

Expected: commit succeeds.

---

### Task 4: Rename Battle Scene And Add Routing Hooks

**Files:**
- Rename: `Pyxis/GameScene.swift` to `Pyxis/BattleScene.swift`
- Rename: `PyxisTests/GameSceneAnimationTests.swift` to `PyxisTests/BattleSceneTests.swift`
- Modify: `Pyxis/BattleScene.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`

- [ ] **Step 1: Rename files and types**

Run:

```bash
git mv Pyxis/GameScene.swift Pyxis/BattleScene.swift
git mv PyxisTests/GameSceneAnimationTests.swift PyxisTests/BattleSceneTests.swift
```

In `Pyxis/BattleScene.swift`, rename:

```swift
final class GameScene: SKScene {
```

to:

```swift
protocol BattleSceneRouting: AnyObject {
    func battleSceneDidRequestCountryMap(_ scene: BattleScene)
}

final class BattleScene: SKScene {
```

Change both initializers to use `BattleScene` and add a router property:

```swift
private weak var router: BattleSceneRouting?

init(size: CGSize, store: KingdomGameStore = .shared, router: BattleSceneRouting? = nil) {
    self.store = store
    self.state = store.load()
    self.router = router
    super.init(size: size)
}

required init?(coder aDecoder: NSCoder) {
    self.store = .shared
    self.state = KingdomGameStore.shared.load()
    self.router = nil
    super.init(coder: aDecoder)
}
```

In `PyxisTests/BattleSceneTests.swift`, rename the test type and helper:

```swift
@MainActor
struct BattleSceneTests {
```

and:

```swift
private func makeScene(store: KingdomGameStore, router: BattleSceneRouting? = nil) -> BattleScene {
    let size = CGSize(width: 390, height: 844)
    let scene = BattleScene(size: size, store: store, router: router)
    let view = SKView(frame: CGRect(origin: .zero, size: size))
    scene.didMove(to: view)
    return scene
}
```

- [ ] **Step 2: Run renamed scene tests and verify current failures**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:PyxisTests/BattleSceneTests
```

Expected: FAIL until old expectations that assume immediate next-city reset are updated.

- [ ] **Step 3: Update existing scene impact tests**

In `soldierImpactCanConquerCityAndSaveReward`, replace final expectations with:

```swift
let savedState = store.load()
#expect(savedState.gold == 8)
#expect(savedState.cityLevel == 1)
#expect(savedState.completedCityCount == 1)
#expect(savedState.cityRemainingPower == 0)
#expect(savedState.stageStatus == .cityConqueredPendingMap)
```

- [ ] **Step 4: Add route spy and popup-close test**

Add this helper type inside `BattleSceneTests`:

```swift
private final class RouteSpy: BattleSceneRouting {
    private(set) var didRequestCountryMap = false

    func battleSceneDidRequestCountryMap(_ scene: BattleScene) {
        didRequestCountryMap = true
    }
}
```

Add this test:

```swift
@Test func closingConquestPopupRequestsCountryMapRoute() throws {
    let store = try makeStore(initialState: KingdomGameState(cityRemainingPower: 1))
    let router = RouteSpy()
    let scene = makeScene(store: store, router: router)

    scene.spawnSoldierForTesting()
    scene.completeFirstPendingSoldierAttackForTesting()

    #expect(scene.isConquestPopupVisibleForTesting)
    #expect(!router.didRequestCountryMap)

    scene.closeConquestPopupForTesting()

    #expect(!scene.isConquestPopupVisibleForTesting)
    #expect(router.didRequestCountryMap)
}
```

- [ ] **Step 5: Add popup nodes and close action**

In `Pyxis/BattleScene.swift`, add button name and popup properties:

```swift
private enum ButtonName {
    static let spawn = "spawnSoldierButton"
    static let upgrade = "upgradeSoldierButton"
    static let popupContinue = "conquestPopupContinueButton"
}

private let popupOverlay = SKShapeNode()
private let popupTitleLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
private let popupRewardLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
private let popupContinueButton = SKNode()
private let popupContinueBackground = SKShapeNode()
private let popupContinueLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
private var isConquestPopupVisible = false
```

Add these nodes in `buildInterface()` after configuring the existing buttons:

```swift
popupOverlay.fillColor = SKColor(white: 0.02, alpha: 0.86)
popupOverlay.strokeColor = SKColor(white: 1.0, alpha: 0.24)
popupOverlay.lineWidth = 2
popupOverlay.zPosition = 200
popupOverlay.isHidden = true

configureLabel(popupTitleLabel, fontSize: 22, color: .white)
configureLabel(popupRewardLabel, fontSize: 18, color: SKColor(red: 1.0, green: 0.84, blue: 0.25, alpha: 1.0))
configureButton(
    popupContinueButton,
    background: popupContinueBackground,
    label: popupContinueLabel,
    name: ButtonName.popupContinue,
    color: SKColor(red: 0.18, green: 0.58, blue: 0.42, alpha: 1.0)
)

popupTitleLabel.zPosition = 201
popupRewardLabel.zPosition = 201
popupContinueButton.zPosition = 201

addChild(popupOverlay)
addChild(popupTitleLabel)
addChild(popupRewardLabel)
addChild(popupContinueButton)

popupTitleLabel.isHidden = true
popupRewardLabel.isHidden = true
popupContinueButton.isHidden = true
```

In `layoutInterface()`, after button layout, add:

```swift
layoutConquestPopup(contentWidth: contentWidth)
```

Add:

```swift
private func layoutConquestPopup(contentWidth: CGFloat) {
    let popupWidth = min(contentWidth, size.width - 56)
    let popupHeight: CGFloat = 188
    let center = CGPoint(x: size.width / 2, y: size.height / 2)

    popupOverlay.path = CGPath(
        roundedRect: CGRect(x: -popupWidth / 2, y: -popupHeight / 2, width: popupWidth, height: popupHeight),
        cornerWidth: 14,
        cornerHeight: 14,
        transform: nil
    )
    popupOverlay.position = center
    popupTitleLabel.position = CGPoint(x: center.x, y: center.y + 52)
    popupRewardLabel.position = CGPoint(x: center.x, y: center.y + 12)
    layoutButton(
        popupContinueButton,
        background: popupContinueBackground,
        size: CGSize(width: popupWidth - 48, height: 48),
        position: CGPoint(x: center.x, y: center.y - 54)
    )
}

private func showConquestPopup(goldEarned: Int) {
    isConquestPopupVisible = true
    popupTitleLabel.text = state.stageStatus == .countryComplete
        ? "Country \(state.countryNumber) Conquered"
        : "\(state.displayCityTitle) Conquered"
    popupRewardLabel.text = "+\(goldEarned) gold"
    popupContinueLabel.text = "Continue"
    setConquestPopupHidden(false)
    layoutInterface()
}

private func setConquestPopupHidden(_ isHidden: Bool) {
    popupOverlay.isHidden = isHidden
    popupTitleLabel.isHidden = isHidden
    popupRewardLabel.isHidden = isHidden
    popupContinueButton.isHidden = isHidden
}

private func closeConquestPopup() {
    guard isConquestPopupVisible else {
        return
    }

    isConquestPopupVisible = false
    setConquestPopupHidden(true)
    router?.battleSceneDidRequestCountryMap(self)
}
```

- [ ] **Step 6: Block battle controls while popup is visible**

At the top of `spawnSoldier()` add:

```swift
guard !isConquestPopupVisible, state.stageStatus == .battleActive else {
    return
}
```

At the top of `upgradeSoldier()` add:

```swift
guard !isConquestPopupVisible else {
    return
}
```

Replace the conquered branch in `completeSoldierAttack(_:)` with:

```swift
if conqueredCity {
    feedbackText = "\(state.displayCityTitle) conquered! +\(result.goldEarned) gold."
} else {
    feedbackText = "Soldier dealt \(result.damageDealt) damage."
}

store.save(state)
redraw()

if conqueredCity {
    playCityConquestFeedback()
    showConquestPopup(goldEarned: result.goldEarned)
} else {
    playCityHitFeedback()
}
```

Update `buttonName(at:)` to include `ButtonName.popupContinue`, and update `touchesEnded`:

```swift
case ButtonName.popupContinue:
    closeConquestPopup()
```

- [ ] **Step 7: Update lifecycle resume to show popup on idle conquest**

In `sceneWillEnterForeground(_:)`, replace the feedback branch with:

```swift
if result.elapsedSeconds > 0 {
    if result.conqueredCities > 0 {
        feedbackText = "Idle attacks conquered \(state.displayCityTitle)."
    } else {
        feedbackText = "Idle attacks dealt \(result.damageDealt) damage."
    }
}

redraw()

if result.conqueredCities > 0 {
    showConquestPopup(goldEarned: result.goldEarned)
}
```

- [ ] **Step 8: Add DEBUG test hooks**

In the `#if DEBUG` extension, rename `extension GameScene` to `extension BattleScene` and add:

```swift
var isConquestPopupVisibleForTesting: Bool {
    isConquestPopupVisible
}

func closeConquestPopupForTesting() {
    closeConquestPopup()
}
```

- [ ] **Step 9: Run battle scene tests**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:PyxisTests/BattleSceneTests
```

Expected: PASS.

- [ ] **Step 10: Commit battle scene split**

Run:

```bash
git add Pyxis/BattleScene.swift PyxisTests/BattleSceneTests.swift
git commit -m "Add battle conquest popup routing"
```

Expected: commit succeeds.

---

### Task 5: Country Map Scene

**Files:**
- Create: `Pyxis/CountryMapScene.swift`
- Create: `PyxisTests/CountryMapSceneTests.swift`

- [ ] **Step 1: Write country map scene tests**

Create `PyxisTests/CountryMapSceneTests.swift`:

```swift
//
//  CountryMapSceneTests.swift
//  PyxisTests
//

import Foundation
import SpriteKit
import Testing
@testable import Pyxis

@MainActor
struct CountryMapSceneTests {
    @Test func enteringUnlockedCitySavesStateAndRoutesToBattle() throws {
        let store = try makeStore(initialState: KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        ))
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        scene.enterCityForTesting(2)

        let saved = store.load()
        #expect(saved.stageStatus == .battleActive)
        #expect(saved.cityNumberInCountry == 2)
        #expect(saved.cityLevel == 2)
        #expect(saved.cityRemainingPower == KingdomGameState.cityMaxPower(for: 2))
        #expect(router.didRequestBattle)
    }

    @Test func enteringLockedCityDoesNotMutateOrRoute() throws {
        let initialState = KingdomGameState(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        )
        let store = try makeStore(initialState: initialState)
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        scene.enterCityForTesting(3)

        #expect(store.load() == initialState)
        #expect(!router.didRequestBattle)
        #expect(scene.feedbackTextForTesting == "City 3 is locked.")
    }

    @Test func completedCountryHasNoEnterableNextCity() throws {
        let initialState = KingdomGameState(
            cityLevel: 15,
            cityRemainingPower: 0,
            cityNumberInCountry: 15,
            completedCityCount: 15,
            stageStatus: .countryComplete
        )
        let store = try makeStore(initialState: initialState)
        let router = RouteSpy()
        let scene = makeScene(store: store, router: router)

        scene.enterCityForTesting(15)

        #expect(store.load() == initialState)
        #expect(!router.didRequestBattle)
        #expect(scene.feedbackTextForTesting == "Country 1 conquered.")
    }

    private final class RouteSpy: CountryMapSceneRouting {
        private(set) var didRequestBattle = false

        func countryMapSceneDidRequestBattle(_ scene: CountryMapScene) {
            didRequestBattle = true
        }
    }

    private func makeScene(store: KingdomGameStore, router: CountryMapSceneRouting) -> CountryMapScene {
        let size = CGSize(width: 390, height: 844)
        let scene = CountryMapScene(size: size, store: store, router: router)
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

- [ ] **Step 2: Run country map tests and verify compile failure**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:PyxisTests/CountryMapSceneTests
```

Expected: FAIL because `CountryMapScene` and `CountryMapSceneRouting` do not exist.

- [ ] **Step 3: Create `CountryMapScene`**

Create `Pyxis/CountryMapScene.swift`:

```swift
//
//  CountryMapScene.swift
//  Pyxis
//

import Foundation
import SpriteKit
import UIKit

protocol CountryMapSceneRouting: AnyObject {
    func countryMapSceneDidRequestBattle(_ scene: CountryMapScene)
}

final class CountryMapScene: SKScene {
    private enum NodeName {
        static let cityPrefix = "countryMapCity-"
    }

    private let store: KingdomGameStore
    private weak var router: CountryMapSceneRouting?
    private var state: KingdomGameState
    private var didBuildInterface = false
    private let titleLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let feedbackLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private let routeLayer = SKNode()
    private let cityLayer = SKNode()
    private var cityNodes: [Int: SKShapeNode] = [:]
    private var cityLabels: [Int: SKLabelNode] = [:]
    private var feedbackText = "Select the unlocked city."

    init(size: CGSize, store: KingdomGameStore = .shared, router: CountryMapSceneRouting? = nil) {
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

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.08, green: 0.15, blue: 0.18, alpha: 1.0)

        if !didBuildInterface {
            buildInterface()
            didBuildInterface = true
        }

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

        guard let cityNumber = cityNumber(at: touch.location(in: self)) else {
            return
        }

        enterCity(cityNumber)
    }

    private func buildInterface() {
        routeLayer.zPosition = 0
        cityLayer.zPosition = 10
        addChild(routeLayer)
        addChild(cityLayer)

        configureLabel(titleLabel, fontSize: 30, color: .white)
        configureLabel(feedbackLabel, fontSize: 16, color: SKColor(red: 0.95, green: 0.91, blue: 0.78, alpha: 1.0))
        addChild(titleLabel)
        addChild(feedbackLabel)

        for cityNumber in 1...KingdomGameState.firstCountryCityCount {
            let node = SKShapeNode(circleOfRadius: 18)
            node.name = "\(NodeName.cityPrefix)\(cityNumber)"
            node.lineWidth = 3
            cityLayer.addChild(node)
            cityNodes[cityNumber] = node

            let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
            configureLabel(label, fontSize: 13, color: .white)
            label.text = "\(cityNumber)"
            label.name = node.name
            cityLayer.addChild(label)
            cityLabels[cityNumber] = label
        }
    }

    private func configureLabel(_ label: SKLabelNode, fontSize: CGFloat, color: SKColor) {
        label.fontSize = fontSize
        label.fontColor = color
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
    }

    private func layoutInterface() {
        guard didBuildInterface else {
            return
        }

        let topMargin: CGFloat = size.height < 500 ? 38 : 72
        let bottomMargin: CGFloat = size.height < 500 ? 34 : 50
        let contentWidth = max(220, min(size.width - 48, 520))
        let mapTop = size.height - topMargin - 70
        let mapBottom = bottomMargin + 70
        let mapHeight = max(220, mapTop - mapBottom)

        titleLabel.position = CGPoint(x: size.width / 2, y: size.height - topMargin)
        feedbackLabel.position = CGPoint(x: size.width / 2, y: bottomMargin)

        let positions = cityPositions(contentWidth: contentWidth, mapHeight: mapHeight)
        drawRoutes(positions: positions)

        for cityNumber in 1...KingdomGameState.firstCountryCityCount {
            guard let point = positions[cityNumber] else {
                continue
            }

            cityNodes[cityNumber]?.position = point
            cityLabels[cityNumber]?.position = point
        }
    }

    private func cityPositions(contentWidth: CGFloat, mapHeight: CGFloat) -> [Int: CGPoint] {
        let centerX = size.width / 2
        let leftX = centerX - contentWidth * 0.36
        let midLeftX = centerX - contentWidth * 0.18
        let midRightX = centerX + contentWidth * 0.14
        let rightX = centerX + contentWidth * 0.36
        let bottomY = max(100, feedbackLabel.position.y + 58)
        let stepY = mapHeight / 14

        let columns: [CGFloat] = [
            leftX, midLeftX, midRightX, rightX, midRightX,
            midLeftX, leftX, midLeftX, centerX, midRightX,
            rightX, midRightX, centerX, midLeftX, midRightX
        ]

        var result: [Int: CGPoint] = [:]
        for cityNumber in 1...KingdomGameState.firstCountryCityCount {
            result[cityNumber] = CGPoint(
                x: columns[cityNumber - 1],
                y: bottomY + CGFloat(cityNumber - 1) * stepY
            )
        }
        return result
    }

    private func drawRoutes(positions: [Int: CGPoint]) {
        routeLayer.removeAllChildren()

        for cityNumber in 1..<KingdomGameState.firstCountryCityCount {
            guard let start = positions[cityNumber], let end = positions[cityNumber + 1] else {
                continue
            }

            let path = CGMutablePath()
            path.move(to: start)
            path.addLine(to: end)
            let line = SKShapeNode(path: path)
            line.strokeColor = SKColor(red: 0.72, green: 0.56, blue: 0.28, alpha: 1.0)
            line.lineWidth = 6
            line.lineCap = .round
            routeLayer.addChild(line)
        }
    }

    private func redraw() {
        titleLabel.text = "Country \(state.countryNumber)"
        feedbackLabel.text = feedbackText

        for cityNumber in 1...KingdomGameState.firstCountryCityCount {
            switch state.mapStatus(for: cityNumber) {
            case .completed:
                cityNodes[cityNumber]?.fillColor = SKColor(red: 0.95, green: 0.78, blue: 0.18, alpha: 1.0)
                cityNodes[cityNumber]?.strokeColor = .white
            case .unlocked:
                cityNodes[cityNumber]?.fillColor = SKColor(red: 0.17, green: 0.62, blue: 0.38, alpha: 1.0)
                cityNodes[cityNumber]?.strokeColor = .white
            case .locked:
                cityNodes[cityNumber]?.fillColor = SKColor(red: 0.23, green: 0.33, blue: 0.43, alpha: 1.0)
                cityNodes[cityNumber]?.strokeColor = SKColor(white: 1.0, alpha: 0.26)
            }
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

    private func enterCity(_ cityNumber: Int) {
        switch state.startCityFromMap(cityNumber) {
        case .entered:
            store.save(state)
            router?.countryMapSceneDidRequestBattle(self)
        case .locked:
            feedbackText = "City \(cityNumber) is locked."
            redraw()
        case .alreadyCompleted:
            feedbackText = "City \(cityNumber) is complete."
            redraw()
        case .countryComplete:
            feedbackText = "Country \(state.countryNumber) conquered."
            redraw()
        }
    }
}

#if DEBUG
extension CountryMapScene {
    var feedbackTextForTesting: String {
        feedbackText
    }

    func enterCityForTesting(_ cityNumber: Int) {
        enterCity(cityNumber)
    }
}
#endif
```

- [ ] **Step 4: Run country map tests**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:PyxisTests/CountryMapSceneTests
```

Expected: PASS.

- [ ] **Step 5: Commit country map scene**

Run:

```bash
git add Pyxis/CountryMapScene.swift PyxisTests/CountryMapSceneTests.swift
git commit -m "Add country map scene"
```

Expected: commit succeeds.

---

### Task 6: Scene Routing In Game View Controller

**Files:**
- Modify: `Pyxis/GameViewController.swift`

- [ ] **Step 1: Replace direct `GameScene` presentation**

Replace `GameViewController` with:

```swift
//
//  GameViewController.swift
//  Pyxis
//
//  Created by Chan Wai Chan on 5/5/2026.
//

import UIKit
import SpriteKit

final class GameViewController: UIViewController {
    private let store = KingdomGameStore.shared

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let view = self.view as? SKView else {
            return
        }

        configure(view)
        presentInitialScene(in: view)
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }

    override var prefersStatusBarHidden: Bool {
        true
    }

    private func configure(_ view: SKView) {
        view.ignoresSiblingOrder = true
        view.showsFPS = true
        view.showsNodeCount = true
    }

    private func presentInitialScene(in view: SKView) {
        let state = store.load()

        switch state.stageStatus {
        case .battleActive:
            presentBattleScene(in: view)
        case .cityConqueredPendingMap, .countryComplete:
            presentCountryMapScene(in: view)
        }
    }

    private func presentBattleScene(in view: SKView) {
        let scene = BattleScene(size: view.bounds.size, store: store, router: self)
        scene.scaleMode = .resizeFill
        view.presentScene(scene)
    }

    private func presentCountryMapScene(in view: SKView) {
        let scene = CountryMapScene(size: view.bounds.size, store: store, router: self)
        scene.scaleMode = .resizeFill
        view.presentScene(scene)
    }
}

extension GameViewController: BattleSceneRouting {
    func battleSceneDidRequestCountryMap(_ scene: BattleScene) {
        guard let view = self.view as? SKView else {
            return
        }

        presentCountryMapScene(in: view)
    }
}

extension GameViewController: CountryMapSceneRouting {
    func countryMapSceneDidRequestBattle(_ scene: CountryMapScene) {
        guard let view = self.view as? SKView else {
            return
        }

        presentBattleScene(in: view)
    }
}
```

- [ ] **Step 2: Run a build**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: PASS.

- [ ] **Step 3: Run scene tests**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:PyxisTests/BattleSceneTests -only-testing:PyxisTests/CountryMapSceneTests
```

Expected: PASS.

- [ ] **Step 4: Commit routing**

Run:

```bash
git add Pyxis/GameViewController.swift
git commit -m "Route between battle and country map scenes"
```

Expected: commit succeeds.

---

### Task 7: Full Regression And Manual Smoke

**Files:**
- Modify only files needed for fixes discovered by verification.

- [ ] **Step 1: Run the full test suite**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test
```

Expected: PASS for unit and UI tests.

- [ ] **Step 2: If iPhone 16 is unavailable, list destinations**

Run only if Step 1 fails with an unavailable destination:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -showdestinations
```

Expected: output lists available iOS simulator destinations. Rerun Step 1 with an available `platform=iOS Simulator,name=<device name>` destination.

- [ ] **Step 3: Manual smoke in the simulator**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: PASS.

Open the app from Xcode or the simulator workflow already available in the environment and verify:

- app launches directly into `Country 1 - City 1` battle
- repeated Spawn Soldier taps create moving soldiers
- city HP changes only when soldiers reach the city
- conquering City 1 opens the congratulations popup
- closing the popup shows the country map
- Country 1 map shows 15 cities
- City 1 is completed
- City 2 is unlocked
- City 3 through City 15 are locked
- tapping City 2 returns to battle

- [ ] **Step 4: Commit verification fixes if needed**

If verification required fixes, commit them:

```bash
git add Pyxis PyxisTests PyxisUITests
git commit -m "Stabilize country map flow"
```

Expected: commit succeeds if there were fixes. If there were no fixes, leave the working tree clean.

---

## Self-Review Notes

- Spec coverage: model campaign fields, explicit city entry, two scenes, `GameViewController` routing, idle stop-at-current-city, persistence, popup, map states, and testing are covered by Tasks 1-7.
- Placeholder scan: this plan uses concrete paths, APIs, commands, and test snippets; it contains no deferred requirement sections.
- Type consistency: `StageStatus`, `MapCityStatus`, `CityEntryResult`, `BattleSceneRouting`, `CountryMapSceneRouting`, `startCityFromMap(_:)`, and DEBUG hooks are introduced before subsequent tasks use them.
