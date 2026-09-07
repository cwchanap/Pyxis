# Living Kingdom Anime Asset Pack Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce the HPA-479 Living Kingdom anime-fantasy fortress, battlefield-treatment, shared-FX, living-map, and corrected-reference pack without changing shipping gameplay/runtime code.

**Architecture:** Keep art as a static human-readable contract. Four fortress families use one near-square full-canvas scaling envelope, landmark treatments reuse the shipping backdrop transform/z-order, shared FX use one explicit bottom-center anchor, and map overlays live in the existing 1024×1536 canonical source space. `docs/visual-parity/living-kingdom/README.md` is the handoff; HPA-478 later consumes the fixed names/anchors/timings/scale rules.

**Tech Stack:** Xcode asset catalogs, PNG/RGBA, existing SpriteKit geometry, image-generation/animation tooling, Pillow + Python `unittest`, macOS `sips`/`shasum`, Xcode/iOS Simulator.

**Spec:** `docs/superpowers/specs/2026-09-07-living-kingdom-art-pack-design.md`

## Global Constraints

- This is **one HPA-479 PR**. Tasks below are commits/review checkpoints in the same draft PR, not separate PRs.
- In shipping terms this remains asset-only: no Swift/runtime behavior, save data, balance, routing, project-file, CI, or Codecov changes.
- The one allowed non-doc/non-asset source addition is `tools/tests/test_living_kingdom_asset_pack.py`, a repository-side asset validator that is run manually; do not wire it into GitHub Actions in this ticket.
- Keep the PR Draft until all production assets, references, provenance, validation, and build checks are complete.
- Visual style: anime-inspired painted fantasy environment art compatible with the existing Forged UI; no troop/character redesign.
- The exact four `Pyxis_Living_Kingdom_Concept_References.zip` boards must be present and hashed before **any bulk generation**.
- New runtime art lives only in uniquely named `lk-*` image sets under `Pyxis/Assets.xcassets/`.
- Fortress sprites are transparent **512×540** PNGs. The full canvas is the runtime scaling envelope; alpha bounds are documentation only.
- Regular Forged enemy-city target height is 132 pt, yielding ≈125 pt width for 512×540. Do not reintroduce 768×512.
- Battlefield treatments are transparent **864×1821** overlays, same aspect-fill as the shipping backdrop, intended below `forgedAtmosphereNode` and lane terrain.
- FX frames are 512×512, `anchorPoint = (0.5, 0)`, impact at canvas bottom center, with fully transparent final frames.
- Country-map overlay sizes are canonical pixels. Runtime display scale is `displayedBackdropFrame.width / 1024`.
- The City 6 → City 7 repair patch stays centered at `(393.6768, 580.3776)` in canonical map space.
- City→family mapping is by city number. City 11 stays Frontier; do not derive family from `CityDefenseTrait`.
- Corrected references composite **only new art** onto real shipping/native plates. Never redraw Forged chrome or invent runtime text.
- Offline return creates no second illustration set. Positive idle damage uses the resulting fortress stage; runtime text remains `Buildings dealt N idle damage.` with no fabricated elapsed-time line.
- HPA-478 owns runtime selection/playback after this PR merges.

## File Map

### Create during production

- `docs/visual-parity/living-kingdom/source/` — four untouched concept boards plus untouched additional pre-art native plate(s) and capture provenance.
- `docs/visual-parity/living-kingdom/references/` — corrected 393×852 compositions.
- `docs/visual-parity/living-kingdom/contact-sheets/` — destruction, landmarks, map, offline, FX.
- `docs/visual-parity/living-kingdom/previews/` — breach/collapse previews.
- `Pyxis/Assets.xcassets/lk-city-*.imageset/` — 16 fortress sets.
- `Pyxis/Assets.xcassets/lk-battlefield-*.imageset/` — 3 treatment sets.
- `Pyxis/Assets.xcassets/lk-fx-*.imageset/` — 12 transition frames + 3 ambient textures.
- `Pyxis/Assets.xcassets/lk-map-*.imageset/` — 4 map overlays.
- `tools/tests/test_living_kingdom_asset_pack.py` — final inventory/dimension/alpha/catalog validator.

### Must remain untouched

- `Pyxis/*.swift`
- `PyxisTests/`
- `PyxisUITests/`
- `Pyxis.xcodeproj/project.pbxproj`
- existing non-`lk-*` image sets
- `.github/`
- `codecov.yml`

---

## Task 1: Pass the source-reference gate and confirm baseline geometry

**Files:**
- Modify: `docs/visual-parity/living-kingdom/README.md`
- Create: `docs/visual-parity/living-kingdom/source/concept-siege-destruction.png`
- Create: `docs/visual-parity/living-kingdom/source/concept-landmark-cities.png`
- Create: `docs/visual-parity/living-kingdom/source/concept-living-map.png`
- Create: `docs/visual-parity/living-kingdom/source/concept-offline-return.png`

**Produces:** A reviewable source pack plus mechanically confirmed immutable-baseline geometry. Tasks 2–6 must not start before this passes.

- [ ] **Step 1: Recover the exact four concept boards.** Extract `Pyxis_Living_Kingdom_Concept_References.zip`; map the boards by subject to the four repository names above. Copy without resizing, resampling, recompressing, or color conversion.

- [ ] **Step 2: Hash the untouched boards.** Run:

```bash
shasum -a 256 docs/visual-parity/living-kingdom/source/concept-*.png
```

Record each SHA-256 in the README.

- [ ] **Step 3: Confirm shipping canvas dimensions against the fixed baseline.** Run:

```bash
sips -g pixelWidth -g pixelHeight -g hasAlpha \
  Pyxis/Assets.xcassets/enemy-city.imageset/enemy-city.png \
  Pyxis/Assets.xcassets/battlefield-backdrop.imageset/battlefield-backdrop.png \
  Pyxis/Assets.xcassets/country-map-backdrop.imageset/country-map-backdrop.png
```

Expected baseline:

```text
enemy-city.png            1223 × 1286
battlefield-backdrop.png   864 × 1821
country-map-backdrop.png  1024 × 1536
```

If any expected dimension differs on this immutable baseline, stop and correct the spec/README before generating art. Do not silently adapt per-asset geometry later.

- [ ] **Step 4: Review the concept boards against exclusions.** In the README record that wood/stone/gems, invented city/level data, stock counters, fortification-management objectives, claim actions, and >8-hour idle credit are mood-board artifacts, not HPA-479 requirements.

- [ ] **Step 5: Lock the production prompt direction.** Reuse the README anime-fantasy brief and the exact 512×540 fortress / 864×1821 treatment / canonical-map contracts. Do not invent a separate prompt registry or generator framework.

- [ ] **Step 6: Verify the source-gate diff.** Run:

```bash
git diff --check
git diff --name-only main...HEAD
```

At this checkpoint, new production image sets are not required. Review the four hashes, source boards, exclusions, and confirmed dimensions before proceeding.

- [ ] **Step 7: Commit the gate.** Run:

```bash
git add docs/visual-parity/living-kingdom
git commit -m "docs: finalize Living Kingdom source handoff"
```

**Checkpoint A:** This is the first point where the art source contract is reviewable. Do not bulk-generate before approval of this checkpoint; do not open another PR.

---

## Task 2: Author the Frontier four-stage vertical slice

**Files:**
- Create: `Pyxis/Assets.xcassets/lk-city-frontier-{intact,damaged,breached,conquered}.imageset/`
- Create: `docs/visual-parity/living-kingdom/references/battle-frontier-{intact,damaged,breached,conquered}.png`
- Create: `docs/visual-parity/living-kingdom/contact-sheets/destruction-frontier.png`
- Modify: `docs/visual-parity/living-kingdom/README.md`

**Produces:** The approved canvas/scale/baseline/gate/damage language every later fortress family copies.

- [ ] **Step 1: Generate `lk-city-frontier-intact` only.** Use a transparent **512×540** canvas. Ground touches the bottom edge, gate center is x=256, intact structural silhouette uses most of the canvas height, and no transparent padding is used to alter apparent scale.

- [ ] **Step 2: Composite onto the exact real Battle plate.** Downsample `docs/visual-parity/forged-ui/native/battle-normal-393x852@3x.png` to logical 393×852, then replace only the enemy-city scene-art region. Do not redraw HUD, lane chrome, gold, troop counts, tabs, or text. At 132 pt target height the fortress should read around 125 pt wide and preserve lane/HP clearance.

- [ ] **Step 3: Reject geometry failures in art, not runtime.** If the intact fortress is too wide/narrow, gate misaligned, or silhouette too small because of padding, regenerate/crop within 512×540. Do not propose an HPA-478 body-rect sizing helper.

- [ ] **Step 4: Derive damaged, breached, conquered.** Preserve canvas, baseline, gate x=256, camera, lighting, and broad footprint. Every stage must make sense when jumped to directly.

- [ ] **Step 5: Create 1x-only scene-art image sets.** Each fortress `Contents.json` follows `enemy-city`: exactly one universal 1x entry with the PNG filename; no empty 2x/3x rows.

- [ ] **Step 6: Verify dimensions/alpha.** Run:

```bash
for file in Pyxis/Assets.xcassets/lk-city-frontier-*.imageset/*.png; do
  sips -g pixelWidth -g pixelHeight -g hasAlpha "$file"
done
```

Expected for every file: **512×540** and alpha.

- [ ] **Step 7: Record alpha bounds as documentation only.** Measure `(minX, minY, maxX, maxY)` in PNG coordinates and add provenance. Do not make later runtime layout depend on those bounds.

- [ ] **Step 8: Build.** Run:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: `BUILD SUCCEEDED` with no asset-catalog warnings.

- [ ] **Step 9: Commit.**

```bash
git add Pyxis/Assets.xcassets/lk-city-frontier-*.imageset \
  docs/visual-parity/living-kingdom
git commit -m "art: add Living Kingdom frontier destruction set"
```

**Checkpoint B:** Do not generate Ember/Arcane/Royal until all four Frontier stages pass phone-scale review.

---

## Task 3: Add the remaining fortress families and landmark treatments

**Files:**
- Create: `Pyxis/Assets.xcassets/lk-city-ember-*.imageset/`
- Create: `Pyxis/Assets.xcassets/lk-city-arcane-*.imageset/`
- Create: `Pyxis/Assets.xcassets/lk-city-royal-*.imageset/`
- Create: `Pyxis/Assets.xcassets/lk-battlefield-{ember,arcane,royal}.imageset/`
- Create: `docs/visual-parity/living-kingdom/references/battle-{emberford,runewatch,crownspire}.png`
- Create: `docs/visual-parity/living-kingdom/contact-sheets/landmarks.png`
- Modify: `docs/visual-parity/living-kingdom/README.md`

**Consumes:** Task 2's approved 512×540 envelope and Task 1's confirmed 864×1821 backdrop.

- [ ] **Step 1: Author Ember stages.** Preserve the Frontier geometry contract; use bridge/gate cues, oil braziers, restrained orange atmosphere for Cities 7 and 12.

- [ ] **Step 2: Author Arcane stages.** Preserve geometry; use cool ward motifs/light for Cities 9 and 13 without implying a second shield/HP system.

- [ ] **Step 3: Author Royal stages.** Crownspire may feel grander through shape/material/banner quality, but it remains inside the same 512×540 canvas and ≈125×132 pt regular display envelope.

- [ ] **Step 4: Preserve the explicit family table.** Record/verify `Frontier = 1–6, 8, 10, 11, 14`; `Ember = 7,12`; `Arcane = 9,13`; `Royal = 15`. City 11 must not become Royal because of `.reinforcedKeep`.

- [ ] **Step 5: Author three transparent 864×1821 battlefield treatments.** Use the shipping backdrop composition/crop. Paint no second fortress. Author color/value so the treatment can sit at `GameUITheme.Z.background` under the warm `forgedAtmosphereNode`; lane terrain at z=-1 remains visually dominant/readable.

- [ ] **Step 6: Create 1x-only image sets.** Twelve fortress sets + three treatment sets; exactly one universal 1x entry each.

- [ ] **Step 7: Compose landmark references onto real Battle chrome.** Use the same shipping `battle-normal` plate. Replace only new art for City 7 Emberford, City 9 Runewatch, City 15 Crownspire Keep.

- [ ] **Step 8: Verify dimensions/alpha and provenance.** All fortress PNGs are 512×540 with alpha. All three treatment PNGs are 864×1821 with alpha. Record measured bounds/tool/prompt/manual edits.

- [ ] **Step 9: Build and commit.**

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' build

git add Pyxis/Assets.xcassets/lk-city-*.imageset \
  Pyxis/Assets.xcassets/lk-battlefield-*.imageset \
  docs/visual-parity/living-kingdom
git commit -m "art: add Living Kingdom landmark families"
```

**Checkpoint C:** At phone scale the three landmarks are distinct, lanes stay readable, and treatments still look color-graded by the existing Forged atmosphere rather than pasted above it.

---

## Task 4: Add shared transition FX and ambient textures

**Files:**
- Create: `Pyxis/Assets.xcassets/lk-fx-breach-{01...06}.imageset/`
- Create: `Pyxis/Assets.xcassets/lk-fx-collapse-{01...06}.imageset/`
- Create: `Pyxis/Assets.xcassets/lk-fx-{smoke-soft,ember-specks,ward-glow}.imageset/`
- Create: `docs/visual-parity/living-kingdom/contact-sheets/fx-{breach,collapse}.png`
- Create: `docs/visual-parity/living-kingdom/previews/{breach,collapse}.gif`
- Modify: `docs/visual-parity/living-kingdom/README.md`

**Produces:** Two deterministic overlay sequences that HPA-478 can place without pixel-coordinate guessing.

- [ ] **Step 1: Author breach frames.** Six transparent 512×512 frames, impact at canvas bottom center, fixed position, dust/chips/debris only. Total 0.30 s at 0.05 s/frame.

- [ ] **Step 2: Author collapse frames.** Same anchor/impact/fixed position, total 0.42 s at 0.07 s/frame. Do not animate a replacement fortress silhouette.

- [ ] **Step 3: Make frame 06 fully transparent in both sequences.** `breached`/`conquered` static art owns the terminal appearance.

- [ ] **Step 4: Author ambient textures.** `smoke-soft` and `ember-specks` are 256×256 RGBA; `ward-glow` is 512×512 RGBA. They require only SpriteKit drift/fade/pulse later.

- [ ] **Step 5: Match catalog conventions.** Breach/collapse frame `Contents.json` mirrors soldier frames: named universal 1x + empty universal 2x/3x entries. Ambient sets are 1x-only scene art.

- [ ] **Step 6: Create contact sheets/GIFs from the production frames only.** Preview order/timing must exactly match README; no preview-only frame set.

- [ ] **Step 7: Verify alpha/registration.** Mechanically inspect dimensions/alpha; additionally verify final frame alpha max is zero and record PNG alpha bounds/provenance.

- [ ] **Step 8: Build and commit.**

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' build

git add Pyxis/Assets.xcassets/lk-fx-*.imageset \
  docs/visual-parity/living-kingdom
git commit -m "art: add Living Kingdom transition effects"
```

---

## Task 5: Add living-map overlays and truthful partial-state plate

**Files:**
- Create: `Pyxis/Assets.xcassets/lk-map-{secured-city,caravan,route-6-7-worn,route-6-7-repaired}.imageset/`
- Create: `docs/visual-parity/living-kingdom/source/native-map-city8-pre-art-393x852@3x.png`
- Create: `docs/visual-parity/living-kingdom/references/map-{early,partial,complete}.png`
- Create: `docs/visual-parity/living-kingdom/contact-sheets/map-progression.png`
- Modify: `docs/visual-parity/living-kingdom/README.md`

**Consumes:** Canonical 1024×1536 map geometry and `mapScale = displayedBackdropFrame.width / 1024`.

- [ ] **Step 1: Author `lk-map-secured-city`.** 96×96 canonical-pixel RGBA. Keep central number legible with low-alpha glow only; put the small banner away from the existing upper-right conquered marker.

- [ ] **Step 2: Author `lk-map-caravan`.** 128×64 canonical-pixel RGBA, center anchor, faces +X. It must remain visually subordinate when scaled by the backdrop transform.

- [ ] **Step 3: Author the 6→7 worn/repaired pair.** Both are 192×192 canonical-pixel RGBA, pre-oriented to 60.9888° and registered at `(393.6768, 580.3776)`. The repaired version changes bridge/road condition only.

- [ ] **Step 4: Create 1x-only map image sets.** HPA-478 later multiplies each canonical canvas by the backdrop scale; it must not treat source pixels as point sizes.

- [ ] **Step 5: Capture a truthful mid-progress shipping plate with existing DEBUG tooling.** On the same 393×852 logical simulator used by Forged parity: launch current shipping code, five-tap the top-right DEBUG jump hotspot, choose **City 8**, switch to Map, and capture the native framebuffer with `simctl io screenshot`. Do not change Swift or persisted production fixtures. Store the untouched capture plus device/runtime provenance.

- [ ] **Step 6: Compose map references without redrawing chrome.** Use:
  - early: existing `native/map-attackable-locked-393x852@3x.png`;
  - partial: new City-8 pre-art native plate, with 6→7 repair eligible;
  - complete: existing `native/map-complete-393x852@3x.png`.

Only new map-art pixels may be composited.

- [ ] **Step 7: Verify scale/readability.** At 393 pt backdrop width, 96 canonical px is roughly 37 pt and 192 canonical px roughly 74 pt. Confirm secured art does not obscure the number/conquered marker and route patches do not read as new interactive geography.

- [ ] **Step 8: Build and commit.**

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' build

git add Pyxis/Assets.xcassets/lk-map-*.imageset \
  docs/visual-parity/living-kingdom
git commit -m "art: add Living Kingdom map overlays"
```

**Checkpoint D:** Review early/partial/complete compositions and the untouched City-8 source plate. No management dashboard, fake completion state, or changed touch geometry.

---

## Task 6: Finish offline references and add the repeatable asset gate

**Files:**
- Create: `docs/visual-parity/living-kingdom/references/offline-{damage,conquest}.png`
- Create: `docs/visual-parity/living-kingdom/contact-sheets/offline-return.png`
- Create: `tools/tests/test_living_kingdom_asset_pack.py`
- Modify: `docs/visual-parity/living-kingdom/README.md`

**Consumes:** All 38 production image sets plus the real Forged native plates.

### Validation interface

`tools/tests/test_living_kingdom_asset_pack.py` is a manual repository gate. It must not require app/runtime imports or modify CI.

- [ ] **Step 1: Add the asset validator.** Use this implementation shape:

```python
from __future__ import annotations

import json
import unittest
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "Pyxis" / "Assets.xcassets"

FAMILIES = ("frontier", "ember", "arcane", "royal")
STAGES = ("intact", "damaged", "breached", "conquered")
FORTRESSES = {
    f"lk-city-{family}-{stage}": (512, 540)
    for family in FAMILIES
    for stage in STAGES
}
BATTLEFIELDS = {
    f"lk-battlefield-{family}": (864, 1821)
    for family in ("ember", "arcane", "royal")
}
FX_FRAMES = {
    **{f"lk-fx-breach-{index:02d}": (512, 512) for index in range(1, 7)},
    **{f"lk-fx-collapse-{index:02d}": (512, 512) for index in range(1, 7)},
}
AMBIENTS = {
    "lk-fx-smoke-soft": (256, 256),
    "lk-fx-ember-specks": (256, 256),
    "lk-fx-ward-glow": (512, 512),
}
MAP = {
    "lk-map-secured-city": (96, 96),
    "lk-map-caravan": (128, 64),
    "lk-map-route-6-7-worn": (192, 192),
    "lk-map-route-6-7-repaired": (192, 192),
}
EXPECTED = FORTRESSES | BATTLEFIELDS | FX_FRAMES | AMBIENTS | MAP


class LivingKingdomAssetPackTests(unittest.TestCase):
    def imageset(self, name: str) -> Path:
        return ASSETS / f"{name}.imageset"

    def test_exact_inventory(self) -> None:
        actual = {path.stem for path in ASSETS.glob("lk-*.imageset")}
        self.assertEqual(set(EXPECTED), actual)
        self.assertEqual(38, len(actual))

    def test_dimensions_and_alpha(self) -> None:
        for name, expected_size in EXPECTED.items():
            with self.subTest(name=name):
                image_path = self.imageset(name) / f"{name}.png"
                with Image.open(image_path) as image:
                    self.assertEqual(expected_size, image.size)
                    self.assertIn("A", image.getbands())
                    alpha_min, _ = image.getchannel("A").getextrema()
                    self.assertLess(alpha_min, 255)

    def test_final_transition_frames_are_fully_transparent(self) -> None:
        for name in ("lk-fx-breach-06", "lk-fx-collapse-06"):
            with Image.open(self.imageset(name) / f"{name}.png") as image:
                self.assertEqual(0, image.getchannel("A").getextrema()[1])

    def test_contents_json_matches_repo_conventions(self) -> None:
        for name in EXPECTED:
            with self.subTest(name=name):
                data = json.loads((self.imageset(name) / "Contents.json").read_text())
                images = data["images"]
                by_scale = {item["scale"]: item for item in images}
                self.assertEqual(f"{name}.png", by_scale["1x"].get("filename"))
                if name in FX_FRAMES:
                    self.assertEqual({"1x", "2x", "3x"}, set(by_scale))
                    self.assertNotIn("filename", by_scale["2x"])
                    self.assertNotIn("filename", by_scale["3x"])
                else:
                    self.assertEqual({"1x"}, set(by_scale))
```

- [ ] **Step 2: Run the Python suite.**

```bash
python3 -m unittest discover -s tools/tests
```

Expected: existing soldier-pipeline tests plus the Living Kingdom asset validator pass. This is a manual gate; do not edit `.github/workflows/ci.yml`.

- [ ] **Step 3: Compose `offline-damage.png` without fabricating chrome.** Start from the real `battle-normal` native plate and replace only fortress/art pixels with the truthful resulting damage stage. Do **not** draw an elapsed-time line or synthetic feedback panel. README records that shipping runtime copy is `Buildings dealt N idle damage.` and HPA-478 native acceptance owns the live feedback proof.

- [ ] **Step 4: Compose `offline-conquest.png`.** Start from real `conquest-idle-393x852@3x.png`; replace only underlying scene art with conquered aftermath. Keep the shipping report, values, and exactly one Continue action unchanged.

- [ ] **Step 5: Complete contact sheets/provenance.** Every final asset records dimensions, alpha treatment, measured bounds, anchor/registration, timing where applicable, intended use/scale, tool/prompt/source board, and manual edits.

- [ ] **Step 6: Verify the final allowed diff.** Run:

```bash
git diff --name-only main...HEAD
```

Every changed path must be one of:

- `Pyxis/Assets.xcassets/lk-*.imageset/**`
- `docs/visual-parity/living-kingdom/**`
- the two HPA-479 spec/plan docs
- `tools/tests/test_living_kingdom_asset_pack.py`

Any Swift, project, existing asset, CI, or Codecov change fails this gate.

- [ ] **Step 7: Run hygiene + build.**

```bash
git diff --check
python3 -m unittest discover -s tools/tests
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: no diff errors, all Python tests pass, `BUILD SUCCEEDED`.

- [ ] **Step 8: Final phone-scale review.** Confirm 512×540 fortress sizing matches the shipping envelope, stages are aligned, Emberford/Runewatch/Crownspire are distinct, treatment overlays remain under the warm Forged grade, FX origins do not drift, map overlays use source-space scale, City 11 remains Frontier, and references do not invent idle elapsed time or HUD values.

- [ ] **Step 9: Commit final acceptance artifacts.**

```bash
git add tools/tests/test_living_kingdom_asset_pack.py \
  docs/visual-parity/living-kingdom
git commit -m "test: validate Living Kingdom asset pack"
```

- [ ] **Step 10: Mark the existing PR ready only after all gates pass.** Do not open another PR. HPA-478 starts runtime consumption only after this HPA-479 asset contract merges.