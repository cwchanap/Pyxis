# HPA-468 Tactical Siege Pilot Implementation Plan

**Ticket:** HPA-468  
**Design:** `docs/superpowers/specs/2026-09-13-tactical-siege-pilot-design.md`  
**Baseline:** `main` at `957a4ae8ddb7de50b3c03858eeaeaef35f8a2260`  
**Delivery:** one draft PR for docs + implementation + tests + gameplay evidence

## Delivery rules

- Continue implementation on the same PR created by this planning change.
- Do not create foundation/integration/QA child PRs.
- Do not create a new Linear issue for implementation.
- HPA-476 remains the standalone image-generation/art ticket; HPA-468 uses procedural placeholders only.
- Do not edit `project.pbxproj`; synchronized source groups pick up new Swift files automatically.
- Keep game rules in pure Swift value types. SpriteKit only renders/applies them.
- No save migration or compatibility layer is required for pre-HPA-468 development saves.

## Task 1 — Introduce the authored siege value model and Falconridge recipe

**Files**

- Create `Pyxis/SiegeState.swift`
- Modify `Pyxis/CityDefinition.swift`
- Modify `Pyxis/Country1CityCatalog.swift`
- Create `PyxisTests/SiegeStateTests.swift`
- Modify `PyxisTests/Country1CityCatalogTests.swift`

### 1.1 Write failing pure-model tests

Cover:

- a one-Keep layout exposes the same Keep from all three lanes;
- default lane is the city profile's standard lane;
- objective max HP sums exactly to `KingdomGameState.cityMaxPower(for:)`;
- any integer allocation remainder is assigned to the Keep;
- route resolution returns the first living authored step;
- damage-budget resolution carries spillover from a destroyed objective to the next step;
- a route cannot reach the Keep while its earlier Gate/Tower step is alive;
- Falconridge uses exactly `falconridge.keep`, `falconridge.arrow-tower`, and `falconridge.ridge-gate`;
- Falconridge left route is Tower → Keep;
- center/right are Gate → Keep;
- Falconridge Tower covers all lanes with no duplicate authored coverage lanes;
- City 3 HP resolves to Keep 46 / Tower 23 / Gate 23;
- the other 14 Country 1 cities use the one-Keep layout.

### 1.2 Implement the minimum values

Keep `SiegeState.swift` small:

- `CitySiegeLayout` with nested objective/route/defensive-fire values;
- `SiegeProgress: Codable, Equatable`;
- pure max-HP / remaining-HP / first-live-step / budget-spend helpers.

Use `[BattleLane]` for authored defensive coverage; do not add `Hashable` to `BattleLane` just to introduce a `Set` here.

Prefer static functions or value methods. Do **not** add protocols, repositories, registries, a graph, or a `SiegeEngine` class.

### 1.3 Author the catalog

Add `siegeLayout` to `CityDefinition`.

For non-pilot definitions, construct `.singleKeep(defaultLane: laneDefenseProfile.standardLane)` without duplicating 14 verbose route tables. Falconridge gets the explicit three-objective layout from the design.

**Gate:** focused `SiegeStateTests` + `Country1CityCatalogTests` pass before moving combat code.

---

## Task 2 — Make objective damage and lane choice the persisted KingdomGameState authority

**Files**

- Modify `Pyxis/KingdomGameState.swift`
- Modify `Pyxis/KingdomGameStore.swift` only if serialization tests expose a real need
- Modify `Pyxis/BattleResultModels.swift`
- Modify `PyxisTests/KingdomGameStateTests.swift`
- Modify `PyxisTests/KingdomGameStoreTests.swift`
- Modify existing fixtures that directly seed `cityRemainingPower`

### 2.1 Add red tests for state projections and persistence

Cover:

- fresh City 3 progress defaults to center and zero objective damage;
- `cityRemainingPower` is derived from active objective state rather than separately mutable storage;
- Keep current/max HP are derived independently from total remaining durability;
- Gate/Tower damage changes total progress but not Keep HP;
- Keep zero completes the city even if Tower or Gate survives;
- surviving support objective damage is not fabricated/zeroed on conquest;
- stage/reward/pending result still transition exactly once;
- final objective damage remains available while the pending report exists;
- next-city entry creates fresh progress for that city's layout;
- save/load round-trips selected lane + objective damage;
- malformed/unknown objective IDs are normalized away and damage clamps to objective max;
- no active city may target an objective from another city's layout.

Delete `cityRemainingPower` from encoded mutable state. Keep a read-only compatibility projection if that keeps HUD call sites simple. Tests that need custom tactical damage should seed `SiegeProgress`, not a scalar city HP.

### 2.2 Make live attack events objective-aware

Change `SoldierAttackEvent` from `appliedCityDamage` to:

- `objectiveID`
- `appliedDamage`

Update `ActiveSiegeSession.recordAttack` to keep the existing report attribution by soldier type/source/lane. Do not add objective rows to `BattleResult` in this ticket; the existing result only needs the actual total damage attribution.

### 2.3 Update KingdomGameState live damage application

`applyLiveSoldierAttacks` should:

1. validate the objective ID against the current authored layout;
2. clamp to remaining HP;
3. apply damage into `SiegeProgress`;
4. record exactly the applied amount into the active siege session;
5. complete when the Keep reaches zero.

Keep one reward and the existing pending-result path.

### 2.4 Route idle/Camp/Map building damage through the selected lane

Replace direct subtraction from aggregate city HP in `applyAbstractBuildingSpawnDamage`.

For each `BuildingSpawn`:

- compute existing trait-adjusted attack power;
- spend it as one damage budget through the selected lane;
- carry the same spawn's remainder into the next route objective if the first falls;
- record the spawn's actual applied total via `recordIdleDamage`;
- stop immediately if Keep destruction completes the city.

Do not synthesize Soldier objects or offline losses.

Keep unchanged:

- 8-hour catch-up cap;
- `idleBuildingProductionScale == 10`;
- no buildings = no damage;
- at-most-one city conquest;
- deliberate Camp build/upgrade routing behavior;
- pending-first report behavior.

### 2.5 Add one lane-selection mutation

Add a model mutation such as:

```swift
@discardableResult
mutating func selectAssaultLane(_ lane: BattleLane, at date: Date = Date()) -> IdleProgressResult
```

Contract:

- if an inactive/offscreen interval is armed, resolve it under the **old** selected lane first;
- if that resolution conquers the city, leave selection unchanged;
- otherwise persist the new lane;
- if no inactive interval is armed, do not create extra building production.

This is the only production write path for selected lane.

**Gate:** focused state/store tests prove persistence, old-lane settlement, spillover, Keep victory, and exactly-once reward before scene integration.

---

## Task 3 — Evolve BattleCombatState from one city target to authored route targets

**Files**

- Modify `Pyxis/BattleCombatState.swift`
- Modify `PyxisTests/BattleCombatStateTests.swift`
- Modify event-driven tests in `PyxisTests/BattleResultModelsTests.swift` if present

### 3.1 Keep actor simulation transient

Do not persist objective HP inside `BattleCombatState`.

Each tick receives an ephemeral current-siege snapshot projected from `KingdomGameState` (layout + remaining HP). `BattleCombatState` may mutate a local copy for ordering inside the tick, then returns objective-aware events that the model applies.

### 3.2 Red tests for ordered movement and attacks

Cover deterministic explicit-lane cases:

- soldier in left lane stops in range of Tower, not Keep;
- soldier in center/right stops at Ridge Gate while Gate lives;
- destroying the current target allows later ticks/soldiers to continue toward Keep;
- attack event reports the objective ID and clamped damage;
- two soldiers in one tick cannot both overkill the same objective;
- soldier already in lane A is unaffected when the selected lane later becomes B;
- building/manual spawn source does not change targeting.

### 3.3 Gate defensive fire by a live source

Update the current tower-fire branch rather than adding a second shooter:

- source objective must be alive in the tick snapshot;
- target only soldiers whose lane is in `coveredLanes`;
- reuse current tower range, cooldown, random occupied-lane selection, foremost-target selection, and lane damage multipliers;
- when only one covered occupied lane exists, preserve deterministic no-RNG behavior;
- a dead Falconridge Tower emits no later shots;
- non-pilot single-Keep layouts retain the current defensive fire until Keep conquest.

The old unconditional/global tower path must disappear.

### 3.4 Spawn into the persisted selected lane

In BattleScene integration points, both:

- manual `spawnSoldier()`;
- building-spawn conversion inside `advanceCombat`;

pass `lane: state.siegeProgress.selectedLane` into the existing spawn API.

No global RNG lane assignment remains for production spawns. Keep the optional/random spawn overload if tests or internal helpers still need it; do not build a new spawn API layer.

**Gate:** `BattleCombatStateTests` cover route target, range, disabled Tower, coverage, and existing soldier lane stability.

---

## Task 4 — Reuse the existing Forged lane chips as the assault selector

**Files**

- Modify `Pyxis/BattleHUDNode.swift`
- Modify `Pyxis/BattleChromeLayout.swift`
- Modify `Pyxis/BattleScene.swift`
- Modify `PyxisTests/BattleChromeLayoutTests.swift`
- Modify `PyxisTests/BattleHUDContentTests.swift`
- Modify `PyxisTests/BattleHUDNodeTests.swift`
- Modify `PyxisTests/BattleSceneTests.swift`

### 4.1 Extend the existing HUD projection and layout

Add `selectedAssaultLane` to `BattleHUDContent` from `state.siegeProgress.selectedLane`.

Add `BattleHUDNode.Action.selectLane(BattleLane)`.

Keep `laneChipFrames` as the existing 26pt visual frames. Add `laneChipHitFrames: [BattleLane: CGRect]` to `BattleChromeLayout`, derived from those visual frames and expanded/clamped to at least 44×44 inside `battlefieldFrame`. This mirrors the existing medallion visual/hit-frame pattern and keeps one geometry authority.

Pin `BattleChromeLayoutTests` for:

- three visual frames + three hit frames;
- visual frames remain contained in the battlefield;
- hit frames are contained and at least 44×44;
- each hit frame contains its corresponding visual frame;
- lane hit frames do not overlap unrelated top/bottom HUD controls.

### 4.2 Show one assault flag, not a second lane taxonomy

Preserve the current OPEN / HELD role visuals for exposed/fortified lanes. The standard lane does not need a new role label.

- all three lane-entry hit regions are selectable;
- selected lane receives the selected treatment and one small procedural flag / `ASSAULT` cue;
- exactly one assault flag is visible;
- `BattleHUDNode.action(at:)` resolves `.selectLane` from `laneChipHitFrames`.

No new command strip or modal selector.

### 4.3 Consume lane input before any fallback scene touch

In `BattleScene.handleBattleHUDTouch`:

- route `.selectLane` to `KingdomGameState.selectAssaultLane`;
- save on successful selection/settlement;
- if old-lane settlement produced conquest, reuse the existing fresh-idle/pending report path instead of inventing a lane-selection result screen;
- refresh HUD/objectives after a normal selection.

Pin tests that touching these existing controls does not change lane:

- Settings gear/modal;
- Deploy;
- soldier medallions;
- Battle/Camp/Map tabs;
- income/city tooltip frames;
- conquest Continue.

**Gate:** Battle layout/HUD/scene tests prove selection is visible, persists, has 44pt hit targets, and does not fall through.

---

## Task 5 — Render Falconridge objectives and keep Living Kingdom truthful

**Files**

- Modify `Pyxis/BattleScene.swift`
- Modify `Pyxis/LivingKingdomPresentation.swift`
- Modify `Pyxis/CountryMapScoutCardContent.swift`
- Modify Scout rendering only where necessary for the existing secondary hint
- Modify `PyxisTests/BattleSceneTests.swift`
- Modify `PyxisTests/LivingKingdomPresentationTests.swift`
- Modify `PyxisTests/CountryMapScoutCardContentTests.swift`

### 5.1 Add local procedural objective nodes

Keep `enemy-city` as the Keep.

Add private scene builders for:

- Falconridge Ridge Gate;
- Falconridge Arrow Tower;
- objective name/HP treatment;
- ruined Gate/Tower treatment;
- Tower coverage overlay on covered lane paths.

Place nodes with existing `BattlefieldLayout.point(forLane:position:)` and authored visual anchors. Avoid a new layout model unless a failing compact/iPad geometry test demonstrates one is required.

Rebuild presentation from `SiegeProgress` on redraw/init. A destroyed Tower must remain ruined after tab switch/relaunch and its coverage treatment must remain absent.

### 5.2 Switch fortress damage stage to Keep HP

Change Battle's `LivingKingdomPresentation` projection to receive/use derived Keep remaining/max HP.

Tests:

- damaging Gate/Tower only leaves fortress stage intact;
- actual Keep thresholds drive intact/damaged/breached;
- Keep destruction still requests conquered/collapse behavior;
- non-pilot one-Keep cities preserve current HPA-478 thresholds.

### 5.3 Update the existing Falconridge Scout hint

Keep the same card and action. Add one concise pilot-only tactical hint sourced from the authored route shape, for example:

`Left: silence Tower · Center: break Gate`

Do not add another inspector, route screen, or stored hint state.

### 5.4 Lock the HPA-476 placeholder contract

The implementation should name placeholder nodes/assets against the design contract:

- `siege-gate` — 256×160 source contract, bottom-center, intact/ruined;
- `siege-arrow-tower` — 256×320, bottom-center, intact/ruined;
- `siege-assault-flag` — 128×160, bottom-center, selected.

HPA-468 does **not** create those image files. Procedural SpriteKit shapes are the shipping placeholder for this PR.

**Gate:** scene tests prove objective identity/HP, ruins, coverage disappearance, Keep-only Living Kingdom damage, and Scout hint.

---

## Task 6 — Regression, gameplay comparison, and PR evidence

### 6.1 Focused automated pass

Run focused suites first with parallel testing disabled:

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/SiegeStateTests \
  -only-testing:PyxisTests/Country1CityCatalogTests \
  -only-testing:PyxisTests/KingdomGameStateTests \
  -only-testing:PyxisTests/KingdomGameStoreTests \
  -only-testing:PyxisTests/BattleCombatStateTests \
  -only-testing:PyxisTests/BattleChromeLayoutTests \
  -only-testing:PyxisTests/BattleHUDContentTests \
  -only-testing:PyxisTests/BattleHUDNodeTests \
  -only-testing:PyxisTests/BattleSceneTests \
  -only-testing:PyxisTests/LivingKingdomPresentationTests \
  -only-testing:PyxisTests/CountryMapScoutCardContentTests
```

Use an available simulator name if iPhone 17 is not installed locally.

### 6.2 Full repo gates

```bash
swiftlint lint

xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO
```

Keep the existing Codecov target; do not lower coverage thresholds to land HPA-468.

### 6.3 Required manual/gameplay evidence

Use DEBUG city jump / existing fixture tooling; do not add a new dev-tools framework.

Record:

1. **Falconridge tower-first run (left)**
   - same starting camp/buildings/upgrades as run 2;
   - Tower falls before Keep can be attacked;
   - no Tower shot occurs after destruction;
   - record active siege time and losses from the existing result/report data.

2. **Falconridge gate-first run (center)**
   - same starting camp/buildings/upgrades;
   - Gate falls before Keep can be attacked;
   - Tower may survive Keep conquest;
   - record active siege time and losses.

3. **State restoration**
   - damage Tower/Gate, change lane, leave Battle, return/relaunch;
   - verify objective HP/ruins + lane selection persist.

4. **Offline blocking**
   - arm idle progress with a Gate alive;
   - verify damage consumes Gate first and only spills to Keep after Gate dies.

5. **Non-pilot smoke**
   - City 1 or City 2 still behaves as one Keep with defensive fire and normal conquest/report routing.

6. **Layout smoke**
   - compact phone;
   - portrait iPad;
   - lane entrances remain tappable, objective labels fit, Settings/tab/report input is unaffected.

Add a compact evidence table to the PR description before moving the PR out of draft. Do not create a separate QA document unless the evidence no longer fits cleanly in the PR.

## Expected implementation footprint

New production surface should stay close to:

- one pure `SiegeState.swift` model/helper file;
- existing catalog/state/combat/result files;
- existing Battle layout/HUD/scene;
- existing Living Kingdom + Scout projections.

If implementation starts requiring a route graph, pathfinder, second combat state, per-objective repository, new scene router, or broad generic framework, stop and simplify back to the authored ordered-route model before continuing.
