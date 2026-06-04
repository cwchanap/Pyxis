# Building UI Enhancement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the Building View from a uniform 5x5 board into a scenic countryside city-builder layout with generated building art, construction pads, level badges, and dimmed locked future building icons.

**Architecture:** Keep the existing `KingdomGameState` and `CityBattleState` rules unchanged. Add presentation asset helpers to `BuildingType`, then refactor `BuildingViewScene` so it renders a backdrop, authored slot containers, pad sprites, building sprites, level badges, and icon-based build palette buttons while preserving current slot IDs and button names.

**Tech Stack:** Swift 5, SpriteKit, UIKit, Swift Testing, Xcode asset catalogs, built-in `image_gen` with local chroma-key removal for transparent sprite assets.

---

## Source Spec

- Design spec: `docs/superpowers/specs/2026-06-04-building-ui-enhancement-design.md`

## File Structure

- Modify: `Pyxis/CityBuildingState.swift`
  - Add presentation-only asset-name helpers to `BuildingType`.
- Modify: `Pyxis/BuildingViewScene.swift`
  - Replace visible grid-cell shape rendering with scenic slot container rendering.
  - Add backdrop sprite, slot pad sprites, building sprites, level badges, selection outlines, and icon-based palette buttons.
  - Keep existing build, upgrade, feedback, lifecycle, and routing behavior.
- Modify: `Pyxis/GameUITheme.swift`
  - Add small presentation constants for scenic building slots and locked icon opacity if it keeps scene code clearer.
- Modify: `PyxisTests/BuildingViewSceneTests.swift`
  - Replace shape-fill expectations with asset-name and opacity expectations.
  - Add tests for authored scenic slot positions, pad assets, building sprite assets, palette icons, locked dimming, and level badges.
- Create asset catalog folders under `Pyxis/Assets.xcassets/`:
  - `building-view-countryside-backdrop.imageset`
  - `building-pad-empty.imageset`
  - `building-barracks.imageset`
  - `building-archery-range.imageset`
  - `building-stable.imageset`
  - `building-mage-tower.imageset`
  - `building-siege-workshop.imageset`

Do not edit `Pyxis.xcodeproj/project.pbxproj`; this repository uses synchronized root groups.

## Verification Commands

Use the simulator available locally. This repo has previously verified reliably with iPhone 17:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests/BuildingViewSceneTests
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test
```

If iPhone 17 is unavailable, run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -showdestinations
```

and substitute a listed iOS Simulator destination.

---

### Task 1: Add Presentation Asset Helpers

**Files:**
- Modify: `Pyxis/CityBuildingState.swift`
- Modify: `PyxisTests/BuildingViewSceneTests.swift`

- [ ] **Step 1: Write failing asset-helper tests**

Add these tests near the existing Building View affordance tests in `PyxisTests/BuildingViewSceneTests.swift`:

```swift
@Test func buildingTypesExposeBuildingSpriteAssetNames() {
    #expect(BuildingType.barracks.buildingAssetName == "building-barracks")
    #expect(BuildingType.archeryRange.buildingAssetName == "building-archery-range")
    #expect(BuildingType.stable.buildingAssetName == "building-stable")
    #expect(BuildingType.mageTower.buildingAssetName == "building-mage-tower")
    #expect(BuildingType.siegeWorkshop.buildingAssetName == "building-siege-workshop")
}

@Test func buildingTypesExposePaletteIconAssetNames() {
    for type in BuildingType.allCases {
        #expect(type.paletteIconAssetName == type.buildingAssetName)
    }
}
```

- [ ] **Step 2: Run the focused test and verify it fails**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests/BuildingViewSceneTests/buildingTypesExposeBuildingSpriteAssetNames -only-testing:PyxisTests/BuildingViewSceneTests/buildingTypesExposePaletteIconAssetNames
```

Expected: FAIL because `buildingAssetName` and `paletteIconAssetName` do not exist.

- [ ] **Step 3: Add the asset helpers**

In `Pyxis/CityBuildingState.swift`, add these properties inside `enum BuildingType`, after `shortDisplayName` and before `soldierType`:

```swift
    var buildingAssetName: String {
        switch self {
        case .barracks:
            return "building-barracks"
        case .archeryRange:
            return "building-archery-range"
        case .stable:
            return "building-stable"
        case .mageTower:
            return "building-mage-tower"
        case .siegeWorkshop:
            return "building-siege-workshop"
        }
    }

    var paletteIconAssetName: String {
        buildingAssetName
    }
```

- [ ] **Step 4: Run the focused tests and verify they pass**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests/BuildingViewSceneTests/buildingTypesExposeBuildingSpriteAssetNames -only-testing:PyxisTests/BuildingViewSceneTests/buildingTypesExposePaletteIconAssetNames
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Pyxis/CityBuildingState.swift PyxisTests/BuildingViewSceneTests.swift
git commit -m "Add building presentation asset names"
```

---

### Task 2: Generate And Add Building View Art Assets

**Files:**
- Create: `Pyxis/Assets.xcassets/building-view-countryside-backdrop.imageset/Contents.json`
- Create: `Pyxis/Assets.xcassets/building-view-countryside-backdrop.imageset/building-view-countryside-backdrop.png`
- Create: `Pyxis/Assets.xcassets/building-pad-empty.imageset/Contents.json`
- Create: `Pyxis/Assets.xcassets/building-pad-empty.imageset/building-pad-empty.png`
- Create: `Pyxis/Assets.xcassets/building-barracks.imageset/Contents.json`
- Create: `Pyxis/Assets.xcassets/building-barracks.imageset/building-barracks.png`
- Create: `Pyxis/Assets.xcassets/building-archery-range.imageset/Contents.json`
- Create: `Pyxis/Assets.xcassets/building-archery-range.imageset/building-archery-range.png`
- Create: `Pyxis/Assets.xcassets/building-stable.imageset/Contents.json`
- Create: `Pyxis/Assets.xcassets/building-stable.imageset/building-stable.png`
- Create: `Pyxis/Assets.xcassets/building-mage-tower.imageset/Contents.json`
- Create: `Pyxis/Assets.xcassets/building-mage-tower.imageset/building-mage-tower.png`
- Create: `Pyxis/Assets.xcassets/building-siege-workshop.imageset/Contents.json`
- Create: `Pyxis/Assets.xcassets/building-siege-workshop.imageset/building-siege-workshop.png`

- [ ] **Step 1: Use the imagegen skill for project-bound raster assets**

Before calling the image generator, load the imagegen skill and follow its built-in path. Use built-in `image_gen` for the images. For transparent sprite assets, generate on a flat chroma-key background, then copy the selected tool-reported PNG into `/private/tmp/pyxis-imagegen/source.png` and remove the key locally. For the empty pad, use:

```bash
mkdir -p /private/tmp/pyxis-imagegen
GENERATED_SOURCE=/private/tmp/pyxis-imagegen/source.png
FINAL_ASSET=/Users/chanwaichan/workspace/Pyxis/Pyxis/Assets.xcassets/building-pad-empty.imageset/building-pad-empty.png
python "${CODEX_HOME:-$HOME/.codex}/skills/.system/imagegen/scripts/remove_chroma_key.py" \
  --input "$GENERATED_SOURCE" \
  --out "$FINAL_ASSET" \
  --auto-key border \
  --soft-matte \
  --transparent-threshold 12 \
  --opaque-threshold 220 \
  --despill
```

For each building sprite, set `FINAL_ASSET` to one of these absolute paths, copy that sprite's selected generated PNG to `/private/tmp/pyxis-imagegen/source.png`, and rerun the same command:

```bash
FINAL_ASSET=/Users/chanwaichan/workspace/Pyxis/Pyxis/Assets.xcassets/building-barracks.imageset/building-barracks.png
FINAL_ASSET=/Users/chanwaichan/workspace/Pyxis/Pyxis/Assets.xcassets/building-archery-range.imageset/building-archery-range.png
FINAL_ASSET=/Users/chanwaichan/workspace/Pyxis/Pyxis/Assets.xcassets/building-stable.imageset/building-stable.png
FINAL_ASSET=/Users/chanwaichan/workspace/Pyxis/Pyxis/Assets.xcassets/building-mage-tower.imageset/building-mage-tower.png
FINAL_ASSET=/Users/chanwaichan/workspace/Pyxis/Pyxis/Assets.xcassets/building-siege-workshop.imageset/building-siege-workshop.png
```

Expected: final building and pad PNGs have transparent corners and no visible key-color fringe. The backdrop does not need transparency.

- [ ] **Step 2: Generate the countryside backdrop**

Use this exact prompt with `image_gen`:

```text
Use case: stylized-concept
Asset type: iOS SpriteKit game background for a city-building management screen
Primary request: Create a polished countryside settlement backdrop for an idle kingdom game building view.
Scene/backdrop: lush green countryside with winding dirt roads, small clearings, scattered trees, shrubs, and gentle terrain variation; no finished barracks, archery range, stable, mage tower, or siege workshop already placed.
Subject: an empty settlement build area with enough visual room for 25 future building pads to be placed by the game.
Style/medium: colorful hand-painted mobile game illustration, three-quarter top-down perspective, clean readable shapes, fantasy kingdom tone.
Composition/framing: full-screen background, important details away from extreme edges, open space in the central and lower-middle area, roads forming natural clusters.
Lighting/mood: bright daytime, warm and inviting, readable contrast for UI overlays.
Color palette: greens, earth browns, soft stone gray accents, restrained warm highlights.
Constraints: no text, no UI, no characters, no watermarks, no existing main building types baked into the image.
Avoid: dark vignette, heavy blur, realistic photo style, empty flat grass field, dense forest blocking build areas.
```

Move the selected generated file into:

```text
Pyxis/Assets.xcassets/building-view-countryside-backdrop.imageset/building-view-countryside-backdrop.png
```

- [ ] **Step 3: Generate the empty building pad**

Use this exact prompt with `image_gen`:

```text
Use case: stylized-concept
Asset type: transparent SpriteKit construction pad sprite
Primary request: Create an empty build pad for a fantasy countryside city-builder game.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background for background removal.
Subject: oval dirt-and-stone construction pad with a few small stakes and packed earth, no building on it.
Style/medium: colorful hand-painted mobile game sprite, three-quarter top-down perspective, clean readable silhouette.
Composition/framing: centered sprite, generous padding, no crop, no cast shadow.
Lighting/mood: bright daytime lighting matching a cheerful kingdom game.
Color palette: earth browns, muted stone grays, small beige highlights.
Constraints: background must be one uniform #00ff00 with no gradients, texture, shadows, reflections, or lighting variation; do not use #00ff00 anywhere in the subject; no text, no watermark.
Avoid: grass background, square tile border, building parts, character tools, photorealism.
```

Remove the chroma key and save the final transparent PNG to:

```text
Pyxis/Assets.xcassets/building-pad-empty.imageset/building-pad-empty.png
```

- [ ] **Step 4: Generate the five building sprites**

Use these exact prompts, one built-in `image_gen` call per asset. For each result, remove the chroma key and save the final transparent PNG to the matching imageset path.

Barracks:

```text
Use case: stylized-concept
Asset type: transparent SpriteKit building sprite
Primary request: Create a barracks building for a fantasy idle kingdom city-builder game.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background for background removal.
Subject: sturdy wooden-and-stone barracks with red cloth banners, training-yard feel, compact footprint.
Style/medium: colorful hand-painted mobile game sprite, three-quarter top-down perspective, clean readable silhouette.
Composition/framing: centered building, generous padding, no crop, no cast shadow.
Lighting/mood: bright daytime lighting consistent with a cheerful countryside kingdom.
Color palette: warm wood browns, stone gray, muted red banners.
Constraints: background must be one uniform #00ff00 with no gradients, texture, shadows, reflections, or lighting variation; do not use #00ff00 anywhere in the subject; no text, no watermark.
Avoid: modern military base, huge castle, characters, weapons floating outside the building, photorealism.
```

Save to:

```text
Pyxis/Assets.xcassets/building-barracks.imageset/building-barracks.png
```

Archery Range:

```text
Use case: stylized-concept
Asset type: transparent SpriteKit building sprite
Primary request: Create an archery range building for a fantasy idle kingdom city-builder game.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background for background removal.
Subject: small timber archery range with covered shooting stand, target boards, and simple teal cloth accents.
Style/medium: colorful hand-painted mobile game sprite, three-quarter top-down perspective, clean readable silhouette.
Composition/framing: centered building, generous padding, no crop, no cast shadow.
Lighting/mood: bright daytime lighting consistent with a cheerful countryside kingdom.
Color palette: warm wood browns, straw tan, teal cloth, target red accents.
Constraints: background must be one uniform #00ff00 with no gradients, texture, shadows, reflections, or lighting variation; do not use #00ff00 anywhere in the subject; no text, no watermark.
Avoid: modern shooting range, characters, loose arrows cluttering the whole image, photorealism.
```

Save to:

```text
Pyxis/Assets.xcassets/building-archery-range.imageset/building-archery-range.png
```

Stable:

```text
Use case: stylized-concept
Asset type: transparent SpriteKit building sprite
Primary request: Create a stable building for a fantasy idle kingdom city-builder game.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background for background removal.
Subject: compact countryside stable with timber walls, hay roof, small fenced side pen, and warm lantern detail.
Style/medium: colorful hand-painted mobile game sprite, three-quarter top-down perspective, clean readable silhouette.
Composition/framing: centered building, generous padding, no crop, no cast shadow.
Lighting/mood: bright daytime lighting consistent with a cheerful countryside kingdom.
Color palette: wood browns, hay yellow, soft cream highlights, small warm accents.
Constraints: background must be one uniform #00ff00 with no gradients, texture, shadows, reflections, or lighting variation; do not use #00ff00 anywhere in the subject; no text, no watermark.
Avoid: visible horses, large barn complex, modern farm equipment, photorealism.
```

Save to:

```text
Pyxis/Assets.xcassets/building-stable.imageset/building-stable.png
```

Mage Tower:

```text
Use case: stylized-concept
Asset type: transparent SpriteKit building sprite
Primary request: Create a mage tower building for a fantasy idle kingdom city-builder game.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background for background removal.
Subject: compact stone mage tower with a violet roof, small glowing crystal, arched doorway, and magical but friendly silhouette.
Style/medium: colorful hand-painted mobile game sprite, three-quarter top-down perspective, clean readable silhouette.
Composition/framing: centered building, generous padding, no crop, no cast shadow.
Lighting/mood: bright daytime lighting with a subtle magical accent, not dark.
Color palette: stone gray, violet roof, soft cyan crystal glow, warm trim.
Constraints: background must be one uniform #00ff00 with no gradients, texture, shadows, reflections, or lighting variation; do not use #00ff00 anywhere in the subject; no text, no watermark.
Avoid: ominous dark tower, giant castle spire, characters, smoke, photorealism.
```

Save to:

```text
Pyxis/Assets.xcassets/building-mage-tower.imageset/building-mage-tower.png
```

Siege Workshop:

```text
Use case: stylized-concept
Asset type: transparent SpriteKit building sprite
Primary request: Create a siege workshop building for a fantasy idle kingdom city-builder game.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background for background removal.
Subject: sturdy workshop shed with stone base, timber frame, small covered work area, gears, beams, and a compact unfinished siege engine detail.
Style/medium: colorful hand-painted mobile game sprite, three-quarter top-down perspective, clean readable silhouette.
Composition/framing: centered building, generous padding, no crop, no cast shadow.
Lighting/mood: bright daytime lighting consistent with a cheerful countryside kingdom.
Color palette: dark wood, stone gray, bronze metal accents, muted canvas.
Constraints: background must be one uniform #00ff00 with no gradients, texture, shadows, reflections, or lighting variation; do not use #00ff00 anywhere in the subject; no text, no watermark.
Avoid: modern factory, huge catapult dominating the sprite, characters, smoke, photorealism.
```

Save to:

```text
Pyxis/Assets.xcassets/building-siege-workshop.imageset/building-siege-workshop.png
```

- [ ] **Step 5: Add asset catalog contents**

For each imageset, create `Contents.json` using this structure and replace both filename occurrences with that asset's PNG filename:

```json
{
  "images" : [
    {
      "filename" : "building-barracks.png",
      "idiom" : "universal",
      "scale" : "1x"
    },
    {
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "idiom" : "universal",
      "scale" : "3x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

Expected: every new `.imageset` has one PNG file and one `Contents.json`; no project file changes are made.

- [ ] **Step 6: Build once to verify assets are accepted**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: PASS. If the build fails with a simulator destination error, run `xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -showdestinations` and retry with an available simulator.

- [ ] **Step 7: Commit**

```bash
git add Pyxis/Assets.xcassets
git commit -m "Add building view art assets"
```

---

### Task 3: Refactor Slots Into Scenic Sprite Containers

**Files:**
- Modify: `Pyxis/BuildingViewScene.swift`
- Modify: `PyxisTests/BuildingViewSceneTests.swift`

- [ ] **Step 1: Write failing scenic slot tests**

Add these tests to `PyxisTests/BuildingViewSceneTests.swift`:

```swift
@Test func scenicLayoutUsesAuthoredNonGridSlotPositions() throws {
    let store = try makeStore(initialState: KingdomGameState(gold: 100))
    let scene = makeScene(store: store, router: RouteSpy())
    let centers = scene.slotCenterPointsForTesting

    #expect(centers.count == 25)

    let roundedXValues = Set(centers.values.map { Int(($0.x / 4).rounded()) })
    let roundedYValues = Set(centers.values.map { Int(($0.y / 4).rounded()) })

    #expect(roundedXValues.count > 5)
    #expect(roundedYValues.count > 5)
}

@Test func emptySlotsUsePadAssetAndNoBuildingAsset() throws {
    let store = try makeStore(initialState: KingdomGameState(gold: 100))
    let scene = makeScene(store: store, router: RouteSpy())

    #expect(scene.backdropAssetNameForTesting == "building-view-countryside-backdrop")
    #expect(scene.slotPadAssetNameForTesting(1) == "building-pad-empty")
    #expect(scene.slotBuildingAssetNameForTesting(1) == nil)
    #expect(scene.slotLevelTextForTesting(1) == nil)
}

@Test func occupiedSlotsUseBuildingAssetAndLevelBadge() throws {
    var initial = KingdomGameState(gold: 200, cityNumberInCountry: 11, completedCityCount: 10)
    #expect(initial.buildBuilding(.mageTower, inSlot: 7) == .built(cost: 40, remainingGold: 160))
    #expect(initial.upgradeBuilding(inSlot: 7) == .upgraded(cost: 30, newLevel: 2, remainingGold: 130))
    let store = try makeStore(initialState: initial)
    let scene = makeScene(store: store, router: RouteSpy())

    #expect(scene.slotPadAssetNameForTesting(7) == "building-pad-empty")
    #expect(scene.slotBuildingAssetNameForTesting(7) == "building-mage-tower")
    #expect(scene.slotLevelTextForTesting(7) == "Lv 2")
}
```

Replace the existing `newBuildingTypesUseReadableSlotLabelsAndColors` test with:

```swift
@Test func newBuildingTypesUseReadableSlotLabelsAndAssets() throws {
    let store = try makeStore(
        initialState: KingdomGameState(gold: 500, cityNumberInCountry: 11, completedCityCount: 10)
    )
    let scene = makeScene(store: store, router: RouteSpy())

    scene.selectSlotForTesting(1)
    scene.buildSelectedSlotForTesting(.stable)
    scene.selectSlotForTesting(2)
    scene.buildSelectedSlotForTesting(.mageTower)
    scene.selectSlotForTesting(3)
    scene.buildSelectedSlotForTesting(.siegeWorkshop)

    #expect(scene.slotTextForTesting(1)?.contains("Stable") == true)
    #expect(scene.slotTextForTesting(2)?.contains("Mage Tower") == true)
    #expect(scene.slotTextForTesting(3)?.contains("Siege Workshop") == true)
    #expect(scene.slotBuildingAssetNameForTesting(1) == "building-stable")
    #expect(scene.slotBuildingAssetNameForTesting(2) == "building-mage-tower")
    #expect(scene.slotBuildingAssetNameForTesting(3) == "building-siege-workshop")
}
```

- [ ] **Step 2: Run the focused tests and verify failure**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests/BuildingViewSceneTests/scenicLayoutUsesAuthoredNonGridSlotPositions -only-testing:PyxisTests/BuildingViewSceneTests/emptySlotsUsePadAssetAndNoBuildingAsset -only-testing:PyxisTests/BuildingViewSceneTests/occupiedSlotsUseBuildingAssetAndLevelBadge -only-testing:PyxisTests/BuildingViewSceneTests/newBuildingTypesUseReadableSlotLabelsAndAssets
```

Expected: FAIL because the debug helpers, backdrop, scenic positions, pad sprites, building sprites, and level badges do not exist.

- [ ] **Step 3: Replace slot and backdrop data structures**

In `Pyxis/BuildingViewScene.swift`, add the new asset and slot/layout structures near the top of `BuildingViewScene`. Leave the existing `BuildButtonBundle` unchanged until Task 4.

```swift
    private enum AssetName {
        static let backdrop = "building-view-countryside-backdrop"
        static let emptyPad = "building-pad-empty"
    }

    private struct SlotNodeBundle {
        let container: SKNode
        let hitArea: SKShapeNode
        let padSprite: SKSpriteNode
        let buildingSprite: SKSpriteNode
        let selectionOutline: SKShapeNode
        let levelBadge: SKShapeNode
        let levelLabel: SKLabelNode
        let label: SKLabelNode
        let padAssetName: String
        var buildingAssetName: String?
    }

    private struct ScenicSlotLayout {
        let slot: Int
        let x: CGFloat
        let y: CGFloat
        let scale: CGFloat
    }

    private static let scenicSlotLayouts: [ScenicSlotLayout] = [
        ScenicSlotLayout(slot: 1, x: 0.18, y: 0.78, scale: 0.96),
        ScenicSlotLayout(slot: 2, x: 0.34, y: 0.82, scale: 0.90),
        ScenicSlotLayout(slot: 3, x: 0.52, y: 0.78, scale: 0.98),
        ScenicSlotLayout(slot: 4, x: 0.70, y: 0.82, scale: 0.90),
        ScenicSlotLayout(slot: 5, x: 0.84, y: 0.72, scale: 0.88),
        ScenicSlotLayout(slot: 6, x: 0.24, y: 0.64, scale: 1.02),
        ScenicSlotLayout(slot: 7, x: 0.43, y: 0.66, scale: 0.94),
        ScenicSlotLayout(slot: 8, x: 0.62, y: 0.62, scale: 1.02),
        ScenicSlotLayout(slot: 9, x: 0.78, y: 0.56, scale: 0.92),
        ScenicSlotLayout(slot: 10, x: 0.13, y: 0.49, scale: 0.86),
        ScenicSlotLayout(slot: 11, x: 0.31, y: 0.50, scale: 1.02),
        ScenicSlotLayout(slot: 12, x: 0.51, y: 0.48, scale: 1.10),
        ScenicSlotLayout(slot: 13, x: 0.68, y: 0.43, scale: 0.98),
        ScenicSlotLayout(slot: 14, x: 0.87, y: 0.42, scale: 0.86),
        ScenicSlotLayout(slot: 15, x: 0.20, y: 0.34, scale: 0.94),
        ScenicSlotLayout(slot: 16, x: 0.39, y: 0.32, scale: 1.06),
        ScenicSlotLayout(slot: 17, x: 0.58, y: 0.31, scale: 0.96),
        ScenicSlotLayout(slot: 18, x: 0.76, y: 0.27, scale: 0.94),
        ScenicSlotLayout(slot: 19, x: 0.10, y: 0.19, scale: 0.82),
        ScenicSlotLayout(slot: 20, x: 0.28, y: 0.17, scale: 0.94),
        ScenicSlotLayout(slot: 21, x: 0.46, y: 0.15, scale: 1.02),
        ScenicSlotLayout(slot: 22, x: 0.64, y: 0.13, scale: 0.94),
        ScenicSlotLayout(slot: 23, x: 0.82, y: 0.14, scale: 0.84),
        ScenicSlotLayout(slot: 24, x: 0.56, y: 0.88, scale: 0.86),
        ScenicSlotLayout(slot: 25, x: 0.90, y: 0.62, scale: 0.80)
    ]
```

Replace these properties:

```swift
    private let gridLayer = SKNode()
    private var slotNodes: [Int: SKShapeNode] = [:]
    private var slotLabels: [Int: SKLabelNode] = [:]
```

with:

```swift
    private let backdropNode = SKSpriteNode(imageNamed: AssetName.backdrop)
    private let gridLayer = SKNode()
    private var slotNodes: [Int: SlotNodeBundle] = [:]
```

- [ ] **Step 4: Build scenic slot nodes**

In `buildInterface()`, after setting panel z positions, configure the backdrop and add it before the grid layer:

```swift
        backdropNode.name = AssetName.backdrop
        backdropNode.zPosition = GameUITheme.Z.background
        addChild(backdropNode)
```

Replace the current `for slot in CityBattleState.slotRange` loop with:

```swift
        for slot in CityBattleState.slotRange {
            let container = SKNode()
            container.name = "\(SlotName.prefix)\(slot)"

            let hitArea = SKShapeNode()
            hitArea.name = container.name
            hitArea.fillColor = .clear
            hitArea.strokeColor = .clear

            let padSprite = SKSpriteNode(imageNamed: AssetName.emptyPad)
            padSprite.name = container.name
            padSprite.alpha = 0.78
            padSprite.zPosition = 0

            let buildingSprite = SKSpriteNode()
            buildingSprite.name = container.name
            buildingSprite.zPosition = 2

            let selectionOutline = SKShapeNode()
            selectionOutline.name = container.name
            selectionOutline.fillColor = .clear
            selectionOutline.strokeColor = GameUITheme.Color.gold
            selectionOutline.lineWidth = 3
            selectionOutline.alpha = 0
            selectionOutline.zPosition = 3

            let levelBadge = SKShapeNode()
            levelBadge.name = container.name
            levelBadge.fillColor = SKColor(red: 0.07, green: 0.10, blue: 0.13, alpha: 0.92)
            levelBadge.strokeColor = GameUITheme.Color.gold
            levelBadge.lineWidth = 1
            levelBadge.zPosition = 4

            let levelLabel = SKLabelNode(fontNamed: GameUITheme.Font.bold)
            levelLabel.name = container.name
            levelLabel.fontSize = 10
            levelLabel.fontColor = GameUITheme.Color.textPrimary
            levelLabel.horizontalAlignmentMode = .center
            levelLabel.verticalAlignmentMode = .center
            levelLabel.zPosition = 5
            levelBadge.addChild(levelLabel)

            let label = SKLabelNode(fontNamed: GameUITheme.Font.medium)
            label.name = container.name
            label.fontSize = 10
            label.fontColor = GameUITheme.Color.textPrimary
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            label.zPosition = 5

            container.addChild(hitArea)
            container.addChild(padSprite)
            container.addChild(buildingSprite)
            container.addChild(selectionOutline)
            container.addChild(levelBadge)
            container.addChild(label)
            gridLayer.addChild(container)

            slotNodes[slot] = SlotNodeBundle(
                container: container,
                hitArea: hitArea,
                padSprite: padSprite,
                buildingSprite: buildingSprite,
                selectionOutline: selectionOutline,
                levelBadge: levelBadge,
                levelLabel: levelLabel,
                label: label,
                padAssetName: AssetName.emptyPad,
                buildingAssetName: nil
            )
        }
```

- [ ] **Step 5: Layout backdrop and scenic slot containers**

In `layoutInterface()`, after computing `gridTop`, `gridBottom`, `gridHeight`, add:

```swift
        let backdropScale = max(size.width / max(backdropNode.size.width, 1), size.height / max(backdropNode.size.height, 1))
        backdropNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        backdropNode.setScale(backdropScale)
```

Replace the grid slot-size calculation and slot layout loop with:

```swift
        let slotArea = CGRect(
            x: horizontalMargin,
            y: gridBottom,
            width: contentWidth,
            height: gridHeight
        )
        let baseSlotSize = max(34, min(slotArea.width * 0.16, slotArea.height * 0.22, 82))

        for layout in Self.scenicSlotLayouts {
            guard var bundle = slotNodes[layout.slot] else {
                continue
            }

            let slotSize = baseSlotSize * layout.scale
            let x = slotArea.minX + slotArea.width * layout.x
            let y = slotArea.minY + slotArea.height * layout.y

            bundle.container.position = CGPoint(x: x, y: y)
            bundle.hitArea.path = CGPath(
                ellipseIn: CGRect(x: -slotSize / 2, y: -slotSize / 2, width: slotSize, height: slotSize),
                transform: nil
            )
            bundle.padSprite.size = CGSize(width: slotSize * 1.08, height: slotSize * 0.72)
            bundle.buildingSprite.size = CGSize(width: slotSize * 1.16, height: slotSize * 1.16)
            bundle.buildingSprite.position = CGPoint(x: 0, y: slotSize * 0.12)
            bundle.selectionOutline.path = CGPath(
                ellipseIn: CGRect(x: -slotSize * 0.62, y: -slotSize * 0.42, width: slotSize * 1.24, height: slotSize * 0.84),
                transform: nil
            )
            bundle.levelBadge.path = CGPath(
                roundedRect: CGRect(x: -18, y: -9, width: 36, height: 18),
                cornerWidth: 6,
                cornerHeight: 6,
                transform: nil
            )
            bundle.levelBadge.position = CGPoint(x: slotSize * 0.34, y: -slotSize * 0.24)
            bundle.label.position = CGPoint(x: 0, y: -slotSize * 0.50)
            bundle.label.fontSize = slotSize < 48 ? 8 : 10
            slotNodes[layout.slot] = bundle
        }
```

Keep the existing panel, button, label fitting, and `layoutFrames` update. `gridFrameForSlots()` should continue to work after Task 3 Step 8 updates it to read container frames.

- [ ] **Step 6: Redraw scenic slots**

Replace `redrawSlot(_:)` with:

```swift
    private func redrawSlot(_ slot: Int) {
        guard var bundle = slotNodes[slot] else {
            return
        }

        if let building = state.cityBattleStateForCurrentCity.building(inSlot: slot) {
            bundle.label.text = building.type.shortDisplayName
            bundle.buildingSprite.texture = SKTexture(imageNamed: building.type.buildingAssetName)
            bundle.buildingSprite.alpha = 1
            bundle.levelLabel.text = "Lv \(building.level)"
            bundle.levelBadge.alpha = 1
            bundle.buildingAssetName = building.type.buildingAssetName
        } else {
            bundle.label.text = "Lot \(slot)"
            bundle.buildingSprite.texture = nil
            bundle.buildingSprite.alpha = 0
            bundle.levelLabel.text = nil
            bundle.levelBadge.alpha = 0
            bundle.buildingAssetName = nil
        }

        bundle.padSprite.alpha = selectedSlot == slot ? 1.0 : 0.78
        bundle.selectionOutline.alpha = selectedSlot == slot ? 1.0 : 0
        slotNodes[slot] = bundle
    }
```

- [ ] **Step 7: Update scene frame helpers for container nodes**

Update `gridFrameForSlots()` to use containers:

```swift
    private func gridFrameForSlots() -> CGRect {
        slotNodes.values
            .compactMap { sceneFrame(for: $0.container) }
            .reduce(nil) { partialFrame, frame in
                partialFrame?.union(frame) ?? frame
            } ?? .zero
    }
```

- [ ] **Step 8: Add test helpers**

In the `#if DEBUG` extension in `Pyxis/BuildingViewScene.swift`, replace `slotNodeCountForTesting`, `slotTextForTesting`, and `slotFillColorForTesting` with helpers that work with `SlotNodeBundle`. Keep the old names where existing tests still call them:

```swift
    var slotNodeCountForTesting: Int {
        slotNodes.count
    }

    var backdropAssetNameForTesting: String {
        AssetName.backdrop
    }

    var slotCenterPointsForTesting: [Int: CGPoint] {
        Dictionary(uniqueKeysWithValues: slotNodes.map { slot, bundle in
            (slot, bundle.container.position)
        })
    }

    func slotTextForTesting(_ slot: Int) -> String? {
        slotNodes[slot]?.label.text
    }

    func slotPadAssetNameForTesting(_ slot: Int) -> String? {
        slotNodes[slot]?.padAssetName
    }

    func slotBuildingAssetNameForTesting(_ slot: Int) -> String? {
        slotNodes[slot]?.buildingAssetName
    }

    func slotLevelTextForTesting(_ slot: Int) -> String? {
        slotNodes[slot]?.levelLabel.text
    }
```

Remove the old `slotFillColorForTesting` helper after rewriting tests that used it.

- [ ] **Step 9: Run the focused tests and verify they pass**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests/BuildingViewSceneTests/scenicLayoutUsesAuthoredNonGridSlotPositions -only-testing:PyxisTests/BuildingViewSceneTests/emptySlotsUsePadAssetAndNoBuildingAsset -only-testing:PyxisTests/BuildingViewSceneTests/occupiedSlotsUseBuildingAssetAndLevelBadge -only-testing:PyxisTests/BuildingViewSceneTests/newBuildingTypesUseReadableSlotLabelsAndAssets
```

Expected: PASS.

- [ ] **Step 10: Commit**

```bash
git add Pyxis/BuildingViewScene.swift PyxisTests/BuildingViewSceneTests.swift
git commit -m "Render scenic building view slots"
```

---

### Task 4: Convert Build Palette To Icon Buttons With Locked Dimming

**Files:**
- Modify: `Pyxis/BuildingViewScene.swift`
- Modify: `Pyxis/GameUITheme.swift`
- Modify: `PyxisTests/BuildingViewSceneTests.swift`

- [ ] **Step 1: Write failing palette icon tests**

Add these tests to `PyxisTests/BuildingViewSceneTests.swift`:

```swift
@Test func buildPaletteShowsAllBuildingIconAssets() throws {
    let store = try makeStore(
        initialState: KingdomGameState(gold: 500, cityNumberInCountry: 11, completedCityCount: 10)
    )
    let scene = makeScene(store: store, router: RouteSpy())

    #expect(scene.buildButtonIconAssetNamesForTesting == [
        .barracks: "building-barracks",
        .archeryRange: "building-archery-range",
        .stable: "building-stable",
        .mageTower: "building-mage-tower",
        .siegeWorkshop: "building-siege-workshop"
    ])
}

@Test func lockedFutureBuildingIconsAreDimmedAndShowUnlockCity() throws {
    let store = try makeStore(
        initialState: KingdomGameState(gold: 500, cityNumberInCountry: 5, completedCityCount: 4)
    )
    let scene = makeScene(store: store, router: RouteSpy())

    #expect(scene.buildButtonTextsForTesting == [
        "Build Barracks",
        "Build Archery",
        "Build Stable",
        "Mage City 8",
        "Siege City 11"
    ])
    #expect(scene.buildButtonIconAlphaForTesting(.barracks) == 1.0)
    #expect(scene.buildButtonIconAlphaForTesting(.archeryRange) == 1.0)
    #expect(scene.buildButtonIconAlphaForTesting(.stable) == 1.0)
    #expect(scene.buildButtonIconAlphaForTesting(.mageTower) == 0.35)
    #expect(scene.buildButtonIconAlphaForTesting(.siegeWorkshop) == 0.35)
}

@Test func unaffordableUnlockedBuildingIconsRemainVisibleButSubdued() throws {
    let store = try makeStore(
        initialState: KingdomGameState(gold: 0, cityNumberInCountry: 11, completedCityCount: 10)
    )
    let scene = makeScene(store: store, router: RouteSpy())

    scene.selectSlotForTesting(1)

    #expect(scene.buildButtonIconAlphaForTesting(.barracks) == 0.65)
    #expect(scene.buildButtonIconAlphaForTesting(.siegeWorkshop) == 0.65)
}
```

- [ ] **Step 2: Run palette tests and verify failure**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests/BuildingViewSceneTests/buildPaletteShowsAllBuildingIconAssets -only-testing:PyxisTests/BuildingViewSceneTests/lockedFutureBuildingIconsAreDimmedAndShowUnlockCity -only-testing:PyxisTests/BuildingViewSceneTests/unaffordableUnlockedBuildingIconsRemainVisibleButSubdued
```

Expected: FAIL because `BuildButtonBundle` has no icon helpers and redraw does not set icon alpha.

- [ ] **Step 3: Add icon opacity constants**

In `Pyxis/GameUITheme.swift`, add this enum inside `GameUITheme` after `Color`:

```swift
    enum Alpha {
        static let enabledIcon: CGFloat = 1.0
        static let unaffordableIcon: CGFloat = 0.65
        static let lockedIcon: CGFloat = 0.35
    }
```

- [ ] **Step 4: Create icon-based button bundles**

Replace `BuildButtonBundle` in `Pyxis/BuildingViewScene.swift` with:

```swift
    private struct BuildButtonBundle {
        let button: SKNode
        let background: SKShapeNode
        let icon: SKSpriteNode
        let label: SKLabelNode
        let assetName: String
    }
```

In the `buildInterface()` loop for `BuildingType.allCases`, update the bundle creation to include an icon:

```swift
            let bundle = BuildButtonBundle(
                button: SKNode(),
                background: SKShapeNode(),
                icon: SKSpriteNode(imageNamed: type.paletteIconAssetName),
                label: SKLabelNode(fontNamed: GameUITheme.Font.bold),
                assetName: type.paletteIconAssetName
            )
```

Update `configureButton` to accept the icon:

```swift
    private func configureButton(
        _ button: SKNode,
        background: SKShapeNode,
        icon: SKSpriteNode? = nil,
        label: SKLabelNode,
        name: String,
        color: SKColor
    ) {
        button.name = name
        background.name = name
        background.fillColor = color
        background.strokeColor = SKColor(white: 1.0, alpha: 0.22)
        background.lineWidth = 2

        icon?.name = name
        icon?.zPosition = 1

        label.name = name
        label.fontSize = 15
        label.fontColor = GameUITheme.Color.textPrimary
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.zPosition = 2

        button.addChild(background)
        if let icon {
            button.addChild(icon)
        }
        button.addChild(label)
    }
```

Update the build-button call site:

```swift
            configureButton(
                bundle.button,
                background: bundle.background,
                icon: bundle.icon,
                label: bundle.label,
                name: buttonName(for: type),
                color: buildColor(for: type)
            )
```

Keep the upgrade and battle button call sites valid by relying on `icon: nil`.

- [ ] **Step 5: Layout icons inside build buttons**

In `layoutInterface()`, inside the `for (index, type) in BuildingType.allCases.enumerated()` loop after `layoutButton(...)`, add:

```swift
            let iconSize = min(buttonHeight * 0.82, buildButtonWidth * 0.24)
            bundle.icon.size = CGSize(width: iconSize, height: iconSize)
            bundle.icon.position = CGPoint(x: -buildButtonWidth / 2 + iconSize * 0.72, y: 0)
            bundle.label.position = CGPoint(x: iconSize * 0.36, y: 0)
            fitLabel(bundle.label, maxWidth: buildButtonWidth - iconSize - 16)
```

Remove the later `buildButtonBundles.values.forEach { fitLabel($0.label, maxWidth: buildButtonWidth - 12) }` call or change it to:

```swift
        buildButtonBundles.values.forEach { bundle in
            fitLabel(bundle.label, maxWidth: buildButtonWidth - min(buttonHeight * 0.82, buildButtonWidth * 0.24) - 16)
        }
```

- [ ] **Step 6: Redraw icon alpha for enabled, locked, and unaffordable states**

In the `redraw()` loop for `BuildingType.allCases`, replace the button fill assignment with:

```swift
            let unlocked = state.isBuildingTypeUnlocked(type)
            if unlocked {
                bundle.label.text = "Build \(type.shortDisplayName)"
            } else {
                bundle.label.text = "\(type.shortDisplayName) City \(KingdomGameState.unlockCity(for: type))"
            }

            let buildable = canBuild(type)
            bundle.background.fillColor = buildable
                ? buildColor(for: type)
                : GameUITheme.Color.upgradeUnavailable
            if !unlocked {
                bundle.icon.alpha = GameUITheme.Alpha.lockedIcon
            } else if buildable {
                bundle.icon.alpha = GameUITheme.Alpha.enabledIcon
            } else {
                bundle.icon.alpha = GameUITheme.Alpha.unaffordableIcon
            }
```

- [ ] **Step 7: Add palette test helpers**

In the `#if DEBUG` extension in `Pyxis/BuildingViewScene.swift`, add:

```swift
    var buildButtonIconAssetNamesForTesting: [BuildingType: String] {
        Dictionary(uniqueKeysWithValues: buildButtonBundles.map { type, bundle in
            (type, bundle.assetName)
        })
    }

    func buildButtonIconAlphaForTesting(_ type: BuildingType) -> CGFloat? {
        buildButtonBundles[type]?.icon.alpha
    }
```

- [ ] **Step 8: Run palette tests and existing affordance tests**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests/BuildingViewSceneTests/selectingEmptySlotExposesUnlockedAndLockedBuildActions -only-testing:PyxisTests/BuildingViewSceneTests/buildPaletteShowsAllBuildingIconAssets -only-testing:PyxisTests/BuildingViewSceneTests/lockedFutureBuildingIconsAreDimmedAndShowUnlockCity -only-testing:PyxisTests/BuildingViewSceneTests/unaffordableUnlockedBuildingIconsRemainVisibleButSubdued
```

Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add Pyxis/BuildingViewScene.swift Pyxis/GameUITheme.swift PyxisTests/BuildingViewSceneTests.swift
git commit -m "Add icon building palette states"
```

---

### Task 5: Verify Layout, Existing Behavior, And Full Suite

**Files:**
- Modify: `Pyxis/BuildingViewScene.swift`
- Modify: `PyxisTests/BuildingViewSceneTests.swift`

- [ ] **Step 1: Update layout tests for scenic slot frames**

Keep `compactLandscapeLayoutKeepsGridBetweenPanelsAndAwayFromButtons` and `shortLandscapeLayoutKeepsGridBetweenPanelsAndAwayFromButtons`, but make their expectations refer to `frames.grid` as the scenic slot area union. The existing assertions remain valid:

```swift
#expect(frames.scene.contains(frames.titlePanel))
#expect(frames.scene.contains(frames.actionPanel))
#expect(frames.scene.contains(frames.grid))
#expect(frames.grid.maxY < frames.titlePanel.minY)
#expect(frames.grid.minY > frames.actionPanel.maxY)
```

If building sprites make `frames.grid` too tall in short landscape, reduce `baseSlotSize` in `layoutInterface()` from:

```swift
let baseSlotSize = max(34, min(slotArea.width * 0.16, slotArea.height * 0.22, 82))
```

to:

```swift
let baseSlotSize = max(30, min(slotArea.width * 0.15, slotArea.height * 0.19, 76))
```

- [ ] **Step 2: Run the whole Building View test file**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test -only-testing:PyxisTests/BuildingViewSceneTests
```

Expected: PASS. If an existing test fails because it still expects `slotFillColorForTesting`, rewrite that assertion to check `slotBuildingAssetNameForTesting` or `slotPadAssetNameForTesting` instead.

- [ ] **Step 3: Run the full test suite**

Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test
```

Expected: PASS.

- [ ] **Step 4: Optional lint hygiene check**

Run:

```bash
swiftlint lint --quiet --no-cache
```

Expected: The command may report pre-existing warnings in this repo. Fix new warnings introduced by the Building UI enhancement; do not broaden the change to unrelated files.

- [ ] **Step 5: Inspect final diff**

Run:

```bash
git diff --stat
git diff -- Pyxis/BuildingViewScene.swift Pyxis/CityBuildingState.swift Pyxis/GameUITheme.swift PyxisTests/BuildingViewSceneTests.swift
find Pyxis/Assets.xcassets -maxdepth 2 -name 'building-*.png' -o -name 'Contents.json'
```

Expected:

- Code changes are limited to Building View presentation helpers, scene rendering, UI theme constants, and focused tests.
- New asset imagesets are under `Pyxis/Assets.xcassets`.
- `Pyxis.xcodeproj/project.pbxproj` is unchanged.

- [ ] **Step 6: Commit**

```bash
git add Pyxis/BuildingViewScene.swift Pyxis/CityBuildingState.swift Pyxis/GameUITheme.swift PyxisTests/BuildingViewSceneTests.swift Pyxis/Assets.xcassets
git commit -m "Finish building view scenic UI"
```
