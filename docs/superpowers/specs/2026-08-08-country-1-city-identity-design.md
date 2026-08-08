# HPA-366 Country 1 City Identity Design

## Goal

Make Country 1 feel like a coherent 15-stage journey by giving every existing city a short authored identity and reusing that identity across the current map, battle, building, and conquest surfaces without adding gameplay mechanics, persistence, or a content framework.

This implements HPA-366 and preserves every existing defense trait, lane profile, HP curve, reward, unlock, building rule, idle rule, and combat behavior.

## Product constraints

- Country 1 remains exactly 15 cities.
- City numbers remain visible in progression-critical titles.
- Every city has a unique name, one-line flavor text, and short conquest title.
- Identity content may describe atmosphere or an already-existing defense trait, but must not imply mechanics that do not exist.
- No identity field is persisted in `KingdomGameState` or `BattleResult`; consumers resolve current authored content from the catalog.
- HPA-390 still owns presentation-only milestone treatment for Cities 5, 10, and 15. HPA-366 adds copy only, not milestone effects.
- No city-specific background, palette, ambience, music, objective, dialogue, cutscene, branching content, localization layer, or generic campaign-content framework is introduced.
- Final-city Battle and Country Map copy have distinct jobs: the City 15 Battle report always says `Crownspire Keep Falls`; country-level completion copy appears only after the report on the Country Map.
- Flavor text is a required HPA-366 deliverable. It must have a shipping consumer, but showing flavor must not temporarily disable the Scout Card's primary Attack action.

## Existing architecture

`Country1CityCatalog` is already the authored source of truth for the 15 existing `CityDefinition` values. `CityDefinition` currently stores only `cityNumber`, `defenseTrait`, and `laneDefenseProfile`.

Current consumers already expose the right seams:

- `KingdomGameState.displayCityTitle(for:)` supplies titles to Battle, Building View feedback, and the Scout Card.
- `CountryMapScoutCardContent` is the pure projection for unlocked/final-country card content.
- `CountryMapScoutCardLayout` owns pure Scout Card geometry.
- `CountryMapScoutCardNode` renders already-projected content and transient overlays.
- `CountryMapTransientFeedback` owns short map feedback and timing.
- `BattleScene` uses `state.displayCityTitle` for the HUD and city tooltip and owns the single production `ConquestReportContent` call site.
- `BuildingViewScene` already embeds `state.displayCityTitle` in building-driven conquest feedback.

The feature extends these seams. It does not add a new service, repository, manager, registry, save field, or scene.

## Data model

Extend `CityDefinition` with exactly three stored identity fields:

```swift
struct CityDefinition: Equatable {
    let cityNumber: Int
    let name: String
    let flavorText: String
    let conquestTitle: String
    let defenseTrait: CityDefenseTrait
    let laneDefenseProfile: LaneDefenseProfile

    var displayTitle: String {
        "City \(cityNumber) · \(name)"
    }
}
```

No `Codable` conformance is required because catalog identity is compiled content, not save data.

### Authoring and fit limits

The authored table must satisfy:

- `name`: non-empty after trimming and at most 18 characters as a coarse authoring bound.
- `flavorText`: non-empty after trimming and at most 48 characters.
- `conquestTitle`: non-empty after trimming and at most 24 characters.
- Names are unique case-insensitively.
- All 15 definitions remain in exact city-number order.
- Existing defense traits and lane profiles remain equivalent by value.

The **rendered title budget is authoritative**, not the character count. The current narrowest supported pad fixture is 480 pt wide. Its information region is 448 pt wide and the existing Scout Card geometry yields a 198 pt title frame. Therefore every `City N · Name` must fit `AvenirNext-DemiBold` at the existing nominal 16 pt pad title size; phone titles must likewise fit at the existing nominal 11 pt size.

The existing `CountryMapScoutCardTextLayoutTests.everyTitleAndRewardFitsAtItsNominalSizeInEverySupportedLayout` test is the acceptance gate. It must read `CityDefinition.displayTitle` directly and run in the same authoring slice as the catalog change. Do not wait until a later integration task to discover a bad authored name.

`Kingshield Bastion` exceeds that current narrow-pad nominal budget. The reviewed City 11 name is therefore **`Kingshield Keep`** before implementation starts.

Character limits remain useful content discipline, but if a string satisfies a character limit and fails the production fit test, the rendered-width test wins and the authored copy is shortened.

## Authored Country 1 identity table

| City | Name | Existing trait | Flavor text | Conquest title |
|---|---|---|---|---|
| 1 | Willowford | Standard Watch | A quiet crossing where the campaign begins. | Willowford Secured |
| 2 | Pinewatch | Standard Watch | A hill watchtown guarding the old trade road. | Pinewatch Secured |
| 3 | Falconridge | Arrow Tower | Arrow towers command the high ridge road. | Falconridge Silenced |
| 4 | Bramblegate | Spiked Gate | Iron spikes guard a narrow frontier gate. | Bramblegate Broken |
| 5 | Highcrest | Arrow Tower | A proud hill fortress crowns the frontier. | Highcrest Falls |
| 6 | Granite Pass | Stone Wall | Stone walls seal the mountain road ahead. | Granite Pass Open |
| 7 | Emberford | Burning Oil | Burning oil guards the bridge inland. | Emberford Secured |
| 8 | Greywall | Stone Wall | Layered stone walls protect a busy town. | Greywall Falls |
| 9 | Runewatch | Arcane Ward | Arcane wards shimmer over the night road. | Runewatch Unbound |
| 10 | Ironthorn Gate | Spiked Gate | A hardened gate blocks the inner road. | Ironthorn Gate Broken |
| 11 | Kingshield Keep | Reinforced Keep | A reinforced fortress guards the royal road. | Kingshield Keep Falls |
| 12 | Ashbridge | Burning Oil | Fire cauldrons guard the last crossing. | Ashbridge Secured |
| 13 | Starveil Citadel | Arcane Ward | Arcane wards protect the capital heights. | Starveil Citadel Falls |
| 14 | Stonecrown | Stone Wall | Massive stone walls ring the royal seat. | Stonecrown Breached |
| 15 | Crownspire Keep | Reinforced Keep | The final keep rises above the capital. | Crownspire Keep Falls |

## Catalog lookup and display fallback

Keep the existing clamping `Country1CityCatalog.definition(for:)` behavior because current combat compatibility code relies on it.

Add a non-clamping optional lookup for display consumers:

```swift
static func definitionIfPresent(for cityNumber: Int) -> CityDefinition? {
    guard cityRange.contains(cityNumber) else { return nil }
    return definitions[cityNumber - cityRange.lowerBound]
}
```

`KingdomGameState.displayCityTitle(for:)` uses authored identity only for a valid Country 1 city and otherwise retains the current release-safe legacy string:

```swift
func displayCityTitle(for cityNumber: Int) -> String {
    guard countryNumber == 1,
          let definition = Country1CityCatalog.definitionIfPresent(for: cityNumber) else {
        return "Country \(countryNumber) - City \(cityNumber)"
    }
    return definition.displayTitle
}
```

Do not use ambient `KingdomGameState.countryNumber` to title a persisted conquest result. The report's `BattleResult.cityKey` is the source of truth for both country and city:

```swift
static func displayConquestTitle(for cityKey: CityKey) -> String {
    guard cityKey.countryNumber == 1,
          let definition = Country1CityCatalog.definitionIfPresent(for: cityKey.cityNumber) else {
        return "Country \(cityKey.countryNumber) - City \(cityKey.cityNumber) Conquered"
    }
    return definition.conquestTitle
}
```

The helper lives with the existing campaign display formatting but depends only on the supplied `CityKey`.

## Country Map projection

`CountryMapScoutCardContent.Scout` gains `flavorText` alongside its current display title and tactical data. Projection reads both from the same `CityDefinition`.

Country completion remains in the pure projection:

```swift
case countryComplete(countryNumber: Int, finalCityName: String)
```

`project(from:)` resolves `finalCityName` from constant catalog City 15 (`cityRange.upperBound`). The SpriteKit node only renders the supplied name.

### Non-blocking flavor interaction

Tapping the non-action Scout Card body shows the city's required `flavorText`, but flavor is informational, not modal. Attack must stay visible and tappable during the entire flavor lifetime.

Current feedback reuse is unsafe unchanged because three independent behaviors block Attack today: `CountryMapScene.redraw()` disables entry while any transient exists, `CountryMapScoutCardNode.applyFeedback` clears `attackHitFrame`, and the full-card overlay intercepts touches before the Attack check.

Use the smallest targeted extension:

1. `CountryMapScoutCardLayout` adds `nonBlockingOverlayFrame`, covering the informational area but not `attackFrame`; existing `overlayFrame` remains the full blocking frame.
2. `CountryMapTransientFeedback.Kind` adds `.flavor` plus `blocksScoutEntry` (`false` only for flavor).
3. `CountryMapScene.redraw()` keeps entry enabled for flavor.
4. `CountryMapScoutCardNode.applyFeedback(..., blocksAttack:)` uses the non-blocking frame and preserves Attack for flavor, while current feedback kinds retain full overlay + Attack suppression.
5. Scene tests tap Attack before flavor expires.

No new modal, controller, scene, durable state, or second timer is added.

## Map feedback

Locked/completed feedback uses resolved titles (`City 3 · Falconridge is locked`, `City 12 · Ashbridge complete`). Idle conquest shows the newly unlocked authored title rather than repeating the trait. Final copy is:

- `Country 1 conquered · Crownspire Keep` on the Scout Card;
- `Country 1 conquered at Crownspire Keep.` for final idle feedback.

## Battle integration

Battle HUD/tooltip continue to use `state.displayCityTitle`.

`ConquestReportContent.project` changes to:

```swift
static func project(
    from result: BattleResult,
    title: String
) -> Self
```

The production caller passes:

```swift
title: KingdomGameState.displayConquestTitle(for: result.cityKey)
```

This deletes the current `isCountryComplete` title branch while preserving report rows, achievements, persistence, restoration, effects, Continue ordering, and routing.

Final-city contract:

- City 15 Battle report = `Crownspire Keep Falls`;
- country-level completion is map-only after Continue;
- both existing BattleScene country-complete report assertions lock this rule.

## Building View integration

`BuildingViewScene` already consumes `state.displayCityTitle` for building-driven conquest feedback. Only matching exact-string tests need to move with the shared producer.

## Call-site inventory

Production: `CityDefinition`, `Country1CityCatalog`, `KingdomGameState`, `CountryMapScoutCardContent`, `CountryMapScoutCardLayout`, `CountryMapScoutCardNode`, `CountryMapTransientFeedback`, `CountryMapScene`, `ConquestReportContent`, `BattleScene`, and existing `BuildingViewScene` shared-title usage.

Tests: `Country1CityCatalogTests`, `KingdomGameStateTests`, `CountryMapScoutCardContentTests`, `CountryMapScoutCardLayoutTests`, `CountryMapScoutCardNodeTests`, `CountryMapScoutCardTextLayoutTests`, `CountryMapScoutCardAcceptanceTests`, `CountryMapTransientFeedbackTests`, `CountryMapSceneTests`, `ConquestReportContentTests`, `ConquestReportNodeTests`, `BattleSceneTests`, `BuildingViewSceneTests`.

## Testing strategy

1. **Task 1 authoring gate:** exact table, uniqueness/limits, unchanged combat metadata, non-clamping optional lookup, and the existing nominal title-fit test reading `definition.displayTitle` directly.
2. **Shared projection/report:** authored display/fallback, result-key conquest formatting, Scout flavor payload, Battle HUD/tooltip, Building View exact copy, caller-owned report title, both final-country Battle paths.
3. **Country Map behavior:** pure final-country payload, named feedback, body tap flavor with no mutation/SFX/route, Attack still routes while flavor is visible, current blocking feedback still blocks.
4. **Fit acceptance:** existing dense all-content matrix; all 15 flavors through `nonBlockingOverlayFrame`; all named locked/completed/final strings through existing blocking overlay.

## Risks and controls

### 1. Authored title exceeds the real layout budget

A character cap can pass while the 198 pt narrow-pad nominal title frame fails. Run the nominal production title-fit in Task 1. `Kingshield Keep` replaces `Kingshield Bastion` before downstream hard-coding.

### 2. Flavor blocks Attack

Existing transient feedback disables Attack in three ways. Flavor gets a dedicated non-blocking mode, pure non-Attack frame, preserved entry/hit frame, and a test that taps Attack before expiry.

### 3. Final-country semantics drift

Resolve report title from `BattleResult.cityKey`; both existing final-country Battle tests require `Crownspire Keep Falls`, while map tests require separate country confirmation.

### 4. Stale exact-string tests

Update known sibling suites in the same task as the producer; final `rg` search is only a backstop.

### 5. Transient-copy fit regression

Enumerate all authored flavor/locked/completed/final strings through existing fit helpers. This is cheap regression coverage, not the primary layout risk.

## Manual smoke

Seed/play City 1→15 and verify Scout title, flavor, immediately usable Attack during flavor, Battle HUD/tooltip, Building View conquest copy, conquest title, named map feedback, and City 15 report → country-map completion handoff. Confirm gameplay/reward/lane/routing/SFX/haptics are unchanged.

## Non-goals

- HPA-390 milestone effects.
- Campaign Chronicle or persisted identity copies.
- New gameplay rules, units, traits, rewards, or balance.
- Per-city art/theme/music/dialogue/lore pages.
- Localization infrastructure.
- Multiple countries or generic campaign-content framework.
- Save migration or malformed-content recovery machinery.