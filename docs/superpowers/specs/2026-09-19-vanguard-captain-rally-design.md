# HPA-475 Vanguard Captain + Rally Design

**Status:** Reviewed planning direction for implementation on this same PR  
**Linear:** HPA-475 — Vanguard Captain — one automatic hero and once-per-siege Rally  
**Baseline:** `main` at `51346efefd116360a2a5b242c307ced99842bb07` (merged HPA-469)

## Goal

Add one recognizable allied Captain and one optional tactical Rally without creating a hero-management or ability system.

From City 3 onward, one Vanguard Captain automatically deploys with the live army. The Captain uses the same three-lane route, Guard-blocking, range, structure targeting, and enemy-pressure rules already shipped by HPA-468/HPA-469. Rally can be consumed once per city siege to reduce incoming damage to ordinary allied soldiers in the Captain's lane by 30% for five seconds.

This remains **one implementation PR**. Planning, persistence, combat integration, HUD, tests, tuning, and gameplay evidence stay together. HPA-476 remains the only image-generation/art-production task.

## Review-locked constraints

1. Extend the existing owners: `SiegeProgress`, `Country1CityCatalog`, `KingdomGameState`, `BattleCombatState`, `BattleScene`, `BattleChromeLayout`, and `BattleHUDNode`. Do not create a hero service, ability registry, effect engine, ECS, or second combat simulator.
2. Captain availability remains derived from Country 1 campaign progress: `VanguardCaptainRules.isAvailable(cityNumber:)` is true from City 3 onward. No separate persisted unlock flag, quest, currency, roster, equipment, XP, hero level, rank, or details screen.
3. Reuse `BattleCombatState.Soldier` for the Captain with one transient `isCaptain` flag. Do **not** add `SoldierType.captain` or `SoldierSpawnSource.captain`; the Captain reuses the shipped soldier movement/route/Guard/tower/pruning/node paths.
4. `SoldierAttackEvent` / `SoldierLossEvent` carry `isCaptain` (default false). Captain events are transient only and are partitioned before persistence: Captain structure damage never enters `ActiveSiegeSession.appliedDamage`, and Captain retreat never enters soldier loss totals.
5. Existing soldier count semantics stay soldier-only. `livingSoldierCount` and `livingSoldierCount(source:)` exclude `isCaptain`, so the Captain never consumes manual cap, never arms the manual-squad navigation lock, and never inflates the ordinary-soldier tooltip/count.
6. Exactly one Captain may be active. Fresh City 3+ entry and recovery completion copy the then-current `selectedLane` into durable Captain progress; ordinary lane-chip changes never move the active Captain. Tab/background reconstruction restores the persisted Captain lane. Position remains transient.
7. Captain attack/HP scale from the existing soldier-upgrade progression. The spawned Captain uses infantry movement/range/defense/attack-speed math plus the explicit Captain HP/attack rule; no hero-specific pathfinding or targeting.
8. Live Captain lane + HP are synchronized into `SiegeProgress` from the flagged soldier after every tick through a sibling post-tick function beside the HPA-469 Guard sync. Do not widen the existing ordinary-soldier live-conquest continuation.
9. Captain recovery advances **only in live Battle** using `combat.clampedDeltaTime`. Leaving Battle pauses recovery; persisted remaining seconds prevent reconstruction exploits. Camp/Map/background settlement functions remain untouched.
10. Rally remains exactly once per siege, 30% incoming-damage reduction for five seconds, ordinary soldiers only. One durable consumed bit + two transient combat fields; no buff/cooldown/effect framework.
11. Manual Rally remains required, and the ticket-required automatic fallback remains required. Auto requests activation only when a still-living ordinary frontline soldier in the Captain lane crosses from at-or-above half HP to below half HP from a tower/Guard hit. Manual and auto call the same mutation.
12. Auto activation happens after `tick` returns: the triggering hit and any later hit in that same tick are unprotected; Rally begins on the next tick.
13. Tower Rally math folds into the existing lane multiplier before the **single** round/clamp. Guard Rally math applies one Rally multiplier/round to Guard attack power before clamping to current HP. Do not double-round.
14. Captain lane is durable; active Rally timer and position are transient. Reconstructing during Rally ends the temporary effect but leaves `rallyConsumed == true`.
15. `BattleChromeLayout` owns the City 3+ Deploy/Captain geometry: disjoint `deployActionFrame`, `captainStripFrame`, and `rallyHitFrame`. Fail closed if the Deploy action and ≥44pt Rally target cannot coexist. `BattleHUDNode` consumes those frames; it does not invent layout math or overlapping hit ordering.
16. Reuse existing soldier-node rendering and all-or-nothing walk/attack/hit animation playback by parameterizing the asset prefix for the flagged Captain. No parallel Captain node bundle/player.
17. Reuse existing melee/tower feedback. Captain attack events naturally map to existing melee feedback; Captain retreat must not emit ordinary soldier-death reporting/SFX.
18. Development save breaks are acceptable. No migrations/converters.
19. No generated art or new SFX in HPA-475. HPA-476 remains the only final Captain/Rally art-production task.

## Rules and tuning

Keep Country 1 authored combat tuning beside the existing `HighcrestGuardRules` in `Country1CityCatalog.swift`:

```swift
enum VanguardCaptainRules {
    static let unlockCity = 3
    static let recoverySeconds = 12.0
    static let rallyDurationSeconds = 5.0
    static let rallyDamageMultiplier = 0.70

    static func isAvailable(cityNumber: Int) -> Bool {
        cityNumber >= unlockCity
    }

    static func attackPower(for upgradeLevel: Int) -> Int {
        KingdomGameState.normalSoldierAttackPower(for: upgradeLevel) + 1
    }

    static func maxHP(for upgradeLevel: Int) -> Int {
        let level = max(1, upgradeLevel)
        return max(1, Int((20 * pow(1.25, Double(level - 1))).rounded()))
    }
}
```

These are starting values, not a new progression axis. Tune only Captain base HP / attack offset / recovery seconds if Task 6 evidence shows the Captain is irrelevant or dominant. Rally remains exactly 30% / five seconds / once per siege.

## Persisted siege state

Keep only the durable state needed to prevent heal/revive/lane-hop/Rally-reset exploits:

```swift
struct VanguardCaptainProgress: Codable, Equatable {
    var lane: BattleLane
    var remainingHP: Int
    var recoveryRemainingSeconds: Double
    var rallyConsumed: Bool
}
```

`SiegeProgress` gains:

```swift
var captain: VanguardCaptainProgress?
```

No actor ID, position, animation state, or active Rally seconds are persisted.

### Forgiving normalization without widening `normalizedSiegeProgress`

Keep `KingdomGameState.normalizedSiegeProgress`'s existing signature. Add a parameter-free `VanguardCaptainProgress.normalizedForCaptain()` beside `normalizedForHighcrest()` that:

- keeps the lane;
- clamps `remainingHP >= 0`;
- clamps recovery into `0...recoverySeconds`;
- preserves `rallyConsumed`;
- if HP > 0, forces recovery to 0.

Then, in the existing top-level `KingdomGameState.init` **after** ordinary siege normalization and after the clamped soldier upgrade level is known:

- if stage is not active or `VanguardCaptainRules.isAvailable(cityNumber:)` is false, force `captain = nil`;
- if City 3+ active and Captain is missing, seed fresh full HP on `siegeProgress.selectedLane`;
- if Captain exists, clamp its remaining HP to the current `VanguardCaptainRules.maxHP(for: normalSoldierUpgradeLevel)`;
- if HP == 0 and recovery == 0, recovery has completed: restore current max HP and set lane to the current selected lane.

This avoids adding city/upgrade parameters to the generic siege normalizer while still giving a constructed `KingdomGameState` honest Captain HP before any scene/HUD reads it.

`startCityFromMap` also constructs `SiegeProgress` directly, so it seeds fresh Captain progress for City 3+ at the same call site that already seeds Highcrest Guard progress.

### Durable lane, transient position

A lane-chip tap updates only `siegeProgress.selectedLane`; it never rewrites a living Captain's `captain.lane`. Scene/tab/background reconstruction restores the persisted Captain lane + HP. Only fresh city entry and recovery completion adopt the then-current selected lane.

Position remains transient, matching the existing live-roster reconstruction boundary.

## Captain reuses the existing Soldier loop

Do **not** add a parallel `Captain` actor.

Extend `BattleCombatState.Soldier`:

```swift
let isCaptain: Bool
```

Ordinary `spawnSoldier` sets `isCaptain = false`. Add one narrow `spawnCaptain` / restore helper that creates the one flagged soldier using:

- `type = .infantry` and the current upgrade level only as shared combat/animation parameter carriers;
- `source = .manual` as a transient compatibility value, never a report/count identity;
- persisted Captain lane + HP;
- Captain HP/attack rules;
- existing infantry defense/range/speed math.

No Captain-specific movement, blocker, range, structure-targeting, tower-targeting, Guard-targeting, pruning, or node-sync loop is added.

`livingSoldierCount` and `livingSoldierCount(source:)` both exclude `isCaptain`. Add a focused `captainSoldier` / `captainSnapshot` projection for orchestration.

### Transient event partition

Add `isCaptain: Bool = false` to explicit initializers for `SoldierAttackEvent` and `SoldierLossEvent` so existing call sites remain source-compatible.

The combat loop emits the same transient events for all soldiers. BattleScene partitions them:

- ordinary attacks -> existing `KingdomGameState.applyLiveSoldierAttacks`;
- Captain attacks -> sibling Captain persistence handler applies objective damage through `applyObjectiveDamage` and never records `ActiveSiegeSession.recordAttack`;
- ordinary losses -> existing `recordSoldierLosses`;
- Captain loss -> `recordCaptainRetreat`, never a soldier casualty.

Guard-hit events need no parallel Captain event: the existing soldier ID/type event is sufficient for animation/sound, and durable Captain HP comes from the post-tick live snapshot.

### Tie behavior

Keep the existing targeting helpers and arrays. Adjust the two existing foremost-selection comparisons (Guard lane target and tower lane target) so equal-position ties prefer `isCaptain`. That makes the Captain actually tank beside equal-speed infantry without adding `AlliedTarget` or generalized actor helpers.

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

Rally protects only ordinary (`!isCaptain`) soldiers in the captured Captain lane.

For tower fire, extend the existing `damageAgainstSoldier` single-round calculation:

```swift
let laneMultiplier = max(0, configuration.laneDamageMultipliers[soldier.lane] ?? 1.0)
let rallyMultiplier = rallyApplies(to: soldier)
    ? VanguardCaptainRules.rallyDamageMultiplier
    : 1.0
return max(
    1,
    Int((Double(baseDamage) * laneMultiplier * rallyMultiplier).rounded())
)
```

Do not calculate lane damage, round, then apply Rally and round again.

For Guard attacks there is no lane multiplier today. Apply Rally to Guard attack power **before** current-HP clamping:

```swift
let incoming = rallyApplies(to: soldier)
    ? max(1, Int((Double(HighcrestGuardRules.attackPower) * VanguardCaptainRules.rallyDamageMultiplier).rounded()))
    : HighcrestGuardRules.attackPower
let appliedDamage = min(incoming, soldier.currentHP)
```

Pin 1→1, 2→1, 3→2, 4→3 for the Rally multiplier at both damage sites with a neutral tower lane multiplier.

Captain damage is never reduced by Rally.

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

Recovery is live-combat time, not settlement time.

`KingdomGameState` keeps focused mutations:

```swift
mutating func recordCaptainRetreat()
@discardableResult
mutating func advanceCaptainRecovery(deltaTime: Double) -> Bool
@discardableResult
mutating func consumeVanguardRally() -> Bool
@discardableResult
mutating func synchronizeLiveCaptain(lane: BattleLane, remainingHP: Int) -> Bool
```

Rules:

- retreat sets HP 0 + 12s recovery and preserves the last live lane;
- recovery advances only from BattleScene using `combat.clampedDeltaTime`;
- leaving Battle pauses recovery; background/Camp/Map do not advance it;
- recovery completion restores current max HP and sets Captain lane to the then-current `siegeProgress.selectedLane`;
- `synchronizeLiveCaptain` persists the flagged living soldier's lane + HP and reports whether durable state changed;
- Rally consumption succeeds once and saves before the transient timer begins.

No changes are made to `resolveCurrentCityBuildingIdleProgress`, `settleCurrentCityBuildingProgress`, or their zero-building timestamp semantics.

### Post-tick sibling, not widened conquest logic

Keep `applyCombatResult`'s ordinary-soldier conquest continuation conceptually unchanged. It may make the small partition needed to use only `!isCaptain` attacks/losses for ordinary state/report mutation, but it does **not** continue Captain-only ticks through that path.

After:

```text
feedback.emitAutomaticCombat(result)
applyCombatResult(result)
```

call a sibling:

```text
synchronizeAndPersistCaptain(result, deltaTime: clampedDeltaTime)
synchronizeAndPersistHighcrestGuards(deltaTime: clampedDeltaTime)
```

The Captain sibling owns:

1. apply `result.soldierAttacks.filter(\.isCaptain)` via `state.applyObjectiveDamage`, never `applyLiveSoldierAttacks`;
2. if a Captain loss exists and stage is still active, record retreat;
3. otherwise synchronize living Captain lane + HP;
4. advance live recovery when no Captain is active;
5. on recovery completion, spawn one Captain from the newly durable full-HP/current-selected-lane state;
6. save immediately for HP change, retreat, Rally consumption, Captain structure damage, or recovery completion; recovery-countdown-only changes use the existing two-second progress cadence;
7. if Captain objective damage creates the pending live conquest result, reuse the existing fresh-live outcome/report helpers; no second reward formula or report model.

Because the full TickResult still reaches automatic feedback, Captain structure/Guard attacks reuse melee sound naturally. Filter `isCaptain` losses out of ordinary soldier-death sound/report handling; retreat is not a soldier casualty.

## HUD and pure geometry

`BattleChromeLayout` owns the split. Add:

```swift
let deployActionFrame: CGRect
let captainStripFrame: CGRect
let rallyHitFrame: CGRect
```

Derive them from `deployFrame` in both compact/reference branches with this fixed contract:

- gap between Deploy and Captain regions: 8pt;
- Captain strip width: 132pt;
- Rally hit frame: the rightmost 44pt of the Captain strip;
- Deploy action frame is the remainder;
- require Deploy action width >= 196pt;
- require Rally hit width/height >= 44pt;
- require all three subframes contained in `deployFrame` and pairwise non-overlapping;
- return `nil` if the contract cannot fit.

At 375pt width, current `contentWidth = 343`, leaving 203pt for Deploy after the 132pt strip + 8pt gap, so the intended compact contract is feasible without shrinking the battlefield.

City 1–2 continue rendering/hit-testing the full `deployFrame` centered exactly as today and simply ignore the Captain subframes. City 3+ use the disjoint precomputed subframes: no action-ordering workaround is needed.

`BattleHUDContent` stays in `BattleHUDNode.swift`. Its projection receives live `rallyRemainingSeconds` so it can distinguish durable Used from transient Active.

The Captain strip shows only portrait/fallback, compact HP/recovery, and Rally Ready/Active/Used. No hero screen, second row, floating button, or extra top-band height.

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

HPA-475 does **not** add a Captain node bundle or animation player. The flagged Captain flows through `soldierNodes` / `syncSoldierNodes`. Parameterize the existing animation asset prefix (`SoldierType.rawValue` vs `vanguard-captain`) while keeping `SoldierAnimationAction`, `SoldierAnimationTiming`, and the complete-trio probe/playback path. Until HPA-476 installs the complete trio, the flagged soldier uses the Captain procedural/static fallback. A partial trio still falls back to static presentation.

Animation is observational only.

## Tests and evidence

### Pure state

- City 1–2 no Captain progress; City 3+ fresh full Captain.
- generic `normalizedSiegeProgress` signature stays unchanged.
- Captain normalization/round trip retains lane, damaged HP, recovery, Rally consumption; top-level state init clamps to current upgrade-derived max HP.
- level increase does not heal current HP.
- `startCityFromMap` seeds fresh Captain from City 3 onward.
- retreat starts 12s recovery; leaving Battle pauses it; re-entering resumes from persisted remaining seconds.
- recovery completion restores current max HP once and adopts current selected lane.
- Rally consumes once and never resets within the same siege.

### Combat reuse

- exactly one `isCaptain` soldier exists when deployable.
- ordinary spawn/movement/route/Guard/structure behavior remains unchanged.
- Captain uses existing blocker/range/cooldown/structure loop and can hit Guards/structures.
- equal-position targeting prefers Captain for Guard/tower selection.
- Captain attack/loss transient events carry `isCaptain`, but report/deployment/loss attribution stays ordinary-soldier-only.
- both soldier-count APIs exclude Captain; manual cap/navigation lock remain unchanged.
- Captain retreat is not ordinary soldier death/report/SFX.
- Rally tower reduction combines lane × Rally before one rounding; Guard reduction rounds once before HP clamp.
- Rally same-lane reduction pins 1→1, 2→1, 3→2, 4→3 at both enemy damage sites.
- Rally never protects the Captain.
- five-second timer expires deterministically.
- ticket-required threshold auto-trigger requests Rally once; dead/off-lane/already-below-half cases do not.
- manual then auto / auto then manual cannot double-consume.

### Scene / UI / lifecycle

- scene init and foreground restore flagged Captain from persisted lane + HP.
- Captain recovery advances only while Battle ticks; Camp/Map/background do not shorten it.
- `synchronizeAndPersistCaptain` runs beside the Guard sibling and handles Captain-only objective hits without widening ordinary `applyCombatResult`.
- Captain-only Keep kill produces the normal pending result and `.freshLive` presentation exactly once.
- `BattleChromeLayoutTests` prove disjoint Deploy/Captain/Rally frames at 375×667, 393×852, and portrait iPad; fail closed below the fit contract.
- City 1–2 Deploy geometry/rendering remains unchanged.
- City 3+ Rally hit uses `rallyHitFrame`; Deploy uses `deployActionFrame`; overlap is structurally impossible.
- Active Rally projection consumes live timer; reconstruction loses timer but stays Used.
- flagged Captain uses the existing soldier node/animation pipeline with Captain asset prefix/fallback.

### Gameplay gate

Reuse the shipped HPA-469 Highcrest comparison exactly: seed 1, 1/60 tick, right/exposed lane, no manual spawns, Barracks L2 + Barracks L1 + Archery Range L1, soldier upgrade level 1. Pre-Captain reference: 567.62s / 158 ordinary-soldier losses.

Compare production behavior:

1. **watch-only:** never press Rally; automatic fallback may consume it when the ticket threshold is reached;
2. **manual:** activate Rally at a deterministic pre-threshold combat point (for example first enemy-contact evidence while the relevant ordinary soldier is still >=50% HP), before auto can consume it.

Auto remains enabled in both cases; do not add a benchmark-only production rule. Record exact activation origin/time, elapsed conquest time, ordinary losses, Captain retreats, and Captain damage contribution. If the real manual window proves impractically narrow, record that as product evidence rather than deleting the ticket-required auto fallback.

Tune only Captain base HP / attack offset / recovery seconds; Rally remains 30% / five seconds / once per siege.

## Risks

1. **Captain-as-Soldier identity leakage.** `type = .infantry` / `source = .manual` are transient compatibility carriers for shared combat code, not report identity. Every persistence/count/report seam must key off `isCaptain`; focused tests must prevent Captain deployment, damage, loss, or death SFX from leaking into ordinary statistics.
2. **Compact Deploy packing.** The fixed 132pt Captain strip + 8pt gap leaves 203pt on the 375×667 fixture. `BattleChromeLayout` owns the fail-closed contract so a future width regression cannot create overlapping controls.
3. **Manual-vs-auto Rally window.** Auto activation is required by HPA-475 and cannot be deleted as a simplification. Task 6 must prove a real manual activation can precede the half-HP fallback under production rules; if it cannot, that is evidence to revise the product requirement in Linear, not a reason to hide the issue in implementation.
4. **Captain-only conquest presentation.** The sibling path must reuse the existing pending-result/fresh-live presenter exactly once. Tests pin no second reward, no duplicate report, and no ordinary-soldier attribution.

## Non-goals

Additional heroes, hero roster/selection, equipment, gacha/rarity, XP, hero levels, passive auras, reusable cooldowns, multiple abilities, manual Captain movement, revive payments, new resources, base defense, hero-specific report sections, offline Captain damage, generic actor/effect framework, generated artwork, or new SFX.
