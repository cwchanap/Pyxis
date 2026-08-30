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

## Fix round 1

The occupied-inspector feedback label now uses a Camp layout-owned frame in
the scenic lot region. The layout rejects a feedback frame that intersects the
selected-lot inspector or bottom tabs, and the scene regression checks both
the projected and rendered frames. The obsolete compatibility aliases and
unused projection fields identified in review were removed after verifying
there were no callers (`Option.type`, `Inspector.lot`,
`Inspector.soldierType`, `selectionPanelFrame`, the convenience layout
overload, and unused gold/city-title/count/recommendation storage).

The replacement contract tests also cover layout-gate idle accounting and
active-battle-only rearming, lifecycle observer deduplication after remount,
single fresh conquest feedback across redraw/remount, route-latch clearing on
nil/refusing routers, Settings modal shielding of Camp controls plus the
layout accessibility guard, and exactly one save for each valid build/upgrade.

### Fix-round TDD and verification

The focused RED run failed as intended before the frame seam existed:

```text
CampLayoutFrames has no member `feedback`
BuildingViewScene has no member `feedbackLabelFrameForTesting`
Testing cancelled because the build failed (3 compile failures)
```

After the minimum layout/scene seam and tests were implemented, the focused
serial run passed:

```text
Camp/BuildingView/Settings/GameVC focused suites: 26 passed, 0 failed, 0 skipped
/private/tmp/PyxisTask6FixGreen1/Logs/Test/Test-Pyxis-2026.08.30_06-10-24--0700.xcresult
```

The final serial unit run passed all 843 tests with no failures or skips:

```text
/private/tmp/PyxisTask6FixFull/Logs/Test/Test-Pyxis-2026.08.30_06-13-34--0700.xcresult
```

The Debug app build succeeded using the same project/scheme and iPhone 17
destination. `swiftlint lint` completed with 74 non-serious repository
violations (including the existing Camp layout complexity warning); no new
serious violations were reported. `git diff --check` passed.

### Fix-round runtime evidence

XcodeBuildMCP was unavailable, so the real DEBUG fixtures were exercised with
the documented direct `xcodebuild`/simulator fallback on iPhone 17. The
temporary UI capture test selected empty lot 1 through the scene's actual
touch path before taking the first screenshot. Both mounted screenshots are
1206x2622 PNGs (3x, 393x852 logical surface) and were inspected with the image
viewer:

```text
camp-empty, lot 1 selected:
/private/tmp/pyxis-task6-fix-camp-empty-builder.png
SHA-256 74e389afc8ee1ac5a85f847546d9aa2e2eb5f742d343fe37db459bd989a38389

camp-occupied, lot 1 selected:
/private/tmp/pyxis-task6-fix-camp-occupied-inspector.png
SHA-256 8c656784fc9cded30578fcb798290df2d24051cb673a0d811fdc131c7d0696a9
```

The selected-empty capture visibly shows all five enum-order options (Barracks,
Archery Range, Stable, Mage Tower, Siege Workshop), with the first option
recommended. Its builder hit targets are laid out above the bottom tabs. The
fixed occupied capture visibly shows feedback inside the lot region, separate
from the inspector and tabs, plus authored Barracks art/name, `Lv 2`, five
level pips, `LOT 1`, `Produces Infantry`, and the live upgrade cost/action.

Against `docs/visual-parity/forged-ui/camp.png`, the captures retain the
authored countryside, 25-lot arrangement, selected-lot flow, and one Settings
gear. They are not claimed as pixel parity: the canonical uses a coin drawing
and `7.4K`, compact circular lot medallions, and a fixture cost of `320`,
whereas the live DEBUG scene uses the existing compact gold presentation,
authored `building-pad-empty` art, and the existing level-2 Barracks cost of
`20`. These are documented gameplay/art or fixture deltas, not a second
economy or generic radial UI.

## Fix round 2

Removed the two remaining verified no-caller compatibility aliases without
changing Camp behavior or geometry:

- `CampChromeLayout.Constraints` (the `Input` alias)
- `CampSelectionContent.project(from:selectedLot:)` (the `selectedSlot`
  projection wrapper)

CodeGraph plus a repository reference check confirmed that production and test
callers use `CampChromeLayout.Input` and `selectedSlot` directly. No tests
needed updating.

The focused serial Camp run passed all 26 tests with no failures or skips:

```text
/private/tmp/PyxisTask6Fix2Focused/Logs/Test/Test-Pyxis-2026.08.30_06-28-20--0700.xcresult
```

`swiftlint lint` completed successfully with the unchanged repository total of
74 non-serious violations, including the existing Camp layout complexity
warning. `git diff --check` passed. The final cleanup commit is
`8f7943c`'s successor on the Task 6 branch.
