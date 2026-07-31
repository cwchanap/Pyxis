# Compact Conquest Report Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** Self-reviewed and ready for execution.

**Goal:** Replace the legacy gold-only conquest popup with a compact report rendered from persisted `pendingBattleResult`, restore it across relaunch and Building View handoff, and acknowledge/save/route exactly once.

**Architecture:** Pure helpers own whole-point text fitting, compact-number formatting, result projection, and safe-area geometry. `ConquestReportNode` owns only SpriteKit rendering, Continue hit testing, and the gold-effect anchor. `BattleScene` owns fresh/restored lifecycle, effects, input gating, fit failure, and acknowledgment; `GameViewController` owns pending-first routing and the existing unsupported-geometry gate.

**Tech Stack:** Swift 5, Swift Testing, Foundation, CoreGraphics, SpriteKit/UIKit, `KingdomGameStore`, Xcode / `xcodebuild` on macOS.

## Global Constraints

- Design authority: `docs/superpowers/specs/2026-07-30-compact-conquest-report-design.md`.
- Required rows are exactly:
  1. `Gold earned: +<amount>`
  2. live `Battle time: <duration>` or idle `Conquered by your buildings`
  3. optional `MVP: <SoldierType.displayName> · <percent>%`
  4. `Deployed: <count> · Lost: <count>`
- Render only from `pendingBattleResult`; do not inspect soldier nodes or aggregate combat data in SpriteKit.
- `.idle` includes offline catch-up and build/upgrade settlement. Do not add another persisted mode or presentation origin.
- Building View conquest stays in Building View. The next explicit Battle request restores the pending report without effects.
- Continue order is exact: disable → acknowledge → save → one Country Map route.
- Compatible pre-release pending results may display once. Do not add a migration marker.
- Conquered-stage Battle Scenes are inert report hosts; only enabled Continue is interactive.
- Use one current numbered city title. HPA-366 owns authored-name fallback later.
- Use `checkmark.shield.fill` and `shield.slash.fill` directly; no procedural fallback and no SpriteKit accessibility claim.
- Read all four safe-area values from `SKView.safeAreaInsets`; do not modify `GameUITheme` for horizontal helpers.
- Layout and node application fail closed. Preserve pending state and use the existing `.unsupportedGeometry` gate.
- Do not modify `Pyxis/BuildingViewScene.swift`, `Pyxis/GameUITheme.swift`, `Pyxis/CityDefinition.swift`, or `Pyxis.xcodeproj/project.pbxproj`.
- TDD every task: failing test → observed failure → minimal implementation → passing test → commit.
- Before every commit run `git status --short` and stage only task files.
- Always disable parallel testing. Fallback command:
  ```bash
  xcodebuild test \
    -project Pyxis.xcodeproj \
    -scheme Pyxis \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -parallel-testing-enabled NO \
    -only-testing:PyxisTests/<SuiteName>
  ```

## File Map

### Create

- `Pyxis/SingleLineTextFitter.swift`
- `Pyxis/CompactNumberFormatter.swift`
- `Pyxis/ConquestReportContent.swift`
- `Pyxis/ConquestReportLayout.swift`
- `Pyxis/ConquestReportNode.swift`
- `PyxisTests/SingleLineTextFitterTests.swift`
- `PyxisTests/CompactNumberFormatterTests.swift`
- `PyxisTests/ConquestReportContentTests.swift`
- `PyxisTests/ConquestReportLayoutTests.swift`
- `PyxisTests/ConquestReportNodeTests.swift`

### Modify

- `Pyxis/CountryMapScoutCardTextLayout.swift`
- `Pyxis/BattleResultModels.swift`
- `Pyxis/BattleScene.swift`
- `Pyxis/GameViewController.swift`
- `PyxisTests/CountryMapScoutCardTextLayoutTests.swift`
- `PyxisTests/BattleResultModelsTests.swift`
- `PyxisTests/BattleSceneTests.swift`
- `PyxisTests/BuildingViewSceneTests.swift`
- `PyxisTests/GameViewControllerTests.swift`
- `CLAUDE.md`

---

### Task 1: Extract `SingleLineTextFitter`

**Files:**
- Create: `Pyxis/SingleLineTextFitter.swift`
- Create: `PyxisTests/SingleLineTextFitterTests.swift`
- Modify: `Pyxis/CountryMapScoutCardTextLayout.swift`
- Modify: `PyxisTests/CountryMapScoutCardTextLayoutTests.swift`

**Produces:**

```swift
enum SingleLineTextFitter {
    static func fittedFontSize(
        _ text: String,
        startingAt start: CGFloat,
        minimum: CGFloat,
        maximumWidth: CGFloat,
        measure: (String, CGFloat) -> CGFloat
    ) -> CGFloat?
}
```

- [ ] **Step 1: Create failing helper tests**

```swift
import CoreGraphics
import Testing
@testable import Pyxis

struct SingleLineTextFitterTests {
    @Test func returnsFirstWholePointSizeThatFits() {
        let result = SingleLineTextFitter.fittedFontSize(
            "AB",
            startingAt: 7.8,
            minimum: 4,
            maximumWidth: 10,
            measure: { text, size in CGFloat(text.count) * size }
        )
        #expect(result == 5)
    }

    @Test func includesTheMinimumSize() {
        let result = SingleLineTextFitter.fittedFontSize(
            "ABC",
            startingAt: 6,
            minimum: 4,
            maximumWidth: 12,
            measure: { text, size in CGFloat(text.count) * size }
        )
        #expect(result == 4)
    }

    @Test func returnsNilWhenMinimumDoesNotFit() {
        let result = SingleLineTextFitter.fittedFontSize(
            "ABC",
            startingAt: 6,
            minimum: 4,
            maximumWidth: 11,
            measure: { text, size in CGFloat(text.count) * size }
        )
        #expect(result == nil)
    }
}
```

- [ ] **Step 2: Run and observe compile failure**

Run `-only-testing:PyxisTests/SingleLineTextFitterTests`. Expected: missing `SingleLineTextFitter`.

- [ ] **Step 3: Implement the helper**

```swift
import CoreGraphics

enum SingleLineTextFitter {
    static func fittedFontSize(
        _ text: String,
        startingAt start: CGFloat,
        minimum: CGFloat,
        maximumWidth: CGFloat,
        measure: (String, CGFloat) -> CGFloat
    ) -> CGFloat? {
        var size = floor(start)
        while size >= minimum {
            if measure(text, size) <= maximumWidth {
                return size
            }
            size -= 1
        }
        return nil
    }
}
```

- [ ] **Step 4: Forward the Scout Card API**

Replace the body of `CountryMapScoutCardTextLayout.fittedFontSize` with:

```swift
SingleLineTextFitter.fittedFontSize(
    text,
    startingAt: start,
    minimum: minimum,
    maximumWidth: maximumWidth,
    measure: measure
)
```

Add:

```swift
@Test func fittedFontSizeMatchesSharedHelper() {
    let measure: (String, CGFloat) -> CGFloat = { text, size in
        CGFloat(text.count) * size
    }
    #expect(CountryMapScoutCardTextLayout.fittedFontSize(
        "AB", startingAt: 7.8, minimum: 4, maximumWidth: 10, measure: measure
    ) == SingleLineTextFitter.fittedFontSize(
        "AB", startingAt: 7.8, minimum: 4, maximumWidth: 10, measure: measure
    ))
}
```

- [ ] **Step 5: Run both suites and commit**

Expected: `SingleLineTextFitterTests` and `CountryMapScoutCardTextLayoutTests` pass.

```bash
git add Pyxis/SingleLineTextFitter.swift \
  Pyxis/CountryMapScoutCardTextLayout.swift \
  PyxisTests/SingleLineTextFitterTests.swift \
  PyxisTests/CountryMapScoutCardTextLayoutTests.swift
git commit -m "refactor: share single-line text fitting"
```

---

### Task 2: Extract `CompactNumberFormatter`

**Files:**
- Create: `Pyxis/CompactNumberFormatter.swift`
- Create: `PyxisTests/CompactNumberFormatterTests.swift`
- Modify: `Pyxis/BattleScene.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`

**Produces:**

```swift
enum CompactNumberFormatter {
    static func string(from value: Int) -> String
}
```

- [ ] **Step 1: Create the failing pure test table**

```swift
import Testing
@testable import Pyxis

struct CompactNumberFormatterTests {
    @Test(arguments: [
        (0, "0"), (999, "999"), (1_000, "1K"),
        (1_100, "1.1K"), (10_000, "10K"),
        (999_000, "999K"), (999_950, "1M"),
        (1_000_000, "1M"), (1_500_000, "1.5M"),
        (1_000_000_000, "1B"),
        (1_000_000_000_000, "1T"),
        (-1_500, "-1.5K")
    ])
    func formatsExistingBattleContract(value: Int, expected: String) {
        #expect(CompactNumberFormatter.string(from: value) == expected)
    }
}
```

Move every current `compactNumberForTesting` case from `BattleSceneTests` into this table before removing the scene seam.

- [ ] **Step 2: Run and observe compile failure**

Expected: missing `CompactNumberFormatter`.

- [ ] **Step 3: Implement the formatter**

```swift
import Foundation

enum CompactNumberFormatter {
    static func string(from value: Int) -> String {
        let magnitude = value.magnitude
        let sign = value < 0 ? "-" : ""
        let units: [(threshold: UInt, suffix: String)] = [
            (1_000_000_000_000, "T"),
            (1_000_000_000, "B"),
            (1_000_000, "M"),
            (1_000, "K")
        ]
        guard let index = units.firstIndex(where: { magnitude >= $0.threshold }) else {
            return String(value)
        }
        let unit = units[index]
        let scaled = Double(magnitude) / Double(unit.threshold)
        let roundedTenths = (scaled * 10).rounded() / 10
        if roundedTenths.rounded() >= 1_000, index > 0 {
            let promoted = units[index - 1]
            return formatted(
                Double(magnitude) / Double(promoted.threshold),
                sign: sign,
                suffix: promoted.suffix
            )
        }
        return formatted(roundedTenths, sign: sign, suffix: unit.suffix, alreadyRounded: true)
    }

    private static func formatted(
        _ value: Double,
        sign: String,
        suffix: String,
        alreadyRounded: Bool = false
    ) -> String {
        let rounded = alreadyRounded ? value : (value * 10).rounded() / 10
        let body = rounded >= 10 || rounded.rounded() == rounded
            ? String(format: "%.0f", rounded)
            : String(format: "%.1f", rounded)
        return "\(sign)\(body)\(suffix)"
    }
}
```

- [ ] **Step 4: Migrate consumers and remove old truth**

Replace every `compactNumber(value)` call with:

```swift
CompactNumberFormatter.string(from: value)
```

Delete `BattleScene.compactNumber(_:)`, `compactNumberForTesting`, and formatter-only scene tests.

- [ ] **Step 5: Run and commit**

Expected: `CompactNumberFormatterTests` and `BattleSceneTests` pass.

```bash
git add Pyxis/CompactNumberFormatter.swift Pyxis/BattleScene.swift \
  PyxisTests/CompactNumberFormatterTests.swift PyxisTests/BattleSceneTests.swift
git commit -m "refactor: share compact number formatting"
```

---

### Task 3: Add Result Totals and Report Content Projection

**Files:**
- Modify: `Pyxis/BattleResultModels.swift`
- Create: `Pyxis/ConquestReportContent.swift`
- Modify: `PyxisTests/BattleResultModelsTests.swift`
- Create: `PyxisTests/ConquestReportContentTests.swift`

**Produces:** `BattleResult.totalDeploymentCount`, `BattleResult.totalLossCount`, and:

```swift
struct ConquestReportContent: Equatable {
    enum Achievement: Equatable { case favorableUnit, exposedLane }
    let title: String
    let summaryLines: [String]
    let achievements: [Achievement]

    static func project(
        from result: BattleResult,
        cityTitle: String,
        isCountryComplete: Bool
    ) -> ConquestReportContent
}
```

- [ ] **Step 1: Add failing total tests**

```swift
@Test func battleResultTotalsSumRows() {
    let result = makeBattleResult(
        deployments: [
            .init(type: .infantry, source: .manual, lane: .left, count: 2),
            .init(type: .archer, source: .building, lane: .right, count: 5)
        ],
        losses: [
            .init(type: .infantry, source: .manual, count: 1),
            .init(type: .archer, source: .building, count: 3)
        ]
    )
    #expect(result.totalDeploymentCount == 7)
    #expect(result.totalLossCount == 4)
}

@Test func battleResultTotalsSaturate() {
    let result = makeBattleResult(
        deployments: [
            .init(type: .infantry, source: .manual, lane: .left, count: Int.max),
            .init(type: .archer, source: .building, lane: .right, count: 1)
        ],
        losses: [
            .init(type: .infantry, source: .manual, count: Int.max),
            .init(type: .archer, source: .building, count: 1)
        ]
    )
    #expect(result.totalDeploymentCount == Int.max)
    #expect(result.totalLossCount == Int.max)
}
```

Use the existing `BattleResultModelsTests` result factory or add one with all current initializer fields.

- [ ] **Step 2: Create failing projection tests**

```swift
import Foundation
import Testing
@testable import Pyxis

struct ConquestReportContentTests {
    @Test func liveReportUsesPersistedResultFields() {
        let content = ConquestReportContent.project(
            from: makeResult(mode: .live, seconds: 65),
            cityTitle: "Country 1 - City 3",
            isCountryComplete: false
        )
        #expect(content.title == "Country 1 - City 3 Conquered")
        #expect(content.summaryLines == [
            "Gold earned: +1.5K",
            "Battle time: 1m 5s",
            "MVP: Archer · 63%",
            "Deployed: 7 · Lost: 2"
        ])
        #expect(content.achievements == [.favorableUnit, .exposedLane])
    }

    @Test func idleReportUsesBuildingCopyAndNoDuration() {
        let content = ConquestReportContent.project(
            from: makeResult(mode: .idle, seconds: 90_061),
            cityTitle: "Country 1 - City 3",
            isCountryComplete: false
        )
        #expect(content.summaryLines[1] == "Conquered by your buildings")
        #expect(!content.summaryLines.contains { $0.contains("Battle time") })
    }

    @Test func missingOrPartialMVPIsOmitted() {
        for pair in [(SoldierType?.none, Int?.none), (.archer, nil), (nil, 63)] {
            let content = ConquestReportContent.project(
                from: makeResult(mvp: pair.0, share: pair.1),
                cityTitle: "Country 1 - City 3",
                isCountryComplete: false
            )
            #expect(content.summaryLines.count == 3)
            #expect(!content.summaryLines.contains { $0.hasPrefix("MVP:") })
        }
    }

    @Test func zeroCountsAndAchievementCombinationsAreStable() {
        let combinations: [(Bool, Bool, [ConquestReportContent.Achievement])] = [
            (false, false, []),
            (true, false, [.favorableUnit]),
            (false, true, [.exposedLane]),
            (true, true, [.favorableUnit, .exposedLane])
        ]
        for combination in combinations {
            let content = ConquestReportContent.project(
                from: makeResult(
                    deployments: 0,
                    losses: 0,
                    favorable: combination.0,
                    exposed: combination.1
                ),
                cityTitle: "Country 1 - City 3",
                isCountryComplete: false
            )
            #expect(content.summaryLines.last == "Deployed: 0 · Lost: 0")
            #expect(content.achievements == combination.2)
        }
    }

    @Test func countryCompleteIgnoresCityTitle() {
        let content = ConquestReportContent.project(
            from: makeResult(city: 15),
            cityTitle: "Ignored",
            isCountryComplete: true
        )
        #expect(content.title == "Country 1 Conquered")
    }

    @Test(arguments: [
        (0.0, "0s"), (59.9, "59s"), (60.0, "1m"),
        (65.0, "1m 5s"), (3_599.0, "59m 59s"),
        (3_600.0, "1h"), (3_612.0, "1h 00m 12s"),
        (3_660.0, "1h 01m"), (3_672.0, "1h 01m 12s"),
        (90_000.0, "25h"), (90_061.0, "25h 01m 01s")
    ])
    func durationGoldenStrings(seconds: TimeInterval, expected: String) {
        let content = ConquestReportContent.project(
            from: makeResult(seconds: seconds),
            cityTitle: "Country 1 - City 3",
            isCountryComplete: false
        )
        #expect(content.summaryLines[1] == "Battle time: \(expected)")
    }

    @Test func invalidDurationsNormalizeToZero() {
        for seconds in [-1.0, .infinity, .nan] {
            let content = ConquestReportContent.project(
                from: makeResult(seconds: seconds),
                cityTitle: "Country 1 - City 3",
                isCountryComplete: false
            )
            #expect(content.summaryLines[1] == "Battle time: 0s")
        }
    }
}
```

The test file includes a `makeResult(...)` factory with all `BattleResult` initializer fields and defaults matching the first test.

- [ ] **Step 3: Run and observe missing APIs**

Run `BattleResultModelsTests` and `ConquestReportContentTests`.

- [ ] **Step 4: Implement saturating totals**

```swift
extension BattleResult {
    var totalDeploymentCount: Int {
        deployments.reduce(0) { total, row in
            let (sum, overflowed) = total.addingReportingOverflow(row.count)
            return overflowed ? Int.max : sum
        }
    }

    var totalLossCount: Int {
        losses.reduce(0) { total, row in
            let (sum, overflowed) = total.addingReportingOverflow(row.count)
            return overflowed ? Int.max : sum
        }
    }
}
```

- [ ] **Step 5: Implement `ConquestReportContent`**

```swift
import Foundation

struct ConquestReportContent: Equatable {
    enum Achievement: Equatable { case favorableUnit, exposedLane }
    let title: String
    let summaryLines: [String]
    let achievements: [Achievement]

    static func project(
        from result: BattleResult,
        cityTitle: String,
        isCountryComplete: Bool
    ) -> Self {
        let title = isCountryComplete
            ? "Country \(result.cityKey.countryNumber) Conquered"
            : "\(cityTitle) Conquered"
        var lines = [
            "Gold earned: +\(CompactNumberFormatter.string(from: result.goldEarned))"
        ]
        switch result.conquestMode {
        case .live:
            lines.append("Battle time: \(durationText(result.activeBattleSeconds))")
        case .idle:
            lines.append("Conquered by your buildings")
        }
        if let type = result.mvpSoldierType,
           let percent = result.mvpDamageSharePercent {
            lines.append("MVP: \(type.displayName) · \(percent)%")
        }
        lines.append(
            "Deployed: \(CompactNumberFormatter.string(from: result.totalDeploymentCount))"
                + " · Lost: \(CompactNumberFormatter.string(from: result.totalLossCount))"
        )
        var achievements = [Achievement]()
        if result.usedFavorableUnit { achievements.append(.favorableUnit) }
        if result.usedExposedLane { achievements.append(.exposedLane) }
        return Self(title: title, summaryLines: lines, achievements: achievements)
    }

    private static func durationText(_ raw: TimeInterval) -> String {
        let total = Int(ActiveSiegeSession.normalizedActiveBattleSeconds(raw))
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        let seconds = total % 60
        if hours == 0, minutes == 0 { return "\(seconds)s" }
        if hours == 0 {
            return seconds == 0 ? "\(minutes)m" : "\(minutes)m \(seconds)s"
        }
        var parts = ["\(hours)h"]
        if minutes > 0 || seconds > 0 {
            parts.append(String(format: "%02dm", minutes))
        }
        if seconds > 0 {
            parts.append(String(format: "%02ds", seconds))
        }
        return parts.joined(separator: " ")
    }
}
```

- [ ] **Step 6: Run, pass, and commit**

```bash
git add Pyxis/BattleResultModels.swift Pyxis/ConquestReportContent.swift \
  PyxisTests/BattleResultModelsTests.swift PyxisTests/ConquestReportContentTests.swift
git commit -m "feat: project compact conquest report content"
```

---

### Task 4: Add Failable Safe-Area Geometry

**Files:**
- Create: `Pyxis/ConquestReportLayout.swift`
- Create: `PyxisTests/ConquestReportLayoutTests.swift`

**Produces:** `ConquestReportSafeAreaInsets`, `ConquestReportLayout.Input`, and `ConquestReportLayout.compute(_:) -> ConquestReportLayout?` with panel/title/row/badge/Continue frames and font metrics.

- [ ] **Step 1: Create failing layout tests**

Use the exact ten fixture sizes/insets from the design and these required assertions:

```swift
@Test func deterministicHeightsMatchConstants() throws {
    let standard = try #require(makeLayout(
        size: .init(width: 375, height: 667), rows: 4, achievements: 2
    ))
    let compact = try #require(makeLayout(
        size: .init(width: 375, height: 499), rows: 4, achievements: 2
    ))
    let threeRows = try #require(makeLayout(
        size: .init(width: 375, height: 667), rows: 3, achievements: 0
    ))
    #expect(standard.panelFrame.height == 282)
    #expect(compact.panelFrame.height == 230)
    #expect(threeRows.panelFrame.height == 220)
}

@Test func badgeStripWidthUsesCountSizeAndGap() throws {
    let one = try #require(makeLayout(rows: 4, achievements: 1))
    let two = try #require(makeLayout(rows: 4, achievements: 2))
    #expect(one.achievementStripFrame?.width == 24)
    #expect(two.achievementStripFrame?.width == 56)
}

@Test func everySupportedFixtureContainsAllFrames() throws {
    for fixture in supportedFixtures {
        let layout = try #require(makeLayout(
            size: fixture.size,
            insets: fixture.insets,
            rows: 4,
            achievements: 2
        ))
        #expect(layout.safeFrame.contains(layout.panelFrame))
        #expect(layout.panelFrame.contains(layout.titleFrame))
        #expect(layout.summaryRowFrames.allSatisfy { layout.panelFrame.contains($0) })
        #expect(layout.achievementStripFrame.map { layout.panelFrame.contains($0) } ?? true)
        #expect(layout.panelFrame.contains(layout.continueFrame))
    }
}

@Test func sideInsetsCenterInsideSafeRegion() throws {
    let layout = try #require(makeLayout(
        size: .init(width: 834, height: 1194),
        insets: .init(top: 24, left: 50, bottom: 20, right: 50),
        rows: 4,
        achievements: 2
    ))
    #expect(layout.safeFrame == CGRect(x: 50, y: 20, width: 734, height: 1_150))
    #expect(layout.panelFrame.midX == layout.safeFrame.midX)
}

@Test func invalidCountsAndInsufficientGeometryReturnNil() {
    #expect(makeLayout(rows: 2, achievements: 0) == nil)
    #expect(makeLayout(rows: 5, achievements: 0) == nil)
    #expect(makeLayout(rows: 4, achievements: 3) == nil)
    #expect(makeLayout(
        size: .init(width: 80, height: 200),
        insets: .init(top: 0, left: 20, bottom: 0, right: 20),
        rows: 4,
        achievements: 2
    ) == nil)
    #expect(makeLayout(
        size: .init(width: 375, height: 200),
        insets: .init(top: 20, left: 0, bottom: 20, right: 0),
        rows: 4,
        achievements: 2
    ) == nil)
}
```

`makeLayout` computes Battle Scene content width with the existing formula and sets `compactHeight = size.height < 500`.

- [ ] **Step 2: Run and observe missing types**

- [ ] **Step 3: Implement layout computation**

Implement the exact constants and formula from the design. The core guards and frame order are:

```swift
guard (3...4).contains(input.summaryRowCount),
      (0...2).contains(input.achievementCount) else { return nil }
let safeWidth = input.sceneSize.width - input.safeAreaInsets.left - input.safeAreaInsets.right
let safeHeight = input.sceneSize.height - input.safeAreaInsets.top - input.safeAreaInsets.bottom
guard safeWidth > 0, safeHeight > 0 else { return nil }
let safeFrame = CGRect(
    x: input.safeAreaInsets.left,
    y: input.safeAreaInsets.bottom,
    width: safeWidth,
    height: safeHeight
)
let panelWidth = min(input.battleContentWidth, safeWidth - 56)
let continueWidth = panelWidth - 48
guard panelWidth > horizontalPadding * 2, continueWidth >= 44 else { return nil }
let panelHeight = verticalPadding * 2
    + titleLine + titleRowsGap
    + CGFloat(input.summaryRowCount) * rowLine
    + CGFloat(input.summaryRowCount - 1) * rowGap
    + (input.achievementCount > 0 ? rowsBadgeGap + badgeSize : 0)
    + contentContinueGap + continueHeight
guard panelHeight <= safeHeight else { return nil }
```

Build frames top-to-bottom, center panel in the safe frame, and return `nil` unless every child frame is contained and the bottom padding equation matches.

- [ ] **Step 4: Run, pass, and commit**

```bash
git add Pyxis/ConquestReportLayout.swift PyxisTests/ConquestReportLayoutTests.swift
git commit -m "feat: add compact conquest report layout"
```

---

### Task 5: Build `ConquestReportNode`

**Files:**
- Create: `Pyxis/ConquestReportNode.swift`
- Create: `PyxisTests/ConquestReportNodeTests.swift`

**Produces:**

```swift
final class ConquestReportNode: SKNode {
    enum ApplyResult: Equatable { case presented, requiredContentDoesNotFit }
    func apply(content: ConquestReportContent, layout: ConquestReportLayout, isContinueEnabled: Bool) -> ApplyResult
    func containsContinue(_ scenePoint: CGPoint) -> Bool
    func goldEffectAnchor(in coordinateNode: SKNode) -> CGPoint?
}
```

- [ ] **Step 1: Create failing node tests**

```swift
@Test func reapplyReusesOneTree() throws {
    let node = ConquestReportNode(textWidth: { text, _, size in CGFloat(text.count) * size * 0.45 })
    let layout = try reportLayout(rows: 4, achievements: 2)
    #expect(node.apply(content: fullContent(), layout: layout, isContinueEnabled: true) == .presented)
    let counts = node.nodeCountsForTesting
    #expect(node.apply(content: fullContent(), layout: layout, isContinueEnabled: true) == .presented)
    #expect(node.nodeCountsForTesting == counts)
    #expect(node.continueControlCountForTesting == 1)
}

@Test func threeRowsHideUnusedLabelAndNoBadgesHideBothSprites() throws {
    let node = ConquestReportNode(textWidth: { text, _, size in CGFloat(text.count) * size * 0.45 })
    let content = ConquestReportContent(
        title: "Country 1 - City 3 Conquered",
        summaryLines: ["Gold earned: +8", "Battle time: 1m", "Deployed: 0 · Lost: 0"],
        achievements: []
    )
    #expect(node.apply(content: content, layout: try reportLayout(rows: 3, achievements: 0), isContinueEnabled: true) == .presented)
    #expect(node.renderedSummaryLinesForTesting == content.summaryLines)
    #expect(node.renderedAchievementSymbolsForTesting == [])
}

@Test func badgeOrderAndGoldAnchorAreStable() throws {
    let scene = SKScene(size: .init(width: 393, height: 852))
    let node = ConquestReportNode(textWidth: { text, _, size in CGFloat(text.count) * size * 0.45 })
    scene.addChild(node)
    let layout = try reportLayout(rows: 4, achievements: 2)
    _ = node.apply(content: fullContent(), layout: layout, isContinueEnabled: true)
    #expect(node.renderedAchievementSymbolsForTesting == ["checkmark.shield.fill", "shield.slash.fill"])
    #expect(node.goldEffectAnchor(in: scene) == CGPoint(x: layout.summaryRowFrames[0].midX, y: layout.summaryRowFrames[0].midY))
}

@Test func disabledContinueAndFitFailureHaveNoHitTarget() throws {
    let layout = try reportLayout(rows: 4, achievements: 2)
    let disabled = ConquestReportNode(textWidth: { text, _, size in CGFloat(text.count) * size * 0.45 })
    _ = disabled.apply(content: fullContent(), layout: layout, isContinueEnabled: false)
    #expect(!disabled.containsContinue(.init(x: layout.continueFrame.midX, y: layout.continueFrame.midY)))

    let failing = ConquestReportNode(textWidth: { text, _, _ in CGFloat(text.count) * 100 })
    #expect(failing.apply(content: fullContent(), layout: layout, isContinueEnabled: true) == .requiredContentDoesNotFit)
    #expect(failing.continueHitFrameForTesting == nil)
    #expect(failing.goldEffectAnchorForTesting == nil)
}

@Test func titleAndRowsOnlyShrinkToTheirMinimums() throws {
    let node = ConquestReportNode(textWidth: { text, _, size in CGFloat(text.count) * size })
    let layout = try reportLayout(rows: 3, achievements: 0, panelWidth: 319)
    let content = ConquestReportContent(
        title: String(repeating: "T", count: 20),
        summaryLines: [String(repeating: "R", count: 20), "Battle time: 1m", "Deployed: 0 · Lost: 0"],
        achievements: []
    )
    _ = node.apply(content: content, layout: layout, isContinueEnabled: true)
    #expect(node.titleFontSizeForTesting >= 14)
    #expect(node.summaryFontSizesForTesting.allSatisfy { $0 >= 12 })
    #expect(node.renderedSummaryLinesForTesting == content.summaryLines)
}
```

- [ ] **Step 2: Run and observe missing node**

- [ ] **Step 3: Implement one-time node construction**

Use one `SKShapeNode` panel, one title label, four prebuilt summary labels, two prebuilt badge sprites, and one prebuilt Continue node. `apply` must:

```swift
guard content.summaryLines.count == layout.summaryRowFrames.count,
      let titleSize = fittedSize(content.title, fontName: GameUITheme.Font.bold,
                                 start: layout.titleStartingFontSize,
                                 minimum: layout.titleMinimumFontSize,
                                 width: layout.titleFrame.width) else {
    return failApply()
}
var rowSizes = [CGFloat]()
for (line, frame) in zip(content.summaryLines, layout.summaryRowFrames) {
    guard let size = fittedSize(line, fontName: GameUITheme.Font.medium,
                                start: layout.summaryStartingFontSize,
                                minimum: layout.summaryMinimumFontSize,
                                width: frame.width) else {
        return failApply()
    }
    rowSizes.append(size)
}
```

Map achievements to exact symbol names, load with `UIImage(systemName:)`, assert in DEBUG if unavailable, render in fixed order, and hide unused sprites. `renderContinue` assigns the hit frame only when enabled. `failApply` hides the node and clears Continue/gold geometry. Use `SingleLineTextFitter` and a production width closure based on `UIFont`/`NSString`.

Add a DEBUG extension exposing only the readbacks used by the tests above.

- [ ] **Step 4: Run, pass, and commit**

```bash
git add Pyxis/ConquestReportNode.swift PyxisTests/ConquestReportNodeTests.swift
git commit -m "feat: add reusable conquest report node"
```

---

### Task 6: Restore Pending Reports in `BattleScene`

**Files:**
- Modify: `Pyxis/BattleScene.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`

- [ ] **Step 1: Add failing restored-report tests**

Add a `pendingResult(city:mode:)` factory and tests for:

```swift
@Test func restoredPendingReportIsStatic() throws {
    let store = try makeStore(initialState: pendingConqueredState(city: 3, mode: .live))
    let scene = makeScene(store: store)
    #expect(scene.isConquestPopupVisibleForTesting)
    #expect(scene.conquestReportTitleForTesting == "Country 1 - City 3 Conquered")
    #expect(scene.conquestReportLinesForTesting[1] == "Battle time: 1m 5s")
    #expect(!scene.isGoldBurstVisibleForTesting)
    #expect(!scene.isCityConquestFeedbackRunningForTesting)
}

@Test func countryCompleteIsAnInertReportHost() throws {
    let store = try makeStore(initialState: pendingConqueredState(city: 15, mode: .idle, countryComplete: true))
    let scene = makeScene(store: store)
    let before = scene.gameStateForTesting
    scene.advanceCombatForTesting(deltaTime: 10)
    scene.spawnSoldierForTesting()
    #expect(scene.conquestReportTitleForTesting == "Country 1 Conquered")
    #expect(scene.gameStateForTesting == before)
    #expect(scene.liveSoldierCountForTesting == 0)
}

@Test func presentabilityRequiresMatchingCityKey() {
    #expect(BattleScene.isPendingResultPresentableForTesting(
        pendingResult(city: 3), currentCityKey: CityKey(countryNumber: 1, cityNumber: 3)
    ))
    #expect(!BattleScene.isPendingResultPresentableForTesting(
        pendingResult(city: 2), currentCityKey: CityKey(countryNumber: 1, cityNumber: 3)
    ))
}
```

- [ ] **Step 2: Run and observe legacy-popup behavior**

- [ ] **Step 3: Replace legacy popup nodes/state**

Delete the legacy overlay/title/reward/Continue nodes and methods. Add:

```swift
private enum ConquestReportPresentationOrigin { case freshLive, freshIdle, restored }
private let conquestReportNode = ConquestReportNode()
private var hasPresentedPendingConquestReport = false
private var isConquestReportVisible = false
private var isConquestContinueEnabled = true
private(set) var isConquestReportFitFailed = false
```

Add the report node once in `buildInterface`, hidden initially.

- [ ] **Step 4: Add validation, projection, layout, and apply helpers**

```swift
private static func isPendingResultPresentable(
    _ result: BattleResult,
    currentCityKey: CityKey
) -> Bool {
    result.cityKey == currentCityKey
}

private func pendingResultForPresentation() -> BattleResult? {
    guard let result = state.pendingBattleResult else { return nil }
    guard Self.isPendingResultPresentable(result, currentCityKey: state.currentCityKey) else {
        assertionFailure("Pending BattleResult city does not match current city")
        return nil
    }
    return result
}

private func conquestReportContent(for result: BattleResult) -> ConquestReportContent {
    .project(
        from: result,
        cityTitle: state.displayCityTitle(for: result.cityKey.cityNumber),
        isCountryComplete: state.stageStatus == .countryComplete
    )
}

private func conquestReportLayout(for content: ConquestReportContent) -> ConquestReportLayout? {
    let metrics = layoutMetrics()
    let insets = view?.safeAreaInsets ?? .zero
    return .compute(.init(
        sceneSize: size,
        safeAreaInsets: .init(top: insets.top, left: insets.left,
                              bottom: insets.bottom, right: insets.right),
        battleContentWidth: metrics.contentWidth,
        summaryRowCount: content.summaryLines.count,
        achievementCount: content.achievements.count,
        compactHeight: metrics.compactHeight
    ))
}

@discardableResult
private func applyPendingConquestReport(resetsContinueState: Bool) -> Bool {
    guard let result = pendingResultForPresentation() else { return false }
    if resetsContinueState { isConquestContinueEnabled = true }
    let content = conquestReportContent(for: result)
    guard let layout = conquestReportLayout(for: content),
          conquestReportNode.apply(
              content: content,
              layout: layout,
              isContinueEnabled: isConquestContinueEnabled
          ) == .presented else {
        isConquestReportVisible = true
        isConquestReportFitFailed = true
        conquestReportNode.isHidden = true
        return false
    }
    isConquestReportVisible = true
    isConquestReportFitFailed = false
    hasPresentedPendingConquestReport = true
    return true
}
```

- [ ] **Step 5: Restore once and retry failed fitting on resize**

After `redraw()` in `didMove`:

```swift
if state.pendingBattleResult != nil, !hasPresentedPendingConquestReport {
    _ = applyPendingConquestReport(resetsContinueState: true)
}
```

At the end of `layoutInterface`:

```swift
if state.pendingBattleResult != nil,
   hasPresentedPendingConquestReport || isConquestReportFitFailed {
    _ = applyPendingConquestReport(resetsContinueState: false)
}
```

This second condition is required: an initial fit failure has not set `hasPresentedPendingConquestReport`, but must retry after a supported resize.

- [ ] **Step 6: Add DEBUG readbacks and run**

Expose report title/lines, node/control counts, Continue state/frame, last layout input, presentability helper, presentation flag, and fit-failure flag. Keep `isConquestPopupVisibleForTesting` as a compatibility alias.

Expected: restored live/idle, country-complete inert, mismatch, no-effect, no-duplicate, and resize-retry tests pass.

- [ ] **Step 7: Commit**

```bash
git add Pyxis/BattleScene.swift PyxisTests/BattleSceneTests.swift
git commit -m "feat: restore conquest report from pending result"
```

---

### Task 7: Gate Fresh Effects by Presentation Origin

**Files:**
- Modify: `Pyxis/BattleScene.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`

- [ ] **Step 1: Add failing fresh-origin tests**

```swift
@Test func liveConquestUsesFreshLiveEffectsOnce() throws {
    let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 1))
    let scene = makeScene(store: store)
    scene.spawnSoldierForTesting()
    scene.advanceCombatForTesting(deltaTime: 3)
    #expect(scene.lastConquestReportOriginForTesting == "freshLive")
    #expect(scene.isGoldBurstVisibleForTesting)
    #expect(scene.isCityConquestFeedbackRunningForTesting)
    #expect(scene.goldBurstAnchorForTesting == scene.conquestReportGoldAnchorForTesting)
    let count = scene.conquestEffectPresentationCountForTesting
    scene.redrawForTesting(shouldLayout: true)
    scene.refreshLayoutForCurrentEnvironment()
    #expect(scene.conquestEffectPresentationCountForTesting == count)
}

@Test func battleForegroundIdleUsesFreshIdleGoldOnly() throws {
    let store = try makeStore(initialState: idleConquestReadyState())
    let scene = makeScene(store: store)
    scene.enterBackgroundForTesting(at: Date(timeIntervalSince1970: 1_000))
    scene.enterForegroundForTesting(at: Date(timeIntervalSince1970: 10_000))
    #expect(scene.lastConquestReportOriginForTesting == "freshIdle")
    #expect(scene.conquestReportLinesForTesting[1] == "Conquered by your buildings")
    #expect(scene.isGoldBurstVisibleForTesting)
    #expect(!scene.isCityConquestFeedbackRunningForTesting)
    #expect(scene.floatingFeedbackCountForTesting == 0)
}
```

Use the existing lifecycle test helpers/state factory names in the file; if missing, add DEBUG wrappers around `sceneDidEnterBackground`/`sceneWillEnterForeground` that call the production methods.

- [ ] **Step 2: Implement origin-aware presentation**

```swift
@discardableResult
private func presentPendingConquestReport(
    origin: ConquestReportPresentationOrigin,
    resetsContinueState: Bool
) -> Bool {
    guard applyPendingConquestReport(resetsContinueState: resetsContinueState) else {
        return false
    }
    #if DEBUG
    lastConquestReportOriginForTestingStorage = origin
    conquestEffectPresentationCountForTestingStorage += origin == .restored ? 0 : 1
    #endif
    if origin != .restored,
       let anchor = conquestReportNode.goldEffectAnchor(in: self) {
        playGoldBurst(at: anchor)
    }
    return true
}
```

Change `playGoldBurst(goldEarned:)` to `playGoldBurst(at:)` and preserve its action sequence.

- [ ] **Step 3: Replace live and foreground-idle call sites**

Live: save and redraw first; call `.freshLive`; only after successful report application run floating damage and city flourish. Idle in Battle Scene: call `.freshIdle`; do not run floating damage or city flourish. Never pass transient reward into rendering.

Replace the first restored call in `didMove` with `.restored`; layout-only reapply continues to call `applyPendingConquestReport` directly.

- [ ] **Step 4: Run and commit**

Expected: fresh effects once, restored/reapply none, fit failure none.

```bash
git add Pyxis/BattleScene.swift PyxisTests/BattleSceneTests.swift
git commit -m "feat: gate conquest effects by report origin"
```

---

### Task 8: Implement Continue Transaction and Modal Input

**Files:**
- Modify: `Pyxis/BattleScene.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`

- [ ] **Step 1: Add failing ordering and modal tests**

```swift
@Test func continueDisablesAcknowledgesSavesThenRoutesOnce() throws {
    let store = try makeStore(initialState: pendingConqueredState())
    let router = BattleRouterSpy()
    let scene = makeScene(store: store, router: router)
    router.onCountryMapRequest = { routed in
        #expect(!routed.isConquestContinueEnabledForTesting)
        #expect(routed.gameStateForTesting.pendingBattleResult == nil)
        #expect(store.load().pendingBattleResult == nil)
    }
    scene.tapConquestContinueForTesting()
    scene.tapConquestContinueForTesting()
    #expect(router.countryMapRequestCount == 1)
}

@Test func missingRouterLeavesReportPendingAndEnabled() throws {
    let store = try makeStore(initialState: pendingConqueredState())
    let scene = makeScene(store: store, router: nil)
    scene.tapConquestContinueForTesting()
    #expect(scene.isConquestContinueEnabledForTesting)
    #expect(store.load().pendingBattleResult != nil)
}

@Test func reportBlocksEveryUnderlyingTouchPath() throws {
    let store = try makeStore(initialState: pendingConqueredState())
    let router = BattleRouterSpy()
    let scene = makeScene(store: store, router: router)
    let before = scene.gameStateForTesting
    for point in scene.underlyingControlCentersForTesting {
        scene.handleTouchForTesting(at: point)
    }
    #expect(scene.gameStateForTesting == before)
    #expect(scene.liveSoldierCountForTesting == 0)
    #expect(router.buildingRequestCount == 0)
    #expect(router.countryMapRequestCount == 0)
    #expect(!scene.isFeedbackTooltipVisibleForTesting)
}

@Test func resizeAfterDisableCannotReenableContinue() throws {
    let store = try makeStore(initialState: pendingConqueredState())
    let router = BattleRouterSpy()
    let scene = makeScene(store: store, router: router)
    scene.tapConquestContinueForTesting()
    scene.refreshLayoutForCurrentEnvironment()
    scene.redrawForTesting(shouldLayout: true)
    #expect(!scene.isConquestContinueEnabledForTesting)
}
```

- [ ] **Step 2: Factor production touch dispatch**

```swift
override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let point = touches.first?.location(in: self) else { return }
    handleTouch(at: point)
}

private func handleTouch(at point: CGPoint) {
    if isConquestReportVisible || isConquestReportFitFailed {
        guard !isConquestReportFitFailed,
              conquestReportNode.containsContinue(point) else { return }
        continueFromConquestReport()
        return
    }
    handleTouch(named: buttonName(at: point))
}
```

Remove the legacy popup button name/case.

- [ ] **Step 3: Implement the exact transaction**

```swift
private func continueFromConquestReport() {
    guard isConquestReportVisible,
          isConquestContinueEnabled,
          !isConquestReportFitFailed,
          state.pendingBattleResult != nil,
          let router else { return }
    isConquestContinueEnabled = false
    _ = applyPendingConquestReport(resetsContinueState: false)
    state.acknowledgePendingBattleResult()
    store.save(state)
    router.battleSceneDidRequestCountryMap(self)
}
```

Keep the disabled report visible until scene replacement. DEBUG tap helpers must call `handleTouch(at:)`, not bypass the production transaction.

- [ ] **Step 4: Run and commit**

```bash
git add Pyxis/BattleScene.swift PyxisTests/BattleSceneTests.swift
git commit -m "feat: acknowledge conquest report before routing"
```

---

### Task 9: Add Pending-First Routing and Fit-Gate Recovery

**Files:**
- Modify: `Pyxis/GameViewController.swift`
- Modify: `PyxisTests/GameViewControllerTests.swift`
- Modify: `PyxisTests/BuildingViewSceneTests.swift`

- [ ] **Step 1: Add failing routing tests**

```swift
@Test func pendingResultWinsOverBothConqueredStagesAtLaunch() throws {
    for stage in [KingdomGameState.StageStatus.cityConqueredPendingMap, .countryComplete] {
        let city = stage == .countryComplete ? 15 : 3
        let store = try makeStore(initialState: pendingConqueredState(city: city, stage: stage))
        let controller = GameViewController(store: store)
        let view = SKView(frame: .init(x: 0, y: 0, width: 393, height: 852))
        controller.view = view
        controller.viewDidLoad()
        #expect(view.scene is BattleScene)
    }
}

@Test func conqueredStateWithoutPendingStillUsesMap() throws {
    let store = try makeStore(initialState: .init(
        cityRemainingPower: 0,
        cityNumberInCountry: 3,
        completedCityCount: 3,
        stageStatus: .cityConqueredPendingMap
    ))
    let controller = GameViewController(store: store)
    let view = SKView(frame: .init(x: 0, y: 0, width: 393, height: 852))
    controller.view = view
    controller.viewDidLoad()
    #expect(view.scene is CountryMapScene)
}

@Test func buildingViewBattleRequestRestoresPendingIdleReport() throws {
    let store = try makeStore(initialState: pendingConqueredState(mode: .idle))
    let controller = GameViewController(store: store)
    let view = SKView(frame: .init(x: 0, y: 0, width: 393, height: 852))
    controller.view = view
    let building = BuildingViewScene(size: view.bounds.size, store: store, router: controller)
    controller.buildingViewSceneDidRequestBattle(building)
    let battle = try #require(view.scene as? BattleScene)
    #expect(battle.conquestReportLinesForTesting[1] == "Conquered by your buildings")
    #expect(!battle.isGoldBurstVisibleForTesting)
}
```

- [ ] **Step 2: Add failing gate and safe-inset tests**

```swift
@Test func battleReportFitFailureUsesExistingGateAndRecovers() throws {
    let store = try makeStore(initialState: .init(stageStatus: .battleActive))
    let controller = GameViewController(store: store)
    let view = SKView(frame: .init(x: 0, y: 0, width: 393, height: 852))
    controller.view = view
    controller.viewDidLoad()
    let battle = try #require(view.scene as? BattleScene)
    battle.setConquestReportFitFailedForTesting(true)
    controller.refreshLayoutSupportForTesting(environment: .init(
        safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0),
        layoutClass: .phone
    ))
    #expect(controller.layoutGateReasonForTesting == .unsupportedGeometry)
    battle.setConquestReportFitFailedForTesting(false)
    controller.refreshLayoutSupportForTesting(environment: .init(
        safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0),
        layoutClass: .phone
    ))
    #expect(controller.layoutGateReasonForTesting == nil)
}
```

For horizontal insets, use an `SKView` test subclass overriding `safeAreaInsets`, present a pending Battle Scene in it, and assert `lastConquestReportLayoutInputForTesting.safeAreaInsets.left/right == 50`.

- [ ] **Step 3: Pin Building View behavior with regression tests**

Use existing Building View state factories and production paths to assert:

```swift
#expect(scene.gameStateForTesting.pendingBattleResult?.conquestMode == .idle)
#expect(scene.feedbackTextForTesting.contains("conquered"))
#expect(router.battleRequestCount == 0) // immediately after settlement/foreground catch-up
scene.requestBattleForTesting()
#expect(router.battleRequestCount == 1)
#expect(store.load().pendingBattleResult != nil)
```

Add one case where `requestBattleForTesting()` performs the final catch-up and creates the pending result before routing. No production Building View change is allowed.

- [ ] **Step 4: Implement controller routing and gate branch**

```swift
private func presentSceneForCurrentStage(in view: SKView) {
    let state = store.load()
    if state.pendingBattleResult != nil {
        presentBattleScene(in: view)
        return
    }
    switch state.stageStatus {
    case .battleActive: presentBattleScene(in: view)
    case .cityConqueredPendingMap, .countryComplete: presentCountryMapScene(in: view)
    }
}
```

In `refreshLayoutSupport`, check `BattleScene.isConquestReportFitFailed` before map-specific gate reasons and map it to `.unsupportedGeometry`.

- [ ] **Step 5: Run and commit**

```bash
git add Pyxis/GameViewController.swift \
  PyxisTests/GameViewControllerTests.swift PyxisTests/BuildingViewSceneTests.swift
git commit -m "feat: route pending reports through battle scene"
```

---

### Task 10: Close Acceptance Coverage, Docs, and Verification

**Files:**
- Modify: `PyxisTests/BattleSceneTests.swift`
- Modify: `PyxisTests/GameViewControllerTests.swift`
- Modify: `PyxisTests/BuildingViewSceneTests.swift`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Add the pre-release pending-save round trip**

```swift
@Test func compatiblePreReleasePendingResultDisplaysOnce() throws {
    let store = try makeStore(initialState: pendingConqueredState())
    let first = GameViewController(store: store)
    let firstView = SKView(frame: .init(x: 0, y: 0, width: 393, height: 852))
    first.view = firstView
    first.viewDidLoad()
    let battle = try #require(firstView.scene as? BattleScene)
    battle.tapConquestContinueForTesting()
    #expect(store.load().pendingBattleResult == nil)

    let second = GameViewController(store: store)
    let secondView = SKView(frame: firstView.frame)
    second.view = secondView
    second.viewDidLoad()
    #expect(secondView.scene is CountryMapScene)
}
```

Use a router/controller-backed scene so Continue routes through production behavior.

- [ ] **Step 2: Add final acceptance cases**

Add exact tests for:

```swift
@Test func repeatedDidMoveResizeAndRedrawDoNotDuplicateOrReplay() throws {
    let scene = makeScene(store: try makeStore(initialState: pendingConqueredState()))
    let controlCount = scene.conquestReportControlCountForTesting
    let effects = scene.conquestEffectPresentationCountForTesting
    scene.repeatDidMoveForTesting()
    scene.refreshLayoutForCurrentEnvironment()
    scene.redrawForTesting(shouldLayout: true)
    #expect(scene.conquestReportControlCountForTesting == controlCount)
    #expect(scene.conquestEffectPresentationCountForTesting == effects)
}
```

Also add separate test methods named:

- `zeroDeploymentLossAndNoMVPRemainReadable`
- `oneAchievementRendersOneBadge`
- `threeRowCompactLayoutKeepsContinueVisible`
- `fitFailureRetriesAndClearsAfterSupportedResize`
- `countryCompleteContinueRoutesToFinalMapOnce`

Each test must assert the exact report rows, badge count, Continue frame containment, fit-failure flag transition, and route count described by its name.

- [ ] **Step 3: Update `CLAUDE.md`**

Update the Battle Scene/controller/lifecycle sections to state that:

- Battle Scene renders `pendingBattleResult` with `ConquestReportNode`/`ConquestReportLayout`.
- Fresh effects do not replay on restoration or resize.
- Continue acknowledges and saves before routing.
- GameViewController uses pending-first routing and gates report fit failure.
- Building View conquest stays until explicit Battle.

Do not edit `AGENTS.md`.

- [ ] **Step 4: Run focused suites**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/SingleLineTextFitterTests \
  -only-testing:PyxisTests/CompactNumberFormatterTests \
  -only-testing:PyxisTests/BattleResultModelsTests \
  -only-testing:PyxisTests/ConquestReportContentTests \
  -only-testing:PyxisTests/ConquestReportLayoutTests \
  -only-testing:PyxisTests/ConquestReportNodeTests \
  -only-testing:PyxisTests/BattleSceneTests \
  -only-testing:PyxisTests/BuildingViewSceneTests \
  -only-testing:PyxisTests/GameViewControllerTests
```

Expected: zero failures and skipped tests.

- [ ] **Step 5: Run lint, build, and full tests**

```bash
swiftlint lint
xcodebuild build -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO
```

Expected: lint/build/full test suite exit 0.

- [ ] **Step 6: Manual smoke matrix**

Verify live conquest, Battle foreground idle conquest, Building settlement/idle handoff, relaunch before/after Continue, pre-release pending save, small phone, side-inset iPad, compact component geometry, and City 15 inert report/final route.

- [ ] **Step 7: Commit and final branch checks**

```bash
git add CLAUDE.md PyxisTests/BattleSceneTests.swift \
  PyxisTests/BuildingViewSceneTests.swift PyxisTests/GameViewControllerTests.swift
git commit -m "test: close compact report acceptance coverage"
git status --short
git diff --check main...HEAD
git log --oneline main..HEAD
```

Expected: clean worktree, no whitespace errors, task-scoped commits only.
