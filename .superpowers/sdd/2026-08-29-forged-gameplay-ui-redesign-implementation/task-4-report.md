# Task 4 report: Battle projection, chrome layout, and HUD

## Result

Added the pure `BattleHUDContent` projection, the bottom-up
`BattleChromeLayout`, and the fixed-tree `BattleHUDNode` required for the
Forged Battle cutover. The projection preserves the authoritative
`manualSoldierLevel(for:)` ordering: an available manual level wins first;
only a nil result falls through to unlocked/unbuilt/locked building status.
Trait multipliers and Camp recommendations remain projections of the existing
gameplay APIs. Manual living soldiers keep Camp and Map visible but disabled.

`BattleChromeLayout` reserves the tab bar, Deploy/count surface, five 56-point
medallions, and then the BattlefieldLayout-owned field from the bottom upward.
It returns nil when the required safe-area, hit-frame, field-floor, or
BattlefieldLayout visibility contract cannot be satisfied. The reference
393×852 geometry produces a 361-point content width and a 432-point field;
the compact fixture preserves a visible field above the 340-point floor.
Lane chip frames are overlays inside the field and do not reduce its height.

`BattleHUDNode` creates all PanelNode, medallion, lane-chip, label, Deploy,
and GameplayTabBarNode children once. Reapplying content/layout only updates
existing nodes and returns the scoped select/deploy/tab/requirement actions;
there is no store, router, combat, Settings, or generic HUD ownership.

## TDD and verification evidence

### RED

The new focused tests were added before the production symbols. The initial
XcodeBuildMCP focused run discovered 14 new tests and failed at compilation
with the expected missing `BattleChromeLayout`, `BattleHUDContent`, and
`BattleHUDNode` symbols (19 compiler diagnostics). No production
implementation existed at that point.

### GREEN

The focused projection/layout/HUD plus relevant existing UI/layout suites
were run through XcodeBuildMCP with parallel testing disabled:

```text
BattleHUDContentTests
BattleChromeLayoutTests
BattleHUDNodeTests
BattlefieldLayoutTests
GameUIComponentsTests
GameplayTabBarNodeTests
42 tests passed, 0 failed, 0 skipped
```

The full `PyxisTests` target was then run serially through XcodeBuildMCP:

```text
877 tests passed, 0 failed, 0 skipped
```

Targeted SwiftLint for the five Task 4 source/test files passed with
`--no-cache`, and `git diff --check` passed before staging.

## Visual verification and gate

The DEBUG `battle` fixture was launched through XcodeBuildMCP on the
configured iPhone 17 simulator after the green tests. Build/install/launch
succeeded. The screenshot capture was written by XcodeBuildMCP to:

```text
/var/folders/_k/lkrpcd8516s5x5szmkq1mbvc0000gn/T/screenshot_optimized_df6758eb-3460-472f-b01a-1fea8243b5d6.jpg
```

The capture was an optimized 368×800 image of the existing production Battle
screen; the runtime UI snapshot contained one root element and no interaction
targets. Task 5 has not mounted `BattleHUDNode` into `BattleScene`, so this
run genuinely verifies the DEBUG fixture launch and current runtime health,
but it cannot verify new-HUD screen parity against
`docs/visual-parity/forged-ui/battle.png`. Runtime screenshot/hierarchy parity
remains explicitly pending the Task 5 cutover. Source-level evidence is
limited to the pure geometry/content tests and the fixed-tree SpriteKit tests;
it is not presented as visual parity.

## Changed files

- `Pyxis/BattleChromeLayout.swift`
- `Pyxis/BattleHUDNode.swift`
- `PyxisTests/BattleChromeLayoutTests.swift`
- `PyxisTests/BattleHUDContentTests.swift`
- `PyxisTests/BattleHUDNodeTests.swift`

No BattleScene cutover, router/store/combat/settings change, or SDD progress
ledger change was made.
