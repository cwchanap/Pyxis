# Living Kingdom Runtime Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate HPA-479's Living Kingdom assets into Battle and Country Map, and make offline-return presentation truthful, without changing Pyxis combat/economy/save ownership.

**Architecture:** Author each city's visual family once in `Country1CityCatalog`, then use one pure `LivingKingdomPresentation` projection for HP stage, asset naming, FX metadata/selection, and completed-map decoration. `BattleScene`, `CountryMapScene`, and `BuildingViewScene` remain scene-local owners. Reuse existing pending-first `GameViewController` routing and intentionally supersede only the historical idle-conquest journey described below.

**Tech Stack:** Swift 5, SpriteKit/UIKit, Swift Testing, XCTest UI tests, Xcode asset catalogs, existing HPA-479 `lk-*` PNGs.

**Spec:** `docs/superpowers/specs/2026-09-10-living-kingdom-runtime-integration-design.md`

## Global Constraints

- This branch/PR is the **single HPA-478 implementation PR**. Tasks are commits/checkpoints, never separate PRs.
- Baseline: `main` at `10036a88911aa055a406035154dd9e181f474701`, after HPA-479 / PR #41.
- HPA-479's tracked art contract is `docs/superpowers/specs/2026-09-07-living-kingdom-art-pack-design.md` plus landed `lk-*` assets/tests.
- `docs/visual-parity/living-kingdom/**` is local-only/gitignored; captures/clips are PR evidence, not runtime inputs.
- Do not modify HPA-479 production art in this PR.
- Do not add save fields/migrations, combat/economy rules, timers, settlement owners, claim/report flows, route topology, Country 2, telemetry, a VFX manager, runtime asset manifest, content registry, or routing service.
- `Country1CityCatalog` remains the single authored source of Country 1 identity. Visual family is authored there, never inferred from `CityDefenseTrait`.
- Keep `enemyCityNode.name == "enemy-city"`; stage/family changes swap its texture rather than replacing the semantic node.
- Fortress stages use exact integer comparisons: `>60%` intact, `>25%...60%` damaged, `>0%...25%` breached, zero/pending conquered.
- Exact visual families: Frontier `1–6,8,10,11,14`; Ember `7,12`; Arcane `9,13`; Royal `15`. City 11 stays Frontier.
- `TransitionEffect` owns the two FX frame-name lists and `0.05` / `0.07` second frame timings.
- Live combat can request at most one final-stage Living Kingdom transition. Restore/resize/relaunch never replays historical FX.
- Optional breach/collapse frames and perpetual caravan motion both honor Reduce Motion; static outcome art always remains visible.
- Map decoration derives from `completedCityCount`; at most two caravans; fixed repair segment is 6→7.
- Positive idle copy is exactly `Buildings dealt <CompactNumberFormatter value> idle damage.`
- A real zero-damage return clears stale feedback to the scene's existing silent/default state.
- Governing journey rule: **conquest that happens while the player was not looking routes to the pending report; conquest caused by a deliberate in-place Camp build/upgrade action stays in place.**
- Map foreground/current-city RETURN idle conquest and Camp foreground/gate-resume idle conquest route through existing `.battle` tab routing. `layoutGateWillPause` never routes.
- Camp build/upgrade conquest does not auto-route; it shows `City conquered. Open Battle for the report.` and leaves `pendingBattleResult` for explicit Battle navigation.
- Production `GameViewController` routing remains unchanged.
- `CountryMapScoutCardNode` continues using generic `enemy-city` thumbnail in this ticket.
- Existing Codecov project/patch targets remain 90%; add tests rather than exclusions or threshold changes.
- Do not edit `project.pbxproj`, `.github/`, or `codecov.yml`.

## Risks

1. **Journey contract inversion.** Current Map tests/specs explicitly assert no auto-route. Task 5 changes those expectations before production routing.
2. **Layout-gate reentrancy.** Pending state may be created during gate pause, but routing must wait for resume.
3. **Threshold rounding.** Real city maxima are not round hundreds; Task 1 uses integer ratios and real City 1/City 3 values.
4. **Perpetual motion accessibility.** Caravans must stop moving under Reduce Motion; static decoration remains.
5. **Scene-consumer regressions.** Focused gates include test suites that actually instantiate each changed scene, not only the scene's primary test file.
6. **Visual evidence drift.** Tracked HPA-479 spec + landed assets/tests are authoritative if local corrected plates are absent.

## File Map

### Create

- `Pyxis/LivingKingdomPresentation.swift` — pure derived stage/asset/FX/map rules.
- `PyxisTests/LivingKingdomPresentationTests.swift` — exact projection and asset-contract tests.

### Modify

- `Pyxis/CityDefinition.swift` — add framework-free `CityVisualFamily` and `visualFamily` field.
- `Pyxis/Country1CityCatalog.swift` — author all 15 visual-family values beside existing city identity.
- `PyxisTests/Country1CityCatalogTests.swift` — extend expected authored table with visual family.
- `Pyxis/BattleScene.swift` — fortress texture/treatment integration, `effectsLayer` FX, zero-return clearing, DEBUG readbacks.
- `Pyxis/CountryMapScene.swift` — living-map layer, Reduce Motion caravan policy, pending-report routing.
- `Pyxis/CountryMapTransientFeedback.swift` — nonblocking `.idleSummary` and positive-only idle projection.
- `Pyxis/BuildingViewScene.swift` — compact positive idle copy, zero-return reset, foreground/gate routing, deliberate-conquest pointer copy.
- `Pyxis/ForgedVisualFixture.swift` — missing visual states plus explicit fixed foreground date.
- `Pyxis/GameViewController.swift` — DEBUG fixture block only if needed to invoke the fixed return seam.
- `CLAUDE.md` — governing idle-conquest routing rule.
- `docs/superpowers/specs/2026-08-01-gameplay-sound-haptics-settings-design.md` — concise HPA-478 supersession note.
- `docs/superpowers/specs/2026-07-30-compact-conquest-report-design.md` — concise HPA-478 supersession note.
- focused tests in `PyxisTests/` and `PyxisUITests/PyxisUITests.swift` as named below.

### Must remain unchanged

- `Pyxis/KingdomGameState.swift`
- `Pyxis/BattleCombatState.swift`
- production `GameViewController` routing
- `Pyxis/CountryMapLayout.swift`
- `Pyxis/CountryMapLayoutDefinition.swift`
- `Pyxis/CountryMapScoutCardNode.swift`
- persistence/schema files
- HPA-479 `lk-*` imagesets
- CI/Codecov configuration

---

## Task 1: Author visual family once and add the pure presentation projection

**Files:**
- Modify: `Pyxis/CityDefinition.swift`
- Modify: `Pyxis/Country1CityCatalog.swift`
- Modify: `PyxisTests/Country1CityCatalogTests.swift`
- Create: `Pyxis/LivingKingdomPresentation.swift`
- Create: `PyxisTests/LivingKingdomPresentationTests.swift`

**Interfaces:**
- `CityDefinition.visualFamily: CityVisualFamily` is the single authored family value.
- `LivingKingdomPresentation.battle(cityNumber:remainingHP:maxHP:hasPendingConquest:) -> Battle`
- `LivingKingdomPresentation.transitionEffect(from:to:) -> TransitionEffect?`
- `LivingKingdomPresentation.map(completedCityCount:) -> Map`

- [ ] **Step 1: Extend the authored catalog test before production code.**

Add `visualFamily: CityVisualFamily` to `Country1CityCatalogTests.ExpectedDefinition`, pass it through its `definition` builder, and add the exact family to each of the 15 expected rows:

```swift
1...6  -> .frontier
7      -> .ember
8      -> .frontier
9      -> .arcane
10...11 -> .frontier
12     -> .ember
13     -> .arcane
14     -> .frontier
15     -> .royal
```

The existing full-table equality check must now fail because production `CityDefinition` has no `visualFamily`.

- [ ] **Step 2: Add failing real-HP projection tests.**

Create `PyxisTests/LivingKingdomPresentationTests.swift`:

```swift
import Testing
import UIKit
@testable import Pyxis

@Suite("Living Kingdom presentation")
struct LivingKingdomPresentationTests {
    @Test(arguments: [
        (13, LivingKingdomPresentation.FortressStage.intact),
        (12, .damaged),
        (6, .damaged),
        (5, .breached),
        (1, .breached),
        (0, .conquered)
    ])
    func cityOneUsesExactBoundaries(
        remaining: Int,
        expected: LivingKingdomPresentation.FortressStage
    ) {
        let maximum = KingdomGameState.cityMaxPower(for: 1)
        #expect(maximum == 20)
        #expect(LivingKingdomPresentation.battle(
            cityNumber: 1,
            remainingHP: remaining,
            maxHP: maximum,
            hasPendingConquest: false
        ).stage == expected)
    }

    @Test(arguments: [
        (56, LivingKingdomPresentation.FortressStage.intact),
        (55, .damaged),
        (24, .damaged),
        (23, .breached)
    ])
    func cityThreeUsesRealIntegerBoundaries(
        remaining: Int,
        expected: LivingKingdomPresentation.FortressStage
    ) {
        let maximum = KingdomGameState.cityMaxPower(for: 3)
        #expect(maximum == 92)
        #expect(LivingKingdomPresentation.battle(
            cityNumber: 3,
            remainingHP: remaining,
            maxHP: maximum,
            hasPendingConquest: false
        ).stage == expected)
    }
}
```

Add a test with positive HP + `hasPendingConquest: true` expecting `.conquered`.

- [ ] **Step 3: Add failing catalog-family/asset and FX-contract tests.**

For every city in `Country1CityCatalog.cityRange`, assert the projected family equals `Country1CityCatalog.definition(for: city).visualFamily`. Assert City 11 is `.frontier`, every generated `lk-city-*` asset resolves, Frontier treatment is nil, and each themed treatment resolves.

Lock FX metadata exactly:

```swift
#expect(LivingKingdomPresentation.TransitionEffect.breach.frameNames == [
    "lk-fx-breach-01", "lk-fx-breach-02", "lk-fx-breach-03",
    "lk-fx-breach-04", "lk-fx-breach-05", "lk-fx-breach-06"
])
#expect(LivingKingdomPresentation.TransitionEffect.breach.secondsPerFrame == 0.05)
#expect(LivingKingdomPresentation.TransitionEffect.collapse.frameNames == [
    "lk-fx-collapse-01", "lk-fx-collapse-02", "lk-fx-collapse-03",
    "lk-fx-collapse-04", "lk-fx-collapse-05", "lk-fx-collapse-06"
])
#expect(LivingKingdomPresentation.TransitionEffect.collapse.secondsPerFrame == 0.07)
```

Assert all 12 names resolve with `UIImage(named:)` and lock skipped-stage selection:

```swift
#expect(LivingKingdomPresentation.transitionEffect(from: .intact, to: .damaged) == nil)
#expect(LivingKingdomPresentation.transitionEffect(from: .intact, to: .breached) == .breach)
#expect(LivingKingdomPresentation.transitionEffect(from: .damaged, to: .breached) == .breach)
#expect(LivingKingdomPresentation.transitionEffect(from: .intact, to: .conquered) == .collapse)
#expect(LivingKingdomPresentation.transitionEffect(from: .breached, to: .conquered) == .collapse)
#expect(LivingKingdomPresentation.transitionEffect(from: .conquered, to: .conquered) == nil)
```

- [ ] **Step 4: Add failing map-projection tests.**

```swift
#expect(LivingKingdomPresentation.map(completedCityCount: -3).securedCityNumbers == [])
#expect(LivingKingdomPresentation.map(completedCityCount: 1).caravanSegmentStartCityNumbers == [])
#expect(LivingKingdomPresentation.map(completedCityCount: 2).caravanSegmentStartCityNumbers == [1])
#expect(LivingKingdomPresentation.map(completedCityCount: 4).caravanSegmentStartCityNumbers == [1, 2])
#expect(LivingKingdomPresentation.map(completedCityCount: 99).securedCityNumbers == Array(1...15))
#expect(LivingKingdomPresentation.map(completedCityCount: 99).caravanSegmentStartCityNumbers == [1, 2])
#expect(LivingKingdomPresentation.map(completedCityCount: 6).routeSixToSevenAssetName == "lk-map-route-6-7-worn")
#expect(LivingKingdomPresentation.map(completedCityCount: 7).routeSixToSevenAssetName == "lk-map-route-6-7-repaired")
```

- [ ] **Step 5: Run the two focused suites and confirm RED.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/Country1CityCatalogTests \
  -only-testing:PyxisTests/LivingKingdomPresentationTests
```

Expected: compile/test failure because `CityVisualFamily`, `visualFamily`, and `LivingKingdomPresentation` do not exist.

- [ ] **Step 6: Add the catalog field and author all 15 values.**

In `CityDefinition.swift`:

```swift
enum CityVisualFamily: String, CaseIterable, Equatable {
    case frontier
    case ember
    case arcane
    case royal
}

struct CityDefinition: Equatable {
    let cityNumber: Int
    let name: String
    let flavorText: String
    let conquestTitle: String
    let defenseTrait: CityDefenseTrait
    let laneDefenseProfile: LaneDefenseProfile
    let visualFamily: CityVisualFamily

    var displayTitle: String {
        "City \(cityNumber) · \(name)"
    }
}
```

Add `visualFamily:` to each existing `Country1CityCatalog.definitions` row using the exact mapping from Step 1. Do not infer it from `defenseTrait`.

- [ ] **Step 7: Implement the minimum pure projection.**

```swift
import Foundation

enum LivingKingdomPresentation {
    enum FortressStage: String, CaseIterable, Equatable {
        case intact, damaged, breached, conquered
    }

    enum TransitionEffect: Equatable {
        case breach, collapse

        var frameNames: [String] {
            switch self {
            case .breach:
                return [
                    "lk-fx-breach-01", "lk-fx-breach-02", "lk-fx-breach-03",
                    "lk-fx-breach-04", "lk-fx-breach-05", "lk-fx-breach-06"
                ]
            case .collapse:
                return [
                    "lk-fx-collapse-01", "lk-fx-collapse-02", "lk-fx-collapse-03",
                    "lk-fx-collapse-04", "lk-fx-collapse-05", "lk-fx-collapse-06"
                ]
            }
        }

        var secondsPerFrame: TimeInterval {
            switch self {
            case .breach: 0.05
            case .collapse: 0.07
            }
        }
    }

    struct Battle: Equatable {
        let family: CityVisualFamily
        let stage: FortressStage

        var fortressAssetName: String {
            "lk-city-\(family.rawValue)-\(stage.rawValue)"
        }

        var battlefieldTreatmentAssetName: String? {
            family == .frontier ? nil : "lk-battlefield-\(family.rawValue)"
        }
    }

    struct Map: Equatable {
        let securedCityNumbers: [Int]
        let caravanSegmentStartCityNumbers: [Int]
        let routeSixToSevenAssetName: String
    }

    static func battle(
        cityNumber: Int,
        remainingHP: Int,
        maxHP: Int,
        hasPendingConquest: Bool
    ) -> Battle {
        let maximum = max(1, maxHP)
        let remaining = max(0, remainingHP)
        let stage: FortressStage
        if hasPendingConquest || remaining == 0 {
            stage = .conquered
        } else if remaining * 5 > maximum * 3 {
            stage = .intact
        } else if remaining * 4 > maximum {
            stage = .damaged
        } else {
            stage = .breached
        }
        return Battle(
            family: Country1CityCatalog.definition(for: cityNumber).visualFamily,
            stage: stage
        )
    }

    static func transitionEffect(
        from old: FortressStage,
        to new: FortressStage
    ) -> TransitionEffect? {
        guard old != new else { return nil }
        switch new {
        case .breached: return .breach
        case .conquered: return .collapse
        case .intact, .damaged: return nil
        }
    }

    static func map(completedCityCount: Int) -> Map {
        let completed = min(KingdomGameState.firstCountryCityCount, max(0, completedCityCount))
        let secured = completed == 0 ? [] : Array(1...completed)
        let eligibleStarts = completed <= 1 ? [] : Array(1..<completed)
        return Map(
            securedCityNumbers: secured,
            caravanSegmentStartCityNumbers: Array(eligibleStarts.prefix(2)),
            routeSixToSevenAssetName: completed >= 7
                ? "lk-map-route-6-7-repaired"
                : "lk-map-route-6-7-worn"
        )
    }
}
```

- [ ] **Step 8: Run focused tests and commit.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/Country1CityCatalogTests \
  -only-testing:PyxisTests/LivingKingdomPresentationTests

git diff --check
git add Pyxis/CityDefinition.swift Pyxis/Country1CityCatalog.swift \
  Pyxis/LivingKingdomPresentation.swift \
  PyxisTests/Country1CityCatalogTests.swift PyxisTests/LivingKingdomPresentationTests.swift
git commit -m "feat: project Living Kingdom visual state"
```

---

## Task 2: Integrate Battle fortress/treatment and live FX through existing owners

**Files:**
- Modify: `Pyxis/BattleScene.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`
- Optional modify: `PyxisTests/BattleSceneCoverageTests.swift` only if new executable branches need direct coverage
- Regression-run unchanged: `PyxisTests/GameViewControllerTests.swift`
- Regression-run unchanged: `PyxisTests/SoldierRuntimeGeometryTests.swift`

**Interfaces:**
- Consumes Task 1 `Battle` and `TransitionEffect`.
- Produces a stable `enemy-city` node with derived texture/treatment and one replaceable `effectsLayer` transition.

- [ ] **Step 1: Add failing static/readback tests.**

Add DEBUG readbacks for the current projected fortress asset and optional treatment asset. Tests must prove:

- full-HP City 3 → `lk-city-frontier-intact`, no treatment;
- City 3 at its real 60% boundary → damaged;
- City 3 at its real 25% boundary → breached;
- City 7 → Ember + `lk-battlefield-ember`;
- City 9 → Arcane + `lk-battlefield-arcane`;
- City 15 → Royal + `lk-battlefield-royal`;
- pending result → conquered immediately;
- `firstNode(named: "enemy-city", in: scene)` still resolves after every texture change.

- [ ] **Step 2: Add failing live-effect tests using a DEBUG request counter.**

Record only requested `TransitionEffect` values in DEBUG storage. Prove:

- damaged transition → zero Living Kingdom effects;
- direct/intact→breached → exactly one `.breach`;
- direct conquest → exactly one `.collapse`, never breach + collapse;
- restored pending scene → zero requested effects;
- layout refresh after a live breach does not append a request;
- a no-layout redraw after a hit does not append a request or replace `enemy-city`.

- [ ] **Step 3: Run Battle tests and confirm RED.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/BattleSceneTests
```

- [ ] **Step 4: Keep the existing fortress node and swap only texture.**

Create the enemy sprite once with any valid current projected fortress asset, then keep:

```swift
cityNode.name = BattleAssetName.enemyCity // "enemy-city"
```

Add:

```swift
private var livingKingdomBattlePresentation: LivingKingdomPresentation.Battle {
    LivingKingdomPresentation.battle(
        cityNumber: state.currentCityKey.cityNumber,
        remainingHP: state.cityRemainingPower,
        maxHP: state.cityMaxPower,
        hasPendingConquest: state.pendingBattleResult != nil
    )
}
```

`applyLivingKingdomStaticPresentation()` sets `enemyCitySprite.texture = SKTexture(imageNamed: presentation.fortressAssetName)` but never changes the sprite's semantic name or replaces it. This is safe because all 16 HPA-479 fortress textures share the same 512×540 canvas.

- [ ] **Step 5: Add one optional treatment node.**

Configure once:

```swift
livingKingdomTreatmentNode.name = "livingKingdomBattlefieldTreatment"
livingKingdomTreatmentNode.anchorPoint = CGPoint(x: 0.5, y: 0.5)
livingKingdomTreatmentNode.zPosition = GameUITheme.Z.background + 0.5
livingKingdomTreatmentNode.blendMode = .alpha
environmentLayer.addChild(livingKingdomTreatmentNode)
```

Frontier hides it. Other families load the projected `lk-battlefield-*`. Mirror the existing backdrop position/scale after battlefield layout.

- [ ] **Step 6: Capture old/new stage around the existing live mutation.**

Immediately before `state.applyLiveSoldierAttacks(...)`:

```swift
let previousStage = livingKingdomBattlePresentation.stage
```

After the existing model mutation, save, and static redraw:

```swift
let currentStage = livingKingdomBattlePresentation.stage
if let effect = LivingKingdomPresentation.transitionEffect(
    from: previousStage,
    to: currentStage
) {
    playLivingKingdomTransition(effect)
}
```

Do not add `lastFortressStage` state.

- [ ] **Step 7: Play transition in existing `effectsLayer`, not under the fortress.**

```swift
private func playLivingKingdomTransition(
    _ effect: LivingKingdomPresentation.TransitionEffect
) {
    #if DEBUG
    livingKingdomTransitionEffectsForTestingStorage.append(effect)
    #endif

    effectsLayer.childNode(withName: "livingKingdomTransitionFX")?.removeFromParent()
    guard !UIAccessibility.isReduceMotionEnabled else { return }

    let textures = effect.frameNames.map(SKTexture.init(imageNamed:))
    guard let first = textures.first else { return }

    let fx = SKSpriteNode(texture: first)
    fx.name = "livingKingdomTransitionFX"
    fx.anchorPoint = CGPoint(x: 0.5, y: 0)
    fx.zPosition = GameUITheme.Z.effects
    effectsLayer.addChild(fx)
    layoutLivingKingdomTransitionFX(fx)
    fx.run(.sequence([
        .animate(with: textures, timePerFrame: effect.secondsPerFrame),
        .removeFromParent()
    ]))
}

private func layoutLivingKingdomTransitionFX(_ fx: SKSpriteNode) {
    guard let city = enemyCityNode as? SKSpriteNode else { return }
    let displayedFortressHeight = city.size.height * abs(city.yScale)
    let fxHeight = 512 * displayedFortressHeight / 540
    fx.position = city.position
    fx.size = CGSize(width: fxHeight, height: fxHeight)
}
```

Because `environmentLayer` and `battlefieldActionLayer` share the battlefield origin and `effectsLayer` is under the latter, `city.position` is the same battlefield coordinate. Settings already pauses `battlefieldActionLayer`, so it pauses the new effect without a second controller.

After laying out the city on resize, if `effectsLayer.childNode(withName: "livingKingdomTransitionFX")` is an active sprite, call `layoutLivingKingdomTransitionFX` to reposition/rescale it without restarting playback.

- [ ] **Step 8: Preserve existing colorize and pause tests.**

The existing `playCityHitFeedback` / `playCityConquestFeedback` continue to colorize only `enemy-city`; the new FX is a separate effects-layer node. Keep the existing Settings pause regression and add only the assertion needed to prove the new FX remains under the paused action layer.

- [ ] **Step 9: Run all real Battle consumers before commit.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/BattleSceneTests \
  -only-testing:PyxisTests/BattleSceneCoverageTests \
  -only-testing:PyxisTests/GameViewControllerTests \
  -only-testing:PyxisTests/SoldierRuntimeGeometryTests

xcodebuild -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build

git diff --check
```

- [ ] **Step 10: Commit.**

```bash
git add Pyxis/BattleScene.swift PyxisTests/BattleSceneTests.swift
# Add BattleSceneCoverageTests.swift only if it actually changed.
git commit -m "feat: render Living Kingdom battle progression"
```

---

## Task 3: Render living-map decoration and make caravan motion accessible

**Files:**
- Modify: `Pyxis/CountryMapScene.swift`
- Modify: `PyxisTests/CountryMapSceneTests.swift`
- Regression-run unchanged: `PyxisTests/CountryMapScoutCardAcceptanceTests.swift`
- Regression-run unchanged: `PyxisTests/GameViewControllerTests.swift`

**Interfaces:**
- Consumes `LivingKingdomPresentation.map(completedCityCount:)` and existing `CountryMapLayout.cityPositions/displayedBackdropFrame`.
- Produces one noninteractive decoration layer; does not change layout/hit topology.

- [ ] **Step 1: Add failing decoration/interaction tests.**

Add DEBUG readbacks for secured count, caravan count, route-patch asset, and whether visible caravans currently have movement actions. Assert:

- completed 0/1 → zero caravans;
- completed 2 → one caravan;
- completed 3+ → exactly two, never more;
- secured count equals clamped completion count;
- completed 6 → worn; completed 7 → repaired;
- existing 44pt city hit frames/centers are unchanged;
- unsupported geometry clears decoration/actions;
- repeated redraw with unchanged progress/layout does not recreate caravan nodes/actions.

- [ ] **Step 2: Add a Reduce Motion seam without new runtime infrastructure.**

Add an init override used only by tests:

```swift
private let isReduceMotionEnabled: () -> Bool
```

Default it to `{ UIAccessibility.isReduceMotionEnabled }`. Existing call sites need no change because the parameter has a default. Add one test with `{ true }` and assert eligible caravan sprites exist but have no movement action.

Do not add an accessibility settings preference; this reads the system setting only.

- [ ] **Step 3: Run Map scene + acceptance tests and confirm RED.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/CountryMapSceneTests \
  -only-testing:PyxisTests/CountryMapScoutCardAcceptanceTests
```

- [ ] **Step 4: Add one decoration layer and render key.**

```swift
private let livingKingdomLayer = SKNode()

private struct LivingKingdomMapRenderKey: Equatable {
    let completedCityCount: Int
    let backdropFrame: CGRect
    let reduceMotion: Bool
}
private var lastLivingKingdomMapRenderKey: LivingKingdomMapRenderKey?
```

Set z positions:

```swift
routeLayer.zPosition = 0
livingKingdomLayer.zPosition = 5
cityLayer.zPosition = 10
```

Add the layer once. In `clearLayoutGeometry()`, reset the key and remove all Living Kingdom children.

- [ ] **Step 5: Render secured overlays and fixed 6→7 patch.**

```swift
let presentation = LivingKingdomPresentation.map(completedCityCount: state.completedCityCount)
let mapScale = layout.displayedBackdropFrame.width
    / CountryMapLayoutDefinition.country1.canonicalBackdropSize.width
```

For every secured city with a runtime position, add `lk-map-secured-city` at that position with `96 * mapScale` square size.

For City 6/7 positions, add the projected route patch at their midpoint with `192 * mapScale` square size. Do not rotate or mutate the underlying route.

- [ ] **Step 6: Render at most two caravans; move only without Reduce Motion.**

For every projected start `n`:

```swift
let start = layout.cityPositions[n]!
let end = layout.cityPositions[n + 1]!
let caravan = SKSpriteNode(imageNamed: "lk-map-caravan")
caravan.name = "livingKingdomCaravan-\(n)"
caravan.size = CGSize(width: 128 * mapScale, height: 64 * mapScale)
caravan.position = start
caravan.zRotation = atan2(end.y - start.y, end.x - start.x)
livingKingdomLayer.addChild(caravan)
```

If Reduce Motion is false, run deterministic movement:

```swift
let wait = SKAction.wait(forDuration: 0.8 * Double(index))
let move = SKAction.move(to: end, duration: 5.0)
let reset = SKAction.run { [weak caravan] in caravan?.position = start }
caravan.run(.repeatForever(.sequence([wait, move, reset])), withKey: "livingKingdomCaravanMove")
```

If Reduce Motion is true, leave the sprite static at `start` and run no action.

- [ ] **Step 7: Render only when completion/layout/motion state changes.**

Call `renderLivingKingdomMapIfNeeded(layout:)` from `redraw()` after valid layout. Compare the render key before rebuilding so Scout selection/transient-feedback redraws are no-ops.

- [ ] **Step 8: Run every real CountryMapScene consumer and commit.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/CountryMapSceneTests \
  -only-testing:PyxisTests/CountryMapScoutCardAcceptanceTests \
  -only-testing:PyxisTests/GameViewControllerTests

git diff --check
git add Pyxis/CountryMapScene.swift PyxisTests/CountryMapSceneTests.swift
git commit -m "feat: make conquered map feel alive"
```

Do not add `CountryMapScoutCardNodeTests` merely for this task: it constructs `CountryMapScoutCardNode` directly, and that node remains unchanged.

---

## Task 4: Make positive idle summaries truthful and zero returns actually silent

**Files:**
- Modify: `Pyxis/CountryMapTransientFeedback.swift`
- Modify: `Pyxis/BattleScene.swift`
- Modify: `Pyxis/BuildingViewScene.swift`
- Modify: `PyxisTests/CountryMapTransientFeedbackTests.swift`
- Modify: `PyxisTests/CountryMapSceneTests.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`
- Modify: `PyxisTests/BuildingViewSceneTests.swift`
- Regression-run unchanged: `PyxisTests/CountryMapScoutCardAcceptanceTests.swift`
- Regression-run unchanged: `PyxisTests/GameViewControllerTests.swift`

**Interfaces:**
- Positive non-conquest result becomes a compact summary.
- Credited elapsed time + zero damage clears stale feedback.
- This task does not change journey routing yet.

- [ ] **Step 1: Rewrite transient-feedback tests first.**

Replace `onlyFlavorDoesNotBlockScoutEntry` so `.flavor` and `.idleSummary` are the only nonblocking kinds. Replace `idleProjectsExistingStatusCopy` with:

```swift
let positive = KingdomGameState.IdleProgressResult(
    elapsedSeconds: 3_600,
    damageDealt: 1_234,
    conqueredCities: 0,
    goldEarned: 0
)
let feedback = try #require(CountryMapTransientFeedback.idle(result: positive, state: state))
#expect(feedback.kind == .idleSummary)
#expect(!feedback.kind.blocksScoutEntry)
#expect(feedback.text == "Buildings dealt 1.2K idle damage.")

#expect(CountryMapTransientFeedback.idle(
    result: .init(elapsedSeconds: 10, damageDealt: 0, conqueredCities: 0, goldEarned: 0),
    state: state
) == nil)
#expect(CountryMapTransientFeedback.idle(
    result: .init(elapsedSeconds: 10, damageDealt: 9, conqueredCities: 1, goldEarned: 4),
    state: state
) == nil)
```

- [ ] **Step 2: Implement `.idleSummary`.**

```swift
enum Kind: Equatable {
    case locked
    case completed
    case status
    case recoverableError
    case flavor
    case idleSummary

    var blocksScoutEntry: Bool {
        self != .flavor && self != .idleSummary
    }
}
```

`idle(result:state:)` returns nil unless `elapsedSeconds > 0`, `damageDealt > 0`, and `conqueredCities == 0`. The returned summary uses the existing 2.5s/0.3s timing and compact formatted damage. Keep the existing `state` parameter for minimal call-site churn in this PR.

- [ ] **Step 3: Add failing stale-text reset tests for all three scenes.**

Battle: seed a visible prior tooltip/message, resolve a real positive elapsed return that yields zero damage, and expect `feedbackTextForTesting == ""` after settlement.

Camp: seed a prior action message such as a successful build or insufficient-gold message, resolve a real positive elapsed zero-damage return, and expect `feedbackTextForTesting == "Select a city lot."` and its label hidden.

Map: show a prior transient, resolve a real positive elapsed zero-damage return, and expect no visible idle transient/overlay.

Also keep positive-damage exact-copy tests.

- [ ] **Step 4: Implement scene-specific silent/default clearing.**

In Battle foreground settlement:

```swift
if result.elapsedSeconds > 0 {
    if result.conqueredCities > 0 {
        // existing conquest behavior
    } else if result.damageDealt > 0 {
        feedbackText = "Buildings dealt \(CompactNumberFormatter.string(from: result.damageDealt)) idle damage."
    } else {
        feedbackText = ""
    }
}
```

In Camp `applyIdleProgressFeedback`:

```swift
guard result.elapsedSeconds > 0 else { return }
if result.conqueredCities > 0 {
    // existing conquest handling for now; Task 5 changes journey/copy
} else if result.damageDealt > 0 {
    feedbackText = "Buildings dealt \(CompactNumberFormatter.string(from: result.damageDealt)) idle damage."
} else {
    feedbackText = "Select a city lot."
}
```

In Map, when a real elapsed result produces neither positive summary nor conquest, clear `transientFeedback` and reapply/redraw so stale status/flavor does not remain as a return result.

- [ ] **Step 5: Run all touched-scene consumers and commit.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/CountryMapTransientFeedbackTests \
  -only-testing:PyxisTests/CountryMapSceneTests \
  -only-testing:PyxisTests/CountryMapScoutCardAcceptanceTests \
  -only-testing:PyxisTests/BattleSceneTests \
  -only-testing:PyxisTests/BuildingViewSceneTests \
  -only-testing:PyxisTests/GameViewControllerTests

git diff --check
git add Pyxis/CountryMapTransientFeedback.swift Pyxis/CountryMapScene.swift \
  Pyxis/BattleScene.swift Pyxis/BuildingViewScene.swift \
  PyxisTests/CountryMapTransientFeedbackTests.swift PyxisTests/CountryMapSceneTests.swift \
  PyxisTests/BattleSceneTests.swift PyxisTests/BuildingViewSceneTests.swift
git commit -m "feat: show truthful idle damage summaries"
```

---

## Task 5: Apply the governing conquest journey rule and update docs of record

**Files:**
- Modify: `Pyxis/CountryMapScene.swift`
- Modify: `Pyxis/BuildingViewScene.swift`
- Modify: `PyxisTests/CountryMapSceneTests.swift`
- Modify: `PyxisTests/BuildingViewSceneTests.swift`
- Regression-run unchanged: `PyxisTests/GameViewControllerTests.swift`
- Modify: `CLAUDE.md`
- Modify: `docs/superpowers/specs/2026-08-01-gameplay-sound-haptics-settings-design.md`
- Modify: `docs/superpowers/specs/2026-07-30-compact-conquest-report-design.md`

**Interfaces:**
- Background/foreground/gate-resume conquest reaches existing pending report.
- Deliberate Camp build/upgrade conquest stays on Camp with one short pointer.
- No new protocol or routing service.

- [ ] **Step 1: Invert the named Map tests before production code.**

Change these existing tests:

- `selectedCurrentCityReturnLeavesLethalIdleConquestPending` → expect one `.battle` request while persisted `pendingBattleResult` remains idle.
- `countryMapFreshIdleConquestEmitsRewardThenCityOutcomeWithoutReplay` → expect one `.battle` request after the same `[goldReward, cityConquest]` feedback; remove `Next: Bramblegate` Map transient expectation.
- `countryMapFinalIdleConquestEmitsExactlyOneCountryOutcome` → expect one `.battle` request after `[goldReward, countryCompletion]`; no Map conquest transient.

Add explicit tests:

- `layoutGateWillPause` can create pending result but router count remains zero;
- `layoutGateWillResume` routes once if pending remains;
- normal tab settlement that creates pending state still produces only its existing one route request.

These failures are intentional HPA-478 contract supersession.

- [ ] **Step 2: Add a five-line scene-local pending route helper in Map.**

```swift
@discardableResult
private func routePendingConquestIfNeeded() -> Bool {
    guard state.pendingBattleResult != nil,
          !isRoutingToBattle,
          let router else { return false }
    isRoutingToBattle = true
    guard router.countryMapSceneDidRequestGameplayTab(self, tab: .battle) else {
        isRoutingToBattle = false
        return false
    }
    return true
}
```

Use it after save/feedback/redraw in `handleSceneWillEnterForeground`, in the current-city RETURN settlement path when conquest occurs, and on `layoutGateWillResume`. Never call it from `layoutGateWillPause`. Leave normal tab routing unchanged.

- [ ] **Step 3: Add Camp tests for the asymmetric deliberate-action rule.**

Lock all of these:

- foreground idle conquest → `.battle` once;
- gate pause → zero route; resume → `.battle` once if pending;
- build settlement conquest → pending result saved, reward/outcome feedback emitted, **no route**;
- upgrade settlement conquest → same no-route behavior;
- build/upgrade conquest visible copy is exactly `City conquered. Open Battle for the report.`;
- later explicit Battle/tab request routes once and existing pending-first controller presents the report.

- [ ] **Step 4: Keep deliberate Camp conquest local and visible.**

For `.cityConqueredDuringSettlement` in both build/upgrade paths:

```swift
store.save(state)
closeFeedbackSettings(focusTarget: .systemDefault)
emitFreshOutcomeFeedback(goldEarned: goldEarned, conqueredCities: 1)
feedbackText = "City conquered. Open Battle for the report."
```

Do not call the router here. Do not repeat the city name, gold amount, report statistics, or add a second Continue action.

- [ ] **Step 5: Route only Camp idle/gate-resume conquest.**

Add a private helper analogous to Map but calling:

```swift
router.buildingViewSceneDidRequestGameplayTab(self, tab: .battle)
```

Call it after foreground idle conquest and on `layoutGateWillResume` when pending remains. Never call it from gate pause or build/upgrade settlement.

- [ ] **Step 6: Update repository docs of record in the same behavior commit.**

In `CLAUDE.md`, replace the unconditional Building View no-auto-route sentence with the governing rule:

> Conquest that happens while the player was not looking (idle foreground/gate-resume settlement, plus Map current-city RETURN settlement) routes to Battle so the pending report is shown. Conquest caused by a deliberate in-place Building View build/upgrade action stays on Camp, leaves the pending result in place, and shows a short pointer to open Battle for the report.

Also update the `.idleSummary` convention so both `.flavor` and `.idleSummary` are documented as nonblocking Map feedback kinds.

In each older spec, add a concise note near the old no-auto-route requirement:

```markdown
> **Superseded by HPA-478:** idle foreground/gate-resume conquest now routes to the existing pending Battle report. Deliberate in-place Camp build/upgrade conquest still stays on Camp.
```

Do not rewrite unrelated historical design sections.

- [ ] **Step 7: Run high-risk routing/doc-adjacent tests.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/CountryMapSceneTests \
  -only-testing:PyxisTests/CountryMapScoutCardAcceptanceTests \
  -only-testing:PyxisTests/BuildingViewSceneTests \
  -only-testing:PyxisTests/GameViewControllerTests

git diff --check
```

- [ ] **Step 8: Commit behavior + superseded docs together.**

```bash
git add Pyxis/CountryMapScene.swift Pyxis/BuildingViewScene.swift \
  PyxisTests/CountryMapSceneTests.swift PyxisTests/BuildingViewSceneTests.swift \
  CLAUDE.md \
  docs/superpowers/specs/2026-08-01-gameplay-sound-haptics-settings-design.md \
  docs/superpowers/specs/2026-07-30-compact-conquest-report-design.md
git commit -m "feat: route idle conquests to pending report"
```

Do not modify production `GameViewController` for this task.

---

## Task 6: Extend deterministic fixtures and finish visual/CI acceptance

**Files:**
- Modify: `Pyxis/ForgedVisualFixture.swift`
- Modify: `Pyxis/GameViewController.swift` **DEBUG fixture block only if the return hook is required**
- Modify: `PyxisTests/ForgedVisualFixtureTests.swift`
- Modify: `PyxisTests/GameViewControllerTests.swift` only for DEBUG fixture semantics if required
- Modify: `PyxisUITests/PyxisUITests.swift`
- Local-only: `docs/visual-parity/living-kingdom/**`

**Interfaces:**
- Consumes completed shipping implementation.
- Produces deterministic visual states/evidence; no Release behavior.

- [ ] **Step 1: Add missing fixture cases and explicitly define fixed foreground time.**

Add cases:

```text
battle-damaged
battle-breached
battle-emberford
battle-runewatch
battle-crownspire
return-damage
```

Use real City 1 thresholds:

```swift
// City 1 max HP = 20.
battle-damaged: remainingHP = 12
battle-breached: remainingHP = 5
```

Landmark fixtures use `DevJumpState.make(city: 7)`, `9`, and `15` at full HP.

For `return-damage`, seed one building, a fixed background timestamp, and enough HP to avoid conquest. Add the missing property explicitly:

```swift
var foregroundReturnDate: Date? {
    switch self {
    case .returnDamage:
        return Date(timeIntervalSince1970: 4_600)
    default:
        return nil
    }
}
```

Seed the return fixture's background state at `Date(timeIntervalSince1970: 1_000)` so the result is deterministic.

- [ ] **Step 2: Add failing fixture parser/state/semantic tests.**

Lock every new raw value. For Battle fixtures, assert projected family/stage in the existing DEBUG accessibility value. For Map, expose only secured/caravan/patch facts needed for UI assertions. For `return-damage`, assert the visible compact damage copy.

- [ ] **Step 3: Use the actual existing Battle lifecycle seam.**

In the existing `#if DEBUG` fixture installer only:

```swift
if let returnDate = fixture.foregroundReturnDate,
   let battle = view.scene as? BattleScene {
    battle.enterForegroundForTesting(at: returnDate)
}
```

The method name is exactly `enterForegroundForTesting(at:)`; do not introduce `sceneWillEnterForegroundForTesting`.

- [ ] **Step 4: Keep Scout thumbnail explicitly outside the fixture matrix.**

Landmark captures validate Battle fortress/treatment only. `CountryMapScoutCardNode.swift` stays unchanged and keeps generic `enemy-city` art.

- [ ] **Step 5: Run fixture semantic tests.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/ForgedVisualFixtureTests \
  -only-testing:PyxisTests/GameViewControllerTests

xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisUITests
```

- [ ] **Step 6: Capture the 393×852 matrix.**

```text
battle                  -> Frontier intact
battle-damaged          -> Frontier damaged
battle-breached         -> Frontier breached
conquest-live/idle      -> conquered fortress under existing report
battle-emberford        -> Ember family/treatment
battle-runewatch        -> Arcane family/treatment
battle-crownspire       -> Royal family/treatment
map                     -> early living map
map-partial             -> partial living map
map-country-complete    -> complete living map
return-damage           -> positive idle summary
conquest-idle           -> idle conquest + one Continue
```

Store evidence under ignored `docs/visual-parity/living-kingdom/runtime/`; attach/link it in the PR conversation and never `git add -f` it.

- [ ] **Step 7: Record one short behavior clip.**

Show one live breach/conquest threshold crossing with its single FX, eligible caravan movement with Reduce Motion off, and an idle return leading to a positive summary or pending report. Also smoke Reduce Motion on and confirm caravans remain static while all static visual state remains readable.

- [ ] **Step 8: Smoke compact phone and portrait iPad.**

Verify lanes, HP bar, milestone accent, 44pt Map city targets, Scout/Attack, tabs, pending report/Continue, Camp/Settings, and no unexpected auto-navigation after deliberate build/upgrade conquest.

- [ ] **Step 9: Run full serial gates.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO

swiftlint lint --strict

xcodebuild -project Pyxis.xcodeproj -scheme Pyxis \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build

xcodebuild -project Pyxis.xcodeproj -scheme Pyxis \
  -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build

git diff --check
git status --short
git diff --name-only main...HEAD
```

Expected final production diff is concentrated in the catalog/projection and three scene owners. It must not include HPA-479 art, save/schema files, `CountryMapLayout*`, production `GameViewController` routing, `CountryMapScoutCardNode.swift`, or CI/Codecov configuration.

Inspect Codecov after CI. If project/patch coverage is below 90%, cover the new executable branches; do not lower the gate.

- [ ] **Step 10: Commit fixture/acceptance code and keep Draft until evidence/CI pass.**

```bash
git add Pyxis/ForgedVisualFixture.swift \
  PyxisTests/ForgedVisualFixtureTests.swift PyxisUITests/PyxisUITests.swift
# Add Pyxis/GameViewController.swift and PyxisTests/GameViewControllerTests.swift only if the DEBUG return fixture required changes.
git commit -m "test: cover Living Kingdom visual acceptance"
```

---

## Final Self-Review Checklist

- [ ] `Country1CityCatalog` is the only authored visual-family table; City 11 is Frontier.
- [ ] `LivingKingdomPresentation` contains derived stage/asset/FX/map rules only.
- [ ] Exact integer stage math is covered with real City 1 and City 3 maxima.
- [ ] `TransitionEffect` owns all 12 frame names and both timings; every name resolves.
- [ ] Enemy fortress semantic node name remains exactly `enemy-city`; texture swaps do not replace the node.
- [ ] All 16 fortress assets remain safe for texture-only swapping because they share the 512×540 canvas contract.
- [ ] Battlefield treatment stays at `background + 0.5` using the existing backdrop transform.
- [ ] Live skipped-stage mutation requests at most one final-stage FX.
- [ ] Living Kingdom FX lives in `effectsLayer`; fortress colorize actions remain independent.
- [ ] Active FX can relayout without restart; resize/restore/relaunch never creates historical FX.
- [ ] Reduce Motion skips optional breach/collapse animation and stops caravan looping; static art remains.
- [ ] Map decoration is noninteractive and leaves route topology/44pt city targets unchanged.
- [ ] At most two caravans use completed primary `n→n+1` segments; 6→7 repairs at completed City 7.
- [ ] `.idleSummary` is nonblocking and compact-formatted.
- [ ] Real elapsed zero-damage return clears stale Battle/Camp/Map feedback to silent/default state.
- [ ] Map foreground/current-city idle conquest routes to existing pending report; gate pause never routes.
- [ ] Camp foreground/gate-resume idle conquest routes, but deliberate build/upgrade conquest stays in place.
- [ ] Deliberate Camp conquest copy is exactly `City conquered. Open Battle for the report.`
- [ ] `CLAUDE.md` + the two superseded design specs reflect the governing journey rule.
- [ ] DEBUG return fixture defines `foregroundReturnDate` and uses `BattleScene.enterForegroundForTesting(at:)`.
- [ ] Focused tests include real scene consumers; unchanged node-only Scout tests are not added mechanically.
- [ ] Scout thumbnail remains generic `enemy-city` by explicit scope decision.
- [ ] No save/schema/economy/combat/layout-definition/art/CI changes.
- [ ] Full tests/lint/Debug+Release builds/Codecov ≥90% and visual evidence pass before Ready for review.
