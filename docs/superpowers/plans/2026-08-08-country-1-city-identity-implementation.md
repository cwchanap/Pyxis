# HPA-366 Country 1 City Identity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the reviewed 15-city Country 1 identity set through the current map, battle, building, and conquest surfaces without changing gameplay, persistence, or adding a content framework.

**Architecture:** Extend the existing `CityDefinition` / `Country1CityCatalog` source of truth with three authored strings. Keep gameplay lookup clamping unchanged; use existing title/projection/report seams for display. Flavor remains a required shipping field and reuses the Scout Card transient layer in a new non-blocking mode that leaves Attack immediately available. Conquest-report titles are resolved from `BattleResult.cityKey`, not ambient scene state.

**Tech Stack:** Swift 5, SpriteKit, UIKit, CoreGraphics, Swift Testing, Xcode/iOS Simulator.

## Global Constraints

- Implement `docs/superpowers/specs/2026-08-08-country-1-city-identity-design.md`.
- Country 1 remains exactly 15 cities.
- `name` is non-empty and <= 18 characters as a coarse authoring bound; `flavorText` is non-empty and <= 48; `conquestTitle` is non-empty and <= 24.
- Rendered width is authoritative: every `City N · Name` must fit the existing nominal Scout title size on every supported fixture. The narrowest pad title budget is currently 198 pt at 16 pt AvenirNext-DemiBold.
- City 11 is `Kingshield Keep`, not `Kingshield Bastion`.
- Names are unique case-insensitively.
- Preserve every existing defense trait and lane profile exactly.
- Do not change HP, reward, unlock, building, idle, routing, combat, sound, or haptic semantics.
- Do not add persistence fields or modify `BattleResult` / `KingdomGameState` coding keys.
- Do not add a content service, repository, registry, multi-country abstraction, localization layer, theme metadata, new scene, or HPA-390 milestone effect.
- No new production file is required; do not edit `Pyxis.xcodeproj/project.pbxproj`.
- Final-city product rule: City 15 Battle report = `Crownspire Keep Falls`; country-level `Country 1 conquered …` copy is Country Map-only after Continue.
- Country-complete identity always comes from catalog City 15 (`Country1CityCatalog.cityRange.upperBound`).
- Flavor must ship and must not disable Attack. Existing locked/completed/error feedback remains blocking exactly as today.
- Existing fitting behavior is authoritative. Fix authored copy instead of adding a second wrapping/truncation policy.
- Unit tests use Swift Testing. Always run simulator tests with `-parallel-testing-enabled NO`.

## Known call-site inventory

Production: `CityDefinition`, `Country1CityCatalog`, `KingdomGameState`, `CountryMapScoutCardContent`, `CountryMapScoutCardLayout`, `CountryMapScoutCardNode`, `CountryMapTransientFeedback`, `CountryMapScene`, `ConquestReportContent`, `BattleScene`, and existing `BuildingViewScene` shared-title usage.

Tests: `Country1CityCatalogTests`, `KingdomGameStateTests`, `CountryMapScoutCardContentTests`, `CountryMapScoutCardLayoutTests`, `CountryMapScoutCardNodeTests`, `CountryMapScoutCardTextLayoutTests`, `CountryMapScoutCardAcceptanceTests`, `CountryMapTransientFeedbackTests`, `CountryMapSceneTests`, `ConquestReportContentTests`, `ConquestReportNodeTests`, `BattleSceneTests`, `BuildingViewSceneTests`.

---

### Task 1: Author the catalog and prove the real title budget immediately

**Files:**
- Modify: `Pyxis/CityDefinition.swift`
- Modify: `Pyxis/Country1CityCatalog.swift`
- Modify: `PyxisTests/Country1CityCatalogTests.swift`
- Modify: `PyxisTests/CountryMapScoutCardTextLayoutTests.swift`

**Interfaces:**
- Produces: `CityDefinition.name`, `flavorText`, `conquestTitle`, `displayTitle`
- Produces: `Country1CityCatalog.definitionIfPresent(for:) -> CityDefinition?`
- Preserves: clamped `Country1CityCatalog.definition(for:)`

- [ ] **Step 1: Write the failing authored table and catalog assertions**

Use this exact identity set while retaining the current independent trait/lane fixture:

```swift
private static let expectedDefinitions: [ExpectedDefinition] = [
    .init(1, "Willowford", "A quiet crossing where the campaign begins.", "Willowford Secured", .standardWatch, .left, .right),
    .init(2, "Pinewatch", "A hill watchtown guarding the old trade road.", "Pinewatch Secured", .standardWatch, .center, .left),
    .init(3, "Falconridge", "Arrow towers command the high ridge road.", "Falconridge Silenced", .arrowTower, .right, .center),
    .init(4, "Bramblegate", "Iron spikes guard a narrow frontier gate.", "Bramblegate Broken", .spikedGate, .left, .right),
    .init(5, "Highcrest", "A proud hill fortress crowns the frontier.", "Highcrest Falls", .arrowTower, .center, .left),
    .init(6, "Granite Pass", "Stone walls seal the mountain road ahead.", "Granite Pass Open", .stoneWall, .right, .center),
    .init(7, "Emberford", "Burning oil guards the bridge inland.", "Emberford Secured", .burningOil, .left, .right),
    .init(8, "Greywall", "Layered stone walls protect a busy town.", "Greywall Falls", .stoneWall, .center, .left),
    .init(9, "Runewatch", "Arcane wards shimmer over the night road.", "Runewatch Unbound", .arcaneWard, .right, .center),
    .init(10, "Ironthorn Gate", "A hardened gate blocks the inner road.", "Ironthorn Gate Broken", .spikedGate, .left, .right),
    .init(11, "Kingshield Keep", "A reinforced fortress guards the royal road.", "Kingshield Keep Falls", .reinforcedKeep, .center, .left),
    .init(12, "Ashbridge", "Fire cauldrons guard the last crossing.", "Ashbridge Secured", .burningOil, .right, .center),
    .init(13, "Starveil Citadel", "Arcane wards protect the capital heights.", "Starveil Citadel Falls", .arcaneWard, .left, .right),
    .init(14, "Stonecrown", "Massive stone walls ring the royal seat.", "Stonecrown Breached", .stoneWall, .center, .left),
    .init(15, "Crownspire Keep", "The final keep rises above the capital.", "Crownspire Keep Falls", .reinforcedKeep, .right, .center)
]
```

Assert completeness, trimmed non-empty values, case-insensitive name uniqueness, the coarse character bounds, exact display title, unchanged combat metadata, existing clamping behavior, and new non-clamping optional lookup.

- [ ] **Step 2: Move the nominal Scout-title fit gate into this slice**

In `everyTitleAndRewardFitsAtItsNominalSizeInEverySupportedLayout`, read `definition.displayTitle` directly instead of `KingdomGameState().displayCityTitle(for:)`. Keep the current nominal 11 pt phone / 16 pt pad assertion. This is the gate that would have rejected `Kingshield Bastion`.

- [ ] **Step 3: Run RED**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/Country1CityCatalogTests \
  -only-testing:PyxisTests/CountryMapScoutCardTextLayoutTests
```

- [ ] **Step 4: Implement only the catalog extension**

Add `name`, `flavorText`, `conquestTitle`, computed `displayTitle`, the exact table above, and non-clamping `definitionIfPresent(for:)`. Do not change clamped `definition(for:)`.

- [ ] **Step 5: Run GREEN and commit**

Require both suites to pass, including nominal narrow-iPad title fit. Commit as `feat: author Country 1 city identities`.

---

### Task 2: Atomically move shared titles, Scout flavor data, and report ownership

**Files:** `KingdomGameState.swift`, `CountryMapScoutCardContent.swift`, `ConquestReportContent.swift`, `BattleScene.swift`; verify existing `BuildingViewScene.swift`; update `KingdomGameStateTests`, `CountryMapScoutCardContentTests`, direct Scout initializers in `CountryMapScoutCardNodeTests`, `ConquestReportContentTests`, `ConquestReportNodeTests`, `BattleSceneTests`, and `BuildingViewSceneTests`.

**Interfaces:** current-state `displayCityTitle(for:)`; static record-key `displayConquestTitle(for:)`; `Scout.flavorText`; `ConquestReportContent.project(from:title:)`.

- [ ] **Step 1: Write/update shared-title and result-key tests**

Cover authored current titles and invalid fallback. Cover `CityKey(1,15) -> Crownspire Keep Falls` and `CityKey(2,3) -> Country 2 - City 3 Conquered`. Update Scout expected data with title + flavor.

- [ ] **Step 2: Update exact-string consumers before production changes**

Move Battle HUD/tooltip, Building View conquest feedback (`Buildings conquered City 1 · Willowford.`), report-node sample, City 3 report, and both final-country Battle report assertions.

- [ ] **Step 3: Run RED across the complete Task 2 blast radius**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/KingdomGameStateTests \
  -only-testing:PyxisTests/CountryMapScoutCardContentTests \
  -only-testing:PyxisTests/CountryMapScoutCardNodeTests \
  -only-testing:PyxisTests/ConquestReportContentTests \
  -only-testing:PyxisTests/ConquestReportNodeTests \
  -only-testing:PyxisTests/BattleSceneTests \
  -only-testing:PyxisTests/BuildingViewSceneTests
```

- [ ] **Step 4: Implement display/report ownership**

Keep current UI title state-aware. Add static conquest formatting that reads only supplied `CityKey`. Change report projection to `project(from:title:)`; BattleScene passes `KingdomGameState.displayConquestTitle(for: result.cityKey)`. Add `Scout.flavorText`. Do not modify `BattleResult` or report lifecycle behavior.

- [ ] **Step 5: Search stale report signatures, run GREEN, commit**

Reject old `cityTitle:` / `isCountryComplete:` and old report strings in report/Battle scope. Rerun suites and commit `feat: project shared city identity`.

---

### Task 3: Ship Country Map identity with non-blocking flavor

**Files:** `CountryMapScoutCardContent.swift`, `CountryMapScoutCardLayout.swift`, `CountryMapScoutCardNode.swift`, `CountryMapTransientFeedback.swift`, `CountryMapScene.swift`, and their content/layout/node/transient/scene/acceptance tests.

**Interfaces:** `countryComplete(countryNumber:finalCityName:)`, `nonBlockingOverlayFrame`, `.flavor`, `blocksScoutEntry`, `applyFeedback(..., blocksAttack:)`.

- [ ] **Step 1: Keep final-country identity in pure content**

Country-complete payload includes `finalCityName` resolved from constant catalog City 15. Update pure/acceptance equality tests. Node only renders supplied data.

- [ ] **Step 2: Add pure non-blocking overlay geometry**

Add `nonBlockingOverlayFrame` spanning informational area through existing Attack gap (`6` phone / `12` pad), while keeping full `overlayFrame` unchanged. Assert containment/positive width/no Attack intersection across fixtures.

- [ ] **Step 3: Add dedicated `.flavor` transient mode**

`.flavor` uses current 2.5s timing and is the only `blocksScoutEntry == false` kind. Current feedback kinds remain blocking.

- [ ] **Step 4: Write node and scene Attack-regression tests**

Node: flavor uses non-blocking frame and preserves Attack; blocking feedback uses full frame and clears Attack. Scene: pending City 5 -> unlocked City 6; body tap shows City 6 flavor with no mutation/route/gameplay feedback; before expiry tap Attack and assert one route plus City 6 `.battleActive` persistence.

- [ ] **Step 5: Run RED**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/CountryMapScoutCardContentTests \
  -only-testing:PyxisTests/CountryMapScoutCardLayoutTests \
  -only-testing:PyxisTests/CountryMapScoutCardNodeTests \
  -only-testing:PyxisTests/CountryMapTransientFeedbackTests \
  -only-testing:PyxisTests/CountryMapSceneTests \
  -only-testing:PyxisTests/CountryMapScoutCardAcceptanceTests
```

- [ ] **Step 6: Implement all three current Attack blockers**

Node `applyFeedback(..., blocksAttack:)` chooses full vs non-blocking frame and preserves Attack only for flavor. Scene `redraw()` uses `blocksScoutEntry` instead of `transientFeedback == nil`; `applyFeedbackPresentation()` forwards the same flag; body tap calls `.flavor(scout.flavorText)`. Input priority remains overlay -> Attack -> Scout body, with flavor overlay not intersecting Attack.

- [ ] **Step 7: Integrate named map/final-country copy, run GREEN, commit**

Render supplied final name; locked/completed use shared display title; idle final copy uses constant City 15 in pure/non-SpriteKit code. Update acceptance strings. Rerun suites and commit `feat: show nonblocking city flavor`.

---

### Task 4: Run authored fit acceptance and stale-copy checks

- [ ] Enumerate all 15 flavors in non-blocking fit mode and all named locked/completed + final/error strings in blocking mode; verify fit, flavor/Attack non-intersection, and preserved Attack frame.
- [ ] Update existing all-content presentation matrix to carry authored title + flavor; do not add a duplicate matrix.
- [ ] Re-run nominal title, node, and acceptance suites; all titles remain 11/16 pt nominal.
- [ ] Run stale-copy searches and verify production names remain centralized in the catalog.
- [ ] Commit `test: validate Country 1 identity fit`.

---

### Task 5: Document ownership, run full verification, and smoke the campaign

- [ ] Update `CLAUDE.md`: catalog owns identity; copy is not persisted; reports resolve from `BattleResult.cityKey`; flavor is non-blocking for Attack.
- [ ] Run full `xcodebuild test` with parallel testing disabled.
- [ ] Run SwiftLint and `git diff --check`.
- [ ] Seed/play City 1→15 verifying Scout title/flavor, immediate Attack during flavor, Battle HUD/tooltip, Building View conquest copy, authored report title, named map feedback, and City 15 report -> map completion. Verify no gameplay/reward/lane/routing/SFX/haptic change.
- [ ] Commit `docs: document Country 1 identity ownership`.

## Risks and controls

1. **Real title budget:** Task 1 nominal fit gate; `Kingshield Keep` replaces overflowing `Kingshield Bastion` before downstream hard-coding.
2. **Flavor blocks Attack:** dedicated non-blocking kind + pure non-Attack frame + preserved entry/hit target + tap-before-expiry test.
3. **Final-country drift:** report title resolves from `BattleResult.cityKey`; Battle and map tests lock separate City/country semantics.
4. **Stale exact strings:** update known consumers atomically; search is final backstop.
5. **Transient fit:** enumerate all authored strings as cheap regression coverage.

## Final scope check

15 authored rows; zero new production files, persistence changes, gameplay systems, scenes/modals, or durable state. One pure Scout layout frame and one `.flavor` transient kind are allowed as the minimum required to ship flavor without blocking Attack.

If implementation starts introducing a reusable content platform, generic campaign abstraction, persistence migration, second text-layout policy, or milestone effect, stop and reduce scope back to this plan.