# HPA-366 Country 1 City Identity Design

## Goal

Make Country 1 feel like a coherent 15-stage journey by giving every existing city a short authored identity and reusing that identity across the current map, battle, building, and conquest surfaces without adding gameplay mechanics, persistence, or a content framework.

This implements HPA-366 and preserves every existing defense trait, lane profile, HP curve, reward, unlock, building rule, idle rule, and combat behavior.

## Product constraints

- Country 1 remains exactly 15 cities.
- City numbers remain visible in progression-critical titles.
- Identity content must describe atmosphere or the already-existing defense trait without implying mechanics that do not exist.
- No city-specific background, palette, ambience, music, objective, dialogue, cutscene, or branching content is added.
- No identity field is persisted in `KingdomGameState` or `BattleResult`; consumers resolve current authored content from the catalog.
- HPA-390 still owns presentation-only milestone treatment for Cities 5, 10, and 15. HPA-366 adds copy only, not milestone effects.
- The implementation must reuse current UI and transient-feedback surfaces instead of creating another scene or content subsystem.
- Final-city Battle and Country Map copy have distinct jobs: the City 15 Battle report always says `Crownspire Keep Falls`; country-level completion copy appears only after the report on the Country Map. Never show both messages in the Battle report and never omit the country-level map confirmation.

## Existing architecture

`Country1CityCatalog` is already the authored source of truth for the 15 existing `CityDefinition` values. `CityDefinition` currently stores only `cityNumber`, `defenseTrait`, and `laneDefenseProfile`.

Current consumers already have useful seams:

- `KingdomGameState.displayCityTitle(for:)` supplies titles to Battle, Building View feedback, and the Scout Card.
- `CountryMapScoutCardContent` projects the unlocked city into the map card.
- `CountryMapTransientFeedback` owns short map feedback.
- `BattleScene` uses `state.displayCityTitle` for the HUD and city tooltip.
- `BattleScene` passes city/campaign information into `ConquestReportContent`.
- `BuildingViewScene` already embeds `state.displayCityTitle` in building-driven conquest feedback.
- The country-complete Scout Card and idle-completion feedback already have compact final-country presentation paths.

The feature should extend these seams rather than add a new service, repository, manager, registry, or persistence type.

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

### Content limits

The authored Country 1 table must satisfy:

- `name`: non-empty after trimming, at most 18 characters.
- `flavorText`: non-empty after trimming, at most 48 characters.
- `conquestTitle`: non-empty after trimming, at most 24 characters.
- Names are unique case-insensitively.
- All 15 definitions remain in exact city-number order.
- Existing defense traits and lane profiles remain byte-for-byte equivalent by value.

Character limits are an authoring guard, not the only layout guarantee. Existing production-fit tests remain authoritative:

- every authored Scout title must fit at the current nominal 11 pt phone / 16 pt pad title size;
- every authored Scout presentation must continue to pass the existing all-content fixture matrix;
- every authored flavor, locked, completed, and final-country transient string must fit the current single-line feedback overlay at or above its existing 8 pt floor.

If authored copy fails those current fitting rules, shorten the copy. Do not add a new truncation or wrapping policy in HPA-366.

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
| 11 | Kingshield Bastion | Reinforced Keep | A reinforced fortress guards the royal road. | Kingshield Bastion Falls |
| 12 | Ashbridge | Burning Oil | Fire cauldrons guard the last crossing. | Ashbridge Secured |
| 13 | Starveil Citadel | Arcane Ward | Arcane wards protect the capital heights. | Starveil Citadel Falls |
| 14 | Stonecrown | Stone Wall | Massive stone walls ring the royal seat. | Stonecrown Breached |
| 15 | Crownspire Keep | Reinforced Keep | The final keep rises above the capital. | Crownspire Keep Falls |

The sequence intentionally moves from ordinary frontier settlements through increasingly fortified inner territory to the final keep. The language references only existing presentation and defense concepts.

## Catalog lookup and fallback

Keep the existing clamping `Country1CityCatalog.definition(for:)` behavior because current combat compatibility code relies on it.

Add a non-clamping optional lookup for display consumers:

```swift
static func definitionIfPresent(for cityNumber: Int) -> CityDefinition? {
    guard cityRange.contains(cityNumber) else { return nil }
    return definitions[cityNumber - cityRange.lowerBound]
}
```

`KingdomGameState.displayCityTitle(for:)` uses the authored title only when the state is in Country 1 and the requested city exists in the Country 1 catalog:

```swift
func displayCityTitle(for cityNumber: Int) -> String {
    guard countryNumber == 1,
          let definition = Country1CityCatalog.definitionIfPresent(for: cityNumber) else {
        return "Country \(countryNumber) - City \(cityNumber)"
    }
    return definition.displayTitle
}
```

This preserves the current release-safe legacy string for unsupported values without inventing malformed-content recovery for static compiled data.

Add the same concrete fallback for authored conquest copy:

```swift
func displayConquestTitle(for cityNumber: Int) -> String {
    guard countryNumber == 1,
          let definition = Country1CityCatalog.definitionIfPresent(for: cityNumber) else {
        return "\(displayCityTitle(for: cityNumber)) Conquered"
    }
    return definition.conquestTitle
}
```

No generic identity protocol or multi-country catalog abstraction is introduced.

### Country-complete identity invariant

Country-complete presentation always reads the final identity from the authored catalog at `Country1CityCatalog.cityRange.upperBound` (City 15). It must not derive the final name from `state.cityNumberInCountry` and must not route through the optional display fallback. This keeps final-country copy deterministic even if a malformed development state is normalized differently in the future.

## Country Map integration

### Scout Card

`CountryMapScoutCardContent.Scout` gains `flavorText` alongside its existing display title and tactical data. Projection reads both values from the same `CityDefinition`.

The existing Scout Card title therefore changes automatically from `Country 1 - City N` to `City N · Name` without changing the card layout.

The card's existing trait, favorable/disadvantaged units, exposed lane, reward, and Attack action remain unchanged.

Tapping the non-action body of the Scout Card shows that city's `flavorText` through the existing transient feedback overlay. This interaction:

- does not mutate game state;
- does not emit gameplay sound/haptic feedback;
- does not route;
- does not add a new modal or node hierarchy;
- leaves the existing Attack button behavior unchanged after the transient overlay expires.

### Map feedback

Change locked/completed map feedback to accept the resolved display title rather than formatting a bare city number:

- `City 3 · Falconridge is locked`
- `City 12 · Ashbridge complete`

After an idle conquest that unlocks another city, show the newly unlocked authored display title instead of the current `City N: Trait` copy. The Scout Card directly below already communicates the trait and tactical details.

For final Country 1 completion, read City 15 by constant upper bound and reuse its identity in the existing compact final-country paths:

- country-complete Scout Card: `Country 1 conquered · Crownspire Keep`
- final idle completion feedback: `Country 1 conquered at Crownspire Keep.`

HPA-390 may later add milestone animation or visual emphasis, but must reuse the same catalog identity.

## Battle integration

`BattleScene` continues to read `state.displayCityTitle`. Its persistent HUD title and current city-info tooltip therefore gain the authored name without a parallel city-name switch.

No Battle HUD layout is redesigned. Existing label fitting remains authoritative; tests update every hard-coded title expectation that changes and retain existing geometry/fit behavior.

The city-info tooltip retains its current trait and HP information. HPA-366 changes only the title portion to the shared authored display title.

## Building View integration

`BuildingViewScene` already uses `state.displayCityTitle` when building settlement/foreground progress conquers the current city. HPA-366 does not add a new Building View feature; the existing player-facing conquest sentence automatically gains the authored title.

The matching `BuildingViewSceneTests` expectation must change in the same slice as `displayCityTitle` so the shared title producer never leaves a known sibling suite stale.

## Conquest report integration

The current `ConquestReportContent.project` decides its title from `cityTitle` plus `isCountryComplete`. HPA-366 simplifies that responsibility: the caller resolves the exact authored/fallback title, while `ConquestReportContent` continues to project only report rows and achievements.

Change the projection signature to:

```swift
static func project(
    from result: BattleResult,
    title: String
) -> Self
```

and store `title` unchanged in the returned content.

`BattleScene` passes:

```swift
state.displayConquestTitle(for: result.cityKey.cityNumber)
```

This gives every city its reviewed conquest title, including `Crownspire Keep Falls` for City 15.

The product rule is explicit:

- the final-city Battle report always uses `Crownspire Keep Falls`;
- `Country 1 conquered …` copy is map-only after Continue;
- the Battle report never substitutes the country banner for the authored City 15 conquest title;
- both existing BattleScene country-complete report assertions must lock this rule.

No `BattleResult` schema change is needed because authored copy is deliberately resolved from the catalog at presentation time.

## Error and unsupported-data behavior

Country 1 identity is static source data, so missing names or malformed authored rows are programmer errors covered by tests. Do not add runtime backup tables, JSON recovery, assertions plus fallback registries, or save migration.

Unsupported country/city values use the existing legacy title format through the optional display lookup. Existing clamping lookup remains untouched for gameplay compatibility.

If an authored title or transient string fails the existing supported-layout fit path, fix the authored string. Do not add a second truncation/wrapping policy.

## Call-site inventory

Changing the shared title shape has a wider test blast radius than the production change. Update known consumers in the same task that changes their producer rather than deferring everything to the final full-suite run.

Production paths:

- `KingdomGameState.displayCityTitle` / `displayCityTitle(for:)` / new `displayConquestTitle(for:)`;
- `CountryMapScoutCardContent`, `CountryMapScoutCardNode`, `CountryMapScene`;
- `CountryMapTransientFeedback`;
- `BattleScene` HUD, tooltip, and `conquestReportContent(for:)`;
- `BuildingViewScene` building-driven conquest feedback.

Known test surfaces whose locked copy/shape must be reconciled:

- `Country1CityCatalogTests`;
- `KingdomGameStateTests`;
- `CountryMapScoutCardContentTests`;
- `CountryMapScoutCardNodeTests`;
- `CountryMapScoutCardTextLayoutTests`;
- `CountryMapTransientFeedbackTests`;
- `CountryMapSceneTests`;
- `ConquestReportContentTests`;
- `ConquestReportNodeTests` sample content where useful;
- `BattleSceneTests` HUD title, City 3 report, both country-complete report assertions, and city tooltip/visible-HUD strings;
- `BuildingViewSceneTests` building-conquest feedback.

Repository-wide stale-copy search remains a final backstop, not the first time these known call sites are discovered.

## Testing strategy

Use behavior-oriented coverage rather than a scene-by-city matrix.

1. `Country1CityCatalogTests`
   - exact reviewed 15-city identity table;
   - content completeness and length limits;
   - case-insensitive unique names;
   - unchanged defense traits and lane profiles;
   - optional lookup does not clamp.
2. `KingdomGameStateTests` / existing Scout content tests
   - valid Country 1 authored display/conquest title;
   - City 15 returns `Crownspire Keep Falls` even when the state is already `.countryComplete`;
   - unsupported country/city legacy fallback;
   - Scout projection carries catalog title and flavor;
   - country-complete projection reads catalog City 15 by constant upper bound.
3. Scout Card/layout tests
   - run existing `everyTitleAndRewardFitsAtItsNominalSizeInEverySupportedLayout` after the shared title change; it must still return the nominal 11/16 pt sizes for all 15 titles;
   - extend existing `allCurrentContentPresentsAcrossEveryFixtureAndImageOutcome` with authored title/flavor fields; do not add a duplicate title matrix.
4. Transient feedback fit tests
   - loop all 15 `flavorText` strings;
   - loop all 15 `"\(definition.displayTitle) is locked"` strings;
   - loop all 15 `"\(definition.displayTitle) complete"` strings;
   - include both final-country strings plus existing damage/no-damage/error copy;
   - every string must install in the current feedback overlay at or above the existing 8 pt floor.
5. `CountryMapTransientFeedbackTests` and representative `CountryMapSceneTests`
   - named locked/completed/idle/final-country copy;
   - tapping the Scout Card body shows flavor without mutation or routing.
6. `ConquestReportContentTests`, `BattleSceneTests`, and Building View regression coverage
   - report accepts exact caller-provided authored title;
   - City 3 uses `Falconridge Silenced`;
   - both final-city report-host / Continue paths use `Crownspire Keep Falls`;
   - HUD/tooltip/Building View expectations use shared authored display titles;
   - overall Country completion remains map-owned.

Do not add exhaustive lifecycle, persistence, concurrency, or 15-scene render matrices for static copy.

## Risks and controls

### Final-city semantics drift

Risk: a later refactor could restore `Country N Conquered` inside the Battle report and duplicate or replace the City 15 authored outcome.

Control: explicit product rule plus pure title projection test and both existing country-complete BattleScene assertions.

### Silent transient-copy drop

Risk: `CountryMapScoutCardNode.applyFeedback` intentionally hides feedback when text cannot fit even at its 8 pt floor, so one longer authored flavor/edit could silently turn a body tap into no visible output.

Control: enumerate every authored flavor/locked/completed string through the existing feedback-fit test across minimum phone and pad fixtures.

### Stale hard-coded test copy

Risk: shared `displayCityTitle` changes update multiple production consumers automatically while old exact-string tests stay stale until a late full-suite run.

Control: maintain the call-site inventory above, update each known sibling suite in the same implementation task, and keep the final `rg` search as a backstop.

## Manual smoke

Before HPA-366 is marked complete, play or seed through City 1 to City 15 and verify:

- every Scout Card shows `City N · Name` consistently;
- Scout Card flavor text is readable when requested;
- Battle HUD and city tooltip use the same title;
- Building View conquest feedback uses the same title when buildings finish a city;
- conquest report title matches the reviewed table;
- locked/completed/idle map feedback uses the same identity;
- City 15 Battle report says `Crownspire Keep Falls` and only after Continue does the Country Map show `Country 1 conquered · Crownspire Keep`;
- no existing trait, lane, reward, building, combat, routing, sound, or haptic behavior changes.

## Non-goals

- HPA-390 milestone animations/effects.
- Campaign Chronicle or persisted completed-city identity copies.
- New gameplay rules, boss behavior, lanes, units, traits, rewards, or balance changes.
- Per-city backgrounds, themes, palettes, music, ambience, dialogue, or lore pages.
- Localization infrastructure.
- Multiple countries or a generic campaign-content framework.
- Save migration or malformed-content recovery machinery.
