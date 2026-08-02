# Semantic Gameplay Feedback Foundation Design

**Issue:** HPA-364  
**Consumer:** HPA-389  
**Related producer:** HPA-362 — adds direct manual lane deployment and emits the fortified-lane warning when a successful deployment uses the fortified lane.  
**Status:** Second-pass review incorporated  
**Date:** 2026-08-02

## Summary

HPA-364 adds the smallest Foundation-only boundary required for gameplay code to describe feedback-worthy occurrences without depending on audio, haptic, UI, asset, or scheduling implementations.

The foundation contains four capabilities:

1. Stable semantic gameplay-feedback events and a scene-facing provider protocol.
2. An exact two-Boolean preference model for sound effects and haptics.
3. A dedicated persistent manager with synchronous, cancellable, re-entrant-safe observation.
4. An injectable monotonic-clock contract for deterministic downstream timing policy.

HPA-364 does not play sound, generate haptics, map events to outputs, project combat results, enforce rate limits, compose the runtime, or modify scenes. HPA-389 owns those behaviors.

## Contract authority and merge order

While PR #20 and PR #19 are both drafts, their shared signatures must remain synchronized.

The intended merge order is:

1. Merge PR #20 so this design exists on `main`.
2. Merge PR #19 after it consumes the HPA-364 contract from `main`.

After PR #20 merges, this file on `main` is the shared-contract authority. HPA-389 may define narrower output policy, mapping, and scheduling behavior, but it may not redefine the HPA-364 event, provider, preference-manager, or clock contracts. A later shared-contract change starts in this HPA-364 design and must update every active consumer before scene integration proceeds.

## Problem

Adding concrete audio players, haptic generators, preference reads, and timing logic directly to each scene would:

- Couple gameplay scenes to platform feedback frameworks.
- Duplicate preference and lifecycle handling.
- Make deterministic tests depend on devices, wall-clock time, or sleeps.
- Allow scene replacement to create inconsistent preference state.
- Leak asset names and output policy into gameplay producers.
- Risk resetting sensory preferences when campaign data is reset or recovered.

The foundation must separate **what happened** from **how the app presents it**.

## Goals

- Give scenes one stable semantic API for discrete feedback and one ordered automatic-combat batch per tick.
- Match the shared contract consumed by HPA-389.
- Persist sound-effects and haptic choices independently from campaign progress.
- Make preference changes visible immediately through one shared in-memory manager.
- Support deterministic downstream timing through an injectable monotonic clock.
- Remain Foundation-only and Swift Testing-friendly.
- Recover safely from missing, older, partially malformed, or corrupt preference data.
- Stay small enough that HPA-389 can consume it directly without parallel abstractions.

## Non-goals

HPA-364 does not include:

- Sound or haptic output protocols.
- A composite/default output coordinator.
- `BattleCombatState.TickResult` projection or coalescing.
- Event-to-SFX or event-to-haptic mapping.
- Global, category, shared, or discrete rate limits.
- Attack-family anti-starvation.
- Audio assets, filenames, licensing, playback, voice pools, readiness, or audio-session behavior.
- UIKit or Core Haptics implementations.
- Settings UI, accessibility, gear placement, or modal behavior.
- Scene or `GameViewController` integration.
- Music, voice acting, volume controls, downloadable packs, or gameplay mechanics tied to preferences.

## Ownership boundary

### HPA-364 owns

- `GameplayFeedbackEvent` and its semantic payload types.
- `GameplayFeedbackProviding` with discrete and ordered automatic-combat entry points.
- `NoOpGameplayFeedbackProvider`.
- `FeedbackPreferences` with exactly two stored Boolean properties.
- `FeedbackPreferencesManaging` and cancellable observation.
- `FeedbackPreferencesStore` persistence and in-memory delivery semantics.
- `MonotonicClock` and `SystemMonotonicClock`.

### HPA-389 owns

- Projection from one authoritative `BattleCombatState.TickResult` into an ordered event array.
- Validation that an automatic-combat batch contains only automatic-combat-eligible events.
- Concrete output types and event mapping.
- Automatic and discrete scheduling policy.
- Final timing intervals and state machines.
- Platform audio and haptic implementations.
- Shared runtime composition in `GameViewController`.
- Settings UI and all scene integration.

## Design decisions

### Semantic events instead of asset-oriented commands

Scenes emit occurrences such as `.manualDeployment` or `.soldierDamage(.death)`. They never request a filename, haptic generator, volume, priority, or cooldown.

### Audible category names are intentional

`SoldierAttackSoundCategory` and `SoldierDamageSoundKind` are intentionally named as audible classifications consumed by HPA-389. They are not a general gameplay taxonomy and must not be reused as the basis for unrelated mechanics.

Renaming them now would break the reviewed HPA-389 contract without improving HPA-364. Any future rename requires one coordinated shared-contract revision rather than an HPA-364-only cleanup.

### Dedicated preference storage instead of campaign-state fields

Feedback preferences use their own `UserDefaults` key and data model. Campaign reset or save recovery must not unexpectedly reset sensory preferences.

### Small callback protocol instead of Combine, Observation, or NotificationCenter

The manager exposes one current snapshot and returns a cancellable token from `observe`.

- Combine would add an unnecessary publisher lifecycle.
- Swift Observation is not needed for this small cross-scene contract.
- NotificationCenter would provide weaker typing and cancellation ownership.

### Synchronous single-executor delivery

Reads, setters, persistence writes, and observer callbacks occur synchronously on the caller's execution context. The foundation performs no queue hop.

Production uses one shared instance from the main/UI executor. The store is re-entrant-safe but intentionally non-`Sendable` and does not support simultaneous access from multiple threads. Under Swift strict concurrency, callers must keep the store confined to one executor unless a later design explicitly adds isolation.

### Timing seam without timing policy

HPA-364 defines how downstream code obtains monotonic time. HPA-389 defines intervals, gates, anti-starvation, and retry policy.

## Semantic feedback contract

```swift
enum GameplayFeedbackEvent: Equatable {
    case manualDeployment
    case soldierAttack(SoldierAttackSoundCategory)
    case towerFire
    case soldierDamage(SoldierDamageSoundKind)
    case buildingChanged
    case invalidAction
    case goldReward
    case cityConquest
    case countryCompletion
    case fortifiedLaneWarning
}

enum SoldierAttackSoundCategory: CaseIterable, Equatable {
    case melee
    case ranged
    case siege
}

enum SoldierDamageSoundKind: Equatable {
    case hit
    case death
}

protocol GameplayFeedbackProviding: AnyObject {
    func emit(_ event: GameplayFeedbackEvent)
    func emitAutomaticCombat(_ orderedEvents: [GameplayFeedbackEvent])
}
```

### Event semantics

- `manualDeployment`: an accepted player-requested deployment. Building spawns do not use it.
- `soldierAttack`: one audible attack category, independent from an asset filename.
- `towerFire`: an authoritative tower firing occurrence.
- `soldierDamage`: a surviving hit or a death.
- `buildingChanged`: a successful construction or upgrade mutation.
- `invalidAction`: one rejected actionable player request.
- `goldReward`: newly awarded gold tied to a fresh transition.
- `cityConquest`: a newly finalized city conquest.
- `countryCompletion`: a newly finalized country completion.
- `fortifiedLaneWarning`: a warning emitted by HPA-362 when a successful direct manual deployment uses the fortified lane; HPA-389 maps it to output.

The enum is not Codable because HPA-364 does not persist or queue events.

### Discrete emission

`emit(_:)` represents one semantic occurrence. It does not promise output; preferences, gates, readiness, deduplication, or platform support may suppress presentation.

The method does not throw and returns no value. Feedback must never control gameplay success.

### Automatic-combat batch boundary

`emitAutomaticCombat(_:)` receives one caller-ordered array for one authoritative combat tick.

- Array order is significant.
- An empty batch is valid.
- One call represents one tick, not independent discrete calls.
- HPA-364 does not project, inspect, validate, select, throttle, queue, replay, or deduplicate the array.
- HPA-389's projector and scene integration must only place automatic-combat-eligible events in this batch: `soldierAttack`, `towerFire`, and `soldierDamage`.
- HPA-389 may select at most one output from the batch.

The automatic-only membership rule is a consumer invariant. HPA-364 intentionally does not add runtime validation or a second batch model.

### No-op and recording providers

```swift
final class NoOpGameplayFeedbackProvider: GameplayFeedbackProviding {
    func emit(_ event: GameplayFeedbackEvent) {}
    func emitAutomaticCombat(_ orderedEvents: [GameplayFeedbackEvent]) {}
}
```

HPA-364 ships `NoOpGameplayFeedbackProvider` as a production type. It is stateless and performs no logging.

A recording provider is test infrastructure only. HPA-364 defines a recorder privately in `PyxisTests/GameplayFeedbackTests.swift` to verify the protocol and order-preserving batch boundary. HPA-389 may reuse an equivalent helper in `PyxisTests/GameplayFeedbackTestDoubles.swift`; neither ticket adds a production recording provider or a `#if DEBUG` event history.

## Preference model

```swift
struct FeedbackPreferences: Codable, Equatable {
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

The encoded object contains exactly:

- `soundEffectsEnabled`
- `hapticsEnabled`

There is no version, music, volume, mixer, voice, or placeholder field.

Both settings default to `true`.

### Coding strategy

`FeedbackPreferences` implements a custom `init(from:)` for field-tolerant decoding and relies on the compiler-synthesized `encode(to:)` to encode both stored properties. A private `CodingKeys` enum contains exactly the two approved keys.

The store uses plain `JSONEncoder()` and `JSONDecoder()` instances with default key strategies. No snake-case conversion, custom key strategy, or alternate key aliases are configured. Therefore encoded keys are exactly `soundEffectsEnabled` and `hapticsEnabled`.

### Field-tolerant fail-open decoding

Each Boolean is decoded independently:

```swift
soundEffectsEnabled =
    (try? container.decode(Bool.self, forKey: .soundEffectsEnabled)) ?? true
hapticsEnabled =
    (try? container.decode(Bool.self, forKey: .hapticsEnabled)) ?? true
```

Consequences:

- A missing field defaults only that field.
- A wrong-typed field defaults only that field.
- A valid sibling field is preserved.
- Unknown fields are ignored.
- A valid keyed object with malformed fields is not root corruption.

Fail-open is intentional product behavior: malformed or older preference fields must not strand an existing user in unexplained silence or disable device feedback indefinitely. A partially corrupt payload may therefore re-enable only the malformed setting. Invalid JSON or a non-keyed root uses the full corrupt-root recovery path and defaults both settings.

## Public preference-manager contract

```swift
protocol FeedbackPreferencesObservation: AnyObject {
    func cancel()
}

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

Domain-specific setters avoid replacing a newer sibling field with a stale full snapshot. Each setter returns the resulting full snapshot.

## Persistent store

```swift
final class FeedbackPreferencesStore: FeedbackPreferencesManaging {
    static let shared = FeedbackPreferencesStore()

    private(set) var current: FeedbackPreferences

    init(
        defaults: UserDefaults = .standard,
        key: String = "pyxis.feedbackPreferences"
    )
}
```

### Storage isolation

The production key is exactly `pyxis.feedbackPreferences`.

The campaign save remains under `pyxis.kingdomGameState`. The preference store never reads, writes, removes, or migrates the campaign key.

Tests inject a unique `UserDefaults` suite and custom key. Tests must not access `FeedbackPreferencesStore.shared`, because `.shared` uses `.standard` and would pollute process-level user defaults.

### Initialization

The store loads once during initialization:

1. No data: use `.defaultValue`.
2. Valid keyed data: decode with field-level tolerance.
3. Invalid JSON or a non-keyed root: back up the original bytes under `<key>.corrupt` and use `.defaultValue`.

The corrupt backup is diagnostic evidence only and is not automatically restored.

### Setter transaction order

For a distinct value, a setter synchronously:

1. Constructs and assigns the new in-memory snapshot while preserving the sibling field.
2. Encodes and writes the complete snapshot under the dedicated key.
3. Advances the observation version.
4. Delivers the new snapshot to active observers.
5. Returns the new snapshot.

The methods do not throw.

`UserDefaults` does not provide a reliable synchronous write-error result. The encode-failure branch is therefore defensive consistency with `KingdomGameStore`, not a primary recovery mechanism. Since the model contains only Booleans, encoding failure is not expected. If it occurs, the store keeps the new in-memory snapshot, logs diagnostically, and still notifies observers. A later successful distinct setter persists a newer snapshot. If no later write succeeds, the next launch loads the last successfully persisted snapshot, which may be older than the in-memory change.

### Duplicate suppression

Setting a property to its current value performs:

- No in-memory replacement.
- No persistence rewrite.
- No version change.
- No observer callback.

## Observation behavior

### Registration

`observe` registers the callback, marks the current version delivered, and synchronously invokes it once with the current snapshot before returning the token.

If the initial callback performs a nested setter, the observer may receive the newer snapshot during nested delivery. The initial call does not re-send the older snapshot afterward.

If a callback registers another observer, the new observer immediately receives the then-current snapshot through its own `observe` call. It is not retroactively added to an already captured outer delivery list.

Registering the same closure more than once creates independent observer records and tokens. Each active registration receives its own callback for each distinct update.

### Delivery guarantees

For each retained active observer:

- Initial state is delivered synchronously.
- Every distinct later update is delivered synchronously before the setter returns.
- Delivered versions never decrease.
- A newer nested update is never followed by a stale outer update.
- Cancellation prevents callbacks that have not begun.

Ordering between different observers is intentionally unspecified.

### Re-entrant-safe delivery

The store maintains a monotonically increasing internal version and records equivalent to:

```swift
private struct ObserverRecord {
    let callback: (FeedbackPreferences) -> Void
    var lastDeliveredVersion: UInt64
}
```

For one update:

1. Increment the version after memory and persistence handling.
2. Capture the current observer IDs.
3. Verify each observer is still registered before invoking it.
4. Skip it when `lastDeliveredVersion` is equal to or newer than this delivery.
5. Mark the version delivered before invoking the callback.
6. Invoke it with the snapshot associated with that version.

This permits self-cancellation, cross-cancellation, re-entrant registration, and nested updates without mutating an active iteration or delivering stale-after-new state.

### Cancellation and ownership

The observation token uses idempotent cancellation. Its closure captures the store weakly, so the token does not retain the store. The store retains callback records but does not retain tokens. The caller must retain the token to continue observing.

Releasing the token unregisters the observer. Callers remain responsible for avoiding callback retain cycles, such as by weakly capturing a scene or controller.

### Threading contract

The store performs no synchronization and no queue hop. Production access is confined to the main/UI executor. Tests use one thread. Simultaneous access from multiple executors is unsupported.

## Monotonic time contract

```swift
protocol MonotonicClock {
    var now: TimeInterval { get }
}

struct SystemMonotonicClock: MonotonicClock {
    var now: TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }
}
```

`SystemMonotonicClock` is unaffected by wall-clock changes and returns seconds suitable for interval comparisons.

HPA-364 defines no gate, timestamp collection, rate, scheduler, retry policy, or sleep. HPA-389 injects the clock into its coordinator, automatic scheduler, discrete gates, and audio-session retry logic.

Tests use a manually controlled clock and never sleep.

## Error handling and recovery

### Missing or older data

Missing data and missing fields use enabled defaults. Valid sibling fields are preserved independently.

### Partially malformed keyed data

A wrong-typed field defaults to `true` without discarding a valid sibling field. No corrupt backup is created for a valid keyed object with field-level errors.

### Completely corrupt root data

The store:

1. Copies the original bytes to `<key>.corrupt`.
2. Logs diagnostically.
3. Uses `.defaultValue`.
4. Continues launch without throwing.

### Persistence failure

Persistence is best-effort. Failure does not roll back in-memory state or block callbacks. The next launch uses the last successfully persisted snapshot.

## Repository shape

Create:

- `Pyxis/GameplayFeedback.swift` — `GameplayFeedbackEvent`, audible payload types, `GameplayFeedbackProviding`, `NoOpGameplayFeedbackProvider`, `MonotonicClock`, and `SystemMonotonicClock`.
- `Pyxis/FeedbackPreferences.swift` — `FeedbackPreferences`, custom tolerant decoding, synthesized encoding, `FeedbackPreferencesObservation`, and `FeedbackPreferencesManaging`.
- `Pyxis/FeedbackPreferencesStore.swift` — dedicated `UserDefaults` persistence, corruption recovery, observation records, and token implementation.
- `PyxisTests/GameplayFeedbackTests.swift` — semantic contract, no-op, test-local recording provider, batch-order, and manual-clock tests.
- `PyxisTests/FeedbackPreferencesTests.swift` — defaults, exact encoding keys, tolerant decoding, and compile-only consumer-signature checks.
- `PyxisTests/FeedbackPreferencesStoreTests.swift` — isolated persistence, corruption, observation, cancellation, ownership, and re-entrancy tests.

Modify only after implementation is green:

- `CLAUDE.md` — document the HPA-364/HPA-389 ownership and composition boundary.

Do not modify scenes, `GameViewController`, platform feedback code, assets, or `Pyxis.xcodeproj/project.pbxproj`.

## Compile-only consumer-signature check

`PyxisTests/FeedbackPreferencesTests.swift` includes a private helper that is compiled but does not need to execute:

```swift
@inline(never)
private func assertHPA389ConsumerContract(
    manager: FeedbackPreferencesManaging,
    observation: FeedbackPreferencesObservation,
    provider: GameplayFeedbackProviding,
    clock: MonotonicClock
) {
    _ = FeedbackPreferences()
    _ = FeedbackPreferences.defaultValue
    _ = manager.current
    _ = manager.setSoundEffectsEnabled(true)
    _ = manager.setHapticsEnabled(true)
    _ = manager.observe { _ in }
    observation.cancel()
    provider.emit(.manualDeployment)
    provider.emitAutomaticCombat([
        .towerFire,
        .soldierAttack(.melee),
        .soldierDamage(.hit)
    ])
    _ = clock.now
}
```

The helper locks the consumer-visible names, payloads, return values, and callable signatures without adding production code or runtime behavior.

## Test strategy

### Semantic contract tests

- Construct and compare every event and associated payload.
- Verify attack-category case order.
- Record discrete and automatic calls separately.
- Preserve caller order, including an empty automatic batch.
- Verify the no-op provider is side-effect-free.
- Verify a manually controlled clock without sleeping.

### Preference model tests

- `FeedbackPreferences()` and `.defaultValue` are enabled defaults.
- All four Boolean combinations round-trip.
- Encoded keys are exactly the two approved camel-case names.
- Synthesized encoding writes both fields after custom decoding is introduced.
- Missing and wrong-typed fields default independently.
- Unknown fields are ignored.
- No music, volume, or version key appears.
- The compile-only consumer helper typechecks.

### Store tests

Every test constructs an isolated store and never uses `.shared`.

- Missing, partial, wrong-typed, and corrupt-root data.
- `<key>.corrupt` backup behavior.
- Campaign-key isolation.
- Setter persistence and duplicate suppression.
- Immediate observation and synchronous updates.
- Self-cancellation, cross-cancellation, and token deallocation.
- Nested updates during initial and later delivery.
- Re-entrant registration and duplicate registration.
- No stale-after-new snapshots.
- No assumptions about cross-observer order.
- Token/store non-retention.

## Acceptance criteria

- Event payloads and provider signatures match this document and the HPA-389 consumer.
- The automatic batch boundary preserves order and permits an empty batch without validating membership.
- HPA-389 owns the automatic-only membership invariant.
- `GameplayFeedback.swift` owns the monotonic-clock seam.
- The production target contains a no-op provider but no recording provider.
- A test-local recorder verifies provider behavior.
- Preferences have exactly two stored fields and enabled defaults.
- Custom tolerant decoding and synthesized encoding preserve both exact keys.
- Fail-open field recovery is documented and tested.
- Root corruption is backed up and never blocks launch.
- Preference persistence is independent from campaign state.
- Observation is synchronous, cancellable, version-monotonic, re-entrant-safe, and single-executor-confined.
- Compile-only tests lock the HPA-389 consumer signatures.
- Tests never access `FeedbackPreferencesStore.shared`.
- The full `PyxisTests` suite and SwiftLint pass with parallel testing disabled.

## Handoff to HPA-389

After HPA-364 merges, HPA-389 may assume:

- The exact semantic event and payload types.
- Discrete and automatic-batch provider calls.
- Independent enabled-by-default preferences.
- Immediate synchronous observation.
- A production no-op provider and test-only recording support.
- The monotonic-clock seam.

HPA-389 must not assume:

- Event mapping or output types from HPA-364.
- Automatic batch validation, selection, throttling, or anti-starvation from HPA-364.
- Platform playback or haptic behavior from HPA-364.
- Scene composition or lifecycle behavior from HPA-364.

## Verification

Before merging implementation:

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests

swiftlint lint
```

If the named simulator is unavailable, list destinations and use an available supported iPhone simulator. CI must use a destination that exists on the selected runner image; a missing simulator is infrastructure failure, not a test failure.