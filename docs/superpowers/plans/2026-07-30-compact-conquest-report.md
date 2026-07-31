# Compact Conquest Report Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the legacy gold-only conquest popup with a compact report rendered from persisted `pendingBattleResult`, restore it safely across relaunch and Building View handoff, and acknowledge/save/route exactly once.

**Architecture:** Foundation/CoreGraphics-only helpers own text fitting, compact-number formatting, result projection, and report geometry. A focused `ConquestReportNode` owns SpriteKit rendering and exposes only Continue hit testing plus a gold-effect anchor. `BattleScene` owns presentation origin, effect lifecycle, input gating, acknowledgment, and fit-failure state; `GameViewController` owns pending-first scene routing and the existing unsupported-geometry gate.

**Tech Stack:** Swift 5, Swift Testing (`PyxisTests`), Foundation, CoreGraphics, SpriteKit/UIKit presentation, `KingdomGameStore` JSON/`UserDefaults`, Xcode / `xcodebuild` on macOS.

## Global Constraints

- Approved design: `docs/superpowers/specs/2026-07-30-compact-conquest-report-design.md`.
- Required report rows are exactly:
  1. `Gold earned: +<amount>`
  2. live `Battle time: <duration>` or idle `Conquered by your buildings`
  3. optional `MVP: <SoldierType.displayName> · <percent>%`
  4. `Deployed: <count> · Lost: <count>`
- Render only from persisted `pendingBattleResult`; never inspect soldier nodes or create a second accumulator.
- `.idle` covers both offline catch-up and build/upgrade settlement; do not add a third persisted conquest mode or presentation origin.
- Settlement/idle conquest in `BuildingViewScene` stays there with existing feedback. The next explicit Battle request presents the report as static `.restored` with no effects.
- Continue order is synchronous and exact: disable input → `acknowledgePendingBattleResult()` → `store.save(state)` → one Country Map route.
- A compatible pending result from a pre-release save may display once after upgrade. Do not add a migration marker.
- A `.cityConqueredPendingMap` or `.countryComplete` Battle Scene is an inert report host; only enabled Continue may mutate or route.
- Current titles are numbered only. Use one title; HPA-366 owns authored-name fallback and future long-title policy.
- Achievement badges use `checkmark.shield.fill` and `shield.slash.fill` directly. Do not add procedural fallbacks or SpriteKit accessibility claims.
- Read all four safe-area values directly from `SKView.safeAreaInsets`; do not modify `GameUITheme` for horizontal helpers.
- `ConquestReportLayout.compute` and `ConquestReportNode.apply` fail closed. On failure, preserve the pending result and route through the existing `.unsupportedGeometry` gate.
- TDD: write each failing test first, run it and observe failure, implement the smallest passing behavior, rerun, then commit.
- Do not edit `Pyxis.xcodeproj/project.pbxproj`; synchronized root groups pick up new Swift files automatically.
- Do not modify `Pyxis/BuildingViewScene.swift`, `Pyxis/GameUITheme.swift`, or `Pyxis/CityDefinition.swift`.
- Preserve unrelated work. Run `git status --short` before each commit and stage only files named by that task.
- Swift tests require macOS + Xcode. Always disable parallel testing. Preferred XcodeBuildMCP: `test_sim` with `extraArgs: ["-parallel-testing-enabled", "NO"]`. Fallback:
  ```bash
  xcodebuild test \
    -project Pyxis.xcodeproj \
    -scheme Pyxis \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -parallel-testing-enabled NO \
    -only-testing:PyxisTests/<SuiteName>
  ```
  If `iPhone 17` is unavailable, run `xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -showdestinations` and use one available simulator consistently.

## File Map

### Create

- `Pyxis/SingleLineTextFitter.swift` — framework-free whole-point single-line font fitting.
- `Pyxis/CompactNumberFormatter.swift` — shared compact integer copy.
- `Pyxis/ConquestReportContent.swift` — pure projection from `BattleResult` to final title, rows, and achievements.
- `Pyxis/ConquestReportLayout.swift` — failable safe-area-aware report geometry.
- `Pyxis/ConquestReportNode.swift` — reusable SpriteKit report rendering, Continue hit testing, and gold anchor.
- `PyxisTests/SingleLineTextFitterTests.swift`
- `PyxisTests/CompactNumberFormatterTests.swift`
- `PyxisTests/ConquestReportContentTests.swift`
- `PyxisTests/ConquestReportLayoutTests.swift`
- `PyxisTests/ConquestReportNodeTests.swift`

### Modify

- `Pyxis/CountryMapScoutCardTextLayout.swift` — forward its existing fit API to `SingleLineTextFitter`.
- `Pyxis/BattleResultModels.swift` — add saturating deployment/loss totals.
- `Pyxis/BattleScene.swift` — replace legacy popup, integrate pending report lifecycle/effects/input/acknowledgment.
- `Pyxis/GameViewController.swift` — pending-first routing and Battle report fit gate.
- `PyxisTests/CountryMapScoutCardTextLayoutTests.swift`
- `PyxisTests/BattleResultModelsTests.swift`
- `PyxisTests/BattleSceneTests.swift`
- `PyxisTests/BuildingViewSceneTests.swift`
- `PyxisTests/GameViewControllerTests.swift`
- `CLAUDE.md` — update Battle Scene/controller architecture after implementation.

---

### Task 1: Extract Shared Single-Line Text Fitting

**Files:**
- Create: `Pyxis/SingleLineTextFitter.swift`
- Create: `PyxisTests/SingleLineTextFitterTests.swift`
- Modify: `Pyxis/CountryMapScoutCardTextLayout.swift`
- Modify: `PyxisTests/CountryMapScoutCardTextLayoutTests.swift`

**Interfaces:**
- Produces:
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
- Preserves `CountryMapScoutCardTextLayout.fittedFontSize(...)` as a forwarding wrapper so existing Scout Card callers do not change.

- [ ] **Step 1: Write failing helper tests**

Create `PyxisTests/SingleLineTextFitterTests.swift`:

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

    @Test func includesMinimumSizeInSearch() {
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

- [ ] **Step 2: Run the focused suite and verify failure**

Run:

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/SingleLineTextFitterTests
```

Expected: compile failure because `SingleLineTextFitter` does not exist.

- [ ] **Step 3: Implement the shared helper**

Create `Pyxis/SingleLineTextFitter.swift`:

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

- [ ] **Step 4: Forward the Scout Card wrapper**

Replace only the body of `CountryMapScoutCardTextLayout.fittedFontSize`:

```swift
static func fittedFontSize(
    _ text: String,
    startingAt start: CGFloat,
    minimum: CGFloat,
    maximumWidth: CGFloat,
    measure: (String, CGFloat) -> CGFloat
) -> CGFloat? {
    SingleLineTextFitter.fittedFontSize(
        text,
        startingAt: start,
        minimum: minimum,
        maximumWidth: maximumWidth,
        measure: measure
    )
}
```

Add this equivalence test to `CountryMapScoutCardTextLayoutTests.swift`:

```swift
@Test func fittedFontSizeForwardsSharedWholePointBehavior() {
    let measure: (String, CGFloat) -> CGFloat = { text, size in
        CGFloat(text.count) * size
    }

    let scout = CountryMapScoutCardTextLayout.fittedFontSize(
        "AB",
        startingAt: 7.8,
        minimum: 4,
        maximumWidth: 10,
        measure: measure
    )
    let shared = SingleLineTextFitter.fittedFontSize(
        "AB",
        startingAt: 7.8,
        minimum: 4,
        maximumWidth: 10,
        measure: measure
    )

    #expect(scout == shared)
    #expect(scout == 5)
}
```

- [ ] **Step 5: Run both suites and verify pass**

Run with `-only-testing:PyxisTests/SingleLineTextFitterTests` and `-only-testing:PyxisTests/CountryMapScoutCardTextLayoutTests`. Expected: both green.

- [ ] **Step 6: Commit**

```bash
git add \
  Pyxis/SingleLineTextFitter.swift \
  Pyxis/CountryMapScoutCardTextLayout.swift \
  PyxisTests/SingleLineTextFitterTests.swift \
  PyxisTests/CountryMapScoutCardTextLayoutTests.swift
git commit -m "refactor: share single-line text fitting"
```

---

### Task 2: Extract Shared Compact-Number Formatting

**Files:**
- Create: `Pyxis/CompactNumberFormatter.swift`
- Create: `PyxisTests/CompactNumberFormatterTests.swift`
- Modify: `Pyxis/BattleScene.swift` (`compactNumber`, all call sites, DEBUG test seam)
- Modify: `PyxisTests/BattleSceneTests.swift` (move compact-number-only cases)

**Interfaces:**
- Produces:
  ```swift
  enum CompactNumberFormatter {
      static func string(from value: Int) -> String
  }
  ```
- `BattleScene` consumes the helper for HUD, damage, tooltip, and conquest-related numeric copy.

- [ ] **Step 1: Move formatter cases into a failing pure suite**

Create `PyxisTests/CompactNumberFormatterTests.swift`:

```swift
import Testing
@testable import Pyxis

struct CompactNumberFormatterTests {
    @Test(arguments: [
        (0, "0"),
        (999, "999"),
        (1_000, "1K"),
        (1_100, "1.1K"),
        (10_000, "10K"),
        (999_000, "999K"),
        (999_950, "1M"),
        (1_000_000, "1M"),
        (1_500_000, "1.5M"),
        (1_000_000_000, "1B"),
        (1_000_000_000_000, "1T"),
        (-1_500, "-1.5K")
    ])
    func formatsCurrentBattleSceneContract(value: Int, expected: String) {
        #expect(CompactNumberFormatter.string(from: value) == expected)
    }
}
```

Copy every existing `compactNumberForTesting` boundary from `BattleSceneTests` into this argument table before deleting the scene-only tests. Do not leave duplicate formatter truth in both suites.

- [ ] **Step 2: Run and verify failure**

Expected: compile failure because `CompactNumberFormatter` does not exist.

- [ ] **Step 3: Implement the pure formatter**

Create `Pyxis/CompactNumberFormatter.swift`:

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

        guard let unitIndex = units.firstIndex(where: { magnitude >= $0.threshold }) else {
            return String(value)
        }

        let unit = units[unitIndex]
        let scaled = Double(magnitude) / Double(unit.threshold)
        let roundedTenths = (scaled * 10).rounded() / 10
        let integerRounded = roundedTenths.rounded()

        if integerRounded >= 1_000, unitIndex > 0 {
            let promoted = units[unitIndex - 1]
            let promotedScaled = Double(magnitude) / Double(promoted.threshold)
            let promotedRounded = (promotedScaled * 10).rounded() / 10
            let body = promotedRounded >= 10 || promotedRounded.rounded() == promotedRounded
                ? String(format: "%.0f", promotedRounded)
                : String(format: "%.1f", promotedRounded)
            return "\(sign)\(body)\(promoted.suffix)"
        }

        let body = roundedTenths >= 10 || roundedTenths.rounded() == roundedTenths
            ? String(format: "%.0f", roundedTenths)
            : String(format: "%.1f", roundedTenths)
        return "\(sign)\(body)\(unit.suffix)"
    }
}
```

- [ ] **Step 4: Migrate Battle Scene consumers**

Replace every `compactNumber(value)` call with:

```swift
CompactNumberFormatter.string(from: value)
```

Delete `BattleScene.compactNumber(_:)` and its DEBUG `compactNumberForTesting` forwarding seam after all formatter-only tests have moved.

- [ ] **Step 5: Run formatter and Battle Scene suites**

Expected: `CompactNumberFormatterTests` and `BattleSceneTests` pass with no old scene formatter references.

- [ ] **Step 6: Commit**

```bash
git add \
  Pyxis/CompactNumberFormatter.swift \
  Pyxis/BattleScene.swift \
  PyxisTests/CompactNumberFormatterTests.swift \
  PyxisTests/BattleSceneTests.swift
git commit -m "refactor: share compact number formatting"
```

---

### Task 3: Add Result Totals and Pure Report Projection

**Files:**
- Modify: `Pyxis/BattleResultModels.swift`
- Create: `Pyxis/ConquestReportContent.swift`
- Modify: `PyxisTests/BattleResultModelsTests.swift`
- Create: `PyxisTests/ConquestReportContentTests.swift`

**Interfaces:**
- Produces:
  ```swift
  extension BattleResult {
      var totalDeploymentCount: Int { get }
      var totalLossCount: Int { get }
  }

  struct ConquestReportContent: Equatable {
      enum Achievement: Equatable {
          case favorableUnit
          case exposedLane
      }

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

Append to `BattleResultModelsTests.swift`:

```swift
@Test func finalizedTotalsSumNormalizedRows() {
    let result = BattleResult(
        cityKey: CityKey(countryNumber: 1, cityNumber: 3),
        conquestMode: .live,
        activeBattleSeconds: 0,
        deployments: [
            SiegeDeploymentCount(type: .infantry, source: .manual, lane: .left, count: 2),
            SiegeDeploymentCount(type: .archer, source: .building, lane: .right, count: 5)
        ],
        appliedDamage: [],
        losses: [
            SiegeLossCount(type: .infantry, source: .manual, count: 1),
            SiegeLossCount(type: .archer, source: .building, count: 3)
        ],
        idleDamageByType: [],
        mvpSoldierType: nil,
        mvpDamageSharePercent: nil,
        usedFavorableUnit: false,
        usedExposedLane: false,
        goldEarned: 8
    )

    #expect(result.totalDeploymentCount == 7)
    #expect(result.totalLossCount == 4)
}

@Test func finalizedTotalsSaturateInsteadOfOverflowing() {
    let result = BattleResult(
        cityKey: CityKey(countryNumber: 1, cityNumber: 3),
        conquestMode: .live,
        activeBattleSeconds: 0,
        deployments: [
            SiegeDeploymentCount(type: .infantry, source: .manual, lane: .left, count: Int.max),
            SiegeDeploymentCount(type: .archer, source: .building, lane: .right, count: 1)
        ],
        appliedDamage: [],
        losses: [
            SiegeLossCount(type: .infantry, source: .manual, count: Int.max),
            SiegeLossCount(type: .archer, source: .building, count: 1)
        ],
        idleDamageByType: [],
        mvpSoldierType: nil,
        mvpDamageSharePercent: nil,
        usedFavorableUnit: false,
        usedExposedLane: false,
        goldEarned: 8
    )

    #expect(result.totalDeploymentCount == Int.max)
    #expect(result.totalLossCount == Int.max)
}
```

- [ ] **Step 2: Add failing projection tests**

Create `PyxisTests/ConquestReportContentTests.swift` with this helper and cases:

```swift
import Testing
@testable import Pyxis

struct ConquestReportContentTests {
    private func makeResult(
        mode: BattleConquestMode = .live,
        seconds: TimeInterval = 65,
        deployments: Int = 7,
        losses: Int = 2,
        mvp: SoldierType? = .archer,
        share: Int? = 63,
        favorable: Bool = true,
        exposed: Bool = true,
        gold: Int = 1_500,
        city: Int = 3
    ) -> BattleResult {
        BattleResult(
            cityKey: CityKey(countryNumber: 1, cityNumber: city),
            conquestMode: mode,
            activeBattleSeconds: seconds,
            deployments: deployments == 0 ? [] : [
                SiegeDeploymentCount(
                    type: .infantry,
                    source: .manual,
                    lane: .center,
                    count: deployments
                )
            ],
            appliedDamage: [],
            losses: losses == 0 ? [] : [
                SiegeLossCount(type: .infantry, source: .manual, count: losses)
            ],
            idleDamageByType: [],
            mvpSoldierType: mvp,
            mvpDamageSharePercent: share,
            usedFavorableUnit: favorable,
            usedExposedLane: exposed,
            goldEarned: gold
        )
    }

    @Test func liveReportProjectsFourRowsAndAchievements() {
        let content = ConquestReportContent.project(
            from: makeResult(),
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

    @Test func idleReportUsesBuildingCopyAndSuppressesDuration() {
        let content = ConquestReportContent.project(
            from: makeResult(mode: .idle, seconds: 90_061),
            cityTitle: "Country 1 - City 3",
            isCountryComplete: false
        )

        #expect(content.summaryLines[1] == "Conquered by your buildings")
        #expect(!content.summaryLines.contains(where: { $0.contains("Battle time") }))
    }

    @Test func missingMVPProducesThreeRowsWithoutGap() {
        let content = ConquestReportContent.project(
            from: makeResult(mvp: nil, share: nil),
            cityTitle: "Country 1 - City 3",
            isCountryComplete: false
        )

        #expect(content.summaryLines == [
            "Gold earned: +1.5K",
            "Battle time: 1m 5s",
            "Deployed: 7 · Lost: 2"
        ])
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
        (0.0, "0s"),
        (59.9, "59s"),
        (60.0, "1m"),
        (65.0, "1m 5s"),
        (3_599.0, "59m 59s"),
        (3_600.0, "1h"),
        (3_612.0, "1h 00m 12s"),
        (3_660.0, "1h 01m"),
        (3_672.0, "1h 01m 12s"),
        (90_000.0, "25h"),
        (90_061.0, "25h 01m 01s")
    ])
    func durationGoldenStrings(seconds: TimeInterval, expected: String) {
        let content = ConquestReportContent.project(
            from: makeResult(seconds: seconds),
            cityTitle: "Country 1 - City 3",
            isCountryComplete: false
        )

        #expect(content.summaryLines[1] == "Battle time: \(expected)")
    }
}
```

- [ ] **Step 3: Run both suites and verify failure**

Expected: missing total accessors and `ConquestReportContent` compile failures.

- [ ] **Step 4: Implement saturating totals**

Add inside `BattleResultModels.swift`:

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

Rows are normalized non-negative values, so saturation only needs the positive-overflow path.

- [ ] **Step 5: Implement pure content projection**

Create `Pyxis/ConquestReportContent.swift`:

```swift
import Foundation

struct ConquestReportContent: Equatable {
    enum Achievement: Equatable {
        case favorableUnit
        case exposedLane
    }

    let title: String
    let summaryLines: [String]
    let achievements: [Achievement]

    static func project(
        from result: BattleResult,
        cityTitle: String,
        isCountryComplete: Bool
    ) -> ConquestReportContent {
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
        if result.usedFavorableUnit {
            achievements.append(.favorableUnit)
        }
        if result.usedExposedLane {
            achievements.append(.exposedLane)
        }

        return ConquestReportContent(
            title: title,
            summaryLines: lines,
            achievements: achievements
        )
    }

    private static func durationText(_ rawValue: TimeInterval) -> String {
        let normalized = ActiveSiegeSession.normalizedActiveBattleSeconds(rawValue)
        let totalSeconds = Int(normalized)
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if hours == 0, minutes == 0 {
            return "\(seconds)s"
        }
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

- [ ] **Step 6: Add remaining projection cases**

Add tests for zero deployment/loss, each single achievement, no achievements, only one MVP field present (omit MVP), non-finite/negative duration normalizing to `0s`, and exactly three-or-four row count.

- [ ] **Step 7: Run and verify pass**

Expected: `BattleResultModelsTests` and `ConquestReportContentTests` green.

- [ ] **Step 8: Commit**

```bash
git add \
  Pyxis/BattleResultModels.swift \
  Pyxis/ConquestReportContent.swift \
  PyxisTests/BattleResultModelsTests.swift \
  PyxisTests/ConquestReportContentTests.swift
git commit -m "feat: project compact conquest report content"
```

---

### Task 4: Add Failable Safe-Area Report Geometry

**Files:**
- Create: `Pyxis/ConquestReportLayout.swift`
- Create: `PyxisTests/ConquestReportLayoutTests.swift`

**Interfaces:**
- Produces:
  ```swift
  struct ConquestReportSafeAreaInsets: Equatable {
      let top: CGFloat
      let left: CGFloat
      let bottom: CGFloat
      let right: CGFloat
  }

  struct ConquestReportLayout: Equatable {
      struct Input: Equatable {
          let sceneSize: CGSize
          let safeAreaInsets: ConquestReportSafeAreaInsets
          let battleContentWidth: CGFloat
          let summaryRowCount: Int
          let achievementCount: Int
          let compactHeight: Bool
      }

      let safeFrame: CGRect
      let panelFrame: CGRect
      let titleFrame: CGRect
      let summaryRowFrames: [CGRect]
      let achievementStripFrame: CGRect?
      let continueFrame: CGRect
      let titleStartingFontSize: CGFloat
      let titleMinimumFontSize: CGFloat
      let summaryStartingFontSize: CGFloat
      let summaryMinimumFontSize: CGFloat
      let continueFontSize: CGFloat
      let badgeSize: CGFloat
      let badgeGap: CGFloat

      static func compute(_ input: Input) -> ConquestReportLayout?
  }
  ```

- [ ] **Step 1: Write failing arithmetic and fixture tests**

Create `PyxisTests/ConquestReportLayoutTests.swift`. Define fixtures explicitly so this component test does not depend on map internals:

```swift
import CoreGraphics
import Testing
@testable import Pyxis

struct ConquestReportLayoutTests {
    private struct Fixture {
        let size: CGSize
        let insets: ConquestReportSafeAreaInsets
    }

    private let supportedFixtures: [Fixture] = [
        Fixture(size: CGSize(width: 375, height: 667), insets: .init(top: 0, left: 0, bottom: 0, right: 0)),
        Fixture(size: CGSize(width: 375, height: 812), insets: .init(top: 50, left: 0, bottom: 34, right: 0)),
        Fixture(size: CGSize(width: 393, height: 852), insets: .init(top: 59, left: 0, bottom: 34, right: 0)),
        Fixture(size: CGSize(width: 440, height: 956), insets: .init(top: 62, left: 0, bottom: 34, right: 0)),
        Fixture(size: CGSize(width: 480, height: 1194), insets: .init(top: 24, left: 0, bottom: 20, right: 0)),
        Fixture(size: CGSize(width: 600, height: 1008), insets: .init(top: 28, left: 0, bottom: 20, right: 0)),
        Fixture(size: CGSize(width: 744, height: 1133), insets: .init(top: 24, left: 0, bottom: 20, right: 0)),
        Fixture(size: CGSize(width: 834, height: 1194), insets: .init(top: 24, left: 0, bottom: 20, right: 0)),
        Fixture(size: CGSize(width: 1032, height: 1376), insets: .init(top: 24, left: 0, bottom: 20, right: 0)),
        Fixture(size: CGSize(width: 834, height: 1194), insets: .init(top: 24, left: 50, bottom: 20, right: 50))
    ]

    private func battleContentWidth(for size: CGSize, compact: Bool) -> CGFloat {
        let margin = max(8, min(compact ? 16 : 18, size.width * 0.045))
        return min(max(0, size.width - margin * 2), 560)
    }

    @Test func standardFourRowTwoBadgeHeightIsDeterministic() throws {
        let layout = try #require(ConquestReportLayout.compute(.init(
            sceneSize: CGSize(width: 375, height: 667),
            safeAreaInsets: .init(top: 0, left: 0, bottom: 0, right: 0),
            battleContentWidth: 341.25,
            summaryRowCount: 4,
            achievementCount: 2,
            compactHeight: false
        )))

        #expect(layout.panelFrame.height == 282)
        #expect(layout.summaryRowFrames.count == 4)
        #expect(layout.achievementStripFrame?.height == 24)
        #expect(layout.continueFrame.height == 48)
    }

    @Test func compactFourRowTwoBadgeHeightIsDeterministic() throws {
        let layout = try #require(ConquestReportLayout.compute(.init(
            sceneSize: CGSize(width: 375, height: 499),
            safeAreaInsets: .init(top: 0, left: 0, bottom: 0, right: 0),
            battleContentWidth: 343,
            summaryRowCount: 4,
            achievementCount: 2,
            compactHeight: true
        )))

        #expect(layout.panelFrame.height == 230)
        #expect(layout.continueFrame.height == 44)
    }

    @Test func everySupportedFixtureContainsAllFrames() throws {
        for fixture in supportedFixtures {
            let compact = fixture.size.height < 500
            let layout = try #require(ConquestReportLayout.compute(.init(
                sceneSize: fixture.size,
                safeAreaInsets: fixture.insets,
                battleContentWidth: battleContentWidth(for: fixture.size, compact: compact),
                summaryRowCount: 4,
                achievementCount: 2,
                compactHeight: compact
            )))

            #expect(layout.safeFrame.contains(layout.panelFrame))
            #expect(layout.panelFrame.contains(layout.titleFrame))
            #expect(layout.summaryRowFrames.allSatisfy(layout.panelFrame.contains))
            #expect(layout.achievementStripFrame.map(layout.panelFrame.contains) ?? true)
            #expect(layout.panelFrame.contains(layout.continueFrame))
        }
    }

    @Test func insufficientSafeGeometryReturnsNil() {
        #expect(ConquestReportLayout.compute(.init(
            sceneSize: CGSize(width: 80, height: 200),
            safeAreaInsets: .init(top: 0, left: 20, bottom: 0, right: 20),
            battleContentWidth: 80,
            summaryRowCount: 4,
            achievementCount: 2,
            compactHeight: true
        )) == nil)

        #expect(ConquestReportLayout.compute(.init(
            sceneSize: CGSize(width: 375, height: 200),
            safeAreaInsets: .init(top: 20, left: 0, bottom: 20, right: 0),
            battleContentWidth: 341.25,
            summaryRowCount: 4,
            achievementCount: 2,
            compactHeight: true
        )) == nil)
    }
}
```

Add separate tests for three rows/no badge, one badge width, side-inset centering, invalid row count, and invalid achievement count.

- [ ] **Step 2: Run and verify failure**

Expected: compile failure because layout types do not exist.

- [ ] **Step 3: Implement the pure layout**

Create `Pyxis/ConquestReportLayout.swift` with the interfaces above and this computation structure:

```swift
import CoreGraphics

struct ConquestReportSafeAreaInsets: Equatable {
    let top: CGFloat
    let left: CGFloat
    let bottom: CGFloat
    let right: CGFloat
}

struct ConquestReportLayout: Equatable {
    struct Input: Equatable {
        let sceneSize: CGSize
        let safeAreaInsets: ConquestReportSafeAreaInsets
        let battleContentWidth: CGFloat
        let summaryRowCount: Int
        let achievementCount: Int
        let compactHeight: Bool
    }

    let safeFrame: CGRect
    let panelFrame: CGRect
    let titleFrame: CGRect
    let summaryRowFrames: [CGRect]
    let achievementStripFrame: CGRect?
    let continueFrame: CGRect
    let titleStartingFontSize: CGFloat
    let titleMinimumFontSize: CGFloat
    let summaryStartingFontSize: CGFloat
    let summaryMinimumFontSize: CGFloat
    let continueFontSize: CGFloat
    let badgeSize: CGFloat
    let badgeGap: CGFloat

    static func compute(_ input: Input) -> ConquestReportLayout? {
        guard (3...4).contains(input.summaryRowCount),
              (0...2).contains(input.achievementCount) else {
            return nil
        }

        let safeWidth = input.sceneSize.width
            - input.safeAreaInsets.left
            - input.safeAreaInsets.right
        let safeHeight = input.sceneSize.height
            - input.safeAreaInsets.top
            - input.safeAreaInsets.bottom
        guard safeWidth > 0, safeHeight > 0 else { return nil }

        let safeFrame = CGRect(
            x: input.safeAreaInsets.left,
            y: input.safeAreaInsets.bottom,
            width: safeWidth,
            height: safeHeight
        )

        let horizontalPadding: CGFloat = input.compactHeight ? 18 : 24
        let verticalPadding: CGFloat = input.compactHeight ? 14 : 18
        let titleLine: CGFloat = input.compactHeight ? 24 : 30
        let titleRowsGap: CGFloat = input.compactHeight ? 8 : 10
        let rowLine: CGFloat = input.compactHeight ? 20 : 24
        let rowGap: CGFloat = input.compactHeight ? 2 : 4
        let badgeSize: CGFloat = input.compactHeight ? 20 : 24
        let badgeGap: CGFloat = input.compactHeight ? 6 : 8
        let rowsBadgeGap: CGFloat = input.compactHeight ? 8 : 10
        let contentContinueGap: CGFloat = input.compactHeight ? 12 : 16
        let continueHeight: CGFloat = input.compactHeight ? 44 : 48

        let panelWidth = min(input.battleContentWidth, safeWidth - 56)
        let continueWidth = panelWidth - 48
        guard panelWidth > horizontalPadding * 2,
              continueWidth >= 44 else {
            return nil
        }

        let badgeHeight = input.achievementCount > 0
            ? rowsBadgeGap + badgeSize
            : 0
        let panelHeight = verticalPadding * 2
            + titleLine
            + titleRowsGap
            + CGFloat(input.summaryRowCount) * rowLine
            + CGFloat(input.summaryRowCount - 1) * rowGap
            + badgeHeight
            + contentContinueGap
            + continueHeight
        guard panelHeight <= safeHeight else { return nil }

        let panelFrame = CGRect(
            x: safeFrame.midX - panelWidth / 2,
            y: safeFrame.midY - panelHeight / 2,
            width: panelWidth,
            height: panelHeight
        )
        var cursor = panelFrame.maxY - verticalPadding
        let titleFrame = CGRect(
            x: panelFrame.minX + horizontalPadding,
            y: cursor - titleLine,
            width: panelFrame.width - horizontalPadding * 2,
            height: titleLine
        )
        cursor = titleFrame.minY - titleRowsGap

        var rowFrames = [CGRect]()
        for index in 0..<input.summaryRowCount {
            let frame = CGRect(
                x: panelFrame.minX + horizontalPadding,
                y: cursor - rowLine,
                width: panelFrame.width - horizontalPadding * 2,
                height: rowLine
            )
            rowFrames.append(frame)
            cursor = frame.minY
            if index < input.summaryRowCount - 1 {
                cursor -= rowGap
            }
        }

        let badgeFrame: CGRect?
        if input.achievementCount > 0 {
            cursor -= rowsBadgeGap
            let width = CGFloat(input.achievementCount) * badgeSize
                + CGFloat(input.achievementCount - 1) * badgeGap
            badgeFrame = CGRect(
                x: panelFrame.midX - width / 2,
                y: cursor - badgeSize,
                width: width,
                height: badgeSize
            )
            cursor = badgeFrame?.minY ?? cursor
        } else {
            badgeFrame = nil
        }

        cursor -= contentContinueGap
        let continueFrame = CGRect(
            x: panelFrame.midX - continueWidth / 2,
            y: cursor - continueHeight,
            width: continueWidth,
            height: continueHeight
        )

        let requiredFrames = [panelFrame, titleFrame, continueFrame]
            + rowFrames
            + (badgeFrame.map { [$0] } ?? [])
        guard safeFrame.contains(panelFrame),
              requiredFrames.dropFirst().allSatisfy(panelFrame.contains),
              abs(continueFrame.minY - verticalPadding - panelFrame.minY) < 0.001 else {
            return nil
        }

        return ConquestReportLayout(
            safeFrame: safeFrame,
            panelFrame: panelFrame,
            titleFrame: titleFrame,
            summaryRowFrames: rowFrames,
            achievementStripFrame: badgeFrame,
            continueFrame: continueFrame,
            titleStartingFontSize: input.compactHeight ? 19 : 22,
            titleMinimumFontSize: 14,
            summaryStartingFontSize: input.compactHeight ? 14 : 17,
            summaryMinimumFontSize: 12,
            continueFontSize: input.compactHeight ? 15 : 16,
            badgeSize: badgeSize,
            badgeGap: badgeGap
        )
    }
}
```

- [ ] **Step 4: Run and verify pass**

Expected: all layout arithmetic and fixture tests green.

- [ ] **Step 5: Commit**

```bash
git add Pyxis/ConquestReportLayout.swift PyxisTests/ConquestReportLayoutTests.swift
git commit -m "feat: add compact conquest report layout"
```

---

### Task 5: Build the Reusable Conquest Report Node

**Files:**
- Create: `Pyxis/ConquestReportNode.swift`
- Create: `PyxisTests/ConquestReportNodeTests.swift`

**Interfaces:**
- Consumes `ConquestReportContent`, `ConquestReportLayout`, and `SingleLineTextFitter`.
- Produces:
  ```swift
  final class ConquestReportNode: SKNode {
      enum ApplyResult: Equatable {
          case presented
          case requiredContentDoesNotFit
      }

      func apply(
          content: ConquestReportContent,
          layout: ConquestReportLayout,
          isContinueEnabled: Bool
      ) -> ApplyResult

      func containsContinue(_ scenePoint: CGPoint) -> Bool
      func goldEffectAnchor(in coordinateNode: SKNode) -> CGPoint?
  }
  ```

- [ ] **Step 1: Write failing node tests**

Create `PyxisTests/ConquestReportNodeTests.swift` with a deterministic width measurer:

```swift
import SpriteKit
import Testing
import UIKit
@testable import Pyxis

@MainActor
struct ConquestReportNodeTests {
    private func layout(rows: Int = 4, achievements: Int = 2) throws -> ConquestReportLayout {
        try #require(ConquestReportLayout.compute(.init(
            sceneSize: CGSize(width: 393, height: 852),
            safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0),
            battleContentWidth: 357.63,
            summaryRowCount: rows,
            achievementCount: achievements,
            compactHeight: false
        )))
    }

    private func content(rows: [String]? = nil) -> ConquestReportContent {
        ConquestReportContent(
            title: "Country 1 - City 3 Conquered",
            summaryLines: rows ?? [
                "Gold earned: +1.5K",
                "Battle time: 1m 5s",
                "MVP: Archer · 63%",
                "Deployed: 7 · Lost: 2"
            ],
            achievements: [.favorableUnit, .exposedLane]
        )
    }

    @Test func applyBuildsOneReusableReportTree() throws {
        let node = ConquestReportNode()
        let reportLayout = try layout()

        #expect(node.apply(
            content: content(),
            layout: reportLayout,
            isContinueEnabled: true
        ) == .presented)
        let firstCounts = node.nodeCountsForTesting

        #expect(node.apply(
            content: content(),
            layout: reportLayout,
            isContinueEnabled: true
        ) == .presented)
        #expect(node.nodeCountsForTesting == firstCounts)
        #expect(node.renderedSummaryLinesForTesting.count == 4)
        #expect(node.renderedAchievementCountForTesting == 2)
        #expect(node.continueControlCountForTesting == 1)
    }

    @Test func disabledContinueHasNoHitTarget() throws {
        let node = ConquestReportNode()
        let reportLayout = try layout()
        _ = node.apply(content: content(), layout: reportLayout, isContinueEnabled: false)

        #expect(!node.containsContinue(CGPoint(
            x: reportLayout.continueFrame.midX,
            y: reportLayout.continueFrame.midY
        )))
        #expect(node.isContinueEnabledForTesting == false)
    }

    @Test func goldAnchorUsesFirstSummaryRowCenter() throws {
        let scene = SKScene(size: CGSize(width: 393, height: 852))
        let node = ConquestReportNode()
        scene.addChild(node)
        let reportLayout = try layout()
        _ = node.apply(content: content(), layout: reportLayout, isContinueEnabled: true)

        #expect(node.goldEffectAnchor(in: scene) == CGPoint(
            x: reportLayout.summaryRowFrames[0].midX,
            y: reportLayout.summaryRowFrames[0].midY
        ))
    }

    @Test func textThatCannotFitReturnsFailureAndClearsHits() throws {
        let node = ConquestReportNode(textWidth: { text, _, _ in CGFloat(text.count) * 100 })
        let result = node.apply(
            content: content(),
            layout: try layout(),
            isContinueEnabled: true
        )

        #expect(result == .requiredContentDoesNotFit)
        #expect(node.continueHitFrameForTesting == nil)
        #expect(node.goldEffectAnchorForTesting == nil)
    }
}
```

Add cases for three rows, one/no badge, fixed badge order, title fitting to 14 pt, summary fitting to 12 pt without copy changes, and enabled Continue hit testing.

- [ ] **Step 2: Run and verify failure**

Expected: compile failure because `ConquestReportNode` does not exist.

- [ ] **Step 3: Implement the stable node tree**

Create `Pyxis/ConquestReportNode.swift`. Use one-time node construction in `init`, not per `apply`:

```swift
import Foundation
import SpriteKit
import UIKit

final class ConquestReportNode: SKNode {
    enum ApplyResult: Equatable {
        case presented
        case requiredContentDoesNotFit
    }

    typealias TextWidth = (_ text: String, _ fontName: String, _ size: CGFloat) -> CGFloat
    typealias SymbolLoader = (_ name: String) -> UIImage?

    private let textWidth: TextWidth
    private let symbolLoader: SymbolLoader
    private let panel = SKShapeNode()
    private let titleLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
    private let summaryLabels = (0..<4).map { _ in
        SKLabelNode(fontNamed: GameUITheme.Font.medium)
    }
    private let badgeSprites = [SKSpriteNode(), SKSpriteNode()]
    private let continueButton = SKNode()
    private let continueBackground = SKShapeNode()
    private let continueLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)

    private var continueHitFrame: CGRect?
    private var goldAnchor: CGPoint?
    private var isContinueEnabled = false

    init(
        textWidth: @escaping TextWidth = ConquestReportNode.productionTextWidth,
        symbolLoader: @escaping SymbolLoader = { UIImage(systemName: $0) }
    ) {
        self.textWidth = textWidth
        self.symbolLoader = symbolLoader
        super.init()
        buildNodeTree()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(
        content: ConquestReportContent,
        layout: ConquestReportLayout,
        isContinueEnabled: Bool
    ) -> ApplyResult {
        guard content.summaryLines.count == layout.summaryRowFrames.count,
              let titleSize = fittedSize(
                  content.title,
                  fontName: GameUITheme.Font.bold,
                  start: layout.titleStartingFontSize,
                  minimum: layout.titleMinimumFontSize,
                  width: layout.titleFrame.width
              ) else {
            return failApply()
        }

        var rowSizes = [CGFloat]()
        for (line, frame) in zip(content.summaryLines, layout.summaryRowFrames) {
            guard let size = fittedSize(
                line,
                fontName: GameUITheme.Font.medium,
                start: layout.summaryStartingFontSize,
                minimum: layout.summaryMinimumFontSize,
                width: frame.width
            ) else {
                return failApply()
            }
            rowSizes.append(size)
        }

        let symbolNames = content.achievements.map(symbolName)
        let images = symbolNames.compactMap(symbolLoader)
        guard images.count == symbolNames.count else {
            assertionFailure("Required conquest report SF Symbol is unavailable")
            return failApply()
        }

        panel.path = CGPath(
            roundedRect: layout.panelFrame,
            cornerWidth: 14,
            cornerHeight: 14,
            transform: nil
        )
        titleLabel.text = content.title
        titleLabel.fontSize = titleSize
        titleLabel.position = CGPoint(x: layout.titleFrame.midX, y: layout.titleFrame.midY)

        for (index, label) in summaryLabels.enumerated() {
            guard index < content.summaryLines.count else {
                label.text = nil
                label.isHidden = true
                continue
            }
            label.text = content.summaryLines[index]
            label.fontSize = rowSizes[index]
            label.position = CGPoint(
                x: layout.summaryRowFrames[index].midX,
                y: layout.summaryRowFrames[index].midY
            )
            label.isHidden = false
        }

        renderBadges(images, layout: layout)
        renderContinue(layout: layout, enabled: isContinueEnabled)
        goldAnchor = CGPoint(
            x: layout.summaryRowFrames[0].midX,
            y: layout.summaryRowFrames[0].midY
        )
        isHidden = false
        return .presented
    }

    func containsContinue(_ scenePoint: CGPoint) -> Bool {
        isContinueEnabled && (continueHitFrame?.contains(scenePoint) ?? false)
    }

    func goldEffectAnchor(in coordinateNode: SKNode) -> CGPoint? {
        guard let goldAnchor else { return nil }
        return convert(goldAnchor, to: coordinateNode)
    }

    private func fittedSize(
        _ text: String,
        fontName: String,
        start: CGFloat,
        minimum: CGFloat,
        width: CGFloat
    ) -> CGFloat? {
        SingleLineTextFitter.fittedFontSize(
            text,
            startingAt: start,
            minimum: minimum,
            maximumWidth: width,
            measure: { [textWidth] text, size in textWidth(text, fontName, size) }
        )
    }

    private static func productionTextWidth(
        _ text: String,
        _ fontName: String,
        _ size: CGFloat
    ) -> CGFloat {
        guard let font = UIFont(name: fontName, size: size) else {
            return .greatestFiniteMagnitude
        }
        return ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }
}
```

Complete the same file with:

- `buildNodeTree()` configuring colors, alignments, z positions, and adding each node exactly once.
- `symbolName(_:)` mapping `.favorableUnit` → `checkmark.shield.fill`, `.exposedLane` → `shield.slash.fill`.
- `renderBadges(_:layout:)` sizing/centering sprites inside `achievementStripFrame`, hiding unused sprites.
- `renderContinue(layout:enabled:)` drawing one rounded button, setting `Continue`, dimming when disabled, and assigning `continueHitFrame` only when enabled.
- `failApply()` hiding the report and clearing `continueHitFrame`/`goldAnchor`.
- A `#if DEBUG` extension exposing only the readbacks used above: node counts, rendered lines, badge count/order, Continue count/enabled/frame, gold anchor, title/row font sizes.

- [ ] **Step 4: Run and verify pass**

Expected: `ConquestReportNodeTests` green with both repeated apply and fit-failure paths.

- [ ] **Step 5: Commit**

```bash
git add Pyxis/ConquestReportNode.swift PyxisTests/ConquestReportNodeTests.swift
git commit -m "feat: add reusable conquest report node"
```

---

### Task 6: Replace the Legacy Popup with Restored Pending-Result Rendering

**Files:**
- Modify: `Pyxis/BattleScene.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`

**Interfaces:**
- Consumes `ConquestReportContent.project`, `ConquestReportLayout.compute`, and `ConquestReportNode.apply`.
- Produces scene state:
  ```swift
  private enum ConquestReportPresentationOrigin {
      case freshLive
      case freshIdle
      case restored
  }

  private var hasPresentedPendingConquestReport = false
  private var isConquestReportVisible = false
  private var isConquestContinueEnabled = true
  private(set) var isConquestReportFitFailed = false
  ```

- [ ] **Step 1: Add failing restored-report scene tests**

Add helpers in `BattleSceneTests.swift` to create a valid pending state:

```swift
private func pendingResult(
    city: Int = 3,
    mode: BattleConquestMode = .live,
    gold: Int = 12
) -> BattleResult {
    BattleResult(
        cityKey: CityKey(countryNumber: 1, cityNumber: city),
        conquestMode: mode,
        activeBattleSeconds: 65,
        deployments: [
            SiegeDeploymentCount(type: .infantry, source: .manual, lane: .center, count: 2)
        ],
        appliedDamage: [],
        losses: [],
        idleDamageByType: [],
        mvpSoldierType: .infantry,
        mvpDamageSharePercent: 100,
        usedFavorableUnit: true,
        usedExposedLane: false,
        goldEarned: gold
    )
}
```

Add tests:

```swift
@Test func newSceneRestoresPersistedPendingReportWithoutEffects() throws {
    let result = pendingResult()
    let store = try makeStore(initialState: KingdomGameState(
        gold: 27,
        cityLevel: 3,
        cityRemainingPower: 0,
        cityNumberInCountry: 3,
        completedCityCount: 3,
        stageStatus: .cityConqueredPendingMap,
        pendingBattleResult: result
    ))
    let scene = makeScene(store: store)

    #expect(scene.isConquestPopupVisibleForTesting)
    #expect(scene.conquestReportTitleForTesting == "Country 1 - City 3 Conquered")
    #expect(scene.conquestReportLinesForTesting[1] == "Battle time: 1m 5s")
    #expect(!scene.isGoldBurstVisibleForTesting)
    #expect(!scene.isCityConquestFeedbackRunningForTesting)
}

@Test func countryCompleteSceneRestoresAsInertReportHost() throws {
    let result = pendingResult(city: 15)
    let store = try makeStore(initialState: KingdomGameState(
        gold: 99,
        cityLevel: 15,
        cityRemainingPower: 0,
        cityNumberInCountry: 15,
        completedCityCount: 15,
        stageStatus: .countryComplete,
        pendingBattleResult: result
    ))
    let scene = makeScene(store: store)

    scene.advanceCombatForTesting(deltaTime: 10)

    #expect(scene.conquestReportTitleForTesting == "Country 1 Conquered")
    #expect(scene.gameStateForTesting == store.load())
    #expect(scene.liveSoldierCountForTesting == 0)
}
```

Add a test that a mismatched result fails the pure `isPendingResultPresentableForTesting` check and is not rendered; production wraps that check with a DEBUG assertion.

- [ ] **Step 2: Run and verify failure**

Expected: missing report readbacks and restored presentation failure.

- [ ] **Step 3: Replace popup node declarations and construction**

In `BattleScene.swift`:

1. Delete `popupOverlay`, `popupTitleLabel`, `popupRewardLabel`, `popupContinueButton`, `popupContinueBackground`, and `popupContinueLabel`.
2. Add:
   ```swift
   private let conquestReportNode = ConquestReportNode()
   private var hasPresentedPendingConquestReport = false
   private var isConquestReportVisible = false
   private var isConquestContinueEnabled = true
   private(set) var isConquestReportFitFailed = false
   ```
3. In `buildInterface()`, set `conquestReportNode.zPosition = GameUITheme.Z.modal`, hide it, and add it once.
4. Remove `layoutConquestPopup`, `showConquestPopup`, `setConquestPopupHidden`, and the legacy popup label font resets/fitting.
5. Replace existing `isConquestPopupVisible` guards with `isConquestReportVisible` while keeping `isConquestPopupVisibleForTesting` as a compatibility readback returning the new flag.

- [ ] **Step 4: Add content/layout application helpers**

Add:

```swift
private func pendingResultForPresentation() -> BattleResult? {
    guard let result = state.pendingBattleResult else { return nil }
    guard result.cityKey == state.currentCityKey else {
        assertionFailure("Pending BattleResult city does not match current city")
        return nil
    }
    return result
}

private func conquestReportContent(for result: BattleResult) -> ConquestReportContent {
    ConquestReportContent.project(
        from: result,
        cityTitle: state.displayCityTitle(for: result.cityKey.cityNumber),
        isCountryComplete: state.stageStatus == .countryComplete
    )
}

private func conquestReportLayout(for content: ConquestReportContent) -> ConquestReportLayout? {
    let metrics = layoutMetrics()
    let viewInsets = view?.safeAreaInsets ?? .zero
    return ConquestReportLayout.compute(.init(
        sceneSize: size,
        safeAreaInsets: ConquestReportSafeAreaInsets(
            top: viewInsets.top,
            left: viewInsets.left,
            bottom: viewInsets.bottom,
            right: viewInsets.right
        ),
        battleContentWidth: metrics.contentWidth,
        summaryRowCount: content.summaryLines.count,
        achievementCount: content.achievements.count,
        compactHeight: metrics.compactHeight
    ))
}

@discardableResult
private func applyPendingConquestReport(
    resetsContinueState: Bool
) -> Bool {
    guard let result = pendingResultForPresentation() else { return false }
    let content = conquestReportContent(for: result)
    guard let reportLayout = conquestReportLayout(for: content) else {
        isConquestReportFitFailed = true
        isConquestReportVisible = true
        conquestReportNode.isHidden = true
        return false
    }
    if resetsContinueState {
        isConquestContinueEnabled = true
    }
    guard conquestReportNode.apply(
        content: content,
        layout: reportLayout,
        isContinueEnabled: isConquestContinueEnabled
    ) == .presented else {
        isConquestReportFitFailed = true
        isConquestReportVisible = true
        return false
    }
    isConquestReportFitFailed = false
    isConquestReportVisible = true
    hasPresentedPendingConquestReport = true
    return true
}
```

- [ ] **Step 5: Restore statically on first `didMove` and reapply on layout**

After interface build and `redraw()` in `didMove(to:)`:

```swift
if state.pendingBattleResult != nil, !hasPresentedPendingConquestReport {
    _ = applyPendingConquestReport(resetsContinueState: true)
}
```

At the end of `layoutInterface()`:

```swift
if state.pendingBattleResult != nil, hasPresentedPendingConquestReport {
    _ = applyPendingConquestReport(resetsContinueState: false)
}
```

This reuses the current Continue state and does not run effects.

- [ ] **Step 6: Add DEBUG readbacks**

Expose report title/lines, Continue enabled/frame, report node counts, layout input, `hasPresentedPendingConquestReport`, and `isConquestReportFitFailed`. Keep old popup readback names only where existing tests need compatibility.

- [ ] **Step 7: Run and verify pass**

Expected: restored live, restored idle, country-complete inert, no-effect, no-duplicate, and mismatch tests green. Existing combat tests remain green.

- [ ] **Step 8: Commit**

```bash
git add Pyxis/BattleScene.swift PyxisTests/BattleSceneTests.swift
git commit -m "feat: restore conquest report from pending result"
```

---

### Task 7: Integrate Fresh Live/Idle Effects Without Replay

**Files:**
- Modify: `Pyxis/BattleScene.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`

**Interfaces:**
- Produces:
  ```swift
  @discardableResult
  private func presentPendingConquestReport(
      origin: ConquestReportPresentationOrigin,
      resetsContinueState: Bool
  ) -> Bool

  private func playGoldBurst(at anchor: CGPoint)
  ```

- [ ] **Step 1: Add failing fresh-origin tests**

Add scene tests that drive the real live and foreground-idle conquest paths:

```swift
@Test func liveConquestPresentsFreshReportAndEffectsOnce() throws {
    let store = try makeStore(initialState: stateWithBarracks(cityRemainingPower: 1))
    let scene = makeScene(store: store)

    scene.spawnSoldierForTesting()
    scene.advanceCombatForTesting(deltaTime: 3)

    #expect(scene.lastConquestReportOriginForTesting == "freshLive")
    #expect(scene.isGoldBurstVisibleForTesting)
    #expect(scene.isCityConquestFeedbackRunningForTesting)
    #expect(scene.goldBurstAnchorForTesting == scene.conquestReportGoldAnchorForTesting)

    let effectCount = scene.conquestEffectPresentationCountForTesting
    scene.redrawForTesting(shouldLayout: true)
    scene.refreshLayoutForCurrentEnvironment()
    #expect(scene.conquestEffectPresentationCountForTesting == effectCount)
}
```

Add an idle-foreground case using the existing lifecycle testing seam and a pending `.idle` result. Assert origin `.freshIdle`, gold burst once, no city flourish/floating damage, and `Conquered by your buildings`.

- [ ] **Step 2: Run and verify failure**

Expected: fresh paths still call removed `showConquestPopup` or do not expose origin/anchor behavior.

- [ ] **Step 3: Centralize origin-aware presentation**

Wrap `applyPendingConquestReport`:

```swift
@discardableResult
private func presentPendingConquestReport(
    origin: ConquestReportPresentationOrigin,
    resetsContinueState: Bool
) -> Bool {
    guard applyPendingConquestReport(resetsContinueState: resetsContinueState) else {
        return false
    }

    switch origin {
    case .freshLive:
        if let anchor = conquestReportNode.goldEffectAnchor(in: self) {
            playGoldBurst(at: anchor)
        }
    case .freshIdle:
        if let anchor = conquestReportNode.goldEffectAnchor(in: self) {
            playGoldBurst(at: anchor)
        }
    case .restored:
        break
    }
    return true
}
```

Record the last origin and an effect-presentation counter under `#if DEBUG` only.

- [ ] **Step 4: Replace live conquest call site**

In `applyCombatResult`, after model save and `redraw(shouldLayout: true)`:

```swift
if conqueredCity,
   presentPendingConquestReport(origin: .freshLive, resetsContinueState: true) {
    playFloatingFeedback(
        text: "-\(CompactNumberFormatter.string(from: damageResult.damageDealt))",
        at: enemyCityImpactPoint
    )
    playCityConquestFeedback()
}
```

Do not pass `damageResult.goldEarned` into report rendering. If report layout/application fails, do not run any conquest effects.

- [ ] **Step 5: Replace Battle Scene foreground idle call site**

After idle conquest saves and redraws:

```swift
if result.conqueredCities > 0 {
    _ = presentPendingConquestReport(origin: .freshIdle, resetsContinueState: true)
}
```

Do not play city flourish or floating damage on this path.

- [ ] **Step 6: Refactor gold burst anchor**

Change:

```swift
private func playGoldBurst(goldEarned _: Int)
```

to:

```swift
private func playGoldBurst(at anchor: CGPoint)
```

Set `burst.position = anchor`. Preserve the current sparkle/action/removal behavior unchanged.

- [ ] **Step 7: Run and verify pass**

Expected: live and foreground-idle fresh effects occur once; restored/reapply paths remain static; fit failure runs no effects.

- [ ] **Step 8: Commit**

```bash
git add Pyxis/BattleScene.swift PyxisTests/BattleSceneTests.swift
git commit -m "feat: gate conquest report effects by presentation origin"
```

---

### Task 8: Implement Continue Transaction and Modal Input Gating

**Files:**
- Modify: `Pyxis/BattleScene.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`

**Interfaces:**
- Produces one touch path:
  ```swift
  private func handleTouch(at point: CGPoint)
  private func continueFromConquestReport()
  ```

- [ ] **Step 1: Add failing transaction tests**

Add a router spy in `BattleSceneTests.swift`:

```swift
private final class BattleRouterSpy: BattleSceneRouting {
    var countryMapRequestCount = 0
    var buildingRequestCount = 0
    var onCountryMapRequest: ((BattleScene) -> Void)?

    func battleSceneDidRequestCountryMap(_ scene: BattleScene) {
        countryMapRequestCount += 1
        onCountryMapRequest?(scene)
    }

    func battleSceneDidRequestBuildingView(_ scene: BattleScene) {
        buildingRequestCount += 1
    }
}
```

Add:

```swift
@Test func continueDisablesAcknowledgesSavesThenRoutesOnce() throws {
    let result = pendingResult()
    let store = try makeStore(initialState: KingdomGameState(
        cityLevel: 3,
        cityRemainingPower: 0,
        cityNumberInCountry: 3,
        completedCityCount: 3,
        stageStatus: .cityConqueredPendingMap,
        pendingBattleResult: result
    ))
    let router = BattleRouterSpy()
    let scene = makeScene(store: store, router: router)
    router.onCountryMapRequest = { routedScene in
        #expect(!routedScene.isConquestContinueEnabledForTesting)
        #expect(routedScene.gameStateForTesting.pendingBattleResult == nil)
        #expect(store.load().pendingBattleResult == nil)
    }

    scene.tapConquestContinueForTesting()
    scene.tapConquestContinueForTesting()

    #expect(router.countryMapRequestCount == 1)
    #expect(store.load().pendingBattleResult == nil)
}

@Test func missingRouterLeavesPendingResultAndContinueEnabled() throws {
    let result = pendingResult()
    let store = try makeStore(initialState: KingdomGameState(
        cityLevel: 3,
        cityRemainingPower: 0,
        cityNumberInCountry: 3,
        completedCityCount: 3,
        stageStatus: .cityConqueredPendingMap,
        pendingBattleResult: result
    ))
    let scene = makeScene(store: store, router: nil)

    scene.tapConquestContinueForTesting()

    #expect(scene.isConquestContinueEnabledForTesting)
    #expect(store.load().pendingBattleResult == result)
}
```

Add tests that report-visible touches cannot spawn, open Building View/world, or show tooltips; fit-failed reports accept no touch; resize after disabling does not re-enable.

- [ ] **Step 2: Run and verify failure**

Expected: current close path routes without acknowledgment/save and underlying input remains reachable.

- [ ] **Step 3: Factor touch dispatch**

Change `touchesEnded` to:

```swift
override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let point = touches.first?.location(in: self) else { return }
    handleTouch(at: point)
}
```

Implement:

```swift
private func handleTouch(at point: CGPoint) {
    if isConquestReportVisible || isConquestReportFitFailed {
        guard !isConquestReportFitFailed,
              conquestReportNode.containsContinue(point) else {
            return
        }
        continueFromConquestReport()
        return
    }

    handleTouch(named: buttonName(at: point))
}
```

Remove `ButtonName.popupContinue` and its `handlePrimaryButton` case.

- [ ] **Step 4: Implement exact Continue transaction**

```swift
private func continueFromConquestReport() {
    guard isConquestReportVisible,
          isConquestContinueEnabled,
          !isConquestReportFitFailed,
          state.pendingBattleResult != nil,
          let router else {
        return
    }

    isConquestContinueEnabled = false
    _ = applyPendingConquestReport(resetsContinueState: false)
    state.acknowledgePendingBattleResult()
    store.save(state)
    router.battleSceneDidRequestCountryMap(self)
}
```

Do not hide the report before routing.

- [ ] **Step 5: Add test hooks without bypassing production logic**

Expose:

```swift
func tapConquestContinueForTesting() {
    guard let frame = conquestReportNode.continueHitFrameForTesting else { return }
    handleTouch(at: CGPoint(x: frame.midX, y: frame.midY))
}

func handleTouchForTesting(at point: CGPoint) {
    handleTouch(at: point)
}
```

- [ ] **Step 6: Run and verify pass**

Expected: ordering callback assertions pass, duplicate tap routes once, missing router preserves state, modal gating blocks all underlying interactions.

- [ ] **Step 7: Commit**

```bash
git add Pyxis/BattleScene.swift PyxisTests/BattleSceneTests.swift
git commit -m "feat: acknowledge conquest report before routing"
```

---

### Task 9: Add Pending-First Controller Routing and Fit-Gate Recovery

**Files:**
- Modify: `Pyxis/GameViewController.swift`
- Modify: `PyxisTests/GameViewControllerTests.swift`
- Modify: `PyxisTests/BuildingViewSceneTests.swift`

**Interfaces:**
- `GameViewController.presentSceneForCurrentStage(in:)` gives non-nil `pendingBattleResult` precedence.
- `GameViewController.refreshLayoutSupport` maps `BattleScene.isConquestReportFitFailed` to `.unsupportedGeometry`.
- `BuildingViewScene` production code remains unchanged.

- [ ] **Step 1: Add failing controller routing tests**

Add a local `pendingResult(city:mode:)` helper to `GameViewControllerTests.swift`, then:

```swift
@Test func pendingResultTakesPrecedenceOverConqueredStageAtLaunch() throws {
    for stage in [
        KingdomGameState.StageStatus.cityConqueredPendingMap,
        .countryComplete
    ] {
        let city = stage == .countryComplete ? 15 : 3
        let store = try makeStore(initialState: KingdomGameState(
            cityLevel: city,
            cityRemainingPower: 0,
            cityNumberInCountry: city,
            completedCityCount: city,
            stageStatus: stage,
            pendingBattleResult: pendingResult(city: city)
        ))
        let controller = GameViewController(store: store)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        controller.view = view

        controller.viewDidLoad()

        #expect(view.scene is BattleScene)
    }
}

@Test func buildingViewBattleRequestUsesPendingFirstRouting() throws {
    let store = try makeStore(initialState: KingdomGameState(
        cityLevel: 3,
        cityRemainingPower: 0,
        cityNumberInCountry: 3,
        completedCityCount: 3,
        stageStatus: .cityConqueredPendingMap,
        pendingBattleResult: pendingResult(city: 3, mode: .idle)
    ))
    let controller = GameViewController(store: store)
    let view = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
    controller.view = view
    let building = BuildingViewScene(size: view.bounds.size, store: store, router: controller)

    controller.buildingViewSceneDidRequestBattle(building)

    let battle = try #require(view.scene as? BattleScene)
    #expect(battle.conquestReportLinesForTesting[1] == "Conquered by your buildings")
    #expect(!battle.isGoldBurstVisibleForTesting)
}
```

Add a conquered-without-pending test that still opens Country Map.

- [ ] **Step 2: Add failing fit-gate tests**

```swift
@Test func battleReportFitFailureUsesUnsupportedGeometryGateAndRecovers() throws {
    let store = try makeStore(initialState: .init(stageStatus: .battleActive))
    let controller = GameViewController(store: store)
    let view = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
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

Add a Battle Scene test/readback proving an `SKView` with 50-point left/right safe insets is converted into `ConquestReportSafeAreaInsets(left: 50, right: 50)`.

- [ ] **Step 3: Add Building View handoff regression tests**

In `BuildingViewSceneTests.swift`, cover the existing behavior without production changes:

- Settlement conquest leaves the current scene in place, saves `.idle` pending result, and displays conquest feedback.
- Foreground idle conquest does the same.
- `requestBattleForTesting()` calls the router once and does not clear pending result.
- Catch-up performed inside `requestBattle()` can finalize conquest and hands the new pending result to the router.

Use the scene’s existing testing seams; add only DEBUG hooks if a production path is currently inaccessible.

- [ ] **Step 4: Run and verify failure**

Expected: controller still routes conquered stages directly to Country Map and has no Battle fit-failure branch.

- [ ] **Step 5: Implement pending-first routing**

Update `presentSceneForCurrentStage(in:)`:

```swift
private func presentSceneForCurrentStage(in view: SKView) {
    let state = store.load()

    if state.pendingBattleResult != nil {
        presentBattleScene(in: view)
        return
    }

    switch state.stageStatus {
    case .battleActive:
        presentBattleScene(in: view)
    case .cityConqueredPendingMap, .countryComplete:
        presentCountryMapScene(in: view)
    }
}
```

- [ ] **Step 6: Integrate Battle report fit failure into the existing gate**

In `refreshLayoutSupport`, before map-specific fit handling:

```swift
if let battleScene = skView.scene as? BattleScene,
   battleScene.isConquestReportFitFailed {
    reason = .unsupportedGeometry
} else if requestedMapGateReason == .mapUnavailable {
    reason = .mapUnavailable
} else {
    // existing CountryMapLayout result mapping
}
```

Keep the existing map-unavailable and Scout Card behavior unchanged.

- [ ] **Step 7: Run and verify pass**

Expected: cold launch, Building View handoff, country-complete pending, no-pending map, safe-inset, and fit-gate recovery tests green.

- [ ] **Step 8: Commit**

```bash
git add \
  Pyxis/GameViewController.swift \
  PyxisTests/GameViewControllerTests.swift \
  PyxisTests/BuildingViewSceneTests.swift
git commit -m "feat: route pending conquest reports through battle scene"
```

---

### Task 10: Close Acceptance Coverage, Update Architecture Docs, and Verify

**Files:**
- Modify: `PyxisTests/BattleSceneTests.swift`
- Modify: `PyxisTests/GameViewControllerTests.swift`
- Modify: `PyxisTests/BuildingViewSceneTests.swift`
- Modify: `CLAUDE.md`

**Interfaces:**
- No new production interfaces. This task closes cross-component acceptance gaps and verifies the complete branch.

- [ ] **Step 1: Add the pre-release pending-save acceptance case**

In `GameViewControllerTests.swift`, construct a compatible conquered state containing `pendingBattleResult` without any new migration/version marker. Launch, verify Battle report appears, tap Continue through the scene testing seam, recreate the controller, and verify the second launch presents Country Map because the pending value was acknowledged and saved.

- [ ] **Step 2: Add first-versus-repeated presentation acceptance coverage**

In `BattleSceneTests.swift`:

```swift
@Test func repeatedDidMoveResizeAndRedrawDoNotReplayOrReenable() throws {
    let store = try makeStore(initialState: pendingConqueredState())
    let router = BattleRouterSpy()
    let scene = makeScene(store: store, router: router)

    scene.tapConquestContinueForTesting()
    let effects = scene.conquestEffectPresentationCountForTesting
    scene.didMove(to: try #require(scene.view))
    scene.didChangeSize(scene.size)
    scene.refreshLayoutForCurrentEnvironment()
    scene.redrawForTesting(shouldLayout: true)

    #expect(!scene.isConquestContinueEnabledForTesting)
    #expect(scene.conquestEffectPresentationCountForTesting == effects)
    #expect(scene.conquestReportControlCountForTesting == 1)
}
```

Add explicit cases for zero deployment/loss, missing MVP, only one achievement, three-row compact layout, and country-complete final route.

- [ ] **Step 3: Update `CLAUDE.md` architecture facts**

Update the Battle Scene and controller paragraphs so they state:

- `BattleScene` renders a `ConquestReportNode` from persisted `pendingBattleResult`, distinguishes fresh/restored effects, and acknowledges/saves before routing.
- `ConquestReportLayout` is pure CoreGraphics and safe-area-aware.
- `GameViewController` gives pending reports precedence over stage routing and maps report fit failure to the app-wide layout gate.
- Building View conquest remains on Building View until explicit Battle routing.

Do not edit `AGENTS.md`; it is a symlink.

- [ ] **Step 4: Run all focused suites**

Run:

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

Expected: zero failures and zero skipped tests.

- [ ] **Step 5: Run lint and build**

```bash
swiftlint lint

xcodebuild build \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Expected: SwiftLint exits 0 and build exits 0.

- [ ] **Step 6: Run the complete unit and UI suite**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO
```

Expected: all `PyxisTests` and `PyxisUITests` pass.

- [ ] **Step 7: Perform the manual smoke matrix**

Verify on simulator/device:

1. Live conquest shows four/three rows as applicable, city flourish/floating damage/gold burst once, and one Continue.
2. Foreground building conquest in Battle Scene shows `Conquered by your buildings` and only the approved gold feedback once.
3. Build/upgrade settlement conquest stays in Building View; tapping Battle shows a static report with no effects.
4. Building View foreground idle conquest behaves the same.
5. Relaunch before Continue restores identical static values.
6. Relaunch after Continue opens Country Map without redisplaying the report.
7. A compatible pre-release pending save displays once.
8. Small phone, side-inset iPad, and synthetic compact component layouts keep Continue visible.
9. City 15 presents an inert country-complete report, then routes to final Country Map.

- [ ] **Step 8: Commit verification/docs changes**

```bash
git add \
  CLAUDE.md \
  PyxisTests/BattleSceneTests.swift \
  PyxisTests/BuildingViewSceneTests.swift \
  PyxisTests/GameViewControllerTests.swift
git commit -m "test: close compact conquest report acceptance coverage"
```

- [ ] **Step 9: Final branch review**

Run:

```bash
git status --short
git diff --check main...HEAD
git log --oneline main..HEAD
```

Expected: clean worktree, no whitespace errors, and task-scoped commits only.
