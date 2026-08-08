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

Add/retain assertions for:

```swift
@Test func authoredIdentityIsCompleteUniqueAndWithinCopyLimits() {
    let definitions = Country1CityCatalog.definitions
    let names = definitions.map {
        $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    #expect(definitions.count == 15)
    #expect(Set(names).count == 15)
    for definition in definitions {
        #expect(!definition.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        #expect(!definition.flavorText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        #expect(!definition.conquestTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        #expect(definition.name.count <= 18)
        #expect(definition.flavorText.count <= 48)
        #expect(definition.conquestTitle.count <= 24)
        #expect(definition.displayTitle == "City \(definition.cityNumber) · \(definition.name)")
    }
}

@Test func optionalDefinitionLookupDoesNotClamp() {
    #expect(Country1CityCatalog.definitionIfPresent(for: 0) == nil)
    #expect(Country1CityCatalog.definitionIfPresent(for: 1) == Self.expectedDefinitions[0].definition)
    #expect(Country1CityCatalog.definitionIfPresent(for: 15) == Self.expectedDefinitions[14].definition)
    #expect(Country1CityCatalog.definitionIfPresent(for: 16) == nil)
}
```

Keep the existing exact combat-metadata and clamping tests.

- [ ] **Step 2: Move the nominal Scout-title gate onto `CityDefinition.displayTitle`**

In `CountryMapScoutCardTextLayoutTests.everyTitleAndRewardFitsAtItsNominalSizeInEverySupportedLayout`, replace the old state-formatted title source:

```swift
for cityNumber in Country1CityCatalog.cityRange {
    let title = KingdomGameState().displayCityTitle(for: cityNumber)
```

with the authored source directly:

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

`CityDefinition` becomes:

```swift
struct CityDefinition: Equatable {
    let cityNumber: Int
    let name: String
    let flavorText: String
    let conquestTitle: String
    let defenseTrait: CityDefenseTrait
    let laneDefenseProfile: LaneDefenseProfile

    var displayTitle: String {
        "City \(cityNumber) · \(name)"
    }
}
```

Install the exact table from Step 1 and add:

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
- Produces: `KingdomGameState.displayConquestTitle(for cityKey: CityKey)` as a static result-key formatter
- Produces: `CountryMapScoutCardContent.Scout.flavorText`
- Changes: `ConquestReportContent.project(from:title:)`
- Preserves temporarily: `.countryComplete(countryNumber:)`; Task 3 moves final name into the pure projection

- [ ] **Step 1: Write/update shared-title and result-key tests**

Add:

```swift
@Test func countryOneIdentityUsesCatalogAndUnsupportedDisplayValuesKeepLegacyFallback() {
    let state = KingdomGameState(cityNumberInCountry: 6, completedCityCount: 5)
    #expect(state.displayCityTitle == "City 6 · Granite Pass")
    #expect(state.displayCityTitle(for: 15) == "City 15 · Crownspire Keep")
    #expect(state.displayCityTitle(for: 99) == "Country 1 - City 99")

    let unsupportedCountry = KingdomGameState(countryNumber: 2)
    #expect(unsupportedCountry.displayCityTitle(for: 1) == "Country 2 - City 1")
}

@Test func conquestTitleUsesTheBattleResultCityKeyRatherThanAmbientState() {
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
}
```

Update Scout projections to include:

```swift
displayTitle: definition.displayTitle,
flavorText: definition.flavorText,
```

Update every direct `CountryMapScoutCardContent.Scout(...)` in `CountryMapScoutCardNodeTests` with a flavor value so the test target compiles when the payload changes.

- [ ] **Step 2: Update known exact-string consumers before production changes**

`BattleSceneTests.swift`:

```swift
#expect(scene.cityTitleTextForTesting == "City 3 · Falconridge")
```

Update City 1 visible HUD/tooltip expectations from `Country 1 - City 1` to `City 1 · Willowford`.

`BuildingViewSceneTests.swift`:

```swift
#expect(scene.feedbackTextForTesting == "Buildings conquered City 1 · Willowford.")
```

Do not change unrelated copy such as `unlocks at City N`.

- [ ] **Step 3: Move report title ownership to the caller and lock both final-country paths**

Change every pure report call from `cityTitle:` / `isCountryComplete:` to `title:`.

```swift
@Test func reportUsesCallerProvidedTitleWithoutCampaignFormatting() {
    let content = ConquestReportContent.project(
        from: makeResult(city: 15),
        title: "Crownspire Keep Falls"
    )
    #expect(content.title == "Crownspire Keep Falls")
}
```

Change `ConquestReportNodeTests.fullContent()` sample title to `Falconridge Silenced`.

In `BattleSceneTests`, update City 3 report expectation to `Falconridge Silenced` and update **both** existing final-country assertions (`countryCompleteIsAnInertReportHost` and `countryCompleteContinueRoutesToFinalMapOnce`) to:

```swift
#expect(scene.conquestReportTitleForTesting == "Crownspire Keep Falls")
```

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

Keep current-title display state-aware:

```swift
func displayCityTitle(for cityNumber: Int) -> String {
    guard countryNumber == 1,
          let definition = Country1CityCatalog.definitionIfPresent(for: cityNumber) else {
        return "Country \(countryNumber) - City \(cityNumber)"
    }
    return definition.displayTitle
}
```

Add a result-record helper that does **not** read ambient `countryNumber`:

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

`CountryMapScoutCardContent.Scout` gains:

```swift
let flavorText: String
```

Normal Scout projection sets it from `definition.flavorText`. Leave country-complete payload unchanged until Task 3.

Change `ConquestReportContent.project` to:

```swift
static func project(
    from result: BattleResult,
    title: String
) -> Self
```

Remove only the title-format branch; keep all row/achievement logic unchanged.

`BattleScene.conquestReportContent(for:)` becomes:

```swift
private func conquestReportContent(for result: BattleResult) -> ConquestReportContent {
    .project(
        from: result,
        title: KingdomGameState.displayConquestTitle(for: result.cityKey)
    )
}
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

Run the Task 2 test command again.

```bash
git add Pyxis/KingdomGameState.swift Pyxis/CountryMapScoutCardContent.swift \
  Pyxis/ConquestReportContent.swift Pyxis/BattleScene.swift \
  PyxisTests/KingdomGameStateTests.swift PyxisTests/CountryMapScoutCardContentTests.swift \
  PyxisTests/CountryMapScoutCardNodeTests.swift PyxisTests/ConquestReportContentTests.swift \
  PyxisTests/ConquestReportNodeTests.swift PyxisTests/BattleSceneTests.swift \
  PyxisTests/BuildingViewSceneTests.swift
git commit -m "feat: project shared city identity"
```

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

- [ ] **Step 1: Put final-country identity back in the pure content projection**

Change the enum case to:

```swift
case countryComplete(countryNumber: Int, finalCityName: String)
```

In `project(from:)`:

```swift
guard state.stageStatus != .countryComplete else {
    let finalCity = Country1CityCatalog.definition(
        for: Country1CityCatalog.cityRange.upperBound
    )
    return .countryComplete(
        countryNumber: state.countryNumber,
        finalCityName: finalCity.name
    )
}
```

Use the same pure projection fallback if the incomplete-map invariant fails.

Update content tests to expect:

```swift
.countryComplete(countryNumber: 1, finalCityName: "Crownspire Keep")
```

This is intentional enum churn: it keeps catalog lookup out of SpriteKit rendering.

- [ ] **Step 2: Add pure non-blocking overlay geometry**

Add to `CountryMapScoutCardLayout`:

```swift
let nonBlockingOverlayFrame: CGRect
```

Keep the existing `overlayFrame` unchanged as the full-card blocking overlay.

For phone, reuse the already-computed `informationalMaxX = attackFrame.minX - 6`:

```swift
let nonBlockingOverlayFrame = CGRect(
    x: informationRegionFrame.minX,
    y: informationRegionFrame.minY,
    width: informationalMaxX - informationRegionFrame.minX,
    height: informationRegionFrame.height
)
```

For pad, use its existing 12 pt information-to-Attack gap (`informationalMaxX = attackFrame.minX - 12`) with the same formula.

Add layout assertions for every supported fixture:

```swift
#expect(layout.cardFrame.contains(layout.nonBlockingOverlayFrame))
#expect(!layout.nonBlockingOverlayFrame.intersects(layout.attackFrame))
#expect(layout.nonBlockingOverlayFrame.width > 0)
```

Do not shrink the existing blocking overlay.

- [ ] **Step 3: Add a dedicated flavor feedback kind without another controller**

Extend `CountryMapTransientFeedback.Kind`:

```swift
case flavor
```

Add:

```swift
var blocksScoutEntry: Bool {
    kind != .flavor
}

static func flavor(_ text: String) -> Self {
    .init(
        kind: .flavor,
        text: text,
        totalDuration: 2.5,
        fadeDuration: 0.3
    )
}
```

Keep existing `.status`, locked/completed/error durations and semantics unchanged.

Add pure tests proving `.flavor` is the only non-blocking kind.

- [ ] **Step 4: Write the node test that catches the real Attack regression**

Start with an enabled Scout Card and show feedback using non-blocking mode. Assert:

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

Then show ordinary blocking feedback:

```swift
node.applyFeedback(text: "City 7 · Emberford is locked", alpha: 1, blocksAttack: true)
#expect(node.overlayHitFrame == layout.overlayFrame)
#expect(node.attackHitFrame == nil)
```

This preserves current invalid-feedback behavior while proving flavor is different.

- [ ] **Step 5: Write the scene test that taps Attack while flavor is still visible**

Create a City 6 active state, tap a point in the Scout body outside Attack, then assert flavor appears with no mutation/route/SFX-haptic event.

Without advancing the 2.5 s transient timer, fetch the Attack frame and tap it:

```swift
scene.handleTouchForTesting(at: bodyPoint)
#expect(scene.visibleFeedbackTextForTesting == "Stone walls seal the mountain road ahead.")
#expect(scene.scoutCardAttackHitFrameForTesting != nil)
#expect(store.load() == initialState)
#expect(router.battleRequestCount == 0)
#expect(feedback.calls.isEmpty)

let attack = try #require(scene.scoutCardAttackHitFrameForTesting)
scene.handleTouchForTesting(at: attack.center)
#expect(router.battleRequestCount == 1)
```

Also retain existing tests that blocking locked/completed feedback cannot be dismissed early and suppresses underlying targets.

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

Expected: compile/behavior failures because final-country payload, flavor geometry/mode, and named copy do not exist yet.

- [ ] **Step 7: Implement non-blocking flavor in the existing node/scene pipeline**

Change `CountryMapScoutCardNode.applyFeedback` to accept:

```swift
func applyFeedback(
    text: String?,
    alpha: CGFloat,
    blocksAttack: Bool = true
)
```

When text is visible, choose:

```swift
let presentationFrame = blocksAttack
    ? layout.overlayFrame
    : layout.nonBlockingOverlayFrame
```

Use `presentationFrame` for fitting, panel geometry, label position, and `overlayHitFrame`.

For `blocksAttack == true`, keep today's `attackHitFrame = nil`.

For `blocksAttack == false`, preserve the Attack frame when `currentPresentationIsScout && currentEntryIsEnabled`; do not call the current `restoreAttackHitFrame()` path unchanged because it intentionally refuses restoration while `feedbackIsVisible` is true.

Update `CountryMapScene.applyFeedbackPresentation()`:

```swift
scoutCardNode.applyFeedback(
    text: transientFeedback?.text,
    alpha: transientFeedback?.alpha ?? 0,
    blocksAttack: transientFeedback?.blocksScoutEntry ?? true
)
```

Update `redraw()` so flavor does not globally disable entry:

```swift
let blocksScoutEntry = transientFeedback?.blocksScoutEntry ?? false

let result = scoutCardNode.apply(
    content: content,
    layout: scoutCardLayout,
    isEntryEnabled: state.stageStatus != .countryComplete
        && !isRoutingToBattle
        && !blocksScoutEntry
)
```

Replace the Scout body no-op with:

```swift
if scoutCardNode.cardHitFrame?.contains(point) == true {
    if case .scout(let scout) = CountryMapScoutCardContent.project(from: state) {
        showFeedback(.flavor(scout.flavorText))
    }
    return
}
```

Input priority stays: blocking/non-blocking overlay → Attack → Scout body → other controls. Because the flavor overlay does not intersect Attack, Attack remains reachable.

- [ ] **Step 8: Render final-country and named feedback from pure projections**

In `CountryMapScoutCardNode.prepare`:

```swift
case .countryComplete(let countryNumber, let finalCityName):
    let text = "Country \(countryNumber) conquered · \(finalCityName)"
```

No catalog read belongs in the node.

Change locked/completed feedback APIs to accept `cityTitle:` and pass `state.displayCityTitle(for:)` from scene call sites.

For idle final-country feedback, read final City 15 through the pure/catalog layer and produce:

```text
Country 1 conquered at Crownspire Keep.
```

Update `CountryMapScoutCardAcceptanceTests` old locked/completed/final strings and enum equality checks in the same task.

- [ ] **Step 9: Run GREEN and commit**

Run the Task 3 command again.

```bash
git add Pyxis/CountryMapScoutCardContent.swift Pyxis/CountryMapScoutCardLayout.swift \
  Pyxis/CountryMapScoutCardNode.swift Pyxis/CountryMapTransientFeedback.swift \
  Pyxis/CountryMapScene.swift PyxisTests/CountryMapScoutCardContentTests.swift \
  PyxisTests/CountryMapScoutCardLayoutTests.swift PyxisTests/CountryMapScoutCardNodeTests.swift \
  PyxisTests/CountryMapTransientFeedbackTests.swift PyxisTests/CountryMapSceneTests.swift \
  PyxisTests/CountryMapScoutCardAcceptanceTests.swift
git commit -m "feat: show nonblocking city flavor"
```

---

### Task 4: Run authored fit acceptance and stale-copy checks

**Files:**
- Modify: `PyxisTests/CountryMapScoutCardNodeTests.swift`
- Verify: `PyxisTests/CountryMapScoutCardTextLayoutTests.swift`
- Verify: `PyxisTests/CountryMapScoutCardAcceptanceTests.swift`
- Verify: production/test call-site inventory

**Interfaces:**
- Consumes: final 15-city catalog, blocking overlay, non-blocking flavor overlay
- Preserves: existing nominal title test and all-content matrix; no duplicate layout framework

- [ ] **Step 1: Expand the existing feedback-fit family to actual authored strings**

Update `everyFeedbackCopyFamilyFitsTheActualLabelOnMinimumPhoneAndPad` so it enumerates, rather than samples:

```swift
let authored = Country1CityCatalog.definitions
let blockingMessages = authored.flatMap { definition in
    [
        "\(definition.displayTitle) is locked",
        "\(definition.displayTitle) complete"
    ]
} + [
    "Country 1 conquered at Crownspire Keep.",
    "Cannot enter city yet."
]

let flavorMessages = authored.map(\.flavorText)
```

For blocking messages, call `applyFeedback(..., blocksAttack: true)` and verify the existing full blocking overlay contains the label at the current >= 8 pt floor.

For flavor messages, call `applyFeedback(..., blocksAttack: false)` and verify the label fits `nonBlockingOverlayFrame`, Attack remains present, and no flavor overlay intersects Attack.

Do not add a second text-layout engine or a per-city scene matrix.

- [ ] **Step 2: Make the existing all-content matrix carry authored identity**

In `allCurrentContentPresentsAcrossEveryFixtureAndImageOutcome`, use:

```swift
let definition = Country1CityCatalog.definition(for: cityNumber)
let scout = CountryMapScoutCardContent.Scout(
    cityNumber: cityNumber,
    displayTitle: definition.displayTitle,
    flavorText: definition.flavorText,
    defenseTrait: trait,
    exposedLane: lane,
    goldReward: reward
)
```

Keep the existing `node.apply(...) == .presented` expectation for every supported fixture/image outcome.

- [ ] **Step 3: Re-run the stronger nominal title gate**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/CountryMapScoutCardTextLayoutTests \
  -only-testing:PyxisTests/CountryMapScoutCardNodeTests \
  -only-testing:PyxisTests/CountryMapScoutCardAcceptanceTests
```

Expected:

- all 15 titles stay at nominal 11/16 pt;
- all current dense card combinations present;
- every flavor fits the non-blocking frame;
- every blocking copy fits the blocking frame.

If a copy fails, shorten the authored string. Do not lower the nominal title size or add another layout policy.

- [ ] **Step 4: Run repository-wide stale-copy searches**

```bash
rg 'Country 1 - City|Country 1 Conquered|City [0-9]+: (Standard Watch|Arrow Tower|Spiked Gate|Stone Wall|Arcane Ward|Burning Oil|Reinforced Keep)' \
  Pyxis PyxisTests
```

Review every hit. Keep only intentional legacy fallback/tests and unrelated historical semantics.

Then:

```bash
rg 'Willowford|Pinewatch|Falconridge|Bramblegate|Highcrest|Granite Pass|Emberford|Greywall|Runewatch|Ironthorn Gate|Kingshield Keep|Ashbridge|Starveil Citadel|Stonecrown|Crownspire Keep' Pyxis
```

Expected: authored city names in production are centralized in `Country1CityCatalog.swift`; scenes must not contain a parallel city-name switch/table. Literal final-country format strings may interpolate projected/catalog values but must not duplicate the name table.

- [ ] **Step 5: Commit Task 4**

```bash
git add PyxisTests/CountryMapScoutCardNodeTests.swift
git commit -m "test: validate Country 1 identity fit"
```

---

### Task 5: Document ownership, run full verification, and smoke the campaign

**Files:**
- Modify: `CLAUDE.md`
- Verify: all production/test files changed in Tasks 1-4

**Interfaces:**
- Produces: architecture guidance for future city-content changes

- [ ] **Step 1: Update architecture guidance**

In the existing `Country1CityCatalog` architecture/conventions material, add:

```markdown
`Country1CityCatalog` is also the sole source of authored Country 1 identity (`name`, `flavorText`, `conquestTitle`). UI derives copy from `CityDefinition`; do not persist identity copies in campaign/result state or add parallel city-name switches in scenes. Conquest reports resolve identity from their persisted `BattleResult.cityKey`. Scout flavor uses the existing transient layer in non-blocking mode and must never disable the Scout Attack action.
```

Do not create another documentation file.

- [ ] **Step 2: Run the full automated suite**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO
```

Expected: full unit/UI suite PASS.

- [ ] **Step 3: Run lint and diff checks**

```bash
swiftlint lint --no-cache
git diff --check origin/main...HEAD
```

Expected: SwiftLint exits 0 with no new serious finding; diff check is clean.

- [ ] **Step 4: Run the City 1→15 identity smoke**

Using simulator/device state seeding as convenient, verify every city:

1. Scout Card shows `City N · Name` at readable nominal sizing.
2. Tapping the non-action Scout body shows the reviewed flavor text.
3. Attack remains immediately tappable while flavor is still visible.
4. Battle HUD and city-info tooltip show the same `City N · Name`.
5. Building View conquest feedback uses the same title when buildings finish a city.
6. Conquest report shows the reviewed authored conquest title.
7. Locked/completed/idle map feedback uses the same identity.
8. City 15 report says `Crownspire Keep Falls`; after Continue the Country Map says `Country 1 conquered · Crownspire Keep`.
9. No trait, lane, reward, building, routing, SFX, haptic, or combat behavior differs from `main`.

Record a copy/layout mismatch as an HPA-366 fix. Do not turn this smoke into a new automation framework.

- [ ] **Step 5: Commit Task 5**

```bash
git add CLAUDE.md
git commit -m "docs: document Country 1 identity ownership"
```

---

## Risks and controls

### 1. Authored title exceeds the real layout budget

Control: the nominal production title-fit test runs in Task 1 against `CityDefinition.displayTitle`. The table is not considered authored until it passes; `Kingshield Keep` replaces the overflowing `Kingshield Bastion` before downstream tests hard-code it.

### 2. Flavor blocks the primary Attack action

Control: flavor is the sole non-blocking transient kind; layout provides a pure non-Attack overlay frame; scene entry remains enabled; node preserves the Attack hit frame; a scene test taps Attack before flavor expires.

### 3. Final-country semantics drift

Control: report title is resolved from `BattleResult.cityKey`, and both existing final-country Battle tests require `Crownspire Keep Falls` while map tests require the country-level confirmation.

### 4. Stale exact-string test copy

Control: Task 2 updates the known Battle/Building/report blast radius atomically; Task 3 updates the Country Map blast radius atomically; Task 4 `rg` searches are only the final backstop.

### 5. Transient-copy fit regression

Control: enumerate all authored flavor/locked/completed/final strings through existing fit helpers. This is inexpensive regression coverage, not the primary layout risk.

## Final scope check

The implementation must remain a compact vertical slice:

- Authored identity rows: exactly 15.
- New production files: 0.
- Persistence schema changes: 0.
- New gameplay systems/mechanics: 0.
- New scenes/modals: 0.
- New durable state: 0.
- One added pure Scout layout frame and one `.flavor` transient kind are allowed because they are the minimum required to ship the ticket's flavor text without blocking Attack.

If implementation starts introducing a reusable content platform, generic campaign abstraction, persistence migration, second text-layout policy, or milestone effect, stop and reduce scope back to this plan.