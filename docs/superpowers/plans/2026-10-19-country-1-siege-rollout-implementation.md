# HPA-477 — Country 1 Tactical Siege Rollout Implementation Plan
**Date:** 2026-10-19  
**Linear:** https://linear.app/cwchanap/issue/HPA-477/gameplay-roll-proven-tactical-siege-layouts-across-country-1  
**Design:** [2026-10-19-country-1-siege-rollout-design.md](../specs/2026-10-19-country-1-siege-rollout-design.md)  
**Baseline:** `main` `2e7046cbe20a37439636a0d8ee7dbe6c57f3d08a`  
**Delivery:** **one HPA-477 implementation PR.** This draft begins with design+plan only; add code, tests, tuning, screenshots, and final evidence to **the same PR**. Keep it Draft until implementation and acceptance are done.

## Minimal change map

| Existing owner | Intended change |
|---|---|
| `Pyxis/Country1CityCatalog.swift` | Explicit layouts and authored weights/routes for all 15; keep Cities 3/5 pinned; adjust Guard naming in place |
| `Pyxis/SiegeState.swift` | Narrow authored max-5/one-tower constraints; clarify shared Guard docs; no new state |
| `Pyxis/KingdomGameState.swift` | Mechanically rename Highcrest-only Guard helper references for valid multi-city Barracks use; no new save/idle algorithm |
| `Pyxis/BattleCombatState.swift`, `Pyxis/BattleScene.swift` | Change Guard naming/comments only initially; focused defect correction and scene proof if concrete issues arise |
| `Pyxis/CountryMapScoutCardContent.swift` | Highest-priority route-derived compact hints, capped at two and shortened if needed |
| `PyxisTests/Country1CityCatalogTests.swift` + `SiegeStateTests.swift` | Layout contracts, HP budgets, route/source meaning, preserved pilots |
| `PyxisTests/CountryMapScoutCardContentTests.swift` + `CountryMapScoutCardAcceptanceTests.swift` | Deterministic hint selection and compact/regular legibility |
| Existing `KingdomGameStateTests`, `BattleCombatStateTests`, `BattleSceneTests`, `ActiveSiegeLifecycleTests`, `KingdomGameStoreTests`, `DevJumpStateTests` and DEBUG fixtures | Barracks multi-city, automatic Captain, idle/relaunch/conquest and representative scene regressions, only where relevant |

Do **not** create new frameworks, production source files, asset files, CI workflows, or Xcode project registrations for this ticket.

## Checkpoints (each may be a commit; never a separate PR)

### 0. Baseline and repeatable smoke harness

- [ ] Freeze baseline SHA above and record the existing Falconridge City 3 and Highcrest City 5 reference loads/lanes. Use current simulation/test seams where possible; do not implement a standalone balance simulator or benchmark framework.
- [ ] Define one reproducible representative loadout per sampled city, using valid existing camp buildings, upgrade levels, fixed RNG seed, and a documented manual-spawn policy. Compare two routes at matched loadout, and include no-input/default-lane behavior.
- [ ] Record City 1/3/5/10/15 measurements in the PR body, including before/after for any pilot correction. Do not claim timings before running the actual simulator.

### 1. Fail-first authored contract tests

- [ ] In `Country1CityCatalogTests`, replace `nonPilotCitiesUseSingleKeepDefaultedToTheirStandardLane` with all-city assertions for authored layouts; preserve exact City 3/5 pilot fixtures and use concise per-city assertions (support kinds, ordered lane-route IDs, defensive source and default lane), not a second copy of every production definition.
- [ ] Add a positive catalog-wide contract for 1–5 objectives, one Keep, ≤1 Tower, ≤1 Barracks, ≤2 Gates, unique IDs, route/source references, lane reachability, support participation, and positive HP allocations at actual `cityMaxPower`.
- [ ] Confirm `CitySiegeLayout` still fails closed through initializer preconditions for unknown/repeated IDs, wrong order, invalid source, missing route, and now >5 structures / >1 Tower. Test the catalog's valid cases rather than introducing an error-returning duplicate validator.
- [ ] Run the focused tests to see the new expectations fail before authoring.

### 2. Author Country 1 in the existing catalog

- [ ] Author Cities 1–2 first, with gentle gate-versus-direct choices and unchanged economy. Keep City 1/2 Captain disabled.
- [ ] Keep City 3's 3:4:1 and City 5's 20:1 pilot layouts untouched by default. Author City 4 Gates, then Cities 6–9 combinations.
- [ ] Author Cities 10–14 stronger combinations and City 15 at most five structures. Use existing Gate lane-segment coverage, one actual tower fire source, and at most one Barracks.
- [ ] Derive default lane from the existing standard-lane metadata unless an encounter's tested behavior requires explicit override. Keep all three routes end-to-end and Keep conquest unchanged.
- [ ] Do a catalog-wide review for accidental direct exposed unopposed routes, off-route decorations, shared Gate visuals blocking safe lanes, stalling ranged soldiers outside defending fire, and structures with 0 HP after flooring.

### 3. Reuse Guard mechanics with a small, honest rename

- [ ] Rename `HighcrestGuardRules` / `freshHighcrest()` / `normalizedForHighcrest()` to a shared Country 1 Guard name in existing files and tests. Keep identical numerical values and the existing Barracks-presence guard; do not break City 5 behavior. Update stale Highcrest-only comments.
- [ ] Verify fresh/decoded/entered sieges seed finite Guard reserve iff the city's layout contains a Barracks; Barracks death stops future waves, not surviving Guards; lane switches affect only new waves. Verify both active and idle/Camp settlement.
- [ ] Reuse existing Guard transient actors and HPA-476 art. Do not make a per-city Guard tuning type unless measured late-city balance demonstrates a concrete need; if necessary, add the smallest authored scalar next to the layouts, without a difficulty engine.
- [ ] Verify automatic Captain from City 3 and one Rally remain intact without changing their progression.

### 4. Keep Scout useful without new UI

- [ ] In `CountryMapScoutCardContent.tacticalFooter`, derive only decision-relevant support text, ranked Barracks > Tower > Gate, at most two entries. Use actual route membership for L/C/R; never invent a lane. Resolve ties deterministically.
- [ ] Check all 15 text outputs against the existing measured single-line fit in compact/regular geometry. If two entries do not fit at 8pt, fall back to one accurate highest-priority entry; do not add a second line or screen. Preserve `Open: <exposed lane>` for Keep-only fallback tests if relevant.
- [ ] Assert every Scout remains attackable/returnable, regular and compact. Add tests for two Gate IDs and a five-structure footer.

### 5. Representative battle, idle, and visual smoke

- [ ] Pin representative layouts' selected-lane route, damage spillover, source-relative tower coverage, Barracks shutdown, Guard HP/reserve normalization, Captain/Rally, and Keep-only win authority.
- [ ] Exercise restored battle scenes, Map/Camp returns, idle catch-up and exactly-once rewards on a **non-Highcrest Barracks city**; no ghost waves or reward duplication.
- [ ] Run repeated deterministic smoke for Cities **1, 3, 5, 10, 15** at matched camps: report lane, duration, losses, Guard wave counts/reserve, shutdown and tactical consequence. Tune only authored weights/placements/coverage (and Guard interval/reserve only with evidence); keep pilot modifications justified.
- [ ] Capture at least three different siege layouts via existing DEBUG city jump and fixtures; add the smallest late-city fixture if current ones cannot stage state. Review compact supported phone and portrait iPad for Scout/HP/structures/tower tint/Guards/Captain/Rally, plus tabs/Settings/report. No generated images.

### 6. Ship-ready verification and closeout

- [ ] Focused tests, then full serial unit/UI suite (no parallel clones), `swiftlint lint`, Debug and Release simulator build; uphold unchanged **90% project + patch** Codecov gate.
- [ ] Check code changes are overwhelmingly catalog/tests. No new mechanics/economy/state/asset generation or speculative abstractions; no weakened assertions or CI exclusions.
- [ ] In the *same PR*, add final play numbers, before/after where tuned, screenshots or captured evidence paths, failures fixed, and explicit acceptance checklist.
- [ ] Update HPA-477 with implementation results and move to Done **only after merge**.

## Verification commands

```sh
# Use an available local simulator if iPhone 17 is absent.
swiftlint lint
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test \
  -only-testing:PyxisTests/Country1CityCatalogTests \
  -only-testing:PyxisTests/SiegeStateTests \
  -only-testing:PyxisTests/CountryMapScoutCardContentTests \
  -only-testing:PyxisTests/CountryMapScoutCardAcceptanceTests

xcodebuild -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test

xcodebuild -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO -configuration Release build
```

CI intentionally skips Build/Lint, Unit+Codecov, and UI jobs on draft PRs (`.github/workflows/ci.yml`); run local gates during implementation and mark Ready for Review to run final CI. Planning-only commit cannot claim build or gameplay acceptance.

## Stop conditions / scope discipline

Ship *good enough* variety, not perfect optimization. A stalled city, meaningless structure, broken guard resume, unreadable Scout, or universally free lane must be corrected here. No per-city art/SFX, new battle feature, second combat simulator, persistence migration, bespoke city scripts, or extra tickets/PRs.
