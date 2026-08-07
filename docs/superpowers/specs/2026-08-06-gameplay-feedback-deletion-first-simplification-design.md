# Gameplay Feedback Deletion-First Simplification Design

**Issue:** HPA-566  
**Status:** Design approved for planning; implementation remains gated by the Linear start condition.  
**Date:** 2026-08-06  
**Implementation plan:** `docs/superpowers/plans/2026-08-06-gameplay-feedback-deletion-first-simplification-implementation.md`

## Summary

HPA-566 reduces the maintenance surface introduced by HPA-364 and HPA-389 without changing what players can observe.

The target keeps the parts that protect real product behavior:

- semantic discrete feedback from scenes;
- restrained automatic-combat SFX with existing rate limits and fairness;
- immediate independent Sound Effects and Haptics settings;
- interruption-safe, drop-only audio playback;
- the existing settings accessibility and scene composition behavior.

It deletes layers that currently have one caller or no production responsibility:

- `CombatFeedbackProjector`;
- `GameplayFeedbackPolicy`;
- `GameplayFeedbackDirective`;
- `GameplayGateID`;
- automatic-only semantic feedback payload types;
- duplicated sound-class input at the playback call site;
- JSON/corrupt-backup/versioned preference-delivery machinery;
- unreachable fortified-lane warning support.

This is a deletion-first maintenance refactor, not a new feedback architecture.

## Start condition

Do not start this implementation solely for cleanup until the HPA-566 Linear start condition is met.

In particular, it must not interrupt HPA-366 or HPA-365. The documentation can merge earlier because it changes no production behavior.

## Goals

- Preserve current player-visible SFX, haptics, settings, accessibility, and lifecycle behavior.
- Reduce production feedback types and lines, not merely move them between files.
- Remove at least one unnecessary production indirection based on real caller analysis.
- Make tests protect emitted/suppressed behavior rather than internal queue, directive, observer-version, or projection structure.
- Keep the resulting code easy to extend only when a concrete future feature actually needs extension.

## Non-goals

- New SFX, haptic events, settings, assets, or gameplay behavior.
- Rewriting the audio engine.
- Broad `BattleScene` cleanup.
- New event buses, DI frameworks, policy registries, lifecycle abstractions, Combine publishers, or Swift Observation models.
- Migration of the pre-release `pyxis.feedbackPreferences` JSON value.
- Preparing feedback infrastructure for music, voice-over, multiplayer, live service, or hypothetical future feedback categories.

## Current caller analysis

### `GameplayFeedbackPolicy`

Production caller: `DefaultGameplayFeedbackCoordinator.emit(_:)` only.

The coordinator immediately unpacks the returned `GameplayFeedbackDirective`.

**Decision:** delete the policy type/file and inline the six reachable discrete mappings into the coordinator.

### `GameplayFeedbackDirective`

Production use: transport object between policy and coordinator only.

**Decision:** delete it.

### `GameplayGateID`

Production use: keys one coordinator dictionary and then maps back to an interval in the same coordinator.

**Decision:** delete it. The coordinator keeps separate sound and haptic timestamp dictionaries keyed by the six discrete events.

### `CombatFeedbackProjector`

Production caller: `BattleScene` only.

It converts one `BattleCombatState.TickResult` into an automatic-only `[GameplayFeedbackEvent]`, which is immediately consumed by one scheduler.

**Decision:** delete it. `AutomaticCombatFeedbackScheduler` consumes `TickResult` directly and derives its sound candidates internally.

### Automatic-only semantic types

`SoldierAttackSoundCategory`, `SoldierDamageSoundKind`, and the automatic cases on `GameplayFeedbackEvent` exist only to transport data from the projector through the scheduler/policy stack.

**Decision:** remove them from the scene-facing semantic contract as part of the same implementation slice that changes the scheduler to return `GameplaySoundID`.

This ordering is deliberate: once automatic scheduling no longer returns semantic events, the public enum immediately becomes the six reachable discrete cases so later exhaustive switches compile without a temporary default case.

This is also a structural safety improvement: today `DefaultGameplayFeedbackCoordinator.emit(_:)` needs a runtime guard to reject automatic-combat events that arrive through the discrete entry point. After the enum shrink, that invalid state is unrepresentable. Do not re-add automatic cases to `GameplayFeedbackEvent` unless a concrete scene-facing discrete consumer requires them.

### `fortifiedLaneWarning`

No production producer exists. Its intended producer is HPA-362, which remains an evidence-gated experiment and may never ship.

**Decision:** remove `.fortifiedLaneWarning` from the semantic enum in the automatic-pipeline collapse slice. Remove `.fortifiedWarning`, the asset/catalog/manifest row, and its tests in the later cleanup slice.

If HPA-362 eventually ships and proves a warning is needed, that ticket adds the smallest concrete warning behavior then.

### `GameplaySoundClass` at the playback boundary

`GameplaySoundCatalog` already stores whether every sound is automatic or protected/non-automatic. Passing the class again on every `play` call creates a second authority and a test whose purpose is only to prove both values agree.

**Decision:** change the output API to `play(_ sound: GameplaySoundID)`. `GameplaySoundOutputController` resolves `GameplaySoundClass` from its injected catalog before voice selection.

`GameplaySoundClass` itself remains because the catalog and voice allocator still need the distinction internally.

### Preference observation

Only two production consumers currently observe preferences:

1. `DefaultGameplayFeedbackCoordinator`, which must immediately stop active sound when Sound Effects is disabled.
2. `FeedbackSettingsController`, which currently keeps a local modal snapshot synchronized.

The settings controller owns all UI mutations while mounted and can instead refresh from `current` when opening and apply each setter's returned snapshot.

**Decision:** remove settings-controller observation and retain a small synchronous cancellable observer registry for the coordinator.

The registry intentionally has no callback-order, version, stale-delivery, or re-entrant-delivery contract. A dictionary plus snapshot iteration is sufficient.

A single `onChange` callback was considered. It saves only a few lines while making the manager contract replacement-based and easier to accidentally overwrite in tests or composition. The simple cancellable registry is retained because it is already a natural injectable contract and remains small after deleting the version machinery.

If a future non-UI actor genuinely needs to mutate feedback preferences while the settings modal is already open, that future ticket can restore modal observation in one place. HPA-566 does not preserve that unused behavior speculatively.

## Target production architecture

```text
BattleScene / CountryMapScene / BuildingViewScene
                 |
                 | six discrete semantic events
                 v
      GameplayFeedbackProviding.emit(event)
                 |
                 v
 DefaultGameplayFeedbackCoordinator
      |                       |
      |                       +--> GameplayHapticOutput
      |
      +--> GameplaySoundOutput.play(soundID)
                               |
                               v
                    GameplaySoundCatalog
                               |
                               v
                GameplaySoundOutputController

BattleScene
    |
    | BattleCombatState.TickResult
    v
GameplayFeedbackProviding.emitAutomaticCombat(result)
    |
    v
DefaultGameplayFeedbackCoordinator
    |
    v
AutomaticCombatFeedbackScheduler.selectSound(result, now)
    |
    v
GameplaySoundOutput.play(soundID)
```

There is no policy object, directive object, projector, generic gate identifier, or automatic semantic-event array in the target flow.

## Target interfaces

### Scene-facing feedback contract

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
```

`NoOpGameplayFeedbackProvider` remains so scenes and tests can use a lightweight default without constructing production audio/haptics.

No feedback event is persisted or exposed as a public network/API contract.

### Automatic scheduler

```swift
struct AutomaticCombatFeedbackScheduler {
    mutating func selectSound(
        from result: BattleCombatState.TickResult,
        at now: TimeInterval
    ) -> GameplaySoundID?
}
```

The scheduler owns automatic-combat projection, coalescing, rate limits, and attack fairness because these behaviors are one cohesive pure rule.

It derives candidate sounds in this exact priority order:

1. `.soldierDeath`
2. `.towerFire`
3. `.attackSiege`
4. `.attackRanged`
5. `.attackMelee`
6. `.soldierHit`

Soldier attack mapping remains:

- Infantry/Cavalry -> `.attackMelee`;
- Archer/Mage -> `.attackRanged`;
- Siege -> `.attackSiege`.

Fatal soldiers must not also create `.soldierHit` eligibility.

The scheduler preserves:

- 150 ms global output gate;
- 200 ms per attack-family gate;
- 250 ms tower gate;
- shared 300 ms hit/death gate;
- no more than two successful eligible non-attack windows before an eligible attack is reserved;
- attack rotation siege -> ranged -> melee.

#### Private gate representation

Keep the scheduler's existing private gate concept because it models real rate-limit families, especially the shared hit/death interval:

```swift
private enum Gate {
    case melee
    case ranged
    case siege
    case tower
    case hitDeath
}
```

Map sound candidates to this private enum for interval/timestamp lookup. Do not introduce a public/general gate identifier.

Attack rotation may use concrete `GameplaySoundID` values. The private `Gate` exists only for scheduler rate-limit state.

### Sound output

```swift
protocol GameplaySoundOutput: AnyObject {
    func prepareIfNeeded()
    func play(_ sound: GameplaySoundID)
    func stopAllAndDeactivate()
}
```

`GameplaySoundOutputController` resolves the sound class from `GameplaySoundCatalog` in the existing ready-play path before selecting a voice. The ready-play guard requires both the catalog resource and the prepared sound. If either is missing, the current event follows the existing drop/retry path and returns; no new assertion, log branch, fallback sound, or queue is introduced. `GameplaySoundCatalogTests` remains the completeness guard for shipped sound IDs.

## Preference design

### Snapshot and manager

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

@MainActor
protocol FeedbackPreferencesObservation: AnyObject {
    func cancel()
}

@MainActor
protocol FeedbackPreferencesManaging: AnyObject {
    var current: FeedbackPreferences { get }

    @discardableResult
    func setSoundEffectsEnabled(_ enabled: Bool) -> FeedbackPreferences

    @discardableResult
    func setHapticsEnabled(_ enabled: Bool) -> FeedbackPreferences

    func observe(
        _ observer: @escaping (FeedbackPreferences) -> Void
    ) -> FeedbackPreferencesObservation
}
```

Both protocols are `@MainActor`-isolated. This preserves their existing APIs and synchronous `current`, mutation, observation, and cancellation behavior — all access stays on the main actor with no async hops, version vectors, or callback queues. `DefaultGameplayFeedbackCoordinator` and `FeedbackPreferencesStore` conform to / consume these protocols from the main actor consistently (`FeedbackPreferencesStore` is `@MainActor`; `DefaultGameplayFeedbackCoordinator` is main-actor-isolated where it reads `preferences.current` and holds the observation token).

Observation is synchronous and cancellable only. No ordering, version, nested-update, duplicate-registration, or callback/current-divergence semantics are product requirements.

### Persistence

Replace the encoded JSON object with two Boolean `UserDefaults` keys:

```text
pyxis.feedback.soundEffectsEnabled
pyxis.feedback.hapticsEnabled
```

The store initializer remains explicitly injectable and accepts a compact prefix for test isolation:

```swift
init(
    defaults: UserDefaults,
    keyPrefix: String = "pyxis.feedback"
)
```

It derives:

```text
<keyPrefix>.soundEffectsEnabled
<keyPrefix>.hapticsEnabled
```

Loading uses `object(forKey:) as? Bool ?? true` for each field so missing values default to enabled while persisted `false` remains false.

Each distinct setter:

1. updates the in-memory snapshot;
2. writes only that Boolean;
3. synchronously notifies a snapshot of registered callbacks;
4. returns the resulting snapshot.

An unchanged setter performs no write and no callback.

### Development compatibility

Do not read, migrate, rewrite, or delete the old `pyxis.feedbackPreferences` JSON key.

Existing pre-release development installs may see both toggles default to enabled once after this change. That is acceptable under the roadmap's pre-release compatibility rule.

`pyxis.kingdomGameState` remains untouched.

## Coordinator design

`DefaultGameplayFeedbackCoordinator` remains the single product-level owner of emitted/suppressed feedback behavior.

It keeps:

- current preferences;
- one preference observation token;
- sound output;
- haptic output;
- monotonic clock;
- separate sound/haptic cooldown timestamps for discrete events;
- automatic combat scheduler.

### Discrete mapping

Use one exhaustive switch on the six reachable cases:

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

Use separate timestamp dictionaries keyed by `GameplayFeedbackEvent`. A channel records its timestamp only after its preference check passes, preserving independent cooldown behavior when the other channel is disabled/re-enabled.

Task ordering must shrink `GameplayFeedbackEvent` before this exhaustive switch is introduced; implementation must never add a catch-all `default` to hide automatic cases.

### Automatic mapping

`emitAutomaticCombat(_:)`:

1. checks `soundEffectsEnabled` before invoking the scheduler so disabled sound does not advance scheduler state;
2. asks the scheduler for at most one `GameplaySoundID`;
3. plays it when present.

It does not rebuild an automatic semantic array or route the selected sound through the discrete switch.

## Settings controller design

Remove `preferenceObservation` from `FeedbackSettingsController`.

- `open()` refreshes from `preferencesManager.current` before rendering.
- Each toggle calls its setter and immediately applies the returned snapshot.
- Scene replacement naturally constructs a controller against the same shared store.

No production actor changes preferences behind an already-open modal, so continuous modal observation is not required.

## Audio and accessibility boundaries intentionally retained

`GameplaySoundOutputController` is not a target for architectural collapse beyond removing the redundant `soundClass` parameter.

Retain:

- async preparation and voice creation;
- drop-before-ready behavior;
- automatic/protected voice allocation;
- serialized backend mutations;
- activation retry cooldown;
- background/interruption/reset cleanup;
- stale-output prevention.

Also retain `AVAudioEngineGameplayAudioBackend`, `FeedbackSettingsAccessibilityAdapter`, settings layout types, and scene-specific gear placement except for mechanical signature updates required by this refactor.

These layers protect observed runtime/accessibility behavior rather than hypothetical extension points.

## Risks and rollback

The highest-risk change is Task 2's projector/scheduler collapse: exact tests can protect timing and priority, but they cannot fully prove that dense combat still sounds restrained and varied to a player. Task 3 can also create silent regressions if discrete mapping or catalog-owned sound class is wired incorrectly; Task 4 can regress immediate preference application/persistence.

Each implementation task is a separate commit and has a task-local smoke for the behavior it can break. If that focused smoke or its focused tests fail, stop and revert/fix that task before proceeding; do not carry a known audio/settings regression into later slices and discover it only during the final smoke.

## Test strategy

Tests protect behavior, not deleted architecture.

### Permanent discrete contract

Keep one table-driven coordinator test covering all six reachable discrete mappings plus focused tests for:

- independent sound/haptic cooldowns;
- immediate `stopAllAndDeactivate()` when sound is disabled;
- disabled sound/haptics suppressing only their own channel;
- outcomes remaining ungated.

Do not replace deleted policy tests with a six-case constructibility/count test; that would not protect player behavior.

### Automatic-combat contract

Port the full existing fairness sequence to `TickResult`-based scheduler tests:

```text
0.000 -> soldierDeath
0.150 -> towerFire
0.300 -> attackSiege
0.450 -> soldierDeath
0.600 -> towerFire
0.750 -> attackRanged
0.900 -> soldierDeath
1.050 -> towerFire
1.200 -> attackMelee
```

Also add a fresh-scheduler pairwise priority contract for each adjacent candidate pair:

```text
soldierDeath > towerFire
towerFire > attackSiege
attackSiege > attackRanged
attackRanged > attackMelee
attackMelee > soldierHit
```

This replaces the deleted projector test that previously asserted the full candidate-array ordering and prevents mid-list priority changes from hiding behind the fairness sequence.

Also retain explicit tests that:

- a closed global gate does not mutate starvation state;
- starvation resets when no attack family is open;
- exact 150/200/250/300 ms boundaries remain intact;
- fatal damage excludes hit eligibility;
- duplicate same-family signals coalesce;
- empty ticks produce no sound;
- disabled sound does not advance scheduler state.

Delete `nonGatedEventsAreFilteredOutWithoutBlockingEligibleEvents`: after the scheduler consumes `TickResult`, mixed discrete/automatic semantic batches no longer exist.

### Preference contract

Keep tests for:

- enabled defaults when keys are missing;
- independent Boolean persistence and sibling preservation;
- unchanged-setter suppression;
- immediate synchronous current/update delivery;
- cancellation stopping future updates;
- isolated test keys and campaign-state isolation;
- round-trip across store recreation;
- immediate sound stop through the coordinator.

Delete tests for JSON field tolerance, corrupt backups, encoding injection, observer versions/order, nested registration, callback/current divergence, and compile-only HPA-389 surface locking.

### Audio/settings tests

Keep existing behavior tests for:

- catalog completeness and bundled resources;
- automatic clip duration budget;
- asset license/manifest evidence;
- voice allocation/protection;
- readiness and activation failure dropping;
- lifecycle/interruption cleanup;
- settings modal blocking, persistence, and accessibility.

## Review decisions incorporated

The external reviews were checked against the current code, scheduler tests, and HPA-566 acceptance criteria before changes were made.

### First review

**Accepted:**

- preserve the full nine-checkpoint dense fairness sequence rather than a shortened sample;
- keep explicit starvation-state and starvation-reset tests;
- shrink automatic semantic cases in the same slice as scheduler projection collapse so the next exhaustive switch compiles;
- retain the scheduler's existing private `Gate` for real rate-limit families such as shared hit/death;
- keep the Task 1 behavioral discrete mapping test as the permanent mapping contract instead of adding a hollow six-case constructibility assertion;
- delete the mixed-batch-only scheduler test once `TickResult` is the input.

**Not adopted:**

- replace observation with a single `onChange` callback. The small cancellable dictionary is already straightforward and avoids replacement/overwrite semantics without retaining the old versioned observer machinery.

### Second review

**Accepted:**

- make the enum-shrink benefit explicit: automatic feedback on the discrete entry point becomes unrepresentable rather than runtime-rejected;
- add pairwise candidate-priority tests before deleting `CombatFeedbackProjectorTests`;
- make missing-catalog behavior deterministic by reusing the existing drop path with no new assertion/log branch;
- add task-local perceptual/manual smoke and an explicit risk/rollback rule so audio regressions are caught near the responsible slice;
- record settings-controller non-observation as deliberate YAGNI rather than an accidental omission.

**Partially adopted:**

- move manual verification earlier. Automatic-combat perceptual checks belong immediately after Task 2, but discrete reward/haptic checks belong after Task 3 and settings persistence checks belong after Task 4 because those later tasks can still break them. A final integrated smoke remains required.

**Not adopted:**

- remove the net-deletion gate. HPA-566 explicitly requires production feedback code to have a net reduction in types and lines. The implementation plan keeps the hard check and scopes its line count to production Swift rather than treating the metric as the only proof of simplification; deleted-type grep and manual replacement-architecture review remain separate gates.

## Deletion success criteria

The implementation is successful when:

- player-visible feedback remains unchanged in task-local and final manual smoke;
- production feedback Swift deletions exceed additions;
- `CombatFeedbackProjector`, `GameplayFeedbackPolicy`, `GameplayFeedbackDirective`, and `GameplayGateID` are gone;
- automatic semantic cases/payload types are gone;
- fortified warning code/asset/manifest/tests are gone;
- JSON/versioned preference machinery is gone;
- no new replacement framework appears;
- the full unit test suite passes.

## Documentation update

Update `CLAUDE.md` to keep only stable product rules:

- feedback is restrained and observational;
- disabled channels are honored immediately;
- background/interruption/readiness failures never replay stale feedback;
- settings expose only Sound Effects and Haptics;
- do not add feedback categories or architecture without a current shipping consumer.

Do not rewrite historical HPA-364/HPA-389 design documents; they remain implementation history.
