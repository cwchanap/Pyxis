# Typed Battle Events and Active-Siege Result Design

**Issue:** HPA-363  
**Date:** 2026-07-30  
**Status:** Approved

## Goal

Give conquest reports and the future Campaign Chronicle a trustworthy,
persistent battle-result boundary without shipping either UI in this ticket.

Today `BattleCombatState.TickResult` exposes aggregate city damage and
soldier IDs after dead soldiers may already have been pruned.
`BattleScene` alone cannot own siege statistics because players route through
Building View or the country map, background the app, reconstruct scenes, or
relaunch before conquering the current city. Conquest currently awards gold
and flips `stageStatus` with no durable result payload.

HPA-363 adds:

1. Typed live combat events emitted before roster pruning.
2. A persistent `ActiveSiegeSession` owned by `KingdomGameState`.
3. Idle (and settlement) damage attribution by soldier type.
4. A finalized Codable `BattleResult` with pending acknowledgment.
5. A conquest mutation shell `completeCurrentCity(with:)` that HPA-367 can
   extend with Chronicle writes.

## Dependencies and Fixed Contracts

- HPA-388 renders the conquest popup from `pendingBattleResult` only. This
  ticket does not change popup layout.
- HPA-367 copies/references the finalized result into Chronicle records. This
  ticket does not add Chronicle storage or completed-city cards.
- Combat balance, gold formulas, idle scale (`idleBuildingProductionScale`),
  and city progression are unchanged.
- Pure models remain free of SpriteKit/UIKit.
- Existing saves must decode without fabricated siege history.

## Scope

### In scope

- Replace attack/kill ID arrays on `TickResult` with typed event payloads.
- Persist an additive `ActiveSiegeSession` and `pendingBattleResult` on
  `KingdomGameState`.
- Accumulate deployments, applied damage, losses, idle damage, markers, and
  active battle time.
- Finalize a compact `BattleResult` at live and idle/settlement conquest.
- Introduce `completeCurrentCity(with:)` and
  `acknowledgePendingBattleResult()`.
- Normalize corrupt/mismatched session and pending-result data on decode.
- Pure-model and integration tests covering the acceptance criteria.

### Non-goals

- Conquest popup or report layout (HPA-388).
- Chronicle records and completed-city UI (HPA-367).
- Remote analytics, telemetry, leaderboards, or sharing.
- Detailed per-soldier timelines or replay.
- Changing combat balance, rewards, or city progression.
- Making Building View or map time count as active battle time.

## Decisions Locked in Brainstorming

| Topic | Decision |
| --- | --- |
| Conquest mutation | Introduce `completeCurrentCity(with: BattleResult)` now; Chronicle write is a future no-op hook for HPA-367. |
| Gold | Embed authoritative `goldEarned` on `BattleResult`. |
| `TickResult` shape | Replace `soldierAttackIDs` / `killedSoldierIDs` with event arrays. Keep tower presentation data separate. |
| Favorable / exposed markers | Flip on first matching **deployment** (manual or building), not on damage. |
| Tallies | Flat Codable summary rows, not nested maps or fixed sparse tables. |
| Module shape | Pure session/result types in a dedicated model file; `KingdomGameState` owns lifecycle and persistence. |

## Architecture and Ownership

```text
BattleCombatState.tick
  -> SoldierAttackEvent / SoldierLossEvent (+ TowerShot / damaged IDs)
       |
       v
BattleScene (and idle/settle paths on KingdomGameState)
  -> ActiveSiegeSession accumulate APIs
       |
       v
KingdomGameState.completeCurrentCity(with: BattleResult)
  -> gold, HP, buildings clear, stageStatus, pendingBattleResult
       |
       v
HPA-388 popup reads pendingBattleResult
HPA-367 later writes Chronicle from the same result
```

`BattleCombatState` emits attribution. It does not own the session.
`ActiveSiegeSession` is a pure accumulator/finalizer.
`KingdomGameState` owns optional session + pending result, decode
normalization, and conquest/acknowledgment mutations.
Scenes forward events and active time; they never rebuild statistics from
SpriteKit nodes.

## 1. Typed Combat Events

### Event payloads

Add framework-free immutable values (exact type names may match these):

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

Semantics:

- Events are emitted **before** dead soldiers are removed from the roster.
- `appliedCityDamage` is already clamped to the tick-local remaining city HP.
  Nominal attack power must not inflate report totals on the killing blow.
- Each killed soldier emits exactly one `SoldierLossEvent`.
- Clearing live combat because of scene routing, backgrounding, or
  reconstruction is **not** a soldier loss and must not invent loss events.

### `TickResult` migration

Replace:

- `soldierAttackIDs: [SoldierID]`
- `killedSoldierIDs: [SoldierID]`

with:

- `soldierAttacks: [SoldierAttackEvent]`
- `soldierLosses: [SoldierLossEvent]`

Retain:

- `cityDamage: Int` as the sum of `soldierAttacks.map(\.appliedCityDamage)`
  for convenience and existing call-site compatibility where aggregate damage
  is enough.
- `didReachConquest: Bool` as today (informational; authoritative conquest
  remains `KingdomGameState`).
- `towerShots: [TowerShot]` and `damagedSoldierIDs: [SoldierID]` for hit FX.
  Tower presentation must not require looking up a soldier that has already
  been pruned: either continue recording the target ID while the soldier still
  exists in the tick, or enrich `TowerShot` if a future change needs type
  without roster lookup. This ticket does not require typed tower events for
  siege accounting.

`BattleScene` reads attack/loss IDs from the event payloads for animation and
node removal. It must not keep a parallel stats accumulator.

## 2. Summary Rows and Session Model

### Flat summary rows

```swift
struct SiegeDeploymentCount: Codable, Equatable {
    var type: SoldierType
    var source: SoldierSpawnSource
    var lane: BattleLane
    var count: Int
}

struct SiegeDamageAttribution: Codable, Equatable {
    var type: SoldierType
    var source: SoldierSpawnSource
    var lane: BattleLane
    var damage: Int
}

struct SiegeLossCount: Codable, Equatable {
    var type: SoldierType
    var source: SoldierSpawnSource
    var count: Int
}

struct SiegeIdleDamageByType: Codable, Equatable {
    var type: SoldierType
    var damage: Int
}
```

Rows with `count == 0` or `damage == 0` are omitted from storage. Accumulation
merges into an existing matching row or appends a new one. Encode/decode order
is normalized (stable sort by type/`SoldierType.allCases` order, then source,
then lane) so equality and tests stay deterministic.

`BattleLane` becomes `Codable` (raw `Int` is fine) because session rows persist
lanes.

### `ActiveSiegeSession`

```swift
struct ActiveSiegeSession: Codable, Equatable {
    var cityKey: CityKey
    var activeBattleSeconds: TimeInterval
    var deployments: [SiegeDeploymentCount]
    var appliedDamage: [SiegeDamageAttribution]
    var losses: [SiegeLossCount]
    var idleDamageByType: [SiegeIdleDamageByType]
    var usedFavorableUnit: Bool
    var usedExposedLane: Bool
}
```

`CityKey` must be `Codable` if it is not already (today it is a pure value used
as a dictionary key via `storageKey`; prefer encoding through `storageKey` /
canonical parse, matching other persisted city-key patterns).

Pure mutating APIs on the session (names may vary):

- `recordDeployment(type:source:lane:favorableTypes:exposedLane:)`
- `recordAttack(_ event: SoldierAttackEvent)`
- `recordLoss(_ event: SoldierLossEvent)`
- `recordIdleDamage(type:appliedDamage:)`
- `advanceActiveBattleTime(_ delta: TimeInterval)`
- `finalize(conquestMode:goldEarned:) -> BattleResult`

Marker rules:

- `usedFavorableUnit` becomes `true` on the first deployment whose `type` is in
  the current city's `CityDefenseTrait.favorableSoldierTypes`.
- `usedExposedLane` becomes `true` on the first deployment whose `lane` equals
  the current city's `LaneDefenseProfile.exposedLane`.
- Marker inputs are supplied by `KingdomGameState` from the catalog/trait
  projections already used by battle and scout card code. The session itself
  does not look up the catalog.

## 3. `KingdomGameState` Lifecycle

### New persisted fields

```swift
var activeSiegeSession: ActiveSiegeSession?
var pendingBattleResult: BattleResult?
```

Decode with `decodeIfPresent`; missing values default to `nil`. Older saves
therefore start with no session and no pending result.

### Session initialization

Create a fresh session when a city becomes battle-active:

- Successful `startCityFromMap` entry into a new (or re-entered unlocked)
  battle-active city.
- Defensively clear any stale `pendingBattleResult` when starting that city.

If `stageStatus == .battleActive` and `activeSiegeSession` is `nil` (legacy
save mid-siege), lazily create a fresh session keyed to `currentCityKey` on
first recording call rather than inventing history.

### Preserve across

- Battle ↔ Building View ↔ country map routing.
- Background / foreground.
- Scene reconstruction and app relaunch (via normal `KingdomGameStore` JSON).

### Drop / reset on decode or normalize when

- Session `cityKey` does not match the current active city.
- Stage is incompatible (e.g. session present while
  `.cityConqueredPendingMap` / `.countryComplete` without a pending result
  that consumes it — prefer: drop active session whenever stage is not
  `.battleActive`).
- Malformed nested rows fail local decode; drop the whole session rather than
  failing the full save (same lossy nested pattern as `cityBattleStates`).

Pending result normalization:

- Keep `pendingBattleResult` only when stage is
  `.cityConqueredPendingMap` or `.countryComplete`.
- Drop pending result when stage is `.battleActive`.
- Drop pending result whose `cityKey` does not match the conquered city still
  reflected by `cityNumberInCountry` / `currentCityKey` at pending-map time.
- Malformed pending result → `nil`, never fail the whole save.

### Active battle time

Advance `activeBattleSeconds` only when all are true:

1. `BattleScene` is foreground-active.
2. `stageStatus == .battleActive`.
3. The conquest popup is not visible.

Exclude:

- Building View time
- Country-map time
- Background time
- Idle catch-up elapsed time
- Layout-gate / first-frame priming gaps (existing `lastUpdateTime` behavior)

API sketch: `KingdomGameState.recordActiveBattleTime(_ delta: TimeInterval)`
forwards into the session after clamping `delta >= 0`. The scene calls it from
the same combat frame path that advances combat, gated by the rules above.

Persistence: save at existing state-save points and immediately before
route / background / conquest boundaries. Do **not** add per-frame disk
writes for time alone.

### Deployment recording

- Manual spawn: scene records deployment when a manual soldier is successfully
  added to combat (type, `.manual`, chosen/assigned lane).
- Building spawn: when `resolveActiveBuildingSpawns` results are turned into
  live soldiers, record each as `.building` with that soldier's assigned lane.
- Idle/settlement abstract spawns are **not** deployments into lanes; they only
  contribute idle damage by type.

## 4. Idle and Settlement Attribution

Idle building resolution already knows each abstract spawn's soldier type and
level. Extend the damage loop so applied damage is attributed per type with
sequential city-HP clamping:

1. For each spawn in resolution order, compute trait-adjusted attack power.
2. Applied = `min(power, remainingHP)`.
3. If applied > 0, `recordIdleDamage(type:applied)`.
4. Reduce remaining HP; stop attributing once the city is at 0.

Then:

- Idle damage uses applied damage only (never nominal overkill).
- Live `activeBattleSeconds` is never increased by offline elapsed time.
- On idle conquest, finalize with `conquestMode = .idle`.

**Settlement conquest** (`settleCurrentCityBuildingProgress` during
build/upgrade) uses the same attribution path and also finalizes as
`.idle`. Those spawns are abstract building production without lanes or live
roster presence; they must not invent live deployments or losses. HPA-388 will
present them with the idle copy ("Conquered while away") — acceptable because
the player was not in an active battlefield tick. If a later ticket wants a
third mode, it can be additive; this design keeps two modes only.

`IdleProgressResult` may gain an optional per-type breakdown or remain
aggregate for scene feedback; siege accounting is authoritative on the session
/ pending result, not on the transient idle feedback struct.

## 5. Final `BattleResult`

```swift
enum BattleConquestMode: String, Codable, Equatable {
    case live
    case idle
}

struct BattleResult: Codable, Equatable {
    var cityKey: CityKey
    var conquestMode: BattleConquestMode
    var activeBattleSeconds: TimeInterval
    var deployments: [SiegeDeploymentCount]
    var appliedDamage: [SiegeDamageAttribution]
    var losses: [SiegeLossCount]
    var idleDamageByType: [SiegeIdleDamageByType]
    var mvpSoldierType: SoldierType?
    var mvpDamageSharePercent: Int?
    var usedFavorableUnit: Bool
    var usedExposedLane: Bool
    var goldEarned: Int
}
```

### MVP

Compute from attributable applied city damage:

- Live damage rows contribute by `type`.
- Idle damage rows contribute by `type`.
- Sum damage per `SoldierType`.
- Winner = highest damage; ties break by `SoldierType.allCases` order.
- If total attributable damage is 0, `mvpSoldierType` and
  `mvpDamageSharePercent` are `nil`.
- Share percent is integer percent of total attributable damage for the MVP
  type, using truncating division consistent with existing Int damage math
  (`(mvpDamage * 100) / totalDamage`), clamped to `1...100` when MVP exists
  and total > 0. (If MVP damage is positive, percent is at least 1 when
  `mvpDamage * 100 >= totalDamage` would otherwise round weirdly — prefer
  exact truncating division and allow 0 only when MVP is nil; with MVP
  non-nil and total > 0, percent is in `1...100` via `max(1, (mvp * 100) / total)`
  only if product would otherwise truncate to 0 for tiny shares — **decision:
  use plain `(mvpDamage * 100) / totalDamage` with no special bump**, matching
  deterministic simplicity; UI may omit a 0% MVP which should not occur when
  MVP exists and total >= mvp >= 1.)

### Finalize timing

When remaining city HP reaches 0 through live events, idle resolution, or
settlement:

1. Ensure session exists (or use empty defaults for a degenerate conquest with
   no prior records).
2. Compute `goldEarned` from the existing reward formula (same value that will
   be added to `gold`).
3. `let result = session.finalize(conquestMode:goldEarned:)`.
4. Call `completeCurrentCity(with: result)`.

## 6. Conquest Mutation Shell

Replace the private gold-only `completeCurrentCity() -> Int` with:

```swift
mutating func completeCurrentCity(with result: BattleResult) -> CompletionResult
```

Within one in-memory mutation before the caller's save:

1. Validate stage is `.battleActive` and `result.cityKey` matches
   `currentCityKey`. Reject duplicates/stale calls without awarding again.
2. Award `result.goldEarned` exactly once (authoritative; do not recompute a
   different reward after the fact).
3. Set `cityRemainingPower = 0`.
4. Remove the current city's `CityBattleState`.
5. Clear `activeSiegeSession`.
6. Set `pendingBattleResult = result`.
7. Advance `completedCityCount` and transition to
   `.cityConqueredPendingMap` or `.countryComplete`.
8. Leave a clearly marked extension point for HPA-367 Chronicle write (no
   Chronicle storage in this ticket).

`CompletionResult` should expose enough for existing live/idle callers
(`goldEarned`, conquered flag / count) so `AttackResult` /
`IdleProgressResult` can still be built at the edges.

Live damage application changes from "aggregate Int may call complete" to
"record attacks into session, apply summed applied damage to HP, and on
conquest finalize + `completeCurrentCity(with:)`". Prefer a state API such as
`applyLiveSoldierAttacks(_ events: [SoldierAttackEvent])` that:

- records each attack into the session,
- applies each event's `appliedCityDamage` (already clamped in combat; still
  defensively clamp against current `cityRemainingPower`),
- records losses via a sibling `recordSoldierLosses(_:)` called from the scene
  for the same tick,
- finalizes on HP reaching 0.

Do not double-count: scene must not both feed events and also pass a second
aggregate damage path that records again.

### Pending acknowledgment

```swift
mutating func acknowledgePendingBattleResult()
```

- Clears only `pendingBattleResult`.
- Does not award gold or change completed-city progress / stage.
- Safe to call when already `nil` (no-op).
- Starting a new city clears any stale pending result defensively.
- A report is never regenerated from current scene nodes after acknowledgment.

Relaunch while stage is `.cityConqueredPendingMap` or `.countryComplete`
restores the same pending result for HPA-388. Chronicle recording (later) may
copy the result but must not clear pending.

## 7. Scene Integration (Foundation Only)

`BattleScene` changes required by this foundation (still no report layout):

- Consume `soldierAttacks` / `soldierLosses` instead of ID arrays.
- Forward deployments, attacks, losses, and gated active time into
  `KingdomGameState`.
- On conquest, rely on `pendingBattleResult` / existing gold feedback fields
  already returned by attack/idle results; do not invent a second accumulator.
- Keep showing the current simple conquest popup until HPA-388. Existing popup
  may continue using `goldEarned` from the transient result structs.
- `clearLiveCombat()` remains presentation-only and must not write loss events.

Building View / map / lifecycle paths that already call idle or settlement
resolution pick up attribution automatically through the model.

## 8. File Layout

Prefer one dedicated pure-model file, e.g. `Pyxis/BattleResultModels.swift`
(or split `ActiveSiegeSession.swift` / `BattleResult.swift` if size warrants),
containing events that are not nested inside `BattleCombatState` if that keeps
combat and siege accounting readable. `SoldierAttackEvent` / `SoldierLossEvent`
may live next to `TickResult` in `BattleCombatState.swift` if that reduces
churn; session/result types should not bloat the combat simulator file.

`PBXFileSystemSynchronizedRootGroup` picks up new files under `Pyxis/` and
`PyxisTests/` automatically.

## Testing Plan

### Pure unit tests

- Event payloads: attack applied damage clamped on final/overkill blow.
- Loss-before-prune: loss events present; roster no longer contains those IDs
  after tick returns.
- Session merge of deployment/damage/loss/idle rows; marker flips on
  deployment only.
- Active-time advance clamps and does not run through idle APIs.
- Idle attribution by type with sequential HP clamping; conquest mode `.idle`.
- Settlement conquest uses idle attribution/mode.
- MVP ties follow `SoldierType.allCases`; nil MVP when no attributable damage.
- `completeCurrentCity(with:)` awards once, sets pending, clears session;
  duplicate/stale rejected.
- `acknowledgePendingBattleResult()` clears pending only.
- Decode: missing fields → nil; mismatched cityKey/stage → drop; corrupt
  nested session/result does not fail whole save.
- `BattleLane` / session / result Codable round-trips.

### Integration tests (no SpriteKit node lookup for attribution)

- One live conquest: deployments + attacks + optional loss → pending
  `BattleResult` with `.live`, matching gold, MVP, markers as applicable.
- One idle conquest: background/foreground or direct idle resolution →
  pending result with `.idle`, idle damage by type, active time unchanged by
  offline elapsed.
- Route Battle → Building View → Battle preserves session.
- Relaunch / reload store while pending preserves identical `BattleResult`.
- Scene-cleared soldiers (background `clearLiveCombat`) do not increment
  losses.

Update existing `TickResult` consumers in
`BattleCombatStateTests` / `BattleSceneTests` for the event-array API.

## Acceptance Criteria Mapping

| Criterion | Design coverage |
| --- | --- |
| Live attacks attributable by type/source/lane/applied damage | §1 events + §3 recording |
| Losses once; scene clears ≠ losses | §1 + §7 |
| Session survives route/background/relaunch | §3 |
| Active duration inclusion/exclusion | §3 active battle time |
| Idle damage by type + idle mode | §4 |
| Deterministic finalized `BattleResult` | §5–6 |
| Pending restore + single ack | §6 |
| Old saves / corrupt data safe | §3 normalize |
| Pure + integration tests | §8 |

## Implementation Notes for the Follow-up Plan

After this spec is approved, write
`docs/superpowers/plans/2026-07-30-typed-battle-events-and-active-siege-result.md`
with TDD slices roughly:

1. Event types + `TickResult` migration + combat unit tests.
2. Summary rows + `ActiveSiegeSession` accumulate/finalize + MVP tests.
3. `KingdomGameState` persistence, normalize, active time, deployment APIs.
4. Live apply-attacks path + `completeCurrentCity(with:)` + pending ack.
5. Idle/settlement attribution wiring.
6. `BattleScene` event consumption + recording integration tests.
7. Save compatibility / corrupt nested data tests.

No implementation work begins until this design is explicitly approved.
