# HPA-365 Recommended Camp Guidance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add one deterministic Recommended Camp suggestion and one explicit one-tap purchase to Building View while preserving all existing economy, persistence, conquest, and manual-control semantics.

**Architecture:** Add one framework-free `RecommendedCampRecommendation` pure value beside Building View. It projects current authored trait/building/unlock/cap/cost state into `Ready`, `Save for`, or `noAction`. `BuildingViewScene` renders a two-line row inside the existing action-panel height and, only for a still-current Ready action, delegates exactly once to its existing build/upgrade methods. No planner, service, scoring engine, persistence, reusable recommendation component, or generic framework.

**Tech Stack:** Swift 5, SpriteKit, Foundation-only pure model code, Swift Testing, Xcode/iOS Simulator.

## Global Constraints

- HPA-365 remains a compact assistance heuristic, not a damage-per-gold optimizer.
- Candidate order is `CityDefenseTrait.favorableSoldierTypes`; `Standard Watch` alone uses the Infantry starter fallback.
- First structurally valid favorable action wins.
- If the favored building already exists, upgrade its lowest `(level, slot)` instance. Otherwise build it in the lowest empty lot when unlocked and under cap.
- Affordability changes only `Ready` vs `Save for`; it never selects another action.
- Type cap blocks another build only; it does not block upgrades. Do not invent a max building level.
- Use existing unlock, cost, cap, building/soldier mapping, mutation, save, settlement, conquest, and feedback code.
- One Ready tap invokes at most one existing mutation path.
- Recompute from the mounted scene's current state immediately before Ready delegation; do not add a second store writer/reload protocol.
- Keep today's action-panel heights (`132 / 158 / 176`) so the scenic-grid budget is unchanged.
- Recommendation UI is exactly two single-line labels inside one scene-owned row.
- Every recommendation-row tap is consumed before manual controls/lots. Save-for/noAction are inert.
- No `project.pbxproj` edits; the repository uses `PBXFileSystemSynchronizedRootGroup`.
- New production files: exactly one (`Pyxis/RecommendedCampRecommendation.swift`).
- No new pure layout type, `RecommendedCampNode`, accessibility adapter, service/protocol/manager/registry, persistence field, analytics, or optimization score.
- Run simulator tests with `-parallel-testing-enabled NO`.

---

### Task 1: Add the pure deterministic recommendation

**Files:**
- Create: `Pyxis/RecommendedCampRecommendation.swift`
- Create: `PyxisTests/RecommendedCampRecommendationTests.swift`
- Read/reuse: `Pyxis/CityDefenseTrait.swift`, `Pyxis/CityBuildingState.swift`, `Pyxis/KingdomGameState.swift`, `Pyxis/Country1CityCatalog.swift`

**Interfaces:**
- Produces: `RecommendedCampRecommendation.make(for: KingdomGameState) -> RecommendedCampRecommendation`
- Consumes: current pure model APIs only; no SpriteKit/UIKit or injected policy dependencies.

- [ ] **Step 1: Create normalized current-city test fixtures**

`KingdomGameState.init` normalizes `.battleActive` to `completedCityCount + 1`, so setting only `cityNumberInCountry` silently tests the wrong city. Start the test file with:

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

Use real current catalog cases only:

- City 1: `Standard Watch` -> Infantry fallback.
- City 5: `Arrow Tower` -> `[Infantry, Cavalry]`, both unlocked.
- City 6: `Stone Wall` -> `[Mage, Siege]`, both locked.
- City 7: `Burning Oil` -> `[Archer, Mage, Cavalry]`; Mage is locked but appears after the already-usable Archer candidate.

Do not add a production trait/unlock injection seam.

- [ ] **Step 2: Write RED tests for starter, affordability, order, and no-action behavior**

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

@Test("City 5 authored order chooses Infantry before Cavalry")
func city5PrefersInfantryBeforeCavalry() {
    let state = makeState(city: 5, gold: 100)

    #expect(RecommendedCampRecommendation.make(for: state) == .ready(
        action: .init(kind: .build, buildingType: .barracks, slot: 1, cost: 15),
        reason: "Infantry favored"
    ))
}

@Test("City 6 does not use the Standard Watch fallback when all favorable buildings are locked")
func city6LockedFavorablesReturnNoAction() {
    let state = makeState(city: 6, gold: 1_000)

    #expect(RecommendedCampRecommendation.make(for: state) == .noAction(
        message: "No favorable camp action available."
    ))
}
```

- [ ] **Step 3: Write RED tests for upgrade-first, tie-break, and non-substitution**

Existing favored buildings intentionally choose upgrade before another copy. Lock that deterministic rule without claiming economic optimality:

```swift
@Test("Existing favored building upgrades before building another copy")
func existingFavoredBuildingChoosesUpgrade() {
    let cityState = CityBattleState(slots: [
        4: CityBuilding(type: .barracks, level: 1)
    ])
    let state = makeState(city: 5, gold: 100, cityState: cityState)
    let expectedCost = KingdomGameState.buildingUpgradeCost(for: .barracks, currentLevel: 1)

    #expect(RecommendedCampRecommendation.make(for: state) == .ready(
        action: .init(kind: .upgrade, buildingType: .barracks, slot: 4, cost: expectedCost),
        reason: "Infantry favored"
    ))
}

@Test("Upgrade target is lowest level then lowest slot")
func upgradeTieBreakIsLevelThenSlot() {
    let cityState = CityBattleState(slots: [
        3: CityBuilding(type: .barracks, level: 2),
        7: CityBuilding(type: .barracks, level: 1),
        5: CityBuilding(type: .barracks, level: 1)
    ])
    let state = makeState(city: 5, gold: 100, cityState: cityState)
    let expectedCost = KingdomGameState.buildingUpgradeCost(for: .barracks, currentLevel: 1)

    #expect(RecommendedCampRecommendation.make(for: state) == .ready(
        action: .init(kind: .upgrade, buildingType: .barracks, slot: 5, cost: expectedCost),
        reason: "Infantry favored"
    ))
}

@Test("Unaffordable preferred Barracks upgrade does not substitute Stable")
func city5SaveForDoesNotSubstituteLaterCandidate() {
    let cityState = CityBattleState(slots: [
        1: CityBuilding(type: .barracks, level: 3)
    ])
    let state = makeState(city: 5, gold: 28, cityState: cityState)
    let upgradeCost = KingdomGameState.buildingUpgradeCost(for: .barracks, currentLevel: 3)

    #expect(upgradeCost > state.gold)
    #expect(KingdomGameState.buildingBuildCost(for: .stable) <= state.gold)
    #expect(RecommendedCampRecommendation.make(for: state) == .saveFor(
        action: .init(kind: .upgrade, buildingType: .barracks, slot: 1, cost: upgradeCost),
        missingGold: upgradeCost - state.gold,
        reason: "Infantry favored"
    ))
}
```

- [ ] **Step 4: Add remaining RED policy coverage**

Add exact tests for:

- lowest-numbered empty lot when no favored building exists;
- five Barracks at the type cap still choose the lowest `(level, slot)` upgrade;
- non-active stage returns `.noAction(message: "No favorable camp action available.")`;
- identical state returns an identical recommendation;
- City 7 remains Archer-first even though Mage later in the authored list is locked.

The City 7 test exists to prevent the docs from turning today's catalog ordering into a false invariant; it should still expect Archery first because Archer is the first favorable candidate.

- [ ] **Step 5: Run the new suite and confirm RED**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/RecommendedCampRecommendationTests
```

Expected: FAIL because `RecommendedCampRecommendation` does not exist.

- [ ] **Step 6: Implement the minimal pure value**

Create:

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
    case noAction(message: String)

    static func make(for state: KingdomGameState) -> RecommendedCampRecommendation {
        guard state.stageStatus == .battleActive else {
            return .noAction(message: "No favorable camp action available.")
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

            let existing = cityState.slots.compactMap { slot, building -> (Int, CityBuilding)? in
                building.type == buildingType ? (slot, building) : nil
            }

            let action: Action?
            if let target = existing.min(by: { lhs, rhs in
                lhs.1.level == rhs.1.level
                    ? lhs.0 < rhs.0
                    : lhs.1.level < rhs.1.level
            }) {
                action = Action(
                    kind: .upgrade,
                    buildingType: buildingType,
                    slot: target.0,
                    cost: KingdomGameState.buildingUpgradeCost(
                        for: buildingType,
                        currentLevel: target.1.level
                    )
                )
            } else if cityState.buildingCount(for: buildingType) < CityBattleState.maxBuildingsPerType,
                      let emptySlot = CityBattleState.slotRange.first(where: {
                          cityState.building(inSlot: $0) == nil
                      }) {
                action = Action(
                    kind: .build,
                    buildingType: buildingType,
                    slot: emptySlot,
                    cost: KingdomGameState.buildingBuildCost(for: buildingType)
                )
            } else {
                action = nil
            }

            guard let action else { continue }

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

        return .noAction(message: "No favorable camp action available.")
    }
}
```

Do not add economic scoring. Current level changes affect both integer-rounded attack and HP, while builds add spawn sources; HPA-365 intentionally does not collapse those into a speculative scalar optimizer.

- [ ] **Step 7: Run GREEN plus adjacent model tests**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/RecommendedCampRecommendationTests \
  -only-testing:PyxisTests/KingdomGameStateTests
```

Expected: PASS.

- [ ] **Step 8: Commit Task 1**

```bash
git add Pyxis/RecommendedCampRecommendation.swift PyxisTests/RecommendedCampRecommendationTests.swift
git commit -m "feat: add deterministic Recommended Camp policy"
```

---

### Task 2: Pack the two-line row inside the existing action panel

**Files:**
- Modify: `Pyxis/BuildingViewScene.swift`
- Modify: `PyxisTests/BuildingViewSceneTests.swift`

**Interfaces:**
- Consumes: `RecommendedCampRecommendation.make(for:)`
- Produces: scene-owned recommendation row/frame/text plus DEBUG geometry hooks used by Task 3.

- [ ] **Step 1: Add RED rendering tests**

Add Ready copy:

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

Add Save-for using City 1 / 10g:

```swift
#expect(scene.recommendedCampPrimaryTextForTesting == "Recommended Camp · Save for")
#expect(scene.recommendedCampSecondaryTextForTesting
    == "Build Barracks · Lot 1 · Need 5g · Infantry starter")
```

Add noAction using a normalized City 6 state:

```swift
#expect(scene.recommendedCampPrimaryTextForTesting == "Recommended Camp")
#expect(scene.recommendedCampSecondaryTextForTesting
    == "No favorable camp action available.")
```

- [ ] **Step 2: Extend the DEBUG layout snapshot before production layout changes**

Add these frames to `BuildingLayoutFrames`:

```swift
let recommendationRow: CGRect
let recommendationPrimaryLabel: CGRect
let recommendationSecondaryLabel: CGRect
let feedbackLabel: CGRect
```

Keep the existing action-panel, grid, build-button, Upgrade, and Battle frames.

Add DEBUG text accessors:

```swift
var recommendedCampPrimaryTextForTesting: String? { recommendationPrimaryLabel.text }
var recommendedCampSecondaryTextForTesting: String? { recommendationSecondaryLabel.text }
```

- [ ] **Step 3: Add RED fixed-height packing tests at both landscape gates**

Extend `shortLandscapeLayoutKeepsGridBetweenPanelsAndAwayFromButtons` (`568 x 320`) and `compactLandscapeLayoutKeepsGridBetweenPanelsAndAwayFromButtons` (`667 x 375`). For each fixture assert:

```swift
#expect(frames.actionPanel.height == expectedExistingActionHeight)
#expect(frames.actionPanel.contains(frames.recommendationRow))
#expect(frames.recommendationRow.contains(frames.recommendationPrimaryLabel))
#expect(frames.recommendationRow.contains(frames.recommendationSecondaryLabel))
#expect(!frames.recommendationPrimaryLabel.intersects(frames.recommendationSecondaryLabel))
#expect(!frames.recommendationRow.intersects(frames.feedbackLabel))
#expect(!frames.recommendationRow.intersects(frames.upgradeButton))
#expect(!frames.recommendationRow.intersects(frames.battleButton))
#expect(!frames.grid.isEmpty)
#expect(frames.grid.minY > frames.actionPanel.maxY)
#expect(!frames.grid.intersects(frames.recommendationRow))
```

Use `expectedExistingActionHeight = 132` for `568 x 320` and `158` for `667 x 375`.

For every build-button frame also assert no intersection with `recommendationRow`.

Do not add a `fontSize >= 10` short-landscape gate. Horizontal width is not the risky dimension there; label-frame containment and non-overlap are the real acceptance conditions.

- [ ] **Step 4: Run Building View tests and confirm RED**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/BuildingViewSceneTests
```

Expected: FAIL because recommendation nodes/hooks do not exist.

- [ ] **Step 5: Add only scene-owned recommendation nodes**

In `BuildingViewScene` add:

```swift
private let recommendationRow = SKNode()
private let recommendationBackground = SKShapeNode()
private let recommendationPrimaryLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
private let recommendationSecondaryLabel = SKLabelNode(fontNamed: GameUITheme.Font.medium)
private var renderedRecommendation: RecommendedCampRecommendation?
```

Add `ButtonName.recommendedCamp = "recommendedCampCard"`. Name the row/background/labels consistently. Configure them in `buildInterface()` using existing theme/Z-order. Do not create a reusable node class.

- [ ] **Step 6: Keep current action-panel height and repack controls**

Keep:

```swift
let actionHeight: CGFloat = veryShortLandscape ? 132 : (compactHeight ? 158 : 176)
```

After `actionPanel` is positioned, derive its frame from the existing `contentWidth`, `actionCenterY`, and `actionHeight`.

Use:

```swift
let recommendationHeight: CGFloat = veryShortLandscape ? 28 : (compactHeight ? 32 : 36)
let panelVerticalInset: CGFloat = veryShortLandscape ? 2 : 4
let controlGap: CGFloat = veryShortLandscape ? 4 : 5
```

Keep the existing button heights (`24 / 30 / 34`). Pack from bottom upward:

```swift
let panelMinY = actionCenterY - actionHeight / 2
let panelMaxY = actionCenterY + actionHeight / 2

let bottomButtonY = panelMinY + panelVerticalInset + buttonHeight / 2
let secondBuildRowY = bottomButtonY + buttonHeight + controlGap
let firstBuildRowY = secondBuildRowY + buttonHeight + controlGap

let recommendationFrame = CGRect(
    x: size.width / 2 - (contentWidth - 28) / 2,
    y: panelMaxY - panelVerticalInset - recommendationHeight,
    width: contentWidth - 28,
    height: recommendationHeight
)

let firstBuildTop = firstBuildRowY + buttonHeight / 2
let feedbackBandMinY = firstBuildTop + controlGap
let feedbackBandMaxY = recommendationFrame.minY - controlGap
feedbackLabel.position = CGPoint(
    x: size.width / 2,
    y: (feedbackBandMinY + feedbackBandMaxY) / 2
)
```

Use `firstBuildRowY` for palette row 1, `secondBuildRowY` for palette row 2, and `bottomButtonY` for Upgrade/Battle. This intentionally replaces the old fractional Y formulas while keeping the panel height fixed.

The recommendation row is pinned to the panel top. Apply the background locally:

```swift
recommendationRow.position = CGPoint(
    x: recommendationFrame.midX,
    y: recommendationFrame.midY
)
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

Place the two labels around the row-local center using small fixed offsets appropriate to the two-line row. Start with:

```swift
let labelOffset: CGFloat = veryShortLandscape ? 6 : 7
recommendationPrimaryLabel.position = CGPoint(x: 0, y: labelOffset)
recommendationSecondaryLabel.position = CGPoint(x: 0, y: -labelOffset)
```

Set nominal fonts to `11/10` in very-short landscape and `13/12` otherwise. Run existing `fitLabel` horizontally. Do not change `fitLabel` globally and do not add a copy-shortening escape hatch; the pinned copy and label-frame tests are authoritative.

Crucially, leave the existing grid calculation based on the unchanged action-panel top:

```swift
let gridBottom = actionCenterY + actionHeight / 2 + panelGridGap
```

The scenic-grid vertical budget must therefore remain identical to pre-HPA-365 for the same fixture.

- [ ] **Step 7: Render exactly two labels from the pure value**

At the start of `redraw()`:

```swift
let recommendation = RecommendedCampRecommendation.make(for: state)
renderedRecommendation = recommendation
```

Then:

```swift
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

case let .noAction(message):
    recommendationPrimaryLabel.text = "Recommended Camp"
    recommendationSecondaryLabel.text = message
}
```

Keep the existing `feedbackLabel` separate.

- [ ] **Step 8: Store DEBUG geometry and run GREEN**

Record scene frames for the row, both labels, and feedback label in `LayoutFrames` / `BuildingLayoutFrames`.

Run:

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/BuildingViewSceneTests \
  -only-testing:PyxisTests/RecommendedCampRecommendationTests
```

Expected: PASS, including both `568 x 320` and `667 x 375` grid/row/manual-control gates.

- [ ] **Step 9: Commit Task 2**

```bash
git add Pyxis/BuildingViewScene.swift PyxisTests/BuildingViewSceneTests.swift
git commit -m "feat: render Recommended Camp guidance"
```

---

### Task 3: Consume row touches and execute Ready through the existing path

**Files:**
- Modify: `Pyxis/BuildingViewScene.swift`
- Modify: `PyxisTests/BuildingViewSceneTests.swift`

**Interfaces:**
- Consumes: `renderedRecommendation` and `RecommendedCampRecommendation.make(for:)`
- Produces: one explicit `activateRecommendedCamp()` scene action; no new model/persistence API.

- [ ] **Step 1: Add RED Ready-build interaction coverage**

```swift
@Test("Ready recommendation delegates one build through the existing mutation path")
func readyRecommendationBuildsExactlyOnce() throws {
    let store = try makeStore(initialState: KingdomGameState(gold: 30))
    let feedback = BuildingViewFeedbackRecorder()
    let scene = makeScene(store: store, router: RouteSpy(), feedback: feedback)
    let frame = try #require(scene.buildingLayoutFramesForTesting?.recommendationRow)

    scene.handleTouchForTesting(at: center(of: frame))

    let saved = store.load()
    #expect(saved.cityBattleStateForCurrentCity.building(inSlot: 1)?.type == .barracks)
    #expect(saved.gold == 15)
    #expect(feedback.discreteEvents == [.buildingChanged])
}
```

Also assert the scene's next recommendation is now an upgrade for that Barracks, proving the successful existing mutation path redraws/recomputes.

- [ ] **Step 2: Add RED Ready-upgrade coverage**

Seed City 5 with one Barracks and enough gold. Tap the row and assert:

- the projected slot's building level increments exactly once;
- gold falls by `KingdomGameState.buildingUpgradeCost` for that level;
- `.buildingChanged` emits exactly once;
- no second building is created.

- [ ] **Step 3: Add RED Save-for/noAction touch-swallow coverage**

For Save-for (City 1 / 10g) and noAction (normalized City 6):

1. capture state, selected slot, router count, and feedback calls;
2. move one slot container/hit area underneath the recommendation-row center if needed to prove fallthrough would select it;
3. tap the row;
4. assert state unchanged;
5. assert selected slot unchanged;
6. assert router unchanged;
7. assert no `.invalidAction` or other gameplay feedback.

- [ ] **Step 4: Add RED Settings precedence coverage**

Open Settings, tap a point inside the recommendation row, and assert Settings consumes it exactly as the current modal precedence requires. No recommendation mutation may occur.

- [ ] **Step 5: Run focused tests and confirm RED**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/BuildingViewSceneTests
```

Expected: FAIL because recommendation-row input is not wired.

- [ ] **Step 6: Add row hit-testing before manual controls/lots**

Keep current priority:

1. layout/routing gates;
2. open Settings modal;
3. Settings gear;
4. Recommended Camp row;
5. manual build palette;
6. Upgrade;
7. Battle;
8. lot selection.

Add:

```swift
if buttonContains(recommendationRow, point: point) {
    activateRecommendedCamp()
    return
}
```

The unconditional return is the behavior contract for Ready, Save-for, and noAction.

- [ ] **Step 7: Implement current-state revalidation without an external store reload**

```swift
private func activateRecommendedCamp() {
    guard let renderedRecommendation else { return }

    let freshRecommendation = RecommendedCampRecommendation.make(for: state)
    guard freshRecommendation == renderedRecommendation else {
        redraw()
        return
    }

    guard case let .ready(action, _) = freshRecommendation else {
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

Do not call `store.load()` merely to manufacture a second-writer stale-state scenario. Current Building View mutation and lifecycle paths update local `state` and save from the same mounted scene. If a future feature introduces a real concurrent writer, revisit this boundary then.

Do not duplicate result switches, settlement, save ordering, conquest handling, or gameplay feedback. `buildSelectedSlot` / `upgradeSelectedSlot` remain authoritative.

- [ ] **Step 8: Run GREEN plus the load-bearing existing mutation tests**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/BuildingViewSceneTests \
  -only-testing:PyxisTests/RecommendedCampRecommendationTests
```

Specifically confirm existing save-before-feedback and settlement-conquest Building View tests remain PASS.

- [ ] **Step 9: Commit Task 3**

```bash
git add Pyxis/BuildingViewScene.swift PyxisTests/BuildingViewSceneTests.swift
git commit -m "feat: execute Ready camp recommendation"
```

---

### Task 4: Document ownership and run full verification

**Files:**
- Modify: `CLAUDE.md`
- Verify: all HPA-365 production/tests plus existing suite

**Interfaces:**
- No new runtime interface. This task locks scope and validates the integrated slice.

- [ ] **Step 1: Add the concise architecture note**

Document in `CLAUDE.md`:

- `RecommendedCampRecommendation` is a pure Building View assistance projection;
- it is deterministic, non-persisted, and intentionally not an optimizer;
- authored favorable order + existing building state/unlock/cap/cost APIs are authoritative;
- current policy strengthens an existing favored building before another copy; this is a simple heuristic, not a damage/gold guarantee;
- Building View recomputes before explicit Ready execution and delegates to existing mutation methods;
- the row is packed inside the existing action-panel height so scenic-grid space is unchanged;
- no recommendation platform/service should be added without a concrete second consumer.

Do not add broader Building View accessibility work in this ticket; the existing palette/lot controls do not currently have a dedicated accessibility surface.

- [ ] **Step 2: Run scope searches**

```bash
git grep -nE 'Recommendation(Manager|Service|Provider|Protocol|Registry)|recommendedCamp.*Codable|recommendedCamp.*UserDefaults' -- Pyxis PyxisTests || true
```

Expected: no framework/persistence matches.

```bash
git diff --name-only origin/main...HEAD
```

Expected implementation surface:

- `Pyxis/RecommendedCampRecommendation.swift`
- `Pyxis/BuildingViewScene.swift`
- `PyxisTests/RecommendedCampRecommendationTests.swift`
- `PyxisTests/BuildingViewSceneTests.swift`
- `CLAUDE.md`
- paired HPA-365 spec/plan docs

No `Pyxis.xcodeproj/project.pbxproj` change.

- [ ] **Step 3: Run full unit tests**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests
```

Expected: PASS, zero failures.

- [ ] **Step 4: Run full UI tests**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisUITests
```

Expected: PASS, zero failures.

- [ ] **Step 5: Run lint and whitespace checks**

```bash
swiftlint lint --no-cache
git diff --check origin/main...HEAD
```

Expected: SwiftLint exits 0 with no serious findings; diff check is clean.

- [ ] **Step 6: Perform manual smoke**

On smallest supported portrait plus `568 x 320` and `667 x 375` landscape fixtures/device:

- City 1 empty camp -> Infantry starter suggestion.
- City 5 -> Infantry-first authored guidance.
- City 6 empty camp -> no recommendation because Mage/Siege are locked; no Infantry fallback.
- Save-for reports exact missing gold and its row tap does not select a lot or emit invalid feedback.
- Ready tap spends once through existing build/upgrade behavior and immediately shows the next suggestion.
- Manual lot/build/Upgrade/Settings/Battle still work.
- Background/foreground may refresh guidance but never purchases automatically.
- Action-panel height matches pre-feature behavior; scenic grid remains clear above it at both landscape gates.
- Both recommendation label frames remain inside the row and do not overlap.

- [ ] **Step 7: Final acceptance check**

Confirm:

- identical state -> identical recommendation;
- first structurally valid favorable action is deterministic;
- upgrade-first is documented as a heuristic, not an economic optimum;
- unaffordable preferred action remains Save-for;
- locked favorable types never become executable;
- Standard Watch alone gets Infantry fallback;
- one tap spends at most once through existing mutation/save code;
- Save-for/noAction consume touches with no side effects;
- fixed action-panel height preserves scenic-grid budget at `568 x 320` and `667 x 375`;
- label frames fit and do not overlap;
- no persistence, scoring engine, generic recommendation architecture, new layout component, or accessibility expansion was added.

- [ ] **Step 8: Commit final documentation**

```bash
git add CLAUDE.md
git commit -m "docs: document Recommended Camp ownership"
```

## Implementation Outcome

One pure production file plus a focused `BuildingViewScene` extension. The feature adds no new gameplay mechanic, optimizer, persistence field, scene, service layer, reusable UI architecture, or second mutation path. HPA-390 remains the next roadmap implementation after HPA-365; HPA-567 remains the post-366/365/390 campaign validation checkpoint.