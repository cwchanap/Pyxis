# Compact Conquest Report Design

**Issue:** HPA-388  
**Status:** Final review incorporated; awaiting approval for implementation planning  
**Date:** 2026-07-30

## Goal

Present the persisted `BattleResult` as a short, satisfying conquest report without recomputing combat statistics in SpriteKit, changing reward or progression semantics, or adding a secondary details flow.

The report must:

- Distinguish live conquest from building-driven conquest.
- Show no more than four summary text rows.
- Restore identically whenever `pendingBattleResult` survives a scene transition or relaunch.
- Play conquest feedback only for an original Battle Scene presentation.
- Acknowledge, save, and route exactly once when Continue is activated.

## Existing Contracts

HPA-363 already provides the authoritative model boundary:

- `BattleResult` contains `cityKey`, explicit `conquestMode`, active battle duration, normalized deployment/damage/loss summaries, optional MVP values, achievement markers, and authoritative gold earned.
- `KingdomGameState.pendingBattleResult` persists the report until acknowledgment.
- `acknowledgePendingBattleResult()` clears only the pending presentation value; it does not award gold or change completed progress.
- Gold and stage completion occur before report presentation.
- Settlement conquest and Building View idle conquest finalize as `conquestMode == .idle`.
- State normalization drops a pending result whose city key or stage is incompatible.

The current UI is a legacy `BattleScene` popup with a title, one gold label, and Continue. Both live and Battle Scene idle paths pass transient `goldEarned` values into the popup, every presentation starts the gold burst, Continue routes without acknowledging or saving, and conquered-stage routing currently skips a pending report.

## Product Decisions

### Report copy

The report has exactly four possible row slots:

1. `Gold earned: +<amount>`
2. Live: `Battle time: <active duration>`; idle: `Conquered by your buildings`
3. Optional: `MVP: <soldier type> · <damage share>%`
4. `Deployed: <count> · Lost: <count>`

When MVP is absent, row 3 is removed and the final row moves up. The report therefore contains three or four visible summary rows and never more than four.

`Conquered by your buildings` is intentionally used for every `.idle` result. The persisted model cannot distinguish true offline catch-up from build/upgrade settlement, and both are caused by building production. The copy is therefore accurate for both paths and remains stable after relaunch.

The gold copy intentionally replaces the legacy `+<amount> gold` string. QA should treat the wording as an approved UX change; the authoritative reward value and award timing are unchanged.

### Title

The current shared display API produces only numbered titles. HPA-388 therefore uses one title value rather than introducing unused preferred/fallback machinery.

- Normal conquest: `<current shared city title> Conquered`
- Country completion: `Country <number> Conquered`

`cityTitle` passed to `ConquestReportContent.project` is a city identity string only and does not include ` Conquered`; the projector appends the suffix exactly once.

`ConquestReportNode` fits the single final title down to 14 pt. If it still does not fit, required content fails closed. HPA-366 owns authored city names, shared identity fallback, and any future long-title policy; that ticket must update the conquest report tests when named cities exist.

### MVP copy

When both MVP fields are present, the soldier name uses `SoldierType.displayName`, not its raw value. The percentage is the persisted integer percentage and is not recomputed or reformatted beyond appending `%`.

### Duration formatting

Normalize to a finite, non-negative value, saturate to `Int.max` before truncating so a finite value above `Int`'s representable range (e.g. a corrupted persisted duration) cannot trap the `Int(_:)` conversion, truncate fractional seconds, and format with unbounded hours; do not convert hours to days.

Rules:

- Under one minute: `<seconds>s`.
- Under one hour: `<minutes>m`, adding ` <seconds>s` only when seconds are non-zero. Minute-range seconds are not zero-padded.
- One hour or more: `<hours>h`; non-zero lower components use two digits. If seconds are non-zero while minutes are zero, include `00m`. Omit trailing zero components.
- The padding asymmetry is intentional: `1m 5s` but `1h 01m 05s`.

Golden strings:

| Seconds | Copy |
|---:|---|
| `0` | `0s` |
| `59.9` | `59s` |
| `60` | `1m` |
| `65` | `1m 5s` |
| `3599` | `59m 59s` |
| `3600` | `1h` |
| `3612` | `1h 00m 12s` |
| `3660` | `1h 01m` |
| `3672` | `1h 01m 12s` |
| `90000` | `25h` |
| `90061` | `25h 01m 01s` |

Idle conquest never displays active duration, even when restored data contains non-zero active seconds.

### Numeric formatting

Extract the current `BattleScene.compactNumber` behavior into a Foundation-only shared helper:

```swift
enum CompactNumberFormatter {
    static func string(from value: Int) -> String
}
```

Use it from both Battle HUD copy and `ConquestReportContent`. Existing compact-number cases move from scene-focused coverage to the helper suite so there is one source of truth.

### Achievement badges

Achievement badges appear only when their persisted booleans are true, in fixed order:

1. `.favorableUnit`, rendered with `checkmark.shield.fill`.
2. `.exposedLane`, rendered with `shield.slash.fill`.

The app deployment target includes both symbols. Use the SF Symbols directly; do not add a procedural fallback or fallback-specific tests. A missing symbol is a development/configuration error and may assert in DEBUG.

Badges are visual, non-interactive presentation in this ticket. HPA-388 does not claim or introduce SpriteKit VoiceOver support. Proper modal SpriteKit accessibility would need actionable Continue semantics, screen-coordinate frames, focus ordering, and resize updates as one app-wide design; that is outside this feature.

## Architecture

Follow the established Scout Card separation: pure content projection, pure geometry, and a focused reusable SpriteKit node.

### Shared single-line text fitting

The Scout Card already has a framework-free whole-point font-fitting algorithm. Extract the generic operation into:

```swift
enum SingleLineTextFitter {
    static func fittedFontSize(
        _ text: String,
        startingAt start: CGFloat,
        minimum: CGFloat,
        maximumWidth: CGFloat,
        measure: (String, CGFloat) -> CGFloat
    ) -> CGFloat?
}
```

`CountryMapScoutCardTextLayout.fittedFontSize` remains as a forwarding wrapper so Scout behavior and call sites do not change. `ConquestReportNode` uses `SingleLineTextFitter` directly. Do not duplicate another decrementing font-size loop.

### `CompactNumberFormatter`

Add `Pyxis/CompactNumberFormatter.swift` with the API above.

Responsibilities:

- Preserve current sign handling, decimal suppression, suffixes, and unit promotion.
- Remain Foundation-only and independent of scene state.
- Serve Battle HUD and conquest report copy.

### `ConquestReportContent`

Add `Pyxis/ConquestReportContent.swift`:

```swift
struct ConquestReportContent: Equatable {
    enum Achievement: Equatable {
        case favorableUnit
        case exposedLane
    }

    let title: String
    let summaryLines: [String]
    let achievements: [Achievement]

    static func project(
        from result: BattleResult,
        cityTitle: String,
        isCountryComplete: Bool
    ) -> ConquestReportContent
}
```

Responsibilities:

- Build the one final report title.
- Format gold, live/building copy, duration, MVP, deployment, and loss rows.
- Use `SoldierType.displayName` for MVP.
- Omit unavailable optional data.
- Preserve achievement ordering.
- Guarantee three or four summary rows.

When `isCountryComplete` is true, the projector ignores `cityTitle` and uses `Country <result.cityKey.countryNumber> Conquered`.

The projector never reads the city catalog or SpriteKit state. No city title is persisted in `BattleResult`.

### Derived `BattleResult` totals

Add non-persisted accessors in `BattleResultModels.swift`:

```swift
var totalDeploymentCount: Int
var totalLossCount: Int
```

Each accessor sums normalized rows with saturating integer addition. SpriteKit must not perform these reductions. Chronicle presentation may reuse the accessors later.

### `ConquestReportLayout`

Add `Pyxis/ConquestReportLayout.swift` as a CoreGraphics-only geometry value.

```swift
struct ConquestReportSafeAreaInsets: Equatable {
    let top: CGFloat
    let left: CGFloat
    let bottom: CGFloat
    let right: CGFloat
}
```

`BattleScene` reads `view?.safeAreaInsets ?? .zero` and converts all four values into this pure input. Do not add horizontal helpers to `GameUITheme`; the view is the authoritative source for this report layout.

Other inputs:

- Scene size.
- `BattleScene.LayoutMetrics.contentWidth`, supplied by the scene so the report does not duplicate the Battle HUD width formula.
- Summary row count in `3...4`.
- Achievement count in `0...2`.
- Compact-height classification.

Compact height is `sceneSize.height < 500`, matching the existing `BattleScene.layoutMetrics()` branch.

Layout computation is failable:

```swift
static func compute(_ input: Input) -> ConquestReportLayout?
```

Return `nil` when safe width is non-positive, the computed panel width cannot contain required padding and Continue geometry, the computed panel height exceeds safe height, or any returned frame would leave the safe region.

#### Width and placement

- Safe width is `scene width - safe left - safe right`.
- Panel width is `min(battleContentWidth, safeWidth - 56)`.
- This applies the legacy-inspired 28-point nominal margin inside the current safe horizontal region; it intentionally differs from the old scene-centered popup when side insets exist.
- Do not clamp up to an unreachable panel minimum.
- Center the panel in the safe horizontal and vertical regions.
- Corner radius is 14 pt.

#### Stack constants

| Constant | Standard | Compact |
|---|---:|---:|
| Horizontal content padding | 24 | 18 |
| Top/bottom content padding | 18 | 14 |
| Title line box | 30 | 24 |
| Title → first row gap | 10 | 8 |
| Summary-row line box | 24 | 20 |
| Summary-row gap | 4 | 2 |
| Achievement badge size | 24 | 20 |
| Badge-to-badge gap | 8 | 6 |
| Rows → badge strip gap | 10 | 8 |
| Last content → Continue gap | 16 | 12 |
| Continue horizontal inset | 24 | 24 |
| Continue height | 48 | 44 |
| Panel corner radius | 14 | 14 |

Starting/minimum fonts:

| Text | Standard start | Compact start | Minimum |
|---|---:|---:|---:|
| Title | 22 | 19 | 14 |
| Summary row | 17 | 14 | 12 |
| Continue | 16 | 15 | 15 |

Panel height is deterministic:

```text
2 × vertical padding
+ title line box
+ title/rows gap
+ rowCount × row line box
+ (rowCount - 1) × row gap
+ (achievementCount > 0 ? rows/badges gap + badge size : 0)
+ content/Continue gap
+ Continue height
```

The computed height must fit within the safe vertical region or layout returns `nil`.

The badge strip is horizontally centered. When there are no achievements, omit the strip and its preceding gap. When MVP is absent, use three rows and close the row gap naturally. Continue is centered and has width `panelWidth - 48`, matching the existing button inset.

#### Required fixtures

Layout tests cover every app-supported portrait fixture already defined by `CountryMapLayoutTestFixtures.supported`:

- 375×667, zero insets.
- 375×812, top 50 / bottom 34.
- 393×852, top 59 / bottom 34.
- 440×956, top 62 / bottom 34.
- 480×1194 iPad, top 24 / bottom 20.
- 600×1008 Stage Manager, top 28 / bottom 20.
- 744×1133 iPad mini, top 24 / bottom 20.
- 834×1194 11-inch iPad, top 24 / bottom 20.
- 1032×1376 13-inch iPad, top 24 / bottom 20.
- 834×1194 with 50-point left/right insets.

Also test a synthetic 375×499 zero-inset component fixture to exercise compact metrics. This fixture does not redefine app-wide supported geometry.

All supported fixtures must compute successfully. Every frame must remain inside the safe region, row frames must not overlap, and the complete Continue hit frame must remain visible.

### `ConquestReportNode`

Add `Pyxis/ConquestReportNode.swift`.

```swift
final class ConquestReportNode: SKNode {
    enum ApplyResult: Equatable {
        case presented
        case requiredContentDoesNotFit
    }

    func apply(
        content: ConquestReportContent,
        layout: ConquestReportLayout,
        isContinueEnabled: Bool
    ) -> ApplyResult

    func containsContinue(_ scenePoint: CGPoint) -> Bool

    func goldEffectAnchor(in coordinateNode: SKNode) -> CGPoint?
}
```

The node owns:

- Modal panel.
- One title label.
- Four reusable one-line summary labels.
- Two reusable SF Symbol badge nodes.
- One Continue button and hit frame.
- The rendered gold-row anchor.

Title fitting:

- Fit `content.title` with `SingleLineTextFitter` down to 14 pt.
- If it fails, return `.requiredContentDoesNotFit`.

Summary fitting:

- Summary copy never changes, truncates, wraps, or substitutes shorter wording.
- Fit each complete row from its starting size down to 12 pt with the shared fitter.
- If any row still fails, return `.requiredContentDoesNotFit`.

`goldEffectAnchor(in:)` returns the center of the rendered first summary-row frame converted into the requested coordinate node. It returns `nil` before a successful apply. `BattleScene` passes that point to `playGoldBurst(at:)`; effect code never reaches into private report-node labels.

Reapplication updates the existing node tree and never duplicates labels, badges, or controls. The node does not read game state, save, route, choose a presentation origin, start effects, or claim accessibility behavior.

## City Identity and Defensive Invariants

`BattleScene` supplies the current title from `BattleResult.cityKey`:

1. Guard `result.cityKey == state.currentCityKey`.
2. In DEBUG, assertion-fail if the guard is violated.
3. In release, if the mismatch somehow survives model normalization, acknowledge and persist the pending result without routing or playing effects. A stale result whose city no longer matches would re-launch BattleScene on every subsequent presentation (the router presents BattleScene whenever a pending result exists, regardless of `stageStatus`), so clearing it lets normal stage-status routing take over instead of looping on the unpresentable result.
4. Resolve the city identity through the current shared state/catalog display API.
5. Pass the identity without ` Conquered` to the projector.

Country completion ignores the city-title input as described above.

## Presentation Lifecycle

### Origins and scene-local state

Use only these origins:

```swift
private enum ConquestReportPresentationOrigin {
    case freshLive
    case freshIdle
    case restored
}
```

Scene-local guards:

```swift
private var hasPresentedPendingConquestReport = false
private var isConquestContinueEnabled = true
private(set) var isConquestReportFitFailed = false
```

The first successful fresh or restored apply sets `hasPresentedPendingConquestReport = true`. Repeated `didMove`, resize, safe-area refresh, or redraw cannot be mistaken for a first presentation.

Centralize initial presentation:

```swift
private func presentPendingConquestReport(
    origin: ConquestReportPresentationOrigin,
    resetsContinueState: Bool
)
```

Every initial fresh/restored presentation uses `resetsContinueState: true`. Layout-only reapplication uses `false` and preserves a disabled Continue.

### Entry-point table

| Trigger | Origin | Reset Continue | Effects |
|---|---|---:|---|
| Live conquest finalized and saved in current Battle Scene | `.freshLive` | `true` | Live conquest effects once |
| Foreground building conquest finalized in current Battle Scene | `.freshIdle` | `true` | Idle gold feedback once |
| First `didMove` on a new Battle Scene with pending result | `.restored` | `true` | None |
| Cold launch with pending result | `.restored` | `true` | None |
| Building View → Battle with pending result | `.restored` | `true` | None |
| Repeat `didMove`, resize, safe-area refresh, redraw | Reapply only | `false` | None |

`didMove` checks `hasPresentedPendingConquestReport`: the first pending presentation uses `.restored` and `true`; later calls only reapply layout/content with `false`.

### Fresh Battle Scene conquest

For live conquest:

1. Finalize and save model state.
2. Preserve existing floating final-damage and city-conquest feedback.
3. Apply `.freshLive` with Continue reset.
4. After successful node apply, play the gold burst at `goldEffectAnchor(in: self)`.

For foreground building conquest while already in Battle Scene:

1. Finalize and save model state.
2. Clear live combat and stale tooltip feedback.
3. Apply `.freshIdle` with Continue reset.
4. After successful node apply, play only the approved idle gold burst at the explicit anchor.

Never pass transient `AttackResult.goldEarned` or `IdleProgressResult.goldEarned` into report rendering.

### Building View settlement and idle conquest

Settlement triggered by build/upgrade and foreground idle catch-up can set an idle `pendingBattleResult` while the player is in `BuildingViewScene`.

The approved behavior preserves the current surface:

- Stay in Building View.
- Show existing conquest feedback there.
- Do not auto-route to Battle Scene.
- Do not play the conquest report gold burst or battlefield flourish.

When the player taps Battle, `BuildingViewScene.requestBattle()` saves state and calls `buildingViewSceneDidRequestBattle`. `GameViewController` then uses `presentSceneForCurrentStage`; pending-first routing creates a new Battle Scene, which presents the report as `.restored` with Continue enabled and no effects.

This also covers a conquest finalized by the final `returnFromBackground` inside `requestBattle()` immediately before routing. No third presentation origin is introduced.

### Pending-first routing

`GameViewController.presentSceneForCurrentStage(in:)` gives pending reports precedence:

```swift
let state = store.load()

if state.pendingBattleResult != nil {
    presentBattleScene(in: view)
    return
}

switch state.stageStatus {
case .battleActive:
    presentBattleScene(in: view)
case .cityConqueredPendingMap, .countryComplete:
    presentCountryMapScene(in: view)
}
```

This rule is load-bearing for both cold launch and `buildingViewSceneDidRequestBattle`.

Consequences:

- Pending live/idle result enters Battle Scene for static restoration.
- Acknowledged conquered state enters Country Map.
- Conquered saves without pending data keep existing map behavior.
- A compatible pre-existing pending result from an earlier pre-release build is treated as unacknowledged and may appear once after upgrade. No migration marker is added because current state cannot distinguish “legacy popup already seen” from “report still awaiting acknowledgment.”
- City 15 restores its report before final country-complete map presentation.

### Inert conquered-stage host

A Battle Scene created for `.cityConqueredPendingMap` or `.countryComplete` with a pending result is an inert report host:

- Do not advance combat or active battle time.
- Do not permit deployment, building, world, tooltip, or battlefield actions.
- Do not mutate city power or progression.
- Only an enabled report Continue action is interactive.

This explicitly covers `.countryComplete`, a stage the scene previously did not present.

### Layout-fit failure

If `ConquestReportLayout.compute` returns `nil` or `ConquestReportNode.apply` returns `.requiredContentDoesNotFit`:

- Set `isConquestReportFitFailed = true`.
- Keep `pendingBattleResult` unchanged.
- Keep underlying Battle input blocked.
- Do not play effects, acknowledge, save, or route.
- Expose the flag to `GameViewController.refreshLayoutSupport`, which maps it to the existing `.unsupportedGeometry` app-wide gate.

A later supported resize retries layout/application; success clears the flag and the existing gate recovers. Supported fixtures must never enter this path.

## Continue Transaction

A newly created scene starts with Continue enabled. Every initial fresh/restored presentation explicitly resets it to `true`; layout-only reapplication preserves the current value.

Continue performs this exact synchronous sequence:

1. Guard report visible, Continue enabled, pending result present, router available, and no fit failure.
2. Set `isConquestContinueEnabled = false`.
3. Reapply/dim the node so Continue becomes immediately non-interactive. If this reapplication fails (layout fit), abort the transaction: preserve `state.pendingBattleResult`, restore `isConquestContinueEnabled = true`, and perform none of steps 4–6. The fit-failure flag stays set so the player can retry once a supported resize recovers geometry.
4. Call `state.acknowledgePendingBattleResult()`.
5. Call `store.save(state)`.
6. Request one Country Map route.

Keep the disabled report visible until scene replacement. Repeated taps exit at step 1. Resize/redraw after step 2 preserve `false` and cannot reopen the transaction. If the router is unavailable, leave Continue enabled and state untouched.

## Effects Lifecycle

Effect ownership remains in `BattleScene`:

| Origin | City flourish | Floating final damage | Gold burst | Future SFX/haptic |
|---|---:|---:|---:|---:|
| Fresh live | Existing | Existing | Once at explicit gold anchor | Once when integrated |
| Fresh idle in Battle Scene | No | No | Once at explicit gold anchor | Once when integrated |
| Restored, including Building View → Battle | No | No | No | No |
| Resize/redraw | No replay | No replay | No replay | No replay |

The report node exposes geometry only; it never starts effects.

## Testing Strategy

### `SingleLineTextFitterTests`

- Preserve Scout Card whole-point fitting behavior.
- Return the first fitting whole-point size.
- Return `nil` when the minimum does not fit.
- Existing Scout Card text-layout tests remain green through the forwarding wrapper.

### `CompactNumberFormatterTests`

- Move existing Battle Scene compact-number boundary and sign cases into the helper suite.
- Preserve suffix promotion and decimal suppression.
- Confirm Battle HUD and report projection use the same helper.

### `BattleResultModelsTests`

- Deployment total across type/source/lane rows.
- Loss total across type/source rows.
- Zero totals.
- Saturating overflow.

### `ConquestReportContentTests`

- Full live and idle reports with MVP.
- Gold wording and compact value.
- Idle copy is `Conquered by your buildings`.
- Idle duration suppression.
- All duration golden strings above, including `3660 → 1h 01m`.
- Intentional minute/hour padding asymmetry.
- MVP uses `SoldierType.displayName`.
- Missing MVP with no gap.
- Zero deployment/loss copy.
- Each achievement and neither.
- Input title excludes suffix and output appends it once.
- Country completion ignores city-title input.
- Exactly three or four rows.

### `ConquestReportLayoutTests`

- Exact panel-height arithmetic for three/four rows and zero/one/two badges.
- Every supported fixture listed above.
- Synthetic compact fixture.
- Side-inset fixture using insets sourced from the view adapter.
- `nil` for insufficient safe width or safe height.
- All successful frames contained by safe region.
- No row/badge/Continue overlap: ordered, non-overlapping summary rows (each row's `maxY` ≤ the row above's `minY`); separation between the last summary row and the achievement badge strip (`strip.maxY` ≤ `lastRow.minY`).
- Complete Continue hit frame visible: `continueFrame` is both the visual background and the enabled hit target, so it must be contained by the safe region.

### `ConquestReportNodeTests`

- Exactly one title and Continue control.
- Reapply/resize does not duplicate nodes.
- Current title fits or returns required-content failure; no synthetic fallback candidate.
- Summary rows only shrink; they never wrap, truncate, or change copy.
- Required-content failure when title or a row cannot fit.
- Enabled/disabled Continue appearance and hit behavior.
- Layout-only reapply preserves disabled Continue.
- Gold effect anchor equals the `ConquestReportContent.goldLineIndex` row center in requested coordinates, and that row's copy is the gold line (semantic, not positional).
- SF Symbol badges appear in fixed order when achievements are present.

### `BattleSceneTests`

- Live conquest renders only persisted pending result and uses `.freshLive`.
- Battle Scene foreground building conquest uses `.freshIdle`.
- Restored report is static and starts with Continue enabled.
- First-versus-repeated `didMove` is deduplicated by the scene-local flag.
- Building View pending result enters as restored with no effects.
- Mismatched pending result DEBUG assertion, then acknowledge-and-persist so the stale result cannot re-launch BattleScene and re-fail on every subsequent presentation; normal stage-status routing proceeds.
- Gold burst uses the node-provided anchor.
- Resize/redraw duplicates neither controls nor effects.
- Resize/redraw cannot re-enable Continue after transaction start.
- Underlying input blocked while report visible or fit failed.
- `.countryComplete` scene remains inert except for Continue.
- Compatible pre-existing pending result is presented once.
- Acknowledge/save/route ordering.
- Duplicate Continue routes once.
- Next city does not redisplay acknowledged result.

A router spy verifies at callback time:

- Scene pending result is nil.
- Reloaded store pending result is nil.
- Route count is one.

### `BuildingViewSceneTests`

- Settlement conquest stays on Building View with feedback and saves idle pending result.
- Foreground idle conquest stays on Building View with feedback.
- Battle request after either path routes once without clearing pending result.
- Conquest triggered by `requestBattle()` catch-up is handed off as pending.

### `GameViewControllerTests`

- Pending result takes precedence for cold launch and both conquered stages.
- `buildingViewSceneDidRequestBattle` with pending result presents Battle Scene, not Country Map.
- Conquered state without pending result presents Country Map.
- Relaunch after acknowledgment presents Country Map.
- Report fit failure maps to `.unsupportedGeometry` and recovers on successful resize.
- Horizontal safe-area values are passed from `SKView.safeAreaInsets` into report layout.
- City 15 pending result restores before map presentation.

### Manual smoke

1. Live conquest in Battle Scene.
2. Foreground building conquest in Battle Scene.
3. Settlement conquest in Building View; remain there; tap Battle; static report.
4. Building View foreground idle conquest; tap Battle; static report.
5. Relaunch before Continue.
6. Relaunch after Continue/save.
7. Upgrade a pre-release save with a compatible pending result; report appears once.
8. Resize after tapping Continue but before scene replacement.
9. Compact component layout.
10. Small phone and side-inset iPad fixtures.
11. City 15 inert report host and final map route.

## File Plan

### New production files

- `Pyxis/SingleLineTextFitter.swift`
- `Pyxis/CompactNumberFormatter.swift`
- `Pyxis/ConquestReportContent.swift`
- `Pyxis/ConquestReportLayout.swift`
- `Pyxis/ConquestReportNode.swift`

### Modified production files

- `Pyxis/CountryMapScoutCardTextLayout.swift` — forward shared fitting helper.
- `Pyxis/BattleResultModels.swift`.
- `Pyxis/BattleScene.swift`.
- `Pyxis/GameViewController.swift`.

`GameUITheme.swift`, `CityDefinition.swift`, and `BuildingViewScene.swift` do not change. Building View’s existing feedback-and-explicit-Battle route is pinned and tested.

### New test files

- `PyxisTests/SingleLineTextFitterTests.swift`
- `PyxisTests/CompactNumberFormatterTests.swift`
- `PyxisTests/ConquestReportContentTests.swift`
- `PyxisTests/ConquestReportLayoutTests.swift`
- `PyxisTests/ConquestReportNodeTests.swift`

### Modified test files

- `PyxisTests/CountryMapScoutCardTextLayoutTests.swift`.
- `PyxisTests/BattleResultModelsTests.swift`.
- `PyxisTests/BattleSceneTests.swift`.
- `PyxisTests/BuildingViewSceneTests.swift`.
- `PyxisTests/GameViewControllerTests.swift`.

## Implementation Order

1. Extract and test `SingleLineTextFitter`; preserve Scout behavior through a forwarding wrapper.
2. Extract and test compact-number formatting; migrate existing HUD tests and consumer.
3. Add and test derived result totals and content projection, including revised idle copy and duration contracts.
4. Add exact layout constants, direct safe-area adaptation, failable containment, and fixture-driven geometry tests.
5. Add report-node title/row fitting, SF Symbol badges, gold-anchor, and failure tests.
6. Replace the legacy popup and render only `pendingBattleResult`.
7. Add first-presentation deduplication, inert conquered-stage hosting, fresh/restored effect gating, and explicit Continue initialization.
8. Implement the synchronous Continue transaction.
9. Add Building View handoff and pending-first controller routing tests.
10. Add report-fit gate recovery and pre-existing pending-save behavior.
11. Run focused suites, then the complete Pyxis suite.
12. Complete the manual smoke matrix.

## Non-Goals

- Auto-routing away from Building View when settlement or idle conquest occurs.
- A third presentation origin for settlement.
- Collecting or recomputing battle statistics.
- Changing combat, rewards, progression, city completion, or idle attribution.
- Detailed per-type tables or a secondary action.
- Chronicle/history persistence.
- Replay, sharing, analytics, leaderboards, or telemetry.
- New sound/haptic implementation beyond preserving the HPA-389 boundary.
- Persisting duplicate city identity strings.
- Authored city names or long-title fallback machinery before HPA-366.
- A migration marker for pre-release pending results.
- SpriteKit accessibility or broader formatting, localization, and HUD-layout work beyond the focused report contracts above.
