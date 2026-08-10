# HPA-365 Recommended Camp Guidance Design

## Goal

Reduce repetitive camp setup to one understandable preparation decision: show one deterministic `Recommended Camp` suggestion in Building View and let the player explicitly buy that exact action with one tap when affordable.

The feature must make the existing building system easier to use without creating a new strategy system, recommendation platform, or automatic spending path.

## Product constraints

- Keep every existing manual lot, build, upgrade, Settings, and Battle interaction available and behaviorally unchanged.
- Show exactly one recommendation state: `Ready`, `Save for`, or `No recommendation`.
- One tap may execute at most one Ready build or upgrade.
- Opening Building View, waiting, backgrounding, resizing, or seeing the card never spends gold.
- An unaffordable preferred action remains the recommendation as `Save for`; never replace it with a cheaper neutral or later favorable action.
- Non-standard cities only recommend authored favorable soldier types.
- `Standard Watch` uses one explicit Infantry-first fallback.
- The visible card is at most two single-line labels on every supported layout. Do not add a third stacked title/action/reason label.
- The whole recommendation row consumes its touches in all three states. Only a still-current `Ready` state may mutate; `Save for` and `No recommendation` are inert and must not fall through to lot selection or emit invalid-action feedback.
- No persistence, planner/service/manager/protocol, score, strategy registry, multi-action optimization, or future extension framework.
- Execute purchases only through the existing `KingdomGameState.buildBuilding` / `upgradeBuilding` mutation and `BuildingViewScene` save/feedback paths.

## Reuse survey

The current code already owns every input needed by this feature:

- `KingdomGameState.currentCityDefenseTrait` supplies the current authored trait.
- `CityDefenseTrait.favorableSoldierTypes` supplies favorable soldier types in authored priority order.
- `BuildingType.soldierType` maps each current building to its soldier type.
- `BuildingType.shortDisplayName` supplies compact existing building copy for the row.
- `KingdomGameState.isBuildingTypeUnlocked(_:)` owns unlock rules.
- `CityBattleState.slotRange`, `building(inSlot:)`, `buildingCount(for:)`, and `maxBuildingsPerType` own lot/cap state.
- `KingdomGameState.buildingBuildCost(for:)` and `buildingUpgradeCost(for:currentLevel:)` own prices.
- `BuildingViewScene.buildSelectedSlot(_:)` / `upgradeSelectedSlot()` already own mutation, persistence, settlement-conquest handling, and semantic feedback.
- `BuildingViewScene.fitLabel` and the existing DEBUG `BuildingLayoutFrames` snapshot already support compact scene-owned presentation testing.

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

`RecommendedCampRecommendation` imports no SpriteKit/UIKit and owns only this ticket's deterministic projection and concise reason/message copy. `BuildingViewScene` owns rendering and the explicit tap.

### Alternatives rejected

1. **Inline all policy in `BuildingViewScene`** — fewer files, but mixes the important deterministic rule with SpriteKit and makes the policy table harder to test directly.
2. **Put recommendation methods on `KingdomGameState`** — testable, but makes the campaign/economy model own a Building View assistance feature it does not need.
3. **Planner/service/protocol architecture** — no current second consumer; explicitly outside HPA-365 and the roadmap's current-consumer rule.
4. **New pure layout type / `RecommendedCampNode`** — unnecessary for one two-line row; extend the existing scene layout and DEBUG snapshot instead.

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

The current Country 1 catalog has no city where an earlier favorable type is locked while a later favorable type is usable. Tests therefore must not invent a synthetic trait/unlock seam just to exercise that impossible ordering. City 6 (`Stone Wall`: Mage, Siege) is the concrete lock case because both favorable buildings are still locked there; it must produce `No recommendation`, never the Standard Watch Infantry fallback.

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

The per-type cap prevents an additional build; it does **not** prevent upgrading an already existing building. `upgradeBuilding` has no maximum-level rule, so HPA-365 must not invent one. A fixture with five buildings of the favored type still recommends the lowest `(level, slot)` upgrade.

If a candidate has no structural action, continue to the next authored favorable candidate. If all candidates fail, return `No recommendation`.

### 4. Affordability classifies the chosen action; it does not change it

After the first structural action is chosen:

- `state.gold >= action.cost` -> `Ready`.
- otherwise -> `Save for`, with `missingGold = action.cost - state.gold`.

Do not continue searching after an unaffordable preferred action. This preserves the first favorable action instead of replacing it with a weaker cheap purchase.

## Recommendation copy and two-line packing

The card has exactly two single-line labels: `primary` and `secondary`. There is no separate third title label.

Use compact existing names (`BuildingType.shortDisplayName`) and preserve the player facts rather than adding wrapping or another text-layout abstraction.

Examples:

- Ready
  - primary: `Recommended Camp · Ready`
  - secondary: `Build Barracks · Lot 1 · 15g · Infantry starter`
- Save for
  - primary: `Recommended Camp · Save for`
  - secondary: `Upgrade Mage · Lot 4 · Need 12g · Mage favored`
- No recommendation
  - primary: `Recommended Camp`
  - secondary: `No favorable camp action available.`

Reason phrases stay intentionally compact:

- `Standard Watch`: `Infantry starter`
- favorable type: `<Soldier> favored`

`Ready` must still show build/upgrade, target lot, exact cost, and one reason. `Save for` must still show the preferred action, target lot, and exact missing gold. If a supported fixture would make either label smaller than 10 pt after the existing `fitLabel` behavior, shorten the copy while preserving those facts; do not add wrapping, scrolling, or a new layout engine.

## Building View presentation

Treat the action panel as two vertical regions, bottom anchored as one panel:

```text
actionPanel (grows upward)
  [recommendation row: two labels]
  [small fixed gap]
  [manual region: same height and bottom-relative geometry as today]
    feedbackLabel
    build palette row 1
    build palette row 2
    upgrade | Battle
```

The existing `132 / 158 / 176` point action heights become `manualActionHeight` for very-short / compact / regular layouts. The recommendation row uses `28 / 36 / 40` points, with a `4` point gap in very-short landscape and `6` points otherwise. This reduces the short-landscape grid loss compared with the earlier three-line `36 / 44 / 48` proposal.

Keep the current manual-control absolute positions by calculating them from the unchanged manual region:

- `feedbackLabel` -> `manualActionCenterY + manualActionHeight * 0.33`
- palette top -> `manualActionCenterY + manualActionHeight * 0.13`
- upgrade/Battle -> `manualActionCenterY - manualActionHeight * 0.34`

Do **not** reuse the enlarged `actionCenterY` / `actionHeight` fractions for those controls; that would move the manual UI and collide with the new row.

Keep `actionPanel` bottom anchored at the current `bottomMargin` and grow it upward. Place the recommendation row immediately above the manual region. Move only `gridBottom` to the enlarged action panel top plus the existing panel/grid gap.

The row uses scene-owned `SKShapeNode` + two `SKLabelNode`s and existing theme/Z-order. Expose the row frame and both label font sizes through the existing DEBUG snapshot/hooks for focused acceptance tests. No new reusable node or layout type.

### Short-landscape acceptance

The existing `568 x 320` fixture is the packing gate. It must assert:

- recommendation row contained by `actionPanel`;
- recommendation row above `feedbackLabel` / manual region;
- no intersection with build/upgrade/Battle controls;
- grid remains non-empty and between panels;
- both recommendation labels remain at least 10 pt after fitting.

Reuse the existing compact landscape and portrait fixtures for containment/non-overlap. Do not create a new exhaustive geometry matrix.

## Input behavior

Settings/modal input keeps highest precedence. Then the recommendation row is checked before palette/upgrade/Battle/lot input.

Use one hit frame for all three recommendation states:

```swift
if recommendationRowContains(point) {
    activateRecommendedCamp()
    return
}
```

That `return` is required even for `Save for` and `No recommendation`. Their taps are intentionally inert: no gold change, no building mutation, no `.invalidAction`, no route, and no selected-lot change. Without the unconditional consume, the current final lot-selection branch could receive a tap that visually belongs to the card.

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

The rendered recommendation is only an offer. Immediately before any recommendation-row tap can spend anything:

1. Reload the current `KingdomGameState` from the existing store into the scene.
2. Recompute the recommendation from that fresh state.
3. Compare it with the currently rendered recommendation.
4. If it changed, redraw and return without mutation or invalid-action feedback.
5. If it is unchanged but is `Save for` / `No recommendation`, redraw and return without mutation.
6. If it is still the same `Ready` action, select its target slot and delegate exactly once:
   - `build` -> existing `buildSelectedSlot(_:)`
   - `upgrade` -> existing `upgradeSelectedSlot()`

Those methods remain authoritative for settlement-before-mutation, save-before-feedback ordering, conquest handling, and error feedback. Do not implement a second purchase path.

The fresh equality check is intentionally simple. If unrelated state changed but the same exact action is still Ready, it may proceed; if affordability, target slot, city state, or action changed, the tap becomes a refresh.

## Test fixture contract

`KingdomGameState.init` normalizes an active city to `completedCityCount + 1`. A helper that sets only `cityNumberInCountry` silently falls back to City 1, so every multi-city pure-policy fixture must seed progression consistently:

```swift
private func makeState(
    city: Int,
    gold: Int,
    cityState: CityBattleState = CityBattleState()
) -> KingdomGameState {
    let key = CityKey(countryNumber: 1, cityNumber: city)
    return KingdomGameState(
        gold: gold,
        cityNumberInCountry: city,
        completedCityCount: city - 1,
        cityBattleStates: [key.storageKey: cityState]
    )
}
```

Pin policy tests to real current catalog cases:

- City 1 — `Standard Watch`, Infantry fallback.
- City 5 — `Arrow Tower`, authored order `[Infantry, Cavalry]`; both buildings are unlocked. Use this for first-candidate order and Save-for non-substitution.
- City 6 — `Stone Wall`, `[Mage, Siege]`; both are locked, so an empty camp is `No recommendation` and does not fall back to Infantry.
- Five Barracks on City 5 — cap is reached for builds, but the lowest `(level, slot)` Barracks upgrade remains valid.

Do not add a production trait/unlock injection seam solely to manufacture an “earlier locked, later unlocked” case that the current catalog cannot produce.

## Testing strategy

### Pure policy table

Add focused Swift Testing coverage for:

- City 1 Standard Watch Infantry build fallback.
- Ready vs Save-for for the same exact action.
- City 5 authored favorable order chooses Infantry/Barracks before Cavalry/Stable.
- City 5 unaffordable Barracks upgrade remains Save-for even when a Stable build would be affordable.
- Existing favorable building -> upgrade instead of another build.
- Lowest-level then lowest-slot upgrade tie-break.
- Lowest empty lot for a build.
- Five favored buildings -> still upgrade the lowest `(level, slot)`; do not invent a max level.
- City 6 all favorable types locked -> No recommendation, with no Standard Watch fallback.
- Full/no-empty-lot structural failure -> No recommendation when no candidate has an action.
- Non-active stage -> No recommendation.
- Identical state -> identical value.

### Building View flow

Extend `BuildingViewSceneTests` with representative behavior:

- Ready/Save-for/No-recommendation render through the same two-label row.
- Ready tap performs exactly one existing build/upgrade mutation, saves it, and recomputes the next card.
- Stale rendered card refreshes without a second spend.
- Save-for / No-recommendation taps are swallowed: state unchanged, no invalid feedback, selected slot unchanged.
- Settings keeps precedence over recommendation touches.
- `568 x 320` short landscape keeps both labels >= 10 pt and preserves row/manual/grid separation.
- Existing compact landscape/portrait and manual control tests remain green.

## Manual smoke

On the smallest supported portrait and landscape layouts:

1. Enter City 1 with an empty camp and confirm the Infantry starter suggestion.
2. Enter City 5 and confirm Infantry is preferred before Cavalry.
3. Enter City 6 with an empty camp and confirm there is no recommendation because Mage/Siege are locked; no Infantry fallback appears.
4. Verify `Save for` reports exact missing gold and its row tap changes neither gold nor selected lot.
5. Buy one Ready recommendation; verify one gold deduction, target lot/level change, existing feedback, and immediate next recommendation.
6. Use the manual palette, upgrade button, lot selection, Settings, and Battle controls to confirm they remain unchanged.
7. Background/foreground Building View and confirm catch-up may refresh the card but never auto-purchases.

## Risks

1. **Short-landscape crowding** — two labels only, smaller row heights, frozen manual-region geometry, and a 10 pt readability gate on `568 x 320`.
2. **Recommendation/manual-control collision** — all legacy feedback/palette/upgrade/Battle positions derive from the unchanged manual region, never the enlarged action-panel fractions.
3. **Recommendation/purchase drift** — compare the fresh pure value against the rendered value immediately before delegating to the existing mutation path.
4. **Informational-card fallthrough** — one row hit frame always consumes touches; Save-for/None never reach the lot branch.
5. **Fixture false greens** — active City N fixtures must set `completedCityCount = N - 1`.
6. **Policy creep** — the function is first-valid favorable action only; no scoring, optimization, history, lane synthesis, or multi-buy planning.
7. **Duplicated gameplay rules** — resolve unlocks, caps, costs, trait order, and mutation results from existing model APIs only.

## Non-goals

- Automatic purchases or multiple actions per tap.
- Copying the previous city's camp.
- Neutral fallback purchases on non-standard cities.
- Lane-placement advice or combat simulation/scoring.
- New currencies, inventory, build queues, demolition/refunds, adjacency, production chains, or placement optimization.
- Recommendation persistence, analytics, history, explanation drill-down, localization framework, or reusable recommendation architecture.
- New recommendation layout/component types.
- HPA-390 milestone presentation or HPA-567 campaign validation.