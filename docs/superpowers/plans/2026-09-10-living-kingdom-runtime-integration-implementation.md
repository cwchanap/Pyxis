# Living Kingdom Runtime Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate HPA-479's Living Kingdom assets into Battle and Country Map, and make offline-return presentation truthful, without changing Pyxis gameplay/economy/save ownership.

**Architecture:** Add one pure `LivingKingdomPresentation` projection. `BattleScene`, `CountryMapScene`, and `BuildingViewScene` keep their existing state/layout/feedback ownership and consume the projection locally. Reuse existing scene routing and pending-first `GameViewController` behavior; explicitly supersede only the historical Map stay-on-idle-conquest journey, while preserving Camp build/upgrade stay-in-place behavior.

**Tech Stack:** Swift 5, SpriteKit/UIKit, Swift Testing, XCTest UI tests, Xcode asset catalogs, existing HPA-479 `lk-*` PNGs.

**Spec:** `docs/superpowers/specs/2026-09-10-living-kingdom-runtime-integration-design.md`

## Global Constraints

- This branch/PR is the **single HPA-478 implementation PR**. Tasks are commits/checkpoints, never separate PRs.
- Baseline: `main` at `10036a88911aa055a406035154dd9e181f474701` after HPA-479 / PR #41.
- HPA-479's tracked art contract is `docs/superpowers/specs/2026-09-07-living-kingdom-art-pack-design.md` plus landed `lk-*` assets/tests.
- `docs/visual-parity/living-kingdom/**` is local-only/gitignored; generate evidence there but do not force it into git.
- Do not modify HPA-479 production art in this PR.
- Do not add save fields/migrations, economy/combat rules, timers, settlement owners, claim/report flows, route topology, Country 2, telemetry, or generic content/VFX infrastructure.
- Keep `enemyCityNode.name == "enemy-city"`; Living Kingdom assets change the texture, not semantic node identity.
- Fortress stages use exact integer comparisons: `>60%` intact, `>25%...60%` damaged, `>0%...25%` breached, zero/pending conquered.
- Exact families: Frontier `1–6,8,10,11,14`; Ember `7,12`; Arcane `9,13`; Royal `15`.
- City 11 remains Frontier.
- `TransitionEffect` owns FX frame names/timings; `BattleScene` only plays the selected effect.
- Restore/resize/relaunch applies static state only and never replays historical Living Kingdom FX.
- Map decoration derives from `completedCityCount`; at most two caravans; fixed repair segment 6→7.
- Positive idle copy: `Buildings dealt <CompactNumberFormatter value> idle damage.`
- Zero idle damage creates no new return/reward message.
- Map foreground/current-city idle conquest intentionally routes to the pending Battle report; this supersedes old Map stay-on-conquest tests/docs.
- Camp foreground idle conquest routes to the pending Battle report, but Camp build/upgrade settlement conquest **does not auto-route**.
- Production `GameViewController` routing remains unchanged.
- `CountryMapScoutCardNode` continues using generic `enemy-city` thumbnail in this ticket.
- Existing Codecov project/patch targets remain 90%; test uncovered code rather than changing thresholds/exclusions.
- Do not edit `project.pbxproj`, `.github/`, or `codecov.yml`.

## Risks

1. **Map journey contract inversion:** old tests/specs assert idle conquest stays on Map. Task 5 rewrites the named expectations before changing routing.
2. **Layout-gate reentrancy:** never route from `layoutGateWillPause`; pending state is the deferral signal, routing happens only after resume.
3. **FX vs city colorize:** `playCityHitFeedback` and `playCityConquestFeedback` colorize the same enemy sprite. Keep one persistent semantic node, swap only texture, and use one replaceable FX child.
4. **Resize/redraw during FX:** static reapplication must not rebuild the enemy node or append another effect. Tests cover layout refresh and `redraw(shouldLayout:false)`.
5. **Threshold rounding:** real city maxima are not all round hundreds. Task 1 uses integer ratio math and real City 1/City 3 maxima.
6. **Visual evidence drift:** local HPA-479 references may not be present. Tracked art spec + installed assets/tests are authoritative; captures are PR evidence only.

## File Map

### Create

- `Pyxis/LivingKingdomPresentation.swift` — pure family/stage/FX/map projection.
- `PyxisTests/LivingKingdomPresentationTests.swift` — exact projection and asset-contract coverage.

### Modify

- `Pyxis/BattleScene.swift` — stable enemy-city texture swap, treatment, live FX, zero-return no-op, DEBUG readbacks.
- `Pyxis/CountryMapScene.swift` — noninteractive map decoration and explicit pending-report routing for Map idle/current-city settlement.
- `Pyxis/CountryMapTransientFeedback.swift` — `.idleSummary`, positive-only compact idle projection.
- `Pyxis/BuildingViewScene.swift` — compact positive idle copy; foreground/gate pending-report routing only; build/upgrade stays in place.
- `Pyxis/ForgedVisualFixture.swift` — missing visual states only.
- focused tests in `PyxisTests/*` and `PyxisUITests/PyxisUITests.swift`.
- `Pyxis/GameViewController.swift` only inside the existing `#if DEBUG` fixture installer if `return-damage` needs the foreground hook.

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

## Task 1: Add the pure Living Kingdom presentation contract

**Files:**
- Create: `Pyxis/LivingKingdomPresentation.swift`
- Create: `PyxisTests/LivingKingdomPresentationTests.swift`

**Interfaces:**
- Consumes: city number, remaining/max HP, pending-result boolean, completed-city count.
- Produces: `LivingKingdomPresentation.Battle`, `TransitionEffect`, and `Map` used by later tasks.

- [ ] **Step 1: Write failing real-HP boundary tests.**

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
        #expect(KingdomGameState.cityMaxPower(for: 1) == 20)
        let battle = LivingKingdomPresentation.battle(
            cityNumber: 1,
            remainingHP: remaining,
            maxHP: KingdomGameState.cityMaxPower(for: 1),
            hasPendingConquest: false
        )
        #expect(battle.stage == expected)
    }

    @Test(arguments: [
        (56, LivingKingdomPresentation.FortressStage.intact),
        (55, .damaged),
        (24, .damaged),
        (23, .breached)
    ])
    func cityThreeUsesIntegerRatioBoundaries(
        remaining: Int,
        expected: LivingKingdomPresentation.FortressStage
    ) {
        #expect(KingdomGameState.cityMaxPower(for: 3) == 92)
        #expect(LivingKingdomPresentation.battle(
            cityNumber: 3,
            remainingHP: remaining,
            maxHP: KingdomGameState.cityMaxPower(for: 3),
            hasPendingConquest: false
        ).stage == expected)
    }
}
```

Add a pending-result case with positive HP and expect `.conquered`.

- [ ] **Step 2: Write failing all-city family and asset-name tests.**

```swift
let expected: [Int: LivingKingdomPresentation.FortressFamily] = [
    1: .frontier, 2: .frontier, 3: .frontier, 4: .frontier,
    5: .frontier, 6: .frontier, 7: .ember, 8: .frontier,
    9: .arcane, 10: .frontier, 11: .frontier, 12: .ember,
    13: .arcane, 14: .frontier, 15: .royal
]
for (city, family) in expected {
    let battle = LivingKingdomPresentation.battle(
        cityNumber: city,
        remainingHP: KingdomGameState.cityMaxPower(for: city),
        maxHP: KingdomGameState.cityMaxPower(for: city),
        hasPendingConquest: false
    )
    #expect(battle.family == family)
    #expect(UIImage(named: battle.fortressAssetName) != nil)
    if let treatment = battle.battlefieldTreatmentAssetName {
        #expect(UIImage(named: treatment) != nil)
    }
}
```

Explicitly assert City 11 `.frontier` and Frontier treatment `nil`.

- [ ] **Step 3: Write failing FX-contract tests.**

```swift
#expect(LivingKingdomPresentation.TransitionEffect.breach.frameNames ==
    (1...6).map { String(format: "lk-fx-breach-%02d", $0) })
#expect(LivingKingdomPresentation.TransitionEffect.breach.secondsPerFrame == 0.05)
#expect(LivingKingdomPresentation.TransitionEffect.collapse.frameNames ==
    (1...6).map { String(format: "lk-fx-collapse-%02d", $0) })
#expect(LivingKingdomPresentation.TransitionEffect.collapse.secondsPerFrame == 0.07)
for name in LivingKingdomPresentation.TransitionEffect.breach.frameNames
    + LivingKingdomPresentation.TransitionEffect.collapse.frameNames {
    #expect(UIImage(named: name) != nil)
}
```

Also lock skipped-stage selection:

```swift
#expect(LivingKingdomPresentation.transitionEffect(from: .intact, to: .damaged) == nil)
#expect(LivingKingdomPresentation.transitionEffect(from: .intact, to: .breached) == .breach)
#expect(LivingKingdomPresentation.transitionEffect(from: .damaged, to: .breached) == .breach)
#expect(LivingKingdomPresentation.transitionEffect(from: .intact, to: .conquered) == .collapse)
#expect(LivingKingdomPresentation.transitionEffect(from: .breached, to: .conquered) == .collapse)
#expect(LivingKingdomPresentation.transitionEffect(from: .conquered, to: .conquered) == nil)
```

- [ ] **Step 4: Write failing map projection tests.**

```swift
#expect(LivingKingdomPresentation.map(completedCityCount: -3).securedCityNumbers == [])
#expect(LivingKingdomPresentation.map(completedCityCount: 1).caravanSegmentStartCityNumbers == [])
#expect(LivingKingdomPresentation.map(completedCityCount: 2).caravanSegmentStartCityNumbers == [1])
#expect(LivingKingdomPresentation.map(completedCityCount: 4).caravanSegmentStartCityNumbers == [1, 2])
#expect(LivingKingdomPresentation.map(completedCityCount: 99).securedCityNumbers == Array(1...15))
#expect(LivingKingdomPresentation.map(completedCityCount: 99).caravanSegmentStartCityNumbers.count == 2)
#expect(LivingKingdomPresentation.map(completedCityCount: 6).routeSixToSevenAssetName == "lk-map-route-6-7-worn")
#expect(LivingKingdomPresentation.map(completedCityCount: 7).routeSixToSevenAssetName == "lk-map-route-6-7-repaired")
```

- [ ] **Step 5: Run the new suite and confirm RED.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/LivingKingdomPresentationTests
```

Expected: compile failure because the projection does not exist.

- [ ] **Step 6: Implement the minimum projection with exact integer math.**

```swift
enum LivingKingdomPresentation {
    enum FortressFamily: String, CaseIterable, Equatable {
        case frontier, ember, arcane, royal
    }

    enum FortressStage: String, CaseIterable, Equatable {
        case intact, damaged, breached, conquered
    }

    enum TransitionEffect: Equatable {
        case breach, collapse

        var frameNames: [String] {
            let prefix = self == .breach ? "lk-fx-breach" : "lk-fx-collapse"
            return (1...6).map { String(format: "\(prefix)-%02d", $0) }
        }

        var secondsPerFrame: Double {
            self == .breach ? 0.05 : 0.07
        }
    }

    struct Battle: Equatable {
        let family: FortressFamily
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
        let family: FortressFamily
        switch cityNumber {
        case 7, 12: family = .ember
        case 9, 13: family = .arcane
        case 15: family = .royal
        default: family = .frontier
        }

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
        return Battle(family: family, stage: stage)
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
        let completed = min(15, max(0, completedCityCount))
        let secured = completed == 0 ? [] : Array(1...completed)
        let starts = completed <= 1 ? [] : Array(1..<completed)
        return Map(
            securedCityNumbers: secured,
            caravanSegmentStartCityNumbers: Array(starts.prefix(2)),
            routeSixToSevenAssetName: completed >= 7
                ? "lk-map-route-6-7-repaired"
                : "lk-map-route-6-7-worn"
        )
    }
}
```

If `String(format:)` requires Foundation in this file, replace it with a tiny private formatter that emits `01...06`; do not add an animation-timing type solely to preserve the Foundation-free preference.

- [ ] **Step 7: Run focused tests and commit.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/LivingKingdomPresentationTests

git diff --check
git add Pyxis/LivingKingdomPresentation.swift PyxisTests/LivingKingdomPresentationTests.swift
git commit -m "feat: project Living Kingdom visual state"
```

---

## Task 2: Integrate Battle fortress/treatment and live FX on the existing enemy-city node

**Files:**
- Modify: `Pyxis/BattleScene.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`
- Optional modify: `PyxisTests/BattleSceneCoverageTests.swift` only for uncovered execution paths

**Interfaces:**
- Consumes: Task 1 `Battle` and `TransitionEffect`.
- Produces: correct static fortress/treatment plus at most one live transition child; semantic node name remains `enemy-city`.

- [ ] **Step 1: Add failing static identity tests.**

Add minimal DEBUG readbacks:

```swift
var livingKingdomFortressAssetNameForTesting: String? { ... }
var livingKingdomTreatmentAssetNameForTesting: String? { ... }
var livingKingdomTransitionEffectsForTesting: [LivingKingdomPresentation.TransitionEffect] { ... }
var livingKingdomTransitionChildCountForTesting: Int { ... }
```

Tests must assert:

- City 3 full → Frontier intact/no treatment;
- City 3 at 55/92 → damaged;
- City 3 at 23/92 → breached;
- City 7 → Ember treatment;
- City 9 → Arcane treatment;
- City 15 → Royal treatment;
- pending result → conquered;
- `firstNode(named: "enemy-city", in: scene)` still finds the fortress in every case.

- [ ] **Step 2: Add failing live-transition tests before production changes.**

Drive existing combat helpers and assert:

- damaged transition records no Living Kingdom FX;
- breached transition records one `.breach`;
- direct conquest records one `.collapse` only;
- restored pending scene records zero transition requests;
- layout refresh after breach does not append another effect;
- a no-layout redraw after a hit leaves one semantic enemy-city node and at most one FX child.

Keep the existing `battleSettingsPausesCityHitFeedbackUntilClose` test intact; it already proves code expects the `enemy-city` semantic name.

- [ ] **Step 3: Run focused Battle tests and confirm RED.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/BattleSceneTests
```

- [ ] **Step 4: Add the projected static presentation without renaming the node.**

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

Build the fortress with the projected asset but keep:

```swift
cityNode.name = BattleAssetName.enemyCity
```

Add one `livingKingdomTreatmentNode` at `GameUITheme.Z.background + 0.5`. Frontier hides it; themed families set texture.

- [ ] **Step 5: Reapply only texture/treatment from `redraw()`.**

`applyLivingKingdomStaticPresentation()` must:

1. read the current projection;
2. set `enemyCitySprite.texture = SKTexture(imageNamed: presentation.fortressAssetName)`;
3. leave `enemyCityNode.name` unchanged;
4. set/hide treatment texture;
5. run no action and create no new fortress node.

Call before the existing layout/HP-bar measurement. Mirror the backdrop position/scale onto the treatment in `layoutBattlefield`.

- [ ] **Step 6: Capture the old stage around the existing live model transaction.**

Immediately before `state.applyLiveSoldierAttacks(...)`:

```swift
let previousStage = livingKingdomBattlePresentation.stage
```

After the existing save/redraw path:

```swift
let currentStage = livingKingdomBattlePresentation.stage
if let effect = LivingKingdomPresentation.transitionEffect(
    from: previousStage,
    to: currentStage
) {
    playLivingKingdomTransition(effect)
}
```

Do not add `lastFortressStage` scene state.

- [ ] **Step 7: Implement one replaceable child FX player using enum metadata.**

```swift
private func playLivingKingdomTransition(
    _ effect: LivingKingdomPresentation.TransitionEffect
) {
    #if DEBUG
    livingKingdomTransitionEffectsForTestingStorage.append(effect)
    #endif
    guard !UIAccessibility.isReduceMotionEnabled,
          let city = enemyCityNode as? SKSpriteNode else { return }

    city.childNode(withName: "livingKingdomTransitionFX")?.removeFromParent()
    let textures = effect.frameNames.map(SKTexture.init(imageNamed:))
    guard let first = textures.first else { return }
    let fx = SKSpriteNode(texture: first)
    fx.name = "livingKingdomTransitionFX"
    fx.anchorPoint = CGPoint(x: 0.5, y: 0)
    fx.position = .zero
    fx.size = CGSize(width: 512, height: 512)
    fx.zPosition = 1
    city.addChild(fx)
    fx.run(.sequence([
        .animate(with: textures, timePerFrame: effect.secondsPerFrame),
        .removeFromParent()
    ]))
}
```

The static texture swap happens even with Reduce Motion; only frames are skipped.

- [ ] **Step 8: Verify colorize/pause/redraw coexistence.**

Add assertions around the existing city-hit test so:

- `city.action(forKey: "cityHitFeedback")` still runs on the same node after texture change;
- opening Settings still pauses that action and the FX child through parent pause;
- `refreshLayoutForCurrentEnvironment()` does not create a second FX request/child;
- `redraw(shouldLayout:false)` does not replace the semantic node.

- [ ] **Step 9: Run Battle tests/build and commit.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/BattleSceneTests \
  -only-testing:PyxisTests/BattleSceneCoverageTests

xcodebuild -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build

git diff --check
git add Pyxis/BattleScene.swift PyxisTests/BattleSceneTests.swift
# Add BattleSceneCoverageTests.swift only if it actually changed.
git commit -m "feat: render Living Kingdom battle progression"
```

---

## Task 3: Render the living conquered map without touching layout or hit targets

**Files:**
- Modify: `Pyxis/CountryMapScene.swift`
- Modify: `PyxisTests/CountryMapSceneTests.swift`

**Interfaces:**
- Consumes: `LivingKingdomPresentation.map(completedCityCount:)` and existing runtime `CountryMapLayout.cityPositions/displayedBackdropFrame`.
- Produces: one noninteractive decoration layer.

- [ ] **Step 1: Add failing early/partial/complete decoration tests.**

Add DEBUG readbacks:

```swift
var livingKingdomSecuredCityCountForTesting: Int { ... }
var livingKingdomCaravanCountForTesting: Int { ... }
var livingKingdomRoutePatchAssetNameForTesting: String? { ... }
```

Assert:

- completed 0/1 → zero caravans;
- completed 2 → one caravan;
- completed 3+ → exactly two, never more;
- secured count equals clamped completed count;
- 6 → worn patch; 7 → repaired patch;
- existing city center/hit frame remains unchanged with decoration;
- unsupported geometry clears decoration/actions.

- [ ] **Step 2: Run `CountryMapSceneTests` and confirm RED.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/CountryMapSceneTests
```

- [ ] **Step 3: Add one decoration layer and render key.**

```swift
private let livingKingdomLayer = SKNode()

private struct LivingKingdomMapRenderKey: Equatable {
    let completedCityCount: Int
    let backdropFrame: CGRect
}
private var lastLivingKingdomMapRenderKey: LivingKingdomMapRenderKey?
```

In `buildInterface`:

```swift
routeLayer.zPosition = 0
livingKingdomLayer.zPosition = 5
cityLayer.zPosition = 10
addChild(routeLayer)
addChild(livingKingdomLayer)
addChild(cityLayer)
```

Reset key + remove children in `clearLayoutGeometry()`.

- [ ] **Step 4: Render secured cities and 6→7 patch using existing runtime positions.**

```swift
let presentation = LivingKingdomPresentation.map(completedCityCount: state.completedCityCount)
let mapScale = layout.displayedBackdropFrame.width
    / CountryMapLayoutDefinition.country1.canonicalBackdropSize.width
```

For each secured city, create `lk-map-secured-city`, center at `layout.cityPositions[city]`, size `96 * mapScale` square.

For City 6→7:

```swift
if let start = layout.cityPositions[6], let end = layout.cityPositions[7] {
    let patch = SKSpriteNode(imageNamed: presentation.routeSixToSevenAssetName)
    patch.position = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
    patch.size = CGSize(width: 192 * mapScale, height: 192 * mapScale)
    livingKingdomLayer.addChild(patch)
}
```

Do not rotate or alter the route line.

- [ ] **Step 5: Render at most two deterministic caravans.**

For each projected start `n`:

```swift
let start = layout.cityPositions[n]!
let end = layout.cityPositions[n + 1]!
let caravan = SKSpriteNode(imageNamed: "lk-map-caravan")
caravan.size = CGSize(width: 128 * mapScale, height: 64 * mapScale)
caravan.position = start
caravan.zRotation = atan2(end.y - start.y, end.x - start.x)
let move = SKAction.move(to: end, duration: 5.0)
let reset = SKAction.run { [weak caravan] in caravan?.position = start }
caravan.run(.repeatForever(.sequence([move, reset])))
livingKingdomLayer.addChild(caravan)
```

A fixed index-based initial wait may stagger the two. No random speed or reverse route.

- [ ] **Step 6: Call render only when progress/layout changes.**

From `redraw()` after valid layout, compare `(completedCityCount, displayedBackdropFrame)` to the last key. City selection/transient feedback redraws must be decoration no-ops.

- [ ] **Step 7: Run map tests and commit.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/CountryMapSceneTests

git diff --check
git add Pyxis/CountryMapScene.swift PyxisTests/CountryMapSceneTests.swift
git commit -m "feat: make conquered map feel alive"
```

---

## Task 4: Make positive idle summaries compact/nonblocking and zero progress silent

**Files:**
- Modify: `Pyxis/CountryMapTransientFeedback.swift`
- Modify: `Pyxis/BattleScene.swift`
- Modify: `Pyxis/BuildingViewScene.swift`
- Modify: `PyxisTests/CountryMapTransientFeedbackTests.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`
- Modify: `PyxisTests/BuildingViewSceneTests.swift`

**Interfaces:**
- Consumes: existing `IdleProgressResult` and `CompactNumberFormatter`.
- Produces: truthful positive non-conquest summary and no zero-result reveal. This task does **not** change journey routing yet.

- [ ] **Step 1: Rewrite the two affected transient-feedback tests first.**

Replace `onlyFlavorDoesNotBlockScoutEntry` with an expectation that exactly `.flavor` and `.idleSummary` are nonblocking.

Replace `idleProjectsExistingStatusCopy` with positive-only semantics:

```swift
let result = KingdomGameState.IdleProgressResult(
    elapsedSeconds: 3_600,
    damageDealt: 1_234,
    conqueredCities: 0,
    goldEarned: 0
)
let feedback = try #require(CountryMapTransientFeedback.idle(result: result, state: state))
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
    case locked, completed, status, recoverableError, flavor, idleSummary

    var blocksScoutEntry: Bool {
        self != .flavor && self != .idleSummary
    }
}
```

`idle(result:state:)` returns nil unless elapsed > 0, damage > 0, and conquered == 0, then returns:

```swift
status-like timing + kind .idleSummary
text = "Buildings dealt \(CompactNumberFormatter.string(from: result.damageDealt)) idle damage."
```

Keep the existing method signature for minimal call-site churn even if `state` is no longer needed; remove the parameter only if every caller/test becomes cleaner in the same commit.

- [ ] **Step 3: Add Battle positive/zero tests and remove only the zero assignment.**

Keep the existing positive compact formatting. Change:

```swift
} else if result.damageDealt > 0 {
    feedbackText = "Buildings dealt \(CompactNumberFormatter.string(from: result.damageDealt)) idle damage."
} else {
    feedbackText = "No building damage while away."
}
```

to:

```swift
} else if result.damageDealt > 0 {
    feedbackText = "Buildings dealt \(CompactNumberFormatter.string(from: result.damageDealt)) idle damage."
}
```

Assert zero return preserves prior/default feedback.

- [ ] **Step 4: Add Camp positive/zero tests and compact formatting.**

In `applyIdleProgressFeedback`, preserve conquest handling for now, change positive copy to `CompactNumberFormatter`, and remove the zero assignment. No routing change in this task.

- [ ] **Step 5: Run focused suites and commit.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/CountryMapTransientFeedbackTests \
  -only-testing:PyxisTests/BattleSceneTests \
  -only-testing:PyxisTests/BuildingViewSceneTests

git diff --check
git add Pyxis/CountryMapTransientFeedback.swift Pyxis/BattleScene.swift Pyxis/BuildingViewScene.swift \
  PyxisTests/CountryMapTransientFeedbackTests.swift PyxisTests/BattleSceneTests.swift \
  PyxisTests/BuildingViewSceneTests.swift
git commit -m "feat: show truthful idle damage summaries"
```

---

## Task 5: Supersede Map stay-on-conquest only where HPA-478 needs the pending report

**Files:**
- Modify: `Pyxis/CountryMapScene.swift`
- Modify: `Pyxis/BuildingViewScene.swift`
- Modify: `PyxisTests/CountryMapSceneTests.swift`
- Modify: `PyxisTests/BuildingViewSceneTests.swift`
- Optional modify: `PyxisTests/GameViewControllerTests.swift` only if pending-first coverage is missing

**Interfaces:**
- Consumes: existing scene routing protocols and `pendingBattleResult`.
- Produces: immediate pending-report route for Map foreground/current-city idle conquest and Camp foreground idle conquest; **no Camp build/upgrade auto-route**.

- [ ] **Step 1: Rewrite the existing Map journey tests before changing production behavior.**

Change these current tests by name:

- `selectedCurrentCityReturnLeavesLethalIdleConquestPending` → expect `.battle` route once while pending result remains persisted;
- `countryMapFreshIdleConquestEmitsRewardThenCityOutcomeWithoutReplay` → expect one `.battle` route after the same `[goldReward, cityConquest]` feedback sequence; remove the `Next: ...` Map transient expectation because the report owns conquest;
- `countryMapFinalIdleConquestEmitsExactlyOneCountryOutcome` → expect one `.battle` route after `[goldReward, countryCompletion]` and no Map conquest transient.

Also add:

- layout-gate pause creates pending result but router count stays zero;
- `layoutGateWillResume` routes pending once;
- normal tab settlement that creates pending result still makes only its existing one route request.

These RED failures are intentional contract supersession, not regressions to preserve.

- [ ] **Step 2: Add a tiny scene-local Map pending route helper.**

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

This is not a new router; it is five-line reuse of the existing routing protocol.

- [ ] **Step 3: Route only the Map settlement cases that otherwise stay on Map.**

After save/feedback/redraw:

- `handleSceneWillEnterForeground`: if conquest/pending, call `routePendingConquestIfNeeded()`;
- current-city `requestEntry` path: when settlement leaves `stageStatus != .battleActive` and pending exists, apply existing fresh feedback then call the helper instead of returning on Map;
- `layoutGateWillResume`: after gate state is usable/redrawn, call helper if pending;
- `layoutGateWillPause`: **never route**.

Leave `requestGameplayTab`'s existing routing path untouched; it already requests a tab after settlement and the controller is pending-first.

- [ ] **Step 4: Add Camp foreground/gate route tests while locking build/upgrade stay-in-place.**

Tests must assert:

- foreground idle conquest → router receives `.battle` once;
- layout-gate pause → zero route; resume → one route if pending;
- build settlement conquest → pending result saved, existing reward/outcome feedback emitted, **router receives no request**;
- upgrade settlement conquest → same no-route contract;
- build/upgrade conquest does not set a duplicate `Buildings conquered ... Earned ...` / `Buildings conquered ...` feedback sentence;
- a later explicit Battle/tab request routes once and the controller's pending-first behavior can present the report.

- [ ] **Step 5: Keep Camp build/upgrade settlement local.**

For `.cityConqueredDuringSettlement` in `buildSelectedSlot` / `upgradeSelectedSlot`:

```swift
store.save(state)
closeFeedbackSettings(focusTarget: .systemDefault)
emitFreshOutcomeFeedback(goldEarned: goldEarned, conqueredCities: 1)
feedbackText = ""
```

Do **not** call the router here. The pending result stays until explicit Battle/tab navigation.

- [ ] **Step 6: Route only Camp foreground/gate idle conquest.**

Add a scene-local helper analogous to Map using `buildingViewSceneDidRequestGameplayTab(self, tab: .battle)`. Call it after foreground idle conquest and from `layoutGateWillResume` if pending. Do not call it from layout-gate pause or build/upgrade settlement.

- [ ] **Step 7: Re-run pending-first controller coverage.**

Search `GameViewControllerTests` first. If it already proves a pending result overrides preferred Camp/Map tabs, do not modify the controller or its tests. Otherwise add one test only; production controller stays unchanged.

- [ ] **Step 8: Run the high-risk affected suites and commit.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/CountryMapSceneTests \
  -only-testing:PyxisTests/BuildingViewSceneTests \
  -only-testing:PyxisTests/GameViewControllerTests

git diff --check
git add Pyxis/CountryMapScene.swift Pyxis/BuildingViewScene.swift \
  PyxisTests/CountryMapSceneTests.swift PyxisTests/BuildingViewSceneTests.swift
# Add GameViewControllerTests.swift only if it actually changed.
git commit -m "feat: route idle conquests to pending report"
```

---

## Task 6: Extend deterministic fixtures and finish visual/CI acceptance

**Files:**
- Modify: `Pyxis/ForgedVisualFixture.swift`
- Modify: `Pyxis/GameViewController.swift` **DEBUG block only if needed for return-damage hook**
- Modify: `PyxisTests/ForgedVisualFixtureTests.swift`
- Modify: `PyxisTests/GameViewControllerTests.swift` only for DEBUG fixture semantics if needed
- Modify: `PyxisUITests/PyxisUITests.swift`
- Local-only: `docs/visual-parity/living-kingdom/**`

**Interfaces:**
- Consumes: completed shipping implementation.
- Produces: deterministic acceptance states/evidence; no Release behavior.

- [ ] **Step 1: Add missing fixture cases using real maxima.**

Add:

```text
battle-damaged
battle-breached
battle-emberford
battle-runewatch
battle-crownspire
return-damage
```

State requirements:

```swift
// exact threshold fixtures use City 1 because maxHP == 20
battle-damaged: remainingHP = KingdomGameState.cityMaxPower(for: 1) * 3 / 5 // 12
battle-breached: remainingHP = KingdomGameState.cityMaxPower(for: 1) / 4     // 5
```

Landmark fixtures use `DevJumpState.make(city: 7/9/15)` at full HP.

`return-damage` seeds one building, a fixed background timestamp, and enough HP to remain non-conquered after a fixed foreground return.

- [ ] **Step 2: Extend fixture parser/state tests and semantic probes.**

For Battle without pending result, expose family/stage through existing DEBUG accessibility value. For Map, expose only secured/caravan/route-patch facts needed by UI assertions. `return-damage` must prove the compact visible copy.

Do not expose animation frames or serialize full state.

- [ ] **Step 3: Add the fixed-time return hook only in the existing DEBUG installer if required.**

```swift
if let returnDate = fixture.foregroundReturnDate,
   let battle = view.scene as? BattleScene {
    battle.sceneWillEnterForegroundForTesting(at: returnDate)
}
```

No production clock/routing change.

- [ ] **Step 4: Keep Scout thumbnail explicitly outside the fixture matrix.**

Landmark acceptance captures validate the Battle fortress/treatment. Do not add `CountryMapScoutCardNode` changes or assert a family-specific Scout thumbnail in this PR.

- [ ] **Step 5: Run fixture unit/UI tests.**

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
map                     -> early map
map-partial             -> partial map
map-country-complete    -> complete map
return-damage           -> positive idle summary
conquest-idle           -> idle conquest + one Continue
```

Store local evidence under ignored `docs/visual-parity/living-kingdom/runtime/`; attach/link it in the PR conversation, never `git add -f` it.

- [ ] **Step 7: Record a short live clip for behavior that screenshots cannot prove.**

Clip must show:

1. one live breached/conquered threshold crossing with the correct single FX;
2. eligible caravan motion;
3. an idle return leading to positive summary or pending report.

Resize/background/foreground during smoke and confirm no historical FX replay.

- [ ] **Step 8: Smoke compact phone and portrait iPad.**

Verify lanes, HP bar, milestone accent, map 44pt city targets, Scout/Attack, tabs, report/Continue, Camp, Settings, and no unexpected Camp navigation after build/upgrade conquest.

- [ ] **Step 9: Run full gates.**

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

Expected:

- no HPA-479 asset changes;
- no schema/model/layout-definition/CI changes;
- production `GameViewController` diff absent;
- `CountryMapScoutCardNode.swift` absent;
- local visual evidence not tracked.

Inspect Codecov after CI; if project/patch is below 90%, add focused tests for uncovered new lines.

- [ ] **Step 10: Commit fixture/acceptance code.**

```bash
git add Pyxis/ForgedVisualFixture.swift \
  PyxisTests/ForgedVisualFixtureTests.swift PyxisUITests/PyxisUITests.swift
# Add GameViewController.swift/GameViewControllerTests.swift only if the DEBUG return hook required them.
git commit -m "test: cover Living Kingdom visual acceptance"
```

Keep PR Draft until local visual evidence and CI/coverage are green.

---

## Final Self-Review Checklist

- [ ] Exact integer stage math is covered with real City 1 and City 3 maxima.
- [ ] City 11 is Frontier; family never comes from `CityDefenseTrait`.
- [ ] `TransitionEffect` owns all 12 frame names and both timings; all names resolve in tests.
- [ ] Enemy fortress semantic node name remains exactly `enemy-city` through texture changes.
- [ ] Treatment stays at `background + 0.5` using backdrop transform.
- [ ] Live skipped-stage hit plays at most one final-stage FX.
- [ ] `redraw(shouldLayout:false)`, resize, restore, and relaunch do not rebuild/replay Living Kingdom FX.
- [ ] Existing city colorize feedback and Settings pause still work with the FX child.
- [ ] Map decoration is noninteractive and does not alter 44pt city targets or route topology.
- [ ] At most two caravans use completed `n→n+1` primary segments.
- [ ] 6→7 patch changes at completed City 7.
- [ ] `.idleSummary` is nonblocking; zero/conquest return produces no Map idle summary.
- [ ] Historical Map no-auto-route tests/docs are explicitly superseded by HPA-478 for foreground/current-city idle conquest.
- [ ] Map gate pause never routes; resume routes a remaining pending result once.
- [ ] Camp foreground idle conquest routes to report, but build/upgrade settlement conquest does not auto-route.
- [ ] Camp build/upgrade conquest has no duplicate conquest/gold sentence.
- [ ] Existing pending-first `GameViewController` behavior is reused unchanged.
- [ ] Scout thumbnail remains generic `enemy-city` by explicit scope decision.
- [ ] No save/schema/economy/combat/layout-definition/art/CI changes.
- [ ] Full tests/lint/Debug+Release builds/Codecov ≥90% and visual evidence pass before Ready for review.
