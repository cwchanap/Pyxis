# HPA-672 — Ascension, Renown and leveled equipment: single-PR implementation plan

**Ticket:** https://linear.app/cwchanap/issue/HPA-672/gameplay-ascension-restart-country-1-for-permanent-renown  
**Companion design:** [2026-11-02-hpa-672-ascension-design.md](../specs/2026-11-02-hpa-672-ascension-design.md)  
**Baseline:** `main` at `eff4ce7f7656360ca1c3485a922d08fd23485528`; includes Treasury PR #49, Equipment PR #50 and merged equipment review PR #51.  
**Delivery rule:** This Draft PR is the **single HPA-672 implementation PR**, initially planning-only. Land implementation, tests, balance evidence and review fixes on this branch/PR. **Do not merge docs alone or create another implementation PR.**

## Current code / design-review audit

| Existing owner | Reuse or change |
| --- | --- |
| `Pyxis/KingdomGameState.swift` | Campaign authority; constructor/decoder already normalize stages, city, siege and gear. `completeCurrentCity(with:)` owns all Country 1 drops; `goldReward(forCity:)` is the single conquest quote. State-aware `traitAdjustedSoldierAttackPower` feeds live spawns; idle `applyAbstractBuildingSpawnDamage` calls its static helper with cached factors. |
| `Pyxis/EquipmentCatalog.swift` | Exactly 15 authored Lv1 effects, with stable IDs. Add one `EquipmentEffect.scaled(toLevel:)` owner—not separate math in the three combat projections and Armory text. |
| `Pyxis/BattleResultModels.swift` and `ConquestReportContent/Node` | Durable pending `BattleResult` currently has `newEquipmentItemID`. Replace it with **one** typed `equipmentReward` receipt for both first drops and upgrades. Keep the decorative report line fail-open. Update all affected tests/readers without legacy-field migration. |
| `Pyxis/KingdomScene.swift` + `KingdomLayout.swift` | Treasury/Armory already share a compact content band. Three selectors need **readable measured labels**; remove visible `Kingdom` title, its fallback geometry and unused `futureSectionFrame` (zero height at 320×454). |
| `Pyxis/GameViewController.swift` | Sole stage/pending-first router; no new controller, tab, or alert. |
| `PyxisTests/Country1SiegeSmokeTests.swift` | Seed-582 chained 15-city rail already uses a real BattleScene/Store, greedy Treasury/Camp/gear policies and real conquest. Add a configurable initial state; run the matched Renown comparison as an **early Step 3 gate**, not at the end. Manual deploy remains enabled for the zero-gold start. |
| `Pyxis/ForgedVisualFixture.swift` | The existing `map-country-complete` fixture is an adequate no-pending starting point for Ascend screenshots; seed owned gear **only in that fixture**, leaving other fixtures/DevJump unchanged. |

Do not add a new game-state owner, modifier engine, save/version framework, scene, UI section platform, screenshot machinery, art or SFX. Swift sources/tests auto-register via `PBXFileSystemSynchronizedRootGroup`; do not edit `project.pbxproj`.

## Work sequence — six checkpoints, one PR

### 1. Pure Ascension state and persistence (tests first)

**Files:** `Pyxis/KingdomGameState.swift`, new `PyxisTests/KingdomAscensionStateTests.swift`, existing `KingdomGameStoreTests.swift`.

1. Add `ascensionCount: Int` and `private(set) equipmentLevelsByID: [String: Int]` to the existing normalized constructor/decoder and `CodingKeys`; default count to 0 and each **owned** gear item to level 1. Clamp count ≥0 and each known owned ID to level 1...3. Discard unowned/unknown level keys; tolerate missing/malformed fields. Add `equipmentLevel(for itemID: String) -> Int?` returning nil when the item is not owned—avoid direct map consumers.
2. Add `AscensionResult` (`.ascended(newCount:)`, `.unavailable`) and pure `ascend()`. Guard `.countryComplete && pendingBattleResult == nil`, then reconstruct a fresh normalized City 1 `.battleActive` state through the existing initializer with **gold explicitly 0**, blank campaign/city/siege/idle state and Treasury 0; copy owned IDs, current equipped selections (including deliberate `None`) and levels; increment count. `FeedbackPreferencesStore` is independent and untouched.
3. Assert rejection is byte-for-byte/model-equal no-op for mid-run, pending-final-result and repeated Ascend. Pin the complete reset/keep matrix: stage/city/country/count, cityBattleStates, activeSiegeSession, pendingBattleResult, siegeProgress/captain/guards, lastBackgroundedAt, Treasury, gear IDs/selections/levels. Prove save round-trip and fresh-state equivalence except permanent fields.
4. **Explicit zero-gold product tradeoff:** a fresh game starts with 15 gold, but the Linear task says Ascension resets to 0. First Renown City 1 yields 10 (8×1.25), short of the 15-gold Barracks; City 1 and City 2 of the first replay are manual-deploy-only and have no idle building production. Pin free level-1 Infantry deployment and a real beginning-of-replay conquest; don't silently grant 15 gold or alter the ticket. Higher Ascension counts may cross the affordability threshold earlier.

**Checkpoint:** Existing zero-Renown tests remain green, normalized equipment levels do not leak to unowned items, and a zero-gold replay is not soft-locked.

### 2. Single repeat-conquest equipment reward and receipt (tests first)

**Files:** `Pyxis/KingdomGameState.swift`, `Pyxis/BattleResultModels.swift`, `Pyxis/ConquestReportContent.swift` only as required for compilation, `PyxisTests/KingdomEquipmentStateTests.swift`, `BattleResultModelsTests.swift`, all existing `newEquipmentItemID` consumers/tests, and `CLAUDE.md` when implementation lands.

1. Replace `BattleResult.newEquipmentItemID` with **one** `equipmentReward: EquipmentReward?` where `EquipmentReward: Codable, Equatable` stores `itemID` and `level`. Level 1 means new, 2/3 means upgraded. This removes representable conflicting receipts; no extra optional `equipmentLevelUp` field or backward-compat adapter. Update all prior reference sites, report/readers and existing tests as part of this same PR.
2. Within the existing `completeCurrentCity(with:)` guard, reset the incoming caller-supplied gear receipt, then grant Country 1's fixed item at Lv1 if new, or increment its owned level 1→2→3 (capped) on subsequent runs. Write the one receipt only for real Lv1/2/3 changes. Keep first-ever-type auto-equip semantics; never alter an intentionally empty or chosen slot on repeat.
3. Test live, idle and Camp-settlement completion paths, duplicates/out-of-stage or mismatched-city attempts, Country 2 negative case, Lv3 capped repeat (normal single gold, **no** gear receipt), report acknowledgment, and saved/restored pending reward. Keep levels `private(set)` so only the one grant seam mutates them.
4. Update `CLAUDE.md` HPA-671 description in this implementation checkpoint to name the sole `equipmentReward` and current level semantics rather than the deleted `newEquipmentItemID`.

**Checkpoint:** No scene writes drops/levels, and no incompatible pair of optional gear receipts is representable.

### 3. One scaling owner + Renown seams **and early balance acceptance gate**

**Files:** `Pyxis/EquipmentCatalog.swift`, `Pyxis/KingdomGameState.swift`, `PyxisTests/TreasuryEffectSeamTests.swift`, `EquipmentEffectTests.swift`, `SoldierRoleDamageTests.swift`, `Country1SiegeSmokeTests.swift` and campaign helper tests.

1. In `EquipmentEffect`, implement `scaled(toLevel:)`: multiply the fractional bonus by precisely 1/1.5/2 for levels 1/2/3 and preserve its kind/target. On `KingdomGameState`, add `equippedEffect(for: SoldierType) -> EquipmentEffect?`, reading `equipmentLevel(for:)`. **All** three existing projections (`equipmentAttackMultiplier`, `equipmentMaxHPMultiplier`, `equipmentSpecialistBonus`) consume this scaled effect, not independent level-scale branches. Armory/UI will use the same accessor in Step 4.
2. Add one computed `renownMultiplier = 1 + 0.25 * Double(ascensionCount)`. Apply it **once** within `goldReward(forCity:)` with War Chest and base reward, preserving the single rounding and all existing report/Map/HUD/live/idle/Camp callers.
3. Add `firstRoundAttackMultiplier(for: SoldierType)` composing **Drill Yard × leveled attack gear × Renown**. The live state method and the idle batch's per-type cached loadout call that one accessor. Simplify the pure static `traitAdjustedSoldierAttackPower` to `(for:level:defenseTrait:multiplier: Double = 1)`, i.e. **one** explicit composite multiplier, and adapt existing tests, role-damage tests and the campaign's test-only helper. Apply the defense trait and all modifiers in one first round; keep role/specialist as the separate second round; Guards, Captain and idle HP unchanged.
4. Extend `runGreedyCampaign` with an optional explicit initial state and preserve every existing seed-582 control when count=0. Add matched 15-city **Ascension 0 vs 1** fixtures with `gold=0`, Treasury 0, all 15 items owned at Lv1, equal initial equipped policy, and the same deterministic Treasury/Camp/gear buyer. Update the test-only greedy candidate scoring to use `EquipmentEffect.scaled(toLevel:)` and the candidate's **effective Renown × Treasury × gear** in the existing integer formula; otherwise an evolved gear loadout is judged using stale Lv1 effects. Run the existing production BattleScene/Store transition for every city so both fixtures naturally level the same items at the same conquest.
5. **Run the opt-in chained rail now** (`TEST_RUNNER_COUNTRY1_SMOKE_CAMPAIGN=1`, seed 582), before implementing report/Armory/Kingdom UI. Assert 15/15 no stalls and Renown 1 measurably faster in total. Record the two variants' **City 1 and City 2 durations separately** (manual-only at first Ascension), all per-city timing/level/gold/treasury states and wall-clock. If the acceptance gate fails, investigate the exact integer rounding/camp policy and resolve the gameplay tradeoff before continuing; do not silently change the ticket's 0 gold or 25% Renown factor.
6. Add focused live/idle parity cases (neutral/advantaged/disadvantaged trait, low integer attack levels, all five soldier types, matching/nonmatching objectives, both levels 1/2/3, no gear). Pin one-round gold, one-round attack and second-round role/specialist boundaries and verify zero-Renown identity and capped gear behavior.

**Checkpoint / must-pass gate before UI:** **15/15 at both counts; Renown 1 clearly faster in measured total time**, no City 1/2 manual soft-lock, and the focused first/second-round tests green. Report actual results, not projected gains.

### 4. Truthful level-aware Armory and fail-open conquest report

**Files:** `Pyxis/KingdomScene.swift`, `Pyxis/ConquestReportContent.swift`, `ConquestReportNode.swift` only if necessary, focused content/node/scene tests.

1. Render `equipmentReward` in the **existing optional** gear report line: Lv1 → `New gear: <name> · Lv 1`; Lv2/3 → `Gear upgraded: <name> · Lv N`; no line for an invalid/capped/no-receipt result. Saved/reloaded results agree and never change report success criteria, Continue, tiles or achievement chips. No new mandatory report geometry.
2. `KingdomScene.armoryRowText`, `equippedEffectRoundsAway`, and accessibility derive effects from `state.equippedEffect(for:)`; do not reimplement scaling or read raw catalog effects for displayed bonuses. Show the owned item's level and effective percent. Replace the existing `wholePercent` formatter with a **single** max-one-decimal version (e.g. 22.5%, 37.5%, 30%) rather than adding another formatter. Keep two-line compact rows, per-type icons and cache.
3. Test level formatting/rounding disclosure, restored reports and the fail-open label on minimum-size viewports, Gear Lv3 no-upgrade receipt, and VoiceOver complete values.

**Checkpoint:** Display and simulation use one scaling authority; a gear reward cannot cause report layout failure.

### 5. Third Kingdom section and in-scene confirmation

**Files:** `Pyxis/KingdomLayout.swift`, `Pyxis/KingdomScene.swift`, `PyxisTests/KingdomLayoutTests.swift`, `KingdomSceneTests.swift`, `GameViewControllerTests.swift`.

1. Extend `KingdomSection` with `.ascend` (ephemeral, no separate screen). Remove the **visible** `Kingdom` title: the four-tab bar already identifies the selected tab. Keep `Kingdom` as a constant accessibility header. Delete `titleFrame`, `minimumTitleWidth`, `titleSpareWidth` and their fallback ladder rather than squeezing three unreadable 44pt labels beside the title. Put **three ≥44pt** header selector frames in the existing top 44pt line, with adaptive width/spacing. At **320×454** (288pt content width), each selector should have ~72pt; at the formerly supported **264×454** row-width floor, preserve fit via compact spacing, measured label widths and (only if needed) a short visible label with the full accessible name. Assert each actual label fits at or above 9pt and selectors/Settings do not intersect.
2. Delete `KingdomLayout.futureSectionFrame` and its old tests; it was noninteractive and zero-height at the 320×454 minimum, while Ascend must share the existing Treasury/Armory content band. Preserve all real Treasury row/Buy and Armory row frames and supported layout-gate recoveries. No scrolling, extra header height or new layout owner.
3. Add a fitted bottom-header gold/Renown display when count>0, plus current→next bonus, clear **Resets / Keeps** preview and an `ascension-renown` image-lookup-with-vector-fallback in the Ascend content band. No final art or SFX. Ensure at least 44pt Confirm/Cancel action targets, disjoint from the tab bar and Settings.
4. First **Ascend** touch arms transient confirmation; distinct **Confirm Ascension** commits; **Cancel**, section/tab change, scene dismissal or reconstruction clears it. On confirm, re-read latest `KingdomGameStore`, call the pure model guard/mutation, save once and route to `.battle` through existing `KingdomSceneRouting`. Never acknowledge an awaiting report or run Ascension from a stale local `state`; no second commit on repeated tap. Keep foreground/idle and unsupported-layout behavior unchanged.
5. Update scene accessibility section membership/labels, selected or disabled action state, current/next Renown and complete reset/keep values; test 320×454, 264×454 where previously supported, normal/inset phones and iPad, absent art, layout fail→recover, all hit-target isolation and pending-first routing.

**Checkpoint:** Existing Treasury/Armory hit/fit invariants remain, all new controls are reachable and legible, no title or dead reservation remains.

### 6. True replay integration, fixture evidence and full regression gate

**Files:** `PyxisTests/Country1SiegeSmokeTests.swift` for a small real-transition assertion if needed, `Pyxis/ForgedVisualFixture.swift` and focused fixture tests, plus this PR description/evidence.

1. Verify the **real** end-to-end stage chain: City 15 complete with a pending report → Continue/acknowledge → Ascend visible/eligible → confirm → City 1 `battleActive`, 0 gold, preserved Lv1 equipment → manual Infantry conquest → the owned City 1 item levels to 2 with a truthful persisted `equipmentReward`. No forged conquest or artificial reward.
2. **Explicitly skip changing `DevJumpState` or the DEBUG five-tap picker**, as allowed by Linear. In the existing `ForgedVisualFixture.mapFixtureState(for: .mapCountryComplete)` branch alone, create the complete state with all 15 catalog IDs owned at Lv1 (through the initializer because ownership is `private(set)`); keep `.map` and `.mapPartial` untouched. Capture Kingdom → Ascend prompt/confirm → Renown header → City 1 Lv2 reward/Armory through real routing, with a compact phone and portrait iPad. Do not build another capture fixture system.
3. Carry forward the **Step 3 measured** seed-582 ascension-0/1 balance table and City 1/2 times. Step 6 is **not** the first time the balance gate runs; re-run after any subsequent change that can alter combat/economy.
4. Run `swiftlint lint`; Debug and Release simulator builds; serial focused/full `PyxisTests` and `PyxisUITests` (`-parallel-testing-enabled NO`); Codecov project and patch ≥90%; opt-in chained campaign gate; inspect compact/iPad visuals. Add actual commands, simulator/Xcode versions, warnings, measurement table, screenshots and deviations to **this same PR**.
5. Address review comments on this branch; mark **PR #52** ready only after the code, tests and evidence are complete. HPA-673 stays the separate art ticket; never open a second implementation PR.

## Risk-focused review checks

- **No unintended reset:** a pending finale means Ascend is unavailable; exact state equality on rejection; feedback preferences are separate.
- **Deliberate early manual play:** first Ascension begins with zero gold, not 15. City 1/2 timing and inability to idle without buildings must be visible in acceptance evidence.
- **One reward:** `equipmentReward` alone; levels stay inside `KingdomGameState`, capped at 3, with no double grant on duplicate/reload, no auto-equip on upgrade.
- **One level scaler and one first-round factor:** `EquipmentEffect.scaled(toLevel:)` → `equippedEffect(for:)`; `firstRoundAttackMultiplier(for:)` feeds live and idle; static helper takes one composite factor; no double rounding, Captain/Guards stay unchanged.
- **Measured gate early:** compare count 0/1 before building report/Kingdom UI; score greedy candidates at their real level/renown factor, and keep seed/camp policy matched.
- **Compact and accessible:** remove visible title and dead future reservation, preserve 320×454 and existing narrow-row support, assert selector text fit and 44pt hit targets.
- **Keep scope small:** no different architecture, extra scene, save migration, final art/SFX, or separate implementation PR.

## Current status

**Planning only.** This PR contains revised design + plan documents addressing the Nov 3 design review. No shipping Swift changes, simulator runs, passing tests, Codecov results or measured Renown balance numbers are claimed yet. All implementation and evidence remain work on the **same Draft PR #52**.
