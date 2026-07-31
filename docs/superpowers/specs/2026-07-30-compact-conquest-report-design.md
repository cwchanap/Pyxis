# Compact Conquest Report Design

**Issue:** HPA-388  
**Status:** Review clarifications incorporated; awaiting final spec review  
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

### Title candidates and overflow ownership

- Normal preferred title: `<resolved city title> Conquered`
- Normal fallback title: `Country <country> - City <city> Conquered`
- Country completion: `Country <number> Conquered`

`ConquestReportContent` carries both title candidates. `ConquestReportNode` owns text measurement and selection:

1. Fit the preferred title down to 14 pt.
2. If it still does not fit, replace it with the fallback title and fit that candidate.

`ConquestReportLayout` remains geometry-only. It never receives, measures, replaces, or synthesizes title strings, and `BattleScene` does not perform a layout-failure retry.

### Summary row slots

The report has exactly four possible row slots:

1. `Gold earned: +<amount>`
2. Live: `Battle time: <active duration>`; idle: `Conquered while away`
3. Optional: `MVP: <soldier type> · <damage share>%`
4. `Deployed: <count> · Lost: <count>`

When MVP is absent, row 3 is removed and the final row moves up. The report therefore contains three or four visible summary rows and never more than four.

### Duration formatting

Use compact natural formatting based only on `BattleResult.activeBattleSeconds`:

- `0s`
- `42s`
- `1m 42s`
- `1h 03m 12s`

Fractional seconds are truncated after normalization to a finite, non-negative value. Idle conquest never displays a duration, even if restored data contains a non-zero active duration.

### Numeric formatting

Extract the current `BattleScene.compactNumber` behavior into a Foundation-only shared helper:

```swift
enum CompactNumberFormatter {
    static func string(from value: Int) -> String
}
```

Use it from both `BattleScene` HUD copy and `ConquestReportContent`. This prevents the two gold displays from drifting while keeping formatting independent of SpriteKit/UIKit.

This is a targeted extraction for two shipping consumers, not a broader HUD, localization, or formatting refactor.

### Optional data and achievements

- MVP appears only when both `mvpSoldierType` and `mvpDamageSharePercent` are present.
- Missing MVP creates no blank row or zero-value placeholder.
- Zero deployments and zero losses remain visible as `Deployed: 0 · Lost: 0`.
- Achievement badges appear only when their persisted booleans are true.

Use two small presentation-only badges in fixed order:

1. Favorable unit: `checkmark.shield.fill`.
2. Exposed lane: `shield.slash.fill`.

If a system symbol is unavailable, render a procedural shield fallback with the corresponding check mark or slash. Badges add no report row and do not affect model state.

The internal content case is `.favorableUnit`, mirroring `BattleResult.usedFavorableUnit`. Player-facing accessibility text may describe this as using a favorable counter.

## Architecture

Follow the existing Scout Card separation: pure content projection, pure layout calculation, and a focused reusable SpriteKit node.

### `CompactNumberFormatter`

Add `Pyxis/CompactNumberFormatter.swift`:

```swift
enum CompactNumberFormatter {
    static func string(from value: Int) -> String
}
```

Responsibilities:

- Preserve current compact integer behavior, including sign handling, decimal suppression, and unit promotion.
- Remain Foundation-only and independent of scene state.
- Serve `BattleScene` and `ConquestReportContent`.

### `ConquestReportContent`

Add `Pyxis/ConquestReportContent.swift`:

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

The projector receives title candidates instead of reading the city catalog. This keeps it pure and lets HPA-366 change shared city identity without persisting or duplicating titles in `BattleResult`.

For country completion, both candidates are `Country <number> Conquered`.

### Derived `BattleResult` totals

Add non-persisted accessors in `BattleResultModels.swift`:

```swift
var totalDeploymentCount: Int
var totalLossCount: Int
```

Each accessor sums normalized rows using saturating integer addition. SpriteKit must not perform these reductions. Chronicle presentation may reuse the same accessors later.

### `ConquestReportLayout`

Add `Pyxis/ConquestReportLayout.swift` as a pure geometry calculator.

Inputs:

- Scene size.
- Existing content-width cap.
- Safe top and bottom insets.
- Compact-height classification.
- Summary row count in `3...4`.
- Achievement count in `0...2`.

Outputs:

- Panel frame.
- Title frame.
- One frame per visible summary row.
- Optional achievement-strip frame.
- Continue-button frame.
- Starting and minimum font metrics.

Rules:

- Center the panel within the safe vertical region.
- Cap width using the current Battle scene content-width policy.
- Compute panel height from actual row and badge counts.
- Close the vertical gap when MVP is omitted.
- Keep the complete Continue hit frame inside safe visible bounds.
- Standard metrics begin at title 22 pt, rows 17 pt, Continue 16 pt, badges 24 pt.
- Compact-height metrics use title 19 pt, rows 14 pt, Continue 15 pt, badges 20 pt.
- Title minimum is 14 pt; summary-row minimum is 12 pt.
- Fixed English row copy plus shared compact numeric formatting must fit every supported layout.

The layout never handles title strings. Unsupported geometry remains owned by the existing app-wide layout gate; this ticket adds no second gate system.

### `ConquestReportNode`

Add `Pyxis/ConquestReportNode.swift`.

The node owns:

- Modal panel.
- One title label.
- Four reusable row labels.
- Two reusable achievement badge nodes.
- One Continue button and hit frame.

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

- Fit `content.preferredTitle` in the title frame down to 14 pt.
- Use and fit `content.fallbackTitle` only when the preferred title still does not fit.
- Make the fallback choice deterministically without requesting a scene/layout retry.

The node must not:

- Read `KingdomGameState` or `BattleResult`.
- Inspect soldier nodes.
- Save or route.
- Play conquest effects.
- Decide whether presentation is fresh or restored.

Reapplication updates the existing node tree and never duplicates labels, badges, or controls.

## City Identity Resolution

`BattleScene` supplies both title candidates from `BattleResult.cityKey`:

1. Confirm the normalized pending result matches `state.currentCityKey`.
2. Resolve the preferred city title through the current state/catalog API.
3. Build the safe fallback from the result key as `Country <country> - City <city>`.
4. Pass both candidates to `ConquestReportContent.project`.

If preferred resolution fails in release, pass the numbered fallback as both candidates. Before HPA-366 this naturally produces the numbered title; after HPA-366 the preferred candidate uses catalog identity. Do not persist city identity strings in `BattleResult`.

Country completion uses `Country <number> Conquered` for both candidates.

## BattleScene Integration

Replace the embedded legacy popup with one `ConquestReportNode`.

### Presentation origin

Use an explicit scene-local origin:

```swift
private enum ConquestReportPresentationOrigin {
    case freshLive
    case freshIdle
    case restored
}
```

Centralize presentation:

```swift
private func presentPendingConquestReport(
    origin: ConquestReportPresentationOrigin,
    resetsContinueState: Bool
)
```

The method:

1. Reads only `state.pendingBattleResult`.
2. Resolves preferred and fallback title candidates from the result key.
3. Projects `ConquestReportContent`.
4. Computes and applies `ConquestReportLayout`.
5. Marks the report visible and blocks underlying input.
6. Plays effects only for a fresh origin.

If no pending result exists, it does nothing and never fabricates a report from scene state.

For every initial fresh/restored presentation, call with `resetsContinueState: true`; this explicitly sets `isConquestContinueEnabled = true` before applying the node. Resize, safe-area refresh, and redraw use `false`, preserving the current value and never re-enabling Continue after acknowledgment begins.

### Fresh live conquest

After live combat finalizes and saves:

1. Preserve existing floating final-damage feedback.
2. Preserve existing city-conquest visual feedback.
3. Present `.freshLive` with `resetsContinueState: true`.
4. Play the existing gold burst once.

Do not pass transient `AttackResult.goldEarned` into report rendering.

### Fresh idle conquest

After foreground catch-up finalizes and saves:

1. Clear live combat and stale tooltip feedback.
2. Present `.freshIdle` with `resetsContinueState: true`.
3. Preserve the existing idle-conquest gold burst once.
4. Do not add live-only floating damage or city-conquest flourish.

Do not pass transient `IdleProgressResult.goldEarned` into report rendering.

### Restored conquest

When a newly constructed `BattleScene.didMove(to:)` completes interface construction and redraw:

- If `pendingBattleResult` exists, present `.restored` with `resetsContinueState: true`.
- Continue starts enabled and tappable.
- Show identical title, rows, badges, and Continue action.
- Do not replay gold burst, conquest flourish, floating damage, SFX, or haptic.

Repeated `didMove` on the same instance, resize, safe-area refresh, and redraw reapply only with `resetsContinueState: false`. They preserve a disabled Continue and never invoke effects.

### Input gating

While the report is visible, accept only the enabled Continue hit target. Ignore spawn, manual type selection, world, building, information tooltip, and battlefield touches.

## Initial Scene Routing

Give a pending report precedence over stage routing in `GameViewController.presentSceneForCurrentStage(in:)`:

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

- Pending live/idle result restores in `BattleScene`.
- Successful acknowledgment relaunches directly to Country Map.
- Older conquered saves without a pending result retain current behavior.
- City 15 restores its pending report before final map presentation.

State normalization already prevents a pending result from surviving in `.battleActive`.

## Continue Transaction

Scene-local guard:

```swift
private var isConquestContinueEnabled = true
```

A newly constructed scene starts enabled. Every initial fresh/restored report explicitly resets it to `true`; layout-only reapplication preserves the current value.

Continue performs this exact synchronous sequence:

1. Guard report visible, Continue enabled, pending result present, and router available.
2. Set `isConquestContinueEnabled = false`.
3. Reapply/dim the node so Continue becomes immediately non-interactive.
4. Call `state.acknowledgePendingBattleResult()`.
5. Call `store.save(state)`.
6. Request one Country Map route.

Keep the disabled report visible until routing to avoid a blank frame. Repeated taps exit at step 1. Resize/redraw after step 2 preserve `false` and cannot reopen the transaction.

If the router is unavailable, leave Continue enabled and state untouched.

## Effects Lifecycle

Effect ownership remains in `BattleScene`:

| Origin | City flourish | Floating final damage | Gold burst | Future SFX/haptic |
|---|---:|---:|---:|---:|
| Fresh live | Existing | Existing | Once | Once when integrated |
| Fresh idle | No | No | Once | Once when integrated |
| Restored | No | No | No | No |
| Resize/redraw | No replay | No replay | No replay | No replay |

The report node never starts effects.

## Defensive Behavior

- Omit missing optional MVP fields.
- Continue relying on `KingdomGameState` to normalize/drop invalid or mismatched persisted results; do not generate replacements in the scene.
- Keep required content and Continue visible on all supported layouts.
- Leave unsupported geometry paused behind `AppLayoutGateView`; do not acknowledge or route while gated.
- Use procedural fallback achievement glyphs when symbols are unavailable.
- Use the numbered fallback title when the preferred title cannot fit at 14 pt.
- Never change authoritative stored values during display formatting.

## Testing Strategy

### `CompactNumberFormatterTests`

- Preserve existing compact-number boundaries and sign behavior.
- Promote values that would round to `1000` in the lower unit.
- Confirm HUD and report consumers receive identical outputs.

### `BattleResultModelsTests`

- Deployment total across type/source/lane rows.
- Loss total across type/source rows.
- Zero totals.
- Saturating overflow.

### `ConquestReportContentTests`

- Full live and idle reports with MVP.
- Idle duration suppression.
- Missing MVP with no gap.
- Zero deployment/loss copy.
- Each achievement and neither.
- Duration boundaries and truncation.
- Shared compact-number boundaries.
- Preferred/fallback normal-city titles.
- Identical country-complete candidates.
- Exactly three or four rows.

### `ConquestReportLayoutTests`

- Three/four-row geometry.
- Zero/one/two badge layouts.
- Supported phone and iPad portrait sizes.
- Compact supported layout.
- Visible, non-overlapping Continue frame.
- Title frame and font metrics.

### `ConquestReportNodeTests`

- Exactly one title and Continue control.
- Reapply/resize does not duplicate nodes.
- Hidden unused row label.
- Preferred title when it fits.
- Fallback title only when preferred cannot fit at 14 pt.
- Enabled/disabled Continue appearance and hit behavior.
- Layout-only reapply preserves disabled Continue.
- Procedural icon fallback.

### `BattleSceneTests`

- Live/idle rendering only from pending result.
- Missing optional fields.
- Fresh effects once.
- Restored report static and Continue enabled.
- Resize/redraw duplicates neither controls nor effects.
- Resize/redraw cannot re-enable Continue after transaction start.
- Underlying input blocked.
- Acknowledge/save/route ordering.
- Duplicate Continue routes once.
- Next city does not redisplay acknowledged result.

A router spy verifies at callback time:

- Scene pending result is nil.
- Reloaded store pending result is nil.
- Route count is one.

### `GameViewControllerTests`

- Pending result takes precedence for both conquered stages.
- Conquered stage without pending result opens Country Map.
- Relaunch after acknowledgment opens Country Map.
- City 15 pending result restores first.

### Manual smoke

1. Live conquest.
2. Idle conquest.
3. Relaunch before Continue.
4. Relaunch after Continue/save.
5. Resize after tapping Continue but before scene replacement.
6. Long preferred-title fallback.
7. Compact phone.
8. iPad portrait.
9. City 15.

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

1. Extract and test shared compact-number formatting; migrate `BattleScene` HUD.
2. Add and test derived result totals and content projection.
3. Add and test pure report layout.
4. Add and test report node title selection and rendering.
5. Replace the legacy popup and render only `pendingBattleResult`.
6. Add fresh/restored effect gating and explicit Continue initialization.
7. Implement and test the synchronous Continue transaction.
8. Add initial-routing restoration tests and update `GameViewController`.
9. Run focused suites, then the complete Pyxis suite.
10. Complete the manual smoke matrix.

## Non-Goals

- Collecting or recomputing battle statistics.
- Changing combat, rewards, progression, or city completion.
- Detailed per-type tables or a secondary action.
- Chronicle/history persistence.
- Replay, sharing, analytics, leaderboards, or telemetry.
- New sound/haptic implementation beyond preserving the HPA-389 boundary.
- Persisting duplicate city identity strings.
- Broader formatting, localization, or HUD-layout work beyond the shared pure helper.