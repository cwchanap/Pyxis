# Gameplay Feedback Deletion-First Simplification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Issue:** HPA-566  
**Design:** `docs/superpowers/specs/2026-08-06-gameplay-feedback-deletion-first-simplification-design.md`  
**Start condition:** Do not begin implementation solely for cleanup until the HPA-566 Linear start condition is met.  

**Goal:** Delete unnecessary gameplay-feedback projection, policy, directive, gate, duplicated sound-class, speculative-warning, and preference-delivery machinery while preserving current player-visible SFX, haptics, settings, automatic-combat restraint, and interruption-safe playback.

**Architecture:** Keep a small scene-facing semantic API for discrete feedback. Pass `BattleCombatState.TickResult` directly to the automatic scheduler. Inline discrete mapping in `DefaultGameplayFeedbackCoordinator`. Make `GameplaySoundCatalog` the sole sound-class authority. Persist the two settings as direct Boolean `UserDefaults` values with one simple synchronous observer path for the coordinator.

**Tech Stack:** Swift 5, SpriteKit, UIKit, AVFoundation/AVAudioEngine, Swift Testing, UserDefaults, Xcode/xcodebuild, SwiftLint.

## Global Constraints

- Preserve existing player-visible sound, haptic, settings, accessibility, and interruption behavior.
- Add no SFX, haptic event, settings option, audio asset, or gameplay behavior.
- Do not broadly rewrite `BattleScene`.
- Do not add a replacement policy framework, event bus, DI layer, lifecycle abstraction, Combine publisher, Swift Observation model, or generalized feedback registry.
- Do not migrate the pre-release `pyxis.feedbackPreferences` JSON value.
- Keep campaign state under `pyxis.kingdomGameState` untouched.
- Automatic combat stays sound-only and drop-only.
- Preserve automatic gates: 150 ms global, 200 ms attack family, 250 ms tower, shared 300 ms hit/death, siege -> ranged -> melee fairness.
- Preserve discrete cooldowns independently per channel: deployment 120 ms, construction 250 ms, invalid action 500 ms.
- Keep audio backend serialization, async preparation, eight-voice allocation/protection, activation retry, background/interruption handling, and accessibility behavior.
- Production feedback-related Swift lines deleted must exceed lines added.
- Always run tests with parallel testing disabled.

---

## Target File Structure

**Delete:**

- `Pyxis/GameplayFeedbackPolicy.swift`
- `Pyxis/CombatFeedbackProjector.swift`
- `PyxisTests/GameplayFeedbackPolicyTests.swift`
- `PyxisTests/CombatFeedbackProjectorTests.swift`
- `Pyxis/Resources/Audio/Gameplay/fortified-warning.caf`

**Modify materially:**

- `Pyxis/GameplayFeedback.swift`
- `Pyxis/AutomaticCombatFeedbackScheduler.swift`
- `Pyxis/DefaultGameplayFeedbackCoordinator.swift`
- `Pyxis/GameplayOutputProtocols.swift`
- `Pyxis/GameplaySoundCatalog.swift`
- `Pyxis/GameplaySoundOutputController.swift`
- `Pyxis/FeedbackPreferences.swift`
- `Pyxis/FeedbackPreferencesStore.swift`
- `Pyxis/FeedbackSettingsController.swift`
- `Pyxis/BattleScene.swift`
- related behavior tests
- `docs/audio-assets.md`
- `CLAUDE.md`

---

### Task 1: Lock behavior before deleting structure

**Files:**
- Modify: `PyxisTests/DefaultGameplayFeedbackCoordinatorTests.swift`
- Modify: `PyxisTests/AutomaticCombatFeedbackSchedulerTests.swift`
- Verify: `PyxisTests/FeedbackSettingsControllerTests.swift`
- Verify: `PyxisTests/GameViewControllerTests.swift`

**Interfaces:**
- Consumes: current HPA-364/HPA-389 interfaces.
- Produces: behavior-level regression coverage independent of policy/directive/projector shape.

- [ ] **Step 1: Add one discrete mapping behavior test**

Add a table-driven coordinator test for the six reachable discrete events:

```swift
@Test func reachableDiscreteEventsEmitCurrentOutputs() {
    struct Case {
        let event: GameplayFeedbackEvent
        let sound: GameplaySoundID
        let haptic: GameplayHapticKind?
    }

    let cases: [Case] = [
        .init(event: .manualDeployment, sound: .deployment, haptic: .lightImpact),
        .init(event: .buildingChanged, sound: .construction, haptic: .mediumImpact),
        .init(event: .invalidAction, sound: .blocked, haptic: .warning),
        .init(event: .goldReward, sound: .goldReward, haptic: nil),
        .init(event: .cityConquest, sound: .cityConquest, haptic: .strongSuccess),
        .init(event: .countryCompletion, sound: .countryCompletion, haptic: .strongSuccess)
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

        #expect(sound.playedSoundIDs == [testCase.sound])
        #expect(haptics.played == testCase.haptic.map { [$0] } ?? [])
    }
}
```

If needed, implement `playedSoundIDs` as a test-only computed property over existing `.play` calls. Do not change production code in this step.

- [ ] **Step 2: Keep the existing independent cooldown tests**

Retain behavior coverage for:

- deployment sound/haptic 120 ms gates when one channel is disabled/re-enabled;
- construction 250 ms gates;
- invalid-action 500 ms gates;
- outcomes not time-gated;
- disabling sound immediately calling `stopAllAndDeactivate()`.

Delete no tests yet.

- [ ] **Step 3: Add reusable `TickResult` fixtures next to scheduler tests**

Add helpers for tower-only, siege-only, melee-only, ranged-only, hit-only, death-only, and dense ticks. The dense fixture must contain death, tower fire, all three attack families, and one non-fatal damaged soldier.

Representative fixture:

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
        SoldierAttackEvent(soldierID: 1, type: .siege, source: .manual, lane: .left, appliedCityDamage: 2),
        SoldierAttackEvent(soldierID: 2, type: .archer, source: .building, lane: .center, appliedCityDamage: 2),
        SoldierAttackEvent(soldierID: 3, type: .infantry, source: .manual, lane: .right, appliedCityDamage: 2)
    ]
    result.damagedSoldierIDs = [90, 91]
    return result
}
```

Do not change the scheduler input yet.

- [ ] **Step 4: Run focused tests**

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

Expected: PASS before production deletion begins.

- [ ] **Step 5: Commit**

```bash
git add \
  PyxisTests/DefaultGameplayFeedbackCoordinatorTests.swift \
  PyxisTests/AutomaticCombatFeedbackSchedulerTests.swift
git commit -m "test: lock gameplay feedback behavior"
```

---

### Task 2: Collapse automatic combat projection into the scheduler

**Files:**
- Modify: `Pyxis/GameplayFeedback.swift`
- Modify: `Pyxis/AutomaticCombatFeedbackScheduler.swift`
- Modify: `Pyxis/DefaultGameplayFeedbackCoordinator.swift`
- Modify: `Pyxis/BattleScene.swift`
- Modify: `PyxisTests/AutomaticCombatFeedbackSchedulerTests.swift`
- Modify: `PyxisTests/DefaultGameplayFeedbackCoordinatorTests.swift`
- Modify: `PyxisTests/GameplayFeedbackTestDoubles.swift`
- Modify: `PyxisTests/GameplayFeedbackTests.swift`
- Modify: `PyxisTests/GameViewControllerTests.swift`
- Delete: `Pyxis/CombatFeedbackProjector.swift`
- Delete: `PyxisTests/CombatFeedbackProjectorTests.swift`

**Interfaces:**
- Produces: `GameplayFeedbackProviding.emitAutomaticCombat(_ result: BattleCombatState.TickResult)`.
- Produces: `AutomaticCombatFeedbackScheduler.selectSound(from:at:) -> GameplaySoundID?`.

- [ ] **Step 1: Change the automatic provider signature**

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

Update recording providers to count automatic calls or record only the fields their tests actually inspect. Do not create an automatic-event replacement model.

- [ ] **Step 2: Change the scheduler to consume `TickResult` directly**

Target signature:

```swift
mutating func selectSound(
    from result: BattleCombatState.TickResult,
    at now: TimeInterval
) -> GameplaySoundID?
```

Use this candidate order:

```swift
private func candidates(from result: BattleCombatState.TickResult) -> [GameplaySoundID] {
    let killed = Set(result.soldierLosses.map(\.soldierID))
    let hasNonfatalHit = result.damagedSoldierIDs.contains { !killed.contains($0) }
    let attacks = Set(result.soldierAttacks.map { attackSound(for: $0.type) })

    var sounds: [GameplaySoundID] = []
    if !result.soldierLosses.isEmpty { sounds.append(.soldierDeath) }
    if !result.towerShots.isEmpty { sounds.append(.towerFire) }
    if attacks.contains(.attackSiege) { sounds.append(.attackSiege) }
    if attacks.contains(.attackRanged) { sounds.append(.attackRanged) }
    if attacks.contains(.attackMelee) { sounds.append(.attackMelee) }
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

Use existing state for the global gate and fairness. Replace per-event timestamps with sound IDs. Keep one explicit shared `lastHitOrDeathAt` for `.soldierHit` and `.soldierDeath` rather than creating a new public/private gate type.

Attack rotation is exactly:

```swift
private static let attackOrder: [GameplaySoundID] = [
    .attackSiege,
    .attackRanged,
    .attackMelee
]
```

- [ ] **Step 3: Update coordinator automatic flow**

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

Keep the old sound-output signature until Task 3.

- [ ] **Step 4: Update the single BattleScene call**

Replace:

```swift
feedback.emitAutomaticCombat(CombatFeedbackProjector.events(from: result))
```

with:

```swift
feedback.emitAutomaticCombat(result)
```

Do not otherwise restructure `advanceCombat`.

- [ ] **Step 5: Rewrite scheduler tests around `TickResult`**

Retain exact boundary/fairness behavior. Dense sequence must still include:

```swift
#expect(scheduler.selectSound(from: dense, at: 0.000) == .soldierDeath)
#expect(scheduler.selectSound(from: dense, at: 0.150) == .towerFire)
#expect(scheduler.selectSound(from: dense, at: 0.300) == .attackSiege)
#expect(scheduler.selectSound(from: dense, at: 0.750) == .attackRanged)
#expect(scheduler.selectSound(from: dense, at: 1.200) == .attackMelee)
```

Keep tests for:

- exact 150/200/250/300 ms boundaries;
- Infantry/Cavalry -> melee;
- Archer/Mage -> ranged;
- Siege -> siege;
- duplicate same-family attacks coalescing;
- fatal damaged soldiers not also yielding hit;
- empty tick yielding nil;
- disabled sound not advancing scheduler state at coordinator level.

- [ ] **Step 6: Delete projector files**

```bash
git rm \
  Pyxis/CombatFeedbackProjector.swift \
  PyxisTests/CombatFeedbackProjectorTests.swift
```

- [ ] **Step 7: Run focused tests**

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

- [ ] **Step 8: Commit**

```bash
git add Pyxis PyxisTests
git commit -m "refactor: collapse automatic combat feedback pipeline"
```

---

### Task 3: Delete policy/directive/gates and make the catalog authoritative

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
- Produces: `GameplaySoundOutput.play(_ sound: GameplaySoundID)`.
- Keeps: `GameplaySoundClass` only inside catalog/output voice selection.

- [ ] **Step 1: Remove transport types and simplify sound output**

Delete `GameplayGateID` and `GameplayFeedbackDirective` from `GameplayOutputProtocols.swift`.

Change:

```swift
func play(_ sound: GameplaySoundID, soundClass: GameplaySoundClass)
```

to:

```swift
func play(_ sound: GameplaySoundID)
```

- [ ] **Step 2: Inline the six discrete mappings in the coordinator**

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

Use separate dictionaries so channel cooldowns stay independent:

```swift
private var lastSoundAt: [GameplayFeedbackEvent: TimeInterval] = [:]
private var lastHapticAt: [GameplayFeedbackEvent: TimeInterval] = [:]
```

A helper must only record a timestamp after that channel passes its enabled check.

- [ ] **Step 3: Remove sound class from automatic playback**

Task 2's automatic method becomes:

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

- [ ] **Step 4: Resolve sound class from catalog in `GameplaySoundOutputController`**

Public entry point:

```swift
func play(_ sound: GameplaySoundID) {
    outputQueue.async { [weak self] in
        self?.playReadySound(sound)
    }
}
```

Inside the existing ready-play path, resolve:

```swift
guard let resource = catalog[soundID] else {
    assertionFailure("Missing gameplay sound catalog entry for \(soundID)")
    return
}
```

Use `resource.soundClass` for `selectVoiceIndex(for:)` and the voice slot's `soundClass` value. Do not change any other voice/lifecycle logic.

- [ ] **Step 5: Simplify recording sound output and expectations**

```swift
final class RecordingGameplaySoundOutput: GameplaySoundOutput {
    enum Call: Equatable {
        case prepareIfNeeded
        case play(GameplaySoundID)
        case stopAllAndDeactivate
    }

    private(set) var calls: [Call] = []

    func play(_ sound: GameplaySoundID) {
        calls.append(.play(sound))
    }
}
```

Update expected call arrays mechanically.

- [ ] **Step 6: Delete policy files and duplicate-authority test**

```bash
git rm \
  Pyxis/GameplayFeedbackPolicy.swift \
  PyxisTests/GameplayFeedbackPolicyTests.swift
```

Delete `GameplaySoundCatalogTests.policyDirectiveSoundClassesMatchCatalogEntries()`. Keep catalog completeness, bundle, duration, and license tests.

- [ ] **Step 7: Run focused tests**

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
git commit -m "refactor: inline gameplay feedback policy"
```

---

### Task 4: Replace JSON/versioned preference machinery with two Boolean keys

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
- Produces: a two-field `FeedbackPreferences` value and `FeedbackPreferencesManaging` with one simple synchronous cancellable observer registry.
- Production keys: `pyxis.feedback.soundEffectsEnabled`, `pyxis.feedback.hapticsEnabled`.

- [ ] **Step 1: Remove `Codable` from the preference value**

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

Delete custom decoding and coding keys.

- [ ] **Step 2: Give the store an exact key-prefix interface**

Use this initializer:

```swift
@MainActor
final class FeedbackPreferencesStore: FeedbackPreferencesManaging {
    static let shared = FeedbackPreferencesStore(defaults: .standard)

    private(set) var current: FeedbackPreferences

    private let defaults: UserDefaults
    private let soundKey: String
    private let hapticsKey: String
    private var observers: [UUID: (FeedbackPreferences) -> Void] = [:]

    init(
        defaults: UserDefaults,
        keyPrefix: String = "pyxis.feedback"
    ) {
        self.defaults = defaults
        soundKey = "\(keyPrefix).soundEffectsEnabled"
        hapticsKey = "\(keyPrefix).hapticsEnabled"
        current = FeedbackPreferences(
            soundEffectsEnabled: defaults.object(forKey: soundKey) as? Bool ?? true,
            hapticsEnabled: defaults.object(forKey: hapticsKey) as? Bool ?? true
        )
    }
}
```

Tests use a unique prefix such as `feedback.<UUID>`. Production uses the default prefix.

Do not read, migrate, rewrite, or delete the old `pyxis.feedbackPreferences` JSON key.

- [ ] **Step 3: Implement minimal setters and observation**

Setter:

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

Implement the equivalent haptics setter.

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

Keep token cancellation idempotent. Do not track observer order, versions, or stale-delivery semantics.

- [ ] **Step 4: Remove settings-controller observation**

Delete its observation property and registration.

Refresh at modal open:

```swift
@discardableResult
func open() -> Bool {
    guard let layout, accessibilityAdapter.canPresentSettings else { return false }

    preferences = preferencesManager.current
    isVisible = true
    modal.apply(layout: layout, preferences: preferences)
    accessibilityAdapter.present(layout: layout, preferences: preferences)
    return true
}
```

Apply setter returns directly:

```swift
private func toggleSoundEffects() {
    applyPreferences(
        preferencesManager.setSoundEffectsEnabled(!preferences.soundEffectsEnabled)
    )
}
```

Use the same shape for haptics. Rename `applyObservedPreferences` to `applyPreferences`.

Delete the test that expects unrelated external changes to repaint an already open modal; no production caller requires that behavior.

- [ ] **Step 5: Replace preference store tests with the actual product contract**

Keep exactly these behavior areas:

```swift
@Test func missingKeysLoadEnabledDefaults()
@Test func settersPersistTheirBooleanAndPreserveSibling()
@Test func unchangedSetterDoesNotNotify()
@Test func observerGetsCurrentThenDistinctUpdatesSynchronously()
@Test func cancellationStopsFutureUpdates()
@Test func isolatedStoreDoesNotTouchCampaignStateOrStandardDefaults()
@Test func persistedValuesRoundTripAcrossStoreRecreation()
```

Delete tests for JSON field tolerance, corrupt backups, encoding failure, encoded key shape, observer delivery versions, nested registration, cross-cancellation ordering, callback/current divergence, duplicate registration semantics, and compile-only HPA-389 contract locking.

- [ ] **Step 6: Simplify the recording preference manager**

Use the same small dictionary-of-callbacks model as production. Do not keep a second versioned observer implementation in test code.

- [ ] **Step 7: Retain immediate sound-stop behavior**

The coordinator keeps one store observation and this behavior:

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

Delete tests that assert exact observer counts or token lifetime structure if the same user-visible behavior is already covered.

- [ ] **Step 8: Run focused tests**

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
git commit -m "refactor: simplify gameplay feedback preferences"
```

---

### Task 5: Delete speculative warning and automatic-only semantic types

**Files:**
- Modify: `Pyxis/GameplayFeedback.swift`
- Modify: `Pyxis/GameplayOutputProtocols.swift`
- Modify: `Pyxis/GameplaySoundCatalog.swift`
- Modify: `PyxisTests/GameplayFeedbackTests.swift`
- Modify: `PyxisTests/GameplaySoundCatalogTests.swift`
- Modify: `PyxisTests/GameplaySoundOutputControllerTests.swift`
- Modify: `docs/audio-assets.md`
- Delete: `Pyxis/Resources/Audio/Gameplay/fortified-warning.caf`

**Interfaces:**
- Produces: six-case reachable discrete `GameplayFeedbackEvent`.

- [ ] **Step 1: Shrink the semantic enum**

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

Delete `SoldierAttackSoundCategory` and `SoldierDamageSoundKind`; Task 2 already moved automatic combat to direct `TickResult` scheduling.

- [ ] **Step 2: Remove fortified warning code and asset**

Delete:

- `GameplayFeedbackEvent.fortifiedLaneWarning`;
- `GameplaySoundID.fortifiedWarning`;
- its `GameplaySoundCatalog` entry;
- the `fortified-warning.caf` manifest row.

Then:

```bash
git rm Pyxis/Resources/Audio/Gameplay/fortified-warning.caf
```

Keep shared license files because remaining assets still use them.

- [ ] **Step 3: Simplify semantic/catalog tests**

Use a small semantic contract assertion:

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

Remove fortified warning from expected catalog/manifest data. Keep tests that every remaining sound ID has a resource, every resource is bundled, automatic clips meet the duration budget, and the manifest/license evidence is complete.

- [ ] **Step 4: Run focused tests**

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

- [ ] **Step 5: Commit**

```bash
git add Pyxis PyxisTests docs/audio-assets.md
git commit -m "chore: delete speculative gameplay feedback support"
```

---

### Task 6: Replace historical architecture mandates and verify the whole refactor

**Files:**
- Modify: `CLAUDE.md`
- Modify only mechanically required tests left by deleted interfaces.
- Do not modify historical HPA-364/HPA-389 specs/plans.

**Interfaces:**
- Produces: current repository guidance matching the simplified implementation.

- [ ] **Step 1: Replace feedback-specific architecture mandates in `CLAUDE.md`**

Remove requirements for the old foundation/consumer split, policy/directive structure, automatic semantic batch, versioned preference observation, and fortified warning.

Keep concise stable rules:

```markdown
- Gameplay feedback is observational only: it must not mutate combat, economy, routing, or campaign state.
- Keep feedback restrained. Automatic combat is coalesced/rate-limited rather than continuous, and suppressed SFX are dropped rather than queued or replayed.
- Honor Sound Effects and Haptics preferences immediately and independently; keep those as the only settings until a concrete player need justifies another option.
- Keep audio readiness, protected-vs-automatic voice behavior, background/interruption cleanup, and stale-output prevention inside the sound output implementation.
- Do not add a feedback policy layer, category, manager, or extension point without a current shipping consumer.
```

Leave historical design documents unchanged.

- [ ] **Step 2: Confirm deleted symbols are gone from live code/tests/guidance**

```bash
rg -n \
  'GameplayFeedbackPolicy|GameplayFeedbackDirective|GameplayGateID|CombatFeedbackProjector|SoldierAttackSoundCategory|SoldierDamageSoundKind|fortifiedLaneWarning|fortifiedWarning|pyxis\.feedbackPreferences' \
  Pyxis PyxisTests CLAUDE.md docs/audio-assets.md
```

Expected: no matches.

Historical specs/plans are intentionally excluded.

- [ ] **Step 3: Confirm the duplicated sound-class call is gone**

```bash
rg -n 'play\([^\n]*soundClass:' Pyxis PyxisTests
```

Expected: no matches.

- [ ] **Step 4: Run lint and full tests**

```bash
swiftlint lint --no-cache
```

Expected: exit 0 without unrelated cleanup.

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests
```

Expected: all unit tests pass.

If UI tests remain part of current CI:

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisUITests
```

Expected: all UI tests pass.

- [ ] **Step 5: Verify deletion-first diff quality**

```bash
git diff --check origin/main...HEAD
git diff --stat origin/main...HEAD
git diff --numstat origin/main...HEAD -- 'Pyxis/*.swift'
```

Required result:

- `GameplayFeedbackPolicy.swift` deleted;
- `CombatFeedbackProjector.swift` deleted;
- their test files deleted;
- fortified warning asset deleted;
- no replacement policy/projector/framework file added;
- feedback-related production Swift deletions exceed additions.

- [ ] **Step 6: Manual smoke the preserved behavior**

Verify:

1. accepted manual deployment sound + light haptic;
2. invalid action sound + warning haptic;
3. construction/upgrade feedback;
4. dense combat remains restrained with attack-family variety;
5. reward precedes fresh city/country outcome feedback;
6. disabling Sound Effects during active output immediately stops sound;
7. haptics still work when only sound is disabled;
8. haptics can be disabled independently;
9. settings values follow Battle -> Building -> Map scene replacement;
10. relaunch preserves both Boolean settings;
11. background/foreground and interruption do not replay stale sounds;
12. settings modal still blocks scene input and VoiceOver remains usable.

- [ ] **Step 7: Commit**

```bash
git add CLAUDE.md Pyxis PyxisTests docs/audio-assets.md
git commit -m "docs: align guidance with simplified feedback architecture"
```

---

## Final Self-Review

Before marking the implementation PR ready:

- [ ] All six reachable discrete mappings still match the design.
- [ ] Exact 150/200/250/300 ms automatic boundaries remain tested.
- [ ] Disabled sound does not advance automatic scheduler state.
- [ ] Sound and haptic cooldown state remains independent.
- [ ] Fatal damage does not also create hit-sound eligibility.
- [ ] `GameplaySoundCatalog` is the only sound-class authority.
- [ ] Sound disable still immediately stops active output.
- [ ] Settings controller has no preference observer and refreshes on open.
- [ ] Campaign persistence is untouched.
- [ ] Old feedback JSON is not migrated.
- [ ] Fortified-warning code, asset, manifest row, and tests are gone.
- [ ] Historical HPA-364/HPA-389 docs remain unchanged.
- [ ] Audio lifecycle/accessibility machinery was not opportunistically rewritten.
- [ ] Production feedback Swift deletions exceed additions.
- [ ] SwiftLint, full unit tests, applicable UI tests, manual smoke, and `git diff --check` pass.

## Implementation PR Requirements

The implementation PR description must report, using the actual final diff/test outputs:

- exactly which files/types/assets/tests were deleted;
- which player-visible behaviors were deliberately retained;
- that the old development JSON preference value is intentionally not migrated;
- which audio/accessibility complexity was deliberately retained and why;
- measured feedback-related production Swift additions, deletions, and net line change;
- exact SwiftLint, unit-test, UI-test, and manual-smoke results.

## Execution Handoff

When the HPA-566 start condition is met, use **subagent-driven development** unless there is a concrete reason to execute inline. Each task above is independently reviewable and ends with focused verification before the next deletion slice begins.
