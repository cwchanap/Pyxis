# HPA-366 Country 1 City Identity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the reviewed 15-city Country 1 identity set through the current map, battle, and conquest surfaces without changing gameplay, persistence, or adding a content framework.

**Architecture:** Extend the existing `CityDefinition` / `Country1CityCatalog` source of truth with three authored strings and route display through existing `KingdomGameState`, Scout Card, transient-feedback, Battle HUD, and conquest-report seams. Keep the existing clamped gameplay lookup, add one optional display lookup for safe fallback, and resolve authored copy at presentation time instead of persisting it.

**Tech Stack:** Swift 5, SpriteKit, UIKit, Swift Testing, Xcode/iOS Simulator.

## Global Constraints

- Implement the approved design in `docs/superpowers/specs/2026-08-08-country-1-city-identity-design.md`.
- Country 1 remains exactly 15 cities.
- `name` is non-empty and at most 18 characters; `flavorText` is non-empty and at most 48; `conquestTitle` is non-empty and at most 24.
- Names are unique case-insensitively.
- Preserve every existing defense trait and lane profile exactly.
- Do not change HP, reward, unlock, building, idle, routing, combat, sound, or haptic behavior.
- Do not add persistence fields or modify `BattleResult` / `KingdomGameState` coding keys.
- Do not add a content service, protocol, repository, registry, generic multi-country abstraction, localization layer, or theme metadata.
- Do not add HPA-390 milestone effects.
- No new production file is required; do not edit `Pyxis.xcodeproj/project.pbxproj`.
- Unit tests use Swift Testing. Always run simulator tests with `-parallel-testing-enabled NO`.

---

### Task 1: Extend the authored city catalog with the reviewed identity set

**Files:**
- Modify: `Pyxis/CityDefinition.swift`
- Modify: `Pyxis/Country1CityCatalog.swift`
- Modify: `PyxisTests/Country1CityCatalogTests.swift`

**Interfaces:**
- Produces: `CityDefinition.name: String`
- Produces: `CityDefinition.flavorText: String`
- Produces: `CityDefinition.conquestTitle: String`
- Produces: `CityDefinition.displayTitle: String`
- Produces: `Country1CityCatalog.definitionIfPresent(for:) -> CityDefinition?`
- Preserves: `Country1CityCatalog.definition(for:) -> CityDefinition` clamping semantics

- [ ] **Step 1: Expand the independent expected fixture and write failing identity assertions**

Add `import Foundation` to `PyxisTests/Country1CityCatalogTests.swift` for trimming/lowercasing helpers. Expand `ExpectedDefinition` to this exact shape:

```swift
private struct ExpectedDefinition {
    let cityNumber: Int
    let name: String
    let flavorText: String
    let conquestTitle: String
    let defenseTrait: CityDefenseTrait
    let fortifiedLane: BattleLane
    let exposedLane: BattleLane

    init(
        _ cityNumber: Int,
        _ name: String,
        _ flavorText: String,
        _ conquestTitle: String,
        _ defenseTrait: CityDefenseTrait,
        _ fortifiedLane: BattleLane,
        _ exposedLane: BattleLane
    ) {
        self.cityNumber = cityNumber
        self.name = name
        self.flavorText = flavorText
        self.conquestTitle = conquestTitle
        self.defenseTrait = defenseTrait
        self.fortifiedLane = fortifiedLane
        self.exposedLane = exposedLane
    }

    var definition: CityDefinition {
        CityDefinition(
            cityNumber: cityNumber,
            name: name,
            flavorText: flavorText,
            conquestTitle: conquestTitle,
            defenseTrait: defenseTrait,
            laneDefenseProfile: LaneDefenseProfile(
                fortifiedLane: fortifiedLane,
                exposedLane: exposedLane
            )
        )
    }
}
```

Use this exact reviewed fixture:

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
    .init(11, "Kingshield Bastion", "A reinforced fortress guards the royal road.", "Kingshield Bastion Falls", .reinforcedKeep, .center, .left),
    .init(12, "Ashbridge", "Fire cauldrons guard the last crossing.", "Ashbridge Secured", .burningOil, .right, .center),
    .init(13, "Starveil Citadel", "Arcane wards protect the capital heights.", "Starveil Citadel Falls", .arcaneWard, .left, .right),
    .init(14, "Stonecrown", "Massive stone walls ring the royal seat.", "Stonecrown Breached", .stoneWall, .center, .left),
    .init(15, "Crownspire Keep", "The final keep rises above the capital.", "Crownspire Keep Falls", .reinforcedKeep, .right, .center)
]
```

Add these focused assertions:

```swift
@Test func authoredIdentityIsCompleteUniqueAndWithinCopyLimits() {
    let definitions = Country1CityCatalog.definitions
    let normalizedNames = definitions.map {
        $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    #expect(definitions.count == 15)
    #expect(Set(normalizedNames).count == 15)
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

Keep the existing `catalogIsCompleteUniqueOrderedAndMatchesAuthoredCombatMetadata` and clamping tests; after updating their fixture construction they continue to protect the original trait/lane values.

- [ ] **Step 2: Run the focused catalog tests and verify they fail**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/Country1CityCatalogTests
```

Expected: compile/test failure because the new identity fields and `definitionIfPresent(for:)` do not exist yet.

- [ ] **Step 3: Extend `CityDefinition` with only the three shipping identity fields**

Replace the type with:

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

Do not add `Codable`, localization IDs, theme fields, or optional identity values.

- [ ] **Step 4: Install the exact authored table and optional display lookup**

Update every `CityDefinition` in `Country1CityCatalog.definitions` with the exact strings from Step 1 while preserving its current `defenseTrait`, `fortifiedLane`, and `exposedLane` values.

Add:

```swift
static func definitionIfPresent(for cityNumber: Int) -> CityDefinition? {
    guard cityRange.contains(cityNumber) else { return nil }
    return definitions[cityNumber - cityRange.lowerBound]
}
```

Keep the current clamped implementation of `definition(for:)` unchanged.

- [ ] **Step 5: Run the focused catalog tests and verify they pass**

Run the Task 1 command again.

Expected: `Country1CityCatalogTests` PASS, including the old combat-metadata and clamping behavior.

- [ ] **Step 6: Commit Task 1**

```bash
git add Pyxis/CityDefinition.swift Pyxis/Country1CityCatalog.swift PyxisTests/Country1CityCatalogTests.swift
git commit -m "feat: author Country 1 city identities"
```

---

### Task 2: Route shared display and completion identity through existing model projections

**Files:**
- Modify: `Pyxis/KingdomGameState.swift`
- Modify: `Pyxis/CountryMapScoutCardContent.swift`
- Modify: `PyxisTests/KingdomGameStateTests.swift`
- Modify: `PyxisTests/CountryMapScoutCardContentTests.swift`

**Interfaces:**
- Consumes: `Country1CityCatalog.definitionIfPresent(for:)`
- Produces: `KingdomGameState.displayCityTitle(for:)`
- Produces: `KingdomGameState.displayConquestTitle(for:)`
- Produces: `CountryMapScoutCardContent.Scout.flavorText`
- Produces: `CountryMapScoutCardContent.countryComplete(countryNumber:finalCityName:)`

- [ ] **Step 1: Write model-facing title and fallback tests**

Add to `KingdomGameStateTests.swift`:

```swift
@Test func countryOneIdentityUsesCatalogAndUnsupportedDisplayValuesKeepLegacyFallback() {
    let state = KingdomGameState(cityNumberInCountry: 6, completedCityCount: 5)

    #expect(state.displayCityTitle == "City 6 · Granite Pass")
    #expect(state.displayCityTitle(for: 15) == "City 15 · Crownspire Keep")
    #expect(state.displayConquestTitle(for: 6) == "Granite Pass Open")
    #expect(state.displayCityTitle(for: 99) == "Country 1 - City 99")
    #expect(state.displayConquestTitle(for: 99) == "Country 1 - City 99 Conquered")

    let unsupportedCountry = KingdomGameState(countryNumber: 2)
    #expect(unsupportedCountry.displayCityTitle(for: 1) == "Country 2 - City 1")
    #expect(unsupportedCountry.displayConquestTitle(for: 1) == "Country 2 - City 1 Conquered")
}
```

Update `CountryMapScoutCardContentTests.swift` expected values so City 1 projects:

```swift
.scout(.init(
    cityNumber: 1,
    displayTitle: "City 1 · Willowford",
    flavorText: "A quiet crossing where the campaign begins.",
    defenseTrait: .standardWatch,
    exposedLane: .right,
    goldReward: KingdomGameState.goldReward(for: 1)
))
```

Update the country-complete expectation to:

```swift
.countryComplete(countryNumber: 1, finalCityName: "Crownspire Keep")
```

For the existing per-city Scout loops, derive expected `displayTitle` and `flavorText` from the already-fetched `definition`:

```swift
displayTitle: definition.displayTitle,
flavorText: definition.flavorText,
```

Do not add a second expected city-name table here.

- [ ] **Step 2: Run the focused model and Scout projection tests and verify they fail**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/KingdomGameStateTests \
  -only-testing:PyxisTests/CountryMapScoutCardContentTests
```

Expected: failures on the old legacy title and old Scout enum shape.

- [ ] **Step 3: Replace `KingdomGameState` display formatting with catalog-backed copy plus legacy fallback**

Replace the current `displayCityTitle(for:)` and add the conquest companion:

```swift
func displayCityTitle(for cityNumber: Int) -> String {
    guard countryNumber == 1,
          let definition = Country1CityCatalog.definitionIfPresent(for: cityNumber) else {
        return "Country \(countryNumber) - City \(cityNumber)"
    }
    return definition.displayTitle
}

func displayConquestTitle(for cityNumber: Int) -> String {
    guard countryNumber == 1,
          let definition = Country1CityCatalog.definitionIfPresent(for: cityNumber) else {
        return "\(displayCityTitle(for: cityNumber)) Conquered"
    }
    return definition.conquestTitle
}
```

Keep:

```swift
var displayCityTitle: String {
    displayCityTitle(for: cityNumberInCountry)
}
```

Do not change `currentCityDefinition`, defense-trait lookup, or persistence normalization.

- [ ] **Step 4: Project flavor and final-city identity in `CountryMapScoutCardContent`**

Change the Scout payload to:

```swift
struct Scout: Equatable {
    let cityNumber: Int
    let displayTitle: String
    let flavorText: String
    let defenseTrait: CityDefenseTrait
    let exposedLane: BattleLane
    let goldReward: Int
}
```

Change the country-complete case to:

```swift
case countryComplete(countryNumber: Int, finalCityName: String)
```

Project final-country content from the same catalog:

```swift
if state.stageStatus == .countryComplete {
    let finalCity = Country1CityCatalog.definition(for: Country1CityCatalog.cityRange.upperBound)
    return .countryComplete(
        countryNumber: state.countryNumber,
        finalCityName: finalCity.name
    )
}
```

For normal Scout projection, set:

```swift
flavorText: definition.flavorText
```

alongside the existing `displayTitle`, trait, lane, and reward fields.

- [ ] **Step 5: Run the focused tests and verify they pass**

Run the Task 2 command again.

Expected: both test groups PASS.

- [ ] **Step 6: Commit Task 2**

```bash
git add Pyxis/KingdomGameState.swift Pyxis/CountryMapScoutCardContent.swift PyxisTests/KingdomGameStateTests.swift PyxisTests/CountryMapScoutCardContentTests.swift
git commit -m "feat: project shared city identity"
```

---

### Task 3: Integrate identity and flavor into the existing Country Map surfaces

**Files:**
- Modify: `Pyxis/CountryMapTransientFeedback.swift`
- Modify: `Pyxis/CountryMapScoutCardNode.swift`
- Modify: `Pyxis/CountryMapScene.swift`
- Modify: `PyxisTests/CountryMapTransientFeedbackTests.swift`
- Modify: `PyxisTests/CountryMapScoutCardNodeTests.swift`
- Modify: `PyxisTests/CountryMapSceneTests.swift`

**Interfaces:**
- Consumes: `CountryMapScoutCardContent.Scout.flavorText`
- Consumes: `CountryMapScoutCardContent.countryComplete(countryNumber:finalCityName:)`
- Consumes: `KingdomGameState.displayCityTitle(for:)`
- Produces: named locked/completed/idle/final-country transient copy
- Produces: non-mutating Scout Card body tap that presents flavor text

- [ ] **Step 1: Update Country Map copy tests and all changed Scout payload construction**

Change `CountryMapTransientFeedbackTests.swift` to use resolved titles:

```swift
let locked = CountryMapTransientFeedback.locked(cityTitle: "City 7 · Emberford")
let completed = CountryMapTransientFeedback.completed(cityTitle: "City 12 · Ashbridge")

#expect(locked.text == "City 7 · Emberford is locked")
#expect(completed.text == "City 12 · Ashbridge complete")
```

Update idle-conquest expectations to:

```swift
#expect(CountryMapTransientFeedback.idle(
    result: .init(elapsedSeconds: 10, damageDealt: 9, conqueredCities: 1, goldEarned: 4),
    state: pendingState
)?.text == "City 4 · Bramblegate")

#expect(CountryMapTransientFeedback.idle(
    result: .init(elapsedSeconds: 10, damageDealt: 9, conqueredCities: 1, goldEarned: 4),
    state: countryCompleteState
)?.text == "Country 1 conquered at Crownspire Keep.")
```

In `CountryMapScoutCardNodeTests.swift`, update every direct Scout construction/helper for the new field. The helper becomes:

```swift
private func testScout(
    cityNumber: Int = 3,
    displayTitle: String = "City 3 · Falconridge",
    flavorText: String = "Arrow towers command the high ridge road.",
    trait: CityDefenseTrait = .arrowTower,
    lane: BattleLane = .left,
    goldReward: Int = 27
) -> CountryMapScoutCardContent.Scout {
    .init(
        cityNumber: cityNumber,
        displayTitle: displayTitle,
        flavorText: flavorText,
        defenseTrait: trait,
        exposedLane: lane,
        goldReward: goldReward
    )
}
```

Update the first direct Scout fixture the same way. Update every `.countryComplete(countryNumber:)` test construction to include `finalCityName:`. Update the feedback-copy fitting list to include the longest/new families, including:

```swift
"City 15 · Crownspire Keep is locked",
"City 15 · Crownspire Keep complete",
"Country 1 conquered at Crownspire Keep.",
"The final keep rises above the capital."
```

This ensures existing one-line feedback fitting is exercised with HPA-366 copy.

- [ ] **Step 2: Add a representative scene test for Scout flavor and named state feedback**

In `CountryMapSceneTests.swift`, add:

```swift
@Test func scoutCardBodyShowsFlavorWithoutMutationRoutingOrGameplayFeedback() throws {
    let initialState = KingdomGameState(
        cityLevel: 6,
        cityNumberInCountry: 6,
        completedCityCount: 5,
        stageStatus: .battleActive
    )
    let store = try makeStore(initialState: initialState)
    let router = RouteSpy()
    let feedback = CountryMapFeedbackRecorder()
    let scene = makeScene(store: store, router: router, feedback: feedback)
    let card = try #require(scene.scoutCardHitFrameForTesting)
    let attack = try #require(scene.scoutCardAttackHitFrameForTesting)
    let point = CGPoint(x: card.minX + 4, y: card.maxY - 4)
    #expect(!attack.contains(point))

    scene.handleTouchForTesting(at: point)

    #expect(scene.visibleFeedbackTextForTesting == "Stone walls seal the mountain road ahead.")
    #expect(store.load() == initialState)
    #expect(router.battleRequestCount == 0)
    #expect(feedback.calls.isEmpty)
}
```

Update existing locked/completed/idle/final-country scene expectations to the authored copy. Update all country-complete content equality checks to `.countryComplete(countryNumber: 1, finalCityName: "Crownspire Keep")`.

- [ ] **Step 3: Run the Country Map tests and verify they fail**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/CountryMapTransientFeedbackTests \
  -only-testing:PyxisTests/CountryMapScoutCardNodeTests \
  -only-testing:PyxisTests/CountryMapSceneTests
```

Expected: compile/copy failures because feedback signatures and country-complete content still use the old shape, and Scout body taps are currently ignored.

- [ ] **Step 4: Make transient feedback accept resolved display titles**

Change:

```swift
static func locked(cityTitle: String) -> Self {
    .init(
        kind: .locked,
        text: "\(cityTitle) is locked",
        totalDuration: 1.5,
        fadeDuration: 0.3
    )
}

static func completed(cityTitle: String) -> Self {
    .init(
        kind: .completed,
        text: "\(cityTitle) complete",
        totalDuration: 1.5,
        fadeDuration: 0.3
    )
}
```

In `idle(result:state:)`, keep damage/no-damage copy unchanged and replace only the conquest branch:

```swift
if result.conqueredCities > 0 {
    if state.stageStatus == .countryComplete {
        let finalCity = Country1CityCatalog.definition(for: Country1CityCatalog.cityRange.upperBound)
        text = "Country \(state.countryNumber) conquered at \(finalCity.name)."
    } else if let cityNumber = state.unlockedMapCityNumber {
        text = state.displayCityTitle(for: cityNumber)
    } else {
        assertionFailure("Idle conquest must unlock a city or complete the country")
        return nil
    }
}
```

Do not change durations or fade behavior.

- [ ] **Step 5: Render the named country-complete Scout Card using the existing title label**

Update `CountryMapScoutCardNode.prepare`:

```swift
case .countryComplete(let countryNumber, let finalCityName):
    let text = "Country \(countryNumber) conquered · \(finalCityName)"
    guard let fontSize = fittedFontSize(
        text,
        startingAt: metrics.titleSize,
        frameWidth: layout.cardFrame.width
    ) else {
        return nil
    }
    return .countryComplete(text: text, fontSize: fontSize)
```

The existing node test should expect:

```swift
content: .countryComplete(countryNumber: 1, finalCityName: "Crownspire Keep")
#expect(node.titleTextForTesting == "Country 1 conquered · Crownspire Keep")
```

No new node hierarchy is needed.

- [ ] **Step 6: Wire named map feedback and Scout flavor in `CountryMapScene`**

At locked/completed call sites, resolve through the state:

```swift
showFeedback(.locked(cityTitle: state.displayCityTitle(for: cityNumber)))
```

and:

```swift
showFeedback(.completed(cityTitle: state.displayCityTitle(for: cityNumber)))
```

Replace the current no-op Scout Card body branch with:

```swift
if scoutCardNode.cardHitFrame?.contains(point) == true {
    if case .scout(let scout) = CountryMapScoutCardContent.project(from: state) {
        showFeedback(.status(scout.flavorText))
    }
    return
}
```

Keep the current input priority: layout/routing guards → Settings/modal → Settings gear → Scout overlay → Scout Attack → Scout body → current-city control → city nodes. Flavor must never steal an Attack tap.

- [ ] **Step 7: Run the focused Country Map tests and verify they pass**

Run the Task 3 command again.

Expected: all three test groups PASS with existing feedback timing and touch-priority behavior preserved.

- [ ] **Step 8: Commit Task 3**

```bash
git add Pyxis/CountryMapTransientFeedback.swift Pyxis/CountryMapScoutCardNode.swift Pyxis/CountryMapScene.swift PyxisTests/CountryMapTransientFeedbackTests.swift PyxisTests/CountryMapScoutCardNodeTests.swift PyxisTests/CountryMapSceneTests.swift
git commit -m "feat: show city identity on country map"
```

---

### Task 4: Use authored conquest titles without changing `BattleResult`

**Files:**
- Modify: `Pyxis/ConquestReportContent.swift`
- Modify: `Pyxis/BattleScene.swift`
- Modify: `PyxisTests/ConquestReportContentTests.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`

**Interfaces:**
- Consumes: `KingdomGameState.displayConquestTitle(for:)`
- Changes: `ConquestReportContent.project(from:title:)`
- Removes: title derivation from `isCountryComplete`
- Preserves: all report rows, achievements, restoration, persistence, routing, and effect behavior

- [ ] **Step 1: Change the pure report tests to assert caller-owned exact titles**

Update the first report test:

```swift
let content = ConquestReportContent.project(
    from: makeResult(mode: .live, seconds: 65),
    title: "Falconridge Silenced"
)
#expect(content.title == "Falconridge Silenced")
```

Update every other `ConquestReportContent.project` call to pass a `title:` string and remove `cityTitle:` / `isCountryComplete:`.

Replace the old `countryCompleteIgnoresCityTitle` test with:

```swift
@Test func reportUsesCallerProvidedTitleWithoutCampaignFormatting() {
    let content = ConquestReportContent.project(
        from: makeResult(city: 15),
        title: "Crownspire Keep Falls"
    )
    #expect(content.title == "Crownspire Keep Falls")
}
```

- [ ] **Step 2: Add/update one Battle scene expectation for the authored title**

Use existing conquest-report scene coverage/readback and assert a City 3 report title is `Falconridge Silenced`. For an existing final-city report assertion, change the expected report title to `Crownspire Keep Falls`; overall Country completion remains map-owned.

Do not add a new DEBUG-only test API if the existing `lastAppliedConquestReportContent` readback already exposes the projected content.

- [ ] **Step 3: Run report and Battle tests and verify they fail**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/ConquestReportContentTests \
  -only-testing:PyxisTests/BattleSceneTests
```

Expected: compile/expectation failures on the old report signature/title rules.

- [ ] **Step 4: Simplify `ConquestReportContent.project` to accept the exact title**

Replace the current projection with this body, preserving all existing row/achievement behavior:

```swift
static func project(
    from result: BattleResult,
    title: String
) -> Self {
    var lines = [
        "Gold earned: +\(CompactNumberFormatter.string(from: result.goldEarned))"
    ]
    switch result.conquestMode {
    case .live:
        lines.append("Battle time: \(durationText(result.activeBattleSeconds))")
    case .idle:
        lines.append("Conquered by your buildings")
    }
    if let type = result.mvpSoldierType,
       let percent = result.mvpDamageSharePercent {
        lines.append("MVP: \(type.displayName) · \(percent)%")
    }
    lines.append(
        "Deployed: \(CompactNumberFormatter.string(from: result.totalDeploymentCount))"
            + " · Lost: \(CompactNumberFormatter.string(from: result.totalLossCount))"
    )
    var achievements = [Achievement]()
    if result.usedFavorableUnit { achievements.append(.favorableUnit) }
    if result.usedExposedLane { achievements.append(.exposedLane) }
    return Self(title: title, summaryLines: lines, achievements: achievements)
}
```

This removes only the old title derivation branch. Keep `durationText` and `goldLineIndex` unchanged.

- [ ] **Step 5: Resolve the authored/fallback title at the existing Battle scene call site**

Change `BattleScene.conquestReportContent(for:)` to:

```swift
private func conquestReportContent(for result: BattleResult) -> ConquestReportContent {
    .project(
        from: result,
        title: state.displayConquestTitle(for: result.cityKey.cityNumber)
    )
}
```

Do not modify `BattleResult`, pending-result persistence, report origin, Continue ordering, gold burst anchoring, SFX/haptics, or routing.

- [ ] **Step 6: Search for stale report signature/copy before rerunning tests**

```bash
rg 'cityTitle:|isCountryComplete:|Country 1 Conquered|Country 1 - City [0-9]+ Conquered' Pyxis PyxisTests
```

Expected after updating intended call sites/tests: no stale `ConquestReportContent.project` arguments and no old report-title assertions. The fallback code `Country N - City M` remains intentionally covered elsewhere.

- [ ] **Step 7: Run report and Battle tests and verify they pass**

Run the Task 4 test command again.

Expected: `ConquestReportContentTests` and `BattleSceneTests` PASS.

- [ ] **Step 8: Commit Task 4**

```bash
git add Pyxis/ConquestReportContent.swift Pyxis/BattleScene.swift PyxisTests/ConquestReportContentTests.swift PyxisTests/BattleSceneTests.swift
git commit -m "feat: use authored conquest titles"
```

---

### Task 5: Lock existing layout acceptance, update architecture guidance, and run campaign-facing verification

**Files:**
- Modify: `PyxisTests/CountryMapScoutCardNodeTests.swift`
- Modify: `CLAUDE.md`
- Verify: all production/test files changed in Tasks 1-4

**Interfaces:**
- Consumes: final 15-city catalog and existing Scout Card layout/fitting path
- Preserves/extends: existing `allCurrentContentPresentsAcrossEveryFixtureAndImageOutcome` coverage instead of adding another overlapping matrix
- Produces: architecture documentation declaring `Country1CityCatalog` the identity source of truth

- [ ] **Step 1: Make the existing all-content Scout Card test exercise authored identity**

The current `allCurrentContentPresentsAcrossEveryFixtureAndImageOutcome` already loops every supported layout fixture, image-present/image-missing outcome, trait, lane, and all 15 city numbers. Do not add a second all-title matrix.

Update its direct Scout construction to carry the authored definition:

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

Keep the existing expectation that `node.apply(...) == .presented` for every supported fixture. That existing matrix becomes the actual layout acceptance test for all 15 authored titles.

Also update the test's diagnostic string if useful to include `definition.displayTitle`; do not create per-city scene tests.

- [ ] **Step 2: Run the Scout Card tests**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/CountryMapScoutCardNodeTests
```

Expected: PASS for all authored titles on every supported fixture. If a title fails, shorten the authored copy within the approved limits; do not add a new layout policy.

- [ ] **Step 3: Update `CLAUDE.md` with the identity ownership rule**

In the architecture paragraph that explains `Country1CityCatalog`, add:

```markdown
`Country1CityCatalog` is also the sole source of authored Country 1 identity (`name`, `flavorText`, `conquestTitle`). UI derives city copy from `CityDefinition`; do not persist copies in campaign/result state or add parallel city-name switches in scenes.
```

Keep this in the existing architecture/conventions material.

- [ ] **Step 4: Run repository-wide stale-copy searches**

```bash
rg 'Country 1 - City|City [0-9]+: (Standard Watch|Arrow Tower|Spiked Gate|Stone Wall|Arcane Ward|Burning Oil|Reinforced Keep)' Pyxis PyxisTests
```

Review every hit. Production player-facing copy for valid Country 1 identity should route through the catalog. Keep the explicit legacy fallback implementation and its tests.

Then:

```bash
rg 'Willowford|Pinewatch|Falconridge|Bramblegate|Highcrest|Granite Pass|Emberford|Greywall|Runewatch|Ironthorn Gate|Kingshield Bastion|Ashbridge|Starveil Citadel|Stonecrown|Crownspire Keep' Pyxis
```

Expected: authored names occur in production only in `Country1CityCatalog.swift`; scenes should not contain a parallel city-name table or switch.

- [ ] **Step 5: Run the full automated verification with parallel simulator clones disabled**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO
```

Then:

```bash
swiftlint lint --no-cache
git diff --check origin/main...HEAD
```

Expected: full unit/UI suite PASS, SwiftLint exits 0 with no new serious finding, and `git diff --check` is clean.

- [ ] **Step 6: Run the manual City 1→15 identity smoke**

Using simulator/device state seeding as convenient, verify each city from 1 through 15:

1. Country Map Scout Card shows `City N · Name`.
2. Tapping the non-action Scout Card body shows the reviewed flavor text.
3. Battle HUD and city-info tooltip show the same `City N · Name` title.
4. Conquest report shows the reviewed authored conquest title.
5. Locked/completed/idle map feedback uses the same identity.
6. City 15 ends on `Crownspire Keep Falls`, then the Country Map shows `Country 1 conquered · Crownspire Keep`.
7. No trait, lane, reward, building, routing, SFX, haptic, or combat behavior differs from `main`.

Record any copy/layout mismatch as an HPA-366 fix. Do not turn the smoke into a new automation framework.

- [ ] **Step 7: Commit Task 5**

```bash
git add PyxisTests/CountryMapScoutCardNodeTests.swift CLAUDE.md
git commit -m "test: validate Country 1 identity presentation"
```

---

## Final scope check

The implementation should remain a compact vertical slice:

- Production files modified: existing model/content/scene/report files only.
- New production files: 0.
- Persistence schema changes: 0.
- New gameplay systems: 0.
- New mechanics: 0.
- New UI surfaces: 0.
- Authored city identity rows: exactly 15.

If implementation starts introducing a reusable content platform, multi-country abstraction, persistence migration, new modal, or milestone effect, stop and reduce scope back to this plan.
