# HPA-477 — Country 1 Tactical Siege Rollout Design

**Date:** 2026-10-19  
**Linear:** https://linear.app/cwchanap/issue/HPA-477/gameplay-roll-proven-tactical-siege-layouts-across-country-1  
**Baseline:** `main` `2e7046cbe20a37439636a0d8ee7dbe6c57f3d08a` (HPA-476 / PR #46 merged)  
**Delivery:** one implementation PR (PR #47); this document and the paired plan are planning-only until implementation lands.

## Goal and boundaries

Turn all 15 Country 1 battles into distinct, legible sieges by authoring existing objective types directly in `Country1CityCatalog.definitions`. Keep the prepare → deploy → watch → conquer loop, existing HP budget/rewards/traits, three lane choices, Keep-only conquest, finite Guards, automatic Captain/Rally, scene routing, and idle settlement. Do not add encounter recipes, generators, a second simulator, generic scaling frameworks, per-city assets, or save migration.

Cities 3 Falconridge and 5 Highcrest are shipped pilot baselines. They remain unchanged unless matched fixed-seed gameplay evidence justifies a very small correction. All new layouts reuse HPA-476 structure, Guard, Captain, and Rally art.

## Verified baseline facts

- `CityDefinition.siegeLayout` currently falls back to `.singleKeep`. Only Cities 3 and 5 have custom routes; the other 13 are fallback layouts. Once all 15 are explicit, remove `CityDefinition.init`'s optional/default `siegeLayout` parameter so missing layout authoring is a compiler error. Keep `CitySiegeLayout.singleKeep` for isolated tests.
- `CitySiegeLayout.init` already fails closed for unique IDs, exactly one Keep, positive weights, all three nonempty routes terminating at the Keep, ordered progress, at most one Barracks, and valid defensive fire. Add only the missing production invariants below.
- `maxPowerAllocation(totalBudget:)` partitions the existing city HP envelope across objectives and returns rounding remainder to the Keep. The Keep's remaining HP, not the sum of structure HP, decides conquest.
- `DefensiveFire` has one **source objective** and a **binary set of covered lanes**, not per-lane weights; `LaneDefenseProfile` separately adjusts incoming tower damage for covered lanes. Defensive fire stops when its source is destroyed.
- Guards use the selected lane, spawn from Keep progress, descend only as far as Barracks progress and attack within `HighcrestGuardRules.attackRange = 0.28`. Ranged soldiers can stop at `objective.visualProgress − attackRange`, with archers reaching up to `0.264`; a badly ordered Gate/Tower below the Barracks can leave stalled attackers unreachable to Guards.
- Current Guard rules (2/30s, 12 reserve, HP 12, attack 3) were tuned specifically for Highcrest, whose 20:1 Keep/Barracks durability and ~26-second shutdown precede wave 1. Unlike player attack/HP and tower damage, those Guard stats are constant today. Those values are a **starting reference**, not proof of late-city balance.
- `CountryMapScoutCardContent.tacticalFooter` currently prints all supports. At 3–4 supports, the single-line iPad lane frame (~82pt) is more restrictive than a regular phone frame. Use the existing measured 8pt minimum and do not add a new UI.

## Authored layout proposal, corrected for combat geometry

Notation: `K` Keep, `G1/G2` Gates, `T` Arrow Tower, `B` Barracks; `L/C/R` are the **complete ordered routes**, implicitly ending in `K`. `Fire` gives the only source and all covered lanes. All Keep positions are `1.00`. Proposed support progress values are starting coordinates (to be confirmed by tests and screenshots), not shipped balance. No city exceeds five total structures, two Gates, one Tower, or one Barracks. Every support is on at least one route.

| City | L route | C route | R route | Source / fire coverage | Starting support progress / teaching goal |
|---|---|---|---|---|---|
| 1 Willowford | G1 → K | G1 → K | K | K / R | G1 .76; more HP without fire vs direct lane with fire; no Captain |
| 2 Pinewatch | G1 → K | K | G1 → K | K / C | G1 .76; gate detour vs exposed direct-fire choice; no Captain |
| 3 Falconridge | T → K | G1 → K | G1 → K | **T / L,C,R** | **UNCHANGED** T .68, G1 .58, Keep 3:4:1 |
| 4 Bramblegate | G1 → K | G1 → K | G2 → K | K / L,C,R | G1 .76, G2 .82; two chokepoint variants |
| 5 Highcrest | B → K | K | K | **K / L,C,R** | **UNCHANGED** B .72, Keep 20:1, Guard pilot |
| 6 Granite Pass | G1 → K | G1 → K | T → K | T / L,C,R | G1 .76, T .80; disable defensive fire vs Gate |
| 7 Emberford | B → K | G1 → K | K | K / L,R | B .72, G1 .80; Guard shutdown vs sheltered Gate/direct |
| 8 Greywall | T → K | G1 → K | G1 → K | T / L,C,R | T .80, G1 .77; tower shutdown vs Gate |
| 9 Runewatch | B → K | K | T → K | T / L,C,R | B .72, T .80; Guard shutdown vs Tower shutdown vs direct |
| 10 Ironthorn Gate | T → K | G1 → K | G2 → K | T / L,C,R | T .80, G1 .78, G2 .84; reinforced remix |
| 11 Kingshield Keep | T → K | G1 → K | B → K | T / L,C,R | T .80, G1 .82, B .72; all three defenses distinct |
| 12 Ashbridge | G1 → K | B → K | T → K | T / L,C,R | G1 .80, B .72, T .83; flame identity stays a trait |
| 13 Starveil Citadel | G1 → K | B → K | G2 → K | K / L,C,R | G1 .80, B .72, G2 .83; ward identity stays a trait |
| 14 Stonecrown | G1 → K | T → K | G2 → K | T / L,C,R | G1 .77, T .82, G2 .84; gate/tower remix |
| 15 Crownspire Keep | T → G1 → K | B → G1 → K | G2 → K | T / L,C,R | B .72, T .78, G1 .84, G2 .82; five familiar structures, no boss phase |

Each city's `LaneDefenseProfile`, defense trait, flavor, visual family, and reward remain unchanged. Explicitly choose default lane (usually current standard lane) and per-objective durability weights when implementing. Check that the automatic default lane can conquer and that alternate routes have comprehensible tradeoffs; the initial table does **not** establish numeric balance.

The City 3/5 table entries are descriptions of the current authored data, not instructions to rewrite the IDs or pilot layouts. All new stable objective IDs are city-prefixed (e.g. `runewatch.keep`, `runewatch.barracks`). Tower-source cities give the Tower's own route fire coverage. In Barracks cities, supports are placed no lower than Barracks progress so Guards can engage stalled attackers without adding Guard navigation.

### Structural invariants (existing `CitySiegeLayout.init` owner)

Extend only the existing preconditions: **1–5** objectives, ≤2 Gates, ≤1 Tower, ≤1 Barracks; any Tower must be the chosen `defensiveFire.sourceObjectiveID`; and every non-Keep objective must appear on at least one lane route. Retain all prior ID/order/Keep/source validation. These preconditions intentionally trap and **cannot be unit-tested as invalid cases in-process**; code review and valid-layout tests establish the contract. Do not add a second validator, thrown errors, or catchable validation API.

### Behavioral geometry invariants (one catalog-wide test)

All checks use each city's actual `CitySiegeLayout`, `BattleCombatState.Configuration.live(cityLevel:)`, and live soldier attack ranges—not a duplicated metadata model:

1. **Identical route, identical fire coverage:** if two lanes have the same ordered route ID array, their membership in `defensiveFire.coveredLanes` must match. Otherwise one gets equivalent obstacles with strictly less source fire.
2. **Tower self-cover:** every lane whose route contains the Tower must be among covered lanes. Killing an undefended Tower must not disable fire for the other lanes for free.
3. **Barracks shelter:** for every lane whose route contains Barracks, that lane must be covered by the actual `defensiveFire` source, and `barracks.progress − soldier.attackRange >= source.progress − towerAttackRange` for each soldier type (including archer). This generalizes Highcrest's existing Keep-specific test without assuming every source is the Keep.
4. **Guard reach:** if a city has Barracks, for each support objective `o` on any route and each soldier type, require `o.progress − soldier.attackRange + guardAttackRange >= barracks.progress`. This prevents Guards parking at their floor out of reach of soldiers attacking an earlier structure. Do not change the Guard movement code.
5. Positive allocated max HP for all objectives at that city's real HP budget; no structural support is absent from all three routes (the latter is already enforced by `init`).

Do not add a separate `LayoutValidator` type. These assertions are readable tests beside the existing catalog tests and real-pilot geometry tests, without baking test logic into production.

### Guard-scaling decision before rename or authoring

**Checkpoint 0 must decide whether the fixed 12 HP / 3 attack Guards remain meaningful at the City 15 representative camp's expected soldier upgrade level.** Capture the existing Highcrest baseline first; compare guard durability/attack against upgraded soldier damage/HP and, if feasible, a bounded live scenario. If Guards are one-hit decoration at the finale, implement the *smallest shared level-aware HP/attack formulas* alongside the existing Country 1 Guard constants, as part of the same Guard rename change. Keep City 5's **12 HP / 3 attack**, 2-per-30s finite 12 reserve and pilot behavior exactly unchanged.

If scaling is adopted, use the **same numbers** for transient Guard actors, new wave/idle synthesis, snapshot normalization, and scene-restored Guards; do not silently heal survivors or create a second wave engine. Re-evaluate the pilot's abstract idle Guard absorption ceiling (formerly 12 × 12 = 144 HP) at the applicable city, while keeping the existing 8-hour cap, one-conquest bound and approximate settlement semantics. No `GuardProfile`, per-city difficulty framework, configurable AI, or new saved fields.

The owner of `HighcrestGuardRules` and `GuardReinforcementProgress.freshHighcrest()/normalizedForHighcrest()` **definitions** is `Country1CityCatalog.swift`; other files contain call sites. Rename to `Country1GuardRules`, `freshCountry1()`, `normalizedForCountry1()` there, and update consumers. Retain the historical Highcrest tuning explanation as pilot rationale, not a late-city guarantee.

## Scout and visual contract

Preserve the route-derived Scout footer for 1–2 supports (especially the existing Falconridge exact output). For 3–4 supports choose **one** truthful high-priority entry in authored order, ranking Barracks > fire-source Tower > Gate; include actual L/C/R route membership. Use the existing single-line fitter with 8pt floor. If a two-support case fails the measured iPad constraint, shorten at the content-projection owner rather than parsing text in the view or adding fields. Extend `CountryMapScoutCardTextLayoutTests`' existing all-supported-fixtures tactical-footer test from City 3 to **all 15**.

Visual evidence **must** include City 15's five structures on a compact supported phone and portrait iPad; also City 7 or 13 with a Keep-source Barracks and clustered 0.72–1.0 supports. Confirm all objective HP/ruins, binary lane coverage, Guard/Captain/Rally, Scouts, tabs, Settings, and conquest report remain readable. Capture three meaningfully different layouts with the existing shared art and DEBUG fixtures only.

## Acceptance, risks and evidence

- All 15 city definitions use an explicit required `siegeLayout`, compiled with the `CitySiegeLayout.init` contracts and catalog-wide behavioral/geometry tests above.
- Preserve Falconridge's tower-versus-gate and Highcrest's Barracks shutdown pilots (including exact City 5 Guard stats). Keep max HP/one conquest reward/existing camp economy and idle behavior.
- **City 1 is a regression-risk seam:** current tests assume a fresh City 1 Keep has the whole city HP. Author City 1 first, run the **full unit suite**, and update those tests (not production fallback logic) to derive Keep maximum from the new `maxPowerAllocation`. Inspect `BattleHUDContentTests`, `LivingKingdomPresentationTests`, `SoldierRuntimeGeometryTests`, `ForgedVisualFixtureTests`, and other default-city fixtures.
- **Guard scaling is a balance-risk seam:** complete the pre-authoring City 15 upgrade comparison; pin any minimal level-aware formula to City 5=12/3 and cover active/idle/persistence consistently.
- Keep one **committed, bounded, deterministic Swift Testing smoke** using the existing `BattleScene.advanceCombatForTesting` seam (no separate simulator or framework). Cover every city's **default watch-only lane**, plus relevant alternatives in Cities **1, 3, 5, 9, 10, 15**. Report fixed loadout/seed, elapsed simulated time, troop losses, Guard waves/reserve, and Barracks shutdown; coarse no-stall guardrail with a documented maximum simulated-time budget. Specifically verify City 9 Barracks shutdown against wave 1. Avoid an arbitrary universal strict speed-ratio assertion across deliberately asymmetric routes.
- Exhaustive `15 cities × 3 lanes × repeated run-to-conquest` is **not required in every CI run** until a measured simulator runtime proves it affordable. Route coverage is exhaustively unit-tested; route comparisons and repeat runs remain release smoke. Do not build an unbounded SpriteKit-heavy CI suite without measuring its cost.
- Run full serial unit/UI tests, SwiftLint, Debug and Release simulator builds, and unchanged Codecov **90% project and patch** thresholds; include compiled smoke output and targeted screenshots in this same PR.

## Explicit non-goals

No new combat mechanics, extra defensive-fire sources, Guard classes, multi-Barracks, boss phases, hero progression, per-city art/SFX, save migrations, registry/framework/template/editor/procedural authoring, separate balance simulator, new currency/economy, or Country 2.
