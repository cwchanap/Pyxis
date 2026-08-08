# HPA-366 Country 1 City Identity Design

## Goal

Make Country 1 feel like a coherent 15-stage journey by giving every existing city a short authored identity and reusing that identity across current map, battle, building, and conquest surfaces without adding gameplay mechanics, persistence, or a content framework.

## Product constraints

- Exactly 15 Country 1 cities; city numbers remain visible where progression matters.
- Every city has a unique name, one-line flavor text, and short conquest title.
- Identity describes atmosphere or existing defense concepts only.
- Identity is compiled catalog content, never persisted in `KingdomGameState` or `BattleResult`.
- HPA-390 still owns milestone effects for Cities 5/10/15.
- No per-city art/theme/music/dialogue, localization layer, multi-country abstraction, content service, or new scene.
- City 15 Battle report = `Crownspire Keep Falls`; overall country completion appears only on the Country Map after Continue.
- Flavor is required and must not disable the Scout Card Attack action.

## Architecture

Keep `Country1CityCatalog` as the single authored source. Extend existing `CityDefinition`, display helpers, pure Scout content/layout projections, transient feedback, Battle report projection, and Building View shared-title consumption. No new persistence or framework layer.

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

## Authoring and fit

- `name` <= 18 chars as a coarse bound; `flavorText` <= 48; `conquestTitle` <= 24; all non-empty.
- Names unique case-insensitively; rows remain City 1...15; trait/lane values unchanged.
- Rendered width is authoritative. The narrowest supported pad fixture is 480 pt wide and current Scout geometry yields a 198 pt title frame at nominal 16 pt. Phone nominal is 11 pt.
- The existing nominal Scout title-fit test must read `CityDefinition.displayTitle` directly and run in the catalog-authoring task.
- `Kingshield Bastion` exceeds the real narrow-pad nominal budget; City 11 is therefore `Kingshield Keep` before implementation.

## Authored identity table

| City | Name | Trait | Flavor | Conquest title |
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

## Lookup and fallback

Keep clamped `Country1CityCatalog.definition(for:)` for gameplay. Add non-clamping `definitionIfPresent(for:)` for display fallback.

Current-state UI keeps `KingdomGameState.displayCityTitle(for:)` and legacy `Country N - City M` for unsupported values.

Persisted report copy derives from the record key, not ambient state:

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

`project(from:)` resolves `finalCityName` from constant catalog City 15. The SpriteKit node only renders supplied content.

## Non-blocking flavor

Current transient feedback blocks Attack in three places: scene entry eligibility, node `attackHitFrame`, and a full-card overlay that wins before the Attack touch check.

Minimal extension:

1. `CountryMapScoutCardLayout.nonBlockingOverlayFrame` covers informational content and excludes `attackFrame`; current `overlayFrame` remains full-card blocking feedback.
2. `CountryMapTransientFeedback.Kind.flavor` is the only kind with `blocksScoutEntry == false`.
3. Scene entry remains enabled for flavor.
4. `CountryMapScoutCardNode.applyFeedback(..., blocksAttack:)` uses the non-blocking frame and preserves Attack for flavor; existing feedback keeps full overlay + Attack suppression.
5. Scene tests tap Attack before flavor expires.

No new modal, controller, scene, timer, or durable state.

## Map copy

Locked/completed feedback uses authored display titles. Idle conquest shows the next authored title. Final Country 1 copy is `Country 1 conquered · Crownspire Keep` on the card and `Country 1 conquered at Crownspire Keep.` for final idle feedback.

## Battle and Building

Battle HUD/tooltip and existing Building View conquest feedback continue to consume shared display titles.

`ConquestReportContent.project` becomes `project(from:title:)`. BattleScene passes `KingdomGameState.displayConquestTitle(for: result.cityKey)`, deleting the current country-complete title branch while preserving report rows, restoration, effects, Continue ordering, persistence, and routing.

## Testing

- Task 1: exact table, unique/length bounds, unchanged combat metadata, optional lookup, nominal title fit from `definition.displayTitle`.
- Shared projection/report: authored current titles/fallback, result-key report formatting, Scout flavor payload, Battle/Building exact copy, caller-owned report title, both final-country Battle paths.
- Country Map: pure final-country payload, named feedback, body flavor with no mutation/SFX/route, Attack still routes while flavor is visible, current blocking feedback still blocks.
- Fit acceptance: existing dense matrix, all flavors through non-blocking overlay, named blocking strings through existing overlay.

## Risks

1. Real title budget: Task 1 nominal fit; `Kingshield Keep` replaces overflow before downstream hard-coding.
2. Flavor blocks Attack: address all three blockers and test Attack before expiry.
3. Final-country drift: report copy from `BattleResult.cityKey`; Battle/map tests lock separate city/country semantics.
4. Stale exact strings: update known sibling suites atomically; repository search is final backstop.
5. Transient fit: enumerate authored strings as cheap regression coverage.

## Manual smoke

Seed/play City 1→15 and verify Scout title/flavor, immediate Attack during flavor, Battle HUD/tooltip, Building View conquest copy, authored report title, named map feedback, City 15 report -> map completion, and unchanged gameplay/reward/lane/routing/SFX/haptics.

## Non-goals

HPA-390 milestone effects, Chronicle persistence, new gameplay/balance, per-city art/theme/music/dialogue/lore, localization, multiple countries/generic content platform, save migration, or malformed-content recovery.