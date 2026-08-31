# Task 10 report: capture stabilization and parity evidence

## Status

Task 10 is complete on the dedicated native 393x852 simulator. DEBUG capture
markers compile out of Release, the fixture smoke verifies the required routes
and state transitions, and the parity board contains direct native captures,
deterministic overlays, and discrepancy notes. The final-review evidence also
recaptures Camp empty/occupied and Conquest live/idle after the route, count,
gear, and fixture-state fixes. Round 2 persists the idle occupied-slot count
in `BattleResult` (legacy results decode without it), clears both city HP-bar
nodes whenever a Conquest report is visible or fit-failed, and re-arms the
building clock only after a rejected nonlethal Map-to-Battle route. `progress.md`
was not changed.

## Implementation

- Added the DEBUG-only `-pyxis-freeze-combat` marker. `BattleScene.update` keeps
  its clock bookkeeping but returns before combat advancement; no save or
  Settings state is introduced. The focused RED parser correction and GREEN
  test cover this boundary.
- Added one serial XCTest fixture smoke for Battle normal/blocked, Camp
  empty/occupied, Map attackable/locked/complete, Conquest live/idle, and a
  Settings one-off toggle. It skips before the fixture loop on any logical
  frame other than 393x852, so the CI iPhone 17 destination cannot fail on a
  capture-only requirement. On the dedicated device it asserts the exact
  route/state probes below and attaches one screenshot per fixture, with one
  shared Map capture; it does not compare pixels.
- Replaced the old fixture-marker echo with one private DEBUG-only probe that
  reads the routed `view.scene` and persisted `store.load()` after routing.
  The blocked path probes after its injected live soldier. Focused tests and
  the UI smoke assert these actual values:
  `Battle;stage=battleActive;mode=normal;city=1-3;manualLiving=0`,
  `Battle;stage=battleActive;mode=blocked;city=1-3;manualLiving=1`,
  `Camp;stage=battleActive;city=1-5;buildings=0`,
  `Camp;stage=battleActive;city=1-5;buildings=6`,
  `Map;stage=cityConqueredPendingMap;completed=3;attackableCity=4;laterLockedCity=5`,
  `Map;stage=countryComplete;completed=15;attackableCity=none;laterLockedCity=none`,
  `Conquest;pending=true;mode=live;city=1-3;source=manual;deployments=6;losses=1`,
  and
  `Conquest;pending=true;mode=idle;city=1-3;source=idle;deployments=0;losses=0;buildings=2;idleDamage=1`.
- Camp fixture routing now uses the existing DEBUG scene seam to select slot 1
  before capture: empty Camp proves `selectedSlot=1;mode=builder` with all five
  building options mounted, while occupied Camp proves
  `selectedSlot=1;mode=inspector` against the six-building fixture.
- Idle Conquest fixture data is now produced by the real building-driven idle
  settlement path: two Barracks create nonempty typed idle damage, conquer City
  3, award the authoritative `+17`, and finalize an optional persisted
  occupied-slot count of `2 BUILDINGS` before the city grid is cleared. Live
  results leave this field absent; legacy JSON without the field still decodes.
- Country Map → Battle tab exit now settles the existing background clock before
  the central pending/stage route, saves once on an accepted route, redraws and
  applies idle feedback, and restores lethal idle conquest reports. If a
  nonlethal route is rejected while the city remains active, it re-arms the
  building timestamp at the same exit date and saves the retry state once more;
  lethal pending state is not re-armed. Conquest reports keep the sole Settings
  gear and both city HP-bar nodes hidden/cleared while visible or fit-failed,
  including restored and resize paths.
- Added only the accessibility-surface identifier/value needed to expose the
  existing gameplay route state and Settings preference transition to XCTest.
  Rendering, routing, persistence, and gameplay ownership remain unchanged.
- Documented Forged scene/router/tab/material/layout/Settings/fixture/combat
  ownership in `CLAUDE.md`.

## Native capture

- Device: `Pyxis-Parity-393x852`, iPhone 15 Pro
  (`com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro`)
- Runtime: iOS 26.5 (`23F77`)
- UDID: `771133AB-2A09-4C6E-85FD-9D7523E8D2C7`
- Source device geometry: logical 393x852 points, native scale 3x, native
  framebuffer 1179x2556 pixels. Direct `simctl io screenshot` was used for all
  board files, with no resize or crop.
- Final-review recapture set: `camp-empty`, `camp-occupied`, `conquest-live`,
  and `conquest-idle` were launched with the exact DEBUG fixture markers and
  `-pyxis-freeze-combat`, captured directly from the same simulator framebuffer,
  and replaced in the board at 1179x2556. Their four 50% overlays were
  regenerated from the updated native files and canonical mocks; no canonical
  image was modified.
- Final-review capture semantics: Camp empty is the five-option builder with
  slot 1 selected; Camp occupied is the slot-1 inspector; Conquest live and idle
  have no Settings gear. Idle Conquest visibly reports `+17`, `2 BUILDINGS`,
  `100% MVP`, and `0/0 SENT/LOST` from the realistic two-Barracks fixture.
- XCUITest `XCUIScreenshot` exports are 1178x2556 on this runner; those remain
  only as result-bundle attachments and are explicitly not labeled as native
  board captures.
- Passing dedicated smoke result bundle:
  `test_sim_2026-08-30T23-42-46-973Z_pid19570_369eddfd.xcresult`
- CI-shaped iPhone 17 smoke result bundle:
  `test_sim_2026-08-30T23-45-38-493Z_pid19570_5b490aa3.xcresult`
- Full serial result bundle:
  `test_sim_2026-08-30T23-50-37-478Z_pid19570_ecb0f093.xcresult`

## Verification

- Focused freeze test: passed.
- Focused fixture-hook semantics: **12 passed, 0 failed, 0 skipped**.
- Fixture UI smoke on the dedicated device: **1 passed, 0 failed, 0 skipped**
  (102.2s result duration). The full serial run also passed all non-skipped
  fixture assertions.
- CI-shaped iPhone 17 capture smoke: **0 passed, 0 failed, 1 skipped**
  (285.1s result duration), with the skip raised after the baseline app frame
  was read and before the fixture loop.
- Full serial unit + UI run with `-parallel-testing-enabled NO` and coverage:
  **861 passed, 0 failed, 1 skipped** out of 862 tests in 168.4s. The one skip
  is the intentional iPhone 17 capture-smoke geometry gate.
- Local coverage from the fresh full result bundle is **96.7% overall**
  (35,292/36,501), with Pyxis.app **94.6%** (15,017/15,869) and PyxisTests
  **98.7%** (20,213/20,470). The executable-added-line patch proxy is
  **94.99% (3,978/4,188)** against the branch merge-base, above the requested
  90% gate. Remote Codecov remains an external pending gate until CI publishes
  the report.
- SwiftLint `lint --no-cache`: completed with 70 pre-existing warnings and 0
  serious violations; no warning originates from the added lines. The only
  warnings in touched Swift files are existing BattleScene/UI-test template
  line-length warnings.
- `git diff --check origin/main...HEAD` and working-tree `git diff --check`:
  passed.
- Release build used fresh derived data via XcodeBuildMCP:
  `/tmp/PyxisForgedReleaseFinalReviewRound2MCP/Build/Products/Release-iphonesimulator/Pyxis.app/Pyxis`.
  The Release `build_sim` returned 0, and `strings` proved both
  `-pyxis-forged-fixture` and `-pyxis-freeze-combat` absent.

## Evidence paths

- Board: `docs/visual-parity/forged-ui/README.md`
- Canonical mocks: `docs/visual-parity/forged-ui/{battle,camp,map,conquest,settings}.png`
- Direct native captures: `docs/visual-parity/forged-ui/native/`
- Deterministic 50% overlays: `docs/visual-parity/forged-ui/overlays/` (9
  unique files for 10 board rows; Map attackable and locked intentionally
  share `map-attackable-50-overlay.png`)

The Map board explicitly records the deliberate computed 164pt card versus the
taller mock: preserving all authored 44pt route interactions and required
headroom is the shipping geometry contract.

## Changed files

- `CLAUDE.md`
- `Pyxis/BattleScene.swift`
- `Pyxis/FeedbackSettingsAccessibilityAdapter.swift`
- `Pyxis/GameViewController.swift`
- `PyxisTests/BattleSceneTests.swift`
- `PyxisUITests/PyxisUITests.swift`
- `docs/visual-parity/forged-ui/README.md`
- `docs/visual-parity/forged-ui/native/*.png`
- `docs/visual-parity/forged-ui/overlays/*.png` (the byte-identical
  `map-locked-50-overlay.png` was removed in favor of the shared attackable
  overlay)
- `.superpowers/sdd/2026-08-29-forged-gameplay-ui-redesign-implementation/task-10-report.md`

Round-2 final-review additions also touch `Pyxis/BattleResultModels.swift`,
`Pyxis/ConquestReportContent.swift`, `Pyxis/CountryMapScene.swift`,
`Pyxis/ForgedVisualFixture.swift`, `Pyxis/KingdomGameState.swift`,
`PyxisTests/BattleResultModelsTests.swift`,
`PyxisTests/ConquestReportContentTests.swift`,
`PyxisTests/CountryMapSceneTests.swift`,
`PyxisTests/ForgedVisualFixtureTests.swift`,
`PyxisTests/GameViewControllerTests.swift`,
`PyxisTests/KingdomGameStateTests.swift`, and the refreshed Conquest idle
native/overlay pair.
