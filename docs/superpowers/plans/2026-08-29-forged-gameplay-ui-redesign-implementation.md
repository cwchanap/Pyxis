# Forged Gameplay UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Pyxis's Battle, Camp, Map, Conquest, and Settings chrome with the canonical Forged 393×852 references while preserving real gameplay contracts and proving mock-versus-real parity against deterministic simulator states.

**Architecture:** Keep `BattleScene`, `BuildingViewScene`, and `CountryMapScene` separate with `GameViewController` as the only production router. Extend the existing `PanelNode` instead of adding another panel type, add one shared tab bar, keep screen geometry in pure CoreGraphics layout values, and extend existing Map/Conquest/Settings owners rather than forking them. Land one closed DEBUG visual-fixture enum immediately after routing so every subsequent screen task can compare the real app against the same canonical mock while it is built.

**Tech Stack:** Swift 5, SpriteKit, UIKit, CoreGraphics, Swift Testing, XCTest UI tests, Xcode/iOS Simulator, existing Pyxis models/persistence.

**Spec:** `docs/superpowers/specs/2026-08-29-forged-gameplay-ui-redesign-design.md`

## Global Constraints

- Implement the complete runtime redesign in **one PR**; tasks below are logical commits, not separate PRs.
- Use only the canonical repository references under `docs/visual-parity/forged-ui/` for 393×852 parity.
- Shipping state/models remain authoritative. Never hardcode mock rewards, costs, unit counts, unlocks, timers, multipliers, or the mock's green `+6` income sample.
- Keep the three existing gameplay scenes and `GameViewController` router. Do not add a persistent shared combat runtime or one all-purpose gameplay scene.
- Preserve Battle's living-manual-squad guard before Camp/Map routing.
- Preserve pending-result-first routing. A pending Conquest result always restores Battle before honoring a requested tab.
- Any Camp exit must reuse the current `returnFromBackground` settlement/save/feedback handoff before routing.
- Infantry with no Barracks remains manually deployable at level 1 via the existing `manualSoldierLevel(for:)` fallback.
- Reuse `FeedbackSettingsController.gear`; no Battle/Camp/Map renderer creates a second settings gear or settings hit target.
- Battle required-chrome failure is a BattleScene flag read by `GameViewController.refreshLayoutSupport`, analogous to the existing Conquest fit flag.
- Map must explicitly grow the information-region budget, remove the separate current-city button, and revalidate all 15 city hit frames/routes.
- Camp shows all five `BuildingType` cases.
- Conquest atomically replaces `summaryLines`, `goldLineIndex`, and the old 3...4 row-count layout contract with reward + 2/3 typed stat tiles.
- Conquest omits the tab bar. Country-complete Map keeps all three tab cells visible but enables only Map.
- Add no save field/migration, balance/content change, landscape support, SwiftUI, third-party package, custom font, generated-asset pipeline, generic design system, router/component/fixture registry, or pixel-snapshot framework.
- Every primary control/tab hit frame is at least 44×44 points.
- `ForgedVisualFixture` and its launch marker compile out of Release.
- Do not edit `project.pbxproj`; synchronized groups discover new Swift/test files.
- Run simulator tests with `-parallel-testing-enabled NO`.
- Keep Codecov project and patch statuses at or above the repository's current 90% target with zero threshold.
- Do not mark the runtime PR ready until the real 393×852 mock/real/50%-overlay parity board is attached.

## Canonical references

- Battle: `docs/visual-parity/forged-ui/battle.png`
- Camp: `docs/visual-parity/forged-ui/camp.png`
- Map: `docs/visual-parity/forged-ui/map.png`
- Conquest: `docs/visual-parity/forged-ui/conquest.png`
- Settings: `docs/visual-parity/forged-ui/settings.png`

## File map

**Create**

- `Pyxis/GameplayTabBarNode.swift`
- `Pyxis/BattleChromeLayout.swift`
- `Pyxis/BattleHUDNode.swift`
- `Pyxis/CampChromeLayout.swift`
- `Pyxis/CampSelectionNode.swift`
- `Pyxis/ForgedVisualFixture.swift` (`#if DEBUG` body)
- focused test files for each new production file

**Modify**

- `Pyxis/GameUIComponents.swift`
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
- existing controller/scene/layout/node tests
- `PyxisUITests/PyxisUITests.swift`
- `CLAUDE.md`

Do **not** create `ForgedSurfaceNode.swift`; `PanelNode` is the existing shared surface seam.

---

## Task 1: Extend the existing panel material and add the closed tab bar

**Files:**
- Modify: `Pyxis/GameUIComponents.swift`
- Modify: `Pyxis/GameUITheme.swift`
- Create: `Pyxis/GameplayTabBarNode.swift`
- Modify: `PyxisTests/GameUIComponentsTests.swift`
- Create: `PyxisTests/GameplayTabBarNodeTests.swift`

**Interfaces:**

```swift
enum GameplayTab: CaseIterable, Hashable {
    case battle
    case camp
    case map
}

extension PanelNode {
    enum Style: Equatable {
        case standard
        case forged
        case selected
        case primaryAction
        case disabled
        case success
        case danger
    }
}

final class PanelNode: SKNode {
    func apply(size: CGSize, style: Style, showsRivets: Bool)
    func update(size: CGSize)
}

final class GameplayTabBarNode: SKNode {
    struct Content: Equatable {
        let selected: GameplayTab
        let enabledTabs: Set<GameplayTab>
        let showsCampAttention: Bool
    }

    func apply(content: Content, frame: CGRect)
    func tab(at point: CGPoint) -> GameplayTab?
}
```

- [ ] **Step 1: Write RED `PanelNode` stability tests**

```swift
@MainActor
@Test("PanelNode applies Forged style without duplicating its tree")
func panelNodeForgedStyleIsStable() {
    let panel = PanelNode(size: CGSize(width: 180, height: 58))
    panel.apply(
        size: CGSize(width: 180, height: 58),
        style: .primaryAction,
        showsRivets: true
    )
    let count = panel.nodeCountForTesting

    panel.apply(
        size: CGSize(width: 180, height: 58),
        style: .primaryAction,
        showsRivets: true
    )

    #expect(panel.nodeCountForTesting == count)
    #expect(panel.rivetCountForTesting == 4)
    #expect(panel.styleForTesting == .primaryAction)
}
```

Also pin that existing `update(size:)` retains `.standard` for a newly initialized panel and does not append children.

- [ ] **Step 2: Write RED tab availability tests**

```swift
@MainActor
@Test("Disabled gameplay tabs keep their cell but lose their hit target")
func disabledTabsAreNonInteractive() throws {
    let tabs = GameplayTabBarNode()
    let frame = CGRect(x: 16, y: 34, width: 361, height: 72)
    tabs.apply(
        content: .init(
            selected: .map,
            enabledTabs: [.map],
            showsCampAttention: false
        ),
        frame: frame
    )

    #expect(tabs.orderedTabsForTesting == [.battle, .camp, .map])
    #expect(tabs.hitFramesForTesting[.battle] == nil)
    #expect(tabs.hitFramesForTesting[.camp] == nil)
    let map = try #require(tabs.hitFramesForTesting[.map])
    #expect(map.width >= 44 && map.height >= 44)
    #expect(tabs.tab(at: CGPoint(x: map.midX, y: map.midY)) == .map)
}
```

- [ ] **Step 3: Run RED**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/GameUIComponentsTests \
  -only-testing:PyxisTests/GameplayTabBarNodeTests
```

Expected: new style/tab APIs are missing.

- [ ] **Step 4: Extend `PanelNode` in place**

Build shadow, plate, top-highlight, and four rivet `SKShapeNode`s once in `init`. Add `style` and `showsRivets` state; `apply` updates paths/colors/visibility only. `update(size:)` calls the same internal renderer using the current style. Add only shared Forged colors/metrics to `GameUITheme`: `horizontalMargin = 16`, `minimumHitSize = 44`, `panelCornerRadius = 12`, `tabBarHeight = 72`, iron/raised-iron/gold-edge/amber/hot-amber/muted/success/danger colors.

- [ ] **Step 5: Add exactly three tab bundles**

Create a fixed bundle per `GameplayTab` with `PanelNode`, SF Symbol sprite, title, and optional attention dot. Divide the supplied frame into three equal visual cells. Only tabs in `enabledTabs` populate hit frames. Use `shield.fill`, `hammer.fill`, and `map.fill`; labels remain readable if an icon cannot load.

- [ ] **Step 6: Run GREEN and commit**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/GameUIComponentsTests \
  -only-testing:PyxisTests/GameplayTabBarNodeTests

git add Pyxis/GameUIComponents.swift Pyxis/GameUITheme.swift \
  Pyxis/GameplayTabBarNode.swift PyxisTests/GameUIComponentsTests.swift \
  PyxisTests/GameplayTabBarNodeTests.swift
git commit -m "feat: add Forged panel styles and gameplay tabs"
```

---

## Task 2: Route tabs pending-first through the existing controller

**Files:**
- Modify: `Pyxis/GameViewController.swift`
- Modify: `Pyxis/BattleScene.swift`
- Modify: `Pyxis/BuildingViewScene.swift`
- Modify: `Pyxis/CountryMapScene.swift`
- Modify: `PyxisTests/GameViewControllerTests.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`
- Modify: `PyxisTests/BuildingViewSceneTests.swift`
- Modify: `PyxisTests/CountryMapSceneTests.swift`

**Interfaces:**

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

- [ ] **Step 1: Write RED Battle roster-preservation tests**

```swift
fixture.scene.spawnSoldierForTesting()
fixture.scene.requestGameplayTabForTesting(.camp)
#expect(fixture.router.requestedTabs.isEmpty)
#expect(fixture.scene.manualLivingSoldierCountForTesting == 1)
#expect(fixture.scene.feedbackTextForTesting == "Finish the current squad before building.")

fixture.scene.requestGameplayTabForTesting(.map)
#expect(fixture.router.requestedTabs.isEmpty)
#expect(fixture.scene.manualLivingSoldierCountForTesting == 1)
#expect(fixture.scene.feedbackTextForTesting == "Finish the current squad before viewing world.")
```

Use the existing Battle test fixture/helper names where they already provide the same spawn/readback; do not add a production abstraction to support this test.

- [ ] **Step 2: Write RED pending-first Camp exit regression**

Construct a mounted Camp state whose background settlement is sufficient to conquer the current city, then request `.map`. Assert the existing settlement produces `pendingBattleResult`, the store is saved, and the controller presents `BattleScene`, not `CountryMapScene`.

```swift
scene.requestGameplayTabForTesting(.map, at: foregroundDate)
#expect(store.load().pendingBattleResult != nil)
#expect(router.requestedTabs == [.map])

controller.buildingViewScene(scene, didRequest: .map)
#expect(skView.scene is BattleScene)
```

Also pin a non-conquering Camp→Map exit settling/saving exactly once.

- [ ] **Step 3: Write RED country-complete/Map tab-policy tests**

Map at `.countryComplete` renders the bar as selected Map with `enabledTabs == [.map]`; tapping Battle/Camp yields no router call. Map at `.cityConqueredPendingMap` uses the same enabled set. Active Map enables all three without changing the store when a tab itself is tapped.

- [ ] **Step 4: Run RED**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/GameViewControllerTests \
  -only-testing:PyxisTests/BattleSceneTests \
  -only-testing:PyxisTests/BuildingViewSceneTests \
  -only-testing:PyxisTests/CountryMapSceneTests
```

- [ ] **Step 5: Add the one controller-private pending-first switch**

```swift
private func presentGameplayTab(_ tab: GameplayTab, in view: SKView) {
    let state = store.load()

    if state.pendingBattleResult != nil {
        presentBattleScene(in: view)
        return
    }

    switch tab {
    case .battle:
        if state.stageStatus == .battleActive {
            presentBattleScene(in: view)
        } else {
            presentCountryMapScene(in: view)
        }
    case .camp:
        if state.stageStatus == .battleActive {
            presentBuildingViewScene(in: view)
        } else {
            presentCountryMapScene(in: view)
        }
    case .map:
        presentCountryMapScene(in: view)
    }
}
```

All three router conformances delegate accepted requests here.

- [ ] **Step 6: Reuse Camp's current settlement handoff for every exit**

Replace `requestBattle()` with one `requestGameplayTab(_:)` path. For `tab != .camp`, call the same sequence current `requestBattle()` uses: `returnFromBackground(at:)`, assign `lastIdleProgressResult`, `store.save(state)`, `applyIdleProgressFeedback`, `redraw()`, then router. Do not add a save-only Map shortcut.

Battle keeps existing living-squad guards before forwarding Camp/Map. Map tabs never call `startCityFromMap(_:)`; only the selected-city card action does.

- [ ] **Step 7: Remove superseded World/Build/Battle protocol methods, run GREEN, commit**

```bash
git add Pyxis/GameViewController.swift Pyxis/BattleScene.swift \
  Pyxis/BuildingViewScene.swift Pyxis/CountryMapScene.swift \
  PyxisTests/GameViewControllerTests.swift PyxisTests/BattleSceneTests.swift \
  PyxisTests/BuildingViewSceneTests.swift PyxisTests/CountryMapSceneTests.swift
git commit -m "refactor: route gameplay tabs pending-first"
```

---

## Task 3: Add the closed DEBUG visual fixtures before screen cutovers

**Files:**
- Create: `Pyxis/ForgedVisualFixture.swift`
- Create: `PyxisTests/ForgedVisualFixtureTests.swift`
- Modify: `Pyxis/GameViewController.swift`
- Modify: `PyxisTests/GameViewControllerTests.swift`

**Interfaces:**

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

    static func requested(in arguments: [String]) -> ForgedVisualFixture?
    var initialTab: GameplayTab { get }
    func makeState() -> KingdomGameState
}
#endif
```

- [ ] **Step 1: Write RED parser/state tests**

Pin the exact raw-value list above. No/unknown/missing value returns nil. Use deterministic states:

```text
battle: City 3, 4_200 gold, Barracks L2 + Archery L1
battle-blocked: same persisted state; Battle test/UI path deploys one manual soldier before blocked-tab capture
camp-empty: City 5, 1_000 gold, empty current grid
camp-occupied: City 5, 1_000 gold, six occupied lots including at least Barracks and Archery
map: three completed cities, City 4 unlocked, stage .cityConqueredPendingMap
map-country-complete: all 15 completed, stage .countryComplete
conquest-live: pending City 3 live result, +640 gold, 74s, Infantry MVP, 6 deployed / 1 lost, both achievements
conquest-idle: pending City 3 idle result, +640 gold, no MVP, zero achievements
```

Each case uses normal `KingdomGameState`, `CityBattleState`, `ActiveSiegeSession`, and `BattleResult` initialization. No fixture JSON/file/builder/registry is added.

- [ ] **Step 2: Write RED controller launch tests**

With no argument, an existing store remains untouched and normal routing occurs. With a valid fixture, the fixture replaces the development/test save then `presentGameplayTab(fixture.initialTab, in:)` uses normal constructors. Pending Conquest fixtures still land on Battle because Task 2 is pending-first.

- [ ] **Step 3: Run RED**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/ForgedVisualFixtureTests \
  -only-testing:PyxisTests/GameViewControllerTests
```

- [ ] **Step 4: Implement the DEBUG-only enum and explicit launch hook**

In `GameViewController.viewDidLoad`, immediately before normal initial routing:

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

Do not add freeze-combat here; Task 10 adds it only for final capture. Do not fold this into `DevJumpState`.

- [ ] **Step 5: Run GREEN and commit**

```bash
git add Pyxis/ForgedVisualFixture.swift Pyxis/GameViewController.swift \
  PyxisTests/ForgedVisualFixtureTests.swift PyxisTests/GameViewControllerTests.swift
git commit -m "test: add Forged visual fixtures"
```

From this task onward, every visual task must launch its relevant fixture at 393×852 and compare it with the canonical PNG before its commit is considered complete.

---

## Task 4: Build Battle's real-state projection, pure layout, and HUD node

**Files:**
- Create: `Pyxis/BattleChromeLayout.swift`
- Create: `Pyxis/BattleHUDNode.swift`
- Create: `PyxisTests/BattleChromeLayoutTests.swift`
- Create: `PyxisTests/BattleHUDNodeTests.swift`

**Interfaces:**

```swift
struct BattleChromeLayout: Equatable {
    let resourceFrame: CGRect
    let settingsFrame: CGRect
    let cityHeaderFrame: CGRect
    let cityHPFrame: CGRect
    let objectiveFrame: CGRect
    let exposedLaneFrame: CGRect
    let fortifiedLaneFrame: CGRect
    let unitFrames: [SoldierType: CGRect]
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

    static func project(
        state: KingdomGameState,
        selectedUnit: SoldierType,
        manualCount: Int
    ) -> BattleHUDContent
}

enum BattleHUDAction: Equatable {
    case selectUnit(SoldierType)
    case showUnitRequirement(SoldierType)
    case deploy
    case selectTab(GameplayTab)
    case consumed
}
```

`BattleHUDNode` has **no** Settings action or gear node.

- [ ] **Step 1: Write RED geometry tests at 375×667, 393×852, and current iPad fixture**

At 393×852 assert 16-point side margins, exactly five 56-point medallion visual frames, Deploy/table width 361, every interactive frame ≥44, required chrome inside safe content, and battlefield vertically separated from lane/unit controls.

- [ ] **Step 2: Write RED Infantry fallback tests**

```swift
let city1 = KingdomGameState(
    gold: 15,
    countryNumber: 1,
    completedCityCount: 0,
    stageStatus: .battleActive,
    cityBattleStates: [:]
)
let content1 = BattleHUDContent.project(
    state: city1,
    selectedUnit: .infantry,
    manualCount: 0
)
#expect(content1.unit(.infantry).availability == .available(level: 1))
#expect(content1.unit(.archer).availability == .locked(unlocksAtCity: 2))
#expect(content1.unit(.cavalry).availability == .locked(unlocksAtCity: 5))
#expect(content1.unit(.mage).availability == .locked(unlocksAtCity: 8))
#expect(content1.unit(.siege).availability == .locked(unlocksAtCity: 11))
```

Add City 5 empty-grid assertions: Infantry available L1, Archer/Cavalry unbuilt, Mage/Siege locked at 8/11. Add built Barracks/Archery tests proving highest matching building level wins. This directly guards against presentation code undoing the starter fallback.

- [ ] **Step 3: Write RED recommendation/lane/tab tests**

Cover `.ready`, `.saveFor`, `.noAction`; 1.25/0.80/1.00 multipliers from `CityDefenseTrait.damageMultiplier`; exposed/fortified lanes; manual `N / 10`; and all three tabs enabled in active Battle content.

- [ ] **Step 4: Run RED**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/BattleChromeLayoutTests \
  -only-testing:PyxisTests/BattleHUDNodeTests
```

- [ ] **Step 5: Implement the projection in the correct order**

For each `SoldierType`, first call `manualSoldierLevel(for:)`. If nonnil, emit available even when there is no building. Only if it is nil inspect `isBuildingTypeUnlocked(_:)` to choose unbuilt vs locked and use `unlockCity(for:)`. Map `RecommendedCampRecommendation` directly. Do not duplicate unlock or trait tables.

- [ ] **Step 6: Implement one Battle chrome geometry authority and one HUD node**

Build bottom-up from tab → Deploy/manual count → medallions → battlefield reservation → lane chips → objective → city/resource top bands. Use existing soldier first-walk-frame assets cropped with `SoldierAnimationGeometry`. Build fixed node bundles once and reapply values/layout without child duplication.

The layout outputs `settingsFrame` but the node ignores it.

- [ ] **Step 7: Launch the `battle` fixture at 393×852, compare with `battle.png`, run GREEN, commit**

Correct geometry/hierarchy mismatches before committing; do not wait for Task 10.

```bash
git add Pyxis/BattleChromeLayout.swift Pyxis/BattleHUDNode.swift \
  PyxisTests/BattleChromeLayoutTests.swift PyxisTests/BattleHUDNodeTests.swift
git commit -m "feat: add Forged Battle HUD projection"
```

---

## Task 5: Cut BattleScene over and wire the existing Settings gear/layout gate

**Files:**
- Modify: `Pyxis/BattleScene.swift`
- Modify: `Pyxis/GameViewController.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`
- Modify: `PyxisTests/GameViewControllerTests.swift`

- [ ] **Step 1: Write RED fail-closed Battle chrome tests**

Add DEBUG readback for the scene flag only:

```swift
#expect(scene.isBattleChromeFitFailed == false)
scene.resizeForTesting(to: unsupportedSize)
#expect(scene.isBattleChromeFitFailed == true)
#expect(router.layoutGateReasons.last == .unsupportedGeometry)
```

Controller test pins:

```swift
controller.refreshLayoutSupportForTesting(environment: environment)
#expect(controller.isLayoutGateVisibleForTesting)
#expect(battle.isBattleChromeFitFailed)
```

Then resize back to a supported geometry and assert both flag and gate clear.

- [ ] **Step 2: Write RED existing-gear ownership tests**

After Battle layout, assert there is exactly one `SettingsGearNode.semanticName` subtree and its `resolvedHitFrame` equals `BattleChromeLayout.settingsFrame` after `FeedbackSettingsController.applyGearFrame`. Tapping it still opens the same controller modal and freezes battlefield actions. Assert `BattleHUDNode` has no settings hit frame/action.

- [ ] **Step 3: Write RED interaction/roster tests**

Available Infantry on an empty City 1 grid selects/deploys normally. Unbuilt Archer at an unlocked city produces existing build-first feedback but does not route. Locked Mage reports City 8. Tab Camp/Map still preserve the living-squad guards from Task 2.

- [ ] **Step 4: Run RED**

- [ ] **Step 5: Integrate without touching combat**

Replace old left/right HUD, manual dropdown, Spawn, World, and Build chrome with one `BattleHUDNode`. Keep combat/battlefield/effects/feedback/milestone/Conquest code. `BattlefieldLayout` receives bounds from `BattleChromeLayout.battlefieldFrame` rather than duplicating chrome math.

Apply `BattleChromeLayout.settingsFrame` to the existing `feedbackSettingsController.gear`. Do not move Settings handling into the HUD node.

- [ ] **Step 6: Add the required layout flag**

```swift
private(set) var isBattleChromeFitFailed = false
```

Set true and hide/disable required HUD controls when `BattleChromeLayout.compute` returns nil; notify router only to trigger refresh. Reset false on successful layout. In `GameViewController.refreshLayoutSupport` use:

```swift
} else if let battle = skView.scene as? BattleScene,
          battle.isConquestReportFitFailed || battle.isBattleChromeFitFailed {
    reason = .unsupportedGeometry
```

- [ ] **Step 7: Launch `battle` and `battle-blocked` at 393×852, run GREEN, commit**

```bash
git add Pyxis/BattleScene.swift Pyxis/GameViewController.swift \
  PyxisTests/BattleSceneTests.swift PyxisTests/GameViewControllerTests.swift
git commit -m "feat: apply Forged Battle chrome"
```

---

## Task 6: Replace Camp controls with five-option builder and occupied inspector

**Files:**
- Create: `Pyxis/CampChromeLayout.swift`
- Create: `Pyxis/CampSelectionNode.swift`
- Modify: `Pyxis/BuildingViewScene.swift`
- Create: `PyxisTests/CampChromeLayoutTests.swift`
- Create: `PyxisTests/CampSelectionNodeTests.swift`
- Modify: `PyxisTests/BuildingViewSceneTests.swift`

**Interfaces:**

```swift
struct CampSelectionContent: Equatable {
    enum BuildAvailability: Equatable {
        case available(cost: Int)
        case unaffordable(cost: Int)
        case locked(unlocksAtCity: Int)
        case capped(maximum: Int)
    }

    enum Selection: Equatable {
        case empty(slot: Int, options: [BuildOption])
        case occupied(Inspector)
    }
}

enum CampSelectionAction: Equatable {
    case build(BuildingType)
    case upgrade
    case selectTab(GameplayTab)
    case consumed
}
```

- [ ] **Step 1: Write RED pure option tests**

At City 5 verify `BuildingType.allCases` yields exactly five options in enum order. Pin locked → capped → available/unaffordable precedence, real cost/unlock/cap values, and recommendation emphasis only when the recommendation's slot/type/kind matches.

- [ ] **Step 2: Write RED 393×852/edge-lot geometry tests**

All five option hit frames are ≥44 and clear tab/inspector/safe edges. Center lots use the authored radial arrangement; edge lots may use two arcs/rows but still expose all five. Occupied inspector includes building art/name, current level pips, lot, produced soldier, upgrade cost/action, and tab frame.

- [ ] **Step 3: Write RED mutation/settlement tests**

Valid build and Upgrade delegate exactly once to existing scene mutation methods and save once. Invalid/unaffordable/locked/capped actions are consumed and preserve existing feedback semantics. A build/upgrade that conquers during settlement leaves `pendingBattleResult`; selecting Map afterward runs Task 2 settlement/routing and restores Battle report.

- [ ] **Step 4: Run RED**

- [ ] **Step 5: Implement projection/layout/node and cut scene over**

Keep scenic backdrop, 25 slot bundles/positions, `selectedSlot`, lifecycle, build/upgrade methods, feedback, and store. Remove old palette/action panel/recommendation row/Upgrade/Battle button only after the new node covers them. Reuse `PanelNode` Forged styles and existing building assets. Successful build keeps the slot selected so inspector replaces the radial options.

Camp layout positions the existing Settings gear through its settings frame; it does not draw another gear.

- [ ] **Step 6: Launch `camp-empty` and `camp-occupied` at 393×852, compare with `camp.png`, run GREEN, commit**

```bash
git add Pyxis/CampChromeLayout.swift Pyxis/CampSelectionNode.swift \
  Pyxis/BuildingViewScene.swift PyxisTests/CampChromeLayoutTests.swift \
  PyxisTests/CampSelectionNodeTests.swift PyxisTests/BuildingViewSceneTests.swift
git commit -m "feat: apply Forged Camp interactions"
```

---

## Task 7: Expand Map budget and selected-city card without duplicate navigation

**Files:**
- Modify: `Pyxis/CountryMapLayout.swift`
- Modify: `Pyxis/CountryMapScene.swift`
- Modify: `Pyxis/CountryMapScoutCardContent.swift`
- Modify: `Pyxis/CountryMapScoutCardLayout.swift`
- Modify: `Pyxis/CountryMapScoutCardNode.swift`
- Modify: all existing Map layout/scene/card/acceptance tests

**Content contract:**

```swift
enum CountryMapScoutCardContent: Equatable {
    enum State: Equatable {
        case attackable
        case current
        case completed
        case locked
        case countryComplete
    }

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

    static func project(
        from state: KingdomGameState,
        selectedCity: Int
    ) -> CountryMapScoutCardContent
}
```

- [ ] **Step 1: Write RED selected-city content tests**

Cover attackable/current/completed/locked/country-complete. Selection projects authored identity, trait, lane, favorable/disadvantaged types and real multipliers without mutating the store. Reward exists only when a future conquest reward is meaningful.

- [ ] **Step 2: Write RED broad-layout tests with the new fixed card heights**

Change and pin:

```swift
var informationRegionHeight: CGFloat {
    self == .phone ? 236 : 300
}
```

At 393×852 assert resource/settings/title/pips/tab/card/illustrated map are contained and non-overlapping. Re-run the existing phone/pad matrix and preserve horizontal-safe-area / invalid-authored-data failures.

Most importantly, assert every Country 1 city 44×44 target and every route stroke remains in `illustratedMapRegionFrame` after the larger card/tab reservation. `CountryMapLayout` must recompute the backdrop/anchor transform for the illustrated region; do not retain the old full-scene transform.

- [ ] **Step 3: Write RED removal tests for the duplicate current-city control**

Delete expectations for `showsCurrentCityControl` / `currentCityControlFrame` and replace them with card `RETURN` behavior. Scene tests assert no `countryMapCurrentCityButton` node/hit target remains. Active Map's selected current city returns through the card; global Battle/Camp use tabs.

- [ ] **Step 4: Write RED scene selection/feedback tests**

Tapping any city changes only `selectedCityNumber`. Locked/completed selection keeps the store equal and primary action non-hit/feedback-driven. Attackable March calls existing sequential entry exactly once. Current `RETURN` goes to Battle without restarting state. Flavor overlay remains non-blocking and excludes an enabled March/Return frame.

- [ ] **Step 5: Run all Map suites RED**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/CountryMapLayoutTests \
  -only-testing:PyxisTests/CountryMapSceneTests \
  -only-testing:PyxisTests/CountryMapScoutCardContentTests \
  -only-testing:PyxisTests/CountryMapScoutCardLayoutTests \
  -only-testing:PyxisTests/CountryMapScoutCardNodeTests \
  -only-testing:PyxisTests/CountryMapScoutCardAcceptanceTests
```

- [ ] **Step 6: Extend the existing owners only**

`CountryMapLayout` owns broad regions, tabs, pips, settings frame, illustrated region, backdrop transform, cities/routes. `CountryMapScoutCardLayout` owns the 236/300-point card interior only. Extend the existing card node tree with Forged surfaces, portrait rows, multipliers, lane, and state action. Reuse first walk-frame portraits plus `SoldierAnimationGeometry` crop logic.

Remove `showsCurrentCityControl` from constraints/output and remove `currentCityButton` creation/touch/layout. Position the existing Settings gear through the broad layout.

- [ ] **Step 7: Launch `map` and `map-country-complete` at 393×852, compare with `map.png`, run GREEN, commit**

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

## Task 8: Atomically replace Conquest text rows with reward + typed stat tiles

**Files:**
- Modify: `Pyxis/ConquestReportContent.swift`
- Modify: `Pyxis/ConquestReportLayout.swift`
- Modify: `Pyxis/ConquestReportNode.swift`
- Modify: `Pyxis/BattleScene.swift`
- Modify: existing Conquest content/layout/node and Battle report tests

**Interfaces:**

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

- [ ] **Step 1: Write RED exact content-shape tests**

Pin four outputs:

```text
live + MVP       -> [mvp, battleTime, sentLost]
live without MVP -> [battleTime, sentLost]
idle + MVP       -> [mvp, buildings, sentLost]
idle without MVP -> [buildings, sentLost]
```

Also cover zero/one/two achievement chips and real reward formatting. Assert no empty/filler tile.

- [ ] **Step 2: Write RED layout/node tests for the new atomic contract**

`ConquestReportLayout.Input` takes `statTileCount` 2...3 and `achievementChipCount` 0...2. Output includes `rewardFrame`, `statTileFrames`, optional chip strip/frames, `continueFrame`, and existing optional country-complete frame. Two tiles center evenly; three fill one row. Zero achievements reserve no chip height. March On ≥44.

Node test pins:

```swift
let anchor = try #require(node.goldEffectAnchorForTesting)
#expect(anchor == CGPoint(x: layout.rewardFrame.midX, y: layout.rewardFrame.midY))
```

- [ ] **Step 3: Run Conquest/Battle suites RED**

- [ ] **Step 4: Replace old content/layout APIs in one compiling commit slice**

Delete `summaryLines` and `goldLineIndex` while adding typed tiles/reward. Delete `(3...4).contains(summaryRowCount)` and old summary-row frames while adding the 2...3 tile contract. Keep `BattleResult` coding/finalization unchanged. Reuse existing duration/compact-number formatting.

- [ ] **Step 5: Rebuild `ConquestReportNode` using fixed reusable bundles**

Keep three tile bundles and two chip bundles; hide unused nodes. Anchor gold feedback to `rewardFrame`. Use visible `MARCH ON` text but retain current Continue hit API, disable-after-tap behavior, acknowledge/save/route path, fresh/restored origin handling, and country-completion layout reservation. Hide/clear GameplayTabBar while report is presented.

- [ ] **Step 6: Launch `conquest-live` and `conquest-idle`, compare with `conquest.png`, run GREEN, commit**

```bash
git add Pyxis/ConquestReportContent.swift Pyxis/ConquestReportLayout.swift \
  Pyxis/ConquestReportNode.swift Pyxis/BattleScene.swift \
  PyxisTests/ConquestReportContentTests.swift PyxisTests/ConquestReportLayoutTests.swift \
  PyxisTests/ConquestReportNodeTests.swift PyxisTests/BattleSceneTests.swift
git commit -m "feat: apply Forged conquest report"
```

---

## Task 9: Restyle Settings while preserving the existing gear/controller/accessibility chain

**Files:**
- Modify: `Pyxis/FeedbackSettingsLayout.swift`
- Modify: `Pyxis/FeedbackSettingsNode.swift`
- Modify: existing Settings layout/node/controller and Battle/Camp/Map modal tests

**Layout contract:**

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

- [ ] **Step 1: Write RED bottom-sheet geometry tests**

At 393×852 with top 59/bottom 34, sheet spans the scene width and anchors above the bottom safe inset, contains two ≥52-point rows and a ≥48-point Done action, and has no overlap. Preserve invalid/non-finite/small-geometry failure coverage.

- [ ] **Step 2: Write RED rendering/controller/accessibility tests**

Assert exactly two icon/title/switch-track/thumb rows plus Done. Enabled thumb right/success; disabled left/muted. Row centers still return `.toggleSoundEffects` / `.toggleHaptics`; Done returns `.close`. Preference persistence remains independent. Existing accessibility labels/values/actions still expose `On`/`Off`, and close restores focus to the one existing `feedbackSettingsGear`.

- [ ] **Step 3: Run Settings plus scene-modal suites RED**

- [ ] **Step 4: Change only layout/rendering**

Keep `FeedbackSettingsController`, preferences, adapter, action enum, focus logic, and Battle pause logic. Render one Forged `PanelNode` sheet, two row panels, SF Symbol icons, SpriteKit switch tracks/thumbs, decorative non-draggable handle, and primary Done panel. Do not add `UISwitch`, another accessibility element set, or another gear.

- [ ] **Step 5: Launch `battle` fixture, open Settings, compare with `settings.png`, run GREEN, commit**

```bash
git add Pyxis/FeedbackSettingsLayout.swift Pyxis/FeedbackSettingsNode.swift \
  PyxisTests/FeedbackSettingsLayoutTests.swift PyxisTests/FeedbackSettingsNodeTests.swift \
  PyxisTests/FeedbackSettingsControllerTests.swift PyxisTests/BattleSceneTests.swift \
  PyxisTests/BuildingViewSceneTests.swift PyxisTests/CountryMapSceneTests.swift
git commit -m "feat: apply Forged settings sheet"
```

---

## Task 10: Add capture freeze, UI smoke, parity evidence, Release proof, and final verification

**Files:**
- Modify: `Pyxis/ForgedVisualFixture.swift`
- Modify: `Pyxis/BattleScene.swift`
- Modify: `PyxisTests/ForgedVisualFixtureTests.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`
- Modify: `PyxisUITests/PyxisUITests.swift`
- Modify: `docs/visual-parity/forged-ui/README.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Write RED freeze parsing/Battle-tick tests**

Add exactly one DEBUG marker:

```swift
static let freezeCombatArgument = "-pyxis-freeze-combat"
static func freezesCombat(in arguments: [String]) -> Bool
```

No marker → normal update. Marker → Battle `update` returns before combat advancement only; layout, taps, Settings, and report presentation remain active. This is screenshot stabilization, not another fixture state.

- [ ] **Step 2: Implement freeze and run focused GREEN**

Keep the check inside `#if DEBUG`. Do not persist it or add Settings/runtime flags.

- [ ] **Step 3: Add one 393×852 coordinate-based UI smoke with screenshot attachments**

Use fixture launches rather than one synthetic mega-flow:

```text
battle-blocked + freeze: capture Battle, deploy Infantry, tap Map, verify Battle remains
camp-empty: open/select an empty lot and capture five-option builder
camp-occupied: select occupied lot and capture inspector
map: select attackable/locked city and capture card
map-country-complete: capture disabled Battle/Camp tabs
conquest-live: capture three-tile report
conquest-idle: capture two-tile/no-chip report
battle + Settings: toggle one setting and capture sheet
```

Attach screenshots with stable `XCTAttachment` names and `.keepAlways`. Do not assert pixels in XCTest; semantic assertions stay in unit/scene tests.

- [ ] **Step 4: Build the mandatory mock/real/50%-overlay board**

Use the five canonical PNGs already in `docs/visual-parity/forged-ui/`. Minimum states:

```text
Battle normal
Battle locked/unbuilt (must show Infantry L1 starter correctly)
Battle blocked Camp/Map
Camp empty radial
Camp occupied inspector
Camp unavailable building option
Map attackable/current
Map locked/completed
Map country complete
Conquest live with MVP
Conquest idle without MVP / zero chips
Settings with one toggle off
```

For each state attach canonical mock, real 393×852 capture, and 50% alpha overlay to the runtime PR. Add only short deliberate-discrepancy notes to `docs/visual-parity/forged-ui/README.md`; do not commit duplicate real/overlay binary sets unless the project later needs them as durable test artifacts.

Review/fix in this order: geometry/safe area → hierarchy → typography/material → real semantic values → omitted-mock states → hit targets/interactions.

- [ ] **Step 5: Record ownership in `CLAUDE.md`**

Document: three scenes remain; tabs are presentation only; `PanelNode` owns shared Forged material; Battle/Camp have focused layout/render nodes; Map/Conquest/Settings retain existing owners; the one Settings gear remains `FeedbackSettingsController.gear`; fixtures are DEBUG-only evidence; shared combat across tabs is deferred.

- [ ] **Step 6: Run full simulator/unit/UI/lint/diff verification**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO

swiftlint lint --no-cache
git diff --check origin/main...HEAD
```

Expected: all tests pass; SwiftLint exits 0; diff check clean.

- [ ] **Step 7: Build Release and prove fixture markers compile out**

```bash
rm -rf /tmp/PyxisForgedRelease
xcodebuild build \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/PyxisForgedRelease

APP_BINARY=/tmp/PyxisForgedRelease/Build/Products/Release-iphonesimulator/Pyxis.app/Pyxis
! strings "$APP_BINARY" | grep -F -- '-pyxis-forged-fixture'
! strings "$APP_BINARY" | grep -F -- '-pyxis-freeze-combat'
```

Expected: Release build succeeds and both grep commands find nothing.

- [ ] **Step 8: Check Codecov and commit final evidence/docs/test slice**

Project and patch statuses remain ≥90% with threshold 0. Do not weaken `codecov.yml`.

```bash
git add Pyxis/ForgedVisualFixture.swift Pyxis/BattleScene.swift \
  PyxisTests/ForgedVisualFixtureTests.swift PyxisTests/BattleSceneTests.swift \
  PyxisUITests/PyxisUITests.swift docs/visual-parity/forged-ui/README.md CLAUDE.md
git commit -m "test: verify Forged gameplay UI parity"
```

## Final plan self-review

Before implementation begins, verify these exact contracts remain present in the completed runtime PR:

- No `ForgedSurfaceNode`; existing `PanelNode` is extended.
- Infantry on an empty current-city grid remains `.available(level: 1)`.
- Camp→Map can never bypass a pending Conquest report.
- Controller reads both Battle chrome and Conquest fit flags.
- `BattleHUDNode` does not own Settings.
- Map uses 236/300 information heights, removes `currentCityButton`, and proves every city/route still fits.
- Fixture support exists before screen cutovers and remains separate from `DevJumpState`.
- Conquest reward/tile contract removes `summaryLines` and `goldLineIndex` in the same slice.
- Conquest has no tab bar; country-complete Map enables only Map.
- Runtime PR includes canonical mock/real/50%-overlay evidence before leaving draft.
