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

Game logic is split into pure value-type models (no SpriteKit/UIKit) and SpriteKit scenes that render and drive them. Decoupling exists so rules can be unit-tested with Swift Testing.

1. **`KingdomGameState`** (`Pyxis/KingdomGameState.swift`) — campaign/economy model. Owns balance formulas (`cityMaxPower`, `goldReward`, `normalSoldierAttackPower`, `normalSoldierUpgradeCost` — exponential curves) and mutating ops: `applyLiveCombatDamage(_:)`, `upgradeNormalSoldier()`, `startCityFromMap(_:)`, and the `enterBackground(at:)` / `returnFromBackground(at:)` pair. A `stageStatus` enum (`battleActive` / `cityConqueredPendingMap` / `countryComplete`) gates which mutations are allowed and which scene the app presents. The init/decoder clamps invalid persisted values (negative gold, out-of-range city/country, mismatched status) back to a consistent state instead of failing.

2. **`BattleCombatState`** (`Pyxis/BattleCombatState.swift`) — pure live-combat simulator. Owns soldier roster + tower cooldown. Each `tick(deltaTime:cityRemainingHP:)` advances soldier positions, resolves tower shots, applies soldier attacks against the city, prunes dead soldiers, and returns a `TickResult` (city damage, conquest flag, attack IDs, tower shots, damaged/killed soldier IDs). `BattleScene` drives this; `KingdomGameState` consumes only its `cityDamage` via `applyLiveCombatDamage(_:)`.

3. **`KingdomGameStore`** (`Pyxis/KingdomGameStore.swift`) — JSON-codes the state into `UserDefaults` under key `pyxis.kingdomGameState`. Decode failure silently returns a fresh state. Tests inject a custom `UserDefaults` suite + key for isolation.

4. **Scenes** — code-owned SpriteKit scenes (the bundled `GameScene.sks` / `Actions.sks` are unused). Each holds its own copy of `KingdomGameState`, persists after every mutation, and rebuilds layout on `didChangeSize`:
   - `BattleScene` (`Pyxis/BattleScene.swift`) — owns a `BattleCombatState`, spawns/upgrades soldiers, runs the per-frame tick, mirrors `TickResult` into UI (HP bar, soldier nodes, conquest popup), and routes to the map via `BattleSceneRouting`.
   - `CountryMapScene` (`Pyxis/CountryMapScene.swift`) — renders the 15-city route, lets the player enter the unlocked city via `startCityFromMap(_:)`, and routes back to battle via `CountryMapSceneRouting`.

5. **`GameViewController`** (`Pyxis/GameViewController.swift`) — presents the initial scene based on persisted `stageStatus` (`battleActive` → `BattleScene`, otherwise `CountryMapScene`) and acts as the router for both scenes' protocols.

### App lifecycle → idle catch-up

`SceneDelegate` translates UIScene lifecycle into two custom notifications declared in `GameLifecycleNotifications.swift`:

- `.pyxisSceneDidEnterBackground` → `BattleScene` calls `state.enterBackground(at: Date())` and saves.
- `.pyxisSceneWillEnterForeground` → `BattleScene` calls `state.returnFromBackground(at: Date())`, which (only when `stageStatus == .battleActive`) applies up to 8 hours of accumulated damage at `normalSoldierAttackPower` per second, conquers at most one city, awards gold, and clears the timestamp so it can't be applied twice.

Scenes guard observer registration with `isObservingLifecycle` because `didMove(to:)` can run more than once.

## Conventions

- Game rules belong in `KingdomGameState` or `BattleCombatState` — neither imports SpriteKit/UIKit. Keep these models framework-free so they stay unit-testable.
- New gameplay features follow the TDD flow used in `docs/plans/` (e.g. `2026-05-05-idle-kingdom-mvp.md`, `2026-05-08-basic-battle-animation.md`, `2026-05-14-live-tower-combat.md`): add a Swift Testing test, watch it fail, implement, watch it pass.
- Implementation plans live in `docs/plans/`; design specs in `docs/superpowers/specs/`.
- `AGENTS.md` is a symlink to `CLAUDE.md` — edit `CLAUDE.md` only.
