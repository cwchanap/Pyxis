# HPA-477 — Country 1 Tactical Siege Rollout Design
**Date:** 2026-10-19  
**Linear:** https://linear.app/cwchanap/issue/HPA-477/gameplay-roll-proven-tactical-siege-layouts-across-country-1  
**Repository baseline:** `main` at `2e7046cbe20a37439636a0d8ee7dbe6c57f3d08a` (HPA-476 / PR #46 merged)  
**Delivery:** one implementation PR, with this design and its paired plan committed first. This draft is planning-only, not a completed rollout.

## Goal and decision

Make all 15 Country 1 sieges distinct and understandable through **authored layouts and restrained tuning**, using only shipped Keep, Gate, Arrow Tower, Barracks/Guard, three assault lanes, defense traits, Vanguard Captain, and Rally. Preserve the prepare → deploy → watch → conquer loop and the existing economy, idle catch-up, map, settings, and report routing.

**Decision:** author layouts explicitly in `Country1CityCatalog.swift` rather than inventing encounter recipes, builders, generators, registries, or services. City 3 Falconridge and City 5 Highcrest are the reference pilots and should be unchanged unless representative reproducible play evidence proves a small correction necessary.

## What exists on main

- `CityDefinition.siegeLayout` defaults to a `CitySiegeLayout.singleKeep` layout. Only Cities **3** and **5** explicitly author nontrivial layouts today; other 13 cities still use the fallback.
- `CitySiegeLayout` in `Pyxis/SiegeState.swift` preconditions one Keep, unique nonempty objective IDs, at most one Barracks, positive weights, three total ordered routes ending at Keep, nondecreasing progress, and a valid defensive-fire source. It currently **does not** enforce the ticket's five-structure limit.
- `CitySiegeLayout.maxPowerAllocation(totalBudget:)` divides the existing budget, flooring shares and giving remainder to Keep. Keep remaining HP is the sole conquest authority. Every lane's route is an ordered list of shared stable IDs.
- Combat has **one defensive-fire source** per layout and one set of covered lanes. Repeated towers would be visually present but not all mechanically meaningful, so author **at most one Arrow Tower per city** in this rollout.
- Gate art renders one segment per blocked lane; tower, gate and barracks art is already integrated. HPA-476 / PR #46 supplies shared `siege-*`, Guard, Captain, and Rally assets; no new art is needed or owned here.
- Guards already spawn for any layout containing a Barracks, but their rules and persistence normalizers are named `HighcrestGuardRules` / `freshHighcrest()` / `normalizedForHighcrest()`. The mechanics can be reused; do not introduce a second wave engine.
- `CountryMapScoutCardContent.tacticalFooter(for:)` currently joins **every** support objective into one line. Its measured compact-card fitter has an 8pt fail-closed floor, so a five-structure layout risks making the Scout card unavailable.

## Authored campaign: starting encounter map

This table is a **testable authoring proposal**, not approved numeric balance. Keep existing city names, flavor, `CityDefenseTrait`, `LaneDefenseProfile`, visual families, and rewards. In the descriptions below, `K` is Keep, `G` Gate, `T` Arrow Tower, and `B` Barracks. The letters L/C/R denote routes, not new gameplay classes.

| City | Proposal (including Keep) | Tactical question |
|---|---|---|
| 1 Willowford | K + G; G spans L/C, R direct; Keep fires primarily on direct R | Gate-free but exposed approach versus covered blocker route; no Captain yet |
| 2 Pinewatch | K + G; G spans L/R, C direct; Keep covers C and L | A different default/safe-route choice, still gentle; no Captain |
| 3 Falconridge | **Unchanged** K + T + G, tower-first L vs gate-first C/R | Preserve proven pilot and fixed-seed benchmark |
| 4 Bramblegate | K + two G, one L/C and one R; different weights/positions | Chokepoint and shared-Gate readability without a new structure |
| 5 Highcrest | **Unchanged** K + B, L shuts down Guards vs R direct | Preserve proven finite-Guard pilot and shutdown tradeoff |
| 6 Granite Pass | K + G + T; G L/C, T R; T covers C/R | Tower suppression versus route blocker under stone-wall trait |
| 7 Emberford | K + G + B; B L, G C, R direct | A modest finite-Guard choice alongside an ordinary Gate |
| 8 Greywall | K + T + G; T L, G C/R; T covers L/R | Tower-first option with asymmetric defensive fire |
| 9 Runewatch | K + B + T; B L, T R, C direct; T covers L/C | Shut down waves, eliminate tower, or race direct |
| 10 Ironthorn Gate | K + two G + T; T L, G C and R; T covers C/R | Stronger gate lanes vs source-tower shutdown |
| 11 Kingshield Keep | K + G + T + B; T L, G C, B R; T covers L/C | Three distinct familiar answers, no new reinforced-Keep system |
| 12 Ashbridge | K + G + B + T; G L, B C, T R; T covers L/R | Barracks timing matters without extra Guard types |
| 13 Starveil Citadel | K + two G + B; G L/R, B C; Keep covers L/C | Barracks pressure versus layered blockers; ward stays a trait |
| 14 Stonecrown | K + two G + T; G L/R, T C; T covers L/R | Final gate/tower remix |
| 15 Crownspire Keep | K + two G + T + B (**five**); T L, shared G C/L, B and second G R, T fires C/R | Finale combines known decisions; no boss phase |

The proposal deliberately uses a small family of authored situations instead of fifteen bespoke scripts. Explicit routes/coverage/weights/positions must be filled in per city, using unique city-prefixed objective IDs (for example, `willowford.keep`, `willowford.west-gate`). If a structure would be unreachable, irrelevant, visually overlapping, or create one universally superior free route, change **its authored placement/coverage/weight**, not combat semantics.

Use progress values strictly ordered along the route where multiple blockers occur. Keep at `1.0`; Guards spawn at Keep and use the Barracks progress as their movement floor. On Barracks cities, pay special attention to whether a ranged unit stalled at Barracks is under the intended source's tower/Keep fire. Do not require perfect lane parity; require a meaningful tradeoff.

## Constraints and ownership

1. `Country1CityCatalog.definitions` is the **sole** authoring source. Keep the existing 15-city order and labels. No `CityDefinition` schema expansion unless measured play evidence proves a field is genuinely needed.
2. Enforce **1–5 total objectives**, exactly one Keep, and **at most one Barracks** in `CitySiegeLayout`. The existing fail-closed rules enforce all routes ending at Keep and valid references. Add a narrowly scoped at-most-one Tower contract because the shipped simulator permits only one fire source; do not change simulator fire rules to accommodate extra towers.
3. Every authored objective must be meaningful: a Gate or Barracks must occur on at least one route; the Arrow Tower must both source defensive fire and be reachable through some route. Keep at most two Gates per city. Add positive tests on the compiled catalog, not a new runtime validator or swallowed precondition error.
4. The sum of objective maximum HP is always `KingdomGameState.cityMaxPower(for:)`; no full-HP stacking, multiphase boss, increased rewards, or new currency. Initial weight ratios should be modest and adjusted by fixed-seed smoke, preserving Falconridge 3:4:1 and Highcrest 20:1 as baselines.
5. Reuse current `HighcrestGuardRules` values (2 per wave, 30s, 12 reserve, existing combat stats) for any additional Barracks city **initially**. For naming clarity, mechanically rename the constant group and `freshHighcrest`/`normalizedForHighcrest` helpers to Country 1 shared Guard terminology in existing files/tests. Do **not** add a GuardProfile or per-city difficulty layer without evidence from smoke. Existing Guard state/recovery, once-per-siege Rally, and approximate idle/active semantics are unchanged.
6. Captain availability starts at City 3 and remains automatic. Neither lane selection nor manual Rally can be mandatory for forward progress. Keep the existing `CityDefenseTrait` effects; ward/oil/wall language is **not** a request for shields, DOT, walls, or status systems.
7. No save migration. This is development-only content; remapped IDs may invalidate old development saves, which is acceptable. Avoid compatibility scaffolding.

## Scout contract and visual readability

Reuse `CountryMapScoutCardContent` and its **existing single-line measured lane-footer**. The current all-supports concatenation is unsuitable for three/four support objectives. For layouts with **one or two** supports, preserve the route-derived summary (especially Falconridge's exact pilot footer); for layouts with **three or four**, show **only the highest-priority truthful entry**, ordered Barracks shutdown > Arrow Tower source > Gate, ties stable by authored order. This intentionally previews a tactical decision rather than listing every structure. If even a two-support summary fails the existing compact 8pt fit test, simplify its authored summary policy to one entry before shipping; **do not** introduce dynamic view-side parsing, another Scout field, or a new text-layout system. Validate every city in regular and compact Scout geometry, especially City 15.

Keep Keep HP/objective HP, intact/ruined structures, source coverage, lane flag, Barracks status, Guard actors, Captain portrait, Rally, tabs, Settings and conquest report legible. `BattleScene` remains the only consumer of objective art. Use the existing DEBUG city jump and visual fixtures; make the smallest fixture extension for representative late-city screenshots if necessary.

## Acceptance and evidence

- Unit/catalog: 15 ordered city definitions; unique nonempty stable IDs per layout; all supported objective kinds; 1–5 structures, ≤1 Barracks, ≤1 Tower, ≤2 Gates; reachable Keep on all three routes, monotonic progress, positive allocated HP for each authored objective at its actual city budget; relevant source/coverage and meaningful route membership.
- Preserve exact Falconridge and Highcrest pilot layout/Guard regression tests; replace the outdated test asserting all other cities are `singleKeep`. Pin the chosen design for all other 13 with focused table-driven assertions rather than a second full duplicated catalog model.
- Representative deterministic gameplay smoke on **Cities 1, 3, 5, 10, 15**: same-seed repeat at least twice for baseline loadout and differing route, record camp setup, lane, duration, allied losses, Guard waves/remaining reserve, Barracks shutdown (if applicable), and whether the tactical difference is visible. Compare **watch-only/default-lane** as well as at least one optional manual lane/Rally choice. Avoid a universally free route or indefinite Guard/tower stall; do not chase globally optimal balance.
- Real compact-phone + portrait-iPad smoke for Scout fit, structure/HP bounds and overlap, coverage, guard cues, Rally, tabs/Settings/report. Capture at least three visibly distinct siege layouts across campaign progression using installed shared art.
- Run targeted Swift Testing and scene tests, full unit + UI suite, `swiftlint lint`, simulator Debug and Release builds, and existing Codecov project/patch **90%** thresholds. Disable parallel simulator testing.
- Record measured tuning deviations against the starting authoring table in **this same PR**.

## Explicit non-goals

A new combat engine, procedural generator, encounter-template framework, pathfinder, editor, new enemy or hero, multiple Barracks, additional Arrow Tower simulation, special boss/finale logic, hero progression, new art/animation/SFX generation, save migration, cross-tab runtime redesign, economy or offline-rule rewrite, and Country 2.
