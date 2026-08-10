# HPA-390 Country 1 Milestone Presentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make City 5, City 10, and the current Country 1 finale feel like escalating campaign milestones through lightweight presentation only, while preserving existing combat, rewards, persistence, progression, routing, and conquest-report semantics.

**Architecture:** Add one framework-free `Country1MilestoneTier` enum. Keep transient SpriteKit presentation in `BattleScene`, but put required finale geometry in the existing pure `ConquestReportLayout` so it remains the single geometry fail-closed authority. Reuse `PanelNode` for arrival chrome and `SingleLineTextFitter` for explicit minimum-font contracts. The existing `.freshLive` / `.freshIdle` / `.restored` origin remains the only one-shot conquest gate.

**Tech Stack:** Swift 5, SpriteKit, UIKit (`UIAccessibility.isReduceMotionEnabled` and font measurement only), CoreGraphics pure layout, Swift Testing, Xcode/iOS Simulator.

## Global Constraints

- HPA-390 is presentation-only. Do not change combat rules, HP, rewards, unlocks, traits, lanes, buildings, idle progress, or campaign progression.
- Only Country 1 City 5, City 10, and `KingdomGameState.firstCountryCityCount` receive milestone treatment.
- Use a bare enum `Country1MilestoneTier`; do not add a wrapper value, registry, service, manager, protocol, or generic theme object.
- Authored city name/flavor/conquest copy stays in `Country1CityCatalog` / `CityDefinition`.
- City 15 keeps `Crownspire Keep Falls`; `Country 1 Complete` is separate required finale state.
- HPA-390 supersedes only HPA-366's prior presentation rule that overall country completion appears exclusively after Continue. Acknowledge -> save -> Country Map is unchanged.
- Arrival is non-modal; combat continues while visible.
- Arrival tap dismissal is consumed before underlying controls.
- VoiceOver Settings activation must dismiss arrival before opening Settings.
- Arrival geometry/typography is decorative and fails open: if it cannot meet the 12pt minimum, hide it and release input.
- Required finale report geometry belongs in `ConquestReportLayout`; no BattleScene geometry preflight Boolean or above/below fallback.
- Required finale report typography must meet its minimum; failure reuses the existing conquest-report fit-failure path.
- Fresh `.freshLive` / `.freshIdle` milestone reports flourish once; `.restored` reports never replay one-shot effects.
- Pass the successfully resolved `BattleResult` into the flourish; do not re-read `state.pendingBattleResult` for milestone identity.
- Enemy-city accent is static in HPA-390. Do not add a looping/pulsing city-accent animation.
- Read Reduce Motion directly from `UIAccessibility.isReduceMotionEnabled`; no persisted setting/dependency seam.
- No new SFX/haptic event, sound/image asset, milestone engine, durable presentation state, analytics, or history.
- No `project.pbxproj` edits; synchronized Xcode groups discover new files.
- New production files: exactly one, `Pyxis/Country1MilestoneTier.swift`.
- Run simulator tests with `-parallel-testing-enabled NO`.

## File Structure

- Create `Pyxis/Country1MilestoneTier.swift` — pure milestone tier selection only.
- Create `PyxisTests/Country1MilestoneTierTests.swift` — focused selector tests.
- Modify `Pyxis/ConquestReportLayout.swift` — optional required country-completion frame and group reservation.
- Modify `PyxisTests/ConquestReportLayoutTests.swift` — pure finale geometry gates/boundary.
- Modify `Pyxis/BattleScene.swift` — arrival, static city/report accents, Settings/report dismissal, required-label rendering, fresh flourish, semantic DEBUG accessors.
- Modify `PyxisTests/BattleSceneTests.swift` — behavior/accessibility/lifecycle integration tests.
- Modify `CLAUDE.md` — ownership/no-framework guidance after implementation.

---

## Task 1: Add the pure Country 1 milestone tier

**Files:**
- Create: `Pyxis/Country1MilestoneTier.swift`
- Create: `PyxisTests/Country1MilestoneTierTests.swift`

**Interfaces:**
- Produces: `Country1MilestoneTier.forCity(_:) -> Country1MilestoneTier?`
- Produces: `.first`, `.second`, `.finale` raw values `1 / 2 / 3`.
- Produces: `isCountryFinale: Bool`.
- Consumes: `KingdomGameState.firstCountryCityCount` for the finale; no literal second source of truth.

- [ ] **Step 1: Write the failing selector tests**

Create `PyxisTests/Country1MilestoneTierTests.swift`:

```swift
import Testing
@testable import Pyxis

struct Country1MilestoneTierTests {
    @Test("Country 1 milestone cities select the three tiers")
    func selectsMilestoneCities() {
        #expect(Country1MilestoneTier.forCity(5) == .first)
        #expect(Country1MilestoneTier.forCity(10) == .second)
        #expect(
            Country1MilestoneTier.forCity(KingdomGameState.firstCountryCityCount)
                == .finale
        )
    }

    @Test("Ordinary cities are not milestones")
    func ordinaryCitiesReturnNil() {
        for city in [1, 4, 6, 9, 11, 14] {
            #expect(Country1MilestoneTier.forCity(city) == nil)
        }
    }

    @Test("Only finale marks country completion")
    func onlyFinaleMarksCountryCompletion() {
        #expect(Country1MilestoneTier.first.isCountryFinale == false)
        #expect(Country1MilestoneTier.second.isCountryFinale == false)
        #expect(Country1MilestoneTier.finale.isCountryFinale)
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
  -only-testing:PyxisTests/Country1MilestoneTierTests
```

Expected: FAIL because `Country1MilestoneTier` does not exist.

- [ ] **Step 3: Implement the minimal enum**

Create `Pyxis/Country1MilestoneTier.swift`:

```swift
enum Country1MilestoneTier: Int, Equatable {
    case first = 1
    case second = 2
    case finale = 3

    static func forCity(_ cityNumber: Int) -> Country1MilestoneTier? {
        if cityNumber == KingdomGameState.firstCountryCityCount {
            return .finale
        }
        switch cityNumber {
        case 5:
            return .first
        case 10:
            return .second
        default:
            return nil
        }
    }

    var isCountryFinale: Bool {
        self == .finale
    }
}
```

Do not add city strings, country registries, effect constants, UIKit/SpriteKit, or persistence.

- [ ] **Step 4: Re-run and confirm GREEN**

Run Step 2 again.

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Pyxis/Country1MilestoneTier.swift PyxisTests/Country1MilestoneTierTests.swift
git commit -m "feat: add Country 1 milestone tiers"
```

---

## Task 2: Add readable fail-open arrival and static enemy-city accent

**Files:**
- Modify: `Pyxis/BattleScene.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`
- Reuse unchanged: `Pyxis/GameUIComponents.swift` (`PanelNode`)
- Reuse unchanged: `Pyxis/SingleLineTextFitter.swift`

**Interfaces:**
- Consumes: `Country1MilestoneTier.forCity(_:)`.
- Consumes: `Country1CityCatalog.definitionIfPresent(for:)` for authored arrival strings.
- Consumes: `PanelNode.update(size:)`.
- Consumes: `SingleLineTextFitter.fittedFontSize(...)` with an explicit 12pt minimum.
- Produces internally: `currentMilestoneTier`, `fitMilestoneLabel`, `presentMilestoneArrivalIfNeeded`, `layoutMilestoneArrival`, `dismissMilestoneArrival(animated:)`, `finishMilestoneArrivalDismissal`, `layoutMilestoneCityAccent`.

- [ ] **Step 1: Add a normalized milestone state fixture**

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

The existing progression normalization requires `completedCityCount = city - 1`.

- [ ] **Step 2: Write RED tests for authored arrival, non-modal combat, and ordinary cities**

```swift
@Test("City 5 presents authored milestone arrival without pausing combat")
func city5PresentsReadableArrivalWithoutPausingCombat() throws {
    let scene = makeScene(
        store: try makeStore(initialState: activeMilestoneState(city: 5))
    )

    #expect(scene.milestoneTierForTesting == 1)
    #expect(scene.isMilestoneArrivalVisibleForTesting)
    #expect(scene.milestoneArrivalTitleForTesting == "City 5 · Highcrest")
    #expect(scene.milestoneArrivalSubtitleForTesting == "A proud hill fortress crowns the frontier.")
    #expect(scene.milestoneArrivalMinimumFontSizeForTesting >= 12)
    #expect(scene.milestoneCityAccentFrameForTesting != nil)

    scene.update(10)
    scene.update(11)
    #expect(scene.lastAdvanceCombatDeltaForTesting == 1)
}

@Test("Ordinary cities create no milestone presentation")
func ordinaryCityHasNoMilestonePresentation() throws {
    let scene = makeScene(store: try makeStore(initialState: KingdomGameState(
        cityLevel: 6,
        cityNumberInCountry: 6,
        completedCityCount: 5
    )))

    #expect(scene.milestoneTierForTesting == nil)
    #expect(!scene.isMilestoneArrivalVisibleForTesting)
    #expect(scene.milestoneCityAccentFrameForTesting == nil)
}
```

- [ ] **Step 3: Write RED touch-precedence and same-scene dedupe tests**

```swift
@Test("Arrival consumes one Settings-gear tap and the next tap opens Settings")
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

@Test("Arrival does not replay on didMove redraw or layout refresh")
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

- [ ] **Step 4: Write the RED VoiceOver Settings-path regression test**

Mirror the existing retained-accessibility-element test pattern:

```swift
@Test("VoiceOver Settings activation dismisses milestone arrival before opening")
func milestoneArrivalDismissesForAccessibilitySettingsActivation() throws {
    let size = CGSize(width: 390, height: 844)
    let containerView = UIView(frame: CGRect(origin: .zero, size: size))
    let adapter = FeedbackSettingsAccessibilityAdapter(
        containerView: containerView,
        sceneToScreenFrame: { $0 },
        postNotification: { _, _ in }
    )
    let scene = makeScene(
        store: try makeStore(initialState: activeMilestoneState(city: 5)),
        size: size,
        feedbackSettingsAccessibilityAdapter: adapter
    )
    let retainedGear = try #require(accessibilityElements(in: containerView).onlyElement)

    #expect(scene.isMilestoneArrivalVisibleForTesting)
    #expect(retainedGear.accessibilityActivate())

    #expect(!scene.isMilestoneArrivalVisibleForTesting)
    #expect(scene.isFeedbackSettingsVisibleForTesting)
}
```

This test is required because `onGearActivate` calls `openFeedbackSettings()` directly and does not pass through `handleTouch(at:)`.

- [ ] **Step 5: Write RED supported-layout legibility gates**

```swift
@Test("Finale arrival stays readable at supported narrow and landscape gates")
func finaleArrivalFitsSupportedGates() throws {
    for size in [
        CGSize(width: 568, height: 320),
        CGSize(width: 667, height: 375),
        CGSize(width: 320, height: 568)
    ] {
        let scene = makeScene(
            store: try makeStore(initialState: activeMilestoneState(
                city: KingdomGameState.firstCountryCityCount
            )),
            size: size
        )
        let banner = try #require(scene.milestoneArrivalFrameForTesting)
        let title = try #require(scene.milestoneArrivalTitleFrameForTesting)
        let subtitle = try #require(scene.milestoneArrivalSubtitleFrameForTesting)

        #expect(banner.contains(title))
        #expect(banner.contains(subtitle))
        #expect(!title.intersects(subtitle))
        #expect(scene.milestoneArrivalTitleFontSizeForTesting >= 12)
        #expect(scene.milestoneArrivalSubtitleFontSizeForTesting >= 12)
    }
}
```

- [ ] **Step 6: Write RED fail-open test for unusable arrival geometry**

```swift
@Test("Arrival layout failure releases input instead of leaving an invisible interceptor")
func milestoneArrivalFailsOpenOnUnusableGeometry() throws {
    let scene = makeScene(
        store: try makeStore(initialState: activeMilestoneState(city: 5)),
        size: CGSize(width: 110, height: 568)
    )

    #expect(!scene.isMilestoneArrivalVisibleForTesting)
    #expect(scene.milestoneArrivalFrameForTesting == nil)
}
```

The production touch branch keys off `isMilestoneArrivalVisible`; clearing that flag proves the failed banner cannot swallow the next touch.

- [ ] **Step 7: Run focused tests and confirm RED**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/BattleSceneTests/city5PresentsReadableArrivalWithoutPausingCombat \
  -only-testing:PyxisTests/BattleSceneTests/milestoneArrivalConsumesUnderlyingTap \
  -only-testing:PyxisTests/BattleSceneTests/milestoneArrivalDismissesForAccessibilitySettingsActivation \
  -only-testing:PyxisTests/BattleSceneTests/finaleArrivalFitsSupportedGates \
  -only-testing:PyxisTests/BattleSceneTests/milestoneArrivalFailsOpenOnUnusableGeometry
```

Expected: FAIL because milestone presentation does not exist.

- [ ] **Step 8: Add scene-local arrival/accent state**

Near existing HUD/report fields:

```swift
private let milestoneArrivalPanel = PanelNode(size: .zero)
private let milestoneArrivalTitleLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
private let milestoneArrivalSubtitleLabel = SKLabelNode(fontNamed: GameUITheme.Font.medium)
private let milestoneCityAccent = SKShapeNode()
private var hasPresentedMilestoneArrival = false
private var isMilestoneArrivalVisible = false
#if DEBUG
private var milestoneArrivalPresentationCountForTestingStorage = 0
#endif

private var currentMilestoneTier: Country1MilestoneTier? {
    guard state.currentCityKey.countryNumber == 1 else { return nil }
    return Country1MilestoneTier.forCity(state.currentCityKey.cityNumber)
}
```

- [ ] **Step 9: Reuse `SingleLineTextFitter` through one small scene adapter**

`SingleLineTextFitter` already is the shared helper; do not modify `ConquestReportNode` or create another utility file.

```swift
private func fitMilestoneLabel(
    _ label: SKLabelNode,
    fontName: String,
    startingAt: CGFloat,
    minimum: CGFloat,
    maximumWidth: CGFloat
) -> Bool {
    guard let text = label.text,
          let size = SingleLineTextFitter.fittedFontSize(
              text,
              startingAt: startingAt,
              minimum: minimum,
              maximumWidth: maximumWidth,
              measure: { candidate, fontSize in
                  let font = UIFont(name: fontName, size: fontSize)
                      ?? UIFont.systemFont(ofSize: fontSize)
                  return (candidate as NSString).size(withAttributes: [.font: font]).width
              }
          ) else {
        return false
    }
    label.fontName = fontName
    label.fontSize = size
    return true
}
```

- [ ] **Step 10: Configure `PanelNode` arrival and static city accent once**

In `buildInterface()`:

```swift
milestoneArrivalPanel.zPosition = GameUITheme.Z.modal - 1
milestoneArrivalPanel.isHidden = true
milestoneArrivalTitleLabel.fontColor = GameUITheme.Color.textPrimary
milestoneArrivalTitleLabel.horizontalAlignmentMode = .center
milestoneArrivalTitleLabel.verticalAlignmentMode = .center
milestoneArrivalSubtitleLabel.fontColor = GameUITheme.Color.textSecondary
milestoneArrivalSubtitleLabel.horizontalAlignmentMode = .center
milestoneArrivalSubtitleLabel.verticalAlignmentMode = .center
milestoneArrivalPanel.addChild(milestoneArrivalTitleLabel)
milestoneArrivalPanel.addChild(milestoneArrivalSubtitleLabel)
addChild(milestoneArrivalPanel)

milestoneCityAccent.fillColor = .clear
milestoneCityAccent.strokeColor = GameUITheme.Color.gold
milestoneCityAccent.isHidden = true
environmentLayer.addChild(milestoneCityAccent)
```

Do not hand-build a second themed rounded panel path; `PanelNode.update(size:)` already owns it.

- [ ] **Step 11: Implement fail-open arrival layout with a real font floor**

```swift
@discardableResult
private func layoutMilestoneArrival() -> Bool {
    guard isMilestoneArrivalVisible || hasPresentedMilestoneArrival else { return false }

    let metrics = layoutMetrics()
    let insets = view?.safeAreaInsets ?? .zero
    let safeWidth = size.width - insets.left - insets.right
    let safeHeight = size.height - insets.top - insets.bottom
    let width = min(metrics.contentWidth, safeWidth - 24)
    let height: CGFloat = metrics.compactHeight ? 64 : 76
    guard width >= 120, safeHeight >= height + 24 else {
        finishMilestoneArrivalDismissal()
        return false
    }

    let safeMinY = insets.bottom + 12
    let safeMaxY = size.height - insets.top - 12
    let desiredCenterY = battlefieldLayout.isVisible
        ? battlefieldLayout.frame.midY
        : (safeMinY + safeMaxY) / 2
    let centerY = min(max(desiredCenterY, safeMinY + height / 2), safeMaxY - height / 2)

    milestoneArrivalPanel.update(size: CGSize(width: width, height: height))
    milestoneArrivalPanel.position = CGPoint(x: size.width / 2, y: centerY)
    milestoneArrivalTitleLabel.position = CGPoint(x: 0, y: height * 0.18)
    milestoneArrivalSubtitleLabel.position = CGPoint(x: 0, y: -height * 0.18)

    let titleFits = fitMilestoneLabel(
        milestoneArrivalTitleLabel,
        fontName: GameUITheme.Font.bold,
        startingAt: metrics.compactHeight ? 17 : 20,
        minimum: 12,
        maximumWidth: width - 24
    )
    let subtitleFits = fitMilestoneLabel(
        milestoneArrivalSubtitleLabel,
        fontName: GameUITheme.Font.medium,
        startingAt: metrics.compactHeight ? 12 : 14,
        minimum: 12,
        maximumWidth: width - 24
    )
    let localBounds = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)
    guard titleFits,
          subtitleFits,
          localBounds.contains(milestoneArrivalTitleLabel.frame),
          localBounds.contains(milestoneArrivalSubtitleLabel.frame),
          !milestoneArrivalTitleLabel.frame.intersects(milestoneArrivalSubtitleLabel.frame) else {
        finishMilestoneArrivalDismissal()
        return false
    }
    return true
}
```

Any early return must release `isMilestoneArrivalVisible`; do not leave a nil/stale panel intercepting touches.

- [ ] **Step 12: Present, auto-dismiss, and skip arrival without pausing combat**

```swift
private func presentMilestoneArrivalIfNeeded() {
    guard state.stageStatus == .battleActive,
          state.pendingBattleResult == nil,
          currentMilestoneTier != nil,
          !hasPresentedMilestoneArrival,
          let definition = Country1CityCatalog.definitionIfPresent(
              for: state.currentCityKey.cityNumber
          ) else {
        return
    }

    hasPresentedMilestoneArrival = true
    isMilestoneArrivalVisible = true
    milestoneArrivalTitleLabel.text = definition.displayTitle
    milestoneArrivalSubtitleLabel.text = definition.flavorText
    guard layoutMilestoneArrival() else { return }

    milestoneArrivalPanel.isHidden = false
    milestoneArrivalPanel.alpha = 0
    milestoneArrivalPanel.setScale(UIAccessibility.isReduceMotionEnabled ? 1 : 0.97)
    #if DEBUG
    milestoneArrivalPresentationCountForTestingStorage += 1
    #endif

    let appear = UIAccessibility.isReduceMotionEnabled
        ? SKAction.fadeIn(withDuration: 0.15)
        : SKAction.group([
            SKAction.fadeIn(withDuration: 0.15),
            SKAction.scale(to: 1, duration: 0.15)
        ])
    let wait = SKAction.wait(forDuration: 1.15)
    let disappear = SKAction.fadeOut(withDuration: 0.20)
    let finish = SKAction.run { [weak self] in
        self?.finishMilestoneArrivalDismissal()
    }
    milestoneArrivalPanel.run(
        SKAction.sequence([appear, wait, disappear, finish]),
        withKey: "milestoneArrival"
    )
}

private func finishMilestoneArrivalDismissal() {
    milestoneArrivalPanel.removeAllActions()
    milestoneArrivalPanel.isHidden = true
    milestoneArrivalPanel.alpha = 1
    milestoneArrivalPanel.setScale(1)
    isMilestoneArrivalVisible = false
}

private func dismissMilestoneArrival(animated: Bool = true) {
    guard isMilestoneArrivalVisible else { return }
    milestoneArrivalPanel.removeAllActions()
    guard animated else {
        finishMilestoneArrivalDismissal()
        return
    }
    milestoneArrivalPanel.run(SKAction.sequence([
        SKAction.fadeOut(withDuration: 0.10),
        SKAction.run { [weak self] in self?.finishMilestoneArrivalDismissal() }
    ]))
}
```

Do not add arrival visibility to the combat `update` guard.

- [ ] **Step 13: Wire lifecycle and all input paths**

In `didMove(to:)`, preserve report authority:

```swift
redraw()
if state.pendingBattleResult != nil, !hasPresentedPendingConquestReport {
    _ = presentPendingConquestReport(origin: .restored, resetsContinueState: true)
} else {
    presentMilestoneArrivalIfNeeded()
}
```

In `handleTouch(at:)`, after conquest-report handling and before Settings:

```swift
if isMilestoneArrivalVisible {
    dismissMilestoneArrival()
    return
}
```

At the top of `openFeedbackSettings()` after the existing guard succeeds but before `feedbackSettingsController.open()`:

```swift
dismissMilestoneArrival(animated: false)
```

At the end of `layoutInterface()`, call `layoutMilestoneArrival()` only when visible. It may reposition but never calls `presentMilestoneArrivalIfNeeded()`.

- [ ] **Step 14: Lay out a static enemy-city accent from the rendered city frame**

At the end of normal battlefield structure positioning:

```swift
private func layoutMilestoneCityAccent() {
    guard let tier = currentMilestoneTier,
          battlefieldLayout.isVisible,
          let enemyCityNode else {
        milestoneCityAccent.isHidden = true
        milestoneCityAccent.path = nil
        return
    }

    let cityFrame = enemyCityNode.calculateAccumulatedFrame()
    let expansion: CGFloat
    switch tier {
    case .first: expansion = 5
    case .second: expansion = 7
    case .finale: expansion = 9
    }

    let insets = view?.safeAreaInsets ?? .zero
    let safeFrame = CGRect(
        x: insets.left,
        y: insets.bottom,
        width: max(0, size.width - insets.left - insets.right),
        height: max(0, size.height - insets.top - insets.bottom)
    )
    let accentFrame = cityFrame
        .insetBy(dx: -expansion, dy: -expansion)
        .intersection(safeFrame)
    guard !accentFrame.isNull, accentFrame.width > 0, accentFrame.height > 0 else {
        milestoneCityAccent.isHidden = true
        milestoneCityAccent.path = nil
        return
    }

    milestoneCityAccent.path = CGPath(
        roundedRect: accentFrame,
        cornerWidth: 12,
        cornerHeight: 12,
        transform: nil
    )
    switch tier {
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
    milestoneCityAccent.isHidden = false
}
```

No action/pulse is installed on `milestoneCityAccent`.

- [ ] **Step 15: Add semantic DEBUG accessors only**

Expose tier, visibility/count/copy, arrival/panel/label frames, title/subtitle font sizes, and city accent frame. Do not expose style constants or private node arrays.

- [ ] **Step 16: Run focused + full BattleScene tests**

Run Step 7 again, then:

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/BattleSceneTests
```

Expected: PASS.

- [ ] **Step 17: Commit**

```bash
git add Pyxis/BattleScene.swift PyxisTests/BattleSceneTests.swift
git commit -m "feat: add milestone arrival presentation"
```

---

## Task 3: Put finale geometry in ConquestReportLayout and add fresh-only report treatment

**Files:**
- Modify: `Pyxis/ConquestReportLayout.swift`
- Modify: `PyxisTests/ConquestReportLayoutTests.swift`
- Modify: `Pyxis/BattleScene.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`

**Interfaces:**
- `ConquestReportLayout.Input` gains `includesCountryCompletion: Bool`.
- `ConquestReportLayout` gains `countryCompleteFrame: CGRect?`.
- Existing no-completion panel geometry remains identical.
- `BattleScene.applyPendingConquestReport` returns the successfully resolved `BattleResult?` rather than only `Bool`, so `presentPendingConquestReport` can pass that exact result into the flourish.

### Part A — pure required geometry

- [ ] **Step 1: Update the layout-test helper and write RED no-regression test**

Change the helper signature:

```swift
private func makeLayout(
    size: CGSize = CGSize(width: 375, height: 667),
    insets: ConquestReportSafeAreaInsets = .init(top: 0, left: 0, bottom: 0, right: 0),
    rows: Int,
    achievements: Int,
    includesCountryCompletion: Bool = false
) -> ConquestReportLayout? {
    let compactHeight = size.height < 500
    let horizontalMargin = max(8, min(compactHeight ? 16 : 18, size.width * 0.045))
    let battleContentWidth = min(max(0, size.width - horizontalMargin * 2), 560)
    return ConquestReportLayout.compute(.init(
        sceneSize: size,
        safeAreaInsets: insets,
        battleContentWidth: battleContentWidth,
        summaryRowCount: rows,
        achievementCount: achievements,
        compactHeight: compactHeight,
        includesCountryCompletion: includesCountryCompletion
    ))
}
```

Existing tests should continue to call the helper without the new flag and preserve exact panel heights.

- [ ] **Step 2: Write RED pure supported-geometry tests for maximum current report density**

```swift
@Test("Country completion fits all HPA-390 supported geometry gates")
func countryCompletionFitsSupportedGates() throws {
    for size in [
        CGSize(width: 568, height: 320),
        CGSize(width: 667, height: 375),
        CGSize(width: 320, height: 568)
    ] {
        let layout = try #require(makeLayout(
            size: size,
            rows: 4,
            achievements: 2,
            includesCountryCompletion: true
        ))
        let completion = try #require(layout.countryCompleteFrame)

        #expect(layout.safeFrame.contains(layout.panelFrame))
        #expect(layout.safeFrame.contains(completion))
        #expect(!completion.intersects(layout.panelFrame))
        #expect(!completion.intersects(layout.continueFrame))
        #expect(layout.panelFrame.contains(layout.titleFrame))
        #expect(layout.summaryRowFrames.allSatisfy { layout.panelFrame.contains($0) })
        #expect(layout.badgeFrames.allSatisfy { layout.panelFrame.contains($0) })
    }
}
```

- [ ] **Step 3: Write RED pure fail-closed discriminator with several points of margin**

```swift
@Test("Country completion reservation is the reason a compact boundary fails")
func countryCompletionFailsClosedAtPureBoundary() throws {
    let size = CGSize(width: 568, height: 205)

    let base = try #require(makeLayout(
        size: size,
        rows: 3,
        achievements: 0,
        includesCountryCompletion: false
    ))
    #expect(base.panelFrame.height == 180)
    #expect(base.countryCompleteFrame == nil)

    #expect(makeLayout(
        size: size,
        rows: 3,
        achievements: 0,
        includesCountryCompletion: true
    ) == nil)
}
```

Current compact metrics make the completion group 210pt, so the base report fits with 25pt spare while the completion version misses by 5pt. If report metrics change enough to invalidate that discriminator, this test fails explicitly instead of silently testing a different branch.

- [ ] **Step 4: Run pure layout tests and confirm RED**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/ConquestReportLayoutTests
```

Expected: FAIL because the completion input/frame do not exist.

- [ ] **Step 5: Extend `ConquestReportLayout` with one required-content flag/frame**

Add to `Input`:

```swift
let includesCountryCompletion: Bool
```

Add to `Metrics`:

```swift
let countryCompletionLine: CGFloat
let countryCompletionGap: CGFloat
```

Initialize:

```swift
countryCompletionLine = compact ? 22 : 26
countryCompletionGap = 8
```

Add to output:

```swift
let countryCompleteFrame: CGRect?
```

Compute existing report-panel height separately from the centered group:

```swift
let reportPanelHeight = panelHeight(
    metrics: metrics,
    summaryRowCount: input.summaryRowCount,
    achievementCount: input.achievementCount
)
let completionReservation = input.includesCountryCompletion
    ? metrics.countryCompletionGap + metrics.countryCompletionLine
    : 0
let groupHeight = reportPanelHeight + completionReservation
guard groupHeight <= safeHeight else { return nil }

let panelX = safeFrame.midX - panelWidth / 2
let groupMinY = safeFrame.midY - groupHeight / 2
let panelFrame = CGRect(
    x: panelX,
    y: groupMinY,
    width: panelWidth,
    height: reportPanelHeight
)
let countryCompleteFrame = input.includesCountryCompletion
    ? CGRect(
        x: panelX,
        y: panelFrame.maxY + metrics.countryCompletionGap,
        width: panelWidth,
        height: metrics.countryCompletionLine
    )
    : nil
```

The existing cursor/layout inside `panelFrame` stays unchanged.

Add `countryCompleteFrame` to `ComputedFrames` and `framesAreContained`:

```swift
if let countryCompleteFrame = frames.countryCompleteFrame {
    guard frames.safeFrame.contains(countryCompleteFrame),
          !countryCompleteFrame.intersects(frames.panelFrame),
          !countryCompleteFrame.intersects(frames.continueFrame) else {
        return false
    }
}
```

Return the frame in `ConquestReportLayout`.

Do not add an above/below fallback; the group reservation makes fallback unnecessary.

- [ ] **Step 6: Run pure layout tests and confirm GREEN**

Run Step 4 again.

Expected: PASS, including all pre-existing exact-height tests for `includesCountryCompletion == false`.

### Part B — BattleScene report integration

- [ ] **Step 7: Write RED restored/fresh/finale integration tests**

Add:

```swift
@Test("Restored City 10 gets static milestone treatment without flourish replay")
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

Extend the existing restored finale Continue test:

```swift
#expect(scene.conquestReportTitleForTesting == "Crownspire Keep Falls")
#expect(scene.countryCompleteTextForTesting == "Country 1 Complete")
#expect(scene.countryCompleteFrameForTesting != nil)
#expect(scene.milestoneConquestFlourishCountForTesting == 0)
```

Keep its existing two-tap Continue assertions unchanged.

- [ ] **Step 8: Write RED fresh-result identity/dedupe test**

```swift
@Test("Fresh City 5 flourish uses the applied result once")
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
    scene.dismissMilestoneArrivalForTesting()

    scene.spawnSoldierForTesting()
    scene.advanceCombatForTesting(deltaTime: 3)

    #expect(scene.lastConquestReportOriginForTesting == "freshLive")
    #expect(scene.milestoneConquestFlourishCountForTesting == 1)
    #expect(scene.lastMilestoneFlourishCityForTesting == 5)

    let count = scene.milestoneConquestFlourishCountForTesting
    scene.redrawForTesting(shouldLayout: true)
    scene.refreshLayoutForCurrentEnvironment()
    #expect(scene.milestoneConquestFlourishCountForTesting == count)
}
```

`lastMilestoneFlourishCityForTesting` is DEBUG-only and records the `result.cityKey.cityNumber` passed into the flourish; do not expose/persist a second runtime identity.

- [ ] **Step 9: Write RED existing-gate integration test for required finale geometry**

Pure layout tests already prove why the geometry fails. BattleScene only needs to prove the existing route is reused:

```swift
@Test("Finale completion layout failure reuses Battle unsupported-geometry gate")
func finaleCompletionLayoutFailureUsesExistingGate() throws {
    let router = BattleRouterSpy()
    let scene = makeScene(
        store: try makeStore(initialState: pendingConqueredState(
            city: KingdomGameState.firstCountryCityCount,
            mode: .idle,
            countryComplete: true
        )),
        router: router,
        size: CGSize(width: 568, height: 205)
    )

    #expect(scene.isConquestReportFitFailedForTesting)
    #expect(!scene.isConquestPopupVisibleForTesting)
    #expect(router.lastLayoutGateReason == .unsupportedGeometry)
}
```

- [ ] **Step 10: Run the new report integration tests and confirm RED**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/BattleSceneTests/restoredCity10ReportDoesNotReplayMilestoneFlourish \
  -only-testing:PyxisTests/BattleSceneTests/freshCity5ConquestPresentsMilestoneFlourishOnce \
  -only-testing:PyxisTests/BattleSceneTests/countryCompleteContinueRoutesToFinalMapOnce \
  -only-testing:PyxisTests/BattleSceneTests/finaleCompletionLayoutFailureUsesExistingGate
```

Expected: FAIL because report milestone integration does not exist.

- [ ] **Step 11: Add scene-owned report nodes**

Near existing conquest fields:

```swift
private let milestoneConquestAccent = SKShapeNode()
private let countryCompleteLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
private var hasPresentedMilestoneConquestFlourish = false
#if DEBUG
private var milestoneConquestFlourishCountForTestingStorage = 0
private var lastMilestoneFlourishCityForTestingStorage: Int?
#endif
```

Configure once:

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

- [ ] **Step 12: Make report layout identity-aware using the resolved result**

Change the private helper to:

```swift
private func conquestReportLayout(
    for content: ConquestReportContent,
    result: BattleResult
) -> ConquestReportLayout? {
    let metrics = layoutMetrics()
    let insets = view?.safeAreaInsets ?? .zero
    let tier = result.cityKey.countryNumber == 1
        ? Country1MilestoneTier.forCity(result.cityKey.cityNumber)
        : nil
    let input = ConquestReportLayout.Input(
        sceneSize: size,
        safeAreaInsets: .init(
            top: insets.top,
            left: insets.left,
            bottom: insets.bottom,
            right: insets.right
        ),
        battleContentWidth: metrics.contentWidth,
        summaryRowCount: content.summaryLines.count,
        achievementCount: content.achievements.count,
        compactHeight: metrics.compactHeight,
        includesCountryCompletion: tier?.isCountryFinale == true
    )
    #if DEBUG
    lastConquestReportLayoutInputForTestingStorage = input
    #endif
    return .compute(input)
}
```

Update every production/test call site to pass the same `BattleResult` that owns the report identity. Do not derive completion from ambient `stageStatus`.

- [ ] **Step 13: Apply static milestone report treatment and required finale text**

Use one method whose `Bool` represents rendering/typography fit only; geometry has already been decided by `ConquestReportLayout`:

```swift
private func applyMilestoneConquestPresentation(
    result: BattleResult,
    layout: ConquestReportLayout
) -> Bool {
    let tier = result.cityKey.countryNumber == 1
        ? Country1MilestoneTier.forCity(result.cityKey.cityNumber)
        : nil
    guard let tier else {
        milestoneConquestAccent.isHidden = true
        milestoneConquestAccent.path = nil
        countryCompleteLabel.isHidden = true
        return true
    }

    let expansion: CGFloat
    switch tier {
    case .first: expansion = 5
    case .second: expansion = 7
    case .finale: expansion = 9
    }
    var accentFrame = layout.panelFrame
        .insetBy(dx: -expansion, dy: -expansion)
        .intersection(layout.safeFrame)
    if let completion = layout.countryCompleteFrame,
       accentFrame.maxY > completion.minY - 2 {
        accentFrame.size.height = max(0, completion.minY - 2 - accentFrame.minY)
    }
    if accentFrame.width > 0, accentFrame.height > 0 {
        milestoneConquestAccent.path = CGPath(
            roundedRect: accentFrame,
            cornerWidth: layout.panelCornerRadius + 4,
            cornerHeight: layout.panelCornerRadius + 4,
            transform: nil
        )
        milestoneConquestAccent.isHidden = false
    } else {
        milestoneConquestAccent.isHidden = true
        milestoneConquestAccent.path = nil
    }

    switch tier {
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

    guard tier.isCountryFinale else {
        countryCompleteLabel.isHidden = true
        return true
    }
    guard let frame = layout.countryCompleteFrame else {
        assertionFailure("Finale report layout omitted required Country 1 Complete frame")
        return false
    }

    countryCompleteLabel.text = "Country 1 Complete"
    countryCompleteLabel.position = CGPoint(x: frame.midX, y: frame.midY)
    let fits = fitMilestoneLabel(
        countryCompleteLabel,
        fontName: GameUITheme.Font.bold,
        startingAt: layoutMetrics().compactHeight ? 15 : 18,
        minimum: 15,
        maximumWidth: frame.width
    )
    countryCompleteLabel.isHidden = !fits
    return fits
}
```

This keeps the required/decorative asymmetry: label typography failure fails the report; accent clipping/hiding never does.

- [ ] **Step 14: Return the resolved result from `applyPendingConquestReport`**

Change:

```swift
@discardableResult
private func applyPendingConquestReport(
    resetsContinueState: Bool
) -> BattleResult? {
    guard let result = pendingResultForPresentation() else { return nil }
    dismissMilestoneArrival(animated: false)
    feedbackSettingsController?.setSettingsAccessibilityActionable(false)
    if resetsContinueState { isConquestContinueEnabled = true }
    let content = conquestReportContent(for: result)
    lastAppliedConquestReportContent = content

    guard let layout = conquestReportLayout(for: content, result: result),
          conquestReportNode.apply(
              content: content,
              layout: layout,
              isContinueEnabled: isConquestContinueEnabled
          ) == .presented,
          applyMilestoneConquestPresentation(result: result, layout: layout) else {
        isConquestReportVisible = true
        isConquestReportFitFailed = true
        conquestReportNode.isHidden = true
        milestoneConquestAccent.isHidden = true
        countryCompleteLabel.isHidden = true
        router?.battleScene(self, didRequestLayoutGate: .unsupportedGeometry)
        return nil
    }

    isConquestReportVisible = true
    isConquestReportFitFailed = false
    hasPresentedPendingConquestReport = true
    return result
}
```

Update callers:

- layout/redraw: `_ = applyPendingConquestReport(resetsContinueState: false)` remains valid;
- Continue: `guard applyPendingConquestReport(resetsContinueState: false) != nil else { ... }`;
- presentation: unwrap the result as Step 15.

- [ ] **Step 15: Pass that exact result into the fresh-only flourish**

```swift
private func presentFreshMilestoneConquestFlourishIfNeeded(
    result: BattleResult,
    origin: ConquestReportPresentationOrigin
) {
    guard origin != .restored,
          !hasPresentedMilestoneConquestFlourish,
          result.cityKey.countryNumber == 1,
          Country1MilestoneTier.forCity(result.cityKey.cityNumber) != nil else {
        return
    }

    hasPresentedMilestoneConquestFlourish = true
    #if DEBUG
    milestoneConquestFlourishCountForTestingStorage += 1
    lastMilestoneFlourishCityForTestingStorage = result.cityKey.cityNumber
    #endif

    milestoneConquestAccent.removeAllActions()
    milestoneConquestAccent.alpha = 0.45
    milestoneConquestAccent.setScale(UIAccessibility.isReduceMotionEnabled ? 1 : 0.97)
    let fade = SKAction.fadeAlpha(to: 1, duration: 0.24)
    let emphasis = UIAccessibility.isReduceMotionEnabled
        ? fade
        : SKAction.group([fade, SKAction.scale(to: 1, duration: 0.24)])
    milestoneConquestAccent.run(emphasis)
}
```

Change `presentPendingConquestReport`:

```swift
guard let result = applyPendingConquestReport(
    resetsContinueState: resetsContinueState
) else {
    return false
}
#if DEBUG
lastConquestReportOriginForTestingStorage = origin
conquestEffectPresentationCountForTestingStorage += origin == .restored ? 0 : 1
#endif
presentFreshMilestoneConquestFlourishIfNeeded(result: result, origin: origin)
if origin != .restored,
   let anchor = conquestReportNode.goldEffectAnchor(in: self) {
    playGoldBurst(at: anchor)
}
return true
```

Do not read `state.pendingBattleResult` inside the flourish.

- [ ] **Step 16: Add semantic DEBUG accessors**

Expose only:

- milestone flourish count;
- last flourish city number;
- report accent frame;
- `Country 1 Complete` text/frame;
- a testing-only arrival dismissal method used by fresh-conquest fixtures if needed.

Do not expose style constants/actions or a second layout model.

- [ ] **Step 17: Run Task 3 GREEN checks**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/ConquestReportLayoutTests \
  -only-testing:PyxisTests/BattleSceneTests
```

Expected: PASS. In particular, existing `deterministicHeightsMatchConstants`, `restoredPendingReportIsStatic`, `liveConquestUsesFreshLiveEffectsOnce`, `battleForegroundIdleUsesFreshIdleGoldOnly`, `repeatedDidMoveResizeAndRedrawDoNotDuplicateOrReplay`, and `countryCompleteContinueRoutesToFinalMapOnce` remain green.

- [ ] **Step 18: Commit**

```bash
git add \
  Pyxis/ConquestReportLayout.swift \
  PyxisTests/ConquestReportLayoutTests.swift \
  Pyxis/BattleScene.swift \
  PyxisTests/BattleSceneTests.swift
git commit -m "feat: add milestone conquest presentation"
```

---

## Task 4: Document ownership and run full verification

**Files:**
- Modify: `CLAUDE.md`
- Verify: `docs/superpowers/specs/2026-08-09-country-1-milestone-presentation-design.md`
- Verify: `docs/superpowers/plans/2026-08-10-country-1-milestone-presentation-implementation.md`

**Interfaces:**
- Produces no runtime API.
- Locks maintenance boundary: pure tier selector, pure required report geometry, scene-owned transient rendering, no persistence/framework.

- [ ] **Step 1: Add concise architecture ownership guidance**

Append to the existing BattleScene architecture notes:

```markdown
Country 1 milestone presentation (HPA-390) is intentionally split by existing ownership: `Country1MilestoneTier` is only the pure City 5/10/finale selector; `ConquestReportLayout` owns required `Country 1 Complete` geometry and returns nil when it cannot fit; `BattleScene` owns transient arrival/accent/flourish nodes and same-scene dedupe. Authored city copy remains in `Country1CityCatalog`, `SingleLineTextFitter` is the shared minimum-font fitter, and no milestone state is persisted. Arrival is decorative and fails open; required finale report content fails closed through the existing report layout gate. Do not add a milestone service/engine, presentation fields to `CityDefinition`, durable consumed state, or a second report-geometry authority without a concrete requirement.
```

Do not edit `AGENTS.md`; it is a symlink.

- [ ] **Step 2: Run focused selector/layout/BattleScene tests**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/Country1MilestoneTierTests \
  -only-testing:PyxisTests/ConquestReportLayoutTests \
  -only-testing:PyxisTests/BattleSceneTests
```

Expected: PASS.

- [ ] **Step 3: Run full unit suite**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests
```

Expected: PASS.

- [ ] **Step 4: Run full UI suite**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisUITests
```

Expected: PASS.

- [ ] **Step 5: Run lint and diff hygiene**

```bash
swiftlint lint --no-cache
git diff --check origin/main...HEAD
```

Expected: SwiftLint exit 0 with no new serious findings; diff check clean.

- [ ] **Step 6: Prove scope remains narrow**

```bash
git diff --name-only origin/main...HEAD
git diff --numstat origin/main...HEAD -- ':(glob)Pyxis/*.swift'
git grep -n -E 'Milestone.*(Service|Manager|Protocol|Registry)|milestone.*(UserDefaults|Codable|persist)' -- Pyxis || true
```

Expected production shape:

- one new file: `Pyxis/Country1MilestoneTier.swift`;
- runtime edits concentrated in `BattleScene.swift` and the existing pure `ConquestReportLayout.swift`;
- no `ConquestReportContent` / `ConquestReportNode` change;
- no milestone persistence/service/registry/assets/project-file edits.

- [ ] **Step 7: Manual City 5 -> 10 -> finale smoke**

Verify:

1. City 5 / Highcrest arrival uses `City 5 · Highcrest` + authored flavor, minimum readable font, modest static city accent, fresh `Highcrest Falls` flourish.
2. City 10 / Ironthorn Gate uses the same structure with stronger static accent/report treatment.
3. Finale / Crownspire Keep uses strongest treatment, keeps `Crownspire Keep Falls`, and shows `Country 1 Complete` before Continue.
4. Arrival auto-dismiss and skip tap never mutate game state or trigger an underlying control.
5. With VoiceOver, activating Settings during arrival dismisses the arrival first; Settings is visible/actionable immediately.
6. With Reduce Motion, required text/static accents remain and scale emphasis is absent.
7. Fresh idle milestone conquest flourishes once; restored milestone report has static treatment only.
8. `568×320`, `667×375`, and `320×568` remain readable; required finale content is safe and Continue remains actionable.
9. Gold, HP, rewards, lanes, buildings, unlocks, idle progress, persistence, and routing are unchanged.

- [ ] **Step 8: Commit documentation after verification**

```bash
git add CLAUDE.md
git commit -m "docs: document milestone presentation ownership"
```

---

## Plan Self-Review Checklist

Before implementation is considered complete, verify all remain true:

- `Country1MilestoneTier` is the only new production file and uses `KingdomGameState.firstCountryCityCount` for finale identity.
- `PanelNode` is reused for arrival; no duplicate themed panel implementation exists.
- `SingleLineTextFitter` is reused with an explicit 12pt arrival floor; supported fit tests assert actual rendered font sizes.
- Arrival layout failure always clears `isMilestoneArrivalVisible` and therefore cannot eat taps invisibly.
- `openFeedbackSettings()` dismisses arrival for the VoiceOver path as well as normal touch flow.
- Enemy-city accent is static; no pulse/loop lifecycle was added.
- `ConquestReportLayout` owns `countryCompleteFrame` and required geometry failure; no BattleScene geometry preflight/fallback exists.
- Base report geometry remains byte-for-byte equivalent in behavior when `includesCountryCompletion == false` (existing exact-height tests pass).
- The pure 205pt boundary test explicitly proves base-report-fit versus completion-group-failure.
- `BattleScene` handles only required-label typography after layout; decorative accent clipping never causes report failure.
- `applyPendingConquestReport` returns the exact successfully resolved `BattleResult`, and the flourish consumes that value rather than re-reading state.
- Resize/redraw may update static geometry but cannot replay arrival/flourish counts.
- City 15 `Crownspire Keep Falls` and Continue acknowledgement/save/map route remain unchanged.
- No persistence, assets, SFX/haptics, presentation framework, or new gameplay rule was introduced.
