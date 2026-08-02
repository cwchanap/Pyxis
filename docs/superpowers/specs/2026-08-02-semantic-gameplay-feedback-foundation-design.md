# Semantic Gameplay Feedback Foundation Design

**Issue:** HPA-364  
**Consumer:** HPA-389  
**Normative consumer reference:** cwchanap/Pyxis#19 at `8ec2b994467a1fe6e85d346bf5edd885e8f23e81`  
**Status:** Ready for review  
**Date:** 2026-08-02

## Summary

HPA-364 adds the smallest framework-light foundation needed for Pyxis scenes and the later HPA-389 feedback runtime to communicate without coupling gameplay code to audio, haptic, UI, or scheduling implementations.

The foundation contains four capabilities:

1. Stable semantic gameplay-feedback events and a scene-facing provider protocol.
2. An exact two-Boolean preference model for sound effects and haptics.
3. A dedicated persistent manager with immediate, cancellable, re-entrant-safe observation.
4. An injectable monotonic-clock contract for deterministic downstream timing policy.

HPA-364 does not play sound, generate haptics, map events to outputs, project combat results, enforce rate limits, compose the runtime, or modify scenes. Those behaviors remain owned by HPA-389.

## Problem

Gameplay feedback is currently scene-owned and mostly visual. Adding concrete audio players, haptic generators, preference reads, and timing logic directly to each scene would create several problems:

- Scene code would depend on platform feedback frameworks.
- Every scene would need duplicate preference and lifecycle handling.
- Tests would need real time, platform devices, or wall-clock sleeps.
- A setting changed in one scene could fail to update another active consumer.
- Concrete asset names and rate-limit policy would leak into gameplay-event producers.
- Feedback preferences stored inside campaign state could be lost when campaign data is reset or recovered from corruption.

The foundation must separate what happened in gameplay from how the app later presents that occurrence.

## Goals

- Give scenes one stable semantic API for discrete feedback and automatic-combat batches.
- Preserve the event payloads already consumed by HPA-389's approved design.
- Persist sound-effects and haptic choices independently from campaign progress.
- Make preference changes visible immediately through one shared in-memory manager.
- Support deterministic downstream timing through an injectable monotonic clock.
- Remain testable with Foundation and Swift Testing only.
- Recover safely from missing, older, partially malformed, or completely corrupt preference data.
- Keep the implementation small enough that HPA-389 can consume it without replacing or wrapping parallel abstractions.

## Non-goals

HPA-364 does not include:

- Sound or haptic output protocols.
- A composite or default output coordinator.
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

- `GameplayFeedbackEvent` and its associated semantic payload types.
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

A change to the shared event, preference-manager, clock, or provider signatures requires the HPA-389 design and plan to be updated before scene integration begins.

## Design decisions and rejected alternatives

### Semantic events instead of asset-oriented commands

Scenes emit occurrences such as `.manualDeployment` or `.soldierDamage(.death)`. They never request a filename, haptic generator, volume, priority, or cooldown.

Rejected: events named after concrete files or platform output types. That would couple gameplay producers to HPA-389's replaceable presentation policy.

### Dedicated preference storage instead of campaign-state fields

Feedback preferences use their own UserDefaults key and data model.

Rejected: adding fields to `KingdomGameState`. A campaign reset, decode recovery, or future save migration must not unexpectedly reset the user's sensory preferences.

### Small callback protocol instead of Combine, Observation, or NotificationCenter

The manager exposes one current snapshot and returns a cancellable token from `observe`.

Rejected:

- Combine would introduce an unnecessary framework and publisher-lifecycle surface.
- Swift Observation would tie the contract to newer language/runtime behavior not needed by the consumer.
- NotificationCenter would provide untyped payloads and weaker ownership and cancellation semantics.

### Synchronous single-thread delivery instead of internal queueing

Reads, setters, persistence writes, and observer callbacks occur synchronously on the caller's thread. The foundation performs no queue hop.

The production composition is intended to use one shared instance from the app's main/UI execution path. The store is re-entrant-safe but is not designed for simultaneous access from multiple threads and is not `Sendable`.

Rejected: internal locks or dispatch queues. HPA-389's current scene and settings flows are main-thread-owned; adding cross-thread synchronization would increase complexity without a current requirement and could change callback ordering.

### A timing seam without timing policy

HPA-364 defines how downstream code obtains monotonic time but does not define what any interval means.

Rejected: placing generic gates or a scheduler in this ticket. The actual gates and anti-starvation behavior are concrete HPA-389 output policy.

## Semantic feedback contract

The implementation uses these exact consumer-facing types unless HPA-389 is updated first:

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

- `manualDeployment`: an accepted player-requested deployment. Automatic building spawns do not use this event.
- `soldierAttack`: one audible attack category, independent from an asset filename.
- `towerFire`: an authoritative tower firing occurrence.
- `soldierDamage`: distinguishes a surviving hit from a death.
- `buildingChanged`: a successful construction or upgrade mutation.
- `invalidAction`: one rejected actionable player request.
- `goldReward`: newly awarded gold tied to a fresh transition.
- `cityConquest`: a newly finalized city conquest.
- `countryCompletion`: a newly finalized country completion; downstream policy may use it instead of city conquest.
- `fortifiedLaneWarning`: the semantic warning required by HPA-362 and HPA-389, defined before the producer path lands.

The enum is not Codable because HPA-364 does not persist or queue events. It is not platform-specific and imports no UI or media framework.

### Discrete emission

`emit(_:)` represents one semantic occurrence. The protocol does not promise that the event creates an output. Preferences, gates, readiness, deduplication, and platform availability may suppress it downstream.

The method does not throw and returns no value. Feedback is best-effort and must never control gameplay success.

### Automatic-combat batch boundary

`emitAutomaticCombat(_:)` receives one caller-ordered array for one authoritative combat tick.

Fixed semantics:

- Array order is significant and preserved at the boundary.
- An empty batch is valid.
- The call represents one tick, not independent discrete calls.
- HPA-364 does not inspect, select, throttle, queue, replay, or deduplicate the array.
- HPA-389 may select at most one output from the batch according to its scheduler.

The array is intentionally used instead of a new batch model because the foundation has no metadata beyond ordered events.

### No-op provider

```swift
final class NoOpGameplayFeedbackProvider: GameplayFeedbackProviding {
    func emit(_ event: GameplayFeedbackEvent) {}
    func emitAutomaticCombat(_ orderedEvents: [GameplayFeedbackEvent]) {}
}
```

The no-op provider is stateless, performs no logging, and accepts all valid calls. Recording behavior stays in the test target so production code does not retain gameplay history.

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

### Stored fields

The encoded object contains exactly:

- `soundEffectsEnabled`
- `hapticsEnabled`

There is no version, music, volume, mixer, voice, or placeholder field.

Both settings default to `true` so existing users receive the intended player-facing behavior when HPA-389 lands.

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
- A valid keyed object with malformed individual fields is not treated as root corruption.

Completely malformed root data, including invalid JSON or a non-keyed root, is handled by the store rather than by the model.

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

The manager exposes domain-specific setters rather than a general `set(_:)` API. This keeps callers from accidentally replacing a newer sibling preference with a stale full snapshot.

The setters return the resulting full snapshot so settings UI can refresh from the source of truth without a second read.

## Persistent store

The concrete implementation is named `FeedbackPreferencesStore`:

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

Tests inject a unique UserDefaults suite and custom key.

### Initialization

The store reads and decodes persisted data once during initialization and holds the current snapshot in memory.

Consumers do not read UserDefaults per event, render, or scene transition.

Initialization behavior:

1. No data: use `.defaultValue`.
2. Valid keyed data: decode with field-level tolerance.
3. Invalid root data: back up the original bytes under `<key>.corrupt` and use `.defaultValue`.

The corrupt backup is diagnostic evidence only. The store does not repeatedly attempt to decode it or restore it automatically.

### Setter transaction order

For a distinct value, a setter performs this synchronous sequence:

1. Construct and assign the new in-memory `current` snapshot while preserving the sibling field.
2. Encode and write the complete snapshot under the dedicated key.
3. Advance the observation version.
4. Deliver the new snapshot to active observers.
5. Return the new snapshot.

The methods do not throw. Feedback preferences must not prevent gameplay or launch.

The model contains only Booleans, so encoding failure is not expected. A defensive encoding failure leaves the new in-memory snapshot active, emits a diagnostic log, still notifies observers, and is corrected by a later successful distinct setter or next launch defaulting from the last valid persisted value.

### Duplicate suppression

Setting a property to its current value is a no-op:

- No in-memory replacement.
- No persistence rewrite.
- No version change.
- No observer callback.

## Observation behavior

### Registration

`observe` registers the callback and synchronously invokes it once with the current snapshot before returning the token.

There is no delayed first delivery and no requirement for the caller to query `current` separately.

The observer is marked as having received the current store version before the callback is invoked. If that callback performs a nested setter, it may receive the newer snapshot during the nested delivery. The outer initial delivery never sends the older snapshot again after the nested update.

### Delivery guarantees

For each retained and active observer:

- The initial snapshot is delivered synchronously.
- Every distinct later update is delivered synchronously before the setter returns.
- Snapshot versions never decrease for that observer.
- A newer re-entrant update is never followed by a stale outer update.
- Cancellation prevents callbacks that have not begun.

Ordering between different observers is intentionally unspecified. Consumers must not depend on registration order or collection iteration order.

### Re-entrant-safe delivery

The store maintains a monotonically increasing internal version and observer records equivalent to:

```swift
private struct ObserverRecord {
    let callback: (FeedbackPreferences) -> Void
    var lastDeliveredVersion: UInt64
}
```

For one update:

1. Increment the version after memory and persistence handling.
2. Capture the current observer IDs.
3. Before invoking each callback, verify it is still registered.
4. Skip it if its `lastDeliveredVersion` is already equal to or newer than this delivery version.
5. Mark this version delivered before invoking the callback.
6. Invoke the callback with the exact snapshot associated with this version.

This permits callbacks to cancel themselves, cancel other observers, or perform nested preference updates without mutating an active collection iterator or receiving stale-after-new state.

### Cancellation and ownership

The observation token has idempotent cancellation:

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

The cancellation closure captures the store weakly, so retaining a token does not retain the store. The store retains the callback record but not the token. The caller must retain the token to keep observing.

Calling `cancel()` more than once is safe. Releasing the token unregisters the observer.

Callers remain responsible for avoiding a callback retain cycle, for example by capturing a scene or controller weakly when appropriate.

### Threading contract

The store performs no synchronization and no queue hop.

All production access is expected from the same main/UI execution context used by SpriteKit scenes and settings UI. Tests use one thread. Simultaneous multi-threaded access is outside this ticket and is not supported.

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

Tests use a manually controlled clock implementation and never sleep.

## Error handling and recovery

### Missing or older data

Missing data and missing fields use enabled defaults. Older valid fields are preserved independently.

### Partially malformed keyed data

A wrong-typed field defaults to `true` without discarding a valid sibling field. No corrupt backup is created for a valid keyed object with field-level errors.

### Completely corrupt root data

The store:

1. Copies the original bytes to `<key>.corrupt`.
2. Uses `.defaultValue` in memory.
3. Continues launch without throwing.
4. Leaves campaign data untouched.

The store does not erase the corrupt source immediately. The next distinct preference change writes a valid replacement under the primary key.

### Feedback-provider failures

The no-op provider cannot fail. Future concrete output failures belong to HPA-389 and never propagate into this foundation's protocol.

## Repository and dependency boundaries

Create:

- `Pyxis/GameplayFeedback.swift`
- `Pyxis/FeedbackPreferences.swift`
- `Pyxis/FeedbackPreferencesStore.swift`
- Focused test files under `PyxisTests/`

The production files import Foundation only. They do not import SpriteKit, UIKit, AVFAudio, AVFoundation, CoreHaptics, Combine, or SwiftUI.

Do not modify in HPA-364:

- `BattleScene.swift`
- `CountryMapScene.swift`
- `BuildingViewScene.swift`
- `GameViewController.swift`
- `Pyxis.xcodeproj/project.pbxproj`
- Audio assets or license manifests

`PBXFileSystemSynchronizedRootGroup` picks up the new files automatically.

After implementation is green, add a concise architecture note to `CLAUDE.md` describing the foundation and its ownership boundary with HPA-389.

## Test strategy

Use Swift Testing and isolated UserDefaults suites.

### Semantic contract tests

- Construct and compare every event and associated payload.
- Lock attack-category `allCases` ordering as melee, ranged, siege.
- Record discrete and batch calls separately.
- Preserve batch order and accept an empty batch.
- Verify no-op behavior.
- Verify a manual clock can be advanced without sleeping.

### Preference-model tests

- Defaults are both enabled.
- All four Boolean combinations round-trip.
- Encoded keys are exactly the two approved fields.
- Each missing or wrong-typed field defaults independently.
- Unknown fields are ignored.
- No music or volume key appears.
- Consumer-facing protocol signatures compile exactly as required by HPA-389.

### Store tests

- Missing data uses defaults.
- Each setter preserves the sibling field and round-trips through a new store.
- Persistence is independent from the campaign key.
- Partial and wrong-typed keyed data recover per field.
- Root corruption is backed up and does not affect campaign data.
- Initial observation is immediate.
- Distinct updates are synchronous and delivered once.
- Duplicate setters do nothing.
- Explicit cancellation and token release stop delivery.
- Callbacks may cancel themselves or other observers.
- Initial callbacks may perform nested updates without stale re-delivery.
- Later callbacks may perform nested updates without stale-after-new delivery.
- Cross-observer order is not asserted.
- Tokens and stores do not retain one another.

### Verification

Run focused suites, the full `PyxisTests` target, and SwiftLint with parallel testing disabled.

No device smoke is required because this ticket adds no platform output or scene integration.

## Acceptance criteria

- Semantic payloads exactly cover manual deployment, attack category, tower fire, hit/death kind, building change, invalid action, reward, conquest, completion, and fortified warning.
- The provider supports discrete events and one caller-ordered automatic-combat batch per tick.
- The foundation imports no SpriteKit, UIKit, audio, haptic, or reactive-observation framework.
- The production no-op provider accepts both APIs without side effects.
- SFX and haptics are independent persisted Booleans, both defaulting to enabled.
- Encoding contains exactly the two preference keys and no music key.
- Missing, partial, wrong-typed, and corrupt preference data recover according to this design.
- Preference persistence remains independent from campaign progress.
- Observation immediately supplies current state, delivers each distinct update once, supports re-entrant cancellation and updates, and stops after cancellation or token release.
- Per-observer snapshots never regress after a nested update.
- The monotonic-clock contract is replaceable with a manual test clock and requires no sleep.
- The APIs remain compatible with the HPA-389 design and implementation plan.
- Focused tests, the full unit-test target, and SwiftLint pass with parallel testing disabled.

## HPA-389 handoff

HPA-389 may rely on:

- The exact event and payload cases in this document.
- The exact provider and preference-manager signatures.
- Immediate initial preference observation.
- Synchronous distinct-update observation.
- Independent sound and haptic settings.
- A shared `FeedbackPreferencesStore.shared` production instance.
- `SystemMonotonicClock` for deterministic gate calculations.
- No-op behavior for tests and unsupported paths.

HPA-389 must not assume:

- That a semantic event always produces output.
- That automatic-batch items are pre-filtered or selected by HPA-364.
- Cross-observer callback ordering.
- Thread safety or automatic queue hopping.
- Any audio, haptic, UI, asset, lifecycle, or rate-limit implementation from this ticket.

Implementation of HPA-389 remains blocked until this foundation is merged and its contract is verified against the HPA-389 design.

## Resolved decisions

- Event payloads match HPA-389 PR #19.
- The preference model contains exactly two Booleans.
- Preferences persist outside campaign state.
- Observation is synchronous, callback-based, cancellable, and re-entrant-safe.
- Per-observer version order is guaranteed; cross-observer order is not.
- The store is single-thread-confined and performs no internal queueing.
- The monotonic clock is a seam only; all timing policy remains in HPA-389.
- No unresolved design question remains for implementation planning.
