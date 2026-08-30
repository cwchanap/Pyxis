# Task 6 report: Camp selection builder and inspector cutover

## Result

Replaced the legacy Building View palette/action/recommendation chrome with a
fixed Camp selection tree. The scene still owns the countryside backdrop, all
25 authored scenic lot anchors, real slot selection, lifecycle/store/feedback
handling, and the existing Settings controller. Selecting an empty lot now
projects exactly the five `BuildingType.allCases` options in enum order;
selecting an occupied lot now projects a single inspector with authored
building art/name, level pips, lot number, produced soldier, and the existing
upgrade cost/action.

`CampSelectionContent` is the pure projection. It applies the required
locked -> capped -> affordability precedence and only marks a recommendation
when the selected slot, building type, and build/upgrade action all match the
existing `RecommendedCampRecommendation`. `CampChromeLayout` owns the
safe-area-derived 25-lot, builder, inspector, Settings, and tab geometry.
`CampSelectionNode` is a fixed SpriteKit tree built once and reapplied with
projected content/layout; it does not own economy, persistence, routing, or
feedback.

Build and upgrade actions continue to call `KingdomGameState.buildBuilding`
and `upgradeBuilding` exactly once. Successful mutations save once before
feedback. Invalid actions continue to use the existing invalid-action
feedback. Settlement still happens before the mutation, a conquest result
stays pending while Camp remains mounted, and an explicit Map request is
forwarded through the existing pending-first GameViewController route.

## TDD and verification evidence

### RED

The Task 6 focused tests were added before the Camp projection/layout/node
symbols and Building View cutover existed. The initial focused run failed at
compile time on the missing `CampChromeLayout`, `CampSelectionContent`, and
`CampSelectionNode` contracts. The tests cover option order/state precedence,
exact recommendation matching, occupied inspector details and real cost,
edge-lot geometry, fixed-tree/action routing, mutation/save ordering,
invalid feedback, settlement/pending conquest, lifecycle idempotence, and
Settings accessibility fallback.

### GREEN

Focused serial run (parallel testing disabled):

```text
CampChromeLayoutTests
CampSelectionContentTests
CampSelectionNodeTests
BuildingViewSceneTests
18 passed, 0 failed, 0 skipped
```

Full serial unit run (parallel testing disabled):

```text
PyxisTests: 835 passed, 0 failed, 0 skipped
967 device test runs including dynamic parameters
```

The full result bundle is:

```text
/private/tmp/PyxisTask6Full/Logs/Test/Test-Pyxis-2026.08.30_05-45-19--0700.xcresult
```

`swiftlint lint` completed successfully with the repository's existing
warning set (`74` warnings, `0` serious). The only new warning is the
cyclomatic-complexity warning for the pure `CampChromeLayout.compute`
projection. `git diff --check` passed. The Pyxis app source/test typechecks
and the Debug simulator app build also passed.

## Runtime screenshots

The XcodeBuildMCP connector was not available in this agent, so the required
runtime checks used the documented direct `xcodebuild`/`simctl` fallback with
the booted iPhone 17 simulator (393x852 logical surface, 3x screenshot
output). Both DEBUG fixtures were installed/launched with the existing
`-pyxis-forged-fixture` argument and inspected using the image viewer:

```text
camp-empty:
/private/tmp/pyxis-task6-camp-empty-v3.png
SHA-256 2b40b28a2dc8b8ebbd2504e0b9819e2212c24d1cc9987be4a29138c44d3c1686

camp-occupied (unselected):
/private/tmp/pyxis-task6-camp-occupied-v1.png
SHA-256 ce70b7d085f1280dd1d24d9b058053a653240a123036fbc3792de414a746aff6

camp-occupied (lot 1 selected):
/private/tmp/pyxis-task6-camp-occupied-inspector.png
SHA-256 def60415ef166763e4f49486c7382e75a4752dbc5027acfc28d3d3c7d74dc342
```

The mounted empty and occupied screens visibly retain the authored
countryside and 25-lot arrangement, show one Settings gear, and replace the
old control chrome with Camp tabs and selection-driven content. The selected
occupied capture visibly contains the Barracks art/name, Lv 2, five level
pips, `LOT 1`, `Produces Infantry`, and the live `20` upgrade cost/action.
These are real mounted simulator captures, not source/geometry parity claims.

## Comparison with canonical `camp.png`

Inspected against `docs/visual-parity/forged-ui/camp.png`. The scene preserves
the canonical composition's broad header, scenic lot flow, inspector region,
and bottom tab placement, but the captures are not claimed as pixel parity.
Concrete remaining visual differences are:

- the canonical gold panel includes a coin illustration and uses its fixture
  amount (`7.4K`), while the current DEBUG camp fixtures render the existing
  compact gold value (`1M`) without a coin sprite;
- the canonical empty-lot markers are compact dark circular medallions,
  while the current scene reuses the existing `building-pad-empty` authored
  pad art with a plus label;
- the canonical inspector fixture shows its authored sample cost (`320`),
  while the mounted state correctly projects the existing API's live level-2
  Barracks upgrade cost (`20`).

Those differences are fixture/art treatment or existing asset availability;
the implementation does not invent a second economy or replace the existing
building assets/mutation APIs.

## Changed files

- `Pyxis/BuildingViewScene.swift`
- `Pyxis/CampChromeLayout.swift`
- `Pyxis/CampSelectionNode.swift`
- `PyxisTests/BuildingViewSceneTests.swift`
- `PyxisTests/CampChromeLayoutTests.swift`
- `PyxisTests/CampSelectionContentTests.swift`
- `PyxisTests/CampSelectionNodeTests.swift`
- `.superpowers/sdd/2026-08-29-forged-gameplay-ui-redesign-implementation/task-6-report.md`

No gameplay model, economy formula, persistence schema, lifecycle
notification, feedback policy, settings controller, router, or SDD progress
ledger file was modified.
