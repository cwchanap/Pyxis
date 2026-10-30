# HPA-670 — Kingdom tab + Treasury: single-PR implementation plan

Related design: [HPA-670 Kingdom/Treasury design](../specs/2026-10-30-hpa-670-kingdom-treasury-design.md)
Linear: https://linear.app/cwchanap/issue/HPA-670/gameplay-kingdom-tab-with-treasury-upgrades-that-persist-across-cities

## Delivery shape

Use **one PR for HPA-670**, first carrying this spec/plan as a draft and later adding implementation, tests and measurement to the *same branch*. Do not open a separate foundation, UI, model, persistence or follow-up PR. Do not block on final imagery; the distinct HPA-673 art ticket owns generated assets. No new Linear tickets are needed.

### Repository baseline verified

Reviewed `cwchanap/Pyxis` `main` at `516f20d873d7c3da3cfe794c662cb6717ab66b61`.

- `KingdomGameState.swift` is the existing campaign and persistence-normalization owner; `currentGoldReward` is the conquest reward seam, `traitAdjustedSoldierAttackPower` is the spawn/abstract-damage seam, and the two static building cost helpers are used across mutation, Camp and recommendations.
- `completeCurrentCity(with:)` already removes the conquered `CityBattleState`, stores `pendingBattleResult` and grants exactly the passed report reward. Do not change the completion contract.
- `GameViewController.presentSceneForCurrentStage` routes pending reports first but currently always opens Map in `cityConqueredPendingMap` or `countryComplete`. The Map tab projection currently enables only Map when not in active battle.
- `GameplayTabBarNode` and Battle/Camp/Map layouts already derive tab geometry from `GameplayTab.allCases.count`. Check every four-tab test assumption rather than adding a second tab implementation.
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

**Modify** `KingdomGameState.swift`, `RecommendedCampRecommendation.swift`, `CampSelectionNode.swift`, `BuildingViewScene.swift`, **`PyxisTests/GreedyCampBuyer.swift`**, and focused existing tests.

1. **Gold:** modify `currentGoldReward` only, multiplying the existing base reward by the War Chest effect and rounding once. Keep `finalizeConquestWhenKeepDestroyed`, `BattleResult` and `completeCurrentCity` as reward consumers; do not multiply them again. Test live settlement, abstract idle settlement and an action in Camp that settles to conquest.
2. **Attack:** extend the **static** `traitAdjustedSoldierAttackPower(for:level:defenseTrait:)` with a defaulted `upgradeMultiplier: Double = 1` parameter; calculate `max(1, Int((Double(baseDamage) * defenseTrait.damageMultiplier(for: soldierType) * upgradeMultiplier).rounded()))` in that helper. The **instance** method passes `1 + 0.05 * DrillYardLevel` and must not round an already trait-rounded static return value. Existing static callers keep their zero-Treasury semantics with the default `1` and there is still **one formula / one round** before the separately rounded role effect. Test the discriminating example base 9 × 0.80 × 1.05 = 7.56 → **8** (not 7 from two rounds); confirm live manual/building spawns and the abstract idle branch agree. Keep `BattleCombatState`'s cached soldier power and existing role-damage second rounding unchanged. Captain remains excluded.
3. **Cost:** make `state.buildingBuildCost(for:)` and `state.buildingUpgradeCost(for:currentLevel:)` the public quote APIs. Treat the current static formulas as private base pricing, apply Quartermaster discount once and round once, min 1. Replace **all** cost call sites in mutations, Camp selection/inspector, affordability, Recommended Camp, **and the test-only `PyxisTests/GreedyCampBuyer.swift`**. Its candidate enumeration and `candidates.filter { $0.cost <= state.gold }` must use the **discounted** quotes so the 4/4/4 harness selects genuinely affordable actions. Search the entire repository, including tests, for remaining `KingdomGameState.buildingBuildCost` / `buildingUpgradeCost` static usage. Tests must assert UI price, recommendation price, buyer candidate price, affordability and actual debited price are identical.

**Checkpoint:** unchanged zero-upgrade baseline tests still pass; nonzero tests exercise live/idle parity and quote/charge parity.

### 3. Four-tab routing and behavior — tests first

**Modify** `Pyxis/GameplayTabBarNode.swift`, `Pyxis/GameViewController.swift`, `Pyxis/CountryMapScene.swift` and relevant `PyxisTests/GameplayTabBarNodeTests.swift` / `GameViewControllerTests.swift` / Map/Battle/Camp tests.

- Add `GameplayTab.kingdom` and its title, name, `tab-kingdom` icon asset lookup with vector fallback. The lookup is intentional despite existing tabs being vector-only: HPA-673 ships **assets without Swift changes**, so the new icon must activate when its image arrives. Do not refactor the three existing tabs. Keep a single `GameplayTabBarNode`; its cell width and hit-frame math should remain driven by `allCases.count`.
- Add controller presentation of `KingdomScene` and a small `KingdomSceneRouting` callback to request a tab switch. Route Kingdom in any stage only **after** the pending-result gate. Do not alter existing routing for Battle/Camp/Map requests.
- Ensure non-active Map enables `[.map, .kingdom]`; do not accidentally expose Battle/Camp in completed campaign. Battle/Camp can include Kingdom in their enabled tabs under the existing no-pending and active-squad guards. Do not bypass Battle's active-manual-squad guard when showing Kingdom.
- Update tests that assume three tabs / hardcoded icon count. Check four-tab 44-point hit targets at compact phone width and portrait iPad. Verify entry to Kingdom from each of the three prior scenes and countryComplete; test that a pending result still opens Battle first and a rejected tab selection doesn't dismiss the report.

**Checkpoint:** routing and tab tests pass; Kingdom scene may initially render a minimal testable shell.

### 4. Kingdom layout, scene and purchase UI

**Add** `Pyxis/KingdomLayout.swift`, `Pyxis/KingdomScene.swift`, `PyxisTests/KingdomLayoutTests.swift`, `PyxisTests/KingdomSceneTests.swift`.

- `KingdomLayout` computes a safe-area-aware title/gold header, three Treasury cards, Buy hit targets, Settings anchor and shared four-tab frame. Leave breathing room for future sections but only render live content. Return nil for an unsupported layout instead of overlapping hit targets.
- Build the scene with existing `PanelNode`, `GameUITheme`, `GameplayTabBarNode` and the common Feedback Settings gear/accessibility adapter. Keep node tree stable across redraws; on layout change recompute frames, don't create duplicate nodes.
- On `didMove` load the latest store state. Display name, current level, next effect (or MAX), current gold, price and enabled/disabled Buy state directly from the pure model. On tap, call `state.purchaseTreasuryUpgrade`; on success `store.save(state)` then redraw. On rejected purchase, redraw/brief feedback but never save a different gold balance.
- Use `UIImage(named:)`/existing SpriteKit asset lookup to test icon presence before using a texture, and otherwise render simple vector glyphs. Do not create final images; no SFX.
- Reuse existing lifecycle/inactive-building settlement behavior for a scene transition and foreground return, so that any newly pending conquest is routed to the standard Battle report, not consumed by Kingdom. Keep the controller as the sole scene router.
- Add accessibility ids for the header, each upgrade row and Buy action; verify disabled states and correct on-screen prices in scene tests.

**Checkpoint:** scene interaction tests, phone/iPad layout geometry tests, and navigation tests pass.

### 5. Campaign balance and regression evidence

**Modify only if necessary** `PyxisTests/Country1SiegeSmokeTests.swift` or its existing test-only helper. Do not make a second simulator.

- Record the opt-in zero-Treasury chained 15-city campaign run using `TEST_RUNNER_COUNTRY1_SMOKE_CAMPAIGN=1`; per-city log lines and City 15 completion should match the HPA-582 baseline within normal run variance.
- Seed Treasury `4/4/4` in the existing harness/test fixture, without gameplay-only DEBUG switches; record City 15 completion and any stalled city for comparison. **Before timing the chain, assert `GreedyCampBuyer.nextAction` quotes the discounted price and its selected actions are actually affordable under Quartermaster**, otherwise the comparison is biased by skipped purchases. The plan proposes a speed-up; use observed evidence before claiming one.
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
| Gold multiplied twice | Assert `BattleResult.goldEarned == creditedGold` in each conquest path |
| Trait + upgrade rounded twice | Static helper takes defaulted `upgradeMultiplier = 1`; assert base 9 × 0.80 × 1.05 yields 8 (not 7), plus live vs abstract parity |
| Static price call left behind | Sweep production **and `GreedyCampBuyer`** call sites; assert Camp + Recommended Camp + harness quotes equal purchase debit |
| Fourth tab steals home-indicator taps | Phone compact/iPad layout and enabled hit-frame containment |
| Completed-map hard route masks Kingdom | Controller `countryComplete` + `cityConqueredPendingMap` integration cases |
| Returning from Kingdom eats pending report | Foreground idle settlement and pending-first test |
