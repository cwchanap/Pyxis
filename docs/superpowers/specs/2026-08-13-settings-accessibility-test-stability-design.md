# HPA-620 Settings Accessibility Flake Diagnosis Design

## Status

Planning design for HPA-620. The issue is now diagnosis-first: improve test diagnostics, reproduce one real intermittent failure, then fix the demonstrated cause. Do not treat green reruns as proof of a root cause.

## Evidence we actually have

PR #26 recorded intermittent Settings accessibility failures across `BuildingViewSceneTests`, `CountryMapSceneTests`, and `GameViewControllerTests`; the tests passed unchanged in isolation / rerun.

PR #35 later recorded nine transient accessibility-adapter failures followed by an unchanged 843/843 rerun. The retained GitHub/Linear record does not contain the exact nine failing test names or assertion messages, so HPA-620 cannot honestly derive a root cause from those summaries alone.

Current test reads are also not uniform:

- Building View has strict `try #require(view.accessibilityElements as? [UIAccessibilityElement])` reads.
- Country Map uses the same whole-array cast with `?? []` fallback.
- GameViewController has one positional `view.accessibilityElements?.first` read.
- The existing shared `accessibilityElements(in:)` helper also converts nil or a failed whole-array cast to `[]`.

The prior `compactMap` design was therefore too confident. A heterogeneous UIKit collection could defeat the current whole-array casts, but the historical evidence does not prove that happened, and `compactMap` would discard diagnostic information about nil or foreign objects.

## Goals

1. Make the next accessibility failure identify the earliest useful distinction: no collection, foreign object, or semantically wrong typed collection.
2. Fix the independent GameViewController positional lookup.
3. Reproduce the intermittent failure under the same unit-test command shape used by CI.
4. Choose a stabilization change only after a concrete failing run points to a cause.
5. Keep production accessibility code unchanged unless the captured failure demonstrates a runtime defect.

## Non-goals

- No tolerant `compactMap` reader as a speculative fix.
- No synthetic cast-semantics regression fixture.
- No standalone raw-SKView probe that only exercises a fresh green fixture.
- No production `ForTesting` API, snapshot model, observer, protocol, or debug surface.
- No retries, sleeps, polling, expected failures, disabled tests, or weakened CI/coverage gates.
- No blanket `.serialized` change without evidence that test interference is the cause.
- No gameplay, persistence, routing, layout, sound, or haptic changes.

## Existing production boundary

`FeedbackSettingsAccessibilityAdapter.expose(_:)` remains the sole production writer to `containerView.accessibilityElements`. It accepts `[UIAccessibilityElement]` and should not change under the current evidence.

## Selected approach

### Slice A: diagnostic correctness that is safe to ship independently

Reuse the existing module-level `accessibilityElements(in:)` helper, but make it strict and throwing instead of tolerant:

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

This keeps the existing helper rather than adding a test framework. It preserves collection order and count and makes every caller a shape check on the real fixture it is already exercising.

The helper distinguishes:

- `accessibilityElements == nil` -> writer/binding/fixture-lifetime problem;
- a non-`UIAccessibilityElement` object -> unexpected collection shape;
- a valid typed collection -> the caller's existing semantic count/label/identity/value assertion remains responsible for the next failure.

`SourceLocation` forwards the failure to the calling test instead of reporting only the helper implementation line.

Migrate the direct Building View and Country Map collection reads through this helper. Existing helper consumers in Battle, Feedback Settings controller, adapter, and GameViewController tests receive only the required `try` plumbing; their semantic assertions remain unchanged.

Separately, change the GameViewController test that assumes `accessibilityElements?.first` is Sound Effects to locate the element by `accessibilityLabel == "Sound Effects"`. That is a correctness cleanup independent of the intermittent failure.

Slice A is diagnostic hardening. Passing Slice A does not close HPA-620.

### Slice B: capture one real failure before selecting a fix

First recover historical failure detail from a retained local `.xcresult` or log if one still exists. The current GitHub/Linear evidence is insufficient.

If no retained artifact exists, repeatedly run the CI-equivalent unit-test command, preserving one log/result bundle per run and stopping at the first failure:

```text
-parallel-testing-enabled NO
-only-testing:PyxisTests
-skip-testing:PyxisUITests
```

Do not use a bare scheme run: CI executes `PyxisTests` and `PyxisUITests` as separate jobs, and the cited 843-test rerun is unit-test evidence.

If a bounded reproduction loop remains green, record the attempt as inconclusive and leave HPA-620 open. Do not claim the flake is fixed because it did not reproduce.

When a failure is captured, classify it before editing behavior:

1. **No accessibility collection** — inspect adapter binding, weak-container lifetime, scene mounting/rebinding, and fixture ownership at that exact failing surface.
2. **Foreign collection object** — inspect the raw runtime object and decide whether the issue is test setup or a player-facing UIKit/adapter integration defect.
3. **Typed collection, wrong semantics** — inspect adapter state/rebinding/focus/order and possible test interference.
4. **Unrelated failure** — do not count it as HPA-620 evidence.

Only after classification should implementation add the smallest focused reproducer and minimal fix.

## Concurrency hypothesis

Swift Testing supports in-process parallel test execution, so shared-state interference remains a legitimate hypothesis. It is not established by the current evidence.

The named accessibility suites are all `@MainActor`. Also, `.serialized` on a suite serializes the tests contained by that suite; applying it independently to several top-level suites does not serialize those suites relative to unrelated peer suites. Therefore “add `.serialized` to each accessibility suite and see whether the flake disappears” is not a decisive cross-suite experiment.

If a captured failure points toward interference, first identify the competing tests/state. Then use the smallest valid discriminator whose serialization boundary actually contains the implicated tests. Do not commit serialization before that experiment distinguishes the cause.

## Verification model

### Slice A

Run the affected accessibility suites once, then the CI-equivalent `PyxisTests` suite once. This proves the diagnostic refactor and independent label lookup preserve current behavior.

### Reproduction

Run up to five CI-equivalent `PyxisTests` attempts, stopping at the first failure and preserving its log/result bundle. Five green runs mean “not reproduced in this diagnostic window,” not “fixed.”

### Post-fix

After a concrete root cause has a focused RED -> GREEN reproducer, run the affected test repeatedly and then three consecutive CI-equivalent `PyxisTests` runs. Repeated full-suite runs belong after the cause/fix, not before it.

## Expected initial implementation footprint

Slice A is test-only and may touch existing helper consumers:

- `PyxisTests/FeedbackSettingsAccessibilityAdapterTests.swift`
- `PyxisTests/FeedbackSettingsControllerTests.swift`
- `PyxisTests/BattleSceneTests.swift`
- `PyxisTests/BuildingViewSceneTests.swift`
- `PyxisTests/CountryMapSceneTests.swift`
- `PyxisTests/GameViewControllerTests.swift`

No new file, production file, project file, workflow, dependency, or coverage-policy change is planned.

Slice B's final footprint is intentionally unknown until a real failure is classified. Production changes require reproducible player-facing evidence.

## Acceptance

Slice A is ready to merge when:

- the shared reader reports nil and foreign-object failures at the calling test instead of silently returning `[]`;
- direct Building View / Country Map raw collection reads use that shared strict reader;
- existing helper users preserve their semantic assertions;
- GameViewController identifies Sound Effects by label;
- the affected suites and one CI-equivalent `PyxisTests` run pass;
- SwiftLint and `git diff --check` pass;
- no production/CI/coverage file changed.

HPA-620 itself is complete only when:

- one real intermittent accessibility failure is captured or historical equivalent evidence is recovered;
- the root cause is documented from that evidence;
- a focused reproducer fails before and passes after the minimal fix;
- three consecutive CI-equivalent `PyxisTests` runs pass after the fix without retries/sleeps;
- any production scope expansion is justified by a reproducible runtime defect.

If no failure can be reproduced after the bounded diagnostic attempts, keep HPA-620 open with the evidence recorded rather than marking it fixed.
