# Country 1 City Catalog Design

## Context

Country 1 has 15 authored cities, but its combat metadata currently comes from
two independent city-number helpers:

- `KingdomGameState.defenseTrait(forCityNumber:)` uses an authored switch.
- `LaneDefenseProfile.profile(forCityNumber:)` uses a three-city rotation
  formula.

That split is safe for today's battle and map consumers, but upcoming scouting,
identity, Chronicle, recommendation, and objective work needs one definition
per city. Adding those features against the existing helpers would invite
parallel city tables and derived values that can drift.

HPA-361 introduces the pure-model foundation only. It centralizes the existing
combat metadata without changing any valid Country 1 battle behavior.

## Goals

- Define exactly one immutable `CityDefinition` for each Country 1 city
  numbered `1...15`.
- Make `Country1CityCatalog` the single runtime source of truth for authored
  per-city combat metadata.
- Preserve every valid city's current defense trait and lane profile.
- Preserve the existing `KingdomGameState` and `LaneDefenseProfile`
  compatibility APIs by making them project catalog fields.
- Provide one non-optional lookup contract that clamps all inputs to `1...15`.
- Expose favorable and disadvantaged soldier types as read-only semantics
  derived from `CityDefenseTrait`.
- Keep the new model framework-free and independently unit-testable.

## Non-Goals

- Scout Card or country-map interaction changes.
- City names, flavor text, conquest messages, themes, art, or milestone
  presentation.
- Quick Build behavior.
- Chronicle persistence, objectives, recommendations, or campaign branching.
- New defense traits, lane roles, unit counters, or balance changes.
- Moving gold rewards or building unlocks into city definitions.
- Changing save data or adding catalog data to `KingdomGameState` persistence.

## Model Architecture

### `CityDefinition`

Add a framework-free immutable value type:

```swift
struct CityDefinition: Equatable {
    let cityNumber: Int
    let defenseTrait: CityDefenseTrait
    let laneDefenseProfile: LaneDefenseProfile
}
```

It contains only authored per-city combat metadata. It does not contain values
that already have a deterministic owner:

- Gold reward remains derived from city level by `KingdomGameState`.
- Building unlocks remain derived from existing progression rules.
- Favorable and disadvantaged soldiers remain derived from the defense trait.
- City identity and presentation fields remain deferred to later tickets.

### `Country1CityCatalog`

Add a framework-free namespace with:

- `cityRange = 1...15`.
- An immutable ordered `[CityDefinition]` containing exactly 15 entries.
- `definition(for cityNumber: Int) -> CityDefinition`.

An ordered array is preferred over a dictionary because clamped lookup maps
directly to `definitions[clampedCityNumber - 1]`, while completeness, ordering,
and uniqueness remain straightforward to test. It is preferred over a 15-case
enum because definitions are data that later tickets can extend without adding
case-by-case computed-property switches.

Every lane profile is explicit in the catalog. The current three-city rotation
formula is not retained as a second runtime source.

`KingdomGameState.firstCountryCityCount` derives from the catalog range so the
campaign and catalog cannot acquire independent Country 1 counts.

## Authored Country 1 Combat Definitions

The catalog preserves the exact pre-migration values for valid city numbers.
Lane roles repeat the current three-city rotation, but are stored explicitly:

| City | Defense trait | Fortified lane | Exposed lane | Standard lane |
|---:|---|---|---|---|
| 1 | Standard Watch | Left | Right | Center |
| 2 | Standard Watch | Center | Left | Right |
| 3 | Arrow Tower | Right | Center | Left |
| 4 | Spiked Gate | Left | Right | Center |
| 5 | Arrow Tower | Center | Left | Right |
| 6 | Stone Wall | Right | Center | Left |
| 7 | Burning Oil | Left | Right | Center |
| 8 | Stone Wall | Center | Left | Right |
| 9 | Arcane Ward | Right | Center | Left |
| 10 | Spiked Gate | Left | Right | Center |
| 11 | Reinforced Keep | Center | Left | Right |
| 12 | Burning Oil | Right | Center | Left |
| 13 | Arcane Ward | Left | Right | Center |
| 14 | Stone Wall | Center | Left | Right |
| 15 | Reinforced Keep | Right | Center | Left |

## Compatibility APIs And Data Flow

Add:

```swift
var currentCityDefinition: CityDefinition
```

The compatibility APIs become catalog projections:

```text
city number
  -> Country1CityCatalog.definition(for:)
       -> CityDefinition.defenseTrait
       -> CityDefinition.laneDefenseProfile
```

Specifically:

- `KingdomGameState.defenseTrait(forCityNumber:)` returns the matching
  definition's `defenseTrait`.
- `KingdomGameState.currentCityDefinition` resolves the current city through
  the catalog.
- `KingdomGameState.currentCityDefenseTrait` projects
  `currentCityDefinition.defenseTrait`.
- `KingdomGameState.currentCityLaneDefenseProfile` projects
  `currentCityDefinition.laneDefenseProfile`.
- `LaneDefenseProfile.profile(forCityNumber:)` remains available and returns
  the matching definition's `laneDefenseProfile`.

The old defense-trait switch and lane rotation formula are removed. Map, battle,
live damage, and idle damage consumers continue using their existing
`KingdomGameState` APIs; those calls now converge on the catalog without
requiring scene changes.

## Trait-Derived Soldier Semantics

Rename and expose the existing private trait lists as non-private, read-only
properties:

```swift
var favorableSoldierTypes: [SoldierType]
var disadvantagedSoldierTypes: [SoldierType]
```

These properties remain computed from `CityDefenseTrait`. They are not copied
into any `CityDefinition`.

`damageMultiplier(for:)` continues to use those properties:

- Favorable types receive `1.25`.
- Disadvantaged types receive `0.80`.
- All other types receive `1.0`.

This preserves current live and idle combat balance while making the semantics
available to later recommendation and scouting features.

## Bounds And Error Handling

`Country1CityCatalog.definition(for:)` is non-optional. It clamps before
indexing:

- Negative values and zero resolve to City 1.
- Values from 1 through 15 resolve to themselves.
- Values above 15 resolve to City 15.

All compatibility helpers inherit that exact contract by delegating to the
catalog. This intentionally gives `LaneDefenseProfile.profile(forCityNumber:)`
an upper clamp it did not previously apply when called directly. Valid Country
1 inputs are unchanged, and normalized campaign state already stays within
`1...15`.

Catalog construction is static and immutable. It introduces no decoding,
runtime fallback definition, or recoverable error state.

## Persistence And Runtime Behavior

`CityDefinition` and `Country1CityCatalog` are derived static data and are not
`Codable`. `KingdomGameState` continues persisting the same campaign, combat,
building, gold, and lifecycle values.

The migration must not change:

- Campaign normalization or map gating.
- City HP, gold rewards, or building unlock formulas.
- Trait-adjusted live soldier damage.
- Trait-adjusted active or idle building damage.
- Lane tower-damage multipliers for Cities 1 through 15.
- Scene routing, layout, or presentation.

## Testing Strategy

Follow the repository's TDD convention.

### Catalog tests

Add focused `Country1CityCatalogTests` that:

- Assert the catalog has exactly 15 definitions.
- Assert city numbers are unique and cover every value in `1...15` without
  gaps.
- Compare all 15 definitions with an independent expected table containing the
  exact trait and lane roles listed in this spec.
- Assert negative, zero, and above-range lookup clamping.

### Compatibility tests

For all 15 cities and representative out-of-range values:

- Compare `KingdomGameState.defenseTrait(forCityNumber:)` with the catalog.
- Compare `LaneDefenseProfile.profile(forCityNumber:)` with the catalog.
- Verify `currentCityDefinition`, `currentCityDefenseTrait`, and
  `currentCityLaneDefenseProfile` from `KingdomGameState`.

These behavioral comparisons make any divergence between a compatibility API
and the catalog fail. The implementation also removes the old switch and
formula rather than preserving redundant lookup logic.

### Trait-semantic tests

For every `CityDefenseTrait`:

- Assert the exact favorable soldier list.
- Assert the exact disadvantaged soldier list.
- Assert favorable, disadvantaged, and neutral damage multipliers remain
  derived from those lists.

### Regression verification

Run the focused new tests first, then the complete unit-test target with
parallel testing disabled. No new UI test is required because this feature
does not change presentation or interaction.

## Expected File Boundaries

- Create `Pyxis/CityDefinition.swift`.
- Create `Pyxis/Country1CityCatalog.swift`.
- Modify `Pyxis/CityDefenseTrait.swift`.
- Modify `Pyxis/LaneDefenseProfile.swift`.
- Modify `Pyxis/KingdomGameState.swift`.
- Create `PyxisTests/Country1CityCatalogTests.swift`.
- Extend existing trait tests only where retaining their current test location
  is clearer than duplicating them in the catalog suite.

The Xcode project uses a synchronized root group, so new Swift files are
discovered automatically and `project.pbxproj` must not be edited.
