# HPA-672 — Ascension, Renown and leveled equipment: single-PR implementation plan

**Ticket:** https://linear.app/cwchanap/issue/HPA-672/gameplay-ascension-restart-country-1-for-permanent-renown  
**Companion design:** [2026-11-02-hpa-672-ascension-design.md](../specs/2026-11-02-hpa-672-ascension-design.md)  
**Baseline:** `main` at `eff4ce7f7656360ca1c3485a922d08fd23485528`; includes Treasury PR #49, Equipment PR #50 and merged equipment-review PR #51.  
**Delivery rule:** This is the **single HPA-672 implementation PR**, initially Draft and planning-only. Implementation, test additions, balance evidence and design-review fixes must continue on this same branch/PR. **Do not merge docs alone or create a follow-up implementation PR.**

## Existing code audit / constraints

| Owner | Current behavior / implementation seam |
| --- | --- |
| `Pyxis/KingdomGameState.swift` | Only campaign authority; constructor/decoder normalize stage, city, siege and equipment. `completeCurrentCity(with:)` is the sole Country 1 gear reward path. `goldReward(forCity:)` computes the one Treasury-adjusted conquest quote. The state-aware `traitAdjustedSoldierAttackPower` serves live spawns; idle `applyAbstractBuildingSpawnDamage` calls its static helper with cached Treasury/gear factors. |
| `Pyxis/EquipmentCatalog.swift` | Exactly 15 fixed catalog items; effect fractions authored at level 1, owned/equipped data in KingdomGameState, new gear receipt already persisted by `BattleResult`. |
| `Pyxis/BattleResultModels.swift` and `ConquestReportContent/Node` | A saved, pending `BattleResult` drives the existing optional fail-open gear line. No new report layout authority is necessary. |
| `Pyxis/KingdomScene.swift` + `KingdomLayout.swift` | Treasury/Armory swap into the same three-row content band. Header is already tight; **320×454 zero-inset** remains a mandatory supported boundary. Sections are ephemeral; existing scene store load/save, idle settlement, tab routing and accessibility should be reused. |
| `Pyxis/GameViewController.swift` | Sole stage/pending-first router; already supports Kingdom while `countryComplete` and Battle after a fresh `battleActive` state. No new route or tab. |
| `PyxisTests/Country1SiegeSmokeTests.swift` | Deterministic seed-582 chained 15-city rail, using a real `BattleScene`, `KingdomGameStore`, greedy Treasury/Camp purchases, greedy equipment selection and real conquest transitions. Calls its run helper with **manual deployment enabled**; keep this so the zero-gold replay can begin with the free infantry deploy. |

Do not add a second campaign manager, modifier engine, save framework, scene, generic section system, art asset or SFX. New Swift files in the existing source/test roots auto-register through `PBXFileSystemSynchronizedRootGroup`; do not edit `project.pbxproj`.

## Work sequence (all commits within this PR)

### 1. Pure Ascension state and persistence — write Swift Testing first

**Files:** `Pyxis/KingdomGameState.swift`, `PyxisTests/KingdomAscensionStateTests.swift` (new), focused `KingdomGameStoreTests.swift` cases.

1. Add `ascensionCount` and `equipmentLevelsByID` to the existing state, constructor/decoder and `CodingKeys`. Default count to 0 and levels for every normalized owned item to 1. Normalize negative count to zero; clamp owned-item levels to 1...3, reject unowned/unknown IDs and malformed input, and preserve all other state fields. No migration version.
2. Add `AscensionResult` and `ascend()` as one pure mutation: guard `stageStatus == .countryComplete && pendingBattleResult == nil`; on success reconstruct normalized City 1 `battleActive` state with **gold 0**, empty city/campaign/siege/idle/transient state, fresh Treasury, preserved gear IDs/equipped slots/levels, and incremented count. Do not touch external feedback preferences.
3. Pin the **entire** reset/keep field matrix, including `countryNumber`, `cityNumberInCountry`, `cityLevel`, `completedCityCount`, `siegeProgress`, `cityBattleStates`, `activeSiegeSession`, `pendingBattleResult`, `lastBackgroundedAt`, Treasury, and deliberate `None` slots. Prove mid-campaign, incomplete-final-report and second-call rejection are exact no-ops. Check encode/decode and fresh state equivalence except permanent fields.
4. Verify the replay with zero gold still exposes the existing level-1 infantry manual deployment even when no Barracks can be bought; do **not** relax the specified zero-gold reset.

**Checkpoint:** Full existing model suite still passes at count 0 and all gear level 1. No UI or stat effect changed yet.

### 2. Re-conquest raises equipment level at the existing completion seam

**Files:** `Pyxis/KingdomGameState.swift`, `Pyxis/BattleResultModels.swift`, `PyxisTests/KingdomEquipmentStateTests.swift`, `PyxisTests/BattleResultModelsTests.swift`.

1. On first Country 1 item grant, add level 1 without changing the first-owned-type auto-equip decision or existing `newEquipmentItemID` receipt.
2. On valid repeat completion of an already-owned item's city, increment the level `1 → 2 → 3`, capped. Keep the owned set unchanged; never silently equip or undo `None`. Use one optional typed `equipmentLevelUp` receipt (item ID/new level) on `BattleResult` **only** for an actual increase. In the one award seam, always clear caller-supplied new/upgraded receipts before computing them.
3. Test separate live, idle and Camp-settlement routes to `completeCurrentCity`; duplicate/out-of-stage attempts do not re-award or level; Country 2 grants no Country 1 gear. Acknowledging a pending result must not touch the account's equipment levels. Persisted receipt survives an actual `KingdomGameStore` round trip.
4. Ensure a level-3 repeat still gives the ordinary single gold payout and conquest progression but no gear change or invented gear line.

**Checkpoint:** Only one production method grants/levels a reward; no scene makes award decisions.

### 3. Renown and scaled equipment effects — preserve the exact rounding seams

**Files:** `Pyxis/KingdomGameState.swift`, `Pyxis/KingdomScene.swift` effect projection (later UI task), existing focused `TreasuryEffectSeamTests.swift`, `EquipmentEffectTests.swift`, `SoldierRoleDamageTests.swift` and new Ascension tests.

1. `goldReward(forCity:)`: include `1 + 0.25 × ascensionCount` in **the same existing round** as base reward × War Chest. No gold adjustment at conquest completion; live, idle, Camp, Scout and HUD already consume the quote.
2. `traitAdjustedSoldierAttackPower`: add a default-1 Renown argument on the shared static helper, include it in the existing first rounding with trait, Drill Yard and equipment, and pass it from the instance helper. In `applyAbstractBuildingSpawnDamage`, include Renown in the cached per-batch first-round factor or pass it as an explicit helper argument so idle matches live. Preserve the existing separate role/specialist second round and idle first-objective/raw-spill rule.
3. Equipment effects: resolve effective percentage as authored bonus × scale(level: 1→1, 2→1.5, 3→2), via the three existing state equipment projection methods (`equipmentAttackMultiplier`, `equipmentMaxHPMultiplier`, `equipmentSpecialistBonus`). Keep soldier attack/max HP/specialist cached when spawned; Captain and Guards unchanged; no HP benefit in idle.
4. Write pinned integer-math cases demonstrating why separately rounding Treasury × Renown × gear is wrong, and cases where the bonus rounds away. Check neutral/advantaged/disadvantaged traits, all five soldier types, each relevant objective, live vs idle parity and level 0/count 0 identity. Verify conquered city HP and original reward curve remain unchanged.

**Checkpoint:** Exactly two Renown seams, three gear seams and two existing attack-vs-objective rounding steps; no third rounding or extra payout.

### 4. Existing fail-open gear report and level-aware Armory

**Files:** `Pyxis/ConquestReportContent.swift`, `Pyxis/ConquestReportNode.swift` (only if needed), `Pyxis/KingdomScene.swift`, `PyxisTests/ConquestReportContentTests.swift`, `ConquestReportNodeTests.swift`, `KingdomSceneTests.swift`.

1. On a new item, project `New gear: <name> · Lv 1`; on the typed level-up receipt, project `Gear upgraded: <name> · Lv 2/3`. At cap or for an invalid/unrecognized receipt, omit the optional line. Reuse existing report space, reset/fail-open semantics; **do not change mandatory geometry or Continue**.
2. In the Armory, show `Lv N` beside equipped item and the **effective** damage/HP/specialist percentage. Use a small formatting helper that preserves 22.5%, 37.5%, etc., rather than the existing whole-percent rounding. Update the rounded-away disclosure to use leveled projections. Full values in accessibility; keep the existing compact two-line rows, per-type order and icon cache.
3. Test narrow text fit, no overlap, restored pending reports, live/idle/settlement receipts, no new report line on capped repeats, and no unexpected changes to selected equipment. Existing image lookups remain `equipment-<itemID>`; HPA-673 provides icons separately.

**Checkpoint:** All optional gear copy is truthful and never blocks an otherwise valid conquest report.

### 5. Ascend section + two-step confirmation inside existing Kingdom scene

**Files:** `Pyxis/KingdomLayout.swift`, `Pyxis/KingdomScene.swift`, `PyxisTests/KingdomLayoutTests.swift`, `PyxisTests/KingdomSceneTests.swift`, existing `GameViewControllerTests.swift`.

1. Extend `KingdomSection` to `.ascend` and fit three selectors into the current **top 44pt header**. Target 44pt-wide selectors with minimum 44pt hit size, adaptive 4–8pt spacing and a fitted short `Kingdom` title. At 320pt scene width, content width is 288pt: 3×44 selectors + 44 Settings + 8 Settings gap + 8 title gap leaves 96pt for title. Test narrower previously supported safe-width cases and adapt title-gap/font rather than regressing Treasury fit. No new vertical band/scrolling; the Treasury 3×80pt and Armory 5×≥44pt rows stay byte-identical in geometry.
2. Add a Gold + Renown bottom-header projection when `ascensionCount > 0`, with fitted separate frames and accessible full `Renown N · +XX%` label; leave other HUDs alone. Draw `ascension-renown` from the existing image loader with vector fallback; add no images.
3. Layout Ascend information and two mutually distinct controls **within the existing alternate content band**. Rows summarize current→next Renown, exactly what resets/keeps, and eligibility. A first **Ascend** tap arms the ephemeral confirmation; **Confirm Ascension** performs the second step; **Cancel** or section/tab change clears it. No UIKit alert or persistence of armed state.
4. For confirmation, load the current store and re-check the model guard, call the model mutation, then save and request `.battle` through the existing router. Prevent double-submit. A stale pending report must win through normal pending-first routing, never be cleared by confirm. No extra idle settle is needed at countryComplete (inactive campaign), but retain Kingdom's existing foreground/gate lifecycle behavior.
5. Add VoiceOver selector/action labels with disabled/selected state and full reset/keep preview. Test all tap areas (Settings, third selector, Treasury Buy, Armory rows, Confirm and Cancel), restoration/resize and unsupported-layout recovery. Keep the four tabs and one Settings gear.

**Checkpoint:** 320×454 zero-inset supported, other existing viewport fixtures unchanged, no hidden hit targets or accidental confirmation, no extra controller.

### 6. Real chained balance rail + completion evidence

**Files:** `PyxisTests/Country1SiegeSmokeTests.swift`, existing chained-campaign tests, this PR description and optional small in-PR evidence notes.

1. Extend the existing `runGreedyCampaign` test-only helper to accept an explicit initial `KingdomGameState` (defaulting to the present fresh state), and expose the final real state if needed to check Ascension. Keep seed **582**, existing greedy Treasury/Camp/equipment policy, 10Hz scene ticks, 900s/city bounds and **manual deploy enabled**. No second combat simulator or arbitrary reward grants.
2. Keep the HPA-670/671 control variants and previous numeric anchors intact when `ascensionCount = 0`. Add **matched** initial fixtures with `gold=0`, Treasury 0, all 15 owned items at **Lv1**, same selected gear policy and `ascensionCount=0` vs `1`. The cities' real repeat-completion code levels gear in both fixtures on the same schedule, so the difference is Renown, not pre-existing item levels. Both must complete 15/15 without stalls, and the Renown-1 run must have lower total elapsed simulated seconds.
3. Separately verify the real player route: City 15 complete with a pending finale → Continue acknowledgment → Ascension once → fresh City1/zero gold/manual infantry → subsequent conquest levels owned City1 gear from 1 to 2. Record run-state transitions without fabricating city completion.
4. Print each variant/city's start/end gold, equipped item IDs/levels, Treasury levels, awarded item/upgrade receipt, elapsed seconds, troop losses and stall/outcome, plus totals and actual simulator wall time. Document comparisons and any surprising rounding effects in the **same PR**; do not invent speeds at planning time.
5. Run `swiftlint lint`; Debug and Release simulator builds; focused then full Swift Testing and UI suites with `-parallel-testing-enabled NO`; opt-in campaign using `TEST_RUNNER_COUNTRY1_SMOKE_CAMPAIGN=1`; verify Codecov project and patch ≥90%. Capture available compact iPhone and portrait iPad Ascend, two-step confirmation, Renown header, leveled Armory and report evidence. Describe which simulator ran and any unverified physical-device behavior.
6. Address code review findings on this branch. Mark **this same PR** ready only after the feature, tests, measured chained run, and review feedback are complete. Link the completed PR to HPA-672; keep HPA-673 as a separate art task.

## Risk-focused review checklist

- **No accidental reset:** guard must reject while a report is pending, even at `countryComplete`; before/after model equality for rejection.
- **Correct replay:** gold is exactly zero, Treasury zero, all per-city state reset, but equipment, explicit None slots, levels and feedback preferences are preserved. City 1 manual infantry is not soft-locked.
- **One payout / one level:** reused completion seam, no double reward on relaunch or stale result, no silent auto-equip on repeats.
- **Rounding:** Renown × Treasury × Attack gear × trait is one first round; role × Specialist is one second round; conquest gold rounds once; idle receives Renown.
- **Compact geometry:** 320×454 Treasury/Armory fit remains, third section/Settings/accessibility still usable, no new vertical content.
- **Truthful optional receipt:** correct Lv1/2/3 line after reload; absent or capped reward does not cause report layout failure.
- **Single PR, separate art:** implementation stays on the documents PR; final icons/SFX are not added.

## Current status

**Planning only:** the design and this implementation plan are committed. No shipping Swift changes, simulator runs, test passes, Codecov results or balance measurements are claimed yet. The draft PR must remain open until the same-PR implementation and evidence above are complete.
