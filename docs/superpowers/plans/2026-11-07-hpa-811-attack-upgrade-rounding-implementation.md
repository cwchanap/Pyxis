# HPA-811 — Attack-upgrade rounding: single-PR implementation plan (review pass 2)

**Ticket:** https://linear.app/cwchanap/issue/HPA-811/early-drill-yard-and-attack-gear-give-no-damage-gain  
**Design:** [effective attack rule](../specs/2026-11-07-hpa-811-attack-upgrade-rounding-design.md)  
**Baseline:** `cwchanap/Pyxis` `main@98c9d358028d04ec8809a9e3efa5799aa1297422`.  
**Delivery:** **Draft PR #54 is the only HPA-811 implementation PR**. Commit code, tests, measured campaign evidence and review fixes to this branch. Do not merge this docs-only draft or open another implementation PR.

## Reuse and ownership

| Existing code | Implementation action |
| --- | --- |
| `Pyxis/KingdomGameState.swift` static `traitAdjustedSoldierAttackPower` (~1930) | **Leave unchanged** as the raw one-round percentage primitive and static test oracle. |
| `KingdomGameState` instance `traitAdjustedSoldierAttackPower(for:level:)` (~1950) | **Extend** as the one effective integer attack path used by live combat, idle damage and Kingdom previews. |
| `firstRoundAttackMultiplier(for:)` (~1269), `EquipmentEffect.scaled(toLevel:)` | Add one pure static multiplier composer and a tiny pure recurrence. Scaling belongs to `scaled(toLevel:)` **only for gear rank ≥1**; rank 0 has no gear bonus. |
| `applyAbstractBuildingSpawnDamage` (~1429–1446) | Replace cached raw `firstRound` factor + static call with state-aware attack. Retain specialist snapshot; delete unused `defenseTrait` local. |
| `PyxisTests/Country1SiegeSmokeTests.swift` | Correct the test-only candidate scorer and post-Camp selection order, then reconcile **four always-on tests** before running the model gate. No runtime recommendation system. |
| `KingdomScene.armoryRowText` and `drillYardExampleText` | **After balance gate only:** keep current real projections **and** the Drill Yard no-gain `changeNote` + narrow-row replacement (reachable for later ranks under the revised rule); remove only the unreachable attack-gear no-gain case; append realized attack delta in row text; VoiceOver already consumes `line2`. |
| `TreasuryEffectSeamTests`, `EquipmentEffectTests`, `KingdomSceneTests` | Keep pure static raw-rounding expectations; update **instance** attack assertions and existing UI cases where the new floor intentionally changes values. |
| `CLAUDE.md` | Update live/idle attack-authority description when implementation lands. |

No new persisted fields, buff registry, migration, scene, Xcode project-file edits, art, SFX or unrelated HPA-812 UI polish.

## Checkpoint 0 — Capture matched empirical baselines before modifying production combat

1. On an available macOS/Xcode simulator, run the opt-in seed-582 chained `Country1SiegeSmokeTests` from **unmodified main**; record the historical fresh bought+gear campaign and Renown 0/1 replay totals, plus per-city `camp=`, `elapsed=`, `loadout=` and stalls.
2. On **this same PR**, change **only the test-only campaign policy** (`PyxisTests/Country1SiegeSmokeTests.swift`) while production attack math remains exactly as main:
   - Move `applyGreedyEquipmentPolicy` to **after** Treasury and greedy Camp purchases but before the siege. The current policy selects gear at city entry, so merely replacing hardcoded level 1 with the soldier-level getter before buying Camp still scores at level 1.
   - Score each candidate at `state.manualSoldierLevel(for: type) ?? 1`, using a copied `KingdomGameState` and its real `equip/unequip`, state-aware first-round attack and existing second-round role/specialist method. Preserve deterministic candidate ordering, strict-positive improvement, and Toughness/None fallback. Do not reimplement the raw or forthcoming minimum formula in the test helper.
   - Update comments describing the prior before-Camp, fixed-level-1 policy.
3. Rerun the exact same seed/variants with **this scorer-corrected but no-floor** harness and capture full per-city and total traces. This is the **matched no-floor control** for the rest of the task. Keep unchanged-main measurements separately, for historical context only; do not attribute scorer/order differences to the attack floor.

**Stop condition:** Baselines must be actually measured before gameplay changes; if the runner is unavailable, record *not measured* and do not declare the gate passed.

## Checkpoint 1 — Write focused red model/scorer tests before implementing the rule

**Files:** `PyxisTests/TreasuryEffectSeamTests.swift`, `PyxisTests/EquipmentEffectTests.swift`, `PyxisTests/Country1SiegeSmokeTests.swift`. **Leave KingdomSceneTests unchanged until Checkpoint 4** (after the balance gate).

1. Add a pure static matrix test (a temporary raw-only stub is acceptable until red): all soldier types, levels 1–19, three trait factors, Renown 1/1.25/1.5/2, Drill Yard 0–4, attack gear rank 0–3. The **first** bought rank of each dimension (DY1 vs 0, gear Lv1 vs 0) must increase the effective attack by ≥1 over its zero-rank predecessor; later ranks must be **nondecreasing** (≥, not strict) and may round away. Do not instantiate thousands of full game states.
2. **Explicit rank-0 regression:** pass a **non-nil `.attackBonus(0.15)` with `ownedGearLevel = 0`** and assert the no-gear baseline, not +15%. Repeat for negative gear level; assert +15% applies only for rank ≥1. Test non-attack/nil effects, gear rank >3 and negative/directly assigned out-of-range Drill Yard (e.g. 10) are bounded: clamp target DY to `0...TreasuryUpgrade.drillYard.maxLevel`.
3. Pin neutral Renown 0, soldier Lv1: no upgrade 1, DY1 2, DY4 2, Attack gear Lv1/Lv2/Lv3 = 2/2/2, DY1+Lv1=3, DY4+Lv3=3. Pin **high-power identity**: soldier Lv10, neutral Renown0, DY4+Lv3 attack item has `raw == effective == 30`. Keep all existing **static** single-round tests unchanged: they are valid raw expectations.
4. Update/extend existing **model-instance** tests that pin old zero-gain behavior (not new duplicate suites):
   - `TreasuryEffectSeamTests.drillYardInstanceWrapper` (~240): Lv2 neutral DY4 changes from old raw 2 to effective **3**, while static raw stays **2**.
   - `TreasuryEffectSeamTests.zeroEquipmentMatchesPreEquipmentFormula` (~410): retain static raw pins; DY0/no attack gear remains raw, DY1 can exceed it by +1 while DY2–4 stay nondecreasing (no-gear bound `effective <= raw + 1`). Its direct mutable DY loop runs 0…10, so replace the old instance==raw assertion with explicit capped effective semantics beyond DY4 (DY10 behaves like DY4).
   - `EquipmentEffectTests.instanceAttackSeamFoldsEquippedAttackGearIntoTheSingleRound` (~69): Lv5 DY2 neutral, **unequipped effective 5**, Attack Lv1 **effective 6**; raw static checks remain **4/5**. Add specific no-gear/other-gear instance wiring.
   - Extend existing `liveSpawnAttackMatchesIdleSeam` (~289) and `deployedSoldiersKeepCachedAttackAfterDrillYardPurchase` (~332) with a formerly rounded-away low-base example. Keep role/Guard/Captain, toughness and specialist invariants.
5. Reconcile the **four always-on** `Country1SiegeSmokeTests` greedy-policy tests (~1509, ~1524, ~1546, ~1568) whose old expected choices relied on Attack gear rounding away:
   - **Toughness fallback:** use owned `c06-infantry-gate` + `c03-infantry-toughness` at City 1's first **Gate**, neutral level-1 infantry; Specialist Lv1 rounds `1×1.4` back to 1, so choose Toughness. Add a companion assertion that actual Attack `c01-infantry-attack` Lv1 now beats None.
   - **Specialist beats Attack:** use a **City 1 Barracks Lv5** seeded into the test fixture (the Barracks unlocks at City 1) and replay-style preowned `c01-infantry-attack`, `c03-infantry-toughness`, `c06-infantry-gate`. First Gate target: Attack Lv1 scores 5, Gate Specialist Lv1 scores 6, so Specialist wins. Do **not** seed Siege Workshop Lv5 at City 5 as suggested in review: that Workshop is locked until City 11, and the fixture would bypass an authored unlock.
   - **Level scaling:** substitute `c06-infantry-gate` for Attack in the old level test, at City 1 Gate, Renown0 and level-1 infantry: Lv1 Specialist ties None (1), Lv2 Specialist becomes 2, proving the scorer still uses `scaled(toLevel:)`.
   - **Renown:** use that same Lv1 Gate Specialist with no camp at Renown0 versus Ascension2 (Renown 1.5). At Renown0 it ties None (1); at Renown1.5 it scores 3 against None's 2. Do not expect Lv3 Attack to round away anymore.
   Keep the no-owned-item test unchanged, update test comments, and preserve the production equipment catalog as-is.

**Checkpoint:** matrix is red under old math; all intended model/scorer assertions are specified. Existing Kingdom view tests are **intentionally deferred** to the post-balance UI step, not silently overlooked.

## Checkpoint 2 — Add the small pure recurrence and unify live/idle attack

**Production file:** `Pyxis/KingdomGameState.swift` only. No new state owner or framework.

1. Add an **internal static** effective attack function accepting soldier type/level, defense trait, `drillYardLevel`, unscaled `EquipmentEffect?`, `ownedGearLevel` and Renown multiplier. **Normalize inputs before building the table:**
   - `targetD = min(max(0, drillYardLevel), TreasuryUpgrade.drillYard.maxLevel)`.
   - `targetG = min(3, ownedGearLevel)` **only if** the effect is `.attackBonus` and `ownedGearLevel > 0`; otherwise `targetG = 0`. This must work even if the helper receives a non-nil Attack effect with zero gear level.
2. Evaluate the bounded `0...targetD × 0...targetG` recurrence. For each cell with **`g == 0`, set `attackFraction = 0` directly**, even if unscaled Attack effect is provided. **Only call `EquipmentEffect.scaled(toLevel: g)` for `g >= 1`**, because that helper clamps 0 to 1 and would otherwise grant a phantom Lv1 bonus. Compose each cell's multiplier through one static `firstRoundAttackMultiplier(drillYard:attackFraction:renown:)` and the **unchanged static** `traitAdjustedSoldierAttackPower`; take the max of raw and the predecessor cells, adding +1 **only on the first-rank edges** (`d==1` / `g==1`) and propagating the predecessor value unchanged elsewhere so later ranks are nondecreasing. Return the effective current cell.
3. Make `firstRoundAttackMultiplier(for:)` a thin wrapper around the same static composer, with the same normalized DY rank. Make the instance `traitAdjustedSoldierAttackPower(for:level:)` read existing city trait, Treasury, owned/equipped item and gear level, and Renown; delegate to the static effective projection.
4. For idle `applyAbstractBuildingSpawnDamage`, replace the cached `firstRound` + static raw call with the **same state-aware instance effective attack** used by `BattleScene`. Remove now-unused `firstRound` from the idle loadout tuple **and** the now-unused local `let defenseTrait = currentCityDefenseTrait`. Retain specialist snapshot, Guard absorption, second-round role/specialist, damage spill and one-city conquest cap. Existing live soldiers still cache attack at spawn.
5. Do **not** change Treasury/gear percentages, prices, renown, soldier levels, equipment drops, persistence, city HP, Guard/Captain attacks, or battle routing.

**Checkpoint:** Run the **focused model and scorer test suites** (including the four always-on policy tests); retain the static raw pins. Do not require the old `KingdomSceneTests` results to pass until the dedicated post-gate UI update.

## Checkpoint 3 — MANDATORY early 15-city go/no-go, **before any Kingdom UI work**

Use the existing `TEST_RUNNER_COUNTRY1_SMOKE_CAMPAIGN=1` seed-582 rail, not a new simulator.

1. Rerun the corrected-scorer **fresh bought+gear** and **Renown 0/1 replay** campaigns with the floor. Capture every `COUNTRY1_SMOKE campaign=1` line (`city=`, `camp=`, `elapsed=`, `treasury=`, `loadout=`, gold and stall result) plus totals, and separately record zero-gold replay City 1/2.
2. Compare each run only against the **same-scorer no-floor** control from Checkpoint 0. Keep untouched main historical output separate to identify test-policy drift.
3. **Stop for a product decision on this PR** if any variant stalls or fails 15/15, any City 1–5 of fresh bought+gear finishes in **<5.0 simulated seconds**, any 15-city total is **<65%** of its matched control (more than 35% faster), or Renown 1 is not faster than Renown 0.
4. These thresholds are **provisional player-feel guardrails**, not empirically proven ideal progression. If they fail, record measurements and revise the decision/rule *before* altering the UI; do not hide the result or silently retune unrelated balance constants.

**Checkpoint:** This PR contains real per-city and total numbers with an explicit pass/fail decision before UI work.

**Measured outcome (recorded):** the every-rank rule at `5730d9a` **failed** this gate — boughtGear fresh/Renown 0/Renown 1 totals 950.2/861.9/771.4 vs controls 1648.0/1496.5/1069.8 (57.7%/57.6%/72.1%, plus bought 55.8% and freeSeeded 60.5%). The user chose to revise the rule; the first-rank-only rule at `a201b67` **passed every criterion** — 1261.8/1204.9/1023.4 (76.6%/80.5%/95.7%; baseline 100% inert, freeSeeded 87.4%, bought 79.8%), all six variants 15/15 with zero stalls, fresh City 1–5 7/7/6/9/15 s, Renown 1 < Renown 0. Verbatim traces and provenance live under `evidence/hpa-811/` (historical context, matched control, rejected and accepted runs); the spec's *Measured gate evidence* table summarizes them.

## Checkpoint 4 — Minimal Kingdom readouts and all UI test updates

**Files:** `Pyxis/KingdomScene.swift` and `PyxisTests/KingdomSceneTests.swift`; leave `TreasuryUpgrade.swift` and `KingdomScene.equipmentEffectText(for:level:)` unchanged.

1. Keep the Drill Yard's existing state-derived current→next values **and** the `changeNote` / `(no damage change yet)` branch (around `KingdomScene.swift:1179`) plus the compact-width fallback `.replacingOccurrences(of: " (no damage change yet)", with: " (no gain)")` (~963) — under the revised first-rank-only rule these branches stay reachable (later Drill Yard ranks can still round away), so the disclosure remains necessary and truthful. Keep the other existing abbreviations.
2. In `equippedEffectRoundsAway` (~1251), remove the now-impossible attack equality comparison; retain true Specialist/Toughness rounded-away disclosures.
3. Leave the two-argument pure nominal `equipmentEffectText(for:level:)` formatter exactly as before (`"Attack Lv N · +P%"`). **Only in `KingdomScene.armoryRowText(for:state:)`**, use an unequipped copy and the same instance attack projection to append exactly `" (atk \(bareAttack) → \(equippedAttack))"` for `.attackBonus`. No new generic prose. VoiceOver already reads `armoryRowText.line2`, so it automatically announces the actual delta without another formatter. Retain next-drop text and row cycling.
4. Update **all** old Kingdom assertions here, including `KingdomSceneTests.swift` around **73** (no-gain at Lv1), **87** (current→next DY levels), **834** (max-level Drill Yard must use **instance** effective projection rather than static raw), **1077** (Armory Attack row), **1268** (attack no-gain expectation), **1342** (DY+gear), **1361** (DY+Renown). Preserve `equipmentEffectTextUsesMaxOneDecimalPercent` pure formatter tests and honest non-Attack notes.
5. Run existing compact phone/iPad label fit, VoiceOver and the 264pt row boundary tests; **measure rather than assume** that adding `(atk X → Y)` fits alongside `Drops at City…`. If necessary shorten the added presentation within the same existing row; do not redesign Kingdom layout or solve HPA-812 issues.

**Checkpoint:** Armory nominal percentages, actual integer attack, accessibility and live/idle combat all agree. UI suite passes.

## Checkpoint 5 — Documentation and final verification on this same PR

1. Update `CLAUDE.md`: after HPA-811 the static formula is the raw primitive; the **instance effective attack** is the live+idle authority, and the static multiplier composer only builds raw hypothetical cells. No cached raw `firstRound` factor in idle. Document that the bounded first-rank floor decides low-base results while later ranks can round away.
2. Run SwiftLint, Debug and Release builds, **serial** `PyxisTests` and `PyxisUITests` (`-parallel-testing-enabled NO`), plus the mandatory opt-in chained Country 1 suite again at the final diff. Record commands, macOS/Xcode/simulator environment, pass/fail, all per-city timings/stalls, replay City 1/2 and final totals; do not invent unrun results.
3. Resolve review findings and adjust tests only for intentional gameplay behavior. Do not bypass the numeric balance gate or create another PR.

**Measured outcome (recorded):** at PR HEAD `eb1dde8` (source code unchanged from last code commit `a66ba5c`; subsequent commits are docs-only), serial on Xcode 27.2 / iPhone 17 (iOS 26.5): `swiftlint lint --quiet` exit 0 with warnings — one new `function_parameter_count` for the 7-parameter static effective-attack helper plus pre-existing warnings; Debug build **succeeded** (16.3 s), Release build **succeeded** (49.7 s); `PyxisTests` 1663 passed, 6 intentional opt-in skips, 0 failures (158.7 s wall); `PyxisUITests` — iPhone 17: 0 failures with 2 logical-size skips, iPhone 16: seven XCTest cases, 0 skipped, 0 failures. Final opt-in seed-582 campaign: 35 passed, 1 opt-in alternate-lane skip, 0 failures, 210.1 s wall; all 96 records identical to the accepted `a201b67` run — `compare-campaigns.py` vs the matched no-floor control reports **BALANCE GATE: PASS**. Verbatim trace: `evidence/hpa-811/final-campaign.txt`.

Reference commands (replace simulator destination with an installed device):

    swiftlint lint
    xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build
    xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Release build
    xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests
    xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisUITests
    TEST_RUNNER_COUNTRY1_SMOKE_CAMPAIGN=1 xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests/Country1SiegeSmokeTests

## Single-PR checklist

- [x] Historical main and scorer-corrected no-floor campaign traces recorded (`evidence/hpa-811/`).
- [x] Pure static recurrence red→green, with rank-zero non-nil effect, rank clamps and high-base raw identity pinned (first-rank-only rule, `a201b67`/`ddde598`).
- [x] Existing model-instance and four always-on scorer tests reconciled, live/idle parity and cached soldiers proven.
- [x] Mandatory pre-UI 15-city balance go/no-go documented using matched scorer baselines — every-rank rule FAILed, user-directed first-rank rule PASSed (Checkpoint 3 outcome above).
- [x] Minimal Kingdom labels and **all** affected UI assertions updated after the balance gate (`eb53392`/`a66ba5c`).
- [x] `CLAUDE.md` updated; raw campaign evidence posted under `evidence/hpa-811/`.
- [x] Final builds/lint/serial test suites and the final-commit campaign repeat — all run at `eb1dde8`; see the Checkpoint 5 measured outcome and `evidence/hpa-811/final-campaign.txt`.
- [x] Review fixes committed to **this PR**; keep Draft until tested.

**Status:** Checkpoints 0–5 are implemented, reviewed and measured (see the Checkpoint 3 and Checkpoint 5 outcomes and the spec's *Measured gate evidence*). Final verification at `eb1dde8` is complete and green — warnings and intentional skips are itemized in the Checkpoint 5 measured outcome; nothing is pending on this PR except final review/push.
