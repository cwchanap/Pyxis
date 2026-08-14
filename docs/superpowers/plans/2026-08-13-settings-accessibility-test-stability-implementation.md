# HPA-620 Settings Accessibility Flake Diagnosis and Stabilization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve Settings accessibility-test diagnostics, capture one real intermittent failure under the CI unit-test regime, and only then implement the smallest fix supported by that evidence.

**Architecture:** Keep `FeedbackSettingsAccessibilityAdapter` unchanged initially. First make the existing test reader strict/diagnostic and fix GameViewController's positional element lookup. Then reproduce the flake with `PyxisTests` only, classify the captured failure, and derive the stabilization from a focused RED -> GREEN reproducer.

**Tech Stack:** Swift 5, UIKit, SpriteKit, Swift Testing, Xcode/iOS Simulator.

## Global Constraints

- `FeedbackSettingsAccessibilityAdapter.expose(_:)` remains the sole production writer unless a captured failure proves a runtime defect.
- Reuse the existing `accessibilityElements(in:)`; no helper file, query DSL, snapshot API, or production `ForTesting` surface.
- Preserve semantic count/order/label/value/identity/activation/focus assertions.
- No speculative `compactMap`, synthetic collection fixture, standalone raw-SKView probe, retries, sleeps, disabled tests, or CI/coverage weakening.
- No speculative `.serialized`; use serialization only after evidence identifies interference and a trait boundary that actually covers the implicated tests.
- Unit reproduction/verification must match CI: `-parallel-testing-enabled NO -only-testing:PyxisTests -skip-testing:PyxisUITests`.
- Do not edit `project.pbxproj`.

---

## Task 1: Ship diagnostic correctness without claiming the flake is fixed

**Files:**
- Modify: `PyxisTests/FeedbackSettingsAccessibilityAdapterTests.swift`
- Modify: `PyxisTests/FeedbackSettingsControllerTests.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`
- Modify: `PyxisTests/BuildingViewSceneTests.swift`
- Modify: `PyxisTests/CountryMapSceneTests.swift`
- Modify: `PyxisTests/GameViewControllerTests.swift`

**Interfaces:**
- Consumes: `UIView.accessibilityElements: [Any]?`
- Consumes: Swift Testing `SourceLocation`, `#require`, `#_sourceLocation`
- Produces: `accessibilityElements(in:_:) throws -> [UIAccessibilityElement]`

- [ ] **Step 1: Run one CI-equivalent baseline before editing**

```bash
mkdir -p build/HPA620
rm -rf build/HPA620/baseline.xcresult

xcodebuild \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -resultBundlePath build/HPA620/baseline.xcresult \
  test \
  -only-testing:PyxisTests \
  -skip-testing:PyxisUITests \
  > build/HPA620/baseline.log 2>&1
```

Expected normally: PASS.

If it reproduces the accessibility flake, preserve `baseline.log` and `baseline.xcresult` and record the exact failing tests/assertions **before editing**. Continue with the diagnostic helper so the same surface reports more detail on the next reproduction; do not discard the pre-change evidence.

- [ ] **Step 2: Make the existing helper strict and caller-attributed**

Replace:

```swift
@MainActor
func accessibilityElements(in containerView: UIView) -> [UIAccessibilityElement] {
    (containerView.accessibilityElements as? [UIAccessibilityElement]) ?? []
}
```

with:

```swift
@MainActor
func accessibilityElements(
    in containerView: UIView,
    _ location: SourceLocation = #_sourceLocation
) throws -> [UIAccessibilityElement] {
    let raw = try #require(
        containerView.accessibilityElements,
        "Feedback Settings adapter exposed no accessibility collection",
        sourceLocation: location
    )

    return try raw.map { element in
        try #require(
            element as? UIAccessibilityElement,
            "Unexpected accessibility element type: \(type(of: element))",
            sourceLocation: location
        )
    }
}
```

This preserves the complete ordered collection and fails early on nil or a foreign object. Do not filter either condition away.

- [ ] **Step 3: Route real integration reads through the strict helper**

In `BuildingViewSceneTests.swift`, replace each strict raw collection cast with:

```swift
let elements = try accessibilityElements(in: view)
```

Keep its existing label/activation lookup unchanged.

In `CountryMapSceneTests.swift`, replace each:

```swift
(view.accessibilityElements as? [UIAccessibilityElement]) ?? []
```

with:

```swift
try accessibilityElements(in: view)
```

Keep all existing `onlyElement`, concrete-type, identity, activation, and frame assertions.

Then find existing shared-helper consumers:

```bash
rg -n 'accessibilityElements\(in:' PyxisTests
```

Add only the `try` plumbing required by the new signature. Typical forms are:

```swift
let elements = try accessibilityElements(in: containerView)
```

or:

```swift
#expect(try accessibilityElements(in: containerView).isEmpty)
```

Add `throws` to a test only if compilation requires it. Do not change its semantic expectations.

- [ ] **Step 4: Fix GameViewController's independent positional assumption**

Replace:

```swift
let soundEffectsElement = try #require(
    view.accessibilityElements?.first as? UIAccessibilityElement
)
```

with:

```swift
let elements = try accessibilityElements(in: view)
let soundEffectsElement = try #require(
    elements.first { $0.accessibilityLabel == "Sound Effects" }
)
```

- [ ] **Step 5: Confirm the affected raw-read patterns are gone**

```bash
rg -n \
  'accessibilityElements\s+as\?\s+\[UIAccessibilityElement\]|accessibilityElements\?\.first' \
  PyxisTests/BuildingViewSceneTests.swift \
  PyxisTests/CountryMapSceneTests.swift \
  PyxisTests/GameViewControllerTests.swift
```

Expected: no matches.

- [ ] **Step 6: Run the affected accessibility-bearing suites once**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/FeedbackSettingsAccessibilityAdapterTests \
  -only-testing:PyxisTests/FeedbackSettingsControllerTests \
  -only-testing:PyxisTests/BattleSceneTests \
  -only-testing:PyxisTests/BuildingViewSceneTests \
  -only-testing:PyxisTests/CountryMapSceneTests \
  -only-testing:PyxisTests/GameViewControllerTests
```

Expected: PASS. If it fails, preserve the strict helper's diagnostic instead of weakening it.

- [ ] **Step 7: Run the CI-equivalent unit suite once**

```bash
rm -rf build/HPA620/slice-a.xcresult
xcodebuild \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -resultBundlePath build/HPA620/slice-a.xcresult \
  test \
  -only-testing:PyxisTests \
  -skip-testing:PyxisUITests
```

Expected: PASS. This validates Slice A only; it is not evidence that the intermittent flake is fixed.

- [ ] **Step 8: Run hygiene checks and commit Slice A**

```bash
swiftlint lint --no-cache
git diff --check

git add \
  PyxisTests/FeedbackSettingsAccessibilityAdapterTests.swift \
  PyxisTests/FeedbackSettingsControllerTests.swift \
  PyxisTests/BattleSceneTests.swift \
  PyxisTests/BuildingViewSceneTests.swift \
  PyxisTests/CountryMapSceneTests.swift \
  PyxisTests/GameViewControllerTests.swift
git commit -m "test: improve settings accessibility diagnostics"
```

Slice A may merge independently. HPA-620 remains open until Task 2 demonstrates and fixes the cause.

---

## Task 2: Capture and classify one real intermittent failure

**Files:**
- Evidence first: `build/HPA620/**/*.log`, `build/HPA620/**/*.xcresult`
- Source changes: none until a cause is classified

- [ ] **Step 1: Recover historical evidence if it still exists**

Inspect retained local HPA-366/HPA-618 logs or `.xcresult` bundles before spending simulator runs. Record exact failing test names and first failing assertions. Current GitHub/Linear summaries do not retain them, so do not infer missing details.

- [ ] **Step 2: Otherwise run a bounded CI-equivalent reproduction loop**

```bash
mkdir -p build/HPA620/repro
captured=0

for run in 1 2 3 4 5; do
  result="build/HPA620/repro/run-${run}.xcresult"
  log="build/HPA620/repro/run-${run}.log"
  rm -rf "$result"

  echo "HPA-620 reproduction run ${run}/5"
  if xcodebuild \
      -project Pyxis.xcodeproj \
      -scheme Pyxis \
      -destination 'platform=iOS Simulator,name=iPhone 17' \
      -parallel-testing-enabled NO \
      -resultBundlePath "$result" \
      test \
      -only-testing:PyxisTests \
      -skip-testing:PyxisUITests \
      > "$log" 2>&1; then
    echo "run ${run}: pass"
  else
    echo "run ${run}: failure captured in $log and $result"
    captured=1
    break
  fi
done

if [ "$captured" -eq 0 ]; then
  echo "No HPA-620 failure reproduced in five CI-equivalent runs."
  exit 2
fi
```

Five green runs mean **not reproduced**, not fixed. Record that result and stop; leave HPA-620 open.

- [ ] **Step 3: Classify the first relevant captured failure**

```bash
rg -n \
  'adapter exposed no accessibility collection|Unexpected accessibility element type|accessibility|Expectation failed|failed' \
  build/HPA620/repro/run-*.log
```

Use the first Settings accessibility failure:

- `adapter exposed no accessibility collection` -> binding/writer/weak-container/fixture-lifetime path.
- `Unexpected accessibility element type` -> preserve the runtime type and investigate collection-shape/runtime integration.
- typed collection followed by wrong count/label/value/identity -> adapter state/rebinding/focus/test-interference path.
- unrelated failure -> preserve separately; it is not HPA-620 root-cause evidence.

Record the exact evidence in HPA-620 before selecting a fix.

- [ ] **Step 4: Run the cheapest cause-specific discriminator**

Do not default to `.serialized`. The named suites are `@MainActor`, and applying `.serialized` to separate top-level suites does not serialize those suites relative to unrelated peers.

If the captured evidence points to interference, first identify the competing tests/shared state, then use a temporary serialization boundary that actually contains those tests and compare repeated runs with/without it.

If evidence points to lifetime/binding, collection shape, or adapter lifecycle, test that exact mechanism instead.

- [ ] **Step 5: Add one focused RED reproducer, implement the minimal fix, confirm GREEN**

The reproducer must fail for the same reason as the captured run. Acceptable fixes depend on evidence and may be a fixture/lifetime correction, justified serialization boundary, adapter lifecycle correction, or production accessibility change only for a reproducible player-facing defect.

Commit the cause-specific fix separately from Slice A.

---

## Task 3: Verify the demonstrated fix and close HPA-620

- [ ] **Step 1: Stress the focused reproducer**

Repeat the exact focused test enough to exercise the discovered mechanism. Any failure stops verification; do not retry it away.

- [ ] **Step 2: Run three consecutive CI-equivalent unit suites after the fix**

```bash
for run in 1 2 3; do
  echo "HPA-620 post-fix PyxisTests run ${run}/3"
  xcodebuild \
    -project Pyxis.xcodeproj \
    -scheme Pyxis \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -parallel-testing-enabled NO \
    test \
    -only-testing:PyxisTests \
    -skip-testing:PyxisUITests \
    || exit 1
done
```

Expected: three consecutive PASS runs only **after** the focused RED -> GREEN proof.

- [ ] **Step 3: Run final hygiene/scope checks**

```bash
swiftlint lint --no-cache
git diff --check origin/main...HEAD
git diff --exit-code origin/main...HEAD -- .github/workflows codecov.yml
```

If production Swift changed, document the reproduced player-facing defect that required it. Otherwise confirm the fix remained test-only.

- [ ] **Step 4: Record completion evidence in Linear**

Record the captured failing test/assertion, classified root cause, focused RED -> GREEN proof, minimal fix, three post-fix PyxisTests results, lint/diff results, and any justified production scope.

Do not mark HPA-620 complete when no failure/root cause was demonstrated.
