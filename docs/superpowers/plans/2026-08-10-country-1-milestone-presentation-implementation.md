# HPA-390 Country 1 Milestone Presentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Cities 5, 10, and 15 feel like escalating Country 1 milestones through lightweight BattleScene presentation only, while preserving all existing combat, rewards, persistence, progression, routing, and conquest-report semantics.

**Architecture:** Add one framework-free `Country1MilestonePresentation` selector that maps only City 5/10/15 to three fixed tiers. `BattleScene` remains the sole runtime owner of the arrival banner, enemy-city accent, fresh-conquest flourish, same-scene dedupe state, and City 15 `Country 1 Complete` label. Authored strings continue to come from `CityDefinition`, and conquest presentation continues to use the existing `.freshLive` / `.freshIdle` / `.restored` boundary.

**Tech Stack:** Swift 5, SpriteKit, UIKit (`UIAccessibility.isReduceMotionEnabled` only), Swift Testing, Xcode/iOS Simulator.

## Global Constraints

- HPA-390 is presentation-only. Do not change combat rules, HP, rewards, unlocks, traits, lanes, buildings, idle progress, or campaign progression.
- Only Country 1 Cities 5, 10, and 15 receive milestone treatment.
- City 5 is tier 1, City 10 is tier 2, and City 15 is tier 3/finale.
- `Country1CityCatalog` / `CityDefinition` remain the sole source of city name, flavor text, and conquest title.
- Arrival title is `CityDefinition.displayTitle`; arrival subtitle is `CityDefinition.flavorText`.
- Existing conquest title remains authoritative. City 15 keeps `Crownspire Keep Falls`; add only the separate literal `Country 1 Complete` state.
- HPA-390 intentionally supersedes only HPA-366's earlier presentation rule that country completion appears exclusively on the map after Continue. The acknowledgement/save/map-routing transaction is unchanged.
- Arrival presentation is non-modal: combat simulation continues while it is visible.
- A tap while arrival is visible dismisses it and is fully consumed before Settings or normal battle controls.
- Arrival auto-dismiss target is 1.5 seconds.
- Resize/redraw/layout refresh may reposition current milestone nodes but must not restart one-shot presentation.
- Fresh `.freshLive` and `.freshIdle` milestone reports receive one flourish; `.restored` reports never replay that one-shot flourish.
- City 15 `Country 1 Complete` is semantic report state and therefore remains visible on restored pending reports.
- Read Reduce Motion directly from `UIAccessibility.isReduceMotionEnabled`; do not add a persisted setting, protocol, manager, or dependency seam.
- No new gameplay SFX/haptic event, sound asset, image asset, milestone engine, presentation service, registry, reusable node framework, or generic theme model.
- No persisted milestone-consumption token in `KingdomGameState`, `BattleResult`, `CityDefinition`, or `UserDefaults`.
- Keep the existing `ConquestReportContent`, `ConquestReportLayout`, `ConquestReportNode`, Continue transaction, and report fit-failure authority intact.
- No `project.pbxproj` edits; the repository uses `PBXFileSystemSynchronizedRootGroup`.
- New production files: exactly one (`Pyxis/Country1MilestonePresentation.swift`). All SpriteKit behavior stays in `BattleScene.swift`.
- Run simulator tests with `-parallel-testing-enabled NO`.

## File Structure

- `Pyxis/Country1MilestonePresentation.swift` — pure City 5/10/15 selection only; no UIKit/SpriteKit, strings, colors, durations, or persistence.
- `Pyxis/BattleScene.swift` — owns all milestone nodes, fixed style constants, layout, input precedence, arrival lifetime, Reduce Motion branching, conquest flourish, and same-scene dedupe.
- `PyxisTests/Country1MilestonePresentationTests.swift` — focused pure selector contract.
- `PyxisTests/BattleSceneTests.swift` — behavior-oriented integration checks for arrival copy/input/dedupe, city accent, fresh/restored conquest behavior, City 15 completion state, layout containment, and Continue routing.
- `CLAUDE.md` — records milestone ownership and the no-persistence/no-framework boundary so later work does not move presentation policy into shared campaign models.

---

### Task 1: Add the pure milestone selector

**Files:**
- Create: `Pyxis/Country1MilestonePresentation.swift`
- Create: `PyxisTests/Country1MilestonePresentationTests.swift`

**Interfaces:**
- Produces: `Country1MilestonePresentation.make(forCityNumber: Int) -> Country1MilestonePresentation?`
- Produces: `Country1MilestonePresentation.Tier` with `.first`, `.second`, `.finale`.
- Produces: `Country1MilestonePresentation.isCountryFinale: Bool`.
- Consumes: integer city number only. This file must not import SpriteKit/UIKit or read `KingdomGameState`.

- [ ] **Step 1: Write the failing selector tests**

Create `PyxisTests/Country1MilestonePresentationTests.swift`:

```swift
import Testing
@testable import Pyxis

struct Country1MilestonePresentationTests {
    @Test("Only Cities 5, 10, and 15 are milestones")
    func selectsOnlyCountry1Milestones() {
        #expect(Country1MilestonePresentation.make(forCityNumber: 5)?.tier == .first)
        #expect(Country1MilestonePresentation.make(forCityNumber: 10)?.tier == .second)
        #expect(Country1MilestonePresentation.make(forCityNumber: 15)?.tier == .finale)

        for city in [1, 4, 6, 9, 11, 14] {
            #expect(Country1MilestonePresentation.make(forCityNumber: city) == nil)
        }
    }

    @Test("Only the finale tier is country completion")
    func finaleMarksCountryCompletion() {
        #expect(Country1MilestonePresentation.make(forCityNumber: 5)?.isCountryFinale == false)
        #expect(Country1MilestonePresentation.make(forCityNumber: 10)?.isCountryFinale == false)
        #expect(Country1MilestonePresentation.make(forCityNumber: 15)?.isCountryFinale == true)
    }

    @Test("Selection is deterministic")
    func selectionIsDeterministic() {
        #expect(
            Country1MilestonePresentation.make(forCityNumber: 10)
                == Country1MilestonePresentation.make(forCityNumber: 10)
        )
    }
}
```

- [ ] **Step 2: Run the new suite and confirm RED**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/Country1MilestonePresentationTests
```

Expected: FAIL because `Country1MilestonePresentation` does not exist.

- [ ] **Step 3: Implement the minimal framework-free value**

Create `Pyxis/Country1MilestonePresentation.swift`:

```swift
struct Country1MilestonePresentation: Equatable {
    enum Tier: Int, Equatable {
        case first = 1
        case second = 2
        case finale = 3
    }

    let tier: Tier

    var isCountryFinale: Bool {
        tier == .finale
    }

    static func make(forCityNumber cityNumber: Int) -> Country1MilestonePresentation? {
        switch cityNumber {
        case 5:
            return Country1MilestonePresentation(tier: .first)
        case 10:
            return Country1MilestonePresentation(tier: .second)
        case 15:
            return Country1MilestonePresentation(tier: .finale)
        default:
            return nil
        }
    }
}
```

Do not add city strings, effect constants, colors, protocols, or a country parameter. HPA-390 has exactly one Country 1 consumer.

- [ ] **Step 4: Run the selector suite and confirm GREEN**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/Country1MilestonePresentationTests
```

Expected: PASS.

- [ ] **Step 5: Commit the selector slice**

```bash
git add Pyxis/Country1MilestonePresentation.swift PyxisTests/Country1MilestonePresentationTests.swift
git commit -m "feat: add Country 1 milestone selector"
```

---

### Task 2: Add the arrival banner and enemy-city accent

**Files:**
- Modify: `Pyxis/BattleScene.swift` — scene state/nodes, `didMove(to:)`, `handleTouch(at:)`, `buildInterface()`, `layoutInterface()`, `layoutBattlefield(...)`, DEBUG accessors.
- Modify: `PyxisTests/BattleSceneTests.swift` — milestone active-state helper and arrival/accent behavior tests.

**Interfaces:**
- Consumes: `Country1MilestonePresentation.make(forCityNumber:)` from Task 1.
- Consumes: `Country1CityCatalog.definitionIfPresent(for:)` for authored arrival text.
- Produces internally: `presentMilestoneArrivalIfNeeded()`, `dismissMilestoneArrival()`, `layoutMilestoneArrival()`, `layoutMilestoneCityAccent()`.
- Produces DEBUG semantics: milestone tier, arrival title/subtitle, visible state, presentation count, arrival frame, city-accent frame.

- [ ] **Step 1: Add a normalized active-milestone fixture and RED arrival-copy test**

In `BattleSceneTests`, add a helper that obeys `KingdomGameState` progression normalization:

```swift
private func activeMilestoneState(city: Int, gold: Int = 100) -> KingdomGameState {
    KingdomGameState(
        gold: gold,
        cityLevel: city,
        cityNumberInCountry: city,
        completedCityCount: city - 1,
        stageStatus: .battleActive
    )
}
```

Then add:

```swift
@Test("City 5 presents authored milestone arrival and an enemy-city accent")
func city5PresentsMilestoneArrival() throws {
    let store = try makeStore(initialState: activeMilestoneState(city: 5))
    let scene = makeScene(store: store)

    #expect(scene.milestoneTierForTesting == 1)
    #expect(scene.isMilestoneArrivalVisibleForTesting)
    #expect(scene.milestoneArrivalPresentationCountForTesting == 1)
    #expect(scene.milestoneArrivalTitleForTesting == "City 5 · Highcrest")
    #expect(scene.milestoneArrivalSubtitleForTesting == "A proud hill fortress crowns the frontier.")
    #expect(scene.milestoneArrivalFrameForTesting != nil)
    #expect(scene.milestoneCityAccentFrameForTesting != nil)
}
```

Also add an ordinary-city negative case:

```swift
@Test("Ordinary cities have no milestone arrival or accent")
func ordinaryCityHasNoMilestonePresentation() throws {
    let store = try makeStore(initialState: KingdomGameState(
        cityLevel: 6,
        cityNumberInCountry: 6,
        completedCityCount: 5
    ))
    let scene = makeScene(store: store)

    #expect(scene.milestoneTierForTesting == nil)
    #expect(!scene.isMilestoneArrivalVisibleForTesting)
    #expect(scene.milestoneArrivalPresentationCountForTesting == 0)
    #expect(scene.milestoneCityAccentFrameForTesting == nil)
}
```

- [ ] **Step 2: Add RED input-precedence and no-replay tests**

Use the existing real Settings hit frame to prove a skip tap cannot fall through:

```swift
@Test("Milestone arrival consumes the tap before Settings")
func milestoneArrivalConsumesUnderlyingTap() throws {
    let store = try makeStore(initialState: activeMilestoneState(city: 5))
    let scene = makeScene(store: store)
    let gearFrame = try #require(scene.feedbackSettingsGearFrameForTesting)

    scene.handleTouchForTesting(at: gearFrame.center)

    #expect(!scene.isMilestoneArrivalVisibleForTesting)
    #expect(!scene.isFeedbackSettingsVisibleForTesting)

    scene.handleTouchForTesting(at: gearFrame.center)
    #expect(scene.isFeedbackSettingsVisibleForTesting)
}

@Test("Milestone arrival is not replayed by layout refresh")
func milestoneArrivalDoesNotReplayOnLayoutRefresh() throws {
    let store = try makeStore(initialState: activeMilestoneState(city: 10))
    let scene = makeScene(store: store)
    let count = scene.milestoneArrivalPresentationCountForTesting

    scene.refreshLayoutForCurrentEnvironment()
    scene.redrawForTesting(shouldLayout: true)
    scene.repeatDidMoveForTesting()

    #expect(scene.milestoneArrivalPresentationCountForTesting == count)
}
```

The `repeatDidMoveForTesting()` assertion intentionally locks same-scene dedupe without requiring durable persistence.

- [ ] **Step 3: Run the focused BattleScene tests and confirm RED**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/BattleSceneTests/city5PresentsMilestoneArrival \
  -only-testing:PyxisTests/BattleSceneTests/ordinaryCityHasNoMilestonePresentation \
  -only-testing:PyxisTests/BattleSceneTests/milestoneArrivalConsumesUnderlyingTap \
  -only-testing:PyxisTests/BattleSceneTests/milestoneArrivalDoesNotReplayOnLayoutRefresh
```

Expected: FAIL because the milestone BattleScene surface does not exist.

- [ ] **Step 4: Add scene-owned milestone state and nodes**

In `BattleScene`, add fixed local constants and state near the existing effect/presentation state:

```swift
private enum MilestoneStyle {
    static let arrivalDuration: TimeInterval = 1.5
    static let arrivalFadeDuration: TimeInterval = 0.18
    static let arrivalActionKey = "milestoneArrival"
    static let arrivalZ = GameUITheme.Z.modal - 5
    static let cityAccentZ: CGFloat = 3
}

private let milestoneArrivalNode = SKNode()
private let milestoneArrivalPanel = SKShapeNode()
private let milestoneArrivalTitleLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
private let milestoneArrivalSubtitleLabel = SKLabelNode(fontNamed: GameUITheme.Font.medium)
private let milestoneCityAccent = SKShapeNode()
private var hasPresentedMilestoneArrival = false
private var isMilestoneArrivalVisible = false
#if DEBUG
private var milestoneArrivalPresentationCountForTestingStorage = 0
#endif

private var currentMilestonePresentation: Country1MilestonePresentation? {
    Country1MilestonePresentation.make(forCityNumber: state.currentCityKey.cityNumber)
}
```

Use current state only to select tier. Do not cache city strings or add fields to `KingdomGameState`.

- [ ] **Step 5: Configure the nodes once in `buildInterface()`**

Add one scene-owned banner tree and one environment-layer accent. Keep both hidden until selected:

```swift
private func configureMilestonePresentationNodes() {
    milestoneArrivalNode.zPosition = MilestoneStyle.arrivalZ
    milestoneArrivalNode.isHidden = true

    milestoneArrivalPanel.fillColor = GameUITheme.Color.panelFill
    milestoneArrivalPanel.strokeColor = GameUITheme.Color.gold
    milestoneArrivalPanel.lineWidth = 2
    milestoneArrivalNode.addChild(milestoneArrivalPanel)

    milestoneArrivalTitleLabel.fontColor = GameUITheme.Color.textPrimary
    milestoneArrivalTitleLabel.horizontalAlignmentMode = .center
    milestoneArrivalTitleLabel.verticalAlignmentMode = .center
    milestoneArrivalNode.addChild(milestoneArrivalTitleLabel)

    milestoneArrivalSubtitleLabel.fontColor = GameUITheme.Color.textSecondary
    milestoneArrivalSubtitleLabel.horizontalAlignmentMode = .center
    milestoneArrivalSubtitleLabel.verticalAlignmentMode = .center
    milestoneArrivalNode.addChild(milestoneArrivalSubtitleLabel)

    milestoneCityAccent.fillColor = .clear
    milestoneCityAccent.strokeColor = GameUITheme.Color.gold
    milestoneCityAccent.zPosition = MilestoneStyle.cityAccentZ
    milestoneCityAccent.isHidden = true

    addChild(milestoneArrivalNode)
    environmentLayer.addChild(milestoneCityAccent)
}
```

Call `configureMilestonePresentationNodes()` once from `buildInterface()` after the battlefield layers/nodes exist. Do not create a `MilestoneNode` type.

- [ ] **Step 6: Implement fixed tier styling without a theme model**

Use one switch in BattleScene for the small number of visual strengths:

```swift
private func applyMilestoneTierStyle(_ presentation: Country1MilestonePresentation) {
    switch presentation.tier {
    case .first:
        milestoneArrivalPanel.lineWidth = 2
        milestoneCityAccent.lineWidth = 2
        milestoneCityAccent.glowWidth = 1
        milestoneCityAccent.alpha = 0.60
    case .second:
        milestoneArrivalPanel.lineWidth = 3
        milestoneCityAccent.lineWidth = 3
        milestoneCityAccent.glowWidth = 3
        milestoneCityAccent.alpha = 0.78
    case .finale:
        milestoneArrivalPanel.lineWidth = 4
        milestoneCityAccent.lineWidth = 4
        milestoneCityAccent.glowWidth = 5
        milestoneCityAccent.alpha = 0.95
    }
}
```

These constants are private presentation details. Tests assert tier selection and layout/behavior, not exact stroke/glow values.

- [ ] **Step 7: Implement authored arrival copy, layout, and 1.5-second lifetime**

Resolve text from the catalog at presentation time:

```swift
private func presentMilestoneArrivalIfNeeded() {
    guard !hasPresentedMilestoneArrival,
          state.stageStatus == .battleActive,
          state.pendingBattleResult == nil,
          let presentation = currentMilestonePresentation,
          let definition = Country1CityCatalog.definitionIfPresent(
              for: state.currentCityKey.cityNumber
          ) else {
        return
    }

    hasPresentedMilestoneArrival = true
    isMilestoneArrivalVisible = true
    #if DEBUG
    milestoneArrivalPresentationCountForTestingStorage += 1
    #endif

    milestoneArrivalTitleLabel.text = definition.displayTitle
    milestoneArrivalSubtitleLabel.text = definition.flavorText
    applyMilestoneTierStyle(presentation)
    layoutMilestoneArrival()

    milestoneArrivalNode.removeAction(forKey: MilestoneStyle.arrivalActionKey)
    milestoneArrivalNode.isHidden = false
    milestoneArrivalNode.alpha = UIAccessibility.isReduceMotionEnabled ? 0 : 0.25
    milestoneArrivalNode.setScale(UIAccessibility.isReduceMotionEnabled ? 1 : 0.96)

    let appear = SKAction.group([
        SKAction.fadeAlpha(to: 1, duration: MilestoneStyle.arrivalFadeDuration),
        SKAction.scale(to: 1, duration: MilestoneStyle.arrivalFadeDuration)
    ])
    let wait = SKAction.wait(forDuration: MilestoneStyle.arrivalDuration)
    let finish = SKAction.run { [weak self] in
        self?.dismissMilestoneArrival()
    }
    milestoneArrivalNode.run(
        SKAction.sequence([appear, wait, finish]),
        withKey: MilestoneStyle.arrivalActionKey
    )
}

private func dismissMilestoneArrival() {
    guard isMilestoneArrivalVisible else { return }
    milestoneArrivalNode.removeAction(forKey: MilestoneStyle.arrivalActionKey)
    milestoneArrivalNode.isHidden = true
    milestoneArrivalNode.alpha = 1
    milestoneArrivalNode.setScale(1)
    isMilestoneArrivalVisible = false
}
```

The reduced-motion path uses no scale delta because the starting scale is `1`. The shared fade remains acceptable under the spec.

- [ ] **Step 8: Lay out the arrival banner inside the current safe/content width**

Keep geometry in BattleScene; do not create a pure layout type for one banner:

```swift
private func layoutMilestoneArrival() {
    guard isMilestoneArrivalVisible || hasPresentedMilestoneArrival else { return }

    let metrics = layoutMetrics()
    let insets = view?.safeAreaInsets ?? .zero
    let availableWidth = max(0, size.width - insets.left - insets.right - 24)
    let width = min(metrics.contentWidth, availableWidth)
    let height: CGFloat = metrics.compactHeight ? 64 : 76
    guard width >= 120, height > 0 else { return }

    let safeMinY = insets.bottom + 12
    let safeMaxY = size.height - insets.top - 12
    let desiredCenterY = battlefieldLayout.isVisible
        ? battlefieldLayout.frame.midY
        : (safeMinY + safeMaxY) / 2
    let centerY = min(max(desiredCenterY, safeMinY + height / 2), safeMaxY - height / 2)
    let frame = CGRect(
        x: size.width / 2 - width / 2,
        y: centerY - height / 2,
        width: width,
        height: height
    )

    milestoneArrivalPanel.path = CGPath(
        roundedRect: frame,
        cornerWidth: 14,
        cornerHeight: 14,
        transform: nil
    )
    milestoneArrivalTitleLabel.fontSize = metrics.compactHeight ? 17 : 20
    milestoneArrivalSubtitleLabel.fontSize = metrics.compactHeight ? 12 : 14
    milestoneArrivalTitleLabel.position = CGPoint(x: frame.midX, y: frame.midY + height * 0.18)
    milestoneArrivalSubtitleLabel.position = CGPoint(x: frame.midX, y: frame.midY - height * 0.18)
    fitLabel(milestoneArrivalTitleLabel, maxWidth: frame.width - 24)
    fitLabel(milestoneArrivalSubtitleLabel, maxWidth: frame.width - 24)
}
```

Current authored strings are short enough for supported layouts; Task 3 adds a compact-layout assertion so required milestone text cannot silently clip.

- [ ] **Step 9: Layout the city accent from the real rendered enemy-city frame**

At the tail of `layoutBattlefield(...)`, after `enemyCityNode` is fitted/positioned and `layoutCityHPBar()` runs, call:

```swift
private func layoutMilestoneCityAccent() {
    guard let presentation = currentMilestonePresentation,
          battlefieldLayout.isVisible,
          let enemyCityNode else {
        milestoneCityAccent.isHidden = true
        milestoneCityAccent.path = nil
        return
    }

    applyMilestoneTierStyle(presentation)
    let cityFrame = enemyCityNode.calculateAccumulatedFrame()
    let inset: CGFloat
    switch presentation.tier {
    case .first: inset = 5
    case .second: inset = 7
    case .finale: inset = 9
    }
    milestoneCityAccent.path = CGPath(
        roundedRect: cityFrame.insetBy(dx: -inset, dy: -inset),
        cornerWidth: 12,
        cornerHeight: 12,
        transform: nil
    )
    milestoneCityAccent.isHidden = false
}
```

Do not change `enemyCityNode.position`, `enemyCityNode` scale, battlefield gate points, HP-bar geometry, or hit routing.

- [ ] **Step 10: Wire lifecycle and input precedence**

In `didMove(to:)`, preserve pending-report authority:

```swift
redraw()

if state.pendingBattleResult != nil, !hasPresentedPendingConquestReport {
    _ = presentPendingConquestReport(origin: .restored, resetsContinueState: true)
} else {
    presentMilestoneArrivalIfNeeded()
}
```

In `handleTouch(at:)`, insert the milestone gate immediately after conquest report/fit-failure handling and before Settings:

```swift
if isMilestoneArrivalVisible {
    dismissMilestoneArrival()
    return
}
```

At the end of `layoutInterface()`, call `layoutMilestoneArrival()` so resize moves the existing banner without calling `presentMilestoneArrivalIfNeeded()` and without restarting its action.

- [ ] **Step 11: Add only semantic DEBUG accessors**

Expose:

```swift
var milestoneTierForTesting: Int? {
    currentMilestonePresentation?.tier.rawValue
}

var isMilestoneArrivalVisibleForTesting: Bool {
    isMilestoneArrivalVisible
}

var milestoneArrivalPresentationCountForTesting: Int {
    milestoneArrivalPresentationCountForTestingStorage
}

var milestoneArrivalTitleForTesting: String? {
    milestoneArrivalTitleLabel.text
}

var milestoneArrivalSubtitleForTesting: String? {
    milestoneArrivalSubtitleLabel.text
}

var milestoneArrivalFrameForTesting: CGRect? {
    milestoneArrivalNode.isHidden ? nil : sceneFrame(for: milestoneArrivalPanel)
}

var milestoneCityAccentFrameForTesting: CGRect? {
    milestoneCityAccent.isHidden ? nil : sceneFrame(for: milestoneCityAccent)
}
```

Do not expose stroke/glow constants or private node-tree structure.

- [ ] **Step 12: Run the focused BattleScene tests and confirm GREEN**

Run the same four `-only-testing` selectors from Step 3.

Expected: PASS.

- [ ] **Step 13: Run the full BattleScene suite for regression**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/BattleSceneTests
```

Expected: PASS, including existing Settings precedence, report restoration, layout, combat, and routing tests.

- [ ] **Step 14: Commit the arrival/accent slice**

```bash
git add Pyxis/BattleScene.swift PyxisTests/BattleSceneTests.swift
git commit -m "feat: add milestone arrival presentation"
```

---

### Task 3: Add fresh-only conquest flourish and City 15 completion state

**Files:**
- Modify: `Pyxis/BattleScene.swift` — report accent/finale nodes, `applyPendingConquestReport`, `presentPendingConquestReport`, report layout application, DEBUG accessors.
- Modify: `PyxisTests/BattleSceneTests.swift` — fresh/restored milestone report tests, City 15 semantic state, compact layout, Continue route.

**Interfaces:**
- Consumes: `BattleResult.cityKey` as report identity authority.
- Consumes: existing `ConquestReportLayout.safeFrame`, `.panelFrame`, `.continueFrame`.
- Produces internally: `applyMilestoneConquestPresentation(result:layout:)`, `presentFreshMilestoneConquestFlourishIfNeeded(origin:)`, `countryCompleteFrame(for:)`.
- Produces DEBUG semantics: flourish count, report-accent frame, `Country 1 Complete` text/frame.

- [ ] **Step 1: Write RED fresh/restored flourish tests using existing conquest fixtures**

Extend the current fresh/restored tests rather than inventing another conquest harness:

```swift
@Test("Fresh City 5 conquest presents milestone flourish once")
func freshCity5ConquestPresentsMilestoneFlourishOnce() throws {
    var state = activeMilestoneState(city: 5)
    let key = CityKey(countryNumber: 1, cityNumber: 5)
    state = KingdomGameState(
        gold: state.gold,
        cityLevel: 5,
        cityRemainingPower: 1,
        cityNumberInCountry: 5,
        completedCityCount: 4,
        cityBattleStates: [
            key.storageKey: CityBattleState(
                slots: [1: CityBuilding(type: .barracks, level: 6)]
            )
        ]
    )
    let scene = makeScene(store: try makeStore(initialState: state))

    scene.handleTouchForTesting(at: .zero) // consume the arrival banner only
    scene.spawnSoldierForTesting()
    scene.advanceCombatForTesting(deltaTime: 3)

    #expect(scene.lastConquestReportOriginForTesting == "freshLive")
    #expect(scene.milestoneConquestFlourishCountForTesting == 1)
    #expect(scene.milestoneConquestAccentFrameForTesting != nil)

    let count = scene.milestoneConquestFlourishCountForTesting
    scene.redrawForTesting(shouldLayout: true)
    scene.refreshLayoutForCurrentEnvironment()
    #expect(scene.milestoneConquestFlourishCountForTesting == count)
}

@Test("Restored City 10 report keeps static treatment without replaying flourish")
func restoredCity10ReportDoesNotReplayMilestoneFlourish() throws {
    let scene = makeScene(
        store: try makeStore(initialState: pendingConqueredState(city: 10, mode: .live))
    )

    #expect(scene.lastConquestReportOriginForTesting == "restored")
    #expect(scene.milestoneConquestFlourishCountForTesting == 0)
    #expect(scene.milestoneConquestAccentFrameForTesting != nil)
    #expect(!scene.isMilestoneArrivalVisibleForTesting)
}
```

The City 5 fixture intentionally uses an existing high-level Barracks to survive the authored city defenses long enough to produce a deterministic live conquest.

- [ ] **Step 2: Add RED City 15 semantic-state and Continue assertions**

Augment the existing `countryCompleteContinueRoutesToFinalMapOnce` test:

```swift
#expect(scene.conquestReportTitleForTesting == "Crownspire Keep Falls")
#expect(scene.countryCompleteTextForTesting == "Country 1 Complete")
let countryCompleteFrame = try #require(scene.countryCompleteFrameForTesting)
let continueFrame = try #require(scene.popupContinueButtonFrameForTesting)
#expect(!countryCompleteFrame.intersects(continueFrame))
#expect(scene.milestoneConquestFlourishCountForTesting == 0) // restored report
```

Keep the existing two Continue taps and assertions:

```swift
scene.tapConquestContinueForTesting()
scene.tapConquestContinueForTesting()
#expect(router.countryMapRequestCount == 1)
#expect(store.load().pendingBattleResult == nil)
```

This proves HPA-390 adds presentation without a second completion transaction.

- [ ] **Step 3: Add RED compact-layout containment coverage**

Use both existing landscape gates in one test, with a restored City 15 report so the semantic state is immediately available and deterministic:

```swift
@Test("City 15 milestone report treatment fits supported landscape gates")
func city15MilestoneReportFitsLandscapeGates() throws {
    for size in [
        CGSize(width: 568, height: 320),
        CGSize(width: 667, height: 375)
    ] {
        let scene = makeScene(
            store: try makeStore(initialState: pendingConqueredState(
                city: 15,
                mode: .idle,
                countryComplete: true
            )),
            size: size
        )
        let safeFrame = try #require(scene.lastConquestReportLayoutForTesting?.safeFrame)
        let reportFrame = try #require(scene.lastConquestReportLayoutForTesting?.panelFrame)
        let accentFrame = try #require(scene.milestoneConquestAccentFrameForTesting)
        let finalFrame = try #require(scene.countryCompleteFrameForTesting)
        let continueFrame = try #require(scene.popupContinueButtonFrameForTesting)

        #expect(safeFrame.contains(accentFrame))
        #expect(safeFrame.contains(finalFrame))
        #expect(!finalFrame.intersects(reportFrame))
        #expect(!finalFrame.intersects(continueFrame))
        #expect(!scene.isConquestReportFitFailedForTesting)
    }
}
```

Add `lastConquestReportLayoutForTesting` as a DEBUG accessor that recomputes from `lastAppliedConquestReportContent` through the existing `conquestReportLayout(for:)`; do not expose or persist a second layout object in production solely for this test.

- [ ] **Step 4: Run the new report tests and confirm RED**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/BattleSceneTests/freshCity5ConquestPresentsMilestoneFlourishOnce \
  -only-testing:PyxisTests/BattleSceneTests/restoredCity10ReportDoesNotReplayMilestoneFlourish \
  -only-testing:PyxisTests/BattleSceneTests/countryCompleteContinueRoutesToFinalMapOnce \
  -only-testing:PyxisTests/BattleSceneTests/city15MilestoneReportFitsLandscapeGates
```

Expected: FAIL because report milestone presentation does not exist.

- [ ] **Step 5: Add the scene-owned report accent/finale nodes and dedupe state**

Near the existing conquest report fields:

```swift
private let milestoneConquestAccent = SKShapeNode()
private let countryCompleteLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
private var hasPresentedMilestoneConquestFlourish = false
#if DEBUG
private var milestoneConquestFlourishCountForTestingStorage = 0
#endif
```

Configure once in `buildInterface()` after `conquestReportNode`:

```swift
milestoneConquestAccent.fillColor = .clear
milestoneConquestAccent.strokeColor = GameUITheme.Color.gold
milestoneConquestAccent.zPosition = GameUITheme.Z.modal - 0.25
milestoneConquestAccent.isHidden = true
addChild(milestoneConquestAccent)

countryCompleteLabel.text = "Country 1 Complete"
countryCompleteLabel.fontColor = GameUITheme.Color.gold
countryCompleteLabel.horizontalAlignmentMode = .center
countryCompleteLabel.verticalAlignmentMode = .center
countryCompleteLabel.zPosition = GameUITheme.Z.modal + 0.25
countryCompleteLabel.isHidden = true
addChild(countryCompleteLabel)
```

Do not modify `ConquestReportNode` or add a fifth summary row.

- [ ] **Step 6: Apply static milestone report geometry during every successful report layout**

Add:

```swift
private func applyMilestoneConquestPresentation(
    result: BattleResult,
    layout: ConquestReportLayout
) {
    guard let presentation = Country1MilestonePresentation.make(
        forCityNumber: result.cityKey.cityNumber
    ) else {
        milestoneConquestAccent.isHidden = true
        milestoneConquestAccent.path = nil
        countryCompleteLabel.isHidden = true
        return
    }

    let inset: CGFloat
    switch presentation.tier {
    case .first: inset = 5
    case .second: inset = 7
    case .finale: inset = 9
    }
    let accentFrame = layout.panelFrame.insetBy(dx: -inset, dy: -inset)
    milestoneConquestAccent.path = CGPath(
        roundedRect: accentFrame,
        cornerWidth: layout.panelCornerRadius + 4,
        cornerHeight: layout.panelCornerRadius + 4,
        transform: nil
    )
    switch presentation.tier {
    case .first:
        milestoneConquestAccent.lineWidth = 2
        milestoneConquestAccent.glowWidth = 1
    case .second:
        milestoneConquestAccent.lineWidth = 3
        milestoneConquestAccent.glowWidth = 3
    case .finale:
        milestoneConquestAccent.lineWidth = 4
        milestoneConquestAccent.glowWidth = 5
    }
    milestoneConquestAccent.isHidden = false

    if presentation.isCountryFinale,
       let finalFrame = countryCompleteFrame(for: layout) {
        countryCompleteLabel.isHidden = false
        countryCompleteLabel.fontSize = layout.compactHeightForMilestoneTesting ? 15 : 18
        countryCompleteLabel.position = CGPoint(x: finalFrame.midX, y: finalFrame.midY)
        fitLabel(countryCompleteLabel, maxWidth: finalFrame.width)
    } else {
        countryCompleteLabel.isHidden = true
    }
}
```

Do **not** add `compactHeightForMilestoneTesting` to `ConquestReportLayout`. Use the existing BattleScene `layoutMetrics().compactHeight` directly in production:

```swift
countryCompleteLabel.fontSize = layoutMetrics().compactHeight ? 15 : 18
```

The first snippet names the desired logic; the production line above is authoritative and avoids changing `ConquestReportLayout` for this feature.

- [ ] **Step 7: Compute the City 15 label frame outside the report panel**

Add one private BattleScene geometry helper:

```swift
private func countryCompleteFrame(for layout: ConquestReportLayout) -> CGRect? {
    let height: CGFloat = layoutMetrics().compactHeight ? 22 : 26
    let gap: CGFloat = 8
    let above = CGRect(
        x: layout.panelFrame.minX,
        y: layout.panelFrame.maxY + gap,
        width: layout.panelFrame.width,
        height: height
    )
    if layout.safeFrame.contains(above) {
        return above
    }

    let below = CGRect(
        x: layout.panelFrame.minX,
        y: layout.panelFrame.minY - gap - height,
        width: layout.panelFrame.width,
        height: height
    )
    return layout.safeFrame.contains(below) ? below : nil
}
```

The supported-layout test must prove one of these frames exists at `568×320` and `667×375`. Do not grow `ConquestReportLayout` or move Continue.

- [ ] **Step 8: Wire static report treatment into `applyPendingConquestReport`**

After `ConquestReportNode.apply(...) == .presented` succeeds and before the method sets visible/presented flags, add:

```swift
applyMilestoneConquestPresentation(result: result, layout: layout)
```

Because `applyPendingConquestReport` runs during resize and when disabling Continue, this method may update geometry but must not run a one-shot animation or increment a presentation counter.

- [ ] **Step 9: Add fresh-only one-shot flourish at the existing origin boundary**

Add:

```swift
private func presentFreshMilestoneConquestFlourishIfNeeded(
    origin: ConquestReportPresentationOrigin
) {
    guard origin != .restored,
          !hasPresentedMilestoneConquestFlourish,
          let result = state.pendingBattleResult,
          Country1MilestonePresentation.make(
              forCityNumber: result.cityKey.cityNumber
          ) != nil else {
        return
    }

    hasPresentedMilestoneConquestFlourish = true
    #if DEBUG
    milestoneConquestFlourishCountForTestingStorage += 1
    #endif

    milestoneConquestAccent.removeAllActions()
    if UIAccessibility.isReduceMotionEnabled {
        milestoneConquestAccent.alpha = 0.45
        milestoneConquestAccent.setScale(1)
        milestoneConquestAccent.run(SKAction.fadeAlpha(to: 1, duration: 0.20))
    } else {
        milestoneConquestAccent.alpha = 0.45
        milestoneConquestAccent.setScale(0.97)
        milestoneConquestAccent.run(SKAction.group([
            SKAction.fadeAlpha(to: 1, duration: 0.24),
            SKAction.scale(to: 1, duration: 0.24)
        ]))
    }
}
```

Call `presentFreshMilestoneConquestFlourishIfNeeded(origin:)` inside `presentPendingConquestReport(...)` only after `applyPendingConquestReport(...)` succeeds. Keep the existing gold-burst branch unchanged.

- [ ] **Step 10: Add semantic DEBUG accessors for report behavior**

Expose:

```swift
var milestoneConquestFlourishCountForTesting: Int {
    milestoneConquestFlourishCountForTestingStorage
}

var milestoneConquestAccentFrameForTesting: CGRect? {
    milestoneConquestAccent.isHidden ? nil : sceneFrame(for: milestoneConquestAccent)
}

var countryCompleteTextForTesting: String? {
    countryCompleteLabel.isHidden ? nil : countryCompleteLabel.text
}

var countryCompleteFrameForTesting: CGRect? {
    countryCompleteLabel.isHidden ? nil : sceneFrame(for: countryCompleteLabel)
}

var lastConquestReportLayoutForTesting: ConquestReportLayout? {
    guard let content = lastAppliedConquestReportContent else { return nil }
    return conquestReportLayout(for: content)
}
```

Do not expose animation actions or private style constants.

- [ ] **Step 11: Run the new report tests and confirm GREEN**

Run the same four `-only-testing` selectors from Step 4.

Expected: PASS.

- [ ] **Step 12: Run all BattleScene tests**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/BattleSceneTests
```

Expected: PASS. In particular, existing `restoredPendingReportIsStatic`, `liveConquestUsesFreshLiveEffectsOnce`, `battleForegroundIdleUsesFreshIdleGoldOnly`, `repeatedDidMoveResizeAndRedrawDoNotDuplicateOrReplay`, and `countryCompleteContinueRoutesToFinalMapOnce` must remain green.

- [ ] **Step 13: Commit the conquest slice**

```bash
git add Pyxis/BattleScene.swift PyxisTests/BattleSceneTests.swift
git commit -m "feat: add milestone conquest presentation"
```

---

### Task 4: Document ownership and run full verification

**Files:**
- Modify: `CLAUDE.md` — BattleScene architecture ownership note.
- Verify: `docs/superpowers/specs/2026-08-09-country-1-milestone-presentation-design.md`
- Verify: `docs/superpowers/plans/2026-08-10-country-1-milestone-presentation-implementation.md`

**Interfaces:**
- Produces no runtime API.
- Locks the maintenance boundary: selector is pure/non-persisted; BattleScene owns milestone visuals/lifecycle; shared city/report models remain unchanged.

- [ ] **Step 1: Add the repository ownership note**

Extend the existing `BattleScene` bullet under `## Architecture -> 5. Scenes` with this concise paragraph:

```markdown
Country 1 milestone presentation (HPA-390) is also BattleScene-owned. `Country1MilestonePresentation` is only a pure City 5/10/15 tier selector; authored names/flavor/conquest copy remain in `Country1CityCatalog`. The arrival banner, enemy-city accent, fresh-only conquest flourish, Reduce Motion branching, and same-scene dedupe are transient scene state and are never persisted. City 15 adds `Country 1 Complete` around the existing report without changing `Crownspire Keep Falls`, report acknowledgement/save, or Country Map routing. Do not add a milestone service/engine, presentation fields to `CityDefinition`, or durable consumed-presentation state without a concrete new requirement.
```

Do not edit `AGENTS.md`; it is a symlink to `CLAUDE.md`.

- [ ] **Step 2: Run focused selector and BattleScene verification**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/Country1MilestonePresentationTests \
  -only-testing:PyxisTests/BattleSceneTests
```

Expected: PASS.

- [ ] **Step 3: Run the full unit suite**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests
```

Expected: PASS.

- [ ] **Step 4: Run the full UI suite**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisUITests
```

Expected: PASS.

- [ ] **Step 5: Run SwiftLint and diff hygiene**

```bash
swiftlint lint --no-cache
git diff --check origin/main...HEAD
```

Expected: SwiftLint exits 0 with no new serious findings; `git diff --check` exits 0 with no whitespace errors.

- [ ] **Step 6: Prove scope did not expand**

Run:

```bash
git diff --name-only origin/main...HEAD
git diff --numstat origin/main...HEAD -- ':(glob)Pyxis/*.swift'
git grep -n -E 'Milestone.*(Service|Manager|Protocol|Registry)|milestone.*(UserDefaults|Codable|persist)' -- Pyxis || true
```

Expected production shape:

- `Pyxis/Country1MilestonePresentation.swift` is the only new production file.
- Runtime edits are concentrated in `Pyxis/BattleScene.swift`.
- No milestone persistence, service/manager/protocol/registry, new asset, or project-file registration appears.

- [ ] **Step 7: Run the manual City 5 -> 10 -> 15 milestone smoke**

For each milestone, seed/play an active city and verify the following player journey:

1. **City 5 / Highcrest** — arrival shows `City 5 · Highcrest` plus `A proud hill fortress crowns the frontier.`; accent is modest; one skip tap only hides the banner; combat continues; fresh conquest uses `Highcrest Falls` and one modest report flourish.
2. **City 10 / Ironthorn Gate** — arrival/report accents are visibly stronger than City 5 while using the same structure; authored copy remains `City 10 · Ironthorn Gate` / `A hardened gate blocks the inner road.` / `Ironthorn Gate Broken`.
3. **City 15 / Crownspire Keep** — strongest treatment; authored conquest title remains `Crownspire Keep Falls`; `Country 1 Complete` is visible before Continue; Continue returns to the completed Country Map exactly once.
4. Repeat one milestone with **Reduce Motion enabled** in iOS Settings: required text and framing remain; scale/pulse motion is absent and only fades/static treatment remain.
5. Exercise one fresh idle conquest through background/foreground at a milestone: report origin is fresh idle and the flourish occurs once.
6. Recreate a scene with a pending milestone report: restored report shows static milestone treatment, City 15 completion text when applicable, no arrival banner, and no replayed one-shot flourish.
7. At `568×320` and `667×375`, required milestone text remains readable and neither `Country 1 Complete` nor the report accent blocks/overlaps Continue.
8. Confirm gold, city HP, rewards, unlocks, lane behavior, unit behavior, building behavior, and save/progression results match ordinary-city behavior.

- [ ] **Step 8: Commit documentation after all verification passes**

```bash
git add CLAUDE.md
git commit -m "docs: document milestone presentation ownership"
```

---

## Plan Self-Review Checklist

The plan is complete only when all of these remain true during implementation:

- Every design requirement maps to Tasks 1-4.
- Selector names/signatures are identical across tasks: `Country1MilestonePresentation.make(forCityNumber:)`, `.Tier`, `.isCountryFinale`.
- Authored city strings are never copied into the selector or persisted state.
- BattleScene's existing fresh/restored report origin remains the only one-shot conquest gate.
- Resize/redraw uses layout/application methods only and cannot call the arrival/flourish presentation entry points.
- City 15 completion text exists for restored reports as semantic state while the one-shot flourish count remains zero.
- No change to `ConquestReportContent`, `ConquestReportNode`, `ConquestReportLayout`, `KingdomGameState`, `BattleResult`, `Country1CityCatalog`, `CityDefinition`, `KingdomGameStore`, or `GameViewController` is required by this plan.
- No new production file beyond `Country1MilestonePresentation.swift` is required.
- Reduced Motion does not require dependency injection or persistence.
- Existing Continue acknowledgement -> save -> Country Map flow remains the only completion transaction.
