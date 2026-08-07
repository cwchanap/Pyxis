# Gameplay Feedback Deletion-First Simplification Design

**Issue:** HPA-566 — Simplify gameplay feedback architecture through deletion-first refactoring  
**Parent roadmap:** HPA-360 — Enrich Pyxis for casual players without increasing mechanical complexity  
**Related delivered work:** HPA-364, HPA-389  
**Implementation plan:** `docs/superpowers/plans/2026-08-06-gameplay-feedback-deletion-first-simplification-implementation.md`  
**Status:** Design ready for implementation after the HPA-566 start condition is met  
**Date:** 2026-08-06

## Summary

HPA-566 reduces the production and test surface introduced by HPA-364 and HPA-389 without changing the feedback players already experience.

This is a deletion-first maintenance refactor. It is not a new feedback system, not an audio-engine rewrite, and not a prerequisite for the next player-facing roadmap slice.

The target architecture keeps the boundaries that still protect real product behavior:

- scenes emit a small set of semantic discrete events;
- `BattleScene` hands the authoritative `BattleCombatState.TickResult` directly to one automatic-combat scheduler;
- one coordinator owns discrete mapping, preference gating, and simple cooldowns;
- one sound controller owns asynchronous playback, voice allocation, audio-session lifecycle, and interruption safety;
- one two-toggle preference manager persists Sound Effects and Haptics independently of campaign state.

The refactor deletes intermediate policy, projection, directive, gate, and preference-delivery machinery that currently has no independent product responsibility.

## Start condition

HPA-566 remains maintenance work and must not interrupt HPA-366 or HPA-365 solely for cleanup.

Start implementation only when either condition is true:

1. the next higher-value player-facing slice has shipped; or
2. gameplay feedback code must be changed for another justified reason.

Preparing this design and implementation plan does not change that start condition.

## Why simplify now

The delivered feedback feature is valuable, but its internal architecture reflects requirements that were stronger than the current product needs.

Current production behavior is small:

- six reachable discrete feedback occurrences are emitted by scenes;
- automatic combat feedback comes from exactly one `BattleCombatState.TickResult` per combat tick;
- one coordinator consumes those occurrences;
- one settings surface owns exactly two Boolean preferences;
- one audio implementation performs all playback and lifecycle handling.

Several intermediate layers have only one production caller and exist mainly because the original foundation and consumer tickets intentionally separated ownership:

```text
BattleCombatState.TickResult
    -> CombatFeedbackProjector
    -> [GameplayFeedbackEvent]
    -> AutomaticCombatFeedbackScheduler
    -> GameplayFeedbackPolicy
    -> GameplayFeedbackDirective
    -> GameplaySoundOutput.play(sound, soundClass)
```

For discrete feedback, the path is similarly indirect:

```text
Scene
    -> GameplayFeedbackEvent
    -> GameplayFeedbackPolicy
    -> GameplayFeedbackDirective
    -> DefaultGameplayFeedbackCoordinator
    -> sound / haptic output
```

The preference implementation also maintains versioned, ordered, re-entrant observer-delivery semantics for two `@MainActor` toggles, even though only the coordinator and the currently mounted settings controller observe the store in production.

These layers increase the number of types, tests, and invariants an implementation agent must preserve without adding player value.

## Goals

- Preserve all currently observable SFX, haptic, settings, and interruption behavior.
- Reduce production feedback types and lines, not merely move code between files.
- Remove at least one full indirection layer; this design intentionally removes several.
- Make automatic-combat feedback follow the authoritative `TickResult` directly.
- Make `GameplaySoundCatalog` the single source of truth for sound class.
- Reduce preference persistence and observation to what two shared toggles actually need.
- Remove feedback-specific architectural mandates from `CLAUDE.md` while retaining stable product rules.
- Replace implementation-detail tests with behavior-level tests where that enables deletion.
- Leave the repository easier to change when the next real feedback requirement appears.

## Non-goals

This work does not:

- add any new sound, haptic, setting, asset, or player-visible feedback;
- change combat, economy, routing, persistence, or progression rules;
- rewrite the AVAudioEngine backend or sound controller from scratch;
- redesign the settings UI, accessibility behavior, or layout;
- broadly refactor `BattleScene`;
- introduce Combine, Swift Observation, NotificationCenter, an event bus, dependency-injection framework, lifecycle framework, or generalized feedback registry;
- preserve speculative APIs for music, voice-over, multiplayer, live-service, or unvalidated future mechanics;
- add backward-compatibility migration for development-only feedback preferences.

## Player-visible behavior contract

The following behavior is authoritative for this refactor.

### Discrete gameplay feedback

| Occurrence | Sound | Haptic | Cooldown |
| --- | --- | --- | --- |
| Accepted manual deployment | `deployment` | light impact | 120 ms independently per channel |
| Successful building construction/upgrade | `construction` | medium impact | 250 ms independently per channel |
| Invalid/blocked player action | `blocked` | warning | 500 ms independently per channel |
| Gold reward | `goldReward` | none | none |
| City conquest | `cityConquest` | strong success | none |
| Country completion | `countryCompletion` | strong success | none |

Disabled sound suppresses only sound. Disabled haptics suppress only haptics. Re-enabling one channel must not incorrectly consume or reset the other channel's cooldown state.

Fresh conquest keeps reward feedback before outcome feedback. Restored conquest reports, resize, background catch-up reconstruction, and other non-fresh presentation paths must not replay stale feedback.

### Automatic combat feedback

Automatic combat remains sound-only.

One authoritative `BattleCombatState.TickResult` is processed per combat tick. Duplicate signals in that result are coalesced into these candidate families in this priority order:

1. soldier death;
2. tower fire;
3. siege attack;
4. ranged attack;
5. melee attack;
6. non-fatal soldier hit.

The existing timing behavior remains:

- 150 ms global successful-output gate;
- 200 ms per attack category;
- 250 ms tower-fire gate;
- shared 300 ms soldier hit/death gate;
- suppressed sounds are dropped and are never queued or replayed;
- while attacks remain eligible, no more than two successful global windows may be consumed by non-attack sounds before an attack is reserved;
- reserved attacks rotate siege -> ranged -> melee.

Automatic combat does not produce haptics.

### Preferences and settings

The settings surface remains exactly:

- Sound Effects on/off;
- Haptics on/off;
- Close.

Both values default to enabled.

Changes apply immediately, survive scene replacement, and persist across relaunch. Disabling sound while sound is active immediately stops and deactivates current SFX output.

The settings modal continues to block underlying scene input and retains current accessibility behavior.

### Audio lifecycle

The following behavior remains owned by the existing sound output implementation:

- preparation remains asynchronous;
- sound received before readiness is dropped, not queued;
- automatic and protected/non-automatic voice capacity remains bounded;
- activation failures drop the current sound and use the existing retry cooldown;
- backgrounding, interruption, and sound disable stop active output and clear scheduled buffers;
- recovery never replays stale effects;
- ordinary foreground recovery preserves the existing fresh-output path.

These rules justify keeping the audio controller's queueing and lifecycle state even though other feedback layers are deleted.

## Caller analysis

### `GameplayFeedbackPolicy`

Production caller: `DefaultGameplayFeedbackCoordinator` only.

It maps one semantic event to one `GameplayFeedbackDirective`, and the coordinator immediately unpacks that directive. It has no independent product responsibility.

**Decision:** delete the policy type and file. Inline the small discrete switch into the coordinator.

### `GameplayFeedbackDirective`

Production use: transport object between the policy and coordinator only.

**Decision:** delete it.

### `GameplayGateID`

Production use: keys a coordinator dictionary and converts back to an interval through another switch.

**Decision:** delete it. Store timestamps directly by discrete event/channel or use two small dictionaries keyed by `GameplayFeedbackEvent`.

### `CombatFeedbackProjector`

Production caller: `BattleScene` only.

It converts one `TickResult` into automatic-only semantic events that are immediately consumed by one scheduler.

**Decision:** delete it. The scheduler consumes `TickResult` directly and derives automatic sound candidates internally.

### Automatic-only semantic payload types

`SoldierAttackSoundCategory` and `SoldierDamageSoundKind` exist to carry data between the projector, scheduler, and policy.

After the projector/policy collapse, they have no scene-facing product responsibility.

**Decision:** delete them from the public feedback contract. The scheduler may use a private attack-category enum if useful, but the preferred implementation rotates concrete `GameplaySoundID` attack cases directly.

### `fortifiedLaneWarning`

No production producer exists. Its intended producer is HPA-362, which remains an evidence-gated experiment and may never ship.

**Decision:** remove `.fortifiedLaneWarning`, `.fortifiedWarning`, the unused asset/catalog row, related manifest row, and tests. If HPA-362 later ships and needs a warning, that ticket reintroduces the smallest concrete implementation then.

### `GameplaySoundClass` at the output call boundary

The sound catalog already stores whether every resource is `.automaticCombat` or `.nonAutomatic`, while the coordinator also supplies the class on every play call.

**Decision:** `GameplaySoundCatalog` becomes the sole authority. Change the playback call to `play(_ sound: GameplaySoundID)`. The sound controller looks up the class from its catalog before selecting a voice.

This removes a possible policy/catalog consistency bug and deletes tests whose only purpose is verifying the duplicated values agree.

### Preference observation

Only two production consumers currently observe preferences:

1. `DefaultGameplayFeedbackCoordinator` — needs immediate notification so disabling sound stops active playback.
2. `FeedbackSettingsController` — uses observation to keep its local snapshot current.

The settings controller itself performs all user mutations while mounted. It can read `current` when opening and apply the setter's returned snapshot after each toggle; it does not need continuous observation.

**Decision:** remove settings-controller observation and retain only a small synchronous cancellable observer mechanism for the coordinator.

The observer implementation does not need ordered callback delivery, delivery versions, stale-outer-snapshot suppression, or re-entrant registration semantics beyond safe iteration over the currently registered callbacks.

## Target production architecture

```text
BattleScene / CountryMapScene / BuildingViewScene
                 |
                 | discrete semantic events
                 v
      GameplayFeedbackProviding
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
    | TickResult
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

`NoOpGameplayFeedbackProvider` remains so scenes can keep lightweight defaults in tests/previews without constructing the production runtime.

`Hashable` is sufficient and allows the coordinator to key timestamp dictionaries directly. No feedback event is persisted or sent across a public API.

### Automatic scheduler

```swift
struct AutomaticCombatFeedbackScheduler {
    mutating func selectSound(
        from result: BattleCombatState.TickResult,
        at now: TimeInterval
    ) -> GameplaySoundID?
}
```

The scheduler owns only automatic-combat selection state.

It derives whether death, tower fire, each audible attack family, and non-fatal hit are present directly from the result. It maps soldier types as follows:

- Infantry/Cavalry -> `.attackMelee`;
- Archer/Mage -> `.attackRanged`;
- Siege -> `.attackSiege`.

Fatal soldiers must not also create `.soldierHit` eligibility.

The scheduler returns at most one sound ID for each call.

### Sound output

```swift
protocol GameplaySoundOutput: AnyObject {
    func prepareIfNeeded()
    func play(_ sound: GameplaySoundID)
    func stopAllAndDeactivate()
}
```

`GameplaySoundOutputController` resolves `GameplaySoundClass` from its injected catalog and uses that class for voice selection. If the sound has no catalog entry, the current event is dropped and a diagnostic assertion/log is acceptable in debug builds; no fallback sound or queued work is introduced.

`GameplaySoundClass` remains because the catalog and voice allocator still need the automatic/protected distinction internally.

### Preference contract

Keep the small snapshot used by settings and coordinator:

```swift
struct FeedbackPreferences: Equatable, Sendable {
    static let defaultValue = FeedbackPreferences()

    var soundEffectsEnabled: Bool = true
    var hapticsEnabled: Bool = true
}
```

The production manager remains injectable:

```swift
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

Observation remains synchronous and cancellable because the coordinator must stop active sound as soon as sound is disabled.

No other ordering or re-entrancy guarantee is part of the product contract.

## Preference persistence design

Replace the encoded JSON object with two direct `UserDefaults` Boolean keys:

```text
pyxis.feedback.soundEffectsEnabled
pyxis.feedback.hapticsEnabled
```

Loading uses `object(forKey:) as? Bool ?? true` for each field so missing values default to enabled without interpreting `false` as missing.

Each setter:

1. returns immediately when the value is unchanged;
2. updates the in-memory snapshot;
3. writes only the changed Boolean to the dedicated key;
4. synchronously notifies a snapshot of registered observers;
5. returns the resulting snapshot.

The store continues to require an explicit `UserDefaults` instance outside `.shared` so tests remain isolated.

### Development preference reset

The previous `pyxis.feedbackPreferences` JSON key is development-only and predates a public release.

This refactor deliberately performs no migration from that key. Existing development installs may see both feedback toggles return to enabled once. That is acceptable under the roadmap's pre-release compatibility rule and materially simplifies the implementation.

Do not add a temporary migration branch, old-key decoder, cleanup version, or compatibility shim.

Campaign state under `pyxis.kingdomGameState` remains untouched.

## Coordinator design

`DefaultGameplayFeedbackCoordinator` remains the single product-level owner of emitted/suppressed feedback behavior.

It keeps:

- current preferences;
- one preference observation token;
- sound output;
- haptic output;
- monotonic clock;
- simple per-channel discrete cooldown timestamps;
- automatic combat scheduler.

### Discrete mapping

Use one exhaustive switch on the six reachable discrete events. The mapping belongs here because it has exactly one consumer and is small enough to read in one place.

The implementation should prefer explicit calls over recreating a directive-like transport object.

Example shape:

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

Use separate sound and haptic timestamp dictionaries keyed by event. This retains independent-channel cooldown behavior without introducing a gate-ID abstraction.

### Automatic mapping

`emitAutomaticCombat(_:)`:

1. checks `currentPreferences.soundEffectsEnabled` before invoking the scheduler so disabled sound does not advance scheduler state;
2. asks the scheduler for at most one sound ID;
3. plays that sound ID when present.

The coordinator does not rebuild an automatic event array or route the selected sound back through the discrete mapping switch.

## Settings controller design

Remove `preferenceObservation` from `FeedbackSettingsController`.

The controller owns a local `preferences` snapshot only while rendering the modal.

- `open()` refreshes `preferences = preferencesManager.current` before applying the modal.
- `toggleSoundEffects()` calls the manager setter and immediately applies the returned snapshot.
- `toggleHaptics()` does the same.
- scene replacement naturally constructs a new controller against the same shared manager and reads the latest persisted state.

No external production actor changes preferences behind an open modal, so continuous settings observation is unnecessary.

## Audio implementation boundary intentionally retained

`GameplaySoundOutputController` is not a target for architectural collapse beyond removing the redundant `soundClass` parameter.

Its complexity protects real behavior:

- preparation and voice creation occur away from the caller;
- requests during preparation are dropped rather than replayed later;
- voice allocation distinguishes automatic from protected output;
- backend mutations are serialized;
- activation retry is bounded;
- interruption/background/reset paths invalidate stale output.

HPA-566 must not trade these guarantees for a shorter file.

Similarly, `AVAudioEngineGameplayAudioBackend`, `FeedbackSettingsAccessibilityAdapter`, settings layout types, and scene-specific gear placement remain outside the refactor unless compilation requires a mechanical signature update.

## Removal of speculative fortified warning

Delete all current fortified-warning-only artifacts:

- `GameplayFeedbackEvent.fortifiedLaneWarning`;
- `GameplaySoundID.fortifiedWarning`;
- `fortified-warning.caf`;
- the catalog entry;
- the `docs/audio-assets.md` manifest row;
- tests whose only purpose is the unreachable warning.

Do not delete general audio license files because remaining assets still use them.

HPA-362 owns any future decision to reintroduce a lane-warning cue if that gameplay experiment is actually shipped.

## Documentation rule after HPA-566

`CLAUDE.md` should describe stable product behavior, not the historical HPA-364/HPA-389 ownership split.

Replace the current feedback-specific architecture mandates with concise rules such as:

- Gameplay feedback is observational and must not mutate gameplay state.
- Keep output restrained; automatic combat remains coalesced/rate-limited rather than continuous noise.
- Honor disabled sound/haptic preferences immediately.
- Never queue or replay stale SFX after readiness failure, backgrounding, or interruption.
- Settings remain Sound Effects and Haptics only until a concrete player need justifies another option.
- Do not introduce a new feedback policy/framework/category without a current shipping consumer.

Historical HPA-364/HPA-389 specs and plans remain in `docs/superpowers/` as implementation history. HPA-566 does not rewrite those records.

## Testing strategy

Tests should protect observable behavior and the small remaining pure policy, not the exact shape of deleted architecture.

### Keep or reshape

- Coordinator tests for emitted/suppressed discrete sound and haptic behavior.
- Coordinator test that disabling sound immediately calls `stopAllAndDeactivate()`.
- Automatic scheduler tests for gate boundaries and attack fairness.
- One dense `TickResult` test proving death/tower/attack/hit selection behavior.
- Settings-controller tests for immediate toggle update and modal state.
- Scene-flow tests proving semantic occurrences are still emitted from representative player actions.
- Sound-controller lifecycle/readiness/voice tests because they cover retained real-risk behavior.
- Catalog resource, duration, bundle, and license-manifest tests for remaining assets.

### Delete

- Tests that only assert `GameplayFeedbackDirective` structure.
- Tests that only prove policy sound class equals catalog sound class.
- Tests that compile-lock the obsolete HPA-364/HPA-389 ownership boundary.
- Projector tests once their meaningful behavior is covered through the scheduler's `TickResult` input.
- Preference tests for JSON field tolerance, corrupt-root backups, injected encoder failure, observer version monotonicity, nested registration, cross-cancellation ordering, duplicate closure semantics, and stale outer-snapshot suppression.
- Tests for the unreachable fortified warning.

### Preference tests after simplification

Keep a small set:

1. missing keys load both values enabled;
2. each setter persists its Boolean and preserves the sibling value;
3. unchanged setter does not notify;
4. observer receives current state then distinct updates synchronously;
5. cancellation stops future updates;
6. isolated `UserDefaults` never writes campaign state or process-standard test keys;
7. relaunch round-trip preserves both values.

## Expected file changes

### Delete

- `Pyxis/GameplayFeedbackPolicy.swift`
- `Pyxis/CombatFeedbackProjector.swift`
- `PyxisTests/GameplayFeedbackPolicyTests.swift`
- `PyxisTests/CombatFeedbackProjectorTests.swift`
- `Pyxis/Resources/Audio/Gameplay/fortified-warning.caf`

### Modify materially

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
- `PyxisTests/DefaultGameplayFeedbackCoordinatorTests.swift`
- `PyxisTests/AutomaticCombatFeedbackSchedulerTests.swift`
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

Other scene tests may need mechanical updates if their recording provider signature changes. Do not use that as a reason to redesign those scenes.

## Deletion-first success metric

The implementation PR must show a net reduction in production feedback code.

At minimum:

- the five listed production/test/asset files are removed;
- `GameplayFeedbackDirective`, `GameplayGateID`, `SoldierAttackSoundCategory`, and `SoldierDamageSoundKind` are removed;
- the preference store loses its JSON/observer-version machinery;
- the implementation adds no replacement framework or generic abstraction;
- total production lines deleted exceed production lines added for feedback-related Swift files.

A refactor that moves the same concepts into differently named files does not satisfy HPA-566.

## Risks and mitigations

### Scheduler behavior changes while merging projection

**Risk:** coalescing order or fatal-hit exclusion changes accidentally.

**Mitigation:** build scheduler tests from concrete `TickResult` fixtures before deleting the projector, then compare the selected sound sequence at the exact existing timing boundaries.

### Independent sound/haptic cooldown regression

**Risk:** replacing separate gate IDs with a single event timestamp causes one disabled channel to consume the other's cooldown.

**Mitigation:** use separate sound and haptic timestamp dictionaries and retain the existing re-enable boundary tests at the behavior level.

### Sound class drift after removing the call parameter

**Risk:** a missing catalog entry prevents voice selection.

**Mitigation:** catalog completeness remains tested for every `GameplaySoundID`; the controller drops an unmapped sound rather than guessing.

### Preference reset surprises during development

**Risk:** existing development installs lose disabled-toggle choices once.

**Mitigation:** explicitly document the one-time pre-release reset in the implementation PR. Do not add migration code solely to avoid it.

### Over-deleting lifecycle complexity

**Risk:** deletion-first work expands into unsafe audio simplification.

**Mitigation:** treat audio readiness, voice allocation, backend serialization, and interruption state as protected boundaries. Only the redundant class parameter changes there.

## Acceptance criteria mapping

HPA-566 acceptance criteria map to this design as follows:

- **Existing player-visible SFX, haptics, and settings behavior remains unchanged:** preserved by the explicit behavior contract and manual smoke.
- **Production feedback code has a net reduction in types and lines:** required by the deletion-first success metric.
- **At least one unnecessary indirection/policy layer is removed:** policy, directive, projector, and gate layers are all removed.
- **Tests focus on emitted/suppressed feedback and settings behavior:** test strategy deletes directive/observer-version contracts and retains behavior tests.
- **Full unit suite passes:** required by the implementation plan verification phase.
- **PR lists deletion, retained behavior, and intentionally retained complexity:** required by the implementation handoff and PR template in the paired plan.

## Decision summary

The target is intentionally boring:

- one small scene-facing discrete event enum;
- one direct `TickResult` automatic path;
- one coordinator switch;
- one scheduler;
- one catalog-owned sound classification;
- one simple two-Boolean store;
- the existing mature audio and accessibility machinery left alone.

That is sufficient for the current game and leaves future feedback work free to add a new abstraction only when a concrete shipping consumer proves it is needed.
