# HPA-811 — Effective Drill Yard and attack-gear gains: design specification

**Linear:** https://linear.app/cwchanap/issue/HPA-811/early-drill-yard-and-attack-gear-give-no-damage-gain  
**Baseline:** `cwchanap/Pyxis` `main@98c9d358028d04ec8809a9e3efa5799aa1297422` (UAT baseline, 2026-11-07).  
**Delivery:** **One HPA-811 PR**. This doc and the [implementation plan](../plans/2026-11-07-hpa-811-attack-upgrade-rounding-implementation.md) are its first commits; implementation, tests, balance evidence and review fixes belong on the **same PR**. Do not merge planning docs alone.

## Problem

At low integer attack power, buying Drill Yard (+5% per level) or equipping attack gear (+15% at Lv1, +22.5% at Lv2, +30% at Lv3) often adds **zero** damage after rounding. UAT observed a 16-gold Drill Yard upgrade showing `2 → 2 attack (no damage change yet)` and even leveled attack gear showing `(no gain yet)`. An honest warning still makes the purchase/reward unsatisfying.

The current first-round formula is `round(baseSoldierAttack × cityDefenseTrait × (1 + 0.05×DrillYard) × attackGearMultiplier × Renown)`, minimum 1. `KingdomGameState.traitAdjustedSoldierAttackPower(for:level:)` provides the state-aware projection for live spawns and Kingdom previews; the idle path instead uses the static percentage primitive with a cached multiplier. The test-only campaign equipment scorer reimplements the first round.

## Product decision and power tradeoff

**Each new Drill Yard rank and each newly equipped attack-gear rank must add at least +1 integer *first-round* ordinary-soldier attack**, even if the authored percentages round away. When the original rounded percentage produces a larger result, keep it. Do not simply add the ranks to every percentage result.

This is a **strong low-power buff**, not merely a first-purchase nudge. At a base attack of 1, one new Drill Yard level can double attack (+100% incremental gain); several ranks together can make the level-1 first-run maximum **six times** its existing rounded value. The floor can dominate into approximately soldier level 9. This is intentional *only provisionally*: the early numeric campaign gate below must be passed before UI implementation.

Examples with the current soldier curve `ceil(1.38^(level−1))`, a **neutral city trait and Renown 0** (these are calculated projections, **not measured campaign times**):

| Soldier level (base) | Drill Yard 4 + Attack gear Lv1: raw → effective | Drill Yard 4 + Attack gear Lv3: raw → effective |
| --- | --- | --- |
| 1 (1) | 1 → **6** (6×) | 2 → **8** |
| 2–3 (2) | 3 → **7** | 3 → **9** |
| 4 (3) | 4 → **8** | 5 → **10** |
| 5 (4) | 6 → **9** | 6 → **11** |
| 8 (10) | 14 → **16** | 16 → **18** |
| 10 (19) | **26 → 26** | **30 → 30** |

Lv3 equipment is earned on replay, but this table deliberately holds **Renown at 0** to isolate the rounding rule. An actual Renown 1+ replay will have different raw/effective values and must be measured separately. A high-base example (soldier Lv10, DY4, Lv3 attack gear, neutral, Renown 0) remains `raw == effective == 30`.

**Other consequence:** Attack gear will generally win more early loadout decisions. Specialist and Toughness gear can still round away their own effects and must keep their truthful `(no gain yet)` note; do not silently buff them. This is a product balance tradeoff, not a request for new systems.

## Exact bounded effective-attack rule

At one soldier level, city defense trait and Renown:

- `d` = Drill Yard rank 0…4, `g` = rank 0…3 of the **currently equipped attack item**, with `g = 0` if no attack item is equipped (including intentionally unequipped/Toughness/Specialist).
- `raw(d,g)` = the existing static, single-round integer attack using the hypothetical ranks: base attack × defense trait × Renown × `(1 + 0.05×d)` × `(1 + attackFractionAtLevel(g))`; at `g=0` the gear factor is 1. Use `EquipmentEffect.scaled(toLevel:)` to obtain each nonzero gear fraction. Preserve existing Swift `.rounded()` and the minimum 1.
- `effective(0,0) = raw(0,0)`.
- `effective(d,g) = max(raw(d,g), effective(d−1,g)+1 if d>0, effective(d,g−1)+1 if g>0)`.
- Return `effective(actual d, actual g)` from the state-aware attack method. Compute the tiny ≤5×4 table on demand; **no persisted modifier or separate attack state**.

The two predecessor constraints guarantee strict growth in **each** rank dimension even with the other upgrade present. Important comparisons at neutral Renown 0 and level-1 base power: `(d,g)=(0,0)→1`, `(1,0)→2`, `(0,1)→2`, `(0,2)→3`, `(0,3)→4`, `(1,1)→3`.

The shortcut `max(raw(d,g),raw(0,0)+d+g)` is **not equivalent**; it can violate strict monotonicity where one raw curve overtakes another. The alternate rule `raw(d,g)+d+g` *is* monotonic, but inflates already-effective high-base percentages by a permanent +d+g (e.g. adds 7 to a Lv10 raw attack of 30). The 2-D predecessor recurrence retains the old high-base values whenever raw percentage increases suffice.

## Code ownership, small scope

1. Keep `KingdomGameState` as the single combat-rule owner. Preserve the existing pure static `traitAdjustedSoldierAttackPower` as the **unchanged raw percentage primitive**. Add an **internal static, pure** `effectiveSoldierAttackPower` helper taking soldier type/level, defense trait, Drill Yard rank, the unscaled attack `EquipmentEffect?` and gear level, and Renown multiplier. The test matrix calls it directly, without building thousands of game states.
2. Add **one static first-round multiplier composer** for `(drillYard, attackFraction, renown)` to evaluate hypothetical cells. The existing `firstRoundAttackMultiplier(for:)` becomes a thin instance wrapper around it; the existing state-aware `traitAdjustedSoldierAttackPower(for:level:)` calls the static effective helper using existing Treasury/Equipment/Renown state. Do not duplicate the 5% constant or authored gear fractions.
3. **Live and idle parity:** `BattleScene` continues spawning ordinary soldiers using the state-aware method, caching stats once. In idle `applyAbstractBuildingSpawnDamage`, replace the static percentage call and cached `firstRound` factor with that same state-aware method; retain the specialist snapshot, Guard absorption, role/specialist second round, damage-spill rules and at-most-one-city conquest. Neither Guards nor Vanguard Captain use this projection; do not change them.
4. **Kingdom UI, only after passing the balance gate:** keep the Drill Yard's real current→next attack example; remove the now-dead below-max `(no damage change yet)` branch. Remove the now-unreachable Attack branch of `equippedEffectRoundsAway`. For Attack gear, show actual `atk X → Y` using a copied, unequipped state alongside the **nominal** `+N%` and gear rank in the existing compact Armory row and VoiceOver. Keep non-Attack no-gain disclosures. **Do not change `TreasuryUpgrade.drillYard.effectName`** (not rendered in the Drill Yard row); no new layout, tabs, art, sound, or strings platform.
5. **Test-only equipment scorer:** project candidates using a copied state and its real equip/unequip + effective attack method, then existing role/specialist second round. Score at `state.manualSoldierLevel(for: type) ?? 1` **after Treasury and Camp purchases**. Current `runGreedyCampaign` chooses gear before Camp, so merely replacing the hard-coded level 1 while keeping the old order would still evaluate level 1. Keep deterministic ties; it is not a runtime recommendation system. To isolate effects, compare against a scorer-corrected **no-new-floor** control as well as unchanged historical main.
6. No new persistence, schema/version layer, migration, general-purpose buff registry, combat engine, feature flag, art/SFX or HPA-812 UI polish. Implementation and adjustments stay on this PR.

## Test acceptance and mandatory early balance gate

- **Pure matrix:** soldier levels 1–19, all five soldier types, neutral/advantaged/disadvantaged traits, Renown multipliers 1/1.25/1.5/2, DY 0–4, attack gear rank 0–3. Assert every adjacent rank raises effective integer attack ≥1. Pin `Lv10 + DY4 + Lv3 == raw == 30` (neutral, Renown 0) and `DY0 + no attack gear == old raw` for all representative scenarios. Add a few real-state and live/idle integration cases instead of creating 7,200 full `KingdomGameState` fixtures.
- **Baseline controls before gameplay-rule changes:** on a macOS/Xcode runner, capture opt-in seed-582 campaign output from unchanged `main@98c9d35` for historical comparison; then, with *production combat math still unchanged*, apply only the test-only **post-Camp, real-level scorer** improvement and rerun it as the matched control. Record all actual `campaign=1`/`elapsed=`/`camp=` and `totalElapsed=` lines for fresh bought+gear and Renown 0/1 replay. Do not invent measurements or compare two different scorer policies as though only the floor changed.
- **Early stop criterion, BEFORE any Kingdom UI edits:** run the same chained campaign with the effective attack rule and corrected scorer. **Stop and seek a product decision** if any variant fails to conquer 15/15 or stalls, if **any City 1–5 of the fresh bought+gear variant completes in under 5.0 simulated seconds**, or if **any matched 15-city total is below 65% of its scorer-corrected control** (>35% faster). Renown 1 must remain faster than Renown 0; explicitly record zero-gold replay City 1/2. These numbers are **provisional game-feel guardrails**, not empirically validated ideal pacing.
- **Final checks:** after the early gate passes, validate the Kingdom projected integers and accessibility, existing cached-live-soldier behavior, unchanged conquest gold/HP/role/specialist semantics, serial Swift Testing/UI tests, Debug/Release build, SwiftLint, and repeat the required opt-in chained campaign at the final commit. Record empirical results in the same PR; do not tune unrelated balance constants or hide a failure.

**Planning status:** No gameplay implementation, Xcode simulator run or baseline timing measurement is claimed in this document.
