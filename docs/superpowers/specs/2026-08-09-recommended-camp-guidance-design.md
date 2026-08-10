# HPA-365 Recommended Camp Guidance Design

## Goal

Reduce repetitive camp setup to one understandable preparation decision: show one deterministic `Recommended Camp` suggestion in Building View and let the player explicitly buy that exact action with one tap when affordable.

The feature must make the existing building system easier to use without creating a new strategy system, recommendation platform, or automatic spending path.

## Product constraints

- Keep every existing manual lot, build, upgrade, and Battle interaction available and behaviorally unchanged.
- Show exactly one recommendation state: `Ready`, `Save for`, or `No recommendation`.
- One tap may execute at most one ready build or upgrade.
- Opening Building View, waiting, backgrounding, resizing, or seeing the card never spends gold.
- An unaffordable preferred action remains the recommendation as `Save for`; never replace it with a cheaper neutral or later favorable action.
- Non-standard cities only recommend authored favorable soldier types.
- `Standard Watch` uses one explicit Infantry-first fallback.
- No persistence, planner/service/manager/protocol, score, strategy registry, multi-action optimization, or future extension framework.
- Execute purchases only through the existing `KingdomGameState.buildBuilding` / `upgradeBuilding` mutation and `BuildingViewScene` save/feedback paths.

## Reuse survey

The current code already owns every input needed by this feature:

- `KingdomGameState.currentCityDefenseTrait` supplies the current authored trait.
- `CityDefenseTrait.favorableSoldierTypes` supplies favorable soldier types in authored priority order.
- `BuildingType.soldierType` maps each current building to its soldier type.
- `KingdomGameState.isBuildingTypeUnlocked(_:)` owns unlock rules.
- `CityBattleState.slotRange`, `building(inSlot:)`, `buildingCount(for:)`, and `maxBuildingsPerType` own lot/cap state.
- `KingdomGameState.buildingBuildCost(for:)` and `buildingUpgradeCost(for:currentLevel:)` own prices.
- `BuildingViewScene.buildSelectedSlot(_:)` / `upgradeSelectedSlot()` already own mutation, persistence, settlement-conquest handling, and semantic feedback.

Do not duplicate any of those rules in a new subsystem.

## Design decision

Use one small framework-free pure value beside Building View:

```swift
enum RecommendedCampRecommendation: Equatable {
    struct Action: Equatable {
        enum Kind: Equatable {
            case build
            case upgrade
        }

        let kind: Kind
        let buildingType: BuildingType
        let slot: Int
        let cost: Int
    }

    case ready(action: Action, reason: String)
    case saveFor(action: Action, missingGold: Int, reason: String)
    case none(message: String)

    static func make(for state: KingdomGameState) -> RecommendedCampRecommendation
}
```

`RecommendedCampRecommendation` imports no SpriteKit/UIKit and owns only this ticket's deterministic projection and concise display copy. `BuildingViewScene` owns rendering and the explicit tap.

### Alternatives rejected

1. **Inline all policy in `BuildingViewScene`** — fewer files, but mixes the important deterministic rule with SpriteKit and makes the policy table harder to test directly.
2. **Put recommendation methods on `KingdomGameState`** — testable, but makes the campaign/economy model own a Building View assistance feature it does not need.
3. **Planner/service/protocol architecture** — no current second consumer; explicitly outside HPA-365 and the roadmap's current-consumer rule.

## Deterministic recommendation policy

### 1. Determine candidate soldier order

For an active city:

- `Standard Watch` -> `[.infantry]` as the documented starter fallback.
- Every other trait -> `currentCityDefenseTrait.favorableSoldierTypes` unchanged and in authored order.

Do not append neutral types. Do not inspect disadvantaged types as fallback candidates.

If `stageStatus != .battleActive`, return `No recommendation`.

### 2. Map each soldier to its existing building type

Resolve the building by the existing `BuildingType.allCases.first { $0.soldierType == soldierType }` relationship. Do not add a second soldier/building mapping table.

Skip a candidate whose building type is locked.

### 3. Derive one structural action for each candidate

Inspect candidates in order and stop at the first one with a structurally valid action.

For a candidate building type:

1. Find all existing buildings of that type, ordered by `(level, slot)` ascending.
2. If at least one exists, choose `upgrade` on the lowest-level building; ties use the lowest slot.
3. If none exists, choose `build` only when:
   - the type is unlocked,
   - its count is below `CityBattleState.maxBuildingsPerType`, and
   - an empty lot exists.
4. A build uses the lowest-numbered empty lot.

The per-type cap prevents an additional build; it does **not** prevent upgrading an already existing building because upgrades do not increase the type count.

If a candidate has no structural action, continue to the next authored favorable candidate. If all candidates fail, return `No recommendation`.

### 4. Affordability classifies the chosen action; it does not change it

After the first structural action is chosen:

- `state.gold >= action.cost` -> `Ready`.
- otherwise -> `Save for`, with `missingGold = action.cost - state.gold`.

Do not continue searching after an unaffordable preferred action. This preserves the first favorable action instead of replacing it with a weaker cheap purchase.

## Recommendation copy

Keep copy short and generated from the same value used for execution.

Examples:

- `Recommended Camp · Ready`
  - `Build Barracks · Lot 1 · 15g`
  - `Infantry is favored vs Arrow Tower.`
- `Recommended Camp · Save for`
  - `Upgrade Mage Tower · Lot 4 · 30g`
  - `Need 12g more · Mage is favored vs Stone Wall.`
- `Recommended Camp`
  - `No recommendation`
  - `No favorable camp action is available.`

For `Standard Watch`, the reason is `Infantry is the safe starter here.`

If a supported layout cannot fit one of these strings at the existing minimum label size, shorten the copy rather than introducing wrapping or a new text-layout framework.

## Building View presentation

Render one compact recommendation row at the top of the existing action panel.

Keep the current manual-control area anchored to the bottom exactly as today:

1. Treat the current `132 / 158 / 176` point action heights as `manualActionHeight` for very-short / compact / regular layouts.
2. Add one small recommendation row plus a fixed gap above that manual frame.
3. Grow `actionPanel` upward only; calculate existing feedback/build/upgrade/Battle controls from the unchanged bottom-anchored manual frame.
4. Reserve the new row from the scenic grid by moving only `gridBottom` upward.

The recommendation row uses the current theme and scene-owned SpriteKit nodes; no new reusable component is required. Reuse the current label fitting helper and expose the row frame through the existing DEBUG layout snapshot for acceptance tests.

`Ready` uses an enabled treatment and one hit frame covering the row. `Save for` and `No recommendation` are visually informational and do not execute or emit invalid-action feedback when tapped.

Settings/modal input keeps highest precedence. The recommendation row is checked before manual palette/upgrade/Battle/lot input, but its frame must not overlap those controls.

## Rendering lifecycle

`redraw()` recomputes `RecommendedCampRecommendation.make(for: state)` every time it refreshes the current scene. This naturally covers:

- initial Building View entry,
- a manual build or upgrade,
- a successful Recommended Camp purchase,
- idle/lifecycle settlement,
- a resize/redraw,
- gold or building changes already reflected in scene state.

Do not cache or persist a recommendation beyond the currently rendered scene value.

## Explicit purchase and stale-state rule

The rendered recommendation is only an offer. Immediately before a Ready tap spends anything:

1. Reload the current `KingdomGameState` from the existing store into the scene.
2. Recompute the recommendation from that fresh state.
3. Compare it with the currently rendered recommendation.
4. If it changed, redraw and return without mutation or invalid-action feedback.
5. If it is still the same `Ready` action, select its target slot and delegate exactly once:
   - `build` -> existing `buildSelectedSlot(_:)`
   - `upgrade` -> existing `upgradeSelectedSlot()`

Those methods remain authoritative for settlement-before-mutation, save-before-feedback ordering, conquest handling, and error feedback. Do not implement a second purchase path.

The fresh equality check is intentionally simple. If unrelated state changed but the same exact action is still Ready, it may proceed; if affordability, target slot, city state, or action changed, the tap becomes a refresh.

## Testing strategy

### Pure policy table

Add focused Swift Testing coverage for:

- Standard Watch Infantry build fallback.
- Ready vs Save-for for the same exact action.
- Existing favorable building -> upgrade instead of another build.
- Lowest-level then lowest-slot upgrade tie-break.
- Lowest empty lot for a build.
- Authored favorable order.
- Locked earlier favorable type -> next structurally valid favorable type.
- An unaffordable preferred action does not fall through to a later/cheaper candidate.
- A type already at the building-count cap is never proposed as another build; its existing lowest-level building may still be upgraded.
- No structurally valid favorable action -> No recommendation.
- Non-active stage -> No recommendation.
- Identical state -> identical value.

### Building View flow

Extend `BuildingViewSceneTests` with representative behavior, not a geometry matrix:

- Ready card displays the projected action/reason and has one enabled hit frame.
- Save-for / No-recommendation do not mutate state when tapped.
- Ready tap performs exactly one existing build/upgrade mutation, saves it, and recomputes the next card.
- Stale rendered card: mutate the store after render, tap the old Ready row, verify no second spend occurs and the card refreshes to the fresh suggestion.
- Existing manual build/upgrade/Battle/lot tests remain green.
- Existing supported layout fixtures verify the recommendation frame fits inside the action panel and does not overlap manual controls.

## Manual smoke

On the smallest supported portrait and landscape layouts:

1. Enter a Standard Watch city with an empty camp and confirm the Infantry starter suggestion.
2. Enter a counter-trait city and confirm the authored favorable type drives the card.
3. Verify `Save for` reports exact missing gold and remains inert.
4. Buy one Ready recommendation; verify one gold deduction, target lot/level change, feedback, and immediate next recommendation.
5. Use the manual palette, upgrade button, lot selection, Settings, and Battle controls to confirm they remain unchanged.
6. Background/foreground Building View and confirm catch-up may refresh the card but never auto-purchases.

## Risks

1. **Action-panel crowding** — preserve the existing manual frame and add one top row rather than reshuffling all controls; use current fit helpers and existing supported fixtures.
2. **Recommendation/purchase drift** — compare the fresh pure value against the rendered value immediately before delegating to the existing mutation path.
3. **Policy creep** — the function is first-valid favorable action only; no scoring, optimization, history, lane synthesis, or multi-buy planning.
4. **Cheap fallback changes the intended decision** — affordability only changes `Ready` to `Save for`; it never changes candidate selection.
5. **Duplicated gameplay rules** — resolve unlocks, caps, costs, trait order, and mutation results from existing model APIs only.

## Non-goals

- Automatic purchases or multiple actions per tap.
- Copying the previous city's camp.
- Neutral fallback purchases on non-standard cities.
- Lane-placement advice or combat simulation/scoring.
- New currencies, inventory, build queues, demolition/refunds, adjacency, production chains, or placement optimization.
- Recommendation persistence, analytics, history, explanation drill-down, localization framework, or reusable recommendation architecture.
- HPA-390 milestone presentation or HPA-567 campaign validation.