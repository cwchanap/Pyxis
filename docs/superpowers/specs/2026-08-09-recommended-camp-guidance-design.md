# HPA-365 Recommended Camp Guidance Design

## Goal

Reduce repetitive camp setup to one understandable preparation decision: show one deterministic `Recommended Camp` suggestion in Building View and let the player explicitly buy that exact action with one tap when affordable.

The feature makes the existing building system easier to use. It is not an optimizer, recommendation platform, or automatic-spending system.

## Product constraints

- Keep every existing manual lot, build, upgrade, Settings, and Battle interaction available.
- Show exactly one recommendation state: `Ready`, `Save for`, or `No recommendation`.
- One tap may execute at most one Ready build or upgrade.
- Opening Building View, waiting, backgrounding, resizing, or merely seeing/tapping an informational recommendation never spends gold.
- An unaffordable preferred action remains `Save for`; do not substitute a cheaper neutral or later favorable action.
- Non-standard cities only recommend authored favorable soldier types.
- `Standard Watch` alone uses the documented Infantry-first starter fallback.
- The visible recommendation uses exactly two single-line labels.
- The whole recommendation row consumes touches in every state. Only a still-current `Ready` state may mutate.
- No persistence, planner/service/manager/protocol, score, strategy registry, multi-action optimization, reusable recommendation component, or future extension framework.
- Execute purchases only through the existing `BuildingViewScene.buildSelectedSlot(_:)` / `upgradeSelectedSlot()` paths.

## Reuse survey

The current code already owns every rule and primitive this feature needs:

- `KingdomGameState.currentCityDefenseTrait` supplies the active authored trait.
- `CityDefenseTrait.favorableSoldierTypes` supplies favorable soldier types in authored order.
- `BuildingType.soldierType` maps current buildings to soldier types.
- `BuildingType.shortDisplayName` supplies compact row copy.
- `KingdomGameState.isBuildingTypeUnlocked(_:)` owns unlock rules.
- `CityBattleState.slotRange`, `building(inSlot:)`, `buildingCount(for:)`, and `maxBuildingsPerType` own lot/cap state.
- `KingdomGameState.buildingBuildCost(for:)` and `buildingUpgradeCost(for:currentLevel:)` own prices.
- `BuildingViewScene.buildSelectedSlot(_:)` / `upgradeSelectedSlot()` own settlement-before-mutation, persistence, conquest-during-settlement handling, and semantic feedback.
- Existing `fitLabel`, scene-owned nodes, and DEBUG `BuildingLayoutFrames` are sufficient for the row.

Do not duplicate those rules in a new subsystem.

## Feature-local pure projection

Use one framework-free pure value beside Building View:

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
    case noAction(message: String)

    static func make(for state: KingdomGameState) -> RecommendedCampRecommendation
}
```

Use `noAction`, not `none`, so code holding `RecommendedCampRecommendation?` never has ambiguous-looking `.none` cases.

`RecommendedCampRecommendation` imports no SpriteKit/UIKit. It owns only this ticket's deterministic projection and compact reason/message copy. `BuildingViewScene` owns rendering and explicit input.

### Alternatives rejected

1. **Inline all policy in `BuildingViewScene`** — fewer files, but mixes the important deterministic rule with SpriteKit and makes the policy table harder to test directly.
2. **Put recommendation methods on `KingdomGameState`** — testable, but makes the campaign/economy model own a Building View assistance feature it does not need.
3. **Planner/service/protocol/scoring architecture** — no second consumer and no evidence that Pyxis needs optimization machinery.
4. **Reusable `RecommendedCampNode` or pure layout type** — unnecessary for one two-line row; extend the existing scene directly.

## Deterministic recommendation policy

### 1. Candidate soldier order

For an active city:

- `Standard Watch` -> `[.infantry]` as the explicit starter fallback.
- Every other trait -> `currentCityDefenseTrait.favorableSoldierTypes` unchanged and in authored order.

Do not append neutral types or inspect disadvantaged types as fallback candidates.

If `stageStatus != .battleActive`, return `noAction`.

### 2. Map candidates through existing building types

Resolve the building type via:

```swift
BuildingType.allCases.first { $0.soldierType == soldierType }
```

Do not add another soldier/building mapping table. Skip locked candidate building types using `state.isBuildingTypeUnlocked(_:)`.

Country 1 can contain locked entries later in a favorable list. City 7 is the concrete example: Burning Oil orders `[Archer, Mage, Cavalry]`; Mage is still locked while Cavalry is unlocked. That does not affect the current chosen result because Archer is first and unlocked. The implementation must nevertheless keep the generic locked-candidate skip rather than treating the current catalog shape as a permanent invariant.

City 6 (`Stone Wall`: Mage, Siege) is the useful all-locked regression: both favorable buildings are unavailable there, so an empty camp returns `noAction` rather than the Standard Watch Infantry fallback.

### 3. Derive the first structural action

Inspect candidate types in authored order and stop at the first candidate with a structural action.

For one candidate building type:

1. Find existing buildings of that type ordered by `(level, slot)` ascending.
2. If at least one exists, choose `upgrade` on the lowest-level building; ties use the lowest slot.
3. If none exists, choose `build` only when the type is unlocked, under `CityBattleState.maxBuildingsPerType`, and an empty lot exists.
4. A build uses the lowest-numbered empty lot.

The type-count cap blocks another build only. `upgradeBuilding` has no maximum-level rule, so HPA-365 must not invent one.

If the candidate has no structural action, continue to the next authored favorable candidate. If every candidate fails, return `noAction`.

### Why upgrade-first remains the policy

HPA-365 deliberately keeps the ticket's simple structural rule: once a favored building exists, strengthen its lowest-level instance before introducing another copy. This is guidance, not a damage-per-gold optimizer.

The current game does not support the review claim that a new building is strictly better than an upgrade:

- soldier attack power is integer-ceiled by level (`1 -> 2 -> 2 -> 3 ...`), not a continuous `+0.38` curve;
- soldier HP also scales by level (`1.25^(level-1)`), so an upgrade can improve survivability even when attack rounds to the same integer;
- a new building adds an additional spawn source, while an upgrade strengthens each future spawn from one source.

Those are different benefits, with no existing scalar score that proves one dominates the other. Adding such a score would turn this compact guidance slice into the optimization system HPA-365 explicitly rejects.

Therefore the policy does **not** claim economic optimality. If the Country 1 validation checkpoint later shows players are being misled by upgrade-first guidance, revise the heuristic from playtest evidence rather than adding speculative scoring now.

### 4. Affordability classifies; it never reselects

Once the first structural action is chosen:

- `state.gold >= action.cost` -> `Ready`.
- otherwise -> `Save for`, with `missingGold = action.cost - state.gold`.

Do not search for a cheaper later candidate after selecting an unaffordable preferred action.

## Recommendation copy

Use exactly two single-line labels: `primary` and `secondary`.

Pinned copy shapes:

- Ready
  - primary: `Recommended Camp · Ready`
  - secondary: `Build Barracks · Lot 1 · 15g · Infantry starter`
- Save for
  - primary: `Recommended Camp · Save for`
  - secondary: `Upgrade Mage · Lot 4 · Need 12g · Mage favored`
- No recommendation
  - primary: `Recommended Camp`
  - secondary: `No favorable camp action available.`

Reason phrases are intentionally short:

- `Standard Watch`: `Infantry starter`
- favorable type: `<Soldier> favored`

Use `BuildingType.shortDisplayName`. Keep the pinned copy authoritative; do not add a vague "shorten it if needed" escape hatch. Existing `fitLabel` may shrink horizontally within its current floor, but layout tests must prove both label frames remain contained by the row and do not overlap each other.

## Building View presentation

### Fixed panel height; repack inside it

Do **not** grow the action panel upward. Keep today's action-panel heights unchanged:

- very short landscape: `132`
- compact: `158`
- regular: `176`

This preserves the existing scenic-grid budget at `568 x 320` and `667 x 375` instead of squeezing slot centers while `minimumSlotSize` is already at its floor.

Carve the recommendation row out of the existing panel by repacking the four vertical bands inside the same height:

```text
actionPanel (same height as today)
  [recommendation row: two labels]
  [feedback label]
  [build palette row 1]
  [build palette row 2]
  [upgrade | Battle]
```

Use scene-local constants only; do not add another layout type.

Recommended dimensions:

- recommendation height: `28 / 32 / 36` for very-short / compact / regular;
- panel vertical inset: `2 / 4 / 4`;
- inter-control gap: `4 / 5 / 5`.

Pack from the panel bottom upward:

1. Upgrade/Battle row.
2. Palette row 2.
3. Palette row 1.
4. Feedback label in the remaining band between palette row 1 and the recommendation row.
5. Recommendation row pinned to the panel top inset.

The old fractional Y formulas are no longer authoritative after HPA-365 because the additional band cannot fit without repacking. What remains invariant is behavior and non-overlap, not the exact pre-HPA-365 pixel centers.

### Geometry acceptance

Extend the existing DEBUG snapshot with:

- `recommendationRow`
- `recommendationPrimaryLabel`
- `recommendationSecondaryLabel`
- existing manual control frames

For **both** existing landscape gates (`568 x 320` and `667 x 375`), assert:

- `actionPanel` height is unchanged from today's fixture;
- recommendation row is contained by `actionPanel`;
- recommendation row does not intersect feedback, palette, Upgrade, or Battle;
- primary and secondary label frames are both contained by the row;
- primary and secondary label frames do not intersect;
- grid union remains non-empty, above `actionPanel`, and does not intersect the recommendation row.

Reuse existing portrait fixtures for containment and text fit. Do not add a new exhaustive geometry matrix.

The previous `fontSize >= 10` short-landscape gate is removed because width is generous there and that assertion does not test the real failure mode. Label-frame containment/non-overlap is authoritative.

## Input behavior

Settings/modal input keeps highest precedence. Then the recommendation row is checked before palette/Upgrade/Battle/lot input.

Use one hit frame in all states:

```swift
if recommendationRowContains(point) {
    activateRecommendedCamp()
    return
}
```

That `return` is unconditional. `Save for` and `noAction` taps do nothing: no gold change, building mutation, invalid feedback, route, or selected-lot change.

## Rendering lifecycle

`redraw()` recomputes `RecommendedCampRecommendation.make(for: state)` whenever Building View refreshes:

- initial entry,
- manual build or upgrade,
- successful Recommended Camp purchase,
- idle/lifecycle settlement,
- redraw/resize after current state changes.

Do not persist or cache recommendation state beyond the value currently rendered by the mounted scene.

## Explicit purchase and revalidation

The visible recommendation is only an offer. On a recommendation-row tap:

1. Recompute from the scene's current `state`.
2. Compare that fresh value with `renderedRecommendation`.
3. If it differs, redraw and return without spending.
4. If it is unchanged but `Save for` / `noAction`, return without mutation.
5. If it is the same `Ready` action, select its target slot and delegate exactly once:
   - `build` -> `buildSelectedSlot(_:)`
   - `upgrade` -> `upgradeSelectedSlot()`

Do not reload `KingdomGameStore` solely for this guard. Every current Building View mutation/lifecycle path updates the scene's local state and saves through the same mounted scene; there is no current second writer that can make the store legitimately ahead while this scene is active. The recompute-and-compare is enough for the current consumer and avoids an artificial external-writer test.

## Test fixture contract

`KingdomGameState.init` normalizes active play to `completedCityCount + 1`, so multi-city fixtures must seed progression consistently:

```swift
private func makeState(
    city: Int,
    gold: Int,
    cityState: CityBattleState = CityBattleState(),
    stageStatus: KingdomGameState.StageStatus = .battleActive
) -> KingdomGameState {
    let key = CityKey(countryNumber: 1, cityNumber: city)
    return KingdomGameState(
        gold: gold,
        cityNumberInCountry: city,
        completedCityCount: city - 1,
        stageStatus: stageStatus,
        cityBattleStates: [key.storageKey: cityState]
    )
}
```

Pin policy tests to current catalog cases:

- City 1 — Standard Watch Infantry fallback.
- City 5 — Arrow Tower `[Infantry, Cavalry]`; both are unlocked; useful for authored order and Save-for non-substitution.
- City 6 — Stone Wall `[Mage, Siege]`; both are locked; useful for all-locked/no-fallback behavior.
- City 7 — Burning Oil `[Archer, Mage, Cavalry]`; useful as documentation evidence that locked entries can exist later in a favorable list even though the first Archer candidate is unlocked.
- Five Barracks on City 5 — build cap reached, but upgrade remains valid.

Do not add a production trait/unlock injection seam merely to manufacture a different catalog ordering.

## Testing strategy

### Pure policy

Cover:

- City 1 Standard Watch Infantry fallback.
- Ready vs Save-for for the same exact action.
- City 5 authored favorable order.
- Existing favored building -> upgrade.
- Lowest-level then lowest-slot upgrade tie-break.
- Lowest empty lot for a build when no favored building exists.
- Unaffordable first structural action remains Save-for without later-candidate substitution.
- Five favored buildings still allow the lowest `(level, slot)` upgrade; no max level is invented.
- City 6 all favorable types locked -> `noAction`, with no Infantry fallback.
- Non-active stage -> `noAction`.
- Identical state -> identical recommendation.

Do not add tests claiming build-vs-upgrade economic optimality; HPA-365 deliberately does not implement an optimizer.

### Building View

Cover:

- Ready / Save-for / noAction render through the same two-label row.
- Fixed action-panel height at `568 x 320` and `667 x 375`.
- Row/manual controls/labels/grid are contained and non-overlapping in those fixtures.
- Ready tap delegates exactly one existing build/upgrade path and recomputes the next value.
- Save-for / noAction taps are swallowed with state, feedback, route, and selected lot unchanged.
- Settings keeps precedence over row touches.
- Existing manual palette/upgrade/Battle/lot tests remain green.

No external-store-writer stale test is required.

## Accessibility decision

HPA-365 does not add a new accessibility adapter or make the Building View palette accessible. The current palette/lot controls are not exposed through a dedicated accessibility surface, so expanding that system only for Recommended Camp would be inconsistent scope. Keep this slice aligned with the current Building View and track broader Building View accessibility separately if desired.

## Manual smoke

On smallest supported portrait and both existing landscape gates:

1. City 1 empty camp -> Infantry starter suggestion.
2. City 5 -> authored Infantry-first favorable guidance.
3. City 6 empty camp -> no recommendation because Mage/Siege are locked; no Infantry fallback.
4. Save-for reports exact missing gold and consumes its touch without selecting a lot.
5. Ready purchase spends once through the existing mutation path and immediately shows the next recommendation.
6. Manual palette, Upgrade, lot selection, Settings, and Battle still work.
7. Background/foreground may recompute guidance but never auto-purchases.
8. At `568 x 320` and `667 x 375`, confirm the scenic grid is not compressed relative to the pre-feature action-panel height and the row/manual controls remain readable.

## Risks

1. **Layout budget** — fixed action-panel height; repack inside it; prove row/labels/manual controls/grid separation at both landscape gates.
2. **Heuristic misunderstood as optimization** — document that upgrade-first is a deterministic assistance rule, not a damage/gold score; revisit only with playtest evidence.
3. **Recommendation/purchase drift** — recompute from current scene state immediately before Ready delegation.
4. **Informational-card fallthrough** — unconditional row hit consumption prevents lot selection underneath Save-for/noAction.
5. **Fixture false greens** — active City N fixtures set `completedCityCount = N - 1`.
6. **Catalog assumptions** — skip locked candidates generically; do not encode the current ordering as an invariant.
7. **Policy creep** — no scoring, history, lane synthesis, multi-buy planning, or generic recommendation infrastructure.

## Non-goals

- Damage-per-gold or combat-outcome optimization.
- Automatic purchases or multiple actions per tap.
- Copying the previous city's camp.
- Neutral fallback purchases on non-standard cities.
- Lane-placement advice or combat simulation/scoring.
- New currencies, inventory, build queues, demolition/refunds, adjacency, production chains, or placement optimization.
- Recommendation persistence, analytics, history, explanation drill-down, localization framework, or reusable recommendation architecture.
- New recommendation layout/component types.
- Building View accessibility expansion.
- HPA-390 milestone presentation or HPA-567 campaign validation.