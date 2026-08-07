# Gameplay Feedback Deletion-First Simplification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Issue:** HPA-566  
**Design:** `docs/superpowers/specs/2026-08-06-gameplay-feedback-deletion-first-simplification-design.md`  
**Start condition:** Do not begin implementation solely for cleanup until the HPA-566 Linear start condition is met.

**Goal:** Delete unnecessary gameplay-feedback projection, policy, directive, generic gate, duplicated sound-class, speculative-warning, and preference-delivery machinery while preserving current player-visible SFX, haptics, settings, automatic-combat restraint, accessibility, and interruption-safe playback.

**Architecture:** Keep six scene-facing discrete semantic events. Pass `BattleCombatState.TickResult` directly to `AutomaticCombatFeedbackScheduler`, which projects/coalesces the tick and returns at most one `GameplaySoundID`. Inline discrete mapping in `DefaultGameplayFeedbackCoordinator`. Make `GameplaySoundCatalog` the sole sound-class authority. Persist two settings as Boolean `UserDefaults` values with a small synchronous cancellable observer registry used by the coordinator.

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
- `docs/audio-assets.md`
- `CLAUDE.md`

## Risks and rollback

The primary risk is a **player-audible automatic-combat regression** in Task 2. Exact scheduler tests protect timing, fairness, and priority, but they cannot prove the resulting pacing still sounds restrained and varied. Task 3 can silently regress discrete SFX/haptic mapping or automatic/protected voice classification. Task 4 can regress immediate preference application/persistence.

Each task is a separate commit. Run the task-local focused tests and smoke before committing the next slice. If a task-local check fails, stop and revert/fix that task before continuing; do not carry a known audio/settings regression across later commits and rely on the final smoke to locate it.

---

### Task 1: Lock player-visible behavior before deleting structure

**Files:**
- Modify: `PyxisTests/DefaultGameplayFeedbackCoordinatorTests.swift`
- Modify: `PyxisTests/AutomaticCombatFeedbackSchedulerTests.swift`
- Verify: `PyxisTests/FeedbackSettingsControllerTests.swift`
- Verify: `PyxisTests/GameViewControllerTests.swift`

**Interfaces:**
- Consumes: current HPA-364/HPA-389 interfaces.
- Produces: behavior-level regression coverage that does not depend on policy/directive/projector shape.

- [ ] **Step 1: Add a permanent table-driven discrete mapping test**

Add this test to `DefaultGameplayFeedbackCoordinatorTests`:

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

        #expect(sound.calls == [.play(testCase.sound, .nonAutomatic)])
        #expect(haptics.played == testCase.haptic.map { [$0] } ?? [])
    }
}
```

This test is permanent. Later tasks update only the sound-call shape after `GameplaySoundOutput` loses the redundant class parameter.

- [ ] **Step 2: Keep independent channel cooldown behavior tests**

Retain the existing assertions for:

- deployment sound/haptic 120 ms gates when one channel is disabled/re-enabled;
- construction 250 ms gates;
- invalid-action 500 ms gates;
- outcomes not time-gated;
- disabling sound immediately calling `stopAllAndDeactivate()`.

Do not replace these with internal gate-ID tests.

- [ ] **Step 3: Add reusable `TickResult` fixtures beside scheduler tests**

Add helpers for tower-only, siege-only, ranged-only, melee-only, hit-only, death-only, attack-free, and dense ticks.

The dense fixture must contain:

- at least one death;
- at least one tower shot;
- siege, ranged, and melee attacks;
- one surviving damaged soldier so `.soldierHit` is eligible independently of the fatal soldier.

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

Do not change scheduler production input in this task.

- [ ] **Step 4: Run focused tests before any deletion**

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

Expected: PASS.

- [ ] **Step 5: Commit the characterization tests**

```bash
git add \
  PyxisTests/DefaultGameplayFeedbackCoordinatorTests.swift \
  PyxisTests/AutomaticCombatFeedbackSchedulerTests.swift
git commit -m "test: lock gameplay feedback behavior"
```

---

### Task 2: Collapse automatic combat projection and shrink the semantic contract atomically

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
- Consumes: `BattleCombatState.TickResult`.
- Produces: `GameplayFeedbackProviding.emitAutomaticCombat(_ result: BattleCombatState.TickResult)`.
- Produces: six-case discrete `GameplayFeedbackEvent`.
- Produces: `AutomaticCombatFeedbackScheduler.selectSound(from:at:) -> GameplaySoundID?`.

- [ ] **Step 1: Change the provider automatic signature and shrink `GameplayFeedbackEvent` in the same edit**

Replace the semantic contract with:

```swift
enum GameplayFeedbackEvent: Hashable {
    case manualDeployment
    case buildingChanged
    case invalidAction
    case goldReward
    case cityConquest
    case countryCompletion
}

protocol GameplayFeedbackProviding: AnyObject {
    func emit(_ event: GameplayFeedbackEvent)
    func emitAutomaticCombat(_ result: BattleCombatState.TickResult)
}

final class NoOpGameplayFeedbackProvider: GameplayFeedbackProviding {
    func emit(_ event: GameplayFeedbackEvent) {}
    func emitAutomaticCombat(_ result: BattleCombatState.TickResult) {}
}
```

Delete from `GameplayFeedback.swift` in this step:

- `.soldierAttack`;
- `.towerFire`;
- `.soldierDamage`;
- `.fortifiedLaneWarning`;
- `SoldierAttackSoundCategory`;
- `SoldierDamageSoundKind`.

This ordering is required so Task 3 can use an exhaustive six-case switch without adding a catch-all `default`.

It also turns an existing runtime-rejected state into an unrepresentable one: after this edit, `emit(_:)` cannot receive an automatic-combat semantic case at all. Do not preserve or recreate the old `directive.soundClass != .automaticCombat` guard.

Update recording providers so automatic calls accept `TickResult`. Record only what existing scene/runtime tests need, such as call count, rather than creating a replacement automatic event model.

- [ ] **Step 2: Move projector coalescing into `AutomaticCombatFeedbackScheduler`**

Change the scheduler API to:

```swift
mutating func selectSound(
    from result: BattleCombatState.TickResult,
    at now: TimeInterval
) -> GameplaySoundID?
```

Derive candidates in this exact order:

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

Map attack sounds directly:

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

- [ ] **Step 3: Retain the scheduler's private gate family representation**

Keep a private enum shaped like the existing scheduler:

```swift
private enum Gate {
    case melee
    case ranged
    case siege
    case tower
    case hitDeath

    var interval: TimeInterval {
        switch self {
        case .melee, .ranged, .siege:
            0.200
        case .tower:
            0.250
        case .hitDeath:
            0.300
        }
    }
}
```

Map sound IDs to gates:

```swift
private func gate(for sound: GameplaySoundID) -> Gate? {
    switch sound {
    case .attackMelee: .melee
    case .attackRanged: .ranged
    case .attackSiege: .siege
    case .towerFire: .tower
    case .soldierHit, .soldierDeath: .hitDeath
    default: nil
    }
}
```

Retain one timestamp per private gate family. Do not key shared hit/death gating directly by sound ID, and do not create a public/general gate type.

Attack fairness rotates concrete sounds:

```swift
private static let attackOrder: [GameplaySoundID] = [
    .attackSiege,
    .attackRanged,
    .attackMelee
]
```

- [ ] **Step 4: Update coordinator and BattleScene automatic flow**

Coordinator:

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

In `BattleScene`, replace:

```swift
feedback.emitAutomaticCombat(CombatFeedbackProjector.events(from: result))
```

with:

```swift
feedback.emitAutomaticCombat(result)
```

Do not otherwise restructure `advanceCombat`.

- [ ] **Step 5: Port the complete fairness and priority contracts to `TickResult` tests**

Keep every checkpoint from the current dense fairness test:

```swift
@Test func reservesEveryThirdEligibleWindowAndRotatesAttackSounds() {
    let dense = denseTickResult()
    var scheduler = AutomaticCombatFeedbackScheduler()

    #expect(scheduler.selectSound(from: dense, at: 0.000) == .soldierDeath)
    #expect(scheduler.selectSound(from: dense, at: 0.150) == .towerFire)
    #expect(scheduler.selectSound(from: dense, at: 0.300) == .attackSiege)
    #expect(scheduler.selectSound(from: dense, at: 0.450) == .soldierDeath)
    #expect(scheduler.selectSound(from: dense, at: 0.600) == .towerFire)
    #expect(scheduler.selectSound(from: dense, at: 0.750) == .attackRanged)
    #expect(scheduler.selectSound(from: dense, at: 0.900) == .soldierDeath)
    #expect(scheduler.selectSound(from: dense, at: 1.050) == .towerFire)
    #expect(scheduler.selectSound(from: dense, at: 1.200) == .attackMelee)
}
```

Add a fresh-scheduler adjacent-priority test to replace the deleted projector's ordered-array assertion:

```swift
@Test func candidatePriorityRemainsDeathTowerSiegeRangedMeleeHit() {
    #expect(firstSound(from: priorityTick(death: true, tower: true)) == .soldierDeath)
    #expect(firstSound(from: priorityTick(tower: true, attacks: [.siege])) == .towerFire)
    #expect(firstSound(from: priorityTick(attacks: [.siege, .archer])) == .attackSiege)
    #expect(firstSound(from: priorityTick(attacks: [.archer, .infantry])) == .attackRanged)
    #expect(firstSound(from: priorityTick(attacks: [.infantry], nonfatalHit: true)) == .attackMelee)
}

private func firstSound(
    from result: BattleCombatState.TickResult
) -> GameplaySoundID? {
    var scheduler = AutomaticCombatFeedbackScheduler()
    return scheduler.selectSound(from: result, at: 0)
}

private func priorityTick(
    death: Bool = false,
    tower: Bool = false,
    attacks: [SoldierType] = [],
    nonfatalHit: Bool = false
) -> BattleCombatState.TickResult {
    var result = BattleCombatState.TickResult()

    if death {
        result.soldierLosses = [
            SoldierLossEvent(
                soldierID: 90,
                type: .infantry,
                source: .manual,
                lane: .left
            )
        ]
    }

    if tower {
        result.towerShots = [
            BattleCombatState.TowerShot(soldierID: 91, damage: 3)
        ]
    }

    result.soldierAttacks = attacks.enumerated().map { index, type in
        SoldierAttackEvent(
            soldierID: index + 1,
            type: type,
            source: .manual,
            lane: .center,
            appliedCityDamage: 1
        )
    }

    if nonfatalHit {
        result.damagedSoldierIDs = [999]
    }

    return result
}
```

Port the current starvation-state test:

```swift
@Test func closedGlobalGateDoesNotChangeStarvationState() {
    let dense = denseTickResult()
    var scheduler = AutomaticCombatFeedbackScheduler()

    #expect(scheduler.selectSound(from: dense, at: 0.000) == .soldierDeath)
    #expect(scheduler.selectSound(from: towerOnlyTickResult(), at: 0.075) == nil)
    #expect(scheduler.selectSound(from: dense, at: 0.150) == .towerFire)
    #expect(scheduler.selectSound(from: dense, at: 0.300) == .attackSiege)
}
```

Port the starvation-reset test:

```swift
@Test func resetsStarvationWhenNoAttackFamilyIsOpen() {
    let dense = denseTickResult()
    var scheduler = AutomaticCombatFeedbackScheduler()

    #expect(scheduler.selectSound(from: dense, at: 0.000) == .soldierDeath)
    #expect(scheduler.selectSound(from: towerOnlyTickResult(), at: 0.150) == .towerFire)
    #expect(scheduler.selectSound(from: dense, at: 0.300) == .soldierDeath)
}
```

Also retain tests for:

- exact 150 ms global boundary and immediately-before boundary;
- exact 200 ms melee/ranged/siege boundaries;
- exact 250 ms tower boundary;
- shared 300 ms death->hit and hit->death boundaries;
- global window not consumed when only a present family is closed;
- attack-only rotation siege -> ranged -> melee;
- rotated-attack fallback to a non-attack when no attack is eligible;
- Infantry/Cavalry -> melee;
- Archer/Mage -> ranged;
- Siege -> siege;
- duplicate same-family attacks coalescing;
- fatal damaged soldiers not also yielding hit;
- empty tick yielding nil;
- disabled sound not advancing scheduler state at coordinator level.

Delete `nonGatedEventsAreFilteredOutWithoutBlockingEligibleEvents`; mixed semantic arrays no longer exist with `TickResult` input.

- [ ] **Step 6: Delete projector files**

```bash
git rm \
  Pyxis/CombatFeedbackProjector.swift \
  PyxisTests/CombatFeedbackProjectorTests.swift
```

- [ ] **Step 7: Run the scheduler/scene/runtime slice**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/AutomaticCombatFeedbackSchedulerTests \
  -only-testing:PyxisTests/DefaultGameplayFeedbackCoordinatorTests \
  -only-testing:PyxisTests/BattleSceneTests \
  -only-testing:PyxisTests/GameplayFeedbackTests \
  -only-testing:PyxisTests/GameViewControllerTests
```

Expected: PASS.

- [ ] **Step 8: Run the automatic-combat perceptual smoke before continuing**

Use a build with prepared gameplay audio and verify:

1. dense combat remains restrained rather than continuous/noisy;
2. repeated dense combat exposes siege, ranged, and melee attack sounds over time rather than sticking to one attack family.

If either fails, stop here and fix/revert Task 2 before touching the discrete policy/output layer.

- [ ] **Step 9: Commit the automatic-pipeline collapse**

```bash
git add Pyxis PyxisTests
git commit -m "refactor: collapse automatic combat feedback pipeline"
```

---

### Task 3: Delete policy/directive/generic gates and make the catalog authoritative

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
- Consumes: six-case `GameplayFeedbackEvent` from Task 2.
- Produces: `GameplaySoundOutput.play(_ sound: GameplaySoundID)`.
- Keeps: `GameplaySoundClass` only inside catalog/output voice selection.

- [ ] **Step 1: Remove directive and generic gate transport types**

Delete `GameplayGateID` and `GameplayFeedbackDirective` from `GameplayOutputProtocols.swift`.

Change:

```swift
func play(_ sound: GameplaySoundID, soundClass: GameplaySoundClass)
```

to:

```swift
func play(_ sound: GameplaySoundID)
```

- [ ] **Step 2: Inline the six discrete mappings with an exhaustive switch**

Use this shape in `DefaultGameplayFeedbackCoordinator`:

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

Do not add a `default` case.

Use separate channel dictionaries:

```swift
private var lastSoundAt: [GameplayFeedbackEvent: TimeInterval] = [:]
private var lastHapticAt: [GameplayFeedbackEvent: TimeInterval] = [:]
```

Each helper must check its own preference first and record a timestamp only after that channel is eligible. This preserves independent cooldown state when one channel is disabled/re-enabled.

- [ ] **Step 3: Remove sound class from automatic playback**

Automatic flow becomes:

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

- [ ] **Step 4: Resolve sound class through the existing ready-play drop path**

Public entry:

```swift
func play(_ sound: GameplaySoundID) {
    outputQueue.async { [weak self] in
        self?.playReadySound(sound)
    }
}
```

Change the existing ready-play guard to require the catalog resource and prepared sound together:

```swift
private func playReadySound(_ soundID: GameplaySoundID) {
    guard isOutputEligible else {
        return
    }

    guard case .ready = preparationState,
          let resource = catalog[soundID],
          let preparedSound = preparedSounds[soundID]
    else {
        beginPreparationIfNeeded()
        return
    }

    let soundClass = resource.soundClass
    // Existing activation, voice selection, scheduling, and completion logic follows.
}
```

A missing catalog entry therefore follows the same drop/retry branch as a missing prepared sound. In the already-ready state `beginPreparationIfNeeded()` is a no-op, so the event is simply dropped. Add no assertion, log branch, fallback sound, or queue. `GameplaySoundCatalogTests.catalogHasOneExpectedResourceForEverySoundID()` remains the completeness guard.

Do not change preparation, activation, voice capacity, lifecycle, or interruption logic.

- [ ] **Step 5: Simplify recording sound output**

Use:

```swift
final class RecordingGameplaySoundOutput: GameplaySoundOutput {
    enum Call: Equatable {
        case prepareIfNeeded
        case play(GameplaySoundID)
        case stopAllAndDeactivate
    }

    private(set) var calls: [Call] = []

    func prepareIfNeeded() {
        calls.append(.prepareIfNeeded)
    }

    func play(_ sound: GameplaySoundID) {
        calls.append(.play(sound))
    }

    func stopAllAndDeactivate() {
        calls.append(.stopAllAndDeactivate)
    }
}
```

Update the Task 1 permanent mapping test to expect `.play(testCase.sound)`.

- [ ] **Step 6: Delete policy files and duplicated-authority tests**

```bash
git rm \
  Pyxis/GameplayFeedbackPolicy.swift \
  PyxisTests/GameplayFeedbackPolicyTests.swift
```

Delete `GameplaySoundCatalogTests.policyDirectiveSoundClassesMatchCatalogEntries()`.

Keep catalog completeness, bundle, duration, and license/manifest tests.

- [ ] **Step 7: Run coordinator/catalog/output tests**

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

- [ ] **Step 8: Run the discrete/output smoke before changing preferences**

Verify on a supported device/simulator, using a physical device for haptics/interruption when available:

1. manual deployment still produces deployment SFX + light haptic;
2. invalid action still produces blocked SFX + warning haptic;
3. building construction/upgrade still produces construction SFX + medium haptic;
4. reward feedback still precedes city/country outcome feedback;
5. background/foreground or audio interruption does not replay a stale cue after resume.

If any fails, stop and fix/revert Task 3 before changing preference persistence.

- [ ] **Step 9: Commit the discrete/output collapse**

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
- Consumes: two UI toggles and one coordinator observer.
- Produces: two-field `FeedbackPreferences` and `FeedbackPreferencesManaging` with a simple synchronous cancellable callback registry.
- Production keys: `pyxis.feedback.soundEffectsEnabled`, `pyxis.feedback.hapticsEnabled`.

- [ ] **Step 1: Remove Codable-specific preference machinery**

Use:

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

Delete custom `CodingKeys` and `init(from:)`.

- [ ] **Step 2: Replace the JSON store with two exact Boolean keys**

Use:

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

Tests use an isolated `UserDefaults` suite and a unique prefix such as `feedback.<UUID>`.

Do not read, migrate, rewrite, or delete `pyxis.feedbackPreferences`.

- [ ] **Step 3: Implement minimal setters and cancellable observation**

Sound setter:

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

Use the same shape for haptics.

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

Keep token cancellation idempotent. Do not track observer order, delivery versions, stale snapshots, or nested registration semantics.

- [ ] **Step 4: Remove settings-controller observation**

Delete the controller's observation property and `observe` registration.

Refresh at `open()`:

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

private func toggleHaptics() {
    applyPreferences(
        preferencesManager.setHapticsEnabled(!preferences.hapticsEnabled)
    )
}
```

Rename `applyObservedPreferences` to `applyPreferences`.

Delete `externallyObservedPreferenceChangesReapplyTheVisibleModal`; no production actor requires an already-open modal to repaint from an external preference mutation. If that real consumer appears later, restore one modal observer then rather than preserving it now.

- [ ] **Step 5: Replace preference tests with the actual product contract**

Keep these tests:

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
- corrupt backups/non-keyed roots;
- injected encoding failure;
- encoded object key shape;
- observer order/version monotonicity;
- nested setters and re-entrant registration;
- callback/current divergence;
- duplicate registration semantics;
- compile-only HPA-389 contract locking.

- [ ] **Step 6: Simplify the recording preference manager**

Implement the test double with the same small callback dictionary, two setters, immediate initial delivery, snapshot iteration, and idempotent cancellation as production. Do not keep any version, observer-order, stale-delivery, or nested-update machinery.

- [ ] **Step 7: Retain immediate sound-stop behavior at coordinator level**

Keep:

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

Keep the behavior test that disabling sound stops active output immediately. Delete tests whose only purpose is exact observer-count/token-lifetime structure.

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

- [ ] **Step 9: Run the preference/settings smoke before cleanup**

Verify:

1. disabling Sound Effects during active output stops current sound immediately;
2. haptics continue when only Sound Effects is disabled;
3. disabling Haptics leaves sound enabled;
4. settings values remain consistent after Battle -> Building -> Map scene replacement;
5. relaunch preserves both Boolean values.

If any fails, stop and fix/revert Task 4 before removing unused assets/tests.

- [ ] **Step 10: Commit the preference simplification**

```bash
git add Pyxis PyxisTests
git commit -m "refactor: simplify gameplay feedback preferences"
```

---

### Task 5: Remove now-unused fortified sound artifacts and stale architecture tests

**Files:**
- Modify: `Pyxis/GameplayOutputProtocols.swift`
- Modify: `Pyxis/GameplaySoundCatalog.swift`
- Modify: `PyxisTests/GameplayFeedbackTests.swift`
- Modify: `PyxisTests/GameplaySoundCatalogTests.swift`
- Modify: `PyxisTests/GameplaySoundOutputControllerTests.swift`
- Modify: `docs/audio-assets.md`
- Delete: `Pyxis/Resources/Audio/Gameplay/fortified-warning.caf`

**Interfaces:**
- Consumes: six-case semantic enum already established in Task 2.
- Produces: catalog/assets containing only currently reachable sounds.

- [ ] **Step 1: Remove fortified sound ID/catalog/resource data**

Delete:

```swift
case fortifiedWarning
```

from `GameplaySoundID`.

Delete its `GameplaySoundCatalog.all` resource entry.

Delete the `fortified-warning.caf` row from `docs/audio-assets.md` and any fortified-only expected manifest fixture data.

Then remove the asset:

```bash
git rm Pyxis/Resources/Audio/Gameplay/fortified-warning.caf
```

Keep shared license files because remaining assets still use them.

- [ ] **Step 2: Delete architecture-only semantic tests rather than replacing them with a count assertion**

Do not add a `reachableDiscreteEventsRemainConstructible` test.

The permanent six-case behavior contract is `DefaultGameplayFeedbackCoordinatorTests.reachableDiscreteEventsEmitCurrentOutputs()` from Task 1.

In `GameplayFeedbackTests`, keep only tests that still protect a useful public seam:

```swift
@Test func noOpProviderAcceptsBothEntryPoints() {
    let provider = NoOpGameplayFeedbackProvider()

    provider.emit(.countryCompletion)
    provider.emitAutomaticCombat(BattleCombatState.TickResult())
}
```

Keep the existing monotonic-clock test if it remains in `GameplayFeedbackTests` after the semantic-enumeration tests are removed.

Delete tests that merely enumerate semantic cases or verify removed automatic payload types.

- [ ] **Step 3: Keep catalog/asset behavior coverage**

Retain tests that:

- every remaining `GameplaySoundID` has exactly one catalog resource;
- every catalog resource is bundled;
- automatic clips stay within their measured duration budget;
- manifest rows and local license evidence cover every remaining resource.

Remove only fortified-warning fixture entries.

- [ ] **Step 4: Run catalog/feedback/output tests**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/GameplayFeedbackTests \
  -only-testing:PyxisTests/GameplaySoundCatalogTests \
  -only-testing:PyxisTests/GameplaySoundOutputControllerTests \
  -only-testing:PyxisTests/DefaultGameplayFeedbackCoordinatorTests
```

Expected: PASS.

- [ ] **Step 5: Commit the unused-artifact deletion**

```bash
git add Pyxis PyxisTests docs/audio-assets.md
git commit -m "chore: remove unused fortified feedback"
```

---

### Task 6: Replace stale architectural mandates and prove net deletion

**Files:**
- Modify: `CLAUDE.md`
- Verify: all production feedback files changed above.
- Verify: all affected tests.

**Interfaces:**
- Produces: stable repository guidance that describes product rules, not obsolete HPA-364/HPA-389 layer ownership.

- [ ] **Step 1: Replace feedback-specific architecture mandates in `CLAUDE.md`**

Remove guidance that requires:

- the HPA-364 foundation/HPA-389 consumer split;
- semantic automatic event arrays;
- projector ownership;
- directive/policy ownership;
- versioned/re-entrant preference delivery semantics;
- fortified-warning preservation.

Keep concise stable rules equivalent to:

```markdown
- Gameplay feedback is observational and restrained; it must not change combat, persistence, routing, or economy.
- Sound Effects and Haptics are independent persisted preferences. Disabled channels are honored immediately.
- Automatic combat feedback remains rate-limited and sound-only; suppressed or not-ready feedback is dropped rather than queued/replayed.
- Backgrounding, interruption, lifecycle recovery, or disabling sound stops stale output and never replays old effects.
- Settings expose only Sound Effects and Haptics unless a concrete player-facing ticket adds another control.
- Do not add feedback categories, policy layers, registries, or extension points without a current shipping consumer.
```

Do not rewrite historical HPA-364/HPA-389 spec/plan documents.

- [ ] **Step 2: Run the full unit suite with parallel testing disabled**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests
```

Expected: all `PyxisTests` PASS.

- [ ] **Step 3: Run UI tests that cover the shared app surface**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisUITests
```

Expected: all `PyxisUITests` PASS.

- [ ] **Step 4: Run SwiftLint, diff sanity checks, and the HPA-566 net-deletion gate**

```bash
swiftlint lint --no-cache
git diff --check origin/main...HEAD
git diff --numstat origin/main...HEAD -- ':(glob)Pyxis/*.swift' | awk '
  { added += $1; deleted += $2 }
  END {
    printf "Production Swift additions: %d\nProduction Swift deletions: %d\nNet: %d\n", added, deleted, added - deleted
    exit !(deleted > added)
  }
'
```

Expected:

- SwiftLint exits 0 under the repository's configured severity rules.
- `git diff --check` exits 0.
- the production-Swift line-count command exits 0 because HPA-566 explicitly requires a net reduction in production feedback lines.

This metric is not the only simplification gate; Step 6 separately verifies deleted types stay deleted and no replacement architecture appears.

- [ ] **Step 5: Run the final integrated player-visible smoke**

Repeat the complete journey after all slices are together, using a physical device for haptics/audio-interruption checks when available:

1. accepted manual deployment produces the existing deployment sound and light haptic;
2. invalid action produces the existing blocked sound and warning haptic;
3. building construction/upgrade produces the existing construction feedback;
4. dense combat remains restrained and attack sounds rotate perceptibly;
5. reward feedback precedes city/country outcome feedback as before;
6. disabling Sound Effects during active output stops current sound immediately;
7. haptics continue when only Sound Effects is disabled;
8. disabling Haptics does not disable sound;
9. settings values remain consistent after Battle -> Building -> Map scene replacement;
10. relaunch preserves both Boolean settings;
11. background/foreground and audio interruption do not replay stale sounds;
12. settings modal still blocks underlying input and VoiceOver focus remains usable.

- [ ] **Step 6: Review the final diff for forbidden replacement architecture**

Run:

```bash
git grep -n "GameplayFeedbackDirective\|GameplayGateID\|CombatFeedbackProjector\|GameplayFeedbackPolicy" -- Pyxis PyxisTests || true
git grep -n "fortifiedWarning\|fortifiedLaneWarning" -- Pyxis PyxisTests docs/audio-assets.md || true
```

Expected: no matches outside historical documentation that is intentionally retained.

Inspect newly added production types manually. The implementation fails HPA-566 if it replaces a deleted layer with a new policy object, gate registry, automatic-event DTO, event bus, or generic preference framework.

- [ ] **Step 7: Commit final repository guidance**

```bash
git add CLAUDE.md
git commit -m "docs: align guidance with simplified feedback architecture"
```

---

## Review Findings Addressed

The external reviews were checked against the current code and HPA-566 acceptance criteria before changing the plan.

### First review

- **Accepted:** preserve the full nine-checkpoint dense fairness sequence and explicit starvation-state/reset tests.
- **Accepted:** shrink `GameplayFeedbackEvent` in Task 2 with the automatic `TickResult` collapse so Task 3 has an exhaustive six-case switch and no temporary `default`.
- **Accepted:** retain the scheduler's existing private `Gate`, including shared `.hitDeath`.
- **Accepted:** keep Task 1's table-driven coordinator mapping test instead of adding a hollow six-case constructibility/count test.
- **Accepted:** delete `nonGatedEventsAreFilteredOutWithoutBlockingEligibleEvents` when mixed semantic batches cease to exist.
- **Not adopted:** replace observation with a single overwriteable `onChange` callback; the small cancellable dictionary remains without version/order semantics.

### Second review

- **Accepted:** explicitly document that shrinking the semantic enum removes the old runtime automatic-event guard by making that state unrepresentable.
- **Accepted:** add five adjacent pairwise-priority assertions so deleting `CombatFeedbackProjectorTests` does not lose the candidate-order contract.
- **Accepted:** remove the undecided missing-catalog diagnostic branch; catalog/resource misses use the existing drop/retry path with no new assert/log/fallback.
- **Accepted:** add a Risks/rollback section and task-local manual smoke so perceptual/settings regressions are caught near the slice that can cause them.
- **Accepted:** record settings-controller non-observation as deliberate YAGNI.
- **Partially adopted:** earlier smoke is split by ownership: automatic pacing immediately after Task 2, discrete/haptic/output behavior after Task 3, and settings/persistence after Task 4. The final integrated smoke remains.
- **Not adopted:** remove the net-deletion gate. HPA-566 explicitly requires net reduction in production feedback types/lines, so the command remains a hard acceptance check and is narrowed to production Swift. Deleted-type grep and manual replacement-architecture inspection remain separate gates.

---

## Final self-review checklist

Before marking the implementation PR ready for review:

- [ ] Every HPA-566 acceptance criterion maps to a completed task above.
- [ ] No `TBD`, `TODO`, compatibility shim, speculative abstraction, or future feedback category was introduced.
- [ ] Task 2 preserves the full nine-checkpoint dense fairness sequence.
- [ ] Five adjacent candidate-priority relationships are explicitly tested.
- [ ] Closed global windows do not change starvation state.
- [ ] Starvation resets when no attack family is open.
- [ ] Exact 150/200/250/300 ms automatic boundaries remain covered.
- [ ] Scheduler uses only a private rate-limit `Gate`; no public/general gate type exists.
- [ ] `GameplayFeedbackEvent` is already six-case discrete-only before Task 3 begins.
- [ ] Automatic feedback through the discrete entry point is unrepresentable; no replacement runtime guard exists.
- [ ] No catch-all `default` hides old automatic semantic cases in coordinator mapping.
- [ ] Disabled sound does not advance automatic scheduler state.
- [ ] Sound/haptic discrete cooldowns remain independent when either channel is disabled/re-enabled.
- [ ] Fatal damage does not also generate hit sound eligibility.
- [ ] `GameplaySoundCatalog` is the only sound-class authority.
- [ ] Missing catalog/prepared sound uses one deterministic drop path with no new diagnostic branch.
- [ ] Sound disable still immediately stops active output through the coordinator's simple preference observation.
- [ ] Settings controller has no preference observer and refreshes from `current` on open.
- [ ] Preference observation has no version/order/re-entrant-delivery machinery.
- [ ] Campaign persistence is untouched.
- [ ] Old development preference JSON is not migrated.
- [ ] Fortified-warning code, asset, manifest row, and tests are gone.
- [ ] No hollow semantic constructibility/count test replaced behavior coverage.
- [ ] Task-local smokes pass before later slices proceed.
- [ ] Historical HPA-364/HPA-389 design records remain unchanged.
- [ ] Audio lifecycle/accessibility complexity was not opportunistically rewritten.
- [ ] Production Swift deletions exceed additions.
- [ ] Deleted-type grep and manual diff inspection find no replacement framework.
- [ ] Full unit tests, UI tests, SwiftLint, and `git diff --check` pass.

## Implementation PR description template

```markdown
## Summary

Implements HPA-566 as a deletion-first maintenance refactor. Player-visible gameplay feedback is unchanged; internal projection, policy, directive, generic gate, speculative-warning, duplicated sound-class, and preference-delivery machinery is reduced.

## Deleted

- `GameplayFeedbackPolicy` and `GameplayFeedbackDirective`.
- `GameplayGateID`.
- `CombatFeedbackProjector`.
- Automatic-only semantic feedback cases/payload types.
- Unreachable fortified-lane warning support and asset.
- JSON/corrupt-backup/versioned observer preference machinery.
- Tests that only froze the deleted internal architecture.

## Retained behavior

- Existing discrete SFX/haptic mapping and independent cooldowns.
- 150/200/250/300 ms automatic combat gates, candidate priority, and siege/ranged/melee fairness.
- Immediate independent Sound Effects/Haptics toggles across scenes and relaunch.
- Immediate sound stop on disable.
- Async preparation, bounded voice allocation, protected outcome output, activation retry, background/interruption cleanup, and stale-output prevention.
- Existing settings UI/accessibility behavior.

## Intentionally retained complexity

The AVAudioEngine backend, sound-controller queues/state, eight-voice allocation, interruption/lifecycle handling, settings accessibility adapter, and scene layout logic remain because they protect observed runtime behavior rather than speculative architecture.

## Development compatibility

The old `pyxis.feedbackPreferences` JSON object is not migrated. Pre-release development installs may see Sound Effects and Haptics default to enabled once after this change.

## Deletion result

Copy the three measured production-Swift lines printed by Task 6 into this section and confirm deletions exceed additions.

## Validation

Copy the exact pass/fail summaries from each task-local smoke and the Task 6 unit suite, UI suite, SwiftLint, diff check, and final integrated smoke into this section.
```

## Execution handoff

When the HPA-566 start condition is met, use subagent-driven development unless there is a concrete reason to execute all tasks inline. Each task above is independently reviewable and ends with focused verification before the next deletion slice begins.
