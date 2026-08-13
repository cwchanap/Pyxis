# HPA-618 DEBUG-only Country 1 City Jump Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a DEBUG-only five-tap Country 1 city picker that replaces the development save with a generous fresh battle state for City 1...15 and routes directly through the existing Battle scene.

**Architecture:** Add one framework-free `DevJumpState` factory, entirely compiled only in DEBUG. Keep the one-consumer gesture, action sheet, save, and Battle routing inside the existing `GameViewController.swift` DEBUG boundary so it can call the existing private `presentBattleScene(in:)` router without another protocol or scene factory. Unit-test the pure state contract and the cheap UIKit glue needed to satisfy the repository's 95% patch-coverage gate; keep real cross-scene gesture behavior and iPad presentation as manual smoke.

**Tech Stack:** Swift 5, UIKit, SpriteKit, Swift Testing, `KingdomGameState`, `KingdomGameStore`, Xcode/iOS Simulator.

## Global Constraints

- HPA-618 is a developer convenience tool, not HPA-567 validation evidence.
- Every new runtime line/symbol/string must be inside `#if DEBUG ... #endif`.
- Country 1 only; do not add a country parameter, multi-country model, registry, protocol, service, or dev-tools framework.
- Picker values come only from `1...KingdomGameState.firstCountryCityCount`.
- DEBUG preset is exactly `gold = 1_000_000` and `normalSoldierUpgradeLevel = 15`.
- A jump starts with empty `cityBattleStates` and no carried active siege, pending result, or background timestamp.
- Selecting a city intentionally overwrites the current development save; do not add backup/reset/restore machinery.
- City 15 starts as `.battleActive`; `countryComplete` is reached only by conquering City 15 normally.
- Reuse `KingdomGameStore.save(_:)` and `GameViewController.presentBattleScene(in:)`; do not add another persistence or routing path.
- Use one five-tap `UITapGestureRecognizer` on the `SKView`, `cancelsTouchesInView = false`, and a 64×64 pt top-right hotspot.
- Picker is `UIAlertController.Style.actionSheet`, title `[DEBUG] Jump to Country 1 City`, message `Replaces current save.`, City 1...15 actions, and Cancel.
- Configure the action sheet's `popoverPresentationController` to the `SKView` and hotspot rect so iPad presentation is valid.
- Do not edit `project.pbxproj`; synchronized Xcode groups discover new files.
- Run simulator tests with `-parallel-testing-enabled NO`.
- Keep Codecov project and patch coverage at or above the repository's 95% gate when the implementation PR is marked ready.
- **Coverage risk:** directly execute the `handleDevJumpGesture` adapter in `GameViewControllerTests`, and keep each `UIAlertAction` handler to one executable forwarding line. If either adapter grows, add focused coverage before readying the PR; do not weaken Codecov.

## File Structure

- Create `Pyxis/DevJumpState.swift` — DEBUG-only pure factory and tweakable preset constants.
- Create `PyxisTests/DevJumpStateTests.swift` — all-15-city normalization contract.
- Modify `Pyxis/GameViewController.swift` — inline DEBUG installer call plus DEBUG-only gesture/picker/jump helpers and semantic testing accessors.
- Modify `PyxisTests/GameViewControllerTests.swift` — gesture adapter/hotspot/picker/save/router coverage.
- Modify `CLAUDE.md` — one short ownership/release-gating note for the developer tool.

---

## Task 1: Add the pure DEBUG jump-state factory

**Files:**
- Create: `Pyxis/DevJumpState.swift`
- Create: `PyxisTests/DevJumpStateTests.swift`

**Interfaces:**
- Produces: `DevJumpState.gold: Int`
- Produces: `DevJumpState.soldierLevel: Int`
- Produces: `DevJumpState.make(city: Int) -> KingdomGameState`
- Consumes: `KingdomGameState.firstCountryCityCount`
- Consumes: existing `KingdomGameState` initializer normalization

- [ ] **Step 1: Write the failing all-city factory test**

Create `PyxisTests/DevJumpStateTests.swift`:

```swift
import Testing
@testable import Pyxis

#if DEBUG
struct DevJumpStateTests {
    @Test("Every Country 1 dev jump creates a fresh active battle")
    func everyCountry1CityCreatesFreshActiveBattle() {
        for city in 1...KingdomGameState.firstCountryCityCount {
            let state = DevJumpState.make(city: city)

            #expect(state.countryNumber == 1)
            #expect(state.completedCityCount == city - 1)
            #expect(state.cityNumberInCountry == city)
            #expect(state.cityLevel == city)
            #expect(state.stageStatus == .battleActive)
            #expect(state.cityRemainingPower == KingdomGameState.cityMaxPower(for: city))
            #expect(state.gold == DevJumpState.gold)
            #expect(state.normalSoldierUpgradeLevel == DevJumpState.soldierLevel)
            #expect(state.cityBattleStates.isEmpty)
            #expect(state.activeSiegeSession == nil)
            #expect(state.pendingBattleResult == nil)
            #expect(state.lastBackgroundedAt == nil)
        }
    }
}
#endif
```

This test deliberately uses only valid picker values. Do not add out-of-range factory semantics that the UI cannot produce.

- [ ] **Step 2: Run the focused suite and confirm RED**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/DevJumpStateTests
```

Expected: FAIL because `DevJumpState` does not exist.

- [ ] **Step 3: Implement the minimal DEBUG-only factory**

Create `Pyxis/DevJumpState.swift`:

```swift
#if DEBUG
enum DevJumpState {
    static let gold = 1_000_000
    static let soldierLevel = 15

    static func make(city: Int) -> KingdomGameState {
        KingdomGameState(
            gold: gold,
            normalSoldierUpgradeLevel: soldierLevel,
            countryNumber: 1,
            completedCityCount: city - 1,
            stageStatus: .battleActive,
            cityBattleStates: [:]
        )
    }
}
#endif
```

Do not pass `cityLevel` or `cityNumberInCountry`; the existing `KingdomGameState` initializer derives those values from the active progression state. Do not add a country parameter or clamp.

- [ ] **Step 4: Re-run the focused suite and confirm GREEN**

Run Step 2 again.

Expected: PASS for all 15 cities.

- [ ] **Step 5: Commit the pure state slice**

```bash
git add Pyxis/DevJumpState.swift PyxisTests/DevJumpStateTests.swift
git commit -m "feat: add DEBUG city jump state"
```

---

## Task 2: Install the five-tap picker and reuse existing save/Battle routing

**Files:**
- Modify: `Pyxis/GameViewController.swift`
- Modify: `PyxisTests/GameViewControllerTests.swift`

**Interfaces:**
- Consumes: `DevJumpState.make(city:)`
- Consumes: `KingdomGameState.firstCountryCityCount`
- Consumes: `KingdomGameStore.save(_:)`
- Consumes: private `GameViewController.presentBattleScene(in:)`
- Produces internally: `installDevJumpGesture(on:)`
- Produces internally: `devJumpTriggerFrame(in:) -> CGRect`
- Produces internally: `handleDevJumpGesture(_:)`
- Produces internally: `handleDevJumpTap(at:in:)`
- Produces internally: `makeDevJumpAlert(in:) -> UIAlertController`
- Produces internally: `performDevJump(to:in:)`

- [ ] **Step 1: Write RED controller tests for installation, adapter coverage, hotspot, picker, and jump routing**

Add these tests inside the existing `@MainActor GameViewControllerTests`:

```swift
#if DEBUG
@Test("DEBUG controller installs a non-cancelling five-tap city-jump gesture")
func debugControllerInstallsFiveTapCityJumpGesture() throws {
    let store = try makeStore(initialState: .init())
    let controller = makeGameViewController(store: store)
    let view = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
    controller.view = view
    controller.viewDidLoad()

    let gesture = try #require(controller.devJumpGestureForTesting)
    #expect(gesture.numberOfTapsRequired == 5)
    #expect(gesture.cancelsTouchesInView == false)
    #expect(controller.devJumpTriggerFrameForTesting(in: view)
        == CGRect(x: 329, y: 0, width: 64, height: 64))
}

@Test("DEBUG recognizer adapter forwards safely without a gesture harness")
func debugRecognizerAdapterIsDirectlyCovered() throws {
    let store = try makeStore(initialState: .init())
    let controller = makeGameViewController(store: store)
    let view = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
    controller.view = view
    controller.viewDidLoad()

    let gesture = try #require(controller.devJumpGestureForTesting)
    controller.handleDevJumpGestureForTesting(gesture)

    // A recognizer that has not received real touches reports an outside/default
    // location. This test exists to execute the tiny adapter; hotspot behavior is
    // covered independently below.
    #expect(controller.presentedViewController == nil)
}

@Test("DEBUG city-jump hotspot ignores outside taps and presents one picker inside")
func debugCityJumpHotspotPresentsOnePicker() throws {
    let store = try makeStore(initialState: .init())
    let controller = makeGameViewController(store: store)
    let view = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
    controller.view = view
    controller.viewDidLoad()
    let lifecycle = try makeSceneLifecycleFixture(rootViewController: controller)
    lifecycle.window.isHidden = false
    defer {
        controller.dismiss(animated: false)
        lifecycle.window.rootViewController = nil
    }

    controller.handleDevJumpTapForTesting(
        at: CGPoint(x: 10, y: view.bounds.maxY - 10),
        in: view
    )
    #expect(controller.presentedViewController == nil)

    let trigger = controller.devJumpTriggerFrameForTesting(in: view)
    controller.handleDevJumpTapForTesting(
        at: CGPoint(x: trigger.midX, y: trigger.midY),
        in: view
    )
    let firstAlert = try #require(controller.presentedViewController as? UIAlertController)

    controller.handleDevJumpTapForTesting(
        at: CGPoint(x: trigger.midX, y: trigger.midY),
        in: view
    )
    #expect(controller.presentedViewController === firstAlert)
}

@Test("DEBUG city-jump picker lists exactly Country 1 and warns about overwrite")
func debugCityJumpPickerContentIsBoundedToCountry1() throws {
    let store = try makeStore(initialState: .init())
    let controller = makeGameViewController(store: store)
    let view = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
    controller.view = view

    let alert = controller.makeDevJumpAlertForTesting(in: view)
    let expectedTitles = (1...KingdomGameState.firstCountryCityCount)
        .map { "City \($0)" } + ["Cancel"]

    #expect(alert.preferredStyle == .actionSheet)
    #expect(alert.title == "[DEBUG] Jump to Country 1 City")
    #expect(alert.message == "Replaces current save.")
    #expect(alert.actions.compactMap(\.title) == expectedTitles)
    #expect(alert.actions.last?.style == .cancel)
}

@Test("DEBUG city jump overwrites the save and routes through the normal Battle scene")
func debugCityJumpOverwritesSaveAndPresentsBattle() throws {
    let store = try makeStore(initialState: KingdomGameState(
        gold: 7,
        completedCityCount: KingdomGameState.firstCountryCityCount,
        stageStatus: .countryComplete
    ))
    let controller = makeGameViewController(store: store)
    let view = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
    controller.view = view
    controller.viewDidLoad()
    #expect(view.scene is CountryMapScene)

    controller.performDevJumpForTesting(to: 10, in: view)

    let state = store.load()
    #expect(state.countryNumber == 1)
    #expect(state.completedCityCount == 9)
    #expect(state.cityNumberInCountry == 10)
    #expect(state.cityLevel == 10)
    #expect(state.stageStatus == .battleActive)
    #expect(state.gold == DevJumpState.gold)
    #expect(state.normalSoldierUpgradeLevel == DevJumpState.soldierLevel)
    #expect(state.cityBattleStates.isEmpty)

    let battle = try #require(view.scene as? BattleScene)
    #expect(battle.cityLevelForTesting == 10)
}
#endif
```

If headless UIKit refuses to expose `presentedViewController` without a visible window, keep the existing `makeSceneLifecycleFixture` approach shown above; do not introduce a custom presentation protocol just for the test.

- [ ] **Step 2: Run the controller tests and confirm RED**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/GameViewControllerTests
```

Expected: FAIL because the DEBUG city-jump installer/helpers/accessors do not exist.

- [ ] **Step 3: Add only the compile-gated installer call to `viewDidLoad()`**

Immediately after `configure(view)` in `GameViewController.viewDidLoad()`:

```swift
#if DEBUG
installDevJumpGesture(on: view)
#endif
```

Do not move normal scene/feedback setup under the DEBUG gate.

- [ ] **Step 4: Add the DEBUG UI constants and minimal controller helpers**

Extend the existing bottom-of-file DEBUG section in `Pyxis/GameViewController.swift`:

```swift
#if DEBUG
private enum DevJumpUI {
    static let triggerSize: CGFloat = 64
    static let title = "[DEBUG] Jump to Country 1 City"
    static let message = "Replaces current save."
}

extension GameViewController {
    private func installDevJumpGesture(on view: SKView) {
        let gesture = UITapGestureRecognizer(
            target: self,
            action: #selector(handleDevJumpGesture(_:))
        )
        gesture.numberOfTapsRequired = 5
        gesture.cancelsTouchesInView = false
        view.addGestureRecognizer(gesture)
    }

    private func devJumpTriggerFrame(in view: SKView) -> CGRect {
        let size = min(
            DevJumpUI.triggerSize,
            min(view.bounds.width, view.bounds.height)
        )
        return CGRect(
            x: view.bounds.maxX - size,
            y: view.bounds.minY,
            width: size,
            height: size
        )
    }

    @objc private func handleDevJumpGesture(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view as? SKView else { return }
        handleDevJumpTap(at: gesture.location(in: view), in: view)
    }

    private func handleDevJumpTap(at point: CGPoint, in view: SKView) {
        guard devJumpTriggerFrame(in: view).contains(point),
              presentedViewController == nil else {
            return
        }
        present(makeDevJumpAlert(in: view), animated: true)
    }

    private func makeDevJumpAlert(in view: SKView) -> UIAlertController {
        let alert = UIAlertController(
            title: DevJumpUI.title,
            message: DevJumpUI.message,
            preferredStyle: .actionSheet
        )

        for city in 1...KingdomGameState.firstCountryCityCount {
            let action = UIAlertAction(title: "City \(city)", style: .default) {
                [weak self] _ in self?.performDevJump(to: city, in: view)
            }
            alert.addAction(action)
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        alert.popoverPresentationController?.sourceView = view
        alert.popoverPresentationController?.sourceRect = devJumpTriggerFrame(in: view)
        return alert
    }

    private func performDevJump(to city: Int, in view: SKView) {
        store.save(DevJumpState.make(city: city))
        presentBattleScene(in: view)
    }

    // Keep the existing layout-gate testing accessors below these helpers.
}
#endif
```

The action captures the short-lived alert's `SKView` strongly and the controller weakly. Do not use a forced unwrap merely to compress the handler. The handler body remains one executable forwarding line, while the tested `performDevJump(to:in:)` owns the real behavior.

Do not add an invisible UIView, a `UIGestureRecognizerDelegate`, a navigation layer, or a separate alert-builder type.

- [ ] **Step 5: Add narrow DEBUG testing accessors in the same extension**

Add:

```swift
var devJumpGestureForTesting: UITapGestureRecognizer? {
    (view as? SKView)?.gestureRecognizers?
        .compactMap { $0 as? UITapGestureRecognizer }
        .first { $0.numberOfTapsRequired == 5 }
}

func devJumpTriggerFrameForTesting(in view: SKView) -> CGRect {
    devJumpTriggerFrame(in: view)
}

func handleDevJumpGestureForTesting(_ gesture: UITapGestureRecognizer) {
    handleDevJumpGesture(gesture)
}

func handleDevJumpTapForTesting(at point: CGPoint, in view: SKView) {
    handleDevJumpTap(at: point, in: view)
}

func makeDevJumpAlertForTesting(in view: SKView) -> UIAlertController {
    makeDevJumpAlert(in: view)
}

func performDevJumpForTesting(to city: Int, in view: SKView) {
    performDevJump(to: city, in: view)
}
```

These are semantic DEBUG accessors only. Do not expose UIKit debug APIs in Release or add a test-only protocol.

- [ ] **Step 6: Re-run the controller suite and confirm GREEN**

Run Step 2 again.

Expected: PASS, including direct execution of the recognizer adapter.

- [ ] **Step 7: Run both HPA-618 focused suites together**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/DevJumpStateTests \
  -only-testing:PyxisTests/GameViewControllerTests
```

Expected: PASS.

- [ ] **Step 8: Commit the controller slice**

```bash
git add Pyxis/GameViewController.swift PyxisTests/GameViewControllerTests.swift
git commit -m "feat: add DEBUG city jump picker"
```

---

## Task 3: Document ownership and prove Release isolation

**Files:**
- Modify: `CLAUDE.md`
- Verify: all implementation files from Tasks 1-2

**Interfaces:**
- Documents: `DevJumpState` owns DEBUG state materialization only.
- Documents: `GameViewController` owns the DEBUG gesture/picker and reuses normal save/Battle routing.
- Verifies: DEBUG cross-scene smoke behavior and Release compile-out.

- [ ] **Step 1: Add one concise developer-tool note to `CLAUDE.md`**

In the existing `GameViewController` architecture section, add a short paragraph equivalent to:

```markdown
- HPA-618's Country 1 city-jump tool is development-only: `DevJumpState` plus the five-tap picker/wiring in `GameViewController` are entirely `#if DEBUG`. The picker overwrites the current save and reuses `KingdomGameStore.save(_:)` + `presentBattleScene(in:)`; do not turn it into a shipping setting, generic dev-tools framework, checkpoint manager, or alternate router.
```

Keep the note beside controller ownership; do not create a separate developer-tools architecture section.

- [ ] **Step 2: Run the complete test suite**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO
```

Expected: all unit and UI tests PASS.

- [ ] **Step 3: Run SwiftLint and diff hygiene**

```bash
swiftlint lint --no-cache
git diff --check
```

Expected: SwiftLint exits 0 with no new serious findings; `git diff --check` exits 0.

- [ ] **Step 4: Build Release with a dedicated derived-data path**

```bash
rm -rf /tmp/pyxis-hpa618-release
xcodebuild build \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -configuration Release \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath /tmp/pyxis-hpa618-release
```

Expected: Release build PASS.

- [ ] **Step 5: Prove the unique DEBUG picker marker is absent from the Release binary**

```bash
release_binary="/tmp/pyxis-hpa618-release/Build/Products/Release-iphonesimulator/Pyxis.app/Pyxis"
test -f "$release_binary"
if strings "$release_binary" | grep -F "[DEBUG] Jump to Country 1 City"; then
  echo "HPA-618 debug picker leaked into Release" >&2
  exit 1
fi
```

Expected: command exits 0 with no grep match.

Do not grep for generic strings such as `City 15`; those are legitimate shipping content.

- [ ] **Step 6: Perform the DEBUG iPhone Battle smoke**

On an iPhone simulator DEBUG build:

1. Start in Battle and five-tap the top-right hotspot.
2. Verify the action sheet title is `[DEBUG] Jump to Country 1 City` and message is `Replaces current save.`.
3. Jump to City 1 and verify Battle opens with City 1.
4. Repeat for City 5 and City 10 to exercise existing milestone presentation.
5. Jump to City 15 and verify it opens as an active Battle rather than a completed country.
6. Conquer City 15 and verify the existing conquest report / `Country 1 Complete` flow still behaves normally.

The automated factory test already covers all City 1...15 state values; do not manually click every city merely to duplicate that proof.

- [ ] **Step 7: Prove the SKView-level trigger survives Country Map and Building View replacement**

On the same DEBUG iPhone build:

1. Navigate to Country Map through the normal game route.
2. Five-tap the top-right hotspot, choose City 10, and verify Battle opens at City 10.
3. Navigate to Building View through the normal Battle control.
4. Five-tap the top-right hotspot, choose City 10, and verify Battle opens at City 10 again.

This smoke is specifically about controller-owned `SKView` gesture lifetime. Do not add scene-specific gesture wiring or automated scene-input infrastructure to make this test easier.

- [ ] **Step 8: Perform the iPad action-sheet smoke**

On an iPad portrait simulator DEBUG build:

1. Five-tap the top-right hotspot.
2. Verify the action sheet presents without a popover-anchor exception.
3. Select City 15 and verify Battle opens.

If this fails, fix only the action-sheet `sourceView` / `sourceRect` configuration; do not replace the design with a generic presentation abstraction.

- [ ] **Step 9: Commit the ownership note after verification**

```bash
git add CLAUDE.md
git commit -m "docs: document DEBUG city jump ownership"
```

- [ ] **Step 10: Open/refresh the implementation PR and verify CI gates when ready**

The implementation PR should reference HPA-618 and include the planning spec/plan. Once it is marked ready for review, require:

- Build & Lint: PASS
- Unit Test & Codecov: PASS
- UI Test: PASS
- Codecov project status: at least 95%
- Codecov patch status: at least 95%

If patch coverage fails, first inspect the new adapter lines: `handleDevJumpGesture` must remain directly covered and each alert action must remain one executable forwarding line. Add focused coverage for any new behavior rather than weakening the gate or adding an abstraction solely for coverage.

## Implementation scope checkpoint

The intended runtime diff remains deliberately small:

- one new DEBUG-only production file: `Pyxis/DevJumpState.swift`;
- one existing production file modified: `Pyxis/GameViewController.swift`;
- two focused test files;
- one short `CLAUDE.md` ownership note.

If implementation starts requiring a new router, picker type, debug menu, checkpoint model, persistence API, launch configuration, or project-file registration, stop and cut that work: it is outside HPA-618.
