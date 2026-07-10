# Soldier Action Animation Redesign

**Date:** 2026-07-09
**Status:** Approved

## Summary

Replace the current attack and hit presentation with authored frame animation for
all five soldier types. The new assets must preserve each walk sprite's identity,
show natural body mechanics, remain readable at battlefield scale, and never leak
artwork from an adjacent source frame.

The existing walk art remains the canonical character reference. Attack and hit
art is regenerated, the slicing pipeline changes from a horizontal strip to a
guttered 5-by-2 storyboard, and `BattleScene` returns to action-specific texture
playback. Procedural weapon, limb, expression, and posture overlays are removed.

## Problem Statement

The existing transient animation has three coupled defects:

1. The generated horizontal strips do not always divide into ten exact visual
   panels. Equal-width slicing can therefore include part of the next pose.
2. The slicer crops and auto-fits each frame from its own opaque bounds. A long
   weapon, arrow, or impact effect changes those bounds and makes the character
   visibly shrink or jump between frames.
3. Runtime texture cropping keeps only the central portion of every frame. This
   can remove bows, lances, limbs, and follow-through poses that extend beyond
   the walk sprite's narrow body region.

The current workaround suppresses real attack and hit textures and layers
procedural strokes and motion over walk textures. It preserves identity but does
not read as a complete, natural action.

## Goals

- Regenerate attack and hit animation for infantry, archer, cavalry, mage, and
  siege soldiers.
- Preserve the exact character identity, costume, palette, proportions, and
  weapon styling established by each soldier's walk frames.
- Give every action a clear anticipation, committed movement, contact or recoil,
  follow-through, and recovery.
- Eliminate adjacent-frame bleed, per-frame scale pumping, broken crops, and
  appearance changes.
- Keep effects restrained so posture, hands, weapons, faces, and weight transfer
  carry the action.
- Complete each animation cycle before the same soldier type can naturally
  trigger its next attack.

## Non-Goals

- Do not change combat damage, targeting, range, attack speed, tower behavior,
  soldier HP, movement speed, or spawn rules.
- Do not redesign the existing walk artwork.
- Do not add new combat controls, physics, hitboxes, or UI.
- Do not add large slash arcs, glowing trails, explosions, star reactions, or
  detached projectiles to the body sprite sheets.
- Do not refactor unrelated battle layout or gameplay code.

## Asset Scope

The redesign replaces 100 frame assets:

- 5 soldier types
- 2 transient actions: `attack` and `hit`
- 10 frames per type and action

The existing asset names remain stable:

- `<soldier>-attack-01` through `<soldier>-attack-10`
- `<soldier>-hit-01` through `<soldier>-hit-10`

Existing walk frames remain unchanged and serve as both identity references and
the neutral-pose scale anchors for the new actions.

## Art Direction

### Shared rules

- Match the existing chibi fantasy mobile-game rendering, outline weight,
  material detail, color palette, lighting direction, and facial proportions.
- Keep the character facing the same battlefield direction in every frame.
- Keep feet, hooves, or wheels on one authored baseline. No jumping unless it is
  intrinsic to an action, and none of these actions require a jump.
- Keep the body at the same apparent scale as the corresponding walk sprite.
- Use the full canvas for a moving weapon or limb while the torso and lower body
  remain aligned to the walk reference box.
- Start and finish close enough to the walk stance that switching actions does
  not produce a visible pop.
- Do not include cast shadows, floor planes, text, watermarks, decorative frames,
  or background scenery.
- Detached combat effects are not part of these storyboards. Small runtime cues
  may accompany contact, but the body animation must read clearly without them.

### Archer

The walk archer is the strict identity and equipment reference. Preserve the
green hood, leather layers, face, quiver, arrow treatment, and the bow's existing
wood color, limb shape, grip, string, and proportions. Do not replace it with a
different bow design.

The attack must show the complete shooting mechanic: the bow shoulder settles,
the bow arm extends, the drawing elbow rises, the drawing hand reaches the cheek,
the torso rotates slightly, the string reaches full draw, and the release creates
a small natural arm and bow recoil. A single restrained runtime arrow may leave
at release, but there are no glowing arrows, trails, or oversized impact effects.

The hit reaction uses a brief shoulder collapse, torso recoil, tightened eyes or
grimace, and controlled recovery while the archer keeps hold of the bow.

### Infantry

The attack uses a compact sword wind-up, planted front foot, visible weight
transfer, diagonal strike, wrist and shoulder follow-through, and return behind
the shield. The sword and shield retain the walk sprite's exact design. No large
slash arc is drawn over the soldier.

The hit reaction turns the shield and torso toward impact, compresses the stance,
shows a brief facial grimace, and then regains guard.

### Cavalry

The rider and mount remain one consistent unit. The attack lowers and drives the
lance while the horse braces and takes one controlled forward step. The rider's
hips, shoulders, hands, and lance align naturally with the mount. There is no
large leap or full-sprite lunge.

The hit reaction shows the mount checking its step and the rider absorbing the
impact through the seat and reins before recovering.

### Mage

The attack uses hand, shoulder, robe, and staff movement as the primary action.
The caster plants the staff, gathers energy with the free hand, directs the staff,
and settles. Only a small staff-tip glow is allowed; no large aura or projectile
occupies the sprite frame.

The hit reaction interrupts the casting posture, tightens the face, folds the
free arm inward, and restores the staff-bearing stance.

### Siege

The attack shows the operator or crew brace, operate the mechanism, absorb the
mechanical recoil, and reset it. Wheels and chassis remain grounded, and moving
parts retain the walk sprite's construction and proportions. Smoke and explosions
are omitted from the body frames.

The hit reaction shows a short chassis jolt plus an operator brace or grimace,
followed by mechanical settling rather than a whole-unit displacement.

## Motion Sequence

Each action uses ten row-major frames with the same phase structure:

1. Neutral stance matching the walk identity.
2. Initial anticipation or recognition.
3. Deeper wind-up or impact brace.
4. Transition into the committed movement.
5. Contact, release, or peak recoil.
6. Follow-through or held reaction.
7. Rebound from the peak pose.
8. Controlled recovery.
9. Near-neutral settle.
10. Neutral stance suitable for returning to walk.

Attack playback duration follows the existing type cadence so an action is not
restarted before it completes:

- Infantry: 0.90 seconds
- Archer: 0.90 seconds
- Cavalry: 0.80 seconds
- Mage: 1.00 second
- Siege: 1.40 seconds

Hit playback lasts 0.80 seconds for every type. A hit reaction may interrupt an
attack when both occur in the same combat tick. A surviving soldier resumes walk
after the transient action; a killed soldier completes the readable hit peak
before its existing removal transition.

## Storyboard Format

Each source action is one 5-column by 2-row storyboard of square cells. Frame
order is row-major: frames 1 through 5 on the first row and frames 6 through 10
on the second row.

The square-cell grid occupies the full storyboard width and is centered
vertically. Any canvas above or below the grid is key-color-only padding. Before
slicing, the pipeline pads only the trailing right edge with key color until the
width is divisible by five. Cell size is then `normalized width / 5`, and the
two-row grid height is exactly two cell sizes. The pipeline never infers panel
boundaries from visible artwork.

Each equal-sized cell has an inner safe region. The outer 8 percent on every side
of a cell is reserved for a flat chroma-key gutter. Character, weapon, clothing,
and antialiased edges must remain inside the inner 84 percent. The slicer rejects
rather than repairs artwork that enters this gutter.

The archer uses a flat `#ff00ff` key so green clothing is preserved. Infantry,
cavalry, mage, and siege use flat `#00ff00`. The background is one uniform key
color with no shadow, gradient, texture, reflection, or lighting variation.

## Slicing And Validation Pipeline

`tools/slice_soldier_animation_strips.py` is extended or replaced with a
storyboard-aware path. The existing horizontal-strip behavior may remain only if
older source material still needs it; new attack and hit assets use the 5-by-2
layout.

For each storyboard, the pipeline:

1. Pads the trailing right edge with key color until width is divisible by five.
2. Computes the centered 5-by-2 square-cell grid from normalized width. It fails
   if source height cannot contain two square rows.
3. Verifies that canvas outside the grid and each cell's reserved 8 percent border
   match the configured key color within 12 values per RGB channel.
4. Removes the key color from each complete cell using border auto-key sampling,
   a soft matte, transparent threshold 12, opaque threshold 220, and despill.
5. Resizes each complete square cell, including its transparent safety border,
   to 128 by 128 using one identical transform for every frame. It does not crop,
   center, or thumbnail from per-frame opaque bounds.
6. Writes RGBA PNG files and their existing `Contents.json` image sets only after
   all ten frames pass validation.

Automated validation requires:

- Exactly ten 128-by-128 RGBA outputs per action.
- Transparent output corners and at least a four-pixel transparent outer border.
- No non-key source pixels in any cell's reserved gutter.
- No empty frame and no pixel-identical adjacent pair.
- Opaque pixel count between 60 and 150 percent of the sequence median.
- Opaque bounding-box height between 70 and 130 percent of the sequence median.
- Ground baseline variation no greater than six output pixels.

Metrics that fail these limits reject the complete action before any existing
asset is replaced. Automated checks supplement, but do not replace, visual review
of identity and natural motion.

## Runtime Playback

`BattleScene` resolves complete, action-specific frame sets for walk, attack, and
hit. Attack and hit no longer alias to walk when their ten-frame sets are valid.

Animation textures use the complete 128-by-128 canvas. The current center texture
crop is removed because it clips extended action poses. Each type's existing walk
body region defines the logical body-height fraction used to size the full frame,
so the visible body remains at the current battlefield height while weapons may
use surrounding transparent space.

Soldier HP bars are positioned from the logical body height rather than the full
transparent sprite frame. This prevents the larger full-canvas node from moving
the HP bar upward.

The transient time-per-frame is selected by soldier type and action from the
durations above. Before a transient starts, competing transient texture actions
are removed. Hit takes priority when attack and hit arrive in the same tick.

The procedural attack-pose limbs and weapons, procedural hit face and posture,
and their associated whole-body exaggeration are removed. Valid authored actions
receive no additional root lunge or posture motion. The existing city impact cue,
tower projectile, and a hit color flash no longer than 0.12 seconds may remain.

If a complete transient set is unavailable, gameplay continues with the stable
walk or static identity plus restrained root-only feedback capped at two points
of displacement at normal battlefield size. Missing art must not crash combat or
expose a broken texture.

## Generation And Review Sequence

Generation is staged to avoid repeating a flawed art direction across all 100
frames:

1. Generate and slice the archer attack storyboard using the existing walk frame
   as the identity, style, scale, and bow reference.
2. Review its source grid, ten-frame contact sheet, animated preview, alpha edges,
   scale, baseline, bow mechanics, and transition back to walk.
3. Generate and review archer hit using the approved identity treatment.
4. Apply the same storyboard and validation contract to infantry, cavalry, mage,
   and siege attack and hit actions.
5. Replace project assets only after each complete action passes its automated
   and visual checks.

## Testing

### Pipeline tests

- A synthetic 5-by-2 board with distinct cell colors proves that no output frame
  contains pixels from a neighboring cell.
- A source subject entering the reserved gutter rejects the complete action.
- Empty, low-density, high-density, scale-jump, baseline-jump, and incomplete
  action fixtures reject without partially replacing assets.
- Valid fixtures produce ten 128-by-128 RGBA frames and correct asset metadata.

### BattleScene tests

- Every soldier type resolves ten distinct walk, attack, and hit frame names.
- Complete attack and hit sets resolve their own textures rather than walk.
- Attack playback installs the correct action key and type-specific duration.
- Hit playback interrupts attack, installs the hit key, and resumes walk only for
  surviving soldiers.
- Full-frame sizing preserves the logical soldier body height and keeps HP bars
  aligned to that body height.
- Missing or incomplete transient sets use the stable fallback without crashing.
- Procedural attack-part and hit-expression overlay nodes are absent.

### Visual verification

- Inspect 5-by-2 source boards and ten-frame alpha contact sheets for every action.
- Inspect animated previews for frame order, continuous motion, stable identity,
  stable baseline, stable scale, and a clean return to walk.
- Run multi-soldier battles in the iPhone simulator and record attack and hit
  cycles for all five types at battlefield size.
- Confirm the archer's elbow, drawing hand, bow bend, string release, and subtle
  recoil are readable without relying on the arrow effect.
- Confirm hit reactions communicate posture and expression without large effects.

## Acceptance Criteria

- No final frame contains visible artwork from an adjacent storyboard cell.
- No soldier changes identity, costume, palette, body scale, or weapon design
  when switching between walk, attack, and hit.
- All five attack actions show an unmistakable, type-appropriate body mechanic.
- All five hit actions show a readable facial or posture reaction and recovery.
- Archer attack visibly raises the drawing elbow and hand, bends the matching bow,
  reaches full draw, releases, and recovers naturally.
- Attack and hit sequences play in correct order, complete smoothly, and return
  cleanly to walk.
- Effects remain secondary, small, and visually quieter than the body animation.
- Focused pipeline and `BattleScene` tests, full `PyxisTests`, `PyxisUITests`,
  SwiftLint, asset validation, `git diff --check`, and simulator verification pass.
