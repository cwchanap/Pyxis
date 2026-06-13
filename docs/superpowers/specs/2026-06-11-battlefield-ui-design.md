# Battlefield UI — Vertical 3-Lane Battlefield (HPA-50)

**Date:** 2026-06-11
**Linear issue:** [HPA-50 Battlefield UI](https://linear.app/cwchanap/issue/HPA-50/battlefield-ui)
**Status:** Approved

## Summary

Rotate the battle screen from its current horizontal layout (player castle left, enemy
city right, one ground lane) to a vertical full-screen battlefield: enemy city at the
top, player castle at the bottom, and three vertical marching lanes between them.
Each soldier is randomly assigned a lane at spawn. Lanes are gameplay-relevant: the
city tower fires at one occupied lane at a time, and each city deterministically marks
one lane fortified (tower hits harder), one exposed (tower hits softer), and one
standard.

## Requirements

1. Enemy city rendered at the top of the screen, player castle at the bottom.
2. Soldier marching is divided into 3 vertical lanes.
3. Each spawn (manual or building-produced) is randomly assigned to one lane; the
   lane never changes for the soldier's lifetime.
4. Tower targeting is per-lane: each shot picks a random lane with soldiers in tower
   range, then hits the most advanced soldier in that lane.
5. Per-city deterministic lane defense modifiers: one fortified lane (1.25× tower
   damage to soldiers), one exposed lane (0.80×), one standard lane (1.0×).
6. The battlefield fills the whole screen; HUD panels and action buttons float over it.
7. Subtle per-lane indicators (shield = fortified, broken shield = exposed) near the
   enemy city end of each non-standard lane.
8. The combat model stays a pure, deterministic, unit-testable value type.

## Architecture

Follows the existing split: gameplay rules live in pure Foundation models;
`BattleScene` only projects model state onto the screen.

### 1. Combat model (`BattleCombatState`)

- **`BattleLane`** — new enum (`left`, `center`, `right`), `CaseIterable`, Foundation-only.
- **`Soldier.lane: BattleLane`** — fixed at spawn. `spawnSoldier(...)` picks the lane
  randomly via the state's internal RNG; a test-facing overload accepts an explicit
  `lane:` parameter.
- **Seedable RNG** — the state stores a small SplitMix64-style PRNG struct (one
  `UInt64` of state, `Equatable`, conforming to `RandomNumberGenerator`). The live
  `init(cityLevel:)` seeds it from `UInt64.random` (system RNG); tests use
  `init(configuration:seed:)` for reproducible runs. The whole state remains an
  `Equatable` value type.
- **Tower targeting** — each shot: collect lanes containing a living soldier within
  tower range → pick one uniformly at random with the RNG → target the most advanced
  soldier in that lane. When only one lane is occupied the RNG is not consumed,
  keeping single-lane scenarios byte-for-byte deterministic.
- **Lane damage modifier** — `Configuration` gains
  `laneDamageMultipliers: [BattleLane: Double]` (default 1.0 per lane). Tower damage
  against a soldier becomes `max(1, towerDamage − defense)` scaled by the soldier's
  lane multiplier, rounded, floored at 1. A missing key defaults to 1.0; non-positive
  multipliers clamp so damage stays ≥ 1.
- **Unchanged** — movement (`position` stays the 0→1 scalar; lanes are parallel and
  equal length), soldier attacks on the city, conquest logic, and the `TickResult`
  shape. The scene looks up a soldier's lane from the roster.

### 2. Per-city lane traits (`LaneDefenseProfile`)

New pure type in `Pyxis/LaneDefenseProfile.swift` (Foundation-only) assigning one
role per lane:

| Role      | Effect on tower damage to soldiers in the lane |
|-----------|------------------------------------------------|
| fortified | 1.25× (risky lane)                             |
| exposed   | 0.80× (safe lane)                              |
| standard  | 1.0×                                           |

Multiplier values mirror `CityDefenseTrait` (1.25× / 0.80×) for balance-language
consistency. Direction differs: `CityDefenseTrait` scales soldier→city damage;
`LaneDefenseProfile` scales tower→soldier damage.

- **Assignment** — `LaneDefenseProfile.profile(forCityNumber:)` is a pure function
  over lane indices `left = 0`, `center = 1`, `right = 2`:
  fortified lane index = `(cityNumber − 1) % 3`, exposed = `(cityNumber + 1) % 3`,
  remaining lane standard. (The two indices always differ since they are 2 apart
  mod 3.) Every city gets exactly one of each role; the physical
  placement rotates city to city. Out-of-range city numbers clamp, matching
  `defenseTrait(forCityNumber:)`.
- **Wiring** — `KingdomGameState` exposes `currentCityLaneDefenseProfile` (mirroring
  `currentCityDefenseTrait`). `BattleScene` translates the profile into
  `Configuration.laneDamageMultipliers` when constructing its `BattleCombatState`.
  The combat model never knows why a lane has a multiplier.
- **No persistence** — pure function of city number; nothing stored.
- **Idle progress untouched** — offline catch-up applies building production damage
  directly without simulating the tower, so lane traits do not apply there.

### 3. Scene layout & rendering (`BattleScene`)

- **Full-screen battlefield** — the backdrop scales to fill the entire scene. HUD
  panels (top) and action buttons (bottom) keep their positions but float over the
  battlefield; their existing opaque panel backgrounds preserve readability.
- **Vertical orientation** — enemy city sprite near the top (base just below the HUD
  area), player castle near the bottom (just above the action buttons). The single
  horizontal `battleGroundLane` is replaced by three vertical lane paths centered at
  roughly 25% / 50% / 75% of the content width.
- **Soldier projection** — `pointForSoldierPosition` becomes
  `point(forLane:position:)`: x = lane center, y = linear interpolation from the
  player gate (position 0, bottom) to the enemy gate (position 1, top). Gate points
  become per-lane (`enemyGatePoints[lane]`), so tower-shot flashes and attack effects
  originate at the correct lane's mouth of the enemy city. Floating damage numbers use
  the center-lane gate because damage is reported in aggregate (not per-lane).
- **Lane indicators** — small emblem near the enemy end of each non-standard lane:
  shield (fortified), cracked shield (exposed). Standard lanes get nothing. Rendered
  with `SKShapeNode`/`SKLabelNode` glyphs in the existing theme style; no new art
  assets.
- **Degenerate sizes** — the existing guard that hides the battlefield when the play
  area is too short stays, recalculated for the new geometry.

### Out of scope

- `CountryMapScene`, `BuildingViewScene`, routing, spawn buttons, manual-type menu,
  and the conquest popup are unchanged.
- No lane-local blocking/spacing, no per-lane tower cooldowns.
- No player control over spawn lane (assignment is always random).

## Testing

New Swift Testing cases in `PyxisTests` (TDD per project convention):

- **Lane assignment** — seeded state produces a deterministic, reproducible lane
  sequence; explicit-`lane:` overload places exactly where asked; lane never changes
  after spawn.
- **Tower targeting** — with soldiers in 2–3 lanes in range, a seeded RNG hits the
  expected lane's most-advanced soldier; out-of-range lanes are never picked; a
  single occupied lane reproduces the pre-change targeting result.
- **Lane modifiers** — fortified lane takes 1.25× (rounded, floor 1) tower damage,
  exposed 0.80×, standard unchanged; defense subtraction applies before scaling.
- **Profile determinism** — every city number yields exactly one fortified, one
  exposed, one standard lane; placement differs across consecutive cities; invalid
  inputs clamp.
- **Existing tests** — `BattleCombatState` tests updated for the seeded init / new
  spawn signature; all other suites pass untouched.

UI tests stay as-is: the layout change alters no accessibility identifiers or button
flows.

## Persistence & error handling

- `BattleCombatState` is transient (rebuilt on scene entry, never saved): no Codable
  changes, no migration.
- `KingdomGameState`'s persisted shape is unchanged.
- Missing lane multiplier → 1.0; non-positive multiplier → clamped, damage floor 1.
- Out-of-range city numbers clamp in `profile(forCityNumber:)`.
- All soldiers in one lane → targeting degenerates to today's behavior.
