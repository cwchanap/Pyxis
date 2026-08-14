# HPA-620 Settings Accessibility Test Stability Design

## Status

Planning design for HPA-620. This change is test-only unless a reproducible player-facing accessibility defect is discovered while implementing the plan.

## Why this is the next actionable Pyxis slice

The remaining player-feature backlog is intentionally gated:

- HPA-362 (direct lane deployment) and HPA-369 (Rally) require casual-play evidence before another battle mechanic is added.
- HPA-367 (Campaign Chronicle) remains deferred until players demonstrate completed-city history demand.
- HPA-567, the intended human validation pass, was canceled because its 1–3 hour active run plus an 8-hour idle window was too expensive under current constraints. Its partial evidence does not justify activating the gated features.
- HPA-49 was stale backlog: merged PR #4 already delivered its countryside backdrop, building art, scenic placement, and locked/unaffordable treatment, so HPA-49 is now closed as Done.

By contrast, the Settings accessibility-test flake is observed and recurring. PR #26 recorded intermittent `accessibilityElements` cast failures in Building View, Country Map, and controller tests, and PR #35 later saw another transient full-suite run with nine accessibility-adapter failures. In both cases the same tests passed unchanged in isolation / immediate rerun. Removing that false-negative verification cost is useful now without violating the roadmap evidence gate.

## Problem

`UIView.accessibilityElements` is exposed by UIKit as `[Any]?`. Pyxis's Feedback Settings adapter intentionally writes `UIAccessibilityElement` instances into that collection, but several integration tests read the whole UIKit collection with a conditional collection downcast:

```swift
view.accessibilityElements as? [UIAccessibilityElement]
```

That read is brittle: a whole-array downcast succeeds only when every object in the current UIKit collection is a `UIAccessibilityElement`. It therefore converts an incidental collection-shape difference into “no accessibility elements,” even when the Settings element the test needs is present.

The existing shared test helper in `FeedbackSettingsAccessibilityAdapterTests.swift` has the same weakness:

```swift
func accessibilityElements(in containerView: UIView) -> [UIAccessibilityElement] {
    (containerView.accessibilityElements as? [UIAccessibilityElement]) ?? []
}
```

Building View and Country Map still bypass the helper in several accessibility tests, while one GameViewController assertion reads `.first` directly from the raw UIKit collection.

This design does **not** claim that the cast is the only possible source of every historical flake. It identifies a deterministic brittle seam that exactly matches the recorded failure wording and can be removed without touching runtime behavior. Repeated focused runs are the proof that the narrow fix is sufficient.

## Design goals

1. Make existing Feedback Settings accessibility integration tests deterministic.
2. Preserve the current semantic assertions: Settings gear exposure, modal ordering, labels/values, activation, retained-element guards, focus behavior, and shared-adapter behavior.
3. Keep the production accessibility adapter unchanged.
4. Avoid retries, sleeps, polling, disabled tests, or broad test infrastructure.
5. Preserve strict unit coverage that the adapter itself writes only accessibility elements in the plain-UIView fixture.

## Non-goals

- New VoiceOver features or accessibility coverage unrelated to the observed flake.
- A production `elementsForTesting` API, snapshot model, observer, protocol, or debug surface.
- Reworking `FeedbackSettingsAccessibilityAdapter` lifecycle, scene rebinding, frame conversion, focus notifications, or element ownership without a reproducible runtime defect.
- Generic UIKit test utilities.
- Gameplay, persistence, routing, layout, audio, haptic, or CI policy changes.
- Weakening semantic assertions to “non-empty” or adding rerun logic.

## Approaches considered

### A. Retry failed tests or add waits

Rejected. The failures already disappear on rerun, so retries would hide the symptom instead of removing the nondeterministic assertion seam. There is no asynchronous contract here that justifies sleeps or polling.

### B. Add a production adapter snapshot/test API

For example, `FeedbackSettingsAccessibilityAdapter.exposedElementsForTesting` could bypass UIKit and let tests inspect the adapter directly.

Rejected. That would add runtime/test-facing state to production solely for tests and would stop the scene/controller tests from proving the UIKit integration path they are supposed to cover.

### C. Harden the existing test reader and reuse it consistently

Selected.

Keep the existing module-level `accessibilityElements(in:)` helper, but treat UIKit's collection according to its actual `[Any]?` contract:

```swift
func accessibilityElements(in containerView: UIView) -> [UIAccessibilityElement] {
    (containerView.accessibilityElements ?? []).compactMap { $0 as? UIAccessibilityElement }
}
```

Then route affected integration tests through that helper and keep their semantic label/type/identity assertions. Add one deterministic helper regression fixture with a mixed UIKit collection so the old whole-array cast would fail while the intended accessibility element remains discoverable.

This is the smallest change that preserves real UIKit integration and removes the fragile collection assumption.

## Detailed design

### 1. Characterize the collection-shape failure in test code

In `PyxisTests/FeedbackSettingsAccessibilityAdapterTests.swift`, add a focused test that creates a plain `UIView`, one `UIAccessibilityElement`, and one unrelated `UIView`, then stores both in `accessibilityElements`.

The test asserts that the shared helper returns the `UIAccessibilityElement` by identity. This creates a deterministic regression for the exact collection-shape assumption being removed; no timing or stochastic reproduction is required.

### 2. Make the shared helper element-wise, not collection-wise

Change only the helper implementation from a whole-array conditional cast to element-wise `compactMap`.

Do not add a label-filtering abstraction. Tests already express their own semantic needs clearly with `.first { $0.accessibilityLabel == ... }` or `onlyElement`; another wrapper would save little and obscure intent.

### 3. Preserve strict adapter-unit coverage

A tolerant integration reader must not silently redefine the adapter's own contract. Add a plain-UIView adapter assertion that the raw collection written by the adapter contains only `UIAccessibilityElement` instances. The existing adapter tests continue to assert exact counts, order, metadata, frames, identity, and activation on the filtered element list.

This separates two concerns:

- production adapter unit contract: it writes the intended element objects;
- UIKit-backed scene/controller integration: tests find those semantic elements without requiring every object in UIKit's `[Any]` collection to share the same concrete type.

### 4. Remove direct raw collection casts from the affected integration tests

Update only the observed surfaces:

- `PyxisTests/BuildingViewSceneTests.swift`
- `PyxisTests/CountryMapSceneTests.swift`
- `PyxisTests/GameViewControllerTests.swift`

Replace direct `view.accessibilityElements as? [UIAccessibilityElement]` and raw `.first as? UIAccessibilityElement` reads with `accessibilityElements(in: view)`.

Keep all current assertions about labels, `ActionAccessibilityElement`, activation behavior, preference mutation, layout/routing guards, and scene replacement. This is a read-path cleanup, not a behavior rewrite.

Battle and `FeedbackSettingsControllerTests` already consume the shared helper; they receive the safer helper behavior automatically and need no broad rewrite unless compilation exposes a direct dependency.

## Test strategy

### RED

Add the mixed-collection helper regression before changing the helper. It should fail because the current whole-array cast returns `[]` for a heterogeneous `[Any]` collection.

### GREEN

Change the helper to element-wise extraction and confirm the regression plus the dedicated adapter suite pass.

### Integration cleanup

Replace the remaining direct raw reads in Building View, Country Map, and GameViewController tests. Run those suites together.

### Stability proof

Run the focused accessibility-bearing suites five consecutive times with simulator parallel testing disabled. The loop must stop on the first failure; there are no retries inside a failed iteration.

Then run the normal full Pyxis test suite once, SwiftLint, and `git diff --check`.

Five focused repetitions plus one full run is intentionally bounded: it gives substantially stronger evidence than the historical single rerun without turning this small maintenance task into a soak-testing framework.

## Scope guard if the flake persists

If the focused five-run loop still fails after all direct raw collection casts are removed, do **not** add sleeps, retries, or a production testing API in HPA-620. Preserve the exact failing test names and failure output, then revise the diagnosis before widening production scope. A reproducible player-facing adapter bug may justify a production fix, but the current evidence does not.

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

No Xcode project edit is needed.

## Acceptance

HPA-620 is complete when:

- the mixed `[Any]` regression proves the shared reader can recover the intended accessibility element without a whole-array cast;
- affected integration tests use the shared reader and retain their existing semantic behavior checks;
- the adapter's plain-UIView unit fixture still proves it exposes only accessibility elements;
- five consecutive focused runs pass with parallel testing disabled;
- the full suite passes once;
- SwiftLint and `git diff --check` pass;
- no production Swift file changes unless a separately documented reproducible runtime defect is discovered.
