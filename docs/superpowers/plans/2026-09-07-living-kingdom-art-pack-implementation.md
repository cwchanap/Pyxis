# Living Kingdom Anime Asset Pack Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce the HPA-479 Living Kingdom anime-fantasy fortress, battlefield-treatment, transition-FX, living-map, and corrected-reference pack with CI-protected asset geometry and reproducible DEBUG capture tooling, without changing shipping gameplay/runtime behavior.

**Architecture:** Keep the art contract static and concrete. Four fortress families share one canvas plus alpha-envelope gate; three battlefield overlays reuse the shipping backdrop transform at a fixed fractional z-position; two short transition sequences share the fortress pixel scale; four map overlays use the existing 1024×1536 source space. Reuse existing asset-catalog writing, Swift asset tests, and `ForgedVisualFixture` instead of adding parallel infrastructure.

**Tech Stack:** Xcode asset catalogs, PNG/RGBA, Swift 5, SpriteKit/UIKit test tooling, Swift Testing, XCTest UI tests, existing `tools/slice_soldier_animation_strips.py` catalog writer, Xcode/iOS Simulator.

**Spec:** `docs/superpowers/specs/2026-09-07-living-kingdom-art-pack-design.md`

## Global Constraints

- One HPA-479 PR. Tasks below are commits/checkpoints, never separate PRs.
- Final runtime inventory: **35 image sets** = 16 fortress + 3 battlefield + 12 transition frames + 4 map.
- Do not author the three ambient smoke/ember/ward textures; HPA-478 has no concrete consumer.
- The four original concept boards are optional documentation inputs, not a blocker. The written anime-fantasy/geometry contract is sufficient to proceed.
- Keep the four-family city-number mapping exact; City 11 stays Frontier.
- Fortress canvas is 512×540; alpha-envelope checks are acceptance, not runtime layout metadata.
- Battlefield treatment z-position for HPA-478 is `GameUITheme.Z.background + 0.5`.
- FX display size uses the fortress pixel scale; never render 512 source pixels as 512 points.
- Map art uses canonical source pixels and `displayedBackdropFrame.width / 1024`.
- Use the existing `write_contents_json` helper for **all** new image sets.
- Validation lives in the existing CI-run Swift test suite; do not add a manual Python validator or change CI.
- HPA-479 may modify only DEBUG capture tooling and test files in Swift. No non-DEBUG shipping scene/model/save/routing/balance behavior changes.
- Do not edit `project.pbxproj`, existing production assets, `.github/`, or `codecov.yml`.
- Keep PR Draft until all production assets/references and final gates pass.

## Risks

1. **Apparent fortress width drift.** Matching canvas aspect ratio alone is insufficient because `fitBattleNode` scales the full transparent canvas. Mitigation: alpha-envelope test lands with Frontier before the other 12 fortress assets.
2. **Unavailable concept ZIP.** Mood boards are not authoritative and may never surface. Mitigation: production continues from the written anime/Forged contract; recovered boards are hashed documentation only.
3. **Overlay ordering ambiguity.** Same-z sibling order is not a contract. Mitigation: HPA-478 handoff pins treatment z to `background + 0.5`.
4. **Capture drift.** Manual five-tap setup is not reproducible evidence. Mitigation: extend the existing DEBUG fixture with `map-partial` and its unit/UI semantic checks.

## File Map

### Production assets/docs created during this PR

- `Pyxis/Assets.xcassets/lk-city-*.imageset/` — 16 fortress sets
- `Pyxis/Assets.xcassets/lk-battlefield-*.imageset/` — 3 treatment sets
- `Pyxis/Assets.xcassets/lk-fx-{breach,collapse}-*.imageset/` — 12 transition sets
- `Pyxis/Assets.xcassets/lk-map-*.imageset/` — 4 map sets
- `docs/visual-parity/living-kingdom/{source,references,contact-sheets,previews}/` — **local-only, gitignored** (see note below)

> **Local-only visual-parity artifacts.** `docs/visual-parity/` is ignored by
> `.gitignore` because the Living Kingdom handoff/reference/contact-sheet PNGs are
> large (tens of MB) and exist for local visual parity only. These paths are **not
> committed**; the `git add docs/visual-parity/living-kingdom` steps below are
> intentional no-ops kept as a local-build marker. Nothing under
> `docs/visual-parity/living-kingdom/**` should appear in the tracked diff.

### Test/DEBUG support modified during this PR

- `PyxisTests/BattleSceneTests.swift` — continuous asset contract
- `Pyxis/ForgedVisualFixture.swift` — DEBUG `map-partial` case
- `PyxisTests/ForgedVisualFixtureTests.swift` — parser/state coverage
- `PyxisUITests/PyxisUITests.swift` — 393×852 fixture capture + semantic value

### Must remain untouched

- non-DEBUG shipping behavior in `Pyxis/*.swift`
- models/persistence/balance/routing
- existing non-`lk-*` assets
- `Pyxis.xcodeproj/project.pbxproj`
- `.github/`, `codecov.yml`

---

## Task 1: Verify the shipping geometry and establish source provenance

**Files:**
- Modify: `docs/visual-parity/living-kingdom/README.md`
- Optional create: `docs/visual-parity/living-kingdom/source/concept-*.png`
- Optional create: `docs/visual-parity/living-kingdom/source/README.md`

**Produces:** Measured shipping dimensions/bounds and a non-blocking source-reference record.

- [ ] **Step 1: Verify baseline dimensions.**

```bash
sips -g pixelWidth -g pixelHeight -g hasAlpha \
  Pyxis/Assets.xcassets/enemy-city.imageset/enemy-city.png \
  Pyxis/Assets.xcassets/battlefield-backdrop.imageset/battlefield-backdrop.png \
  Pyxis/Assets.xcassets/country-map-backdrop.imageset/country-map-backdrop.png
```

Expected baseline: enemy city 1223×1286; battlefield 864×1821; country map 1024×1536.

- [ ] **Step 2: Measure the shipping city alpha box before authoring.**

```bash
python3 - <<'PY'
from PIL import Image
p = "Pyxis/Assets.xcassets/enemy-city.imageset/enemy-city.png"
with Image.open(p).convert("RGBA") as image:
    print("size=", image.size)
    print("alpha_bbox=", image.getchannel("A").getbbox())
PY
```

Expected approximately `(155, 23, 1070, 1258)` on the 1223×1286 baseline. If the checked-in source differs materially, update the spec's alpha-envelope bands **before** Task 2; do not generate around stale numbers.

- [ ] **Step 3: Handle concept boards without blocking production.**

If the exact ZIP is available, copy the four PNGs unchanged and hash them:

```bash
shasum -a 256 docs/visual-parity/living-kingdom/source/concept-*.png
```

If the ZIP is unavailable, create `source/README.md` stating that the original boards were unavailable and production uses the approved written anime-fantasy brief plus Forged native plates. Do not wait for the ZIP.

- [ ] **Step 4: Record the measured baseline and source status in the handoff README.** No runtime asset is created in this task.

- [ ] **Step 5: Verify and commit.**

```bash
git diff --check
git diff --name-only main...HEAD
# docs/visual-parity/living-kingdom is local-only (gitignored); nothing to commit here.
git commit --allow-empty -m "docs: finalize Living Kingdom production baseline"
```

---

## Task 2: Author Frontier first and land the CI asset contract

**Files:**
- Create: `Pyxis/Assets.xcassets/lk-city-frontier-{intact,damaged,breached,conquered}.imageset/`
- Create: `docs/visual-parity/living-kingdom/references/battle-frontier-{intact,damaged,breached,conquered}.png`
- Create: `docs/visual-parity/living-kingdom/contact-sheets/destruction-frontier.png`
- Modify: `PyxisTests/BattleSceneTests.swift`
- Modify: `docs/visual-parity/living-kingdom/README.md`

**Produces:** The four-stage quality gate and a CI test that later tasks extend.

- [ ] **Step 1: Extend the existing pixel-bounds helper to 2D.** Change the private test-only structure to:

```swift
private struct PixelBounds {
    let minX: Int
    let minY: Int
    let maxXExclusive: Int
    let maxYExclusive: Int

    var width: Int { maxXExclusive - minX }
    var height: Int { maxYExclusive - minY }
}
```

Update `opaquePixelBounds(in:)` so its existing alpha scan tracks min/max Y as well as X. Preserve existing `infantryAttackFramesKeepMotionInsideCanvasInset` behavior.

- [ ] **Step 2: Write the Frontier asset-contract test before adding the files.** Add beside `allSoldierAnimationFramesAreInstalled`:

```swift
@Test("Living Kingdom fortress assets match the shipping display envelope")
func livingKingdomFrontierAssetsMatchContract() throws {
    for stage in ["intact", "damaged", "breached", "conquered"] {
        let name = "lk-city-frontier-\(stage)"
        let image = try #require(UIImage(named: name))
        let cgImage = try #require(image.cgImage)
        let bounds = try #require(opaquePixelBounds(in: image))

        #expect(cgImage.width == 512)
        #expect(cgImage.height == 540)

        let widthRatio = Double(bounds.width) / 512.0
        let heightRatio = Double(bounds.height) / 540.0
        let bottomGapRatio = Double(540 - bounds.maxYExclusive) / 540.0
        let center = Double(bounds.minX + bounds.maxXExclusive) / 2.0

        #expect((0.72...0.80).contains(widthRatio))
        #expect((0.94...0.98).contains(heightRatio))
        #expect((0.015...0.030).contains(bottomGapRatio))
        #expect(abs(center - 256.0) <= 10.24)
        if stage == "intact" {
            #expect(widthRatio <= 0.78)
        }
    }
}
```

Expected RED: missing `lk-city-frontier-*` assets.

- [ ] **Step 3: Author only `lk-city-frontier-intact` first.** 512×540 RGBA, centered gate, target alpha envelope from the spec. Composite it onto the real 393×852 Battle plate and reject it if it reads materially wider than the shipping city.

- [ ] **Step 4: Derive damaged/breached/conquered from the approved intact source.** Keep camera, center, baseline gap, tower positions, and footprint stable.

- [ ] **Step 5: Create all four image sets using the existing catalog writer.**

```bash
python3 - <<'PY'
import sys
from pathlib import Path
sys.path.insert(0, "tools")
from slice_soldier_animation_strips import write_contents_json

root = Path("Pyxis/Assets.xcassets")
for stage in ("intact", "damaged", "breached", "conquered"):
    name = f"lk-city-frontier-{stage}"
    write_contents_json(root / f"{name}.imageset", f"{name}.png")
PY
```

The image-set directories/PNGs must already exist before this command.

- [ ] **Step 6: Run the CI-shaped focused test.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/BattleSceneTests/livingKingdomFrontierAssetsMatchContract
```

Expected GREEN: all four assets resolve, dimensions match, alpha envelope passes.

- [ ] **Step 7: Record measured bounds/provenance and create the Frontier contact sheet/reference files.** Bounds are acceptance evidence, not HPA-478 layout input.

- [ ] **Step 8: Build and commit.**

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build

git add Pyxis/Assets.xcassets/lk-city-frontier-*.imageset \
  PyxisTests/BattleSceneTests.swift
git commit -m "art: add Living Kingdom frontier destruction set"
```

**Checkpoint B:** Do not author the remaining 12 fortress assets until this gate passes.

---

## Task 3: Add Ember, Arcane, Royal, and battlefield treatments

**Files:**
- Create: `Pyxis/Assets.xcassets/lk-city-{ember,arcane,royal}-*.imageset/`
- Create: `Pyxis/Assets.xcassets/lk-battlefield-{ember,arcane,royal}.imageset/`
- Create: landmark references/contact sheet
- Modify: `PyxisTests/BattleSceneTests.swift`
- Modify: `docs/visual-parity/living-kingdom/README.md`

- [ ] **Step 1: Extend the existing Living Kingdom asset test table to all 16 fortress names before authoring.** Apply the same 512×540 + alpha-envelope assertions to every family/stage.

- [ ] **Step 2: Add dimension/presence expectations for the three battlefield treatments:**

```swift
for name in ["lk-battlefield-ember", "lk-battlefield-arcane", "lk-battlefield-royal"] {
    let image = try #require(UIImage(named: name))
    let cgImage = try #require(image.cgImage)
    #expect(cgImage.width == 864)
    #expect(cgImage.height == 1821)
}
```

Expected RED until the new files land.

- [ ] **Step 3: Author the Ember family.** Cities 7/12; bridge/gate/oil-brazier identity; no gameplay fire mechanic.

- [ ] **Step 4: Author the Arcane family.** Cities 9/13; cyan/blue ward motifs; no shield/second-HP reading.

- [ ] **Step 5: Author the Royal family.** City 15 only; grander materials/banners but same alpha envelope.

- [ ] **Step 6: Author three 864×1821 transparent treatments.** Compose for runtime z `GameUITheme.Z.background + 0.5`, beneath the warm Forged atmosphere and lane terrain. Paint no second fortress.

- [ ] **Step 7: Generate all 15 Contents.json files with the same existing `write_contents_json` helper.** Do not hand-author a second JSON shape.

- [ ] **Step 8: Compose real-plate landmark references for Emberford, Runewatch, Crownspire; record bounds/provenance.**

- [ ] **Step 9: Run focused/full unit gates and build, then commit.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO -only-testing:PyxisTests/BattleSceneTests

xcodebuild -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build

git add Pyxis/Assets.xcassets/lk-city-*.imageset \
  Pyxis/Assets.xcassets/lk-battlefield-*.imageset \
  PyxisTests/BattleSceneTests.swift
git commit -m "art: add Living Kingdom landmark families"
```

---

## Task 4: Add only the two required transition sequences

**Files:**
- Create: `Pyxis/Assets.xcassets/lk-fx-breach-{01...06}.imageset/`
- Create: `Pyxis/Assets.xcassets/lk-fx-collapse-{01...06}.imageset/`
- Create: FX contact sheets/previews
- Modify: `PyxisTests/BattleSceneTests.swift`
- Modify: `docs/visual-parity/living-kingdom/README.md`

- [ ] **Step 1: Extend the CI asset table with all 12 FX names and 512×512 dimensions.** Also add terminal transparency checks:

```swift
for name in ["lk-fx-breach-06", "lk-fx-collapse-06"] {
    let image = try #require(UIImage(named: name))
    #expect(opaquePixelBounds(in: image) == nil)
}
```

Expected RED until the sequence assets land.

- [ ] **Step 2: Author breach frames.** Fixed 512×512 canvas, bottom-center `(0.5, 0)` impact, no positional drift, frame 06 fully transparent, 0.05 s/frame.

- [ ] **Step 3: Author collapse frames.** Same registration, frame 06 fully transparent, 0.07 s/frame.

- [ ] **Step 4: Review at the actual display transform.** For regular Battle:

```text
fortressScale = 132 / 540
fxDisplayHeight = 512 × fortressScale ≈ 125 pt
```

Reject any effect that requires native 512 pt display or obscures the battlefield.

- [ ] **Step 5: Generate all 12 Contents.json files with the same helper; make previews/contact sheets from the production frames.**

- [ ] **Step 6: Run `BattleSceneTests`, build, record timing/provenance, and commit.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO -only-testing:PyxisTests/BattleSceneTests

git add Pyxis/Assets.xcassets/lk-fx-*.imageset \
  PyxisTests/BattleSceneTests.swift
git commit -m "art: add Living Kingdom transition effects"
```

---

## Task 5: Add map overlays and a reproducible partial-map fixture

**Files:**
- Create: `Pyxis/Assets.xcassets/lk-map-{secured-city,caravan,route-6-7-worn,route-6-7-repaired}.imageset/`
- Modify: `Pyxis/ForgedVisualFixture.swift`
- Modify: `PyxisTests/ForgedVisualFixtureTests.swift`
- Modify: `PyxisUITests/PyxisUITests.swift`
- Modify: `PyxisTests/BattleSceneTests.swift`
- Create: `docs/visual-parity/living-kingdom/source/native-map-partial-393x852@3x.png`
- Create: map references/contact sheet
- Modify: handoff README

- [ ] **Step 1: Add RED fixture parser/state tests.** Extend the exact parser list with `("map-partial", .mapPartial)`. Extend map-state coverage with:

```swift
let partial = ForgedVisualFixture.mapPartial.makeState()
#expect(partial.countryNumber == 1)
#expect(partial.cityNumberInCountry == 8)
#expect(partial.completedCityCount == 7)
#expect(partial.stageStatus == .cityConqueredPendingMap)
#expect(partial.pendingBattleResult == nil)
```

This is the **pre-round-trip seed** asserted directly against `makeState()`. The captured app state is normalized: `installForgedVisualFixtureIfRequested` saves then reloads the fixture, and `KingdomGameState.init` clamps `cityConqueredPendingMap` to `completedCityCount = max(completedCityCount, cityNumberInCountry) = max(7, 8) = 8`. The post-normalization values (completed=8, attackableCity=9) are asserted in the UI smoke in Step 3, not here.

- [ ] **Step 2: Add the DEBUG fixture case.** In `ForgedVisualFixture`:

```swift
case mapPartial = "map-partial"
```

Include it in `.map` preferred-tab routing. In `makeState()`:

```swift
case .mapPartial:
    var state = DevJumpState.make(city: 8)
    state.stageStatus = .cityConqueredPendingMap
    return state
```

This yields seven completed cities without a manual five-tap sequence.

- [ ] **Step 3: Extend the existing 393×852 UI smoke.** Add `"map-partial"` to the fixture list and semantic switch:

```swift
case "map-partial":
    expected = "Map;stage=cityConqueredPendingMap;completed=8;"
        + "attackableCity=9;laterLockedCity=10"
```

These are the post-normalization values: the fixture is saved then reloaded, and `KingdomGameState.init` clamps `cityConqueredPendingMap` City 8 to `completedCityCount = 8`, so city 9 is the unlock and city 10 the next lock. This must match the shipping semantic string emitted by the fixture after the round trip.

If the controller's actual semantic string differs, use the shipping semantic value emitted by the fixture and update this exact expectation before capture; do not fabricate a string.

- [ ] **Step 4: Run fixture tests before map art.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/ForgedVisualFixtureTests
```

- [ ] **Step 5: Author the four map assets in canonical source pixels.**

- secured city: 96×96;
- caravan: 128×64, faces +X;
- worn/repaired: both 192×192, centered at `(393.6768, 580.3776)`, lower-left→upper-right.

The worn asset is retained as the explicit before state required by HPA-479.

- [ ] **Step 6: Extend the CI asset contract with the four map names/dimensions and generate all four Contents.json files with the same helper.**

- [ ] **Step 7: Capture the native partial plate using the new fixture.** On the same logical 393×852 simulator:

```bash
xcrun simctl io booted screenshot \
  docs/visual-parity/living-kingdom/source/native-map-partial-393x852@3x.png
```

Launch the app beforehand with `-pyxis-forged-fixture map-partial`; use the existing fixture capture flow rather than manual gameplay setup. Record device/runtime provenance.

- [ ] **Step 8: Compose map early/partial/complete references only on real plates.** Partial uses the new untouched source plate; repaired 6→7 is eligible because the normalized captured state has `completed=8`, so city 7 has been conquered and the 6→7 route is in its repaired state.

- [ ] **Step 9: Run unit/UI/build gates and commit.**

```bash
xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests/ForgedVisualFixtureTests \
  -only-testing:PyxisTests/BattleSceneTests \
  -only-testing:PyxisUITests/testForgedFixtureParitySmoke393x852

git add Pyxis/Assets.xcassets/lk-map-*.imageset \
  Pyxis/ForgedVisualFixture.swift \
  PyxisTests/ForgedVisualFixtureTests.swift \
  PyxisTests/BattleSceneTests.swift \
  PyxisUITests/PyxisUITests.swift
git commit -m "art: add Living Kingdom map overlays and fixture"
```

---

## Task 6: Finish offline references and final acceptance

**Files:**
- Create: `docs/visual-parity/living-kingdom/references/offline-{damage,conquest}.png`
- Create: `docs/visual-parity/living-kingdom/contact-sheets/offline-return.png`
- Modify: `docs/visual-parity/living-kingdom/README.md`

**Consumes:** All 35 production image sets and real Forged native plates.

- [ ] **Step 1: Compose `offline-damage.png` from the real Battle plate.** Replace scene-art pixels only. Do not synthesize elapsed-time UI or rewrite feedback chrome. When documenting the expected shipping wording, use formatted copy such as `Buildings dealt 1.2K idle damage.` rather than a raw integer example.

- [ ] **Step 2: Compose `offline-conquest.png` from `conquest-idle-393x852@3x.png`.** Replace underlying fortress/art only; preserve report values and the single Continue action.

- [ ] **Step 3: Complete the handoff inventory/provenance.** Every asset batch records names, dimensions, measured bounds where relevant, anchor/registration, timing/display rule, tool/prompt/source status, and manual edits.

- [ ] **Step 4: Verify exact final inventory.**

```bash
find Pyxis/Assets.xcassets -maxdepth 1 -type d -name 'lk-*.imageset' -print | sort
```

Expected: **35** image sets.

- [ ] **Step 5: Verify the allowed diff.**

```bash
git diff --name-only main...HEAD
```

Allowed paths only:

- `Pyxis/Assets.xcassets/lk-*.imageset/**`
- the HPA-479 spec/plan docs
- `PyxisTests/BattleSceneTests.swift`
- `Pyxis/ForgedVisualFixture.swift`
- `PyxisTests/ForgedVisualFixtureTests.swift`
- `PyxisUITests/PyxisUITests.swift`

`docs/visual-parity/living-kingdom/**` is local-only and gitignored, so it must
**not** appear in the tracked diff. Any other Swift/project/CI/existing-asset
change fails the gate.

- [ ] **Step 6: Run final hygiene, unit, UI, and build gates.**

```bash
git diff --check

xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisTests

xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO \
  -only-testing:PyxisUITests

xcodebuild -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

Expected: no diff errors, unit/UI suites pass, BUILD SUCCEEDED.

- [ ] **Step 7: Final visual review at logical 393×852.** Confirm apparent fortress width, stage continuity, landmark identity, treatment grade/z intent, FX scale/origin, map scale/labels, and truthful offline compositions.

- [ ] **Step 8: Commit final reference/provenance updates.**

```bash
# docs/visual-parity/living-kingdom is local-only (gitignored); nothing to commit here.
git commit --allow-empty -m "docs: finalize Living Kingdom visual handoff"
```

- [ ] **Step 9: Mark the existing PR ready only after every gate passes.** HPA-478 starts shipping integration only after HPA-479 merges.