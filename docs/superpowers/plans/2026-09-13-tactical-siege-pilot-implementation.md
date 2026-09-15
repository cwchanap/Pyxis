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
- Keep gameplay/layout rules in pure Swift values and SpriteKit as renderer/input owner.
- Old development saves may reset; no migration/compatibility framework.
- Final production must have one Keep authority and one selected-lane spawn path.
- **Every checkpoint must compile the app target.** Temporary scalar fields may remain only until the final cleanup task so intermediate test gates are real; they are not final compatibility APIs.

## Task 0 — Freeze the balance baseline before changing combat

Before implementation changes the City 3 loop, record one current-`main` Falconridge run with a fixed camp/loadout that can be reproduced on the feature branch.

Record:

- camp/buildings/upgrades;
- route is irrelevant on current `main` because production lane assignment is random;
- active battle elapsed time from existing result/session data;
- soldier losses from existing result/session data.

This is not a release gate by itself. It provides the quantitative reference needed because the authored 46/23/23 layout has 69 raw route HP versus today's 92 scalar HP while source-relative Tower fire begins earlier.

Do not add telemetry or a benchmark harness. A reproducible DEBUG/manual setup + compact note in the PR is enough.

---

## Task 1 — Add the fail-closed authored siege model

**Files**

- Create `Pyxis/SiegeState.swift`
- Modify `Pyxis/CityDefinition.swift`
- Modify `Pyxis/Country1CityCatalog.swift`
- Create `PyxisTests/SiegeStateTests.swift`
- Modify `PyxisTests/Country1CityCatalogTests.swift`

### 1.1 Red tests: construction and route math

Cover:

- exactly one Keep;
- objective IDs unique/non-empty;
- positive durability weights;
- objective `visualProgress` within `0...1`;
- routes contain exactly all three `BattleLane` values;
- every route non-empty, references existing IDs, ends at the one Keep, and is non-decreasing by referenced objective progress;
- default lane is valid;
- defensive-fire source exists; coverage is non-empty and duplicate-free;
- invalid authored layouts fail immediately;
- `.singleKeep(defaultLane:)` emits valid total three-lane content;
- max-HP allocation sums exactly to `cityMaxPower` and remainder goes to Keep;
- first-live-target lookup respects route order;
- damage-budget spend spills only after the current objective dies.

Falconridge pins:

- `falconridge.keep`, `falconridge.arrow-tower`, `falconridge.ridge-gate`;
- 46 / 23 / 23 allocation from total 92;
- left route Tower → Keep;
- center/right routes Gate → Keep;
- objective positions: Tower `0.68`, Gate `0.58`, Keep `1.0`;
- default center;
- Tower fire covers all three lanes;
- other 14 cities use `.singleKeep`.

### 1.2 Implement the minimum values

`CitySiegeLayout.routes` is `[BattleLane: [String]]`: ordered stable objective IDs only. Do **not** add `RouteStep.progress`; resolve geometry from `Objective.visualProgress`.

Keep stable string IDs. Do **not** key persistence by `ObjectiveKind`: repeated Gates/Towers are allowed by the ticket/future rollout, so kind is category, not identity.

`SiegeState.swift` owns only:

- `CitySiegeLayout` + nested objective/defensive-fire values;
- invariant-checking init;
- `.singleKeep(defaultLane:)`;
- `SiegeProgress: Codable, Equatable`;
- pure HP allocation/remaining, first-live-target, and route-budget helpers.

No graph, registry, service, protocol hierarchy, second repository, or engine.

### 1.3 Extend the catalog

Add `siegeLayout` to `CityDefinition`. `Country1CityCatalog` remains the only Country 1 authoring site.

**Gate:** app target builds; `SiegeStateTests` + `Country1CityCatalogTests` green.

---

## Task 2 — Add siege persistence/Keep authority **without deleting old scalar readers yet**

This task is intentionally additive so its gate can run. The old scalar is a temporary intra-PR bridge only and is deleted in Task 5.5.

**Files**

- Modify `Pyxis/KingdomGameState.swift`
- Create `PyxisTests/SiegeTestSupport.swift`
- Modify `PyxisTests/KingdomGameStateTests.swift`
- Modify `PyxisTests/KingdomGameStoreTests.swift`

`KingdomGameStore.swift` stays generic JSON plumbing; schema work lives in `KingdomGameState.CodingKeys`/init/decode normalization.

### 2.1 Add test support before mechanical migration

Create one test-only helper that can build current-city states by:

- Keep remaining HP;
- optional support-objective damage;
- optional selected lane.

The helper resolves stable IDs from the current authored layout instead of spreading `"*.keep"` literals. If tests need aggregate objective remaining, calculate it **in this test support file**, not as a production API.

### 2.2 Add `siegeProgress` and Keep projections

Add and test:

- fresh city default lane + zero damage;
- explicit `CodingKeys` encode/decode of `siegeProgress`;
- unknown saved IDs discarded and damage clamped;
- `currentKeepRemainingPower` / `currentKeepMaxPower`;
- next-city entry resets to the next layout;
- pending result keeps progress long enough for restored Battle presentation.

Leave current `cityRemainingPower` storage/readers temporarily in place **only so untouched Battle/HUD/fixture code compiles**. It is not used as the new conquest authority and is not part of the final design.

### 2.3 Add explicit lane-selection result

Add:

```swift
enum AssaultLaneSelectionResult: Equatable {
    case unavailable
    case unchanged(idleProgress: IdleProgressResult)
    case selected(idleProgress: IdleProgressResult)
    case conqueredDuringSettlement(IdleProgressResult)
}
```

`selectAssaultLane(_:at:)` owns settle-before-select:

- settle armed inactive time using old lane first;
- if Keep is conquered, leave selection unchanged and return `.conqueredDuringSettlement`;
- otherwise return `.unchanged` or `.selected` explicitly;
- no armed interval means no synthetic work.

### 2.4 Add objective-aware state mutation helpers

Add the objective mutation/validation paths needed by Task 3, with model tests for:

- Gate/Tower damage does not change Keep HP;
- Keep zero finalizes exactly once despite live support structures;
- support structures are not fabricated as destroyed;
- idle route spending respects blockers/spillover;
- old-lane settlement is used before selection changes.

Do not remove the old scalar field yet.

**Gate:** app target builds; `KingdomGameStateTests` + `KingdomGameStoreTests` green.

---

## Task 3 — Make combat and live/idle damage objective-aware while preserving compile continuity

**Files**

- Modify `Pyxis/BattleCombatState.swift`
- Modify `Pyxis/KingdomGameState.swift`
- Modify `Pyxis/BattleResultModels.swift`
- Modify `Pyxis/BattleScene.swift` only for the minimum tick/spawn call-site switch required here
- Modify `PyxisTests/BattleCombatStateTests.swift`
- Modify `PyxisTests/BattleResultModelsTests.swift`
- Modify `PyxisTests/KingdomGameStateTests.swift`
- Modify `PyxisTests/ActiveSiegeLifecycleTests.swift`

### 3.1 Tick an ephemeral siege snapshot

Replace the live simulator's scalar target input with an ephemeral current-siege snapshot containing:

- authored layout;
- objective remaining HP;
- Keep identity.

`BattleCombatState` may mutate a local copy during a tick to prevent same-tick overkill; persisted state remains in `KingdomGameState`.

`TickResult.didReachConquest` means local Keep reached zero.

During this task, keep any legacy event/scalar field still required by untouched readers only long enough for compilation; mark it for Task 5.5 deletion. Do not let it decide targets or conquest.

### 3.2 Target by objective identity; position by objective

Tests pin:

- left soldier stops at Tower, center/right at Gate;
- target position is referenced objective's `visualProgress`;
- destroyed target allows continuation to next ID;
- same-tick attacks cannot overkill one objective;
- Keep-zero conquest works with surviving optional structures;
- deployed soldier lane remains stable;
- manual/building source does not change route targeting.

### 3.3 Source-relative defensive fire

Replace the unconditional global tower branch:

```text
inRange = soldier.position >= max(0, sourceObjective.visualProgress - towerAttackRange)
```

Pin:

- Falconridge source `0.68`, range `0.55` → threshold `0.13`;
- a left-route Archer attacking Tower is still inside coverage;
- dead Tower emits no later shot;
- non-pilot Keep source `1.0` preserves current threshold;
- covered-lane/foremost-target/current lane-multiplier behavior remains.

### 3.4 Remove production random-lane behavior

Make production/test spawn lane explicit. `BattleScene` manual + building-produced spawns pass `state.siegeProgress.selectedLane`.

No optional/random production overload remains. RNG stays only for true random choices such as choosing among multiple occupied defensive-fire lanes.

Pin City 1:

- default standard-lane spawn;
- selecting exposed lane makes **new** spawns use it and receive current `0.80×` incoming multiplier;
- already-deployed soldiers do not move.

### 3.5 Pin trait independence

After Falconridge Tower objective dies:

- defensive fire is off;
- `.arrowTower` city-wide soldier damage multiplier remains active against Gate/Keep.

### 3.6 Route idle/Camp/Map budgets through the same helper

`applyAbstractBuildingSpawnDamage` uses selected route targeting/spillover, not scalar subtraction. Preserve 8-hour cap, 1/10 production, no-buildings/no-progress, at-most-one-city conquest, reward/report semantics.

**Gate:** app target builds; combat/result/state/lifecycle focused suites green.

---

## Task 4 — Reuse Forged lane chips and switch all Battle player-facing HP to Keep

**Files**

- Modify `Pyxis/BattleChromeLayout.swift`
- Modify `Pyxis/BattleHUDNode.swift`
- Modify `Pyxis/BattleScene.swift`
- Modify `PyxisTests/BattleChromeLayoutTests.swift`
- Modify `PyxisTests/BattleHUDContentTests.swift`
- Modify `PyxisTests/BattleHUDNodeTests.swift`
- Modify `PyxisTests/BattleSceneTests.swift`
- Modify `PyxisTests/BattleSceneCoverageTests.swift`

### 4.1 Add lane hit frames in the existing geometry authority

Keep 26pt visual `laneChipFrames`; add `laneChipHitFrames` expanded/clamped to 44×44+ inside battlefield, mirroring `medallionHitFrames`.

Tests pin three visual/hit frames, containment, minimum size, corresponding visual containment, and no unrelated HUD overlap.

### 4.2 Extend HUD content/action

`BattleHUDContent` gains selected lane and Keep current/max. `BattleHUDNode.Action` gains `.selectLane`.

- all three lanes selectable;
- OPEN/HELD role visuals preserved;
- exactly selected lane gets procedural flag / `ASSAULT` treatment.

### 4.3 Route selection through model result

`BattleScene` handles the explicit `AssaultLaneSelectionResult`:

- `.conqueredDuringSettlement` → existing fresh-idle/pending-result path;
- `.selected` / `.unchanged` → save/refresh as appropriate;
- `.unavailable` → no mutation.

Pin no fallthrough from Settings, Deploy, medallions, tabs, info frames, and conquest Continue.

### 4.4 Switch player HP readers now

Move all Battle player-facing readers to Keep current/max:

- top HUD progress;
- Keep sprite HP bar;
- city tooltip.

Gate/Tower hits must not change Keep displays.

The temporary old scalar may still exist only for remaining non-Battle fixture/test compile continuity until Task 5.5.

**Gate:** app target builds; Battle layout/HUD/scene/coverage suites green.

---

## Task 5 — Render objectives, Living Kingdom, Scout, and fixtures

**Files**

- Modify `Pyxis/BattleScene.swift`
- Modify `Pyxis/LivingKingdomPresentation.swift`
- Modify `Pyxis/CountryMapScoutCardContent.swift`
- Modify `Pyxis/CountryMapScoutCardNode.swift`
- Modify `Pyxis/CountryMapScoutCardLayout.swift` only if measured copy cannot fit existing frame at approved minimum
- Modify `Pyxis/ForgedVisualFixture.swift`
- Modify `PyxisTests/BattleSceneTests.swift`
- Modify `PyxisTests/LivingKingdomPresentationTests.swift`
- Modify `PyxisTests/CountryMapScoutCardContentTests.swift`
- Modify `PyxisTests/CountryMapScoutCardTextLayoutTests.swift`
- Modify `PyxisTests/CountryMapScoutCardNodeTests.swift`
- Modify `PyxisTests/CountryMapScoutCardAcceptanceTests.swift`
- Modify `PyxisTests/ForgedVisualFixtureTests.swift`
- Modify `PyxisTests/SoldierRuntimeGeometryTests.swift` where combat fixture HP changes affect setup

### 5.1 Procedural Falconridge objectives

Keep `enemy-city` as Keep. Add local private scene builders for:

- Arrow Tower + HP/ruin;
- Ridge Gate + HP/ruin;
- live-Tower coverage treatment.

All placement reads `Objective.visualProgress`.

For the shared Gate:

- derive route lanes containing its stable ID;
- render one barrier spanning center/right at `0.58`, sized from existing battlefield lane geometry;
- ruined state spans the same approaches.

Do not add duplicate Gate state or a generic scene-object framework.

### 5.2 Correct defensive-fire projectile origin

Spawn the projectile visual from the actual defensive-fire source objective/node. Falconridge shots leave the Tower at `0.68`, not `enemyGatePoints[lane]`. Non-pilot Keep-source visuals remain equivalent.

### 5.3 Living Kingdom uses Keep only

Pass Keep remaining/max into the existing presentation projection.

Tests pin:

- fresh Falconridge = intact `46/46`;
- Gate/Tower-only damage does not change fortress stage;
- City 3 threshold tests use Keep max 46;
- Keep thresholds drive damage/breach/conquest;
- non-pilot one-Keep behavior stays equivalent.

### 5.4 Scout footer is measured

Falconridge projects concise tactical footer (`L Tower · C/R Gate` or shorter measured equivalent); other cities keep `Open: <lane>`.

Use existing fitter/measurement and fail-closed card path. Add compact-phone node/text-layout/acceptance coverage proving Falconridge card still presents.

### 5.5 Migrate deterministic fixtures

`ForgedVisualFixture.battleState` / `conquestState` and remaining scene/controller fixture helpers seed `SiegeProgress`/Keep HP through `SiegeTestSupport` patterns rather than writing the scalar.

### 5.6 HPA-476 placeholder contract

No generated image files. Keep only future semantic contracts:

- `siege-gate` — bottom-center anchor, intact/ruined;
- `siege-arrow-tower` — bottom-center anchor, intact/ruined;
- `siege-assault-flag` — bottom-center anchor, selected.

Do **not** pin source pixel dimensions before final art exists; HPA-476 chooses real canvas sizes from actual render needs.

**Gate:** app target builds; Battle/Living Kingdom/Scout/fixture focused suites green; compact-phone Falconridge Scout passes.

---

## Task 5.5 — Delete transitional scalar/event residue and prove zero references

This is part of HPA-468, not a follow-up PR.

### 5.5.1 Delete final compatibility residue

Remove from production:

- `cityRemainingPower` storage/init/CodingKeys/reads;
- `SoldierAttackEvent.appliedCityDamage` transitional alias/name in favor of `appliedDamage`;
- `BattleCombatState.TickResult.cityDamage`.

No total-objective remaining production projection is added. Test-only aggregate verification stays in `SiegeTestSupport`.

### 5.5.2 Migrate the real blast radius

Explicitly search/migrate affected suites, including:

- `KingdomGameStateTests`
- `KingdomGameStoreTests`
- `BattleCombatStateTests`
- `BattleResultModelsTests`
- `BattleSceneTests`
- `BattleSceneCoverageTests`
- `BattleHUDNodeTests`
- `CountryMapSceneTests`
- `BuildingViewSceneTests`
- `GameViewControllerTests`
- `ActiveSiegeLifecycleTests`
- `CountryMapScoutCardAcceptanceTests`
- `CountryMapScoutCardContentTests`
- `ForgedVisualFixtureTests`
- `DevJumpStateTests`
- `SoldierRuntimeGeometryTests`
- `AutomaticCombatFeedbackSchedulerTests`
- `DefaultGameplayFeedbackCoordinatorTests`

Use repository search to catch any additional reference rather than assuming this list is exhaustive.

### 5.5.3 Hard cleanup gate

Require:

```bash
grep -R "cityRemainingPower\|appliedCityDamage" Pyxis PyxisTests
```

returns no source references, and search for `cityDamage` confirms the removed `TickResult` field is gone (excluding unrelated prose/docs if any).

Then run a full build + full test suite before Task 6 evidence. This is the point where the final architecture exists: no scalar shim, no old attack field, no write-only tick aggregate.

---

## Task 6 — Regression, balance comparison, and PR evidence

### 6.1 Broad focused automated pass

Run with parallel testing disabled. Include at least:

- `SiegeStateTests`
- `Country1CityCatalogTests`
- `KingdomGameStateTests`
- `KingdomGameStoreTests`
- `BattleCombatStateTests`
- `BattleResultModelsTests`
- `ActiveSiegeLifecycleTests`
- `AutomaticCombatFeedbackSchedulerTests`
- `DefaultGameplayFeedbackCoordinatorTests`
- `BattleChromeLayoutTests`
- `BattleHUDContentTests`
- `BattleHUDNodeTests`
- `BattleSceneTests`
- `BattleSceneCoverageTests`
- `GameViewControllerTests`
- `CountryMapSceneTests`
- `BuildingViewSceneTests`
- `CountryMapScoutCardContentTests`
- `CountryMapScoutCardLayoutTests`
- `CountryMapScoutCardNodeTests`
- `CountryMapScoutCardTextLayoutTests`
- `CountryMapScoutCardAcceptanceTests`
- `LivingKingdomPresentationTests`
- `ForgedVisualFixtureTests`
- `DevJumpStateTests`
- `SoldierRuntimeGeometryTests`

Use `-parallel-testing-enabled NO` and an installed simulator.

### 6.2 Full repository gates

- `swiftlint lint`
- full unit + UI test run with parallel testing disabled
- Debug build
- Release build if touched DEBUG fixture seams make compile-out relevant
- existing Codecov project/patch target; do not weaken coverage
- `git diff --check`

### 6.3 Quantitative Falconridge gameplay comparison

From the **same camp/loadout** used for Task 0 baseline:

1. run Tower-first left;
2. run Gate-first center;
3. record active elapsed time + losses for both;
4. verify Tower death noticeably stops subsequent defensive fire;
5. verify Gate-first can conquer with Tower still alive.

The 46/23/23 allocation intentionally starts at 69 raw route damage versus the baseline 92, while Tower coverage starts earlier. Use the measurements to judge the actual trade.

Retune Falconridge-only weights/fire **within total 92** when either condition holds:

- a new route is an obvious free improvement over the current-main baseline (same-or-lower losses and same-or-faster elapsed time, with at least one strictly better); or
- one new route clearly dominates the other on both elapsed time and losses without a meaningful countervailing advantage.

Also retune if Tower destruction has no noticeable survival consequence. Do not add mechanics to fix balance.

### 6.4 State/lifecycle evidence

- partially damage Gate/Tower, change lane, leave/relaunch → damage/ruin/selection persist;
- idle settlement with Gate alive → Gate consumes damage before Keep;
- old-lane settlement occurs before a lane change;
- settlement conquest returns `.conqueredDuringSettlement` and routes through existing pending Battle result exactly once.

### 6.5 Non-pilot unified-path evidence

Smoke City 1/2:

- fresh standard lane;
- selected exposed lane affects only new spawns and current `0.80×` defensive-fire pressure;
- one-Keep objective path still conquers/reports normally.

### 6.6 Layout/presentation evidence

Smoke:

- compact phone;
- portrait iPad;
- center/right shared Gate visibly spans both blocked approaches;
- objective HP/ruins fit;
- Tower projectile visibly starts at Tower;
- lane hit targets remain usable;
- Settings/tabs/report input unchanged;
- Falconridge Scout card does not disappear.

Add a compact evidence table to the PR before moving it out of draft. Do not create a separate QA artifact unless the evidence genuinely no longer fits the PR.

## Risks and mitigations

### Risk: intermediate branch stops compiling

**Mitigation:** Task 2 is additive; Tasks 3–5 switch readers; Task 5.5 performs final deletion. Every task gate includes an app build.

### Risk: Falconridge becomes materially easier/harder in a confusing way

**Mitigation:** capture current-main baseline first, explicitly acknowledge 69-vs-92 raw route cost and earlier Tower coverage, compare same-camp elapsed/losses, and retune only Falconridge values inside the fixed 92 total.

### Risk: shared Gate is mechanically correct but visually misleading

**Mitigation:** Gate spans the exact lanes whose routes contain its ID; scene tests + compact-phone/iPad smoke happen before final gameplay evidence.

### Risk: large symbol migration misses non-obvious tests

**Mitigation:** add `SiegeTestSupport` before rewrites, list the known lifecycle/controller/feedback suites in focused gates, repository-search all references, and enforce Task 5.5 zero-reference/full-suite gate.

## Expected implementation footprint

New production surface should remain close to one pure `SiegeState.swift` plus changes to existing catalog/state/combat/HUD/scene/Living-Kingdom/Scout owners. New test-only support is one small `SiegeTestSupport.swift`.

If implementation starts requiring a route graph, pathfinder, second combat state, per-objective repository, new router, generic scene-object framework, or additional PR, stop and simplify back to this authored ordered-route design.
