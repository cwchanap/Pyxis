# Forged Gameplay UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Pyxis's Battle, Camp, Map, Conquest, and Settings chrome with the canonical Forged mobile UI while preserving real gameplay and proving mock-versus-real parity against deterministic simulator states.

**Architecture:** Keep `BattleScene`, `BuildingViewScene`, and `CountryMapScene` separate. Extend the existing `PanelNode`, add one shared tab bar, extract Battle/Camp geometry into pure CoreGraphics values, extend existing Map/Conquest/Settings owners, and keep `GameViewController.presentSceneForCurrentStage` as the one stage/pending routing authority. Add one closed DEBUG visual-fixture enum before any screen cutover.

**Tech Stack:** Swift 5, SpriteKit, UIKit, CoreGraphics, Swift Testing, XCTest UI tests, Xcode/iOS Simulator, existing Pyxis models/persistence.

**Spec:** `docs/superpowers/specs/2026-08-29-forged-gameplay-ui-redesign-design.md`

## Global Constraints

- Implement this task in **one runtime PR**. Tasks below are logical commits/review checkpoints, not separate PRs.
- Use only the exact canonical files `docs/visual-parity/forged-ui/{battle,camp,map,conquest,settings}.png` as the 393×852 visual targets. These files must be present before runtime implementation begins.
- Existing models remain authoritative. Never hardcode mock rewards, costs, counts, unlocks, timers, multipliers, or `+6` income.
- Keep three gameplay scenes; no shared combat shell or all-purpose scene.
- Keep `presentSceneForCurrentStage` as the pending/stage routing authority; do not fork that policy into another switch.
- Any Camp exit reuses the existing `returnFromBackground` settlement/save/feedback handoff before routing.
- Manual living soldiers disable Camp/Map tabs and the existing route guard remains as defense in depth.
- Infantry without Barracks remains `.available(level: 1)` through `manualSoldierLevel(for:)`.
- Reuse `FeedbackSettingsController.gear`; no screen renderer creates another Settings gear/hit target.
- Regular Battle field minimum is 416 pt; the 393×852 reference must produce 424...440 pt. Compact 375×667 field floor is 340 pt.
- Map uses computed vertical budget: minimum illustrated phone map height 431, preferred reference phone card 164, preferred pad card 140, compact card floor 48, city-center distance ≥45.
- Map removes `showsCurrentCityControl` / `currentCityButton` rather than preserving duplicate navigation.
- Camp shows all five `BuildingType` cases.
- Conquest removes `summaryLines`, `goldLineIndex`, and 3...4 summary-row layout together.
- Settings retains `panelFrame` and `closeFrame`; add only `handleFrame` and change presentation/copy.
- `ForgedVisualFixture` reuses `DevJumpState.make(city:)` for Country 1 state baselines but keeps its launch-argument trigger separate.
- Add no save migration, balance/content change, Country 2, landscape support, SwiftUI, dependency, custom font, generated-asset pipeline, generic design/router/fixture registry, or pixel snapshot framework.
- Every primary control/tab hit frame is at least 44×44 pt.
- DEBUG fixture/freeze markers compile out of Release.
- Do not edit `project.pbxproj`; synchronized groups discover new files.
- Run simulator tests with `-parallel-testing-enabled NO`.
- Keep Codecov project and patch statuses ≥90%, threshold 0; do not weaken `codecov.yml`.
- Runtime PR stays Draft until the parity board and final gates pass.

## Risks already planned for

1. **Map geometry:** pure tests pin 431 pt illustrated map, ≥45 pt city spacing, and ~8 pt reference target headroom before scene cutover. Fallback is a smaller computed card, never smaller city hits or dropped cities.
2. **Battle collapse:** pure tests pin 416 pt regular / 340 pt compact minimum and 424...440 pt reference output. Nil layout sets `isBattleChromeFitFailed`.
3. **Codecov:** pure types own branching; render nodes use fixed trees/thin apply/hit paths. If patch <90%, add focused tests for Codecov-reported uncovered lines.
4. **Large one-PR review:** checkpoint reviews after Tasks 3, 5, 7, and 9; do not split PRs unless explicitly approved.

## File Map

**Create:**
- `Pyxis/GameplayTabBarNode.swift`
- `Pyxis/BattleChromeLayout.swift`
- `Pyxis/BattleHUDNode.swift`
- `Pyxis/CampChromeLayout.swift`
- `Pyxis/CampSelectionNode.swift`
- `Pyxis/ForgedVisualFixture.swift` (`#if DEBUG` body)
- focused tests for each new type

**Modify:**
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
- corresponding existing tests, `PyxisUITests/PyxisUITests.swift`, `CLAUDE.md`

---

## Task 1: Extend `PanelNode` and add truthful gameplay tabs

**Files:** `GameUIComponents.swift`, `GameUITheme.swift`, new `GameplayTabBarNode.swift`, `GameUIComponentsTests.swift`, new `GameplayTabBarNodeTests.swift`.

**Interfaces:**

```swift
enum GameplayTab: CaseIterable, Hashable { case battle, camp, map }

extension PanelNode {
    enum Style: Equatable {
        case normal
        case selected
        case primaryAction
        case disabled
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

- [ ] **Step 1: RED `PanelNode` fixed-tree test.** Apply `.primaryAction` twice to a 180×58 panel; assert child count does not change, four rivets are visible, style readback is `.primaryAction`, and `update(size:)` preserves style.
- [ ] **Step 2: RED tab test.** Apply selected Map with `enabledTabs == [.map]`; assert all three visual cells exist, Battle/Camp have no hit frame, Map hit is ≥44×44, and `tab(at:)` returns only Map.
- [ ] **Step 3: Run:**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/GameUIComponentsTests \
  -only-testing:PyxisTests/GameplayTabBarNodeTests
```

Expected RED: style/tab APIs absent.

- [ ] **Step 4: Implement `PanelNode`.** Build shadow, plate, highlight, four rivets once. Add only state styles `normal/selected/primaryAction/disabled`. Do not add `.standard`, `.forged`, `.success`, or `.danger` panel cases. Theme may expose success/danger **colors** for actual badges/switches.
- [ ] **Step 5: Implement three tab bundles.** Fixed `PanelNode` + SF Symbol + title + optional Camp dot. Only enabled tabs get hit frames.
- [ ] **Step 6: GREEN + commit.**

```bash
git add Pyxis/GameUIComponents.swift Pyxis/GameUITheme.swift \
  Pyxis/GameplayTabBarNode.swift PyxisTests/GameUIComponentsTests.swift \
  PyxisTests/GameplayTabBarNodeTests.swift
git commit -m "feat: add Forged panel treatment and gameplay tabs"
```

---

## Task 2: Extend the existing pending-first router instead of forking it

**Files:** `GameViewController.swift`, Battle/Camp/Map scenes and their existing tests.

- [ ] **Step 1: RED pending-first tests.** A mounted Camp whose `returnFromBackground` settlement conquers the city requests Map; assert save contains `pendingBattleResult` and controller presents `BattleScene`, not Map. Non-conquering Camp→Map settles/saves once then opens Map.
- [ ] **Step 2: RED Battle enabled-tab tests.** With zero manual living soldiers, Battle content enables all tabs. After spawning one manual soldier, content enables only Battle; Camp/Map visual cells remain but `tab(at:)` returns nil. Direct route requests still preserve existing feedback if invoked through test seams.
- [ ] **Step 3: RED stage tests.** `preferredTab: .camp` during `.battleActive` opens Camp; `.map` opens Map; any preferred tab with pending result opens Battle; any preferred tab at `.countryComplete` opens Map.
- [ ] **Step 4: Replace the current method with one extended authority:**

```swift
private func presentSceneForCurrentStage(
    in view: SKView,
    preferredTab: GameplayTab = .battle
) {
    let state = store.load()
    if state.pendingBattleResult != nil {
        presentBattleScene(in: view)
        return
    }
    switch state.stageStatus {
    case .battleActive:
        switch preferredTab {
        case .battle: presentBattleScene(in: view)
        case .camp: presentBuildingViewScene(in: view)
        case .map: presentCountryMapScene(in: view)
        }
    case .cityConqueredPendingMap, .countryComplete:
        presentCountryMapScene(in: view)
    }
}
```

All tab router callbacks call this method; do not duplicate the pending check elsewhere.

- [ ] **Step 5: Generalize Camp's existing `requestBattle()` to `requestGameplayTab(_:)`.** Before any `tab != .camp` route, run current `returnFromBackground(at:)` → store save → idle feedback → redraw → router sequence.
- [ ] **Step 6: Remove superseded World/Build/Battle protocol methods after callers compile.** Map tabs never call `startCityFromMap(_:)`.
- [ ] **Step 7: Run the four focused suites GREEN and commit.**

```bash
git add Pyxis/GameViewController.swift Pyxis/BattleScene.swift \
  Pyxis/BuildingViewScene.swift Pyxis/CountryMapScene.swift \
  PyxisTests/GameViewControllerTests.swift PyxisTests/BattleSceneTests.swift \
  PyxisTests/BuildingViewSceneTests.swift PyxisTests/CountryMapSceneTests.swift
git commit -m "refactor: route gameplay tabs through stage authority"
```

---

## Task 3: Add deterministic DEBUG fixtures before visual work

**Files:** new `ForgedVisualFixture.swift` + tests; modify `GameViewController.swift` + tests.

**Contract:** battle, battle-blocked, camp-empty, camp-occupied, map, map-country-complete, conquest-live, conquest-idle; marker `-pyxis-forged-fixture`.

- [ ] **Step 1: RED parser test.** Exact raw-value list; missing/unknown value returns nil.
- [ ] **Step 2: RED state tests.** Use `DevJumpState.make(city:)` as the base for Country 1 battle/camp/map cases, then mutate only fixture-specific gold, building slots, stage status, and pending result. Pin:
  - battle City 3 / 4,200 gold / Barracks L2 + Archery L1;
  - camp empty City 5 / 1,000 gold;
  - camp occupied City 5 / six authored lots;
  - map completed=3 / pending-next-map state;
  - country complete completed=15;
  - live result +640 / 74s / Infantry MVP / 6 sent / 1 lost / both achievements;
  - idle result +640 / no MVP / zero achievements.
- [ ] **Step 3: RED controller test.** No arg leaves an existing store unchanged; valid arg overwrites development/test save and routes through `presentSceneForCurrentStage(in:preferredTab:)`. Pending Conquest fixtures land on Battle.
- [ ] **Step 4: Implement all new symbols inside `#if DEBUG` and install the explicit launch hook before normal initial routing.** Keep trigger separate from the five-tap DevJump gesture.
- [ ] **Step 5: GREEN + commit.**

```bash
git add Pyxis/ForgedVisualFixture.swift Pyxis/GameViewController.swift \
  PyxisTests/ForgedVisualFixtureTests.swift PyxisTests/GameViewControllerTests.swift
git commit -m "test: add Forged visual fixtures"
```

**Checkpoint A:** review Tasks 1–3 as the foundation slice before changing any screen.

---

## Task 4: Add Battle projection/layout/HUD with a real field budget

**Files:** new `BattleChromeLayout.swift`, `BattleHUDNode.swift`, focused tests.

**Layout constants:**

```swift
static let minimumBattlefieldHeight: CGFloat = 416
static let compactMinimumBattlefieldHeight: CGFloat = 340
```

At 393×852, `battlefieldFrame.height` must be 424...440. `manualCountFrame` is contained inside `deployFrame`; lane chips are overlay frames inside the upper battlefield and do not subtract field height.

- [ ] **Step 1: RED geometry tests at 375×667, 393×852, and current iPad fixture.** Reference asserts: side margin 16, five 56 pt visual medallions with ≥44 hits, Deploy/tab width 361, field 424...440, `BattlefieldLayout.compute(...).isVisible == true`. Compact asserts field ≥340 and visible.
- [ ] **Step 2: RED derivation guard.** Assert `minimumBattlefieldHeight == 416` and document test arithmetic `144 + (144*1.04+14) + 108` rounds up to 416.
- [ ] **Step 3: RED Infantry projection.** City 1 empty → Infantry L1 available, Archer/Cavalry/Mage/Siege locked 2/5/8/11. City 5 empty → Infantry L1, Archer/Cavalry unbuilt, Mage/Siege locked 8/11. Built Barracks/Archery use highest existing level.
- [ ] **Step 4: RED tab projection.** `manualCount == 0` enables all; positive manual living count enables Battle only. Camp attention still follows recommendation independently of enabled state.
- [ ] **Step 5: Implement projection ordering:** call `manualSoldierLevel(for:)` first; only nil falls through to unlocked/unbuilt/locked. Reuse trait/recommendation APIs.
- [ ] **Step 6: Implement pure layout bottom-up.** Tab → Deploy (including count) → medallions → field → objective/top bands. Lane chips are overlays within field. Return nil if required hit frames, compact/reference field floor, or safe content fails.
- [ ] **Step 7: Implement `BattleHUDNode` as a fixed tree.** No store/router/combat/Settings ownership; it renders content and returns select/deploy/tab/requirement actions only.
- [ ] **Step 8: Launch `battle` fixture at 393×852 and compare geometry/hierarchy against `battle.png` before commit.**
- [ ] **Step 9: GREEN + commit.**

---

## Task 5: Cut `BattleScene` over and wire the existing gear/gate

**Files:** `BattleScene.swift`, `GameViewController.swift`, existing tests.

- [ ] **Step 1: RED fit-failure test.** Supported size starts `isBattleChromeFitFailed == false`; forced unsupported size sets true + router `.unsupportedGeometry`; supported resize clears it.
- [ ] **Step 2: RED controller gate test.** `refreshLayoutSupport` gates when either Battle chrome or Conquest fit flag is true.
- [ ] **Step 3: RED one-gear test.** Exactly one `SettingsGearNode.semanticName`; `resolvedHitFrame == layout.settingsFrame`; tapping it still opens the same controller modal and pauses Battle. HUD has no Settings action.
- [ ] **Step 4: RED interaction tests.** Infantry fallback deploy works, unbuilt feedback does not route, locked Mage reports City 8, manual squad disables Camp/Map tabs and direct guards remain intact.
- [ ] **Step 5: Replace old manual dropdown/Spawn/World/Build HUD with `BattleHUDNode`.** Keep combat, battlefield, effects, feedback, milestones, Conquest, persistence untouched.
- [ ] **Step 6: Feed `BattlefieldLayout` the field frame from `BattleChromeLayout`; set/clear `isBattleChromeFitFailed` around nil/success.**
- [ ] **Step 7: Apply `settingsFrame` to `feedbackSettingsController.gear`.**
- [ ] **Step 8: Launch `battle` and `battle-blocked` at 393×852; fix parity before commit. GREEN + commit.**

```bash
git add Pyxis/BattleScene.swift Pyxis/GameViewController.swift \
  PyxisTests/BattleSceneTests.swift PyxisTests/GameViewControllerTests.swift
git commit -m "feat: apply Forged Battle chrome"
```

**Checkpoint B:** review foundation + completed Battle before Camp/Map.

---

## Task 6: Replace Camp controls with five-option builder and inspector

**Files:** new `CampChromeLayout.swift`, `CampSelectionNode.swift`, `BuildingViewScene.swift`, focused/existing tests.

- [ ] **Step 1: RED projection.** `BuildingType.allCases` yields exactly five options in enum order. State precedence: locked → capped → available/unaffordable. Recommendation emphasis only when slot/type/action matches.
- [ ] **Step 2: RED geometry.** 393 reference and edge lots: every build hit ≥44, clears tab/safe edge; occupied inspector contains art/name/level/lot/produced soldier/upgrade cost/action.
- [ ] **Step 3: RED mutation/settlement.** Valid build/upgrade delegates once and saves once; invalid states consume with existing feedback. Settlement conquest leaves pending result; a requested Map then restores Battle through Task 2.
- [ ] **Step 4: Implement pure selection/layout/node.** Reuse `PanelNode`, existing building assets, mutations, recommendation policy. No second economy path.
- [ ] **Step 5: Cut `BuildingViewScene` over.** Keep backdrop/25 lots/selection/lifecycle/store/feedback/Settings. Remove old palette/action panel/recommendation row/buttons only after replacement paths exist. Apply existing gear frame from Camp layout.
- [ ] **Step 6: Launch `camp-empty` and `camp-occupied` at 393×852; fix parity, GREEN, commit.**

---

## Task 7: Rework Map with computed budget before rendering the large card

**Files:** existing `CountryMapLayout`, scene, scout-card content/layout/node, all Map tests.

### Broad geometry constants

```swift
static let tabBarHeight: CGFloat = 72
static let preferredPhoneInformationHeight: CGFloat = 164
static let preferredPadInformationHeight: CGFloat = 140
static let minimumCompactInformationHeight: CGFloat = 48
static let minimumIllustratedMapHeight: CGFloat = 431
static let minimumCityCenterDistance: CGFloat = 45
```

`informationRegionHeight` is no longer a fixed `layoutClass` property.

- [ ] **Step 1: RED budget tests.** With current title/safe gaps, assert resolved card/map heights:
  - 375×667 / zero insets → card 48, illustrated map 431;
  - 375×812 / 50/34 → card 133, illustrated map 431;
  - 393×852 / 59/34 → card 164, illustrated map 431;
  - pad fixtures → card 140 where budget permits.
  If remaining card budget <48, result is unsupported.
- [ ] **Step 2: RED transform arithmetic.** Compute canonical authored minimum center distance from `CountryMapLayoutDefinition.country1.cityAnchors`; scale is max(width-fill, height-fill, scale needed for 45 pt closest centers). Build city ±22 + route-stroke vertical interaction envelope and center that envelope vertically in the illustrated region while keeping bitmap horizontally centered/aspect ratio unchanged.
- [ ] **Step 3: Pin reference numeric proof.** At 393×852 / 59/34 / card164:
  - illustrated height = 431;
  - closest city centers ≥45.0;
  - minimum city-target headroom ≥8.0 (expected ~8.3);
  - minimum route-stroke headroom ≥27.0;
  - every 44×44 target and all 18 routes contained.
- [ ] **Step 4: RED content tests.** Attackable/current/completed/locked/country-complete projections are scene-selection driven and do not mutate state.
- [ ] **Step 5: RED duplicate-control deletion.** Remove expectations for `showsCurrentCityControl`/`currentCityControlFrame`; scene contains no `countryMapCurrentCityButton`. Current selected city uses card `RETURN`.
- [ ] **Step 6: RED short-phone card.** For a 48 pt card, `CountryMapScoutCardLayout` returns a horizontal compact summary with city identity/status + ≥44 primary action. Tapping informational body still reaches existing flavor/details feedback; no scroll/pan feature is added.
- [ ] **Step 7: Implement broad layout exactly as tested.** Do not aspect-fit/letterbox. Do not use the previous 236/300 values. Keep fail-closed city/route validation.
- [ ] **Step 8: Extend existing card owners only.** Reference/mini/pad card layouts may use richer vertical/horizontal arrangements; same content/state/action authority.
- [ ] **Step 9: Remove current-city button and add scene-local `selectedCityNumber`.** City tap selects only; March uses existing sequential entry; Return routes to active Battle without restart.
- [ ] **Step 10: Launch `map` and `map-country-complete` at 393×852.** The card is intentionally shallower than the mock; record that as a gameplay-geometry discrepancy rather than enlarging it until targets fail.
- [ ] **Step 11: Run all Map suites GREEN and commit.**

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

**Checkpoint C:** review completed Battle/Camp/Map geometry before report/settings work.

---

## Task 8: Atomically replace Conquest rows with typed tiles

**Files:** `ConquestReportContent.swift`, `ConquestReportLayout.swift`, `ConquestReportNode.swift`, `BattleScene.swift`, existing Conquest/Battle tests.

- [ ] **Step 1: RED four exact result shapes:** live+MVP `[mvp,time,sentLost]`; live-no-MVP `[time,sentLost]`; idle+MVP `[mvp,buildings,sentLost]`; idle-no-MVP `[buildings,sentLost]`. Zero/one/two achievements; no filler.
- [ ] **Step 2: RED layout.** Input accepts tile count 2...3, chip count 0...2. Output has `rewardFrame`, tile frames, optional chips, `continueFrame`, optional country-complete. Zero chips reserve zero chip height.
- [ ] **Step 3: RED gold anchor.** Node gold-effect anchor equals `rewardFrame` center.
- [ ] **Step 4: Replace `summaryLines`, `goldLineIndex`, old row count/frames in one compiling slice.** Keep `BattleResult` coding/finalization unchanged.
- [ ] **Step 5: Rebuild node with three reusable tile and two chip bundles.** Visible copy `MARCH ON`; keep existing Continue hit/acknowledge/save/route/disabled/fresh-restored semantics. No tab bar during report.
- [ ] **Step 6: Launch live/idle fixtures, fix parity, GREEN, commit.**

---

## Task 9: Restyle Settings without renaming its value contract

**Files:** `FeedbackSettingsLayout.swift`, `FeedbackSettingsNode.swift`, existing Settings/controller/scene-modal tests.

**Layout value remains:**

```swift
struct FeedbackSettingsLayout: Equatable {
    let scrimFrame: CGRect
    let panelFrame: CGRect
    let handleFrame: CGRect
    let soundRowFrame: CGRect
    let hapticsRowFrame: CGRect
    let closeFrame: CGRect
}
```

- [ ] **Step 1: RED bottom-sheet geometry at 393×852 / 59/34.** `panelFrame` bottom-sheet aligned, two ≥52 rows, `closeFrame` ≥48, decorative handle contained, no overlap. Keep invalid/non-finite/small failures.
- [ ] **Step 2: RED node/controller/accessibility.** Two icon/title/switch rows + Done. Row centers still produce existing toggle actions; `closeFrame` returns `.close`; independent persistence; accessibility values remain On/Off and focus restores to the one gear.
- [ ] **Step 3: Implement only metrics/rendering.** Keep controller, preferences, adapter, action enum, field names, focus/pause logic. `closeFrame` displays `Done`; no `sheetFrame`/`doneFrame` rename, `UISwitch`, drag behavior, or extra accessible controls.
- [ ] **Step 4: Launch Battle fixture + Settings, fix parity, GREEN, commit.**

**Checkpoint D:** review Conquest/Settings and whole UI before final evidence.

---

## Task 10: Add capture stabilization, parity evidence, Release proof, and coverage gate

**Files:** fixture/Battle tests, UI tests, visual-parity README, `CLAUDE.md`.

- [ ] **Step 1: Add RED/green DEBUG freeze marker:** `-pyxis-freeze-combat`; when present Battle update returns before combat advancement only. No persistence/Settings flag.
- [ ] **Step 2: Add one 393×852 fixture-based UI smoke with screenshot attachments:** Battle normal/blocked, Camp empty/occupied, Map attackable/locked/complete, Conquest live/idle, Settings one-off toggle. XCTest asserts route/state viability, not pixels.
- [ ] **Step 3: Build mandatory parity board.** For each minimum state attach canonical mock, real 393×852 screenshot, 50% overlay, and short deliberate discrepancy note. Map note explicitly records why the computed 164 pt card differs from the taller mock.
- [ ] **Step 4: Document ownership in `CLAUDE.md`:** three scenes, stage router, shared tabs/material, Battle/Camp pure layouts, Map computed geometry, one Settings gear, DEBUG fixtures, shared combat deferred.
- [ ] **Step 5: Run full verification:**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO

swiftlint lint --no-cache
git diff --check origin/main...HEAD
```

- [ ] **Step 6: Release compile-out proof:**

```bash
rm -rf /tmp/PyxisForgedRelease
xcodebuild build -project Pyxis.xcodeproj -scheme Pyxis \
  -configuration Release -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/PyxisForgedRelease
APP_BINARY=/tmp/PyxisForgedRelease/Build/Products/Release-iphonesimulator/Pyxis.app/Pyxis
! strings "$APP_BINARY" | grep -F -- '-pyxis-forged-fixture'
! strings "$APP_BINARY" | grep -F -- '-pyxis-freeze-combat'
```

- [ ] **Step 7: Check Codecov statuses after CI.** Both project and patch must be ≥90%, threshold 0, blocking. If patch is lower, inspect Codecov uncovered lines and add focused tests that execute those render-node branches; do not exclude files, add `nocov`, or weaken configuration.
- [ ] **Step 8: Commit final evidence/test/docs slice.**

```bash
git add Pyxis/ForgedVisualFixture.swift Pyxis/BattleScene.swift \
  PyxisTests/ForgedVisualFixtureTests.swift PyxisTests/BattleSceneTests.swift \
  PyxisUITests/PyxisUITests.swift docs/visual-parity/forged-ui/README.md CLAUDE.md
git commit -m "test: verify Forged gameplay UI parity"
```

## Final Plan Self-Review

Before runtime implementation starts, confirm this plan still states all of the following:

- one runtime PR, with checkpoint reviews rather than multi-PR delivery;
- no `ForgedSurfaceNode`; `PanelNode.Style` is state-only and has no unused danger/migration case;
- `presentSceneForCurrentStage(in:preferredTab:)` is the sole pending/stage routing authority;
- Battle Camp/Map tabs are disabled while manual soldiers live;
- Infantry empty-grid fallback is available L1;
- reference Battle field is 424...440 and never below regular 416;
- Map does not use 236/300; reference card164 + illustrated431 + center distance45/headroom≥8 are pure tests;
- current-city Map button is deleted;
- fixtures use `DevJumpState` for Country 1 baseline construction;
- Conquest rows/gold index are removed atomically;
- Settings keeps `panelFrame`/`closeFrame` names;
- Risks section and actionable Codecov fallback are present;
- all five exact canonical PNGs are present before runtime implementation starts;
- canonical mock/real/overlay evidence is required before leaving Draft.

---

## Task 11: Correct Battle to the canonical 393×852 reference after visual rejection

**User-approved correction:** The prior Battle palette pass was rejected because the composition, information density, icon rendering, and material behavior still visibly diverged from `docs/visual-parity/forged-ui/battle.png`. Treat the exact HTML-derived reference below as binding visual data while preserving gameplay behavior, hit targets, accessibility, routing, and state ownership.

**Files:** `BattleChromeLayout.swift`, `BattleHUDNode.swift`, `BattleScene.swift`, `GameUIComponents.swift`, `GameplayTabBarNode.swift`, `SettingsGearNode.swift`, and focused existing tests. Touch fewer files if the existing owners can express the correction.

- [ ] **Step 1: RED exact reference geometry at 393×852.** Pin the canonical bands in full-screen top-origin coordinates: resource/gear `top 56, height 46, side margin 16`; city band `top 112`; recommendation `top 168, height 48`; medallions `bottom 154, height 56`; Deploy `bottom 90, height 58`; tab shell `bottom 0, height 82`. The battlefield between the recommendation and medallion bands remains 424...440 pt and never below the existing 416 pt regular minimum. Pin the selected tab tile at 96×52 inside the 82 pt shell and every interactive hit at ≥44×44.
- [ ] **Step 2: RED information hierarchy.** Pin separate city progress and 21 pt uppercase city-title labels, a 14 pt HP bar without the redundant numeric HP label, one compact recommendation row, and portrait-led medallions with no soldier-type prose. Favorable/disadvantaged multipliers and lock/city requirements live only in the bottom medallion pill. Derive recommendation build/upgrade level detail from the existing city state; do not add or change game rules.
- [ ] **Step 3: RED transparency/material checks.** Cream SF-symbol textures must preserve transparent corners. The gold indicator must render as a smooth coin rather than `gold-burst`. Forged panels use continuous top-to-bottom gradients rather than a solid fill plus rectangular half-sheen. The Battle atmosphere reproduces the reference vertical warm grade and inset vignette instead of a uniform overlay.
- [ ] **Step 4: Implement through current owners only.** Reuse `PanelNode`, `BattleChromeLayout`, `BattleHUDNode`, `GameplayTabBarNode`, and the existing gear. Use native CoreGraphics/UIKit/SpriteKit rendering; add no dependency, generic styling framework, new asset pipeline, or duplicate interaction owner.
- [ ] **Step 5: GREEN focused tests and lint.** Run the affected layout/HUD/component/tab/Battle suites serially, targeted SwiftLint, and `git diff --check`.
- [ ] **Step 6: Launch the deterministic Battle fixture at 393×852.** Capture a fresh native screenshot, rebuild the side-by-side and 50% overlay, and inspect the actual rendered pixels. Do not claim parity from source geometry alone.
- [ ] **Step 7: Commit the correction as one reviewed slice.**

## Task 12: Close the remaining Forged Battle material and hierarchy gap

**User-approved correction:** The Task 11 runtime still visibly diverges from the exact `3b · FORGED` prototype. Keep its accepted outer-band geometry and correct the remaining context-specific material, internal alignment, medallion-state, verdict, progress, tab-opacity, and vignette differences without changing gameplay or fixture truth.

- [ ] Follow the durable SDD brief at `.superpowers/sdd/2026-08-29-forged-gameplay-ui-redesign-implementation/task-12-brief.md`.
- [ ] Require failing exact-reference readbacks before production edits.
- [ ] Require a fresh 393×852 runtime capture, side-by-side, and overlay before review.
