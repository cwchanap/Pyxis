# Unlocked-City Scout Card Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the always-visible HPA-387 Scout Card to the country map so the one unlocked city exposes its defense matchup, exposed lane, reward, and guarded Attack action without changing campaign rules or the HPA-117 outer layout.

**Architecture:** Project the card from normalized `KingdomGameState` into a framework-free content value, subdivide the existing information region with pure CoreGraphics layout and text-fit helpers, render it in one focused SpriteKit node, and keep timing, persistence, input priority, and routing in `CountryMapScene`. Entry through the city node, current-city control, and Attack action converges on one guarded method whose router returns whether presentation was accepted.

**Tech Stack:** Swift 5, Swift Testing, XCTest UI infrastructure, SpriteKit, UIKit font measurement, CoreGraphics, XcodeBuildMCP, and `xcodebuild` fallback.

## Global Constraints

- The approved design is
  `docs/superpowers/specs/2026-07-27-unlocked-city-scout-card-design.md`.
  Treat its copy, layout constants, timings, failure behavior, and input order
  as acceptance contracts.
- Start each task with the failing test specified below. Do not add production
  behavior before seeing the relevant failure.
- Keep rules and geometry pure. Only `CountryMapScoutCardNode` may import
  SpriteKit/UIKit for card presentation and production-font measurement.
- Do not change `CountryMapLayout`, its authored city anchors, map interaction
  frames, or supported portrait fixtures.
- Do not add persisted state, new assets, a new scene, catalog fields, city
  names, branching, or chronicle behavior.
- Do not edit `Pyxis.xcodeproj/project.pbxproj`; synchronized root groups pick
  up new Swift files automatically.
- Preserve unrelated work. Check `git status --short` before every commit and
  stage only the files named by the task.
- Prefix shell commands with `rtk`.
- Prefer XcodeBuildMCP. Before the first build or test in an execution session:
  call `session_show_defaults`; if needed, set
  `/Users/chanwaichan/workspace/Pyxis/Pyxis.xcodeproj`, scheme `Pyxis`, and an
  available iPhone simulator. Every `test_sim` call must include
  `extraArgs: ["-parallel-testing-enabled", "NO"]`.
- Direct fallback commands must include `-parallel-testing-enabled NO`. If
  `iPhone 17` is unavailable, run the documented `-showdestinations` command
  and substitute one available simulator consistently.
- After each green task, inspect the diff, run the focused tests again, and
  make the listed small commit.

## File Map

### Create

- `Pyxis/CountryMapScoutCardContent.swift` — total projection of normalized
  campaign state into Scout or country-complete content.
- `Pyxis/CountryMapScoutCardLayout.swift` — pure scene-coordinate subdivision
  of the existing information region.
- `Pyxis/CountryMapScoutCardTextLayout.swift` — pure two-line wrapping,
  whole-point font fitting, and footer width arithmetic.
- `Pyxis/CountryMapScoutCardNode.swift` — SpriteKit rendering, asset fallback,
  fit validation, enabled styling, and local overlay presentation.
- `Pyxis/CountryMapTransientFeedback.swift` — typed feedback copy, duration,
  fade, and advancement.
- `PyxisTests/CountryMapLayoutTestFixtures.swift` — shared supported HPA-117
  layout fixtures.
- `PyxisTests/CountryMapScoutCardContentTests.swift`
- `PyxisTests/CountryMapScoutCardLayoutTests.swift`
- `PyxisTests/CountryMapScoutCardTextLayoutTests.swift`
- `PyxisTests/CountryMapScoutCardNodeTests.swift`
- `PyxisTests/CountryMapTransientFeedbackTests.swift`

### Modify

- `Pyxis/KingdomGameState.swift` — canonical unlocked-city projection and
  arbitrary-city display-title helper.
- `Pyxis/BattleLane.swift` — model-owned display names.
- `Pyxis/CountryMapScene.swift` — card orchestration, timed overlay, unified
  input path, failure gate, and duplicate-route protection.
- `Pyxis/GameViewController.swift` — return router acceptance.
- `PyxisTests/CountryMapLayoutTests.swift` — consume the shared supported
  fixtures.
- `PyxisTests/CountryMapSceneTests.swift` — presentation, input, timing,
  relayout, route rejection, and failure behavior.
- `PyxisTests/GameViewControllerTests.swift` — accepted/rejected map routing.

---

## Task 1: Project the One Unlocked City from Existing Model Semantics

**Files:**

- Create: `Pyxis/CountryMapScoutCardContent.swift`
- Create: `PyxisTests/CountryMapScoutCardContentTests.swift`
- Modify: `Pyxis/KingdomGameState.swift`
- Modify: `Pyxis/BattleLane.swift`

### 1.1 Write the failing projection tests

- [ ] Add a Swift Testing suite covering:

  - fresh `.battleActive` state projects city 1;
  - `.cityConqueredPendingMap` with one completed city projects city 2 even
    when `cityNumberInCountry` and `cityLevel` still describe city 1;
  - the projected definition supplies the catalog trait and exposed lane;
  - the reward is
    `KingdomGameState.goldReward(for: unlockedCityNumber)`;
  - each possible unlocked city 1...15 projects its exact title, catalog
    trait, trait-derived matchup arrays, exposed lane, and formula reward;
  - every incomplete normalized Country 1 state has exactly one
    `unlockedMapCityNumber` and exposes no later definition;
  - the pending-map city 2 reward differs from
    `goldReward(for: state.cityLevel)` when that stale level is still 1;
  - `.countryComplete` projects only
    `.countryComplete(countryNumber: state.countryNumber)`;
  - display titles continue to use `Country N - City N`; and
  - battle-lane names are exactly `Left`, `Center`, and `Right`.

Use direct value assertions, including the pending-map stale-field case:

```swift
@Test
func pendingMapProjectsTheNextUnlockedCityInsteadOfTheStaleBattleCity() {
    let state = KingdomGameState(
        gold: 15,
        cityLevel: 1,
        cityRemainingPower: 0,
        countryNumber: 1,
        cityNumberInCountry: 1,
        completedCityCount: 1,
        stageStatus: .cityConqueredPendingMap
    )

    let content = CountryMapScoutCardContent.project(from: state)
    let definition = Country1CityCatalog.definition(for: 2)

    #expect(
        content == .scout(
            .init(
                cityNumber: 2,
                displayTitle: "Country 1 - City 2",
                defenseTrait: definition.defenseTrait,
                exposedLane: definition.laneDefenseProfile.exposedLane,
                goldReward: KingdomGameState.goldReward(for: 2)
            )
        )
    )
}
```

### 1.2 Run the focused tests and confirm RED

- [ ] Preferred: run
  `test_sim` for `PyxisTests/CountryMapScoutCardContentTests` with parallel
  testing disabled.
- [ ] Fallback:

```bash
rtk xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/CountryMapScoutCardContentTests
```

- [ ] Confirm the failure is missing production types/members, not a fixture or
  simulator failure.

### 1.3 Add the canonical model helpers

- [ ] In `KingdomGameState`, add the only unlocked-city convenience projection.
  Resolve it through the existing `mapStatus(for:)` API:

```swift
var unlockedMapCityNumber: Int? {
    Country1CityCatalog.cityRange.first {
        mapStatus(for: $0) == .unlocked
    }
}

func displayCityTitle(for cityNumber: Int) -> String {
    "Country \(countryNumber) - City \(cityNumber)"
}

var displayCityTitle: String {
    displayCityTitle(for: cityNumberInCountry)
}
```

- [ ] Do not duplicate the `completedCityCount + 1` formula outside
  `mapStatus(for:)`.
- [ ] Add framework-free `BattleLane.displayName`:

```swift
var displayName: String {
    switch self {
    case .left: return "Left"
    case .center: return "Center"
    case .right: return "Right"
    }
}
```

### 1.4 Implement the total content projection

- [ ] Add the exact value shape approved by the spec:

```swift
enum CountryMapScoutCardContent: Equatable {
    struct Scout: Equatable {
        let cityNumber: Int
        let displayTitle: String
        let defenseTrait: CityDefenseTrait
        let exposedLane: BattleLane
        let goldReward: Int
    }

    case scout(Scout)
    case countryComplete(countryNumber: Int)

    static func project(from state: KingdomGameState) -> Self {
        guard state.stageStatus != .countryComplete else {
            return .countryComplete(countryNumber: state.countryNumber)
        }

        guard let cityNumber = state.unlockedMapCityNumber else {
            assertionFailure("An incomplete normalized map must have one unlocked city")
            return .countryComplete(countryNumber: state.countryNumber)
        }

        let definition = Country1CityCatalog.definition(for: cityNumber)
        return .scout(
            Scout(
                cityNumber: cityNumber,
                displayTitle: state.displayCityTitle(for: cityNumber),
                defenseTrait: definition.defenseTrait,
                exposedLane: definition.laneDefenseProfile.exposedLane,
                goldReward: KingdomGameState.goldReward(for: cityNumber)
            )
        )
    }
}
```

- [ ] Keep derived favorable/disadvantaged arrays on
  `Scout.defenseTrait`; do not copy them into the projection.

### 1.5 Run GREEN, inspect, and commit

- [ ] Run the focused content suite.
- [ ] Run the existing model/catalog regression suites:

```bash
rtk xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/KingdomGameStateTests \
  -only-testing:PyxisTests/Country1CityCatalogTests \
  -only-testing:PyxisTests/LaneDefenseProfileTests \
  -only-testing:PyxisTests/CountryMapScoutCardContentTests
```

- [ ] Review the diff for new persistence keys or duplicated unlock formulas;
  there must be none.
- [ ] Commit:

```bash
rtk git add \
  Pyxis/KingdomGameState.swift \
  Pyxis/BattleLane.swift \
  Pyxis/CountryMapScoutCardContent.swift \
  PyxisTests/CountryMapScoutCardContentTests.swift
rtk git commit -m "feat: project unlocked city scout content"
```

---

## Task 2: Lock the Inner Card Geometry Across Every Supported Layout

**Files:**

- Create: `Pyxis/CountryMapScoutCardLayout.swift`
- Create: `PyxisTests/CountryMapLayoutTestFixtures.swift`
- Create: `PyxisTests/CountryMapScoutCardLayoutTests.swift`
- Modify: `PyxisTests/CountryMapLayoutTests.swift`

### 2.1 Extract the shared HPA-117 fixtures

- [ ] Move only the ten supported fixture values out of
  `CountryMapLayoutTests.swift` into test support:

```swift
struct CountryMapLayoutTestFixture: Sendable {
    let name: String
    let size: CGSize
    let insets: CountryMapSafeAreaInsets
    let layoutClass: CountryMapLayoutClass
}

enum CountryMapLayoutTestFixtures {
    static let supported: [CountryMapLayoutTestFixture] = [
        .init(name: "small phone", size: .init(width: 375, height: 667),
              insets: .zero, layoutClass: .phone),
        .init(name: "iPhone 12/13 mini", size: .init(width: 375, height: 812),
              insets: .init(top: 50, left: 0, bottom: 34, right: 0), layoutClass: .phone),
        .init(name: "modern phone", size: .init(width: 393, height: 852),
              insets: .init(top: 59, left: 0, bottom: 34, right: 0), layoutClass: .phone),
        .init(name: "large phone", size: .init(width: 440, height: 956),
              insets: .init(top: 62, left: 0, bottom: 34, right: 0), layoutClass: .phone),
        .init(name: "iPad mini", size: .init(width: 744, height: 1133),
              insets: .init(top: 24, left: 0, bottom: 20, right: 0), layoutClass: .pad),
        .init(name: "11-inch iPad", size: .init(width: 834, height: 1194),
              insets: .init(top: 24, left: 0, bottom: 20, right: 0), layoutClass: .pad),
        .init(name: "13-inch iPad", size: .init(width: 1032, height: 1376),
              insets: .init(top: 24, left: 0, bottom: 20, right: 0), layoutClass: .pad),
        .init(name: "Stage Manager", size: .init(width: 600, height: 1008),
              insets: .init(top: 28, left: 0, bottom: 20, right: 0), layoutClass: .pad),
        .init(name: "narrow iPad", size: .init(width: 480, height: 1194),
              insets: .init(top: 24, left: 0, bottom: 20, right: 0), layoutClass: .pad),
        .init(name: "iPad with side insets", size: .init(width: 834, height: 1194),
              insets: .init(top: 24, left: 50, bottom: 20, right: 50), layoutClass: .pad)
    ]
}
```

- [ ] Update existing layout test argument providers to use
  `CountryMapLayoutTestFixtures.supported`. Preserve unsupported-layout tests
  in their current file.

### 2.2 Write the failing geometry tests

- [ ] For every shared fixture, compute the authoritative outer layout first,
  then the Scout layout from `informationRegionFrame`.
- [ ] Assert:

  - `cardFrame` and `overlayFrame` equal the complete information region;
  - all returned frames are contained in the information region;
  - Attack is at least 44×44;
  - informational frames never intersect Attack;
  - phone rows are exactly 22, 24, and 12 points with 1-point gaps;
  - phone favorable/disadvantaged frames are exactly 106/70 with 6-point
    group gaps;
  - iPad rows are exactly 32, 28, and 28 points with 4-point gaps;
  - iPad favorable occupies footer line 1;
  - iPad disadvantage occupies footer line 2 up to a 12-point gap;
  - iPad exposed lane is the trailing 82 points of footer line 2;
  - title boundaries use the same badge/title and title/reward gaps, without
    an accidental second inset; and
  - geometry is content-independent.

Use the minimum fixtures as explicit arithmetic locks:

```swift
#expect(phoneLayout.favorableFrame.width == 106)
#expect(phoneLayout.disadvantagedFrame.width == 70)
#expect(phoneLayout.exposedLaneFrame.width == 67)
#expect(phoneLayout.attackFrame.size == CGSize(width: 70, height: 44))

#expect(narrowPadLayout.exposedLaneFrame.width == 82)
#expect(narrowPadLayout.attackFrame.size == CGSize(width: 96, height: 52))
#expect(
    narrowPadLayout.exposedLaneFrame.minX
        - narrowPadLayout.disadvantagedFrame.maxX == 12
)
```

### 2.3 Run the focused tests and confirm RED

- [ ] Run `PyxisTests/CountryMapScoutCardLayoutTests` and confirm the missing
  type failure.

### 2.4 Implement the pure CoreGraphics layout

- [ ] Define explicit scene-coordinate frames:

```swift
struct CountryMapScoutCardLayout: Equatable {
    let layoutClass: CountryMapLayoutClass
    let cardFrame: CGRect
    let badgeFrame: CGRect
    let titleFrame: CGRect
    let goldIconFrame: CGRect
    let rewardFrame: CGRect
    let traitLineFrames: [CGRect]
    let favorableFrame: CGRect
    let disadvantagedFrame: CGRect
    let exposedLaneFrame: CGRect
    let attackFrame: CGRect
    let overlayFrame: CGRect

    static func compute(
        in informationRegionFrame: CGRect,
        layoutClass: CountryMapLayoutClass
    ) -> Self {
        switch layoutClass {
        case .phone:
            return phone(in: informationRegionFrame)
        case .pad:
            return pad(in: informationRegionFrame)
        }
    }
}
```

- [ ] Phone arithmetic:

  - inset the card by `dx: 6, dy: 2`;
  - place 70×44 Attack trailing and vertically centered;
  - informational max X is `attackFrame.minX - 6`;
  - header/trait/footer Y coordinates consume exactly 22/1/24/1/12;
  - badge is 22×22;
  - reward group is 12 + 2 + 34;
  - title begins badge.maxX + 4 and ends gold.minX - 4;
  - footer is `106 + 6 + 70 + 6 + remainder`.

- [ ] iPad arithmetic:

  - inset by `dx: 12, dy: 8`;
  - place 96×52 Attack trailing and vertically centered;
  - informational max X is `attackFrame.minX - 12`;
  - header/trait/footer consume exactly 32/4/28/4/28;
  - badge is 32×32;
  - reward group is 18 + 4 + 48;
  - title begins badge.maxX + 8 and ends gold.minX - 8;
  - favorable is footer line 1;
  - exposed lane is the trailing 82 points of footer line 2; and
  - disadvantage fills footer line 2 through
    `exposedLaneFrame.minX - 12`.

- [ ] Precondition the expected information-region height for the selected
  class. Do not silently rescale rows.

### 2.5 Run GREEN, inspect, and commit

- [ ] Run `CountryMapScoutCardLayoutTests` and the full existing
  `CountryMapLayoutTests`.
- [ ] Confirm the fixture extraction did not change a single fixture value.
- [ ] Commit:

```bash
rtk git add \
  Pyxis/CountryMapScoutCardLayout.swift \
  PyxisTests/CountryMapLayoutTestFixtures.swift \
  PyxisTests/CountryMapScoutCardLayoutTests.swift \
  PyxisTests/CountryMapLayoutTests.swift
rtk git commit -m "feat: define scout card layout"
```

---

## Task 3: Prove Every Required String Fits Without Clipping

**Files:**

- Create: `Pyxis/CountryMapScoutCardTextLayout.swift`
- Create: `PyxisTests/CountryMapScoutCardTextLayoutTests.swift`

### 3.1 Write failing pure text-layout tests

- [ ] Cover the greedy two-line wrapper:

  - one line when all words fit;
  - two lines at the last fitting word;
  - `nil` when a single word is wider than the slot;
  - `nil` when a third line is required;
  - no character-level splitting; and
  - empty/whitespace-only text is rejected.

- [ ] Cover whole-point fitting:

  - returns the starting size when it fits;
  - decrements only by whole points;
  - returns 8 when that is the first fit; and
  - returns `nil` when 8 still fails.

- [ ] Cover width arithmetic for a footer group, including:

  - prefix width;
  - prefix/first-item gap;
  - icon width;
  - icon/label gap;
  - intrinsic or fixed label width;
  - inter-item gaps; and
  - the icon-free `None` case.

- [ ] Use UIKit only in the test target to supply production-font measurement
  closures. Against the computed layouts for all shared fixtures, assert:

  - all seven exact
    `displayName · shortDescription` strings return one or two complete lines;
  - joining wrapped words reproduces the source string exactly;
  - every line fits at phone 9-point or pad 12-point medium;
  - Burning Oil's three favorable and two disadvantaged entries fit;
  - all matchup groups for all seven traits fit;
  - `Open: Left`, `Open: Center`, and `Open: Right` fit;
  - every city 1...15 title fits at its nominal title size;
  - every city 1...15 numeric reward and `Gold <reward>` fallback fits; and
  - synthetic footer, title, and reward overflow returns failure.

Use the actual label font and `NSString` metrics:

```swift
func width(_ text: String, fontName: String, size: CGFloat) throws -> CGFloat {
    let font = try #require(UIFont(name: fontName, size: size))
    return ceil((text as NSString).size(withAttributes: [.font: font]).width)
}
```

### 3.2 Run the focused tests and confirm RED

- [ ] Run `PyxisTests/CountryMapScoutCardTextLayoutTests`.

### 3.3 Implement the framework-free helper

- [ ] Use injected measurement closures so the file imports CoreGraphics, not
  UIKit or SpriteKit:

```swift
enum CountryMapScoutCardTextLayout {
    struct FooterItem: Equatable {
        let label: String
        let showsIcon: Bool
    }

    static func wrapIntoTwoLines(
        _ text: String,
        maximumWidth: CGFloat,
        measure: (String) -> CGFloat
    ) -> [String]? {
        let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return nil }
        guard words.allSatisfy({ measure($0) <= maximumWidth }) else { return nil }

        var lines = [String]()
        var current = ""
        for word in words {
            let candidate = current.isEmpty ? word : "\(current) \(word)"
            if measure(candidate) <= maximumWidth {
                current = candidate
            } else {
                lines.append(current)
                current = word
            }
        }
        lines.append(current)
        return lines.count <= 2 ? lines : nil
    }

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

- [ ] Add `footerGroupRequiredWidth` with explicit parameters for prefix,
  items, icon width, prefix gap, icon/label gap, item gap, and label width.
  Treat `FooterItem(label: "None", showsIcon: false)` as a normal item with no
  icon or icon-label gap.

### 3.4 Run GREEN, inspect, and commit

- [ ] Run the pure text-layout suite.
- [ ] Verify the helper contains no production-font names or UIKit imports.
- [ ] Commit:

```bash
rtk git add \
  Pyxis/CountryMapScoutCardTextLayout.swift \
  PyxisTests/CountryMapScoutCardTextLayoutTests.swift
rtk git commit -m "feat: validate scout card text layout"
```

---

## Task 4: Render and Validate the Focused SpriteKit Card Node

**Files:**

- Create: `Pyxis/CountryMapScoutCardNode.swift`
- Create: `PyxisTests/CountryMapScoutCardNodeTests.swift`

### 4.1 Write failing presentation tests

- [ ] Instantiate the node directly with deterministic image loaders and
  computed phone/pad layouts. Cover:

  - Scout content renders badge, title, exact trait copy, favorable soldiers,
    disadvantaged soldiers, lane, reward, and Attack;
  - country-complete content renders exact
    `Country N conquered.` and no Attack hit frame;
  - phone uses `Inf`, `Arc`, `Cav`, `Mag`, `Sie`;
  - iPad uses full `SoldierType.displayName`;
  - empty matchup arrays render `+ None` and `- None`;
  - a `gold-burst` image uses the separate gold and reward frames;
  - a missing `gold-burst` renders literal `Gold <reward>` in the union frame;
  - soldier frames use `<rawValue>-walk-01`;
  - each soldier texture rect equals
    `SoldierAnimationGeometry(type: type).bodyRegion`;
  - soldier bodies aspect-fit their target frame;
  - disabled entry preserves the card-consumption frame, removes only the
    Attack hit frame, and dims Attack;
  - `applyFeedback(text:alpha:)` places the transient overlay above unchanged
    base content, removes the Attack hit frame while visible, and restores it
    when cleared;
  - invalid trait wrap, title fit, footer fit, and reward fit each return
    `.requiredContentDoesNotFit`; and
  - every current trait/title/reward/lane combination presents on every shared
    supported fixture with production font metrics.

Use an image loader spy keyed by the exact requested names. For geometry,
expose DEBUG-only readbacks rather than traversing anonymous child arrays.

### 4.2 Run the focused tests and confirm RED

- [ ] Run `PyxisTests/CountryMapScoutCardNodeTests`.

### 4.3 Build the node with one explicit presentation API

- [ ] Use a result that forces the scene to handle required-copy failures:

```swift
final class CountryMapScoutCardNode: SKNode {
    enum ApplyResult: Equatable {
        case presented
        case requiredContentDoesNotFit
    }

    typealias ImageLoader = (String) -> UIImage?

    init(imageLoader: @escaping ImageLoader = { UIImage(named: $0) }) {
        self.imageLoader = imageLoader
        super.init()
        buildNodeTree()
    }

    func apply(
        content: CountryMapScoutCardContent,
        layout: CountryMapScoutCardLayout,
        isEntryEnabled: Bool
    ) -> ApplyResult

    func applyFeedback(text: String?, alpha: CGFloat)
    func clearLayout()

    private(set) var cardHitFrame: CGRect?
    private(set) var attackHitFrame: CGRect?
    private(set) var overlayHitFrame: CGRect?
}
```

- [ ] Own a `PanelNode`, city badge, title, reward nodes, two trait labels,
  footer containers, Attack panel/label, and feedback panel/label. Keep local
  z positions at base 0, content 1, overlay 2; place the node itself at
  `GameUITheme.Z.hud`.
- [ ] `cardHitFrame` equals the card frame after every successful Scout or
  country-complete presentation. `attackHitFrame` exists only for enabled
  Scout content with no visible overlay. `overlayHitFrame` exists only while
  feedback text is visible. `clearLayout()` clears all three.
- [ ] Use `GameUITheme.Font.bold` and `.medium` at the approved sizes:

  - phone: title/badge 11, reward 10, trait/footer 9, Attack 13;
  - pad: title/badge 16, reward 14, trait 12, footer 11, Attack 16.

- [ ] Measure with the same production fonts used by the labels. Feed the
  measurements into `CountryMapScoutCardTextLayout`.
- [ ] Trait copy must be exactly:

```swift
let traitText =
    "\(scout.defenseTrait.displayName) · \(scout.defenseTrait.shortDescription)"
```

- [ ] Render at most two returned strings in two independent, vertically
  centered, single-line `SKLabelNode`s. Clear the unused second line.
- [ ] Validate all required widths before mutating visible content. On
  failure, clear hit frames and return `.requiredContentDoesNotFit`; never
  leave a partial new card on screen.

### 4.4 Implement exact icon and fallback behavior

- [ ] Phone labels use this fixed mapping:

```swift
private func compactName(for type: SoldierType) -> String {
    switch type {
    case .infantry: return "Inf"
    case .archer: return "Arc"
    case .cavalry: return "Cav"
    case .mage: return "Mag"
    case .siege: return "Sie"
    }
}
```

- [ ] Load and crop the installed walk frame:

```swift
let frameName = "\(type.rawValue)-walk-01"
if let image = imageLoader(frameName) {
    let source = SKTexture(image: image)
    let body = SKTexture(
        rect: SoldierAnimationGeometry(type: type).bodyRegion,
        in: source
    )
    icon.texture = body
    icon.size = aspectFit(body.size(), in: targetFrame.size)
}
```

- [ ] Do not fall back to an uncropped 128×128 soldier canvas. If a soldier
  image is missing, render its required text label without an icon and
  recompute width through the same pure helper.
- [ ] If `gold-burst` is present, use its normal 12×12 or 18×18 frame with a
  separate right-aligned numeric reward. If absent, hide the icon and render
  exact `Gold <reward>` at phone 9 or pad 13 bold in the union of the normal
  gold/reward frames.
- [ ] Preserve aspect ratio for every texture.

### 4.5 Run GREEN, inspect, and commit

- [ ] Run the node, layout, and text-layout suites together.
- [ ] Confirm the matrix includes all seven traits, all three lane names, all
  rewards for city levels 1...15, both image-loader outcomes, and all ten
  supported fixtures.
- [ ] Commit:

```bash
rtk git add \
  Pyxis/CountryMapScoutCardNode.swift \
  PyxisTests/CountryMapScoutCardNodeTests.swift
rtk git commit -m "feat: render unlocked city scout card"
```

---

## Task 5: Replace String Feedback with a Typed Exact-Duration Overlay

**Files:**

- Create: `Pyxis/CountryMapTransientFeedback.swift`
- Create: `PyxisTests/CountryMapTransientFeedbackTests.swift`
- Modify: `Pyxis/CountryMapScene.swift`
- Modify: `PyxisTests/CountryMapSceneTests.swift`

### 5.1 Write failing timer/copy tests

- [ ] In the pure feedback suite, assert:

  - locked copy is exactly `City N is locked`;
  - completed copy is exactly `City N complete`;
  - both use total duration 1.5 seconds;
  - idle/status and recoverable errors use 2.5 seconds;
  - alpha stays 1 before the last 0.3 seconds;
  - alpha decreases linearly through the final 0.3 seconds;
  - the message becomes finished exactly at total duration;
  - negative delta does not rewind; and
  - a large delta clamps at finished.

- [ ] Add scene tests that assert:

  - card base content is identical before, during, and after an overlay;
  - a first tap inside the overlay is consumed and does not change elapsed
    time;
  - taps cannot dismiss locked/completed feedback early;
  - overlay disappears at exactly 1.5 seconds;
  - idle feedback preserves the existing wording;
  - country-complete base content remains visible after feedback expires; and
  - `didChangeSize` preserves active feedback text and remaining duration.

### 5.2 Run focused tests and confirm RED

- [ ] Run `CountryMapTransientFeedbackTests` plus the selected new
  `CountryMapSceneTests`.

### 5.3 Implement the pure feedback value

- [ ] Use typed construction rather than arbitrary strings:

```swift
struct CountryMapTransientFeedback: Equatable {
    enum Kind: Equatable {
        case locked
        case completed
        case status
        case recoverableError
    }

    let kind: Kind
    let text: String
    let totalDuration: TimeInterval
    let fadeDuration: TimeInterval
    private(set) var elapsed: TimeInterval = 0

    var alpha: CGFloat {
        let fadeStart = totalDuration - fadeDuration
        guard elapsed > fadeStart else { return 1 }
        return max(0, CGFloat((totalDuration - elapsed) / fadeDuration))
    }

    var isFinished: Bool {
        elapsed >= totalDuration
    }

    mutating func advance(by deltaTime: TimeInterval) {
        elapsed = min(totalDuration, elapsed + max(0, deltaTime))
    }

    static func locked(cityNumber: Int) -> Self {
        .init(kind: .locked, text: "City \(cityNumber) is locked",
              totalDuration: 1.5, fadeDuration: 0.3)
    }

    static func completed(cityNumber: Int) -> Self {
        .init(kind: .completed, text: "City \(cityNumber) complete",
              totalDuration: 1.5, fadeDuration: 0.3)
    }
}
```

- [ ] Add named 2.5-second factories for the existing idle-progress messages,
  the existing cannot-enter message, and router rejection. Use the exact
  projection:

```swift
static func idle(
    result: KingdomGameState.IdleProgressResult,
    state: KingdomGameState
) -> Self? {
    guard result.elapsedSeconds > 0 else { return nil }

    let text: String
    if result.conqueredCities > 0 {
        if state.stageStatus == .countryComplete {
            text = "Country \(state.countryNumber) conquered."
        } else if let cityNumber = state.unlockedMapCityNumber {
            let trait = KingdomGameState.defenseTrait(forCityNumber: cityNumber)
            text = "City \(cityNumber): \(trait.displayName)"
        } else {
            assertionFailure("Idle conquest must unlock a city or complete the country")
            return nil
        }
    } else if result.damageDealt > 0 {
        text = "Buildings dealt \(result.damageDealt) idle damage."
    } else {
        text = "No building damage while away."
    }

    return status(text)
}

static func cannotEnterCityYet() -> Self {
    recoverableError("Cannot enter city yet.")
}
```

  `status(_:)` and `recoverableError(_:)` both use 2.5 seconds total and a
  0.3-second fade.

### 5.4 Integrate card presentation and update timing in the scene

- [ ] Replace `feedbackPanel`, `feedbackLabel`, `feedbackText`, and
  `defaultFeedbackText(for:)` with:

```swift
private let scoutCardNode: CountryMapScoutCardNode
private var scoutCardLayout: CountryMapScoutCardLayout?
private var transientFeedback: CountryMapTransientFeedback?
private var previousUpdateTime: TimeInterval?
```

- [ ] Build one card node in `buildInterfaceIfNeeded`.
- [ ] In `layoutInterface`, compute the outer `CountryMapLayout`, then the
  inner Scout layout from `informationRegionFrame`.
- [ ] In redraw, project content from current state and call
  `scoutCardNode.apply`. If it returns
  `.requiredContentDoesNotFit`, invoke the existing `.mapUnavailable` layout
  gate and clear the Scout layout/hit frames.
- [ ] Advance time in `update(_:)` from the SpriteKit timestamp:

```swift
override func update(_ currentTime: TimeInterval) {
    defer { previousUpdateTime = currentTime }
    guard let previousUpdateTime, var feedback = transientFeedback else {
        return
    }

    feedback.advance(by: currentTime - previousUpdateTime)
    transientFeedback = feedback.isFinished ? nil : feedback
    scoutCardNode.applyFeedback(
        text: transientFeedback?.text,
        alpha: transientFeedback?.alpha ?? 0
    )
}
```

- [ ] Reset only `previousUpdateTime` in `didMove(to:)`; do not reset active
  feedback during relayout.
- [ ] Route lifecycle idle results into the typed 2.5-second status factory.

### 5.5 Expose focused DEBUG seams

- [ ] Replace old feedback-panel hooks with:

  - card frame;
  - projected card content;
  - card/Attack/overlay hit frames;
  - visible feedback text, alpha, elapsed, and remaining duration;
  - a deterministic `advanceFeedbackForTesting(by:)`; and
  - whether the map-unavailable gate is active.

- [ ] Keep hooks read-only except the explicit time advance.

### 5.6 Run GREEN, inspect, and commit

- [ ] Run the feedback, card-node, and full country-map scene suites.
- [ ] Verify the old default-feedback symbols no longer exist:

```bash
rtk rg -n \
  'feedbackPanel|feedbackLabel|defaultFeedbackText|var feedbackText' \
  Pyxis/CountryMapScene.swift
```

- [ ] Commit:

```bash
rtk git add \
  Pyxis/CountryMapTransientFeedback.swift \
  Pyxis/CountryMapScene.swift \
  PyxisTests/CountryMapTransientFeedbackTests.swift \
  PyxisTests/CountryMapSceneTests.swift
rtk git commit -m "feat: present timed map scout feedback"
```

---

## Task 6: Converge Every Entry Target on One Guarded Routing Handshake

**Files:**

- Modify: `Pyxis/CountryMapScene.swift`
- Modify: `Pyxis/GameViewController.swift`
- Modify: `PyxisTests/CountryMapSceneTests.swift`
- Modify: `PyxisTests/GameViewControllerTests.swift`

### 6.1 Write failing entry and input-priority tests

- [ ] Change the scene route spy to return a configurable Boolean, defaulting
  to accepted:

```swift
final class CountryMapRouteSpy: CountryMapSceneRouting {
    var acceptsBattleRequest = true
    private(set) var battleRequestCount = 0

    func countryMapSceneDidRequestBattle(_ scene: CountryMapScene) -> Bool {
        battleRequestCount += 1
        return acceptsBattleRequest
    }
}
```

- [ ] Add scene tests for all entry sources:

  - unlocked city node enters;
  - Attack enters;
  - current-city control enters when battle is active;
  - all three persist through `startCityFromMap(_:)` and make exactly one
    router request;
  - two accepted taps across different entry targets still make one request;
  - accepted routing removes the Attack hit target, dims Attack, sets the
    routing lock, and behaviorally suppresses current-city/city targets;
  - `.entered` with a missing router reloads the store and leaves retry
    enabled;
  - router rejection after save reloads the persisted `.battleActive` state,
    displays a recoverable error, and re-enables retry;
  - router acceptance keeps the routing lock;
  - locked city displays exact 1.5-second feedback and does not mutate state;
  - completed city displays exact 1.5-second feedback and does not mutate
    state; and
  - country complete exposes no Attack target.

- [ ] Add explicit touch-priority tests in this order:

  1. map-unavailable gate consumes everything;
  2. routing lock consumes everything;
  3. transient overlay consumes before card;
  4. Attack/card consumes before current control;
  5. current control consumes before city nodes; and
  6. city nodes handle the remaining map taps.

- [ ] Assert the first tap on the card body outside Attack is consumed and
  does not enter. The card itself must not allow touch fallthrough to an
  underlying city node.

### 6.2 Write failing router acceptance tests

- [ ] In `GameViewControllerTests`, assert:

  - no `SKView` returns `false` and does not claim accepted presentation;
  - an attached `SKView` returns `true` only after synchronously presenting
    the battle scene; and
  - the presented battle scene receives the saved state.

### 6.3 Run the focused tests and confirm RED

- [ ] Run the country-map scene and game-view-controller suites. Confirm
  failures reflect the old `Void` router and separate entry paths.

### 6.4 Change the route contract

- [ ] Change the protocol and implementation:

```swift
protocol CountryMapSceneRouting: AnyObject {
    @discardableResult
    func countryMapSceneDidRequestBattle(_ scene: CountryMapScene) -> Bool
    func countryMapScene(
        _ scene: CountryMapScene,
        didRequestLayoutGate reason: AppLayoutGateReason
    )
}
```

```swift
@discardableResult
func countryMapSceneDidRequestBattle(_ scene: CountryMapScene) -> Bool {
    guard let view = self.view as? SKView else { return false }
    presentBattleScene(in: view)
    return true
}
```

- [ ] Return `true` only after `presentBattleScene(in:)` has synchronously
  handed the saved model to the new scene.

### 6.5 Implement one entry method and one routing lock

- [ ] Add:

```swift
private var isRoutingToBattle = false

private func requestEntry(for cityNumber: Int) {
    guard !isRoutingToBattle,
          countryMapLayout != nil,
          scoutCardLayout != nil else {
        return
    }

    var latestState = store.load()
    switch latestState.startCityFromMap(cityNumber) {
    case .entered:
        guard let router else {
            state = store.load()
            showFeedback(.cannotEnterCityYet())
            redraw()
            return
        }

        let idleResult = latestState.returnFromBackground(at: Date())
        state = latestState
        store.save(state)

        guard state.stageStatus == .battleActive else {
            if let feedback = CountryMapTransientFeedback.idle(
                result: idleResult,
                state: state
            ) {
                showFeedback(feedback)
            }
            redraw()
            return
        }

        isRoutingToBattle = true
        redraw()

        guard router.countryMapSceneDidRequestBattle(self) else {
            isRoutingToBattle = false
            showFeedback(.cannotEnterCityYet())
            redraw()
            return
        }

    case .locked:
        showFeedback(.locked(cityNumber: cityNumber))
    case .alreadyCompleted:
        showFeedback(.completed(cityNumber: cityNumber))
    case .countryComplete:
        redraw()
    }
}
```

- [ ] A missing router is detected after the local `.entered` result but
  before idle settlement or save. Reload the store to discard the local
  mutation instead of attempting to reverse fields manually.
- [ ] A router rejection occurs after save. Keep `state` equal to that saved
  `.battleActive` model, clear only the routing lock, and do not save again.
- [ ] Route the Attack action to the projected Scout city number.
- [ ] Route the current-city control and an unlocked city node through the same
  method.
- [ ] City-node taps first reload state and call `mapStatus(for:)`. `.unlocked`
  calls the unified method; `.locked` and `.completed` show their exact
  feedback directly without calling `startCityFromMap`, mutating state, or
  saving. The unified method still handles race-changed `.locked`,
  `.alreadyCompleted`, and `.countryComplete` results after its own reload.

### 6.6 Implement touch priority and duplicate protection

- [ ] In `touchesEnded`, guard point containment in this exact order:

```swift
if isMapUnavailable { return }
if isRoutingToBattle { return }
if scoutCardNode.overlayHitFrame?.contains(location) == true { return }
if scoutCardNode.attackHitFrame?.contains(location) == true {
    requestProjectedScoutEntry()
    return
}
if scoutCardNode.cardHitFrame?.contains(location) == true { return }
if currentCityControlFrame?.contains(location) == true {
    requestEntry(for: state.cityNumberInCountry)
    return
}
if let cityNumber = cityNumber(at: location) {
    handleCityNodeTouch(cityNumber)
}
```

- [ ] A successfully presented card keeps its card-consumption frame. Attack
  has no hit frame while routing or feedback is active, and the existing
  `isRoutingToBattle` early return is the authoritative guard for current-city
  and city-node targets.
- [ ] Keep base card content visible but dim the Attack presentation while a
  route is in flight. Verify subsequent calls through every entry source make
  no additional router request even if SpriteKit nodes remain in the tree.

### 6.7 Run GREEN, inspect, and commit

- [ ] Run `CountryMapSceneTests` and `GameViewControllerTests`.
- [ ] Search for direct calls to `startCityFromMap` in `CountryMapScene`; only
  the unified entry method may call it:

```bash
rtk rg -n 'startCityFromMap|countryMapSceneDidRequestBattle' \
  Pyxis/CountryMapScene.swift \
  Pyxis/GameViewController.swift \
  PyxisTests/CountryMapSceneTests.swift \
  PyxisTests/GameViewControllerTests.swift
```

- [ ] Commit:

```bash
rtk git add \
  Pyxis/CountryMapScene.swift \
  Pyxis/GameViewController.swift \
  PyxisTests/CountryMapSceneTests.swift \
  PyxisTests/GameViewControllerTests.swift
rtk git commit -m "feat: guard country map battle entry"
```

---

## Task 7: Close the Full Acceptance Matrix and Clean Up the Old Path

**Files:**

- Modify: `Pyxis/CountryMapScene.swift`
- Modify: `PyxisTests/CountryMapSceneTests.swift`
- Modify: any Task 1–6 file only when a failing acceptance test demonstrates
  the need.

### 7.1 Add the cross-feature acceptance matrix

- [ ] Parameterize scene construction over every
  `CountryMapLayoutTestFixtures.supported` fixture.
- [ ] For each fixture, assert:

  - a fresh state immediately shows city 1 Scout content without selection;
  - a pending-map state immediately shows the next unlocked city;
  - card and Attack frames remain inside the information region;
  - the card does not intersect any authored city hit frame;
  - every visible required string is non-empty and validated;
  - Attack and unlocked city node both enter;
  - locked/completed overlays leave card content unchanged;
  - country complete shows exact `Country N conquered.` and no Attack;
  - relayout recreates the same projected content and routing-enabled state;
    and
  - no future locked city trait, reward, or lane appears anywhere in DEBUG
    presentation readbacks.

- [ ] Add a dense-content matrix for every `Country1CityCatalog.definition`
  with its actual favorable/disadvantaged arrays and all authored exposed
  lanes.
- [ ] Add the missing-asset matrix:

  - all assets present;
  - `gold-burst` missing;
  - one soldier icon missing;
  - all soldier icons missing.

  Required text must remain complete in every case.

### 7.2 Run the new matrix and fix only demonstrated gaps

- [ ] Run the country-map content/layout/text/node/feedback/scene suites
  together.
- [ ] Make the smallest production correction for each demonstrated failure.
  Do not loosen fit contracts, shrink below the approved minimums, or change
  the outer layout to make a test pass.

### 7.3 Remove superseded code and stale tests

- [ ] Delete the old feedback panel/label/default-copy path and obsolete DEBUG
  hooks once every replacement assertion is green.
- [ ] Rename tests that still describe the information region as a generic
  feedback panel.
- [ ] Keep existing lifecycle observer guards and idle-progress semantics
  intact.
- [ ] Confirm the scene has one card node, one typed feedback value, one entry
  method, and one routing lock.

### 7.4 Run static checks

- [ ] Run SwiftLint:

```bash
rtk swiftlint lint --cache-path /private/tmp/pyxis-hpa-387-swiftlint-cache
```

- [ ] Run a build:

```bash
rtk xcodebuild \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build
```

- [ ] Resolve only warnings/errors caused by HPA-387.

### 7.5 Run the full test suite with parallel testing disabled

- [ ] Preferred: `test_sim` for scheme `Pyxis` with
  `extraArgs: ["-parallel-testing-enabled", "NO"]`.
- [ ] Fallback:

```bash
rtk xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO
```

- [ ] Record the simulator, test count, and final result in the implementation
  handoff.

### 7.6 Perform a whole-branch review

- [ ] Inspect:

```bash
rtk git status --short
rtk git diff --stat main...HEAD
rtk git diff main...HEAD -- \
  Pyxis \
  PyxisTests
rtk git diff --check
```

- [ ] Review against every in-scope bullet in the approved spec.
- [ ] Verify:

  - no new persistence key;
  - no new asset;
  - no outer-layout edit;
  - no future-city disclosure;
  - exact ticket copy and durations;
  - no overlay tap dismissal;
  - no duplicate accepted route;
  - router rejection remains retryable;
  - asset cropping preserves body aspect ratio; and
  - no test relies on SpriteKit action advancement for feedback timing.

### 7.7 Run the simulator smoke

- [ ] Build and launch the app with XcodeBuildMCP on the configured portrait
  simulator.
- [ ] On a clean app state, visually confirm the city 1 Scout Card is present
  immediately, tap a locked city and observe exact timed feedback, then tap
  Attack and confirm battle presentation.
- [ ] Seed pending-map, completed-city, and country-complete
  `pyxis.kingdomGameState` values in the simulator's `cwchanap.Pyxis`
  defaults domain using JSON produced by the app's existing
  `KingdomGameState` encoder in a temporary test harness. Relaunch after each
  seed and visually confirm:

  - the next unlocked Scout appears without selection;
  - a completed node shows `City N complete` for 1.5 seconds over unchanged
    content; and
  - country completion shows `Country 1 conquered.` with no Attack target.

- [ ] Remove the temporary simulator defaults seeds by uninstalling the app or
  erasing its data. Do not add a DEBUG launch-argument contract to production
  solely for this smoke.
- [ ] Capture the simulator/device and observed outcomes in the handoff.

### 7.8 Commit final acceptance cleanup

- [ ] If the acceptance pass changed code, commit only those changes:

```bash
rtk git add Pyxis PyxisTests
rtk git commit -m "test: close scout card acceptance matrix"
```

- [ ] If no changes were required after the Task 6 commit, do not create an
  empty commit.

---

## Final Handoff Checklist

- [ ] Every task commit is present and narrowly scoped.
- [ ] Worktree contains no accidental generated files or unrelated changes.
- [ ] Focused Scout Card suites pass.
- [ ] Existing country-map, campaign, catalog, lane, and lifecycle regressions
  pass.
- [ ] SwiftLint passes.
- [ ] Full unit and UI test suite passes with parallel testing disabled.
- [ ] The implementation handoff reports any simulator-only limitation
  plainly; do not claim physical-device validation unless it was performed.
- [ ] Do not change the Linear issue status or post detailed evidence without
  explicit user authorization.
