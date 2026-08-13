# HPA-618 — DEBUG-only Country 1 City Jump Design

## Status

Approved planning design for HPA-618: **Dev tool: DEBUG-only jump-to-city overlay (Country 1)**.

The Linear ticket already fixes the product direction: this is a developer convenience tool, not player-facing validation and not a replacement for the canceled HPA-567 casual playtest. This spec tightens that agreed direction against current `main` and deliberately removes unnecessary abstraction.

## Why this is the next actionable slice

The player-facing HPA-360 slices are already implemented, including Country 1 city identity, Recommended Camp guidance, and the City 5/10/15 milestone treatment. The remaining work now benefits more from cheap repeatable late-city smoke testing than from another gameplay mechanic.

HPA-618 is unblocked and gives that leverage without changing the shipping game. It makes City 5/10/15 presentation, late-city battlefield layout, conquest reports, soldier feedback, and Country 1 completion cheap to revisit while keeping evidence-gated mechanics deferred.

## Goal

In a DEBUG build, five taps in an invisible top-right hotspot on the `SKView` open a city picker for Country 1. Selecting City 1 through City 15 replaces the current campaign save with a generous fresh battle state for that city and immediately presents `BattleScene`.

The tool must compile out of Release builds.

## Non-goals

HPA-618 does not add:

- a player-facing cheat/debug menu;
- a shipping Settings control;
- a reset/checkpoint/export/restore API;
- campaign validation evidence or analytics;
- a generic developer-tools framework;
- a reusable picker/overlay builder type;
- launch arguments, deep links, URL routing, or automation harnesses;
- changes to combat, economy, persistence semantics, routing semantics, feedback policy, milestone behavior, or Country 1 authored content;
- support for a future Country 2.

The picker explicitly overwrites the current save. Testers who need a previous checkpoint can manage their own development copy outside this feature.

## Existing code to reuse

The repository already owns every shipping boundary this tool needs:

- `KingdomGameState` normalizes active-campaign state from `completedCityCount` and `stageStatus`. In `.battleActive`, it derives the current city and level from `completedCityCount + 1` and initializes current city power from `cityMaxPower(for:)`.
- `KingdomGameState.firstCountryCityCount` is the authoritative current Country 1 range and is 15 today.
- `KingdomGameStore.save(_:)` already replaces the persisted `pyxis.kingdomGameState` value.
- `GameViewController.presentBattleScene(in:)` is the existing Battle router and already reuses the shared feedback runtime/accessibility adapter.
- `GameViewController.viewDidLoad()` owns `SKView` setup and is the smallest place to install one DEBUG-only UIKit gesture.
- `GameViewController.swift` already contains a `#if DEBUG` extension for testing-only controller accessors.
- The project uses `PBXFileSystemSynchronizedRootGroup`; a new Swift file is discovered automatically and must not be registered manually in `project.pbxproj`.

## Approaches considered

### 1. Pure state factory + controller-local DEBUG wiring — selected

Add one pure `DevJumpState` factory and keep the one-consumer UIKit gesture/picker logic inside `GameViewController.swift` under `#if DEBUG`.

This is the smallest design that keeps state construction unit-testable while letting the controller reuse its private Battle router directly.

### 2. Separate `DevJumpOverlayBuilder` type — rejected

A standalone builder would only wrap one `UIAlertController` for one controller. It would add another type/file without a second consumer or independent policy. The alert can be constructed by a private DEBUG helper in `GameViewController` and inspected through narrow DEBUG test accessors.

### 3. SpriteKit dev scene, launch arguments, or deep-link routing — rejected

These approaches add routing/configuration machinery for a tool whose only job is “pick one of 15 values, replace the save, show Battle.” They also create more seams that would need maintenance while providing no current user value.

## Architecture

The complete runtime shape is:

`five-tap hotspot -> GameViewController DEBUG picker -> DevJumpState.make(city:) -> KingdomGameStore.save -> existing presentBattleScene(in:)`

There are only two runtime ownership units.

### 1. `DevJumpState`

Create `Pyxis/DevJumpState.swift`, with the entire file wrapped in `#if DEBUG ... #endif`.

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

The factory is intentionally Country 1-only. It does **not** accept a `country` argument: HPA-618 has one caller and one supported country, so a generic parameter would be speculative API surface.

The picker is the range boundary and passes only `1...KingdomGameState.firstCountryCityCount`. The factory therefore does not add a second clamp or validator.

For a valid selected city `N`, the existing `KingdomGameState` initializer must remain authoritative for normalization:

- `countryNumber == 1`;
- `completedCityCount == N - 1`;
- `cityNumberInCountry == N`;
- `cityLevel == N`;
- `stageStatus == .battleActive`;
- `cityRemainingPower == KingdomGameState.cityMaxPower(for: N)`;
- `gold == 1_000_000`;
- `normalSoldierUpgradeLevel == 15`;
- `cityBattleStates` starts empty;
- no active siege session, pending result, or background timestamp is carried from the overwritten save.

The generous constants live on the factory so they are obvious and cheap to tweak during development.

### 2. `GameViewController` DEBUG wiring

Keep all controller changes in `Pyxis/GameViewController.swift`.

Inside `viewDidLoad()`, after the `SKView` is available, install the debug gesture behind an inline compile gate:

```swift
#if DEBUG
installDevJumpGesture(on: view)
#endif
```

The helper methods themselves live in the file's existing `#if DEBUG` extension.

#### Trigger

- `UITapGestureRecognizer`
- `numberOfTapsRequired = 5`
- attached to the `SKView`
- `cancelsTouchesInView = false`, because this is a developer convenience and should not introduce a new SpriteKit input policy
- hotspot: fixed 64×64 pt square at the top-right of the current `SKView.bounds`
- a recognized five-tap whose final location is outside that hotspot is ignored

Do not add an invisible `UIView`. A separate view would become another input surface layered over SpriteKit for no benefit.

The gesture handler should stay thin: resolve the `SKView`, read the gesture location, then delegate to a private method that tests the hotspot and opens the picker. The delegated method can be exercised directly in unit tests without trying to synthesize UIGestureRecognizer state.

#### Picker

Build one `UIAlertController(preferredStyle: .actionSheet)` with:

- title: `[DEBUG] Jump to Country 1 City`;
- message: `Replaces current save.`;
- one default action for each `City 1` through `City 15`, using `1...KingdomGameState.firstCountryCityCount`;
- one Cancel action.

Do not present another picker when `GameViewController.presentedViewController` is already non-nil.

Because `.actionSheet` presentation requires a popover anchor on iPad, set the alert's `popoverPresentationController?.sourceView` to the `SKView` and `sourceRect` to the same top-right hotspot before presentation. This is required runtime correctness for the repository's supported iPad orientation, not extra framework work.

Each city action delegates to one private method:

```swift
private func performDevJump(to city: Int, in view: SKView) {
    store.save(DevJumpState.make(city: city))
    presentBattleScene(in: view)
}
```

No second router, scene factory, or persistence path is added.

## Save and scene semantics

A jump is intentionally destructive to the current development save:

1. the selected city is materialized as a fresh active battle state;
2. `KingdomGameStore.save(_:)` replaces the persisted state;
3. `presentBattleScene(in:)` creates the normal Battle scene using that saved state and existing shared runtime;
4. later gameplay proceeds normally from that debug-created state.

There is no “return to prior save” stack. Adding one would turn this simple smoke tool into checkpoint management.

City 15 is still an active battle when selected. `countryComplete` remains a normal result of conquering City 15; it is not directly selectable.

## Release isolation

Every new runtime symbol/string is inside `#if DEBUG`:

- the entire `DevJumpState.swift` body;
- the `viewDidLoad()` installer call;
- gesture/picker/jump helpers and DEBUG test accessors in `GameViewController.swift`.

There is no Release branch, no runtime `assert`, no hidden shipping gesture, and no player preference controlling the feature.

A Release build must succeed with these symbols compiled out. Final verification should also scan the built Release app binary for the unique picker title `[DEBUG] Jump to Country 1 City` and find no match.

## Testing strategy

### Pure factory — automated

`PyxisTests/DevJumpStateTests.swift` iterates every Country 1 city and asserts the normalized fresh battle contract listed above. This locks the important coupling to `KingdomGameState` without reproducing its normalization logic.

### Controller DEBUG glue — automated where cheap

Extend `PyxisTests/GameViewControllerTests.swift` to cover:

- a five-tap recognizer is installed on the `SKView` and does not cancel SpriteKit touches;
- the top-right hotspot is exactly the expected 64×64 frame for a normal test view;
- an outside hotspot point does not present the picker;
- an inside hotspot point presents the action sheet once;
- the action sheet contains exactly City 1...City 15 plus Cancel and the overwrite warning;
- direct selection delegation overwrites an existing store and presents a `BattleScene` for the selected city.

Keep the actual `@objc` recognizer adapter tiny. Tests exercise the delegated location method rather than inventing gesture-recognizer test infrastructure.

The iPad popover source configuration remains visible in the picker construction path and gets a manual iPad smoke because CI runs on iPhone Simulator.

### Manual smoke

In a DEBUG simulator build:

1. From Battle, Map, or Building View, five-tap the top-right hotspot.
2. Verify the picker appears and clearly states that it replaces the current save.
3. Jump to representative Cities 1, 5, 10, and 15; each must land directly in Battle with the correct city identity and generous resources.
4. On iPad portrait, open the picker and choose City 15; the action sheet must present without a popover crash.
5. Conquer City 15 and verify the existing Country 1 completion flow still occurs normally.

The pure factory test covers all 15 values; the manual pass does not need to click all 15 actions.

## Acceptance

HPA-618 is complete when:

- DEBUG five-tap in the top-right hotspot opens a City 1...15 picker;
- the picker states that the current save is replaced;
- choosing any listed city saves a fresh active Country 1 state and immediately presents Battle;
- the state uses `gold = 1_000_000`, `normalSoldierUpgradeLevel = 15`, and empty city building state;
- City 15 remains an active battle, not a pre-completed country;
- iPad action-sheet presentation is correctly popover-anchored;
- automated factory/controller tests pass without introducing a dev-tools framework;
- full unit/UI tests and SwiftLint pass with parallel testing disabled;
- a Release build succeeds and its app binary contains no `[DEBUG] Jump to Country 1 City` string;
- no shipping gameplay, persistence semantics, feedback policy, settings, or project-file registration changes are introduced.
