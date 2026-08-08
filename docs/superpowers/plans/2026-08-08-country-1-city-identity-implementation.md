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

In `PyxisTests/Country1CityCatalogTests.swift`, extend `ExpectedDefinition` with `name`, `flavorText`, and `conquestTitle`, and make its `definition` builder use the new initializer.

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

Add focused assertions:

```swift
@Test func authoredIdentityIsCompleteUniqueAndWithinCopyLimits() {
    let definitions = Country1CityCatalog.definitions
    let normalizedNames = definitions.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

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

Keep the existing clamping test unchanged; it protects gameplay compatibility.

- [ ] **Step 2: Run the focused catalog tests and verify they fail**

Run:

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

Add below `definition(for:)` or immediately before it:

```swift
static func definitionIfPresent(for cityNumber: Int) -> CityDefinition? {
    guard cityRange.contains(cityNumber) else { return nil }
    return definitions[cityNumber - cityRange.lowerBound]
}
```

Keep the current clamped implementation of `definition(for:)` unchanged.

- [ ] **Step 5: Run the focused catalog tests and verify they pass**

Run the Task 1 command again.

Expected: `Country1CityCatalogTests` PASS, including the old combat-metadata fixture and clamping assertions.

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

Add a focused test to `KingdomGameStateTests.swift`:

```swift
@Test func CountryOneIdentityUsesCatalogAndUnsupportedDisplayValuesKeepLegacyFallback() {
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

Apply the same identity fields to the existing per-city Scout projection loops by deriving expected strings from `Country1CityCatalog.definition(for:)` rather than creating another name switch.

- [ ] **Step 2: Run the focused model and Scout projection tests and verify they fail**

Run:

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

Keep `displayCityTitle` as the current convenience property:

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

- [ ] **Step 1: Update transient-feedback tests to the named copy contract**

Change the first test in `CountryMapTransientFeedbackTests.swift` to use resolved titles:

```swift
let locked = CountryMapTransientFeedback.locked(cityTitle: "City 7 · Emberford")
let completed = CountryMapTransientFeedback.completed(cityTitle: "City 12 · Ashbridge")

#expect(locked.text == "City 7 · Emberford is locked")
#expect(completed.text == "City 12 · Ashbridge complete")
```

Update the idle-conquest expectations to:

```swift
#expect(/* pending next city */?.text == "City 4 · Bramblegate")
#expect(/* country complete */?.text == "Country 1 conquered at Crownspire Keep.")
```

Keep existing timing/fade assertions unchanged.

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

Update existing locked/completed scene expectations from bare `City N` copy to the authored display title.

- [ ] **Step 3: Run the Country Map tests and verify they fail**

Run:

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

In `idle(result:state:)`, keep damage/no-damage copy unchanged. Replace only conquest branches:

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

Update `CountryMapScoutCardNode.prepare` to match the new case:

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

Update the existing node test to expect:

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

Replace the current no-op Scout Card body branch:

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

Expected: all three test groups PASS with the existing feedback timing and touch-priority behavior preserved.

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

Update the first report test to:

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

In the existing conquest-report scene coverage, use a City 3 state/result and assert:

```swift
#expect(scene.lastAppliedConquestReportContentForTesting?.title == "Falconridge Silenced")
```

For a final-city report assertion, expect `Crownspire Keep Falls`, not `Country 1 Conquered`; overall Country completion remains a Country Map concern.

If the current DEBUG readback has a different existing name, use that existing readback rather than adding another test-only production API.

- [ ] **Step 3: Run report and Battle tests and verify they fail**

Run:

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

Change the projection signature and title assignment to:

```swift
static func project(
    from result: BattleResult,
    title: String
) -> Self {
    var lines = [
        "Gold earned: +\(CompactNumberFormatter.string(from: result.goldEarned))"
    ]
    // Keep the existing conquest-mode, MVP, deployment/loss, and achievement logic unchanged.
    return Self(title: title, summaryLines: lines, achievements: achievements)
}
```

The implementation should literally remove the old:

```swift
let title = isCountryComplete
    ? "Country \(result.cityKey.countryNumber) Conquered"
    : "\(cityTitle) Conquered"
```

Do not move other report logic into `BattleScene`.

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

Run:

```bash
rg 'cityTitle:|isCountryComplete:|Country 1 Conquered|Country 1 - City [0-9]+ Conquered' Pyxis PyxisTests
```

Expected after updating intended call sites/tests: no stale `ConquestReportContent.project` arguments and no old report-title assertions. Unrelated historical docs are outside this implementation grep.

- [ ] **Step 7: Run report and Battle tests and verify they pass**

Run the Task 4 test command again.

Expected: `ConquestReportContentTests` and `BattleSceneTests` PASS.

- [ ] **Step 8: Commit Task 4**

```bash
git add Pyxis/ConquestReportContent.swift Pyxis/BattleScene.swift PyxisTests/ConquestReportContentTests.swift PyxisTests/BattleSceneTests.swift
git commit -m "feat: use authored conquest titles"
```

---

### Task 5: Lock layout acceptance, update architecture guidance, and run the campaign-facing verification

**Files:**
- Modify: `PyxisTests/CountryMapScoutCardNodeTests.swift`
- Modify: `CLAUDE.md`
- Verify: all production/test files changed in Tasks 1-4

**Interfaces:**
- Consumes: the final 15-city catalog and existing Scout Card layout/fitting path
- Produces: one all-content supported-layout regression guard
- Produces: architecture documentation that declares `Country1CityCatalog` the identity source of truth

- [ ] **Step 1: Add one all-authored-title Scout Card fit test**

In `CountryMapScoutCardNodeTests.swift`, add a single test that checks every authored city against both supported fixture classes:

```swift
@Test func everyAuthoredCountryOneTitleFitsSupportedScoutCardLayouts() throws {
    let phoneLayout = try scoutCardLayout(named: "small phone")
    let padLayout = try scoutCardLayout(named: "narrow iPad")

    for layout in [phoneLayout, padLayout] {
        let node = CountryMapScoutCardNode(imageLoader: { _ in nil })
        for definition in Country1CityCatalog.definitions {
            let content = CountryMapScoutCardContent.scout(.init(
                cityNumber: definition.cityNumber,
                displayTitle: definition.displayTitle,
                flavorText: definition.flavorText,
                defenseTrait: definition.defenseTrait,
                exposedLane: definition.laneDefenseProfile.exposedLane,
                goldReward: KingdomGameState.goldReward(for: definition.cityNumber)
            ))

            #expect(node.apply(
                content: content,
                layout: layout,
                isEntryEnabled: true
            ) == .presented)
        }
    }
}
```

This is the layout acceptance guard. Do not add separate per-city scene tests or another truncation algorithm.

- [ ] **Step 2: Run the Scout Card tests**

Run:

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/CountryMapScoutCardNodeTests
```

Expected: PASS for all 15 titles on phone and pad fixtures. If one fails, shorten the authored copy within the approved limits; do not add a new layout policy.

- [ ] **Step 3: Update `CLAUDE.md` with the identity ownership rule**

In the architecture paragraph that currently explains `Country1CityCatalog`, add concise guidance equivalent to:

```markdown
`Country1CityCatalog` is also the sole source of authored Country 1 identity (`name`, `flavorText`, `conquestTitle`). UI must derive city copy from `CityDefinition`; do not persist copies in campaign/result state or add parallel city-name switches in scenes.
```

Keep this to the existing architecture/conventions section; do not add a new documentation subsystem.

- [ ] **Step 4: Run repository-wide stale-copy searches**

Run:

```bash
rg 'Country 1 - City|City [0-9]+: (Standard Watch|Arrow Tower|Spiked Gate|Stone Wall|Arcane Ward|Burning Oil|Reinforced Keep)' Pyxis PyxisTests
```

Review every hit. Production player-facing copy for valid Country 1 identity should now route through the catalog. Keep the explicit `Country N - City M` fallback implementation and tests.

Then run:

```bash
rg 'Willowford|Pinewatch|Falconridge|Bramblegate|Highcrest|Granite Pass|Emberford|Greywall|Runewatch|Ironthorn Gate|Kingshield Bastion|Ashbridge|Starveil Citadel|Stonecrown|Crownspire Keep' Pyxis
```

Expected: authored names live in `Country1CityCatalog.swift` only; production scenes should not contain parallel name switches or copied city tables.

- [ ] **Step 5: Run the full automated verification with parallel simulator clones disabled**

Run:

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
