# HPA-620 Settings Accessibility Test Stability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the recurring false-negative Feedback Settings accessibility-test seam by reading UIKit's `[Any]?` accessibility collection element-wise in tests, without changing player-facing accessibility behavior or production architecture.

**Architecture:** Keep `FeedbackSettingsAccessibilityAdapter` unchanged. Harden the existing module-level `accessibilityElements(in:)` test helper in `FeedbackSettingsAccessibilityAdapterTests.swift`, add one deterministic mixed-collection regression plus a strict raw adapter-output assertion, then route the affected Building View, Country Map, and GameViewController integration tests through that helper. Prove stability with five consecutive focused runs and one full suite.

**Tech Stack:** Swift 5, UIKit, SpriteKit, Swift Testing, Xcode/iOS Simulator.

## Global Constraints

- Production Swift files should remain unchanged.
- Do not add a production `ForTesting` accessor, snapshot model, protocol, adapter wrapper, observer, or debug API.
- Do not add sleeps, polling, retries, test disabling, expected-failure annotations, or order dependencies.
- Preserve the existing semantic assertions: labels, values, ordering, element identity/type, activation, preference mutation, focus behavior, layout/routing guards, and scene replacement.
- UIKit exposes `UIView.accessibilityElements` as `[Any]?`; tests must not require the entire collection to downcast to `[UIAccessibilityElement]` before locating the intended element.
- Keep a strict adapter-unit assertion that the plain-UIView fixture itself is populated only with `UIAccessibilityElement` instances.
- Do not expand accessibility product scope.
- If the five-run focused loop still fails after direct raw casts are removed, stop HPA-620 implementation and record the exact failure before proposing any production change. Do not paper over it in this ticket.
- Run simulator tests with `-parallel-testing-enabled NO`.
- Do not edit `project.pbxproj`.
- Keep existing Codecov project and patch gates unchanged.

## File Structure

- Modify `PyxisTests/FeedbackSettingsAccessibilityAdapterTests.swift` — deterministic mixed-collection regression, strict adapter-output assertion, and safer shared `accessibilityElements(in:)` helper.
- Modify `PyxisTests/BuildingViewSceneTests.swift` — replace direct whole-array Settings accessibility reads with the shared helper.
- Modify `PyxisTests/CountryMapSceneTests.swift` — replace direct whole-array Settings accessibility reads with the shared helper.
- Modify `PyxisTests/GameViewControllerTests.swift` — replace the remaining raw `.first` accessibility read with the shared helper.
- No production files.

---

## Task 1: Characterize and fix the shared accessibility-element reader

**Files:**
- Modify: `PyxisTests/FeedbackSettingsAccessibilityAdapterTests.swift`

**Consumes:**
- `UIView.accessibilityElements: [Any]?`
- `UIAccessibilityElement`
- existing module-level `accessibilityElements(in:)`

**Produces:**
- deterministic regression for a heterogeneous UIKit accessibility collection
- element-wise shared reader
- strict adapter-output assertion on the plain-UIView fixture

- [ ] **Step 1: Add the RED mixed-collection regression before changing the helper**

Add this test to `FeedbackSettingsAccessibilityAdapterTests`:

```swift
@Test func accessibilityElementsHelperReadsMixedUIKitCollectionElementWise() throws {
    let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    let expected = UIAccessibilityElement(accessibilityContainer: view)
    expected.accessibilityLabel = "Settings"

    view.accessibilityElements = [UIView(), expected]

    let elements = accessibilityElements(in: view)

    #expect(elements.count == 1)
    #expect(elements[0] === expected)
}
```

This fixture is intentionally heterogeneous. The current helper's whole-array cast should return `[]`, so the new test must fail before the helper changes.

- [ ] **Step 2: Run the adapter test suite and confirm RED**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/FeedbackSettingsAccessibilityAdapterTests
```

Expected: FAIL only because the new mixed-collection helper test does not recover `expected`.

Do not proceed if an unrelated existing test fails; preserve that output because HPA-620 is specifically about distinguishing existing instability from the new regression.

- [ ] **Step 3: Change the helper to element-wise extraction**

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

Do not add a generic predicate/query helper. Existing tests can continue to state their semantic lookup directly with `onlyElement` or `first { $0.accessibilityLabel == ... }`.

- [ ] **Step 4: Add a strict raw-output unit assertion for the adapter itself**

Add one test using `makeAccessibilityContext()`:

```swift
@Test func adapterWritesOnlyAccessibilityElementsToPlainUIView() throws {
    let context = makeAccessibilityContext()
    context.adapter.applyGear(frame: CGRect(x: 16, y: 24, width: 44, height: 44))

    let rawElements = try #require(context.containerView.accessibilityElements)

    #expect(rawElements.count == 1)
    #expect(rawElements.allSatisfy { $0 is UIAccessibilityElement })
}
```

This keeps the production adapter contract strict while the integration reader tolerates UIKit's `[Any]` container shape.

- [ ] **Step 5: Re-run the adapter suite and confirm GREEN**

Run Step 2 again.

Expected: all adapter tests pass, including the mixed-collection regression and strict raw-output assertion.

- [ ] **Step 6: Commit the reader slice**

```bash
git add PyxisTests/FeedbackSettingsAccessibilityAdapterTests.swift
git commit -m "test: harden accessibility element reader"
```

---

## Task 2: Route affected scene/controller accessibility tests through the shared reader

**Files:**
- Modify: `PyxisTests/BuildingViewSceneTests.swift`
- Modify: `PyxisTests/CountryMapSceneTests.swift`
- Modify: `PyxisTests/GameViewControllerTests.swift`

**Consumes:**
- `accessibilityElements(in:)` from the test target
- existing `ActionAccessibilityElement`
- existing Settings accessibility labels and activation behavior

**Produces:**
- no direct whole-array `[UIAccessibilityElement]` casts on the three historically flaky surfaces
- no direct raw `.first as? UIAccessibilityElement` read in the controller test

- [ ] **Step 1: Replace Building View's direct collection casts**

In `BuildingViewSceneTests.swift`, replace every form of:

```swift
try #require(view.accessibilityElements as? [UIAccessibilityElement])
```

with:

```swift
accessibilityElements(in: view)
```

Keep the existing semantic lookups and behavior checks unchanged, including:

- Settings gear activation opens Settings;
- Sound Effects activation toggles the preference;
- Haptics activation toggles the preference;
- Close activation closes Settings;
- retained gear activation remains blocked while the layout gate is paused;
- retained gear activation remains blocked while routing to Battle.

Do not replace those assertions with only a count/non-empty check.

- [ ] **Step 2: Replace Country Map's direct collection casts**

In `CountryMapSceneTests.swift`, replace every form of:

```swift
(view.accessibilityElements as? [UIAccessibilityElement]) ?? []
```

with:

```swift
accessibilityElements(in: view)
```

Keep the existing `ActionAccessibilityElement` type/identity assertions and the semantic activation checks for:

- layout-gate refusal of a retained Settings gear;
- Settings modal Sound Effects / Haptics / Close actions;
- retained modal elements after dismissal;
- gear frame conversion into UIKit screen coordinates.

- [ ] **Step 3: Replace GameViewController's remaining raw first-element read**

Change the controller test that currently does:

```swift
let soundEffectsElement = try #require(
    view.accessibilityElements?.first as? UIAccessibilityElement
)
```

so it uses the shared reader and locates the semantic element explicitly:

```swift
let soundEffectsElement = try #require(
    accessibilityElements(in: view)
        .first { $0.accessibilityLabel == "Sound Effects" }
)
```

Preserve the existing expectation that the element's value reflects the preference after scene replacement.

Leave existing controller assertions that already use `accessibilityElements(in:)` unchanged.

- [ ] **Step 4: Assert the fragile raw read patterns are gone from the affected files**

```bash
rg -n \
  'accessibilityElements\s+as\?\s+\[UIAccessibilityElement\]|accessibilityElements\?\.first' \
  PyxisTests/BuildingViewSceneTests.swift \
  PyxisTests/CountryMapSceneTests.swift \
  PyxisTests/GameViewControllerTests.swift
```

Expected: no matches.

Do not globally rewrite unrelated accessibility tests just to make this grep repository-wide; HPA-620 is bounded to the observed surfaces.

- [ ] **Step 5: Run the affected suites together**

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

Expected: PASS with all existing semantic Settings accessibility coverage intact.

- [ ] **Step 6: Commit the integration cleanup**

```bash
git add \
  PyxisTests/BuildingViewSceneTests.swift \
  PyxisTests/CountryMapSceneTests.swift \
  PyxisTests/GameViewControllerTests.swift
git commit -m "test: stabilize settings accessibility integration"
```

---

## Task 3: Prove the flake is gone without retries and close the scope

**Files:**
- Verify only; no planned source changes.

- [ ] **Step 1: Run five consecutive focused iterations**

Use one shell loop that exits immediately on the first failed iteration:

```bash
for run in 1 2 3 4 5; do
  echo "HPA-620 focused run ${run}/5"
  xcodebuild test \
    -project Pyxis.xcodeproj \
    -scheme Pyxis \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -parallel-testing-enabled NO \
    -only-testing:PyxisTests/FeedbackSettingsAccessibilityAdapterTests \
    -only-testing:PyxisTests/BuildingViewSceneTests \
    -only-testing:PyxisTests/CountryMapSceneTests \
    -only-testing:PyxisTests/GameViewControllerTests \
    || exit 1
done
```

Expected: five consecutive PASS results. This is repeated execution, not retry-on-failure: any failed iteration fails the acceptance gate.

If any iteration fails, stop here. Record the exact failing test names and assertions on HPA-620; do not add waits/retries or modify production code under the existing diagnosis.

- [ ] **Step 2: Run the complete suite once in the repository's normal serial mode**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO
```

Expected: full PASS.

- [ ] **Step 3: Run lint and diff hygiene**

```bash
swiftlint lint --no-cache
git diff --check origin/main...HEAD
```

Expected: SwiftLint exits 0 with no new serious violation; diff check is clean.

- [ ] **Step 4: Prove the implementation stayed test-only**

```bash
git diff --name-only origin/main...HEAD -- 'Pyxis/*.swift'
```

Expected: empty output.

Also review the complete diff:

```bash
git diff --stat origin/main...HEAD
git diff origin/main...HEAD -- \
  PyxisTests/FeedbackSettingsAccessibilityAdapterTests.swift \
  PyxisTests/BuildingViewSceneTests.swift \
  PyxisTests/CountryMapSceneTests.swift \
  PyxisTests/GameViewControllerTests.swift
```

Expected: only the shared test reader/regression and the direct-read replacements described above.

- [ ] **Step 5: Verify CI/coverage policy was not changed**

```bash
git diff --exit-code origin/main...HEAD -- \
  .github/workflows \
  codecov.yml
```

Expected: exit 0. HPA-620 fixes tests; it does not weaken verification to make them pass.

- [ ] **Step 6: Record HPA-620 evidence and final implementation commit if needed**

If implementation required no changes after Task 2, do not create an empty commit. Otherwise commit only legitimate test cleanup found by verification.

Update HPA-620 with:

- five focused run results;
- full-suite result;
- SwiftLint and diff-check result;
- confirmation that no production Swift file changed;
- any remaining flake evidence if the stability gate failed.

## Final expected diff

The implementation should change exactly these test files unless compilation proves an already-existing shared test dependency:

- `PyxisTests/FeedbackSettingsAccessibilityAdapterTests.swift`
- `PyxisTests/BuildingViewSceneTests.swift`
- `PyxisTests/CountryMapSceneTests.swift`
- `PyxisTests/GameViewControllerTests.swift`

No production file, asset, project file, workflow, dependency, gameplay rule, persistence schema, or accessibility feature should change.
