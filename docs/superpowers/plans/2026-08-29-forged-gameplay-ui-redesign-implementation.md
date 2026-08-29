# Forged Gameplay UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Pyxis's Battle, Camp, Map, Conquest, and Settings chrome with the supplied Forged mobile UI while preserving the real game rules and proving mock parity against deterministic simulator states.

**Architecture:** Keep `BattleScene`, `BuildingViewScene`, and `CountryMapScene` separate, with `GameViewController` as the only production router. Add one shared Forged surface primitive and one shared Battle/Camp/Map tab bar; keep screen-specific geometry in pure CoreGraphics layouts and screen-specific rendering in focused SpriteKit nodes. Add one DEBUG-only closed fixture enum for reproducible parity screenshots; do not extract combat into a global runtime or create a generic UI/fixture framework.

**Tech Stack:** Swift 5, SpriteKit, UIKit, CoreGraphics, Swift Testing, XCTest UI tests, Xcode/iOS Simulator, existing Pyxis models and persistence.

**Spec:** `docs/superpowers/specs/2026-08-29-forged-gameplay-ui-redesign-design.md`

## Global Constraints

- Implement the runtime redesign in **one PR**; the tasks below are logical commits, not separate PRs.
- Treat `3b.png`, `2b.png`, `2c.png`, `2d.png`, and `2e.png` as visual references at 393×852, not as gameplay data.
- All visible values must come from existing game/combat/catalog/result/preference state. Do not hardcode mock rewards, costs, unit counts, unlocks, timers, multipliers, or the mock's green `+6` income sample.
- Keep the three existing scenes. Do not add a persistent shared combat runtime or a single all-purpose gameplay scene.
- Preserve Battle's living-manual-squad guard before Camp/Map routing.
- Preserve combat, active/idle building production, persistence, lifecycle, layout gates, feedback, Settings pause/focus/accessibility behavior, milestone treatment, and conquest restoration.
- Add no save field or migration, balance change, new gameplay content, landscape support, SwiftUI, third-party package, custom font, generated-asset pipeline, router framework, component registry, or fixture registry.
- Camp must expose all five existing `BuildingType` cases, even though the prototype wheel visually samples four.
- Conquest must adapt to live/idle, optional MVP, zero achievements, and country completion without filler data.
- Every primary control and tab hit target is at least 44×44 points.
- The DEBUG fixture activates only through `-pyxis-forged-fixture` and compiles out of Release.
- Do not edit `project.pbxproj`; synchronized groups discover new files.
- Run simulator tests with `-parallel-testing-enabled NO`.
- Keep Codecov project and patch statuses at or above the current 90% target with zero threshold.
- Do not mark the implementation PR ready until a real 393×852 mock/real/50%-overlay parity board is attached.

## File Map

**Create**

- `Pyxis/ForgedSurfaceNode.swift`
- `Pyxis/GameplayTabBarNode.swift`
- `Pyxis/BattleChromeLayout.swift`
- `Pyxis/BattleHUDNode.swift`
- `Pyxis/CampChromeLayout.swift`
- `Pyxis/CampSelectionNode.swift`
- `Pyxis/ForgedVisualFixture.swift` (`#if DEBUG` body)
- focused test files for each new production file

**Modify**

- `Pyxis/GameUITheme.swift`
- `Pyxis/GameViewController.swift`
- `Pyxis/BattleScene.swift`
- `Pyxis/BuildingViewScene.swift`
- `Pyxis/CountryMapLayout.swift`
- `Pyxis/CountryMapScene.swift`
- `Pyxis/CountryMapScoutCardContent.swift`
- `Pyxis/CountryMapScoutCardLayout.swift`
- `Pyxis/CountryMapScoutCardNode.swift`
- `Pyxis/ConquestReportContent.swift`
- `Pyxis/ConquestReportLayout.swift`
- `Pyxis/ConquestReportNode.swift`
- `Pyxis/FeedbackSettingsLayout.swift`
- `Pyxis/FeedbackSettingsNode.swift`
- corresponding existing scene/layout/node/controller tests
- `PyxisUITests/PyxisUITests.swift`
- `CLAUDE.md`

---

## Task 1: Add the minimal shared Forged material and tab bar

**Files**

- Modify: `Pyxis/GameUITheme.swift`
- Create: `Pyxis/ForgedSurfaceNode.swift`
- Create: `Pyxis/GameplayTabBarNode.swift`
- Create: `PyxisTests/ForgedSurfaceNodeTests.swift`
- Create: `PyxisTests/GameplayTabBarNodeTests.swift`

**Interfaces**

```swift
enum GameplayTab: CaseIterable, Equatable { case battle, camp, map }

final class ForgedSurfaceNode: SKNode {
    enum Style: Equatable { case panel, selected, primaryAction, disabled, success, danger }
    func apply(frame: CGRect, cornerRadius: CGFloat, style: Style, showsRivets: Bool)
}

final class GameplayTabBarNode: SKNode {
    struct Content: Equatable {
        let selected: GameplayTab
        let showsCampAttention: Bool
    }
    func apply(content: Content, frame: CGRect)
    func tab(at point: CGPoint) -> GameplayTab?
}
```

- [ ] **Step 1: Write RED node-tree and tab-contract tests**

```swift
@MainActor
@Test("Forged surfaces and tabs reapply without duplicating children")
func sharedChromeIsStable() {
    let surface = ForgedSurfaceNode()
    let frame = CGRect(x: 16, y: 20, width: 361, height: 58)
    surface.apply(frame: frame, cornerRadius: 12, style: .primaryAction, showsRivets: true)
    let firstCount = surface.nodeCountForTesting
    surface.apply(frame: frame, cornerRadius: 12, style: .primaryAction, showsRivets: true)
    #expect(surface.nodeCountForTesting == firstCount)
    #expect(surface.rivetCountForTesting == 4)

    let tabs = GameplayTabBarNode()
    tabs.apply(content: .init(selected: .battle, showsCampAttention: true), frame: frame)
    #expect(tabs.orderedTabsForTesting == [.battle, .camp, .map])
    #expect(tabs.hitFramesForTesting.values.allSatisfy { $0.width >= 44 && $0.height >= 44 })
}
```

- [ ] **Step 2: Run the new suites and confirm RED**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/ForgedSurfaceNodeTests \
  -only-testing:PyxisTests/GameplayTabBarNodeTests
```

- [ ] **Step 3: Add only shared tokens with at least two consumers**

Add dark-iron, raised-iron, gold-edge, amber, hot-amber, muted, success, and danger colors plus `horizontalMargin = 16`, `minimumHitSize = 44`, `panelCornerRadius = 12`, and `tabBarHeight = 72`. Keep existing theme values during migration; do not create a spacing/type registry.

- [ ] **Step 4: Implement one fixed `ForgedSurfaceNode` tree**

Build shadow, plate, top-highlight, and four optional rivet nodes once in `init`. `apply` only changes paths/colors/positions; it never appends children. Use `SKShapeNode` layers only—no shaders, generated textures, or new assets.

- [ ] **Step 5: Implement exactly three reusable tab bundles**

Create one surface/icon/title/attention bundle per `GameplayTab` in `init`. Divide the supplied frame into three equal hit frames. Use safe SF Symbols (`shield.fill`, `hammer.fill`, `map.fill`), keep labels visible if an icon cannot load, and show the attention dot only on Camp when requested.

- [ ] **Step 6: Re-run and confirm GREEN; commit**

```bash
git add Pyxis/GameUITheme.swift Pyxis/ForgedSurfaceNode.swift \
  Pyxis/GameplayTabBarNode.swift PyxisTests/ForgedSurfaceNodeTests.swift \
  PyxisTests/GameplayTabBarNodeTests.swift
git commit -m "feat: add Forged gameplay chrome foundation"
```

---

## Task 2: Route tabs through the existing scene controller

**Files**

- Modify: `Pyxis/GameViewController.swift`
- Modify: `Pyxis/BattleScene.swift`
- Modify: `Pyxis/BuildingViewScene.swift`
- Modify: `Pyxis/CountryMapScene.swift`
- Modify: their existing controller/scene tests

**Interfaces**

Replace the old scene-specific World/Build/Battle callbacks with tab requests:

```swift
protocol BattleSceneRouting: AnyObject {
    func battleScene(_ scene: BattleScene, didRequest tab: GameplayTab)
    func battleScene(_ scene: BattleScene, didRequestLayoutGate reason: AppLayoutGateReason)
}

protocol BuildingViewSceneRouting: AnyObject {
    @discardableResult
    func buildingViewScene(_ scene: BuildingViewScene, didRequest tab: GameplayTab) -> Bool
}

protocol CountryMapSceneRouting: AnyObject {
    @discardableResult
    func countryMapScene(_ scene: CountryMapScene, didRequest tab: GameplayTab) -> Bool
    func countryMapScene(_ scene: CountryMapScene, didRequestLayoutGate reason: AppLayoutGateReason)
}
```

- [ ] **Step 1: Write RED routing tests**

Cover Battle→Camp→Map→Battle, country-complete requests remaining on Map, and Camp/Map state handoffs. Add this Battle regression:

```swift
fixture.scene.tapDeployForTesting()
fixture.scene.requestGameplayTabForTesting(.camp)
#expect(fixture.router.requestedTabs.isEmpty)
#expect(fixture.scene.feedbackTextForTesting == "Finish the current squad before building.")
#expect(fixture.scene.manualLivingSoldierCountForTesting == 1)

fixture.scene.requestGameplayTabForTesting(.map)
#expect(fixture.router.requestedTabs.isEmpty)
#expect(fixture.scene.feedbackTextForTesting == "Finish the current squad before viewing world.")
#expect(fixture.scene.manualLivingSoldierCountForTesting == 1)
```

- [ ] **Step 2: Run controller/Battle/Camp/Map suites and confirm RED**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/GameViewControllerTests \
  -only-testing:PyxisTests/BattleSceneTests \
  -only-testing:PyxisTests/BuildingViewSceneTests \
  -only-testing:PyxisTests/CountryMapSceneTests
```

- [ ] **Step 3: Add one controller-private tab switch**

```swift
private func presentGameplayTab(_ tab: GameplayTab, in view: SKView) {
    let state = store.load()
    switch tab {
    case .battle:
        guard state.stageStatus == .battleActive || state.pendingBattleResult != nil else {
            presentCountryMapScene(in: view)
            return
        }
        presentBattleScene(in: view)
    case .camp:
        guard state.stageStatus == .battleActive, state.pendingBattleResult == nil else {
            presentCountryMapScene(in: view)
            return
        }
        presentBuildingViewScene(in: view)
    case .map:
        presentCountryMapScene(in: view)
    }
}
```

Battle keeps its transient-roster checks before calling the router. Camp reuses its current idle-resolution/save handoff before Battle or Map. Map's Battle action retains current/unlocked entry semantics; Map→Camp is allowed only for an already active city and does not call `startCityFromMap(_:)`.

- [ ] **Step 4: Remove superseded protocol methods, update all fake routers, re-run GREEN, commit**

```bash
git add Pyxis/GameViewController.swift Pyxis/BattleScene.swift \
  Pyxis/BuildingViewScene.swift Pyxis/CountryMapScene.swift \
  PyxisTests/GameViewControllerTests.swift PyxisTests/BattleSceneTests.swift \
  PyxisTests/BuildingViewSceneTests.swift PyxisTests/CountryMapSceneTests.swift
git commit -m "refactor: route gameplay tabs through existing scenes"
```

---

## Task 3: Build the real-state Battle projection, geometry, and HUD node

**Files**

- Create: `Pyxis/BattleChromeLayout.swift`
- Create: `Pyxis/BattleHUDNode.swift`
- Create: `PyxisTests/BattleChromeLayoutTests.swift`
- Create: `PyxisTests/BattleHUDNodeTests.swift`

**Interfaces**

```swift
struct BattleChromeLayout: Equatable {
    let resourceFrame: CGRect
    let settingsFrame: CGRect
    let cityHeaderFrame: CGRect
    let cityHPFrame: CGRect
    let objectiveFrame: CGRect
    let laneFrames: [LaneDefenseRole: CGRect] // exposed + fortified
    let unitFrames: [SoldierType: CGRect]      // exactly five
    let deployFrame: CGRect
    let manualCountFrame: CGRect
    let tabFrame: CGRect
    let battlefieldFrame: CGRect
    static func compute(_ input: Input) -> BattleChromeLayout?
}

struct BattleHUDContent: Equatable {
    enum UnitAvailability: Equatable {
        case available(level: Int)
        case unbuilt
        case locked(unlocksAtCity: Int)
    }
    static func project(state: KingdomGameState,
                        selectedUnit: SoldierType,
                        manualCount: Int) -> BattleHUDContent
}

enum BattleHUDAction: Equatable {
    case selectUnit(SoldierType)
    case showUnitRequirement(SoldierType)
    case deploy
    case selectTab(GameplayTab)
    case openSettings
    case consumed
}
```

- [ ] **Step 1: Write RED layout tests at 375×667, 393×852, and 768×1024**

At the reference size assert: 16-point side margins, five 56-point medallions, 361-point Deploy/tab width, minimum hit sizes, all required chrome inside safe content, and `battlefieldFrame` vertically between unit controls and lane chips with no overlap.

- [ ] **Step 2: Write RED projection tests for all real unit states**

Use City 5 with Barracks + Archery built:

```swift
let content = BattleHUDContent.project(state: state, selectedUnit: .infantry, manualCount: 3)
let units = Dictionary(uniqueKeysWithValues: content.units.map { ($0.type, $0) })
#expect(units[.infantry]?.availability == .available(level: 2))
#expect(units[.archer]?.availability == .available(level: 1))
#expect(units[.cavalry]?.availability == .unbuilt)
#expect(units[.mage]?.availability == .locked(unlocksAtCity: 8))
#expect(units[.siege]?.availability == .locked(unlocksAtCity: 11))
#expect(content.manualCountText == "3 / 10")
```

Assert multiplier text comes from `currentCityDefenseTrait.damageMultiplier(for:)`. Cover `.ready`, `.saveFor`, and `.noAction` recommendation projections.

- [ ] **Step 3: Run the two new suites and confirm RED**

- [ ] **Step 4: Implement one pure Battle geometry authority**

Build from safe area inward: tab → Deploy → medallions → battlefield → exposed/fortified chips → objective → HP/title → resource/settings. At 393×852 use tab `CGRect(x: 16, y: 34, width: 361, height: 72)` and Deploy `CGRect(x: 16, y: 114, width: 361, height: 58)`. Return nil when required controls fall outside safe content, medallions/hit frames fall below 44 points, or battlefield height falls below the tested floor.

- [ ] **Step 5: Implement the projection only from existing APIs**

For each `SoldierType`, find its `BuildingType`; use `manualSoldierLevel(for:)` for `.available`, `isBuildingTypeUnlocked(_:)` for `.unbuilt`, and `unlockCity(for:)` for `.locked`. Map `RecommendedCampRecommendation` directly. Build OPEN from `exposedLane`, HELD from `fortifiedLane`, and use existing lane-role multipliers. `canDeploy` requires an available selected unit, active stage, and manual count below the cap.

- [ ] **Step 6: Implement one reusable HUD node**

Build labels/icons/surfaces, five medallion bundles, two lane chips, objective strip, Deploy, and one `GameplayTabBarNode` once. The node receives only `BattleHUDContent` + layout and returns `BattleHUDAction`; it never receives store/router/combat/feedback. Reuse the existing first walk-frame asset and `SoldierAnimationGeometry` body crop for portraits.

- [ ] **Step 7: Re-run GREEN and commit**

```bash
git add Pyxis/BattleChromeLayout.swift Pyxis/BattleHUDNode.swift \
  PyxisTests/BattleChromeLayoutTests.swift PyxisTests/BattleHUDNodeTests.swift
git commit -m "feat: add Forged Battle chrome units"
```

---

## Task 4: Cut `BattleScene` over without changing combat

**Files**

- Modify: `Pyxis/BattleScene.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`
- Modify: `PyxisTests/BattleSceneCoverageTests.swift`

- [ ] **Step 1: Write RED mounted-scene tests**

Assert real gold/city/HP/recommendation/unit state reaches the HUD. Tap an available medallion then Deploy and assert the existing spawn path records one manual deployment, emits `.manualDeployment`, and updates the same combat roster. Tap unbuilt/locked medallions and assert invalid-action feedback without spawning or routing. Assert report and Settings modal touch priority remains above the new HUD.

- [ ] **Step 2: Write RED geometry tests**

At reference phone, smallest supported portrait, and iPad fixtures assert `BattlefieldLayout.frame` is contained in `BattleChromeLayout.battlefieldFrame`, required battlefield objects do not intersect Deploy/tabs, and HUD reapply/resize does not duplicate nodes.

- [ ] **Step 3: Run Battle suites and confirm RED**

- [ ] **Step 4: Install one `BattleHUDNode` and map its actions**

```swift
switch battleHUDNode.action(at: point) {
case .selectUnit(let type):
    selectManualSoldierType(type)
case .showUnitRequirement(let type):
    showUnitRequirement(type)
case .deploy:
    spawnSoldier()
case .selectTab(let tab):
    requestGameplayTab(tab)
case .openSettings:
    openFeedbackSettings()
case .consumed:
    break
case nil:
    break
}
```

`showUnitRequirement` emits `.invalidAction` and shows either `Unlock <unit> at City N.` or `Build <building> in Camp first.` from real model data.

- [ ] **Step 5: Drive existing `BattlefieldLayout` from the new battlefield reservation**

Compute `BattleChromeLayout` from current size/safe area; pass its battlefield top/bottom into existing battlefield constraints. If the chrome layout fails, clear hit frames and request `.unsupportedGeometry` through the existing router.

- [ ] **Step 6: Delete replaced dropdown/Spawn/World/Build nodes and helpers**

Keep battlefield, combat tick, effects, feedback tooltip, milestone, conquest, Settings, lifecycle, and persistence code. Delete only old normal-control nodes, names, dropdown state/layout, and duplicate navigation paths after tests prove replacement coverage.

- [ ] **Step 7: Re-run GREEN and commit**

```bash
git add Pyxis/BattleScene.swift PyxisTests/BattleSceneTests.swift \
  PyxisTests/BattleSceneCoverageTests.swift
git commit -m "feat: apply Forged Battle HUD"
```

---

## Task 5: Replace Camp's action panel with radial build and inspector flows

**Files**

- Create: `Pyxis/CampChromeLayout.swift`
- Create: `Pyxis/CampSelectionNode.swift`
- Create: `PyxisTests/CampChromeLayoutTests.swift`
- Create: `PyxisTests/CampSelectionNodeTests.swift`
- Modify: `Pyxis/BuildingViewScene.swift`
- Modify: `PyxisTests/BuildingViewSceneTests.swift`

**Interfaces**

```swift
enum CampBuildOptionState: Equatable {
    case available(cost: Int)
    case unaffordable(cost: Int)
    case locked(unlocksAtCity: Int)
    case capped(maximum: Int)
}

enum CampSelectionAction: Equatable {
    case build(BuildingType)
    case upgrade
    case selectTab(GameplayTab)
    case consumed
}
```

- [ ] **Step 1: Write RED pure tests**

At 393×852 assert all five `BuildingType` option frames fit at 44 points or larger and clear the tab bar. Cover available/unaffordable/locked/capped states and an occupied inspector with real type, soldier, level, lot, cost, and recommendation emphasis.

- [ ] **Step 2: Write RED scene mutation tests**

Tap one valid radial option and inspector Upgrade; assert existing build/upgrade methods mutate/save once, preserve current feedback, close/update selection correctly, and retain pending conquest when settlement conquers the city. Verify `.ready` highlights the real action, `.saveFor` highlights but disables it, and `.noAction` adds no false emphasis.

- [ ] **Step 3: Run Camp suites and confirm RED**

- [ ] **Step 4: Implement a pure selection projection**

For an empty selected slot, generate options in `BuildingType.allCases` order with priority locked → capped → affordable available → unaffordable, using existing unlock/cost/count APIs. For an occupied slot, compute upgrade cost and affordability using existing APIs. Reuse the one `RecommendedCampRecommendation` action to mark the matching slot/type/kind.

- [ ] **Step 5: Implement one Camp geometry authority and one renderer**

`CampChromeLayout` owns header, scenic reservation, selected-lot overlay, five radial frames, inspector, Upgrade, feedback, and tab frames. It may use two arcs/rows near screen edges but may not omit a type or shrink a hit target. `CampSelectionNode` renders/reuses option bundles and inspector and returns actions only.

- [ ] **Step 6: Cut `BuildingViewScene` over**

Keep scenic backdrop, all 25 lot bundles/positions, `selectedSlot`, current build/upgrade methods, lifecycle settlement, store, feedback, Settings precedence, and conquest behavior. Remove the old build palette, recommendation row, Upgrade/Battle buttons, and action panel after the new node covers them. Successful build keeps the slot selected so the inspector appears.

- [ ] **Step 7: Re-run GREEN and commit**

```bash
git add Pyxis/CampChromeLayout.swift Pyxis/CampSelectionNode.swift \
  Pyxis/BuildingViewScene.swift PyxisTests/CampChromeLayoutTests.swift \
  PyxisTests/CampSelectionNodeTests.swift PyxisTests/BuildingViewSceneTests.swift
git commit -m "feat: apply Forged Camp interactions"
```

---

## Task 6: Expand Map into a selected-city Forged card

**Files**

- Modify: `Pyxis/CountryMapLayout.swift`
- Modify: `Pyxis/CountryMapScene.swift`
- Modify: `Pyxis/CountryMapScoutCardContent.swift`
- Modify: `Pyxis/CountryMapScoutCardLayout.swift`
- Modify: `Pyxis/CountryMapScoutCardNode.swift`
- Modify: all existing Map layout/scene/card/acceptance tests

**Content contract**

```swift
enum CountryMapScoutCardContent: Equatable {
    enum State: Equatable { case attackable, current, completed, locked, countryComplete }
    struct City: Equatable {
        let cityNumber: Int
        let displayTitle: String
        let defenseTrait: CityDefenseTrait
        let exposedLane: BattleLane
        let favorableTypes: [SoldierType]
        let disadvantagedTypes: [SoldierType]
        let goldReward: Int?
        let flavorText: String
        let state: State
    }
    case city(City)
    case countryComplete(countryNumber: Int, finalCityName: String)
    static func project(from state: KingdomGameState,
                        selectedCity: Int) -> CountryMapScoutCardContent
}
```

- [ ] **Step 1: Write RED content tests for attackable/current/completed/locked/complete**

Selection must project authored identity/trait/lanes/real multipliers without mutating state. Reward is present only when a future conquest reward is meaningful.

- [ ] **Step 2: Write RED geometry tests**

Extend the existing phone/pad matrix. At 393×852 assert resource/settings, country title, 15 pips, illustrated map, large card, March, and tabs are contained and non-overlapping; all existing city hit frames/routes remain in the illustrated region. Keep existing horizontal-safe-area and invalid-authored-data failure tests.

- [ ] **Step 3: Write RED scene interaction tests**

Tapping any city changes only scene-local `selectedCityNumber`. Locked/completed selection leaves the store equal and disables March. Tapping disabled primary action uses existing feedback. Attackable/current March delegates once through existing `startCityFromMap(_:)` or return-to-Battle behavior. Flavor remains a non-blocking overlay that excludes an enabled March frame.

- [ ] **Step 4: Run all Map suites and confirm RED**

- [ ] **Step 5: Extend existing layout/content/node authorities**

Do not add a parallel Map card system. `CountryMapLayout` owns broad regions and pips; `CountryMapScoutCardLayout` owns only the card interior. Rebuild the existing node's base/overlay layers with Forged surfaces, authored title/reward/trait, favorable/weak portraits + real multiplier text, exposed lane, and state label (`MARCH`, `RETURN`, `COMPLETED`, `LOCKED`). Disabled states keep visual action copy but `attackHitFrame = nil`.

- [ ] **Step 6: Add scene-local selection and tab handling**

Default to final city for country complete, otherwise `unlockedMapCityNumber ?? cityNumberInCountry`. City taps select and redraw only. The card action performs existing entry/current routing; tab actions use Task 2 protocols.

- [ ] **Step 7: Re-run GREEN and commit**

```bash
git add Pyxis/CountryMapLayout.swift Pyxis/CountryMapScene.swift \
  Pyxis/CountryMapScoutCardContent.swift Pyxis/CountryMapScoutCardLayout.swift \
  Pyxis/CountryMapScoutCardNode.swift PyxisTests/CountryMapLayoutTests.swift \
  PyxisTests/CountryMapSceneTests.swift PyxisTests/CountryMapScoutCardContentTests.swift \
  PyxisTests/CountryMapScoutCardLayoutTests.swift \
  PyxisTests/CountryMapScoutCardNodeTests.swift \
  PyxisTests/CountryMapScoutCardAcceptanceTests.swift
git commit -m "feat: apply Forged selected-city map"
```

---

## Task 7: Replace Conquest rows with adaptive real-stat tiles

**Files**

- Modify: `Pyxis/ConquestReportContent.swift`
- Modify: `Pyxis/ConquestReportLayout.swift`
- Modify: `Pyxis/ConquestReportNode.swift`
- Modify: `Pyxis/BattleScene.swift`
- Modify: existing Conquest content/layout/node and Battle integration tests

**Content contract**

```swift
struct ConquestReportContent: Equatable {
    enum StatKind: Equatable { case mvp, battleTime, buildings, sentLost }
    struct StatTile: Equatable {
        let kind: StatKind
        let title: String
        let value: String
        let soldierType: SoldierType?
    }
    enum AchievementChip: Equatable { case favorableUnit, exposedLane }
    let title: String
    let rewardText: String
    let statTiles: [StatTile]
    let achievementChips: [AchievementChip]
}
```

- [ ] **Step 1: Write RED content tests for four exact shapes**

- live + MVP → MVP, battle time, sent/lost
- live without MVP → battle time, sent/lost
- idle + MVP → MVP, Buildings, sent/lost
- idle without MVP → Buildings, sent/lost

Use complete `BattleResult` fixtures and assert no empty/filler tile. Cover zero/both achievements.

- [ ] **Step 2: Write RED layout/node tests**

Support exactly two or three equal-width centered tiles and zero through two named chips. No chip reservation for zero achievements. Keep March On at least 44 points, reward as gold-effect anchor, and country-complete frame outside the report panel but within safe content. Assert reapply/restore does not duplicate node bundles.

- [ ] **Step 3: Run Conquest/Battle report suites and confirm RED**

- [ ] **Step 4: Replace only the display projection**

Keep `BattleResult` coding/finalization unchanged. Build typed tiles with existing compact number and duration formatting. Achievement titles are `FAVOURED` and `OPEN LANE`. Do not invent an MVP or third tile.

- [ ] **Step 5: Extend the existing pure layout and reusable node**

Change layout input to `statTileCount` (2...3) and `achievementChipCount` (0...2). Keep three reusable tile bundles and two chip bundles, hiding unused ones. Change visible Continue copy to `MARCH ON` while preserving hit API, acknowledge/save/route behavior, disabled transition window, fresh/restored origin semantics, and finale reservation.

- [ ] **Step 6: Re-run GREEN and commit**

```bash
git add Pyxis/ConquestReportContent.swift Pyxis/ConquestReportLayout.swift \
  Pyxis/ConquestReportNode.swift Pyxis/BattleScene.swift \
  PyxisTests/ConquestReportContentTests.swift PyxisTests/ConquestReportLayoutTests.swift \
  PyxisTests/ConquestReportNodeTests.swift PyxisTests/BattleSceneTests.swift
git commit -m "feat: apply Forged conquest report"
```

---

## Task 8: Restyle Settings as the existing controller's bottom sheet

**Files**

- Modify: `Pyxis/FeedbackSettingsLayout.swift`
- Modify: `Pyxis/FeedbackSettingsNode.swift`
- Modify: existing Settings layout/node/controller and scene-modal tests

**Layout contract**

```swift
struct FeedbackSettingsLayout: Equatable {
    let scrimFrame: CGRect
    let sheetFrame: CGRect
    let handleFrame: CGRect
    let soundRowFrame: CGRect
    let hapticsRowFrame: CGRect
    let doneFrame: CGRect
}
```

- [ ] **Step 1: Write RED bottom-sheet tests**

At 393×852 with top 59/bottom 34 assert the sheet spans scene width, anchors at bottom safe inset, contains two ≥52-point rows and a ≥48-point Done action, and has no row overlap. Keep invalid/non-finite/small-geometry tests.

- [ ] **Step 2: Write RED node/controller tests**

Assert exactly two icon/title/switch-track/thumb rows and one Done action. Enabled thumb is right/success, disabled is left/muted. Row centers still return existing toggle actions, Done returns `.close`, persistence remains independent, and accessibility values remain `On`/`Off` even though visual state uses switches.

- [ ] **Step 3: Run Settings suites and confirm RED**

- [ ] **Step 4: Change only layout and rendering**

Keep `FeedbackSettingsController`, preference store, adapter, action enum, focus restoration, and scene pause logic. Render one Forged sheet, two Forged rows, static SF Symbol icons, SpriteKit switch tracks/thumbs, and one primary Done surface. The handle is decorative only; do not add drag behavior or `UISwitch`.

- [ ] **Step 5: Re-run Settings plus Battle/Camp/Map modal-precedence tests; commit**

```bash
git add Pyxis/FeedbackSettingsLayout.swift Pyxis/FeedbackSettingsNode.swift \
  PyxisTests/FeedbackSettingsLayoutTests.swift PyxisTests/FeedbackSettingsNodeTests.swift \
  PyxisTests/FeedbackSettingsControllerTests.swift PyxisTests/BattleSceneTests.swift \
  PyxisTests/BuildingViewSceneTests.swift PyxisTests/CountryMapSceneTests.swift
git commit -m "feat: apply Forged settings sheet"
```

---

## Task 9: Add parity fixtures, UI smoke, comparison evidence, and final gates

**Files**

- Create: `Pyxis/ForgedVisualFixture.swift`
- Create: `PyxisTests/ForgedVisualFixtureTests.swift`
- Modify: `Pyxis/GameViewController.swift`
- Modify: `PyxisTests/GameViewControllerTests.swift`
- Modify: `PyxisUITests/PyxisUITests.swift`
- Create: `docs/visual-parity/forged-ui/README.md`
- Modify: `CLAUDE.md`

**Fixture contract**

```swift
#if DEBUG
enum ForgedVisualFixture: String, CaseIterable {
    case battle
    case battleBlocked = "battle-blocked"
    case campEmpty = "camp-empty"
    case campOccupied = "camp-occupied"
    case map
    case mapCountryComplete = "map-country-complete"
    case conquestLive = "conquest-live"
    case conquestIdle = "conquest-idle"

    static let argument = "-pyxis-forged-fixture"
    static let freezeCombatArgument = "-pyxis-freeze-combat"

    static func requested(in arguments: [String]) -> ForgedVisualFixture?
    static func freezesCombat(in arguments: [String]) -> Bool
    var initialTab: GameplayTab { get }
    func makeState() -> KingdomGameState
}
#endif
```

- [ ] **Step 1: Write RED fixture/controller tests**

Pin the closed raw-value list. Verify no/unknown argument leaves the store untouched. Verify each valid argument normalizes to its intended surface and routes through normal scene constructors. Conquest fixtures have pending results; Map fixture has three completed cities and City 4 attackable; country-complete fixture has all 15 complete. Freeze affects only the DEBUG Battle update guard.

Use deterministic fixture values:

- Battle: City 3, 4,200 gold, Barracks Lv2 + Archery Lv1.
- Camp empty: City 5, 1,000 gold, empty current grid.
- Camp occupied: City 5, 1,000 gold, six authored occupied slots.
- Map: `.cityConqueredPendingMap`, three completed, City 4 unlocked.
- Conquest live: City 3, +640, 74s, Infantry MVP, 6 sent/1 lost, both achievements.
- Conquest idle: City 3, +640, Buildings tile, no MVP, zero achievements.

Construct all states with normal model initializers; add no fixture file format or mutable builder.

- [ ] **Step 2: Run fixture/controller suites and confirm RED**

- [ ] **Step 3: Apply the explicit fixture before normal initial routing**

```swift
#if DEBUG
if let fixture = ForgedVisualFixture.requested(in: ProcessInfo.processInfo.arguments) {
    store.save(fixture.makeState())
    presentGameplayTab(fixture.initialTab, in: view)
    return
}
#endif
presentInitialScene(in: view)
```

In `BattleScene.update`, an explicit freeze argument returns before combat advancement; normal DEBUG launches are unchanged. Release must contain no fixture marker.

- [ ] **Step 4: Add one coordinate-based 393×852 UI smoke with screenshot attachments**

Launch `battle-blocked` + freeze, capture Battle, tap reference Deploy center `(0.50, 0.832)`, tap reference Map-tab center `(0.806, 0.918)`, and assert the app stays foreground. Relaunch `camp-occupied`, `map`, `conquest-live`, and `conquest-idle`, capturing each surface. Use `XCTAttachment(screenshot:)`, set a stable name, and `.keepAlways`. The UI test does not compare pixels; scene tests own semantic assertions.

- [ ] **Step 5: Create the mandatory parity record**

Create `docs/visual-parity/forged-ui/README.md` with columns: State, Mock, Real, 50% overlay, Deliberate discrepancy. Attach real board PNGs to the implementation PR rather than committing duplicate large binaries.

Minimum evidence:

- Battle normal
- Battle locked/unbuilt
- Battle blocked tab
- Camp radial
- Camp inspector
- Camp unavailable option
- Map attackable
- Map locked/completed
- Map country complete
- Conquest live with MVP
- Conquest idle without MVP
- Settings with one toggle off

Review in this order: safe-area/geometry; hierarchy; typography/material; real semantic values; mock-omitted states; interactions/hit targets. Every discrepancy must be either corrected or documented as a real-gameplay requirement.

- [ ] **Step 6: Document final ownership briefly in `CLAUDE.md`**

Record that scenes remain separate, the tab bar is presentation only, Battle/Camp nodes are scene presentation boundaries, Map/Conquest/Settings retain their existing layout/node ownership, fixtures are DEBUG-only evidence, and shared combat across tabs remains deferred.

- [ ] **Step 7: Run full verification**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO

swiftlint lint --no-cache
git diff --check origin/main...HEAD

rm -rf /tmp/PyxisForgedRelease
xcodebuild build -project Pyxis.xcodeproj -scheme Pyxis \
  -configuration Release -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/PyxisForgedRelease

APP_BINARY=/tmp/PyxisForgedRelease/Build/Products/Release-iphonesimulator/Pyxis.app/Pyxis
test -x "$APP_BINARY"
! strings "$APP_BINARY" | grep -F -- '-pyxis-forged-fixture'
```

Expected: full unit/UI suite passes, SwiftLint exits 0 with no new serious findings, diff is clean, Release builds, and fixture marker is absent. Confirm Codecov project and patch statuses are both at least 90%.

- [ ] **Step 8: Verify final scope and commit**

```bash
git diff --name-status origin/main...HEAD
git log --oneline origin/main..HEAD
```

Confirm there is no persistence schema/balance/dependency/custom-font/project-file/landscape/shared-combat change, no duplicate old navigation chrome, and the parity board is attached before ready-for-review.

```bash
git add Pyxis/ForgedVisualFixture.swift Pyxis/GameViewController.swift \
  PyxisTests/ForgedVisualFixtureTests.swift PyxisTests/GameViewControllerTests.swift \
  PyxisUITests/PyxisUITests.swift docs/visual-parity/forged-ui/README.md CLAUDE.md
git commit -m "test: prove Forged gameplay parity"
```

## Implementation PR Ready Checklist

- [ ] Battle, Camp, and Map remain separate scenes.
- [ ] Living manual soldiers still block leaving Battle for Camp/Map.
- [ ] Stable resource UI contains no fake income rate.
- [ ] Battle shows all five real unit states and uses the existing spawn path.
- [ ] Camp shows all five building types and delegates to existing build/upgrade mutations.
- [ ] Map selection does not mutate progression until the real action is invoked.
- [ ] Conquest uses only real two/three-tile statistics and named achievements.
- [ ] Settings retains independent persistence and accessibility behavior.
- [ ] Existing idle, lifecycle, feedback, restoration, milestone, and layout-gate tests pass.
- [ ] All primary/tab hit frames are at least 44 points.
- [ ] 393×852 mock/real/overlay evidence covers every required state.
- [ ] Phone and iPad containment tests pass.
- [ ] Full tests, lint, diff check, Release build/marker scan, and Codecov 90% gates pass.
- [ ] No dependency, migration, generic framework, custom font, or shared combat runtime was added.
