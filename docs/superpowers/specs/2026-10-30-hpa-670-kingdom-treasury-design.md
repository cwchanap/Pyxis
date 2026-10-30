# HPA-670 — Kingdom tab and Treasury: design

Status: proposed for the single HPA-670 implementation PR.
Backlog: https://linear.app/cwchanap/issue/HPA-670/gameplay-kingdom-tab-with-treasury-upgrades-that-persist-across-cities
Code reviewed against `main` at `516f20d873d7c3da3cfe794c662cb6717ab66b61` (2026-10-28).

## Problem and outcome

A conquest clears its `CityBattleState` and the camp must be rebuilt for the next city. Gold carries over, but there is no long-term use for it. Add one immediately useful Kingdom tab with three purchased, persistent bonuses. This is the prerequisite for HPA-671 (Equipment) and HPA-672 (Ascension), **not** their implementation. HPA-673 independently owns final imagery.

The player should be able to inspect the Kingdom and choose to spend saved gold at any point, including after City 15. Purchasing a bonus should make the *next* relevant battle/reward/build action stronger or cheaper without restarting the campaign.

## Player-facing contract

- A four-item shared tab bar: Battle, Camp, Map, Kingdom. Use the existing `GameplayTabBarNode` and forged `PanelNode` treatment. The Kingdom icon attempts `tab-kingdom` first and uses a vector crown/shield placeholder if the asset is absent. Existing three icons remain unchanged. Keep the small tab lookup in this implementation: HPA-673 is an **asset-only** ticket with no Swift changes, so its `tab-kingdom` image must become usable automatically when added later. Do not refactor the three existing tab glyphs.
- `KingdomScene` is a code-owned SpriteKit scene. It displays current gold and **exactly** three Treasury rows: icon, name, level/max, current → next effect, next purchase cost, and Buy. At max level, replace the next price with “MAX” and disable Buy; if unaffordable, show the cost with a disabled action. Readable “No upgrade” text is enough for Level 0. Keep touch targets at least 44 points.
- Treasury icons attempt `treasury-war-chest`, `treasury-drill-yard`, `treasury-quartermaster`. Missing images use simple type-specific vector glyphs; do not create or modify image assets in this ticket.
- Reuse the existing settings presentation/accessibility plumbing instead of creating a second settings control. Keep visual styling and safe-area handling consistent with the three existing scenes.
- `KingdomLayout` owns all critical frames as a pure CoreGraphics model (no SpriteKit/UIKit). It takes viewport and safe-area constraints and returns a valid layout or nil for unsupported sizes. Test reference phone, compact phone and portrait iPad. Reserve noninteractive space for future Armory/Ascension only if it does not crowd the three live Treasury rows; no dummy buttons or placeholder models.

## Navigation and lifecycle

`GameViewController.presentSceneForCurrentStage(in:preferredTab:)` remains the **only** stage/pending-result router. Preserve the current rules:

1. If `pendingBattleResult` exists, present Battle first, regardless of requested tab. Do not let Kingdom dismiss or consume the conquest report.
2. When no result is pending, `.kingdom` routes to `KingdomScene` in `battleActive`, `cityConqueredPendingMap` or `countryComplete`.
3. For non-Kingdom requests, keep today's routing behavior: in `battleActive` use requested Battle/Camp/Map; in non-active stages fall back to Map. The Map should enable Map and Kingdom in non-active stages without accidentally making Camp/Battle available.
4. Battle's existing manual-squad-exit guard still applies to Kingdom; avoid disappearing deployed soldiers merely to access the upgrade screen. Camp retains its settle-before-switch behavior. Reuse the existing inactive-building / foreground-settlement lifecycle; no separate combat clock or background scheduler in Kingdom.
5. A successful purchase persists through `KingdomGameStore`, immediately redraws the gold/rows, and is visible on return to other scenes. A rejected purchase never spends gold. A completed or pending city does not block a valid Treasury purchase, but routing still respects pending-first.

If entering or resuming Kingdom settles an idle conquest, persist that result and show the normal pending Battle report via the controller; never silently acknowledge it.

## Pure economy model

Add `TreasuryUpgrade: String, Codable, CaseIterable` with exactly three choices, and a small codable `TreasuryState` value containing the levels. Keep these in one separate pure Swift file rather than growing the already large `KingdomGameState.swift` with UI metadata.

| Upgrade | Base cost | Max level | Effect at level L |
| --- | ---: | ---: | --- |
| War Chest | 40 | 10 | Conquest gold × (1 + 0.10 × L) |
| Drill Yard | 50 | 10 | Soldier attack × (1 + 0.05 × L) |
| Quartermaster | 45 | 8 | Building build/upgrade price × (1 − 0.04 × L) |

- The price to buy the *next* level from current level L is `max(1, round(baseCost × 1.8^L))`. Use the project's existing nearest-integer rounding convention; all calculations clamp to valid positive integer costs.
- `KingdomGameState.purchaseTreasuryUpgrade(_:)` is the only purchase mutation and returns `TreasuryPurchaseResult`: `purchased(cost:newLevel:remainingGold:)`, `insufficientGold` or `maxLevel`. Check max level before affordability. On success subtract the computed price exactly once and increment exactly one level. No stage gate.
- New states default to level zero for all upgrades. Encode under one top-level `treasury` key. On decode, a missing or malformed key falls back to zero; any decoded level is clamped to `0...maxLevel`. Do not add schema versioning or a migration framework.

### One authoritative calculation seam per effect

**War Chest:** `currentGoldReward` is currently the common source for the reward passed into `finalizeConquestWhenKeepDestroyed` and then `BattleResult.goldEarned`. Fold War Chest in here, *not* in `completeCurrentCity(with:)` or the report. This keeps live, idle, and Camp-initiated settlement in agreement and prevents double award. `KingdomGameState.goldReward(for:)` remains the zero-upgrade base formula. At L=0, existing reward numbers are bit-for-bit unchanged.

**Drill Yard:** `KingdomGameState.traitAdjustedSoldierAttackPower(for:level:)` is used when live soldiers spawn and in `applyAbstractBuildingSpawnDamage`. **Preserve exactly one rounding step:** extend the existing static `traitAdjustedSoldierAttackPower(for:level:defenseTrait:)` with `upgradeMultiplier: Double = 1`; compute `round(baseAttack × defenseTraitMultiplier × upgradeMultiplier)` **inside the static helper**, and have the instance method pass its Drill Yard multiplier (`1 + 0.05 × level`). Do **not** multiply or round the already-rounded static result in the instance method. Default `1` preserves all existing static call sites and zero-Treasury behavior. An illustrative regression: base attack 9 × disadvantage 0.80 × Drill Yard level-1 1.05 = 7.56 → **8**, whereas rounding the trait first produces 7; test this difference explicitly. Keep the existing per-objective role multiplier and its *second* rounding step untouched (`SoldierType.roleAdjustedDamage`). Never recompute the power of already spawned live soldiers; their cached attack remains as spawned. Captain attack is not boosted.

**Quartermaster:** replace static price calls by state-aware `buildingBuildCost(for:)` and `buildingUpgradeCost(for:currentLevel:)` for the **player-facing** price. Keep the existing undiscounted formulas private as base helpers. Apply the percentage and round once; clamp to at least one gold. The same state-aware price must feed `buildBuilding`, `upgradeBuilding`, `BuildingViewScene` affordability, `CampSelectionContent.project` / `CampSelectionNode`, and `RecommendedCampRecommendation.make`, **plus the test-only `PyxisTests/GreedyCampBuyer.swift` campaign buyer**. That buyer currently quotes static prices and filters affordability against those quotes; it must use the same state-aware API or the 4/4/4 measurement will incorrectly skip affordable discounted purchases. Do not let the displayed cost, buyer's quote and deducted amount drift. A purchased discount never retroactively refunds a built structure.

Do not add a global stat modifier registry, effects event bus, second currency, a shared runtime scene, new persisted battle fields or runtime scripting.

## Edge decisions

- Price/level display is driven by `TreasuryState` and shared price functions, not duplicated calculations in the scene.
- Purchase is a simple atomic state mutation followed by the normal scene save; no new transaction layer.
- Existing saves and zero-level states continue to behave exactly as now.
- Since all Treasury multipliers are bounded, use normal `Double`/`Int` math and the project's positive rounding helper; no premature generic number/overflow infrastructure.
- When a building action settles an offline conquest before executing, the existing settlement result and pending report are preserved. The discounted quote shown before settlement remains consistent with the state at action start.
- Art and SFX belong to separate tasks; there is no new sound/haptic requirement.

## Evidence required before implementation is considered done

- Pure Swift Testing for cost progression, zero/max/insufficient-gold purchase paths, persistence defaults/clamping, and no accidental cross-city reset.
- Assert War Chest reward parity for a direct live conquest, idle progress, and Camp settlement. Verify `BattleResult.goldEarned` agrees with gold credited exactly once.
- Assert Drill Yard parity between newly spawned live soldiers and abstract idle damage; pin the exact 9 × 0.80 × 1.05 → 8 single-round case and unchanged soldier role rounding; old live soldiers retain cached power.
- Assert discounted quote equals charged price in both build and upgrade, including Camp selections, recommended camp, and `GreedyCampBuyer` affordability/action selection.
- `KingdomLayout` geometry and four tab hit-frame tests across phone/iPad, as well as controller tests from Battle, Camp and Map, post-City-15 access, and pending-first behavior.
- Run the existing opt-in chained 15-city smoke baseline with zero Treasury; it must remain unchanged. Add a small harness parameter/fixture for an illustrative mid-level `4/4/4` run, record the observed City 15 wall-clock and per-city evidence. Avoid hard-coding an assumed speed-up threshold.
- Build, lint, Swift Testing and relevant UI tests with `-parallel-testing-enabled NO`, following `CLAUDE.md`. This planning-only PR makes no claim to have run them.

## Scope guard

HPA-671: Equipment/Armory, drops and loadouts. HPA-672: Ascension, resets and Renown. HPA-673: final 20 icons. No features from these tickets should enter the HPA-670 implementation PR.
