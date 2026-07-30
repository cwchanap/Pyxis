# Typed Battle Events and Active-Siege Result Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add typed combat events, a persistent `ActiveSiegeSession`, idle/settlement damage attribution, and a finalized `BattleResult` with pending acknowledgment so HPA-388/HPA-367 can consume trustworthy siege data without SpriteKit node lookup.

**Architecture:** `BattleCombatState` emits immutable attack/loss events before pruning. Pure `ActiveSiegeSession` / `BattleResult` types in `BattleResultModels.swift` accumulate flat Codable rows and finalize MVP. `KingdomGameState` owns optional session + `pendingBattleResult`, normalize/decode, active-time/deployment forwarding, `applyLiveSoldierAttacks`, idle attribution, `completeCurrentCity(with:)`, and `acknowledgePendingBattleResult()`. `BattleScene` forwards events and gated active time; it does not keep a second stats accumulator.

**Tech Stack:** Swift 5, Swift Testing (`PyxisTests`), Foundation-only pure models, `KingdomGameStore` JSON/`UserDefaults`, Xcode / `xcodebuild` on macOS (not runnable on the Linux cloud VM).

## Global Constraints

- Approved design:
  `docs/superpowers/specs/2026-07-30-typed-battle-events-and-active-siege-result-design.md`.
  Treat its types, lifecycle rules, marker-on-deployment rule, idle=settlement
  mode, MVP tie-break, and pending-ack semantics as acceptance contracts.
- TDD: write the failing test first for each task; do not add production
  behavior before seeing the relevant failure.
- Pure models stay free of SpriteKit/UIKit.
- Do not implement conquest-report layout (HPA-388) or Chronicle storage
  (HPA-367). Leave a marked no-op extension point in
  `completeCurrentCity(with:)` for Chronicle.
- Do not change combat balance, gold formulas, idle scale, or city progression
  rules beyond attribution/persistence.
- Do not edit `Pyxis.xcodeproj/project.pbxproj`; synchronized root groups pick
  up new Swift files automatically.
- Preserve unrelated work. Check `git status --short` before every commit and
  stage only the files named by the task.
- Swift unit/UI tests require macOS + Xcode. Prefer XcodeBuildMCP when
  available; every `test_sim` / `xcodebuild test` call must include
  `-parallel-testing-enabled NO`. Fallback:
  ```bash
  xcodebuild test \
    -project Pyxis.xcodeproj \
    -scheme Pyxis \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -parallel-testing-enabled NO \
    -only-testing:PyxisTests/<TestFile>/<testName>
  ```
  If `iPhone 17` is unavailable, run `-showdestinations` and substitute one
  available simulator consistently. On the Linux cloud VM, implement and
  review against the design; run Swift tests on macOS CI / a macOS host before
  claiming green.

## File Map

### Create

- `Pyxis/BattleResultModels.swift` — `SiegeDeploymentCount`,
  `SiegeDamageAttribution`, `SiegeLossCount`, `SiegeIdleDamageByType`,
  `ActiveSiegeSession`, `BattleConquestMode`, `BattleResult`, row-merge helpers,
  MVP finalize.
- `PyxisTests/BattleResultModelsTests.swift` — session accumulate, markers,
  MVP, finalize, Codable round-trip.
- `PyxisTests/ActiveSiegeLifecycleTests.swift` — state lifecycle, pending ack,
  normalize/decode, live/idle integration without SpriteKit node attribution.

### Modify

- `Pyxis/BattleCombatState.swift` — event types (or re-export), `TickResult`
  event arrays, emit before prune.
- `Pyxis/BattleLane.swift` — add `Codable`.
- `Pyxis/CityBuildingState.swift` — `CityKey: Codable` via `storageKey`.
- `Pyxis/KingdomGameState.swift` — session/pending fields, coding keys, init
  normalize, deployment/time/attack/loss/idle APIs, `completeCurrentCity(with:)`,
  `acknowledgePendingBattleResult()`, wire idle/settle attribution.
- `Pyxis/BattleScene.swift` — consume events; record deployments, losses,
  attacks, gated active time; keep simple popup until HPA-388.
- `PyxisTests/BattleCombatStateTests.swift` — migrate ID assertions to events;
  add overkill + loss-before-prune coverage.
- `PyxisTests/KingdomGameStateTests.swift` — update conquest callers as needed;
  add/adjust decode compatibility for new keys.
- `PyxisTests/KingdomGameStoreTests.swift` — missing/corrupt session/result.
- `PyxisTests/BattleSceneTests.swift` — event consumption, session preserve on
  route/background, live + idle pending result, clearLiveCombat ≠ losses.

---

### Task 1: Typed Tick Events and Overkill Clamp

**Files:**
- Modify: `Pyxis/BattleCombatState.swift`
- Modify: `PyxisTests/BattleCombatStateTests.swift`
- Test: `PyxisTests/BattleCombatStateTests.swift`

**Interfaces:**
- Produces:
  ```swift
  struct SoldierAttackEvent: Equatable {
      let soldierID: BattleCombatState.SoldierID
      let type: SoldierType
      let source: SoldierSpawnSource
      let lane: BattleLane
      let appliedCityDamage: Int
  }

  struct SoldierLossEvent: Equatable {
      let soldierID: BattleCombatState.SoldierID
      let type: SoldierType
      let source: SoldierSpawnSource
      let lane: BattleLane
  }
  ```
  and `TickResult.soldierAttacks` / `soldierLosses` replacing
  `soldierAttackIDs` / `killedSoldierIDs`.

- [ ] **Step 1: Write the failing tests**

Add to `BattleCombatStateTests.swift` (update existing ID assertions in the
same edit once implementation lands; for TDD, add these new tests first and
expect compile failure on missing symbols):

```swift
@Test func soldierAttackEventUsesClampedAppliedDamageOnOverkill() {
    var combat = BattleCombatState(
        configuration: .init(
            soldierAttackRange: 1,
            soldierMovementSpeed: 1,
            towerAttackInterval: 999,
            maxDeltaTime: 1
        ),
        seed: 1
    )
    let id = combat.spawnSoldier(
        type: .infantry,
        source: .manual,
        level: 1,
        attackPower: 10,
        lane: .center
    )

    let result = combat.tick(deltaTime: 0.1, cityRemainingHP: 3)

    #expect(result.cityDamage == 3)
    #expect(result.soldierAttacks.count == 1)
    let attack = result.soldierAttacks[0]
    #expect(attack.soldierID == id)
    #expect(attack.type == .infantry)
    #expect(attack.source == .manual)
    #expect(attack.lane == .center)
    #expect(attack.appliedCityDamage == 3)
    #expect(result.didReachConquest)
}

@Test func soldierLossEventEmittedBeforePrune() {
    var combat = BattleCombatState(
        configuration: .init(
            soldierMaxHP: 1,
            soldierDefense: 0,
            towerDamage: 10,
            towerAttackInterval: 0.01,
            maxDeltaTime: 1
        ),
        seed: 1
    )
    let id = combat.spawnSoldier(
        type: .archer,
        source: .building,
        level: 2,
        attackPower: 1,
        lane: .left
    )

    let result = combat.tick(deltaTime: 0.1, cityRemainingHP: 20)

    #expect(result.soldierLosses == [
        SoldierLossEvent(soldierID: id, type: .archer, source: .building, lane: .left)
    ])
    #expect(combat.soldier(id: id) == nil)
    #expect(result.damagedSoldierIDs.contains(id))
}
```

Adapt `Configuration` field names to the real `BattleCombatState.Configuration`
initializer in the file (copy from neighboring tests). Do not invent config
keys that do not exist.

- [ ] **Step 2: Run tests to verify they fail**

Run focused `BattleCombatStateTests` (macOS). Expected: compile error or
failure on missing `soldierAttacks` / `SoldierLossEvent`.

- [ ] **Step 3: Implement event payloads and tick emission**

In `BattleCombatState.swift`:

1. Add `SoldierAttackEvent` and `SoldierLossEvent` (file-level or nested; if
   nested, tests use `BattleCombatState.SoldierAttackEvent` — prefer
   file-level in `BattleCombatState.swift` or move to
   `BattleResultModels.swift` in Task 2; for this task, defining them next to
   `TickResult` is fine).
2. Change `TickResult` to:
   ```swift
   struct TickResult: Equatable {
       var cityDamage: Int = 0
       var didReachConquest = false
       var soldierAttacks: [SoldierAttackEvent] = []
       var towerShots: [TowerShot] = []
       var damagedSoldierIDs: [SoldierID] = []
       var soldierLosses: [SoldierLossEvent] = []
   }
   ```
3. On soldier attack, append a full `SoldierAttackEvent` with
   `appliedCityDamage = min(attackPower, remainingCityHP)` before reducing HP.
4. On tower kill, append `SoldierLossEvent` from the soldier’s current fields
   **before** `soldiers.removeAll { !$0.isAlive }`.
5. Remove all uses of `soldierAttackIDs` / `killedSoldierIDs`.

- [ ] **Step 4: Migrate existing combat tests**

Replace assertions:

- `result.soldierAttackIDs == [id]` →
  `result.soldierAttacks.map(\.soldierID) == [id]` (and check type/source/lane
  where useful).
- `result.killedSoldierIDs` → `result.soldierLosses.map(\.soldierID)`.

- [ ] **Step 5: Run tests to verify they pass**

Expected: `BattleCombatStateTests` green on macOS.

- [ ] **Step 6: Commit**

```bash
git add Pyxis/BattleCombatState.swift PyxisTests/BattleCombatStateTests.swift
git commit -m "feat: emit typed soldier attack and loss events from combat ticks"
```

---

### Task 2: Codable Foundations and Pure Session Accumulator

**Files:**
- Create: `Pyxis/BattleResultModels.swift`
- Create: `PyxisTests/BattleResultModelsTests.swift`
- Modify: `Pyxis/BattleLane.swift`
- Modify: `Pyxis/CityBuildingState.swift` (`CityKey` Codable)

**Interfaces:**
- Produces session/result types and:
  ```swift
  mutating func recordDeployment(
      type: SoldierType,
      source: SoldierSpawnSource,
      lane: BattleLane,
      favorableTypes: [SoldierType],
      exposedLane: BattleLane
  )
  mutating func recordAttack(_ event: SoldierAttackEvent)
  mutating func recordLoss(_ event: SoldierLossEvent)
  mutating func recordIdleDamage(type: SoldierType, appliedDamage: Int)
  mutating func advanceActiveBattleTime(_ delta: TimeInterval)
  func finalized(conquestMode: BattleConquestMode, goldEarned: Int) -> BattleResult
  ```

- [ ] **Step 1: Write failing session/MVP tests**

Create `PyxisTests/BattleResultModelsTests.swift`:

```swift
import Foundation
import Testing
@testable import Pyxis

struct BattleResultModelsTests {
    @Test func deploymentMergesRowsAndFlipsMarkers() {
        var session = ActiveSiegeSession(cityKey: CityKey(countryNumber: 1, cityNumber: 1))
        session.recordDeployment(
            type: .mage,
            source: .manual,
            lane: .right,
            favorableTypes: [.mage, .siege],
            exposedLane: .right
        )
        session.recordDeployment(
            type: .mage,
            source: .manual,
            lane: .right,
            favorableTypes: [.mage, .siege],
            exposedLane: .right
        )
        session.recordDeployment(
            type: .infantry,
            source: .building,
            lane: .left,
            favorableTypes: [.mage, .siege],
            exposedLane: .right
        )

        #expect(session.usedFavorableUnit)
        #expect(session.usedExposedLane)
        #expect(session.deployments == [
            SiegeDeploymentCount(type: .infantry, source: .building, lane: .left, count: 1),
            SiegeDeploymentCount(type: .mage, source: .manual, lane: .right, count: 2),
        ])
    }

    @Test func markersDoNotFlipFromDamageAlone() {
        var session = ActiveSiegeSession(cityKey: CityKey(countryNumber: 1, cityNumber: 2))
        session.recordAttack(
            SoldierAttackEvent(
                soldierID: 1,
                type: .mage,
                source: .manual,
                lane: .right,
                appliedCityDamage: 5
            )
        )
        #expect(!session.usedFavorableUnit)
        #expect(!session.usedExposedLane)
    }

    @Test func mvpUsesHighestDamageThenAllCasesOrder() {
        var session = ActiveSiegeSession(cityKey: CityKey(countryNumber: 1, cityNumber: 3))
        session.recordAttack(
            SoldierAttackEvent(
                soldierID: 1, type: .cavalry, source: .manual, lane: .center, appliedCityDamage: 4
            )
        )
        session.recordAttack(
            SoldierAttackEvent(
                soldierID: 2, type: .infantry, source: .manual, lane: .left, appliedCityDamage: 4
            )
        )
        // infantry appears before cavalry in SoldierType.allCases → infantry wins tie
        let result = session.finalized(conquestMode: .live, goldEarned: 10)
        #expect(result.mvpSoldierType == .infantry)
        #expect(result.mvpDamageSharePercent == 50)
        #expect(result.goldEarned == 10)
        #expect(result.conquestMode == .live)
    }

    @Test func mvpNilWhenNoAttributableDamage() {
        let session = ActiveSiegeSession(cityKey: CityKey(countryNumber: 1, cityNumber: 4))
        let result = session.finalized(conquestMode: .idle, goldEarned: 8)
        #expect(result.mvpSoldierType == nil)
        #expect(result.mvpDamageSharePercent == nil)
        #expect(result.conquestMode == .idle)
    }

    @Test func idleDamageMergesByType() {
        var session = ActiveSiegeSession(cityKey: CityKey(countryNumber: 1, cityNumber: 5))
        session.recordIdleDamage(type: .archer, appliedDamage: 3)
        session.recordIdleDamage(type: .archer, appliedDamage: 2)
        session.recordIdleDamage(type: .siege, appliedDamage: 1)
        #expect(session.idleDamageByType == [
            SiegeIdleDamageByType(type: .archer, damage: 5),
            SiegeIdleDamageByType(type: .siege, damage: 1),
        ])
        let result = session.finalized(conquestMode: .idle, goldEarned: 1)
        #expect(result.mvpSoldierType == .archer)
        #expect(result.mvpDamageSharePercent == 83) // 5*100/6
    }

    @Test func activeBattleTimeIgnoresNonPositiveDelta() {
        var session = ActiveSiegeSession(cityKey: CityKey(countryNumber: 1, cityNumber: 1))
        session.advanceActiveBattleTime(1.25)
        session.advanceActiveBattleTime(-4)
        session.advanceActiveBattleTime(0)
        #expect(session.activeBattleSeconds == 1.25)
    }

    @Test func cityKeyAndBattleLaneRoundTrip() throws {
        let key = CityKey(countryNumber: 1, cityNumber: 7)
        let encodedKey = try JSONEncoder().encode(key)
        let decodedKey = try JSONDecoder().decode(CityKey.self, from: encodedKey)
        #expect(decodedKey == key)

        let laneData = try JSONEncoder().encode(BattleLane.right)
        #expect(try JSONDecoder().decode(BattleLane.self, from: laneData) == .right)
    }
}
```

Normalize row sort order in expectations to match the implementation
(`SoldierType.allCases`, then source raw value, then lane raw value).

- [ ] **Step 2: Run tests — expect compile failure**

- [ ] **Step 3: Implement Codable helpers and models**

`BattleLane.swift` — add `Codable` to the enum declaration.

`CityKey` — add `Codable` with single-value `storageKey` encode/decode;
decode failure should throw (state-level lossy handling wraps this later):

```swift
extension CityKey: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let storageKey = try container.decode(String.self)
        guard let key = CityKey(storageKey: storageKey) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid CityKey storageKey \(storageKey)"
            )
        }
        self = key
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(storageKey)
    }
}
```

Create `Pyxis/BattleResultModels.swift` with the summary structs,
`ActiveSiegeSession`, `BattleConquestMode`, `BattleResult`, merge helpers that
omit zero rows, stable sort after each mutation (or on finalize — prefer sort
on mutate so Equatable tests are stable), and MVP:

```swift
// Per-type damage = sum(appliedDamage rows by type) + sum(idleDamageByType)
// Winner = max damage; tie → first in SoldierType.allCases
// percent = (mvpDamage * 100) / totalDamage  // truncating; MVP nil iff total == 0
```

If `SoldierAttackEvent` / `SoldierLossEvent` lived only in Task 1’s combat
file, either keep them there and import via `@testable`, or move both event
types into `BattleResultModels.swift` and leave combat referencing them —
pick one home and delete duplicates.

- [ ] **Step 4: Run tests — expect pass**

- [ ] **Step 5: Commit**

```bash
git add Pyxis/BattleResultModels.swift Pyxis/BattleLane.swift \
  Pyxis/CityBuildingState.swift PyxisTests/BattleResultModelsTests.swift \
  Pyxis/BattleCombatState.swift
git commit -m "feat: add ActiveSiegeSession accumulator and BattleResult finalize"
```

---

### Task 3: Persist Session and Pending Result on KingdomGameState

**Files:**
- Modify: `Pyxis/KingdomGameState.swift`
- Create: `PyxisTests/ActiveSiegeLifecycleTests.swift`
- Modify: `PyxisTests/KingdomGameStateTests.swift` / `KingdomGameStoreTests.swift` as needed

**Interfaces:**
- Produces:
  ```swift
  var activeSiegeSession: ActiveSiegeSession?
  var pendingBattleResult: BattleResult?

  mutating func ensureActiveSiegeSession() -> ActiveSiegeSession // or private
  mutating func recordSoldierDeployment(type:source:lane:)
  mutating func recordActiveBattleTime(_ delta: TimeInterval)
  mutating func acknowledgePendingBattleResult()
  ```

- [ ] **Step 1: Write failing lifecycle/normalize tests**

In `ActiveSiegeLifecycleTests.swift`:

```swift
@Test func missingSessionAndPendingDecodeAsNil() throws {
    // Encode a minimal legacy-like state JSON without the new keys, or
    // construct KingdomGameState and re-encode/decode after stripping keys.
    var state = KingdomGameState(
        gold: 0,
        cityLevel: 1,
        cityRemainingPower: 20,
        normalSoldierUpgradeLevel: 1
    )
    let data = try JSONEncoder().encode(state)
    // Decode round-trip must succeed with nil session/pending
    let decoded = try JSONDecoder().decode(KingdomGameState.self, from: data)
    #expect(decoded.activeSiegeSession == nil)
    #expect(decoded.pendingBattleResult == nil)
}

@Test func mismatchedSessionCityKeyIsDroppedOnNormalize() {
    var state = KingdomGameState(
        gold: 0,
        cityLevel: 2,
        cityRemainingPower: 20,
        normalSoldierUpgradeLevel: 1,
        cityNumberInCountry: 2,
        completedCityCount: 1,
        stageStatus: .battleActive,
        activeSiegeSession: ActiveSiegeSession(
            cityKey: CityKey(countryNumber: 1, cityNumber: 9)
        )
    )
    #expect(state.activeSiegeSession == nil)
}

@Test func pendingResultDroppedWhenBattleActive() {
    let pending = BattleResult(
        cityKey: CityKey(countryNumber: 1, cityNumber: 1),
        conquestMode: .live,
        activeBattleSeconds: 3,
        deployments: [],
        appliedDamage: [],
        losses: [],
        idleDamageByType: [],
        mvpSoldierType: nil,
        mvpDamageSharePercent: nil,
        usedFavorableUnit: false,
        usedExposedLane: false,
        goldEarned: 8
    )
    var state = KingdomGameState(
        gold: 8,
        cityLevel: 1,
        cityRemainingPower: 20,
        normalSoldierUpgradeLevel: 1,
        stageStatus: .battleActive,
        pendingBattleResult: pending
    )
    #expect(state.pendingBattleResult == nil)
}

@Test func startCityClearsStalePendingAndStartsFreshSession() {
    var state = KingdomGameState(
        gold: 10,
        cityLevel: 1,
        cityRemainingPower: 0,
        normalSoldierUpgradeLevel: 1,
        completedCityCount: 1,
        stageStatus: .cityConqueredPendingMap,
        pendingBattleResult: BattleResult(
            cityKey: CityKey(countryNumber: 1, cityNumber: 1),
            conquestMode: .live,
            activeBattleSeconds: 1,
            deployments: [],
            appliedDamage: [],
            losses: [],
            idleDamageByType: [],
            mvpSoldierType: nil,
            mvpDamageSharePercent: nil,
            usedFavorableUnit: false,
            usedExposedLane: false,
            goldEarned: 8
        )
    )
    let entry = state.startCityFromMap(2)
    #expect(entry == .entered(country: 1, city: 2))
    #expect(state.pendingBattleResult == nil)
    #expect(state.activeSiegeSession?.cityKey == CityKey(countryNumber: 1, cityNumber: 2))
    #expect(state.activeSiegeSession?.activeBattleSeconds == 0)
}

@Test func acknowledgePendingClearsOnlyPending() {
    var state = KingdomGameState(
        gold: 10,
        cityLevel: 1,
        cityRemainingPower: 0,
        normalSoldierUpgradeLevel: 1,
        completedCityCount: 1,
        stageStatus: .cityConqueredPendingMap,
        pendingBattleResult: BattleResult(
            cityKey: CityKey(countryNumber: 1, cityNumber: 1),
            conquestMode: .live,
            activeBattleSeconds: 2,
            deployments: [],
            appliedDamage: [],
            losses: [],
            idleDamageByType: [],
            mvpSoldierType: .infantry,
            mvpDamageSharePercent: 100,
            usedFavorableUnit: false,
            usedExposedLane: false,
            goldEarned: 8
        )
    )
    let goldBefore = state.gold
    let completedBefore = state.completedCityCount
    state.acknowledgePendingBattleResult()
    #expect(state.pendingBattleResult == nil)
    #expect(state.gold == goldBefore)
    #expect(state.completedCityCount == completedBefore)
    #expect(state.stageStatus == .cityConqueredPendingMap)
    state.acknowledgePendingBattleResult() // no-op
}
```

Match `KingdomGameState` memberwise init parameters to the real initializer
(add new optional params with defaults `nil`). Adapt constructor call sites
across tests if the init signature gains parameters.

- [ ] **Step 2: Run — expect fail / compile errors**

- [ ] **Step 3: Implement persistence + normalize + thin APIs**

In `KingdomGameState`:

1. Add properties and `CodingKeys`.
2. Extend memberwise `init` with
   `activeSiegeSession: ActiveSiegeSession? = nil`,
   `pendingBattleResult: BattleResult? = nil`, then normalize:
   - Drop session if stage ≠ `.battleActive` or `session.cityKey != currentCityKey`.
   - Drop pending if stage is `.battleActive`, or pending `cityKey` mismatches
     `currentCityKey` while pending-map/complete.
3. Decode via `decodeIfPresent`; on nested decode failure for session/pending,
   use `nil` (try? decode) so the whole save does not fail.
4. `startCityFromMap` success path: `pendingBattleResult = nil`;
   `activeSiegeSession = ActiveSiegeSession(cityKey: currentCityKey)`.
5. Implement:
   ```swift
   mutating func recordSoldierDeployment(
       type: SoldierType,
       source: SoldierSpawnSource,
       lane: BattleLane
   ) {
       guard stageStatus == .battleActive else { return }
       ensureSession()
       let trait = currentCityDefenseTrait
       let exposed = currentCityLaneDefenseProfile.exposedLane
       activeSiegeSession?.recordDeployment(
           type: type,
           source: source,
           lane: lane,
           favorableTypes: trait.favorableSoldierTypes,
           exposedLane: exposed
       )
   }

   mutating func recordActiveBattleTime(_ delta: TimeInterval) {
       guard stageStatus == .battleActive else { return }
       ensureSession()
       activeSiegeSession?.advanceActiveBattleTime(delta)
   }

   mutating func acknowledgePendingBattleResult() {
       pendingBattleResult = nil
   }
   ```
6. Lazy `ensureSession()` creates `ActiveSiegeSession(cityKey: currentCityKey)`
   when nil mid-battle.

- [ ] **Step 4: Store corrupt nested coverage**

Add a `KingdomGameStoreTests` case: JSON with `"activeSiegeSession": "bogus"`
or invalid object still loads a playable state (session nil).

- [ ] **Step 5: Run focused tests — expect pass**

- [ ] **Step 6: Commit**

```bash
git add Pyxis/KingdomGameState.swift PyxisTests/ActiveSiegeLifecycleTests.swift \
  PyxisTests/KingdomGameStateTests.swift PyxisTests/KingdomGameStoreTests.swift
git commit -m "feat: persist active siege session and pending battle result"
```

---

### Task 4: Conquest Shell and Live Attack Application

**Files:**
- Modify: `Pyxis/KingdomGameState.swift`
- Modify: `PyxisTests/ActiveSiegeLifecycleTests.swift`
- Modify: `PyxisTests/KingdomGameStateTests.swift` (existing conquest tests)

**Interfaces:**
- Produces:
  ```swift
  struct CompletionResult: Equatable {
      let awarded: Bool
      let goldEarned: Int
  }

  mutating func completeCurrentCity(with result: BattleResult) -> CompletionResult

  mutating func applyLiveSoldierAttacks(
      _ events: [SoldierAttackEvent]
  ) -> AttackResult

  mutating func recordSoldierLosses(_ events: [SoldierLossEvent])
  ```
- Keep `applyLiveCombatDamage(_:)` working for legacy/unit tests by applying
  HP and, on conquest, finalizing the current session (possibly empty) as
  `.live` — so gold/stage tests stay valid without fabricating attack rows.

- [ ] **Step 1: Write failing conquest tests**

```swift
@Test func liveAttacksAttributeDamageAndFinalizePendingResult() {
    var state = KingdomGameState(
        gold: 0,
        cityLevel: 1,
        cityRemainingPower: 5,
        normalSoldierUpgradeLevel: 1
    )
    state.recordSoldierDeployment(type: .infantry, source: .manual, lane: .center)
    let result = state.applyLiveSoldierAttacks([
        SoldierAttackEvent(
            soldierID: 1, type: .infantry, source: .manual, lane: .center, appliedCityDamage: 5
        )
    ])
    #expect(result.conqueredCities == 1)
    #expect(result.goldEarned == state.pendingBattleResult?.goldEarned)
    let pending = try #require(state.pendingBattleResult)
    #expect(pending.conquestMode == .live)
    #expect(pending.cityKey == CityKey(countryNumber: 1, cityNumber: 1))
    #expect(pending.mvpSoldierType == .infantry)
    #expect(pending.goldEarned == KingdomGameState.goldReward(for: 1))
    #expect(state.gold == pending.goldEarned)
    #expect(state.activeSiegeSession == nil)
    #expect(state.stageStatus == .cityConqueredPendingMap)
}

@Test func completeCurrentCityRejectsDuplicate() {
    var state = KingdomGameState(
        gold: 0,
        cityLevel: 1,
        cityRemainingPower: 1,
        normalSoldierUpgradeLevel: 1
    )
    _ = state.applyLiveSoldierAttacks([
        SoldierAttackEvent(
            soldierID: 1, type: .infantry, source: .manual, lane: .left, appliedCityDamage: 1
        )
    ])
    let pending = try #require(state.pendingBattleResult)
    let gold = state.gold
    let second = state.completeCurrentCity(with: pending)
    #expect(second.awarded == false)
    #expect(state.gold == gold)
}

@Test func recordLossesDoNotRunOnEmptyAndMergeByTypeSource() {
    var state = KingdomGameState(
        gold: 0,
        cityLevel: 1,
        cityRemainingPower: 20,
        normalSoldierUpgradeLevel: 1
    )
    state.recordSoldierLosses([
        SoldierLossEvent(soldierID: 1, type: .archer, source: .building, lane: .left),
        SoldierLossEvent(soldierID: 2, type: .archer, source: .building, lane: .right),
    ])
    #expect(state.activeSiegeSession?.losses == [
        SiegeLossCount(type: .archer, source: .building, count: 2)
    ])
}
```

- [ ] **Step 2: Run — expect fail**

- [ ] **Step 3: Implement conquest shell**

Replace private `completeCurrentCity() -> Int` with:

```swift
@discardableResult
mutating func completeCurrentCity(with result: BattleResult) -> CompletionResult {
    guard stageStatus == .battleActive,
          result.cityKey == currentCityKey else {
        return CompletionResult(awarded: false, goldEarned: 0)
    }

    gold += result.goldEarned
    cityRemainingPower = 0
    cityBattleStates.removeValue(forKey: currentCityKey.storageKey)
    activeSiegeSession = nil
    pendingBattleResult = result
    completedCityCount = min(Self.firstCountryCityCount, max(completedCityCount, cityNumberInCountry))
    stageStatus = completedCityCount >= Self.firstCountryCityCount
        ? .countryComplete
        : .cityConqueredPendingMap

    // HPA-367: Chronicle write hooks here (no-op in HPA-363).

    return CompletionResult(awarded: true, goldEarned: result.goldEarned)
}
```

Implement `applyLiveSoldierAttacks`:

1. Guard `.battleActive`.
2. `ensureSession()`; for each event with `appliedCityDamage > 0`,
   `recordAttack` then apply `min(event.appliedCityDamage, cityRemainingPower)`
   to HP (defensive re-clamp).
3. If HP hits 0: build
   `session.finalized(conquestMode: .live, goldEarned: currentGoldReward)`
   ensuring `result.cityKey == currentCityKey`, then
   `completeCurrentCity(with:)`.
4. Return `AttackResult` mirroring today’s fields.

`applyLiveCombatDamage` on conquest should finalize empty/current session the
same way (no fabricated attack rows) so existing tests keep passing.

`recordSoldierLosses` only records while `.battleActive`; never invent losses
from `clearLiveCombat`.

- [ ] **Step 4: Fix any broken KingdomGameStateTests that depended on the old
  private return Int path** (they should still pass via
  `applyLiveCombatDamage`).

- [ ] **Step 5: Run focused tests — expect pass**

- [ ] **Step 6: Commit**

```bash
git add Pyxis/KingdomGameState.swift PyxisTests/ActiveSiegeLifecycleTests.swift \
  PyxisTests/KingdomGameStateTests.swift
git commit -m "feat: finalize BattleResult through completeCurrentCity(with:)"
```

---

### Task 5: Idle and Settlement Attribution

**Files:**
- Modify: `Pyxis/KingdomGameState.swift` (`resolveCurrentCityBuildingIdleProgress`,
  `settleCurrentCityBuildingProgress`)
- Modify: `PyxisTests/ActiveSiegeLifecycleTests.swift`
- Modify: `PyxisTests/KingdomGameStateTests.swift` if idle conquest assertions
  need pending-result checks

**Interfaces:**
- Consumes: `ActiveSiegeSession.recordIdleDamage`, `finalized(conquestMode: .idle, ...)`
- Produces: idle/settlement conquest sets `pendingBattleResult` with
  `.idle`; does not advance `activeBattleSeconds` by offline elapsed time.

- [ ] **Step 1: Write failing idle attribution test**

```swift
@Test func idleConquestAttributesDamageByTypeAndMarksIdle() {
    var state = KingdomGameState(
        gold: 0,
        cityLevel: 1,
        cityRemainingPower: KingdomGameState.cityMaxPower(for: 1),
        normalSoldierUpgradeLevel: 1
    )
    // Build one barracks, background, return after enough time to kill city.
    // Prefer the same helpers existing idle tests use (buildBuilding +
    // enterBackground + returnFromBackground with controlled dates).
    // Assert:
    // - pendingBattleResult?.conquestMode == .idle
    // - idleDamageByType sums to applied damageDealt
    // - activeBattleSeconds == 0 (never increased by offline elapsed)
    // - gold matches pending.goldEarned
}
```

Copy timing/building setup from an existing passing idle conquest test in
`KingdomGameStateTests` rather than inventing intervals.

Add a settlement variant: force `settleCurrentCityBuildingProgress` conquest
via build/upgrade after enough unresolved building time; expect `.idle` mode.

- [ ] **Step 2: Run — expect fail (pending nil or wrong mode)**

- [ ] **Step 3: Implement sequential idle attribution**

Extract a private helper used by both idle and settle paths:

```swift
private mutating func applyAbstractBuildingSpawnDamage(
    _ spawns: [BuildingSpawn],
    conquestMode: BattleConquestMode
) -> (applied: Int, conquered: Bool, goldEarned: Int)
```

For each spawn in order:

```swift
let power = traitAdjustedSoldierAttackPower(for: spawn.soldierType, level: spawn.level)
let applied = min(power, cityRemainingPower)
if applied > 0 {
    ensureSession()
    activeSiegeSession?.recordIdleDamage(type: spawn.soldierType, appliedDamage: applied)
    cityRemainingPower -= applied
}
if cityRemainingPower <= 0 {
    let reward = currentGoldReward
    let result = (activeSiegeSession ?? ActiveSiegeSession(cityKey: currentCityKey))
        .finalized(conquestMode: conquestMode, goldEarned: reward)
    let completion = completeCurrentCity(with: result)
    return (appliedTotal, true, completion.goldEarned)
}
```

Call with `.idle` from both idle catch-up and settlement. Do **not** call
`advanceActiveBattleTime` here.

- [ ] **Step 4: Run idle/settlement tests — expect pass**

- [ ] **Step 5: Commit**

```bash
git add Pyxis/KingdomGameState.swift PyxisTests/ActiveSiegeLifecycleTests.swift \
  PyxisTests/KingdomGameStateTests.swift
git commit -m "feat: attribute idle and settlement damage into ActiveSiegeSession"
```

---

### Task 6: BattleScene Integration

**Files:**
- Modify: `Pyxis/BattleScene.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`

**Interfaces:**
- Consumes: `soldierAttacks` / `soldierLosses`,
  `recordSoldierDeployment`, `recordSoldierLosses`,
  `applyLiveSoldierAttacks`, `recordActiveBattleTime`
- Must not treat `clearLiveCombat` as losses.

- [ ] **Step 1: Write failing scene integration tests**

Add tests that drive combat through existing `advanceCombatForTesting` (or
equivalent) helpers:

1. **Live conquest pending result** — spawn, advance until conquest; assert
   `state.pendingBattleResult` is non-nil, `.live`, gold matches popup gold
   path, and MVP/deployments come from model state (not nodes).
2. **Background clear is not a loss** — spawn soldier, trigger background
   handler / `clearLiveCombat` path without a tower kill; assert
   `activeSiegeSession?.losses` is empty (or unchanged).
3. **Active time** — advance combat while battle-active and popup hidden;
   assert `activeBattleSeconds` increases. With popup visible or after
   backgrounding, time does not advance.
4. **Idle conquest on foreground** — reuse existing idle conquest scene test;
   assert pending `.idle`.

- [ ] **Step 2: Run — expect fail**

- [ ] **Step 3: Wire BattleScene**

In `applyCombatResult`:

```swift
for attack in result.soldierAttacks {
    playSoldierAttackFeedback(for: attack.soldierID)
}
let killedIDs = Set(result.soldierLosses.map(\.soldierID))
// damagedSoldierIDs + killedIDs for hit FX as today
state.recordSoldierLosses(result.soldierLosses)
if !result.soldierAttacks.isEmpty {
    let damageResult = state.applyLiveSoldierAttacks(result.soldierAttacks)
    // conquest / feedback / save / popup as today using damageResult
}
```

Do **not** also call `applyLiveCombatDamage(result.cityDamage)` (double count).

On manual and building spawn success, after `combat.spawnSoldier` returns an
id, read `combat.soldier(id:)!.lane` and call
`state.recordSoldierDeployment(...)`. Save at existing save points.

In the combat frame path (where delta drives `advanceCombat`), when
`!isConquestPopupVisible && state.stageStatus == .battleActive` and the scene
is foreground-active, call `state.recordActiveBattleTime(clampedDelta)` —
use the same clamped delta combat uses, not background gaps. Do not save
every frame solely for time; existing throttled/boundary saves persist it.

Update any compile breaks from removed `soldierAttackIDs` /
`killedSoldierIDs`.

- [ ] **Step 4: Run BattleSceneTests + ActiveSiegeLifecycleTests — expect pass**

- [ ] **Step 5: Commit**

```bash
git add Pyxis/BattleScene.swift PyxisTests/BattleSceneTests.swift
git commit -m "feat: record siege session data from BattleScene combat ticks"
```

---

### Task 7: Full Acceptance Sweep

**Files:**
- Touch only if gaps appear in tests/docs listed above
- Modify: design/plan checkboxes only if needed

- [ ] **Step 1: Map acceptance criteria to tests**

Verify coverage exists for:

| Criterion | Test location |
| --- | --- |
| Live attribution by type/source/lane/applied | Tasks 1, 4, 6 |
| Losses once; clear ≠ loss | Tasks 1, 6 |
| Session survives route/background/relaunch | Task 3 + scene/store tests |
| Active time rules | Task 6 |
| Idle attribution + mode | Task 5 |
| Deterministic BattleResult | Tasks 2, 4 |
| Pending restore + ack | Task 3 |
| Old saves / corrupt safe | Task 3 store tests |

Add any missing focused test rather than broadening production code.

- [ ] **Step 2: Run broader unit suite on macOS**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests
```

Fix regressions without expanding scope into HPA-388 UI.

- [ ] **Step 3: Final commit if fixes landed**

```bash
git add -u
git commit -m "test: close HPA-363 acceptance coverage gaps"
```

- [ ] **Step 4: Update PR description** to note design + implementation and
  link HPA-363 / HPA-388 / HPA-367 boundaries.

---

## Spec Coverage Self-Check

| Spec section | Task |
| --- | --- |
| §1 Typed events / TickResult replace | Task 1 |
| §2 Flat rows + ActiveSiegeSession | Task 2 |
| §3 Lifecycle, persist, active time APIs | Tasks 3, 6 |
| §4 Idle + settlement `.idle` | Task 5 |
| §5 BattleResult + MVP | Task 2, 4 |
| §6 completeCurrentCity / acknowledge | Tasks 3–4 |
| §7 Scene integration foundation | Task 6 |
| §8 Testing plan | Tasks 1–7 |
| Non-goals (no report UI / no Chronicle) | All tasks |

## Placeholder Scan

No TBD/TODO steps. Configuration initializer details in Task 1 must be copied
from neighboring `BattleCombatStateTests` (real property names). Idle timing
setup in Task 5 must be copied from existing idle conquest tests.

## Type Consistency

- Events: `SoldierAttackEvent`, `SoldierLossEvent`
- Session API: `recordDeployment`, `recordAttack`, `recordLoss`,
  `recordIdleDamage`, `advanceActiveBattleTime`, `finalized(conquestMode:goldEarned:)`
- State API: `recordSoldierDeployment`, `recordSoldierLosses`,
  `applyLiveSoldierAttacks`, `recordActiveBattleTime`,
  `completeCurrentCity(with:)`, `acknowledgePendingBattleResult`
- Modes: `BattleConquestMode.live` / `.idle`
- Pending field: `pendingBattleResult`
