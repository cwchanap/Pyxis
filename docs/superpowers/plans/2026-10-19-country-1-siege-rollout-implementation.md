# HPA-477 — Country 1 Tactical Siege Rollout Implementation Plan

**Date:** 2026-10-19  
**Linear:** https://linear.app/cwchanap/issue/HPA-477/gameplay-roll-proven-tactical-siege-layouts-across-country-1  
**Design:** [2026-10-19-country-1-siege-rollout-design.md](../specs/2026-10-19-country-1-siege-rollout-design.md)  
**Baseline:** `main` `2e7046cbe20a37439636a0d8ee7dbe6c57f3d08a`  
**Delivery:** **one PR #47** for design, implementation, tests, tuning, screenshots, and acceptance. Keep Draft until shipping checks pass; no sub-PRs or separate tickets for this code/content work.

## Minimal change ownership

| Existing owner | Change |
|---|---|
| `Pyxis/SiegeState.swift` | Extend **existing** fail-closed `CitySiegeLayout.init` preconditions: ≤5 objectives, ≤2 Gates, ≤1 Tower, Tower must be the fire source, every support reachable on some route. No new validator, throw, or save fields. |
| `Pyxis/Country1CityCatalog.swift` | Explicit authored layouts for 15 cities, unchanged 3/5 pilots. Definition site for `HighcrestGuardRules` and `freshHighcrest()/normalizedForHighcrest()`: rename alongside any evidence-backed minimal Guard HP/attack scaling; retain Highcrest historical baseline. |
| `Pyxis/CityDefinition.swift` | Once the catalog authors all 15, **require** `siegeLayout: CitySiegeLayout` at init (remove default/fallback). Keep `.singleKeep` as a test fixture. |
| `Pyxis/KingdomGameState.swift` | Update Guard rule/helper call sites, and only if scaling is justified pass the same per-city Guard HP through fresh/idle/catch-up/normalization. No new idle algorithm. |
| `Pyxis/BattleCombatState.swift`, `Pyxis/BattleScene.swift` | Update names; if Guard scaling is required use the same shared values for spawn/restore/combat. No second simulator, wave service, or scene architecture. |
| `Pyxis/CountryMapScoutCardContent.swift` | Keep 1–2 supports' route-derived footer; for 3–4 select one Barracks > source Tower > Gate entry. No new UI/text framework. |
| Existing catalog, siege, Guard, State, scene, Scout, geometry and lifecycle tests | Validate all 15 definitions, reuse pilot pins, test Guard reach and shelter, City 1 assumptions, deterministic watch-only and route comparisons, accessibility/fit. Use existing DEBUG fixtures. |

`AGENTS.md` is a symlink to `CLAUDE.md`; don't edit either merely for this rollout. No new asset files, CI workflow, Xcode project registration, or production framework.

## Checkpoints (all within this PR)

### 0. Reproducible balance baseline and Guard scaling decision

- [ ] Freeze the baseline SHA and record unchanged City 3 Falconridge and City 5 Highcrest gameplay reference with fixed RNG seed, camp buildings/levels, soldier upgrade level, manual spawn policy, default lane and one alternative.
- [ ] Select realistic representative City 9 and City 15 camp loadouts **before authoring**. Compare current 12-HP/3-attack Guards with expected player damage/HP at their upgrade levels (City 15's higher-upgrade camp is the required decision point). Record the decision in the PR body: either shared fixed stats are still consequential or a **single pure City 1–15 Guard HP/attack curve** is needed. Do not defer this decision until after renaming all call sites.
- [ ] If evidence shows trivial late-city Guards, specify the smallest level-aware HP/attack rules alongside `Country1GuardRules`, pin City 5 to **12/3** exactly, and identify all existing active/restore/normalization/idle sites that must use them consistently. Do not create a `GuardProfile`, per-city table of combat engines, new Guard persistence fields, or generic difficulty system. Recalculate the per-city idle absorption ceiling; the old Highcrest-only figure was 12 Guards × 12 HP = 144.
- [ ] Commit **one small bounded Swift Testing run-to-conquest smoke function**, using existing `BattleScene.advanceCombatForTesting(deltaTime:)` and DEBUG test seams, not a second simulator. Fixture: deterministic seed and valid productive camp; report city, lane, loadout, simulated elapsed time, troop losses, Guard waves/reserve and Barracks shutdown. Include a maximum simulated-time bound so a stalled siege fails rather than hanging CI. First prove the harness runtime is acceptable on a pilot before growing its parameter list. No exact balance-value assertions that will fight legitimate tuning.

### 1. Fail-closed layout contracts and catalog-wide geometry tests

- [ ] Add only these `CitySiegeLayout.init` preconditions: 1–5 objectives, ≤2 Gates, ≤1 Tower, all non-Keep objectives reachable on some route, and any Tower is `defensiveFire.sourceObjectiveID`. Preserve existing 3-route/Keep/order/ID/positive-weight checks and default-lane semantics.
- [ ] Do **not** write an in-process `@Test` that expects an invalid initializer to throw: `precondition` traps are uncatchable here. Document the invariant in `SiegeStateTests` and keep valid-layout construction tests; reject a duplicate recoverable validator.
- [ ] In `Country1CityCatalogTests`, add one table-driven test over **all 15 actual definitions** for: budget allocations >0 and sum==cityMaxPower; identical ordered routes have equal *binary* source-fire coverage; Tower-containing routes are covered; Barracks-route stallers stay within the **actual** fire source's range; and Guards reach soldiers stalled at every support objective from the Barracks floor. Derive attack ranges from live `BattleCombatState` as the existing Highcrest shelter test does—do not hard-code archer 0.264 in the test. Keep the existing City 3/5 exact pins.
- [ ] The support/route/source structural rules are already initializer-owned after this checkpoint; **do not redundantly recheck them** in the catalog-wide test. Rewrite the prior `nonPilotCitiesUseSingleKeepDefaultedToTheirStandardLane` test to assert new city features rather than duplicating `CityDefinition` instances as the whole test oracle. Expect fail-first tests before the new content.

### 2. Guard rename (and scaling, only if checkpoint 0 justified it)

- [ ] In `Country1CityCatalog.swift`, rename `HighcrestGuardRules` to `Country1GuardRules` and `GuardReinforcementProgress.freshHighcrest()/normalizedForHighcrest()` to `freshCountry1()/normalizedForCountry1()`. Rename consumers in State, Combat, Scene, and tests in one coherent change.
- [ ] If scaling was justified, implement only shared Guard HP/attack calculations and carry those exact per-city values through spawn, persistence normalization, live restore, Guard hit damage, and idle approximation. Keep the finite **2/30s × 12 reserve**, current Guards-on-selected-lane behavior, and Barracks shutdown semantics unchanged. Do **not** scale wave system complexity or add per-city overrides until a measured need.
- [ ] Run exact Highcrest City 5 Guard/route/persistence/lifecycle tests to prove identical baseline (HP 12, attack 3, wave interval 30, reserve 12, Keep 407/Barracks 20). The first rename commit must not silently change the pilot.

### 3. Explicit city authoring; City 1 is a separate commit *within this same PR*

- [ ] Author **City 1 Willowford only** with the corrected route/fire proposal and positive objective HP. Immediately run the **full serial unit test suite**, not just catalog tests. This reveals tests assuming `currentKeepMaxPower == cityMaxPower` on the default fresh-state path; update expectations to `layout.maxPowerAllocation(...)[keepID]` in `BattleHUDContentTests`, `LivingKingdomPresentationTests`, `SoldierRuntimeGeometryTests`, `ForgedVisualFixtureTests`, and whichever other existing fixtures genuinely require it. Do not restore a production single-Keep fallback just to appease tests.
- [ ] Author City 2, leave City 3 Falconridge untouched, author City 4, leave City 5 Highcrest untouched, then author Cities 6–15 with only Keep/Gate/Tower/Barracks and the exact route/fire-coverage design starting table. Every Tower lane must be covered, identical routes must have identical binary coverage, and Guards must reach/support all stalls. Start Barracks at ~0.72 with other supports at/above that level and confirm geometry.
- [ ] Run the **same catalog-wide tests** and the bounded run-to-conquest smoke as each city is authored. The smoke's mandatory **watch-only/default-lane** case covers all 15 cities; also exercise alternative lanes at **1, 3, 5, 9, 10, 15** under matched camp/seed, repeating any comparisons used to justify actual tuning. Explicitly record City 9 Barracks shutdown time versus the first 30-second Guard wave. No unbounded 15×3×repeats matrix on every CI run unless its runtime has been measured acceptable.
- [ ] Tune authored objective weights/progress, coverage and default lane only to correct concrete stalls, trivial free routes, or irrelevant structures. Guards may use a single evidence-backed scale rule from checkpoint 0; don't add a difficulty tuning framework. Keep city rewards, campaign order, `CityDefenseTrait`, Keep-only win and current idle settlement unchanged.
- [ ] Once all 15 layouts are explicit, remove `CityDefinition.init(siegeLayout: CitySiegeLayout? = nil)` and its `?? .singleKeep` fallback. The argument becomes required; update the catalog's test fixture constructors accordingly. Do not remove `CitySiegeLayout.singleKeep` from model unit tests.

### 4. Scout hints and targeted visual acceptance

- [ ] In `CountryMapScoutCardContent.tacticalFooter`, preserve full existing copy for one/two supports (exact Falconridge unchanged). For three/four supports show only the highest-priority truthful route-derived entry: Barracks > source Tower > Gate, stable tie by authored order. No extra card fields, screen, wrap, or view-side parsing.
- [ ] Extend `CountryMapScoutCardTextLayoutTests.falconridgeTacticalFooterFitsAtAMeasuredSizeInEverySupportedLayout` (rename appropriately) to all **15** cities × existing supported fixtures, including the **portrait iPad lane frame** as the likely 8pt bottleneck. If a two-support footer cannot fit there, shorten it in the projection rather than bypassing the fit check.
- [ ] Verify the **five-structure City 15** on compact supported phone and portrait iPad (objective HP, gate segments/ruins, coverage, Captain/Rally, tabs and report); and at least **City 7 or 13** as the tight Keep-source Barracks case (0.72–1.0 support cluster, Guard movement/status and no overlap). Capture a third visually distinct City 3/9 siege. Use HPA-476 shared images and existing DEBUG city-jump/fixture seams; only add the minimum fixture state required.

### 5. Final regression gates and PR evidence

- [ ] Verify Guard-only live ticks and lane switches persist correctly; destroyed Barracks stops future spawns but does not delete existing Guards. Validate save/relaunch, Map/Camp/idle progress, Captain/Rally automatic behavior, one conquest and exactly-once reward/report on at least one **non-Highcrest** Barracks city.
- [ ] Keep the **committed** bounded smoke test in `PyxisTests`; report reproducible loadout/seed, simulated elapsed time, losses, and Guard data for the default/watch-only route of **all 15**, plus repeatable representative alternate-route comparisons at **Cities 1, 3, 5, 9, 10, 15**. No strict universal cross-lane speed-ratio threshold: different routes deliberately trade structure HP for tower/Guard pressure. Assert the absence of obvious stalls and investigate outliers.
- [ ] Run `swiftlint lint`; focused catalog/geometry/Guard/Scout tests; full serial `PyxisTests` and `PyxisUITests`; simulator Debug + Release builds; unchanged **90% project and patch Codecov** gates. Keep parallel testing **off**. Since draft PR CI build/test jobs are skipped, don't claim a green CI run before Ready for Review.
- [ ] Add measured smoke output, Guard scaling decision, every deliberate authoring deviation, and screenshots to **this same PR**. Recheck no additional runtime abstractions, economy/state changes, asset-generation files, child tickets or PRs.
- [ ] Mark PR ready only when tests and visual acceptance pass. Move Linear HPA-477 to Done only after this PR is merged.

## Focused commands

```sh
swiftlint lint

# Choose a simulator actually installed if iPhone 17 is unavailable.
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test \
  -only-testing:PyxisTests/Country1CityCatalogTests \
  -only-testing:PyxisTests/SiegeStateTests \
  -only-testing:PyxisTests/CountryMapScoutCardTextLayoutTests

# Run full tests immediately after City 1, and again for final acceptance.
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test

xcodebuild -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO \
  -configuration Debug build
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO \
  -configuration Release build
```

## Scope guards

This is mostly authored data plus focused model/scene/fixture tests. Reject procedural encounters, generic difficulty models, extra tower fire sources, save migration/backward compatibility, Guard AI overhauls, new effects/assets/SFX, economy or Country 2 changes. Any required Guard formula must remain one small shared rule with the pilot pinned. No additional PRs for this ticket.
