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

