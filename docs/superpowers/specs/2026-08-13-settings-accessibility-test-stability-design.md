# HPA-620 Settings Accessibility Test Stability Design

## Status

Planning design for HPA-620. This change is test-only unless a reproducible player-facing accessibility defect is discovered while implementing the plan.

## Why this is the next actionable Pyxis slice

The remaining player-feature backlog is intentionally evidence-gated, while the Settings accessibility-test flake is already observed and recurring. PR #26 recorded intermittent `accessibilityElements` failures in Building View, Country Map, and controller tests, and PR #35 later saw another transient full-suite run with nine accessibility-adapter failures. In both cases the named tests passed unchanged in isolation / immediate rerun.

HPA-620 removes a brittle test read without expanding gameplay or accessibility product scope.

## Problem

`UIView.accessibilityElements` is exposed by UIKit as `[Any]?`. Pyxis's `FeedbackSettingsAccessibilityAdapter` is the sole production writer and intentionally assigns `UIAccessibilityElement` objects, but several integration tests read the entire UIKit collection with a conditional collection downcast:

```swift
view.accessibilityElements as? [UIAccessibilityElement]
```

The existing shared test helper does the same thing:

```swift
func accessibilityElements(in containerView: UIView) -> [UIAccessibilityElement] {
    (containerView.accessibilityElements as? [UIAccessibilityElement]) ?? []
}
```

That is unnecessarily strict for a property whose public contract is `[Any]?`: a heterogeneous collection makes the whole-array cast fail even when the semantic accessibility element the test needs is present.

Important diagnostic boundary: Swift's runtime **can** downcast a homogeneous `[Any]` to `[UIAccessibilityElement]` when every element matches. Type erasure alone is therefore not a deterministic reproduction of the historical flake. This design does not claim that a heterogeneous collection was definitely the historical cause. It removes one brittle read assumption, adds a raw SKView contract guard, and requires repeated execution in the full-suite regime that actually produced the failures.

## Goals

1. Make the existing Settings accessibility integration reads robust to UIKit's `[Any]?` API shape.
2. Preserve semantic assertions: Settings gear exposure, modal ordering, labels/values, activation, retained-element guards, focus behavior, and shared-adapter behavior.
3. Keep production accessibility code unchanged unless a reproducible runtime defect is found.
4. Add diagnostics that distinguish a test-reader failure from an SKView/adapter collection-shape defect.
5. Prove stability in the same full serial-suite regime where the flake was observed.

## Non-goals

- New VoiceOver behavior or accessibility product features.
- A production `ForTesting` accessor, snapshot model, protocol, observer, or debug API.
- A new helper file, query DSL, or generic UI-test framework.
- Retries, sleeps, polling, expected failures, disabled tests, or weakened CI/coverage gates.
- Gameplay, persistence, routing, layout, audio, or haptic changes.
- Rewriting tests that already use the shared helper unless compilation or a concrete finding requires it.

## Approaches considered

### A. Retry failed tests or add waits — rejected

The failures already disappear on rerun. Retries would hide the symptom and provide no diagnosis.

### B. Add a production adapter snapshot/test API — rejected

A production testing surface would bypass the UIKit integration boundary these tests are intended to exercise and would add runtime architecture for a test-only problem.

### C. Harden the existing shared reader and add SKView diagnostics — selected

Keep the existing module-level helper and change it to element-wise extraction:

```swift
func accessibilityElements(in containerView: UIView) -> [UIAccessibilityElement] {
    (containerView.accessibilityElements ?? []).compactMap { element in
        element as? UIAccessibilityElement
    }
}
```

Then route only the affected direct reads through that helper, while keeping one raw SKView assertion that the Settings adapter's mounted collection contains only `UIAccessibilityElement` instances.

This gives the integration tests a tolerant reader **without** allowing that tolerance to hide an unexpected SKView collection shape.

## Detailed design

### 1. Characterize the brittle `[Any]` assumption on SKView

Use an `SKView` in the helper regression so the fixture exercises the same view class as the historically flaky scene/controller tests.

Assign a deliberately heterogeneous but legal `[Any]` collection containing one ordinary `UIView` plus the expected `UIAccessibilityElement`:

```swift
let view = SKView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
let expected = UIAccessibilityElement(accessibilityContainer: view)
expected.accessibilityLabel = "Settings"
view.accessibilityElements = [UIView(), expected]
```

Before the helper change, the whole-array cast returns `[]`; after the change, the helper recovers `expected` by identity.

This fixture characterizes why a whole-array cast is too strong for UIKit's `[Any]?` contract. It does **not** assert that UIKit historically injected a `UIView` into Pyxis's collection.

Do not replace this with a homogeneous `[Any]` fixture: Swift's dynamic array cast succeeds when every element has the requested runtime type, so such a test would not be RED under the current helper.

### 2. Make the shared helper element-wise

Change only the existing `accessibilityElements(in:)` helper to `compactMap` each item.

Do not add label-query wrappers. Existing tests already state semantic intent clearly with `onlyElement` and `.first { $0.accessibilityLabel == ... }`.

Battle and `FeedbackSettingsControllerTests` already consume the helper and should pick up the safer read automatically.

### 3. Keep the production adapter contract strict

`FeedbackSettingsAccessibilityAdapter.expose(_:)` remains the only production writer and is unchanged.

Keep a plain-UIView adapter unit assertion that the adapter writes only `UIAccessibilityElement` instances. In addition, add one raw collection assertion on an existing SKView-backed Building View fixture:

```swift
let raw = view.accessibilityElements ?? []
#expect(raw.allSatisfy { $0 is UIAccessibilityElement })
```

This assertion must read `view.accessibilityElements` directly, not the tolerant helper.

If this raw SKView assertion fails during a full-suite run, stop HPA-620. That would mean the tolerant helper could hide a collection-shape difference that may be player-facing or adapter-related and needs a new diagnosis before production changes are proposed.

### 4. Remove only the known fragile integration reads

Update:

- `PyxisTests/BuildingViewSceneTests.swift`
- `PyxisTests/CountryMapSceneTests.swift`
- `PyxisTests/GameViewControllerTests.swift`

Replace direct whole-array casts with `accessibilityElements(in: view)`.

Change the controller's raw `.first` read to locate `"Sound Effects"` by label through the helper. `.first` is semantically wrong even when the collection is homogeneous because it assumes ordering instead of identifying the intended control.

Keep all existing activation, identity/type, preference, layout/routing, and scene-replacement assertions.

Do not rewrite Battle or controller assertions that already use the helper.

## Test strategy

### RED

Add the heterogeneous SKView helper regression before changing the helper. It must fail under the current whole-array cast.

### GREEN

Change the helper to element-wise extraction, keep the strict plain-UIView adapter assertion, add the raw SKView collection-shape assertion, and run the adapter plus affected scene/controller suites once together.

### Stability proof

The historical failures occurred during a full serial suite and then disappeared in isolation / rerun. Therefore the acceptance proof must stress the full-suite regime rather than repeat isolated suites five times.

After the focused GREEN, run the complete Pyxis suite **three consecutive times** with:

```text
-parallel-testing-enabled NO
```

Any failed full-suite iteration fails the stability gate immediately. Do not retry the failed iteration.

Three full serial runs are bounded but materially closer to the observed failure regime than five repetitions of the focused files.

Then run SwiftLint and `git diff --check`.

## Diagnostic stop conditions

Stop HPA-620 implementation and preserve exact failure evidence if either condition occurs:

1. the raw SKView collection contains a non-`UIAccessibilityElement`; or
2. any of the three consecutive full serial suites reproduces the accessibility failure after direct raw reads are removed.

Do not add waits, retries, production testing APIs, or accessibility lifecycle changes under the current diagnosis. Re-open the diagnosis first.

## Expected file footprint

Production files: **0**.

Test files:

- `PyxisTests/FeedbackSettingsAccessibilityAdapterTests.swift`
- `PyxisTests/BuildingViewSceneTests.swift`
- `PyxisTests/CountryMapSceneTests.swift`
- `PyxisTests/GameViewControllerTests.swift`

Documentation:

- this design
- `docs/superpowers/plans/2026-08-13-settings-accessibility-test-stability-implementation.md`

No Xcode project, CI, or coverage configuration changes.

## Acceptance

HPA-620 is complete when:

- the SKView heterogeneous `[Any]` regression fails before and passes after the shared-reader change;
- the shared helper uses element-wise extraction;
- affected integration tests use the helper and retain their semantic assertions;
- GameViewController finds `"Sound Effects"` by label rather than raw `.first`;
- the adapter's plain-UIView fixture and one raw SKView-backed fixture both prove the adapter-exposed collection contains only `UIAccessibilityElement` instances;
- the focused affected suites pass once;
- three consecutive full Pyxis suites pass with parallel testing disabled;
- SwiftLint and `git diff --check` pass;
- no production Swift, workflow, coverage, project, or dependency file changes unless a separately documented reproducible runtime defect is found.
