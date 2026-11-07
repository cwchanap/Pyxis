# HPA-811 — Guaranteed effective attack gains: single-PR implementation plan

**Ticket:** https://linear.app/cwchanap/issue/HPA-811/early-drill-yard-and-attack-gear-give-no-damage-gain  
**Design:** [HPA-811 effective attack design](../specs/2026-11-07-hpa-811-attack-upgrade-rounding-design.md)  
**Baseline:** main at 98c9d358028d04ec8809a9e3efa5799aa1297422 (Nov 7, 2026). No open PR at planning time.  
**Delivery rule:** This draft PR is the **one implementation PR for HPA-811**. Commit code, tests, validation evidence and review fixes to this branch; **do not merge the planning-only commit or open a second implementation PR**.

## Review of the actual code

| Owner | Relevant current behavior | Planned work |
| --- | --- | --- |
| Pyxis/KingdomGameState.swift | Static traitAdjustedSoldierAttackPower rounds base × city trait × first-round modifiers once. Instance overload and live spawn use the current firstRoundAttackMultiplier. Idle applyAbstractBuildingSpawnDamage instead uses a cached composite multiplier with the static helper. | Keep the existing static rounding primitive; derive a monotonic effective integer attack from existing Drill Yard/gear ranks at the **one state-aware projection**, and converge live/idle on it. |
| Pyxis/EquipmentCatalog.swift | EquipmentEffect.scaled(toLevel:) is the sole +15%, +22.5%, +30% authority. | Reuse it; no catalog or save changes. |
| Pyxis/KingdomScene.swift | Drill Yard example projects levels using the real instance seam, but says “no damage change yet”; Armory flags attack items as “no gain yet” when equal to an unequipped quote. | Keep real-state previews; explain guaranteed floor, remove obsolete attack no-gain note and preserve honest non-attack disclosures. |
| Pyxis/TreasuryUpgrade.swift | Drill Yard effectName says attack +5% per level. | Add concise floor wording, without changing costs, max level or authored multiplier. |
| PyxisTests/Country1SiegeSmokeTests.swift | Deterministic greedy-equipment scorer calculates candidate attack with the old static percentage fold; the chained smoke rail is opt-in with seed 582. | Use hypothetical equip/unequip on a copied state and the **same effective attack accessor**; update stale policy expectations; reuse existing campaign variants. |
| PyxisTests/EquipmentEffectTests.swift, TreasuryEffectSeamTests.swift, KingdomSceneTests.swift, KingdomAscensionStateTests.swift | Pin single-round math, live/idle parity, old no-gain copy and Renown/gear-level examples. | Update only expectations intentionally changed by HPA-811; preserve unaffected baselines, HP/specialist and snapshot semantics. |

## Step 1 — Red tests first (no production changes yet)

**Files:** PyxisTests/TreasuryEffectSeamTests.swift, EquipmentEffectTests.swift, KingdomSceneTests.swift; focused tests in KingdomAscensionStateTests.swift where needed.

1. Add a table test with current state at soldier level 1–8, each neutral/advantaged/disadvantaged city trait, Renown 0 and 1 (plus one later Ascension), Drill Yard levels 0–4, and same-soldier attack gear None/Lv1/Lv2/Lv3. Assert strict increment of at least 1 for **every** next Drill Yard and gear rank; assert the no-upgrade result equals the pre-change static trait projection exactly.
2. Pin small examples: Lv1 neutral infantry with no buffs = 1; DY 1 = 2; attack gear Lv1/Lv2/Lv3 = 2/3/4; DY1 + Lv1 attack gear = 3. Pin one large-attack example where the ordinary percentage result wins over the floor.
3. Cover unequip, switching to toughness/specialist and max-level transitions; verify those do not inherit an attack floor. Prove raw equipment fraction scaling and Renown formula have not changed.
4. Red-test the existing idle-vs-live seam: one identical ordinary troop spawned live and abstractly while receiving the rounded-away bonuses must deal the same first-round attack. Verify an already-spawned troop keeps its prior cached attack after a later Treasury purchase or equipment change.
5. Pin Kingdom Drill Yard and Armory output/VoiceOver values. These tests should fail for the known “1 → 1” / “no gain yet” state on main. Do not delete tests merely because their old result will change.

**Checkpoint:** reproduce the bug with failing tests before changing gameplay.

## Step 2 — Implement exactly one effective first-round projection

**Files:** Pyxis/KingdomGameState.swift only for production combat rules, plus focused tests.

1. Implement the design's bounded 2D recurrence using integer levels **d=0…4, g=0…3**. Compute raw(d,g) through the existing static traitAdjustedSoldierAttackPower and its **one** round; get each gear stage from the equipped item's existing EquipmentEffect.scaled(toLevel:). Add predecessor +1 floors, return the current cell. Only a currently equipped **attack** item has g>0. Keep the helper private or file-scoped; there is no general buff/matrix framework.
2. Have the existing state-aware traitAdjustedSoldierAttackPower(for:level:) return this result. Preserve the unmodified zero-DY/no-attack-gear calculation, including all Renown-only cases. If keeping firstRoundAttackMultiplier(for:), make it a single raw-target accessor rather than a parallel authoritative final-attack path; avoid duplicated authored constants.
3. In applyAbstractBuildingSpawnDamage, replace direct static percentage-only evaluation with the **same state-aware effective attack projection** used by BattleScene's live spawn. Keep the existing batch's specialist snapshot, Guard path, role second round and raw spill. Avoid a new service/caching layer; optimize only if the existing smoke rail reveals a real issue.
4. Do **not** change BattleCombatState's cached spawn-attack interface, Guard/Captain damage, other equipped effects, city HP, Treasury prices, Renown percentages, equipment levels, saves, or scene routing. No migration and no project-file editing (the repo auto-registers Swift source files).

**Checkpoint:** minimum rank increments pass; unmodified no-upgrade combat and existing role-damage contracts remain green.

## Step 3 — Bring campaign scorer and Kingdom explanations into parity

**Files:** PyxisTests/Country1SiegeSmokeTests.swift, Pyxis/KingdomScene.swift, Pyxis/TreasuryUpgrade.swift and focused scene/accessibility tests.

1. Rework the existing test-only greedy equipment candidate projection to copy the current KingdomGameState, try the candidate through its real equip/unequip mutation, and score attack via the shared state-aware projection at level 1. Score specialist through the unchanged second-round helper. Do **not** write another percentage/floor formula into the campaign helper and do not turn it into runtime AI.
2. Update scorer tests that currently prefer Toughness because the Attack item rounded away; attack is now an actual integer gain. Keep strict-damage comparison, stable tie-breaking, and specialist-over-attack behavior where the specialist genuinely wins.
3. Drill Yard: keep the existing current → next infantry/trait/gear/Renown example. For an available next level the integer must increase; the stale “no damage change yet” note is unnecessary there. At max level, retain the existing current-value behavior.
4. Armory: the attack row should show the **effective item level and nominal percentage plus a concise minimum-gain disclosure**; do not claim the percentage alone caused the result. Provide the exact comparison with the unequipped attack in accessible detail if visual width is constrained. The attack “no gain yet” branch must no longer appear. Leave rounded-away Toughness/Specialist disclosures, cycling, art and all HPA-812 layout issues unchanged.
5. Update the Drill Yard static effect description (currently “+5% per level”) to include the minimum in appropriately compact language. Assert text frames and touch targets fit the existing narrowest accepted iPhone and iPad layouts and VoiceOver values remain accurate.

**Checkpoint:** previews agree with combat and are legible; no unrelated UI polish.

## Step 4 — Balance acceptance before review completion (mandatory)

**Files:** existing tests and the PR evidence section; avoid creating a new simulation.

1. Run focused and complete **PyxisTests**, **PyxisUITests** and SwiftLint, with simulator tests **serial** (-parallel-testing-enabled NO), plus Debug and Release builds. Use whichever installed simulator is available.
2. Run the opt-in **TEST_RUNNER_COUNTRY1_SMOKE_CAMPAIGN=1** suite (Country1SiegeSmokeTests) after the change. This is **required** because this task alters attack balance, even though it does not edit the percentage constants.
3. Reuse seed 582, the existing baseline, bought-Treasury + gear campaign and the matched Renown 0/1 replay campaigns. Record per-city elapsed time, 15/15 completion or stalls, and total duration; explicitly inspect first-replay City 1/2 (manual-only starting at zero gold).
4. Check first-upgrade effective damage on real State/scene projections and verify unchanged result/persistence, gold awards, objective-role behavior, Captain/Guard paths, and live-soldier snapshots. Include a short table showing first-level Drill Yard and attack-gear level gains plus measured total campaign changes.
5. If progression becomes trivially fast, **do not silently lower the guarantee or change unrelated balance constants**. Document the measured tradeoff and request an explicit product decision on the same draft PR. Change the design and re-run the same suite before merging if a different rule is agreed.

Suggested commands (replace destination if necessary):

    swiftlint lint
    xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO -only-testing:PyxisTests test
    xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO -only-testing:PyxisUITests test
    TEST_RUNNER_COUNTRY1_SMOKE_CAMPAIGN=1 xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests/Country1SiegeSmokeTests

**Planning-only status:** No simulator execution or implementation has been performed in this draft. The commands and acceptance gates are required for the later implementation commits, not claimed as passing here.

## Completion checklist — one PR

- [ ] Red tests reproduce low-level no-gain conditions and pin strict next-level gains.
- [ ] State-aware first-round rule is the only effective attack authority; live/idle agree.
- [ ] Attack gear Lv1/2/3 and Drill Yard 0/1/2/3/4 have perceptible increments under all targeted early states; none/other effects untouched.
- [ ] Test-only greedy scorer uses the real state projection; affected old tests updated deliberately.
- [ ] Kingdom text/VoiceOver show honest realized and nominal numbers, including the minimum.
- [ ] Serial build, lint, unit/UI tests and **opt-in chained campaign** pass; evidence is added to this PR.
- [ ] Record any balance compromises and review responses in this same PR; do not split implementation across PRs.
