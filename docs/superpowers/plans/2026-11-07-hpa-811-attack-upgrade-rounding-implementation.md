# HPA-811 — Attack upgrade rounding: reviewed single-PR implementation plan

**Ticket:** https://linear.app/cwchanap/issue/HPA-811/early-drill-yard-and-attack-gear-give-no-damage-gain  
**Companion design:** [effective attack design](../specs/2026-11-07-hpa-811-attack-upgrade-rounding-design.md)  
**Baseline:** `cwchanap/Pyxis` `main@98c9d358028d04ec8809a9e3efa5799aa1297422`.  
**Delivery:** Draft PR #54 is the **one** HPA-811 implementation PR. All code, tests, balance measurements, doc updates, and review fixes go on this branch; do **not** merge planning docs or create a follow-up implementation PR.

## Current code survey

| Existing owner | Action |
| --- | --- |
| `Pyxis/KingdomGameState.swift`, static `traitAdjustedSoldierAttackPower` (around 1930) | **Reuse unchanged** as the raw single-round percentage primitive. |
| `KingdomGameState` instance `traitAdjustedSoldierAttackPower(for:level:)` (around 1950) | **Extend** into the one effective-attack runtime seam. Existing live spawn, Kingdom preview and Armory already use this call. |
| `KingdomGameState.firstRoundAttackMultiplier(for:)` (around 1269) | **Refactor narrowly** to call a static multiplier composer; do not copy the 5% constant in recurrence math. |
| `EquipmentEffect.scaled(toLevel:)` | **Reuse** for hypothetical attack-gear level 1/2/3; keep authorship at +15%, +22.5%, +30%. |
| `KingdomGameState.applyAbstractBuildingSpawnDamage` (around 1430–1446) | Replace cached `firstRound` + static attack call with the same instance effective seam as live combat. Retain cached specialist snapshot, Guard and role behavior. |
| `PyxisTests/TreasuryEffectSeamTests.swift` | **Extend** existing `liveSpawnAttackMatchesIdleSeam` and `deployedSoldiersKeepCachedAttackAfterDrillYardPurchase` tests rather than writing duplicates. Leave static raw-rounding pins intact. |
| `PyxisTests/Country1SiegeSmokeTests.swift` | Move test-only gear-choice policy after Camp purchases and score at actual soldier level through a copied state. The current policy runs before Camp, so changing the hardcoded `level: 1` alone would have no practical effect. |
| `KingdomScene.swift`, `TreasuryUpgrade.swift` | **Minimal UI changes only after balance passes**. Keep Drill Yard's existing state-derived example; delete two unreachable no-change branches; show real gear attack deltas in existing Armory row/VoiceOver. **Do not edit** unused `TreasuryUpgrade.drillYard.effectName`. |
| `CLAUDE.md` | At implementation finish, update the description of the effective first-round authority and idle path. |

There is no need for a new engine, cache, modifier registry, persistence field, migration, scene, asset, SFX, package or Xcode project-file edit.

## Checkpoint 0 — Empirical baseline **before production combat changes**

**Files:** test harness only, `PyxisTests/Country1SiegeSmokeTests.swift`. This checkpoint intentionally precedes the main code rule and UI work.

1. Run the existing opt-in `TEST_RUNNER_COUNTRY1_SMOKE_CAMPAIGN=1` suite on **unmodified** `main@98c9d35` and save each `COUNTRY1_SMOKE campaign=1 city=… camp=… elapsed=…` line plus `totalElapsed=…` for the fresh bought+gear campaign and matched Renown 0/1 replays. This is the **historical** control.
2. On PR #54, with all **production combat math still unchanged**, correct the **test-only** loadout scorer **once**:
   - In `runGreedyCampaign`, keep entering the real city and buying Treasury and Camp through existing real mutations, but move gear selection to **after** those purchases and before the siege.
   - Evaluate candidates at `state.manualSoldierLevel(for: type) ?? 1`, *now reflecting the bought camp*.
   - Replace the copied percentage formula in `greedyCandidateDamage` with a copy of the current `KingdomGameState`, a real candidate `equip/unequip` mutation, its state-aware `traitAdjustedSoldierAttackPower(for:level:)` and existing `SoldierType.roleAdjustedDamage`/specialist projection. Preserve the existing deterministic tie/None/Toughness choice policy and no-runtime-AI boundary.
   - The corrected scorer now automatically picks up the new floor when Step 2 changes the state-aware seam; **do not rewrite it again** or introduce a second formula.
3. Rerun seed 582 with this **scorer-corrected, no-new-floor** test-only change. Record the same fresh bought+gear and Renown 0/1 replay outputs, including all 15 city durations, equipment decisions, camp, gold and total durations. **This is the matched control** for the Step 3 go/no-go test. Keep the historical main output for transparency, but never attribute a difference in loadout policy to the attack-floor rule.

**Checkpoint:** Both sets of real baseline numbers are in the PR before gameplay code changes. If no macOS/Xcode simulator is available, mark the control as **not measured**, not passed; do not skip the gate or invent values.

## Checkpoint 1 — Red tests before the new rule

**Files:** `PyxisTests/TreasuryEffectSeamTests.swift`, `EquipmentEffectTests.swift` and `KingdomSceneTests.swift` as needed.

1. Add one **pure static** parameterized attack matrix (after introducing an initially raw-only function stub, if needed to compile): levels 1–19, all five soldier types, defense-trait factors neutral/advantaged/disadvantaged, Renown 1/1.25/1.5/2, DY 0–4 and attack gear ranks 0–3. Test every adjacent DY/gear increment is ≥1. Do not construct 7,200 whole game states; the core recurrence is an internal static function, testable via `@testable import Pyxis`.
2. Pin exact low-power results for neutral Renown 0: baseline 1, DY1 2, gear Lv1/Lv2/Lv3 2/3/4, DY1 + gear Lv1 3. **Pin high-power identity: soldier Lv10, DY4, Lv3 attack item, raw 30, effective 30**; this rejects unconditional rank addition.
3. Preserve static raw-rounding tests (they describe intended raw math). Add a few instance-level wiring cases (unequipped, attack, toughness, specialist) and assert DY0 + attack-gear None is bit-identical to current main including Renown.
4. Extend existing `liveSpawnAttackMatchesIdleSeam` with one formerly rounded-away low-power case and `deployedSoldiersKeepCachedAttackAfterDrillYardPurchase` with a floor-triggering case. Verify second-round specialist/role and HP calculations remain unchanged.
5. Update only old Kingdom UI assertions that deliberately pin the bug: `Drill Yard 1→1` and an Attack item marked `(no gain yet)` must fail under the intended new rule. Keep existing max-level/other-gear cases.

**Checkpoint:** tests reproduce the bug without disguising it by weakening old raw formula tests.

## Checkpoint 2 — One pure static recurrence and shared runtime seam

**Production file:** `Pyxis/KingdomGameState.swift`. No new general abstractions.

1. Add an **internal static** `effectiveSoldierAttackPower` taking `(SoldierType, level, CityDefenseTrait, drillYardLevel, unscaledAttackEffect: EquipmentEffect?, ownedGearLevel, renownMultiplier)`. If effect isn't `.attackBonus`, treat gear rank as 0.
2. For each hypothetical `(d,g)` up to the actual ranks, call the **existing static** single-round attack primitive on base/trait and a multiplier composed from **one static** `firstRoundAttackMultiplier(drillYard:attackFraction:renown:)`. Obtain each gear fraction via `EquipmentEffect.scaled(toLevel: g)`. Compute `effective(d,g) = max(raw(d,g), effective(d-1,g)+1 when d>0, effective(d,g-1)+1 when g>0)`. The tiny ≤5×4 table is derived on demand. Keep all rounding order and high-base raw outputs.
3. Make the existing instance `firstRoundAttackMultiplier(for:)` a thin wrapper over the same static multiplier composer for the **raw** path; make `traitAdjustedSoldierAttackPower(for:level:)` a thin wrapper that supplies current Treasury rank, equipped item's unscaled effect + level, city trait and Renown to the effective helper.
4. Switch the idle damage loop to call this same **instance** effective-attack function. Delete the now-unused cached `firstRound` field; keep cached specialist effects, Guard absorption, role second-round rounding and damage spill. `BattleScene` still caches the attack at spawn; changing gear or Treasury never rewrites an existing soldier.
5. Do not change authored percentages, conquest gold, prices, Renown formula, gear levels/drop logic, Captain/Guard power, combat scene architecture or save fields.

**Checkpoint:** static and instance matrix, live/idle parity and existing baseline no-buff/specialist behavior pass.

## Checkpoint 3 — **MANDATORY EARLY BALANCE GO/NO-GO (BEFORE UI)**

**Files:** existing seed-582 `Country1SiegeSmokeTests.swift` and PR evidence section.

1. Rerun `TEST_RUNNER_COUNTRY1_SMOKE_CAMPAIGN=1` using the same **post-Camp, real-level scorer** from Checkpoint 0 on the new attack rule: fresh bought+gear, Renown 0 replay, Renown 1 replay. Capture the full `city=`, `elapsed=`, `camp=`, `loadout=`, `treasury=`, `startGold/endGold=`, and `totalElapsed=` lines. Include City 1/2 of the zero-gold replay individually.
2. Compare every new variant against **its scorer-corrected no-floor control** from Checkpoint 0 (not only the untouched `main` historical trace).
3. **Stop before UI and seek an explicit balance decision on this same PR** if **any** of:
   - Any variant stalls or fails to conquer all 15 cities.
   - **Any City 1–5 of the fresh bought+gear variant finishes in <5.0 simulated seconds.**
   - **Any matched 15-city total is <65% of its scorer-corrected control** (more than 35% faster).
   - Renown 1 is not faster than Renown 0 on matched replays.
4. These are **provisional numerical guardrails**, chosen to flag trivialization, not claims of objectively ideal idle pacing. Record actual measurements, investigate which city/rank drives any regression, and resolve tradeoffs **before** polishing UI. Do not bypass the gate or silently tweak unrelated balance constants.

**Checkpoint:** The PR has empirical timing evidence and a written pass/fail verdict, before UI changes.

## Checkpoint 4 — Minimal truthful Kingdom readout

**Files:** `Pyxis/KingdomScene.swift` and focused `KingdomSceneTests.swift`; do not edit `TreasuryUpgrade.swift`.

1. Drill Yard preview already projects real state copies through the instance attack seam: remove the now-unreachable `(no damage change yet)` suffix for available next ranks. At max rank the existing current-power copy remains.
2. In `equippedEffectRoundsAway`, remove the now-unreachable `.attackBonus` result path (or handle it as always false without a second attack calculation); retain the Specialist/Toughness cases and their honest `(no gain yet)` note.
3. For an equipped attack item, use the existing copied/unequipped-state pattern and the state-aware attack seam to show **actual first-round** `atk X → Y` beside its nominal `Attack Lv N · +P%`. Keep the existing two-line compact row, and make accessible values carry the same actual gain. Shorten existing text if needed; no extra layout infrastructure or generic explanation string. Preserve next-drop and equip-cycle behavior.
4. Run existing compact-size fitting and VoiceOver/scene tests to ensure the row fits and remains understandable. Do not touch unrelated HPA-812 design items, Treasury effectName, icon art or animation.

**Checkpoint:** User-facing values agree with combat, with no new UI surface.

## Checkpoint 5 — Final documentation and verification

1. Update `CLAUDE.md`: the static raw modifier is **not** the final first-round authority; the instance effective attack projection feeds both live and idle, while the static composer supplies the raw cell multiplier. Note that the floor may dominate low-power progression; do not leave the pre-HPA-811 claim that the cached firstRound multiplier alone drives both paths.
2. Run Debug and Release builds, SwiftLint, **serial** `PyxisTests` and `PyxisUITests` (`-parallel-testing-enabled NO`; repo has limited simulator capacity). Extend existing tests instead of adding a new campaign engine. Then rerun the opt-in chained Country 1 suite once more on the final diff; record 15/15, all per-city timing, first replay City 1/2 and total.
3. If checks fail, fix and rerun **in this same PR**. Record actual commands, macOS/Xcode/simulator environment, outcomes, baseline-versus-new numbers, exceptions and remaining caveats in PR #54 before ready-for-review. Never claim an unexecuted test passed.

Suggested commands (use an installed simulator in place of iPhone 17 if needed):

    swiftlint lint
    xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build
    xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Release build
    xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests
    xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisUITests
    TEST_RUNNER_COUNTRY1_SMOKE_CAMPAIGN=1 xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests/Country1SiegeSmokeTests

## Same-PR acceptance checklist

- [ ] Historical main and scorer-corrected no-floor campaign **baseline traces recorded**.
- [ ] Pure rank matrix red→green; high-base `Lv10/DY4/G3 == raw == 30`; no-upgrade identity.
- [ ] One static effective-attack implementation; real live/idle projection parity; snapshot behavior.
- [ ] Gear-policy ordering and scorer corrected **before** the rule so timing comparison isolates the rule.
- [ ] **Early seeded campaign stop criteria pass before UI work**; 15/15, first replay City 1/2 and Renown comparison measured.
- [ ] Minimal Kingdom copy and VoiceOver updated; non-Attack no-gain truth preserved.
- [ ] `CLAUDE.md` refreshed; final serial lint, builds, unit/UI and campaign smoke run recorded.
- [ ] Review comments handled and balance evidence documented on PR #54, not split across tickets or PRs.

**Planning-only status at this revision:** No gameplay code has been implemented, and no simulator measurements have been executed or asserted by this review update.
