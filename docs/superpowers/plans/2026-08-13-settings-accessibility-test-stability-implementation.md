# HPA-620 Settings Accessibility Test Stability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the recurring false-negative Settings accessibility-test seam by reading UIKit's `[Any]?` collection element-wise in tests, while keeping production accessibility behavior unchanged and proving the result in the full serial-suite regime where the flake occurred.

**Architecture:** Keep `FeedbackSettingsAccessibilityAdapter` unchanged and reuse the existing module-level `accessibilityElements(in:)` test helper. Characterize the whole-array-cast weakness on `SKView`, change the helper to `compactMap`, add raw adapter/SKView collection guards so the tolerant reader cannot hide a runtime shape defect, then route only the historically fragile direct reads through the helper. Run one focused GREEN followed by three consecutive full serial Pyxis suites.

**Tech Stack:** Swift 5, UIKit, SpriteKit, Swift Testing, Xcode/iOS Simulator.

## Global Constraints

- Production Swift files remain unchanged unless a separately reproducible player-facing accessibility defect is found.
- `FeedbackSettingsAccessibilityAdapter.expose(_:)` remains the only production writer; do not add a production `ForTesting` accessor, snapshot model, protocol, wrapper, observer, or debug API.
- Reuse the existing module-level `accessibilityElements(in:)`; do not create a new helper file, query DSL, label wrapper, or test framework.
- UIKit exposes `UIView.accessibilityElements` as `[Any]?`; integration reads must not require the entire collection to downcast before locating the intended element.
- Swift dynamic casting can downcast a homogeneous `[Any]` to `[UIAccessibilityElement]`; a homogeneous type-erased array is **not** a RED reproduction. The characterization fixture must be heterogeneous.
- Preserve semantic assertions for labels, values, ordering, element identity/type, activation, preference mutation, focus behavior, layout/routing guards, and scene replacement.
- Keep a strict raw adapter assertion on a plain `UIView` and a strict raw collection-shape assertion on an existing `SKView` scene fixture.
- If the raw SKView collection contains a non-`UIAccessibilityElement`, stop and preserve the evidence before proposing a production change.
- Do not add sleeps, polling, retries, expected-failure annotations, disabled tests, order dependencies, or CI/coverage weakening.
- Run simulator tests with `-parallel-testing-enabled NO`.
- Do not edit `project.pbxproj`.
- Keep existing Codecov project and patch gates unchanged.

## File Structure

- Modify `PyxisTests/FeedbackSettingsAccessibilityAdapterTests.swift` — import SpriteKit, add the deterministic heterogeneous-SKView RED regression, add the strict plain-UIView adapter-output assertion, and change the shared reader to element-wise extraction.
- Modify `PyxisTests/BuildingViewSceneTests.swift` — add one raw SKView collection-shape guard and replace direct whole-array Settings accessibility casts with the shared helper.
- Modify `PyxisTests/CountryMapSceneTests.swift` — replace direct whole-array Settings accessibility casts with the shared helper.
- Modify `PyxisTests/GameViewControllerTests.swift` — replace the remaining raw `.first` read with an explicit `"Sound Effects"` lookup through the shared helper.
- No production, project, workflow, coverage, asset, or dependency files.

---

## Task 1: Characterize and harden the shared accessibility reader

**Files:**
- Modify: `PyxisTests/FeedbackSettingsAccessibilityAdapterTests.swift`

**Interfaces:**
- Consumes: `UIView.accessibilityElements: [Any]?`
- Consumes: `SKView`
- Consumes: `UIAccessibilityElement`
- Produces: `accessibilityElements(in:) -> [UIAccessibilityElement]` using element-wise extraction

- [ ] **Step 1: Add SpriteKit to the existing test file**

At the imports, add:

```swift
import SpriteKit
```

Do not create a new test target or helper file.

- [ ] **Step 2: Add the RED heterogeneous-SKView regression before changing the helper**

Add this test to `FeedbackSettingsAccessibilityAdapterTests`:

```swift
@Test func accessibilityElementsHelperReadsMixedSKViewCollectionElementWise() throws {
    let view = SKView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    let expected = UIAccessibilityElement(accessibilityContainer: view)
    expected.accessibilityLabel = "Settings"

    view.accessibilityElements = [UIView(), expected]

    let elements = accessibilityElements(in: view)

    #expect(elements.count == 1)
    #expect(elements[0] === expected)
}
```

The extra `UIView` is deliberate test data that makes the public `[Any]` collection heterogeneous. This characterizes the whole-array-cast weakness on the same view class as the flaky integration tests; it does **not** claim UIKit historically injected that exact object.

Do not use a homogeneous `[Any]` fixture. Swift's runtime collection cast succeeds when every element has the requested runtime type, so that fixture would already pass before the helper change.

- [ ] **Step 3: Run the adapter suite and confirm RED**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/FeedbackSettingsAccessibilityAdapterTests
```

Expected: the new mixed-SKView helper test fails because the current whole-array cast returns no elements.

If an unrelated pre-existing test fails, stop and preserve that result rather than treating it as the intended RED.

- [ ] **Step 4: Change only the shared helper to element-wise extraction**

Replace:

```swift
func accessibilityElements(in containerView: UIView) -> [UIAccessibilityElement] {
    (containerView.accessibilityElements as? [UIAccessibilityElement]) ?? []
}
```

with:

```swift
func accessibilityElements(in containerView: UIView) -> [UIAccessibilityElement] {
    (containerView.accessibilityElements ?? []).compactMap { element in
        element as? UIAccessibilityElement
    }
}
```

Do not add a label query helper. Callers keep using `onlyElement` or their existing semantic `.first { ... }` expressions.

- [ ] **Step 5: Add a strict plain-UIView adapter-output assertion**

Add:

```swift
@Test func adapterWritesOnlyAccessibilityElementsToPlainUIView() throws {
    let context = makeAccessibilityContext()
    context.adapter.applyGear(frame: CGRect(x: 16, y: 24, width: 44, height: 44))

    let rawElements = try #require(context.containerView.accessibilityElements)

    #expect(rawElements.count == 1)
    #expect(rawElements.allSatisfy { $0 is UIAccessibilityElement })
}
```

This protects the adapter's own writer contract independently of the tolerant integration reader.

- [ ] **Step 6: Re-run the adapter suite and confirm GREEN**

Run Step 3 again.

Expected: all adapter tests pass, including the mixed-SKView regression and strict raw-output assertion.

- [ ] **Step 7: Commit the reader slice**

```bash
git add PyxisTests/FeedbackSettingsAccessibilityAdapterTests.swift
git commit -m "test: harden accessibility element reader"
```

---

## Task 2: Keep SKView strict and route only fragile integration reads through the helper

**Files:**
- Modify: `PyxisTests/BuildingViewSceneTests.swift`
- Modify: `PyxisTests/CountryMapSceneTests.swift`
- Modify: `PyxisTests/GameViewControllerTests.swift`

**Interfaces:**
- Consumes: `accessibilityElements(in:)`
- Consumes: existing `ActionAccessibilityElement`
- Produces: no direct whole-array casts on the historically flaky surfaces
- Produces: one raw SKView collection-shape guard

- [ ] **Step 1: Add the raw SKView guard beside Building View accessibility coverage**

Use the existing `makeSceneAndPreviewView(...)` fixture and read the raw property directly:

```swift
@Test("Building View SKView exposes only accessibility elements")
func buildingViewRawAccessibilityCollectionContainsOnlyAccessibilityElements() throws {
    let (_, view) = makeSceneAndPreviewView(
        store: try makeStore(initialState: KingdomGameState(gold: 100)),
        router: RouteSpy()
    )

    let raw = try #require(view.accessibilityElements)

    #expect(!raw.isEmpty)
    #expect(raw.allSatisfy { $0 is UIAccessibilityElement })
}
```

Do **not** read this assertion through `accessibilityElements(in:)`. Its job is to fail if the tolerant helper would otherwise drop an unexpected SKView object.

If this assertion ever fails in the full-suite stability run, stop HPA-620 and record the raw collection-shape failure before changing production code.

- [ ] **Step 2: Replace Building View's direct collection casts**

Replace each:

```swift
try #require(view.accessibilityElements as? [UIAccessibilityElement])
```

with:

```swift
accessibilityElements(in: view)
```

Keep the existing semantic lookups and assertions unchanged, including Settings gear activation, Sound Effects, Haptics, Close, layout-gate refusal, and routing refusal.

- [ ] **Step 3: Replace Country Map's direct collection casts**

Replace each:

```swift
(view.accessibilityElements as? [UIAccessibilityElement]) ?? []
```

with:

```swift
accessibilityElements(in: view)
```

Preserve the existing `ActionAccessibilityElement` type/identity assertions and activation behavior for retained gear/modal elements and frame conversion.

- [ ] **Step 4: Make GameViewController identify Sound Effects semantically**

Replace the raw first-element read:

```swift
let soundEffectsElement = try #require(
    view.accessibilityElements?.first as? UIAccessibilityElement
)
```

with:

```swift
let soundEffectsElement = try #require(
    accessibilityElements(in: view)
        .first { $0.accessibilityLabel == "Sound Effects" }
)
```

Keep the existing value expectation. Do not rewrite controller assertions that already use the shared helper.

- [ ] **Step 5: Prove the fragile raw-read patterns are gone from the affected files**

```bash
rg -n \
  'accessibilityElements\s+as\?\s+\[UIAccessibilityElement\]|accessibilityElements\?\.first' \
  PyxisTests/BuildingViewSceneTests.swift \
  PyxisTests/CountryMapSceneTests.swift \
  PyxisTests/GameViewControllerTests.swift
```

Expected: no matches.

Do not turn this into a repository-wide rewrite. Battle and other tests already using the helper stay unchanged.

- [ ] **Step 6: Run one combined focused GREEN**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/FeedbackSettingsAccessibilityAdapterTests \
  -only-testing:PyxisTests/BuildingViewSceneTests \
  -only-testing:PyxisTests/CountryMapSceneTests \
  -only-testing:PyxisTests/GameViewControllerTests
```

Expected: PASS with the original semantic Settings accessibility assertions intact and the new raw SKView guard passing.

- [ ] **Step 7: Commit the integration cleanup**

```bash
git add \
  PyxisTests/BuildingViewSceneTests.swift \
  PyxisTests/CountryMapSceneTests.swift \
  PyxisTests/GameViewControllerTests.swift
git commit -m "test: stabilize settings accessibility integration"
```

---

## Task 3: Stress the actual failure regime and close scope

**Files:**
- Verify only; no planned source changes.

- [ ] **Step 1: Run three consecutive complete serial Pyxis suites**

The historical failures occurred in a full serial suite and disappeared when the affected tests were run in isolation / rerun. Do not spend the stability budget repeating the isolated grouping.

Run:

```bash
for run in 1 2 3; do
  echo "HPA-620 full serial run ${run}/3"
  xcodebuild test \
    -project Pyxis.xcodeproj \
    -scheme Pyxis \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -parallel-testing-enabled NO \
    || exit 1
done
```

Expected: three consecutive complete PASS results.

This is a stability gate, not retry-on-failure. The loop exits on the first failure.

If any run fails, record:

- run number;
- exact failing test names;
- assertion/failure text;
- whether `buildingViewRawAccessibilityCollectionContainsOnlyAccessibilityElements` failed;
- whether the failure still concerns Settings accessibility exposure.

Then stop HPA-620 implementation. Do not add sleeps/retries or change production accessibility code under the existing diagnosis.

- [ ] **Step 2: Run lint and diff hygiene**

```bash
swiftlint lint --no-cache
git diff --check origin/main...HEAD
```

Expected: SwiftLint exits 0 with no new serious violation; diff check is clean.

- [ ] **Step 3: Prove the implementation stayed test-only**

```bash
git diff --name-only origin/main...HEAD -- 'Pyxis/*.swift'
```

Expected: empty output.

Review the implementation diff:

```bash
git diff origin/main...HEAD -- \
  PyxisTests/FeedbackSettingsAccessibilityAdapterTests.swift \
  PyxisTests/BuildingViewSceneTests.swift \
  PyxisTests/CountryMapSceneTests.swift \
  PyxisTests/GameViewControllerTests.swift
```

Expected: only the shared-reader regression/change, strict raw guards, and direct-read replacements described above.

- [ ] **Step 4: Verify CI and coverage policy did not change**

```bash
git diff --exit-code origin/main...HEAD -- \
  .github/workflows \
  codecov.yml
```

Expected: exit 0.

- [ ] **Step 5: Record HPA-620 verification evidence**

Update HPA-620 with:

- focused GREEN result;
- full serial run 1/3, 2/3, and 3/3 results;
- raw SKView collection guard result;
- SwiftLint and `git diff --check` results;
- confirmation that no production Swift/CI/coverage file changed;
- exact evidence instead if the stability gate failed.

Do not create an empty verification commit.

## Final expected diff

Implementation should change exactly:

- `PyxisTests/FeedbackSettingsAccessibilityAdapterTests.swift`
- `PyxisTests/BuildingViewSceneTests.swift`
- `PyxisTests/CountryMapSceneTests.swift`
- `PyxisTests/GameViewControllerTests.swift`

No production file, asset, project file, workflow, dependency, gameplay rule, persistence schema, or accessibility feature should change.
