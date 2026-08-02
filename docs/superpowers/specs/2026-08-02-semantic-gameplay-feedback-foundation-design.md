# Semantic Gameplay Feedback Foundation Design

**Issue:** HPA-364  
**Consumer:** HPA-389  
**Related producer:** HPA-362 — adds direct manual lane deployment and emits the fortified-lane warning when a successful deployment uses the fortified lane.  
**Normative consumer reference:** cwchanap/Pyxis#19, with the HPA-364 contract clarification added after review of PR #20.  
**Status:** Review feedback incorporated  
**Date:** 2026-08-02

## Summary

HPA-364 adds the smallest Foundation-only boundary required for gameplay code to describe feedback-worthy occurrences without depending on audio, haptic, UI, asset, or scheduling implementations.

The foundation contains four capabilities:

1. Stable semantic gameplay-feedback events and a scene-facing provider protocol.
2. An exact two-Boolean preference model for sound effects and haptics.
3. A dedicated persistent manager with synchronous, cancellable, re-entrant-safe observation.
4. An injectable monotonic-clock contract for deterministic downstream timing policy.

HPA-364 does not play sound, generate haptics, map events to outputs, project combat results, enforce rate limits, compose the runtime, or modify scenes. HPA-389 owns those behaviors.

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
- Concrete output types and event mapping.
- Automatic and discrete scheduling policy.
- Final timing intervals and state machines.
- Platform audio and haptic implementations.
- Shared runtime composition in `GameViewController`.
- Settings UI and all scene integration.

A shared signature change requires HPA-364 and PR #19 to be updated together before HPA-389 scene integration begins.

## Design decisions

### Semantic events instead of asset-oriented commands

Scenes emit occurrences such as `.manualDeployment` or `.soldierDamage(.death)`. They never request a filename, haptic generator, volume, priority, or cooldown.

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
- HPA-364 does not project, inspect, select, throttle, queue, replay, or deduplicate the array.
- HPA-389 may select at most one output from the batch.

### No-op provider

```swift
final class NoOpGameplayFeedbackProvider: GameplayFeedbackProviding {
    func emit(_ event: GameplayFeedbackEvent) {}
    func emitAutomaticCombat(_ orderedEvents: [GameplayFeedbackEvent]) {}
}
```

The provider is stateless and performs no logging. Recording behavior remains test-only.

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

The store uses plain `JSONEncoder()` and `JSONDecoder()` instances with default key strategies. No snake-case conversion, custom key strategy, or alternate key aliases are configured. Therefore encoded keys are exactly `soundEffectsEnabled` and `hapticsEnabled`.

### Field-tolerant decoding

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

Invalid JSON or a non-keyed root is handled by the store.

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
3. Invalid root data: back up the original bytes under `<key>.corrupt` and use `.defaultValue`.

The corrupt backup is diagnostic evidence only and is not automatically restored.

### Setter transaction order

For a distinct value, a setter synchronously:

1. Constructs and assigns the new in-memory snapshot while preserving the sibling field.
2. Encodes and writes the complete snapshot under the dedicated key.
3. Advances the observation version.
4. Delivers the new snapshot to active observers.
5. Returns the new snapshot.

The methods do not throw.

The model contains only Booleans, so encoding failure is not expected. A defensive encoding failure leaves the new in-memory snapshot active, logs diagnostically, and still notifies observers. A later successful distinct setter persists a newer snapshot. If no later write succeeds, the next launch loads the last successfully persisted snapshot, which may be older than the in-memory change.

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
- Snapshot versions never decrease.
- A newer re-entrant update is never followed by a stale outer update.
- Cancellation prevents callbacks that have not begun.

Ordering between different observers is intentionally unspecified. Consumers must not depend on registration or collection iteration order.

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
2. Capture current observer IDs.
3. Verify each observer is still registered before delivery.
4. Skip it when `lastDeliveredVersion >= deliveryVersion`.
5. Mark the delivery version before invoking the callback.
6. Invoke with the exact snapshot associated with that version.

This supports self-cancellation, cross-cancellation, nested setters, and nested registration without mutating active iteration or delivering stale-after-new state.

### Cancellation and ownership

The token has idempotent cancellation:

```swift
private final class ObservationToken: FeedbackPreferencesObservation {
    private var cancellation: (() -> Void)?

    init(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    func cancel() {
        let action = cancellation
        cancellation = nil
        action?()
    }

    deinit {
        cancel()
    }
}
```

The cancellation closure captures the store weakly. The store retains callback records but not tokens. The caller must retain the token to keep observing.

Callers remain responsible for avoiding callback retain cycles, such as by weakly capturing scenes or controllers.

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

HPA-364 defines no gate, timestamp collection, rate, scheduler, retry policy, or sleep. HPA-389 injects the clock into its timing policy.

Tests use a manually controlled clock and never sleep.

## Error handling and recovery

### Missing or older data

Missing data and fields use enabled defaults. Valid older fields are preserved independently.

### Partially malformed keyed data

A wrong-typed field defaults to `true` without discarding a valid sibling field. No corrupt backup is created for a valid keyed object.

### Completely corrupt root data

The store:

1. Copies original bytes to `<key>.corrupt`.
2. Logs a diagnostic.
3. Uses `.defaultValue`.
4. Continues launch.

It does not delete or overwrite campaign data.

### Persistence failure

UserDefaults writes are best-effort. Failure does not roll back in-memory state or block callbacks. The next launch uses the last successfully persisted snapshot.

## Repository shape

Create:

- `Pyxis/GameplayFeedback.swift`
- `Pyxis/FeedbackPreferences.swift`
- `Pyxis/FeedbackPreferencesStore.swift`
- `PyxisTests/GameplayFeedbackTests.swift`
- `PyxisTests/FeedbackPreferencesTests.swift`
- `PyxisTests/FeedbackPreferencesStoreTests.swift`

Modify after implementation is green:

- `CLAUDE.md` to document the HPA-364/HPA-389 boundary.

Do not modify:

- `BattleScene.swift`
- `CountryMapScene.swift`
- `BuildingViewScene.swift`
- `GameViewController.swift`
- Platform audio or haptic code
- Audio assets
- `Pyxis.xcodeproj/project.pbxproj`

## Test strategy

### Semantic contract

- Construct and compare every event and payload.
- Verify attack-category `allCases`.
- Record discrete calls separately from batch calls.
- Verify batch order and empty-batch identity.
- Verify no-op behavior.
- Verify a manual clock without sleeps.

### Preference model

- Defaults and all Boolean combinations.
- Exactly two encoded keys using default JSON key strategies.
- No music or volume keys.
- Missing-field, wrong-type, unknown-field, and round-trip behavior.
- Compile-only consumer-signature checks.

### Persistent store

Every test uses an isolated `UserDefaults` suite and key and never uses `.shared`.

Cover:

- Missing, valid, partial, wrong-typed, and corrupt data.
- Dedicated-key isolation from campaign state.
- Corrupt backup.
- Independent persistence.
- Immediate initial delivery.
- Distinct update delivery and duplicate suppression.
- Self- and cross-cancellation.
- Token release.
- Nested setters during initial and later callbacks.
- Cross-observer stale-after-new prevention.
- Re-entrant observer registration.
- Duplicate closure registrations as independent tokens.
- Unspecified cross-observer order.
- Token/store non-retention.

### Verification

Run with parallel testing disabled:

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests

swiftlint lint
```

## Acceptance criteria

- Semantic payloads cover manual deployment, attack category, tower fire, hit/death, building change, invalid action, reward, conquest, completion, and fortified warning.
- The provider supports discrete events and one ordered automatic-combat batch per tick.
- Production foundation files import Foundation only.
- The no-op provider has no side effects.
- Preferences have exactly two stored Booleans with enabled defaults and explicit `defaultValue`/default-valued initialization.
- Default JSON key strategies encode exactly the approved keys.
- Preference persistence is independent from campaign persistence.
- Missing, partial, wrong-typed, and corrupt data recover safely.
- Observation is synchronous, cancellable, duplicate-suppressed, re-entrant-safe, and per-observer version-monotonic.
- Re-entrant registration and duplicate registrations have explicit deterministic semantics.
- Cross-observer callback order is unspecified.
- The store is intentionally non-`Sendable` and confined to one executor.
- Tests never use `.shared` and do not pollute `.standard`.
- The monotonic clock is replaceable without sleeps.
- Full unit tests and SwiftLint pass with parallel testing disabled.

## HPA-389 handoff

HPA-389 may assume:

- Exact semantic event types and payloads.
- Exact preference model, defaults, manager, and observation signatures.
- One shared synchronous preference store.
- One ordered automatic batch per tick.
- No-op and test-recording support.
- An injectable monotonic clock.

HPA-389 must not assume:

- HPA-364 maps or schedules output.
- HPA-364 imports platform media or haptic frameworks.
- Events are persisted or replayed.
- Automatic batches have already been projected or coalesced.
- Observer callback order between separate registrations.

## Change control

This document is the HPA-364 design authority. PR #19 must contain an equivalent shared-contract statement before HPA-389 implementation begins.

Any change to event cases, payload types, preference fields/defaults, manager signatures, batch semantics, observation guarantees, or clock signatures requires both designs to be updated and re-reviewed.
