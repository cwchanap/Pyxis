# HPA-366 Country 1 City Identity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the reviewed 15-city Country 1 identity set through the current map, battle, building, and conquest surfaces without changing gameplay, persistence, or adding a content framework.

**Architecture:** Extend `CityDefinition` / `Country1CityCatalog` with three authored strings. Keep gameplay lookup clamping unchanged. Current UI titles reuse state display seams; conquest reports resolve from `BattleResult.cityKey`. Flavor ships through the existing Scout Card transient layer in one non-blocking mode that leaves Attack immediately available.

**Tech Stack:** Swift 5, SpriteKit, UIKit, CoreGraphics, Swift Testing, Xcode/iOS Simulator.

## Global Constraints

- Exactly 15 Country 1 identity rows.
- `name` <= 18 chars as a coarse bound; `flavorText` <= 48; `conquestTitle` <= 24; all non-empty; names unique case-insensitively.
- Rendered title fit is authoritative. Narrowest current pad title frame is 198 pt at nominal 16 pt AvenirNext-DemiBold; phone nominal is 11 pt.
- City 11 = `Kingshield Keep`.
- Preserve current trait/lane/HP/reward/unlock/building/idle/routing/combat/SFX/haptic semantics.
- No persistence schema, content service, registry, multi-country abstraction, localization layer, theme metadata, scene, or HPA-390 milestone effect.
- New production files: 0; no `project.pbxproj` edits.
- City 15 Battle report = `Crownspire Keep Falls`; overall country completion is Country Map-only after Continue.
- Country-complete name always comes from catalog City 15.
- Flavor is required and must not disable Attack. Existing invalid/locked/completed/error feedback remains blocking.
- Existing fit behavior is authoritative; shorten copy instead of adding another layout policy.
- Simulator tests run with `-parallel-testing-enabled NO`.

## Task 1 — Catalog + real title gate

**Files:** `CityDefinition.swift`, `Country1CityCatalog.swift`, `Country1CityCatalogTests.swift`, `CountryMapScoutCardTextLayoutTests.swift`.

- [ ] Author the exact reviewed table:

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

- [ ] Add completeness/uniqueness/coarse-length/display-title assertions, preserve exact combat metadata/clamping tests, add non-clamping `definitionIfPresent(for:)` test.
- [ ] Change existing nominal Scout title test to read `definition.displayTitle` directly, not `KingdomGameState().displayCityTitle(for:)`. Keep nominal 11/16 pt assertion; this gate would reject `Kingshield Bastion`.
- [ ] Run catalog + text-layout RED tests.
- [ ] Implement `name`, `flavorText`, `conquestTitle`, `displayTitle`, exact table, and `definitionIfPresent(for:)`; keep clamped gameplay lookup unchanged.
- [ ] Run GREEN; commit `feat: author Country 1 city identities`.

## Task 2 — Shared title/report atom

**Files:** `KingdomGameState.swift`, `CountryMapScoutCardContent.swift`, `ConquestReportContent.swift`, `BattleScene.swift`; verify Building View production already consumes shared title; update state/Scout/node/report/Battle/Building tests.

- [ ] Add authored current-title/fallback tests and result-key tests (`CityKey(1,15) -> Crownspire Keep Falls`; `CityKey(2,3) -> Country 2 - City 3 Conquered`).
- [ ] Add `Scout.flavorText` to expected/direct Scout construction.
- [ ] Update Battle HUD/tooltip, Building View conquest copy, report node sample, City 3 report, and both final-country Battle report assertions before production change.
- [ ] Run complete Task 2 RED suites.
- [ ] Keep current UI `displayCityTitle(for:)` state-aware. Add static `displayConquestTitle(for cityKey:)` using both supplied key components and no ambient state.
- [ ] Change `ConquestReportContent.project` to `project(from:title:)`; BattleScene passes `KingdomGameState.displayConquestTitle(for: result.cityKey)`; remove only old title branch; do not modify `BattleResult` or report lifecycle.
- [ ] Reject stale report signatures/strings, run GREEN, commit `feat: project shared city identity`.

## Task 3 — Country Map + non-blocking flavor

**Files:** Scout content/layout/node, transient feedback, CountryMapScene, and content/layout/node/transient/scene/acceptance tests.

- [ ] Pure country-complete payload becomes `countryComplete(countryNumber:finalCityName:)`; final name resolves from catalog City 15. Node only renders supplied value.
- [ ] Add pure `nonBlockingOverlayFrame` spanning informational area through existing Attack gap (6 pt phone / 12 pt pad), keeping full `overlayFrame` unchanged. Assert no Attack intersection across fixtures.
- [ ] Add `.flavor`, `blocksScoutEntry` (`false` only for flavor), and `flavor(_:)` using current 2.5s timing; current feedback stays blocking.
- [ ] Node regression: non-blocking flavor uses new frame and preserves `attackHitFrame`; blocking feedback uses full frame and clears Attack.
- [ ] Scene regression: pending City 5 -> unlocked City 6; body tap shows City 6 flavor with no mutation/route/gameplay feedback; before expiry tap Attack and assert one route plus City 6 `.battleActive` persistence.
- [ ] Run Country Map RED suites.
- [ ] Implement all three current Attack blockers: node blocking flag/frame; scene entry uses `blocksScoutEntry` rather than any-transient; presentation forwards same flag. Body tap calls `.flavor(scout.flavorText)`. Input priority remains overlay -> Attack -> Scout body; flavor overlay excludes Attack.
- [ ] Integrate named locked/completed/idle/final-country copy, update acceptance exact strings, run GREEN, commit `feat: show nonblocking city flavor`.

## Task 4 — Fit acceptance + stale-copy checks

- [ ] Existing feedback-fit test enumerates all 15 flavors in non-blocking mode and all named locked/completed + final/error copy in blocking mode; verify fit, no flavor/Attack overlap, preserved Attack frame.
- [ ] Existing all-content matrix carries authored title + flavor; no duplicate matrix.
- [ ] Re-run nominal title, node, and acceptance suites; all titles remain nominal 11/16 pt.
- [ ] Run stale-copy searches; production names remain centralized in catalog.
- [ ] Commit `test: validate Country 1 identity fit`.

## Task 5 — Docs + full verification + campaign smoke

- [ ] Update `CLAUDE.md`: catalog owns identity; identity not persisted; reports resolve from `BattleResult.cityKey`; flavor never disables Attack.
- [ ] Full tests with parallel disabled; SwiftLint; `git diff --check`.
- [ ] Seed/play City 1→15 verifying Scout title/flavor, immediate Attack during flavor, Battle HUD/tooltip, Building View copy, authored report title, named map feedback, City 15 report -> map completion, and unchanged gameplay/reward/lane/routing/SFX/haptics.
- [ ] Commit `docs: document Country 1 identity ownership`.

## Risks

1. Real title budget: Task 1 nominal fit gate; `Kingshield Keep` replaces overflow before downstream hard-coding.
2. Flavor blocks Attack: one non-blocking transient kind + pure non-Attack frame + preserved entry/hit target + tap-before-expiry test.
3. Final-country drift: report title from `BattleResult.cityKey`; Battle/map tests lock separate city/country semantics.
4. Stale exact strings: update known consumers atomically; repository search is final backstop.
5. Transient fit: enumerate all authored strings as cheap regression coverage.

## Final scope

15 authored rows; zero new production files, persistence changes, gameplay systems, scenes/modals, or durable state. Allowed minimal additions: one pure Scout layout frame and one `.flavor` transient kind.