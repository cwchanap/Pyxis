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
- Modify: `PyxisTests/CountryMapScoutCardNodeTests.swift` (direct `Scout` initializers gain `flavorText`)
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

Add representative expectations:

```swift
let state = KingdomGameState(cityNumberInCountry: 6, completedCityCount: 5)
#expect(state.displayCityTitle == "City 6 · Granite Pass")
#expect(state.displayCityTitle(for: 15) == "City 15 · Crownspire Keep")
#expect(state.displayCityTitle(for: 99) == "Country 1 - City 99")

#expect(
    KingdomGameState.displayConquestTitle(
        for: CityKey(countryNumber: 1, cityNumber: 15)
    ) == "Crownspire Keep Falls"
)
#expect(
    KingdomGameState.displayConquestTitle(
        for: CityKey(countryNumber: 2, cityNumber: 3)
    ) == "Country 2 - City 3 Conquered"
)
```

Update normal Scout projections to carry `definition.displayTitle` and `definition.flavorText`. Update every direct `Scout(...)` initializer in node tests with a flavor value so the test target compiles.

- [ ] **Step 2: Update known exact-string consumers before production changes**

Update Battle HUD/tooltip expectations to authored display titles and update the Building View foreground/building-conquest expectation to:

```swift
#expect(scene.feedbackTextForTesting == "Buildings conquered City 1 · Willowford.")
```

Do not change unrelated copy such as `unlocks at City N`.

- [ ] **Step 3: Move report title ownership to the caller and lock both final-country paths**

Change every `ConquestReportContent.project` call from `cityTitle:` / `isCountryComplete:` to `title:`. Change the report node sample to `Falconridge Silenced`. In `BattleSceneTests`, update City 3 report expectation to `Falconridge Silenced` and update both `countryCompleteIsAnInertReportHost` and `countryCompleteContinueRoutesToFinalMapOnce` to `Crownspire Keep Falls`.

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

Expected: failures on old title formatting, old Scout payload, and old report signature.

- [ ] **Step 5: Implement shared display helpers**

Keep current UI title formatting state-aware:

```swift
func displayCityTitle(for cityNumber: Int) -> String {
    guard countryNumber == 1,
          let definition = Country1CityCatalog.definitionIfPresent(for: cityNumber) else {
        return "Country \(countryNumber) - City \(cityNumber)"
    }
    return definition.displayTitle
}
```

Add result-record formatting that uses both values from `CityKey` and reads no ambient state:

```swift
static func displayConquestTitle(for cityKey: CityKey) -> String {
    guard cityKey.countryNumber == 1,
          let definition = Country1CityCatalog.definitionIfPresent(for: cityKey.cityNumber) else {
        return "Country \(cityKey.countryNumber) - City \(cityKey.cityNumber) Conquered"
    }
    return definition.conquestTitle
}
```

Do not change persistence normalization or gameplay catalog accessors.

- [ ] **Step 6: Add Scout flavor data and simplify report projection**

`CountryMapScoutCardContent.Scout` gains `flavorText`. Normal projection reads it from the definition. Leave country-complete payload unchanged until Task 3.

Change `ConquestReportContent.project` to:

```swift
static func project(
    from result: BattleResult,
    title: String
) -> Self
```

Remove only the old title-format branch. `BattleScene.conquestReportContent(for:)` passes:

```swift
title: KingdomGameState.displayConquestTitle(for: result.cityKey)
```

Do not modify `BattleResult`, report restoration/origin, Continue ordering, gold burst anchoring, sound/haptics, or routing.

- [ ] **Step 7: Search the Task 2 scope for stale report signatures/copy**

```bash
rg 'cityTitle:|isCountryComplete:|Country 1 Conquered|Country 1 - City [0-9]+ Conquered' \
  Pyxis/ConquestReportContent.swift Pyxis/BattleScene.swift \
  PyxisTests/ConquestReportContentTests.swift PyxisTests/BattleSceneTests.swift
```

Expected: no stale report signature or old report-title assertion.

- [ ] **Step 8: Run GREEN and commit**

Run the Task 2 test command again, then commit the production and listed test files as one atomic shared-projection slice.

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

Change the enum case to:

```swift
case countryComplete(countryNumber: Int, finalCityName: String)
```

`project(from:)` resolves `finalCityName` from `Country1CityCatalog.cityRange.upperBound`. Update content tests to expect `.countryComplete(countryNumber: 1, finalCityName: "Crownspire Keep")`. No catalog read belongs in `CountryMapScoutCardNode`.

- [ ] **Step 2: Add pure non-blocking overlay geometry**

Add:

```swift
let nonBlockingOverlayFrame: CGRect
```

Keep existing `overlayFrame` unchanged as the full blocking frame. For phone, build the new frame from `informationRegionFrame.minX` through the existing `informationalMaxX = attackFrame.minX - 6`; for pad use the existing 12 pt gap. Assert on every supported fixture that the new frame is contained in the card, positive-width, and does not intersect `attackFrame`.

- [ ] **Step 3: Add a dedicated flavor feedback kind without another controller**

Extend `CountryMapTransientFeedback.Kind` with `.flavor`, add `blocksScoutEntry` (`false` only for `.flavor`), and add `flavor(_:)` with the current 2.5 s status timing. Existing kinds/durations remain unchanged.

- [ ] **Step 4: Write the node test that catches the real Attack regression**

With an enabled Scout:

```swift
node.applyFeedback(
    text: "Stone walls seal the mountain road ahead.",
    alpha: 1,
    blocksAttack: false
)
#expect(node.overlayHitFrame == layout.nonBlockingOverlayFrame)
#expect(node.attackHitFrame == layout.attackFrame)
#expect(!node.overlayHitFrame!.intersects(layout.attackFrame))
```

Then prove ordinary blocking feedback still uses `layout.overlayFrame` and clears `attackHitFrame`.

- [ ] **Step 5: Write the scene test that taps Attack while flavor is still visible**

Use a pending-map state whose unlocked target is City 6:

```swift
let initialState = KingdomGameState(
    cityLevel: 5,
    cityRemainingPower: 0,
    cityNumberInCountry: 5,
    completedCityCount: 5,
    stageStatus: .cityConqueredPendingMap
)
```

Tap the Scout body outside Attack. Assert City 6 flavor is visible, state/route/gameplay feedback are unchanged, and the Attack frame remains present. Without advancing the flavor timer, tap Attack and assert one route plus persisted transition to City 6 `.battleActive`.

- [ ] **Step 6: Run RED for Country Map behavior**

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

- [ ] **Step 7: Implement non-blocking flavor in the existing node/scene pipeline**

Change `CountryMapScoutCardNode.applyFeedback` to accept `blocksAttack: Bool = true` and choose either the existing full `overlayFrame` or new `nonBlockingOverlayFrame`. Blocking mode keeps today's `attackHitFrame = nil`. Non-blocking flavor preserves the Attack frame while `currentPresentationIsScout && currentEntryIsEnabled`; do not rely on the existing restore helper unchanged because it refuses restoration while feedback is visible.

`CountryMapScene.applyFeedbackPresentation()` passes `transientFeedback?.blocksScoutEntry ?? true` as the blocking flag. `redraw()` uses `blocksScoutEntry` instead of `transientFeedback == nil` when computing `isEntryEnabled`.

Replace the Scout body no-op with `showFeedback(.flavor(scout.flavorText))`.

Input priority remains overlay → Attack → Scout body → other controls. Blocking overlay still covers Attack; flavor overlay does not intersect it.

- [ ] **Step 8: Render final-country and named feedback from pure projections**

`CountryMapScoutCardNode.prepare` renders `.countryComplete(let countryNumber, let finalCityName)` without reading the catalog. Locked/completed feedback accepts `cityTitle:` and scene call sites pass `state.displayCityTitle(for:)`. Idle final-country copy remains `Country 1 conquered at Crownspire Keep.` using constant catalog City 15 in pure/non-SpriteKit code.

Update `CountryMapScoutCardAcceptanceTests` exact strings and enum equality checks in the same task.

- [ ] **Step 9: Run GREEN and commit**

Run the Task 3 command again, then commit the listed Country Map production/tests together.

---

### Task 4: Run authored fit acceptance and stale-copy checks

**Files:**
- Modify: `PyxisTests/CountryMapScoutCardNodeTests.swift`
- Verify: `PyxisTests/CountryMapScoutCardTextLayoutTests.swift`
- Verify: `PyxisTests/CountryMapScoutCardAcceptanceTests.swift`
- Verify: production/test call-site inventory

- [ ] **Step 1: Expand the existing feedback-fit family to actual authored strings**

Enumerate all 15 `flavorText` values using non-blocking mode and all 15 named locked/completed strings plus final/error strings using blocking mode. Verify label containment/current >=8 pt floor, flavor/Attack non-intersection, and preserved Attack hit frame for flavor.

- [ ] **Step 2: Make the existing all-content matrix carry authored identity**

Update the existing `allCurrentContentPresentsAcrossEveryFixtureAndImageOutcome` Scout construction to use `definition.displayTitle` and `definition.flavorText`. Keep its existing matrix and `.presented` expectation; do not add another all-title matrix.

- [ ] **Step 3: Re-run the stronger nominal title gate and acceptance suites**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/CountryMapScoutCardTextLayoutTests \
  -only-testing:PyxisTests/CountryMapScoutCardNodeTests \
  -only-testing:PyxisTests/CountryMapScoutCardAcceptanceTests
```

Expected: all 15 titles stay at nominal 11/16 pt; all dense card combinations present; every flavor fits the non-blocking frame; blocking copy fits the full overlay.

- [ ] **Step 4: Run repository-wide stale-copy searches**

```bash
rg 'Country 1 - City|Country 1 Conquered|City [0-9]+: (Standard Watch|Arrow Tower|Spiked Gate|Stone Wall|Arcane Ward|Burning Oil|Reinforced Keep)' Pyxis PyxisTests
```

Review each hit and keep only intentional fallback/tests or unrelated copy.

Then verify authored production names are centralized in `Country1CityCatalog.swift` rather than duplicated in scene switches/tables.

- [ ] **Step 5: Commit Task 4**

Commit the acceptance-test amendment separately as `test: validate Country 1 identity fit`.

---

### Task 5: Document ownership, run full verification, and smoke the campaign

**Files:**
- Modify: `CLAUDE.md`
- Verify: all production/test files changed in Tasks 1-4

- [ ] **Step 1: Update architecture guidance**

Document that `Country1CityCatalog` is the sole source of Country 1 `name`/`flavorText`/`conquestTitle`, copy is not persisted, conquest reports resolve from `BattleResult.cityKey`, and Scout flavor must remain non-blocking for Attack.

- [ ] **Step 2: Run the full automated suite**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO
```

- [ ] **Step 3: Run lint and diff checks**

```bash
swiftlint lint --no-cache
git diff --check origin/main...HEAD
```

- [ ] **Step 4: Run the City 1→15 identity smoke**

For every city verify Scout `City N · Name`, flavor body-tap, Attack still immediately available while flavor is visible, Battle HUD/tooltip, Building View conquest copy, authored conquest report, named map feedback, and final City 15 report → country-map handoff. Verify no gameplay, reward, lane, routing, SFX, or haptic change.

- [ ] **Step 5: Commit Task 5**

```bash
git add CLAUDE.md
git commit -m "docs: document Country 1 identity ownership"
```

---

## Risks and controls

### 1. Authored title exceeds the real layout budget

Control: nominal production title-fit runs in Task 1 against `CityDefinition.displayTitle`. `Kingshield Keep` replaces the overflowing `Kingshield Bastion` before downstream tests hard-code it.

### 2. Flavor blocks the primary Attack action

Control: flavor is the sole non-blocking transient kind; layout provides a pure non-Attack overlay frame; scene entry remains enabled; node preserves the Attack hit frame; a scene test taps Attack before flavor expires.

### 3. Final-country semantics drift

Control: report title resolves from `BattleResult.cityKey`; both existing final-country Battle tests require `Crownspire Keep Falls`, while map tests require the separate country confirmation.

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