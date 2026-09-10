# Living Kingdom Runtime Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate HPA-479's Living Kingdom production assets into Battle, Map, and truthful offline-return presentation without changing Pyxis gameplay, economy, saves, or runtime ownership.

**Architecture:** Add one pure `LivingKingdomPresentation` projection for fortress family/stage, live transition selection, and completed-map decoration. `BattleScene`, `CountryMapScene`, and `BuildingViewScene` remain the runtime owners of their existing state, layout, feedback, and routing; they consume the projection locally. Reuse the pending-first `GameViewController` route and the existing `ForgedVisualFixture` rather than adding services, manifests, routers, or snapshot infrastructure.

**Tech Stack:** Swift 5, SpriteKit/UIKit, Swift Testing, XCTest UI tests, Xcode asset catalogs, existing HPA-479 `lk-*` PNGs.

**Spec:** `docs/superpowers/specs/2026-09-10-living-kingdom-runtime-integration-design.md`

## Global Constraints

- This branch/PR is the **single HPA-478 implementation PR**. Tasks below are commits/checkpoints, never separate PRs.
- Baseline is `main` at `10036a88911aa055a406035154dd9e181f474701` after HPA-479 / PR #41.
- HPA-479's tracked art contract is `docs/superpowers/specs/2026-09-07-living-kingdom-art-pack-design.md` plus the landed `lk-*` assets/tests.
- `docs/visual-parity/living-kingdom/**` is local-only/gitignored. Generate evidence there, but do not force the large PNG/clip set back into git.
- Do not author or modify production art in this PR. Asset defects go back to art scope.
- Do not add save fields, migration code, economy/combat rules, timers, settlement owners, report/claim flows, route topology, or gameplay abilities.
- Keep the exact HP stages: `>60%` intact, `>25%...60%` damaged, `>0%...25%` breached, zero/pending conquered.
- Keep the exact city families: Frontier `1–6,8,10,11,14`; Ember `7,12`; Arcane `9,13`; Royal `15`.
- City 11 must remain Frontier.
- Live skipped-stage damage plays only the effect for the final stage reached: breached → breach, conquered → collapse.
- Restore/resize/relaunch applies static state and never replays historical breach/collapse or fresh reward feedback.
- Map decoration is derived from `completedCityCount`; max two decorative caravans; fixed repair is City 6→7.
- Positive idle copy is `Buildings dealt <CompactNumberFormatter value> idle damage.` No invented duration/gold/claim UI.
- Zero idle damage does not create a new return/reward reveal.
- Idle conquest from Battle/Map/Camp must use the existing pending `BattleResult` report and its one Continue action.
- `GameViewController.presentSceneForCurrentStage` remains the pending-first router; do not create a second router or protocol method.
- Keep existing 90% project/patch coverage gates; add tests rather than exclusions or threshold changes.
- Do not edit `project.pbxproj`, `.github/`, or `codecov.yml`.

## File Map

### Create

- `Pyxis/LivingKingdomPresentation.swift` — pure, deterministic presentation rules only.
- `PyxisTests/LivingKingdomPresentationTests.swift` — exact boundary/mapping/transition/map-projection tests.

### Modify

- `Pyxis/BattleScene.swift` — static fortress/theme integration, live breach/collapse playback, truthful zero-return behavior, DEBUG readback.
- `Pyxis/CountryMapScene.swift` — living-map decoration and pending-conquest routing after existing settlement paths.
- `Pyxis/CountryMapTransientFeedback.swift` — formatted nonblocking positive idle summary; nil for conquest/zero.
- `Pyxis/BuildingViewScene.swift` — formatted positive idle copy and pending-conquest routing after existing settlement paths.
- `Pyxis/ForgedVisualFixture.swift` — only missing deterministic visual states.
- `PyxisTests/BattleSceneTests.swift` and/or `PyxisTests/BattleSceneCoverageTests.swift` — runtime integration/coverage.
- `PyxisTests/CountryMapSceneTests.swift` — decoration, hit-target preservation, idle-conquest routing.
- `PyxisTests/CountryMapTransientFeedbackTests.swift` — idle-summary semantics/copy.
- `PyxisTests/BuildingViewSceneTests.swift` — idle copy/routing.
- `PyxisTests/ForgedVisualFixtureTests.swift` — new fixture parsing/state expectations.
- `PyxisTests/GameViewControllerTests.swift` only if an existing pending-first regression test needs an additional Map/Camp case; do not change production controller code.
- `PyxisUITests/PyxisUITests.swift` — deterministic capture/semantic cases.

### Must remain unchanged unless the PR documents a concrete discovered blocker

- `Pyxis/KingdomGameState.swift`
- `Pyxis/BattleCombatState.swift`
- `Pyxis/GameViewController.swift`
- `Pyxis/CountryMapLayout.swift`
- `Pyxis/CountryMapLayoutDefinition.swift`
- persistence/schema files
- HPA-479 `lk-*` imagesets
- CI/Codecov configuration

---

## Task 1: Add the pure Living Kingdom presentation projection

**Files:**
- Create: `Pyxis/LivingKingdomPresentation.swift`
- Create: `PyxisTests/LivingKingdomPresentationTests.swift`

**Interfaces:**
- Consumes: city number, remaining/max HP, pending-conquest boolean, completed-city count.
- Produces: `LivingKingdomPresentation.Battle`, `TransitionEffect?`, and `LivingKingdomPresentation.Map` used by Tasks 2–5.

- [ ] **Step 1: Write failing stage-boundary and pending-conquest tests.**

Start `PyxisTests/LivingKingdomPresentationTests.swift` with Swift Testing coverage equivalent to:

```swift
import Testing
@testable import Pyxis

@Suite("Living Kingdom presentation")
struct LivingKingdomPresentationTests {
    @Test(arguments: [
        (61, LivingKingdomPresentation.FortressStage.intact),
        (60, .damaged),
        (26, .damaged),
        (25, .breached),
        (1, .breached),
        (0, .conquered)
    ])
    func fortressStageUsesExactPercentBoundaries(
        remaining: Int,
        expected: LivingKingdomPresentation.FortressStage
    ) {
        let battle = LivingKingdomPresentation.battle(
            cityNumber: 1,
            remainingHP: remaining,
            maxHP: 100,
            hasPendingConquest: false
        )
        #expect(battle.stage == expected)
    }

    @Test
    func pendingConquestForcesConqueredPresentation() {
        let battle = LivingKingdomPresentation.battle(
            cityNumber: 1,
            remainingHP: 100,
            maxHP: 100,
            hasPendingConquest: true
        )
        #expect(battle.stage == .conquered)
    }
}
```

- [ ] **Step 2: Write failing exact city-family tests, including City 11.**

Use a table over all 15 cities, not only the landmarks:

```swift
let expected: [Int: LivingKingdomPresentation.FortressFamily] = [
    1: .frontier, 2: .frontier, 3: .frontier, 4: .frontier,
    5: .frontier, 6: .frontier, 7: .ember, 8: .frontier,
    9: .arcane, 10: .frontier, 11: .frontier, 12: .ember,
    13: .arcane, 14: .frontier, 15: .royal
]
for (city, family) in expected {
    #expect(LivingKingdomPresentation.battle(
        cityNumber: city,
        remainingHP: 100,
        maxHP: 100,
        hasPendingConquest: false
    ).family == family)
}
```

Also assert exact asset strings for one Frontier and all three themed families, and that Frontier has no battlefield-treatment asset.

- [ ] **Step 3: Write failing transition-selection tests.**

Cover direct/skipped transitions:

```swift
#expect(LivingKingdomPresentation.transitionEffect(from: .intact, to: .damaged) == nil)
#expect(LivingKingdomPresentation.transitionEffect(from: .intact, to: .breached) == .breach)
#expect(LivingKingdomPresentation.transitionEffect(from: .damaged, to: .breached) == .breach)
#expect(LivingKingdomPresentation.transitionEffect(from: .intact, to: .conquered) == .collapse)
#expect(LivingKingdomPresentation.transitionEffect(from: .breached, to: .conquered) == .collapse)
#expect(LivingKingdomPresentation.transitionEffect(from: .conquered, to: .conquered) == nil)
```

- [ ] **Step 4: Write failing map-projection tests.**

Lock the smallest deterministic policy:

```swift
#expect(LivingKingdomPresentation.map(completedCityCount: 0).securedCityNumbers == [])
#expect(LivingKingdomPresentation.map(completedCityCount: 1).caravanSegmentStartCityNumbers == [])
#expect(LivingKingdomPresentation.map(completedCityCount: 2).caravanSegmentStartCityNumbers == [1])
#expect(LivingKingdomPresentation.map(completedCityCount: 4).caravanSegmentStartCityNumbers == [1, 2])
#expect(LivingKingdomPresentation.map(completedCityCount: 15).caravanSegmentStartCityNumbers.count == 2)
#expect(LivingKingdomPresentation.map(completedCityCount: 6).routeSixToSevenAssetName == "lk-map-route-6-7-worn")
#expect(LivingKingdomPresentation.map(completedCityCount: 7).routeSixToSevenAssetName == "lk-map-route-6-7-repaired")
```

Also test negative and >15 completion counts clamp rather than generate invalid city numbers.

- [ ] **Step 5: Run the new suite and confirm RED.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/LivingKingdomPresentationTests
```

Expected: compile/test failure because `LivingKingdomPresentation` does not exist.

- [ ] **Step 6: Implement the minimum pure projection.**

Use concrete enums/value types only. A valid minimal shape is:

```swift
enum LivingKingdomPresentation {
    enum FortressFamily: String, CaseIterable, Equatable {
        case frontier, ember, arcane, royal
    }

    enum FortressStage: String, CaseIterable, Equatable {
        case intact, damaged, breached, conquered
    }

    enum TransitionEffect: Equatable { case breach, collapse }

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
        Battle(
            family: family(for: cityNumber),
            stage: stage(
                remainingHP: remainingHP,
                maxHP: maxHP,
                hasPendingConquest: hasPendingConquest
            )
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
        let completed = min(15, max(0, completedCityCount))
        let secured = completed > 0 ? Array(1...completed) : []
        let eligibleStarts = completed > 1 ? Array(1..<completed) : []
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

Keep `family` and `stage` private helpers. For stage thresholds, compare ratios without introducing a persisted/raw percentage. Guard `maxHP` with `max(1, maxHP)`; clamp negative remaining HP to conquered.

- [ ] **Step 7: Add an asset-resolution assertion to the projection tests.**

For every family/stage pair generated by the projection, assert `UIImage(named: battle.fortressAssetName) != nil`; for themed families assert treatment resolution. This proves runtime-generated strings match the already-landed HPA-479 contract without duplicating the PNG dimension/alpha tests from PR #41.

- [ ] **Step 8: Run focused tests and commit.**

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

## Task 2: Integrate static fortress stages and landmark treatments into BattleScene

**Files:**
- Modify: `Pyxis/BattleScene.swift` (`BattleAssetName`, `buildBattlefield`, `layoutBattlefield`, `redraw`, DEBUG extension)
- Modify: `PyxisTests/BattleSceneTests.swift`

**Interfaces:**
- Consumes: `LivingKingdomPresentation.battle(...)` from Task 1.
- Produces: correct static fortress texture and optional themed battlefield treatment on every scene/layout refresh. No animation yet.

- [ ] **Step 1: Add failing scene tests for static asset selection.**

Use existing in-memory `KingdomGameStore` scene helpers and add DEBUG readbacks for only what the tests need:

```swift
var livingKingdomFortressAssetNameForTesting: String? { ... }
var livingKingdomTreatmentAssetNameForTesting: String? { ... }
```

Tests must prove at least:

- City 3 at full HP → `lk-city-frontier-intact`, no treatment;
- City 3 at 60% → `lk-city-frontier-damaged`;
- City 3 at 25% → `lk-city-frontier-breached`;
- City 7 → Ember fortress + `lk-battlefield-ember`;
- City 9 → Arcane fortress + `lk-battlefield-arcane`;
- City 15 → Royal fortress + `lk-battlefield-royal`;
- a pending result → `*-conquered` immediately on scene creation.

- [ ] **Step 2: Run the focused Battle scene tests and confirm RED.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/BattleSceneTests
```

Expected: new Living Kingdom readbacks/behavior missing.

- [ ] **Step 3: Replace the static `enemy-city` construction with the projected fortress.**

Add a small helper inside `BattleScene`:

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

In `buildBattlefield`, construct the city using `livingKingdomBattlePresentation.fortressAssetName`. Keep `anchorPoint = (0.5, 0)`, `enemyCityNode`, existing fallback behavior, HP bar, milestone accent, gate geometry, and `fitBattleNode` ownership unchanged.

- [ ] **Step 4: Add exactly one treatment sprite.**

Add a stored `livingKingdomTreatmentNode = SKSpriteNode()` to the existing environment. Configure once in `buildBattlefield`:

```swift
livingKingdomTreatmentNode.name = "livingKingdomBattlefieldTreatment"
livingKingdomTreatmentNode.anchorPoint = CGPoint(x: 0.5, y: 0.5)
livingKingdomTreatmentNode.zPosition = GameUITheme.Z.background + 0.5
livingKingdomTreatmentNode.blendMode = .alpha
environmentLayer.addChild(livingKingdomTreatmentNode)
```

Do not add a treatment for Frontier. For a themed family set the texture from the projected asset and show the node; otherwise hide it.

- [ ] **Step 5: Reapply the static presentation from `redraw()` and mirror backdrop layout.**

Add one private `applyLivingKingdomStaticPresentation()` that:

1. sets the enemy `SKSpriteNode.texture` from the projected fortress name;
2. updates its `name` to the asset name for diagnostics/tests;
3. sets/hides the treatment texture;
4. does not run any action.

Call it before layout in `redraw()` so HP-driven texture changes are in place before `layoutCityHPBar`/milestone geometry is measured.

In `layoutBattlefield`, after the existing backdrop aspect-fill transform, mirror its `position` and `xScale/yScale` onto the treatment. Because HPA-479 treatments are also 864×1821, do not introduce a new scaling formula.

- [ ] **Step 6: Add a no-replay static-refresh regression.**

At this checkpoint there is no Living Kingdom FX yet; assert repeated `refreshLayoutForCurrentEnvironment()` / `redraw` retains the same asset/treatment and does not create a transition child. This becomes the restore/resize base invariant for Task 3.

- [ ] **Step 7: Run Battle tests and build.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/BattleSceneTests

xcodebuild -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

- [ ] **Step 8: Commit.**

```bash
git add Pyxis/BattleScene.swift PyxisTests/BattleSceneTests.swift
git commit -m "feat: render Living Kingdom battle states"
```

---

## Task 3: Play live breach/collapse FX without replaying restored history

**Files:**
- Modify: `Pyxis/BattleScene.swift` (`applyCombatResult`, FX helper, lifecycle/report DEBUG readback)
- Modify: `PyxisTests/BattleSceneTests.swift`
- Modify: `PyxisTests/BattleSceneCoverageTests.swift` only if the executable effect path needs focused coverage there

**Interfaces:**
- Consumes: `LivingKingdomPresentation.transitionEffect(from:to:)`.
- Produces: at most one six-frame effect per newly observed live stage transition; zero effect for layout/restore/foreground static reapplication.

- [ ] **Step 1: Add failing live-transition integration tests.**

Add a DEBUG counter/readback such as:

```swift
var livingKingdomTransitionEffectsForTesting: [LivingKingdomPresentation.TransitionEffect] { ... }
```

The readback records only effects actually requested by the runtime helper; it is not persisted and is DEBUG-only.

Drive existing `advanceCombatForTesting`/combat helpers so tests prove:

- a hit ending in `.damaged` records no Living Kingdom effect;
- a hit ending in `.breached` records one `.breach`;
- a direct hit to conquest records one `.collapse`, not `.breach` + `.collapse`;
- a restored pending-result scene records zero transition effects while showing conquered art;
- layout refresh after a live breach does not append another effect.

Keep existing city hit/conquest feedback assertions intact.

- [ ] **Step 2: Run the focused tests and confirm RED.**

Use the same serial `xcodebuild test` destination as Task 2.

- [ ] **Step 3: Capture the old stage before model mutation.**

In `applyCombatResult(_:)`, immediately before:

```swift
let damageResult = state.applyLiveSoldierAttacks(result.soldierAttacks)
```

capture:

```swift
let previousStage = livingKingdomBattlePresentation.stage
```

After the existing mutation/save/redraw path, compute:

```swift
let currentStage = livingKingdomBattlePresentation.stage
```

and ask the pure projection for one effect. Do not maintain `lastFortressStage` as scene state; explicit live mutation boundaries are enough and avoid restore/replay bugs.

- [ ] **Step 4: Implement one concrete effect player.**

Use a fixed child/action name such as `livingKingdomTransitionFX`. For `.breach`, load frames `lk-fx-breach-01...06` with `0.05` seconds per frame; for `.collapse`, load `lk-fx-collapse-01...06` with `0.07` seconds per frame.

Attach the temporary `SKSpriteNode` directly to the enemy fortress when it is an `SKSpriteNode`:

```swift
let fx = SKSpriteNode(texture: textures[0])
fx.name = "livingKingdomTransitionFX"
fx.anchorPoint = CGPoint(x: 0.5, y: 0)
fx.position = .zero
fx.size = CGSize(width: 512, height: 512)
fx.zPosition = 1
enemyCitySprite.addChild(fx)
```

Because the 512×512 FX is a child of the 512×540 fortress, it inherits the exact fortress scale and shake/pause transform required by HPA-479. Run `SKAction.animate` followed by removal. Replace an existing same-name child before playback so effects never stack.

Guard `UIAccessibility.isReduceMotionEnabled`: static state still changes, extra frame playback is skipped.

- [ ] **Step 5: Keep the existing conquest transaction ordering.**

Do not move or delay:

- `state.applyLiveSoldierAttacks`;
- `store.save(state)`;
- fresh feedback emission;
- `redraw`;
- `presentPendingConquestReport`;
- Continue acknowledgment/routing.

Start the optional collapse FX after static conquered art is applied; the report may present immediately over it. The effect must never become a prerequisite for report presentation.

- [ ] **Step 6: Verify Settings pause remains inherited.**

The city node is already paused by `synchronizeBattlefieldActionPause()`. Add/adjust a focused test only if current coverage does not prove the child FX pauses with it; do not add a second pause controller.

- [ ] **Step 7: Run focused tests, full Battle tests, and commit.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/BattleSceneTests \
  -only-testing:PyxisTests/BattleSceneCoverageTests

git diff --check
git add Pyxis/BattleScene.swift PyxisTests/BattleSceneTests.swift PyxisTests/BattleSceneCoverageTests.swift
git commit -m "feat: animate live fortress transitions"
```

If `BattleSceneCoverageTests.swift` did not need a change, omit it from `git add` rather than touching it for symmetry.

---

## Task 4: Render secured cities, the 6→7 repair, and at most two caravans on Country Map

**Files:**
- Modify: `Pyxis/CountryMapScene.swift`
- Modify: `PyxisTests/CountryMapSceneTests.swift`

**Interfaces:**
- Consumes: `LivingKingdomPresentation.map(completedCityCount:)` and existing `CountryMapLayout.cityPositions/displayedBackdropFrame`.
- Produces: one noninteractive living-map layer. Does not change `CountryMapLayout`, route topology, city nodes, or hit targets.

- [ ] **Step 1: Add failing decoration tests at early/partial/complete progress.**

Add minimal DEBUG readbacks, for example:

```swift
var livingKingdomSecuredCityCountForTesting: Int { ... }
var livingKingdomCaravanCountForTesting: Int { ... }
var livingKingdomRoutePatchAssetNameForTesting: String? { ... }
var livingKingdomDecorationFramesForTesting: [CGRect] { ... }
```

Using existing phone map-layout test helpers, assert:

- completed `0/1` → no caravan;
- completed `2` → one caravan;
- completed `3+` → two caravans, never more;
- secured overlay count equals completed count;
- completed 6 uses `lk-map-route-6-7-worn`;
- completed 7 uses `lk-map-route-6-7-repaired`;
- existing `cityHitArea` centers/44pt hit targets are unchanged before vs after decoration;
- unsupported geometry clears all decoration and actions.

- [ ] **Step 2: Run `CountryMapSceneTests` and confirm RED.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/CountryMapSceneTests
```

- [ ] **Step 3: Add one decoration layer between routes and cities.**

In `buildInterface()`:

```swift
routeLayer.zPosition = 0
livingKingdomLayer.zPosition = 5
cityLayer.zPosition = 10
```

Add the layer once. Children remain normal noninteractive SpriteKit nodes; never give them `countryMapCity-*` names.

- [ ] **Step 4: Add a tiny render key so ordinary redraws do not restart caravans.**

A private value like this is sufficient:

```swift
private struct LivingKingdomMapRenderKey: Equatable {
    let completedCityCount: Int
    let backdropFrame: CGRect
}
```

Store `lastLivingKingdomMapRenderKey`. Reset it and `livingKingdomLayer.removeAllChildren()` in `clearLayoutGeometry()`.

- [ ] **Step 5: Render secured-city overlays from existing runtime city positions.**

Inside one `renderLivingKingdomMapIfNeeded(layout:)` helper:

```swift
let presentation = LivingKingdomPresentation.map(
    completedCityCount: state.completedCityCount
)
let mapScale = layout.displayedBackdropFrame.width /
    CountryMapLayoutDefinition.country1.canonicalBackdropSize.width
```

For each secured city with an existing `layout.cityPositions[city]`, create `lk-map-secured-city`, center it on the city, and size it to `96 * mapScale` square. The existing circle, number, conquered marker, Scout selection, and 44pt hit target stay in `cityLayer` above it.

- [ ] **Step 6: Render the fixed City 6→7 worn/repaired patch.**

Use existing runtime positions:

```swift
let start = layout.cityPositions[6]!
let end = layout.cityPositions[7]!
let midpoint = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
```

Create the projected `lk-map-route-6-7-*` sprite at `midpoint`, size `192 * mapScale` square, and do not rotate it. The art is already authored in canonical map orientation.

- [ ] **Step 7: Render at most two deterministic caravans.**

For every projected start city `n`, use `layout.cityPositions[n]` and `[n + 1]`. Create `lk-map-caravan`, size `128×64 * mapScale`, orient it with:

```swift
caravan.zRotation = atan2(end.y - start.y, end.x - start.x)
```

Move from start to end with one fixed duration such as `5.0` seconds and `SKAction.repeatForever`; a fixed `0.8 * index` initial wait is enough to stagger two caravans. At action completion, reset position to start before repeating. No random speed, reverse traffic, collision, branch route, or simulation state.

- [ ] **Step 8: Call the render helper from `redraw()` after a valid layout exists.**

The render key makes city selection/transient-feedback redraws no-ops for decoration. A changed completed count or backdrop frame rebuilds the layer, which covers conquest progress and resize.

- [ ] **Step 9: Run map tests and verify city interaction regression coverage.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/CountryMapSceneTests
```

- [ ] **Step 10: Commit.**

```bash
git add Pyxis/CountryMapScene.swift PyxisTests/CountryMapSceneTests.swift
git commit -m "feat: make conquered map feel alive"
```

---

## Task 5: Make offline return truthful and route all idle conquests to the existing report

**Files:**
- Modify: `Pyxis/CountryMapTransientFeedback.swift`
- Modify: `Pyxis/CountryMapScene.swift`
- Modify: `Pyxis/BuildingViewScene.swift`
- Modify: `Pyxis/BattleScene.swift`
- Modify: `PyxisTests/CountryMapTransientFeedbackTests.swift`
- Modify: `PyxisTests/CountryMapSceneTests.swift`
- Modify: `PyxisTests/BuildingViewSceneTests.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`
- Optional modify: `PyxisTests/GameViewControllerTests.swift` only for an extra pending-first regression

**Interfaces:**
- Consumes: existing `IdleProgressResult`, scene routing protocols, `pendingBattleResult`, and `CompactNumberFormatter`.
- Produces: nonblocking formatted positive-damage reveal; no zero-result reveal; one pending report for every idle conquest path.

- [ ] **Step 1: Change `CountryMapTransientFeedback` tests first.**

Add `.idleSummary` semantics and lock:

```swift
let positive = KingdomGameState.IdleProgressResult(
    elapsedSeconds: 3_600,
    damageDealt: 1_234,
    conqueredCities: 0,
    goldEarned: 0
)
let feedback = try #require(CountryMapTransientFeedback.idle(
    result: positive,
    state: state
))
#expect(feedback.kind == .idleSummary)
#expect(feedback.kind.blocksScoutEntry == false)
#expect(feedback.text == "Buildings dealt 1.2K idle damage.")
```

Also assert:

- `elapsedSeconds == 0` → nil;
- positive elapsed but `damageDealt == 0` → nil;
- `conqueredCities > 0` → nil, because the pending report owns conquest.

- [ ] **Step 2: Make the Map feedback helper pass.**

Add `.idleSummary` to `Kind`; make `blocksScoutEntry` false for `.flavor` and `.idleSummary`. `idle(result:state:)` becomes positive-nonconquest-only and uses `CompactNumberFormatter.string(from:)`.

Do not change `.status`, locked/completed errors, or Scout flavor behavior.

- [ ] **Step 3: Add failing Battle zero/positive/conquest foreground tests.**

Using the existing `sceneWillEnterForegroundForTesting(at:)` seam, assert:

- positive damage sets the exact compact copy;
- zero damage does not replace default/prior feedback with `No building damage while away.`;
- idle conquest still creates/presents the existing pending report exactly once and the Living Kingdom fortress readback is conquered;
- restored pending report produces no fresh transition/reward effect.

- [ ] **Step 4: Make Battle zero-result behavior minimal.**

In `handleSceneWillEnterForeground(at:)`, keep the existing positive compact copy and conquest path, but remove the zero-result assignment:

```swift
} else if result.damageDealt > 0 {
    feedbackText = "Buildings dealt \(CompactNumberFormatter.string(from: result.damageDealt)) idle damage."
}
```

Do not change settlement, saving, report origin, or reward emission.

- [ ] **Step 5: Add failing Map route-to-report tests.**

Reuse the existing `CountryMapSceneRouting` test spy. Test these existing settlement entry paths:

1. foreground return conquers → router receives `.battle` exactly once;
2. current-city `requestEntry` settles into conquest → router receives `.battle` instead of staying on Map;
3. normal tab request that settles conquest still routes once and pending-first controller behavior remains compatible;
4. layout-gate pause may create pending result but does **not** route while the gate is being applied; `layoutGateWillResume` routes once if pending remains;
5. positive non-conquest shows `.idleSummary` and Attack/Scout entry remains enabled;
6. zero result shows no new idle summary.

- [ ] **Step 6: Implement one private pending-route helper in `CountryMapScene`.**

Do not change the routing protocol:

```swift
@discardableResult
private func routeToPendingConquestIfNeeded() -> Bool {
    guard state.pendingBattleResult != nil,
          !isRoutingToBattle,
          let router else {
        return false
    }
    isRoutingToBattle = true
    guard router.countryMapSceneDidRequestGameplayTab(self, tab: .battle) else {
        isRoutingToBattle = false
        return false
    }
    return true
}
```

Use it only after save/redraw on foreground conquest/current-city entry, and on layout-gate resume. Leave normal tab routing unchanged so its already-correct pending-first behavior remains one path.

Do not invoke it inside `layoutGateWillPause`; avoid controller routing reentrancy while the gate is being installed.

- [ ] **Step 7: Add failing Camp route/copy tests.**

Reuse the existing `BuildingViewSceneRouting` spy. Cover:

- foreground positive damage → compact copy;
- foreground zero damage → no new return message;
- foreground conquest → existing router `.battle` exactly once;
- `buildSelectedSlot` / `upgradeSelectedSlot` returning `.cityConqueredDuringSettlement` → save/emit then existing router `.battle` once;
- layout-gate pause defers route; resume routes pending result once;
- normal tab request remains pending-first without a new route layer.

- [ ] **Step 8: Implement the same scene-local pending-route rule in Camp.**

Add a private helper analogous to Map but calling `buildingViewSceneDidRequestGameplayTab`. Do not extract a shared routing service for two five-line methods.

Update `applyIdleProgressFeedback`:

- conquest: emit existing fresh outcome feedback; no duplicate gold/reward text needed because the report follows;
- positive damage: exact compact copy;
- zero: no new feedback assignment.

After build/upgrade settlement conquest, save and emit exactly as today, then route to the pending report. Do not call `completeCurrentCity`, award gold, or acknowledge the result again.

- [ ] **Step 9: Re-run the existing pending-first controller tests.**

If `GameViewControllerTests` already proves `pendingBattleResult` overrides preferred tabs, leave production/controller files untouched. Add one small regression test only if the Map/Camp path is not currently covered.

- [ ] **Step 10: Run all affected tests serially.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/CountryMapTransientFeedbackTests \
  -only-testing:PyxisTests/CountryMapSceneTests \
  -only-testing:PyxisTests/BuildingViewSceneTests \
  -only-testing:PyxisTests/BattleSceneTests \
  -only-testing:PyxisTests/GameViewControllerTests
```

- [ ] **Step 11: Commit.**

```bash
git add Pyxis/CountryMapTransientFeedback.swift \
  Pyxis/CountryMapScene.swift Pyxis/BuildingViewScene.swift Pyxis/BattleScene.swift \
  PyxisTests/CountryMapTransientFeedbackTests.swift \
  PyxisTests/CountryMapSceneTests.swift PyxisTests/BuildingViewSceneTests.swift \
  PyxisTests/BattleSceneTests.swift PyxisTests/GameViewControllerTests.swift
git commit -m "feat: reveal truthful idle outcomes"
```

Omit unchanged optional files from the commit.

---

## Task 6: Extend deterministic fixtures and complete visual/CI acceptance

**Files:**
- Modify: `Pyxis/ForgedVisualFixture.swift`
- Modify: `Pyxis/GameViewController.swift` **DEBUG fixture block only if needed for fixed-time return-damage triggering**
- Modify: `PyxisTests/ForgedVisualFixtureTests.swift`
- Modify: `PyxisTests/GameViewControllerTests.swift` for DEBUG fixture semantics if needed
- Modify: `PyxisUITests/PyxisUITests.swift`
- Local-only generated: `docs/visual-parity/living-kingdom/**` (gitignored)

**Interfaces:**
- Consumes: shipping scenes and existing `-pyxis-forged-fixture` launch seam.
- Produces: reproducible visual states and semantic probes; no Release behavior.

- [ ] **Step 1: Add failing fixture parse/state tests for only the missing matrix.**

Add raw-value cases:

```text
battle-damaged
battle-breached
battle-emberford
battle-runewatch
battle-crownspire
return-damage
```

Keep existing `battle`, `conquest-live`, `conquest-idle`, `map`, `map-partial`, and `map-country-complete` as the other acceptance states.

State expectations:

- `battle-damaged`: Frontier City 3 with exactly 60% max HP;
- `battle-breached`: Frontier City 3 with exactly 25% max HP;
- `battle-emberford`: `DevJumpState.make(city: 7)`, active/intact;
- `battle-runewatch`: City 9, active/intact;
- `battle-crownspire`: City 15, active/intact;
- `return-damage`: active Battle with a building, high enough remaining HP to avoid conquest, fixed background timestamp, and a fixed foreground timestamp that produces positive damage.

- [ ] **Step 2: Implement fixture states without adding a new fixture framework.**

Reuse `DevJumpState.make(city:)`, existing city building state helpers, and the current `ForgedVisualFixture` switch. A tiny optional property such as:

```swift
var foregroundReturnDate: Date? {
    self == .returnDamage
        ? Date(timeIntervalSince1970: 4_600)
        : nil
}
```

is sufficient if `return-damage` seeds background time `1_000`.

- [ ] **Step 3: Trigger only the return-damage lifecycle in the existing DEBUG installer.**

Inside the existing `#if DEBUG` fixture installation path, after scene presentation:

```swift
if let returnDate = fixture.foregroundReturnDate,
   let battle = view.scene as? BattleScene {
    battle.sceneWillEnterForegroundForTesting(at: returnDate)
}
```

Do not alter Release routing or add a clock abstraction.

- [ ] **Step 4: Extend fixture accessibility semantics minimally.**

For Battle without a pending result, include the projected family/stage so native captures can prove they show the requested state. For Map, add secured/caravan/route-patch counts/names only if needed by the existing semantic UI assertions. For `return-damage`, assert the visible feedback text contains the compact damage copy.

Do not expose frame-by-frame FX internals or large serialized state.

- [ ] **Step 5: Run fixture unit/UI semantic tests.**

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

- [ ] **Step 6: Capture the 393×852 matrix using the existing fixture flow.**

Generate local evidence for:

```text
battle                  -> Frontier intact
battle-damaged          -> Frontier damaged
battle-breached         -> Frontier breached
conquest-live or idle   -> Frontier conquered under pending report
battle-emberford        -> Ember family/treatment
battle-runewatch        -> Arcane family/treatment
battle-crownspire       -> Royal family/treatment
map                     -> early conquered map
map-partial             -> partial conquered map
map-country-complete    -> complete conquered map
return-damage           -> positive idle return summary
conquest-idle           -> idle conquest + one Continue
```

Store generated PNGs under ignored `docs/visual-parity/living-kingdom/runtime/`. Do not `git add -f` them.

- [ ] **Step 7: Compare real captures against the HPA-479 intent.**

Use the tracked art spec and the actual landed assets as authoritative. If local corrected reference plates from HPA-479 are still available, use side-by-side/overlay comparison. Record any unavoidable capture variance in the PR conversation; do not silently compensate by changing game geometry or mixing new art production into HPA-478.

Reject the integration if any of these regress:

- three battle lanes/readability;
- city HP bar and milestone accent;
- Map city numbers/conquered markers/hit targets;
- Scout card and Attack interaction;
- Camp/Settings usability;
- pending report/Continue;
- safe areas on compact phone or portrait iPad.

- [ ] **Step 8: Record one short live clip.**

The clip must show:

1. a live hit crossing into breached or conquest and the one relevant FX sequence;
2. a map with eligible caravan motion;
3. an idle return, preferably positive damage then pending conquest if convenient.

Also manually resize/background/foreground once to verify historical FX does not replay and no effect blocks controls.

- [ ] **Step 9: Smoke a compact supported phone and one portrait iPad.**

Verify clipping, lanes, safe areas, Map 44pt city targets, report/Continue, tabs, Camp, and Settings. Do not add device-specific layout branches unless a real supported geometry fails existing layout contracts.

- [ ] **Step 10: Run full serial unit/UI tests, lint, Debug build, and Release build.**

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
```

Expected: tests/lint/builds green; no `docs/visual-parity/living-kingdom/**` binaries in tracked status; no HPA-479 asset modifications; no schema/CI changes.

- [ ] **Step 11: Review the final diff for scope and coverage.**

```bash
git diff --name-only main...HEAD
git diff --stat main...HEAD
```

Expected production change set is concentrated in:

```text
Pyxis/LivingKingdomPresentation.swift
Pyxis/BattleScene.swift
Pyxis/CountryMapScene.swift
Pyxis/CountryMapTransientFeedback.swift
Pyxis/BuildingViewScene.swift
Pyxis/ForgedVisualFixture.swift
```

plus focused tests/docs and, only if required for DEBUG fixture triggering, a `#if DEBUG`-only `GameViewController.swift` change.

Explicitly inspect Codecov after CI. If patch coverage misses 90%, test the uncovered new branches; do not lower the gate or exclude files.

- [ ] **Step 12: Commit fixture/acceptance code and leave the PR Draft until evidence/CI are green.**

```bash
git add Pyxis/ForgedVisualFixture.swift Pyxis/GameViewController.swift \
  PyxisTests/ForgedVisualFixtureTests.swift PyxisTests/GameViewControllerTests.swift \
  PyxisUITests/PyxisUITests.swift
git commit -m "test: cover Living Kingdom visual acceptance"
```

Omit unchanged optional files. Local captures/clips are attached to the PR conversation, not committed.

---

## Final self-review checklist

Before marking the draft ready for review, verify each requirement against the diff:

- [ ] Stage thresholds are exact at 60% and 25%; no persisted visual stage.
- [ ] City-family table is exact and City 11 is Frontier.
- [ ] Theme treatment uses z `background + 0.5` and same backdrop transform.
- [ ] FX uses only HPA-479 frames/timings, inherits fortress scale, and skipped stages do not queue effects.
- [ ] Restore/resize/relaunch paths never invoke the live transition helper.
- [ ] Map secured overlays derive from completion count and do not own/touch hit targets.
- [ ] 6→7 worn/repaired cutoff is completion of City 7.
- [ ] Caravan count is `0...2`, deterministic, noninteractive, and uses only completed primary segments.
- [ ] Positive idle damage is compact-formatted; zero result creates no new return reveal.
- [ ] Map positive idle summary is nonblocking.
- [ ] Battle/Map/Camp idle conquest all land on the existing pending report with one Continue.
- [ ] No duplicate reward, acknowledgment, save owner, timer, or report was introduced.
- [ ] No `KingdomGameState`, `BattleCombatState`, layout-definition, schema, production router, CI, Codecov, or art change slipped in without a documented blocker.
- [ ] Existing economy, 8-hour idle cap, 1/10 building rate, at-most-one-city idle conquest, navigation restrictions, and milestone behavior remain test-green.
- [ ] 393×852 matrix, live clip, compact phone, and portrait iPad acceptance have been reviewed.
- [ ] Full CI and unchanged 90% project/patch coverage gates are green.

## Execution boundary

The planning commit is complete when this plan and its paired spec are on the HPA-478 branch and the pull request is open as Draft. Runtime implementation starts by Task 1 on **this same PR**; do not create another implementation PR or child tickets.
