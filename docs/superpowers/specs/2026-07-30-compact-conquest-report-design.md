# Compact Conquest Report Design

**Issue:** HPA-388  
**Status:** Design approved; awaiting written spec review  
**Date:** 2026-07-30

## Goal

Present the persisted `BattleResult` as a short, satisfying conquest report without recomputing combat statistics in SpriteKit, changing reward or progression semantics, or adding a secondary details flow.

The report must:

- Distinguish live and idle conquest clearly.
- Show no more than four summary text rows.
- Restore identically after relaunch while `pendingBattleResult` exists.
- Play conquest feedback only for the original presentation.
- Acknowledge, save, and route exactly once when Continue is activated.

## Existing Behavior and Constraints

HPA-363 already provides the authoritative model boundary:

- `BattleResult` contains the conquered `cityKey`, explicit `conquestMode`, active battle duration, normalized deployment/damage/loss summaries, optional MVP values, achievement markers, and authoritative gold earned.
- `KingdomGameState.pendingBattleResult` persists the report until acknowledgment.
- `acknowledgePendingBattleResult()` clears only the pending presentation value; it does not award gold or change progress.
- Gold and stage completion occur before report presentation.

The current UI is a legacy `BattleScene` popup with a title, one gold label, and a Continue button. Both live and idle paths pass transient `goldEarned` values into that popup, every presentation plays the gold burst, and Continue routes without acknowledging or saving. On relaunch, `GameViewController` routes conquered stages directly to `CountryMapScene`, so a pending report is currently bypassed.

## Product Decisions

### Title

- Normal conquest preferred title: `<resolved city title> Conquered`
- Normal conquest fallback title: `Country <country> - City <city> Conquered`
- Country completion: `Country <number> Conquered`

The content projection carries both preferred and fallback title candidates. `ConquestReportNode` owns text measurement and selection: it fits the preferred title down to 14 pt, then uses and fits the fallback title only when the preferred title still does not fit. `ConquestReportLayout` remains geometry-only and never substitutes text.

### Summary row slots

The report has exactly these four possible row slots:

1. `Gold earned: +<amount>`
2. Live: `Battle time: <active duration>`; idle: `Conquered while away`
3. Optional: `MVP: <soldier type> · <damage share>%`
4. `Deployed: <count> · Lost: <count>`

When MVP is absent, row slot 3 is removed and the final row moves up. The report therefore contains three or four visible summary rows and never more than four.

### Duration formatting

Use compact natural formatting based only on `BattleResult.activeBattleSeconds`:

- `0s`
- `42s`
- `1m 42s`
- `1h 03m 12s`

Fractional seconds are truncated after normalizing to a finite, non-negative value. Idle conquest never displays a duration, even if restored data contains a non-zero active duration.

### Numeric formatting

Add a Foundation-only shared helper:

```swift
namespace CompactNumberFormatter {
    static func string(from value: Int) -> String
}
```

Use it from both `ConquestReportContent` and the existing `BattleScene` HUD. The helper preserves the current `BattleScene.compactNumber` behavior and prevents the battle HUD and conquest report from drifting while keeping formatting outside SpriteKit/UIKit.

This ticket performs only the targeted extraction needed by these two shipping consumers; it does not broaden into an unrelated HUD or localization refactor.

### Optional data

- MVP is rendered only when both `mvpSoldierType` and `mvpDamageSharePercent` are present.
- A missing MVP creates no blank row and no zero-value placeholder.
- Favorable-unit and exposed-lane achievements appear as compact icon badges only when their persisted booleans are true.
- Zero deployments and zero losses remain visible as `Deployed: 0 · Lost: 0`.

### Achievement icons

Use two small presentation-only badges in a fixed horizontal order:

1. Favorable unit: `checkmark.shield.fill`.
2. Exposed lane: `shield.slash.fill`.

Load each with `UIImage(systemName:)`. If a symbol is unavailable, render a procedural shield fallback with the corresponding check mark or slash. Icons add no report row and do not affect model state.

The internal content case is named `.favorableUnit` to mirror `BattleResult.usedFavorableUnit`. Player-facing copy or accessibility text may still describe this as using a favorable counter.

## Architecture

Follow the existing Scout Card separation: pure content projection, pure layout calculation, and a focused reusable SpriteKit node.

### `CompactNumberFormatter`

Add `Pyxis/CompactNumberFormatter.swift`.

```swift
namespace CompactNumberFormatter {
    static func string(from value: Int) -> String
}
```

Responsibilities:

- Preserve the current compact integer formatting behavior, including sign handling, decimal suppression, and unit promotion.
- Remain Foundation-only and independent of scene state.
- Serve both `BattleScene` HUD copy and `ConquestReportContent`.

### `ConquestReportContent`

Add `Pyxis/ConquestReportContent.swift`.

```swift
struct ConquestReportContent: Equatable {
    enum Achievement: Equatable {
        case favorableUnit
        case exposedLane
    }

    let preferredTitle: String
    let fallbackTitle: String
    let summaryLines: [String]
    let achievements: [Achievement]

    static func project(
        from result: BattleResult,
        preferredCityTitle: String,
        fallbackCityTitle: String,
        isCountryComplete: Bool
    ) -> ConquestReportContent
}
```

Responsibilities:

- Build preferred and fallback report titles.
- Format gold, duration, live/idle distinction, MVP, and totals.
- Omit unavailable optional data.
- Preserve achievement ordering.
- Guarantee three or four summary rows.

The projector receives resolved title candidates instead of reading the city catalog. This keeps it pure and allows HPA-366 to change the shared city-identity API without persisting or duplicating titles in `BattleResult`.

For country completion, `preferredTitle` and `fallbackTitle` are both `Country <number> Conquered`, so no city-title fallback decision is required.

### Derived `BattleResult` totals

Add non-persisted accessors in `BattleResultModels.swift`:

```swift
var totalDeploymentCount: Int
var totalLossCount: Int
```

Each accessor sums normalized rows using saturating integer addition. SpriteKit must not perform these reductions. The accessors can later be reused by Chronicle presentation.

### `ConquestReportLayout`

Add `Pyxis/ConquestReportLayout.swift` as a pure geometry calculator.

Inputs:

- Scene size.
- Existing content-width cap.
- Safe top and bottom insets.
- Compact-height classification.
- Summary row count, restricted to `3...4`.
- Achievement count, restricted to `0...2`.

Outputs:

- Panel frame.
- Title frame.
- One frame per visible summary row.
- Optional achievement-strip frame.
- Continue-button frame.
- Starting and minimum font metrics for the current layout class.

Layout rules:

- Center the panel within the safe vertical region.
- Cap width using the current Battle scene content-width policy.
- Compute panel height from the actual row and badge counts.
- Omitted MVP closes the vertical gap.
- Keep the complete Continue hit frame inside the safe visible bounds.
- Standard metrics start at title 22 pt, rows 17 pt, Continue 16 pt, and badges 24 pt.
- Compact-height metrics use title 19 pt, rows 14 pt, Continue 15 pt, and badges 20 pt.
- Title minimum is 14 pt; summary-row minimum is 12 pt.
- The fixed English row copy plus compact numeric formatting must fit every supported layout; tests enforce this.

`ConquestReportLayout` never receives, measures, or replaces title strings. `ConquestReportNode` performs title measurement within the geometry supplied by the layout.

`ConquestReportLayout` is required to produce valid geometry for every app-supported portrait layout. Unsupported geometry remains owned by the existing app-wide layout gate; this ticket adds no second layout-gate system.

### `ConquestReportNode`

Add `Pyxis/ConquestReportNode.swift`.

The node owns:

- The modal panel.
- One title label.
- Four reusable row labels, hiding unused labels.
- Two reusable achievement badge nodes.
- One Continue button and its hit frame.

API:

```swift
final class ConquestReportNode: SKNode {
    func apply(
        content: ConquestReportContent,
        layout: ConquestReportLayout,
        isContinueEnabled: Bool
    )

    func containsContinue(_ scenePoint: CGPoint) -> Bool
}
```

The node must:

- Fit `content.preferredTitle` within the title frame down to the layout's 14 pt minimum.
- If the preferred title still does not fit, replace it with `content.fallbackTitle` and fit that candidate.
- Use the fallback title deterministically without asking `BattleScene` or `ConquestReportLayout` to retry.

The node must not:

- Read `KingdomGameState` or `BattleResult`.
- Inspect soldier nodes.
- Save or route.
- Play conquest effects.
- Decide whether the presentation is fresh or restored.

Reapplying content or layout updates the existing node tree. It never creates duplicate labels, badges, or buttons.

## City Identity Resolution

`BattleScene` supplies both title candidates from `BattleResult.cityKey` through the current shared city-display boundary.

1. Confirm the normalized pending result matches `state.currentCityKey`.
2. Resolve the preferred city title with the current state/catalog API for `result.cityKey.cityNumber`.
3. Build the safe fallback city title directly from the result key as `Country <country> - City <city>`.
4. Pass both candidates to `ConquestReportContent.project`.

If preferred title resolution fails in a release build, pass the numbered fallback as both candidates. Before HPA-366 this naturally produces the existing numbered title. After HPA-366 the preferred candidate uses catalog-provided identity. Do not persist a city name or conquest title inside `BattleResult`.

Country completion uses `Country <number> Conquered` for both candidates regardless of city naming.

## BattleScene Integration

Replace the embedded legacy popup labels and button with one `ConquestReportNode`.

### Presentation origin

Use an explicit scene-local origin:

```swift
private enum ConquestReportPresentationOrigin {
    case freshLive
    case freshIdle
    case restored
}
```

Centralize presentation in:

```swift
private func presentPendingConquestReport(
    origin: ConquestReportPresentationOrigin,
    resetsContinueState: Bool
)
```

This method:

1. Reads only `state.pendingBattleResult` as report data.
2. Resolves the preferred and fallback title candidates from the result's `cityKey`.
3. Projects `ConquestReportContent`.
4. Computes and applies `ConquestReportLayout`.
5. Marks the report visible and blocks all underlying battle/HUD actions.
6. Plays effects only for a fresh origin.

If no pending result exists, the method does nothing and must not fabricate a report from scene state.

For the initial presentation of every fresh or restored pending result, call with `resetsContinueState: true`; this explicitly sets `isConquestContinueEnabled = true` before applying the node. Resize, safe-area refresh, and redraw call with `resetsContinueState: false` and preserve the current value. They must never re-enable Continue after acknowledgment has begun.

### Fresh live conquest

After live combat finalizes the result and saves state:

1. Preserve the existing floating final-damage feedback.
2. Preserve the existing city-conquest visual feedback.
3. Present `state.pendingBattleResult` with `.freshLive` and `resetsContinueState: true`.
4. Play the existing gold burst once.

The scene no longer passes `AttackResult.goldEarned` into report rendering.

### Fresh idle conquest

After foreground catch-up finalizes the result and saves state:

1. Clear live combat and stale tooltip feedback.
2. Present `state.pendingBattleResult` with `.freshIdle` and `resetsContinueState: true`.
3. Preserve the existing idle conquest gold burst once.
4. Do not introduce live-only floating damage or city-conquest flourish.

The scene no longer passes `IdleProgressResult.goldEarned` into report rendering.

### Restored conquest

When a newly constructed `BattleScene.didMove(to:)` completes interface construction and redraw:

- If `pendingBattleResult` exists, present it with `.restored` and `resetsContinueState: true`.
- Continue therefore begins enabled and tappable for every restored pending report.
- Show the same title, rows, badges, and Continue action.
- Do not play the gold burst, conquest flourish, floating damage, SFX, or haptic.

Repeated `didMove` on the same scene instance, resize, safe-area refresh, and redraw may reapply content/layout only with `resetsContinueState: false`. They must preserve a disabled Continue and must not call an effect path.

### Input gating

While the report is visible, `BattleScene` accepts only the enabled Continue hit target. Spawn, manual type selection, world, building, information tooltip, and battlefield touches are ignored.

This explicit gate replaces reliance on each individual button handler to reject report-visible input.

## Initial Scene Routing

Update `GameViewController.presentSceneForCurrentStage(in:)` so a pending report has precedence over stage routing:

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

Consequences:

- Relaunch with a pending live or idle result restores the report in `BattleScene`.
- Relaunch after successful acknowledgment routes directly to Country Map.
- Older conquered saves without a pending result retain current Country Map behavior.
- Country 15 restores its pending report before final Country Map presentation.

`KingdomGameState` normalization already prevents a pending result from surviving in `.battleActive`, so the precedence rule does not redirect a valid active battle.

## Continue Transaction

`BattleScene` owns a scene-local guard:

```swift
private var isConquestContinueEnabled = true
```

A newly constructed scene starts enabled. Every initial fresh/restored report presentation explicitly resets it to `true`; layout-only reapplication preserves the current value.

Continue performs this exact synchronous sequence:

1. Guard that the report is visible, Continue is enabled, a pending result exists, and a router is available.
2. Set `isConquestContinueEnabled = false`.
3. Reapply/dim the report node so Continue is immediately non-interactive.
4. Call `state.acknowledgePendingBattleResult()`.
5. Call `store.save(state)`.
6. Request one Country Map route.

Do not hide or destroy the report before routing. Keeping the disabled report visible avoids a blank frame if scene presentation is delayed.

A repeated tap exits at the first guard and performs no additional acknowledgment, save, or route. Resize/redraw after step 2 must preserve `false` and cannot reopen the transaction.

If the router is unavailable, leave Continue enabled and state untouched so a later valid interaction can complete the transaction.

## Effects Lifecycle

Effect ownership remains in `BattleScene`, separate from report rendering.

| Origin | City flourish | Floating final damage | Gold burst | Future SFX/haptic |
|---|---:|---:|---:|---:|
| Fresh live | Existing behavior | Existing behavior | Once | Once when integrated |
| Fresh idle | No | No | Once | Once when integrated |
| Restored | No | No | No | No |
| Resize/redraw | No replay | No replay | No replay | No replay |

The report node never starts effects, so node reapplication cannot replay them.

## Defensive Behavior

- Missing optional MVP fields are omitted.
- Invalid or mismatched persisted results continue to be normalized or dropped by `KingdomGameState`; the scene does not generate a replacement result.
- App-supported layouts must always keep the required content and Continue visible.
- Unsupported geometry remains paused and blocked by the existing `AppLayoutGateView`; no acknowledgment or route occurs while gated.
- If an achievement system symbol is unavailable, its procedural fallback is rendered.
- If a preferred title cannot fit at 14 pt, the node deterministically uses the numbered fallback title.
- Display formatting never changes authoritative stored values.

## Testing Strategy

### `CompactNumberFormatterTests`

- Preserve all existing compact-number boundaries and sign behavior.
- Promote values that would round to `1000` in the lower unit.
- Verify `BattleScene` and report copy use the same helper outputs.

### `BattleResultModelsTests`

- Total deployment count across type/source/lane rows.
- Total loss count across type/source rows.
- Zero totals.
- Saturating overflow behavior.

### `ConquestReportContentTests`

- Full live report with MVP and both achievements.
- Full idle report with MVP.
- Idle mode suppresses active duration.
- Missing MVP produces three rows with no gap.
- Zero deployment and zero loss copy.
- Each achievement independently and neither achievement.
- Duration boundaries and truncation.
- Shared compact numeric boundaries.
- Preferred/fallback normal-city title candidates.
- Identical country-complete title candidates.
- Exactly three or four summary rows.

### `ConquestReportLayoutTests`

- Three-row and four-row geometry.
- Zero, one, and two badge layouts.
- Supported phone and iPad portrait sizes.
- Compact-height supported layout.
- Continue frame remains fully visible and non-overlapping.
- Title frame and starting/minimum font metrics.

### `ConquestReportNodeTests`

- One title, up to four row labels, optional badges, and exactly one Continue button.
- Reapply and resize do not duplicate nodes or controls.
- Hidden fourth label when MVP is absent.
- Preferred title selected when it fits.
- Numbered fallback title selected only when preferred title cannot fit at 14 pt.
- Enabled and disabled Continue appearance and hit behavior.
- Layout-only reapply preserves disabled Continue.
- Missing system symbol uses the procedural fallback.

### `BattleSceneTests`

- Live conquest renders only the persisted pending result.
- Idle conquest renders `Conquered while away`.
- Missing optional fields.
- Fresh live presentation plays existing effects once.
- Fresh idle presentation plays only its approved gold effect once.
- Restored report is static and starts with Continue enabled.
- Resize/redraw duplicates neither effects nor controls.
- Resize/redraw cannot re-enable Continue after the transaction starts.
- Underlying HUD and battlefield input is blocked.
- Continue acknowledges, saves, then routes.
- Duplicate Continue routes once.
- Next-city state does not redisplay an acknowledged result.

A router spy verifies ordering at callback time:

- The scene's pending result is already nil.
- Reloading the store returns a nil pending result.
- Route count is exactly one.

### `GameViewControllerTests`

- Pending result takes precedence and presents `BattleScene` for both conquered stage values.
- Conquered stage without a pending result presents `CountryMapScene`.
- Relaunch after acknowledgment presents Country Map.
- Country 15 pending result restores before country-complete map presentation.

### Manual smoke

1. Live conquest.
2. Idle conquest.
3. Relaunch before Continue.
4. Relaunch after Continue/save.
5. Resize after tapping Continue but before scene replacement.
6. Long preferred title falling back to numbered title.
7. Compact supported phone layout.
8. iPad portrait layout.
9. City 15 country completion.

## File Plan

### New production files

- `Pyxis/CompactNumberFormatter.swift`
- `Pyxis/ConquestReportContent.swift`
- `Pyxis/ConquestReportLayout.swift`
- `Pyxis/ConquestReportNode.swift`

### Modified production files

- `Pyxis/BattleResultModels.swift`
- `Pyxis/BattleScene.swift`
- `Pyxis/GameViewController.swift`

### New test files

- `PyxisTests/CompactNumberFormatterTests.swift`
- `PyxisTests/ConquestReportContentTests.swift`
- `PyxisTests/ConquestReportLayoutTests.swift`
- `PyxisTests/ConquestReportNodeTests.swift`

### Modified test files

- `PyxisTests/BattleResultModelsTests.swift`
- `PyxisTests/BattleSceneTests.swift`
- `PyxisTests/GameViewControllerTests.swift`

## Implementation Order

1. Add failing shared compact-number formatter tests and extract the existing behavior.
2. Update `BattleScene` HUD formatting to use the shared helper.
3. Add failing total-count and content-projection tests.
4. Implement derived `BattleResult` totals and `ConquestReportContent`.
5. Add failing pure layout tests and implement `ConquestReportLayout`.
6. Add failing node tests and implement title fitting/fallback plus `ConquestReportNode`.
7. Replace the legacy popup in `BattleScene` and render only `pendingBattleResult`.
8. Add and implement fresh-versus-restored effect gating and explicit Continue initialization.
9. Add and implement the synchronous Continue transaction and duplicate-input guard.
10. Add controller restoration tests and update initial routing precedence.
11. Run focused suites, then the complete Pyxis test suite.
12. Complete the manual live, idle, restoration, title-fallback, compact-layout, and City 15 smoke matrix.

## Non-Goals

- Collecting or recomputing battle statistics.
- Changing combat, rewards, progression, or city completion.
- Detailed per-type tables or a secondary details action.
- Chronicle/history persistence.
- Replay, sharing, analytics, leaderboards, or remote telemetry.
- New sound or haptic implementation beyond preserving the effect boundary for HPA-389.
- Persisting duplicate city identity strings.
- Broader number-formatting, localization, or HUD-layout refactors beyond the shared pure helper required by the battle HUD and conquest report.