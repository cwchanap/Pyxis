# Infantry And Archer Size-Consistency Sidecar Report

## Scope

This sidecar pauses Cavalry at its existing canonical approval gate. It first
created and validated temporary Infantry and Archer raster candidates. After
the user reported that Xcode still showed the issue, the validated candidates
were installed into the production asset catalog and rebuilt from fresh
DerivedData. The animation manifest and unrelated `.gitignore` were unchanged.

## Diagnosis

The current 128 px previews reproduced the reported scale pumping:

| Sequence | Previous heights | Previous median | Previous range | Previous neutral |
| --- | --- | ---: | ---: | ---: |
| Infantry attack | 83, 82, 83, 81, 79, 80, 83, 81, 81, 81 | 81.0 | 4 | 82.0 |
| Infantry hit | 97, 96, 92, 88, 85, 79, 88, 92, 92, 91 | 91.5 | 18 | 94.0 |
| Archer hit | 105, 104, 93, 91, 90, 97, 96, 102, 102, 103 | 99.5 | 15 | 104.0 |

The unchanged Infantry walk neutral height is approximately 93.5 px. Infantry
attack therefore rendered about 12 percent shorter than walk even though its
baseline was stable. The old Infantry and Archer hit sequences used deep
vertical compression at their reaction peaks.

## Generated Candidates

Built-in image generation was used once per corrected action. Each prompt used
the shared canonical and storyboard contracts from the implementation plan.

### Infantry Attack

Inputs:

- `/private/tmp/pyxis-full-animation/infantry-canonical.png`: identity and
  equipment authority.
- `/private/tmp/pyxis-full-animation/infantry-walk.png`: apparent head/body
  scale, neutral height, baseline, style, and composition authority.
- `/private/tmp/pyxis-full-animation/infantry-attack.png`: attack-motion
  reference only; its reduced scale was explicitly rejected.

Prompt-specific request: restore the attack to the walk scale, preserve a
planted neutral/wind-up/strike/follow-through/recovery sequence, and drive the
motion with the sword arm, elbow, shoulders, and mild torso rotation rather
than whole-character translation or scaling.

Generated source:
`/Users/chanwaichan/.codex/generated_images/019f5e43-eb0f-7cb3-8208-d0e408330614/exec-6bba1246-cdb0-4cea-9a61-7b79d045fb6c.png`

### Infantry Hit

Inputs:

- `/private/tmp/pyxis-full-animation/infantry-canonical.png`: identity and
  equipment authority.
- `/private/tmp/pyxis-full-animation/infantry-walk.png`: apparent head/body
  scale, neutral height, baseline, style, and composition authority.
- `/private/tmp/pyxis-full-animation/infantry-hit.png`: reaction context only;
  its crouch and vertical compression were explicitly rejected.

Prompt-specific request: use a shield-first lean and recoil, visible grimace,
shoulder and elbow changes, planted feet, and only slight knee flexion. Frames
7-10 recover smoothly to the walk-scale neutral.

Generated source:
`/Users/chanwaichan/.codex/generated_images/019f5e43-eb0f-7cb3-8208-d0e408330614/exec-c432214a-76b2-4bdb-9f45-e9c11fb5ecee.png`

### Archer Hit

Inputs:

- `/private/tmp/pyxis-full-animation/archer-canonical.png`: identity,
  equipment, and rendering authority.
- `/private/tmp/pyxis-full-animation/archer-walk.png`: apparent head/body
  scale, neutral height, baseline, style, and composition authority.
- `/private/tmp/pyxis-full-animation/archer-hit.png`: reaction context only;
  its crouch and vertical compression were explicitly rejected.

Prompt-specific request: use facial expression, shoulder recoil, elbow/cape
movement, a mild torso lean, planted feet, and slight knee flexion while
preserving the complete bow, quiver, arrows, hood, cape, belt, and pouches.

Generated source:
`/Users/chanwaichan/.codex/generated_images/019f5e43-eb0f-7cb3-8208-d0e408330614/exec-ee668231-b0e7-4824-ae82-cf97853fa249.png`

All prompts also required exactly ten row-major 5-by-2 frames, fixed apparent
scale, one baseline, complete equipment, generous exact chroma padding, and no
shadow, scenery, text, projectile, slash arc, impact effect, aura, or frame
bleed.

## Deterministic Preparation

The generated key backgrounds were removed with the bundled image-generation
chroma helper using border auto-keying, soft matte, and despill. Each complete,
separated pose was then rigidly translated onto a fixed square cell without
pose scaling or discarded artwork:

- Infantry: 397 px cells, 1985 by 794 board, subject baseline 365.
- Archer: 355 px cells, 1775 by 710 board, subject baseline 327.

Every source cell keeps at least the required 8 percent flat key gutter. The
final temporary boards use exact `#00ff00` for Infantry and exact `#ff00ff` for
Archer.

## Standard Candidate Set

The separate candidate directory contains complete trios so the atomic preview
can combine unchanged approved boards with corrected boards:

```text
/private/tmp/pyxis-sizefix/infantry-walk.png
/private/tmp/pyxis-sizefix/infantry-attack.png
/private/tmp/pyxis-sizefix/infantry-hit.png
/private/tmp/pyxis-sizefix/archer-walk.png
/private/tmp/pyxis-sizefix/archer-attack.png
/private/tmp/pyxis-sizefix/archer-hit.png
```

SHA-256:

```text
f7eae06a70ac9aae458fd89223dc634042f92e698d48eb08fbf72fd690b40527  infantry-walk.png
b3f490706e2385a9dff11b8e51a6143d90318ac15859144335e392063e123bf8  infantry-attack.png
7771f6f5e9ac4973e9552772f5fcc31ae83e1ac3007afeb503265a8a0d9e7df1  infantry-hit.png
4d5809fbeaa8ae45031086a80ef37218a1312f28630a168c4d2be9ad9e899c99  archer-walk.png
696483d99effcc8c9f5e3d756610154f692525651d7014fb6c75259bdd04d777  archer-attack.png
f45f6a89cfef11da20c03f06df57733c6c26ee7b1a9914835b70aa8e0cb31ec7  archer-hit.png
```

The unchanged walk boards and unchanged Archer attack hashes match their
approved `/private/tmp/pyxis-full-animation` sources.

## Corrected 128 Px Metrics

| Sequence | Corrected heights | Corrected median | Corrected range | Corrected neutral | Baseline |
| --- | --- | ---: | ---: | ---: | --- |
| Infantry attack | 95, 93, 98, 89, 86, 85, 83, 86, 90, 91 | 89.5 | 15 | 93.0 | 120-120 |
| Infantry hit | 96, 96, 96, 91, 91, 91, 92, 93, 93, 92 | 92.5 | 5 | 94.0 | 120-120 |
| Archer hit | 103, 103, 100, 98, 94, 103, 105, 104, 105, 104 | 103.0 | 11 | 103.5 | 120-121 |

Infantry attack now enters and exits at the walk neutral scale instead of being
approximately 12 percent undersized. Its lower strike-frame bounding heights
come from horizontal sword and arm orientation, while the helmet/head and body
scale remain fixed. Infantry hit peak compression improved from 79 px to 91 px.
Archer hit peak height improved from 90 px to 94 px, with the visible reaction
now coming from head expression and a mild upper-body recoil rather than a deep
crouch.

## Validation

Atomic preview command:

```bash
rtk python3 tools/slice_soldier_animation_strips.py \
  --storyboards-dir /private/tmp/pyxis-sizefix \
  --assets-dir build/animation-preview/sizefix/Assets.xcassets \
  --soldiers infantry archer \
  --actions walk attack hit
```

Result: exit 0. Both complete 30-frame trios passed source-gutter,
transparent-border, density, height, baseline, neutral-scale, distinct-frame,
and cross-action validation.

Pipeline tests:

```text
Ran 21 tests in 7.244s
OK
```

Post-resize chroma scan:

```text
infantry: frames=30 exact=0 key_dominant=0
archer: frames=30 exact=0 key_dominant=0
```

## QA Artifacts

Infantry:

```text
build/animation-preview/qa/sizefix/infantry/walk-contact.png
build/animation-preview/qa/sizefix/infantry/walk.gif
build/animation-preview/qa/sizefix/infantry/attack-contact.png
build/animation-preview/qa/sizefix/infantry/attack.gif
build/animation-preview/qa/sizefix/infantry/hit-contact.png
build/animation-preview/qa/sizefix/infantry/hit.gif
```

Archer:

```text
build/animation-preview/qa/sizefix/archer/walk-contact.png
build/animation-preview/qa/sizefix/archer/walk.gif
build/animation-preview/qa/sizefix/archer/attack-contact.png
build/animation-preview/qa/sizefix/archer/attack.gif
build/animation-preview/qa/sizefix/archer/hit-contact.png
build/animation-preview/qa/sizefix/archer/hit.gif
```

Visual review found no identity drift, whole-character scale pulse, baseline
jump, frame bleed, equipment crop, detached equipment, or added effect.

## Production Cutover And Simulator Verification

The atomic production cutover installed both complete trios from
`/private/tmp/pyxis-sizefix`. Git comparison confirmed that unchanged walk and
Archer attack frames remained byte-identical; exactly the intended 30 PNGs
changed: ten Infantry attack, ten Infantry hit, and ten Archer hit frames.

Commit `2fbb1d3` adds the neutral-frame scale regression guard. Its 21 pipeline
tests pass, and the current Infantry source now satisfies the new guard instead
of failing at the previous `0.88` attack-to-walk neutral-height ratio.

XcodeBuildMCP used a fresh DerivedData directory at
`/private/tmp/pyxis-sizefix-derived-data`, then built, installed, and launched
bundle `cwchanap.Pyxis` on the iPhone 17 Pro simulator. Build and launch passed.
A temporary uncommitted XCUITest spawned eight Infantry soldiers and held the
battle scene for 24 seconds with parallel testing disabled; it passed (`1`
test, `0` failures) and was deleted after capture.

Live simulator evidence:

```text
build/animation-preview/qa/sizefix/simulator-infantry-playback.mp4
build/animation-preview/qa/sizefix/simulator-infantry-contact.jpg
build/animation-preview/qa/sizefix/simulator-infantry-action-contact.jpg
```

The frame-by-frame live contact sheet shows the corrected Infantry maintaining
the same apparent body/head scale while transitioning through walk, strike,
recovery, and tower-hit reactions. The simulator is running the newly compiled
asset catalog rather than the previous QA-only assets.
