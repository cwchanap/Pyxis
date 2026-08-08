# HPA-366 Country 1 City Identity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the reviewed 15-city Country 1 identity set through the current map, battle, building, and conquest surfaces without changing gameplay, persistence, or adding a content framework.

**Architecture:** Extend the existing `CityDefinition` / `Country1CityCatalog` source of truth with three authored strings. Reuse the current title, Scout Card, transient-feedback, Building View, Battle HUD/tooltip, and conquest-report seams. Keep gameplay lookup clamping unchanged, add one optional non-clamping display lookup, and resolve authored copy at presentation time instead of persisting it.

**Tech Stack:** Swift 5, SpriteKit, UIKit, Swift Testing, Xcode/iOS Simulator.

## Global Constraints

- Implement `docs/superpowers/specs/2026-08-08-country-1-city-identity-design.md`.
- Country 1 remains exactly 15 cities.
- `name` <= 18 characters, `flavorText` <= 48, `conquestTitle` <= 24; all are non-empty after trimming.
- Names are unique case-insensitively.
- Preserve every existing defense trait and lane profile exactly.
- Do not change HP, reward, unlock, building, idle, routing, combat, sound, or haptic behavior.
- Do not add persistence fields or modify `BattleResult` / `KingdomGameState` coding keys.
- Do not add a content service, protocol, repository, registry, multi-country abstraction, localization layer, theme metadata, new modal, or HPA-390 milestone effect.
- No new production file is required; do not edit `Pyxis.xcodeproj/project.pbxproj`.
- Final-city product rule: City 15 Battle report = `Crownspire Keep Falls`; country-level `Country 1 conquered …` copy is Country Map-only after Continue.
- Country-complete identity always reads catalog City 15 via `Country1CityCatalog.cityRange.upperBound`; do not derive the final name from `state.cityNumberInCountry` or the optional display fallback.
- Existing fitting behavior is authoritative. Fix authored copy rather than adding another wrapping/truncation policy.
- Unit tests use Swift Testing. Always run simulator tests with `-parallel-testing-enabled NO`.

## Known call-site inventory

Treat this as part of the task scope, not a late discovery list.

Production consumers:
- `Pyxis/KingdomGameState.swift` — display title/conquest title.
- `Pyxis/CountryMapScoutCardContent.swift` — Scout title/flavor projection.
- `Pyxis/CountryMapScoutCardNode.swift` — Scout title, country-complete title, transient overlay.
- `Pyxis/CountryMapTransientFeedback.swift` — locked/completed/idle/final copy.
- `Pyxis/CountryMapScene.swift` — Scout body tap and map feedback call sites.
- `Pyxis/BattleScene.swift` — HUD, tooltip, conquest-report projection.
- `Pyxis/BuildingViewScene.swift` — existing building-driven conquest sentence automatically consumes `state.displayCityTitle`.
- `Pyxis/ConquestReportContent.swift` — caller-owned exact report title.

Known test surfaces whose exact copy/shape must be reconciled in the same slice that changes the producer:
- `PyxisTests/Country1CityCatalogTests.swift`
- `PyxisTests/KingdomGameStateTests.swift`
- `PyxisTests/CountryMapScoutCardContentTests.swift`
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

- [ ] **Step 1: Write failing catalog identity tests**

Extend the independent expected fixture with `name`, `flavorText`, and `conquestTitle`; keep the existing trait/lane values independent from production.

Use this exact authored table:

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

Add:

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

- [ ] **Step 2: Run the focused test and verify RED**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/Country1CityCatalogTests
```

Expected: compile/test failure because identity fields and optional lookup do not exist.

- [ ] **Step 3: Implement the minimal catalog extension**

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

Install the exact table above and add:

```swift
static func definitionIfPresent(for cityNumber: Int) -> CityDefinition? {
    guard cityRange.contains(cityNumber) else { return nil }
    return definitions[cityNumber - cityRange.lowerBound]
}
```

Do not change the current clamped `definition(for:)` implementation.

- [ ] **Step 4: Run GREEN and commit**

Run the Task 1 test command again, then:

```bash
git add Pyxis/CityDefinition.swift Pyxis/Country1CityCatalog.swift PyxisTests/Country1CityCatalogTests.swift
git commit -m "feat: author Country 1 city identities"
```

---

### Task 2: Route shared identity through Scout, Battle, Building View, and conquest report atomically

This task intentionally updates the full known blast radius of the shared title producer. Do not leave Battle/Building exact-string suites for Task 5.

**Files:**
- Modify: `Pyxis/KingdomGameState.swift`
- Modify: `Pyxis/CountryMapScoutCardContent.swift`
- Modify: `Pyxis/ConquestReportContent.swift`
- Modify: `Pyxis/BattleScene.swift`
- Production verification only: `Pyxis/BuildingViewScene.swift` already consumes `state.displayCityTitle`; no code change should be needed.
- Modify: `PyxisTests/KingdomGameStateTests.swift`
- Modify: `PyxisTests/CountryMapScoutCardContentTests.swift`
- Modify: `PyxisTests/CountryMapScoutCardNodeTests.swift` (all direct `Scout` initializers gain `flavorText`)
- Verify: `PyxisTests/CountryMapScoutCardTextLayoutTests.swift`
- Modify: `PyxisTests/ConquestReportContentTests.swift`
- Modify: `PyxisTests/ConquestReportNodeTests.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`
- Modify: `PyxisTests/BuildingViewSceneTests.swift`

**Interfaces:**
- Produces: `KingdomGameState.displayCityTitle(for:)`
- Produces: `KingdomGameState.displayConquestTitle(for:)`
- Produces: `CountryMapScoutCardContent.Scout.flavorText`
- Changes: `ConquestReportContent.project(from:title:)`
- Preserves: current `.countryComplete(countryNumber:)` enum shape in this task; final-city map naming is Task 3.

- [ ] **Step 1: Write/update failing model and Scout projection expectations**

Add:

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

@Test func countryCompleteStateStillUsesAuthoredFinalCityConquestTitle() {
    let state = KingdomGameState(
        cityLevel: 15,
        cityRemainingPower: 0,
        cityNumberInCountry: 15,
        completedCityCount: 15,
        stageStatus: .countryComplete
    )
    #expect(state.displayConquestTitle(for: 15) == "Crownspire Keep Falls")
}
```

Update Scout expectations to include:

```swift
displayTitle: definition.displayTitle,
flavorText: definition.flavorText,
```

and update every direct `CountryMapScoutCardContent.Scout(...)` construction in `CountryMapScoutCardNodeTests.swift` with a `flavorText` value so the test target keeps compiling when the struct shape changes.

- [ ] **Step 2: Update the known shared-title exact-string tests in the same slice**

Before production changes, change the expectations that are guaranteed to move with `displayCityTitle`:

`BattleSceneTests.swift`:

```swift
#expect(scene.cityTitleTextForTesting == "City 3 · Falconridge")
```

Update existing City 1 visible HUD/tooltip expectations from `Country 1 - City 1` to `City 1 · Willowford`.

`BuildingViewSceneTests.swift`:

```swift
#expect(scene.feedbackTextForTesting == "Buildings conquered City 1 · Willowford.")
```

Do not change unrelated unlock copy such as `unlocks at City N`.

- [ ] **Step 3: Update pure report tests and all existing Battle report expectations**

Change every `ConquestReportContent.project` call from `cityTitle:` / `isCountryComplete:` to `title:`. Lock caller ownership:

```swift
@Test func reportUsesCallerProvidedTitleWithoutCampaignFormatting() {
    let content = ConquestReportContent.project(
        from: makeResult(city: 15),
        title: "Crownspire Keep Falls"
    )
    #expect(content.title == "Crownspire Keep Falls")
}
```

In `ConquestReportNodeTests.fullContent()`, use an authored sample:

```swift
title: "Falconridge Silenced"
```

In `BattleSceneTests` update:

```swift
#expect(scene.conquestReportTitleForTesting == "Falconridge Silenced")
```

for the City 3 report path, and update **both** existing country-complete report assertions (`countryCompleteIsAnInertReportHost` and `countryCompleteContinueRoutesToFinalMapOnce`) to:

```swift
#expect(scene.conquestReportTitleForTesting == "Crownspire Keep Falls")
```

This is the product lock: country-level copy must not appear in the Battle report.

- [ ] **Step 4: Run RED across the complete known Task 2 blast radius**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/KingdomGameStateTests \
  -only-testing:PyxisTests/CountryMapScoutCardContentTests \
  -only-testing:PyxisTests/CountryMapScoutCardNodeTests \
  -only-testing:PyxisTests/CountryMapScoutCardTextLayoutTests \
  -only-testing:PyxisTests/ConquestReportContentTests \
  -only-testing:PyxisTests/ConquestReportNodeTests \
  -only-testing:PyxisTests/BattleSceneTests \
  -only-testing:PyxisTests/BuildingViewSceneTests
```

Expected: compile/expectation failures on the new identity/report interfaces.

- [ ] **Step 5: Implement shared display and conquest title helpers**

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

Keep `var displayCityTitle` forwarding to the method.

- [ ] **Step 6: Add Scout flavor to the existing projection without changing country-complete shape yet**

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

Projection uses:

```swift
flavorText: definition.flavorText
```

Keep `.countryComplete(countryNumber:)` unchanged in Task 2 to avoid an unnecessary enum-shape blast; Task 3 can render City 15 identity directly from the shared catalog.

- [ ] **Step 7: Simplify report title ownership in the same atomic slice**

`ConquestReportContent.project` becomes:

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

`BattleScene` resolves the title once:

```swift
private func conquestReportContent(for result: BattleResult) -> ConquestReportContent {
    .project(
        from: result,
        title: state.displayConquestTitle(for: result.cityKey.cityNumber)
    )
}
```

Do not change `BattleResult`, report restoration, effects, Continue ordering, or routing.

- [ ] **Step 8: Run GREEN, including the nominal Scout-title test**

Run the Task 2 test command again.

`CountryMapScoutCardTextLayoutTests.everyTitleAndRewardFitsAtItsNominalSizeInEverySupportedLayout` is the nominal-size acceptance: all 15 authored titles must remain at 11 pt phone / 16 pt pad. Do not replace this with shrink-to-8-only coverage.

- [ ] **Step 9: Search the Task 2 surfaces before committing**

```bash
rg -n 'Country 1 - City|Country 1 Conquered|cityTitle:|isCountryComplete:' \
  PyxisTests/BattleSceneTests.swift \
  PyxisTests/BuildingViewSceneTests.swift \
  PyxisTests/ConquestReportContentTests.swift \
  PyxisTests/ConquestReportNodeTests.swift \
  Pyxis/BattleScene.swift \
  Pyxis/ConquestReportContent.swift
```

Expected: no stale valid-Country-1 player-facing/report expectations remain in these files. Explicit unsupported-value fallback tests are allowed elsewhere.

- [ ] **Step 10: Commit Task 2**

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

### Task 3: Integrate named Country Map feedback, Scout flavor, and final-country copy

**Files:**
- Modify: `Pyxis/CountryMapTransientFeedback.swift`
- Modify: `Pyxis/CountryMapScoutCardNode.swift`
- Modify: `Pyxis/CountryMapScene.swift`
- Modify: `PyxisTests/CountryMapTransientFeedbackTests.swift`
- Modify: `PyxisTests/CountryMapScoutCardNodeTests.swift`
- Modify: `PyxisTests/CountryMapSceneTests.swift`
- Modify: `PyxisTests/CountryMapScoutCardAcceptanceTests.swift`

**Interfaces:**
- Consumes: `CountryMapScoutCardContent.Scout.flavorText`
- Consumes: `KingdomGameState.displayCityTitle(for:)`
- Preserves: `.countryComplete(countryNumber:)`
- Produces: named locked/completed/idle/final copy and non-mutating Scout-body flavor interaction

- [ ] **Step 1: Update feedback copy tests**

Change signatures to resolved titles:

```swift
let locked = CountryMapTransientFeedback.locked(cityTitle: "City 7 · Emberford")
let completed = CountryMapTransientFeedback.completed(cityTitle: "City 12 · Ashbridge")
#expect(locked.text == "City 7 · Emberford is locked")
#expect(completed.text == "City 12 · Ashbridge complete")
```

Idle conquest expectations become:

```swift
#expect(/* next-city idle result */?.text == "City 4 · Bramblegate")
#expect(/* final-country idle result */?.text == "Country 1 conquered at Crownspire Keep.")
```

- [ ] **Step 2: Strengthen the existing feedback-fit test over every authored string**

In `CountryMapScoutCardNodeTests.everyFeedbackCopyFamilyFitsTheActualLabelOnMinimumPhoneAndPad`, build the complete authored message set:

```swift
let authoredMessages = Country1CityCatalog.definitions.flatMap { definition in
    [
        definition.flavorText,
        "\(definition.displayTitle) is locked",
        "\(definition.displayTitle) complete"
    ]
}
let messages = authoredMessages + [
    "Country 1 conquered · Crownspire Keep",
    "Country 1 conquered at Crownspire Keep.",
    "Buildings dealt 999999 idle damage.",
    "No building damage while away.",
    "Cannot enter city yet."
]
```

Keep the existing phone/pad fixture loop and assertions that the installed feedback label fits the overlay with font size >= 8. This protects against `applyFeedback` silently dropping one future authored string.

- [ ] **Step 3: Add the representative Scout-body behavior test and update map acceptance copy**

Add to `CountryMapSceneTests`:

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

Update all locked/completed/idle/final expectations in `CountryMapSceneTests` and `CountryMapScoutCardAcceptanceTests`, including:

```swift
"City 4 · Bramblegate is locked"
"City 2 · Pinewatch complete"
"Country 1 conquered · Crownspire Keep"
```

- [ ] **Step 4: Run RED for the Country Map slice**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/CountryMapTransientFeedbackTests \
  -only-testing:PyxisTests/CountryMapScoutCardNodeTests \
  -only-testing:PyxisTests/CountryMapSceneTests \
  -only-testing:PyxisTests/CountryMapScoutCardAcceptanceTests
```

Expected: copy/behavior failures while old map formatting/no-op body tap remains.

- [ ] **Step 5: Implement resolved locked/completed/idle copy**

```swift
static func locked(cityTitle: String) -> Self {
    .init(kind: .locked, text: "\(cityTitle) is locked", totalDuration: 1.5, fadeDuration: 0.3)
}

static func completed(cityTitle: String) -> Self {
    .init(kind: .completed, text: "\(cityTitle) complete", totalDuration: 1.5, fadeDuration: 0.3)
}
```

In the idle conquest branch:

```swift
if state.stageStatus == .countryComplete {
    let finalCity = Country1CityCatalog.definition(
        for: Country1CityCatalog.cityRange.upperBound
    )
    text = "Country \(state.countryNumber) conquered at \(finalCity.name)."
} else if let cityNumber = state.unlockedMapCityNumber {
    text = state.displayCityTitle(for: cityNumber)
} else {
    assertionFailure("Idle conquest must unlock a city or complete the country")
    return nil
}
```

- [ ] **Step 6: Render final-country identity from constant catalog City 15 without changing the enum shape**

In `CountryMapScoutCardNode.prepare` keep `.countryComplete(let countryNumber)` and derive only presentation copy:

```swift
case .countryComplete(let countryNumber):
    let finalCity = Country1CityCatalog.definition(
        for: Country1CityCatalog.cityRange.upperBound
    )
    let text = "Country \(countryNumber) conquered · \(finalCity.name)"
    guard let fontSize = fittedFontSize(
        text,
        startingAt: metrics.titleSize,
        frameWidth: layout.cardFrame.width
    ) else {
        return nil
    }
    return .countryComplete(text: text, fontSize: fontSize)
```

This is deliberately smaller than adding another associated value to the existing content enum.

- [ ] **Step 7: Wire Scout flavor and named map feedback**

At locked/completed call sites:

```swift
showFeedback(.locked(cityTitle: state.displayCityTitle(for: cityNumber)))
showFeedback(.completed(cityTitle: state.displayCityTitle(for: cityNumber)))
```

Replace the current no-op Scout body branch with:

```swift
if scoutCardNode.cardHitFrame?.contains(point) == true {
    if case .scout(let scout) = CountryMapScoutCardContent.project(from: state) {
        showFeedback(.status(scout.flavorText))
    }
    return
}
```

Keep input priority unchanged so Attack wins before the card body.

- [ ] **Step 8: Run GREEN and commit**

Run the Task 3 command again, then:

```bash
git add Pyxis/CountryMapTransientFeedback.swift Pyxis/CountryMapScoutCardNode.swift \
  Pyxis/CountryMapScene.swift PyxisTests/CountryMapTransientFeedbackTests.swift \
  PyxisTests/CountryMapScoutCardNodeTests.swift PyxisTests/CountryMapSceneTests.swift \
  PyxisTests/CountryMapScoutCardAcceptanceTests.swift
git commit -m "feat: show city identity on country map"
```

---

### Task 4: Lock cross-surface fit/copy acceptance and remove stale hard-coded Country 1 copy

**Files:**
- Verify: `PyxisTests/CountryMapScoutCardTextLayoutTests.swift`
- Verify/modify only if needed: `PyxisTests/CountryMapScoutCardNodeTests.swift`
- Verify/modify only if needed: all test files in the call-site inventory

- [ ] **Step 1: Run the stronger nominal Scout-title test explicitly**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/CountryMapScoutCardTextLayoutTests/everyTitleAndRewardFitsAtItsNominalSizeInEverySupportedLayout
```

Expected: PASS with every authored title retaining nominal 11/16 pt size. If a title fails, shorten the authored copy; do not rely on shrinking to 8 pt.

- [ ] **Step 2: Keep the existing all-content presentation matrix as the second fit gate**

Ensure `allCurrentContentPresentsAcrossEveryFixtureAndImageOutcome` constructs Scout data with both authored fields:

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

Run:

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/CountryMapScoutCardNodeTests/allCurrentContentPresentsAcrossEveryFixtureAndImageOutcome \
  -only-testing:PyxisTests/CountryMapScoutCardNodeTests/everyFeedbackCopyFamilyFitsTheActualLabelOnMinimumPhoneAndPad
```

Expected: PASS across authored titles, every authored transient family, supported fixtures, and image outcomes.

- [ ] **Step 3: Run repository-wide stale-copy searches and classify every hit**

```bash
rg -n 'Country 1 - City|Country 1 Conquered|City [0-9]+: (Standard Watch|Arrow Tower|Spiked Gate|Stone Wall|Arcane Ward|Burning Oil|Reinforced Keep)' Pyxis PyxisTests
```

Allowed hits:
- the explicit fallback implementation;
- tests whose purpose is unsupported-country/city fallback.

All other valid Country 1 player-facing exact copy must use the catalog-backed expectations.

Also verify authored names are not duplicated in production:

```bash
rg -n 'Willowford|Pinewatch|Falconridge|Bramblegate|Highcrest|Granite Pass|Emberford|Greywall|Runewatch|Ironthorn Gate|Kingshield Bastion|Ashbridge|Starveil Citadel|Stonecrown|Crownspire Keep' Pyxis
```

Expected: authored names appear in production only in `Country1CityCatalog.swift`; scenes contain no parallel name table/switch.

- [ ] **Step 4: Commit only if the acceptance sweep required test cleanup**

If Step 3 found stale test expectations, stage only those test files and commit:

```bash
git commit -m "test: align Country 1 identity acceptance"
```

If no files changed, do not create an empty commit.

---

### Task 5: Update architecture guidance and run final campaign verification

**Files:**
- Modify: `CLAUDE.md`
- Verify: all Task 1-4 production/test files

- [ ] **Step 1: Document identity ownership**

Add to the existing `Country1CityCatalog` architecture/conventions material:

```markdown
`Country1CityCatalog` is the sole source of authored Country 1 identity (`name`, `flavorText`, `conquestTitle`). UI derives copy from `CityDefinition`; do not persist identity copies in campaign/result state or add parallel city-name switches in scenes. Country-complete copy resolves the final identity from catalog City 15 (`cityRange.upperBound`).
```

- [ ] **Step 2: Run full automated verification**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO
swiftlint lint --no-cache
git diff --check origin/main...HEAD
```

Expected: full unit/UI suite PASS, SwiftLint exits 0 with no new serious finding, and `git diff --check` is clean.

- [ ] **Step 3: Run the City 1→15 identity smoke**

For every city 1 through 15 verify:

1. Scout Card shows `City N · Name`.
2. Scout body tap shows the exact reviewed flavor text.
3. Battle HUD and city tooltip use the same title.
4. Building View conquest feedback, when applicable, uses the same title.
5. Battle conquest report uses the reviewed authored conquest title.
6. Locked/completed/idle Country Map feedback uses the same identity.
7. City 15 Battle report says `Crownspire Keep Falls`.
8. Only after Continue does the Country Map show `Country 1 conquered · Crownspire Keep`.
9. No trait, lane, reward, building, routing, SFX, haptic, or combat behavior differs from `main`.

If any copy fails current fit rules, shorten the authored string. Do not create a new layout/content framework.

- [ ] **Step 4: Commit Task 5**

```bash
git add CLAUDE.md
git commit -m "docs: record Country 1 identity ownership"
```

---

## Risks and controls

- **Final-city semantics drift:** lock `displayConquestTitle(for: 15)` under `.countryComplete` plus both existing final Battle report assertions.
- **Silent transient feedback drop:** enumerate all 15 flavor/locked/completed strings through the existing minimum-phone/pad feedback-fit test.
- **Stale exact-string tests:** update the known call-site inventory in the same producer-changing task; final `rg` is a backstop, not the primary discovery mechanism.
- **Overbuilding fit handling:** keep current nominal/fitted tests and shorten copy if needed; add no second layout policy.

## Final scope check

- New production files: 0.
- Persistence schema changes: 0.
- New gameplay systems/mechanics: 0.
- New UI surfaces: 0.
- Authored rows: exactly 15.
- Country-complete content enum shape: unchanged.

If implementation starts introducing a reusable content platform, multi-country abstraction, persistence migration, new modal, or milestone effect, stop and reduce scope back to this plan.
