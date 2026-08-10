# HPA-365 Recommended Camp Guidance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add one deterministic Recommended Camp suggestion and one explicit one-tap purchase to Building View while keeping every manual building path and all existing economy/persistence semantics unchanged.

**Architecture:** Add one framework-free `RecommendedCampRecommendation` pure value/function beside the Building View feature. It projects existing city trait, building, unlock, cap, and cost state into `Ready`, `Save for`, or `No recommendation`. `BuildingViewScene` renders one compact row and, only for a still-current Ready action, delegates to its existing build/upgrade methods. No new service, protocol, persistence, planner, scoring engine, or generic recommendation layer.

**Tech Stack:** Swift 5, SpriteKit, Foundation-only pure model code, Swift Testing, Xcode/iOS Simulator.

## Global constraints

- HPA-365 is the next HPA-360 player-visible slice after completed HPA-366.
- Candidate order is the current `CityDefenseTrait.favorableSoldierTypes`; `Standard Watch` alone uses Infantry-first fallback.
- First structurally valid favorable action wins. Affordability changes only `Ready` vs `Save for`; it never chooses a different action.
- Existing favorable building -> upgrade the lowest level, tie by lowest slot. No existing building -> build in lowest empty slot.
- Use existing unlock, type-cap, build-cost, upgrade-cost, and soldier/building mapping APIs.
- Type cap blocks another build only; it does not block upgrading an existing building.
- No automatic spending. One Ready tap invokes one existing mutation path at most once.
- Re-read/recompute immediately before a Ready purchase. A changed suggestion refreshes instead of spending.
- Manual lot/build/upgrade/Battle/Settings behavior stays unchanged.
- No `project.pbxproj` edits: the repository uses `PBXFileSystemSynchronizedRootGroup`.
- New production files: exactly one (`RecommendedCampRecommendation.swift`).
- Prefer existing colors, label fitting, `PanelNode`/shape patterns, and test helpers over new UI abstractions.
- Run simulator tests with `-parallel-testing-enabled NO`.

---

## Task 1 — Implement the pure deterministic recommendation

**Files:**
- Create: `Pyxis/RecommendedCampRecommendation.swift`
- Create: `PyxisTests/RecommendedCampRecommendationTests.swift`
- Read/reuse only: `Pyxis/CityDefenseTrait.swift`, `Pyxis/CityBuildingState.swift`, `Pyxis/KingdomGameState.swift`

### 1. Write the failing pure-policy table first

- [ ] Create `RecommendedCampRecommendationTests.swift` using Swift Testing.
- [ ] Add test helpers that construct a `KingdomGameState` for a requested current city and seed `CityBattleState.slots` directly. Keep fixtures explicit; do not introduce production fixture builders.
- [ ] Add these failing tests before production code:

```swift
@Test("Standard Watch recommends the Infantry starter build")
func standardWatchRecommendsInfantryStarterBuild() {
    let state = makeState(city: 1, gold: 15)

    #expect(RecommendedCampRecommendation.make(for: state) == .ready(
        action: .init(kind: .build, buildingType: .barracks, slot: 1, cost: 15),
        reason: "Infantry is the safe starter here."
    ))
}

@Test("Unaffordable preferred action remains Save for")
func unaffordablePreferredActionDoesNotFallThrough() {
    // Use a non-standard city with at least two favorable candidates.
    // Seed the first favorable candidate with an upgrade whose cost is above
    // current gold while a later favorable action would be affordable.
    // Expect Save-for for the first action, not the later action.
}

@Test("Upgrade target is lowest level then lowest slot")
func upgradeTieBreakIsLevelThenSlot() {
    // Same favorable building type in multiple slots with e.g. levels 2, 1, 1.
    // Expect the lower-numbered level-1 slot.
}
```

- [ ] Cover the complete HPA-365 table:
  - identical state -> identical result,
  - Ready build,
  - Save-for same build,
  - existing favorable type -> upgrade rather than a second build,
  - lowest-level/lowest-slot upgrade tie-break,
  - lowest-numbered empty lot for a build,
  - authored favorable order,
  - locked earlier favorable type -> next structurally valid favorable type,
  - unaffordable first valid action -> Save-for without substitution,
  - count-cap state never proposes another build and can still upgrade an existing building,
  - all favorable structural actions invalid -> No recommendation,
  - non-active stage -> No recommendation.

### 2. Run RED

- [ ] Run only the new suite and confirm it fails because the type does not exist:

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/RecommendedCampRecommendationTests
```

Use an available simulator from `-showdestinations` if `iPhone 17` is unavailable.

### 3. Implement one pure value/function

- [ ] Create `Pyxis/RecommendedCampRecommendation.swift` with exactly this feature-sized shape:

```swift
enum RecommendedCampRecommendation: Equatable {
    struct Action: Equatable {
        enum Kind: Equatable {
            case build
            case upgrade
        }

        let kind: Kind
        let buildingType: BuildingType
        let slot: Int
        let cost: Int
    }

    case ready(action: Action, reason: String)
    case saveFor(action: Action, missingGold: Int, reason: String)
    case none(message: String)

    static func make(for state: KingdomGameState) -> RecommendedCampRecommendation {
        // feature-local pure projection only
    }
}
```

- [ ] Implement candidate order:
  - guard `state.stageStatus == .battleActive`, else `.none`;
  - `.standardWatch` -> `[.infantry]`;
  - otherwise use `state.currentCityDefenseTrait.favorableSoldierTypes` unchanged.
- [ ] Resolve candidate `BuildingType` by existing `BuildingType.allCases.first { $0.soldierType == soldierType }`; do not add a second mapping table.
- [ ] Skip locked candidates using `state.isBuildingTypeUnlocked(_:)`.
- [ ] For each candidate in order:
  - collect existing matching `(slot, building)` rows;
  - if non-empty, choose minimum `(building.level, slot)` and create an upgrade action with `KingdomGameState.buildingUpgradeCost`;
  - otherwise require type count below `CityBattleState.maxBuildingsPerType`, choose the first empty `CityBattleState.slotRange` slot, and create a build action with `KingdomGameState.buildingBuildCost`;
  - first structural action stops candidate search.
- [ ] Classify the chosen action only after selection:
  - affordable -> `.ready`;
  - unaffordable -> `.saveFor(missingGold: cost - state.gold)`.
- [ ] Use short feature-local reason copy:
  - Standard Watch -> `Infantry is the safe starter here.`
  - favorable -> `<Soldier> is favored vs <Trait>.`
  - no action -> neutral `No favorable camp action is available.`
- [ ] Do not import SpriteKit/UIKit and do not add protocol/service/manager/scoring/persistence types.

### 4. Run GREEN and commit

- [ ] Run the new suite until green.
- [ ] Run adjacent model tests to catch accidental rule duplication/drift:

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/RecommendedCampRecommendationTests \
  -only-testing:PyxisTests/KingdomGameStateTests
```

- [ ] Commit:

```bash
git add Pyxis/RecommendedCampRecommendation.swift PyxisTests/RecommendedCampRecommendationTests.swift
git commit -m "feat: add deterministic Recommended Camp policy"
```

---

## Task 2 — Render the compact Recommended Camp row without moving manual controls

**Files:**
- Modify: `Pyxis/BuildingViewScene.swift`
- Modify: `PyxisTests/BuildingViewSceneTests.swift`

### 1. Add RED presentation/layout tests

- [ ] Add a representative Ready presentation test to `BuildingViewSceneTests`:

```swift
@Test("Building View renders one Ready Recommended Camp row")
func buildingViewRendersReadyRecommendedCamp() throws {
    let scene = makeScene(
        store: try makeStore(initialState: KingdomGameState(gold: 15)),
        router: RouteSpy()
    )

    #expect(scene.recommendedCampTitleForTesting == "Recommended Camp · Ready")
    #expect(scene.recommendedCampActionForTesting?.contains("Build Barracks") == true)
    #expect(scene.recommendedCampActionForTesting?.contains("Lot 1") == true)
    #expect(scene.recommendedCampReasonForTesting == "Infantry is the safe starter here.")
}
```

- [ ] Add Save-for and No-recommendation rendering assertions using policy fixtures rather than creating separate scene policy logic.
- [ ] Extend the existing `BuildingLayoutFrames` DEBUG snapshot with `recommendationRow`.
- [ ] Across the existing supported Building View layout fixtures, assert:
  - recommendation row is contained by `actionPanel`;
  - recommendation row does not intersect any build button, upgrade button, or Battle button;
  - manual button frames remain within the action panel;
  - grid remains non-empty and does not intersect the recommendation row.
- [ ] Do not add a new exhaustive geometry matrix; reuse the layouts already exercised by `BuildingViewSceneTests`.

### 2. Run RED

- [ ] Run focused Building View tests and confirm the new hooks/row do not exist yet:

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/BuildingViewSceneTests
```

### 3. Add scene-owned row nodes

- [ ] In `BuildingViewScene`, add only scene-local nodes:
  - `recommendationBackground: SKShapeNode`,
  - `recommendationTitleLabel: SKLabelNode`,
  - `recommendationActionLabel: SKLabelNode`,
  - `recommendationReasonLabel: SKLabelNode`.
- [ ] Add `ButtonName.recommendedCamp = "recommendedCampCard"` and name the row/background/labels consistently so the existing scene hit-testing pattern can be reused.
- [ ] Add `private var renderedRecommendation: RecommendedCampRecommendation?`.
- [ ] Configure/add the nodes in `buildInterface()` using existing fonts/colors/Z-order. Do not create a reusable `RecommendedCampNode` class.

### 4. Preserve the existing manual-control geometry

- [ ] Refactor the current action-panel layout into two vertical regions:

```swift
let manualActionHeight: CGFloat = veryShortLandscape ? 132 : (compactHeight ? 158 : 176)
let recommendationHeight: CGFloat = veryShortLandscape ? 36 : (compactHeight ? 44 : 48)
let recommendationGap: CGFloat = 6
let actionHeight = manualActionHeight + recommendationGap + recommendationHeight

let manualActionCenterY = bottomMargin + manualActionHeight / 2
let actionCenterY = bottomMargin + actionHeight / 2
```

- [ ] Keep `actionPanel` bottom anchored at the existing `bottomMargin` and grow it upward.
- [ ] Calculate existing `feedbackLabel`, build palette, upgrade, and Battle positions from `manualActionCenterY` + `manualActionHeight`, preserving their prior absolute bottom-relative placement.
- [ ] Place the recommendation row above the manual frame using the existing button-area horizontal inset (`contentWidth - 28`).
- [ ] Move `gridBottom` only to the enlarged `actionPanel` top + existing `panelGridGap`.
- [ ] Use `fitLabel` for all three row labels. Prefer short copy over wrapping/new text-layout code.
- [ ] Add `recommendationRow` to `LayoutFrames` and its DEBUG projection.

### 5. Recompute and render from the pure value

- [ ] At the start of `redraw()`, assign:

```swift
renderedRecommendation = RecommendedCampRecommendation.make(for: state)
```

- [ ] Render cases without re-deriving policy in the scene:
  - Ready: `Recommended Camp · Ready`, enabled background, exact action/cost, reason.
  - Save-for: `Recommended Camp · Save for`, unavailable/neutral background, exact action/cost + missing gold, reason.
  - None: `Recommended Camp`, `No recommendation`, neutral message.
- [ ] Keep the existing `feedbackLabel` for manual mutation/lifecycle feedback; do not overload it as recommendation state.

### 6. Run GREEN and commit

- [ ] Run `BuildingViewSceneTests` plus the pure recommendation suite.
- [ ] Confirm existing Settings/palette/upgrade/Battle/slot precedence tests remain green.
- [ ] Commit:

```bash
git add Pyxis/BuildingViewScene.swift PyxisTests/BuildingViewSceneTests.swift
git commit -m "feat: render Recommended Camp guidance"
```

---

## Task 3 — Add one-tap Ready execution with stale-state refresh

**Files:**
- Modify: `Pyxis/BuildingViewScene.swift`
- Modify: `PyxisTests/BuildingViewSceneTests.swift`

### 1. Add RED interaction tests

- [ ] Add one successful Ready-build flow that locks the existing save/feedback path:

```swift
@Test("Ready Recommended Camp tap delegates one build through existing mutation path")
func readyRecommendedCampTapBuildsExactlyOnce() throws {
    let store = try makeStore(initialState: KingdomGameState(gold: 30))
    let feedback = BuildingViewFeedbackRecorder()
    let scene = makeScene(store: store, router: RouteSpy(), feedback: feedback)
    let frame = try #require(scene.recommendedCampFrameForTesting)

    scene.handleTouchForTesting(at: center(of: frame))

    let saved = store.load()
    #expect(saved.cityBattleStateForCurrentCity.building(inSlot: 1)?.type == .barracks)
    #expect(saved.gold == 15)
    #expect(feedback.discreteEvents == [.buildingChanged])
}
```

- [ ] Add a representative Ready-upgrade flow and assert the target is the projected lowest-level/lowest-slot building.
- [ ] Add Save-for and No-recommendation taps: no state mutation, no invalid-action feedback.
- [ ] Add the required stale-card regression:
  1. create/render a Ready build recommendation;
  2. load a second copy from the store, perform/save the recommended build externally;
  3. tap the original rendered Ready row;
  4. expect no second gold spend/upgrade;
  5. expect the scene to reload and show the now-current upgrade recommendation.
- [ ] Add one overlap/priority assertion showing an open Settings modal still consumes recommendation-row touches.

### 2. Run RED

- [ ] Run focused scene tests and confirm row taps are inert before implementation.

### 3. Implement one explicit activation method

- [ ] In `handleTouch(at:)`, keep current ordering:
  1. layout/routing gates,
  2. open Settings modal,
  3. Settings gear,
  4. **Recommended Camp row**,
  5. manual build palette,
  6. upgrade,
  7. Battle,
  8. lot selection.
- [ ] Add `activateRecommendedCamp()` with exactly this flow:

```swift
private func activateRecommendedCamp() {
    guard let renderedRecommendation else { return }

    state = store.load()
    let freshRecommendation = RecommendedCampRecommendation.make(for: state)

    guard freshRecommendation == renderedRecommendation else {
        redraw()
        return
    }

    guard case .ready(let action, _) = freshRecommendation else {
        redraw()
        return
    }

    selectedSlot = action.slot
    switch action.kind {
    case .build:
        buildSelectedSlot(action.buildingType)
    case .upgrade:
        upgradeSelectedSlot()
    }
}
```

- [ ] Ready row hit-testing calls this method once. Save-for/None may pass through this method but must return without mutation and without `.invalidAction` feedback.
- [ ] Do not duplicate any result switch, `store.save`, settlement, conquest, or gameplay-feedback logic; `buildSelectedSlot` / `upgradeSelectedSlot` remain the only scene purchase paths.
- [ ] Do not auto-select or auto-execute on redraw, lifecycle, `didMove`, or resize.

### 4. Run GREEN and commit

- [ ] Run the pure policy + full Building View scene suites.
- [ ] Re-run the existing save-before-feedback and settlement-conquest tests specifically; the Recommended Camp path must inherit those semantics rather than bypass them.
- [ ] Commit:

```bash
git add Pyxis/BuildingViewScene.swift PyxisTests/BuildingViewSceneTests.swift
git commit -m "feat: execute Ready camp recommendation"
```

---

## Task 4 — Lock scope, document ownership, and run full verification

**Files:**
- Modify: `CLAUDE.md`
- Verify: all HPA-365 production/tests

### 1. Document the small ownership boundary

- [ ] Add one concise Building View architecture note to `CLAUDE.md`:
  - `RecommendedCampRecommendation` is a pure feature-local projection.
  - it reads current authored trait/building/cost state only;
  - it is not persisted;
  - Building View revalidates before an explicit purchase and delegates to existing build/upgrade mutations;
  - no recommendation platform/service should be added without a concrete second consumer.

### 2. Scope searches

- [ ] Confirm no accidental recommendation framework/persistence was introduced:

```bash
git grep -nE 'Recommendation(Manager|Service|Provider|Protocol|Registry)|recommendedCamp.*Codable|recommendedCamp.*UserDefaults' -- Pyxis PyxisTests || true
```

- [ ] Confirm production changes stay within the intended surface:

```bash
git diff --name-only origin/main...HEAD
```

Expected implementation files are limited to:

- `Pyxis/RecommendedCampRecommendation.swift`
- `Pyxis/BuildingViewScene.swift`
- `PyxisTests/RecommendedCampRecommendationTests.swift`
- `PyxisTests/BuildingViewSceneTests.swift`
- `CLAUDE.md`
- the paired design/plan docs already on the planning branch/implementation branch as appropriate.

No `Pyxis.xcodeproj/project.pbxproj` change.

### 3. Full automated verification

- [ ] Run unit tests with parallel testing disabled:

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests
```

- [ ] Run UI tests:

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisUITests
```

- [ ] Lint and whitespace checks:

```bash
swiftlint lint --no-cache
git diff --check origin/main...HEAD
```

### 4. Manual smoke

- [ ] On smallest supported portrait and landscape fixtures/device:
  - Standard Watch -> Infantry starter card.
  - Counter-trait city -> authored favorable suggestion.
  - Save-for shows exact missing gold and does nothing when tapped.
  - Ready tap spends once, builds/upgrades the shown lot, emits existing construction feedback, and immediately shows the next suggestion.
  - Manual lot/build/upgrade controls still work.
  - Settings still blocks underlying touches.
  - Battle route still works.
  - Background/foreground may refresh recommendation after idle progress but never purchases automatically.

### 5. Final acceptance checklist

- [ ] Identical state produces identical recommendation.
- [ ] One tap spends at most once and only via existing mutation/save code.
- [ ] First favorable action is preserved as Save-for when unaffordable.
- [ ] No locked/disadvantaged/invalid build or missing upgrade target can be executable.
- [ ] Standard Watch uses only the documented Infantry fallback.
- [ ] Manual Building View paths are unchanged.
- [ ] No persistence or recommendation architecture was added.
- [ ] Player-visible row fits supported compact layouts.

- [ ] Commit final docs/verification update:

```bash
git add CLAUDE.md
git commit -m "docs: document Recommended Camp ownership"
```

## Implementation outcome

One pure production file plus a focused Building View slice. No new gameplay mechanic, persistence field, economy rule, scene, service layer, generic planner, or future-facing abstraction. HPA-390 remains the next roadmap implementation after HPA-365; HPA-567 remains the post-366/365/390 campaign validation checkpoint.