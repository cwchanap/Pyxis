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
- `RecommendedCampRecommendation.make(for:)` is a deterministic, authored next-action selector; it returns `ready`, `saveFor` or `noAction`. It is not an optimizer. Execute each `ready` action using the real `KingdomGameState.buildBuilding` / `upgradeBuilding` calls.
- `KingdomGameState.traitAdjustedSoldierAttackPower` currently builds the soldier's per-hit base power; `BattleCombatState.tick` then applies that cached power to the first live objective. Idle settlement calls `applyAbstractBuildingSpawnDamage` and `CitySiegeLayout.spendDamageBudget`, whose route budget can spill from one objective into the next.
- `normalSoldierUpgradeLevel` is persisted but `upgradeNormalSoldier()` has no production UI. The Captain uses this dormant level for HP/attack, while ordinary manual soldier level already comes from current-camp buildings.
- `BattleScene.syncSiegeObjectiveNodes` rebuilds structure nodes on changing HP. A structure-fall SKAction attached to a replaced structure node will vanish on redraw.

## Decision 1 — Real chained campaign baseline and limited tuning

Extend the existing smoke test file with **one opt-in sequential run** (`COUNTRY1_SMOKE_CAMPAIGN=1`, passed to xcodebuild as `TEST_RUNNER_COUNTRY1_SMOKE_CAMPAIGN=1`). Start at the game's production fresh state. For each city 1–15:

1. Confirm the city is active (for later cities use the real `acknowledgePendingBattleResult` and `startCityFromMap` progression path, not a fabricated city number).
2. Record gold on arrival; while `RecommendedCampRecommendation` yields `ready`, execute the stated build/upgrade with the existing state model. Stop on `saveFor` or `noAction`; don't invent alternative purchases or spend gold from previous cities twice.
3. Save the purchased state to an isolated `KingdomGameStore`; construct a fresh `BattleScene` with the existing fixed-size test seam, fixed RNG seed, deterministic manual spawn attempts and 0.1-second combat ticks. Run until conquest or a bounded 900 simulated seconds.
4. Carry the actual resulting `KingdomGameState` (after its exactly-once reward and camp reset) to the next city. Print a `COUNTRY1_SMOKE`-style line with city, camp, start/spent/end gold, elapsed, losses and outcome. On a stall, print evidence and fail clearly; don't synthesize a win.

**Baseline rule:** record the full pre-change run, including any stall, before altering balance. After role/upgrade/charge changes, rerun the same chain and adjust **only the existing** city HP, rewards, building costs or production intervals where evidence requires it. Success is 15/15 conquests, a comprehensible ramp and no city above about 900 simulated seconds. Preserve existing independent smoke coverage and its fixture intent.

## Decision 2 — Soldier roles, one pure lookup

Add a small pure `SoldierType` × `CitySiegeLayout.ObjectiveKind` multiplier helper, not a second attack stat or trait table:

| Soldier | Target | Role multiplier |
|---|---|---|
| Siege | Gate / Keep | 2.0 |
| Archer | Arrow Tower | 1.5 |
| Mage | Barracks | 1.5 |
| Infantry / Cavalry | Any objective | 1.0 |
| All other soldier/target combinations | Any objective | 1.0 |

Apply after the existing trait-adjusted integer base attack, round deterministically, clamp to positive damage, and cap to target's remaining HP. Live structure attacks read the target kind **at the tick's selected objective**. Captain stays an Infantry-typed special actor (1.0); Guard-vs-soldier fighting remains unchanged.

Idle settlement reads **the same helper**, but must account for mixed-objective routes: a buff earned against a Gate must not leak into the Keep, or vice versa. Keep the existing Guards-first absorption and route ordering. When a single abstract spawn has budget left after destroying a structure, consume the raw budget attributable to that structure (using deterministic integer/rounding rules) and recompute effective damage against the next objective kind. The all-1.0 route must reproduce the current spill behavior. Prefer a small local route walker in the existing settlement function over a new simulator or generic damage pipeline. Lock overkill and mixed-objective routing with tests.

Only update `RecommendedCampRecommendation`'s authored favorable order or an existing description if the observed roles make current text materially incorrect. No new UI.

## Decision 3 — Derive Captain power from existing camp buildings

Delete `normalSoldierUpgradeLevel` from stored state, coding keys, initialization and DEBUG/test fixtures, together with `upgradeNormalSoldier`, the dead upgrade-cost formula/accessor and unused upgrade-result surface if no real caller remains. **Keep** the base attack-power formula used by soldiers.

Compute a single `captainLevel` projection from the maximum level of **any** building in the current camp, or level 1 if empty. Use it consistently for Captain fresh entry, decode normalization, recovery, HP clamping, scene spawn/restore, attack power and HUD max HP. During a building upgrade the maximum increases; preserve the Captain's remaining HP while recomputing the ceiling/attack on scene reconstruction rather than granting a free heal. No retained synthetic level in `DevJumpState`; a DEBUG fixture that wants stronger troops must seed an actual building.

No compatibility migration or dual state paths for pre-release saves.

## Decision 4 — Transient manual deployment charges

`BattleCombatState` owns exactly two transient values: current manual charges (initial/max **3**) and fractional recharge progress. Replenish **one** charge every **1.5 seconds of valid active combat ticks**, capped at 3; don't advance during Settings/modal pause, idle/background settlement or a completed siege. New combat state starts full. No persistence or wall-clock catch-up.

`BattleScene.spawnSoldier` checks soldier availability and the existing 10-live-manual cap before spending a charge; zero charge emits existing `invalidAction` and does not deploy/record an event. Building-produced soldiers and Captain must never use charges. Maintain the existing manual type selector and one-tap Deploy action.

Show available charges on the existing Deploy label (for example `DEPLOY · 2`), retaining the existing `manualCount/manualCapacity` count. Feed `BattleHUDContent` from combat state and use the current text-fitting contract within `deployActionFrame`, including narrow City 3+ Captain/Rally layouts. Redraw only when the displayed integer charge count changes (or through the existing HUD refresh), not on every fractional tick.

## Decision 5 — One-shot non-Keep structure fall

Detect the *fresh, live* transition of any Gate, Tower or Barracks from positive HP to zero around the existing ordinary/Captain attack application flow. Use before/after objective snapshots and objective IDs to coalesce multiple hits in a tick; do not fire on `syncSiegeObjectiveNodes`, restore, layout or idle settlement. The Keep continues to use its existing conquest effect.

Render a short shake/dust-flash and one kind-specific floating label (e.g. `GATE DOWN`) via `effectsLayer` and existing `cityShakeAction`, `playImpactFlash` and `playFloatingFeedback` helpers. Anchor using existing objective geometry so the effect survives structural node rebuilds. Count requests through a DEBUG test seam before the Reduce Motion playback guard. Do not modify HP, persistence, rewards, routing or feedback taxonomy; only use an existing haptic if a matching semantic event already exists.

## Validation boundaries

Tests first for each item (Swift Testing). Lock role table/live/idle equivalence; Captain level across empty/leveled camps, normalize, retreat/restore; charge depletion/recharge/cap/scene restoration; exactly-once fresh destruction versus restore; real chained campaign, budget conservation and city progression. Re-run existing per-city smoke, catalog, Guard, Rally, trait, UI fit, lifecycle and conquest-report tests.

Preserve the Keep-only conquest authority, one reward/report, 8-hour idle cap, 1/10 idle building production, no-buildings/no-progress rule, and current manual cap. Full serial tests, SwiftLint, unchanged CI/coverage gates, and compact-phone/iPad Deploy/Captain visual evidence precede Ready for Review. Generated art and any future collapse SFX belong in a **separate art/SFX task**, not this PR.