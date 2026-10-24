# HPA-582 — Country 1 Battle Polish Implementation Plan

**Date:** 2026-10-23  
**Issue:** https://linear.app/cwchanap/issue/HPA-582/gameplay-polish-core-battle-mechanics-and-country-1-pacing  
**Design:** [2026-10-23-country-1-battle-polish-design.md](../specs/2026-10-23-country-1-battle-polish-design.md)  
**Base:** `main` at `7de4bf9fe73d9092a02adc2c954811cf36f710a6`  
**Delivery:** **one PR** for this entire ticket. This draft begins with design+plan; add all implementation, review fixes, tests and evidence on this branch before marking Ready. No separate foundation or follow-up implementation PR.

## Reuse / deletion survey

| Concern | Current production owner | Minimal proposed change |
|---|---|---|
| Chained balance evidence | `PyxisTests/Country1SiegeSmokeTests.swift`, `KingdomGameStore` | Extend existing DEBUG scene-driven harness with a chained campaign test and test-only greedy camp buyer; no production AI or second simulator. |
| Economy and Captain scaling | `KingdomGameState.swift` | Adjust *existing* balance constants only as measured; delete dead upgrade state; expose computed highest-building `captainLevel`. |
| Soldier role lookup | `SoldierType.swift` + `CitySiegeLayout.ObjectiveKind` | Add one pure multiplier function. Live simulator and idle settlement share it. |
| Live hits and manual charges | `BattleCombatState.swift` | Apply role multiplier at each structure hit; add two ephemeral charge fields and tick recharge. |
| Idle hits | `KingdomGameState.applyAbstractBuildingSpawnDamage`, `CitySiegeLayout.spendDamageBudget` / `firstLiveObjectiveID` | Preserve Guard-first handling; apply bonus for first live objective once per spawn, then reuse unchanged route-budget helper. |
| Scene orchestration and FX | `BattleScene.swift` | Gate successful manual deploys and project charges; detect collapse in existing `playObjectiveAttackFeedback` instead of snapshot comparisons. |
| HUD | `BattleHUDContent`, `BattleHUDNode` and current `BattleChromeLayout` | Add charges to existing Deploy and trait×role for current lane target to existing medallions, without a new panel. |
| Test fixtures | `DevJumpState.swift`, `PyxisTests`, DEBUG `BattleScene` seams | Stop faking upgrade level; use existing camp and scene fixtures; add narrow test probes only. |


## Task 0 — Choose a realistic buyer, then lock baseline

- [ ] **Policy first:** The player-facing `RecommendedCampRecommendation` is not a camp optimizer: it repeatedly upgrades a single favored type, may stop at an unaffordable action despite cheaper purchases, and has no unlocked favored type in City 6. **Do not tune to that one-building/no-building behavior.**
- [ ] Add a **small deterministic test-only greedy camp buyer**, parameterized in the existing `Country1SiegeSmoke` chained runner. Enumerate affordable legal builds/upgrades using existing unlocks, slot/per-type caps and cost functions. Prefer favorable *unlocked* types when affordable, otherwise any unlocked type; within each tier select cheapest (stable type/action/slot tie-break). Re-evaluate after each purchase. Support multiple buildings and stop only when nothing legal is affordable. No runtime AI.
- [ ] TDD for buyer: multiple buildings acquired, City 6 nonempty camp, unaffordable recommendation doesn't block a cheaper legal action, spent gold conserved, and deterministic tie-break.
- [ ] Add a chained `@Test` beside existing smoke suites, default opt-in with `COUNTRY1_SMOKE_CAMPAIGN=1` forwarded as `TEST_RUNNER_COUNTRY1_SMOKE_CAMPAIGN=1` (reuse current `.enabled(if:)` pattern). After measuring wall-clock, make the chained run always-on if reasonably comparable to existing default-route coverage; otherwise keep opt-in and add a mandatory balance-change run in `CLAUDE.md`.
- [ ] Split only the existing scene-runner seam into initial-state input and **actual final-state** output, keeping existing independent fixtures. Use an isolated `KingdomGameStore` per chain and a fresh scene per city. Buy through real `buildBuilding` / `upgradeBuilding` calls using fixed test dates (avoid ambient idle-credit time); transition with `acknowledgePendingBattleResult` and `startCityFromMap`. Optionally inject a recommendation-following *diagnostic* buyer; it must not be the default tuning target.
- [ ] Log one `COUNTRY1_SMOKE campaign=1` line per reached city with start/spent/end gold, camp, elapsed simulated time, losses, lane and outcome. Bound to 900 simulated seconds/city; preserve stall evidence, never fabricate conquest or duplicate rewards.
- [ ] **Before any balance changes**, capture pre-change output/first stall in PR and the chained test's **wall-clock run time** using an ordinary shell measurement (`time xcodebuild ...`). Record original main SHA, seed, cadence and buyer policy so later runs compare the same player.

**Evidence gate:** No tuning or role/charge refactoring before the baseline and policy are fixed. Keep independent authored multi-building smoke results as second evidence; never reduce their strictness to accommodate the new buyer.


## Task 1 — Soldier roles, idle reuse and truthful HUD (item 2)

- [ ] Add failing pure role-table tests for each 5×4 soldier/objective combination, trait×role product and explicit L1/L2 rounding examples. Add **one** `SoldierType.objectiveDamageMultiplier(against:)` helper. Preserve current trait-adjusted cached soldier power (also used for Guards), then apply and round the role multiplier per structure hit. **Two-step rounding is intentional**, preserving production Guard/combat fixture semantics; pin at least one case where it differs from single rounding before tuning.
- [ ] In `BattleCombatState.tick` the target ID already identifies the first surviving structure on each soldier's route. Apply the role bonus only at the structure-hit site, capped to target HP, without modifying cached `Soldier.attackPower`, Captain or Guard combat. Where model state is available, reuse the existing `CitySiegeLayout.firstLiveObjectiveID(for:maxPowers:damageByObjectiveID:)` rather than another first-target helper.
- [ ] In `KingdomGameState.applyAbstractBuildingSpawnDamage` retain Guards-first absorption. On the remaining single-spawn budget, apply role bonus for the **first live objective** on the chosen lane, then call unchanged `CitySiegeLayout.spendDamageBudget`. This is intentionally a bounded approximation at structure transitions, not a new idle per-objective walker or reverse-rounding system; neutral 1.0 calls existing helper and retains its behavior.
- [ ] Red/green tests: per-kind live damage/HP clamp, stacked trait/role rounding, first-target idle bonus, Gate→Keep / Tower→Keep / Barracks→Keep spill, Guard priority and neutral role preserving existing route-budget semantics.
- [ ] In `Pyxis/BattleHUDNode.swift`, update existing `BattleHUDContent.project`'s `Medallion.damageMultiplier` to trait×role for the selected lane's **current first surviving** structure. Update `BattleScene.presentLiveObjectiveDamageOutcome`'s existing damage-color selection to the same multiplier based on each event's objective. Keep the current view; fix misleading existing help copy only where needed (e.g. Falconridge Archer-vs-Tower), with HUD tests for lane switching and target destruction.
- [ ] Change `RecommendedCampRecommendation` copy/order only if a concrete contradiction exists; keep it as player advice, **not** the campaign buyer.


## Task 2 — Delete obsolete upgrade and derive Captain from camp (item 4)

- [ ] Write failing state/lifecycle tests: level 1 for no camp, highest building level across types, normalized Captain HP/attack on restore, and valid recovery from 0. **Protect damage taken on successful building purchases:** new City 3 Captain starts full; after Barracks L1→L3 remains full under the larger max; a Captain missing 5 HP remains missing 5. A down Captain stays down until recovery, which restores the then-current max. Repeated scene reconstruction never awards the increment again.
- [ ] Delete persisted `normalSoldierUpgradeLevel`, its coding/init/decode fields/accessors, `upgradeNormalSoldier`, the upgrade cost helper and unused `UpgradeResult`. Keep ordinary base soldier-attack formula; no migration or dual-format path.
- [ ] Add pure computed `KingdomGameState.captainLevel` = max level of all current-camp buildings (fallback 1), consumed by state normalizer/fresh city entry/recovery/HP sync, `BattleScene` Captain spawn/restore and `Pyxis/BattleHUDNode.swift`'s `BattleHUDContent.captainStatus` (currently trait-independent old level reference).
- [ ] In the two **existing successful** `KingdomGameState.buildBuilding` / `upgradeBuilding` mutation sites, record pre/post derived Captain max HP and increase a *living* Captain's remaining HP by the max delta (clamp to new max). Do not heal on read, decode or reconstruction, and don't add an upgrade-observer service.
- [ ] Remove fake `DevJumpState` soldier-level fixture; seed a real building when a stronger Captain is required by a DEBUG fixture. Update independent smoke/test fixture references and compile removed-symbol references to zero; run state, store, Captain, Rally and scene tests.


## Task 3 — Manual deploy recharge (item 5)

- [ ] First add `BattleCombatStateTests` for initial 3/3, successful spend only, zero-charge denial, +1 per 1.5 valid tick seconds, 0.1-second fractional accumulation, max 3, and new scene restarting full. Add scene tests for cap/type/paused modal not consuming, and auto/Captain spawns unaffected.
- [ ] Add only two transient combat fields (charge count and recharge accumulator); recharge in existing valid active `tick` after delta/Keep guard. Never persist or credit background/Settings/modal time; discard extra accumulation while full. Check charges in `BattleScene.spawnSoldier` after existing type/cap guards and before spawn+record, with current `invalidAction` feedback when empty.
- [ ] Project integer charge count to `BattleHUDContent` and existing `DEPLOY · N` label while retaining manual soldier count `N/10`; fit actual text on compact City 3+ Deploy/Captain/Rally layout without new UI. Refresh when integer changes, not on every fractional tick.
- [ ] Run independent Country 1 smokes. **An intermediate red suite is expected before Task 4** because the throughput limit changes against fixed camps. Keep those failures as tuning evidence; do not weaken assertions or hide failures by adjusting unrelated fixtures out of sequence.


## Task 4 — Rerun chain and tune only authorized constants (item 1 completion)

- [ ] Run **the same greedy purchasing policy fixed in Task 0** after roles, upgrade deletion and charges, and paste post-mechanics **pre-tuning** 15-city evidence to PR.
- [ ] Tune the smallest number of existing `KingdomGameState.cityMaxPower` / `goldReward` / building costs and spawn intervals. **Tower damage is explicitly excluded**: it is defined in combat configuration and altering it affects established tower pressure outside the ticket's allowable curve list. If permitted knobs cannot solve a wall, document it rather than silently widen scope.
- [ ] **Batch cohesive constant adjustments** and rerun the expensive full chain after each batch, not after every knob. Record policy, wall time, city-by-city actual budgets and elapsed times. Require 15/15 conquests, ≤900 simulated seconds/city, sensible ramp; continue running existing authored-camp default and representative alternate-route cases.
- [ ] Update exact curve-value tests in `KingdomGameStateTests.formulasMatchMVPBalanceCurve` and now-stale cost/budget arithmetic comments in `Country1SiegeSmokeTests.swift`. Delete/rename `soldierUpgrade=` output token and stale 'byte-identical' historical fixture claims once upgrade state is gone. Preserve gold conservation, camp reset, progression and exactly-once reward checks; do not lock arbitrary combat elapsed values.
- [ ] Put **balance constants and before/after evidence in their own commit on this same PR**, independent from the feature commits, to make tuning reviewable/revertible. Record the baseline vs final deltas and any unresolved limitations in PR description.


## Task 5 — Non-Keep structure-fall effect from existing loop (item 3)

- [ ] Failing scene tests: Gate/Tower/Barracks each requests exactly one fall event for fresh combat destruction (multiple same-tick hits coalesce); Keep stays conquest-only; restore/resize/idle/old ruin yields zero new events; ordinary and Captain attack paths both work.
- [ ] Extend `BattleScene.playObjectiveAttackFeedback` itself: existing loop aggregates fresh live hit events by objective and runs **after redraw** in both ordinary and Captain outcome flows. Add a third branch following Keep conquest: any non-Keep objective with grouped positive damage whose current remaining HP is 0 emits the fall. Otherwise keep existing hit response. This detects a fresh crossing by construction; **no before/after snapshots, second mutation path or persisted flag**.
- [ ] Reuse existing target geometry, `effectsLayer`, short shake, `playImpactFlash` and `playFloatingFeedback` label. DEBUG count/record requests before Reduce Motion guard, using existing Living Kingdom transition-test style. No new sound, haptic kind, image, gameplay mutation or structure node persistence.


## Task 6 — Final gates, docs and PR evidence

- [ ] Update `CLAUDE.md` for removed upgrade path, derived Captain level + preserve-damage-on-building-upgrade, two-step role rounding + idle first-objective approximation, and transient deploy charges. If the chain is kept opt-in based on Task 0 wall time, explicitly require its execution on any future balance constant change. `AGENTS.md` aliases it; edit only `CLAUDE.md`.
- [ ] SwiftLint, new focused Swift Testing suites, authored independent Country 1 smokes plus chained campaign before/after, Guard/Rally/idle/conquest regressions; serial full unit/UI tests, Debug/Release builds and unchanged CI/CodeCov gates. Draft PR CI may skip jobs; do not claim unexecuted tests.
- [ ] Compact phone and portrait iPad captures for City 1 Deploy, City 3+ Captain/Rally split, empty charges and support-structure fall. Check multiplier label after lane selection/target death and Reduce Motion requests.
- [ ] Diff review: no invented baseline, no extra damage walker, economic framework, save fields, duplicate formula, UI panel, art/SFX, migration or second PR. **One bounded commit per task where practical**, with tuning constants+evidence on their own commit in **PR #48**. Mark Ready only after evidence; move Linear HPA-582 to Done only after merge.

### Risks / review choices (2026-10-24)

- **Representative player is highest risk:** purchase buyer fixed before baseline, real carry-over budgets and authored multi-building smoke as sanity check; no tuning for a one-building recommendation bot.
- **Rounding and role UI:** choose/pin two-step attack integer rounding to preserve existing Guard damage and cached attack power. HUD describes trait×role for the first living lane target; green damage color agrees.
- **Idle approximation:** reuse the existing route-budget helper and accept one-spawn bonus spill at support death; no new walker/differential test.
- **Captain HP:** apply max-HP delta on successful building mutations only; preserve damage taken and no heal on restore.
- **Runtime:** compare baseline wall time to existing smoke before deciding always-on coverage; batch balance tuning.

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
- [ ] Role table tests and trait×role rounding pinned; live uses per-hit objective role, idle uses first-surviving-objective role with unchanged budget helper; medallion and color agree with selected target.
- [ ] Non-Keep fall FX occurs once on fresh destruction and never restore/resize; Keep conquest unchanged.
- [ ] Dead upgrade path absent; Captain stats follow highest **current** building level and preserve prior damage when buildings raise maximum HP.
- [ ] Manual deploy uses transient 3-charge / 1.5s recharge, keeps 10-live cap and shows the integer in existing Deploy control; auto/hero untouched.
- [ ] New tests added fail-first; lint, full tests, CI/coverage and visual checks documented; `CLAUDE.md` updated.
- [ ] No new art/SFX, new scenes, economic systems, migrations, second simulator, second PR, or new follow-up task for this implementation.