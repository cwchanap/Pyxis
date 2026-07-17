# Task 5 Report: Infantry RED Tests And Canonical Approval Gate

## Scope

Completed Task 5 Step 1 and Step 2 only. No production manifest, production
asset, storyboard, staging, or commit work was performed.

## Step 1: RED Test Evidence

Both suites ran through XcodeBuildMCP against the `Pyxis` scheme on `iPhone 17`
with `-parallel-testing-enabled NO` and isolated DerivedData at
`/private/tmp/pyxis-task5-derived-data`.

### SoldierAnimationManifestTests

Selector: `-only-testing:PyxisTests/SoldierAnimationManifestTests`

- Discovered: 2 tests
- Result: 1 passed, 1 failed
- Expected RED assertions: 4
- Failure boundary: infantry walk, attack, and hit are not authored, and
  infantry does not use full-canvas rendering.

### BattleSceneTests

Selector: `-only-testing:PyxisTests/BattleSceneTests`

- Discovered: 120 tests
- Result: 116 passed, 4 failed
- Expected RED expectations: 39
- Failure boundary: all ten infantry attack and hit textures still alias their
  matching walk textures; infantry still layers procedural attack and hit
  feedback; infantry still uses the legacy `(0.25, 0.0, 0.5, 0.57)` crop for
  walk, attack, and hit instead of the full canvas.

The failures are assertion failures at the intended staged-approval boundary,
not compilation errors or empty test selectors.

## Step 2: Canonical Infantry Reference

### Source Images

- Identity and equipment source:
  `Pyxis/Assets.xcassets/infantry-walk-01.imageset/infantry-walk-01.png`
  (`128 x 128` PNG)
- Approved render-quality source:
  `/private/tmp/pyxis-full-animation/archer-canonical.png`
  (`1254 x 1254` PNG)

The infantry source controlled identity and equipment semantics. The archer
source controlled rendering detail, outline weight, material treatment,
lighting, and compact chibi proportions only.

### Canonical Generation Prompt

```text
Use case: stylized-concept
Asset type: canonical character reference for a mobile-game sprite animation pipeline
Input images: Image 1 is the authoritative infantry identity and equipment reference; Image 2 is the approved archer reference for rendering quality, detail, outline weight, materials, lighting, and compact chibi proportions only. Do not borrow Image 2's clothing, bow, quiver, cape, hood, or green palette.
Primary request: Create one complete neutral infantry reference on a perfectly flat solid #00ff00 background. Preserve the recognizable blue-plumed helmet, silver armor, blue-and-gold shield, short silver sword, brown hair, and open chibi face from the infantry concept. Render it with the approved archer's detail, outline, materials, lighting, and proportions without borrowing the archer's clothing or green palette. Use a planted guarded stance with complete sword and shield.
Subject: One compact chibi fantasy infantry soldier facing right, with the same recognizable identity as Image 1. Preserve the blue-plumed silver helmet, visible brown hair, open youthful face, silver plate armor, blue-and-gold round shield, and short silver sword. Both feet are planted. Keep the entire helmet plume, body, hands, boots, shield, sword blade, hilt, and all equipment fully inside the canvas.
Scene/backdrop: Perfectly flat exact solid #00ff00 chroma-key background, one uniform color across the entire canvas, with no gradient, texture, lighting variation, floor plane, reflection, or shadow.
Style/medium: Polished 2D chibi fantasy mobile-game character art matching Image 2's crisp dark outline, material detail, soft directional highlights, readable metal and leather surfaces, and compact head/body proportions.
Composition/framing: Single centered full-body character with generous safe padding on every side. The complete figure and all equipment must remain well separated from every canvas edge.
Lighting/mood: Match Image 2's lighting direction and friendly readable neutral expression. No cast shadow or contact shadow.
Color palette: Silver steel, vivid royal blue plume and cloth accents, blue-and-gold shield, brown hair and leather, natural warm skin. Do not use green on the subject and do not use #00ff00 anywhere in the character or equipment.

Match the supplied canonical character exactly: same face, hair, head/body
proportions, costume pieces, colors, weapon or mechanism construction, outline
weight, lighting direction, and chibi fantasy mobile-game rendering quality.
Keep the character facing right. Keep apparent body scale constant. No text,
labels, borders, dividers, shadows, floor, scenery, watermark, extra character,
detached projectile, slash arc, impact star, speed line, aura, explosion, or
decorative effect. Preserve the complete character and all equipment.

Constraints: One character only; exact flat green canvas; complete sword and shield; complete plume and boots; open unobscured chibi face; planted guarded neutral stance; generous chroma-key padding; no crop; no missing equipment; no added weapon; no text or effects.
Avoid: Archer clothing or equipment, green subject colors, closed helmet visor, aggressive attack pose, oversized realistic anatomy, cropped sword, cropped plume, cast shadow, contact shadow, glow, particles, symbols, lettering, scenery, or ground.
```

Built-in generation output:
`<generated-artifact>/019f59d9-6dbe-7243-97f4-58ef72f0855a/exec-0a14cdb7-e9fb-4f5e-9c4d-08e41b3777af.png`
(`1254 x 1254` PNG).

### Targeted Background Correction Prompt

The first image preserved the required infantry identity and equipment but used
a faint green vignette. A single targeted built-in edit requested a background
correction while locking the character.

```text
Use case: precise-object-edit
Asset type: canonical character reference for a mobile-game sprite animation pipeline
Input images: Image 1 is the edit target and must remain the exact character reference.
Primary request: Replace only the green background with one perfectly flat exact solid #00ff00 chroma-key color. Remove every gradient, vignette, glow, texture, lighting variation, floor, and shadow from the background. Do not alter, redraw, resize, reposition, crop, recolor, or restyle the infantry character or any equipment.
Scene/backdrop: Exact #00ff00 on every background pixel, visually uniform from edge to edge.
Composition/framing: Preserve the existing centered full-body figure and generous padding exactly.

Match the supplied canonical character exactly: same face, hair, head/body
proportions, costume pieces, colors, weapon or mechanism construction, outline
weight, lighting direction, and chibi fantasy mobile-game rendering quality.
Keep the character facing right. Keep apparent body scale constant. No text,
labels, borders, dividers, shadows, floor, scenery, watermark, extra character,
detached projectile, slash arc, impact star, speed line, aura, explosion, or
decorative effect. Preserve the complete character and all equipment.

Constraints: Change only the background. Keep the blue-plumed helmet, silver armor, blue-and-gold shield, short silver sword, brown hair, open chibi face, compact proportions, guarded stance, complete equipment, crisp outline, materials, and lighting unchanged. Preserve all safe padding. No #00ff00 may appear inside the subject.
Avoid: Gradient, vignette, texture, green glow, cast shadow, contact shadow, floor plane, scenery, text, effects, missing equipment, cropped equipment, or character drift.
```

Built-in edit output:
`<generated-artifact>/019f59d9-6dbe-7243-97f4-58ef72f0855a/exec-91babb0f-6ae9-48a5-a5e0-52cbfad5dba0.png`
(`1254 x 1254` PNG).

The built-in edit retained a slight green variation, so deterministic chroma
normalization replaced only the keyed background with exact `#00ff00`. The
character pixels and generated scale were preserved. The final outer 8% of the
canvas contains zero non-green pixels.

### Final Candidate

Path: `/private/tmp/pyxis-full-animation/infantry-canonical.png`

- Dimensions: `1254 x 1254`
- Format: PNG, RGBA
- Background: exact flat `#00ff00` at all sampled borders; outer 8% is entirely
  key color
- Framing: centered full body with generous safe padding; no crop or overlap
- Identity: blue-plumed helmet, silver armor, brown hair, open chibi face, and
  compact proportions are preserved
- Equipment: complete blue-and-gold shield and complete short silver sword are
  visible in a planted guarded stance
- Style: detail, outline, material rendering, and lighting match the approved
  archer quality without borrowing archer clothing or green palette
- Exclusions: no text, watermark, shadow, floor, scenery, projectile, slash,
  impact, speed line, aura, explosion, or decorative effect

Visual assessment: suitable for the first visual approval gate. No further
iteration is warranted before user review.

## Step 3: Infantry Storyboards

The user approved the canonical infantry reference. Three separate built-in
image-generation calls then used that reference, the shared image/frame
contracts, and the exact Task 5 walk, attack, and hit prompts. The generated
boards were copied to:

- `/private/tmp/pyxis-full-animation/infantry-walk.png`
- `/private/tmp/pyxis-full-animation/infantry-attack.png`
- `/private/tmp/pyxis-full-animation/infantry-hit.png`

Each source was `1774 x 887`, fixed 5x2 order, with one complete separated pose
per frame and exact green background after deterministic normalization. Visual
inspection confirmed stable identity/equipment, a level alternating walk, a
readable sword wind-up/strike/recovery, and a shield-first planted hit reaction
with facial expression. No pose contained effects, crop, overlap, or missing
equipment.

The generation worker stopped responding during deterministic validation and
was terminated without installing or committing anything. Direct reproduction
showed the exact blocker:

```text
ValueError: outer canvas: non-key artwork entered reserved gutter at (153, 84)
```

The generated figures were complete but taller than the original 355px source
cells' reserved inner region. No validator was weakened and no figure was
scaled or cropped. Column projection identified exactly five disjoint complete
poses per row. Each complete pose rectangle was cropped at its original pixels
and rigidly translated into a uniform `450 x 450` exact-green cell using
ffmpeg `crop`, `pad`, `hstack`, and `vstack`. All thirty frames use the same
cell size and a shared source baseline at y=414 within each cell. The resulting
boards are `2250 x 900` and preserve every generated subject pixel while
providing stable padding and scale across all actions.

Aligned candidates:

- `/private/tmp/pyxis-full-animation/infantry-walk-aligned.png`
- `/private/tmp/pyxis-full-animation/infantry-attack-aligned.png`
- `/private/tmp/pyxis-full-animation/infantry-hit-aligned.png`

The aligned candidates replaced the three task storyboard paths only after an
in-memory call to `prepare_soldier_storyboards` passed all source-gutter,
transparent-border, density, height, baseline, distinct-frame, and cross-action
trio checks (`10` prepared frames for each action).

## Step 4: Preview Validation

The atomic preview command exited 0:

```bash
rtk python3 tools/slice_soldier_animation_strips.py --storyboards-dir /private/tmp/pyxis-full-animation --assets-dir build/animation-preview/Assets.xcassets --soldiers infantry --actions walk attack hit
```

QA artifacts:

- `build/animation-preview/qa/infantry/walk-contact.png`
- `build/animation-preview/qa/infantry/attack-contact.png`
- `build/animation-preview/qa/infantry/hit-contact.png`
- `build/animation-preview/qa/infantry/walk.gif`
- `build/animation-preview/qa/infantry/attack.gif`
- `build/animation-preview/qa/infantry/hit.gif`

The post-resize chroma scan covered exactly 30 preview PNGs and returned:

```text
frames=30 exact_green_nonzero_alpha=0 key_dominant_green_nonzero_alpha=0
```

Coordinator inspection of all three 128px contact sheets found no identity
drift, size pumping, baseline jump, equipment crop, frame bleed, or effect.
Status: awaiting user approval before production installation.

## Step 4 Approval And Task 5 Completion

### User Approval

The user approved all three validated GIFs generated from the exact-green
storyboards:

- `/private/tmp/pyxis-full-animation/infantry-walk.png`
- `/private/tmp/pyxis-full-animation/infantry-attack.png`
- `/private/tmp/pyxis-full-animation/infantry-hit.png`

The approved sources had already passed `prepare_soldier_storyboards`, the
atomic preview slicer, and the 30-frame `0/0` fringe scan recorded above. The
coordinator performed the post-commit simulator playback check recorded below.

### Production Installation

```bash
rtk python3 tools/slice_soldier_animation_strips.py --storyboards-dir /private/tmp/pyxis-full-animation --assets-dir Pyxis/Assets.xcassets --soldiers infantry --actions walk attack hit
```

Result: exit `0`. The atomic slicer replaced exactly the 30 approved infantry
frames (`walk`, `attack`, and `hit`, 10 each) in the production asset catalog.

`SoldierAnimationManifest` now declares the exact approved sets:

```swift
private static let authoredActions: [SoldierType: Set<SoldierAnimationAction>] = [
    .archer: Set(SoldierAnimationAction.allCases),
    .infantry: Set(SoldierAnimationAction.allCases)
]
private static let fullCanvasTypes: Set<SoldierType> = [.archer, .infantry]
```

The existing infantry RED assertions remain and now pass. Legacy BattleScene
tests that intentionally assert cropped, procedural behavior explicitly spawn
unapproved cavalry instead of approved full-canvas infantry.

### Fresh Verification

```bash
rtk python3 -m unittest tools.tests.test_slice_soldier_animation_strips
```

Result: exit `0`; `Ran 19 tests`; `OK`.

```bash
rtk python3 -c 'from pathlib import Path; from PIL import Image; frames=sorted(Path("Pyxis/Assets.xcassets").glob("infantry-*.imageset/*.png")); assert len(frames)==30, len(frames); exact=dominant=0
for path in frames:
    image=Image.open(path).convert("RGBA")
    assert image.size==(128,128), (path,image.size)
    for red,green,blue,alpha in image.getdata():
        if alpha:
            exact += (red,green,blue)==(0,255,0)
            dominant += green>red*1.6 and green>blue*1.6 and green>150 and red<95 and blue<95
assert exact==0 and dominant==0, (exact,dominant)
print(f"frames={len(frames)} exact_green_nonzero_alpha={exact} key_dominant_green_nonzero_alpha={dominant}")'
```

Result: exit `0`; `frames=30 exact_green_nonzero_alpha=0 key_dominant_green_nonzero_alpha=0`.

XcodeBuildMCP session defaults: `Pyxis.xcodeproj`, scheme `Pyxis`, simulator
`iPhone 17`, derived data `/private/tmp/pyxis-task5-derived-data`. Each test
call used `extraArgs: ["-parallel-testing-enabled", "NO", ...]`.

```text
test_sim -only-testing:PyxisTests/SoldierAnimationManifestTests
```

Result: `2 passed, 0 failed, 0 skipped`.

```text
test_sim -only-testing:PyxisTests/BattleSceneTests
```

Result: `120 passed, 0 failed, 0 skipped`.

```text
test_sim -only-testing:PyxisTests
```

Result: `351 passed, 0 failed, 0 skipped`.

```bash
rtk swiftlint lint --quiet --cache-path /private/tmp/pyxis-full-animation-swiftlint-cache
```

Result: exit `0`; repository warnings remain but no lint errors.

```bash
rtk git diff --check
```

Result: exit `0`.

### Independent Review

The Task 5 reviewer inspected commit range `d322d8be..6c4e9d9` and returned
`APPROVED` with no critical, important, or minor findings. The review is
recorded in `.superpowers/sdd/full-animation-task-5-review.md`. The reviewer
correctly left simulator playback to the coordinator because the recording had
not yet been captured during that review pass.

### Simulator Playback Verification

XcodeBuildMCP rebuilt, installed, and launched commit `6c4e9d9` on the configured
`iPhone 17 Pro` simulator. A temporary, uncommitted XCUITest tapped the Infantry
spawn control eight times and held the battle scene for 24 seconds. The test ran
with parallel testing disabled and passed (`1 passed, 0 failed`); the temporary
test file was deleted immediately after capture.

Playback evidence:

- `build/animation-preview/qa/infantry/simulator-playback.mp4`
- `build/animation-preview/qa/infantry/simulator-playback-focus.gif`
- `build/animation-preview/qa/infantry/simulator-action-contact.jpg`

The live sequence shows the installed blue-plumed Infantry sprites advancing
through the authored walk frames, changing sword-arm and body posture through
the strike sequence at the enemy city, and entering the authored guarded hit
reaction under tower fire. The soldiers retain the approved appearance and
scale throughout; no legacy cropped texture or procedural-only substitution is
visible.
