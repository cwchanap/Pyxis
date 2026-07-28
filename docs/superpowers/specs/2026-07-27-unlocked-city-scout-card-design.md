# Unlocked-City Scout Card Design

**Issue:** HPA-387  
**Date:** 2026-07-27  
**Status:** Approved in design discussion; pending written-spec review

## Goal

Make the one unlocked Country 1 city understandable before entry without a
selection tap, a new scene, or duplicated combat rules. The country map always
shows either:

- a complete Scout Card for the one unlocked city; or
- a non-interactive country-complete state.

The card explains the city's trait, favorable and disadvantaged soldiers,
exposed lane, and formula-derived reward while preserving the existing
one-thumb path into battle.

## Dependencies and Fixed Contracts

HPA-117 and HPA-361 are complete in the current checkout.

HPA-117 remains authoritative for the country-map shell:

- supported geometry is portrait-only and fails closed through the existing
  app-wide layout gate;
- the canonical backdrop, authored anchors, routes, title/control region, and
  city interaction frames do not change;
- the information region remains 64 points high on phone and 112 points high
  on iPad; and
- the information region remains outside the illustrated map corridor, so the
  card cannot obscure a supported city target.

HPA-361 remains authoritative for Country 1 combat metadata:

- `Country1CityCatalog` owns the 15 immutable `CityDefinition` values;
- favorable and disadvantaged soldiers remain derived from
  `CityDefenseTrait`;
- the exposed lane comes from the definition's `LaneDefenseProfile`; and
- the reward remains derived from `KingdomGameState.goldReward(for:)`.

HPA-387 does not add city names or identity content. Until HPA-366 extends the
display-title API, the card uses the current `Country N - City N` title.

## Scope

### In scope

- Immediately render the unlocked-city Scout Card on map presentation.
- Render all ticket-required information without an expand interaction.
- Let the unlocked node and the card's `Attack` action enter the city.
- Preserve the existing current-city return control and route it through the
  same guarded entry path.
- Prevent duplicate route requests after an entry is accepted.
- Show timed, non-modal locked/completed feedback without replacing card
  content.
- Replace the card with a country-complete state when appropriate.
- Preserve existing idle-progress and recoverable-error feedback through the
  same overlay channel.
- Test every supported layout fixture established by HPA-117.

### Non-goals

- A scouting scene, tutorial page, expansion interaction, or modal.
- City names, flavor, themes, objectives, or milestone treatment.
- Chronicle persistence, completed-city details, or replay.
- Multiple unlocked cities or branching routes.
- New combat, balance, building, save, or offline-progress rules.
- New visual assets or changes to the HPA-117 outer map layout.
- A generic Scout/Chronicle card framework.

## Architecture and Ownership

### Pure content projection

Add a framework-free `CountryMapScoutCardContent` value with two states:

```swift
enum CountryMapScoutCardContent: Equatable {
    struct Scout: Equatable {
        let cityNumber: Int
        let displayTitle: String
        let defenseTrait: CityDefenseTrait
        let exposedLane: BattleLane
        let goldReward: Int
    }

    case scout(Scout)
    case countryComplete(countryNumber: Int)
}
```

`Scout` deliberately stores the trait rather than copied presentation arrays.
Its favorable and disadvantaged soldiers and its concise explanation remain
computed semantics on `CityDefenseTrait`.

The projection accepts a normalized `KingdomGameState`:

1. A country-complete state produces `.countryComplete`.
2. Otherwise, the model identifies the one city whose map status is
   `.unlocked`.
3. The projection looks up that city's `CityDefinition`.
4. It obtains the current display title through a shared game-state helper.
5. It obtains the reward from the existing formula.

Add `KingdomGameState.unlockedMapCityNumber: Int?` as the single convenience
projection for the current map. It resolves through `mapStatus(for:)` rather
than adding a second city-unlock formula.

Both incomplete stages project a Scout Card. In `.battleActive`, the unlocked
city is the current battle city. In `.cityConqueredPendingMap`, the unlocked
city is `completedCityCount + 1`, while `cityNumberInCountry` and `cityLevel`
can still describe the city that was just conquered.

`goldReward(for:)` is level-keyed. For Country 1, the target level assigned by
`startCityFromMap` is `completedCityCount + 1`, which is also the unlocked
city number. The Scout projection therefore passes `unlockedMapCityNumber` as
the target level instead of reading the possibly stale pending-map
`state.cityLevel`. Tests lock this Country 1 equality so a future change to
the level/city mapping cannot silently change Scout rewards.

Refactor the existing `displayCityTitle` property to delegate to:

```swift
func displayCityTitle(for cityNumber: Int) -> String
```

The battle title and Scout title therefore share one current naming API, and a
later HPA-366 change can extend that API without rewriting this scene.

Add `BattleLane.displayName` as framework-free model semantics for `Left`,
`Center`, and `Right`. The scene does not switch on lane values.

No new persisted state is introduced.

### Pure inner-card layout

Add a CoreGraphics-only `CountryMapScoutCardLayout`. Its inputs are:

- the `CountryMapLayout.informationRegionFrame`; and
- the existing `CountryMapLayoutClass`.

It returns scene-coordinate frames for:

- the card panel;
- city-number badge;
- title;
- reward;
- trait name and explanation;
- favorable soldiers;
- disadvantaged soldiers;
- exposed lane;
- Attack action; and
- transient overlay.

The outer `CountryMapLayout` remains unchanged and authoritative. The card
layout only subdivides its information region.

Phone layout constants:

- card frame equals the complete 64-point information region;
- 6-point horizontal outer inset and 2-point vertical outer inset;
- 70×44-point Attack frame, right-aligned and vertically centered;
- 6-point gap between Attack and informational content;
- 22×22-point city-number badge;
- a 22-point header row containing the 22-point badge and one centered
  14-point text slot, with 11-point title type and 10-point reward type;
- a 1-point header/trait gap;
- a 24-point trait row made from two fixed 12-point line slots at 9-point
  type;
- a 1-point trait/footer gap; and
- a 12-point matchup/lane footer made from one 12-point line slot at 9-point
  type.

The two 2-point vertical insets plus `22 + 1 + 24 + 1 + 12` exactly consume
the 64-point phone region. Rows never expand based on content and the outer
information region never grows.

Trait copy word-wraps at spaces into the two fixed line slots. Every current
Country 1 trait name plus exact `shortDescription` must fit those slots at
9 points on the 375×667 fixture. Scene-level font measurement tests cover all
seven traits. If future copy fails that contract, the tests fail and the copy
or layout must be reviewed; the runtime does not silently truncate text,
overlap rows, or change HPA-117 geometry.

iPad layout constants:

- card frame equals the complete 112-point information region;
- 12-point outer inset;
- 96×52-point Attack frame, right-aligned and vertically centered;
- 12-point gap between Attack and informational content;
- 32×32-point city-number badge; and
- the same information hierarchy with larger fonts, icons, and spacing.

For both classes:

- the Attack frame is at least 44×44 points;
- every returned frame is contained by the information region;
- informational frames do not overlap Attack;
- the transient overlay frame equals the card frame; and
- no content-dependent geometry changes the outer map.

### SpriteKit presentation

Add a focused `CountryMapScoutCardNode` presentation component. It owns only:

- the panel, labels, icon nodes, Attack visuals, and overlay visuals;
- application of `CountryMapScoutCardContent` and
  `CountryMapScoutCardLayout`; and
- enabled/disabled visual styling.

It does not load game state, mutate progress, run timers, or route scenes.
This keeps the already-large `CountryMapScene` focused on map orchestration
without prematurely creating a generic map-card framework.

The card node sits at `GameUITheme.Z.hud`. Its base panel and card content use
local z positions 0 and 1; its feedback overlay uses local z position 2, so
the overlay is always above the unchanged content. The existing title/current
city region remains separate.

The current `feedbackPanel`, `feedbackLabel`, `feedbackText`, and
`defaultFeedbackText(for:)` path are removed. `CountryMapScoutCardNode`
replaces the panel/label, and a typed transient-feedback value replaces the
string property. Existing idle-result copy is produced by the new overlay
message projection. DEBUG layout hooks and tests that currently expose
`feedbackPanelFrame` migrate to the card frame.

`CountryMapScene` owns:

- content projection from the current state;
- the outer and inner layouts;
- touch priority;
- transient-message timing;
- persistence;
- entry coordination; and
- the existing router call.

## Card Presentation

The compact phone hierarchy is:

```text
┌ [2] Country 1 - City 2       [gold] 12 ┬────────┐
│ Standard Watch · No counter modifiers  │ ATTACK │
│ + Inf Cav   - Arc Mag   Open: Right    │        │
└────────────────────────────────────────┴────────┘
```

The city-number badge and display title satisfy the separate city-number and
current-title requirements. The header also contains a `gold-burst` icon and
the formula-derived reward.

The trait row displays `CityDefenseTrait.displayName` and the exact
`shortDescription`. On phone it wraps to at most two lines when one line does
not fit; it is never truncated.

The final row contains:

- favorable soldiers, prefixed with `+`;
- disadvantaged soldiers, prefixed with `-`; and
- `Open: <lane>`.

Phone soldier entries use each type's installed `<rawValue>-walk-01` frame and
the first three characters of `SoldierType.displayName` (`Inf`, `Arc`, `Cav`,
`Mag`, and `Sie`). iPad uses the same icon with the full display name. Empty
favorable or disadvantaged arrays display `None`.

The gold icon falls back to `Gold` if unavailable. A missing soldier icon
leaves its short or full text visible. Missing optional card icons never hide
model information and never trigger the map-unavailable gate.

The Attack action is labeled `Attack`. While routing is locked, it is dimmed
and non-interactive.

The country-complete state centers exactly `Country <number> conquered.` in
the same panel and creates no active Attack node or Attack hit frame. The
trailing period preserves the existing country-complete copy.

No new art is required.

## Interaction and Input Priority

`CountryMapScene` handles a completed touch in this order:

1. If battle routing is already in progress, consume the touch.
2. If a visible feedback overlay contains the point, consume the touch.
3. If the Scout Card contains the point:
   - invoke entry only when the enabled Attack frame contains the point;
   - otherwise consume the touch.
4. If the existing current-city control contains the point, request entry
   with `state.cityNumberInCountry`.
5. If the existing city-node lookup resolves a city, classify it with
   `mapStatus(for:)`:
   - `.unlocked` requests entry;
   - `.locked` shows exactly `City N is locked`; and
   - `.completed` shows exactly `City N complete`.
6. Otherwise, do nothing.

Frame-first priority is intentional. A card or overlay touch is consumed even
if a lower-z test node or future decorative node at the same point carries a
city name.

This is a hybrid hit-test change, not a second city-geometry system. Card and
overlay priority use explicit `CGRect.contains(_:)` checks from
`CountryMapScoutCardLayout`. The current-city control uses its production
layout frame. Only after those checks does the scene reuse the existing
`nodes(at:)`/node-name lookup and 44×44 `cityHitTargets` for cities; it does
not retain a parallel dictionary of city `CGRect` values.

Locked and completed node handling does not call `startCityFromMap`, mutate
the in-memory state, or write the store. This remains true after country
completion: map status classifies conquered cities as completed, so tapping
one still shows `City N complete` over the country-complete state.

The shorter completed copy is an intentional HPA-387 behavior change. It
replaces the current `City N complete. <Trait>.` string with the ticket's
exact `City N complete` transient until HPA-367 supplies Chronicle details.

## Unified Entry Flow and Duplicate Protection

The unlocked node, Scout Attack action, and existing current-city control call
one entry function with a city number.

That function:

1. Rejects the request when `isRoutingToBattle` is already true.
2. Reloads the latest state from `KingdomGameStore`.
3. Calls `startCityFromMap(cityNumber)`.
4. For `.entered`, verifies that a router exists before persisting the local
   mutation.
5. Applies the existing foreground/idle settlement.
6. Saves the settled state and refreshes content if settlement no longer
   leaves a battle-active stage.
7. When the stage remains battle-active, sets `isRoutingToBattle = true`
   before invoking `countryMapSceneDidRequestBattle`.
8. Re-renders entry visuals as disabled and then invokes the existing router
   exactly once.

The routing flag remains set for the lifetime of the departing map scene.
There is no completion callback to reset: successful routing replaces the
scene.

If the router is absent, the locally entered state is not saved,
`isRoutingToBattle` remains false, entry visuals remain enabled for retry, and
`Cannot enter city yet.` is shown. If a race changes the entry result,
`.locked` shows `City N is locked`, `.alreadyCompleted` shows
`City N complete`, and `.countryComplete` refreshes the country-complete panel
without an additional transient. None of these outcomes route.

The behavioral guard is authoritative even if a disabled node remains in the
SpriteKit tree during the short routing transition.

## Transient Feedback

The Scout or country-complete content always remains installed beneath the
feedback overlay.

Each transient message has:

- text;
- total duration;
- 0.3-second fade duration;
- elapsed time; and
- derived alpha.

Locked and completed messages:

- are fully opaque for 1.2 seconds;
- fade linearly for 0.3 seconds; and
- are removed at 1.5 seconds total.

Existing idle-progress and recoverable-error messages keep their current copy
but use a 2.5-second presentation:

- fully opaque for 2.2 seconds;
- the same 0.3-second fade; and
- removal at 2.5 seconds.

Removing `defaultFeedbackText(for:)` does not remove its idle-conquest copy.
The replacement overlay-message projection produces:

- `Country N conquered.` after idle settlement completes Country 1;
- `City N: <Trait>` for the newly unlocked city after any other idle
  conquest;
- `Buildings dealt N idle damage.` when damage was dealt without conquest;
  and
- `No building damage while away.` when elapsed idle time dealt no damage.

A new message replaces the current message and restarts its timer. It never
changes the underlying card content.

`CountryMapScene.update(_:)` advances the timer through a small shared private
advance function. A DEBUG test hook calls that same function with an explicit
delta. Tests therefore do not depend on SpriteKit actions advancing without a
render loop.

Map presentation does not show the old default city/trait feedback first. The
Scout Card is the immediate default content.

## Lifecycle and Relayout

`didMove(to:)` continues to reload the store before presentation. Once the
interface exists, the scene computes both layouts and applies content in the
same presentation pass, so no selection tap or intermediate empty state is
required.

`didChangeSize(_:)` recomputes the inner card layout from the latest supported
outer information region. Active feedback retains its remaining duration and
moves with the card.

HPA-117's layout gate remains app-wide and pauses the SpriteKit view. Card
timing therefore pauses with the rest of the scene while the gate is active.
No separate unsupported-layout fallback is added.

Foreground idle settlement refreshes the underlying content first, then
presents the existing idle-result copy through the overlay. If settlement
completes the country, the country-complete state is already underneath that
message.

## Failure Handling

- Unsupported geometry continues through the existing HPA-117 gate.
- Missing `country-map-backdrop` continues through the existing
  map-unavailable gate.
- Invalid authored outer-map data continues to fail without partial geometry.
- Missing optional card icons use text fallbacks.
- Missing router state does not persist a locally entered city.
- Locked/completed input does not mutate or persist progress.
- Country completion has no Attack target.
- The pure content projection does not expose locked future-city definitions
  to SpriteKit nodes.

## Test Design

### Shared HPA-117 fixtures

Move the existing supported country-map fixture definitions into shared test
support so both the pure map tests and Scout scene tests exercise the same
matrix:

- 375×667 small phone;
- 375×812 iPhone mini;
- 393×852 modern phone;
- 440×956 large phone;
- 744×1133 iPad mini;
- 834×1194 11-inch iPad;
- 1032×1376 13-inch iPad;
- 600×1008 Stage Manager;
- 480×1194 narrow iPad; and
- 834×1194 iPad with 50-point side insets.

This is test-only fixture sharing, not a production device whitelist. The
runtime HPA-117 invariants remain authoritative.

### Pure content tests

For each of the 15 possible unlocked cities:

- project the correct city number and shared display title;
- match the exact catalog trait;
- match trait-derived favorable and disadvantaged soldiers;
- match the catalog's exposed lane; and
- match `KingdomGameState.goldReward(for: unlockedMapCityNumber)` as the
  Country 1 target level.

Additional tests cover:

- battle-active state projects the current unlocked city;
- city-conquered-pending-map state projects `completedCityCount + 1` rather
  than the stored completed-city number or level;
- Standard Watch retains empty favorable and disadvantaged arrays;
- country completion projects no Scout data; and
- the projection never includes a locked future city.

### Pure inner-layout tests

For every shared supported fixture:

- compute the production `CountryMapLayout`;
- compute the Scout layout from its information region;
- contain every card frame within that region;
- keep Attack at least 44×44;
- keep informational frames disjoint from Attack;
- keep overlay and card frames identical; and
- verify phone/iPad constants are selected from the layout class.

The phone fixture also asserts the exact vertical partition:
2-point inset, 22-point header, 1-point gap, 24-point trait block, 1-point gap,
12-point footer, and 2-point inset.

### Scene tests

Scene coverage includes:

- Scout content is visible immediately after `didMove(to:)`;
- the unlocked city node enters and routes;
- Attack enters and routes;
- the current-city control uses the unified entry path;
- rapid node/Attack/current-control combinations produce one router call;
- accepted routing disables all three entry visuals;
- locked and completed copy is exact;
- locked/completed input leaves in-memory and stored progress unchanged;
- the underlying Scout or country-complete content does not change while a
  message is visible;
- Standard Watch presents both empty matchup groups as `None`;
- every current trait name plus exact description fits the two 12-point trait
  line slots at 9-point type on the 375×667 fixture;
- alpha is 1 through 1.2 seconds, fades during the final 0.3 seconds, and is
  hidden at 1.5 seconds;
- country completion presents exactly `Country N conquered.`;
- country completion creates no Attack target;
- card background taps are consumed;
- overlay taps at the Attack point are consumed;
- a synthetic lower-z city node beneath the card cannot receive a card touch;
- every shared supported fixture keeps the card visible and Attack tappable;
- missing soldier/gold icons leave text fallbacks; and
- existing missing-backdrop and unsupported-layout paths remain unchanged.

Update the route spy from a Boolean to a call count for exact duplicate-route
assertions.

### Verification

Run with parallel testing disabled:

1. focused content, layout, and `CountryMapSceneTests`;
2. the complete `PyxisTests` target;
3. `PyxisUITests`;
4. SwiftLint with a writable cache path;
5. `git diff --check`; and
6. a simulator smoke covering initial card presentation, Attack, locked and
   completed feedback, and country completion.

The smallest supported phone and every HPA-117 layout remain covered
deterministically even when a matching physical simulator is unavailable.
