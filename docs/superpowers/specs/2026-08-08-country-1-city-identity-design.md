# HPA-366 Country 1 City Identity Design

## Goal

Make Country 1 feel like a coherent 15-stage journey by giving every existing city a short authored identity and reusing that identity across the current map, battle, and conquest surfaces without adding gameplay mechanics, persistence, or a content framework.

This implements HPA-366 and preserves every existing defense trait, lane profile, HP curve, reward, unlock, building rule, idle rule, and combat behavior.

## Product constraints

- Country 1 remains exactly 15 cities.
- City numbers remain visible in progression-critical titles.
- Identity content must describe atmosphere or the already-existing defense trait without implying mechanics that do not exist.
- No city-specific background, palette, ambience, music, objective, dialogue, cutscene, or branching content is added.
- No identity field is persisted in `KingdomGameState` or `BattleResult`; consumers resolve current authored content from the catalog.
- HPA-390 still owns presentation-only milestone treatment for Cities 5, 10, and 15. HPA-366 adds copy only, not milestone effects.
- The implementation must reuse current UI and transient-feedback surfaces instead of creating another scene or content subsystem.

## Existing architecture

`Country1CityCatalog` is already the authored source of truth for the 15 existing `CityDefinition` values. `CityDefinition` currently stores only `cityNumber`, `defenseTrait`, and `laneDefenseProfile`.

Current consumers already have useful seams:

- `KingdomGameState.displayCityTitle(for:)` supplies titles to Battle and the Scout Card.
- `CountryMapScoutCardContent` projects the unlocked city into the map card.
- `CountryMapTransientFeedback` owns short map feedback.
- `BattleScene` uses `state.displayCityTitle` for the HUD and city tooltip.
- `BattleScene` passes the city title into `ConquestReportContent`.
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

Character limits are an authoring guard, not the only layout guarantee. Tests must also run all authored display titles through the current Scout Card phone and pad fitting path.

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

For final Country 1 completion, reuse City 15 identity in the existing compact final-country copy:

- country-complete Scout Card: `Country 1 conquered · Crownspire Keep`
- final idle completion feedback: `Country 1 conquered at Crownspire Keep.`

HPA-390 may later add milestone animation or visual emphasis, but must reuse the same catalog identity.

## Battle integration

`BattleScene` continues to read `state.displayCityTitle`. Its persistent HUD title and current city-info tooltip therefore gain the authored name without a parallel city-name switch.

No Battle HUD layout is redesigned. Existing label fitting remains authoritative; tests add representative/all-content fit coverage rather than new geometry code.

The city-info tooltip retains its current trait and HP information. HPA-366 changes only the title portion to the shared authored display title.

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

This gives every city its reviewed conquest title, including `Crownspire Keep Falls` for City 15. The subsequent Country Map still owns the separate overall `Country 1 conquered` presentation.

No `BattleResult` schema change is needed because authored copy is deliberately resolved from the catalog at presentation time.

## Error and unsupported-data behavior

Country 1 identity is static source data, so missing names or malformed authored rows are programmer errors covered by tests. Do not add runtime backup tables, JSON recovery, assertions plus fallback registries, or save migration.

Unsupported country/city values use the existing legacy title format through the optional display lookup. Existing clamping lookup remains untouched for gameplay compatibility.

If an authored title fails the existing Scout Card fit path on a supported layout, the existing `requiredContentDoesNotFit` / layout-gate behavior remains authoritative. The content table must be fixed rather than adding a second truncation policy.

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
   - unsupported country/city legacy fallback;
   - Scout projection carries the catalog title and flavor.
3. Scout Card/layout tests
   - all 15 authored display titles fit existing supported phone and pad Scout Card layouts.
4. `CountryMapTransientFeedbackTests` and one representative `CountryMapSceneTests` flow
   - named locked/completed/idle/final-country copy;
   - tapping the Scout Card body shows flavor without mutation or routing.
5. `ConquestReportContentTests` and representative Battle scene coverage
   - report accepts exact caller-provided authored title;
   - City 15 uses `Crownspire Keep Falls` while overall Country completion remains map-owned.

Do not add exhaustive lifecycle, persistence, concurrency, or 15-scene render matrices for static copy.

## Manual smoke

Before HPA-366 is marked complete, play or seed through City 1 to City 15 and verify:

- every Scout Card shows `City N · Name` consistently;
- Scout Card flavor text is readable when requested;
- Battle HUD and city tooltip use the same title;
- conquest report title matches the reviewed table;
- locked/completed/idle map feedback uses the same identity;
- City 15 transitions to the named Country-complete copy;
- no existing trait, lane, reward, building, combat, routing, sound, or haptic behavior changes.

## Non-goals

- HPA-390 milestone animations/effects.
- Campaign Chronicle or persisted completed-city identity copies.
- New gameplay rules, boss behavior, lanes, units, traits, rewards, or balance changes.
- Per-city backgrounds, themes, palettes, music, ambience, dialogue, or lore pages.
- Localization infrastructure.
- Multiple countries or a generic campaign-content framework.
- Save migration or malformed-content recovery machinery.
