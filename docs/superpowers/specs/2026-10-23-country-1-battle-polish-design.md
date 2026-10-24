# HPA-582 — Country 1 Battle Polish Design

**Date:** 2026-10-23  
**Linear:** https://linear.app/cwchanap/issue/HPA-582/gameplay-polish-core-battle-mechanics-and-country-1-pacing  
**Baseline:** `main` at `7de4bf9fe73d9092a02adc2c954811cf36f710a6` (HPA-477 merged)  
**Delivery:** one implementation PR, starting as a draft with this design and its paired plan. Implementation, tuning, tests and evidence land on this same PR.

## Goal and constraints

Make the existing Country 1 siege loop smoother and each deploy decision more legible without adding another progression/economy layer. The authorized five items are: a true 15-city chained balance run; per-objective soldier roles; a non-Keep structure-fall effect; deletion of the unused soldier upgrade; and recharging manual deployment charges.

Keep `KingdomGameState` as campaign/persistence/economy owner, `BattleCombatState` as the one live simulator and transient charge owner, `BattleScene` as the existing orchestration and FX owner, and `BattleHUDContent`/`BattleHUDNode`/`BattleChromeLayout` as the existing deploy presentation. No generic buff system, balancing service, ability tree, new HUD surface, art or SFX. No save migration (development saves may reset).

## Existing code contracts confirmed

- `PyxisTests/Country1SiegeSmokeTests.swift` runs separate city fixtures with authored camps and fixed soldier-upgrade level, using `BattleScene.advanceCombatForTesting` at 10 Hz and manual spawn attempts once per second. An optional heavy-route flag already exists. It **does not** conserve spent gold across cities.
- `RecommendedCampRecommendation.make(for:)` is a deterministic, authored next-action selector; it returns `ready`, `saveFor` or `noAction`. It is not an optimizer. Treat this as an optional UI-advice diagnostic, **not** the balance-run purchasing policy: the recommendation upgrades one favored building repeatedly, may stop at an unaffordable upgrade even when cheaper actions exist, and can return `noAction` where favored types have not unlocked (e.g. City 6). A chained baseline built from this advice would be unrepresentative.
- `KingdomGameState.traitAdjustedSoldierAttackPower` currently builds the soldier's per-hit base power; `BattleCombatState.tick` then applies that cached power to the first live objective. Idle settlement calls `applyAbstractBuildingSpawnDamage` and `CitySiegeLayout.spendDamageBudget`, whose route budget can spill from one objective into the next.
- `normalSoldierUpgradeLevel` is persisted but `upgradeNormalSoldier()` has no production UI. The Captain uses this dormant level for HP/attack, while ordinary manual soldier level already comes from current-camp buildings.
- `BattleScene.syncSiegeObjectiveNodes` rebuilds structure nodes on changing HP. A structure-fall SKAction attached to a replaced structure node will vanish on redraw.

## Decision 1 — Real chained campaign baseline and limited tuning

**Choose the purchase policy before measuring the baseline.** The existing `RecommendedCampRecommendation` is not a strategy for filling a camp: after one build it prioritizes upgrading the same type, even if cheaper buildings are available; City 6 has no unlocked favored type. Balancing around repeated recommendations would turn a player guidance limitation into artificially easy global tuning.

Extend `PyxisTests/Country1SiegeSmokeTests.swift` with one sequential 15-city run using the actual store/scene/test seams. Keep the camp-purchase policy **test-only and deterministic**, injected as a simple parameter into the chain runner (no runtime economy AI):

- Default **greedy camp** policy: enumerate legal build/upgrade candidates using existing unlocked types, per-type/slot caps and existing cost formulas. Prefer affordable actions for favored **unlocked** types, then other unlocked types; within the chosen tier, take the cheapest legal candidate (stable tie-break by type order, action and slot). Recompute candidates after each purchase. The policy can build *multiple* structures of a type; it does not stop at the first unaffordable recommendation. Stop only when no valid action is affordable.
- Optionally run a **recommendation-following** policy as a diagnostic for advice/soft-lock problems, not as the tuning target. Never hide its City 6 behavior or force global balance curves to suit its one-building strategy.

Start from the game's production fresh state. For each city 1–15:

1. Confirm active city (for later cities, real `acknowledgePendingBattleResult` + `startCityFromMap`, not a fabricated level).
2. Record arrival gold; purchase buildings/upgrades under the selected test policy using the actual `KingdomGameState.buildBuilding`/`upgradeBuilding` mutations. Record paid gold and camp; stop when no affordable legal action remains.
3. Persist into a single isolated `KingdomGameStore`, create a fresh `BattleScene` per city, and run with fixed seed, manual spawn cadence, 0.1-second combat ticks and a 900-simulated-second bound.
4. Carry real state and reward into the next city. Print per-city `COUNTRY1_SMOKE` lines (arrival/spent/end gold, camp, elapsed, losses, outcome). Never fabricate a conquest or double-count rewards.

**Baseline gate:** capture the full pre-change output (or first actual stall) **and the chained run's wall-clock time** before changing constants. After soldier roles, upgrade deletion and charges, rerun the same player policy, then batch only a few evidence-backed existing-number changes per expensive full run. A pass is 15/15 conquests, smooth pacing, none above ~900 simulated seconds, and no regression in the independent authored-camp/route smoke suites. Keep the opt-in gate until runtime is measured; if the 15-city chain is comparable in wall time to the existing always-on smoke, enable it by default. Otherwise document the balance-change obligation in `CLAUDE.md`.

**Allowed tuning knobs:** `KingdomGameState.goldReward`, `cityMaxPower`, building build/upgrade costs and building spawn intervals (the existing ticket list). **Tower damage** is *not* a tuning knob for this ticket: changing it alters the defensive pressure underlying authored route comparisons and is outside this bounded scope. If these permitted knobs cannot fix a measured wall, record the limitation for reconsideration rather than broadening mechanics silently.

## Decision 2 — Soldier roles, one pure lookup

Add a small pure `SoldierType` × `CitySiegeLayout.ObjectiveKind` multiplier helper, not a second attack stat or trait table:

| Soldier | Target | Role multiplier |
|---|---|---|
| Siege | Gate / Keep | 2.0 |
| Archer | Arrow Tower | 1.5 |
| Mage | Barracks | 1.5 |
| Infantry / Cavalry | Any objective | 1.0 |
| All other soldier/target combinations | Any objective | 1.0 |

**Rounding choice:** preserve the existing trait-adjusted integer attack power used by deployed soldiers and Guards; apply the role multiplier to that value at a structure hit, round deterministically again, clamp positive and cap to remaining HP. This is **two-step rounding**, intentionally retaining the current Guard/combat fixture contract instead of refactoring cached soldier damage just to change the rounding point. Pin representative L1/L2 trait×role results in tests before tuning, including a case where a single rounding would differ. Captain uses its existing Infantry-type attack (role ×1), and Guard combat stays unchanged.

Live structure damage reads the kind of the *first still-living target along the soldier's route* at hit time. For the HUD and idle settlement, reuse `CitySiegeLayout.firstLiveObjectiveID(for:maxPowers:damageByObjectiveID:)` where its input model is already available; do not add another first-target helper or objective registry.

**Idle approximation:** retain `CitySiegeLayout.spendDamageBudget` unchanged. After same-lane Guard absorption, multiply the remaining one-spawn damage budget once using the role of the **first surviving objective** on the selected lane, then pass that integer to `spendDamageBudget`. Existing spill behavior remains intact (the applied bonus can spill beyond the initially targeted support), which is a deliberate bounded approximation consistent with live attacks dropping per-hit overkill. Test a multi-objective spill and a neutral-role exact match to the existing `spendDamageBudget` result. No per-objective idle walker, reverse-rounding budget accounting or differential testing against a new walker.

**UI correctness, no new UI:** `BattleHUDContent.Medallion.damageMultiplier` should show the product of the current `CityDefenseTrait` multiplier and the role multiplier for the *currently selected lane's first living objective*. The existing green damage-feedback condition must use that same per-event trait×role product rather than trait-only. Adjust misleading existing trait/help wording where necessary; a colored ×0.8 label while actual target damage benefits from role ×1.5 is unacceptable. HUD multipliers describe pre-rounding effectiveness; actual integer hits follow the explicit two-step rule above.

Only adjust `RecommendedCampRecommendation`'s authored text/order if the new role information is demonstrably misleading; it remains player-facing *advice*, not the campaign-balance buyer.

## Decision 3 — Derive Captain power from existing camp buildings

Delete `normalSoldierUpgradeLevel` from stored state, coding keys, initialization and DEBUG/test fixtures, together with `upgradeNormalSoldier`, the dead upgrade-cost formula/accessor and unused upgrade-result surface if no real caller remains. **Keep** the base attack-power formula used by soldiers.

Compute a single `captainLevel` projection from the maximum level of **any** building in the current camp, or level 1 if empty. Use it consistently for Captain fresh entry, decode normalization, recovery, HP clamping, scene spawn/restore, attack power and HUD max HP. **Preserve damage taken rather than absolute remaining HP when the maximum increases.** A fresh City 3+ Captain begins at full level-1 HP before any camp exists. On successful `buildBuilding`/`upgradeBuilding` mutations that raise `captainLevel`, add `newMaxHP − oldMaxHP` to a *living* Captain's remaining HP (clamped to the new max). Thus a previously full Captain stays full, while a Captain missing 5 HP stays missing 5 HP. Do not heal on read/restore or re-normalization; a down/recovering Captain stays down and recovers to the new max through the existing recovery flow. Recompute ceiling/attack for scene reconstruction from the current camp, without storing a synthetic level. No retained synthetic level in `DevJumpState`; a DEBUG fixture that wants stronger troops must seed an actual building.

No compatibility migration or dual state paths for pre-release saves.

## Decision 4 — Transient manual deployment charges

`BattleCombatState` owns exactly two transient values: current manual charges (initial/max **3**) and fractional recharge progress. Replenish **one** charge every **1.5 seconds of valid active combat ticks**, capped at 3; don't advance during Settings/modal pause, idle/background settlement or a completed siege. New combat state starts full. No persistence or wall-clock catch-up.

`BattleScene.spawnSoldier` checks soldier availability and the existing 10-live-manual cap before spending a charge; zero charge emits existing `invalidAction` and does not deploy/record an event. Building-produced soldiers and Captain must never use charges. Maintain the existing manual type selector and one-tap Deploy action.

Show available charges on the existing Deploy label (for example `DEPLOY · 2`), retaining the existing `manualCount/manualCapacity` count. Feed `BattleHUDContent` from combat state and use the current text-fitting contract within `deployActionFrame`, including narrow City 3+ Captain/Rally layouts. Redraw only when the displayed integer charge count changes (or through the existing HUD refresh), not on every fractional tick.

## Decision 5 — One-shot non-Keep structure fall

Reuse `BattleScene.playObjectiveAttackFeedback`: it already groups **fresh live** ordinary/Captain hit events by objective ID and runs after `redraw`, when each support has already become its intact/ruined node. In the existing Keep-conquest vs ordinary-hit conditional, add a third branch for a non-Keep objective with fresh grouped hit damage and `state.currentSiegeSnapshot.objectiveRemainingPower[id] == 0`. An objective attacked in this tick was alive at attack time, so this is the one-shot destruction transition. No before/after HP snapshots or extra persistence flags.

Play a restrained dust/impact burst, short shake and kind-specific label using existing `effectsLayer`, `playImpactFlash`, `playFloatingFeedback` and `cityShakeAction` helpers; anchor at `objectiveFeedbackTarget` geometry so rebuilt structure nodes cannot remove the effect. Keep-only conquest follows the original branch. Count requested effects in a DEBUG seam before Reduce Motion suppresses playback. Restore, resize, idle and plain redraw never execute this combat-only feedback loop. No new feedback event category, asset or SFX.

## Validation boundaries

Tests first for each item (Swift Testing). Lock role table/live/idle equivalence; Captain level across empty/leveled camps, normalize, retreat/restore; charge depletion/recharge/cap/scene restoration; exactly-once fresh destruction versus restore; real chained campaign, budget conservation and city progression. Re-run existing per-city smoke, catalog, Guard, Rally, trait, UI fit, lifecycle and conquest-report tests.

Preserve the Keep-only conquest authority, one reward/report, 8-hour idle cap, 1/10 idle building production, no-buildings/no-progress rule, and current manual cap. Full serial tests, SwiftLint, unchanged CI/coverage gates, and compact-phone/iPad Deploy/Captain visual evidence precede Ready for Review. Generated art and any future collapse SFX belong in a **separate art/SFX task**, not this PR.
## Risks and review decisions

1. **Primary: tuning to a nonrepresentative purchase policy.** Greedy policy must assemble affordable multi-building camps, use actual spend and compare against authored smoke camps; the recommendation-only bot is not the balance target. Document the policy before baseline and do not switch halfway through tuning.
2. **Expensive full campaign:** measure wall-clock at baseline; batch constant changes per rerun and make always-on vs opt-in an evidence-based decision.
3. **HUD multiplier and two-stage rounding:** medallion and damage color describe the same current target/trait/role relationship; effective integer hits may round differently at L1/L2, so lock explicit examples. Preserve Guard hit semantics.
4. **Captain level across new camps:** building purchases adjust a living Captain's HP by the increase in maximum without erasing damage already sustained; restoration never grants that delta a second time.
5. **Idle abstraction:** the target-kind bonus is applied to a spawn budget once and may spill into the next objective. This is intentional and test-scoped; no chronological idle simulation or per-objective damage walker.
