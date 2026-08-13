# HPA-618 — DEBUG-only Country 1 City Jump Design

## Status

Approved planning design for HPA-618: **Dev tool: DEBUG-only jump-to-city overlay (Country 1)**.

HPA-618 is a developer convenience tool. It is not player-facing validation, does not revive the canceled HPA-567 casual run, and must not change shipping gameplay.

## Why this is the next actionable slice

Country 1 identity, Recommended Camp guidance, conquest reporting, feedback, and the City 5/10/15 milestone treatment are already implemented. The useful next step is a cheap way to revisit late-city presentation without replaying the campaign.

The tool should stay smaller than the features it helps inspect. It therefore reuses the existing state normalization, persistence, and Battle router instead of introducing a developer-tools subsystem.

## Goal

In a DEBUG build, five taps inside a 64×64 pt top-right hotspot on the app's `SKView` open a Country 1 city picker. Selecting City 1 through City 15 replaces the current development save with a generous fresh active-battle state and immediately presents the normal `BattleScene`.

The trigger must not add observable tap latency to normal DEBUG gameplay, and the entire tool must compile out of Release builds.

## Non-goals

HPA-618 does not add:

- a player-facing cheat/debug menu;
- a shipping Settings control;
- a reset/checkpoint/export/restore API;
- HPA-567 evidence or analytics;
- a generic developer-tools framework;
- a reusable picker/overlay builder;
- launch arguments, deep links, URL routing, or an automation harness;
- an alternate scene router or persistence path;
- changes to combat, economy, feedback policy, milestone behavior, authored content, or persistence semantics;
- support for a future Country 2.

The picker intentionally overwrites the current development save.

## Existing code to reuse

The repository already owns the shipping boundaries this tool needs:

- `KingdomGameState` normalizes `.battleActive` progression from `completedCityCount`: current city and level become `completedCityCount + 1`, and current city power is initialized from `cityMaxPower(for:)`.
- `KingdomGameState.firstCountryCityCount` is the authoritative Country 1 range.
- `KingdomGameStore.save(_:)` replaces the persisted game state.
- `GameViewController.presentBattleScene(in:)` is the existing Battle router and reuses the shared feedback runtime/accessibility adapter.
- `GameViewController.viewDidLoad()` owns `SKView` setup and is the smallest place to install a controller-owned DEBUG gesture that survives SpriteKit scene replacement.
- The Xcode project uses synchronized root groups, so no `project.pbxproj` registration is required for a new Swift file.

Do not reuse `startCityFromMap(_:)`: it is the shipping sequential-entry API, not a teleport API.

## Approaches considered

### 1. Pure state factory + controller-local DEBUG wiring — selected

Add one pure `DevJumpState` factory and keep the one-consumer UIKit gesture/action-sheet logic inside `GameViewController.swift` under `#if DEBUG`.

This keeps state materialization independently testable while reusing the controller's private Battle router directly.

### 2. Separate `DevJumpOverlayBuilder` — rejected

It would wrap one `UIAlertController` for one caller and add another type/file with no independent policy or second consumer.

### 3. SpriteKit dev scene, launch arguments, or deep-link routing — rejected

These add routing/configuration machinery for a tool whose complete job is: pick one of 15 cities, replace the save, show Battle.

## Architecture

The complete runtime flow is:

`five-tap hotspot -> GameViewController DEBUG picker -> DevJumpState.make(city:) -> KingdomGameStore.save -> presentBattleScene(in:)`

There are exactly two runtime ownership units.

## 1. `DevJumpState`

Create `Pyxis/DevJumpState.swift` with the entire body inside `#if DEBUG ... #endif`.

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

### Country 1 boundary

The factory intentionally has no `country` parameter and no clamp.

The picker supplies only `1...KingdomGameState.firstCountryCityCount`. The factory also fails loudly on programmer misuse so a future bad caller cannot silently normalize City 0 into City 1 or City 16 into country completion.

The `precondition` is not a second gameplay validator. It is a DEBUG-only assertion of the factory's documented domain.

### State normalization

For a valid selected city `N`, `KingdomGameState.init` remains authoritative:

- `countryNumber == 1`;
- `completedCityCount == N - 1`;
- `cityNumberInCountry == N`;
- `cityLevel == N`;
- `stageStatus == .battleActive`;
- `cityRemainingPower == KingdomGameState.cityMaxPower(for: N)`;
- `gold == 1_000_000`;
- `normalSoldierUpgradeLevel == 15`;
- `cityBattleStates` starts empty;
- no active siege session, pending battle result, or background timestamp is carried over.

Do not eagerly create an `ActiveSiegeSession`; the normal model creates one when combat/idle event recording first needs it.

## 2. `GameViewController` DEBUG wiring

Keep all controller changes in `Pyxis/GameViewController.swift`.

Inside `viewDidLoad()`, after obtaining the `SKView`, install the gesture under an inline compile gate:

```swift
#if DEBUG
installDevJumpGesture(on: view)
#endif
```

The DEBUG helper methods are internal rather than private. They already compile out of Release, so adding one-to-one `...ForTesting` wrappers would protect no production boundary and only increase code/coverage surface.

### Trigger

Install one `UITapGestureRecognizer` with:

- `numberOfTapsRequired = 5`;
- `cancelsTouchesInView = false`;
- `delaysTouchesEnded = false`;
- a 64×64 pt top-right hotspot derived from current `SKView.bounds`;
- no invisible `UIView`;
- no `UIGestureRecognizerDelegate` hotspot policy.

`delaysTouchesEnded = false` is required. Pyxis scenes process taps in `touchesEnded`; leaving UIKit's default delayed-ended behavior enabled would make the DEBUG build wait on five-tap recognition before delivering ordinary scene taps, distorting the gameplay/feedback timing this tool exists to inspect.

The top-right hotspot is intentionally away from the existing left-side Settings gear. Because `cancelsTouchesInView` and `delaysTouchesEnded` are both false, ordinary scene input continues normally while the recognizer observes the touch stream.

### Gesture adapter

Keep the Objective-C selector thin:

```swift
@objc func handleDevJumpGesture(_ gesture: UITapGestureRecognizer) {
    guard let view = gesture.view as? SKView else { return }
    handleDevJumpTap(at: gesture.location(in: view), in: view)
}
```

Do not add a recognizer abstraction merely for testing. The focused controller test may exercise this adapter using a 64×64 `SKView`, where the full bounds are the trigger frame, and must assert that the picker is actually presented rather than merely executing lines for coverage.

### Hotspot and re-entrancy

`handleDevJumpTap(at:in:)`:

1. ignores points outside the top-right hotspot;
2. ignores the trigger when `presentedViewController != nil`;
3. otherwise presents the city action sheet.

The UIKit re-entrancy guard deliberately does not inspect the SpriteKit feedback-settings modal. That modal is not a UIKit presentation, and coupling the app controller to scene-local Settings state is unnecessary for this dev tool. Manual smoke covers this interaction explicitly.

### Picker

Build one `UIAlertController(preferredStyle: .actionSheet)` with:

- title: `[DEBUG] Jump to Country 1 City`;
- message: `Replaces current save.`;
- one default action for each `City 1` through `City 15`, derived from `1...KingdomGameState.firstCountryCityCount`;
- one Cancel action.

Each city action contains one executable forwarding line into the tested jump method:

```swift
[weak self] _ in self?.performDevJump(to: city, in: view)
```

The short-lived alert owns the captured `SKView`; the controller is weakly captured. Do not add a multi-line optional-unwrapping guard or a forced unwrap just to manipulate line coverage.

For iPad correctness, configure:

```swift
alert.popoverPresentationController?.sourceView = view
alert.popoverPresentationController?.sourceRect = devJumpTriggerFrame(in: view)
```

### Save and landing

The selected action delegates to one method:

```swift
func performDevJump(to city: Int, in view: SKView) {
    store.save(DevJumpState.make(city: city))
    presentBattleScene(in: view)
}
```

No second router, scene factory, or persistence path is added.

City 15 is still an active battle when selected. `countryComplete` remains the normal result of conquering City 15.

## Release isolation

Every new runtime line, symbol, and string is inside `#if DEBUG`:

- the entire `DevJumpState.swift` body;
- the `viewDidLoad()` installer call;
- gesture/picker/jump helpers in `GameViewController.swift`.

There is no Release branch, runtime feature flag, hidden shipping gesture, or player preference controlling the feature.

Final verification must:

1. build Release successfully;
2. scan the built app binary for `[DEBUG] Jump to Country 1 City`;
3. fail if that unique marker exists.

Do not grep generic shipping strings such as `City 15`.

## Testing strategy

### Pure factory — automated

`PyxisTests/DevJumpStateTests.swift` iterates every valid Country 1 city and asserts the normalized fresh-battle contract. Every valid call also executes the DEBUG precondition.

No trap-testing helper is needed for invalid cities; the precondition is programmer-failure behavior, not a second public validation API.

### Controller DEBUG glue — automated where cheap

Extend `PyxisTests/GameViewControllerTests.swift` to cover:

- one five-tap recognizer is installed on the `SKView`;
- `cancelsTouchesInView == false`;
- `delaysTouchesEnded == false`;
- the normal-view hotspot is exactly 64×64 at top-right;
- the recognizer adapter genuinely reaches picker presentation on a 64×64 view;
- an outside point does not present the picker;
- an inside point presents exactly one action sheet;
- picker copy/actions are exactly Country 1 City 1...15 plus Cancel;
- direct jump execution overwrites an existing store and presents a `BattleScene` for the selected city.

Tests call the internal DEBUG helpers directly through `@testable import Pyxis`; do not add five one-to-one `...ForTesting` wrappers.

### Manual smoke

On DEBUG iPhone Simulator:

1. From Battle, five-tap top-right and verify the picker/overwrite warning.
2. Jump to Cities 1, 5, 10, and 15; each lands directly in Battle with correct identity/resources.
3. Navigate normally to Country Map, five-tap top-right, choose City 10, and verify Battle opens at City 10.
4. Navigate normally to Building View, five-tap top-right, choose City 10, and verify Battle opens at City 10.
5. Open the in-scene feedback Settings modal, five-tap top-right, and verify the picker can present without corrupting Settings interaction; Cancel returns to the still-open modal, while selecting a city replaces the scene normally.
6. Conquer City 15 and verify the existing Country 1 completion flow.

On DEBUG iPad portrait:

7. Five-tap the hotspot, verify the action sheet presents without a popover exception, choose City 15, and verify Battle opens.

The Map and Building View beats prove the controller-owned gesture survives SpriteKit scene replacement. The all-city factory test covers the 15 state values; the manual pass does not need to select every action.

## Risks and mitigations

- **DEBUG tap latency:** a five-tap recognizer would delay scene `touchesEnded` by default. Set and test `delaysTouchesEnded = false`.
- **iPad action-sheet validity:** `.actionSheet` requires a valid popover source. Anchor it to the `SKView` hotspot and smoke it on iPad portrait.
- **95% patch coverage:** keep adapters minimal, directly test real forwarding behavior, and avoid pass-through test wrappers. If implementation grows new executable adapter behavior, add focused coverage rather than weakening Codecov.

## Acceptance

HPA-618 is complete when:

- DEBUG five-tap top-right opens City 1...15 picker from Battle, Country Map, and Building View;
- ordinary DEBUG scene taps are not delayed by the recognizer;
- picker clearly states that it replaces the current save;
- any listed city saves a fresh active Country 1 state and immediately presents Battle;
- invalid direct factory use fails loudly rather than silently normalizing;
- preset is `gold = 1_000_000`, soldier upgrade level 15, empty city-building state;
- City 15 remains active Battle until conquered normally;
- iPad action sheet is popover-anchored;
- factory/controller tests, full unit/UI suite, and SwiftLint pass with parallel testing disabled;
- Codecov project and patch statuses remain at or above 95%; no gate weakening;
- Release build succeeds and the unique DEBUG picker marker is absent from the built app binary;
- no shipping gameplay/settings/routing/persistence behavior changes are introduced.