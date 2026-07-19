# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Pyxis is an iOS idle kingdom game (SpriteKit + UIKit, Swift 5). Soldiers (manually spawned, or auto-spawned by city buildings) attack a city; conquest grants gold; gold upgrades soldiers and constructs/upgrades buildings; backgrounded time converts into accumulated building production (capped at 8 hours). Five soldier types — `infantry` (from Barracks), `archer` (from Archery Range), `cavalry` (from Stable), `mage` (from Mage Tower), and `siege` (from Siege Workshop).

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
xcodebuild ... test -only-testing:PyxisTests/KingdomGameStateTests/formulasMatchMVPBalanceCurve
```

Lint (config in `.swiftlint.yml`; `file_length`, `function_body_length`, `identifier_name`, `type_body_length` are disabled):
```bash
swiftlint lint
```

CI (`.github/workflows/ci.yml`, runs on push to `main` + PRs) has three jobs: **Build & Lint** (SwiftLint + build), **Unit Test & Codecov** (`-only-testing:PyxisTests` with coverage uploaded via `tools/xccov-to-lcov.rb`), and **UI Test** (`-only-testing:PyxisUITests`). It targets the iPhone 17 simulator and `latest-stable` Xcode — use whatever simulator is available locally.

### Running Tests (preferred: XcodeBuildMCP, fallback: xcodebuild)

**Always disable parallel testing** — this machine does not have enough resources for concurrent simulator clones, and parallel `xcodebuild test` leaves orphaned clones in `~/Library/Developer/XCTestDevices` that accumulate to tens of GB.

**Preferred — via XcodeBuildMCP** (configured in Devin CLI):
1. Call `session_show_defaults` first to verify the active project/scheme/simulator.
2. If defaults are unset, call `session_set_defaults` with `projectPath`, `scheme`, and `simulatorName`.
3. Run `test_sim` with `extraArgs: ["-parallel-testing-enabled", "NO"]` to disable cloning.

**Fallback — direct xcodebuild** (when XcodeBuildMCP is unavailable):
```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO
```

## Project Structure Notes

- The Xcode project uses `PBXFileSystemSynchronizedRootGroup`, so new files dropped into `Pyxis/`, `PyxisTests/`, or `PyxisUITests/` are picked up automatically — do **not** edit `project.pbxproj` to register them.
- Unit tests under `PyxisTests/` use **Swift Testing** (`import Testing`, `@Test`, `#expect`), not XCTest. UI tests under `PyxisUITests/` still use XCTest.

## Architecture

Game logic is split into pure value-type models (no SpriteKit/UIKit) and SpriteKit scenes that render and drive them. Decoupling exists so rules can be unit-tested with Swift Testing.

1. **`KingdomGameState`** (`Pyxis/KingdomGameState.swift`) — campaign/economy model. Owns balance formulas (`cityMaxPower`, `goldReward`, `normalSoldierAttackPower`, `normalSoldierUpgradeCost`, `buildingBuildCost`, `buildingUpgradeCost`, `activeSpawnInterval`, `soldierAttackPower` — exponential curves) and mutating ops: `applyLiveCombatDamage(_:)`, `upgradeNormalSoldier()`, `startCityFromMap(_:)`, the building ops (`buildBuilding`, `upgradeBuilding`, `resolveActiveBuildingSpawns`), and the `enterBackground(at:)` / `returnFromBackground(at:)` pair. It also owns the per-city `cityBattleStates: [String: CityBattleState]` map (see #2) and assigns each city a `CityDefenseTrait` (`Pyxis/CityDefenseTrait.swift`) which adjusts soldier damage via `traitAdjustedSoldierAttackPower` — advantaged types deal 1.25×, disadvantaged deal 0.80×. A `stageStatus` enum (`battleActive` / `cityConqueredPendingMap` / `countryComplete`) gates which mutations are allowed and which scene the app presents. Key constants: `firstCountryCityCount = 15`, `manualSoldierCap = 10`, `maxIdleCatchUpSeconds = 8h`, `idleBuildingProductionScale = 10` (idle production runs at 1/10 active rate). The init/decoder clamps invalid persisted values (negative gold, out-of-range city/country, mismatched status, malformed/non-canonical `cityBattleStates` keys) back to a consistent state instead of failing.

2. **City-building model** (`Pyxis/CityBuildingState.swift` + `Pyxis/SoldierType.swift`) — pure value types, no SpriteKit/UIKit. `CityBattleState` is a 25-slot building grid (`slotRange = 1...25`, `maxBuildingsPerType = 5`) holding `CityBuilding`s (`type`, `level`, `spawnTimerElapsed`). `CityKey(countryNumber:cityNumber:)` ↔ its `storageKey` string (`"country-city"`) namespaces one grid per city in `KingdomGameState.cityBattleStates`. `BuildingType` (`barracks` → `infantry`, `archeryRange` → `archer`, `stable` → `cavalry`, `mageTower` → `mage`, `siegeWorkshop` → `siege`) maps to `SoldierType`. Buildings spawn soldiers over time; resolution returns `[BuildingSpawn]`. `normalize()` enforces the slot range and per-type cap on every mutation/decode.

3. **`BattleCombatState`** (`Pyxis/BattleCombatState.swift`) — pure live-combat simulator. Owns soldier roster (each `Soldier` has a `SoldierType` and is spawned `manual` or from a `building`) + tower cooldown. Each `tick(deltaTime:cityRemainingHP:)` advances soldier positions, resolves tower shots, applies soldier attacks against the city, prunes dead soldiers, and returns a `TickResult` (city damage, conquest flag, attack IDs, tower shots, damaged/killed soldier IDs). Soldier HP and range vary by type. Each soldier is randomly assigned one of three `BattleLane`s (`left`/`center`/`right`) at spawn via a seedable internal PRNG (`SplitMix64`); the tower targets a random occupied lane per shot and scales its damage by `Configuration.laneDamageMultipliers`. `LaneDefenseProfile` (`Pyxis/LaneDefenseProfile.swift`) deterministically assigns each city one fortified (1.25× tower damage), one exposed (0.80×), and one standard lane from the city number; `KingdomGameState.currentCityLaneDefenseProfile` exposes it and `BattleScene` feeds it into the combat configuration. `BattleScene` drives this; `KingdomGameState` consumes only its `cityDamage` via `applyLiveCombatDamage(_:)`.

4. **`KingdomGameStore`** (`Pyxis/KingdomGameStore.swift`) — JSON-codes the state into `UserDefaults` under key `pyxis.kingdomGameState`. Decode failure silently returns a fresh state. Tests inject a custom `UserDefaults` suite + key for isolation.

5. **Scenes** — code-owned SpriteKit scenes (the bundled `GameScene.sks` / `Actions.sks` are unused). Each holds its own copy of `KingdomGameState`, persists after every mutation, and rebuilds layout on `didChangeSize`. Shared UI helpers live in `GameUIComponents.swift` (`PanelNode`, `ProgressBarNode`) and `GameUITheme.swift` (fonts, colors, Z-order, safe-area insets).
   - `BattleScene` (`Pyxis/BattleScene.swift`) — owns a `BattleCombatState`, spawns/upgrades soldiers, runs the per-frame tick (which also calls `resolveActiveBuildingSpawns` to inject building-produced soldiers), mirrors `TickResult` into UI (HP bar, soldier nodes, conquest popup) on a vertical full-screen battlefield (enemy city top, player castle bottom, three marching lanes), and routes to the map or the building view via `BattleSceneRouting`.
   - `CountryMapScene` (`Pyxis/CountryMapScene.swift`) — renders the 15-city route, lets the player enter the unlocked city via `startCityFromMap(_:)`, and routes back to battle via `CountryMapSceneRouting`.
   - `BuildingViewScene` (`Pyxis/BuildingViewScene.swift`) — renders the 25-slot grid for the current city, builds/upgrades buildings via `buildBuilding`/`upgradeBuilding` (showing affordability/cap feedback), and routes back to battle via `BuildingViewSceneRouting`. A build/upgrade settles pending building production first, which can itself conquer the city mid-action.

6. **`GameViewController`** (`Pyxis/GameViewController.swift`) — presents the initial scene based on persisted `stageStatus` (`battleActive` → `BattleScene`, otherwise `CountryMapScene`) and acts as the router for all three scenes' protocols (`BattleSceneRouting`, `CountryMapSceneRouting`, `BuildingViewSceneRouting`).

### App lifecycle → idle catch-up

`SceneDelegate` translates UIScene lifecycle into two custom notifications declared in `GameLifecycleNotifications.swift`:

- `.pyxisSceneDidEnterBackground` → `enterBackground(at:)` (→ `markCurrentCityBuildingProgressInactive`) records `lastBackgroundedAt` and freezes the per-city building progress timestamp, then saves.
- `.pyxisSceneWillEnterForeground` → `returnFromBackground(at:)` (→ `resolveCurrentCityBuildingIdleProgress`), which (only when `stageStatus == .battleActive`) resolves up to 8 hours of building-produced soldier spawns at `1/idleBuildingProductionScale` of the active rate, applies their `traitAdjustedSoldierAttackPower` (defense-trait-adjusted via `CityDefenseTrait`) as city damage, conquers at most one city, awards gold, and clears `lastBackgroundedAt` so it can't be applied twice. Returns an `IdleProgressResult`. Idle progress is now **building-driven** — a city with no buildings makes no offline progress.

Both `BattleScene` and `BuildingViewScene` observe these notifications (the building view also re-arms idle tracking and resolves time spent in the grid before routing back). Scenes guard observer registration with `isObservingLifecycle` because `didMove(to:)` can run more than once.

## Conventions

- Game rules belong in the pure models (`KingdomGameState`, `BattleCombatState`, `CityBuildingState`/`SoldierType`) — none import SpriteKit/UIKit. Keep these models framework-free so they stay unit-testable.
- New gameplay features follow a TDD flow: add a Swift Testing test, watch it fail, implement, watch it pass.
- Implementation plans live in `docs/plans/` and (newer) `docs/superpowers/plans/`; design specs in `docs/superpowers/specs/`. Each feature typically has a paired spec + plan dated by filename.
- `AGENTS.md` is a symlink to `CLAUDE.md` — edit `CLAUDE.md` only.
- Soldier animation frames are generated at **128×128 px** (`tools/slice_soldier_animation_strips.py --frame-size 128`, the script default). Soldier bodies render at ~54-70 pt on the battlefield (38-50 pt on screens shorter than 500pt; see `BattleScene.soldierTargetHeight`), and the body occupies ~58-82% of the 128px canvas (`SoldierAnimationGeometry.bodyRegion.height`: cavalry/siege 0.578, infantry 0.734, mage 0.664, archer 0.820), so the body is sourced from only ~74-105 px of texture. That is under-sampled on 2-3× devices — accepted as a memory tradeoff, since soldiers are small fast-moving actors where the softness is less perceptible and bumping to 256px would roughly quadruple GPU texture memory across all five types' walk/attack/hit sets. 512px would waste ~150 MB of GPU memory once all five soldier types' sets are cached (5 types × 3 actions × 10 frames × 512² × 4 bytes); the current 128px frames occupy ~9.4 MB (5 × 3 × 10 × 128² × 4 bytes). When adding new sprite-animated actors, pick the smallest square frame size that still looks crisp at their on-screen render height.
- Soldier animation frames must be re-authored and installed as a **complete validated trio**: every soldier type ships all 30 frames (10 walk + 10 attack + 10 hit) named `<type>-<action>-<NN>` (zero-padded 01–10), validated all-or-nothing by `tools/slice_soldier_animation_strips.py`'s storyboard check. Do **not** hand-edit the asset catalog to add, remove, or rename individual frames — `firstAvailableSoldierAnimationFrameName` requires all 30 frames before setting `isAnimatedCanvas = true`, so a partial trio (any missing frame) falls through to the static-fallback sprite path entirely; the soldier renders as a static image with no walk/attack/hit animation. Re-author the full 5-by-2 storyboard for that type and re-run the slicer so the trio is atomic. `PyxisTests.allSoldierAnimationFramesAreInstalled` guards this synchronously at test time.
- Attack animations last longer than the per-type damage interval for 4 of 5 soldier types (infantry/archer/cavalry/mage; siege is unaffected). `BattleScene.playSoldierAnimation` suppresses attack triggers while an attack animation is already in flight so the cycle isn't restarted mid-pose (which would pop back to frame 1 and never reach the strike frames). The accepted side-effect is that those four types visually attack at ~50% of their damage cadence (e.g. infantry attacks every 1.0s but the attack pose cycles every 2.0s). This is a documented visual-cadence tradeoff, not a bug — see the suppression comment in `BattleScene.playSoldierAnimation` for the engineering rationale.
- Cavalry is the only soldier type whose hit-reaction duration (0.9s) exceeds its attack interval (~0.87s), so the next attack tick would always land mid-hit and cut off the authored hit reaction. `BattleScene.playSoldierAnimation` suppresses attack triggers while a hit reaction is still playing **only for types where hit duration > attack interval** (currently cavalry). The hit-reaction countdown is tracked in `BattleScene.soldierHitAnimationRemaining` (a per-soldier `[SoldierID: TimeInterval]` decremented per combat tick) rather than checking `sprite.action(forKey: .hit)` because the test suite drives combat via `advanceCombatForTesting` without a SpriteKit render loop — installed SKActions never advance in tests, so an action-key check would suppress attacks forever after the first hit. For other types (infantry/archer/mage/siege), hit < attack interval so the hit usually finishes before the next attack; suppressing attacks for those types would cause a severe visual regression (the tower re-arms the 0.9s hit timer every 1.25s, so suppression would be active ~72% of the time). `BattleCombatState.attackInterval(for:)` is exposed for this guard check.
