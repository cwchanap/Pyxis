# HPA-365 Recommended Camp Guidance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add one deterministic Recommended Camp suggestion and one explicit one-tap purchase to Building View while keeping every manual building path and all existing economy/persistence semantics unchanged.

**Architecture:** Add one framework-free `RecommendedCampRecommendation` pure value/function beside the Building View feature. It projects existing city trait, building, unlock, cap, and cost state into `Ready`, `Save for`, or `No recommendation`. `BuildingViewScene` renders one two-line row above a frozen manual-control region and, only for a still-current Ready action, delegates to its existing build/upgrade methods. All recommendation states consume their row touch. No new service, protocol, persistence, planner, scoring engine, layout type, reusable node, or generic recommendation layer.

**Tech Stack:** Swift 5, SpriteKit, Foundation-only pure model code, Swift Testing, Xcode/iOS Simulator.

## Global constraints

- HPA-365 is the next HPA-360 player-visible slice after completed HPA-366.
- Candidate order is the current `CityDefenseTrait.favorableSoldierTypes`; `Standard Watch` alone uses Infantry-first fallback.
- First structurally valid favorable action wins. Affordability changes only `Ready` vs `Save for`; it never chooses a different action.
- Existing favorable building -> upgrade the lowest level, tie by lowest slot. No existing building -> build in lowest empty slot.
- Use existing unlock, type-cap, build-cost, upgrade-cost, `BuildingType.soldierType`, and `BuildingType.shortDisplayName` APIs.
- Type cap blocks another build only; it does not block upgrading an existing building. Do not invent a max building level.
- No automatic spending. One Ready tap invokes one existing mutation path at most once.
- Re-read/recompute immediately before a recommendation-row tap can spend. A changed suggestion refreshes instead of spending.
- Save-for and No-recommendation row taps are swallowed: no mutation, no `.invalidAction`, no route, no selected-slot change.
- Manual lot/build/upgrade/Battle/Settings behavior stays unchanged.
- The visible recommendation card is exactly two single-line labels on supported layouts. The `568 x 320` fixture must keep both at >= 10 pt after fitting.
- Keep the existing manual action region bottom-relative geometry. Grow the action panel upward only.
- No `project.pbxproj` edits: the repository uses `PBXFileSystemSynchronizedRootGroup`.
- New production files: exactly one (`RecommendedCampRecommendation.swift`).
- Run simulator tests with `-parallel-testing-enabled NO`.

---

## Task 1 — Implement the pure deterministic recommendation

**Files:**
- Create: `Pyxis/RecommendedCampRecommendation.swift`
- Create: `PyxisTests/RecommendedCampRecommendationTests.swift`
- Read/reuse only: `Pyxis/CityDefenseTrait.swift`, `Pyxis/CityBuildingState.swift`, `Pyxis/KingdomGameState.swift`, `Pyxis/Country1CityCatalog.swift`

**Interfaces:**
- Produces `RecommendedCampRecommendation.make(for:)` for `BuildingViewScene`.
- Consumes only current pure model APIs; no SpriteKit/UIKit and no injected policy dependencies.

### 1. Write normalized current-city fixtures first

- [ ] Create `PyxisTests/RecommendedCampRecommendationTests.swift` with this helper. `KingdomGameState.init` normalizes active play to `completedCityCount + 1`; setting only `cityNumberInCountry` would silently test City 1.

```swift
import Testing
@testable import Pyxis

struct RecommendedCampRecommendationTests {
    private func makeState(
        city: Int,
        gold: Int,
        cityState: CityBattleState = CityBattleState(),
        stageStatus: KingdomGameState.StageStatus = .battleActive
    ) -> KingdomGameState {
        let key = CityKey(countryNumber: 1, cityNumber: city)
        return KingdomGameState(
            gold: gold,
            cityNumberInCountry: city,
            completedCityCount: city - 1,
            stageStatus: stageStatus,
            cityBattleStates: [key.storageKey: cityState]
        )
    }
}
```

- [ ] Pin tests to actual current catalog behavior instead of introducing a production trait/unlock injection seam:
  - City 1: `Standard Watch` -> fallback Infantry.
  - City 5: `Arrow Tower` -> `[Infantry, Cavalry]`; both Barracks and Stable are unlocked.
  - City 6: `Stone Wall` -> `[Mage, Siege]`; both are locked at City 6.

The current catalog has no city where an earlier favorable building is locked while a later favorable building is usable. Do not add a synthetic production seam merely to create that case.

### 2. Write the failing policy table

- [ ] Add the City 1 starter and affordability tests:

```swift
@Test("City 1 recommends the Standard Watch Infantry starter")
func city1RecommendsInfantryStarter() {
    let state = makeState(city: 1, gold: 15)

    #expect(RecommendedCampRecommendation.make(for: state) == .ready(
        action: .init(kind: .build, buildingType: .barracks, slot: 1, cost: 15),
        reason: "Infantry starter"
    ))
}

@Test("The same City 1 action becomes Save for when unaffordable")
func city1BuildBecomesSaveFor() {
    let state = makeState(city: 1, gold: 10)

    #expect(RecommendedCampRecommendation.make(for: state) == .saveFor(
        action: .init(kind: .build, buildingType: .barracks, slot: 1, cost: 15),
        missingGold: 5,
        reason: "Infantry starter"
    ))
}
```

- [ ] Add City 5 authored-order and non-substitution tests. A level-3 Barracks costs 33g to upgrade; a Stable build costs 28g, so 28g proves the first unaffordable favorable action is preserved instead of substituting the later affordable candidate.

```swift
@Test("City 5 authored order prefers Infantry before Cavalry")
func city5PrefersInfantryBeforeCavalry() {
    let state = makeState(city: 5, gold: 100)

    #expect(RecommendedCampRecommendation.make(for: state) == .ready(
        action: .init(kind: .build, buildingType: .barracks, slot: 1, cost: 15),
        reason: "Infantry favored"
    ))
}

@Test("City 5 keeps an unaffordable Barracks upgrade instead of affordable Stable")
func city5SaveForDoesNotSubstituteLaterCandidate() {
    let cityState = CityBattleState(slots: [
        1: CityBuilding(type: .barracks, level: 3)
    ])
    let state = makeState(city: 5, gold: 28, cityState: cityState)

    #expect(RecommendedCampRecommendation.make(for: state) == .saveFor(
        action: .init(kind: .upgrade, buildingType: .barracks, slot: 1, cost: 33),
        missingGold: 5,
        reason: "Infantry favored"
    ))
}
```

- [ ] Add the concrete tie-break test:

```swift
@Test("Upgrade tie-break is lowest level then lowest slot")
func upgradeTieBreakIsLevelThenSlot() {
    let cityState = CityBattleState(slots: [
        2: CityBuilding(type: .barracks, level: 1),
        3: CityBuilding(type: .barracks, level: 2),
        7: CityBuilding(type: .barracks, level: 1)
    ])
    let state = makeState(city: 5, gold: 100, cityState: cityState)

    #expect(RecommendedCampRecommendation.make(for: state) == .ready(
        action: .init(kind: .upgrade, buildingType: .barracks, slot: 2, cost: 12),
        reason: "Infantry favored"
    ))
}
```

- [ ] Add the lowest-empty-lot test with two valid City 5 Archery Ranges occupying the first two lots:

```swift
@Test("A build uses the lowest empty lot")
func buildUsesLowestEmptyLot() {
    let cityState = CityBattleState(slots: [
        1: CityBuilding(type: .archeryRange),
        2: CityBuilding(type: .archeryRange)
    ])
    let state = makeState(city: 5, gold: 100, cityState: cityState)

    #expect(RecommendedCampRecommendation.make(for: state) == .ready(
        action: .init(kind: .build, buildingType: .barracks, slot: 3, cost: 15),
        reason: "Infantry favored"
    ))
}
```

- [ ] Add the explicit five-building cap regression:

```swift
@Test("The five-building type cap still allows upgrading an existing favored building")
func typeCapStillAllowsUpgrade() {
    let cityState = CityBattleState(slots: [
        1: CityBuilding(type: .barracks, level: 3),
        2: CityBuilding(type: .barracks, level: 1),
        3: CityBuilding(type: .barracks, level: 1),
        4: CityBuilding(type: .barracks, level: 4),
        5: CityBuilding(type: .barracks, level: 2)
    ])
    let state = makeState(city: 5, gold: 100, cityState: cityState)

    #expect(RecommendedCampRecommendation.make(for: state) == .ready(
        action: .init(kind: .upgrade, buildingType: .barracks, slot: 2, cost: 12),
        reason: "Infantry favored"
    ))
}
```

- [ ] Add the real locked/non-standard fallback regression:

```swift
@Test("City 6 with only locked favorable buildings has no recommendation")
func city6DoesNotFallBackToInfantry() {
    let state = makeState(city: 6, gold: 1_000)

    #expect(RecommendedCampRecommendation.make(for: state) == .none(
        message: "No favorable camp action available."
    ))
}
```

- [ ] Add non-active and determinism tests:

```swift
@Test("Non-active stage has no recommendation")
func nonActiveStageHasNoRecommendation() {
    let state = makeState(
        city: 5,
        gold: 100,
        stageStatus: .cityConqueredPendingMap
    )

    #expect(RecommendedCampRecommendation.make(for: state) == .none(
        message: "No favorable camp action available."
    ))
}

@Test("Identical state produces identical recommendation")
func identicalStateIsDeterministic() {
    let state = makeState(city: 5, gold: 100)
    #expect(RecommendedCampRecommendation.make(for: state)
        == RecommendedCampRecommendation.make(for: state))
}
```

Do not create malformed/no-empty-lot fixtures that `CityBattleState.normalize()` would reject. With current per-type caps and authored favorable sets, “all 25 lots occupied while every favorable type is absent” is not a reachable normalized state.

### 3. Run RED

- [ ] Run the new suite and confirm failure because `RecommendedCampRecommendation` does not exist:

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/RecommendedCampRecommendationTests
```

Use an available simulator from `-showdestinations` if `iPhone 17` is unavailable.

### 4. Implement the pure projection

- [ ] Create `Pyxis/RecommendedCampRecommendation.swift` with this feature-local shape:

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
        guard state.stageStatus == .battleActive else {
            return .none(message: "No favorable camp action available.")
        }

        let trait = state.currentCityDefenseTrait
        let candidates: [SoldierType] = trait == .standardWatch
            ? [.infantry]
            : trait.favorableSoldierTypes
        let cityState = state.cityBattleStateForCurrentCity

        for soldierType in candidates {
            guard let buildingType = BuildingType.allCases.first(where: {
                $0.soldierType == soldierType
            }), state.isBuildingTypeUnlocked(buildingType) else {
                continue
            }

            let existing = cityState.slots.compactMap { slot, building in
                building.type == buildingType ? (slot, building) : nil
            }.min {
                if $0.1.level != $1.1.level {
                    return $0.1.level < $1.1.level
                }
                return $0.0 < $1.0
            }

            let action: Action
            if let existing {
                action = Action(
                    kind: .upgrade,
                    buildingType: buildingType,
                    slot: existing.0,
                    cost: KingdomGameState.buildingUpgradeCost(
                        for: buildingType,
                        currentLevel: existing.1.level
                    )
                )
            } else {
                guard cityState.buildingCount(for: buildingType) < CityBattleState.maxBuildingsPerType,
                      let slot = CityBattleState.slotRange.first(where: {
                          cityState.building(inSlot: $0) == nil
                      }) else {
                    continue
                }
                action = Action(
                    kind: .build,
                    buildingType: buildingType,
                    slot: slot,
                    cost: KingdomGameState.buildingBuildCost(for: buildingType)
                )
            }

            let reason = trait == .standardWatch
                ? "Infantry starter"
                : "\(soldierType.displayName) favored"

            if state.gold >= action.cost {
                return .ready(action: action, reason: reason)
            }
            return .saveFor(
                action: action,
                missingGold: action.cost - state.gold,
                reason: reason
            )
        }

        return .none(message: "No favorable camp action available.")
    }
}
```

- [ ] Keep this file free of SpriteKit/UIKit, persistence, scoring, manager/service/protocol types, and a second soldier/building mapping table.

### 5. Run GREEN and commit

- [ ] Run the pure suite plus adjacent model tests:

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

## Task 2 — Render a two-line row above a frozen manual-control region

**Files:**
- Modify: `Pyxis/BuildingViewScene.swift`
- Modify: `PyxisTests/BuildingViewSceneTests.swift`

**Interfaces:**
- Consumes `RecommendedCampRecommendation.make(for:)` from Task 1.
- Produces one scene-owned recommendation row frame, two labels, and DEBUG inspection hooks used by Task 3.

### 1. Add RED presentation assertions

- [ ] Add Ready copy assertions for the existing City 1 fixture:

```swift
@Test("Building View renders Ready Recommended Camp in two lines")
func buildingViewRendersReadyRecommendedCamp() throws {
    let scene = makeScene(
        store: try makeStore(initialState: KingdomGameState(gold: 15)),
        router: RouteSpy()
    )

    #expect(scene.recommendedCampPrimaryTextForTesting == "Recommended Camp · Ready")
    #expect(scene.recommendedCampSecondaryTextForTesting
        == "Build Barracks · Lot 1 · 15g · Infantry starter")
}
```

- [ ] Add Save-for copy using City 1 with 10g and assert:

```swift
#expect(scene.recommendedCampPrimaryTextForTesting == "Recommended Camp · Save for")
#expect(scene.recommendedCampSecondaryTextForTesting
    == "Build Barracks · Lot 1 · Need 5g · Infantry starter")
```

- [ ] Add No-recommendation copy using a normalized City 6 state and assert:

```swift
#expect(scene.recommendedCampPrimaryTextForTesting == "Recommended Camp")
#expect(scene.recommendedCampSecondaryTextForTesting
    == "No favorable camp action available.")
```

- [ ] Extend the existing DEBUG `BuildingLayoutFrames` with `manualRegion` and `recommendationRow`. Add DEBUG accessors for primary/secondary text and font sizes.

### 2. Add RED packing tests before scene implementation

- [ ] Extend the existing `568 x 320` short-landscape test. After the row exists, require:

```swift
#expect(frames.actionPanel.contains(frames.recommendationRow))
#expect(frames.recommendationRow.minY >= frames.manualRegion.maxY)
#expect(frames.grid.minY > frames.actionPanel.maxY)
#expect(scene.recommendedCampPrimaryFontSizeForTesting >= 10)
#expect(scene.recommendedCampSecondaryFontSizeForTesting >= 10)
```

`manualRegion` is a DEBUG frame for the unchanged old action-panel region, not a new production layout type.

- [ ] For every build button frame plus upgrade/Battle:

```swift
for frame in frames.buildButtonFrames.values {
    #expect(!frames.recommendationRow.intersects(frame))
}
#expect(!frames.recommendationRow.intersects(frames.upgradeButton))
#expect(!frames.recommendationRow.intersects(frames.battleButton))
```

- [ ] Reuse the current compact-landscape and portrait fixtures to assert the row is contained, grid remains non-empty, and manual controls remain inside the panel. Do not add a new geometry matrix.

### 3. Run RED

- [ ] Run focused Building View tests and confirm the new row/hooks do not exist:

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/BuildingViewSceneTests
```

### 4. Add only scene-owned row nodes

- [ ] Add these nodes to `BuildingViewScene`:
  - `recommendationRow = SKNode()`
  - `recommendationBackground = SKShapeNode()`
  - `recommendationPrimaryLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)`
  - `recommendationSecondaryLabel = SKLabelNode(fontNamed: GameUITheme.Font.medium)`

- [ ] Add `ButtonName.recommendedCamp = "recommendedCampCard"`, name the row/background/labels with that semantic button name, and add `private var renderedRecommendation: RecommendedCampRecommendation?`.

- [ ] Configure/add the nodes in `buildInterface()` with current theme/Z-order. Do not create `RecommendedCampNode`, a pure layout type, or another reusable UI layer.

### 5. Freeze existing manual-control positions while growing the panel upward

- [ ] Replace the old `actionHeight` calculation with:

```swift
let manualActionHeight: CGFloat = veryShortLandscape ? 132 : (compactHeight ? 158 : 176)
let recommendationHeight: CGFloat = veryShortLandscape ? 28 : (compactHeight ? 36 : 40)
let recommendationGap: CGFloat = veryShortLandscape ? 4 : 6
let actionHeight = manualActionHeight + recommendationGap + recommendationHeight

let manualActionCenterY = bottomMargin + manualActionHeight / 2
let actionCenterY = bottomMargin + actionHeight / 2
```

- [ ] Keep `actionPanel` bottom anchored exactly as before.

- [ ] Preserve the legacy positions by changing only their reference region:

```swift
feedbackLabel.position = CGPoint(
    x: size.width / 2,
    y: manualActionCenterY + manualActionHeight * 0.33
)

let buildTopY = manualActionCenterY + manualActionHeight * 0.13
let bottomButtonY = manualActionCenterY - manualActionHeight * 0.34
```

Do not calculate these from enlarged `actionCenterY` / `actionHeight`.

- [ ] Define the manual region and recommendation row geometry:

```swift
let manualRegion = CGRect(
    x: size.width / 2 - contentWidth / 2,
    y: bottomMargin,
    width: contentWidth,
    height: manualActionHeight
)
let recommendationFrame = CGRect(
    x: size.width / 2 - (contentWidth - 28) / 2,
    y: manualRegion.maxY + recommendationGap,
    width: contentWidth - 28,
    height: recommendationHeight
)
```

- [ ] Apply `recommendationFrame` without adding another layout type:

```swift
recommendationRow.position = CGPoint(x: recommendationFrame.midX, y: recommendationFrame.midY)
recommendationBackground.path = CGPath(
    roundedRect: CGRect(
        x: -recommendationFrame.width / 2,
        y: -recommendationFrame.height / 2,
        width: recommendationFrame.width,
        height: recommendationFrame.height
    ),
    cornerWidth: 9,
    cornerHeight: 9,
    transform: nil
)
```

Place the two labels locally above/below the row center with a small gap.

- [ ] Reset nominal font sizes on every `layoutInterface()` call:
  - very-short: primary 11, secondary 10;
  - other layouts: primary 13, secondary 12.

- [ ] Run existing `fitLabel` on both labels. If the short-landscape test would push either below 10, shorten the row copy; do not add wrapping or change `fitLabel` globally.

- [ ] Move `gridBottom` only to `actionPanel.maxY + panelGridGap`. Keep the existing `minimumSlotSize` rule unchanged.

- [ ] Store `manualRegion` and `recommendationRow` in the existing layout snapshot for DEBUG tests.

### 6. Render exactly two lines from the pure value

- [ ] At the start of `redraw()`, bind a non-optional local before switching:

```swift
let recommendation = RecommendedCampRecommendation.make(for: state)
renderedRecommendation = recommendation

switch recommendation {
case let .ready(action, reason):
    recommendationPrimaryLabel.text = "Recommended Camp · Ready"
    recommendationSecondaryLabel.text =
        "\(action.kind == .build ? "Build" : "Upgrade") "
        + "\(action.buildingType.shortDisplayName) · Lot \(action.slot) · "
        + "\(action.cost)g · \(reason)"

case let .saveFor(action, missingGold, reason):
    recommendationPrimaryLabel.text = "Recommended Camp · Save for"
    recommendationSecondaryLabel.text =
        "\(action.kind == .build ? "Build" : "Upgrade") "
        + "\(action.buildingType.shortDisplayName) · Lot \(action.slot) · "
        + "Need \(missingGold)g · \(reason)"

case let .none(message):
    recommendationPrimaryLabel.text = "Recommended Camp"
    recommendationSecondaryLabel.text = message
}
```

- [ ] Keep `feedbackLabel` separate for manual/lifecycle feedback.

### 7. Run GREEN and commit

- [ ] Run `BuildingViewSceneTests` and the pure recommendation suite. Confirm the existing short/compact landscape, Settings, palette, upgrade, Battle, and slot tests stay green.

- [ ] Commit:

```bash
git add Pyxis/BuildingViewScene.swift PyxisTests/BuildingViewSceneTests.swift
git commit -m "feat: render Recommended Camp guidance"
```

---

## Task 3 — Consume all row touches and execute only a still-current Ready action

**Files:**
- Modify: `Pyxis/BuildingViewScene.swift`
- Modify: `PyxisTests/BuildingViewSceneTests.swift`

**Interfaces:**
- Consumes `renderedRecommendation` and Task 2 row frame.
- Delegates mutations only to existing `buildSelectedSlot(_:)` / `upgradeSelectedSlot()`.

### 1. Add RED interaction tests

- [ ] Add Ready build execution:

```swift
@Test("Ready Recommended Camp tap delegates exactly one existing build")
func readyRecommendedCampTapBuildsExactlyOnce() throws {
    let store = try makeStore(initialState: KingdomGameState(gold: 30))
    let feedback = BuildingViewFeedbackRecorder()
    let scene = makeScene(store: store, router: RouteSpy(), feedback: feedback)
    let frame = try #require(scene.recommendedCampFrameForTesting)

    scene.handleTouchForTesting(at: CGPoint(x: frame.midX, y: frame.midY))

    let saved = store.load()
    #expect(saved.cityBattleStateForCurrentCity.building(inSlot: 1)?.type == .barracks)
    #expect(saved.gold == 15)
    #expect(feedback.discreteEvents == [.buildingChanged])
}
```

- [ ] Add Ready upgrade with a normalized City 5 state containing Barracks at slots 2/3/7 with levels 1/2/1. Tap once and assert slot 2 becomes level 2 while slot 7 remains level 1.

- [ ] Add Save-for and No-recommendation row tests. Before tapping, select lot 9. After tapping the recommendation row assert:
  - saved state is unchanged;
  - `selectedSlotForTesting == 9`;
  - no `.invalidAction` or construction feedback.

- [ ] Prove the row consumes touches rather than merely missing other hit targets. In the Save-for test, move slot 1 under the row center:

```swift
let slotNode = try #require(scene.childNode(withName: "//buildingSlot-1"))
let parent = try #require(slotNode.parent)
slotNode.position = parent.convert(
    CGPoint(x: frame.midX, y: frame.midY),
    from: scene
)
scene.handleTouchForTesting(at: CGPoint(x: frame.midX, y: frame.midY))
#expect(scene.selectedSlotForTesting == 9)
```

- [ ] Add stale-card regression:
  1. render City 1 Ready Barracks build with 30g;
  2. load another state copy, build Barracks slot 1, and save it externally;
  3. tap the stale row in the original scene;
  4. assert saved gold remains 15 and Barracks stays level 1 (no second action);
  5. assert the scene refreshes to the current Barracks upgrade recommendation.

- [ ] Add Settings precedence by opening Settings, tapping the recommendation row, and asserting no building/gold change.

### 2. Run RED

- [ ] Run focused `BuildingViewSceneTests` and confirm recommendation-row taps are still inert/unhandled.

### 3. Insert recommendation input at one precedence point

- [ ] Keep `handleTouch(at:)` ordering:
  1. layout/routing gates;
  2. visible Settings modal;
  3. Settings gear;
  4. recommendation row;
  5. build palette;
  6. upgrade;
  7. Battle;
  8. lot selection.

- [ ] Use one hit frame for **all** recommendation states and always return after a hit:

```swift
if buttonContains(recommendationRow, point: point) {
    activateRecommendedCamp()
    return
}
```

### 4. Implement one activation method

- [ ] Add:

```swift
private func activateRecommendedCamp() {
    guard let renderedRecommendation else {
        return
    }

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

This means Save-for/None reload/recompute/redraw but do not change `selectedSlot`, emit invalid feedback, or mutate state. A stale row refreshes without spending.

- [ ] Do not duplicate result switches, `store.save`, settlement, conquest, or gameplay-feedback logic. `buildSelectedSlot` / `upgradeSelectedSlot` remain the only scene purchase paths.

- [ ] Do not auto-select or auto-execute on redraw, lifecycle, `didMove`, or resize.

### 5. Run GREEN and commit

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

### 1. Document the ownership boundary

- [ ] Add one concise Building View architecture note to `CLAUDE.md`:
  - `RecommendedCampRecommendation` is a pure feature-local projection;
  - it reads current authored trait/building/unlock/cap/cost state only;
  - it is not persisted;
  - Building View renders a two-line row above the unchanged manual-control region;
  - all row states consume touches, but only a still-current Ready action may mutate;
  - Building View revalidates before purchase and delegates to existing build/upgrade mutations;
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
- the paired HPA-365 design/plan docs.

No `Pyxis.xcodeproj/project.pbxproj` change.

### 3. Focused acceptance verification

- [ ] Run the two feature suites first:

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/RecommendedCampRecommendationTests \
  -only-testing:PyxisTests/BuildingViewSceneTests
```

- [ ] Confirm the focused run includes:
  - City 1 / 5 / 6 normalized fixtures;
  - five-building upgrade-at-cap row;
  - short-landscape two-line >= 10 pt gate;
  - Save-for/None touch swallow with selected slot unchanged;
  - stale-card no-second-spend;
  - existing save-before-feedback and settlement-conquest behavior.

### 4. Full automated verification

- [ ] Run unit tests:

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

### 5. Manual smoke

- [ ] On the smallest supported portrait and landscape layouts:
  - City 1 -> Infantry starter card.
  - City 5 -> Infantry/Barracks before Cavalry/Stable.
  - City 6 empty camp -> No recommendation; no neutral Infantry fallback.
  - Save-for shows exact missing gold; tapping it leaves gold and selected lot unchanged.
  - Ready tap spends once, builds/upgrades the shown lot, emits existing construction feedback, and immediately shows the next suggestion.
  - recommendation copy remains two lines and readable in `568 x 320` short landscape.
  - manual lot/build/upgrade controls still work.
  - Settings still blocks underlying touches.
  - Battle route still works.
  - background/foreground may refresh recommendation after idle progress but never purchases automatically.

### 6. Final acceptance checklist

- [ ] Identical state produces identical recommendation.
- [ ] One tap spends at most once and only via existing mutation/save code.
- [ ] First favorable action is preserved as Save-for when unaffordable.
- [ ] City 6 never proposes locked Mage/Siege or the Standard Watch Infantry fallback.
- [ ] Five favored buildings still yield an upgrade recommendation; no max level was invented.
- [ ] Save-for/None row taps are consumed with no state, feedback, route, or selected-slot side effect.
- [ ] Manual Building View paths keep their previous bottom-relative positions and behavior.
- [ ] `568 x 320` keeps both row labels >= 10 pt, a non-empty grid, and no control intersections.
- [ ] No persistence or recommendation architecture was added.

- [ ] Commit final docs/verification update:

```bash
git add CLAUDE.md
git commit -m "docs: document Recommended Camp ownership"
```

## Implementation outcome

One pure production file plus a focused Building View slice. No new gameplay mechanic, persistence field, economy rule, scene, service layer, generic planner, reusable layout/component type, or future-facing abstraction. HPA-390 remains the next roadmap implementation after HPA-365; HPA-567 remains the post-366/365/390 campaign validation checkpoint.