# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Pyxis is an iOS idle kingdom game (SpriteKit + UIKit, Swift 5). Spawned soldiers attack a city; conquest grants gold; gold upgrades soldier attack power; backgrounded time converts into automatic attacks (capped at 8 hours).

## Build & Test

Run unit + UI tests:
```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' test
```

If that simulator destination isn't available locally, list available ones first:
```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -showdestinations
```

Build only (no tests):
```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Run a single Swift Testing test by name with the `-only-testing` flag, e.g.:
```bash
xcodebuild ... test -only-testing:PyxisTests/KingdomGameStateTests/idleCatchUpIsCappedAtEightHours
```

## Project Structure Notes

- The Xcode project uses `PBXFileSystemSynchronizedRootGroup`, so new files dropped into `Pyxis/`, `PyxisTests/`, or `PyxisUITests/` are picked up automatically — do **not** edit `project.pbxproj` to register them.
- Unit tests under `PyxisTests/` use **Swift Testing** (`import Testing`, `@Test`, `#expect`), not XCTest. UI tests under `PyxisUITests/` still use XCTest.

## Architecture

Three layers, intentionally kept decoupled so game rules can be unit-tested without SpriteKit:

1. **`KingdomGameState`** (`Pyxis/KingdomGameState.swift`) — pure value type. Owns all balance formulas (`cityMaxPower`, `goldReward`, `normalSoldierAttackPower`, `normalSoldierUpgradeCost` — exponential curves) and the three mutating operations: `spawnSoldierAttack()`, `upgradeNormalSoldier()`, and the `enterBackground(at:)` / `returnFromBackground(at:)` pair. Excess damage carries between cities during idle catch-up but **not** during a foreground spawn. The decoder clamps invalid persisted values (negative gold, zero levels) back to safe defaults rather than failing.

2. **`KingdomGameStore`** (`Pyxis/KingdomGameStore.swift`) — JSON-codes the state into `UserDefaults` under key `pyxis.kingdomGameState`. Decode failure silently returns a fresh state. Tests inject a custom `UserDefaults` suite + key for isolation.

3. **`GameScene`** (`Pyxis/GameScene.swift`) — code-owned SpriteKit scene (the bundled `GameScene.sks` is unused; `GameViewController` constructs `GameScene(size:)` directly). Builds labels/buttons/HP bar in code and re-runs `layoutInterface()` on every `didChangeSize` for orientation changes. Holds its own copy of `KingdomGameState` and persists after every mutation via the injected store.

### App lifecycle → idle catch-up

`SceneDelegate` translates UIScene lifecycle into two custom notifications declared in `GameLifecycleNotifications.swift`:

- `.pyxisSceneDidEnterBackground` → `GameScene` calls `state.enterBackground(at: Date())` and saves.
- `.pyxisSceneWillEnterForeground` → `GameScene` calls `state.returnFromBackground(at: Date())`, which applies up to 8 hours of accumulated damage, conquers cities, awards gold, and clears the timestamp so it can't be applied twice.

`GameScene` guards observer registration with `isObservingLifecycle` because `didMove(to:)` can run more than once.

## Conventions

- Game rules belong in `KingdomGameState` (no `SpriteKit` / `UIKit` imports there). Keep the model SpriteKit-free so it stays unit-testable.
- New gameplay features should follow the same TDD flow used in `docs/plans/2026-05-05-idle-kingdom-mvp.md`: add a Swift Testing test, watch it fail, implement, watch it pass.
- Implementation plans live in `docs/plans/`; design specs in `docs/superpowers/specs/`.
