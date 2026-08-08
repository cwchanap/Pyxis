# HPA-366 Country 1 City Identity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the reviewed 15-city Country 1 identity set through the current map, battle, building, and conquest surfaces without changing gameplay, persistence, or adding a content framework.

**Architecture:** Extend `CityDefinition` / `Country1CityCatalog` with three authored strings. Keep gameplay lookup clamping unchanged. Current UI titles reuse state display seams; conquest reports resolve from `BattleResult.cityKey`. Flavor ships through the existing Scout Card transient layer in one non-blocking mode that leaves Attack immediately available.

**Tech Stack:** Swift 5, SpriteKit, UIKit, CoreGraphics, Swift Testing, Xcode/iOS Simulator.

## Global Constraints

- Country 1 stays exactly 15 cities.
- `name` <= 18 chars as a coarse bound; `flavorText` <= 48; `conquestTitle` <= 24; all non-empty; names unique case-insensitively.
- Rendered title fit is authoritative. Narrowest current pad title frame is 198 pt at 16 pt AvenirNext-DemiBold; phone nominal is 11 pt.
- City 11 = `Kingshield Keep` (not overflowing `Kingshield Bastion`).
- Preserve all current trait/lane/HP/reward/unlock/building/idle/routing/combat/SFX/haptic semantics.
- No persistence schema, content service, registry, multi-country abstraction, localization layer, theme metadata, scene, or HPA-390 milestone effect.
- New production files: 0. Do not edit `project.pbxproj`.
- City 15 Battle report = `Crownspire Keep Falls`; overall country completion is Country Map-only after Continue.
- Country-complete name always comes from catalog City 15.
- Flavor is required and must not disable Attack. Existing invalid/locked/completed/error feedback remains blocking.
- Existing fit behavior is authoritative; shorten copy instead of adding another layout policy.
- Unit tests use Swift Testing; simulator tests run with `-parallel-testing-enabled NO`.

## Call-site inventory

Production: `CityDefinition`, `Country1CityCatalog`, `KingdomGameState`, `CountryMapScoutCardContent`, `CountryMapScoutCardLayout`, `CountryMapScoutCardNode`, `CountryMapTransientFeedback`, `CountryMapScene`, `ConquestReportContent`, `BattleScene`, plus existing Building View shared-title consumption.

Tests: catalog/state/Scout content/layout/node/text-layout/acceptance/transient/scene suites, report content/node suites, BattleSceneTests, BuildingViewSceneTests.

---

### Task 1: Author the catalog and gate the real title budget

**Files:** `CityDefinition.swift`, `Country1CityCatalog.swift`, `Country1CityCatalogTests.swift`, `CountryMapScoutCardTextLayoutTests.swift`.

- [ ] Extend the independent expected fixture with the exact reviewed 15-city table below while preserving current trait/lane values:

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

- [ ] Add catalog completeness/uniqueness/coarse-length/display-title assertions and `definitionIfPresent(for:)` non-clamping tests. Keep existing exact combat metadata and clamping tests.
- [ ] In existing `everyTitleAndRewardFitsAtItsNominalSizeInEverySupportedLayout`, read `definition.displayTitle` directly. Keep nominal 11/16 pt assertion. This gate belongs in Task 1 and would reject `Kingshield Bastion`.
- [ ] Run RED:

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/Country1CityCatalogTests \
  -only-testing:PyxisTests/CountryMapScoutCardTextLayoutTests
```

- [ ] Implement `CityDefinition.name/flavorText/conquestTitle/displayTitle`, exact table, and non-clamping `definitionIfPresent(for:)`. Keep clamped `definition(for:)` unchanged.
- [ ] Run GREEN; commit `feat: author Country 1 city identities`.

---

### Task 2: Atomically move shared titles, Scout flavor data, and report ownership

**Files:** `KingdomGameState.swift`, `CountryMapScoutCardContent.swift`, `ConquestReportContent.swift`, `BattleScene.swift`; exact-string tests in state/Scout/report/Battle/Building suites; verify BuildingView production already consumes shared title.

- [ ] Add current-title authored/fallback tests and result-record tests:

```swift
#expect(KingdomGameState.displayConquestTitle(
    for: CityKey(countryNumber: 1, cityNumber: 15)
) == "Crownspire Keep Falls")
#expect(KingdomGameState.displayConquestTitle(
    for: CityKey(countryNumber: 2, cityNumber: 3)
) == "Country 2 - City 3 Conquered")
```

- [ ] Update Scout expected/direct construction with `displayTitle` + `flavorText`.
- [ ] Update Battle HUD/tooltip, Building View conquest copy (`Buildings conquered City 1 · Willowford.`), report node sample, City 3 report, and both final-country Battle report assertions before production changes.
- [ ] Run the state/Scout/node/report/Battle/Building test groups and verify RED.
- [ ] Keep `displayCityTitle(for:)` state-aware; add static `displayConquestTitle(for cityKey:)` that uses both values from the supplied key and reads no ambient state.
- [ ] Change `ConquestReportContent.project` to `project(from:title:)`, remove only the old title branch, and have BattleScene pass `KingdomGameState.displayConquestTitle(for: result.cityKey)`. Add `Scout.flavorText`. Do not modify `BattleResult` or report lifecycle behavior.
- [ ] Search stale `cityTitle:` / `isCountryComplete:` and old report title strings; run GREEN; commit `feat: project shared city identity`.

---

### Task 3: Ship Country Map identity with non-blocking flavor

**Files:** Scout content/layout/node, transient feedback, CountryMapScene, and their content/layout/node/transient/scene/acceptance tests.

- [ ] Change pure country-complete payload to `countryComplete(countryNumber:finalCityName:)`; resolve final name from catalog City 15. Node renders supplied content and does not read catalog.
- [ ] Add pure `nonBlockingOverlayFrame` covering informational area through existing Attack gap (6 pt phone / 12 pt pad); keep full `overlayFrame` unchanged. Assert no Attack intersection across all fixtures.
- [ ] Add `.flavor`, `blocksScoutEntry` (`false` only for flavor), and `flavor(_:)` using current 2.5s timing. Current feedback kinds stay blocking.
- [ ] Node test: non-blocking flavor uses the new frame and preserves `attackHitFrame`; blocking feedback uses full frame and clears Attack.
- [ ] Scene test: pending City 5 -> unlocked City 6; body tap shows City 6 flavor with no mutation/route/gameplay feedback; before expiry tap Attack and assert one route plus City 6 `.battleActive` persistence.
- [ ] Run RED across content/layout/node/transient/scene/acceptance suites.
- [ ] Implement all three current Attack blockers: node blocking flag/frame; scene entry uses `blocksScoutEntry` rather than any-transient; presentation forwards same flag. Body tap calls `.flavor(scout.flavorText)`. Input priority remains overlay -> Attack -> Scout body; flavor overlay excludes Attack.
- [ ] Integrate named locked/completed/idle/final-country copy, update acceptance exact strings, run GREEN, commit `feat: show nonblocking city flavor`.

---

### Task 4: Run authored fit acceptance and stale-copy checks

- [ ] Extend existing feedback-fit test to all 15 flavors in non-blocking mode and all named locked/completed + final/error copy in blocking mode; verify fit, no flavor/Attack overlap, preserved Attack frame.
- [ ] Update existing all-content matrix with authored title + flavor; do not add another matrix.
- [ ] Re-run nominal title, node, and acceptance suites; all titles stay nominal 11/16 pt.
- [ ] Run stale-copy searches and verify production names remain centralized in the catalog.
- [ ] Commit `test: validate Country 1 identity fit`.

---

### Task 5: Document ownership, full verification, campaign smoke

- [ ] Update `CLAUDE.md`: catalog owns identity, identity not persisted, reports resolve from `BattleResult.cityKey`, Scout flavor never disables Attack.
- [ ] Full `xcodebuild test` with parallel disabled; SwiftLint; `git diff --check`.
- [ ] Seed/play City 1→15 verifying Scout title/flavor, immediate Attack during flavor, Battle HUD/tooltip, Building View copy, authored report title, named map feedback, City 15 report -> country-map completion, and unchanged gameplay/SFX/haptics.
- [ ] Commit `docs: document Country 1 identity ownership`.

## Risks and controls

1. **Real title budget:** Task 1 nominal fit gate; `Kingshield Keep` replaces overflowing `Kingshield Bastion` before downstream hard-coding.
2. **Flavor blocks Attack:** one non-blocking transient kind + pure non-Attack frame + preserved entry/hit target + tap-before-expiry test.
3. **Final-country drift:** report title from `BattleResult.cityKey`; Battle and map tests lock separate city/country semantics.
4. **Stale exact strings:** update known consumers atomically; repository search is final backstop.
5. **Transient fit:** enumerate all authored strings as cheap regression coverage.

## Final scope check

15 authored rows; zero new production files, persistence changes, gameplay systems, scenes/modals, or durable state. Allowed minimal interaction additions: one pure Scout layout frame and one `.flavor` transient kind.

If implementation introduces a reusable content platform, generic campaign abstraction, persistence migration, second text-layout policy, or milestone effect, reduce scope back to this plan.