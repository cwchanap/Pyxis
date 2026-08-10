# HPA-390 — Country 1 Milestone Presentation Design

## Status

Approved design for HPA-390: **Add presentation-only milestone treatment for Cities 5, 10, and 15**.

HPA-390 is the final player-visible HPA-360 roadmap slice before the HPA-567 Country 1 validation checkpoint. HPA-366 (Country 1 city identity) and HPA-365 (Recommended Camp guidance) are complete.

This design keeps milestone behavior presentation-only. It does not change combat, rewards, progression, persistence, buildings, lane rules, unit rules, or idle progress.

## Goal

Make Cities 5, 10, and the current Country 1 finale feel like increasingly important campaign moments without adding another gameplay system.

Each milestone receives:

1. a short arrival banner using the existing authored city identity;
2. a static decorative accent around the existing enemy city;
3. a fresh-conquest flourish around the existing conquest report.

The Country 1 finale additionally shows the required text `Country 1 Complete` before Continue returns to the completed map.

The implementation must remain cheap to revise or delete after HPA-567 playtesting.

## Non-goals

HPA-390 does not add:

- boss mechanics or combat-rule changes;
- rewards, unlocks, currencies, objectives, or achievements;
- durable milestone-consumption state or save migration;
- unique backgrounds, cutscenes, dialogue, music, or new art assets;
- a milestone engine, presentation service, protocol hierarchy, registry, or generic theme model;
- milestone presentation for ordinary Country 1 cities;
- a generalized motion-preference system;
- new gameplay SFX or haptic events;
- a new report/content subsystem.

## Existing code to reuse

The repository already owns the required boundaries:

- `Country1CityCatalog` / `CityDefinition` own city name, flavor text, and conquest title.
- `KingdomGameState.firstCountryCityCount` is the authoritative current Country 1 length and therefore the finale identity.
- `BattleScene` owns the enemy-city node, input routing, effects, scene lifecycle, Settings integration, and conquest presentation origin.
- `BattleScene.presentPendingConquestReport(origin:resetsContinueState:)` already distinguishes `.freshLive`, `.freshIdle`, and `.restored`.
- `ConquestReportLayout` is the pure geometry authority for required report layout and already returns `nil` when required geometry cannot fit.
- `ConquestReportNode` owns report typography/content rendering and uses `SingleLineTextFitter` to enforce minimum-font fit.
- `PanelNode` already provides the themed rounded panel needed by the arrival banner.
- `SingleLineTextFitter` is already a shared framework-free minimum-font fitter; HPA-390 must reuse it instead of adding another text-fitting utility.

## Architecture

Use three narrowly scoped extensions:

1. **`Country1MilestoneTier`** — one framework-free enum that maps the current Country 1 milestone city numbers to `.first`, `.second`, or `.finale`.
2. **`ConquestReportLayout`** — one concrete extension for the required finale label: input says whether country-completion content is present, and output provides `countryCompleteFrame`. The pure layout remains the single geometry fail-closed authority.
3. **`BattleScene`** — owns transient SpriteKit presentation: arrival lifetime/input, static enemy-city accent, fresh-only report flourish, required-label rendering, Reduce Motion branching, and same-scene dedupe.

This is a concrete extension of the existing report layout for a shipping required-content consumer, not a general milestone/report framework.

The flow is:

`city -> Country1MilestoneTier -> BattleScene arrival/accent -> existing conquest origin -> ConquestReportLayout required geometry -> BattleScene static report treatment/fresh flourish`

## Milestone selector

Prefer a bare enum rather than a wrapper struct with one field:

```swift
enum Country1MilestoneTier: Int, Equatable {
    case first = 1
    case second = 2
    case finale = 3

    static func forCity(_ cityNumber: Int) -> Self? {
        if cityNumber == KingdomGameState.firstCountryCityCount {
            return .finale
        }
        switch cityNumber {
        case 5: return .first
        case 10: return .second
        default: return nil
        }
    }

    var isCountryFinale: Bool { self == .finale }
}
```

The current catalog has 15 cities, so this selects Cities 5, 10, and 15 today without duplicating a second literal definition of the finale.

The enum contains no strings, colors, durations, persistence, SpriteKit/UIKit, or future-country registry.

## Authored text ownership

Player-facing city copy remains derived from the catalog:

- arrival title: `CityDefinition.displayTitle`;
- arrival subtitle: `CityDefinition.flavorText`;
- conquest title: existing `KingdomGameState.displayConquestTitle(for:)` resolution from `BattleResult.cityKey`;
- finale state: literal `Country 1 Complete` only when the result city is the current Country 1 finale.

No parallel city-name or conquest-message switch is allowed.

HPA-390 intentionally supersedes only HPA-366's earlier presentation rule that overall country completion appears exclusively after Continue. City 15 still uses `Crownspire Keep Falls`, and acknowledgement/save/map routing remain unchanged.

## Arrival banner

### Presentation

When an active `BattleScene` first mounts for a milestone city, show one compact `PanelNode` containing:

- the full authored `City N · Name` title;
- the authored one-line flavor text.

The banner is non-modal: combat simulation continues while it is visible.

Use current theme fonts/colors and `PanelNode`. Do not add an image asset or reusable milestone/banner component.

### Required legibility and fail-open behavior

Arrival is decorative assistance, so it must **fail open** rather than block the scene.

Use `SingleLineTextFitter.fittedFontSize` with an explicit 12pt minimum for both arrival lines. The supported-layout gate must assert the rendered font sizes meet that floor.

If the available banner width is insufficient, either line cannot meet the 12pt floor, or layout otherwise cannot produce a valid banner frame:

- immediately finish/dismiss the arrival presentation;
- clear the visible/intercepting state;
- leave combat and controls usable;
- do not route through the conquest-report unsupported-geometry gate.

No invisible milestone state may consume input.

### Lifetime

- Present at most once for the mounted `BattleScene` instance.
- Target approximately 1.5 seconds total including short transition effects.
- A player tap while visible dismisses the banner and is fully consumed.
- Resize/redraw may reposition the current banner but must not restart its timer or presentation count.
- If a later geometry change makes the visible banner unable to meet its fit contract, dismiss it fail-open.
- Scene reconstruction/relaunch replay is acceptable before public release.
- Do not persist a consumed token.

### Input and accessibility precedence

Touch input remains:

1. conquest report / fit-failure gate;
2. visible milestone arrival;
3. visible Settings modal;
4. Settings gear;
5. normal controls.

The Settings gear also has a VoiceOver activation path that calls `openFeedbackSettings()` directly and bypasses touch precedence. Therefore `openFeedbackSettings()` must synchronously dismiss any visible milestone arrival **without animation** before opening Settings.

Likewise, any conquest report presentation must synchronously remove a visible arrival before applying the report.

A Settings sheet or conquest report must never render underneath a still-intercepting arrival banner.

## Enemy-city accent

Milestone battles receive one static decorative accent around the existing rendered enemy-city frame.

- City 5: thin accent.
- City 10: stronger stroke/glow.
- Finale: strongest stroke/glow.

Reuse the same `SKShapeNode` and fixed tier constants. The accent is intentionally static in HPA-390; looping/pulsing enemy-city animation is deferred unless playtesting provides evidence for it.

The accent:

- derives from `enemyCityNode.calculateAccumulatedFrame()` after normal battlefield layout;
- does not resize/reposition the city;
- does not alter HP-bar, lane, hit, or combat geometry;
- clamps to the current safe/battle presentation region when decoration would extend beyond it;
- never causes fit failure.

## Conquest report required geometry

### One geometry authority

`Country 1 Complete` is required finale content, so its frame belongs in the existing pure `ConquestReportLayout` instead of a separate `BattleScene` preflight.

Extend `ConquestReportLayout.Input` with:

```swift
let includesCountryCompletion: Bool
```

Extend `ConquestReportLayout` with:

```swift
let countryCompleteFrame: CGRect?
```

Keep the existing report panel's height/content unchanged. When `includesCountryCompletion` is true, compute the unchanged report-panel height first, reserve a fixed completion-label height plus gap above it, and center the **label + panel group** as one unit inside `safeFrame`. `panelFrame` still describes only the original report panel; `countryCompleteFrame` describes the required label outside it.

Conceptually:

```text
[ Country 1 Complete ]
        8pt gap
[ existing report panel ]
```

`framesAreContained` validates the optional completion frame along with the existing panel/title/rows/badges/Continue frames.

If the complete group cannot fit, `ConquestReportLayout.compute` returns `nil`. This automatically reaches BattleScene's existing `isConquestReportFitFailed` / `.unsupportedGeometry` path. There is no second scene-owned geometry Boolean and no above/below fallback.

### Typography

`Country 1 Complete` is required text. `BattleScene` positions it at `layout.countryCompleteFrame` and uses the existing `SingleLineTextFitter` with a minimum font floor. If the required literal cannot meet that typography floor, treat the presentation as the same report fit failure and hide the report until supported geometry is restored.

This mirrors the existing split of responsibilities: pure layout owns required rectangles; rendering owns text measurement/legibility.

## Conquest flourish

### Fresh versus restored behavior

The existing report-origin boundary remains the only one-shot gate:

- `.freshLive` milestone result -> flourish once;
- `.freshIdle` milestone result -> flourish once;
- `.restored` milestone result -> static milestone treatment only, no one-shot replay.

`applyPendingConquestReport` may reapply static layout on resize/Continue disable but never starts a flourish or increments its count.

`presentPendingConquestReport` receives the `BattleResult` returned by the successful apply path and passes that same resolved result into the flourish. Do not re-read `state.pendingBattleResult` to make a second city-identity decision.

### Visual treatment

Use one scene-owned `SKShapeNode` around the existing `layout.panelFrame`. Tier controls fixed line/glow strength.

The report accent is decorative:

- clamp it to `layout.safeFrame`;
- keep it outside required report content;
- when finale completion text is present, do not extend the accent into `layout.countryCompleteFrame`;
- never change Continue geometry or cause fit failure.

Fresh flourish may briefly fade/scale this accent. Restored reports show the same accent statically.

## Reduce Motion

Read `UIAccessibility.isReduceMotionEnabled` directly at presentation time.

- Arrival: short fade is always allowed; scale emphasis is omitted when Reduce Motion is enabled.
- Fresh conquest flourish: fade-only under Reduce Motion; short fade/scale otherwise.
- Enemy-city accent: static in both modes.

All milestone meaning is carried by text. Do not add a persisted motion setting or dependency protocol.

## Scene-local state

`BattleScene` may own only the transient state needed for the current scene:

- current milestone tier;
- arrival presented/visible state and scene-owned nodes;
- static city/report accent nodes;
- fresh flourish presented flag;
- finale label node.

None of this state is persisted in `KingdomGameState`, `BattleResult`, `CityDefinition`, or `UserDefaults`.

## Layout verification

### Arrival

Automated BattleScene fit gates cover:

- `568×320`;
- `667×375`;
- existing narrow portrait `320×568`.

At each size:

- banner is contained in the safe/current scene region;
- title/subtitle are contained and non-overlapping;
- each rendered font size is at least 12pt.

An additional deliberately-too-narrow fixture verifies decorative fail-open: the banner becomes non-visible/non-intercepting rather than leaving an invisible tap eater.

### Finale report

The riskiest geometry is tested in **pure** `ConquestReportLayoutTests`, not by booting scenes.

For `568×320`, `667×375`, and `320×568`, maximum current report density (4 summary rows + 2 badges) with `includesCountryCompletion = true` must return a layout where:

- `safeFrame` contains both `panelFrame` and `countryCompleteFrame`;
- `countryCompleteFrame` does not intersect `panelFrame` or `continueFrame`;
- existing report frames retain their normal containment.

A separate boundary test must explicitly prove the discriminator:

- the base 3-row/0-badge report fits at a chosen compact height;
- the same input with `includesCountryCompletion = true` returns `nil` because the reserved completion group does not fit.

Use a boundary with several points of difference (for current compact metrics, 205pt height: base panel 180pt fits; completion group 210pt does not), rather than a half-point threshold.

BattleScene keeps only small integration checks that City 15 renders the label at the supplied layout frame and uses the existing unsupported-geometry route when the layout returns `nil`.

## Risks and go/no-go gates

### Risk 1 — finale required layout

Adding required text could make dense reports unsupported on compact geometry.

Mitigation: `ConquestReportLayout` owns the reservation and fail-closed result. Task 3 is not green until the three supported geometry tests and pure boundary discriminator pass. If they fail, reduce presentation spacing/label metrics within the current simple layout; do not create another layout system.

### Risk 2 — narrow arrival copy

Authored title/flavor could shrink below comfortable reading size.

Mitigation: `SingleLineTextFitter` minimum 12pt plus explicit rendered-font assertions. Unsupported arrival geometry fails open and releases input.

### Risk 3 — accessibility path bypasses touch precedence

VoiceOver can invoke Settings without touching the gear.

Mitigation: `openFeedbackSettings()` dismisses arrival first, and a retained accessibility-element test covers this exact path.

## Error handling

There is no new persistence or external I/O.

- Ordinary cities have no milestone tier or nodes.
- Missing/out-of-scope city identity continues to use existing HPA-366 behavior.
- Decorative arrival failure dismisses fail-open.
- Decorative city/report accent failure hides decoration only.
- Required report geometry/typography failure uses the existing conquest-report unsupported-geometry path.
- No milestone-specific route or recovery mode is added.

## Testing strategy

1. **Pure selector tests** — Cities 5/10/finale mapping, ordinary-city nil, deterministic result.
2. **Pure `ConquestReportLayoutTests`** — country-completion reservation, three supported gates, dense content, fail-closed boundary discriminator, existing no-completion geometry unchanged.
3. **BattleScene behavior tests** — authored arrival copy, non-modal combat, consumed tap, VoiceOver Settings dismissal, fail-open narrow arrival, same-scene dedupe, static city accent, fresh/restored flourish, same resolved result, City 15 label integration, Continue unchanged.
4. **Existing regression suites** — report, Settings, layout, fresh/restored effects, routing, full unit/UI/lint.
5. **Manual smoke** — City 5 -> 10 -> finale, live + idle conquest, restored result, Reduce Motion, compact/narrow layouts.

Avoid broad private-node snapshots and style-constant tests.

## Expected production scope

Create exactly one production file:

- `Pyxis/Country1MilestoneTier.swift`.

Modify only the concrete existing consumers/helpers needed by the shipping slice:

- `Pyxis/BattleScene.swift`;
- `Pyxis/ConquestReportLayout.swift`;
- `CLAUDE.md` ownership guidance.

No `ConquestReportContent`, `ConquestReportNode`, `KingdomGameState` persistence/model mutation, `Country1CityCatalog`, `CityDefinition`, `KingdomGameStore`, `GameViewController`, asset, or `project.pbxproj` change is required.

## Acceptance criteria

- Only City 5, City 10, and the current Country 1 finale receive milestone treatment.
- Milestone city copy comes from the shared definition; no parallel city-name/message switch exists.
- Arrival is readable, non-modal, auto-dismisses, may be skipped by one consumed tap, and does not replay from redraw/resize.
- Arrival failure cannot leave invisible input interception.
- VoiceOver Settings activation dismisses arrival before opening Settings.
- Enemy-city accent is static, presentation-only, and does not alter combat geometry.
- `ConquestReportLayout` is the single required-geometry authority for the finale label and fails closed through its existing `nil` result.
- Required finale text is legible and never silently omitted.
- Fresh live/idle milestone conquests show one flourish; restored reports do not replay it.
- Flourish uses the same resolved `BattleResult` that was successfully applied to the report.
- Finale clearly shows `Country 1 Complete` before the existing Continue route returns to the completed map.
- Required finale content and decorative accents do not obscure or alter Continue.
- Reduced Motion preserves all meaning with static/fade-only treatment.
- No gameplay mutation, reward calculation, progression rule, idle behavior, save schema, durable presentation state, new SFX/haptics, or presentation framework is added.
- Focused pure + scene-flow tests, full unit/UI/lint verification, and manual milestone smoke pass.
