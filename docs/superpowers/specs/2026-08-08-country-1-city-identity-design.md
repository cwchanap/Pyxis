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

The sequence intentionally moves from ordinary frontier settlements through increasingly fortified inner territory to the final keep. The language references only existing presentation and defense concepts.

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

Do not use the ambient `KingdomGameState.countryNumber` to title a persisted conquest result. The report's `BattleResult.cityKey` is the source of truth for both country and city:

```swift
static func displayConquestTitle(for cityKey: CityKey) -> String {
    guard cityKey.countryNumber == 1,
          let definition = Country1CityCatalog.definitionIfPresent(for: cityKey.cityNumber) else {
        return "Country \(cityKey.countryNumber) - City \(cityKey.cityNumber) Conquered"
    }
    return definition.conquestTitle
}
```

This helper lives with the existing campaign display formatting, but its output depends only on the supplied `CityKey`; it does not read mutable/current campaign state.

No generic identity protocol or multi-country abstraction is introduced.

## Country Map projection

### Scout content

`CountryMapScoutCardContent.Scout` gains `flavorText` alongside its current display title and tactical data. Projection reads both from the same `CityDefinition`.

For country completion, keep final identity inside the pure projection rather than reading the catalog from the SpriteKit node:

```swift
case countryComplete(countryNumber: Int, finalCityName: String)
```

`project(from:)` always resolves `finalCityName` from `Country1CityCatalog.cityRange.upperBound` (City 15). It must not derive the final name from `state.cityNumberInCountry` or an optional display fallback.

This keeps the node render-only and makes final-country content testable with a pure `#expect`.

### Scout Card title

The current Scout title changes from `Country 1 - City N` to `City N · Name`. The card's trait, favorable/disadvantaged units, exposed lane, reward, and Attack action remain unchanged.

### Non-blocking flavor interaction

Tapping the non-action body of the Scout Card shows that city's `flavorText`, but flavor is **informational, not modal**. The existing Attack action must remain visible and tappable for the whole flavor duration.

Current transient feedback cannot be reused unchanged: today `CountryMapScene.redraw()` disables entry whenever any `transientFeedback` exists, `CountryMapScoutCardNode.applyFeedback` sets `attackHitFrame = nil`, and `overlayFrame` covers the whole card so the overlay touch guard wins before Attack. HPA-366 must address all three behaviors for flavor while preserving existing blocking behavior for locked/completed/error feedback.

Use the smallest targeted extension:

1. `CountryMapScoutCardLayout` gains one pure `nonBlockingOverlayFrame` that covers the informational portion of the card and stops before the Attack column. Existing `overlayFrame` remains the full-card blocking frame for current feedback behavior.
2. `CountryMapTransientFeedback.Kind` gains `.flavor`, with a small derived `blocksScoutEntry` property that is `false` only for `.flavor` and `true` for current blocking feedback kinds.
3. `CountryMapTransientFeedback.flavor(_:)` owns the existing transient timing; no separate timer or controller is added.
4. `CountryMapScene.redraw()` keeps Scout entry enabled while flavor is visible by checking `blocksScoutEntry` instead of `transientFeedback == nil`.
5. `CountryMapScoutCardNode.applyFeedback` accepts whether the presentation blocks Attack. Blocking feedback keeps today's full overlay and clears `attackHitFrame`. Flavor uses `nonBlockingOverlayFrame` and preserves/restores the current Attack hit frame.
6. `overlayHitFrame` for flavor is only the non-blocking informational frame. A tap inside that flavor overlay is consumed, while a tap in `attackFrame` still reaches `requestProjectedScoutEntry()`.

No new modal, label hierarchy, scene, or persistence state is added.

Tests must prove that after a body tap shows flavor:

- game state is unchanged;
- no gameplay SFX/haptic event is emitted;
- no route occurs from the body tap;
- flavor text is visible;
- `scoutCardAttackHitFrameForTesting` remains non-nil;
- tapping Attack **before flavor expires** routes exactly once;
- blocking locked/completed/error feedback retains its existing Attack suppression and full-overlay consumption.

## Map feedback

Locked/completed feedback accepts the resolved display title rather than formatting a bare number:

- `City 3 · Falconridge is locked`
- `City 12 · Ashbridge complete`

After an idle conquest that unlocks another city, show the newly unlocked authored display title instead of `City N: Trait`; the Scout Card already presents the trait/tactical details.

Final Country 1 completion uses the final projected identity:

- country-complete Scout Card: `Country 1 conquered · Crownspire Keep`
- final idle completion feedback: `Country 1 conquered at Crownspire Keep.`

HPA-390 may later add milestone animation or visual emphasis, but must reuse the same catalog identity.

## Battle integration

`BattleScene` continues to read `state.displayCityTitle` for its persistent HUD title and current city-info tooltip. No HUD layout is redesigned.

For conquest reports, simplify `ConquestReportContent.project` to accept the exact caller-owned title:

```swift
static func project(
    from result: BattleResult,
    title: String
) -> Self
```

and store `title` unchanged.

The production caller resolves the title from the result record, not ambient state:

```swift
private func conquestReportContent(for result: BattleResult) -> ConquestReportContent {
    .project(
        from: result,
        title: KingdomGameState.displayConquestTitle(for: result.cityKey)
    )
}
```

This removes the current `isCountryComplete` title-format branch while preserving report rows, achievements, persistence, restoration, effects, Continue ordering, and routing.

The final-city product rule is explicit:

- City 15 Battle report = `Crownspire Keep Falls`;
- `Country 1 conquered …` copy is map-only after Continue;
- both existing BattleScene country-complete report assertions lock this rule.

## Building View integration

`BuildingViewScene` already uses `state.displayCityTitle` when building settlement/foreground progress conquers the current city. HPA-366 adds no Building View subsystem; the existing sentence automatically gains the authored title.

The matching `BuildingViewSceneTests` expectation changes in the same atomic slice as the shared title producer.

## Call-site inventory

Production paths:

- `CityDefinition` / `Country1CityCatalog`;
- `KingdomGameState.displayCityTitle(for:)` / static `displayConquestTitle(for:)`;
- `CountryMapScoutCardContent`;
- `CountryMapScoutCardLayout`;
- `CountryMapScoutCardNode`;
- `CountryMapTransientFeedback`;
- `CountryMapScene`;
- `BattleScene`;
- `BuildingViewScene` existing shared-title consumer;
- `ConquestReportContent`.

Known test surfaces whose exact copy/shape must be reconciled:

- `Country1CityCatalogTests`;
- `KingdomGameStateTests`;
- `CountryMapScoutCardContentTests`;
- `CountryMapScoutCardLayoutTests`;
- `CountryMapScoutCardNodeTests`;
- `CountryMapScoutCardTextLayoutTests`;
- `CountryMapScoutCardAcceptanceTests`;
- `CountryMapTransientFeedbackTests`;
- `CountryMapSceneTests`;
- `ConquestReportContentTests`;
- `ConquestReportNodeTests` sample content;
- `BattleSceneTests` HUD/tooltip, City 3 report, and both country-complete report assertions;
- `BuildingViewSceneTests` building-conquest feedback.

Repository-wide stale-copy search is a final backstop, not the first time these known call sites are discovered.

## Testing strategy

### 1. Authoring gate — same slice as the table

- Exact reviewed 15-city table.
- Completeness, case-insensitive unique names, coarse character limits.
- Existing trait/lane metadata unchanged.
- `definitionIfPresent(for:)` does not clamp.
- Existing `everyTitleAndRewardFitsAtItsNominalSizeInEverySupportedLayout` reads `definition.displayTitle` directly and passes for every supported fixture at nominal 11/16 pt title size.

This gate catches content/layout mistakes before later tasks hard-code the authored table elsewhere.

### 2. Shared projection/report atom

- Valid Country 1 display title.
- Unsupported country/city fallback.
- `KingdomGameState.displayConquestTitle(for: CityKey(...))` uses both components of the supplied record key.
- City 15 key yields `Crownspire Keep Falls`.
- Scout projection carries title + flavor.
- Battle HUD/tooltip and Building View exact-copy expectations move with the shared producer.
- `ConquestReportContent` accepts exact caller-provided title.
- Both final-country Battle report paths remain `Crownspire Keep Falls`.

### 3. Country Map behavior

- Pure country-complete projection returns `finalCityName: "Crownspire Keep"` from constant catalog City 15.
- Named locked/completed/idle/final-country copy.
- Body tap shows flavor without mutation, routing, or gameplay feedback.
- Attack remains enabled and routes during the flavor lifetime.
- Existing blocking feedback still suppresses Attack and consumes the full overlay.

### 4. Fit acceptance

- Existing all-content presentation matrix carries authored title + flavor.
- All 15 flavors fit the new `nonBlockingOverlayFrame` at the current feedback floor/nominal sizing.
- All 15 named locked/completed strings and final-country strings fit the existing blocking overlay.
- No duplicate all-title matrix is added.

## Risks and controls

### Authored title exceeds the real layout budget

Risk: a name can satisfy a character limit yet overflow the narrow-pad 198 pt nominal title frame.

Control: run the existing nominal title-fit test in Task 1 against `CityDefinition.displayTitle`; the authored table is not accepted until that gate is green. City 11 is shortened to `Kingshield Keep` before implementation.

### Flavor accidentally blocks the primary Attack action

Risk: existing transient feedback disables entry, clears the Attack hit frame, and covers the whole Scout Card. Reusing it unchanged would make Attack unresponsive for the flavor duration.

Control: flavor gets one non-blocking feedback mode, a pure informational overlay frame excluding Attack, entry stays enabled, and a scene test taps Attack while flavor is still visible.

### Final-city semantics drift

Risk: a later refactor could restore `Country N Conquered` inside the Battle report and duplicate or replace the City 15 authored outcome.

Control: result-key-based conquest title projection plus both existing final-country BattleScene assertions.

### Stale hard-coded test copy

Risk: shared title changes update production consumers automatically while old exact-string tests remain stale.

Control: update the known inventory in the same task as its producer and keep repository-wide `rg` searches as a backstop.

### Transient-copy fit regression

Risk: a later authored copy edit could exceed the existing one-line feedback fit floor.

Control: enumerate all authored flavor/locked/completed/final strings through existing fit helpers. This is a cheap backstop, not the primary layout risk.

## Manual smoke

Before HPA-366 is marked complete, play or seed City 1 through City 15 and verify:

- every Scout Card shows `City N · Name`;
- body tap shows the reviewed flavor text;
- Attack remains immediately tappable while flavor is visible;
- Battle HUD and city tooltip use the same title;
- Building View conquest feedback uses the same title when buildings finish a city;
- conquest report matches the reviewed conquest title;
- locked/completed/idle map feedback uses the same identity;
- City 15 report says `Crownspire Keep Falls`, then the Country Map shows `Country 1 conquered · Crownspire Keep`;
- no trait, lane, reward, building, combat, routing, sound, or haptic behavior changes.

## Non-goals

- HPA-390 milestone animations/effects.
- Campaign Chronicle or persisted completed-city identity copies.
- New gameplay rules, boss behavior, lanes, units, traits, rewards, or balance changes.
- Per-city backgrounds, themes, palettes, music, ambience, dialogue, or lore pages.
- Localization infrastructure.
- Multiple countries or a generic campaign-content framework.
- Save migration or malformed-content recovery machinery.