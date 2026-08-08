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
- Flavor must ship; do not drop `flavorText` merely to avoid interaction work.
- Flavor must not disable Attack. Existing locked/completed/error feedback remains blocking exactly as today.
- Existing fitting behavior is authoritative. Fix authored copy instead of adding a second wrapping/truncation policy.
- Unit tests use Swift Testing. Always run simulator tests with `-parallel-testing-enabled NO`.

## Known call-site inventory

Production consumers:

- `Pyxis/CityDefinition.swift`
- `Pyxis/Country1CityCatalog.swift`
- `Pyxis/KingdomGameState.swift`
- `Pyxis/CountryMapScoutCardContent.swift`
- `Pyxis/CountryMapScoutCardLayout.swift`
- `Pyxis/CountryMapScoutCardNode.swift`
- `Pyxis/CountryMapTransientFeedback.swift`
- `Pyxis/CountryMapScene.swift`
- `Pyxis/ConquestReportContent.swift`
- `Pyxis/BattleScene.swift`
- `Pyxis/BuildingViewScene.swift` (existing shared-title consumer; production change should not be needed)

Known test surfaces:

- `PyxisTests/Country1CityCatalogTests.swift`
- `PyxisTests/KingdomGameStateTests.swift`
- `PyxisTests/CountryMapScoutCardContentTests.swift`
- `PyxisTests/CountryMapScoutCardLayoutTests.swift`
- `PyxisTests/CountryMapScoutCardNodeTests.swift`
- `PyxisTests/CountryMapScoutCardTextLayoutTests.swift`
- `PyxisTests/CountryMapScoutCardAcceptanceTests.swift`
- `PyxisTests/CountryMapTransientFeedbackTests.swift`
- `PyxisTests/CountryMapSceneTests.swift`
- `PyxisTests/ConquestReportContentTests.swift`
- `PyxisTests/ConquestReportNodeTests.swift`
- `PyxisTests/BattleSceneTests.swift`
- `PyxisTests/BuildingViewSceneTests.swift`

---

### Task 1: Author the catalog and prove the real title budget immediately

**Files:**
- Modify: `Pyxis/CityDefinition.swift`
- Modify: `Pyxis/Country1CityCatalog.swift`
- Modify: `PyxisTests/Country1CityCatalogTests.swift`
- Modify: `PyxisTests/CountryMapScoutCardTextLayoutTests.swift`

**Interfaces:**
- Produces: `CityDefinition.name: String`
- Produces: `CityDefinition.flavorText: String`
- Produces: `CityDefinition.conquestTitle: String`
- Produces: `CityDefinition.displayTitle: String`
- Produces: `Country1CityCatalog.definitionIfPresent(for:) -> CityDefinition?`
- Preserves: clamped `Country1CityCatalog.definition(for:)`

- [ ] **Step 1: Write the failing authored-identity fixture**

Extend the independent `ExpectedDefinition` fixture in `Country1CityCatalogTests.swift` with `name`, `flavorText`, and `conquestTitle` while retaining the existing independent trait/lane values.

Use exactly:

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

Add/retain assertions for completeness, trimmed non-empty copy, case-insensitive name uniqueness, the coarse character bounds, `displayTitle`, the exact reviewed trait/lane metadata, and a non-clamping `definitionIfPresent(for:)` lookup.

- [ ] **Step 2: Move the nominal Scout-title gate onto `CityDefinition.displayTitle`**

In `CountryMapScoutCardTextLayoutTests.everyTitleAndRewardFitsAtItsNominalSizeInEverySupportedLayout`, replace the old state-formatted title source with:

```swift
for definition in Country1CityCatalog.definitions {
    let cityNumber = definition.cityNumber
    let title = definition.displayTitle
```

Keep the existing assertion that the fitted size equals the nominal 11 pt phone / 16 pt pad title size. Do not lower the size or add a new matrix.

This is the authoring gate that would have rejected `City 11 · Kingshield Bastion`; it must run in Task 1.

- [ ] **Step 3: Run RED**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/Country1CityCatalogTests \
  -only-testing:PyxisTests/CountryMapScoutCardTextLayoutTests
```

Expected: compile/test failure because identity fields and `definitionIfPresent(for:)` do not exist yet.

- [ ] **Step 4: Implement only the catalog extension**

Add the three identity fields and computed `displayTitle` to `CityDefinition`, install the exact table from Step 1, and add:

```swift
static func definitionIfPresent(for cityNumber: Int) -> CityDefinition? {
    guard cityRange.contains(cityNumber) else { return nil }
    return definitions[cityNumber - cityRange.lowerBound]
}
```

Do not change the clamped `definition(for:)` implementation.

- [ ] **Step 5: Run GREEN and commit**

Run the Task 1 test command again. Expected: both suites PASS, including the nominal narrow-iPad title fit.

```bash
git add Pyxis/CityDefinition.swift Pyxis/Country1CityCatalog.swift \
  PyxisTests/Country1CityCatalogTests.swift \
  PyxisTests/CountryMapScoutCardTextLayoutTests.swift
git commit -m "feat: author Country 1 city identities"
```

---

### Task 2: Atomically move shared titles, Scout flavor data, and report ownership

This task changes the shared title producer and all known exact-string consumers together so it ends green rather than deferring a wall of stale tests.

**Files:**
- Modify: `Pyxis/KingdomGameState.swift`
- Modify: `Pyxis/CountryMapScoutCardContent.swift`
- Modify: `Pyxis/ConquestReportContent.swift`
- Modify: `Pyxis/BattleScene.swift`
- Verify only: `Pyxis/BuildingViewScene.swift` already consumes `state.displayCityTitle`
- Modify: `PyxisTests/KingdomGameStateTests.swift`
- Modify: `PyxisTests/CountryMapScoutCardContentTests.swift`
- Modify: `PyxisTests/CountryMapScoutCardNodeTests.swift`
- Modify: `PyxisTests/ConquestReportContentTests.swift`
- Modify: `PyxisTests/ConquestReportNodeTests.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`
- Modify: `PyxisTests/BuildingViewSceneTests.swift`

**Interfaces:**
- Produces: `KingdomGameState.displayCityTitle(for:)`
- Produces: static `KingdomGameState.displayConquestTitle(for cityKey: CityKey)` whose output depends only on the supplied record key
- Produces: `CountryMapScoutCardContent.Scout.flavorText`
- Changes: `ConquestReportContent.project(from:title:)`
- Preserves temporarily: `.countryComplete(countryNumber:)`; Task 3 moves final name into the pure projection

- [ ] **Step 1: Write/update shared-title and result-key tests**

Add representative expectations for `City 6 · Granite Pass`, `City 15 · Crownspire Keep`, legacy invalid-city/country fallback, `CityKey(countryNumber: 1, cityNumber: 15) -> Crownspire Keep Falls`, and `CityKey(countryNumber: 2, cityNumber: 3) -> Country 2 - City 3 Conquered`.

Update normal Scout projections to carry `definition.displayTitle` and `definition.flavorText`. Update direct Scout initializers in node tests with a flavor value so the test target compiles.

- [ ] **Step 2: Update known exact-string consumers before production changes**

Update Battle HUD/tooltip expectations to authored display titles and the Building View foreground/building-conquest expectation to `Buildings conquered City 1 · Willowford.`. Do not change unrelated copy such as `unlocks at City N`.

- [ ] **Step 3: Move report title ownership to the caller and lock both final-country paths**

Change every `ConquestReportContent.project` call from `cityTitle:` / `isCountryComplete:` to `title:`. Change the report node sample to `Falconridge Silenced`. Update City 3 report expectation to `Falconridge Silenced` and both existing country-complete Battle report assertions to `Crownspire Keep Falls`.

- [ ] **Step 4: Run RED across the complete Task 2 blast radius**

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

- [ ] **Step 5: Implement shared display helpers**

Keep `displayCityTitle(for:)` state-aware for current UI. Add static result formatting:

```swift
static func displayConquestTitle(for cityKey: CityKey) -> String {
    guard cityKey.countryNumber == 1,
          let definition = Country1CityCatalog.definitionIfPresent(for: cityKey.cityNumber) else {
        return "Country \(cityKey.countryNumber) - City \(cityKey.cityNumber) Conquered"
    }
    return definition.conquestTitle
}
```

This helper reads no ambient campaign state.

- [ ] **Step 6: Add Scout flavor data and simplify report projection**

`Scout` gains `flavorText`; normal projection reads it from the definition. Change report projection to `project(from:title:)`, remove only the old title branch, and have BattleScene pass `KingdomGameState.displayConquestTitle(for: result.cityKey)`. Do not modify `BattleResult` or report lifecycle behavior.

- [ ] **Step 7: Search stale report signatures/copy, run GREEN, and commit**

Use `rg` to reject old report signature/title assertions, rerun the Task 2 test set, then commit this atomic shared-projection slice.

---

### Task 3: Ship Country Map identity with non-blocking flavor

**Files:**
- Modify: `Pyxis/CountryMapScoutCardContent.swift`
- Modify: `Pyxis/CountryMapScoutCardLayout.swift`
- Modify: `Pyxis/CountryMapScoutCardNode.swift`
- Modify: `Pyxis/CountryMapTransientFeedback.swift`
- Modify: `Pyxis/CountryMapScene.swift`
- Modify: `PyxisTests/CountryMapScoutCardContentTests.swift`
- Modify: `PyxisTests/CountryMapScoutCardLayoutTests.swift`
- Modify: `PyxisTests/CountryMapScoutCardNodeTests.swift`
- Modify: `PyxisTests/CountryMapTransientFeedbackTests.swift`
- Modify: `PyxisTests/CountryMapSceneTests.swift`
- Modify: `PyxisTests/CountryMapScoutCardAcceptanceTests.swift`

**Interfaces:**
- Changes: `CountryMapScoutCardContent.countryComplete(countryNumber:finalCityName:)`
- Produces: `CountryMapScoutCardLayout.nonBlockingOverlayFrame`
- Produces: `CountryMapTransientFeedback.flavor(_:)`
- Produces: `CountryMapTransientFeedback.blocksScoutEntry`
- Changes: `CountryMapScoutCardNode.applyFeedback(..., blocksAttack:)`
- Preserves: existing full-card blocking overlay behavior for locked/completed/status/error feedback

- [ ] **Step 1: Put final-country identity in the pure content projection**

Change the enum case to `countryComplete(countryNumber:finalCityName:)`; `project(from:)` resolves the final name from constant catalog City 15. Update pure content tests. The SpriteKit node must not read the catalog.

- [ ] **Step 2: Add pure non-blocking overlay geometry**

Add `nonBlockingOverlayFrame`. Keep existing `overlayFrame` unchanged. Build the new frame from the card's left edge through the existing informational/Attack gap (`6` phone, `12` pad). Assert containment, positive width, and no intersection with `attackFrame` for every supported fixture.

- [ ] **Step 3: Add a dedicated flavor feedback kind**

Add `.flavor`, `blocksScoutEntry` (`false` only for flavor), and `flavor(_:)` using current 2.5s status timing. Keep current blocking kinds/durations unchanged.

- [ ] **Step 4: Write node + scene tests for Attack during flavor**

Node test: non-blocking feedback uses `nonBlockingOverlayFrame` and preserves `attackHitFrame`; blocking feedback uses full `overlayFrame` and clears Attack.

Scene test: use pending City 5 -> unlocked City 6, tap body to show `Stone walls seal the mountain road ahead.`, assert no mutation/route/gameplay feedback and non-nil Attack frame, then tap Attack before flavor expires and assert one route plus City 6 `.battleActive` persisted state.

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

- [ ] **Step 6: Implement non-blocking flavor through all three current blockers**

`CountryMapScoutCardNode.applyFeedback` accepts `blocksAttack: Bool = true` and chooses full `overlayFrame` vs `nonBlockingOverlayFrame`. Blocking mode keeps current Attack clearing. Non-blocking mode preserves the current Attack frame even while feedback is visible.

`CountryMapScene.redraw()` uses `transientFeedback?.blocksScoutEntry` rather than `transientFeedback == nil` so flavor does not disable entry. `applyFeedbackPresentation()` passes the same blocking flag. Scout body calls `showFeedback(.flavor(scout.flavorText))`.

Input priority remains overlay -> Attack -> Scout body. The blocking overlay still covers Attack; the flavor overlay does not intersect it.

- [ ] **Step 7: Render final-country and named feedback from pure projections**

Node renders the supplied final city name. Locked/completed feedback accepts `cityTitle:`. Idle final-country copy reads constant City 15 in pure/non-SpriteKit code. Update acceptance exact strings and enum equality checks.

- [ ] **Step 8: Run GREEN and commit**

Rerun the Task 3 suites, then commit the listed Country Map production/tests together.

---

### Task 4: Run authored fit acceptance and stale-copy checks

- [ ] Extend the existing feedback-fit family to enumerate all 15 flavors in non-blocking mode and all 15 named locked/completed strings plus final/error strings in blocking mode. Verify label containment/current floor, flavor/Attack non-intersection, and preserved Attack frame.
- [ ] Update existing `allCurrentContentPresentsAcrossEveryFixtureAndImageOutcome` to carry `definition.displayTitle` + `definition.flavorText`; do not add another matrix.
- [ ] Re-run `CountryMapScoutCardTextLayoutTests`, `CountryMapScoutCardNodeTests`, and `CountryMapScoutCardAcceptanceTests`. All titles remain nominal 11/16 pt.
- [ ] Run repository-wide stale-copy `rg` searches; keep only intentional fallback/unrelated copy.
- [ ] Commit acceptance amendments as `test: validate Country 1 identity fit`.

---

### Task 5: Document ownership, run full verification, and smoke the campaign

- [ ] Update `CLAUDE.md`: catalog owns identity, identity is not persisted, report copy resolves from `BattleResult.cityKey`, Scout flavor is non-blocking for Attack.
- [ ] Run full `xcodebuild test` with `-parallel-testing-enabled NO`.
- [ ] Run `swiftlint lint --no-cache` and `git diff --check origin/main...HEAD`.
- [ ] Seed/play City 1→15 verifying Scout title/flavor, immediate Attack during flavor, Battle HUD/tooltip, Building View conquest copy, authored report titles, named map feedback, and City 15 report -> country-map completion. No gameplay/reward/lane/routing/SFX/haptic change.
- [ ] Commit `CLAUDE.md` as `docs: document Country 1 identity ownership`.

---

## Risks and controls

### 1. Authored title exceeds the real layout budget

Control: nominal production title-fit runs in Task 1 against `CityDefinition.displayTitle`. `Kingshield Keep` replaces `Kingshield Bastion` before downstream hard-coding.

### 2. Flavor blocks the primary Attack action

Control: flavor is the sole non-blocking transient kind; layout provides a pure non-Attack overlay frame; scene entry remains enabled; node preserves the Attack hit frame; a scene test taps Attack before flavor expires.

### 3. Final-country semantics drift

Control: report title resolves from `BattleResult.cityKey`; both existing final-country Battle tests require `Crownspire Keep Falls`, while map tests require separate country confirmation.

### 4. Stale exact-string test copy

Control: Task 2 updates Battle/Building/report blast radius atomically; Task 3 updates Country Map blast radius atomically; Task 4 search is the final backstop.

### 5. Transient-copy fit regression

Control: enumerate all authored flavor/locked/completed/final strings through existing fit helpers. This is inexpensive regression coverage, not the primary layout risk.

## Final scope check

- Authored identity rows: exactly 15.
- New production files: 0.
- Persistence schema changes: 0.
- New gameplay systems/mechanics: 0.
- New scenes/modals: 0.
- New durable state: 0.
- One pure Scout layout frame and one `.flavor` transient kind are allowed because they are the minimum required to ship required flavor text without blocking Attack.

If implementation starts introducing a reusable content platform, generic campaign abstraction, persistence migration, second text-layout policy, or milestone effect, stop and reduce scope back to this plan.