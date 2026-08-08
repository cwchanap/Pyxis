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

`Country1CityCatalog` is already the authored source of truth for the 15 existing `CityDefinition` values. Current consumers already expose the right seams: `KingdomGameState.displayCityTitle(for:)`, the pure `CountryMapScoutCardContent` projection, `CountryMapScoutCardLayout`, `CountryMapScoutCardNode`, `CountryMapTransientFeedback`, Battle HUD/tooltip/report projection, and the existing Building View shared-title feedback.

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

## Authoring and fit limits

- `name`: non-empty, <= 18 characters as a coarse authoring bound.
- `flavorText`: non-empty, <= 48 characters.
- `conquestTitle`: non-empty, <= 24 characters.
- Names are unique case-insensitively.
- All 15 rows stay in city order and preserve existing trait/lane values.

Rendered width is authoritative. The narrowest supported pad fixture is 480 pt wide; current geometry yields a 198 pt Scout title frame. Every `City N · Name` must fit the existing nominal 16 pt pad title size (and 11 pt phone size). `CountryMapScoutCardTextLayoutTests.everyTitleAndRewardFitsAtItsNominalSizeInEverySupportedLayout` must read `CityDefinition.displayTitle` directly and run in the same authoring slice.

`Kingshield Bastion` exceeds that real nominal budget, so City 11 is **`Kingshield Keep`** before implementation starts.

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

## Catalog lookup and fallback

Keep clamped `Country1CityCatalog.definition(for:)` for gameplay compatibility. Add non-clamping display lookup:

```swift
static func definitionIfPresent(for cityNumber: Int) -> CityDefinition? {
    guard cityRange.contains(cityNumber) else { return nil }
    return definitions[cityNumber - cityRange.lowerBound]
}
```

Current-state titles remain instance/state-based:

```swift
func displayCityTitle(for cityNumber: Int) -> String {
    guard countryNumber == 1,
          let definition = Country1CityCatalog.definitionIfPresent(for: cityNumber) else {
        return "Country \(countryNumber) - City \(cityNumber)"
    }
    return definition.displayTitle
}
```

Persisted conquest reports must use their own record key, not ambient state:

```swift
static func displayConquestTitle(for cityKey: CityKey) -> String {
    guard cityKey.countryNumber == 1,
          let definition = Country1CityCatalog.definitionIfPresent(for: cityKey.cityNumber) else {
        return "Country \(cityKey.countryNumber) - City \(cityKey.cityNumber) Conquered"
    }
    return definition.conquestTitle
}
```

## Country Map projection

`CountryMapScoutCardContent.Scout` gains `flavorText`. Country completion remains pure:

```swift
case countryComplete(countryNumber: Int, finalCityName: String)
```

`project(from:)` resolves `finalCityName` from constant catalog City 15. The SpriteKit node renders the supplied value and does not read the catalog.

## Non-blocking flavor interaction

Flavor must ship, but current transient feedback cannot be reused unchanged because three independent behaviors block Attack: `CountryMapScene.redraw()` disables entry while any transient exists, `CountryMapScoutCardNode.applyFeedback` clears `attackHitFrame`, and the full-card `overlayFrame` intercepts touches before Attack.

Use the minimum targeted extension:

1. `CountryMapScoutCardLayout.nonBlockingOverlayFrame` covers only the informational card area and excludes Attack. Existing `overlayFrame` remains full-card blocking feedback.
2. `CountryMapTransientFeedback.Kind.flavor` is the only kind with `blocksScoutEntry == false`.
3. Scene entry stays enabled for flavor.
4. `CountryMapScoutCardNode.applyFeedback(..., blocksAttack:)` uses the non-blocking frame and preserves Attack for flavor; existing feedback keeps today's full overlay + Attack suppression.
5. Tests tap Attack before flavor expires.

No new modal, controller, scene, timer, or durable state is added.

## Map feedback

Locked/completed feedback uses shared authored titles. Idle conquest shows the newly unlocked authored title rather than repeating its trait. Final copy is:

- `Country 1 conquered · Crownspire Keep` on the Scout Card;
- `Country 1 conquered at Crownspire Keep.` for final idle feedback.

## Battle and Building integration

Battle HUD/tooltip continue to use `state.displayCityTitle`. Building View already consumes the same shared title.

`ConquestReportContent.project` becomes caller-owned:

```swift
static func project(from result: BattleResult, title: String) -> Self
```

BattleScene passes:

```swift
title: KingdomGameState.displayConquestTitle(for: result.cityKey)
```

This deletes the current `isCountryComplete` title branch without changing report rows, restoration, effects, Continue ordering, persistence, or routing.

Final-city contract: Battle says `Crownspire Keep Falls`; country-level copy is map-only after Continue.

## Testing strategy

1. **Authoring gate in Task 1:** exact table, uniqueness/limits, unchanged combat metadata, optional lookup, nominal title fit using `definition.displayTitle` directly.
2. **Shared projection/report:** current display/fallback, result-key conquest formatting, Scout flavor payload, Battle/Building exact strings, caller-owned report title, both final-country Battle paths.
3. **Country Map behavior:** pure final-country payload, named feedback, body-tap flavor with no mutation/SFX/route, Attack still routes while flavor is visible, current blocking feedback still blocks.
4. **Fit acceptance:** existing dense all-content matrix; all 15 flavors through non-blocking overlay; all named locked/completed/final strings through blocking overlay.

Known affected test files are explicitly inventoried in the implementation plan; repository-wide search is a final backstop rather than discovery mechanism.

## Risks and controls

1. **Real title budget:** character limits are insufficient; run nominal production title fit in Task 1. `Kingshield Keep` replaces the overflow before downstream hard-coding.
2. **Flavor blocks Attack:** address all three current blockers and test an Attack tap before flavor expiry.
3. **Final-country drift:** resolve report title from `BattleResult.cityKey`; both final-country Battle tests lock City 15 title and map tests lock separate country confirmation.
4. **Stale exact strings:** update known sibling suites atomically with their producer.
5. **Transient-copy fit:** enumerate all authored strings as cheap regression coverage; this is not the primary layout risk.

## Manual smoke

Seed/play City 1→15 and verify Scout title/flavor, immediate Attack during flavor, Battle HUD/tooltip, Building View conquest copy, authored report title, named map feedback, and City 15 report -> country-map completion. Confirm gameplay/reward/lane/routing/SFX/haptics are unchanged.

## Non-goals

HPA-390 milestone effects, Chronicle persistence, new gameplay/balance, per-city art/theme/music/dialogue/lore pages, localization infrastructure, multiple countries/generic content platform, save migration, or malformed-content recovery machinery.