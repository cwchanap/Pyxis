# HPA-670 — Kingdom tab and Treasury: design

Status: proposed for the single HPA-670 implementation PR.
Backlog: https://linear.app/cwchanap/issue/HPA-670/gameplay-kingdom-tab-with-treasury-upgrades-that-persist-across-cities
Code reviewed against `main` at `516f20d873d7c3da3cfe794c662cb6717ab66b61` (2026-10-28).

## Problem and outcome

A conquest clears its `CityBattleState` and the camp must be rebuilt for the next city. Gold carries over, but there is no long-term use for it. Add one immediately useful Kingdom tab with three purchased, persistent bonuses. This is the prerequisite for HPA-671 (Equipment) and HPA-672 (Ascension), **not** their implementation. HPA-673 independently owns final imagery.

The player should be able to inspect the Kingdom and choose to spend saved gold at any point, including after City 15. Purchasing a bonus changes the shared combat/reward/build formula immediately without restarting the campaign; because attack is stored as a rounded integer, a small Drill Yard bonus may not increase the next soldier's actual damage.

## Player-facing contract

- A four-item shared tab bar: Battle, Camp, Map, Kingdom. Use the existing `GameplayTabBarNode` and forged `PanelNode` treatment. The Kingdom icon attempts `tab-kingdom` first and uses a vector crown/shield placeholder if absent. HPA-673 is **asset-only**, so implement the sprite path **here**: fixed visual size in both forged/standard appearances, selected/disabled alpha, appropriate tint/color blending in forged mode, and test hooks accepting `SKShapeNode` or `SKSpriteNode`. Existing three icons remain vector glyphs; do not refactor their rendering.
- `KingdomScene` is a code-owned SpriteKit scene. It displays current gold and **exactly** three Treasury rows: icon, name, level/max, current → next effect, next purchase cost, and Buy. At max level, replace next price with “MAX” and disable Buy; if unaffordable, display the disabled cost. Drill Yard also shows one compact **rounded attack example**: “Infantry Lv N vs this city's trait: P → Q attack”, using the current state's Infantry level and trait, labeled as an example rather than a guarantee for every soldier. If P == Q, say “no damage change yet”; never imply the +5% always changes an integer hit. Keep touch targets at least 44 points.
- Treasury icons attempt `treasury-war-chest`, `treasury-drill-yard`, `treasury-quartermaster`. Missing images use **one shared vector placeholder glyph**, with text differentiating upgrades; do not generate art or write three bespoke paths.
- Reuse the existing settings presentation/accessibility plumbing instead of creating a second settings control. Keep visual styling and safe-area handling consistent with the three existing scenes.
- `KingdomLayout` owns all critical frames as a pure CoreGraphics model (no SpriteKit/UIKit). It takes viewport and safe-area constraints and returns a valid layout or nil. Reuse the pure `BattleChromeLayout.tabHitFramesInSafeArea` function (make it internal) to compute the new scene's four tab hit frames rather than copying that math; leave existing Map/Camp layouts alone. Test compact/reference phones and portrait iPad. Reserve noninteractive space for future sections only if three live Treasury rows still fit; no dummy controls.

## Navigation and lifecycle

`GameViewController.presentSceneForCurrentStage(in:preferredTab:)` remains the **only** stage/pending-result router. Preserve the current rules:

1. If `pendingBattleResult` exists, present Battle first, regardless of requested tab. Do not let Kingdom dismiss or consume the conquest report.
2. When no result is pending, `.kingdom` routes to `KingdomScene` in `battleActive`, `cityConqueredPendingMap` or `countryComplete`.
3. For non-Kingdom requests, keep today's routing behavior: in `battleActive` use requested Battle/Camp/Map; in non-active stages fall back to Map. The Map should enable Map and Kingdom in non-active stages without accidentally making Camp/Battle available.
4. Battle's existing manual-squad-exit guard still applies to Kingdom; do not discard deployed soldiers to reach upgrades. Camp keeps settle-before-switch. Kingdom mirrors Map's inactive-building, background/foreground and layout-gate settlement **behavior** with focused tests; do **not** refactor existing Map/Camp scene-specific intent/notification routing into generic state methods as part of HPA-670.
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

**War Chest:** rename the existing static `goldReward(for:)` to `baseGoldReward(for:)` for the zero-Treasury formula. Add `state.goldReward(forCity:)` which computes the War Chest-adjusted price of *any scouted city*, rounding once; make `currentGoldReward` delegate to `goldReward(forCity: cityLevel)` and `CountryMapScoutCardContent.project(from:)` use `state.goldReward(forCity: cityNumber)`. `finalizeConquestWhenKeepDestroyed` and `BattleResult.goldEarned` continue consuming only `currentGoldReward`; do **not** multiply rewards at `completeCurrentCity(with:)`, report, or elsewhere. This keeps Map Scout, Battle HUD, live, idle and Camp settlements consistent. At zero Treasury, the base formula and values are unchanged.

**Drill Yard — decision: retain the ticket's +5% per level, with an honest effective-damage preview rather than changing its pricing/multiplier before paid-campaign evidence.** `KingdomGameState.traitAdjustedSoldierAttackPower(for:level:)` remains the shared live/abstract seam. Extend static `traitAdjustedSoldierAttackPower(for:level:defenseTrait:)` with `upgradeMultiplier: Double = 1` and compute `round(baseAttack × traitMultiplier × upgradeMultiplier)` **once** inside it; the instance wrapper passes `1 + 0.05 × drillYardLevel`. Do not round the static result again; retain the separate existing role adjustment round. Cached live soldiers and Captain remain unchanged. At base attacks 1–3 (early camps), several paid levels can produce **no effective integer gain**; the Kingdom row must display a current→next rounded example and say so when unchanged. Keep the illustrative 9 × 0.80 × 1.05 → 8 single-round test, but **also** test the actual `ceil(1.38^(level−1))` curve at reachable soldier levels 1...8 for neutral, 0.80 and 1.25 traits across Drill Yard levels 0...10; explicitly pin where purchases have zero or nonzero visible attack effect. Record the paid-run result before deciding whether to propose a *separate* balance change. A `level + drillYardLevel` alternative is not adopted: the existing ceiling curve has repeated values (L2 and L3 both attack 2), so even that alternative would not make every purchase immediately visible.

**Quartermaster:** rename static `buildingBuildCost` and `buildingUpgradeCost` to `baseBuildingBuildCost(for:)` and `baseBuildingUpgradeCost(for:currentLevel:)` so old call sites **fail compilation** and must choose base vs discounted explicitly. Expose state-aware `buildingBuildCost(for:)` and `buildingUpgradeCost(for:currentLevel:)` as the only charged/quoted prices. Apply the percentage once, round once and clamp to ≥1. Replace all use sites in `buildBuilding`, `upgradeBuilding`, `BuildingViewScene` affordability, `CampSelectionContent.project` / `CampSelectionNode`, `RecommendedCampRecommendation.make` and test-only `PyxisTests/GreedyCampBuyer.swift`. Its candidate filter must use discounted prices, or the 4/4/4 chain skips affordable purchases. Quote must equal actual debit for UI, recommendation and buyer; no retroactive refunds. Base formula-pin tests should explicitly use the renamed `base*` helpers.

Do not add a global stat modifier registry, effects event bus, second currency, a shared runtime scene, new persisted battle fields or runtime scripting.

### Economy measurement and max-level expectation

- The four levels in each track cost **1,603 gold in aggregate** at starting prices (War Chest 475, Drill Yard 594, Quartermaster 534). A free seeded 4/4/4 simulation measures potential speed-up, **not** affordability or ROI. Keep that comparison, but add a **bought** simulation which buys only affordable Treasury upgrades before buying Camp at each city entry, using real purchase mutations and recorded Treasury levels/spend.
- The current 15-city reward curve may not fund max levels within one run. This is intentional as a **measurement question**, not a promise of reachability: HPA-672 resets Treasury upon Ascension but adds Renown-gold scaling. If the bought run shows no useful upgrade progression or stalls, revise values based on evidence **within HPA-670 before merging**, rather than adding a new economy system.

## Edge decisions

- Price/level display is driven by `TreasuryState` and shared price functions, not duplicated calculations in the scene.
- Purchase is a simple atomic state mutation followed by the normal scene save; no new transaction layer.
- Existing saves and zero-level states continue to behave exactly as now.
- Since all Treasury multipliers are bounded, use normal `Double`/`Int` math and the project's positive rounding helper; no premature generic number/overflow infrastructure.
- When a building action settles an offline conquest before executing, the existing settlement result and pending report are preserved. The discounted quote shown before settlement remains consistent with the state at action start.
- Art and SFX belong to separate tasks; there is no new sound/haptic requirement.

## Evidence required before implementation is considered done

- Pure Swift Testing for cost progression, zero/max/insufficient-gold purchase paths, persistence defaults/clamping, and no accidental cross-city reset.
- Assert War Chest reward parity across Map scout card quote, Battle HUD, direct live conquest, idle progress and Camp settlement. Verify `BattleResult.goldEarned` equals gold credited exactly once and that `baseGoldReward(for:)` is not used to display player-facing quotes.
- Assert Drill Yard parity between new live spawns and abstract idle damage, pin the 9 × 0.80 × 1.05 → 8 one-round example **and reachable-level 1...8 × all three traits × DY 0...10** visibility table, preserve role rounding and old live soldiers' cached attack; check the illustrative Infantry effective attack preview.
- Assert discounted quote equals charged price in both build and upgrade, including Camp selections, recommended camp, and `GreedyCampBuyer` affordability/action selection.
- `KingdomLayout` geometry, four tab hit frames, image-asset sprite sizing/tint/alpha and fallback testing across phone/iPad, plus controller tests from Battle, Camp and Map, post-City-15 access and pending-first behavior.
- Run the existing opt-in chained 15-city smoke baseline with zero Treasury. Compare **three variants**: baseline, free seeded `4/4/4` (power ceiling), and a **bought** variant (real affordability) which buys the cheapest affordable Treasury level before each city's Camp purchases. Log each city's `treasury=a/b/c` levels, Treasury spend, camp spend and any stall. Record observed City 15 times; do not hard-code an assumed speed-up threshold.
- Build, lint, Swift Testing and relevant UI tests with `-parallel-testing-enabled NO`, following `CLAUDE.md`. This planning-only PR makes no claim to have run them.

## Scope guard

HPA-671: Equipment/Armory, drops and loadouts. HPA-672: Ascension, resets and Renown. HPA-673: final 20 icons. No features from these tickets should enter the HPA-670 implementation PR.
