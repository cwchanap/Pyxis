# Task 7 Report: Forged selected-city map

Status: complete

## Implemented

- Replaced the fixed Country Map card/map sizing with the computed vertical budget. The contract is now `tabBarHeight = 72`, preferred card heights of 164pt (phone) and 140pt (iPad), a 48pt compact-card floor, a 431pt illustrated-map floor, and a 45pt minimum authored city-center distance.
- The map transform derives the authored minimum center distance from the existing Country 1 anchors, uses the maximum width-fill/height-fill/45pt spacing scale, keeps the backdrop aspect ratio and horizontal centering, and vertically centers the city-target plus route-stroke interaction envelope. All city targets and the 18 authored routes are validated before a layout is returned.
- Removed the duplicate current-city button/control. Map selection is scene-local: tapping a city selects it without mutating the model; MARCH uses the existing sequential `startCityFromMap` path, while RETURN routes the active current city back to Battle without restarting it.
- Added the horizontal compact scout card for 48pt budgets. It retains city identity/status and a 44pt+ primary action; rich detail remains available through the existing informational/flavor path. No scrolling or panning was added.
- Preserved pending-first routing, authored backdrop/anchors/routes, status/feedback/flavor semantics, tab/gear ownership, and fail-closed geometry behavior.

## Geometry evidence

Pure geometry probe output:

| Fixture | Card | Illustrated map | City headroom | Route headroom |
| --- | ---: | ---: | ---: | ---: |
| 375x667, zero insets | 48 | 431 | 8.2676 | 27.2676 |
| 375x812, 50/34 insets | 133 | 431 | 8.2676 | 27.2676 |
| 393x852, 59/34 insets | 164 | 431 | 8.2676 | 27.2676 |
| iPad mini fixture | 140 | 785 | 22.587 | 41.587 |
| 11-inch iPad fixture | 140 | 846 | 11.0008 | 30.0008 |

The closest authored center distance resolves to 45pt or greater in the reference fixture, and every target/route containment assertion passes. A budget below 48pt returns nil.

## Runtime captures

Both fixtures were launched at the 393x852 iPhone 17 simulator through XcodeBuildMCP and inspected against `docs/visual-parity/forged-ui/map.png`:

- [map fixture PNG](/private/tmp/pyxis-task7-map.png)
- [country-complete fixture PNG](/private/tmp/pyxis-task7-map-country-complete.png)

The map fixture shows the authored route and compact identity/status card with MARCH. The country-complete fixture preserves the map/tabs and shows the completion feedback card. The computed 164pt reference card is intentionally shallower than the taller canonical mock card; this is the planned geometry discrepancy required to preserve the 431pt map and 45pt/8pt/27pt geometry contract.

## Verification

- Focused Map/Card/GameplayTab/GameViewController suites: 192 parameterized cases passed, 0 failed.
- `CountryMapScoutCardTextLayoutTests`: 17 passed, 0 failed.
- Full serial `PyxisTests` via XcodeBuildMCP (`-parallel-testing-enabled NO`): 841 passed, 0 failed, 0 skipped.
- `swiftc -parse` over all 12 changed Swift files: passed.
- SwiftLint over all 12 changed Swift files: 0 violations.
- `git diff --check`: passed.

## Review fix round

- Current-city RETURN now uses the existing `requestEntry(for:)` path. It settles and saves idle progress before routing, leaves lethal idle conquest pending on the map, and preserves the active city instead of restarting it. Added nonlethal and lethal action-path coverage.
- The vertical stack is bottom-up: the 72pt tabs sit at the bottom safe area, the scout card is above them, and the illustrated map is above the card. The reference arithmetic remains tabs `y=34...106`, card `y=114...278` at 164pt, and map `y=278...709` at 431pt for 393x852 with 59/34 insets.
- Map chrome now has a separate gold/resource tile, a 15-segment Country 1 progress row, and the one existing framed Settings gear at top-right. Rich selected-city cards use the existing `enemy-city` art while retaining authored identity, defense details, reward, flavor, and the 44pt+ MARCH/RETURN action.

Review-round captures (XcodeBuildMCP, iPhone 17 DEBUG fixtures, optimized 368x800 output):

- [map fixture PNG](/private/tmp/pyxis-task7-map-fix.png)
- [country-complete fixture PNG](/private/tmp/pyxis-task7-map-country-complete-fix.png)

The 164pt selected-city card remains intentionally shallower than the canonical mock; all other observed stack/chrome/card gaps were addressed.

Review-round verification:

- Focused Map/Card/GameplayTab/GameViewController suites: 196 passed, 0 failed, 0 skipped.
- Full serial `PyxisTests` via XcodeBuildMCP (`-parallel-testing-enabled NO`): 845 passed, 0 failed, 0 skipped.
- `swiftc -parse` over all fix-round Swift files: passed.
- SwiftLint over all fix-round Swift files: 0 violations.
- `git diff --check`: passed; report ends with one newline.

## Review fix round 2

- Re-laid out the existing title allocation into a 44pt upper row for the resource tile and framed Settings gear, plus a 22pt lower row for the Country title/progress treatment. At the 393x852 reference fixture the resource/treatment/gear rows are contained and visually separated; map/card budgets are unchanged.
- Added exact reference frame and pairwise separation assertions, then verified the mounted map and country-complete fixtures after the fix:
  - [map fixture PNG](/private/tmp/pyxis-task7-map-round2.png)
  - [country-complete fixture PNG](/private/tmp/pyxis-task7-map-country-complete-round2.png)

The available iPhone 17 simulator does not expose the requested 393x852 logical surface. XcodeBuildMCP's screenshot endpoint returns an optimized 368x800 image, and direct `simctl io screenshot` cannot connect to CoreSimulatorService in this environment. These captures are therefore honest optimized runtime evidence, not native-size proof; exact 393x852 capture remains an open Task 10 runtime-evidence gate. No substantive header overlap remains in the mounted screens.

Review-round-2 verification:

- CountryMapLayoutTests: 18 passed, 0 failed, 0 skipped.
- Focused Map/Card/GameplayTab/GameViewController suites: 197 passed, 0 failed, 0 skipped.
- Full serial `PyxisTests` via XcodeBuildMCP (`-parallel-testing-enabled NO`): 846 passed, 0 failed, 0 skipped.
- `swiftc -parse` over all fix-round Swift files: passed.
- SwiftLint over all fix-round Swift files: 0 violations.
- `git diff --check`: passed; report ends with one newline.
