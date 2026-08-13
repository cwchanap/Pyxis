# HPA-618 DEBUG-only Country 1 City Jump Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a DEBUG-only five-tap Country 1 city picker that replaces the development save with a generous fresh battle state for City 1...15 and routes through the existing Battle scene without adding latency to normal DEBUG taps.

**Architecture:** Add one framework-free `DevJumpState` factory compiled only in DEBUG. Keep the one-consumer gesture, action sheet, save, and Battle routing inside the existing `GameViewController.swift` DEBUG boundary. Reuse `KingdomGameState` normalization, `KingdomGameStore.save(_:)`, and `presentBattleScene(in:)`; add no dev-tools framework, overlay builder, alternate router, or checkpoint model.

**Tech Stack:** Swift 5, UIKit, SpriteKit, Swift Testing, `KingdomGameState`, `KingdomGameStore`, Xcode/iOS Simulator.

## Global Constraints

- HPA-618 is developer convenience only, not HPA-567 validation evidence.
- Every new runtime line, symbol, and unique picker string must be inside `#if DEBUG ... #endif`.
- Country 1 only; do not add a country parameter, multi-country model, registry, protocol, service, or dev-tools framework.
- Picker values come only from `1...KingdomGameState.firstCountryCityCount`.
- `DevJumpState.make(city:)` must also precondition that valid range so programmer misuse fails loudly instead of silently normalizing.
- DEBUG preset is exactly `gold = 1_000_000` and `normalSoldierUpgradeLevel = 15`.
- A jump starts with empty `cityBattleStates` and no carried active siege, pending result, or background timestamp.
- Selecting a city intentionally overwrites the development save; do not add backup/reset/restore machinery.
- City 15 starts as `.battleActive`; country completion happens only by conquering City 15 normally.
- Reuse `KingdomGameStore.save(_:)` and private `GameViewController.presentBattleScene(in:)`.
- Use one five-tap `UITapGestureRecognizer` on the `SKView` with `cancelsTouchesInView = false` **and** `delaysTouchesEnded = false`.
- Use one 64×64 pt top-right hotspot. Do not add an invisible `UIView` or `UIGestureRecognizerDelegate` hotspot filter.
- Picker is `UIAlertController.Style.actionSheet`, title `[DEBUG] Jump to Country 1 City`, message `Replaces current save.`, City 1...15 actions, and Cancel.
- Configure the action sheet popover to the `SKView` + hotspot rect for iPad.
- DEBUG controller helpers are internal for `@testable import`; do not add one-to-one `...ForTesting` pass-through wrappers.
- Keep each alert city handler to one executable forwarding line into `performDevJump(to:in:)`.
- Do not edit `project.pbxproj`; synchronized groups discover new files.
- Run simulator tests with `-parallel-testing-enabled NO`.
- Keep Codecov project and patch coverage at or above 95%; do not weaken the gate.

## Risks already designed out

- **Input latency:** UIKit defaults `delaysTouchesEnded` to true. Because Pyxis scenes handle tap actions in `touchesEnded`, the recognizer must explicitly set and test `delaysTouchesEnded = false`.
- **iPad popover validity:** `.actionSheet` needs a valid popover source; anchor it to the `SKView` hotspot and perform an iPad smoke.
- **Patch coverage:** directly exercise the tiny gesture adapter, test real hotspot/picker/save behavior, remove pass-through test wrappers, and keep the one alert closure line trivial.

## File Structure

- Create `Pyxis/DevJumpState.swift` — DEBUG-only pure factory, domain precondition, and tweakable preset constants.
- Create `PyxisTests/DevJumpStateTests.swift` — valid City 1...15 normalization contract.
- Modify `Pyxis/GameViewController.swift` — DEBUG installer call plus internal DEBUG gesture/picker/jump helpers.
- Modify `PyxisTests/GameViewControllerTests.swift` — recognizer properties, adapter forwarding, hotspot, picker, save/router coverage.
- Modify `CLAUDE.md` — one short developer-tool ownership/release-gating note.

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

Do not add an out-of-range clamping test. Invalid direct use is a DEBUG programmer error, not a recoverable public API contract.

- [ ] **Step 2: Run the focused test and confirm RED**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/DevJumpStateTests
```

Expected: FAIL because `DevJumpState` does not exist.

- [ ] **Step 3: Implement the minimal DEBUG-only factory with a loud domain boundary**

Create `Pyxis/DevJumpState.swift`:

```swift
#if DEBUG
enum DevJumpState {
    static let gold = 1_000_000
    static let soldierLevel = 15

    static func make(city: Int) -> KingdomGameState {
        precondition(
            (1...KingdomGameState.firstCountryCityCount).contains(city),
            "DevJumpState supports Country 1 cities only"
        )

        return KingdomGameState(
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

Do not pass `cityLevel`, `cityNumberInCountry`, or `cityRemainingPower`; the existing model derives them. Do not add a country parameter or clamp.

- [ ] **Step 4: Re-run and confirm GREEN**

Run Step 2 again.

Expected: PASS for all valid Country 1 cities. The precondition line is executed on every valid factory call.

- [ ] **Step 5: Commit the pure state slice**

```bash
git add Pyxis/DevJumpState.swift PyxisTests/DevJumpStateTests.swift
git commit -m "feat: add DEBUG city jump state"
```

---

## Task 2: Install the five-tap picker without delaying SpriteKit input

**Files:**
- Modify: `Pyxis/GameViewController.swift`
- Modify: `PyxisTests/GameViewControllerTests.swift`

**Interfaces:**
- Consumes: `DevJumpState.make(city:)`
- Consumes: `KingdomGameState.firstCountryCityCount`
- Consumes: `KingdomGameStore.save(_:)`
- Consumes: private `GameViewController.presentBattleScene(in:)`
- Produces DEBUG-internal: `installDevJumpGesture(on:)`
- Produces DEBUG-internal: `devJumpTriggerFrame(in:) -> CGRect`
- Produces DEBUG-internal: `handleDevJumpGesture(_:)`
- Produces DEBUG-internal: `handleDevJumpTap(at:in:)`
- Produces DEBUG-internal: `makeDevJumpAlert(in:) -> UIAlertController`
- Produces DEBUG-internal: `performDevJump(to:in:)`

- [ ] **Step 1: Write RED controller tests for recognizer behavior, real adapter forwarding, hotspot, picker, and jump routing**

Add these tests inside the existing `@MainActor GameViewControllerTests`:

```swift
#if DEBUG
@Test("DEBUG controller installs a non-delaying five-tap city-jump recognizer")
func debugControllerInstallsFiveTapCityJumpRecognizer() throws {
    let store = try makeStore(initialState: .init())
    let controller = makeGameViewController(store: store)
    let view = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
    controller.view = view
    controller.viewDidLoad()

    let gesture = try #require(view.gestureRecognizers?
        .compactMap { $0 as? UITapGestureRecognizer }
        .first { $0.numberOfTapsRequired == 5 })

    #expect(gesture.numberOfTapsRequired == 5)
    #expect(gesture.cancelsTouchesInView == false)
    #expect(gesture.delaysTouchesEnded == false)
    #expect(controller.devJumpTriggerFrame(in: view)
        == CGRect(x: 329, y: 0, width: 64, height: 64))
}

@Test("DEBUG recognizer adapter forwards its view and location into picker presentation")
func debugRecognizerAdapterActuallyPresentsPicker() throws {
    let store = try makeStore(initialState: .init())
    let controller = makeGameViewController(store: store)
    let view = SKView(frame: CGRect(x: 0, y: 0, width: 64, height: 64))
    controller.view = view
    controller.installDevJumpGesture(on: view)

    let lifecycle = try makeSceneLifecycleFixture(rootViewController: controller)
    lifecycle.window.isHidden = false
    defer {
        controller.dismiss(animated: false)
        lifecycle.window.rootViewController = nil
    }

    let gesture = try #require(view.gestureRecognizers?
        .compactMap { $0 as? UITapGestureRecognizer }
        .first { $0.numberOfTapsRequired == 5 })

    controller.handleDevJumpGesture(gesture)

    let alert = try #require(controller.presentedViewController as? UIAlertController)
    #expect(alert.title == "[DEBUG] Jump to Country 1 City")
    #expect(controller.devJumpTriggerFrame(in: view) == view.bounds)
}

@Test("DEBUG city-jump hotspot ignores outside taps and presents only one picker inside")
func debugCityJumpHotspotPresentsOnePicker() throws {
    let store = try makeStore(initialState: .init())
    let controller = makeGameViewController(store: store)
    let view = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
    controller.view = view

    let lifecycle = try makeSceneLifecycleFixture(rootViewController: controller)
    lifecycle.window.isHidden = false
    defer {
        controller.dismiss(animated: false)
        lifecycle.window.rootViewController = nil
    }

    controller.handleDevJumpTap(
        at: CGPoint(x: 10, y: view.bounds.maxY - 10),
        in: view
    )
    #expect(controller.presentedViewController == nil)

    let trigger = controller.devJumpTriggerFrame(in: view)
    controller.handleDevJumpTap(
        at: CGPoint(x: trigger.midX, y: trigger.midY),
        in: view
    )
    let firstAlert = try #require(controller.presentedViewController as? UIAlertController)

    controller.handleDevJumpTap(
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

    let alert = controller.makeDevJumpAlert(in: view)
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

    controller.performDevJump(to: 10, in: view)

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

The 64×64 adapter fixture intentionally makes the trigger frame equal the full view bounds, so the recognizer's untouched location exercises the real picker path. If UIKit behavior on the target SDK makes that fixture unreliable, replace only this focused test seam; do not add a general recognizer harness or production abstraction.

Popover source configuration is verified by the iPad manual smoke below rather than by an iPhone-only unit assertion; `popoverPresentationController` may be `nil` when a controller is not using popover presentation.

- [ ] **Step 2: Run the controller suite and confirm RED**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/GameViewControllerTests
```

Expected: FAIL because the DEBUG city-jump installer/helpers do not exist.

- [ ] **Step 3: Add the compile-gated install hook and all minimal DEBUG helpers as one compiling implementation step**

In `GameViewController.viewDidLoad()`, immediately after `configure(view)`:

```swift
#if DEBUG
installDevJumpGesture(on: view)
#endif
```

Then extend the existing bottom-of-file DEBUG section:

```swift
#if DEBUG
private enum DevJumpUI {
    static let triggerSize: CGFloat = 64
    static let title = "[DEBUG] Jump to Country 1 City"
    static let message = "Replaces current save."
}

extension GameViewController {
    func installDevJumpGesture(on view: SKView) {
        let gesture = UITapGestureRecognizer(
            target: self,
            action: #selector(handleDevJumpGesture(_:))
        )
        gesture.numberOfTapsRequired = 5
        gesture.cancelsTouchesInView = false
        gesture.delaysTouchesEnded = false
        view.addGestureRecognizer(gesture)
    }

    func devJumpTriggerFrame(in view: SKView) -> CGRect {
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

    @objc func handleDevJumpGesture(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view as? SKView else { return }
        handleDevJumpTap(at: gesture.location(in: view), in: view)
    }

    func handleDevJumpTap(at point: CGPoint, in view: SKView) {
        guard devJumpTriggerFrame(in: view).contains(point),
              presentedViewController == nil else {
            return
        }
        present(makeDevJumpAlert(in: view), animated: true)
    }

    func makeDevJumpAlert(in view: SKView) -> UIAlertController {
        let alert = UIAlertController(
            title: DevJumpUI.title,
            message: DevJumpUI.message,
            preferredStyle: .actionSheet
        )

        for city in 1...KingdomGameState.firstCountryCityCount {
            alert.addAction(UIAlertAction(title: "City \(city)", style: .default) {
                [weak self] _ in self?.performDevJump(to: city, in: view)
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        alert.popoverPresentationController?.sourceView = view
        alert.popoverPresentationController?.sourceRect = devJumpTriggerFrame(in: view)
        return alert
    }

    func performDevJump(to city: Int, in view: SKView) {
        store.save(DevJumpState.make(city: city))
        presentBattleScene(in: view)
    }

    // Existing layout-gate DEBUG testing accessors remain unchanged below.
}
#endif
```

These helpers are internal because they exist only in DEBUG and `@testable import Pyxis` can exercise them directly. Do not add `devJumpTriggerFrameForTesting`, `handleDevJumpGestureForTesting`, `handleDevJumpTapForTesting`, `makeDevJumpAlertForTesting`, or `performDevJumpForTesting` wrappers.

Do not use a forced unwrap in the alert action. Do not add an invisible view, recognizer delegate, navigation layer, or separate alert-builder type.

- [ ] **Step 4: Re-run the controller suite and confirm GREEN**

Run Step 2 again.

Expected: PASS, including the non-delaying recognizer property and real adapter-to-picker forwarding.

- [ ] **Step 5: Run both HPA-618 focused suites together**

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

- [ ] **Step 6: Commit the controller slice**

```bash
git add Pyxis/GameViewController.swift PyxisTests/GameViewControllerTests.swift
git commit -m "feat: add DEBUG city jump picker"
```

---

## Task 3: Document ownership and prove cross-scene + Release behavior

**Files:**
- Modify: `CLAUDE.md`
- Verify: all implementation files from Tasks 1-2

**Interfaces:**
- Documents: `DevJumpState` owns DEBUG state materialization only.
- Documents: `GameViewController` owns the DEBUG gesture/picker and reuses normal save/Battle routing.
- Verifies: ordinary tap responsiveness, cross-scene trigger lifetime, Settings interaction, iPad presentation, and Release compile-out.

- [ ] **Step 1: Add one concise developer-tool note to `CLAUDE.md`**

In the existing `GameViewController` architecture section, add:

```markdown
- HPA-618's Country 1 city-jump tool is development-only: `DevJumpState` plus the five-tap picker/wiring in `GameViewController` are entirely `#if DEBUG`. The recognizer must keep `cancelsTouchesInView` and `delaysTouchesEnded` false so it does not distort SpriteKit input timing. The picker overwrites the current save and reuses `KingdomGameStore.save(_:)` + `presentBattleScene(in:)`; do not turn it into a shipping setting, generic dev-tools framework, checkpoint manager, or alternate router.
```

Do not create a separate developer-tools architecture section.

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

- [ ] **Step 5: Prove the unique DEBUG picker marker is absent from Release**

```bash
release_binary="/tmp/pyxis-hpa618-release/Build/Products/Release-iphonesimulator/Pyxis.app/Pyxis"
test -f "$release_binary"
if strings "$release_binary" | grep -F "[DEBUG] Jump to Country 1 City"; then
  echo "HPA-618 debug picker leaked into Release" >&2
  exit 1
fi
```

Expected: command exits 0 with no grep match.

Do not grep generic shipping strings such as `City 15`.

- [ ] **Step 6: Perform the DEBUG iPhone Battle smoke, including normal tap responsiveness**

On an iPhone simulator DEBUG build:

1. Before using the dev gesture, perform ordinary one-tap Battle controls and confirm they respond immediately rather than waiting for multi-tap recognition.
2. Five-tap the top-right hotspot.
3. Verify title `[DEBUG] Jump to Country 1 City` and message `Replaces current save.`.
4. Jump to City 1 and verify Battle opens with City 1.
5. Repeat for City 5 and City 10 to exercise milestone presentation.
6. Jump to City 15 and verify it opens as active Battle, not completed country.
7. Conquer City 15 and verify the existing conquest report / `Country 1 Complete` flow.

The all-city factory test covers all state values; do not manually click all 15 actions.

- [ ] **Step 7: Prove the SKView-level trigger survives Country Map and Building View replacement**

On the same DEBUG iPhone build:

1. Navigate to Country Map through the normal route.
2. Confirm a normal one-tap map action remains responsive.
3. Five-tap top-right, choose City 10, and verify Battle opens at City 10.
4. Navigate to Building View through the normal Battle control.
5. Confirm a normal one-tap Building interaction remains responsive.
6. Five-tap top-right, choose City 10, and verify Battle opens at City 10 again.

Do not add scene-specific gesture wiring or automated scene-input infrastructure.

- [ ] **Step 8: Smoke the in-scene Settings interaction without adding controller coupling**

On DEBUG iPhone:

1. Open the existing SpriteKit feedback Settings modal.
2. Five-tap the top-right hotspot.
3. Verify the UIKit action sheet can present over the in-scene modal without a crash or stuck input state.
4. Cancel the action sheet and verify the same Settings modal remains usable.
5. Open the picker again, choose City 10, and verify normal Battle scene replacement removes the old scene/modal naturally.

Do not add a guard for SpriteKit Settings and do not teach `GameViewController` about `FeedbackSettingsController` state solely for HPA-618.

- [ ] **Step 9: Perform the iPad action-sheet smoke**

On an iPad portrait simulator DEBUG build:

1. Five-tap the top-right hotspot.
2. Verify the action sheet presents without a popover-anchor exception.
3. Select City 15 and verify Battle opens.

If this fails, fix only `sourceView` / `sourceRect`; do not introduce a generic presentation abstraction.

- [ ] **Step 10: Commit the ownership note after verification**

```bash
git add CLAUDE.md
git commit -m "docs: document DEBUG city jump ownership"
```

- [ ] **Step 11: Open/refresh the implementation PR and verify ready-for-review gates**

Once the implementation PR is ready, require:

- Build & Lint: PASS
- Unit Test & Codecov: PASS
- UI Test: PASS
- Codecov project status: at least 95%
- Codecov patch status: at least 95%

If patch coverage fails, inspect only the newly executable DEBUG lines first. `handleDevJumpGesture` must remain directly covered; the city alert handler must remain one executable forwarding line. Add focused coverage for genuine new behavior rather than weakening Codecov or adding abstraction solely for coverage.

## Implementation scope checkpoint

The intended runtime diff remains deliberately small:

- one new DEBUG-only production file: `Pyxis/DevJumpState.swift`;
- one existing production file modified: `Pyxis/GameViewController.swift`;
- two focused test files;
- one short `CLAUDE.md` ownership note.

If implementation starts requiring a new router, picker type, debug menu, checkpoint model, persistence API, launch configuration, scene-specific gesture wiring, or project-file registration, stop and cut that work: it is outside HPA-618.