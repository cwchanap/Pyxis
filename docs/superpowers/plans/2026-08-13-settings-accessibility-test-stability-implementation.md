# HPA-620 Settings Accessibility Flake Diagnosis and Stabilization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve Settings accessibility-test diagnostics, capture one real intermittent failure under the CI unit-test regime, and only then implement the smallest fix supported by that evidence.

**Architecture:** Keep `FeedbackSettingsAccessibilityAdapter` unchanged initially. First make the existing test reader strict/diagnostic and fix GameViewController's positional element lookup. Then reproduce the flake with `PyxisTests` only, classify the captured failure, and derive the actual stabilization from a focused RED -> GREEN reproducer.

**Tech Stack:** Swift 5, UIKit, SpriteKit, Swift Testing, Xcode/iOS Simulator.

## Global Constraints

- `FeedbackSettingsAccessibilityAdapter.expose(_:)` remains the sole production writer unless a captured failure proves a runtime defect.
- Reuse the existing module-level `accessibilityElements(in:)`; no helper file, query DSL, snapshot API, or production `ForTesting` surface.
- Preserve existing semantic assertions for count, order, labels, values, identity/type, activation, focus, preferences, and scene routing.
- Do not add `compactMap`, a synthetic mixed-collection test, or a standalone raw-SKView guard as a presumed fix.
- Do not add retries, sleeps, polling, expected failures, disabled tests, or CI/coverage weakening.
- Do not add `.serialized` speculatively. Use serialization only after a captured failure identifies a state/interference hypothesis and the chosen trait boundary actually covers the implicated tests.
- Unit reproduction/verification must match CI: `-parallel-testing-enabled NO -only-testing:PyxisTests -skip-testing:PyxisUITests`.
- Do not edit `project.pbxproj`.

---

## Task 1: Ship better diagnostics without claiming the flake is fixed

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

- [ ] **Step 1: Run one CI-equivalent baseline before editing the reader**

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

If this run reproduces the intermittent accessibility failure, **stop before editing Task 1**. Preserve `baseline.log` + `baseline.xcresult`, record the exact failing tests/assertions, and jump to Task 2 Step 3 with the stronger pre-change evidence.

- [ ] **Step 2: Replace the existing silent helper with one strict throwing reader**

In `PyxisTests/FeedbackSettingsAccessibilityAdapterTests.swift`, replace:

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

Do not filter foreign objects. A foreign object is evidence to preserve, not something the test helper should hide.

- [ ] **Step 3: Route the existing direct collection reads through the strict helper**

In `BuildingViewSceneTests.swift`, replace each direct form:

```swift
try #require(view.accessibilityElements as? [UIAccessibilityElement])
```

with a local strict read:

```swift
let elements = try accessibilityElements(in: view)
```

Keep the existing label/activation assertion that follows the read.

In `CountryMapSceneTests.swift`, replace each:

```swift
(view.accessibilityElements as? [UIAccessibilityElement]) ?? []
```

with:

```swift
try accessibilityElements(in: view)
```

Keep every existing `onlyElement`, `ActionAccessibilityElement`, label, identity, activation, and frame assertion unchanged.

- [ ] **Step 4: Mechanically add `try` to current helper consumers**

Find all helper uses:

```bash
rg -n 'accessibilityElements\(in:' PyxisTests
```

For existing helper consumers in adapter, controller, Battle, and GameViewController tests, add only the `try` plumbing required by the new signature. Examples:

```swift
let elements = try accessibilityElements(in: context.containerView)
```

and:

```swift
#expect(try accessibilityElements(in: containerView).isEmpty)
```

Do not change the surrounding semantic expectations. Add `throws` to a test function only if the compiler requires it.

- [ ] **Step 5: Fix the independent GameViewController positional lookup**

Replace:

```swift
let soundEffectsElement = try #require(
    view.accessibilityElements?.first as? UIAccessibilityElement
)
```

with:

```swift
let soundEffectsElement = try #require(
    try accessibilityElements(in: view)
        .first { $0.accessibilityLabel == "Sound Effects" }
)
```

The test now identifies the intended control semantically rather than assuming it is first.

- [ ] **Step 6: Confirm the fragile raw patterns are gone from the affected integration files**

```bash
rg -n \
  'accessibilityElements\s+as\?\s+\[UIAccessibilityElement\]|accessibilityElements\?\.first' \
  PyxisTests/BuildingViewSceneTests.swift \
  PyxisTests/CountryMapSceneTests.swift \
  PyxisTests/GameViewControllerTests.swift
```

Expected: no matches.

- [ ] **Step 7: Run the accessibility-bearing suites once**

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

Expected: PASS. If it fails, preserve the new diagnostic message; do not soften the helper.

- [ ] **Step 8: Run the CI-equivalent unit suite once**

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

Expected: PASS. This validates Slice A only; it does not establish that the intermittent flake is fixed.

- [ ] **Step 9: Run hygiene checks and commit Slice A**

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

Slice A may merge independently even if Task 2 cannot reproduce the flake. HPA-620 itself remains open until the cause is demonstrated and fixed.

---

## Task 2: Capture and classify one real intermittent failure

**Files:**
- Evidence only at first: `build/HPA620/*.log`, `build/HPA620/*.xcresult`
- Source changes: none until Step 4 identifies a cause

**Interfaces:**
- Consumes: diagnostic helper messages from Task 1
- Consumes: CI-equivalent `PyxisTests` command
- Produces: exact failing test name, assertion/diagnostic, and root-cause hypothesis supported by one captured run

- [ ] **Step 1: Check for retained historical evidence before spending simulator runs**

Inspect any retained local HPA-618/HPA-366 test logs or `.xcresult` bundles. If they contain the original PR #26/#35 failure, record:

- failing test names;
- first failing assertion/message per test;
- whether the raw collection was nil, foreign-typed, or semantically wrong if that can be determined.

The current PR and Linear summaries do not preserve those details, so do not invent them if local artifacts are gone.

- [ ] **Step 2: If historical detail is unavailable, run a bounded CI-equivalent reproduction loop**

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

A green five-run window is inconclusive. Record it and stop implementation without declaring HPA-620 fixed.

- [ ] **Step 3: Classify the first captured failure before editing source**

Search the captured log:

```bash
rg -n \
  'adapter exposed no accessibility collection|Unexpected accessibility element type|accessibility|Expectation failed|failed' \
  build/HPA620/repro/run-*.log
```

Classify the first relevant failure:

- **`adapter exposed no accessibility collection`**: investigate adapter binding, weak `containerView`, scene mount/rebind ordering, and fixture lifetime at that test.
- **`Unexpected accessibility element type`**: preserve the reported runtime type; determine whether UIKit/test setup or production adapter integration introduced it.
- **typed collection but later semantic failure**: investigate count/order/label/value/identity and adapter rebind/focus state at that exact surface.
- **unrelated failure**: preserve it separately and continue HPA-620 only when the Settings accessibility symptom is captured.

Add the exact evidence to HPA-620 before choosing a fix.

- [ ] **Step 4: Test the cheapest cause-specific discriminator**

Do not default to `.serialized` merely because Swift Testing supports in-process parallelism. The named suites are `@MainActor`, and suite-local `.serialized` traits do not serialize unrelated peer suites against each other.

If the captured evidence points to state interference, first identify the competing test(s) or shared state. Then create the smallest temporary discriminator whose serialization boundary actually includes the implicated tests and compare repeated runs with/without it.

If evidence instead points to nil lifetime/binding, collection shape, or adapter lifecycle, test that specific path directly rather than adding serialization.

- [ ] **Step 5: Write one focused RED reproducer for the demonstrated cause**

The reproducer must fail for the same reason as the captured run, not for a synthetic cast shape. Name it after the actual behavior discovered in Step 3.

Run only that test and confirm RED before changing the implementation/fixture.

- [ ] **Step 6: Implement the smallest cause-specific fix and confirm GREEN**

Allowed outcomes include:

- test fixture/lifetime correction;
- a justified serialization boundary covering the actual conflicting tests;
- adapter lifecycle/rebinding correction;
- production accessibility change only when a reproducible player-facing defect requires it.

Do not add generic test infrastructure or retry behavior.

Commit the cause-specific fix separately from Slice A.

---

## Task 3: Verify the demonstrated fix and close HPA-620

**Files:**
- Verify the actual Task 2 diff only

- [ ] **Step 1: Stress the focused reproducer**

Run the exact focused test repeatedly enough to exercise the discovered mechanism. Any failure stops verification; do not retry it away.

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

Expected: three consecutive PASS runs **after** the focused RED -> GREEN proof.

- [ ] **Step 3: Run final hygiene and scope checks**

```bash
swiftlint lint --no-cache
git diff --check origin/main...HEAD
git diff --exit-code origin/main...HEAD -- .github/workflows codecov.yml
```

If production Swift changed, document the reproduced player-facing defect that required it. Otherwise confirm the final fix remained test-only.

- [ ] **Step 4: Record evidence in Linear**

HPA-620's completion note must include:

- captured historical/reproduction failing test and assertion;
- classified root cause;
- focused RED -> GREEN test;
- exact minimal fix;
- post-fix PyxisTests 1/3, 2/3, 3/3 results;
- SwiftLint and diff-check results;
- whether production accessibility code changed and why.

Do not mark HPA-620 complete if the reproduction loop stayed green and no root cause was demonstrated.
