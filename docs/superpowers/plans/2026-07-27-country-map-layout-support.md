# Country Map Layout Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Country 1 map's compact/wide fallback with one tested portrait layout contract and an app-wide blocking gate for unsupported geometry.

**Architecture:** A CoreGraphics-only layout engine owns canonical Country 1 data, computes every map frame and route atomically, and rejects invalid definitions or unsupported windows without partial output. `CountryMapScene` renders only supported output, while `GameViewController` applies the same policy app-wide through a UIKit overlay and resets `BattleScene`'s frame clock before resuming.

**Tech Stack:** Swift 5, CoreGraphics, SpriteKit, UIKit, Swift Testing, Xcode project build settings

## Global Constraints

- iPhone supports upright portrait only.
- iPad supports upright portrait and upside-down portrait only.
- The Country 1 canonical backdrop is 1024×1536 points with 15 normalized anchors.
- The backdrop uniformly aspect-fills the scene; no alternate anchor frame, clamping, or non-uniform scale is allowed.
- Supported geometry has a 375×667 base floor and must pass all computed chrome, city-frame, and route bounds.
- Every city has a centered 44×44-point interaction and clearance frame.
- The information region is 76 points high on phone and 112 points high on iPad.
- The illustrated map region is the full-width corridor from `informationRegion.maxY + 8` through `titleControlRegion.minY - 8`.
- Safe-area inputs are live semantic UIKit edge distances with no synthetic tall-phone substitution or upside-down swap.
- Unsupported geometry copy is “Pyxis needs a supported portrait window. Rotate or resize to continue.”
- Tests and verification run with parallel testing disabled.

---

## File Map

- Create `Pyxis/CountryMapLayoutDefinition.swift` for canonical anchors and route definitions.
- Create `Pyxis/CountryMapLayout.swift` for pure constraints, result types, geometry computation, and invariant validation.
- Create `Pyxis/CountryMapLayoutUIKitAdapter.swift` for `UIEdgeInsets` and `UIUserInterfaceIdiom` conversion.
- Create `Pyxis/AppLayoutGateView.swift` for the blocking UIKit overlay and gate reason.
- Create `PyxisTests/CountryMapLayoutTests.swift` for the complete pure fixture matrix and malformed-data coverage.
- Create `PyxisTests/GameViewControllerTests.swift` for app-wide gating, adapter semantics, state preservation, and orientation policy.
- Modify `Pyxis/CountryMapScene.swift` to apply `CountryMapLayout` output and report map unavailability.
- Modify `PyxisTests/CountryMapSceneTests.swift` to consume production layout output and remove fallback expectations.
- Modify `Pyxis/GameViewController.swift` to own orientation policy, overlay state, and pause/resume sequencing.
- Modify `Pyxis/BattleScene.swift` and `PyxisTests/BattleSceneTests.swift` for the gate-resume clock hook.
- Modify `Pyxis.xcodeproj/project.pbxproj` to narrow the generated Info.plist orientation declarations.

### Task 1: Build the pure Country 1 layout engine

**Files:**
- Create: `Pyxis/CountryMapLayoutDefinition.swift`
- Create: `Pyxis/CountryMapLayout.swift`
- Create: `PyxisTests/CountryMapLayoutTests.swift`

**Interfaces:**
- Produces: `CountryMapLayoutDefinition.country1`
- Produces: `CountryMapLayoutEnvironment`
- Produces: `CountryMapLayoutConstraints`
- Produces: `CountryMapLayout.compute(_:) -> CountryMapLayoutResult`
- Produces: `.supported(CountryMapLayout)` or `.unsupported(.unsupportedGeometry/.invalidAuthoredData)`
- Consumes: `KingdomGameState.firstCountryCityCount` only in tests that tie the authored count to the gameplay model

- [ ] **Step 1: Write definition and malformed-data tests**

Add `CountryMapLayoutTests` with these exact structural assertions:

```swift
import CoreGraphics
import Testing
@testable import Pyxis

struct CountryMapLayoutTests {
    @Test func country1DefinitionMatchesCampaignAndRouteContract() {
        let definition = CountryMapLayoutDefinition.country1

        #expect(definition.canonicalBackdropSize == CGSize(width: 1024, height: 1536))
        #expect(definition.cityAnchors.count == KingdomGameState.firstCountryCityCount)
        #expect(definition.primaryRoutes.count == 14)
        #expect(definition.branches.map(\.originCityNumber) == [3, 6, 9, 12])
    }

    @Test func malformedDefinitionFailsWithoutPartialGeometry() {
        let source = CountryMapLayoutDefinition.country1
        let malformed = CountryMapLayoutDefinition(
            canonicalBackdropSize: source.canonicalBackdropSize,
            cityAnchors: Array(source.cityAnchors.dropLast()),
            primaryRoutes: source.primaryRoutes,
            branches: source.branches
        )
        let result = CountryMapLayout.compute(.init(
            sceneSize: CGSize(width: 393, height: 852),
            environment: .init(
                safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0),
                layoutClass: .phone
            ),
            definition: malformed
        ))

        #expect(result == .unsupported(.invalidAuthoredData))
    }
}
```

- [ ] **Step 2: Run the new suite and verify the expected compile failure**

Run:

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/CountryMapLayoutTests
```

Expected: compilation fails because the new country-map layout types do not exist.

- [ ] **Step 3: Add the canonical definition types and data**

Create these exact type boundaries in `CountryMapLayoutDefinition.swift`:

```swift
import CoreGraphics

struct CountryMapPrimaryRouteDefinition: Equatable {
    let startCityNumber: Int
    let endCityNumber: Int
    let lineWidth: CGFloat
}

struct CountryMapBranchDefinition: Equatable {
    let originCityNumber: Int
    let offset: CGVector
    let lineWidth: CGFloat
}

struct CountryMapLayoutDefinition: Equatable {
    let canonicalBackdropSize: CGSize
    let cityAnchors: [CGPoint]
    let primaryRoutes: [CountryMapPrimaryRouteDefinition]
    let branches: [CountryMapBranchDefinition]

    static let country1 = CountryMapLayoutDefinition(
        canonicalBackdropSize: CGSize(width: 1024, height: 1536),
        cityAnchors: [
            CGPoint(x: 0.4000, y: 0.1696),
            CGPoint(x: 0.7528, y: 0.2020),
            CGPoint(x: 0.6846, y: 0.2874),
            CGPoint(x: 0.6904, y: 0.3721),
            CGPoint(x: 0.2776, y: 0.2517),
            CGPoint(x: 0.3518, y: 0.3386),
            CGPoint(x: 0.4171, y: 0.4171),
            CGPoint(x: 0.7078, y: 0.4598),
            CGPoint(x: 0.7200, y: 0.6160),
            CGPoint(x: 0.5894, y: 0.6473),
            CGPoint(x: 0.3468, y: 0.5793),
            CGPoint(x: 0.4225, y: 0.6725),
            CGPoint(x: 0.3452, y: 0.7280),
            CGPoint(x: 0.4865, y: 0.7651),
            CGPoint(x: 0.6807, y: 0.7931)
        ],
        primaryRoutes: (1...14).map {
            CountryMapPrimaryRouteDefinition(
                startCityNumber: $0,
                endCityNumber: $0 + 1,
                lineWidth: 6
            )
        },
        branches: [
            .init(originCityNumber: 3, offset: CGVector(dx: -44, dy: 34), lineWidth: 4),
            .init(originCityNumber: 6, offset: CGVector(dx: 44, dy: 34), lineWidth: 4),
            .init(originCityNumber: 9, offset: CGVector(dx: -44, dy: 34), lineWidth: 4),
            .init(originCityNumber: 12, offset: CGVector(dx: 44, dy: 34), lineWidth: 4)
        ]
    )
}
```

- [ ] **Step 4: Add the complete supported and unsupported fixture tests**

Use the production fixture matrix verbatim:

```swift
private struct Fixture {
    let name: String
    let size: CGSize
    let insets: CountryMapSafeAreaInsets
    let layoutClass: CountryMapLayoutClass
}

private let supportedFixtures = [
    Fixture(name: "small phone", size: .init(width: 375, height: 667), insets: .zero, layoutClass: .phone),
    Fixture(name: "modern phone", size: .init(width: 393, height: 852), insets: .init(top: 59, left: 0, bottom: 34, right: 0), layoutClass: .phone),
    Fixture(name: "large phone", size: .init(width: 440, height: 956), insets: .init(top: 62, left: 0, bottom: 34, right: 0), layoutClass: .phone),
    Fixture(name: "iPad mini", size: .init(width: 744, height: 1133), insets: .init(top: 24, left: 0, bottom: 20, right: 0), layoutClass: .pad),
    Fixture(name: "11-inch iPad", size: .init(width: 834, height: 1194), insets: .init(top: 24, left: 0, bottom: 20, right: 0), layoutClass: .pad),
    Fixture(name: "13-inch iPad", size: .init(width: 1032, height: 1376), insets: .init(top: 24, left: 0, bottom: 20, right: 0), layoutClass: .pad),
    Fixture(name: "Stage Manager", size: .init(width: 600, height: 1000), insets: .init(top: 28, left: 0, bottom: 20, right: 0), layoutClass: .pad),
    Fixture(name: "narrow iPad", size: .init(width: 480, height: 1194), insets: .init(top: 24, left: 0, bottom: 20, right: 0), layoutClass: .pad)
]

private let unsupportedFixtures = [
    Fixture(name: "phone landscape", size: .init(width: 667, height: 375), insets: .zero, layoutClass: .phone),
    Fixture(name: "iPad landscape", size: .init(width: 1194, height: 834), insets: .init(top: 24, left: 0, bottom: 20, right: 0), layoutClass: .pad),
    Fixture(name: "wide split", size: .init(width: 678, height: 834), insets: .init(top: 24, left: 0, bottom: 20, right: 0), layoutClass: .pad),
    Fixture(name: "wide iPad", size: .init(width: 1024, height: 768), insets: .init(top: 24, left: 0, bottom: 20, right: 0), layoutClass: .pad),
    Fixture(name: "square", size: .init(width: 700, height: 700), insets: .init(top: 24, left: 0, bottom: 20, right: 0), layoutClass: .pad),
    Fixture(name: "undersized", size: .init(width: 320, height: 568), insets: .zero, layoutClass: .phone),
    Fixture(name: "over-cropped narrow iPad", size: .init(width: 375, height: 1194), insets: .init(top: 24, left: 0, bottom: 20, right: 0), layoutClass: .pad)
]

private func result(
    size: CGSize,
    insets: CountryMapSafeAreaInsets = .zero,
    layoutClass: CountryMapLayoutClass
) -> CountryMapLayoutResult {
    CountryMapLayout.compute(.init(
        sceneSize: size,
        environment: .init(safeAreaInsets: insets, layoutClass: layoutClass),
        definition: .country1
    ))
}

private func supportedLayout(
    size: CGSize,
    insets: CountryMapSafeAreaInsets,
    layoutClass: CountryMapLayoutClass
) throws -> CountryMapLayout {
    var supported: CountryMapLayout?
    if case .supported(let layout) = result(
        size: size,
        insets: insets,
        layoutClass: layoutClass
    ) {
        supported = layout
    }
    return try #require(supported)
}
```

For every supported fixture, require `.supported`, then assert:

```swift
#expect(layout.sceneFrame.contains(layout.titleControlRegionFrame))
#expect(layout.sceneFrame.contains(layout.currentCityControlFrame))
#expect(layout.titleControlRegionFrame.contains(layout.currentCityControlFrame))
#expect(layout.sceneFrame.contains(layout.informationRegionFrame))
#expect(layout.cityPositions.count == 15)
#expect(layout.routes.count == 18)

for position in layout.cityPositions.values {
    let cityFrame = CGRect(
        x: position.x - 22,
        y: position.y - 22,
        width: 44,
        height: 44
    )
    #expect(layout.illustratedMapRegionFrame.contains(cityFrame))
}

for route in layout.routes {
    #expect(layout.illustratedMapRegionFrame.contains(route.strokeExpandedBounds))
}
```

Also assert the backdrop covers every scene edge and each city position equals
the normalized anchor mapped into `displayedBackdropFrame` within 1 point. For
every unsupported fixture, assert
`.unsupported(.unsupportedGeometry)` and no layout payload.

- [ ] **Step 5: Implement the pure layout result and formulas**

Create the following public-internal shape in `CountryMapLayout.swift`:

```swift
import CoreGraphics

struct CountryMapSafeAreaInsets: Equatable {
    let top: CGFloat
    let left: CGFloat
    let bottom: CGFloat
    let right: CGFloat

    static let zero = CountryMapSafeAreaInsets(top: 0, left: 0, bottom: 0, right: 0)
}

enum CountryMapLayoutClass: Equatable {
    case phone
    case pad

    var informationRegionHeight: CGFloat {
        self == .phone ? 76 : 112
    }
}

struct CountryMapLayoutEnvironment: Equatable {
    let safeAreaInsets: CountryMapSafeAreaInsets
    let layoutClass: CountryMapLayoutClass
}

struct CountryMapLayoutConstraints: Equatable {
    let sceneSize: CGSize
    let environment: CountryMapLayoutEnvironment
    let definition: CountryMapLayoutDefinition
}

struct CountryMapRouteLayout: Equatable {
    let start: CGPoint
    let end: CGPoint
    let lineWidth: CGFloat

    var strokeExpandedBounds: CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        ).insetBy(dx: -lineWidth / 2, dy: -lineWidth / 2)
    }
}

enum CountryMapLayoutFailureReason: Equatable {
    case unsupportedGeometry
    case invalidAuthoredData
}

enum CountryMapLayoutResult: Equatable {
    case supported(CountryMapLayout)
    case unsupported(CountryMapLayoutFailureReason)
}

struct CountryMapLayout: Equatable {
    let sceneFrame: CGRect
    let displayedBackdropFrame: CGRect
    let titleControlRegionFrame: CGRect
    let currentCityControlFrame: CGRect
    let informationRegionFrame: CGRect
    let illustratedMapRegionFrame: CGRect
    let cityPositions: [Int: CGPoint]
    let routes: [CountryMapRouteLayout]

    static func compute(_ constraints: CountryMapLayoutConstraints) -> CountryMapLayoutResult
}
```

Implement `compute(_:)` in this order:

```swift
let sceneFrame = CGRect(origin: .zero, size: constraints.sceneSize)
guard constraints.sceneSize.width >= 375,
      constraints.sceneSize.height >= 667,
      constraints.sceneSize.width.isFinite,
      constraints.sceneSize.height.isFinite
else {
    return .unsupported(.unsupportedGeometry)
}
```

Before calculating the aspect-fill scale, reject non-finite/non-positive
canonical dimensions, any anchor outside `0...1`, a city count other than 15,
primary route endpoints outside `1...15`, a primary route count other than 14,
branch origins outside `1...15`, non-finite branch offsets, or
non-positive/non-finite line widths as `.invalidAuthoredData`.

Then calculate:

```swift
let source = constraints.definition.canonicalBackdropSize
let scale = max(
    constraints.sceneSize.width / source.width,
    constraints.sceneSize.height / source.height
)
let backdropSize = CGSize(width: source.width * scale, height: source.height * scale)
let displayedBackdropFrame = CGRect(
    x: (constraints.sceneSize.width - backdropSize.width) / 2,
    y: (constraints.sceneSize.height - backdropSize.height) / 2,
    width: backdropSize.width,
    height: backdropSize.height
)

let topMargin = max(34, constraints.environment.safeAreaInsets.top + 10)
let titleWidth = max(220, min(constraints.sceneSize.width - 40, 520))
let titleControlRegionFrame = CGRect(
    x: (constraints.sceneSize.width - titleWidth) / 2,
    y: constraints.sceneSize.height - topMargin - 66,
    width: titleWidth,
    height: 66
)
let currentCityControlFrame = CGRect(
    x: titleControlRegionFrame.maxX - 10 - 82,
    y: titleControlRegionFrame.midY - 22,
    width: 82,
    height: 44
)

let informationWidth = max(0, min(constraints.sceneSize.width - 32, 600))
let informationRegionFrame = CGRect(
    x: (constraints.sceneSize.width - informationWidth) / 2,
    y: constraints.environment.safeAreaInsets.bottom,
    width: informationWidth,
    height: constraints.environment.layoutClass.informationRegionHeight
)
let illustratedMapRegionFrame = CGRect(
    x: sceneFrame.minX,
    y: informationRegionFrame.maxY + 8,
    width: sceneFrame.width,
    height: titleControlRegionFrame.minY - informationRegionFrame.maxY - 16
)
```

Map anchors into `displayedBackdropFrame`, create 14 primary routes plus four
fixed-offset branches, and reject as `.unsupportedGeometry` when:

- any safe-area component is negative or non-finite;
- any chrome or current-city frame escapes `sceneFrame`;
- `illustratedMapRegionFrame` is null, empty, or non-finite;
- any 44×44 city frame escapes `illustratedMapRegionFrame`; or
- any route's `strokeExpandedBounds` escapes `illustratedMapRegionFrame`.

Return `.supported` only after every collection is complete.

- [ ] **Step 6: Add semantic-inset and boundary regression tests**

Add tests proving:

```swift
@Test func semanticInsetsAreNotSwappedOrSynthesized() throws {
    let upright = try supportedLayout(
        size: CGSize(width: 834, height: 1194),
        insets: .init(top: 24, left: 7, bottom: 36, right: 11),
        layoutClass: .pad
    )
    #expect(upright.titleControlRegionFrame.maxY == 1160)
    #expect(upright.informationRegionFrame.minY == 36)

    let upsideDown = try supportedLayout(
        size: CGSize(width: 834, height: 1194),
        insets: .init(top: 36, left: 11, bottom: 24, right: 7),
        layoutClass: .pad
    )
    #expect(upsideDown.titleControlRegionFrame.maxY == 1148)
    #expect(upsideDown.informationRegionFrame.minY == 24)
}

@Test func reviewedNarrowBoundaryRejects375By1194AndAccepts480By1194() {
    let insets = CountryMapSafeAreaInsets(top: 24, left: 0, bottom: 20, right: 0)
    #expect(result(
        size: .init(width: 375, height: 1194),
        insets: insets,
        layoutClass: .pad
    )
        == .unsupported(.unsupportedGeometry))
    guard case .supported = result(
        size: .init(width: 480, height: 1194),
        insets: insets,
        layoutClass: .pad
    ) else {
        Issue.record("480×1194 must satisfy the complete invariant set")
        return
    }
}
```

The test helper must pass the fixture's explicit inset values; it must not call
`GameUITheme.topUnsafeInset` or `bottomUnsafeInset`.

- [ ] **Step 7: Run the pure layout suite and commit**

Run:

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/CountryMapLayoutTests
```

Expected: all `CountryMapLayoutTests` pass.

Commit:

```bash
git add Pyxis/CountryMapLayoutDefinition.swift Pyxis/CountryMapLayout.swift PyxisTests/CountryMapLayoutTests.swift
git commit -m "feat: add canonical country map layout"
```

### Task 2: Make CountryMapScene render only production layout output

**Files:**
- Create: `Pyxis/CountryMapLayoutUIKitAdapter.swift`
- Modify: `Pyxis/CountryMapScene.swift:10-438`
- Modify: `PyxisTests/CountryMapSceneTests.swift:335-770`

**Interfaces:**
- Consumes: `CountryMapLayout.compute(_:)`
- Produces: `CountryMapLayoutUIKitAdapter.environment(safeAreaInsets:idiom:)`
- Produces: `CountryMapScene.lastLayoutResult`
- Produces: `CountryMapScene.countryMapLayoutForTesting`
- Produces: `CountryMapScene.refreshLayoutForCurrentEnvironment()`
- Preserves: all city selection, routing, visual-state, persistence, and idle-progress behavior

- [ ] **Step 1: Replace fallback-oriented scene tests with production-layout assertions**

Delete the expectations from
`compactLandscapeLayoutKeepsCityNodesInsideMapArea` and
`wideLayoutClampsCityAnchorsToVisibleMapRegion`. Replace them with:

```swift
@Test func unsupportedLandscapeDoesNotApplyPartialMapGeometry() throws {
    let scene = makeScene(
        size: CGSize(width: 667, height: 375),
        store: try makeStore(initialState: .init()),
        router: RouteSpy(),
        environment: .init(safeAreaInsets: .zero, layoutClass: .phone)
    )

    #expect(scene.lastLayoutResultForTesting == .unsupported(.unsupportedGeometry))
    #expect(scene.routeLayoutCountForTesting == 0)
}

@Test func supportedSceneProjectsTheProductionLayout() throws {
    let scene = makeScene(
        size: CGSize(width: 393, height: 852),
        store: try makeStore(initialState: .init(
            cityRemainingPower: 0,
            cityNumberInCountry: 1,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        )),
        router: RouteSpy(),
        environment: .init(
            safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0),
            layoutClass: .phone
        )
    )
    let layout = try #require(scene.countryMapLayoutForTesting)

    #expect(scene.mapLayoutFramesForTesting.sceneFrame == layout.sceneFrame)
    #expect(scene.mapLayoutFramesForTesting.titlePanelFrame == layout.titleControlRegionFrame)
    #expect(scene.mapLayoutFramesForTesting.illustratedRegionFrame == layout.illustratedMapRegionFrame)
    #expect(scene.mapLayoutFramesForTesting.feedbackPanelFrame.midX == layout.informationRegionFrame.midX)
    #expect(scene.mapLayoutFramesForTesting.feedbackPanelFrame.midY == layout.informationRegionFrame.midY)
}

private func makeScene(
    size: CGSize = CGSize(width: 393, height: 852),
    store: KingdomGameStore,
    router: CountryMapSceneRouting?,
    environment: CountryMapLayoutEnvironment = .init(
        safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0),
        layoutClass: .phone
    )
) -> CountryMapScene {
    let scene = CountryMapScene(
        size: size,
        store: store,
        router: router,
        layoutEnvironmentOverride: environment
    )
    scene.didMove(to: SKView(frame: CGRect(origin: .zero, size: size)))
    return scene
}
```

Migrate the six accessors in these tests:

```text
fullBackdropMapLayoutKeepsTitleFeedbackAndAllCitiesVisible
countryMapBackdropCoversFullSceneBehindHUD
wideLayoutClampsCityAnchorsToVisibleMapRegion
illustratedRegionMapAvoidsTallPhoneSensorArea
titleLabelFitsWithinPanelOnFirstLayout
titleLabelFitsWithCurrentCityButtonVisible
```

The wide-layout test becomes the unsupported-output test above. Rename the
tall-phone test to `semanticSafeAreaInsetsPositionMapChrome` and inject
`top: 59, bottom: 34`; assert the layout edges derive from those exact values
instead of the old synthetic 58/26 values. Move the two title-fitting tests
from unsupported 320×568 to the supported 375×667 fixture.

Remove the duplicated 15-anchor literal from
`cityNodesAlignToAuthoredBackdropPads`; calculate expected positions from
`CountryMapLayoutDefinition.country1`. Remove
`authoredCityPadAnchorCountForTesting`; Task 1 owns the count contract.

- [ ] **Step 2: Run the focused scene suite and verify the failures**

Run:

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/CountryMapSceneTests
```

Expected: the new production-layout accessors and injected environment do not
exist, and the two old fallback behaviors no longer match the tests.

- [ ] **Step 3: Add the UIKit adapter without size-class inference**

Create `CountryMapLayoutUIKitAdapter.swift`:

```swift
import SpriteKit
import UIKit

enum CountryMapLayoutUIKitAdapter {
    static func environment(
        safeAreaInsets: UIEdgeInsets,
        idiom: UIUserInterfaceIdiom
    ) -> CountryMapLayoutEnvironment? {
        let layoutClass: CountryMapLayoutClass
        switch idiom {
        case .phone:
            layoutClass = .phone
        case .pad:
            layoutClass = .pad
        default:
            return nil
        }

        return CountryMapLayoutEnvironment(
            safeAreaInsets: CountryMapSafeAreaInsets(
                top: safeAreaInsets.top,
                left: safeAreaInsets.left,
                bottom: safeAreaInsets.bottom,
                right: safeAreaInsets.right
            ),
            layoutClass: layoutClass
        )
    }

    static func environment(for view: SKView) -> CountryMapLayoutEnvironment? {
        environment(
            safeAreaInsets: view.safeAreaInsets,
            idiom: view.traitCollection.userInterfaceIdiom
        )
    }
}
```

Add:

```swift
@Test func UIKitAdapterUsesIdiomAndPreservesSemanticInsets() throws {
    let phone = try #require(CountryMapLayoutUIKitAdapter.environment(
        safeAreaInsets: .init(top: 59, left: 3, bottom: 34, right: 5),
        idiom: .phone
    ))
    #expect(phone.layoutClass == .phone)
    #expect(phone.safeAreaInsets == .init(top: 59, left: 3, bottom: 34, right: 5))

    let narrowPad = try #require(CountryMapLayoutUIKitAdapter.environment(
        safeAreaInsets: .init(top: 24, left: 11, bottom: 20, right: 7),
        idiom: .pad
    ))
    #expect(narrowPad.layoutClass == .pad)
    #expect(narrowPad.safeAreaInsets == .init(top: 24, left: 11, bottom: 20, right: 7))

    #expect(CountryMapLayoutUIKitAdapter.environment(
        safeAreaInsets: .zero,
        idiom: .unspecified
    ) == nil)
}
```

- [ ] **Step 4: Refactor CountryMapScene to atomically apply supported output**

Add an optional injected environment:

```swift
private let layoutEnvironmentOverride: CountryMapLayoutEnvironment?
private(set) var lastLayoutResult: CountryMapLayoutResult?
private(set) var countryMapLayout: CountryMapLayout?

init(
    size: CGSize,
    store: KingdomGameStore = .shared,
    router: CountryMapSceneRouting? = nil,
    layoutEnvironmentOverride: CountryMapLayoutEnvironment? = nil
) {
    self.store = store
    self.router = router
    self.state = store.load()
    self.layoutEnvironmentOverride = layoutEnvironmentOverride
    super.init(size: size)
}
```

The coder initializer sets `layoutEnvironmentOverride = nil`.

Replace `layoutInterface()`'s compact branch, synthetic inset calls, local
anchor calculations, and wide fallback with:

```swift
private func layoutInterface() {
    guard didBuildInterface else { return }

    guard let environment = layoutEnvironmentOverride
        ?? view.flatMap({ CountryMapLayoutUIKitAdapter.environment(for: $0) })
    else {
        lastLayoutResult = .unsupported(.unsupportedGeometry)
        countryMapLayout = nil
        routeLayer.removeAllChildren()
        return
    }

    let result = CountryMapLayout.compute(.init(
        sceneSize: size,
        environment: environment,
        definition: .country1
    ))
    lastLayoutResult = result

    guard case .supported(let layout) = result else {
        countryMapLayout = nil
        routeLayer.removeAllChildren()
        return
    }

    countryMapLayout = layout
    apply(layout)
    redraw()
}
```

Add an internal adapter entry point used for inset-only UIKit changes:

```swift
func refreshLayoutForCurrentEnvironment() {
    layoutInterface()
}
```

`didMove(to:)` and `didChangeSize(_:)` continue to call `layoutInterface()`.
The controller calls the new method from
`viewSafeAreaInsetsDidChange()` so a safe-area-only change updates the rendered
map as well as the app-wide support decision.

`apply(_:)` must:

- size and position the backdrop from `displayedBackdropFrame` with uniform
  scale and no use of loaded texture dimensions;
- update and position the 66-point title panel;
- lay out an 82×44 current-city button inside
  `currentCityControlFrame`;
- update the information/feedback panel to
  `CGSize(width: informationRegionFrame.width, height: 56)` and center it in
  `informationRegionFrame`;
- set every city node to 15-point visual radius, every city label to 12 points,
  and every city/label/marker from the layout's position dictionary; and
- rebuild all 18 `SKShapeNode` routes from `layout.routes`.

Remove `authoredCityPadAnchors`, `cityPositions(in:)`, the hard-coded loops in
`drawRoutes`, `isCompactHeight`, and `GameUITheme` safe-area lookup from this
scene.

- [ ] **Step 5: Make city hit areas and current-city control match production frames**

Keep the visible 15-point circle but attach an invisible named
`SKShapeNode(rectOf: CGSize(width: 44, height: 44))` to each city container, or
replace the current city node with a container whose named hit area is 44×44.
Ensure `cityNumber(at:)` still resolves the name from the hit area.

Set the current-city background path to 82×44 and keep its entire frame inside
the title panel. Add assertions:

```swift
@Test func allCityCentersHave44PointHitTargets() throws {
    let scene = makeScene(
        store: try makeStore(initialState: .init(
            cityRemainingPower: 0,
            completedCityCount: 1,
            stageStatus: .cityConqueredPendingMap
        )),
        router: RouteSpy()
    )
    for cityNumber in 1...15 {
        let center = try #require(scene.cityNodePositionForTesting(cityNumber))
        #expect(scene.cityNumberAtPointForTesting(center) == cityNumber)
        #expect(scene.cityHitFrameForTesting(cityNumber)?.size == CGSize(width: 44, height: 44))
    }
}

@Test func currentCityControlFrameIsInsideTitlePanel() throws {
    let scene = makeScene(
        store: try makeStore(initialState: .init(stageStatus: .battleActive)),
        router: RouteSpy()
    )
    let layout = try #require(scene.countryMapLayoutForTesting)
    #expect(layout.titleControlRegionFrame.contains(layout.currentCityControlFrame))
    #expect(scene.currentCityButtonFrameForTesting == layout.currentCityControlFrame)
}
```

- [ ] **Step 6: Run pure and scene suites and commit**

Run:

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/CountryMapLayoutTests \
  -only-testing:PyxisTests/CountryMapSceneTests
```

Expected: both suites pass; landscape and wide tests now assert unsupported
output instead of fallback placement.

Commit:

```bash
git add Pyxis/CountryMapLayoutUIKitAdapter.swift Pyxis/CountryMapScene.swift PyxisTests/CountryMapSceneTests.swift
git commit -m "refactor: render country map from canonical layout"
```

### Task 3: Add the app-wide layout gate and safe resume hook

**Files:**
- Create: `Pyxis/AppLayoutGateView.swift`
- Create: `PyxisTests/GameViewControllerTests.swift`
- Modify: `Pyxis/GameViewController.swift:11-123`
- Modify: `Pyxis/CountryMapScene.swift:10-202`
- Modify: `PyxisTests/CountryMapSceneTests.swift:700-770`
- Modify: `Pyxis/BattleScene.swift:90-110,283-299,2778-3355`
- Modify: `PyxisTests/BattleSceneTests.swift`

**Interfaces:**
- Consumes: `CountryMapLayout.compute(_:)` and `CountryMapLayoutUIKitAdapter`
- Produces: `AppLayoutGateReason`
- Produces: `LayoutGateResumable.prepareForLayoutGateResume()`
- Produces: `CountryMapSceneRouting.countryMapScene(_:didRequestLayoutGate:)`
- Produces: app-wide pause, input interception, and automatic supported-geometry restoration

- [ ] **Step 1: Write controller gate-cycle and state-preservation tests**

Create `GameViewControllerTests.swift`:

```swift
import SpriteKit
import Testing
import UIKit
@testable import Pyxis

@MainActor
struct GameViewControllerTests {
    @Test func unsupportedGeometryPausesAndBlocksThenResumesWithoutStateMutation() throws {
        let initialState = KingdomGameState(gold: 37)
        let store = try makeStore(initialState: initialState)
        let controller = GameViewController(store: store)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        controller.view = view
        controller.viewDidLoad()

        controller.refreshLayoutSupportForTesting(environment: .init(
            safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0),
            layoutClass: .phone
        ))
        #expect(!controller.isLayoutGateVisibleForTesting)
        #expect(!view.isPaused)

        view.frame.size = CGSize(width: 667, height: 375)
        controller.refreshLayoutSupportForTesting(environment: .init(
            safeAreaInsets: .zero,
            layoutClass: .phone
        ))
        #expect(controller.layoutGateReasonForTesting == .unsupportedGeometry)
        #expect(controller.layoutGateTextForTesting
            == "Pyxis needs a supported portrait window. Rotate or resize to continue.")
        #expect(view.isPaused)
        #expect(view.scene?.isUserInteractionEnabled == false)
        #expect(store.load() == initialState)

        view.frame.size = CGSize(width: 393, height: 852)
        controller.refreshLayoutSupportForTesting(environment: .init(
            safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0),
            layoutClass: .phone
        ))
        #expect(!controller.isLayoutGateVisibleForTesting)
        #expect(!view.isPaused)
        #expect(view.scene?.isUserInteractionEnabled == true)
        #expect(store.load() == initialState)
    }

    private func makeStore(
        initialState: KingdomGameState
    ) throws -> KingdomGameStore {
        let suiteName = "GameViewControllerTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let store = KingdomGameStore(defaults: defaults, key: "state")
        store.save(initialState)
        return store
    }
}
```

Add these two tests to prove scene coverage and failure separation:

```swift
@Test func normallyMountedBuildingViewUsesTheAppWideGate() throws {
    let store = try makeStore(initialState: .init(stageStatus: .battleActive))
    let controller = GameViewController(store: store)
    let view = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
    controller.view = view
    controller.viewDidLoad()
    let battle = try #require(view.scene as? BattleScene)
    controller.battleSceneDidRequestBuildingView(battle)
    #expect(view.scene is BuildingViewScene)

    view.frame.size = CGSize(width: 678, height: 834)
    controller.refreshLayoutSupportForTesting(environment: .init(
        safeAreaInsets: .init(top: 24, left: 0, bottom: 20, right: 0),
        layoutClass: .pad
    ))

    #expect(controller.layoutGateReasonForTesting == .unsupportedGeometry)
    #expect(view.isPaused)
    #expect(view.scene?.isUserInteractionEnabled == false)
}

@Test func mapUnavailableIsDistinctFromSupportedGeometry() throws {
    let store = try makeStore(initialState: .init(
        cityRemainingPower: 0,
        stageStatus: .cityConqueredPendingMap
    ))
    let controller = GameViewController(store: store)
    let view = SKView(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
    controller.view = view
    controller.viewDidLoad()
    let map = try #require(view.scene as? CountryMapScene)

    controller.countryMapScene(map, didRequestLayoutGate: .mapUnavailable)

    #expect(controller.layoutGateReasonForTesting == .mapUnavailable)
    #expect(controller.layoutGateTextForTesting == "Map unavailable")
    #expect(view.isPaused)
}
```

- [ ] **Step 2: Run controller tests and verify the expected compile failure**

Run:

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/GameViewControllerTests
```

Expected: compilation fails because the gate view, testing accessors, and
refresh method do not exist.

- [ ] **Step 3: Add the gate reason, overlay, and resume protocol**

Create `AppLayoutGateView.swift`:

```swift
import UIKit

enum AppLayoutGateReason: Equatable {
    case unsupportedGeometry
    case mapUnavailable

    var message: String {
        switch self {
        case .unsupportedGeometry:
            return "Pyxis needs a supported portrait window. Rotate or resize to continue."
        case .mapUnavailable:
            return "Map unavailable"
        }
    }
}

protocol LayoutGateResumable: AnyObject {
    func prepareForLayoutGateResume()
}

final class AppLayoutGateView: UIView {
    let messageLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.black.withAlphaComponent(0.86)
        isUserInteractionEnabled = true
        accessibilityViewIsModal = true

        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.textColor = .white
        messageLabel.font = .preferredFont(forTextStyle: .headline)
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        addSubview(messageLabel)

        NSLayoutConstraint.activate([
            messageLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            messageLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),
            messageLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            messageLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func apply(_ reason: AppLayoutGateReason) {
        messageLabel.text = reason.message
        accessibilityLabel = reason.message
    }
}
```

- [ ] **Step 4: Implement controller-owned geometry evaluation and atomic gate sequencing**

In `GameViewController`, add:

```swift
private let layoutGateView = AppLayoutGateView()
private var requestedMapGateReason: AppLayoutGateReason?
private var activeLayoutGateReason: AppLayoutGateReason?

override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    refreshLayoutSupport()
}

override func viewSafeAreaInsetsDidChange() {
    super.viewSafeAreaInsetsDidChange()
    if let mapScene = (view as? SKView)?.scene as? CountryMapScene {
        mapScene.refreshLayoutForCurrentEnvironment()
    }
    refreshLayoutSupport()
}

private func refreshLayoutSupport(
    environment override: CountryMapLayoutEnvironment? = nil
) {
    guard let skView = view as? SKView else { return }
    let environment = override ?? CountryMapLayoutUIKitAdapter.environment(for: skView)
    let layoutResult = environment.map {
        CountryMapLayout.compute(.init(
            sceneSize: skView.bounds.size,
            environment: $0,
            definition: .country1
        ))
    } ?? .unsupported(.unsupportedGeometry)

    let reason: AppLayoutGateReason?
    if requestedMapGateReason == .mapUnavailable {
        reason = .mapUnavailable
    } else {
        switch layoutResult {
        case .supported:
            reason = nil
        case .unsupported(.invalidAuthoredData):
            reason = .mapUnavailable
        case .unsupported(.unsupportedGeometry):
            reason = .unsupportedGeometry
        }
    }

    applyLayoutGate(reason, in: skView)
}
```

`applyLayoutGate` must use this ordering:

```swift
if let reason {
    skView.isPaused = true
    skView.scene?.isUserInteractionEnabled = false
    activeLayoutGateReason = reason
    layoutGateView.apply(reason)
    if layoutGateView.superview == nil {
        layoutGateView.frame = view.bounds
        layoutGateView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(layoutGateView)
    }
    return
}

if activeLayoutGateReason != nil {
    (skView.scene as? LayoutGateResumable)?.prepareForLayoutGateResume()
}
layoutGateView.removeFromSuperview()
activeLayoutGateReason = nil
skView.scene?.isUserInteractionEnabled = true
skView.isPaused = false
```

Call `refreshLayoutSupport()` after each `presentScene` so a routed scene cannot
briefly become interactive under unsupported geometry.

Expose only these DEBUG projections:

```swift
#if DEBUG
extension GameViewController {
    func refreshLayoutSupportForTesting(
        environment: CountryMapLayoutEnvironment
    ) {
        refreshLayoutSupport(environment: environment)
    }

    var isLayoutGateVisibleForTesting: Bool {
        layoutGateView.superview != nil
    }

    var layoutGateReasonForTesting: AppLayoutGateReason? {
        activeLayoutGateReason
    }

    var layoutGateTextForTesting: String? {
        layoutGateView.messageLabel.text
    }
}
#endif
```

- [ ] **Step 5: Separate missing assets from pure layout failure**

Extend `CountryMapSceneRouting`:

```swift
protocol CountryMapSceneRouting: AnyObject {
    func countryMapSceneDidRequestBattle(_ scene: CountryMapScene)
    func countryMapScene(
        _ scene: CountryMapScene,
        didRequestLayoutGate reason: AppLayoutGateReason
    )
}
```

In `CountryMapScene`, move image availability behind an internal pure seam:

```swift
static func isBackdropAvailable(
    named name: String,
    imageLoader: (String) -> UIImage?
) -> Bool {
    imageLoader(name) != nil
}
```

Test it without constructing a scene that would intentionally trip the
development assertion:

```swift
@Test func missingBackdropIsDetectedSeparatelyFromLayout() {
    #expect(!CountryMapScene.isBackdropAvailable(
        named: "country-map-backdrop",
        imageLoader: { _ in nil }
    ))
    #expect(CountryMapLayout.compute(.init(
        sceneSize: CGSize(width: 393, height: 852),
        environment: .init(
            safeAreaInsets: .init(top: 59, left: 0, bottom: 34, right: 0),
            layoutClass: .phone
        ),
        definition: .country1
    )) != .unsupported(.invalidAuthoredData))
}
```

Keep the production path:

```swift
guard Self.isBackdropAvailable(
    named: MapAssetName.countryMapBackdrop,
    imageLoader: { UIImage(named: $0) }
) else {
    assertionFailure("Missing country-map-backdrop asset")
    router?.countryMapScene(self, didRequestLayoutGate: .mapUnavailable)
    return
}
```

When the pure result is `.unsupported(.invalidAuthoredData)`, raise a
development assertion and request `.mapUnavailable`. Geometry failures do not
request a scene-specific reason because the controller already owns them.
Update `RouteSpy` with a captured `requestedGateReason`.

In `GameViewController`'s routing conformance, store the request and immediately
refresh:

```swift
func countryMapScene(
    _ scene: CountryMapScene,
    didRequestLayoutGate reason: AppLayoutGateReason
) {
    requestedMapGateReason = reason
    refreshLayoutSupport()
}
```

Set `requestedMapGateReason = nil` immediately before presenting a fresh
`CountryMapScene`; the scene may synchronously request `.mapUnavailable` again
while it builds. Do not clear the request merely because the window geometry
changes.

- [ ] **Step 6: Write and implement the BattleScene clock-reset regression**

Add this test to `BattleSceneTests`:

```swift
@Test func layoutGateResumePrimesBattleClockWithoutPausedDelta() throws {
    let scene = try makeScene()

    scene.update(10)
    #expect(scene.lastUpdateTimeForTesting == 10)

    scene.prepareForLayoutGateResume()
    #expect(scene.lastUpdateTimeForTesting == nil)

    scene.update(10_000)
    #expect(scene.lastUpdateTimeForTesting == 10_000)
    #expect(scene.lastAdvanceCombatDeltaForTesting == nil)
}
```

Track the last raw delta only for the DEBUG test projection:

```swift
private var lastAdvanceCombatDeltaForTestingStorage: TimeInterval?

func prepareForLayoutGateResume() {
    lastUpdateTime = nil
}
```

Set `lastAdvanceCombatDeltaForTestingStorage = deltaTime` at the start of
`advanceCombat(deltaTime:)` under `#if DEBUG`, expose it with
`lastUpdateTimeForTesting`, and clear it in
`prepareForLayoutGateResume()`. Conform `BattleScene` to
`LayoutGateResumable`; no other scene needs a resume hook.

- [ ] **Step 7: Run gate, map, and battle regression suites**

Run:

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/GameViewControllerTests \
  -only-testing:PyxisTests/CountryMapSceneTests \
  -only-testing:PyxisTests/BattleSceneTests
```

Expected: all three suites pass, including supported → unsupported → supported,
map-unavailable separation, state preservation, and zero paused-time combat
delta.

- [ ] **Step 8: Commit the app-wide gate**

```bash
git add Pyxis/AppLayoutGateView.swift Pyxis/GameViewController.swift Pyxis/CountryMapScene.swift Pyxis/BattleScene.swift PyxisTests/GameViewControllerTests.swift PyxisTests/CountryMapSceneTests.swift PyxisTests/BattleSceneTests.swift
git commit -m "feat: gate unsupported app layouts"
```

### Task 4: Enforce and verify the portrait orientation matrix

**Files:**
- Modify: `Pyxis/GameViewController.swift:35-41`
- Modify: `Pyxis.xcodeproj/project.pbxproj:288-345`
- Modify: `PyxisTests/GameViewControllerTests.swift`

**Interfaces:**
- Produces: `GameViewController.interfaceOrientations(for:)`
- Produces: `supportedInterfaceOrientations` and `preferredInterfaceOrientationForPresentation`
- Preserves: iPad rotation between upright and upside-down portrait

- [ ] **Step 1: Write orientation policy and generated-plist tests**

Add:

```swift
@Test func controllerOrientationPolicyMatchesApprovedMatrix() {
    #expect(GameViewController.interfaceOrientations(for: .phone) == .portrait)
    #expect(GameViewController.interfaceOrientations(for: .pad)
        == [.portrait, .portraitUpsideDown])
    #expect(GameViewController.interfaceOrientations(for: .unspecified) == .portrait)
    #expect(GameViewController().preferredInterfaceOrientationForPresentation == .portrait)
}

@Test func generatedInfoPlistMatchesApprovedOrientationMatrix() throws {
    let info = try #require(Bundle.main.infoDictionary)
    let phone = Set(try #require(
        info["UISupportedInterfaceOrientations"] as? [String]
    ))
    let pad = Set(try #require(
        info["UISupportedInterfaceOrientations~ipad"] as? [String]
    ))

    #expect(phone == ["UIInterfaceOrientationPortrait"])
    #expect(pad == [
        "UIInterfaceOrientationPortrait",
        "UIInterfaceOrientationPortraitUpsideDown"
    ])
}
```

- [ ] **Step 2: Run the controller suite and verify it fails against current masks**

Run:

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/GameViewControllerTests
```

Expected: the current controller and generated Info.plist still include
landscape.

- [ ] **Step 3: Narrow controller and project declarations**

Implement:

```swift
static func interfaceOrientations(
    for idiom: UIUserInterfaceIdiom
) -> UIInterfaceOrientationMask {
    switch idiom {
    case .pad:
        return [.portrait, .portraitUpsideDown]
    default:
        return .portrait
    }
}

override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
    Self.interfaceOrientations(for: view.traitCollection.userInterfaceIdiom)
}

override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
    .portrait
}
```

Change both Debug and Release build settings to:

```text
INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait";
INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown";
```

Do not add `UIRequiresFullScreen` or `UISceneSizeRestrictions`.

- [ ] **Step 4: Run orientation tests and inspect build settings**

Run:

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/GameViewControllerTests

xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -showBuildSettings \
  | rg 'INFOPLIST_KEY_UISupportedInterfaceOrientations'
```

Expected: tests pass; the output contains only portrait for iPhone and portrait
plus portrait-upside-down for iPad.

- [ ] **Step 5: Commit the orientation contract**

```bash
git add Pyxis/GameViewController.swift PyxisTests/GameViewControllerTests.swift Pyxis.xcodeproj/project.pbxproj
git commit -m "feat: enforce portrait orientation support"
```

### Task 5: Run whole-branch verification and record HPA-117 evidence

**Files:**
- Verify: all HPA-117 implementation files
- Update externally: Linear issue `HPA-117`

**Interfaces:**
- Consumes: all prior task deliverables
- Produces: build, lint, unit, UI, and manual-smoke evidence
- Produces: final Linear decision record without changing gameplay state

- [ ] **Step 1: Run formatting and static checks**

Run:

```bash
swiftlint lint
git diff --check
```

Expected: SwiftLint completes without new violations and `git diff --check`
prints no errors.

- [ ] **Step 2: Run all unit tests with simulator cloning disabled**

Prefer XcodeBuildMCP after checking its session defaults. Its `test_sim` call
must include:

```text
extraArgs: ["-parallel-testing-enabled", "NO", "-only-testing:PyxisTests"]
```

Fallback:

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests
```

Expected: the complete unit-test target passes.

- [ ] **Step 3: Run UI tests with simulator cloning disabled**

```bash
xcodebuild test \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisUITests
```

Expected: the complete UI-test target passes.

- [ ] **Step 4: Perform the supported-layout smoke matrix**

Check 375×667 phone and 1032×1376 iPad portrait:

```text
- Cities 1, 8, and 15 are visible and tappable.
- Every city remains centered on its illustrated pad.
- The title/current-city control and information region do not overlap the route.
- iPad upside-down portrait preserves semantic top and bottom placement.
- Returning from a gate preserves gold, city HP, buildings, and campaign status.
```

On iPad windowing, additionally check:

```text
- 480×1194 is interactive.
- 600×1000 is interactive.
- 375×1194 shows the blocking resize gate.
- 678×834 shows the blocking resize gate.
- While gated, taps do not reach SpriteKit and combat does not advance.
```

- [ ] **Step 5: Review the complete branch against the specification**

Run:

```bash
git diff origin/main...HEAD --stat
git diff origin/main...HEAD -- \
  Pyxis/CountryMapLayoutDefinition.swift \
  Pyxis/CountryMapLayout.swift \
  Pyxis/CountryMapLayoutUIKitAdapter.swift \
  Pyxis/CountryMapScene.swift \
  Pyxis/AppLayoutGateView.swift \
  Pyxis/GameViewController.swift \
  Pyxis/BattleScene.swift \
  Pyxis.xcodeproj/project.pbxproj \
  PyxisTests/CountryMapLayoutTests.swift \
  PyxisTests/CountryMapSceneTests.swift \
  PyxisTests/GameViewControllerTests.swift \
  PyxisTests/BattleSceneTests.swift
```

Confirm each specification section has a corresponding implementation and
test: orientation matrix, canonical backdrop mapping, explicit illustrated
region, safe-area adapter, persistent information region, invalid-data path,
app-wide gate, resume hook, and fixture matrix.

- [ ] **Step 6: Post the completion evidence to Linear**

Add this update to HPA-117 with the actual command results and smoke devices:

```text
Decision implemented: Option A (portrait-only) is now the app-wide layout contract.

Rejected: shared visible-region mapping, dedicated wide art, and the prior hybrid fallback.

Supported:
- iPhone: upright portrait
- iPad: upright and upside-down portrait
- Resizable windows only when the complete CountryMapLayout invariant set passes

Implementation:
- Canonical 1024×1536 Country 1 layout definition
- Pure fixture-tested layout computation
- Persistent phone/iPad information region
- App-wide blocking gate for unsupported geometry
- Battle clock reset before gate resume

Verification:
- SwiftLint: [result]
- Unit tests: [result]
- UI tests: [result]
- Manual smoke: [devices and window sizes]

Spec: docs/superpowers/specs/2026-07-26-country-map-layout-support-design.md
Plan: docs/superpowers/plans/2026-07-27-country-map-layout-support.md
```

Close HPA-117 only after all automated checks and the manual smoke matrix pass.
