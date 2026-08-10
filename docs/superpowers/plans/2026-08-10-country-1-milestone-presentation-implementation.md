# HPA-390 Country 1 Milestone Presentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Cities 5, 10, and 15 feel like escalating Country 1 milestones through lightweight BattleScene presentation only, while preserving existing combat, rewards, persistence, progression, routing, and conquest-report semantics.

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
- Arrival auto-dismiss target is 1.5 seconds including its short fade-in/fade-out.
- Resize/redraw/layout refresh may reposition current milestone nodes but must not restart one-shot presentation.
- Any conquest report presentation dismisses a still-visible arrival banner before the report is applied, so the two presentations never compete.
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
- `Pyxis/BattleScene.swift` — owns milestone nodes, fixed style constants, layout, input precedence, arrival lifetime, Reduce Motion branching, conquest flourish, and same-scene dedupe.
- `PyxisTests/Country1MilestonePresentationTests.swift` — focused pure selector contract.
- `PyxisTests/BattleSceneTests.swift` — behavior-oriented integration checks for arrival copy/input/dedupe/layout, city accent, fresh/restored conquest behavior, City 15 completion state, and Continue routing.
- `CLAUDE.md` — records milestone ownership and the no-persistence/no-framework boundary.

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

- [ ] **Step 2: Run the selector suite and confirm RED**

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

Do not add city strings, effect constants, colors, protocols, a country parameter, or future-country extension points.

- [ ] **Step 4: Run the selector suite and confirm GREEN**

Run the Step 2 command again.

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
- Produces internally: `presentMilestoneArrivalIfNeeded()`, `dismissMilestoneArrival()`, `finishMilestoneArrivalDismissal()`, `layoutMilestoneArrival()`, `layoutMilestoneCityAccent()`.
- Produces DEBUG semantics: milestone tier, arrival title/subtitle, visible state, presentation count, banner/title/subtitle frames, city-accent frame.

- [ ] **Step 1: Add the normalized active-milestone fixture**

In `BattleSceneTests`, add:

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

`completedCityCount = city - 1` is required because `KingdomGameState` normalizes the active city from progression.

- [ ] **Step 2: Write RED arrival/ordinary/non-modal tests**

```swift
@Test("City 5 presents authored milestone arrival and an enemy-city accent")
func city5PresentsMilestoneArrival() throws {
    let scene = makeScene(
        store: try makeStore(initialState: activeMilestoneState(city: 5))
    )

    #expect(scene.milestoneTierForTesting == 1)
    #expect(scene.isMilestoneArrivalVisibleForTesting)
    #expect(scene.milestoneArrivalPresentationCountForTesting == 1)
    #expect(scene.milestoneArrivalTitleForTesting == "City 5 · Highcrest")
    #expect(scene.milestoneArrivalSubtitleForTesting == "A proud hill fortress crowns the frontier.")
    #expect(scene.milestoneCityAccentFrameForTesting != nil)

    scene.update(10)
    scene.update(11)
    #expect(scene.lastAdvanceCombatDeltaForTesting == 1)
}

@Test("Ordinary cities have no milestone arrival or accent")
func ordinaryCityHasNoMilestonePresentation() throws {
    let scene = makeScene(store: try makeStore(initialState: KingdomGameState(
        cityLevel: 6,
        cityNumberInCountry: 6,
        completedCityCount: 5
    )))

    #expect(scene.milestoneTierForTesting == nil)
    #expect(!scene.isMilestoneArrivalVisibleForTesting)
    #expect(scene.milestoneArrivalPresentationCountForTesting == 0)
    #expect(scene.milestoneCityAccentFrameForTesting == nil)
}
```

The `update` assertion proves the banner does not add itself to BattleScene's combat pause guard.

- [ ] **Step 3: Write RED input-precedence and same-scene dedupe tests**

```swift
@Test("Milestone arrival consumes the tap before Settings")
func milestoneArrivalConsumesUnderlyingTap() throws {
    let scene = makeScene(
        store: try makeStore(initialState: activeMilestoneState(city: 5))
    )
    let gearFrame = try #require(scene.feedbackSettingsGearFrameForTesting)

    scene.handleTouchForTesting(at: gearFrame.center)
    #expect(!scene.isMilestoneArrivalVisibleForTesting)
    #expect(!scene.isFeedbackSettingsVisibleForTesting)

    scene.handleTouchForTesting(at: gearFrame.center)
    #expect(scene.isFeedbackSettingsVisibleForTesting)
}

@Test("Milestone arrival is not replayed by layout refresh")
func milestoneArrivalDoesNotReplayOnLayoutRefresh() throws {
    let scene = makeScene(
        store: try makeStore(initialState: activeMilestoneState(city: 10))
    )
    let count = scene.milestoneArrivalPresentationCountForTesting

    scene.refreshLayoutForCurrentEnvironment()
    scene.redrawForTesting(shouldLayout: true)
    scene.repeatDidMoveForTesting()

    #expect(scene.milestoneArrivalPresentationCountForTesting == count)
}
```

- [ ] **Step 4: Write RED compact arrival-layout test**

Use the two landscape gates already used by Building View and current compact validation:

```swift
@Test("Milestone arrival text fits supported landscape gates")
func milestoneArrivalFitsLandscapeGates() throws {
    for size in [
        CGSize(width: 568, height: 320),
        CGSize(width: 667, height: 375)
    ] {
        let scene = makeScene(
            store: try makeStore(initialState: activeMilestoneState(city: 15)),
            size: size
        )
        let banner = try #require(scene.milestoneArrivalFrameForTesting)
        let title = try #require(scene.milestoneArrivalTitleFrameForTesting)
        let subtitle = try #require(scene.milestoneArrivalSubtitleFrameForTesting)

        #expect(banner.contains(title))
        #expect(banner.contains(subtitle))
        #expect(!title.intersects(subtitle))
        #expect(banner.minX >= 0)
        #expect(banner.maxX <= size.width)
        #expect(banner.minY >= 0)
        #expect(banner.maxY <= size.height)
    }
}
```

- [ ] **Step 5: Run the new BattleScene tests and confirm RED**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/BattleSceneTests/city5PresentsMilestoneArrival \
  -only-testing:PyxisTests/BattleSceneTests/ordinaryCityHasNoMilestonePresentation \
  -only-testing:PyxisTests/BattleSceneTests/milestoneArrivalConsumesUnderlyingTap \
  -only-testing:PyxisTests/BattleSceneTests/milestoneArrivalDoesNotReplayOnLayoutRefresh \
  -only-testing:PyxisTests/BattleSceneTests/milestoneArrivalFitsLandscapeGates
```

Expected: FAIL because the milestone BattleScene surface does not exist.

- [ ] **Step 6: Add scene-owned milestone state and nodes**

Near the existing effect/presentation state in `BattleScene`, add:

```swift
private enum MilestoneStyle {
    static let arrivalDuration: TimeInterval = 1.5
    static let fadeDuration: TimeInterval = 0.18
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

Do not cache city strings or write milestone state into `KingdomGameState`.

- [ ] **Step 7: Configure the nodes once in `buildInterface()`**

Add this BattleScene helper and call it once after the battlefield layers/nodes are built:

```swift
private func configureMilestonePresentationNodes() {
    milestoneArrivalNode.zPosition = MilestoneStyle.arrivalZ
    milestoneArrivalNode.isHidden = true

    milestoneArrivalPanel.fillColor = GameUITheme.Color.panelFill
    milestoneArrivalPanel.strokeColor = GameUITheme.Color.gold
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

Do not create a reusable banner/accent node type.

- [ ] **Step 8: Add the three fixed visual strengths**

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

Tests do not freeze these exact style constants; they remain private presentation details.

- [ ] **Step 9: Implement authored copy and exact 1.5-second auto-dismiss**

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
    milestoneArrivalNode.alpha = 0
    milestoneArrivalNode.setScale(UIAccessibility.isReduceMotionEnabled ? 1 : 0.96)

    let fadeIn = SKAction.fadeAlpha(to: 1, duration: MilestoneStyle.fadeDuration)
    let appear = UIAccessibility.isReduceMotionEnabled
        ? fadeIn
        : SKAction.group([
            fadeIn,
            SKAction.scale(to: 1, duration: MilestoneStyle.fadeDuration)
        ])
    let visibleDuration = MilestoneStyle.arrivalDuration - MilestoneStyle.fadeDuration * 2
    let wait = SKAction.wait(forDuration: visibleDuration)
    let fadeOut = SKAction.fadeOut(withDuration: MilestoneStyle.fadeDuration)
    let finish = SKAction.run { [weak self] in
        self?.finishMilestoneArrivalDismissal()
    }
    milestoneArrivalNode.run(
        SKAction.sequence([appear, wait, fadeOut, finish]),
        withKey: MilestoneStyle.arrivalActionKey
    )
}

private func finishMilestoneArrivalDismissal() {
    milestoneArrivalNode.isHidden = true
    milestoneArrivalNode.alpha = 1
    milestoneArrivalNode.setScale(1)
    isMilestoneArrivalVisible = false
}

private func dismissMilestoneArrival() {
    guard isMilestoneArrivalVisible else { return }
    milestoneArrivalNode.removeAction(forKey: MilestoneStyle.arrivalActionKey)
    finishMilestoneArrivalDismissal()
}
```

`0.18 + 1.14 + 0.18 = 1.5` seconds. Reduce Motion uses only fades because its scale is always `1`.

- [ ] **Step 10: Lay out the banner inside the existing safe/content width**

Keep one small geometry method in BattleScene:

```swift
private func layoutMilestoneArrival() {
    guard isMilestoneArrivalVisible || hasPresentedMilestoneArrival else { return }

    let metrics = layoutMetrics()
    let insets = view?.safeAreaInsets ?? .zero
    let availableWidth = max(0, size.width - insets.left - insets.right - 24)
    let width = min(metrics.contentWidth, availableWidth)
    let height: CGFloat = metrics.compactHeight ? 64 : 76
    guard width >= 120 else { return }

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

The compact test is the required regression gate for the fixed Country 1 strings; do not add a new generic layout type.

- [ ] **Step 11: Lay out the city accent from the actual rendered city frame**

At the tail of `layoutBattlefield(...)`, after the city is fitted/positioned and `layoutCityHPBar()` runs, call:

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

Do not change `enemyCityNode.position`, scale, battlefield gate points, HP-bar geometry, or any hit target.

- [ ] **Step 12: Wire lifecycle and input precedence**

In `didMove(to:)`, preserve restored-report authority:

```swift
redraw()

if state.pendingBattleResult != nil, !hasPresentedPendingConquestReport {
    _ = presentPendingConquestReport(origin: .restored, resetsContinueState: true)
} else {
    presentMilestoneArrivalIfNeeded()
}
```

In `handleTouch(at:)`, insert this immediately after conquest report/fit-failure handling and before Settings:

```swift
if isMilestoneArrivalVisible {
    dismissMilestoneArrival()
    return
}
```

At the end of `layoutInterface()`, call `layoutMilestoneArrival()` so resize moves the existing banner without invoking a presentation entry point.

- [ ] **Step 13: Add semantic DEBUG accessors**

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

var milestoneArrivalTitleFrameForTesting: CGRect? {
    milestoneArrivalNode.isHidden ? nil : sceneFrame(for: milestoneArrivalTitleLabel)
}

var milestoneArrivalSubtitleFrameForTesting: CGRect? {
    milestoneArrivalNode.isHidden ? nil : sceneFrame(for: milestoneArrivalSubtitleLabel)
}

var milestoneCityAccentFrameForTesting: CGRect? {
    milestoneCityAccent.isHidden ? nil : sceneFrame(for: milestoneCityAccent)
}
```

Do not expose stroke/glow constants or private node-tree structure.

- [ ] **Step 14: Run the five focused tests and confirm GREEN**

Run the Step 5 command again.

Expected: PASS.

- [ ] **Step 15: Run the full BattleScene suite**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/BattleSceneTests
```

Expected: PASS, including existing Settings precedence, combat timing, report restoration, layout, and routing coverage.

- [ ] **Step 16: Commit the arrival/accent slice**

```bash
git add Pyxis/BattleScene.swift PyxisTests/BattleSceneTests.swift
git commit -m "feat: add milestone arrival presentation"
```

---

### Task 3: Add fresh-only conquest flourish and City 15 completion state

**Files:**
- Modify: `Pyxis/BattleScene.swift` — report accent/finale nodes, `applyPendingConquestReport`, `presentPendingConquestReport`, DEBUG accessors.
- Modify: `PyxisTests/BattleSceneTests.swift` — fresh/restored milestone report tests, City 15 semantic state, compact report layout, Continue route.

**Interfaces:**
- Consumes: `BattleResult.cityKey` as report identity authority.
- Consumes: existing `ConquestReportLayout.safeFrame`, `.panelFrame`, `.continueFrame`.
- Produces internally: `applyMilestoneConquestPresentation(result:layout:)`, `presentFreshMilestoneConquestFlourishIfNeeded(origin:)`, `countryCompleteFrame(for:)`.
- Produces DEBUG semantics: flourish count, report-accent frame, `Country 1 Complete` text/frame, current report layout.

- [ ] **Step 1: Write RED fresh/restored milestone report tests**

```swift
@Test("Fresh City 5 conquest presents milestone flourish once")
func freshCity5ConquestPresentsMilestoneFlourishOnce() throws {
    let key = CityKey(countryNumber: 1, cityNumber: 5)
    let state = KingdomGameState(
        gold: 100,
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
    let gearFrame = try #require(scene.feedbackSettingsGearFrameForTesting)

    scene.handleTouchForTesting(at: gearFrame.center) // consume arrival only
    scene.spawnSoldierForTesting()
    scene.advanceCombatForTesting(deltaTime: 3)

    #expect(scene.lastConquestReportOriginForTesting == "freshLive")
    #expect(!scene.isMilestoneArrivalVisibleForTesting)
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

The level-6 Barracks follows the same high-level-unit pattern already used by the existing City 15 live-conquest test and is more than sufficient for City 5.

- [ ] **Step 2: Extend the existing fresh City 15 test**

At the end of `battleFinalCityOutcomeEmitsRewardThenCountryCompletion`, add:

```swift
#expect(scene.countryCompleteTextForTesting == "Country 1 Complete")
#expect(scene.milestoneConquestFlourishCountForTesting == 1)
#expect(!scene.isMilestoneArrivalVisibleForTesting)
```

This locks semantic completion text on a fresh finale without changing the existing feedback assertions.

- [ ] **Step 3: Extend the existing restored City 15 Continue test**

In `countryCompleteContinueRoutesToFinalMapOnce`, before tapping Continue, add:

```swift
#expect(scene.conquestReportTitleForTesting == "Crownspire Keep Falls")
#expect(scene.countryCompleteTextForTesting == "Country 1 Complete")
#expect(scene.milestoneConquestFlourishCountForTesting == 0)
let countryCompleteFrame = try #require(scene.countryCompleteFrameForTesting)
let continueFrame = try #require(scene.popupContinueButtonFrameForTesting)
#expect(!countryCompleteFrame.intersects(continueFrame))
```

Keep the existing route transaction unchanged:

```swift
scene.tapConquestContinueForTesting()
scene.tapConquestContinueForTesting()
#expect(router.countryMapRequestCount == 1)
#expect(store.load().pendingBattleResult == nil)
```

- [ ] **Step 4: Add RED compact City 15 report-layout test**

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
        let layout = try #require(scene.lastConquestReportLayoutForTesting)
        let accentFrame = try #require(scene.milestoneConquestAccentFrameForTesting)
        let finalFrame = try #require(scene.countryCompleteFrameForTesting)
        let continueFrame = try #require(scene.popupContinueButtonFrameForTesting)

        #expect(layout.safeFrame.contains(accentFrame))
        #expect(layout.safeFrame.contains(finalFrame))
        #expect(!finalFrame.intersects(layout.panelFrame))
        #expect(!finalFrame.intersects(continueFrame))
        #expect(!scene.isConquestReportFitFailedForTesting)
    }
}
```

- [ ] **Step 5: Run the new/extended report tests and confirm RED**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/BattleSceneTests/freshCity5ConquestPresentsMilestoneFlourishOnce \
  -only-testing:PyxisTests/BattleSceneTests/restoredCity10ReportDoesNotReplayMilestoneFlourish \
  -only-testing:PyxisTests/BattleSceneTests/battleFinalCityOutcomeEmitsRewardThenCountryCompletion \
  -only-testing:PyxisTests/BattleSceneTests/countryCompleteContinueRoutesToFinalMapOnce \
  -only-testing:PyxisTests/BattleSceneTests/city15MilestoneReportFitsLandscapeGates
```

Expected: FAIL because report milestone presentation does not exist.

- [ ] **Step 6: Add the report accent/finale nodes and scene-local dedupe state**

Near the current conquest-report fields:

```swift
private let milestoneConquestAccent = SKShapeNode()
private let countryCompleteLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
private var hasPresentedMilestoneConquestFlourish = false
#if DEBUG
private var milestoneConquestFlourishCountForTestingStorage = 0
#endif
```

Configure once in `buildInterface()`:

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

Do not modify `ConquestReportNode` or add another summary row.

- [ ] **Step 7: Compute the finale-label frame outside the existing report**

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

This keeps the completion label out of report rows and out of Continue geometry.

- [ ] **Step 8: Apply static milestone report treatment on every successful report layout**

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
    milestoneConquestAccent.alpha = 1
    milestoneConquestAccent.setScale(1)
    milestoneConquestAccent.isHidden = false

    guard presentation.isCountryFinale,
          let finalFrame = countryCompleteFrame(for: layout) else {
        countryCompleteLabel.isHidden = true
        return
    }

    countryCompleteLabel.isHidden = false
    countryCompleteLabel.fontSize = layoutMetrics().compactHeight ? 15 : 18
    countryCompleteLabel.position = CGPoint(x: finalFrame.midX, y: finalFrame.midY)
    fitLabel(countryCompleteLabel, maxWidth: finalFrame.width)
}
```

This method owns static state only. It never increments one-shot counts or starts animation.

- [ ] **Step 9: Dismiss arrival and apply static milestone state from `applyPendingConquestReport`**

After `pendingResultForPresentation()` succeeds, dismiss any still-visible arrival before applying the report:

```swift
guard let result = pendingResultForPresentation() else { return false }
dismissMilestoneArrival()
```

Then preserve the existing report layout/apply guard. Immediately after `conquestReportNode.apply(...) == .presented`, add:

```swift
applyMilestoneConquestPresentation(result: result, layout: layout)
```

`applyPendingConquestReport` is also called on resize and when disabling Continue, so this path may reposition static nodes but must never call the fresh-flourish method.

- [ ] **Step 10: Add fresh-only one-shot flourish at the existing origin boundary**

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
    milestoneConquestAccent.alpha = 0.45
    milestoneConquestAccent.setScale(UIAccessibility.isReduceMotionEnabled ? 1 : 0.97)

    let fade = SKAction.fadeAlpha(to: 1, duration: 0.24)
    let emphasis = UIAccessibility.isReduceMotionEnabled
        ? fade
        : SKAction.group([
            fade,
            SKAction.scale(to: 1, duration: 0.24)
        ])
    milestoneConquestAccent.run(emphasis)
}
```

Inside `presentPendingConquestReport(...)`, call it only after `applyPendingConquestReport(...)` succeeds:

```swift
presentFreshMilestoneConquestFlourishIfNeeded(origin: origin)
```

Keep the existing fresh-only gold-burst branch unchanged. Restored reports retain the static accent from Step 8 but get no one-shot animation/count.

- [ ] **Step 11: Add semantic DEBUG accessors**

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
    guard !countryCompleteLabel.isHidden,
          let content = lastAppliedConquestReportContent,
          let layout = conquestReportLayout(for: content) else {
        return nil
    }
    return countryCompleteFrame(for: layout)
}

var lastConquestReportLayoutForTesting: ConquestReportLayout? {
    guard let content = lastAppliedConquestReportContent else { return nil }
    return conquestReportLayout(for: content)
}
```

Do not expose animation actions or private style constants.

- [ ] **Step 12: Run the five report tests and confirm GREEN**

Run the Step 5 command again.

Expected: PASS.

- [ ] **Step 13: Run all BattleScene tests**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/BattleSceneTests
```

Expected: PASS. In particular, existing `restoredPendingReportIsStatic`, `liveConquestUsesFreshLiveEffectsOnce`, `battleForegroundIdleUsesFreshIdleGoldOnly`, `repeatedDidMoveResizeAndRedrawDoNotDuplicateOrReplay`, and `countryCompleteContinueRoutesToFinalMapOnce` remain green.

- [ ] **Step 14: Commit the conquest slice**

```bash
git add Pyxis/BattleScene.swift PyxisTests/BattleSceneTests.swift
git commit -m "feat: add milestone conquest presentation"
```

---

### Task 4: Document ownership and run full verification

**Files:**
- Modify: `CLAUDE.md` — extend the existing BattleScene architecture bullet.
- Verify: `docs/superpowers/specs/2026-08-09-country-1-milestone-presentation-design.md`
- Verify: `docs/superpowers/plans/2026-08-10-country-1-milestone-presentation-implementation.md`

**Interfaces:**
- Produces no runtime API.
- Locks the maintenance boundary: selector is pure/non-persisted; BattleScene owns milestone visuals/lifecycle; shared city/report models remain unchanged.

- [ ] **Step 1: Add the repository ownership note**

Append this paragraph to the existing `BattleScene` bullet under `## Architecture -> 5. Scenes`:

```markdown
Country 1 milestone presentation (HPA-390) is also BattleScene-owned. `Country1MilestonePresentation` is only a pure City 5/10/15 tier selector; authored names/flavor/conquest copy remain in `Country1CityCatalog`. The arrival banner, enemy-city accent, fresh-only conquest flourish, Reduce Motion branching, and same-scene dedupe are transient scene state and are never persisted. City 15 adds `Country 1 Complete` around the existing report without changing `Crownspire Keep Falls`, report acknowledgement/save, or Country Map routing. Do not add a milestone service/engine, presentation fields to `CityDefinition`, or durable consumed-presentation state without a concrete new requirement.
```

Do not edit `AGENTS.md`; it is a symlink to `CLAUDE.md`.

- [ ] **Step 2: Run focused selector + BattleScene verification**

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

Expected: SwiftLint exits 0 with no new serious findings; `git diff --check` exits 0.

- [ ] **Step 6: Prove scope did not expand**

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

Verify this exact journey:

1. **City 5 / Highcrest** — arrival shows `City 5 · Highcrest` plus `A proud hill fortress crowns the frontier.`; accent is modest; one skip tap only hides the banner; combat continues; fresh conquest uses `Highcrest Falls` and one modest report flourish.
2. **City 10 / Ironthorn Gate** — arrival/report accents are visibly stronger than City 5 while using the same structure; authored copy remains `City 10 · Ironthorn Gate` / `A hardened gate blocks the inner road.` / `Ironthorn Gate Broken`.
3. **City 15 / Crownspire Keep** — strongest treatment; authored conquest title remains `Crownspire Keep Falls`; `Country 1 Complete` is visible before Continue; Continue returns to the completed Country Map exactly once.
4. Repeat one milestone with **Reduce Motion enabled** in iOS Settings: required text/framing remain; scale emphasis is absent and only fades/static treatment remain.
5. Exercise one fresh idle conquest through background/foreground at a milestone: report origin is fresh idle and the flourish occurs once.
6. Recreate a scene with a pending milestone report: restored report shows static milestone treatment, City 15 completion text when applicable, no arrival banner, and no replayed one-shot flourish.
7. At `568×320` and `667×375`, arrival title/subtitle and City 15 completion state remain readable; report treatment does not block/overlap Continue.
8. Confirm gold, city HP, rewards, unlocks, lane behavior, unit behavior, building behavior, and save/progression results match ordinary-city behavior.

- [ ] **Step 8: Commit documentation after verification**

```bash
git add CLAUDE.md
git commit -m "docs: document milestone presentation ownership"
```

---

## Plan Self-Review Checklist

- Every approved design requirement maps to Tasks 1-4.
- Selector names/signatures are consistent everywhere: `Country1MilestonePresentation.make(forCityNumber:)`, `.Tier`, `.isCountryFinale`.
- All code snippets reference types/properties that already exist or are introduced earlier in this plan.
- Authored city strings are never copied into the selector or persisted state.
- BattleScene's existing fresh/restored report origin remains the only one-shot conquest gate.
- Arrival and conquest one-shot entry points are never called from resize/redraw/layout methods.
- A conquest report explicitly dismisses any still-visible arrival before report application.
- Compact arrival text has an automated containment/non-overlap gate at `568×320` and `667×375`.
- City 15 completion text exists for fresh and restored reports while restored one-shot flourish count remains zero.
- `ConquestReportContent`, `ConquestReportNode`, `ConquestReportLayout`, `KingdomGameState`, `BattleResult`, `Country1CityCatalog`, `CityDefinition`, `KingdomGameStore`, and `GameViewController` require no production changes.
- No new production file beyond `Country1MilestonePresentation.swift` is required.
- Reduced Motion does not require dependency injection or persistence.
- Existing Continue acknowledgement -> save -> Country Map flow remains the only completion transaction.
