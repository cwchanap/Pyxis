# HPA-468 Tactical Siege Pilot Implementation Plan

**Ticket:** HPA-468  
**Design:** `docs/superpowers/specs/2026-09-13-tactical-siege-pilot-design.md`  
**Baseline:** `main` at `957a4ae8ddb7de50b3c03858eeaeaef35f8a2260`  
**Delivery:** one draft PR for docs + implementation + tests + gameplay evidence

## Delivery rules

- Continue implementation on this same PR. No foundation/integration/QA child PRs.
- Do not create another Linear issue for implementation.
- HPA-476 remains the only image-generation/art-production task; HPA-468 uses procedural placeholders.
- Do not edit `project.pbxproj`; synchronized source groups pick up files automatically.
- Keep rules/layout math in pure Swift values and keep SpriteKit as renderer/input owner.
- Old development saves may reset. Do not add migration or compatibility layers.
- Do not preserve a scalar HP authority or RNG lane-spawn path merely to reduce test churn.

## Task 1 — Add the fail-closed authored siege model

**Files**

- Create `Pyxis/SiegeState.swift`
- Modify `Pyxis/CityDefinition.swift`
- Modify `Pyxis/Country1CityCatalog.swift`
- Create `PyxisTests/SiegeStateTests.swift`
- Modify `PyxisTests/Country1CityCatalogTests.swift`

### 1.1 Red tests: authored invariants and route math

Cover:

- exactly one Keep is required;
- objective IDs are unique/non-empty;
- weights are positive;
- objective and route progress are within `0...1`;
- each route is non-empty, references existing objective IDs, and ends at the one Keep;
- default lane has a route;
- defensive-fire source exists and coverage lanes contain no duplicates;
- invalid authored layouts precondition/fail immediately rather than silently normalizing;
- `singleKeep(defaultLane:)` creates a valid one-Keep layout for all three routes;
- max-HP allocation sums exactly to `KingdomGameState.cityMaxPower(for:)` and gives integer remainder to Keep;
- first-live-step lookup respects ordered blockers;
- damage-budget spend carries spillover only after the current route objective dies.

Falconridge catalog pins:

- objective IDs: `falconridge.keep`, `falconridge.arrow-tower`, `falconridge.ridge-gate`;
- HP allocation: Keep 46 / Tower 23 / Gate 23;
- left: Tower `0.68` → Keep `1.0`;
- center/right: Gate `0.58` → Keep `1.0`;
- default center;
- Tower source covers all three lanes;
- other 14 cities use `singleKeep`.

### 1.2 Implement only the needed pure values

`SiegeState.swift` owns:

- `CitySiegeLayout` + nested objective/route/defensive-fire values;
- invariant-checking initializer;
- `.singleKeep(defaultLane:)`;
- `SiegeProgress: Codable, Equatable`;
- pure max/remaining HP, first-live-step, and route-budget-spend helpers.

Use `[BattleLane]` for authored defensive coverage. Do not add a graph, registry, protocol hierarchy, repository, or `SiegeEngine`.

### 1.3 Extend the catalog

Add `siegeLayout` to `CityDefinition`. `Country1CityCatalog` stays the only authored Country 1 location for these layouts.

**Gate:** `SiegeStateTests` + `Country1CityCatalogTests` green before persistence/combat work.

---

## Task 2 — Replace scalar city HP with persisted siege progress and Keep authority

**Files**

- Modify `Pyxis/KingdomGameState.swift`
- Modify `Pyxis/BattleResultModels.swift`
- Create one small test-only helper, e.g. `PyxisTests/SiegeTestSupport.swift`
- Modify `PyxisTests/KingdomGameStateTests.swift`
- Modify `PyxisTests/KingdomGameStoreTests.swift`
- Mechanically update direct scalar-HP fixture sites, including `BattleSceneTests`, `CountryMapSceneTests`, `BuildingViewSceneTests`, and later `ForgedVisualFixture`

`KingdomGameStore.swift` itself is a generic JSON encoder/decoder and should not gain siege-specific logic. The schema work belongs in `KingdomGameState.CodingKeys`/decode/init normalization; store tests pin the round trip.

### 2.1 Red tests: persisted authority

Cover:

- fresh City 3 defaults to center with zero objective damage;
- `siegeProgress` is encoded/decoded through `KingdomGameState.CodingKeys`;
- unknown saved objective IDs are discarded and damage clamps to objective max;
- `currentKeepRemainingPower` / `currentKeepMaxPower` are derived from the authored Keep;
- Gate/Tower damage does not change Keep HP;
- Keep zero completes immediately even with live support objectives;
- support objectives are not fabricated as destroyed on conquest;
- reward/stage/pending result finalize exactly once;
- pending-result state retains objective damage long enough for truthful restored Battle presentation;
- next-city entry creates fresh progress for the next layout.

### 2.2 Remove scalar HP compatibility from production

Remove independently encoded/mutable `cityRemainingPower` and update production call sites instead of retaining it as a compatibility property.

Keep:

- `cityMaxPower` as the existing total durability **budget** used to allocate objective max HP;
- `currentKeepRemainingPower` / `currentKeepMaxPower` as the player/win-facing HP authority.

A debug/test-only total-objective remaining projection is acceptable if it materially simplifies assertions. It must not drive gameplay or UI.

Use one shared test helper to build states by **Keep remaining HP** plus optional support-objective damage, so tests do not repeat stable objective IDs. Do not replace one scalar literal with hundreds of `"*.keep"` literals.

Run a repository search for direct `cityRemainingPower` reads/writes and classify every remaining one. No production win/tick/HUD/Living-Kingdom reader should remain.

### 2.3 Make attack events objective-aware

Change `SoldierAttackEvent` from `appliedCityDamage` to:

- `objectiveID`;
- `appliedDamage`.

`ActiveSiegeSession.recordAttack` continues to aggregate actual type/source/lane damage only; no per-objective report rows are added.

### 2.4 Apply live damage by objective, win by Keep

`KingdomGameState.applyLiveSoldierAttacks`:

1. validates objective ID against current layout;
2. clamps to that objective's remaining HP;
3. records actual applied damage;
4. updates `SiegeProgress`;
5. after each event checks **Keep remaining HP**;
6. finalizes exactly once when Keep reaches zero and stops processing further attacks.

Never use total remaining structure durability as the conquest guard.

### 2.5 Route idle/Camp/Map damage through the selected lane

Replace scalar subtraction in `applyAbstractBuildingSpawnDamage`.

For each `BuildingSpawn`:

- compute current trait-adjusted attack power;
- spend it through the selected lane's ordered route;
- spill only after an objective dies;
- record actual applied total via existing idle attribution;
- stop immediately if Keep reaches zero, regardless of surviving optional objectives.

Keep unchanged: 8-hour cap, `idleBuildingProductionScale == 10`, no-buildings/no-progress rule, at-most-one-city conquest, pending-first report, and deliberate Camp conquest routing.

### 2.6 Add one settle-before-select mutation

Add `KingdomGameState.selectAssaultLane(_:at:)` (exact return shape may reuse `IdleProgressResult`).

Contract:

- if inactive/offscreen time is armed, settle it under the old selected lane first;
- if that settlement conquers Keep, do not change selection;
- otherwise persist the new lane;
- an ordinary Battle tap with no armed interval creates no extra production.

This is the only production write path for selected lane.

**Gate:** state/store tests prove coding, normalization, Keep-only victory, old-lane settlement, spillover, and exactly-once reward.

---

## Task 3 — Make `BattleCombatState` objective-aware with explicit selected lanes

**Files**

- Modify `Pyxis/BattleCombatState.swift`
- Modify `PyxisTests/BattleCombatStateTests.swift`
- Modify `PyxisTests/BattleResultModelsTests.swift` where event field names change

### 3.1 Tick an ephemeral siege snapshot

Replace `tick(deltaTime:cityRemainingHP:)` with a tick input that contains the current authored layout + remaining objective HP/Keep identity.

`BattleCombatState` may mutate a local copy during one tick to avoid overkill races; persisted HP remains in `KingdomGameState`.

`TickResult.didReachConquest` means **local Keep remaining HP reached zero**, never “sum of objective HP reached zero.”

### 3.2 Red tests: target/range/order

Cover:

- left soldier stops in range of Tower, not Keep;
- center/right soldier stops at Gate while Gate lives;
- destroyed current target allows later movement/attacks toward the next route step;
- events carry objective ID + clamped applied damage;
- two same-tick soldiers cannot overkill one objective;
- Keep reaching zero sets conquest even if Tower/Gate remain;
- existing soldier lane does not change when selected lane changes;
- manual/building source does not change route targeting.

### 3.3 Make defensive fire source-relative

Replace the unconditional tower branch with the layout's live defensive-fire source.

Range contract:

```text
inRange = soldier.position >= max(0, sourceObjective.visualProgress - towerAttackRange)
```

Pin deterministic cases:

- Falconridge Tower at `0.68` with range `0.55` starts coverage at `0.13`;
- a left-route Archer attacking the Tower is still in Tower range;
- dead Falconridge Tower produces no later shot;
- non-pilot Keep source at `1.0` preserves the current `1.0 - towerAttackRange` threshold;
- target selection remains foremost living soldier in an authored covered occupied lane;
- lane defense multiplier still scales incoming Tower/Keep fire.

Do not add a second shooter or a special ranged immunity.

### 3.4 Remove production RNG spawn assignment

Require explicit lane for production/test soldier spawning. Both BattleScene production sources pass `state.siegeProgress.selectedLane`:

- manual Deploy;
- building-produced spawn conversion.

Do not retain an optional/random spawn overload as a second behavior. Combat RNG remains only for actual random choices still in the model (for example multiple occupied defensive-fire lanes).

Add non-pilot model/scene tests:

- City 1 fresh/default spawn uses its standard lane;
- selecting City 1's exposed lane causes new spawns to use exposed lane and receive its existing `0.80×` incoming defensive-fire multiplier;
- a soldier deployed before selection stays in its original lane.

### 3.5 Pin trait independence

After Falconridge's Arrow Tower objective is destroyed:

- defensive fire is disabled;
- `CityDefenseTrait.arrowTower` remains active for soldier→Gate/Keep damage;
- e.g. Archer/Mage remain disadvantaged at `0.80×`, Infantry/Cavalry favorable at `1.25×`.

**Gate:** combat tests prove Keep liveness, source-relative fire, no RNG spawn path, non-pilot lane behavior, and trait independence.

---

## Task 4 — Reuse Forged lane chips and switch Battle HP presentation to Keep

**Files**

- Modify `Pyxis/BattleChromeLayout.swift`
- Modify `Pyxis/BattleHUDNode.swift`
- Modify `Pyxis/BattleScene.swift`
- Modify `PyxisTests/BattleChromeLayoutTests.swift`
- Modify `PyxisTests/BattleHUDContentTests.swift`
- Modify `PyxisTests/BattleHUDNodeTests.swift`
- Modify `PyxisTests/BattleSceneTests.swift`

### 4.1 Add one lane hit geometry contract

Keep current `laneChipFrames` as 26pt visual frames. Add `laneChipHitFrames: [BattleLane: CGRect]`, derived from them and expanded/clamped to at least 44×44 inside `battlefieldFrame`.

Tests pin:

- three visual + three hit frames;
- every hit frame contains its visual frame;
- hit frames are at least 44×44 and contained in battlefield;
- they do not overlap unrelated HUD controls.

No scene-local duplicate geometry.

### 4.2 Extend HUD content/action

`BattleHUDContent`:

- add selected assault lane;
- replace aggregate city HP fields with `keepRemainingPower` / `keepMaxPower`;
- progress bar renders Keep HP only.

`BattleHUDNode.Action` adds `.selectLane(BattleLane)`.

Presentation:

- exposed/fortified keep OPEN / HELD treatment;
- standard lane remains visually neutral when unselected;
- exactly selected lane gets one procedural flag + `ASSAULT` treatment;
- all three lane hit frames are selectable.

### 4.3 Route lane input through state

`BattleScene.handleBattleHUDTouch` routes `.selectLane` to `selectAssaultLane`, saves state, and refreshes HUD/objective nodes.

If settle-before-select conquers the Keep, reuse the existing fresh-idle/pending-result flow. No lane-specific result screen.

Pin no-fallthrough for Settings, Deploy, medallions, tabs, income/city tooltip frames, and conquest Continue.

### 4.4 Remove the global HP story from Battle UI

Update all player-facing readers in the same task:

- top HUD progress = Keep current/max;
- `layoutCityHPBar` = Keep current/max;
- `showCityInfoTooltip` says Keep HP current/max;
- no Gate/Tower hit changes these Keep displays.

Gate/Tower get their own objective HP labels in Task 5.

**Gate:** Battle layout/HUD/scene tests prove 44pt selection, persistence, Keep-only HP presentation, and input isolation.

---

## Task 5 — Render objectives, keep Living Kingdom truthful, and fit Scout copy

**Files**

- Modify `Pyxis/BattleScene.swift`
- Modify `Pyxis/LivingKingdomPresentation.swift`
- Modify `Pyxis/CountryMapScoutCardContent.swift`
- Modify `Pyxis/CountryMapScoutCardNode.swift`
- Modify `Pyxis/CountryMapScoutCardLayout.swift` only if the measured footer cannot fit within the current frame at the approved minimum font
- Modify `Pyxis/ForgedVisualFixture.swift`
- Modify `PyxisTests/BattleSceneTests.swift`
- Modify `PyxisTests/LivingKingdomPresentationTests.swift`
- Modify `PyxisTests/CountryMapScoutCardContentTests.swift`
- Modify `PyxisTests/CountryMapScoutCardTextLayoutTests.swift`
- Modify `PyxisTests/CountryMapScoutCardNodeTests.swift`
- Modify `PyxisTests/ForgedVisualFixtureTests.swift`

### 5.1 Add local procedural Falconridge nodes

Keep `enemy-city` as Keep. Add private BattleScene builders only for:

- Ridge Gate;
- Arrow Tower;
- objective name/HP treatment;
- ruined Gate/Tower treatment;
- live-Tower coverage overlay.

Use `BattlefieldLayout.point(forLane:position:)` + authored progress. Do not add a scene-object framework.

Rebuild from persisted progress on redraw/relaunch; destroyed objectives stay ruined and a dead Tower has no coverage treatment.

### 5.2 Living Kingdom uses Keep current/max

Change/rename the Battle projection inputs so callers pass Keep remaining + Keep max, not aggregate durability budget.

Tests pin:

- Falconridge starts intact at `46/46`;
- damaging only Gate/Tower does not change fortress stage;
- City 3 integer threshold tests use Keep max 46;
- Keep thresholds drive intact/damaged/breached/conquered;
- non-pilot one-Keep city thresholds remain equivalent to HPA-478.

Update `ForgedVisualFixture.battleState` / `conquestState` to seed siege progress/Keep HP instead of assigning `cityRemainingPower`. Pin the fixtures with their existing tests.

### 5.3 Scout hint is measured, not blindly swapped

`CountryMapScoutCardContent.Scout` may carry one optional tactical footer. Falconridge projects concise copy such as:

`L Tower · C/R Gate`

Other cities retain `Open: <lane>`.

In `CountryMapScoutCardNode.prepareScout`:

- measure the selected footer against `layout.exposedLaneFrame`;
- fit Falconridge tactical copy with `SingleLineTextFitter` (or the existing equivalent) down to an explicit small minimum;
- preserve the current fail-closed behavior if required content genuinely cannot fit;
- if the concise copy still cannot fit at the floor, adjust the footer frame within `CountryMapScoutCardLayout` rather than shipping a disappearing card.

Tests must include the supported compact-phone geometry and prove the Falconridge card presents with its tactical footer.

### 5.4 Lock HPA-476 placeholder contract

No generated files in HPA-468. Procedural placeholders use these future names/contracts:

- `siege-gate` — 256×160 source contract, bottom-center, intact/ruined;
- `siege-arrow-tower` — 256×320, bottom-center, intact/ruined;
- `siege-assault-flag` — 128×160, bottom-center, selected.

**Gate:** scene/Living-Kingdom/Scout/fixture tests prove truthful Keep HP, ruins, Tower coverage removal, compact Scout fit, and no generated art.

---

## Task 6 — Regression, gameplay comparison, and evidence

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
  -only-testing:PyxisTests/CountryMapScoutCardContentTests \
  -only-testing:PyxisTests/CountryMapScoutCardTextLayoutTests \
  -only-testing:PyxisTests/CountryMapScoutCardNodeTests \
  -only-testing:PyxisTests/ForgedVisualFixtureTests
```

Use an installed simulator if iPhone 17 is unavailable.

### 6.2 Full gates

```bash
swiftlint lint

xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO
```

Keep current Codecov project/patch target. Do not weaken coverage.

### 6.3 Required gameplay/manual evidence

Use existing DEBUG city jump/fixture tooling; no new dev-tools framework.

1. **Falconridge tower-first / left**
   - same camp/buildings/upgrades as center run;
   - Tower falls before Keep is reachable;
   - source-relative fire threatens the attack while Tower lives;
   - no shots after Tower death;
   - `.arrowTower` soldier damage trait still applies after Tower death;
   - record active time/losses.

2. **Falconridge gate-first / center**
   - same setup;
   - Gate falls before Keep;
   - Tower may survive Keep conquest;
   - conquest happens immediately on Keep zero;
   - record active time/losses.

3. **State restoration**
   - partially damage/destroy support objective, select another lane, leave/relaunch;
   - objective state + selected lane survive.

4. **Offline blocking**
   - arm idle progress with Gate alive;
   - selected route consumes Gate first and spills to Keep only after Gate dies;
   - Keep zero stops settlement even if Tower survives.

5. **Non-pilot unified path**
   - City 1 starts on standard lane;
   - switch to exposed lane and confirm new soldiers receive `0.80×` incoming defensive-fire pressure;
   - already-deployed soldier stays in original lane;
   - one-Keep conquest/report routing remains normal.

6. **Layout/input**
   - compact phone + portrait iPad;
   - 44pt lane hit regions are usable;
   - Gate/Tower labels fit;
   - Falconridge Scout card presents/fits;
   - Settings/tabs/Continue remain isolated.

Add a compact evidence table to the PR body before marking ready. Do not create a separate QA doc unless the evidence genuinely cannot fit.

## Expected implementation footprint

New production surface should remain close to:

- one pure `SiegeState.swift` value/helper file;
- existing catalog/state/combat/result files;
- existing Battle layout/HUD/scene;
- existing Living Kingdom + Scout projections;
- procedural BattleScene nodes only.

Test support may add one small Keep-HP state helper. If implementation starts requiring a graph, pathfinder, second combat state/repository, compatibility HP authority, RNG spawn fork, scene router, or generic framework, stop and simplify before continuing.
