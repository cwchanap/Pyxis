# HPA-670 — Kingdom tab + Treasury: single-PR implementation plan

Related design: [HPA-670 Kingdom/Treasury design](../specs/2026-10-30-hpa-670-kingdom-treasury-design.md)
Linear: https://linear.app/cwchanap/issue/HPA-670/gameplay-kingdom-tab-with-treasury-upgrades-that-persist-across-cities

## Delivery shape

Use **one PR for HPA-670**, first carrying this spec/plan as a draft and later adding implementation, tests and measurement to the *same branch*. Do not open a separate foundation, UI, model, persistence or follow-up PR. Do not block on final imagery; the distinct HPA-673 art ticket owns generated assets. No new Linear tickets are needed.

### Repository baseline verified

Reviewed `cwchanap/Pyxis` `main` at `516f20d873d7c3da3cfe794c662cb6717ab66b61`.

- `KingdomGameState.swift` is the campaign/normalization owner. `currentGoldReward` and `traitAdjustedSoldierAttackPower` are shared conquest and spawn/abstract-damage seams, but `CountryMapScoutCardContent.project` displays the **static base reward**, so it must also use an upgraded instance quote. Existing static building prices appear in purchase mutations, Camp and recommendations.
- `completeCurrentCity(with:)` already removes the conquered `CityBattleState`, stores `pendingBattleResult` and grants exactly the passed report reward. Do not change the completion contract.
- `GameViewController.presentSceneForCurrentStage` routes pending reports first but currently always opens Map in `cityConqueredPendingMap` or `countryComplete`. The Map tab projection currently enables only Map when not in active battle.
- `GameplayTabBarNode` and Battle/Camp/Map layouts derive tab widths from `GameplayTab.allCases.count`. `GameplayTabBarNode.makeIcon` currently yields only vector shapes; the new asset-backed Kingdom icon requires explicit sprite size/tint/alpha and sprite-capable test hooks. Reuse the pure `BattleChromeLayout.tabHitFramesInSafeArea` calculation for Kingdom rather than writing a fifth independent tab-hit algorithm.
- `CampSelectionContent.project`, `BuildingViewScene.canBuild`/`canUpgradeSelectedSlot`, `RecommendedCampRecommendation.make` **and test-only `PyxisTests/GreedyCampBuyer.swift`** explicitly invoke static cost functions. They all need the same state-aware quote; otherwise the 4/4/4 campaign buyer rejects some affordable discounted purchases.
- `CLAUDE.md` calls for Swift Testing, nonparallel simulator testing, and an opt-in chained Country 1 smoke run for balance-affecting work.

## Work sequence (all within this PR)

### 1. Treasury rules, purchase and persistence — tests first

**Add** `Pyxis/TreasuryUpgrade.swift` and `PyxisTests/TreasuryUpgradeTests.swift`.
**Modify** `Pyxis/KingdomGameState.swift` and `PyxisTests/KingdomGameStateTests.swift` (and existing decode/store tests as needed).

- Define `TreasuryUpgrade` with three cases and one authoritative place for base cost, max level, effect name and placeholder asset name. Define a tiny `TreasuryState` with three integer levels and clamping. No reusable perk/modifier system.
- Add `treasury` to `KingdomGameState`, its initializer, `CodingKeys` and decoder. Normalize missing/invalid levels to zero; preserve through `completeCurrentCity` and stage changes; let the synthesized encoder include the key.
- Implement `purchaseTreasuryUpgrade(_:)` and test initial costs 40/50/45, exponent 1.8 price progression, exact last purchase, max-level rejection, insufficient gold with no mutation, and purchase while both pending-map and country-complete.
- Add store round-trip and hand-crafted JSON tests for absent `treasury`, negative and over-max levels. Avoid any general migration layer.

**Checkpoint:** pure tests green; no gameplay/UI code needed yet.

### 2. Centralize the three effect seams — tests first

**Modify** `KingdomGameState.swift`, `CountryMapScoutCardContent.swift`, `RecommendedCampRecommendation.swift`, `CampSelectionNode.swift`, `BuildingViewScene.swift`, **`PyxisTests/GreedyCampBuyer.swift`**, and focused existing tests.

1. **Gold:** rename static `goldReward(for:)` → `baseGoldReward(for:)` and add `state.goldReward(forCity:)` as the **one adjusted quote** for any city. Have `currentGoldReward` delegate to it and `CountryMapScoutCardContent.project(from:)` use the same instance quote, so the Scout card, Battle HUD, live settlement and Camp/idle results agree. Keep `finalizeConquestWhenKeepDestroyed`, `BattleResult` and `completeCurrentCity` as consumers without multiplying again. Fix compile errors at old `goldReward(for:)` sites by choosing base vs adjusted deliberately, retaining base-curve formula tests under `baseGoldReward(for:)`. Test a scouted different city as well as current and earned rewards.
2. **Attack:** retain HPA-670's initial +5%/level Drill Yard percentage **for this planning decision** (option **b** in review), not a level-offset rule. Extend static `traitAdjustedSoldierAttackPower(for:level:defenseTrait:)` with defaulted `upgradeMultiplier: Double = 1`, fold it into the existing **single** round; instance passes `1 + 0.05 * DrillYardLevel`. Keep existing role-damage second rounding and cached soldier attack. Add two tests: (i) the illustrative base 9 × 0.80 × 1.05 = 7.56 → **8** vs double-round 7, and (ii) a **reachable-level matrix** using real `normalSoldierAttackPower` for levels 1...8, all three trait multipliers and DY 0...10, asserting the actual visible integer attack deltas (including zero). The Kingdom UI must display one **rounded current→next example** for Infantry at its actual accessible level and current city trait; when both values equal, clearly show “no damage change yet.” Check the real bought campaign before merging and revise balance if the result is not rewarding.
3. **Cost:** **rename** the existing static helpers to `baseBuildingBuildCost(for:)` / `baseBuildingUpgradeCost(for:currentLevel:)` (internal to allow base-formula tests). Old static calls then **fail compilation**, forcing a deliberate choice for each call site, including the actual charged mutations in `KingdomGameState`. Add state-aware `buildingBuildCost(for:)` and `buildingUpgradeCost(for:currentLevel:)` as the only quoted/charged API; apply Quartermaster once and round once, min 1. Fix compile errors across Camp selection/inspector, affordability, Recommended Camp, test-only `PyxisTests/GreedyCampBuyer.swift`, and tests. Its `candidates.filter { $0.cost <= state.gold }` must use discounted quotes. Assert Camp displayed price, recommendation price, buyer candidate, affordability and actual debit are identical. Keep explicit base-price curve assertions in tests.

**Checkpoint:** unchanged zero-upgrade baseline tests still pass; nonzero tests exercise live/idle parity and quote/charge parity.

### 3. Four-tab routing and behavior — tests first

**Modify** `Pyxis/GameplayTabBarNode.swift`, `Pyxis/GameViewController.swift`, `Pyxis/CountryMapScene.swift` and relevant `PyxisTests/GameplayTabBarNodeTests.swift` / `GameViewControllerTests.swift` / Map/Battle/Camp tests.

- Add `GameplayTab.kingdom` and its title/name/`tab-kingdom` asset lookup with vector fallback. The HPA-673 art PR changes **no Swift**, so implement raster sprite sizing (both forged and standard appearance), selected/disabled alpha, forged tint/color blending and shape-or-sprite test hooks in this PR; do not refactor existing Battle/Camp/Map vector icons. Four-tab cell widths still use `allCases.count`. Test present/missing asset paths and that a sprite doesn't regress tab hit frames.
- Add controller presentation of `KingdomScene` and a small `KingdomSceneRouting` callback to request a tab switch. Route Kingdom in any stage only **after** the pending-result gate. Do not alter existing routing for Battle/Camp/Map requests.
- Ensure non-active Map enables `[.map, .kingdom]`; do not accidentally expose Battle/Camp in completed campaign. Battle/Camp can include Kingdom in their enabled tabs under the existing no-pending and active-squad guards. Do not bypass Battle's active-manual-squad guard when showing Kingdom.
- Update tests that assume three tabs / hardcoded icon count. Check four-tab 44-point hit targets at compact phone width and portrait iPad. Verify entry to Kingdom from each of the three prior scenes and countryComplete; test that a pending result still opens Battle first and a rejected tab selection doesn't dismiss the report.

**Checkpoint:** routing and tab tests pass; Kingdom scene may initially render a minimal testable shell.

### 4. Kingdom layout, scene and purchase UI

**Add** `Pyxis/KingdomLayout.swift`, `Pyxis/KingdomScene.swift`, `PyxisTests/KingdomLayoutTests.swift`, `PyxisTests/KingdomSceneTests.swift`.

- `KingdomLayout` computes a safe-area-aware title/gold header, three Treasury cards, Buy hit targets, Settings anchor and shared four-tab frame. Make `BattleChromeLayout.tabHitFramesInSafeArea(for:safeFrame:)` internal and reuse this **pure** function for Kingdom's hit frames; do not refactor existing Map/Camp hit frames. Leave room for future sections only if all three actual rows fit, returning nil otherwise.
- Build the scene with existing `PanelNode`, `GameUITheme`, `GameplayTabBarNode` and the common Feedback Settings gear/accessibility adapter. Keep node tree stable across redraws; on layout change recompute frames, don't create duplicate nodes.
- On `didMove` load the latest store state. Display name, current level, next effect (or MAX), current gold, price and Buy enabled/disabled from the pure model. For Drill Yard, compute a **labeled example** (current Infantry level × current city's trait) using the same static single-round attack helper at current and next DY levels; display actual `P → Q attack` and “no damage change yet” if equal. Avoid presenting the theoretical multiplier as an immediate guaranteed damage gain. On Buy, call `state.purchaseTreasuryUpgrade`, save only on success and redraw.
- Use existing `UIImage(named:)`/SpriteKit lookup for all three Treasury art names; render **one shared** vector placeholder shape when missing, with upgrade names differentiating the rows. Do not create three bespoke glyph implementations or art; no SFX.
- **Mirror behavior, not ownership:** keep Map/Camp's existing scene-local notification/gate-routing semantics untouched; Kingdom follows their `returnFromBackground` → optional `enterBackground` on gate pause, active `markCurrentCityBuildingProgressInactive` on gate resume, and foreground settle → pending-report routing sequence. Test a Kingdom foreground conquest and gate pause/resume, including no lost or duplicated report. Do **not** add a new shared `KingdomGameState` lifecycle method taking view flags or refactor Map/Camp in this already-large feature PR: scene-level pending routing differs (Camp preserves deliberate in-place conquests). The three short call sequences are acceptable until a shared abstraction is justified.
- Add accessibility ids for the header, each upgrade row and Buy action; verify disabled states and correct on-screen prices in scene tests.

**Checkpoint:** scene interaction tests, phone/iPad layout geometry tests, and navigation tests pass.

### 5. Campaign balance and regression evidence

**Modify only if necessary** `PyxisTests/Country1SiegeSmokeTests.swift` or its existing test-only helper. Do not make a second simulator.

- Record the opt-in zero-Treasury chained 15-city campaign run using `TEST_RUNNER_COUNTRY1_SMOKE_CAMPAIGN=1`; per-city log lines and City 15 completion should match the HPA-582 baseline within normal run variance.
- Seed Treasury `4/4/4` in the existing harness/test fixture **as a free comparison only**, without gameplay DEBUG switches. Assert `GreedyCampBuyer.nextAction` quotes discounted cost and buys only affordable actions. Record City 15 time/stall as a power-ceiling measurement, not evidence of pricing quality.
- Add a **bought Treasury** variant to the same `runGreedyCampaign` test harness: at every city entry, repeatedly buy the cheapest affordable Treasury level via the real `purchaseTreasuryUpgrade(_:)` mutation (deterministic tie-break) **before** the existing greedy Camp purchase loop. Do not seed free upgrades. Extend `Country1CampaignCityRecord`/`campaignLine` with per-city `treasury=a/b/c`, Treasury spend and Camp spend, and retain per-city elapsed/stall markers. Compare baseline, free 4/4/4 and bought results; if actual paid upgrades are unavailable until very late or stall progression, record that as a balance issue and tune the starting values before merging. Current `4/4/4` sum is 1,603 gold at quoted prices, and max levels may not be reachable within one run; HPA-672 resets Treasury but eventually increases earned gold through Renown. No new simulator.
- Regression checks: old saves default levels 0; no new state owner survives an unintended city reset; a pending battle report is not lost; a purchase from Kingdom affects the next spawn/build/conquest; live soldiers retain cached stats; Quartermaster affects all build/upgrade paths; no accidental discount to Treasury prices.
- Run build, lint, full `PyxisTests` and relevant UI tests in the simulator. Disable parallel testing per repo guidance. Record pass/fail and any unavailable simulator/platform constraints directly in the PR.

Reference shell command (replace destination with an installed iOS simulator):

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test
TEST_RUNNER_COUNTRY1_SMOKE_CAMPAIGN=1 xcodebuild \
  -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO test \
  -only-testing:PyxisTests/Country1SiegeSmokeTests
```

## Done means

- One reviewable PR contains this plan, code, focused unit and scene tests, and recorded smoke evidence.
- The Treasury feature works through all three existing entry scenes, in every campaign stage; pending reports still take priority.
- Saved Treasury levels survive conquest and relaunch; zero-level behavior matches current main.
- No equipment, Armory UI, Ascension, final art or SFX has slipped into this PR.

## Review risks to check

| Risk | Focused check |
| --- | --- |
| Gold multiplied twice / Scout quote stale | `CountryMapScoutCardContent.project` and current reward use instance `goldReward(forCity:)`; assert Scout/HUD/report/credited gold agree |
| Trait + upgrade rounded twice / negligible low-level effect | Static helper default `upgradeMultiplier = 1`; assert base 9 × 0.80 × 1.05 → 8, and matrix levels 1...8 × traits × DY 0...10; effective attack preview shows no change when rounded |
| Static price call left behind | Rename base helpers to force compile errors at old price sites; assert production charged price, Camp quote, Recommended Camp and buyer quote are identical |
| Fourth tab steals home-indicator taps | Reuse `BattleChromeLayout.tabHitFramesInSafeArea`; test compact/iPad containment and sprite sizing/tint/test hooks |
| Completed-map hard route masks Kingdom | Controller `countryComplete` + `cityConqueredPendingMap` integration cases |
| Returning from Kingdom eats pending report | Scene-local foreground/gate settlement tests plus controller pending-first routing; no Map/Camp lifecycle refactor |
| Free 4/4/4 masks unaffordable progression | Run real purchased variant, log Treasury/Camp spend and levels per city; any stall/late unlock is balance evidence |
