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

- Normal conquest: `<resolved city title> Conquered`
- Country completion: `Country <number> Conquered`

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

Gold, deployment count, and loss count use a private pure compact formatter inside `ConquestReportContent`, matching the existing `BattleScene.compactNumber` behavior. This ticket does not refactor unrelated HUD formatting.

### Optional data

- MVP is rendered only when both `mvpSoldierType` and `mvpDamageSharePercent` are present.
- A missing MVP creates no blank row and no zero-value placeholder.
- Favorable-counter and exposed-lane achievements appear as compact icon badges only when their persisted booleans are true.
- Zero deployments and zero losses remain visible as `Deployed: 0 · Lost: 0`.

### Achievement icons

Use two small presentation-only badges in a fixed horizontal order:

1. Favorable counter: `checkmark.shield.fill`.
2. Exposed lane: `shield.slash.fill`.

Load each with `UIImage(systemName:)`. If a symbol is unavailable, render a procedural shield fallback with the corresponding check mark or slash. Icons add no report row and do not affect model state.

## Architecture

Follow the existing Scout Card separation: pure content projection, pure layout calculation, and a focused reusable SpriteKit node.

### `ConquestReportContent`

Add `Pyxis/ConquestReportContent.swift`.

```swift
struct ConquestReportContent: Equatable {
    enum Achievement: Equatable {
        case favorableCounter
        case exposedLane
    }

    let title: String
    let summaryLines: [String]
    let achievements: [Achievement]

    static func project(
        from result: BattleResult,
        resolvedCityTitle: String,
        isCountryComplete: Bool
    ) -> ConquestReportContent
}
```

Responsibilities:

- Format title, gold, duration, live/idle distinction, MVP, and totals.
- Omit unavailable optional data.
- Preserve achievement ordering.
- Guarantee three or four summary rows.

The projector receives a resolved title instead of reading the city catalog. This keeps it pure and allows HPA-366 to change the shared city-identity API without persisting or duplicating titles in `BattleResult`.

### Derived `BattleResult` totals

Add non-persisted accessors in `BattleResultModels.swift`:

```swift
var totalDeploymentCount: Int
var totalLossCount: Int
```

Each accessor sums normalized rows using saturating integer addition. SpriteKit must not perform these reductions. The accessors can later be reused by Chronicle presentation.

### `ConquestReportLayout`

Add `Pyxis/ConquestReportLayout.swift` as a pure layout calculator.

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
- Font metrics for the current layout class.

Layout rules:

- Center the panel within the safe vertical region.
- Cap width using the current Battle scene content-width policy.
- Compute panel height from the actual row and badge counts.
- Omitted MVP closes the vertical gap.
- Keep the complete Continue hit frame inside the safe visible bounds.
- Standard metrics start at title 22 pt, rows 17 pt, Continue 16 pt, and badges 24 pt.
- Compact-height metrics use title 19 pt, rows 14 pt, Continue 15 pt, and badges 20 pt.
- Title fitting may reduce to 14 pt. If a future named-city title still does not fit, replace it with the safe numbered city title and fit again.
- Summary rows may reduce to 12 pt. The fixed English copy plus compact numeric formatting must fit every supported layout; tests enforce this.

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

The node must not:

- Read `KingdomGameState` or `BattleResult`.
- Inspect soldier nodes.
- Save or route.
- Play conquest effects.
- Decide whether the presentation is fresh or restored.

Reapplying content or layout updates the existing node tree. It never creates duplicate labels, badges, or buttons.

## City Identity Resolution

`BattleScene` resolves the title from `BattleResult.cityKey` through the current shared city-display boundary.

1. Confirm the normalized pending result matches `state.currentCityKey`.
2. Resolve the title with the current state/catalog API for `result.cityKey.cityNumber`.
3. If resolution fails in a release build, use `Country <country> - City <city>` from the result key.

Before HPA-366 this produces the existing numbered title. After HPA-366 the same boundary uses catalog-provided identity. Do not persist a city name or conquest title inside `BattleResult`.

Country completion uses `Country <number> Conquered` regardless of city naming.

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
    origin: ConquestReportPresentationOrigin
)
```

This method:

1. Reads only `state.pendingBattleResult` as report data.
2. Resolves the city title from the result's `cityKey`.
3. Projects `ConquestReportContent`.
4. Computes and applies `ConquestReportLayout`.
5. Marks the report visible and blocks all underlying battle/HUD actions.
6. Plays effects only for a fresh origin.

If no pending result exists, the method does nothing and must not fabricate a report from scene state.

### Fresh live conquest

After live combat finalizes the result and saves state:

1. Preserve the existing floating final-damage feedback.
2. Preserve the existing city-conquest visual feedback.
3. Present `state.pendingBattleResult` with `.freshLive`.
4. Play the existing gold burst once.

The scene no longer passes `AttackResult.goldEarned` into report rendering.

### Fresh idle conquest

After foreground catch-up finalizes the result and saves state:

1. Clear live combat and stale tooltip feedback.
2. Present `state.pendingBattleResult` with `.freshIdle`.
3. Preserve the existing idle conquest gold burst once.
4. Do not introduce live-only floating damage or city-conquest flourish.

The scene no longer passes `IdleProgressResult.goldEarned` into report rendering.

### Restored conquest

When `BattleScene.didMove(to:)` completes interface construction and redraw:

- If `pendingBattleResult` exists, present it with `.restored`.
- Show the same title, rows, badges, and Continue action.
- Do not play the gold burst, conquest flourish, floating damage, SFX, or haptic.

Repeated `didMove`, resize, safe-area refresh, and redraw may reapply content/layout but must not call an effect path.

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

Continue performs this exact synchronous sequence:

1. Guard that the report is visible, Continue is enabled, a pending result exists, and a router is available.
2. Set `isConquestContinueEnabled = false`.
3. Reapply/dim the report node so Continue is immediately non-interactive.
4. Call `state.acknowledgePendingBattleResult()`.
5. Call `store.save(state)`.
6. Request one Country Map route.

Do not hide or destroy the report before routing. Keeping the disabled report visible avoids a blank frame if scene presentation is delayed.

A repeated tap exits at the first guard and performs no additional acknowledgment, save, or route.

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
- Display formatting never changes authoritative stored values.

## Testing Strategy

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
- Compact numeric boundaries.
- Normal city and country-complete titles.
- Exactly three or four summary rows.

### `ConquestReportLayoutTests`

- Three-row and four-row geometry.
- Zero, one, and two badge layouts.
- Supported phone and iPad portrait sizes.
- Compact-height supported layout.
- Continue frame remains fully visible and non-overlapping.
- Title fallback and minimum-font policy.

### `ConquestReportNodeTests`

- One title, up to four row labels, optional badges, and exactly one Continue button.
- Reapply and resize do not duplicate nodes or controls.
- Hidden fourth label when MVP is absent.
- Enabled and disabled Continue appearance and hit behavior.
- Missing system symbol uses the procedural fallback.

### `BattleSceneTests`

- Live conquest renders only the persisted pending result.
- Idle conquest renders `Conquered while away`.
- Missing optional fields.
- Fresh live presentation plays existing effects once.
- Fresh idle presentation plays only its approved gold effect once.
- Restored report is static.
- Resize/redraw duplicates neither effects nor controls.
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
5. Compact supported phone layout.
6. iPad portrait layout.
7. City 15 country completion.

## File Plan

### New production files

- `Pyxis/ConquestReportContent.swift`
- `Pyxis/ConquestReportLayout.swift`
- `Pyxis/ConquestReportNode.swift`

### Modified production files

- `Pyxis/BattleResultModels.swift`
- `Pyxis/BattleScene.swift`
- `Pyxis/GameViewController.swift`

### New test files

- `PyxisTests/ConquestReportContentTests.swift`
- `PyxisTests/ConquestReportLayoutTests.swift`
- `PyxisTests/ConquestReportNodeTests.swift`

### Modified test files

- `PyxisTests/BattleResultModelsTests.swift`
- `PyxisTests/BattleSceneTests.swift`
- `PyxisTests/GameViewControllerTests.swift`

## Implementation Order

1. Add failing total-count and content-projection tests.
2. Implement derived `BattleResult` totals and `ConquestReportContent`.
3. Add failing pure layout tests and implement `ConquestReportLayout`.
4. Add failing node tests and implement `ConquestReportNode`.
5. Replace the legacy popup in `BattleScene` and render only `pendingBattleResult`.
6. Add and implement fresh-versus-restored effect gating.
7. Add and implement the synchronous Continue transaction and duplicate-input guard.
8. Add controller restoration tests and update initial routing precedence.
9. Run focused suites, then the complete Pyxis test suite.
10. Complete the manual live, idle, restoration, compact-layout, and City 15 smoke matrix.

## Non-Goals

- Collecting or recomputing battle statistics.
- Changing combat, rewards, progression, or city completion.
- Detailed per-type tables or a secondary details action.
- Chronicle/history persistence.
- Replay, sharing, analytics, leaderboards, or remote telemetry.
- New sound or haptic implementation beyond preserving the effect boundary for HPA-389.
- Persisting duplicate city identity strings.
- Refactoring unrelated number formatting or HUD layout.
