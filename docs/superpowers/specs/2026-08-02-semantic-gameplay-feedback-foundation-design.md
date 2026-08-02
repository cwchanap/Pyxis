# Semantic Gameplay Feedback Foundation Design

**Issue:** HPA-364  
**Consumer:** HPA-389  
**Related producer:** HPA-362 — adds direct manual lane deployment and emits the fortified-lane warning when a successful deployment uses the fortified lane.  
**Implementation plan:** Maintained in Linear and intentionally not duplicated in this design-only PR; a repository-local plan may be added with the implementation PR after this design merges.  
**Status:** Third-pass review incorporated  
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

HPA-362 is related but is not a merge precondition for HPA-364 or HPA-389. Until HPA-362 lands, `fortifiedLaneWarning` is an accepted unreachable/dead semantic case: HPA-389 may contain its mapping, but no current `main` producer emits it. HPA-362 becomes the sole producer when direct fortified-lane deployment is implemented.

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

### Audible category names and collapse are intentional

`SoldierAttackSoundCategory` and `SoldierDamageSoundKind` are audible classifications consumed by HPA-389. They are not a general gameplay taxonomy and must not be reused as the basis for unrelated mechanics.

The reviewed HPA-389 mapping is explicit: Infantry and Cavalry map to `.melee`; Archer and Mage map to `.ranged`; Siege maps to `.siege`. Magic attacks intentionally receive no distinct category or sound family in this contract. HPA-389 still owns the mapping implementation, but changing this three-category product decision requires a coordinated shared-contract revision.

`SoldierAttackSoundCategory` remains `CaseIterable` so HPA-389 can write completeness checks across all attack categories. `allCases` has no priority or scheduler-order meaning. The anti-starvation rotation is the separately specified explicit order siege → ranged → melee. `SoldierDamageSoundKind` is not `CaseIterable` because damage kinds share one scheduling family and require no category rotation or catalog-completeness enumeration.

### Dedicated preference storage instead of campaign-state fields

Feedback preferences use their own `UserDefaults` key and data model. Campaign reset or save recovery must not unexpectedly reset sensory preferences.

### Small callback protocol instead of Combine, Observation, or NotificationCenter

The manager exposes one current snapshot and returns a cancellable token from `observe`.

- Combine would add an unnecessary publisher lifecycle.
- Swift Observation is not needed for this small cross-scene contract.
- NotificationCenter would provide weaker typing and cancellation ownership.

### Synchronous single-executor delivery

Reads, setters, persistence writes, and observer callbacks occur synchronously on the caller's execution context. The foundation performs no queue hop.

Production uses one shared instance from the main/UI executor. The store is re-entrant-safe but intentionally non-`Sendable` and does not support simultaneous access from multiple threads.

The current app target builds in Swift 5 language mode with approachable concurrency and `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. That module-wide default already models production access as main-actor-oriented; the project does not rely only on `MEMBER_IMPORT_VISIBILITY`. Caller discipline remains the Swift 5 runtime rule, but it is not the complete Swift 6 migration story. If the project enables Swift 6 language mode without an equivalent main-actor default, the intended migration is to make `FeedbackPreferencesStore` explicitly `@MainActor` and keep its protocol conformance/call sites actor-compatible. No actor, lock, queue, or asynchronous API redesign is intended.

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
- HPA-389's projector and scene integration must place only `soldierAttack`, `towerFire`, and `soldierDamage` in this batch.
- HPA-389 may select at most one output from the batch.

The automatic-only membership rule is a consumer invariant. HPA-364 intentionally adds no runtime validation or second batch model.

### No-op and recording providers

```swift
final class NoOpGameplayFeedbackProvider: GameplayFeedbackProviding {
    func emit(_ event: GameplayFeedbackEvent) {}
    func emitAutomaticCombat(_ orderedEvents: [GameplayFeedbackEvent]) {}
}
```

HPA-364 ships `NoOpGameplayFeedbackProvider` as a production type. It is stateless and performs no logging.

A recording provider is test infrastructure only. HPA-364 defines a recorder privately in `PyxisTests/GameplayFeedbackTests.swift` to verify the protocol and order-preserving batch boundary. HPA-389 may define an equivalent shared test helper in `PyxisTests/GameplayFeedbackTestDoubles.swift`; neither ticket adds a production recorder or a `#if DEBUG` event history.

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

`FeedbackPreferences` implements a custom `init(from:)` for field-tolerant decoding and relies on compiler-synthesized `encode(to:)` to encode both stored properties. A private `CodingKeys` enum contains exactly the two approved keys.

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
    static let shared = FeedbackPreferencesStore(defaults: .standard)

    private(set) var current: FeedbackPreferences

    init(
        defaults: UserDefaults,
        key: String = "pyxis.feedbackPreferences"
    )
}
```

### Storage isolation

The production key is exactly `pyxis.feedbackPreferences`.

The campaign save remains under `pyxis.kingdomGameState`. The preference store never reads, writes, removes, or migrates the campaign key.

The `defaults` argument has no default. Production passes `.standard` explicitly only at `.shared`; tests must supply an isolated suite, so `FeedbackPreferencesStore()` cannot silently bind to process-level defaults.

Tests inject a unique `UserDefaults` suite and custom key and never access `FeedbackPreferencesStore.shared`. A dedicated isolation test uses a unique key, constructs the store with an isolated suite, and verifies `UserDefaults.standard` has no value for that key before or after construction/mutation.

### Initialization

The store loads once during initialization:

1. No data: use `.defaultValue`.
2. Valid keyed data: decode with field-level tolerance.
3. Invalid root data: back up the original bytes under `<key>.corrupt` and use `.defaultValue`.

The corrupt backup is diagnostic evidence only and is not automatically restored. `<key>.corrupt` is a single latest-corruption slot: a later root corruption overwrites the previous backup. Successful loads and writes do not clear it automatically; it remains until an explicit future cleanup or migration removes it.

### Setter transaction order

For a distinct value, a setter synchronously:

1. Constructs and assigns the new in-memory snapshot while preserving the sibling field.
2. Encodes and writes the complete snapshot under the dedicated key.
3. Advances the observation version.
4. Delivers the new snapshot to active observers.
5. Returns the new snapshot.

The methods do not throw.

`KingdomGameStore.save` also treats encoding as best-effort by returning without throwing when encoding fails. This store preserves that non-throwing behavior and improves it with diagnostic logging plus continued observer delivery. Because the model contains only Booleans, encoding failure is not expected. A defensive encoding failure leaves the new in-memory snapshot active, logs diagnostically, and still notifies observers. A later successful distinct setter persists a newer snapshot. If no later write succeeds, the next launch loads the last successfully persisted snapshot, which may be older than the in-memory change.

### Duplicate suppression

Setting a property to its current value performs:

- No in-memory replacement.
- No persistence rewrite.
- No version change.
- No observer callback.

### `current` during delivery

`current` always reflects the latest committed in-memory snapshot, not necessarily the version represented by a callback currently executing. A nested setter may therefore advance `current` while an outer callback still holds an older, valid callback argument.

Observers must use the snapshot argument passed to their callback when reacting to that delivery. Reading `manager.current` inside a callback is allowed for an explicit latest-state query, but it may skip intermediate delivery state and is outside the stale-after-new guarantee.

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

### Threading contract

The store performs no synchronization and no queue hop. Production access is confined to the main/UI executor. Tests use one thread or main-actor isolation as required by the active language mode. Simultaneous access from multiple executors is unsupported.

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

Missing data and fields use enabled defaults. Valid older fields are preserved independently.

### Partially malformed keyed data

A wrong-typed field defaults to `true` without discarding a valid sibling field. No corrupt backup is created for a valid keyed object.

### Completely corrupt root data

The store:

1. Copies original bytes to `<key>.corrupt`.
2. Logs a diagnostic.
3. Uses `.defaultValue`.
4. Continues launch.

A later root corruption replaces the single `<key>.corrupt` backup. Valid preference writes do not clear that backup. The store never deletes or overwrites campaign data.

### Persistence failure

UserDefaults writes are best-effort. Failure does not roll back in-memory state or block callbacks. The next launch uses the last successfully persisted snapshot.

## Repository shape

Create:

- `Pyxis/GameplayFeedback.swift` — semantic events, audible payload types, provider/no-op, `MonotonicClock`, and `SystemMonotonicClock`.
- `Pyxis/FeedbackPreferences.swift` — exact model, tolerant decoding, synthesized encoding, and public manager/token protocols.
- `Pyxis/FeedbackPreferencesStore.swift` — dedicated persistence, corruption recovery, observer records, and token implementation.
- `PyxisTests/GameplayFeedbackTests.swift` — semantic contract, test-local recorder, batch-order, and manual-clock tests.
- `PyxisTests/FeedbackPreferencesTests.swift` — defaults, exact encoding keys, tolerant decoding, and compile-only consumer signatures.
- `PyxisTests/FeedbackPreferencesStoreTests.swift` — isolated persistence, corruption lifecycle, observation, cancellation, ownership, and re-entrancy tests.

Modify only after implementation is green:

- `CLAUDE.md` — document the HPA-364/HPA-389 ownership and composition boundary.

Do not modify scenes, `GameViewController`, platform feedback code, assets, CI configuration, or `Pyxis.xcodeproj/project.pbxproj`.

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

The helper locks consumer-visible names, payloads, return values, and callable signatures without adding production code or runtime behavior.

## Test strategy

### Semantic contract

- Construct and compare every event and payload.
- Verify the complete attack-category case set without asserting declaration order.
- Verify that `allCases` is completeness-only and that the explicit scheduler rotation remains HPA-389's siege → ranged → melee policy.
- Record discrete calls separately from batch calls.
- Verify batch order and empty-batch identity.
- Verify no-op behavior.
- Verify a manual clock without sleeps.

### Preference model

- Defaults and all Boolean combinations.
- Exactly two encoded keys using default JSON key strategies.
- Synthesized encoding writes both fields after custom decoding is introduced.
- No music or volume keys.
- Missing-field, wrong-type, unknown-field, and round-trip behavior.
- Compile-only consumer-signature checks.

### Persistent store

Every test uses an isolated `UserDefaults` suite and key and never uses `.shared`.

Cover:

- Missing, valid, partial, wrong-typed, and corrupt data.
- Dedicated-key isolation from campaign state.
- Corrupt backup, second-corruption overwrite, and persistence across later valid loads/writes.
- Required explicit `defaults` injection and no writes to `UserDefaults.standard` for an isolated-store key.
- Independent persistence.
- Immediate initial delivery.
- Distinct update delivery and duplicate suppression.
- Self- and cross-cancellation.
- Token release.
- Nested setters during initial and later callbacks.
- Cross-observer stale-after-new prevention.
- Callback arguments remain version-specific while `current` may reflect a newer nested snapshot.
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

If the named simulator is unavailable, list destinations and select an available supported iPhone simulator. CI must use a destination present on the selected runner image; a missing simulator is infrastructure failure, not a test assertion failure.

## Acceptance criteria

- Semantic payloads cover manual deployment, attack category, tower fire, hit/death, building change, invalid action, reward, conquest, completion, and fortified warning.
- The provider supports discrete events and one ordered automatic-combat batch per tick.
- Production foundation files import Foundation only.
- The production target contains a no-op provider and no recording provider; a test-local recorder verifies provider behavior.
- Preferences have exactly two stored Booleans with enabled defaults and explicit `defaultValue`/default-valued initialization.
- Custom tolerant decoding and synthesized encoding preserve both exact keys.
- Fail-open field recovery is documented and tested.
- Preference persistence is independent from campaign persistence.
- Missing, partial, wrong-typed, and corrupt data recover safely.
- `<key>.corrupt` uses documented latest-backup overwrite and retention semantics.
- Observation is synchronous, cancellable, duplicate-suppressed, re-entrant-safe, and per-observer version-monotonic.
- `current` is latest-state while callback arguments are delivery-version-specific.
- Re-entrant registration and duplicate registrations have explicit deterministic semantics.
- Cross-observer callback order is unspecified.
- The store is intentionally non-`Sendable` and confined to one executor; the Swift 6 remedy is explicit main-actor isolation rather than caller discipline alone.
- The initializer requires explicit `UserDefaults`; tests never use `.shared` and verify isolated construction does not write the unique test key to `.standard`.
- `GameplayFeedback.swift` owns the monotonic-clock seam, which is replaceable without sleeps.
- Compile-only tests lock every HPA-389-visible constructor, property, method, payload, and return value.
- Full unit tests and SwiftLint pass with parallel testing disabled.

## HPA-389 handoff

HPA-389 may assume:

- Exact semantic event types and payloads.
- Exact preference model, defaults, manager, and observation signatures.
- One shared synchronous preference store.
- One ordered automatic batch per tick.
- A production no-op provider and test-only recording support.
- An injectable monotonic clock.

HPA-389 must not assume:

- HPA-364 maps or schedules output.
- HPA-364 imports platform media or haptic frameworks.
- Events are persisted or replayed.
- Automatic batches have already been projected, validated, selected, throttled, or coalesced.
- Observer callback order between separate registrations.

## Change control

After PR #20 merges, this document on `main` is the HPA-364 shared-contract authority. PR #19 must consume it and retain an equivalent authority statement before HPA-389 implementation begins.

Any change to event cases, payload types, preference fields/defaults, manager signatures, batch semantics, observation guarantees, or clock signatures requires both designs to be updated and re-reviewed.
