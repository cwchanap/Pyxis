# Country Map Layout Support Design

**Date:** 2026-07-26  
**Last revised:** 2026-07-27  
**Issue:** HPA-117  
**Status:** Approved for implementation planning

## Summary

Pyxis will use **Option A: portrait-only support for the current Country 1 map art**.

The app will declare an app-wide portrait orientation contract. The existing
1024×1536 Country 1 backdrop will continue to aspect-fill the scene, and all 15
city anchors will remain normalized against that displayed backdrop frame so
they stay aligned with the illustrated pads.

Landscape, wide, undersized, or otherwise invalid window geometries will not
receive a remapped or partially clamped map. They will show a blocking
resize/portrait gate. This preserves one authored map contract for the future
Scout and Chronicle interfaces.

## Context

`CountryMapScene` currently has two different positioning behaviors:

- Portrait layouts map city anchors into the cover-scaled backdrop frame and
  preserve exact art alignment.
- Wide layouts may fall back to the visible illustrated region when backdrop
  mapping would place cities behind the title or feedback panels.

The fallback makes the cities visible, but it silently changes the canonical
anchor frame. Scout and Chronicle UI cannot reserve stable information space
while the map switches between two positioning contracts.

The project targets iPhone and iPad with iOS/iPadOS 26.4. Current build settings
declare portrait and landscape orientations, and `GameViewController` returns
all-but-upside-down on iPhone and all orientations on iPad. The map asset is a
portrait 1024×1536 illustration with 15 authored city pads.

## Product Decision

### Chosen: Option A — portrait only

Country 1 keeps its existing portrait art, full-scene aspect-fill backdrop, and
exact pad-aligned anchors. Unsupported layouts are prevented from presenting
interactive gameplay through a deterministic gate.

This option was chosen because:

- The current art and anchors were authored as one portrait composition.
- Pixel alignment is already an intentional, tested behavior.
- Landscape is not a product requirement for Pyxis.
- Scout and Chronicle need one stable information-region contract.
- It avoids new art-production scope and avoids weakening the portrait result.

### Rejected: Option B — shared visible-region mapping

Mapping all anchors into a shared visible region would make wide layouts
playable with one algorithm, but portrait cities would no longer align with the
illustrated pads. It would intentionally discard a current product behavior and
make the artwork read less coherently.

### Rejected: Option C — dedicated wide art and anchors

A dedicated wide asset and authored anchor set could provide a high-quality
landscape experience, but landscape is not required. The additional art,
layout data, review, asset selection, and matrix testing are disproportionate
to the current product need.

### Rejected: current hybrid fallback

The current runtime fallback is not a fourth supported option. It creates two
anchor frames and makes downstream card placement depend on layout-specific
workarounds. The implementation will remove this fallback rather than rename it
as a supported contract.

## Supported Device and Orientation Matrix

### Hardware orientations

| Device family | Supported | Unsupported |
| --- | --- | --- |
| iPhone | Portrait upright | Portrait upside-down, landscape left, landscape right |
| iPad | Portrait upright, portrait upside-down | Landscape left, landscape right |

The matrix applies app-wide, not only while `CountryMapScene` is visible.

### Window geometries

Full-screen portrait iPhone and iPad layouts are supported. A resizable iPad
window is supported only when:

1. its scene size is at least 375×667 points;
2. the title/control region, its current-city control, and the information
   region are contained inside the scene after applying semantic safe-area
   insets;
3. every 44×44-point city render and interaction frame is contained inside the
   illustrated map region; and
4. every route segment's stroke-expanded bounds are contained inside the
   illustrated map region.

Representative supported fixtures are:

| Class | Scene size | Test safe insets (top/bottom) |
| --- | --- | --- |
| Smallest supported phone | 375×667 | 0/0 |
| iPhone 12/13 mini | 375×812 | 50/34 |
| Modern phone | 393×852 | 59/34 |
| Large phone | 440×956 | 62/34 |
| iPad mini portrait | 744×1133 | 24/20 |
| 11-inch iPad portrait | 834×1194 | 24/20 |
| 13-inch iPad portrait | 1032×1376 | 24/20 |
| Stage Manager/resizable iPad window | 600×1008 | 28/20 |
| Narrow portrait iPad window | 480×1194 | 24/20 |

Representative unsupported fixtures are:

| Class | Scene size |
| --- | --- |
| Phone landscape | 667×375 |
| iPad landscape | 1194×834 |
| Wide iPad Split View | 678×834 |
| Wide iPad layout | 1024×768 |
| Square window | 700×700 |
| Undersized portrait window | 320×568 |
| Over-cropped narrow iPad window | 375×1194 |

The safe-area values above are deterministic test inputs, not promises about
every system configuration. The fixture list is test coverage, while the four
validation rules are the runtime authority. Unexpected safe-area or window
configurations fail closed to the unsupported-layout gate.

Every representative supported fixture must retain at least 8 points of
additional city-frame headroom inside the illustrated map region after the
runtime containment rules pass. This is a regression budget for authored
constants, not an additional runtime rejection rule for intermediate window
sizes.

The 375×667 dimension floor is necessary but not sufficient. For a
height-driven aspect-fill window, City 2 is the horizontally limiting city.
Keeping its complete 44-point frame inside the scene requires approximately
`sceneWidth >= 44 + 0.33707 * sceneHeight`. The invariant computation remains
the authority instead of reducing support to a fixed minimum width.

City 1 supplies the corresponding bottom constraint:

```text
0.1696 * sceneHeight - 22
    >= semanticBottomInset + informationRegionHeight + 8
```

For the 375×812 mini fixture with a 34-point bottom inset, a 76-point phone
information region misses this bound by 2.285 points. The 64-point phone region
passes it with 9.715 points of additional fixture headroom.

## Canonical Map Geometry

### Authored coordinate space

The canonical authored frame is the complete 1024×1536
`country-map-backdrop` image. A production
`CountryMapLayoutDefinition.country1` value owns this named backdrop size,
the 15 normalized anchors, the primary route connections, and the decorative
branch definitions. Tests may inject another definition, but production code
does not derive canonical dimensions from a loaded SpriteKit node.

The 15 normalized `authoredCityPadAnchors` remain defined against that complete
source frame. At runtime:

1. Center the backdrop in the scene.
2. Uniformly scale it by
   `max(sceneWidth / 1024, sceneHeight / 1536)`.
3. Treat the resulting displayed backdrop frame as the city-anchor frame.
4. Map each normalized anchor directly into that frame.

There is no alternate anchor frame, per-city clamp, or non-uniform scale.

### Safe-area coordinate contract

`CountryMapLayout` receives semantic scene-edge distances through its own
CoreGraphics-only inset value:

- `top` is the distance from `sceneFrame.maxY`;
- `bottom` is the distance from `sceneFrame.minY`;
- `left` is the distance from `sceneFrame.minX`; and
- `right` is the distance from `sceneFrame.maxX`.

UIKit window coordinates already follow the current interface orientation.
With the app's `.resizeFill` scene configuration, the `SKView` bounds and scene
size use the same point dimensions. The adapter therefore maps
`view.safeAreaInsets.top` to semantic `top` and
`view.safeAreaInsets.bottom` to semantic `bottom`; it does not manually swap
them for upside-down portrait.

The adapter supplies the live UIKit values directly. `CountryMapLayout` does
not use `GameUITheme`'s synthetic tall-phone inset fallback; its explicit title
margin and information-region dimensions provide the baseline spacing when a
system inset is zero.

`GameViewController.viewSafeAreaInsetsDidChange()` asks the presented scene to
recompute its layout so an inset-only change cannot leave stale geometry.

### Backdrop behavior

The backdrop aspect-fills the complete scene and extends behind the title and
information chrome. Cropping is centered. Letterboxing is not used.

The backdrop must cover all four scene edges on every supported layout.

### City and route behavior

All city positions are computed together from the canonical frame. Primary
route lines and the four decorative branch stubs at Cities 3, 6, 9, and 12 are
then derived from the production layout definition. Their endpoints,
stroke-expanded bounds, and line widths are production `CountryMapLayout`
output and participate in the illustrated-region validation.

The existing branch offsets and line widths remain fixed scene-point values
applied after mapping their origin city. They do not scale with the backdrop.
Normalizing or visually re-authoring those decorative stubs is known visual
debt outside HPA-117.

A layout is either wholly supported or wholly gated; individual cities and
route segments are never moved to repair a failed layout.

## Reserved Interface Regions

### Title and control region

The top region keeps the current 66-point title panel. It contains:

- the country title; and
- the current-city return control when a battle is active.

Its width is `max(220, min(sceneWidth - 40, 520))`, centered horizontally.
Its top margin is `max(34, semanticTopInset + 10)`, so its bottom edge is
`sceneHeight - topMargin - 66`. The 34-point non-notched baseline intentionally
moves the current 42-point baseline upward; it is load-bearing on the 375×667
fixture and is not a cosmetic constant to restore independently.

The current-city control receives an interaction frame of at least 44×44
points. Its complete interaction frame must remain inside the title panel, so
the panel is the single title/control exclusion region.

### Map information region

A persistent bottom information region is reserved for current and future map
information:

- 64 points high on iPhone;
- 112 points high on iPad; and
- positioned above the effective bottom safe-area inset.

Its width is `min(sceneWidth - 32, 600)`, centered horizontally, and its bottom
edge is the semantic bottom safe-area inset. The 16-point side margins are an
intentional expansion from the current title-matched 20-point margins, not a
fallback calculation. The 375-point width floor makes this width positive
before the region is computed.

The region is always present even before the Scout or Chronicle feature is
implemented. Until then, the existing feedback panel is horizontally and
vertically centered in the region.

HPA-387 will populate it with the unlocked-city Scout Card. HPA-367 may
temporarily replace the Scout content with a completed-city Chronicle card.
Transient locked/completed feedback uses an overlay layer centered inside this
region, above the unchanged underlying card in z order. It does not move the
map, title, city anchors, or underlying card.

If the reserved region does not leave a valid illustrated map region, the
geometry is unsupported and the gate appears.

### Illustrated map region

The illustrated map region is the full-width vertical corridor between the two
reserved interface regions:

```text
minY = informationRegion.maxY + 8
maxY = titleControlRegion.minY - 8
x = sceneFrame.minX
width = sceneFrame.width
```

The region is invalid when `maxY < minY`. Every complete city interaction
frame and every route segment's stroke-expanded bounds must be contained
inside this rectangle. This full-width rectangle is the sole clearance
authority; separate distance checks against the narrower title and information
panel rectangles are not equivalent and are not used. Because the backdrop
aspect-fills the scene, this region is also fully covered by the displayed
backdrop.

### Supported city chrome

Supported layouts use one non-compact map chrome:

- 15-point city-node radius;
- 12-point city-number labels;
- 66-point title panel;
- 64-point iPhone information region; and
- 112-point iPad information region.

Each city receives a centered 44×44-point interaction/clearance frame. That
frame includes the rendered node, label, and conquered marker for exclusion
validation and provides a stable minimum tap target.

At the 15-point city radius, the conquered marker's center offset is
`(0.74 * 15, 0.62 * 15)` and its square side is `1.35 * 15`. Its farthest
extent is therefore 21.225 points horizontally and 19.425 points vertically,
leaving 0.775 and 2.575 points inside the 22-point half-frame. Scene tests lock
that derived containment so a later radius or marker-size change cannot
silently invalidate the pure layout contract.

The current `isCompactHeight` branch and its alternate node, font, panel, and
anchor-frame rules are removed. Heights below the supported layout floor show
the app-wide gate rather than entering a second layout mode. The supported
fixture tests prove that the fixed chrome and reserved regions pass the full
invariant set.

## Architecture

### `CountryMapLayoutDefinition`

Add a pure `CountryMapLayoutDefinition` value containing:

- `canonicalBackdropSize`;
- the 15 normalized city anchors;
- the 14 primary city-to-city route connections; and
- the four authored decorative branch origins, offsets, and line widths.

`CountryMapLayoutDefinition.country1` is the single production home for these
authored values. `CountryMapLayout` validates the complete definition before
using it, without loading UIKit or SpriteKit assets.

### `CountryMapLayout`

Add a pure `CountryMapLayout` value type that imports only CoreGraphics,
following the established `BattlefieldLayout` pattern.

Its input constraints include:

- scene size;
- live semantic safe-area insets;
- a phone or iPad layout class supplied by the UIKit adapter;
- a `CountryMapLayoutDefinition`;
- city render and interaction bounds;
- title-region dimensions; and
- information-region dimensions.

Its output includes:

- support status and failure reason;
- scene frame;
- displayed backdrop frame;
- title/control region frame;
- current-city control interaction frame;
- illustrated map region frame;
- information region frame;
- all 15 city positions; and
- route geometry.

The type performs the complete invariant check. Definition validation uses a
guarded failure path that returns `.unsupported(.invalidAuthoredData)`.
`CountryMapScene` raises `assertionFailure` when it receives that result in a
development build; with assertions disabled, it continues into the production
`Map unavailable` gate. It does not use the current release-trapping
`precondition`.

Texture availability is not an input to the pure layout computation. A missing
backdrop is detected separately by `CountryMapScene` and requests the
`Map unavailable` gate without changing a valid layout result.

`CountryMapScene` does not choose a fallback when the result is unsupported.

### `CountryMapScene`

`CountryMapScene` requests a layout whenever it moves to a view or its size
changes. For a supported result it applies all frames and positions together.
It removes the current compact-height path and wide anchor-frame fallback.

The scene exposes the production information-region frame to the later Scout
and Chronicle work. Testing accessors should project production layout output
rather than reconstructing layout rules in test-only code.

### App-wide orientation and layout gate

The project orientation declarations become:

- iPhone: `UIInterfaceOrientationPortrait`;
- iPad: `UIInterfaceOrientationPortrait` and
  `UIInterfaceOrientationPortraitUpsideDown`.

`GameViewController.supportedInterfaceOrientations` returns the matching mask.
`GameViewController.preferredInterfaceOrientationForPresentation` returns
`.portrait` as an advisory preference for presentation contexts that consult
it. The generated Info.plist declarations and
`supportedInterfaceOrientations` mask are authoritative for the root window.
The controller does not request a persistent interface-orientation lock because
iPad must remain free to rotate between its two supported portrait directions.

The UIKit adapter maps `view.traitCollection.userInterfaceIdiom` directly:
`.phone` produces the phone layout class, `.pad` produces the iPad layout
class, and any other idiom is unsupported. It never infers the device family
from horizontal size class or window width, so a narrow iPad window continues
to use iPad information-region dimensions.

`GameViewController` owns a UIKit overlay above the `SKView` for unsupported
geometry. The overlay:

- says “Pyxis needs a supported portrait window. Rotate or resize to
  continue.”;
- intercepts all input;
- sets `SKView.isPaused = true` while visible, suppressing SpriteKit
  `update(_:)` delivery;
- contains no gameplay actions; and
- disappears automatically when geometry becomes supported.

The controller intentionally uses the Country 1 map layout policy as the
app-wide product floor. This is a chosen support contract, not a minimum
derived from the defensive Battle or Building layouts. Those scenes may render
at smaller sizes in isolated tests while the normally mounted app still gates
them.

HPA-117 covers the only implemented country map. A future country must define
and review its own authored layout policy and update the app-wide support
contract and fixture matrix before shipping; it does not implicitly inherit
Country 1's anchors, nor does this work pre-build a multi-country union policy.

`BattleScene` and `BuildingViewScene` may retain their defensive compact-layout
math for direct scene tests and unexpected isolated use. The controller gate is
the only production unsupported-geometry experience; it prevents interactive
gameplay from reaching those branches when the app is mounted normally.

The implementation does not set `UISceneSizeRestrictions`. A fixed minimum
size cannot represent the aspect-dependent cropping boundary, so the runtime
layout policy remains the sole geometry authority.

The implementation does not add `UIRequiresFullScreen`. Its compatibility mode
is deprecated on iPadOS 26 and cannot serve as the durable layout contract.

## Resize and Rotation Flow

For initial presentation, rotation, split-view changes, Stage Manager changes,
or interactive window resize:

1. From `viewDidLayoutSubviews()` or `viewSafeAreaInsetsDidChange()`, read the
   latest `SKView.bounds.size`, live safe-area values, and interface idiom.
2. Compute the complete Country 1 `CountryMapLayout` policy regardless of which
   gameplay scene is mounted.
3. On the supported-to-unsupported transition, call the mounted scene's dated
   gate-pause hook, set `SKView.isPaused = true`, disable scene input, and show
   the blocking overlay.
4. If supported, apply any scene layout while the overlay still intercepts
   input, invoke the dated gate-resume hook, hide the overlay, enable scene
   input, and finally set `SKView.isPaused = false`.

The currently presented scene remains mounted. Returning from unsupported to
supported geometry recomputes from authoritative state and anchors; it does not
reuse transformed positions from the unsupported size.

The gated wall-clock interval itself never awards resources, applies damage, or
advances campaign state. Entering the gate from `CountryMapScene` or
`BuildingViewScene` may settle building production already earned before the
gate appeared, and leaving it re-arms inactive building progress from the
resume time. Those dated bookkeeping mutations are required to exclude the
gated interval rather than accidentally treating it as offline production.

`LayoutGateLifecycleHandling` provides
`layoutGateWillPause(at:)` and `layoutGateWillResume(at:)`:

- `BattleScene` performs no pause mutation and sets `lastUpdateTime = nil` on
  resume. Its first resumed `update(_:)` primes the timestamp and applies no
  combat delta.
- `CountryMapScene` and `BuildingViewScene` settle their legitimate pre-gate
  inactive-building interval at gate entry, save the result, and re-arm
  inactive progress at gate exit only when battle remains active.
- Repeated layout callbacks while already gated do not settle or re-arm again.

If the app actually enters the system background while the gate is visible,
the mounted scene starts inactive progress at the real background timestamp,
resolves it at the real foreground timestamp, and does not re-arm until the
layout gate later resumes. Existing idle-production rules, including the
eight-hour cap, remain authoritative for that true system-background interval;
the gate-only intervals before and after it remain excluded.

## Failure Handling

- Unsupported geometry shows the resize/portrait gate with an
  `.unsupportedGeometry` reason.
- Unexpected safe-area values that violate layout invariants also show the
  gate.
- A missing backdrop or malformed authored anchor set triggers an assertion in
  development.
- In release builds, a missing backdrop or
  `.unsupported(.invalidAuthoredData)` result is translated by the scene into
  a separate `.mapUnavailable` gate with “Map unavailable” copy. Missing
  textures never become a pure `CountryMapLayout` failure reason.
- No failure path clamps individual cities, awards resources, enters a city, or
  changes campaign progression.

## Testing

### Pure layout tests

For every supported fixture:

- the backdrop uniformly aspect-fills all scene edges;
- all 15 positions match the canonical displayed-backdrop mapping within
  1 point;
- every complete city render and interaction frame is contained inside the
  illustrated map region;
- route geometry remains inside the illustrated map region; and
- title, the complete current-city interaction frame, and the information
  region remain inside safe bounds.

Each representative supported fixture also asserts at least 8 points of
additional city-frame headroom inside the illustrated map region. The
375×812 mini fixture specifically guards the bottom constraint that the prior
76-point information region violated.

For every unsupported fixture, the result is unsupported and no partial
position set is returned.

Tests cover both iPad portrait directions with asymmetric semantic scene-edge
insets as UIKit reports them. They verify that no orientation-specific manual
swap or synthetic tall-phone override is applied.

Malformed definitions return `.unsupported(.invalidAuthoredData)` from the
pure layout computation without producing partial geometry.

### Scene and controller tests

- `CountryMapScene` applies production layout output without a wide fallback.
- City centers remain tappable for Cities 1 through 15.
- The information-region frame is stable and available to future card work.
- The existing feedback panel is centered inside the information region.
- Supported → unsupported → supported resizing toggles the gate atomically.
- Gate input never reaches SpriteKit nodes.
- `SKView.isPaused` is true while gated and false after resuming.
- The first resumed `BattleScene.update(_:)` primes its clock and applies zero
  paused-time combat delta.
- Country Map and Building View tests prove pre-gate building progress is
  settled, gate-only time is excluded, post-gate progress is re-armed, and a
  true system-background interval nested inside the gate still resolves.
- No damage, resources, or campaign progression is caused by the gate-only
  interval.
- Every conquered-marker frame remains inside its city's 44×44 clearance
  frame.
- The backdrop asset is installed at 1024×1536.
- Exactly 15 authored anchors are installed.
- Project and controller orientation masks match the approved matrix.
- A normally mounted `BattleScene` or `BuildingViewScene` is gated at
  unsupported geometry even though its defensive compact calculations remain
  independently testable.
- A malformed definition and a missing backdrop exercise distinct
  `.invalidAuthoredData` and `.mapUnavailable` paths.

The existing
`compactLandscapeLayoutKeepsCityNodesInsideMapArea` and
`wideLayoutClampsCityAnchorsToVisibleMapRegion` tests are replaced with
unsupported-layout gate assertions. The six current
`mapLayoutFramesForTesting` call sites migrate to production
`CountryMapLayout` output; tests do not reconstruct layout frames from
SpriteKit nodes.

Run unit and UI tests with parallel testing disabled.

### Manual smoke

On the 375×667 phone, 375×812 mini, and 1032×1376 iPad fixtures:

- verify Cities 1, 8, and 15 are visible and tappable;
- verify every city is centered on its illustrated pad;
- verify title and information regions do not overlap the route;
- verify iPad upside-down rotation preserves the layout;
- verify a wide resize shows the gate and blocks interaction; and
- verify returning to supported portrait geometry restores the same state.

Manual iPad coverage includes the supported 480×1194 narrow portrait window,
the over-cropped 375×1194 narrow window that must gate, one wide window that
must gate, and the supported 600×1008 Stage Manager fixture.

## Linear Completion Evidence

Before HPA-117 is closed, add a Linear update that records:

- Option A as chosen;
- Options B, C, and the current hybrid fallback as rejected;
- the supported device, orientation, and window matrix;
- this specification and the implementation plan;
- automated test results; and
- manual-smoke evidence.

HPA-387 and the map-UI portion of HPA-367 may proceed only after the
implementation and verification for this contract are complete.

## Non-Goals

- Implementing the Scout Card.
- Implementing Chronicle records or the completed-city card.
- Redesigning campaign progression or route topology.
- Adding a landscape map asset.
- Supporting landscape gameplay.
- Per-city runtime clamping.
- Re-authoring or normalizing the fixed decorative branch offsets.
- Changing city unlock rules or adding multiple unlocked cities.
- Removing `BattlefieldLayout`'s defensive collapsed-layout behavior; the
  app-wide gate normally keeps production scenes above that threshold, but the
  pure fallback remains valid and tested.
