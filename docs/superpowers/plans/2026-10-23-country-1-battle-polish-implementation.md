# HPA-582 — Country 1 Battle Polish Implementation Plan

**Date:** 2026-10-23  
**Issue:** https://linear.app/cwchanap/issue/HPA-582/gameplay-polish-core-battle-mechanics-and-country-1-pacing  
**Design:** [2026-10-23-country-1-battle-polish-design.md](../specs/2026-10-23-country-1-battle-polish-design.md)  
**Base:** `main` at `7de4bf9fe73d9092a02adc2c954811cf36f710a6`  
**Delivery:** **one PR** for this entire ticket. This draft begins with design+plan; add all implementation, review fixes, tests and evidence on this branch before marking Ready. No separate foundation or follow-up implementation PR.

## Reuse / deletion survey

| Concern | Current production owner | Minimal proposed change |
|---|---|---|
| Chained balance evidence | `PyxisTests/Country1SiegeSmokeTests.swift`, `KingdomGameStore` | Extend the existing DEBUG scene-driven harness with one opt-in sequential campaign test; no parallel simulation engine. |
| Economy and Captain scaling | `KingdomGameState.swift` | Adjust *existing* balance constants only as measured; delete dead upgrade state; expose computed highest-building `captainLevel`. |
| Soldier role lookup | `SoldierType.swift` + `CitySiegeLayout.ObjectiveKind` | Add one pure multiplier function. Live simulator and idle settlement share it. |
| Live hits and manual charges | `BattleCombatState.swift` | Apply role multiplier at each structure hit; add two ephemeral charge fields and tick recharge. |
| Idle hits | `KingdomGameState.applyAbstractBuildingSpawnDamage` | Keep Guard-first and route-spill contracts; apply per-objective multiplier while spending remaining *raw* damage budget. |
| Scene orchestration and FX | `BattleScene.swift` | Gate successful manual deploys, project charge count, detect live object-death transitions, reuse effect helpers. |
| HUD | `BattleHUDContent`, `BattleHUDNode` and current `BattleChromeLayout` | One charge integer on existing deploy action; fit text within existing geometry (no new bar/panel). |
| Test fixtures | `DevJumpState.swift`, `PyxisTests`, DEBUG `BattleScene` seams | Stop faking upgrade level; use existing camp and scene fixtures; add narrow test probes only. |

## Task 0 — Lock baseline before changing balance

- [ ] On current `main`, run focused existing smoke/campaign coverage and record existing per-city evidence. Use the existing `COUNTRY1_SMOKE` format, fixed seed 1, 10 Hz, once-per-second manual attempts, currently authored default lanes. Do **not** transcribe invented baseline numbers.
- [ ] TDD: add an **opt-in** `@Test` in `Country1SiegeSmokeTests` with `.enabled(if: ...)` using `COUNTRY1_SMOKE_CAMPAIGN`. Verify it is disabled for ordinary CI runs.
- [ ] Factor only the minimal scene runner seam needed to take a supplied `KingdomGameState` and return its **actual final state**, without rewriting established independent fixtures. Use a fresh per-test UserDefaults suite and a new `BattleScene` per city; keep one store for the campaign. After each city, use `acknowledgePendingBattleResult()` and `startCityFromMap(nextCity)`.
- [ ] Execute a `RecommendedCampRecommendation.make(for:)` loop: `ready(build)` → `buildBuilding`; `ready(upgrade)` → `upgradeBuilding`; `saveFor` / `noAction` → stop. Assert actual spend, non-negative gold, no duplicate rewards and reset building state. Use deterministic fixture dates to prevent incidental wall-clock idle catch-up. Bound loop iterations by the finite building/cost curve instead of retrying an unaffordable action.
- [ ] Emit one line/city: `COUNTRY1_SMOKE campaign=1 city=... lane=... goldStart=... goldSpent=... goldEnd=... camp=... elapsed=... losses=... outcome=...`. Keep partial lines on stall. Limit each stage to 900 seconds simulated; fail with the first blocked city rather than silently increasing its budget.
- [ ] **Capture and paste PRE-tuning output into this PR's description.** Record which city first stalls and the per-city budget gap; keep the opt-in test present even if it initially fails.

**Evidence gate:** no economy/HP/cost tuning before this baseline is captured. The per-city smoke remains on its existing budget/fixture policy.

## Task 1 — Unit identity and objective roles (ticket item 2)

- [ ] Add failing `SoldierType`/role tests for every 5×4 combination, default 1.0, and trait×role stacking (rounding and minimum damage). Then implement a pure `objectiveDamageMultiplier(against:)` lookup near `SoldierType`. No new SoldierType, status effect or target registry.
- [ ] In `BattleCombatState.tick`, where `targetID` already points to the first living route objective, resolve that objective's kind and multiply `soldiers[index].attackPower` **for that hit** before remaining-HP clamp. Do not mutate cached `attackPower` or boost Guard damage, Captain stats or non-structure attack events.
- [ ] In `KingdomGameState.applyAbstractBuildingSpawnDamage`, leave existing same-lane Guard consumption unchanged. Spend the remainder down the authored route using the same pure role lookup per surviving objective, applying damage and deducting the corresponding raw budget (e.g. ceiling of effective HP absorbed / multiplier, bounded by remaining raw budget) before moving to the next objective. Keep 1.0 spill exactly equivalent to `CitySiegeLayout.spendDamageBudget`.
- [ ] Add red/green tests for a one-objective hit, a Gate→Keep spill, Archer Tower→Keep and Mage Barracks→Keep, damage never crossing an exhausted budget, Guard priority and a neutral-role regression. Recheck trait defense-counter tests.
- [ ] Only change existing `RecommendedCampRecommendation` authored ordering/copy if role checks prove current guidance misleading.

## Task 2 — Delete dormant soldier upgrade and derive Captain level (item 4)

- [ ] Write failing `KingdomGameStateTests`/`ActiveSiegeLifecycleTests`: empty camp → Captain level 1; any type's highest building level sets Captain HP and attack; mixed levels pick max; Captain restore/retreat recovery use current camp's level; a building level change doesn't grant a heal.
- [ ] Remove `normalSoldierUpgradeLevel`, `CodingKeys.normalSoldierUpgradeLevel`, init/decode parameters, stored accessors, `upgradeNormalSoldier()`, `normalSoldierUpgradeCost` and the result enum if now unused. Keep `normalSoldierAttackPower(for:)` because per-type attacks still use it.
- [ ] Add computed `captainLevel` to `KingdomGameState` (max building level or 1) and replace all Captain production reads in state initialization/normalization, fresh city entry, recovery, live HP sync, `BattleScene` spawn/restore and `BattleHUDContent.captainStatus`.
- [ ] Update `DevJumpState` and forged/DEBUG visual fixtures to remove synthetic soldier level; seed a real camp only where a high-level fixture is strictly needed. Update independent smoke initialization and historical tests, but keep their fixed authored camps, lanes and qualitative success contract. No save-version shim or migration.
- [ ] Compile/test all removed-symbol references to zero; run focused Captain, Guard, conquest, store and smoke tests.

## Task 3 — Manual deploy recharge (item 5)

- [ ] First add `BattleCombatStateTests` for initial 3/3, one charge consumed on successful deploy, zero denied, +1 per 1.5 **valid** tick seconds, no overfill, fractional 0.1-second ticks and restart at full on scene reconstruction. Add scene tests that cap/locked type/paused modal do not consume and that building/Captain spawns do not consume.
- [ ] Implement `manualDeployCharges` and `manualChargeRechargeAccumulator` as transient fields in `BattleCombatState`. Recharge as part of its existing `tick` after validation of active `deltaTime` and a live Keep. If full, discard excess accumulator instead of banking bursts. Expose one small consume attempt called only from `BattleScene.spawnSoldier`, after type and manual cap checks.
- [ ] Project charges through `BattleHUDContent.project`. Put the integer in the existing `DEPLOY` text (`DEPLOY · N`) while retaining the existing manual-soldier `N/10` count. Adapt text measurement to the actual rendered string, keep the Captain strip and Rally hit geometry disjoint, and use existing invalid-action feedback on zero.
- [ ] Trigger a HUD apply when the displayed integer changes, not per fractional recharge tick. Verify 375×667 and iPad/City 3+ fits via existing layout and scene coverage, and no spurious persistence.
- [ ] Run the unchanged independent Country 1 smoke tests. Fix genuine newly revealed pacing issues **with tuning at Task 4**, not by silently weakening assertions.

## Task 4 — Rerun chained campaign and tune existing numbers (item 1 completion)

- [ ] Run exactly Task 0's chained recipe *after* soldier roles, upgrade deletion and charges are in place. Paste a post-mechanics, **pre-tuning** 15-city log into the PR.
- [ ] For any stall/outlier, adjust the fewest existing `KingdomGameState.cityMaxPower` / `goldReward` / building build+upgrade costs / spawn intervals necessary. Keep changes global and easy to reason about; avoid city-special-case rewards, hidden boosts, new counters or a difficulty configuration subsystem.
- [ ] Repeat the same chained log and both default and selected alternate-lane smoke tests after each material tuning change. Require 15/15 chained conquests, <=900 simulated seconds for each and no obviously inverted difficulty spike. The exact curves remain empirical, not specified in advance.
- [ ] Add targeted model assertions for meaningful final formulas; retain tests for actual gold conservation, camp reset, progression and exactly-once reward rather than brittle exact combat times. Annotate deliberate tuning with baseline→final deltas in PR description.
- [ ] Preserve the fixed City 3/5 baseline tests' *intent*, not obsolete upgrade-level requirements; tests may update fixtures only where removing the dead system genuinely changes their setup.

## Task 5 — One-shot structure-fall presentation (item 3, last)

- [ ] Add failing `BattleSceneTests` using current DEBUG seams: Gate, Arrow Tower and Barracks each request one fall event at positive→0 HP, multiple hits in same tick still request one per objective, Keep uses old conquest path, prior ruins/restore/resize/idle produce zero new requests. Cover ordinary soldier and Captain damage paths.
- [ ] Capture objective remaining HP around the existing `applyLiveSoldierAttacks`/Captain damage mutation sites. Compare by objective ID; call a compact scene-only `playStructureFall` helper on **fresh non-Keep zero-crossings**. Do not hook `syncSiegeObjectiveNodes` or add durable `hasPlayed` flags.
- [ ] Use objective lane/progress geometry to place effects in `effectsLayer`, surviving the node rebuild on `redraw`. Reuse existing impact flash, brief shake and floating label; stop/skip motion under existing Reduce Motion convention. DEBUG counters are the only new visibility hook.
- [ ] Ensure no HP, attacks, route, gold, report, audio taxonomy or SFX change. No image/audio generation here.

## Task 6 — Final checks and PR evidence

- [ ] Update `CLAUDE.md` accurately: deleted upgrade path; derived Captain level; structure-role table; transient Deploy charges. `AGENTS.md` aliases it—don't modify separately.
- [ ] Run SwiftLint, all new focused Swift Testing suites, all existing independent Country 1 smoke tests, and the opt-in chained run; capture before/after logs in this PR.
- [ ] Run serial unit/UI tests (`-parallel-testing-enabled NO`), simulator Debug/Release builds and unchanged Codecov/CI gates. Draft PR CI may skip jobs; don't report green CI until it actually runs.
- [ ] Capture City 1 Deploy, City 3+ Deploy/Captain split, an empty-charge state and a structure-collapse state on compact phone and portrait iPad using existing DEBUG fixtures. Check label fit, Rally accessibility/hit area, Reduce Motion and restoration.
- [ ] Review the diff for duplicate balance formulas, extra save fields, generic architecture, accidental new art/SFX, and fake test budgets. Keep all commits and review resolutions on this **single PR**. Mark Ready only when acceptance is supported; update Linear HPA-582 to Done only after merge.

## Focused commands

```sh
# Existing and new focused suites
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test \
  -only-testing:PyxisTests/Country1SiegeSmokeTests \
  -only-testing:PyxisTests/BattleCombatStateTests \
  -only-testing:PyxisTests/KingdomGameStateTests \
  -only-testing:PyxisTests/BattleSceneTests

# Opt-in, potentially expensive chained 15-city run
TEST_RUNNER_COUNTRY1_SMOKE_CAMPAIGN=1 \
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test \
  -only-testing:PyxisTests/Country1SiegeSmokeTests

swiftlint lint

# Full verification (unit + UI)
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test
```

Use an installed simulator from `xcodebuild -showdestinations` if iPhone 17 is unavailable. No macOS test commands are claimed to have run during this docs-only planning step.

## Acceptance checklist

- [ ] True chained 15-city run exists behind an opt-in flag; baseline and post-tuning per-city evidence attached; all cities conquer within the agreed ~15-minute simulated bound.
- [ ] Role table unit tested; target-specific live + idle paths share it and preserve current trait/Guard/Keep semantics.
- [ ] Non-Keep fall FX occurs once on fresh destruction and never restore/resize; Keep conquest unchanged.
- [ ] Dead upgrade path is absent; Captain stats reflect the highest **current** camp building level.
- [ ] Manual deploy uses transient 3-charge / 1.5s recharge, keeps 10-live cap and shows the integer in existing Deploy control; auto/hero untouched.
- [ ] New tests added fail-first; lint, full tests, CI/coverage and visual checks documented; `CLAUDE.md` updated.
- [ ] No new art/SFX, new scenes, economic systems, migrations, second simulator, second PR, or new follow-up task for this implementation.