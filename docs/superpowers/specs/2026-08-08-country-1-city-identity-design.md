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
- City 15 Battle and Country Map copy have distinct jobs: Battle report says `Crownspire Keep Falls`; country-level completion appears only after Continue on the Country Map.
- Flavor text is required and must have a shipping consumer without disabling the Scout Card's primary Attack action.

## Architecture

`Country1CityCatalog` remains the authored source of truth. Extend existing `CityDefinition`, current display helpers, pure Scout content/layout projections, transient feedback, Battle report projection, and existing Building View shared-title use. Add no service, repository, manager, save field, scene, or generic content abstraction.

## CityDefinition

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

Identity is compiled content, not `Codable` save state.

## Authoring and fit limits

- `name`: non-empty, <= 18 characters as a coarse content bound.
- `flavorText`: non-empty, <= 48 characters.
- `conquestTitle`: non-empty, <= 24 characters.
- Names unique case-insensitively; rows remain City 1...15; trait/lane metadata unchanged.

Rendered width is authoritative. The narrowest supported pad fixture is 480 pt wide; current geometry yields a 198 pt Scout title frame. Every `City N · Name` must fit the existing nominal 16 pt pad / 11 pt phone title sizes. The existing nominal title-fit test must read `CityDefinition.displayTitle` directly and run in the authoring task.

`Kingshield Bastion` exceeds that real budget, so City 11 is **`Kingshield Keep`** before implementation starts.

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

## Lookup and display fallback

Keep clamped `Country1CityCatalog.definition(for:)` for gameplay. Add non-clamping `definitionIfPresent(for:)` for display fallback.

Current-state UI uses `KingdomGameState.displayCityTitle(for:)` and retains legacy `Country N - City M` for unsupported values.

Persisted conquest reports use their own record key, not ambient state:

```swift
static func displayConquestTitle(for cityKey: CityKey) -> String {
    guard cityKey.countryNumber == 1,
          let definition = Country1CityCatalog.definitionIfPresent(for: cityKey.cityNumber) else {
        return "Country \(cityKey.countryNumber) - City \(cityKey.cityNumber) Conquered"
    }
    return definition.conquestTitle
}
```

## Pure Country Map content

`CountryMapScoutCardContent.Scout` gains `flavorText`.

Country completion stays pure:

```swift
case countryComplete(countryNumber: Int, finalCityName: String)
```

`project(from:)` resolves `finalCityName` from constant catalog City 15. `CountryMapScoutCardNode` renders supplied content and never reads the catalog for final identity.

## Non-blocking flavor

Current transient feedback cannot be reused unchanged because it blocks Attack in three independent places: scene entry eligibility, node `attackHitFrame`, and the full-card overlay touch guard.

Minimal extension:

1. `CountryMapScoutCardLayout.nonBlockingOverlayFrame` covers informational content and excludes `attackFrame`; current `overlayFrame` remains full-card blocking feedback.
2. `CountryMapTransientFeedback.Kind.flavor` is the only kind with `blocksScoutEntry == false`.
3. Scene entry remains enabled for flavor.
4. `CountryMapScoutCardNode.applyFeedback(..., blocksAttack:)` preserves Attack and uses the non-blocking frame for flavor; existing feedback retains full overlay + Attack suppression.
5. Scene tests tap Attack before flavor expires.

No new modal, controller, scene, timer, or durable state.

## Map copy

Locked/completed feedback uses authored display titles. Idle conquest shows the next authored title rather than redundant trait copy. Final Country 1 copy is `Country 1 conquered · Crownspire Keep` on the Scout Card and `Country 1 conquered at Crownspire Keep.` for final idle feedback.

## Battle and Building integration

Battle HUD/tooltip and existing Building View conquest feedback continue to consume shared display titles.

`ConquestReportContent.project` becomes caller-owned:

```swift
static func project(from result: BattleResult, title: String) -> Self
```

BattleScene passes `KingdomGameState.displayConquestTitle(for: result.cityKey)`, deleting the current `isCountryComplete` report-title branch without changing rows, restoration, effects, Continue ordering, persistence, or routing.

## Testing

1. **Task 1:** exact table, unique/length bounds, unchanged combat metadata, optional lookup, and nominal title fit from `definition.displayTitle`.
2. **Shared projection/report:** authored current titles/fallback, result-key report formatting, Scout flavor payload, Battle/Building exact copy, caller-owned report title, both final-country Battle paths.
3. **Country Map:** pure final-country payload, named feedback, body-tap flavor with no mutation/SFX/route, Attack still routes while flavor is visible, existing blocking feedback still blocks.
4. **Fit acceptance:** existing dense matrix, all 15 flavors through non-blocking overlay, named locked/completed/final copy through blocking overlay.

## Risks

1. **Real title budget:** nominal fit runs in Task 1; `Kingshield Keep` replaces overflowing `Kingshield Bastion` before downstream hard-coding.
2. **Flavor blocks Attack:** address all three blockers and test Attack before expiry.
3. **Final-country drift:** report title derives from `BattleResult.cityKey`; Battle and map tests lock separate city/country semantics.
4. **Stale exact strings:** update known sibling suites atomically; repository search is only a backstop.
5. **Transient fit:** enumerate authored strings as cheap regression coverage.

## Manual smoke

Seed/play City 1→15 and verify Scout title/flavor, immediate Attack during flavor, Battle HUD/tooltip, Building View conquest copy, authored report title, named map feedback, and City 15 report -> map completion. Confirm gameplay/reward/lane/routing/SFX/haptics unchanged.

## Non-goals

HPA-390 milestone effects, Chronicle persistence, new gameplay/balance, per-city art/theme/music/dialogue/lore pages, localization, multiple countries/generic content platform, save migration, or malformed-content recovery machinery.