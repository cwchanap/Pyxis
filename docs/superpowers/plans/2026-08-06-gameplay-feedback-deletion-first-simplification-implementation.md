# Gameplay Feedback Deletion-First Simplification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Issue:** HPA-566  
**Design:** `docs/superpowers/specs/2026-08-06-gameplay-feedback-deletion-first-simplification-design.md`  
**Start condition:** Do not begin implementation solely for cleanup until the HPA-566 Linear start condition is met.  

**Goal:** Delete unnecessary gameplay-feedback projection, policy, directive, gate, sound-class duplication, speculative warning, and preference-delivery machinery while preserving current player-visible SFX, haptics, settings, automatic-combat restraint, and interruption-safe playback.

**Architecture:** Keep scenes behind a small semantic discrete-feedback protocol, pass `BattleCombatState.TickResult` directly to the automatic scheduler, inline discrete mapping in `DefaultGameplayFeedbackCoordinator`, and make `GameplaySoundCatalog` the sole authority for sound class. Keep the mature sound lifecycle/accessibility implementations intact. Replace JSON/versioned preference machinery with two direct Boolean `UserDefaults` keys and one simple synchronous cancellable observer path used by the coordinator.

**Tech Stack:** Swift 5, SpriteKit, UIKit, AVFoundation/AVAudioEngine, Swift Testing, UserDefaults, Xcode/xcodebuild, SwiftLint.

## Global Constraints

- Preserve existing player-visible sound, haptic, settings, accessibility, and interruption behavior.
- Add no SFX, haptic event, settings option, audio asset, or gameplay behavior.
- Do not broadly rewrite `BattleScene`.
- Do not introduce a replacement event bus, policy framework, DI layer, lifecycle abstraction, Combine publisher, Swift Observation model, or generalized feedback registry.
- Do not add backward-compatibility migration for the pre-release `pyxis.feedbackPreferences` JSON key.
- Keep campaign state under `pyxis.kingdomGameState` untouched.
- Keep automatic combat sound-only and drop-only: suppressed/pre-readiness/interrupted sounds are never queued or replayed.
- Preserve the current automatic timing contract: 150 ms global, 200 ms per attack family, 250 ms tower, shared 300 ms hit/death, and siege -> ranged -> melee anti-starvation rotation.
- Preserve discrete cooldowns independently per channel: deployment 120 ms, construction 250 ms, invalid action 500 ms.
- Keep audio backend serialization, asynchronous preparation, eight-voice allocation/protection, activation retry, background/interruption handling, and accessibility behavior unless a mechanical signature change is required.
- Production feedback-related Swift lines deleted must exceed lines added.
- Always run tests with parallel testing disabled.

---

## File Structure

### Files to delete

- `Pyxis/GameplayFeedbackPolicy.swift` — one-caller semantic-event -> directive mapping.
- `Pyxis/CombatFeedbackProjector.swift` — one-caller `TickResult` -> automatic-event projection.
- `PyxisTests/GameplayFeedbackPolicyTests.swift` — freezes the deleted directive structure.
- `PyxisTests/CombatFeedbackProjectorTests.swift` — behavior moves into scheduler tests using `TickResult` directly.
- `Pyxis/Resources/Audio/Gameplay/fortified-warning.caf` — no current production producer.

### Files with responsibility changes

- `Pyxis/GameplayFeedback.swift` — shrink to six reachable discrete events, direct `TickResult` automatic entry point, no automatic payload types.
- `Pyxis/AutomaticCombatFeedbackScheduler.swift` — derive candidates directly from `TickResult` and return one `GameplaySoundID`.
- `Pyxis/DefaultGameplayFeedbackCoordinator.swift` — inline discrete mapping and keep separate sound/haptic cooldown timestamps.
- `Pyxis/GameplayOutputProtocols.swift` — remove directive/gate types and change sound playback to `play(_ sound:)`.
- `Pyxis/GameplaySoundOutputController.swift` — resolve `GameplaySoundClass` from its catalog.
- `Pyxis/FeedbackPreferences.swift` — two-field value snapshot only; no Codable contract.
- `Pyxis/FeedbackPreferencesStore.swift` — direct Boolean keys and simple observer registry.
- `Pyxis/FeedbackSettingsController.swift` — read `current` on open and apply setter-returned snapshots; no observation token.
- `Pyxis/BattleScene.swift` — pass one authoritative `TickResult` directly to feedback.
- `Pyxis/GameplaySoundCatalog.swift` — remove fortified warning and remain class authority.
- `docs/audio-assets.md` — remove fortified-warning manifest row.
- `CLAUDE.md` — replace HPA-364/HPA-389 architecture mandates with stable product rules.

### Tests to reshape

- `PyxisTests/AutomaticCombatFeedbackSchedulerTests.swift`
- `PyxisTests/DefaultGameplayFeedbackCoordinatorTests.swift`
- `PyxisTests/FeedbackPreferencesStoreTests.swift`
- `PyxisTests/FeedbackPreferencesTests.swift`
- `PyxisTests/FeedbackSettingsControllerTests.swift`
- `PyxisTests/GameplayFeedbackTestDoubles.swift`
- `PyxisTests/GameplayFeedbackTests.swift`
- `PyxisTests/GameplaySoundCatalogTests.swift`
- `PyxisTests/GameplaySoundOutputControllerTests.swift`
- `PyxisTests/GameViewControllerTests.swift`
- representative scene tests if their recording-provider signature changes.

---

### Task 1: Characterize the behavior that must survive deletion

**Files:**
- Modify: `PyxisTests/DefaultGameplayFeedbackCoordinatorTests.swift`
- Modify: `PyxisTests/AutomaticCombatFeedbackSchedulerTests.swift`
- Modify: `PyxisTests/FeedbackSettingsControllerTests.swift`
- Modify: `PyxisTests/GameViewControllerTests.swift`

**Interfaces:**
- Consumes: current production feedback interfaces before refactoring.
- Produces: behavior-level regression tests that remain valid after policy/projector/preferences internals are deleted.

- [ ] **Step 1: Add one table-driven discrete behavior test**

Add a coordinator test that asserts output behavior rather than `GameplayFeedbackDirective` shape. Keep the existing detailed cooldown tests; this table locks the basic mapping before `GameplayFeedbackPolicyTests` is deleted.

```swift
@Test func reachableDiscreteEventsEmitTheCurrentSoundAndHapticBehavior() {
    struct Case {
        let event: GameplayFeedbackEvent
        let expectedSound: GameplaySoundID
        let expectedHaptic: GameplayHapticKind?
    }

    let cases: [Case] = [
        .init(event: .manualDeployment, expectedSound: .deployment, expectedHaptic: .lightImpact),
        .init(event: .buildingChanged, expectedSound: .construction, expectedHaptic: .mediumImpact),
        .init(event: .invalidAction, expectedSound: .blocked, expectedHaptic: .warning),
        .init(event: .goldReward, expectedSound: .goldReward, expectedHaptic: nil),
        .init(event: .cityConquest, expectedSound: .cityConquest, expectedHaptic: .strongSuccess),
        .init(event: .countryCompletion, expectedSound: .countryCompletion, expectedHaptic: .strongSuccess)
    ]

    for testCase in cases {
        let sound = RecordingGameplaySoundOutput()
        let haptics = RecordingGameplayHapticOutput()
        let coordinator = makeCoordinator(
            preferences: RecordingFeedbackPreferencesManager(),
            sound: sound,
            haptics: haptics,
            clock: AdjustableMonotonicClock(now: 0)
        )

        coordinator.emit(testCase.event)

        #expect(sound.playedSoundIDs == [testCase.expectedSound])
        #expect(haptics.played == testCase.expectedHaptic.map { [$0] } ?? [])
    }
}
```

If `RecordingGameplaySoundOutput` does not yet expose `playedSoundIDs`, add a computed projection over its current `.play` calls instead of changing production code in this task.

- [ ] **Step 2: Add a dense automatic behavior fixture built from `TickResult`**

In `AutomaticCombatFeedbackSchedulerTests`, add a reusable fixture that represents the same current dense automatic candidates:

```swift
private func denseTickResult() -> BattleCombatState.TickResult {
    var result = BattleCombatState.TickResult()
    result.soldierLosses = [
        SoldierLossEvent(
            soldierID: 90,
            type: .infantry,
            source: .manual,
            lane: .left
        )
    ]
    result.towerShots = [
        BattleCombatState.TowerShot(soldierID: 90, damage: 3)
    ]
    result.soldierAttacks = [
        SoldierAttackEvent(
            soldierID: 1,
            type: .siege,
            source: .manual,
            lane: .left,
            appliedCityDamage: 2
        ),
        SoldierAttackEvent(
            soldierID: 2,
            type: .archer,
            source: .building,
            lane: .center,
            appliedCityDamage: 2
        ),
        SoldierAttackEvent(
            soldierID: 3,
            type: .infantry,
            source: .manual,
            lane: .right,
            appliedCityDamage: 2
        )
    ]
    result.damagedSoldierIDs = [90, 91]
    return result
}
```

Do not change the scheduler signature yet. This fixture is preparation for Task 2 and should coexist temporarily with the existing event-array tests.

- [ ] **Step 3: Keep explicit immediate-disable coverage**

Ensure `DefaultGameplayFeedbackCoordinatorTests` still has a behavior test equivalent to:

```swift
coordinator.emit(.goldReward)
_ = preferences.setSoundEffectsEnabled(false)

#expect(sound.calls.contains(.stopAllAndDeactivate))
```

Do not test observer count/cancellation shape here; that is implementation detail and will be deleted later.

- [ ] **Step 4: Keep settings persistence across scene replacement covered**

Retain `GameViewControllerTests.controllerKeepsFeedbackPreferencesAcrossSceneReplacement` or the equivalent existing scene-flow test. The assertion should remain about the toggle value visible in the next scene, not about observer identity.

- [ ] **Step 5: Run focused behavior tests**

Run:

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/DefaultGameplayFeedbackCoordinatorTests \
  -only-testing:PyxisTests/AutomaticCombatFeedbackSchedulerTests \
  -only-testing:PyxisTests/FeedbackSettingsControllerTests \
  -only-testing:PyxisTests/GameViewControllerTests
```

Expected: PASS on `main` behavior before production deletion begins.

- [ ] **Step 6: Commit**

```bash
git add \
  PyxisTests/DefaultGameplayFeedbackCoordinatorTests.swift \
  PyxisTests/AutomaticCombatFeedbackSchedulerTests.swift \
  PyxisTests/FeedbackSettingsControllerTests.swift \
  PyxisTests/GameViewControllerTests.swift
git commit -m "test: lock gameplay feedback behavior"
```

---

### Task 2: Collapse `TickResult` projection into the automatic scheduler

**Files:**
- Modify: `Pyxis/GameplayFeedback.swift`
- Modify: `Pyxis/AutomaticCombatFeedbackScheduler.swift`
- Modify: `Pyxis/DefaultGameplayFeedbackCoordinator.swift`
- Modify: `Pyxis/BattleScene.swift`
- Modify: `PyxisTests/AutomaticCombatFeedbackSchedulerTests.swift`
- Modify: `PyxisTests/DefaultGameplayFeedbackCoordinatorTests.swift`
- Modify: `PyxisTests/GameplayFeedbackTestDoubles.swift`
- Modify: `PyxisTests/GameplayFeedbackTests.swift`
- Modify: representative scene/runtime tests with recording automatic batches
- Delete: `Pyxis/CombatFeedbackProjector.swift`
- Delete: `PyxisTests/CombatFeedbackProjectorTests.swift`

**Interfaces:**
- Consumes: `BattleCombatState.TickResult`, `GameplaySoundID`, `MonotonicClock`.
- Produces:
  - `GameplayFeedbackProviding.emitAutomaticCombat(_ result: BattleCombatState.TickResult)`
  - `AutomaticCombatFeedbackScheduler.selectSound(from:at:) -> GameplaySoundID?`

- [ ] **Step 1: Change the scene-facing automatic signature and let tests fail**

In `GameplayFeedback.swift`:

```swift
protocol GameplayFeedbackProviding: AnyObject {
    func emit(_ event: GameplayFeedbackEvent)
    func emitAutomaticCombat(_ result: BattleCombatState.TickResult)
}

final class NoOpGameplayFeedbackProvider: GameplayFeedbackProviding {
    func emit(_ event: GameplayFeedbackEvent) {}
    func emitAutomaticCombat(_ result: BattleCombatState.TickResult) {}
}
```

Update the test recorder to store `TickResult` calls only if an existing scene test needs to assert call count. Prefer a call counter over requiring `TickResult: Equatable`:

```swift
private(set) var automaticCombatCallCount = 0

func emitAutomaticCombat(_ result: BattleCombatState.TickResult) {
    automaticCombatCallCount += 1
}
```

- [ ] **Step 2: Run a focused compile/test to verify the signature change exposes callers**

Run:

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/AutomaticCombatFeedbackSchedulerTests
```

Expected: FAIL to compile at old event-array callers until the following steps are complete.

- [ ] **Step 3: Change the scheduler to return concrete sound IDs from `TickResult`**

Replace the event-array input with:

```swift
mutating func selectSound(
    from result: BattleCombatState.TickResult,
    at now: TimeInterval
) -> GameplaySoundID?
```

Use the existing timing/fairness state. Replace automatic semantic-event gates with sound IDs.

Recommended private constants:

```swift
private static let globalInterval: TimeInterval = 0.150
private static let attackOrder: [GameplaySoundID] = [
    .attackSiege,
    .attackRanged,
    .attackMelee
]
```

Build candidates directly from the tick in this exact order:

```swift
private func candidates(from result: BattleCombatState.TickResult) -> [GameplaySoundID] {
    let killed = Set(result.soldierLosses.map(\.soldierID))
    let hasNonfatalHit = result.damagedSoldierIDs.contains { !killed.contains($0) }
    let attackSounds = Set(result.soldierAttacks.map { attackSound(for: $0.type) })

    var sounds: [GameplaySoundID] = []
    if !result.soldierLosses.isEmpty { sounds.append(.soldierDeath) }
    if !result.towerShots.isEmpty { sounds.append(.towerFire) }
    if attackSounds.contains(.attackSiege) { sounds.append(.attackSiege) }
    if attackSounds.contains(.attackRanged) { sounds.append(.attackRanged) }
    if attackSounds.contains(.attackMelee) { sounds.append(.attackMelee) }
    if hasNonfatalHit { sounds.append(.soldierHit) }
    return sounds
}
```

Map soldier types directly:

```swift
private func attackSound(for type: SoldierType) -> GameplaySoundID {
    switch type {
    case .infantry, .cavalry:
        .attackMelee
    case .archer, .mage:
        .attackRanged
    case .siege:
        .attackSiege
    }
}
```

Keep category intervals without a replacement public gate type. A private helper is enough:

```swift
private func interval(for sound: GameplaySoundID) -> TimeInterval? {
    switch sound {
    case .attackMelee, .attackRanged, .attackSiege:
        0.200
    case .towerFire:
        0.250
    case .soldierHit, .soldierDeath:
        0.300
    default:
        nil
    }
}
```

Use one timestamp dictionary for automatic sounds, except hit/death must share one stored timestamp. Implement that shared family explicitly with a private `lastHitOrDeathAt` rather than a generic gate abstraction.

- [ ] **Step 4: Change coordinator automatic flow**

In `DefaultGameplayFeedbackCoordinator`:

```swift
func emitAutomaticCombat(_ result: BattleCombatState.TickResult) {
    guard currentPreferences.soundEffectsEnabled,
          let sound = automaticCombatScheduler.selectSound(
              from: result,
              at: clock.now
          )
    else {
        return
    }

    soundOutput.play(sound, soundClass: .automaticCombat)
}
```

This task still uses the old sound-output signature. Removing `soundClass` is Task 3.

- [ ] **Step 5: Change the single BattleScene call**

Replace:

```swift
feedback.emitAutomaticCombat(CombatFeedbackProjector.events(from: result))
```

with:

```swift
feedback.emitAutomaticCombat(result)
```

Do not otherwise refactor `advanceCombat`.

- [ ] **Step 6: Rewrite scheduler tests around `TickResult`**

Convert every existing timing/fairness case from `[GameplayFeedbackEvent]` to minimal `TickResult` fixtures.

Examples:

```swift
@Test func opensGlobalGateAtTheExact150MillisecondBoundary() {
    var scheduler = AutomaticCombatFeedbackScheduler()

    #expect(scheduler.selectSound(from: towerTick(), at: 0.000) == .towerFire)
    #expect(scheduler.selectSound(from: siegeTick(), at: 0.149) == nil)
    #expect(scheduler.selectSound(from: siegeTick(), at: 0.150) == .attackSiege)
}
```

and dense fairness:

```swift
#expect(scheduler.selectSound(from: dense, at: 0.000) == .soldierDeath)
#expect(scheduler.selectSound(from: dense, at: 0.150) == .towerFire)
#expect(scheduler.selectSound(from: dense, at: 0.300) == .attackSiege)
#expect(scheduler.selectSound(from: dense, at: 0.450) == .soldierDeath)
#expect(scheduler.selectSound(from: dense, at: 0.600) == .towerFire)
#expect(scheduler.selectSound(from: dense, at: 0.750) == .attackRanged)
#expect(scheduler.selectSound(from: dense, at: 1.200) == .attackMelee)
```

Keep explicit tests for:

- duplicate attack types coalescing;
- Infantry/Cavalry -> melee;
- Archer/Mage -> ranged;
- Siege -> siege;
- fatal damaged soldiers excluded from hit;
- empty `TickResult` producing no sound.

- [ ] **Step 7: Delete projector files**

```bash
git rm \
  Pyxis/CombatFeedbackProjector.swift \
  PyxisTests/CombatFeedbackProjectorTests.swift
```

- [ ] **Step 8: Run automatic/coordinator/scene tests**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/AutomaticCombatFeedbackSchedulerTests \
  -only-testing:PyxisTests/DefaultGameplayFeedbackCoordinatorTests \
  -only-testing:PyxisTests/BattleSceneTests \
  -only-testing:PyxisTests/GameViewControllerTests
```

Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add Pyxis PyxisTests
git commit -m "refactor: collapse automatic combat feedback pipeline"
```

---

### Task 3: Inline discrete feedback mapping and make the catalog own sound class

**Files:**
- Modify: `Pyxis/DefaultGameplayFeedbackCoordinator.swift`
- Modify: `Pyxis/GameplayOutputProtocols.swift`
- Modify: `Pyxis/GameplaySoundOutputController.swift`
- Modify: `Pyxis/GameplaySoundCatalog.swift`
- Modify: `PyxisTests/DefaultGameplayFeedbackCoordinatorTests.swift`
- Modify: `PyxisTests/GameplayFeedbackTestDoubles.swift`
- Modify: `PyxisTests/GameplaySoundCatalogTests.swift`
- Modify: `PyxisTests/GameplaySoundOutputControllerTests.swift`
- Modify: `PyxisTests/GameViewControllerTests.swift`
- Delete: `Pyxis/GameplayFeedbackPolicy.swift`
- Delete: `PyxisTests/GameplayFeedbackPolicyTests.swift`

**Interfaces:**
- Consumes: six discrete `GameplayFeedbackEvent` cases, catalog resources, preferences, monotonic clock.
- Produces:
  - `GameplaySoundOutput.play(_ sound: GameplaySoundID)`
  - direct coordinator mapping with independent sound/haptic cooldowns.

- [ ] **Step 1: Delete directive and gate transport types**

From `GameplayOutputProtocols.swift`, remove:

```swift
GameplayGateID
GameplayFeedbackDirective
```

Change:

```swift
func play(_ sound: GameplaySoundID, soundClass: GameplaySoundClass)
```

to:

```swift
func play(_ sound: GameplaySoundID)
```

Keep `GameplaySoundClass` because `GameplaySoundCatalog` and `GameplaySoundOutputController` still use it internally for voice allocation.

- [ ] **Step 2: Inline the six-event mapping in the coordinator**

Replace `GameplayFeedbackPolicy.directive(for:)` with one switch:

```swift
func emit(_ event: GameplayFeedbackEvent) {
    switch event {
    case .manualDeployment:
        emitSound(.deployment, for: event, interval: 0.120)
        emitHaptic(.lightImpact, for: event, interval: 0.120)

    case .buildingChanged:
        emitSound(.construction, for: event, interval: 0.250)
        emitHaptic(.mediumImpact, for: event, interval: 0.250)

    case .invalidAction:
        emitSound(.blocked, for: event, interval: 0.500)
        emitHaptic(.warning, for: event, interval: 0.500)

    case .goldReward:
        emitSound(.goldReward)

    case .cityConquest:
        emitSound(.cityConquest)
        emitHaptic(.strongSuccess)

    case .countryCompletion:
        emitSound(.countryCompletion)
        emitHaptic(.strongSuccess)
    }
}
```

Replace `lastDiscreteOutputAt: [GameplayGateID: TimeInterval]` with:

```swift
private var lastSoundAt: [GameplayFeedbackEvent: TimeInterval] = [:]
private var lastHapticAt: [GameplayFeedbackEvent: TimeInterval] = [:]
```

Use separate helpers so disabled sound cannot consume haptic cooldown and vice versa:

```swift
private func emitSound(
    _ sound: GameplaySoundID,
    for event: GameplayFeedbackEvent? = nil,
    interval: TimeInterval? = nil
) {
    guard currentPreferences.soundEffectsEnabled else { return }

    if let event, let interval {
        let now = clock.now
        guard isOpen(lastSoundAt[event], interval: interval, at: now) else { return }
        lastSoundAt[event] = now
    }

    soundOutput.play(sound)
}
```

Mirror this for haptics with `lastHapticAt`.

- [ ] **Step 3: Make automatic coordinator playback use only the sound ID**

Task 2's automatic flow becomes:

```swift
func emitAutomaticCombat(_ result: BattleCombatState.TickResult) {
    guard currentPreferences.soundEffectsEnabled,
          let sound = automaticCombatScheduler.selectSound(
              from: result,
              at: clock.now
          )
    else {
        return
    }

    soundOutput.play(sound)
}
```

- [ ] **Step 4: Resolve sound class in `GameplaySoundOutputController`**

Change public play:

```swift
func play(_ sound: GameplaySoundID) {
    outputQueue.async { [weak self] in
        self?.playReadySound(sound)
    }
}
```

Change the private method to look up the resource/class:

```swift
private func playReadySound(_ soundID: GameplaySoundID) {
    guard isOutputEligible else { return }

    guard let resource = catalog[soundID] else {
        assertionFailure("Missing gameplay sound catalog entry for \(soundID)")
        return
    }

    guard case .ready = preparationState,
          let preparedSound = preparedSounds[soundID]
    else {
        beginPreparationIfNeeded()
        return
    }

    // existing activation logic...
    guard let voiceIndex = selectVoiceIndex(for: resource.soundClass) else {
        return
    }

    // existing scheduling logic; record resource.soundClass in the slot
}
```

Do not change voice ranges, preemption, queues, or lifecycle state.

- [ ] **Step 5: Simplify test doubles and expected calls**

`RecordingGameplaySoundOutput` becomes:

```swift
final class RecordingGameplaySoundOutput: GameplaySoundOutput {
    enum Call: Equatable {
        case prepareIfNeeded
        case play(GameplaySoundID)
        case stopAllAndDeactivate
    }

    // ...

    func play(_ sound: GameplaySoundID) {
        calls.append(.play(sound))
    }
}
```

Update expected call arrays mechanically.

- [ ] **Step 6: Delete the policy and its structure tests**

```bash
git rm \
  Pyxis/GameplayFeedbackPolicy.swift \
  PyxisTests/GameplayFeedbackPolicyTests.swift
```

In `GameplaySoundCatalogTests`, delete `policyDirectiveSoundClassesMatchCatalogEntries()`. Keep catalog completeness, bundle, duration, and license evidence tests.

- [ ] **Step 7: Run focused output tests**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/DefaultGameplayFeedbackCoordinatorTests \
  -only-testing:PyxisTests/GameplaySoundCatalogTests \
  -only-testing:PyxisTests/GameplaySoundOutputControllerTests \
  -only-testing:PyxisTests/GameViewControllerTests
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add Pyxis PyxisTests
git commit -m "refactor: inline discrete feedback mapping"
```

---

### Task 4: Simplify feedback preferences to two direct Boolean keys

**Files:**
- Modify: `Pyxis/FeedbackPreferences.swift`
- Modify: `Pyxis/FeedbackPreferencesStore.swift`
- Modify: `Pyxis/FeedbackSettingsController.swift`
- Modify: `PyxisTests/FeedbackPreferencesStoreTests.swift`
- Modify: `PyxisTests/FeedbackPreferencesTests.swift`
- Modify: `PyxisTests/FeedbackSettingsControllerTests.swift`
- Modify: `PyxisTests/GameplayFeedbackTestDoubles.swift`
- Modify: `PyxisTests/DefaultGameplayFeedbackCoordinatorTests.swift`
- Modify: `PyxisTests/GameViewControllerTests.swift`

**Interfaces:**
- Consumes: two UI toggles and one coordinator observation.
- Produces: `FeedbackPreferencesManaging` with `current`, two setters, and simple synchronous cancellable observation.

- [ ] **Step 1: Shrink `FeedbackPreferences` to a value snapshot**

Remove `Codable`, custom `CodingKeys`, and `init(from:)`.

Keep:

```swift
struct FeedbackPreferences: Equatable, Sendable {
    static let defaultValue = FeedbackPreferences()

    var soundEffectsEnabled: Bool
    var hapticsEnabled: Bool

    init(
        soundEffectsEnabled: Bool = true,
        hapticsEnabled: Bool = true
    ) {
        self.soundEffectsEnabled = soundEffectsEnabled
        self.hapticsEnabled = hapticsEnabled
    }
}
```

Keep the existing manager protocol surface for now so scene/runtime injection does not churn.

- [ ] **Step 2: Replace JSON storage with two Boolean keys**

In `FeedbackPreferencesStore` use:

```swift
@MainActor
final class FeedbackPreferencesStore: FeedbackPreferencesManaging {
    static let shared = FeedbackPreferencesStore(defaults: .standard)

    private static let soundKey = "pyxis.feedback.soundEffectsEnabled"
    private static let hapticsKey = "pyxis.feedback.hapticsEnabled"

    private(set) var current: FeedbackPreferences

    private let defaults: UserDefaults
    private var observers: [UUID: (FeedbackPreferences) -> Void] = [:]

    init(defaults: UserDefaults) {
        self.defaults = defaults
        current = FeedbackPreferences(
            soundEffectsEnabled: defaults.object(forKey: Self.soundKey) as? Bool ?? true,
            hapticsEnabled: defaults.object(forKey: Self.hapticsKey) as? Bool ?? true
        )
    }
    // ...
}
```

If test isolation currently relies on custom keys, use a compact key-prefix argument instead of separate arbitrary keys:

```swift
init(
    defaults: UserDefaults,
    keyPrefix: String = "pyxis.feedback"
)
```

and derive:

```swift
"\(keyPrefix).soundEffectsEnabled"
"\(keyPrefix).hapticsEnabled"
```

This keeps tests isolated without recreating a generic persistence abstraction.

Do not read, migrate, decode, or delete `pyxis.feedbackPreferences`.

- [ ] **Step 3: Implement minimal setters and observer delivery**

Setter shape:

```swift
@discardableResult
func setSoundEffectsEnabled(_ enabled: Bool) -> FeedbackPreferences {
    guard current.soundEffectsEnabled != enabled else { return current }

    current.soundEffectsEnabled = enabled
    defaults.set(enabled, forKey: soundKey)
    notifyObservers()
    return current
}
```

Use the equivalent haptic setter.

Observation:

```swift
func observe(
    _ observer: @escaping (FeedbackPreferences) -> Void
) -> FeedbackPreferencesObservation {
    let id = UUID()
    observers[id] = observer
    observer(current)

    return ObservationToken { [weak self] in
        self?.observers.removeValue(forKey: id)
    }
}

private func notifyObservers() {
    let snapshot = current
    for callback in Array(observers.values) {
        callback(snapshot)
    }
}
```

Keep token cancellation idempotent. Do not track versions, observer order, or per-observer delivery generations.

- [ ] **Step 4: Remove settings-controller observation**

Delete:

```swift
private var preferenceObservation: FeedbackPreferencesObservation?
```

and its `observe` registration.

At the start of `open()`:

```swift
preferences = preferencesManager.current
```

Then keep modal rendering from that refreshed snapshot.

Toggle methods become:

```swift
private func toggleSoundEffects() {
    let updated = preferencesManager.setSoundEffectsEnabled(
        !preferences.soundEffectsEnabled
    )
    applyPreferences(updated)
}
```

and equivalent haptics code.

Rename `applyObservedPreferences` to `applyPreferences` because the controller no longer observes.

Delete the test `externallyObservedPreferenceChangesReapplyTheVisibleModal`; it protects behavior with no production caller.

- [ ] **Step 5: Rewrite store tests to the minimal contract**

Replace the current large matrix with these tests only:

```swift
@Test func missingKeysLoadEnabledDefaults()
@Test func settersPersistTheirBooleanAndPreserveSibling()
@Test func unchangedSetterDoesNotNotify()
@Test func observerGetsCurrentThenDistinctUpdatesSynchronously()
@Test func cancellationStopsFutureUpdates()
@Test func isolatedStoreDoesNotTouchCampaignStateOrStandardDefaults()
@Test func persistedValuesRoundTripAcrossStoreRecreation()
```

Delete tests for:

- JSON partial-field tolerance;
- corrupt backups;
- non-keyed roots;
- injected encoding failure;
- encoded object key shape;
- self/cross cancellation ordering;
- nested setter version monotonicity;
- re-entrant registration semantics;
- callback-argument/current divergence;
- duplicate closure registration independence;
- compile-only HPA-389 contract locking.

- [ ] **Step 6: Simplify `RecordingFeedbackPreferencesManager`**

Use the same minimal callback model as production:

```swift
final class RecordingFeedbackPreferencesManager: FeedbackPreferencesManaging {
    private(set) var current: FeedbackPreferences
    private var observers: [UUID: (FeedbackPreferences) -> Void] = [:]

    // setters update current then notify Array(observers.values)
}
```

Do not copy production's old versioned observer implementation into the test double.

- [ ] **Step 7: Keep immediate sound-stop test passing**

`DefaultGameplayFeedbackCoordinator` should retain one observation and `apply(_:)` behavior:

```swift
private func apply(_ updatedPreferences: FeedbackPreferences) {
    let shouldDeactivateSound =
        currentPreferences.soundEffectsEnabled && !updatedPreferences.soundEffectsEnabled

    currentPreferences = updatedPreferences

    if shouldDeactivateSound {
        soundOutput.stopAllAndDeactivate()
    }
}
```

Delete `retainsOnePreferenceObservationAndCancelsItOnDeinit()` if it only freezes observer-count structure. Keep the behavior assertion that disabling sound stops output immediately.

- [ ] **Step 8: Run preference/settings/runtime tests**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/FeedbackPreferencesStoreTests \
  -only-testing:PyxisTests/FeedbackPreferencesTests \
  -only-testing:PyxisTests/FeedbackSettingsControllerTests \
  -only-testing:PyxisTests/DefaultGameplayFeedbackCoordinatorTests \
  -only-testing:PyxisTests/GameViewControllerTests
```

Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add Pyxis PyxisTests
git commit -m "refactor: simplify feedback preferences"
```

---

### Task 5: Delete speculative fortified-warning support and shrink the semantic contract

**Files:**
- Modify: `Pyxis/GameplayFeedback.swift`
- Modify: `Pyxis/GameplayOutputProtocols.swift`
- Modify: `Pyxis/GameplaySoundCatalog.swift`
- Modify: `PyxisTests/GameplayFeedbackTests.swift`
- Modify: `PyxisTests/GameplaySoundCatalogTests.swift`
- Modify: `PyxisTests/GameplaySoundOutputControllerTests.swift` if it enumerates all IDs
- Modify: `docs/audio-assets.md`
- Delete: `Pyxis/Resources/Audio/Gameplay/fortified-warning.caf`

**Interfaces:**
- Consumes: only currently reachable discrete events and current audio assets.
- Produces: six-case `GameplayFeedbackEvent`, catalog without speculative warning support.

- [ ] **Step 1: Shrink `GameplayFeedbackEvent`**

Replace the enum with:

```swift
enum GameplayFeedbackEvent: Hashable {
    case manualDeployment
    case buildingChanged
    case invalidAction
    case goldReward
    case cityConquest
    case countryCompletion
}
```

Delete:

```swift
SoldierAttackSoundCategory
SoldierDamageSoundKind
fortifiedLaneWarning
```

Automatic combat no longer uses semantic feedback events after Task 2.

- [ ] **Step 2: Remove fortified sound ID and resource**

Delete `.fortifiedWarning` from `GameplaySoundID` and `GameplaySoundCatalog.all`.

Delete the asset:

```bash
git rm Pyxis/Resources/Audio/Gameplay/fortified-warning.caf
```

- [ ] **Step 3: Remove the manifest row**

Delete only the `fortified-warning.caf` row from `docs/audio-assets.md`.

Do not remove Kenney/CC0 license files because remaining sounds still use them.

- [ ] **Step 4: Simplify semantic contract tests**

Replace constructibility/count tests with a small behavior-independent set:

```swift
@Test func reachableDiscreteEventsRemainConstructible() {
    let events: Set<GameplayFeedbackEvent> = [
        .manualDeployment,
        .buildingChanged,
        .invalidAction,
        .goldReward,
        .cityConquest,
        .countryCompletion
    ]

    #expect(events.count == 6)
}
```

Delete tests for attack `allCases`, automatic recorder event-array order, and manual test clocks if those behaviors are now directly covered by scheduler tests.

- [ ] **Step 5: Update catalog expectations**

Remove fortified warning from expected resource and manifest-entry dictionaries. Keep:

- one catalog resource for every remaining sound ID;
- bundle presence;
- 750 ms automatic-resource budget;
- manifest/license evidence.

- [ ] **Step 6: Run contract/catalog tests**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/GameplayFeedbackTests \
  -only-testing:PyxisTests/GameplaySoundCatalogTests \
  -only-testing:PyxisTests/GameplaySoundOutputControllerTests
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Pyxis PyxisTests docs/audio-assets.md
git commit -m "chore: delete speculative feedback support"
```

---

### Task 6: Remove historical architecture mandates and verify net deletion

**Files:**
- Modify: `CLAUDE.md`
- Modify: any tests left failing from obsolete internal-contract assumptions
- Do not modify historical HPA-364/HPA-389 specs/plans.

**Interfaces:**
- Consumes: final simplified code from Tasks 2-5.
- Produces: concise stable repository guidance and a fully validated HPA-566 implementation.

- [ ] **Step 1: Replace feedback architecture mandates in `CLAUDE.md`**

Remove guidance that requires:

- strict HPA-364/HPA-389 foundation/consumer ownership;
- ordered automatic semantic batches;
- policy/directive layering;
- versioned re-entrant preference delivery semantics;
- the unreachable fortified warning;
- duplicate sound-class authority.

Replace with concise current rules:

```markdown
- Gameplay feedback is observational only: it must not mutate combat, economy, routing, or campaign state.
- Keep feedback restrained. Automatic combat is coalesced/rate-limited rather than continuous, and suppressed SFX are dropped rather than queued or replayed.
- Honor Sound Effects and Haptics preferences immediately and independently; keep those as the only settings until a concrete player need justifies another option.
- Keep audio readiness, protected-vs-automatic voice behavior, background/interruption cleanup, and stale-output prevention inside the sound output implementation.
- Do not add a feedback policy layer, category, manager, or extension point without a current shipping consumer.
```

Keep the `GameViewController` composition-root description if it remains accurate.

- [ ] **Step 2: Search for deleted symbols**

Run:

```bash
rg -n \
  'GameplayFeedbackPolicy|GameplayFeedbackDirective|GameplayGateID|CombatFeedbackProjector|SoldierAttackSoundCategory|SoldierDamageSoundKind|fortifiedLaneWarning|fortifiedWarning|pyxis\.feedbackPreferences' \
  Pyxis PyxisTests CLAUDE.md docs/audio-assets.md
```

Expected: no production/test/guidance matches. A historical HPA-364/HPA-389 spec/plan may still contain these terms and is intentionally excluded from the search paths above.

- [ ] **Step 3: Verify the old sound playback signature is gone**

Run:

```bash
rg -n 'play\([^\n]*soundClass:' Pyxis PyxisTests
```

Expected: no matches.

- [ ] **Step 4: Run SwiftLint**

```bash
swiftlint lint --no-cache
```

Expected: exit 0; do not expand this task into unrelated warning cleanup.

- [ ] **Step 5: Run the full unit suite**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests
```

Expected: all unit tests pass.

- [ ] **Step 6: Run UI tests if they are part of the current CI gate**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisUITests
```

Expected: all UI tests pass.

- [ ] **Step 7: Verify diff quality and net production deletion**

Run:

```bash
git diff --check origin/main...HEAD

git diff --numstat origin/main...HEAD -- 'Pyxis/*.swift'
```

Sum feedback-related production Swift additions/deletions. Required result: deleted production lines exceed added production lines.

Also inspect:

```bash
git diff --stat origin/main...HEAD
```

Required structural result:

- `GameplayFeedbackPolicy.swift` deleted;
- `CombatFeedbackProjector.swift` deleted;
- their test files deleted;
- fortified warning asset deleted;
- no replacement policy/projector/framework file added.

- [ ] **Step 8: Manual device/simulator smoke**

Record results for:

1. launch with both settings enabled;
2. accepted manual deployment sound + light haptic;
3. invalid action sound + warning haptic;
4. building construction/upgrade feedback;
5. dense automatic combat remains restrained and attack sounds rotate perceptibly;
6. reward then city/country outcome ordering;
7. disable Sound Effects during active output -> immediate silence/deactivation;
8. haptics continue when only sound is disabled;
9. disable Haptics independently;
10. open settings after moving Battle -> Building -> Map and verify values follow the shared store;
11. relaunch and verify both Boolean values persist;
12. background/foreground and audio interruption do not replay stale sounds;
13. settings modal still blocks underlying input and VoiceOver focus remains usable.

- [ ] **Step 9: Commit final guidance/cleanup**

```bash
git add CLAUDE.md Pyxis PyxisTests docs/audio-assets.md
git commit -m "docs: align guidance with simplified feedback architecture"
```

---

## Final self-review checklist

Before opening the implementation PR as ready for review:

- [ ] Every HPA-566 acceptance criterion maps to a completed task above.
- [ ] No `TBD`, `TODO`, compatibility shim, speculative abstraction, or future feedback category was introduced.
- [ ] The scheduler still enforces exact 150/200/250/300 ms boundaries.
- [ ] Disabled sound does not advance automatic scheduler state.
- [ ] Sound/haptic discrete cooldowns remain independent when either channel is disabled/re-enabled.
- [ ] Fatal damage does not also generate hit sound eligibility.
- [ ] `GameplaySoundCatalog` is the only sound-class authority.
- [ ] Sound disable still immediately stops active sound through the coordinator's one simple preference observation.
- [ ] Settings controller has no preference observer and refreshes from `current` on open.
- [ ] Campaign persistence is untouched.
- [ ] Old development preference JSON is not migrated.
- [ ] Fortified-warning code, asset, manifest row, and tests are gone.
- [ ] Historical HPA-364/HPA-389 design records remain unchanged.
- [ ] Audio lifecycle/accessibility complexity was not opportunistically rewritten.
- [ ] Production feedback Swift deletions exceed additions.
- [ ] Full unit tests, applicable UI tests, SwiftLint, and `git diff --check` pass.

## Implementation PR description template

Use this structure when implementation begins:

```markdown
## Summary

Implements HPA-566 as a deletion-first maintenance refactor. Player-visible gameplay feedback is unchanged; internal projection, policy, directive, gate, speculative-warning, duplicated sound-class, and preference-delivery machinery is reduced.

## Deleted

- `GameplayFeedbackPolicy` and `GameplayFeedbackDirective`.
- `GameplayGateID`.
- `CombatFeedbackProjector`.
- Automatic-only semantic feedback payload types.
- Unreachable fortified-lane warning support and asset.
- JSON/corrupt-backup/versioned observer preference machinery.
- Tests that only froze the deleted internal architecture.

## Retained behavior

- Existing discrete SFX/haptic mapping and independent cooldowns.
- 150/200/250/300 ms automatic combat gates and siege/ranged/melee fairness.
- Immediate independent Sound Effects/Haptics toggles across scenes and relaunch.
- Immediate sound stop on disable.
- Async preparation, bounded voice allocation, protected outcome output, activation retry, background/interruption cleanup, and stale-output prevention.
- Existing settings UI/accessibility behavior.

## Intentionally retained complexity

The AVAudioEngine backend, sound-controller queues/state, eight-voice allocation, interruption/lifecycle handling, settings accessibility adapter, and scene layout logic remain because they protect observed runtime behavior rather than speculative architecture.

## Development compatibility

The old `pyxis.feedbackPreferences` JSON object is not migrated. Pre-release development installs may see Sound Effects and Haptics default to enabled once after this change.

## Deletion result

- Production feedback Swift additions: `<count>`
- Production feedback Swift deletions: `<count>`
- Net: `<negative count>` lines

## Validation

- SwiftLint: `<result>`
- PyxisTests: `<result>`
- PyxisUITests: `<result>`
- Manual feedback/lifecycle smoke: `<result>`
```

## Execution handoff

When the HPA-566 start condition is met, use **subagent-driven development** unless there is a reason to keep all tasks inline. Each task above is independently reviewable and ends with focused verification before the next deletion slice begins.
