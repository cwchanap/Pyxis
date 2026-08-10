# HPA-390 Country 1 Milestone Presentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Cities 5, 10, and 15 feel like escalating Country 1 milestones through lightweight BattleScene presentation only, while preserving existing combat, rewards, persistence, progression, routing, and conquest-report semantics.

**Architecture:** Add one framework-free `Country1MilestonePresentation` selector that maps only City 5/10/15 to three fixed tiers. `BattleScene` remains the sole runtime owner of the arrival banner, static enemy-city accent, fresh-conquest flourish, same-scene dedupe state, and City 15 `Country 1 Complete` label. Authored strings continue to come from `CityDefinition`, and conquest presentation continues to use the existing `.freshLive` / `.freshIdle` / `.restored` boundary and existing unsupported-geometry authority.

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
- City 15 `Country 1 Complete` is required semantic report state and remains visible on restored pending reports.
- If City 15 required completion text cannot fit, fail closed through the existing conquest-report unsupported-geometry path. Never silently hide it while treating the report as presented.
- Read Reduce Motion directly from `UIAccessibility.isReduceMotionEnabled`; do not add a persisted setting, protocol, manager, or dependency seam.
- The enemy-city accent is **static** in HPA-390. Do not add a looping pulse; motion is limited to arrival transition and fresh conquest flourish.
- No new gameplay SFX/haptic event, sound asset, image asset, milestone engine, presentation service, registry, reusable node framework, or generic theme model.
- No persisted milestone-consumption token in `KingdomGameState`, `BattleResult`, `CityDefinition`, or `UserDefaults`.
- Keep the existing `ConquestReportContent`, `ConquestReportLayout`, `ConquestReportNode`, Continue transaction, and report fit-failure authority intact.
- Automated geometry gates cover `568×320`, `667×375`, and `320×568`.
- No `project.pbxproj` edits; the repository uses `PBXFileSystemSynchronizedRootGroup`.
- New production files: exactly one (`Pyxis/Country1MilestonePresentation.swift`). All SpriteKit behavior stays in `BattleScene.swift`.
- Run simulator tests with `-parallel-testing-enabled NO`.

## File Structure

- `Pyxis/Country1MilestonePresentation.swift` — pure Country 1 City 5/10/15 selection only; no UIKit/SpriteKit, strings, colors, durations, or persistence.
- `Pyxis/BattleScene.swift` — owns milestone nodes, fixed style constants, layout, input precedence, arrival lifetime, Reduce Motion branching, conquest flourish, fail-closed City 15 fit, and same-scene dedupe.
- `PyxisTests/Country1MilestonePresentationTests.swift` — focused pure selector contract.
- `PyxisTests/BattleSceneTests.swift` — behavior-oriented integration checks for arrival copy/input/dedupe/layout, city accent, fresh/restored conquest behavior, City 15 completion state/failure, and Continue routing.
- `CLAUDE.md` — records milestone ownership and the no-persistence/no-framework boundary.

## Risks and Go/No-Go Gates

### Risk 1 — City 15 outside-panel required text

`Country 1 Complete` is the only new required report content outside `ConquestReportLayout.panelFrame`. It must fit inside `safeFrame` without touching the report or Continue.

Task 3 is not green until `city15MilestoneReportFitsSupportedGates` passes at `568×320`, `667×375`, and `320×568`.

If no frame fits, use the existing `isConquestReportFitFailed` + `.unsupportedGeometry` path. Do not add a new layout engine, change `ConquestReportLayout`, or silently omit the label.

### Risk 2 — narrow portrait arrival copy

`City 15 · Crownspire Keep` makes `320×568` the hardest width. Task 2 is not green until title/subtitle frames remain contained and non-overlapping at all three geometry gates.

### Risk 3 — one-shot replay

`applyPendingConquestReport` is called for resize and Continue disabling. One-shot flourish belongs only in `presentPendingConquestReport(origin:)`; static geometry belongs in `applyPendingConquestReport`/layout methods. Arrival presentation is entered only during active-scene mounting.

---

### Task 1: Add the pure milestone selector

**Files:**
- Create: `Pyxis/Country1MilestonePresentation.swift`
- Create: `PyxisTests/Country1MilestonePresentationTests.swift`

**Interfaces:**
- Produces: `Country1MilestonePresentation.make(forCityNumber: Int) -> Country1MilestonePresentation?`
- Produces: `Country1MilestonePresentation.Tier` with `.first`, `.second`, `.finale`.
- Produces: `Country1MilestonePresentation.isCountryFinale: Bool`.
- Consumes: integer city number only. The file must not import SpriteKit/UIKit or read `KingdomGameState`.

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

### Task 2: Add the arrival banner and static enemy-city accent

**Files:**
- Modify: `Pyxis/BattleScene.swift` — scene state/nodes, `didMove(to:)`, `handleTouch(at:)`, `buildInterface()`, `layoutInterface()`, `layoutBattlefield(...)`, DEBUG accessors.
- Modify: `PyxisTests/BattleSceneTests.swift` — milestone active-state helper and arrival/accent behavior tests.

**Interfaces:**
- Consumes: `Country1MilestonePresentation.make(forCityNumber:)` from Task 1.
- Consumes: `Country1CityCatalog.definitionIfPresent(for:)` for authored arrival text.
- Produces internally: `currentMilestonePresentation`, `presentMilestoneArrivalIfNeeded()`, `dismissMilestoneArrival(animated:)`, `finishMilestoneArrivalDismissal()`, `layoutMilestoneArrival()`, `layoutMilestoneCityAccent()`.
- Produces DEBUG semantics: milestone tier, arrival title/subtitle, visible state, presentation count, banner/title/subtitle frames, city-accent frame.

- [ ] **Step 1: Add the normalized active-milestone fixture**

In `BattleSceneTests`:

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

`completedCityCount = city - 1` is required because `KingdomGameState` normalizes active progression.

- [ ] **Step 2: Write RED arrival/ordinary/non-modal tests**

```swift
@Test("City 5 presents authored milestone arrival and a static enemy-city accent")
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

The `update` assertion proves the arrival banner is not added to BattleScene's combat pause guard.

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

- [ ] **Step 4: Write RED three-gate arrival-layout test**

```swift
@Test("City 15 milestone arrival fits supported BattleScene gates")
func city15MilestoneArrivalFitsSupportedGates() throws {
    for size in [
        CGSize(width: 568, height: 320),
        CGSize(width: 667, height: 375),
        CGSize(width: 320, height: 568)
    ] {
        let scene = makeScene(
            store: try makeStore(initialState: activeMilestoneState(city: 15)),
            size: size
        )
        let banner = try #require(scene.milestoneArrivalFrameForTesting)
        let title = try #require(scene.milestoneArrivalTitleFrameForTesting)
        let subtitle = try #require(scene.milestoneArrivalSubtitleFrameForTesting)

        #expect(banner.minX >= 0)
        #expect(banner.maxX <= size.width)
        #expect(banner.minY >= 0)
        #expect(banner.maxY <= size.height)
        #expect(banner.contains(title))
        #expect(banner.contains(subtitle))
        #expect(!title.intersects(subtitle))
        #expect(scene.milestoneArrivalTitleForTesting == "City 15 · Crownspire Keep")
        #expect(scene.milestoneArrivalSubtitleForTesting == "The final keep rises above the capital.")
    }
}
```

- [ ] **Step 5: Run focused tests and confirm RED**

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
  -only-testing:PyxisTests/BattleSceneTests/city15MilestoneArrivalFitsSupportedGates
```

Expected: FAIL because milestone BattleScene presentation does not exist.

- [ ] **Step 6: Add only the required BattleScene state/nodes**

Near existing scene presentation fields:

```swift
private var currentMilestonePresentation: Country1MilestonePresentation? {
    guard state.currentCityKey.countryNumber == 1 else { return nil }
    return Country1MilestonePresentation.make(
        forCityNumber: state.currentCityKey.cityNumber
    )
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
```

Keep style constants as a small private `MilestoneStyle` enum inside `BattleScene`; do not create another production file.

- [ ] **Step 7: Configure the nodes once**

In `buildInterface()` after existing battlefield construction:

```swift
milestoneArrivalPanel.fillColor = GameUITheme.Color.panelFill
milestoneArrivalPanel.strokeColor = GameUITheme.Color.gold
milestoneArrivalPanel.lineWidth = 2
milestoneArrivalNode.addChild(milestoneArrivalPanel)

for label in [milestoneArrivalTitleLabel, milestoneArrivalSubtitleLabel] {
    label.horizontalAlignmentMode = .center
    label.verticalAlignmentMode = .center
    milestoneArrivalNode.addChild(label)
}
milestoneArrivalTitleLabel.fontColor = GameUITheme.Color.textPrimary
milestoneArrivalSubtitleLabel.fontColor = GameUITheme.Color.textSecondary
milestoneArrivalNode.zPosition = GameUITheme.Z.modal - 1
milestoneArrivalNode.isHidden = true
addChild(milestoneArrivalNode)

milestoneCityAccent.fillColor = .clear
milestoneCityAccent.strokeColor = GameUITheme.Color.gold
milestoneCityAccent.zPosition = 3
milestoneCityAccent.isHidden = true
environmentLayer.addChild(milestoneCityAccent)
```

The city accent remains static: do not install a repeat/pulse `SKAction` on it.

- [ ] **Step 8: Add tier styling without a theme object**

```swift
private func applyMilestoneCityAccentStyle(
    _ presentation: Country1MilestonePresentation
) {
    switch presentation.tier {
    case .first:
        milestoneCityAccent.lineWidth = 2
        milestoneCityAccent.glowWidth = 1
    case .second:
        milestoneCityAccent.lineWidth = 3
        milestoneCityAccent.glowWidth = 3
    case .finale:
        milestoneCityAccent.lineWidth = 4
        milestoneCityAccent.glowWidth = 5
    }
}
```

No pulse is added in this ticket. HPA-567 may revisit motion if playtesting shows static treatment is insufficient.

- [ ] **Step 9: Present the authored arrival exactly once per mounted scene**

```swift
private func presentMilestoneArrivalIfNeeded() {
    guard !hasPresentedMilestoneArrival,
          state.stageStatus == .battleActive,
          currentMilestonePresentation != nil,
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
    milestoneArrivalNode.removeAllActions()
    milestoneArrivalNode.isHidden = false
    milestoneArrivalNode.alpha = 0
    milestoneArrivalNode.setScale(UIAccessibility.isReduceMotionEnabled ? 1 : 0.96)
    layoutMilestoneArrival()

    let appear: SKAction = UIAccessibility.isReduceMotionEnabled
        ? SKAction.fadeIn(withDuration: 0.15)
        : SKAction.group([
            SKAction.fadeIn(withDuration: 0.15),
            SKAction.scale(to: 1, duration: 0.15)
        ])
    let hold = SKAction.wait(forDuration: 1.20)
    let fade = SKAction.fadeOut(withDuration: 0.15)
    let finish = SKAction.run { [weak self] in
        self?.finishMilestoneArrivalDismissal()
    }
    milestoneArrivalNode.run(
        SKAction.sequence([appear, hold, fade, finish]),
        withKey: "milestoneArrival"
    )
}
```

- [ ] **Step 10: Add consumed-tap and immediate-report dismissal paths**

```swift
private func dismissMilestoneArrival(animated: Bool = true) {
    guard isMilestoneArrivalVisible || !milestoneArrivalNode.isHidden else {
        return
    }
    isMilestoneArrivalVisible = false
    milestoneArrivalNode.removeAction(forKey: "milestoneArrival")

    guard animated else {
        finishMilestoneArrivalDismissal()
        return
    }

    milestoneArrivalNode.run(SKAction.sequence([
        SKAction.fadeOut(withDuration: 0.12),
        SKAction.run { [weak self] in
            self?.finishMilestoneArrivalDismissal()
        }
    ]))
}

private func finishMilestoneArrivalDismissal() {
    isMilestoneArrivalVisible = false
    milestoneArrivalNode.removeAllActions()
    milestoneArrivalNode.alpha = 0
    milestoneArrivalNode.setScale(1)
    milestoneArrivalNode.isHidden = true
}
```

In `handleTouch(at:)`, insert immediately after the existing conquest report / fit-failure branch and before Settings handling:

```swift
if isMilestoneArrivalVisible {
    dismissMilestoneArrival()
    return
}
```

Task 3 uses `dismissMilestoneArrival(animated: false)` before report application so a report never overlaps an arrival fade.

- [ ] **Step 11: Lay out and fit the arrival banner**

```swift
private func layoutMilestoneArrival() {
    guard !milestoneArrivalNode.isHidden else { return }

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
    let centerY = min(
        max(desiredCenterY, safeMinY + height / 2),
        safeMaxY - height / 2
    )
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
    milestoneArrivalTitleLabel.position = CGPoint(
        x: frame.midX,
        y: frame.midY + height * 0.18
    )
    milestoneArrivalSubtitleLabel.position = CGPoint(
        x: frame.midX,
        y: frame.midY - height * 0.18
    )
    fitLabel(milestoneArrivalTitleLabel, maxWidth: frame.width - 24)
    fitLabel(milestoneArrivalSubtitleLabel, maxWidth: frame.width - 24)
}
```

The three-gate test is the acceptance authority for these authored strings. Do not add a new text-layout type.

- [ ] **Step 12: Lay out the static city accent from the real enemy-city frame**

At the tail of `layoutBattlefield(...)`, after the city is fitted/positioned and `layoutCityHPBar()` runs:

```swift
private func layoutMilestoneCityAccent() {
    guard let presentation = currentMilestonePresentation,
          battlefieldLayout.isVisible,
          let enemyCityNode else {
        milestoneCityAccent.isHidden = true
        milestoneCityAccent.path = nil
        return
    }

    applyMilestoneCityAccentStyle(presentation)
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

Do not change enemy-city position/scale, lane gates, HP-bar geometry, or hit routing.

- [ ] **Step 13: Wire mount/layout lifecycle**

In `didMove(to:)`, preserve pending-report authority:

```swift
redraw()

if state.pendingBattleResult != nil, !hasPresentedPendingConquestReport {
    _ = presentPendingConquestReport(origin: .restored, resetsContinueState: true)
} else {
    presentMilestoneArrivalIfNeeded()
}
```

At the end of `layoutInterface()`, call `layoutMilestoneArrival()`. At the tail of the visible `layoutBattlefield(...)` path, call `layoutMilestoneCityAccent()`.

Neither layout method may call a presentation entry point or start a one-shot animation.

- [ ] **Step 14: Add semantic DEBUG accessors**

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

- [ ] **Step 15: Run the focused tests and confirm GREEN**

Run the Step 5 command again.

Expected: PASS.

- [ ] **Step 16: Run the full BattleScene suite**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/BattleSceneTests
```

Expected: PASS, including existing Settings precedence, combat timing, report restoration, narrow portrait, layout, and routing coverage.

- [ ] **Step 17: Commit the arrival/accent slice**

```bash
git add Pyxis/BattleScene.swift PyxisTests/BattleSceneTests.swift
git commit -m "feat: add milestone arrival presentation"
```

---

### Task 3: Add fresh-only conquest flourish and fail-closed City 15 completion

**Files:**
- Modify: `Pyxis/BattleScene.swift` — report accent/finale nodes, required-content fit preflight, `applyPendingConquestReport`, `presentPendingConquestReport`, DEBUG accessors.
- Modify: `PyxisTests/BattleSceneTests.swift` — fresh/restored milestone report tests, City 15 semantic state, three-gate report layout, fail-closed fixture, Continue route.

**Interfaces:**
- Consumes: `BattleResult.cityKey` as report identity authority.
- Consumes: existing `ConquestReportLayout.safeFrame`, `.panelFrame`, `.continueFrame`.
- Consumes: existing BattleScene report fit-failure branch and `.unsupportedGeometry` router callback.
- Produces internally: `countryCompleteFrame(for:)`, `milestoneConquestRequiredContentFits(result:layout:)`, `milestoneConquestAccentFrame(for:presentation:)`, `applyMilestoneConquestPresentation(result:layout:)`, `presentFreshMilestoneConquestFlourishIfNeeded(origin:)`.
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

    scene.handleTouchForTesting(at: gearFrame.center) // consumes arrival only
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

- [ ] **Step 2: Extend fresh and restored City 15 behavior tests**

At the end of existing `battleFinalCityOutcomeEmitsRewardThenCountryCompletion`:

```swift
#expect(scene.countryCompleteTextForTesting == "Country 1 Complete")
#expect(scene.milestoneConquestFlourishCountForTesting == 1)
#expect(!scene.isMilestoneArrivalVisibleForTesting)
```

In existing `countryCompleteContinueRoutesToFinalMapOnce`, before tapping Continue:

```swift
#expect(scene.conquestReportTitleForTesting == "Crownspire Keep Falls")
#expect(scene.countryCompleteTextForTesting == "Country 1 Complete")
#expect(scene.milestoneConquestFlourishCountForTesting == 0)
let finalFrame = try #require(scene.countryCompleteFrameForTesting)
let continueFrame = try #require(scene.popupContinueButtonFrameForTesting)
#expect(!finalFrame.intersects(continueFrame))
```

Keep the existing two taps and assertions unchanged:

```swift
scene.tapConquestContinueForTesting()
scene.tapConquestContinueForTesting()
#expect(router.countryMapRequestCount == 1)
#expect(store.load().pendingBattleResult == nil)
```

- [ ] **Step 3: Add RED three-gate City 15 report-layout test**

```swift
@Test("City 15 milestone report treatment fits supported gates")
func city15MilestoneReportFitsSupportedGates() throws {
    for size in [
        CGSize(width: 568, height: 320),
        CGSize(width: 667, height: 375),
        CGSize(width: 320, height: 568)
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

This is the primary Task 3 go/no-go test.

- [ ] **Step 4: Add RED fail-closed City 15 required-text test**

The existing compact idle City 15 report has three summary rows and no badges by default, so `ConquestReportLayout` computes a 180pt compact panel. At `568×239`, that base report still fits, leaving only 29.5pt above and below a centered panel. The new completion row needs 22pt plus an 8pt gap = 30pt, so this fixture isolates the new HPA-390 required-label failure rather than reproducing the old report-fit failure.

```swift
@Test("City 15 completion fails closed when required label has no safe frame")
func city15CompletionUsesExistingFitFailureWhenLabelCannotFit() throws {
    let size = CGSize(width: 568, height: 239)
    let router = BattleRouterSpy()
    let store = try makeStore(initialState: pendingConqueredState(
        city: 15,
        mode: .idle,
        countryComplete: true
    ))
    let scene = makeScene(store: store, router: router, size: size)

    #expect(scene.isConquestReportFitFailedForTesting)
    #expect(scene.countryCompleteTextForTesting == nil)
    #expect(scene.milestoneConquestAccentFrameForTesting == nil)
    #expect(router.lastLayoutGateReason == .unsupportedGeometry)
    #expect(router.layoutGateRequestCount == 1)
    #expect(store.load().pendingBattleResult != nil)
}
```

- [ ] **Step 5: Run new/extended report tests and confirm RED**

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
  -only-testing:PyxisTests/BattleSceneTests/city15MilestoneReportFitsSupportedGates \
  -only-testing:PyxisTests/BattleSceneTests/city15CompletionUsesExistingFitFailureWhenLabelCannotFit
```

Expected: FAIL because milestone report treatment does not exist.

- [ ] **Step 6: Add the report accent/finale nodes and dedupe state**

Near current conquest report fields:

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

Do not modify `ConquestReportNode`, `ConquestReportContent`, or `ConquestReportLayout`.

- [ ] **Step 7: Compute the City 15 required-label frame**

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

- [ ] **Step 8: Preflight required milestone content before applying the report**

```swift
private func milestoneConquestRequiredContentFits(
    result: BattleResult,
    layout: ConquestReportLayout
) -> Bool {
    guard result.cityKey.countryNumber == 1,
          let presentation = Country1MilestonePresentation.make(
              forCityNumber: result.cityKey.cityNumber
          ),
          presentation.isCountryFinale else {
        return true
    }

    return countryCompleteFrame(for: layout) != nil
}
```

This is intentionally a Boolean preflight, not a new layout/result type.

- [ ] **Step 9: Keep the decorative report accent inside safeFrame**

```swift
private func milestoneConquestAccentFrame(
    for layout: ConquestReportLayout,
    presentation: Country1MilestonePresentation
) -> CGRect {
    let desiredInset: CGFloat
    switch presentation.tier {
    case .first: desiredInset = 5
    case .second: desiredInset = 7
    case .finale: desiredInset = 9
    }

    let availableInset = max(0, min(
        desiredInset,
        layout.panelFrame.minX - layout.safeFrame.minX,
        layout.safeFrame.maxX - layout.panelFrame.maxX,
        layout.panelFrame.minY - layout.safeFrame.minY,
        layout.safeFrame.maxY - layout.panelFrame.maxY
    ))
    return layout.panelFrame.insetBy(dx: -availableInset, dy: -availableInset)
}
```

The accent is decorative, so it clamps rather than expanding the required-layout contract.

- [ ] **Step 10: Apply static milestone report state without one-shot animation**

```swift
private func applyMilestoneConquestPresentation(
    result: BattleResult,
    layout: ConquestReportLayout
) {
    guard result.cityKey.countryNumber == 1,
          let presentation = Country1MilestonePresentation.make(
              forCityNumber: result.cityKey.cityNumber
          ) else {
        milestoneConquestAccent.isHidden = true
        milestoneConquestAccent.path = nil
        countryCompleteLabel.isHidden = true
        return
    }

    let accentFrame = milestoneConquestAccentFrame(
        for: layout,
        presentation: presentation
    )
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

The final-frame optional cannot be nil in a successfully presented City 15 report because Step 8 joins it to the report guard. The defensive `guard` remains local safety, not a second fail-open policy.

- [ ] **Step 11: Join City 15 required text to the existing report fit-failure branch**

In `applyPendingConquestReport(resetsContinueState:)`, immediately after resolving the pending result:

```swift
guard let result = pendingResultForPresentation() else { return false }
dismissMilestoneArrival(animated: false)
```

Then extend the existing guard:

```swift
guard let layout = conquestReportLayout(for: content),
      milestoneConquestRequiredContentFits(result: result, layout: layout),
      conquestReportNode.apply(
          content: content,
          layout: layout,
          isContinueEnabled: isConquestContinueEnabled
      ) == .presented else {
    isConquestReportVisible = true
    isConquestReportFitFailed = true
    conquestReportNode.isHidden = true
    milestoneConquestAccent.isHidden = true
    milestoneConquestAccent.path = nil
    countryCompleteLabel.isHidden = true
    router?.battleScene(self, didRequestLayoutGate: .unsupportedGeometry)
    return false
}

applyMilestoneConquestPresentation(result: result, layout: layout)
```

Preserve the current feedback-settings accessibility call, `isConquestContinueEnabled` reset, content projection, visible flags, and `hasPresentedPendingConquestReport` behavior around this guard.

This is the only fail-closed path; do not create a milestone-specific layout gate.

- [ ] **Step 12: Add fresh-only one-shot flourish at the existing origin boundary**

```swift
private func presentFreshMilestoneConquestFlourishIfNeeded(
    origin: ConquestReportPresentationOrigin
) {
    guard origin != .restored,
          !hasPresentedMilestoneConquestFlourish,
          let result = state.pendingBattleResult,
          result.cityKey.countryNumber == 1,
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

Keep the existing fresh-only gold-burst branch unchanged. Never call the flourish method from `applyPendingConquestReport`, `layoutInterface`, or redraw.

- [ ] **Step 13: Add semantic DEBUG accessors**

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

- [ ] **Step 14: Run new/extended report tests and confirm GREEN**

Run the Step 5 command again.

Expected: PASS.

- [ ] **Step 15: Run all BattleScene tests**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/BattleSceneTests
```

Expected: PASS. Existing restored/fresh effect, fit-failure, Settings, narrow-portrait, and Continue transaction tests must remain green.

- [ ] **Step 16: Commit the conquest slice**

```bash
git add Pyxis/BattleScene.swift PyxisTests/BattleSceneTests.swift
git commit -m "feat: add milestone conquest presentation"
```

---

### Task 4: Document ownership and run full verification

**Files:**
- Modify: `CLAUDE.md` — BattleScene milestone ownership note.
- Verify: `docs/superpowers/specs/2026-08-09-country-1-milestone-presentation-design.md`
- Verify: `docs/superpowers/plans/2026-08-10-country-1-milestone-presentation-implementation.md`

**Interfaces:**
- Produces no runtime API.
- Locks the maintenance boundary: selector is pure/non-persisted; BattleScene owns milestone visuals/lifecycle; shared city/report models remain unchanged.

- [ ] **Step 1: Add the repository ownership note**

Extend the existing `BattleScene` architecture bullet with:

```markdown
Country 1 milestone presentation (HPA-390) is BattleScene-owned. `Country1MilestonePresentation` is only a pure City 5/10/15 tier selector; authored names/flavor/conquest copy remain in `Country1CityCatalog`. Arrival, the static enemy-city accent, fresh-only conquest flourish, Reduce Motion branching, and same-scene dedupe are transient scene state and are never persisted. City 15 adds required `Country 1 Complete` around the existing report; if that label cannot fit, it uses the existing report unsupported-geometry gate. `Crownspire Keep Falls`, report acknowledgement/save, and Country Map routing remain unchanged. Do not add a milestone service/engine, presentation fields to `CityDefinition`, durable consumed-presentation state, or looping city-accent animation without a concrete new requirement.
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
- `ConquestReportContent`, `ConquestReportLayout`, `ConquestReportNode`, persistence, assets, and project registration remain unchanged.
- No milestone service/manager/protocol/registry or persisted state appears.

- [ ] **Step 7: Run the manual City 5 -> 10 -> 15 milestone smoke**

1. **City 5 / Highcrest:** arrival shows `City 5 · Highcrest` + `A proud hill fortress crowns the frontier.`; static accent is modest; one skip tap only hides arrival; combat continues; fresh conquest title remains `Highcrest Falls` and flourish occurs once.
2. **City 10 / Ironthorn Gate:** static arrival/report treatment is stronger than City 5 while reusing the same structure; authored copy remains unchanged.
3. **City 15 / Crownspire Keep:** strongest treatment; conquest title remains `Crownspire Keep Falls`; `Country 1 Complete` is visible before Continue; Continue returns to the completed Country Map exactly once.
4. Repeat one milestone with **Reduce Motion enabled:** required text and framing remain; scale emphasis is absent; the enemy-city accent remains static in both modes.
5. Exercise a fresh idle milestone conquest through background/foreground: flourish occurs once.
6. Recreate a scene with a pending milestone report: static treatment remains, no arrival appears, and no one-shot flourish replays.
7. Check `568×320`, `667×375`, and `320×568`: required arrival/finale text remains readable and Continue stays unobstructed.
8. Confirm gold, HP, rewards, unlocks, lanes, units, buildings, persistence, and progression match ordinary-city behavior.

- [ ] **Step 8: Commit documentation after verification**

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
- Resize/redraw uses layout/application methods only and cannot call arrival/flourish presentation entry points.
- Any report application immediately removes an arrival banner before report nodes are shown.
- City 15 completion text exists for fresh and restored reports; missing required-label geometry routes through existing `isConquestReportFitFailed` / `.unsupportedGeometry` handling.
- `city15MilestoneReportFitsSupportedGates` passes `568×320`, `667×375`, and `320×568` before Task 3 is considered green.
- `city15MilestoneArrivalFitsSupportedGates` passes the same three fixtures before Task 2 is considered green.
- The enemy-city accent is static; no pulse/repeat action is introduced.
- No change to `ConquestReportContent`, `ConquestReportNode`, `ConquestReportLayout`, `KingdomGameState`, `BattleResult`, `Country1CityCatalog`, `CityDefinition`, `KingdomGameStore`, or `GameViewController` is required by this plan.
- No new production file beyond `Country1MilestonePresentation.swift` is required.
- Reduced Motion does not require dependency injection or persistence.
- Existing Continue acknowledgement -> save -> Country Map flow remains the only completion transaction.