# Compact Conquest Report Design

**Issue:** HPA-388  
**Status:** Approved for implementation planning  
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

The current UI is still a legacy `BattleScene` popup with a title, one gold label, and a Continue button. Both live and idle paths pass transient `goldEarned` values into that popup, every presentation plays the gold burst, and Continue routes without acknowledging or saving. On relaunch, `GameViewController` routes conquered stages directly to `CountryMapScene`, so a pending report is currently bypassed.

## Product Decisions

### Report copy

The report has one title and three or four summary rows.

Title:

- Normal conquest: `<resolved city title> Conquered`
- Country completion: `Country <number> Conquered`

Required rows:

1. `Gold earned: +<amount>`
2. Live: `Battle time: <active duration>`
3. Idle: `Conquered while away`
4. Optional MVP: `MVP: <soldier type> · <damage share>%`
5. Final row: `Deployed: <count> · Lost: <count>`

The list above produces at most four rows because live/idle share the second-row position and MVP is omitted when unavailable.

### Duration formatting

Use compact natural formatting based only on `BattleResult.activeBattleSeconds`:

- `0s`
- `42s`
- `1m 42s`
- `1h 03m 12s`

Fractional seconds are truncated after normalizing to a finite, non-negative value. Idle conquest never displays a duration, even if restored data contains a non-zero active duration.

### Optional data

- MVP is rendered only when both `mvpSoldierType` and `mvpDamageSharePercent` are present.
- A missing MVP creates no blank row and no zero-value placeholder.
- Favorable-counter and exposed-lane achievements appear as compact icon badges only when their persisted booleans are true.
- Zero deployments and zero losses remain visible as `Deployed: 0 · Lost: 0`.

### Achievement icons

Use two small presentation-only badges in a horizontal strip:

- Favorable counter: a check-mark shield glyph.
- Exposed lane: a broken/slashed shield glyph.

The node may use installed game assets, system-symbol images, or equivalent procedural glyphs, but the semantic mapping and ordering are fixed: favorable counter first, exposed lane second. Icons add no report row and do not affect model state.

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

- Format the title, gold, duration, live/idle distinction, MVP, and totals.
- Omit unavailable optional data.
- Preserve achievement ordering.
- Guarantee three or four summary rows.

The projector receives a resolved title instead of reading the city catalog itself. This keeps it pure and allows HPA-366 to change the shared city-identity API without persisting or duplicating titles in `BattleResult`.

### Derived `BattleResult` totals

Add non-persisted accessors in `BattleResultModels.swift`:

```swift
var totalDeploymentCount: Int
var totalLossCount: Int
```

Each accessor sums the normalized rows using saturating integer addition. SpriteKit must not perform these reductions. The same accessors can later be reused by Chronicle presentation.

### `ConquestReportLayout`

Add `Pyxis/ConquestReportLayout.swift` as a pure layout calculator.

Inputs include:

- Scene size.
- Safe-area insets or the existing layout environment.
- Content width limit.
- Summary row count.
- Whether achievement icons are present.
- Compact-height classification.

Outputs include deterministic frames for:

- Panel.
- Title.
- Each visible summary row.
- Achievement strip.
- Continue button.

Layout rules:

- Center the panel in the supported scene region.
- Cap width using the scene's existing content-width policy.
- Compute height from actual rows and optional badges.
- Reduce font size and vertical spacing on compact-height layouts.
- Omitted MVP closes the vertical gap.
- Keep the complete Continue hit frame inside the supported visible bounds.
- Return an explicit failure only when required content cannot fit at the documented minimum sizes; the scene must then remain safely blocked rather than route or acknowledge silently.

### `ConquestReportNode`

Add `Pyxis/ConquestReportNode.swift`.

The node owns:

- The modal panel.
- One title label.
- Four reusable row labels, hiding unused labels.
- Two reusable achievement badge nodes.
- One Continue button and its hit frame.

Suggested API:

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

`BattleScene` resolves the report title from `BattleResult.cityKey` through the current shared city-display API.

- Before HPA-366, use the existing safe `Country N - City M` display title.
- After HPA-366, the same resolution boundary uses the catalog-provided identity.
- Do not persist a city name or conquest title inside `BattleResult`.
- If a release build cannot resolve an authored definition, fall back to the existing numbered title rather than failing report restoration.

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
3. Preserve the existing idle conquest presentation, including the gold burst, once.
4. Do not introduce live-only floating damage or city-hit feedback.

The scene no longer passes `IdleProgressResult.goldEarned` into report rendering.

### Restored conquest

When `BattleScene.didMove(to:)` completes interface construction and redraw:

- If `pendingBattleResult` exists, present it with `.restored`.
- Show the same title, rows, badges, and Continue action.
- Do not play the gold burst, conquest flourish, floating damage, SFX, or haptic.

Repeated `didMove`, resize, safe-area refresh, and redraw may reapply content/layout but must not call any effect path.

### Input gating

While the report is visible, `BattleScene` accepts only the enabled Continue hit target. Spawn, manual type selection, world, building, information tooltip, and background battlefield touches are ignored.

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
- Country 15 also restores its pending report before the final Country Map presentation.

## Continue Transaction

`BattleScene` owns a scene-local guard such as:

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

If the router is unavailable, leave Continue enabled and leave state untouched so a later valid interaction can complete the transaction.

## Effects Lifecycle

Effect ownership remains in `BattleScene`, separate from report rendering.

| Origin | City flourish | Floating final damage | Gold burst | Future SFX/haptic |
|---|---:|---:|---:|---:|
| Fresh live | Existing behavior | Existing behavior | Once | Once when integrated |
| Fresh idle | No new live-only effect | No | Once | Once when integrated |
| Restored | No | No | No | No |
| Resize/redraw | No replay | No replay | No replay | No replay |

The report node never starts effects, so node reapplication cannot replay them.

## Error and Defensive Behavior

- Missing optional MVP fields are omitted.
- Invalid or mismatched persisted results continue to be normalized/dropped by `KingdomGameState`; the scene does not compensate by generating a new result.
- If required report content cannot fit, keep the report state unacknowledged and surface the existing unsupported-layout gate or equivalent safe blocked state. Never route past an unreadable report automatically.
- If an achievement icon image is unavailable, render its procedural fallback glyph; do not remove the persisted achievement silently.
- All counts and displayed gold use compact-number formatting without changing authoritative stored values.

## Testing Strategy

### `BattleResultModelsTests`

Cover:

- Total deployment count across type/source/lane rows.
- Total loss count across type/source rows.
- Zero totals.
- Saturating overflow behavior.

### `ConquestReportContentTests`

Cover:

- Full live report with MVP and both achievements.
- Full idle report with MVP.
- Idle mode suppresses active duration.
- Missing MVP produces three rows with no gap.
- Zero deployment and zero loss copy.
- Each achievement independently and neither achievement.
- Duration boundaries and truncation.
- Normal city and country-complete titles.
- Exactly three or four summary rows.

### `ConquestReportLayoutTests`

Cover:

- Three-row and four-row geometry.
- Layouts with zero, one, and two badges.
- Supported phone and iPad portrait sizes.
- Compact-height supported layout.
- Continue frame remains fully visible and non-overlapping.
- Required-content fit failure at impossible sizes.

### `ConquestReportNodeTests`

Cover:

- One title, up to four row labels, optional badges, and exactly one Continue button.
- Reapply and resize do not duplicate nodes or controls.
- Hidden fourth row when MVP is absent.
- Enabled and disabled Continue appearance/hit behavior.
- Missing icon asset uses a fallback glyph.

### `BattleSceneTests`

Cover:

- Live conquest renders only the persisted pending result.
- Idle conquest renders `Conquered while away`.
- Missing optional fields.
- Fresh live presentation plays existing effects once.
- Fresh idle presentation plays only its approved effects once.
- Restored report is static.
- Resize/redraw duplicate neither effects nor controls.
- Underlying HUD and battlefield input is blocked.
- Continue acknowledges, saves, then routes.
- Duplicate Continue routes once.
- Next-city state does not redisplay an acknowledged result.

A router spy verifies acknowledgment ordering at callback time:

- The scene's pending result is already nil.
- Reloading the store returns a nil pending result.
- Route count is exactly one.

### `GameViewControllerTests`

Cover:

- Pending result takes precedence and presents `BattleScene` for both conquered stage values.
- Conquered stage without a pending result presents `CountryMapScene`.
- Relaunch after acknowledgment presents Country Map.
- Country 15 pending result restores before country-complete map presentation.

### Manual smoke

Verify:

1. One live conquest.
2. One idle conquest.
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
