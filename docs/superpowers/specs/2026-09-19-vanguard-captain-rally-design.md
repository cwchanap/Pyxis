# HPA-475 Vanguard Captain + Rally Design

**Status:** Reviewed planning direction for implementation on this same PR  
**Linear:** HPA-475 — Vanguard Captain — one automatic hero and once-per-siege Rally  
**Baseline:** `main` at `51346efefd116360a2a5b242c307ced99842bb07` (merged HPA-469)

## Goal

Add one recognizable allied Captain and one optional tactical Rally without creating a hero-management or ability system.

From City 3 onward, one Vanguard Captain automatically deploys with the live army. The Captain uses the same three-lane route, Guard-blocking, range, structure targeting, and enemy-pressure rules already shipped by HPA-468/HPA-469. Rally can be consumed once per city siege to reduce incoming damage to ordinary allied soldiers in the Captain's lane by 30% for five seconds.

This remains **one implementation PR**. Planning, persistence, combat integration, HUD, tests, tuning, and gameplay evidence stay together. HPA-476 remains the only image-generation/art-production task.

## Review-locked constraints

1. Extend the existing owners: `SiegeProgress`, `KingdomGameState`, `BattleCombatState`, `BattleScene`, `BattleHUDContent` / `BattleHUDNode`. Do not create a hero service, ability registry, effect engine, ECS, or second combat simulator.
2. Captain availability is derived from `cityNumberInCountry >= 3`. No unlock flag, quest, currency, roster, equipment, XP, hero level, rank, or details screen.
3. The Captain is a dedicated combat actor, **not** a new `SoldierType` or `SoldierSpawnSource`. This keeps manual cap, navigation lock, deployments, losses, MVP, and soldier report rows unchanged.
4. Exactly one Captain may exist in live combat.
5. Captain lane is durable while that Captain is alive. Fresh City 3+ entry and recovery completion copy the then-current `selectedLane` into Captain progress; ordinary lane-chip changes never rewrite it. Scene/tab/background reconstruction restores that persisted lane instead of granting a free lane hop. Position remains transient.
6. Captain attack and HP scale from the existing `normalSoldierUpgradeLevel` through one explicit rule set. Movement/range/defense/attack-speed reuse the existing base infantry combat configuration; no hero-specific pathing or targeting.
7. Live Captain HP + lane are synchronized into `SiegeProgress` after every combat tick, outside the existing soldier-structure-event early return. HP changes, retreat, Rally consumption, and recovery completion save immediately; the existing throttled progress save may cover recovery countdown-only changes.
8. Captain retreat is not a `SoldierLossEvent`. Defeat persists HP = 0 plus one fixed recovery countdown; completion restores current maximum HP, writes the current selected lane, and redeploys automatically.
9. Rally is hard-coded to this Captain: one consumed bit in persisted siege progress plus one transient five-second timer in `BattleCombatState`. No reusable cooldown/timed-effect abstraction.
10. Rally protects **ordinary allied soldiers only**, not the Captain. The feature is intended to protect the army around the Captain and keeps Captain tuning independent.
11. Rally damage rule: after the source's normal damage calculation, multiply by `0.70`, round to nearest integer with Swift's default `.rounded()`, then clamp to at least 1 damage.
12. Manual and automatic Rally activation call one BattleScene activation path and consume persisted readiness before starting the transient effect.
13. Auto Rally may request activation only when an enemy tower/Guard hit causes a still-living frontline soldier in the Captain lane to cross from at-or-above half HP to below half HP. The enemy hit itself is the engagement proof; do not add engagement state.
14. Rally activation occurs after the tick that requested it. The triggering hit **and any later hits in that same tick** are unprotected; protection starts on the next combat tick.
15. Captain-only structure hits, retreat signals, and Rally auto-requests must bypass the current `soldierAttacks.isEmpty` return and reuse the existing live-conquest persistence/report presenter. Do not create a second conquest path.
16. If a scene/app reconstruction occurs during the five-second window, the timer may disappear; `rallyConsumed` remains true, so Rally cannot return to ready.
17. Captain recovery advances through the already-owned live/settlement elapsed windows even with zero player buildings. Call it before the current occupied-slot early returns; Captain still creates no offline damage, Guard waves still require player buildings, and zero buildings remain zero offline damage/conquest.
18. Reuse existing melee/tower feedback sounds and the existing all-or-nothing walk/attack/hit animation trio machinery. Do not add new SFX or a second animation player.
19. Development save breaks are acceptable. No migrations/converters.
20. No generated art in HPA-475. Use procedural/static fallbacks until HPA-476 supplies final Captain/Rally visuals.

## Rules and tuning

Keep the cross-city Captain rules next to `KingdomGameState` as one small top-level enum, rather than introducing a subsystem.

```swift
enum VanguardCaptainRules {
    static let unlockCity = 3
    static let recoverySeconds = 12.0
    static let rallyDurationSeconds = 5.0
    static let rallyDamageMultiplier = 0.70

    static func attackPower(for upgradeLevel: Int) -> Int {
        KingdomGameState.normalSoldierAttackPower(for: upgradeLevel) + 1
    }

    static func maxHP(for upgradeLevel: Int) -> Int {
        let level = max(1, upgradeLevel)
        return max(1, Int((20 * pow(1.25, Double(level - 1))).rounded()))
    }
}
```

These are starting values for HPA-475 gameplay evidence, not a new progression axis. Tune only Captain base HP / attack offset / recovery seconds if the representative fights show the Captain is irrelevant or dominant. Rally remains exactly 30% / 5s / once-per-siege.

## Persisted siege state

Add only the minimum state needed to prevent heal/revive/lane-hop/Rally-reset exploits:

```swift
struct VanguardCaptainProgress: Codable, Equatable {
    var lane: BattleLane
    var remainingHP: Int
    var recoveryRemainingSeconds: Double
    var rallyConsumed: Bool
}

struct SiegeProgress: Codable, Equatable {
    var selectedLane: BattleLane
    var damageByObjectiveID: [String: Int]
    var guardReinforcements: GuardReinforcementProgress?
    var captain: VanguardCaptainProgress?
}
```

Interpretation:

- City 1–2: `captain == nil`.
- Fresh City 3+: full current Captain HP, recovery 0, Rally unused, lane = the fresh siege's selected/default lane.
- Healthy/deployable: `remainingHP > 0 && recoveryRemainingSeconds == 0`; `lane` is the live/reconstruction lane.
- Recovering: `remainingHP == 0 && recoveryRemainingSeconds > 0`; keep the last lane only as durable history while no actor is live.
- Recovery reaching zero restores current max HP and writes `lane = siegeProgress.selectedLane` for the next deployment.
- Captain max HP is recalculated from the current soldier-upgrade level. Increasing that level does not heal current HP; normalization only clamps down to the current maximum.
- Persist no Captain position, actor ID, animation action, or active Rally seconds.

`normalizedSiegeProgress` stays the forgiving owner. Pass the current city number and soldier-upgrade level into normalization so it can derive Captain availability/max HP without adding an unlock field.

A malformed City 3+ Captain payload clamps HP into `0...maxHP`, recovery into `0...recoverySeconds`, keeps the persisted lane, and preserves `rallyConsumed`. If HP is zero and recovery is zero, recovery is complete and the normalized state becomes full HP on the currently selected lane. City 1–2 discard Captain progress.

`startCityFromMap` constructs `SiegeProgress` directly and therefore must seed fresh Captain progress there, just as it already seeds fresh Highcrest Guard progress. Decoder normalization alone is not enough.

### Why lane persists but position does not

HPA-469 already persists Guard lane + HP while accepting transient position. Captain needs the same boundary. A lane-chip tap changes only `siegeProgress.selectedLane`; it does not teleport the active Captain. Reconstructing Battle after a Camp/Map visit or background event must restore the Captain on its persisted lane, otherwise a tab switch becomes a free lane-change exploit.

Position remains transient because allied soldiers and Guards already rebuild spatial position across scene reconstruction. HPA-475 does not introduce partial spatial continuity for only the Captain.

### Live HP/lane synchronization

Add one focused `KingdomGameState` seam next to `synchronizeLiveGuardSnapshots`, for example:

```swift
@discardableResult
mutating func synchronizeLiveCaptain(lane: BattleLane, remainingHP: Int) -> Bool
```

After every live combat tick, BattleScene writes the live Captain's lane + current HP into `SiegeProgress.captain` even when no soldier hit a structure. A changed HP/lane snapshot saves immediately. Retreat uses `recordCaptainRetreat()` instead of synchronizing a dead actor back to healthy state.

Scene init and foreground restoration converge combat from durable Captain progress the same way `restorePersistedGuardsIntoCombat()` converges Guards.

## Live Captain actor

Extend `BattleCombatState` with one optional `Captain`; do not put the Captain in `soldiers`.

```swift
struct Captain: Equatable {
    let lane: BattleLane
    let maxHP: Int
    var currentHP: Int
    let defense: Int
    let attackPower: Int
    let attackSpeed: Double
    let attackRange: Double
    let movementSpeed: Double
    var position: Double
    var attackCooldownRemaining: Double
}
```

Deployment starts at position 0 in the selected lane. Movement/range/attack-speed/defense use the same base configuration as infantry; HP and attack use `VanguardCaptainRules`.

Captain targeting stays inside the current combat tick:

- nearest live Guard on Captain lane blocks first;
- otherwise attack the first live objective in that lane's authored route;
- stop/move using the same no-cross and range rules already used by soldiers;
- Captain can damage Guards directly in combat;
- structure damage is returned as a Captain-specific structure event and applied by `KingdomGameState.applyObjectiveDamage`.

Captain structure damage is intentionally **not** converted to `SoldierAttackEvent` and is not written into `ActiveSiegeSession.appliedDamage`. The current report is soldier-attribution/MVP data; adding a fake soldier row would corrupt it, while adding hero report schema is explicitly out of scope. Captain damage can still destroy objectives/Keep and complete the siege through the existing objective-damage authority.

## Enemy targeting and retreat

The Captain must be able to retreat, so towers and Guards treat the Captain as one possible allied combat target.

Use one small private `AlliedTarget` enum inside `BattleCombatState`, but keep the two existing targeting meanings explicit:

- `foremostAlliedTarget(in:)` — no range filter; Guard movement + Guard attacks use it.
- the defensive-fire helper — covered lanes + source-relative range filter; tower targeting uses it.

When Captain and a soldier share the same foremost position, prefer the Captain. This lets equal-speed infantry march beside the Captain while the Captain actually tanks instead of being skipped by tie ordering.

Do not expose `AlliedTarget` as a generic actor hierarchy.

Preserve existing soldier events and add Captain-specific result signals rather than widening soldier IDs:

- soldier-targeted `TowerShot` and `GuardAttackEvent` remain unchanged;
- add a Captain-targeted tower hit signal;
- add a Captain-targeted Guard hit signal;
- add Captain Guard-hit / structure-hit signals;
- add `didCaptainRetreat`.

On Captain HP reaching zero:

1. combat removes the live Captain once;
2. no `SoldierLossEvent` is emitted;
3. BattleScene records retreat in `KingdomGameState` as HP 0 + 12s recovery;
4. existing soldier casualty/report totals are untouched;
5. a small procedural fade/scale is presentation only.

Tower lane selection still consumes RNG only when several occupied covered lanes create a real lane choice. The Captain simply makes its lane occupied when it is in source-relative range.

## Rally

### Durable + transient ownership

Durable state:

```text
SiegeProgress.captain.rallyConsumed
```

Transient live state in `BattleCombatState`:

```text
rallyLane: BattleLane?
rallyRemainingSeconds: Double
```

There is no persisted `active` state. UI derives:

- **Ready**: Captain deployed, `rallyConsumed == false`, transient timer is zero.
- **Active**: transient timer > 0.
- **Used**: `rallyConsumed == true`, transient timer == 0.
- **Recovering**: show Captain recovery; Rally is not actionable even if unused.

BattleScene owns one `activateRally()` funnel:

1. require a live Captain and capture its fixed lane;
2. call `KingdomGameState.consumeVanguardRally()`;
3. start the five-second combat timer on that lane;
4. save and redraw;
5. reuse existing feedback sound/haptic rather than adding a new SFX asset.

Manual HUD action and `TickResult.shouldAutoActivateRally` both call this method. Persisted consumption happens before the transient protection begins, so interruption cannot duplicate the use.

### Damage reduction

Only incoming tower/Guard damage to an ordinary soldier is eligible:

```swift
let reduced = max(
    1,
    Int((Double(baseDamage) * VanguardCaptainRules.rallyDamageMultiplier).rounded())
)
```

The reduction applies only while the timer is active and the soldier's lane equals the captured Rally lane. Captain damage is never reduced by Rally. No stack, healing, outgoing bonus, summon, aura, mana, or charge semantics exist.

### Automatic activation

While Rally is unused and the Captain is deployed, BattleScene tells the combat tick auto-trigger is available.

For each enemy hit to an ordinary soldier:

- capture pre-hit HP;
- apply normal/Rally-reduced damage;
- require the soldier is still alive;
- require Captain lane == soldier lane;
- require pre-hit HP was at least half and post-hit HP is below half;
- emit at most one `shouldAutoActivateRally` request for the tick.

The triggering hit itself is not protected. If manual Rally already consumed state, or another trigger consumed it first, the common mutation rejects later requests.

## Recovery and lifecycle

Add focused `KingdomGameState` mutations rather than another timer owner:

```swift
mutating func recordCaptainRetreat()
@discardableResult
mutating func advanceCaptainRecovery(deltaTime: Double) -> Bool
@discardableResult
mutating func consumeVanguardRally() -> Bool
```

`advanceCaptainRecovery` returns true only when recovery crosses to ready/full HP; that transition also writes the then-current `siegeProgress.selectedLane` for redeployment.

### Live Battle integration

The current `BattleScene.applyCombatResult` returns early when `result.soldierAttacks.isEmpty`. Captain work cannot live behind that guard. Keep one live-outcome path and widen the continuation condition so Captain structure hits / retreat / Rally auto-request are handled even on a Captain-only tick.

Post-tick order:

```text
player building spawns
-> BattleCombatState.tick
-> feedback
-> apply ordinary soldier structure events
-> apply Captain structure events via applyObjectiveDamage (no report attribution)
-> record ordinary soldier losses
-> record Captain retreat if needed
-> synchronize live Captain lane + HP
-> process Rally auto-request through activateRally()
-> advance Captain recovery with combat-clamped delta
-> deploy returned Captain if recovery completed
-> existing Guard snapshot sync + Guard wave advance/restore
-> immediate save for Captain HP/retreat/Rally/recovery-completion changes
-> existing throttled progress save for countdown-only progression
-> sync actor nodes + HUD
```

A Captain Keep kill reuses the same `persistLiveCombatStateAndEmitFreshOutcomeFeedback` / pending-report presentation path used by ordinary live conquest. Do not add a Captain conquest presenter.

Manual/automatic Rally starts after the current tick has already resolved. All same-tick enemy hits remain unprotected.

### Camp / Map / background elapsed recovery

Captain recovery is independent of player buildings, while **damage remains building-driven**.

Use the already-owned elapsed windows:

- `resolveCurrentCityBuildingIdleProgress(at:)`: compute its capped elapsed interval, call `advanceCaptainRecovery` **before** the `occupiedSlotCount == 0` damage early return, then keep today's zero-building damage result.
- `settleCurrentCityBuildingProgress(at:)`: resolve the interval from the existing building timestamp or the already-recorded `lastBackgroundedAt` fallback, advance Captain recovery before building-only exits, then leave Guard/building settlement semantics unchanged.
- `markCurrentCityBuildingProgressInactive(at:)` remains the single transition timestamp owner; do not add a Captain clock.
- live Battle recovery uses `combat.clampedDeltaTime`.

A zero-building Camp/Map/background interval may finish Captain recovery but can never advance Guard waves, create `BuildingSpawn`, apply objective damage, award gold, or conquer.

## HUD

Keep the current top band and battlefield field budget unchanged.

`BattleHUDContent` already lives in `BattleHUDNode.swift`; do not create `BattleHUDContent.swift`.

For City 3+, split the existing Deploy frame horizontally:

- **left:** the existing Deploy icon/label/divider/manual-count cluster, left-aligned instead of centered;
- **right:** a bounded Captain/Rally strip large enough for a ≥44pt Rally target plus compact `CAPT 18/20` / `CAPT 7s` status.

City 1–2 keep today's centered Deploy cluster byte-for-byte.

The right strip shows only:

- small Captain portrait/fallback mark;
- `CAPT 18/20` or `CAPT 7s`;
- `RALLY`, `ACTIVE`, or `USED`.

`BattleHUDContent.project` must receive the live `rallyRemainingSeconds` (and whether a Captain actor is deployed if needed) from BattleScene; `KingdomGameState` alone cannot distinguish transient Active from durable Used.

Add `BattleHUDNode.Action.rally`. When Rally is Ready, the Captain strip owns a ≥44pt Rally hit target. `action(at:)` checks that frame **before** the remaining Deploy hit region, so Rally cannot accidentally spawn a soldier.

Touch `BattleChromeLayout` only if 375×667 evidence proves the right strip cannot coexist with a still-tappable Deploy region inside today's 56pt compact Deploy frame.

Do not add a hero screen, tooltip tree, second bottom bar, battlefield floating button, or extra top-band row.

Because the Captain is not in `combat.soldiers`, existing manual-cap count and “finish the current squad before building” navigation lock continue to observe only manual soldiers.

## Placeholder / HPA-476 asset contract

HPA-475 installs **no generated images**. Runtime probes these stable names and falls back to procedural/SF-symbol presentation.

| Asset | Contract |
| --- | --- |
| `vanguard-captain-portrait` | 128×128 transparent square, visual center anchored at 0.5/0.5; HUD crops within the Captain segment |
| `vanguard-captain-resting` | 128×128 transparent actor canvas, feet at bottom-center |
| `vanguard-captain-walk-01...10` | 128×128, feet/bottom-center, same timing convention as soldier walk |
| `vanguard-captain-attack-01...10` | 128×128, feet/bottom-center |
| `vanguard-captain-hit-01...10` | 128×128, feet/bottom-center |
| `rally-icon` | 64×64 transparent, center anchor; HUD Ready/Active mark |
| `rally-protection-accent` | 128×128 transparent accent, feet/bottom-center behind protected ordinary soldiers |

No Captain retreat frame set is required: retreat uses a procedural fade/scale. Rally protection may be procedural until HPA-476 supplies the optional accent.

HPA-475 does **not** add a Captain animation player. Reuse `SoldierAnimationAction`, `SoldierAnimationTiming`, and the existing all-or-nothing walk/attack/hit trio probe/playback path by making the frame-name probe accept the Captain prefix as another caller. Until HPA-476 installs the complete trio, the Captain remains on one procedural/static fallback sprite. Dropping the complete HPA-476 trio under these names activates the existing animation path; a partial trio still fails back to static presentation.

Animation is observational only.

## Tests and evidence

### Pure state

- City 1–2 no Captain progress; City 3+ fresh full Captain.
- normalization/round trip retains Captain lane, damaged HP, recovery, and Rally consumption.
- level increase does not heal an already-damaged Captain.
- retreat starts 12s recovery; partial recovery persists; crossing zero restores current max HP once.
- Rally consumes once and never resets inside the same siege.
- fresh next city gets fresh Rally state.
- recovery can advance during elapsed settlement without generating any damage.

### Combat

- exactly one Captain deploys at position 0 on selected lane;
- lane flag changes do not move live Captain; scene/tab/background reconstruction restores the persisted live lane; recovery completion is the only redeployment that adopts the current selected lane;
- Captain blocks/attacks Guard first, then route structure;
- tower/Guard can damage Captain; retreat is not a soldier loss;
- manual soldier count is unchanged by Captain;
- Rally same-lane reduction pins 1→1, 2→1, 3→2, 4→3;
- off-lane soldier damage is unchanged;
- five-second timer expires deterministically;
- threshold-crossing enemy hit requests auto Rally once;
- dead/non-frontline/off-lane/already-below-half cases do not request it;
- active/used state prevents double trigger.

### Scene / UI / lifecycle

- both manual and auto trigger use one activation path;
- scene reconstruction during active Rally loses transient timer but stays Used;
- healthy reconstruction restores persisted lane/HP; recovery completion deploys on the then-current selected lane;
- foreground/background preserves HP/recovery/consumed state;
- zero buildings still produce zero offline damage/conquest;
- Captain does not activate manual troop navigation lock;
- compact phone + portrait iPad keep lane chips, Deploy, Captain segment, Settings, tabs, and report readable.

### Gameplay gate

Reuse the shipped HPA-469 Highcrest comparison exactly after correctness is green: combat seed 1, 1/60 tick, selected right/exposed lane, no manual spawns, Barracks L2 (slot 1) + Barracks L1 (slot 2) + Archery Range L1 (slot 3), soldier upgrade level 1. The pre-Captain reference is 567.62s / 158 ordinary-soldier losses on the right direct route.

Compare:

1. watch-only / automatic Rally;
2. the same seed/camp with one deliberately timed manual Rally.

Do not choose a new camp for Task 6; that would make the HPA-469 baseline incomparable.

Record elapsed conquest time, normal soldier losses, Captain retreats, Rally trigger timing, and whether Captain damage appears dominant. Tune only the bounded Captain numbers above; do not add mechanics.

## Non-goals

Additional heroes, hero roster/selection, equipment, gacha/rarity, XP, hero levels, passive auras, reusable cooldowns, multiple abilities, manual Captain movement, revive payments, new resources, base defense, hero-specific report sections, offline Captain damage, generic actor/effect framework, generated artwork, or new SFX.
