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
5. Captain lane is transient. Initial scene construction, scene reconstruction, and recovery completion are deployment/redeployment points and use the then-current selected assault lane. Changing the flag while the Captain is alive never changes the active actor's lane.
6. Captain attack and HP scale from the existing `normalSoldierUpgradeLevel` through one explicit rule set. Movement/range/defense/attack-speed reuse the existing base infantry combat configuration; no hero-specific pathing or targeting.
7. Captain retreat is not a `SoldierLossEvent`. Defeat persists HP = 0 plus one fixed recovery countdown; completion restores current maximum HP and redeploys automatically.
8. Rally is hard-coded to this Captain: one consumed bit in persisted siege progress plus one transient five-second timer in `BattleCombatState`. No reusable cooldown/timed-effect abstraction.
9. Rally protects **ordinary allied soldiers only**, not the Captain. The feature is intended to protect the army around the Captain and keeps Captain tuning independent.
10. Rally damage rule: after the source's normal damage calculation, multiply by `0.70`, round to nearest integer with Swift's default `.rounded()`, then clamp to at least 1 damage.
11. Manual and automatic Rally activation call one BattleScene activation path and consume persisted readiness before starting the transient effect.
12. Auto Rally may request activation only when an enemy tower/Guard hit causes a still-living frontline soldier in the Captain lane to cross from at-or-above half HP to below half HP. Tower/Guard targeting already picks a frontline actor, so an actual enemy hit is the “actively engaged” proof; do not add engagement state.
13. Rally's triggering hit is not retroactively reduced. Protection begins after the shared activation mutation and affects later incoming hits.
14. If a scene/app reconstruction occurs during the five-second window, the timer may disappear; `rallyConsumed` remains true, so Rally cannot return to ready.
15. Captain recovery may advance through existing elapsed-time settlement/foreground handling, even with zero player buildings, but the Captain never creates offline damage. Existing no-buildings/no-offline-damage semantics remain intact.
16. Development save breaks are acceptable. No migrations/converters.
17. No generated art or new SFX in HPA-475. Use procedural/static fallbacks and existing feedback sounds. HPA-476 owns final Captain/Rally visuals.

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

Add only the minimum state needed to prevent heal/revive/Rally-reset exploits:

```swift
struct VanguardCaptainProgress: Codable, Equatable {
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
- Fresh City 3+: full current Captain HP, recovery 0, Rally unused.
- Healthy/deployable: `remainingHP > 0 && recoveryRemainingSeconds == 0`.
- Recovering: `remainingHP == 0 && recoveryRemainingSeconds > 0`.
- Recovery reaching zero restores current max HP.
- Captain max HP is recalculated from the current soldier-upgrade level. Increasing that level does not heal current HP; normalization only clamps down to the current maximum.
- Persist no Captain position, actor ID, animation action, active Rally seconds, or active lane.

`normalizedSiegeProgress` stays the forgiving owner. Pass the current city number and soldier-upgrade level into normalization so it can derive Captain availability/max HP without adding an unlock field.

A malformed City 3+ Captain payload clamps HP into `0...maxHP`, recovery into `0...recoverySeconds`, and preserves `rallyConsumed`. If HP is zero and recovery is zero, recovery is complete and the normalized state becomes full HP. City 1–2 discard Captain progress.

### Why active lane is not persisted

HPA-469 already accepts transient actor positions across scene replacement, and HPA-475 explicitly asks for only enough state to block heal/revive/Rally exploits. A scene reconstruction is a redeployment boundary: a healthy Captain comes back in the currently selected lane. A live lane-chip tap does not mutate the current Captain actor. This gives the requested “next deployment/redeployment” behavior without another persistence field.

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

Use one small private `AlliedTarget` enum inside `BattleCombatState` only to select the foremost in-range ordinary soldier or Captain. Do not expose it as a generic actor hierarchy.

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

`advanceCaptainRecovery` returns true only when recovery crosses to ready/full HP.

Live Battle order stays close to HPA-469:

```text
player building spawns
-> BattleCombatState.tick
-> feedback
-> apply soldier structure events
-> apply Captain structure events (no report attribution)
-> record soldier losses
-> record Captain retreat if needed
-> synchronize Guard HP
-> advance Guard waves
-> advance Captain recovery
-> deploy returned Captain if recovery completed
-> persist on existing immediate/throttled save rules
-> sync actor nodes + HUD
```

Background/Camp/Map settlement may call `advanceCaptainRecovery` with the same credited elapsed window it already knows. This call is independent of player-building count. The existing building/Guard damage path remains unchanged: Captain never appears in `BuildingSpawn`, never attacks offline, and never changes reward/report damage.

## HUD

Keep the current top band and battlefield field budget unchanged.

For City 3+, extend the existing **Deploy panel** with one bounded right-side Captain/Rally segment. City 1–2 keep the current Deploy layout byte-for-byte.

The segment shows only:

- small Captain portrait/fallback mark;
- `CAPT 18/20` or `CAPT 7s`;
- `RALLY`, `ACTIVE`, or `USED`.

When Rally is Ready, this segment is the ≥44pt Rally hit target. Otherwise it is status-only. `BattleHUDNode.action(at:)` checks the Rally hit region before the remaining Deploy hit region, preventing a Rally tap from spawning a soldier.

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

No Captain retreat frame set is required: retreat uses a procedural fade/scale. Rally protection may be procedural until HPA-476 supplies the optional accent. Animation is observational only.

## Tests and evidence

### Pure state

- City 1–2 no Captain progress; City 3+ fresh full Captain.
- normalization/round trip retains damaged HP, recovery, and Rally consumption.
- level increase does not heal an already-damaged Captain.
- retreat starts 12s recovery; partial recovery persists; crossing zero restores current max HP once.
- Rally consumes once and never resets inside the same siege.
- fresh next city gets fresh Rally state.
- recovery can advance during elapsed settlement without generating any damage.

### Combat

- exactly one Captain deploys at position 0 on selected lane;
- lane flag changes do not move live Captain; recovery/scene redeployment uses the current lane;
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
- healthy reconstruction/recovery return deploys on selected lane;
- foreground/background preserves HP/recovery/consumed state;
- zero buildings still produce zero offline damage/conquest;
- Captain does not activate manual troop navigation lock;
- compact phone + portrait iPad keep lane chips, Deploy, Captain segment, Settings, tabs, and report readable.

### Gameplay gate

Use deterministic representative City 5 Highcrest fights after correctness is green:

1. watch-only / automatic Rally;
2. same seed/camp with one deliberately timed manual Rally.

Record elapsed conquest time, normal soldier losses, Captain retreats, Rally trigger timing, and whether Captain damage appears dominant. Tune only the bounded Captain numbers above; do not add mechanics.

## Non-goals

Additional heroes, hero roster/selection, equipment, gacha/rarity, XP, hero levels, passive auras, reusable cooldowns, multiple abilities, manual Captain movement, revive payments, new resources, base defense, hero-specific report sections, offline Captain damage, generic actor/effect framework, generated artwork, or new SFX.
